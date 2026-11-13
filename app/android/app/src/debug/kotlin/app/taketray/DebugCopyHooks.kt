package app.taketray

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.WindowManager
import app.taketray.editors.CopyEngine
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Debug-only hooks for the on-device copy tests (Phase 8, D-122): registers
 * the `app.taketray/test_copy` channel. The release and profile builds have
 * none of this (`DebugHooks` there registers nothing), and
 * `tool/check_release_permissions` fails if the release dex holds it.
 */
object DebugCopyHooks {
    /** [context] is MainActivity itself: the flag is read from its window. */
    fun register(
        engine: FlutterEngine,
        context: Context,
    ) {
        val activity = context as? Activity
        val copies = CopyEngine.shared(context.applicationContext)
        MethodChannel(engine.dartExecutor.binaryMessenger, DebugCopyHandler.CHANNEL)
            .setMethodCallHandler(DebugCopyHandler(copies) { flagOf(activity) })
    }

    /** Whether [activity]'s window has FLAG_KEEP_SCREEN_ON now; false without one. */
    fun flagOf(activity: Activity?): Boolean =
        activity?.window?.attributes?.flags?.let { it and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0 } ?: false
}

/**
 * The method channel [CHANNEL]:
 *
 * - `setCopyThrottleMs(int)`: a pause after every copied chunk, so a flow can
 *   stop a copy mid-file or watch its progress. A whole number from 0; 0
 *   switches it off (the default).
 * - `keepScreenOnFlag()`: whether the activity's window has
 *   FLAG_KEEP_SCREEN_ON now (the real flag, not what Dart asked for).
 *
 * Errors carry a code and no name or path (D-10).
 */
class DebugCopyHandler(
    private val engine: CopyEngine,
    private val keepScreenOnFlag: () -> Boolean,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "setCopyThrottleMs" -> {
                val ms = (call.arguments as? Number)?.takeIf { it is Int || it is Long }?.toLong()
                if (ms == null || ms < 0) {
                    Log.w(TAG, "setCopyThrottleMs: bad argument")
                    result.error("bad-argument", "setCopyThrottleMs takes a whole number from 0", null)
                } else {
                    engine.throttleMs = ms
                    result.success(null)
                }
            }
            "keepScreenOnFlag" -> result.success(keepScreenOnFlag())
            else -> result.notImplemented()
        }
    }

    companion object {
        /** The channel name Dart uses (`patrol_test/support/`). */
        const val CHANNEL = "app.taketray/test_copy"

        private const val TAG = "TakeTrayTestCopy"
    }
}
