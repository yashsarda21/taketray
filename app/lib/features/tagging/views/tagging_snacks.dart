import 'package:taketray/features/reels/views/reel_picker_sheet.dart'
    show addedToText;
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// The snack after a tag or a skip in the tag player (D-97): "Added to
/// {names}" or "Skipped", with **Undo**.
///
/// - **Undo goes through the session** ([session].undo), not straight to the
///   repository: it puts the records back, takes back what the session
///   counted, and returns the player to that clip (owner ruling, D-91). Hold
///   the notifier from before the action: an Undo from a snack that outlives
///   the player still restores the clip (`TagSessionController.undo` is safe
///   after the player has closed, D-96).
/// - **Only the latest action offers Undo.** A new snack replaces the one
///   showing (`showTtSnackOn` hides it first), because a stale `InboxUndo`
///   can revert a row that has since gone back and forth (D-94).
/// - **It names what was tagged**, from [outcome], never from what is on
///   screen now: if the clip left To tag during the hold, the snack still
///   says where the held clip went.
void showTagOutcome({
  required ReelSnacks snacks,
  required AppLocalizations l10n,
  required TagOutcome outcome,
  required TagSessionController session,
}) {
  final message = outcome.skipped
      ? l10n.tagSkippedSnack
      : addedToText(l10n, outcome.reelNames);
  snacks.showUndoAll(
    message,
    outcome.records,
    undo: () => session.undo(outcome.records, outcome.clipId),
  );
}

/// "Something went wrong. Try again." after an action of the player failed
/// (the controller logged the type and kept the clip showing).
void showTagFailure({
  required ReelSnacks snacks,
  required AppLocalizations l10n,
}) => snacks.show(l10n.reelActionFailed, done: false);
