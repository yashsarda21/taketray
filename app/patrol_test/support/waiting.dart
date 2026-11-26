import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Pumps frames (in real time: Patrol's binding is live) until [done] is true,
/// and fails with [what] when [timeout] passes first.
///
/// [done] may look at the screen (a sync check) or ask the database or a
/// channel (an async one); it is asked before the first frame and again after
/// each one.
///
/// Used instead of `pumpAndSettle`, which never settles while the Shooting
/// mode card's record dot pulses or a skeleton shimmers.
Future<void> waitFor(
  PatrolIntegrationTester $,
  FutureOr<bool> Function() done, {
  required String what,
  Duration timeout = const Duration(seconds: 45),
}) => pollUntil(
  pump: () => $.tester.pump(const Duration(milliseconds: 250)),
  done: done,
  what: what,
  timeout: timeout,
);

/// Pumps frames until what [read] gives is the same on two frames in a row:
/// an animation (the dock shrinking, the rail coming back) that has stopped.
/// Fails with [what] when [timeout] passes first.
///
/// A frame is 50 ms here, so a layout that has not started to move yet is not
/// taken for still for long: it has to rest for a whole frame, and every
/// animation of the player is 150 ms or more.
Future<void> waitForStill(
  PatrolIntegrationTester $,
  List<Object?> Function() read, {
  required String what,
  Duration timeout = const Duration(seconds: 10),
}) => untilStill(
  pump: () => $.tester.pump(const Duration(milliseconds: 50)),
  read: read,
  what: what,
  timeout: timeout,
);

/// [waitFor] with the frame and the clock given: the loop, which a test can
/// run with no phone (`waiting_test.dart`).
Future<void> pollUntil({
  required Future<void> Function() pump,
  required FutureOr<bool> Function() done,
  required String what,
  Duration timeout = const Duration(seconds: 45),
  DateTime Function() clock = DateTime.now,
}) async {
  final deadline = clock().add(timeout);
  while (!await done()) {
    if (clock().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what',
      );
    }
    await pump();
  }
}

/// [waitForStill] with the frame and the clock given.
Future<void> untilStill({
  required Future<void> Function() pump,
  required List<Object?> Function() read,
  required String what,
  Duration timeout = const Duration(seconds: 10),
  DateTime Function() clock = DateTime.now,
}) async {
  final deadline = clock().add(timeout);
  await pump();
  var last = read();
  while (true) {
    await pump();
    final now = read();
    if (listEquals(now, last)) return;
    last = now;
    if (clock().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what',
      );
    }
  }
}

/// Pumps frames for [duration]: a pause that still draws the app.
Future<void> pumpFor(PatrolIntegrationTester $, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}
