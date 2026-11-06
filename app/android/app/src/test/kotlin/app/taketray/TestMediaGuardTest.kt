package app.taketray

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The delete rule (D-77) as a pure function: a row may be deleted only when it
 * is in exactly `Movies/TakeTray Test/` and owned by this very app.
 */
class TestMediaGuardTest {
    private val own = "app.taketray.dev"
    private val folder = "Movies/TakeTray Test/"

    @Test
    fun `the test folder and this app as owner is allowed`() {
        assertTrue(TestMediaGuard.allowsDelete(folder, own, own))
    }

    @Test
    fun `another owner in the test folder is refused`() {
        assertFalse(TestMediaGuard.allowsDelete(folder, "com.sec.android.gallery3d", own))
        assertFalse(TestMediaGuard.allowsDelete(folder, "com.android.providers.media", own))
    }

    @Test
    fun `the release app is not the debug app`() {
        // The real TakeTray's files are never the debug app's to delete, and
        // the other way round.
        assertFalse(TestMediaGuard.allowsDelete(folder, "app.taketray", own))
        assertFalse(TestMediaGuard.allowsDelete(folder, "app.taketray.dev", "app.taketray"))
        assertFalse(TestMediaGuard.allowsDelete(folder, "app.taketray.dev.test", own))
    }

    @Test
    fun `no known owner is refused`() {
        assertFalse(TestMediaGuard.allowsDelete(folder, null, own))
        assertFalse(TestMediaGuard.allowsDelete(folder, "", own))
        assertFalse(TestMediaGuard.allowsDelete(folder, "", ""))
    }

    @Test
    fun `this app's files in any other folder are refused`() {
        for (other in listOf(
            "DCIM/Camera/",
            "Movies/",
            "Movies/TakeTray/",
            "Download/",
            "Movies/TakeTray Test2/",
            "Movies/TakeTray Test/sub/",
            "Pictures/Movies/TakeTray Test/",
            "/Movies/TakeTray Test/",
            "",
        )) {
            assertFalse("folder '$other'", TestMediaGuard.allowsDelete(other, own, own))
        }
    }

    @Test
    fun `the folder matches ignoring case (the media provider keeps the case of a folder that exists)`() {
        assertTrue(TestMediaGuard.allowsDelete("movies/taketray test/", own, own))
        assertTrue(TestMediaGuard.allowsDelete("MOVIES/TAKETRAY TEST/", own, own))
        assertTrue(TestMediaGuard.allowsDelete("Movies/Taketray Test/", own, own))
        assertTrue(TestMediaGuard.allowsDelete("moViEs/TakeTRAY tEST/", own, own))
    }

    @Test
    fun `a case variant is still refused for another owner`() {
        assertFalse(TestMediaGuard.allowsDelete("movies/taketray test/", "com.sec.android.gallery3d", own))
        assertFalse(TestMediaGuard.allowsDelete("MOVIES/TAKETRAY TEST/", "app.taketray", own))
        assertFalse(TestMediaGuard.allowsDelete("Movies/Taketray Test/", null, own))
    }

    @Test
    fun `the trailing slash, spaces and sub-folders still decide, whatever the case`() {
        assertFalse(TestMediaGuard.allowsDelete("Movies/TakeTray Test", own, own))
        assertFalse(TestMediaGuard.allowsDelete("Movies/TakeTray Test//", own, own))
        assertFalse(TestMediaGuard.allowsDelete(" Movies/TakeTray Test/", own, own))
        assertFalse(TestMediaGuard.allowsDelete("movies/taketray test", own, own))
        assertFalse(TestMediaGuard.allowsDelete("MOVIES/TAKETRAY TEST/SUB/", own, own))
        assertFalse(TestMediaGuard.allowsDelete("movies/taketray test2/", own, own))
        assertFalse(TestMediaGuard.allowsDelete("Movies/TakeTray Tests/", own, own))
    }

    @Test
    fun `an unknown folder is refused`() {
        assertFalse(TestMediaGuard.allowsDelete(null, own, own))
    }

    @Test
    fun `the folder constant is the one MediaStore stores`() {
        // No leading slash, one trailing slash: how RELATIVE_PATH is stored and
        // how the Dart tests name it (Movies/TakeTray Test).
        assertTrue(TestMediaGuard.FOLDER == "Movies/TakeTray Test/")
    }
}
