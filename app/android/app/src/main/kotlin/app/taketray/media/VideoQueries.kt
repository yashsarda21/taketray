package app.taketray.media

import android.content.ContentResolver
import android.database.Cursor
import android.os.Bundle
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns

/**
 * The MediaStore video queries: selections, query arguments and the mapping
 * of one cursor row. Decides nothing about what a row means to TakeTray (D-66);
 * it only has to pick exactly the rows the contract in pigeons/media_api.dart
 * describes, the same rows FakeMediaBridge picks in the Dart tests.
 */
object VideoQueries {
    /** The columns every video query reads; [rowFrom] reads them by name. */
    val PROJECTION: Array<String> =
        arrayOf(
            MediaColumns._ID,
            MediaColumns.GENERATION_ADDED,
            MediaColumns.SIZE,
            MediaColumns.DURATION,
            MediaColumns.DATE_TAKEN,
            MediaColumns.DATE_ADDED,
            MediaColumns.DATE_MODIFIED,
            MediaColumns.DISPLAY_NAME,
            MediaColumns.RELATIVE_PATH,
            MediaColumns.WIDTH,
            MediaColumns.HEIGHT,
            MediaColumns.MIME_TYPE,
            MediaColumns.IS_PENDING,
        )

    /** The most ids one `_ID IN (...)` selection takes; longer lists are chunked. */
    const val MAX_IDS = 500

    private const val ADDED_ORDER = "${MediaColumns.GENERATION_ADDED} ASC, ${MediaColumns._ID} ASC"
    private const val ID_ORDER = "${MediaColumns._ID} ASC"
    private const val NEWEST_ORDER = "${MediaColumns.GENERATION_ADDED} DESC, ${MediaColumns._ID} DESC"

    /** The columns the new-clips count reads (D-104). */
    val NEW_CLIPS_PROJECTION: Array<String> =
        arrayOf(
            MediaColumns._ID,
            MediaColumns.GENERATION_ADDED,
            MediaColumns.DATE_TAKEN,
            MediaColumns.DATE_ADDED,
            MediaColumns.DATE_MODIFIED,
        )

    /**
     * A requested folder as MediaStore stores RELATIVE_PATH: no leading '/',
     * exactly one trailing '/'. The stored path is compared as it is.
     */
    fun normaliseFolder(folder: String): String = folder.trim('/') + "/"

    /**
     * "In one of [folders]": exact folder, ignoring case of A to Z only
     * (SQLite's COLLATE NOCASE). No folders is `0`, which matches nothing:
     * never invalid SQL, never every row.
     */
    private fun folderClause(folders: List<String>): Pair<String, List<String>> =
        if (folders.isEmpty()) {
            "0" to emptyList()
        } else {
            folders.joinToString(" OR ", "(", ")") { "${MediaColumns.RELATIVE_PATH} = ? COLLATE NOCASE" } to
                folders.map(::normaliseFolder)
        }

    /** GENERATION_ADDED > [afterGeneration], in one of [folders]. */
    fun addedAfterSelection(
        afterGeneration: Long,
        folders: List<String>,
    ): Pair<String, Array<String>> {
        val (clause, folderArgs) = folderClause(folders)
        return "${MediaColumns.GENERATION_ADDED} > ? AND $clause" to
            (listOf(afterGeneration.toString()) + folderArgs).toTypedArray()
    }

    /**
     * In one of [folders], and DATE_TAKEN (ms) >= [sinceMs], or DATE_ADDED or
     * DATE_MODIFIED (seconds) >= [sinceMs] / 1000 rounded down, or no
     * DATE_ADDED at all: a superset that Dart narrows.
     */
    fun shotSinceSelection(
        folders: List<String>,
        sinceMs: Long,
    ): Pair<String, Array<String>> {
        val (clause, folderArgs) = folderClause(folders)
        val sinceSec = Math.floorDiv(sinceMs, 1000L)
        val selection =
            "$clause AND (${MediaColumns.DATE_TAKEN} >= ? OR ${MediaColumns.DATE_ADDED} >= ? OR " +
                "${MediaColumns.DATE_MODIFIED} >= ? OR ${MediaColumns.DATE_ADDED} IS NULL)"
        return selection to (folderArgs + listOf(sinceMs.toString(), sinceSec.toString(), sinceSec.toString())).toTypedArray()
    }

    /** `_ID IN (?,...)` for 1 to [MAX_IDS] ids. */
    fun idsSelection(ids: List<Long>): Pair<String, Array<String>> {
        require(ids.size in 1..MAX_IDS) { "idsSelection takes 1 to $MAX_IDS ids, got ${ids.size}" }
        return "${MediaColumns._ID} IN (${ids.joinToString(",") { "?" }})" to
            ids.map { it.toString() }.toTypedArray()
    }

    /** Pending rows included (a video still being recorded), oldest generation first, at most [limit]. */
    fun addedAfterArgs(
        afterGeneration: Long,
        folders: List<String>,
        limit: Long,
    ): Bundle =
        args(addedAfterSelection(afterGeneration, folders), MediaStore.MATCH_INCLUDE, ADDED_ORDER).apply {
            putInt(ContentResolver.QUERY_ARG_LIMIT, limit.coerceIn(0, Int.MAX_VALUE.toLong()).toInt())
        }

