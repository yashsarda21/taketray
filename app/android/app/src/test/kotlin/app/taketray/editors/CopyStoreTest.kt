package app.taketray.editors

import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import android.provider.MediaStore.MediaColumns
import androidx.test.core.app.ApplicationProvider
import java.io.FileNotFoundException
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowStatFs

/**
 * The MediaStore side of copying (D-122) over [FakeCopyProvider]: the
 * pending row in exactly `Movies/TakeTray/<folder>/` on the primary volume,
 * the original opened read-only on any volume, the name read back after
 * publishing, and deletes that only ever hit TakeTray's own rows in that
 * folder.
 */
@RunWith(RobolectricTestRunner::class)
class CopyStoreTest {
    private val app = ApplicationProvider.getApplicationContext<Context>()
    private val own = "app.taketray.dev"
    private lateinit var store: MediaStoreCopyStore

    @Before
    fun setUp() {
        FakeCopyProvider.install(own)
        store = MediaStoreCopyStore(app.contentResolver, own)
    }

    private val rows get() = FakeCopyProvider.rows
    private val events get() = FakeCopyProvider.events

    private fun detected(
        volume: String,
        id: Long,
    ) = CopySource(volume, id, null, "video/mp4")

    @Test
    fun `insertPending makes a pending row in exactly the folder on the primary volume`() {
        val id = store.insertPending("Goa 🌴", "2026-10-12_14-32-05.mp4")
        val row = rows[id]!!
        assertEquals(MediaStore.VOLUME_EXTERNAL_PRIMARY, row.volume)
        assertEquals("Movies/TakeTray/Goa 🌴/", row.path)
        assertEquals("2026-10-12_14-32-05.mp4", row.name)
        assertTrue(row.pending)
        assertEquals(own, row.owner)
        assertEquals(listOf("insert external_primary"), events)
    }

    @Test
    fun `an original on an SD card is read there and copied to the primary volume`() {
        val bytes = ByteArray(5000) { it.toByte() }
        val original = FakeCopyProvider.add("DCIM/Camera/", "VID_1.mp4", pending = false, owner = "com.camera", volume = "1a2b-3c4d", bytes = bytes)
        val source = store.openSource(detected("1a2b-3c4d", original.id))
        assertEquals(5000L, source.length)
        val read = source.use { it.input.readBytes() }
        assertTrue(read.contentEquals(bytes))
        assertTrue(events.contains("open content://media/1a2b-3c4d/video/media/${original.id} r"))

        val id = store.insertPending("Goa", "a.mp4")
        store.openTarget(id).use { it.write(read) }
        assertEquals(MediaStore.VOLUME_EXTERNAL_PRIMARY, rows[id]!!.volume)
        assertTrue(rows[id]!!.file.readBytes().contentEquals(bytes))
        assertTrue(events.contains("open content://media/external_primary/video/media/$id w"))
        // The original is untouched.
        assertTrue(original.file.readBytes().contentEquals(bytes))
        assertFalse(original.pending)
    }

    @Test
    fun `a picked clip is read through its picker address`() {
        val picked = FakeCopyProvider.add("", "p.mp4", pending = false, owner = null, volume = "picker", bytes = ByteArray(10))
        val uri = "content://media/picker/0/com.android.providers.media.photopicker/media/${picked.id}"
        val source = store.openSource(CopySource(null, null, uri, "video/mp4"))
        source.close()
        assertTrue(events.contains("open $uri r"))
    }

    @Test
    fun `a source with no identity or a non-content address is refused, a missing one throws`() {
        for (bad in listOf(
            CopySource(null, null, null, "video/mp4"),
            CopySource("external_primary", null, null, "video/mp4"),
            CopySource(null, 5, null, "video/mp4"),
            CopySource(null, null, "file:///sdcard/DCIM/a.mp4", "video/mp4"),
        )) {
            try {
                store.openSource(bad)
                fail("expected a refusal")
            } catch (e: IllegalArgumentException) {
                // expected
            }
        }
        try {
            store.openSource(detected("external_primary", 999))
            fail("expected a failure")
        } catch (e: FileNotFoundException) {
            // expected
        }
        assertTrue(events.none { it.startsWith("open file") })
    }

