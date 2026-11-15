package app.taketray.editors

import android.app.Activity
import android.os.Looper
import android.view.WindowManager
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The Pigeon side of copying (D-122): messages map both ways, errors carry
 * a code and a class name only, events reach Dart on the main thread, and
 * the job outlives the activity that started it.
 */
@RunWith(RobolectricTestRunner::class)
class CopyHostApiImplTest {
    private val store = FakeCopyStore()
    private val executor = Executors.newSingleThreadExecutor()

    /** Default posting: events go through the main looper, as on the phone. */
    private val engine =
        CopyEngine(store, io = executor.asCoroutineDispatcher(), clock = { 0L }, wallClock = { WALL_MS }, chunkBytes = 1024)
    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

    private val sent: MutableList<Pair<CopyJobMsg, Boolean>> = Collections.synchronizedList(mutableListOf())

    private fun impl(
        host: Activity? = activity,
        into: MutableList<Pair<CopyJobMsg, Boolean>> = sent,
    ) = CopyHostApiImpl(host, engine, send = { into += it to (Looper.myLooper() == Looper.getMainLooper()) })

    /** Every latch a test made: released after it, so a failing test never leaves the worker waiting. */
    private val latches = mutableListOf<CountDownLatch>()

    private fun latch() = CountDownLatch(1).also { latches += it }

    @After
    fun tearDown() {
        latches.forEach { it.countDown() }
        executor.shutdownNow()
    }

    private fun source(id: Long) = CopySourceMsg("external_primary", id, null, "video/mp4")

    private fun item(
        id: Long,
        size: Int = 3000,
        onRead: ((Long) -> Unit)? = null,
    ): CopyItemMsg {
        store.sources["external_primary:$id"] = FakeCopyStore.Source(ByteArray(size), onRead = onRead)
        return CopyItemMsg(id, source(id), "$id.mp4", size.toLong())
    }

    private fun request(
        vararg items: CopyItemMsg,
        jobId: String = "job-1",
    ) = CopyRequestMsg(jobId, 7, FOLDER, items.toList())

