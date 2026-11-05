import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/router/popup_route_tracker.dart';

Future<(PopupRouteTracker, NavigatorState)> _pump(WidgetTester tester) async {
  final tracker = PopupRouteTracker();
  addTearDown(tracker.dispose);
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: key,
      navigatorObservers: [tracker.observerForNavigator()],
      home: const Scaffold(body: Text('home')),
    ),
  );
  return (tracker, key.currentState!);
}

void main() {
  testWidgets('nothing is open at first', (tester) async {
    final (tracker, _) = await _pump(tester);

    expect(tracker.isOpen, isFalse);
  });

  testWidgets('a page is not a popup', (tester) async {
    final (tracker, navigator) = await _pump(tester);

    navigator.push<void>(MaterialPageRoute(builder: (_) => const Text('page')));
    await tester.pumpAndSettle();

    expect(tracker.isOpen, isFalse);
  });

  testWidgets('a dialog is open until it pops, and listeners hear both', (
    tester,
  ) async {
    final (tracker, navigator) = await _pump(tester);
    final heard = <bool>[];
    tracker.addListener(() => heard.add(tracker.isOpen));

    unawaited(
      showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(title: Text('d')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isTrue);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(tracker.isOpen, isFalse);
    expect(heard, [true, false]);
  });

  testWidgets('a bottom sheet counts, and two popups need both closed', (
    tester,
  ) async {
    final (tracker, navigator) = await _pump(tester);

    unawaited(
      showModalBottomSheet<void>(
        context: navigator.context,
        builder: (_) => const Text('sheet'),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(title: Text('d')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isTrue);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isTrue, reason: 'the sheet is still there');

    navigator.pop();
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isFalse);
  });

  testWidgets('a popup that is removed or replaced stops counting', (
    tester,
  ) async {
    final (tracker, navigator) = await _pump(tester);
    final route = DialogRoute<void>(
      context: navigator.context,
      builder: (_) => const AlertDialog(title: Text('d')),
    );
    navigator.push(route);
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isTrue);

    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isFalse);

    final second = DialogRoute<void>(
      context: navigator.context,
      builder: (_) => const AlertDialog(title: Text('e')),
    );
    navigator.push(second);
    await tester.pumpAndSettle();
    navigator.replace<void>(
      oldRoute: second,
      newRoute: MaterialPageRoute(builder: (_) => const Text('page')),
    );
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isFalse);
  });

  testWidgets('one tracker serves several navigators', (tester) async {
    final tracker = PopupRouteTracker();
    addTearDown(tracker.dispose);
    final outer = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: outer,
        navigatorObservers: [tracker.observerForNavigator()],
        home: Navigator(
          key: inner,
          observers: [tracker.observerForNavigator()],
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const Text('inner')),
        ),
      ),
    );

    unawaited(
      showDialog<void>(
        context: inner.currentContext!,
        useRootNavigator: false,
        builder: (_) => const AlertDialog(title: Text('d')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tracker.isOpen, isTrue);
    inner.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tracker.isOpen, isFalse);
  });

  test('the provider gives one tracker for the app', () {
    final container = ProviderContainer.test();

    expect(
      container.read(popupRouteTrackerProvider),
      same(container.read(popupRouteTrackerProvider)),
    );
  });
}
