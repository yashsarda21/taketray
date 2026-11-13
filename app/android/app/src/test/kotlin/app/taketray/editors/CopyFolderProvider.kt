package app.taketray.editors

import android.app.PendingIntent
import android.content.ClipData
import android.content.ContentProvider
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteQueryBuilder
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Looper
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import org.robolectric.Robolectric

/**
 * Android's video table, small, in a real SQLite database, for the copy
 * folder tests. Queries and deletes run through a strict query builder set up
 * as MediaProvider sets one up for other apps (strict, strict columns, strict
 * grammar), so SQL Android would refuse fails here too. Like the real
 * provider it leaves out pending and trashed rows unless the call asks for
 * them, and answers only for the volume in the URI.
 *
 * It records every query and delete (with whether it ran on the main
 * thread), and answers `MediaStore.createDeleteRequest` (the provider's
 * `create_delete_request` call) with a PendingIntent, recording the URIs.
 * Hooks: [queryFailure], [noCursor], [deleteFailure] (by id),
 * [beforeDelete] (runs just before a delete, to change the row under it).
 */
class CopyFolderProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = throw AssertionError("the copy folder must query with a Bundle")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        queryArgs: Bundle?,
        cancellationSignal: CancellationSignal?,
    ): Cursor? {
        queries += Call(uri, onMain(), queryArgs?.let { Bundle(it) })
        queryFailure?.let { throw it }
        if (noCursor) return null
        val args = queryArgs ?: Bundle()
        val qb = builder(uri.pathSegments.first(), args)
        return qb.query(
            db,
            projection?.let { arrayOf(*it) },
            args.getString(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION),
            args.getStringArray(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS)?.let { arrayOf(*it) },
            null,
            null,
            args.getString(android.content.ContentResolver.QUERY_ARG_SQL_SORT_ORDER),
        )
    }

    override fun delete(
        uri: Uri,
        extras: Bundle?,
    ): Int {
        val id = ContentUris.parseId(uri)
        deletes += Call(uri, onMain(), extras?.let { Bundle(it) })
        beforeDelete?.invoke(id)
        deleteFailure[id]?.let { throw it }
        val args = extras ?: Bundle()
        val qb = builder(uri.pathSegments.first(), args)
        qb.appendWhere(" AND ${MediaColumns._ID} = $id")
        return qb.delete(
            db,
            args.getString(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION),
            args.getStringArray(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS)?.let { arrayOf(*it) },
        )
    }

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw AssertionError("the copy folder must delete with a Bundle")

    @Suppress("DEPRECATION")
    override fun call(
        authority: String,
        method: String,
        arg: String?,
        extras: Bundle?,
    ): Bundle? {
        if (method != "create_delete_request") throw AssertionError("unexpected call: $method")
        val uris = mutableListOf<Uri>()
        extras?.getParcelable<ClipData>("clip_data")?.let { clip ->
            for (i in 0 until clip.itemCount) uris += clip.getItemAt(i).uri
        }
        extras?.getParcelableArrayList<Uri>("uris")?.let { uris += it }
        deleteRequests += listOf(uris.toList())
        deleteRequestFailure?.let { throw it }
        val pending = PendingIntent.getActivity(context, 0, Intent("p8.delete.request"), PendingIntent.FLAG_IMMUTABLE)
        return Bundle().apply { putParcelable("result", pending) }
    }

    override fun getType(uri: Uri): String? = null

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri? = throw AssertionError("the copy folder never inserts")

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw AssertionError("the copy folder never updates")

    private fun onMain() = Looper.getMainLooper().isCurrentThread

    private fun builder(
        volume: String,
        args: Bundle,
    ) = SQLiteQueryBuilder().apply {
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
        when (args.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)) {
            MediaStore.MATCH_EXCLUDE -> appendWhere(" AND ${MediaColumns.IS_TRASHED} = 0")
            MediaStore.MATCH_ONLY -> appendWhere(" AND ${MediaColumns.IS_TRASHED} = 1")
        }
    }

    /** One recorded query or delete: its URI, whether it ran on the main thread, and a copy of its arguments. */
    data class Call(
        val uri: Uri,
        val onMain: Boolean,
        val args: Bundle?,
    )

    companion object {
        private const val TABLE = "video"
        private val COLUMNS =
            listOf(
                MediaColumns._ID,
                MediaColumns.RELATIVE_PATH,
                MediaColumns.DISPLAY_NAME,
                MediaColumns.OWNER_PACKAGE_NAME,
                MediaColumns.SIZE,
                MediaColumns.IS_PENDING,
                MediaColumns.IS_TRASHED,
                "volume",
            )

        private lateinit var db: SQLiteDatabase

        val queries = mutableListOf<Call>()
        val deletes = mutableListOf<Call>()

        /** The URI list of every `createDeleteRequest`, in order. */
        val deleteRequests = mutableListOf<List<Uri>>()

        var queryFailure: Exception? = null
        var noCursor = false
        val deleteFailure = mutableMapOf<Long, Exception>()
        var beforeDelete: ((Long) -> Unit)? = null
        var deleteRequestFailure: Exception? = null

        /** A fresh, empty table registered for the media authority. */
        fun install() {
            db = SQLiteDatabase.create(null)
            db.execSQL(
                "CREATE TABLE $TABLE (${MediaColumns._ID} INTEGER PRIMARY KEY, ${MediaColumns.RELATIVE_PATH} TEXT, " +
                    "${MediaColumns.DISPLAY_NAME} TEXT, ${MediaColumns.OWNER_PACKAGE_NAME} TEXT, ${MediaColumns.SIZE} INTEGER, " +
                    "${MediaColumns.IS_PENDING} INTEGER, ${MediaColumns.IS_TRASHED} INTEGER, volume TEXT)",
            )
            queries.clear()
            deletes.clear()
            deleteRequests.clear()
            queryFailure = null
            noCursor = false
            deleteFailure.clear()
            beforeDelete = null
            deleteRequestFailure = null
            Robolectric.setupContentProvider(CopyFolderProvider::class.java, MediaStore.AUTHORITY)
        }

        /** Adds one row; the defaults make a finished copy of [owner] on the primary volume. */
        fun add(
            id: Long,
            path: String?,
            name: String?,
            owner: String?,
            size: Long? = 1_000_000,
            pending: Boolean = false,
            trashed: Boolean = false,
            volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
        ) {
            db.execSQL(
                "INSERT INTO $TABLE VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                arrayOf<Any?>(id, path, name, owner, size, if (pending) 1 else 0, if (trashed) 1 else 0, volume),
            )
        }

        /** Changes a row's name in place (MediaStore renaming it, or an id reused). */
        fun rename(
            id: Long,
            name: String,
        ) {
            db.execSQL("UPDATE $TABLE SET ${MediaColumns.DISPLAY_NAME} = ? WHERE ${MediaColumns._ID} = ?", arrayOf<Any?>(name, id))
        }

        fun remove(id: Long) {
            db.execSQL("DELETE FROM $TABLE WHERE ${MediaColumns._ID} = ?", arrayOf<Any?>(id))
        }

        /** The ids still in the table, in order. */
        fun ids(): List<Long> =
            db.rawQuery("SELECT ${MediaColumns._ID} FROM $TABLE ORDER BY ${MediaColumns._ID}", null).use { c ->
                buildList { while (c.moveToNext()) add(c.getLong(0)) }
            }
    }
}
