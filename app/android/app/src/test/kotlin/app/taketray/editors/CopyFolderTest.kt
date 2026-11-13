package app.taketray.editors

import android.app.Application
import android.content.ContentResolver
import android.content.ContentUris
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The copy folder guard (D-121) on a real SQLite table through a strict query
 * builder: a row is deleted only when it is exactly in
 * `Movies/TakeTray/<folder>/` (any case), has the recorded name and is owned
 * by TakeTray. Everything else is refused and left untouched.
 */
@RunWith(RobolectricTestRunner::class)
class CopyFolderTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val ours get() = app.packageName
    private val other = "com.other.app"
    private lateinit var folder: CopyFolder

    @Before
    fun setUp() {
        CopyFolderProvider.install()
        folder = CopyFolder(app.contentResolver, ours)
    }

    private fun ref(
        id: Long,
        folderName: String = "Goa",
        name: String = "2026-10-12_14-32-05.mp4",
    ) = CopyFileRefMsg(id, folderName, name)

    private fun own(
        id: Long,
        path: String? = "Movies/TakeTray/Goa/",
        name: String? = "2026-10-12_14-32-05.mp4",
        owner: String? = null,
        size: Long? = 1_000_000,
        pending: Boolean = false,
        trashed: Boolean = false,
    ) = CopyFolderProvider.add(id, path, name, owner ?: ours, size, pending, trashed)

    private fun itemUri(id: Long) = ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), id)

    // ------------------------------------------------------------ the guard

    @Test
    fun `the guard needs the folder, the exact name and TakeTray as owner`() {
        val r = ref(1)
        fun allows(
            path: String?,
            name: String?,
            owner: String?,
            ref: CopyFileRefMsg = r,
        ) = CopyFolder.allowsDelete(path, name, owner, ref, "app.taketray")
        assertTrue(allows("Movies/TakeTray/Goa/", "2026-10-12_14-32-05.mp4", "app.taketray"))
        assertTrue(allows("movies/taketray/GOA/", "2026-10-12_14-32-05.mp4", "app.taketray"))
        assertFalse(allows("Movies/TakeTray Test/", "2026-10-12_14-32-05.mp4", "app.taketray"))
        assertFalse(allows("Movies/TakeTray/Goa/sub/", "2026-10-12_14-32-05.mp4", "app.taketray"))
        assertFalse(allows("DCIM/Camera/", "2026-10-12_14-32-05.mp4", "app.taketray"))
        assertFalse(allows(null, "2026-10-12_14-32-05.mp4", "app.taketray"))
        assertFalse(allows("Movies/TakeTray/Goa/", "2026-10-12_14-32-06.mp4", "app.taketray"))
        assertFalse("the name is compared exactly", allows("Movies/TakeTray/Goa/", "2026-10-12_14-32-05.MP4", "app.taketray"))
        assertFalse(allows("Movies/TakeTray/Goa/", null, "app.taketray"))
        assertFalse(allows("Movies/TakeTray/Goa/", "2026-10-12_14-32-05.mp4", "app.taketray.dev"))
        assertFalse(allows("Movies/TakeTray/Goa/", "2026-10-12_14-32-05.mp4", null))
        assertFalse(allows("Movies/TakeTray/Goa/", "2026-10-12_14-32-05.mp4", "com.other.app"))
    }

    @Test
    fun `a folder name that is not one plain segment is refused`() {
        for (bad in listOf("", ".", "..", "Goa/sub", "../DCIM", "Goa/", "/Goa", "Go\u0000a")) {
            val path = CopyFolderPath.relativePath(bad)
            assertFalse("folder '$bad'", CopyFolder.allowsDelete(path, "a.mp4", "app.taketray", CopyFileRefMsg(1, bad, "a.mp4"), "app.taketray"))
        }
    }

    // ------------------------------------------------------------ deleteCopies

    @Test
    fun `deleteCopies deletes TakeTray's own copy`() {
        own(1)
        own(2, path = "movies/taketray/goa/")

        val report = folder.deleteCopies(listOf(ref(1), ref(2)))

        assertEquals(listOf(1L, 2L), report.deleted)
        assertEquals(emptyList<Long>(), report.gone + report.refused + report.failed)
        assertEquals(emptyList<Long>(), CopyFolderProvider.ids())
    }

    @Test
    fun `deleteCopies refuses and leaves every other row untouched`() {
        own(10, path = "Movies/TakeTray Test/")
        own(11, path = "DCIM/Camera/")
        own(12, path = "Movies/TakeTray/Goa/sub/")
        own(13, path = "Movies/TakeTray/Goa2/")
        own(14, name = "other.mp4")
        own(15, owner = other)
        CopyFolderProvider.add(16, "Movies/TakeTray/Goa/", "2026-10-12_14-32-05.mp4", owner = null)
        own(17, name = "2026-10-12_14-32-05.MP4")
        own(18, path = null)
        own(19, path = "Movies/TakeTray/Goa/sub/")

        val report =
            folder.deleteCopies(
                listOf(ref(10), ref(11), ref(12), ref(13), ref(14), ref(15), ref(16), ref(17), ref(18), ref(19, folderName = "Goa/sub")),
            )

        assertEquals((10L..19L).toList(), report.refused)
        assertEquals(emptyList<Long>(), report.deleted + report.gone + report.failed)
        assertEquals((10L..19L).toList(), CopyFolderProvider.ids())
        assertTrue("nothing was even tried", CopyFolderProvider.deletes.isEmpty())
    }

    @Test
    fun `an id with no row is gone, and the rest go on`() {
        own(1)
        own(3)

        val report = folder.deleteCopies(listOf(ref(1), ref(2), ref(3)))

        assertEquals(listOf(1L, 3L), report.deleted)
        assertEquals(listOf(2L), report.gone)
    }

    @Test
    fun `a delete that throws is failed and the rest continue`() {
        own(1)
        own(2)
        own(3)
        CopyFolderProvider.deleteFailure[2] = SecurityException("no")
        CopyFolderProvider.deleteFailure[3] = IllegalStateException("broken")

        val report = folder.deleteCopies(listOf(ref(1), ref(2), ref(3)))

        assertEquals(listOf(1L), report.deleted)
        assertEquals(listOf(2L, 3L), report.failed)
        assertEquals(listOf(2L, 3L), CopyFolderProvider.ids())
    }

    @Test
    fun `own pending and trashed copies are deleted too`() {
        own(1, pending = true)
        own(2, trashed = true)

        val report = folder.deleteCopies(listOf(ref(1), ref(2)))

        assertEquals(listOf(1L, 2L), report.deleted)
        assertEquals(emptyList<Long>(), CopyFolderProvider.ids())
    }

    @Test
    fun `a row that changes between the check and the delete is not deleted`() {
        own(1)
        own(2)
        CopyFolderProvider.beforeDelete = { id -> if (id == 1L) CopyFolderProvider.rename(1, "someone-else.mp4") }

        val report = folder.deleteCopies(listOf(ref(1), ref(2)))

        assertEquals(listOf(2L), report.deleted)
        assertEquals(listOf(1L), report.gone)
        assertEquals(listOf(1L), CopyFolderProvider.ids())
    }

    @Test
    fun `the delete names the row by its item URI on the primary volume`() {
        own(7)
        folder.deleteCopies(listOf(ref(7)))
        assertEquals(itemUri(7), CopyFolderProvider.deletes.single().uri)
    }

    @Test
    fun `a failing read fails deleteCopies and deletes nothing`() {
        own(1)
        CopyFolderProvider.queryFailure = IllegalStateException("provider died")
        assertThrows(IllegalStateException::class.java) { folder.deleteCopies(listOf(ref(1))) }
        CopyFolderProvider.queryFailure = null
        CopyFolderProvider.noCursor = true
        assertThrows(IOException::class.java) { folder.deleteCopies(listOf(ref(1))) }
        assertEquals(listOf(1L), CopyFolderProvider.ids())
    }

    @Test
    fun `many refs are read in chunks and all are handled`() {
        for (id in 1L..1200L) own(id)
        val report = folder.deleteCopies((1L..1200L).map { ref(it) })
        assertEquals(1200, report.deleted.size)
        assertTrue(CopyFolderProvider.queries.size >= 3)
    }

    @Test
    fun `no refs is an empty report with no query`() {
        val report = folder.deleteCopies(emptyList())
        assertEquals(emptyList<Long>(), report.deleted + report.gone + report.refused + report.failed)
        assertTrue(CopyFolderProvider.queries.isEmpty())
    }

    // ------------------------------------------------------------ existingCopies

    @Test
    fun `existingCopies uses the same match`() {
        own(1)
        own(2, name = "reused.mp4")
        own(3, owner = other)
        own(4, path = "Movies/TakeTray/Goa/sub/")
        own(5, path = "Movies/TakeTray Test/")
        own(6, path = "MOVIES/TAKETRAY/goa/")

        assertEquals(setOf(1L, 6L), folder.existingCopies((1L..7L).map { ref(it) }))
    }

    @Test
    fun `pending and trashed copies are not present`() {
        own(1, pending = true)
        own(2, trashed = true)
        assertEquals(emptySet<Long>(), folder.existingCopies(listOf(ref(1), ref(2))))
    }

    @Test
    fun `a failing query throws, never reads as gone`() {
        own(1)
        CopyFolderProvider.queryFailure = IllegalStateException("provider died")
        assertThrows(IllegalStateException::class.java) { folder.existingCopies(listOf(ref(1))) }
        CopyFolderProvider.queryFailure = null
        CopyFolderProvider.noCursor = true
        assertThrows(IOException::class.java) { folder.existingCopies(listOf(ref(1))) }
    }

    @Test
    fun `existingCopies with no refs asks nothing`() {
        assertEquals(emptySet<Long>(), folder.existingCopies(emptyList()))
        assertTrue(CopyFolderProvider.queries.isEmpty())
    }

    // ------------------------------------------------------------ copyFolderNames

    @Test
    fun `copyFolderNames lists distinct first segments under the root`() {
        own(1, path = "Movies/TakeTray/Goa/")
        own(2, path = "Movies/TakeTray/Goa/")
        own(3, path = "Movies/TakeTray/Goa (2)/sub/")
        own(4, path = "movies/taketray/Kerala/", owner = other)
        own(5, path = "Movies/TakeTray Test/")
        own(6, path = "Movies/TakeTray Test 123/")
        own(7, path = "DCIM/Camera/")
        own(8, path = "Movies/TakeTray/")
        own(9, path = "Movies/TakeTray/Delhi/", pending = true)
        own(10, path = "Movies/Other/TakeTray/Paris/")
        own(11, path = null)

        assertEquals(listOf("Delhi", "Goa", "Goa (2)", "Kerala"), folder.copyFolderNames())
    }

    @Test
    fun `copyFolderNames with a failing query throws`() {
        CopyFolderProvider.noCursor = true
        assertThrows(IOException::class.java) { folder.copyFolderNames() }
    }

    // ------------------------------------------------------------ filesInCopyFolders

    @Test
    fun `filesInCopyFolders lists one level deep with size and owner`() {
        own(1, path = "Movies/TakeTray/Goa/", name = "a.mp4", size = 5)
        own(2, path = "movies/taketray/Kerala/", name = "b.mp4", size = null, owner = other)
        own(3, path = "Movies/TakeTray/Goa/sub/", name = "c.mp4")
        own(4, path = "Movies/TakeTray/", name = "d.mp4")
        own(5, path = "Movies/TakeTray Test/", name = "e.mp4")
        own(6, path = "Movies/TakeTray/Goa/", name = "f.mp4", pending = true)
        own(7, path = "DCIM/Camera/", name = "g.mp4")
        own(8, path = "Movies/TakeTray/Goa/", name = null, size = 9)

        assertEquals(
            listOf(
                CopyFolderFileMsg(1, "Goa", "a.mp4", 5, true),
                CopyFolderFileMsg(2, "Kerala", "b.mp4", 0, false),
                CopyFolderFileMsg(8, "Goa", "", 9, true),
            ),
            folder.filesInCopyFolders(),
        )
    }

    // ------------------------------------------------------------ deletableUris

    @Test
    fun `deletableUris are the rows in their folder with their name, any owner`() {
        own(1)
        own(2, owner = other)
        CopyFolderProvider.add(3, "Movies/TakeTray/Goa/", "2026-10-12_14-32-05.mp4", owner = null)
        own(4, path = "Movies/TakeTray Test/")
        own(5, path = "DCIM/Camera/", owner = other)
        own(6, path = "Movies/TakeTray/Goa/sub/")
        own(7, name = "other.mp4")
        own(9, path = "Movies/TakeTray/Goa/sub/")

        val uris = folder.deletableUris((1L..9L).map { ref(it) } + ref(9, folderName = "Goa/sub"))

        assertEquals(listOf(itemUri(1), itemUri(2), itemUri(3)), uris)
    }

    @Test
    fun `queries use a Bundle with an id selection on the primary volume`() {
        own(1)
        folder.existingCopies(listOf(ref(1)))
        val q = CopyFolderProvider.queries.single()
        assertEquals(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), q.uri)
        assertTrue(q.args!!.getString(ContentResolver.QUERY_ARG_SQL_SELECTION)!!.contains("_id IN"))
    }
}
