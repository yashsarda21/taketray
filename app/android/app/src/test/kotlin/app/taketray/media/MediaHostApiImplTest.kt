package app.taketray.media

import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.database.MatrixCursor
import android.graphics.Point
import android.net.Uri
import android.os.Build
import android.os.Looper
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
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

    private val firstPermission get() = MediaAccessChecker.permissionsToRequest(sdk).first()

    private fun rationale(show: Boolean) =
        shadowOf(activity.packageManager).setShouldShowRequestPermissionRationale(firstPermission, show)

    /**
     * One permission request: [before] is Android's rationale when it is
     * asked, [after] the rationale when the answer comes; [grant] gives full
     * access in the dialog.
     */
    private suspend fun CoroutineScope.request(
        before: Boolean,
        after: Boolean,
        grant: Boolean = false,
    ): AccessReportMsg {
        rationale(before)
        val pending = async(start = CoroutineStart.UNDISPATCHED) { impl.requestAccess() }
        rationale(after)
        if (grant) shadowOf(activity.application).grantPermissions(fullPermission)
        assertTrue(impl.onPermissionResult(code))
        return pending.await()
    }

    /** Two denials: the second takes the rationale from true to false. */
    private suspend fun CoroutineScope.getBlocked() {
        assertTrue(request(before = false, after = true).canAskAgain)
        assertFalse(request(before = true, after = false).canAskAgain)
    }

    @Test
    fun `before any request a denied report can ask`() {
        assertEquals(AccessReportMsg(MediaAccessLevelMsg.DENIED, true, sdk.toLong()), impl.accessReport())
    }

    @Test
    fun `request - a first dismissal stays askable`() =
        timed {
            assertTrue(request(before = false, after = false).canAskAgain)
            assertTrue(impl.accessReport().canAskAgain)
        }

    @Test
    fun `request - a first explicit denial stays askable`() =
        timed {
            assertTrue(request(before = false, after = true).canAskAgain)
            assertTrue(impl.accessReport().canAskAgain)
        }

    @Test
    fun `request - a second denial with the rationale going from true to false is blocked`() =
        timed {
            getBlocked()
            assertFalse(impl.accessReport().canAskAgain)
            // A fresh impl (the app restarted) still remembers it.
            assertFalse(MediaHostApiImpl(activity, noVolumes).accessReport().canAskAgain)
        }

    @Test
    fun `request - a dismissal while blocked stays blocked`() =
        timed {
            getBlocked()
            assertFalse(request(before = false, after = false).canAskAgain)
            assertFalse(impl.accessReport().canAskAgain)
        }

    @Test
    fun `request - a grant clears the flag`() =
        timed {
            getBlocked()
            assertEquals(AccessReportMsg(MediaAccessLevelMsg.FULL, true, sdk.toLong()), request(false, false, grant = true))
            // Revoked later, with no rationale (Android's auto-reset): askable.
            shadowOf(activity.application).denyPermissions(fullPermission)
            rationale(false)
            assertTrue(impl.accessReport().canAskAgain)
        }

    @Test
    fun `accessReport clears a stale block when access is full`() =
        timed {
            getBlocked()
            // Granted in Settings, without a request.
            shadowOf(activity.application).grantPermissions(fullPermission)
            assertEquals(MediaAccessLevelMsg.FULL, impl.accessReport().level)
            shadowOf(activity.application).denyPermissions(fullPermission)
            rationale(false)
            assertTrue(impl.accessReport().canAskAgain)
        }

    @Test
    @Config(sdk = [34, 35])
    fun `limited access can always ask again`() =
        timed {
            getBlocked()
            shadowOf(activity.application).grantPermissions(MediaAccessChecker.READ_MEDIA_VISUAL_USER_SELECTED)
            assertEquals(AccessReportMsg(MediaAccessLevelMsg.LIMITED, true, sdk.toLong()), impl.accessReport())
            assertEquals(AccessReportMsg(MediaAccessLevelMsg.LIMITED, true, sdk.toLong()), request(true, false))
        }

    @Test
    fun `a failing permission request reaches Dart without its message and frees the slot`() =
        timed {
            impl =
                MediaHostApiImpl(activity, noVolumes) { _, _, _ ->
                    throw IllegalStateException("content://media/external/video/media/1 /storage/emulated/0/x.mp4")
                }
            repeat(2) {
                val error = requestError()
                assertEquals("native-error", error?.code)
                assertEquals("requestAccess failed: IllegalStateException", error?.message)
                assertFalse(error.toString().contains("content://"))
            }
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
    fun `zone offsets come from ZoneOffsets, off the main thread`() =
        timed {
            assertEquals(Looper.getMainLooper(), Looper.myLooper())
            var onMain: Boolean? = null
            val spy =
                MediaHostApiImpl(activity, noVolumes, offsetsOf = { ids, at ->
                    onMain = Looper.myLooper() == Looper.getMainLooper()
                    ZoneOffsets.offsetsMs(ids, at)
                })
            assertEquals(
                listOf<Long?>(3_600_000L, null, 19_800_000L),
                spy.zoneOffsetsMs(listOf("Europe/London", "Not/AZone", "Asia/Kolkata"), listOf(1_782_907_200_000L, 0L, 0L)),
            )
            assertEquals(false, onMain)
            // The default is the real ZoneOffsets.
            assertEquals(listOf<Long?>(0L), impl.zoneOffsetsMs(listOf("UTC"), listOf(0L)))
        }

    @Test
    fun `zone offsets with lists of different lengths are a native-error`() =
        timed {
            val error =
                try {
                    impl.zoneOffsetsMs(listOf("Europe/London"), emptyList())
                    null
                } catch (e: FlutterError) {
                    e
                }
            assertEquals("native-error", error?.code)
            assertEquals("zoneOffsetsMs failed: IllegalArgumentException", error?.message)
        }

    @Test
    fun `a gone thumbnail is null`() =
        timed {
            FakeMediaProvider.install(FileNotFoundException("gone"))
            assertNull(impl.thumbnail("external_primary", 4821, 96, 96))
        }

    @Test
    fun `a thumbnail size of 0 or less is an error`() =
        timed {
            FakeMediaProvider.install()
            for ((w, h) in listOf(0L to 96L, 96L to 0L, -5L to 96L)) {
                try {
                    impl.thumbnail("external_primary", 1, w, h)
                    fail("expected an error for $w x $h")
                } catch (e: FlutterError) {
                    assertEquals("native-error", e.code)
                }
            }
            assertTrue(FakeMediaProvider.opens.isEmpty())
        }

    @Test
    fun `a thumbnail request is capped at 4096 pixels a side`() =
        timed {
            FakeMediaProvider.install(FileNotFoundException("gone"))
            assertNull(impl.thumbnail("external_primary", 1, 10_000, 5_000))
            @Suppress("DEPRECATION")
            val size = FakeMediaProvider.opens.single().getParcelable<Point>(ContentResolver.EXTRA_SIZE)
            assertEquals(Point(4096, 4096), size)
        }

    /** A cursor in [VideoQueries.PROJECTION] order; each row maps column to value, missing columns null. */
    private fun cursorOf(rows: List<Map<String, Any?>>): MatrixCursor =
        MatrixCursor(VideoQueries.PROJECTION).apply {
            for (r in rows) addRow(VideoQueries.PROJECTION.map { r[it] }.toTypedArray())
        }

    private fun videoRow(
        id: Long,
        path: String? = "DCIM/Camera/",
        pending: Long = 0,
    ) = mapOf(
        MediaColumns._ID to id,
        MediaColumns.GENERATION_ADDED to id,
        MediaColumns.SIZE to 1000L,
        MediaColumns.RELATIVE_PATH to path,
        MediaColumns.IS_PENDING to pending,
    )

    private fun FakeMediaProvider.Query.selectionArgs() =
        args!!.getStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS)!!.toList()

    @Test
    fun `videosByIds drops duplicate ids and asks in chunks of 500, rows concatenated`() =
        timed {
            FakeMediaProvider.install(answer = { q -> cursorOf(q.selectionArgs().map { videoRow(it.toLong()) }) })
            val ids = (1L..1201L).toList() + listOf(7L, 600L, 1201L)
            val rows = impl.videosByIds("external_primary", ids)

            val queries = FakeMediaProvider.queries
            assertEquals(listOf(500, 500, 201), queries.map { it.selectionArgs().size })
            val chunks = listOf((1L..500L).toList(), (501L..1000L).toList(), (1001L..1201L).toList())
            for ((q, chunk) in queries.zip(chunks)) {
                assertEquals(MediaStore.Video.Media.getContentUri("external_primary"), q.uri)
                assertEquals(VideoQueries.PROJECTION.toList(), q.projection)
                assertEquals(VideoQueries.idsSelection(chunk).first, q.args!!.getString(ContentResolver.QUERY_ARG_SQL_SELECTION))
                assertEquals(chunk.map { it.toString() }, q.selectionArgs())
                assertEquals(MediaStore.MATCH_INCLUDE, q.args!!.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
            }
            assertEquals((1L..1201L).toList(), rows.map { it.mediaStoreId })
            assertTrue(rows.all { it.volumeName == "external_primary" })
        }

    @Test
    fun `videosAddedAfter asks the volume's video table, pending included, with the limit`() =
        timed {
            FakeMediaProvider.install(answer = { cursorOf(listOf(videoRow(42), videoRow(43, pending = 1))) })
            val rows = impl.videosAddedAfter("abcd-1234", 41, listOf("DCIM/Camera"), 25)

            val q = FakeMediaProvider.queries.single()
            assertEquals(MediaStore.Video.Media.getContentUri("abcd-1234"), q.uri)
            assertEquals(VideoQueries.PROJECTION.toList(), q.projection)
            val expected = VideoQueries.addedAfterSelection(41, listOf("DCIM/Camera"))
            assertEquals(expected.first, q.args!!.getString(ContentResolver.QUERY_ARG_SQL_SELECTION))
            assertEquals(expected.second.toList(), q.selectionArgs())
            assertEquals(MediaStore.MATCH_INCLUDE, q.args!!.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
            assertEquals(MediaStore.MATCH_EXCLUDE, q.args!!.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED))
            assertEquals(25, q.args!!.getInt(ContentResolver.QUERY_ARG_LIMIT))
            assertEquals(listOf(42L, 43L), rows.map { it.mediaStoreId })
            assertEquals(listOf(false, true), rows.map { it.isPending })
            assertTrue(rows.all { it.volumeName == "abcd-1234" })
        }

    @Test
    fun `videoFolders counts per path on every volume, a null path as empty, sorted`() =
        timed {
            val twoVolumes =
                object : Volumes {
                    override fun names() = setOf("external_primary", "abcd-1234")

                    override fun version(volume: String): String? = "v"

                    override fun generation(volume: String) = 1L
                }
            impl = MediaHostApiImpl(activity, twoVolumes)
            val primary = MediaStore.Video.Media.getContentUri("external_primary")
            FakeMediaProvider.install(answer = { q ->
                val paths =
                    if (q.uri == primary) listOf("Movies/", "DCIM/Camera/", "DCIM/Camera/") else listOf("DCIM/", null)
                MatrixCursor(arrayOf(MediaColumns.RELATIVE_PATH)).apply { paths.forEach { addRow(arrayOf<Any?>(it)) } }
            })
            assertEquals(
                listOf(
                    VideoFolderMsg("abcd-1234", "", 1),
                    VideoFolderMsg("abcd-1234", "DCIM/", 1),
                    VideoFolderMsg("external_primary", "DCIM/Camera/", 2),
                    VideoFolderMsg("external_primary", "Movies/", 1),
                ),
                impl.videoFolders(),
            )
            val queries = FakeMediaProvider.queries
            assertEquals(
                listOf(MediaStore.Video.Media.getContentUri("abcd-1234"), primary),
                queries.map { it.uri },
            )
            for (q in queries) {
                assertEquals(listOf(MediaColumns.RELATIVE_PATH), q.projection)
                assertEquals(MediaStore.MATCH_EXCLUDE, q.args!!.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
            }
        }

    @Test
    fun `a query on an unknown or unmounted volume is an error, never an empty answer`() =
        timed {
            FakeMediaProvider.install(answer = {
                throw IllegalArgumentException("Volume external_gone not found: content://media/external_gone/video/media")
            })
            impl =
                MediaHostApiImpl(
                    activity,
                    object : Volumes {
                        override fun names() = setOf("external_gone")

                        override fun version(volume: String): String? = null

                        override fun generation(volume: String) = 0L
                    },
                )
            for (call in listOf<suspend () -> Unit>(
                { impl.videosByIds("external_gone", listOf(1, 2)) },
                { impl.videosAddedAfter("external_gone", 0, listOf("DCIM/Camera/"), 10) },
                { impl.allVideos("external_gone") },
                { impl.videosShotSince("external_gone", listOf("DCIM/Camera/"), 0) },
                { impl.videoFolders() },
            )) {
                try {
                    call()
                    fail("expected an error")
                } catch (e: FlutterError) {
                    assertEquals("native-error", e.code)
                    assertFalse(e.toString().contains("content://"))
                }
            }
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
            FakeMediaProvider.install()
            assertEquals(emptyList<VideoRowMsg>(), impl.videosByIds("external_primary", emptyList()))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosAddedAfter("external_primary", 0, listOf("A/"), 0))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosAddedAfter("external_primary", 0, listOf("A/"), -1))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosAddedAfter("external_primary", 0, emptyList(), 10))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosShotSince("external_primary", emptyList(), 0))
            assertTrue(FakeMediaProvider.queries.isEmpty())
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
    fun `volumes come from the injected volume source`() =
        timed {
            assertEquals(emptyList<VolumeMsg>(), impl.volumes())
        }
    // ---- Folder pages (D-112) ----

    private fun volumesOf(vararg names: String) =
        object : Volumes {
            override fun names() = names.toSet()

            override fun version(volume: String): String? = "v"

            override fun generation(volume: String) = 1L
        }

    private fun folderRow(
        id: Long,
        path: String = "DCIM/Camera/",
    ) = videoRow(id, path).toMutableMap().apply {
        put(MediaColumns.DURATION, 5_000L)
        put(MediaColumns.DISPLAY_NAME, "VID_$id.mp4")
    }

    @Test
    fun `videosInFolder asks one folder of the volume's video table, a page at a time, off the main thread`() =
        timed {
            impl = MediaHostApiImpl(activity, volumesOf("abcd-1234"))
            var onMain: Boolean? = null
            FakeMediaProvider.install(answer = {
                onMain = Looper.myLooper() == Looper.getMainLooper()
                cursorOf(listOf(folderRow(42), folderRow(41)))
            })
            val rows = impl.videosInFolder("abcd-1234", "DCIM/Camera", 25, 50)

            val q = FakeMediaProvider.queries.single()
            assertEquals(MediaStore.Video.Media.getContentUri("abcd-1234"), q.uri)
            assertEquals(VideoQueries.PROJECTION.toList(), q.projection)
            val expected = VideoQueries.inFolderSelection("DCIM/Camera")
            assertEquals(expected.first, q.args!!.getString(ContentResolver.QUERY_ARG_SQL_SELECTION))
            assertEquals(expected.second.toList(), q.selectionArgs())
            assertEquals(MediaStore.MATCH_EXCLUDE, q.args!!.getInt(MediaStore.QUERY_ARG_MATCH_PENDING))
            assertEquals(MediaStore.MATCH_EXCLUDE, q.args!!.getInt(MediaStore.QUERY_ARG_MATCH_TRASHED))
            assertEquals(VideoQueries.SHOT_NEWEST_ORDER, q.args!!.getString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER))
            assertEquals(25, q.args!!.getInt(ContentResolver.QUERY_ARG_LIMIT))
            assertEquals(50, q.args!!.getInt(ContentResolver.QUERY_ARG_OFFSET))
            // The provider's order is kept.
            assertEquals(listOf(42L, 41L), rows.map { it.mediaStoreId })
            assertTrue(rows.all { it.volumeName == "abcd-1234" })
            assertEquals(false, onMain)
        }

    @Test
    fun `videosInFolder with a limit of 0 or less gives no rows without a query, and a negative offset is 0`() =
        timed {
            impl = MediaHostApiImpl(activity, volumesOf("external_primary"))
            FakeMediaProvider.install(answer = { cursorOf(listOf(folderRow(1))) })
            assertEquals(emptyList<VideoRowMsg>(), impl.videosInFolder("external_primary", "A/", 0, 0))
            assertEquals(emptyList<VideoRowMsg>(), impl.videosInFolder("external_primary", "A/", -3, 0))
            assertTrue(FakeMediaProvider.queries.isEmpty())
            impl.videosInFolder("external_primary", "A/", 10, -7)
            assertEquals(0, FakeMediaProvider.queries.single().args!!.getInt(ContentResolver.QUERY_ARG_OFFSET))
        }

    @Test
    fun `videosInFolder on a volume that is gone is empty and never asks the provider`() =
        timed {
            impl = MediaHostApiImpl(activity, volumesOf("external_primary"))
            FakeMediaProvider.install(answer = { throw AssertionError("a gone volume must not be queried") })
            assertEquals(emptyList<VideoRowMsg>(), impl.videosInFolder("1234-ABCD", "DCIM/", 10, 0))
            assertTrue(FakeMediaProvider.queries.isEmpty())
            // No volumes at all.
            impl = MediaHostApiImpl(activity, noVolumes)
            assertEquals(emptyList<VideoRowMsg>(), impl.videosInFolder("external_primary", "DCIM/", 10, 0))
        }

    @Test
    fun `videosInFolder on a volume removed while the query runs is empty`() =
        timed {
            var present = true
            impl =
                MediaHostApiImpl(
                    activity,
                    object : Volumes {
                        override fun names() = if (present) setOf("1234-ABCD") else emptySet()

                        override fun version(volume: String): String? = "v"

                        override fun generation(volume: String) = 1L
                    },
                )
            FakeMediaProvider.install(answer = {
                present = false // the card is pulled during the query
                throw IllegalArgumentException("Volume 1234-ABCD not found")
            })
            assertEquals(emptyList<VideoRowMsg>(), impl.videosInFolder("1234-ABCD", "DCIM/", 10, 0))
        }

    @Test
    fun `videosInFolder failing on a volume that is still there is an error, never an empty page`() =
        timed {
            impl = MediaHostApiImpl(activity, volumesOf("external_primary"))
            for (failure in listOf<() -> android.database.Cursor?>(
                { throw IllegalArgumentException("Invalid column") },
                { throw IllegalStateException("provider died") },
                { null },
            )) {
                FakeMediaProvider.install(answer = { failure() })
                try {
                    impl.videosInFolder("external_primary", "DCIM/", 10, 0)
                    fail("expected an error")
                } catch (e: FlutterError) {
                    assertTrue(e.code, e.code == "native-error" || e.code == "no-cursor")
                }
            }
        }

    // ---- Saved addresses ----

    private val mediaUri = MediaStore.Video.Media.getContentUri("external_primary")

    private fun videoUri(id: Long): String = Uri.withAppendedPath(mediaUri, "$id").toString()

    @Test
    fun `readableUris keeps the readable ones, off the main thread, and fails whole when a query fails`() =
        timed {
            val threads = mutableListOf<Boolean>()
            FakeMediaProvider.install(answer = { q ->
                threads += Looper.myLooper() == Looper.getMainLooper()
                when (q.uri.lastPathSegment) {
                    "1" -> MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME)).apply { addRow(arrayOf<Any?>("a")) }
                    "2" -> throw SecurityException("grant lost")
                    "3" -> MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME))
                    else -> throw IllegalStateException("provider died")
                }
            })
            assertEquals(listOf(videoUri(1)), impl.readableUris(listOf(videoUri(1), videoUri(2), videoUri(3))))
            assertTrue(threads.isNotEmpty() && threads.none { it })
            try {
                impl.readableUris(listOf(videoUri(1), videoUri(4)))
                fail("expected an error")
            } catch (e: FlutterError) {
                assertEquals("readableUris failed: IllegalStateException", e.message)
            }
        }

    @Test
    fun `readableUris with a null cursor fails whole, as no-cursor, so a failed read is never gone`() =
        timed {
            FakeMediaProvider.install(answer = { q ->
                if (q.uri.lastPathSegment == "2") {
                    null
                } else {
                    MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME)).apply { addRow(arrayOf<Any?>("a")) }
                }
            })
            try {
                impl.readableUris(listOf(videoUri(1), videoUri(2)))
                fail("expected an error")
            } catch (e: FlutterError) {
                assertEquals("no-cursor", e.code)
                assertFalse(e.toString().contains("content://"))
            }
        }

    @Test
    fun `releaseUris and persistedUris never carry a uri in an error`() =
        timed {
            // Nothing is persisted in a fresh app: an empty list, and a release of an unknown uri is harmless.
            assertEquals(emptyList<String>(), impl.persistedUris())
            impl.releaseUris(listOf(videoUri(1), "not a uri", ""))
        }

    @Test
    fun `thumbnailOfUri is null for a gone video and for an address that is not a content address`() =
        timed {
            FakeMediaProvider.install(FileNotFoundException("gone"))
            assertNull(impl.thumbnailOfUri(videoUri(4821), 96, 96))
            assertNull(impl.thumbnailOfUri("file:///storage/emulated/0/a.mp4", 96, 96))
            assertNull(impl.thumbnailOfUri("", 96, 96))
            assertEquals(1, FakeMediaProvider.opens.size)
        }

    @Test
    fun `thumbnailOfUri caps the size at 4096 and refuses 0 or less`() =
        timed {
            FakeMediaProvider.install(FileNotFoundException("gone"))
            assertNull(impl.thumbnailOfUri(videoUri(1), 10_000, 5_000))
            @Suppress("DEPRECATION")
            val size = FakeMediaProvider.opens.single().getParcelable<Point>(ContentResolver.EXTRA_SIZE)
            assertEquals(Point(4096, 4096), size)
            for ((w, h) in listOf(0L to 96L, 96L to 0L, -5L to 96L)) {
                try {
                    impl.thumbnailOfUri(videoUri(1), w, h)
                    fail("expected an error for $w x $h")
                } catch (e: FlutterError) {
                    assertEquals("native-error", e.code)
                }
            }
        }

    // ---- The photo picker ----

    private fun pickerImpl(
        extension: Int = 0,
        limit: Int = 100,
    ) = MediaHostApiImpl(activity, noVolumes, extensionLevelOf = { extension }, pickLimitOf = { limit })

    private fun pickedUri(id: Int) = Uri.parse("content://media/picker/0/com.android.providers.media.photopicker/media/$id")

    @Test
    fun `pickVideos starts the picker for its request code, and a result answers it`() =
        timed {
            impl = pickerImpl(extension = 2)
            FakeMediaProvider.install(answer = {
                MatrixCursor(arrayOf(MediaColumns.DISPLAY_NAME, MediaColumns.SIZE)).apply { addRow(arrayOf<Any?>("a.mp4", 77L)) }
            })
            val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            val started = shadowOf(activity).peekNextStartedActivityForResult()
            assertEquals(PickedVideos.REQUEST_CODE, started.requestCode)
            assertEquals(PickedVideos.intent(sdk, 2) { 100 }.action, started.intent.action)
            assertEquals("video/*", started.intent.type)
            assertFalse(pick.isCompleted)

            val result =
                Intent().apply {
                    clipData = android.content.ClipData.newRawUri("", pickedUri(1)).apply { addItem(android.content.ClipData.Item(pickedUri(2))) }
                }
            assertTrue(impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_OK, result))
            val picked = pick.await()
            assertEquals(listOf(pickedUri(1), pickedUri(2)).map { it.toString() }, picked.map { it.uri })
            assertTrue(picked.all { it.displayName == "a.mp4" && it.sizeBytes == 77L })
        }

    @Test
    fun `cancelling the picker gives an empty list`() =
        timed {
            impl = pickerImpl()
            val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            assertTrue(impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_CANCELED, null))
            assertEquals(emptyList<PickedVideoMsg>(), pick.await())
        }

    @Test
    fun `a second pickVideos while one is open fails with busy and leaves the first waiting`() =
        timed {
            impl = pickerImpl()
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            for (attempt in 1..2) {
                try {
                    impl.pickVideos()
                    fail("expected busy")
                } catch (e: FlutterError) {
                    assertEquals("busy", e.code)
                }
            }
            assertFalse(first.isCompleted)
            // Only the first picker was started.
            shadowOf(activity).nextStartedActivityForResult
            assertNull(shadowOf(activity).nextStartedActivityForResult)

            impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertEquals(emptyList<PickedVideoMsg>(), first.await())
            // Once answered, a new pick may start.
            val again = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertEquals(emptyList<PickedVideoMsg>(), again.await())
        }

    @Test
    fun `a picker result with no caller waiting is dropped silently`() =
        timed {
            impl = pickerImpl()
            // The process died while the picker was open; the new activity gets the result.
            assertFalse(impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_OK, Intent().setData(pickedUri(1))))
            // And another request code is not this bridge's.
            val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            assertFalse(impl.onActivityResult(PickedVideos.REQUEST_CODE + 1, Activity.RESULT_OK, Intent().setData(pickedUri(1))))
            assertFalse(pick.isCompleted)
            impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertEquals(emptyList<PickedVideoMsg>(), pick.await())
        }

    @Test
    fun `the host going away fails a waiting pick`() =
        timed {
            impl = pickerImpl()
            val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            impl.onHostGone()
            try {
                pick.await()
                fail("expected host-gone")
            } catch (e: FlutterError) {
                assertEquals("host-gone", e.code)
            }
            try {
                impl.pickVideos()
                fail("expected no-activity")
            } catch (e: FlutterError) {
                assertEquals("no-activity", e.code)
            }
        }

    @Test
    fun `a picker that cannot start fails without its message and frees the slot`() =
        timed {
            impl = pickerImpl()
            shadowOf(activity.application).checkActivities(true)
            repeat(2) {
                try {
                    impl.pickVideos()
                    fail("expected an error")
                } catch (e: FlutterError) {
                    assertEquals("no-picker", e.code)
                }
            }
        }

    @Test
    fun `facts of picked videos are read off the main thread`() =
        timed {
            impl = pickerImpl()
            val threads = mutableListOf<Boolean>()
            FakeMediaProvider.install(answer = {
                threads += Looper.myLooper() == Looper.getMainLooper()
                null
            })
            val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickVideos() }
            val uri = Uri.parse(videoUri(7))
            impl.onActivityResult(PickedVideos.REQUEST_CODE, Activity.RESULT_OK, Intent().setData(uri))
            assertEquals(listOf(videoUri(7)), pick.await().map { it.uri })
            assertTrue(threads.isNotEmpty() && threads.none { it })
        }
}
