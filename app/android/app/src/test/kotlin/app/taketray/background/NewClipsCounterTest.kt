package app.taketray.background

import android.app.Application
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import app.taketray.background.NewClipsCounter.NewClips
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The new-clips count (D-104) against a real SQLite video table
 * ([SqlVideoProvider]): only finished, non-empty videos added after a
 * volume's baseline, in a watched folder, on a volume whose MediaStore version
 * still matches the baseline's. Anything uncertain counts nothing, never
 * everything.
 */
@RunWith(RobolectricTestRunner::class)
class NewClipsCounterTest {
    private val main = MediaStore.VOLUME_EXTERNAL_PRIMARY
    private val card = "1a2b-3c4d"

    private var versions = mutableMapOf<String, String?>(main to "v1", card to "c1")
    private var access = true

    /** Far after the fixture rows (1.78e9 s), so none of them is recent unless a test says so. */
    private var clockMs = 1_790_000_000_000L

    private val counter by lazy {
        val app = ApplicationProvider.getApplicationContext<Application>()
        NewClipsCounter(app.contentResolver, { versions[it] }, { access }, { clockMs })
    }

    private fun state(
        baselines: List<BackgroundState.Baseline> = listOf(BackgroundState.Baseline(main, "v1", 100)),
        folders: List<String> = listOf("DCIM/Camera/", "Movies/Reels"),
        on: Boolean = true,
    ) = BackgroundState.OFF.copy(shootingOn = on, sinceMs = if (on) 1_780_000_000_000 else null, baselines = baselines, watchedFolders = folders)

    @Before
    fun setUp() = SqlVideoProvider.install()

    @Test
    fun `counts videos after the baseline in watched folders`() {
        SqlVideoProvider.add(id = 1, generation = 99)
        SqlVideoProvider.add(id = 2, generation = 100) // the baseline itself: already scanned
        SqlVideoProvider.add(id = 3, generation = 101)
        SqlVideoProvider.add(id = 4, generation = 102, path = "dcim/camera/") // case of A to Z ignored
        SqlVideoProvider.add(id = 5, generation = 103, path = "Movies/Reels/") // second folder, asked without its slash
        SqlVideoProvider.add(id = 6, generation = 104, trashed = true)
        assertEquals(3, counter.count(state()).count)
    }

    @Test
    fun `pending rows are not counted`() {
        // A recording still in progress (a 4-hour one, or one of a burst) is
        // pending until the camera finishes it; it counts once it is finished.
        SqlVideoProvider.add(id = 1, generation = 101, pending = true, duration = null, size = 0)
        SqlVideoProvider.add(id = 2, generation = 102, pending = true)
        SqlVideoProvider.add(id = 3, generation = 103)
        assertEquals(NewClips(1, main to 3L, listOf(1_780_000_000_000), 1_780_000_000_000), counter.count(state()))
    }

    @Test
    fun `zero duration not counted`() {
        SqlVideoProvider.add(id = 1, generation = 101, duration = 0)
        SqlVideoProvider.add(id = 2, generation = 102, duration = null)
        SqlVideoProvider.add(id = 3, generation = 103, size = 0)
        SqlVideoProvider.add(id = 4, generation = 104, size = null)
        SqlVideoProvider.add(id = 5, generation = 105, duration = 1, size = 1)
        assertEquals(1, counter.count(state()).count)
    }

    @Test
    fun `unwatched folder not counted`() {
        SqlVideoProvider.add(id = 1, generation = 101, path = "Download/")
        SqlVideoProvider.add(id = 2, generation = 102, path = "DCIM/Camera/Sub/")
        SqlVideoProvider.add(id = 3, generation = 103, path = null)
        SqlVideoProvider.add(id = 4, generation = 104)
        assertEquals(1, counter.count(state()).count)
        // No watched folder at all: nothing, and still valid SQL.
        assertEquals(NewClipsCounter.NONE, counter.count(state(folders = emptyList())))
    }

    @Test
    fun `version change counts nothing`() {
        // The library was rebuilt (a new version): its generations start again,
        // so "after 100" would count old videos as new. The card still matches.
        versions[main] = "v2"
        SqlVideoProvider.add(id = 1, generation = 101)
        SqlVideoProvider.add(id = 2, generation = 7, volume = card)
        val both = listOf(BackgroundState.Baseline(main, "v1", 100), BackgroundState.Baseline(card, "c1", 5))
        assertEquals(NewClips(1, card to 2L, listOf(1_780_000_000_000), 1_780_000_000_000), counter.count(state(baselines = both)))
        assertEquals(listOf(card), SqlVideoProvider.queries)
    }

