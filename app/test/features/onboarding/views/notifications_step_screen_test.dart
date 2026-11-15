import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/onboarding/views/notifications_step_screen.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';

/// Onboarding's notifications step (Task 7, D-140): the notification card,
/// Allow notifications (asks once, then goes on whatever the answer) and Not
/// now.

const _homeMarker = 'the screen before';
const _reelsMarker = 'the reels step';
const _title = 'Know when clips are waiting';

NotificationAccess _na({required int sdk, required bool granted}) =>
    NotificationAccess(granted: granted, canAsk: !granted, sdkInt: sdk);

/// A [NotificationAccessController] that shows [access], counts [askOnce],
/// can hold it open on [gate] and answer it with [afterAsk].
class _Notif extends NotificationAccessController {
  _Notif(this.access, {this.loading = false});

  /// The first view; null is a first read that failed.
  final NotificationAccess? access;
  final bool loading;
  int asked = 0;
  Completer<void>? gate;
  NotificationAccess? afterAsk;
  Error? askThrows;

  @override
  Future<NotificationAccess> build() {
    if (loading) return Completer<NotificationAccess>().future;
    final a = access;
    if (a == null) return Future.error(StateError('the first read failed'));
    return Future.value(a);
  }

  @override
  Future<void> askOnce() async {
    asked++;
    await gate?.future;
    final error = askThrows;
    if (error != null) throw error;
    final next = afterAsk;
    if (next != null) state = AsyncData(next);
  }

  void show(NotificationAccess a) => state = AsyncData(a);
}

late GoRouter _router;

