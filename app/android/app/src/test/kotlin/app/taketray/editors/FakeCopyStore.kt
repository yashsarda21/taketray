package app.taketray.editors

import android.system.ErrnoException
import android.system.OsConstants
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/**
 * A [CopyStore] in memory, for the loop and engine tests. Every call is
 * logged in [events] (`space`, `insert <name>`, `open <clipKey>`,
 * `target <id>`, `publish <id>`, `delete <id>`), so a test can say what was
 * done and in which order. Rows are kept by id; sources by [key].
 *
 * Synchronised: the worker thread and the test thread both touch it.
 */
class FakeCopyStore(
    private val ownPackage: String = "app.taketray.dev",
) : CopyStore {
    class Row(
        val id: Long,
        val folder: String,
        var name: String,
        var pending: Boolean,
        val owner: String,
    ) {
        val bytes = ByteArrayOutputStream()
    }

    /**
     * One original. [length] is what opening it reports (its own size);
     * [failReadAt] makes a read throw once that many bytes were read (the
     * file deleted or the card pulled mid-copy); [onRead] runs before every
     * read with the bytes read so far, or -1 at the end.
     */
    class Source(
        val bytes: ByteArray,
        val length: Long = bytes.size.toLong(),
        val openError: Exception? = null,
        val failReadAt: Long? = null,
        val onRead: ((Long) -> Unit)? = null,
    )

    val events = mutableListOf<String>()
    val rows = linkedMapOf<Long, Row>()
    val sources = mutableMapOf<String, Source>()

    /** Free bytes; asked before every file. */
    var available: () -> Long = { Long.MAX_VALUE / 2 }

    /** When set, writing a target throws it once this many bytes are in the row. */
    var writeErrorAt: Pair<Long, IOException>? = null

    /**
     * When set, closing a target throws it once (then clears it), after the
     * bytes are in the row: a full disk or write error that shows only at
     * `close()`, as on a FUSE-backed file.
     */
    @Volatile var closeError: IOException? = null

    var insertError: Exception? = null
    var publishError: Exception? = null
    var targetError: Exception? = null

    /** Row ids whose delete fails (returns false). */
    val undeletable = mutableSetOf<Long>()

    /** When set, deletePendingIn waits for it (to race it with a start). */
    var deletePendingGate: java.util.concurrent.CountDownLatch? = null

    /** Set when deletePendingIn has started. */
    val deletePendingEntered = java.util.concurrent.CountDownLatch(1)

    private var nextId = 100L

    fun key(source: CopySource): String = source.pickerUri ?: "${source.volumeName}:${source.mediaStoreId}"

    @Synchronized
    fun addRow(
        folder: String,
        name: String,
        pending: Boolean,
        owner: String = ownPackage,
    ): Row = Row(nextId++, folder, name, pending, owner).also { rows[it.id] = it }

    @Synchronized
    fun log(): List<String> = events.toList()

    @Synchronized
    fun rowsNow(): List<Row> = rows.values.toList()

    @Synchronized
    override fun availableBytes(): Long {
        events += "space"
        return available()
    }

    @Synchronized
    override fun insertPending(
        folder: String,
        fileName: String,
    ): Long {
        events += "insert $fileName"
        insertError?.let { throw it }
        // MediaStore's own rename on a clash: "x.mp4" becomes "x (1).mp4".
        var name = fileName
        var n = 1
        while (rows.values.any { it.folder.equals(folder, true) && it.name.equals(name, true) }) {
            val dot = fileName.lastIndexOf('.')
            name = "${fileName.substring(0, dot)} ($n)${fileName.substring(dot)}"
            n++
        }
        return addRow(folder, name, pending = true).id
    }

    override fun openSource(source: CopySource): SourceFile {
        val k = key(source)
        val s =
            synchronized(this) {
                events += "open $k"
                sources[k]
            } ?: throw FileNotFoundException("no source")
        s.openError?.let { throw it }
        val input =
            object : InputStream() {
                var pos = 0L

                override fun read(): Int = throw AssertionError("the loop reads in chunks")

                override fun read(
                    b: ByteArray,
                    off: Int,
                    len: Int,
                ): Int {
                    val atEnd = pos >= s.bytes.size
                    s.onRead?.invoke(if (atEnd) -1 else pos)
                    s.failReadAt?.let { if (pos >= it) throw IOException("gone") }
                    if (atEnd) return -1
                    var n = minOf(len.toLong(), s.bytes.size - pos).toInt()
                    s.failReadAt?.let { n = minOf(n.toLong(), it - pos).toInt().coerceAtLeast(1) }
                    System.arraycopy(s.bytes, pos.toInt(), b, off, n)
                    pos += n
                    return n
                }
            }
        return SourceFile(input, s.length)
    }

    @Synchronized
    override fun openTarget(rowId: Long): OutputStream {
        events += "target $rowId"
        targetError?.let { throw it }
        val row = rows[rowId] ?: throw FileNotFoundException("no row")
        return object : OutputStream() {
            override fun write(b: Int) = throw AssertionError("the loop writes in chunks")

            override fun write(
                b: ByteArray,
                off: Int,
                len: Int,
            ) {
                synchronized(this@FakeCopyStore) {
                    writeErrorAt?.let { (at, e) -> if (row.bytes.size() + len > at) throw e }
                    row.bytes.write(b, off, len)
                }
            }

            override fun close() {
                synchronized(this@FakeCopyStore) {
                    closeError?.let {
                        closeError = null
                        throw it
                    }
                }
            }
        }
    }

    @Synchronized
    override fun publish(rowId: Long): Published {
        events += "publish $rowId"
        publishError?.let { throw it }
        val row = rows[rowId] ?: throw IOException("no row")
        row.pending = false
        return Published(row.id, row.name)
    }

    /** When set, deleteOwn waits for it (to race a cancel's deletes with other calls); bounded. */
    @Volatile var deleteGate: java.util.concurrent.CountDownLatch? = null

    /** Counted down when a deleteOwn has reached the gate. */
    val deleteEntered = java.util.concurrent.CountDownLatch(1)

    override fun deleteOwn(
        rowId: Long,
        folder: String,
        fileName: String?,
    ): Boolean {
        deleteGate?.let {
            deleteEntered.countDown()
            // Bounded: a test that fails before opening the gate must not hang the run.
            check(it.await(5, java.util.concurrent.TimeUnit.SECONDS)) { "delete gate never opened" }
        }
        return deleteOwnNow(rowId, folder, fileName)
    }

    @Synchronized
    private fun deleteOwnNow(
        rowId: Long,
        folder: String,
        fileName: String?,
    ): Boolean {
        events += "delete $rowId"
        if (rowId in undeletable) return false
        val row = rows[rowId] ?: return true
        if (!row.folder.equals(folder, true) || row.owner != ownPackage) return false
        if (fileName != null && row.name != fileName) return false
        rows.remove(rowId)
        return true
    }

    @Synchronized
    override fun ownRowsIn(folder: String): List<FolderRow> =
        rows.values
            .filter { it.folder.equals(folder, true) && it.owner == ownPackage }
            .map { FolderRow(it.id, it.name, it.bytes.size().toLong(), it.pending) }

    override fun deletePendingIn(folder: String): Int {
        deletePendingEntered.countDown()
        // Bounded: a test that fails before opening the gate must not hang the run.
        deletePendingGate?.let { check(it.await(5, java.util.concurrent.TimeUnit.SECONDS)) { "gate never opened" } }
        synchronized(this) {
            val gone = rows.values.filter { it.folder.equals(folder, true) && it.owner == ownPackage && it.pending }
            gone.forEach { rows.remove(it.id) }
            return gone.size
        }
    }

    companion object {
        fun noSpace(): IOException =
            IOException("write failed: ENOSPC (No space left on device)", ErrnoException("write", OsConstants.ENOSPC))
    }
}
