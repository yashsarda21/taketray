import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/waiting.dart';

/// The waiting helpers the Patrol flows use, run here with no phone: a fake
/// frame and a fake clock stand in for Patrol's `$.tester.pump` and real time.
void main() {
  late DateTime now;
  late int frames;

  setUp(() {
    now = DateTime(2026);
    frames = 0;
  });

  /// A frame: the clock moves 50 ms.
  Future<void> frame() async {
    frames++;
    now = now.add(const Duration(milliseconds: 50));
  }

  group('pollUntil', () {
    Future<void> poll(
      Future<bool> Function() done, {
      Duration timeout = const Duration(seconds: 1),
    }) => pollUntil(
      pump: frame,
      done: done,
      what: 'the clip to be in Patrol B',
      timeout: timeout,
      clock: () => now,
    );

    test('returns at once, with no frame, when it is already true', () async {
      await poll(() async => true);
      expect(frames, 0);
    });

    test('waits, a frame at a time, for an async condition', () async {
      var asked = 0;
      await poll(() async => ++asked == 4);
      expect(frames, 3);
    });

    test('a synchronous condition works as well', () async {
      var asked = 0;
      await pollUntil(
        pump: frame,
        done: () => ++asked == 3,
        what: 'x',
        clock: () => now,
      );
      expect(frames, 2);
    });

    test('fails, naming what it waited for, when the time is up', () async {
      Object? failure;
      try {
        await poll(() async => false);
      } on TestFailure catch (e) {
        failure = e;
      }
      expect(failure, isA<TestFailure>());
      expect(
        '$failure',
        contains('Timed out after 1 s waiting for: the clip to be in Patrol B'),
      );
      // 50 ms a frame, a second: about twenty frames, and not more.
      expect(frames, inInclusiveRange(19, 22));
    });

    test('an error from the condition is not swallowed', () async {
      await expectLater(
        poll(() async => throw const FormatException('the database failed')),
        throwsA(isA<FormatException>()),
      );
      expect(frames, 0);
    });
  });

  group('untilStill', () {
    Future<void> still(
      List<Object?> Function() read, {
      Duration timeout = const Duration(seconds: 1),
    }) => untilStill(
      pump: frame,
      read: read,
      what: 'the rail to stop',
      timeout: timeout,
      clock: () => now,
    );

    test('returns on the second frame when nothing moves', () async {
      await still(() => [const Rect.fromLTWH(1, 2, 3, 4)]);
      // One frame to read it, one to see it has not changed.
      expect(frames, 2);
    });

    test('waits while the readings change, and returns on the first two '
        'frames in a row that are the same', () async {
      final readings = <List<Object?>>[
        [100.0],
        [90.0],
        [80.0],
        [80.0],
        [70.0],
      ];
      var at = 0;
      await still(() => readings[at++]);
      // Frames 1 to 3 moved, frame 4 is the same as frame 3: done there.
      expect(frames, 4);
      expect(at, 4);
    });

    test('a rest of one frame between two moves is stillness (two frames '
        'in a row), as the flows ask', () async {
      final readings = <List<Object?>>[
        [1],
        [2],
        [2],
        [3],
      ];
      var at = 0;
      await still(() => readings[at++]);
      expect(frames, 3);
    });

    test('compares by contents: new lists of equal values are still', () async {
      await still(
        () => [const Rect.fromLTWH(5, 5, 5, 5), const Offset(1, 2), 'a'],
      );
      expect(frames, 2);
    });

    test('a change in only one of the values is a change', () async {
      var at = 0;
      await still(() {
        final moving = at++ < 3 ? at : 3;
        return [const Rect.fromLTWH(0, 0, 1, 1), moving];
      });
      expect(frames, 4);
    });

    test('fails, naming what it waited for, when it never stops', () async {
      var y = 0.0;
      Object? failure;
      try {
        await still(() => [Rect.fromLTWH(0, y += 1, 1, 1)]);
      } on TestFailure catch (e) {
        failure = e;
      }
      expect(failure, isA<TestFailure>());
      expect('$failure', contains('Timed out after 1 s waiting for'));
      expect('$failure', contains('the rail to stop'));
      expect(frames, inInclusiveRange(19, 22));
    });
  });
}
