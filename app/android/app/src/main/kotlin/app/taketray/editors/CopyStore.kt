package app.taketray.editors

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.os.StatFs
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/** An original opened read-only: its bytes and its own length (-1 when the provider does not know it). */
class SourceFile(
    val input: InputStream,
    val length: Long,
) : AutoCloseable {
    override fun close() = input.close()
}

/** A row after IS_PENDING 0: its id and the name MediaStore really gave it. */
data class Published(
    val id: Long,
    val displayName: String,
)

/** A TakeTray-owned row in one copy folder. */
data class FolderRow(
    val mediaStoreId: Long,
    val fileName: String,
    val sizeBytes: Long,
    val pending: Boolean,
)

/**
 * Everything the copy loop does to storage, behind one interface so the loop
 * is tested without MediaStore. Every method does blocking I/O.
 */
interface CopyStore {
    fun availableBytes(): Long

    fun insertPending(
        folder: String,
        fileName: String,
    ): Long

    fun openSource(source: CopySource): SourceFile

    fun openTarget(rowId: Long): OutputStream

    fun publish(rowId: Long): Published

    fun deleteOwn(
        rowId: Long,
        folder: String,
        fileName: String?,
    ): Boolean

    fun ownRowsIn(folder: String): List<FolderRow>

    fun deletePendingIn(folder: String): Int
}

/**
 * The real [CopyStore] over MediaStore (D-122). Copies go to the primary
 * volume's video collection, always; an original is read from wherever it
 * is (an SD card too), read-only. Every delete checks the row first: only a
 * row TakeTray owns in exactly `Movies/TakeTray/<folder>/` ([CopyFolderPath])
 * is ever deleted.
 */
