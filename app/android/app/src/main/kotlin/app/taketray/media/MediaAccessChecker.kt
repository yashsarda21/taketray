package app.taketray.media

/**
 * The permission model (D-68): which permission means which access level on
 * each Android version, and which ones to ask for. Pure, so it is tested on
 * the JVM for every version without a phone.
 */
object MediaAccessChecker {
    // Strings, not Manifest.permission constants: the two media ones do not
    // exist below API 33/34, and minSdk is 30.
    const val READ_EXTERNAL_STORAGE = "android.permission.READ_EXTERNAL_STORAGE"
    const val READ_MEDIA_VIDEO = "android.permission.READ_MEDIA_VIDEO"
    const val READ_MEDIA_VISUAL_USER_SELECTED = "android.permission.READ_MEDIA_VISUAL_USER_SELECTED"

    /**
     * Android 11 and 12 (30 to 32): READ_EXTERNAL_STORAGE is full, else denied.
     * Android 13 (33): READ_MEDIA_VIDEO is full, else denied.
     * Android 14 and later (34+): READ_MEDIA_VIDEO is full; only
     * READ_MEDIA_VISUAL_USER_SELECTED ("Select photos and videos") is limited;
     * neither is denied.
     */
    fun level(
        sdkInt: Int,
        granted: (String) -> Boolean,
    ): MediaAccessLevelMsg =
        when {
            sdkInt >= 34 ->
                when {
                    granted(READ_MEDIA_VIDEO) -> MediaAccessLevelMsg.FULL
                    granted(READ_MEDIA_VISUAL_USER_SELECTED) -> MediaAccessLevelMsg.LIMITED
                    else -> MediaAccessLevelMsg.DENIED
                }
            sdkInt == 33 -> if (granted(READ_MEDIA_VIDEO)) MediaAccessLevelMsg.FULL else MediaAccessLevelMsg.DENIED
            else -> if (granted(READ_EXTERNAL_STORAGE)) MediaAccessLevelMsg.FULL else MediaAccessLevelMsg.DENIED
        }

    /**
     * What one request asks for. On 34+ both media permissions are asked
     * together, so the system dialog offers "Allow all" and "Select photos and
     * videos"; the first entry is the one whose rationale decides [canAskAgain].
     */
    fun permissionsToRequest(sdkInt: Int): Array<String> =
        when {
            sdkInt >= 34 -> arrayOf(READ_MEDIA_VIDEO, READ_MEDIA_VISUAL_USER_SELECTED)
            sdkInt == 33 -> arrayOf(READ_MEDIA_VIDEO)
            else -> arrayOf(READ_EXTERNAL_STORAGE)
        }

    /**
     * Whether TakeTray stops asking after a request (D-68, Ruling F). Android
     * gives no rationale both before the first ask and after the final "Don't
     * allow"; it does give one between the first and the second denial. So a
     * request ends blocked only when access is not full, there is no
     * rationale now, and there was one before the request (the second denial)
     * or the last request had already ended blocked (a dismissal while
     * blocked). A first dismissal (no rationale before or after) stays askable.
     */
    fun blockedAfterRequest(
        level: MediaAccessLevelMsg,
        rationaleBefore: Boolean,
        rationaleAfter: Boolean,
        wasBlocked: Boolean,
    ): Boolean = level != MediaAccessLevelMsg.FULL && !rationaleAfter && (rationaleBefore || wasBlocked)

    /**
     * Whether Dart may show the dialog: always with full access, always with
     * limited access (Android shows the picker again for partial access,
     * Ruling G), when Android would show a rationale, or when not [blocked].
     */
    fun canAskAgain(
        level: MediaAccessLevelMsg,
        rationale: Boolean,
        blocked: Boolean,
    ): Boolean = level == MediaAccessLevelMsg.FULL || level == MediaAccessLevelMsg.LIMITED || rationale || !blocked
}
