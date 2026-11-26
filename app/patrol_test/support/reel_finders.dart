import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'player_finders.dart' show canBeTapped, tapTarget;
import 'waiting.dart';

/// Finders for the reel, editor and references flows (D-161, D-197) that a
/// Patrol tap or wait can rely on, on the phone as in a widget test
/// (`reel_finders_test.dart`).

/// The app's own words, in English (the flows run with the phone in English).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// The header's **New** pill on Home: the `TtHeaderPill` read "New reel"
/// (`reelsNewReel`, its screen-reader name), the way in once Home has reels
/// (D-186; the FAB is gone).
///
/// Not by the words alone: on an empty Home the empty state's own **New
/// reel** button says the same, and a finder by its label would find both.
/// The pill's visible text is only "New" (`reelsNew`).
Finder newReelButton() => find.byWidgetPredicate(
  (w) => w is TtHeaderPill && w.semanticLabel == _l10n.reelsNewReel,
  description: 'the header pill "${_l10n.reelsNewReel}"',
);

/// The Home card of the reel named [reelName] (the `TtReelCard` itself, which
/// is one button; not its text, which no tap needs).
Finder reelCardOf(String reelName) => find.byWidgetPredicate(
  (w) => w is TtReelCard && w.name == reelName,
  description: 'the reel card of "$reelName"',
);

/// The action of the reel page's selection dock (D-190) whose words under the
/// icon are [label]: Share, Add to, Move or Remove (`selectionDockShare`, …).
///
/// The action's own button (its ink), so a tap lands on the whole 56 dp area,
/// not on the small text. Not the tag player's `dockAction` of
/// `player_finders.dart` (a different dock): a file imports one of the two.
Finder dockAction(String label) => find.descendant(
  of: find.byType(TtSelectionDock),
  matching: find.ancestor(
    of: find.descendant(
      of: find.byType(TtSelectionDock),
      matching: find.text(label),
    ),
    matching: find.byType(InkWell),
  ),
);

/// The selection dock's **Edit {n} clips** button. Not there while the reel is
/// being edited (the dock has a note instead, R1) or before a clip is chosen
/// (the dock itself is not there).
Finder dockEdit() => find.descendant(
  of: find.byType(TtSelectionDock),
  matching: find.byType(FilledButton),
);

/// [finder] is a button that is on (its `onPressed` is set). A disabled
/// button can still be hit by a tap, which then does nothing, so `canBeTapped`
/// does not tell the two apart. False when nothing is found or the widget is
/// no button.
bool isEnabledButton(Finder finder) {
  final found = finder.evaluate();
  if (found.isEmpty) return false;
  final widget = found.first.widget;
  return widget is ButtonStyleButton && widget.enabled;
}

/// A tap on [finder]'s first match would land and do something: it can be hit,
/// and, when [enabled] is true, it is a button that is on (the dock's Edit is
/// off until the clips and the session are known, and a tap on it is lost).
bool readyToTap(Finder finder, {bool enabled = false}) =>
    canBeTapped(finder) && (!enabled || isEnabledButton(finder));

/// A raw tap, then one frame, on [finder]'s first match once it is there, can
/// be hit and has stopped moving: the dock slides up over its first frames, a
/// sheet slides in, and on the phone the frames run between the finger's down
/// and up, so a tap on a target that is still moving is lost (S24, 2026-11-25,
/// the All reels sheet). Waits on conditions, not on time.
///
/// With [enabled] it also waits for a button to be on (`readyToTap`): a tap on
/// a disabled one does nothing, and the wait that follows then runs out.
Future<void> tapWhenStill(
  PatrolIntegrationTester $,
  Finder finder, {
  bool enabled = false,
}) async {
  await waitFor(
    $,
    () => readyToTap(finder, enabled: enabled),
    what: 'a tap target that can be hit${enabled ? ' and is on' : ''}: $finder',
  );
  await waitForStill(
    $,
    () => [tapTarget($.tester, finder)],
    what: 'the tap target to stop moving: $finder',
  );
  await $.tester.tap(finder.first);
  await $.tester.pump();
}

/// The page of the reel [reelId], by its id.
///
/// Not by the reel's name: opened at its References (`?refs=1`, D-196), the
/// page scrolls its header, with the name, off the screen, and a finder skips
/// a sliver that is off the screen.
/// [reelName] is only for the description.
Finder reelPageOf(int reelId, String reelName) => find.byWidgetPredicate(
  (w) => w is ReelDetailScreen && w.reelId == reelId,
  description: 'the page of "$reelName"',
);
