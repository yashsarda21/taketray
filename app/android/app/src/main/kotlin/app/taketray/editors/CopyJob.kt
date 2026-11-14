package app.taketray.editors

import android.util.Log
import java.io.IOException
import java.io.OutputStream

enum class CopyState { RUNNING, FINISHED, SPACE_FULL, INTERRUPTED, CANCELLED }

data class CopySource(
    val volumeName: String?,
    val mediaStoreId: Long?,
    val pickerUri: String?,
    val mimeType: String,
)

data class CopyItem(
    val clipId: Long,
    val source: CopySource,
    val fileName: String,
    val sizeBytes: Long,
)

data class CopyRequest(
    val jobId: String,
    val reelId: Long,
    val folderName: String,
    val items: List<CopyItem>,
)

data class CopiedFile(
    val clipId: Long,
    val copyMediaStoreId: Long,
    val fileName: String,
    val sizeBytes: Long,
    val copiedAtMs: Long,
)

data class CopySnapshot(
    val jobId: String,
    val reelId: Long,
    val folderName: String,
    val state: CopyState,
    val total: Int,
    val done: Int,
    val bytesDone: Long,
    val bytesTotal: Long,
    val copied: List<CopiedFile>,
    val failedClipIds: List<Long>,
    val undeleted: List<CopiedFile>,
)

/** The native hard floor: a file is copied only when this much is left after it. */
const val NATIVE_FLOOR_BYTES = 50L * 1000 * 1000

/** Chunk size of the copy loop. */
const val CHUNK_BYTES = 1024 * 1024

/** At most one progress event this often during a file. */
const val PROGRESS_EVERY_MS = 250L


/** Tag for the copy log lines: ids, counts and error class names only, never a name or a path (D-10). */
internal const val COPY_LOG_TAG = "TakeTrayCopy"

/**
 * True when [e] or one of its causes says "no space left on the device". The
 * message is enough: a full disk's `ErrnoException` always names ENOSPC in it
 * ("write failed: ENOSPC (No space left on device)"), and an exception that
 * crossed a binder keeps only its message.
 */
internal fun isNoSpace(e: Throwable): Boolean {
    var t: Throwable? = e
    var depth = 0
    while (t != null && depth++ < 16) {
        val message = t.message.orEmpty()
        if ("ENOSPC" in message || "No space left on device" in message) return true
        t = t.cause
    }
    return false
}

/**
 * One copy job and its loop (D-122). The engine owns it, runs [run] and
 * [deleteCopies] on its one worker, and reads it from any thread: every
 * field below is guarded by [lock].
 *
 * Per item, in the order given (shooting order):
 * 1. free space on the primary volume must be at least the item's size plus
 *    [NATIVE_FLOOR_BYTES], else the job stops `SPACE_FULL` before any row is made;
 * 2. a pending row (IS_PENDING 1) is made in `Movies/TakeTray/<folder>/`;
 * 3. the original is opened read-only and copied in chunks, the cancel flag
 *    checked before every chunk;
 * 4. the bytes written must equal the original's length, else the row is
 *    deleted and the item failed;
 * 5. IS_PENDING 0 publishes it; its id and real name are read back.
 *
 * What a failure does: the original cannot be opened or read, or is short
 * (the clip is gone, its grant is lost, the card was pulled) → the row is
 * deleted, the clip is in `failedClipIds`, the job goes on. No space (the
 * floor, ENOSPC while writing, or a full disk at insert) → the row is deleted
 * and the job stops `SPACE_FULL`. Any other storage failure (the row cannot
 * be made, opened, written or published) → the row is deleted and the job
 * stops `INTERRUPTED`. Both can be resumed from the item that stopped them.
 * MediaStore refusing an item's name (IllegalArgumentException at insert)
 * fails that item only; a second refusal in a row stops the job `INTERRUPTED`
 * instead (it is not the names), and that item is tried again on resume.
 */
