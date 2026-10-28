package app.taketray.media

/**
 * Placeholder for the Kotlin side of the media bridge: every method fails with
 * [NotImplementedError]. Task 4 of Phase 3 replaces it with the real MediaStore
 * reader. It is not registered in MainActivity yet, so nothing calls it.
 */
class MediaHostApiImpl : MediaHostApi {
    override fun accessReport(): AccessReportMsg = notYet()

    override suspend fun requestAccess(): AccessReportMsg = notYet()

    override fun openAppSettings(): Unit = notYet()

    override fun volumes(): List<VolumeMsg> = notYet()

    override suspend fun videosAddedAfter(
        volumeName: String,
        afterGeneration: Long,
        folders: List<String>,
        limit: Long,
    ): List<VideoRowMsg> = notYet()

    override suspend fun videosByIds(volumeName: String, ids: List<Long>): List<VideoRowMsg> = notYet()

    override suspend fun allVideos(volumeName: String): List<VideoRowMsg> = notYet()

    override suspend fun videosShotSince(
        volumeName: String,
        folders: List<String>,
        sinceMs: Long,
    ): List<VideoRowMsg> = notYet()

    override suspend fun videoFolders(): List<VideoFolderMsg> = notYet()

    override suspend fun thumbnail(
        volumeName: String,
        mediaStoreId: Long,
        widthPx: Long,
        heightPx: Long,
    ): ByteArray? = notYet()

    override fun currentZoneId(): String = notYet()

    override fun pendingZoneChanges(): List<ZoneChangeMsg> = notYet()

    override fun clearZoneChangesUpTo(atMs: Long): Unit = notYet()

    override fun openVideoCamera(): Boolean = notYet()

    private fun notYet(): Nothing = throw NotImplementedError("MediaHostApi is implemented in Task 4")
}
