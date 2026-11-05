package app.taketray.background

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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
    private val sent = mutableListOf<LaunchActionMsg>()

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
            assertEquals(action, LaunchActions.read(intent))
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
        assertEquals(LaunchActionMsg.REELS, relay.take())

        // The activity is re-created (a configuration change MainActivity
        // does not handle) with the same intent: nothing to deliver again,
        // although Dart is listening now.
        val recreated = controller.recreate().get()
        relay.onIntent(recreated.intent)
        assertEquals("delivered again after re-creation", emptyList<LaunchActionMsg>(), sent)
        assertNull(relay.take())
        assertFalse(recreated.intent.hasExtra(LaunchActions.EXTRA_OPEN))

        // The same intent read twice gives the action once.
        val twice = LaunchActions.intent(context, LaunchActionMsg.TO_TAG)
        assertEquals(LaunchActionMsg.TO_TAG, LaunchActions.read(twice))
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
        assertEquals(LaunchActionMsg.TO_TAG, relay.take())
        assertNull(relay.take())

        // Dart listens now: a new tap goes straight to it.
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertEquals(listOf(LaunchActionMsg.REELS), sent)
        assertNull(relay.take())
    }

    @Test
    fun `the newest action wins while Dart is not listening`() {
        val relay = relay()
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.TO_TAG))
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertEquals(LaunchActionMsg.REELS, relay.take())
    }

    @Test
    fun `an action Dart could not take is kept for the next take`() {
        val relay = relay(fail = true)
        assertNull(relay.take())
        relay.onIntent(LaunchActions.intent(context, LaunchActionMsg.REELS))
        assertEquals(LaunchActionMsg.REELS, relay.take())
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
