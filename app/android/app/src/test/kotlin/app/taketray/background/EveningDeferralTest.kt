package app.taketray.background

import android.app.Application
import android.app.NotificationManager
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import app.taketray.background.ReminderTestSupport.LONDON
import app.taketray.background.ReminderTestSupport.MAIN
import app.taketray.background.ReminderTestSupport.NINE_PM
import app.taketray.background.ReminderTestSupport.alarmAt
import app.taketray.background.ReminderTestSupport.ms
import app.taketray.background.ReminderTestSupport.notification
import app.taketray.background.ReminderTestSupport.title
import app.taketray.media.MediaAccessChecker
import java.util.concurrent.Executor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
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
 * The evening reminder waits for 5 quiet minutes too (D-110): when its alarm
 * fires with a clip under 5 minutes old, or a take in progress, it is
 * deferred to a one-off job, posts when it is quiet (counting that moment),
 * only for the same evening, and still at most once a local day. The clock
 * is 21:00:30 on 5 November in London, the alarm for 21:00.
 */
@RunWith(RobolectricTestRunner::class)
class EveningDeferralTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val jobs = app.getSystemService(JobScheduler::class.java)

    private var now = ms("2026-11-05T21:00:30Z")
    private val eveningInstant = ms("2026-11-05T21:00:00Z")
    private val today = ms("2026-11-05T10:00:00Z")

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = ms("2026-10-01T09:00:00Z"),
            baselines = listOf(BackgroundState.Baseline(MAIN, "v1", 100)),
            watchedFolders = listOf("DCIM/Camera/"),
            eveningEnabled = true,
            eveningMinutes = NINE_PM,
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
        Receivers.counter = { NewClipsCounter(it.contentResolver, { volume -> if (volume == MAIN) "v1" else null }, { true }, { now }) }
        store.write(on)
        // Armed at 20:00 for 21:00, as the app's first write would.
        ReminderScheduler(app, LONDON).armEvening(on, ms("2026-11-05T20:00:00Z"))
    }

    @After
    fun tearDown() = Receivers.reset()

    private fun alarmFires() = ReminderReceiver().onReceive(app, Intent(app, ReminderReceiver::class.java).setAction(ReminderScheduler.ACTION_EVENING))

    private fun runDeferred(): ShadowJobService {
        val service = Robolectric.buildService(EveningDeferJobService::class.java).create().get()
        assertTrue(service.onStartJob(ReflectionHelpers.callConstructor(JobParameters::class.java)))
        return Shadow.extract(service)
    }

    private fun deferred() = jobs.getPendingJob(EveningDeferJobService.JOB_ID)

    private fun title() = notification(app, Notifier.EVENING)?.title()

    /** A clip shot today, added [agoSec] seconds before the clock. */
    private fun clip(
        id: Long,
        agoSec: Long,
        atMs: Long = now,
    ) = SqlVideoProvider.add(id = id, generation = 100 + id, taken = today, added = (atMs - agoSec * 1000) / 1000)

    private fun pending(
        id: Long,
        agoSec: Long,
    ) = SqlVideoProvider.add(
        id = id,
        generation = 100 + id,
        pending = true,
        duration = null,
        size = 0,
        added = (now - agoSec * 1000) / 1000,
    )

    private val tomorrowsAlarm get() = alarmAt(app, ReminderScheduler.ACTION_EVENING)

    @Test
    fun `quiet at alarm time posts at once`() {
        clip(1, agoSec = 3_600)
        clip(2, agoSec = 300) // exactly 5 minutes old
        alarmFires()
        assertEquals("You shot 2 clips today. Tag them?", title())
        assertNull(deferred())
        assertNull(store.eveningDeferredFor())
        assertEquals(ReminderTimes.localDay(eveningInstant, LONDON), store.eveningHandledDay())
        assertEquals("2026-11-06T21:00:00Z", tomorrowsAlarm)
    }

    @Test
    fun `mid-shoot it is deferred and posts after 5 quiet minutes counting the new clips too`() {
        clip(1, agoSec = 60)
        alarmFires()
        assertNull("not in the middle of a shoot", title())
        val job = deferred() ?: throw AssertionError("no deferral job")
        assertEquals(240_000L + NewClipsArming.SETTLE_MARGIN_MS, job.minLatencyMillis)
        assertTrue("a wake-up deadline, not an exact alarm", job.maxExecutionDelayMillis > job.minLatencyMillis)
        assertTrue(job.isPersisted)
        assertEquals(eveningInstant, store.eveningDeferredFor())
        assertNull("handled only when it posts or is skipped", store.eveningHandledDay())
        assertEquals("tomorrow's alarm is armed as usual", "2026-11-06T21:00:00Z", tomorrowsAlarm)

        // Another clip arrives 2 minutes later; the job runs at 4 minutes: still not quiet.
        val second = now + 120_000
        clip(2, agoSec = 0, atMs = second)
        now += 245_000
        val first = runDeferred()
        assertFalse("no retry: it is scheduled again", first.isRescheduleNeeded)
        assertNull(title())
        assertEquals(second / 1000 * 1000 + 300_000 - now + NewClipsArming.SETTLE_MARGIN_MS, deferred()?.minLatencyMillis)
        assertNull(store.eveningHandledDay())

        // 5 quiet minutes after the last clip: it posts, counting both.
        now = second + 301_000
        runDeferred()
        assertEquals("You shot 2 clips today. Tag them?", title())
        assertNull(deferred())
        assertNull(store.eveningDeferredFor())
        assertEquals(ReminderTimes.localDay(eveningInstant, LONDON), store.eveningHandledDay())

        // Run again: nothing, and a swiped reminder does not come back.
        manager.cancel(Notifier.EVENING)
        runDeferred()
        assertNull(title())
    }

    @Test
    fun `a take in progress defers it`() {
        clip(1, agoSec = 3_600)
        pending(2, agoSec = 100)
        alarmFires()
        assertNull(title())
        assertEquals(NewClipsArming.QUIET_MS, deferred()?.minLatencyMillis)

        // Still recording when the job runs: again.
        now += 301_000
        runDeferred()
        assertNull(title())
        assertEquals(NewClipsArming.QUIET_MS, deferred()?.minLatencyMillis)

        // The take ends (finished, modified now): 5 quiet minutes from its end.
        SqlVideoProvider.finish(2, modified = now / 1000)
        now += 120_000
        runDeferred()
        assertNull(title())
        now += 301_000
        runDeferred()
        assertEquals("You shot 2 clips today. Tag them?", title())
    }

    @Test
    fun `a stuck pending row older than 3 hours does not defer it`() {
        clip(1, agoSec = 3_600)
        pending(2, agoSec = 10_801)
        alarmFires()
        assertEquals("You shot 1 clip today. Tag it?", title())
    }

    @Test
    fun `when the quiet comes after midnight it is skipped and handled with no post`() {
        clip(1, agoSec = 60)
        alarmFires()
        assertNotNull(deferred())

        now = ms("2026-11-06T00:10:00Z")
        val job = runDeferred()
        assertFalse(job.isRescheduleNeeded)
        assertNull("never 'today' for yesterday", title())
        assertNull(deferred())
        assertNull(store.eveningDeferredFor())
        assertEquals(ReminderTimes.localDay(eveningInstant, LONDON), store.eveningHandledDay())
        assertEquals("2026-11-06T21:00:00Z", tomorrowsAlarm)

        // Tomorrow's evening is untouched: it posts once.
        store.write(store.state().copy(waitingShotMs = listOf(ms("2026-11-06T09:00:00Z"))))
        now = ms("2026-11-06T21:00:30Z")
        alarmFires()
        assertEquals("You shot 1 clip today. Tag it?", title())
    }

    @Test
    fun `a deferral left from yesterday is dropped when the next evening fires`() {
        clip(1, agoSec = 60)
        alarmFires()
        assertNotNull(deferred())
        // The job never ran (Doze, a dead phone); the next evening's alarm comes.
        store.write(store.state().copy(waitingShotMs = listOf(ms("2026-11-06T09:00:00Z"))))
        SqlVideoProvider.trash(1)
        now = ms("2026-11-06T21:00:30Z")
        alarmFires()
        assertEquals("You shot 1 clip today. Tag it?", title())
        assertNull(deferred())
        assertNull(store.eveningDeferredFor())
    }

    @Test
    fun `switching the reminder off while it is deferred cancels the deferral`() {
        clip(1, agoSec = 60)
        alarmFires()
        assertNotNull(deferred())

        ReminderArming({ now }, { LONDON }).apply(app, store.state().copy(eveningEnabled = false))
        assertNull(deferred())
        assertNull(store.eveningDeferredFor())
        assertNull(tomorrowsAlarm)

        // A run that was already on its way posts nothing.
        runDeferred()
        assertNull(title())
    }

    @Test
    fun `a boot while it is deferred neither doubles nor loses it`() {
        clip(1, agoSec = 60)
        alarmFires()
        val before = deferred()

        // The job survived the reboot (it is persisted): arming leaves it and posts nothing.
        now += 20_000
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertNull(title())
        assertEquals(before?.minLatencyMillis, deferred()?.minLatencyMillis)
        assertEquals("tomorrow's alarm, not tonight's again", "2026-11-06T21:00:00Z", tomorrowsAlarm)

        // The job was lost with the reboot: arming makes it again.
        jobs.cancel(EveningDeferJobService.JOB_ID)
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(NewClipsArming.QUIET_MS, deferred()?.minLatencyMillis)

        now += 400_000
        runDeferred()
        assertEquals("You shot 1 clip today. Tag it?", title())
        manager.cancel(Notifier.EVENING)
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))
        runDeferred()
        assertNull("once a day", title())
        assertNull(deferred())
    }

    @Test
    fun `an alarm that fires again once it is quiet posts once and the job then does nothing`() {
        clip(1, agoSec = 60)
        alarmFires()
        now += 400_000
        alarmFires() // the clock was set back, or a duplicate delivery
        assertEquals("You shot 1 clip today. Tag it?", title())
        assertNull(deferred())
        manager.cancel(Notifier.EVENING)
        runDeferred()
        assertNull(title())
    }

    @Test
    fun `Shooting mode switched off while deferred still posts once what is waiting`() {
        clip(1, agoSec = 60)
        alarmFires()
        store.write(store.state().copy(shootingOn = false, sinceMs = null, baselines = emptyList(), waitingShotMs = listOf(today)))
        now += 301_000
        runDeferred()
        assertEquals("You shot 1 clip today. Tag it?", title())
        manager.cancel(Notifier.EVENING)
        runDeferred()
        assertNull(title())
    }

    @Test
    fun `nothing to post when quiet posts nothing and is handled`() {
        clip(1, agoSec = 60)
        alarmFires()
        // Tagged in the app meanwhile: the baseline moved past the clip.
        store.write(store.state().copy(baselines = listOf(BackgroundState.Baseline(MAIN, "v1", 500))))
        now += 301_000
        runDeferred()
        assertNull(title())
        assertNull(deferred())
        assertEquals(ReminderTimes.localDay(eveningInstant, LONDON), store.eveningHandledDay())
    }

    @Test
    fun `a failing count defers instead of losing the evening, and the job keeps asking`() {
        clip(1, agoSec = 3_600)
        SqlVideoProvider.noCursor = true
        alarmFires()
        assertNull(title())
        assertEquals(NewClipsArming.QUIET_MS, deferred()?.minLatencyMillis)
        assertNull(store.eveningHandledDay())

        now += 301_000
        runDeferred()
        assertNull(title())
        assertNotNull("asks again", deferred())

        SqlVideoProvider.noCursor = false
        now += 301_000
        runDeferred()
        assertEquals("You shot 1 clip today. Tag it?", title())
    }

    @Test
    fun `a failing take check defers too`() {
        clip(1, agoSec = 3_600)
        SqlVideoProvider.pendingFailure = IllegalStateException("provider died")
        alarmFires()
        assertNull(title())
        assertEquals(NewClipsArming.QUIET_MS, deferred()?.minLatencyMillis)
    }

    @Test
    fun `the deferral job is not exported and asks for a retry when stopped`() {
        val info = app.packageManager.getServiceInfo(ComponentName(app, EveningDeferJobService::class.java), 0)
        assertFalse(info.exported)
        assertEquals("android.permission.BIND_JOB_SERVICE", info.permission)
        val service = Robolectric.buildService(EveningDeferJobService::class.java).create().get()
        assertTrue(service.onStopJob(ReflectionHelpers.callConstructor(JobParameters::class.java)))
    }

    @Test
    fun `a deferral for an evening that is handled already posts nothing and goes`() {
        clip(1, agoSec = 3_600)
        store.setEveningDeferredFor(eveningInstant)
        store.setEveningHandledDay(ReminderTimes.localDay(eveningInstant, LONDON))
        ReminderScheduler(app, LONDON).deferEvening(1_000)
        runDeferred()
        assertNull(title())
        assertNull(deferred())
        assertNull(store.eveningDeferredFor())
    }

    @Test
    fun `a deferral job with nothing stored goes without posting`() {
        clip(1, agoSec = 3_600)
        ReminderScheduler(app, LONDON).deferEvening(1_000)
        runDeferred()
        assertNull(title())
        assertNull(deferred())
    }

    @Test
    fun `the reminder switched off at alarm time defers nothing`() {
        store.write(store.state().copy(eveningEnabled = false))
        clip(1, agoSec = 60)
        alarmFires()
        assertNull(deferred())
        assertNull(title())
    }
}
