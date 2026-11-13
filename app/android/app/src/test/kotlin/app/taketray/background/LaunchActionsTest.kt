package app.taketray.background

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.app.Notification
import android.app.NotificationManager
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import app.taketray.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

/**
 * Launch actions (D-103): the allow-listed extra a notification puts on its
 * MainActivity intent, read once, and the relay that hands it to Dart. Other
 * apps can start the exported activity with any extra, so anything that is
 * not exactly `toTag` or `reels` is ignored.
 */
@RunWith(RobolectricTestRunner::class)
class LaunchActionsTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    /** What the relay sent to Dart, in order. */
    private val sent = mutableListOf<LaunchMsg>()

    /** A relay whose sends run at once, on the test thread. */
    private fun relay(fail: Boolean = false) =
        LaunchActionRelay(
            send = { action ->
                if (fail) throw IllegalStateException("no Dart listener")
                sent += action
            },
            scope = CoroutineScope(Dispatchers.Unconfined),
        )

    private fun openIntent(value: Any?): Intent =
        Intent(context, MainActivity::class.java).apply {
            when (value) {
                is String -> putExtra(LaunchActions.EXTRA_OPEN, value)
                is Int -> putExtra(LaunchActions.EXTRA_OPEN, value)
                null -> putExtra(LaunchActions.EXTRA_OPEN, null as String?)
            }
        }

    @Test
    fun `the notification intent opens MainActivity with the action`() {
        for ((action, value) in listOf(LaunchActionMsg.TO_TAG to "toTag", LaunchActionMsg.REELS to "reels")) {
            val intent = LaunchActions.intent(context, action)
            assertEquals(ComponentName(context, MainActivity::class.java), intent.component)
            assertEquals(value, intent.getStringExtra(LaunchActions.EXTRA_OPEN))
            assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
            assertEquals(LaunchMsg(action), LaunchActions.read(intent))
        }
        // The two intents differ for PendingIntent (which ignores extras).
        assertFalse(LaunchActions.intent(context, LaunchActionMsg.TO_TAG).filterEquals(LaunchActions.intent(context, LaunchActionMsg.REELS)))
    }

    @Test
    fun `unknown launch action ignored`() {
        for (value in listOf<Any?>("settings", "/reels/1", "TOTAG", "toTag ", "", 1, null)) {
            val intent = openIntent(value)
            assertNull("$value", LaunchActions.read(intent))
            assertFalse("$value", intent.hasExtra(LaunchActions.EXTRA_OPEN))
        }
        // No extra at all, and no intent.
        assertNull(LaunchActions.read(Intent(context, MainActivity::class.java)))
        assertNull(LaunchActions.read(null))

        val relay = relay()
        relay.onIntent(openIntent("settings"))
        assertNull(relay.take())
        relay.onIntent(openIntent("debug"))
        assertTrue(sent.isEmpty())
    }

    @Test
    fun `launch action from history ignored`() {
        // Reopened from Recents: Android replays the first intent, extra and all.
        val intent = LaunchActions.intent(context, LaunchActionMsg.TO_TAG).addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        val relay = relay()
        relay.onIntent(intent)
        assertNull(relay.take())
        assertFalse(intent.hasExtra(LaunchActions.EXTRA_OPEN))

        // Once Dart listens, a replay is not sent either.
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS).addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY))
        assertTrue(sent.isEmpty())
    }

    @Test
    fun `extra removed after reading`() {
        val intent = LaunchActions.intent(context, LaunchActionMsg.REELS)
        val controller = Robolectric.buildActivity(Activity::class.java, intent).setup()
        val relay = relay()

        relay.onIntent(controller.get().intent)
        assertEquals(LaunchMsg(LaunchActionMsg.REELS), relay.take())

        // The activity is re-created (a configuration change MainActivity
        // does not handle) with the same intent: nothing to deliver again,
        // although Dart is listening now.
        val recreated = controller.recreate().get()
        relay.onIntent(recreated.intent)
        assertEquals("delivered again after re-creation", emptyList<LaunchMsg>(), sent)
        assertNull(relay.take())
        assertFalse(recreated.intent.hasExtra(LaunchActions.EXTRA_OPEN))

        // The same intent read twice gives the action once.
        val twice = LaunchActions.intent(context, LaunchActionMsg.TO_TAG)
        assertEquals(LaunchMsg(LaunchActionMsg.TO_TAG), LaunchActions.read(twice))
        assertNull(LaunchActions.read(twice))
    }

    @Test
    fun `an activity restored from saved state does not act on its intent`() {
        // After the process died, Android restores the activity with the
        // intent it was first started with, extra included.
        val relay = relay()
        val intent = LaunchActions.intent(context, LaunchActionMsg.TO_TAG)
        relay.onIntent(intent, restored = true)
        assertNull(relay.take())
        assertFalse(intent.hasExtra(LaunchActions.EXTRA_OPEN))
    }

    @Test
    fun `the action waits for Dart, then goes through the Flutter API`() {
        val relay = relay()
        // Cold start: kept until Dart asks.
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        assertTrue(sent.isEmpty())
        assertEquals(LaunchMsg(LaunchActionMsg.TO_TAG), relay.take())
        assertNull(relay.take())

        // Dart listens now: a new tap goes straight to it.
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertEquals(listOf(LaunchMsg(LaunchActionMsg.REELS)), sent)
        assertNull(relay.take())
    }

    @Test
    fun `the newest action wins while Dart is not listening`() {
        val relay = relay()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertEquals(LaunchMsg(LaunchActionMsg.REELS), relay.take())
    }

    @Test
    fun `an action Dart could not take is kept for the next take`() {
        val relay = relay(fail = true)
        assertNull(relay.take())
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertEquals(LaunchMsg(LaunchActionMsg.REELS), relay.take())
    }

    // ---- The evening reminder goes when To tag opens (final review I-3) ----

    /** MainActivity's relay: its sends run at once, and a To tag action removes the evening reminder. */
    private fun phoneRelay() = LaunchActionRelay.forActivity(context, send = { sent += it }, scope = CoroutineScope(Dispatchers.Unconfined))

    private fun postEvening() {
        shadowOf(context.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(true)
        assertTrue(Notifier(context).showEvening(2))
        assertNotNull(ReminderTestSupport.notification(context, Notifier.EVENING))
    }

    private fun eveningShowing() = ReminderTestSupport.notification(context, Notifier.EVENING) != null

    @Test
    fun `tag now and the body tap on the evening reminder remove it`() {
        // Both taps start MainActivity with the same To tag action; Android does not cancel for an action button.
        val taps = listOf<(Notification) -> android.app.PendingIntent>({ it.contentIntent }, { it.actions.single().actionIntent })
        for (tap in taps) {
            postEvening()
            val n = ReminderTestSupport.notification(context, Notifier.EVENING) ?: throw AssertionError("no evening reminder")
            phoneRelay().onIntent(Intent(shadowOf(tap(n)).savedIntent))
            assertFalse(eveningShowing())
        }
    }

    @Test
    fun `a To tag action from the new clips notification removes it too, a Reels action does not`() {
        postEvening()
        phoneRelay().onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertTrue("the Still shooting? body tap opens Reels and leaves it", eveningShowing())
        phoneRelay().onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        assertFalse(eveningShowing())
    }

    @Test
    fun `a cold start with To tag removes it before Dart listens, and the action is still kept`() {
        postEvening()
        val relay = phoneRelay()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        assertFalse(eveningShowing())
        assertEquals(LaunchMsg(LaunchActionMsg.TO_TAG), relay.take())
    }

    @Test
    fun `a replayed, restored or unknown launch leaves the evening reminder`() {
        postEvening()
        val relay = phoneRelay()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG), restored = true)
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG).addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY))
        relay.onIntent(openIntent("TOTAG"))
        relay.onIntent(Intent(context, MainActivity::class.java))
        relay.onIntent(null)
        assertTrue(eveningShowing())
    }

    @Test
    fun `without the notification permission opening To tag still works`() {
        shadowOf(context.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)
        val relay = phoneRelay()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        assertEquals(LaunchMsg(LaunchActionMsg.TO_TAG), relay.take())
    }

    @Test
    fun `a failing removal never stops the action and logs only its class`() {
        val relay =
            LaunchActionRelay(
                send = { sent += it },
                scope = CoroutineScope(Dispatchers.Unconfined),
                onToTag = { throw IllegalStateException("secret-notification") },
            )
        ShadowLog.clear()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        assertEquals(LaunchMsg(LaunchActionMsg.TO_TAG), relay.take())
        assertEquals(listOf("evening reminder not removed: IllegalStateException"), ShadowLog.getLogsForTag(LOG_TAG).map { it.msg })
        assertTrue(ShadowLog.getLogs().none { "secret-notification" in it.msg || it.throwable != null })
    }

    // ---- Done editing (Phase 8, D-124): the reel id is the only payload ----

    @Test
    fun `a Done editing intent names its reel and reads back once`() {
        val intent = LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 42)
        assertEquals(ComponentName(context, MainActivity::class.java), intent.component)
        assertEquals("doneEditing", intent.getStringExtra(LaunchActions.EXTRA_OPEN))
        assertEquals(42L, intent.getLongExtra(LaunchActions.EXTRA_REEL_ID, -1))
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, 42), LaunchActions.read(intent))
        assertFalse(intent.hasExtra(LaunchActions.EXTRA_OPEN))
        assertFalse(intent.hasExtra(LaunchActions.EXTRA_REEL_ID))
        assertNull("read once", LaunchActions.read(intent))
    }

    @Test
    fun `Done editing intents of two reels, or of Done editing and To tag, never replace each other`() {
        val one = LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 1)
        val two = LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 2)
        assertFalse("PendingIntent compares intents without their extras", one.filterEquals(two))
        assertFalse(one.filterEquals(LaunchActions.intent(context, LaunchActionMsg.TO_TAG)))
        assertFalse(one.filterEquals(LaunchActions.intent(context, LaunchActionMsg.REELS)))
        assertTrue(one.filterEquals(LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 1)))
    }

    @Test
    fun `a Done editing intent without a usable reel id makes no intent`() {
        for (id in listOf<Long?>(null, 0, -1, -997, BackgroundState.MAX_REEL_ID + 1, Long.MAX_VALUE)) {
            try {
                LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, id)
                org.junit.Assert.fail("expected a refusal for $id")
            } catch (e: IllegalArgumentException) {
                // Refused, as expected.
            }
        }
        // The largest id the request codes can hold is fine.
        val max = LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, BackgroundState.MAX_REEL_ID)
        assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, BackgroundState.MAX_REEL_ID), LaunchActions.read(max))
    }

    @Test
    fun `a Done editing launch with a bad reel id still opens, with no reel`() {
        // Another app can start the exported activity with anything: the action stays (Dart opens Reels), the reel is dropped.
        val bad = listOf<Any?>(null, "7", 7, 7.0, 0L, -1L, -999L, BackgroundState.MAX_REEL_ID + 1, Long.MAX_VALUE, longArrayOf(7))
        for (id in bad) {
            val intent = Intent(context, MainActivity::class.java).putExtra(LaunchActions.EXTRA_OPEN, "doneEditing")
            when (id) {
                is String -> intent.putExtra(LaunchActions.EXTRA_REEL_ID, id)
                is Int -> intent.putExtra(LaunchActions.EXTRA_REEL_ID, id)
                is Double -> intent.putExtra(LaunchActions.EXTRA_REEL_ID, id)
                is Long -> intent.putExtra(LaunchActions.EXTRA_REEL_ID, id)
                is LongArray -> intent.putExtra(LaunchActions.EXTRA_REEL_ID, id)
            }
            assertEquals("$id", LaunchMsg(LaunchActionMsg.DONE_EDITING, null), LaunchActions.read(intent))
            assertFalse("$id", intent.hasExtra(LaunchActions.EXTRA_REEL_ID))
        }
    }

    @Test
    fun `a reel id on a To tag or Reels launch is dropped`() {
        for ((value, action) in listOf("toTag" to LaunchActionMsg.TO_TAG, "reels" to LaunchActionMsg.REELS)) {
            val intent = Intent(context, MainActivity::class.java).putExtra(LaunchActions.EXTRA_OPEN, value).putExtra(LaunchActions.EXTRA_REEL_ID, 7L)
            assertEquals(LaunchMsg(action, null), LaunchActions.read(intent))
            assertFalse(intent.hasExtra(LaunchActions.EXTRA_REEL_ID))
        }
        // The intents Android builds for those never carry one.
        assertFalse(LaunchActions.intent(context, LaunchActionMsg.TO_TAG, 7).hasExtra(LaunchActions.EXTRA_REEL_ID))
        assertFalse(LaunchActions.intent(context, LaunchActionMsg.REELS, 7).hasExtra(LaunchActions.EXTRA_REEL_ID))
    }

    @Test
    fun `a reel id alone, without an action, opens nothing and is removed`() {
        val intent = Intent(context, MainActivity::class.java).putExtra(LaunchActions.EXTRA_REEL_ID, 7L)
        assertNull(LaunchActions.read(intent))
        // The extras another app sent are not left behind for a later read.
        val unknown = Intent(context, MainActivity::class.java).putExtra(LaunchActions.EXTRA_OPEN, "reels2").putExtra(LaunchActions.EXTRA_REEL_ID, 7L)
        assertNull(LaunchActions.read(unknown))
        assertFalse(unknown.hasExtra(LaunchActions.EXTRA_REEL_ID))
    }

    @Test
    fun `a Done editing launch from history or a restored activity is dropped with its reel id`() {
        val replay = LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 7).addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        val relay = relay()
        relay.onIntent(replay)
        assertNull(relay.take())
        assertFalse(replay.hasExtra(LaunchActions.EXTRA_REEL_ID))

        val restored = LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 7)
        relay.onIntent(restored, restored = true)
        assertNull(relay.take())
        assertFalse(restored.hasExtra(LaunchActions.EXTRA_REEL_ID))
        assertTrue(sent.isEmpty())
    }

    @Test
    fun `the relay hands Done editing and its reel to Dart, kept until Dart listens and then sent`() {
        val relay = relay()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 7))
        assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, 7), relay.take())
        assertTrue(sent.isEmpty())
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 8))
        assertEquals(listOf(LaunchMsg(LaunchActionMsg.DONE_EDITING, 8)), sent)
    }

    private fun postCopies(
        reelId: Long,
        name: String = "Trip",
    ) {
        shadowOf(context.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(true)
        assertTrue(Notifier(context).showCopies(BackgroundState.CopiesReminder(reelId, name, 2_000_000_000, 1_780_000_000_000)))
    }

    private fun copiesShowing(reelId: Long) = ReminderTestSupport.notification(context, (Notifier.COPIES_ID_BASE + reelId).toInt()) != null

    @Test
    fun `the Done editing body and button taps remove only that reel's reminder`() {
        val taps = listOf<(Notification) -> android.app.PendingIntent>({ it.contentIntent }, { it.actions.single().actionIntent })
        for (tap in taps) {
            postCopies(7)
            postCopies(8)
            postEvening()
            val n = ReminderTestSupport.notification(context, Notifier.COPIES_ID_BASE + 7) ?: throw AssertionError("no reminder for reel 7")
            val relay = phoneRelay()
            relay.onIntent(Intent(shadowOf(tap(n)).savedIntent))
            assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, 7), relay.take())
            assertFalse("the tapped reel's goes", copiesShowing(7))
            assertTrue("another reel's stays", copiesShowing(8))
            assertTrue("Phase 6's stay", eveningShowing())
            Notifier(context).cancelCopies(8)
            Notifier(context).cancelEvening()
        }
    }

    @Test
    fun `a Done editing launch with a bad reel id removes no reminder, and a failing removal never stops it`() {
        postCopies(7)
        val relay = phoneRelay()
        relay.onIntent(Intent(context, MainActivity::class.java).putExtra(LaunchActions.EXTRA_OPEN, "doneEditing"))
        assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, null), relay.take())
        assertTrue(copiesShowing(7))

        val failing =
            LaunchActionRelay(
                send = { sent += it },
                scope = CoroutineScope(Dispatchers.Unconfined),
                onDoneEditing = { throw IllegalStateException("secret-reel-name") },
            )
        ShadowLog.clear()
        failing.onIntent(LaunchActions.intent(context, LaunchActionMsg.DONE_EDITING, 7))
        assertEquals(LaunchMsg(LaunchActionMsg.DONE_EDITING, 7), failing.take())
        assertEquals(listOf("copies reminder not removed: IllegalStateException"), ShadowLog.getLogsForTag(LOG_TAG).map { it.msg })
        assertTrue(ShadowLog.getLogs().none { "secret-reel-name" in it.msg || it.throwable != null })
    }

    @Test
    fun `To tag and Reels launches leave the copies reminders alone`() {
        postCopies(7)
        phoneRelay().onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        phoneRelay().onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertTrue(copiesShowing(7))
    }

    @Test
    fun `deep linking is off`() {
        // The merged manifest, as the phone sees it.
        val info =
            context.packageManager.getActivityInfo(
                ComponentName(context, MainActivity::class.java),
                PackageManager.GET_META_DATA,
            )
        assertTrue(info.exported)
        val metaData = info.metaData
        assertNotNull(metaData)
        assertTrue(metaData.containsKey("flutter_deeplinking_enabled"))
        assertFalse(metaData.getBoolean("flutter_deeplinking_enabled", true))
    }

    @Test
    fun `the route extra is ignored`() {
        // Flutter reads `route` from any launching intent, deep linking or not;
        // another app could open any screen with it.
        val intent = Intent(context, MainActivity::class.java).putExtra("route", "/settings")
        val activity = Robolectric.buildActivity(MainActivity::class.java, intent).get()
        assertNull(activity.initialRoute)
    }
}
