package app.taketray.background

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.provider.MediaStore
import android.util.Log
import java.time.ZoneId

/**
 * Arms the background work for a freshly written [BackgroundState]: the
 * notification channels, the new-clips job ([NewClipsArming], D-104) and the
 * reminder alarms ([ReminderArming], D-105). Called by
 * `BackgroundHostApiImpl.writeState` after the state is stored, by the
 * receivers that re-arm after a reboot, an update, a clock or zone change,
 * and by the shade's Turn off.
 */
fun interface Arming {
    /**
     * [keepNewClips]: with Shooting mode off, the new-clips notification
     * stays (the shade's Turn off: those clips still arrive when the app
     * opens). Every other caller removes it with the job.
     */
    fun apply(
        context: Context,
        state: BackgroundState,
        keepNewClips: Boolean,
    )

    /** The usual arming: Shooting mode off removes the new-clips notification too. */
    fun apply(
        context: Context,
        state: BackgroundState,
    ) = apply(context, state, keepNewClips = false)

    companion object {
        /** Arms nothing (tests). */
        val NONE = Arming { _, _, _ -> }

        /**
         * Both channels, so "New clips" and "Reminders" are in Android's
         * settings from the first write, before anything is posted.
         */
        val CHANNELS = Arming { context, _, _ -> Notifier(context).ensureChannels() }

        /**
         * Every part in order. Each part runs even when an earlier one throws
         * (a failed job must not leave the alarms unarmed); the first failure
         * is rethrown at the end.
         */
        fun of(vararg parts: Arming): Arming =
            Arming { context, state, keepNewClips ->
                var failure: Exception? = null
                for (part in parts) {
                    try {
                        part.apply(context, state, keepNewClips)
                    } catch (e: Exception) {
                        if (failure == null) failure = e
                    }
                }
                failure?.let { throw it }
            }

        /** What TakeTray arms: the channels, the new-clips job and the reminder alarms, on [nowMs] and [zone]. */
        fun background(
            nowMs: () -> Long = System::currentTimeMillis,
            zone: () -> ZoneId = ZoneId::systemDefault,
            armOverdueStill: Boolean = true,
        ): Arming = of(CHANNELS, NewClipsArming(), ReminderArming(nowMs, zone, armOverdueStill))
    }
}

/**
 * A one-off job that waits for the quiet (D-110): [latencyMs] of minimum
 * latency, an override deadline [NewClipsArming.SETTLE_DEADLINE_SLACK_MS]
 * after it (the deadline alarm wakes the phone, the delay alarm does not),
 * persisted. Scheduling over a pending job with the same id replaces it.
 * Returns whether Android accepted it.
 */
internal fun scheduleQuietJob(
    context: Context,
    jobId: Int,
    service: Class<*>,
    latencyMs: Long,
): Boolean {
    val job =
        JobInfo
            .Builder(jobId, ComponentName(context, service))
            .setMinimumLatency(latencyMs)
            .setOverrideDeadline(latencyMs + NewClipsArming.SETTLE_DEADLINE_SLACK_MS)
            .setPersisted(true)
            .build()
    val ok = context.getSystemService(JobScheduler::class.java).schedule(job) == JobScheduler.RESULT_SUCCESS
    if (!ok) Log.w(LOG_TAG, "one-off job not scheduled")
    return ok
}

/**
 * Arming's alarms part (D-105): the evening reminder, Still shooting? and
 * (Phase 8, D-124) the copies reminder ([ReminderScheduler]), in the zone of
 * the moment. Each is armed even when another fails.
 *
 * It also takes the evening reminder out of the shade when its claim, "You
 * shot 3 clips today", is no longer true ([dropStaleEvening]).
 */
