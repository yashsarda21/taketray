import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/view_models/reel_actions.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids and types only, never a reel name (D-10).
final Logger _log = Logger('deleteReel');

/// Asks "Delete {name}?" (`screens.js`: `dialogs.deleteReel`, without the VN
/// line, which is Phase 8). On **Delete reel**:
///
/// 1. the reel is deleted (once, however often the button is tapped);
/// 2. "{name} deleted" is shown with **Undo**, on the root messenger, so it
///    stays after the next step;
/// 3. the app goes to Reels (`Routes.reels`), where the reel list is.
///
/// Undo puts the reel back with its clips (D-84). **Cancel**, or a tap
/// outside, does nothing. If the delete fails, "Something went wrong. Try
/// again." is shown and the app stays where it is.
///
/// The snack and the router are looked up before anything is awaited, so the
/// screen that opened the dialog may be gone by the time the delete ends.
Future<void> showDeleteReelDialog(BuildContext context, Reel reel) async {
  final l10n = AppLocalizations.of(context);
  final snacks = ReelSnacks.of(context);
  final router = GoRouter.of(context);
  final actions = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(reelActionsProvider);
  final confirmed = await showTtDialog<bool>(
    context,
    icon: Symbols.delete_rounded,
    title: l10n.deleteReelTitle(reel.name),
    content: TtDialogNote(text: l10n.deleteReelSafe),
    actions: [
      TtDialogAction(false, l10n.cancel),
      TtDialogAction(true, l10n.deleteReelConfirm, destructive: true),
    ],
  );
  if (confirmed != true) return;
  try {
    final record = await actions.confirmDelete(reel.id);
    // A reel that was already gone has nothing to undo, so nothing to say.
    if (!record.isEmpty) {
      snacks.showUndo(l10n.reelDeletedSnack(reel.name), record);
    }
    router.go(Routes.reels);
  } on Object catch (error) {
    _log.warning('Deleting reel ${reel.id} failed: ${error.runtimeType}');
    snacks.show(l10n.reelActionFailed, done: false);
  }
}
