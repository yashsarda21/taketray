package app.taketray.share

import android.app.Activity
import android.app.Application
import android.content.res.Resources
import android.util.TypedValue
import android.view.Window
import android.view.WindowManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The share screen's window blur (D-177, amends D-167): on Android 12+ the
 * window asks Android to blur the app behind it by the design's 3 dp, and
 * turns the request off again when cross-window blur goes off (battery saver).
 * The Flutter 50 % dim stays the only dim, and is all there is on Android 11.
 *
 * What a JVM test cannot show: that the compositor really blurs (the owner
 * checks the radius by eye, hand checks 14.8) and that the activity registers
 * and removes the system's listener in `onAttachedToWindow` and
 * `onDetachedFromWindow` (a FlutterActivity cannot be created without the
 * native engine library, and Robolectric's WindowManager has no
 * cross-window-blur state to flip).
 */
@RunWith(RobolectricTestRunner::class)
class ShareWindowBlurTest {
    private fun window(): Window = Robolectric.buildActivity(Activity::class.java).setup().get().window

    private fun Window.blurRequested(): Boolean = (attributes.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND) != 0

    @Test
    fun radiusForSigmaUsesAndroidsRule() {
        assertEquals(4, ShareWindowBlur.radiusForSigma(3f))
        assertEquals(10, ShareWindowBlur.radiusForSigma(3f * 2f))
        assertEquals(14, ShareWindowBlur.radiusForSigma(3f * 2.8125f))
        assertEquals(15, ShareWindowBlur.radiusForSigma(3f * 3f))
        assertEquals(0, ShareWindowBlur.radiusForSigma(0.5f))
        assertEquals(0, ShareWindowBlur.radiusForSigma(0f))
        assertEquals(0, ShareWindowBlur.radiusForSigma(-2f))
    }

    @Test
    fun theSigmaIsTheDesignsThreeDp() {
        assertEquals(3f, ShareWindowBlur.SIGMA_DP, 0f)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun theRadiusFollowsTheScreenDensity() {
        assertEquals(14, ShareWindowBlur(window(), 2.8125f).radiusPx)
        assertEquals(4, ShareWindowBlur(window(), 1f).radiusPx)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun blurOnSetsTheFlagAndRadius() {
        val window = window()
        ShareWindowBlur(window, 2.8125f).onBlurEnabledChanged(true)
        assertTrue(window.blurRequested())
        assertEquals(14, window.attributes.blurBehindRadius)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun blurOffFallsBackToTheDimAlone() {
        val window = window()
        val blur = ShareWindowBlur(window, 2.8125f)
        blur.onBlurEnabledChanged(true)
        blur.onBlurEnabledChanged(false)
        assertFalse(window.blurRequested())
        assertEquals(0, window.attributes.blurBehindRadius)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun blurOffBeforeAnyBlurStaysOff() {
        val window = window()
        ShareWindowBlur(window, 2.8125f).onBlurEnabledChanged(false)
        assertFalse(window.blurRequested())
        assertEquals(0, window.attributes.blurBehindRadius)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun toggledOffAndOnAgainRestoresTheBlur() {
        val window = window()
        val blur = ShareWindowBlur(window, 2.8125f)
        blur.onBlurEnabledChanged(true)
        blur.onBlurEnabledChanged(false)
        blur.onBlurEnabledChanged(true)
        assertTrue(window.blurRequested())
        assertEquals(14, window.attributes.blurBehindRadius)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun theListenerIsTheSameCallAsTheMethod() {
        val window = window()
        val blur = ShareWindowBlur(window, 2.8125f)
        blur.listener.accept(true)
        assertTrue(window.blurRequested())
        blur.listener.accept(false)
        assertFalse(window.blurRequested())
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun theBlurLeavesTheOtherFlagsAlone() {
        val window = window()
        val before = window.attributes.flags
        val blur = ShareWindowBlur(window, 2.8125f)
        blur.onBlurEnabledChanged(true)
        assertEquals(before or WindowManager.LayoutParams.FLAG_BLUR_BEHIND, window.attributes.flags)
        blur.onBlurEnabledChanged(false)
        assertEquals(before and WindowManager.LayoutParams.FLAG_BLUR_BEHIND.inv(), window.attributes.flags)
    }

    @Test
    @Config(sdk = [30])
    fun android11AsksForNothing() {
        val window = window()
        val flags = window.attributes.flags
        val blur = ShareWindowBlur(window, 2.8125f)
        blur.onBlurEnabledChanged(true)
        assertEquals(flags, window.attributes.flags)
        assertFalse(window.blurRequested())
        blur.onBlurEnabledChanged(false)
        assertEquals(flags, window.attributes.flags)
    }

    @Test
    fun theShareThemeStillHasNoSystemDim() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val style = app.resources.getIdentifier("ShareTheme", "style", app.packageName)
        assertTrue("@style/ShareTheme is missing", style != 0)
        val theme: Resources.Theme = app.resources.newTheme().apply { applyStyle(style, true) }
        val value = TypedValue()
        assertTrue(theme.resolveAttribute(android.R.attr.backgroundDimEnabled, value, true))
        assertEquals(0, value.data)
    }
}
