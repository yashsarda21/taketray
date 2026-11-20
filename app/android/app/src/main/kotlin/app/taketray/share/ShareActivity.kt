package app.taketray.share

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs

/**
 * The share screen (D-163): another app's Share › TakeTray opens it with an
 * `ACTION_SEND` of `text/plain` text. It runs its own Flutter engine with the
 * Dart entry point `shareMain` (`lib/share_main.dart`) on a see-through window
 * (`ShareTheme`, a transparent Flutter view), so the sharing app shows behind
 * it. It starts in the sharing app's task and is left out of Recents
 * (manifest), so closing it goes back to where the user was. TakeTray's own
 * screen, if it is open, is never touched: that is MainActivity's engine.
 *
 * It is exported, so any app can start it with any extras. FlutterActivity
 * reads several of its settings from the intent (a route, a cached engine,
 * the background mode, the entry point's arguments, the engine's flags); each
 * of those is fixed here, so an intent can only give a text to share.
 */
class ShareActivity : FlutterActivity() {
    private val bridges = ShareBridges(this)

    override fun getDartEntrypointFunctionName(): String = "shareMain"

    /** `main.dart` exports it, so the library is in the build. */
    override fun getDartEntrypointLibraryUri(): String = "package:taketray/share_main.dart"

    /** See-through: the sharing app shows behind the share sheet. */
    public override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    // Never from the intent (any app can start this activity). Deep linking
    // is off in the manifest (flutter_deeplinking_enabled), as on MainActivity.
    override fun getInitialRoute(): String? = null

    override fun getCachedEngineId(): String? = null

    override fun getCachedEngineGroupId(): String? = null

    override fun shouldDestroyEngineWithHost(): Boolean = true

    override fun getDartEntrypointArgs(): List<String>? = null

    override fun getFlutterShellArgs(): FlutterShellArgs = FlutterShellArgs(emptyArray<String>())

    override fun shouldRestoreAndSaveState(): Boolean = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridges.setUp(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridges.tearDown(flutterEngine.dartExecutor.binaryMessenger)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * A second share while the screen is open: it replaces the first, and
     * Dart reads it through `sharedText` (each intent is read once).
     */
    public override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        bridges.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        bridges.onHostGone()
        super.onDestroy()
    }
}
