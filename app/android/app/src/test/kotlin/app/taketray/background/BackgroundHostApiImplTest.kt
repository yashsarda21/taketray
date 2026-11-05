package app.taketray.background

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import app.taketray.media.MediaHostApiImpl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowBuild

/**
 * The background bridge on a Robolectric activity: the mirror written before
 * arming, the shade action, the notification permission (Android 13+ only,
 * with its own request code), the settings intents and the phone maker.
 */
@RunWith(RobolectricTestRunner::class)
class BackgroundHostApiImplTest {
    private lateinit var activity: Activity
    private lateinit var impl: BackgroundHostApiImpl
    private lateinit var store: BackgroundStateStore
    private lateinit var notifications: NotificationManager
    private val sdk get() = Build.VERSION.SDK_INT
    private val code = BackgroundHostApiImpl.PERMISSION_REQUEST_CODE

    /** Every Arming.apply call: the state passed and the state stored at that moment. */
    private val armed = mutableListOf<Pair<BackgroundState, BackgroundState>>()

    private val stateMsg =
        BackgroundStateMsg(
            shootingOn = true,
            sinceMs = 1_780_000_000_123,
            baselines = listOf(VolumeBaselineMsg("external_primary", "abc123", 90_210)),
            watchedFolders = listOf("DCIM/Camera/"),
            waitingShotMs = listOf(1_780_000_000_000),
            eveningEnabled = true,
            eveningMinutes = 1_260,
            stillReminderEnabled = true,
            stillAnswered = false,
        )

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val prefs = activity.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        store = BackgroundStateStore(prefs)
        notifications = activity.getSystemService(NotificationManager::class.java)
        impl = newImpl()
    }

    private fun newImpl(ask: ((Activity, Array<String>, Int) -> Unit)? = null): BackgroundHostApiImpl {
        val arming = Arming { _, state, _ -> armed += state to store.state() }
        val relay = LaunchActionRelay(send = {}, scope = CoroutineScope(Dispatchers.Unconfined))
        return if (ask == null) BackgroundHostApiImpl(activity, arming, relay) else BackgroundHostApiImpl(activity, arming, relay, ask)
    }

    private fun timed(body: suspend CoroutineScope.() -> Unit) = runBlocking { withTimeout(5_000) { supervisorScope { body() } } }

    @Test
    fun `writeState stores then arms`() =
        timed {
            impl.writeState(stateMsg)
            val expected = BackgroundState.from(stateMsg)
            assertEquals(expected, store.state())
            // Armed once, with the new state, which was already stored.
            assertEquals(listOf(expected to expected), armed)

            impl.writeState(stateMsg.copy(shootingOn = false, sinceMs = null, baselines = emptyList()))
            assertEquals(2, armed.size)
            assertFalse(armed.last().first.shootingOn)
            assertEquals(armed.last().first, armed.last().second)
        }

    @Test
    fun `the app's own off write still cancels the new clips notification`() =
        timed {
            // The real arming, as MainActivity passes it.
            val full = if (sdk >= 33) "android.permission.READ_MEDIA_VIDEO" else "android.permission.READ_EXTERNAL_STORAGE"
            shadowOf(activity.application).grantPermissions(full)
            shadowOf(notifications).setNotificationsEnabled(true)
            val real = BackgroundHostApiImpl(activity, Arming.background(), LaunchActionRelay(send = {}, scope = CoroutineScope(Dispatchers.Unconfined)))
            real.writeState(stateMsg)
            Notifier(activity).showNewClips(3, null)
            store.setPostedNewClips(3)
            // Turned off in the app (not the shade's Turn off): the notification goes with the job.
            real.writeState(stateMsg.copy(shootingOn = false, sinceMs = null))
            assertNull(shadowOf(notifications).getNotification(Notifier.NEW_CLIPS))
            assertEquals(0, store.postedNewClips())
        }

    @Test
    fun `a failing arming reaches Dart as native-error, with the state stored`() =
        timed {
            val failing =
                BackgroundHostApiImpl(
                    activity,
                    { _, _, _ -> throw IllegalStateException("/storage/emulated/0/DCIM/Camera") },
                    LaunchActionRelay(send = {}, scope = CoroutineScope(Dispatchers.Unconfined)),
                )
            try {
                failing.writeState(stateMsg)
                fail("expected an error")
            } catch (e: FlutterError) {
                assertEquals("native-error", e.code)
                assertEquals("writeState failed: IllegalStateException", e.message)
            }
            assertEquals(BackgroundState.from(stateMsg), store.state())
        }

    @Test
    fun `the shade action goes through the store`() {
        assertNull(impl.pendingShadeAction())
        val action = ShadeActionMsg(ShadeActionKindMsg.KEEP_ON, 1, 2, emptyList())
        store.putShadeAction(action)
        assertEquals(action, impl.pendingShadeAction())
        impl.clearShadeAction(1)
        assertEquals(action, impl.pendingShadeAction())
        impl.clearShadeAction(2)
        assertNull(impl.pendingShadeAction())
    }

    @Test
    fun `clearing the new-clips notification cancels id 1 and forgets the count`() {
        notifications.createNotificationChannel(NotificationChannel("t", "t", NotificationManager.IMPORTANCE_LOW))
        val notification = Notification.Builder(activity, "t").setSmallIcon(android.R.drawable.ic_menu_camera).build()
        notifications.notify(Notifier.NEW_CLIPS, notification)
        notifications.notify(2, notification)
        store.setPostedNewClips(4)

        impl.clearNewClipsNotification()

        assertNull(shadowOf(notifications).getNotification(Notifier.NEW_CLIPS))
        // Another notification (a reminder) stays.
        assertEquals(1, shadowOf(notifications).size())
        assertEquals(0, store.postedNewClips())
    }

    @Test
    @Config(sdk = [30])
    fun `notification access below 33 is granted and cannot ask`() =
        timed {
            val granted = NotificationAccessMsg(granted = true, canAsk = false, sdkInt = 30)
            assertEquals(granted, impl.notificationAccess())
            // No dialog exists: the request reports the same, and asks nothing.
            assertEquals(granted, impl.requestNotificationAccess())
            assertNull(shadowOf(activity).lastRequestedPermission)

            // Notifications switched off in Settings: not granted, still no dialog.
            shadowOf(notifications).setNotificationsEnabled(false)
            val off = NotificationAccessMsg(granted = false, canAsk = false, sdkInt = 30)
            assertEquals(off, impl.notificationAccess())
            assertEquals(off, impl.requestNotificationAccess())
            assertNull(shadowOf(activity).lastRequestedPermission)
        }

    // ---- Android 13 and later ----

    private fun rationale(show: Boolean) =
        shadowOf(activity.packageManager).setShouldShowRequestPermissionRationale(BackgroundHostApiImpl.POST_NOTIFICATIONS, show)

    /** Notifications not allowed yet: the state of a fresh install on 13+. */
    private fun notAllowed() = shadowOf(notifications).setNotificationsEnabled(false)

    private fun allow() {
        shadowOf(activity.application).grantPermissions(BackgroundHostApiImpl.POST_NOTIFICATIONS)
        shadowOf(notifications).setNotificationsEnabled(true)
    }

    private suspend fun CoroutineScope.request(
        before: Boolean,
        after: Boolean,
        grant: Boolean = false,
    ): NotificationAccessMsg {
        rationale(before)
        val pending = async(start = CoroutineStart.UNDISPATCHED) { impl.requestNotificationAccess() }
        rationale(after)
        if (grant) allow()
        assertTrue(impl.onPermissionResult(code))
        return pending.await()
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun `on 13 and later the request asks for POST_NOTIFICATIONS with its own code`() =
        timed {
            notAllowed()
            assertEquals(NotificationAccessMsg(false, true, sdk.toLong()), impl.notificationAccess())

            val pending = async(start = CoroutineStart.UNDISPATCHED) { impl.requestNotificationAccess() }
            val asked = shadowOf(activity).lastRequestedPermission
            assertArrayEquals(arrayOf(BackgroundHostApiImpl.POST_NOTIFICATIONS), asked.requestedPermissions)
            assertEquals(code, asked.requestCode)
            // The media bridge's result is not this one's.
            assertTrue(code != MediaHostApiImpl.PERMISSION_REQUEST_CODE)
            assertFalse(impl.onPermissionResult(MediaHostApiImpl.PERMISSION_REQUEST_CODE))
            assertFalse(pending.isCompleted)

            allow()
            assertTrue(impl.onPermissionResult(code))
            assertEquals(NotificationAccessMsg(true, false, sdk.toLong()), pending.await())
            // A late result with nothing waiting is harmless.
            assertFalse(impl.onPermissionResult(code))
        }

    @Test
    @Config(sdk = [33, 34, 35])
    fun `two denials stop the asking, and a grant clears it`() =
        timed {
            notAllowed()
            // A first dismissal stays askable.
            assertTrue(request(before = false, after = false).canAsk)
            // A first denial: Android now gives a rationale.
            assertTrue(request(before = false, after = true).canAsk)
            // The second denial: the rationale goes from true to false.
            assertFalse(request(before = true, after = false).canAsk)
            assertFalse(impl.notificationAccess().canAsk)
            // A fresh bridge (the app restarted) remembers it.
            assertFalse(newImpl().notificationAccess().canAsk)

            // Allowed in Settings, then switched off again: askable.
            allow()
            assertEquals(NotificationAccessMsg(true, false, sdk.toLong()), impl.notificationAccess())
            shadowOf(activity.application).denyPermissions(BackgroundHostApiImpl.POST_NOTIFICATIONS)
            notAllowed()
            rationale(false)
            assertTrue(impl.notificationAccess().canAsk)
        }

    @Test
    @Config(sdk = [33, 34, 35])
    fun `with the permission held but notifications off, Android will not ask`() {
        shadowOf(activity.application).grantPermissions(BackgroundHostApiImpl.POST_NOTIFICATIONS)
        notAllowed()
        assertEquals(NotificationAccessMsg(false, false, sdk.toLong()), impl.notificationAccess())
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun `a second request is busy, and a gone host fails the waiting one`() =
        timed {
            notAllowed()
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestNotificationAccess() }
            try {
                impl.requestNotificationAccess()
                fail("expected busy")
            } catch (e: FlutterError) {
                assertEquals("busy", e.code)
            }
            impl.onHostGone()
            try {
                first.await()
                fail("expected host-gone")
            } catch (e: FlutterError) {
                assertEquals("host-gone", e.code)
            }
            try {
                impl.requestNotificationAccess()
                fail("expected no-activity")
            } catch (e: FlutterError) {
                assertEquals("no-activity", e.code)
            }
        }

    @Test
    @Config(sdk = [33, 34, 35])
    fun `a failing request reaches Dart without its message and frees the slot`() =
        timed {
            notAllowed()
            impl = newImpl { _, _, _ -> throw IllegalStateException("content://media/external/video/media/1") }
            repeat(2) {
                try {
                    impl.requestNotificationAccess()
                    fail("expected an error")
                } catch (e: FlutterError) {
                    assertEquals("native-error", e.code)
                    assertEquals("requestNotificationAccess failed: IllegalStateException", e.message)
                    assertFalse(e.toString().contains("content://"))
                }
            }
        }

    // ---- Settings and the phone ----

    private fun resolvable(intent: Intent) {
        val info = ResolveInfo().apply { activityInfo = ActivityInfo().apply { packageName = "com.android.settings"; name = "S" } }
        shadowOf(activity.packageManager).addResolveInfoForIntent(intent, info)
    }

    private val appDetails get() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null))

    @Test
    fun `battery settings opens the battery page`() {
        assertTrue(impl.openBatterySettings())
        assertEquals(Intent.ACTION_POWER_USAGE_SUMMARY, shadowOf(activity).nextStartedActivity.action)
    }

    @Test
    fun `battery settings falls back to app details`() {
        // Only the app details page exists on this phone.
        shadowOf(activity.application).checkActivities(true)
        resolvable(appDetails)
        assertTrue(impl.openBatterySettings())
        val started = shadowOf(activity).nextStartedActivity
        assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, started.action)
        assertEquals("package:${activity.packageName}", started.dataString)
        assertNull(shadowOf(activity).nextStartedActivity)

        // Neither page: false, nothing started, no exception.
        shadowOf(activity.packageManager).removeResolveInfosForIntent(appDetails, "com.android.settings")
        assertFalse(impl.openBatterySettings())
        assertNull(shadowOf(activity).nextStartedActivity)
    }

    @Test
    fun `notification settings opens this app's page, or its details`() {
        impl.openNotificationSettings()
        val started = shadowOf(activity).nextStartedActivity
        assertEquals(Settings.ACTION_APP_NOTIFICATION_SETTINGS, started.action)
        assertEquals(activity.packageName, started.getStringExtra(Settings.EXTRA_APP_PACKAGE))

        shadowOf(activity.application).checkActivities(true)
        resolvable(appDetails)
        impl.openNotificationSettings()
        assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, shadowOf(activity).nextStartedActivity.action)
    }

    @Test
    fun `phone maker is lower-cased and trimmed`() {
        ShadowBuild.setManufacturer("  Samsung \n")
        assertEquals("samsung", impl.phoneMaker())
        ShadowBuild.setManufacturer("OnePlus")
        assertEquals("oneplus", impl.phoneMaker())
    }

    @Test
    fun `takeLaunchAction hands over the kept action once`() {
        impl.launches.onIntent(LaunchActions.intent(activity, LaunchActionMsg.TO_TAG))
        assertEquals(LaunchActionMsg.TO_TAG, impl.takeLaunchAction())
        assertNull(impl.takeLaunchAction())
    }

    @Test
    fun `without the activity the settings calls fail with no-activity`() {
        impl.onHostGone()
        for (call in listOf({ impl.openBatterySettings() }, { impl.openNotificationSettings() })) {
            try {
                call()
                fail("expected no-activity")
            } catch (e: FlutterError) {
                assertEquals("no-activity", e.code)
            }
        }
        // The rest needs no activity.
        assertEquals(sdk.toLong(), impl.notificationAccess().sdkInt)
    }
}
