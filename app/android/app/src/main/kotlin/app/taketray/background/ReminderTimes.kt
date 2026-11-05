package app.taketray.background

import java.time.Duration
import java.time.Instant
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * When the reminders fire (D-105), in the phone's local time. Pure
 * `java.time`: no Android, no clock of its own, so every case (a daylight
 * saving day, another zone, minute 0 and 1439) is a plain JVM test.
 */
object ReminderTimes {
    /** "Still shooting?" comes this many days after Shooting mode went on (Dart's `stillShootingAfter`). */
    const val STILL_AFTER_DAYS = 14

    /** The local hour the 14-day reminder waits for: never in the night. */
    const val STILL_HOUR = 10

    /** The last minute of a day: the evening time is clamped to 0..[LAST_MINUTE]. */
    const val LAST_MINUTE = 24 * 60 - 1

    /**
     * The next instant strictly after [nowMs] when the local time in [zone] is
     * [minutes] past midnight ([minutes] outside 0..[LAST_MINUTE] is clamped).
     * On a day where that time does not exist (the clocks go forward over
     * it) it is the first instant after the gap; on a day where it comes
     * twice (the clocks go back) it is the first time only, so it fires once.
     */
    fun nextEvening(
        nowMs: Long,
        minutes: Int,
        zone: ZoneId,
    ): Long {
        val time = eveningTime(minutes)
        val now = Instant.ofEpochMilli(nowMs)
        var date = now.atZone(zone).toLocalDate()
        while (true) {
            val at = instantAt(date.atTime(time), zone)
            if (at.isAfter(now)) return at.toEpochMilli()
            date = date.plusDays(1)
        }
    }

    /**
     * Today's evening: the instant on [nowMs]'s local date in [zone] when the
     * local time is [minutes] past midnight (clamped, and a gap or overlap
     * as in [nextEvening]). It may be before or after [nowMs].
     */
    fun eveningToday(
        nowMs: Long,
        minutes: Int,
        zone: ZoneId,
    ): Long {
        val date = Instant.ofEpochMilli(nowMs).atZone(zone).toLocalDate()
        return instantAt(date.atTime(eveningTime(minutes)), zone).toEpochMilli()
    }

    /**
     * [nowMs]'s local date in [zone] as `LocalDate.toEpochDay()`: the day the
     * evening reminder's "handled" mark names. The receiver that sets the
     * mark and the arming that reads it both use this, in the same zone.
     */
    fun localDay(
        nowMs: Long,
        zone: ZoneId,
    ): Long = Instant.ofEpochMilli(nowMs).atZone(zone).toLocalDate().toEpochDay()

    /**
     * When "Still shooting?" is due for a session that started at [sinceMs]:
     * the first [STILL_HOUR]:00 local at or after `since` + [STILL_AFTER_DAYS]
     * days (14 × 24 hours, as Dart counts them).
     */
    fun stillDueAt(
        sinceMs: Long,
        zone: ZoneId,
    ): Long {
        val due = Instant.ofEpochMilli(sinceMs).plus(Duration.ofDays(STILL_AFTER_DAYS.toLong()))
        val ten = LocalTime.of(STILL_HOUR, 0)
        val date = due.atZone(zone).toLocalDate()
        val sameDay = instantAt(date.atTime(ten), zone)
        val at = if (sameDay.isBefore(due)) instantAt(date.plusDays(1).atTime(ten), zone) else sameDay
        return at.toEpochMilli()
    }

    /** The first instant of [nowMs]'s local day in [zone]. */
    fun startOfToday(
        nowMs: Long,
        zone: ZoneId,
    ): Long =
        Instant
            .ofEpochMilli(nowMs)
            .atZone(zone)
            .toLocalDate()
            .atStartOfDay(zone)
            .toInstant()
            .toEpochMilli()

    /** [minutes] past midnight, clamped to 0..[LAST_MINUTE]. */
    private fun eveningTime(minutes: Int): LocalTime {
        val m = minutes.coerceIn(0, LAST_MINUTE)
        return LocalTime.of(m / 60, m % 60)
    }

    /**
     * [local] in [zone]: in a gap, the first instant after it (the
     * transition); in an overlap, the earlier of the two.
     */
    private fun instantAt(
        local: LocalDateTime,
        zone: ZoneId,
    ): Instant {
        val rules = zone.rules
        if (rules.getValidOffsets(local).isEmpty()) return rules.getTransition(local).instant
        return ZonedDateTime.ofLocal(local, zone, null).toInstant()
    }
}
