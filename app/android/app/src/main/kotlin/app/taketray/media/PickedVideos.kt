package app.taketray.media

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import kotlinx.coroutines.CompletableDeferred

/** One saved grant: the address, and whether it lets this app read. */
data class SavedGrant(
    val uri: Uri,
    val read: Boolean,
)

/**
 * The saved (persistable) read grants of this app, behind a seam so tests can
 * record every call. The real one is [ResolverGrants].
 */
interface UriGrants {
    /** Saves [flags] access to [uri]; throws when Android will not (no persistable grant, or the limit is reached). */
    fun take(
        uri: Uri,
        flags: Int,
    )

    fun release(
        uri: Uri,
        flags: Int,
    )

    fun saved(): List<SavedGrant>
}

/** [UriGrants] on the app's [ContentResolver]. Each call is a binder call: off the main thread. */
class ResolverGrants(
    private val resolver: ContentResolver,
) : UriGrants {
    override fun take(
        uri: Uri,
        flags: Int,
    ) = resolver.takePersistableUriPermission(uri, flags)

    override fun release(
        uri: Uri,
        flags: Int,
    ) = resolver.releasePersistableUriPermission(uri, flags)

    override fun saved(): List<SavedGrant> =
        resolver.persistedUriPermissions.map { SavedGrant(it.uri, it.isReadPermission) }
}

/**
 * The video picker (D-112): which intent each Android level gets, the one
 * pick in flight, the facts read for each picked video, and the calls on
 * saved addresses (readable, persisted, release).
 *
 * Threading: [await], [onResult] and [fail] run on the main thread (the
 * activity's result arrives there). Everything in the companion that reads a
 * provider or the grants is a binder call and must run off the main thread
 * (MediaHostApiImpl does that).
 *
 * Privacy: nothing here logs an address, a name or a folder (D-10); the caller
 * logs counts only.
 */
