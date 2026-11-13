package app.taketray.background

import android.content.Context
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The native mirror of the background state. The store runs on
 * [ProcessPrefs], whose "disk" only `commit()` writes: [afterProcessEnd]
 * is a new process reading it, so a write that was only applied in memory
 * (an `apply()` still queued when the process ended) is lost there.
 */
@RunWith(RobolectricTestRunner::class)
class BackgroundStateStoreTest {
    private lateinit var prefs: ProcessPrefs
    private lateinit var store: BackgroundStateStore

    private val on =
        BackgroundState(
            shootingOn = true,
            sinceMs = 1_780_000_000_123,
            baselines =
                listOf(
                    BackgroundState.Baseline("external_primary", "abc123", 90_210),
                    BackgroundState.Baseline("1a2b-3c4d", "v2", 7),
                ),
            watchedFolders = listOf("DCIM/Camera/", "Movies/Café/"),
            waitingShotMs = listOf(1_780_000_000_000, 1_780_000_500_000),
            eveningEnabled = true,
            eveningMinutes = 1_439,
            stillReminderEnabled = true,
            stillAnswered = false,
        )

    private val turnOff =
        ShadeActionMsg(
            kind = ShadeActionKindMsg.TURN_OFF,
            sinceMs = 1_780_000_000_123,
            atMs = 1_781_000_000_000,
            generations = listOf(VolumeGenerationMsg("external_primary", 90_300), VolumeGenerationMsg("1a2b-3c4d", 9)),
        )

    @Before
    fun setUp() {
        prefs = ProcessPrefs()
        store = BackgroundStateStore(prefs)
    }

    /** The preferences as a new process would read them: the committed values only. */
    private fun afterProcessEnd(): SharedPreferences = prefs.afterProcessEnd()

    @Test
    fun `store round trips the state`() {
        assertEquals(BackgroundState.OFF, store.state())
        store.write(on)
        assertEquals(on, store.state())
        // A new process reads the same state from disk.
        assertEquals(on, BackgroundStateStore(afterProcessEnd()).state())

        // Off, with nothing: the null since and the empty lists survive too.
        store.write(BackgroundState.OFF)
        assertEquals(BackgroundState.OFF, BackgroundStateStore(afterProcessEnd()).state())

        // The message from Dart becomes the same state.
        val msg =
            BackgroundStateMsg(
                shootingOn = true,
                sinceMs = 1_780_000_000_123,
                baselines =
                    listOf(
                        VolumeBaselineMsg("external_primary", "abc123", 90_210),
                        VolumeBaselineMsg("1a2b-3c4d", "v2", 7),
                    ),
                watchedFolders = listOf("DCIM/Camera/", "Movies/Café/"),
                waitingShotMs = listOf(1_780_000_000_000, 1_780_000_500_000),
                eveningEnabled = true,
                eveningMinutes = 1_439,
                stillReminderEnabled = true,
                stillAnswered = false,
                copiesReminders = emptyList(),
            )
        assertEquals(on, BackgroundState.from(msg))
    }

    @Test
    fun `corrupt state reads as off`() {
        for (text in listOf(
            "{\"shootingOn\": true, \"sinceMs\": ",
            "[]",
            "{}",
            // A field of the wrong shape.
            on.toJson().replace("\"baselines\":[", "\"baselines\":[1,"),
            on.toJson().replace("\"waitingShotMs\":[", "\"waitingShotMs\":[\"soon\","),
        )) {
            prefs.edit().putString(BackgroundStateStore.KEY_STATE, text).commit()
            assertEquals(text, BackgroundState.OFF, store.state())
        }
        // Not a string at all.
        prefs.edit().putInt(BackgroundStateStore.KEY_STATE, 1).commit()
        assertEquals(BackgroundState.OFF, store.state())
        // The next write replaces it.
        store.write(on)
        assertEquals(on, store.state())
    }

