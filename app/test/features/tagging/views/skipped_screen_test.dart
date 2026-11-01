import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/tagging/view_models/skipped_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/views/skipped_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import 'to_tag_actions_test.dart' show DbToTag;

/// The Skipped list straight from the database, with no verify: what the
/// screen sees in the app, without the phone behind it.
class DbSkipped extends SkippedController {
  @override
  Stream<List<Clip>> build() => ref
      .watch(clipsRepositoryProvider)
      .watchInbox(InboxState.skipped)
      .map((oldestFirst) => oldestFirst.reversed.toList());
}

/// A clips repository that counts restores and can hold the first one.
class _CountingRestores extends ClipsRepository {
  _CountingRestores(VmHarness h) : super(h.media.db, h.media.clock);

  int restores = 0;
  Completer<void>? gate;

  @override
  Future<InboxUndo> restoreClips(Iterable<int> clipIds) async {
    restores++;
    await gate?.future;
    return await super.restoreClips(clipIds);
  }
}

/// A clips repository whose restore fails.
class _FailingRestore extends ClipsRepository {
  _FailingRestore(VmHarness h) : super(h.media.db, h.media.clock);

  @override
  Future<InboxUndo> restoreClips(Iterable<int> clipIds) =>
      Future.error(StateError('disk full'));
}

/// A skipped list whose first build fails and later ones show the database.
class _FailsOnce extends DbSkipped {
  int builds = 0;

  @override
  Stream<List<Clip>> build() {
    builds++;
    if (builds == 1) return Stream.error(StateError('the database failed'));
    return super.build();
  }
}

final List<DateTime> _threeDayShots = [
  DateTime.utc(2026, 10, 28, 12, 1),
  DateTime.utc(2026, 10, 28, 12, 2),
  DateTime.utc(2026, 10, 29, 12, 5),
  DateTime.utc(2026, 10, 30, 11),
];

/// A Skipped list with a clip flagged missing among the others (the verifier
/// takes such a clip out of the database, so the screen only ever meets one
/// for a moment).
class _WithMissing extends SkippedController {
  @override
  Stream<List<Clip>> build() => Stream.value([
    testClip(2, shot: DateTime.utc(2026, 10, 28, 12, 2), missing: true),
    testClip(1, shot: DateTime.utc(2026, 10, 28, 12, 1)),
  ]);
}

