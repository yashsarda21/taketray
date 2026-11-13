package app.taketray.editors

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.os.Environment
import android.os.Looper
import android.provider.MediaStore
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowStatFs

/**
 * The bridge's wiring (D-121): every package-manager, MediaStore and storage
 * read runs off the main thread, every activity start on the caller's (the
 * main) thread, and an unexpected exception reaches Dart as `native-error`
 * with the method and the exception's class only (D-10).
 */
@RunWith(RobolectricTestRunner::class)
class EditorsHostApiImplTest {
    private lateinit var activity: Activity
    private val capcut = "com.lemon.lvoverseas"

    /** Thread of each package read: true when it ran on the main thread. */
    private val sourceThreads = mutableListOf<Boolean>()
    private var launch: Intent? = Intent(Intent.ACTION_MAIN).setPackage("com.lemon.lvoverseas")

    private val source =
        object : PackageSource {
            override fun applicationInfo(packageName: String): ApplicationInfo {
                sourceThreads += onMain()
                if (packageName == "boom") throw IllegalStateException("/storage/emulated/0/secret")
                return ApplicationInfo().apply {
                    this.packageName = packageName
                    enabled = true
                }
            }

            override fun icon(packageName: String): Drawable {
                sourceThreads += onMain()
                return ColorDrawable(Color.BLUE)
            }

            override fun launchIntent(packageName: String): Intent? {
                sourceThreads += onMain()
                return launch
            }
        }

    /** Each start: the intent and whether it ran on the main thread. */
    private val starts = mutableListOf<Pair<Intent, Boolean>>()
    private var startFailure: RuntimeException? = null
    private val starter =
        ActivityStarter { intent ->
            startFailure?.let { throw it }
            starts += intent to onMain()
        }

    private fun onMain() = Looper.getMainLooper().isCurrentThread

    private var freeThread: Boolean? = null

    private fun impl(
        free: () -> Long = {
            freeThread = onMain()
            123L
        },
        start: ActivityStarter? = starter,
    ) = EditorsHostApiImpl(activity, apps = EditorApps(source), freeBytesOf = free, starter = start)

    private fun media(id: Long) = ShareClipMsg(MediaStore.VOLUME_EXTERNAL_PRIMARY, id, null)

    private fun ref(id: Long) = CopyFileRefMsg(id, "Goa", "a.mp4")

    private fun <T> call(block: suspend () -> T): T = runBlocking { withTimeout(5_000) { block() } }