    @Test
    fun `clear shade action only clears the same atMs`() {
        assertNull(store.shadeAction())
        store.putShadeAction(turnOff)
        assertEquals(turnOff, store.shadeAction())

        // Another action's atMs (an older one Dart already applied) leaves it.
        store.clearShadeAction(turnOff.atMs - 1)
        store.clearShadeAction(turnOff.atMs + 1)
        assertEquals(turnOff, BackgroundStateStore(afterProcessEnd()).shadeAction())

        // A newer action replaces it; clearing the older atMs keeps the newer.
        val keepOn = ShadeActionMsg(ShadeActionKindMsg.KEEP_ON, turnOff.sinceMs, turnOff.atMs + 60_000, emptyList())
        store.putShadeAction(keepOn)
        store.clearShadeAction(turnOff.atMs)
        assertEquals(keepOn, store.shadeAction())

        store.clearShadeAction(keepOn.atMs)
        assertNull(store.shadeAction())
        assertNull(BackgroundStateStore(afterProcessEnd()).shadeAction())

        // A corrupt or unknown action reads as none.
        prefs.edit().putString(BackgroundStateStore.KEY_SHADE_ACTION, "{\"kind\":\"explode\",\"sinceMs\":1,\"atMs\":2,\"generations\":[]}").commit()
        assertNull(store.shadeAction())
        prefs.edit().putString(BackgroundStateStore.KEY_SHADE_ACTION, "{\"kind\":").commit()
        assertNull(store.shadeAction())
    }

    @Test
    fun `posted count persists`() {
        assertEquals(0, store.postedNewClips())
        store.setPostedNewClips(7)
        assertEquals(7, store.postedNewClips())
        assertEquals(7, BackgroundStateStore(afterProcessEnd()).postedNewClips())
        store.setPostedNewClips(0)
        assertEquals(0, BackgroundStateStore(afterProcessEnd()).postedNewClips())
        // A value of the wrong type reads as 0.
        prefs.edit().putString(BackgroundStateStore.KEY_POSTED_NEW_CLIPS, "7").commit()
        assertEquals(0, store.postedNewClips())
    }

    @Test
    fun `still posted since round trips and survives the process ending`() {
        assertNull(store.stillPostedSince())
        store.setStillPostedSince(1_780_000_000_123)
        assertEquals(1_780_000_000_123, store.stillPostedSince())
        assertEquals(1_780_000_000_123, BackgroundStateStore(afterProcessEnd()).stillPostedSince())
        // The next session replaces it.
        store.setStillPostedSince(1_790_000_000_000)
        assertEquals(1_790_000_000_000, BackgroundStateStore(afterProcessEnd()).stillPostedSince())
        // Zero is a value, not "missing".
        store.setStillPostedSince(0)
        assertEquals(0L, BackgroundStateStore(afterProcessEnd()).stillPostedSince())
        // A value of the wrong type reads as missing, and the next write replaces it.
        prefs.edit().putString(BackgroundStateStore.KEY_STILL_POSTED_SINCE, "7").commit()
        assertNull(store.stillPostedSince())
        prefs.edit().putInt(BackgroundStateStore.KEY_STILL_POSTED_SINCE, 7).commit()
        assertNull(store.stillPostedSince())
        store.setStillPostedSince(5)
        assertEquals(5L, store.stillPostedSince())
    }

    @Test
    fun `evening handled day round trips and survives the process ending`() {
        assertNull(store.eveningHandledDay())
        store.setEveningHandledDay(20_400)
        assertEquals(20_400L, store.eveningHandledDay())
        assertEquals(20_400L, BackgroundStateStore(afterProcessEnd()).eveningHandledDay())
        // Day 0 (1 January 1970) is a value too.
        store.setEveningHandledDay(0)
        assertEquals(0L, BackgroundStateStore(afterProcessEnd()).eveningHandledDay())
        // Wrong type: missing; the next write replaces it.
        prefs.edit().putString(BackgroundStateStore.KEY_EVENING_HANDLED_DAY, "20400").commit()
        assertNull(store.eveningHandledDay())
        store.setEveningHandledDay(20_401)
        assertEquals(20_401L, store.eveningHandledDay())
    }

    @Test
    fun `evening armed for round trips, clears to null and survives the process ending`() {
        assertNull(store.eveningArmedFor())
        store.setEveningArmedFor(1_780_000_000_000)
        assertEquals(1_780_000_000_000, BackgroundStateStore(afterProcessEnd()).eveningArmedFor())
        // The same value again changes nothing; a new one replaces it.
        store.setEveningArmedFor(1_780_000_000_000)
        store.setEveningArmedFor(1_780_086_400_000)
        assertEquals(1_780_086_400_000, BackgroundStateStore(afterProcessEnd()).eveningArmedFor())
        // Null removes it, on disk as well.
        store.setEveningArmedFor(null)
        assertNull(store.eveningArmedFor())
        assertNull(BackgroundStateStore(afterProcessEnd()).eveningArmedFor())
        assertEquals(false, afterProcessEnd().contains(BackgroundStateStore.KEY_EVENING_ARMED_FOR))
        // Wrong type: missing, and writing a value replaces it (it differs from "missing").
        prefs.edit().putString(BackgroundStateStore.KEY_EVENING_ARMED_FOR, "soon").commit()
        assertNull(store.eveningArmedFor())
        store.setEveningArmedFor(42)
        assertEquals(42L, store.eveningArmedFor())
    }

