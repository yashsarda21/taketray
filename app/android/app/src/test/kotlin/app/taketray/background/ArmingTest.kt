package app.taketray.background

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import app.taketray.media.MediaAccessChecker
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * Arming's job part (D-104): with Shooting mode on and full video access, one
 * content-trigger job on the video library; otherwise no job and no
 * new-clips notification.
 */
@RunWith(RobolectricTestRunner::class)
class ArmingTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val scheduler = app.getSystemService(JobScheduler::class.java)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val store = BackgroundStateStore(app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE))

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = 1_780_000_000_000,
            baselines = listOf(BackgroundState.Baseline(MediaStore.VOLUME_EXTERNAL_PRIMARY, "v1", 100)),
            watchedFolders = listOf("DCIM/Camera/"),
        )

    @Before
    fun setUp() {
        shadowOf(manager).setNotificationsEnabled(true)
        // The real access check: full video access on this SDK level.
        val full = if (Build.VERSION.SDK_INT >= 33) MediaAccessChecker.READ_MEDIA_VIDEO else MediaAccessChecker.READ_EXTERNAL_STORAGE
        shadowOf(app).grantPermissions(full)
    }

    private fun showNewClips() {
        Notifier(app).showNewClips(3, null)
        store.setPostedNewClips(3)
    }

    @Test
    fun `arming schedules the content trigger with the delays`() {
        NewClipsArming().apply(app, on)
        val job = scheduler.getPendingJob(NewClipsJobService.JOB_ID) ?: throw AssertionError("no job")
        assertEquals(0x7A72, job.id)
        assertEquals(ComponentName(app, NewClipsJobService::class.java), job.service)
        assertArrayEquals(
            arrayOf(
                JobInfo.TriggerContentUri(
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL),
                    JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS,
                ),
            ),
            job.triggerContentUris,
        )
        assertEquals("5 quiet minutes after the last change", 300_000L, job.triggerContentUpdateDelay)
        // Unset (-1) is not "no max": Android then uses its own 2 minute default
        // (JobStatus.DEFAULT_TRIGGER_MAX_DELAY), which would run the job in the
        // middle of a shoot. The max is so long that it never ends a shoot.
        assertTrue("an explicit, very long max (unset means Android's 2 minutes)", job.triggerContentMaxDelay >= 24L * 60 * 60 * 1000)
        assertTrue("the max stays far from overflowing Android's clock", job.triggerContentMaxDelay <= 30L * 24 * 60 * 60 * 1000)
        assertFalse("content triggers cannot be persisted", job.isPersisted)
    }

    @Test
    fun `arming twice keeps one job`() {
        val arming = NewClipsArming()
        assertTrue(arming.arm(app, on, replace = false))
        // The same job is already pending: it is left alone (scheduling again
        // would reset its content observer, and stop it if it is running).
        assertFalse(arming.arm(app, on, replace = false))
        arming.apply(app, on)
        assertEquals(1, scheduler.allPendingJobs.size)
    }

    @Test
    fun `a different pending job is replaced`() {
        val stale = JobInfo.Builder(NewClipsJobService.JOB_ID, ComponentName(app, NewClipsJobService::class.java)).setMinimumLatency(60_000).build()
        scheduler.schedule(stale)
        assertTrue(NewClipsArming().arm(app, on, replace = false))
        assertEquals(NewClipsArming.jobInfo(app), scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `the job re-arms even while its own job is listed`() {
        // While the job runs, Android still lists it as pending; it ends when
        // the run finishes, so the run must schedule its successor anyway.
        val arming = NewClipsArming()
        arming.apply(app, on)
        assertTrue(arming.arm(app, on, replace = true))
        assertEquals(1, scheduler.allPendingJobs.size)
    }

    @Test
    fun `arming off cancels the job and the notification`() {
        NewClipsArming().apply(app, on)
        showNewClips()
        NewClipsArming().apply(app, on.copy(shootingOn = false, sinceMs = null))
        assertNull(scheduler.getPendingJob(NewClipsJobService.JOB_ID))
        assertNull(shadowOf(manager).getNotification(Notifier.NEW_CLIPS))
        assertEquals(0, store.postedNewClips())
    }

    @Test
    fun `arming without full access cancels`() {
        NewClipsArming().apply(app, on)
        showNewClips()
        NewClipsArming(access = { false }).apply(app, on)
        assertNull(scheduler.getPendingJob(NewClipsJobService.JOB_ID))
        assertNull(shadowOf(manager).getNotification(Notifier.NEW_CLIPS))
        assertEquals(0, store.postedNewClips())
    }

    @Test
    fun `the background arming runs every part even when one fails`() {
        val ran = mutableListOf<String>()
        val arming =
            Arming.of(
                Arming { _, _, _ -> ran += "job"; throw IllegalStateException("boom") },
                Arming { _, _, _ -> ran += "alarms" },
            )
        try {
            arming.apply(app, on)
            fail("the first failure is rethrown")
        } catch (e: IllegalStateException) {
            assertEquals("boom", e.message)
        }
        assertEquals(listOf("job", "alarms"), ran)
    }

    @Test
    fun `the background arming arms the job`() {
        Arming.background().apply(app, on)
        assertEquals(NewClipsArming.jobInfo(app), scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `the background arming arms the alarms`() {
        val evening = on.copy(eveningEnabled = true, eveningMinutes = 21 * 60, stillReminderEnabled = true)
        val now = ReminderTestSupport.ms("2026-11-05T12:00:00Z")
        Arming.background(nowMs = { now }, zone = { ReminderTestSupport.LONDON }).apply(app, evening)
        assertEquals("2026-11-05T21:00:00Z", ReminderTestSupport.alarmAt(app, ReminderScheduler.ACTION_EVENING))
        // The session began in May: Still shooting? is due, so at once.
        assertEquals("2026-11-05T12:00:00Z", ReminderTestSupport.alarmAt(app, ReminderScheduler.ACTION_STILL))
    }

    // ---- Final review M-2: the app's own write leaves an overdue Still shooting? to the dialog ----

    private val stillSince = ReminderTestSupport.ms("2026-10-01T09:00:00Z")
    private val stillOn = on.copy(sinceMs = stillSince, stillReminderEnabled = true)
    private val stillDue = ReminderTimes.stillDueAt(stillSince, ReminderTestSupport.LONDON)

    private fun appArming(now: Long) = Arming.background(nowMs = { now }, zone = { ReminderTestSupport.LONDON }, armOverdueStill = false)

    private fun systemArming(now: Long) = Arming.background(nowMs = { now }, zone = { ReminderTestSupport.LONDON })

    private fun stillAlarm() = ReminderTestSupport.alarm(app, ReminderScheduler.ACTION_STILL)?.triggerAtMs

    @Test
    fun `an app write after Still shooting is due arms no still alarm`() {
        val now = stillDue + 3_600_000
        appArming(now).apply(app, stillOn.copy(eveningEnabled = true, eveningMinutes = 21 * 60))
        assertNull("the in-app dialog asks, not a notification that posts under it", stillAlarm())
        // The rest is armed as ever.
        assertNotNull(ReminderTestSupport.alarm(app, ReminderScheduler.ACTION_EVENING))
        assertNotNull(scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `an app write exactly at the due time arms none, one a moment before arms it`() {
        appArming(stillDue).apply(app, stillOn)
        assertNull(stillAlarm())
        appArming(stillDue - 1).apply(app, stillOn)
        assertEquals(stillDue, stillAlarm())
    }

    @Test
    fun `an app write before it is due arms it for the due time`() {
        appArming(stillDue - 86_400_000).apply(app, stillOn)
        assertEquals(stillDue, stillAlarm())
    }

    @Test
    fun `an alarm armed before it was due stays when the app writes after`() {
        appArming(stillDue - 86_400_000).apply(app, stillOn)
        appArming(stillDue + 60_000).apply(app, stillOn)
        // Not replaced "at once" and not cancelled: it is the one already on its way.
        assertEquals(stillDue, stillAlarm())
    }

    @Test
    fun `boot, update, clock and zone re-arms still arm an overdue one at once`() {
        val now = stillDue + 3_600_000
        systemArming(now).apply(app, stillOn)
        assertEquals(now, stillAlarm())
    }

    @Test
    fun `an app write still cancels the still alarm when it is answered or Shooting mode is off`() {
        systemArming(stillDue - 86_400_000).apply(app, stillOn)
        assertNotNull(stillAlarm())
        appArming(stillDue + 1_000).apply(app, stillOn.copy(stillAnswered = true))
        assertNull(stillAlarm())

        systemArming(stillDue - 86_400_000).apply(app, stillOn)
        appArming(stillDue + 1_000).apply(app, stillOn.copy(shootingOn = false, sinceMs = null))
        assertNull(stillAlarm())
    }

    @Test
    fun `arming creates the channels before anything is posted`() {
        assertNull(manager.getNotificationChannel(Notifier.CHANNEL_NEW_CLIPS))
        manager.createNotificationChannel(NotificationChannel("new_clips", "New clips", NotificationManager.IMPORTANCE_LOW))
        Arming.background().apply(app, BackgroundState.OFF)
        assertNull("the old quiet channel is gone from the first write", manager.getNotificationChannel("new_clips"))
        assertEquals("New clips", manager.getNotificationChannel(Notifier.CHANNEL_NEW_CLIPS)?.name)
        assertEquals("Reminders", manager.getNotificationChannel(Notifier.CHANNEL_REMINDERS)?.name)
        assertEquals(0, shadowOf(manager).size())
    }

    @Test
    fun `keeping new clips stops the job but keeps the notification`() {
        NewClipsArming().apply(app, on)
        showNewClips()
        Arming.background().apply(app, on.copy(shootingOn = false, sinceMs = null), keepNewClips = true)
        assertNull(scheduler.getPendingJob(NewClipsJobService.JOB_ID))
        assertNotNull(shadowOf(manager).getNotification(Notifier.NEW_CLIPS))
        assertEquals(3, store.postedNewClips())

        // Without it (every other caller): removed.
        Arming.background().apply(app, on.copy(shootingOn = false, sinceMs = null))
        assertNull(shadowOf(manager).getNotification(Notifier.NEW_CLIPS))
        assertEquals(0, store.postedNewClips())
    }
}
