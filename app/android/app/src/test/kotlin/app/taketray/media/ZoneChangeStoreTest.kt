package app.taketray.media

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** The native list of time-zone changes, in real (Robolectric) preferences. */
@RunWith(RobolectricTestRunner::class)
class ZoneChangeStoreTest {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private lateinit var store: ZoneChangeStore

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs = context.getSharedPreferences(ZoneChangeStore.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        store = ZoneChangeStore(prefs)
    }

    @Test
    fun `the same zone is not appended twice in a row`() {
        store.record(1_000, "Europe/Berlin")
        store.record(2_000, "Europe/Berlin")
        assertEquals(listOf(ZoneChangeMsg(1_000, "Europe/Berlin")), store.pending())
    }

    @Test
    fun `A then B then A gives 3 entries`() {
        store.record(1_000, "Europe/Berlin")
        store.record(2_000, "Asia/Kolkata")
        store.record(3_000, "Europe/Berlin")
        assertEquals(
            listOf(
                ZoneChangeMsg(1_000, "Europe/Berlin"),
                ZoneChangeMsg(2_000, "Asia/Kolkata"),
                ZoneChangeMsg(3_000, "Europe/Berlin"),
            ),
            store.pending(),
        )
    }

    @Test
    fun `the cap at 500 drops the oldest`() {
        for (i in 0 until 501) store.record(i.toLong(), if (i % 2 == 0) "Europe/Berlin" else "Asia/Kolkata")
        val pending = store.pending()
        assertEquals(500, pending.size)
        assertEquals(ZoneChangeMsg(1, "Asia/Kolkata"), pending.first())
        assertEquals(ZoneChangeMsg(500, "Europe/Berlin"), pending.last())
    }

    @Test
    fun `clearUpTo keeps later entries`() {
        store.record(1_000, "Europe/Berlin")
        store.record(2_000, "Asia/Kolkata")
        store.record(3_000, "UTC")
        store.clearUpTo(2_000)
        assertEquals(listOf(ZoneChangeMsg(3_000, "UTC")), store.pending())
        // A fresh store on the same preferences sees the same list.
        assertEquals(listOf(ZoneChangeMsg(3_000, "UTC")), ZoneChangeStore(prefs).pending())
    }

    @Test
    fun `corrupt JSON reads as empty, and the next record works`() {
        prefs.edit().putString(ZoneChangeStore.KEY, "[{\"atMs\": 1, \"zoneId\": ").commit()
        assertEquals(emptyList<ZoneChangeMsg>(), store.pending())
        store.record(5_000, "UTC")
        assertEquals(listOf(ZoneChangeMsg(5_000, "UTC")), store.pending())
    }

    @Test
    fun `an entry of the wrong shape counts as corrupt`() {
        prefs.edit().putString(ZoneChangeStore.KEY, "[{\"atMs\": 1}]").commit()
        assertEquals(emptyList<ZoneChangeMsg>(), store.pending())
        prefs.edit().putString(ZoneChangeStore.KEY, "{\"atMs\": 1, \"zoneId\": \"UTC\"}").commit()
        assertEquals(emptyList<ZoneChangeMsg>(), store.pending())
    }

    @Test
    fun `the receiver records the zone named in the broadcast`() {
        val intent = Intent(Intent.ACTION_TIMEZONE_CHANGED).putExtra(Intent.EXTRA_TIMEZONE, "America/Denver")
        val before = System.currentTimeMillis()
        TimeZoneChangedReceiver().onReceive(context, intent)
        val after = System.currentTimeMillis()
        val pending = store.pending()
        assertEquals(1, pending.size)
        assertEquals("America/Denver", pending.single().zoneId)
        assert(pending.single().atMs in before..after)
    }

    @Test
    fun `without the extra the receiver records the default zone`() {
        val saved = java.util.TimeZone.getDefault()
        try {
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Tokyo"))
            TimeZoneChangedReceiver().onReceive(context, Intent(Intent.ACTION_TIMEZONE_CHANGED))
        } finally {
            java.util.TimeZone.setDefault(saved)
        }
        assertEquals("Asia/Tokyo", store.pending().single().zoneId)
    }

    @Test
    fun `the receiver ignores any other broadcast`() {
        TimeZoneChangedReceiver().onReceive(context, Intent(Intent.ACTION_TIME_CHANGED))
        assertEquals(emptyList<ZoneChangeMsg>(), store.pending())
    }
}
