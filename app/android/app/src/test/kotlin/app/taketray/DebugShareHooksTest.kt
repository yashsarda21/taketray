package app.taketray

import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import app.taketray.share.ShareActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The debug-only share hook (channel `app.taketray/test_share`, D-169): a
 * Patrol flow starts the share screen with a text, as another app's Share
 * does, without another app. The release dex check forbids this class.
 */
@RunWith(RobolectricTestRunner::class)
class DebugShareHooksTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val handler = DebugShareHandler(app)

    private class Answer : MethodChannel.Result {
        var value: Any? = "unset"
        var errorCode: String? = null
        var errorMessage: String? = null
        var notImplemented = false
        var replies = 0

        override fun success(result: Any?) {
            replies++
            value = result
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

    private fun call(
        method: String,
        argument: Any? = null,
        handler: DebugShareHandler = this.handler,
    ) = Answer().also { handler.onMethodCall(MethodCall(method, argument), it) }

    private fun started(): Intent? = shadowOf(app).nextStartedActivity

    @Test
    fun `the channel is the one Dart uses`() {
        assertEquals("app.taketray/test_share", DebugShareHandler.CHANNEL)
    }

    @Test
    fun `startShare starts ShareActivity with the text as a plain-text send`() {
        val reply = call("startShare", "Look https://www.instagram.com/reel/TTTEST1/?igsh=x")

        assertEquals(1, reply.replies)
        assertNull(reply.value)
        val intent = started()!!
        assertEquals(Intent.ACTION_SEND, intent.action)
        assertEquals("text/plain", intent.type)
        assertEquals("Look https://www.instagram.com/reel/TTTEST1/?igsh=x", intent.getStringExtra(Intent.EXTRA_TEXT))
        assertEquals(ShareActivity::class.java.name, intent.component?.className)
        assertEquals(app.packageName, intent.component?.packageName)
        assertNull("one start only", started())
    }

    @Test
    fun `it is started as a new task, which a non-activity context needs`() {
        call("startShare", "x")
        val flags = started()!!.flags
        assertTrue(flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        // Nothing a real share does not have: no clear-top, no single-top.
        assertEquals(0, flags and Intent.FLAG_ACTIVITY_CLEAR_TOP)
        assertEquals(0, flags and Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    @Test
    fun `an empty text and a caption with no link are shared as they are`() {
        call("startShare", "")
        assertEquals("", started()!!.getStringExtra(Intent.EXTRA_TEXT))
        call("startShare", "just a caption, no link")
        assertEquals("just a caption, no link", started()!!.getStringExtra(Intent.EXTRA_TEXT))
    }

    @Test
    fun `a long text is not cut by the hook`() {
        val long = "a".repeat(30_000)
        call("startShare", long)
        assertEquals(30_000, started()!!.getStringExtra(Intent.EXTRA_TEXT)!!.length)
    }

    @Test
    fun `two shares in a row are two starts, each with its own text`() {
        call("startShare", "first")
        call("startShare", "second")
        // Robolectric hands its started intents back newest first.
        val texts = listOf(started()!!, started()!!).map { it.getStringExtra(Intent.EXTRA_TEXT) }
        assertEquals(setOf("first", "second"), texts.toSet())
        assertEquals(2, texts.size)
        assertNull(started())
    }

    @Test
    fun `a text that is not a string is a bad argument and starts nothing`() {
        for (bad in listOf<Any?>(null, 5, true, listOf("a"), mapOf("text" to "a"))) {
            val reply = call("startShare", bad)
            assertEquals("for $bad", "bad-args", reply.errorCode)
            assertEquals(1, reply.replies)
        }
        assertNull(started())
    }

    @Test
    fun `an unknown method is not implemented and starts nothing`() {
        assertTrue(call("noSuchHook").notImplemented)
        assertNull(started())
    }

    @Test
    fun `a start that fails is native-error with the class name only`() {
        val failing =
            object : ContextWrapper(app) {
                override fun getApplicationContext(): Context = this

                override fun startActivity(intent: Intent) = throw ActivityNotFoundException("secret https://example.com/caption")
            }

        val reply = call("startShare", "https://example.com/secret-caption", DebugShareHandler(failing))

        assertEquals("native-error", reply.errorCode)
        assertEquals("startShare failed: ActivityNotFoundException", reply.errorMessage)
        assertFalse("no text in the message", reply.errorMessage!!.contains("example.com"))
        assertEquals(1, reply.replies)
    }

    @Test
    fun `the registered handler starts from the application context`() {
        // MainActivity hands every hook itself; an activity must not be kept
        // by a handler that outlives it.
        var startedFrom: Context? = null
        val activityLike =
            object : ContextWrapper(app) {
                override fun getApplicationContext(): Context =
                    object : ContextWrapper(app) {
                        override fun getApplicationContext(): Context = this

                        override fun startActivity(intent: Intent) {
                            startedFrom = this
                            super.startActivity(intent)
                        }
                    }

                override fun startActivity(intent: Intent): Unit = throw IllegalStateException("the activity's own context was used")
            }

        val reply = call("startShare", "x", DebugShareHooks.handlerFor(activityLike))

        assertNull(reply.errorCode)
        assertNotNull("started from the application context", startedFrom)
    }
}
