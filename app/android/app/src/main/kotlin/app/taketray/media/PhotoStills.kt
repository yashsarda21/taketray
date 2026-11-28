package app.taketray.media

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.IOException
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The clip viewer's still of a photo (D-201): the picture decoded by Android
 * at the screen's size, as JPEG bytes for Dart.
 *
 * Android's own decoder (ImageDecoder, API 28) reads every image type the
 * phone knows (JPEG, HEIC, PNG, WebP...), applies the EXIF orientation, and
 * decodes straight at the target size, so a 50 MP photo never takes its full
 * size in memory. No package is added for it.
 */
object PhotoStills {
    /** The JPEG quality of a still: it is shown full screen, so higher than a thumbnail's. */
    const val STILL_JPEG_QUALITY = 90

    /**
     * The size to decode a [width] x [height] picture at: as it is when its
     * longer side is at most [maxSide] (never bigger), else scaled down,
     * shape kept, so the longer side is [maxSide]. Each side is at least 1.
     */
    fun targetSize(
        width: Int,
        height: Int,
        maxSide: Int,
    ): Size {
        val longer = max(width, height)
        if (longer <= maxSide) return Size(width, height)
        val factor = maxSide.toDouble() / longer
        return Size(
            (width * factor).roundToInt().coerceIn(1, maxSide),
            (height * factor).roundToInt().coerceIn(1, maxSide),
        )
    }

    /**
     * JPEG bytes of the picture at [uri], its longer side at most [maxSide].
     *
     * Null, and nothing decoded, for an address that is not `content:` (a
     * file path, nothing, rubbish). Null too when the photo is gone or
     * unreadable (IOException, which includes ImageDecoder.DecodeException
     * for bytes that are not a picture) or its grant is lost
     * (SecurityException). Any other exception goes to the caller, and so to
     * Dart as an error. [maxSide] must be above 0.
     *
     * [decodeBitmap] decodes an address, asking the function it is given for
     * the size to decode at from the picture's own (oriented) size; it
     * defaults to [imageDecoder]. Tests pass a recording one.
     */
    fun decode(
        resolver: ContentResolver,
        uri: String,
        maxSide: Int,
        decodeBitmap: (Uri, (Size) -> Size) -> Bitmap = imageDecoder(resolver),
    ): ByteArray? {
        require(maxSide > 0) { "still size must be positive" }
        val parsed = Uri.parse(uri)
        if (!ContentResolver.SCHEME_CONTENT.equals(parsed.scheme, ignoreCase = true)) return null
        val bitmap = decodeOrNull(parsed, maxSide, decodeBitmap) ?: return null
        try {
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, STILL_JPEG_QUALITY, out)
            return out.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    /** [decodeBitmap]'s bitmap at the target size; null for a gone, unreadable or refused photo. */
    private fun decodeOrNull(
        uri: Uri,
        maxSide: Int,
        decodeBitmap: (Uri, (Size) -> Size) -> Bitmap,
    ): Bitmap? =
        try {
            decodeBitmap(uri) { size -> targetSize(size.width, size.height, maxSide) }
        } catch (e: IOException) {
            null
        } catch (e: SecurityException) {
            null
        }

    /**
     * Decodes with ImageDecoder from [resolver]: the header is read first, and
     * the decoder is told the target size before any pixel is decoded. The
     * software allocator, because a hardware bitmap is not meant to be read
     * back for the JPEG.
     */
    fun imageDecoder(resolver: ContentResolver): (Uri, (Size) -> Size) -> Bitmap =
        { uri, sizeFor ->
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(resolver, uri)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val target = sizeFor(info.size)
                decoder.setTargetSize(target.width, target.height)
            }
        }
}
