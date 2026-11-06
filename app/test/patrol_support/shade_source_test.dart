import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `closeShade` once pressed Back (Patrol's `closeNotifications` is
/// `UiDevice.pressBack`). With the shade already closed and the app on its
/// root screen, Back finishes `MainActivity`; the Flutter engine goes and the
/// running Patrol test dies with an `EOFException` (seen on the S24,
/// 2026-11-06, flows 2 and 5). The shade is closed with Home instead, which
/// leaves the app alive whether the shade is open or not. The channel to the
/// phone cannot run here, so this guards the source.
void main() {
  final shade = File('patrol_test/support/shade.dart').readAsStringSync();
  final flows = File('patrol_test/background_test.dart').readAsStringSync();

  test('no helper closes the shade with Back', () {
    expect(shade, isNot(contains('closeNotifications')));
    expect(flows, isNot(contains('closeNotifications')));
    expect(shade, isNot(contains('pressBack')));
    expect(flows, isNot(contains('pressBack')));
  });

  test('closeShade presses Home', () {
    final start = shade.indexOf('Future<void> closeShade');
    expect(start, greaterThanOrEqualTo(0));
    final body = shade.substring(start, shade.indexOf('\n}\n', start));
    expect(body, contains('pressHome'));
  });

  test(
    'the shade is never tapped at a point or expanded; Turn off is a hook',
    () {
      for (final source in [shade, flows]) {
        expect(source, isNot(contains('tapAt(')));
        expect(source, isNot(contains('tapOwnButton')));
        expect(source, isNot(contains('swipe')));
      }
      expect(flows, contains('pressStillTurnOff()'));
    },
  );
}
