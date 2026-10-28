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

    private val full = MediaAccessLevelMsg.FULL
    private val limited = MediaAccessLevelMsg.LIMITED
    private val denied = MediaAccessLevelMsg.DENIED

    private fun blocked(
        level: MediaAccessLevelMsg,
        before: Boolean,
        after: Boolean,
        wasBlocked: Boolean,
    ) = MediaAccessChecker.blockedAfterRequest(level, rationaleBefore = before, rationaleAfter = after, wasBlocked = wasBlocked)

    @Test
    fun `a first dismissal stays askable`() {
        assertFalse(blocked(denied, before = false, after = false, wasBlocked = false))
    }

    @Test
    fun `a first explicit denial stays askable`() {
        assertFalse(blocked(denied, before = false, after = true, wasBlocked = false))
    }

    @Test
    fun `a second denial, rationale true then false, is blocked`() {
        assertTrue(blocked(denied, before = true, after = false, wasBlocked = false))
    }

    @Test
    fun `a dismissal while blocked stays blocked`() {
        assertTrue(blocked(denied, before = false, after = false, wasBlocked = true))
    }

    @Test
    fun `a grant clears the flag`() {
        assertFalse(blocked(full, before = true, after = false, wasBlocked = true))
        assertFalse(blocked(full, before = false, after = false, wasBlocked = true))
    }

    @Test
    fun `canAskAgain is true when full, limited, with a rationale, or not blocked`() {
        assertTrue(MediaAccessChecker.canAskAgain(full, rationale = false, blocked = true))
        // Android shows the picker again for partial access (Ruling G).
        assertTrue(MediaAccessChecker.canAskAgain(limited, rationale = false, blocked = true))
        assertTrue(MediaAccessChecker.canAskAgain(denied, rationale = true, blocked = true))
        assertTrue(MediaAccessChecker.canAskAgain(denied, rationale = false, blocked = false))
        assertFalse(MediaAccessChecker.canAskAgain(denied, rationale = false, blocked = true))
    }
}
