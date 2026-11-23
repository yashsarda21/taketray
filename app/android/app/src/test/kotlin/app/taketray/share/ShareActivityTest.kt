package app.taketray.share

import android.app.Application
import android.content.Intent
import android.content.res.Resources
import android.graphics.Color
import android.util.TypedValue
import androidx.test.core.app.ApplicationProvider
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.plugin.common.BinaryMessenger
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Remembers which channels have a handler. */
private class RecordingMessenger : BinaryMessenger {
    val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler?>()

    override fun send(
        channel: String,
        message: ByteBuffer?,
    ) {}

    override fun send(
        channel: String,
        message: ByteBuffer?,
        callback: BinaryMessenger.BinaryReply?,
    ) {}

    override fun setMessageHandler(
        channel: String,
        handler: BinaryMessenger.BinaryMessageHandler?,
    ) {
        handlers[channel] = handler
    }

    /** The APIs with a handler, by their Pigeon name (`ShareHostApi`, ...). */
    fun liveApis(): Set<String> = handlers.filterValues { it != null }.keys.map(::apiOf).toSet()

    fun allApis(): Set<String> = handlers.keys.map(::apiOf).toSet()

    private fun apiOf(channel: String): String = channel.removePrefix("dev.flutter.pigeon.taketray.").substringBefore('.')
}

/**
 * The share screen (D-163): its own Dart entry point on a see-through
 * window; what an intent from another app can and cannot change; a second
 * share replacing the first; the three bridges it registers; its theme,
 * with no splash.
 *
 * The activity is built but never created: creating a FlutterActivity starts
 * a Flutter engine, which needs the native library a JVM test does not have.
 * The methods checked here read only the intent and the manifest.
 */
