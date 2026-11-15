package app.taketray

import android.content.Intent
import android.os.Bundle
import app.taketray.background.Arming
import app.taketray.background.BackgroundFlutterApi
import app.taketray.background.BackgroundHostApi
import app.taketray.background.BackgroundHostApiImpl
import app.taketray.background.LaunchActionRelay
import app.taketray.editors.EditorsHostApi
import app.taketray.editors.EditorsHostApiImpl
import app.taketray.editors.CopyEngine
import app.taketray.editors.CopyFlutterApi
import app.taketray.editors.CopyHostApi
import app.taketray.editors.CopyHostApiImpl
import app.taketray.media.MediaHostApi
import app.taketray.media.MediaHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** The media bridge of the current engine; null before configure and after clean-up. */
    private var media: MediaHostApiImpl? = null

    /** The background bridge of the current engine (D-103); null before configure and after clean-up. */
    private var background: BackgroundHostApiImpl? = null

    /** The editors bridge of the current engine (D-121); null before configure and after clean-up. */
    private var editors: EditorsHostApiImpl? = null
    /** The copy bridge of the current engine (D-122); the job itself lives in the process-wide [CopyEngine]. */
    private var copy: CopyHostApiImpl? = null

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

        // Arming.background(): the channels, the new-clips job (D-104) and the reminder alarms (D-105).
        // From the app's own writes an overdue Still shooting? is left to the in-app dialog.
        val flutterApi = BackgroundFlutterApi(messenger)
        val bg = BackgroundHostApiImpl(this, Arming.background(armOverdueStill = false),LaunchActionRelay.forActivity(this, send = flutterApi::onLaunchAction))
        background = bg
        BackgroundHostApi.setUp(messenger, bg)
        bg.launches.onIntent(intent, restored)

        // The editors bridge (D-121): shares, the store listing and the copy folders behind their guard.
        val ed = EditorsHostApiImpl(this)
        editors = ed
        EditorsHostApi.setUp(messenger, ed)

        // Copying (D-122): the job belongs to the process; this activity gives the bridge its window for the screen-on flag.
        val copyFlutterApi = CopyFlutterApi(messenger)
        val copyApi = CopyHostApiImpl(this, CopyEngine.shared(applicationContext), send = copyFlutterApi::onCopyChanged)
        copy = copyApi
        CopyHostApi.setUp(messenger, copyApi)

        // The activity itself: the debug copy hooks read its window (the others use the application context).
        DebugHooks.register(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MediaHostApi.setUp(messenger, null)
        BackgroundHostApi.setUp(messenger, null)
        EditorsHostApi.setUp(messenger, null)
        editors?.onHostGone()
        editors = null
        media?.onHostGone()
        media = null
        background?.let {
            it.onHostGone()
            it.launches.close()
        }
        background = null
        CopyHostApi.setUp(messenger, null)
        copy?.onHostGone()
        copy = null
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

    /**
     * The photo picker's answer (D-112) and the copies' delete consent (D-121):
     * each bridge takes only its own request code, or drops it when no call
     * waits (the process died).
     */
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        media?.onActivityResult(requestCode, resultCode, data)
        editors?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        // A permission request still waiting (for example, the activity is
        // recreated while the dialog is up) fails instead of hanging. The engine
        // these bridges belong to is destroyed with the activity.
        media?.onHostGone()
        background?.onHostGone()
        editors?.onHostGone()
        copy?.onHostGone()
        super.onDestroy()
    }
}
