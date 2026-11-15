package app.taketray.background

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.provider.MediaStore
import androidx.test.core.app.ApplicationProvider
import app.taketray.MainActivity
import app.taketray.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * The new-clips notification (D-104): one quiet notification with a fixed id,
 * private on the lock screen, whose taps open To tag or the video camera.
 */
@RunWith(RobolectricTestRunner::class)
class NotifierTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val notifier = Notifier(app)
    private val picture = Bitmap.createBitmap(64, 36, Bitmap.Config.ARGB_8888)

    @Before
    fun setUp() = shadowOf(manager).setNotificationsEnabled(true)

    private fun posted(): Notification =
        shadowOf(manager).getNotification(Notifier.NEW_CLIPS) ?: throw AssertionError("no new-clips notification")

    private fun Notification.title() = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()

    private fun Notification.text() = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()

    private fun Notification.action(label: String): Notification.Action = actions.single { it.title.toString() == label }

    @Test
    fun `channels have the copy names and importance`() {
        notifier.ensureChannels()
        val newClips = manager.getNotificationChannel(Notifier.CHANNEL_NEW_CLIPS)
        assertEquals("New clips", newClips.name)
        assertEquals("new_clips_alert", Notifier.CHANNEL_NEW_CLIPS)
        assertEquals("A notification, with one sound, when you have stopped filming and new clips are waiting to be tagged.", newClips.description)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, newClips.importance)
        val reminders = manager.getNotificationChannel(Notifier.CHANNEL_REMINDERS)
        assertEquals("Reminders", reminders.name)
        assertEquals("The evening reminder and the Shooting mode reminder.", reminders.description)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, reminders.importance)
    }

    @Test
    fun `not allowed posts nothing and does not throw`() {
        shadowOf(manager).setNotificationsEnabled(false)
        assertFalse(notifier.showNewClips(3, picture))
        assertEquals(0, shadowOf(manager).size())

        // Allowed for the app, but the user blocked the New clips channel.
        shadowOf(manager).setNotificationsEnabled(true)
        manager.createNotificationChannel(NotificationChannel(Notifier.CHANNEL_NEW_CLIPS, "New clips", NotificationManager.IMPORTANCE_NONE))
        assertFalse(notifier.canPost(Notifier.CHANNEL_NEW_CLIPS))
        assertFalse(notifier.showNewClips(3, picture))
        assertEquals(0, shadowOf(manager).size())
    }

    @Test
    fun `notification alerts once, private`() {
        assertTrue(notifier.showNewClips(3, picture))
        val n = posted()
        assertEquals(Notifier.CHANNEL_NEW_CLIPS, n.channelId)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel(n.channelId).importance)
        assertTrue("only alerts once", n.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertTrue("auto-cancel", n.flags and Notification.FLAG_AUTO_CANCEL != 0)
        assertEquals(Notification.VISIBILITY_PRIVATE, n.visibility)
        assertEquals(R.drawable.ic_stat_taketray, n.smallIcon.resId)
        assertEquals("3 new clips to tag", n.title())
        assertEquals("Tap to tag them into your reels.", n.text())
        // The thumbnail: the big picture, and the large icon only while collapsed.
        assertNotNull(n.extras.getParcelable(Notification.EXTRA_PICTURE) as Bitmap?)
        assertNotNull(n.getLargeIcon())
        assertNull(n.extras.getParcelable(Notification.EXTRA_LARGE_ICON_BIG) as android.os.Parcelable?)
        assertEquals(listOf("Open camera", "Tag now"), n.actions.map { it.title.toString() })

        // One clip: the singular copy, the same id (updated in place).
        assertTrue(notifier.showNewClips(1, null))
        assertEquals(1, shadowOf(manager).size())
        assertEquals("1 new clip to tag", posted().title())
        assertEquals("Tap to tag it into a reel.", posted().text())
    }

    @Test
    fun `a missing thumbnail still posts`() {
        assertTrue(notifier.showNewClips(2, null))
        val n = posted()
        assertEquals("2 new clips to tag", n.title())
        assertNull(n.extras.getParcelable(Notification.EXTRA_PICTURE) as Bitmap?)
        assertNull(n.getLargeIcon())
    }

    @Test
    fun `public version has no picture`() {
        notifier.showNewClips(4, picture)
        val public = posted().publicVersion ?: throw AssertionError("no public version")
        assertEquals("TakeTray", public.title())
        assertEquals("4 new clips to tag", public.text())
        assertNull(public.extras.getParcelable(Notification.EXTRA_PICTURE) as Bitmap?)
        assertNull(public.getLargeIcon())
        assertNull(public.extras.getString(Notification.EXTRA_TEMPLATE))
        assertEquals(R.drawable.ic_stat_taketray, public.smallIcon.resId)
        assertEquals(Notifier.CHANNEL_NEW_CLIPS, public.channelId)
    }

    @Test
    fun `tag now and body open To tag`() {
        notifier.showNewClips(3, picture)
        val n = posted()
        val body = shadowOf(n.contentIntent)
        val tagNow = shadowOf(n.action("Tag now").actionIntent)
        for (pending in listOf(body, tagNow)) {
            assertTrue(pending.isActivity)
            assertTrue(pending.isImmutable)
            assertTrue(pending.flags and PendingIntent.FLAG_UPDATE_CURRENT != 0)
            val intent = Intent(pending.savedIntent)
            assertEquals(ComponentName(app, MainActivity::class.java), intent.component)
            assertEquals(LaunchMsg(LaunchActionMsg.TO_TAG), LaunchActions.read(intent))
        }
        val camera = shadowOf(n.action("Open camera").actionIntent)
        assertEquals(
            setOf(Notifier.REQUEST_NEW_CLIPS_BODY, Notifier.REQUEST_NEW_CLIPS_TAG_NOW, Notifier.REQUEST_NEW_CLIPS_CAMERA),
            setOf(body.requestCode, tagNow.requestCode, camera.requestCode),
        )
    }

    @Test
    fun `open camera opens the video camera`() {
        notifier.showNewClips(3, picture)
        val camera = shadowOf(posted().action("Open camera").actionIntent)
        assertTrue(camera.isActivity)
        assertTrue(camera.isImmutable)
        assertTrue(camera.flags and PendingIntent.FLAG_UPDATE_CURRENT != 0)
        assertEquals(MediaStore.INTENT_ACTION_VIDEO_CAMERA, camera.savedIntent.action)
        assertTrue(camera.savedIntent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }

    @Test
    fun `cancel removes only the new clips notification`() {
        notifier.showNewClips(3, picture)
        val other = Notification.Builder(app, Notifier.CHANNEL_REMINDERS).setSmallIcon(R.drawable.ic_stat_taketray).build()
        manager.notify(Notifier.EVENING, other)
        notifier.cancelNewClips()
        assertNull(shadowOf(manager).getNotification(Notifier.NEW_CLIPS))
        assertNotNull(shadowOf(manager).getNotification(Notifier.EVENING))
    }

    @Test
    fun `the old quiet channel is deleted, also on a phone that already has it`() {
        // A phone that ran the previous version: the LOW channel exists.
        manager.createNotificationChannel(NotificationChannel("new_clips", "New clips", NotificationManager.IMPORTANCE_LOW))
        assertNotNull(manager.getNotificationChannel("new_clips"))
        notifier.ensureChannels()
        assertNull(manager.getNotificationChannel("new_clips"))
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel("new_clips_alert").importance)
        // Again, with nothing left to delete, and after a post.
        notifier.ensureChannels()
        notifier.showNewClips(2, null)
        assertNull(manager.getNotificationChannel("new_clips"))
        assertEquals(setOf("new_clips_alert", "reminders"), manager.notificationChannels.map { it.id }.toSet())
    }

    @Test
    fun `a blocked old channel does not block the new one`() {
        manager.createNotificationChannel(NotificationChannel("new_clips", "New clips", NotificationManager.IMPORTANCE_NONE))
        assertTrue(notifier.showNewClips(3, null))
        assertEquals(Notifier.CHANNEL_NEW_CLIPS, posted().channelId)
        assertNull(manager.getNotificationChannel("new_clips"))
    }

    @Test
    fun `a blocked new channel still blocks`() {
        notifier.ensureChannels()
        manager.createNotificationChannel(NotificationChannel(Notifier.CHANNEL_NEW_CLIPS, "New clips", NotificationManager.IMPORTANCE_NONE))
        assertFalse(notifier.canPost(Notifier.CHANNEL_NEW_CLIPS))
        assertFalse(notifier.showNewClips(3, null))
    }

    @Test
    fun `a count update of a showing notification does not alert again`() {
        // Android alerts a notification that replaces a showing one only when
        // it is not marked only-alert-once; both posts carry the mark.
        assertTrue(notifier.showNewClips(2, picture))
        assertTrue(posted().flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertTrue(notifier.showNewClips(3, picture))
        val updated = posted()
        assertEquals("3 new clips to tag", updated.title())
        assertEquals(1, shadowOf(manager).size())
        assertTrue("the update is marked only-alert-once", updated.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertEquals(Notifier.CHANNEL_NEW_CLIPS, updated.channelId)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel(updated.channelId).importance)
    }

    @Test
    fun `a post after a dismiss is a fresh alert`() {
        // A fresh post is alerted by the channel (DEFAULT: sound), as nothing
        // is showing for only-alert-once to hold back; and nothing silences it.
        notifier.showNewClips(2, picture)
        manager.cancel(Notifier.NEW_CLIPS) // swiped away
        assertEquals(0, shadowOf(manager).size())
        assertTrue(notifier.showNewClips(4, picture))
        val again = posted()
        assertEquals("4 new clips to tag", again.title())
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, manager.getNotificationChannel(again.channelId).importance)
        assertEquals(Notification.GROUP_ALERT_ALL, again.groupAlertBehavior)
        assertNull("no group that could silence it", again.group)
    }
}
