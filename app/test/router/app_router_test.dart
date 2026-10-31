import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/features/reels/views/clip_viewer_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fake_video_player.dart';
import '../support/reel_videos.dart';
import '../support/test_app.dart';
import '../support/vm_harness.dart';

Future<(ProviderContainer, GoRouter)> _pumpApp(
  WidgetTester tester, {
  VmHarness? harness,
}) async {
  final container = ProviderContainer(
    overrides: (harness ?? VmHarness()).appOverrides,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
  return (container, container.read(appRouterProvider));
}

/// Lets the database and the media jobs answer, then redraws.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(settle);
  await tester.pump();
  await tester.pumpAndSettle();
  // What the redraw let go of (a player to dispose) finishes in real time.
  await tester.runAsync(settle);
  await tester.pump();
}

void main() {
  testApp('go to a known location shows that tab', (tester) async {
    final (_, router) = await _pumpApp(tester);

    router.go(Routes.toTag);
    await tester.pumpAndSettle();

    expect(find.byType(ToTagScreen), findsOneWidget);
  });

  testApp('unknown location redirects to Reels', (tester) async {
    final (_, router) = await _pumpApp(tester);

    router.go('/nope');
    await tester.pumpAndSettle();

    expect(find.byType(ReelsScreen), findsOneWidget);
  });

  for (final location in ['/reels/unknown', '/to-tag/a/b', '/settings/x']) {
    testApp('unknown location below a tab root ($location) lands on Reels', (
      tester,
    ) async {
      final (_, router) = await _pumpApp(tester);
      router.go(Routes.toTag);
      await tester.pumpAndSettle();

      final logged = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(logged.add);
      addTearDown(sub.cancel);

      router.go(location);
      await tester.pumpAndSettle();

      expect(logged.map((r) => r.loggerName), contains('router'));
      expect(logged.map((r) => r.message).join(), isNot(contains(location)));

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.textContaining('Page Not Found'), findsNothing);
      final bar = tester.widget<TtNavPill>(find.byType(TtNavPill));
      expect(bar.currentIndex, 0);
    });
  }

  testApp('a reel location shows the reel page and back goes to Reels', (
    tester,
  ) async {
    final h = VmHarness();
    final reel = await h.container.read(reelsRepositoryProvider).create('Goa');
    final (_, router) = await _pumpApp(tester, harness: h);

    router.go(Routes.reel(reel.id));
    await _settle(tester);

    expect(find.byType(ReelDetailScreen), findsOneWidget);
    expect(
      tester.widget<ReelDetailScreen>(find.byType(ReelDetailScreen)).reelId,
      reel.id,
    );
    expect(find.text('Goa'), findsOneWidget);
    // The nav pill stays, on the Reels tab.
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReelsScreen), findsOneWidget);
  });

  testApp('unknown id route goes to Reels', (tester) async {
    final (_, router) = await _pumpApp(tester);

    // A good number that names no reel: the page finds that out and leaves.
    router.go(Routes.reel(7));
    await _settle(tester);

    expect(find.byType(ReelDetailScreen), findsNothing);
    expect(find.byType(ReelsScreen), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
  });

  testApp('a reel deleted while its page is open goes to Reels', (
    tester,
  ) async {
    final h = VmHarness();
    final reels = h.container.read(reelsRepositoryProvider);
    final reel = await reels.create('Goa');
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.reel(reel.id));
    await _settle(tester);
    expect(find.byType(ReelDetailScreen), findsOneWidget);

    await tester.runAsync(() => reels.delete(reel.id));
    await _settle(tester);

    expect(find.byType(ReelDetailScreen), findsNothing);
    expect(find.byType(ReelsScreen), findsOneWidget);
  });

  testApp('a clip location opens the viewer above the shell, with no nav pill, '
      'and back returns to the reel', (tester) async {
    final platform = FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final reel = await h.container.read(reelsRepositoryProvider).create('Goa');
    final ids = (await tester.runAsync(
      () => putInReel(h, reel.id, [reelVideo(1), reelVideo(2)]),
    ))!;
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.reel(reel.id));
    await _settle(tester);
    expect(find.byType(TtNavPill), findsOneWidget);

    unawaited(router.push(Routes.clip(reel.id, ids[1])));
    await _settle(tester);

    expect(find.byType(ClipViewerScreen), findsOneWidget);
    final viewer = tester.widget<ClipViewerScreen>(
      find.byType(ClipViewerScreen),
    );
    expect((viewer.reelId, viewer.clipId), (reel.id, ids[1]));
    // Above the tab shell: its nav pill is not on the screen.
    expect(find.byType(TtNavPill), findsNothing);
    expect(platform.uris, ['content://media/external_primary/video/media/2']);

    // The viewer is a route of the root navigator; Back leaves it for the
    // reel's page, which was kept under it in the Reels tab, with the pill.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(ClipViewerScreen), findsNothing);
    expect(find.byType(ReelDetailScreen), findsOneWidget);
    expect(find.byType(TtNavPill), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
    expect(platform.live, isEmpty);
  });

  testApp('moving the last clip from the viewer closes the viewer, not only '
      'the picker', (tester) async {
    FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final reels = h.container.read(reelsRepositoryProvider);
    final goa = await reels.create('Goa');
    await reels.create('London');
    final ids = (await tester.runAsync(
      () => putInReel(h, goa.id, [reelVideo(1)]),
    ))!;
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.reel(goa.id));
    await _settle(tester);
    unawaited(router.push(Routes.clip(goa.id, ids.single)));
    await _settle(tester);
    expect(find.byType(ClipViewerScreen), findsOneWidget);

    await tester.tap(find.text('Move'));
    await _settle(tester);
    await tester.tap(find.text('London'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TtButton, 'Move'));
    await _settle(tester);

    // The picker is closed and so is the viewer; the reel's page is under it.
    expect(find.byType(TtSheet), findsNothing);
    expect(find.byType(ClipViewerScreen), findsNothing);
    expect(find.byType(ReelDetailScreen), findsOneWidget);
    expect(find.text('Moved to London'), findsOneWidget);
  });

  testApp('a clip that goes while the picker is open leaves the picker open '
      'and closes the viewer after it', (tester) async {
    FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final reels = h.container.read(reelsRepositoryProvider);
    final goa = await reels.create('Goa');
    await reels.create('London');
    final ids = (await tester.runAsync(
      () => putInReel(h, goa.id, [reelVideo(1)]),
    ))!;
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.reel(goa.id));
    await _settle(tester);
    unawaited(router.push(Routes.clip(goa.id, ids.single)));
    await _settle(tester);
    await tester.tap(find.text('Move'));
    await _settle(tester);
    expect(find.byType(TtSheet), findsOneWidget);

    // The video turns out to be gone while the picker is up: the pager is
    // empty, but a pop now would close the picker, not the viewer.
    await tester.runAsync(() => flagForTest(h, {ids.single}, missing: true));
    await _settle(tester);
    expect(find.byType(TtSheet), findsOneWidget);
    expect(find.byType(ClipViewerScreen), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.byType(TtSheet), findsNothing);
    expect(find.byType(ClipViewerScreen), findsNothing);
    expect(find.byType(ReelDetailScreen), findsOneWidget);
  });

  testApp('the viewer on a clip that is not in the reel goes back to the '
      'reel', (tester) async {
    final platform = FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final reel = await h.container.read(reelsRepositoryProvider).create('Goa');
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.reel(reel.id));
    await _settle(tester);

    unawaited(router.push(Routes.clip(reel.id, 5)));
    await _settle(tester);

    expect(find.byType(ClipViewerScreen), findsNothing);
    expect(find.byType(ReelDetailScreen), findsOneWidget);
    expect(platform.players, isEmpty);
  });

  for (final location in [
    '/reels/3/clip/abc',
    '/reels/3/clip/0',
    '/reels/3/clip/-1',
    '/reels/abc/clip/1',
    '/reels/0/clip/1',
  ]) {
    testApp('a clip location with a bad id ($location) lands on Reels', (
      tester,
    ) async {
      final (_, router) = await _pumpApp(tester);

      router.go(location);
      await _settle(tester);

      expect(find.byType(ClipViewerScreen), findsNothing);
      expect(find.byType(ReelsScreen), findsOneWidget);
    });
  }

  test('Routes.clip is the clip location of a reel', () {
    expect(Routes.clip(4, 9), '/reels/4/clip/9');
    expect(Routes.reel(4), '/reels/4');
  });

  for (final id in ['abc', '1.5', '0', '-3', '99999999999999999999']) {
    testApp('a reel location with the id "$id" lands on Reels', (tester) async {
      final (_, router) = await _pumpApp(tester);
      router.go(Routes.toTag);
      await tester.pumpAndSettle();

      router.go('/reels/$id');
      await tester.pumpAndSettle();

      expect(find.byType(ReelDetailScreen), findsNothing);
      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
    });
  }

  testApp('system back on Reels is not intercepted', (tester) async {
    await _pumpApp(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isFalse);
  });

  testApp('system back on To tag selects Reels and keeps the app open', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);
    router.go(Routes.toTag);
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(ReelsScreen), findsOneWidget);
    final bar = tester.widget<TtNavPill>(find.byType(TtNavPill));
    expect(bar.currentIndex, 0);
  });

  testApp('each tab keeps its own navigation stack', (tester) async {
    final (_, router) = await _pumpApp(tester);

    Navigator.of(tester.element(find.byType(ReelsScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('dummy-pushed')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('dummy-pushed'), findsOneWidget);

    router.go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('dummy-pushed'), findsNothing);

    router.go(Routes.reels);
    await tester.pumpAndSettle();
    expect(find.text('dummy-pushed'), findsOneWidget);
  });
}
