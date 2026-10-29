import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/features/tagging/views/add_earlier_videos.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/pump_screen.dart';
import '../../../support/vm_harness.dart';

// 15:00 local on 2026-10-28; the dates are built in local time, so the tests
// hold in any time zone.
final DateTime _now = DateTime(2026, 10, 28, 15);

MediaVideo shot(int id, DateTime when) => fakeVideo(
  id: id,
  generation: id,
  sizeBytes: 1000000 + id,
  dateTakenMs: when.millisecondsSinceEpoch,
  dateAddedSec: when.millisecondsSinceEpoch ~/ 1000,
  dateModifiedSec: when.millisecondsSinceEpoch ~/ 1000,
);

/// An undo that fails, as a database that cannot write would.
class _UndoFails extends ClipsRepository {
  // The parameters of ClipsRepository are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  _UndoFails(AppDatabase db, Clock clock) : super(db, clock);
  int undoCalls = 0;

  @override
  Future<int> undoEarlierAdd(Set<int> clipIds) async {
    undoCalls++;
    throw StateError('disk full');
  }
}

/// A counting `Clips` that counts the undo calls without failing.
class _UndoCounts extends ClipsRepository {
  // ignore: use_super_parameters, see _UndoFails
  _UndoCounts(AppDatabase db, Clock clock) : super(db, clock);
  int undoCalls = 0;

  @override
  Future<int> undoEarlierAdd(Set<int> clipIds) {
    undoCalls++;
    return super.undoEarlierAdd(clipIds);
  }
}

