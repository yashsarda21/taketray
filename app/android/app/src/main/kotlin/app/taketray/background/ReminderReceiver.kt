package app.taketray.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.time.ZoneId

/**
 * Where the reminder alarms land (D-105). Only [ReminderScheduler]'s own
 * explicit broadcasts reach it: it is not exported and has no intent
 * filter. The work (the evening count queries MediaStore) runs on the
 * receivers' thread ([inBackground]).
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val action = intent.action
        if (action != ReminderScheduler.ACTION_EVENING && action != ReminderScheduler.ACTION_STILL) return
        val since = if (intent.hasExtra(ReminderScheduler.EXTRA_SINCE_MS)) intent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, 0) else null
        val app = context.applicationContext
        inBackground("reminder") {
            val reminders = Reminders.forPhone(app)
            if (action == ReminderScheduler.ACTION_EVENING) {
                reminders.evening()
            } else if (since != null) {
                reminders.still(since)
            }
        }
    }
}

/**
 * One reminder alarm's work, with everything it touches injected. Nothing it
 * reads is logged but error classes (D-10).
 */
class Reminders(
    private val store: BackgroundStateStore,
    private val scheduler: ReminderScheduler,
    private val counter: NewClipsCounter,
    private val notifier: Notifier,
    private val nowMs: Long,
    private val zone: ZoneId,
) {
    /**
     * 1. Arm the next evening (tomorrow's) first, so nothing below can lose it.
     * 2. If the reminder is on and today's evening is not handled yet, mark it
     *    handled (once a local day, posted or not: a re-arm later today then
     *    arms tomorrow's), and count today's waiting clips: the scanned ones
     *    Dart lists ([BackgroundState.waitingShotMs]) and the ones the app has
     *    not scanned yet ([NewClipsCounter]), shot at or after the start of
     *    the local day.
     * 3. One or more: post the evening reminder. None: nothing (quiet, even
     *    if older clips wait).
     */
    fun evening() {
        val state = store.state()
        scheduler.armEvening(state, nowMs, firing = true)
        if (!state.eveningEnabled) return
        val day = ReminderTimes.localDay(nowMs, zone)
        // Handled already today (the clock moved back, a trip west): once a day.
        if (store.eveningHandledDay() == day) return
        store.setEveningHandledDay(day)
        val today = ReminderTimes.startOfToday(nowMs, zone)
        val waiting = state.waitingShotMs.count { it >= today }
        val count = waiting + counter.count(state).shotMs.count { it >= today }
        if (count < 1) return
        notifier.showEvening(count)
    }

    /**
     * Posts Still shooting? for the session that started at [sinceMs], if it
     * is still the stored one, on, the reminder on, not answered, and not
     * handled already. It is marked handled before posting: one per session
     * at most, even if the post fails or notifications are off.
     */
    fun still(sinceMs: Long) {
        val state = store.state()
        if (!state.shootingOn || state.sinceMs != sinceMs || !state.stillReminderEnabled || state.stillAnswered) return
        if (store.stillPostedSince() == sinceMs) return
        store.setStillPostedSince(sinceMs)
        notifier.showStillShooting(sinceMs)
    }

    companion object {
        /** A run on the phone's own parts ([Receivers]). */
        fun forPhone(context: Context): Reminders {
            val zone = Receivers.zone()
            return Reminders(
                store = Receivers.store(context),
                scheduler = ReminderScheduler(context, zone),
                counter = Receivers.counter(context),
                notifier = Notifier(context),
                nowMs = Receivers.nowMs(),
                zone = zone,
            )
        }
    }
}
