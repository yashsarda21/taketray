package app.taketray

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Debug-only hooks for on-device tests. Registers the `app.taketray/test_media`
 * channel, with which the Patrol tests put test videos into the phone's media
 * library and remove them again (D-77), and `app.taketray/test_background`
 * ([DebugBackgroundHooks], Phase 6). The release and profile copies of this
 * object register nothing, and `tool/check_release_permissions` fails if the
 * release build holds any of this.
 */
object DebugHooks {
    fun register(
        engine: FlutterEngine,
        context: Context,
    ) {
        val app = context.applicationContext
        val media = TestMedia(app.contentResolver, app.packageName)
        MethodChannel(engine.dartExecutor.binaryMessenger, TestMediaHandler.CHANNEL)
            .setMethodCallHandler(TestMediaHandler(media))
        DebugBackgroundHooks.register(engine, app)
    }
}
