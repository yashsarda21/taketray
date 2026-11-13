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
import java.io.File
import java.util.Properties
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.w3c.dom.Element

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

    /**
     * The merged manifest as AGP hands it to Robolectric (`test_config.properties`),
     * read as XML: Android has no API that lists an app's own `<queries>`.
     */
    private fun queriedPackages(): List<String> {
        val props = Properties()
        javaClass.classLoader!!.getResourceAsStream("com/android/tools/test_config.properties")!!.use { props.load(it) }
        val manifest = File(props.getProperty("android_merged_manifest"))
        assertTrue("merged manifest at $manifest", manifest.isFile)
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val doc = factory.newDocumentBuilder().parse(manifest)
        val queries = doc.getElementsByTagName("queries")
        return buildList {
            for (q in 0 until queries.length) {
                val packages = (queries.item(q) as Element).getElementsByTagName("package")
                for (i in 0 until packages.length) {
                    add((packages.item(i) as Element).getAttributeNS("http://schemas.android.com/apk/res/android", "name"))
                }
            }
        }
    }

    @Test
    fun `the three editors are queried by package, and nothing else is`() {
        // The package names live in Dart (EditorApp.packageName, D-119); a Dart
        // test checks exactly these three against the source manifest. The
        // unit-test manifest also merges androidx.test's own queries (test
        // builds only), so only those may stand beside the three.
        val editors = listOf("com.frontrow.vlog", "com.instagram.basel", "com.lemon.lvoverseas")
        val queried = queriedPackages()
        assertEquals(editors, queried.filter { it in editors }.sorted())
        val testTooling = listOf("androidx.test.", "com.google.android.apps.common.testing.")
        val others = queried.filter { it !in editors }
        assertTrue("unexpected package queries: $others", others.all { p -> testTooling.any { p.startsWith(it) } })
    }
}
