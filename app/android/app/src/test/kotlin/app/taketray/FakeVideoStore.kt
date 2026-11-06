package app.taketray

import android.content.ContentProvider
import android.content.ContentUris
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import java.io.File
import java.io.FileNotFoundException
import org.robolectric.Robolectric

/**
 * A small in-memory video table standing in for Android's media provider in the
 * [TestMedia] tests. It answers only the selections TestMedia makes
 * (`_id = ?`, `relative_path = ?` and `relative_path = ? COLLATE NOCASE`) and fails the test on any other; like the
 * real provider it hides IS_PENDING rows unless the query asks to include them,
 * and it records the owner of an inserted row as [callerPackage] (the real one
 * does the same). [events] lists what was done, in order, for example
 * `insert`, `write`, `update`, `delete`.
 */
class FakeVideoStore : ContentProvider() {
    /** One row. [values] holds DISPLAY_NAME, RELATIVE_PATH, IS_PENDING and so on. */
    class Row(
        val id: Long,
        val values: ContentValues,
        val owner: String?,
        val file: File,
    ) {
        val path: String? get() = values.getAsString(MediaColumns.RELATIVE_PATH)
        val pending: Boolean get() = values.getAsInteger(MediaColumns.IS_PENDING) == 1
    }

    override fun onCreate() = true

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri? {
        events += "insert"
        insertError?.let { throw it }
        if (insertReturnsNull) return null
        return ContentUris.withAppendedId(uri, add(values!!, callerPackage).id)
    }

    override fun openFile(
        uri: Uri,
        mode: String,
    ): ParcelFileDescriptor {
        events += "write"
        writeError?.let { throw it }
        val row = rows[ContentUris.parseId(uri)] ?: throw FileNotFoundException("no row")
        pendingAtWrite = row.pending
        return ParcelFileDescriptor.open(
            row.file,
            ParcelFileDescriptor.MODE_WRITE_ONLY or ParcelFileDescriptor.MODE_CREATE or ParcelFileDescriptor.MODE_TRUNCATE,
        )
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        events += "update"
        val row = rows[ContentUris.parseId(uri)] ?: return 0
        row.values.putAll(values!!)
        return 1
    }

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        events += "delete"
        return if (rows.remove(ContentUris.parseId(uri)) != null) 1 else 0
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = throw AssertionError("TestMedia must query with a Bundle")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        queryArgs: Bundle?,
        cancellationSignal: CancellationSignal?,
    ): Cursor {
        events += "query"
        val selection = queryArgs!!.getString(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION)
        val value = queryArgs.getStringArray(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS)!!.single()
        val includePending = queryArgs.getInt(MediaStore.QUERY_ARG_MATCH_PENDING) == MediaStore.MATCH_INCLUDE
        val matching =
            when (selection) {
                "${MediaColumns._ID} = ?" -> rows.values.filter { it.id.toString() == value }
                "${MediaColumns.RELATIVE_PATH} = ?" -> rows.values.filter { it.path == value }
                "${MediaColumns.RELATIVE_PATH} = ? COLLATE NOCASE" -> rows.values.filter { it.path.equals(value, ignoreCase = true) }
                else -> throw AssertionError("unexpected selection: $selection")
            }.filter { includePending || !it.pending }
        val columns = projection!!.toList()
        return MatrixCursor(projection).also { cursor ->
            for (row in matching) {
                cursor.addRow(
                    columns
                        .map<String, Any?> { column ->
                            when (column) {
                                MediaColumns._ID -> row.id
                                MediaColumns.RELATIVE_PATH -> row.path
                                MediaColumns.OWNER_PACKAGE_NAME -> row.owner
                                else -> throw AssertionError("unexpected column: $column")
                            }
                        }.toTypedArray(),
                )
            }
        }
    }

    override fun getType(uri: Uri): String? = null

    companion object {
        /** The package the provider records as the owner of an inserted row. */
        var callerPackage = "app.taketray.dev"

        /** What was done since [install], in order. */
        val events = mutableListOf<String>()

        /** The rows, by id. */
        val rows = linkedMapOf<Long, Row>()

        /** When set, [insert] throws it. */
        var insertError: Exception? = null

        /** When true, [insert] gives no Uri (as when the provider refuses). */
        var insertReturnsNull = false

        /** Whether the row was still pending when its file was opened for writing (null: never opened). */
        var pendingAtWrite: Boolean? = null

        /** When set, opening the file for writing throws it. */
        var writeError: Exception? = null

        private var nextId = 100L

        /** Adds a row as if [owner] had made it. */
        fun add(
            values: ContentValues,
            owner: String?,
        ): Row {
            val id = nextId++
            val file = File.createTempFile("fake-video-$id", ".mp4").apply { deleteOnExit() }
            return Row(id, ContentValues(values), owner, file).also { rows[id] = it }
        }

        /** Registers a fresh provider for the media authority and clears the table and the recordings. */
        fun install(callerPackage: String = "app.taketray.dev") {
            this.callerPackage = callerPackage
            events.clear()
            rows.clear()
            insertError = null
            insertReturnsNull = false
            writeError = null
            pendingAtWrite = null
            Robolectric.setupContentProvider(FakeVideoStore::class.java, MediaStore.AUTHORITY)
        }
    }
}
