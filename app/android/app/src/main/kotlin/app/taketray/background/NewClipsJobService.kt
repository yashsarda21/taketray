package app.taketray.background

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.provider.MediaStore
import android.util.Log
import app.taketray.BuildConfig
import app.taketray.media.Thumbnails
import app.taketray.media.ZoneChangeStore
import java.util.TimeZone
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * The new-clips job (D-104): Android starts it when the video library
 * changes ([NewClipsArming]), with no Flutter engine. It hands the work to one
 * background thread ([NewClipsJob.run]), then tells Android it is finished
 * without a retry: the run has already armed its successor.
 *
 * Not exported, and only the system may bind it (`BIND_JOB_SERVICE`, in the
 * manifest).
 */
class NewClipsJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val context = applicationContext
        executor.execute {
            try {
                newJob(context).run()
            } catch (e: Exception) {
                // NewClipsJob.run catches its own; this is building it failing.
                Log.w(LOG_TAG, "new clips job not run: ${e.javaClass.simpleName}")
            }
            jobFinished(params, false)
        }
        return true
    }

    /** Android stopped the run (its time ran out, or it was re-armed while running): arm again, no retry. */
    override fun onStopJob(params: JobParameters): Boolean {
        try {
            newJob(applicationContext).rearm()
        } catch (e: Exception) {
            Log.w(LOG_TAG, "new clips job not re-armed: ${e.javaClass.simpleName}")
        }
        return false
    }

    companion object {
        /** The job's id (the notification permission's request code has the same value; they never meet). */
        const val JOB_ID = 0x7A72

        /**
         * One thread for every run, so two runs never overlap. Tests make it
         * direct. Like [newJob] this is a test seam held in a static: the
         * Android tests run one at a time (Gradle's default, one test JVM),
         * and each puts back what it replaced.
         */
        @Volatile
        internal var executor: Executor = Executors.newSingleThreadExecutor()

        /** Builds a run on the phone's own parts. Tests inject theirs. */
        @Volatile
        internal var newJob: (Context) -> NewClipsJob = { NewClipsJob.forPhone(it) }
    }
}

/**
 * The settle job (D-110): a one-off job the content job schedules when it runs
 * while the newest new clip is under 5 minutes old, so the notification waits
 * for the quiet. It does the content job's counting and posting under the
 * same rule ([NewClipsJob.runSettle]) and schedules itself again while a
 * newer clip is still too fresh. It never re-arms the content trigger (that
 * would restart its watch); it only makes sure it is armed. A failed count asks
 * Android for a retry, and Android stopping the run does too.
 *
 * Not exported, and only the system may bind it.
 */
class NewClipsSettleJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val context = applicationContext
        NewClipsJobService.executor.execute {
            val done =
                try {
                    NewClipsJobService.newJob(context).runSettle()
                } catch (e: Exception) {
                    Log.w(LOG_TAG, "new clips settle job not run: ${e.javaClass.simpleName}")
                    false
                }
            jobFinished(params, !done)
        }
        return true
    }

    /** Android stopped the run: try again later. */
    override fun onStopJob(params: JobParameters): Boolean = true

    companion object {
        /** The settle job's id, next to the content job's. */
        const val JOB_ID = 0x7A73
    }
}

/**
 * One run of the new-clips job, with everything it touches injected. Every
 * step catches its own errors, logged by type only (D-10), so the run always
 * reaches the re-arming.
 */
