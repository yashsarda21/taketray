import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

// Error types only (D-10).
final Logger _log = Logger('removeMissing');

/// **Remove** on a missing tile in To tag and Skipped (D-116): the same
/// action, snack and **Undo** as on the reel page (D-85, D-87), for a screen
/// that mixes it in.
///
/// - Nothing is shown when there was nothing to remove (the clip was found
///   again, or is gone already); a failure says "Something went wrong. Try
///   again." and keeps the tile.
/// - A clip already being removed is left out, so a double tap writes once.
/// - The messenger and the controller's method are looked up before the
///   write, so the snack and its **Undo** work after the screen has gone.
mixin RemoveMissingClip<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Set<int> _removingMissing = {};

  /// Takes the missing clip [clipId] out of the list with [remove] (the
  /// controller's `removeMissing`, taken from the provider by the caller
  /// before this runs) and says so, with **Undo**.
  Future<void> removeMissingClip(
    int clipId,
    Future<InboxRemoveUndo> Function(int clipId) remove,
  ) async {
    if (!_removingMissing.add(clipId)) return;
    final snacks = ReelSnacks.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final record = await remove(clipId);
      if (!record.isEmpty) {
        snacks.showUndo(l10n.missingClipRemovedSnack, record);
      }
    } on Object catch (error) {
      _log.warning('Removing a missing clip failed: ${error.runtimeType}');
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _removingMissing.remove(clipId);
    }
  }
}
