package app.taketray.editors

import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout

const val FOLDER = "Goa"
const val WALL_MS = 1_780_000_000_000L

/**
 * An engine on its own worker thread, over a [FakeCopyStore], with a clock
 * the test moves and every event recorded with the clock at that moment.
 * Events are delivered on the worker thread (`post` runs them at once).
 */
class Harness(
    val store: FakeCopyStore = FakeCopyStore(),
    chunkBytes: Int = 1024,
) {
    val time = AtomicLong(0)
    val events: MutableList<Pair<Long, CopySnapshot>> = Collections.synchronizedList(mutableListOf())
    val sleeps: MutableList<Long> = Collections.synchronizedList(mutableListOf())
    private val executor = Executors.newSingleThreadExecutor()
    val engine =
        CopyEngine(
            store,
            io = executor.asCoroutineDispatcher(),
            post = { it.run() },
            clock = { time.get() },
            wallClock = { WALL_MS },
            chunkBytes = chunkBytes,
            sleep = { sleeps += it },
        )
    val listener: (CopySnapshot) -> Unit = { events += time.get() to it }

    init {
        engine.attach(listener)
    }

    fun snapshots(): List<CopySnapshot> = synchronized(events) { events.map { it.second } }

    /** A detected clip [clipId] of [size] bytes, registered as a source; named `<clipId>.mp4` unless [name] is given. */
    fun item(
        clipId: Long,
        size: Int = 4096,
        name: String = "$clipId.mp4",
        volume: String = "external_primary",
        length: Long = size.toLong(),
        openError: Exception? = null,
        failReadAt: Long? = null,
        onRead: ((Long) -> Unit)? = null,
        sizeBytes: Long = size.toLong(),
    ): CopyItem {
        val source = CopySource(volume, clipId, null, "video/mp4")
        store.sources[store.key(source)] =
            FakeCopyStore.Source(ByteArray(size) { (it + clipId).toByte() }, length, openError, failReadAt, onRead)
        return CopyItem(clipId, source, name, sizeBytes)
    }

    fun request(
        vararg items: CopyItem,
        jobId: String = "job-1",
    ) = CopyRequest(jobId, reelId = 7, folderName = FOLDER, items = items.toList())

    /** Starts [request] and waits until the worker is idle; returns the snapshot then. */
    fun runJob(request: CopyRequest): CopySnapshot =
        timed {
            engine.start(request)
            engine.awaitIdle()
            engine.current()!!
        }

    fun <T> timed(body: suspend CoroutineScope.() -> T): T = runBlocking { withTimeout(10_000) { body() } }

    fun close() {
        executor.shutdownNow()
    }
}
