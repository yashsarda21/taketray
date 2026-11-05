package app.taketray.background

import android.content.SharedPreferences
import android.util.Log
import app.taketray.media.ZoneChangeStore
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * The background mirror (D-103) in the `taketray_native` preferences, under
 * these keys: [KEY_STATE] (the [BackgroundState] as JSON), [KEY_SHADE_ACTION]
 * (the one waiting shade action as JSON), [KEY_POSTED_NEW_CLIPS] (the count
 * the new-clips notification shows, 0 when none is posted), the two
 * "handled once" marks of the reminders (D-105), [KEY_STILL_POSTED_SINCE]
 * and [KEY_EVENING_HANDLED_DAY], and the evening the evening alarm stands
 * for ([KEY_EVENING_ARMED_FOR]).
 *
 * - Every write uses `commit()`, not `apply()`: a receiver or the job may run
 *   in a process that ends right after it returns, and a queued `apply()`
 *   would be lost.
 * - One lock for every instance: the bridge, the job and each receiver make
 *   their own store.
 * - A missing or corrupt value reads as "off, nothing" ([BackgroundState.OFF],
 *   no shade action, 0) and is replaced by the next write. Nothing read here
 *   is logged (D-10).
 */
class BackgroundStateStore(
    private val prefs: SharedPreferences,
) {
    fun state(): BackgroundState =
        synchronized(LOCK) {
            val text = string(KEY_STATE) ?: return@synchronized BackgroundState.OFF
            try {
                BackgroundState.fromJson(text)
            } catch (e: JSONException) {
                Log.w(LOG_TAG, "background state unreadable; treated as off")
                BackgroundState.OFF
            }
        }

    fun write(state: BackgroundState) =
        synchronized(LOCK) {
            prefs.edit().putString(KEY_STATE, state.toJson()).commit()
            Unit
        }

    /** The shade action waiting for Dart, or null. */
    fun shadeAction(): ShadeActionMsg? =
        synchronized(LOCK) {
            val text = string(KEY_SHADE_ACTION) ?: return@synchronized null
            try {
                shadeActionFromJson(text)
            } catch (e: JSONException) {
                Log.w(LOG_TAG, "shade action unreadable; treated as none")
                null
            }
        }

    /** Stores [action], replacing any earlier one (the newest tap wins). */
    fun putShadeAction(action: ShadeActionMsg) =
        synchronized(LOCK) {
            prefs.edit().putString(KEY_SHADE_ACTION, shadeActionToJson(action)).commit()
            Unit
        }

    /** Removes the stored action only if its atMs is [atMs]: a newer tap stays for Dart. */
    fun clearShadeAction(atMs: Long) =
        synchronized(LOCK) {
            if (shadeAction()?.atMs == atMs) prefs.edit().remove(KEY_SHADE_ACTION).commit()
            Unit
        }

    fun postedNewClips(): Int =
        synchronized(LOCK) {
            try {
                prefs.getInt(KEY_POSTED_NEW_CLIPS, 0)
            } catch (e: ClassCastException) {
                0
            }
        }

    fun setPostedNewClips(count: Int) =
        synchronized(LOCK) {
            prefs.edit().putInt(KEY_POSTED_NEW_CLIPS, count).commit()
            Unit
        }

    /**
     * The session (`sinceMs`) whose Still shooting? the reminder receiver has
     * handled, or null. One per session: re-arming skips a handled session.
     */
    fun stillPostedSince(): Long? = synchronized(LOCK) { long(KEY_STILL_POSTED_SINCE) }

    fun setStillPostedSince(sinceMs: Long) =
        synchronized(LOCK) {
            prefs.edit().putLong(KEY_STILL_POSTED_SINCE, sinceMs).commit()
            Unit
        }

    /**
     * The local day ([ReminderTimes.localDay]) whose evening reminder the
     * receiver last handled (posted, or found nothing to post), or null.
     */
    fun eveningHandledDay(): Long? = synchronized(LOCK) { long(KEY_EVENING_HANDLED_DAY) }

    fun setEveningHandledDay(epochDay: Long) =
        synchronized(LOCK) {
            prefs.edit().putLong(KEY_EVENING_HANDLED_DAY, epochDay).commit()
            Unit
        }

    /**
     * The evening instant (UTC ms) the evening alarm stands for: the time it
     * was armed for, even when a catch-up made it fire later. Null when off.
     */
    fun eveningArmedFor(): Long? = synchronized(LOCK) { long(KEY_EVENING_ARMED_FOR) }

    /** Written only when it changes (every arming calls it). */
    fun setEveningArmedFor(atMs: Long?) =
        synchronized(LOCK) {
            if (long(KEY_EVENING_ARMED_FOR) != atMs) {
                val edit = prefs.edit()
                if (atMs == null) edit.remove(KEY_EVENING_ARMED_FOR) else edit.putLong(KEY_EVENING_ARMED_FOR, atMs)
                edit.commit()
            }
            Unit
        }

    /** The Long under [key]; null when missing or of another type (corrupt). */
    private fun long(key: String): Long? =
        try {
            if (prefs.contains(key)) prefs.getLong(key, 0) else null
        } catch (e: ClassCastException) {
            Log.w(LOG_TAG, "background value of the wrong type; treated as missing")
            null
        }

    /** The string under [key]; null when missing or of another type (corrupt). */
    private fun string(key: String): String? =
        try {
            prefs.getString(key, null)
        } catch (e: ClassCastException) {
            Log.w(LOG_TAG, "background value of the wrong type; treated as missing")
            null
        }

    companion object {
        const val PREFS_NAME = ZoneChangeStore.PREFS_NAME
        const val KEY_STATE = "background_state"
        const val KEY_SHADE_ACTION = "shade_action"
        const val KEY_POSTED_NEW_CLIPS = "posted_new_clips"
        const val KEY_STILL_POSTED_SINCE = "still_posted_since"
        const val KEY_EVENING_HANDLED_DAY = "evening_handled_day"
        const val KEY_EVENING_ARMED_FOR = "evening_armed_for"

        /** One lock for every store instance (as ZoneChangeStore has). */
        private val LOCK = Any()

        private val KINDS = mapOf("turnOff" to ShadeActionKindMsg.TURN_OFF, "keepOn" to ShadeActionKindMsg.KEEP_ON)

        private fun shadeActionToJson(action: ShadeActionMsg): String =
            JSONObject()
                .put("kind", KINDS.entries.first { it.value == action.kind }.key)
                .put("sinceMs", action.sinceMs)
                .put("atMs", action.atMs)
                .put(
                    "generations",
                    JSONArray().apply {
                        for (g in action.generations) put(JSONObject().put("volumeName", g.volumeName).put("generation", g.generation))
                    },
                ).toString()

        private fun shadeActionFromJson(text: String): ShadeActionMsg {
            val o = JSONObject(text)
            val kind = KINDS[o.getString("kind")] ?: throw JSONException("unknown kind")
            val generations = o.getJSONArray("generations")
            return ShadeActionMsg(
                kind = kind,
                sinceMs = o.getLong("sinceMs"),
                atMs = o.getLong("atMs"),
                generations =
                    List(generations.length()) { i ->
                        val g = generations.getJSONObject(i)
                        VolumeGenerationMsg(g.getString("volumeName"), g.getLong("generation"))
                    },
            )
        }
    }
}