    @Test
    fun `the three reminder keys are independent of the state and of each other`() {
        store.setStillPostedSince(1)
        store.setEveningHandledDay(2)
        store.setEveningArmedFor(3)
        store.write(on)
        store.write(BackgroundState.OFF)
        assertEquals(1L, store.stillPostedSince())
        assertEquals(2L, store.eveningHandledDay())
        assertEquals(3L, store.eveningArmedFor())
    }

    // ---- The copies reminders (Phase 8, D-124) ----

    private val wedding = BackgroundState.CopiesReminder(7, "Wedding \"Goa\" \u00e9\u00e8 \ud83c\udfac", 1_234_567_890, 1_780_000_000_000)
    private val trip = BackgroundState.CopiesReminder(9, "Trip", 0, 1_780_100_000_000)

    /** The JSON a Phase 6 build stored: the same fields, and no `copiesReminders`. */
    private fun phase6Json(): String =
        JSONObject(on.toJson()).also { it.remove("copiesReminders") }.toString()

    @Test
    fun `a stored Phase 6 state without copies reminders loads with an empty list`() {
        val old = phase6Json()
        assertFalse("the fixture is the old shape", "copiesReminders" in old)
        prefs.edit().putString(BackgroundStateStore.KEY_STATE, old).commit()
        assertEquals(on.copy(copiesReminders = emptyList()), store.state())
        assertEquals(emptyList<BackgroundState.CopiesReminder>(), store.state().copiesReminders)
        // The next write adds the field and keeps it.
        store.write(store.state().copy(copiesReminders = listOf(wedding)))
        assertEquals(listOf(wedding), BackgroundStateStore(afterProcessEnd()).state().copiesReminders)
    }

    @Test
    fun `copies reminders round trip, in order, and survive the process ending`() {
        val state = on.copy(copiesReminders = listOf(trip, wedding))
        store.write(state)
        assertEquals(state, store.state())
        assertEquals(listOf(trip, wedding), BackgroundStateStore(afterProcessEnd()).state().copiesReminders)
        // Empty is empty.
        store.write(state.copy(copiesReminders = emptyList()))
        assertEquals(emptyList<BackgroundState.CopiesReminder>(), BackgroundStateStore(afterProcessEnd()).state().copiesReminders)
    }

    @Test
    fun `the message from Dart carries its copies reminders`() {
        val msg =
            BackgroundStateMsg(
                shootingOn = false,
                sinceMs = null,
                baselines = emptyList(),
                watchedFolders = emptyList(),
                waitingShotMs = emptyList(),
                eveningEnabled = false,
                eveningMinutes = 0,
                stillReminderEnabled = false,
                stillAnswered = false,
                copiesReminders =
                    listOf(
                        CopiesReminderMsg(7, "Wedding", 1_234_567_890, 1_780_000_000_000),
                        CopiesReminderMsg(9, "Trip", 5, 1_780_100_000_000),
                    ),
            )
        assertEquals(
            listOf(
                BackgroundState.CopiesReminder(7, "Wedding", 1_234_567_890, 1_780_000_000_000),
                BackgroundState.CopiesReminder(9, "Trip", 5, 1_780_100_000_000),
            ),
            BackgroundState.from(msg).copiesReminders,
        )
    }

    @Test
    fun `a malformed copies reminders field makes the whole state read as off`() {
        val good = JSONObject(on.copy(copiesReminders = listOf(wedding)).toJson())
        for (bad in listOf<Any>(
            "soon",
            JSONArray().put(1),
            JSONArray().put(JSONObject().put("reelId", 7)),
            JSONArray().put(JSONObject().put("reelId", "seven").put("reelName", "W").put("copyBytes", 1).put("lastCopiedAtMs", 2)),
            JSONArray().put(JSONObject().put("reelId", 7).put("reelName", "W").put("copyBytes", 1).put("lastCopiedAtMs", "now")),
        )) {
            prefs.edit().putString(BackgroundStateStore.KEY_STATE, JSONObject(good.toString()).put("copiesReminders", bad).toString()).commit()
            assertEquals("$bad", BackgroundState.OFF, store.state())
        }
    }

