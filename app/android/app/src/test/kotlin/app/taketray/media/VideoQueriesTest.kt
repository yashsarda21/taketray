package app.taketray.media

import android.content.ContentResolver
import android.database.MatrixCursor
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** The selections, query arguments and row mapping of the MediaStore queries. */
@RunWith(RobolectricTestRunner::class)
class VideoQueriesTest {
    private val folderTerm = "${MediaColumns.RELATIVE_PATH} = ? COLLATE NOCASE"
    private val sinceTerm =
        "(${MediaColumns.DATE_TAKEN} >= ? OR ${MediaColumns.DATE_ADDED} >= ? OR " +
            "${MediaColumns.DATE_MODIFIED} >= ? OR ${MediaColumns.DATE_ADDED} IS NULL)"

    @Test
    fun `addedAfterSelection with one folder`() {
        val (selection, args) = VideoQueries.addedAfterSelection(41, listOf("DCIM/Camera/"))
        assertEquals("${MediaColumns.GENERATION_ADDED} > ? AND ($folderTerm)", selection)
        assertArrayEquals(arrayOf("41", "DCIM/Camera/"), args)
    }

    @Test
    fun `addedAfterSelection with two folders`() {
        val (selection, args) = VideoQueries.addedAfterSelection(7, listOf("DCIM/Camera/", "Movies/Reels/"))
        assertEquals("${MediaColumns.GENERATION_ADDED} > ? AND ($folderTerm OR $folderTerm)", selection)
        assertArrayEquals(arrayOf("7", "DCIM/Camera/", "Movies/Reels/"), args)
    }

    @Test
    fun `trailing and leading slashes are normalised`() {
        val (_, args) =
            VideoQueries.addedAfterSelection(0, listOf("DCIM/Camera", "/DCIM/Camera/", "//Movies//", "Movies/Reels///"))
        assertArrayEquals(arrayOf("0", "DCIM/Camera/", "DCIM/Camera/", "Movies/", "Movies/Reels/"), args)
    }

    @Test
    fun `an empty folder list matches nothing`() {
        val (selection, args) = VideoQueries.addedAfterSelection(5, emptyList())
        assertEquals("${MediaColumns.GENERATION_ADDED} > ? AND 0", selection)
        assertArrayEquals(arrayOf("5"), args)
        val (shotSelection, shotArgs) = VideoQueries.shotSinceSelection(emptyList(), 1000)
        assertEquals("0 AND $sinceTerm", shotSelection)
        assertArrayEquals(arrayOf("1000", "1", "1"), shotArgs)
    }

    @Test
    fun `shotSinceSelection args are ms for DATE_TAKEN and whole seconds for the other two`() {
        val (selection, args) = VideoQueries.shotSinceSelection(listOf("DCIM/Camera"), 1_999)
        assertEquals("($folderTerm) AND $sinceTerm", selection)
        assertArrayEquals(arrayOf("DCIM/Camera/", "1999", "1", "1"), args)
        val (_, later) = VideoQueries.shotSinceSelection(listOf("A/", "B/"), 1_780_000_000_999)
        assertArrayEquals(arrayOf("A/", "B/", "1780000000999", "1780000000", "1780000000"), later)
    }

    @Test
    fun `idsSelection at 1 and 500 ids, and 501 is refused`() {
        val (one, oneArgs) = VideoQueries.idsSelection(listOf(42))
        assertEquals("${MediaColumns._ID} IN (?)", one)
        assertArrayEquals(arrayOf("42"), oneArgs)

        val ids = (1L..500L).toList()
        val (many, manyArgs) = VideoQueries.idsSelection(ids)
        assertEquals("${MediaColumns._ID} IN (${List(500) { "?" }.joinToString(",")})", many)
        assertArrayEquals(ids.map { it.toString() }.toTypedArray(), manyArgs)

        assertThrows(IllegalArgumentException::class.java) { VideoQueries.idsSelection((1L..501L).toList()) }
        assertThrows(IllegalArgumentException::class.java) { VideoQueries.idsSelection(emptyList()) }
    }

    @Test
    fun `query args include or exclude pending rows per method, never trashed ones`() {
        val added = VideoQueries.addedAfterArgs(3, listOf("DCIM/Camera/"), 50)
        assertEquals(MediaStore.MATCH_INCLUDE, added.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
        assertEquals(MediaStore.MATCH_EXCLUDE, added.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED))
        assertEquals(
            "${MediaColumns.GENERATION_ADDED} ASC, ${MediaColumns._ID} ASC",
            added.getString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER),
        )
        assertEquals(50, added.getInt(ContentResolver.QUERY_ARG_LIMIT))
        assertEquals(
            VideoQueries.addedAfterSelection(3, listOf("DCIM/Camera/")).first,
            added.getString(ContentResolver.QUERY_ARG_SQL_SELECTION),
        )

        val shot = VideoQueries.shotSinceArgs(listOf("DCIM/Camera/"), 1000)
        assertEquals(MediaStore.MATCH_EXCLUDE, shot.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
        assertEquals(MediaStore.MATCH_EXCLUDE, shot.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED))

