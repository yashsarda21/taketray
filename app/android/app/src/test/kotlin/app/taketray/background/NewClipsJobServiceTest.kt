package app.taketray.background

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import app.taketray.R
import app.taketray.media.ZoneChangeMsg
import app.taketray.media.ZoneChangeStore
import java.util.concurrent.Executor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowLog
import org.robolectric.shadows.ShadowJobService
import org.robolectric.util.ReflectionHelpers

/**
 * The new-clips job (D-104) as Android runs it: the real service, the real
 * state store, notification manager and job scheduler, and a real SQLite
 * video table. The run is made synchronous (a direct executor) and the
 * volume versions, the clock, the zone and the thumbnail are injected.
 */
@RunWith(RobolectricTestRunner::class)
class NewClipsJobServiceTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val zones = ZoneChangeStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val scheduler = app.getSystemService(JobScheduler::class.java)
    private val main = MediaStore.VOLUME_EXTERNAL_PRIMARY

    private val now = 1_781_000_000_000L

    /** What the job's clock says; a test moves it. */
    private var clockMs = now
    private var zone = "Europe/London"

    /** Every thumbnail asked for: one per notification posted. */
    private val thumbnails = mutableListOf<Pair<String, Long>>()
    private var thumbnail: (String, Long) -> Bitmap? = { _, _ -> Bitmap.createBitmap(64, 36, Bitmap.Config.ARGB_8888) }

    private val savedExecutor = NewClipsJobService.executor
    private val savedNewJob = NewClipsJobService.newJob

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = 1_780_000_000_000,
            baselines = listOf(BackgroundState.Baseline(main, "v1", 100)),
            watchedFolders = listOf("DCIM/Camera/"),
        )

    @Before
    fun setUp() {
        prefs.edit().clear().commit()
        shadowOf(manager).setNotificationsEnabled(true)
        SqlVideoProvider.install()
        NewClipsJobService.executor = Executor { it.run() }
        NewClipsJobService.newJob = { context ->
            NewClipsJob(
                context = context,
                store = BackgroundStateStore(prefs),
                counter = NewClipsCounter(context.contentResolver, { if (it == main) "v1" else null }, { true }, { clockMs }),
                notifier = Notifier(context),
                zones = ZoneChangeStore(prefs),
                arming = NewClipsArming(access = { true }),
                thumbnail = { volume, id ->
                    thumbnails += volume to id
                    thumbnail(volume, id)
                },
                nowMs = { clockMs },
                zoneId = { zone },
            )
        }
    }

    private fun jobNow() = NewClipsJobService.newJob(app)

    @After
    fun tearDown() {
        NewClipsJobService.executor = savedExecutor
        NewClipsJobService.newJob = savedNewJob
    }

    /** Starts the job as Android would and returns its shadow (finished or not). */
    private fun runJob(): ShadowJobService {
        val service = Robolectric.buildService(NewClipsJobService::class.java).create().get()
        assertTrue("the work runs off the main thread", service.onStartJob(ReflectionHelpers.callConstructor(JobParameters::class.java)))
        return Shadow.extract(service)
    }

    /** Starts the settle job as Android would and returns its shadow. */
    private fun runSettle(): ShadowJobService {
        val service = Robolectric.buildService(NewClipsSettleJobService::class.java).create().get()
        assertTrue("the work runs off the main thread", service.onStartJob(ReflectionHelpers.callConstructor(JobParameters::class.java)))
        return Shadow.extract(service)
    }

    private fun settle() = scheduler.getPendingJob(NewClipsSettleJobService.JOB_ID)

    /** A clip added [agoSec] seconds before the injected clock. */
    private fun addClip(
        id: Long,
        agoSec: Long,
        modifiedAgoSec: Long? = null,
    ) = SqlVideoProvider.add(
        id = id,
        generation = 100 + id,
        added = now / 1000 - agoSec,
        modified = modifiedAgoSec?.let { now / 1000 - it },
    )

    private fun notification(): Notification? = shadowOf(manager).getNotification(Notifier.NEW_CLIPS)

    private fun title() = notification()?.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()

    private fun assertFinishedAndArmed(job: ShadowJobService) {
        assertTrue("jobFinished called", job.isJobFinished)
        assertFalse("no retry: the content trigger is armed again instead", job.isRescheduleNeeded)
        assertEquals(NewClipsArming.jobInfo(app), scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `same count does not re-post`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        SqlVideoProvider.add(id = 2, generation = 102)
        runJob()
        assertEquals("2 new clips to tag", title())
        assertEquals(2, store.postedNewClips())
        assertEquals(listOf(main to 2L), thumbnails)

        // The job fires again (a pending insert turned into a finished one,
        // say) with the same count: nothing is posted again.
        val marker = notification()
        runJob()
        assertEquals(listOf(main to 2L), thumbnails)
        assertSame(marker, notification())

        // A third clip: the notification is updated in place, once.
        SqlVideoProvider.add(id = 3, generation = 103)
        runJob()
        assertEquals(listOf(main to 2L, main to 3L), thumbnails)
        assertEquals("3 new clips to tag", title())
        assertEquals(3, store.postedNewClips())
        assertEquals(1, shadowOf(manager).size())
    }

    @Test
    fun `after a dismiss, more clips post again and the same count does not`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        SqlVideoProvider.add(id = 2, generation = 102)
        runJob()
        assertEquals("2 new clips to tag", title())

        manager.cancel(Notifier.NEW_CLIPS) // the user swipes it away
        runJob()
        assertNull("the same count is not posted again", notification())

        SqlVideoProvider.add(id = 3, generation = 103)
        runJob()
        assertEquals("3 new clips to tag", title())
        assertEquals(Notifier.CHANNEL_NEW_CLIPS, notification()?.channelId)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel(Notifier.CHANNEL_NEW_CLIPS).importance)
    }

    @Test
    fun `zero cancels`() {
        // The app scanned (the baseline moved past every clip), then the job ran.
        store.write(on)
        Notifier(app).showNewClips(3, null)
        store.setPostedNewClips(3)
        SqlVideoProvider.add(id = 1, generation = 100)
        val job = runJob()
        assertNull(notification())
        assertEquals(0, store.postedNewClips())
        assertTrue(thumbnails.isEmpty())
        assertFinishedAndArmed(job)
    }

    @Test
    fun `off cancels and stops the job`() {
        store.write(on)
        NewClipsArming(access = { true }).apply(app, on)
        Notifier(app).showNewClips(3, null)
        store.setPostedNewClips(3)
        SqlVideoProvider.add(id = 1, generation = 101)
        store.write(on.copy(shootingOn = false, sinceMs = null))
        val job = runJob()
        assertNull(notification())
        assertEquals(0, store.postedNewClips())
        assertNull("not re-armed", scheduler.getPendingJob(NewClipsJobService.JOB_ID))
        assertTrue(job.isJobFinished)
        assertFalse(job.isRescheduleNeeded)
        assertEquals(emptyList<String>(), SqlVideoProvider.queries)
    }

    @Test
    fun `not allowed - nothing posted, nothing remembered as posted`() {
        shadowOf(manager).setNotificationsEnabled(false)
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        val job = runJob()
        assertNull(notification())
        assertEquals(0, store.postedNewClips())
        assertFinishedAndArmed(job)

        // Allowed again: the next run posts the same count.
        shadowOf(manager).setNotificationsEnabled(true)
        runJob()
        assertEquals("1 new clip to tag", title())
    }

    @Test
    fun `a thumbnail failure still posts`() {
        thumbnail = { _, _ -> throw IllegalArgumentException("decoder") }
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        val job = runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(notification()?.extras?.getParcelable(Notification.EXTRA_PICTURE) as Bitmap?)
        assertEquals(R.drawable.ic_stat_taketray, notification()?.smallIcon?.resId)
        assertEquals(1, store.postedNewClips())
        assertFinishedAndArmed(job)
    }

    @Test
    fun `a scan in the app during the run is not undone`() {
        // The app scans while the job loads the thumbnail: Dart moves the
        // baseline past the clips and clears the notification. The count the
        // job made before the scan must not stay in the shade.
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        SqlVideoProvider.add(id = 2, generation = 102)
        thumbnail = { _, _ ->
            store.write(on.copy(baselines = listOf(BackgroundState.Baseline(main, "v1", 102))))
            Notifier(app).cancelNewClips()
            store.setPostedNewClips(0)
            null
        }
        val job = runJob()
        assertNull(notification())
        assertEquals(0, store.postedNewClips())
        assertFinishedAndArmed(job)
    }

    @Test
    fun `job records the zone`() {
        store.write(on)
        runJob()
        zone = "Asia/Kolkata"
        store.write(on.copy(shootingOn = false, sinceMs = null))
        runJob() // even while off: every run records the zone (spec §8.3a)
        assertEquals(listOf(ZoneChangeMsg(now, "Europe/London"), ZoneChangeMsg(now, "Asia/Kolkata")), zones.pending())
    }

    @Test
    fun `job re-arms after every run`() {
        store.write(on)
        assertFinishedAndArmed(runJob()) // nothing new
        scheduler.cancelAll()
        SqlVideoProvider.add(id = 1, generation = 101)
        assertFinishedAndArmed(runJob()) // posted
        scheduler.cancelAll()
        assertFinishedAndArmed(runJob()) // same count
    }

    @Test
    fun `job re-arms after an error`() {
        store.write(on)
        Notifier(app).showNewClips(3, null)
        store.setPostedNewClips(3)
        SqlVideoProvider.failure = IllegalStateException("provider died")
        val job = runJob()
        // The error says nothing about the count: the notification stays as it was.
        assertNotNull(notification())
        assertEquals(3, store.postedNewClips())
        assertEquals(listOf(ZoneChangeMsg(now, "Europe/London")), zones.pending())
        assertFinishedAndArmed(job)

        // No cursor at all: the same.
        SqlVideoProvider.failure = null
        SqlVideoProvider.noCursor = true
        scheduler.cancelAll()
        assertFinishedAndArmed(runJob())
        assertNotNull(notification())
    }

    @Test
    fun `stopping re-arms and does not ask for a retry`() {
        store.write(on)
        val service = Robolectric.buildService(NewClipsJobService::class.java).create().get()
        assertFalse(service.onStopJob(ReflectionHelpers.callConstructor(JobParameters::class.java)))
        assertEquals(NewClipsArming.jobInfo(app), scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `the job service is not exported and only the system binds it`() {
        val info = app.packageManager.getServiceInfo(ComponentName(app, NewClipsJobService::class.java), 0)
        assertFalse(info.exported)
        assertEquals("android.permission.BIND_JOB_SERVICE", info.permission)
    }

    // ------------------------------------------------- the quiet wait (D-110)

    @Test
    fun `a newest clip 1 minute old posts nothing and settles in about 4 minutes`() {
        store.write(on)
        addClip(1, agoSec = 60)
        val job = runJob()
        assertNull("nothing is posted while the shoot may go on", notification())
        assertEquals(0, store.postedNewClips())
        assertTrue("no thumbnail is loaded for a post that does not happen", thumbnails.isEmpty())
        val settle = settle() ?: throw AssertionError("no settle job")
        assertEquals("the 4 minutes left plus the margin", 240_000L + NewClipsArming.SETTLE_MARGIN_MS, settle.minLatencyMillis)
        assertEquals(ComponentName(app, NewClipsSettleJobService::class.java), settle.service)
        assertNotEquals(NewClipsJobService.JOB_ID, settle.id)
        // A wakeup deadline: the delay alone does not wake a sleeping phone (the delay alarm is not a wakeup alarm).
        assertTrue(settle.maxExecutionDelayMillis > settle.minLatencyMillis)
        assertTrue("survives a reboot", settle.isPersisted)
        // The content trigger is armed as always.
        assertFinishedAndArmed(job)
    }

    @Test
    fun `a newest clip exactly 5 minutes old posts`() {
        store.write(on)
        addClip(1, agoSec = 300)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `a newest clip 1 second short of 5 minutes does not post`() {
        store.write(on)
        addClip(1, agoSec = 299)
        runJob()
        assertNull(notification())
        assertEquals(1_000L + NewClipsArming.SETTLE_MARGIN_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `an older newest clip posts and leaves no settle job`() {
        store.write(on)
        addClip(1, agoSec = 301)
        addClip(2, agoSec = 3_600)
        runJob()
        assertEquals("2 new clips to tag", title())
        assertNull(settle())
    }

    @Test
    fun `one fresh clip among old ones holds the whole count back`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addClip(2, agoSec = 900)
        addClip(3, agoSec = 30)
        runJob()
        assertNull(notification())
        assertEquals(270_000L + NewClipsArming.SETTLE_MARGIN_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `a clip finished just now counts as fresh even when it was added long ago`() {
        // A long recording's row is added when the recording starts and
        // modified when it ends.
        store.write(on)
        addClip(1, agoSec = 1_800, modifiedAgoSec = 10)
        runJob()
        assertNull(notification())
        assertEquals(290_000L + NewClipsArming.SETTLE_MARGIN_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `an old modified time does not make a fresh clip old`() {
        store.write(on)
        addClip(1, agoSec = 20, modifiedAgoSec = 86_400)
        runJob()
        assertNull(notification())
        assertEquals(280_000L + NewClipsArming.SETTLE_MARGIN_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `a clip with no time at all is not held back`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101, added = null, modified = null)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `an immediate run in the middle of a shoot posts nothing`() {
        // Android runs the content job at once at 40 changed URIs, however
        // long the update delay: the clip just recorded is seconds old.
        store.write(on)
        for (i in 1L..40L) addClip(i, agoSec = 40 - i)
        runJob()
        assertNull(notification())
        assertEquals(0, store.postedNewClips())
        assertEquals("at most the 5 minutes from now", NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `a clip a little ahead of the clock is fresh but waits at most 5 minutes`() {
        store.write(on)
        addClip(1, agoSec = -30)
        runJob()
        assertNull(notification())
        assertEquals(NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `a clip more than a minute ahead of the clock does not hold the post back and wakes nothing`() {
        // The clock was set back, or a file came with a future time: waiting
        // for it would wake the phone every 5 minutes for days.
        store.write(on)
        addClip(1, agoSec = -61)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `a clip a day ahead posts at once`() {
        store.write(on)
        addClip(1, agoSec = -86_400, modifiedAgoSec = -86_400)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `a clip a day ahead does not hide a clip that was just recorded`() {
        store.write(on)
        addClip(1, agoSec = -86_400)
        addClip(2, agoSec = 30)
        runJob()
        assertNull(notification())
        assertEquals(270_000L + NewClipsArming.SETTLE_MARGIN_MS, settle()?.minLatencyMillis)
    }

    // ------------------------------------ a recording in progress (D-110)

    private fun addPending(
        id: Long,
        agoSec: Long,
        modifiedAgoSec: Long? = null,
        path: String? = "DCIM/Camera/",
        generation: Long = 100 + id,
    ) = SqlVideoProvider.add(
        id = id,
        generation = generation,
        added = now / 1000 - agoSec,
        modified = modifiedAgoSec?.let { now / 1000 - it },
        pending = true,
        duration = null,
        size = 0,
        path = path,
    )

    @Test
    fun `a take in progress holds back an older finished clip and settles in 5 minutes`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 400)
        val job = runJob()
        assertNull("no sound in the middle of a take", notification())
        assertEquals(0, store.postedNewClips())
        assertTrue(thumbnails.isEmpty())
        assertEquals(NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
        assertFinishedAndArmed(job)
    }

    @Test
    fun `a take in progress also holds back the update of a showing notification`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        runJob()
        assertEquals("1 new clip to tag", title())
        addClip(2, agoSec = 3_000)
        addPending(3, agoSec = 100)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNotNull(settle())
    }

    @Test
    fun `the recording check is asked only when a post is possible`() {
        store.write(on)
        runJob() // nothing new
        assertEquals(0, SqlVideoProvider.pendingQueries)
        addClip(1, agoSec = 3_600)
        runJob() // posts: asked once
        assertEquals(1, SqlVideoProvider.pendingQueries)
        runJob() // the same count is showing: not asked again
        assertEquals(1, SqlVideoProvider.pendingQueries)
    }

    @Test
    fun `a pending row older than 3 hours is ignored and the clips post`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 10_800 + 1)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `a pending row outside the watched folders is ignored`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 10, path = "Download/")
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `a pending row below the baseline is ignored`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 10, generation = 50)
        runJob()
        assertEquals("1 new clip to tag", title())
    }

    @Test
    fun `a take that finishes is counted and waits 5 quiet minutes from its end`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 600)
        runJob()
        assertNull(notification())

        // The camera finishes the take 2 minutes later, at the clock's now + 100 s.
        clockMs = now + 100_000
        SqlVideoProvider.finish(2, modified = now / 1000 + 100)
        clockMs = now + 220_000
        runJob()
        assertNull("only 2 minutes since the end", notification())
        assertEquals(180_000L + NewClipsArming.SETTLE_MARGIN_MS, settle()?.minLatencyMillis)

        clockMs = now + 100_000 + 301_000
        runSettle()
        assertEquals("2 new clips to tag", title())
        assertNull(settle())
        assertTrue(notification()!!.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
    }

    @Test
    fun `the settle job during a take reschedules itself and posts when the take is over`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 50)
        runJob()
        val job = runSettle()
        assertFalse("no retry: the next settle job is scheduled instead", job.isRescheduleNeeded)
        assertNull(notification())
        assertEquals(NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)

        // The take was stopped without a clip (deleted): the row is gone.
        SqlVideoProvider.trash(2)
        runSettle()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    @Test
    fun `a failing recording check posts nothing and the content job retries in 5 minutes`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        SqlVideoProvider.pendingFailure = IllegalStateException("provider died")
        val job = runJob()
        assertNull("not knowing is not a reason to sound", notification())
        assertEquals(0, store.postedNewClips())
        assertEquals(NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
        assertFinishedAndArmed(job)

        // The settle job asks Android for a retry instead.
        scheduler.cancel(NewClipsSettleJobService.JOB_ID)
        val retry = runSettle()
        assertTrue(retry.isRescheduleNeeded)
        assertNull(notification())
    }

    @Test
    fun `a failed count in the content job schedules a retry in 5 minutes`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        SqlVideoProvider.failure = IllegalStateException("provider died")
        val job = runJob()
        assertNull(notification())
        assertEquals(NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
        assertFinishedAndArmed(job)

        SqlVideoProvider.failure = null
        SqlVideoProvider.noCursor = true
        scheduler.cancel(NewClipsSettleJobService.JOB_ID)
        runJob()
        assertEquals("no cursor at all: the same", NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
    }

    @Test
    fun `a failed count with Shooting mode off schedules no retry`() {
        store.write(on.copy(shootingOn = false, sinceMs = null, baselines = emptyList()))
        SqlVideoProvider.failure = IllegalStateException("provider died")
        runJob()
        assertNull(settle())
    }

    @Test
    fun `a pending row dated in the future does not hold the post or wake the phone`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = -86_400)
        runJob()
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }

    // ----------------------------- the debug log of the quiet rule (D-110)

    private fun quietLines() = ShadowLog.getLogsForTag(LOG_TAG).map { it.msg }.filter { it.startsWith("quiet-rule:") }

    @Test
    fun `the debug log says a take is in progress, counts only`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 100)
        ShadowLog.clear()
        runJob()
        assertEquals(listOf("quiet-rule: recording=true fresh=false posted=false"), quietLines())
    }

    @Test
    fun `the debug log says a fresh clip holds the post`() {
        store.write(on)
        addClip(1, agoSec = 60)
        ShadowLog.clear()
        runJob()
        assertEquals(listOf("quiet-rule: recording=false fresh=true posted=false"), quietLines())
    }

    @Test
    fun `the debug log says it posted`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        ShadowLog.clear()
        runJob()
        assertEquals(listOf("quiet-rule: recording=false fresh=false posted=true"), quietLines())
    }

    @Test
    fun `the debug log with nothing new says nothing is fresh`() {
        store.write(on)
        ShadowLog.clear()
        runJob()
        assertEquals(listOf("quiet-rule: recording=false fresh=false posted=false"), quietLines())
    }

    @Test
    fun `the settle job logs the same line and the line holds no text of a clip`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        ShadowLog.clear()
        clockMs = now + 301_000
        runSettle()
        assertEquals(listOf("quiet-rule: recording=false fresh=false posted=true"), quietLines())
        // D-10: only three flags, no number, no name, path, URI or id.
        assertTrue(quietLines().single().matches(Regex("quiet-rule: recording=(true|false) fresh=(true|false) posted=(true|false)")))
    }

    /** The prefs of the job's store throw once, on the first read after the failed count's warning. */
    private fun prefsThatThrowOnceAfterTheWarning(thrown: BooleanArray): android.content.SharedPreferences =
        java.lang.reflect.Proxy.newProxyInstance(
            javaClass.classLoader,
            arrayOf(android.content.SharedPreferences::class.java),
        ) { _, method, args ->
            val warned = ShadowLog.getLogsForTag(LOG_TAG).any { it.msg.startsWith("new clips not counted") }
            if (warned && !thrown[0] && (method.name.startsWith("get") || method.name == "contains")) {
                thrown[0] = true
                throw IllegalStateException("store died")
            }
            try {
                method.invoke(prefs, *(args ?: emptyArray()))
            } catch (e: java.lang.reflect.InvocationTargetException) {
                throw e.targetException
            }
        } as android.content.SharedPreferences

    @Test
    fun `a store that fails while the debug line is logged still reaches the retry and the re-arm`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        SqlVideoProvider.failure = IllegalStateException("provider died")
        val thrown = BooleanArray(1)
        val failing = prefsThatThrowOnceAfterTheWarning(thrown)
        NewClipsJobService.newJob = { context ->
            NewClipsJob(
                context = context,
                store = BackgroundStateStore(failing),
                counter = NewClipsCounter(context.contentResolver, { if (it == main) "v1" else null }, { true }, { clockMs }),
                notifier = Notifier(context),
                zones = ZoneChangeStore(prefs),
                arming = NewClipsArming(access = { true }),
                thumbnail = { _, _ -> null },
                nowMs = { clockMs },
                zoneId = { zone },
            )
        }
        ShadowLog.clear()
        val job = runJob()
        assertTrue("the store failed once, after the warning", thrown[0])
        // The log line cannot take the retry, the zone record or the re-arm with it.
        assertEquals(NewClipsArming.QUIET_MS, settle()?.minLatencyMillis)
        assertEquals(listOf(ZoneChangeMsg(now, "Europe/London")), zones.pending())
        assertFinishedAndArmed(job)
    }

    @Test
    fun `the debug log of a failed count says nothing was posted`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        SqlVideoProvider.failure = IllegalStateException("provider died")
        ShadowLog.clear()
        runJob()
        assertEquals(listOf("quiet-rule: recording=false fresh=false posted=false"), quietLines())
    }

    @Test
    fun `the debug run ignores a take in progress too`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        addPending(2, agoSec = 5)
        jobNow().run(ignoreQuiet = true)
        assertEquals("1 new clip to tag", title())
    }

    @Test
    fun `the settle job reschedules itself while a newer clip is under 5 minutes old`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        val first = settle() ?: throw AssertionError("no settle job")

        // The settle job runs; meanwhile another clip arrived 10 s ago.
        addClip(2, agoSec = 10)
        val job = runSettle()
        assertTrue("jobFinished called", job.isJobFinished)
        assertFalse("no retry: the next settle job is scheduled instead", job.isRescheduleNeeded)
        assertNull(notification())
        assertEquals(0, store.postedNewClips())
        val second = settle() ?: throw AssertionError("settle job gone")
        assertEquals(290_000L + NewClipsArming.SETTLE_MARGIN_MS, second.minLatencyMillis)
        assertNotEquals(first.minLatencyMillis, second.minLatencyMillis)
        // The content trigger stays the one that was pending.
        assertEquals(NewClipsArming.jobInfo(app), scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `the settle job after the quiet period posts once and stays silent after`() {
        store.write(on)
        addClip(1, agoSec = 100)
        addClip(2, agoSec = 90)
        runJob()
        assertNull(notification())

        // 5 minutes later (the clock is injected: the clips are now old).
        clockMs = now + 301_000
        runSettle()
        assertEquals("2 new clips to tag", title())
        assertEquals(2, store.postedNewClips())
        assertNull("no further settle job once it has posted", settle())
        assertTrue("only alerts once", notification()!!.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertEquals(Notifier.CHANNEL_NEW_CLIPS, notification()?.channelId)
        val marker = notification()

        // Another run with the same count: nothing again.
        runSettle()
        assertSame(marker, notification())
        assertEquals(1, thumbnails.size)
    }

    @Test
    fun `a showing notification is not updated while a newer clip is fresh`() {
        store.write(on)
        addClip(1, agoSec = 3_600)
        runJob()
        assertEquals("1 new clip to tag", title())

        clockMs = now + 100_000
        addClip(2, agoSec = -100 + 5) // 5 s old at the clock
        runJob()
        assertEquals("the shade keeps the count it had", "1 new clip to tag", title())
        assertEquals(1, store.postedNewClips())
        assertNotNull(settle())

        clockMs = now + 100_000 + 301_000
        runSettle()
        assertEquals("2 new clips to tag", title())
        assertTrue(notification()!!.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertNull(settle())
    }

    @Test
    fun `the settle job with Shooting mode off removes the notification and posts nothing`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        assertNotNull(settle())
        store.write(on.copy(shootingOn = false, sinceMs = null, baselines = emptyList()))
        runSettle()
        assertNull(notification())
        assertNull(settle())
    }

    @Test
    fun `arming off or without access cancels the settle job with the content job`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        assertNotNull(settle())
        NewClipsArming(access = { true }).apply(app, on.copy(shootingOn = false, sinceMs = null))
        assertNull(scheduler.getPendingJob(NewClipsJobService.JOB_ID))
        assertNull("the settle job goes with it", settle())

        store.write(on)
        runJob()
        assertNotNull(settle())
        NewClipsArming(access = { false }).apply(app, on)
        assertNull(settle())
    }

    @Test
    fun `a run that finds nothing new or nothing to wait for cancels the settle job`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        assertNotNull(settle())

        // The clip was tagged in the app meanwhile: the baseline moved past it.
        store.write(on.copy(baselines = listOf(BackgroundState.Baseline(main, "v1", 200))))
        runSettle()
        assertNull(settle())
        assertNull(notification())
    }

    @Test
    fun `the settle job records the zone and arms the content job only when it is missing`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        val before = scheduler.getPendingJob(NewClipsJobService.JOB_ID)
        runSettle()
        // The very same job: it was not scheduled again (that restarts the watch).
        assertSame(before, scheduler.getPendingJob(NewClipsJobService.JOB_ID))
        assertEquals(listOf(ZoneChangeMsg(now, "Europe/London")), zones.pending().takeLast(1))

        scheduler.cancel(NewClipsJobService.JOB_ID)
        runSettle()
        assertNotNull(scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `the settle job survives a failed count and asks for a retry when stopped`() {
        store.write(on)
        addClip(1, agoSec = 100)
        runJob()
        SqlVideoProvider.failure = IllegalStateException("provider down")
        val job = runSettle()
        assertTrue(job.isJobFinished)
        assertTrue("Android is asked for a retry (the one-off job is used up)", job.isRescheduleNeeded)
        SqlVideoProvider.failure = null

        val service = Robolectric.buildService(NewClipsSettleJobService::class.java).create().get()
        assertTrue(service.onStopJob(ReflectionHelpers.callConstructor(JobParameters::class.java)))
    }

    @Test
    fun `the settle job service is not exported and only the system binds it`() {
        val info = app.packageManager.getServiceInfo(ComponentName(app, NewClipsSettleJobService::class.java), 0)
        assertFalse(info.exported)
        assertEquals("android.permission.BIND_JOB_SERVICE", info.permission)
    }

    @Test
    fun `the debug run ignores the quiet wait`() {
        store.write(on)
        addClip(1, agoSec = 5)
        val job = jobNow()
        job.run(ignoreQuiet = true)
        assertEquals("1 new clip to tag", title())
        assertNull(settle())
    }
}
