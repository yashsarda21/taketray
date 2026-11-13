package app.taketray.editors

import android.content.Intent

/**
 * Starts an activity for the editors bridge: a share to an editor, the
 * chooser, an editor's launcher or the store listing. The real one is the
 * activity's `startActivity`, called on the main thread.
 *
 * The debug build's intent recorder (`src/debug`, D-121) sets [replacement]
 * so the on-device tests can check the intent without opening CapCut, Edits,
 * VN, the Play Store or the share sheet. The release build never sets it.
 */
fun interface ActivityStarter {
    /** Starts [intent]; throws what `startActivity` throws (for example `ActivityNotFoundException`). */
    fun start(intent: Intent)

    companion object {
        /** When set, used instead of the activity's own starter. Only the debug build sets it. */
        @Volatile
        var replacement: ActivityStarter? = null
    }
}