class PickedVideos(
    private val requestCode: Int = REQUEST_CODE,
) {
    private var waiting: CompletableDeferred<List<Uri>>? = null

    /** True while a picker is open (a second one is "busy"). */
    val isWaiting: Boolean get() = waiting != null

    /**
     * Runs [start] (which opens the picker with this request code) and waits
     * for [onResult]: the picked addresses, empty when cancelled. If [start]
     * throws, the slot is freed and the exception passes. A cancelled caller
     * frees the slot too, so its late result is dropped.
     */
    suspend fun await(start: () -> Unit): List<Uri> {
        val pick = CompletableDeferred<List<Uri>>()
        waiting = pick
        try {
            start()
            return pick.await()
        } finally {
            if (waiting === pick) waiting = null
        }
    }

    /**
     * True when [code] is this picker's and a caller was waiting; it then
     * resumes. A result with nobody waiting (the process died while the picker
     * was open and Android re-created the activity) is dropped silently.
     */
    fun onResult(
        code: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (code != requestCode) return false
        val pick = waiting ?: return false
        waiting = null
        pick.complete(if (resultCode == Activity.RESULT_OK) urisOf(data) else emptyList())
        return true
    }

    /** Fails a waiting pick with [error] (the activity went away) instead of leaving it hanging. */
    fun fail(error: Throwable) {
        waiting?.let {
            waiting = null
            it.completeExceptionally(error)
        }
    }

    companion object {
        /** The request code of the picker (16 bits; the permission request uses 0x7A71). */
        const val REQUEST_CODE = 0x7A73

        private const val VIDEO_TYPE = "video/*"

        /** What the photo picker lets a user choose at most, from the system. */
        @SuppressLint("NewApi")
        fun systemLimit(): Int = MediaStore.getPickImagesMaxLimit()

        /**
         * Android's photo picker on API 33 and later, and on API 30 to 32 when
         * the R extension is 2 or more (it ships the picker through Google Play
         * system updates); otherwise the document picker, with the same videos
         * and a saved read grant. [maxLimit] is read only for the photo picker.
         */
        fun intent(
            sdk: Int,
            extensionLevel: Int,
            maxLimit: () -> Int = { systemLimit() },
        ): Intent =
            if (sdk >= 33 || (sdk in 30..32 && extensionLevel >= 2)) {
                Intent(MediaStore.ACTION_PICK_IMAGES)
                    .setType(VIDEO_TYPE)
                    .putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, maxLimit())
            } else {
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType(VIDEO_TYPE)
                    .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }

        /** The addresses a result carries: every clipData item with an address, then `data` when it is new, in order. */
        fun urisOf(data: Intent?): List<Uri> {
            if (data == null) return emptyList()
            val out = LinkedHashSet<Uri>()
            data.clipData?.let { clip ->
                for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let(out::add)
            }
            data.data?.let(out::add)
            return out.toList()
        }

        /**
         * One message per picked address, in order: the facts the provider
         * gives (read by column name from MediaColumns, which PickerMediaColumns
         * shares, or from OpenableColumns for a document), and whether Android
         * kept read access across restarts. A provider that refuses or has no
         * row still gives the row, with a 0 size and an empty name; any other
         * failure fails the whole call.
         */
        fun describe(
            resolver: ContentResolver,
            grants: UriGrants,
            uris: List<Uri>,
        ): List<PickedVideoMsg> =
            uris.map { uri ->
                val facts = factsOf(resolver, uri)
                val persisted =
                    try {
                        grants.take(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        true
                    } catch (e: Exception) {
                        false
                    }
                facts.copy(persisted = persisted)
            }

        private fun factsOf(
            resolver: ContentResolver,
            uri: Uri,
        ): PickedVideoMsg {
            val empty = PickedVideoMsg(uri.toString(), 0, null, null, "", null, null, null, false)
            val cursor =
                try {
                    resolver.query(uri, null, null, null)
                } catch (e: SecurityException) {
                    null
                } ?: return empty
            cursor.use { c ->
                if (!c.moveToFirst()) return empty
                return empty.copy(
                    sizeBytes = longOf(c, MediaColumns.SIZE) ?: 0,
                    durationMs = longOf(c, MediaColumns.DURATION),
                    dateTakenMs = longOf(c, MediaColumns.DATE_TAKEN),
                    displayName = stringOf(c, MediaColumns.DISPLAY_NAME) ?: "",
                    width = longOf(c, MediaColumns.WIDTH),
                    height = longOf(c, MediaColumns.HEIGHT),
                    mimeType = stringOf(c, MediaColumns.MIME_TYPE),
                )
            }
        }

        private fun longOf(
            c: Cursor,
            column: String,
        ): Long? {
            val i = c.getColumnIndex(column)
            return if (i < 0 || c.isNull(i)) null else c.getLong(i)
        }

        private fun stringOf(
            c: Cursor,
            column: String,
        ): String? {
            val i = c.getColumnIndex(column)
            return if (i < 0 || c.isNull(i)) null else c.getString(i)
        }

        /**
         * The subset of [uris] that can still be read, in order. A read that is
         * refused (SecurityException) or gives no row means gone. Any other
         * failure is thrown, so a failed call is never read as "all gone".
         */
        fun readable(
            resolver: ContentResolver,
            uris: List<String>,
        ): List<String> =
            uris.filter { text ->
                try {
                    resolver.query(Uri.parse(text), arrayOf(MediaColumns.DISPLAY_NAME), null, null)?.use { it.moveToFirst() } ?: false
                } catch (e: SecurityException) {
                    false
                }
            }

        /** Every address with a saved read grant. */
        fun persisted(grants: UriGrants): List<String> = grants.saved().filter { it.read }.map { it.uri.toString() }

        /** Gives up the saved read grants of exactly [uris]. A failure on one does not stop the rest; returns how many failed. */
        fun release(
            grants: UriGrants,
            uris: List<String>,
        ): Int {
            var failures = 0
            for (text in uris) {
                try {
                    grants.release(Uri.parse(text), Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (e: Exception) {
                    failures++
                }
            }
            return failures
        }
    }
}
