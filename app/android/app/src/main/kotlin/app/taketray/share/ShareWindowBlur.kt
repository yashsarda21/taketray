package app.taketray.share

import android.os.Build
import android.view.Window
import android.view.WindowManager
import java.util.function.Consumer
import kotlin.math.roundToInt

/**
 * The share screen's window blur (D-177, amends D-167). The window is
 * see-through to the sharing app, so on Android 12+ it asks Android to blur
 * what is behind it ([WindowManager.LayoutParams.FLAG_BLUR_BEHIND] with
 * `blurBehindRadius`), by the design's 3 dp. Below Android 12 nothing is
 * asked, and while cross-window blur is off (battery saver) the request is
 * withdrawn: in both cases the Flutter 50 % dim (`share_app.dart`) is all
 * there is.
 *
 * Android calls [listener] (registered by `ShareActivity` with
 * `WindowManager.addCrossWindowBlurEnabledListener`) at once with the current
 * state and again whenever it changes.
 */
internal class ShareWindowBlur(
    private val window: Window,
    density: Float,
) {
    /** The blur radius in pixels that Android turns into 3 dp of blur. */
    val radiusPx: Int = radiusForSigma(SIGMA_DP * density)

    val listener: Consumer<Boolean> = Consumer { onBlurEnabledChanged(it) }

    /**
     * Android 12+: enabled asks for the blur, disabled withdraws it (flag
     * cleared, radius 0). Below Android 12: does nothing.
     */
    fun onBlurEnabledChanged(enabled: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val attributes = window.attributes
        if (enabled) {
            attributes.flags = attributes.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
            attributes.blurBehindRadius = radiusPx
        } else {
            attributes.flags = attributes.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND.inv()
            attributes.blurBehindRadius = 0
        }
        window.attributes = attributes
    }

    companion object {
        /** tt-style.css:122: .style-tt .scrim { backdrop-filter: blur(3px) } (TtMetrics.scrimBlur). */
        const val SIGMA_DP = 3f

        /**
         * Android's own rule, sigma = 0.57735 x radius + 0.5 (AOSP hwui
         * Blur::convertRadiusToSigma), inverted and rounded; 0 for sigma <= 0.5.
         */
        fun radiusForSigma(sigmaPx: Float): Int = if (sigmaPx <= 0.5f) 0 else ((sigmaPx - 0.5f) / 0.57735f).roundToInt()
    }
}
