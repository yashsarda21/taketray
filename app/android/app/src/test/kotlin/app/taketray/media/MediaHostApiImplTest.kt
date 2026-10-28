package app.taketray.media

import android.app.Activity
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import java.io.FileNotFoundException
import java.util.TimeZone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * The real implementation on a Robolectric activity: the permission request
 * (one at a time, never left hanging), the remembered "can ask again", the
 * intents, the zone list, and errors that never carry a path or URI.
 */
@RunWith(RobolectricTestRunner::class)
class MediaHostApiImplTest {
    private lateinit var activity: Activity
    private lateinit var impl: MediaHostApiImpl
    private val sdk get() = Build.VERSION.SDK_INT
    private val code = MediaHostApiImpl.PERMISSION_REQUEST_CODE

    /** The one permission that means full access on this SDK. */
    private val fullPermission
        get() = if (sdk >= 33) MediaAccessChecker.READ_MEDIA_VIDEO else MediaAccessChecker.READ_EXTERNAL_STORAGE

    private val noVolumes =
        object : Volumes {
            override fun names() = emptySet<String>()

            override fun version(volume: String): String? = null

            override fun generation(volume: String) = 0L
        }

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        activity.getSharedPreferences(ZoneChangeStore.PREFS_NAME, Context.MODE_PRIVATE).edit().clear().commit()
        impl = MediaHostApiImpl(activity, noVolumes)
    }

    /**
     * Runs a test body with a time limit, so a request that is never answered
     * fails the test instead of hanging it; a failing child coroutine is
     * reported by its await, not by cancelling the test.
     */
    private fun timed(body: suspend CoroutineScope.() -> Unit) =
        runBlocking { withTimeout(5_000) { supervisorScope { body() } } }

    private suspend fun requestError(): FlutterError? =
        try {
            impl.requestAccess()
            null
        } catch (e: FlutterError) {
            e
        }

    @Test
    fun `requestAccess asks for this SDK's permissions and reports the result`() =
        timed {
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
            val asked = shadowOf(activity).lastRequestedPermission
            assertArrayEquals(MediaAccessChecker.permissionsToRequest(sdk), asked.requestedPermissions)
            assertEquals(code, asked.requestCode)
            assertFalse(first.isCompleted)

            shadowOf(activity.application).grantPermissions(fullPermission)
            assertTrue(impl.onPermissionResult(code))
            assertEquals(AccessReportMsg(MediaAccessLevelMsg.FULL, true, sdk.toLong()), first.await())
        }

    @Test
    fun `a second permission request while one is pending fails with busy`() =
        timed {
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
            assertEquals("busy", requestError()?.code)
            assertFalse(first.isCompleted)

            impl.onPermissionResult(code)
            assertEquals(MediaAccessLevelMsg.DENIED, first.await().level)
            // Once answered, a new request may start.
            val again = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
            impl.onPermissionResult(code)
            assertEquals(MediaAccessLevelMsg.DENIED, again.await().level)
        }

    @Test
    fun `a result for another request code is ignored`() =
        timed {
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
            assertFalse(impl.onPermissionResult(code + 1))
            assertFalse(first.isCompleted)
            assertTrue(impl.onPermissionResult(code))
            first.await()
            // A late result with nothing pending is harmless.
            assertFalse(impl.onPermissionResult(code))
        }

    @Test
    fun `the host going away fails the pending request instead of leaving it hanging`() =
        timed { hostGone() }

    private suspend fun CoroutineScope.hostGone() {
        val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
        impl.onHostGone()
        try {
            first.await()
            fail("expected the pending request to fail")
        } catch (e: FlutterError) {
            assertEquals("host-gone", e.code)
        }
        // Without an activity nothing can be asked or opened.
        assertEquals("no-activity", requestError()?.code)
    }

    @Test
    fun `a denial without a rationale is remembered as cannot ask again`() =
        timed {
            assertEquals(AccessReportMsg(MediaAccessLevelMsg.DENIED, true, sdk.toLong()), impl.accessReport())

            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
            shadowOf(activity.packageManager).setShouldShowRequestPermissionRationale(
                MediaAccessChecker.permissionsToRequest(sdk).first(),
                false,
            )
            impl.onPermissionResult(code)
            assertFalse(first.await().canAskAgain)
            assertFalse(impl.accessReport().canAskAgain)
            // A fresh impl (the app restarted) still remembers it.
            assertFalse(MediaHostApiImpl(activity, noVolumes).accessReport().canAskAgain)

            // Android shows its dialog again (a rationale), or access became full.
            shadowOf(activity.packageManager).setShouldShowRequestPermissionRationale(
                MediaAccessChecker.permissionsToRequest(sdk).first(),
                true,
            )
            assertTrue(impl.accessReport().canAskAgain)
        }

    @Test
    fun `a denial with a rationale can ask again`() =
        timed {
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
            shadowOf(activity.packageManager).setShouldShowRequestPermissionRationale(
                MediaAccessChecker.permissionsToRequest(sdk).first(),
                true,
            )
            impl.onPermissionResult(code)
            assertTrue(first.await().canAskAgain)
        }

    @Test
    fun `full access is reported with the SDK level`() {
        shadowOf(activity.application).grantPermissions(fullPermission)
        assertEquals(AccessReportMsg(MediaAccessLevelMsg.FULL, true, sdk.toLong()), impl.accessReport())
    }

    @Test
    @Config(sdk = [34, 35])
    fun `only selected photos and videos is limited on 14 and later`() {
        shadowOf(activity.application).grantPermissions(MediaAccessChecker.READ_MEDIA_VISUAL_USER_SELECTED)
        assertEquals(MediaAccessLevelMsg.LIMITED, impl.accessReport().level)
    }

    @Test
    fun `openAppSettings opens this app's details page`() {
        impl.openAppSettings()
        val started = shadowOf(activity).nextStartedActivity
        assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, started.action)
        assertEquals("package:${activity.packageName}", started.dataString)
    }

    @Test
    fun `openVideoCamera starts the video camera, and is false when there is none`() {
        assertTrue(impl.openVideoCamera())
        assertEquals(MediaStore.INTENT_ACTION_VIDEO_CAMERA, shadowOf(activity).nextStartedActivity.action)

        shadowOf(activity.application).checkActivities(true)
        assertFalse(impl.openVideoCamera())
    }

    @Test
    fun `zone changes go through the native store`() {
        val store =
            ZoneChangeStore(activity.getSharedPreferences(ZoneChangeStore.PREFS_NAME, Context.MODE_PRIVATE))
        store.record(1_000, "Europe/Berlin")
        store.record(2_000, "UTC")
        assertEquals(listOf(ZoneChangeMsg(1_000, "Europe/Berlin"), ZoneChangeMsg(2_000, "UTC")), impl.pendingZoneChanges())
        impl.clearZoneChangesUpTo(1_000)
        assertEquals(listOf(ZoneChangeMsg(2_000, "UTC")), impl.pendingZoneChanges())
        assertEquals(TimeZone.getDefault().id, impl.currentZoneId())
    }

    @Test
    fun `a gone thumbnail is null`() =
        timed {
            FakeMediaProvider.install(FileNotFoundException("gone"))
            assertNull(impl.thumbnail("external_primary", 4821, 96, 96))
        }

    @Test
    fun `a query that gets no cursor is an error, never an empty answer`() =
        timed {
            // An empty list from videosByIds would mean "every clip is gone".
            FakeMediaProvider.install()
            for (call in listOf<suspend () -> Unit>(
                { impl.videosByIds("external_primary", listOf(1, 2)) },
                { impl.videosAddedAfter("external_primary", 0, listOf("DCIM/Camera/"), 10) },
                { impl.allVideos("external_primary") },
                { impl.videosShotSince("external_primary", listOf("DCIM/Camera/"), 0) },
            )) {
                try {
                    call()
                    fail("expected an error")
                } catch (e: FlutterError) {
                    assertEquals("no-cursor", e.code)
                }
            }
        }

    @Test
    fun `no ids, no folders to ask about, or a limit of 0 give no rows without a query`() =
        timed {
            assertEquals(emptyList<VideoRowMsg>(), impl.videosByIds("external_primary", emptyList()))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosAddedAfter("external_primary", 0, listOf("A/"), 0))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosAddedAfter("external_primary", 0, listOf("A/"), -1))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosAddedAfter("external_primary", 0, emptyList(), 10))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosShotSince("external_primary", emptyList(), 0))
        }

    @Test
    fun `an unexpected error reaches Dart without its message`() {
        val error =
            nativeError(
                "thumbnail",
                FileNotFoundException("content://media/external_primary/video/media/4821 /storage/emulated/0/DCIM/Camera/VID_1.mp4"),
            )
        assertEquals("native-error", error.code)
        assertEquals("thumbnail failed: FileNotFoundException", error.message)
        assertNull(error.details)
        assertNull(error.cause)
        assertFalse(error.toString().contains("content://"))
        // A FlutterError the code threw on purpose passes through as it is.
        val busy = FlutterError("busy", "already asking")
        assertTrue(nativeError("requestAccess", busy) === busy)
    }

    @Test
    fun `volumes come from the injected volume source`() {
        assertEquals(emptyList<VolumeMsg>(), impl.volumes())
    }
}
