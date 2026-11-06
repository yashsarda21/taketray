package app.taketray.background

import android.content.Context
import android.content.Intent
import android.util.Log
import app.taketray.MainActivity
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Launch actions (D-103): what a notification tap asks the app to open. Flutter's
 * own deep linking is off, because MainActivity is exported for the launcher and
 * any app could otherwise open any route (D-101). Instead a notification's
 * intent carries [EXTRA_OPEN] with one of two allow-listed values; anything
 * else is ignored.
 */
object LaunchActions {
    const val EXTRA_OPEN = "app.taketray.extra.OPEN"

    private val VALUES = mapOf("toTag" to LaunchActionMsg.TO_TAG, "reels" to LaunchActionMsg.REELS)

    /**
     * The explicit MainActivity intent a notification uses for [action]. It
     * brings the app's task to the front (NEW_TASK, as a PendingIntent starts it
     * from outside an activity) and reaches the running activity through
     * onNewIntent (CLEAR_TOP with SINGLE_TOP). Each action has its own
     * identifier, so PendingIntents for the two never replace each other
     * (PendingIntent compares intents without their extras).
     */
    fun intent(
        context: Context,
        action: LaunchActionMsg,
    ): Intent {
        val value = VALUES.entries.first { it.value == action }.key
        return Intent(context, MainActivity::class.java)
            .setIdentifier("taketray-open-$value")
            .putExtra(EXTRA_OPEN, value)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    /**
     * The action in [intent], read once: the extra is removed whatever it
     * held, so the same intent (an activity re-created with it) gives
     * nothing the second time. Null when there is none, when its value is not
     * exactly `toTag` or `reels` (another app can send anything), and when the
     * activity was opened from Recents (FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY:
     * Android replays the first intent, extra and all).
     */
    fun read(intent: Intent?): LaunchActionMsg? {
        if (intent == null) return null
        val value =
            try {
                if (!intent.hasExtra(EXTRA_OPEN)) return null
                intent.getStringExtra(EXTRA_OPEN).also { intent.removeExtra(EXTRA_OPEN) }
            } catch (e: RuntimeException) {
                // Extras another app made unreadable (BadParcelableException).
                Log.w(LOG_TAG, "launch intent unreadable: ${e.javaClass.simpleName}")
                return null
            }
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return VALUES[value]
    }
}

/**
 * Hands launch actions from MainActivity's intents to Dart. Main thread only.
 *
 * Dart is listening once it has called [take] (the bridge does that when it
 * starts, after setting up its `BackgroundFlutterApi` handler). Until then
 * the newest action is kept for [take]; after that each one is sent through
 * [send] (`BackgroundFlutterApi.onLaunchAction`). A send that fails (no
 * handler, say) keeps the action for the next [take].
 *
 * [onToTag] runs for every fresh To tag action, before it goes to Dart
 * (D-105): the evening reminder's **Tag now** and body tap, and the
 * new-clips notification's, all lead to To tag, and Android removes only the
 * tapped body, never the notification of a button. A failure in it is logged
 * by class only and never stops the action.
 */
class LaunchActionRelay(
    private val send: suspend (LaunchActionMsg) -> Unit,
    private val scope: CoroutineScope = MainScope(),
    private val onToTag: () -> Unit = {},
) {
    companion object {
        /** MainActivity's relay: opening To tag removes the evening reminder. */
        fun forActivity(
            context: Context,
            send: suspend (LaunchActionMsg) -> Unit,
            scope: CoroutineScope = MainScope(),
        ): LaunchActionRelay {
            val notifier = Notifier(context.applicationContext)
            return LaunchActionRelay(send, scope, onToTag = notifier::cancelEvening)
        }
    }

    private var kept: LaunchActionMsg? = null
    private var dartListening = false

    /**
     * Reads [intent] ([LaunchActions.read], which also strips it). [restored]
     * is true for the intent of an activity re-created from saved state (the
     * process had died): Android gives it the intent it was first started
     * with, whose action was already handled, so it is dropped.
     */
    fun onIntent(
        intent: Intent?,
        restored: Boolean = false,
    ) {
        val action = LaunchActions.read(intent) ?: return
        if (restored) return
        if (action == LaunchActionMsg.TO_TAG) {
            try {
                onToTag()
            } catch (e: RuntimeException) {
                Log.w(LOG_TAG, "evening reminder not removed: ${e.javaClass.simpleName}")
            }
        }
        if (!dartListening) {
            kept = action
            return
        }
        scope.launch {
            try {
                send(action)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                Log.w(LOG_TAG, "launch action not delivered: ${e.javaClass.simpleName}")
                kept = action
                dartListening = false
            }
        }
    }

    /** The kept action, once; from now on Dart is listening. */
    fun take(): LaunchActionMsg? {
        dartListening = true
        return kept.also { kept = null }
    }

    /** The engine is going away: stop any send in flight. */
    fun close() = scope.cancel()
}
