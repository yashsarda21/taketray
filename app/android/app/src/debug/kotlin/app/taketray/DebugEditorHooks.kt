package app.taketray

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import app.taketray.editors.ActivityStarter
import app.taketray.editors.EditorApps
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Debug-only hooks for the on-device editor tests (D-121): registers the
 * `app.taketray/test_editors` channel. The release and profile builds have
 * none of this (`DebugHooks` there registers nothing), and
 * `tool/check_release_permissions` fails if the release dex holds it.
 */
object DebugEditorHooks {
    @Suppress("UNUSED_PARAMETER")
    fun register(
        engine: FlutterEngine,
        context: Context,
    ) {
        MethodChannel(engine.dartExecutor.binaryMessenger, DebugEditorHandler.CHANNEL)
            .setMethodCallHandler(DebugEditorHandler())
    }
}

/**
 * Stands in for the activity while recording: describes each intent instead
 * of starting it, so a test never opens CapCut, Edits, VN, the Play Store or
 * the share sheet. An editor the override marks as not installed throws
 * `ActivityNotFoundException`, as Android would, and is not recorded.
 */
class IntentRecorder : ActivityStarter {
    private val recorded = mutableListOf<Map<String, Any?>>()

    @Synchronized
    override fun start(intent: Intent) {
        val pkg = intent.`package`
        if (pkg != null && EditorApps.installedOverride?.get(pkg) == false) throw ActivityNotFoundException()
        recorded += describe(intent)
    }

    /** What was recorded since the last take, in order; then forgets it. */
    @Synchronized
    fun take(): List<Map<String, Any?>> = recorded.toList().also { recorded.clear() }

    private fun describe(intent: Intent): Map<String, Any?> {
        @Suppress("DEPRECATION")
        val target = if (intent.action == Intent.ACTION_CHOOSER) intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) else null
        val shared = target ?: intent
        return mapOf(
            "action" to intent.action,
            "package" to intent.`package`,
            "targetAction" to target?.action,
            "type" to shared.type,
            "uris" to streams(shared).map(::label),
            "grantRead" to (grants(intent) && (target == null || grants(target))),
            "clipDataCount" to (intent.clipData?.itemCount ?: 0),
            "data" to intent.data?.takeIf { it.scheme == "market" }?.toString(),
        )
    }

    private fun grants(intent: Intent) = intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0

    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): List<Uri> =
        when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            else -> emptyList()
        }

    /** `volume:id` for a MediaStore video, `picker` for any other address: never the address itself. */
    private fun label(uri: Uri): String {
        val s = uri.pathSegments
        return if (uri.authority == "media" && s.size == 4 && s[1] == "video" && s[2] == "media") "${s[0]}:${s[3]}" else "picker"
    }
}

/**
 * The method channel [CHANNEL]:
 *
 * - `setInstalledOverride(Map<String, bool>?)`: the editors these packages
 *   are, installed or not, whatever the phone has ([EditorApps.installedOverride]);
 *   null goes back to the phone's answer.
 * - `recordIntents(bool)`: true puts a fresh [IntentRecorder] in place of
 *   the activity's starter ([ActivityStarter.replacement]), so nothing starts;
 *   false removes it and forgets what it held.
 * - `takeRecordedIntents()`: each recorded intent's action, package, the
 *   chooser's target action, type, the clips as `volume:id` or `picker`,
 *   whether it grants read access (on the chooser and its target both), its
 *   ClipData count and, for the store, its `market://` address. Taken once.
 *
 * Errors: `bad-args` for arguments of the wrong type; `native-error` with the
 * class name only (D-10).
 */
class DebugEditorHandler : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            when (call.method) {
                "setInstalledOverride" -> {
                    val args = call.arguments
                    if (args != null && args !is Map<*, *>) return result.error("bad-args", "a map or null", null)
                    EditorApps.installedOverride =
                        (args as Map<*, *>?)?.entries?.associate { (k, v) ->
                            if (k !is String || v !is Boolean) return result.error("bad-args", "package to bool", null)
                            k to v
                        }
                    result.success(null)
                }
                "recordIntents" -> {
                    val on = call.arguments as? Boolean ?: return result.error("bad-args", "a bool", null)
                    ActivityStarter.replacement = if (on) IntentRecorder() else null
                    result.success(null)
                }
                "takeRecordedIntents" -> result.success((ActivityStarter.replacement as? IntentRecorder)?.take().orEmpty())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "${call.method} failed: ${e.javaClass.simpleName}")
            result.error("native-error", "${call.method} failed: ${e.javaClass.simpleName}", null)
        }
    }

    companion object {
        /** The channel name Dart uses. */
        const val CHANNEL = "app.taketray/test_editors"

        private const val TAG = "TakeTrayTestEditors"
    }
}
