package app.taketray

import android.content.Intent
import android.os.Bundle
import app.taketray.background.Arming
import app.taketray.background.BackgroundFlutterApi
import app.taketray.background.BackgroundHostApi
import app.taketray.background.BackgroundHostApiImpl
import app.taketray.background.LaunchActionRelay
import app.taketray.media.MediaHostApi
import app.taketray.media.MediaHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** The media bridge of the current engine; null before configure and after clean-up. */
    private var media: MediaHostApiImpl? = null

    /** The background bridge of the current engine (D-103); null before configure and after clean-up. */
    private var background: BackgroundHostApiImpl? = null

    /**
     * True when Android re-created this activity from saved state (after the
     * process died): its intent is the first one, already handled, so its
     * launch action is dropped.
     */
    private var restored = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super: super.onCreate runs configureFlutterEngine.
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val impl = MediaHostApiImpl(this)
        media = impl
        MediaHostApi.setUp(messenger, impl)

        // Arming.background(): the new-clips job (D-104); Task 5 adds the alarms.
        val flutterApi = BackgroundFlutterApi(messenger)
        val bg = BackgroundHostApiImpl(this, Arming.background(), LaunchActionRelay(send = flutterApi::onLaunchAction))
        background = bg
        BackgroundHostApi.setUp(messenger, bg)
        bg.launches.onIntent(intent, restored)

        DebugHooks.register(flutterEngine, applicationContext)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MediaHostApi.setUp(messenger, null)
        BackgroundHostApi.setUp(messenger, null)
        media?.onHostGone()
        media = null
        background?.let {
            it.onHostGone()
            it.launches.close()
        }
        background = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** A notification tapped while the activity runs (singleTop): its launch action, if any. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        background?.launches?.onIntent(intent)
    }

    /**
     * Never a route from the launching intent. FlutterActivity reads a `route`
     * extra from any intent, with deep linking on or off, and MainActivity is
     * exported: any app could open any screen. Notifications use launch actions
     * instead (D-103).
     */
    override fun getInitialRoute(): String? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Each bridge answers only its own request code.
        media?.onPermissionResult(requestCode)
        background?.onPermissionResult(requestCode)
    }

    override fun onDestroy() {
        // A permission request still waiting (for example, the activity is
        // recreated while the dialog is up) fails instead of hanging. The engine
        // these bridges belong to is destroyed with the activity.
        media?.onHostGone()
        background?.onHostGone()
        super.onDestroy()
    }
}
