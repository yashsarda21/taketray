package app.taketray.media

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * MediaStore.getVersion and getGeneration have no Robolectric shadows, so the
 * version read is injected and the volume list is tested over a fake.
 */
@RunWith(RobolectricTestRunner::class)
class VolumesTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun `a version that throws gives null`() {
        val unmounted = MediaStoreVolumes(context, readVersion = { throw IllegalArgumentException("volume not found") })
        assertNull(unmounted.version("abcd-1234"))
        val stateError = MediaStoreVolumes(context, readVersion = { throw IllegalStateException("not mounted") })
        assertNull(stateError.version("abcd-1234"))
    }

    @Test
    fun `a version is passed through as it is`() {
        val volumes = MediaStoreVolumes(context, readVersion = { "opaque-$it" })
        assertEquals("opaque-external_primary", volumes.version("external_primary"))
    }

    @Test
    fun `any other version failure is not hidden`() {
        val volumes = MediaStoreVolumes(context, readVersion = { throw UnsupportedOperationException() })
        assertThrows(UnsupportedOperationException::class.java) { volumes.version("external_primary") }
    }

    @Test
    fun `the volume list skips a volume whose generation or version throws and keeps a null version`() {
        val fake =
            object : Volumes {
                override fun names() = setOf("external_primary", "abcd-1234", "ffff-0000", "eeee-1111")

                override fun version(volume: String) =
                    when (volume) {
                        "abcd-1234" -> null
                        "eeee-1111" -> throw UnsupportedOperationException()
                        else -> "v-$volume"
                    }

                override fun generation(volume: String): Long =
                    if (volume == "ffff-0000") throw IllegalStateException("gone") else 40L
            }
        assertEquals(
            listOf(
                VolumeMsg("abcd-1234", null, 40),
                VolumeMsg("external_primary", "v-external_primary", 40),
            ),
            readVolumes(fake),
        )
    }
}