    @Test
    fun `usable copies reminders have a valid reel id and time, one per reel, the newest`() {
        val max = BackgroundState.MAX_REEL_ID
        fun r(
            id: Long,
            at: Long = 1_780_000_000_000,
        ) = BackgroundState.CopiesReminder(id, "R$id", 10, at)
        val state =
            BackgroundState.OFF.copy(
                copiesReminders =
                    listOf(
                        r(0), // not a reel id
                        r(-997), // would land on Phase 6's notification 3
                        r(-999),
                        r(max + 1), // its request code would overflow
                        r(Long.MAX_VALUE),
                        r(1, at = 0), // no time known
                        r(2, at = -5),
                        r(3, at = 1_000),
                        r(3, at = 5_000), // the same reel twice: the newer
                        r(3, at = 2_000),
                        r(max),
                        r(1),
                    ),
            )
        assertEquals(
            listOf(r(3, at = 5_000), r(max), r(1)).sortedBy { it.reelId },
            state.usableCopiesReminders().sortedBy { it.reelId },
        )
    }

    @Test
    fun `copies shown marks round trip per reel and survive the process ending`() {
        assertNull(store.copiesShown(7))
        store.setCopiesShown(7, 1_780_000_000_000)
        store.setCopiesShown(9, 1_780_100_000_000)
        assertEquals(1_780_000_000_000, store.copiesShown(7))
        assertEquals(1_780_100_000_000, BackgroundStateStore(afterProcessEnd()).copiesShown(9))
        assertNull(BackgroundStateStore(afterProcessEnd()).copiesShown(8))
        // A new batch replaces the mark of that reel only.
        store.setCopiesShown(7, 1_790_000_000_000)
        assertEquals(1_790_000_000_000, BackgroundStateStore(afterProcessEnd()).copiesShown(7))
        assertEquals(1_780_100_000_000, store.copiesShown(9))
        // Independent of the mirror, which is written over and over.
        store.write(on)
        store.write(BackgroundState.OFF)
        assertEquals(1_790_000_000_000, store.copiesShown(7))
    }

    @Test
    fun `pruning the shown marks keeps exactly the reels named`() {
        store.setCopiesShown(7, 1)
        store.setCopiesShown(9, 2)
        store.setCopiesShown(11, 3)
        store.pruneCopiesShown(setOf(9, 12))
        assertNull(store.copiesShown(7))
        assertEquals(2L, BackgroundStateStore(afterProcessEnd()).copiesShown(9))
        assertNull(store.copiesShown(11))
        // Nothing to keep: all go. Pruning nothing twice is harmless.
        store.pruneCopiesShown(emptySet())
        store.pruneCopiesShown(emptySet())
        assertNull(BackgroundStateStore(afterProcessEnd()).copiesShown(9))
    }

    @Test
    fun `an unreadable shown marks value reads as no marks and the next write replaces it`() {
        for (junk in listOf("[]", "{\"7\": \"soon\"}", "not json", "")) {
            prefs.edit().putString(BackgroundStateStore.KEY_COPIES_SHOWN, junk).commit()
            assertNull(junk, store.copiesShown(7))
            store.pruneCopiesShown(setOf(7)) // must not throw
            store.setCopiesShown(7, 42)
            assertEquals(junk, 42L, store.copiesShown(7))
            prefs.edit().remove(BackgroundStateStore.KEY_COPIES_SHOWN).commit()
        }
        prefs.edit().putInt(BackgroundStateStore.KEY_COPIES_SHOWN, 3).commit()
        assertNull(store.copiesShown(7))
        store.setCopiesShown(7, 43)
        assertEquals(43L, store.copiesShown(7))
    }

    @Test
    fun `the store works on the real native preferences`() {
        val context: Context = ApplicationProvider.getApplicationContext()
        val real = context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
        real.edit().clear().commit()
        BackgroundStateStore(real).write(on)
        BackgroundStateStore(real).setPostedNewClips(3)
        // Another store (the job, a receiver) on the same preferences.
        val other = BackgroundStateStore(context.getSharedPreferences("taketray_native", Context.MODE_PRIVATE))
        assertEquals(on, other.state())
        assertEquals(3, other.postedNewClips())
        // A value of the wrong type in the real preferences reads as off.
        real.edit().putInt(BackgroundStateStore.KEY_STATE, 1).commit()
        assertEquals(BackgroundState.OFF, other.state())
    }
}
