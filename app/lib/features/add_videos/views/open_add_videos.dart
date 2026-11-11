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
/// list (or one sheet) even when the access read is slow: it passes
/// `openSlow`'s [pushing], which this calls just before it opens either.
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

  Future<void> announce(AddResult result) async {
    // The reel's name is read now: the add is over, and it may be gone.
    final name = result.added == 0
        ? null
        : reelId == null
        ? l10n.navToTag
        : (await reels.getById(reelId))?.name;
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
    pushing?.call();
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
