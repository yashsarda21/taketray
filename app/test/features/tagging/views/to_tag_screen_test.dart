import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
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
Future<Pumped> pump(
  WidgetTester tester, {
  ShootingState shooting = ShootingState.off,
  MediaAccessLevel? access = MediaAccessLevel.full,
  List<Clip>? clips = const [],
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool settle = true,
  bool use24Hour = false,
}) async {
  final fakeShooting = FakeShooting(shooting);
  final fakeAccess = FakeAccess(access);
  final fakeToTag = FakeToTag(clips);
  await pumpScreen(
    tester,
    const ToTagScreen(),
    overrides: <Override>[
      shootingModeControllerProvider.overrideWith(() => fakeShooting),
      mediaAccessControllerProvider.overrideWith(() => fakeAccess),
      toTagControllerProvider.overrideWith(() => fakeToTag),
      clockProvider.overrideWithValue(FixedClock(_now)),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
    settle: settle,
    use24Hour: use24Hour,
  );
  return Pumped(fakeShooting, fakeAccess, fakeToTag);
}

List<TtClipTile> tiles(WidgetTester tester) =>
    tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

String plain(String s) => s.replaceAll(' ', ' ');

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

    testWidgets('tapping a tile does nothing yet', (tester) async {
      await pump(tester, clips: [testClip(1)]);

      await tester.tap(find.byType(TtClipTile));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TtClipTile), findsOneWidget);
      expect(find.text(toTagRouteMarker), findsNothing);
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
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -200000),
      );
      await tester.pumpAndSettle();
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
  });
}
