package app.taketray.share

import android.app.Activity
import android.content.Intent
import android.util.Log
import app.taketray.bridge.failureMessage
import app.taketray.bridge.guardedWith

/**
 * The Kotlin side of the share bridge (D-163), for the share screen's engine
 * only ([ShareActivity]).
 *
 * [sharedText] reads `EXTRA_TEXT` of the activity's intent when it is an
 * `ACTION_SEND` of type `text/plain` (`Intent.normalizeMimeType`, so any case
 * and any parameters), as a `CharSequence` turned into a plain `String` (an
 * app may share text with spans), cut to [MAX_CHARS] characters without
 * splitting an emoji in half. Each intent is read once: the next call answers
 * null until [ShareActivity.onNewIntent] puts a new share in its place.
 *
 * [finish] closes the screen with `finishAndRemoveTask` when it is the root
 * of its own task (an app that shares with `FLAG_ACTIVITY_NEW_TASK`), so
 * nothing stays in Recents, and with `finish` inside the sharing app's task.
 *
 * Errors: once the activity is gone every call is `no-activity`; anything
 * unexpected is `native-error` with the method and the exception's class name
 * only. Logs never hold the shared text, only its length (D-10).
 */
class ShareHostApiImpl(
    activity: Activity,
) : ShareHostApi {
    /** Null once the activity is gone ([onHostGone]). */
    private var activity: Activity? = activity

    /** The intent [sharedText] last answered for: it is not read again. */
    private var read: Intent? = null

    override fun sharedText(): String? =
        guardedWith("sharedText", ::shareFailure) {
            val intent = host("sharedText").intent
            if (intent == null || intent === read) {
                Log.i(TAG, "sharedText: nothing new")
                return@guardedWith null
            }
            read = intent
            val text = textOf(intent)
            Log.i(TAG, "sharedText: ${text?.length ?: "no"} characters")
            text
        }

    override fun finish() =
        guardedWith("finish", ::shareFailure) {
            close(host("finish"))
        }

    /**
     * Closes the share screen. Task 4 makes it open the reel through the
     * `openReel` launch action first; until then [reelId] is not used.
     */
    override fun openReel(reelId: Long) =
        guardedWith("openReel", ::shareFailure) {
            close(host("openReel"))
        }

    /** The activity is being destroyed: every later call is `no-activity`. */
    fun onHostGone() {
        activity = null
    }

    private fun host(method: String): Activity = activity ?: throw ShareError("no-activity", "$method needs the activity")

    private fun close(host: Activity) {
        if (host.isTaskRoot) {
            Log.i(TAG, "closing the share screen and its task")
            host.finishAndRemoveTask()
        } else {
            Log.i(TAG, "closing the share screen")
            host.finish()
        }
    }

    companion object {
        /** The longest shared text Dart is given. */
        const val MAX_CHARS = 20_000

        private const val TAG = "TakeTrayShare"

        /** The text of a `text/plain` `ACTION_SEND`, cut to [MAX_CHARS]; null for anything else. */
        internal fun textOf(intent: Intent): String? {
            if (intent.action != Intent.ACTION_SEND) return null
            if (Intent.normalizeMimeType(intent.type) != "text/plain") return null
            val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return null
            return cut(text)
        }

        /** [text]'s first [MAX_CHARS] characters, one fewer when the last would be half an emoji. */
        private fun cut(text: String): String {
            if (text.length <= MAX_CHARS) return text
            val end = if (Character.isHighSurrogate(text[MAX_CHARS - 1])) MAX_CHARS - 1 else MAX_CHARS
            return text.substring(0, end)
        }
    }
}

/**
 * [ShareError] stays as it is; anything else becomes `native-error` with the
 * method and the class name only (D-10).
 */
private fun shareFailure(
    method: String,
    e: Throwable,
): ShareError = e as? ShareError ?: ShareError("native-error", failureMessage("TakeTrayShare", method, e), null)
