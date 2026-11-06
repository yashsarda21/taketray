import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Since Task 7 the first time Shooting mode is turned on, the app asks for
/// the notification permission (D-107). A Patrol flow that only taps the
/// switch then waits for a stored "on" behind the system dialog and times out
/// (seen on the S24, 2026-11-06: `media_scan_test` and `tagging_test`). Every
/// helper that turns Shooting mode on answers the dialog. The phone cannot
/// run here, so this guards the source.
void main() {
  for (final file in [
    'patrol_test/media_scan_test.dart',
    'patrol_test/tagging_test.dart',
  ]) {
    test('$file: turning Shooting mode on answers the notification dialog', () {
      final source = File(file).readAsStringSync();
      final start = source.indexOf('Future<void> _setShootingMode(');
      expect(start, greaterThanOrEqualTo(0), reason: 'the helper exists');
      final end = source.indexOf('\n}\n', start);
      final body = source.substring(start, end);

      final tap = body.indexOf(r'$(ReelsScreen).$(TtSwitch).tap()');
      final answer = body.indexOf(r'allowNotificationsInDialog($)');
      expect(tap, greaterThanOrEqualTo(0));
      expect(answer, greaterThan(tap), reason: 'answered after the tap');
      // Only when turning on: switching off never asks.
      final guard = body.substring(tap, answer);
      expect(guard, contains('if (on)'));
      // Before the wait for the stored state.
      expect(answer, lessThan(body.indexOf('stored() == on')));
    });
  }
}
