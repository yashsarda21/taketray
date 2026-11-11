import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
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
///   that called this, and the snack "{n} videos added to {target}" offers
///   **Undo** (`AddVideosService.undo`, on the root messenger, so it still
///   works after switching tabs). An add that found every video already
///   there says "Already added". Back, or leaving because access was lost or
///   the reel was deleted, shows nothing.
/// - **limited, denied, or a read that failed:** Manual mode, the photo
///   picker, which Task 6 adds here; for now nothing opens.
///
/// The caller opens it through an `OpenOnce`, so a double tap opens one list.
Future<void> openAddVideos(
  BuildContext context,
  WidgetRef ref,
  AddTarget target,
) async {
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
  if (access?.level != MediaAccessLevel.full) {
    _log.info('Add videos without full access: Manual mode is Task 6');
    return;
  }

  final reelId = switch (target) {
    AddToToTag() => null,
    AddToReel(:final reelId) => reelId,
  };
  final result = await router.push<AddResult>(
    Routes.addVideosTo(reelId: reelId),
  );
  if (result == null) return;
  if (result.added == 0) {
    snacks.show(l10n.addVideosAlreadyAdded, done: false);
    return;
  }
  final name = reelId == null
      ? l10n.navToTag
      : (await reels.getById(reelId))?.name;
  // The reel was deleted right after the add: there is nothing to name.
  if (name == null) return;
  snacks.showUndoAll(
    l10n.addVideosAddedSnack(result.added, name),
    const [],
    undo: () => service.undo(result),
  );
}
