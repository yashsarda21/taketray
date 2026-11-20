package app.taketray.share

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * An activity that records how it was finished, and can be made to fail
 * reading its intent.
 */
class RecordingActivity : Activity() {
    var removedTask = false
    var finishedOnly = false
    var intentError: RuntimeException? = null

    override fun getIntent(): Intent {
        intentError?.let { throw it }
        return super.getIntent()
    }

    override fun finishAndRemoveTask() {
        removedTask = true
        super.finishAndRemoveTask()
    }

    override fun finish() {
        finishedOnly = true
        super.finish()
    }
}

/**
 * The share bridge (D-163) on a Robolectric activity: the text of an
 * `ACTION_SEND` `text/plain` intent, read once and cut to 20,000 characters;
 * null for anything else; closing the screen with its task when it is the
 * task's root. Errors name a class, never the shared text.
 */
@RunWith(RobolectricTestRunner::class)
class ShareHostApiImplTest {
    private fun send(text: CharSequence?): Intent =
        Intent(Intent.ACTION_SEND).setType("text/plain").apply {
            if (text != null) putExtra(Intent.EXTRA_TEXT, text)
        }

    private fun activityWith(intent: Intent): RecordingActivity =
        Robolectric.buildActivity(RecordingActivity::class.java, intent).setup().get()

    private fun textOf(intent: Intent): String? = ShareHostApiImpl(activityWith(intent)).sharedText()

    // ------------------------------------------------------------ the text

    @Test
    fun `a String in a text plain SEND is the text`() {
        assertEquals("Look https://www.instagram.com/reel/abc/ !", textOf(send("Look https://www.instagram.com/reel/abc/ !")))
    }

    @Test
    fun `a CharSequence with spans is its plain text`() {
        val spanned = SpannableString("bold https://x.com/a")
        spanned.setSpan(StyleSpan(Typeface.BOLD), 0, 4, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        val text = textOf(send(spanned))

        assertEquals("bold https://x.com/a", text)
        assertEquals(String::class.java, text!!.javaClass)
    }

    @Test
    fun `a 30,000 character text is cut to its first 20,000`() {
        val long = buildString { repeat(30_000) { append(('a' + it % 26)) } }

        val text = textOf(send(long))!!

        assertEquals(20_000, text.length)
        assertEquals(long.substring(0, 20_000), text)
    }

    @Test
    fun `exactly 20,000 characters stay whole and 20,001 lose the last one`() {
        val exact = "x".repeat(20_000)
        assertEquals(exact, textOf(send(exact)))
        assertEquals(exact, textOf(send(exact + "y")))
    }

    @Test
    fun `the cut never splits an emoji in half`() {
        // The emoji is two chars, at 19,999 and 20,000: cutting at 20,000 would keep half of it.
        val text = textOf(send("a".repeat(19_999) + "😀" + "tail"))!!

        assertEquals("a".repeat(19_999), text)
        assertFalse(Character.isHighSurrogate(text.last()))
    }

    @Test
    fun `an emoji that ends exactly at 20,000 is kept`() {
        val whole = "a".repeat(19_998) + "😀"
        assertEquals(whole, textOf(send(whole + "more")))
    }

    @Test
    fun `an empty text is empty, not null`() {
        assertEquals("", textOf(send("")))
    }

    @Test
    fun `the type is read in any case and without its parameters`() {
        for (type in listOf("TEXT/PLAIN", "text/plain; charset=utf-8")) {
            val intent = Intent(Intent.ACTION_SEND).setType(type).putExtra(Intent.EXTRA_TEXT, "hi")
            assertEquals(type, "hi", textOf(intent))
        }
    }

    @Test
    fun `another action is null`() {
        for (action in listOf(Intent.ACTION_VIEW, Intent.ACTION_SEND_MULTIPLE, Intent.ACTION_MAIN, null)) {
            val intent = Intent(action).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "https://x.com")
            assertNull("$action", textOf(intent))
        }
    }

