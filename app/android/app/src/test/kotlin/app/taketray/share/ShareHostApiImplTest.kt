package app.taketray.share

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import app.taketray.MainActivity
import app.taketray.background.BackgroundState
import app.taketray.background.LaunchActionMsg
import app.taketray.background.LaunchActions
import app.taketray.background.LaunchMsg
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
import org.robolectric.shadows.ShadowLog

/**
 * An activity that records how it was finished, and can be made to fail
 * reading its intent.
 */
class RecordingActivity : Activity() {
    var removedTask = false
    var finishedOnly = false
    var intentError: RuntimeException? = null
    var startError: RuntimeException? = null

    override fun getIntent(): Intent {
        intentError?.let { throw it }
        return super.getIntent()
    }

    override fun startActivity(intent: Intent) {
        startError?.let { throw it }
        super.startActivity(intent)
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
    fun `openReel starts MainActivity with the openReel launch action, then closes the screen`() {
        val activity = activityWith(send("x"))
        shadowOf(activity).setIsTaskRoot(false)

        ShareHostApiImpl(activity).openReel(7)

        val started = shadowOf(activity).nextStartedActivity
        assertEquals(ComponentName(activity, MainActivity::class.java), started.component)
        assertEquals("openReel", started.getStringExtra(LaunchActions.EXTRA_OPEN))
        assertEquals(7L, started.getLongExtra(LaunchActions.EXTRA_REEL_ID, -1))
        assertEquals(LaunchMsg(LaunchActionMsg.OPEN_REEL, 7), LaunchActions.read(started))
        assertNull("one start only", shadowOf(activity).nextStartedActivity)
        assertTrue(activity.isFinishing)
        assertTrue(activity.finishedOnly)
        assertFalse(activity.removedTask)
    }

    @Test
    fun `openReel at the root of its task starts MainActivity and closes the task too`() {
        val activity = activityWith(send("x"))
        shadowOf(activity).setIsTaskRoot(true)

        ShareHostApiImpl(activity).openReel(7)

        assertEquals(ComponentName(activity, MainActivity::class.java), shadowOf(activity).nextStartedActivity.component)
        assertTrue(activity.removedTask)
    }

    @Test
    fun `openReel with an id outside 1 to MAX_REEL_ID starts nothing, only finishes, and does not crash`() {
        for (id in listOf(0L, -1L, Long.MIN_VALUE, BackgroundState.MAX_REEL_ID + 1, Long.MAX_VALUE)) {
            val activity = activityWith(send("x"))
            shadowOf(activity).setIsTaskRoot(false)
            ShadowLog.clear()

            ShareHostApiImpl(activity).openReel(id)

            assertNull("$id", shadowOf(activity).nextStartedActivity)
            assertTrue("$id", activity.isFinishing)
            val logged = ShadowLog.getLogs().joinToString { it.msg }
            assertTrue("$id: the reason is logged", logged.contains("unusable reel id"))
            assertFalse("$id: refused before an intent is built", logged.contains("IllegalArgumentException"))
            assertTrue("$id: no stack trace", ShadowLog.getLogs().none { it.throwable != null })
        }
    }

    @Test
    fun `openReel with the largest usable id starts MainActivity`() {
        val activity = activityWith(send("x"))
        ShareHostApiImpl(activity).openReel(BackgroundState.MAX_REEL_ID)
        assertEquals(
            BackgroundState.MAX_REEL_ID,
            shadowOf(activity).nextStartedActivity.getLongExtra(LaunchActions.EXTRA_REEL_ID, -1),
        )
    }

    @Test
    fun `an openReel that cannot start MainActivity still finishes, and logs only the class`() {
        val activity = activityWith(send("x"))
        activity.startError = IllegalStateException("secret https://private.example.com")
        ShadowLog.clear()

        ShareHostApiImpl(activity).openReel(7)

        assertTrue(activity.isFinishing)
        assertNull(shadowOf(activity).nextStartedActivity)
        val logged = ShadowLog.getLogs().joinToString { it.msg }
        assertTrue(logged.contains("IllegalStateException"))
        assertFalse(logged.contains("secret"))
        assertTrue(ShadowLog.getLogs().none { it.throwable != null })
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
