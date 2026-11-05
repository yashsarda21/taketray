package app.taketray.background

import android.app.Application
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
        assertEquals(5_000L, job.triggerContentUpdateDelay)
        assertEquals(30_000L, job.triggerContentMaxDelay)
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
                Arming { _, _ -> ran += "job"; throw IllegalStateException("boom") },
                Arming { _, _ -> ran += "alarms" },
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
}
