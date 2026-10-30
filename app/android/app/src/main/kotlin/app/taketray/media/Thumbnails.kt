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

/** A video's thumbnail as JPEG bytes. */
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
        val bitmap =
            try {
                loader(Size(widthPx, heightPx))
            } catch (e: IOException) {
                return null
            } catch (e: SecurityException) {
                return null
            } catch (e: OperationCanceledException) {
                return null
            }
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
