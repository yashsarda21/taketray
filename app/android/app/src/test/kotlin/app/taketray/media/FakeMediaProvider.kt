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
 * Stands in for Android's media provider in Robolectric tests: every query
 * answers with no cursor (as when the real provider is unavailable), and
 * opening a thumbnail throws [openError].
 */
class FakeMediaProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        queryArgs: Bundle?,
        cancellationSignal: CancellationSignal?,
    ): Cursor? = null

    override fun openTypedAssetFile(
        uri: Uri,
        mimeTypeFilter: String,
        opts: Bundle?,
        signal: CancellationSignal?,
    ): AssetFileDescriptor = throw openError

    override fun openTypedAssetFile(
        uri: Uri,
        mimeTypeFilter: String,
        opts: Bundle?,
    ): AssetFileDescriptor = throw openError

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

        /** Registers a fresh provider for the media authority. */
        fun install(openError: Exception = java.io.FileNotFoundException("gone")) {
            this.openError = openError
            Robolectric.setupContentProvider(FakeMediaProvider::class.java, MediaStore.AUTHORITY)
        }
    }
}
