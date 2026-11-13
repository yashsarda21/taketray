/// Top-level locations of the three tabs.
abstract final class Routes {
  static const reels = '/reels';
  static const toTag = '/to-tag';
  static const settings = '/settings';

  /// The help screen "Notifications not arriving?" (D-107), a child of
  /// Settings, full screen above the tab shell like the tag player. Back
  /// returns to Settings.
  static const notificationsHelp = '/settings/notifications-help';

  /// The Skipped clips (D-98, D-99), inside the To tag tab
  /// so the nav pill stays; Back returns to To tag.
  static const skipped = '/to-tag/skipped';

  /// The tag player (D-97), above the tab shell. It is a child of To tag, so
  /// Back returns there.
  static const tagPlayer = '/to-tag/play';

  /// The name of the clip id in the tag player's location.
  static const tagFromParameter = 'from';

  /// The tag player's location, starting on clip [clipId] (`?from=<id>`), or
  /// on the first waiting clip when it is null.
  static String tagFrom(int? clipId) =>
      clipId == null ? tagPlayer : '$tagPlayer?$tagFromParameter=$clipId';

  /// The name of the reel id in a reel's location.
  static const reelIdParameter = 'id';

  /// The location of reel [id]'s page, under the Reels tab.
  static String reel(int id) => '$reels/$id';

  /// The name of the "ask Done editing" flag in a reel's location.
  static const reelDoneParameter = 'done';

  /// Reel [id]'s page, opened by the copies reminder (Phase 8, D-124). The
  /// page asks Done editing once when the reel still has an editing session.
  static String reelDoneEditing(int id) => '${reel(id)}?done=1';

  /// The name of the clip id in a clip's location.
  static const clipIdParameter = 'clipId';

  /// The location of the viewer on clip [clipId] of reel [reelId], above the
  /// reel's page (`/reels/:reelId/clip/:clipId`).
  static String clip(int reelId, int clipId) => '${reel(reelId)}/clip/$clipId';

  /// Add videos' folder list (Phase 7, D-114): full screen above the tab
  /// shell, on the root navigator, so it can be opened from To tag and from a
  /// reel's page. Its target is To tag, or the reel in [addVideosReelParameter]
  /// (`?reel=<id>`). Back returns to where it was opened.
  static const addVideos = '/add-videos';

  /// Add videos' video grid, above the folder list: one folder of one volume
  /// ([addVideosVolumeParameter], [addVideosPathParameter]; no path is the
  /// volume's root), for the target in [addVideosReelParameter].
  static const addVideosFolder = '$addVideos/folder';

  /// The name of the target reel's id in an Add videos location; none means
  /// To tag.
  static const addVideosReelParameter = 'reel';

  /// The name of the folder's volume in the grid's location.
  static const addVideosVolumeParameter = 'volume';

  /// The name of the folder's relative path in the grid's location.
  static const addVideosPathParameter = 'path';

  /// The folder list's location for To tag, or for reel [reelId].
  static String addVideosTo({int? reelId}) => Uri(
    path: addVideos,
    queryParameters: reelId == null
        ? null
        : {addVideosReelParameter: '$reelId'},
  ).toString();

  /// The grid's location for the folder [relativePath] of volume
  /// [volumeName], for To tag or reel [reelId]. The path travels encoded, so
  /// any folder name works. Never log it (D-10).
  static String addVideosFolderOf(
    String volumeName,
    String relativePath, {
    int? reelId,
  }) => Uri(
    path: addVideosFolder,
    queryParameters: {
      addVideosVolumeParameter: volumeName,
      addVideosPathParameter: relativePath,
      if (reelId != null) addVideosReelParameter: '$reelId',
    },
  ).toString();
}
