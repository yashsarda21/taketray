package app.taketray

import android.content.ContentResolver
import android.content.Context
import android.provider.MediaStore.MediaColumns
import androidx.test.core.app.ApplicationProvider
import java.io.FileNotFoundException
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Putting test videos into MediaStore and taking them out again (D-77), on a
 * small in-memory stand-in for the media provider. What only the real provider
 * can show (that a pending row is published, that deleting an own file needs no
 * dialog, the owner column) is proven on the phone by the Patrol tests.
 */
@RunWith(RobolectricTestRunner::class)
class TestMediaTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val resolver: ContentResolver = context.contentResolver
    private val own = context.packageName
    private val folder = "Movies/TakeTray Test/"
    private lateinit var media: TestMedia

    @Before
    fun setUp() {
        FakeVideoStore.install(callerPackage = own)
        media = TestMedia(resolver, own)
    }

    private fun seed(
        path: String?,
        owner: String?,
        pending: Boolean = false,
    ): FakeVideoStore.Row =
        FakeVideoStore.add(
            android.content.ContentValues().apply {
                put(MediaColumns.DISPLAY_NAME, "seed.mp4")
                if (path != null) put(MediaColumns.RELATIVE_PATH, path)
                put(MediaColumns.IS_PENDING, if (pending) 1 else 0)
            },
            owner,
        )

    // ---- insertVideo ----

    @Test
    fun `insert makes a pending row in the test folder, writes the bytes, then publishes it`() {
        val bytes = byteArrayOf(1, 2, 3, 4, 5)
        val made = media.insertVideo(bytes, "clip-a.mp4")

        assertEquals(listOf("insert", "write", "update"), FakeVideoStore.events)
        assertEquals("external_primary", made.volumeName)
        val row = FakeVideoStore.rows.getValue(made.mediaStoreId)
        assertEquals(folder, row.path)
        assertEquals("clip-a.mp4", row.values.getAsString(MediaColumns.DISPLAY_NAME))
        assertEquals("video/mp4", row.values.getAsString(MediaColumns.MIME_TYPE))
        assertEquals("published, not pending", 0, row.values.getAsInteger(MediaColumns.IS_PENDING))
        assertEquals(own, row.owner)
        assertArrayEquals(bytes, row.file.readBytes())
    }

    @Test
    fun `the row is still pending when the bytes are written`() {
        // The row is only published after the write: a scan must not see half a file.
        media.insertVideo(byteArrayOf(9), "clip-b.mp4")

        assertEquals(true, FakeVideoStore.pendingAtWrite)
        assertEquals(0, FakeVideoStore.rows.values.single().values.getAsInteger(MediaColumns.IS_PENDING))
    }

    @Test
    fun `a failure while writing deletes the half-made row and goes on`() {
        FakeVideoStore.writeError = FileNotFoundException("disk full")

        assertThrows(FileNotFoundException::class.java) { media.insertVideo(byteArrayOf(1), "clip-c.mp4") }

        assertTrue("the half-made row is gone", FakeVideoStore.rows.isEmpty())
        assertTrue(FakeVideoStore.events.contains("delete"))
    }

    @Test
    fun `a provider that makes no row is an error and leaves nothing`() {
        FakeVideoStore.insertReturnsNull = true

        assertThrows(IOException::class.java) { media.insertVideo(byteArrayOf(1), "clip-d.mp4") }

        assertTrue(FakeVideoStore.rows.isEmpty())
        assertEquals(listOf("insert"), FakeVideoStore.events)
    }

    @Test
    fun `empty bytes and a name with a slash are refused before anything is inserted`() {
        assertThrows(IllegalArgumentException::class.java) { media.insertVideo(ByteArray(0), "x.mp4") }
        assertThrows(IllegalArgumentException::class.java) { media.insertVideo(byteArrayOf(1), "../x.mp4") }
        assertThrows(IllegalArgumentException::class.java) { media.insertVideo(byteArrayOf(1), " ") }
        assertTrue(FakeVideoStore.events.isEmpty())
    }

    // ---- deleteVideo ----

    @Test
    fun `an own test video is deleted`() {
        val made = media.insertVideo(byteArrayOf(1), "clip-e.mp4")

        assertTrue(media.deleteVideo(made.mediaStoreId))

        assertTrue(FakeVideoStore.rows.isEmpty())
    }

    @Test
    fun `deleting a row that is gone is not an error`() {
        val made = media.insertVideo(byteArrayOf(1), "clip-f.mp4")
        assertTrue(media.deleteVideo(made.mediaStoreId))

        assertFalse(media.deleteVideo(made.mediaStoreId))
        assertFalse(media.deleteVideo(987654321L))
    }

    @Test
    fun `a pending own row in the test folder can be deleted`() {
        val row = seed(folder, own, pending = true)

        assertTrue("pending rows are included in the lookup", media.deleteVideo(row.id))

        assertTrue(FakeVideoStore.rows.isEmpty())
    }

    @Test
    fun `a row owned by another app is refused and nothing is deleted`() {
        val row = seed(folder, "com.sec.android.gallery3d")

        assertThrows(TestMediaRefused::class.java) { media.deleteVideo(row.id) }

        assertTrue(FakeVideoStore.rows.containsKey(row.id))
        assertFalse("no delete was sent", FakeVideoStore.events.contains("delete"))
    }

    @Test
    fun `a row with no owner is refused`() {
        val row = seed(folder, null)

        assertThrows(TestMediaRefused::class.java) { media.deleteVideo(row.id) }

        assertTrue(FakeVideoStore.rows.containsKey(row.id))
        assertFalse(FakeVideoStore.events.contains("delete"))
    }

    @Test
    fun `the release app's file in the test folder is refused`() {
        val row = seed(folder, "app.taketray")

        assertThrows(TestMediaRefused::class.java) { media.deleteVideo(row.id) }

        assertTrue(FakeVideoStore.rows.containsKey(row.id))
    }

    @Test
    fun `an own file outside the test folder is refused`() {
        for (path in listOf("DCIM/Camera/", "Movies/", "movies/taketray test/", "Movies/TakeTray Test/sub/", null)) {
            val row = seed(path, own)

            assertThrows("folder '$path'", TestMediaRefused::class.java) { media.deleteVideo(row.id) }

            assertTrue("folder '$path'", FakeVideoStore.rows.containsKey(row.id))
        }
        assertFalse(FakeVideoStore.events.contains("delete"))
    }

    // ---- deleteLeftovers ----

    @Test
    fun `leftovers removes this app's rows in the test folder, pending ones too, and leaves the rest`() {
        val published = seed(folder, own)
        val pending = seed(folder, own, pending = true)
        val foreign = seed(folder, "com.sec.android.gallery3d")
        val elsewhere = seed("DCIM/Camera/", own)

        val done = media.deleteLeftovers()

        assertEquals(2, done.deleted)
        assertEquals("the foreign row in the folder is counted, not deleted", 1, done.refused)
        assertEquals(setOf(foreign.id, elsewhere.id), FakeVideoStore.rows.keys)
        assertFalse(FakeVideoStore.rows.containsKey(published.id))
        assertFalse(FakeVideoStore.rows.containsKey(pending.id))
    }

    @Test
    fun `leftovers with nothing to do deletes nothing`() {
        val done = media.deleteLeftovers()

        assertEquals(TestMedia.Cleanup(0, 0), done)
        assertFalse(FakeVideoStore.events.contains("delete"))
    }
}
