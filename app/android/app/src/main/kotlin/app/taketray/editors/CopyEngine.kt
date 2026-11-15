package app.taketray.editors

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** A job runs or its result waits (R4: one job at a time), or the folder sweep runs. */
class CopyBusyException : IllegalStateException("a copy job runs or its result waits")

/**
 * The one copy job of this process (D-122, R4). It lives here, not in the
 * activity: the job goes on while the process lives, also when the user
 * leaves the app or the activity is re-created, and the next bridge reads it
 * with [current]. If Android stops the process the job is gone; Dart then
 * recovers from the folder ([ownRowsIn], [deletePendingIn]) and the plan it
 * saved before starting. There is no journal file.
 *
 * Threading: one worker coroutine on [io] runs the loop, and the deletes
 * after a cancel, after the loop has ended, so they never race the file
 * being written. Every other method may be called from any thread; the job
 * state is guarded by one lock. Events go through [post] (the main thread on
 * the phone) to the attached listener; with none attached they are dropped.
 */
class CopyEngine(
    private val store: CopyStore,
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val post: (Runnable) -> Unit = { Handler(Looper.getMainLooper()).post(it) },
    private val clock: () -> Long = SystemClock::elapsedRealtime,
    private val wallClock: () -> Long = System::currentTimeMillis,
    private val chunkBytes: Int = CHUNK_BYTES,
    private val sleep: (Long) -> Unit = Thread::sleep,
) {
    /**
     * A pause after every chunk, for the on-device tests only (to stop a copy
     * mid-file). 0 by default; only `DebugCopyHooks` sets it, and the release
     * dex check fails if that class is in a release build.
     */
    @Volatile var throttleMs: Long = 0

    private val lock = Any()
    private val scope = CoroutineScope(SupervisorJob() + io)

    // ---- Guarded by lock ----
    private var job: CopyJob? = null
    private var worker: Job? = null
    private var sweeps = 0

    @Volatile private var listener: ((CopySnapshot) -> Unit)? = null

    /** The bridge of the current activity listens; it replaces any earlier one. */
    fun attach(listener: (CopySnapshot) -> Unit) {
        synchronized(lock) { this.listener = listener }
    }

    /** Stops [listener]'s events, only if it is still the attached one (an old activity's late destroy changes nothing). */
    fun detach(listener: (CopySnapshot) -> Unit) {
        synchronized(lock) { if (this.listener === listener) this.listener = null }
    }

    /** Whether a bridge listens (tests): a gone bridge must not stay referenced by this process-wide engine. */
    internal val hasListener: Boolean get() = listener != null

    /** The listener is read when the event is delivered: one that left gets nothing more. */
    private fun emit(snapshot: CopySnapshot) {
        post { listener?.invoke(snapshot) }
    }

    /**
     * Starts [request] on the worker. Throws [CopyBusyException] while a job
     * runs or its result waits (or the folder sweep runs), and
     * [IllegalArgumentException] for a job id, folder or file name that is
     * not one plain path segment, or a negative size; nothing is written then.
     */
    fun start(request: CopyRequest) {
        synchronized(lock) {
            if (job != null || sweeps > 0) throw CopyBusyException()
            require(request.jobId.isNotBlank()) { "no job id" }
            requireSegment(request.folderName)
            for (item in request.items) {
                requireSegment(item.fileName)
                require(item.sizeBytes >= 0) { "negative size" }
            }
            val created =
                CopyJob(request, store, lock, clock, wallClock, chunkBytes, { throttleMs }, sleep, ::emit)
            job = created
            // Posted before the worker exists, so no event of the worker can overtake it.
            emit(created.snapshot())
            launchWorker { created.run() }
        }
    }

    /** Caller holds [lock]: the next worker starts after the one before it is over, so there is only ever one. */
    private fun launchWorker(body: () -> Unit): Job {
        val previous = worker
        return scope
            .launch {
                previous?.join()
                body()
            }.also { worker = it }
    }

    /** The running job or the waiting result; null when there is none (also after a restart). */
    fun current(): CopySnapshot? = synchronized(lock) { job?.snapshot() }

    /**
     * Stop: sets the cancel flag and returns a wait that ends once the copies
     * are deleted; null for an unknown id. A running job's loop sees the flag
     * at its next chunk and deletes its own copies; a stopped or finished one
     * gets a worker that deletes them. A cancelled job is answered as it is.
     * The loop's last step (setting its end state) takes the same lock, so a
     * cancel racing the last file either reaches the loop or finds it ended.
     */
    internal fun beginCancel(jobId: String): (suspend () -> CopySnapshot)? =
        synchronized(lock) {
            val target = job?.takeIf { it.request.jobId == jobId } ?: return null
            val waitFor: Job? =
                when {
                    target.state == CopyState.CANCELLED -> null
                    target.cancelRequested -> worker
                    target.state == CopyState.RUNNING -> {
                        target.requestCancel()
                        worker
                    }
                    else -> {
                        target.requestCancel()
                        launchWorker { target.deleteCopies() }
                    }
                }
            return {
                waitFor?.join()
                target.snapshot()
            }
        }

    /** Stops [jobId] and deletes its copies; answers once they are deleted. Null for an unknown id. */
    suspend fun cancel(jobId: String): CopySnapshot? = beginCancel(jobId)?.invoke()

    /**
     * After SPACE_FULL or INTERRUPTED: the remaining items of [jobId]. Anything
     * else does nothing. Throws [CopyBusyException] while the folder sweep
     * runs (it must not delete the row the resumed job would write).
     */
    fun resume(jobId: String) {
        synchronized(lock) {
            val target = job?.takeIf { it.request.jobId == jobId } ?: return
            if (target.cancelRequested) return
            if (target.state != CopyState.SPACE_FULL && target.state != CopyState.INTERRUPTED) return
            if (sweeps > 0) throw CopyBusyException()
            target.markRunning()
            // Posted before the worker exists, so no event of the worker can overtake it.
            emit(target.snapshot())
            launchWorker { target.run() }
        }
    }

    /** Forgets the result of [jobId]. Another id, a running job or one still deleting its copies is left alone. */
    fun clear(jobId: String) {
        synchronized(lock) {
            val target = job?.takeIf { it.request.jobId == jobId } ?: return
            if (target.state == CopyState.RUNNING) return
            if (target.cancelRequested && target.state != CopyState.CANCELLED) return
            job = null
        }
    }

    /** TakeTray's own rows in exactly `Movies/TakeTray/<folder>/`, pending ones included. */
    suspend fun ownRowsIn(folder: String): List<FolderRow> {
        requireSegment(folder)
        return withContext(io) { store.ownRowsIn(folder) }
    }

    /**
     * Deletes TakeTray's own pending rows in exactly `Movies/TakeTray/<folder>/`
     * (what a process that died mid-copy left). Busy while a job's worker
     * runs, and no job can start until it is over, so it never deletes the
     * row a running job is writing.
     */
    suspend fun deletePendingIn(folder: String): Int {
        requireSegment(folder)
        synchronized(lock) {
            if (worker?.isActive == true) throw CopyBusyException()
            sweeps++
        }
        try {
            return withContext(io) { store.deletePendingIn(folder) }
        } finally {
            synchronized(lock) { sweeps-- }
        }
    }

    /** Waits until the worker is idle (tests). */
    internal suspend fun awaitIdle() {
        while (true) {
            val running = synchronized(lock) { worker } ?: return
            running.join()
            if (synchronized(lock) { worker } === running) return
        }
    }

    companion object {
        @Volatile private var shared: CopyEngine? = null

        /** The process-wide engine, over MediaStore. */
        fun shared(context: Context): CopyEngine =
            shared ?: synchronized(this) {
                shared ?: context.applicationContext.let { app ->
                    CopyEngine(MediaStoreCopyStore(app.contentResolver, app.packageName)).also { shared = it }
                }
            }
    }
}

/**
 * A folder or file name must be one plain path segment: not blank, no `/`,
 * no NUL, not `.` or `..`. The names come from Dart's rules (D-119); this
 * keeps a wrong one from ever writing outside `Movies/TakeTray/<folder>/`.
 */
internal fun requireSegment(name: String) {
    require(name.isNotBlank() && '/' !in name && '\u0000' !in name && name != "." && name != "..") { "not a plain name" }
}
