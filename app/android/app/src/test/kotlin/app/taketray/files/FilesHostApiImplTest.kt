package app.taketray.files

import android.app.Activity
import android.content.ComponentName
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Looper
import androidx.core.content.FileProvider
import app.taketray.share.ShareActivity
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.nio.file.Files
import java.util.function.Supplier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The files bridge (D-147) on a Robolectric activity: the share sheet through
 * the app's FileProvider (and only for files in `cache/shared/`), the document
 * picker to save and to open, the folder picker read as a MediaStore relative
 * path with no grant kept, one picker at a time, results nobody waits for,
 * and errors that never carry a path or an address.
 */
@RunWith(RobolectricTestRunner::class)
class FilesHostApiImplTest {
    private lateinit var activity: Activity
    private lateinit var impl: FilesHostApiImpl
    private lateinit var resolver: ContentResolver
    private lateinit var shared: File

    private val document = Uri.parse("content://test.documents/document/7")

    @Before
    fun setUp() {
        // FileProvider keeps each authority's folders for the life of the
        // process; Robolectric gives every test a new cache folder.
        (FileProvider::class.java.getDeclaredField("sCache").apply { isAccessible = true }.get(null) as MutableMap<*, *>).clear()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        resolver = activity.contentResolver
        shared = File(activity.cacheDir, "shared").apply { mkdirs() }
        impl = FilesHostApiImpl(activity)
    }

    /** Runs a test body with a time limit; a failing child is reported by its await. */
    private fun timed(body: suspend CoroutineScope.() -> Unit) = runBlocking { withTimeout(5_000) { supervisorScope { body() } } }

    private suspend fun errorOf(call: suspend () -> Any?): FilesError? =
        try {
            call()
            null
        } catch (e: FilesError) {
            e
        }

    private fun onMain() = Looper.getMainLooper().isCurrentThread

    private fun ok(uri: Uri?) = Intent().apply { data = uri }

    private fun sharedFile(
        name: String,
        text: String = "log",
    ): File = File(shared, name).apply { writeText(text) }

    // ---- shareFile ----

