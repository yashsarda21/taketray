package app.taketray.background

import android.app.Application
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import app.taketray.MainActivity
import app.taketray.background.ReminderTestSupport.LONDON
import app.taketray.background.ReminderTestSupport.MAIN
import app.taketray.background.ReminderTestSupport.NINE_PM
import app.taketray.background.ReminderTestSupport.action
import app.taketray.background.ReminderTestSupport.alarm
import app.taketray.background.ReminderTestSupport.alarmAt
import app.taketray.background.ReminderTestSupport.fire
import app.taketray.background.ReminderTestSupport.ms
import app.taketray.background.ReminderTestSupport.notification
import app.taketray.background.ReminderTestSupport.text
import app.taketray.background.ReminderTestSupport.title
import java.util.concurrent.Executor
import org.junit.After
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
 * The reminders as they fire (D-105): the real receiver, store, alarm and
 * notification managers, and a real SQLite video table for the clips the app
 * has not scanned yet. The clock is 21:00:30 on 5 November in London.
 */
@RunWith(RobolectricTestRunner::class)
class ReminderReceiverTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)

    private var now = ms("2026-11-05T21:00:30Z")
    private val since = ms("2026-10-01T09:00:00Z")

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
        SqlVideoProvider.install()
        Receivers.executor = Executor { it.run() }
        Receivers.nowMs = { now }
        Receivers.zone = { LONDON }
        Receivers.counter = { NewClipsCounter(it.contentResolver, { volume -> if (volume == MAIN) "v1" else null }, { true }) }
    }

    @After
    fun tearDown() = Receivers.reset()

    private fun evening() = ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_EVENING))

    private fun still(sinceMs: Long) =
        ReminderReceiver().onReceive(
            app,
            Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_STILL).putExtra(ReminderScheduler.EXTRA_SINCE_MS, sinceMs),
        )

    private fun eveningTitle() = notification(app, Notifier.EVENING)?.title()

    @Test
    fun `evening counts only today's waiting clips`() {
        // Scanned and waiting (Dart's list): one from last night, two from today.
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-04T23:59:59.999Z"), ms("2026-11-05T00:00:00Z"), ms("2026-11-05T09:00:00Z"))))
        // Not scanned yet: today (DATE_TAKEN), today (no DATE_TAKEN: DATE_ADDED), yesterday, and one the app has (below the baseline).
        SqlVideoProvider.add(id = 1, generation = 101, taken = ms("2026-11-05T10:00:00Z"))
        SqlVideoProvider.add(id = 2, generation = 102, taken = null, added = ms("2026-11-05T11:00:00Z") / 1000)
        SqlVideoProvider.add(id = 3, generation = 103, taken = ms("2026-11-04T18:00:00Z"))
        SqlVideoProvider.add(id = 4, generation = 99, taken = ms("2026-11-05T08:00:00Z"))
        evening()
        assertEquals("You shot 4 clips today. Tag them?", eveningTitle())
    }

    @Test
    fun `evening with none today posts nothing`() {
        // Older clips wait, but none was shot today: quiet.
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-01T10:00:00Z"), ms("2026-11-04T23:59:59Z"))))
        SqlVideoProvider.add(id = 1, generation = 101, taken = ms("2026-11-04T20:00:00Z"))
        evening()
        assertNull(notification(app, Notifier.EVENING))
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `evening re-arms before posting`() {
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        val failing =
            object : Notifier(app) {
                override fun showEvening(count: Int): Boolean = throw IllegalStateException("post failed")
            }
        val reminders = Reminders(store, ReminderScheduler(app, LONDON), Receivers.counter(app), failing, now, LONDON)
        try {
            reminders.evening()
            fail("the post throws")
        } catch (e: IllegalStateException) {
            assertEquals("post failed", e.message)
        }
        // Tomorrow's evening was armed before the post failed.
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `evening posts the copy and opens To tag`() {
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        // Armed by the scheduler and fired as Android would.
        ReminderScheduler(app, LONDON).armEvening(store.state(), ms("2026-11-05T20:00:00Z"))
        fire(app, ReminderScheduler.ACTION_EVENING)
        val n = notification(app, Notifier.EVENING) ?: throw AssertionError("no evening reminder")
        assertEquals("You shot 1 clip today. Tag it?", n.title())
        assertEquals("Takes a few minutes, one tap per clip.", n.text())
        assertEquals(Notifier.CHANNEL_REMINDERS, n.channelId)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel(n.channelId).importance)
        assertTrue("auto-cancel", n.flags and android.app.Notification.FLAG_AUTO_CANCEL != 0)
        assertEquals(listOf("Tag now"), n.actions.map { it.title.toString() })
        val body = shadowOf(n.contentIntent)
        val tagNow = shadowOf(n.action("Tag now").actionIntent)
        for (pending in listOf(body, tagNow)) {
            assertTrue(pending.isActivity)
            assertTrue(pending.isImmutable)
            assertTrue(pending.flags and PendingIntent.FLAG_UPDATE_CURRENT != 0)
            val intent = Intent(pending.savedIntent)
            assertEquals(ComponentName(app, MainActivity::class.java), intent.component)
            assertEquals(LaunchActionMsg.TO_TAG, LaunchActions.read(intent))
        }
        assertEquals(setOf(Notifier.REQUEST_EVENING_BODY, Notifier.REQUEST_EVENING_TAG_NOW), setOf(body.requestCode, tagNow.requestCode))
        // Re-armed for tomorrow.
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
        // More than one: the plural.
        store.write(store.state().copy(waitingShotMs = listOf(ms("2026-11-06T09:00:00Z"), ms("2026-11-06T10:00:00Z"))))
        now = ms("2026-11-06T21:00:10Z")
        evening()
        assertEquals("You shot 2 clips today. Tag them?", eveningTitle())
    }

    @Test
    fun `evening posts at most once a local day`() {
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        evening()
        assertNotNull(notification(app, Notifier.EVENING))
        manager.cancel(Notifier.EVENING) // swiped away

        // The clock is set back to 20:59 and the alarm fires again at 21:00.
        now = ms("2026-11-05T21:00:05Z")
        evening()
        assertNull("one evening reminder a day", notification(app, Notifier.EVENING))

        // The next day it posts again.
        store.write(store.state().copy(waitingShotMs = listOf(ms("2026-11-06T09:00:00Z"))))
        now = ms("2026-11-06T21:00:30Z")
        evening()
        assertEquals("You shot 1 clip today. Tag it?", eveningTitle())
    }

    @Test
    fun `evening disabled posts nothing and arms nothing`() {
        store.write(on.copy(eveningEnabled = false, waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        evening()
        assertNull(notification(app, Notifier.EVENING))
        assertNull(alarm(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `evening not allowed posts nothing and does not throw`() {
        shadowOf(manager).setNotificationsEnabled(false)
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        evening()
        assertEquals(0, shadowOf(manager).size())
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `a failed count posts nothing and still re-arms`() {
        // "You shot 1 clip today" would be wrong if MediaStore could not say how many more there are.
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-05T09:00:00Z"))))
        SqlVideoProvider.noCursor = true
        evening()
        assertNull(notification(app, Notifier.EVENING))
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `still posts the copy with Turn off and Keep on`() {
        store.write(on)
        // The session is older than 14 days: the alarm is due at once.
        ReminderScheduler(app, LONDON).armStill(store.state(), now)
        fire(app, ReminderScheduler.ACTION_STILL)
        val n = notification(app, Notifier.STILL_SHOOTING) ?: throw AssertionError("no Still shooting?")
        assertEquals("Still shooting?", n.title())
        assertEquals("Shooting mode has been on for 14 days. Turn it off?", n.text())
        assertEquals(Notifier.CHANNEL_REMINDERS, n.channelId)
        assertEquals(listOf("Turn off", "Keep on"), n.actions.map { it.title.toString() })
        // The body opens Reels, where the app asks again.
        val body = shadowOf(n.contentIntent)
        assertTrue(body.isActivity)
        assertTrue(body.isImmutable)
        assertEquals(LaunchActionMsg.REELS, LaunchActions.read(Intent(body.savedIntent)))
        // The buttons are broadcasts to the shade receiver that name the session.
        val turnOff = shadowOf(n.action("Turn off").actionIntent)
        val keepOn = shadowOf(n.action("Keep on").actionIntent)
        for ((pending, action) in listOf(turnOff to ShadeActionReceiver.ACTION_TURN_OFF, keepOn to ShadeActionReceiver.ACTION_KEEP_ON)) {
            assertTrue(pending.isBroadcast)
            assertTrue(pending.isImmutable)
            assertEquals(ComponentName(app, ShadeActionReceiver::class.java), pending.savedIntent.component)
            assertEquals(action, pending.savedIntent.action)
            assertEquals(since, pending.savedIntent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, 0))
        }
        assertEquals(
            setOf(Notifier.REQUEST_STILL_BODY, Notifier.REQUEST_STILL_TURN_OFF, Notifier.REQUEST_STILL_KEEP_ON),
            setOf(body.requestCode, turnOff.requestCode, keepOn.requestCode),
        )
        assertEquals(since, store.stillPostedSince())
    }

    @Test
    fun `still for an older session posts nothing`() {
        val newer = ms("2026-10-20T09:00:00Z")
        store.write(on.copy(sinceMs = newer))
        still(since)
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(store.stillPostedSince())
        // Its own session does post.
        still(newer)
        assertNotNull(notification(app, Notifier.STILL_SHOOTING))
    }

    @Test
    fun `still answered posts nothing`() {
        store.write(on.copy(stillAnswered = true))
        still(since)
        assertNull(notification(app, Notifier.STILL_SHOOTING))
    }

    @Test
    fun `still while off or with the reminder off posts nothing`() {
        store.write(on.copy(shootingOn = false, sinceMs = null))
        still(since)
        store.write(on.copy(stillReminderEnabled = false))
        still(since)
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        // An alarm without its session posts nothing either.
        store.write(on)
        ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_STILL))
        assertNull(notification(app, Notifier.STILL_SHOOTING))
    }

    @Test
    fun `still posts once per session, even after a reboot`() {
        store.write(on)
        still(since)
        assertNotNull(notification(app, Notifier.STILL_SHOOTING))
        manager.cancel(Notifier.STILL_SHOOTING) // swiped away

        // A reboot re-arms everything: no second Still shooting? for this session.
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertNull(alarm(app, ReminderScheduler.ACTION_STILL))
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
        // Even if an old alarm fires.
        still(since)
        assertNull(notification(app, Notifier.STILL_SHOOTING))

        // A new session has its own.
        val next = ms("2026-11-05T08:00:00Z")
        store.write(on.copy(sinceMs = next))
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals("2026-11-19T10:00:00Z", alarmAt(app, ReminderScheduler.ACTION_STILL))
        assertFalse(store.stillPostedSince() == next)
    }
}
