import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Finders for the tagging flows on the full-screen tag player (D-183) that
/// a Patrol tap, wait or fling can rely on, on the phone as in a widget test
/// (`player_finders_test.dart`).
///
/// The player's layers carry keys (`tag-top`, `tag-dock`, `tag-rail`,
/// `tag-stage`), and the All reels sheet holds the same reels as the dock
/// does: a finder that asks only for a chip by its name finds two as soon as
/// the sheet is open, and a tap on `first` may then go to the wrong one.

/// The dock: the one that is on the screen (the measuring copy that decides
/// the dock's floor is offstage and has no key).
final Finder _dock = find.byKey(const ValueKey('tag-dock'));

/// The rail button with [label] on it ("Skip", "Same"): the words on the
/// button, `tagPlayerSkip` and `tagRailSame`. Not the screen reader's name
/// (that one has the reel names in it).
Finder railButton(String label) => find.byWidgetPredicate(
  (w) => w is TtRailButton && w.label == label,
  description: 'the "$label" rail button',
);

/// The reel chip named [name] **in the dock**, never the one of the same
/// reel in the All reels sheet.
Finder dockChip(String name) =>
    find.descendant(of: _dock, matching: _chipNamed(name));

/// The reel chip named [name] **in a sheet** (All reels), never the one in
/// the dock. A Ready or Published reel has a chip only here.
Finder sheetChip(String name) =>
    find.descendant(of: find.byType(TtSheet), matching: _chipNamed(name));

/// The dock's button with [label]: Pick several, All reels, Cancel, and the
/// confirm ("Add to 2 reels & next"). Not a button of the same words in a
/// sheet (the All reels sheet has a Done of its own).
Finder dockAction(String label) => find.descendant(
  of: _dock,
  matching: find.byWidgetPredicate(
    (w) => w is TtButton && w.label == label,
    description: 'TtButton "$label"',
  ),
);

Finder _chipNamed(String name) => find.byWidgetPredicate(
  (w) => w is TtReelChip && w.name == name,
  description: 'the "$name" chip',
);

/// The middle of the clip, as a finger sees it: across the middle of the
/// screen, and between the top's scrim and the dock (a swipe that starts on
/// the dock or the header is theirs). Where a fling goes to move between
/// clips (D-182). Asked of a player on the screen.
Offset stageCentre(WidgetTester tester) {
  final top = tester.getRect(find.byKey(const ValueKey('tag-top')));
  final dock = tester.getRect(_dock);
  return Offset(top.center.dx, (top.bottom + dock.top) / 2);
}

/// Where the dock and the rail are now (the rail's is null while it is not
/// there, as in Pick several), to wait until the layout has stopped moving:
/// `waitForStill` with this as its reading. Asked of a player on the screen.
List<Rect?> playerLayout(WidgetTester tester) {
  Rect? of(Finder finder) =>
      finder.evaluate().isEmpty ? null : tester.getRect(finder);
  return [of(_dock), of(find.byKey(const ValueKey('tag-rail')))];
}

/// Where the first widget [finder] finds is now (null while there is none),
/// to wait until it has stopped moving before a tap that is aimed at it:
/// `waitForStill` with this in a list as its reading. A sheet's chip exists
/// from the first frame of the sheet sliding in, and a tap on a live phone
/// (frames run between the finger's down and up) misses a chip that is still
/// moving. Asked of a screen that is up.
Rect? tapTarget(WidgetTester tester, Finder finder) =>
    finder.evaluate().isEmpty ? null : tester.getRect(finder.first);

/// A touch at the middle of the first widget [finder] finds would reach it
/// (nothing, a scrim or a sliding sheet is not over that spot).
bool canBeTapped(Finder finder) => finder.hitTestable().evaluate().isNotEmpty;
