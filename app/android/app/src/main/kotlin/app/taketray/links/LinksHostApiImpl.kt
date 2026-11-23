package app.taketray.links

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import app.taketray.bridge.failureMessage
import app.taketray.bridge.guardedWith

/**
 * The Kotlin side of the links bridge (D-155): opens a reference link with
 * `ACTION_VIEW` and `CATEGORY_BROWSABLE`, in whichever app or browser the
 * phone picks. No permission is needed.
 *
 * Only `http` and `https` (with a host) are opened: a link comes from text the
 * user pasted, so `javascript:`, `file:`, `content:`, `intent:` and the like
 * answer false and start nothing. A phone with nothing to open the link
 * (`ActivityNotFoundException`) answers false too.
 *
 * Errors: anything unexpected is `native-error` with the method and the
 * exception's class name only, never its message, which can hold the address;
 * once the activity is gone, `no-activity`. Logs say the outcome only, never
 * an address (D-10).
 *
 * [start] is how an intent is started; it defaults to the activity's own and
 * exists so a test can make it fail.
 */
class LinksHostApiImpl(
    activity: Activity,
    private val start: ((Intent) -> Unit)? = null,
) : LinksHostApi {
    /** Null once the activity is gone ([onHostGone]). */
    private var activity: Activity? = activity

    override suspend fun openLink(url: String): Boolean =
        guardedWith("openLink", ::linksFailure) {
            val uri = Uri.parse(url)
            if (!isWebLink(uri)) {
                Log.i(TAG, "openLink: not a web link; nothing started")
                return@guardedWith false
            }
            val host = activity ?: throw LinksError("no-activity", "openLink needs the activity")
            val view =
                Intent(Intent.ACTION_VIEW, uri)
                    .addCategory(Intent.CATEGORY_BROWSABLE)
            try {
                (start ?: host::startActivity)(view)
                Log.i(TAG, "openLink: started")
                true
            } catch (e: ActivityNotFoundException) {
                Log.i(TAG, "openLink: no app can open it")
                false
            }
        }

    /** The activity is being destroyed: nothing more starts. */
    fun onHostGone() {
        activity = null
    }

    private fun isWebLink(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase()
        return (scheme == "http" || scheme == "https") && !uri.host.isNullOrEmpty()
    }

    private companion object {
        const val TAG = "TakeTrayLinks"
    }
}

/**
 * [LinksError] stays as it is; anything else becomes `native-error` with the
 * method and the class name only (D-10).
 */
private fun linksFailure(
    method: String,
    e: Throwable,
): LinksError = e as? LinksError ?: LinksError("native-error", failureMessage("TakeTrayLinks", method, e), null)
