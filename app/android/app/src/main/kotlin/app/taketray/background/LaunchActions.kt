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
 * Launch actions (D-103, D-124): what a notification tap asks the app to open.
 * Flutter's own deep linking is off, because MainActivity is exported for the
 * launcher and any app could otherwise open any route (D-101). Instead a
 * notification's intent carries [EXTRA_OPEN] with one of three allow-listed
 * values, and `doneEditing` also [EXTRA_REEL_ID], the reel it is for: the only
 * payload there is, checked here and again by Dart. Anything else is ignored.
 */
object LaunchActions {
    const val EXTRA_OPEN = "app.taketray.extra.OPEN"
    const val EXTRA_REEL_ID = "app.taketray.extra.REEL_ID"

    private val VALUES =
        mapOf(
            "toTag" to LaunchActionMsg.TO_TAG,
            "reels" to LaunchActionMsg.REELS,
            "doneEditing" to LaunchActionMsg.DONE_EDITING,
        )

    /**
     * The explicit MainActivity intent a notification uses for [action]. It
     * brings the app's task to the front (NEW_TASK, as a PendingIntent starts it
     * from outside an activity) and reaches the running activity through
     * onNewIntent (CLEAR_TOP with SINGLE_TOP). Each action has its own
     * identifier, and a Done editing intent one per reel, so PendingIntents for
     * them never replace each other (PendingIntent compares intents without
     * their extras). [reelId] is used for [LaunchActionMsg.DONE_EDITING] only,
     * which needs a valid one ([BackgroundState.MAX_REEL_ID]): otherwise
     * [IllegalArgumentException].
     */
    fun intent(
        context: Context,
        action: LaunchActionMsg,
        reelId: Long? = null,
    ): Intent {
        val value = VALUES.entries.first { it.value == action }.key
        val intent =
            Intent(context, MainActivity::class.java)
                .putExtra(EXTRA_OPEN, value)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (action != LaunchActionMsg.DONE_EDITING) return intent.setIdentifier("taketray-open-$value")
        require(reelId != null && reelId in 1..BackgroundState.MAX_REEL_ID) { "Done editing needs a usable reel id" }
        return intent.setIdentifier("taketray-open-$value-$reelId").putExtra(EXTRA_REEL_ID, reelId)
    }

    /**
     * The launch in [intent], read once: both extras are removed whatever they
     * held, so the same intent (an activity re-created with it) gives nothing
     * the second time. Null when there is none, when the value is not exactly
     * `toTag`, `reels` or `doneEditing` (another app can send anything), and
     * when the activity was opened from Recents
     * (FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY: Android replays the first intent,
     * extras and all). Only `doneEditing` has a reel, and only a valid reel id
     * (a Long from 1 to [BackgroundState.MAX_REEL_ID]) counts; otherwise it is
     * still a `doneEditing` launch, with no reel, and Dart opens Reels.
     */
    fun read(intent: Intent?): LaunchMsg? {
        if (intent == null) return null
        val value: String?
        val reel: Long
        try {
            value = if (intent.hasExtra(EXTRA_OPEN)) intent.getStringExtra(EXTRA_OPEN) else null
            reel = intent.getLongExtra(EXTRA_REEL_ID, -1)
        } catch (e: RuntimeException) {
            // Extras another app made unreadable (BadParcelableException).
            Log.w(LOG_TAG, "launch intent unreadable: ${e.javaClass.simpleName}")
            return null
        } finally {
            strip(intent)
        }
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val action = VALUES[value] ?: return null
        val reelId = if (action == LaunchActionMsg.DONE_EDITING && reel in 1..BackgroundState.MAX_REEL_ID) reel else null
        return LaunchMsg(action, reelId)
    }

    /** Removes both extras, so the intent gives nothing a second time; extras that cannot be read are logged by class only. */
    private fun strip(intent: Intent) {
        try {
            intent.removeExtra(EXTRA_OPEN)
            intent.removeExtra(EXTRA_REEL_ID)
        } catch (e: RuntimeException) {
            Log.w(LOG_TAG, "launch intent not cleared: ${e.javaClass.simpleName}")
        }
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
 * by class only and never stops the action. [onDoneEditing] does the same for
 * a Done editing action that names a reel (the copies reminder's **Done
 * editing** button, like **Tag now**, leaves its notification behind).
 */
class LaunchActionRelay(
    private val send: suspend (LaunchMsg) -> Unit,
    private val scope: CoroutineScope = MainScope(),
    private val onToTag: () -> Unit = {},
    private val onDoneEditing: (Long) -> Unit = {},
) {
    companion object {
        /** MainActivity's relay: opening To tag removes the evening reminder, Done editing that reel's copies reminder. */
        fun forActivity(
            context: Context,
            send: suspend (LaunchMsg) -> Unit,
            scope: CoroutineScope = MainScope(),
        ): LaunchActionRelay {
            val notifier = Notifier(context.applicationContext)
            return LaunchActionRelay(send, scope, onToTag = notifier::cancelEvening, onDoneEditing = notifier::cancelCopies)
        }
    }

    private var kept: LaunchMsg? = null
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
        if (action.action == LaunchActionMsg.TO_TAG) {
            try {
                onToTag()
            } catch (e: RuntimeException) {
                Log.w(LOG_TAG, "evening reminder not removed: ${e.javaClass.simpleName}")
            }
        }
        val reelId = action.reelId
        if (action.action == LaunchActionMsg.DONE_EDITING && reelId != null) {
            try {
                onDoneEditing(reelId)
            } catch (e: RuntimeException) {
                Log.w(LOG_TAG, "copies reminder not removed: ${e.javaClass.simpleName}")
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
    fun take(): LaunchMsg? {
        dartListening = true
        return kept.also { kept = null }
    }

    /** The engine is going away: stop any send in flight. */
    fun close() = scope.cancel()
}
