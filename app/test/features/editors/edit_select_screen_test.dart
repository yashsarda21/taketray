import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/views/edit_select_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import '../reels/edit_session_support.dart';
import 'editors_support.dart';

void main() {
  late VmHarness h;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
  });

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<Reel> newReel(WidgetTester tester, String name) =>
      real(tester, () => reels.create(name));

  /// Opens the picking screen for reel [id], with [ticked] preselected.
  Future<void> open(
    WidgetTester tester,
    int id, {
    List<int> ticked = const [],
    bool add = false,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    List<Override> overrides = const [],
  }) async {
    await pumpScreen(
      tester,
      EditSelectScreen(reelId: id, clipIds: ticked, addMode: add),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
  }

  List<TtClipTile> tiles(WidgetTester tester) =>
      tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

  List<bool?> ticks(WidgetTester tester) => [
    for (final t in tiles(tester)) t.selected,
  ];

  TtBottomBar bar(WidgetTester tester) =>
      tester.widget<TtBottomBar>(find.byType(TtBottomBar));

  TtButton continueButton(WidgetTester tester) => tester.widget<TtButton>(
    find.descendant(
      of: find.byType(TtBottomBar),
      matching: find.byType(TtButton),
    ),
  );

  /// The top bar's text button (Select all or Clear).
  Finder selectAllButton() => find.descendant(
    of: find.byType(TtAppBar),
    matching: find.byType(TtButton),
  );

  /// Three clips on two days: ids in the order they were shot.
  Future<(Reel, List<int>)> threeClips(WidgetTester tester) async {
    final goa = await newReel(tester, 'Goa');
    final ids = await real(
      tester,
      () => putInReel(h, goa.id, [
        sizedVideo(1, shot: DateTime.utc(2026, 10, 25, 9), size: 400000000),
        sizedVideo(2, shot: DateTime.utc(2026, 10, 25, 10), size: 500000000),
        sizedVideo(3, shot: DateTime.utc(2026, 10, 28, 9), size: 300000000),
      ]),
    );
    return (goa, ids);
  }

  group('the list', () {
    testApp('the title, the reel name, the note and the clips by day, all '
        'unticked when none is preselected (the FAB)', (tester) async {
      final (goa, _) = await threeClips(tester);

      await open(tester, goa.id);

      final appBar = tester.widget<TtAppBar>(find.byType(TtAppBar));
      expect(appBar.title, 'Pick clips to edit');
      expect(appBar.subtitle, 'Goa');
      expect(
        find.text('Clips go to your editor in the order you shot them.'),
        findsOneWidget,
      );
      expect(
        [
          for (final d in tester.widgetList<TtDayHeader>(
            find.byType(TtDayHeader),
          ))
            (d.title.replaceAll(RegExp('[\u202f\u00a0]'), ' '), d.trailing),
        ],
        [('Day 1 · Sun, Oct 25', '2 clips'), ('Day 4 · Wed, Oct 28', '1 clip')],
      );
      expect(ticks(tester), [false, false, false]);
    });

    testApp('lists live clips only: a missing clip is not shown', (
      tester,
    ) async {
      final (goa, _) = await threeClips(tester);
      final [gone] = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(9)], onPhone: false),
      );
      await real(tester, () => flagForTest(h, {gone}, missing: true));

      await open(tester, goa.id);

      expect(tiles(tester), hasLength(3));
      expect(find.byType(TtMissingClipTile), findsNothing);
      expect(find.textContaining('missing'), findsNothing);
    });

    testApp('the clips come from the ids given (the ⋮ menu): ticked, with a '
        'missing clip and a clip of another reel dropped', (tester) async {
      final (goa, ids) = await threeClips(tester);
      final other = await newReel(tester, 'London');
      final [foreign] = await real(
        tester,
        () => putInReel(h, other.id, [reelVideo(7)]),
      );
      await real(tester, () => flagForTest(h, {ids[1]}, missing: true));

      await open(tester, goa.id, ticked: [ids[0], ids[1], foreign, 9999]);

      // The second clip is missing: it is not shown, so two clips remain,
      // and only the first is ticked.
      expect(ticks(tester), [true, false]);
      expect(bar(tester).title, '1 clip · 0:04');
    });

    testApp('a tap ticks and un-ticks a clip', (tester) async {
      final (goa, _) = await threeClips(tester);
      await open(tester, goa.id);

      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(ticks(tester), [false, true, false]);

      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(ticks(tester), [false, false, false]);
    });

    testApp('Select all ticks every clip and becomes Clear; Clear unticks '
        'them; a clip un-ticked after Select all brings Select all back', (
      tester,
    ) async {
      final (goa, _) = await threeClips(tester);
      await open(tester, goa.id);
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Select all');

      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, true, true]);
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Clear');

      await tester.tap(find.byType(TtClipTile).at(0));
      await tester.pumpAndSettle();
      expect(ticks(tester), [false, true, true]);
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Select all');

      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      expect(ticks(tester), [false, false, false]);
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Select all');
    });

    testApp('a clip that goes missing meanwhile leaves the screen and the '
        'selection', (tester) async {
      final (goa, ids) = await threeClips(tester);
      await open(tester, goa.id, ticked: ids);
      expect(bar(tester).title, '3 clips · 0:12');

      await real(tester, () => flagForTest(h, {ids[1]}, missing: true));
      await settleApp(tester);

      expect(tiles(tester), hasLength(2));
      expect(ticks(tester), [true, true]);
      expect(bar(tester).title, '2 clips · 0:08');
      // Select all is Clear again: every clip left is ticked.
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Clear');
    });

    testApp('a reel with no live clip: nothing to pick, nothing breaks', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');

      await open(tester, goa.id);

      expect(tiles(tester), isEmpty);
      expect(bar(tester).title, 'No clips picked');
      expect(continueButton(tester).onPressed, isNull);
      expect(tester.widget<TtButton>(selectAllButton()).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testApp('a reel deleted while the screen is open goes to Reels', (
      tester,
    ) async {
      final (goa, _) = await threeClips(tester);
      await open(tester, goa.id);

      await real(tester, () => reels.delete(goa.id));
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('a reel that does not exist goes to Reels', (tester) async {
      await open(tester, 4242);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('the close button goes back (to the reel when nothing is under '
        'it)', (tester) async {
      final (goa, _) = await threeClips(tester);
      await open(tester, goa.id);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Close',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
    });
  });

  group('the bottom bar', () {
    testApp('nothing picked: the hint, and Continue is off', (tester) async {
      final (goa, _) = await threeClips(tester);

      await open(tester, goa.id);

      expect(bar(tester).title, 'No clips picked');
      expect(bar(tester).subtitle, 'Tap the clips you want to edit');
      expect(continueButton(tester).label, 'Continue');
      expect(continueButton(tester).onPressed, isNull);
    });

    testApp('count, length and size of the picked clips; Continue on', (
      tester,
    ) async {
      final (goa, ids) = await threeClips(tester);

      await open(tester, goa.id, ticked: [ids[0], ids[1]]);

      expect(bar(tester).title, '2 clips · 0:08');
      expect(bar(tester).subtitle, '900\u00a0MB · in shooting order');
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      expect(bar(tester).title, '3 clips · 0:12');
      // 1.2 GB, with one decimal.
      expect(bar(tester).subtitle, '1.2\u00a0GB · in shooting order');
    });

    testApp('Continue goes off again when the last clip is un-ticked', (
      tester,
    ) async {
      final (goa, ids) = await threeClips(tester);
      await open(tester, goa.id, ticked: [ids[2]]);
      expect(bar(tester).title, '1 clip · 0:04');
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();

      expect(bar(tester).title, 'No clips picked');
      expect(continueButton(tester).onPressed, isNull);
    });

    testApp('Continue opens the editor sheet for the picked clips', (
      tester,
    ) async {
      final (goa, ids) = await threeClips(tester);
      h.editors.allow({'apps'});
      await open(tester, goa.id, ticked: [ids[0], ids[2]]);

      await tester.tap(find.text('Continue'));
      await settleApp(tester);

      expect(find.text('Edit 2 clips in…'), findsOneWidget);
    });

    testApp('a double tap on Continue opens one sheet', (tester) async {
      final (goa, ids) = await threeClips(tester);
      h.editors.allow({'apps'});
      await open(tester, goa.id, ticked: ids);

      await tester.tap(find.text('Continue'));
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.text('Edit 3 clips in…'), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
    });
  });

  group('one sheet', () {
    testApp('a second Continue while the sheet is opening opens no second '
        'sheet: one Back closes the only one', (tester) async {
      final (goa, ids) = await threeClips(tester);
      h.editors.allow({'apps'});
      await open(tester, goa.id, ticked: ids);

      // Two calls of the button in one frame, as two fast taps would be.
      final onPressed = continueButton(tester).onPressed!;
      onPressed();
      onPressed();
      await settleApp(tester);
      expect(find.byType(TtSheet), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Edit 3 clips in…'), findsNothing);
    });

    testApp('Continue opens a sheet again after the first was closed', (
      tester,
    ) async {
      final (goa, ids) = await threeClips(tester);
      h.editors.allow({'apps'});
      await open(tester, goa.id, ticked: ids);
      await tester.tap(find.text('Continue'));
      await settleApp(tester);
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(find.byType(TtSheet), findsNothing);

      await tester.tap(find.text('Continue'));
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
    });
  });

  group('add mode (VN add-later)', () {
    /// "Goa" with [threeClips] in a VN session: the first clip copied, the
    /// second sent (not copied), the third fresh.
    Future<(Reel, List<int>)> editing(WidgetTester tester) async {
      final (goa, ids) = await threeClips(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: [ids[0]],
          sent: [ids[1]],
        ),
      );
      return (goa, ids);
    }

    testApp('the title, every live clip, the folder clip ticked and marked, '
        'the fresh one ticked, the sent one not', (tester) async {
      final (goa, ids) = await editing(tester);

      await open(tester, goa.id, add: true);

      final appBar = tester.widget<TtAppBar>(find.byType(TtAppBar));
      expect(appBar.title, 'Add clips to VN folder');
      expect(appBar.subtitle, 'Goa');
      expect(ticks(tester), [true, false, true]);
      expect(
        [for (final t in tiles(tester)) t.vnLabel],
        ['In VN folder', null, null],
      );
      expect(
        tiles(tester).first.semanticLabel,
        endsWith(', already in VN folder'),
      );
      expect(bar(tester).title, '1 new clip to copy');
      expect(
        bar(tester).subtitle.replaceAll('\u00a0', ' '),
        '300 MB · copies are added, never renamed',
      );
      expect(continueButton(tester).label, 'Copy');
      expect(ids, hasLength(3));
    });

    testApp('a tap on the folder clip keeps it ticked and says why', (
      tester,
    ) async {
      final (goa, _) = await editing(tester);
      await open(tester, goa.id, add: true);

      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(ticks(tester), [true, false, true]);
      expect(
        find.text(
          'Already in the VN folder. Copies are deleted when you tap Done '
          'editing.',
        ),
        findsOneWidget,
      );
      expect(bar(tester).title, '1 new clip to copy');
    });

    testApp('nothing new picked: "Pick clips to add", how many are in the '
        'folder, and Copy is off', (tester) async {
      final (goa, _) = await editing(tester);
      await open(tester, goa.id, add: true);

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();

      expect(ticks(tester), [true, false, false]);
      expect(bar(tester).title, 'Pick clips to add');
      expect(bar(tester).subtitle, '1 already in the VN folder');
      expect(continueButton(tester).onPressed, isNull);
    });

    testApp('Copy opens the space check with only the clips to copy, in '
        'shooting order', (tester) async {
      final (goa, ids) = await editing(tester);
      await open(tester, goa.id, add: true);
      // Tick the sent clip as well: it is copied too.
      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(bar(tester).title, '2 new clips to copy');

      await tester.tap(find.text('Copy'));
      await tester.tap(find.text('Copy'), warnIfMissed: false);
      await settleApp(tester);

      expect(
        find.text(
          copySpaceRouteMarker('${goa.id}', 'vn', '${ids[1]},${ids[2]}'),
        ),
        findsOneWidget,
      );
      // One screen, however fast the taps.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.byType(EditSelectScreen), findsOneWidget);
    });

    testApp('Select all and Clear leave the folder clip ticked', (
      tester,
    ) async {
      final (goa, _) = await editing(tester);
      await open(tester, goa.id, add: true);

      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, true, true]);
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Clear');

      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, false, false]);
    });

    testApp('a reel with no session goes back to its page', (tester) async {
      final (goa, _) = await threeClips(tester);

      await open(tester, goa.id, add: true);

      expect(find.text(reelRouteMarker('${goa.id}')), findsOneWidget);
    });

    testApp('a CapCut session goes back to its page too (Task 12 adds it)', (
      tester,
    ) async {
      final (goa, ids) = await threeClips(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.capcut, sent: [ids[0]]),
      );

      await open(tester, goa.id, add: true);

      expect(find.text(reelRouteMarker('${goa.id}')), findsOneWidget);
    });

    testApp('the plain mode shows no folder marks', (tester) async {
      final (goa, _) = await editing(tester);

      await open(tester, goa.id);

      expect([for (final t in tiles(tester)) t.vnLabel], [null, null, null]);
      expect(
        tester.widget<TtAppBar>(find.byType(TtAppBar)).title,
        'Pick clips to edit',
      );
    });

    for (final (scale, brightness) in [
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
    ]) {
      testApp('at ${scale}x, ${brightness.name}: nothing cut, accessible', (
        tester,
      ) async {
        final (goa, _) = await editing(tester);
        await open(
          tester,
          goa.id,
          add: true,
          textScale: scale,
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
      });
    }
  });

  group('the look', () {
    for (final scale in [1.0, 2.0]) {
      testApp('the screen at ${scale}x text does not overflow and is '
          'accessible', (tester) async {
        final (goa, ids) = await threeClips(tester);
        await open(tester, goa.id, ticked: [ids[0]], textScale: scale);

        expect(tiles(tester), hasLength(3));
        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
      });
    }

    testApp('dark: accessible', (tester) async {
      final (goa, ids) = await threeClips(tester);
      await open(tester, goa.id, ticked: ids, brightness: Brightness.dark);

      expect(tiles(tester), hasLength(3));
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('every tile is read as a clip, ticked or not', (tester) async {
      final (goa, ids) = await threeClips(tester);
      await open(tester, goa.id, ticked: [ids[0]]);

      final semantics = tester.ensureSemantics();
      final first = tester.getSemantics(find.byType(TtClipTile).first);
      expect(first.label, startsWith('Clip, '));
      semantics.dispose();
    });
  });
}