    @Test
    fun `publish clears IS_PENDING and reads back the name MediaStore gave`() {
        val id = store.insertPending("Goa", "x.mp4")
        FakeCopyProvider.renameOnPublish = "x (1).mp4"
        assertEquals(Published(id, "x (1).mp4"), store.publish(id))
        assertFalse(rows[id]!!.pending)
    }

    @Test
    fun `publish fails when the row was not updated or is gone`() {
        val id = store.insertPending("Goa", "x.mp4")
        FakeCopyProvider.updateReturnsZero = true
        try {
            store.publish(id)
            fail("expected a failure")
        } catch (e: IOException) {
            // expected
        }
        FakeCopyProvider.updateReturnsZero = false
        rows.remove(id)
        try {
            store.publish(id)
            fail("expected a failure")
        } catch (e: IOException) {
            // expected
        }
    }

    @Test
    fun `deleteOwn deletes only TakeTray's own row in exactly the folder with that name`() {
        val mine = FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = false)
        val pendingMine = FakeCopyProvider.add("movies/taketray/goa/", "b.mp4", pending = true)
        val other = FakeCopyProvider.add("Movies/TakeTray/Goa/", "c.mp4", pending = false, owner = "com.other")
        val test = FakeCopyProvider.add("Movies/TakeTray Test/", "d.mp4", pending = false)
        val deeper = FakeCopyProvider.add("Movies/TakeTray/Goa/sub/", "e.mp4", pending = false)
        val goa2 = FakeCopyProvider.add("Movies/TakeTray/Goa2/", "f.mp4", pending = false)
        val camera = FakeCopyProvider.add("DCIM/Camera/", "a.mp4", pending = false)

        // Refused: someone else's, another folder, another name.
        assertFalse(store.deleteOwn(other.id, "Goa", "c.mp4"))
        assertFalse(store.deleteOwn(test.id, "Goa", "d.mp4"))
        assertFalse(store.deleteOwn(deeper.id, "Goa", "e.mp4"))
        assertFalse(store.deleteOwn(goa2.id, "Goa", "f.mp4"))
        assertFalse(store.deleteOwn(camera.id, "Goa", "a.mp4"))
        assertFalse(store.deleteOwn(mine.id, "Goa", "other.mp4"))
        assertEquals(7, rows.size)

