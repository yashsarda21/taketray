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

  /// The name of the clip id in a clip's location.
  static const clipIdParameter = 'clipId';

  /// The location of the viewer on clip [clipId] of reel [reelId], above the
  /// reel's page (`/reels/:reelId/clip/:clipId`).
  static String clip(int reelId, int clipId) => '${reel(reelId)}/clip/$clipId';
}
