import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// A clips repository whose `addClipsToReels` and `moveClips` fail.
class _FailingWrites extends ClipsRepository {
  _FailingWrites(VmHarness h) : super(h.media.db, h.media.clock);

  @override
  Future<List<AddUndo>> addClipsToReels(
    Set<int> reelIds,
    Iterable<int> clipIds,
  ) => Future.error(StateError('disk full'));

  @override
  Future<MoveUndo> moveClips(int from, int to, Iterable<int> clipIds) =>
      Future.error(StateError('disk full'));
}

/// A reels repository whose `create` fails.
class _FailingCreate extends ReelsRepository {
  // ignore: use_super_parameters, the parameters of ReelsRepository are private
  _FailingCreate(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<Reel> create(String name, {String? description}) =>
      Future.error(StateError('disk full'));
}

/// A reels repository that notes every list handed to `undoAll`.
class _RecordingUndo extends ReelsRepository {
  _RecordingUndo(VmHarness h) : super(h.media.db, h.media.clock);

  final List<List<UndoRecord>> undone = [];

  @override
  Future<void> undoAll(List<UndoRecord> records) {
    undone.add(records);
    return super.undoAll(records);
  }
}

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
  });

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<Reel> newReel(
    WidgetTester tester,
    String name, {
    ReelStatus? status,
  }) async {
    final reel = await real(tester, () => reels.create(name));
    if (status != null) {
      await real(tester, () => reels.setStatus(reel.id, status));
    }
    return reel;
  }

  Future<void> open(
    WidgetTester tester,
    int id, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
    List<Override> overrides = const [],
  }) async {
    await pumpScreen(
      tester,
      ReelDetailScreen(reelId: id),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
  }

  Future<Set<int>> clipIdsOf(WidgetTester tester, int reelId) async => {
    for (final c in await real(
      tester,
      () => clips.watchReelClips(reelId).first,
    ))
      c.clip.id,
  };

  List<TtClipTile> tiles(WidgetTester tester) =>
      tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

  Finder barButton(String label) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == label,
    description: 'the "$label" button',
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(barButton('More options'));
    await tester.pumpAndSettle();
  }

  /// A reel with [count] clips, the first of them long pressed.
  Future<List<int>> reelWithClips(WidgetTester tester, Reel reel, int count) =>
      real(
        tester,
        () => putInReel(h, reel.id, [
          for (var i = 1; i <= count; i++) reelVideo(i),
        ]),
      );

  Future<void> select(WidgetTester tester, int count) async {
    await tester.longPress(find.byType(TtClipTile).first);
    await tester.pumpAndSettle();
    for (var i = 1; i < count; i++) {
      await tester.tap(find.byType(TtClipTile).at(i));
      await tester.pumpAndSettle();
    }
  }

  List<String> pickerNames(WidgetTester tester) => [
    for (final r in tester.widgetList<TtReelPickRow>(
      find.byType(TtReelPickRow),
    ))
      r.name,
  ];

  Finder confirm(String label) =>
      find.widgetWithText(TtButton, label, skipOffstage: false);

  group('selection mode', () {
    testApp('long press starts selection', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 3);
      await open(tester, goa.id);
      expect(find.textContaining('selected'), findsNothing);

      await tester.longPress(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [false, true, false]);
      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).selection, isTrue);
    });

    testApp('the count is announced when it changes', (tester) async {
      final semantics = tester.ensureSemantics();
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 3);
      await open(tester, goa.id);
      await select(tester, 1);

      bool live(String title) => tester
          .getSemantics(find.text(title))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion;
      expect(live('1 selected'), isTrue);
      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      expect(live('2 selected'), isTrue);
      semantics.dispose();
    });

    testApp('the bar has the three actions and Select all only', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);

      expect(barButton('Add to another reel'), findsOneWidget);
      expect(barButton('Move to another reel'), findsOneWidget);
      expect(barButton('Remove from this reel'), findsOneWidget);
      expect(barButton('Close'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('Select all'), findsOneWidget);
      // Edit video and Share are Phase 8.
      expect(find.textContaining('Edit video'), findsNothing);
      expect(find.text('Share'), findsNothing);
    });

    testApp('a tap toggles a tile and does not open the viewer', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 3);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [true, false, true]);

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.textContaining('the viewer of clip'), findsNothing);
    });

    testApp('toggle to empty ends selection', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).selection, isFalse);
      expect(tiles(tester).map((t) => t.selected), [null, null]);
    });

    testApp('Close ends selection', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 2);

      await tester.tap(barButton('Close'));
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(tiles(tester).map((t) => t.selected), [null, null]);
    });

    testApp('back ends selection and stays on the page', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 2);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
    });

    testApp('back with nothing chosen leaves the page', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await tester.tap(barButton('Back'));
      await tester.pumpAndSettle();

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('select all skips missing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 3);
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(9)], onPhone: false),
      );
      await open(tester, goa.id);
      expect(find.byType(TtMissingClipTile), findsOneWidget);
      await select(tester, 1);

      await openMenu(tester);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
      expect(tiles(tester).every((t) => t.selected ?? false), isTrue);
    });

    testApp('missing tile cannot be selected', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(9)], onPhone: false),
      );
      await open(tester, goa.id);

      await tester.longPress(find.byType(TtMissingClipTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);

      await select(tester, 1);
      await tester.tap(find.byType(TtMissingClipTile));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    });

    testApp('Remove on a missing tile still works while choosing', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(9)], onPhone: false),
      );
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(find.text('Missing clip removed'), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  group('the picker', () {
    testApp('picker excludes the current reel', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Paris');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);

      expect(pickerNames(tester), unorderedEquals(['London', 'Paris']));
      expect(
        find.descendant(of: find.byType(TtSheet), matching: find.text('Goa')),
        findsNothing,
      );
    });

    testApp('picker sections Collecting then Other reels', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'Done', status: ReelStatus.published);
      await newReel(tester, 'Rome');
      await newReel(tester, 'Edit me', status: ReelStatus.ready);
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);

      expect(
        tester
            .widgetList<TtGroupLabel>(find.byType(TtGroupLabel))
            .map((l) => l.text),
        ['Collecting', 'Other reels'],
      );
      // Collecting reels first (newest first), then the others.
      expect(pickerNames(tester), ['London', 'Rome', 'Edit me', 'Done']);
    });

    testApp('a section with no reels has no heading', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);

      expect(
        tester
            .widgetList<TtGroupLabel>(find.byType(TtGroupLabel))
            .map((l) => l.text),
        ['Collecting'],
      );
    });

    testApp('titles and subtitles for one and several clips', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 3);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      expect(
        tester.widget<TtSheet>(find.byType(TtSheet)).title,
        'Add clip to reels',
      );
      expect(find.text('It stays in this reel too.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      expect(
        tester.widget<TtSheet>(find.byType(TtSheet)).title,
        'Move clip to',
      );
      expect(find.text('It leaves Goa.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      expect(
        tester.widget<TtSheet>(find.byType(TtSheet)).title,
        'Add 3 clips to reels',
      );
      expect(find.text('They stay in this reel too.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      expect(
        tester.widget<TtSheet>(find.byType(TtSheet)).title,
        'Move 3 clips to',
      );
      expect(find.text('They leave Goa.'), findsOneWidget);
    });

    testApp('confirm disabled until picked', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);

      expect(tester.widget<TtButton>(confirm('Add')).onPressed, isNull);

      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TtButton>(confirm('Add to 1 reel')).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      expect(tester.widget<TtButton>(confirm('Add')).onPressed, isNull);
    });

    testApp('add is multi-select', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Paris');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);

      await tester.tap(find.text('London'));
      await tester.tap(find.text('Paris'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<TtReelPickRow>(find.byType(TtReelPickRow))
            .every((r) => r.selected && r.multi),
        isTrue,
      );
      expect(confirm('Add to 2 reels'), findsOneWidget);
    });

    testApp('move is single-select', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Paris');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);

      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paris'));
      await tester.pumpAndSettle();

      final rows = {
        for (final r in tester.widgetList<TtReelPickRow>(
          find.byType(TtReelPickRow),
        ))
          r.name: r,
      };
      expect(rows['Paris']!.selected, isTrue);
      expect(rows['London']!.selected, isFalse);
      expect(rows.values.every((r) => !r.multi), isTrue);
      expect(confirm('Move'), findsOneWidget);
    });

    testApp('a row shows the clip count', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await real(
        tester,
        () => putInReel(h, london.id, [reelVideo(7), reelVideo(8)]),
      );
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);

      final row = tester.widget<TtReelPickRow>(find.byType(TtReelPickRow));
      expect(row.countText, '2 clips');
      expect(row.semanticLabel, 'London, 2 clips');
    });

    testApp('Cancel changes nothing and keeps the selection', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
      expect(await clipIdsOf(tester, london.id), isEmpty);
    });
  });

  group('new reel inline', () {
    Future<void> openAdd(WidgetTester tester, Reel goa) async {
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
    }

    Finder nameField() => find.descendant(
      of: find.byType(TtSheet),
      matching: find.byType(EditableText),
    );

    testApp('new reel inline creates and picks it', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 1);
      await openAdd(tester, goa);
      expect(nameField(), findsNothing);

      await tester.tap(find.text('New reel'));
      await tester.pumpAndSettle();
      expect(find.text('New reel name'), findsOneWidget);
      await tester.enterText(nameField(), '  London Food ');
      await tester.tap(find.text('Create'));
      await settleApp(tester);

      // The field closed, the reel is in the list and picked.
      expect(nameField(), findsNothing);
      final row = tester
          .widgetList<TtReelPickRow>(find.byType(TtReelPickRow))
          .singleWhere((r) => r.name == 'London Food');
      expect(row.selected, isTrue);
      expect(confirm('Add to 1 reel'), findsOneWidget);
      final stored = await real(tester, () => reels.watchAll().first);
      expect(stored.map((r) => r.name), contains('London Food'));
    });

    testApp('in move the new reel replaces the pick', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New reel'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Rome');
      await tester.tap(find.text('Create'));
      await settleApp(tester);

      final picked = tester
          .widgetList<TtReelPickRow>(find.byType(TtReelPickRow))
          .where((r) => r.selected)
          .map((r) => r.name);
      expect(picked, ['Rome']);
    });

    testApp('empty new reel name shows the error', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 1);
      await openAdd(tester, goa);
      await tester.tap(find.text('New reel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      await settleApp(tester);

      expect(find.text('Give this reel a name'), findsOneWidget);
      // The field stays, and nothing was created.
      expect(nameField(), findsOneWidget);
      expect((await real(tester, () => reels.watchAll().first)).length, 1);

      // The error goes with the next edit.
      await tester.enterText(nameField(), 'R');
      await tester.pumpAndSettle();
      expect(find.text('Give this reel a name'), findsNothing);
    });

    testApp('a duplicate name shows the error and creates nothing', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await openAdd(tester, goa);
      await tester.tap(find.text('New reel'));
      await tester.pumpAndSettle();

      await tester.enterText(nameField(), ' london ');
      await tester.tap(find.text('Create'));
      await settleApp(tester);

      expect(
        find.text('You already have a reel called London'),
        findsOneWidget,
      );
      expect((await real(tester, () => reels.watchAll().first)).length, 2);
    });

    testApp('Create twice makes one reel', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 1);
      await openAdd(tester, goa);
      await tester.tap(find.text('New reel'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Rome');

      await tester.tap(find.text('Create'));
      await tester.tap(find.text('Create'), warnIfMissed: false);
      await settleApp(tester);

      final stored = await real(tester, () => reels.watchAll().first);
      expect(stored.where((r) => r.name == 'Rome'), hasLength(1));
    });

    testApp('a create that fails says so in the sheet', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 1);
      await open(
        tester,
        goa.id,
        overrides: [
          reelsRepositoryProvider.overrideWithValue(
            _FailingCreate(h.media.db, h.media.clock),
          ),
        ],
      );
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('New reel'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Rome');

      await tester.tap(find.text('Create'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(nameField(), findsOneWidget);
    });
  });

  group('add', () {
    Future<void> addTo(
      WidgetTester tester,
      Reel goa,
      List<String> names,
    ) async {
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      for (final name in names) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.widgetWithText(
          TtButton,
          names.length == 1 ? 'Add to 1 reel' : 'Add to ${names.length} reels',
        ),
      );
      await settleApp(tester);
    }

    for (final (names, copy) in [
      (['London'], 'Added to London'),
      (['London', 'Paris'], 'Added to London and Paris'),
      (['London', 'Paris', 'Rome'], 'Added to London, Paris and 1 more'),
      (
        ['London', 'Paris', 'Rome', 'Oslo'],
        'Added to London, Paris and 2 more',
      ),
    ]) {
      testApp('add snack copy for 1, 2 and 3 reels: ${names.length}', (
        tester,
      ) async {
        final goa = await newReel(tester, 'Goa');
        for (final n in ['Oslo', 'Rome', 'Paris', 'London']) {
          await newReel(tester, n);
        }
        await reelWithClips(tester, goa, 1);

        await addTo(tester, goa, names);

        expect(find.text(copy), findsOneWidget, reason: copy);
        expect(find.text('Undo'), findsOneWidget);
        // The sheet is gone and the selection ended.
        expect(find.byType(TtSheet), findsNothing);
        expect(find.textContaining('selected'), findsNothing);
      });
    }

    testApp('add puts the clip in every reel and keeps it here, Undo takes '
        'it out of the others', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final paris = await newReel(tester, 'Paris');
      final ids = await reelWithClips(tester, goa, 2);

      await addTo(tester, goa, ['London', 'Paris']);

      expect(await clipIdsOf(tester, london.id), {ids.first});
      expect(await clipIdsOf(tester, paris.id), {ids.first});
      expect(await clipIdsOf(tester, goa.id), ids.toSet());

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(await clipIdsOf(tester, london.id), isEmpty);
      expect(await clipIdsOf(tester, paris.id), isEmpty);
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });

    testApp('a chosen clip deleted while the picker is open is dropped: '
        'confirm adds the rest (Phase 4 picker, later item)', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 2);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      // Another screen removes one chosen clip; it was in no other reel,
      // so it is deleted.
      await real(tester, () => clips.removeClipsFromReel(goa.id, [ids[0]]));
      await settleApp(tester);

      await tester.tap(confirm('Add to 1 reel'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
      expect(await clipIdsOf(tester, london.id), {ids[1]});
      expect(find.text('Added to London'), findsOneWidget);
    });

    testApp('every chosen clip deleted while the picker is open: confirm '
        'closes it and says nothing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      await real(tester, () => clips.removeClipsFromReel(goa.id, [ids[0]]));
      await settleApp(tester);

      await tester.tap(confirm('Add to 1 reel'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
      expect(await clipIdsOf(tester, london.id), isEmpty);
      expect(find.textContaining('Added to'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(find.textContaining('selected'), findsNothing);
    });

    testApp('Undo of an add to several reels undoes every record in one go', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final paris = await newReel(tester, 'Paris');
      final ids = await reelWithClips(tester, goa, 1);
      final recording = _RecordingUndo(h);
      await open(
        tester,
        goa.id,
        overrides: [reelsRepositoryProvider.overrideWithValue(recording)],
      );
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.tap(find.text('Paris'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to 2 reels'));
      await settleApp(tester);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      // One call with both records (one transaction: all or nothing), not
      // one call for each reel.
      expect(recording.undone, hasLength(1));
      expect(recording.undone.single, hasLength(2));
      expect(await clipIdsOf(tester, london.id), isEmpty);
      expect(await clipIdsOf(tester, paris.id), isEmpty);
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });

    testApp('a failed add says so in the sheet and keeps it open', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(
        tester,
        goa.id,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingWrites(h)),
        ],
      );
      await select(tester, 1);
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to 1 reel'));
      await settleApp(tester);

      // In the sheet, not behind it as a snack.
      expect(find.byType(TtSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text('Something went wrong. Try again.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
      // The pick is kept, and a new pick clears the failure.
      expect(confirm('Add to 1 reel'), findsOneWidget);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong. Try again.'), findsNothing);
    });
  });

  group('move', () {
    testApp('move removes from this reel and Undo puts it back', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);

      expect(find.text('Moved to London'), findsOneWidget);
      expect(tiles(tester), hasLength(1));
      expect(await clipIdsOf(tester, goa.id), {ids.last});
      expect(await clipIdsOf(tester, london.id), {ids.first});
      expect(find.textContaining('selected'), findsNothing);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(tiles(tester), hasLength(2));
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
      expect(await clipIdsOf(tester, london.id), isEmpty);
    });

    testApp('Add and Move open one picker however often they are tapped', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);

      for (final label in ['Add to another reel', 'Move to another reel']) {
        // Two presses before a frame is drawn (a tap cannot do that: the
        // sheet's barrier takes the second one once it is on screen).
        final press = tester.widget<TtIconButton>(barButton(label)).onPressed!;
        press();
        press();
        await settleApp(tester);
        expect(find.byType(TtSheet), findsOneWidget, reason: label);
        await tester.tap(find.text('Cancel'));
        await settleApp(tester);
        expect(find.byType(TtSheet), findsNothing, reason: label);
      }
      // The guard is released when a picker closes: the next tap works.
      await tester.tap(barButton('Add to another reel'));
      await settleApp(tester);
      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('a move of clips that already left shows nothing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final paris = await newReel(tester, 'Paris');
      final ids = await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      // The chosen clip is moved to Paris meanwhile (by another screen).
      await real(tester, () => clips.moveClips(goa.id, paris.id, {ids.first}));
      await settleApp(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Moved to'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(await clipIdsOf(tester, london.id), isEmpty);
      expect(await clipIdsOf(tester, paris.id), {ids.first});
      // The choice ends, as after a remove that removed nothing.
      expect(find.textContaining('selected'), findsNothing);
    });

    testApp('a failed move says so in the sheet', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      final ids = await reelWithClips(tester, goa, 1);
      await open(
        tester,
        goa.id,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingWrites(h)),
        ],
      );
      await select(tester, 1);
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);

      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text('Something went wrong. Try again.'),
        ),
        findsOneWidget,
      );
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });
  });

  group('remove', () {
    testApp('remove snack copy and Undo', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await reelWithClips(tester, goa, 3);
      await open(tester, goa.id);
      await select(tester, 2);

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);

      expect(
        find.text(
          '2 clips removed from Goa. The videos are still in your gallery.',
        ),
        findsOneWidget,
      );
      expect(tiles(tester), hasLength(1));
      expect(await clipIdsOf(tester, goa.id), {ids.last});
      expect(find.textContaining('selected'), findsNothing);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(tiles(tester), hasLength(3));
      // The same clips, with their ids.
      expect(await real(tester, clips.allClipIds), ids.toSet());
    });

    testApp('one clip says 1 clip and the video', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);

      expect(
        find.text(
          '1 clip removed from Goa. The video is still in your gallery.',
        ),
        findsOneWidget,
      );
    });

    testApp('removing all the clips shows the empty reel', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 2);

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);

      expect(find.byType(TtEmptyState), findsOneWidget);
      expect(find.textContaining('selected'), findsNothing);
    });

    testApp('Remove twice removes once', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(barButton('Remove from this reel'));
      await tester.tap(barButton('Remove from this reel'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.textContaining('removed from Goa'), findsOneWidget);
    });

    testApp('Undo after leaving the reel restores', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 2);
      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);
      expect(await real(tester, clips.allClipIds), isEmpty);

      GoRouter.of(tester.element(find.byType(ReelDetailScreen)))
          .go(Routes.reels);
      await tester.pumpAndSettle();
      expect(find.byType(ReelDetailScreen), findsNothing);
      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(await real(tester, clips.allClipIds), ids.toSet());
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });

    testApp('Undo of a move after leaving the reel restores', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await reelWithClips(tester, goa, 1);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);

      GoRouter.of(tester.element(find.byType(ReelDetailScreen)))
          .go(Routes.reels);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(await clipIdsOf(tester, goa.id), ids.toSet());
      expect(await clipIdsOf(tester, london.id), isEmpty);
    });
  });

  group('2x text at 360 dp', () {
    for (final brightness in Brightness.values) {
      testApp(
        '2x text at 360 dp, selection bar and picker, ${brightness.name}',
        (tester) async {
          final goa = await newReel(tester, 'Summer road trip with family');
          await newReel(tester, 'London Food Adventures with a long name');
          await newReel(tester, 'Done', status: ReelStatus.published);
          await reelWithClips(tester, goa, 4);
          await open(tester, goa.id, textScale: 2, brightness: brightness);

          await select(tester, 2);
          expect(tester.takeException(), isNull);
          await expectTtAccessible(tester);

          await tester.tap(barButton('Add to another reel'));
          await settleApp(tester);
          expect(tester.takeException(), isNull);
          await expectTtAccessible(tester);

          // With the new reel field open and an error showing.
          await tester.tap(find.text('New reel'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Create'));
          await settleApp(tester);
          expect(tester.takeException(), isNull);
          await expectTtAccessible(tester);
        },
      );
    }

    testApp('expectTtAccessible on the move picker with a pick', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await expectTtAccessible(tester);
    });
  });
}
