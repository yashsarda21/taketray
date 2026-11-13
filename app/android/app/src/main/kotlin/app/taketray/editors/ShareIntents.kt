package app.taketray.editors

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Log

/**
 * The intents that hand clips to an editor (D-121), and starting them.
 *
 * A share names the editor's package, carries the clips **in the order
 * given** (EXTRA_STREAM and ClipData alike), has the type [TYPE] (any video) and grants
 * read access to each clip, never write. A clip with no usable address
 * (no picker address and no volume and id above 0) is left out; nothing left
 * means nothing is started.
 *
 * Building is pure; starting goes through an [ActivityStarter], on the main
 * thread. Logs say counts and exception classes only (D-10).
 */
object ShareIntents {
    const val TYPE = "video/*"

    private const val TAG = "TakeTrayShare"

    /**
     * The address a clip is read from: its picker address (a content URI) when
     * it has one, else its volume's video collection with its id. Null when
     * neither is usable.
     */
    fun uriOf(clip: ShareClipMsg): Uri? {
        clip.pickerUri?.let { picked ->
            val uri = Uri.parse(picked)
            return if (uri.scheme == ContentResolver.SCHEME_CONTENT && !uri.authority.isNullOrEmpty()) uri else null
        }
        val volume = clip.volumeName
        val id = clip.mediaStoreId
        if (volume.isNullOrEmpty() || id == null || id <= 0) return null
        return ContentUris.withAppendedId(MediaStore.Video.Media.getContentUri(volume), id)
    }

    /** ACTION_SEND for one address, ACTION_SEND_MULTIPLE for several, to [packageName] (none for the chooser). */
    fun sendIntent(
        packageName: String?,
        uris: List<Uri>,
    ): Intent {
        require(uris.isNotEmpty()) { "nothing to share" }
        val intent =
            if (uris.size == 1) {
                Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
            } else {
                Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
            }
        intent.type = TYPE
        if (packageName != null) intent.setPackage(packageName)
        intent.clipData = clipDataOf(uris)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return intent
    }

    /**
     * Android's chooser around the same send intent (no package). The read
     * grant and the ClipData end up on both intents: `Intent.createChooser`
     * copies them from the target onto the chooser (a test checks both on
     * every SDK level TakeTray supports).
     */
    fun chooserIntent(
        uris: List<Uri>,
        title: String,
    ): Intent = Intent.createChooser(sendIntent(null, uris), title)

    /** Shares [clips] with [packageName] alone. */
    fun send(
        packageName: String,
        clips: List<ShareClipMsg>,
        starter: ActivityStarter,
    ): SendResultMsg {
        val uris = clips.mapNotNull(::uriOf)
        logLeftOut(clips.size, uris.size)
        if (uris.isEmpty()) return SendResultMsg.FAILED
        val result =
            try {
                starter.start(sendIntent(packageName, uris))
                SendResultMsg.SENT
            } catch (e: ActivityNotFoundException) {
                SendResultMsg.NOT_INSTALLED
            } catch (e: Exception) {
                Log.w(TAG, "send failed: ${e.javaClass.simpleName}")
                SendResultMsg.FAILED
            }
        Log.i(TAG, "send: ${uris.size} clips, $result")
        return result
    }

    /** Shares [clips] through the chooser; false when nothing could be started. */
    fun chooser(
        clips: List<ShareClipMsg>,
        title: String,
        starter: ActivityStarter,
    ): Boolean {
        val uris = clips.mapNotNull(::uriOf)
        logLeftOut(clips.size, uris.size)
        if (uris.isEmpty()) return false
        return start(starter, chooserIntent(uris, title), "chooser")
    }

    /** Starts an editor's launcher intent; false when it has none or it cannot start. */
    fun openApp(
        launch: Intent?,
        starter: ActivityStarter,
    ): Boolean = launch != null && start(starter, launch, "openApp")

    /** `market://details?id=<packageName>`; the name is a query value, so it cannot add another parameter. */
    fun storeIntent(packageName: String): Intent =
        Intent(
            Intent.ACTION_VIEW,
            Uri
                .Builder()
                .scheme("market")
                .authority("details")
                .appendQueryParameter("id", packageName)
                .build(),
        )

    /** Opens the store listing; false when no store handles `market://` (there is no web fallback). */
    fun openStoreListing(
        packageName: String,
        starter: ActivityStarter,
    ): Boolean = start(starter, storeIntent(packageName), "openStoreListing")

    private fun start(
        starter: ActivityStarter,
        intent: Intent,
        what: String,
    ): Boolean =
        try {
            starter.start(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "$what could not start: ${e.javaClass.simpleName}")
            false
        }

    private fun clipDataOf(uris: List<Uri>): ClipData {
        // The constructor, not ClipData.newUri: that asks the provider for each type (a binder call).
        val clip = ClipData(null, arrayOf(TYPE), ClipData.Item(uris[0]))
        for (uri in uris.drop(1)) clip.addItem(ClipData.Item(uri))
        return clip
    }

    private fun logLeftOut(
        asked: Int,
        usable: Int,
    ) {
        if (usable < asked) Log.w(TAG, "${asked - usable} of $asked clips have no address and are left out")
    }
}
