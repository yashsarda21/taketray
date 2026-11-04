import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

// 15:30 local on 2026-10-28.
final DateTime _now = DateTime(2026, 10, 28, 15, 30);
final DateTime _since = DateTime(2026, 10, 28, 9, 41);

ShootingState on({DateTime? since}) => ShootingState(
  on: true,
  baselines: const {},
  since: (since ?? _since).toUtc(),
);

class Pumped {
  Pumped(this.shooting, this.access, this.toTag);
  final FakeShooting shooting;
  final FakeAccess access;
  final FakeToTag toTag;
}

/// To tag with fake view models. [clips] null: the list is still loading.
///
/// [times] are the clips' local times (`toTagTimesProvider`); null: they
/// come from [timesLater] (still loading until the test completes it). By
/// default none, so each tile shows the phone's time. [timesFail]: reading
/// them fails.
Future<Pumped> pump(
  WidgetTester tester, {
  ShootingState shooting = ShootingState.off,
  MediaAccessLevel? access = MediaAccessLevel.full,
  List<Clip>? clips = const [],
  Map<int, ClipLocalTime>? times = const {},
  bool timesFail = false,
  Completer<Map<int, ClipLocalTime>>? timesLater,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool settle = true,
  bool use24Hour = false,
  FixedClock? clock,
  bool cameraOpens = true,
  bool midnightTick = false,
  int skipped = 0,
  FakeToTag? toTag,
}) async {
  final fakeShooting = FakeShooting(shooting, cameraOpens: cameraOpens);
  final fakeAccess = FakeAccess(access);
  final fakeToTag = toTag ?? FakeToTag(clips);
  await pumpScreen(
    tester,
    const ToTagScreen(),
    overrides: <Override>[
      shootingModeControllerProvider.overrideWith(() => fakeShooting),
      mediaAccessControllerProvider.overrideWith(() => fakeAccess),
      toTagControllerProvider.overrideWith(() => fakeToTag),
      skippedCountProvider.overrideWith((ref) => Stream.value(skipped)),
      toTagTimesProvider.overrideWith((ref) {
        if (timesFail) return Future.error(StateError('no times'));
        if (times == null) {
          return (timesLater ?? Completer<Map<int, ClipLocalTime>>()).future;
        }
        return Future.value(times);
      }),
      clockProvider.overrideWithValue(clock ?? FixedClock(_now)),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
    settle: settle,
    use24Hour: use24Hour,
    midnightTick: midnightTick,
  );
  return Pumped(fakeShooting, fakeAccess, fakeToTag);
}

List<TtClipTile> tiles(WidgetTester tester) =>
    tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

String plain(String s) => s.replaceAll(' ', ' ');

/// [text] with no-break spaces made plain (a day header's date keeps its
/// spaces together).
String spaced(String text) => text.replaceAll(' ', ' ');

/// The scene headers on screen.
List<TtSceneHeader> sceneHeaders(WidgetTester tester) =>
    tester.widgetList<TtSceneHeader>(find.byType(TtSceneHeader)).toList();

/// The day headers on screen, as text.
List<String> dayHeaders(WidgetTester tester) => [
  for (final h in tester.widgetList<TtDayHeader>(find.byType(TtDayHeader)))
    spaced(h.title),
];

/// Clips shot at 09:41, 09:45 and 09:50 (one scene) and 13:05 and 13:12
/// (another), all on 2026-10-28 and 32 seconds long.
List<Clip> twoScenes() => [
  testClip(1, shot: DateTime(2026, 10, 28, 9, 41)),
  testClip(2, shot: DateTime(2026, 10, 28, 9, 45)),
  testClip(3, shot: DateTime(2026, 10, 28, 9, 50)),
  testClip(4, shot: DateTime(2026, 10, 28, 13, 5)),
  testClip(5, shot: DateTime(2026, 10, 28, 13, 12)),
];

Finder barButton(String label) => find.byWidgetPredicate(
  (w) => w is TtIconButton && w.semanticLabel == label,
  description: 'the "$label" button',
);

/// A [FakeToTag] whose first build fails and later ones show [then].
class FailsOnce extends FakeToTag {
  FailsOnce(this.then);

  final List<Clip> then;
  int builds = 0;

  @override
  Stream<List<Clip>> build() async* {
    builds++;
    if (builds == 1) throw StateError('the database failed');
    yield then;
  }
}

void main() {
  group('the app bar', () {
    testWidgets('is the large "To tag" bar', (tester) async {
      await pump(tester);

      final bar = tester.widget<TtAppBar>(find.byType(TtAppBar));
      expect(bar.title, 'To tag');
      expect(bar.large, isTrue);
    });
  });

  group('shows the banner for each AccessBanner', () {
    testWidgets('full: no banner', (tester) async {
      await pump(tester);
      expect(find.byType(TtBanner), findsNothing);
    });

    testWidgets('limited: Manual mode', (tester) async {
      await pump(tester, access: MediaAccessLevel.limited);
      expect(find.text('Manual mode'), findsOneWidget);
    });

    testWidgets("denied: can't see your videos", (tester) async {
      await pump(tester, access: MediaAccessLevel.denied);
      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
    });

    testWidgets('the first read failed: no banner, no crash', (tester) async {
      await pump(tester, access: null);
      expect(find.byType(TtBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the banner is above the strip', (tester) async {
      await pump(tester, shooting: on(), access: MediaAccessLevel.limited);
      expect(
        tester.getTopLeft(find.byType(TtBanner)).dy,
        lessThan(tester.getTopLeft(find.byType(TtStatStrip)).dy),
      );
    });

    testWidgets('Allow calls allow()', (tester) async {
      final p = await pump(tester, access: MediaAccessLevel.denied);

      await tester.tap(find.text('Allow'));
      await tester.pump();

      expect(p.access.allowed, 1);
    });
  });

  group('empty on / empty off states', () {
    testWidgets('on: All caught up, with Open camera', (tester) async {
      final p = await pump(tester, shooting: on());

      expect(find.text('All caught up'), findsOneWidget);
      expect(
        find.text('New clips you shoot will show up here.'),
        findsOneWidget,
      );
      final empty = tester.widget<TtEmptyState>(find.byType(TtEmptyState));
      expect(empty.illustration, TtIllustrationKind.caught);
      expect(find.byType(TtClipTile), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(TtEmptyState),
          matching: find.text('Open camera'),
        ),
      );
      await tester.pump();
      expect(p.shooting.cameraOpened, 1);
    });

    testWidgets('off: Nothing to tag, with Turn on Shooting mode', (
      tester,
    ) async {
      final p = await pump(tester);

      expect(find.text('Nothing to tag'), findsOneWidget);
      expect(
        find.text(
          'Turn on Shooting mode before you start filming. New videos will '
          'show up here.',
        ),
        findsOneWidget,
      );
      final empty = tester.widget<TtEmptyState>(find.byType(TtEmptyState));
      expect(empty.illustration, TtIllustrationKind.shootOff);

      await tester.tap(find.text('Turn on Shooting mode'));
      await tester.pump();
      expect(p.shooting.switched, [true]);
    });
  });

  group('strip on / off', () {
    testWidgets('on: Shooting since the time, and Open camera', (tester) async {
      final p = await pump(tester, shooting: on(), clips: [testClip(1)]);

      expect(findPlain('Shooting since 9:41 AM'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(TtStatStrip),
          matching: find.text('Open camera'),
        ),
      );
      await tester.pump();
      expect(p.shooting.cameraOpened, 1);
    });

    testWidgets('camera failure shows the snack (To tag strip)', (
      tester,
    ) async {
      final p = await pump(
        tester,
        shooting: on(),
        clips: [testClip(1)],
        cameraOpens: false,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(TtStatStrip),
          matching: find.text('Open camera'),
        ),
      );
      await tester.pumpAndSettle();

      expect(p.shooting.cameraOpened, 1);
      expect(
        find.text("Couldn't open the camera.").hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('camera failure shows the snack (All caught up)', (
      tester,
    ) async {
      final p = await pump(tester, shooting: on(), cameraOpens: false);

      await tester.tap(
        find.descendant(
          of: find.byType(TtEmptyState),
          matching: find.text('Open camera'),
        ),
      );
      await tester.pumpAndSettle();

      expect(p.shooting.cameraOpened, 1);
      expect(
        find.text("Couldn't open the camera.").hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('a camera that opens shows no snack', (tester) async {
      final p = await pump(tester, shooting: on(), clips: [testClip(1)]);

      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();

      expect(p.shooting.cameraOpened, 1);
      expect(find.text("Couldn't open the camera."), findsNothing);
    });

    testWidgets('Shooting since changes at midnight', (tester) async {
      final clock = FixedClock(DateTime(2026, 10, 28, 23, 50));
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 28, 22)),
        clips: [testClip(1)],
        clock: clock,
        midnightTick: true,
      );
      expect(findPlain('Shooting since 10:00 PM'), findsOneWidget);

      clock.advance(const Duration(minutes: 11));
      await tester.pump(const Duration(minutes: 11));

      expect(findPlain('Shooting since Oct 28, 10:00 PM'), findsOneWidget);
    });

    testWidgets('on since yesterday: with the date', (tester) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 27, 21, 41)),
        clips: [testClip(1)],
      );

      expect(findPlain('Shooting since Oct 27, 9:41 PM'), findsOneWidget);
    });

    testWidgets('off with clips: Shooting mode off, and Turn on', (
      tester,
    ) async {
      final p = await pump(tester, clips: [testClip(1)]);

      expect(find.text('Shooting mode off'), findsOneWidget);
      expect(
        tester.widget<TtStatStrip>(find.byType(TtStatStrip)).muted,
        isTrue,
      );
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(p.shooting.switched, [true]);
    });

    testWidgets('off with no clips: no strip', (tester) async {
      await pump(tester);

      expect(find.byType(TtStatStrip), findsNothing);
    });

    testWidgets('on with no clips: the strip shows above All caught up', (
      tester,
    ) async {
      await pump(tester, shooting: on());

      expect(find.byType(TtStatStrip), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TtStatStrip)).dy,
        lessThan(tester.getTopLeft(find.byType(TtEmptyState)).dy),
      );
    });
  });

  group('the phone set to 24-hour time', () {
    testWidgets('the strip today: Shooting since 09:41', (tester) async {
      await pump(tester, shooting: on(), clips: [testClip(1)], use24Hour: true);

      expect(findPlain('Shooting since 09:41'), findsOneWidget);
    });

    testWidgets('the strip not today: Shooting since Oct 27, 21:41', (
      tester,
    ) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 27, 21, 41)),
        clips: [testClip(1)],
        use24Hour: true,
      );
      expect(findPlain('Shooting since Oct 27, 21:41'), findsOneWidget);
    });

    testWidgets('a tile: 21:41 on the tile and in what it says aloud', (
      tester,
    ) async {
      await pump(
        tester,
        clips: [testClip(1, shot: DateTime(2026, 10, 28, 21, 41))],
        use24Hour: true,
      );

      final tile = tiles(tester).single;
      expect(tile.timeText, '21:41');
      expect(tile.semanticLabel, 'Clip, 21:41, 0:32');
    });

    testWidgets('a tile at 09:41 shows a leading zero', (tester) async {
      await pump(
        tester,
        clips: [testClip(1, shot: DateTime(2026, 10, 28, 9, 41))],
        use24Hour: true,
      );

      expect(tiles(tester).single.timeText, '09:41');
    });

    testWidgets('a tile just after midnight shows 00:05', (tester) async {
      await pump(
        tester,
        clips: [testClip(3, shot: DateTime(2026, 10, 28, 0, 5))],
        use24Hour: true,
      );
      expect(tiles(tester).single.timeText, '00:05');
    });

    testWidgets('a 12-hour phone keeps 9:41 PM on the tile', (tester) async {
      await pump(
        tester,
        clips: [testClip(1, shot: DateTime(2026, 10, 28, 21, 41))],
      );

      expect(plain(tiles(tester).single.timeText!), '9:41 PM');
      expect(plain(tiles(tester).single.semanticLabel), 'Clip, 9:41 PM, 0:32');
    });
  });

  group('the time where a clip was shot (D-83)', () {
    testWidgets('a clip shot in another zone shows the time where it was '
        'shot', (tester) async {
      await pump(
        tester,
        clips: [testClip(1, shot: DateTime(2026, 10, 28, 9, 41))],
        times: {
          1: ClipLocalTime(
            wallClock: DateTime.utc(2026, 10, 28, 4, 11),
            zoneId: 'Europe/London',
            isPhoneZone: false,
          ),
        },
      );

      final tile = tiles(tester).single;
      expect(plain(tile.timeText!), '4:11 AM');
      expect(plain(tile.semanticLabel), 'Clip, 4:11 AM, 0:32');
    });

    testWidgets('the clip zone keeps the 24-hour rule', (tester) async {
      await pump(
        tester,
        clips: [testClip(1, shot: DateTime(2026, 10, 28, 21, 41))],
        times: {
          1: ClipLocalTime(
            wallClock: DateTime.utc(2026, 10, 28, 16, 11),
            zoneId: 'Europe/London',
            isPhoneZone: false,
          ),
        },
        use24Hour: true,
      );

      expect(tiles(tester).single.timeText, '16:11');
    });

    testWidgets("while the times load, tiles show the phone's time; then the "
        'time where it was shot', (tester) async {
      final later = Completer<Map<int, ClipLocalTime>>();
      await pump(
        tester,
        clips: [testClip(1, shot: DateTime(2026, 10, 28, 9, 41))],
        times: null,
        timesLater: later,
      );

      // No skeletons waiting on the bridge (a hung channel would keep them
      // for its timeouts): the tile is there at once, in the phone's time.
      expect(find.byType(TtClipTileSkeleton), findsNothing);
      expect(plain(tiles(tester).single.timeText!), '9:41 AM');

      later.complete({
        1: ClipLocalTime(
          wallClock: DateTime.utc(2026, 10, 28, 4, 11),
          zoneId: 'Europe/London',
          isPhoneZone: false,
        ),
      });
      await tester.pumpAndSettle();

      expect(plain(tiles(tester).single.timeText!), '4:11 AM');
      expect(plain(tiles(tester).single.semanticLabel), 'Clip, 4:11 AM, 0:32');
    });

    testWidgets("times that fail show the phone's time", (tester) async {
      await pump(tester, clips: [testClip(1)], timesFail: true);

      expect(plain(tiles(tester).single.timeText!), '9:41 AM');
      expect(tester.takeException(), isNull);
    });

    testWidgets("a clip the times miss shows the phone's time", (tester) async {
      await pump(
        tester,
        clips: [
          testClip(1),
          testClip(2, shot: DateTime(2026, 10, 28, 10)),
        ],
        times: {
          2: ClipLocalTime(
            wallClock: DateTime.utc(2026, 10, 28, 4, 30),
            zoneId: 'Europe/London',
            isPhoneZone: false,
          ),
        },
      );

      expect(tiles(tester).map((t) => plain(t.timeText!)), [
        '9:41 AM',
        '4:30 AM',
      ]);
    });
  });

  group('grid lists pending clips oldest first', () {
    testWidgets('by date taken, then by id', (tester) async {
      await pump(
        tester,
        clips: [
          testClip(9, shot: DateTime(2026, 10, 28, 11), durationMs: 9000),
          testClip(7, shot: DateTime(2026, 10, 28, 10), durationMs: 7000),
          testClip(4, shot: DateTime(2026, 10, 28, 10), durationMs: 4000),
          testClip(2, shot: DateTime(2026, 10, 28, 12), durationMs: 2000),
        ],
      );

      expect(tiles(tester).map((t) => t.durationText), [
        '0:04',
        '0:07',
        '0:09',
        '0:02',
      ]);
    });

    testWidgets('three columns of equal tiles with the grid gap', (
      tester,
    ) async {
      await pump(tester, clips: [for (var i = 1; i <= 7; i++) testClip(i)]);

      final rects = [
        for (final t in find.byType(TtClipTile).evaluate())
          tester.getRect(find.byElementPredicate((e) => e == t)),
      ];
      expect(rects, hasLength(7));
      expect(rects[0].top, rects[1].top);
      expect(rects[1].top, rects[2].top);
      expect(rects[3].top, greaterThan(rects[0].top));
      expect(rects[3].left, rects[0].left);
      // 16 dp gutters and 4 dp gaps on a 360 dp screen.
      expect(rects[0].left, 16);
      expect(rects[2].right, 344);
      expect(rects[1].left - rects[0].right, 4);
      expect(rects[3].top - rects[0].bottom, 4);
      expect(rects[0].width, rects[1].width);
    });

    testWidgets('a tile shows the time, the length and a spoken label', (
      tester,
    ) async {
      await pump(tester, clips: [testClip(1)]);

      final tile = tiles(tester).single;
      expect(plain(tile.timeText!), '9:41 AM');
      expect(tile.durationText, '0:32');
      expect(plain(tile.semanticLabel), 'Clip, 9:41 AM, 0:32');
    });

    testWidgets('lengths of an hour or more show hours', (tester) async {
      await pump(
        tester,
        clips: [
          testClip(1, durationMs: 3665000),
          testClip(2, durationMs: 59500),
          testClip(3, durationMs: 0),
        ],
      );

      expect(tiles(tester).map((t) => t.durationText), [
        '1:01:05',
        '1:00',
        '0:00',
      ]);
    });

    testWidgets('a clip flagged missing shows the Missing tile, no Remove', (
      tester,
    ) async {
      await pump(tester, clips: [testClip(1, missing: true), testClip(2)]);

      expect(find.byType(TtMissingClipTile), findsOneWidget);
      expect(find.text('Missing from phone'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.byType(TtClipTile), findsOneWidget);
    });

    testWidgets('500 clips build lazily', (tester) async {
      await pump(
        tester,
        clips: [
          for (var i = 1; i <= 500; i++)
            testClip(
              i,
              shot: DateTime(2026, 10, 28).add(Duration(minutes: i)),
              durationMs: i * 1000,
            ),
        ],
      );

      final built = find.byType(TtClipTile).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(60));

      // Scrolling to the end builds the last clips and drops the first ones.
      // (The list is built on demand, so its length is an estimate that the
      // first drag corrects; a second one reaches the end.)
      for (var i = 0; i < 2; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -200000),
        );
        await tester.pumpAndSettle();
      }
      expect(tiles(tester).last.durationText, '8:20');
      expect(find.byType(TtClipTile).evaluate().length, lessThan(60));
    });
  });

  group('while the list loads', () {
    testWidgets('shows skeleton tiles, no empty state', (tester) async {
      await pump(tester, clips: null, settle: false);
      await tester.pump();

      expect(find.byType(TtClipTileSkeleton), findsWidgets);
      expect(find.byType(TtEmptyState), findsNothing);
      expect(find.byType(TtClipTile), findsNothing);
    });

    testWidgets('the loading state is as the prototype: a summary line, two '
        'scene headers, six tiles under each', (tester) async {
      await pump(tester, clips: null, settle: false);
      await tester.pump();

      final lines = find.byType(TtSkeletonLine);
      expect(lines, findsNWidgets(3));
      expect(find.byType(TtClipTileSkeleton), findsNWidgets(12));
      // The summary line, then a scene header line over the first tiles.
      final tilesTop = tester.getTopLeft(find.byType(TtClipTileSkeleton).first);
      expect(tester.getTopLeft(lines.at(0)).dy, lessThan(tilesTop.dy));
      expect(tester.getTopLeft(lines.at(1)).dy, lessThan(tilesTop.dy));
      expect(tester.getTopLeft(lines.at(2)).dy, greaterThan(tilesTop.dy));
    });

    testWidgets('shows the clips when they arrive', (tester) async {
      final p = await pump(tester, clips: null);

      p.toTag.clips.add([testClip(1)]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(TtClipTileSkeleton), findsNothing);
      expect(find.byType(TtClipTile), findsOneWidget);
    });

    testWidgets('a clip arriving later joins the grid in order', (
      tester,
    ) async {
      final p = await pump(
        tester,
        clips: [
          testClip(2, shot: DateTime(2026, 10, 28, 10), durationMs: 2000),
        ],
      );

      p.toTag.clips.add([
        testClip(2, shot: DateTime(2026, 10, 28, 10), durationMs: 2000),
        testClip(1, shot: DateTime(2026, 10, 28, 9), durationMs: 1000),
      ]);
      await tester.pump();
      await tester.pump();

      expect(tiles(tester).map((t) => t.durationText), ['0:01', '0:02']);
    });
  });

  group('the menu', () {
    testWidgets('full access: shown, with Add earlier videos', (tester) async {
      await pump(tester);

      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Add earlier videos'), findsOneWidget);
    });

    testWidgets('also with Shooting mode on', (tester) async {
      await pump(tester, shooting: on());

      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Add earlier videos'), findsOneWidget);
    });

    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testWidgets('hidden in ${level.name} access (Manual mode)', (
        tester,
      ) async {
        await pump(tester, access: level, shooting: on());

        expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
      });
    }

    testWidgets('hidden while access is unknown', (tester) async {
      await pump(tester, access: null);

      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });

    testWidgets('appears when access becomes full, without a restart', (
      tester,
    ) async {
      final p = await pump(tester, access: MediaAccessLevel.limited);
      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);

      p.access.show(MediaAccessLevel.full);
      await tester.pump();

      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
    });

    testWidgets('goes away again when access is lost', (tester) async {
      final p = await pump(tester);
      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);

      p.access.show(MediaAccessLevel.denied);
      await tester.pump();

      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });
  });

  group('opening and resuming', () {
    testWidgets('the app coming back to the front checks again', (
      tester,
    ) async {
      final p = await pump(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(p.toTag.resumes, 1);
    });

    testWidgets('going to another state of the app does not', (tester) async {
      final p = await pump(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(p.toTag.resumes, 0);
    });

    testWidgets('the screen being hidden does not, being shown again does', (
      tester,
    ) async {
      final fakeToTag = FakeToTag(const []);
      final active = ValueNotifier<bool>(true);
      await pumpScreen(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (context, isActive, _) =>
              TickerMode(enabled: isActive, child: const ToTagScreen()),
        ),
        overrides: <Override>[
          shootingModeControllerProvider.overrideWith(
            () => FakeShooting(ShootingState.off),
          ),
          mediaAccessControllerProvider.overrideWith(
            () => FakeAccess(MediaAccessLevel.full),
          ),
          toTagControllerProvider.overrideWith(() => fakeToTag),
          skippedCountProvider.overrideWith((ref) => Stream.value(0)),
          thumbnailCacheForTests,
        ],
      );
      expect(fakeToTag.resumes, 0);

      // Another tab is selected: the screen stays built but not active, and a
      // resume of the app is not for it.
      active.value = false;
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fakeToTag.resumes, 0);

      // The tab is selected again: scan and verify.
      active.value = true;
      await tester.pump();
      expect(fakeToTag.resumes, 1);
    });
  });

  group('scenes (D-95, D-98)', () {
    testWidgets('scenes and summary row', (tester) async {
      await pump(tester, clips: twoScenes());

      // "5 clips · 2 scenes · 3 min": 5 x 32 s is 160 s, 3 minutes.
      expect(find.text('5 clips · 2 scenes · 3 min'), findsOneWidget);
      final headers = sceneHeaders(tester);
      expect(headers, hasLength(2));
      expect(plain(headers[0].title), '9:41–9:50 AM');
      expect(headers[0].subtitle, '3 clips · 1:36');
      expect(plain(headers[1].title), '1:05–1:12 PM');
      expect(headers[1].subtitle, '2 clips · 1:04');
      // Each scene's tiles are under its header, in shooting order.
      expect(tiles(tester), hasLength(5));
      expect(find.text('Tag scene'), findsNWidgets(2));
      // The button says which scene it tags.
      final labels = [
        for (final b in tester.widgetList<TtButton>(
          find.widgetWithText(TtButton, 'Tag scene'),
        ))
          plain(b.semanticLabel!),
      ];
      expect(labels, [
        'Tag scene 9:41–9:50 AM, 3 clips',
        'Tag scene 1:05–1:12 PM, 2 clips',
      ]);
      // The summary is above the first scene.
      expect(
        tester.getTopLeft(find.byType(TtSceneHeader).first).dy,
        greaterThan(
          tester.getBottomLeft(find.text('5 clips · 2 scenes · 3 min')).dy,
        ),
      );
    });

    testWidgets('one clip: 1 clip, 1 scene, one time', (tester) async {
      await pump(tester, clips: [testClip(1)]);

      expect(find.text('1 clip · 1 scene · 32 s'), findsOneWidget);
      final header = sceneHeaders(tester).single;
      expect(plain(header.title), '9:41 AM');
      expect(header.subtitle, '1 clip · 0:32');
    });

    testWidgets('24-hour phones read the range as 09:41–09:50', (tester) async {
      await pump(tester, clips: twoScenes(), use24Hour: true);

      expect(sceneHeaders(tester).first.title, '09:41–09:50');
      expect(sceneHeaders(tester).last.title, '13:05–13:12');
    });

    testWidgets('a scene uses the time where its clips were shot', (
      tester,
    ) async {
      await pump(
        tester,
        clips: [
          testClip(1, shot: DateTime(2026, 10, 28, 9, 41)),
          testClip(2, shot: DateTime(2026, 10, 28, 9, 45)),
        ],
        times: {
          1: ClipLocalTime(
            wallClock: DateTime.utc(2026, 10, 28, 4, 11),
            zoneId: 'Europe/London',
            isPhoneZone: false,
          ),
          2: ClipLocalTime(
            wallClock: DateTime.utc(2026, 10, 28, 4, 15),
            zoneId: 'Europe/London',
            isPhoneZone: false,
          ),
        },
      );

      expect(plain(sceneHeaders(tester).single.title), '4:11–4:15 AM');
    });

    testWidgets('the scenes do not wait for the times', (tester) async {
      final later = Completer<Map<int, ClipLocalTime>>();
      await pump(tester, clips: twoScenes(), times: null, timesLater: later);

      expect(find.byType(TtClipTileSkeleton), findsNothing);
      expect(sceneHeaders(tester), hasLength(2));
      expect(plain(sceneHeaders(tester).first.title), '9:41–9:50 AM');
    });

    testWidgets('day headers only across days', (tester) async {
      // Three days: Yesterday, Today and an older one, each over its scene.
      await pump(
        tester,
        clips: [
          testClip(1, shot: DateTime(2026, 10, 26, 18)),
          testClip(2, shot: DateTime(2026, 10, 27, 20)),
          testClip(3, shot: DateTime(2026, 10, 27, 20, 3)),
          testClip(4, shot: DateTime(2026, 10, 28, 9)),
        ],
      );
      expect(dayHeaders(tester), [
        'Mon, Oct 26',
        'Yesterday · Tue, Oct 27',
        'Today · Wed, Oct 28',
      ]);
      // A day header is above its scene header, and a day with two scenes
      // gets one header.
      expect(sceneHeaders(tester), hasLength(3));
      expect(
        tester.getTopLeft(find.byType(TtDayHeader).first).dy,
        lessThan(tester.getTopLeft(find.byType(TtSceneHeader).first).dy),
      );
    });

    testWidgets('day headers only across days: one day has none', (
      tester,
    ) async {
      // One day, two scenes: no day header at all.
      await pump(tester, clips: twoScenes());

      expect(sceneHeaders(tester), hasLength(2));
      expect(find.byType(TtDayHeader), findsNothing);
    });

    testWidgets('a day with two scenes has one day header', (tester) async {
      await pump(
        tester,
        clips: [
          testClip(1, shot: DateTime(2026, 10, 27, 9)),
          testClip(2, shot: DateTime(2026, 10, 28, 9)),
          testClip(3, shot: DateTime(2026, 10, 28, 15)),
        ],
      );

      expect(dayHeaders(tester), [
        'Yesterday · Tue, Oct 27',
        'Today · Wed, Oct 28',
      ]);
      expect(sceneHeaders(tester), hasLength(3));
    });

    testWidgets('a day of another year has its year', (tester) async {
      await pump(
        tester,
        clips: [
          testClip(1, shot: DateTime(2025, 12, 30, 9)),
          testClip(2, shot: DateTime(2026, 10, 28, 9)),
        ],
      );

      expect(dayHeaders(tester).first, 'Tue, Dec 30, 2025');
    });

    testWidgets('300 clips in 60 scenes build lazily', (tester) async {
      // 300 clips over 6 days, 10 scenes a day: 60 scenes of 5 clips each.
      final clips = <Clip>[];
      var id = 1;
      for (var day = 0; day < 6; day++) {
        for (var scene = 0; scene < 10; scene++) {
          for (var k = 0; k < 5; k++) {
            clips.add(
              testClip(
                id++,
                shot: DateTime(2026, 10, 23 + day, 8 + scene, k),
                durationMs: 5000,
              ),
            );
          }
        }
      }
      await pump(tester, clips: clips);

      expect(find.text('300 clips · 60 scenes · 25 min'), findsOneWidget);
      expect(find.byType(TtClipTile).evaluate().length, lessThan(60));
      expect(find.byType(TtSceneHeader).evaluate().length, lessThan(12));

      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2000000),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(TtClipTile).evaluate().length, lessThan(60));
      expect(find.byType(TtSceneHeader).evaluate().length, lessThan(12));
      // The last scene of the last day: 17:00 to 17:04.
      expect(plain(sceneHeaders(tester).last.title), '5:00–5:04 PM');
      expect(plain(tiles(tester).last.timeText!), '5:04 PM');
    });

    testWidgets('300 clips build lazily', (tester) async {
      // 300 clips over 6 days, 5 scenes a day: 30 scenes of 10 clips each.
      final clips = <Clip>[];
      var id = 1;
      for (var day = 0; day < 6; day++) {
        for (var scene = 0; scene < 5; scene++) {
          for (var k = 0; k < 10; k++) {
            clips.add(
              testClip(
                id++,
                shot: DateTime(2026, 10, 23 + day, 8 + scene * 2, k),
                durationMs: 5000,
              ),
            );
          }
        }
      }
      expect(clips, hasLength(300));
      await pump(tester, clips: clips);

      expect(find.byType(TtClipTile).evaluate().length, lessThan(60));
      expect(find.byType(TtSceneHeader).evaluate().length, lessThan(8));
      expect(find.byType(TtDayHeader).evaluate().length, lessThan(4));
      expect(find.text('300 clips · 30 scenes · 25 min'), findsOneWidget);

      // Scrolling to the end builds the last clips, and drops the first.
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2000000),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(TtClipTile).evaluate().length, lessThan(60));
      // The last clip shot is the last tile: 16:09 on the last day.
      expect(plain(tiles(tester).last.timeText!), '4:09 PM');
    });
  });

  group('opening the player', () {
    testWidgets('tile tap opens the player on it', (tester) async {
      await pump(tester, clips: twoScenes());

      await tester.tap(find.byType(TtClipTile).at(3));
      await tester.pumpAndSettle();

      expect(find.text(tagPlayerRouteMarker(4)), findsOneWidget);
    });

    testWidgets('start tagging opens on the first clip', (tester) async {
      await pump(
        tester,
        clips: [
          testClip(7, shot: DateTime(2026, 10, 28, 9)),
          testClip(3, shot: DateTime(2026, 10, 28, 10)),
        ],
      );

      await tester.tap(find.text('Start tagging'));
      await tester.pumpAndSettle();

      // The first in shooting order, not the lowest id.
      expect(find.text(tagPlayerRouteMarker(7)), findsOneWidget);
    });

    testWidgets('start tagging skips a missing first clip', (tester) async {
      await pump(
        tester,
        clips: [
          testClip(1, shot: DateTime(2026, 10, 28, 9), missing: true),
          testClip(2, shot: DateTime(2026, 10, 28, 10)),
        ],
      );

      await tester.tap(find.text('Start tagging'));
      await tester.pumpAndSettle();

      expect(find.text(tagPlayerRouteMarker(2)), findsOneWidget);
    });

    testWidgets('a double tap opens one player', (tester) async {
      await pump(tester, clips: twoScenes());

      await tester.tap(find.byType(TtClipTile).first);
      await tester.tap(find.byType(TtClipTile).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(tagPlayerRouteMarker(1)), findsOneWidget);

      // Back goes to To tag, not to a second player.
      GoRouter.of(tester.element(find.text(tagPlayerRouteMarker(1)))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(TtClipTile), findsWidgets);
      expect(find.textContaining('the tag player'), findsNothing);
    });

    testWidgets('start tagging is not there with no clips', (tester) async {
      await pump(tester);

      expect(find.text('Start tagging'), findsNothing);
    });

    testWidgets('start tagging is away while choosing', (tester) async {
      await pump(tester, clips: twoScenes());
      expect(find.text('Start tagging'), findsOneWidget);
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Start tagging'), findsNothing);
    });

    testWidgets('start tagging sits above the nav pill and lifts over a '
        'snack', (tester) async {
      await pump(tester, clips: twoScenes());
      final resting = tester.getTopLeft(find.text('Start tagging')).dy;
      // The same place as the Reels tab's New reel button: a 16 dp step above
      // the pill's room.
      expect(
        tester.getBottomRight(find.byType(TtFab)).dy,
        tester.view.physicalSize.height -
            TtNavPill.fabBottom(tester.element(find.byType(TtFab))),
      );

      ReelSnacks.of(tester.element(find.byType(TtFab))).show('Hello');
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Start tagging')).dy,
        lessThan(resting),
      );
    });
  });

  group('Skipped', () {
    testWidgets('skipped button shows with a count', (tester) async {
      await pump(tester, clips: twoScenes(), skipped: 3);

      expect(find.text('Skipped (3)'), findsOneWidget);
      // On the summary row, after the text.
      expect(
        tester.getTopLeft(find.text('Skipped (3)')).dx,
        greaterThan(tester.getTopLeft(find.textContaining('5 clips')).dx),
      );

      await tester.tap(find.text('Skipped (3)'));
      await tester.pumpAndSettle();
      expect(find.text(skippedRouteMarker), findsOneWidget);
    });

    testWidgets('a double tap on Skipped opens one page', (tester) async {
      await pump(tester, clips: twoScenes(), skipped: 3);

      await tester.tap(find.text('Skipped (3)'));
      await tester.tap(find.text('Skipped (3)'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(skippedRouteMarker), findsOneWidget);

      // Back goes to To tag, not to a second Skipped page.
      GoRouter.of(tester.element(find.text(skippedRouteMarker))).pop();
      await tester.pumpAndSettle();
      expect(find.text(skippedRouteMarker), findsNothing);
      expect(find.byType(TtClipTile), findsWidgets);
    });

    testWidgets('no button when nothing is skipped', (tester) async {
      await pump(tester, clips: twoScenes());

      expect(find.textContaining('Skipped'), findsNothing);
    });

    testWidgets('under All caught up when any are skipped', (tester) async {
      await pump(tester, shooting: on(), skipped: 2);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('Skipped (2)'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Skipped (2)')).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.descendant(
                  of: find.byType(TtEmptyState),
                  matching: find.text('Open camera'),
                ),
              )
              .dy,
        ),
      );
    });

    testWidgets('under Nothing to tag when any are skipped', (tester) async {
      await pump(tester, skipped: 2);
      expect(find.text('Nothing to tag'), findsOneWidget);
      await tester.tap(find.text('Skipped (2)'));
      await tester.pumpAndSettle();
      expect(find.text(skippedRouteMarker), findsOneWidget);
    });

    testWidgets('the empty states have no Skipped button with none skipped', (
      tester,
    ) async {
      await pump(tester, shooting: on());
      expect(find.textContaining('Skipped'), findsNothing);
    });

    testWidgets('the menu shows Skipped (n) and opens it', (tester) async {
      await pump(tester, clips: twoScenes(), skipped: 4);

      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();
      // The summary row has one as well; the menu has the other.
      expect(find.text('Skipped (4)'), findsNWidgets(2));
      await tester.tap(find.text('Skipped (4)').last);
      await tester.pumpAndSettle();
      expect(find.text(skippedRouteMarker), findsOneWidget);
    });
  });

  group('the error state', () {
    testWidgets('error state retries', (tester) async {
      final toTag = FailsOnce([testClip(1)]);
      await pump(tester, toTag: toTag);

      expect(find.text("Couldn't load your clips"), findsOneWidget);
      expect(
        find.text('Your videos are safe in your gallery.'),
        findsOneWidget,
      );
      expect(find.byType(TtClipTileSkeleton), findsNothing);
      expect(find.byType(TtClipTile), findsNothing);
      expect(find.text('Start tagging'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(toTag.builds, 2);
      expect(find.text("Couldn't load your clips"), findsNothing);
      expect(find.byType(TtClipTile), findsOneWidget);
    });

    testWidgets('it shows no menu items that need clips', (tester) async {
      await pump(tester, toTag: FailsOnce(const []), access: null);

      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });
  });

  group('choosing clips (D-98)', () {
    testWidgets('long press selects and shows the bar', (tester) async {
      await pump(tester, clips: twoScenes());
      expect(find.textContaining('selected'), findsNothing);

      await tester.longPress(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [
        false,
        true,
        false,
        false,
        false,
      ]);
      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).selection, isTrue);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Tag'), findsOneWidget);
      // The scene buttons read Select all, not Tag scene.
      expect(find.text('Tag scene'), findsNothing);
      expect(find.text('Select all'), findsNWidgets(2));
      // A tap now chooses; it does not open the player.
      await tester.tap(find.byType(TtClipTile).at(4));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.textContaining('the tag player'), findsNothing);
    });

    testWidgets('the count is announced when it changes', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, clips: twoScenes());
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      bool live(String title) => tester
          .getSemantics(find.text(title))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion;
      expect(live('1 selected'), isTrue);
      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(live('2 selected'), isTrue);
      semantics.dispose();
    });

    testWidgets('Select clips in the menu starts with nothing chosen', (
      tester,
    ) async {
      await pump(tester, clips: twoScenes());

      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select clips'));
      await tester.pumpAndSettle();

      expect(find.text('0 selected'), findsOneWidget);
      // Skip and Tag wait for a choice.
      for (final label in ['Skip', 'Tag']) {
        final button = tester.widget<TtButton>(
          find.widgetWithText(TtButton, label),
        );
        expect(button.onPressed, isNull, reason: label);
      }
      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      // Un-choosing the last one ends choosing.
      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('select all in a scene', (tester) async {
      await pump(tester, clips: twoScenes());
      await tester.longPress(find.byType(TtClipTile).at(4));
      await tester.pumpAndSettle();

      // The first scene: Select all chooses its three clips.
      await tester.tap(find.text('Select all').first);
      await tester.pumpAndSettle();
      expect(find.text('4 selected'), findsOneWidget);
      expect(tiles(tester).map((t) => t.selected), [
        true,
        true,
        true,
        false,
        true,
      ]);
      expect(find.text('Unselect'), findsOneWidget);

      // Unselect takes just that scene's clips out again.
      await tester.tap(find.text('Unselect'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Unselect'), findsNothing);

      // The second scene is all chosen: Unselect empties the choice, and
      // choosing goes on.
      await tester.tap(find.text('Select all').last);
      await tester.pumpAndSettle();
      expect(find.text('Unselect'), findsOneWidget);
      await tester.tap(find.text('Unselect'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('select all leaves a missing clip out', (tester) async {
      await pump(
        tester,
        clips: [testClip(1, missing: true), testClip(2), testClip(3)],
      );
      // A long press on the missing tile starts nothing.
      await tester.longPress(find.byType(TtMissingClipTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);

      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      // The two clips on the phone; the missing one is not counted, and the
      // scene reads Unselect because every chooseable clip is chosen.
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Unselect'), findsOneWidget);
      await tester.tap(find.byType(TtMissingClipTile));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('back clears selection', (tester) async {
      await pump(tester, clips: twoScenes());
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Still on To tag, nothing chosen.
      expect(find.textContaining('selected'), findsNothing);
      expect(tiles(tester).map((t) => t.selected), everyElement(isNull));
      expect(find.text('Start tagging'), findsOneWidget);
    });

    testWidgets('close ends choosing', (tester) async {
      await pump(tester, clips: twoScenes());
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      await tester.tap(barButton('Close'));
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('Select all and Unselect name the scene for a screen reader', (
      tester,
    ) async {
      await pump(tester, clips: twoScenes());
      await tester.longPress(find.byType(TtClipTile).at(4));
      await tester.pumpAndSettle();

      String label(String text) => plain(
        tester
            .widget<TtButton>(find.widgetWithText(TtButton, text).first)
            .semanticLabel!,
      );
      expect(label('Select all'), 'Select all, 9:41–9:50 AM, 3 clips');
      await tester.tap(find.text('Select all').first);
      await tester.pumpAndSettle();
      expect(label('Unselect'), 'Unselect, 9:41–9:50 AM, 3 clips');
    });

    testWidgets('choosing with nothing chosen ends when the list empties', (
      tester,
    ) async {
      final p = await pump(tester, clips: twoScenes());
      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select clips'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);

      // Everything is tagged elsewhere: nothing is left to choose.
      p.toTag.clips.add(const []);
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(find.text('Nothing to tag'), findsOneWidget);
    });

    testWidgets('2x text: the count stays whole; Skip and Tag keep their '
        'names', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, clips: twoScenes(), textScale: 2);
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final count = tester.renderObject<RenderParagraph>(
        find.text('2 selected'),
      );
      expect(count.didExceedMaxLines, isFalse);
      // Tag gives up its word for its icon and keeps its name.
      expect(find.bySemanticsLabel('Tag'), findsOneWidget);
      expect(find.bySemanticsLabel('Skip'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('selection drops a clip that leaves To tag', (tester) async {
      final p = await pump(tester, clips: twoScenes());
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TtClipTile).at(1));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // Clip 1 is tagged elsewhere (the player, a verify).
      p.toTag.clips.add(twoScenes().sublist(1));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(tiles(tester).first.selected, isTrue);
      expect(tiles(tester), hasLength(4));

      // The last chosen clip leaves: choosing ends.
      p.toTag.clips.add(twoScenes().sublist(2));
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);
      expect(tiles(tester).map((t) => t.selected), everyElement(isNull));
    });
  });

  group('the menu (D-98)', () {
    testWidgets('has Select clips, Skipped and Skip all with clips', (
      tester,
    ) async {
      await pump(tester, clips: twoScenes(), skipped: 2);

      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Add earlier videos'), findsOneWidget);
      expect(find.text('Select clips'), findsOneWidget);
      expect(find.text('Skip all'), findsOneWidget);
      expect(find.text('Skipped (2)'), findsNWidgets(2));
    });

    testWidgets('limited access: still Select clips and Skip all', (
      tester,
    ) async {
      await pump(tester, access: MediaAccessLevel.limited, clips: twoScenes());

      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Add earlier videos'), findsNothing);
      expect(find.text('Select clips'), findsOneWidget);
      expect(find.text('Skip all'), findsOneWidget);
    });

    testWidgets('nothing waiting and nothing skipped: only Add earlier '
        'videos', (tester) async {
      await pump(tester);

      await tester.tap(barButton('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Add earlier videos'), findsOneWidget);
      expect(find.text('Select clips'), findsNothing);
      expect(find.text('Skip all'), findsNothing);
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: with clips, accessible', (tester) async {
        await pump(
          tester,
          shooting: on(),
          access: MediaAccessLevel.limited,
          clips: [for (var i = 1; i <= 7; i++) testClip(i)],
          brightness: brightness,
        );

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: with a missing clip, accessible', (
        tester,
      ) async {
        await pump(
          tester,
          clips: [testClip(1, missing: true), testClip(2)],
          brightness: brightness,
        );

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: empty on, accessible', (tester) async {
        await pump(tester, shooting: on(), brightness: brightness);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: empty off, accessible', (tester) async {
        await pump(
          tester,
          access: MediaAccessLevel.denied,
          brightness: brightness,
        );

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: strip off with clips, accessible', (
        tester,
      ) async {
        await pump(tester, clips: [testClip(1)], brightness: brightness);

        await expectTtAccessible(tester);
      });
    }

    testWidgets('at 2x text nothing overflows at 360 dp', (tester) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 27, 21, 41)),
        access: MediaAccessLevel.limited,
        clips: [for (var i = 1; i <= 7; i++) testClip(i)],
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testWidgets('at 2x text the empty states fit', (tester) async {
      await pump(tester, access: MediaAccessLevel.denied, textScale: 2);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: scenes, accessible', (tester) async {
        await pump(
          tester,
          clips: twoScenes(),
          skipped: 3,
          brightness: brightness,
        );

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: selecting, accessible', (tester) async {
        await pump(tester, clips: twoScenes(), brightness: brightness);
        await tester.longPress(find.byType(TtClipTile).first);
        await tester.pumpAndSettle();

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: the error state, accessible', (
        tester,
      ) async {
        await pump(tester, toTag: FailsOnce(const []), brightness: brightness);

        await expectTtAccessible(tester);
      });
    }

    testWidgets('2x text no overflow', (tester) async {
      // The summary, the day and scene headers and Start tagging all fit.
      await pump(
        tester,
        clips: [
          ...twoScenes(),
          testClip(6, shot: DateTime(2026, 10, 27, 20)),
        ],
        skipped: 12,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testWidgets('2x text no overflow while choosing', (tester) async {
      await pump(
        tester,
        clips: [
          ...twoScenes(),
          testClip(6, shot: DateTime(2026, 10, 27, 20)),
        ],
        skipped: 12,
        textScale: 2,
      );
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testWidgets('2x text: the error state fits', (tester) async {
      await pump(tester, toTag: FailsOnce(const []), textScale: 2);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testWidgets('2x text: the empty Skipped button fits', (tester) async {
      await pump(tester, skipped: 123, textScale: 2);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });
  });
}
