import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/fake_media_bridge.dart';
import 'support/test_app.dart';
import 'support/view_model_fakes.dart';
import 'support/vm_harness.dart';

Finder _inScreen(Type screen, String text) =>
    find.descendant(of: find.byType(screen), matching: find.text(text));

Finder _inPill(String text) =>
    find.descendant(of: find.byType(TtNavPill), matching: find.text(text));

/// The app on an in-memory database and a `FakeMediaBridge`:
/// `MediaLifecycle` runs at start, and must not reach the phone's channels.
Future<VmHarness> _pumpApp(WidgetTester tester) async {
  final harness = VmHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.appOverrides, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testApp('shows the TakeTray nav pill, not the Material bar', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(TtNavPill), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(_inPill('Reels'), findsOneWidget);
    expect(_inPill('To tag'), findsOneWidget);
    expect(_inPill('Settings'), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
  });

  testApp('a cold start with a failing volume counts one failure', (
    tester,
  ) async {
    final harness = VmHarness();
    harness.bridge.put([fakeVideo(id: 1, generation: 5)]);
    final session = await harness.media.turnOnNow();
    harness.bridge.put([fakeVideo(id: 2, generation: 6, sizeBytes: 2)]);
    for (var i = 0; i < 20; i++) {
      harness.bridge.failNext('videosAddedAfter');
    }
    harness.background.shadeAction = ShadeAction(
      kind: ShadeActionKind.turnOff,
      since: session.since!,
      at: DateTime.utc(2026, 6, 1, 18),
      generations: const {'external_primary': 6},
    );

    // The start: the copy's first write and the lifecycle's scan both try
    // the end, at the same moment.
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.appOverrides,
        child: const TakeTrayApp(),
      ),
    );
    // Not pumpAndSettle: with Shooting mode on, its card keeps animating.
    await tester.pump();
    await tester.runAsync(settle);

    // One more failure 5 minutes later is only the second that counts.
    harness.media.clock.advance(const Duration(minutes: 5));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(settle);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(settle);

    final state = await tester.runAsync(harness.media.phoneState.loadShooting);
    expect(state!.on, isTrue);
    expect(harness.background.shadeAction, isNotNull);
  });

  testApp('writes the background copy once at start', (tester) async {
    final harness = await _pumpApp(tester);
    await tester.runAsync(settle);

    expect(harness.background.writes, hasLength(1));
    expect(harness.background.state!.shootingOn, isFalse);
    expect(harness.background.state!.stillReminderEnabled, isTrue);
  });

  testApp('starts the media work through the bridge on the first frame', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    await tester.runAsync(settle);

    expect(
      harness.bridge.calls,
      containsAllInOrder([
        'pendingZoneChanges',
        'currentZoneId',
        'accessReport',
      ]),
    );
  });

  testApp('uses the TakeTray theme', (tester) async {
    await _pumpApp(tester);

    final context = tester.element(find.byType(TtNavPill));
    expect(Theme.of(context).extension<TtThemeData>(), isNotNull);
  });

  testApp('the Reels tab has a large TtAppBar titled Reels', (tester) async {
    await _pumpApp(tester);

    final bar = find.descendant(
      of: find.byType(ReelsScreen),
      matching: find.byType(TtAppBar),
    );
    expect(bar, findsOneWidget);
    expect(tester.widget<TtAppBar>(bar).title, 'Reels');
    expect(tester.widget<TtAppBar>(bar).large, isTrue);
  });

  testApp('opens on Reels and switches tabs', (tester) async {
    await _pumpApp(tester);

    expect(_inScreen(ReelsScreen, 'Reels'), findsOneWidget);

    await tester.tap(_inPill('To tag'));
    await tester.pumpAndSettle();
    expect(_inScreen(ToTagScreen, 'To tag'), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 1);

    await tester.tap(_inPill('Settings'));
    await tester.pumpAndSettle();
    expect(_inScreen(SettingsScreen, 'Settings'), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 2);
  });

  testApp('system back from another tab returns to Reels', (tester) async {
    await _pumpApp(tester);

    await tester.tap(_inPill('Settings'));
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(ReelsScreen), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
  });

  testApp('the To tag item has no badge until phase 5', (tester) async {
    await _pumpApp(tester);

    final item = tester.widget<TtNavPill>(find.byType(TtNavPill)).items[1];
    expect(item.label, 'To tag');
    expect(item.badgeCount, 0);
  });

  testApp('a tab screen can reserve the room the pill takes', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);
    await _pumpApp(tester);

    final context = tester.element(find.byType(ReelsScreen));
    final pillTop = tester.getRect(find.byType(TtGlass)).top;
    expect(TtNavPill.reservedHeight(context), 780 - pillTop);
  });

  testApp('the Reels tab shows the Shooting mode card, off at first', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byType(TtShootingModeCard), findsOneWidget);
    expect(
      tester.widget<TtShootingModeCard>(find.byType(TtShootingModeCard)).on,
      isFalse,
    );
    expect(_inScreen(ReelsScreen, 'Shooting mode'), findsOneWidget);
  });

  testApp('the To tag tab shows the To tag screen, empty', (tester) async {
    await _pumpApp(tester);

    await tester.tap(_inPill('To tag'));
    await tester.pumpAndSettle();

    expect(find.byType(ToTagScreen), findsOneWidget);
    expect(find.text('Nothing to tag'), findsOneWidget);
  });

  testApp('turning on Shooting mode on Reels shows it on To tag', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.tap(find.byType(TtSwitch));
    await tester.runAsync(settle);
    await tester.pump();
    expect(find.text('Shooting mode on'), findsOneWidget);
    expect(
      (await tester.runAsync(harness.media.phoneState.loadShooting))!.on,
      isTrue,
    );

    await tester.tap(_inPill('To tag'));
    await tester.pump();
    await tester.runAsync(settle);
    await tester.pump();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testApp('selecting To tag again checks the clips again', (tester) async {
    final harness = VmHarness();
    final toTag = FakeToTag(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...harness.appOverrides,
          toTagControllerProvider.overrideWith(() => toTag),
        ],
        child: const TakeTrayApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_inPill('To tag'));
    await tester.pumpAndSettle();
    expect(toTag.resumes, 0);

    await tester.tap(_inPill('Reels'));
    await tester.pumpAndSettle();
    expect(toTag.resumes, 0);

    await tester.tap(_inPill('To tag'));
    await tester.pumpAndSettle();
    expect(toTag.resumes, 1);
  });

  testApp('the Undo snack sits above the nav pill', (tester) async {
    // The record dot of the "on" card would pulse for ever, and
    // pumpAndSettle would never settle: the phone says "remove animations".
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    // 12:00 local; one video shot at 09:41 today.
    final harness = VmHarness(now: DateTime(2026, 10, 28, 12).toUtc());
    final shot = DateTime(2026, 10, 28, 9, 41).millisecondsSinceEpoch;
    harness.bridge.put([
      fakeVideo(
        id: 1,
        dateTakenMs: shot,
        dateAddedSec: shot ~/ 1000,
        dateModifiedSec: shot ~/ 1000,
      ),
    ]);
    await tester.runAsync(harness.media.turnOnNow);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.appOverrides,
        child: const TakeTrayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pump();

    await tester.tap(find.text('Add earlier videos'));
    await tester.pump();
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pump();
    await tester.runAsync(settle);
    await tester.pumpAndSettle();

    expect(find.text('1 clip added to To tag'), findsOneWidget);
    expect(find.byType(TtSnack), findsOneWidget);
    final snack = tester.getRect(find.byType(TtSnack));
    final pill = tester.getRect(find.byType(TtNavPill));
    expect(snack.bottom, lessThanOrEqualTo(pill.top));
  });
}