    private fun settle() {
        runBlocking { withTimeout(10_000) { engine.awaitIdle() } }
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun code(block: () -> Unit): CopyApiError {
        try {
            block()
        } catch (e: CopyApiError) {
            return e
        }
        fail("expected a CopyApiError")
        throw AssertionError()
    }

    @Test
    fun `start and current map every field`() {
        val api = impl()
        store.sources["picker"] = FakeCopyStore.Source(ByteArray(10), openError = SecurityException("gone"))
        val picked = CopyItemMsg(2, CopySourceMsg(null, null, "picker", "video/quicktime"), "2.mov", 10)
        api.start(request(item(1), picked))
        settle()
        assertTrue(store.log().containsAll(listOf("open external_primary:1", "open picker", "insert 1.mp4", "insert 2.mov")))

        val job = api.current()!!
        assertEquals("job-1", job.jobId)
        assertEquals(7L, job.reelId)
        assertEquals(FOLDER, job.folderName)
        assertEquals(CopyStateMsg.FINISHED, job.state)
        assertEquals(2L, job.total)
        assertEquals(2L, job.done)
        assertEquals(3010L, job.bytesTotal)
        assertEquals(3010L, job.bytesDone)
        assertEquals(listOf(CopiedFileMsg(1, 100, "1.mp4", 3000, WALL_MS)), job.copied)
        assertEquals(listOf(2L), job.failedClipIds)
        assertEquals(emptyList<CopiedFileMsg>(), job.undeleted)
    }

    @Test
    fun `every state maps to its message`() {
        val pairs =
            mapOf(
                CopyState.RUNNING to CopyStateMsg.RUNNING,
                CopyState.FINISHED to CopyStateMsg.FINISHED,
                CopyState.SPACE_FULL to CopyStateMsg.SPACE_FULL,
                CopyState.INTERRUPTED to CopyStateMsg.INTERRUPTED,
                CopyState.CANCELLED to CopyStateMsg.CANCELLED,
            )
        for ((state, msg) in pairs) assertEquals(msg, stateMsg(state))
    }

    @Test
    fun `busy, a bad request and an unexpected failure arrive as codes without names`() {
        val api = impl()
        api.start(request(item(1)))
        settle()
        assertEquals("busy", code { api.start(request(item(2), jobId = "job-2")) }.code)
        api.clear("job-1")

        val bad = code { api.start(CopyRequestMsg("job-3", 7, "../DCIM", listOf(item(3)))) }
        assertEquals("bad-request", bad.code)
        assertFalse(bad.message!!.contains("DCIM"))

        val bad2 = code { runBlocking { withTimeout(10_000) { api.ownRowsIn("a/secret") } } }
        assertEquals("bad-request", bad2.code)
        assertFalse(bad2.message!!.contains("secret"))

        // A store that throws with a path in its message: only the class name reaches Dart.
        val broken =
            object : CopyStore by store {
                override fun ownRowsIn(folder: String): List<FolderRow> = throw IllegalStateException("/storage/emulated/0/Movies/TakeTray/Goa")
            }
        val api2 = CopyHostApiImpl(activity, CopyEngine(broken, io = executor.asCoroutineDispatcher()), send = {})
        val e = code { runBlocking { withTimeout(10_000) { api2.ownRowsIn(FOLDER) } } }
        assertEquals("native-error", e.code)
        assertEquals("ownRowsIn failed: IllegalStateException", e.message)
    }

    @Test
    fun `cancel, resume, clear and the folder calls go through`() {
        val api = impl()
        assertNull(runBlocking { withTimeout(10_000) { api.cancel("nope") } })
        api.start(request(item(1)))
        settle()
        val cancelled = runBlocking { withTimeout(10_000) { api.cancel("job-1") } }!!
        assertEquals(CopyStateMsg.CANCELLED, cancelled.state)
        api.resume("job-1")
        api.clear("job-1")
        assertNull(api.current())

        val left = store.addRow(FOLDER, "left.mp4", pending = true)
        assertEquals(listOf(FolderRowMsg(left.id, "left.mp4", 0, true)), runBlocking { withTimeout(10_000) { api.ownRowsIn(FOLDER) } })
        assertEquals(1L, runBlocking { withTimeout(10_000) { api.deletePendingIn(FOLDER) } })
    }

    @Test
    fun `deletePendingIn while a job runs is busy`() {
        val entered = latch()
        val release = latch()
        val api = impl()
        api.start(request(item(1, onRead = { if (it == 0L) { entered.countDown(); release.await(5, TimeUnit.SECONDS) } })))
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        assertEquals("busy", code { runBlocking { withTimeout(10_000) { api.deletePendingIn(FOLDER) } } }.code)
        release.countDown()
        settle()
    }

    @Test
    fun `events reach Dart on the main thread`() {
        val api = impl()
        api.start(request(item(1), item(2)))
        settle()
        val all = synchronized(sent) { sent.toList() }
        assertTrue(all.isNotEmpty())
        assertTrue("every send on the main thread", all.all { it.second })
        assertEquals(CopyStateMsg.RUNNING, all.first().first.state)
        assertEquals(CopyStateMsg.FINISHED, all.last().first.state)
        api.onHostGone()
    }

    @Test
    fun `the job outlives the activity and events reach only the new listener`() {
        val entered = latch()
        val release = latch()
        val first = impl()
        first.start(request(item(1, onRead = { if (it == 0L) { entered.countDown(); release.await(5, TimeUnit.SECONDS) } }), item(2)))
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        shadowOf(Looper.getMainLooper()).idle()

        // The activity is destroyed (a rotation, or Android reclaiming it while the app is in the background).
        first.onHostGone()
        first.onHostGone()
        val before = synchronized(sent) { sent.size }

        val activity2 = Robolectric.buildActivity(Activity::class.java).setup().get()
        val sent2: MutableList<Pair<CopyJobMsg, Boolean>> = Collections.synchronizedList(mutableListOf())
        val second = impl(activity2, sent2)
        val now = second.current()!!
        assertEquals("job-1", now.jobId)
        assertEquals(CopyStateMsg.RUNNING, now.state)

        release.countDown()
        settle()
        assertEquals(before, synchronized(sent) { sent.size })
        assertEquals(CopyStateMsg.FINISHED, synchronized(sent2) { sent2.last() }.first.state)
        assertEquals(2, second.current()!!.copied.size)

        // The old bridge no longer touches any window; the new one does.
        first.keepScreenOn(true)
        assertFalse(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0)
        second.keepScreenOn(true)
        assertTrue(activity2.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0)
        second.keepScreenOn(false)
        assertFalse(activity2.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0)
    }

    @Test
    fun `a bridge that is gone leaves no listener on the engine`() {
        assertFalse(engine.hasListener)
        val api = impl()
        assertTrue(engine.hasListener)
        api.onHostGone()
        assertFalse("the dead bridge must not stay referenced by the process-wide engine", engine.hasListener)
        api.onHostGone()
        assertFalse(engine.hasListener)
    }

    @Test
    fun `an old bridge going away does not detach the new one`() {
        val first = impl()
        val sent2: MutableList<Pair<CopyJobMsg, Boolean>> = Collections.synchronizedList(mutableListOf())
        val second = impl(into = sent2)
        // The old activity's destroy arrives after the new one was set up.
        first.onHostGone()
        second.start(request(item(1)))
        settle()
        assertTrue(synchronized(sent2) { sent2.isNotEmpty() })
    }

    @Test
    fun `a failing send is dropped quietly`() {
        val api = CopyHostApiImpl(activity, engine, send = { throw CopyApiError("channel-error", "no Dart side") })
        api.start(request(item(1)))
        settle()
        assertEquals(CopyStateMsg.FINISHED, api.current()!!.state)
    }
}
