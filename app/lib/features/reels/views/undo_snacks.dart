import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Error types only, never a message (D-10).
final Logger _log = Logger('undoSnacks');

/// Snacks for the reel screens, shown on the app's **root** messenger (D-85),
/// so one outlives the screen that raised it: a reel's delete goes back to
/// Reels, and its Undo is still there.
///
/// Made from a live context with [ReelSnacks.of], which looks up everything it
/// needs then (the messenger, the container, the words). After that it works
/// without the context: a sheet that has closed, or a screen that has popped,
/// can still use it.
class ReelSnacks {
  new _(this._messenger, this._container, this._l10n, this._persistActions);

  /// Looks up the root messenger and the rest for [context].
  factory of(BuildContext context) => ReelSnacks._(
    rootMessengerOf(context),
    ProviderScope.containerOf(context, listen: false),
    AppLocalizations.of(context),
    MediaQuery.accessibleNavigationOf(context),
  );

  final ScaffoldMessengerState _messenger;
  final ProviderContainer _container;
  final AppLocalizations _l10n;
  final bool _persistActions;

  /// A plain snack saying [message], with a check mark when [done].
  /// Null when the app is gone and there is nowhere to show it.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message, {
    bool done = true,
  }) {
    if (!_messenger.mounted) return null;
    return showTtSnackOn(
      _messenger,
      message: message,
      icon: done ? Symbols.check_circle_rounded : null,
    );
  }

  /// A snack saying [message] with **Undo**, which puts back what [record]
  /// changed. If that fails, "Couldn't undo. Try again." is shown. Null when
  /// the app is gone.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndo(
    String message,
    UndoRecord record,
  ) => showUndoAll(message, [record]);

  /// A snack saying [message] with **Undo**, which puts back what every one
  /// of [records] changed, last to first (an add to three reels is three
  /// records). Every record is tried even if one fails, and "Couldn't undo.
  /// Try again." is shown if any did. Null when the app is gone.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndoAll(
    String message,
    List<UndoRecord> records,
  ) {
    if (!_messenger.mounted) return null;
    return showTtSnackOn(
      _messenger,
      message: message,
      icon: Symbols.check_circle_rounded,
      actionLabel: _l10n.undo,
      onAction: () => unawaited(_undo(records)),
      persist: _persistActions,
    );
  }

  Future<void> _undo(List<UndoRecord> records) async {
    var failed = false;
    for (final record in records.reversed) {
      try {
        await _container.read(reelsRepositoryProvider).undo(record);
      } on Object catch (error) {
        failed = true;
        _log.warning('Undo failed: ${error.runtimeType}');
      }
    }
    if (failed) show(_l10n.undoFailed, done: false);
  }
}

/// Shows [message] with an **Undo** button for [record] on the root messenger
/// (D-85). The snack stays when the screen that called this is popped, and
/// Undo works until the snack closes.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndoSnack(
  BuildContext context,
  String message,
  UndoRecord record,
) => ReelSnacks.of(context).showUndo(message, record);
