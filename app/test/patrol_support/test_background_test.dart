import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/test_background.dart';

/// The helpers of the on-device background tests (patrol_test/support): the
/// channel wrapper sends exactly the method names the Kotlin hooks answer to
/// (the shade guards are in `shade_test.dart`).
void main() {
  group('TestBackground', () {
    const channel = MethodChannel('test/test_background_fake');
    late List<String> calls;
    late Object? Function(String method) reply;

    setUp(() {
      calls = [];
      reply = (_) => null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return reply(call.method);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('the channel and the ids are the ones Kotlin uses', () {
      expect(TestBackground.channelName, 'app.taketray/test_background');
      expect(TestBackground.newClipsId, 1);
      expect(TestBackground.eveningId, 2);
      expect(TestBackground.stillShootingId, 3);
      expect(TestBackground.newClipsJobId, 0x7A72);
    });

    test('each call is the method of the same name', () async {
      final background = TestBackground(channel);
      reply = (_) => <int>[];

      await background.fireEvening();
      await background.fireStill();
      await background.runNewClipsJob();
      await background.activeNotifications();
      await background.pendingJobs();
      await background.pressStillTurnOff();

      expect(calls, [
        'fireEvening',
        'fireStill',
        'runNewClipsJob',
        'activeNotifications',
        'pendingJobs',
        'pressStillTurnOff',
      ]);
    });

    test('ids come back as a list of ints, an empty list as empty', () async {
      final background = TestBackground(channel);
      reply = (m) => m == 'pendingJobs' ? <int>[0x7A72] : <int>[];

      expect(await background.pendingJobs(), [0x7A72]);
      expect(await background.activeNotifications(), isEmpty);
    });

    test(
      'pressStillTurnOff is the method of the same name and waits for it',
      () async {
        final background = TestBackground(channel);

        await background.pressStillTurnOff();

        expect(calls, ['pressStillTurnOff']);
      },
    );

    test(
      'pressStillTurnOff errors reach the test (no notification, no action)',
      () async {
        final background = TestBackground(channel);
        for (final code in ['no-notification', 'no-action', 'native-error']) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                throw PlatformException(code: code);
              });

          await expectLater(
            background.pressStillTurnOff(),
            throwsA(
              isA<PlatformException>().having((e) => e.code, 'code', code),
            ),
            reason: code,
          );
        }
      },
    );

    test('a null reply is an empty list', () async {
      final background = TestBackground(channel);

      expect(await background.activeNotifications(), isEmpty);
    });

    test(
      'thermalStatus asks the thermalStatus hook and returns its int',
      () async {
        final background = TestBackground(channel);
        reply = (m) => m == 'thermalStatus' ? 3 : null;

        expect(await background.thermalStatus(), 3);
        expect(calls, ['thermalStatus']);
      },
    );

    test(
      'thermalStatus with no number in the reply is an error, not 0',
      () async {
        final background = TestBackground(channel);
        reply = (_) => null;

        await expectLater(background.thermalStatus(), throwsStateError);
      },
    );

    test('requireCool lets a cool phone through (none, light)', () async {
      final background = TestBackground(channel);
      for (final status in [0, 1]) {
        reply = (_) => status;

        await background.requireCool();
      }
    });

    test(
      'requireCool fails a hot phone (moderate and above) by name',
      () async {
        final background = TestBackground(channel);
        for (final status in [2, 3, 4, 5, 6]) {
          reply = (_) => status;

          await expectLater(
            background.requireCool(),
            throwsA(
              isA<TestFailure>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('phone too hot'),
                  contains('let it cool'),
                  contains('thermal status $status'),
                ),
              ),
            ),
            reason: 'status $status',
          );
        }
      },
    );

    test('requireCool does not hide a hook that cannot be read', () async {
      final background = TestBackground(channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'native-error');
          });

      await expectLater(
        background.requireCool(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('thermalNote names the status for a timeout message', () async {
      final background = TestBackground(channel);
      reply = (_) => 2;

      final note = await background.thermalNote();

      expect(note, contains('thermal status 2'));
      expect(note, contains('moderate'));
    });

    test('thermalNote never throws: an unreadable status is unknown', () async {
      final background = TestBackground(channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'native-error');
          });

      expect(
        await background.thermalNote(),
        contains('thermal status unknown'),
      );
    });

    test('thermal status names follow PowerManager (0 to 6)', () {
      expect(
        [for (var i = 0; i <= 6; i++) TestBackground.thermalName(i)],
        [
          'none',
          'light',
          'moderate',
          'severe',
          'critical',
          'emergency',
          'shutdown',
        ],
      );
      expect(TestBackground.thermalName(7), 'unknown');
      expect(TestBackground.thermalName(-1), 'unknown');
      expect(TestBackground.thermalModerate, 2);
    });

    test('waitUntilCool returns at once on a cool phone', () async {
      final background = TestBackground(channel);
      reply = (_) => 1;

      final waited = await background.waitUntilCool(
        limit: const Duration(seconds: 5),
        poll: const Duration(milliseconds: 10),
      );

      expect(waited, lessThan(const Duration(milliseconds: 100)));
      expect(calls, ['thermalStatus'], reason: 'one read, no waiting');
    });

    test(
      'waitUntilCool waits for a hot phone to drop below moderate',
      () async {
        final background = TestBackground(channel);
        final statuses = [3, 2, 2, 1];
        reply = (_) => statuses.removeAt(0);

        final waited = await background.waitUntilCool(
          limit: const Duration(seconds: 5),
          poll: const Duration(milliseconds: 10),
        );

        expect(calls, hasLength(4), reason: 'polled until the status was 1');
        expect(waited, greaterThan(Duration.zero));
      },
    );

    test('waitUntilCool gives up on a phone that stays hot, by name', () async {
      final background = TestBackground(channel);
      reply = (_) => 2;

      await expectLater(
        background.waitUntilCool(
          limit: const Duration(milliseconds: 100),
          poll: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('phone too hot'), contains('thermal status 2')),
          ),
        ),
      );
    });

    test('waitUntilCool does not hide a hook that cannot be read', () async {
      final background = TestBackground(channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'native-error');
          });

      await expectLater(
        background.waitUntilCool(
          limit: const Duration(milliseconds: 100),
          poll: const Duration(milliseconds: 20),
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    test('the error code reaches the test', () async {
      final background = TestBackground(channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'no-session');
          });

      await expectLater(
        background.fireStill(),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'no-session'),
        ),
      );
    });
  });
}
