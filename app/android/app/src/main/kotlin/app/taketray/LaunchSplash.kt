package app.taketray

import android.app.Activity
import android.view.View
import androidx.core.splashscreen.SplashScreen
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

/**
 * The launch splash's code half (D-137). The look is all resources
 * (`LaunchTheme`, `splash_icon_animated`); this is the exit.
 *
 * The splash stays only until Flutter draws its first frame (Dart holds that
 * frame until the onboarding flags are read, D-136) and never waits for the
 * 900 ms animation, so no keep-on-screen condition is set. When the frame
 * comes, the splash fades out in 200 ms, faster than the entrance.
 */
object LaunchSplash {
    /** The exit fade, Material `short4`: shorter than the entrance. */
    const val FADE_MS = 200L

    /**
     * Installs the splash for [activity]. Call it before `super.onCreate`:
     * the compat library swaps the launch theme for the post-splash one
     * (`NormalTheme`) at this call, before the Flutter view is built.
     */
    fun install(activity: Activity): SplashScreen {
        val splash = activity.installSplashScreen()
        splash.setOnExitAnimationListener { provider ->
            fadeOut(provider.view, provider::remove)
        }
        return splash
    }

    /** Fades [view] to nothing over [FADE_MS], then calls [remove] once. */
    fun fadeOut(view: View, remove: () -> Unit) {
        view.animate()
            .alpha(0f)
            .setDuration(FADE_MS)
            .withEndAction(remove)
            .start()
    }
}
