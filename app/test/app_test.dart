import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/app/database_refresh.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/access_step_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/onboarding_redirect.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/fake_media_bridge.dart';
import 'support/fixed_onboarding.dart';
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

/// An onboarding controller whose first read waits for [read].
class _SlowOnboarding extends OnboardingController {
  _SlowOnboarding(this.read);

  final Completer<OnboardingFlags> read;

  @override
  Future<OnboardingFlags> build() => read.future;
}

const _doneFlags = OnboardingFlags(
  done: true,
  introPlayed: true,
  homeTipSeen: true,
);

const _freshFlags = OnboardingFlags(
  done: false,
  introPlayed: false,
  homeTipSeen: false,
);

/// The app on [harness], one pump in: the first frame is built, not settled.
Future<ProviderContainer> _start(WidgetTester tester, VmHarness harness) async {
  final container = ProviderContainer(overrides: harness.appOverrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TakeTrayApp()),
  );
  return container;
}

int _tab(WidgetTester tester) =>
    tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex;

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

  testApp('a resume re-reads the reels a share saved, with one listener '
      '(D-164)', (tester) async {
    final harness = await _pumpApp(tester);
    expect(find.byType(DatabaseRefresh), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(MaterialApp),
        matching: find.byType(DatabaseRefresh),
      ),
      findsOneWidget,
    );
    final notified = <Set<String>>[];
    final sub = harness.media.db.tableUpdates().listen(
      (u) => notified.add({for (final t in u) t.table}),
    );
    addTearDown(sub.cancel);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(
      notified.where((u) => u.containsAll({'reels', 'reel_references'})),
      isNotEmpty,
    );
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

  testApp('the Reels tab has a large collapsing header titled Reels (D-196)', (
    tester,
  ) async {
    await _pumpApp(tester);

    final bar = find.descendant(
      of: find.byType(ReelsScreen),
      matching: find.byType(TtLargeSliverAppBar),
    );
    expect(bar, findsOneWidget);
    expect(tester.widget<TtLargeSliverAppBar>(bar).title, 'Reels');
  });

  testApp('opens on Reels and switches tabs', (tester) async {
    await _pumpApp(tester);

    // Material builds the large header's title twice: the page title, and
    // the bar's small one that shows once the page scrolls (D-195).
    expect(_inScreen(ReelsScreen, 'Reels'), findsNWidgets(2));

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
    // The compact off card (D-196): one row, its line, no chips.
    final card = tester.widget<TtShootingModeCard>(
      find.byType(TtShootingModeCard),
    );
    expect(card.subtitle, 'Off · turn it on before you film');
    expect(card.chips, isEmpty);
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
    expect(
      find.descendant(
        of: find.byType(TtShootingModeCard),
        matching: find.text('Shooting'),
      ),
      findsOneWidget,
    );
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

    // The on card's Earlier videos chip (D-196).
    await tester.tap(find.text('Earlier videos'));
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

  group('the first frame (D-136)', () {
    testApp('is held while the flags are read, and sent once they are', (
      tester,
    ) async {
      final read = Completer<OnboardingFlags>();
      await _start(tester, VmHarness(onboarding: () => _SlowOnboarding(read)));
      await tester.pump();
      expect(tester.binding.sendFramesToEngine, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.sendFramesToEngine, isFalse);

      read.complete(_doneFlags);
      await tester.pump();
      expect(tester.binding.sendFramesToEngine, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ReelsScreen), findsOneWidget);

      // The 2 s limit was called off: passing it changes nothing (a second
      // allowFirstFrame would fail an assertion).
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(ReelsScreen), findsOneWidget);
    });

    testApp('flags known at once: the frame is not held', (tester) async {
      await _start(tester, VmHarness());
      await tester.pump();

      expect(tester.binding.sendFramesToEngine, isTrue);
    });

    testApp('a read that never ends: frames are sent after 2 s, on the '
        'welcome', (tester) async {
      final read = Completer<OnboardingFlags>();
      await _start(tester, VmHarness(onboarding: () => _SlowOnboarding(read)));

      await tester.pump(const Duration(milliseconds: 1999));
      expect(tester.binding.sendFramesToEngine, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.sendFramesToEngine, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(ReelsScreen), findsNothing);
    });

    testApp('a read that ends after the 2 s limit still counts: done gives '
        'Reels', (tester) async {
      final read = Completer<OnboardingFlags>();
      await _start(tester, VmHarness(onboarding: () => _SlowOnboarding(read)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      read.complete(_doneFlags);
      await tester.pumpAndSettle();

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(tester.binding.sendFramesToEngine, isTrue);
    });

    testApp('the app taken down before the flags arrive lets frames go and '
        'leaves no timer', (tester) async {
      final read = Completer<OnboardingFlags>();
      final container = await _start(
        tester,
        VmHarness(onboarding: () => _SlowOnboarding(read)),
      );
      await tester.pump();
      expect(tester.binding.sendFramesToEngine, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.binding.sendFramesToEngine, isTrue);
      // What the app's providers left (the midnight tick) goes with the
      // container; testWidgets then fails the test if the 2 s timer is still
      // pending.
      container.dispose();
      await tester.pump(Duration.zero);
    });
  });

  group('during onboarding (D-136)', () {
    testApp('the first scan still runs while the welcome shows', (
      tester,
    ) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      await _start(tester, harness);
      await tester.pumpAndSettle();
      await tester.runAsync(settle);
      await tester.pump();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        harness.bridge.calls,
        containsAllInOrder([
          'pendingZoneChanges',
          'currentZoneId',
          'accessReport',
        ]),
      );
      expect(harness.background.writes, hasLength(1));
    });

    testApp('a tap on a notification leaves the welcome showing, and is not '
        'opened after onboarding', (tester) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();

      harness.background.emit(LaunchAction.toTag);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(ToTagScreen), findsNothing);

      await container.read(onboardingControllerProvider.notifier).finish();
      container.read(appRouterProvider).go(Routes.reels);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(ToTagScreen), findsNothing);
      expect(_tab(tester), 0);
    });

    testApp('a tap during a later step leaves that step showing', (
      tester,
    ) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.byType(AccessStepScreen), findsOneWidget);

      harness.background
        ..emit(LaunchAction.toTag)
        ..emit(LaunchAction.reels);
      await tester.pumpAndSettle();

      expect(find.byType(AccessStepScreen), findsOneWidget);
      expect(
        container.read(appRouterProvider).state.uri.path,
        Routes.onboardingAccess,
      );
    });

    testApp('the start tap waits for the flags: not done drops it, it is not '
        'merely redirected', (tester) async {
      final records = captureLogs();
      final read = Completer<OnboardingFlags>();
      final harness = VmHarness(onboarding: () => _SlowOnboarding(read));
      harness.background.startAction = LaunchAction.toTag;
      final container = await _start(tester, harness);
      await tester.pump();
      // The router's own navigations: a tap that was kept would `go` to the
      // to-tag screen (and the redirect would send it back to the welcome).
      final visited = <String>[];
      final router = container.read(appRouterProvider);
      void record() => visited.add(router.state.uri.path);
      router.routerDelegate.addListener(record);
      addTearDown(() => router.routerDelegate.removeListener(record));

      read.complete(_freshFlags);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(logText(records), contains('A tap during onboarding was dropped'));
      expect(visited, isNot(contains(Routes.toTag)));

      await container.read(onboardingControllerProvider.notifier).finish();
      container.read(appRouterProvider).go(Routes.reels);
      await tester.pumpAndSettle();
      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(ToTagScreen), findsNothing);
      expect(_tab(tester), 0);
    });

    testApp('the start tap waits for the flags: done opens it', (tester) async {
      final read = Completer<OnboardingFlags>();
      final harness = VmHarness(onboarding: () => _SlowOnboarding(read));
      harness.background.startAction = LaunchAction.toTag;
      await _start(tester, harness);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      read.complete(_doneFlags);
      await tester.pumpAndSettle();

      expect(find.byType(ToTagScreen), findsOneWidget);
      expect(_tab(tester), 1);
    });

    testApp('a tap after onboarding finished opens as before', (tester) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();
      await container.read(onboardingControllerProvider.notifier).finish();
      await tester.pumpAndSettle();
      expect(find.byType(ReelsScreen), findsOneWidget);

      harness.background.emit(LaunchAction.toTag);
      await tester.pumpAndSettle();

      expect(find.byType(ToTagScreen), findsOneWidget);
      expect(_tab(tester), 1);
    });
  });

  group('openReel held through onboarding (D-165)', () {
    // The paths the router showed, one per navigation.
    List<String> watch(ProviderContainer container) {
      final visited = <String>[];
      final router = container.read(appRouterProvider);
      void record() => visited.add(router.state.uri.toString());
      router.routerDelegate.addListener(record);
      addTearDown(() => router.routerDelegate.removeListener(record));
      return visited;
    }

    Future<int> makeReel(VmHarness harness, String name) async =>
        (await ReelsRepository(
          harness.media.db,
          harness.media.clock,
        ).create(name)).id;

    Future<void> finishOnboarding(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await container.read(onboardingControllerProvider.notifier).finish();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    String location(ProviderContainer container) =>
        container.read(appRouterProvider).state.uri.toString();

    testApp('onboarding done: it opens the reel References at once', (
      tester,
    ) async {
      final harness = VmHarness();
      final id = await makeReel(harness, 'Goa');
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();

      harness.background.emit(LaunchAction.openReel, reelId: id);
      await tester.pumpAndSettle();

      expect(location(container), Routes.reelReferences(id));
      expect(find.byType(ReelDetailScreen), findsOneWidget);
    });

    testApp('not done: nothing opens until done flips, then it opens once, '
        'never twice', (tester) async {
      final records = captureLogs();
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final repo = _CountingReels(harness.media.db, harness.media.clock);
      final id = (await repo.create('Goa')).id;
      final container = ProviderContainer(
        overrides: [
          ...harness.appOverrides,
          reelsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TakeTrayApp(),
        ),
      );
      await tester.pumpAndSettle();
      final visited = watch(container);

      harness.background.emit(LaunchAction.openReel, reelId: id);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(ReelDetailScreen), findsNothing);
      expect(visited, isNot(contains(Routes.reelReferences(id))));
      expect(repo.lookups, 0, reason: 'nothing is looked up while it waits');
      expect(logText(records), contains('held'));
      expect(logText(records), contains('$id'));
      expect(logText(records), isNot(contains('Goa')));

      await finishOnboarding(tester, container);

      expect(location(container), Routes.reelReferences(id));
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(
        visited.where((v) => v == Routes.reelReferences(id)),
        hasLength(1),
      );
      expect(repo.lookups, 1, reason: 'opened once, not twice');

      // Away and back: the held reel is used up and is not opened again.
      container.read(appRouterProvider).go(Routes.reels);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(location(container), Routes.reels);
      expect(
        visited.where((v) => v == Routes.reelReferences(id)),
        hasLength(1),
      );

      // Even if the gate reports done again (it can be reset and set again),
      // the used-up reel does not come back.
      final gate = container.read(onboardingGateProvider)..value = _freshFlags;
      await tester.pumpAndSettle();
      gate.value = _doneFlags;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.lookups, 1);
      expect(location(container), Routes.reels);
    });

    testApp('two openReels while not done: only the newest opens', (
      tester,
    ) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final one = await makeReel(harness, 'One');
      final two = await makeReel(harness, 'Two');
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();
      final visited = watch(container);

      harness.background.emit(LaunchAction.openReel, reelId: one);
      harness.background.emit(LaunchAction.openReel, reelId: two);
      await tester.pumpAndSettle();
      await finishOnboarding(tester, container);

      expect(location(container), Routes.reelReferences(two));
      expect(visited, isNot(contains(Routes.reelReferences(one))));
    });

    testApp('toTag and Reels while not done are dropped even after done, '
        'with or without a held reel', (tester) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final id = await makeReel(harness, 'Goa');
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();
      final visited = watch(container);

      harness.background
        ..emit(LaunchAction.toTag)
        ..emit(LaunchAction.openReel, reelId: id)
        ..emit(LaunchAction.reels)
        ..emit(LaunchAction.toTag);
      await tester.pumpAndSettle();
      await finishOnboarding(tester, container);

      expect(location(container), Routes.reelReferences(id));
      expect(visited, isNot(contains(Routes.toTag)));
      expect(find.byType(ToTagScreen), findsNothing);
    });

    testApp('toTag alone while not done is dropped even after done', (
      tester,
    ) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();
      final visited = watch(container);

      harness.background.emit(LaunchAction.toTag);
      await tester.pumpAndSettle();
      await finishOnboarding(tester, container);

      expect(visited, isNot(contains(Routes.toTag)));
      expect(find.byType(ToTagScreen), findsNothing);
      expect(location(container), Routes.reels);
    });

    testApp('the start action waits for the flags, is held when not done, '
        'and opens after', (tester) async {
      final read = Completer<OnboardingFlags>();
      final harness = VmHarness(onboarding: () => _SlowOnboarding(read));
      final id = await makeReel(harness, 'Goa');
      harness.background
        ..startAction = LaunchAction.openReel
        ..startReelId = id;
      final container = await _start(tester, harness);
      await tester.pump();

      read.complete(_freshFlags);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      await finishOnboarding(tester, container);
      expect(location(container), Routes.reelReferences(id));
    });

    testApp('the held reel is deleted before done: Reels opens', (
      tester,
    ) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final repo = ReelsRepository(harness.media.db, harness.media.clock);
      final reel = await repo.create('Goa');
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();

      harness.background.emit(LaunchAction.openReel, reelId: reel.id);
      await tester.pumpAndSettle();
      await tester.runAsync(() => repo.delete(reel.id));
      await finishOnboarding(tester, container);

      expect(location(container), Routes.reels);
      expect(find.byType(ReelDetailScreen), findsNothing);
    });

    testApp('an openReel with no usable reel id is held, and opens Reels', (
      tester,
    ) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();

      harness.background.emit(LaunchAction.openReel);
      await tester.pumpAndSettle();
      await finishOnboarding(tester, container);

      expect(location(container), Routes.reels);
    });

    testApp('a kill forgets the held reel: nothing is stored', (tester) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final id = await makeReel(harness, 'Goa');
      final first = await _start(tester, harness);
      await tester.pumpAndSettle();
      harness.background.emit(LaunchAction.openReel, reelId: id);
      await tester.pumpAndSettle();

      // The process dies: a new container, the same database.
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      final second = await _start(tester, harness);
      await tester.pumpAndSettle();
      final visited = watch(second);
      await finishOnboarding(tester, second);

      expect(visited, isNot(contains(Routes.reelReferences(id))));
      expect(location(second), Routes.reels);
      expect(find.byType(ReelDetailScreen), findsNothing);
    });

    testApp('the app taken down while a reel is held: done later does '
        'nothing and nothing throws', (tester) async {
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final id = await makeReel(harness, 'Goa');
      final container = await _start(tester, harness);
      await tester.pumpAndSettle();
      harness.background.emit(LaunchAction.openReel, reelId: id);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(onboardingControllerProvider.notifier).finish();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });

  group('the real onboarding flags (D-135, D-136)', () {
    testApp('no rows in the database: the welcome', (tester) async {
      final harness = VmHarness(onboarding: OnboardingController.new);
      await _start(tester, harness);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(ReelsScreen), findsNothing);
    });

    testApp('an onboardingDone row: Reels', (tester) async {
      final harness = VmHarness(onboarding: OnboardingController.new);
      await tester.runAsync(harness.media.phoneState.markOnboardingDone);
      await _start(tester, harness);
      await tester.pumpAndSettle();

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testApp('a done row that is not true: the welcome', (tester) async {
      final harness = VmHarness(onboarding: OnboardingController.new);
      await tester.runAsync(harness.media.phoneState.markIntroPlayed);
      await _start(tester, harness);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  testApp('a gate that cannot be read leaves no held frame behind, and '
      'dispose meets no unassigned field', (tester) async {
    final harness = VmHarness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...harness.appOverrides,
          onboardingGateProvider.overrideWith((ref) => throw StateError('x')),
        ],
        child: const TakeTrayApp(),
      ),
    );
    expect(tester.takeException(), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
    expect(tester.binding.sendFramesToEngine, isTrue);
  });
}

/// A reels repository that counts how often a reel was looked up: each
/// `openReel` that is opened looks its reel up once (D-165).
class _CountingReels extends ReelsRepository {
  // The base class's fields are private, so super parameters cannot be named.
  // ignore: use_super_parameters
  _CountingReels(AppDatabase db, Clock clock) : super(db, clock);

  int lookups = 0;

  @override
  Future<Reel?> getById(int id) {
    lookups++;
    return super.getById(id);
  }
}
