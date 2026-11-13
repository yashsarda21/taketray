package app.taketray.editors

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The engine owns at most one job (D-122, R4): busy while a job runs or its
 * result waits, unknown ids change nothing, the listener can come and go,
 * and a bad request is refused before anything is written.
 */
@RunWith(RobolectricTestRunner::class)
class CopyEngineTest {
    private val h = Harness()
    private val engine get() = h.engine
    private val store get() = h.store

    /** Every latch a test made: released after it, so a failing test never leaves the worker waiting. */
    private val latches = mutableListOf<CountDownLatch>()

    private fun latch() = CountDownLatch(1).also { latches += it }

    @After
    fun tearDown() {
        latches.forEach { it.countDown() }
        h.close()
    }

    /** An item whose first read waits for [release], so the job is surely running. */
    private fun held(
        clipId: Long,
        entered: CountDownLatch,
        release: CountDownLatch,
    ) = h.item(clipId, onRead = { pos ->
        if (pos == 0L) {
            entered.countDown()
            release.await(5, TimeUnit.SECONDS)
        }
    })

    private fun busy(block: () -> Unit) {
        try {
            block()
            fail("expected busy")
        } catch (e: CopyBusyException) {
            // expected
        }
    }

    @Test
    fun `a fresh engine has no job and no throttle`() {
        val fresh = CopyEngine(FakeCopyStore())
        assertNull(fresh.current())
        assertEquals(0L, fresh.throttleMs)
    }

    @Test
    fun `start while a job runs is busy and changes nothing`() {
        val entered = latch()
        val release = latch()
        engine.start(h.request(held(1, entered, release)))
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        val log = store.log()
        busy { engine.start(h.request(h.item(9), jobId = "job-2")) }
        assertEquals(log, store.log())
        assertEquals("job-1", engine.current()!!.jobId)
        assertEquals(CopyState.RUNNING, engine.current()!!.state)
        release.countDown()
        h.timed { engine.awaitIdle() }
        assertEquals(CopyState.FINISHED, engine.current()!!.state)
        assertEquals(listOf(1L), engine.current()!!.copied.map { it.clipId })
    }

    @Test
    fun `start while a result waits is busy until it is cleared`() {
        h.runJob(h.request(h.item(1)))
        busy { engine.start(h.request(h.item(2), jobId = "job-2")) }
        assertEquals("job-1", engine.current()!!.jobId)

        // Another id clears nothing.
        engine.clear("job-2")
        assertEquals("job-1", engine.current()!!.jobId)

        engine.clear("job-1")
        assertNull(engine.current())
        val next = h.runJob(h.request(h.item(2), jobId = "job-2"))
        assertEquals("job-2", next.jobId)
        assertEquals(CopyState.FINISHED, next.state)
    }

    @Test
    fun `unknown ids change nothing`() {
        h.runJob(h.request(h.item(1)))
        val before = engine.current()
        val log = store.log()
        assertNull(h.timed { engine.cancel("nope") })
        engine.resume("nope")
        engine.clear("nope")
        h.timed { engine.awaitIdle() }
        assertEquals(before, engine.current())
        assertEquals(log, store.log())
        assertEquals(1, store.rows.size)

        // And with no job at all.
        engine.clear("job-1")
        assertNull(h.timed { engine.cancel("job-1") })
        engine.resume("job-1")
        assertNull(engine.current())
    }

    @Test
    fun `resume does nothing to a finished job and clear does nothing to a running one`() {
        h.runJob(h.request(h.item(1)))
        val log = store.log()
        engine.resume("job-1")
        h.timed { engine.awaitIdle() }
        assertEquals(log, store.log())
        assertEquals(CopyState.FINISHED, engine.current()!!.state)
        engine.clear("job-1")

        val entered = latch()
        val release = latch()
        engine.start(h.request(held(2, entered, release), jobId = "job-2"))
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        engine.clear("job-2")
        assertEquals("job-2", engine.current()!!.jobId)
        release.countDown()
        h.timed { engine.awaitIdle() }
        assertEquals(CopyState.FINISHED, engine.current()!!.state)
    }

    @Test
    fun `cancel waits for the worker and two cancels give one outcome`() {
        val entered = latch()
        val release = latch()
        engine.start(h.request(h.item(1), held(2, entered, release)))
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        val (a, b) =
            h.timed {
                val first = async(Dispatchers.Default, start = CoroutineStart.DEFAULT) { engine.cancel("job-1") }
                val second = async(Dispatchers.Default) { engine.cancel("job-1") }
                // Neither answers while the worker still holds the file.
                Thread.sleep(50)
                assertTrue(!first.isCompleted && !second.isCompleted)
                release.countDown()
                first.await() to second.await()
            }
        assertEquals(CopyState.CANCELLED, a!!.state)
        assertEquals(a, b)
        assertTrue(store.rows.isEmpty())
        // Each row was deleted once.
        val deletes = store.log().filter { it.startsWith("delete ") }
        assertEquals(deletes.distinct(), deletes)
        // A cancel of a cancelled job answers the same and deletes nothing more.
        assertEquals(a, h.timed { engine.cancel("job-1") })
        assertEquals(deletes, store.log().filter { it.startsWith("delete ") })
    }

