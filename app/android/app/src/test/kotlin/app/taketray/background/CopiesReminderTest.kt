package app.taketray.background

import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.Formatter
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import app.taketray.MainActivity
import app.taketray.R
import app.taketray.background.ReminderTestSupport.LONDON
import app.taketray.background.ReminderTestSupport.MAIN
import app.taketray.background.ReminderTestSupport.NINE_PM
import app.taketray.background.ReminderTestSupport.action
import app.taketray.background.ReminderTestSupport.alarm
import app.taketray.background.ReminderTestSupport.alarmAt
import app.taketray.background.ReminderTestSupport.fire
import app.taketray.background.ReminderTestSupport.ms
import app.taketray.background.ReminderTestSupport.notification
import app.taketray.background.ReminderTestSupport.operation
import app.taketray.background.ReminderTestSupport.text
import app.taketray.background.ReminderTestSupport.title
import app.taketray.media.MediaAccessChecker
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
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowLog

/**
 * The copies reminder (Phase 8, D-124): three days after the last copies of an
 * editing session were made, "Done editing?" says the copies are still on the
 * phone. The real scheduler, store, receiver, notifier and managers; the clock
 * is a plain variable and no test waits on Android's scheduler.
 *
 * The mirror's reminders are `(reelId, reelName, copyBytes, lastCopiedAtMs)`.
 * The reminder is shown once per `(reelId, lastCopiedAtMs)`.
 */
