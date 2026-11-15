package app.taketray

import android.app.Activity
import android.view.WindowManager
import app.taketray.editors.CopyEngine
import app.taketray.editors.FakeCopyStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * The debug-only copy hooks (channel `app.taketray/test_copy`, D-122): the
 * Patrol flows slow the copy down to cancel it mid-file, and read the real
 * window flag. The release dex check forbids this class.
 */
@RunWith(RobolectricTestRunner::class)
class DebugCopyHooksTest {
    private val engine = CopyEngine(FakeCopyStore())
    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    private val handler = DebugCopyHandler(engine) { DebugCopyHooks.flagOf(activity) }

    private class Answer : MethodChannel.Result {
        var value: Any? = "unset"
        var error: String? = null
        var notImplemented = false

        override fun success(result: Any?) {
            value = result
        }

        override fun error(
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?,
        ) {
            error = errorCode
        }

        override fun notImplemented() {
            notImplemented = true
        }
    }

    private fun call(
        method: String,
        argument: Any? = null,
    ) = Answer().also { handler.onMethodCall(MethodCall(method, argument), it) }

    @Test
    fun `the channel name`() = assertEquals("app.taketray/test_copy", DebugCopyHandler.CHANNEL)

    @Test
    fun `setCopyThrottleMs sets the engine's throttle, and only a whole number from 0 is taken`() {
        assertEquals(0L, engine.throttleMs)
        val ok = call("setCopyThrottleMs", 40)
        assertNull(ok.value)
        assertNull(ok.error)
        assertEquals(40L, engine.throttleMs)
        assertEquals("bad-argument", call("setCopyThrottleMs", -1).error)
        assertEquals("bad-argument", call("setCopyThrottleMs", "40").error)
        assertEquals("bad-argument", call("setCopyThrottleMs", null).error)
        assertEquals(40L, engine.throttleMs)
        call("setCopyThrottleMs", 0)
        assertEquals(0L, engine.throttleMs)
    }

    @Test
    fun `keepScreenOnFlag reads the activity's window flag`() {
        assertEquals(false, call("keepScreenOnFlag").value)
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        assertEquals(true, call("keepScreenOnFlag").value)
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        assertEquals(false, call("keepScreenOnFlag").value)
        // With no activity the flag is off.
        assertEquals(false, DebugCopyHooks.flagOf(null))
    }

    @Test
    fun `an unknown method is not implemented`() {
        assertEquals(true, call("deleteEverything").notImplemented)
    }
}