@RunWith(RobolectricTestRunner::class)
class ShareActivityTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()

    private fun share(text: String): Intent =
        Intent(Intent.ACTION_SEND)
            .setClassName(app, ShareActivity::class.java.name)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, text)

    private fun activityWith(intent: Intent): ShareActivity = Robolectric.buildActivity(ShareActivity::class.java, intent).get()

    /** A share with every extra FlutterActivity would otherwise read from its intent. */
    private fun hostile(): Intent =
        share("x")
            .putExtra("route", "/settings")
            .putExtra("background_mode", "opaque")
            .putExtra("cached_engine_id", "someone-elses-engine")
            .putExtra("cached_engine_group_id", "someone-elses-group")
            .putExtra("destroy_engine_with_activity", false)
            .putExtra("dart_entrypoint_args", arrayListOf("--evil"))
            .putExtra("dart_entrypoint", "main")
            .putExtra("enable_state_restoration", false)
            .putExtra("trace-startup", true)
            .putExtra("start-paused", true)
            .putExtra("enable-dart-profiling", true)
            .putExtra("verbose-logging", true)
            .putExtra("dart-flags", "--observe")
            .setData(android.net.Uri.parse("https://x.com/deep/link"))

    // ------------------------------------------------------------ the engine

    @Test
    fun `it runs shareMain from share_main dart`() {
        val activity = activityWith(share("x"))
        assertEquals("shareMain", activity.dartEntrypointFunctionName)
        assertEquals("package:taketray/share_main.dart", activity.dartEntrypointLibraryUri)
    }

    @Test
    fun `its Flutter view is see-through`() {
        assertEquals(BackgroundMode.transparent, activityWith(share("x")).backgroundMode)
    }

    @Test
    fun `the engine attaches to the activity as usual`() {
        assertTrue(activityWith(share("x")).shouldAttachEngineToActivity())
    }

    @Test
    fun `nothing in another app's intent changes the engine or opens a route`() {
        val activity = activityWith(hostile())

        assertEquals("shareMain", activity.dartEntrypointFunctionName)
        assertEquals("package:taketray/share_main.dart", activity.dartEntrypointLibraryUri)
        assertEquals(BackgroundMode.transparent, activity.backgroundMode)
        assertNull(activity.initialRoute)
        assertFalse(activity.shouldHandleDeeplinking())
        assertNull(activity.cachedEngineId)
        assertNull(activity.cachedEngineGroupId)
        assertTrue(activity.shouldDestroyEngineWithHost())
        assertNull(activity.dartEntrypointArgs)
        assertEquals(0, activity.flutterShellArgs.toArray().size)
        assertTrue(activity.shouldRestoreAndSaveState())
    }

    // ------------------------------------------------------------ a second share

    @Test
    fun `a second share replaces the first and is read once`() {
        val activity = activityWith(share("first"))
        val impl = ShareHostApiImpl(activity)
        assertEquals("first", impl.sharedText())

        activity.onNewIntent(share("second"))

        assertEquals("second", impl.sharedText())
        assertNull(impl.sharedText())
    }

    @Test
    fun `a second share before the first was read replaces it`() {
        val activity = activityWith(share("first"))
        val impl = ShareHostApiImpl(activity)

        activity.onNewIntent(share("second"))

        assertEquals("second", impl.sharedText())
        assertNull(impl.sharedText())
    }

    // ------------------------------------------------------------ the bridges

    @Test
    fun `it registers the share, links and editors bridges and nothing else`() {
        val messenger = RecordingMessenger()
        val bridges = ShareBridges(activityWith(share("x")))

        bridges.setUp(messenger)

        assertEquals(setOf("ShareHostApi", "LinksHostApi", "EditorsHostApi"), messenger.liveApis())
        for (absent in listOf("MediaHostApi", "BackgroundHostApi", "CopyHostApi", "FilesHostApi")) {
            assertFalse(absent, absent in messenger.allApis())
        }
        // The share bridge has its three methods.
        for (method in listOf("sharedText", "finish", "openReel")) {
            assertNotNull(method, messenger.handlers["dev.flutter.pigeon.taketray.ShareHostApi.$method"])
        }
    }

    @Test
    fun `tearing down removes every handler it set`() {
        val messenger = RecordingMessenger()
        val bridges = ShareBridges(activityWith(share("x")))
        bridges.setUp(messenger)

        bridges.tearDown(messenger)

        assertEquals(emptySet<String>(), messenger.liveApis())
        assertEquals(setOf("ShareHostApi", "LinksHostApi", "EditorsHostApi"), messenger.allApis())
    }

    @Test
    fun `once the host is gone the share bridge answers no-activity`() {
        val activity = activityWith(share("secret"))
        val bridges = ShareBridges(activity)
        bridges.setUp(RecordingMessenger())

        bridges.onHostGone()

        val e =
            try {
                bridges.share!!.sharedText()
                null
            } catch (e: ShareError) {
                e
            }
        assertEquals("no-activity", e?.code)
    }

    // ------------------------------------------------------------ the theme

    private fun id(
        type: String,
        name: String,
    ): Int = app.resources.getIdentifier(name, type, app.packageName)

    private fun shareTheme(): Resources.Theme {
        val style = id("style", "ShareTheme")
        assertTrue("@style/ShareTheme is missing", style != 0)
        return app.resources.newTheme().apply { applyStyle(style, true) }
    }

    private fun Resources.Theme.flag(attr: Int): Boolean {
        val value = TypedValue()
        assertTrue("${app.resources.getResourceName(attr)} is not set", resolveAttribute(attr, value, true))
        return value.data != 0
    }

    private fun Resources.Theme.isSet(attr: Int): Boolean = resolveAttribute(attr, TypedValue(), true)

    private fun checkShareTheme() {
        val theme = shareTheme()
        assertTrue("translucent", theme.flag(android.R.attr.windowIsTranslucent))
        assertTrue("no title", theme.flag(android.R.attr.windowNoTitle))
        assertTrue("no starting window", theme.flag(android.R.attr.windowDisablePreview))
        assertFalse("the window dims nothing itself", theme.flag(android.R.attr.backgroundDimEnabled))

        val background = TypedValue()
        assertTrue(theme.resolveAttribute(android.R.attr.windowBackground, background, true))
        val color = app.resources.getDrawable(background.resourceId, theme)
        assertTrue("windowBackground is $color", color is android.graphics.drawable.ColorDrawable)
        assertEquals(Color.TRANSPARENT, (color as android.graphics.drawable.ColorDrawable).color)

        // No splash: none of the splash screen's attributes (core-splashscreen) is set.
        for (name in listOf("windowSplashScreenAnimatedIcon", "windowSplashScreenBackground", "postSplashScreenTheme")) {
            val attr = id("attr", name)
            assertTrue("attr $name exists", attr != 0)
            assertFalse("$name is set", theme.isSet(attr))
        }
    }

    @Test
    fun `ShareTheme is see-through with no title and no splash`() {
        checkShareTheme()
    }

    @Test
    @Config(qualifiers = "night")
    fun `ShareTheme is see-through with no title and no splash in dark mode too`() {
        checkShareTheme()
    }

    @Test
    fun `the manifest gives ShareActivity ShareTheme and no NormalTheme`() {
        val info =
            app.packageManager.getActivityInfo(
                android.content.ComponentName(app, ShareActivity::class.java),
                android.content.pm.PackageManager.GET_META_DATA,
            )
        assertEquals(id("style", "ShareTheme"), info.theme)
        assertNull(info.metaData?.get("io.flutter.embedding.android.NormalTheme"))
    }
}
