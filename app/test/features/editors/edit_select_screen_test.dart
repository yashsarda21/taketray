import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
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

  /// Opens the picking screen (add mode only) for reel [id].
  Future<void> open(
    WidgetTester tester,
    int id, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
    List<Override> overrides = const [],
    Size size = const Size(360, 800),
  }) async {
    await pumpScreen(
      tester,
      EditSelectScreen(reelId: id),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      size: size,
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

      await open(tester, goa.id);

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
      await open(tester, goa.id);

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
      await open(tester, goa.id);

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
      await open(tester, goa.id);
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
      await open(tester, goa.id);

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

      await open(tester, goa.id);

      expect(find.text(reelRouteMarker('${goa.id}')), findsOneWidget);
    });

    for (final (scale, brightness) in [
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
    ]) {
      testApp('at ${scale}x, ${brightness.name}: nothing cut, accessible', (
        tester,
      ) async {
        final (goa, _) = await editing(tester);
        await open(tester, goa.id, textScale: scale, brightness: brightness);

        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
      });
    }
  });

  group('add mode (CapCut and Edits, D-129)', () {
    /// "Goa" with [threeClips] in a [editor] session: the first clip copied
    /// (and sent), the second sent only, the third fresh.
    Future<(Reel, List<int>)> editing(
      WidgetTester tester,
      EditorApp editor,
    ) async {
      final (goa, ids) = await threeClips(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          editor,
          copied: [ids[0]],
          sent: [ids[0], ids[1]],
        ),
      );
      return (goa, ids);
    }

    for (final (editor, name) in [
      (EditorApp.capcut, 'CapCut'),
      (EditorApp.edits, 'Edits'),
    ]) {
      testApp('$name: stays on the picker; title, the folder clip ticked and '
          'marked, the sent one selectable, the fresh one ticked', (
        tester,
      ) async {
        final (goa, _) = await editing(tester, editor);

        await open(tester, goa.id);

        expect(find.byType(EditSelectScreen), findsOneWidget);
        expect(find.text(reelRouteMarker('${goa.id}')), findsNothing);
        final appBar = tester.widget<TtAppBar>(find.byType(TtAppBar));
        expect(appBar.title, 'Add clips to your $name project');
        expect(appBar.subtitle, 'Goa');
        expect(ticks(tester), [true, false, true]);
        expect(
          [for (final t in tiles(tester)) t.vnLabel],
          ['In the folder', null, null],
        );
        expect(
          tiles(tester).first.semanticLabel,
          endsWith(', already in the folder'),
        );
        expect(bar(tester).title, '1 clip to copy');
        expect(
          bar(tester).subtitle.replaceAll('\u00a0', ' '),
          '300 MB · into Movies/TakeTray/Goa',
        );
        expect(continueButton(tester).label, 'Copy');
      });
    }

    testApp("the bar names the session's folder after a rename", (
      tester,
    ) async {
      final (goa, _) = await editing(tester, EditorApp.capcut);
      await real(tester, () => reels.rename(goa.id, 'Goa 2026'));

      await open(tester, goa.id);

      expect(
        bar(tester).subtitle.replaceAll('\u00a0', ' '),
        '300 MB · into Movies/TakeTray/Goa',
      );
    });

    testApp('a tap on the folder clip keeps it ticked and says why, in the '
        'folder words', (tester) async {
      final (goa, _) = await editing(tester, EditorApp.capcut);
      await open(tester, goa.id);

      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(ticks(tester), [true, false, true]);
      expect(
        find.text(
          'Already in the folder. Copies are deleted when you tap Done '
          'editing.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('VN'), findsNothing);
    });

    testApp('a clip sent but not copied can be ticked and is then copied: '
        'Copy opens the space check for CapCut with it, in shooting order', (
      tester,
    ) async {
      final (goa, ids) = await editing(tester, EditorApp.capcut);
      await open(tester, goa.id);

      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, true, true]);
      expect(bar(tester).title, '2 clips to copy');

      await tester.tap(find.text('Copy'));
      await tester.tap(find.text('Copy'), warnIfMissed: false);
      await settleApp(tester);

      expect(
        find.text(
          copySpaceRouteMarker('${goa.id}', 'capcut', '${ids[1]},${ids[2]}'),
        ),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.byType(EditSelectScreen), findsOneWidget);
    });

    testApp('Edits: Copy opens the space check for Edits', (tester) async {
      final (goa, ids) = await editing(tester, EditorApp.edits);
      await open(tester, goa.id);

      await tester.tap(find.text('Copy'));
      await settleApp(tester);

      expect(
        find.text(copySpaceRouteMarker('${goa.id}', 'edits', '${ids[2]}')),
        findsOneWidget,
      );
    });

    testApp('nothing new picked: "Pick clips to add", how many are in the '
        'folder, and Copy is off', (tester) async {
      final (goa, _) = await editing(tester, EditorApp.edits);
      await open(tester, goa.id);

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();

      expect(ticks(tester), [true, false, false]);
      expect(bar(tester).title, 'Pick clips to add');
      expect(bar(tester).subtitle, '1 already in the folder');
      expect(continueButton(tester).onPressed, isNull);
    });

    testApp('a copy deleted outside TakeTray: its clip is selectable again, '
        'unticked, and no longer marked', (tester) async {
      final (goa, ids) = await threeClips(tester);
      final copies = await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.capcut,
          copied: [ids[0]],
          sent: [ids[0], ids[1]],
        ),
      );
      await open(tester, goa.id);
      expect(ticks(tester), [true, false, true]);

      await real(
        tester,
        () => h.container
            .read(editSessionsRepositoryProvider)
            .removeCopies(goa.id, copies),
      );
      await settleApp(tester);

      expect(ticks(tester), [false, false, true]);
      expect([for (final t in tiles(tester)) t.vnLabel], [null, null, null]);
      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, false, true]);
      expect(bar(tester).title, '2 clips to copy');
    });

    testApp('VN still says VN: folder words with the editor name', (
      tester,
    ) async {
      final (goa, _) = await editing(tester, EditorApp.vn);

      await open(tester, goa.id);

      expect(
        tester.widget<TtAppBar>(find.byType(TtAppBar)).title,
        'Add clips to VN folder',
      );
      expect(tiles(tester).first.vnLabel, 'In VN folder');
      expect(bar(tester).title, '1 new clip to copy');
    });

    testApp('Select all and Clear leave the folder clip ticked: in the bar '
        'at 1x, under the title at 2x, where it still works', (tester) async {
      final (goa, _) = await editing(tester, EditorApp.capcut);
      await open(tester, goa.id);
      expect(selectAllButton(), findsOneWidget);

      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, true, true]);
      expect(tester.widget<TtButton>(selectAllButton()).label, 'Clear');
      await tester.tap(selectAllButton());
      await tester.pumpAndSettle();
      expect(ticks(tester), [true, false, false]);

      await open(tester, goa.id, textScale: 2);
      // Not in the bar any more: under it, at its end, and not lost.
      expect(selectAllButton(), findsNothing);
      final below = find.widgetWithText(TtButton, 'Select all');
      expect(below, findsOneWidget);
      expect(
        tester.getTopLeft(below).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TtAppBar)).dy),
      );
      // Before: only the fresh clip is to copy; Select all adds the sent one.
      expect(bar(tester).title, '1 clip to copy');
      await tester.tap(below);
      await tester.pumpAndSettle();
      expect(bar(tester).title, '2 clips to copy');
      expect(find.widgetWithText(TtButton, 'Clear'), findsOneWidget);
    });

    testApp('VN keeps its Select all in the bar at 2x', (tester) async {
      final (goa, _) = await editing(tester, EditorApp.vn);
      await open(tester, goa.id, textScale: 2);

      expect(selectAllButton(), findsOneWidget);
    });

    for (final (scale, brightness) in [
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
    ]) {
      testApp('at ${scale}x, ${brightness.name}: nothing cut, accessible', (
        tester,
      ) async {
        final (goa, _) = await editing(tester, EditorApp.edits);
        await open(tester, goa.id, textScale: scale, brightness: brightness);

        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
      });
    }
  });

  group('the app bar, add mode (T9-m2, T12-m3)', () {
    Scaffold scaffold(WidgetTester tester) => tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(EditSelectScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );

    testApp('add mode keeps one layout from the first frame: the bar never '
        'moves from the Scaffold slot into the body when the session is read', (
      tester,
    ) async {
      final (goa, ids) = await threeClips(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.capcut,
          copied: [ids[0]],
          sent: [ids[0]],
        ),
      );

      // The first frame: the session is not read yet.
      await pumpScreen(
        tester,
        EditSelectScreen(reelId: goa.id),
        overrides: h.appOverrides,
        settle: false,
      );
      expect(
        tester.widget<TtAppBar>(find.byType(TtAppBar)).title,
        '',
        reason: 'no editor named before it is known',
      );
      expect(scaffold(tester).appBar, isNull, reason: 'the first frame');

      await settleApp(tester);
      expect(
        tester.widget<TtAppBar>(find.byType(TtAppBar)).title,
        'Add clips to your CapCut project',
      );
      expect(scaffold(tester).appBar, isNull, reason: 'once it is read');
    });

    testApp('VN add mode too: the same body layout before and after the '
        'session is read, Select all still in the bar at 2x', (tester) async {
      final (goa, ids) = await threeClips(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );

      await pumpScreen(
        tester,
        EditSelectScreen(reelId: goa.id),
        overrides: h.appOverrides,
        settle: false,
        textScale: 2,
      );
      expect(scaffold(tester).appBar, isNull);
      await settleApp(tester);
      expect(scaffold(tester).appBar, isNull);
      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).wrapTitle, isFalse);
      expect(selectAllButton(), findsOneWidget);
    });
  });

  // What the normal mode's tests pinned and add mode still has to keep (D-192).
  group(
    'the picking screen, whichever editor (ported from the normal mode)',
    () {
      /// "Goa" with [threeClips] in a VN session where nothing is copied yet:
      /// every clip is fresh, so every clip starts ticked.
      Future<(Reel, List<int>)> editing(WidgetTester tester) async {
        final (goa, ids) = await threeClips(tester);
        await real(tester, () => startEditing(h, goa.id, EditorApp.vn));
        return (goa, ids);
      }

      testApp('lists live clips only: a missing clip is not shown', (
        tester,
      ) async {
        final (goa, _) = await editing(tester);
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

      testApp('the clips are listed by day under their headers', (
        tester,
      ) async {
        final (goa, _) = await editing(tester);

        await open(tester, goa.id);

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
          [
            ('Day 1 · Sun, Oct 25', '2 clips'),
            ('Day 4 · Wed, Oct 28', '1 clip'),
          ],
        );
      });

      testApp('a clip that goes missing meanwhile leaves the screen, the '
          'selection and the bar', (tester) async {
        final (goa, ids) = await editing(tester);
        await open(tester, goa.id);
        expect(ticks(tester), [true, true, true]);
        expect(bar(tester).title, '3 new clips to copy');

        await real(tester, () => flagForTest(h, {ids[1]}, missing: true));
        await settleApp(tester);

        expect(tiles(tester), hasLength(2));
        expect(ticks(tester), [true, true]);
        expect(bar(tester).title, '2 new clips to copy');
        // Select all is Clear again: every clip left is ticked.
        expect(tester.widget<TtButton>(selectAllButton()).label, 'Clear');
      });

      testApp('a reel with no live clip: nothing to pick, nothing breaks', (
        tester,
      ) async {
        final goa = await newReel(tester, 'Goa');
        await real(tester, () => startEditing(h, goa.id, EditorApp.vn));

        await open(tester, goa.id);

        expect(tiles(tester), isEmpty);
        expect(bar(tester).title, 'Pick clips to add');
        expect(continueButton(tester).onPressed, isNull);
        expect(tester.widget<TtButton>(selectAllButton()).onPressed, isNull);
        expect(tester.takeException(), isNull);
      });

      testApp('a reel deleted while the screen is open goes to Reels', (
        tester,
      ) async {
        final (goa, _) = await editing(tester);
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
        final (goa, _) = await editing(tester);
        await open(tester, goa.id);

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is TtIconButton && w.semanticLabel == 'Close',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      });

      testApp('every tile is read as a clip, ticked or not', (tester) async {
        final (goa, _) = await editing(tester);
        await open(tester, goa.id);

        final semantics = tester.ensureSemantics();
        final first = tester.getSemantics(find.byType(TtClipTile).first);
        expect(first.label, startsWith('Clip, '));
        semantics.dispose();
      });
    },
  );
}
