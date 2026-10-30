package app.taketray.media

import android.content.Context
import android.provider.MediaStore
import android.util.Log

/**
 * The phone's storage volumes, as MediaStore sees them. An interface because
 * MediaStore.getVersion and getGeneration have no Robolectric shadows.
 */
interface Volumes {
    /** The mounted external volumes, for example `external_primary` and an SD card's id. */
    fun names(): Set<String>

    /** MediaStore's opaque version string, or null when the volume is not mounted. Compare for equality only. */
    fun version(volume: String): String?

    /** The volume's current generation. */
    fun generation(volume: String): Long
}

/** The real [Volumes]. [readVersion] is injectable so its failures can be tested. */
class MediaStoreVolumes(
    private val context: Context,
    private val readVersion: (String) -> String? = { MediaStore.getVersion(context, it) },
) : Volumes {
    override fun names(): Set<String> = MediaStore.getExternalVolumeNames(context)

    /** Null, never a throw, for an unmounted or unknown volume. */
    override fun version(volume: String): String? =
        try {
            readVersion(volume)
        } catch (e: IllegalArgumentException) {
            null
        } catch (e: IllegalStateException) {
            null
        }

    override fun generation(volume: String): Long = MediaStore.getGeneration(context, volume)
}

/**
 * Every volume with its version and generation, sorted by name. A volume whose
 * version or generation read throws is left out (logged by volume name and
 * error class only): to Dart it looks unmounted, so its clips are left alone.
 */
fun readVolumes(volumes: Volumes): List<VolumeMsg> =
    volumes.names().sorted().mapNotNull { name ->
        try {
            VolumeMsg(volumeName = name, version = volumes.version(name), generation = volumes.generation(name))
        } catch (e: Exception) {
            Log.w(LOG_TAG, "volume $name skipped: ${e.javaClass.simpleName}")
            null
        }
    }

/** Tag for the bridge's Android log lines. They never hold a name, path, folder, URI or version string (D-10). */
internal const val LOG_TAG = "TakeTrayMedia"
