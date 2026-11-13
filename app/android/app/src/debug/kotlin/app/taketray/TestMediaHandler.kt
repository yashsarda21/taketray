package app.taketray

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The method channel [CHANNEL], seen from Dart as the on-device tests' way to
 * put videos into the phone's media library and take them out again (D-77).
 * Debug builds only (this file is in `src/debug`).
 *
 * - `insertVideo({bytes, displayName, inWhatsAppSent})` gives
 *   `{volumeName, mediaStoreId}`; `inWhatsAppSent` (optional, false) puts the
 *   video in the test folder's `WhatsApp/Sent/` sub-folder instead.
 * - `deleteVideo({mediaStoreId})` gives true (deleted) or false (no such row).
 *   A row that is not one of this app's test videos is refused with the error
 *   code `refused`, and nothing is deleted.
 * - `deleteLeftovers()` gives `{deleted, refused}`: it deletes what an earlier,
 *   crashed run left in the test folder and its `WhatsApp/Sent/` sub-folder
 *   (only rows this app owns).
 *
 * The I/O runs on [io]; the reply is sent from [scope] (the main thread in the
 * app). Errors reach Dart as `native-error` with the method and the exception's
 * class name only, never a message, a name or a path (D-10).
 */
class TestMediaHandler(
    private val media: TestMedia,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main),
    private val io: CoroutineDispatcher = Dispatchers.IO,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val method = call.method
        scope.launch {
            try {
                when (method) {
                    "insertVideo" -> {
                        val bytes = call.argument<Any>("bytes") as? ByteArray
                        val name = call.argument<Any>("displayName") as? String
                        if (bytes == null || name == null) return@launch badArguments(method, result)
                        val inSent = call.argument<Any>("inWhatsAppSent") as? Boolean ?: false
                        val made = withContext(io) { media.insertVideo(bytes, name, inSent) }
                        result.success(mapOf("volumeName" to made.volumeName, "mediaStoreId" to made.mediaStoreId))
                    }
                    "deleteVideo" -> {
                        val id = (call.argument<Any>("mediaStoreId") as? Number)?.toLong() ?: return@launch badArguments(method, result)
                        result.success(withContext(io) { media.deleteVideo(id) })
                    }
                    "deleteLeftovers" -> {
                        val done = withContext(io) { media.deleteLeftovers() }
                        result.success(mapOf("deleted" to done.deleted, "refused" to done.refused))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: TestMediaRefused) {
                Log.w(TAG, "$method refused")
                result.error("refused", "not a TakeTray test video", null)
            } catch (e: Throwable) {
                Log.w(TAG, "$method failed: ${e.javaClass.simpleName}")
                result.error("native-error", "$method failed: ${e.javaClass.simpleName}", null)
            }
        }
    }

    private fun badArguments(
        method: String,
        result: MethodChannel.Result,
    ) {
        Log.w(TAG, "$method: bad arguments")
        result.error("bad-arguments", "$method needs its arguments", null)
    }

    companion object {
        /** The channel name Dart uses (`patrol_test/support/test_media.dart`). */
        const val CHANNEL = "app.taketray/test_media"

        private const val TAG = "TakeTrayTestMedia"
    }
}
