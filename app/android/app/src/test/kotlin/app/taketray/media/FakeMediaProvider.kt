package app.taketray.media

import android.content.ContentProvider
import android.content.ContentValues
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.provider.MediaStore
import org.robolectric.Robolectric

/**
 * Stands in for Android's media provider in Robolectric tests. It records
 * every query (uri, projection, query arguments) in [queries] and answers
 * with [answer], which by default gives no cursor (as when the real provider
 * is unavailable). Opening a thumbnail records its options in [opens] and
 * throws [openError].
 */
class FakeMediaProvider : ContentProvider() {
    /** One recorded query. [args] is a copy of the Bundle the resolver passed. */
    data class Query(
        val uri: Uri,
        val projection: List<String>?,
        val args: Bundle?,
    )

    override fun onCreate() = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = throw AssertionError("the bridge must query with a Bundle")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        queryArgs: Bundle?,
        cancellationSignal: CancellationSignal?,
    ): Cursor? {
        val q = Query(uri, projection?.toList(), queryArgs?.let { Bundle(it) })
        queries += q
        return answer(q)
    }

    override fun openTypedAssetFile(
        uri: Uri,
        mimeTypeFilter: String,
        opts: Bundle?,
        signal: CancellationSignal?,
    ): AssetFileDescriptor {
        opens += opts?.let { Bundle(it) } ?: Bundle()
        throw openError
    }

    override fun openTypedAssetFile(
        uri: Uri,
        mimeTypeFilter: String,
        opts: Bundle?,
    ): AssetFileDescriptor = openTypedAssetFile(uri, mimeTypeFilter, opts, null)

    override fun getType(uri: Uri): String? = null

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri? = null

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0

    companion object {
        /** What opening a thumbnail throws. */
        var openError: Exception = java.io.FileNotFoundException("gone")

        /** How a query is answered; may throw. */
        var answer: (Query) -> Cursor? = { null }

        /** Every query since [install], in order. */
        val queries = mutableListOf<Query>()

        /** The options of every thumbnail open since [install]. */
        val opens = mutableListOf<Bundle>()

        /** Registers a fresh provider for the media authority and resets the recordings. */
        fun install(
            openError: Exception = java.io.FileNotFoundException("gone"),
            answer: (Query) -> Cursor? = { null },
        ) {
            this.openError = openError
            this.answer = answer
            queries.clear()
            opens.clear()
            Robolectric.setupContentProvider(FakeMediaProvider::class.java, MediaStore.AUTHORITY)
        }
    }
}
