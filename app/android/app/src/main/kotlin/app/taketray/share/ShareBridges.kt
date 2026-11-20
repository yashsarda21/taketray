package app.taketray.share

import android.app.Activity
import android.content.Intent
import app.taketray.editors.EditorsHostApi
import app.taketray.editors.EditorsHostApiImpl
import app.taketray.links.LinksHostApi
import app.taketray.links.LinksHostApiImpl
import io.flutter.plugin.common.BinaryMessenger

/**
 * The bridges of the share screen's engine (D-163), and only these: the share
 * bridge itself, links (to open a saved reference) and editors (for the
 * source apps' icons). The share engine has no media, background, copy or
 * files bridge, so it cannot scan videos, arm the background or touch
 * copies.
 */
internal class ShareBridges(
    private val activity: Activity,
) {
    /** The share bridge of the current engine; null before [setUp] and after [tearDown]. */
    var share: ShareHostApiImpl? = null
        private set

    private var links: LinksHostApiImpl? = null
    private var editors: EditorsHostApiImpl? = null

    fun setUp(messenger: BinaryMessenger) {
        val shareApi = ShareHostApiImpl(activity)
        share = shareApi
        ShareHostApi.setUp(messenger, shareApi)

        val linksApi = LinksHostApiImpl(activity)
        links = linksApi
        LinksHostApi.setUp(messenger, linksApi)

        val editorsApi = EditorsHostApiImpl(activity)
        editors = editorsApi
        EditorsHostApi.setUp(messenger, editorsApi)
    }

    fun tearDown(messenger: BinaryMessenger) {
        ShareHostApi.setUp(messenger, null)
        LinksHostApi.setUp(messenger, null)
        EditorsHostApi.setUp(messenger, null)
        onHostGone()
        share = null
        links = null
        editors = null
    }

    /** The activity is going: a call still waiting fails, and later calls are `no-activity`. */
    fun onHostGone() {
        share?.onHostGone()
        links?.onHostGone()
        editors?.onHostGone()
    }

    /** A result for the editors bridge (its delete consent); the share screen starts no other. */
    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        editors?.onActivityResult(requestCode, resultCode, data)
    }
}
