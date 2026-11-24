import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../patrol_test/support/player_finders.dart';
import '../support/fake_hold.dart';
import '../support/fake_video_player.dart';
import '../support/pump_screen.dart';
import '../support/reel_videos.dart';
import '../support/test_app.dart';
import '../support/vm_harness.dart';

/// The finders the tagging Patrol flows tap and wait on in the full-screen
/// tag player (D-183), checked here against the widgets they find: each one
/// finds exactly one widget, and a tap reaches it (`hitTestable`), as the
/// phone's `tester.tap` needs.
void main() {
  late VmHarness h;
  late FakeHolds holds;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    holds = FakeHolds();
    reels = h.container.read(reelsRepositoryProvider);
    FakeVideoPlayerPlatform.install();
  });

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(settle);
    await tester.pump();
  }

  Future<Reel> newReel(
    WidgetTester tester,
    String name, {
    ReelStatus status = ReelStatus.collecting,
  }) async => (await tester.runAsync(() async {
    final reel = await reels.create(name);
    if (status != ReelStatus.collecting) {
      await reels.setStatus(reel.id, status);
    }
    return reel;
  }))!;

  /// The player over [clips] waiting clips, on a phone 360 dp wide.
  Future<void> open(
    WidgetTester tester, {
    int clips = 3,
    double textScale = 1,
  }) async {
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24);
    await tester.runAsync(
      () => h.media.store([for (var i = 1; i <= clips; i++) reelVideo(i)]),
    );
    await pumpScreen(
      tester,
      const TagPlayerScreen(),
      overrides: [
        ...h.appOverrides,
        holdTimerProvider.overrideWithValue(holds.call),
      ],
      textScale: textScale,
      brightness: Brightness.dark,
      settle: false,
    );
    await settleApp(tester);
  }

  /// A tap would reach [finder]: it finds one widget and that widget is hit
  /// by a touch at its middle.
  void expectOneTappable(Finder finder) {
    expect(finder, findsOneWidget);
    expect(finder.hitTestable(), findsOneWidget);
  }

  String title(WidgetTester tester) =>
      tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).title;

  group('railButton', () {
    testApp('finds Skip and Same, each one, and a tap reaches them', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await open(tester);

      expectOneTappable(railButton('Skip'));
      // Same is off until something is tagged, and still on the screen.
      expect(railButton('Same'), findsOneWidget);
    });

    testApp('finds nothing for a label the rail does not have', (tester) async {
      await newReel(tester, 'Goa');
      await open(tester);

      expect(railButton('Skip it'), findsNothing);
      expect(railButton('Same as previous'), findsNothing);
    });

    testApp('Same is tappable once a tag has happened', (tester) async {
      await newReel(tester, 'Goa');
      await open(tester);
      await tester.tap(dockChip('Goa'));
      await tester.pump();
      holds.fireAll();
      await settleApp(tester);

      expectOneTappable(railButton('Same'));
      expect(title(tester), '2 of 3');
    });
  });

  group('dockChip', () {
    testApp('finds the chip of a Collecting reel once, and a tap tags', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Lisbon');
      await open(tester);

      expectOneTappable(dockChip('Goa'));
      expectOneTappable(dockChip('Lisbon'));
      expect(dockChip('London'), findsNothing);
    });

    testApp("finds only the dock's chip while All reels is open", (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Rome', status: ReelStatus.ready);
      await open(tester);
      await tester.tap(dockAction('All reels'));
      await settleApp(tester);

      // Goa is in the dock and in the sheet: a bare chip finder finds two.
      expect(find.byType(TtSheet), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is TtReelChip && w.name == 'Goa'),
        findsNWidgets(2),
      );
      expect(dockChip('Goa'), findsOneWidget);
      // The sheet's scrim lies over the dock: a tap there is not reaching
      // the dock, and the sheet's own chip is the one a finger reaches.
      expect(dockChip('Goa').hitTestable(), findsNothing);
      expectOneTappable(sheetChip('Goa'));
      // Rome is Ready: not in the dock.
      expect(dockChip('Rome'), findsNothing);
    });
  });

  group('sheetChip', () {
    testApp('finds the chip in All reels, also a Ready reel', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Rome', status: ReelStatus.ready);
      await open(tester);
      expect(sheetChip('Goa'), findsNothing);
      await tester.tap(dockAction('All reels'));
      await settleApp(tester);

      expectOneTappable(sheetChip('Goa'));
      expectOneTappable(sheetChip('Rome'));
      expect(sheetChip('London'), findsNothing);
    });

    testApp('a tap on it closes the sheet and tags the clip into the reel', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      final rome = await newReel(tester, 'Rome', status: ReelStatus.ready);
      await open(tester);
      await tester.tap(dockAction('All reels'));
      await settleApp(tester);

      await tester.tap(sheetChip('Rome'));
      await tester.pump();
      holds.fireAll();
      await settleApp(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect(title(tester), '2 of 3');
      final inRome = await tester.runAsync(
        () => h.container
            .read(clipsRepositoryProvider)
            .watchReelClips(rome.id)
            .first,
      );
      expect(inRome, hasLength(1));
    });
  });

  group('dockAction', () {
    testApp('finds All reels only when the dock has it', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Lisbon');
      await open(tester);

      // Two Collecting reels: all in the dock, so no All reels.
      expect(dockAction('All reels'), findsNothing);
      expectOneTappable(dockAction('Pick several'));
    });

    testApp('finds All reels once a reel is Ready', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Rome', status: ReelStatus.ready);
      await open(tester);

      expectOneTappable(dockAction('All reels'));
    });

    testApp('finds Cancel and the confirm while picking, and not the '
        "sheet's Done", (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Lisbon');
      await open(tester);
      await tester.tap(dockAction('Pick several'));
      await settleApp(tester);
      await tester.tap(dockChip('Goa'));
      await settleApp(tester);

      expectOneTappable(dockAction('Cancel'));
      expectOneTappable(dockAction('Add to 1 reel & next'));
      // Picking has no rail.
      expect(railButton('Skip'), findsNothing);
      // All reels is always in the dock while picking; its sheet has a Done
      // of its own, which is not the dock's.
      await tester.tap(dockAction('All reels'));
      await settleApp(tester);
      expect(
        find.byWidgetPredicate((w) => w is TtButton && w.label == 'Done'),
        findsOneWidget,
      );
      expect(dockAction('Done'), findsNothing);
    });
  });

  group('stageCentre', () {
    testApp("lies under the top and over the dock, on the screen's middle", (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await open(tester);

      final centre = stageCentre(tester);
      final top = tester.getRect(find.byKey(const ValueKey('tag-top')));
      final dock = tester.getRect(find.byKey(const ValueKey('tag-dock')));
      expect(centre.dy, greaterThan(top.bottom));
      expect(centre.dy, lessThan(dock.top));
      expect(centre.dx, 180);
    });

    testApp('does the same with the dock tall at 2x text', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Lisbon');
      await open(tester, textScale: 2);

      final centre = stageCentre(tester);
      final top = tester.getRect(find.byKey(const ValueKey('tag-top')));
      final dock = tester.getRect(find.byKey(const ValueKey('tag-dock')));
      expect(centre.dy, greaterThan(top.bottom));
      expect(centre.dy, lessThan(dock.top));
    });

    testApp('a fling up from it goes to the next clip, down comes back, '
        'sideways does nothing', (tester) async {
      await newReel(tester, 'Goa');
      await open(tester);
      expect(title(tester), '1 of 3');

      await tester.flingFrom(stageCentre(tester), const Offset(0, -300), 1500);
      await settleApp(tester);
      expect(title(tester), '2 of 3');

      await tester.flingFrom(stageCentre(tester), const Offset(0, 300), 1500);
      await settleApp(tester);
      expect(title(tester), '1 of 3');

      await tester.flingFrom(stageCentre(tester), const Offset(-300, 0), 1500);
      await settleApp(tester);
      expect(title(tester), '1 of 3');
    });
  });
}
