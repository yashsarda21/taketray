import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/tagging/view_models/last_tags.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The To tag list straight from the database, with no scan or verify: what
/// the screen sees in the app, without the phone behind it.
class DbToTag extends ToTagController {
  @override
  Stream<List<Clip>> build() =>
      ref.watch(clipsRepositoryProvider).watchInbox(InboxState.pending);
}

/// A clips repository whose tag, skip and skip-all writes fail.
class _FailingWrites extends ClipsRepository {
  _FailingWrites(VmHarness h) : super(h.media.db, h.media.clock);

  @override
  Future<List<AddUndo>> addClipsToReels(
    Set<int> reelIds,
    Iterable<int> clipIds,
  ) => Future.error(StateError('disk full'));

  @override
  Future<InboxUndo> skipClips(Iterable<int> clipIds) =>
      Future.error(StateError('disk full'));

  @override
  Future<InboxUndo> skipAllPending() => Future.error(StateError('disk full'));
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

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// To tag over the real database. [ids] are the clips, in order.
  late List<int> ids;

  /// Clips 1 to 3 at 09:01 to 09:03 UTC (one scene) and 4 and 5 at 15:00
  /// and 15:03 (another), 4 s each.
  Future<void> waiting(WidgetTester tester) async {
    ids = await real(
      tester,
      () => h.media.store([
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
        reelVideo(4, shot: DateTime.utc(2026, 10, 28, 15)),
        reelVideo(5, shot: DateTime.utc(2026, 10, 28, 15, 3)),
      ]),
    );
  }

  Future<Reel> newReel(WidgetTester tester, String name) =>
      real(tester, () => reels.create(name));

  Future<ProviderContainer> open(
    WidgetTester tester, {
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
    bool animations = false,
  }) async {
    final container = await pumpScreen(
      tester,
      const ToTagScreen(),
      overrides: [
        ...h.appOverrides,
        toTagControllerProvider.overrideWith(DbToTag.new),
        toTagTimesProvider.overrideWith(
          (ref) async => const <int, ClipLocalTime>{},
        ),
        ...overrides,
      ],
      textScale: textScale,
      brightness: brightness,
      animations: animations,
      settle: false,
    );
    await settleApp(tester);
    return container;
  }

  Future<List<int>> pendingIds(WidgetTester tester) async => [
    for (final c in await real(tester, () => h.media.toTag())) c.id,
  ];

  Future<List<int>> skippedIds(WidgetTester tester) async => [
    for (final c in await real(tester, () => h.media.skipped())) c.id,
  ];

  Future<Set<int>> clipIdsOf(WidgetTester tester, int reelId) async => {
    for (final c in await real(
      tester,
      () => clips.watchReelClips(reelId).first,
    ))
      c.clip.id,
  };

  List<TtClipTile> tiles(WidgetTester tester) =>
      tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

  Finder tagScene(int n) => find.widgetWithText(TtButton, 'Tag scene').at(n);

  Finder sheetButton(String label) =>
      find.widgetWithText(TtButton, label, skipOffstage: false);

  Finder pickRow(String name) => find.byWidgetPredicate(
    (w) => w is TtReelPickRow && w.name == name,
    description: 'the "$name" row',
  );

  String? sheetTitle(WidgetTester tester) =>
      tester.widget<TtSheet>(find.byType(TtSheet)).title;

