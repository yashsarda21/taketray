package app.taketray.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.taketray.media.Volumes

/**
 * Still shooting?'s **Turn off** and **Keep on** in the shade (D-105): they
 * work without opening the app. Not exported and without an intent filter:
 * only the notification's own explicit broadcasts reach it.
 *
 * Dart is the truth: each button names its session (`sinceMs`). The receiver
 * acts only while that session is the stored one and on; otherwise (an
 * older notification, Shooting mode already off) it only removes the
 * notification. What it did waits in the store as a shade action, which
 * Dart applies to the database at the next app start (Task 6).
 */
class ShadeActionReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val action = intent.action
        if (action != ACTION_TURN_OFF && action != ACTION_KEEP_ON) return
        val since = if (intent.hasExtra(ReminderScheduler.EXTRA_SINCE_MS)) intent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, 0) else null
        val app = context.applicationContext
        inBackground("shade action") {
            val store = Receivers.store(app)
            val notifier = Notifier(app)
            val state = store.state()
            if (since == null || !state.shootingOn || state.sinceMs != since) {
                notifier.cancelStillShooting()
                return@inBackground
            }
            val now = Receivers.nowMs()
            try {
                if (action == ACTION_TURN_OFF) turnOff(app, store, state, since, now) else keepOn(app, store, state, since, now)
            } finally {
                notifier.cancelStillShooting()
            }
        }
    }

    /**
     * Records the mounted volumes' current generations (where the scan may go
     * up to, so clips shot after the tap stay out; a volume with no baseline
     * is named too, so the clips shot on it before the tap still arrive),
     * writes the state off and stops
     * the job. The new-clips notification stays: those clips still arrive
     * when the app opens, and its scan clears it.
     */
    private fun turnOff(
        context: Context,
        store: BackgroundStateStore,
        state: BackgroundState,
        since: Long,
        now: Long,
    ) {
        val generations = generations(Receivers.volumes(context), state)
        store.putShadeAction(ShadeActionMsg(ShadeActionKindMsg.TURN_OFF, since, now, generations))
        val off = state.copy(shootingOn = false, sinceMs = null, baselines = emptyList())
        store.write(off)
        Receivers.arming().apply(context, off, keepNewClips = true)
    }

    /** Answers the reminder for this session: no alarm, no notification, and Dart marks it answered. */
    private fun keepOn(
        context: Context,
        store: BackgroundStateStore,
        state: BackgroundState,
        since: Long,
        now: Long,
    ) {
        store.putShadeAction(ShadeActionMsg(ShadeActionKindMsg.KEEP_ON, since, now, emptyList()))
        store.write(state.copy(stillAnswered = true))
        ReminderScheduler(context, Receivers.zone()).cancelStill()
    }

    companion object {
        const val ACTION_TURN_OFF = "app.taketray.SHADE_TURN_OFF"
        const val ACTION_KEEP_ON = "app.taketray.SHADE_KEEP_ON"

        /** The explicit broadcast for a shade button. */
        fun intent(
            context: Context,
            action: String,
            sinceMs: Long,
        ): Intent =
            Intent(context, ShadeActionReceiver::class.java)
                .setAction(action)
                .putExtra(ReminderScheduler.EXTRA_SINCE_MS, sinceMs)

        /**
         * Every mounted volume's current generation (where Dart's capped end
         * may read up to), sorted by name: a baselined volume whose MediaStore
         * version still matches its baseline's, and a volume with no baseline
         * yet (an SD card inserted during the session, or one whose read
         * failed at switch-on), whose clips shot before the tap Dart adds
         * (D-108, M-8). A rebuilt volume (its version is not the baseline's)
         * and an unmounted one are left out, and Dart skips them. A volume
         * whose read throws is left out too, logged by error class only
         * (D-10).
         */
        internal fun generations(
            volumes: Volumes,
            state: BackgroundState,
        ): List<VolumeGenerationMsg> {
            val baselined = state.baselines.associateBy { it.volumeName }
            return volumes.names().sorted().mapNotNull { name ->
                try {
                    val version = volumes.version(name) ?: return@mapNotNull null
                    val baseline = baselined[name]
                    if (baseline != null && baseline.version != version) {
                        null
                    } else {
                        VolumeGenerationMsg(name, volumes.generation(name))
                    }
                } catch (e: Exception) {
                    Log.w(LOG_TAG, "volume generation not read: ${e.javaClass.simpleName}")
                    null
                }
            }
        }
    }
}
