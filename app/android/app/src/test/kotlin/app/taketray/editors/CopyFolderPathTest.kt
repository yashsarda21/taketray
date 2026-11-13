package app.taketray.editors

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The one folder match the guard and the copy engine share (plain JUnit). */
class CopyFolderPathTest {
    @Test
    fun `the relative path is the root, the folder and one slash`() {
        assertEquals("Movies/TakeTray/", CopyFolderPath.ROOT)
        assertEquals("Movies/TakeTray/Goa/", CopyFolderPath.relativePath("Goa"))
        assertEquals("Movies/TakeTray/Goa trip (2)/", CopyFolderPath.relativePath("Goa trip (2)"))
    }

    @Test
    fun `the folder itself matches, in any case`() {
        assertTrue(CopyFolderPath.isInFolder("Movies/TakeTray/Goa/", "Goa"))
        assertTrue(CopyFolderPath.isInFolder("movies/taketray/goa/", "Goa"))
        assertTrue(CopyFolderPath.isInFolder("MOVIES/TAKETRAY/GOA/", "goa"))
    }

    @Test
    fun `a deeper folder, a sibling, the test folder and no path never match`() {
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray/Goa/sub/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray Test/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray Test/Goa/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray/Goa2/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray/Go/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("Movies/TakeTray/Goa", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("DCIM/Camera/", "Goa"))
        assertFalse(CopyFolderPath.isInFolder("", "Goa"))
        assertFalse(CopyFolderPath.isInFolder(null, "Goa"))
    }

    @Test
    fun `isOwn is exact`() {
        assertTrue(CopyFolderPath.isOwn("app.taketray", "app.taketray"))
        assertFalse(CopyFolderPath.isOwn("app.taketray.dev", "app.taketray"))
        assertFalse(CopyFolderPath.isOwn("app.taketray", "app.taketray.dev"))
        assertFalse(CopyFolderPath.isOwn("APP.TAKETRAY", "app.taketray"))
        assertFalse(CopyFolderPath.isOwn(null, "app.taketray"))
        assertFalse(CopyFolderPath.isOwn("", "app.taketray"))
    }
}
