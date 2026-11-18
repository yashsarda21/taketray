package app.taketray.files

import android.app.Activity
import android.content.ClipData
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Log
import androidx.core.content.FileProvider
import app.taketray.bridge.failureMessage
import app.taketray.bridge.guardedOnIo
import app.taketray.bridge.guardedWith
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred

/**
 * The Kotlin side of the files bridge (D-147), on Android's own screens only:
 * the share sheet for a file in `cache/shared/` (through the app's
 * `FileProvider`), the document picker to save or open a document, and the
 * folder picker, read as a MediaStore relative path. No permission is needed,
 * and no grant is kept: the user's choice is the grant, for this one call.
 *
 * One picker at a time: a second save, open or folder call while one waits
 * fails with `busy`. A result with nobody waiting (Android re-created the
 * activity and its engine while the picker was open) is dropped, and its type
 * logged. The activity going away fails the waiting call with `host-gone`.
 *
 * Threading: Pigeon runs every handler on the main thread, where pickers start
 * and their results arrive; reading and writing a document and the package
 * read move to Dispatchers.IO.
 *
 * Errors: `invalid_path`, `too_large` and `unsupported_folder` on purpose;
 * anything unexpected as `native-error` with the method and the exception's
 * class name only, never its message, which can hold a path or an address.
 * Logs say the call and its outcome, never a path, a name or an address (D-10).
 */
class FilesHostApiImpl(
    activity: Activity,
) : FilesHostApi {
    private val context: Context = activity.applicationContext
    private val resolver: ContentResolver = context.contentResolver

    /** Null once the activity is gone ([onHostGone]). */
    private var activity: Activity? = activity

    /** The one picker in flight; touched on the main thread only. */
    private val pickers = Pickers()

    // ---- The share sheet ----

    override suspend fun shareFile(
        path: String,
        mimeType: String,
        subject: String,
        text: String,
    ): Unit = main("shareFile") {
        val host = activity ?: throw FilesError("no-activity", "shareFile needs the activity")
        val file = sharedFileOf(path) ?: throw FilesError("invalid_path", "shareFile takes a file in cache/shared only")
        val uri = FileProvider.getUriForFile(context, authorityOf(context), file)
        val send =
            Intent(Intent.ACTION_SEND)
                .setType(mimeType)
                .putExtra(Intent.EXTRA_STREAM, uri)
                .putExtra(Intent.EXTRA_SUBJECT, subject)
                .putExtra(Intent.EXTRA_TEXT, text)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // The constructor, not ClipData.newUri: that asks the provider for the type.
        send.clipData = ClipData(null, arrayOf(mimeType), ClipData.Item(uri))
        host.startActivity(Intent.createChooser(send, null))
        Log.i(TAG, "shareFile: share sheet opened")
    }

    /**
     * [path] as a regular file inside `cache/shared/`, both compared after
     * resolving `..` and links; null for anything else (outside, the folder
     * itself, a file that is not there, a relative path, a path the file
     * system cannot resolve, such as one holding a NUL).
     */
    private fun sharedFileOf(path: String): File? {
        val file = File(path)
        if (!file.isAbsolute) return null
        return try {
            val shared = File(context.cacheDir, SHARED_DIR).canonicalFile
            val target = file.canonicalFile
            if (!target.path.startsWith(shared.path + File.separator)) return null
            if (target.isFile) target else null
        } catch (e: IOException) {
            null
        }
    }

    // ---- The document picker ----

    override suspend fun saveDocument(
        suggestedName: String,
        mimeType: String,
        text: String,
    ): String? {
        val intent =
            Intent(Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType(mimeType)
                .putExtra(Intent.EXTRA_TITLE, suggestedName)
        val uri = pick("saveDocument", intent, SAVE_REQUEST_CODE) ?: return null
        io("saveDocument") {
            // A new document: plain "w" is the mode every provider supports.
            val out = resolver.openOutputStream(uri, "w") ?: throw FilesError("native-error", "saveDocument failed: no stream")
            out.use { it.write(text.toByteArray(Charsets.UTF_8)) }
        }
        Log.i(TAG, "saveDocument: saved")
        return uri.toString()
    }

    override suspend fun openDocument(
        mimeTypes: List<String>,
        maxBytes: Long,
    ): String? {
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("*/*")
                .putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
        val uri = pick("openDocument", intent, OPEN_REQUEST_CODE) ?: return null
        val bytes =
            io("openDocument") {
                val input = resolver.openInputStream(uri) ?: throw FilesError("native-error", "openDocument failed: no stream")
                input.use { readAtMost(it, maxBytes) }
            }
        if (bytes == null) {
            Log.i(TAG, "openDocument: over the limit")
            throw FilesError("too_large", "the document is over the limit")
        }
        Log.i(TAG, "openDocument: read")
        return String(bytes, Charsets.UTF_8)
    }

    // ---- The folder picker ----

    override suspend fun pickFolder(): String? {
        // No grant flags: the picker grants this call only, and nothing is kept.
        val uri = pick("pickFolder", Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), FOLDER_REQUEST_CODE) ?: return null
        val path = relativePathOf(uri)
        if (path == null) {
            Log.i(TAG, "pickFolder: unsupported folder")
            throw FilesError("unsupported_folder", "the folder is not on the phone or an SD card")
        }
        Log.i(TAG, "pickFolder: chosen")
        return path
    }

    // ---- The app ----

    override suspend fun appInfo(): AppInfoMsg =
        io("appInfo") {
            @Suppress("DEPRECATION")
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            AppInfoMsg(info.versionName ?: "", Build.VERSION.RELEASE)
        }

    // ---- Results and the activity ----

    /** Starts [intent] for [code] and waits for its address; null when cancelled. `busy` while another waits. */
    private suspend fun pick(
        method: String,
        intent: Intent,
        code: Int,
    ): Uri? {
        val host = activity ?: throw FilesError("no-activity", "$method needs the activity")
        if (pickers.isWaiting) throw FilesError("busy", "a picker is already open")
        val uri = main(method) { pickers.await(code) { host.startActivityForResult(intent, code) } }
        if (uri == null) Log.i(TAG, "$method: cancelled")
        return uri
    }

    /**
     * Called by MainActivity.onActivityResult. True when it answered the
     * waiting picker; a result of this bridge's with nobody waiting (the
     * process died while the picker was open) is dropped and its type logged.
     */
    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        val type = TYPES[requestCode] ?: return false
        val answered = pickers.onResult(requestCode, if (resultCode == Activity.RESULT_OK) data?.data else null)
        if (!answered) Log.i(TAG, "a $type result came with nobody waiting; dropped")
        return answered
    }

    /** The activity is being destroyed: nothing more starts, and a waiting picker fails instead of hanging. */
    fun onHostGone() {
        activity = null
        pickers.fail(FilesError("host-gone", "the activity closed before the picker answered"))
    }

    private suspend fun <T> io(
        method: String,
        block: () -> T,
    ): T = guardedOnIo(method, ::filesFailure, block)

    private inline fun <T> main(
        method: String,
        block: () -> T,
    ): T = guardedWith(method, ::filesFailure, block)

    companion object {
        /** The request codes of the save, open and folder pickers (the other bridges use 0x7A71 to 0x7A75). */
        const val SAVE_REQUEST_CODE = 4101
        const val OPEN_REQUEST_CODE = 4102
        const val FOLDER_REQUEST_CODE = 4103

        /** The only folder in the provider's paths (`res/xml/file_paths.xml`). */
        const val SHARED_DIR = "shared"

        /** The provider of the phone's own storage and its SD cards. */
        const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"

        private const val TAG = "TakeTrayFiles"

        private val TYPES = mapOf(SAVE_REQUEST_CODE to "save", OPEN_REQUEST_CODE to "open", FOLDER_REQUEST_CODE to "folder")

        /** A portable SD card's volume id, such as `1A2B-3C4D`. */
        private val SD_VOLUME = Regex("[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}")

        /** The FileProvider's authority: `<applicationId>.files`, so the dev and the release build never clash. */
        fun authorityOf(context: Context): String = "${context.packageName}.files"

        /**
         * A folder picker's tree address as a MediaStore relative path: the
         * part after `<volume>:` of the tree's document id, without a slash at
         * either end (`''` for the volume's root). Null for any other provider,
         * an address that is not a tree, or a volume that is not `primary` or
         * an SD card's id (the provider's `home` root among them).
         */
        fun relativePathOf(uri: Uri): String? {
            if (uri.scheme != ContentResolver.SCHEME_CONTENT || uri.authority != EXTERNAL_STORAGE_AUTHORITY) return null
            val id =
                try {
                    DocumentsContract.getTreeDocumentId(uri)
                } catch (e: IllegalArgumentException) {
                    return null
                }
            val colon = id.indexOf(':')
            if (colon < 0) return null
            val volume = id.substring(0, colon)
            if (volume != "primary" && !SD_VOLUME.matches(volume)) return null
            return id.substring(colon + 1).trim('/')
        }

        /** Up to [maxBytes] bytes of [input]; null as soon as there is one more. */
        internal fun readAtMost(
            input: java.io.InputStream,
            maxBytes: Long,
        ): ByteArray? {
            require(maxBytes >= 0) { "maxBytes must not be negative" }
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(BUFFER_BYTES)
            var total = 0L
            while (true) {
                val n = input.read(buffer)
                if (n < 0) return out.toByteArray()
                total += n
                if (total > maxBytes) return null
                out.write(buffer, 0, n)
            }
        }

        private const val BUFFER_BYTES = 64 * 1024
    }
}

