package app.taketray.editors

import android.system.ErrnoException
import android.system.OsConstants
import java.io.FileNotFoundException
import java.io.IOException
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The copy loop (D-122), through the engine over a [FakeCopyStore]: order,
 * names read back, failed items, the space floor and ENOSPC, resume, cancel
 * at every point, and the progress throttle.
 */
@RunWith(RobolectricTestRunner::class)
class CopyJobTest {
    private val h = Harness()
    private val store get() = h.store

    @After
    fun tearDown() {
        h.close()
    }

    private fun rowIdsPublished(): List<Long> = store.log().filter { it.startsWith("publish ") }.map { it.removePrefix("publish ").toLong() }

    private fun resumeAndEnd(): CopySnapshot =
        h.timed {
            h.engine.resume("job-1")
            h.engine.awaitIdle()
            h.engine.current()!!
        }

    private fun inserts(): List<String> = store.log().filter { it.startsWith("insert ") }.map { it.removePrefix("insert ") }

    @Test
    fun `happy path copies every item in order and reports the names MediaStore gave`() {
        // Someone else's file already has the second name: MediaStore renames ours.
        store.addRow(FOLDER, "2.mp4", pending = false, owner = "com.other")
        val items = arrayOf(h.item(1, size = 4096), h.item(2, size = 3000), h.item(3, size = 5000))
        // Every read moves the clock 100 ms, so progress events can happen.
        h.time.set(0)
        items.forEach { item ->
            val s = store.sources[store.key(item.source)]!!
            store.sources[store.key(item.source)] = FakeCopyStore.Source(s.bytes, onRead = { h.time.addAndGet(100) })
        }
        val end = h.runJob(h.request(*items))

        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf("1.mp4", "2.mp4", "3.mp4"), inserts())
        assertEquals(listOf(1L, 2L, 3L), end.copied.map { it.clipId })
        assertEquals(listOf("1.mp4", "2 (1).mp4", "3.mp4"), end.copied.map { it.fileName })
        assertEquals(listOf(4096L, 3000L, 5000L), end.copied.map { it.sizeBytes })
        assertTrue(end.copied.all { it.copiedAtMs == WALL_MS })
        assertEquals(3, end.total)
        assertEquals(3, end.done)
        assertEquals(12096L, end.bytesTotal)
        assertEquals(12096L, end.bytesDone)
        assertTrue(end.failedClipIds.isEmpty())
        assertTrue(end.undeleted.isEmpty())
        // The rows hold the bytes and are published; each copy's id is its row.
        for ((item, file) in items.zip(end.copied)) {
            val row = store.rows[file.copyMediaStoreId]!!
            assertFalse(row.pending)
            assertTrue(row.bytes.toByteArray().contentEquals(store.sources[store.key(item.source)]!!.bytes))
        }

