package app.taketray.background

import android.content.ContentProvider
import android.content.ContentResolver
import android.content.ContentValues
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteQueryBuilder
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import org.robolectric.Robolectric

/**
 * Android's video table, small, in a real SQLite database, for the new-clips
 * count. Each query runs its Bundle selection through a strict query builder
 * set up as MediaProvider sets one up for other apps (strict, strict columns,
 * strict grammar), so SQL Android would refuse fails here too. Like the real
 * provider it leaves out pending rows unless the query asks for them
 * (QUERY_ARG_MATCH_PENDING, MATCH_EXCLUDE by default) and trashed rows unless
 * asked (QUERY_ARG_MATCH_TRASHED), and answers only for the volume in the
 * URI. [queries] records the volume of every query; [failure], when set, is
 * thrown by the next queries.
 */
class SqlVideoProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = throw AssertionError("the job must query with a Bundle")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        queryArgs: Bundle?,
        cancellationSignal: CancellationSignal?,
    ): Cursor? {
        val volume = uri.pathSegments.first()
        queries += volume
        failure?.let { throw it }
        val onlyPending = queryArgs?.getInt(MediaStore.QUERY_ARG_MATCH_PENDING) == MediaStore.MATCH_ONLY
        if (onlyPending) {
            pendingQueries++
            pendingFailure?.let { throw it }
            if (pendingNoCursor) return null
        }
        if (noCursor) return null
        val args = queryArgs ?: Bundle()
        val selection = args.getString(ContentResolver.QUERY_ARG_SQL_SELECTION)
        val selectionArgs = args.getStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS)
        val order = args.getString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER)
        val qb =
            SQLiteQueryBuilder().apply {
                tables = TABLE
                isStrict = true
                isStrictColumns = true
                isStrictGrammar = true
                projectionMap = COLUMNS.associateWith { it }
                appendWhere("volume = ")
                appendWhereEscapeString(volume)
                when (args.getInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_EXCLUDE)) {
                    MediaStore.MATCH_EXCLUDE -> appendWhere(" AND ${MediaColumns.IS_PENDING} = 0")
                    MediaStore.MATCH_ONLY -> appendWhere(" AND ${MediaColumns.IS_PENDING} = 1")
                }
                if (args.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE) == MediaStore.MATCH_EXCLUDE) {
                    appendWhere(" AND ${MediaColumns.IS_TRASHED} = 0")
                }
            }
        return qb.query(db, projection?.let { arrayOf(*it) }, selection, selectionArgs?.let { arrayOf(*it) }, null, null, order)
    }

    override fun getType(uri: Uri): String? = null

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri? = null

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0

    companion object {
        private const val TABLE = "video"
        private val COLUMNS =
            listOf(
                MediaColumns._ID,
                MediaColumns.GENERATION_ADDED,
                MediaColumns.RELATIVE_PATH,
                MediaColumns.DURATION,
                MediaColumns.SIZE,
                MediaColumns.DATE_TAKEN,
                MediaColumns.DATE_ADDED,
                MediaColumns.IS_PENDING,
                MediaColumns.IS_TRASHED,
                "volume",
                MediaColumns.DATE_MODIFIED,
            )

        private lateinit var db: SQLiteDatabase

        /** The volume of every query since [install], in order. */
        val queries = mutableListOf<String>()

        /** Thrown by every query while set. */
        var failure: Exception? = null

        /** Thrown by the queries for pending rows only (the recording check), while set. */
        var pendingFailure: Exception? = null

        /** While true, the queries for pending rows only give no cursor. */
        var pendingNoCursor = false

        /** How many queries for pending rows only ran since [install]. */
        var pendingQueries = 0

        /** While true, every query gives no cursor (the provider unavailable). */
        var noCursor = false

        /** A fresh, empty table registered for the media authority. */
        fun install() {
            db = SQLiteDatabase.create(null)
            db.execSQL(
                "CREATE TABLE $TABLE (${MediaColumns._ID} INTEGER, ${MediaColumns.GENERATION_ADDED} INTEGER, " +
                    "${MediaColumns.RELATIVE_PATH} TEXT, ${MediaColumns.DURATION} INTEGER, ${MediaColumns.SIZE} INTEGER, " +
                    "${MediaColumns.DATE_TAKEN} INTEGER, ${MediaColumns.DATE_ADDED} INTEGER, " +
                    "${MediaColumns.IS_PENDING} INTEGER, ${MediaColumns.IS_TRASHED} INTEGER, volume TEXT, " +
                    "${MediaColumns.DATE_MODIFIED} INTEGER)",
            )
            queries.clear()
            failure = null
            noCursor = false
            pendingFailure = null
            pendingNoCursor = false
            pendingQueries = 0
            Robolectric.setupContentProvider(SqlVideoProvider::class.java, MediaStore.AUTHORITY)
        }

        /** Adds one video row; the defaults make a finished, non-empty clip in DCIM/Camera/ on the main volume. */
        /** The camera finishes the recording: not pending any more, with a length and a size, modified at [modified] (seconds). */
        fun finish(
            id: Long,
            modified: Long?,
        ) {
            db.execSQL(
                "UPDATE $TABLE SET ${MediaColumns.IS_PENDING} = 0, ${MediaColumns.DURATION} = 12000, ${MediaColumns.SIZE} = 5000000, " +
                    "${MediaColumns.DATE_MODIFIED} = ? WHERE ${MediaColumns._ID} = ?",
                arrayOf<Any?>(modified, id),
            )
        }

        /** The row goes to the trash (a deleted take). */
        fun trash(id: Long) {
            db.execSQL("UPDATE $TABLE SET ${MediaColumns.IS_TRASHED} = 1 WHERE ${MediaColumns._ID} = ?", arrayOf<Any?>(id))
        }

        fun add(
            id: Long,
            generation: Long,
            path: String? = "DCIM/Camera/",
            duration: Long? = 12_000,
            size: Long? = 5_000_000,
            taken: Long? = null,
            added: Long? = 1_780_000_000,
            pending: Boolean = false,
            trashed: Boolean = false,
            volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
            modified: Long? = null,
        ) {
            db.execSQL(
                "INSERT INTO $TABLE VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                arrayOf<Any?>(id, generation, path, duration, size, taken, added, if (pending) 1 else 0, if (trashed) 1 else 0, volume, modified),
            )
        }
    }
}