class NewClipsJob(
    private val context: Context,
    private val store: BackgroundStateStore,
    private val counter: NewClipsCounter,
    private val notifier: Notifier,
    private val zones: ZoneChangeStore,
    private val arming: NewClipsArming,
    /** The newest clip's thumbnail (volume, MediaStore id); null or a throw: no picture. */
    private val thumbnail: (String, Long) -> Bitmap?,
    private val nowMs: () -> Long,
    private val zoneId: () -> String,
) {
    /**
     * 1. Update the notification ([update]). If Dart wrote a new state during
     *    the update (a scan in the app moved the baselines and cleared the
     *    notification), update once more on that state, so a count from
     *    before the scan does not stay in the shade.
     * 2. Record the phone's zone (spec §8.3a: every background job run).
     * 3. Arm the next run ([rearm]); with Shooting mode off that cancels instead.
     */
    fun run(ignoreQuiet: Boolean = false) {
        execute(ignoreQuiet, replaceContentJob = true)
    }

    /**
     * The settle job's run (D-110): the same work, but the content job is only
     * made sure of ([NewClipsArming.apply] leaves an identical pending job
     * alone), because re-arming it would restart its watch. False when the
     * count failed (the caller asks Android for a retry).
     */
    fun runSettle(): Boolean = execute(ignoreQuiet = false, replaceContentJob = false)

    private fun execute(
        ignoreQuiet: Boolean,
        replaceContentJob: Boolean,
    ): Boolean {
        var counted = true
        try {
            var outcome = update(ignoreQuiet)
            if (store.state() != outcome.state) outcome = update(ignoreQuiet)
            debugLog(outcome)
            // Wait for the quiet, or nothing left to wait for.
            if (outcome.settleInMs != null) arming.settle(context, outcome.settleInMs) else arming.cancelSettle(context)
        } catch (e: Exception) {
            // The count failed: the notification stays as it was. The content
            // job asks again in 5 minutes (no further video change may come);
            // the settle job is retried by Android (its caller).
            counted = false
            Log.w(LOG_TAG, "new clips not counted: ${e.javaClass.simpleName}")
            // The log line must not be able to skip the retry and the re-arm below.
            if (BuildConfig.DEBUG) {
                try {
                    debugLog(Outcome(store.state()))
                } catch (logError: Exception) {
                    Log.w(LOG_TAG, "debug log not written: ${logError.javaClass.simpleName}")
                }
            }
            if (replaceContentJob) retryLater()
        }
        try {
            zones.record(nowMs(), zoneId())
        } catch (e: Exception) {
            Log.w(LOG_TAG, "zone not recorded: ${e.javaClass.simpleName}")
        }
        if (replaceContentJob) {
            rearm()
        } else {
            try {
                arming.apply(context, store.state())
            } catch (e: Exception) {
                Log.w(LOG_TAG, "new clips job not armed: ${e.javaClass.simpleName}")
            }
        }
        return counted
    }

    /** Asks for a settle run in 5 minutes; with Shooting mode off the re-arm that follows cancels it. */
    private fun retryLater() {
        try {
            arming.settle(context, NewClipsArming.QUIET_MS)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "new clips retry not scheduled: ${e.javaClass.simpleName}")
        }
    }

    /** Arms the next run for the stored state (read again: Dart may have written meanwhile). */
    fun rearm() {
        try {
            arming.rearm(context, store.state())
        } catch (e: Exception) {
            Log.w(LOG_TAG, "new clips job not re-armed: ${e.javaClass.simpleName}")
        }
    }

    /**
     * Off: no notification. Otherwise the count: 0 removes the notification;
     * the count already shown leaves it alone (never re-posted); a newest
     * clip under 5 minutes old (D-110) neither posts nor updates, and asks for
     * a settle job; any other count posts or updates it. The posted count is
     * what the shade shows: 0 whenever nothing is.
     */
    private fun update(ignoreQuiet: Boolean): Outcome {
        val state = store.state()
        if (!state.shootingOn) {
            clear()
            return Outcome(state)
        }
        val found = counter.count(state)
        if (found.count == 0) {
            clear()
            return Outcome(state)
        }
        val fresh = found.lastTouchedMs?.let { nowMs() - it < NewClipsArming.QUIET_MS } ?: false
        if (found.count == store.postedNewClips()) return Outcome(state, fresh = fresh)
        if (!notifier.canPost(Notifier.CHANNEL_NEW_CLIPS)) {
            // Not allowed: nothing shows, so nothing is remembered as shown,
            // and the next run after notifications are allowed posts.
            store.setPostedNewClips(0)
            return Outcome(state, fresh = fresh)
        }
        if (!ignoreQuiet) {
            // A take still being recorded holds the post: the sound must not land in it.
            if (counter.recording(state)) return Outcome(state, NewClipsArming.QUIET_MS, recording = true, fresh = fresh)
            NewClipsCounter.quietWaitMs(found.lastTouchedMs, nowMs())?.let { return Outcome(state, it, fresh = fresh) }
        }
        val picture = found.newest?.let { (volume, id) -> picture(volume, id) }
        val posted = notifier.showNewClips(found.count, picture)
        store.setPostedNewClips(if (posted) found.count else 0)
        return Outcome(state, fresh = fresh, posted = posted)
    }

    /**
     * The state a run worked on, when to try again (null: not waiting for
     * anything), and what the quiet rule saw, for the debug log: whether a
     * take was in progress, whether the newest new clip was under 5 minutes
     * old, whether it posted.
     */
    private class Outcome(
        val state: BackgroundState,
        val settleInMs: Long? = null,
        val recording: Boolean = false,
        val fresh: Boolean = false,
        val posted: Boolean = false,
    )

    /**
     * Debug and profile builds only (`BuildConfig.DEBUG` is a constant false
     * in release, so the line is not in the release dex;
     * `tool/check_release_permissions` looks for it; Flutter's profile build
     * type is a copy of debug): what the quiet rule saw in a run, as the hand
     * check reads it from the process's own logcat. Three flags, no time and
     * no number, nothing else (D-10). Callers guard with `BuildConfig.DEBUG`
     * so that nothing is read in release to build the argument.
     */
    private fun debugLog(outcome: Outcome) {
        if (!BuildConfig.DEBUG) return
        Log.i(LOG_TAG, "quiet-rule: recording=${outcome.recording} fresh=${outcome.fresh} posted=${outcome.posted}")
    }

    private fun clear() {
        notifier.cancelNewClips()
        store.setPostedNewClips(0)
    }

    /** The shade never misses a count because of a thumbnail: any failure is no picture. */
    private fun picture(
        volume: String,
        id: Long,
    ): Bitmap? =
        try {
            thumbnail(volume, id)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "new clips thumbnail failed: ${e.javaClass.simpleName}")
            null
        } catch (e: OutOfMemoryError) {
            Log.w(LOG_TAG, "new clips thumbnail failed: ${e.javaClass.simpleName}")
            null
        }

    companion object {
        /** The thumbnail's longer side, in pixels. */
        const val THUMBNAIL_PX = 1024

        /** A run on the phone's MediaStore, preferences, notifications and job scheduler. */
        fun forPhone(context: Context): NewClipsJob {
            val prefs = context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
            return NewClipsJob(
                context = context,
                store = BackgroundStateStore(prefs),
                counter = NewClipsCounter.forPhone(context),
                notifier = Notifier(context),
                zones = ZoneChangeStore(prefs),
                arming = NewClipsArming(),
                thumbnail = { volume, id ->
                    val uri = ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(volume), id)
                    Thumbnails.bitmap(context.contentResolver, uri, THUMBNAIL_PX)
                },
                nowMs = System::currentTimeMillis,
                zoneId = { TimeZone.getDefault().id },
            )
        }
    }
}

/**
 * The deferred evening reminder's job (D-110): a one-off job the evening
 * alarm's work schedules when a clip is under 5 minutes old or a take is in
 * progress. It runs on the receivers' thread ([Receivers.executor]), so it
 * never overlaps a reminder, and calls [Reminders.eveningDeferred], which
 * posts when it is quiet, defers again, or skips the evening once its day is
 * over. It has its own id and service (not the settle job): a new-clips
 * settle job would replace it, and Shooting mode off cancels that one and not
 * this. A failure asks Android for a retry; so does Android stopping it.
 *
 * Not exported, and only the system may bind it.
 */
class EveningDeferJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val context = applicationContext
        Receivers.executor.execute {
            val done =
                try {
                    Reminders.forPhone(context).eveningDeferred()
                    true
                } catch (e: Exception) {
                    Log.w(LOG_TAG, "evening deferral not run: ${e.javaClass.simpleName}")
                    false
                }
            jobFinished(params, !done)
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    companion object {
        /** Next to the new-clips job (0x7A72) and its settle job (0x7A73). */
        const val JOB_ID = 0x7A74
    }
}
