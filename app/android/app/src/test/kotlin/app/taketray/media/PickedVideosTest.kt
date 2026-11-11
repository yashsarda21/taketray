package app.taketray.media

import android.app.Activity
import android.content.ClipData
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The photo picker: which intent each Android level gets, how its result
 * (many, one, cancelled, with nobody waiting) is read, the facts read for each
 * picked video, and the three calls on saved addresses (readable, persisted,
 * release). A ContentResolver subclass records every binder call, so no phone
 * is needed.
 */
@RunWith(RobolectricTestRunner::class)
class PickedVideosTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val limit = { 100 }
    private val noLimit: () -> Int = { throw AssertionError("the picker limit must not be read here") }

    // ---- intent ----

    private fun assertPicker(intent: Intent) {
        assertEquals(MediaStore.ACTION_PICK_IMAGES, intent.action)
        assertEquals("video/*", intent.type)
        assertEquals(100, intent.getIntExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, -1))
    }

    private fun assertDocuments(intent: Intent) {
        assertEquals(Intent.ACTION_OPEN_DOCUMENT, intent.action)
        assertEquals("video/*", intent.type)
        assertTrue(intent.getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, false))
        assertTrue(intent.hasCategory(Intent.CATEGORY_OPENABLE))
        assertTrue(intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
        assertTrue(intent.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0)
        assertFalse(intent.hasExtra(MediaStore.EXTRA_PICK_IMAGES_MAX))
    }

    @Test
    fun `API 33 and later use the photo picker whatever the extension level`() {
        for (sdk in listOf(33, 34, 35, 36)) {
            for (ext in listOf(0, 1, 2, 5)) assertPicker(PickedVideos.intent(sdk, ext, limit))
        }
    }

    @Test
    fun `API 30 to 32 use the photo picker with R extension 2 or more`() {
        for (sdk in 30..32) {
            for (ext in listOf(2, 3, 10)) assertPicker(PickedVideos.intent(sdk, ext, limit))
        }
    }

    @Test
    fun `API 30 to 32 with R extension 0 or 1 use the document picker`() {
        for (sdk in 30..32) {
            for (ext in listOf(0, 1)) assertDocuments(PickedVideos.intent(sdk, ext, noLimit))
        }
    }

    @Test
    fun `below API 30 uses the document picker even with a high extension level`() {
        assertDocuments(PickedVideos.intent(29, 9, noLimit))
    }

    @Test
    fun `the picker asks for the system's maximum number of videos`() {
        val intent = PickedVideos.intent(34, 0) { 37 }
        assertEquals(37, intent.getIntExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, -1))
    }

    // ---- results ----

    private fun uri(n: Int): Uri = Uri.parse("content://media/picker/0/com.android.providers.media.photopicker/media/$n")

    private fun clip(vararg uris: Uri): Intent =
        Intent().apply {
            val first = ClipData.newRawUri("", uris.first())
            for (u in uris.drop(1)) first.addItem(ClipData.Item(u))
            clipData = first
        }

    private fun <T> timed(body: suspend kotlinx.coroutines.CoroutineScope.() -> T): T =
        runBlocking { withTimeout(5_000) { supervisorScope { body() } } }

    @Test
    fun `a clipData of many comes back in order`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            assertTrue(picks.isWaiting)
            assertTrue(picks.onResult(7, Activity.RESULT_OK, clip(uri(3), uri(1), uri(2))))
            assertEquals(listOf(uri(3), uri(1), uri(2)), waiting.await())
            assertFalse(picks.isWaiting)
        }

    @Test
    fun `a single data uri comes back as one`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            assertTrue(picks.onResult(7, Activity.RESULT_OK, Intent().setData(uri(9))))
            assertEquals(listOf(uri(9)), waiting.await())
        }

    @Test
    fun `data that repeats a clipData uri is not counted twice`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            picks.onResult(7, Activity.RESULT_OK, clip(uri(1), uri(2)).setData(uri(1)))
            assertEquals(listOf(uri(1), uri(2)), waiting.await())
        }

    @Test
    fun `a clipData item with no uri is skipped`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            val data = clip(uri(1))
            data.clipData!!.addItem(ClipData.Item("just text"))
            data.clipData!!.addItem(ClipData.Item(uri(2)))
            picks.onResult(7, Activity.RESULT_OK, data)
            assertEquals(listOf(uri(1), uri(2)), waiting.await())
        }

    @Test
    fun `cancelling gives an empty list, even when the intent carries data`() =
        timed {
            val picks = PickedVideos(7)
            for (data in listOf<Intent?>(null, Intent(), clip(uri(1)))) {
                val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
                assertTrue(picks.onResult(7, Activity.RESULT_CANCELED, data))
                assertEquals(emptyList<Uri>(), waiting.await())
            }
        }

    @Test
    fun `OK with nothing picked is an empty list`() =
        timed {
            val picks = PickedVideos(7)
            for (data in listOf<Intent?>(null, Intent())) {
                val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
                assertTrue(picks.onResult(7, Activity.RESULT_OK, data))
                assertEquals(emptyList<Uri>(), waiting.await())
            }
        }

    @Test
    fun `a result for another request code is ignored and the pick keeps waiting`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            assertFalse(picks.onResult(8, Activity.RESULT_OK, clip(uri(1))))
            assertTrue(picks.isWaiting)
            assertFalse(waiting.isCompleted)
            assertTrue(picks.onResult(7, Activity.RESULT_OK, clip(uri(2))))
            assertEquals(listOf(uri(2)), waiting.await())
        }

    @Test
    fun `a result with nobody waiting is dropped silently and never answers a later pick`() =
        timed {
            val picks = PickedVideos(7)
            // The process died while the picker was open: the new process gets the result.
            assertFalse(picks.onResult(7, Activity.RESULT_OK, clip(uri(1), uri(2))))
            assertFalse(picks.isWaiting)

            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            assertFalse(waiting.isCompleted)
            picks.onResult(7, Activity.RESULT_OK, clip(uri(3)))
            assertEquals(listOf(uri(3)), waiting.await())
            // A second delivery of the same result is dropped as well.
            assertFalse(picks.onResult(7, Activity.RESULT_OK, clip(uri(3))))
        }

    @Test
    fun `starting the picker fails and frees the slot`() =
        timed {
            val picks = PickedVideos(7)
            try {
                picks.await { throw android.content.ActivityNotFoundException() }
                fail("expected the start to fail")
            } catch (e: android.content.ActivityNotFoundException) {
                // expected
            }
            assertFalse(picks.isWaiting)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            picks.onResult(7, Activity.RESULT_OK, clip(uri(1)))
            assertEquals(listOf(uri(1)), waiting.await())
        }

    @Test
    fun `fail wakes a waiting pick with the error`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            val error = IllegalStateException("host gone")
            picks.fail(error)
            assertFalse(picks.isWaiting)
            try {
                waiting.await()
                fail("expected the error")
            } catch (e: IllegalStateException) {
                // Coroutines may hand back a copy of the exception, with the same message.
                assertEquals("host gone", e.message)
            }
            picks.fail(error) // nothing waiting: harmless
        }

    @Test
    fun `a cancelled pick frees the slot and its late result is dropped`() =
        timed {
            val picks = PickedVideos(7)
            val waiting = async(start = CoroutineStart.UNDISPATCHED) { picks.await {} }
            waiting.cancelAndJoin()
            assertFalse(picks.isWaiting)
            assertFalse(picks.onResult(7, Activity.RESULT_OK, clip(uri(1))))
        }

    // ---- facts ----
    //
    // Queries go through the real resolver to FakeMediaProvider (the "media"
    // authority, which also serves content://media/picker/...); the saved
    // grants go through a recording UriGrants.

    private val resolver: ContentResolver = context.contentResolver
    private val opened = mutableListOf<Cursor>()
    private val queried = mutableListOf<FakeMediaProvider.Query>()

    private fun provider(answer: (Uri) -> Cursor?) {
        opened.clear()
        queried.clear()
        FakeMediaProvider.install(answer = { q ->
            queried += q
            answer(q.uri)?.also { opened += it }
        })
    }

    private class FakeGrants : UriGrants {
        var takeError: (Uri) -> Throwable? = { null }
        var releaseError: (Uri) -> Throwable? = { null }
        var saved: List<SavedGrant> = emptyList()
        var savedError: Throwable? = null
        val taken = mutableListOf<Pair<Uri, Int>>()
        val released = mutableListOf<Pair<Uri, Int>>()

        override fun take(
            uri: Uri,
            flags: Int,
        ) {
            taken += uri to flags
            takeError(uri)?.let { throw it }
        }

        override fun release(
            uri: Uri,
            flags: Int,
        ) {
            released += uri to flags
            releaseError(uri)?.let { throw it }
        }

        override fun saved(): List<SavedGrant> {
            savedError?.let { throw it }
            return saved
        }
    }

    private fun factsCursor(columns: Map<String, Any?>): MatrixCursor =
        MatrixCursor(columns.keys.toTypedArray()).apply { addRow(columns.values.toTypedArray()) }

    @Test
    fun `facts are read from the MediaColumns of a media uri`() {
        provider {
            factsCursor(
                linkedMapOf(
                    MediaColumns.DISPLAY_NAME to "VID_1.mp4",
                    MediaColumns.SIZE to 123_456_789L,
                    MediaColumns.DURATION to 15_000L,
                    MediaColumns.DATE_TAKEN to 1_780_000_000_123L,
                    MediaColumns.WIDTH to 1920L,
                    MediaColumns.HEIGHT to 1080L,
                    MediaColumns.MIME_TYPE to "video/mp4",
                ),
            )
        }
        val msg = PickedVideos.describe(resolver, FakeGrants(), listOf(uri(1))).single()
        assertEquals(
            PickedVideoMsg(
                uri = uri(1).toString(),
                sizeBytes = 123_456_789,
                durationMs = 15_000,
                dateTakenMs = 1_780_000_000_123,
                displayName = "VID_1.mp4",
                width = 1920,
                height = 1080,
                mimeType = "video/mp4",
                persisted = true,
            ),
            msg,
        )
        assertEquals(uri(1), queried.single().uri)
    }

    @Test
    fun `facts are read from the picker's own columns`() {
        // PickerMediaColumns uses the same names; DURATION_MILLIS is "duration".
        assertEquals(MediaStore.PickerMediaColumns.DURATION_MILLIS, MediaColumns.DURATION)
        assertEquals(MediaStore.PickerMediaColumns.DATE_TAKEN, MediaColumns.DATE_TAKEN)
        assertEquals(MediaStore.PickerMediaColumns.DISPLAY_NAME, MediaColumns.DISPLAY_NAME)
        assertEquals(MediaStore.PickerMediaColumns.SIZE, MediaColumns.SIZE)
        assertEquals(MediaStore.PickerMediaColumns.MIME_TYPE, MediaColumns.MIME_TYPE)
        assertEquals(MediaStore.PickerMediaColumns.WIDTH, MediaColumns.WIDTH)
        assertEquals(MediaStore.PickerMediaColumns.HEIGHT, MediaColumns.HEIGHT)
        provider {
            factsCursor(
                linkedMapOf(
                    MediaStore.PickerMediaColumns.DISPLAY_NAME to "a.mp4",
                    MediaStore.PickerMediaColumns.SIZE to 9L,
                    MediaStore.PickerMediaColumns.DURATION_MILLIS to 4_000L,
                    MediaStore.PickerMediaColumns.DATE_TAKEN to 5L,
                ),
            )
        }
        val msg = PickedVideos.describe(resolver, FakeGrants(), listOf(uri(1))).single()
        assertEquals(9L, msg.sizeBytes)
        assertEquals(4_000L, msg.durationMs)
        assertEquals(5L, msg.dateTakenMs)
        assertNull(msg.width)
        assertNull(msg.height)
        assertNull(msg.mimeType)
    }

    @Test
    fun `a missing size or name still returns the row`() {
        provider {
            factsCursor(linkedMapOf(MediaColumns.DISPLAY_NAME to null, MediaColumns.SIZE to null, MediaColumns.DURATION to null))
        }
        val msg = PickedVideos.describe(resolver, FakeGrants(), listOf(uri(4))).single()
        assertEquals(uri(4).toString(), msg.uri)
        assertEquals(0L, msg.sizeBytes)
        assertEquals("", msg.displayName)
        assertNull(msg.durationMs)
        assertNull(msg.dateTakenMs)
    }

    @Test
    fun `a cursor without those columns, no row, no cursor or no access still returns the row`() {
        val answers: List<(Uri) -> Cursor?> =
            listOf(
                { MatrixCursor(arrayOf("something_else")).apply { addRow(arrayOf<Any?>("x")) } },
                { MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME)) },
                { null },
                { throw SecurityException("no grant") },
            )
        for (answer in answers) {
            provider(answer)
            val msg = PickedVideos.describe(resolver, FakeGrants(), listOf(uri(5))).single()
            assertEquals(PickedVideoMsg(uri(5).toString(), 0, null, null, "", null, null, null, true), msg)
        }
    }

    @Test
    fun `any other failure reading facts fails the whole call`() {
        provider { throw IllegalStateException("provider broke") }
        assertThrows(IllegalStateException::class.java) { PickedVideos.describe(resolver, FakeGrants(), listOf(uri(1))) }
    }

    @Test
    fun `every picked uri is made persistable with read access, in order`() {
        provider { null }
        val grants = FakeGrants()
        val msgs = PickedVideos.describe(resolver, grants, listOf(uri(1), uri(2), uri(3)))
        assertEquals(listOf(uri(1), uri(2), uri(3)), grants.taken.map { it.first })
        assertTrue(grants.taken.all { it.second == Intent.FLAG_GRANT_READ_URI_PERMISSION })
        assertEquals(listOf(uri(1), uri(2), uri(3)).map { it.toString() }, msgs.map { it.uri })
        assertEquals(listOf(true, true, true), msgs.map { it.persisted })
    }

    @Test
    fun `a uri whose persist throws is not persisted, and the others are`() {
        for (error in listOf<Throwable>(SecurityException("no persistable grant"), IllegalArgumentException("bad"))) {
            provider { factsCursor(linkedMapOf(MediaColumns.DISPLAY_NAME to "n", MediaColumns.SIZE to 3L)) }
            val grants = FakeGrants()
            grants.takeError = { if (it == uri(2)) error else null }
            val msgs = PickedVideos.describe(resolver, grants, listOf(uri(1), uri(2), uri(3)))
            assertEquals(listOf(true, false, true), msgs.map { it.persisted })
            // The row is still there with its facts, and the third one was still tried.
            assertEquals(listOf("n", "n", "n"), msgs.map { it.displayName })
            assertEquals(3, grants.taken.size)
        }
    }

    @Test
    fun `no uris means no binder calls`() {
        provider { null }
        val grants = FakeGrants()
        assertEquals(emptyList<PickedVideoMsg>(), PickedVideos.describe(resolver, grants, emptyList()))
        assertTrue(queried.isEmpty() && grants.taken.isEmpty())
    }

    @Test
    fun `cursors are closed`() {
        provider { factsCursor(linkedMapOf(MediaColumns.DISPLAY_NAME to "a")) }
        PickedVideos.describe(resolver, FakeGrants(), listOf(uri(1), uri(2)))
        assertTrue(opened.size == 2 && opened.all { it.isClosed })
    }

    // ---- readableUris ----

    private val oneRow: (Uri) -> Cursor? = { MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME)).apply { addRow(arrayOf<Any?>("a")) } }

    @Test
    fun `readable keeps a uri that answers a row, in order`() {
        provider(oneRow)
        val asked = listOf(uri(3), uri(1), uri(2)).map { it.toString() }
        assertEquals(asked, PickedVideos.readable(resolver, asked))
        assertTrue(opened.size == 3 && opened.all { it.isClosed })
    }

    @Test
    fun `readable drops a uri whose query throws SecurityException`() {
        provider { if (it == uri(2)) throw SecurityException("grant lost") else oneRow(it) }
        assertEquals(
            listOf(uri(1), uri(3)).map { it.toString() },
            PickedVideos.readable(resolver, listOf(uri(1), uri(2), uri(3)).map { it.toString() }),
        )
    }

    @Test
    fun `readable drops a uri whose cursor has no row`() {
        provider {
            when (it) {
                uri(1) -> MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME))
                else -> oneRow(it)
            }
        }
        assertEquals(
            listOf(uri(2), uri(3)).map { it.toString() },
            PickedVideos.readable(resolver, listOf(uri(1), uri(2), uri(3)).map { it.toString() }),
        )
        assertTrue(opened.all { it.isClosed })
    }

    @Test
    fun `readable throws on a null cursor, which is a failed read and not a gone video`() {
        provider { null }
        val error =
            assertThrows(FlutterError::class.java) {
                PickedVideos.readable(resolver, listOf(uri(1).toString()))
            }
        assertEquals("no-cursor", error.code)
        // The error carries no address (D-10).
        assertFalse(error.toString().contains("content://"))
    }

    @Test
    fun `readable throws when any uri in a mixed list answers a null cursor, never a partial answer`() {
        // The provider's process died while the list was read: nothing may be reported gone.
        for (nullAt in listOf(1, 2, 3)) {
            provider {
                when (it) {
                    uri(nullAt) -> null
                    uri(2) -> throw SecurityException("grant lost")
                    uri(3) -> MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME))
                    else -> oneRow(it)
                }
            }
            val error =
                assertThrows(FlutterError::class.java) {
                    PickedVideos.readable(resolver, listOf(uri(1), uri(2), uri(3), uri(4)).map { it.toString() })
                }
            assertEquals("null at $nullAt", "no-cursor", error.code)
        }
    }

    @Test
    fun `readable throws when the call itself fails, so failed is never read as gone`() {
        for (error in listOf<Throwable>(IllegalStateException("provider died"), IllegalArgumentException("x"), RuntimeException("y"))) {
            provider { if (it == uri(2)) throw error else oneRow(it) }
            val thrown =
                assertThrows(Throwable::class.java) {
                    PickedVideos.readable(resolver, listOf(uri(1), uri(2), uri(3)).map { it.toString() })
                }
            assertSame(error, thrown)
        }
    }

    @Test
    fun `readable of nothing asks nothing`() {
        provider(oneRow)
        assertEquals(emptyList<String>(), PickedVideos.readable(resolver, emptyList()))
        assertTrue(queried.isEmpty())
    }

    @Test
    fun `readable asks a light projection`() {
        provider(oneRow)
        PickedVideos.readable(resolver, listOf(uri(1).toString()))
        assertEquals(listOf(MediaColumns.DISPLAY_NAME), queried.single().projection)
    }

    // ---- persistedUris ----

    @Test
    fun `persisted lists the uris with a read grant`() {
        val grants = FakeGrants()
        grants.saved = listOf(SavedGrant(uri(1), read = true), SavedGrant(uri(2), read = false), SavedGrant(uri(3), read = true))
        assertEquals(listOf(uri(1), uri(3)).map { it.toString() }, PickedVideos.persisted(grants))
    }

    @Test
    fun `persisted with no grants is empty, and a failure throws`() {
        val grants = FakeGrants()
        assertEquals(emptyList<String>(), PickedVideos.persisted(grants))
        grants.savedError = IllegalStateException("system down")
        assertThrows(IllegalStateException::class.java) { PickedVideos.persisted(grants) }
    }

    // ---- releaseUris ----

    @Test
    fun `release gives up only the uris asked for, with read access`() {
        val grants = FakeGrants()
        val failures = PickedVideos.release(grants, listOf(uri(2), uri(5)).map { it.toString() })
        assertEquals(0, failures)
        assertEquals(listOf(uri(2), uri(5)), grants.released.map { it.first })
        assertTrue(grants.released.all { it.second == Intent.FLAG_GRANT_READ_URI_PERMISSION })
    }

    @Test
    fun `one failing release does not stop the rest, and the failures are counted`() {
        for (error in listOf<Throwable>(SecurityException("no grant"), IllegalStateException("x"), RuntimeException("y"))) {
            val grants = FakeGrants()
            grants.releaseError = { if (it == uri(1) || it == uri(3)) error else null }
            val failures = PickedVideos.release(grants, listOf(uri(1), uri(2), uri(3), uri(4)).map { it.toString() })
            assertEquals(2, failures)
            assertEquals(listOf(uri(1), uri(2), uri(3), uri(4)), grants.released.map { it.first })
        }
    }

    @Test
    fun `release of nothing does nothing`() {
        val grants = FakeGrants()
        assertEquals(0, PickedVideos.release(grants, emptyList()))
        assertTrue(grants.released.isEmpty())
    }
}
