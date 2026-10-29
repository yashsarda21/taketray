import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/test_media.dart';

/// The clean-up of the on-device tests' helper (patrol_test/support): it must
/// try to delete every video it inserted, however many deletes fail.
void main() {
  const channel = MethodChannel('test/test_media_fake');
  late List<String> calls;
  late int nextId;
  late Set<int> failingDeletes;
  late int refusedLeftovers;

  setUp(() {
    calls = [];
    nextId = 1;
    failingDeletes = {};
    refusedLeftovers = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'insertVideo':
              calls.add('insert');
              return {
                'volumeName': 'external_primary',
                'mediaStoreId': nextId++,
              };
            case 'deleteVideo':
              final id = (call.arguments as Map)['mediaStoreId'] as int;
              calls.add('delete $id');
              if (failingDeletes.contains(id)) {
                throw PlatformException(code: 'native-error');
              }
              return true;
            case 'deleteLeftovers':
              calls.add('leftovers');
              return {'deleted': 0, 'refused': refusedLeftovers};
          }
          throw MissingPluginException();
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'cleanUp deletes every inserted video, then asks for leftovers',
    () async {
      final media = TestMedia.withChannel(channel);
      for (var i = 0; i < 3; i++) {
        await media.insert();
      }
      calls.clear();

      await media.cleanUp();

      expect(calls, ['delete 1', 'delete 2', 'delete 3', 'leftovers']);
      expect(media.inserted, isEmpty);
    },
  );

  test('the second of three deletes fails: all three are tried, the '
      'leftovers fallback runs and the first error is rethrown', () async {
    final media = TestMedia.withChannel(channel);
    for (var i = 0; i < 3; i++) {
      await media.insert();
    }
    calls.clear();
    failingDeletes = {2};

    await expectLater(media.cleanUp(), throwsA(isA<PlatformException>()));

    expect(calls, ['delete 1', 'delete 2', 'delete 3', 'leftovers']);
    // The failed one is still listed: a second cleanUp tries it again.
    expect(media.inserted.map((v) => v.mediaStoreId), [2]);
    failingDeletes = {};
    calls.clear();
    await media.cleanUp();
    expect(calls, ['delete 2', 'leftovers']);
  });

  test(
    'the first error is the one rethrown when several deletes fail',
    () async {
      final media = TestMedia.withChannel(channel);
      for (var i = 0; i < 3; i++) {
        await media.insert();
      }
      calls.clear();
      failingDeletes = {1, 3};

      Object? error;
      try {
        await media.cleanUp();
      } on Object catch (e) {
        error = e;
      }

      expect(error, isA<PlatformException>());
      expect(calls, ['delete 1', 'delete 2', 'delete 3', 'leftovers']);
      expect(media.inserted.map((v) => v.mediaStoreId), [1, 3]);
    },
  );

  test(
    'start fails when the folder holds a file this app does not own',
    () async {
      refusedLeftovers = 2;
      await expectLater(
        TestMedia.start(channel: channel),
        throwsA(isA<TestFailure>()),
      );
    },
  );
}
