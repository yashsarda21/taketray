package app.taketray.editors

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import android.util.Log
import app.taketray.bridge.failureMessage
import app.taketray.bridge.guardedOnIo
import app.taketray.bridge.guardedWith

/**
 * The Kotlin side of the editors bridge (D-121): which editors are
 * installed, the shares to them, the store listing, the free space and
 * TakeTray's copy folders behind their guard ([CopyFolder]).
 *
 * Threading: Pigeon runs every handler on the main thread. Every
 * package-manager, MediaStore and storage read (and the consent request's
 * `createDeleteRequest`) moves to Dispatchers.IO; starting an activity stays
 * on the main thread, where Android expects it.
 *
 * Errors: an unexpected exception reaches Dart as [EditorsError]
 * `native-error` with the method and the exception's class name only, never
 * its message, which can hold a path or a URI (D-10). `no-activity` when an
 * activity is needed and gone; `busy` and `host-gone` from [requestDelete].
 */
class EditorsHostApiImpl(
    activity: Activity,
    private val apps: EditorApps = EditorApps(PackageManagerSource(activity.applicationContext.packageManager)),
    private val folder: CopyFolder = CopyFolder(activity.applicationContext.contentResolver, activity.packageName),
    private val freeBytesOf: () -> Long = ::primaryFreeBytes,
    private val starter: ActivityStarter? = null,
    private val createDeleteRequest: (List<Uri>) -> IntentSender = { uris ->
        MediaStore.createDeleteRequest(activity.applicationContext.contentResolver, uris).intentSender
    },
    private val startSender: (Activity, IntentSender, Int) -> Unit = { host, sender, code ->
        host.startIntentSenderForResult(sender, code, null, 0, 0, 0)
    },
) : EditorsHostApi {
    /** Null once the activity is gone ([onHostGone]). */
    private var activity: Activity? = activity

    /** The one consent dialog in flight; touched on the main thread only. */
    private val deletes = DeleteRequests()

    // ---- Editors ----

    override suspend fun apps(
        packageNames: List<String>,
        iconPx: Long,
    ): List<InstalledAppMsg> =
        io("apps") {
            require(iconPx in 1..EditorApps.MAX_ICON_PX) { "icon size out of range" }
            apps.apps(packageNames, iconPx.toInt())
        }

    override suspend fun sendTo(
        packageName: String,
        clips: List<ShareClipMsg>,
    ): SendResultMsg = main("sendTo") { ShareIntents.send(packageName, clips, starterNow("sendTo")) }

    override suspend fun shareWithChooser(
        clips: List<ShareClipMsg>,
        chooserTitle: String,
    ): Boolean = main("shareWithChooser") { ShareIntents.chooser(clips, chooserTitle, starterNow("shareWithChooser")) }

    override suspend fun openApp(packageName: String): Boolean {
        val start = main("openApp") { starterNow("openApp") }
        val launch = io("openApp") { apps.launchIntent(packageName) }
        return main("openApp") { ShareIntents.openApp(launch, start) }
    }

    override suspend fun openStoreListing(packageName: String): Boolean =
        main("openStoreListing") { ShareIntents.openStoreListing(packageName, starterNow("openStoreListing")) }

    /** The debug recorder when set, else the given starter, else the activity's own. */
    private fun starterNow(method: String): ActivityStarter {
        ActivityStarter.replacement?.let { return it }
        starter?.let { if (activity != null) return it }
        val host = activity ?: throw EditorsError("no-activity", "$method needs the activity")
        return ActivityStarter(host::startActivity)
    }

    // ---- Storage ----

    override suspend fun freeBytes(): Long = io("freeBytes") { freeBytesOf() }

    override suspend fun copyFolderNames(): List<String> = io("copyFolderNames") { folder.copyFolderNames() }

    override suspend fun existingCopies(refs: List<CopyFileRefMsg>): List<Long> =
        io("existingCopies") { if (refs.isEmpty()) emptyList() else folder.existingCopies(refs).toList() }

    override suspend fun deleteCopies(refs: List<CopyFileRefMsg>): DeleteReportMsg =
        io("deleteCopies") {
            if (refs.isEmpty()) DeleteReportMsg(emptyList(), emptyList(), emptyList(), emptyList()) else folder.deleteCopies(refs)
        }

    override suspend fun filesInCopyFolders(): List<CopyFolderFileMsg> = io("filesInCopyFolders") { folder.filesInCopyFolders() }

    /**
     * Android's consent dialog for the rows of [refs] that are in their copy
     * folder with their name (any owner; [CopyFolder.deletableUris]). False,
     * with no dialog, when there is none. The system deletes them once the user
     * allows it.
     */
    override suspend fun requestDelete(refs: List<CopyFileRefMsg>): Boolean {
        if (activity == null) throw EditorsError("no-activity", "requestDelete needs the activity")
        val allowed =
            deletes.run(
                prepare = {
                    io("requestDelete") {
                        val uris = folder.deletableUris(refs)
                        if (uris.isEmpty()) null else createDeleteRequest(uris)
                    }
                },
                start = { sender, code ->
                    val host = activity ?: throw EditorsError("host-gone", "the activity closed before the delete request")
                    main("requestDelete") { startSender(host, sender, code) }
                },
            )
        Log.i(TAG, "requestDelete: ${refs.size} asked, allowed $allowed")
        return allowed
    }

    /** Called by MainActivity.onActivityResult: true when it answered the waiting consent dialog. */
    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean = deletes.onResult(requestCode, resultCode)

    /** The activity is being destroyed: nothing more starts, and a waiting dialog fails instead of hanging. */
    fun onHostGone() {
        activity = null
        deletes.fail(EditorsError("host-gone", "the activity closed before the delete request was answered"))
    }

    private suspend fun <T> io(
        method: String,
        block: () -> T,
    ): T = guardedOnIo(method, ::editorsFailure, block)

    private inline fun <T> main(
        method: String,
        block: () -> T,
    ): T = guardedWith(method, ::editorsFailure, block)

    private companion object {
        const val TAG = "TakeTrayEditors"
    }
}

/**
 * What Dart gets for [e]: an [EditorsError] the bridge threw on purpose as it
 * is; anything else as `native-error` with the method and the class name only
 * (D-10).
 */
private fun editorsFailure(
    method: String,
    e: Throwable,
): EditorsError = e as? EditorsError ?: EditorsError("native-error", failureMessage("TakeTrayEditors", method, e), null)

/** Free bytes on the primary external volume (where the copies go). */
fun primaryFreeBytes(): Long = StatFs(Environment.getExternalStorageDirectory().path).availableBytes
