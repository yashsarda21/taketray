package app.taketray.editors

import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** The intents TakeTray hands to an editor, the chooser, a launcher and the store (D-121). */
@RunWith(RobolectricTestRunner::class)
class ShareIntentsTest {
    private val capcut = "com.lemon.lvoverseas"

    private fun media(
        id: Long,
        volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
    ) = ShareClipMsg(volumeName = volume, mediaStoreId = id, pickerUri = null)

    private fun picked(uri: String) = ShareClipMsg(volumeName = null, mediaStoreId = null, pickerUri = uri)

    private fun mediaUri(
        id: Long,
        volume: String = MediaStore.VOLUME_EXTERNAL_PRIMARY,
    ) = ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(volume), id)

    private val pickerUri = "content://media/picker/0/com.android.providers.media.photopicker/media/1000000042"

    /** Records the intents it is asked to start; [failWith] is thrown instead when set. */
    private class Recorder(
        var failWith: RuntimeException? = null,
    ) : ActivityStarter {
        val started = mutableListOf<Intent>()

        override fun start(intent: Intent) {
            failWith?.let { throw it }
            started += intent
        }
    }

    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): List<Uri> =
        if (intent.action == Intent.ACTION_SEND) {
            listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM))
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        }

    private fun clipUris(intent: Intent): List<Uri> {
        val clip = intent.clipData ?: return emptyList()
        return (0 until clip.itemCount).map { clip.getItemAt(it).uri }
    }

    private fun grants(intent: Intent) = intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0

    // ---------------------------------------------------------------- URIs

    @Test
    fun `a MediaStore clip's URI is its volume's video collection and its id`() {
        assertEquals(mediaUri(42), ShareIntents.uriOf(media(42)))
        assertEquals(mediaUri(7, "1a2b-3c4d"), ShareIntents.uriOf(media(7, "1a2b-3c4d")))
        assertEquals("content://media/external_primary/video/media/42", ShareIntents.uriOf(media(42)).toString())
    }

    @Test
    fun `a picked clip uses its picker URI`() {
        assertEquals(Uri.parse(pickerUri), ShareIntents.uriOf(picked(pickerUri)))
        // The picker address wins over a stray identity (D-57).
        assertEquals(Uri.parse(pickerUri), ShareIntents.uriOf(ShareClipMsg("external_primary", 5, pickerUri)))
    }

    @Test
    fun `a clip with no usable identity has no URI`() {
        assertNull(ShareIntents.uriOf(ShareClipMsg(null, null, null)))
        assertNull(ShareIntents.uriOf(ShareClipMsg("external_primary", null, null)))
        assertNull(ShareIntents.uriOf(ShareClipMsg(null, 5, null)))
        assertNull(ShareIntents.uriOf(ShareClipMsg("", 5, null)))
        assertNull(ShareIntents.uriOf(ShareClipMsg("external_primary", 0, null)))
        assertNull(ShareIntents.uriOf(ShareClipMsg("external_primary", -3, null)))
        assertNull(ShareIntents.uriOf(picked("")))
        assertNull("a file address would crash the share", ShareIntents.uriOf(picked("file:///sdcard/a.mp4")))
        assertNull(ShareIntents.uriOf(picked("not a uri")))
        assertNull("a content address with no authority", ShareIntents.uriOf(picked("content:///x")))
        assertNull("a content address with an empty authority", ShareIntents.uriOf(picked("content://")))
    }

    // ---------------------------------------------------------------- send

    @Test
    fun `one clip is ACTION_SEND with EXTRA_STREAM to the editor alone`() {
        val intent = ShareIntents.sendIntent(capcut, listOf(mediaUri(1)))

        assertEquals(Intent.ACTION_SEND, intent.action)
        assertEquals(listOf(mediaUri(1)), streams(intent))
        assertEquals("video/*", intent.type)
        assertEquals(capcut, intent.`package`)
        assertTrue(grants(intent))
        assertEquals(listOf(mediaUri(1)), clipUris(intent))
    }

    @Test
    fun `several clips are ACTION_SEND_MULTIPLE in the given order`() {
        val uris = listOf(mediaUri(30), Uri.parse(pickerUri), mediaUri(4), mediaUri(12, "1a2b-3c4d"))

        val intent = ShareIntents.sendIntent(capcut, uris)

        assertEquals(Intent.ACTION_SEND_MULTIPLE, intent.action)
        @Suppress("DEPRECATION")
        val extra = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        assertTrue("an ArrayList<Uri>", extra is ArrayList<*>)
        assertEquals(uris, extra)
        assertEquals("video/*", intent.type)
        assertEquals(capcut, intent.`package`)
        assertTrue(grants(intent))
        assertEquals("ClipData in the same order", uris, clipUris(intent))
        assertEquals(0, intent.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    }

    @Test
    fun `send starts the share once and says sent`() {
        val starter = Recorder()

        val result = ShareIntents.send(capcut, listOf(media(2), picked(pickerUri), media(1)), starter)

        assertEquals(SendResultMsg.SENT, result)
        val intent = starter.started.single()
        assertEquals(listOf(mediaUri(2), Uri.parse(pickerUri), mediaUri(1)), streams(intent))
        assertEquals(capcut, intent.`package`)
    }

    @Test
    fun `clips with no usable identity are left out of the share`() {
        val starter = Recorder()

        ShareIntents.send(capcut, listOf(media(2), ShareClipMsg(null, null, null), media(0), media(1)), starter)

        assertEquals(listOf(mediaUri(2), mediaUri(1)), streams(starter.started.single()))
        assertEquals(listOf(mediaUri(2), mediaUri(1)), clipUris(starter.started.single()))
    }

    @Test
    fun `one usable clip of several is a single send`() {
        val starter = Recorder()
        ShareIntents.send(capcut, listOf(ShareClipMsg(null, null, null), media(9)), starter)
        assertEquals(Intent.ACTION_SEND, starter.started.single().action)
    }

    @Test
    fun `nothing to share starts nothing and fails`() {
        val starter = Recorder()
        assertEquals(SendResultMsg.FAILED, ShareIntents.send(capcut, emptyList(), starter))
        assertEquals(SendResultMsg.FAILED, ShareIntents.send(capcut, listOf(ShareClipMsg(null, null, null)), starter))
        assertTrue(starter.started.isEmpty())
    }

    @Test
    fun `no activity for the editor is notInstalled, anything else is failed`() {
        assertEquals(SendResultMsg.NOT_INSTALLED, ShareIntents.send(capcut, listOf(media(1)), Recorder(ActivityNotFoundException())))
        assertEquals(SendResultMsg.FAILED, ShareIntents.send(capcut, listOf(media(1)), Recorder(SecurityException("grant"))))
        assertEquals(SendResultMsg.FAILED, ShareIntents.send(capcut, listOf(media(1)), Recorder(IllegalStateException())))
    }

    // ---------------------------------------------------------------- chooser

    @Test
    fun `the chooser wraps the same send intent, with grants on both`() {
        val uris = listOf(mediaUri(3), mediaUri(1))

        val chooser = ShareIntents.chooserIntent(uris, "Share 2 clips")

        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        assertEquals("Share 2 clips", chooser.getCharSequenceExtra(Intent.EXTRA_TITLE)?.toString())
        @Suppress("DEPRECATION")
        val target = chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND_MULTIPLE, target.action)
        assertNull("the chooser target names no package", target.`package`)
        assertEquals(uris, streams(target))
        assertEquals("video/*", target.type)
        assertTrue(grants(target))
        assertTrue(grants(chooser))
        assertEquals(uris, clipUris(target))
        assertEquals(uris, clipUris(chooser))
    }

    @Test
    fun `chooser starts it and says true, false when nothing can start`() {
        val starter = Recorder()
        assertTrue(ShareIntents.chooser(listOf(media(1)), "Share", starter))
        assertEquals(Intent.ACTION_CHOOSER, starter.started.single().action)
        assertFalse(ShareIntents.chooser(listOf(media(1)), "Share", Recorder(ActivityNotFoundException())))
        assertFalse(ShareIntents.chooser(listOf(media(1)), "Share", Recorder(SecurityException())))
        val none = Recorder()
        assertFalse(ShareIntents.chooser(listOf(ShareClipMsg(null, null, null)), "Share", none))
        assertTrue(none.started.isEmpty())
    }

    // ---------------------------------------------------------------- launcher and store

    @Test
    fun `openApp starts the launch intent, false when there is none`() {
        val starter = Recorder()
        val launch = Intent(Intent.ACTION_MAIN).setPackage(capcut)
        assertTrue(ShareIntents.openApp(launch, starter))
        assertTrue(starter.started.single() === launch)
        assertFalse(ShareIntents.openApp(null, Recorder()))
        assertFalse(ShareIntents.openApp(launch, Recorder(ActivityNotFoundException())))
    }

    @Test
    fun `the store listing is market details only, never a web address`() {
        val intent = ShareIntents.storeIntent(capcut)
        assertEquals(Intent.ACTION_VIEW, intent.action)
        assertEquals("market://details?id=com.lemon.lvoverseas", intent.dataString)
        assertNull(intent.`package`)
        // A package name cannot add a second query parameter.
        assertEquals("market", ShareIntents.storeIntent("a&id=b").data?.scheme)
        assertEquals("a&id=b", ShareIntents.storeIntent("a&id=b").data?.getQueryParameter("id"))
        assertEquals(listOf("id"), ShareIntents.storeIntent("a&id=b").data?.queryParameterNames?.toList())
    }

    @Test
    fun `openStoreListing is false when no store handles it`() {
        val starter = Recorder()
        assertTrue(ShareIntents.openStoreListing(capcut, starter))
        assertEquals("market://details?id=com.lemon.lvoverseas", starter.started.single().dataString)
        assertFalse(ShareIntents.openStoreListing(capcut, Recorder(ActivityNotFoundException())))
        // Only one try: no web address as a fallback.
        val tried = mutableListOf<Intent>()
        assertFalse(ShareIntents.openStoreListing(capcut) { tried += it; throw ActivityNotFoundException() })
        assertEquals(listOf("market"), tried.map { it.data?.scheme })
    }
}
