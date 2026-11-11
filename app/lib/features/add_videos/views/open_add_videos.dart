import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/add_videos/views/manual_pick_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray/router/routes.dart';

// Counts, the target kind and error types only (D-10).
final Logger _log = Logger('addVideos');

/// **Add videos** on To tag and on a reel's page (D-111, D-114): adds videos
/// the user picks to [target].
///
/// It reads the access now (not the banner's last answer):
/// - **full:** opens the folder list (`Routes.addVideos`), above the tab
///   shell. When the grid adds videos, both screens close, back to the page
///   that called this. Back, or leaving because access was lost or the reel
///   was deleted, shows nothing.
/// - **limited, denied, or a read that failed:** Manual mode, the sheet "Pick
///   videos yourself" (`showManualPickSheet`), which sends the user to
///   Android's photo picker (it needs no permission).
///
/// Either way an add ends with one snack on the root messenger (so it still
/// works after switching tabs), whatever the route:
/// "{n} videos added to {target}" with **Undo**; "Already added" when every
/// video was already there; and, when some could not be added,
/// "Couldn't add {n} videos." under it. A failed pick or add says "Couldn't
/// add videos. Try again.".
///
/// The caller opens it through `OpenOnce.openSlow`, so a double tap opens one
/// list (or one sheet) even when the access read is slow. It passes
/// `openSlow`'s [pushing], which this calls just before it pushes the folder
/// list. The sheet does not call it: taps stay shut out until the sheet
/// closes.
Future<void> openAddVideos(
  BuildContext context,
  WidgetRef ref,
  AddTarget target, {
  VoidCallback? pushing,
}) async {
  // Everything the end needs is read now: the caller may be gone by then.
  final bridge = ref.read(mediaBridgeProvider);
  final service = ref.read(addVideosServiceProvider);
  final reels = ref.read(reelsRepositoryProvider);
  final snacks = ReelSnacks.of(context);
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);

  MediaAccess? access;
  try {
    access = await bridge.accessReport();
  } on Object catch (error) {
    _log.warning('Reading the access failed: ${error.runtimeType}');
  }

  final reelId = switch (target) {
    AddToToTag() => null,
    AddToReel(:final reelId) => reelId,
  };

  /// What the snack calls the target. The add is over and kept, so a reel
  /// whose name cannot be read is called "this reel": the snack (and its Undo)
  /// still show. A reel that is gone has no name (null).
  Future<String?> targetName() async {
    if (reelId == null) return l10n.navToTag;
    try {
      return (await reels.getById(reelId))?.name;
    } on Object catch (error) {
      _log.warning('Reading the reel name failed: ${error.runtimeType}');
      return l10n.pickerThisReel;
    }
  }

  Future<void> announce(AddResult result) async {
    // The reel's name is read now: the add is over, and it may be gone.
    final name = result.added == 0 ? null : await targetName();
    final notKept = result.notKept > 0
        ? l10n.addVideosNotKept(result.notKept)
        : null;
    if (result.added == 0) {
      // Nothing new: "Already added" when videos were there, and what could
      // not be added; when both are zero, the old plain answer.
      final lines = [
        if (result.alreadyThere > 0 || notKept == null)
          l10n.addVideosAlreadyAdded,
        ?notKept,
      ];
      snacks.show(lines.join('\n'), done: false);
      return;
    }
    // The reel was deleted right after the add: there is nothing to name.
    if (name == null) return;
    snacks.showUndoAll(
      [l10n.addVideosAddedSnack(result.added, name), ?notKept].join('\n'),
      const [],
      undo: () => service.undo(result),
    );
  }

  if (access?.level != MediaAccessLevel.full) {
    _log.info('Add videos without full access: Manual mode');
    // The caller may be gone after a slow read: there is no sheet to show.
    if (!context.mounted) return;
    // No `pushing` here: `openSlow` holds the taps until this future ends,
    // that is until the sheet closes, and the sheet covers the page and its
    // button meanwhile. A window from when it opened would only shut out a
    // tap after it closed.
    await showManualPickSheet(
      context,
      target: target,
      onOutcome: (outcome) {
        switch (outcome) {
          case PickedAdded(:final result):
            unawaited(announce(result));
          case PickFailed():
            snacks.show(l10n.addVideosFailed, done: false);
        }
      },
    );
    return;
  }

  final route = router.push<AddResult>(Routes.addVideosTo(reelId: reelId));
  pushing?.call();
  final result = await route;
  if (result == null) return;
  await announce(result);
}
