import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray/features/add_videos/views/add_grid_screen.dart';
import 'package:taketray/features/editors/views/copies_storage_screen.dart';
import 'package:taketray/features/editors/views/copy_progress_screen.dart';
import 'package:taketray/features/editors/views/copy_ready_screen.dart';
import 'package:taketray/features/editors/views/copy_space_screen.dart';
import 'package:taketray/features/editors/views/edit_select_screen.dart';
import 'package:taketray/features/notifications/views/notifications_help_screen.dart';
import 'package:taketray/features/reels/views/clip_viewer_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/features/tagging/views/skipped_screen.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/popup_route_tracker.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../features/reels/edit_session_support.dart' show startEditing;
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

  // Each tab has its own navigator, and the popup tracker needs an observer on
  // every one (a "Still shooting?" dialog must never open over a sheet).
  for (final (name, location, screen) in [
    ('Reels', Routes.reels, ReelsScreen),
    ('To tag', Routes.toTag, ToTagScreen),
    ('Settings', Routes.settings, SettingsScreen),
  ]) {
    testApp("a dialog on the $name tab's own navigator is seen by the popup "
        'tracker', (tester) async {
      final (container, router) = await _pumpApp(tester);
      final tracker = container.read(popupRouteTrackerProvider);
      router.go(location);
      await tester.pumpAndSettle();
      expect(tracker.isOpen, isFalse);

      final context = tester.element(find.byType(screen));
      unawaited(
        showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (_) => const AlertDialog(title: Text('d')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tracker.isOpen, isTrue);

      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(tracker.isOpen, isFalse);
    });
  }

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

  test('the Done editing location is the reel page with the done flag', () {
    expect(Routes.reelDoneParameter, 'done');
    expect(Routes.reelDoneEditing(7), '/reels/7?done=1');
    expect(Routes.reelDoneEditing(7), '${Routes.reel(7)}?done=1');
    final uri = Uri.parse(Routes.reelDoneEditing(12345));
    expect(uri.path, Routes.reel(12345));
    expect(uri.queryParameters, {Routes.reelDoneParameter: '1'});
  });

  testApp('the Done editing location shows that reel page', (tester) async {
    final h = VmHarness();
    final reel = await h.container.read(reelsRepositoryProvider).create('Goa');
    final (_, router) = await _pumpApp(tester, harness: h);

    router.go(Routes.reelDoneEditing(reel.id));
    await _settle(tester);

    expect(
      tester.widget<ReelDetailScreen>(find.byType(ReelDetailScreen)).reelId,
      reel.id,
    );
    expect(router.routerDelegate.currentConfiguration.uri.queryParameters, {
      Routes.reelDoneParameter: '1',
    });
  });

  testApp('the Done editing location asks Done editing once for a reel with '
      'a session; Back and forth does not ask again', (tester) async {
    FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final reel = await h.container.read(reelsRepositoryProvider).create('Goa');
    final ids = (await tester.runAsync(
      () => putInReel(h, reel.id, [reelVideo(1), reelVideo(2)]),
    ))!;
    await tester.runAsync(
      () => startEditing(h, reel.id, EditorApp.vn, copied: [ids[0]]),
    );
    final (_, router) = await _pumpApp(tester, harness: h);

    router.go(Routes.reelDoneEditing(reel.id));
    await _settle(tester);
    expect(
      tester
          .widget<ReelDetailScreen>(find.byType(ReelDetailScreen))
          .askDoneEditing,
      isTrue,
    );
    expect(find.text('Have you exported your video?'), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await _settle(tester);
    expect(find.byType(TtDialog<bool>), findsNothing);

    // The viewer and back.
    unawaited(router.push(Routes.clip(reel.id, ids[1])));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(ReelDetailScreen), findsOneWidget);
    expect(find.byType(TtDialog<bool>), findsNothing);

    // Another tab and back.
    Finder tab(String label) =>
        find.descendant(of: find.byType(TtNavPill), matching: find.text(label));
    await tester.tap(tab('Settings'));
    await _settle(tester);
    await tester.tap(tab('Reels'));
    await _settle(tester);
    expect(find.byType(TtDialog<bool>), findsNothing);
  });

  testApp('a plain reel location never asks Done editing', (tester) async {
    final h = reelHarness();
    final reel = await h.container.read(reelsRepositoryProvider).create('Goa');
    final ids = (await tester.runAsync(
      () => putInReel(h, reel.id, [reelVideo(1)]),
    ))!;
    await tester.runAsync(
      () => startEditing(h, reel.id, EditorApp.vn, copied: ids),
    );
    final (_, router) = await _pumpApp(tester, harness: h);

    router.go(Routes.reel(reel.id));
    await _settle(tester);

    expect(
      tester
          .widget<ReelDetailScreen>(find.byType(ReelDetailScreen))
          .askDoneEditing,
      isFalse,
    );
    expect(find.byType(TtDialog<bool>), findsNothing);
    expect(find.text('Done editing'), findsOneWidget);
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

  testApp('the tag player opens above the shell, with no nav pill, on the '
      'clip in ?from, and back returns to To tag', (tester) async {
    final platform = FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final ids = (await tester.runAsync(
      () => h.media.store([reelVideo(1), reelVideo(2), reelVideo(3)]),
    ))!;
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.toTag);
    await _settle(tester);
    expect(find.byType(TtNavPill), findsOneWidget);

    unawaited(router.push(Routes.tagFrom(ids[1])));
    await _settle(tester);

    expect(find.byType(TagPlayerScreen), findsOneWidget);
    expect(
      tester.widget<TagPlayerScreen>(find.byType(TagPlayerScreen)).startClipId,
      ids[1],
    );
    expect(find.byType(TtNavPill), findsNothing);
    expect(
      tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).title,
      '2 of 3',
    );
    expect(
      platform.uris.first,
      'content://media/external_primary/video/media/2',
    );

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(TagPlayerScreen), findsNothing);
    expect(find.byType(ToTagScreen), findsOneWidget);
    expect(find.byType(TtNavPill), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 1);
    expect(platform.live, isEmpty);
  });

  testApp('a tile on To tag opens the tag player on that clip', (tester) async {
    FakeVideoPlayerPlatform.install();
    final h = reelHarness();
    final ids = (await tester.runAsync(
      () => h.media.store([reelVideo(1), reelVideo(2), reelVideo(3)]),
    ))!;
    final (_, router) = await _pumpApp(tester, harness: h);
    router.go(Routes.toTag);
    await _settle(tester);

    await tester.tap(find.byType(TtClipTile).at(2));
    await _settle(tester);

    expect(
      tester.widget<TagPlayerScreen>(find.byType(TagPlayerScreen)).startClipId,
      ids[2],
    );
  });

  testApp('Skipped opens inside the To tag tab, and back returns to To tag', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);
    router.go(Routes.toTag);
    await _settle(tester);

    unawaited(router.push(Routes.skipped));
    await _settle(tester);

    expect(find.byType(SkippedScreen), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    // Inside the tab: the nav pill stays, on To tag.
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 1);

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.byType(SkippedScreen), findsNothing);
    expect(find.byType(ToTagScreen), findsOneWidget);
  });

  test('Routes.skipped is inside the To tag tab', () {
    expect(Routes.skipped, '/to-tag/skipped');
    expect(Routes.skipped, startsWith(Routes.toTag));
  });

  for (final from in ['abc', '0', '-2', '1.5', '']) {
    testApp('the tag player with ?from=$from starts on the first clip', (
      tester,
    ) async {
      FakeVideoPlayerPlatform.install();
      final h = reelHarness();
      await tester.runAsync(() => h.media.store([reelVideo(1), reelVideo(2)]));
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(router.push('${Routes.tagPlayer}?from=$from'));
      await _settle(tester);

      expect(
        tester
            .widget<TagPlayerScreen>(find.byType(TagPlayerScreen))
            .startClipId,
        isNull,
      );
      expect(
        tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).title,
        '1 of 2',
      );
    });
  }

  test('Routes.tagFrom is the tag player location', () {
    expect(Routes.tagPlayer, '/to-tag/play');
    expect(Routes.tagFrom(null), '/to-tag/play');
    expect(Routes.tagFrom(12), '/to-tag/play?from=12');
  });

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

  testApp('Settings shows the Settings screen with its Help row', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);

    router.go(Routes.settings);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Notifications not arriving?'), findsOneWidget);
  });

  testApp('the help screen is a full-screen page above Settings', (
    tester,
  ) async {
    expect(Routes.notificationsHelp, '/settings/notifications-help');
    final (_, router) = await _pumpApp(tester);
    router.go(Routes.settings);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifications not arriving?'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsHelpScreen), findsOneWidget);
    expect(find.byType(TtNavPill).hitTestable(), findsNothing);

    await tester.tap(find.byType(TtIconButton));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsHelpScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 2);
  });

  testApp('the system Back key leaves the help screen for Settings', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);
    router.go(Routes.notificationsHelp);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsHelpScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsHelpScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testApp('the VN copies screen is a full-screen page above Settings', (
    tester,
  ) async {
    expect(Routes.copiesStorage, '/settings/vn-copies');
    final harness = VmHarness();
    harness.editors.allow({'filesInCopyFolders'});
    final (_, router) = await _pumpApp(tester, harness: harness);
    router.go(Routes.settings);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Storage used by VN copies'));
    await tester.pumpAndSettle();

    expect(find.byType(CopiesStorageScreen), findsOneWidget);
    expect(find.byType(TtNavPill).hitTestable(), findsNothing);

    await tester.tap(find.byType(TtIconButton));
    await tester.pumpAndSettle();

    expect(find.byType(CopiesStorageScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 2);
  });

  testApp('the system Back key leaves the VN copies screen for Settings', (
    tester,
  ) async {
    final harness = VmHarness();
    harness.editors.allow({'filesInCopyFolders'});
    final (_, router) = await _pumpApp(tester, harness: harness);
    router.go(Routes.copiesStorage);
    await tester.pumpAndSettle();
    expect(find.byType(CopiesStorageScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(CopiesStorageScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('Picking clips for an editor (Phase 8, D-126)', () {
    test('the locations', () {
      expect(Routes.editSelect, '/edit');
      expect(Routes.editSelectOf(7), '/edit?reel=7');
      expect(
        Routes.editSelectOf(7, clipIds: [3, 5, 9]),
        '/edit?reel=7&clips=3%2C5%2C9',
      );
      expect(Routes.editSelectOf(7, add: true), '/edit?reel=7&add=1');
      final both = Uri.parse(Routes.editSelectOf(7, clipIds: [4], add: true));
      expect(both.path, '/edit');
      expect(both.queryParameters, {
        Routes.editReelParameter: '7',
        Routes.editClipsParameter: '4',
        Routes.editAddParameter: '1',
      });
      expect(Routes.copySpace, '/edit/space');
      final space = Uri.parse(Routes.copySpaceOf(7, EditorApp.vn, [8, 2]));
      expect(space.path, '/edit/space');
      expect(space.queryParameters, {
        Routes.editReelParameter: '7',
        Routes.copyEditorParameter: 'vn',
        Routes.editClipsParameter: '8,2',
      });
      expect(Routes.copyProgress, '/edit/copying');
      final progress = Uri.parse(Routes.copyProgressOf('7-1700000000000'));
      expect(progress.path, '/edit/copying');
      expect(progress.queryParameters, {
        Routes.copyJobParameter: '7-1700000000000',
      });
      expect(Routes.copyReady, '/edit/ready');
      final ready = Uri.parse(Routes.copyReadyOf(7));
      expect(ready.path, '/edit/ready');
      expect(ready.queryParameters, {Routes.editReelParameter: '7'});
      // The job's clips, when known (an empty job still says so).
      expect(
        Uri.parse(Routes.copyReadyOf(7, clipIds: [8, 2])).queryParameters,
        {Routes.editReelParameter: '7', Routes.editClipsParameter: '8,2'},
      );
      expect(Uri.parse(Routes.copyReadyOf(7, clipIds: [])).queryParameters, {
        Routes.editReelParameter: '7',
        Routes.editClipsParameter: '',
      });
    });

    test('clipIdsIn keeps the positive whole numbers once, in order', () {
      expect(Routes.clipIdsIn('3,5,9'), [3, 5, 9]);
      expect(Routes.clipIdsIn('9,3,9,5,3'), [9, 3, 5]);
      expect(Routes.clipIdsIn('3,x,,0,-4,5.5,8'), [3, 8]);
      expect(Routes.clipIdsIn(''), isEmpty);
      expect(Routes.clipIdsIn(null), isEmpty);
      expect(Routes.clipIdsIn('x'), isEmpty);
      // Only plain digits: no hex, sign, spaces or separators (T9-m8).
      expect(Routes.clipIdsIn('0x10,+5,5 ,3'), [3]);
      expect(Routes.clipIdsIn('1_0,0010,٣'), [10]);
      expect(Routes.clipIdsIn(' 7,8'), [8]);
      expect(Routes.clipIdsIn('99999999999999999999,4'), [4]);
    });

    testApp('the picking screen is full screen, above the nav pill, with '
        'the reel, the preselected clips and the add flag', (tester) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      ))!;
      // Add mode stays only for a reel in a VN session (D-128); one with a
      // copy, as the app's start ends a session that holds nothing.
      final ids = (await tester.runAsync(
        () => putInReel(h, goa.id, [reelVideo(1)]),
      ))!;
      await tester.runAsync(
        () => startEditing(h, goa.id, EditorApp.vn, copied: ids),
      );
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(
        router.push(Routes.editSelectOf(goa.id, clipIds: [4, 5], add: true)),
      );
      await tester.pumpAndSettle();

      final screen = tester.widget<EditSelectScreen>(
        find.byType(EditSelectScreen),
      );
      expect(screen.reelId, goa.id);
      expect(screen.clipIds, [4, 5]);
      expect(screen.addMode, isTrue);
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(EditSelectScreen), findsNothing);
    });

    testApp('without clips or the flag: nothing preselected, no add mode', (
      tester,
    ) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      ))!;
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(router.push(Routes.editSelectOf(goa.id)));
      await tester.pumpAndSettle();

      final screen = tester.widget<EditSelectScreen>(
        find.byType(EditSelectScreen),
      );
      expect(screen.clipIds, isEmpty);
      expect(screen.addMode, isFalse);
    });

    testApp('bad clip ids are left out, a flag other than 1 is no add mode', (
      tester,
    ) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      ))!;
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(router.push('/edit?reel=${goa.id}&clips=3,x,0,5&add=yes'));
      await tester.pumpAndSettle();

      final screen = tester.widget<EditSelectScreen>(
        find.byType(EditSelectScreen),
      );
      expect(screen.clipIds, [3, 5]);
      expect(screen.addMode, isFalse);
    });

    testApp('from a reel: Edit video, pick, Continue, CapCut leaves the '
        'picking screen for the reel page under it, with the snack', (
      tester,
    ) async {
      final h = reelHarness();
      h.editors
        ..allow({'apps', 'sendTo', 'copyFolderNames'})
        ..installed = {EditorApp.capcut.packageName: true};
      final goa = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      ))!;
      await tester.runAsync(
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      final (_, router) = await _pumpApp(tester, harness: h);
      router.go(Routes.reel(goa.id));
      await _settle(tester);

      await tester.tap(find.byType(TtFab));
      await _settle(tester);
      expect(find.byType(EditSelectScreen), findsOneWidget);
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await _settle(tester);
      await tester.tap(find.text('CapCut'));
      await _settle(tester);

      expect(find.byType(EditSelectScreen), findsNothing);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
      expect(h.editors.sent, hasLength(1));
      // Back on the reel's page: Back goes to Reels, not to the picker.
      expect(router.canPop(), isTrue);
      // The offer of Ready to edit comes 1.3 s later.
      await tester.pump(const Duration(milliseconds: 1500));
      await _settle(tester);
      expect(find.text('Mark Goa as Ready to edit?'), findsOneWidget);
    });

    for (final location in [
      '/edit',
      '/edit?reel=',
      '/edit?reel=0',
      '/edit?reel=-3',
      '/edit?reel=abc',
      '/edit?clips=3,4',
    ]) {
      testApp('$location is unknown: Reels', (tester) async {
        final (_, router) = await _pumpApp(tester);

        router.go(location);
        await tester.pumpAndSettle();

        expect(find.byType(EditSelectScreen), findsNothing);
        expect(find.byType(ReelsScreen), findsOneWidget);
      });
    }
  });

  group('The VN copy screens (Phase 8, D-127)', () {
    ReelsRepository reels0(VmHarness h) =>
        h.container.read(reelsRepositoryProvider);

    testApp('the space check is full screen, above the nav pill, with the '
        'reel, the editor and the clips in the order given', (tester) async {
      final h = reelHarness();
      h.editors.allow({'freeBytes', 'copyFolderNames'});
      final goa = (await tester.runAsync(() => reels0(h).create('Goa')))!;
      final ids = (await tester.runAsync(
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      ))!;
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(router.push(Routes.copySpaceOf(goa.id, EditorApp.vn, ids)));
      await _settle(tester);

      final screen = tester.widget<CopySpaceScreen>(
        find.byType(CopySpaceScreen),
      );
      expect(screen.reelId, goa.id);
      expect(screen.editor, EditorApp.vn);
      expect(screen.clipIds, ids);
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);
      expect(find.text('Copy clips for VN'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(CopySpaceScreen), findsNothing);
    });

    testApp('the progress screen is full screen with the job id', (
      tester,
    ) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(() => reels0(h).create('Goa')))!;
      final jobId = '${goa.id}-1700000000000';
      h.copy
        ..allowAll()
        ..job = CopyJob(
          jobId: jobId,
          reelId: goa.id,
          folderName: 'Goa',
          state: CopyState.running,
          total: 2,
          done: 0,
          bytesDone: 0,
          bytesTotal: 2,
          copied: const [],
          failedClipIds: const [],
          undeleted: const [],
        );
      final (_, router) = await _pumpApp(tester, harness: h);
      await _settle(tester);
      // The app itself opened it (a job that runs, found at start): leave it
      // and open it by its location.
      router.go(Routes.reels);
      await _settle(tester);

      unawaited(router.push(Routes.copyProgressOf(jobId)));
      await _settle(tester);

      expect(
        tester
            .widget<CopyProgressScreen>(find.byType(CopyProgressScreen))
            .jobId,
        jobId,
      );
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);
    });

    testApp('the ready screen is full screen with the reel', (tester) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(() => reels0(h).create('Goa')))!;
      // A session with a copy: an empty one is ended by the app's start.
      final ids = (await tester.runAsync(
        () => putInReel(h, goa.id, [reelVideo(1)]),
      ))!;
      await tester.runAsync(() async {
        final sessions = h.container.read(editSessionsRepositoryProvider);
        await sessions.startSession(goa.id, EditorApp.vn, 'Goa');
        await sessions.recordCopies([
          EditCopy(
            reelId: goa.id,
            clipId: ids.single,
            copyMediaStoreId: 700,
            fileName: 'c.mp4',
            sizeBytes: 1,
            copiedAt: DateTime.utc(2026, 10, 30),
          ),
        ]);
      });
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(router.push(Routes.copyReadyOf(goa.id)));
      await _settle(tester);

      expect(
        tester.widget<CopyReadyScreen>(find.byType(CopyReadyScreen)).reelId,
        goa.id,
      );
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);
      expect(find.text('Ready for VN'), findsOneWidget);
      // No clips in the location: the pictures are any clips with a copy.
      expect(
        tester.widget<CopyReadyScreen>(find.byType(CopyReadyScreen)).clipIds,
        isNull,
      );

      // The job's clips: the valid ids, each once; none given is an empty
      // set, not "any".
      for (final (location, expected) in [
        (Routes.copyReadyOf(goa.id, clipIds: [9, 3, 9, 5]), {9, 3, 5}),
        ('/edit/ready?reel=${goa.id}&clips=3,x,,0,-4,8', {3, 8}),
        ('/edit/ready?reel=${goa.id}&clips=', <int>{}),
        ('/edit/ready?reel=${goa.id}&clips=x', <int>{}),
      ]) {
        unawaited(router.push(location));
        await _settle(tester);
        expect(
          tester.widget<CopyReadyScreen>(find.byType(CopyReadyScreen)).clipIds,
          expected,
          reason: location,
        );
      }
    });

    for (final location in [
      '/edit/space',
      '/edit/space?reel=0&editor=vn&clips=1',
      '/edit/space?reel=abc&editor=vn&clips=1',
      '/edit/space?reel=3&clips=1',
      '/edit/space?reel=3&editor=word&clips=1',
      '/edit/space?reel=3&editor=vn',
      '/edit/space?reel=3&editor=vn&clips=x,0',
      '/edit/copying',
      '/edit/copying?job=',
      '/edit/ready',
      '/edit/ready?reel=0',
      '/edit/ready?reel=-2',
      '/edit/ready?reel=x',
    ]) {
      testApp('$location is unknown: Reels', (tester) async {
        final (_, router) = await _pumpApp(tester);

        router.go(location);
        await tester.pumpAndSettle();

        expect(find.byType(CopySpaceScreen), findsNothing);
        expect(find.byType(CopyProgressScreen), findsNothing);
        expect(find.byType(CopyReadyScreen), findsNothing);
        expect(find.byType(ReelsScreen), findsOneWidget);
      });
    }
  });

  group('Add videos (Phase 7, D-114)', () {
    test('the locations', () {
      expect(Routes.addVideos, '/add-videos');
      expect(Routes.addVideosFolder, '/add-videos/folder');
      expect(Routes.addVideosTo(), '/add-videos');
      expect(Routes.addVideosTo(reelId: 7), '/add-videos?reel=7');
      final folder = Uri.parse(
        Routes.addVideosFolderOf('1234-5678', 'A & B/?#ü/', reelId: 7),
      );
      expect(folder.path, Routes.addVideosFolder);
      expect(folder.queryParameters, {
        Routes.addVideosVolumeParameter: '1234-5678',
        Routes.addVideosPathParameter: 'A & B/?#ü/',
        Routes.addVideosReelParameter: '7',
      });
      final root = Uri.parse(Routes.addVideosFolderOf('external_primary', ''));
      expect(root.queryParameters, {
        Routes.addVideosVolumeParameter: 'external_primary',
        Routes.addVideosPathParameter: '',
      });
    });

    testApp('the folder list is full screen, for To tag or for a reel', (
      tester,
    ) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      ))!;
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(router.push(Routes.addVideosTo()));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AddFoldersScreen>(find.byType(AddFoldersScreen)).target,
        const AddToToTag(),
      );
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AddFoldersScreen), findsNothing);
      unawaited(router.push(Routes.addVideosTo(reelId: goa.id)));
      await _settle(tester);

      expect(
        tester.widget<AddFoldersScreen>(find.byType(AddFoldersScreen)).target,
        AddToReel(goa.id),
      );
    });

    testApp('the grid gets its folder and target from the location', (
      tester,
    ) async {
      final h = reelHarness();
      final goa = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      ))!;
      final (_, router) = await _pumpApp(tester, harness: h);

      unawaited(
        router.push(
          Routes.addVideosFolderOf('1234-5678', 'DCIM/A & B/', reelId: goa.id),
        ),
      );
      await _settle(tester);

      final grid = tester.widget<AddGridScreen>(find.byType(AddGridScreen));
      expect(grid.volumeName, '1234-5678');
      expect(grid.relativePath, 'DCIM/A & B/');
      expect(grid.target, AddToReel(goa.id));
      expect(find.byType(TtNavPill).hitTestable(), findsNothing);
    });

    testApp('Add videos for a reel that does not exist closes at once', (
      tester,
    ) async {
      final (_, router) = await _pumpApp(tester);
      router.go(Routes.toTag);
      await tester.pumpAndSettle();

      unawaited(router.push(Routes.addVideosTo(reelId: 99)));
      await _settle(tester);

      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.byType(ToTagScreen), findsOneWidget);
    });

    testApp('a grid location with no path is the volume root', (tester) async {
      final (_, router) = await _pumpApp(tester);

      unawaited(
        router.push('${Routes.addVideosFolder}?volume=external_primary'),
      );
      await tester.pumpAndSettle();

      final grid = tester.widget<AddGridScreen>(find.byType(AddGridScreen));
      expect(grid.relativePath, '');
      expect(grid.target, const AddToToTag());
    });

    for (final location in [
      '/add-videos?reel=abc',
      '/add-videos?reel=0',
      '/add-videos?reel=-3',
      '/add-videos/folder',
      '/add-videos/folder?volume=',
      '/add-videos/folder?volume=external_primary&reel=x',
    ]) {
      testApp('a bad Add videos location ($location) lands on Reels, and is '
          'not logged', (tester) async {
        final (_, router) = await _pumpApp(tester);
        router.go(Routes.toTag);
        await tester.pumpAndSettle();
        final logged = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(logged.add);
        addTearDown(sub.cancel);

        router.go(location);
        await tester.pumpAndSettle();

        expect(find.byType(AddFoldersScreen), findsNothing);
        expect(find.byType(AddGridScreen), findsNothing);
        expect(find.byType(ReelsScreen), findsOneWidget);
        expect(
          logged.map((r) => r.message).join(),
          isNot(contains('add-videos')),
        );
      });
    }
  });
}