/**
 * The one picker in flight, answered through the activity's onActivityResult.
 * Touched on the main thread only.
 */
private class Pickers {
    private var waiting: Pair<Int, CompletableDeferred<Uri?>>? = null

    /** True while a picker is open (another one is "busy"). */
    val isWaiting: Boolean get() = waiting != null

    /**
     * Runs [start] (which opens the picker for [code]) and waits for
     * [onResult]. If [start] throws, the slot is freed and the exception passes.
     */
    suspend fun await(
        code: Int,
        start: () -> Unit,
    ): Uri? {
        val answer = CompletableDeferred<Uri?>()
        val entry = code to answer
        waiting = entry
        try {
            start()
            return answer.await()
        } finally {
            if (waiting === entry) waiting = null
        }
    }

    /** True when a picker for [code] was waiting; it then resumes with [uri] (null: cancelled). */
    fun onResult(
        code: Int,
        uri: Uri?,
    ): Boolean {
        val (waitingCode, answer) = waiting ?: return false
        if (waitingCode != code) return false
        waiting = null
        answer.complete(uri)
        return true
    }

    fun fail(error: Throwable) {
        waiting?.let {
            waiting = null
            it.second.completeExceptionally(error)
        }
    }
}

/**
 * What Dart gets for [e]: a [FilesError] the bridge threw on purpose as it is;
 * anything else as `native-error` with the method and the class name only (D-10).
 */
private fun filesFailure(
    method: String,
    e: Throwable,
): FilesError = e as? FilesError ?: FilesError("native-error", failureMessage("TakeTrayFiles", method, e), null)
