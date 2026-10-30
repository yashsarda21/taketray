import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/media_work_queue.dart';

void main() {
  late MediaWorkQueue queue;

  setUp(() => queue = MediaWorkQueue());

  test('runs jobs one at a time, in the order they were queued', () async {
    final log = <String>[];
    final first = Completer<void>();
    final a = queue.run(() async {
      log.add('a start');
      await first.future;
      log.add('a end');
      return 'a';
    });
    final b = queue.run(() async {
      log.add('b');
      return 'b';
    });
    final c = queue.run(() async {
      log.add('c');
      return 'c';
    });
    await Future<void>.delayed(Duration.zero);
    expect(log, ['a start'], reason: 'b and c wait for a');
    first.complete();
    expect(await Future.wait([a, b, c]), ['a', 'b', 'c']);
    expect(log, ['a start', 'a end', 'b', 'c']);
  });

  test('a job that throws fails only its caller; the queue goes on', () async {
    final failing = queue.run<int>(() async => throw StateError('boom'));
    final next = queue.run(() async => 2);
    await expectLater(failing, throwsA(isA<StateError>()));
    expect(await next, 2);
    expect(await queue.run(() async => 3), 3);
  });

  test(
    'a job that throws before its first await does not stop the queue',
    () async {
      final failing = queue.run<int>(() => throw ArgumentError('sync'));
      final next = queue.run(() async => 'after');
      await expectLater(failing, throwsArgumentError);
      expect(await next, 'after');
    },
  );

  test('a job queued after a failure has finished still runs', () async {
    await expectLater(
      queue.run<void>(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await queue.run(() async => 'later'), 'later');
  });

  test('mediaWorkQueueProvider keeps one queue', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(mediaWorkQueueProvider);
    expect(container.read(mediaWorkQueueProvider), same(first));
  });
}
