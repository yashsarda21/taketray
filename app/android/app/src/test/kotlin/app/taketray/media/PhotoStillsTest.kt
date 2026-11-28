package app.taketray.media

import android.content.ContentResolver
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.util.Size
import androidx.test.core.app.ApplicationProvider
import java.io.FileNotFoundException
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The viewer's still of a photo (D-201): the size it is decoded at, never
 * bigger than the picture, and which failures mean "no still".
 */
@RunWith(RobolectricTestRunner::class)
class PhotoStillsTest {
    private val resolver: ContentResolver =
        ApplicationProvider.getApplicationContext<Context>().contentResolver

    private val photo = "content://media/picker/0/com.android.providers.media.photopicker/media/1000000077"

    @Test
    fun `targetSize never upscales and keeps the longest side at most maxSide`() {
        // A 50 MP phone photo on a 2340 px screen: the longer side is the screen's.
        assertEquals(Size(2340, 1755), PhotoStills.targetSize(8160, 6120, 2340))
        // The same photo held upright.
        assertEquals(Size(1755, 2340), PhotoStills.targetSize(6120, 8160, 2340))
        // A small picture stays as it is.
        assertEquals(Size(800, 600), PhotoStills.targetSize(800, 600, 2340))
        // Exactly the screen: as it is.
        assertEquals(Size(2340, 1000), PhotoStills.targetSize(2340, 1000, 2340))
    }

    @Test
    fun `targetSize keeps a side of at least 1`() {
        assertEquals(Size(100, 1), PhotoStills.targetSize(10000, 1, 100))
        assertEquals(Size(1, 100), PhotoStills.targetSize(1, 10000, 100))
    }

    @Test
    fun `decode asks the decoder for the target size and gives JPEG bytes`() {
        val asked = mutableListOf<Uri>()
        var target: Size? = null
        val bytes =
            PhotoStills.decode(resolver, photo, 2340) { uri, sizeFor ->
                asked += uri
                // The decoder reads the picture's size from its header (EXIF
                // orientation applied) and asks what to decode it at.
                val size = sizeFor(Size(8160, 6120))
                target = size
                Bitmap.createBitmap(size.width, size.height, Bitmap.Config.ARGB_8888)
            }
        assertEquals(listOf(Uri.parse(photo)), asked)
        assertEquals(Size(2340, 1755), target)
        assertNotNull(bytes)
        // JPEG: it starts with the SOI marker, and decodes at the target size.
        assertEquals(0xFF.toByte(), bytes!![0])
        assertEquals(0xD8.toByte(), bytes[1])
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        assertEquals("decoded ${bounds.outWidth}x${bounds.outHeight}", 2340, bounds.outWidth)
        assertEquals("decoded ${bounds.outWidth}x${bounds.outHeight}", 1755, bounds.outHeight)
        assertEquals(90, PhotoStills.STILL_JPEG_QUALITY)
    }

    @Test
    fun `decode is null for a gone file, a lost grant, an undecodable file and a non-content address`() {
        // ImageDecoder's own error for bytes that are not a picture. Its
        // constructor is hidden from apps, so it is made by reflection.
        val undecodable =
            ImageDecoder.DecodeException::class.java
                .getDeclaredConstructor(
                    Int::class.javaPrimitiveType,
                    String::class.java,
                    Throwable::class.java,
                    ImageDecoder.Source::class.java,
                ).apply { isAccessible = true }
                .newInstance(
                    ImageDecoder.DecodeException.SOURCE_MALFORMED_DATA,
                    "not a picture",
                    null,
                    ImageDecoder.createSource(ByteBuffer.wrap(byteArrayOf(1, 2, 3))),
                )
        for (error in listOf<Exception>(FileNotFoundException("gone"), SecurityException("grant lost"), undecodable)) {
            var calls = 0
            val bytes =
                PhotoStills.decode(resolver, photo, 2340) { _, _ ->
                    calls++
                    throw error
                }
            assertNull(error.javaClass.simpleName, bytes)
            assertEquals(1, calls)
        }
        // Not a content address: nothing is asked.
        val asked = mutableListOf<Uri>()
        for (text in listOf("", "file:///storage/emulated/0/DCIM/a.jpg", "/storage/emulated/0/a.jpg", "not a uri", "http://example.com/a.jpg")) {
            val bytes =
                PhotoStills.decode(resolver, text, 2340) { uri, _ ->
                    asked += uri
                    Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
                }
            assertNull(text, bytes)
        }
        assertTrue(asked.isEmpty())
        // A content address in capitals is still one.
        assertNotNull(PhotoStills.decode(resolver, photo.uppercase(), 2340) { _, _ -> Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888) })
    }

    @Test
    fun `decode passes any other exception on`() {
        assertThrows(IllegalStateException::class.java) {
            PhotoStills.decode(resolver, photo, 2340) { _, _ -> throw IllegalStateException("decoder broke") }
        }
        assertThrows(OutOfMemoryError::class.java) {
            PhotoStills.decode(resolver, photo, 2340) { _, _ -> throw OutOfMemoryError() }
        }
        // A size of 0 or less is the caller's mistake.
        assertThrows(IllegalArgumentException::class.java) {
            PhotoStills.decode(resolver, photo, 0) { _, _ -> Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888) }
        }
    }
}
