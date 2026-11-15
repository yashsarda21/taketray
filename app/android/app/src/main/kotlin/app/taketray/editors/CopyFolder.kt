package app.taketray.editors

import android.content.ContentResolver
import android.content.ContentUris
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import android.util.Log
import java.io.IOException

/**
 * TakeTray's copy folders, `Movies/TakeTray/<folder>/` on the primary volume,
 * and **the guard** every delete goes through (D-121).
 *
 * A row is deleted only when [allowsDelete] says yes: its RELATIVE_PATH is
 * exactly `Movies/TakeTray/<folder>/` ([CopyFolderPath.isInFolder], any ASCII case, no Unicode lookalike,
 * never a deeper folder or `Movies/TakeTray Test/`), its DISPLAY_NAME is the
 * recorded file name (exactly), and its OWNER_PACKAGE_NAME is this app
 * ([CopyFolderPath.isOwn]; the release app and the debug app are different
 * owners). A wrong id from Dart, an id that MediaStore reused after a media
 * rebuild, or a row someone else made is **refused and never touched**. The
 * delete itself repeats the three facts as its selection, so a row that
 * changes between the check and the delete is not deleted either.
 *
 * Reads never turn a failure into "gone": a null cursor is an [IOException]
 * and any provider exception passes to the caller.
 *
 * Privacy: logs counts only, never a name, a folder, a path or a URI (D-10).
 * Every method does binder calls: call it off the main thread.
 */