class MediaStoreCopyStore(
    private val resolver: ContentResolver,
    private val ownPackage: String,
    /** Free bytes on the primary volume, where every copy goes. */
    private val freeBytes: () -> Long = { StatFs(Environment.getExternalStorageDirectory().path).availableBytes },
) : CopyStore {
    private val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

    private fun rowUri(id: Long): Uri = ContentUris.withAppendedId(collection, id)

    override fun availableBytes(): Long = freeBytes()

    /**
     * A pending row named [fileName] in `Movies/TakeTray/<folder>/`. No
     * MIME type is given: MediaStore takes it from the name's extension, so
     * it never adds a second extension to a `.mov` whose clip said `video/mp4`.
     */
    override fun insertPending(
        folder: String,
        fileName: String,
    ): Long {
        val values =
            ContentValues().apply {
                put(MediaColumns.DISPLAY_NAME, fileName)
                put(MediaColumns.RELATIVE_PATH, CopyFolderPath.relativePath(folder))
                put(MediaColumns.IS_PENDING, 1)
            }
        val uri = resolver.insert(collection, values) ?: throw IOException("MediaStore made no row")
        return ContentUris.parseId(uri)
    }

    /** Read-only, on the original's own volume or through its picker address (content addresses only). */
    override fun openSource(source: CopySource): SourceFile {
        val uri = sourceUri(source)
        val pfd = resolver.openFileDescriptor(uri, "r") ?: throw FileNotFoundException("no descriptor")
        return SourceFile(ParcelFileDescriptor.AutoCloseInputStream(pfd), pfd.statSize)
    }

    private fun sourceUri(source: CopySource): Uri {
        val picker = source.pickerUri
        if (picker != null) {
            val uri = Uri.parse(picker)
            require(uri.scheme == ContentResolver.SCHEME_CONTENT) { "not a content address" }
            return uri
        }
        val volume = source.volumeName
        val id = source.mediaStoreId
        require(!volume.isNullOrEmpty() && id != null) { "no identity" }
        return ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(volume), id)
    }

    override fun openTarget(rowId: Long): OutputStream {
        val pfd = resolver.openFileDescriptor(rowUri(rowId), "w") ?: throw FileNotFoundException("no descriptor")
        return ParcelFileDescriptor.AutoCloseOutputStream(pfd)
    }

    /** IS_PENDING 0, then the name MediaStore really gave the file. */
    override fun publish(rowId: Long): Published {
        val updated = resolver.update(rowUri(rowId), ContentValues().apply { put(MediaColumns.IS_PENDING, 0) }, null, null)
        if (updated != 1) throw IOException("the row was not published")
        val row = query("${MediaColumns._ID} = ?", rowId.toString()).firstOrNull() ?: throw IOException("the row is gone")
        return Published(row.id, row.name ?: throw IOException("the row has no name"))
    }

    /**
     * Deletes [rowId] only when it is TakeTray's own row in exactly the
     * folder and, when [fileName] is given, has that name. True when the row
     * is gone afterwards (also when it already was); false when it is not
     * ours to delete or the delete removed nothing.
     */
    override fun deleteOwn(
        rowId: Long,
        folder: String,
        fileName: String?,
    ): Boolean {
        val row = query("${MediaColumns._ID} = ?", rowId.toString()).firstOrNull() ?: return true
        if (!isOurs(row, folder)) return false
        if (fileName != null && row.name != fileName) return false
        return resolver.delete(rowUri(rowId), pendingIncluded()) > 0
    }

    override fun ownRowsIn(folder: String): List<FolderRow> =
        query("${MediaColumns.RELATIVE_PATH} = ? COLLATE NOCASE", CopyFolderPath.relativePath(folder))
            .filter { isOurs(it, folder) }
            .map { FolderRow(it.id, it.name.orEmpty(), it.size, it.pending) }

    /**
     * Each delete itself also asks for IS_PENDING = 1, so a row published
     * between the listing and the delete stays.
     */
    override fun deletePendingIn(folder: String): Int {
        var deleted = 0
        for (row in ownRowsIn(folder)) {
            if (!row.pending) continue
            val args =
                pendingIncluded().apply {
                    putString(ContentResolver.QUERY_ARG_SQL_SELECTION, "${MediaColumns.IS_PENDING} = 1")
                }
            deleted += resolver.delete(rowUri(row.mediaStoreId), args)
        }
        return deleted
    }

    private fun isOurs(
        row: Row,
        folder: String,
    ): Boolean = CopyFolderPath.isInFolder(row.relativePath, folder) && CopyFolderPath.isOwn(row.owner, ownPackage)

    private fun pendingIncluded() = Bundle().apply { putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE) }

    private class Row(
        val id: Long,
        val name: String?,
        val relativePath: String?,
        val owner: String?,
        val size: Long,
        val pending: Boolean,
    )

    /** Rows of the primary volume's video collection, pending ones included. A null cursor is a failed read. */
    private fun query(
        selection: String,
        arg: String,
    ): List<Row> {
        val args =
            pendingIncluded().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, arrayOf(arg))
            }
        val projection =
            arrayOf(
                MediaColumns._ID,
                MediaColumns.DISPLAY_NAME,
                MediaColumns.RELATIVE_PATH,
                MediaColumns.OWNER_PACKAGE_NAME,
                MediaColumns.SIZE,
                MediaColumns.IS_PENDING,
            )
        val cursor = resolver.query(collection, projection, args, null) ?: throw IOException("MediaStore gave no cursor")
        return cursor.use { c ->
            val id = c.getColumnIndexOrThrow(MediaColumns._ID)
            val name = c.getColumnIndexOrThrow(MediaColumns.DISPLAY_NAME)
            val path = c.getColumnIndexOrThrow(MediaColumns.RELATIVE_PATH)
            val owner = c.getColumnIndexOrThrow(MediaColumns.OWNER_PACKAGE_NAME)
            val size = c.getColumnIndexOrThrow(MediaColumns.SIZE)
            val pending = c.getColumnIndexOrThrow(MediaColumns.IS_PENDING)
            buildList {
                while (c.moveToNext()) {
                    add(
                        Row(
                            id = c.getLong(id),
                            name = if (c.isNull(name)) null else c.getString(name),
                            relativePath = if (c.isNull(path)) null else c.getString(path),
                            owner = if (c.isNull(owner)) null else c.getString(owner),
                            size = if (c.isNull(size)) 0 else c.getLong(size),
                            pending = !c.isNull(pending) && c.getInt(pending) == 1,
                        ),
                    )
                }
            }
        }
    }
}
