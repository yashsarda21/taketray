package app.taketray.media

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteQueryBuilder
import android.provider.MediaStore.MediaColumns
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Runs the selections on a real SQLite table through a query builder set up
 * the way MediaProvider sets one up for other apps (strict, strict columns,
 * strict grammar), so a selection that Android would refuse fails here, and
 * the rows each selection picks can be checked. The phone itself is Task 11.
 */
@RunWith(RobolectricTestRunner::class)
class VideoQueriesSqlTest {
    private lateinit var db: SQLiteDatabase

    private val columns =
        listOf(
            MediaColumns._ID,
            MediaColumns.GENERATION_ADDED,
            MediaColumns.RELATIVE_PATH,
            MediaColumns.DATE_TAKEN,
            MediaColumns.DATE_ADDED,
            MediaColumns.DATE_MODIFIED,
            MediaColumns.DURATION,
        )

    @Before
    fun setUp() {
        db = SQLiteDatabase.create(null)
        db.execSQL(
            "CREATE TABLE video (${MediaColumns._ID} INTEGER PRIMARY KEY, " +
                "${MediaColumns.GENERATION_ADDED} INTEGER, ${MediaColumns.RELATIVE_PATH} TEXT, " +
                "${MediaColumns.DATE_TAKEN} INTEGER, ${MediaColumns.DATE_ADDED} INTEGER, " +
                "${MediaColumns.DATE_MODIFIED} INTEGER, ${MediaColumns.DURATION} INTEGER)",
        )
    }

    @After
    fun tearDown() = db.close()

    private fun insert(
        id: Long,
        generation: Long = 1,
        path: String? = "DCIM/Camera/",
        taken: Long? = null,
        added: Long? = 0,
        modified: Long? = 0,
        duration: Long? = 5_000,
    ) {
        db.execSQL(
            "INSERT INTO video VALUES (?, ?, ?, ?, ?, ?, ?)",
            arrayOf<Any?>(id, generation, path, taken, added, modified, duration),
        )
    }

    /** The ids a selection picks, through a strict builder like MediaProvider's. */
    private fun ids(selection: Pair<String, Array<String>>): List<Long> {
        val qb =
            SQLiteQueryBuilder().apply {
                tables = "video"
                isStrict = true
                isStrictColumns = true
                isStrictGrammar = true
                projectionMap = columns.associateWith { it }
            }
        qb.query(db, arrayOf(MediaColumns._ID), selection.first, selection.second, null, null, MediaColumns._ID)
            .use { c ->
                val out = mutableListOf<Long>()
                while (c.moveToNext()) out += c.getLong(0)
                return out
            }
    }

    /** The ids of a selection in the given order, through the same strict builder; [limit] as SQL ("3 OFFSET 6"). */
    private fun orderedIds(
        selection: Pair<String, Array<String>>,
        order: String,
        limit: String? = null,
    ): List<Long> {
        val qb =
            SQLiteQueryBuilder().apply {
                tables = "video"
                isStrict = true
                isStrictColumns = true
                isStrictGrammar = true
                projectionMap = columns.associateWith { it }
            }
        qb.query(db, arrayOf(MediaColumns._ID), selection.first, selection.second, null, null, order, limit).use { c ->
            val out = mutableListOf<Long>()
            while (c.moveToNext()) out += c.getLong(0)
            return out
        }
    }

    private fun inFolder(folder: String) = VideoQueries.inFolderSelection(folder)

    @Test
    fun `in-folder picks videos with a positive duration in exactly that folder, ignoring ASCII case only`() {
        insert(1, path = "DCIM/Camera/")
        insert(2, path = "dcim/CAMERA/")
        insert(3, path = "DCIM/Camera/Sub/")
        insert(4, path = "DCIM/Camera") // stored without the slash: not the same folder
        insert(5, path = "DCIM/Camera/", duration = 0)
        insert(6, path = "DCIM/Camera/", duration = null)
        insert(7, path = "DCIM/Other/")
        insert(8, path = "Vidéos/")
        assertEquals(listOf(1L, 2L), ids(inFolder("DCIM/Camera")))
        assertEquals(listOf(1L, 2L), ids(inFolder("/dcim/camera/")))
        assertEquals(listOf(8L), ids(inFolder("Vidéos")))
        assertEquals(emptyList<Long>(), ids(inFolder("VIDÉOS")))
    }

    @Test
    fun `in-folder for the volume root picks an empty or missing path only`() {
        insert(1, path = "")
        insert(2, path = null)
        insert(3, path = "DCIM/")
        insert(4, path = "", duration = 0)
        assertEquals(listOf(1L, 2L), ids(inFolder("")))
        assertEquals(listOf(1L, 2L), ids(inFolder("/")))
    }

    @Test
    fun `shot-time order is newest first by DATE_TAKEN, then DATE_ADDED, then DATE_MODIFIED`() {
        insert(1, taken = 5_000_000, added = 1) // 5_000_000 ms
        insert(2, taken = null, added = 6_000, modified = 1) // DATE_ADDED 6_000 s = 6_000_000 ms: newer than 1
        insert(3, taken = 0, added = 4_000, modified = 1) // a zero DATE_TAKEN is no date: 4_000_000 ms
        insert(4, taken = null, added = null, modified = 7_000) // only DATE_MODIFIED: 7_000_000 ms
        insert(5, taken = null, added = 0, modified = 3_000) // zero DATE_ADDED is no date: 3_000_000 ms
        insert(6, taken = 8_000_000, added = 1, modified = 1) // newest
        insert(7, taken = null, added = null, modified = null) // no date at all: last
        assertEquals(
            listOf(6L, 4L, 2L, 1L, 3L, 5L, 7L),
            orderedIds(inFolder("DCIM/Camera/"), VideoQueries.SHOT_NEWEST_ORDER),
        )
    }

