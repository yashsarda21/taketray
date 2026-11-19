import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The references Patrol flows cannot run here (no device), so the rules that
/// keep them safe are guarded in the source (D-161): no real link is ever
/// opened, the text is typed the way the 10A harness needs, and nothing is
/// tapped at a point.
void main() {
  final source = File('patrol_test/references_test.dart').readAsStringSync();

  /// The text of the function that starts with [signature], to its end.
  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0), reason: '$signature exists');
    return source.substring(start, source.indexOf('\n}\n', start));
  }

  test('every app that is pumped has the fake links bridge', () {
    final pumps = RegExp(r'pumpWidget\(').allMatches(source).toList();
    // The app, and the empty widget that closes it in the tear-down.
    expect(pumps, hasLength(2));
    final start = bodyOf('Future<void> _startApp(');
    expect(start, contains('linksBridgeProvider.overrideWithValue(env.links)'));
    expect(start, contains(r'restoreResumedLifecycle(env.$)'));
    expect(
      start.indexOf('restoreResumedLifecycle'),
      lessThan(start.indexOf('pumpWidget')),
      reason: 'the lifecycle state is restored before the app is pumped',
    );
    // The real bridge is never made here.
    expect(source, isNot(contains('PigeonLinksBridge')));
    expect(source, isNot(contains('LinksHostApi')));
  });

  test('the fake bridge is what _flowTest makes, one per flow', () {
    final flow = bodyOf('void _flowTest(');
    expect(flow, contains('final links = PatrolLinksBridge();'));
  });

  test('every enterText keeps the keyboard up (the 10A rule)', () {
    final calls = RegExp(r'enterText\(([^;]*)\)').allMatches(source).toList();
    expect(calls, isNotEmpty);
    for (final call in calls) {
      expect(call.group(1), contains('hideKeyboard: false'));
    }
  });

  test('nothing is tapped at a point, through adb or with Android Back', () {
    expect(source, isNot(contains('tapAt(')));
    expect(source, isNot(contains('adb')));
    expect(source, isNot(contains('pressBack')));
    expect(source, isNot(contains('PlatformAutomator')));
  });

  test('the tear-down empties the clipboard and turns Shooting mode off', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    expect(
      tearDown,
      contains("Clipboard.setData(const ClipboardData(text: ''))"),
    );
    expect(tearDown, contains('.setOn(false)'));
    // Each step runs even when one before it threw.
    expect(tearDown, contains('first ??= (error, stack)'));
  });
}
