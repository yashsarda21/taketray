package app.taketray.background

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import app.taketray.background.ReminderTestSupport.LONDON
import app.taketray.background.ReminderTestSupport.MAIN
import app.taketray.background.ReminderTestSupport.NINE_PM
import app.taketray.background.ReminderTestSupport.alarmAt
import app.taketray.background.ReminderTestSupport.ms
import app.taketray.background.ReminderTestSupport.notification
import app.taketray.media.MediaAccessChecker
import app.taketray.media.TimeZoneChangedReceiver
import app.taketray.media.ZoneChangeStore
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
 * Re-arming (D-105): after a reboot, an update, a clock change and a zone
 * change, the job and both alarms are armed again for the stored state, at
 * times computed from the new now and zone.
 */
@RunWith(RobolectricTestRunner::class)
class BootReceiverTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val jobs = app.getSystemService(JobScheduler::class.java)
    private val alarms = app.getSystemService(AlarmManager::class.java)

    private var now = ms("2026-11-05T12:00:00Z")
    private val since = ms("2026-11-01T03:00:00Z")

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = since,
            baselines = listOf(BackgroundState.Baseline(MAIN, "v1", 100)),
            watchedFolders = listOf("DCIM/Camera/"),
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
        SqlVideoProvider.install()
        Receivers.executor = Executor { it.run() }
        Receivers.nowMs = { now }
        Receivers.zone = { LONDON }
        Receivers.counter = { NewClipsCounter(it.contentResolver, { volume -> if (volume == MAIN) "v1" else null }, { true }) }
    }

    @After
    fun tearDown() = Receivers.reset()

    private fun send(action: String) = BootReceiver().onReceive(app, Intent(action))

    private fun nothingArmed() {
        jobs.cancelAll()
        alarms.cancel(
            android.app.PendingIntent.getBroadcast(
                app,
                ReminderScheduler.REQUEST_EVENING_ALARM,
                Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_EVENING),
                android.app.PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        alarms.cancel(
            android.app.PendingIntent.getBroadcast(
                app,
                ReminderScheduler.REQUEST_STILL_ALARM,
                Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_STILL),
                android.app.PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        assertTrue(shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    private fun assertArmed(
        evening: String,
        still: String?,
    ) {
        assertEquals(NewClipsArming.jobInfo(app), jobs.getPendingJob(NewClipsJobService.JOB_ID))
        assertEquals(evening, alarmAt(app, ReminderScheduler.ACTION_EVENING))
        assertEquals(still, alarmAt(app, ReminderScheduler.ACTION_STILL))
    }

    @Test
    fun `boot re-arms the job and alarms`() {
        // Stored before the reboot; a reboot forgets the job and the alarms.
        store.write(on)
        send(Intent.ACTION_BOOT_COMPLETED)
        assertArmed(evening = "2026-11-05T21:00:00Z", still = "2026-11-15T10:00:00Z")
        // And the channels are in Android's settings.
        assertNotNull(manager.getNotificationChannel(Notifier.CHANNEL_NEW_CLIPS))
        assertNotNull(manager.getNotificationChannel(Notifier.CHANNEL_REMINDERS))
    }

    @Test
    fun `update and clock change re-arm`() {
        store.write(on)
        send(Intent.ACTION_MY_PACKAGE_REPLACED)
        assertArmed(evening = "2026-11-05T21:00:00Z", still = "2026-11-15T10:00:00Z")

        // The clock is moved forward to 22:00, past an evening that has not run: at once.
        nothingArmed()
        now = ms("2026-11-05T22:00:00Z")
        send(Intent.ACTION_TIME_CHANGED)
        assertArmed(evening = "2026-11-05T22:00:00Z", still = "2026-11-15T10:00:00Z")
        // Once it has run, the next clock change arms tomorrow's.
        ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_EVENING))
        nothingArmed()
        send(Intent.ACTION_TIME_CHANGED)
        assertArmed(evening = "2026-11-06T21:00:00Z", still = "2026-11-15T10:00:00Z")
    }

    @Test
    fun `a reboot just after the evening fired does not fire it twice`() {
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        now = ms("2026-11-05T21:00:30Z")
        ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_EVENING))
        assertNotNull(notification(app, Notifier.EVENING))
        manager.cancel(Notifier.EVENING)

        nothingArmed()
        now = ms("2026-11-05T21:05:00Z")
        send(Intent.ACTION_BOOT_COMPLETED)
        // Strictly after now: tomorrow's, not tonight's again.
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `zone change re-arms`() {
        store.write(on)
        // The process default (Receivers.zone) is still London; the broadcast names the new zone.
        TimeZoneChangedReceiver().onReceive(app, Intent(Intent.ACTION_TIMEZONE_CHANGED).putExtra(Intent.EXTRA_TIMEZONE, "Asia/Kolkata"))
        // 21:00 in India is 15:30 UTC; 10:00 there is 04:30 UTC.
        assertArmed(evening = "2026-11-05T15:30:00Z", still = "2026-11-15T04:30:00Z")
        assertEquals("Asia/Kolkata", ZoneChangeStore(prefs).pending().last().zoneId)

        // Back to London.
        TimeZoneChangedReceiver().onReceive(app, Intent(Intent.ACTION_TIMEZONE_CHANGED).putExtra(Intent.EXTRA_TIMEZONE, "Europe/London"))
        assertArmed(evening = "2026-11-05T21:00:00Z", still = "2026-11-15T10:00:00Z")
    }

    @Test
    fun `off re-arms nothing and removes what is left`() {
        store.write(on.copy(shootingOn = false, sinceMs = null, eveningEnabled = false))
        Notifier(app).showNewClips(2, null)
        send(Intent.ACTION_BOOT_COMPLETED)
        assertNull(jobs.getPendingJob(NewClipsJobService.JOB_ID))
        assertTrue(shadowOf(alarms).scheduledAlarms.isEmpty())
        assertNull(notification(app, Notifier.NEW_CLIPS))
    }

    @Test
    fun `other broadcasts do nothing`() {
        store.write(on)
        send(Intent.ACTION_SCREEN_ON)
        send(Intent.ACTION_TIMEZONE_CHANGED)
        assertNull(jobs.getPendingJob(NewClipsJobService.JOB_ID))
        assertTrue(shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    @Test
    fun `a failing arming does not crash the receiver, and only its class is logged`() {
        store.write(on)
        ShadowLog.clear()
        BootReceiver.rearm(app, Arming { _, _, _ -> throw IllegalStateException("scheduler gone") })
        val logs = ShadowLog.getLogsForTag(LOG_TAG)
        assertEquals(listOf("re-arming failed: IllegalStateException"), logs.map { it.msg })
        assertEquals(Log.WARN, logs.single().type)
        // D-10: the exception's message (it may name a path or a time) is never logged.
        assertTrue(ShadowLog.getLogs().none { "scheduler gone" in it.msg || it.throwable != null })
    }
}
