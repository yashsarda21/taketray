import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/view_models/reel_actions.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids and error types only (D-10).
final Logger _log = Logger('markStatus');

/// "Mark {name} as {status}?" (`screens.js`: `dialogs.markStatus`): offers
/// the reel [reelId] a new [status] (Ready to edit after a send, Published
/// after Done editing). **Not now**, or a tap outside, changes nothing;
/// **Mark as {status}** sets it and says "Marked as {status}".
///
/// Nothing is shown when the reel is gone, already has [status], or cannot be
/// read. [ref] only keeps the usual calling shape; the work uses the app's
/// container. When the screen that asks may be gone by the time the dialog
/// is due (the 1.3 s after a send), use [showMarkStatusDialogIn] with the
/// root navigator's context.
Future<void> showMarkStatusDialog(
  BuildContext context,
  WidgetRef ref,
  int reelId,
  ReelStatus status,
) => showMarkStatusDialogIn(
  context,
  ProviderScope.containerOf(context, listen: false),
  reelId,
  status,
);

/// [showMarkStatusDialog] with the container passed in, for a caller whose
/// `WidgetRef` is gone (a `WidgetRef` cannot be used after its widget is
/// disposed). [context] must be mounted when the dialog is due.
Future<void> showMarkStatusDialogIn(
  BuildContext context,
  ProviderContainer container,
  int reelId,
  ReelStatus status,
) async {
  assert(
    status != ReelStatus.collecting,
    'Nothing is offered a Collecting status',
  );
  final l10n = AppLocalizations.of(context);
  final snacks = ReelSnacks.of(context);
  final statusText = statusName(l10n, status);
  final reel = await _readReel(container, reelId);
  if (reel == null || reel.status == status || !context.mounted) return;
  final confirmed = await showTtDialog<bool>(
    context,
    icon: statusIcon(status),
    title: l10n.markStatusTitle(reel.name, statusText),
    body: status == ReelStatus.published
        ? l10n.markStatusPublishedBody
        : l10n.markStatusReadyBody,
    actions: [
      TtDialogAction(false, l10n.markStatusNotNow),
      TtDialogAction(true, l10n.markStatusConfirm(statusText)),
    ],
  );
  if (confirmed != true) return;
  try {
    await container.read(reelActionsProvider).setStatus(reelId, status);
  } on Object catch (error) {
    _log.warning('Marking reel $reelId failed: ${error.runtimeType}');
    snacks.show(l10n.reelActionFailed, done: false);
    return;
  }
  snacks.show(l10n.reelStatusChangedSnack(statusText));
}

Future<Reel?> _readReel(ProviderContainer container, int reelId) async {
  try {
    return await container.read(reelsRepositoryProvider).getById(reelId);
  } on Object catch (error) {
    _log.warning('Reading reel $reelId failed: ${error.runtimeType}');
    return null;
  }
}