    @Test
    fun `the last touched time is the latest added or modified time of any counted row`() {
        assertNull(counter.count(state()).lastTouchedMs)
        SqlVideoProvider.add(id = 1, generation = 101, added = 1_780_000_100, modified = 1_780_000_900)
        SqlVideoProvider.add(id = 2, generation = 102, added = 1_780_000_500, modified = null)
        SqlVideoProvider.add(id = 3, generation = 103, added = null, modified = 1_780_000_700)
        // Not counted: pending, so its newer times say nothing.
        SqlVideoProvider.add(id = 4, generation = 104, added = 1_790_000_000, pending = true)
        assertEquals(1_780_000_900_000, counter.count(state()).lastTouchedMs)
    }

    @Test
    fun `rows with no times give no last touched time`() {
        SqlVideoProvider.add(id = 1, generation = 101, added = null, modified = null)
        assertEquals(1, counter.count(state()).count)
        assertNull(counter.count(state()).lastTouchedMs)
    }

    @Test
    fun `future times beyond a minute are ignored for the last touched time`() {
        clockMs = 1_780_000_000_000
        SqlVideoProvider.add(id = 1, generation = 101, added = 1_779_999_990) // 10 s ago
        SqlVideoProvider.add(id = 2, generation = 102, added = 1_780_000_060, modified = 1_780_086_400) // 1 min and 1 day ahead
        val found = counter.count(state())
        assertEquals(2, found.count)
        assertEquals("1 minute ahead is still clock skew, a day ahead is not a time", 1_780_000_060_000, found.lastTouchedMs)
        SqlVideoProvider.add(id = 3, generation = 103, added = 1_780_000_061)
        assertEquals(1_780_000_060_000, counter.count(state()).lastTouchedMs)
    }

    @Test
    fun `a clip dated a day ahead has no last touched time`() {
        clockMs = 1_780_000_000_000
        SqlVideoProvider.add(id = 1, generation = 101, added = 1_780_086_400, modified = 1_780_086_400)
        val found = counter.count(state())
        assertEquals(1, found.count)
        assertNull(found.lastTouchedMs)
    }

    // ------------------------------------- a recording in progress (D-110)

    private fun recording(
        clipsToo: Boolean = true,
        nowSec: Long = 1_780_000_000,
    ): Boolean {
        clockMs = nowSec * 1000
        if (clipsToo) SqlVideoProvider.add(id = 1, generation = 101, added = nowSec - 3_600)
        return counter.recording(state())
    }

