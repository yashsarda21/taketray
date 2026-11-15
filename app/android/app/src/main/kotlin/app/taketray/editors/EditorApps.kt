package app.taketray.editors

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Log
import java.io.ByteArrayOutputStream

/** What [EditorApps] reads from the package manager (a seam for the tests). */
interface PackageSource {
    /** The package's ApplicationInfo; throws `NameNotFoundException` when it is not installed. */
    fun applicationInfo(packageName: String): ApplicationInfo

    /** The package's launcher icon; throws `NameNotFoundException` when it is not installed. */
    fun icon(packageName: String): Drawable

    /** The package's launcher intent, or null when it has none. */
    fun launchIntent(packageName: String): Intent?
}

class PackageManagerSource(
    private val pm: PackageManager,
) : PackageSource {
    override fun applicationInfo(packageName: String): ApplicationInfo = pm.getApplicationInfo(packageName, 0)

    override fun icon(packageName: String): Drawable = pm.getApplicationIcon(packageName)

    override fun launchIntent(packageName: String): Intent? = pm.getLaunchIntentForPackage(packageName)
}

/**
 * Which editors are installed, with their launcher icons (D-121). The package
 * names come from Dart (`EditorApp.packageName`); the manifest lists each in
 * `<queries>`, without which Android 11+ hides them.
 *
 * A package that is not there, is disabled, or disappears between the two
 * reads is `installed = false`; the call never fails for one. Any other
 * package-manager failure fails the whole call, so a broken read is never
 * shown as "not installed". An icon that cannot be drawn leaves the app
 * installed with no icon.
 *
 * Binder calls: call it off the main thread. Logs never name a package (D-10).
 */
class EditorApps(
    private val packages: PackageSource,
) {
    /** Each of [packageNames], in order. [iconPx] must be 1 to [MAX_ICON_PX]. */
    fun apps(
        packageNames: List<String>,
        iconPx: Int,
    ): List<InstalledAppMsg> {
        require(iconPx in 1..MAX_ICON_PX) { "icon size out of range" }
        val override = installedOverride
        return packageNames.map { name ->
            val forced = override?.get(name)
            if (forced == false) return@map InstalledAppMsg(name, false, null)
            var present = false
            var png: ByteArray? = null
            try {
                if (packages.applicationInfo(name).enabled) {
                    png = iconPng(name, iconPx)
                    present = true
                }
            } catch (e: PackageManager.NameNotFoundException) {
                // Not installed, or uninstalled while its icon was read.
                png = null
            }
            InstalledAppMsg(name, present || forced == true, png)
        }
    }

    /** The launcher intent of [packageName], or null when it has none or the debug override says it is not there. */
    fun launchIntent(packageName: String): Intent? =
        if (installedOverride?.get(packageName) == false) null else packages.launchIntent(packageName)

    /**
     * The icon drawn to a [px] square PNG; null when it cannot be drawn.
     * Throws `NameNotFoundException` when the package is gone.
     */
    private fun iconPng(
        name: String,
        px: Int,
    ): ByteArray? {
        val drawable =
            try {
                packages.icon(name)
            } catch (e: PackageManager.NameNotFoundException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "an icon could not be read: ${e.javaClass.simpleName}")
                return null
            }
        return try {
            val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, px, px)
            drawable.draw(Canvas(bitmap))
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } catch (e: Exception) {
            Log.w(TAG, "an icon could not be drawn: ${e.javaClass.simpleName}")
            null
        }
    }

    companion object {
        private const val TAG = "TakeTrayEditorApps"

        /** The largest icon side asked for, in pixels. */
        const val MAX_ICON_PX = 512

        /**
         * Package name to installed, for the packages it names; null (always,
         * in release) means "ask the package manager". Only the debug build's
         * editor hooks set it, so the on-device tests can show an editor as
         * installed or missing.
         */
        @Volatile
        var installedOverride: Map<String, Boolean>? = null
    }
}
