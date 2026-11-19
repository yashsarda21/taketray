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
import app.taketray.files.FilesHostApiImpl
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
import org.xmlpull.v1.XmlPullParser

/**
 * The manifest's background parts (D-105), as Android reads the merged
 * manifest: no other app can send TakeTray's receivers anything, the
 * reminder and shade receivers take explicit broadcasts only, and no
 * exact-alarm or foreground-service permission is asked for. The files
 * provider (D-147) is not exported and hands out `cache/shared/` only.
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

    @Test
    fun `copying adds no service, no foreground service and no wake lock`() {
        // Copying runs in the app's own process (D-122): the only services are Phase 6's three JobServices.
        val info = pm.getPackageInfo(app.packageName, PackageManager.GET_SERVICES)
        val services = info.services.orEmpty()
        assertEquals(
            setOf(
                "app.taketray.background.NewClipsJobService",
                "app.taketray.background.NewClipsSettleJobService",
                "app.taketray.background.EveningDeferJobService",
            ),
            services.map { it.name }.toSet(),
        )
        assertEquals(3, services.size)
        for (service in services) {
            assertEquals("${service.name} has a foregroundServiceType", 0, service.foregroundServiceType)
        }
        val requested = pm.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS).requestedPermissions.orEmpty()
        for (permission in requested) {
            assertFalse("$permission is requested", permission.startsWith("android.permission.FOREGROUND_SERVICE"))
        }
        assertFalse("WAKE_LOCK is requested", "android.permission.WAKE_LOCK" in requested)
    }

    @Test
    fun `the files provider is not exported, grants addresses one by one, and is named after the build`() {
        // D-147: the share sheet reads TakeTray's file through this provider only.
        val providers = pm.getPackageInfo(app.packageName, PackageManager.GET_PROVIDERS).providers.orEmpty()
        val files = providers.filter { it.authority.orEmpty().endsWith(".files") }
        assertEquals(1, files.size)
        val provider = files.single()
        assertEquals("androidx.core.content.FileProvider", provider.name)
        assertFalse("the files provider is exported", provider.exported)
        assertTrue("the files provider grants no URI permissions", provider.grantUriPermissions)
        // ${applicationId}.files: the dev and the release build never share an authority.
        assertEquals("${app.packageName}.files", provider.authority)
        assertEquals(FilesHostApiImpl.authorityOf(app), provider.authority)
    }

    @Test
    fun `the files provider covers cache shared and nothing else`() {
        val paths = mutableListOf<Triple<String, String?, String?>>()
        app.resources.getXml(R.xml.file_paths).use { xml ->
            while (xml.next() != XmlPullParser.END_DOCUMENT) {
                if (xml.eventType == XmlPullParser.START_TAG && xml.name != "paths") {
                    paths += Triple(xml.name, xml.getAttributeValue(null, "name"), xml.getAttributeValue(null, "path"))
                }
            }
        }
        assertEquals(listOf(Triple("cache-path", "shared", "shared/")), paths)
    }
}
