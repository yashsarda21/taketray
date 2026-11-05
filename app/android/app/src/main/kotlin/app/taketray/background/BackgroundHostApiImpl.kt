package app.taketray.background

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import app.taketray.bridge.PendingPermission
import app.taketray.bridge.blockedAfterRequest
import app.taketray.bridge.failureMessage
import app.taketray.bridge.guardedOnIo
import app.taketray.bridge.guardedWith
import java.util.Locale

internal const val LOG_TAG = "TakeTrayBackground"

/**
 * The Kotlin side of the background bridge (D-103): stores Dart's mirror and
 * arms the background work for it, hands over shade actions and launch
 * actions, and reports and asks for the notification permission.
 *
 * Threading: Pigeon runs every handler on the main thread. [writeState]
 * stores and arms on Dispatchers.IO; [requestNotificationAccess] stays on
 * the main thread, where Android delivers the permission result.
 *
 * Errors: as the media bridge (`bridge/BridgeSupport.kt`), an unexpected
 * exception reaches Dart as "native-error" with the method and the class
 * name only. The phone maker, folders and volume versions are never logged
 * (D-10).
 */
class BackgroundHostApiImpl(
    activity: Activity,
    private val arming: Arming,
    /** MainActivity hands its intents to this relay; [takeLaunchAction] reads it. */
    val launches: LaunchActionRelay,
    private val askPermissions: (Activity, Array<String>, Int) -> Unit = { host, permissions, code ->
        host.requestPermissions(permissions, code)
    },
) : BackgroundHostApi {
    private val context: Context = activity.applicationContext
    private val prefs = context.getSharedPreferences(BackgroundStateStore.PREFS_NAME, Context.MODE_PRIVATE)
    private val store = BackgroundStateStore(prefs)
    private val notifications: NotificationManager = context.getSystemService(NotificationManager::class.java)
    private val notifier = Notifier(context)

    /** Null once the activity is gone ([onHostGone]). */
    private var activity: Activity? = activity

    /** The one notification permission request in flight (its own request code). */
    private val permission = PendingPermission(PERMISSION_REQUEST_CODE)

    private val sdkInt get() = Build.VERSION.SDK_INT

    // ---- The mirror and the shade action ----

    /** Stores the state first, so the arming (and anything it starts) reads the new one. */
    override suspend fun writeState(state: BackgroundStateMsg) =
        guardedOnIo("writeState", ::nativeError) {
            val next = BackgroundState.from(state)
            store.write(next)
            arming.apply(context, next)
        }

    override fun pendingShadeAction(): ShadeActionMsg? = guarded("pendingShadeAction") { store.shadeAction() }

    override fun clearShadeAction(atMs: Long) = guarded("clearShadeAction") { store.clearShadeAction(atMs) }

    /** After a scan in the app: the notification goes, and nothing is shown any more (posted 0). */
    override fun clearNewClipsNotification() =
        guarded("clearNewClipsNotification") {
            notifier.cancelNewClips()
            store.setPostedNewClips(0)
        }

    // ---- Notification permission ----

    override fun notificationAccess(): NotificationAccessMsg = guarded("notificationAccess") { report() }

    /**
     * Below Android 13 there is no dialog: the report comes back unchanged.
     * From 13, as the media request: "no-activity" without the activity,
     * "busy" while one waits, "host-gone" if the activity goes first.
     */
    override suspend fun requestNotificationAccess(): NotificationAccessMsg {
        if (sdkInt < 33) return guarded("requestNotificationAccess") { report() }
        val host = activity ?: throw FlutterError("no-activity", "requestNotificationAccess needs the activity")
        if (permission.isWaiting) throw FlutterError("busy", "a permission request is already showing")
        val rationaleBefore = guarded("requestNotificationAccess") { rationale() }
        permission.await {
            guarded("requestNotificationAccess") { askPermissions(host, arrayOf(POST_NOTIFICATIONS), PERMISSION_REQUEST_CODE) }
        }
        return guarded("requestNotificationAccess") {
            val granted = granted()
            val blocked = blockedAfterRequest(granted, rationaleBefore, rationale(), blocked())
            setBlocked(blocked)
            val report = report()
            Log.i(LOG_TAG, "notification request answered: granted ${report.granted}, canAsk ${report.canAsk}")
            report
        }
    }

    /** Called by MainActivity.onRequestPermissionsResult; true when it was this bridge's request. */
    fun onPermissionResult(requestCode: Int): Boolean = permission.onResult(requestCode)

    /** The activity is being destroyed: a waiting request fails instead of hanging. */
    fun onHostGone() {
        activity = null
        permission.fail(FlutterError("host-gone", "the activity closed before the permission result"))
    }

    /**
     * granted: notifications are on for the app. canAsk: Android 13 or later,
     * not granted, the permission not held (when it is, notifications were
     * switched off in Settings and the dialog would not show), and not
     * blocked by two denials unless Android would show a rationale. A grant
     * clears the remembered block.
     */
    private fun report(): NotificationAccessMsg {
        val granted = granted()
        if (granted && blocked()) setBlocked(false)
        val canAsk =
            sdkInt >= 33 &&
                !granted &&
                context.checkSelfPermission(POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                (rationale() || !blocked())
        return NotificationAccessMsg(granted, canAsk, sdkInt.toLong())
    }

    private fun granted(): Boolean = notifications.areNotificationsEnabled()

    /** Whether Android would explain before asking again (needs the activity; false without one). */
    private fun rationale(): Boolean = activity?.shouldShowRequestPermissionRationale(POST_NOTIFICATIONS) ?: false

    private fun blocked(): Boolean = prefs.getBoolean(KEY_BLOCKED, false)

    private fun setBlocked(blocked: Boolean) = prefs.edit().putBoolean(KEY_BLOCKED, blocked).apply()

    override fun openNotificationSettings() =
        guarded("openNotificationSettings") {
            val host = activity ?: throw FlutterError("no-activity", "openNotificationSettings needs the activity")
            val page = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, host.packageName)
            if (!startFirst(host, page, appDetails(host))) throw ActivityNotFoundException("no settings page")
        }

    // ---- The phone ----

    override fun phoneMaker(): String = guarded("phoneMaker") { Build.MANUFACTURER.orEmpty().trim().lowercase(Locale.ROOT) }

    override fun openBatterySettings(): Boolean =
        guarded("openBatterySettings") {
            val host = activity ?: throw FlutterError("no-activity", "openBatterySettings needs the activity")
            startFirst(host, Intent(Intent.ACTION_POWER_USAGE_SUMMARY), appDetails(host))
        }

    private fun appDetails(host: Activity) =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", host.packageName, null))

    /** Starts the first of [intents] that the phone can open; false when none can. */
    private fun startFirst(
        host: Activity,
        vararg intents: Intent,
    ): Boolean {
        for (intent in intents) {
            try {
                host.startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
                // Not on this phone: try the next.
            } catch (e: SecurityException) {
                // Not exported on this phone: try the next.
            }
        }
        return false
    }

    // ---- Launch actions ----

    override fun takeLaunchAction(): LaunchActionMsg? = guarded("takeLaunchAction") { launches.take() }

    companion object {
        /** The notification permission's request code: 16 bits, unlike the media one (0x7A71) or any plugin's. */
        const val PERMISSION_REQUEST_CODE = 0x7A72

        /** A string, not Manifest.permission.POST_NOTIFICATIONS: it does not exist below API 33. */
        const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"

        /** Remembers that the last request ended blocked; cleared by a grant. */
        private const val KEY_BLOCKED = "notification_request_blocked"
    }
}

/** Runs [block]; an unexpected exception becomes [nativeError]. */
private inline fun <T> guarded(
    method: String,
    block: () -> T,
): T = guardedWith(method, ::nativeError, block)

/** As the media bridge's: a FlutterError as it is; anything else "native-error" with the class name only (D-10). */
internal fun nativeError(
    method: String,
    e: Throwable,
): FlutterError {
    if (e is FlutterError) return e
    return FlutterError("native-error", failureMessage(LOG_TAG, method, e), null)
}
