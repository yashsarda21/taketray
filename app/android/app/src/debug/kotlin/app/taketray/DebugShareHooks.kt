package app.taketray

import android.content.Context
import android.content.Intent
import android.util.Log
import app.taketray.share.ShareActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Debug-only hook for the on-device share tests (Phase 9B, D-169): registers
 * the `app.taketray/test_share` channel on the app's engine (the one Patrol
 * drives). The release and profile builds have none of this (`DebugHooks`
 * there registers nothing), and `tool/check_release_permissions` fails if the
 * release dex holds it.
 */
object DebugShareHooks {
    fun register(
        engine: FlutterEngine,
        context: Context,
    ) {
        MethodChannel(engine.dartExecutor.binaryMessenger, DebugShareHandler.CHANNEL)
            .setMethodCallHandler(handlerFor(context))
    }

    /**
     * The handler for [context], which may be an activity (MainActivity
     * passes itself): only its application context is kept, so the handler
     * never holds an activity.
     */
    fun handlerFor(context: Context): DebugShareHandler = DebugShareHandler(context.applicationContext)
}

/**
 * The method channel [CHANNEL]:
 *
 * - `startShare(String text)`: starts [ShareActivity] with an `ACTION_SEND`
 *   of `text/plain` carrying [text] as `EXTRA_TEXT`, as another app's Share
 *   does. The text is passed as it is (empty, long and caption-only texts
 *   too: the screen decides what it is).
 *
 * It starts from the application context, which Android only allows with
 * `FLAG_ACTIVITY_NEW_TASK`. A real share has no such flag: the sharing app
 * starts the screen in its own task, which shows behind it. Here the screen
 * is the root of a task of its own, and TakeTray's task (the app engine
 * Patrol drives) is what shows behind it. Everything the screen does is the
 * same; what it returns to is a hand check (D-169).
 *
 * Errors: `bad-args` for a text that is not a string; `native-error` with the
 * class name only (D-10: never the text, which can be a caption or a link).
 */
class DebugShareHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            when (call.method) {
                "startShare" -> {
                    val text = call.arguments as? String ?: return result.error("bad-args", "a string", null)
                    val intent =
                        Intent(Intent.ACTION_SEND)
                            .setClassName(context, ShareActivity::class.java.name)
                            .setType("text/plain")
                            .putExtra(Intent.EXTRA_TEXT, text)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "${call.method} failed: ${e.javaClass.simpleName}")
            result.error("native-error", "${call.method} failed: ${e.javaClass.simpleName}", null)
        }
    }

    companion object {
        /** The channel name Dart uses (`patrol_test/support/test_share.dart`). */
        const val CHANNEL = "app.taketray/test_share"

        private const val TAG = "TakeTrayTestShare"
    }
}
