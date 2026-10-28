package app.taketray.media

import app.taketray.media.MediaAccessChecker.READ_EXTERNAL_STORAGE
import app.taketray.media.MediaAccessChecker.READ_MEDIA_VIDEO
import app.taketray.media.MediaAccessChecker.READ_MEDIA_VISUAL_USER_SELECTED
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pure JVM test: the permission model per Android version (D-68). */
class MediaAccessCheckerTest {
    private val all = listOf(READ_EXTERNAL_STORAGE, READ_MEDIA_VIDEO, READ_MEDIA_VISUAL_USER_SELECTED)

    /** Every subset of the three permissions (8 grant combinations). */
    private val combinations: List<Set<String>> =
        (0 until 8).map { bits -> all.filterIndexed { i, _ -> bits and (1 shl i) != 0 }.toSet() }

    private fun level(sdk: Int, granted: Set<String>) = MediaAccessChecker.level(sdk) { it in granted }

    @Test
    fun `level on Android 11 and 12 (30, 32) is full only with READ_EXTERNAL_STORAGE`() {
        for (sdk in listOf(30, 32)) {
            for (granted in combinations) {
                val expected =
                    if (READ_EXTERNAL_STORAGE in granted) MediaAccessLevelMsg.FULL else MediaAccessLevelMsg.DENIED
                assertEquals("sdk $sdk granted $granted", expected, level(sdk, granted))
            }
        }
    }

    @Test
    fun `level on Android 13 (33) is full only with READ_MEDIA_VIDEO`() {
        for (granted in combinations) {
            val expected = if (READ_MEDIA_VIDEO in granted) MediaAccessLevelMsg.FULL else MediaAccessLevelMsg.DENIED
            assertEquals("granted $granted", expected, level(33, granted))
        }
    }

    @Test
    fun `level on Android 14 and 15 (34, 35) is full, limited or denied`() {
        for (sdk in listOf(34, 35)) {
            for (granted in combinations) {
                val expected =
                    when {
                        READ_MEDIA_VIDEO in granted -> MediaAccessLevelMsg.FULL
                        READ_MEDIA_VISUAL_USER_SELECTED in granted -> MediaAccessLevelMsg.LIMITED
                        else -> MediaAccessLevelMsg.DENIED
                    }
                assertEquals("sdk $sdk granted $granted", expected, level(sdk, granted))
            }
        }
    }

    @Test
    fun `34 with only VISUAL_USER_SELECTED is limited`() {
        assertEquals(MediaAccessLevelMsg.LIMITED, level(34, setOf(READ_MEDIA_VISUAL_USER_SELECTED)))
    }

    @Test
    fun `33 with READ_EXTERNAL_STORAGE only is denied`() {
        assertEquals(MediaAccessLevelMsg.DENIED, level(33, setOf(READ_EXTERNAL_STORAGE)))
    }

    @Test
    fun `33 with VISUAL_USER_SELECTED only is denied (that permission is new in 14)`() {
        assertEquals(MediaAccessLevelMsg.DENIED, level(33, setOf(READ_MEDIA_VISUAL_USER_SELECTED)))
    }

    @Test
    fun `permissionsToRequest on 30 is READ_EXTERNAL_STORAGE`() {
        assertArrayEquals(arrayOf(READ_EXTERNAL_STORAGE), MediaAccessChecker.permissionsToRequest(30))
        assertArrayEquals(arrayOf(READ_EXTERNAL_STORAGE), MediaAccessChecker.permissionsToRequest(32))
    }

    @Test
    fun `permissionsToRequest on 33 is READ_MEDIA_VIDEO`() {
        assertArrayEquals(arrayOf(READ_MEDIA_VIDEO), MediaAccessChecker.permissionsToRequest(33))
    }

    @Test
    fun `permissionsToRequest on 34 asks for both media permissions together`() {
        val both = arrayOf(READ_MEDIA_VIDEO, READ_MEDIA_VISUAL_USER_SELECTED)
        assertArrayEquals(both, MediaAccessChecker.permissionsToRequest(34))
        assertArrayEquals(both, MediaAccessChecker.permissionsToRequest(35))
    }

    @Test
    fun `canAskAgain after a request is the rationale unless access is full`() {
        assertTrue(MediaAccessChecker.canAskAgainAfterRequest(MediaAccessLevelMsg.FULL, rationale = false))
        assertTrue(MediaAccessChecker.canAskAgainAfterRequest(MediaAccessLevelMsg.DENIED, rationale = true))
        assertFalse(MediaAccessChecker.canAskAgainAfterRequest(MediaAccessLevelMsg.DENIED, rationale = false))
        assertFalse(MediaAccessChecker.canAskAgainAfterRequest(MediaAccessLevelMsg.LIMITED, rationale = false))
    }

    @Test
    fun `canAskAgain in a report is false only after a request that left it false`() {
        // Never asked: Android says "no rationale" both before the first ask and
        // after a permanent denial, so only the remembered result tells them apart.
        assertTrue(MediaAccessChecker.canAskAgainNow(MediaAccessLevelMsg.DENIED, rationale = false, blocked = false))
        assertFalse(MediaAccessChecker.canAskAgainNow(MediaAccessLevelMsg.DENIED, rationale = false, blocked = true))
        assertTrue(MediaAccessChecker.canAskAgainNow(MediaAccessLevelMsg.DENIED, rationale = true, blocked = true))
        assertTrue(MediaAccessChecker.canAskAgainNow(MediaAccessLevelMsg.FULL, rationale = false, blocked = true))
    }
}
