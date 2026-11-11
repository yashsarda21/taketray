import 'package:flutter/widgets.dart'
    show Navigator, NavigatorState, Size, SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray/features/add_videos/views/add_grid_screen.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

Finder barButton(String label) => find.byWidgetPredicate(
  (w) => w is TtIconButton && w.semanticLabel == label,
  description: 'the "$label" button',
);

Finder inPill(String text) =>
    find.descendant(of: find.byType(TtNavPill), matching: find.text(text));

void main() {
  group('To tag', () {
    /// To tag on fake view models (nothing waiting, Shooting mode off), on a
    /// bridge whose access is [level].
    Future<FakeMediaBridge> pumpToTag(
      WidgetTester tester, {
      MediaAccessLevel level = MediaAccessLevel.full,
    }) async {
      final bridge = FakeMediaBridge()
        ..access = MediaAccess(level: level, canAskAgain: true, sdkInt: 34);
      await pumpScreen(
        tester,
        const ToTagScreen(),
        overrides: <Override>[
          mediaBridgeProvider.overrideWithValue(bridge),
          shootingModeControllerProvider.overrideWith(
            () => FakeShooting(ShootingState.off),
          ),
          mediaAccessControllerProvider.overrideWith(() => FakeAccess(level)),
          toTagControllerProvider.overrideWith(() => FakeToTag(const [])),
          skippedCountProvider.overrideWith((ref) => Stream.value(0)),
          toTagTimesProvider.overrideWith((ref) => Future.value(const {})),
          clockProvider.overrideWithValue(FixedClock(addNow.toUtc())),
          thumbnailCacheForTests,
        ],
      );
      return bridge;
    }

    testWidgets('the app bar has Add videos, which opens it for To tag', (
      tester,
    ) async {
      await pumpToTag(tester);

      expect(barButton('Add videos'), findsOneWidget);
      expect(
        tester.widget<TtIconButton>(barButton('Add videos')).icon,
        Symbols.library_add_rounded,
      );

      await tester.tap(barButton('Add videos'));
      await tester.pumpAndSettle();

      expect(find.text(addVideosRouteMarker(null)), findsOneWidget);
    });

    testWidgets('nothing to tag: the empty state offers Add videos too', (
      tester,
    ) async {
      await pumpToTag(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Add videos'));
      await tester.pumpAndSettle();

      expect(find.text(addVideosRouteMarker(null)), findsOneWidget);
    });

    testWidgets('a double tap opens Add videos once', (tester) async {
      await pumpToTag(tester);

      await tester.tap(barButton('Add videos'));
      await tester.tap(barButton('Add videos'));
      await tester.pumpAndSettle();

      expect(
        find.text(addVideosRouteMarker(null), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a slow access read does not let a second tap open a second '
        'list', (tester) async {
      final bridge = await pumpToTag(tester);
      final slow = bridge.gate('accessReport');

      await tester.tap(barButton('Add videos'));
      // Much longer than the window after a tap.
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(barButton('Add videos'));
      await tester.pump(const Duration(seconds: 2));
      slow.complete();
      await tester.pumpAndSettle();

      expect(bridge.calls.where((c) => c == 'accessReport'), hasLength(1));
      expect(
        find.text(addVideosRouteMarker(null), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('taps are shut out for the whole read and then for the page '
        'to arrive, and no longer', (tester) async {
      final bridge = await pumpToTag(tester);
      final slow = bridge.gate('accessReport');

      await tester.tap(barButton('Add videos'));
      await tester.pump(const Duration(seconds: 5));
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.text(addVideosRouteMarker(null)), findsOneWidget);

      // Back to To tag: a new tap opens again.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text(addVideosRouteMarker(null)), findsNothing);
      await tester.tap(barButton('Add videos'));
      await tester.pumpAndSettle();

      expect(find.text(addVideosRouteMarker(null)), findsOneWidget);
      expect(bridge.calls.where((c) => c == 'accessReport'), hasLength(2));
    });

    testWidgets('a read that fails lets the next tap try again', (
      tester,
    ) async {
      final bridge = await pumpToTag(tester);
      bridge.failNext('accessReport');

      await tester.tap(barButton('Add videos'));
      await tester.pumpAndSettle();
      expect(find.text(addVideosRouteMarker(null)), findsNothing);
      await tester.tap(barButton('Add videos'));
      await tester.pumpAndSettle();

      expect(find.text(addVideosRouteMarker(null)), findsOneWidget);
    });

    testWidgets('leaving To tag during a slow read leaves nothing pending', (
      tester,
    ) async {
      final bridge = await pumpToTag(tester);
      final slow = bridge.gate('accessReport');
      await tester.tap(barButton('Add videos'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      slow.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testWidgets('without full access (${level.name}) the folder browser '
          'does not open', (tester) async {
        await pumpToTag(tester, level: level);

        await tester.tap(barButton('Add videos'));
        await tester.pumpAndSettle();

        expect(find.text(addVideosRouteMarker(null)), findsNothing);
        expect(find.byType(ToTagScreen), findsOneWidget);
      });
    }

    testWidgets('an access read that fails does not open the folder browser', (
      tester,
    ) async {
      final bridge = await pumpToTag(tester);
      bridge.failNext('accessReport');

      await tester.tap(barButton('Add videos'));
      await tester.pumpAndSettle();

      expect(find.text(addVideosRouteMarker(null)), findsNothing);
    });
  });

  group('the reel page', () {
    late VmHarness h;

    setUp(() => h = VmHarness(now: addNow.toUtc()));

    Future<int> reelWithNoClips(WidgetTester tester) async =>
        (await tester.runAsync(
          () => h.container.read(reelsRepositoryProvider).create('Goa'),
        ))!.id;

    Future<void> open(WidgetTester tester, int id) async {
      await pumpScreen(
        tester,
        ReelDetailScreen(reelId: id),
        overrides: h.appOverrides,
        settle: false,
      );
      await settleApp(tester);
    }

    testApp('the app bar has Add videos, which opens it for this reel', (
      tester,
    ) async {
      final id = await reelWithNoClips(tester);
      await open(tester, id);

      expect(barButton('Add videos'), findsOneWidget);

      await tapAndSettle(tester, barButton('Add videos'));

      expect(find.text(addVideosRouteMarker(id)), findsOneWidget);
    });

    testApp('an empty reel says how to fill it and offers Add videos', (
      tester,
    ) async {
      final id = await reelWithNoClips(tester);
      await open(tester, id);

      expect(
        find.text('Tag clips from To tag, or add videos from your phone.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TtButton, 'Go to To tag'), findsOneWidget);

      await tapAndSettle(tester, find.widgetWithText(TtButton, 'Add videos'));

      expect(find.text(addVideosRouteMarker(id)), findsOneWidget);
    });

    testApp('a double tap on the app bar button opens Add videos once', (
      tester,
    ) async {
      final id = await reelWithNoClips(tester);
      await open(tester, id);

      await tester.tap(barButton('Add videos'));
      await tester.tap(barButton('Add videos'));
      await settleApp(tester);

      expect(
        find.text(addVideosRouteMarker(id), skipOffstage: false),
        findsOneWidget,
      );
    });

    testApp('a slow access read does not let a second tap open a second '
        'list', (tester) async {
      final id = await reelWithNoClips(tester);
      await open(tester, id);
      final slow = h.bridge.gate('accessReport');

      await tester.tap(barButton('Add videos'));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(TtButton, 'Add videos'));
      await tester.pump(const Duration(seconds: 2));
      slow.complete();
      await settleApp(tester);

      expect(h.bridge.calls.where((c) => c == 'accessReport'), hasLength(1));
      expect(
        find.text(addVideosRouteMarker(id), skipOffstage: false),
        findsOneWidget,
      );
    });

    testApp('a double tap on the empty reel page Add videos opens it once', (
      tester,
    ) async {
      final id = await reelWithNoClips(tester);
      await open(tester, id);

      final button = find.widgetWithText(TtButton, 'Add videos');
      await tester.tap(button);
      await tester.tap(button);
      await settleApp(tester);

      expect(
        find.text(addVideosRouteMarker(id), skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('in the app', () {
    late AddHarness a;

    setUp(() => a = AddHarness());

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge.putFolder(whatsAppFolder, [
        folderVideo(1, day),
        folderVideo(2, day.add(const Duration(minutes: 5))),
      ]);
      await tester.pumpWidget(
        ProviderScope(overrides: a.overrides, child: const TakeTrayApp()),
      );
      await settleApp(tester);
    }

    testApp('from To tag: the add lands back on To tag, and Undo works after '
        'switching tabs', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, inPill('To tag'));

      await tapAndSettle(tester, barButton('Add videos'));
      expect(find.byType(AddFoldersScreen), findsOneWidget);
      expect(find.text('to To tag'), findsOneWidget);
      await openFolder(tester, 'WhatsApp Video');
      await tapAndSettle(tester, tileOf(1));
      await tapAndSettle(tester, find.text('Add 1'));

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.byType(ToTagScreen), findsOneWidget);
      expect(find.text('1 video added to To tag'), findsOneWidget);
      expect(await a.pendingIds(tester), [1]);

      await tapAndSettle(tester, inPill('Reels'));
      await tapAndSettle(tester, find.text('Undo'));

      expect(await a.pendingIds(tester), isEmpty);
    });

    testApp('from a reel: the add lands back on the reel, which shows the '
        'clip', (tester) async {
      final goa = await a.makeReel(tester, 'Goa');
      await pumpApp(tester);
      await tapAndSettle(tester, find.text('Goa'));

      await tapAndSettle(tester, barButton('Add videos'));
      expect(find.text('to Goa'), findsOneWidget);
      await openFolder(tester, 'WhatsApp Video');
      await tapAndSettle(tester, tileOf(2));
      await tapAndSettle(tester, find.text('Add 1'));

      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(find.text('1 video added to Goa'), findsOneWidget);
      final inReel = (await tester.runAsync(
        () => a.h.media.clips.watchReelClips(goa.id).first,
      ))!;
      expect([for (final c in inReel) c.clip.mediaStoreId], [2]);
      expect(find.byType(TtClipTile), findsOneWidget);
    });
  });
}
