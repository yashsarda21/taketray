package app.taketray.background

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
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
 * The evening reminder leaves the shade when its claim stops being true
 * (D-105, final review I-3): the clips are tagged, the reminder is switched
 * off, the day is over, or the user opens To tag. Android does not cancel a
 * notification when one of its action buttons is tapped, so the app does.
 */
@RunWith(RobolectricTestRunner::class)
class EveningReminderRemovalTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)

    /** 21:30 on 5 November in London, after the evening reminder posted. */
    private var now = ms("2026-11-05T21:30:00Z")
    private val since = ms("2026-10-01T09:00:00Z")
    private val today = ms("2026-11-05T09:00:00Z")

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = since,
            baselines = listOf(BackgroundState.Baseline(MAIN, "v1", 100)),
            watchedFolders = listOf("DCIM/Camera/"),
            waitingShotMs = listOf(today),
            eveningEnabled = true,
            eveningMinutes = NINE_PM,
            stillReminderEnabled = true,
        )

    private var counterCalls = 0

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
        Receivers.counter = {
            counterCalls++
            NewClipsCounter(it.contentResolver, { volume -> if (volume == MAIN) "v1" else null }, { true }, { now })
        }
        ShadowLog.clear()
    }

    @After
    fun tearDown() = Receivers.reset()

    /** What the app's writeState arms: the real alarms part, on this clock. */
    private fun write(state: BackgroundState) {
        store.write(state)
        ReminderArming({ now }, { LONDON }).apply(app, state, keepNewClips = false)
    }

    private fun postEvening() {
        assertTrue(Notifier(app).showEvening(2))
        assertNotNull(notification(app, Notifier.EVENING))
    }

    private fun showing() = notification(app, Notifier.EVENING) != null

    private fun title() = notification(app, Notifier.EVENING)?.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()

    private fun fireEveningAlarm() =
        ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_EVENING))

    // ---- Notifier ----

    @Test
    fun `cancelling the evening reminder leaves the other notifications`() {
        Notifier(app).showNewClips(3, null)
        Notifier(app).showStillShooting(since)
        postEvening()
        Notifier(app).cancelEvening()
        assertNull(notification(app, Notifier.EVENING))
        assertNotNull(notification(app, Notifier.NEW_CLIPS))
        assertNotNull(notification(app, Notifier.STILL_SHOOTING))
        // Nothing showing: harmless, and again.
        Notifier(app).cancelEvening()
    }

    // ---- The app's writes ----

    @Test
    fun `tagging the last of today's clips removes the evening reminder`() {
        postEvening()
        // Some are tagged: one clip from today still waits.
        write(on.copy(waitingShotMs = listOf(today)))
        assertTrue("a waiting clip from today keeps it", showing())
        // The last one is tagged.
        write(on.copy(waitingShotMs = emptyList()))
        assertNull(notification(app, Notifier.EVENING))
        // Tomorrow's reminder is still armed.
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `older clips waiting do not keep it`() {
        postEvening()
        write(on.copy(waitingShotMs = listOf(ms("2026-11-04T23:59:59Z"), ms("2026-11-01T10:00:00Z"))))
        assertNull(notification(app, Notifier.EVENING))
    }

    @Test
    fun `a clip shot at the start of today keeps it`() {
        postEvening()
        write(on.copy(waitingShotMs = listOf(ms("2026-11-05T00:00:00Z"))))
        assertTrue(showing())
    }

    @Test
    fun `switching the reminder off removes it even with clips waiting`() {
        postEvening()
        write(on.copy(eveningEnabled = false))
        assertNull(notification(app, Notifier.EVENING))
        assertNull(alarmAt(app, ReminderScheduler.ACTION_EVENING))
        assertEquals("the off path needs no query", 0, counterCalls)
    }

    @Test
    fun `the next day's first write removes yesterday's reminder`() {
        postEvening()
        // Tomorrow morning: the app opens and writes, with last night's clips still waiting.
        now = ms("2026-11-06T08:00:00Z")
        write(on.copy(waitingShotMs = listOf(today)))
        assertNull(notification(app, Notifier.EVENING))
    }

    @Test
    fun `a clip the app has not scanned yet keeps it`() {
        postEvening()
        SqlVideoProvider.add(id = 1, generation = 101, taken = ms("2026-11-05T10:00:00Z"))
        write(on.copy(waitingShotMs = emptyList()))
        assertTrue("clips still unscanned are today's too", showing())
        assertEquals(1, counterCalls)
    }

    @Test
    fun `an unscanned clip from yesterday does not keep it`() {
        postEvening()
        SqlVideoProvider.add(id = 1, generation = 101, taken = ms("2026-11-04T10:00:00Z"))
        write(on.copy(waitingShotMs = emptyList()))
        assertNull(notification(app, Notifier.EVENING))
    }

    @Test
    fun `with nothing in the shade it asks MediaStore nothing`() {
        write(on.copy(waitingShotMs = emptyList()))
        assertEquals(0, counterCalls)
        assertEquals(emptyList<String>(), SqlVideoProvider.queries.toList())
    }

    @Test
    fun `a failing count keeps it and logs only the class`() {
        postEvening()
        SqlVideoProvider.failure = IllegalStateException("secret-folder")
        write(on.copy(waitingShotMs = emptyList()))
        assertTrue(showing())
        val logs = ShadowLog.getLogsForTag(LOG_TAG)
        assertEquals(listOf("evening reminder not checked: IllegalStateException"), logs.map { it.msg })
        assertEquals(Log.WARN, logs.single().type)
        assertTrue(ShadowLog.getLogs().none { "secret-folder" in it.msg || it.throwable != null })
        // The alarms were armed all the same.
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
    }

    @Test
    fun `without notification permission nothing throws and the alarm is armed`() {
        shadowOf(manager).setNotificationsEnabled(false)
        write(on.copy(waitingShotMs = emptyList()))
        write(on.copy(eveningEnabled = false))
        assertNull(notification(app, Notifier.EVENING))
        write(on)
        assertEquals("2026-11-06T21:00:00Z", alarmAt(app, ReminderScheduler.ACTION_EVENING))
        assertTrue(ShadowLog.getLogsForTag(LOG_TAG).isEmpty())
    }

    @Test
    fun `Still shooting and the new clips notification stay when the evening goes`() {
        postEvening()
        Notifier(app).showStillShooting(since)
        Notifier(app).showNewClips(2, null)
        write(on.copy(waitingShotMs = emptyList(), eveningEnabled = false))
        assertNull(notification(app, Notifier.EVENING))
        assertNotNull(notification(app, Notifier.STILL_SHOOTING))
        assertNotNull(notification(app, Notifier.NEW_CLIPS))
    }

    // ---- The alarm itself ----

    @Test
    fun `the next evening with no clips today removes yesterday's reminder`() {
        // Posted yesterday and left in the shade.
        store.write(on.copy(waitingShotMs = listOf(today)))
        now = ms("2026-11-05T21:00:30Z")
        fireEveningAlarm()
        assertEquals("You shot 1 clip today. Tag it?", title())

        // Tomorrow's alarm: nothing shot today. Yesterday's is not true any more.
        now = ms("2026-11-06T21:00:30Z")
        store.write(on.copy(waitingShotMs = emptyList()))
        fireEveningAlarm()
        assertNull(notification(app, Notifier.EVENING))
    }

    @Test
    fun `the alarm after the reminder was switched off removes what is left`() {
        postEvening()
        store.write(on.copy(eveningEnabled = false))
        fireEveningAlarm()
        assertNull(notification(app, Notifier.EVENING))
    }

    @Test
    fun `an alarm firing again for the same evening does not remove it`() {
        store.write(on.copy(waitingShotMs = listOf(today)))
        now = ms("2026-11-05T21:00:30Z")
        fireEveningAlarm()
        assertTrue(showing())
        // The clock went back and the alarm fires again: this evening is handled, the reminder stays.
        now = ms("2026-11-05T21:00:40Z")
        fireEveningAlarm()
        assertTrue(showing())
    }

    @Test
    fun `an evening with clips replaces yesterday's in place`() {
        store.write(on.copy(waitingShotMs = listOf(today)))
        now = ms("2026-11-05T21:00:30Z")
        fireEveningAlarm()
        now = ms("2026-11-06T21:00:30Z")
        store.write(on.copy(waitingShotMs = listOf(ms("2026-11-06T09:00:00Z"), ms("2026-11-06T10:00:00Z"))))
        fireEveningAlarm()
        assertEquals(1, shadowOf(manager).size())
        assertEquals("You shot 2 clips today. Tag them?", title())
    }
}
