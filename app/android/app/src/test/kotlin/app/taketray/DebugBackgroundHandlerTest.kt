package app.taketray

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import app.taketray.background.BackgroundState
import app.taketray.background.BackgroundStateStore
import app.taketray.background.NewClipsArming
import app.taketray.background.NewClipsCounter
import app.taketray.background.NewClipsJob
import app.taketray.background.NewClipsJobService
import app.taketray.background.NewClipsSettleJobService
import app.taketray.background.Notifier
import app.taketray.background.ReminderReceiver
import app.taketray.background.ReminderScheduler
import app.taketray.background.ReminderTestSupport
import app.taketray.background.Receivers
import app.taketray.background.ShadeActionReceiver
import app.taketray.background.SqlVideoProvider
import app.taketray.media.ZoneChangeStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.After
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

/**
 * The debug-only background hooks (Phase 6, Task 9): `fireEvening`,
 * `fireStill` and `runNewClipsJob`. Each must reach the production receiver
 * or job by the same road Android uses, so these tests run the real
 * receivers on the real store and notification manager, and compare the
 * broadcast with the one the alarm carries.
 */
@RunWith(RobolectricTestRunner::class)
class DebugBackgroundHandlerTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val prefs = app.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val scheduler = app.getSystemService(JobScheduler::class.java)
    private val main = MediaStore.VOLUME_EXTERNAL_PRIMARY

    private var now = ReminderTestSupport.ms("2026-11-05T20:00:00Z")
    private val since = ReminderTestSupport.ms("2026-10-01T09:00:00Z")

    private val on =
        BackgroundState.OFF.copy(
            shootingOn = true,
            sinceMs = since,
            baselines = listOf(BackgroundState.Baseline(main, "v1", 100)),
            watchedFolders = listOf("DCIM/Camera/"),
            eveningEnabled = true,
            eveningMinutes = ReminderTestSupport.NINE_PM,
            stillReminderEnabled = true,
        )

    private val savedExecutor = NewClipsJobService.executor
    private val savedNewJob = NewClipsJobService.newJob

    private lateinit var handler: DebugBackgroundHandler

    /** Records the one reply. */
    private class Reply : MethodChannel.Result {
        var success: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var notImplemented = false
        var replies = 0

        override fun success(result: Any?) {
            replies++
            success = result
        }

        override fun error(
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?,
        ) {
            replies++
            this.errorCode = errorCode
            this.errorMessage = errorMessage
        }

        override fun notImplemented() {
            replies++
            notImplemented = true
        }
    }

    @Before
    fun setUp() {
        prefs.edit().clear().commit()
        shadowOf(manager).setNotificationsEnabled(true)
        SqlVideoProvider.install()
        Receivers.executor = Executor { it.run() }
        Receivers.nowMs = { now }
        Receivers.zone = { ReminderTestSupport.LONDON }
        Receivers.counter = { NewClipsCounter(it.contentResolver, { volume -> if (volume == main) "v1" else null }, { true }, { now }) }
        NewClipsJobService.newJob = { context -> job(context) }
        handler = DebugBackgroundHandler(app, scope = CoroutineScope(Dispatchers.Unconfined), io = Dispatchers.Unconfined)
    }

    @After
    fun tearDown() {
        Receivers.reset()
        NewClipsJobService.executor = savedExecutor
        NewClipsJobService.newJob = savedNewJob
    }

    private fun job(context: Context) =
        NewClipsJob(
            context = context,
            store = BackgroundStateStore(prefs),
            counter = NewClipsCounter(context.contentResolver, { if (it == main) "v1" else null }, { true }, { now }),
            notifier = Notifier(context),
            zones = ZoneChangeStore(prefs),
            arming = NewClipsArming(access = { true }),
            thumbnail = { _, _ -> null },
            nowMs = { now },
            zoneId = { "Europe/London" },
        )

    private fun call(method: String): Reply {
        val reply = Reply()
        handler.onMethodCall(MethodCall(method, null), reply)
        shadowOf(Looper.getMainLooper()).idle()
        return reply
    }

    private fun notification(id: Int): Notification? = shadowOf(manager).getNotification(id)

    private fun title(id: Int) = notification(id)?.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()

    private fun sentBroadcasts(): List<Intent> = shadowOf(app).broadcastIntents

    @Test
    fun `the channel is the one Dart uses`() {
        assertEquals("app.taketray/test_background", DebugBackgroundHandler.CHANNEL)
    }

    @Test
    fun `an unknown method is not implemented`() {
        val reply = call("noSuchHook")
        assertTrue(reply.notImplemented)
        assertEquals(1, reply.replies)
    }

    // ------------------------------------------------------------ fireEvening

    @Test
    fun `fireEvening reaches the receiver and posts the evening reminder`() {
        store.write(on.copy(waitingShotMs = listOf(ReminderTestSupport.ms("2026-11-05T09:00:00Z"))))
        now = ReminderTestSupport.ms("2026-11-05T20:00:00Z")

        val reply = call("fireEvening")

        assertEquals(1, reply.replies)
        assertNull(reply.errorCode)
        assertEquals("You shot 1 clip today. Tag it?", title(Notifier.EVENING))
    }

    @Test
    fun `fireEvening sends the very broadcast the evening alarm carries`() {
        store.write(on)
        ReminderScheduler(app, ReminderTestSupport.LONDON).armEvening(store.state(), now)
        val alarmIntent = shadowOf(ReminderTestSupport.operation(ReminderTestSupport.alarm(app, ReminderScheduler.ACTION_EVENING)!!)).savedIntent
        shadowOf(app).clearBroadcastIntents()

        call("fireEvening")

        val sent = sentBroadcasts().single()
        assertTrue("same component, action and data as the alarm's", sent.filterEquals(alarmIntent))
        assertEquals(ReminderReceiver::class.java.name, sent.component?.className)
        assertEquals(alarmIntent.extras?.keySet().orEmpty(), sent.extras?.keySet().orEmpty())
    }

    @Test
    fun `fireEvening with no clip today posts nothing and answers success`() {
        store.write(on.copy(waitingShotMs = listOf(ReminderTestSupport.ms("2026-11-01T09:00:00Z"))))

        val reply = call("fireEvening")

        assertEquals(1, reply.replies)
        assertNull(reply.errorCode)
        assertNull(notification(Notifier.EVENING))
    }

    @Test
    fun `fireEvening with the reminder off posts nothing`() {
        store.write(on.copy(eveningEnabled = false, waitingShotMs = listOf(ReminderTestSupport.ms("2026-11-05T09:00:00Z"))))

        call("fireEvening")

        assertNull(notification(Notifier.EVENING))
    }

    @Test
    fun `fireEvening keeps the receiver's once-a-day rule`() {
        store.write(on.copy(waitingShotMs = listOf(ReminderTestSupport.ms("2026-11-05T09:00:00Z"))))
        call("fireEvening")
        assertNotNull(notification(Notifier.EVENING))
        manager.cancel(Notifier.EVENING)

        call("fireEvening")

        assertNull("the production rule is not bypassed", notification(Notifier.EVENING))
    }

    @Test
    fun `fireEvening re-arms the next evening as the real alarm does`() {
        store.write(on.copy(waitingShotMs = listOf(ReminderTestSupport.ms("2026-11-05T09:00:00Z"))))

        // 20:00: the next 21:00 is tonight's (its day is handled now, so it will be quiet).
        call("fireEvening")

        assertEquals("2026-11-05T21:00:00Z", ReminderTestSupport.alarmAt(app, ReminderScheduler.ACTION_EVENING))
        assertEquals(ReminderTestSupport.ms("2026-11-05T21:00:00Z"), store.eveningArmedFor())
    }

    // -------------------------------------------------------------- fireStill

    @Test
    fun `fireStill sends the very broadcast the still alarm carries, with the session`() {
        store.write(on)
        ReminderScheduler(app, ReminderTestSupport.LONDON).armStill(store.state(), now)
        val alarmIntent = shadowOf(ReminderTestSupport.operation(ReminderTestSupport.alarm(app, ReminderScheduler.ACTION_STILL)!!)).savedIntent
        shadowOf(app).clearBroadcastIntents()

        call("fireStill")

        val sent = sentBroadcasts().single()
        assertTrue(sent.filterEquals(alarmIntent))
        assertEquals(since, sent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, -1))
        assertEquals(alarmIntent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, -2), sent.getLongExtra(ReminderScheduler.EXTRA_SINCE_MS, -1))
    }

    @Test
    fun `fireStill posts Still shooting for the stored session`() {
        store.write(on)

        val reply = call("fireStill")

        assertNull(reply.errorCode)
        assertEquals("Still shooting?", title(Notifier.STILL_SHOOTING))
    }

    @Test
    fun `fireStill twice posts it once per session`() {
        store.write(on)
        call("fireStill")
        manager.cancel(Notifier.STILL_SHOOTING)

        call("fireStill")

        assertNull("one per session, the receiver's rule", notification(Notifier.STILL_SHOOTING))
        assertEquals(since, store.stillPostedSince())
    }

    @Test
    fun `fireStill with Shooting mode off answers no-session and sends nothing`() {
        store.write(BackgroundState.OFF)
        shadowOf(app).clearBroadcastIntents()

        val reply = call("fireStill")

        assertEquals("no-session", reply.errorCode)
        assertEquals(1, reply.replies)
        assertTrue(sentBroadcasts().isEmpty())
        assertNull(notification(Notifier.STILL_SHOOTING))
    }

    @Test
    fun `fireStill after the question was answered posts nothing`() {
        store.write(on.copy(stillAnswered = true))

        val reply = call("fireStill")

        assertNull(reply.errorCode)
        assertNull(notification(Notifier.STILL_SHOOTING))
    }

    @Test
    fun `fireStill with the reminder off posts nothing`() {
        store.write(on.copy(stillReminderEnabled = false))

        call("fireStill")

        assertNull(notification(Notifier.STILL_SHOOTING))
    }

    // ------------------------------------------------------- runNewClipsJob

    @Test
    fun `runNewClipsJob builds the job the service builds and runs it`() {
        var built = 0
        NewClipsJobService.newJob = { context ->
            built++
            job(context)
        }
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        SqlVideoProvider.add(id = 2, generation = 102)

        val reply = call("runNewClipsJob")

        assertEquals(1, built)
        assertEquals(1, reply.replies)
        assertNull(reply.errorCode)
        assertEquals("2 new clips to tag", title(Notifier.NEW_CLIPS))
        assertEquals(2, store.postedNewClips())
    }

    @Test
    fun `runNewClipsJob posts a clip that is only seconds old, without the quiet wait`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101, added = now / 1000 - 3)

        call("runNewClipsJob")

        assertEquals("1 new clip to tag", title(Notifier.NEW_CLIPS))
        assertNull("no settle job: the hook is the test's shortcut around the 5 minutes", scheduler.getPendingJob(NewClipsSettleJobService.JOB_ID))
    }

    @Test
    fun `runNewClipsJob arms the successor like a real run`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)

        call("runNewClipsJob")

        assertEquals(NewClipsArming.jobInfo(app), scheduler.getPendingJob(NewClipsJobService.JOB_ID))
    }

    @Test
    fun `runNewClipsJob with nothing new posts nothing and still answers`() {
        store.write(on)

        val reply = call("runNewClipsJob")

        assertEquals(1, reply.replies)
        assertNull(reply.errorCode)
        assertNull(notification(Notifier.NEW_CLIPS))
    }

    @Test
    fun `runNewClipsJob with Shooting mode off removes the notification`() {
        store.write(BackgroundState.OFF)
        manager.notify(Notifier.NEW_CLIPS, Notification.Builder(app, "x").setSmallIcon(android.R.drawable.ic_dialog_info).build())

        call("runNewClipsJob")

        assertNull(notification(Notifier.NEW_CLIPS))
    }

    @Test
    fun `runNewClipsJob replies only after the work has finished`() {
        val queued = mutableListOf<Runnable>()
        NewClipsJobService.executor = Executor { queued += it }
        handler = DebugBackgroundHandler(app, scope = CoroutineScope(Dispatchers.Unconfined))
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)

        val reply = Reply()
        handler.onMethodCall(MethodCall("runNewClipsJob", null), reply)

        assertEquals("not answered while the job has not run", 0, reply.replies)
        assertFalse(notification(Notifier.NEW_CLIPS) != null)
        queued.forEach { it.run() }
        // The reply is sent from the scope's thread, which here is the same.
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, reply.replies)
        assertEquals("1 new clip to tag", title(Notifier.NEW_CLIPS))
    }

    // ------------------------------------------------- activeNotifications

    private fun notify(id: Int) {
        val n = Notification.Builder(app, "x").setSmallIcon(android.R.drawable.ic_dialog_info).build()
        manager.notify(id, n)
    }

    @Test
    fun `activeNotifications lists the ids of this app's notifications, sorted`() {
        notify(Notifier.STILL_SHOOTING)
        notify(Notifier.NEW_CLIPS)

        val reply = call("activeNotifications")

        assertEquals(1, reply.replies)
        assertEquals(listOf(Notifier.NEW_CLIPS, Notifier.STILL_SHOOTING), reply.success)
    }

    @Test
    fun `activeNotifications is an empty list when nothing is posted, and after a cancel`() {
        assertEquals(emptyList<Int>(), call("activeNotifications").success)
        notify(Notifier.EVENING)
        manager.cancel(Notifier.EVENING)

        assertEquals(emptyList<Int>(), call("activeNotifications").success)
    }

    @Test
    fun `activeNotifications shows what the job posted and what turning off removes`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        call("runNewClipsJob")
        assertEquals(listOf(Notifier.NEW_CLIPS), call("activeNotifications").success)

        store.write(BackgroundState.OFF)
        call("runNewClipsJob")

        assertEquals(emptyList<Int>(), call("activeNotifications").success)
    }

    // ------------------------------------------------------------ pendingJobs

    @Test
    fun `pendingJobs is empty when no job is armed`() {
        assertEquals(emptyList<Int>(), call("pendingJobs").success)
    }

    @Test
    fun `pendingJobs lists the one job a run arms, however many runs`() {
        store.write(on)
        SqlVideoProvider.add(id = 1, generation = 101)
        repeat(3) { call("runNewClipsJob") }

        assertEquals(listOf(NewClipsJobService.JOB_ID), call("pendingJobs").success)
    }

    @Test
    fun `pendingJobs lists every pending job id, sorted`() {
        val other =
            android.app.job.JobInfo
                .Builder(7, android.content.ComponentName(app, NewClipsJobService::class.java))
                .setMinimumLatency(60_000)
                .build()
        scheduler.schedule(other)
        store.write(on)
        call("runNewClipsJob")

        assertEquals(listOf(7, NewClipsJobService.JOB_ID).sorted(), call("pendingJobs").success)
    }

    @Test
    fun `a job that cannot be built is a native-error with the class only`() {
        NewClipsJobService.newJob = { throw IllegalStateException("/storage/emulated/0/Movies/TakeTray Test/secret.mp4") }

        val reply = call("runNewClipsJob")

        assertEquals("native-error", reply.errorCode)
        assertEquals(1, reply.replies)
        assertTrue(reply.errorMessage!!.contains("IllegalStateException"))
        assertFalse("no path (D-10)", reply.errorMessage!!.contains("storage"))
        assertFalse(reply.errorMessage!!.contains("secret"))
    }

    @Test
    fun `thermalStatus is the phone's thermal status now, a number only`() {
        val power = app.getSystemService(PowerManager::class.java)
        for (status in listOf(
            PowerManager.THERMAL_STATUS_NONE,
            PowerManager.THERMAL_STATUS_LIGHT,
            PowerManager.THERMAL_STATUS_MODERATE,
            PowerManager.THERMAL_STATUS_SEVERE,
            PowerManager.THERMAL_STATUS_SHUTDOWN,
        )) {
            shadowOf(power).setCurrentThermalStatus(status)

            val reply = call("thermalStatus")

            assertEquals("status $status", status, reply.success)
            assertEquals(1, reply.replies)
        }
    }

    @Test
    fun `thermalStatus is read at call time, not once`() {
        val power = app.getSystemService(PowerManager::class.java)
        shadowOf(power).setCurrentThermalStatus(PowerManager.THERMAL_STATUS_NONE)
        assertEquals(0, call("thermalStatus").success)

        shadowOf(power).setCurrentThermalStatus(PowerManager.THERMAL_STATUS_MODERATE)

        assertEquals(2, call("thermalStatus").success)
    }

    @Test
    fun `thermalStatus that throws is a native-error with the class only`() {
        handler =
            DebugBackgroundHandler(
                app,
                scope = CoroutineScope(Dispatchers.Unconfined),
                io = Dispatchers.Unconfined,
                thermalStatus = { throw SecurityException("/storage/emulated/0/secret") },
            )

        val reply = call("thermalStatus")

        assertEquals("native-error", reply.errorCode)
        assertTrue(reply.errorMessage!!.contains("SecurityException"))
        assertFalse(reply.errorMessage!!.contains("secret"))
        assertNull(reply.success)
    }

    // -------------------------------------------------------- pressStillTurnOff

    private fun broadcastFor(action: String): PendingIntent =
        PendingIntent.getBroadcast(
            app,
            action.hashCode(),
            ShadeActionReceiver.intent(app, action, since),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    /** Id 3 with exactly these (label, broadcast action) buttons, in this order. */
    private fun postStill(
        id: Int,
        vararg buttons: Pair<String, String>,
    ) {
        val builder = Notification.Builder(app, Notifier.CHANNEL_REMINDERS).setSmallIcon(android.R.drawable.ic_dialog_info)
        for ((label, action) in buttons) {
            builder.addAction(Notification.Action.Builder(null as Icon?, label, broadcastFor(action)).build())
        }
        manager.notify(id, builder.build())
    }

    private fun shadeBroadcasts(): List<String?> = sentBroadcasts().filter { it.component?.className == ShadeActionReceiver::class.java.name }.map { it.action }

    @Test
    fun `pressStillTurnOff fires the real Turn off button, through the receiver`() {
        store.write(on)
        assertTrue(Notifier(app).showStillShooting(since))
        assertNotNull(notification(Notifier.STILL_SHOOTING))

        val reply = call("pressStillTurnOff")

        assertEquals(1, reply.replies)
        assertNull(reply.errorCode)
        assertEquals(listOf(ShadeActionReceiver.ACTION_TURN_OFF), shadeBroadcasts())
        assertFalse("the receiver ran: Shooting mode is off", store.state().shootingOn)
        assertNull("and the notification is gone", notification(Notifier.STILL_SHOOTING))
    }

    @Test
    fun `pressStillTurnOff with the notification not posted is an error and sends nothing`() {
        store.write(on)

        val reply = call("pressStillTurnOff")

        assertEquals("no-notification", reply.errorCode)
        assertEquals(1, reply.replies)
        assertTrue(shadeBroadcasts().isEmpty())
        assertTrue("Shooting mode is untouched", store.state().shootingOn)
    }

    @Test
    fun `pressStillTurnOff with a notification of id 3 that has no actions is an error`() {
        postStill(Notifier.STILL_SHOOTING)

        val reply = call("pressStillTurnOff")

        assertEquals("no-action", reply.errorCode)
        assertTrue(shadeBroadcasts().isEmpty())
    }

    @Test
    fun `pressStillTurnOff with only Keep on is an error and never presses it`() {
        postStill(Notifier.STILL_SHOOTING, "Keep on" to ShadeActionReceiver.ACTION_KEEP_ON)

        val reply = call("pressStillTurnOff")

        assertEquals("no-action", reply.errorCode)
        assertTrue("Keep on is not pressed instead", shadeBroadcasts().isEmpty())
    }

    @Test
    fun `pressStillTurnOff finds Turn off when it is not the first action`() {
        postStill(
            Notifier.STILL_SHOOTING,
            "Keep on" to ShadeActionReceiver.ACTION_KEEP_ON,
            "Turn off" to ShadeActionReceiver.ACTION_TURN_OFF,
        )

        val reply = call("pressStillTurnOff")

        assertNull(reply.errorCode)
        assertEquals("only the Turn off button is pressed", listOf(ShadeActionReceiver.ACTION_TURN_OFF), shadeBroadcasts())
    }

    @Test
    fun `pressStillTurnOff finds Turn off when it is first, with Keep on after`() {
        postStill(
            Notifier.STILL_SHOOTING,
            "Turn off" to ShadeActionReceiver.ACTION_TURN_OFF,
            "Keep on" to ShadeActionReceiver.ACTION_KEEP_ON,
        )

        call("pressStillTurnOff")

        assertEquals(listOf(ShadeActionReceiver.ACTION_TURN_OFF), shadeBroadcasts())
    }

    @Test
    fun `pressStillTurnOff matches the label exactly, not a part of it or another case`() {
        for (label in listOf("Turn Off", "turn off", "Turn off now", "Turn", "")) {
            shadowOf(app).clearBroadcastIntents()
            postStill(Notifier.STILL_SHOOTING, label to ShadeActionReceiver.ACTION_TURN_OFF)

            val reply = call("pressStillTurnOff")

            assertEquals("label '$label'", "no-action", reply.errorCode)
            assertTrue("label '$label'", shadeBroadcasts().isEmpty())
        }
    }

    @Test
    fun `pressStillTurnOff ignores a Turn off on another notification id`() {
        postStill(Notifier.NEW_CLIPS, "Turn off" to ShadeActionReceiver.ACTION_TURN_OFF)
        postStill(Notifier.EVENING, "Turn off" to ShadeActionReceiver.ACTION_TURN_OFF)

        val reply = call("pressStillTurnOff")

        assertEquals("no-notification", reply.errorCode)
        assertTrue(shadeBroadcasts().isEmpty())
    }

    @Test
    fun `pressStillTurnOff for an older session leaves Shooting mode on, like the real button`() {
        store.write(on.copy(sinceMs = since + 1))
        assertTrue(Notifier(app).showStillShooting(since))

        call("pressStillTurnOff")

        assertEquals(listOf(ShadeActionReceiver.ACTION_TURN_OFF), shadeBroadcasts())
        assertTrue("the receiver checks the session itself", store.state().shootingOn)
    }

    @Test
    fun `pressStillTurnOff presses the button exactly once`() {
        store.write(on)
        Notifier(app).showStillShooting(since)

        call("pressStillTurnOff")

        assertEquals(1, shadeBroadcasts().size)
    }
}
