package app.taketray.background

import android.app.Application
import android.app.NotificationManager
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Looper
import android.util.Log
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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

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
        // Off as Dart writes it (D-103): no session and no baselines.
        assertEquals(on.copy(shootingOn = false, sinceMs = null, baselines = emptyList()), store.state())
        assertNull("the job stops", jobs.getPendingJob(NewClipsJobService.JOB_ID))
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(alarm(app, ReminderScheduler.ACTION_STILL))
        // The evening reminder is not Shooting mode's: it stays.
        assertEquals("2026-11-05T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    /** Shooting mode on since [since] with baselines for [named] only (volumes never baselined are the point). */
    private fun onWithBaselines(vararg named: BackgroundState.Baseline) = on.copy(baselines = named.toList())

    @Test
    fun `turn off names a mounted volume with no baseline`() {
        // An SD card inserted mid-session (or whose read failed at switch-on): no baseline yet.
        val state = onWithBaselines(BackgroundState.Baseline(MAIN, "v1", 100))
        Receivers.volumes = { FakeVolumes(mapOf(MAIN to ("v1" to 140L), sd to ("c1" to 55L))) }
        armedAndPosted(state)
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)

        val tapped = store.shadeAction() ?: throw AssertionError("no shade action")
        assertEquals(setOf(VolumeGenerationMsg(MAIN, 140), VolumeGenerationMsg(sd, 55)), tapped.generations.toSet())
        assertEquals(2, tapped.generations.size)
    }

    @Test
    fun `turn off names each volume once, baselined or not, and the primary one is unchanged`() {
        val state = onWithBaselines(BackgroundState.Baseline(MAIN, "v1", 100), BackgroundState.Baseline(sd, "c1", 20))
        Receivers.volumes = { FakeVolumes(mapOf(MAIN to ("v1" to 140L), sd to ("c1" to 55L))) }
        armedAndPosted(state)
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)

        val generations = store.shadeAction()?.generations ?: throw AssertionError("no shade action")
        assertEquals(setOf(VolumeGenerationMsg(MAIN, 140), VolumeGenerationMsg(sd, 55)), generations.toSet())
        assertEquals(2, generations.size)
    }

    @Test
    fun `an unmounted volume with no baseline is not named`() {
        val state = onWithBaselines(BackgroundState.Baseline(MAIN, "v1", 100))
        // The card is not mounted at the tap: it is not among the volumes at all.
        Receivers.volumes = { FakeVolumes(mapOf(MAIN to ("v1" to 140L))) }
        armedAndPosted(state)
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)

        assertEquals(listOf(VolumeGenerationMsg(MAIN, 140)), store.shadeAction()?.generations)
    }

    @Test
    fun `a baselined volume rebuilt since is still left out, a card without a baseline is named`() {
        val state = onWithBaselines(BackgroundState.Baseline(MAIN, "old-version", 100))
        Receivers.volumes = { FakeVolumes(mapOf(MAIN to ("v1" to 140L), sd to ("c1" to 55L))) }
        armedAndPosted(state)
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)

        // The rebuilt volume's generations mean nothing against the old baseline (Dart resyncs it), the card is new.
        assertEquals(listOf(VolumeGenerationMsg(sd, 55)), store.shadeAction()?.generations)
    }

    @Test
    fun `a card without a baseline whose generation cannot be read is skipped and logged by class only`() {
        val state = onWithBaselines(BackgroundState.Baseline(MAIN, "v1", 100))
        Receivers.volumes = { FakeVolumes(mapOf(MAIN to ("v1" to 140L)), failing = setOf("broken-card")) }
        armedAndPosted(state)
        ShadowLog.clear()
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)

        assertEquals(listOf(VolumeGenerationMsg(MAIN, 140)), store.shadeAction()?.generations)
        val logs = ShadowLog.getLogsForTag(LOG_TAG).map { it.msg }
        assertEquals(listOf("volume generation not read: IllegalStateException"), logs)
        assertTrue(ShadowLog.getLogs().none { "broken-card" in it.msg })
        // The session still ends.
        assertEquals(state.copy(shootingOn = false, sinceMs = null, baselines = emptyList()), store.state())
    }

    @Test
    fun `a failing shade action never reaches Android, only its class is logged, and Still shooting goes`() {
        armedAndPosted()
        Receivers.volumes = { throw IllegalStateException("volumes-secret") }
        ShadowLog.clear()
        tap(ShadeActionReceiver.ACTION_TURN_OFF, since)
        val logs = ShadowLog.getLogsForTag(LOG_TAG)
        assertEquals(listOf("shade action failed: IllegalStateException"), logs.map { it.msg })
        assertEquals(Log.WARN, logs.single().type)
        assertTrue(ShadowLog.getLogs().none { "volumes-secret" in it.msg || it.throwable != null })
        // The button's own notification is gone even so, and nothing was recorded.
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(store.shadeAction())
        assertEquals(on, store.state())
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