    @Test
    fun `a pending row in a watched folder above the baseline is a recording in progress`() {
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, duration = null, size = 0, added = 1_780_000_000 - 20)
        assertEquals(true, recording())
        // It is not counted as a clip.
        assertEquals(1, counter.count(state()).count)
    }

    @Test
    fun `a finished row alone is not a recording`() {
        assertEquals(false, recording())
    }

    @Test
    fun `a pending row older than 3 hours is a stuck row and is ignored`() {
        val now = 1_780_000_000L
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, added = now - 10_800 - 1)
        assertEquals(false, recording(nowSec = now))
    }

    @Test
    fun `a pending row exactly 3 hours old still counts`() {
        val now = 1_780_000_000L
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, added = now - 10_800)
        assertEquals(true, recording(nowSec = now))
    }

    @Test
    fun `the 3 hours go by the later of added and modified`() {
        val now = 1_780_000_000L
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, added = now - 20_000, modified = now - 60)
        assertEquals(true, recording(nowSec = now))
    }

    @Test
    fun `a pending row with no times is ignored`() {
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, added = null, modified = null)
        assertEquals(false, recording())
    }

    @Test
    fun `a pending row outside the watched folders is ignored`() {
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, path = "Download/", added = 1_780_000_000 - 5)
        assertEquals(false, recording())
    }

    @Test
    fun `a pending row at or below the baseline is ignored`() {
        SqlVideoProvider.add(id = 2, generation = 100, pending = true, added = 1_780_000_000 - 5)
        SqlVideoProvider.add(id = 3, generation = 50, pending = true, added = 1_780_000_000 - 5)
        assertEquals(false, recording())
    }

    @Test
    fun `a trashed pending row is ignored`() {
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, trashed = true, added = 1_780_000_000 - 5)
        assertEquals(false, recording())
    }

    @Test
    fun `a pending row on the card counts, on a volume whose version changed it does not`() {
        val both = listOf(BackgroundState.Baseline(main, "v1", 100), BackgroundState.Baseline(card, "c1", 5))
        clockMs = 1_780_000_000_000
        SqlVideoProvider.add(id = 1, generation = 101, added = 1_780_000_000 - 3_600)
        SqlVideoProvider.add(id = 2, generation = 7, volume = card, pending = true, added = 1_780_000_000 - 5)
        assertEquals(true, counter.recording(state(baselines = both)))
        versions[card] = "c2"
        assertEquals(false, counter.recording(state(baselines = both)))
    }

    @Test
    fun `no recording check without Shooting mode, access or a watched folder`() {
        SqlVideoProvider.add(id = 2, generation = 102, pending = true, added = 1_780_000_000 - 5)
        clockMs = 1_780_000_000_000
        assertEquals(false, counter.recording(state(on = false)))
        assertEquals(false, counter.recording(state(folders = emptyList())))
        access = false
        assertEquals(false, counter.recording(state()))
        assertEquals(0, SqlVideoProvider.pendingQueries)
    }

    @Test
    fun `a failing recording check throws, it does not say no`() {
        clockMs = 1_780_000_000_000
        SqlVideoProvider.add(id = 1, generation = 101, added = 1_780_000_000 - 3_600)
        SqlVideoProvider.pendingFailure = IllegalStateException("provider died")
        assertThrows(IllegalStateException::class.java) { counter.recording(state()) }
        SqlVideoProvider.pendingFailure = null
        SqlVideoProvider.pendingNoCursor = true
        assertThrows(IllegalStateException::class.java) { counter.recording(state()) }
    }

    @Test
    fun `no baseline counts nothing`() {
        // A volume without a baseline (a new SD card) is never queried; an
        // unmounted volume (version null) is skipped.
        SqlVideoProvider.add(id = 1, generation = 1, volume = card)
        assertEquals(NewClipsCounter.NONE, counter.count(state()))
        versions[main] = null
        SqlVideoProvider.add(id = 2, generation = 101)
        assertEquals(NewClipsCounter.NONE, counter.count(state()))
        assertEquals(NewClipsCounter.NONE, counter.count(state(baselines = emptyList())))
        assertEquals(listOf(main), SqlVideoProvider.queries)
    }

    @Test
    fun `no access counts nothing`() {
        SqlVideoProvider.add(id = 1, generation = 101)
        access = false
        assertEquals(NewClipsCounter.NONE, counter.count(state()))
        access = true
        assertEquals(NewClipsCounter.NONE, counter.count(state(on = false)))
        assertEquals(emptyList<String>(), SqlVideoProvider.queries)
    }

    @Test
    fun `newest is the highest generation`() {
        SqlVideoProvider.add(id = 30, generation = 101, taken = 1_780_000_100_000)
        SqlVideoProvider.add(id = 10, generation = 105, taken = 0, added = 1_780_000_300) // DATE_TAKEN 0: DATE_ADDED
        SqlVideoProvider.add(id = 20, generation = 103, taken = null, added = 1_780_000_200)
        val found = counter.count(state())
        assertEquals(3, found.count)
        assertEquals(main to 10L, found.newest)
        assertEquals(listOf(1_780_000_100_000, 1_780_000_200_000, 1_780_000_300_000), found.shotMs.sorted())
    }

    @Test
    fun `on two volumes the newest is the one added last`() {
        // Generations of two volumes are separate counters: the card's newest
        // has the lower generation but was added later.
        SqlVideoProvider.add(id = 1, generation = 900, added = 1_780_000_100)
        SqlVideoProvider.add(id = 2, generation = 6, added = 1_780_000_200, volume = card)
        val both = listOf(BackgroundState.Baseline(main, "v1", 100), BackgroundState.Baseline(card, "c1", 5))
        assertEquals(card to 2L, counter.count(state(baselines = both)).newest)
    }

    @Test
    fun `no cursor is an error, never zero`() {
        // Zero would cancel the notification; the provider being unavailable says nothing.
        SqlVideoProvider.noCursor = true
        assertThrows(IllegalStateException::class.java) { counter.recording(state()) }
    }
}
