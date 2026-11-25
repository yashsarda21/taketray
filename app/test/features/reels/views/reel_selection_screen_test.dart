import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../edit_session_support.dart' show startEditing;

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
    Size size = const Size(360, 800),
  }) async {
    await pumpScreen(
      tester,
      ReelDetailScreen(reelId: id),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      size: size,
      settle: false,
      // In the app's shell, where the dock takes the nav pill's place while
      // choosing (D-191).
      inShell: true,
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

  /// The action of the dock (D-191) whose word under the icon is [label]:
  /// Share, Add to, Move or Remove.
  Finder dockAction(String label) => find.descendant(
    of: find.byType(TtSelectionDock),
    matching: find.text(label),
  );

  /// The top bar's Select all or Clear, at text 1x a text button.
  Finder topButton(String label) => find.descendant(
    of: find.byType(TtAppBar),
    matching: find.widgetWithText(TtButton, label),
  );

  /// A reel with [count] clips, the first of them long pressed.
  Future<List<int>> reelWithClips(WidgetTester tester, Reel reel, int count) =>
      real(
        tester,
        () => putInReel(h, reel.id, [
          for (var i = 1; i <= count; i++) reelVideo(i),
        ]),
      );

  /// Long presses the first tile, then taps the next [count] - 1. A tile
  /// the dock covers (at large text) is scrolled above it first.
  Future<void> select(WidgetTester tester, int count) async {
    await tester.longPress(find.byType(TtClipTile).first);
    await tester.pumpAndSettle();
    for (var i = 1; i < count; i++) {
      final tile = find.byType(TtClipTile).at(i);
      final panel = find.descendant(
        of: find.byType(TtSelectionDock),
        matching: find.byType(DecoratedBox),
      );
      if (panel.evaluate().isNotEmpty) {
        final under =
            tester.getBottomLeft(tile).dy - tester.getTopLeft(panel.first).dy;
        if (under > 0) {
          // A drag scrolls a little less than it moves (the touch slop).
          await tester.drag(
            find.byType(CustomScrollView),
            Offset(0, -under - 48),
          );
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(tile);
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

      await tester.tap(topButton('Select all'));
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

      await tester.tap(
        find.descendant(
          of: find.byType(TtMissingClipTile),
          matching: find.text('Remove'),
        ),
      );
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

      await tester.tap(dockAction('Add to'));
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

      await tester.tap(dockAction('Add to'));
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

      await tester.tap(dockAction('Add to'));
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

      await tester.tap(dockAction('Add to'));
      await settleApp(tester);
      expect(
        tester.widget<TtSheet>(find.byType(TtSheet)).title,
        'Add clip to reels',
      );
      expect(find.text('It stays in this reel too.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      await tester.tap(dockAction('Move'));
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
      await tester.tap(dockAction('Add to'));
      await settleApp(tester);
      expect(
        tester.widget<TtSheet>(find.byType(TtSheet)).title,
        'Add 3 clips to reels',
      );
      expect(find.text('They stay in this reel too.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      await tester.tap(dockAction('Move'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Move'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Move'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Add to'));
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

      await tester.tap(dockAction('Move'));
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

      for (final (index, label) in [(1, 'Add to'), (2, 'Move')]) {
        // Two presses before a frame is drawn (a tap cannot do that: the
        // sheet's barrier takes the second one once it is on screen).
        final action = tester
            .widget<TtSelectionDock>(find.byType(TtSelectionDock))
            .actions[index];
        expect(action.label, label);
        final press = action.onPressed!;
        press();
        press();
        await settleApp(tester);
        expect(find.byType(TtSheet), findsOneWidget, reason: label);
        await tester.tap(find.text('Cancel'));
        await settleApp(tester);
        expect(find.byType(TtSheet), findsNothing, reason: label);
      }
      // The guard is released when a picker closes: the next tap works.
      await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Move'));
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
      await tester.tap(dockAction('Move'));
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

      await tester.tap(dockAction('Remove'));
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

      await tester.tap(dockAction('Remove'));
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

      await tester.tap(dockAction('Remove'));
      await settleApp(tester);

      expect(find.byType(TtEmptyState), findsOneWidget);
      expect(find.textContaining('selected'), findsNothing);
    });

    testApp('Remove twice removes once', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(dockAction('Remove'));
      await tester.tap(dockAction('Remove'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.textContaining('removed from Goa'), findsOneWidget);
    });

    testApp('Undo after leaving the reel restores', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await reelWithClips(tester, goa, 2);
      await open(tester, goa.id);
      await select(tester, 2);
      await tester.tap(dockAction('Remove'));
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
      await tester.tap(dockAction('Move'));
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
          expect(find.text('2 selected'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectTtAccessible(tester);

          await tester.tap(dockAction('Add to'));
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
      await tester.tap(dockAction('Move'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await expectTtAccessible(tester);
    });
  });
  group('Edit video and the dock (D-191)', () {
    setUp(
      () => h.editors
        ..allow({'apps', 'sendTo', 'shareWithChooser', 'copyFolderNames'})
        ..installed = {
          for (final editor in EditorApp.values) editor.packageName: true,
        },
    );

    /// A reel with three clips shot in the reverse order of their ids, 10,
    /// 25 and 40 s long: the tile order is shooting order, the first tile
    /// is video 3 (40 s).
    Future<(Reel, List<int>)> reelWithThree(WidgetTester tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 10, 28, 12), durationMs: 10000),
          reelVideo(2, shot: DateTime.utc(2026, 10, 28, 11), durationMs: 25000),
          reelVideo(3, shot: DateTime.utc(2026, 10, 28, 10), durationMs: 40000),
        ]),
      );
      return (goa, ids);
    }

    TtSelectionDock dock(WidgetTester tester) =>
        tester.widget<TtSelectionDock>(find.byType(TtSelectionDock));

    Finder dockEdit() =>
        find.byKey(const ValueKey<String>('tt-selection-dock-edit'));

    /// The hint banner of choosing from the sheet.
    Finder hint() => find.descendant(
      of: find.byType(TtBanner),
      matching: find.text('Tap the clips you want to edit'),
    );

    String? sheetTitle(WidgetTester tester) =>
        tester.widget<TtSheet>(find.byType(TtSheet)).title;

    bool choosing(WidgetTester tester) =>
        tester.widget<TtAppBar>(find.byType(TtAppBar)).selection;

    /// The MediaStore ids of the last share through Android's menu.
    List<int?> sharedIds() => [
      for (final c in h.editors.chooserShares.last.$1) c.mediaStoreId,
    ];

    /// The top of the dock's panel (not of the slide around it).
    double dockTop(WidgetTester tester) => tester
        .getTopLeft(
          find
              .descendant(
                of: find.byType(TtSelectionDock),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .dy;

    Future<void> tapEditVideo(WidgetTester tester) async {
      await tester.tap(find.byType(TtFab));
      await settleApp(tester);
    }

    Future<void> chooseInstead(WidgetTester tester) async {
      await tapEditVideo(tester);
      await tester.tap(find.widgetWithText(TtButton, 'Choose clips instead'));
      await settleApp(tester);
    }

    /// Lets the "Mark as Ready to edit?" offer of a CapCut send come, 1.3 s
    /// later, and closes it.
    Future<void> flushReadyOffer(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 1500));
      await settleApp(tester);
      if (find.text('Not now').evaluate().isNotEmpty) {
        await tester.tap(find.text('Not now'));
        await settleApp(tester);
      }
    }

    testApp('Edit video opens the sheet with every live clip in shooting '
        'order, "Edit all 3 clips in…"', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      // A missing clip is left out.
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(9)], onPhone: false),
      );
      await open(tester, goa.id);
      expect(find.byType(TtMissingClipTile), findsOneWidget);

      await tapEditVideo(tester);

      expect(sheetTitle(tester), 'Edit all 3 clips in…');
      expect(find.text('Choose clips instead'), findsOneWidget);
      // No picking screen, and nothing chosen on the page.
      expect(find.textContaining('the picking screen'), findsNothing);
      expect(choosing(tester), isFalse);

      // The sheet's clips are the live ones in shooting order: 3, 2, 1.
      await tester.tap(find.text('Other app…'));
      await settleApp(tester);
      expect(sharedIds(), [3, 2, 1]);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
    });

    testApp('a double tap on Edit video opens one sheet', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);

      await tester.tap(find.byType(TtFab));
      await tester.tap(find.byType(TtFab), warnIfMissed: false);
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('every clip missing: no Edit video', (tester) async {
      final goa = await newReel(tester, 'Goa');
      // Gone from the phone, so the check on open keeps them missing.
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [
          for (var i = 1; i <= 3; i++) reelVideo(i),
        ], onPhone: false),
      );
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));
      await open(tester, goa.id);

      expect(find.byType(TtMissingClipTile), findsNWidgets(3));
      expect(find.byType(TtFab), findsNothing);
    });

    testApp('Choose clips instead: choosing, nothing chosen, the hint, the '
        'dock off', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);

      await chooseInstead(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect(choosing(tester), isTrue);
      expect(find.text('Choose clips'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [false, false, false]);
      expect(find.byType(TtFab), findsNothing);
      // The hint is the first thing under the access banner, above the
      // reel's header.
      expect(hint(), findsOneWidget);
      expect(
        find.text('Next time, hold a clip to start choosing straight away.'),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(hint()).dy,
        lessThan(tester.getTopLeft(find.byType(TtReelHeader<ReelStatus>)).dy),
      );
      // The dock in the nav pill's place, everything in it off.
      expect(find.byType(TtNavPill), findsNothing);
      final d = dock(tester);
      expect(d.semanticLabel, 'Chosen clips');
      expect(
        [for (final a in d.actions) a.label],
        ['Share', 'Add to', 'Move', 'Remove'],
      );
      expect(
        [for (final a in d.actions) a.semanticLabel],
        [
          'Share',
          'Add to another reel',
          'Move to another reel',
          'Remove from this reel',
        ],
      );
      expect(
        [for (final a in d.actions) a.icon],
        [
          Symbols.share_rounded,
          Symbols.library_add_rounded,
          Symbols.drive_file_move_rounded,
          Symbols.playlist_remove_rounded,
        ],
      );
      expect(d.actions.map((a) => a.onPressed), everyElement(isNull));
      expect(d.edit!.label, 'Tap the clips you want to edit');
      expect(d.edit!.semanticLabel, 'Edit: choose clips first');
      expect(d.edit!.detail, isNull);
      expect(d.edit!.onPressed, isNull);
      expect(d.note, isNull);
    });

    testApp('from the sheet, un-choosing to zero keeps choosing and the hint '
        'comes back', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await chooseInstead(tester);

      // A long press while choosing chooses (it does not start again), so
      // choosing still comes from the sheet.
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(hint(), findsNothing);
      expect(dock(tester).edit!.label, 'Edit 1 clip');

      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(choosing(tester), isTrue);
      expect(find.text('Choose clips'), findsOneWidget);
      expect(hint(), findsOneWidget);
      expect(find.byType(TtSelectionDock), findsOneWidget);
      expect(dock(tester).edit!.onPressed, isNull);
      expect(find.byType(TtNavPill), findsNothing);
    });

    testApp('a long press: that clip chosen, no hint; un-choosing it ends '
        'choosing', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);

      await tester.longPress(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [false, true, false]);
      expect(hint(), findsNothing);
      expect(find.byType(TtNavPill), findsNothing);
      final d = dock(tester);
      expect(d.actions.map((a) => a.onPressed), everyElement(isNotNull));
      // Video 2 is 25 s long.
      expect(d.edit!.label, 'Edit 1 clip');
      expect(d.edit!.detail, '0:25');
      expect(d.edit!.semanticLabel, 'Edit 1 clip, 0:25');
      expect(d.edit!.onPressed, isNotNull);

      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();

      expect(choosing(tester), isFalse);
      expect(find.byType(TtSelectionDock), findsNothing);
      expect(find.byType(TtNavPill), findsOneWidget);
      expect(find.byType(TtFab), findsOneWidget);
    });

    testApp('Edit 2 clips opens the sheet with exactly those, in shooting '
        'order', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      // Tiles are in shooting order: video 3, 2, 1. Choose the last tile
      // first, then the first: videos 1 and 3, 50 s together.
      await tester.longPress(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(dock(tester).edit!.label, 'Edit 2 clips');
      expect(dock(tester).edit!.detail, '0:50');
      expect(dock(tester).edit!.semanticLabel, 'Edit 2 clips, 0:50');

      await tester.tap(dockEdit());
      await settleApp(tester);

      expect(sheetTitle(tester), 'Edit 2 clips in…');
      // Not the whole reel's sheet.
      expect(find.text('Choose clips instead'), findsNothing);
      await tester.tap(find.text('Other app…'));
      await settleApp(tester);
      expect(sharedIds(), [3, 1]);
      // Other app… is an editor too: choosing ends.
      expect(choosing(tester), isFalse);
      expect(find.byType(TtSelectionDock), findsNothing);
    });

    testApp('a double tap on Edit opens one sheet', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(dockEdit());
      await tester.tap(dockEdit(), warnIfMissed: false);
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('picking CapCut ends choosing and shows "Sent 2 clips to '
        'CapCut"', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 2);
      await tester.tap(dockEdit());
      await settleApp(tester);

      await tester.tap(find.text('CapCut'));
      await settleApp(tester);

      expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
      expect(h.editors.sent.single.$1, EditorApp.capcut.packageName);
      expect(
        [for (final c in h.editors.sent.single.$2) c.mediaStoreId],
        [3, 2],
      );
      expect(find.byType(TtSheet), findsNothing);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(choosing(tester), isFalse);
      expect(find.byType(TtSelectionDock), findsNothing);
      expect(find.byType(TtNavPill), findsOneWidget);
      await flushReadyOffer(tester);
    });

    testApp('dismissing the sheet keeps the choice', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 2);
      await tester.tap(dockEdit());
      await settleApp(tester);
      expect(find.byType(TtSheet), findsOneWidget);

      // A tap on the scrim above the sheet.
      await tester.tapAt(const Offset(180, 40));
      await settleApp(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('2 selected'), findsOneWidget);
      expect(dock(tester).edit!.label, 'Edit 2 clips');
      expect(dock(tester).edit!.onPressed, isNotNull);
      expect(h.editors.sent, isEmpty);
    });

    testApp('Select all becomes Clear; Clear empties and keeps choosing', (
      tester,
    ) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 1);
      expect(topButton('Select all'), findsOneWidget);
      expect(topButton('Clear'), findsNothing);

      await tester.tap(topButton('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      expect(topButton('Select all'), findsNothing);
      expect(topButton('Clear'), findsOneWidget);

      await tester.tap(topButton('Clear'));
      await tester.pumpAndSettle();

      expect(choosing(tester), isTrue);
      expect(find.text('Choose clips'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [false, false, false]);
      expect(topButton('Select all'), findsOneWidget);
      expect(
        dock(tester).actions.map((a) => a.onPressed),
        everyElement(isNull),
      );
      // Choosing came from a long press, not the sheet: no hint.
      expect(hint(), findsNothing);
    });

    testApp('2x text: Select all is its icon with its name; the count does '
        'not overflow', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id, textScale: 2);
      await select(tester, 2);

      Finder icon(String label) => find.descendant(
        of: find.byType(TtAppBar),
        matching: barButton(label),
      );
      expect(topButton('Select all'), findsNothing);
      expect(icon('Select all'), findsOneWidget);
      expect(
        tester.widget<TtIconButton>(icon('Select all')).icon,
        Symbols.select_all_rounded,
      );
      expect(find.text('2 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(icon('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      expect(icon('Clear'), findsOneWidget);
      expect(
        tester.widget<TtIconButton>(icon('Clear')).icon,
        Symbols.deselect_rounded,
      );
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    for (final brightness in Brightness.values) {
      testApp('the page while choosing is accessible at 1x, '
          '${brightness.name}: from the sheet, then with a clip chosen', (
        tester,
      ) async {
        // The tap targets, their names and the text contrast (D-62). Not
        // Flutter's pixel sampler: it widens each text's box by 4 dp, and the
        // reel's name sits flush under the coloured selection bar, so it
        // takes the bar's colour for the text's (as with the bar before).
        Future<void> accessible() async {
          final semantics = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
          semantics.dispose();
        }

        final (goa, _) = await reelWithThree(tester);
        await open(tester, goa.id, brightness: brightness);

        await chooseInstead(tester);
        await accessible();

        await tester.tap(find.byType(TtClipTile).first);
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        await accessible();
      });
    }

    testApp('the top bar has no Add to, Move, Remove or ⋮', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 1);

      expect(
        [
          for (final b in tester.widgetList<TtIconButton>(
            find.descendant(
              of: find.byType(TtAppBar),
              matching: find.byType(TtIconButton),
            ),
          ))
            b.semanticLabel,
        ],
        ['Close'],
      );
      expect(
        find.descendant(
          of: find.byType(TtAppBar),
          matching: find.byType(TtButton),
        ),
        findsOneWidget,
      );
      expect(topButton('Select all'), findsOneWidget);
    });

    for (final (editor, name) in [
      (EditorApp.vn, 'VN'),
      (EditorApp.capcut, 'CapCut'),
      (EditorApp.edits, 'Edits'),
    ]) {
      testApp('during a session the dock has the note and no Edit ($name)', (
        tester,
      ) async {
        final (goa, _) = await reelWithThree(tester);
        await real(
          tester,
          () => h.container
              .read(editSessionsRepositoryProvider)
              .startSession(goa.id, editor, 'Goa'),
        );
        await open(tester, goa.id);
        await select(tester, 1);

        final d = dock(tester);
        expect(d.edit, isNull);
        expect(dockEdit(), findsNothing);
        expect(
          d.note,
          'This reel is being edited in $name. Tap Done editing at the top '
          'before sending clips again.',
        );
        // The four actions stay.
        expect(d.actions.map((a) => a.onPressed), everyElement(isNotNull));
      });
    }

    testApp('while the session loads, Edit is off', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(
        tester,
        goa.id,
        overrides: [
          // The database has not answered about the session yet.
          reelEditSessionProvider(goa.id)
              .overrideWith((ref) => const Stream<EditState?>.empty()),
        ],
      );
      await select(tester, 1);

      final d = dock(tester);
      expect(d.note, isNull);
      expect(d.edit!.label, 'Edit 1 clip');
      expect(d.edit!.onPressed, isNull);
      expect(d.actions.map((a) => a.onPressed), everyElement(isNotNull));
    });

    testApp('Done editing while choosing brings Edit back', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      final sessions = h.container.read(editSessionsRepositoryProvider);
      await real(
        tester,
        () => sessions.startSession(goa.id, EditorApp.capcut, 'Goa'),
      );
      await open(tester, goa.id);
      await select(tester, 1);
      expect(dock(tester).note, isNotNull);

      await real(tester, () => sessions.endSession(goa.id));
      await settleApp(tester);

      expect(dock(tester).note, isNull);
      expect(dock(tester).edit!.label, 'Edit 1 clip');
      expect(dock(tester).edit!.onPressed, isNotNull);
      // The choice stays.
      expect(find.text('1 selected'), findsOneWidget);
    });

    testApp('Share keeps the choice; Remove ends it with Undo', (tester) async {
      final (goa, ids) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 2);

      await tester.tap(dockAction('Share'));
      await settleApp(tester);
      expect(h.editors.chooserShares, hasLength(1));
      expect(sharedIds(), [3, 2]);
      expect(h.editors.chooserShares.single.$2, 'Share 2 videos');
      expect(h.editors.sent, isEmpty);
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(dockAction('Remove'));
      await settleApp(tester);

      expect(
        find.text(
          '2 clips removed from Goa. The videos are still in your gallery.',
        ),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsOneWidget);
      expect(choosing(tester), isFalse);
      expect(find.byType(TtSelectionDock), findsNothing);
      expect(await clipIdsOf(tester, goa.id), {ids[0]});
    });

    testApp('a second Share while the first is opening opens no second '
        'chooser', (tester) async {
      h.editors.hold('shareWithChooser');
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(dockAction('Share'));
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      await tester.tap(dockAction('Share'));
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      h.editors.release('shareWithChooser');
      await settleApp(tester);

      expect(h.editors.chooserShares, hasLength(1));
    });

    testApp('Share of one clip says Share video', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.tap(dockAction('Share'));
      await settleApp(tester);

      expect(h.editors.chooserShares.single.$2, 'Share video');
    });

    testApp('a chosen clip that goes missing is left out of the share', (
      tester,
    ) async {
      final (goa, ids) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 2);
      // Tiles are in shooting order: video 3 then video 2. Video 2 goes.
      await real(tester, () => flagForTest(h, {ids[1]}, missing: true));
      await settleApp(tester);

      await tester.tap(dockAction('Share'));
      await settleApp(tester);

      expect(sharedIds(), [3]);
      expect(h.editors.chooserShares.single.$2, 'Share video');
    });

    testApp('a snack shown while choosing sits above the dock', (tester) async {
      final (goa, ids) = await reelWithThree(tester);
      // Video 3 (the first tile) has a copy in a VN session, and deleting
      // it fails: the remove throws CopiesNotDeleted (R8).
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[2]]),
      );
      h.editors
        ..allow({'deleteCopies'})
        ..failNext('deleteCopies');
      // Tall enough for the editing banner and both parts.
      await open(tester, goa.id, size: const Size(360, 1400));
      await tester.longPress(
        find.byWidgetPredicate(
          (w) => w is TtClipTile && w.key == ValueKey(ids[2]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(dockAction('Remove'));
      await settleApp(tester);

      expect(
        find.text("Couldn't delete the copies. Try again."),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(find.byType(TtSnack)).dy,
        lessThanOrEqualTo(dockTop(tester)),
      );
      // The choice is kept to try again.
      expect(find.text('1 selected'), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });

    testApp('clips gone after the sheet opened: the failure in the sheet, '
        'the page stays', (tester) async {
      final (goa, ids) = await reelWithThree(tester);
      await open(tester, goa.id);
      await tapEditVideo(tester);
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));

      await tester.tap(find.text('CapCut'));
      await settleApp(tester);

      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text('These clips are missing from your phone.'),
        ),
        findsOneWidget,
      );
      expect(h.editors.sent, isEmpty);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(choosing(tester), isFalse);

      await tester.tapAt(const Offset(180, 40));
      await settleApp(tester);
      expect(find.byType(TtSheet), findsNothing);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(choosing(tester), isFalse);
      expect(find.byType(TtSelectionDock), findsNothing);
    });

    for (final scale in [1.0, 2.0]) {
      testApp('the last row scrolls clear of the dock, at ${scale}x', (
        tester,
      ) async {
        final goa = await newReel(tester, 'Goa');
        await reelWithClips(tester, goa, 15);
        await open(tester, goa.id, textScale: scale);
        await select(tester, 1);

        for (var i = 0; i < 4; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -2000),
          );
          await tester.pumpAndSettle();
        }

        final last = find.byType(TtClipTile).last;
        expect(
          tester.getBottomLeft(last).dy,
          lessThanOrEqualTo(dockTop(tester)),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testApp('Back ends choosing, then leaves the page', (tester) async {
      final (goa, _) = await reelWithThree(tester);
      await open(tester, goa.id);
      await select(tester, 1);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(choosing(tester), isFalse);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(find.byType(TtSelectionDock), findsNothing);
      expect(find.byType(TtNavPill), findsOneWidget);

      await tester.tap(barButton('Back'));
      await tester.pumpAndSettle();
      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    group('the dock and the page coming and going (F13)', () {
      /// A host in the shell's first tab that keeps reel [reelId]'s
      /// selection alive and shows its page only after "Open the page".
      Widget host(int reelId) => Consumer(
        builder: (context, ref, _) {
          ref.watch(reelSelectionProvider(reelId));
          return _PageHost(reelId: reelId);
        },
      );

      Future<void> pumpHost(WidgetTester tester, int reelId) async {
        await pumpScreen(
          tester,
          host(reelId),
          overrides: h.appOverrides,
          settle: false,
          inShell: true,
        );
        await settleApp(tester);
      }

      testApp('a page that opens already choosing has the dock on its first '
          'frame', (tester) async {
        final (goa, _) = await reelWithThree(tester);
        await pumpHost(tester, goa.id);
        expect(find.byType(TtNavPill), findsOneWidget);

        // Choosing starts before the page is built; the page's first frame
        // already chooses, and nothing told the shell while building.
        await tester.tap(find.text(_PageHost.openLabel));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ReelDetailScreen), findsOneWidget);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(TtSelectionDock), findsOneWidget);
        expect(find.byType(TtNavPill), findsNothing);
      });

      testApp('the page going away while choosing gives the nav pill back', (
        tester,
      ) async {
        final (goa, _) = await reelWithThree(tester);
        await pumpHost(tester, goa.id);
        await tester.tap(find.text(_PageHost.openLabel));
        await settleApp(tester);
        expect(find.byType(TtSelectionDock), findsOneWidget);

        _PageHost.close(tester);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ReelDetailScreen), findsNothing);
        expect(find.byType(TtSelectionDock), findsNothing);
        expect(find.byType(TtNavPill), findsOneWidget);
      });
    });
  });
}

/// Shows "Open the page" until it is tapped; the tap starts choosing on reel
/// [reelId] with nothing chosen and shows its page in the same frame.
class _PageHost extends ConsumerStatefulWidget {
  const _PageHost({required this.reelId});

  final int reelId;

  static const String openLabel = 'Open the page';

  /// Takes the page away again.
  static void close(WidgetTester tester) =>
      tester.state<_PageHostState>(find.byType(_PageHost)).setOpen(open: false);

  @override
  ConsumerState<_PageHost> createState() => _PageHostState();
}

class _PageHostState extends ConsumerState<_PageHost> {
  bool _open = false;

  void setOpen({required bool open}) => setState(() => _open = open);

  @override
  Widget build(BuildContext context) => _open
      ? ReelDetailScreen(reelId: widget.reelId)
      : Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () {
                ref.read(reelSelectionProvider(widget.reelId).notifier).begin();
                setOpen(open: true);
              },
              child: const Text(_PageHost.openLabel),
            ),
          ),
        );
}