    @Test
    fun `cancel then clear frees the engine`() {
        h.runJob(h.request(h.item(1)))
        h.timed { engine.cancel("job-1") }
        busy { engine.start(h.request(h.item(2), jobId = "job-2")) }
        engine.clear("job-1")
        assertEquals(CopyState.FINISHED, h.runJob(h.request(h.item(2), jobId = "job-2")).state)
    }

    @Test
    fun `events reach only the attached listener`() {
        val other = mutableListOf<CopySnapshot>()
        val second: (CopySnapshot) -> Unit = { synchronized(other) { other += it } }
        engine.detach(h.listener)
        h.runJob(h.request(h.item(1)))
        assertTrue("dropped while nobody listens", h.events.isEmpty())
        engine.clear("job-1")

        engine.attach(second)
        // Detaching a listener that is not the attached one changes nothing.
        engine.detach(h.listener)
        h.runJob(h.request(h.item(2), jobId = "job-2"))
        assertTrue(h.events.isEmpty())
        assertTrue(synchronized(other) { other.isNotEmpty() })
        assertEquals(CopyState.FINISHED, synchronized(other) { other.last() }.state)
    }

    @Test
    fun `a request with a path in a name is refused before anything is written`() {
        val bad =
            listOf(
                h.request(h.item(1)).copy(folderName = "Goa/../DCIM"),
                h.request(h.item(1)).copy(folderName = ".."),
                h.request(h.item(1)).copy(folderName = "."),
                h.request(h.item(1)).copy(folderName = " "),
                h.request(h.item(1)).copy(folderName = "a\u0000b"),
                h.request(h.item(1, name = "x/1.mp4")),
                h.request(h.item(1, name = "..")),
                h.request(h.item(1, name = "")),
                h.request(h.item(1)).copy(jobId = ""),
                h.request(h.item(1, sizeBytes = -1)),
            )
        for (request in bad) {
            try {
                engine.start(request)
                fail("expected a refusal")
            } catch (e: IllegalArgumentException) {
                // expected
            }
            assertNull(engine.current())
        }
        assertTrue(store.log().isEmpty())
        assertTrue(h.events.isEmpty())
    }

    @Test
    fun `folder calls refuse a bad folder name`() {
        for (folder in listOf("a/b", "..", "", "TakeTray/..")) {
            try {
                h.timed { engine.ownRowsIn(folder) }
                fail("expected a refusal")
            } catch (e: IllegalArgumentException) {
                // expected
            }
            try {
                h.timed { engine.deletePendingIn(folder) }
                fail("expected a refusal")
            } catch (e: IllegalArgumentException) {
                // expected
            }
        }
    }

    @Test
    fun `deletePendingIn is busy while a job runs, and start is busy while it sweeps`() {
        val entered = latch()
        val release = latch()
        engine.start(h.request(held(1, entered, release)))
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        try {
            h.timed { engine.deletePendingIn(FOLDER) }
            fail("expected busy")
        } catch (e: CopyBusyException) {
            // expected
        }
        // The running job's pending row is still there.
        assertTrue(store.rowsNow().single().pending)
        release.countDown()
        h.timed { engine.awaitIdle() }
        engine.clear("job-1")

        val gate = CountDownLatch(1)
        store.deletePendingGate = gate
        try {
            h.timed {
                val sweep = async(Dispatchers.Default) { engine.deletePendingIn(FOLDER) }
                assertTrue(store.deletePendingEntered.await(5, TimeUnit.SECONDS))
                try {
                    busy { engine.start(h.request(h.item(2), jobId = "job-2")) }
                } finally {
                    gate.countDown()
                }
                assertEquals(0, sweep.await())
            }
        } finally {
            gate.countDown()
        }
        // Once the sweep is over a job may start.
        assertEquals(CopyState.FINISHED, h.runJob(h.request(h.item(2), jobId = "job-2")).state)
    }

    @Test
    fun `ownRowsIn and deletePendingIn reach the store`() {
        store.addRow(FOLDER, "left.mp4", pending = true)
        val kept = store.addRow(FOLDER, "done.mp4", pending = false)
        assertEquals(2, h.timed { engine.ownRowsIn(FOLDER) }.size)
        assertEquals(1, h.timed { engine.deletePendingIn(FOLDER) })
        assertEquals(listOf(kept.id), store.rows.keys.toList())
    }

    @Test
    fun `an unexpected failure ends the job as interrupted, never stuck running`() {
        var calls = 0
        store.available = { if (++calls == 2) throw RuntimeException("boom") else Long.MAX_VALUE / 2 }
        val end = h.runJob(h.request(h.item(1), h.item(2)))
        assertEquals(CopyState.INTERRUPTED, end.state)
        assertEquals(listOf(1L), end.copied.map { it.clipId })
        engine.clear("job-1")
        assertNull(engine.current())
    }

    @Test
    fun `the shared engine is one per process`() {
        val app = androidx.test.core.app.ApplicationProvider.getApplicationContext<android.content.Context>()
        assertSame(CopyEngine.shared(app), CopyEngine.shared(app))
        assertEquals(0L, CopyEngine.shared(app).throttleMs)
    }
}