void main() {
  late VmHarness h;
  late ClipsRepository clips;

  setUp(() {
    h = reelHarness();
    clips = h.container.read(clipsRepositoryProvider);
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Stores [shots] as clips 1..n (4 s each, in order), skips every one of
  /// them, and returns their ids.
  Future<List<int>> skipped(WidgetTester tester, List<DateTime> shots) async {
    final ids = await real(
      tester,
      () => h.media.store([
        for (var i = 0; i < shots.length; i++) reelVideo(i + 1, shot: shots[i]),
      ]),
    );
    await real(tester, () => clips.skipClips(ids));
    return ids;
  }

  /// Four skipped clips over three days: Wed Oct 28 (two), Thu Oct 29 (one)
  /// and Fri Oct 30, the phone's today (one). The ids are in the order of
  /// the times, oldest first.
  Future<List<int>> threeDays(WidgetTester tester) =>
      skipped(tester, _threeDayShots);

  Future<ProviderContainer> open(
    WidgetTester tester, {
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Override? controller,
    bool verify = false,
  }) async {
    final container = await pumpScreen(
      tester,
      const SkippedScreen(),
      overrides: [
        ...h.appOverrides,
        ?controller,
        if (!verify && controller == null)
          skippedControllerProvider.overrideWith(DbSkipped.new),
        toTagControllerProvider.overrideWith(DbToTag.new),
        skippedTimesProvider.overrideWith(
          (ref) async => const <int, ClipLocalTime>{},
        ),
        ...overrides,
      ],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    return container;
  }

  Future<List<int>> skippedIds(WidgetTester tester) async => [
    for (final c in await real(tester, () => h.media.skipped())) c.id,
  ];

  Future<List<int>> pendingIds(WidgetTester tester) async => [
    for (final c in await real(tester, () => h.media.toTag())) c.id,
  ];

  List<TtClipTile> tiles(WidgetTester tester) =>
      tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

  /// The clip ids of the tiles, top to bottom, left to right.
  List<Object?> tileIds(WidgetTester tester) => [
    for (final tile in tiles(tester)) (tile.key! as ValueKey<Object?>).value,
  ];

  Finder tile(int clipId) => find.byKey(ValueKey(clipId));

  List<String> dayHeaders(WidgetTester tester) => [
    for (final header in tester.widgetList<TtDayHeader>(
      find.byType(TtDayHeader),
    ))
      // A day's date keeps its spaces together (no-break); plain ones here.
      '${header.title.replaceAll('\u00a0', ' ')}|${header.trailing}',
  ];

  Future<void> snackUndo(WidgetTester tester) async {
    await tester.tap(find.text('Undo'));
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.widgetWithText(TtButton, label);

  testApp('newest day first', (tester) async {
    final ids = await threeDays(tester);
    await open(tester);

    // The days, newest first, each with its count; the phone's day is Oct 30.
    expect(dayHeaders(tester), [
      'Today · Fri, Oct 30|1 clip',
      'Yesterday · Thu, Oct 29|1 clip',
      'Wed, Oct 28|2 clips',
    ]);
    // Newest clip first inside a day, as the prototype's list sorts them.
    expect(tileIds(tester), [ids[3], ids[2], ids[1], ids[0]]);
    // The note, and Select on the bar.
    expect(
      find.text(
        'Skipped clips are still in your gallery. Restore any you want to tag.',
      ),
      findsOneWidget,
    );
    expect(button('Select'), findsOneWidget);
    expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).title, 'Skipped');
  });

  testApp('tap restores with undo', (tester) async {
    final ids = await threeDays(tester);
    await open(tester);

    await tester.tap(tile(ids[2]));
    await settleApp(tester);

    // The clip left Skipped for To tag; the snack says so with Undo.
    expect(await pendingIds(tester), [ids[2]]);
    expect(await skippedIds(tester), [ids[0], ids[1], ids[3]]);
    expect(tile(ids[2]), findsNothing);
    expect(find.text('Restored to To tag'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    // Its day had one clip, so the day went too.
    expect(dayHeaders(tester), [
      'Today · Fri, Oct 30|1 clip',
      'Wed, Oct 28|2 clips',
    ]);

    await snackUndo(tester);

    // The same clip is back in Skipped, in its day, and out of To tag.
    expect(await pendingIds(tester), isEmpty);
    expect(await skippedIds(tester), [ids[0], ids[1], ids[2], ids[3]]);
    expect(tile(ids[2]), findsOneWidget);
    expect(find.text('Restored to To tag'), findsNothing);
  });

  testApp('select and restore several', (tester) async {
    final ids = await threeDays(tester);
    await open(tester);

    await tester.tap(button('Select'));
    await tester.pumpAndSettle();
    // Choosing with nothing chosen: the bar says so and Restore waits.
    expect(find.text('0 selected'), findsOneWidget);
    expect(tester.widget<TtButton>(button('Restore')).onPressed, isNull);

    await tester.tap(tile(ids[0]));
    await tester.pumpAndSettle();
    await tester.tap(tile(ids[3]));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    // While choosing a tap chooses: nothing was restored.
    expect(await pendingIds(tester), isEmpty);

    await tester.tap(button('Restore'));
    await settleApp(tester);

    expect(await pendingIds(tester), [ids[0], ids[3]]);
    expect(await skippedIds(tester), [ids[1], ids[2]]);
    expect(find.text('2 clips restored to To tag'), findsOneWidget);
    // Choosing is over: the plain bar is back.
    expect(find.textContaining('selected'), findsNothing);
    expect(button('Select'), findsOneWidget);

    await snackUndo(tester);

    expect(await pendingIds(tester), isEmpty);
    expect(await skippedIds(tester), [ids[0], ids[1], ids[2], ids[3]]);
    expect(tileIds(tester), [ids[3], ids[2], ids[1], ids[0]]);
  });

  testApp('one chosen clip says "1 clip restored to To tag"', (tester) async {
    final ids = await threeDays(tester);
    await open(tester);

    await tester.longPress(tile(ids[1]));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(button('Restore'));
    await settleApp(tester);

    expect(find.text('1 clip restored to To tag'), findsOneWidget);
    expect(await pendingIds(tester), [ids[1]]);
  });

  testApp('restored clip shows in To tag', (tester) async {
    final ids = await threeDays(tester);
    // A clip already waiting, shot between the skipped ones of Oct 28.
    final waiting = await real(
      tester,
      () => h.media.store([
        reelVideo(9, shot: DateTime.utc(2026, 10, 28, 12, 1, 30)),
      ]),
    );
    final container = await open(tester);
    // To tag is not on screen here: hold its list open, as its screen does.
    container.listen(toTagControllerProvider, (_, _) {});

    await tester.tap(tile(ids[1]));
    await settleApp(tester);

    // To tag lists it in shooting order with the clip that waited.
    final toTag = await container.read(toTagControllerProvider.future);
    expect([for (final c in toTag) c.id], [waiting.single, ids[1]]);
    expect(await skippedIds(tester), [ids[0], ids[2], ids[3]]);
  });

  testApp('empty state', (tester) async {
    await open(tester);

    expect(find.text('No skipped clips'), findsOneWidget);
    expect(
      find.text(
        'Clips you skip in To tag show up here, in case you change your mind.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TtEmptyState>(find.byType(TtEmptyState)).illustration,
      TtIllustrationKind.skipped,
    );
    // Nothing to choose, no note.
    expect(button('Select'), findsNothing);
    expect(find.byType(TtInfoBar), findsNothing);
    expect(find.byType(TtClipTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testApp('missing skipped clip is verified away', (tester) async {
    // Two skipped clips; only video 1 is still on the phone.
    h.bridge.put([reelVideo(1, shot: DateTime.utc(2026, 10, 28, 12, 1))]);
    await skipped(tester, [
      DateTime.utc(2026, 10, 28, 12, 1),
      DateTime.utc(2026, 10, 28, 12, 2),
    ]);
    final all = await real(tester, () => h.media.skipped());
    expect(all, hasLength(2));

    await open(tester, verify: true);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settleApp(tester);

    // The one whose video is gone has left the list, and the database.
    expect(tiles(tester), hasLength(1));
    final left = await skippedIds(tester);
    expect(left, [all.first.id]);
    expect(tileIds(tester), left);
    expect(dayHeaders(tester), ['Wed, Oct 28|1 clip']);
  });

  group('restoring once', () {
    testApp('a double tap restores once', (tester) async {
      final ids = await threeDays(tester);
      final counting = _CountingRestores(h)..gate = Completer<void>();
      await open(
        tester,
        overrides: [clipsRepositoryProvider.overrideWithValue(counting)],
      );

      await tester.tap(tile(ids[0]));
      await tester.pump();
      await tester.tap(tile(ids[0]));
      await tester.pump();
      counting.gate!.complete();
      await settleApp(tester);

      expect(counting.restores, 1);
      expect(await pendingIds(tester), [ids[0]]);
      expect(find.text('Restored to To tag'), findsOneWidget);
    });

    testApp('two different tiles each restore', (tester) async {
      final ids = await threeDays(tester);
      final counting = _CountingRestores(h);
      await open(
        tester,
        overrides: [clipsRepositoryProvider.overrideWithValue(counting)],
      );

      await tester.tap(tile(ids[0]));
      await settleApp(tester);
      await tester.tap(tile(ids[3]));
      await settleApp(tester);

      expect(counting.restores, 2);
      expect(await pendingIds(tester), [ids[0], ids[3]]);
      // Only the latest snack, and only it offers Undo.
      expect(find.text('Restored to To tag'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testApp('a double tap on Restore restores once', (tester) async {
      final ids = await threeDays(tester);
      final counting = _CountingRestores(h)..gate = Completer<void>();
      await open(
        tester,
        overrides: [clipsRepositoryProvider.overrideWithValue(counting)],
      );
      await tester.longPress(tile(ids[0]));
      await tester.pumpAndSettle();
      await tester.tap(tile(ids[1]));
      await tester.pumpAndSettle();

      await tester.tap(button('Restore'));
      await tester.pump();
      await tester.tap(button('Restore'));
      await tester.pump();
      counting.gate!.complete();
      await settleApp(tester);

      expect(counting.restores, 1);
      expect(find.text('2 clips restored to To tag'), findsOneWidget);
    });

    testApp('a clip tagged elsewhere meanwhile says nothing', (tester) async {
      final ids = await threeDays(tester);
      final counting = _CountingRestores(h)..gate = Completer<void>();
      await open(
        tester,
        overrides: [clipsRepositoryProvider.overrideWithValue(counting)],
      );

      await tester.tap(tile(ids[0]));
      await tester.pump();
      // Meanwhile the clip is restored from elsewhere (and so not skipped).
      await real(tester, () => clips.restoreClips({ids[0]}));
      counting.gate!.complete();
      await settleApp(tester);

      expect(find.text('Restored to To tag'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(await pendingIds(tester), [ids[0]]);
    });

    testApp('undo still works after leaving the screen', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);
      await tester.tap(tile(ids[1]));
      await settleApp(tester);
      expect(await pendingIds(tester), [ids[1]]);

      // Back: nothing to pop, so the screen goes to To tag.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Back',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(toTagRouteMarker), findsOneWidget);
      expect(find.byType(SkippedScreen), findsNothing);

      await snackUndo(tester);

      expect(await pendingIds(tester), isEmpty);
      expect(await skippedIds(tester), [ids[0], ids[1], ids[2], ids[3]]);
    });

    testApp('a failed restore says so and keeps the choice', (tester) async {
      final ids = await threeDays(tester);
      await open(
        tester,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingRestore(h)),
        ],
      );
      await tester.longPress(tile(ids[0]));
      await tester.pumpAndSettle();

      await tester.tap(button('Restore'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
      expect(await skippedIds(tester), [ids[0], ids[1], ids[2], ids[3]]);
      expect(tester.takeException(), isNull);
    });

    testApp('a failed tap says so and the clip stays', (tester) async {
      final ids = await threeDays(tester);
      await open(
        tester,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingRestore(h)),
        ],
      );

      await tester.tap(tile(ids[0]));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(tile(ids[0]), findsOneWidget);
    });
  });

  group('choosing', () {
    testApp('a long press starts choosing', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);

      await tester.longPress(tile(ids[2]));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.widget<TtClipTile>(tile(ids[2])).selected, isTrue);
      expect(tester.widget<TtClipTile>(tile(ids[0])).selected, isFalse);
      // Un-choosing the last clip ends choosing.
      await tester.tap(tile(ids[2]));
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);
      expect(button('Select'), findsOneWidget);
    });

    testApp('back clears the choice before it leaves', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);
      await tester.longPress(tile(ids[0]));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Still on Skipped, nothing chosen.
      expect(find.textContaining('selected'), findsNothing);
      expect(find.byType(SkippedScreen), findsOneWidget);
      expect(find.text(toTagRouteMarker), findsNothing);
      expect(tiles(tester).map((t) => t.selected), everyElement(isNull));

      // With nothing chosen, Back leaves.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Back',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(toTagRouteMarker), findsOneWidget);
    });

    testApp(
      'a missing clip shows as missing and cannot be restored or chosen',
      (tester) async {
        await open(
          tester,
          controller: skippedControllerProvider.overrideWith(_WithMissing.new),
        );

        expect(find.byType(TtMissingClipTile), findsOneWidget);
        expect(find.byType(TtClipTile), findsOneWidget);
        // A tap and a long press on it do nothing.
        await tester.tap(find.byType(TtMissingClipTile));
        await tester.longPress(find.byType(TtMissingClipTile));
        await tester.pumpAndSettle();
        expect(find.text('Restored to To tag'), findsNothing);
        expect(find.textContaining('selected'), findsNothing);
        // While choosing it cannot be chosen either.
        await tester.tap(button('Select'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TtMissingClipTile));
        await tester.pumpAndSettle();
        expect(find.text('0 selected'), findsOneWidget);
        await tester.tap(find.byType(TtClipTile));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
      },
    );

    testApp('close ends choosing', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);
      await tester.longPress(tile(ids[0]));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Close',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(await skippedIds(tester), hasLength(4));
    });

    testApp('a chosen clip that leaves Skipped is un-chosen', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);
      await tester.longPress(tile(ids[0]));
      await tester.pumpAndSettle();
      await tester.tap(tile(ids[1]));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // One of them is tagged elsewhere.
      await real(tester, () => clips.restoreClips({ids[1]}));
      await settleApp(tester);

      expect(find.text('1 selected'), findsOneWidget);
      expect(tile(ids[1]), findsNothing);

      await tester.tap(button('Restore'));
      await settleApp(tester);
      expect(find.text('1 clip restored to To tag'), findsOneWidget);
    });

    testApp('choosing ends when the list empties', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);
      await tester.tap(button('Select'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);

      // Everything is restored from elsewhere.
      await real(tester, () => clips.restoreClips(ids));
      await settleApp(tester);

      expect(find.textContaining('selected'), findsNothing);
      expect(find.text('No skipped clips'), findsOneWidget);
      expect(button('Select'), findsNothing);
    });
  });

  group('the screen around the list', () {
    testApp('the error state offers Try again', (tester) async {
      final ids = await threeDays(tester);
      await open(
        tester,
        controller: skippedControllerProvider.overrideWith(_FailsOnce.new),
      );

      expect(find.text("Couldn't load your clips"), findsOneWidget);
      expect(
        find.text('Your videos are safe in your gallery.'),
        findsOneWidget,
      );
      expect(button('Select'), findsNothing);

      await tester.tap(button('Try again'));
      await settleApp(tester);

      expect(find.text("Couldn't load your clips"), findsNothing);
      expect(tileIds(tester), [ids[3], ids[2], ids[1], ids[0]]);
    });

    testApp('a tile is announced as a restore', (tester) async {
      final ids = await threeDays(tester);
      await open(tester);

      expect(
        tester.widget<TtClipTile>(tile(ids[0])).semanticLabel,
        startsWith('Skipped clip, '),
      );
      expect(
        tester.widget<TtClipTile>(tile(ids[0])).semanticLabel,
        endsWith('Restores it to To tag'),
      );
      await tester.longPress(tile(ids[0]));
      await tester.pumpAndSettle();
      // While choosing a tap only chooses.
      expect(
        tester.widget<TtClipTile>(tile(ids[0])).semanticLabel,
        startsWith('Clip, '),
      );
    });

    testApp('Back with nothing to pop goes to To tag', (tester) async {
      await open(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Back',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(toTagRouteMarker), findsOneWidget);
    });
  });

  group('large text and accessibility', () {
    testApp('2x text no overflow', (tester) async {
      await threeDays(tester);
      await open(tester, textScale: 2);

      expect(tiles(tester), isNotEmpty);
      expect(dayHeaders(tester), isNotEmpty);
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('2x text no overflow while choosing; the count is whole', (
      tester,
    ) async {
      // More days below the four clips, so the list scrolls.
      final ids = await skipped(tester, [
        ..._threeDayShots,
        for (var i = 0; i < 8; i++) DateTime.utc(2026, 10, 20 + i, 12),
      ]);
      await open(tester, textScale: 2);
      await tester.longPress(tile(ids[3]));
      await tester.pumpAndSettle();
      for (final id in [ids[2], ids[1], ids[0]]) {
        await tester.ensureVisible(tile(id));
        await tester.tap(tile(id));
        await tester.pumpAndSettle();
      }

      expect(find.text('4 selected'), findsOneWidget);
      // The count is not cut short ("4 sel…") as To tag's is at 2x.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('4 selected'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('2x text: Restore is an icon with its name, and it works', (
      tester,
    ) async {
      final ids = await threeDays(tester);
      await open(tester, textScale: 2);
      await tester.longPress(tile(ids[3]));
      await tester.pumpAndSettle();

      // No word on the button at 2x, but a screen reader hears "Restore".
      expect(button('Restore'), findsNothing);
      final restore = find.byWidgetPredicate(
        (w) => w is TtIconButton && w.semanticLabel == 'Restore',
      );
      expect(restore, findsOneWidget);
      await tester.tap(restore);
      await settleApp(tester);

      expect(await pendingIds(tester), [ids[3]]);
      expect(find.text('1 clip restored to To tag'), findsOneWidget);
    });

    testApp('1.5x text keeps the labelled Restore and the whole count', (
      tester,
    ) async {
      final ids = await threeDays(tester);
      await open(tester, textScale: 1.5);
      await tester.longPress(tile(ids[3]));
      await tester.pumpAndSettle();
      await tester.tap(tile(ids[2]));
      await tester.pumpAndSettle();

      expect(button('Restore'), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('2 selected'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('2x text: the empty state fits', (tester) async {
      await open(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('2x text: the error state fits', (tester) async {
      await open(
        tester,
        textScale: 2,
        controller: skippedControllerProvider.overrideWith(_FailsOnce.new),
      );

      expect(find.text("Couldn't load your clips"), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    for (final brightness in Brightness.values) {
      testApp('the list is accessible in ${brightness.name}', (tester) async {
        await threeDays(tester);
        await open(tester, brightness: brightness);

        expect(tiles(tester), isNotEmpty);
        await expectTtAccessible(tester);
      });
    }

    testApp('300 skipped clips build lazily', (tester) async {
      await skipped(tester, [
        for (var i = 0; i < 300; i++)
          DateTime.utc(2026, 10, 1 + i % 25, 6 + i % 12, i % 60, i ~/ 60),
      ]);
      await open(tester);

      expect(tiles(tester).length, inInclusiveRange(1, 39));
      expect(tester.takeException(), isNull);
      expect(find.text('Select'), findsOneWidget);
    });
  });
}