void main() {
  late VmHarness h;

  setUp(() {
    h = VmHarness(now: _now.toUtc());
    h.bridge.put([
      shot(1, DateTime(2026, 10, 28, 9, 41)), // today
      shot(2, DateTime(2026, 10, 27, 20)), // yesterday
      shot(3, DateTime(2026, 10, 24, 10)), // four days ago
    ]);
  });

  /// Replaces the phone's videos with just [video].
  void only(MediaVideo video) {
    h.bridge.videosByVolume.clear();
    h.bridge.put([video]);
  }

  /// A page with one button that opens the sheet the way the screens do.
  Future<ProviderContainer> pumpHost(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TtButton(
          label: 'open the sheet',
          onPressed: () => showAddEarlierVideos(context),
        ),
      ),
    ),
    overrides: h.appOverrides,
    textScale: textScale,
    brightness: brightness,
  );

  /// Lets the database, the bridge and the queue answer, then redraws.
  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open the sheet'));
    await tester.pump();
    await settleApp(tester);
    await tester.pumpAndSettle();
  }

  TtListRow row(WidgetTester tester, String title) =>
      tester.widget<TtListRow>(find.widgetWithText(TtListRow, title));

  Finder trailing(String title, String text) => find.descendant(
    of: find.widgetWithText(TtListRow, title),
    matching: find.text(text),
  );

  /// The ids waiting in To tag (a real-async read, outside the test clock).
  Future<List<int>> pendingIds(WidgetTester tester) async => [
    for (final c in (await tester.runAsync(h.media.toTag))!) c.id,
  ];

  group('sheet shows counts; a zero row is disabled', () {
    testWidgets('title, subtitle, three rows with their counts', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);

      expect(find.text('Add earlier videos'), findsOneWidget);
      expect(
        find.text(
          'From your camera folders. Clips you already tagged or skipped '
          'stay where they are.',
        ),
        findsOneWidget,
      );
      expect(trailing('Today', '1 new'), findsOneWidget);
      expect(trailing('Last 2 days', '2 new'), findsOneWidget);
      expect(trailing('Last 7 days', '3 new'), findsOneWidget);
      for (final t in ['Today', 'Last 2 days', 'Last 7 days']) {
        expect(row(tester, t).onTap, isNotNull, reason: t);
      }

      // Enabled buttons to a screen reader, named with their count.
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(
        find.widgetWithText(TtListRow, 'Last 2 days'),
      );
      expect(node.flagsCollection.isEnabled, isNot(ui.Tristate.isFalse));
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
      expect(node.label, 'Last 2 days, 2 new');
      semantics.dispose();
    });

    testWidgets('a row with 0 says none and is disabled', (tester) async {
      only(shot(3, DateTime(2026, 10, 24, 10)));
      await pumpHost(tester);
      await openSheet(tester);

      expect(trailing('Today', 'none'), findsOneWidget);
      expect(trailing('Last 2 days', 'none'), findsOneWidget);
      expect(trailing('Last 7 days', '1 new'), findsOneWidget);
      expect(row(tester, 'Today').onTap, isNull);
      expect(row(tester, 'Last 2 days').onTap, isNull);
      expect(row(tester, 'Last 7 days').onTap, isNotNull);

      // Disabled to a screen reader as well, and a tap does nothing.
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.widgetWithText(TtListRow, 'Today'));
      expect(node.flagsCollection.isEnabled, ui.Tristate.isFalse);
      semantics.dispose();
      await tester.tap(find.text('Today'));
      await settleApp(tester);
      expect(find.byType(TtSnack), findsNothing);
      expect(find.text('Add earlier videos'), findsOneWidget);
    });

    testWidgets('every count 0: all three rows are disabled', (tester) async {
      h.bridge.videosByVolume.clear();
      await pumpHost(tester);
      await openSheet(tester);

      for (final t in ['Today', 'Last 2 days', 'Last 7 days']) {
        expect(row(tester, t).onTap, isNull, reason: t);
        expect(trailing(t, 'none'), findsOneWidget, reason: t);
      }
    });

    testWidgets('1 new is singular and N new is plural', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      expect(find.text('1 new'), findsOneWidget);
      expect(find.text('2 new'), findsOneWidget);
    });
  });

  group('while the counts load or fail', () {
    testWidgets('skeletons stand in for the counts, rows are disabled', (
      tester,
    ) async {
      final gate = h.bridge.gate('videosShotSince');
      await pumpHost(tester);
      await tester.tap(find.text('open the sheet'));
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TtSkeletonLine), findsNWidgets(3));
      expect(find.text('Today'), findsOneWidget);
      // The bar for a count has its own width, not a touch-target size.
      expect(
        tester.getSize(find.byType(TtSkeletonLine).first).width,
        TtMetrics.skeletonCountWidth,
      );
      // A screen reader hears that the count is loading, not just a dead row.
      final semantics = tester.ensureSemantics();
      for (final t in ['Today', 'Last 2 days', 'Last 7 days']) {
        final node = tester.getSemantics(find.widgetWithText(TtListRow, t));
        expect(node.label, '$t, Loading', reason: t);
      }
      semantics.dispose();
      for (final t in ['Today', 'Last 2 days', 'Last 7 days']) {
        expect(row(tester, t).onTap, isNull, reason: t);
      }

      gate.complete();
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(TtSkeletonLine), findsNothing);
      expect(trailing('Last 7 days', '3 new'), findsOneWidget);
    });

    testWidgets('a failed count shows a short retry that counts again', (
      tester,
    ) async {
      h.bridge.failNext('accessReport');
      await pumpHost(tester);
      await openSheet(tester);

      expect(find.text("Couldn't check your videos."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(TtListRow), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't check your videos."), findsNothing);
      expect(trailing('Last 7 days', '3 new'), findsOneWidget);
    });
  });

  group(
    'tapping Last 2 days adds and shows the snack with the right count',
    () {
      testWidgets('2 clips: in To tag, the snack says 2 and offers Undo', (
        tester,
      ) async {
        await pumpHost(tester);
        await openSheet(tester);

        await tester.tap(find.text('Last 2 days'));
        await tester.pump();
        await settleApp(tester);
        await tester.pumpAndSettle();

        expect(find.text('2 clips added to To tag'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
        expect((await pendingIds(tester)).length, 2);
        // The sheet is closed.
        expect(find.byType(TtSheet), findsNothing);
      });

      testWidgets('1 clip: singular', (tester) async {
        await pumpHost(tester);
        await openSheet(tester);

        await tester.tap(find.text('Today'));
        await tester.pump();
        await settleApp(tester);

        expect(find.text('1 clip added to To tag'), findsOneWidget);
        expect((await pendingIds(tester)).length, 1);
      });

      testWidgets('7 days: 3 clips', (tester) async {
        await pumpHost(tester);
        await openSheet(tester);

        await tester.tap(find.text('Last 7 days'));
        await tester.pump();
        await settleApp(tester);

        expect(find.text('3 clips added to To tag'), findsOneWidget);
      });

      testWidgets('tapping a row twice quickly adds only once', (tester) async {
        await pumpHost(tester);
        await openSheet(tester);

        await tester.tap(find.text('Last 2 days'));
        await tester.tap(find.text('Last 2 days'));
        await tester.pump();
        await settleApp(tester);

        expect(find.text('2 clips added to To tag'), findsOneWidget);
        expect((await pendingIds(tester)).length, 2);
        // The calls to the access check are the scanner's calls: the count
        // that opened the sheet, one add, and the recount after it. A second
        // add would be two more. (The scanner would not add the clips twice
        // anyway, so the clips alone cannot show it.)
        expect(h.bridge.count('accessReport'), 3);
      });

      testWidgets('the rows are disabled while an add is running', (
        tester,
      ) async {
        await pumpHost(tester);
        await openSheet(tester);
        final gate = h.bridge.gate('currentZoneId');

        await tester.tap(find.text('Last 2 days'));
        await tester.pump();
        await tester.runAsync(settle);
        await tester.pump();

        for (final t in ['Today', 'Last 2 days', 'Last 7 days']) {
          expect(row(tester, t).onTap, isNull, reason: t);
        }
        // A tap on another row meanwhile does nothing.
        await tester.tap(find.text('Last 7 days'));
        await tester.pump();

        gate.complete();
        await settleApp(tester);
        await tester.pumpAndSettle();
        expect(find.text('2 clips added to To tag'), findsOneWidget);
        expect(h.bridge.count('currentZoneId'), 1);
      });

      testWidgets('an add that finds nothing keeps the sheet open', (
        tester,
      ) async {
        await pumpHost(tester);
        await openSheet(tester);
        // The videos are gone between the count and the tap.
        h.bridge.videosByVolume.clear();

        await tester.tap(find.text('Last 2 days'));
        await tester.pump();
        await settleApp(tester);
        await tester.pumpAndSettle();

        expect(find.byType(TtSnack), findsNothing);
        expect(find.byType(TtSheet), findsOneWidget);
        // The recount disabled the rows.
        expect(row(tester, 'Last 2 days').onTap, isNull);
      });
    },
  );

  group('errors', () {
    testWidgets('an add that fails shows the error snack, nothing is added', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      // Access is lost between the count and the tap: addEarlier throws.
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );

      await tester.tap(find.text('Last 2 days'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't add videos. Try again."), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
      expect(await pendingIds(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an undo that fails shows the error snack', (tester) async {
      late _UndoFails repo;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TtButton(
              label: 'open the sheet',
              onPressed: () => showAddEarlierVideos(context),
            ),
          ),
        ),
        overrides: [
          ...h.appOverrides,
          clipsRepositoryProvider.overrideWith(
            (ref) => repo = _UndoFails(h.media.db, h.media.clock),
          ),
        ],
      );
      await openSheet(tester);
      await tester.tap(find.text('Last 2 days'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('2 clips added to To tag'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(repo.undoCalls, 1);
      expect(find.text("Couldn't undo. Try again."), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      // Nothing was taken back.
      expect((await pendingIds(tester)).length, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('Undo removes them', () {
    testWidgets('only the added clips go, and the snack closes', (
      tester,
    ) async {
      final earlier = (await tester.runAsync(
        () => h.media.store([shot(10, DateTime(2026, 10, 28, 8))]),
      ))!;
      await pumpHost(tester);
      await openSheet(tester);
      await tester.tap(find.text('Last 2 days'));
      await tester.pump();
      await settleApp(tester);
      expect((await pendingIds(tester)).length, 3);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      // The clip that was in To tag before stays.
      expect(await pendingIds(tester), earlier);
      expect(find.text('Undo'), findsNothing);
      expect(find.text("Couldn't undo. Try again."), findsNothing);
    });

    testWidgets('Undo tapped twice undoes once', (tester) async {
      late _UndoCounts repo;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TtButton(
              label: 'open the sheet',
              onPressed: () => showAddEarlierVideos(context),
            ),
          ),
        ),
        overrides: [
          ...h.appOverrides,
          clipsRepositoryProvider.overrideWith(
            (ref) => repo = _UndoCounts(h.media.db, h.media.clock),
          ),
        ],
      );
      await openSheet(tester);
      await tester.tap(find.text('Today'));
      await tester.pump();
      await settleApp(tester);

      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);

      expect(repo.undoCalls, 1);
    });

    testWidgets('after the snack has closed there is nothing to undo', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      await tester.tap(find.text('Today'));
      await tester.pump();
      await settleApp(tester);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsNothing);
      expect(find.byType(TtSnack), findsNothing);
      expect((await pendingIds(tester)).length, 1);
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: the sheet is accessible', (
        tester,
      ) async {
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: with a zero row, accessible', (
        tester,
      ) async {
        only(shot(3, DateTime(2026, 10, 24, 10)));
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: the retry state is accessible', (
        tester,
      ) async {
        h.bridge.failNext('accessReport');
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);

        await expectTtAccessible(tester);
      });
    }

    testWidgets('at 2x text the sheet fits 360 dp and 800 dp', (tester) async {
      await pumpHost(tester, textScale: 2);
      await openSheet(tester);

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(TtSheet));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(800));
      await expectTtAccessible(tester);
    });

    testWidgets('at 2x text the retry state fits', (tester) async {
      h.bridge.failNext('accessReport');
      await pumpHost(tester, textScale: 2);
      await openSheet(tester);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testWidgets('at 2x text and a small phone the rows still scroll', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TtButton(
              label: 'open the sheet',
              onPressed: () => showAddEarlierVideos(context),
            ),
          ),
        ),
        overrides: h.appOverrides,
        textScale: 2,
        size: const Size(360, 400),
      );
      await openSheet(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('from the screens', () {
    testWidgets(
      'the To tag menu item opens the sheet, even with Shooting off',
      (tester) async {
        await pumpScreen(
          tester,
          const ToTagScreen(),
          overrides: h.appOverrides,
        );
        await settleApp(tester);

        await tester.tap(find.byIcon(Symbols.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add earlier videos'));
        await tester.pump();
        await settleApp(tester);
        await tester.pumpAndSettle();

        expect(find.byType(TtSheet), findsOneWidget);
        expect(trailing('Last 7 days', '3 new'), findsOneWidget);

        await tester.tap(find.text('Last 2 days'));
        await tester.pump();
        await settleApp(tester);
        await tester.pumpAndSettle();

        // The new clips are in the grid, and the snack says how many.
        expect(find.byType(TtClipTile), findsNWidgets(2));
        expect(find.text('2 clips added to To tag'), findsOneWidget);
      },
    );

    testWidgets('the card link opens the sheet; it is gone after adding', (
      tester,
    ) async {
      await tester.runAsync(h.media.turnOnNow);
      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: ShootingModeSection()),
        ),
        overrides: h.appOverrides,
      );
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('Add earlier videos'), findsOneWidget);

      await tester.tap(find.text('Add earlier videos'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(TtSheet), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('1 clip added to To tag'), findsOneWidget);
      // markEarlierAdded hides the link; the strip now counts the clip.
      expect(find.text('Add earlier videos'), findsNothing);
      expect(find.text('1 clip to tag'), findsOneWidget);
    });
  });
}
