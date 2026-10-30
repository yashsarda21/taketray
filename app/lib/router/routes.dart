/// Top-level locations of the three tabs.
abstract final class Routes {
  static const reels = '/reels';
  static const toTag = '/to-tag';
  static const settings = '/settings';

  /// The name of the reel id in a reel's location.
  static const reelIdParameter = 'id';

  /// The location of reel [id]'s page, under the Reels tab.
  static String reel(int id) => '$reels/$id';

  /// The name of the clip id in a clip's location.
  static const clipIdParameter = 'clipId';

  /// The location of the viewer on clip [clipId] of reel [reelId], above the
  /// reel's page (`/reels/:reelId/clip/:clipId`).
  static String clip(int reelId, int clipId) => '${reel(reelId)}/clip/$clipId';
}
