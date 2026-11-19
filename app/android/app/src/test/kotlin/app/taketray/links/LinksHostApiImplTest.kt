package app.taketray.links

import android.app.Activity
import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The links bridge (D-155) on a Robolectric activity: only `http` and `https`
 * start an `ACTION_VIEW` (with `CATEGORY_BROWSABLE`); everything else, and a
 * phone with nothing to open the link, answers false; any other failure is an
 * error that names its class and never the address.
 */
@RunWith(RobolectricTestRunner::class)
class LinksHostApiImplTest {
    private lateinit var activity: Activity
    private lateinit var impl: LinksHostApiImpl

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        impl = LinksHostApiImpl(activity)
    }

    private fun open(url: String): Boolean = runBlocking { impl.openLink(url) }

    private fun started(): Intent? = shadowOf(activity).nextStartedActivity

    @Test
    fun `https starts ACTION_VIEW with the address and CATEGORY_BROWSABLE`() {
        assertTrue(open("https://x.com"))

        val intent = started()
        assertNotNull("nothing was started", intent)
        assertEquals(Intent.ACTION_VIEW, intent!!.action)
        assertEquals(Uri.parse("https://x.com"), intent.data)
        assertTrue(intent.categories.contains(Intent.CATEGORY_BROWSABLE))
        assertNull("one activity only", started())
    }

    @Test
    fun `http starts too, with its path and query kept`() {
        assertTrue(open("http://example.com/a/b?c=1&d=2#e"))
        assertEquals(Uri.parse("http://example.com/a/b?c=1&d=2#e"), started()!!.data)
    }

    @Test
    fun `the scheme is read in any case`() {
        assertTrue(open("HTTPS://x.com/A"))
        assertNotNull(started())
    }

    @Test
    fun `javascript, file, content, intent, market and tel start nothing and answer false`() {
        for (url in listOf(
            "javascript:x",
            "file:///a",
            "content://app.taketray.files/shared/a.txt",
            "intent://x#Intent;scheme=https;end",
            "market://details?id=a.b",
            "tel:123",
            "mailto:a@b.c",
            "ftp://x.com/a",
        )) {
            assertFalse(url, open(url))
            assertNull(url, started())
        }
    }

    @Test
    fun `no scheme, an empty text and no host start nothing and answer false`() {
        for (url in listOf("", "   ", "example.com", "//example.com", "https:", "https://", "https:///a", "not a link")) {
            assertFalse("[$url]", open(url))
            assertNull("[$url]", started())
        }
    }

    @Test
    fun `a scheme hidden behind a prefix is not http`() {
        for (url in listOf(" https://x.com", "xhttps://x.com", "javascript:https://x.com", "view-source:https://x.com")) {
            assertFalse("[$url]", open(url))
            assertNull("[$url]", started())
        }
    }

    @Test
    fun `nothing on the phone can open it answers false and the next call still works`() {
        // Robolectric's package manager is empty: with the check on, startActivity throws ActivityNotFoundException.
        shadowOf(activity.application).checkActivities(true)

        assertFalse(open("https://x.com"))
        assertNull(started())
        shadowOf(activity.application).checkActivities(false)
        assertTrue(open("https://x.com"))
    }

    @Test
    fun `any other failure is a native-error that names the class and never the address`() {
        val url = "https://secret.example.com/private-path"
        val failing = LinksHostApiImpl(activity) { throw SecurityException("denied $url") }

        val e =
            try {
                runBlocking { failing.openLink(url) }
                fail("expected a LinksError")
                return
            } catch (e: LinksError) {
                e
            }
        assertEquals("native-error", e.code)
        assertEquals("openLink failed: SecurityException", e.message)
        assertFalse(e.toString().contains("secret"))
        assertNull(e.details)
    }

    @Test
    fun `after the activity is gone it fails with no-activity and starts nothing`() {
        impl.onHostGone()

        val e =
            try {
                open("https://x.com")
                fail("expected a LinksError")
                return
            } catch (e: LinksError) {
                e
            }
        assertEquals("no-activity", e.code)
        assertNull(started())
    }

    @Test
    fun `a refused address is false even after the activity is gone`() {
        // The scheme check comes first: a bad address never depends on the host.
        impl.onHostGone()
        assertFalse(open("javascript:x"))
    }
}