        val all = VideoQueries.allVideosArgs()
        assertEquals(MediaStore.MATCH_EXCLUDE, all.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
        assertEquals(MediaStore.MATCH_EXCLUDE, all.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED))

        val byIds = VideoQueries.idsArgs(listOf(1, 2))
        assertEquals(MediaStore.MATCH_INCLUDE, byIds.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
        assertEquals(MediaStore.MATCH_EXCLUDE, byIds.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED))
    }

    @Test
    fun `a huge limit is capped to Int MAX_VALUE`() {
        val args = VideoQueries.addedAfterArgs(0, listOf("A/"), Long.MAX_VALUE)
        assertEquals(Int.MAX_VALUE, args.getInt(ContentResolver.QUERY_ARG_LIMIT))
    }

    @Test
    fun `rowFrom with every nullable column null`() {
        val cursor = MatrixCursor(VideoQueries.PROJECTION)
        cursor.addRow(row(id = 9, generation = 77))
        cursor.moveToFirst()
        val msg = VideoQueries.rowFrom(cursor, "external_primary")
        assertEquals(
            VideoRowMsg(
                volumeName = "external_primary",
                mediaStoreId = 9,
                generationAdded = 77,
                sizeBytes = 0,
                durationMs = null,
                dateTakenMs = null,
                dateAddedSec = null,
                dateModifiedSec = null,
                displayName = "",
                relativePath = "",
                width = null,
                height = null,
                mimeType = null,
                isPending = false,
            ),
            msg,
        )
    }

    @Test
    fun `rowFrom with every column set`() {
        val cursor = MatrixCursor(VideoQueries.PROJECTION)
        cursor.addRow(
            row(
                id = 12,
                generation = 300,
                size = 123_456_789,
                duration = 15_000,
                dateTaken = 1_780_000_000_123,
                dateAdded = 1_780_000_001,
                dateModified = 1_780_000_002,
                name = "VID_1.mp4",
                path = "DCIM/Camera/",
                width = 1920,
                height = 1080,
                mime = "video/mp4",
                pending = 0,
            ),
        )
        cursor.moveToFirst()
        assertEquals(
            VideoRowMsg(
                volumeName = "abcd-1234",
                mediaStoreId = 12,
                generationAdded = 300,
                sizeBytes = 123_456_789,
                durationMs = 15_000,
                dateTakenMs = 1_780_000_000_123,
                dateAddedSec = 1_780_000_001,
                dateModifiedSec = 1_780_000_002,
                displayName = "VID_1.mp4",
                relativePath = "DCIM/Camera/",
                width = 1920,
                height = 1080,
                mimeType = "video/mp4",
                isPending = false,
            ),
            VideoQueries.rowFrom(cursor, "abcd-1234"),
        )
    }

    @Test
    fun `isPending mapping`() {
        val cursor = MatrixCursor(VideoQueries.PROJECTION)
        cursor.addRow(row(id = 1, generation = 1, pending = 1))
        cursor.addRow(row(id = 2, generation = 2, pending = 0))
        cursor.moveToPosition(0)
        assertTrue(VideoQueries.rowFrom(cursor, "external_primary").isPending)
        cursor.moveToPosition(1)
        assertFalse(VideoQueries.rowFrom(cursor, "external_primary").isPending)
    }

    @Test
    fun `rowFrom reads columns by name, not by position`() {
        val reversed = VideoQueries.PROJECTION.reversedArray()
        val cursor = MatrixCursor(reversed)
        val values = row(id = 5, generation = 6, size = 7, name = "a.mp4", path = "P/", pending = 1)
        cursor.addRow(values.reversedArray())
        cursor.moveToFirst()
        val msg = VideoQueries.rowFrom(cursor, "v")
        assertEquals(5L, msg.mediaStoreId)
        assertEquals(6L, msg.generationAdded)
        assertEquals(7L, msg.sizeBytes)
        assertEquals("a.mp4", msg.displayName)
        assertEquals("P/", msg.relativePath)
        assertTrue(msg.isPending)
    }

    /** One cursor row in [VideoQueries.PROJECTION] order. */
    private fun row(
        id: Long,
        generation: Long?,
        size: Long? = null,
        duration: Long? = null,
        dateTaken: Long? = null,
        dateAdded: Long? = null,
        dateModified: Long? = null,
        name: String? = null,
        path: String? = null,
        width: Long? = null,
        height: Long? = null,
        mime: String? = null,
        pending: Long? = null,
    ): Array<Any?> {
        val byColumn =
            mapOf(
                MediaColumns._ID to id,
                MediaColumns.GENERATION_ADDED to generation,
                MediaColumns.SIZE to size,
                MediaColumns.DURATION to duration,
                MediaColumns.DATE_TAKEN to dateTaken,
                MediaColumns.DATE_ADDED to dateAdded,
                MediaColumns.DATE_MODIFIED to dateModified,
                MediaColumns.DISPLAY_NAME to name,
                MediaColumns.RELATIVE_PATH to path,
                MediaColumns.WIDTH to width,
                MediaColumns.HEIGHT to height,
                MediaColumns.MIME_TYPE to mime,
                MediaColumns.IS_PENDING to pending,
            )
        return VideoQueries.PROJECTION.map { byColumn.getValue(it) }.toTypedArray()
    }
}
