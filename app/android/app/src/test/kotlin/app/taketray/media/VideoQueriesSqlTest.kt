package app.taketray.media

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteQueryBuilder
import android.provider.MediaStore.MediaColumns
import org.junit.After
import org.junit.Assert.assertEquals
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
        )

    @Before
    fun setUp() {
        db = SQLiteDatabase.create(null)
        db.execSQL(
            "CREATE TABLE video (${MediaColumns._ID} INTEGER PRIMARY KEY, " +
                "${MediaColumns.GENERATION_ADDED} INTEGER, ${MediaColumns.RELATIVE_PATH} TEXT, " +
                "${MediaColumns.DATE_TAKEN} INTEGER, ${MediaColumns.DATE_ADDED} INTEGER, " +
                "${MediaColumns.DATE_MODIFIED} INTEGER)",
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
    ) {
        db.execSQL(
            "INSERT INTO video VALUES (?, ?, ?, ?, ?, ?)",
            arrayOf<Any?>(id, generation, path, taken, added, modified),
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