        val events = h.snapshots()
        // One event per finished file: the first snapshot with k copies, for every k.
        for (k in 1..3) assertTrue("an event with $k copied", events.any { it.copied.size == k })
        // done and bytesDone never go back.
        events.zipWithNext().forEach { (a, b) ->
            assertTrue(b.done >= a.done)
            assertTrue(b.bytesDone >= a.bytesDone)
        }
        // At least one progress event inside a file (bytes moved, no file finished).
        assertTrue(events.zipWithNext().any { (a, b) -> b.done == a.done && b.bytesDone > a.bytesDone && b.state == CopyState.RUNNING })
        assertEquals(CopyState.FINISHED, events.last().state)
        assertEquals(CopyState.RUNNING, events.first().state)
    }

    @Test
    fun `a source that cannot be read or is short fails alone and the job goes on`() {
        val items =
            arrayOf(
                h.item(1),
                h.item(2, openError = FileNotFoundException("deleted")),
                // A picked clip whose grant is gone.
                h.item(3, openError = SecurityException("no grant")),
                // Shorter than it says it is.
                h.item(4, size = 3000, length = 5000),
                // Deleted (or the card pulled) mid-copy.
                h.item(5, size = 4096, failReadAt = 2048),
                // Unknown own length: the size Dart gave is the measure, and it is short too.
                h.item(6, size = 1000, length = -1, sizeBytes = 2000),
                h.item(7),
            )
        val end = h.runJob(h.request(*items))

        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(2L, 3L, 4L, 5L, 6L), end.failedClipIds)
        assertEquals(listOf(1L, 7L), end.copied.map { it.clipId })
        assertEquals(7, end.done)
        // Every failed item's pending row is gone and none was published.
        assertEquals(end.copied.map { it.copyMediaStoreId }.toSet(), store.rows.keys)
        assertEquals(end.copied.map { it.copyMediaStoreId }, rowIdsPublished())
        assertTrue(store.rowsNow().none { it.pending })
        assertEquals(end.bytesTotal, end.bytesDone)
    }

    @Test
    fun `an unknown own length and no size from Dart copies to the end`() {
        val end = h.runJob(h.request(h.item(1, size = 3000, length = -1, sizeBytes = 0)))
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(3000L, end.copied.single().sizeBytes)
    }

    @Test
    fun `the space floor stops before the file one byte short and copies at exactly enough`() {
        val size = 4096L
        store.available = { size + NATIVE_FLOOR_BYTES }
        val ok = h.runJob(h.request(h.item(1)))
        assertEquals(CopyState.FINISHED, ok.state)
        assertEquals(1, ok.copied.size)

        val h2 = Harness()
        try {
            h2.store.available = { size + NATIVE_FLOOR_BYTES - 1 }
            val short = h2.runJob(h2.request(h2.item(1)))
            assertEquals(CopyState.SPACE_FULL, short.state)
            assertTrue(short.copied.isEmpty())
            assertTrue("no row is made", h2.store.log().none { it.startsWith("insert") })
            assertTrue(h2.store.rows.isEmpty())
        } finally {
            h2.close()
        }
    }

    @Test
    fun `space running out before a later file keeps the earlier copies`() {
        var calls = 0
        store.available = { if (++calls == 1) Long.MAX_VALUE / 2 else 0L }
        val end = h.runJob(h.request(h.item(1), h.item(2), h.item(3)))
        assertEquals(CopyState.SPACE_FULL, end.state)
        assertEquals(listOf(1L), end.copied.map { it.clipId })
        assertEquals(listOf("1.mp4"), inserts())
        assertEquals(1, end.done)
        assertEquals(4096L, end.bytesDone)
        assertTrue(store.rows.values.single().let { !it.pending })
    }

    @Test
    fun `ENOSPC mid-file deletes that pending row and keeps the earlier copies`() {
        // The error is armed by the second file's first read: once its row holds 2 KB, the disk is full.
        val two = h.item(2, size = 8192, onRead = { store.writeErrorAt = 2048L to FakeCopyStore.noSpace() })
        val full = h.runJob(h.request(h.item(1), two, h.item(3)))
        assertEquals(CopyState.SPACE_FULL, full.state)
        assertEquals(listOf(1L), full.copied.map { it.clipId })
        assertTrue(full.failedClipIds.isEmpty())
        assertEquals(setOf(full.copied.single().copyMediaStoreId), store.rows.keys)
        assertEquals(1, full.done)
        // The half file's bytes are not counted.
        assertEquals(4096L, full.bytesDone)
        assertTrue("item 3 never started", store.log().none { it == "insert 3.mp4" })
        assertTrue("the half file is never published", rowIdsPublished().size == 1)
    }

    @Test
    fun `resume copies only the remaining items and fails again at once while space is short`() {
        var free = Long.MAX_VALUE / 2
        var calls = 0
        store.available = { if (++calls == 2) 0L else free }
        val items = arrayOf(h.item(1), h.item(2), h.item(3), h.item(4))
        val full = h.runJob(h.request(*items))
        assertEquals(CopyState.SPACE_FULL, full.state)
        assertEquals(listOf("1.mp4"), inserts())

        // Still short: fails at once, nothing made.
        free = 0L
        h.timed {
            h.engine.resume("job-1")
            h.engine.awaitIdle()
        }
        assertEquals(CopyState.SPACE_FULL, h.engine.current()!!.state)
        assertEquals(listOf("1.mp4"), inserts())
        assertEquals(CopyState.SPACE_FULL, h.snapshots().last().state)

        free = Long.MAX_VALUE / 2
        h.timed {
            h.engine.resume("job-1")
            h.engine.awaitIdle()
        }
        val end = h.engine.current()!!
        assertEquals(CopyState.FINISHED, end.state)
        // Item 1 is never copied twice.
        assertEquals(listOf("1.mp4", "2.mp4", "3.mp4", "4.mp4"), inserts())
        assertEquals(listOf(1L, 2L, 3L, 4L), end.copied.map { it.clipId })
        assertEquals(4, end.done)
        assertEquals(end.bytesTotal, end.bytesDone)
    }

    @Test
    fun `a target that fails for another reason interrupts the job and resume goes on from that item`() {
        val items = arrayOf(h.item(1), h.item(2), h.item(3))
        val s = store
        s.sources[s.key(items[1].source)] =
            FakeCopyStore.Source(s.sources[s.key(items[1].source)]!!.bytes, onRead = { if (it == 0L) s.writeErrorAt = 0L to IOException("EIO") })
        val stop = h.runJob(h.request(*items))
        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertEquals(listOf(1L), stop.copied.map { it.clipId })
        assertTrue(stop.failedClipIds.isEmpty())
        assertEquals(setOf(stop.copied.single().copyMediaStoreId), s.rows.keys)

        s.writeErrorAt = null
        s.sources[s.key(items[1].source)] = FakeCopyStore.Source(ByteArray(4096) { (it + 2).toByte() })
        h.timed {
            h.engine.resume("job-1")
            h.engine.awaitIdle()
        }
        val end = h.engine.current()!!
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(1L, 2L, 3L), end.copied.map { it.clipId })
        assertEquals(listOf("1.mp4", "2.mp4", "2.mp4", "3.mp4"), inserts())
    }

    @Test
    fun `a close that fails for space after a full write never publishes and the job is space full`() {
        // Every byte was handed to the stream; the disk-full error shows only at close.
        val two = h.item(2, size = 8192, onRead = { if (it == 0L) store.closeError = FakeCopyStore.noSpace() })
        val full = h.runJob(h.request(h.item(1), two, h.item(3)))
        assertEquals(CopyState.SPACE_FULL, full.state)
        assertEquals(listOf(1L), full.copied.map { it.clipId })
        assertTrue(full.failedClipIds.isEmpty())
        assertEquals(1, full.done)
        // The half file's bytes are not counted.
        assertEquals(4096L, full.bytesDone)
        assertEquals("only the first copy was ever published", listOf(full.copied.single().copyMediaStoreId), rowIdsPublished())
        assertEquals(setOf(full.copied.single().copyMediaStoreId), store.rows.keys)
        assertTrue("item 3 never started", store.log().none { it == "insert 3.mp4" })
        assertTrue(store.rowsNow().none { it.pending })
    }

    @Test
    fun `a close that fails for another reason never publishes and interrupts, and resume copies it again`() {
        var armed = false
        val two =
            h.item(2, size = 8192, onRead = {
                // Only the first try fails at close; resume reads the item again.
                if (it == 0L && !armed) {
                    armed = true
                    store.closeError = IOException("EIO")
                }
            })
        val stop = h.runJob(h.request(h.item(1), two, h.item(3)))
        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertEquals(listOf(1L), stop.copied.map { it.clipId })
        assertTrue(stop.failedClipIds.isEmpty())
        assertEquals(1, stop.done)
        assertEquals(listOf(stop.copied.single().copyMediaStoreId), rowIdsPublished())
        assertEquals(setOf(stop.copied.single().copyMediaStoreId), store.rows.keys)

        // The close error was spent: resume copies item 2 whole, then item 3.
        h.timed {
            h.engine.resume("job-1")
            h.engine.awaitIdle()
        }
        val end = h.engine.current()!!
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(1L, 2L, 3L), end.copied.map { it.clipId })
        assertTrue(store.rows.values.all { !it.pending })
        assertEquals(8192, store.rows[end.copied[1].copyMediaStoreId]!!.bytes.size())
    }

    @Test
    fun `a close that fails during a cancel publishes nothing and the job is cancelled with every row gone`() {
        val two =
            h.item(2, size = 8192, onRead = { pos ->
                if (pos >= 2048) {
                    store.closeError = IOException("EIO")
                    h.engine.beginCancel("job-1")
                }
            })
        val end = h.runJob(h.request(h.item(1), two, h.item(3)))
        assertEquals(CopyState.CANCELLED, end.state)
        assertEquals(listOf(1L), end.copied.map { it.clipId })
        assertTrue(end.undeleted.isEmpty())
        assertEquals("item 2 was never published", 1, rowIdsPublished().size)
        assertTrue("the pending row and the copy are both deleted", store.rows.isEmpty())
        assertEquals(CopyState.CANCELLED, h.snapshots().last().state)
    }

    @Test
    fun `an insert that fails interrupts, one MediaStore refuses for its name fails that item only`() {
        store.insertError = IllegalStateException("volume gone")
        val stop = h.runJob(h.request(h.item(1), h.item(2)))
        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertTrue(stop.copied.isEmpty())
        assertTrue(stop.failedClipIds.isEmpty())
        assertEquals(0, stop.done)

        val h2 = Harness()
        try {
            h2.store.insertErrorFor["1.mp4"] = IllegalArgumentException("bad name")
            val end = h2.runJob(h2.request(h2.item(1), h2.item(2)))
            assertEquals(CopyState.FINISHED, end.state)
            assertEquals(listOf(1L), end.failedClipIds)
            assertEquals(listOf(2L), end.copied.map { it.clipId })
        } finally {
            h2.close()
        }
    }

    @Test
    fun `a single item that MediaStore refuses fails alone and the job finishes (T5)`() {
        store.insertError = IllegalArgumentException("bad name")
        val end = h.runJob(h.request(h.item(1)))
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(1L), end.failedClipIds)
    }

    @Test
    fun `two refusals in a row mean it is not the names, so the job stops interrupted and keeps the second item for a retry (T5)`() {
        store.insertError = IllegalArgumentException("Unknown URL")
        val stop = h.runJob(h.request(h.item(1), h.item(2), h.item(3)))

        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertEquals("the first stays failed", listOf(1L), stop.failedClipIds)
        assertEquals("the second was not tried to the end: 1 of 3 done", 1, stop.done)
        assertEquals(listOf("1.mp4", "2.mp4"), inserts())
        assertTrue(store.rows.isEmpty())

        // The cause is gone: resume starts again at the second item.
        store.insertError = null
        val end = resumeAndEnd()
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(2L, 3L), end.copied.map { it.clipId })
        assertEquals(listOf(1L), end.failedClipIds)
    }

    @Test
    fun `a refusal, a good item and a refusal are two single failures, not two in a row (T5)`() {
        store.insertErrorFor["1.mp4"] = IllegalArgumentException("bad name")
        store.insertErrorFor["3.mp4"] = IllegalArgumentException("bad name")
        val end = h.runJob(h.request(h.item(1), h.item(2), h.item(3)))

        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(1L, 3L), end.failedClipIds)
        assertEquals(listOf(2L), end.copied.map { it.clipId })
    }

    @Test
    fun `a refusal then a failed original then a refusal is not two in a row either (T5)`() {
        store.insertErrorFor["1.mp4"] = IllegalArgumentException("bad name")
        store.insertErrorFor["3.mp4"] = IllegalArgumentException("bad name")
        val end = h.runJob(h.request(h.item(1), h.item(2, openError = IOException("gone")), h.item(3)))

        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(1L, 2L, 3L), end.failedClipIds)
    }

    @Test
    fun `the count of refusals starts again on a resume (T5)`() {
        store.insertErrorFor["2.mp4"] = IllegalArgumentException("bad name")
        store.insertErrorFor["3.mp4"] = IllegalArgumentException("bad name")
        store.publishError = null
        val stop = h.runJob(h.request(h.item(1), h.item(2), h.item(3), h.item(4)))
        // 2 refused, 3 refused: stops at 3 (interrupted), 2 failed.
        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertEquals(listOf(2L), stop.failedClipIds)

        // Resume: 3 is refused again, which is the first refusal of this run.
        val end = resumeAndEnd()
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(2L, 3L), end.failedClipIds)
        assertEquals(listOf(1L, 4L), end.copied.map { it.clipId })
    }

    @Test
    fun `a refusal before a stop for space does not count toward the next run (T5)`() {
        var calls = 0
        var free = Long.MAX_VALUE / 2
        // The second room check (before item 2) finds no space; later ones do.
        store.available = { if (++calls == 2) 0L else free }
        store.insertErrorFor["1.mp4"] = IllegalArgumentException("bad name")
        store.insertErrorFor["2.mp4"] = IllegalArgumentException("bad name")
        val stop = h.runJob(h.request(h.item(1), h.item(2), h.item(3)))
        assertEquals(CopyState.SPACE_FULL, stop.state)
        assertEquals(listOf(1L), stop.failedClipIds)

        // Space is back: item 2 is refused too, which is the first refusal of
        // THIS run, not the second in a row.
        val end = resumeAndEnd()
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(listOf(1L, 2L), end.failedClipIds)
        assertEquals(listOf(3L), end.copied.map { it.clipId })
    }

    @Test
    fun `an insert that fails for space is space full`() {
        store.insertError = IOException("No space left on device")
        assertEquals(CopyState.SPACE_FULL, h.runJob(h.request(h.item(1))).state)
    }

    @Test
    fun `a publish that fails deletes the row and interrupts`() {
        store.publishError = IllegalStateException("update failed")
        val stop = h.runJob(h.request(h.item(1)))
        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertTrue(stop.copied.isEmpty())
        assertTrue(store.rows.isEmpty())
    }

    @Test
    fun `a target that cannot be opened deletes the row and interrupts`() {
        store.targetError = FileNotFoundException("row gone")
        val stop = h.runJob(h.request(h.item(1)))
        assertEquals(CopyState.INTERRUPTED, stop.state)
        assertTrue(store.rows.isEmpty())
    }

    @Test
    fun `cancel mid-file deletes the pending row and this job's copies only`() {
        val earlier = store.addRow(FOLDER, "earlier.mp4", pending = false)
        lateinit var two: CopyItem
        two = h.item(2, size = 8192, onRead = { pos -> if (pos >= 2048) h.engine.beginCancel("job-1") })
        val end = h.runJob(h.request(h.item(1), two, h.item(3)))

        assertEquals(CopyState.CANCELLED, end.state)
        // Only the earlier job's file is left.
        assertEquals(listOf(earlier.id), store.rows.keys.toList())
        // copied lists what was deleted.
        assertEquals(listOf(1L), end.copied.map { it.clipId })
        assertTrue(end.undeleted.isEmpty())
        assertTrue("item 2 never published", rowIdsPublished().size == 1)
        assertTrue("item 3 never opened", store.log().none { it.startsWith("open external_primary:3") })
        assertEquals(CopyState.CANCELLED, h.snapshots().last().state)
    }

    @Test
    fun `a copy that cannot be deleted after a cancel is undeleted`() {
        val two = h.item(2, onRead = { h.engine.beginCancel("job-1") })
        val one = h.item(1)
        // The first copy's row will be id 100 (the store's first).
        store.undeletable += 100L
        val end = h.runJob(h.request(one, two))
        assertEquals(CopyState.CANCELLED, end.state)
        assertTrue(end.copied.isEmpty())
        assertEquals(listOf(1L), end.undeleted.map { it.clipId })
        assertEquals(listOf(100L), store.rows.keys.toList())
    }

    @Test
    fun `cancel racing the end of the last file still deletes every copy`() {
        val last = h.item(2, onRead = { pos -> if (pos == -1L) h.engine.beginCancel("job-1") })
        val end = h.runJob(h.request(h.item(1), last))
        assertEquals(CopyState.CANCELLED, end.state)
        assertTrue(store.rows.isEmpty())
        assertEquals(listOf(1L, 2L), end.copied.map { it.clipId })
    }

    @Test
    fun `cancel after finished but before clear deletes the copies`() {
        val done = h.runJob(h.request(h.item(1), h.item(2)))
        assertEquals(CopyState.FINISHED, done.state)
        val end = h.timed { h.engine.cancel("job-1") }!!
        assertEquals(CopyState.CANCELLED, end.state)
        assertTrue(store.rows.isEmpty())
        assertEquals(listOf(1L, 2L), end.copied.map { it.clipId })
        assertEquals(CopyState.CANCELLED, h.engine.current()!!.state)
    }

    @Test
    fun `cancel after space full deletes the copies made so far`() {
        var calls = 0
        store.available = { if (++calls == 1) Long.MAX_VALUE / 2 else 0L }
        assertEquals(CopyState.SPACE_FULL, h.runJob(h.request(h.item(1), h.item(2))).state)
        val end = h.timed { h.engine.cancel("job-1") }!!
        assertEquals(CopyState.CANCELLED, end.state)
        assertTrue(store.rows.isEmpty())
    }

    @Test
    fun `an empty job is finished at once`() {
        val end = h.runJob(h.request())
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(0, end.total)
    }

    @Test
    fun `ENOSPC is found by its message, anywhere in the causes`() {
        assertTrue(isNoSpace(FakeCopyStore.noSpace()))
        assertTrue(isNoSpace(IOException("x", ErrnoException("write", OsConstants.ENOSPC))))
        assertTrue(isNoSpace(IOException(IOException("write failed: ENOSPC"))))
        assertTrue(isNoSpace(IllegalStateException("No space left on device")))
        assertFalse(isNoSpace(IOException("x", ErrnoException("write", OsConstants.EIO))))
        assertFalse(isNoSpace(IOException("EIO")))
    }

    @Test
    fun `every finished file sends its own event, in order, even with no progress events`() {
        // The clock never moves: no progress event can be due, so every event is the start, a file or the end.
        val items = (1L..5L).map { h.item(it, size = 3000) }.toTypedArray()
        items[2] = h.item(3, openError = FileNotFoundException("gone"))
        h.runJob(h.request(*items))
        val events = h.snapshots()
        assertEquals(1 + 5 + 1, events.size)
        assertEquals(0, events.first().done)
        // The k-th file event has k items handled, the failed one included.
        for (k in 1..5) assertEquals(k, events[k].done)
        assertEquals(listOf(1, 2, 2, 3, 4), (1..5).map { events[it].copied.size })
        assertEquals(listOf(3L), events[3].failedClipIds)
        assertEquals(CopyState.FINISHED, events.last().state)
    }

    @Test
    fun `a 200-item job throttles progress to one per 250 ms and reports every file`() {
        val items = (1L..200L).map { id -> h.item(id, size = 5 * 1024, onRead = { h.time.addAndGet(60) }) }
        val end = h.runJob(h.request(*items.toTypedArray()))
        assertEquals(CopyState.FINISHED, end.state)
        assertEquals(200, end.copied.size)

        val events = synchronized(h.events) { h.events.toList() }
        // Every finished file has its event.
        for (k in 1..200) assertTrue("file $k", events.any { it.second.copied.size == k })
        // A progress event (same file, more bytes) comes at least 250 ms after the event before it.
        var progress = 0
        events.zipWithNext().forEach { (a, b) ->
            if (b.second.state == CopyState.RUNNING && b.second.done == a.second.done && b.second.bytesDone > a.second.bytesDone) {
                progress++
                assertTrue("progress after ${b.first - a.first} ms", b.first - a.first >= PROGRESS_EVERY_MS)
            }
        }
        assertTrue("some progress events", progress > 0)
        // 6 reads of 60 ms per file is 360 ms: never more than one progress event per file.
        assertTrue(progress <= 200)
    }

    @Test
    fun `the default chunk is 1 MiB and the debug throttle sleeps per chunk`() {
        val big = Harness(chunkBytes = CHUNK_BYTES)
        try {
            assertEquals(1024 * 1024, CHUNK_BYTES)
            big.engine.throttleMs = 7
            val end = big.runJob(big.request(big.item(1, size = 3 * 1024 * 1024 + 10)))
            assertEquals(CopyState.FINISHED, end.state)
            // Four chunks (three full, one of 10 bytes), one sleep each.
            assertEquals(listOf(7L, 7L, 7L, 7L), big.sleeps.toList())
        } finally {
            big.close()
        }
        // Without the hook there is no sleep at all.
        h.runJob(h.request(h.item(1)))
        assertTrue(h.sleeps.isEmpty())
    }
}
