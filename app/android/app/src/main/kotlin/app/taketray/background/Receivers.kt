package app.taketray.background

import android.content.BroadcastReceiver
import android.content.Context
import android.util.Log
import app.taketray.media.MediaStoreVolumes
import app.taketray.media.Volumes
import java.time.ZoneId
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * What TakeTray's broadcast receivers run on (D-105): the phone's clock,
 * zone, volumes and video counter, and one background thread. Tests swap
 * them and put them back with [reset].
 */
internal object Receivers {
    /** One thread for every receiver's work, so a shade tap and a reminder never overlap. */
    private val thread: Executor = Executors.newSingleThreadExecutor()

    /** Tests make it direct. */
    var executor: Executor = thread
    var nowMs: () -> Long = System::currentTimeMillis
    var zone: () -> ZoneId = ZoneId::systemDefault
    var volumes: (Context) -> Volumes = { MediaStoreVolumes(it) }
    var counter: (Context) -> NewClipsCounter = NewClipsCounter::forPhone

    /** The phone's parts again (tests). */
    fun reset() {
        executor = thread
        nowMs = System::currentTimeMillis
        zone = ZoneId::systemDefault
        volumes = { MediaStoreVolumes(it) }
        counter = NewClipsCounter::forPhone
    }

    fun store(context: Context): BackgroundStateStore =
        BackgroundStateStore(context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE))

    /** What every receiver arms: the job, the alarms and the channels, on this clock and [zone]. */
    fun arming(zone: () -> ZoneId = this.zone): Arming = Arming.background(nowMs = { nowMs() }, zone = zone)
}

/**
 * Runs [block] on [Receivers.executor], keeping the broadcast alive until it
 * ends (`goAsync`). A failure is logged by its class only (D-10) and never
 * reaches Android. Called directly (a test), `goAsync` has nothing to keep.
 */
internal fun BroadcastReceiver.inBackground(
    what: String,
    block: () -> Unit,
) {
    val pending = goAsync()
    Receivers.executor.execute {
        try {
            block()
        } catch (e: Exception) {
            Log.w(LOG_TAG, "$what failed: ${e.javaClass.simpleName}")
        } finally {
            pending?.finish()
        }
    }
}
