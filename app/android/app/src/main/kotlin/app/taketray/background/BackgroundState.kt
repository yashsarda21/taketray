package app.taketray.background

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * The native mirror of what the background code needs (D-103), written by
 * Dart through `writeState` at every app start and on every change. Dart is
 * the truth: this copy is only read by the job, the alarms and the receivers
 * (Tasks 4 and 5), and never written back into the database.
 *
 * [sinceMs] is when Shooting mode was switched on (UTC ms; null while off).
 * [waitingShotMs] are the UTC instants of the clips waiting in To tag, in
 * ascending order. [eveningMinutes] is the evening reminder's local time, in
 * minutes after midnight. Nothing here is ever logged except counts (D-10).
 */
data class BackgroundState(
    val shootingOn: Boolean,
    val sinceMs: Long?,
    val baselines: List<Baseline>,
    val watchedFolders: List<String>,
    val waitingShotMs: List<Long>,
    val eveningEnabled: Boolean,
    val eveningMinutes: Int,
    val stillReminderEnabled: Boolean,
    val stillAnswered: Boolean,
    val copiesReminders: List<CopiesReminder> = emptyList(),
) {
    /** One editing session with copies (D-124). */
    data class CopiesReminder(
        val reelId: Long,
        val reelName: String,
        val copyBytes: Long,
        val lastCopiedAtMs: Long,
    )

    /** Where a volume's scan stopped: its MediaStore version and generation. */
    data class Baseline(
        val volumeName: String,
        val version: String,
        val generation: Long,
    )

    /**
     * The copies reminders the alarm, the receiver and the notifications may
     * use: a reel id that makes valid notification ids and request codes
     * (1 to [MAX_REEL_ID]; anything else could land on Phase 6's ids 1 to 3
     * or overflow a request code), a known time (above zero), and one per
     * reel, the newest batch. Ordered by reel id.
     */
    fun usableCopiesReminders(): List<CopiesReminder> =
        copiesReminders
            .filter { it.reelId in 1..MAX_REEL_ID && it.lastCopiedAtMs > 0 }
            .groupBy { it.reelId }
            .map { (_, batches) -> batches.maxBy { it.lastCopiedAtMs } }
            .sortedBy { it.reelId }

    /** The stored form: one JSON object (see [fromJson]). */
    fun toJson(): String =
        JSONObject()
            .put("shootingOn", shootingOn)
            .put("sinceMs", sinceMs ?: JSONObject.NULL)
            .put(
                "baselines",
                JSONArray().apply {
                    for (b in baselines) {
                        put(JSONObject().put("volumeName", b.volumeName).put("version", b.version).put("generation", b.generation))
                    }
                },
            ).put("watchedFolders", JSONArray(watchedFolders))
            .put("waitingShotMs", JSONArray(waitingShotMs))
            .put("eveningEnabled", eveningEnabled)
            .put("eveningMinutes", eveningMinutes)
            .put("stillReminderEnabled", stillReminderEnabled)
            .put("stillAnswered", stillAnswered)
            .put(
                "copiesReminders",
                JSONArray().apply {
                    for (r in copiesReminders) {
                        put(
                            JSONObject()
                                .put("reelId", r.reelId)
                                .put("reelName", r.reelName)
                                .put("copyBytes", r.copyBytes)
                                .put("lastCopiedAtMs", r.lastCopiedAtMs),
                        )
                    }
                },
            ).toString()

    companion object {
        /**
         * The largest reel id with valid ids and request codes: the tap codes are
         * `Notifier.COPIES_REQUEST_BASE + 2 * reelId + 1`, which must fit an Int.
         */
        const val MAX_REEL_ID = 1_073_241_823L

        /** Off, with nothing to watch and no reminder: what a missing or corrupt copy means. */
        val OFF =
            BackgroundState(
                shootingOn = false,
                sinceMs = null,
                baselines = emptyList(),
                watchedFolders = emptyList(),
                waitingShotMs = emptyList(),
                eveningEnabled = false,
                eveningMinutes = 0,
                stillReminderEnabled = false,
                stillAnswered = false,
            )

        fun from(msg: BackgroundStateMsg): BackgroundState =
            BackgroundState(
                shootingOn = msg.shootingOn,
                sinceMs = msg.sinceMs,
                baselines = msg.baselines.map { Baseline(it.volumeName, it.version, it.generation) },
                watchedFolders = msg.watchedFolders,
                waitingShotMs = msg.waitingShotMs,
                eveningEnabled = msg.eveningEnabled,
                eveningMinutes = msg.eveningMinutes.toInt(),
                stillReminderEnabled = msg.stillReminderEnabled,
                stillAnswered = msg.stillAnswered,
                copiesReminders =
                    msg.copiesReminders.map {
                        CopiesReminder(it.reelId, it.reelName, it.copyBytes, it.lastCopiedAtMs)
                    },
            )

        /**
         * Reads [toJson]'s form. Throws [JSONException] when any field is
         * missing or of the wrong type: the store then reads [OFF].
         */
        fun fromJson(text: String): BackgroundState {
            val o = JSONObject(text)
            val baselines = o.getJSONArray("baselines")
            val folders = o.getJSONArray("watchedFolders")
            val shots = o.getJSONArray("waitingShotMs")
            return BackgroundState(
                shootingOn = o.getBoolean("shootingOn"),
                sinceMs = if (o.isNull("sinceMs")) null else o.getLong("sinceMs"),
                baselines =
                    List(baselines.length()) { i ->
                        val b = baselines.getJSONObject(i)
                        Baseline(b.getString("volumeName"), b.getString("version"), b.getLong("generation"))
                    },
                watchedFolders = List(folders.length()) { folders.getString(it) },
                waitingShotMs = List(shots.length()) { shots.getLong(it) },
                eveningEnabled = o.getBoolean("eveningEnabled"),
                eveningMinutes = o.getInt("eveningMinutes"),
                stillReminderEnabled = o.getBoolean("stillReminderEnabled"),
                stillAnswered = o.getBoolean("stillAnswered"),
                // A state stored by Phase 6 has none.
                copiesReminders =
                    if (!o.has("copiesReminders")) {
                        emptyList()
                    } else {
                        val reminders = o.getJSONArray("copiesReminders")
                        List(reminders.length()) { i ->
                            val r = reminders.getJSONObject(i)
                            CopiesReminder(r.getLong("reelId"), r.getString("reelName"), r.getLong("copyBytes"), r.getLong("lastCopiedAtMs"))
                        }
                    },
            )
        }
    }
}