    /**
     * The new-clips count (D-104): GENERATION_ADDED > [afterGeneration], in
     * one of [folders], with a positive DURATION and SIZE. A row still being
     * written has neither yet (and is pending; [newClipsArgs] leaves those
     * out too); NULL > 0 is not true, so a missing value never counts.
     */
    fun newClipsSelection(
        afterGeneration: Long,
        folders: List<String>,
    ): Pair<String, Array<String>> {
        val (selection, args) = addedAfterSelection(afterGeneration, folders)
        return "$selection AND ${MediaColumns.DURATION} > 0 AND ${MediaColumns.SIZE} > 0" to args
    }

    /**
     * A recording in progress (D-110): a pending row above [afterGeneration] in
     * one of [folders] with a DATE_ADDED or DATE_MODIFIED (seconds) from
     * [sinceSec] to [untilSec]: a crashed recording's stuck row older than
     * that stops counting, and so does a time in the future (the clock was set
     * back; a time beyond [untilSec] is not a time). Only pending rows
     * (trashed ones left out), one is enough.
     */
    fun recordingArgs(
        afterGeneration: Long,
        folders: List<String>,
        sinceSec: Long,
        untilSec: Long,
    ): Bundle {
        val (selection, selectionArgs) = addedAfterSelection(afterGeneration, folders)
        val added = "${MediaColumns.DATE_ADDED} BETWEEN ? AND ?"
        val modified = "${MediaColumns.DATE_MODIFIED} BETWEEN ? AND ?"
        val recent = "($added OR $modified)"
        return args(
            "$selection AND $recent" to selectionArgs + listOf(sinceSec, untilSec, sinceSec, untilSec).map { it.toString() },
            MediaStore.MATCH_ONLY,
            NEWEST_ORDER,
        ).apply { putInt(ContentResolver.QUERY_ARG_LIMIT, 1) }
    }

    /** Pending and trashed rows left out, newest generation first, no limit. */
    fun newClipsArgs(
        afterGeneration: Long,
        folders: List<String>,
    ): Bundle = args(newClipsSelection(afterGeneration, folders), MediaStore.MATCH_EXCLUDE, NEWEST_ORDER)

    /** Pending rows left out. */
    fun shotSinceArgs(
        folders: List<String>,
        sinceMs: Long,
    ): Bundle = args(shotSinceSelection(folders, sinceMs), MediaStore.MATCH_EXCLUDE, ID_ORDER)

    /** Every finished video on the volume: pending rows left out. */
    fun allVideosArgs(): Bundle = args(null, MediaStore.MATCH_EXCLUDE, ID_ORDER)

    /** Any row with one of the ids, pending included: a row that exists is never reported gone. */
    fun idsArgs(ids: List<Long>): Bundle = args(idsSelection(ids), MediaStore.MATCH_INCLUDE, ID_ORDER)

    /** Trashed rows are always left out. */
    private fun args(
        selection: Pair<String, Array<String>>?,
        matchPending: Int,
        order: String,
    ): Bundle =
        Bundle().apply {
            if (selection != null) {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection.first)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, selection.second)
            }
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, order)
            putInt(MediaStore.QUERY_ARG_MATCH_PENDING, matchPending)
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
        }

    /**
     * The current row as a message. Null SIZE becomes 0 and null DISPLAY_NAME
     * or RELATIVE_PATH becomes "" (the contract keeps them non-null; a 0 size
     * never matches a fingerprint). Null DURATION, DATE_TAKEN, DATE_ADDED,
     * DATE_MODIFIED, WIDTH, HEIGHT and MIME_TYPE stay null. IS_PENDING 1 is true.
     */
    fun rowFrom(
        cursor: Cursor,
        volumeName: String,
    ): VideoRowMsg {
        fun long(column: String): Long? {
            val i = cursor.getColumnIndexOrThrow(column)
            return if (cursor.isNull(i)) null else cursor.getLong(i)
        }

        fun string(column: String): String? {
            val i = cursor.getColumnIndexOrThrow(column)
            return if (cursor.isNull(i)) null else cursor.getString(i)
        }

        return VideoRowMsg(
            volumeName = volumeName,
            mediaStoreId = long(MediaColumns._ID) ?: 0,
            generationAdded = long(MediaColumns.GENERATION_ADDED) ?: 0,
            sizeBytes = long(MediaColumns.SIZE) ?: 0,
            durationMs = long(MediaColumns.DURATION),
            dateTakenMs = long(MediaColumns.DATE_TAKEN),
            dateAddedSec = long(MediaColumns.DATE_ADDED),
            dateModifiedSec = long(MediaColumns.DATE_MODIFIED),
            displayName = string(MediaColumns.DISPLAY_NAME) ?: "",
            relativePath = string(MediaColumns.RELATIVE_PATH) ?: "",
            width = long(MediaColumns.WIDTH),
            height = long(MediaColumns.HEIGHT),
            mimeType = string(MediaColumns.MIME_TYPE),
            isPending = long(MediaColumns.IS_PENDING) == 1L,
        )
    }
}
