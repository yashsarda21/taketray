import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vm_harness.dart';

/// `testWidgets` for a test that runs the whole app, which watches the
/// database (the Shooting mode card and To tag).
///
/// When the body is done it takes the widget tree down and lets the event loop
/// turn once: closing a drift stream schedules a zero-delay timer, and the
/// test binding fails a test that ends with a timer pending.
void testApp(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      // The timers run on the test clock, which only a pump moves.
      await tester.pump(Duration.zero);
      await tester.runAsync(settle);
      await tester.pump(Duration.zero);
    }
  });
}
