package app.taketray.media

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.taketray.background.BootReceiver
import app.taketray.background.Receivers
import java.time.DateTimeException
import java.time.ZoneId
import java.util.TimeZone

/**
 * Records every time-zone change in [ZoneChangeStore], even while TakeTray is
 * not running, then arms the job and the reminder alarms again in the new
 * zone (D-105: the evening is a local time). A manifest receiver:
 * ACTION_TIMEZONE_CHANGED is one of the broadcasts exempt from Android's
 * implicit-broadcast limits. Not exported; the system still delivers its own
 * broadcasts to it.
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
        // The new zone, from the broadcast: the process default may not have caught up.
        val zone =
            try {
                ZoneId.of(zoneId)
            } catch (e: DateTimeException) {
                Log.w(LOG_TAG, "zone id unreadable; re-armed in the default zone")
                ZoneId.systemDefault()
            }
        BootReceiver.rearm(context.applicationContext, Receivers.arming { zone })
    }
}
