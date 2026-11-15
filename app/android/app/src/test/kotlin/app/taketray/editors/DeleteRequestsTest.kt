package app.taketray.editors

import android.app.Activity
import android.app.PendingIntent
import android.content.ContentUris
import android.content.Intent
import android.content.IntentSender
import android.provider.MediaStore
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * Android's consent dialog for copies TakeTray may not delete itself (D-121):
 * one request at a time, never left hanging, a late result dropped, and only
 * rows in their copy folder with their name ever in the request.
 */
@RunWith(RobolectricTestRunner::class)
class DeleteRequestsTest {
    private lateinit var activity: Activity
    private lateinit var sender: IntentSender
    private val code = DeleteRequests.REQUEST_CODE

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        sender = PendingIntent.getActivity(activity, 0, Intent("p8.test"), PendingIntent.FLAG_IMMUTABLE).intentSender
        CopyFolderProvider.install()
    }

    private fun timed(body: suspend CoroutineScope.() -> Unit) = runBlocking { withTimeout(5_000) { supervisorScope { body() } } }

    private suspend fun errorCode(block: suspend () -> Unit): String? =
        try {
            block()
            null
        } catch (e: EditorsError) {
            e.code
        }

    // ---------------------------------------------------------- the one slot

    @Test
    fun `run starts the dialog with its request code and answers the result`() =
        timed {
            val requests = DeleteRequests()
            val started = mutableListOf<Pair<IntentSender, Int>>()
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ sender }) { s, c -> started += s to c } }
            assertEquals(listOf(sender to code), started)
            assertTrue(requests.isBusy)
            assertFalse(first.isCompleted)

            assertTrue(requests.onResult(code, Activity.RESULT_OK))
            assertTrue(first.await())
            assertFalse(requests.isBusy)

            val second = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ sender }) { _, _ -> } }
            assertTrue(requests.onResult(code, Activity.RESULT_CANCELED))
            assertFalse("declined", second.await())
        }

    @Test
    fun `nothing to ask starts no dialog and is false`() =
        timed {
            val requests = DeleteRequests()
            var started = 0
            assertFalse(requests.run({ null }) { _, _ -> started++ })
            assertEquals(0, started)
            assertFalse(requests.isBusy)
        }

    @Test
    fun `a second request while one is open fails with busy`() =
        timed {
            val requests = DeleteRequests()
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ sender }) { _, _ -> } }
            assertEquals("busy", errorCode { requests.run({ sender }) { _, _ -> fail("must not start") } })
            assertFalse(first.isCompleted)
            requests.onResult(code, Activity.RESULT_OK)
            assertTrue(first.await())
        }

    @Test
    fun `a second request while the first is still preparing fails with busy`() =
        timed {
            val requests = DeleteRequests()
            val gate = CompletableDeferred<IntentSender?>()
            var started = false
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ gate.await() }) { _, _ -> started = true } }
            assertTrue(requests.isBusy)
            assertEquals("busy", errorCode { requests.run({ sender }) { _, _ -> fail("must not start") } })
            gate.complete(sender)
            while (!started) kotlinx.coroutines.yield()
            requests.onResult(code, Activity.RESULT_OK)
            assertTrue(first.await())
        }

    @Test
    fun `a result for another code is ignored, one with nobody waiting is dropped`() =
        timed {
            val requests = DeleteRequests()
            assertFalse("no caller: dropped", requests.onResult(code, Activity.RESULT_OK))
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ sender }) { _, _ -> } }
            assertFalse(requests.onResult(code + 1, Activity.RESULT_OK))
            assertFalse(first.isCompleted)
            assertTrue(requests.onResult(code, Activity.RESULT_OK))
            assertTrue(first.await())
            assertFalse("a late second result is dropped", requests.onResult(code, Activity.RESULT_OK))
        }

    @Test
    fun `the host going away fails the waiting request`() =
        timed {
            val requests = DeleteRequests()
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ sender }) { _, _ -> } }
            requests.fail(EditorsError("host-gone", "gone"))
            assertEquals("host-gone", errorCode { first.await() })
            assertFalse(requests.isBusy)
        }

    @Test
    fun `the host going away while preparing starts no dialog`() =
        timed {
            val requests = DeleteRequests()
            val gate = CompletableDeferred<IntentSender?>()
            var started = 0
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ gate.await() }) { _, _ -> started++ } }
            requests.fail(EditorsError("host-gone", "gone"))
            gate.complete(sender)
            assertEquals("host-gone", errorCode { first.await() })
            assertEquals(0, started)
            assertFalse(requests.isBusy)
        }

    @Test
    fun `a start that throws frees the slot and passes the error`() =
        timed {
            val requests = DeleteRequests()
            try {
                requests.run({ sender }) { _, _ -> throw IntentSender.SendIntentException() }
                fail("expected the start error")
            } catch (e: IntentSender.SendIntentException) {
                // expected
            }
            assertFalse(requests.isBusy)
            assertFalse(requests.onResult(code, Activity.RESULT_OK))
        }

    @Test
    fun `a prepare that throws frees the slot`() =
        timed {
            val requests = DeleteRequests()
            try {
                requests.run({ throw IllegalStateException("query failed") }) { _, _ -> }
                fail("expected the prepare error")
            } catch (e: IllegalStateException) {
                // expected
            }
            assertFalse(requests.isBusy)
        }

    @Test
    fun `a cancelled caller frees the slot and its late result is dropped`() =
        timed {
            val requests = DeleteRequests()
            val first = async(start = CoroutineStart.UNDISPATCHED) { requests.run({ sender }) { _, _ -> } }
            first.cancel()
            first.join()
            assertFalse(requests.isBusy)
            assertFalse(requests.onResult(code, Activity.RESULT_OK))
        }

    // ---------------------------------------------------------- through the bridge

    private val ours get() = activity.packageName

    private fun itemUri(id: Long) = ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), id)

    private fun ref(
        id: Long,
        folderName: String = "Goa",
        name: String = "a.mp4",
    ) = CopyFileRefMsg(id, folderName, name)

    private val started = mutableListOf<Pair<IntentSender, Int>>()

    private fun impl() = EditorsHostApiImpl(activity, startSender = { _, s, c -> started += s to c })

    @Test
    fun `the request holds only rows in their folder with their name, any owner`() =
        timed {
            CopyFolderProvider.add(1, "Movies/TakeTray/Goa/", "a.mp4", ours)
            CopyFolderProvider.add(2, "Movies/TakeTray/Goa/", "a.mp4", "com.other.app")
            CopyFolderProvider.add(3, "Movies/TakeTray/Goa/", "a.mp4", null)
            CopyFolderProvider.add(4, "Movies/TakeTray Test/", "a.mp4", ours)
            CopyFolderProvider.add(5, "DCIM/Camera/", "a.mp4", "com.other.app")
            CopyFolderProvider.add(6, "Movies/TakeTray/Goa/sub/", "a.mp4", ours)
            CopyFolderProvider.add(7, "Movies/TakeTray/Goa/", "b.mp4", ours)
            val bridge = impl()

            val answer = async(start = CoroutineStart.UNDISPATCHED) { bridge.requestDelete((1L..8L).map { ref(it) }) }
            while (started.isEmpty()) kotlinx.coroutines.delay(5)

            assertEquals(listOf(listOf(itemUri(1), itemUri(2), itemUri(3))), CopyFolderProvider.deleteRequests)
            assertEquals(code, started.single().second)
            assertTrue(bridge.onActivityResult(code, Activity.RESULT_OK, null))
            assertTrue(answer.await())
            assertTrue("the system deletes, never the bridge", CopyFolderProvider.deletes.isEmpty())
        }

    @Test
    fun `refused rows only means no request and false`() =
        timed {
            CopyFolderProvider.add(4, "Movies/TakeTray Test/", "a.mp4", ours)
            CopyFolderProvider.add(5, "DCIM/Camera/", "a.mp4", "com.other.app")
            assertFalse(impl().requestDelete(listOf(ref(4), ref(5), ref(9))))
            assertTrue(CopyFolderProvider.deleteRequests.isEmpty())
            assertTrue(started.isEmpty())
        }

    @Test
    fun `a second request through the bridge is busy, a result with no caller is dropped`() =
        timed {
            CopyFolderProvider.add(1, "Movies/TakeTray/Goa/", "a.mp4", "com.other.app")
            val bridge = impl()
            assertFalse("no caller: dropped", bridge.onActivityResult(code, Activity.RESULT_OK, null))
            val first = async(start = CoroutineStart.UNDISPATCHED) { bridge.requestDelete(listOf(ref(1))) }
            assertEquals("busy", errorCode { bridge.requestDelete(listOf(ref(1))) })
            while (started.isEmpty()) kotlinx.coroutines.delay(5)
            bridge.onActivityResult(code, Activity.RESULT_CANCELED, null)
            assertFalse(first.await())
            assertFalse("another code is not ours", bridge.onActivityResult(code + 1, Activity.RESULT_OK, null))
        }

    @Test
    fun `the activity closing fails the open request with host-gone`() =
        timed {
            CopyFolderProvider.add(1, "Movies/TakeTray/Goa/", "a.mp4", "com.other.app")
            val bridge = impl()
            val first = async(start = CoroutineStart.UNDISPATCHED) { bridge.requestDelete(listOf(ref(1))) }
            while (started.isEmpty()) kotlinx.coroutines.delay(5)
            bridge.onHostGone()
            assertEquals("host-gone", errorCode { first.await() })
            assertEquals("no-activity", errorCode { bridge.requestDelete(listOf(ref(1))) })
        }

    @Test
    fun `the real start opens the system's intent sender for a result`() =
        timed {
            CopyFolderProvider.add(1, "Movies/TakeTray/Goa/", "a.mp4", "com.other.app")
            val bridge = EditorsHostApiImpl(activity)
            val first = async(start = CoroutineStart.UNDISPATCHED) { bridge.requestDelete(listOf(ref(1))) }
            while (shadowOf(activity).lastIntentSenderRequest == null) kotlinx.coroutines.delay(5)
            assertEquals(code, shadowOf(activity).lastIntentSenderRequest.requestCode)
            bridge.onActivityResult(code, Activity.RESULT_OK, null)
            assertTrue(first.await())
        }
}