class CopyFolder(
    private val resolver: ContentResolver,
    private val ourPackage: String,
    private val volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
) {
    private val collection: Uri = MediaStore.Video.Media.getContentUri(volume)

    /** One row as the guard sees it. */
    private class Row(
        val id: Long,
        val path: String?,
        val name: String?,
        val owner: String?,
        val size: Long,
    )

    /**
     * The ids of [refs] whose finished, untrashed row passes the guard now. A
     * reused id with another name, another owner or another folder is not
     * there. Throws when the read fails.
     */
    fun existingCopies(refs: List<CopyFileRefMsg>): Set<Long> {
        val rows = rowsById(refs.map { it.mediaStoreId }, includeHidden = false)
        return refs
            .filter { ref -> rows[ref.mediaStoreId]?.let { allows(it, ref) } == true }
            .mapTo(LinkedHashSet()) { it.mediaStoreId }
    }

    /**
     * Deletes each of [refs] whose row passes the guard. Pending and trashed
     * rows are looked at too: an own copy in the trash still takes space.
     * Each id ends in one list: deleted, gone (no row, or none left to delete
     * when the delete ran), refused (the guard said no; untouched) or failed
     * (the delete threw; the others go on). A failed read throws and deletes
     * nothing.
     */
    fun deleteCopies(refs: List<CopyFileRefMsg>): DeleteReportMsg {
        val rows = rowsById(refs.map { it.mediaStoreId }, includeHidden = true)
        val deleted = mutableListOf<Long>()
        val gone = mutableListOf<Long>()
        val refused = mutableListOf<Long>()
        val failed = mutableListOf<Long>()
        // One outcome per id: with two refs for one id the first one counts,
        // so an id is never in two lists (a second delete would say "gone").
        for (ref in refs.distinctBy { it.mediaStoreId }) {
            val id = ref.mediaStoreId
            val row = rows[id]
            when {
                row == null -> gone += id
                !allows(row, ref) -> refused += id
                else ->
                    try {
                        if (deleteExactly(row) > 0) deleted += id else gone += id
                    } catch (e: Exception) {
                        Log.w(TAG, "deleteCopies: a delete failed: ${e.javaClass.simpleName}")
                        failed += id
                    }
            }
        }
        Log.i(TAG, "deleteCopies: ${deleted.size} deleted, ${gone.size} gone, ${refused.size} refused, ${failed.size} failed")
        return DeleteReportMsg(deleted, gone, refused, failed)
    }

    /**
     * The distinct folder names directly under `Movies/TakeTray/` that hold any
     * row (pending and trashed ones too: their folder exists), from any owner,
     * sorted. A deeper folder counts for its first segment.
     */
    fun copyFolderNames(): List<String> {
        val names = sortedSetOf<String>()
        underRoot(includeHidden = true).forEach { row ->
            val segment = row.path?.let(::folderOf) ?: return@forEach
            names += segment.substringBefore('/')
        }
        return names.toList()
    }

    /**
     * Every finished file exactly one folder below `Movies/TakeTray/`, in id
     * order, with its size (0 when unknown) and whether TakeTray owns it.
     */
    fun filesInCopyFolders(): List<CopyFolderFileMsg> =
        underRoot(includeHidden = false).mapNotNull { row ->
            val folder = row.path?.let(::folderOf)?.removeSuffix("/") ?: return@mapNotNull null
            if (folder.isEmpty() || '/' in folder) return@mapNotNull null
            CopyFolderFileMsg(row.id, folder, row.name ?: "", row.size, CopyFolderPath.isOwn(row.owner, ourPackage))
        }

    /**
     * The item URIs of [refs] whose row is in its copy folder with its name,
     * whoever owns it: what Android's consent dialog may be asked to delete.
     * A row anywhere else is never in the list.
     */
    fun deletableUris(refs: List<CopyFileRefMsg>): List<Uri> {
        val rows = rowsById(refs.map { it.mediaStoreId }, includeHidden = false)
        return refs
            .filter { ref -> rows[ref.mediaStoreId]?.let { inPlace(it.path, it.name, ref) } == true }
            .map { ContentUris.withAppendedId(collection, it.mediaStoreId) }
            .distinct()
    }

    private fun allows(
        row: Row,
        ref: CopyFileRefMsg,
    ) = allowsDelete(row.path, row.name, row.owner, ref, ourPackage)

    /** Deletes [row] by id only while it still has the path, name and owner the guard saw. */
    private fun deleteExactly(row: Row): Int {
        val extras =
            Bundle().apply {
                putString(
                    ContentResolver.QUERY_ARG_SQL_SELECTION,
                    "${MediaColumns.RELATIVE_PATH} = ? AND ${MediaColumns.DISPLAY_NAME} = ? AND ${MediaColumns.OWNER_PACKAGE_NAME} = ?",
                )
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, arrayOf(row.path, row.name, row.owner))
                putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
            }
        return resolver.delete(ContentUris.withAppendedId(collection, row.id), extras)
    }

    /** The rows with these ids, by id; ids read in chunks. */
    private fun rowsById(
        ids: List<Long>,
        includeHidden: Boolean,
    ): Map<Long, Row> {
        val out = HashMap<Long, Row>()
        ids.distinct().chunked(MAX_IDS).forEach { chunk ->
            val selection = "${MediaColumns._ID} IN (${chunk.joinToString(",") { "?" }})"
            query(selection, chunk.map(Long::toString).toTypedArray(), includeHidden).forEach { out[it.id] = it }
        }
        return out
    }

    /** Rows whose RELATIVE_PATH starts with the root (LIKE ignores ASCII case); [folderOf] is the real check. */
    private fun underRoot(includeHidden: Boolean): List<Row> =
        query("${MediaColumns.RELATIVE_PATH} LIKE ?", arrayOf("${CopyFolderPath.ROOT}%"), includeHidden)

    private fun query(
        selection: String,
        args: Array<String>,
        includeHidden: Boolean,
    ): List<Row> {
        val queryArgs =
            Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaColumns._ID} ASC")
                val match = if (includeHidden) MediaStore.MATCH_INCLUDE else MediaStore.MATCH_EXCLUDE
                putInt(MediaStore.QUERY_ARG_MATCH_PENDING, match)
                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, match)
            }
        val cursor = resolver.query(collection, PROJECTION, queryArgs, null) ?: throw IOException("MediaStore gave no cursor")
        return cursor.use(::rowsOf)
    }

    private fun rowsOf(c: Cursor): List<Row> {
        val id = c.getColumnIndexOrThrow(MediaColumns._ID)
        val path = c.getColumnIndexOrThrow(MediaColumns.RELATIVE_PATH)
        val name = c.getColumnIndexOrThrow(MediaColumns.DISPLAY_NAME)
        val owner = c.getColumnIndexOrThrow(MediaColumns.OWNER_PACKAGE_NAME)
        val size = c.getColumnIndexOrThrow(MediaColumns.SIZE)
        return buildList {
            while (c.moveToNext()) {
                add(
                    Row(
                        id = c.getLong(id),
                        path = c.stringOrNull(path),
                        name = c.stringOrNull(name),
                        owner = c.stringOrNull(owner),
                        size = if (c.isNull(size)) 0 else c.getLong(size),
                    ),
                )
            }
        }
    }

    private fun Cursor.stringOrNull(i: Int): String? = if (isNull(i)) null else getString(i)

    companion object {
        private const val TAG = "TakeTrayCopyFolder"

        /** Ids per `IN (...)` query, as the media bridge reads them (VideoQueries.MAX_IDS). */
        private const val MAX_IDS = 500

        private val PROJECTION =
            arrayOf(
                MediaColumns._ID,
                MediaColumns.RELATIVE_PATH,
                MediaColumns.DISPLAY_NAME,
                MediaColumns.OWNER_PACKAGE_NAME,
                MediaColumns.SIZE,
            )

        /**
         * The guard: true only when the row is in `Movies/TakeTray/<ref.folderName>/`
         * with exactly `ref.fileName` and owned by [ourPackage]. A folder name that
         * is not one plain segment (empty, `.`, `..`, a `/` or a NUL) never
         * matches, so a deeper folder cannot be named through it.
         */
        fun allowsDelete(
            rowPath: String?,
            rowName: String?,
            rowOwner: String?,
            ref: CopyFileRefMsg,
            ourPackage: String,
        ): Boolean = inPlace(rowPath, rowName, ref) && CopyFolderPath.isOwn(rowOwner, ourPackage)

        /** In its copy folder with its name, whoever owns it. */
        private fun inPlace(
            rowPath: String?,
            rowName: String?,
            ref: CopyFileRefMsg,
        ): Boolean =
            plainSegment(ref.folderName) &&
                CopyFolderPath.isInFolder(rowPath, ref.folderName) &&
                rowName != null &&
                rowName == ref.fileName

        private fun plainSegment(folder: String): Boolean =
            folder.isNotEmpty() && folder != "." && folder != ".." && '/' !in folder && '\u0000' !in folder

        /** What follows the root in [path] (ignoring ASCII case), or null when [path] is not under it. */
        private fun folderOf(path: String): String? =
            if (CopyFolderPath.startsWithRoot(path)) {
                path.substring(CopyFolderPath.ROOT.length).takeIf { it.isNotEmpty() }
            } else {
                null
            }
    }
}
