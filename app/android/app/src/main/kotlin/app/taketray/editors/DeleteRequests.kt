package app.taketray.editors

import android.app.Activity
import android.content.IntentSender
import kotlinx.coroutines.CompletableDeferred

/**
 * The one delete request in flight: Android's consent dialog
 * (`MediaStore.createDeleteRequest`) for copies TakeTray may not delete
 * itself, answered through the activity's onActivityResult (D-121).
 *
 * One at a time: a second request while one is being prepared or shown
 * fails with `busy`. A result with nobody waiting (the process died while the
 * dialog was up and Android re-created the activity) is dropped. The activity
 * going away fails the waiting request with the given error instead of
 * leaving it hanging. Touched on the main thread only.
 */
class DeleteRequests(
    private val requestCode: Int = REQUEST_CODE,
) {
    /** True from the start of [run] until it ends. */
    private var busy = false

    /** The open dialog's answer, while one is shown. */
    private var waiting: CompletableDeferred<Boolean>? = null

    /** Set by [fail] while a request is being prepared: it then ends with this error. */
    private var failure: Throwable? = null

    /** True while a request is being prepared or shown (a second one is "busy"). */
    val isBusy: Boolean get() = busy

    /**
     * Runs [prepare] (off the main thread, by the caller's choice), which gives
     * the dialog's sender or null when there is nothing to ask; then [start]s
     * it with this request code and waits for [onResult]. True only when the
     * user allowed it (RESULT_OK). Every way out frees the slot.
     */
    suspend fun run(
        prepare: suspend () -> IntentSender?,
        start: (IntentSender, Int) -> Unit,
    ): Boolean {
        if (busy) throw EditorsError("busy", "a delete request is already open")
        busy = true
        failure = null
        var answer: CompletableDeferred<Boolean>? = null
        try {
            val sender = prepare()
            failure?.let { throw it }
            if (sender == null) return false
            val request = CompletableDeferred<Boolean>()
            answer = request
            waiting = request
            start(sender, requestCode)
            return request.await()
        } finally {
            if (answer != null && waiting === answer) waiting = null
            failure = null
            busy = false
        }
    }

    /** True when [code] is this request's and one was waiting; it then resumes. */
    fun onResult(
        code: Int,
        resultCode: Int,
    ): Boolean {
        if (code != requestCode) return false
        val request = waiting ?: return false
        waiting = null
        request.complete(resultCode == Activity.RESULT_OK)
        return true
    }

    /** Fails the request in flight with [error] (the activity went away). */
    fun fail(error: Throwable) {
        val request = waiting
        if (request != null) {
            waiting = null
            request.completeExceptionally(error)
        } else if (busy) {
            failure = error
        }
    }

    companion object {
        /** The request code of the consent dialog (16 bits; the media bridge uses 0x7A71 and 0x7A73, the background one 0x7A72). */
        const val REQUEST_CODE = 0x7A75
    }
}
