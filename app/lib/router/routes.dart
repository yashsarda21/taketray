/// Top-level locations of the three tabs.
abstract final class Routes {
  static const reels = '/reels';
  static const toTag = '/to-tag';
  static const settings = '/settings';

  /// The name of the reel id in a reel's location.
  static const reelIdParameter = 'id';

  /// The location of reel [id]'s page, under the Reels tab.
  static String reel(int id) => '$reels/$id';
}
