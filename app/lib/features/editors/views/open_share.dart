import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

// Counts and error types only (D-10).
final Logger _log = Logger('openShare');

/// Opens Android's share menu for the clips [clipIds] (the viewer's **Share**,
/// the reel page's ⋮ **Share**, the editor sheet's **Other app…**; D-126).
///
/// The chooser's title is "Share video" or "Share {n} videos" (n is how many
/// were asked for). The service shares the clips that are still on the phone,
/// in shooting order, and makes no editing session (R5). When none is left
/// the snack says "These clips are missing from your phone."; a failure,
/// including a share menu that did not open, says "Something went wrong. Try
/// again.". Nothing happens for an empty list.
///
/// Everything is looked up before the first `await`, so the caller may be
/// gone when it ends.
Future<void> openShare(
  BuildContext context,
  WidgetRef ref,
  List<int> clipIds,
) => shareClips(
  ReelSnacks.of(context),
  AppLocalizations.of(context),
  ref.read(editSessionServiceProvider),
  clipIds,
);

/// [openShare] with everything already looked up (the editor sheet uses it
/// after it has closed).
Future<void> shareClips(
  ReelSnacks snacks,
  AppLocalizations l10n,
  EditSessionService service,
  List<int> clipIds,
) async {
  if (clipIds.isEmpty) return;
  try {
    final opened = await service.share(
      clipIds,
      l10n.shareChooserTitle(clipIds.length),
    );
    if (!opened) snacks.show(l10n.shareClipsMissing, done: false);
  } on Object catch (error) {
    _log.warning(
      'Sharing ${clipIds.length} clips failed: ${error.runtimeType}',
    );
    snacks.show(l10n.reelActionFailed, done: false);
  }
}
