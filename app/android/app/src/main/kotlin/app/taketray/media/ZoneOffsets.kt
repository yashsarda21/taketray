package app.taketray.media

import java.time.DateTimeException
import java.time.Instant
import java.time.ZoneId
import java.time.zone.ZoneRules

/**
 * UTC offsets of time zones at instants, from the phone's own time-zone rules
 * (D-83): `ZoneId.of(id).rules.getOffset(instant)`. On a phone those rules
 * are the system's tz data, which Android updates on its own, so TakeTray
 * bundles no zone database and has nothing to keep up to date.
 *
 * Pure: no Android state, no logging (a zone id names a place, D-10).
 */
object ZoneOffsets {
    /**
     * The offset in milliseconds of `zoneIds[i]` at `instantsMs[i]` (UTC
     * milliseconds since the epoch), for every i, in order. An entry is null
     * when its id is not a zone the phone knows (ZoneId.of throws a
     * DateTimeException: unknown, empty or malformed).
     *
     * @throws IllegalArgumentException when the two lists differ in length.
     */
    fun offsetsMs(
        zoneIds: List<String>,
        instantsMs: List<Long>,
    ): List<Long?> {
        require(zoneIds.size == instantsMs.size) {
            "zoneIds has ${zoneIds.size} entries and instantsMs ${instantsMs.size}"
        }
        // A batch usually repeats a handful of zones: look each one up once.
        val rulesById = HashMap<String, ZoneRules?>()
        return zoneIds.indices.map { i ->
            val id = zoneIds[i]
            val rules = if (rulesById.containsKey(id)) rulesById[id] else rulesOf(id).also { rulesById[id] = it }
            rules?.getOffset(Instant.ofEpochMilli(instantsMs[i]))?.totalSeconds?.times(MS_PER_SECOND)
        }
    }

    private fun rulesOf(id: String): ZoneRules? =
        try {
            ZoneId.of(id).rules
        } catch (e: DateTimeException) {
            null
        }

    private const val MS_PER_SECOND = 1000L
}
