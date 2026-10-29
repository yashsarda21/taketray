import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Pumps frames (in real time: Patrol's binding is live) until [done] is true,
/// and fails with [what] when [timeout] passes first.
///
/// Used instead of `pumpAndSettle`, which never settles while the Shooting
/// mode card's record dot pulses or a skeleton shimmers.
Future<void> waitFor(
  PatrolIntegrationTester $,
  bool Function() done, {
  required String what,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what',
      );
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}

/// Pumps frames for [duration]: a pause that still draws the app.
Future<void> pumpFor(PatrolIntegrationTester $, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}
