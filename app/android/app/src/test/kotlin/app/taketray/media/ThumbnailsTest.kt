package app.taketray.media

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.OperationCanceledException
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import java.io.FileNotFoundException
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** Thumbnail loading: which failures mean "no thumbnail", and the size. */
@RunWith(RobolectricTestRunner::class)
class ThumbnailsTest {
    private val resolver: ContentResolver =
        ApplicationProvider.getApplicationContext<Context>().contentResolver
    private val gone = ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri("external_primary"), 4821)

    @Test
    fun `a resolver that throws FileNotFoundException gives null`() {
        // The media provider throws FileNotFoundException, as for a gone video.
        FakeMediaProvider.install(FileNotFoundException("gone"))
        assertThrows(FileNotFoundException::class.java) { resolver.loadThumbnail(gone, android.util.Size(96, 96), null) }
        assertNull(Thumbnails.load(resolver, gone, 96, 96))
        assertNull(Thumbnails.encode(96, 96) { throw FileNotFoundException("gone") })
    }

    @Test
    fun `a resolver that throws SecurityException gives null`() {
        FakeMediaProvider.install(SecurityException("no access"))
        assertNull(Thumbnails.load(resolver, gone, 96, 96))
    }

    @Test
    fun `SecurityException gives null`() {
        assertNull(Thumbnails.encode(96, 96) { throw SecurityException("no access") })
    }

    @Test
    fun `IOException and OperationCanceledException give null`() {
        assertNull(Thumbnails.encode(96, 96) { throw IOException("unreadable") })
        assertNull(Thumbnails.encode(96, 96) { throw OperationCanceledException() })
    }

    @Test
    fun `any other exception goes back to the caller`() {
        assertThrows(IllegalStateException::class.java) {
            Thumbnails.encode(96, 96) { throw IllegalStateException("decoder broke") }
        }
    }

    @Test
    fun `a 1024x768 bitmap with a 256 request has its longer side at most 256`() {
        var asked: android.util.Size? = null
        val bytes =
            Thumbnails.encode(256, 256) { size ->
                asked = size
                Bitmap.createBitmap(1024, 768, Bitmap.Config.ARGB_8888)
            }
        assertEquals(android.util.Size(256, 256), asked)
        assertNotNull(bytes)
        val scaled = Thumbnails.scaleToFit(Bitmap.createBitmap(1024, 768, Bitmap.Config.ARGB_8888), 256)
        assertEquals(256, scaled.width)
        assertEquals(192, scaled.height)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes!!.size, bounds)
        assertEquals("decoded ${bounds.outWidth}x${bounds.outHeight}", 256, bounds.outWidth)
        assertEquals("decoded ${bounds.outWidth}x${bounds.outHeight}", 192, bounds.outHeight)
    }

    @Test
    fun `a small enough bitmap is kept as it is, and the longer request side counts`() {
        val small = Bitmap.createBitmap(100, 80, Bitmap.Config.ARGB_8888)
        assertTrue(Thumbnails.scaleToFit(small, 256) === small)
        val tall = Thumbnails.scaleToFit(Bitmap.createBitmap(300, 600, Bitmap.Config.ARGB_8888), 320)
        assertEquals(160, tall.width)
        assertEquals(320, tall.height)
    }
}
