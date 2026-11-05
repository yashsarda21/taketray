package app.taketray.background

import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import app.taketray.R
import app.taketray.background.ReminderTestSupport.LONDON
import app.taketray.background.ReminderTestSupport.NINE_PM
import app.taketray.background.ReminderTestSupport.alarm
import app.taketray.background.ReminderTestSupport.alarmAt
import app.taketray.background.ReminderTestSupport.ms
import app.taketray.background.ReminderTestSupport.notification
import app.taketray.background.ReminderTestSupport.operation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowLog

/**
 * The reminder alarms (D-105): inexact, allowed while idle, explicit
 * broadcasts to ReminderReceiver, at the times ReminderTimes gives.
 */
@RunWith(RobolectricTestRunner::class)
class ReminderSchedulerTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val scheduler = ReminderScheduler(app, LONDON)
    private val now = ms("2026-11-05T12:00:00Z")
    private val since = ms("2026-11-01T03:00:00Z")

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = since,
            eveningEnabled = true,
            eveningMinutes = NINE_PM,
            stillReminderEnabled = true,
        )

    @Before
    fun setUp() {
        prefs.edit().clear().commit()
        shadowOf(manager).setNotificationsEnabled(true)
        ShadowLog.clear()
    }

    private fun postStill() {
        val n = Notification.Builder(app, Notifier.CHANNEL_REMINDERS).setSmallIcon(R.drawable.ic_stat_taketray).build()
        Notifier(app).ensureChannels()
        manager.notify(Notifier.STILL_SHOOTING, n)
    }

    @Test
    fun `evening armed inexact while idle at the next evening`() {
        scheduler.armEvening(on, now)
        val alarm = alarm(app, ReminderScheduler.ACTION_EVENING) ?: throw AssertionError("no evening alarm")
        assertEquals(AlarmManager.RTC_WAKEUP, alarm.getType())
        assertEquals(ms("2026-11-05T21:00:00Z"), alarm.triggerAtMs)
        assertTrue("allowed while idle (Doze)", alarm.isAllowWhileIdle)
        assertEquals("inexact: no exact-alarm permission", ShadowAlarmManager.WINDOW_HEURISTIC, alarm.windowLengthMs)
        val pending = shadowOf(operation(alarm))
        assertTrue(pending.isBroadcast)
        assertTrue(pending.isImmutable)
        assertEquals(ComponentName(app, ReminderReceiver::class.java), pending.savedIntent.component)
        assertEquals(ReminderScheduler.REQUEST_EVENING_ALARM, pending.requestCode)

        // Arming again replaces it: one evening alarm.
        scheduler.armEvening(on, ms("2026-11-05T22:00:00Z"))
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
        assertEquals(1, shadowOf(app.getSystemService(AlarmManager::class.java)).scheduledAlarms.size)
    }

    @Test
    fun `evening disabled cancels`() {
        scheduler.armEvening(on, now)
        assertNotNull(alarm(app, ReminderScheduler.ACTION_EVENING))
        scheduler.armEvening(on.copy(eveningEnabled = false), now)
        assertNull(alarm(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `evening minutes out of range are clamped and only that is logged`() {
        scheduler.armEvening(on.copy(eveningMinutes = 5000), now)
        assertEquals("2026-11-05T23:59:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
        scheduler.armEvening(on.copy(eveningMinutes = -7), now)
        assertEquals("2026-11-06T00:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
        val logs = ShadowLog.getLogsForTag(LOG_TAG)
        assertEquals(listOf("evening minutes out of range; clamped", "evening minutes out of range; clamped"), logs.map { it.msg })
        assertEquals(Log.WARN, logs.first().type)
        // A value in range logs nothing.
        ShadowLog.clear()
        scheduler.armEvening(on, now)
        assertTrue(ShadowLog.getLogsForTag(LOG_TAG).isEmpty())
    }

    @Test
    fun `still armed at 10 o'clock after 14 days with its session`() {
        scheduler.armStill(on, now)
        val alarm = alarm(app, ReminderScheduler.ACTION_STILL) ?: throw AssertionError("no still alarm")
        // On at 03:00 on 1 November: 14 days later it waits for 10:00.
        assertEquals(ms("2026-11-15T10:00:00Z"), alarm.triggerAtMs)
        assertEquals(AlarmManager.RTC_WAKEUP, alarm.getType())
        assertTrue(alarm.isAllowWhileIdle)
        assertEquals(ShadowAlarmManager.WINDOW_HEURISTIC, alarm.windowLengthMs)
        val pending = shadowOf(operation(alarm))
        assertTrue(pending.isBroadcast)
        assertTrue(pending.isImmutable)
        assertEquals(ComponentName(app, ReminderReceiver::class.java), pending.savedIntent.component)
        assertEquals(since, pending.savedIntent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, 0))
        assertEquals(ReminderScheduler.REQUEST_STILL_ALARM, pending.requestCode)
    }

    @Test
    fun `still due in the past arms at once`() {
        val old = on.copy(sinceMs = ms("2026-09-01T08:00:00Z"))
        scheduler.armStill(old, now)
        assertEquals(now, alarm(app, ReminderScheduler.ACTION_STILL)?.triggerAtMs)
    }

    @Test
    fun `still off, disabled or answered cancels the alarm and the notification`() {
        for (state in listOf(on.copy(shootingOn = false, sinceMs = null), on.copy(stillReminderEnabled = false), on.copy(stillAnswered = true))) {
            scheduler.armStill(on, now)
            postStill()
            scheduler.armStill(state, now)
            assertNull(alarm(app, ReminderScheduler.ACTION_STILL))
            assertNull(notification(app, Notifier.STILL_SHOOTING))
        }
    }

    @Test
    fun `still handled for this session is not armed again`() {
        store.setStillPostedSince(since)
        postStill()
        scheduler.armStill(on, now)
        assertNull(alarm(app, ReminderScheduler.ACTION_STILL))
        assertNotNull("the posted notification stays for the user to answer", notification(app, Notifier.STILL_SHOOTING))

        // A new session gets its own.
        val next = on.copy(sinceMs = ms("2026-11-04T09:00:00Z"))
        scheduler.armStill(next, now)
        assertEquals("2026-11-18T10:00:00Z", alarmAt(app, ReminderScheduler.ACTION_STILL))
        assertFalse(store.stillPostedSince() == next.sinceMs)
    }
}
