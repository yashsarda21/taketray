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
/// - [LaunchAction.openReel]: the share screen's Open reel (D-165) opens the
///   reel's References ([Routes.reelReferences]) when the reel still exists;
///   the same cases as Done editing open Reels.
Future<String> routeFor(Launch launch, ReelExists reelExists) async {
  switch (launch.action) {
    case LaunchAction.toTag:
      return Routes.toTag;
    case LaunchAction.reels:
      return Routes.reels;
    case LaunchAction.doneEditing:
      return await _reelRoute(launch, reelExists, Routes.reelDoneEditing);
    case LaunchAction.openReel:
      return await _reelRoute(launch, reelExists, Routes.reelReferences);
  }
}

/// [page] of the launch's reel when it still exists, else Reels.
Future<String> _reelRoute(
  Launch launch,
  ReelExists reelExists,
  String Function(int id) page,
) async {
  final id = launch.reelId;
  if (id == null || id < 1) return Routes.reels;
  try {
    if (await reelExists(id)) return page(id);
  } on Object catch (e) {
    // The type only (D-10).
    _log.warning('Looking up the reel of a tap failed: ${e.runtimeType}');
  }
  return Routes.reels;
}

/// Opens taps one after the other, in the order they came (D-124): finding out
/// whether a reel exists takes a moment, and a later tap must not be
/// overtaken by an earlier one.
class LaunchQueue {
  /// The function given handles one tap.
  LaunchQueue(this._open);

  final Future<void> Function(Launch launch) _open;
  Future<void> _tail = Future<void>.value();

  /// Queues [launch] behind the taps already waiting. A tap that fails is
  /// logged by type only (D-10) and never blocks the ones after it.
  void add(Launch launch) {
    _tail = _tail.then((_) async {
      try {
        await _open(launch);
      } on Object catch (e) {
        _log.warning('Opening a tap failed: ${e.runtimeType}');
      }
    });
  }
}
