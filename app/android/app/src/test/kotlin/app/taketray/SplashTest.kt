package app.taketray

import android.animation.Animator
import android.animation.AnimatorInflater
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.Activity
import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.res.Resources
import android.graphics.drawable.AnimatedVectorDrawable
import android.os.Looper
import android.util.TypedValue
import android.view.View
import androidx.core.splashscreen.SplashScreen
import androidx.test.core.app.ApplicationProvider
import java.io.File
import java.time.Duration
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.w3c.dom.Element
import org.xmlpull.v1.XmlPullParser

/**
 * The animated launch splash (D-137), checked as Android reads it: the theme
 * the activity starts with, the animated vector's groups and numbers, the
 * wordmark, the 200 ms exit fade and the order in `MainActivity.onCreate`.
 * Values are those of `design/handoff/launch-and-welcome-motion.md` section 1.
 */
@RunWith(RobolectricTestRunner::class)
class SplashTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val res: Resources = app.resources
    private val pkg = app.packageName

    private fun id(type: String, name: String): Int = res.getIdentifier(name, type, pkg)

    private fun requireId(type: String, name: String): Int {
        val found = id(type, name)
        assertTrue("@$type/$name is missing", found != 0)
        return found
    }

    /** The launch theme as the system applies it before any code runs. */
    private fun launchTheme(): Resources.Theme =
        res.newTheme().apply { applyStyle(requireId("style", "LaunchTheme"), true) }

    private fun Resources.Theme.resolved(attr: Int): TypedValue {
        val value = TypedValue()
        assertTrue("attribute ${res.getResourceName(attr)} is not set", resolveAttribute(attr, value, true))
        return value
    }

    // ------------------------------------------------------------ the theme

    @Test
    fun `the activity starts with LaunchTheme and keeps Flutter's NormalTheme`() {
        val info = app.packageManager.getActivityInfo(
            ComponentName(app, MainActivity::class.java),
            PackageManager.GET_META_DATA,
        )
        assertEquals(requireId("style", "LaunchTheme"), info.theme)
        assertEquals(
            requireId("style", "NormalTheme"),
            info.metaData.getInt("io.flutter.embedding.android.NormalTheme"),
        )
    }

    @Test
    fun `the splash animation lasts 900 ms and stays within Android's 1000 ms`() {
        val duration = launchTheme().resolved(androidx.core.splashscreen.R.attr.windowSplashScreenAnimationDuration)
        assertEquals(900, duration.data)
        assertTrue("over 1000 ms", duration.data <= 1000)
    }

    @Test
    fun `the post-splash theme is NormalTheme and the animated icon is set`() {
        val theme = launchTheme()
        val post = theme.resolved(androidx.core.splashscreen.R.attr.postSplashScreenTheme)
        assertEquals(requireId("style", "NormalTheme"), post.resourceId)
        val icon = theme.resolved(androidx.core.splashscreen.R.attr.windowSplashScreenAnimatedIcon)
        assertEquals(requireId("drawable", "splash_icon_animated"), icon.resourceId)
    }

    @Test
    fun `light splash is graphite with an icon background that matches it`() {
        val theme = launchTheme()
        val window = theme.resolved(androidx.core.splashscreen.R.attr.windowSplashScreenBackground)
        val icon = theme.resolved(androidx.core.splashscreen.R.attr.windowSplashScreenIconBackgroundColor)
        assertEquals(0xFF516072.toInt(), window.data)
        assertEquals(0xFF516072.toInt(), icon.data)
    }

    @Test
    @Config(qualifiers = "night")
    fun `dark splash is the light graphite with the graphite icon background`() {
        val theme = launchTheme()
        val window = theme.resolved(androidx.core.splashscreen.R.attr.windowSplashScreenBackground)
        val icon = theme.resolved(androidx.core.splashscreen.R.attr.windowSplashScreenIconBackgroundColor)
        assertEquals(0xFFB8C8DD.toInt(), window.data)
        assertEquals(0xFF516072.toInt(), icon.data)
        // The animation and the post theme do not change in the dark.
        assertEquals(900, theme.resolved(androidx.core.splashscreen.R.attr.windowSplashScreenAnimationDuration).data)
        assertEquals(
            requireId("style", "NormalTheme"),
            theme.resolved(androidx.core.splashscreen.R.attr.postSplashScreenTheme).resourceId,
        )
    }

    private fun checkPlatformAttributes() {
        // Android 12+ reads the platform attributes, which the compat theme mirrors.
        val theme = launchTheme()
        assertEquals(
            requireId("drawable", "splash_wordmark"),
            theme.resolved(android.R.attr.windowSplashScreenBrandingImage).resourceId,
        )
        assertEquals(900, theme.resolved(android.R.attr.windowSplashScreenAnimationDuration).data)
        assertEquals(
            requireId("drawable", "splash_icon_animated"),
            theme.resolved(android.R.attr.windowSplashScreenAnimatedIcon).resourceId,
        )
        assertEquals(0xFF516072.toInt(), theme.resolved(android.R.attr.windowSplashScreenIconBackgroundColor).data)
    }

    @Test
    @Config(sdk = [33, 34, 35])
    fun `Android 12 and up show the wordmark as the branding image`() {
        checkPlatformAttributes()
        assertEquals(0xFF516072.toInt(), launchTheme().resolved(android.R.attr.windowSplashScreenBackground).data)
    }

    @Test
    @Config(sdk = [33, 34, 35], qualifiers = "night")
    fun `Android 12 and up show the same branding image in the dark`() {
        checkPlatformAttributes()
        assertEquals(0xFFB8C8DD.toInt(), launchTheme().resolved(android.R.attr.windowSplashScreenBackground).data)
    }

    @Test
    fun `LaunchTheme descends from Theme SplashScreen in the day and the dark`() {
        // Source of truth: the style files. The dark folder must not bring its
        // own LaunchTheme (it would not be a Theme.SplashScreen child).
        val day = styleParent(File("src/main/res/values/styles.xml"), "LaunchTheme")
        assertTrue("LaunchTheme parent is $day", day == "Theme.SplashScreen" || day == "Theme.SplashScreen.IconBackground")
        assertNull(styleParent(File("src/main/res/values-night/styles.xml"), "LaunchTheme"))
    }

    private fun styleParent(file: File, name: String): String? {
        assertTrue("$file", file.isFile)
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
        val styles = doc.getElementsByTagName("style")
        for (i in 0 until styles.length) {
            val style = styles.item(i) as Element
            if (style.getAttribute("name") == name) return style.getAttribute("parent")
        }
        return null
    }

    // ------------------------------------------------- the animated vector

    @Test
    fun `splash_icon_animated inflates as an AnimatedVectorDrawable`() {
        val drawable = res.getDrawable(requireId("drawable", "splash_icon_animated"), app.theme)
        assertTrue("was ${drawable.javaClass}", drawable is AnimatedVectorDrawable)
    }

    /** A resource XML file as a tree: tag, android attributes (raw text and resource id), children. */
    private class Node(val tag: String, val raw: Map<String, String>, val ids: Map<String, Int>, val kids: List<Node>) {
        fun float(name: String): Float = raw.getValue(name).removeSuffix("dip").removeSuffix("dp").toFloat()
        fun all(tag: String): List<Node> = kids.filter { it.tag == tag }
        fun find(tag: String, name: String): Node = all(tag).single { it.raw["name"] == name }
    }

    private fun parse(type: String, name: String): Node {
        val xml = res.getXml(requireId(type, name))
        val stack = ArrayDeque<Triple<String, MutableMap<String, String>, MutableList<Node>>>()
        val ids = ArrayDeque<MutableMap<String, Int>>()
        var root: Node? = null
        var event = xml.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> {
                    val raw = mutableMapOf<String, String>()
                    val refs = mutableMapOf<String, Int>()
                    for (i in 0 until xml.attributeCount) {
                        raw[xml.getAttributeName(i)] = xml.getAttributeValue(i)
                        refs[xml.getAttributeName(i)] = xml.getAttributeResourceValue(i, 0)
                    }
                    stack.addLast(Triple(xml.name, raw, mutableListOf()))
                    ids.addLast(refs)
                }
                XmlPullParser.END_TAG -> {
                    val (tag, raw, kids) = stack.removeLast()
                    val node = Node(tag, raw, ids.removeLast(), kids)
                    if (stack.isEmpty()) root = node else stack.last().third.add(node)
                }
            }
            event = xml.next()
        }
        return root!!
    }

    private val vector get() = parse("drawable", "splash_icon_vector")

    @Test
    fun `the vector is the 108 launcher foreground in three groups in drawing order`() {
        val root = vector
        assertEquals("vector", root.tag)
        assertEquals(108f, root.float("viewportWidth"))
        assertEquals(108f, root.float("viewportHeight"))
        assertEquals(listOf("back", "front", "tray"), root.all("group").map { it.raw["name"] })
        assertTrue("only groups at the top", root.kids.all { it.tag == "group" })
    }

    @Test
    fun `the tray group pivots on its bottom centre and holds the body and the rim`() {
        val tray = vector.find("group", "tray")
        assertEquals(54f, tray.float("pivotX"))
        assertEquals(82f, tray.float("pivotY"))
        val paths = tray.all("path")
        assertEquals(listOf("tray_body", "tray_rim"), paths.map { it.raw["name"] })
        assertEquals(
            listOf("#ffffb952", "#ffe89b00"),
            paths.map { it.raw.getValue("fillColor").lowercase() },
        )
    }

    @Test
    fun `the clips keep their rotations on inner groups so the drop is straight down`() {
        val root = vector
        val back = root.find("group", "back")
        val front = root.find("group", "front")
        // The animated group itself is not rotated.
        for (outer in listOf(back, front)) {
            assertFalse("${outer.raw["name"]} is rotated", outer.raw.containsKey("rotation"))
        }
        val backInner = back.all("group").single()
        assertEquals(-12f, backInner.float("rotation"))
        assertEquals(52f, backInner.float("pivotX"))
        assertEquals(47f, backInner.float("pivotY"))
        assertEquals(listOf("back_clip"), backInner.all("path").map { it.raw["name"] })
        // The front clip and its play mark both turn 7 degrees about (61, 52).
        val frontInners = front.all("group")
        assertEquals(1, frontInners.size)
        val frontInner = frontInners.single()
        assertEquals(7f, frontInner.float("rotation"))
        assertEquals(61f, frontInner.float("pivotX"))
        assertEquals(52f, frontInner.float("pivotY"))
        assertEquals(listOf("front_clip", "front_play"), frontInner.all("path").map { it.raw["name"] })
    }

    private fun Node.paths(): List<Node> = all("path") + all("group").flatMap { it.paths() }

    @Test
    fun `the vector has no background rectangle because the theme gives the icon background`() {
        assertEquals(
            listOf("back_clip", "front_clip", "front_play", "tray_body", "tray_rim"),
            vector.paths().map { it.raw["name"] },
        )
    }

    @Test
    fun `the animated vector animates exactly the groups and paths the handoff names`() {
        val avd = parse("drawable", "splash_icon_animated")
        assertEquals("animated-vector", avd.tag)
        assertEquals(requireId("drawable", "splash_icon_vector"), avd.ids["drawable"])
        val targets = avd.all("target").associate { it.raw.getValue("name") to it.ids.getValue("animation") }
        assertEquals(
            mapOf(
                "tray" to requireId("animator", "splash_tray"),
                "back" to requireId("animator", "splash_back"),
                "front" to requireId("animator", "splash_front"),
                "tray_body" to requireId("animator", "splash_fade_tray"),
                "tray_rim" to requireId("animator", "splash_fade_tray"),
                "back_clip" to requireId("animator", "splash_fade_back"),
                "front_clip" to requireId("animator", "splash_fade_front"),
                "front_play" to requireId("animator", "splash_fade_front"),
            ),
            targets,
        )
        assertEquals(targets.size, avd.all("target").size)
    }

    // ----------------------------------------------------- the animations

    private data class Move(
        val property: String,
        val start: Long,
        val duration: Long,
        val from: Float,
        val to: Float,
        val interpolator: Int,
    )

    /** The `objectAnimator`s of an animator file (one, or the children of its `set`), in file order. */
    private fun moves(name: String): List<Move> {
        val root = parse("animator", name)
        val animators = if (root.tag == "set") root.all("objectAnimator") else listOf(root)
        assertTrue("$name has no objectAnimator", animators.isNotEmpty())
        return animators.map {
            Move(
                it.raw.getValue("propertyName"),
                it.raw["startOffset"]?.toLong() ?: 0L,
                it.raw.getValue("duration").toLong(),
                it.float("valueFrom"),
                it.float("valueTo"),
                it.ids["interpolator"] ?: 0,
            )
        }
    }

    private val decelerate get() = requireId("interpolator", "splash_emphasized_decelerate")
    private val standard get() = requireId("interpolator", "splash_standard")

    /** Sets [property] to [value] in the first frame: a zero-length animator at offset 0, no easing. */
    private fun hold(property: String, value: Float) = Move(property, 0, 0, value, value, 0)

    @Test
    fun `the back clip is held above the tray, then falls 40 units in 400 ms after 150 ms`() {
        assertEquals(
            listOf(hold("translateY", -40f), Move("translateY", 150, 400, -40f, 0f, decelerate)),
            moves("splash_back"),
        )
        assertEquals(
            listOf(hold("fillAlpha", 0f), Move("fillAlpha", 150, 400, 0f, 1f, decelerate)),
            moves("splash_fade_back"),
        )
    }

    @Test
    fun `the front clip is held above the tray, then falls 48 units in 450 ms after 300 ms`() {
        assertEquals(
            listOf(hold("translateY", -48f), Move("translateY", 300, 450, -48f, 0f, decelerate)),
            moves("splash_front"),
        )
        assertEquals(
            listOf(hold("fillAlpha", 0f), Move("fillAlpha", 300, 450, 0f, 1f, decelerate)),
            moves("splash_fade_front"),
        )
    }

    @Test
    fun `the tray's rise and fade start at offset 0 so the first frame shows their start values`() {
        // Nothing to hold: they begin at 0 ms themselves (the clips need a hold, they wait 150 and 300 ms).
        assertEquals(listOf(Move("fillAlpha", 0, 300, 0f, 1f, decelerate)), moves("splash_fade_tray"))
        val rise = moves("splash_tray").single { it.property == "translateY" }
        assertEquals(Move("translateY", 0, 300, 14f, 0f, decelerate), rise)
    }

    @Test
    fun `the tray catches the clips at 700 ms with a 220 ms squash peaking at 40 percent`() {
        val tray = parse("animator", "splash_tray")
        assertEquals("set", tray.tag)
        assertEquals("ordering is together (0), not sequentially (1)", "0", tray.raw["ordering"])
        // Two plain two-value animators per property (there, then back): the
        // hardware path of an animated vector may sample only the first and last
        // keyframe of a keyframe animator (both 1) and the tray would not squash.
        assertTrue("no keyframes", tray.kids.none { it.tag == "objectAnimator" && it.kids.isNotEmpty() })
        val squash = moves("splash_tray").filter { it.property != "translateY" }
        assertEquals(
            listOf(
                Move("scaleX", 700, 88, 1f, 1.04f, standard),
                Move("scaleX", 788, 132, 1.04f, 1f, standard),
                Move("scaleY", 700, 88, 1f, 0.9f, standard),
                Move("scaleY", 788, 132, 0.9f, 1f, standard),
            ),
            squash,
        )
        // The peak is 40 % of 220 ms, and the two legs end where the motion ends.
        assertEquals(88L, Math.round(220 * 0.4))
        assertEquals(920L, squash.maxOf { it.start + it.duration })
    }

    @Test
    fun `no animator uses keyframes or a propertyValuesHolder`() {
        for (name in listOf("splash_tray", "splash_back", "splash_front", "splash_fade_tray", "splash_fade_back", "splash_fade_front")) {
            fun Node.hasKeyframes(): Boolean = tag == "keyframe" || tag == "propertyValuesHolder" || kids.any { it.hasKeyframes() }
            assertFalse("$name uses keyframes", parse("animator", name).hasKeyframes())
        }
    }

    @Test
    fun `the vector itself stays the settled icon, so Android 11 and Remove animations show it whole`() {
        val root = vector
        fun Node.settled() {
            assertFalse("$tag ${raw["name"]} is translated", raw.containsKey("translateY") || raw.containsKey("translateX"))
            assertFalse("$tag ${raw["name"]} is scaled", raw.containsKey("scaleX") || raw.containsKey("scaleY"))
            assertFalse("$tag ${raw["name"]} is faded", raw.containsKey("fillAlpha") || raw.containsKey("alpha"))
            kids.forEach { it.settled() }
        }
        root.settled()
    }

    @Test
    fun `the two interpolators are the Material emphasized decelerate and standard curves`() {
        fun curve(name: String): List<Float> {
            val n = parse("interpolator", name)
            assertEquals("pathInterpolator", n.tag)
            return listOf("controlX1", "controlY1", "controlX2", "controlY2").map { n.float(it) }
        }
        assertEquals(listOf(0.05f, 0.7f, 0.1f, 1f), curve("splash_emphasized_decelerate"))
        assertEquals(listOf(0.2f, 0f, 0f, 1f), curve("splash_standard"))
    }

    @Test
    fun `the whole motion ends at 920 ms, inside Android's second`() {
        val ends = listOf("splash_tray", "splash_back", "splash_front", "splash_fade_tray", "splash_fade_back", "splash_fade_front")
            .map { totalMs(AnimatorInflater.loadAnimator(app, requireId("animator", it))) }
        assertEquals(listOf(920L, 550L, 750L, 300L, 550L, 750L), ends)
        assertTrue(ends.max() <= 1000)
    }

    private fun totalMs(animator: Animator): Long = animator.totalDuration

    @Test
    fun `the inflated animators are objectAnimators on the right properties`() {
        val tray = AnimatorInflater.loadAnimator(app, requireId("animator", "splash_tray"))
        assertTrue(tray is AnimatorSet)
        val children = (tray as AnimatorSet).childAnimations.filterIsInstance<ObjectAnimator>()
        assertEquals(setOf("translateY", "scaleX", "scaleY"), children.map { it.propertyName }.toSet())
        assertEquals(5, children.size)
    }

    // --------------------------------------------------------- the wordmark

    @Test
    fun `the wordmark is a 200 by 80 dp vector in the on-primary colour`() {
        val wm = parse("drawable", "splash_wordmark")
        assertEquals("vector", wm.tag)
        assertEquals(200f, wm.float("width"))
        assertEquals(80f, wm.float("height"))
        assertEquals(200f, wm.float("viewportWidth"))
        assertEquals(80f, wm.float("viewportHeight"))
        val paths = wm.paths()
        assertTrue("no glyph outline", paths.isNotEmpty())
        for (path in paths) {
            assertEquals(requireId("color", "splash_on_primary"), path.ids["fillColor"])
            assertTrue("empty path data", path.raw.getValue("pathData").length > 200)
        }
        // TakeTray has eight letters: T a k e T r a y; the outline paths are 8 subpaths of M.
        val subpaths = paths.sumOf { Regex("M").findAll(it.raw.getValue("pathData")).count() }
        assertTrue("fewer than 8 glyph outlines ($subpaths)", subpaths >= 8)
    }

    @Test
    fun `the wordmark colour in the light is white`() {
        assertEquals(0xFFFFFFFF.toInt(), res.getColor(requireId("color", "splash_on_primary"), null))
    }

    @Test
    @Config(qualifiers = "night")
    fun `the wordmark colour in the dark is dark graphite`() {
        assertEquals(0xFF243142.toInt(), res.getColor(requireId("color", "splash_on_primary"), null))
    }

    // ------------------------------------------------------------ the exit

    @Test
    fun `the exit fades the splash to nothing in 200 ms and removes it after the fade`() {
        // Robolectric's ShadowViewPropertyAnimator runs a view animation at once
        // (its end values, then the end action), so the order is what can be
        // checked here (after the looper runs): remove only after the alpha is 0, and once.
        val view = View(app)
        var removed = 0
        var alphaWhenRemoved = -1f
        LaunchSplash.fadeOut(view) {
            removed++
            alphaWhenRemoved = view.alpha
        }
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("the fade lasts 200 ms", 200L, view.animate().duration)
        assertEquals("the exit is short4", 200L, LaunchSplash.FADE_MS)
        assertTrue("the exit is faster than the 920 ms entrance", LaunchSplash.FADE_MS < 920)
        assertEquals("removed once", 1, removed)
        assertEquals("removed after the fade, not before", 0f, alphaWhenRemoved, 0f)
        assertEquals(0f, view.alpha, 0f)
    }

    // ------------------------------------------------------------ installing

    // The two helpers below and the test after them read core-splashscreen's
    // private fields (`impl`, `splashScreenWaitPredicate`, `preDrawListener`,
    // `animationListener`) by reflection, as of 1.0.1. A version bump of
    // androidx.core:core-splashscreen needs this re-checked: a renamed field
    // fails the test with NoSuchFieldException, which means "look again", not
    // "the splash is broken".
    private fun implOf(splash: SplashScreen): Any {
        val field = SplashScreen::class.java.getDeclaredField("impl")
        field.isAccessible = true
        return field.get(splash)!!
    }

    private fun field(owner: Any, name: String): Any? {
        var c: Class<*>? = owner.javaClass
        while (c != null) {
            try {
                val f = c.getDeclaredField(name)
                f.isAccessible = true
                return f.get(owner)
            } catch (_: NoSuchFieldException) {
                c = c.superclass
            }
        }
        throw NoSuchFieldException(name)
    }

    @Test
    fun `installing keeps no condition that holds the splash and attaches the exit`() {
        val activity = Robolectric.buildActivity(Activity::class.java).get()
        activity.setTheme(requireId("style", "LaunchTheme"))
        val splash = LaunchSplash.install(activity)
        val impl = implOf(splash)
        val predicate = field(impl, "splashScreenWaitPredicate") as SplashScreen.KeepOnScreenCondition
        assertFalse("a keep-on-screen condition holds the splash", predicate.shouldKeepOnScreen())
        // Android 12+ attaches the condition as a pre-draw listener, only when one is set.
        if (impl.javaClass.simpleName == "Impl31") assertNull(field(impl, "preDrawListener"))
        // Android 11's compat keeps the listener itself; on 12+ it hands it to the platform.
        if (impl.javaClass.simpleName == "Impl") assertNotNull(field(impl, "animationListener"))
    }

    @Test
    fun `the source calls installSplashScreen before super onCreate`() {
        // A Robolectric launch of MainActivity cannot tell the order: there is no
        // Flutter engine on the JVM, and FlutterActivity applies NormalTheme
        // itself before it fails, the same theme the splash swaps in. So the order
        // is read from the source, the one place it is written.
        val source = File("src/main/kotlin/app/taketray/MainActivity.kt").readText()
        val onCreate = source.substringAfter("override fun onCreate(")
            .substringBefore("override fun configureFlutterEngine")
        val install = onCreate.indexOf("LaunchSplash.install(")
        val superCreate = onCreate.indexOf("super.onCreate(")
        assertTrue("no install call", install >= 0)
        assertTrue("no super.onCreate", superCreate >= 0)
        assertTrue("install comes after super.onCreate", install < superCreate)
        assertFalse(onCreate.contains("setKeepOnScreenCondition"))
    }
}
