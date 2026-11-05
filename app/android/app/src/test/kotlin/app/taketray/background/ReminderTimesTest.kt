package app.taketray.background

import java.time.Instant
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * When the reminders fire (D-105). Plain JVM: `java.time` and its own zone
 * rules. London's clocks go forward on 2026-03-29 at 01:00 UTC (local 01:00
 * to 01:59 does not exist) and back on 2026-10-25 at 01:00 UTC (local 01:00
 * to 01:59 comes twice).
 */
class ReminderTimesTest {
    private val london = ZoneId.of("Europe/London")
    private val kolkata = ZoneId.of("Asia/Kolkata")
    private val nine = 21 * 60

    private fun ms(text: String): Long = Instant.parse(text).toEpochMilli()

    private fun at(ms: Long): String = Instant.ofEpochMilli(ms).toString()

    @Test
    fun `next evening later today`() {
        assertEquals("2026-11-05T21:00:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T12:00:00Z"), nine, london)))
        // Another zone: 21:00 in India is 15:30 UTC.
        assertEquals("2026-11-05T15:30:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T04:30:00Z"), nine, kolkata)))
        // One millisecond before: still today.
        assertEquals("2026-11-05T21:00:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T20:59:59.999Z"), nine, london)))
    }

    @Test
    fun `next evening after the time passed is tomorrow`() {
        // Strictly after now: at 21:00 exactly the next one is tomorrow's.
        assertEquals("2026-11-06T21:00:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T21:00:00Z"), nine, london)))
        assertEquals("2026-11-06T21:00:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T21:30:00Z"), nine, london)))
        // Late at night in India: 21:00 IST has passed today (it is 23:00 IST).
        assertEquals("2026-11-06T15:30:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T17:30:00Z"), nine, kolkata)))
    }

    @Test
    fun `next evening across spring forward`() {
        // 21:00 on the day the clocks go forward is 21:00 BST (20:00 UTC), once.
        val saturdayNight = ms("2026-03-28T22:00:00Z")
        val sunday = ReminderTimes.nextEvening(saturdayNight, nine, london)
        assertEquals("2026-03-29T20:00:00Z", at(sunday))
        assertEquals("2026-03-30T20:00:00Z", at(ReminderTimes.nextEvening(sunday, nine, london)))

        // 01:30 does not exist that day: the first instant after the gap (02:00 BST).
        val inGap = ReminderTimes.nextEvening(saturdayNight, 90, london)
        assertEquals("2026-03-29T01:00:00Z", at(inGap))
        // Then the next day's 01:30 BST, not a second one that night.
        assertEquals("2026-03-30T00:30:00Z", at(ReminderTimes.nextEvening(inGap, 90, london)))
    }

    @Test
    fun `next evening across fall back fires once`() {
        // 01:30 comes twice on 2026-10-25: 01:30 BST (00:30 UTC), then 01:30 GMT (01:30 UTC).
        val first = ReminderTimes.nextEvening(ms("2026-10-24T22:00:00Z"), 90, london)
        assertEquals("2026-10-25T00:30:00Z", at(first))
        // Re-armed when it fires: the next day, not the second 01:30.
        assertEquals("2026-10-26T01:30:00Z", at(ReminderTimes.nextEvening(first, 90, london)))
        // Re-armed between the two 01:30s (a reboot at 01:10 GMT): still the next day.
        assertEquals("2026-10-26T01:30:00Z", at(ReminderTimes.nextEvening(ms("2026-10-25T01:10:00Z"), 90, london)))
        // 21:00 that day is 21:00 GMT, once.
        val evening = ReminderTimes.nextEvening(ms("2026-10-25T12:00:00Z"), nine, london)
        assertEquals("2026-10-25T21:00:00Z", at(evening))
        assertEquals("2026-10-26T21:00:00Z", at(ReminderTimes.nextEvening(evening, nine, london)))
    }

    @Test
    fun `minute 0 and 1439`() {
        val noon = ms("2026-11-05T12:00:00Z")
        assertEquals("2026-11-06T00:00:00Z", at(ReminderTimes.nextEvening(noon, 0, london)))
        assertEquals("2026-11-05T23:59:00Z", at(ReminderTimes.nextEvening(noon, 1439, london)))
        // At 23:59 exactly, 23:59 is tomorrow's; 30 s later, midnight is 30 s away.
        assertEquals("2026-11-06T23:59:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T23:59:00Z"), 1439, london)))
        assertEquals("2026-11-06T00:00:00Z", at(ReminderTimes.nextEvening(ms("2026-11-05T23:59:30Z"), 0, london)))
        // At midnight exactly, midnight is tomorrow's.
        assertEquals("2026-11-07T00:00:00Z", at(ReminderTimes.nextEvening(ms("2026-11-06T00:00:00Z"), 0, london)))
    }

    @Test
    fun `evening minutes out of range are clamped`() {
        // Dart sends what the settings hold; Kotlin does not check it on write.
        val noon = ms("2026-11-05T12:00:00Z")
        assertEquals(ReminderTimes.nextEvening(noon, 0, london), ReminderTimes.nextEvening(noon, -5, london))
        assertEquals(ReminderTimes.nextEvening(noon, 1439, london), ReminderTimes.nextEvening(noon, 5000, london))
        assertEquals(ReminderTimes.nextEvening(noon, 1439, london), ReminderTimes.nextEvening(noon, Int.MAX_VALUE, london))
        assertEquals(ReminderTimes.nextEvening(noon, 0, london), ReminderTimes.nextEvening(noon, Int.MIN_VALUE, london))
    }

    @Test
    fun `still due rounds up to 10 o'clock`() {
        // On at 03:00: 14 days later is 03:00, so it waits for 10:00 that morning.
        assertEquals("2026-11-15T10:00:00Z", at(ReminderTimes.stillDueAt(ms("2026-11-01T03:00:00Z"), london)))
        // On at 15:00: 14 days later 10:00 has passed, so the next morning.
        assertEquals("2026-11-16T10:00:00Z", at(ReminderTimes.stillDueAt(ms("2026-11-01T15:00:00Z"), london)))
        // A millisecond after 10:00 is the next morning too.
        assertEquals("2026-11-16T10:00:00Z", at(ReminderTimes.stillDueAt(ms("2026-11-01T10:00:00.001Z"), london)))
        // 10:00 India time is 04:30 UTC.
        assertEquals("2026-11-15T04:30:00Z", at(ReminderTimes.stillDueAt(ms("2026-11-01T00:00:00Z"), kolkata)))
    }

    @Test
    fun `still due exactly at 10 o'clock stays`() {
        assertEquals("2026-11-15T10:00:00Z", at(ReminderTimes.stillDueAt(ms("2026-11-01T10:00:00Z"), london)))
        // Across the spring change: 14 × 24 hours after 09:00 GMT is 10:00 BST.
        assertEquals("2026-04-03T09:00:00Z", at(ReminderTimes.stillDueAt(ms("2026-03-20T09:00:00Z"), london)))
        assertEquals(14, ReminderTimes.STILL_AFTER_DAYS)
    }

    @Test
    fun `start of today`() {
        assertEquals("2026-11-05T00:00:00Z", at(ReminderTimes.startOfToday(ms("2026-11-05T23:30:00Z"), london)))
        // 20:00 UTC is already 01:30 on the 6th in India, whose day began at 18:30 UTC.
        assertEquals("2026-11-05T18:30:00Z", at(ReminderTimes.startOfToday(ms("2026-11-05T20:00:00Z"), kolkata)))
        // Summer time: London's day starts at 23:00 UTC the day before.
        assertEquals("2026-07-09T23:00:00Z", at(ReminderTimes.startOfToday(ms("2026-07-10T12:00:00Z"), london)))
    }
}
