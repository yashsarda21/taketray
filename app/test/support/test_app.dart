import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vm_harness.dart';

/// `testWidgets` for a test that runs the whole app, which watches the
/// database (the Shooting mode card and To tag).
///
/// When the body is done it takes the widget tree down and lets the event loop
/// turn once: closing a drift stream schedules a zero-delay timer, and the
/// test binding fails a test that ends with a timer pending.
///
/// The clean-up never hides the test's own failure: if the body threw, that
/// error is what the test reports, and a clean-up error is only printed. If
/// the body passed, a clean-up error fails the test.
///
/// [skip] is passed on to `testWidgets` (a golden that only the owner's Mac
/// makes, D-61).
void testApp(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  bool? skip,
}) {
  testWidgets(skip: skip, description, (tester) async {
    Object? bodyError;
    StackTrace? bodyStack;
    try {
      await body(tester);
    } on Object catch (error, stack) {
      bodyError = error;
      bodyStack = stack;
    }
    try {
      await tearDownApp(tester);
    } on Object catch (error, stack) {
      if (bodyError == null) rethrow;
      // ignore: avoid_print, test output only
      print('The clean-up of "$description" failed as well: $error\n$stack');
    }
    if (bodyError != null) {
      Error.throwWithStackTrace(bodyError, bodyStack!);
    }
  });
}

/// Takes the tree down and lets the timers it left run (see [testApp]).
///
/// The provider containers the tree used are disposed too. Riverpod disposes
/// an unused provider through the scope that held it, which is gone by then,
/// so a provider that owns a timer (the midnight tick, D-86) would otherwise
/// leave it pending.
Future<void> tearDownApp(WidgetTester tester) async {
  final containers = [
    for (final element in find.byType(UncontrolledProviderScope).evaluate())
      (element.widget as UncontrolledProviderScope).container,
  ];
  await tester.pumpWidget(const SizedBox.shrink());
  // Disposing twice is fine; a test that made its container disposes it too.
  for (final container in containers) {
    container.dispose();
  }
  // The timers run on the test clock, which only a pump moves.
  await tester.pump(Duration.zero);
  await tester.runAsync(settle);
  await tester.pump(Duration.zero);
}
