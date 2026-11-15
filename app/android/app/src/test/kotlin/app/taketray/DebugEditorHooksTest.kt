package app.taketray

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.os.Looper
import android.provider.MediaStore
import app.taketray.editors.ActivityStarter
import app.taketray.editors.EditorApps
import app.taketray.editors.EditorsHostApiImpl
import app.taketray.editors.SendResultMsg
import app.taketray.editors.ShareClipMsg
import app.taketray.editors.ShareIntents
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The debug-only editor hooks (D-121): the on-device tests can pretend an
 * editor is or is not installed, and record the outgoing intent instead of
 * opening CapCut, Edits, VN, the Play Store or the share sheet.
 */
@RunWith(RobolectricTestRunner::class)
class DebugEditorHooksTest {
    private lateinit var activity: Activity
    private lateinit var handler: DebugEditorHandler
    private val capcut = "com.lemon.lvoverseas"
    private val pickerUri = "content://media/picker/0/com.android.providers.media.photopicker/media/1000000042"

    private class Reply : MethodChannel.Result {
        var success: Any? = null
        var errorCode: String? = null
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
        }

        override fun notImplemented() {
            replies++
            notImplemented = true
        }
    }

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        ActivityStarter.replacement = null
        EditorApps.installedOverride = null
        handler = DebugEditorHandler()
    }

    @After
    fun tearDown() {
        ActivityStarter.replacement = null
        EditorApps.installedOverride = null
    }

    private fun call(
        method: String,
        args: Any? = null,
    ): Reply {
        val reply = Reply()
        handler.onMethodCall(MethodCall(method, args), reply)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, reply.replies)
        return reply
    }

    @Suppress("UNCHECKED_CAST")
    private fun recorded(): List<Map<String, Any?>> = call("takeRecordedIntents").success as List<Map<String, Any?>>

    /** Runs [block] with a time limit, so a hang fails the test instead of stalling it. */
    private fun <T> timed(block: suspend () -> T): T = runBlocking { withTimeout(5_000) { block() } }

    private fun media(id: Long) = ShareClipMsg(MediaStore.VOLUME_EXTERNAL_PRIMARY, id, null)

    private val bridge get() = EditorsHostApiImpl(activity)

    @Test
    fun `the channel is the one Dart uses`() {
        assertEquals("app.taketray/test_editors", DebugEditorHandler.CHANNEL)
    }

    @Test
    fun `an unknown method is not implemented`() {
        assertTrue(call("noSuchHook").notImplemented)
    }

    @Test
    fun `setInstalledOverride sets and clears the override`() {
        call("setInstalledOverride", mapOf(capcut to true, "com.frontrow.vlog" to false))
        assertEquals(mapOf(capcut to true, "com.frontrow.vlog" to false), EditorApps.installedOverride)
        assertEquals(listOf(true), timed { bridge.apps(listOf(capcut), 48) }.map { it.installed })

        call("setInstalledOverride", null)
        assertNull(EditorApps.installedOverride)
        assertEquals(listOf(false), timed { bridge.apps(listOf(capcut), 48) }.map { it.installed })
    }

    @Test
    fun `while recording nothing starts and each intent is described`() {
        call("recordIntents", true)

        val result = timed { bridge.sendTo(capcut, listOf(media(30), ShareClipMsg(null, null, pickerUri), media(4))) }

        assertEquals(SendResultMsg.SENT, result)
        assertNull("no activity started", shadowOf(activity).nextStartedActivity)
        val one = recorded().single()
        assertEquals(Intent.ACTION_SEND_MULTIPLE, one["action"])
        assertEquals(capcut, one["package"])
        assertEquals("video/*", one["type"])
        assertEquals(listOf("external_primary:30", "picker", "external_primary:4"), one["uris"])
        assertEquals(true, one["grantRead"])
        assertEquals(3, one["clipDataCount"])
        assertTrue("taken once", recorded().isEmpty())
    }

    @Test
    fun `a single send, the chooser and the store are recorded too`() {
        call("recordIntents", true)
        timed {
            bridge.sendTo(capcut, listOf(media(7)))
            bridge.shareWithChooser(listOf(media(7), media(8)), "Share")
            bridge.openStoreListing(capcut)
        }

        val (single, chooser, store) = recorded()
        assertEquals(Intent.ACTION_SEND, single["action"])
        assertEquals(listOf("external_primary:7"), single["uris"])
        assertEquals(1, single["clipDataCount"])

        assertEquals(Intent.ACTION_CHOOSER, chooser["action"])
        assertNull(chooser["package"])
        assertEquals(Intent.ACTION_SEND_MULTIPLE, chooser["targetAction"])
        assertEquals("video/*", chooser["type"])
        assertEquals(listOf("external_primary:7", "external_primary:8"), chooser["uris"])
        assertEquals(true, chooser["grantRead"])
        assertEquals(2, chooser["clipDataCount"])

        assertEquals(Intent.ACTION_VIEW, store["action"])
        assertEquals("market://details?id=com.lemon.lvoverseas", store["data"])
        assertEquals(emptyList<String>(), store["uris"])
        assertEquals(false, store["grantRead"])
        assertEquals(0, store["clipDataCount"])
    }

    @Test
    fun `an editor overridden away is notInstalled while recording`() {
        call("recordIntents", true)
        call("setInstalledOverride", mapOf(capcut to false))

        assertEquals(SendResultMsg.NOT_INSTALLED, timed { bridge.sendTo(capcut, listOf(media(1))) })
        assertTrue(recorded().isEmpty())
    }

    @Test
    fun `recording off starts for real again and forgets what was recorded`() {
        call("recordIntents", true)
        timed { bridge.sendTo(capcut, listOf(media(1))) }
        call("recordIntents", false)
        assertNull(ActivityStarter.replacement)

        timed { bridge.sendTo(capcut, listOf(media(2))) }

        assertEquals(capcut, shadowOf(activity).nextStartedActivity?.`package`)
        assertTrue(recorded().isEmpty())
    }

    @Test
    fun `a URI that is not a MediaStore video is picker`() {
        val recorder = IntentRecorder()
        recorder.start(ShareIntents.sendIntent(capcut, listOf(ContentUris.withAppendedId(MediaStore.Images.Media.getContentUri("external"), 3))))
        assertEquals(listOf("picker"), recorder.take().single()["uris"])
    }

    @Test
    fun `bad arguments are an error, not a crash`() {
        assertEquals("bad-args", call("recordIntents", "yes").errorCode)
        assertEquals("bad-args", call("setInstalledOverride", listOf(1)).errorCode)
    }
}
