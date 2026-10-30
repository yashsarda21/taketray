import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/guarded.dart';

import '../data/media/media_harness.dart';

void main() {
  final log = Logger('guardedTest');

  test('returns the job result', () async {
    expect(await guarded(log, 'step', () async => 7), 7);
  });

  test('an exception gives null and logs only its type', () async {
    final records = captureLogs();

    final result = await guarded<int>(
      log,
      'step',
      () async => throw const FormatException('/storage/emulated/0/secret.mp4'),
    );

    expect(result, isNull);
    final text = logText(records);
    expect(text, contains('step failed: FormatException'));
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('/storage')));
  });

  test('an Error is caught too', () async {
    expect(
      await guarded<int>(log, 'step', () async => throw StateError('x')),
      isNull,
    );
  });

  test('a job that throws before its first await is caught', () async {
    expect(
      await guarded<int>(log, 'step', () => throw ArgumentError('x')),
      isNull,
    );
  });

  test('noRetry never retries', () {
    expect(noRetry(0, StateError('x')), isNull);
    expect(noRetry(5, StateError('x')), isNull);
  });
}
