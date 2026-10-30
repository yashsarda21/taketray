package app.taketray.media

import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * The time-zone changes the phone made while TakeTray was not looking, kept
 * natively until Dart reads them into its zone timeline (spec §8.3a). A JSON
 * array of `{"atMs": <UTC ms>, "zoneId": "<IANA id>"}` under one key of the
 * `taketray_native` preferences. Corrupt JSON reads as empty and is replaced
 * on the next record. Zone ids are not logged.
 */
class ZoneChangeStore(private val prefs: SharedPreferences) {
    /** Appends (atMs, zoneId) unless the last entry already has this zone; keeps the newest [MAX_ENTRIES]. */
    fun record(
        atMs: Long,
        zoneId: String,
    ) = synchronized(LOCK) {
        val entries = read()
        if (entries.lastOrNull()?.zoneId == zoneId) return@synchronized
        entries += ZoneChangeMsg(atMs, zoneId)
        while (entries.size > MAX_ENTRIES) entries.removeAt(0)
        write(entries)
    }

    /** Every stored change, oldest first. */
    fun pending(): List<ZoneChangeMsg> = synchronized(LOCK) { read() }

    /** Removes the changes at or before [atMs]; later ones stay. */
    fun clearUpTo(atMs: Long) =
        synchronized(LOCK) {
            val entries = read()
            val kept = entries.filter { it.atMs > atMs }
            if (kept.size != entries.size) write(kept)
        }

    private fun read(): MutableList<ZoneChangeMsg> {
        val text = prefs.getString(KEY, null) ?: return mutableListOf()
        return try {
            val array = JSONArray(text)
            MutableList(array.length()) { i ->
                val entry = array.getJSONObject(i)
                ZoneChangeMsg(atMs = entry.getLong("atMs"), zoneId = entry.getString("zoneId"))
            }
        } catch (e: JSONException) {
            Log.w(LOG_TAG, "zone change list unreadable; treated as empty")
            mutableListOf()
        }
    }

    private fun write(entries: List<ZoneChangeMsg>) {
        val array = JSONArray()
        for (e in entries) array.put(JSONObject().put("atMs", e.atMs).put("zoneId", e.zoneId))
        // commit, not apply: the receiver may run in a process that ends right after.
        prefs.edit().putString(KEY, array.toString()).commit()
    }

    companion object {
        const val PREFS_NAME = "taketray_native"
        const val KEY = "zone_changes"
        const val MAX_ENTRIES = 500

        /** One lock for every store instance: the receiver and the bridge each make their own. */
        private val LOCK = Any()
    }
}
