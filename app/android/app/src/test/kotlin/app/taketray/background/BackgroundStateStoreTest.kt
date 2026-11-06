package app.taketray.background

import android.content.Context
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
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