  Finder barButton(String label) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == label,
    description: 'the "$label" button',
  );

  Future<void> snackUndo(WidgetTester tester) async {
    await tester.tap(find.text('Undo'));
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('tagging a scene', () {
    testApp('tag scene opens the picker in tag mode and tags', (tester) async {
      await waiting(tester);
      final london = await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      final container = await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);

      // Tag mode: its own title and line, every reel listed (nothing is
      // left out, the clips are in no reel), nothing picked yet.
      expect(sheetTitle(tester), 'Tag 3 clips');
      expect(find.text('Pick one or more reels.'), findsOneWidget);
      expect(find.byType(TtReelPickRow), findsNWidgets(2));
      expect(
        tester.widget<TtButton>(sheetButton('Tag 3 clips')).onPressed,
        isNull,
      );

      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);

      // The scene's three clips went to the reel and left To tag; the other
      // scene is untouched.
      expect(find.byType(TtSheet), findsNothing);
      expect(await clipIdsOf(tester, london.id), {ids[0], ids[1], ids[2]});
      expect(await pendingIds(tester), [ids[3], ids[4]]);
      expect(tiles(tester), hasLength(2));
      expect(find.text('2 clips · 1 scene · 8 s'), findsOneWidget);
      expect(find.text('3 clips added to London Food'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      // "Same as previous" in the player follows it.
      expect(container.read(lastTagsProvider), [london.id]);
    });

    testApp('picker tag confirm text one reel and several', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      await open(tester);

      // The second scene has two clips: "Tag 2 clips".
      await tester.tap(tagScene(1));
      await settleApp(tester);
      expect(sheetTitle(tester), 'Tag 2 clips');
      expect(sheetButton('Tag 2 clips'), findsOneWidget);

      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      expect(sheetButton('Tag 2 clips'), findsOneWidget);
      expect(
        tester.widget<TtButton>(sheetButton('Tag 2 clips')).onPressed,
        isNotNull,
      );

      await tester.tap(pickRow('Goa Trip'));
      await tester.pumpAndSettle();
      expect(sheetButton('Tag into 2 reels'), findsOneWidget);
      await tester.tap(pickRow('Sunsets'));
      await tester.pumpAndSettle();
      expect(sheetButton('Tag into 3 reels'), findsOneWidget);

      // Back to one reel, and to none (the button waits again).
      await tester.tap(pickRow('Goa Trip'));
      await tester.tap(pickRow('Sunsets'));
      await tester.pumpAndSettle();
      expect(sheetButton('Tag 2 clips'), findsOneWidget);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TtButton>(sheetButton('Tag 2 clips')).onPressed,
        isNull,
      );
    });

    testApp('one clip: "Tag 1 clip"', (tester) async {
      await real(tester, () => h.media.store([reelVideo(1)]));
      await newReel(tester, 'London Food');
      await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);

      expect(sheetTitle(tester), 'Tag 1 clip');
      expect(sheetButton('Tag 1 clip'), findsOneWidget);
    });

    testApp('several reels: one snack naming them, all of them get the '
        'clips', (tester) async {
      await waiting(tester);
      final a = await newReel(tester, 'A');
      final b = await newReel(tester, 'B');
      final c = await newReel(tester, 'C');
      final container = await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('A'));
      await tester.tap(pickRow('B'));
      await tester.tap(pickRow('C'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag into 3 reels'));
      await settleApp(tester);

      expect(find.text('3 clips added to A, B and 1 more'), findsOneWidget);
      for (final reel in [a, b, c]) {
        expect(await clipIdsOf(tester, reel.id), {ids[0], ids[1], ids[2]});
      }
      expect(container.read(lastTagsProvider), [a.id, b.id, c.id]);
    });

    testApp('two reels: "{n} clips added to A and B"', (tester) async {
      await waiting(tester);
      await newReel(tester, 'A');
      await newReel(tester, 'B');
      await open(tester);

      await tester.tap(tagScene(1));
      await settleApp(tester);
      await tester.tap(pickRow('A'));
      await tester.tap(pickRow('B'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag into 2 reels'));
      await settleApp(tester);

      expect(find.text('2 clips added to A and B'), findsOneWidget);
    });

    testApp('tag snack undo puts them back', (tester) async {
      await waiting(tester);
      final london = await newReel(tester, 'London Food');
      final container = await open(tester);
      container.read(lastTagsProvider.notifier).set([999]);
      final before = await real(tester, () => h.media.toTag());

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);
      expect(await pendingIds(tester), [ids[3], ids[4]]);
      expect(container.read(lastTagsProvider), [london.id]);

      await snackUndo(tester);

      // The same clips are back in To tag, in the same order, and out of the
      // reel; "Same as previous" is what it was.
      expect(await pendingIds(tester), [for (final c in before) c.id]);
      expect(await clipIdsOf(tester, london.id), isEmpty);
      expect(tiles(tester), hasLength(5));
      expect(container.read(lastTagsProvider), [999]);
    });

    testApp('undo leaves a later tag of Same as previous alone', (
      tester,
    ) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      final container = await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);
      // Another tag (the player) is remembered after this one.
      container.read(lastTagsProvider.notifier).set([42]);

      await snackUndo(tester);

      expect(container.read(lastTagsProvider), [42]);
    });

    testApp('the tag snack counts the clips really added', (tester) async {
      await waiting(tester);
      final goa = await newReel(tester, 'Goa');
      await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      // While the picker is open, the first clip goes into Goa elsewhere.
      await real(tester, () => clips.addClipsToReel(goa.id, [ids[0]]));
      await tester.tap(pickRow('Goa'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);

      // Two clips got a new place in Goa; the first was there already.
      expect(find.text('2 clips added to Goa'), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), {ids[0], ids[1], ids[2]});
    });

    testApp('cancel changes nothing', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      final container = await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Cancel'));
      await settleApp(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect(await pendingIds(tester), ids);
      expect(find.text('Undo'), findsNothing);
      expect(container.read(lastTagsProvider), isEmpty);
    });

    testApp('a double tap on Tag scene opens one picker', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await open(tester);

      await tester.tap(tagScene(0));
      await tester.tap(tagScene(0), warnIfMissed: false);
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('a clip removed by a verify while the picker is open is dropped: '
        'confirm tags the rest (Phase 5 later item)', (tester) async {
      await waiting(tester);
      final london = await newReel(tester, 'London Food');
      final container = await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      // A verify finds clip 2's video gone: it leaves To tag and is deleted.
      await real(
        tester,
        () => clips.applyVerification(
          found: const {},
          gone: {ids[1]},
          otherVideo: const {},
        ),
      );
      await settleApp(tester);
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
      expect(await clipIdsOf(tester, london.id), {ids[0], ids[2]});
      expect(find.text('2 clips added to London Food'), findsOneWidget);
      expect(container.read(lastTagsProvider), [london.id]);
    });

    testApp('every clip removed while the picker is open: confirm closes the '
        'sheet with no snack and remembers nothing', (tester) async {
      await waiting(tester);
      final london = await newReel(tester, 'London Food');
      final container = await open(tester);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await real(
        tester,
        () => clips.applyVerification(
          found: const {},
          gone: {ids[0], ids[1], ids[2]},
          otherVideo: const {},
        ),
      );
      await settleApp(tester);
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
      expect(await clipIdsOf(tester, london.id), isEmpty);
      expect(find.textContaining('added to'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(container.read(lastTagsProvider), isEmpty);
    });

    testApp('a failed tag is told in the sheet and remembers nothing', (
      tester,
    ) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      final container = await open(
        tester,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingWrites(h)),
        ],
      );

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 3 clips'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(await pendingIds(tester), ids);
      expect(container.read(lastTagsProvider), isEmpty);
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('tagged tiles leave (Scene tagging motion)', () {
    /// The opacity of each tile that is on its way out, in screen order.
    List<double> fading(WidgetTester tester) => [
      for (final f in tester.widgetList<FadeTransition>(
        find.byWidgetPredicate(
          (w) => w is FadeTransition && w.child is TtClipTile,
        ),
      ))
        f.opacity.value,
    ];

    /// Confirms a tag of the first scene (3 clips) into London Food and
    /// steps until its tiles start to leave.
    Future<void> tagFirstScene(WidgetTester tester) async {
      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 3 clips'));
      await tester.runAsync(settle);
      for (var i = 0; i < 100 && fading(tester).isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    testApp('the scene fades out one tile after another, then the rest moves '
        'up', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await open(tester, animations: true);
      final scenesTop = tester.getTopLeft(find.byType(TtSceneHeader).last).dy;

      await tagFirstScene(tester);

      // The tagged tiles are still there, whole, as the run begins; the
      // list is the one from before the tag.
      expect(tiles(tester), hasLength(5));
      expect(fading(tester), [1.0, 1.0, 1.0]);

      await tester.pump(const Duration(milliseconds: 90));
      final mid = fading(tester);
      // Staggered: the first is furthest gone, the last has not begun or
      // has only begun, and nothing outside the scene fades.
      expect(mid, hasLength(3));
      expect(mid[0], lessThan(mid[1]));
      expect(mid[1], lessThan(mid[2]));
      expect(mid[0], lessThan(1));
      // The second scene moves up as the first folds away.
      expect(
        tester.getTopLeft(find.byType(TtSceneHeader).last).dy,
        lessThan(scenesTop),
      );
      // Nothing can be tapped on the way out.
      expect(
        tester
            .widget<IgnorePointer>(
              find.byWidgetPredicate(
                (w) => w is IgnorePointer && w.child is CustomScrollView,
              ),
            )
            .ignoring,
        isTrue,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tiles(tester), hasLength(2));
      expect(fading(tester), isEmpty);
      expect(find.byType(TtSceneHeader), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find.byWidgetPredicate(
                (w) => w is IgnorePointer && w.child is CustomScrollView,
              ),
            )
            .ignoring,
        isFalse,
      );
    });

    testApp('reduced motion: they fade together in 150 ms', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await open(tester);
      final scenesTop = tester.getTopLeft(find.byType(TtSceneHeader).last).dy;

      await tagFirstScene(tester);
      expect(fading(tester), [1.0, 1.0, 1.0]);

      await tester.pump(const Duration(milliseconds: 75));
      final mid = fading(tester);
      expect(mid, hasLength(3));
      // No stagger: all three are at the same point.
      expect(mid[0], closeTo(mid[1], 1e-9));
      expect(mid[1], closeTo(mid[2], 1e-9));
      expect(mid[0], inExclusiveRange(0, 1));
      // A fade only: no row folds, so nothing below moves during the run.
      expect(tester.getTopLeft(find.byType(TtSceneHeader).last).dy, scenesTop);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tiles(tester), hasLength(2));
    });

    testApp('a cancelled picker plays nothing', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await open(tester, animations: true);

      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(sheetButton('Cancel'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(fading(tester), isEmpty);
      expect(tiles(tester), hasLength(5));
    });

    testApp('leaving the screen mid-run throws nothing', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await open(tester, animations: true);

      await tagFirstScene(tester);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });

  group('tagging the chosen clips', () {
    testApp('Tag opens the picker for the chosen clips and ends choosing', (
      tester,
    ) async {
      await waiting(tester);
      final london = await newReel(tester, 'London Food');
      await open(tester);
      await tester.longPress(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).at(4));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Tag'));
      await settleApp(tester);
      expect(sheetTitle(tester), 'Tag 2 clips');
      await tester.tap(pickRow('London Food'));
      await tester.pumpAndSettle();
      await tester.tap(sheetButton('Tag 2 clips'));
      await settleApp(tester);

      expect(await clipIdsOf(tester, london.id), {ids[1], ids[4]});
      expect(await pendingIds(tester), [ids[0], ids[2], ids[3]]);
      expect(find.text('2 clips added to London Food'), findsOneWidget);
      // Choosing is over.
      expect(find.textContaining('selected'), findsNothing);
      expect(find.text('Start tagging'), findsOneWidget);
    });

    testApp('cancelling the picker keeps the choice', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await open(tester);
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Tag'));
      await settleApp(tester);
      await tester.tap(sheetButton('Cancel'));
      await settleApp(tester);

      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  group('Skip on the selection bar', () {
    testApp('selection skip with undo', (tester) async {
      await waiting(tester);
      await open(tester);
      await tester.longPress(find.byType(TtClipTile).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).at(3));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Skip'));
      await settleApp(tester);

      expect(await skippedIds(tester), [ids[0], ids[3]]);
      expect(await pendingIds(tester), [ids[1], ids[2], ids[4]]);
      expect(find.text('2 clips skipped'), findsOneWidget);
      expect(find.textContaining('selected'), findsNothing);
      expect(tiles(tester), hasLength(3));
      // The button now shows how many are skipped.
      expect(find.text('Skipped (2)'), findsWidgets);

      await snackUndo(tester);

      expect(await skippedIds(tester), isEmpty);
      expect(await pendingIds(tester), ids);
      expect(tiles(tester), hasLength(5));
    });

    testApp('one clip: "1 clip skipped"', (tester) async {
      await waiting(tester);
      await open(tester);
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Skip'));
      await settleApp(tester);

      expect(find.text('1 clip skipped'), findsOneWidget);
    });

    testApp('a clip that left meanwhile is not counted', (tester) async {
      await waiting(tester);
      final london = await newReel(tester, 'London Food');
      await open(tester);
      await tester.longPress(find.byType(TtClipTile).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      // Clip 2 is tagged elsewhere between the choice and the tap.
      await real(tester, () => clips.addClipsToReel(london.id, [ids[1]]));
      await settleApp(tester);
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(TtButton, 'Skip'));
      await settleApp(tester);

      expect(find.text('1 clip skipped'), findsOneWidget);
      expect(await skippedIds(tester), [ids[0]]);
      expect(await clipIdsOf(tester, london.id), {ids[1]});
    });

    testApp('a failed skip tells the user and keeps the choice', (
      tester,
    ) async {
      await waiting(tester);
      await open(
        tester,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingWrites(h)),
        ],
      );
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Skip'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      expect(await pendingIds(tester), ids);
    });
  });

  group('Skip all', () {
    Future<void> openSkipAll(WidgetTester tester) async {
      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip all'));
      await tester.pumpAndSettle();
    }

    testApp('skip all asks then skips with undo', (tester) async {
      await waiting(tester);
      await open(tester);

      await openSkipAll(tester);

      // Asked first, and nothing has moved yet.
      expect(find.text('Skip all 5 clips?'), findsOneWidget);
      expect(
        find.text('They move to Skipped, and you can restore them any time.'),
        findsOneWidget,
      );
      expect(find.text('Your videos stay in your gallery.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(await skippedIds(tester), isEmpty);
      expect(await pendingIds(tester), ids);

      await tester.tap(
        find.descendant(
          of: find.byType(TtDialog<bool>),
          matching: find.text('Skip all'),
        ),
      );
      await settleApp(tester);

      expect(await skippedIds(tester), ids);
      expect(await pendingIds(tester), isEmpty);
      expect(find.text('5 clips skipped'), findsOneWidget);
      // The empty state, with the Skipped button.
      expect(find.text('Nothing to tag'), findsOneWidget);
      expect(find.text('Skipped (5)'), findsOneWidget);

      await snackUndo(tester);

      expect(await skippedIds(tester), isEmpty);
      expect(await pendingIds(tester), ids);
      expect(tiles(tester), hasLength(5));
    });

    testApp('skip all skips the clips the dialog counted', (tester) async {
      await waiting(tester);
      await open(tester);

      await openSkipAll(tester);
      expect(find.text('Skip all 5 clips?'), findsOneWidget);
      // A scan adds a clip while the dialog is open.
      final late = await real(
        tester,
        () =>
            h.media.store([reelVideo(6, shot: DateTime.utc(2026, 10, 28, 16))]),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(TtDialog<bool>),
          matching: find.text('Skip all'),
        ),
      );
      await settleApp(tester);

      // The five it asked about, and the snack agrees; the new one waits.
      expect(find.text('5 clips skipped'), findsOneWidget);
      expect(await skippedIds(tester), ids);
      expect(await pendingIds(tester), late);
    });

    testApp('cancel skip all changes nothing', (tester) async {
      await waiting(tester);
      await open(tester);

      await openSkipAll(tester);
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(await skippedIds(tester), isEmpty);
      expect(await pendingIds(tester), ids);
      expect(find.textContaining('skipped'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(tiles(tester), hasLength(5));
    });

    testApp('a tap outside the dialog changes nothing', (tester) async {
      await waiting(tester);
      await open(tester);

      await openSkipAll(tester);
      await tester.tapAt(const Offset(4, 4));
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(await pendingIds(tester), ids);
    });

    testApp('skip all with one clip asks about one', (tester) async {
      await real(tester, () => h.media.store([reelVideo(1)]));
      await open(tester);

      await openSkipAll(tester);

      expect(find.text('Skip 1 clip?'), findsOneWidget);
    });

    testApp('a failed skip all tells the user, nothing moved', (tester) async {
      await waiting(tester);
      await open(
        tester,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingWrites(h)),
        ],
      );

      await openSkipAll(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(TtDialog<bool>),
          matching: find.text('Skip all'),
        ),
      );
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(await pendingIds(tester), ids);
    });

    testApp('skip all clears a choice that was open', (tester) async {
      await waiting(tester);
      await open(tester);
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      // While choosing, the app bar is the selection bar: Skip all is in the
      // menu of the plain bar only, so end choosing first, as a user does.
      await tester.tap(barButton('Close'));
      await tester.pumpAndSettle();

      await openSkipAll(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(TtDialog<bool>),
          matching: find.text('Skip all'),
        ),
      );
      await settleApp(tester);

      expect(find.textContaining('selected'), findsNothing);
      expect(await skippedIds(tester), ids);
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testApp('${brightness.name}: the picker in tag mode, accessible', (
        tester,
      ) async {
        await waiting(tester);
        await newReel(tester, 'London Food');
        await newReel(tester, 'Goa Trip');
        await open(tester, brightness: brightness);
        await tester.tap(tagScene(0));
        await settleApp(tester);

        await expectTtAccessible(tester);
      });

      testApp('${brightness.name}: the Skip all dialog, accessible', (
        tester,
      ) async {
        await waiting(tester);
        await open(tester, brightness: brightness);
        await tester.tap(barButton('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip all'));
        await tester.pumpAndSettle();

        await expectTtAccessible(tester);
      });
    }

    testApp('2x text: the picker and the dialog fit', (tester) async {
      await waiting(tester);
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await open(tester, textScale: 2);
      await tester.tap(tagScene(0));
      await settleApp(tester);
      await tester.tap(pickRow('London Food'));
      await tester.tap(pickRow('Goa Trip'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
      await tester.tap(sheetButton('Cancel'));
      await settleApp(tester);

      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip all'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });
  });
}
