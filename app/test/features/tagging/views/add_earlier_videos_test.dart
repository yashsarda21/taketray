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

  /// Whichever dialog is open (the found one asks, the none one informs).
  final dialog = find.byWidgetPredicate(
    (w) => w is TtDialog,
    description: 'a TtDialog',
  );

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

  /// Day [d] of October 2026 in the open date picker. The picker lists the
  /// months one under another, ending with October (today's month), so the
  /// last "d" in the tree is October's.
  Finder day(int d) => find
      .descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.text('$d'),
      )
      .last;

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.text('Choose dates…'));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Picks October [from] to [to] in the picker and confirms; returns with
  /// the count done and the dialog open (or the failure state shown).
  Future<void> pickRange(WidgetTester tester, int from, int to) async {
    await openPicker(tester);
    await tester.tap(day(from));
    await tester.pump();
    await tester.tap(day(to));
    await tester.pump();
    await tester.tap(find.text('Find videos'));
    await tester.pump();
    await settleApp(tester);
    await tester.pumpAndSettle();
  }

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.text('Add'));
    await tester.pump();
    await settleApp(tester);
    await tester.pumpAndSettle();
  }

  group('the sheet', () {
    testWidgets('title, subtitle, and only Today and Choose dates…', (
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
      expect(find.byType(TtListRow), findsNWidgets(2));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Choose dates…'), findsOneWidget);
      // The fixed windows are gone.
      expect(find.text('Last 2 days'), findsNothing);
      expect(find.text('Last 7 days'), findsNothing);
      // Today keeps its count; Choose dates… has a chevron and no count.
      expect(trailing('Today', '1 new'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(TtListRow, 'Choose dates…'),
          matching: find.byIcon(Symbols.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(TtListRow, 'Choose dates…'),
          matching: find.byType(Text),
        ),
        findsOneWidget,
        reason: 'only the title, no count',
      );
      expect(row(tester, 'Today').onTap, isNotNull);
      expect(row(tester, 'Choose dates…').onTap, isNotNull);

      // Enabled buttons to a screen reader, Today named with its count.
      final semantics = tester.ensureSemantics();
      final today = tester.getSemantics(
        find.widgetWithText(TtListRow, 'Today'),
      );
      expect(today.flagsCollection.isEnabled, isNot(ui.Tristate.isFalse));
      expect(
        today.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      expect(today.label, 'Today, 1 new');
      final choose = tester.getSemantics(
        find.widgetWithText(TtListRow, 'Choose dates…'),
      );
      expect(choose.flagsCollection.isEnabled, isNot(ui.Tristate.isFalse));
      expect(
        choose.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('Today with 0 says none and is disabled; Choose dates is not', (
      tester,
    ) async {
      only(shot(3, DateTime(2026, 10, 24, 10)));
      await pumpHost(tester);
      await openSheet(tester);

      expect(trailing('Today', 'none'), findsOneWidget);
      expect(row(tester, 'Today').onTap, isNull);
      expect(row(tester, 'Choose dates…').onTap, isNotNull);

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

    testWidgets('1 new is singular and N new is plural', (tester) async {
      h.bridge.put([shot(4, DateTime(2026, 10, 28, 11))]);
      await pumpHost(tester);
      await openSheet(tester);

      expect(find.text('2 new'), findsOneWidget);
    });
  });

  group('while the count loads or fails', () {
    testWidgets('a skeleton stands in for the count, both rows are disabled', (
      tester,
    ) async {
      final gate = h.bridge.gate('videosShotSince');
      await pumpHost(tester);
      await tester.tap(find.text('open the sheet'));
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TtSkeletonLine), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TtSkeletonLine)).width,
        TtMetrics.skeletonCountWidth,
      );
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.widgetWithText(TtListRow, 'Today'));
      expect(node.label, 'Today, Loading');
      semantics.dispose();
      expect(row(tester, 'Today').onTap, isNull);
      expect(row(tester, 'Choose dates…').onTap, isNull);

      gate.complete();
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(TtSkeletonLine), findsNothing);
      expect(trailing('Today', '1 new'), findsOneWidget);
      expect(row(tester, 'Choose dates…').onTap, isNotNull);
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
      expect(trailing('Today', '1 new'), findsOneWidget);
    });
  });

  group('Today adds straight away', () {
    testWidgets('1 clip: no dialog, the snack says 1 and offers Undo', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);

      await tester.tap(find.text('Today'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(find.text('1 clip added to To tag'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect((await pendingIds(tester)).length, 1);
      expect(find.byType(TtSheet), findsNothing);
    });

    testWidgets('tapping Today twice quickly adds only once', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await tester.tap(find.text('Today'));
      await tester.tap(find.text('Today'));
      await tester.pump();
      await settleApp(tester);

      expect(find.text('1 clip added to To tag'), findsOneWidget);
      expect((await pendingIds(tester)).length, 1);
      // The scanner's calls to the access check: the count that opened the
      // sheet, one add, and the recount after it.
      expect(h.bridge.count('accessReport'), 3);
    });

    testWidgets('the rows are disabled while an add is running', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      final gate = h.bridge.gate('currentZoneId');

      await tester.tap(find.text('Today'));
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pump();

      expect(row(tester, 'Today').onTap, isNull);
      expect(row(tester, 'Choose dates…').onTap, isNull);
      await tester.tap(find.text('Choose dates…'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(DateRangePickerDialog), findsNothing);

      gate.complete();
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('1 clip added to To tag'), findsOneWidget);
      // One add: the zone sync reads the zone, and the add reads it again.
      expect(h.bridge.count('currentZoneId'), 2);
    });

    testWidgets('an add that finds nothing keeps the sheet open', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      h.bridge.videosByVolume.clear();

      await tester.tap(find.text('Today'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TtSnack), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(row(tester, 'Today').onTap, isNull);
    });
  });

  group('Choose dates… opens the date range picker', () {
    testWidgets('with the right limits and copy', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await openPicker(tester);

      final picker = tester.widget<DateRangePickerDialog>(
        find.byType(DateRangePickerDialog),
      );
      // Today is the last day; the first is ten years before it.
      expect(picker.lastDate, DateTime(2026, 10, 28));
      expect(picker.firstDate, DateTime(2016, 10, 28));
      expect(picker.initialDateRange, isNull);
      expect(picker.helpText, 'Choose dates');
      expect(picker.saveText, 'Find videos');
      expect(find.text('Choose dates'), findsOneWidget);
      expect(find.text('Find videos'), findsOneWidget);
    });

    testWidgets(
      'future days cannot be picked; Find videos waits for two days',
      (tester) async {
        await pumpHost(tester);
        await openSheet(tester);
        await openPicker(tester);

        bool enabled() {
          final button = tester.widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text('Find videos'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          );
          return button.onPressed != null;
        }

        expect(enabled(), isFalse, reason: 'nothing picked yet');
        // Tomorrow and the day after: nothing happens.
        await tester.tap(day(29), warnIfMissed: false);
        await tester.pump();
        await tester.tap(day(30), warnIfMissed: false);
        await tester.pump();
        expect(enabled(), isFalse, reason: 'future days cannot be picked');

        // The first pick alone is not a range yet; with the second it is.
        await tester.tap(day(26));
        await tester.pump();
        expect(enabled(), isFalse);
        await tester.tap(day(28));
        await tester.pump();
        expect(enabled(), isTrue);
      },
    );

    testWidgets('a one-day range is allowed', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 27, 27);

      expect(find.text('1 video found'), findsOneWidget);
    });

    testWidgets('closing the picker with Cancel does nothing', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      final before = h.bridge.count('accessReport');
      await openPicker(tester);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(h.bridge.count('accessReport'), before, reason: 'nothing counted');
      expect(row(tester, 'Choose dates…').onTap, isNotNull);
    });
  });

  group('after the dates are picked', () {
    testWidgets('a progress state shows while the videos are counted', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      await openPicker(tester);
      await tester.tap(day(24));
      await tester.pump();
      await tester.tap(day(28));
      await tester.pump();
      final gate = h.bridge.gate('videosShotSince');

      await tester.tap(find.text('Find videos'));
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 500));

      // Skeleton for Choose dates…, no dialog yet, and nothing can be tapped.
      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(dialog, findsNothing);
      expect(
        find.descendant(
          of: find.widgetWithText(TtListRow, 'Choose dates…'),
          matching: find.byType(TtSkeletonLine),
        ),
        findsOneWidget,
      );
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.widgetWithText(TtListRow, 'Choose dates…'))
            .label,
        'Choose dates…, Loading',
      );
      semantics.dispose();
      expect(row(tester, 'Today').onTap, isNull);
      expect(row(tester, 'Choose dates…').onTap, isNull);

      gate.complete();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TtSkeletonLine), findsNothing);
      expect(find.text('3 videos found'), findsOneWidget);
    });

    testWidgets('N videos: plural title and body, Cancel and Add', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 24, 28);

      expect(find.text('3 videos found'), findsOneWidget);
      expect(find.text('Add them to To tag?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      // Counting wrote nothing.
      expect(await pendingIds(tester), isEmpty);
    });

    testWidgets('1 video: singular title and body', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 24, 24);

      expect(find.text('1 video found'), findsOneWidget);
      expect(find.text('Add it to To tag?'), findsOneWidget);
    });

    testWidgets('only the days picked are counted', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 26, 27);

      expect(find.text('1 video found'), findsOneWidget);
    });

    testWidgets('0 videos: "No new videos between…" with one OK', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 20, 22);

      expect(find.text('No new videos'), findsOneWidget);
      expect(
        find.text('No new videos between Oct 20 and Oct 22.'),
        findsOneWidget,
      );
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Add'), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(find.byType(TtSheet), findsOneWidget, reason: 'the sheet stays');
      expect(await pendingIds(tester), isEmpty);
      expect(row(tester, 'Choose dates…').onTap, isNotNull);
    });

    testWidgets('0 videos on one day: "No new videos on…"', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 20, 20);

      expect(find.text('No new videos on Oct 20.'), findsOneWidget);
      expect(find.textContaining('between'), findsNothing);
    });

    testWidgets('known clips are not counted: all added gives 0', (
      tester,
    ) async {
      await tester.runAsync(
        () => h.media.store([shot(3, DateTime(2026, 10, 24, 10))]),
      );
      await pumpHost(tester);
      await openSheet(tester);

      await pickRange(tester, 24, 24);

      expect(find.text('No new videos on Oct 24.'), findsOneWidget);
    });

    testWidgets('Cancel adds nothing, the sheet stays, other dates can be '
        'picked', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 28);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.byType(TtSnack), findsNothing);
      expect(await pendingIds(tester), isEmpty);
      expect(h.bridge.count('currentZoneId'), 0, reason: 'no add ran');

      // Pick again: this time one day.
      await pickRange(tester, 27, 27);
      expect(find.text('1 video found'), findsOneWidget);
    });

    testWidgets('dismissing the dialog by tapping outside is a Cancel', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 28);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(await pendingIds(tester), isEmpty);
    });

    testWidgets('Add adds exactly those videos, then the snack offers Undo', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 27);
      expect(find.text('2 videos found'), findsOneWidget);

      await tapAdd(tester);

      expect(find.text('2 clips added to To tag'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byType(TtSheet), findsNothing);
      expect(dialog, findsNothing);
      final inbox = (await tester.runAsync(h.media.toTag))!;
      // The 24th and the 27th; not today's video (the 28th).
      expect({for (final c in inbox) c.mediaStoreId}, {2, 3});
    });

    testWidgets('a single added clip says "1 clip"', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 24);

      await tapAdd(tester);

      expect(find.text('1 clip added to To tag'), findsOneWidget);
    });

    testWidgets('Undo takes the added clips back out', (tester) async {
      final earlier = (await tester.runAsync(
        () => h.media.store([shot(10, DateTime(2026, 10, 28, 8))]),
      ))!;
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 27);
      await tapAdd(tester);
      expect((await pendingIds(tester)).length, 3);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(await pendingIds(tester), earlier);
      expect(find.text('Undo'), findsNothing);
      expect(find.text("Couldn't undo. Try again."), findsNothing);
    });

    testWidgets('a double tap on Add adds once', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 27);
      final before = h.bridge.count('accessReport');

      await tester.tap(find.text('Add'));
      await tester.tap(find.text('Add'), warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('2 clips added to To tag'), findsOneWidget);
      expect((await pendingIds(tester)).length, 2);
      // One add and the recount after it; a second add would be two more.
      expect(h.bridge.count('accessReport') - before, 2);
      expect(h.bridge.count('currentZoneId'), 2, reason: 'one add, not two');
    });

    testWidgets('if the videos changed since the count, the snack shows the '
        'real number', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 28);
      expect(find.text('3 videos found'), findsOneWidget);
      // One of the three goes away before Add is tapped.
      h.bridge.videosByVolume.clear();
      h.bridge.put([
        shot(1, DateTime(2026, 10, 28, 9, 41)),
        shot(2, DateTime(2026, 10, 27, 20)),
      ]);

      await tapAdd(tester);

      expect(find.text('2 clips added to To tag'), findsOneWidget);
      expect(find.text('3 clips added to To tag'), findsNothing);
    });

    testWidgets('if everything went away since the count, nothing is added '
        'and the sheet stays', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 28);
      h.bridge.videosByVolume.clear();

      await tapAdd(tester);

      expect(find.byType(TtSnack), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(await pendingIds(tester), isEmpty);
      expect(row(tester, 'Choose dates…').onTap, isNotNull);
    });
  });

  group('errors', () {
    testWidgets('a failed count shows the count-failure state; Try again '
        'counts the same dates again', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await openPicker(tester);
      await tester.tap(day(24));
      await tester.pump();
      await tester.tap(day(28));
      await tester.pump();
      h.bridge.failNext('accessReport');

      await tester.tap(find.text('Find videos'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't check your videos."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(TtListRow), findsNothing);
      expect(dialog, findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't check your videos."), findsNothing);
      expect(find.text('3 videos found'), findsOneWidget, reason: 'same dates');
    });

    testWidgets('a double tap on Try again counts once and opens one dialog '
        '(M-4)', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await openPicker(tester);
      await tester.tap(day(24));
      await tester.pump();
      await tester.tap(day(28));
      await tester.pump();
      h.bridge.failNext('accessReport');
      await tester.tap(find.text('Find videos'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      final before = h.bridge.count('accessReport');

      // Two taps before the screen has redrawn.
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Try again'), warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(dialog, findsOneWidget);
      expect(find.text('3 videos found'), findsOneWidget);
      expect(
        h.bridge.count('accessReport') - before,
        1,
        reason: 'one count of the same dates, not two',
      );

      // And the one dialog closes cleanly: the sheet is still there.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
    });

    testWidgets("a double tap on the dialog's Cancel closes the dialog "
        'only, not the sheet (M-4)', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 28);
      expect(dialog, findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.byType(TtSnack), findsNothing);
      expect(await pendingIds(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an add that fails shows the error snack, nothing is added', (
      tester,
    ) async {
      await pumpHost(tester);
      await openSheet(tester);
      await pickRange(tester, 24, 28);
      // Access is lost between the count and Add: addEarlier throws.
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );

      await tapAdd(tester);

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
      await pickRange(tester, 24, 27);
      await tapAdd(tester);
      expect(find.text('2 clips added to To tag'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(repo.undoCalls, 1);
      expect(find.text("Couldn't undo. Try again."), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect((await pendingIds(tester)).length, 2);
      expect(tester.takeException(), isNull);
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

    testWidgets('closing the sheet while the dates are counted does nothing '
        'and throws nothing', (tester) async {
      await pumpHost(tester);
      await openSheet(tester);
      await openPicker(tester);
      await tester.tap(day(24));
      await tester.pump();
      await tester.tap(day(28));
      await tester.pump();
      final gate = h.bridge.gate('videosShotSince');
      await tester.tap(find.text('Find videos'));
      await tester.pump();
      await tester.runAsync(settle);

      // Drag the sheet away (tap the scrim), then let the count finish.
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TtSheet), findsNothing);
      gate.complete();
      await settleApp(tester);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(tester.takeException(), isNull);
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

      testWidgets('${brightness.name}: with Today at 0, accessible', (
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

      testWidgets('${brightness.name}: the date picker is accessible', (
        tester,
      ) async {
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);
        await openPicker(tester);
        await tester.tap(day(24));
        await tester.pump();
        await tester.tap(day(28));
        await tester.pumpAndSettle();

        // Tomorrow and after cannot be picked: 29, 30 and 31 are inactive.
        await expectDatePickerAccessible(
          tester,
          inactiveTexts: {'29', '30', '31'},
        );
      });

      testWidgets('${brightness.name}: the found dialog is accessible', (
        tester,
      ) async {
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);
        await pickRange(tester, 24, 28);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: the none dialog is accessible', (
        tester,
      ) async {
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);
        await pickRange(tester, 20, 22);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: the progress state is accessible', (
        tester,
      ) async {
        await pumpHost(tester, brightness: brightness);
        await openSheet(tester);
        await openPicker(tester);
        await tester.tap(day(24));
        await tester.pump();
        await tester.tap(day(28));
        await tester.pump();
        final gate = h.bridge.gate('videosShotSince');
        await tester.tap(find.text('Find videos'));
        await tester.pump();
        await tester.runAsync(settle);
        await tester.pump(const Duration(milliseconds: 500));

        await expectTtAccessible(tester);

        gate.complete();
        await settleApp(tester);
        await tester.pumpAndSettle();
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

    testWidgets('at 2x text and 360 dp the picker does not overflow', (
      tester,
    ) async {
      await pumpHost(tester, textScale: 2);
      await openSheet(tester);

      await openPicker(tester);

      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Still reaches the buttons and the days.
      await tester.tap(day(24));
      await tester.pump();
      await tester.tap(day(28));
      await tester.pump();
      expect(find.text('Find videos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 2x text and 360 dp both dialogs fit', (tester) async {
      await pumpHost(tester, textScale: 2);
      await openSheet(tester);
      await pickRange(tester, 24, 28);

      expect(tester.takeException(), isNull);
      var rect = tester.getRect(dialog);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(800));
      await expectTtAccessible(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pickRange(tester, 20, 22);

      expect(tester.takeException(), isNull);
      rect = tester.getRect(dialog);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(800));
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
        expect(trailing('Today', '1 new'), findsOneWidget);
        expect(find.text('Choose dates…'), findsOneWidget);

        await pickRange(tester, 24, 27);
        await tapAdd(tester);

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

    testWidgets('adding a chosen range also hides the card link', (
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
      await tester.tap(find.text('Add earlier videos'));
      await tester.pump();
      await settleApp(tester);
      await tester.pumpAndSettle();

      await pickRange(tester, 24, 27);
      await tapAdd(tester);

      expect(find.text('2 clips added to To tag'), findsOneWidget);
      expect(find.text('Add earlier videos'), findsNothing);
    });
  });
}