        assertTrue(store.deleteOwn(mine.id, "Goa", "a.mp4"))
        // A pending row of ours, with any name (MediaStore may have renamed it).
        assertTrue(store.deleteOwn(pendingMine.id, "Goa", null))
        assertNull(rows[mine.id])
        assertNull(rows[pendingMine.id])
        assertEquals(setOf(other.id, test.id, deeper.id, goa2.id, camera.id), rows.keys)
        // The row lookup and the delete both see pending rows.
        assertTrue(events.filter { it.startsWith("query") || it.startsWith("delete") }.all { it.endsWith("true") })
    }

    @Test
    fun `deleteOwn of a row that is already gone is true, a delete that removes nothing is false`() {
        assertTrue(store.deleteOwn(12345, "Goa", "a.mp4"))
        val mine = FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = false)
        FakeCopyProvider.deleteError = SecurityException("no")
        try {
            store.deleteOwn(mine.id, "Goa", "a.mp4")
            fail("expected the failure to pass")
        } catch (e: SecurityException) {
            // expected
        }
        assertNotNull(rows[mine.id])
    }

    @Test
    fun `ownRowsIn lists only TakeTray's own rows in exactly the folder, pending ones included`() {
        val a = FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = false, bytes = ByteArray(7))
        val b = FakeCopyProvider.add("movies/taketray/GOA/", "b.mp4", pending = true)
        FakeCopyProvider.add("Movies/TakeTray/Goa/", "c.mp4", pending = false, owner = "com.other")
        FakeCopyProvider.add("Movies/TakeTray/Goa/", "n.mp4", pending = false, owner = null)
        FakeCopyProvider.add("Movies/TakeTray Test/", "d.mp4", pending = false)
        FakeCopyProvider.add("Movies/TakeTray/Goa/sub/", "e.mp4", pending = false)
        FakeCopyProvider.add("Movies/TakeTray/Goa2/", "f.mp4", pending = false)
        // The same folder on another volume is not a copy folder.
        FakeCopyProvider.add("Movies/TakeTray/Goa/", "g.mp4", pending = false, volume = "1a2b-3c4d")

        assertEquals(
            listOf(FolderRow(a.id, "a.mp4", 7, false), FolderRow(b.id, "b.mp4", 0, true)),
            store.ownRowsIn("Goa"),
        )
        assertEquals(listOf("query ${MediaColumns.RELATIVE_PATH} = ? COLLATE NOCASE true"), events)
    }

    @Test
    fun `ownRowsIn and deletePendingIn check folder and owner themselves even when the provider returns more`() {
        // A provider whose folder query returns every row: the store's own checks still apply.
        FakeCopyProvider.queryIgnoresFolder = true
        val a = FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = true)
        val test = FakeCopyProvider.add("Movies/TakeTray Test/", "d.mp4", pending = true)
        val deeper = FakeCopyProvider.add("Movies/TakeTray/Goa/sub/", "e.mp4", pending = true)
        val other = FakeCopyProvider.add("Movies/TakeTray/Goa/", "c.mp4", pending = true, owner = "com.other")
        val camera = FakeCopyProvider.add("DCIM/Camera/", "v.mp4", pending = true, owner = null)
        assertEquals(listOf(a.id), store.ownRowsIn("Goa").map { it.mediaStoreId })
        assertEquals(1, store.deletePendingIn("Goa"))
        assertEquals(setOf(test.id, deeper.id, other.id, camera.id), rows.keys)
    }

    @Test
    fun `a null size is 0 and a failed query throws`() {
        FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = false)
        FakeCopyProvider.sizeNull = true
        assertEquals(0L, store.ownRowsIn("Goa").single().sizeBytes)
        FakeCopyProvider.queryReturnsNull = true
        try {
            store.ownRowsIn("Goa")
            fail("expected a failure")
        } catch (e: IOException) {
            // expected
        }
    }

    @Test
    fun `deletePendingIn deletes only TakeTray's own pending rows in exactly the folder`() {
        // What a process that died mid-copy leaves: a pending row next to finished copies.
        val left = FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = true)
        val left2 = FakeCopyProvider.add("movies/taketray/goa/", "b.mp4", pending = true)
        val finished = FakeCopyProvider.add("Movies/TakeTray/Goa/", "c.mp4", pending = false)
        val otherFolder = FakeCopyProvider.add("Movies/TakeTray/Paris/", "d.mp4", pending = true)
        val test = FakeCopyProvider.add("Movies/TakeTray Test/", "e.mp4", pending = true)
        val deeper = FakeCopyProvider.add("Movies/TakeTray/Goa/sub/", "f.mp4", pending = true)
        val otherOwner = FakeCopyProvider.add("Movies/TakeTray/Goa/", "g.mp4", pending = true, owner = "com.other")

        assertEquals(2, store.deletePendingIn("Goa"))
        assertNull(rows[left.id])
        assertNull(rows[left2.id])
        assertEquals(setOf(finished.id, otherFolder.id, test.id, deeper.id, otherOwner.id), rows.keys)
        // Each delete itself only matches a pending row.
        val deletes = events.filter { it.startsWith("delete") }
        assertEquals(2, deletes.size)
        assertTrue(deletes.all { it.endsWith("${MediaColumns.IS_PENDING} = 1 true") })
    }

    @Test
    fun `a row published between the listing and its delete stays`() {
        val row = FakeCopyProvider.add("Movies/TakeTray/Goa/", "a.mp4", pending = true)
        // Published after deletePendingIn listed it and before its delete arrives.
        FakeCopyProvider.beforeDelete = { row.values.put(MediaColumns.IS_PENDING, 0) }
        assertEquals(0, store.deletePendingIn("Goa"))
        assertNotNull(rows[row.id])
    }

    @Test
    fun `availableBytes reads the primary volume`() {
        val primary = Environment.getExternalStorageDirectory()
        ShadowStatFs.registerStats(primary, 1000, 300, 200)
        val real = MediaStoreCopyStore(app.contentResolver, own)
        assertEquals(200L * ShadowStatFs.BLOCK_SIZE, real.availableBytes())
        assertEquals(42L, MediaStoreCopyStore(app.contentResolver, own) { 42L }.availableBytes())
    }
}
