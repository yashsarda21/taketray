package app.taketray.media

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import android.provider.Settings
import android.util.Log
import java.util.TimeZone
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The Kotlin side of the media bridge (D-66): a thin pipe that reads
 * permissions, volumes, MediaStore rows, thumbnails and the zone-change list
 * and reports them. It decides nothing about which video is which.
 *
 * Threading: Pigeon runs every handler on the main thread; the `suspend`
 * (@async) ones that read MediaStore switch to Dispatchers.IO and Pigeon
 * replies on the main thread when they return. [requestAccess] stays on the
 * main thread, where Android delivers the permission result.
 *
 * Errors: an unexpected exception reaches Dart as FlutterError
 * "native-error" with the method and the exception's class name only, never
 * its message, which can hold a URI or a file path (D-10).
 */
class MediaHostApiImpl(
    activity: Activity,
    private val volumeSource: Volumes = MediaStoreVolumes(activity.applicationContext),
) : MediaHostApi {
    private val context: Context = activity.applicationContext
    private val resolver: ContentResolver = context.contentResolver
    private val prefs = context.getSharedPreferences(ZoneChangeStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val zones = ZoneChangeStore(prefs)

    /** Null once the activity is gone ([onHostGone]). */
    private var activity: Activity? = activity

    /** The one permission request in flight; touched on the main thread only. */
    private var pendingRequest: CompletableDeferred<Unit>? = null

    private val sdkInt get() = Build.VERSION.SDK_INT

    // ---- Access ----

    override fun accessReport(): AccessReportMsg =
        guarded("accessReport") {
            val level = currentLevel()
            val canAskAgain =
                MediaAccessChecker.canAskAgainNow(level, rationale(), blocked = prefs.getBoolean(KEY_BLOCKED, false))
            AccessReportMsg(level, canAskAgain, sdkInt.toLong())
        }

    /**
     * Shows Android's permission dialog and reports the result. A second call
     * while one is waiting fails with "busy". If the activity goes away first,
     * the waiting call fails with "host-gone" rather than hang.
     */
    override suspend fun requestAccess(): AccessReportMsg {
        val host = activity ?: throw FlutterError("no-activity", "requestAccess needs the activity")
        if (pendingRequest != null) throw FlutterError("busy", "a permission request is already showing")
        val request = CompletableDeferred<Unit>()
        pendingRequest = request
        try {
            host.requestPermissions(MediaAccessChecker.permissionsToRequest(sdkInt), PERMISSION_REQUEST_CODE)
            request.await()
        } finally {
            if (pendingRequest === request) pendingRequest = null
        }
        return guarded("requestAccess") {
            val level = currentLevel()
            val canAskAgain = MediaAccessChecker.canAskAgainAfterRequest(level, rationale())
            prefs.edit().putBoolean(KEY_BLOCKED, !canAskAgain).apply()
            Log.i(LOG_TAG, "access request answered: $level, canAskAgain $canAskAgain")
            AccessReportMsg(level, canAskAgain, sdkInt.toLong())
        }
    }

    /**
     * Called by MainActivity.onRequestPermissionsResult. True when it was this
     * bridge's request; the level is read again rather than from the result
     * arrays, which are empty when Android cancels a request.
     */
    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val request = pendingRequest ?: return false
        pendingRequest = null
        request.complete(Unit)
        return true
    }

    /** The activity is being destroyed: a waiting request fails instead of hanging. */
    fun onHostGone() {
        activity = null
        pendingRequest?.let {
            pendingRequest = null
            it.completeExceptionally(FlutterError("host-gone", "the activity closed before the permission result"))
        }
    }

    override fun openAppSettings() =
        guarded("openAppSettings") {
            val host = activity ?: throw FlutterError("no-activity", "openAppSettings needs the activity")
            host.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", host.packageName, null)),
            )
        }

    private fun currentLevel(): MediaAccessLevelMsg =
        MediaAccessChecker.level(sdkInt) { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    /** Whether Android would explain before asking again (needs the activity; false without one). */
    private fun rationale(): Boolean =
        activity?.shouldShowRequestPermissionRationale(MediaAccessChecker.permissionsToRequest(sdkInt).first()) ?: false

    // ---- Volumes and rows ----

    override fun volumes(): List<VolumeMsg> = guarded("volumes") { readVolumes(volumeSource) }

    override suspend fun videosAddedAfter(
        volumeName: String,
        afterGeneration: Long,
        folders: List<String>,
        limit: Long,
    ): List<VideoRowMsg> =
        io("videosAddedAfter") {
            if (folders.isEmpty() || limit <= 0) {
                emptyList()
            } else {
                rows(volumeName, VideoQueries.addedAfterArgs(afterGeneration, folders, limit))
            }
        }

    override suspend fun videosByIds(
        volumeName: String,
        ids: List<Long>,
    ): List<VideoRowMsg> =
        io("videosByIds") {
            ids.distinct().chunked(VideoQueries.MAX_IDS).flatMap { chunk -> rows(volumeName, VideoQueries.idsArgs(chunk)) }
        }

    override suspend fun allVideos(volumeName: String): List<VideoRowMsg> =
        io("allVideos") { rows(volumeName, VideoQueries.allVideosArgs()) }

    override suspend fun videosShotSince(
        volumeName: String,
        folders: List<String>,
        sinceMs: Long,
    ): List<VideoRowMsg> =
        io("videosShotSince") {
            if (folders.isEmpty()) emptyList() else rows(volumeName, VideoQueries.shotSinceArgs(folders, sinceMs))
        }

    /** Every folder that holds finished videos, per mounted volume, with how many. */
    override suspend fun videoFolders(): List<VideoFolderMsg> =
        io("videoFolders") {
            volumeSource.names().sorted().flatMap { volume ->
                val counts = sortedMapOf<String, Long>()
                query(volume, arrayOf(MediaColumns.RELATIVE_PATH), VideoQueries.allVideosArgs()).use { c ->
                    val i = c.getColumnIndexOrThrow(MediaColumns.RELATIVE_PATH)
                    while (c.moveToNext()) {
                        val path = if (c.isNull(i)) "" else c.getString(i)
                        counts[path] = (counts[path] ?: 0) + 1
                    }
                }
                counts.map { (path, count) -> VideoFolderMsg(volume, path, count) }
            }
        }

    private fun rows(
        volumeName: String,
        args: Bundle,
    ): List<VideoRowMsg> =
        query(volumeName, VideoQueries.PROJECTION, args).use { c ->
            val out = ArrayList<VideoRowMsg>(c.count.coerceAtLeast(0))
            while (c.moveToNext()) out += VideoQueries.rowFrom(c, volumeName)
            out
        }

    /**
     * A null cursor (the provider is unavailable) is an error, never an empty
     * answer: no rows from videosByIds would mean "every clip is gone".
     */
    private fun query(
        volumeName: String,
        projection: Array<String>,
        args: Bundle,
    ) = resolver.query(MediaStore.Video.Media.getContentUri(volumeName), projection, args, null)
        ?: throw FlutterError("no-cursor", "MediaStore returned no cursor for volume $volumeName")

    // ---- Thumbnails ----

    override suspend fun thumbnail(
        volumeName: String,
        mediaStoreId: Long,
        widthPx: Long,
        heightPx: Long,
    ): ByteArray? =
        io("thumbnail") {
            val uri = ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(volumeName), mediaStoreId)
            Thumbnails.load(resolver, uri, widthPx.toPixels(), heightPx.toPixels())
        }

    private fun Long.toPixels(): Int = coerceIn(0, MAX_THUMBNAIL_PX.toLong()).toInt()

    // ---- Time zones ----

    override fun currentZoneId(): String = guarded("currentZoneId") { TimeZone.getDefault().id }

    override fun pendingZoneChanges(): List<ZoneChangeMsg> = guarded("pendingZoneChanges") { zones.pending() }

    override fun clearZoneChangesUpTo(atMs: Long) = guarded("clearZoneChangesUpTo") { zones.clearUpTo(atMs) }

    // ---- Camera ----

    /** Opens the camera in video mode; false when no app handles it. */
    override fun openVideoCamera(): Boolean =
        guarded("openVideoCamera") {
            val host = activity ?: throw FlutterError("no-activity", "openVideoCamera needs the activity")
            try {
                host.startActivity(Intent(MediaStore.INTENT_ACTION_VIDEO_CAMERA))
                true
            } catch (e: ActivityNotFoundException) {
                false
            }
        }

    private suspend fun <T> io(
        method: String,
        block: () -> T,
    ): T = withContext(Dispatchers.IO) { guarded(method, block) }

    companion object {
        /** The request code of the media permission request (16 bits, unlike any plugin's). */
        const val PERMISSION_REQUEST_CODE = 0x7A71

        /** Remembers that the last request ended with "cannot ask again" (see MediaAccessChecker.canAskAgainNow). */
        private const val KEY_BLOCKED = "media_request_blocked"

        /** No thumbnail is asked bigger than this; a larger request is capped. */
        private const val MAX_THUMBNAIL_PX = 4096
    }
}

/** Runs [block]; an unexpected exception becomes [nativeError]. */
private inline fun <T> guarded(
    method: String,
    block: () -> T,
): T =
    try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        throw nativeError(method, e)
    }

/**
 * What Dart gets for [e]: a FlutterError the bridge threw on purpose as it is;
 * anything else as "native-error" with the method and the class name, without
 * the message or cause, which can hold a URI or a file path (D-10).
 */
internal fun nativeError(
    method: String,
    e: Throwable,
): FlutterError {
    if (e is FlutterError) return e
    Log.w(LOG_TAG, "$method failed: ${e.javaClass.simpleName}")
    return FlutterError("native-error", "$method failed: ${e.javaClass.simpleName}", null)
}
