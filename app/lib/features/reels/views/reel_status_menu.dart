import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/view_models/reel_actions.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Types only (D-10).
final Logger _log = Logger('reelStatusMenu');

/// The pill kind that draws [status].
TtStatusKind statusKindOf(ReelStatus status) => switch (status) {
  ReelStatus.collecting => TtStatusKind.collecting,
  ReelStatus.ready => TtStatusKind.ready,
  ReelStatus.published => TtStatusKind.published,
};

/// [status] in words: Collecting, Ready to edit or Published (D-80).
String statusName(AppLocalizations l10n, ReelStatus status) => switch (status) {
  ReelStatus.collecting => l10n.statusCollecting,
  ReelStatus.ready => l10n.statusReady,
  ReelStatus.published => l10n.statusPublished,
};

/// One line saying what [status] means.
String statusDescription(AppLocalizations l10n, ReelStatus status) =>
    switch (status) {
      ReelStatus.collecting => l10n.statusCollectingDescription,
      ReelStatus.ready => l10n.statusReadyDescription,
      ReelStatus.published => l10n.statusPublishedDescription,
    };

/// The icon of [status] (the same glyph as its pill).
IconData statusIcon(ReelStatus status) => switch (status) {
  ReelStatus.collecting => Symbols.radio_button_checked_rounded,
  ReelStatus.ready => Symbols.content_cut_rounded,
  ReelStatus.published => Symbols.check_circle_rounded,
};

/// The entries of the status menu, one per status, with [current] checked
/// (`screens.js`: `menus.status`). Reel detail passes them to
/// `TtReelHeader.statusItems` and [changeReelStatus] to `onStatusSelected`.
List<TtMenuItem<ReelStatus>> reelStatusItems(
  AppLocalizations l10n,
  ReelStatus current,
) => [
  for (final status in ReelStatus.values)
    TtMenuItem<ReelStatus>(
      status,
      statusName(l10n, status),
      icon: statusIcon(status),
      iconFilled: true,
      subtitle: statusDescription(l10n, status),
      checked: status == current,
    ),
];

/// Sets the status of [reel] and says so: "Marked as {status}", with no Undo
/// (D-80). Choosing the status the reel already has changes nothing and says
/// nothing. If the change fails, "Something went wrong. Try again." is shown.
///
/// Nothing is thrown. The snack is on the root messenger.
Future<void> changeReelStatus(
  BuildContext context,
  Reel reel,
  ReelStatus status,
) async {
  if (status == reel.status) return;
  final snacks = ReelSnacks.of(context);
  final l10n = AppLocalizations.of(context);
  final actions = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(reelActionsProvider);
  try {
    await actions.setStatus(reel.id, status);
  } on Object catch (error) {
    _log.warning('The status change failed: ${error.runtimeType}');
    snacks.show(l10n.reelActionFailed, done: false);
    return;
  }
  snacks.show(l10n.reelStatusChangedSnack(statusName(l10n, status)));
}
