package app.taketray.media

import android.content.ContentResolver
import android.graphics.Bitmap
import android.net.Uri
import android.os.OperationCanceledException
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.IOException
import kotlin.math.max
import kotlin.math.roundToInt

/** A video's thumbnail: JPEG bytes for Dart, or a bitmap for a notification. */
object Thumbnails {
    private const val JPEG_QUALITY = 85

    /** JPEG bytes of [uri]'s thumbnail, or null when the video is gone or unreadable. */
    fun load(
        resolver: ContentResolver,
        uri: Uri,
        widthPx: Int,
        heightPx: Int,
    ): ByteArray? = encode(widthPx, heightPx) { size -> resolver.loadThumbnail(uri, size, null) }

    /**
     * Like [load] for an address as text (a picked video). Anything that is
     * not a `content:` address (a file path, nothing, rubbish) has no
     * thumbnail and asks nothing: [loader] is not called for it. The size must
     * be positive, as for [encode]. [loader] defaults to the resolver's own
     * thumbnail load; tests pass a recording one.
     */
    fun loadFromUri(
        resolver: ContentResolver,
        uri: String,
        widthPx: Int,
        heightPx: Int,
        loader: (Uri, Size) -> Bitmap = { address, size -> resolver.loadThumbnail(address, size, null) },
    ): ByteArray? {
        require(widthPx > 0 && heightPx > 0) { "thumbnail size must be positive" }
        val parsed = Uri.parse(uri)
        if (!ContentResolver.SCHEME_CONTENT.equals(parsed.scheme, ignoreCase = true)) return null
        return encode(widthPx, heightPx) { size -> loader(parsed, size) }
    }

    /**
     * Loads with [loader] and encodes. A gone or unreadable video
     * (FileNotFoundException, IOException), a lost permission
     * (SecurityException) or a cancelled load (OperationCanceledException)
     * is null; any other exception goes to the caller, and so to Dart as an
     * error. loadThumbnail may return a bigger bitmap than asked, so the result
     * is scaled down until its longer side is at most max(width, height).
     */
    fun encode(
        widthPx: Int,
        heightPx: Int,
        loader: (Size) -> Bitmap,
    ): ByteArray? {
        require(widthPx > 0 && heightPx > 0) { "thumbnail size must be positive" }
        val bitmap = loadOrNull(Size(widthPx, heightPx), loader) ?: return null
        val scaled = scaleToFit(bitmap, max(widthPx, heightPx))
        try {
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            return out.toByteArray()
        } finally {
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
        }
    }

    /**
     * [uri]'s thumbnail as a bitmap whose longer side is at most [maxSide],
     * for the new-clips notification (D-104); null in the same cases as
     * [encode].
     */
    fun bitmap(
        resolver: ContentResolver,
        uri: Uri,
        maxSide: Int,
    ): Bitmap? = scaled(maxSide) { size -> resolver.loadThumbnail(uri, size, null) }

    /** Loads with [loader] at [maxSide] square and scales the result to fit; null as [encode]. */
    fun scaled(
        maxSide: Int,
        loader: (Size) -> Bitmap,
    ): Bitmap? {
        require(maxSide > 0) { "thumbnail size must be positive" }
        val bitmap = loadOrNull(Size(maxSide, maxSide), loader) ?: return null
        val scaled = scaleToFit(bitmap, maxSide)
        if (scaled !== bitmap) bitmap.recycle()
        return scaled
    }

    /** [loader]'s bitmap; null for a gone or unreadable video, a lost permission or a cancelled load. */
    private fun loadOrNull(
        size: Size,
        loader: (Size) -> Bitmap,
    ): Bitmap? =
        try {
            loader(size)
        } catch (e: IOException) {
            null
        } catch (e: SecurityException) {
            null
        } catch (e: OperationCanceledException) {
            null
        }

    /** [bitmap] itself when its longer side is at most [maxSide], else a scaled-down copy. */
    fun scaleToFit(
        bitmap: Bitmap,
        maxSide: Int,
    ): Bitmap {
        val longer = max(bitmap.width, bitmap.height)
        if (longer <= maxSide) return bitmap
        val factor = maxSide.toDouble() / longer
        val width = (bitmap.width * factor).roundToInt().coerceIn(1, maxSide)
        val height = (bitmap.height * factor).roundToInt().coerceIn(1, maxSide)
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }
}
