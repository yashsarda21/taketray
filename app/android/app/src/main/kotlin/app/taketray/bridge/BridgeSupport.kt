package app.taketray.bridge

import android.util.Log
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

// What the Pigeon bridges (media, background) share. Each generated contract
// has its own FlutterError class (one per Kotlin package), so a bridge passes
// its own `toError`; the rule for what an error may say lives here once.

/** Runs [block]; an unexpected exception goes through [toError] and is thrown. */
internal inline fun <T> guardedWith(
    method: String,
    toError: (String, Throwable) -> Throwable,
    block: () -> T,
): T =
    try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        throw toError(method, e)
    }

/** [guardedWith] on Dispatchers.IO, for the `@async` handlers that touch storage. */
internal suspend fun <T> guardedOnIo(
    method: String,
    toError: (String, Throwable) -> Throwable,
    block: () -> T,
): T = withContext(Dispatchers.IO) { guardedWith(method, toError, block) }

/**
 * "<method> failed: <ExceptionClass>", also logged at warning level under
 * [tag]: what Dart gets for an unexpected exception. Never the exception's
 * message or cause, which can hold a URI or a file path (D-10).
 */
internal fun failureMessage(
    tag: String,
    method: String,
    e: Throwable,
): String {
    val text = "$method failed: ${e.javaClass.simpleName}"
    Log.w(tag, text)
    return text
}

/**
 * One runtime-permission request in flight, answered through the activity's
 * onRequestPermissionsResult. Touched on the main thread only.
 */
internal class PendingPermission(
    private val requestCode: Int,
) {
    private var waiting: CompletableDeferred<Unit>? = null

    /** True while a request waits for its result (a second one is "busy"). */
    val isWaiting: Boolean get() = waiting != null

    /**
     * Runs [ask] (which shows the dialog with this request code) and waits for
     * [onResult]. If [ask] throws, the slot is freed and the exception passes.
     */
    suspend fun await(ask: () -> Unit) {
        val request = CompletableDeferred<Unit>()
        waiting = request
        try {
            ask()
            request.await()
        } finally {
            if (waiting === request) waiting = null
        }
    }

    /** True when [code] is this request's and one was waiting; it then resumes. */
    fun onResult(code: Int): Boolean {
        if (code != requestCode) return false
        val request = waiting ?: return false
        waiting = null
        request.complete(Unit)
        return true
    }

    /** Fails a waiting request with [error] (the activity went away) instead of leaving it hanging. */
    fun fail(error: Throwable) {
        waiting?.let {
            waiting = null
            it.completeExceptionally(error)
        }
    }
}

/**
 * Android's "ask again" rule for one permission (D-68, Ruling F). Android
 * gives no rationale both before the first ask and after the final "Don't
 * allow"; it does give one between the first and the second denial. So a
 * request ends blocked only when the permission is not [granted], there is no
 * rationale now, and there was one before the request (the second denial) or
 * the last request had already ended blocked (a dismissal while blocked). A
 * first dismissal (no rationale before or after) stays askable.
 */
internal fun blockedAfterRequest(
    granted: Boolean,
    rationaleBefore: Boolean,
    rationaleAfter: Boolean,
    wasBlocked: Boolean,
): Boolean = !granted && !rationaleAfter && (rationaleBefore || wasBlocked)
