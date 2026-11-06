package app.taketray.background

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.provider.MediaStore
import android.util.Log
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
    fun run() {
        try {
            val counted = update()
            if (store.state() != counted) update()
        } catch (e: Exception) {
            // The count failed: the notification stays as it was.
            Log.w(LOG_TAG, "new clips not counted: ${e.javaClass.simpleName}")
        }
        try {
            zones.record(nowMs(), zoneId())
        } catch (e: Exception) {
            Log.w(LOG_TAG, "zone not recorded: ${e.javaClass.simpleName}")
        }
        rearm()
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
     * the count already shown leaves it alone (never re-posted, Quiet); any
     * other count posts or updates it. The posted count is what the shade
     * shows: 0 whenever nothing is. Returns the state it worked on.
     */
    private fun update(): BackgroundState {
        val state = store.state()
        if (!state.shootingOn) {
            clear()
            return state
        }
        val found = counter.count(state)
        if (found.count == 0) {
            clear()
            return state
        }
        if (found.count == store.postedNewClips()) return state
        if (!notifier.canPost(Notifier.CHANNEL_NEW_CLIPS)) {
            // Not allowed: nothing shows, so nothing is remembered as shown,
            // and the next run after notifications are allowed posts.
            store.setPostedNewClips(0)
            return state
        }
        val picture = found.newest?.let { (volume, id) -> picture(volume, id) }
        store.setPostedNewClips(if (notifier.showNewClips(found.count, picture)) found.count else 0)
        return state
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