class ReminderArming(
    private val nowMs: () -> Long = System::currentTimeMillis,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
    /**
     * False for the app's own `writeState` (final review M-2): with the app
     * open, an overdue Still shooting? is the in-app dialog's to ask, so this
     * arming does not arm an alarm "at once" (a notification that would post,
     * with sound, under the dialog). The receivers' re-arms (boot, update,
     * clock, zone) keep the default and arm it at once.
     */
    private val armOverdueStill: Boolean = true,
) : Arming {
    override fun apply(
        context: Context,
        state: BackgroundState,
        keepNewClips: Boolean,
    ) {
        val scheduler = ReminderScheduler(context, zone())
        val now = nowMs()
        try {
            try {
                scheduler.armEvening(state, now)
                dropStaleEvening(context, state, now)
            } finally {
                scheduler.armStill(state, now, armOverdue = armOverdueStill)
            }
        } finally {
            armCopies(context, scheduler, state, now)
        }
    }

    /**
     * The copies reminder (Phase 8, D-124): its alarm, and the removal of the
     * reminders of reels that left the mirror (their session ended). Every
     * part, also with Shooting mode off.
     */
    private fun armCopies(
        context: Context,
        scheduler: ReminderScheduler,
        state: BackgroundState,
        now: Long,
    ) {
        try {
            scheduler.armCopies(state, now)
        } finally {
            Notifier(context).cancelCopiesExcept(state.usableCopiesReminders().map { it.reelId }.toSet())
        }
    }

    /**
     * Removes the evening reminder when the reminder is off, or when no clip
     * shot today is waiting any more: neither in Dart's list
     * ([BackgroundState.waitingShotMs]) nor among the clips the app has not
     * scanned yet ([NewClipsCounter], the same two the alarm counted). Only
     * asks MediaStore while the reminder is in the shade, and keeps it when
     * that count fails (logged by error class only, D-10). Not for the alarm
     * itself: [Reminders.evening] arms without this, so it never removes the
     * reminder it is about to post.
     */
    private fun dropStaleEvening(
        context: Context,
        state: BackgroundState,
        nowMs: Long,
    ) {
        val notifier = Notifier(context)
        if (!state.eveningEnabled) {
            notifier.cancelEvening()
            return
        }
        if (!notifier.isEveningShowing()) return
        val today = ReminderTimes.startOfToday(nowMs, zone())
        if (state.waitingShotMs.any { it >= today }) return
        try {
            if (Receivers.counter(context).count(state).shotMs.any { it >= today }) return
        } catch (e: Exception) {
            Log.w(LOG_TAG, "evening reminder not checked: ${e.javaClass.simpleName}")
            return
        }
        notifier.cancelEvening()
    }
}

/**
 * Arming's job part (D-104). With Shooting mode on and full video access:
 * one JobScheduler job ([NewClipsJobService.JOB_ID]) that Android starts when
 * anything under the external video collection changes, 5 quiet minutes
 * after the last change (D-110; no practical maximum). Otherwise: no job, and
 * the new-clips notification is removed (posted count 0), unless the caller
 * keeps it (the shade's Turn off).
 *
 * A content-trigger job runs once per arming and cannot be persisted across
 * a reboot, so the job arms its successor after every run ([rearm]) and the
 * app and the boot receiver ([BootReceiver]) arm it again.
 */
