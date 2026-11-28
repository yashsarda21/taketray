package app.taketray.media

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract.Document
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
    /**
     * Saves [flags] access to [uri]; throws when Android will not (the address
     * carries no persistable grant). It does **not** throw at the cap: Android
     * keeps at most 512 saved grants per app and, when one more is taken,
     * silently releases the **oldest** (least recently saved) ones and returns
     * normally (AOSP `UriGrantsManagerService.maybePrunePersistedUriGrantsLocked`,
     * `MAX_PERSISTED_URI_GRANTS = 512`; D-112, final review I-2). So a `take`
     * that returns is no promise the grant lasts, and an old picked clip can
     * lose its grant without any error: it reads as unreadable and is flagged
     * missing, never deleted (D-116).
     */
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
 * The video picker (D-112), and from Phase 13 the photo picker too (D-199):
 * which intent each Android level gets, the one pick in flight, the facts
 * read for each picked video or photo, and the calls on saved addresses
 * (readable, persisted, release).
 *
 * Videos and photos share one slot and one request code: there is only ever
 * one pick at a time, and a second one, of either kind, is "busy".
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

        /** What Add videos' picker shows (D-112). */
        const val VIDEO_TYPE = "video/*"

        /** What Add photos' picker shows (D-199): photos only, never videos. */
        const val PHOTO_TYPE = "image/*"

        /** What the photo picker lets a user choose at most, from the system. */
        @SuppressLint("NewApi")
        fun systemLimit(): Int = MediaStore.getPickImagesMaxLimit()

        /**
         * Android's photo picker on API 33 and later, and on API 30 to 32 when
         * the R extension is 2 or more (it ships the picker through Google Play
         * system updates); otherwise the document picker, with the same videos
         * and a saved read grant. [maxLimit] is read only for the photo picker.
         * This is Add videos' picker: [intent] with [VIDEO_TYPE].
         */
        fun intent(
            sdk: Int,
            extensionLevel: Int,
            maxLimit: () -> Int = { systemLimit() },
        ): Intent = intent(sdk, extensionLevel, maxLimit, VIDEO_TYPE)

        /**
         * The picker of [type]: [VIDEO_TYPE] (Add videos) or [PHOTO_TYPE] (Add
         * photos, D-199). Everything else (which picker for which level, the
         * limit, multiple choice, the grant flags) is the same for both.
         */
        fun intent(
            sdk: Int,
            extensionLevel: Int,
            maxLimit: () -> Int,
            type: String,
        ): Intent =
            if (sdk >= 33 || (sdk in 30..32 && extensionLevel >= 2)) {
                Intent(MediaStore.ACTION_PICK_IMAGES)
                    .setType(type)
                    .putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, maxLimit())
            } else {
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType(type)
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
         * failure fails the whole call, and then no grant has been taken.
         *
         * With [photos] (Add photos, D-199) two more facts are read, and only
         * then: `dateModifiedMs` is the document's COLUMN_LAST_MODIFIED (ms)
         * when the cursor has it, else MediaStore's DATE_MODIFIED (seconds)
         * times 1000, else null; and an `orientation` of 90 or 270 swaps the
         * width and the height, so they are the photo as it is seen. A video
         * pick never sets `dateModifiedMs` and never swaps (R13-3).
         */
        fun describe(
            resolver: ContentResolver,
            grants: UriGrants,
            uris: List<Uri>,
            photos: Boolean = false,
        ): List<PickedVideoMsg> {
            // Every read that can fail the call runs before the first grant is
            // taken, so a failure part-way leaves no grant behind (they would
            // count toward the per-app limit and Dart never hears of them), and
            // there is nothing to release, which could drop a grant that a clip
            // already picked earlier is using.
            val facts = uris.map { factsOf(resolver, it, photos) }
            return facts.zip(uris) { fact, uri ->
                val persisted =
                    try {
                        grants.take(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        true
                    } catch (e: Exception) {
                        false
                    }
                fact.copy(persisted = persisted)
            }
        }

        private fun factsOf(
            resolver: ContentResolver,
            uri: Uri,
            photo: Boolean,
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
                val facts =
                    empty.copy(
                        sizeBytes = longOf(c, MediaColumns.SIZE) ?: 0,
                        durationMs = longOf(c, MediaColumns.DURATION),
                        dateTakenMs = longOf(c, MediaColumns.DATE_TAKEN),
                        displayName = stringOf(c, MediaColumns.DISPLAY_NAME) ?: "",
                        width = longOf(c, MediaColumns.WIDTH),
                        height = longOf(c, MediaColumns.HEIGHT),
                        mimeType = stringOf(c, MediaColumns.MIME_TYPE),
                    )
                return if (photo) photoFacts(c, facts) else facts
            }
        }

        /** The two facts only a photo pick reads (D-199): the modified date, and the size as seen. */
        private fun photoFacts(
            c: Cursor,
            facts: PickedVideoMsg,
        ): PickedVideoMsg {
            val modifiedMs =
                longOf(c, Document.COLUMN_LAST_MODIFIED)
                    ?: longOf(c, MediaColumns.DATE_MODIFIED)?.let { it * 1000 }
            val turned = longOf(c, MediaColumns.ORIENTATION).let { it == 90L || it == 270L }
            return facts.copy(
                dateModifiedMs = modifiedMs,
                width = if (turned) facts.height else facts.width,
                height = if (turned) facts.width else facts.height,
            )
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
         * The subset of [uris] that can still be read, in order. Only two
         * answers mean gone: a read that is refused (SecurityException) and a
         * cursor with no row. Everything else is a failed read and is thrown, so
         * the caller never reads "failed" as "gone": any other exception, and a
         * null cursor (the provider is not installed, or its process died
         * during the call: `query` swallows that and returns null), which is
         * `FlutterError("no-cursor")` as for MediaStore.
         */
        fun readable(
            resolver: ContentResolver,
            uris: List<String>,
        ): List<String> =
            uris.filter { text ->
                try {
                    val cursor =
                        resolver.query(Uri.parse(text), arrayOf(MediaColumns.DISPLAY_NAME), null, null)
                            ?: throw FlutterError("no-cursor", "the provider returned no cursor")
                    cursor.use { it.moveToFirst() }
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
