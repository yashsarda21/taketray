package app.taketray.background

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.util.Log
import java.time.ZoneId

/**
 * The reminder alarms (D-105): the evening reminder and the 14-day
 * "Still shooting?", and (Phase 8, D-124) the copies reminder. All are `setAndAllowWhileIdle(RTC_WAKEUP, …)`:
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
    private val jobs: JobScheduler = context.getSystemService(JobScheduler::class.java)
    private val store = BackgroundStateStore(context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE))

    /**
     * With the evening reminder on: the next evening strictly after [nowMs],
     * except for a catch-up. When the alarm already armed
     * ([BackgroundStateStore.eveningArmedFor]) is due ([ReminderTimes.dueEvening]:
     * today's evening once its time has passed, or yesterday's), at most
     * [ReminderTimes.EVENING_CATCH_UP] (3 hours) has gone by since that
     * evening instant, and that evening's day is not handled yet
     * ([BackgroundStateStore.eveningHandledDay]), it keeps standing for that
     * evening, firing at max(that instant, [nowMs]): the alarm is inexact and
     * may come late, and a re-arm in between (the app opened at 21:01, or at
     * 00:05 for a 23:30 alarm, a clock correction, an update) must not move
     * it on. Later than 3 hours (a boot or an app open the next morning),
     * and with nothing armed for that evening (a fresh install, the reminder
     * just switched on, a new time), it never fires at once. With [firing]
     * (the receiver re-arming from the alarm itself) there is no catch-up.
     * Remembers the evening it armed for. Off: no alarm, and nothing armed
     * for.
     */
    fun armEvening(
        state: BackgroundState,
        nowMs: Long,
        firing: Boolean = false,
    ) {
        if (!state.eveningEnabled) {
            cancel(armedEveningAlarm(context))
            store.setEveningArmedFor(null)
            cancelEveningDeferral()
            return
        }
        if (state.eveningMinutes !in 0..ReminderTimes.LAST_MINUTE) {
            // Dart stores what the settings hold; the value itself is not logged.
            Log.w(LOG_TAG, "evening minutes out of range; clamped")
        }
        val due = ReminderTimes.dueEvening(store.eveningArmedFor(), nowMs, state.eveningMinutes, zone)
        val catchUp =
            due?.takeIf {
                !firing &&
                    nowMs - it <= ReminderTimes.EVENING_CATCH_UP.toMillis() &&
                    store.eveningHandledDay() != ReminderTimes.localDay(it, zone)
            }
        val armedFor = catchUp ?: ReminderTimes.nextEvening(nowMs, state.eveningMinutes, zone)
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, maxOf(armedFor, nowMs), eveningAlarm(context))
        store.setEveningArmedFor(armedFor)
        // A deferred evening (D-110) whose job Android lost (a reboot that did
        // not keep it): ask again. One that is pending is left alone.
        if (store.eveningDeferredFor() != null && jobs.getPendingJob(EveningDeferJobService.JOB_ID) == null) {
            deferEvening(NewClipsArming.QUIET_MS)
        }
    }

    /**
     * Defers the evening reminder to the one-off [EveningDeferJobService] in
     * [latencyMs] (D-110): a job, not an alarm, so no exact-alarm permission.
     * The caller has stored the evening ([BackgroundStateStore.setEveningDeferredFor]).
     */
    fun deferEvening(latencyMs: Long) {
        scheduleQuietJob(context, EveningDeferJobService.JOB_ID, EveningDeferJobService::class.java, latencyMs)
    }

    /** Nothing deferred any more: the reminder posted, was skipped or was switched off. */
    fun cancelEveningDeferral() {
        store.setEveningDeferredFor(null)
        jobs.cancel(EveningDeferJobService.JOB_ID)
    }

    /**
     * With Shooting mode on, the reminder on and not answered: an alarm at
     * [ReminderTimes.stillDueAt] (at [nowMs] when that has passed), carrying
     * the session's `sinceMs`. Once the receiver has handled this session
     * ([BackgroundStateStore.stillPostedSince]), no alarm: one per session,
     * however often the app or a reboot re-arms. With [armOverdue] false (the
     * app's own write) a due time that has passed arms nothing: the in-app
     * dialog asks, and an alarm already armed stays. Otherwise no alarm and
     * no Still shooting? notification.
     */
    fun armStill(
        state: BackgroundState,
        nowMs: Long,
        armOverdue: Boolean = true,
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
        val due = ReminderTimes.stillDueAt(since, zone)
        // The app's own write after the due time (armOverdue false): the in-app dialog asks. An alarm
        // already armed is left as it is, neither replaced "at once" nor cancelled.
        if (!armOverdue && due <= nowMs) return
        val at = maxOf(due, nowMs)
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, stillAlarm(context, since))
    }

    /**
     * The copies reminder (Phase 8, D-124): one alarm, for the earliest reminder
     * of [BackgroundState.usableCopiesReminders] that is not shown yet
     * ([BackgroundStateStore.copiesShown] differs from its batch time), at
     * [ReminderTimes.copiesDueAt] (at [nowMs] when that has passed). The alarm
     * carries no reel: the receiver shows every reminder that is due. No
     * reminder to wait for: no alarm. Reels that left the mirror lose their
     * shown mark. Independent of Shooting mode and of the other two reminders.
     */
    fun armCopies(
        state: BackgroundState,
        nowMs: Long,
    ) {
        val reminders = state.usableCopiesReminders()
        store.pruneCopiesShown(reminders.map { it.reelId }.toSet())
        val next =
            reminders
                .filter { store.copiesShown(it.reelId) != it.lastCopiedAtMs }
                .minOfOrNull { ReminderTimes.copiesDueAt(it.lastCopiedAtMs) }
        if (next == null) {
            cancel(armedCopiesAlarm(context))
            return
        }
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, maxOf(next, nowMs), copiesAlarm(context))
    }

    /** Removes the Still shooting? alarm; the notification stays. */
    fun cancelStill() = cancel(armedStillAlarm(context))

    /**
     * Cancels the alarm of [pending] and the PendingIntent itself. A cancel
     * looks the PendingIntent up (`FLAG_NO_CREATE`), so it makes none when
     * nothing was armed: null here.
     */
    private fun cancel(pending: PendingIntent?) {
        if (pending == null) return
        alarms.cancel(pending)
        pending.cancel()
    }

    companion object {
        const val ACTION_EVENING = "app.taketray.REMINDER_EVENING"
        const val ACTION_STILL = "app.taketray.REMINDER_STILL"
        const val ACTION_COPIES = "app.taketray.REMINDER_COPIES"

        /** The session a Still shooting? alarm or shade button belongs to (UTC ms). */
        const val EXTRA_SINCE_MS = "app.taketray.extra.SINCE_MS"

        /** Alarm request codes (the notifications' taps use the 1xx, 2xx and 3xx above them; the copies taps 1_000_000 and up). */
        const val REQUEST_EVENING_ALARM = 200
        const val REQUEST_STILL_ALARM = 300
        const val REQUEST_COPIES_ALARM = 400

        /** The broadcast the evening alarm delivers (the debug hook sends the same one). */
        internal fun eveningIntent(context: Context): Intent = Intent(context, ReminderReceiver::class.java).setAction(ACTION_EVENING)

        /** The broadcast the Still shooting? alarm delivers for the session [sinceMs]; null: without the session (cancelling). */
        internal fun stillIntent(
            context: Context,
            sinceMs: Long?,
        ): Intent {
            val intent = Intent(context, ReminderReceiver::class.java).setAction(ACTION_STILL)
            if (sinceMs != null) intent.putExtra(EXTRA_SINCE_MS, sinceMs)
            return intent
        }

        /** The broadcast the copies alarm delivers. */
        internal fun copiesIntent(context: Context): Intent = Intent(context, ReminderReceiver::class.java).setAction(ACTION_COPIES)

        private const val ARM = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT

        /** What a cancel looks up: the PendingIntent if the alarm was armed, never a new one (null). */
        private const val LOOK_UP = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE

        private fun eveningAlarm(context: Context): PendingIntent =
            PendingIntent.getBroadcast(context, REQUEST_EVENING_ALARM, eveningIntent(context), ARM)

        private fun armedEveningAlarm(context: Context): PendingIntent? =
            PendingIntent.getBroadcast(context, REQUEST_EVENING_ALARM, eveningIntent(context), LOOK_UP)

        private fun stillAlarm(
            context: Context,
            sinceMs: Long,
        ): PendingIntent = PendingIntent.getBroadcast(context, REQUEST_STILL_ALARM, stillIntent(context, sinceMs), ARM)

        private fun copiesAlarm(context: Context): PendingIntent =
            PendingIntent.getBroadcast(context, REQUEST_COPIES_ALARM, copiesIntent(context), ARM)

        private fun armedCopiesAlarm(context: Context): PendingIntent? =
            PendingIntent.getBroadcast(context, REQUEST_COPIES_ALARM, copiesIntent(context), LOOK_UP)

        /** Without the session: a PendingIntent is matched without its extras. */
        private fun armedStillAlarm(context: Context): PendingIntent? =
            PendingIntent.getBroadcast(context, REQUEST_STILL_ALARM, stillIntent(context, null), LOOK_UP)
    }
}