/// The step, pushed on a home screen, so Back and a replace can be told apart.
Future<void> _pump(
  WidgetTester tester,
  _Notif notif, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text(_homeMarker)),
      ),
      GoRoute(
        path: Routes.onboardingNotifications,
        builder: (context, state) => const NotificationsStepScreen(),
      ),
      GoRoute(
        path: Routes.onboardingReels,
        builder: (context, state) => const Scaffold(body: Text(_reelsMarker)),
      ),
    ],
  );
  addTearDown(_router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationAccessControllerProvider.overrideWith(() => notif),
      ],
      child: MaterialApp.router(
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(_router.push(Routes.onboardingNotifications));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Finder _button(String label) => find.widgetWithText(TtButton, label);

String _location() => _router.state.uri.toString();

void main() {
  group('the step', () {
    testWidgets('title, body, the card and its two buttons', (tester) async {
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)));
      expect(tester.takeException(), isNull);
      expect(find.text(_title), findsOneWidget);
      expect(
        find.text(
          'One quiet notification when new clips are waiting, and a reminder '
          "at 9 pm if you haven't tagged them. No sound.",
        ),
        findsOneWidget,
      );
      expect(find.text('TakeTray · now'), findsOneWidget);
      expect(find.text('5 new clips to tag'), findsOneWidget);
      expect(find.text('Tap to tag them into your reels.'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(_button('Allow notifications'), findsOneWidget);
      expect(_button('Not now'), findsOneWidget);
      expect(
        tester.widget<TtButton>(_button('Allow notifications')).kind,
        TtButtonKind.filled,
      );
      expect(
        tester.widget<TtButton>(_button('Not now')).kind,
        TtButtonKind.text,
      );
    });

    testWidgets('dots show step 3 of 4 and the title is a heading', (
      tester,
    ) async {
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)));
      final dots = tester.widget<StepDots>(find.byType(StepDots));
      expect(dots.index, 2);
      expect(dots.count, 4);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Step 3 of 4'), findsOneWidget);
      expect(
        tester.getSemantics(find.text(_title)).flagsCollection.isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('the card uses the four take pictures, the +1 tile and '
        'a 268 dp width, on the 260 dp art', (tester) async {
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)));
      final art = find.byKey(NotificationsStepScreen.artKey);
      expect(tester.getSize(art).height, 260);
      expect(tester.getSize(art).width, 360);
      expect(
        tester.widget<ColoredBox>(art).color,
        Theme.of(tester.element(find.byType(StepDots)))
            .colorScheme
            .surfaceContainer,
      );
      final card = find.byKey(NotificationsStepScreen.cardKey);
      expect(tester.getSize(card).width, 268);
      expect(tester.getCenter(card).dx, 180);
      final images = tester
          .widgetList<Image>(
            find.descendant(of: card, matching: find.byType(Image)),
          )
          .map((i) => (i.image as AssetImage).assetName)
          .toList();
      expect(images, [
        'assets/welcome/take_london_food.png',
        'assets/welcome/take_cinematic.png',
        'assets/welcome/take_day1_vlog.png',
        'assets/welcome/take_extra.png',
      ]);
      // Four pictures and the "+1" tile fit the card, 4 dp apart, 64 dp tall.
      final rects = [
        for (var i = 0; i < 5; i++)
          tester.getRect(find.byKey(NotificationsStepScreen.thumbKey(i))),
      ];
      for (final r in rects) {
        expect(r.height, 64);
        expect(r.width, closeTo(44, 0.01));
      }
      for (var i = 1; i < 5; i++) {
        expect(rects[i].left - rects[i - 1].right, closeTo(4, 0.01));
      }
      expect(
        rects.last.right,
        lessThanOrEqualTo(tester.getRect(card).right - 16 + 0.01),
      );
    });

    testWidgets('the card is picture only for a screen reader: its text is '
        'not read', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)));
      expect(find.bySemanticsLabel('5 new clips to tag'), findsNothing);
      expect(find.bySemanticsLabel('TakeTray · now'), findsNothing);
      expect(find.bySemanticsLabel('+1'), findsNothing);
      handle.dispose();
    });

    testWidgets('buttons are large and across the foot; 48 dp targets', (
      tester,
    ) async {
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)));
      final allow = tester.getRect(_button('Allow notifications'));
      expect(allow.left, 24);
      expect(allow.right, 336);
      expect(allow.height, 56);
      expect(
        tester.widget<TtButton>(_button('Allow notifications')).size,
        TtButtonSize.large,
      );
      await expectTtAccessible(tester);
    });

    testWidgets('at 2x text the buttons stay at the bottom', (tester) async {
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_button('Not now')).bottom, lessThanOrEqualTo(800));
      expect(tester.getRect(_button('Not now')).bottom, greaterThan(760));
      await tester.tap(_button('Not now'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });
  });

  group('Allow notifications', () {
    testWidgets('asks once, then pushes the reels step', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false));
      await _pump(tester, notif);
      await tester.tap(_button('Allow notifications'));
      await tester.pumpAndSettle();
      expect(notif.asked, 1);
      expect(_location(), Routes.onboardingReels);
      expect(find.text(_reelsMarker), findsOneWidget);
    });

    testWidgets('Back from the reels step returns to this step', (
      tester,
    ) async {
      await _pump(tester, _Notif(_na(sdk: 34, granted: false)));
      await tester.tap(_button('Allow notifications'));
      await tester.pumpAndSettle();
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
    });

    testWidgets('goes on whatever the answer: refused', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false))
        ..afterAsk = const NotificationAccess(
          granted: false,
          canAsk: false,
          sdkInt: 34,
        );
      await _pump(tester, notif);
      await tester.tap(_button('Allow notifications'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });

    testWidgets('goes on once, when the answer is "allowed" (the step does '
        'not skip itself a second time)', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false))
        ..afterAsk = _na(sdk: 34, granted: true);
      await _pump(tester, notif);
      await tester.tap(_button('Allow notifications'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
      _router.pop();
      await tester.pumpAndSettle();
      // Back is the step, then the screen before: exactly one reels route
      // was pushed.
      expect(find.text(_title), findsOneWidget);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_homeMarker), findsOneWidget);
    });

    testWidgets('goes on when asking throws', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false))
        ..askThrows = StateError('boom');
      await _pump(tester, notif);
      await tester.tap(_button('Allow notifications'));
      await tester.pumpAndSettle();
      expect(notif.asked, 1);
      expect(_location(), Routes.onboardingReels);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two taps at once ask once and push once', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false))
        ..gate = Completer<void>();
      await _pump(tester, notif);
      final press = tester
          .widget<TtButton>(_button('Allow notifications'))
          .onPressed!;
      press();
      press();
      expect(notif.asked, 1);
      notif.gate!.complete();
      await tester.pumpAndSettle();
      expect(notif.asked, 1);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_homeMarker), findsOneWidget);
    });

    testWidgets('while it runs both buttons are disabled; Not now does '
        'nothing', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false))
        ..gate = Completer<void>();
      await _pump(tester, notif);
      await tester.tap(_button('Allow notifications'));
      await tester.pump();
      expect(
        tester.widget<TtButton>(_button('Allow notifications')).onPressed,
        isNull,
      );
      expect(tester.widget<TtButton>(_button('Not now')).onPressed, isNull);
      await tester.tap(_button('Not now'), warnIfMissed: false);
      await tester.pump();
      expect(_location(), Routes.onboardingNotifications);
      notif.gate!.complete();
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });

    testWidgets('leaving while the dialog is up: nothing is pushed or broken '
        'when it answers', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false))
        ..gate = Completer<void>();
      await _pump(tester, notif);
      await tester.tap(_button('Allow notifications'));
      await tester.pump();
      _router.pop();
      await tester.pumpAndSettle();
      notif.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(_homeMarker), findsOneWidget);
      expect(find.text(_reelsMarker), findsNothing);
    });
  });

  group('Not now', () {
    testWidgets('pushes the reels step and never asks', (tester) async {
      final notif = _Notif(_na(sdk: 34, granted: false));
      await _pump(tester, notif);
      await tester.tap(_button('Not now'));
      await tester.pumpAndSettle();
      expect(notif.asked, 0);
      expect(_location(), Routes.onboardingReels);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
    });
  });

  group('opened when there is nothing to ask', () {
    for (final (name, access) in [
      ('Android 12', _na(sdk: 32, granted: false)),
      ('Android 11', _na(sdk: 30, granted: false)),
      ('already allowed', _na(sdk: 34, granted: true)),
      ('Android 12, allowed', _na(sdk: 32, granted: true)),
    ]) {
      testWidgets('$name: replaces itself with the reels step', (tester) async {
        final notif = _Notif(access);
        await _pump(tester, notif);
        expect(_location(), Routes.onboardingReels);
        expect(find.text(_reelsMarker), findsOneWidget);
        expect(find.text(_title), findsNothing);
        expect(notif.asked, 0);
        // Replaced, not stacked: Back goes to the screen before the step.
        _router.pop();
        await tester.pumpAndSettle();
        expect(find.text(_homeMarker), findsOneWidget);
      });
    }

    testWidgets('does not show itself for a frame first', (tester) async {
      await _pump(tester, _Notif(_na(sdk: 32, granted: false)), settle: false);
      expect(find.text(_title), findsNothing);
      expect(find.byType(TtButton), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(_reelsMarker), findsOneWidget);
    });

    testWidgets('while the read is running it shows nothing and does not '
        'move', (tester) async {
      await _pump(tester, _Notif(null, loading: true));
      expect(find.text(_title), findsNothing);
      expect(find.byType(TtButton), findsNothing);
      expect(_location(), Routes.onboardingNotifications);
    });

    testWidgets('when the read failed it shows the step', (tester) async {
      await _pump(tester, _Notif(null));
      expect(find.text(_title), findsOneWidget);
      expect(_button('Allow notifications'), findsOneWidget);
    });

    testWidgets('a permission that changes later does not move the step', (
      tester,
    ) async {
      final notif = _Notif(_na(sdk: 34, granted: false));
      await _pump(tester, notif);
      notif.show(_na(sdk: 34, granted: true));
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
      expect(_location(), Routes.onboardingNotifications);
    });
  });
}
