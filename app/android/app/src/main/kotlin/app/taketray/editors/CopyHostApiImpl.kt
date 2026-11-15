package app.taketray.editors

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import app.taketray.bridge.failureMessage
import app.taketray.bridge.guardedWith
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The copy screen keeps the screen on through the activity window's
 * FLAG_KEEP_SCREEN_ON (D-122, R4): no permission and no wake lock. The
 * window is only touched on the main thread. Without an activity (none
 * given, or after [detach]) nothing happens.
 */
class KeepScreenOn(
    activity: Activity?,
) {
    @Volatile private var activity: Activity? = activity

    fun set(on: Boolean) {
        val host = activity ?: return
        val apply = {
            val window = host.window
            if (on) window.addFlags(FLAG) else window.clearFlags(FLAG)
        }
        if (Looper.myLooper() == Looper.getMainLooper()) apply() else Handler(Looper.getMainLooper()).post(apply)
    }

    /** Whether the held activity's window has the flag now (false without one). */
    fun isOn(): Boolean = activity?.window?.attributes?.flags?.let { it and FLAG != 0 } ?: false

    /** The activity is going away: its window is never touched again. */
    fun detach() {
        activity = null
    }

    companion object {
        const val FLAG = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
    }
}

/**
 * The Kotlin side of the copy bridge (D-122): a thin pipe from Pigeon to the
 * process-wide [CopyEngine]. One is made per Flutter engine (per activity);
 * the job belongs to the engine and outlives it. Events go to Dart through
 * [send] (`CopyFlutterApi.onCopyChanged`) on the main thread, until
 * [onHostGone].
 *
 * Errors: `busy` (one job at a time), `bad-request` (a name that is not one
 * plain path segment), anything else `native-error` with the method and the
 * class name only, never a name, a folder or a path (D-10).
 */
class CopyHostApiImpl(
    activity: Activity?,
    private val engine: CopyEngine,
    private val send: suspend (CopyJobMsg) -> Unit,
    private val scope: CoroutineScope = MainScope(),
) : CopyHostApi {
    private val screen = KeepScreenOn(activity)

    /** The engine posts on the main thread; the send starts there at once, so events keep their order. */
    private val listener: (CopySnapshot) -> Unit = { snapshot ->
        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            try {
                send(snapshot.toMsg())
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // No Dart side listening (yet): the next event or current() tells it.
                Log.w(COPY_LOG_TAG, "copy event not delivered: ${e.javaClass.simpleName}")
            }
        }
    }

    init {
        engine.attach(listener)
    }

    /** The activity is going away: no more events from this bridge and no window. The job goes on. */
    fun onHostGone() {
        engine.detach(listener)
        screen.detach()
        scope.cancel()
    }

    override fun start(request: CopyRequestMsg) = guarded("start") { engine.start(request.toRequest()) }

    override fun current(): CopyJobMsg? = guarded("current") { engine.current()?.toMsg() }

    override suspend fun cancel(jobId: String): CopyJobMsg? = guardedSuspend("cancel") { engine.cancel(jobId)?.toMsg() }

    override fun resume(jobId: String) = guarded("resume") { engine.resume(jobId) }

    override fun clear(jobId: String) = guarded("clear") { engine.clear(jobId) }

    override suspend fun ownRowsIn(folderName: String): List<FolderRowMsg> =
        guardedSuspend("ownRowsIn") {
            engine.ownRowsIn(folderName).map { FolderRowMsg(it.mediaStoreId, it.fileName, it.sizeBytes, it.pending) }
        }

    override suspend fun deletePendingIn(folderName: String): Long =
        guardedSuspend("deletePendingIn") {
            engine.deletePendingIn(folderName).toLong().also { Log.i(COPY_LOG_TAG, "pending copies deleted: $it") }
        }

    override fun keepScreenOn(on: Boolean) = guarded("keepScreenOn") { screen.set(on) }
}

private inline fun <T> guarded(
    method: String,
    block: () -> T,
): T = guardedWith(method, ::copyError, block)

private suspend inline fun <T> guardedSuspend(
    method: String,
    block: () -> T,
): T =
    try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        throw copyError(method, e)
    }

/** busy, bad-request, or native-error with the class name only (D-10). */
internal fun copyError(
    method: String,
    e: Throwable,
): CopyApiError =
    when (e) {
        is CopyApiError -> e
        is CopyBusyException -> CopyApiError("busy", "$method: a copy job runs or its result waits", null)
        is IllegalArgumentException -> CopyApiError("bad-request", "$method: not a plain name", null)
        else -> CopyApiError("native-error", failureMessage(COPY_LOG_TAG, method, e), null)
    }

internal fun stateMsg(state: CopyState): CopyStateMsg =
    when (state) {
        CopyState.RUNNING -> CopyStateMsg.RUNNING
        CopyState.FINISHED -> CopyStateMsg.FINISHED
        CopyState.SPACE_FULL -> CopyStateMsg.SPACE_FULL
        CopyState.INTERRUPTED -> CopyStateMsg.INTERRUPTED
        CopyState.CANCELLED -> CopyStateMsg.CANCELLED
    }

private fun CopyRequestMsg.toRequest() =
    CopyRequest(
        jobId = jobId,
        reelId = reelId,
        folderName = folderName,
        items =
            items.map {
                CopyItem(
                    clipId = it.clipId,
                    source = CopySource(it.source.volumeName, it.source.mediaStoreId, it.source.pickerUri, it.source.mimeType),
                    fileName = it.fileName,
                    sizeBytes = it.sizeBytes,
                )
            },
    )

private fun CopiedFile.toMsg() = CopiedFileMsg(clipId, copyMediaStoreId, fileName, sizeBytes, copiedAtMs)

private fun CopySnapshot.toMsg() =
    CopyJobMsg(
        jobId = jobId,
        reelId = reelId,
        folderName = folderName,
        state = stateMsg(state),
        total = total.toLong(),
        done = done.toLong(),
        bytesDone = bytesDone,
        bytesTotal = bytesTotal,
        copied = copied.map { it.toMsg() },
        failedClipIds = failedClipIds,
        undeleted = undeleted.map { it.toMsg() },
    )
