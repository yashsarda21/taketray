package app.taketray

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import app.taketray.background.BootReceiver
import app.taketray.background.ReminderReceiver
import app.taketray.background.ReminderScheduler
import app.taketray.background.ShadeActionReceiver
import app.taketray.media.TimeZoneChangedReceiver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The manifest's background parts (D-105), as Android reads the merged
 * manifest: no other app can send TakeTray's receivers anything, the
 * reminder and shade receivers take explicit broadcasts only, and no
 * exact-alarm or foreground-service permission is asked for.
 */
@RunWith(RobolectricTestRunner::class)
class ManifestTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val pm = app.packageManager

    private fun receivers(action: String): List<String> =
        pm.queryBroadcastReceivers(Intent(action).setPackage(app.packageName), 0).map { it.activityInfo.name }

    @Test
    fun `receivers are not exported`() {
        for (receiver in listOf(BootReceiver::class.java, ReminderReceiver::class.java, ShadeActionReceiver::class.java, TimeZoneChangedReceiver::class.java)) {
            val info = pm.getReceiverInfo(ComponentName(app, receiver), 0)
            assertFalse("${receiver.simpleName} is exported", info.exported)
        }
        // The system broadcasts reach the re-arming receivers through their filters.
        for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED)) {
            assertEquals(action, listOf(BootReceiver::class.java.name), receivers(action))
        }
        assertEquals(listOf(TimeZoneChangedReceiver::class.java.name), receivers(Intent.ACTION_TIMEZONE_CHANGED))
        // The reminder and shade receivers have no filter: their actions match nothing implicitly.
        for (action in listOf(
            ReminderScheduler.ACTION_EVENING,
            ReminderScheduler.ACTION_STILL,
            ShadeActionReceiver.ACTION_TURN_OFF,
            ShadeActionReceiver.ACTION_KEEP_ON,
        )) {
            assertEquals(action, emptyList<String>(), receivers(action))
        }
    }

    @Test
    fun `no exact alarm permission`() {
        val requested = pm.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS).requestedPermissions.orEmpty().toSet()
        for (forbidden in listOf(
            "android.permission.SCHEDULE_EXACT_ALARM",
            "android.permission.USE_EXACT_ALARM",
            "android.permission.FOREGROUND_SERVICE",
        )) {
            assertFalse("$forbidden is requested", forbidden in requested)
        }
        // The two permissions Phase 6 adds (D-101).
        assertTrue("android.permission.RECEIVE_BOOT_COMPLETED" in requested)
        assertTrue("android.permission.POST_NOTIFICATIONS" in requested)
    }
}
