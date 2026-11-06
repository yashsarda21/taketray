package app.taketray.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
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
     * 1. Note the evening this alarm stood for ([ReminderTimes.dueEvening] of
     *    the armed evening: yesterday's when it is delivered after midnight;
     *    else now), then arm the next evening first, so nothing below can
     *    lose it.
     * 2. If the reminder is on and that evening's day is not handled yet,
     *    mark it handled (once per evening, posted or not: a re-arm later
     *    then arms the next one), and count that day's waiting clips: the
     *    scanned ones Dart lists ([BackgroundState.waitingShotMs]) and the
     *    ones the app has not scanned yet ([NewClipsCounter]), shot at or
     *    after the start of that local day.
     * 3. One or more: post the evening reminder. None: nothing (quiet, even
     *    if older clips wait). Either way, a reminder left from an earlier
     *    evening goes: it is replaced, or no longer true. So does it when the
     *    reminder is off. (A repeat for an evening already handled leaves
     *    the one in the shade alone.)
     */
    fun evening() {
        val state = store.state()
        // Read before re-arming, which moves it to the next evening.
        val evening = ReminderTimes.dueEvening(store.eveningArmedFor(), nowMs, state.eveningMinutes, zone) ?: nowMs
        val day = ReminderTimes.localDay(evening, zone)
        scheduler.armEvening(state, nowMs, firing = true)
        if (!state.eveningEnabled) {
            notifier.cancelEvening()
            return
        }
        // Handled already (the clock moved back, a trip west): once per evening.
        if (store.eveningHandledDay() == day) return
        settleEvening(state, evening, day)
    }

    /**
     * The deferred evening reminder's job (D-110). Nothing deferred, or the
     * reminder switched off, or its evening handled meanwhile: nothing, and
     * the job goes. The local day of the evening over: skipped, and handled,
     * so it never says "today" for yesterday. Otherwise [settleEvening] again.
     */
    fun eveningDeferred() {
        val state = store.state()
        val evening = store.eveningDeferredFor()
        if (evening == null || !state.eveningEnabled) {
            scheduler.cancelEveningDeferral()
            return
        }
        val day = ReminderTimes.localDay(evening, zone)
        if (store.eveningHandledDay() == day) {
            scheduler.cancelEveningDeferral()
            return
        }
        if (ReminderTimes.localDay(nowMs, zone) != day) {
            store.setEveningHandledDay(day)
            scheduler.cancelEveningDeferral()
            return
        }
        settleEvening(state, evening, day)
    }

    /**
     * Waits for the quiet, then posts. When the newest unscanned clip is under
     * 5 minutes old, or a take is in progress (the new-clips job's rule,
     * D-110), or MediaStore cannot say, the evening is deferred
     * ([ReminderScheduler.deferEvening]) and not handled yet. When quiet: mark
     * it handled (once per evening, posted or not), count that day's waiting
     * clips at this moment, and post or not.
     */
    private fun settleEvening(
        state: BackgroundState,
        evening: Long,
        day: Long,
    ) {
        val found: NewClipsCounter.NewClips
        val wait: Long?
        try {
            found = counter.count(state)
            wait = if (counter.recording(state)) NewClipsArming.QUIET_MS else NewClipsCounter.quietWaitMs(found.lastTouchedMs, nowMs)
        } catch (e: Exception) {
            // Not knowing is not quiet; the same evening is tried again.
            Log.w(LOG_TAG, "evening clips not counted: ${e.javaClass.simpleName}")
            defer(evening, NewClipsArming.QUIET_MS)
            return
        }
        if (wait != null) {
            defer(evening, wait)
            return
        }
        scheduler.cancelEveningDeferral()
        store.setEveningHandledDay(day)
        val since = ReminderTimes.startOfToday(evening, zone)
        val waiting = state.waitingShotMs.count { it >= since }
        val count = waiting + found.shotMs.count { it >= since }
        if (count < 1) {
            // Quiet, and yesterday's reminder, if it is still there, is not true any more.
            notifier.cancelEvening()
            return
        }
        notifier.showEvening(count)
    }

    private fun defer(
        evening: Long,
        latencyMs: Long,
    ) {
        store.setEveningDeferredFor(evening)
        scheduler.deferEvening(latencyMs)
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
