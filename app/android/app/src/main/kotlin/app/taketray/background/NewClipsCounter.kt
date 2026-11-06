package app.taketray.background

import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import app.taketray.media.MediaAccessChecker
import app.taketray.media.MediaAccessLevelMsg
import app.taketray.media.MediaStoreVolumes
import app.taketray.media.VideoQueries

/**
 * Counts the videos added since the stored baselines (D-104): the clips the
 * app has not scanned yet (spec §8.3). It only counts; the scan when the app
 * opens stays the truth (spec §11) and decides what becomes a clip.
 *
 * Never everything as new: a volume whose MediaStore version is not its
 * baseline's (rebuilt library, or [versionOf] null because it is not
 * mounted) and a volume without a baseline count 0. Without full video access
 * or with Shooting mode off the answer is [NONE], without a query.
 *
 * Nothing it reads is logged (D-10).
 */
class NewClipsCounter(
    private val resolver: ContentResolver,
    /** A volume's MediaStore version, or null when it is not mounted. */
    private val versionOf: (String) -> String?,
    /** Whether TakeTray has full video access (D-68). */
    private val access: () -> Boolean,
    /** The clock (ms), for how recent a row is. */
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    /**
     * [count] clips; [newest] is the volume and MediaStore id of the one added
     * last (for the thumbnail); [shotMs] the UTC instants they were shot, in no
     * particular order (Task 5's evening count): DATE_TAKEN, or DATE_ADDED x
     * 1000 when DATE_TAKEN is missing or 0; a row with neither has no entry.
     * [lastTouchedMs] is the latest of every counted row's DATE_ADDED and
     * DATE_MODIFIED (seconds, here in ms; a recording's row is added when it
     * starts and modified when it ends), or null when no row has either: how
     * recently the library took a clip in, for the quiet wait (D-110). A time
     * more than [FUTURE_SLACK_MS] ahead of the clock (the clock was set back,
     * or a file came with a future time) is not a time and counts for nothing.
     */
    data class NewClips(
        val count: Int,
        val newest: Pair<String, Long>?,
        val shotMs: List<Long>,
        val lastTouchedMs: Long? = null,
    )

    /**
     * The count for [state]. Throws when MediaStore gives no cursor (the
     * provider unavailable): that says nothing about the count, and 0 would
     * cancel the notification.
     */
    /**
     * Whether a take is still being recorded (D-110): a pending row above a
     * baseline in a watched folder, touched within [RECORDING_CAP_MS] (a
     * crashed recording's stuck row must not hold the notification for ever)
     * and not more than [FUTURE_SLACK_MS] ahead of the clock (a time further
     * ahead is no time, as for [NewClips.lastTouchedMs]).
     * Throws when MediaStore gives no cursor: not knowing is not "no".
     */
    fun recording(state: BackgroundState): Boolean {
        if (!state.shootingOn || state.watchedFolders.isEmpty() || !access()) return false
        val sinceSec = Math.floorDiv(nowMs() - RECORDING_CAP_MS, 1000L)
        val untilSec = Math.floorDiv(nowMs() + FUTURE_SLACK_MS, 1000L)
        for (baseline in state.baselines) {
            if (versionOf(baseline.volumeName) != baseline.version) continue
            val uri = MediaStore.Video.Media.getContentUri(baseline.volumeName)
            val args = VideoQueries.recordingArgs(baseline.generation, state.watchedFolders, sinceSec, untilSec)
            val cursor =
                resolver.query(uri, arrayOf(MediaColumns._ID), args, null)
                    ?: throw IllegalStateException("MediaStore gave no cursor")
            if (cursor.use { it.moveToFirst() }) return true
        }
        return false
    }

    fun count(state: BackgroundState): NewClips {
        if (!state.shootingOn || state.watchedFolders.isEmpty() || !access()) return NONE
        var count = 0
        val shots = ArrayList<Long>()
        // The newest so far: volume, id, DATE_ADDED (seconds).
        var newest: Triple<String, Long, Long>? = null
        var lastTouchedSec: Long? = null
        val latestTrustedSec = Math.floorDiv(nowMs() + FUTURE_SLACK_MS, 1000L)
        for (baseline in state.baselines) {
            if (versionOf(baseline.volumeName) != baseline.version) continue
            val uri = MediaStore.Video.Media.getContentUri(baseline.volumeName)
            val args = VideoQueries.newClipsArgs(baseline.generation, state.watchedFolders)
            val cursor =
                resolver.query(uri, VideoQueries.NEW_CLIPS_PROJECTION, args, null)
                    ?: throw IllegalStateException("MediaStore gave no cursor")
            cursor.use { c ->
                val id = c.getColumnIndexOrThrow(MediaColumns._ID)
                val taken = c.getColumnIndexOrThrow(MediaColumns.DATE_TAKEN)
                val added = c.getColumnIndexOrThrow(MediaColumns.DATE_ADDED)
                val modified = c.getColumnIndexOrThrow(MediaColumns.DATE_MODIFIED)
                var first = true
                while (c.moveToNext()) {
                    count++
                    val takenMs = if (c.isNull(taken)) 0L else c.getLong(taken)
                    val addedSec = if (c.isNull(added)) null else c.getLong(added)
                    for (index in intArrayOf(added, modified)) {
                        if (c.isNull(index)) continue
                        val sec = c.getLong(index)
                        if (sec > latestTrustedSec) continue
                        if (lastTouchedSec.let { it == null || sec > it }) lastTouchedSec = sec
                    }
                    when {
                        takenMs != 0L -> shots += takenMs
                        addedSec != null -> shots += addedSec * 1000
                    }
                    // Rows come newest generation first, so the first row is
                    // this volume's newest. Generations of two volumes are
                    // separate counters: between volumes, DATE_ADDED decides.
                    if (first) {
                        first = false
                        val addedOrZero = addedSec ?: 0
                        val current = newest
                        if (current == null || addedOrZero > current.third) {
                            newest = Triple(baseline.volumeName, c.getLong(id), addedOrZero)
                        }
                    }
                }
            }
        }
        return NewClips(count, newest?.let { it.first to it.second }, shots, lastTouchedSec?.let { it * 1000 })
    }

    companion object {
        /**
         * How long to wait for the newest new clip (its [NewClips.lastTouchedMs])
         * to be [NewClipsArming.QUIET_MS] old (D-110): null when it is (exactly
         * 5 minutes old is), or when no clip has a time. What is left plus a
         * margin, never more than the 5 minutes from now: a clip a little
         * ahead of the clock has a negative age, so what is left is more than
         * 5 minutes, and it is waited for the 5 minutes at most.
         */
        fun quietWaitMs(
            lastTouchedMs: Long?,
            nowMs: Long,
        ): Long? {
            val age = nowMs - (lastTouchedMs ?: return null)
            if (age >= NewClipsArming.QUIET_MS) return null
            val left = NewClipsArming.QUIET_MS - age
            return minOf(left + NewClipsArming.SETTLE_MARGIN_MS, NewClipsArming.QUIET_MS)
        }

        /** A pending row untouched this long is a stuck row, not a take (D-110). */
        const val RECORDING_CAP_MS = 3L * 60 * 60 * 1000

        /** A clip time this far ahead of the clock is still clock skew; further ahead is no time. */
        const val FUTURE_SLACK_MS = 60_000L

        /** Nothing new. */
        val NONE = NewClips(0, null, emptyList())

        /** The counter on the phone's own MediaStore, versions and permissions. */
        fun forPhone(context: Context): NewClipsCounter {
            val volumes = MediaStoreVolumes(context)
            return NewClipsCounter(context.contentResolver, volumes::version, { fullAccess(context) })
        }

        /** Full video access on this Android version (MediaAccessChecker, D-68). */
        fun fullAccess(context: Context): Boolean =
            MediaAccessChecker.level(Build.VERSION.SDK_INT) {
                context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
            } == MediaAccessLevelMsg.FULL
    }
}
