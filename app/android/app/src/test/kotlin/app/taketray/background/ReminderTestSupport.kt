package app.taketray.background

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Looper
import android.provider.MediaStore
import app.taketray.media.Volumes
import java.time.Instant
import java.time.ZoneId
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowAlarmManager

/** Shared by the reminder, shade-action and boot tests (D-105). */
internal object ReminderTestSupport {
    val LONDON: ZoneId = ZoneId.of("Europe/London")
    const val MAIN = MediaStore.VOLUME_EXTERNAL_PRIMARY
    const val NINE_PM = 21 * 60

    fun ms(text: String): Long = Instant.parse(text).toEpochMilli()

    fun utc(ms: Long): String = Instant.ofEpochMilli(ms).toString()

    /** The alarm's PendingIntent (Robolectric 4.17 offers only the deprecated field). */
    @Suppress("DEPRECATION")
    fun operation(alarm: ShadowAlarmManager.ScheduledAlarm): PendingIntent = alarm.operation ?: throw AssertionError("an alarm without a PendingIntent")

    /** The one alarm armed for [action] (an evening or still reminder), or null. */
    fun alarm(
        context: Context,
        action: String,
    ): ShadowAlarmManager.ScheduledAlarm? {
        val alarms = shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms
        val matching = alarms.filter { shadowOf(operation(it)).savedIntent.action == action }
        check(matching.size <= 1) { "${matching.size} alarms for $action" }
        return matching.singleOrNull()
    }

    /** When the alarm for [action] fires, as an ISO instant, or null when none is armed. */
    fun alarmAt(
        context: Context,
        action: String,
    ): String? = alarm(context, action)?.let { utc(it.triggerAtMs) }

    /** Fires the alarm for [action] as Android would: its PendingIntent's broadcast, delivered on the main looper. */
    fun fire(
        context: Context,
        action: String,
    ) {
        val alarm = alarm(context, action) ?: throw AssertionError("no alarm for $action")
        shadowOf(context.getSystemService(AlarmManager::class.java)).fireAlarm(alarm)
        shadowOf(Looper.getMainLooper()).idle()
    }

    fun notification(
        context: Context,
        id: Int,
    ): Notification? = shadowOf(context.getSystemService(NotificationManager::class.java)).getNotification(id)

    fun Notification.title() = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()

    fun Notification.text() = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()

    fun Notification.action(label: String): Notification.Action = actions.single { it.title.toString() == label }
}

/** Volumes with a version and generation per name; a name in [failing] throws on its generation. */
internal class FakeVolumes(
    private val volumes: Map<String, Pair<String, Long>>,
    private val failing: Set<String> = emptySet(),
) : Volumes {
    override fun names(): Set<String> = volumes.keys + failing

    override fun version(volume: String): String? = volumes[volume]?.first ?: if (volume in failing) "v1" else null

    override fun generation(volume: String): Long {
        if (volume in failing) throw IllegalStateException("generation unreadable")
        return volumes[volume]?.second ?: throw IllegalArgumentException("unknown volume")
    }
}
