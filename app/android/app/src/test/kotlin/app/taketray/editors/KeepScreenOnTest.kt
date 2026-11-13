package app.taketray.editors

import android.app.Activity
import android.os.Looper
import android.view.WindowManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The copy screen keeps the screen on through the activity window's
 * FLAG_KEEP_SCREEN_ON (D-122, R4): no permission, no wake lock.
 */
@RunWith(RobolectricTestRunner::class)
class KeepScreenOnTest {
    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

    private fun flagSet(a: Activity = activity) = a.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0

    @Test
    fun `on sets the window flag and off clears it`() {
        val keep = KeepScreenOn(activity)
        assertFalse(flagSet())
        assertFalse(keep.isOn())
        keep.set(true)
        assertTrue(flagSet())
        assertTrue(keep.isOn())
        keep.set(true)
        assertTrue(flagSet())
        keep.set(false)
        assertFalse(flagSet())
        assertFalse(keep.isOn())
        keep.set(false)
        assertFalse(flagSet())
    }

    @Test
    fun `a call from another thread changes the window on the main thread`() {
        val keep = KeepScreenOn(activity)
        val worker = Thread { keep.set(true) }
        worker.start()
        worker.join()
        // Not applied on the calling thread...
        assertFalse(flagSet())
        // ...but once the main thread runs.
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(flagSet())

        val off = Thread { keep.set(false) }
        off.start()
        off.join()
        assertTrue(flagSet())
        shadowOf(Looper.getMainLooper()).idle()
        assertFalse(flagSet())
    }

    @Test
    fun `with no activity it does nothing and does not throw`() {
        val none = KeepScreenOn(null)
        none.set(true)
        none.set(false)
        assertFalse(none.isOn())

        val keep = KeepScreenOn(activity)
        keep.set(true)
        keep.detach()
        // The window it no longer holds is left alone, and nothing throws.
        keep.set(false)
        assertTrue(flagSet())
        assertFalse(keep.isOn())
        assertEquals(Unit, keep.detach())
    }
}
