package app.taketray

import android.content.ContentValues
import android.content.Context
import android.provider.MediaStore.MediaColumns
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The method channel of the test media (D-77): what Dart sends, what it gets
 * back, and that an error never carries a name or a path (D-10).
 */
@RunWith(RobolectricTestRunner::class)
class TestMediaHandlerTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val own = context.packageName
    private lateinit var handler: TestMediaHandler

    /** Records the one reply. */
    private class Reply : MethodChannel.Result {
        var success: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var notImplemented = false
        var replies = 0

        override fun success(result: Any?) {
            replies++
            success = result
        }

        override fun error(
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?,
        ) {
            replies++
            this.errorCode = errorCode
            this.errorMessage = errorMessage
        }

        override fun notImplemented() {
            replies++
            notImplemented = true
        }
    }

    @Before
    fun setUp() {
        FakeVideoStore.install(callerPackage = own)
        // Unconfined: the work runs inside onMethodCall, so the test sees the reply at once.
        handler =
            TestMediaHandler(
                TestMedia(context.contentResolver, own),
                scope = CoroutineScope(Dispatchers.Unconfined),
                io = Dispatchers.Unconfined,
            )
    }

    private fun call(
        method: String,
        arguments: Any? = null,
    ): Reply = Reply().also { handler.onMethodCall(MethodCall(method, arguments), it) }

    @Test
    fun `the channel is the one Dart uses`() {
        assertEquals("app.taketray/test_media", TestMediaHandler.CHANNEL)
    }

    @Test
    fun `insertVideo answers the volume and the id`() {
        val reply = call("insertVideo", mapOf("bytes" to byteArrayOf(1, 2, 3), "displayName" to "a.mp4"))

        assertEquals(1, reply.replies)
        @Suppress("UNCHECKED_CAST")
        val answer = reply.success as Map<String, Any?>
        assertEquals("external_primary", answer["volumeName"])
        val id = answer["mediaStoreId"] as Long
        assertTrue(FakeVideoStore.rows.containsKey(id))
    }

    @Test
    fun `insertVideo puts the video in the Sent sub-folder only when inWhatsAppSent is true`() {
        val args = mapOf("bytes" to byteArrayOf(1, 2, 3), "displayName" to "a.mp4")
        val plain = call("insertVideo", args)
        val sent = call("insertVideo", args + ("inWhatsAppSent" to true))
        val off = call("insertVideo", args + ("inWhatsAppSent" to false))

        @Suppress("UNCHECKED_CAST")
        fun pathOf(reply: Reply) = FakeVideoStore.rows.getValue((reply.success as Map<String, Any?>)["mediaStoreId"] as Long).path
        assertEquals("Movies/TakeTray Test/", pathOf(plain))
        assertEquals("Movies/TakeTray Test/WhatsApp/Sent/", pathOf(sent))
        assertEquals("Movies/TakeTray Test/", pathOf(off))
    }

    @Test
    fun `deleteVideo accepts an int or a long id and answers true, then false`() {
        val made = TestMedia(context.contentResolver, own).insertVideo(byteArrayOf(1), "b.mp4")

        val first = call("deleteVideo", mapOf("mediaStoreId" to made.mediaStoreId.toInt()))
        val second = call("deleteVideo", mapOf("mediaStoreId" to made.mediaStoreId))

        assertEquals(true, first.success)
        assertEquals(false, second.success)
        assertTrue(FakeVideoStore.rows.isEmpty())
    }

    @Test
    fun `deleteVideo of a row that is not ours answers refused and deletes nothing`() {
        val row =
            FakeVideoStore.add(
                ContentValues().apply {
                    put(MediaColumns.RELATIVE_PATH, "DCIM/Camera/")
                    put(MediaColumns.IS_PENDING, 0)
                },
                own,
            )

        val reply = call("deleteVideo", mapOf("mediaStoreId" to row.id))

        assertEquals("refused", reply.errorCode)
        assertTrue(FakeVideoStore.rows.containsKey(row.id))
        assertFalse(FakeVideoStore.events.contains("delete"))
        assertFalse("the error does not name the folder", reply.errorMessage!!.contains("DCIM"))
    }

    @Test
    fun `deleteLeftovers answers the counts`() {
        val media = TestMedia(context.contentResolver, own)
        media.insertVideo(byteArrayOf(1), "c.mp4")
        media.insertVideo(byteArrayOf(2), "d.mp4")

        val reply = call("deleteLeftovers")

        assertEquals(mapOf("deleted" to 2, "refused" to 0), reply.success)
        assertTrue(FakeVideoStore.rows.isEmpty())
    }

    @Test
    fun `missing arguments are an error and touch nothing`() {
        for ((method, args) in listOf(
            "insertVideo" to null,
            "insertVideo" to mapOf("displayName" to "a.mp4"),
            "insertVideo" to mapOf("bytes" to byteArrayOf(1)),
            "deleteVideo" to null,
            "deleteVideo" to mapOf("mediaStoreId" to "12"),
        )) {
            val reply = call(method, args)
            assertEquals("$method $args", "bad-arguments", reply.errorCode)
        }
        assertTrue(FakeVideoStore.events.isEmpty())
    }

    @Test
    fun `an unknown method is not implemented`() {
        val reply = call("format")

        assertTrue(reply.notImplemented)
        assertNull(reply.errorCode)
    }

    @Test
    fun `an error names the method and the exception class, never the message, the name or the path`() {
        FakeVideoStore.insertError = IllegalStateException("secret-clip-name.mp4 at Movies/TakeTray Test/")

        val reply = call("insertVideo", mapOf("bytes" to byteArrayOf(1), "displayName" to "secret-clip-name.mp4"))

        assertEquals("native-error", reply.errorCode)
        assertEquals("insertVideo failed: IllegalStateException", reply.errorMessage)
        assertNotNull(reply.errorMessage)
        assertFalse(reply.errorMessage!!.contains("secret"))
        assertFalse(reply.errorMessage!!.contains("Movies"))
        assertEquals(1, reply.replies)
    }
}
