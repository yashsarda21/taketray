package app.taketray.media

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.TimeZone

/**
 * Records every time-zone change in [ZoneChangeStore], even while TakeTray is
 * not running. A manifest receiver: ACTION_TIMEZONE_CHANGED is one of the
 * broadcasts exempt from Android's implicit-broadcast limits. Not exported;
 * the system still delivers its own broadcasts to it.
 */
class TimeZoneChangedReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (intent.action != Intent.ACTION_TIMEZONE_CHANGED) return
        // The broadcast names the new zone; the process default is the fallback.
        val zoneId = intent.getStringExtra(Intent.EXTRA_TIMEZONE) ?: TimeZone.getDefault().id
        val prefs = context.getSharedPreferences(ZoneChangeStore.PREFS_NAME, Context.MODE_PRIVATE)
        ZoneChangeStore(prefs).record(System.currentTimeMillis(), zoneId)
    }
}
