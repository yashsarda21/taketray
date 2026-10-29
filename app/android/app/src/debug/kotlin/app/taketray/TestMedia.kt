package app.taketray

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.os.Bundle
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import java.io.IOException

/**
 * Test videos for the on-device (Patrol) tests, in a folder of their own (D-77).
 * Debug builds only: this file lives in `src/debug`, so release and profile
 * builds do not contain it (`tool/check_release_permissions` checks the dex).
 *
 * **Safety.** The app can only be told to delete a row that [TestMediaGuard]
 * accepts: in `Movies/TakeTray Test/` and owned by this very app. Anything else
 * is refused with [TestMediaRefused] and nothing is deleted. The files belong
 * to this app (MediaStore records the inserting package as the owner), so
 * deleting them needs no consent dialog.
 *
 * **Privacy.** Nothing here logs or puts into an error message a display name,
 * a path, a URI or an id (D-10).
 *
 * All methods do blocking I/O: call them off the main thread.
 */
class TestMedia(
    private val resolver: ContentResolver,
    private val ownPackage: String,
    private val volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
) {
    /** What [insertVideo] made. */
    data class Inserted(
        val volumeName: String,
        val mediaStoreId: Long,
    )

    /** What [deleteLeftovers] did: rows deleted, and rows in the folder it had to leave alone. */
    data class Cleanup(
        val deleted: Int,
        val refused: Int,
    )

    private val collection = MediaStore.Video.Media.getContentUri(volume)

    /**
     * Puts [bytes] into `Movies/TakeTray Test/` as a video named [displayName]
     * (MediaStore renames it if the name is taken): the row is made with
     * IS_PENDING 1, the bytes are written, then IS_PENDING is set to 0, which
     * publishes it, as a camera app does. If anything fails on the way, the
     * half-made row is deleted and the failure goes on.
     */
    fun insertVideo(
        bytes: ByteArray,
        displayName: String,
    ): Inserted {
        require(bytes.isNotEmpty()) { "no video bytes" }
        require(displayName.isNotBlank() && '/' !in displayName) { "bad display name" }
        val uri =
            resolver.insert(
                collection,
                ContentValues().apply {
                    put(MediaColumns.DISPLAY_NAME, displayName)
                    put(MediaColumns.MIME_TYPE, MIME_TYPE)
                    put(MediaColumns.RELATIVE_PATH, TestMediaGuard.FOLDER)
                    put(MediaColumns.DATE_TAKEN, System.currentTimeMillis())
                    put(MediaColumns.IS_PENDING, 1)
                },
            ) ?: throw IOException("MediaStore made no row")
        val id = ContentUris.parseId(uri)
        try {
            val out = resolver.openOutputStream(uri, "w") ?: throw IOException("no output stream")
            out.use { it.write(bytes) }
            val published = resolver.update(uri, ContentValues().apply { put(MediaColumns.IS_PENDING, 0) }, null, null)
            if (published != 1) throw IOException("the row was not published")
        } catch (e: Throwable) {
            // Our own half-made row: removing it is exactly what deleteVideo does.
            try {
                deleteVideo(id)
            } catch (ignored: Exception) {
                // The first failure is the one to report.
            }
            throw e
        }
        return Inserted(volume, id)
    }

    /**
     * Deletes the row [mediaStoreId] when [TestMediaGuard] accepts it. Returns
     * true when a row was deleted and false when no such row exists (it was
     * deleted already: deleting twice is fine). Throws [TestMediaRefused], and
     * deletes nothing, when the row is not one of this app's test videos.
     */
    fun deleteVideo(mediaStoreId: Long): Boolean {
        val row = findRow(mediaStoreId) ?: return false
        if (!TestMediaGuard.allowsDelete(row.relativePath, row.ownerPackage, ownPackage)) {
            throw TestMediaRefused()
        }
        return resolver.delete(ContentUris.withAppendedId(collection, mediaStoreId), null, null) > 0
    }

    /**
     * Deletes every row in the test folder that this app owns (what an earlier
     * run that crashed left behind), pending rows included. Rows in the folder
     * that someone else owns are counted in [Cleanup.refused] and left alone.
     */
    fun deleteLeftovers(): Cleanup {
        var deleted = 0
        var refused = 0
        for (row in rowsIn(TestMediaGuard.FOLDER)) {
            if (TestMediaGuard.allowsDelete(row.relativePath, row.ownerPackage, ownPackage)) {
                if (deleteVideo(row.id)) deleted++
            } else {
                refused++
            }
        }
        return Cleanup(deleted, refused)
    }

    private class Row(
        val id: Long,
        val relativePath: String?,
        val ownerPackage: String?,
    )

    private fun findRow(id: Long): Row? = query("${MediaColumns._ID} = ?", arrayOf(id.toString())).firstOrNull()

    private fun rowsIn(folder: String): List<Row> = query("${MediaColumns.RELATIVE_PATH} = ?", arrayOf(folder))

    /** Pending and trashed rows included: a leftover is often one of those. */
    private fun query(
        selection: String,
        args: Array<String>,
    ): List<Row> {
        val queryArgs =
            Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
            }
        val projection = arrayOf(MediaColumns._ID, MediaColumns.RELATIVE_PATH, MediaColumns.OWNER_PACKAGE_NAME)
        val cursor = resolver.query(collection, projection, queryArgs, null) ?: throw IOException("MediaStore gave no cursor")
        return cursor.use { c ->
            val idColumn = c.getColumnIndexOrThrow(MediaColumns._ID)
            val pathColumn = c.getColumnIndexOrThrow(MediaColumns.RELATIVE_PATH)
            val ownerColumn = c.getColumnIndexOrThrow(MediaColumns.OWNER_PACKAGE_NAME)
            buildList {
                while (c.moveToNext()) {
                    add(
                        Row(
                            id = c.getLong(idColumn),
                            relativePath = if (c.isNull(pathColumn)) null else c.getString(pathColumn),
                            ownerPackage = if (c.isNull(ownerColumn)) null else c.getString(ownerColumn),
                        ),
                    )
                }
            }
        }
    }

    private companion object {
        const val MIME_TYPE = "video/mp4"
    }
}

/**
 * The one rule that decides whether a row may be deleted. A pure function, so
 * it is tested alone.
 */
object TestMediaGuard {
    /** The test folder as MediaStore stores RELATIVE_PATH: no leading '/', one trailing '/'. */
    const val FOLDER = "Movies/TakeTray Test/"

    /**
     * True only for a row whose folder is exactly [FOLDER] (same case, no
     * sub-folder) and whose owner is exactly [ownPackage]. An unknown folder or
     * owner (null) is a no. The release app `app.taketray` is not the debug
     * app `app.taketray.dev`: it never matches.
     */
    fun allowsDelete(
        relativePath: String?,
        ownerPackage: String?,
        ownPackage: String,
    ): Boolean = relativePath == FOLDER && ownerPackage != null && ownPackage.isNotEmpty() && ownerPackage == ownPackage
}

/** [TestMedia.deleteVideo] was asked for a row that is not one of this app's test videos. */
class TestMediaRefused : SecurityException("not a TakeTray test video")
