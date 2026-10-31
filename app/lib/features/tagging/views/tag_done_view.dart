import 'package:flutter/material.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// "All done!" (`routes['player-done']`, D-97): the end of the tag player.
///
/// "{n} clips sorted. Nice work." counts every clip of the session that has
/// left To tag (also by someone else); the rows are what **this** session did:
/// one for each reel, "{name}" and "+{n}", in the order the reels were first
/// used, and "Skipped" with its count when any clip was skipped. A reel that
/// was deleted meanwhile has no name and no row. **See your reels** goes to
/// the Reels tab, **Back to To tag** to To tag.
///
/// Always dark, as the player (`TtTagDone` is on `TtVideoSurface`); it adds
/// the room for the status bar, which the component leaves to the screen.
class TagDoneView extends StatelessWidget {
  const new({
    required this.session,
    required this.reelNames,
    required this.onSeeReels,
    required this.onBack,
    super.key,
  });

  /// What the session did.
  final TagSessionState session;

  /// The names of the reels that exist, by id.
  final Map<int, String> reelNames;

  /// **See your reels**.
  final VoidCallback onSeeReels;

  /// **Back to To tag**.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = [
      for (final MapEntry(key: id, value: count)
          in session.taggedPerReel.entries)
        if (reelNames[id] != null)
          TtTagDoneRow(name: reelNames[id]!, count: l10n.tagDoneAdded(count)),
      if (session.skipped > 0)
        TtTagDoneRow(
          name: l10n.tagDoneSkippedRow,
          count: l10n.tagDoneSkippedCount(session.skipped),
        ),
    ];
    return SafeArea(
      child: TtTagDone(
        title: l10n.tagDoneTitle,
        body: l10n.tagDoneBody(session.sortedCount),
        rows: rows,
        primaryLabel: l10n.tagDoneSeeReels,
        onPrimary: onSeeReels,
        secondaryLabel: l10n.tagDoneBack,
        onSecondary: onBack,
      ),
    );
  }
}
