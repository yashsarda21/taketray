package app.taketray

import app.taketray.media.MediaHostApi
import app.taketray.media.MediaHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** The media bridge of the current engine; null before configure and after clean-up. */
    private var media: MediaHostApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val impl = MediaHostApiImpl(this)
        media = impl
        MediaHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, impl)
        DebugHooks.register(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MediaHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        media?.onHostGone()
        media = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        media?.onPermissionResult(requestCode)
    }

    override fun onDestroy() {
        // A permission request still waiting (for example, the activity is
        // recreated while the dialog is up) fails instead of hanging. The engine
        // this bridge belongs to is destroyed with the activity.
        media?.onHostGone()
        super.onDestroy()
    }
}
