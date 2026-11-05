package app.taketray.background

import android.app.Application
import android.app.NotificationManager
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import app.taketray.background.ReminderTestSupport.LONDON
import app.taketray.background.ReminderTestSupport.MAIN
import app.taketray.background.ReminderTestSupport.NINE_PM
import app.taketray.background.ReminderTestSupport.action
import app.taketray.background.ReminderTestSupport.alarm
import app.taketray.background.ReminderTestSupport.alarmAt
import app.taketray.background.ReminderTestSupport.ms
import app.taketray.background.ReminderTestSupport.notification
import app.taketray.media.MediaAccessChecker
import java.util.concurrent.Executor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * Still shooting?'s Turn off and Keep on from the shade (D-105): they act
 * only for their own session, record what Dart needs to apply them, and work
 * without the app.
 */
@RunWith(RobolectricTestRunner::class)
class ShadeActionReceiverTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val jobs = app.getSystemService(JobScheduler::class.java)

    private val now = ms("2026-11-05T10:15:00Z")
    private val since = ms("2026-10-20T09:00:00Z")
    private val sd = "1234-abcd"

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = since,
            baselines =
                listOf(
                    BackgroundState.Baseline(MAIN, "v1", 100),
                    // Rebuilt since (version v8 now), unmounted, and one whose generation cannot be read.
                    BackgroundState.Baseline(sd, "v7", 50),
                    BackgroundState.Baseline("gone", "v3", 10),
                    BackgroundState.Baseline("broken", "v1", 20),
                ),
            watchedFolders = listOf("DCIM/Camera/"),
            waitingShotMs = listOf(ms("2026-11-05T09:00:00Z")),
            eveningEnabled = true,
            eveningMinutes = NINE_PM,
            stillReminderEnabled = true,
        )

    @Before
    fun setUp() {
        prefs.edit().clear().commit()
        shadowOf(manager).setNotificationsEnabled(true)
        val full = if (Build.VERSION.SDK_INT >= 33) MediaAccessChecker.READ_MEDIA_VIDEO else MediaAccessChecker.READ_EXTERNAL_STORAGE
        shadowOf(app).grantPermissions(full)
        Receivers.executor = Executor { it.run() }
        Receivers.nowMs = { now }
        Receivers.zone = { LONDON }
        Receivers.volumes = { FakeVolumes(mapOf(MAIN to ("v1" to 140L), sd to ("v8" to 7L)), failing = setOf("broken")) }
    }

    @After
    fun tearDown() = Receivers.reset()

    /** Shooting mode on and armed, with Still shooting? and three new clips in the shade. */
    private fun armedAndPosted(state: BackgroundState = on) {
        store.write(state)
        Arming.background(nowMs = { now }, zone = { LONDON }).apply(app, state)
        Notifier(app).showNewClips(3, null)
        store.setPostedNewClips(3)
        Notifier(app).showStillShooting(since)
    }

    private fun tap(
        action: String,
        sinceMs: Long?,
    ) {
        val intent = Intent(app, ShadeActionReceiver::class.java).setAction(action)
        if (sinceMs != null) intent.putExtra(ReminderScheduler.EXTRA_SINCE_MS, sinceMs)
        ShadeActionReceiver().onReceive(app, intent)
    }

    @Test
    fun `turn off records the generations and stops the job`() {
        armedAndPosted()
        assertNotNull(jobs.getPendingJob(NewClipsJobService.JOB_ID))
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)

        // Only the volume whose version still matches; a failing read is skipped.
        assertEquals(
            ShadeActionMsg(ShadeActionKindMsg.TURN_OFF, since, now, listOf(VolumeGenerationMsg(MAIN, 140))),
            store.shadeAction(),
        )
        assertEquals(on.copy(shootingOn = false, sinceMs = null), store.state())
        assertNull("the job stops", jobs.getPendingJob(NewClipsJobService.JOB_ID))
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(alarm(app, ReminderScheduler.ACTION_STILL))
        // The evening reminder is not Shooting mode's: it stays.
        assertEquals("2026-11-05T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `turn off keeps the new clips notification`() {
        armedAndPosted()
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)
        // Those clips still arrive when the app opens; its scan clears it.
        assertNotNull(notification(app, Notifier.NEW_CLIPS))
        assertEquals(3, store.postedNewClips())
        assertNull(jobs.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `keep on marks answered and cancels`() {
        val recent = on.copy(sinceMs = ms("2026-11-01T09:00:00Z"))
        armedAndPosted(recent)
        assertNotNull(alarm(app, ReminderScheduler.ACTION_STILL))
        tap(ShadeActionReceiver.ACTION_KEEP_ON, recent.sinceMs)

        assertEquals(ShadeActionMsg(ShadeActionKindMsg.KEEP_ON, recent.sinceMs!!, now, emptyList()), store.shadeAction())
        assertEquals(recent.copy(stillAnswered = true), store.state())
        assertNull(alarm(app, ReminderScheduler.ACTION_STILL))
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        // Shooting mode stays on: the job and the new-clips notification are untouched.
        assertNotNull(jobs.getPendingJob(NewClipsJobService.JOB_ID))
        assertNotNull(notification(app, Notifier.NEW_CLIPS))
    }

    @Test
    fun `shade action for another session only cancels`() {
        val newer = on.copy(sinceMs = ms("2026-11-04T09:00:00Z"))
        for (action in listOf(ShadeActionReceiver.ACTION_TURN_OFF, ShadeActionReceiver.ACTION_KEEP_ON)) {
            armedAndPosted(newer)
            // A button from the older session's notification.
            tap(action, since)
            assertNull(notification(app, Notifier.STILL_SHOOTING))
            assertNull(store.shadeAction())
            assertEquals(newer, store.state())
            assertNotNull(jobs.getPendingJob(NewClipsJobService.JOB_ID))
            assertNotNull(alarm(app, ReminderScheduler.ACTION_STILL))
        }
        // Already off (a second tap, or turned off in the app): the same.
        armedAndPosted()
        store.write(on.copy(shootingOn = false, sinceMs = null))
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(store.shadeAction())
        // A button without its session: the same.
        armedAndPosted()
        tap(ShadeActionReceiver.ACTION_KEEP_ON, null)
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(store.shadeAction())
        assertEquals(on, store.state())
    }

    @Test
    fun `the shade buttons reach the receiver`() {
        // Tapping Keep on in the notification, as Android sends it.
        val recent = on.copy(sinceMs = ms("2026-11-01T09:00:00Z"))
        store.write(recent)
        Notifier(app).showStillShooting(recent.sinceMs!!)
        val n = notification(app, Notifier.STILL_SHOOTING) ?: throw AssertionError("no Still shooting?")
        n.action("Keep on").actionIntent.send()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(ShadeActionKindMsg.KEEP_ON, store.shadeAction()?.kind)
        assertNull(notification(app, Notifier.STILL_SHOOTING))
    }
}