    @Test
    fun `seconds and milliseconds are compared in one unit, and DATE_TAKEN wins over the same clip's DATE_ADDED`() {
        // Seconds and milliseconds must be compared in one unit: 1_780_000_000 s is 1_780_000_000_000 ms.
        insert(1, taken = 1_780_000_000_500, added = 1_780_000_100)
        insert(2, taken = null, added = 1_780_000_001) // 1_780_000_001_000 ms: newer than clip 1's DATE_TAKEN
        insert(3, taken = 1_779_999_999_000, added = 1_790_000_000) // its DATE_ADDED is ignored: DATE_TAKEN rules
        assertEquals(listOf(2L, 1L, 3L), orderedIds(inFolder("DCIM/Camera/"), VideoQueries.SHOT_NEWEST_ORDER))
    }

    @Test
    fun `clips with the same shot time are ordered by id, newest id first`() {
        for (id in listOf(3L, 1L, 4L, 2L)) insert(id, taken = 1_000)
        assertEquals(listOf(4L, 3L, 2L, 1L), orderedIds(inFolder("DCIM/Camera/"), VideoQueries.SHOT_NEWEST_ORDER))
    }

    @Test
    fun `pages never repeat or skip a clip, even when many share a shot time`() {
        // 11 clips: five share one time, three have none, three are distinct.
        for (id in 1L..5L) insert(id, taken = 2_000)
        for (id in 6L..8L) insert(id, taken = null, added = null, modified = null)
        insert(9, taken = 3_000)
        insert(10, taken = 1_000)
        insert(11, taken = 4_000)
        val all = orderedIds(inFolder("DCIM/Camera/"), VideoQueries.SHOT_NEWEST_ORDER)
        assertEquals(11, all.size)
        assertEquals(listOf(11L, 9L, 5L, 4L, 3L, 2L, 1L, 10L, 8L, 7L, 6L), all)
        for (pageSize in listOf(1, 2, 3, 4, 5, 10, 11, 12)) {
            val paged = mutableListOf<Long>()
            var offset = 0
            while (true) {
                val page = orderedIds(inFolder("DCIM/Camera/"), VideoQueries.SHOT_NEWEST_ORDER, "$pageSize OFFSET $offset")
                if (page.isEmpty()) break
                assertTrue(page.size <= pageSize)
                paged += page
                offset += pageSize
            }
            assertEquals("page size $pageSize", all, paged)
        }
    }

    @Test
    fun `added-after picks a higher generation in an exact folder, ignoring ASCII case only`() {
        insert(1, generation = 10, path = "DCIM/Camera/")
        insert(2, generation = 11, path = "DCIM/Camera/")
        insert(3, generation = 12, path = "dcim/CAMERA/")
        insert(4, generation = 13, path = "DCIM/Camera/Sub/")
        insert(5, generation = 14, path = "DCIM/Camera") // stored without the slash: not the same folder
        insert(6, generation = 15, path = "Vidéos/")
        insert(7, generation = 16, path = null)
        assertEquals(listOf(2L, 3L), ids(VideoQueries.addedAfterSelection(10, listOf("/DCIM/Camera"))))
        assertEquals(emptyList<Long>(), ids(VideoQueries.addedAfterSelection(0, listOf("VIDÉOS"))))
        assertEquals(listOf(6L), ids(VideoQueries.addedAfterSelection(0, listOf("Vidéos"))))
    }

    @Test
    fun `an empty folder list is valid SQL and picks nothing`() {
        insert(1, generation = 10)
        assertEquals(emptyList<Long>(), ids(VideoQueries.addedAfterSelection(0, emptyList())))
        assertEquals(emptyList<Long>(), ids(VideoQueries.shotSinceSelection(emptyList(), 0)))
    }

    @Test
    fun `shot-since picks any of the three dates at or after the start, or no DATE_ADDED`() {
        val since = 1_780_000_000_500L // seconds threshold 1_780_000_000
        insert(1, taken = since) // DATE_TAKEN exactly at the start (ms)
        insert(2, taken = since - 1) // one ms before, and old added/modified
        insert(3, added = 1_780_000_000) // DATE_ADDED in the same second (rounded down)
        insert(4, added = 1_779_999_999, modified = 1_780_000_000) // DATE_MODIFIED
        insert(5, added = null) // no DATE_ADDED at all
        insert(6, path = "Other/", taken = since) // wrong folder
        assertEquals(listOf(1L, 3L, 4L, 5L), ids(VideoQueries.shotSinceSelection(listOf("dcim/camera/"), since)))
    }

    @Test
    fun `ids selection picks exactly the ids asked for`() {
        for (id in 1L..600L) insert(id)
        assertEquals(listOf(3L, 500L), ids(VideoQueries.idsSelection(listOf(500, 3, 9999))))
        val chunk = (1L..500L).toList()
        assertEquals(chunk, ids(VideoQueries.idsSelection(chunk)))
    }
}
