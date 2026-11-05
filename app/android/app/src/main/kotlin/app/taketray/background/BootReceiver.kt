package app.taketray.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Arms the job and the alarms again when Android has forgotten them or their
 * times have moved (D-105): after a reboot (`BOOT_COMPLETED`; a content-
 * trigger job and alarms do not survive one), after TakeTray is updated
 * (`MY_PACKAGE_REPLACED`) and when the clock is set (`TIME_SET`). A zone
 * change re-arms from TimeZoneChangedReceiver. Not exported: the system still
 * delivers its own broadcasts to it.
 *
 * Re-arming computes the next evening strictly after now, so a reboot at
 * 21:05 arms tomorrow's 21:00, not tonight's again.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (intent.action !in ACTIONS) return
        rearm(context.applicationContext)
    }

    companion object {
        val ACTIONS = setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED)

        /**
         * `Arming.apply` for the stored state, on the main thread (a few
         * system calls). A failure is logged by its class only and never
         * crashes the receiver.
         */
        fun rearm(
            context: Context,
            arming: Arming = Receivers.arming(),
        ) {
            try {
                arming.apply(context, Receivers.store(context).state())
            } catch (e: Exception) {
                Log.w(LOG_TAG, "re-arming failed: ${e.javaClass.simpleName}")
            }
        }
    }
}
