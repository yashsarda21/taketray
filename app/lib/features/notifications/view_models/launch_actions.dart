import 'package:logging/logging.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';

final Logger _log = Logger('launchActions');

/// Whether reel [id] still exists.
typedef ReelExists = Future<bool> Function(int id);

/// The screen a notification tap opens (D-107, D-124).
///
/// An allow-list: Android sends a [Launch], never a location, so no other app
/// can make TakeTray open an arbitrary route (D-101). The reel id is the only
/// payload and is checked here.
///
/// - [LaunchAction.toTag]: the new-clips notification (its body and Tag now)
///   and the evening reminder open To tag.
/// - [LaunchAction.reels]: the "Still shooting?" notification opens Reels,
///   where the dialog asks (`StillShootingPromptHost`).
/// - [LaunchAction.doneEditing]: the copies reminder opens the reel's page
///   ([Routes.reelDoneEditing]) when the reel still exists; a reel that is
///   gone, an unusable id (null, zero, negative) or a failing check open
///   Reels.
Future<String> routeFor(Launch launch, ReelExists reelExists) async {
  switch (launch.action) {
    case LaunchAction.toTag:
      return Routes.toTag;
    case LaunchAction.reels:
      return Routes.reels;
    case LaunchAction.doneEditing:
      final id = launch.reelId;
      if (id == null || id < 1) return Routes.reels;
      try {
        if (await reelExists(id)) return Routes.reelDoneEditing(id);
      } on Object catch (e) {
        // The type only (D-10).
        _log.warning('Looking up the reel of a tap failed: ${e.runtimeType}');
      }
      return Routes.reels;
  }
}
