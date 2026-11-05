package app.taketray.background

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.provider.MediaStore
import app.taketray.R

/**
 * TakeTray's notifications, built without a Flutter engine (D-101), with the
 * copy in `res/values/strings.xml`. Two channels: **New clips** (LOW: no
 * sound, no vibration) and **Reminders** (DEFAULT, Task 5). Each notification
 * has a fixed id, so posting again updates it in place.
 *
 * Quiet (D-104): one new-clips notification, `setOnlyAlertOnce`, and nothing
 * at all while notifications or its channel are off. Never a file name or a
 * folder in a notification, never a count in the log (D-10).
 */
class Notifier(
    private val context: Context,
) {
    private val manager: NotificationManager = context.getSystemService(NotificationManager::class.java)

    /** Creates both channels; creating an existing one only refreshes its name and description. */
    fun ensureChannels() {
        manager.createNotificationChannels(
            listOf(
                channel(CHANNEL_NEW_CLIPS, R.string.channel_new_clips_name, R.string.channel_new_clips_description, NotificationManager.IMPORTANCE_LOW),
                channel(CHANNEL_REMINDERS, R.string.channel_reminders_name, R.string.channel_reminders_description, NotificationManager.IMPORTANCE_DEFAULT),
            ),
        )
    }

    private fun channel(
        id: String,
        name: Int,
        description: Int,
        importance: Int,
    ) = NotificationChannel(id, context.getString(name), importance).apply { this.description = context.getString(description) }

    /**
     * Whether a notification on [channelId] would show: notifications are
     * enabled for the app (on Android 13+, the permission) and the user has
     * not blocked the channel.
     */
    fun canPost(channelId: String): Boolean {
        if (!manager.areNotificationsEnabled()) return false
        val channel = manager.getNotificationChannel(channelId) ?: return true
        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    /**
     * Posts or updates the new-clips notification for [count] (at least 1)
     * clips, with [thumbnail] (the newest clip's) as its big picture and large
     * icon, or without a picture when null. Returns false, posting nothing,
     * when notifications are not allowed ([canPost]).
     */
    fun showNewClips(
        count: Int,
        thumbnail: Bitmap?,
    ): Boolean {
        require(count > 0) { "the new-clips notification needs at least one clip" }
        ensureChannels()
        if (!canPost(CHANNEL_NEW_CLIPS)) return false
        val res = context.resources
        val title = res.getQuantityString(R.plurals.new_clips_title, count, count)
        // The lock screen: the app name and the count, nothing else (D-101).
        val public =
            Notification
                .Builder(context, CHANNEL_NEW_CLIPS)
                .setSmallIcon(R.drawable.ic_stat_taketray)
                .setContentTitle(context.getString(R.string.new_clips_public_title))
                .setContentText(title)
                .build()
        val toTag = LaunchActions.intent(context, LaunchActionMsg.TO_TAG)
        val camera = Intent(MediaStore.INTENT_ACTION_VIDEO_CAMERA).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val builder =
            Notification
                .Builder(context, CHANNEL_NEW_CLIPS)
                .setSmallIcon(R.drawable.ic_stat_taketray)
                .setContentTitle(title)
                .setContentText(res.getQuantityString(R.plurals.new_clips_text, count))
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setPublicVersion(public)
                .setContentIntent(activity(REQUEST_NEW_CLIPS_BODY, toTag))
                .addAction(action(R.string.action_open_camera, activity(REQUEST_NEW_CLIPS_CAMERA, camera)))
                .addAction(action(R.string.action_tag_now, activity(REQUEST_NEW_CLIPS_TAG_NOW, toTag)))
        if (thumbnail != null) {
            // The picture as the large icon while collapsed; expanded, the big
            // picture alone (no second copy as the large icon).
            builder
                .setLargeIcon(thumbnail)
                .setStyle(Notification.BigPictureStyle().bigPicture(thumbnail).bigLargeIcon(null as Icon?))
        }
        manager.notify(NEW_CLIPS, builder.build())
        return true
    }

    /** Removes the new-clips notification; the reminders stay. */
    fun cancelNewClips() = manager.cancel(NEW_CLIPS)

    private fun activity(
        requestCode: Int,
        intent: Intent,
    ): PendingIntent = PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    /** A text action: Android reads the label (accessibility). */
    private fun action(
        label: Int,
        intent: PendingIntent,
    ): Notification.Action = Notification.Action.Builder(null as Icon?, context.getString(label), intent).build()

    companion object {
        /** Notification ids, fixed: posting again updates in place. */
        const val NEW_CLIPS = 1
        const val EVENING = 2
        const val STILL_SHOOTING = 3

        const val CHANNEL_NEW_CLIPS = "new_clips"
        const val CHANNEL_REMINDERS = "reminders"

        /**
         * PendingIntent request codes, one per tap target, so no two replace
         * each other (the body and Tag now carry the same intent). Task 5's
         * reminders use 2xx and 3xx.
         */
        const val REQUEST_NEW_CLIPS_BODY = 101
        const val REQUEST_NEW_CLIPS_TAG_NOW = 102
        const val REQUEST_NEW_CLIPS_CAMERA = 103
    }
}
