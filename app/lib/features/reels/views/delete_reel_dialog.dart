import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/view_models/reel_actions.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids and types only, never a reel name (D-10).
final Logger _log = Logger('deleteReel');

/// Asks "Delete {name}?" (`screens.js`: `dialogs.deleteReel`). While the reel
/// is being edited and its folder holds copies, one more line says they go
/// too (R8, D-128): "The {n} VN copies ({size}) will also be deleted, and the
/// VN project can't be edited after that." for VN, "The {n} copies in
/// Movies/TakeTray/{folder} ({size}) will also be deleted." for CapCut and
/// Edits. On **Delete reel**:
///
/// 1. the reel is deleted (once, however often the button is tapped): its
///    copy job is cancelled, its copies deleted and its session ended first
///    (`ReelActions.confirmDelete`);
/// 2. "{name} deleted" is shown with **Undo**, on the root messenger, so it
///    stays after the next step;
/// 3. the app goes to Reels (`Routes.reels`), where the reel list is.
///
/// The dialog stays open while the delete runs (**Cancel**, a tap outside and
/// Back wait). When the copies cannot be deleted nothing is deleted, the
/// dialog stays and says "Couldn't delete the copies. Try again." under its
/// text, and **Delete reel** tries again. Undo puts the reel back with its
/// clips and without its session (D-84, R8). **Cancel**, or a tap outside,
/// does nothing. If the delete fails otherwise, the dialog closes, "Something
/// went wrong. Try again." is shown and the app stays where it is.
///
/// The snack and the router are looked up before anything is awaited, so the
/// screen that opened the dialog may be gone by the time the delete ends.
Future<void> showDeleteReelDialog(BuildContext context, Reel reel) async {
  final l10n = AppLocalizations.of(context);
  final snacks = ReelSnacks.of(context);
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final actions = container.read(reelActionsProvider);
  EditState? edit;
  try {
    edit = await container
        .read(editSessionsRepositoryProvider)
        .editState(reel.id);
  } on Object catch (error) {
    // The line is only a warning: the delete still deletes the copies.
    _log.warning('Reading reel ${reel.id} failed: ${error.runtimeType}');
  }
  if (!context.mounted) return;
  final run = _DeleteRun(reel.id, actions);
  final confirmed = await showTtDialog<bool>(
    context,
    icon: Symbols.delete_rounded,
    title: l10n.deleteReelTitle(reel.name),
    content: _DeleteBody(
      run: run,
      safe: l10n.deleteReelSafe,
      copies: _copiesLine(l10n, edit),
    ),
    actions: [
      TtDialogAction(false, l10n.cancel),
      TtDialogAction(true, l10n.deleteReelConfirm, destructive: true),
    ],
  );
  // A dialog taken away from outside (its route removed) completes before a
  // delete that was running: wait for that delete, then act on its result
  // (T11-m6).
  await run.inFlight;
  final record = run.record;
  if (record != null) {
    // A reel that was already gone has nothing to undo, so nothing to say.
    if (!record.isEmpty) {
      snacks.showUndo(l10n.reelDeletedSnack(reel.name), record);
    }
    router.go(Routes.reels);
  } else if (run.failed) {
    snacks.show(l10n.reelActionFailed, done: false);
  } else if (confirmed == null && run.copiesFailed) {
    snacks.show(l10n.copiesNotDeleted, done: false);
  }
}

/// The copies line of the dialog, or null when the folder holds none.
String? _copiesLine(AppLocalizations l10n, EditState? edit) {
  if (edit == null || edit.copies.isEmpty) return null;
  final size = byteSizeText(
    l10n,
    edit.copies.fold(0, (sum, c) => sum + c.sizeBytes),
  );
  return edit.session.editor == EditorApp.vn
      ? l10n.deleteReelVnCopies(edit.copies.length, size)
      : l10n.deleteReelFolderCopies(
          edit.copies.length,
          edit.session.folderName,
          size,
        );
}

/// The delete of one reel from the dialog: what it gave back, and whether it
/// failed in a way that closes the dialog.
class _DeleteRun {
  _DeleteRun(this.reelId, this.actions);

  final int reelId;
  final ReelActions actions;
  DeleteReelUndo? record;
  bool failed = false;

  /// The last try failed because the copies could not be deleted.
  bool copiesFailed = false;

  /// The delete that is running, or null when none ran yet (it completes
  /// whether or not the dialog is still there).
  Future<void>? inFlight;
}

/// The dialog's text, and the hand on its buttons: a `PopScope` turns each
/// tap (and Back, and a tap outside) into a decision of this widget, so the
/// dialog stays open while the delete runs and when the copies could not be
/// deleted.
class _DeleteBody extends StatefulWidget {
  const _DeleteBody({required this.run, required this.safe, this.copies});

  final _DeleteRun run;
  final String safe;
  final String? copies;

  @override
  State<_DeleteBody> createState() => _DeleteBodyState();
}

class _DeleteBodyState extends State<_DeleteBody> {
  bool _busy = false;
  bool _copiesFailed = false;

  void _onPop(bool didPop, Object? result) {
    if (didPop || _busy) return;
    if (result == true) {
      unawaited(_delete());
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _delete() async {
    final run = widget.run;
    setState(() {
      _busy = true;
      _copiesFailed = false;
    });
    final done = Completer<void>();
    run.inFlight = done.future;
    run.copiesFailed = false;
    try {
      run.record = await run.actions.confirmDelete(run.reelId);
    } on CopiesNotDeleted {
      // Nothing was deleted (R8): the dialog stays to try again.
      run.copiesFailed = true;
      if (mounted) {
        setState(() {
          _busy = false;
          _copiesFailed = true;
        });
      }
      return;
    } on Object catch (error) {
      _log.warning('Deleting reel ${run.reelId} failed: ${error.runtimeType}');
      run.failed = true;
    } finally {
      done.complete();
    }
    if (mounted) Navigator.of(context).pop(run.record != null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final copies = widget.copies;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TtMetrics.dialogBodyGap,
        children: [
          TtDialogNote(text: widget.safe),
          if (copies != null)
            Text(
              copies,
              style: tt.text.material.bodyMedium!.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          if (_copiesFailed)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.copiesNotDeleted,
                style: tt.text.material.bodyMedium!.copyWith(
                  color: context.scheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