    @Test
    fun `another type, or none, is null`() {
        for (type in listOf("image/*", "image/jpeg", "text/html", "text/*", "*/*", "video/mp4", null)) {
            val intent = Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_TEXT, "https://x.com")
            if (type != null) intent.type = type
            assertNull("$type", textOf(intent))
        }
    }

    @Test
    fun `no EXTRA_TEXT is null`() {
        assertNull(textOf(send(null)))
        // A stream with a subject but no text.
        assertNull(textOf(send(null).putExtra(Intent.EXTRA_SUBJECT, "subject")))
    }

    @Test
    fun `an EXTRA_TEXT that is not text is null`() {
        assertNull(textOf(send(null).putExtra(Intent.EXTRA_TEXT, 42)))
        assertNull(textOf(send(null).putExtra(Intent.EXTRA_TEXT, arrayOf("a", "b"))))
    }

    // ------------------------------------------------------------ read once

    @Test
    fun `a second call is null`() {
        val impl = ShareHostApiImpl(activityWith(send("once")))

        assertEquals("once", impl.sharedText())
        assertNull(impl.sharedText())
        assertNull(impl.sharedText())
    }

    @Test
    fun `a new intent gives its text once`() {
        val activity = activityWith(send("first"))
        val impl = ShareHostApiImpl(activity)
        assertEquals("first", impl.sharedText())

        activity.intent = send("second")

        assertEquals("second", impl.sharedText())
        assertNull(impl.sharedText())
    }

    @Test
    fun `a new intent that is not a share is null, and the old text does not come back`() {
        val activity = activityWith(send("first"))
        val impl = ShareHostApiImpl(activity)
        assertEquals("first", impl.sharedText())

        activity.intent = Intent(Intent.ACTION_VIEW)

        assertNull(impl.sharedText())
    }

    @Test
    fun `a call that is null does not use up a later share`() {
        val activity = activityWith(Intent(Intent.ACTION_MAIN))
        val impl = ShareHostApiImpl(activity)
        assertNull(impl.sharedText())

        activity.intent = send("later")

        assertEquals("later", impl.sharedText())
    }

    // ------------------------------------------------------------ closing

    @Test
    fun `finish at the root of its task closes the task too`() {
        val activity = activityWith(send("x"))
        shadowOf(activity).setIsTaskRoot(true)

        ShareHostApiImpl(activity).finish()

        assertTrue(activity.removedTask)
        assertTrue(activity.isFinishing)
    }

    @Test
    fun `finish inside the sharing app's task closes the activity only`() {
        val activity = activityWith(send("x"))
        shadowOf(activity).setIsTaskRoot(false)

        ShareHostApiImpl(activity).finish()

        assertFalse(activity.removedTask)
        assertTrue(activity.finishedOnly)
        assertTrue(activity.isFinishing)
    }

    @Test
    fun `openReel closes the screen, until Task 4 opens the reel`() {
        val activity = activityWith(send("x"))
        shadowOf(activity).setIsTaskRoot(false)

        ShareHostApiImpl(activity).openReel(7)

        assertTrue(activity.isFinishing)
        // Nothing is started yet (Task 4 starts MainActivity).
        assertNull(shadowOf(activity).nextStartedActivity)
    }

    @Test
    fun `openReel at the root of its task closes the task too`() {
        val activity = activityWith(send("x"))
        shadowOf(activity).setIsTaskRoot(true)

        ShareHostApiImpl(activity).openReel(7)

        assertTrue(activity.removedTask)
    }

    // ------------------------------------------------------------ errors

    private fun shareError(block: () -> Unit): ShareError {
        try {
            block()
        } catch (e: ShareError) {
            return e
        }
        fail("expected a ShareError")
        throw AssertionError()
    }

    @Test
    fun `once the activity is gone every call is no-activity and nothing finishes`() {
        val activity = activityWith(send("secret text"))
        val impl = ShareHostApiImpl(activity)
        impl.onHostGone()

        assertEquals("no-activity", shareError { impl.sharedText() }.code)
        assertEquals("no-activity", shareError { impl.finish() }.code)
        assertEquals("no-activity", shareError { impl.openReel(1) }.code)
        assertFalse(activity.isFinishing)
    }

    @Test
    fun `a failure reading the intent is a native-error that names the class and never the text`() {
        val activity = activityWith(send("x"))
        activity.intentError = IllegalStateException("secret https://private.example.com")
        val impl = ShareHostApiImpl(activity)

        val e = shareError { impl.sharedText() }

        assertEquals("native-error", e.code)
        assertEquals("sharedText failed: IllegalStateException", e.message)
        assertNull(e.details)
        assertFalse(e.toString().contains("secret"))
        assertNull(e.cause)
    }

    @Test
    fun `the read after a failure still works`() {
        val activity = activityWith(send("after"))
        activity.intentError = IllegalStateException("x")
        val impl = ShareHostApiImpl(activity)
        shareError { impl.sharedText() }

        activity.intentError = null

        assertEquals("after", impl.sharedText())
    }
}