@RunWith(RobolectricTestRunner::class)
class CopiesReminderTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val alarms = app.getSystemService(AlarmManager::class.java)
    private val scheduler = ReminderScheduler(app, LONDON)

    /** 12:00 UTC on 10 November. */
    private var now = ms("2026-11-10T12:00:00Z")

    private val batch = ms("2026-11-08T09:00:00Z")
    private val batchDue = ms("2026-11-11T09:00:00Z")

    private fun copies(
        reelId: Long,
        at: Long = batch,
        name: String = "Reel $reelId",
        bytes: Long = 1_234_567_890,
    ) = BackgroundState.CopiesReminder(reelId, name, bytes, at)

    private fun mirror(vararg reminders: BackgroundState.CopiesReminder) = BackgroundState.OFF.copy(copiesReminders = reminders.toList())

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
        Receivers.counter = { NewClipsCounter(it.contentResolver, { volume -> if (volume == MAIN) "v1" else null }, { true }, { now }) }
        ShadowLog.clear()
    }

    @After
    fun tearDown() = Receivers.reset()

    private fun copiesAlarm(): ShadowAlarmManager.ScheduledAlarm? = alarm(app, ReminderScheduler.ACTION_COPIES)

    private fun copiesAlarmAt(): String? = alarmAt(app, ReminderScheduler.ACTION_COPIES)

    private fun alarmCount() = shadowOf(alarms).scheduledAlarms.size

    /** The alarm's PendingIntent if one exists, without making one. */
    private fun armedCopiesIntent(): PendingIntent? =
        PendingIntent.getBroadcast(
            app,
            ReminderScheduler.REQUEST_COPIES_ALARM,
            ReminderScheduler.copiesIntent(app),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )

    /** The receiver, as Android calls it for the copies alarm. */
    private fun deliver() = ReminderReceiver().onReceive(app, ReminderScheduler.copiesIntent(app))

    private fun copiesNotification(reelId: Long): Notification? = notification(app, Notifier.COPIES_ID_BASE + reelId.toInt())

    /** The reels (1 to 200) whose copies reminder is in the shade. */
    private fun shownReels(): List<Long> = (1..200L).filter { copiesNotification(it) != null }

    private fun iso(ms: Long) = ReminderTestSupport.utc(ms)

    /** What the phone writes for a size: its short file size, the same on every SDK level the test runs on. */
    private fun size(bytes: Long): String = Formatter.formatShortFileSize(app, bytes)

    // ---- The alarm ----

    @Test
    fun `one inexact alarm, allowed while idle, for the earliest reminder due`() {
        scheduler.armCopies(mirror(copies(7, at = ms("2026-11-08T09:00:00Z")), copies(9, at = ms("2026-11-09T09:00:00Z"))), now)
        val alarm = copiesAlarm() ?: throw AssertionError("no copies alarm")
        assertEquals("2026-11-11T09:00:00Z", iso(alarm.triggerAtMs))
        assertEquals(AlarmManager.RTC_WAKEUP, alarm.getType())
        assertTrue("allowed while idle (Doze)", alarm.isAllowWhileIdle)
        assertEquals("inexact: no exact-alarm permission", ShadowAlarmManager.WINDOW_HEURISTIC, alarm.windowLengthMs)
        val pending = shadowOf(operation(alarm))
        assertTrue(pending.isBroadcast)
        assertTrue(pending.isImmutable)
        assertEquals(ComponentName(app, ReminderReceiver::class.java), pending.savedIntent.component)
        assertEquals(ReminderScheduler.ACTION_COPIES, pending.savedIntent.action)
        assertEquals(400, pending.requestCode)
        assertEquals("one alarm for all the reels", 1, alarmCount())
    }

    @Test
    fun `the earliest is found whatever the order of the mirror`() {
        val early = copies(3, at = ms("2026-11-01T00:00:00Z"))
        val late = copies(4, at = ms("2026-11-09T00:00:00Z"))
        for (order in listOf(arrayOf(early, late), arrayOf(late, early))) {
            scheduler.armCopies(mirror(*order), now - 100L * 24 * 3600 * 1000)
            assertEquals("2026-11-04T00:00:00Z", copiesAlarmAt())
        }
    }

    @Test
    fun `the alarm is at exactly 3 days after the last copies, and never earlier`() {
        val last = ms("2026-11-10T11:00:00.123Z")
        scheduler.armCopies(mirror(copies(7, at = last)), now)
        assertEquals("2026-11-13T11:00:00.123Z", copiesAlarmAt())
        assertEquals(last + 3 * 24 * 3600 * 1000L, copiesAlarm()!!.triggerAtMs)
        // Not moved to a morning or an evening hour: a reminder, not a reading time.
        scheduler.armCopies(mirror(copies(7, at = ms("2026-11-10T03:00:00Z"))), now)
        assertEquals("2026-11-13T03:00:00Z", copiesAlarmAt())
    }

    @Test
    fun `a reminder already due is armed for now`() {
        scheduler.armCopies(mirror(copies(7, at = ms("2026-11-01T09:00:00Z"))), now)
        assertEquals(iso(now), copiesAlarmAt())
        // Exactly due is now too.
        scheduler.armCopies(mirror(copies(7, at = now - 3 * 24 * 3600 * 1000L)), now)
        assertEquals(iso(now), copiesAlarmAt())
    }

    @Test
    fun `arming again replaces the alarm`() {
        scheduler.armCopies(mirror(copies(7)), now)
        scheduler.armCopies(mirror(copies(7)), now + 1000)
        scheduler.armCopies(mirror(copies(7, at = batch + 3_600_000)), now)
        assertEquals(1, alarmCount())
        assertEquals(iso(batchDue + 3_600_000), copiesAlarmAt())
    }

    @Test
    fun `a reminder shown for this batch is skipped, the next is armed, all shown arms nothing`() {
        val a = copies(7, at = ms("2026-11-07T09:00:00Z"))
        val b = copies(9, at = ms("2026-11-08T09:00:00Z"))
        store.setCopiesShown(7, a.lastCopiedAtMs)
        scheduler.armCopies(mirror(a, b), now)
        assertEquals("2026-11-11T09:00:00Z", copiesAlarmAt())

        store.setCopiesShown(9, b.lastCopiedAtMs)
        scheduler.armCopies(mirror(a, b), now)
        assertNull(copiesAlarm())
        assertNull("the PendingIntent goes with the alarm", armedCopiesIntent())
        assertEquals(0, alarmCount())
    }

    @Test
    fun `a new copy batch of a shown reel is armed again`() {
        store.setCopiesShown(7, batch)
        scheduler.armCopies(mirror(copies(7, at = batch)), now)
        assertNull(copiesAlarm())
        // The mark is for an older batch (earlier or later): only the same one is "shown".
        scheduler.armCopies(mirror(copies(7, at = batch + 1)), now)
        assertEquals(iso(batchDue + 1), copiesAlarmAt())
        scheduler.armCopies(mirror(copies(7, at = batch - 1)), now)
        assertEquals(iso(batchDue - 1), copiesAlarmAt())
    }

    @Test
    fun `a reel dropped from the mirror loses its alarm and the alarm moves to the next`() {
        scheduler.armCopies(mirror(copies(7, at = ms("2026-11-08T09:00:00Z")), copies(9, at = ms("2026-11-09T09:00:00Z"))), now)
        assertEquals("2026-11-11T09:00:00Z", copiesAlarmAt())
        scheduler.armCopies(mirror(copies(9, at = ms("2026-11-09T09:00:00Z"))), now)
        assertEquals("2026-11-12T09:00:00Z", copiesAlarmAt())
        scheduler.armCopies(mirror(), now)
        assertNull(copiesAlarm())
        assertNull(armedCopiesIntent())
        assertEquals(0, alarmCount())
    }

    @Test
    fun `a reel dropped from the mirror forgets its shown mark, so a new session is reminded afresh`() {
        store.setCopiesShown(7, batch)
        store.setCopiesShown(9, batch)
        scheduler.armCopies(mirror(copies(9)), now)
        assertNull("dropped", store.copiesShown(7))
        assertEquals("kept", batch, store.copiesShown(9))
        scheduler.armCopies(mirror(copies(7), copies(9)), now)
        assertEquals("reel 7 is reminded again", iso(batchDue), copiesAlarmAt())
    }

    @Test
    fun `a mirror of unusable reminders arms nothing and leaves the marks of usable reels alone`() {
        val bad =
            mirror(
                copies(0),
                copies(-997),
                copies(BackgroundState.MAX_REEL_ID + 1),
                copies(5, at = 0),
                copies(6, at = -1),
            )
        scheduler.armCopies(bad, now)
        assertNull(copiesAlarm())
        assertNull("no PendingIntent is made to cancel", armedCopiesIntent())
        assertEquals(0, alarmCount())
    }

    @Test
    fun `the same reel twice in the mirror is armed for its newest batch`() {
        scheduler.armCopies(mirror(copies(7, at = batch), copies(7, at = batch + 86_400_000)), now)
        assertEquals(iso(batchDue + 86_400_000), copiesAlarmAt())
        // The older batch's mark does not hide the newest.
        store.setCopiesShown(7, batch)
        scheduler.armCopies(mirror(copies(7, at = batch), copies(7, at = batch + 86_400_000)), now)
        assertEquals(iso(batchDue + 86_400_000), copiesAlarmAt())
    }

    @Test
    fun `copies reminders do not depend on Shooting mode or the other reminders`() {
        // Everything off: still armed.
        scheduler.armCopies(BackgroundState.OFF.copy(copiesReminders = listOf(copies(7))), now)
        assertNotNull(copiesAlarm())

        // The evening and Still shooting? alarms stand beside it, each its own.
        val on =
            BackgroundState.OFF.copy(
                shootingOn = true,
                sinceMs = ms("2026-11-01T03:00:00Z"),
                eveningEnabled = true,
                eveningMinutes = NINE_PM,
                stillReminderEnabled = true,
                copiesReminders = listOf(copies(7)),
            )
        scheduler.armEvening(on, now)
        scheduler.armStill(on, now)
        scheduler.armCopies(on, now)
        assertEquals(3, alarmCount())
        assertEquals(setOf(200, 300, 400), shadowOf(alarms).scheduledAlarms.map { shadowOf(operation(it)).requestCode }.toSet())

        // Switching the others off leaves the copies alarm.
        scheduler.armEvening(on.copy(eveningEnabled = false), now)
        scheduler.cancelStill()
        assertEquals(listOf(ReminderScheduler.ACTION_COPIES), shadowOf(alarms).scheduledAlarms.map { shadowOf(operation(it)).savedIntent.action })

        // And arming the others never moves it.
        scheduler.armStill(on, now)
        scheduler.armEvening(on, now)
        assertEquals(iso(batchDue), copiesAlarmAt())
    }

    @Test
    fun `the copies codes never meet Phase 6's`() {
        assertEquals(400, ReminderScheduler.REQUEST_COPIES_ALARM)
        val phase6 = setOf(1, 2, 3, 101, 102, 103, 200, 201, 202, 300, 301, 302, 303)
        assertTrue(ReminderScheduler.REQUEST_COPIES_ALARM !in phase6)
        assertTrue(ReminderScheduler.ACTION_COPIES !in setOf(ReminderScheduler.ACTION_EVENING, ReminderScheduler.ACTION_STILL))
        assertEquals(1000, Notifier.COPIES_ID_BASE)
        assertEquals(1_000_000, Notifier.COPIES_REQUEST_BASE)
        // The smallest and the largest reel's ids and codes stay clear of Phase 6's and of Int's end.
        for (reel in listOf(1L, 2L, 3L, BackgroundState.MAX_REEL_ID)) {
            assertTrue(Notifier.COPIES_ID_BASE + reel > 3)
            assertTrue(Notifier.COPIES_REQUEST_BASE + 2 * reel + 1 <= Int.MAX_VALUE)
            assertTrue(Notifier.COPIES_REQUEST_BASE + 2 * reel > 303)
        }
        assertTrue("one more reel would overflow a request code", Notifier.COPIES_REQUEST_BASE + 2 * (BackgroundState.MAX_REEL_ID + 1) + 1 > Int.MAX_VALUE)
    }

    // ---- The alarm fires ----

    @Test
    fun `the armed alarm, fired as Android would, shows the reminder once`() {
        now = ms("2026-11-10T12:00:00Z")
        store.write(mirror(copies(7, at = now - 3 * 24 * 3600 * 1000L)))
        scheduler.armCopies(store.state(), now - 60_000)
        // Armed for exactly the due time, so Android delivers it then, not before.
        assertEquals(iso(now), copiesAlarmAt())
        fire(app, ReminderScheduler.ACTION_COPIES)

        val n = copiesNotification(7) ?: throw AssertionError("no copies reminder")
        assertEquals("Reel 7 copies are using ${size(1_234_567_890)}", n.title())
        assertEquals(1, shadowOf(manager).size())
        assertEquals("marked shown", now - 3 * 24 * 3600 * 1000L, store.copiesShown(7))
        assertNull("nothing left to arm", copiesAlarm())
        assertNull(armedCopiesIntent())
    }

    @Test
    fun `delivery at the due time posts, one millisecond before posts nothing and arms for the due time`() {
        store.write(mirror(copies(7)))
        now = batchDue - 1
        deliver()
        assertNull("not yet", copiesNotification(7))
        assertNull("and not marked", store.copiesShown(7))
        assertEquals(iso(batchDue), copiesAlarmAt())

        now = batchDue
        deliver()
        assertNotNull(copiesNotification(7))
        assertEquals(batch, store.copiesShown(7))
        assertNull(copiesAlarm())
    }

    @Test
    fun `a late delivery still shows it`() {
        store.write(mirror(copies(7)))
        now = batchDue + 5 * 3_600_000L
        deliver()
        assertNotNull(copiesNotification(7))
    }

    @Test
    fun `a second delivery, a re-arm or a mirror write does not repeat it`() {
        store.write(mirror(copies(7)))
        now = batchDue + 1000
        deliver()
        assertNotNull(copiesNotification(7))
        manager.cancel(Notifier.COPIES_ID_BASE + 7) // the user swiped it away
        deliver()
        ReminderArming({ now }, { LONDON }).apply(app, store.state())
        deliver()
        assertNull("not again for the same copies", copiesNotification(7))
        assertNull(copiesAlarm())
        assertEquals(0, alarmCount())
    }

    @Test
    fun `a new copy batch is reminded again, in the same notification slot`() {
        store.write(mirror(copies(7)))
        now = batchDue
        deliver()
        val first = copiesNotification(7)
        assertNotNull(first)

        val next = batch + 2 * 86_400_000L
        store.write(mirror(copies(7, at = next, bytes = 500_000_000)))
        ReminderArming({ now }, { LONDON }).apply(app, store.state())
        assertEquals(iso(next + 3 * 86_400_000L), copiesAlarmAt())
        now = next + 3 * 86_400_000L
        deliver()
        assertEquals(1, shadowOf(manager).size())
        assertEquals("Reel 7 copies are using ${size(500_000_000)}", copiesNotification(7)?.title())
        assertEquals(next, store.copiesShown(7))
    }

    @Test
    fun `several reels post beside Phase 6's notifications without replacing them, each tap opening its own reel`() {
        assertTrue(Notifier(app).showNewClips(3, null))
        assertTrue(Notifier(app).showEvening(2))
        assertTrue(Notifier(app).showStillShooting(ms("2026-10-01T09:00:00Z")))
        store.write(mirror(copies(1, name = "One"), copies(2, name = "Two"), copies(3, name = "Three")))
        now = batchDue
        deliver()

        assertEquals(6, shadowOf(manager).size())
        for (phase6 in listOf(Notifier.NEW_CLIPS, Notifier.EVENING, Notifier.STILL_SHOOTING)) {
            assertNotNull("Phase 6's $phase6 is untouched", notification(app, phase6))
        }
        assertEquals("New clips are still 3", "3 new clips to tag", notification(app, Notifier.NEW_CLIPS)?.title())
        assertEquals("Still shooting?", notification(app, Notifier.STILL_SHOOTING)?.title())
        for ((reel, name) in listOf(1L to "One", 2L to "Two", 3L to "Three")) {
            val n = copiesNotification(reel) ?: throw AssertionError("no reminder for reel $reel")
            assertEquals("$name copies are using ${size(1_234_567_890)}", n.title())
            for (pending in listOf(shadowOf(n.contentIntent), shadowOf(n.action("Done editing").actionIntent))) {
                assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, reel), LaunchActions.read(Intent(pending.savedIntent)))
            }
        }
        // Nothing is left to arm.
        assertNull(copiesAlarm())
    }

    @Test
    fun `only the reels due post, and the later one stays armed`() {
        val earlier = ms("2026-11-07T09:00:00Z")
        val later = ms("2026-11-09T09:00:00Z")
        store.write(mirror(copies(7, at = earlier), copies(9, at = later)))
        now = ms("2026-11-10T09:00:00Z")
        deliver()
        assertEquals(listOf(7L), shownReels())
        assertEquals(earlier, store.copiesShown(7))
        assertNull(store.copiesShown(9))
        assertEquals("2026-11-12T09:00:00Z", copiesAlarmAt())

        now = ms("2026-11-12T09:00:00Z")
        deliver()
        assertEquals(listOf(7L, 9L), shownReels())
        assertNull(copiesAlarm())
    }

    @Test
    fun `the receiver posts and marks only the usable reminders, the newest batch of each reel`() {
        val older = batch
        val newer = batch + 86_400_000L
        // The mirror as a bug or a hand edit could leave it: two batches for one reel, and ids and times that are no reel's.
        val unusable = listOf(copies(0), copies(-1), copies(-997), copies(BackgroundState.MAX_REEL_ID + 1), copies(5, at = 0), copies(6, at = -1))
        store.write(mirror(copies(7, at = older), copies(7, at = newer), copies(9, at = older), *unusable.toTypedArray()))
        now = newer + 4 * 86_400_000L
        deliver()

        assertEquals("only the valid reels post", listOf(7L, 9L), shownReels())
        assertEquals("the newest batch is the one marked", newer, store.copiesShown(7))
        assertEquals(older, store.copiesShown(9))
        for (id in listOf(0L, -1L, -997L, BackgroundState.MAX_REEL_ID + 1, 5L, 6L)) {
            assertNull("no mark for $id", store.copiesShown(id))
        }
        assertEquals("one notification per valid reel, none on Phase 6's ids", 2, shadowOf(manager).size())
        assertNull(notification(app, Notifier.STILL_SHOOTING))
        assertNull(notification(app, Notifier.EVENING))
        assertNull(copiesAlarm())
    }

    @Test
    fun `a reel dropped from the mirror before its alarm fires posts nothing`() {
        store.write(mirror(copies(7), copies(9)))
        scheduler.armCopies(store.state(), now)
        store.write(mirror(copies(9, at = batch + 86_400_000L)))
        now = batchDue + 1000
        deliver()
        assertNull(copiesNotification(7))
        assertNull(copiesNotification(9))
        assertEquals(iso(batchDue + 86_400_000L), copiesAlarmAt())
    }

    @Test
    fun `with no mirror at all, a delivery posts nothing and arms nothing`() {
        deliver()
        assertEquals(0, shadowOf(manager).size())
        assertEquals(0, alarmCount())
    }

    @Test
    fun `notifications off post nothing, and the batch is not asked again`() {
        shadowOf(manager).setNotificationsEnabled(false)
        store.write(mirror(copies(7)))
        now = batchDue
        deliver()
        assertEquals(0, shadowOf(manager).size())
        assertEquals("handled once, like Still shooting?", batch, store.copiesShown(7))
        assertNull(copiesAlarm())

        // Turning them on later does not bring a three-day-old batch back.
        shadowOf(manager).setNotificationsEnabled(true)
        deliver()
        assertNull(copiesNotification(7))
    }

    @Test
    fun `a blocked Reminders channel posts nothing`() {
        manager.createNotificationChannel(NotificationChannel(Notifier.CHANNEL_REMINDERS, "Reminders", NotificationManager.IMPORTANCE_NONE))
        store.write(mirror(copies(7)))
        now = batchDue
        deliver()
        assertEquals(0, shadowOf(manager).size())
    }

    @Test
    fun `a post that throws still lets the other reels post and the next one be armed, logging only the class`() {
        val failing =
            object : Notifier(app) {
                override fun showCopies(reminder: BackgroundState.CopiesReminder): Boolean {
                    if (reminder.reelId == 7L) throw IllegalStateException("Secret Wedding Name")
                    return super.showCopies(reminder)
                }
            }
        store.write(mirror(copies(7, name = "Secret Wedding Name"), copies(9, name = "Other"), copies(11, at = batch + 5 * 86_400_000L)))
        now = batchDue
        val reminders = Reminders(store, ReminderScheduler(app, LONDON), Receivers.counter(app), failing, now, LONDON)
        reminders.copies()
        assertNull(copiesNotification(7))
        assertNotNull("the next reel is not lost to the failure", copiesNotification(9))
        assertEquals("a failed post is not retried", batch, store.copiesShown(7))
        assertEquals("the later reel is armed", iso(batch + 8 * 86_400_000L), copiesAlarmAt())
        val logs = ShadowLog.getLogsForTag(LOG_TAG)
        assertEquals(listOf("copies reminder not posted: IllegalStateException"), logs.map { it.msg })
        assertEquals(Log.WARN, logs.single().type)
        assertTrue(ShadowLog.getLogs().none { "Secret" in it.msg || it.throwable != null })
    }

    @Test
    fun `no log line holds a reel name or a size`() {
        store.write(mirror(copies(7, name = "Zq Wedding Zq"), copies(9, name = "Zq Trip Zq")))
        ReminderArming({ now }, { LONDON }).apply(app, store.state())
        now = batchDue
        deliver()
        ReminderArming({ now }, { LONDON }).apply(app, mirror())
        Receivers.zone = { throw IllegalStateException("Zq-zone") }
        deliver()
        val all = ShadowLog.getLogs().joinToString("\n") { it.tag + " " + it.msg }
        assertFalse(all, "Zq" in all)
        assertFalse(all, "1234567890" in all || size(1_234_567_890) in all)
        assertTrue("the failing run was logged by class", "reminder failed: IllegalStateException" in all)
    }

    @Test
    fun `the receiver ignores a copies broadcast it cannot read and other apps' actions`() {
        store.write(mirror(copies(7)))
        now = batchDue
        ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction("app.taketray.REMINDER_COPIES_X"))
        ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java))
        assertEquals(0, shadowOf(manager).size())
    }

    // ---- Arming (writeState, the receivers) ----

    @Test
    fun `arming for the mirror arms the alarm and takes the notifications of dropped reels out of the shade`() {
        store.write(mirror(copies(7), copies(9)))
        now = batchDue
        deliver()
        assertEquals(listOf(7L, 9L), shownReels())
        assertTrue(Notifier(app).showNewClips(2, null))

        // Reel 7's session ended (Done editing): the mirror no longer has it.
        val next = mirror(copies(9))
        store.write(next)
        ReminderArming({ now }, { LONDON }).apply(app, next)
        assertEquals(listOf(9L), shownReels())
        assertNotNull(notification(app, Notifier.NEW_CLIPS))

        ReminderArming({ now }, { LONDON }).apply(app, mirror())
        assertEquals(emptyList<Long>(), shownReels())
        assertNotNull("Phase 6's stay", notification(app, Notifier.NEW_CLIPS))
    }

    @Test
    fun `a new copy batch takes the old reminder's text out of the shade until its own is due (T7-M5)`() {
        store.write(mirror(copies(7), copies(9)))
        now = batchDue
        deliver()
        assertEquals(listOf(7L, 9L), shownReels())

        // The same mirror again, and a mirror that only changes another
        // reel's size: the shown reminders stay.
        ReminderArming({ now }, { LONDON }).apply(app, store.state())
        assertEquals(listOf(7L, 9L), shownReels())

        // Reel 7 got more copies: its notification still says the old size.
        val next = batch + 2 * 86_400_000L
        val state = mirror(copies(7, at = next, bytes = 500_000_000), copies(9))
        store.write(state)
        ReminderArming({ now }, { LONDON }).apply(app, state)
        assertEquals("reel 7's stale text is gone, reel 9's stays", listOf(9L), shownReels())
        assertEquals(iso(next + 3 * 86_400_000L), copiesAlarmAt())
        assertEquals(batch, store.copiesShown(7))

        // Applied again before it is due: nothing comes back early.
        ReminderArming({ now }, { LONDON }).apply(app, state)
        assertEquals(listOf(9L), shownReels())

        now = next + 3 * 86_400_000L
        deliver()
        assertEquals(listOf(7L, 9L), shownReels())
        assertEquals("Reel 7 copies are using ${size(500_000_000)}", copiesNotification(7)?.title())
    }

    @Test
    fun `arming arms the copies alarm for a mirror written by the app`() {
        val state = mirror(copies(7))
        store.write(state)
        ReminderArming({ now }, { LONDON }).apply(app, state)
        assertEquals(iso(batchDue), copiesAlarmAt())
        // The app writes the same thing again: still one alarm.
        ReminderArming({ now }, { LONDON }).apply(app, state)
        assertEquals(1, alarmCount())
    }

    @Test
    fun `a reboot arms the alarm again and a shown batch is not shown again`() {
        store.write(mirror(copies(7), copies(9, at = batch + 86_400_000L)))
        now = batchDue
        deliver()
        assertEquals(listOf(7L), shownReels())

        // The reboot: alarms gone, the shade emptied, the stored mirror and marks remain.
        shadowOf(alarms).scheduledAlarms.clear()
        manager.cancelAll()
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals("reel 9 is still to come", iso(batchDue + 86_400_000L), copiesAlarmAt())
        assertEquals(emptyList<Long>(), shownReels())

        now = batchDue + 86_400_000L
        deliver()
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(listOf(9L), shownReels())
        assertNull(copiesAlarm())
    }

    @Test
    fun `a zone change or an update does not move the alarm`() {
        store.write(mirror(copies(7)))
        Receivers.zone = { java.time.ZoneId.of("Asia/Kolkata") }
        for (action in listOf(Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED)) {
            shadowOf(alarms).scheduledAlarms.clear()
            BootReceiver().onReceive(app, Intent(action))
            assertEquals(action, iso(batchDue), copiesAlarmAt())
        }
        // The zone change re-arms through the same part.
        shadowOf(alarms).scheduledAlarms.clear()
        BootReceiver.rearm(app)
        assertEquals(iso(batchDue), copiesAlarmAt())
    }

    // ---- The notification ----

    private val notifier get() = Notifier(app)

    private fun post(reminder: BackgroundState.CopiesReminder = copies(7, name = "Goa")): Notification {
        assertTrue(notifier.showCopies(reminder))
        return copiesNotification(reminder.reelId) ?: throw AssertionError("not posted")
    }

    @Test
    fun `the reminder says which reel and how big, and offers Done editing`() {
        val n = post(copies(7, name = "Goa trip", bytes = 1_234_567_890))
        assertEquals(Notifier.CHANNEL_REMINDERS, n.channelId)
        assertEquals("Goa trip copies are using ${size(1_234_567_890)}", n.title())
        assertEquals("Done editing? Tap to clean up.", n.text())
        assertEquals(listOf("Done editing"), n.actions.map { it.title.toString() })
        assertEquals(R.drawable.ic_stat_taketray, n.smallIcon.resId)
        assertEquals(Notification.CATEGORY_REMINDER, n.category)
        assertTrue("auto-cancel", n.flags and Notification.FLAG_AUTO_CANCEL != 0)
        assertEquals(Notification.VISIBILITY_PRIVATE, n.visibility)
        // Same channel as the other reminders; it has no sound of its own to repeat.
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel(Notifier.CHANNEL_REMINDERS).importance)
    }

    @Test
    fun `sizes read as the phone's short file size`() {
        for (bytes in listOf(0L, 999L, 523_000L, 1_500_000L, 1_234_567_890L, 21_000_000_000L)) {
            assertEquals("$bytes", "Goa copies are using ${size(bytes)}", post(copies(7, name = "Goa", bytes = bytes)).title())
        }
        // The short form is what is asked for: the long one reads differently here.
        assertTrue(size(1_500_000) != Formatter.formatFileSize(app, 1_500_000))
        assertEquals("Goa copies are using 0 B", post(copies(7, name = "Goa", bytes = 0)).title())
    }

    @Test
    fun `the lock screen shows only the app name and a general line`() {
        val n = post(copies(7, name = "Secret Wedding", bytes = 1_234_567_890))
        val public = n.publicVersion ?: throw AssertionError("no public version")
        assertEquals("TakeTray", public.title())
        assertEquals("Copies for an edit are still on your phone", public.text())
        assertEquals(Notifier.CHANNEL_REMINDERS, public.channelId)
        assertEquals(R.drawable.ic_stat_taketray, public.smallIcon.resId)
        assertNull(public.actions)
        val shown = listOf(public.title(), public.text(), public.extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(), public.extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString())
        assertTrue(shown.none { it != null && ("Secret" in it || size(1_234_567_890) in it) })
    }

    @Test
    fun `a reel name is shown as it is, whatever characters it has`() {
        for (name in listOf("100% sure", "%1\$s %2\$s", "{0}", "Café 🎬", "It's \"quoted\"", "<b>bold</b>", "a\nb")) {
            assertEquals("$name copies are using ${size(1_234_567_890)}", post(copies(7, name = name)).title())
        }
    }

    @Test
    fun `the notification id and the tap request codes are per reel`() {
        for (reel in listOf(1L, 2L, 3L, 41L)) {
            val n = post(copies(reel))
            assertNotNull(notification(app, 1000 + reel.toInt()))
            val body = shadowOf(n.contentIntent)
            val button = shadowOf(n.action("Done editing").actionIntent)
            assertEquals(1_000_000 + 2 * reel.toInt(), body.requestCode)
            assertEquals(1_000_000 + 2 * reel.toInt() + 1, button.requestCode)
            for (pending in listOf(body, button)) {
                assertTrue(pending.isActivity)
                assertTrue(pending.isImmutable)
                assertTrue(pending.flags and PendingIntent.FLAG_UPDATE_CURRENT != 0)
                val intent = Intent(pending.savedIntent)
                assertEquals(ComponentName(app, MainActivity::class.java), intent.component)
                assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, reel), LaunchActions.read(intent))
            }
        }
        assertEquals("one notification per reel", 4, shadowOf(manager).size())
    }

    @Test
    fun `the largest reel id gets valid ids and codes`() {
        val max = BackgroundState.MAX_REEL_ID
        val n = post(copies(max))
        assertEquals(Int.MAX_VALUE - 1, shadowOf(n.contentIntent).requestCode)
        assertEquals(Int.MAX_VALUE, shadowOf(n.action("Done editing").actionIntent).requestCode)
        assertNotNull(notification(app, Notifier.COPIES_ID_BASE + max.toInt()))
    }

    @Test
    fun `a reminder for a reel id that has no valid id posts nothing and throws`() {
        for (bad in listOf(0L, -1L, -997L, BackgroundState.MAX_REEL_ID + 1, Long.MAX_VALUE)) {
            try {
                notifier.showCopies(copies(bad))
                fail("expected a refusal for $bad")
            } catch (e: IllegalArgumentException) {
                // Refused, as expected.
            }
        }
        assertEquals(0, shadowOf(manager).size())
    }

    @Test
    fun `posting a reel again updates its notification in place`() {
        post(copies(7, name = "Goa", bytes = 1_000_000))
        post(copies(7, name = "Goa", bytes = 2_000_000))
        assertEquals(1, shadowOf(manager).size())
        assertEquals("Goa copies are using ${size(2_000_000)}", copiesNotification(7)?.title())
    }

    @Test
    fun `not allowed posts nothing and does not throw`() {
        shadowOf(manager).setNotificationsEnabled(false)
        assertFalse(notifier.showCopies(copies(7)))
        assertEquals(0, shadowOf(manager).size())
    }

    @Test
    fun `cancelling one reel's reminder leaves the others and Phase 6's`() {
        post(copies(1))
        post(copies(2))
        assertTrue(notifier.showEvening(1))
        assertTrue(notifier.showStillShooting(1))
        notifier.cancelCopies(1)
        assertNull(copiesNotification(1))
        assertNotNull(copiesNotification(2))
        assertNotNull(notification(app, Notifier.EVENING))
        // A reel with none, or an id that is no reel's: nothing happens, and no other id is touched.
        notifier.cancelCopies(99)
        notifier.cancelCopies(0)
        notifier.cancelCopies(-997) // 1000 + -997 would be Still shooting?'s id
        notifier.cancelCopies(-998) // and the evening reminder's
        notifier.cancelCopies(BackgroundState.MAX_REEL_ID + 1)
        assertNotNull(copiesNotification(2))
        assertNotNull(notification(app, Notifier.EVENING))
        assertNotNull(notification(app, Notifier.STILL_SHOOTING))
    }

    @Test
    fun `cancelling all but some leaves those reels and every other notification`() {
        for (reel in 1L..4L) post(copies(reel))
        assertTrue(notifier.showNewClips(1, null))
        assertTrue(notifier.showEvening(1))
        assertTrue(notifier.showStillShooting(1))
        notifier.cancelCopiesExcept(setOf(2, 4, 77))
        assertEquals(listOf(2L, 4L), shownReels())
        assertEquals(setOf(1, 2, 3), setOf(Notifier.NEW_CLIPS, Notifier.EVENING, Notifier.STILL_SHOOTING).filter { notification(app, it) != null }.toSet())
        notifier.cancelCopiesExcept(emptySet())
        assertEquals(emptyList<Long>(), shownReels())
        assertEquals(3, shadowOf(manager).size())
    }
}