    @Test
    fun `shareFile opens the chooser around ACTION_SEND with the FileProvider address, a read grant, the subject and the text`() =
        timed {
            val file = sharedFile("taketray-log-2026-11-17-0930.txt", "line one\nline two\n")
            impl.shareFile(file.path, "text/plain", "TakeTray error log", "TakeTray 1.0.0 on Android 15")

            val chooser = shadowOf(activity).nextStartedActivity
            assertNotNull("nothing was started", chooser)
            assertEquals(Intent.ACTION_CHOOSER, chooser.action)
            @Suppress("DEPRECATION")
            val send = chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
            assertEquals(Intent.ACTION_SEND, send.action)
            assertEquals("text/plain", send.type)
            @Suppress("DEPRECATION")
            val stream = send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
            assertEquals(Uri.parse("content://${activity.packageName}.files/shared/taketray-log-2026-11-17-0930.txt"), stream)
            assertEquals("TakeTray error log", send.getStringExtra(Intent.EXTRA_SUBJECT))
            assertEquals("TakeTray 1.0.0 on Android 15", send.getStringExtra(Intent.EXTRA_TEXT))
            // Read only, never write, and the grant rides on the clip so the chooser passes it on.
            assertTrue(send.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            assertEquals(0, send.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            assertEquals(stream, send.clipData!!.getItemAt(0).uri)
            assertTrue(chooser.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            assertEquals(0, chooser.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            // The address really reaches the file through the app's own provider.
            assertEquals("line one\nline two\n", resolver.openInputStream(stream)!!.use { String(it.readBytes(), Charsets.UTF_8) })
        }

    @Test
    fun `shareFile keeps TakeTray's own share screen out of the chooser`() =
        timed {
            val file = sharedFile("taketray-log-2026-11-17-0930.txt", "line one\n")
            impl.shareFile(file.path, "text/plain", "TakeTray error log", "TakeTray 1.0.0 on Android 15")

            val chooser = shadowOf(activity).nextStartedActivity
            @Suppress("DEPRECATION")
            val excluded = chooser.getParcelableArrayExtra(Intent.EXTRA_EXCLUDE_COMPONENTS)
            assertNotNull("no component is excluded", excluded)
            assertEquals(
                listOf(ComponentName(activity, ShareActivity::class.java)),
                excluded!!.toList(),
            )
        }

    @Test
    fun `shareFile shares a file in a folder under cache shared`() =
        timed {
            val file = File(shared, "sub/a.txt").apply { parentFile!!.mkdirs() }
            file.writeText("x")
            impl.shareFile(file.path, "text/plain", "s", "t")
            @Suppress("DEPRECATION")
            val send = shadowOf(activity).nextStartedActivity.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
            @Suppress("DEPRECATION")
            assertEquals(Uri.parse("content://${activity.packageName}.files/shared/sub/a.txt"), send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        }

    @Test
    fun `shareFile refuses every path that is not a file in cache shared, and opens nothing`() =
        timed {
            sharedFile("a.txt")
            File(activity.cacheDir, "other.txt").writeText("x")
            File(activity.cacheDir, "sharedx").mkdirs()
            File(activity.cacheDir, "sharedx/a.txt").writeText("x")
            File(activity.filesDir, "shared").mkdirs()
            File(activity.filesDir, "shared/a.txt").writeText("x")
            val refused =
                listOf(
                    File(activity.cacheDir, "other.txt").path,
                    // A sibling whose name starts with "shared".
                    File(activity.cacheDir, "sharedx/a.txt").path,
                    // Out of the folder through "..", though the file exists.
                    "${shared.path}/../other.txt",
                    // The same name in another of the app's folders.
                    File(activity.filesDir, "shared/a.txt").path,
                    // The folder itself, and a file that is not there.
                    shared.path,
                    File(shared, "missing.txt").path,
                    // Not absolute.
                    "shared/a.txt",
                    "",
                )
            for (path in refused) {
                assertEquals(path, "invalid_path", errorOf { impl.shareFile(path, "text/plain", "s", "t") }?.code)
            }
            assertNull(shadowOf(activity).nextStartedActivity)
        }

    @Test
    fun `shareFile refuses a link inside cache shared that points at a file outside it`() =
        timed {
            val outside = File(activity.cacheDir, "other.txt").apply { writeText("x") }
            val link = File(shared, "link.txt")
            Files.createSymbolicLink(link.toPath(), outside.toPath())
            assertTrue("the link was not made", Files.isSymbolicLink(link.toPath()))

            assertEquals("invalid_path", errorOf { impl.shareFile(link.path, "text/plain", "s", "t") }?.code)
            assertNull(shadowOf(activity).nextStartedActivity)
        }

    @Test
    fun `shareFile refuses a file reached through a linked folder that leads out of cache shared`() =
        timed {
            File(activity.cacheDir, "other.txt").writeText("x")
            val dir = File(shared, "dir")
            Files.createSymbolicLink(dir.toPath(), activity.cacheDir.toPath())
            assertTrue("the link was not made", Files.isSymbolicLink(dir.toPath()))

            assertEquals("invalid_path", errorOf { impl.shareFile("${dir.path}/other.txt", "text/plain", "s", "t") }?.code)
            assertNull(shadowOf(activity).nextStartedActivity)
        }

    @Test
    fun `shareFile answers invalid_path, not a failure, for a path the file system cannot resolve`() =
        timed {
            // A NUL makes File.getCanonicalFile throw IOException("Invalid file path").
            val error = errorOf { impl.shareFile("${shared.path}/a\u0000b.txt", "text/plain", "s", "t") }!!

            assertEquals("invalid_path", error.code)
            assertFalse(error.message.orEmpty().contains("b.txt"))
            assertNull(shadowOf(activity).nextStartedActivity)
        }

    @Test
    fun `shareFile errors never carry the path`() =
        timed {
            val error = errorOf { impl.shareFile("/secret/folder/name.txt", "text/plain", "s", "t") }!!
            assertEquals("invalid_path", error.code)
            assertFalse(error.message.orEmpty().contains("secret"))
            assertFalse(error.details.toString().contains("secret"))
        }

    // ---- saveDocument ----

    @Test
    fun `saveDocument asks to create a document with the name and type, then writes the exact UTF-8 bytes`() =
        timed {
            val written = ByteArrayOutputStream()
            shadowOf(resolver).registerOutputStream(document, written)
            val text = "{\"name\":\"Café ✓ 日本\"}\n"

            val save = async(start = CoroutineStart.UNDISPATCHED) { impl.saveDocument("taketray-backup-2026-11-17.json", "application/json", text) }
            val started = shadowOf(activity).peekNextStartedActivityForResult()
            assertEquals(FilesHostApiImpl.SAVE_REQUEST_CODE, started.requestCode)
            assertEquals(4101, started.requestCode)
            assertEquals(Intent.ACTION_CREATE_DOCUMENT, started.intent.action)
            assertTrue(started.intent.hasCategory(Intent.CATEGORY_OPENABLE))
            assertEquals("application/json", started.intent.type)
            assertEquals("taketray-backup-2026-11-17.json", started.intent.getStringExtra(Intent.EXTRA_TITLE))
            assertEquals(0, started.intent.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            assertFalse(save.isCompleted)

            assertTrue(impl.onActivityResult(FilesHostApiImpl.SAVE_REQUEST_CODE, Activity.RESULT_OK, ok(document)))
            assertEquals(document.toString(), save.await())
            assertArrayEquals(text.toByteArray(Charsets.UTF_8), written.toByteArray())
            assertTrue(resolver.persistedUriPermissions.isEmpty())
        }

    @Test
    fun `saveDocument cancelled answers null and writes nothing`() =
        timed {
            val written = ByteArrayOutputStream()
            shadowOf(resolver).registerOutputStream(document, written)
            // Cancelled, and an OK that carries no address (some pickers do that).
            for (result in listOf(Activity.RESULT_CANCELED to ok(document), Activity.RESULT_CANCELED to null, Activity.RESULT_OK to null, Activity.RESULT_OK to ok(null))) {
                val save = async(start = CoroutineStart.UNDISPATCHED) { impl.saveDocument("a.json", "application/json", "{}") }
                assertTrue(impl.onActivityResult(FilesHostApiImpl.SAVE_REQUEST_CODE, result.first, result.second))
                assertNull(save.await())
            }
            assertEquals(0, written.size())
        }

    @Test
    fun `saveDocument writes off the main thread`() =
        timed {
            val threads = mutableListOf<Boolean>()
            shadowOf(resolver).registerOutputStream(
                document,
                object : OutputStream() {
                    override fun write(b: Int) {
                        threads += onMain()
                    }

                    override fun write(
                        b: ByteArray,
                        off: Int,
                        len: Int,
                    ) {
                        threads += onMain()
                    }
                },
            )
            val save = async(start = CoroutineStart.UNDISPATCHED) { impl.saveDocument("a.json", "application/json", "{}") }
            impl.onActivityResult(FilesHostApiImpl.SAVE_REQUEST_CODE, Activity.RESULT_OK, ok(document))
            assertEquals(document.toString(), save.await())
            assertTrue(threads.isNotEmpty() && threads.none { it })
        }

    @Test
    fun `saveDocument that cannot write fails without the message`() =
        timed {
            shadowOf(resolver).registerOutputStream(
                document,
                object : OutputStream() {
                    override fun write(b: Int) = throw IOException("/storage/emulated/0/secret.json")

                    override fun write(
                        b: ByteArray,
                        off: Int,
                        len: Int,
                    ) = throw IOException("/storage/emulated/0/secret.json")
                },
            )
            val save = async(start = CoroutineStart.UNDISPATCHED) { errorOf { impl.saveDocument("a.json", "application/json", "{}") } }
            impl.onActivityResult(FilesHostApiImpl.SAVE_REQUEST_CODE, Activity.RESULT_OK, ok(document))
            val error = save.await()!!
            assertEquals("native-error", error.code)
            assertFalse(error.message.orEmpty().contains("secret"))
            assertFalse(error.details.toString().contains("secret"))
        }

    // ---- openDocument ----

    private fun registerText(bytes: ByteArray) =
        shadowOf(resolver).registerInputStreamSupplier(document, Supplier<InputStream> { ByteArrayInputStream(bytes) })

    private suspend fun CoroutineScope.open(
        maxBytes: Long,
        mimeTypes: List<String> = listOf("application/json", "text/plain", "*/*"),
    ): Pair<String?, FilesError?> {
        val open = async(start = CoroutineStart.UNDISPATCHED) { runCatching { impl.openDocument(mimeTypes, maxBytes) } }
        assertTrue(impl.onActivityResult(FilesHostApiImpl.OPEN_REQUEST_CODE, Activity.RESULT_OK, ok(document)))
        val result = open.await()
        return result.getOrNull() to (result.exceptionOrNull() as FilesError?)
    }

    @Test
    fun `openDocument asks for one openable document of the types and reads it as UTF-8`() =
        timed {
            val text = "{\"reel\":\"Goa ✓ 日本\"}"
            registerText(text.toByteArray(Charsets.UTF_8))
            val open = async(start = CoroutineStart.UNDISPATCHED) { impl.openDocument(listOf("application/json", "text/plain", "*/*"), 1_000) }
            val started = shadowOf(activity).peekNextStartedActivityForResult()
            assertEquals(FilesHostApiImpl.OPEN_REQUEST_CODE, started.requestCode)
            assertEquals(4102, started.requestCode)
            assertEquals(Intent.ACTION_OPEN_DOCUMENT, started.intent.action)
            assertTrue(started.intent.hasCategory(Intent.CATEGORY_OPENABLE))
            assertEquals("*/*", started.intent.type)
            assertArrayEquals(arrayOf("application/json", "text/plain", "*/*"), started.intent.getStringArrayExtra(Intent.EXTRA_MIME_TYPES))
            assertFalse(started.intent.getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, false))
            assertEquals(0, started.intent.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)

            impl.onActivityResult(FilesHostApiImpl.OPEN_REQUEST_CODE, Activity.RESULT_OK, ok(document))
            assertEquals(text, open.await())
            assertTrue(resolver.persistedUriPermissions.isEmpty())
        }

    @Test
    fun `openDocument allows exactly maxBytes and refuses one byte more with too_large`() =
        timed {
            // Multi-byte characters: the limit counts bytes, not characters.
            val bytes = "é".repeat(50).toByteArray(Charsets.UTF_8)
            assertEquals(100, bytes.size)
            registerText(bytes)
            assertEquals("é".repeat(50) to null, open(maxBytes = 100))
            assertEquals("é".repeat(50) to null, open(maxBytes = 101))
            val (text, error) = open(maxBytes = 99)
            assertNull(text)
            assertEquals("too_large", error?.code)
        }

    @Test
    fun `openDocument refuses a document far over the limit without reading it all`() =
        timed {
            var read = 0L
            shadowOf(resolver).registerInputStreamSupplier(
                document,
                Supplier<InputStream> {
                    // An endless document: only a bounded read can end.
                    object : InputStream() {
                        override fun read(): Int {
                            read++
                            return 'a'.code
                        }
                    }
                },
            )
            val (_, error) = open(maxBytes = 1_000)
            assertEquals("too_large", error?.code)
            assertTrue("read $read bytes", read <= 1_000 + 64 * 1024)
        }

    @Test
    fun `openDocument reads an empty document as empty text`() =
        timed {
            registerText(ByteArray(0))
            assertEquals("" to null, open(maxBytes = 0))
        }

    @Test
    fun `openDocument cancelled answers null and reads nothing`() =
        timed {
            var opened = 0
            shadowOf(resolver).registerInputStreamSupplier(
                document,
                Supplier<InputStream> {
                    opened++
                    ByteArrayInputStream(ByteArray(1))
                },
            )
            for (result in listOf(Activity.RESULT_CANCELED to ok(document), Activity.RESULT_CANCELED to null, Activity.RESULT_OK to null, Activity.RESULT_OK to ok(null))) {
                val open = async(start = CoroutineStart.UNDISPATCHED) { impl.openDocument(listOf("application/json"), 10) }
                assertTrue(impl.onActivityResult(FilesHostApiImpl.OPEN_REQUEST_CODE, result.first, result.second))
                assertNull(open.await())
            }
            assertEquals(0, opened)
        }

    @Test
    fun `openDocument that cannot read fails without the message, off the main thread`() =
        timed {
            val threads = mutableListOf<Boolean>()
            shadowOf(resolver).registerInputStreamSupplier(
                document,
                Supplier<InputStream> {
                    threads += onMain()
                    throw FileNotFoundException("/storage/emulated/0/secret.json")
                },
            )
            val (_, error) = open(maxBytes = 10)
            assertEquals("native-error", error?.code)
            assertFalse(error?.message.orEmpty().contains("secret"))
            assertFalse(error?.details.toString().contains("secret"))
            assertTrue(threads.isNotEmpty() && threads.none { it })
        }

    // ---- pickFolder ----

    private suspend fun CoroutineScope.pickWith(tree: Uri): Pair<String?, FilesError?> {
        val pick = async(start = CoroutineStart.UNDISPATCHED) { runCatching { impl.pickFolder() } }
        assertTrue(impl.onActivityResult(FilesHostApiImpl.FOLDER_REQUEST_CODE, Activity.RESULT_OK, ok(tree)))
        val result = pick.await()
        return result.getOrNull() to (result.exceptionOrNull() as FilesError?)
    }

    @Test
    fun `pickFolder opens the folder picker asking for no grant`() =
        timed {
            val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickFolder() }
            val started = shadowOf(activity).peekNextStartedActivityForResult()
            assertEquals(FilesHostApiImpl.FOLDER_REQUEST_CODE, started.requestCode)
            assertEquals(4103, started.requestCode)
            assertEquals(Intent.ACTION_OPEN_DOCUMENT_TREE, started.intent.action)
            val grants =
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            assertEquals(0, started.intent.flags and grants)
            impl.onActivityResult(FilesHostApiImpl.FOLDER_REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertNull(pick.await())
        }

    @Test
    fun `pickFolder maps a tree on the phone or an SD card to its relative path`() =
        timed {
            val tree = "content://com.android.externalstorage.documents/tree/"
            val cases =
                mapOf(
                    "primary%3ADCIM%2FCamera" to "DCIM/Camera",
                    "primary%3A" to "",
                    "1A2B-3C4D%3AMovies%2FTrips" to "Movies/Trips",
                    "1a2b-3c4d%3ADCIM" to "DCIM",
                    "1A2B-3C4D%3A" to "",
                    "primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2FWhatsApp%20Video" to
                        "Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video",
                    // A trailing slash is dropped.
                    "primary%3ADCIM%2FCamera%2F" to "DCIM/Camera",
                )
            for ((id, path) in cases) {
                assertEquals(id, path to null, pickWith(Uri.parse(tree + id)))
            }
            // The folder picker's temporary grant is never kept.
            assertTrue(resolver.persistedUriPermissions.isEmpty())
        }

    @Test
    fun `pickFolder refuses a tree that is not a folder on the phone or an SD card with unsupported_folder`() =
        timed {
            val refused =
                listOf(
                    "content://com.android.providers.downloads.documents/tree/downloads",
                    "content://com.android.providers.downloads.documents/tree/raw%3A%2Fstorage%2Femulated%2F0%2FDownload",
                    "content://com.android.providers.media.documents/tree/video_root",
                    "content://com.google.android.apps.docs.storage/tree/acc%3D1%3Bdoc%3Dencoded%3Dabc",
                    // The external storage provider's Documents root and an unknown root.
                    "content://com.android.externalstorage.documents/tree/home%3A",
                    "content://com.android.externalstorage.documents/tree/usb%3ADCIM",
                    // No volume, and no ":" at all.
                    "content://com.android.externalstorage.documents/tree/%3ADCIM",
                    "content://com.android.externalstorage.documents/tree/primary",
                    // A document address, not a tree.
                    "content://com.android.externalstorage.documents/document/primary%3ADCIM",
                    "file:///storage/emulated/0/DCIM",
                )
            for (uri in refused) {
                val (path, error) = pickWith(Uri.parse(uri))
                assertNull(uri, path)
                assertEquals(uri, "unsupported_folder", error?.code)
                assertFalse(uri, error?.message.orEmpty().contains("DCIM") || error?.message.orEmpty().contains("storage"))
            }
            assertTrue(resolver.persistedUriPermissions.isEmpty())
        }

    @Test
    fun `pickFolder cancelled answers null`() =
        timed {
            for (result in listOf(Activity.RESULT_CANCELED to null, Activity.RESULT_OK to null, Activity.RESULT_OK to ok(null))) {
                val pick = async(start = CoroutineStart.UNDISPATCHED) { impl.pickFolder() }
                assertTrue(impl.onActivityResult(FilesHostApiImpl.FOLDER_REQUEST_CODE, result.first, result.second))
                assertNull(pick.await())
            }
        }

    // ---- One picker at a time, results nobody waits for, the host going away ----

    @Test
    fun `a second picker call while one waits fails with busy and leaves the first waiting`() =
        timed {
            val first = async(start = CoroutineStart.UNDISPATCHED) { impl.saveDocument("a.json", "application/json", "{}") }
            assertEquals("busy", errorOf { impl.saveDocument("b.json", "application/json", "{}") }?.code)
            assertEquals("busy", errorOf { impl.openDocument(listOf("application/json"), 10) }?.code)
            assertEquals("busy", errorOf { impl.pickFolder() }?.code)
            assertFalse(first.isCompleted)
            // Only the first picker was started.
            shadowOf(activity).nextStartedActivityForResult
            assertNull(shadowOf(activity).nextStartedActivityForResult)

            impl.onActivityResult(FilesHostApiImpl.SAVE_REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertNull(first.await())
            // Once answered, a new picker may open.
            val again = async(start = CoroutineStart.UNDISPATCHED) { impl.pickFolder() }
            assertTrue(impl.onActivityResult(FilesHostApiImpl.FOLDER_REQUEST_CODE, Activity.RESULT_CANCELED, null))
            assertNull(again.await())
        }

    @Test
    fun `a result nobody waits for is dropped, and another request code is not this bridge's`() =
        timed {
            // The process died while a picker was open; the new activity gets the result.
            for (code in listOf(FilesHostApiImpl.SAVE_REQUEST_CODE, FilesHostApiImpl.OPEN_REQUEST_CODE, FilesHostApiImpl.FOLDER_REQUEST_CODE)) {
                assertFalse(impl.onActivityResult(code, Activity.RESULT_OK, ok(document)))
            }
            val save = async(start = CoroutineStart.UNDISPATCHED) { impl.saveDocument("a.json", "application/json", "{}") }
            // Another bridge's code, and another files picker's code, do not answer the waiting save.
            assertFalse(impl.onActivityResult(0x7A73, Activity.RESULT_OK, ok(document)))
            assertFalse(impl.onActivityResult(FilesHostApiImpl.OPEN_REQUEST_CODE, Activity.RESULT_OK, ok(document)))
            assertFalse(save.isCompleted)
            impl.onActivityResult(FilesHostApiImpl.SAVE_REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertNull(save.await())
        }

    @Test
    fun `the host going away fails a waiting picker, and later calls need the activity`() =
        timed {
            val pick = async(start = CoroutineStart.UNDISPATCHED) { errorOf { impl.pickFolder() } }
            impl.onHostGone()
            assertEquals("host-gone", pick.await()?.code)
            assertEquals("no-activity", errorOf { impl.pickFolder() }?.code)
            assertEquals("no-activity", errorOf { impl.saveDocument("a.json", "application/json", "{}") }?.code)
            assertEquals("no-activity", errorOf { impl.openDocument(listOf("application/json"), 10) }?.code)
            val file = sharedFile("a.txt")
            assertEquals("no-activity", errorOf { impl.shareFile(file.path, "text/plain", "s", "t") }?.code)
        }

    @Test
    fun `a picker that cannot start fails and frees the slot`() =
        timed {
            shadowOf(activity.application).checkActivities(true)
            repeat(2) {
                assertEquals("native-error", errorOf { impl.pickFolder() }?.code)
                assertEquals("native-error", errorOf { impl.saveDocument("a.json", "application/json", "{}") }?.code)
                assertEquals("native-error", errorOf { impl.openDocument(listOf("application/json"), 10) }?.code)
            }
        }

    // ---- appInfo ----

    @Test
    fun `appInfo answers the package's version name and the Android release`() =
        timed {
            val info = shadowOf(activity.packageManager).getInternalMutablePackageInfo(activity.packageName)
            info.versionName = "9.8.7"
            assertEquals(AppInfoMsg("9.8.7", Build.VERSION.RELEASE), impl.appInfo())
            // A package with no version name says so with an empty one, never a failure.
            info.versionName = null
            assertEquals(AppInfoMsg("", Build.VERSION.RELEASE), impl.appInfo())
        }
}
