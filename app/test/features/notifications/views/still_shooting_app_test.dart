import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

final DateTime _start = DateTime.utc(2026, 6, 1, 9);

const _title = 'Still shooting?';

/// The whole app, with Shooting mode on for [on] (default: 15 days).
Future<(VmHarness, ProviderContainer, DateTime)> _pumpApp(
  WidgetTester tester, {
  Duration on = const Duration(days: 15),
  ShadeActionKind? shade,
  LaunchAction? startedWith,
}) async {
  final harness = VmHarness(now: _start);
  final since = (await tester.runAsync(harness.media.turnOnNow))!.since!;
  harness.media.clock.advance(on);
  harness.background.startAction = startedWith;
  if (shade != null) {
    harness.background.shadeAction = ShadeAction(
      kind: shade,
      since: since,
      at: DateTime.utc(2026, 6, 10, 10),
      generations: const {},
    );
  }
  final container = ProviderContainer(overrides: harness.appOverrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TakeTrayApp()),
  );
  await _settle(tester);
  return (harness, container, since);
}

/// Not `pumpAndSettle` alone: with Shooting mode on, its card keeps moving.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await _settle(tester);
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(TtNavPill), matching: find.text(label)),
  );
  await _settle(tester);
}

void main() {
  testApp('dialog shows when due on Reels, at the start', (tester) async {
    await _pumpApp(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.widgetWithText(TtButton, 'Keep it on'), findsOneWidget);
  });

  testApp('not shown before 14 days', (tester) async {
    await _pumpApp(tester, on: const Duration(days: 13));

    expect(find.text(_title), findsNothing);
  });

  testApp('keep it on at the start tells the phone, once', (tester) async {
    final (harness, _, _) = await _pumpApp(tester);

    await tester.tap(find.widgetWithText(TtButton, 'Keep it on'));
    await _settle(tester);

    expect(find.text(_title), findsNothing);
    expect(harness.background.state!.stillAnswered, isTrue);
    await _resume(tester);
    expect(find.text(_title), findsNothing);
  });

  group('answered in the shade first', () {
    for (final kind in ShadeActionKind.values) {
      testApp('${kind.name} waiting at the start: no dialog', (tester) async {
        final (harness, _, _) = await _pumpApp(tester, shade: kind);

        expect(find.text(_title), findsNothing);
        await _resume(tester);
        expect(find.text(_title), findsNothing);
        // The app applied it meanwhile; the question never came.
        final state = await tester.runAsync(
          harness.media.phoneState.loadShooting,
        );
        expect(
          kind == ShadeActionKind.keepOn ? state!.stillAnswered : !state!.on,
          isTrue,
        );
      });
    }
  });

  group('only on Reels', () {
    testApp('not on To tag; shown when Reels comes back', (tester) async {
      final (harness, _, _) = await _pumpApp(
        tester,
        on: const Duration(days: 1),
      );
      await _tapTab(tester, 'To tag');
      harness.media.clock.advance(const Duration(days: 14));

      await _resume(tester);
      expect(find.text(_title), findsNothing);
      await _tapTab(tester, 'Settings');
      expect(find.text(_title), findsNothing);
      await _tapTab(tester, 'Reels');

      expect(find.text(_title), findsOneWidget);
    });

    testApp('a tap on the notification opens Reels and the dialog', (
      tester,
    ) async {
      final (harness, _, _) = await _pumpApp(
        tester,
        on: const Duration(days: 1),
      );
      await _tapTab(tester, 'Settings');
      harness.media.clock.advance(const Duration(days: 14));

      harness.background.emit(LaunchAction.reels);
      await _resume(tester);

      expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
      expect(find.text(_title), findsOneWidget);
    });

    testApp('not over the New reel sheet; shown when it closes', (
      tester,
    ) async {
      final (harness, _, _) = await _pumpApp(
        tester,
        on: const Duration(days: 1),
      );
      // What the New reel button does (it can sit behind the nav pill in a
      // short test window).
      unawaited(showReelForm(tester.element(find.byType(ReelsScreen))));
      await _settle(tester);
      expect(find.text('Reel name'), findsOneWidget);
      harness.media.clock.advance(const Duration(days: 14));

      await _resume(tester);
      expect(find.text(_title), findsNothing);
      await tester.tapAt(const Offset(4, 4));
      await _settle(tester);

      expect(find.text('Reel name'), findsNothing);
      expect(find.text(_title), findsOneWidget);
    });

    testApp("not over a popup in the Reels tab's own navigator", (
      tester,
    ) async {
      final (harness, _, _) = await _pumpApp(
        tester,
        on: const Duration(days: 1),
      );
      final context = tester.element(find.byType(ReelsScreen));
      unawaited(
        showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (_) => const AlertDialog(title: Text('Tab popup')),
        ),
      );
      await _settle(tester);
      harness.media.clock.advance(const Duration(days: 14));

      await _resume(tester);
      expect(find.text('Tab popup'), findsOneWidget);
      expect(find.text(_title), findsNothing);
      Navigator.of(context).pop();
      await _settle(tester);

      expect(find.text(_title), findsOneWidget);
    });

    testApp('never over the help screen', (tester) async {
      final (harness, container, _) = await _pumpApp(
        tester,
        on: const Duration(days: 1),
      );
      container.read(appRouterProvider).go(Routes.notificationsHelp);
      await _settle(tester);
      harness.media.clock.advance(const Duration(days: 14));

      await _resume(tester);

      expect(find.text('Notifications not arriving?'), findsWidgets);
      expect(find.text(_title), findsNothing);
    });
  });
}