class NewClipsArming(
    private val access: (Context) -> Boolean = NewClipsCounter::fullAccess,
) : Arming {
    /** From the app and the receivers: an identical job already pending is left alone. */
    override fun apply(
        context: Context,
        state: BackgroundState,
        keepNewClips: Boolean,
    ) {
        arm(context, state, replace = false, keepNewClips = keepNewClips)
    }

    /**
     * From the job itself, after a run (and when Android stops it). Android
     * still lists the running job as pending and drops it when the run ends,
     * so the successor is scheduled even when an identical job is listed.
     * Scheduling over a running job makes Android stop that run
     * (`onStopJob`), which is harmless: its work is done.
     */
    fun rearm(
        context: Context,
        state: BackgroundState,
    ) {
        arm(context, state, replace = true)
    }

    /** True when a job was scheduled. */
    internal fun arm(
        context: Context,
        state: BackgroundState,
        replace: Boolean,
        keepNewClips: Boolean = false,
    ): Boolean {
        val scheduler = context.getSystemService(JobScheduler::class.java)
        if (!state.shootingOn || !access(context)) {
            scheduler.cancel(NewClipsJobService.JOB_ID)
            scheduler.cancel(NewClipsSettleJobService.JOB_ID)
            if (!keepNewClips) {
                Notifier(context).cancelNewClips()
                BackgroundStateStore(context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)).setPostedNewClips(0)
            }
            return false
        }
        val job = jobInfo(context)
        if (!replace && scheduler.getPendingJob(NewClipsJobService.JOB_ID) == job) return false
        if (scheduler.schedule(job) != JobScheduler.RESULT_SUCCESS) {
            Log.w(LOG_TAG, "new clips job not scheduled")
            return false
        }
        return true
    }

    /**
     * Schedules the one-off settle job (D-110) to run in [latencyMs]: the
     * content job ran while the newest clip was under [QUIET_MS] old, so the
     * notification waits for it. Replaces a settle job already pending.
     *
     * `setMinimumLatency` counts from `SystemClock.elapsedRealtime`, which
     * keeps counting in deep sleep (unlike the content trigger's uptime
     * timer), but the delay alarm Android sets for it is not a wake-up alarm
     * (`TimeController.setDelayExpiredAlarmLocked`); the override deadline is
     * (`ELAPSED_REALTIME_WAKEUP`), so it is set just after the latency and the
     * phone is woken once to post. Persisted: it survives a reboot
     * (RECEIVE_BOOT_COMPLETED is already declared). Not an alarm: no exact
     * alarm permission.
     */
    fun settle(
        context: Context,
        latencyMs: Long,
    ) {
        scheduleQuietJob(context, NewClipsSettleJobService.JOB_ID, NewClipsSettleJobService::class.java, latencyMs)
    }

    /** Nothing left to wait for. */
    fun cancelSettle(context: Context) = context.getSystemService(JobScheduler::class.java).cancel(NewClipsSettleJobService.JOB_ID)

    companion object {
        /** The notification waits until the newest new clip is this old (D-110): the same 5 minutes as the update delay. */
        const val QUIET_MS = 300_000L

        /** Added to what is left of the quiet wait: DATE_ADDED has whole seconds and a job starts a little late. */
        const val SETTLE_MARGIN_MS = 5_000L

        /** How long after its latency the settle job's wake-up deadline is. */
        const val SETTLE_DEADLINE_SLACK_MS = 60_000L

        /** Quiet minutes after the last change before the job runs (D-110): each new clip restarts the wait. */
        const val UPDATE_DELAY_MS = QUIET_MS

        /**
         * "No max delay" (D-110). JobScheduler has no such value: a max left
         * unset (-1) is Android's own default of 2 minutes
         * (`JobStatus.DEFAULT_TRIGGER_MAX_DELAY`), which would run the job in
         * the middle of a shoot. So the max is explicit and so long (7 days)
         * that no shoot reaches it, and short enough for Android's clock
         * arithmetic (`Handler.postDelayed(uptime + delay)`) never to overflow.
         */
        const val MAX_DELAY_MS = 7L * 24 * 60 * 60 * 1000

        /** The job: a content trigger on every video volume, not persisted (content triggers cannot be). */
        fun jobInfo(context: Context): JobInfo =
            JobInfo
                .Builder(NewClipsJobService.JOB_ID, ComponentName(context, NewClipsJobService::class.java))
                .addTriggerContentUri(
                    JobInfo.TriggerContentUri(
                        MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL),
                        JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS,
                    ),
                ).setTriggerContentUpdateDelay(UPDATE_DELAY_MS)
                .setTriggerContentMaxDelay(MAX_DELAY_MS)
                .build()
    }
}
