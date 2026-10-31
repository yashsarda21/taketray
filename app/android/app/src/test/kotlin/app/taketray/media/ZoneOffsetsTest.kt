package app.taketray.media

import java.time.Instant
import java.time.ZoneId
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The UTC offsets of zones at instants, from the phone's own rules (D-83).
 * Robolectric, so it runs once per SDK level in robolectric.properties.
 */
@RunWith(RobolectricTestRunner::class)
class ZoneOffsetsTest {
    private fun ms(text: String): Long = Instant.parse(text).toEpochMilli()

    @Test
    fun `london summer and winter offsets`() {
        assertEquals(
            listOf<Long?>(3_600_000L, 0L),
            ZoneOffsets.offsetsMs(
                listOf("Europe/London", "Europe/London"),
                listOf(ms("2026-07-01T12:00:00Z"), ms("2026-12-01T12:00:00Z")),
            ),
        )
    }

    @Test
    fun `the exact London DST instant`() {
        // Clocks go back at 01:00 UTC on 2026-10-25 (02:00 BST becomes 01:00 GMT).
        assertEquals(
            listOf<Long?>(3_600_000L, 0L),
            ZoneOffsets.offsetsMs(
                listOf("Europe/London", "Europe/London"),
                listOf(ms("2026-10-25T00:59:59.999Z"), ms("2026-10-25T01:00:00Z")),
            ),
        )
    }

    @Test
    fun `kolkata half hour`() {
        assertEquals(
            listOf<Long?>(19_800_000L),
            ZoneOffsets.offsetsMs(listOf("Asia/Kolkata"), listOf(ms("2026-10-28T09:41:00Z"))),
        )
    }

    @Test
    fun `invalid id is null`() {
        // Each answer stays at its own index, between valid ones.
        val at = ms("2026-07-01T12:00:00Z")
        assertEquals(
            listOf<Long?>(null, 3_600_000L, null, 19_800_000L),
            ZoneOffsets.offsetsMs(
                listOf("Not/AZone", "Europe/London", "", "Asia/Kolkata"),
                listOf(at, at, at, at),
            ),
        )
    }

    @Test
    fun `length mismatch throws`() {
        assertThrows(IllegalArgumentException::class.java) {
            ZoneOffsets.offsetsMs(listOf("Europe/London", "Asia/Kolkata"), listOf(0L))
        }
        assertThrows(IllegalArgumentException::class.java) {
            ZoneOffsets.offsetsMs(emptyList(), listOf(0L))
        }
    }

    @Test
    fun `empty lists give empty`() {
        assertEquals(emptyList<Long?>(), ZoneOffsets.offsetsMs(emptyList(), emptyList()))
    }

    @Test
    fun `offsets come from the phone's zone rules`() {
        // Every zone the phone knows, at a summer, a winter and a far-past
        // instant, agrees with java.util.TimeZone (ICU on a phone). The far
        // past (1950) shows the answer is the zone's rule for that instant,
        // not today's offset.
        val ids = ZoneId.getAvailableZoneIds().sorted()
        val instants = listOf(ms("2026-07-01T12:00:00Z"), ms("2026-12-01T12:00:00Z"), ms("1950-07-01T12:00:00Z"))
        val zoneIds = ids.flatMap { id -> instants.map { id } }
        val at = ids.flatMap { instants }

        val answers = ZoneOffsets.offsetsMs(zoneIds, at)

        assertEquals(zoneIds.size, answers.size)
        zoneIds.indices.forEach { i ->
            assertEquals(
                "${zoneIds[i]} at ${at[i]}",
                TimeZone.getTimeZone(zoneIds[i]).getOffset(at[i]).toLong(),
                answers[i],
            )
        }
    }

    @Test
    fun `instants at the ends of the range do not fail`() {
        // A corrupt date taken can be anything a Dart int holds.
        val answers = ZoneOffsets.offsetsMs(listOf("Europe/London", "UTC"), listOf(Long.MIN_VALUE, Long.MAX_VALUE))
        assertEquals(2, answers.size)
        assertEquals(0L, answers[1])
    }
}
