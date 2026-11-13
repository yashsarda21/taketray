package app.taketray.editors

import android.content.ContentProvider
import android.content.ContentResolver
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
 * A small media table standing in for Android's media provider in the
 * [MediaStoreCopyStore] tests. Like the real one it records the inserting
 * package as a row's owner, hides IS_PENDING rows from a query unless it
 * asks for them, and keeps each row's bytes in a file. It answers only the
 * selections the store makes (`_id = ?`, `relative_path = ? COLLATE NOCASE`,
 * and `is_pending = 1` on a delete) and fails the test on any other.
 * [events] lists what was done: `insert <volume>`, `open <uri> <mode>`,
 * `update <id>`, `delete <id> <selection> <pending>`, `query <selection> <pending>`.
 */
class FakeCopyProvider : ContentProvider() {
    class Row(
        val id: Long,
        val volume: String,
        val values: ContentValues,
        val owner: String?,
        val file: File,
    ) {
        val path: String? get() = values.getAsString(MediaColumns.RELATIVE_PATH)
        val name: String? get() = values.getAsString(MediaColumns.DISPLAY_NAME)
        val pending: Boolean get() = values.getAsInteger(MediaColumns.IS_PENDING) == 1
    }

    override fun onCreate() = true

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri {
        val volume = uri.pathSegments[0]
        events += "insert $volume"
        return ContentUris.withAppendedId(uri, add(volume, values!!, callerPackage).id)
    }

    override fun openFile(
        uri: Uri,
        mode: String,
    ): ParcelFileDescriptor {
        events += "open $uri $mode"
        openError?.let { throw it }
        val row = rowFor(uri) ?: throw FileNotFoundException("no row")
        val flags =
            if (mode == "r") {
                ParcelFileDescriptor.MODE_READ_ONLY
            } else {
                ParcelFileDescriptor.MODE_WRITE_ONLY or ParcelFileDescriptor.MODE_CREATE or ParcelFileDescriptor.MODE_TRUNCATE
            }
        return ParcelFileDescriptor.open(row.file, flags)
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        events += "update ${ContentUris.parseId(uri)}"
        if (updateReturnsZero) return 0
        val row = rowFor(uri) ?: return 0
        row.values.putAll(values!!)
        if (values.getAsInteger(MediaColumns.IS_PENDING) == 0) renameOnPublish?.let { row.values.put(MediaColumns.DISPLAY_NAME, it) }
        return 1
    }

    override fun delete(
        uri: Uri,
        extras: Bundle?,
    ): Int {
        val selection = extras?.getString(ContentResolver.QUERY_ARG_SQL_SELECTION)
        val pending = extras?.getInt(MediaStore.QUERY_ARG_MATCH_PENDING) == MediaStore.MATCH_INCLUDE
        events += "delete ${ContentUris.parseId(uri)} $selection $pending"
        beforeDelete?.invoke()
        deleteError?.let { throw it }
        val row = rowFor(uri) ?: return 0
        when (selection) {
            null -> {}
            "${MediaColumns.IS_PENDING} = 1" -> if (!row.pending) return 0
            else -> throw AssertionError("unexpected delete selection: $selection")
        }
        if (row.pending && !pending) return 0
        rows.remove(row.id)
        return 1
    }

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw AssertionError("the store must delete with a Bundle")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = throw AssertionError("the store must query with a Bundle")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        queryArgs: Bundle?,
        cancellationSignal: CancellationSignal?,
    ): Cursor? {
        val selection = queryArgs!!.getString(ContentResolver.QUERY_ARG_SQL_SELECTION)
        val value = queryArgs.getStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS)!!.single()
        val includePending = queryArgs.getInt(MediaStore.QUERY_ARG_MATCH_PENDING) == MediaStore.MATCH_INCLUDE
        events += "query $selection $includePending"
        queryError?.let { throw it }
        if (queryReturnsNull) return null
        val volume = uri.pathSegments[0]
        val matching =
            when (selection) {
                "${MediaColumns._ID} = ?" -> rows.values.filter { it.id.toString() == value }
                "${MediaColumns.RELATIVE_PATH} = ? COLLATE NOCASE" -> rows.values.filter { queryIgnoresFolder || it.path.equals(value, ignoreCase = true) }
                else -> throw AssertionError("unexpected selection: $selection")
            }.filter { (includePending || !it.pending) && it.volume == volume }
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
                                MediaColumns.DISPLAY_NAME -> row.name
                                MediaColumns.IS_PENDING -> if (row.pending) 1 else 0
                                MediaColumns.SIZE -> if (sizeNull) null else row.file.length()
                                else -> throw AssertionError("unexpected column: $column")
                            }
                        }.toTypedArray(),
                )
            }
        }
    }

    override fun getType(uri: Uri): String? = null

    companion object {
        var callerPackage = "app.taketray.dev"
        val events = mutableListOf<String>()
        val rows = linkedMapOf<Long, Row>()
        var openError: Exception? = null
        var deleteError: Exception? = null
        var queryError: Exception? = null
        var queryReturnsNull = false
        var updateReturnsZero = false
        var sizeNull = false

        /** When true, the folder query returns every row of the volume (the store must check the folder itself). */
        var queryIgnoresFolder = false

        /** Runs as a delete arrives, before the row is looked at (to race a publish with it). */
        var beforeDelete: (() -> Unit)? = null

        /** The name MediaStore gives a row when it is published (null: it keeps its name). */
        var renameOnPublish: String? = null

        private var nextId = 100L

        private fun rowFor(uri: Uri): Row? = rows[ContentUris.parseId(uri)]?.takeIf { it.volume == uri.pathSegments[0] }

        /** Adds a row on [volume] as if [owner] had made it, holding [bytes]. */
        fun add(
            volume: String,
            values: ContentValues,
            owner: String?,
            bytes: ByteArray = ByteArray(0),
        ): Row {
            val id = nextId++
            val file = File.createTempFile("p8-task5-copy-$id", ".mp4").apply { deleteOnExit() }
            file.writeBytes(bytes)
            return Row(id, volume, ContentValues(values), owner, file).also { rows[id] = it }
        }

        fun add(
            path: String,
            name: String,
            pending: Boolean,
            owner: String? = callerPackage,
            volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
            bytes: ByteArray = ByteArray(0),
        ): Row =
            add(
                volume,
                ContentValues().apply {
                    put(MediaColumns.RELATIVE_PATH, path)
                    put(MediaColumns.DISPLAY_NAME, name)
                    put(MediaColumns.IS_PENDING, if (pending) 1 else 0)
                },
                owner,
                bytes,
            )

        fun install(callerPackage: String = "app.taketray.dev") {
            this.callerPackage = callerPackage
            events.clear()
            rows.clear()
            openError = null
            deleteError = null
            queryError = null
            queryReturnsNull = false
            updateReturnsZero = false
            sizeNull = false
            queryIgnoresFolder = false
            beforeDelete = null
            renameOnPublish = null
            Robolectric.setupContentProvider(FakeCopyProvider::class.java, MediaStore.AUTHORITY)
        }
    }
}
