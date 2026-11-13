package app.taketray.editors

import android.app.Application
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/** Which editors are installed, with their icons, from the package manager (D-121). */
@RunWith(RobolectricTestRunner::class)
class EditorAppsTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val pm = app.packageManager
    private val capcut = "com.lemon.lvoverseas"
    private val edits = "com.instagram.basel"
    private val vn = "com.frontrow.vlog"

    private val real = PackageManagerSource(pm)
    private val apps = EditorApps(real)

    @Before
    fun setUp() {
        EditorApps.installedOverride = null
    }

    @After
    fun tearDown() {
        EditorApps.installedOverride = null
    }

    private fun install(
        name: String,
        enabled: Boolean = true,
        icon: Drawable? = ColorDrawable(Color.RED),
    ) {
        val info =
            PackageInfo().apply {
                packageName = name
                applicationInfo =
                    ApplicationInfo().apply {
                        packageName = name
                        this.enabled = enabled
                    }
            }
        shadowOf(pm).installPackage(info)
        if (icon != null) shadowOf(pm).setApplicationIcon(name, icon)
    }

    private fun size(png: ByteArray?): Pair<Int, Int> {
        assertNotNull(png)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(png, 0, png!!.size, bounds)
        return bounds.outWidth to bounds.outHeight
    }

    @Test
    fun `each package in order, installed or not`() {
        install(capcut)
        install(vn)

        val result = apps.apps(listOf(capcut, edits, vn), 48)

        assertEquals(listOf(capcut, edits, vn), result.map { it.packageName })
        assertEquals(listOf(true, false, true), result.map { it.installed })
        assertNull(result[1].iconPng)
    }

    @Test
    fun `an unknown or odd package never throws`() {
        val result = apps.apps(listOf("no.such.app", "", "   ", "a/b"), 48)
        assertEquals(listOf(false, false, false, false), result.map { it.installed })
        assertEquals(emptyList<InstalledAppMsg>(), apps.apps(emptyList(), 48))
    }

    @Test
    fun `the icon is drawn to a PNG of iconPx`() {
        install(capcut)

        val png = apps.apps(listOf(capcut), 96).single().iconPng

        assertEquals(96 to 96, size(png))
        assertArrayEquals("a PNG", byteArrayOf(0x89.toByte(), 'P'.code.toByte(), 'N'.code.toByte(), 'G'.code.toByte()), png!!.copyOf(4))
        assertEquals(1 to 1, size(apps.apps(listOf(capcut), 1).single().iconPng))
        assertEquals(512 to 512, size(apps.apps(listOf(capcut), 512).single().iconPng))
    }

    @Test
    fun `an icon size outside 1 to 512 is refused`() {
        install(capcut)
        for (px in listOf(0, -1, 513, Int.MAX_VALUE)) {
            assertThrows("$px", IllegalArgumentException::class.java) { apps.apps(listOf(capcut), px) }
        }
    }

    @Test
    fun `a package that disappears mid-call is not installed`() {
        install(capcut)
        install(edits)
        val vanishing =
            object : PackageSource by real {
                override fun icon(packageName: String): Drawable {
                    if (packageName == capcut) {
                        // Uninstalled between the two reads; Robolectric's shadow
                        // would still hand out the icon, the real one throws.
                        shadowOf(pm).removePackage(capcut)
                        throw PackageManager.NameNotFoundException(packageName)
                    }
                    return real.icon(packageName)
                }
            }

        val result = EditorApps(vanishing).apps(listOf(capcut, edits), 48)

        assertFalse(result[0].installed)
        assertNull(result[0].iconPng)
        assertTrue("the rest go on", result[1].installed)
    }

    @Test
    fun `a disabled app is not installed`() {
        install(capcut, enabled = false)
        assertFalse(apps.apps(listOf(capcut), 48).single().installed)
    }

    @Test
    fun `an icon that cannot be drawn leaves the app installed with no icon`() {
        install(capcut)
        val broken =
            object : PackageSource by real {
                override fun icon(packageName: String): Drawable = throw IllegalStateException("bad drawable")
            }
        val result = EditorApps(broken).apps(listOf(capcut), 48).single()
        assertTrue(result.installed)
        assertNull(result.iconPng)
    }

    @Test
    fun `a package manager failure that is not NameNotFound fails the call`() {
        val dead =
            object : PackageSource by real {
                override fun applicationInfo(packageName: String): ApplicationInfo = throw RuntimeException("system died")
            }
        assertThrows(RuntimeException::class.java) { EditorApps(dead).apps(listOf(capcut), 48) }
    }

    @Test
    fun `the debug override decides for the packages it names`() {
        install(capcut)
        install(edits)
        EditorApps.installedOverride = mapOf(capcut to false, vn to true)

        val result = apps.apps(listOf(capcut, edits, vn), 48)

        assertEquals(listOf(false, true, true), result.map { it.installed })
        assertNull("an app overridden away has no icon", result[0].iconPng)
        assertNotNull(result[1].iconPng)
        assertNull("not really there: no icon", result[2].iconPng)

        EditorApps.installedOverride = null
        assertEquals(listOf(true, true, false), apps.apps(listOf(capcut, edits, vn), 48).map { it.installed })
    }

    @Test
    fun `launchIntent is the package's own, null when overridden away or missing`() {
        val launch = Intent(Intent.ACTION_MAIN).setPackage(capcut)
        val source =
            object : PackageSource by real {
                override fun launchIntent(packageName: String): Intent? = if (packageName == capcut) launch else null
            }
        val editors = EditorApps(source)

        assertTrue(editors.launchIntent(capcut) === launch)
        assertNull(editors.launchIntent(vn))
        EditorApps.installedOverride = mapOf(capcut to false)
        assertNull(editors.launchIntent(capcut))
    }

    @Test
    fun `the real source reads the package manager`() {
        install(capcut)
        assertEquals(capcut, real.applicationInfo(capcut).packageName)
        assertThrows(PackageManager.NameNotFoundException::class.java) { real.applicationInfo(vn) }
        assertThrows(PackageManager.NameNotFoundException::class.java) { real.icon(vn) }
        assertNull(real.launchIntent(vn))
    }
}
