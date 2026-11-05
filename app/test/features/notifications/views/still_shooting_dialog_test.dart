import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/notifications/views/still_shooting_dialog.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';

final DateTime _start = DateTime.utc(2026, 6, 1, 9);

const _title = 'Still shooting?';
const _body =
    "Shooting mode has been on for 14 days. While it's on, every new video "
    'goes to To tag.';

void main() {
  late VmHarness h;
  late DateTime since;

  /// Real work (the database, the fake bridges) runs between redraws.
  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleApp(tester);
  }

  /// The host alone on a screen, on [h]'s database. Shooting mode went on
  /// [on] ago.
  Future<ProviderContainer> pumpHost(
    WidgetTester tester, {
    Duration on = const Duration(days: 15),
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    since = (await tester.runAsync(h.media.turnOnNow))!.since!;
    h.media.clock.advance(on);
    final container = await pumpScreen(
      tester,
      const Scaffold(body: StillShootingPromptHost()),
      overrides: [...h.overrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    return container;
  }

  setUp(() {
    h = VmHarness(now: _start);
  });

  Future<ShootingState> stored(WidgetTester tester) =>
      tester.runAsync(h.media.phoneState.loadShooting).then((s) => s!);

  group('the dialog', () {
    testApp('dialog shows when due on Reels', (tester) async {
      await pumpHost(tester);

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_body), findsOneWidget);
      expect(find.widgetWithText(TtButton, 'Keep it on'), findsOneWidget);
      expect(find.widgetWithText(TtButton, 'Turn off'), findsOneWidget);
      expect(find.byType(TtDialog<bool>), findsOneWidget);
      expect(
        tester.widget<TtDialog<bool>>(find.byType(TtDialog<bool>)).icon,
        Symbols.videocam_rounded,
      );
    });

    testApp('not shown before 14 days', (tester) async {
      await pumpHost(tester, on: const Duration(days: 14, minutes: -1));

      expect(find.text(_title), findsNothing);
    });

    testApp('shown at exactly 14 days', (tester) async {
      await pumpHost(tester, on: const Duration(days: 14));

      expect(find.text(_title), findsOneWidget);
    });

    testApp('not shown with Shooting mode off', (tester) async {
      h.media.clock.advance(const Duration(days: 20));
      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
    });

    testApp('not shown once answered in this session', (tester) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      await tester.runAsync(() => h.media.phoneState.markStillAnswered(since));
      h.media.clock.advance(const Duration(days: 20));
      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
    });

    testApp('dialog shows once per session', (tester) async {
      // A switch that does nothing, so the session stays due after the answer.
      final fake = FakeShooting(
        ShootingState(on: true, baselines: const {}, since: _start),
      );
      await pumpHost(
        tester,
        overrides: [shootingModeControllerProvider.overrideWith(() => fake)],
      );
      expect(find.text(_title), findsOneWidget);

      await tester.tap(find.widgetWithText(TtButton, 'Turn off'));
      await settleApp(tester);
      expect(find.text(_title), findsNothing);
      expect(fake.switched, [false]);

      await resume(tester);
      await resume(tester);

      expect(find.text(_title), findsNothing, reason: 'asked once already');
    });

    testApp('a resume while it is open does not open a second', (tester) async {
      await pumpHost(tester);

      await resume(tester);

      expect(find.text(_title), findsOneWidget);
    });

    testApp('shown on a resume after it became due', (tester) async {
      await pumpHost(tester, on: const Duration(days: 13));
      expect(find.text(_title), findsNothing);

      h.media.clock.advance(const Duration(days: 2));
      await resume(tester);

      expect(find.text(_title), findsOneWidget);
    });
  });

  group('the answers', () {
    testApp('keep it on marks answered', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Keep it on'));
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
      final state = await stored(tester);
      expect(state.stillAnswered, isTrue);
      expect(state.on, isTrue);
      expect(find.text('Shooting mode off'), findsNothing);
    });

    testApp('back counts as keep it on', (tester) async {
      await pumpHost(tester);

      await tester.binding.handlePopRoute();
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
      expect((await stored(tester)).stillAnswered, isTrue);
      expect((await stored(tester)).on, isTrue);
    });

    testApp('a tap outside counts as keep it on', (tester) async {
      await pumpHost(tester);

      await tester.tapAt(const Offset(4, 4));
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
      expect((await stored(tester)).stillAnswered, isTrue);
    });

    testApp('turn off turns off and shows the snack', (tester) async {
      await pumpHost(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Turn off'));
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
      expect((await stored(tester)).on, isFalse);
      expect(find.text('Shooting mode off'), findsOneWidget);
      expect(find.byType(TtSnack), findsOneWidget);
    });

    testApp('answered in the app: the phone is told, so the shade clears', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      container.read(backgroundSyncProvider).start();
      await settleApp(tester);
      expect(h.background.state!.stillAnswered, isFalse);

      await tester.tap(find.widgetWithText(TtButton, 'Keep it on'));
      await settleApp(tester);

      expect(h.background.state!.stillAnswered, isTrue);
      expect(h.background.state!.shootingOn, isTrue);
    });

    testApp('turned off in the app: the phone is told it is off', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      container.read(backgroundSyncProvider).start();
      await settleApp(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Turn off'));
      await settleApp(tester);

      expect(h.background.state!.shootingOn, isFalse);
    });
  });

  group('answered in the shade first', () {
    ShadeAction shade(ShadeActionKind kind) => ShadeAction(
      kind: kind,
      since: since,
      at: DateTime.utc(2026, 6, 10, 10),
      generations: const {},
    );

    for (final kind in ShadeActionKind.values) {
      testApp('a waiting ${kind.name} from the shade: no dialog', (
        tester,
      ) async {
        since = (await tester.runAsync(h.media.turnOnNow))!.since!;
        h.media.clock.advance(const Duration(days: 15));
        h.background.shadeAction = shade(kind);

        await pumpScreen(
          tester,
          const Scaffold(body: StillShootingPromptHost()),
          overrides: h.overrides,
          settle: false,
        );
        await settleApp(tester);

        expect(find.text(_title), findsNothing);
      });
    }

    testApp('the shade action applied before we look: no dialog', (
      tester,
    ) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      h.media.clock.advance(const Duration(days: 15));
      // Keep on applied: the session is answered, the action is gone.
      await tester.runAsync(() => h.media.phoneState.markStillAnswered(since));

      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
    });

    testApp('a Turn off applied before we look: no dialog', (tester) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      h.media.clock.advance(const Duration(days: 15));
      await tester.runAsync(h.media.phoneState.turnShootingOff);

      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await settleApp(tester);

      expect(find.text(_title), findsNothing);
    });

    testApp('a shade action of an older session does not hide the dialog', (
      tester,
    ) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      h.media.clock.advance(const Duration(days: 15));
      h.background.shadeAction = ShadeAction(
        kind: ShadeActionKind.turnOff,
        since: _start.subtract(const Duration(days: 40)),
        at: DateTime.utc(2026, 6, 10, 10),
        generations: const {},
      );

      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await settleApp(tester);

      expect(find.text(_title), findsOneWidget);
    });

    testApp('an action that cannot be read: no dialog now, one next time', (
      tester,
    ) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      h.media.clock.advance(const Duration(days: 15));
      h.background.failNext('pendingShadeAction');

      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await settleApp(tester);
      expect(find.text(_title), findsNothing);

      await resume(tester);

      expect(find.text(_title), findsOneWidget);
    });
  });

  group('only on Reels', () {
    BuildContext hostContext(WidgetTester tester) =>
        tester.element(find.byType(StillShootingPromptHost));

    testApp('never shows over another route, then shows when it returns', (
      tester,
    ) async {
      await pumpHost(tester, on: const Duration(days: 1));
      expect(find.text(_title), findsNothing);

      unawaited(GoRouter.of(hostContext(tester)).push<void>(Routes.tagPlayer));
      await settleApp(tester);
      expect(find.text(tagPlayerRouteMarker(null)), findsOneWidget);
      h.media.clock.advance(const Duration(days: 14));
      await resume(tester);
      expect(find.text(_title), findsNothing, reason: 'the player is open');

      GoRouter.of(tester.element(find.text(tagPlayerRouteMarker(null)))).pop();
      await settleApp(tester);

      expect(find.text(_title), findsOneWidget);
    });

    testApp('a check that is still reading when a route opens shows nothing', (
      tester,
    ) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      h.media.clock.advance(const Duration(days: 15));
      final gate = h.background.gate('pendingShadeAction');
      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      await tester.runAsync(settle);
      await tester.pump();

      unawaited(GoRouter.of(hostContext(tester)).push<void>(Routes.tagPlayer));
      await tester.pumpAndSettle();
      gate.complete();
      await settleApp(tester);
      expect(find.text(_title), findsNothing);

      GoRouter.of(tester.element(find.text(tagPlayerRouteMarker(null)))).pop();
      await settleApp(tester);

      expect(find.text(_title), findsOneWidget);
    });

    testApp('two checks at once open one dialog', (tester) async {
      since = (await tester.runAsync(h.media.turnOnNow))!.since!;
      h.media.clock.advance(const Duration(days: 15));
      await pumpScreen(
        tester,
        const Scaffold(body: StillShootingPromptHost()),
        overrides: h.overrides,
        settle: false,
      );
      // The first frame's check and a resume's, at the same moment.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(find.text(_title), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (scale, brightness) in [
      (1.0, Brightness.light),
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
    ]) {
      testApp('accessible at ${scale}x, ${brightness.name}', (tester) async {
        await pumpHost(tester, textScale: scale, brightness: brightness);

        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testApp('dialog 2x no overflow: both buttons readable', (tester) async {
      await pumpHost(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Keep it on'), findsOneWidget);
      expect(find.text('Turn off'), findsOneWidget);
    });
  });
}
