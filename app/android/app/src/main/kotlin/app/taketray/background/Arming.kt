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
        ): Arming = of(CHANNELS, NewClipsArming(), ReminderArming(nowMs, zone))
    }
}

/**
 * Arming's alarms part (D-105): the evening reminder and Still shooting?
 * ([ReminderScheduler]), in the zone of the moment. The evening is armed
 * even when Still shooting? fails, and the other way round.
 */
class ReminderArming(
    private val nowMs: () -> Long = System::currentTimeMillis,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
) : Arming {
    override fun apply(
        context: Context,
        state: BackgroundState,
        keepNewClips: Boolean,
    ) {
        val scheduler = ReminderScheduler(context, zone())
        val now = nowMs()
        try {
            scheduler.armEvening(state, now)
        } finally {
            scheduler.armStill(state, now)
        }
    }
}

/**
 * Arming's job part (D-104). With Shooting mode on and full video access:
 * one JobScheduler job ([NewClipsJobService.JOB_ID]) that Android starts when
 * anything under the external video collection changes, at least 5 s after
 * the last change and at most 30 s after the first. Otherwise: no job, and
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

    companion object {
        const val UPDATE_DELAY_MS = 5_000L
        const val MAX_DELAY_MS = 30_000L

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
