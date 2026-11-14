import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/editors/views/mark_status_dialog.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids, the editor's enum name and error types only, never a reel or folder
// name (D-10).
final Logger _log = Logger('doneEditing');

/// How long after Done editing "Mark {name} as Published?" is offered
/// (`app.js`: `confirmDoneEditing`, 900 ms): the snack is read first.
// style-check: allow a wait before a question, not motion
const Duration publishedOfferDelay = Duration(milliseconds: 900);

/// The reels whose Done editing is being asked or run, per app (container):
/// a second call while one runs (a double tap, the reminder's tap while the
/// banner's dialog is open) does nothing.
final Expando<Set<int>> _asking = Expando('doneEditing');

/// Asks Done editing for reel [reelId] (D-128) and runs it on yes.
///
/// The question depends on the session, read once when it is asked:
///
/// - **With copies** in the reel's folder: "Have you exported your video?",
///   for VN "Once the copies are deleted, the VN project for **{name}** can't
///   be edited any more. This frees {size}.", for CapCut and Instagram Edits
///   "Once the copies are deleted, clips you added to your {editor} project
///   from the folder may show as missing. This frees {size}.", then "Your
///   original clips are safe in your gallery.", **Not yet** and **Delete
///   copies**. Done: "Copies deleted · {size} freed" (the bytes the delete
///   freed), plus a sentence when the guard left files in the folder that
///   were no longer TakeTray's (`DoneEditingResult.leftBehind`).
/// - **Without copies** (CapCut or Edits sent the originals; a VN folder
///   whose copies were all deleted outside TakeTray): "Done editing {name}?",
///   "TakeTray stops showing which clips are in your {editor} project.
///   Nothing is deleted.", **Not yet** and **Done editing**. Done: "Done
///   editing {name}".
///
/// Then, after [publishedOfferDelay], "Mark {name} as Published?" unless
/// [suggestPublished] is false (the storage screen, Task 13) or the reel is
/// Published already (`showMarkStatusDialogIn` checks when it is due). The
/// wait and the question outlive the page: they use the root navigator and
/// the container, never [ref] (D-126).
///
/// **Any** error of `EditSessionService.doneEditing` (copies it could not
/// delete, a copy job not cleared yet, the bridge) says "Couldn't delete the
/// copies. Try again." ("Something went wrong. Try again." when there were
/// no copies to delete); the session stays, so the banner does, and a retry
/// works (D-123). Nothing is asked for a reel with no session, a reel that is
/// gone, or a reel whose copy job runs (Done editing would refuse it; with
/// [sayWhenCopying] a snack says "Copying is still running. Try again when it
/// finishes." for that last case, the VN copies screen's Delete). One
/// question per reel at a time, and one Done editing however often its
/// button is tapped.
Future<void> showDoneEditingDialog(
  BuildContext context,
  WidgetRef ref,
  int reelId, {
  bool suggestPublished = true,
  bool sayWhenCopying = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final asking = _asking[container] ??= <int>{};
  if (!asking.add(reelId)) return;
  final NavigatorState? navigator;
  try {
    navigator = await _askAndRun(context, container, reelId, sayWhenCopying);
  } finally {
    asking.remove(reelId);
  }
  if (navigator == null || !suggestPublished) return;
  await Future<void>.delayed(publishedOfferDelay);
  try {
    // The navigator's own context has no navigator above it; the overlay is
    // below it.
    final overlay = navigator.overlay;
    if (!navigator.mounted || overlay == null) return;
    await showMarkStatusDialogIn(
      overlay.context,
      container,
      reelId,
      ReelStatus.published,
    );
  } on Object catch (error) {
    _log.warning('The Published offer failed: ${error.runtimeType}');
  }
}

/// Asks and, on yes, runs Done editing; the app's root navigator when it was
/// done, null when it was not.
Future<NavigatorState?> _askAndRun(
  BuildContext context,
  ProviderContainer container,
  int reelId,
  bool sayWhenCopying,
) async {
  // Looked up now: the page that asked may be gone when the delete ends.
  final l10n = AppLocalizations.of(context);
  final snacks = ReelSnacks.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  // The copies are checked first (on the service's queue, behind the page's
  // own check), so the size asked about is of the copies still on the phone.
  // A failing check is logged and the recorded size is used (T11-m3).
  try {
    await container.read(editSessionServiceProvider).verifyCopies(reelId);
  } on Object catch (error) {
    _log.warning('Checking the copies failed: ${error.runtimeType}');
  }
  final EditState? edit;
  final Reel? reel;
  try {
    edit = await container
        .read(editSessionsRepositoryProvider)
        .editState(reelId);
    reel = await container.read(reelsRepositoryProvider).getById(reelId);
  } on Object catch (error) {
    _log.warning('Reading reel $reelId failed: ${error.runtimeType}');
    return null;
  }
  if (edit == null || reel == null || !context.mounted) return null;
  if (await _copying(container, reelId)) {
    // A button that was tapped should not seem dead: the copies screen asks
    // for a snack, the reel's page has a banner that already says it.
    if (sayWhenCopying) snacks.show(l10n.copyStillRunning, done: false);
    return null;
  }
  if (!context.mounted) return null;

  final editor = edit.session.editor;
  final copies = edit.copies.length;
  final size = byteSizeText(
    l10n,
    edit.copies.fold(0, (sum, c) => sum + c.sizeBytes),
  );
  final confirmed = await showTtDialog<bool>(
    context,
    icon: copies > 0 ? Symbols.folder_delete_rounded : Symbols.task_alt_rounded,
    title: copies > 0
        ? l10n.doneEditingExportedTitle
        : l10n.doneEditingTitle(reel.name),
    body: copies > 0
        ? null
        : l10n.doneEditingNoCopiesBody(editorName(l10n, editor)),
    content: copies > 0
        ? _CopiesBody(
            text: editor == EditorApp.vn
                ? l10n.doneEditingVnBody(boldMark(reel.name), size)
                : l10n.doneEditingCopiesBody(editorName(l10n, editor), size),
            safe: l10n.doneEditingSafe,
          )
        : null,
    actions: [
      TtDialogAction(false, l10n.doneEditingNotYet),
      if (copies > 0)
        TtDialogAction(true, l10n.doneEditingDeleteCopies, destructive: true)
      else
        TtDialogAction(true, l10n.reelDoneEditing),
    ],
  );
  if (confirmed != true) return null;

  final DoneEditingResult result;
  try {
    result = await container
        .read(editSessionServiceProvider)
        .doneEditing(reelId);
  } on Object catch (error) {
    _log.warning(
      'Done editing reel $reelId (${editor.name}) failed: '
      '${error.runtimeType}',
    );
    snacks.show(
      copies > 0 ? l10n.copiesNotDeleted : l10n.reelActionFailed,
      done: false,
    );
    return null;
  }
  final freed = byteSizeText(l10n, result.freedBytes);
  snacks.show(
    copies == 0
        ? l10n.doneEditingSnack(reel.name)
        : result.leftBehind > 0
        ? l10n.doneEditingFreedLeftSnack(freed, result.leftBehind)
        : l10n.doneEditingFreedSnack(freed),
  );
  return navigator;
}

/// Whether a copy job of reel [reelId] runs: the job the app follows, or,
/// when it follows none yet (a page opened by the reminder before the
/// engine was read), the engine's own. A failing read says no: Done editing
/// itself refuses a running job, and that is told.
Future<bool> _copying(ProviderContainer container, int reelId) async {
  final followed = container.read(copyJobControllerProvider);
  if (followed != null) return runningCopyJobOf(followed, reelId) != null;
  try {
    final engine = await container.read(copyBridgeProvider).current();
    return runningCopyJobOf(engine, reelId) != null;
  } on Object catch (error) {
    _log.warning('Reading the copy job failed: ${error.runtimeType}');
    return false;
  }
}

/// The question's body with copies: [text] (the reel's name in bold), then
/// the reassurance [safe].
class _CopiesBody extends StatelessWidget {
  const _CopiesBody({required this.text, required this.safe});

  final String text;
  final String safe;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TtMetrics.dialogBodyGap,
      children: [
        // As `TtDialog`'s own body, with bold parts.
        Text.rich(
          boldSpans(text),
          style: tt.text.material.bodyMedium!.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        TtDialogNote(text: safe),
      ],
    );
  }
}
