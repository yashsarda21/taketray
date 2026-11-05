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
                counter = NewClipsCounter(context.contentResolver, { if (it == main) "v1" else null }, { true }),
                notifier = Notifier(context),
                zones = ZoneChangeStore(prefs),
                arming = NewClipsArming(access = { true }),
                thumbnail = { volume, id ->
                    thumbnails += volume to id
                    thumbnail(volume, id)
                },
                nowMs = { now },
                zoneId = { zone },
            )
        }
    }

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
}
