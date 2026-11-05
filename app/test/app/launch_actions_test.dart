import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/notifications/view_models/launch_actions.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/test_app.dart';
import '../support/vm_harness.dart';

/// The app on an in-memory database and fake bridges.
Future<VmHarness> _pumpApp(
  WidgetTester tester, {
  LaunchAction? startedWith,
}) async {
  final harness = VmHarness();
  harness.background.startAction = startedWith;
  await tester.pumpWidget(
    ProviderScope(overrides: harness.appOverrides, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

int _tab(WidgetTester tester) =>
    tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex;

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(TtNavPill), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the screen a tap asks for', () {
    test('toTag is To tag, reels is Reels', () {
      expect(routeFor(LaunchAction.toTag), Routes.toTag);
      expect(routeFor(LaunchAction.reels), Routes.reels);
    });

    test('every action has a route', () {
      for (final action in LaunchAction.values) {
        expect(routeFor(action), startsWith('/'), reason: action.name);
      }
    });
  });

  testApp('to tag action opens To tag', (tester) async {
    final harness = await _pumpApp(tester);
    expect(_tab(tester), 0);

    harness.background.emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
  });

  testApp('reels action opens Reels', (tester) async {
    final harness = await _pumpApp(tester);
    await _tapTab(tester, 'Settings');
    expect(_tab(tester), 2);

    harness.background.emit(LaunchAction.reels);
    await tester.pumpAndSettle();

    expect(_tab(tester), 0);
  });

  testApp('a tap goes to its screen from any tab, and back again', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    await _tapTab(tester, 'To tag');

    harness.background.emit(LaunchAction.reels);
    await tester.pumpAndSettle();
    harness.background.emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
  });

  testApp('action at start is handled once', (tester) async {
    final harness = await _pumpApp(tester, startedWith: LaunchAction.toTag);
    expect(_tab(tester), 1, reason: 'the app was started by a tap on To tag');
    expect(harness.background.launchListens, 1);

    await _tapTab(tester, 'Reels');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(_tab(tester), 0, reason: 'the start action is not applied again');
    expect(harness.background.launchListens, 1);
  });

  testApp('taps in a row end at the last one', (tester) async {
    final harness = await _pumpApp(tester);

    harness.background
      ..emit(LaunchAction.toTag)
      ..emit(LaunchAction.reels)
      ..emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
  });

  testApp("one listener for the app's whole life", (tester) async {
    final harness = await _pumpApp(tester);

    await _tapTab(tester, 'To tag');
    await _tapTab(tester, 'Settings');
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(null);
    await tester.pumpAndSettle();

    expect(harness.background.launchListens, 1);
    expect(harness.background.launchCancels, 0);
  });

  testApp('stops listening when the app is taken down', (tester) async {
    final harness = await _pumpApp(tester);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(harness.background.launchCancels, 1);
    harness.background.emit(LaunchAction.toTag);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testApp('an error on the stream is logged by type and the next tap works', (
    tester,
  ) async {
    final records = captureLogs();
    final harness = await _pumpApp(tester);

    harness.background.emitError(StateError('/storage/emulated/0/secret'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    harness.background.emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
    expect(logText(records), contains('StateError'));
    expect(logText(records), isNot(contains('secret')));
  });
}