internal class CopyJob(
    val request: CopyRequest,
    private val store: CopyStore,
    private val lock: Any,
    private val clock: () -> Long,
    private val wallClock: () -> Long,
    private val chunkBytes: Int,
    private val throttleMs: () -> Long,
    private val sleep: (Long) -> Unit,
    private val emit: (CopySnapshot) -> Unit,
) {
    private val folder = request.folderName
    private val bytesTotal = request.items.sumOf { it.sizeBytes }

    // ---- Guarded by lock ----
    var state = CopyState.RUNNING
        private set
    private var next = 0
    private var handledBytes = 0L
    private var currentBytes = 0L
    private val copied = mutableListOf<CopiedFile>()
    private val failed = mutableListOf<Long>()

    /** Worker only: items refused at insert just before this one; zero at each run (a resume starts again). */
    private var refusedInRow = 0
    private val undeleted = mutableListOf<CopiedFile>()

    /** Set by Stop; the loop reads it before every chunk. */
    @Volatile var cancelRequested = false
        private set

    /** When the worker last emitted, for the progress throttle (worker only). */
    private var lastEventAt = 0L

    fun snapshot(): CopySnapshot =
        synchronized(lock) {
            CopySnapshot(
                jobId = request.jobId,
                reelId = request.reelId,
                folderName = folder,
                state = state,
                total = request.items.size,
                done = next,
                bytesDone = handledBytes + currentBytes,
                bytesTotal = bytesTotal,
                copied = copied.toList(),
                failedClipIds = failed.toList(),
                undeleted = undeleted.toList(),
            )
        }

    /** Caller holds [lock]. */
    fun requestCancel() {
        cancelRequested = true
    }

    /** Caller holds [lock]: a stopped job goes on (resume). */
    fun markRunning() {
        state = CopyState.RUNNING
    }

    /** Worker: copies from the next item until the end, a stop or a cancel; a cancel ends in [deleteCopies]. */
    fun run() {
        lastEventAt = clock()
        refusedInRow = 0
        val end =
            try {
                copyItems()
            } catch (e: Exception) {
                Log.w(COPY_LOG_TAG, "copy job stopped: ${e.javaClass.simpleName}")
                CopyState.INTERRUPTED
            }
        val cancel =
            synchronized(lock) {
                currentBytes = 0
                if (cancelRequested || end == CopyState.CANCELLED) {
                    true
                } else {
                    state = end
                    false
                }
            }
        if (cancel) {
            deleteCopies()
        } else {
            log()
            send()
        }
    }

    /**
     * Worker: deletes every copy this job made (Stop always means "delete the
     * copies made so far"), then the job is `CANCELLED`. A copy that cannot be
     * deleted moves to `undeleted`; `copied` keeps those that were deleted.
     */
    fun deleteCopies() {
        val made = synchronized(lock) { copied.toList() }
        val gone = mutableListOf<CopiedFile>()
        val left = mutableListOf<CopiedFile>()
        for (file in made) {
            val deleted =
                try {
                    store.deleteOwn(file.copyMediaStoreId, folder, file.fileName)
                } catch (e: Exception) {
                    Log.w(COPY_LOG_TAG, "copy not deleted: ${e.javaClass.simpleName}")
                    false
                }
            if (deleted) gone += file else left += file
        }
        synchronized(lock) {
            copied.clear()
            copied += gone
            undeleted += left
            state = CopyState.CANCELLED
        }
        log()
        send()
    }

    private fun log() {
        val s = snapshot()
        Log.i(COPY_LOG_TAG, "copy job ${s.state}: ${s.copied.size} copied, ${s.failedClipIds.size} failed, ${s.undeleted.size} undeleted, ${s.done} of ${s.total}")
    }

    private fun send() {
        lastEventAt = clock()
        emit(snapshot())
    }

    private enum class Outcome { COPIED, FAILED, REFUSED, NO_SPACE, INTERRUPTED, CANCELLED }

    /** The loop: the state the job ends in ([CopyState.CANCELLED] for a cancel). */
    private fun copyItems(): CopyState {
        while (true) {
            val index = synchronized(lock) { next }
            if (index >= request.items.size) return CopyState.FINISHED
            if (cancelRequested) return CopyState.CANCELLED
            val item = request.items[index]
            if (store.availableBytes() < item.sizeBytes + NATIVE_FLOOR_BYTES) return CopyState.SPACE_FULL
            when (copyOne(item)) {
                Outcome.COPIED, Outcome.FAILED -> {
                    synchronized(lock) {
                        next = index + 1
                        handledBytes += item.sizeBytes
                        currentBytes = 0
                    }
                    send()
                }
                Outcome.NO_SPACE -> return CopyState.SPACE_FULL
                Outcome.INTERRUPTED -> return CopyState.INTERRUPTED
                Outcome.CANCELLED -> return CopyState.CANCELLED
                // copyOne settles a refusal as FAILED or INTERRUPTED.
                Outcome.REFUSED -> throw IllegalStateException("an unsettled refusal")
            }
        }
    }

    /** A failure of the original (not the copy's). */
    private class SourceFailure(cause: Throwable) : IOException(cause)

    /** A failure writing the copy. */
    private class TargetFailure(cause: Throwable) : IOException(cause)

    /**
     * One item. MediaStore refusing the item's name (IllegalArgumentException
     * at insert) fails that item only. The names are plain, so a second
     * refusal in a row means it is not the names (an unknown collection, a
     * volume that is not there): the job stops [Outcome.INTERRUPTED], resumable,
     * and that item is tried again.
     */
    private fun copyOne(item: CopyItem): Outcome {
        val outcome = copyItem(item)
        if (outcome != Outcome.REFUSED) {
            refusedInRow = 0
            return outcome
        }
        if (refusedInRow >= 1) {
            return Outcome.INTERRUPTED
        }
        refusedInRow++
        synchronized(lock) { failed += item.clipId }
        return Outcome.FAILED
    }

    private fun copyItem(item: CopyItem): Outcome {
        val rowId =
            try {
                store.insertPending(folder, item.fileName)
            } catch (e: IllegalArgumentException) {
                Log.w(COPY_LOG_TAG, "copy item refused at insert: ${e.javaClass.simpleName}")
                return Outcome.REFUSED
            } catch (e: Exception) {
                Log.w(COPY_LOG_TAG, "copy row not made: ${e.javaClass.simpleName}")
                return if (isNoSpace(e)) Outcome.NO_SPACE else Outcome.INTERRUPTED
            }
        var outcome = Outcome.INTERRUPTED
        try {
            outcome = copyInto(item, rowId)
        } catch (e: Exception) {
            Log.w(COPY_LOG_TAG, "copy item stopped: ${e.javaClass.simpleName}")
            outcome =
                when {
                    e is SourceFailure -> Outcome.FAILED
                    isNoSpace(e) -> Outcome.NO_SPACE
                    else -> Outcome.INTERRUPTED
                }
        } finally {
            if (outcome != Outcome.COPIED) {
                // Our own half-made row, never published: it goes.
                try {
                    if (!store.deleteOwn(rowId, folder, null)) Log.w(COPY_LOG_TAG, "pending row not deleted")
                } catch (e: Exception) {
                    Log.w(COPY_LOG_TAG, "pending row not deleted: ${e.javaClass.simpleName}")
                }
                synchronized(lock) { currentBytes = 0 }
            }
        }
        if (outcome == Outcome.FAILED) synchronized(lock) { failed += item.clipId }
        return outcome
    }

    /** Copies [item] into [rowId] and publishes it; throws [SourceFailure] for the original's failures. */
    private fun copyInto(
        item: CopyItem,
        rowId: Long,
    ): Outcome {
        val source =
            try {
                store.openSource(item.source)
            } catch (e: Exception) {
                throw SourceFailure(e)
            }
        val written: Long
        source.use {
            val target = store.openTarget(rowId)
            val result =
                try {
                    copy(source, target, item)
                } catch (e: Exception) {
                    try {
                        target.close()
                    } catch (ignored: Exception) {
                        // The first failure is the one that counts.
                    }
                    throw e
                }
            try {
                target.close()
            } catch (e: Exception) {
                throw TargetFailure(e)
            }
            if (result < 0) return Outcome.CANCELLED
            written = result
        }
        val expected = if (source.length >= 0) source.length else item.sizeBytes.takeIf { it > 0 }
        if (expected != null && written != expected) {
            Log.w(COPY_LOG_TAG, "copy item failed: length differs")
            return Outcome.FAILED
        }
        val published = store.publish(rowId)
        synchronized(lock) {
            copied += CopiedFile(item.clipId, published.id, published.displayName, written, wallClock())
        }
        return Outcome.COPIED
    }

    /** The bytes copied, or -1 when Stop came first. */
    private fun copy(
        source: SourceFile,
        target: OutputStream,
        item: CopyItem,
    ): Long {
        val buffer = ByteArray(chunkBytes)
        var total = 0L
        while (true) {
            if (cancelRequested) return -1
            val n =
                try {
                    source.input.read(buffer, 0, buffer.size)
                } catch (e: Exception) {
                    throw SourceFailure(e)
                }
            if (n < 0) return total
            if (n == 0) continue
            try {
                target.write(buffer, 0, n)
            } catch (e: Exception) {
                throw TargetFailure(e)
            }
            total += n
            val pause = throttleMs()
            if (pause > 0) sleep(pause)
            synchronized(lock) { currentBytes = minOf(total, item.sizeBytes) }
            if (clock() - lastEventAt >= PROGRESS_EVERY_MS) send()
        }
    }
}
