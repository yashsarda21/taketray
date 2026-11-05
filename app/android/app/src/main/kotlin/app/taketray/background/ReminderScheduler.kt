package app.taketray.background

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.time.ZoneId

/**
 * The two reminder alarms (D-105): the evening reminder and the 14-day
 * "Still shooting?". Both are `setAndAllowWhileIdle(RTC_WAKEUP, …)`:
 * inexact (Android may deliver them a little late, never early), allowed in
 * Doze, and in need of no exact-alarm permission (D-101). Each is one
 * explicit broadcast to [ReminderReceiver]; arming again replaces it.
 * Times are in [zone], read when the alarm is armed: a zone change re-arms.
 */
class ReminderScheduler(
    private val context: Context,
    private val zone: ZoneId = ZoneId.systemDefault(),
) {
    private val alarms: AlarmManager = context.getSystemService(AlarmManager::class.java)
    private val store = BackgroundStateStore(context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE))

    /**
     * With the evening reminder on: the next evening strictly after [nowMs],
     * except for a catch-up. When the alarm was already armed for today's
     * evening ([BackgroundStateStore.eveningArmedFor] is exactly today's
     * evening instant), that time has passed and today is not handled yet
     * ([BackgroundStateStore.eveningHandledDay]), it stays today's, at
     * max(that instant, [nowMs]): the alarm is inexact and may come late,
     * and a re-arm in between (the app opened at 21:01, a clock correction,
     * an update) must not move it to tomorrow. Nothing armed for today (a
     * fresh install, the reminder just switched on, a new time) never fires
     * at once. With [firing] (the receiver re-arming from the alarm itself)
     * there is no catch-up. Remembers the evening it armed for. Off: no
     * alarm, and nothing armed for.
     */
    fun armEvening(
        state: BackgroundState,
        nowMs: Long,
        firing: Boolean = false,
    ) {
        if (!state.eveningEnabled) {
            alarms.cancel(eveningAlarm(context))
            store.setEveningArmedFor(null)
            return
        }
        if (state.eveningMinutes !in 0..ReminderTimes.LAST_MINUTE) {
            // Dart stores what the settings hold; the value itself is not logged.
            Log.w(LOG_TAG, "evening minutes out of range; clamped")
        }
        val today = ReminderTimes.eveningToday(nowMs, state.eveningMinutes, zone)
        val armedForToday = store.eveningArmedFor() == today
        val catchUp = !firing && today <= nowMs && armedForToday && store.eveningHandledDay() != ReminderTimes.localDay(nowMs, zone)
        val armedFor = if (catchUp) today else ReminderTimes.nextEvening(nowMs, state.eveningMinutes, zone)
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, maxOf(armedFor, nowMs), eveningAlarm(context))
        store.setEveningArmedFor(armedFor)
    }

    /**
     * With Shooting mode on, the reminder on and not answered: an alarm at
     * [ReminderTimes.stillDueAt] (at [nowMs] when that has passed), carrying
     * the session's `sinceMs`. Once the receiver has handled this session
     * ([BackgroundStateStore.stillPostedSince]), no alarm: one per session,
     * however often the app or a reboot re-arms. Otherwise no alarm and no
     * Still shooting? notification.
     */
    fun armStill(
        state: BackgroundState,
        nowMs: Long,
    ) {
        val since = state.sinceMs
        if (!state.shootingOn || since == null || !state.stillReminderEnabled || state.stillAnswered) {
            cancelStill()
            Notifier(context).cancelStillShooting()
            return
        }
        if (store.stillPostedSince() == since) {
            // Posted already (and maybe still in the shade): nothing more to arm.
            cancelStill()
            return
        }
        val at = maxOf(ReminderTimes.stillDueAt(since, zone), nowMs)
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, stillAlarm(context, since))
    }

    /** Removes the Still shooting? alarm; the notification stays. */
    fun cancelStill() = alarms.cancel(stillAlarm(context, null))

    companion object {
        const val ACTION_EVENING = "app.taketray.REMINDER_EVENING"
        const val ACTION_STILL = "app.taketray.REMINDER_STILL"

        /** The session a Still shooting? alarm or shade button belongs to (UTC ms). */
        const val EXTRA_SINCE_MS = "app.taketray.extra.SINCE_MS"

        /** Alarm request codes (the notifications' taps use the 2xx and 3xx above them). */
        const val REQUEST_EVENING_ALARM = 200
        const val REQUEST_STILL_ALARM = 300

        private fun eveningAlarm(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                REQUEST_EVENING_ALARM,
                Intent(context, ReminderReceiver::class.java).setAction(ACTION_EVENING),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        /** [sinceMs] null: the same alarm for cancelling (a PendingIntent is matched without its extras). */
        private fun stillAlarm(
            context: Context,
            sinceMs: Long?,
        ): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).setAction(ACTION_STILL)
            if (sinceMs != null) intent.putExtra(EXTRA_SINCE_MS, sinceMs)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_STILL_ALARM,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}