    private fun error(block: suspend () -> Unit): EditorsError? =
        try {
            call(block)
            null
        } catch (e: EditorsError) {
            e
        }

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        CopyFolderProvider.install()
        ActivityStarter.replacement = null
        EditorApps.installedOverride = null
    }

    @After
    fun tearDown() {
        ActivityStarter.replacement = null
        EditorApps.installedOverride = null
        ShadowStatFs.reset()
    }

    // ------------------------------------------------------------ editors

    @Test
    fun `apps reads the package manager off the main thread`() {
        val result = call { impl().apps(listOf(capcut, "com.instagram.basel"), 48) }

        assertEquals(listOf(true, true), result.map { it.installed })
        assertTrue(sourceThreads.isNotEmpty())
        assertTrue("never on the main thread", sourceThreads.none { it })
    }

    @Test
    fun `apps with a bad icon size or a failing read is a Pigeon error naming only the class`() {
        val badSize = error { impl().apps(listOf(capcut), 0) }
        assertEquals("native-error", badSize?.code)
        assertEquals("apps failed: IllegalArgumentException", badSize?.message)
        assertEquals("native-error", error { impl().apps(listOf(capcut), Long.MAX_VALUE) }?.code)

        val failed = error { impl().apps(listOf("boom"), 48) }
        assertEquals("native-error", failed?.code)
        assertEquals("apps failed: IllegalStateException", failed?.message)
        assertFalse("no path in the message", failed.toString().contains("/storage"))
        assertNull(failed?.details)
    }

    @Test
    fun `sendTo starts the share on the main thread`() {
        val result = call { impl().sendTo(capcut, listOf(media(2), media(1))) }

        assertEquals(SendResultMsg.SENT, result)
        val (intent, onMain) = starts.single()
        assertTrue(onMain)
        assertEquals(Intent.ACTION_SEND_MULTIPLE, intent.action)
        assertEquals(capcut, intent.`package`)
    }

    @Test
    fun `sendTo reports notInstalled and failed`() {
        startFailure = ActivityNotFoundException()
        assertEquals(SendResultMsg.NOT_INSTALLED, call { impl().sendTo(capcut, listOf(media(1))) })
        startFailure = SecurityException()
        assertEquals(SendResultMsg.FAILED, call { impl().sendTo(capcut, listOf(media(1))) })
    }

    @Test
    fun `the debug replacement starter wins over the activity's`() {
        val replaced = mutableListOf<Intent>()
        ActivityStarter.replacement = ActivityStarter { replaced += it }

        call { impl().sendTo(capcut, listOf(media(1))) }
        call { impl().openStoreListing(capcut) }

        assertEquals(2, replaced.size)
        assertTrue(starts.isEmpty())
    }

    @Test
    fun `with no starter given the activity starts the share`() {
        call { impl(start = null).sendTo(capcut, listOf(media(1))) }
        val started = shadowOf(activity).nextStartedActivity
        assertEquals(Intent.ACTION_SEND, started.action)
        assertEquals(capcut, started.`package`)
    }

    @Test
    fun `shareWithChooser starts the chooser on the main thread`() {
        assertTrue(call { impl().shareWithChooser(listOf(media(1)), "Share") })
        assertEquals(Intent.ACTION_CHOOSER, starts.single().first.action)
        assertTrue(starts.single().second)
        startFailure = ActivityNotFoundException()
        assertFalse(call { impl().shareWithChooser(listOf(media(1)), "Share") })
    }

    @Test
    fun `openApp reads the launch intent off the main thread and starts it on it`() {
        assertTrue(call { impl().openApp(capcut) })
        assertTrue(sourceThreads.single().not())
        assertTrue(starts.single().first === launch)
        assertTrue(starts.single().second)

        launch = null
        assertFalse(call { impl().openApp(capcut) })
        assertEquals(1, starts.size)
    }

    @Test
    fun `openStoreListing opens market details`() {
        assertTrue(call { impl().openStoreListing(capcut) })
        assertEquals("market://details?id=com.lemon.lvoverseas", starts.single().first.dataString)
        startFailure = ActivityNotFoundException()
        assertFalse(call { impl().openStoreListing(capcut) })
    }

    @Test
    fun `without the activity nothing starts`() {
        val bridge = impl()
        bridge.onHostGone()
        assertEquals("no-activity", error { bridge.sendTo(capcut, listOf(media(1))) }?.code)
        assertEquals("no-activity", error { bridge.shareWithChooser(listOf(media(1)), "Share") }?.code)
        assertEquals("no-activity", error { bridge.openApp(capcut) }?.code)
        assertEquals("no-activity", error { bridge.openStoreListing(capcut) }?.code)
        assertTrue(starts.isEmpty())
    }

    // ------------------------------------------------------------ storage

    @Test
    fun `freeBytes runs off the main thread`() {
        assertEquals(123L, call { impl().freeBytes() })
        assertEquals(false, freeThread)
        val failed = error { impl(free = { throw IllegalStateException("/storage/x") }).freeBytes() }
        assertEquals("freeBytes failed: IllegalStateException", failed?.message)
    }

    @Test
    fun `freeBytes is StatFs's available bytes of the primary external storage`() {
        ShadowStatFs.registerStats(Environment.getExternalStorageDirectory(), 1000, 700, 600)
        assertEquals(600L * ShadowStatFs.BLOCK_SIZE, primaryFreeBytes())
        assertEquals(600L * ShadowStatFs.BLOCK_SIZE, call { EditorsHostApiImpl(activity).freeBytes() })
    }

    @Test
    fun `the copy folder calls run off the main thread`() {
        val ours = activity.packageName
        CopyFolderProvider.add(1, "Movies/TakeTray/Goa/", "a.mp4", ours)
        CopyFolderProvider.add(2, "Movies/TakeTray/Goa/", "a.mp4", ours)
        CopyFolderProvider.add(3, "Movies/TakeTray Test/", "a.mp4", ours)
        val bridge = impl()

        assertEquals(listOf("Goa"), call { bridge.copyFolderNames() })
        assertEquals(setOf(1L, 2L), call { bridge.existingCopies(listOf(ref(1), ref(2), ref(3))) }.toSet())
        assertEquals(2, call { bridge.filesInCopyFolders() }.size)
        val report = call { bridge.deleteCopies(listOf(ref(1), ref(3), ref(9))) }
        assertEquals(listOf(1L), report.deleted)
        assertEquals(listOf(3L), report.refused)
        assertEquals(listOf(9L), report.gone)

        assertTrue(CopyFolderProvider.queries.size >= 4)
        assertTrue("queries off the main thread", CopyFolderProvider.queries.none { it.onMain })
        assertTrue("deletes off the main thread", CopyFolderProvider.deletes.none { it.onMain })
    }

    @Test
    fun `a copy folder failure is a Pigeon error naming only the class`() {
        CopyFolderProvider.queryFailure = IllegalStateException("/storage/emulated/0/Movies/TakeTray/Goa")
        for ((method, block) in listOf<Pair<String, suspend () -> Unit>>(
            "copyFolderNames" to { impl().copyFolderNames() },
            "existingCopies" to { impl().existingCopies(listOf(ref(1))) },
            "deleteCopies" to { impl().deleteCopies(listOf(ref(1))) },
            "filesInCopyFolders" to { impl().filesInCopyFolders() },
            "requestDelete" to { impl().requestDelete(listOf(ref(1))) },
        )) {
            val e = error(block)
            assertEquals(method, "native-error", e?.code)
            assertEquals("$method failed: IllegalStateException", e?.message)
            assertFalse(e.toString().contains("Goa"))
        }
    }

    @Test
    fun `a null cursor is an error, never an empty answer`() {
        CopyFolderProvider.noCursor = true
        assertEquals("existingCopies failed: IOException", error { impl().existingCopies(listOf(ref(1))) }?.message)
    }
}
