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

      expect(calls, [
        'fireEvening',
        'fireStill',
        'runNewClipsJob',
        'activeNotifications',
        'pendingJobs',
      ]);
    });

    test('ids come back as a list of ints, an empty list as empty', () async {
      final background = TestBackground(channel);
      reply = (m) => m == 'pendingJobs' ? <int>[0x7A72] : <int>[];

      expect(await background.pendingJobs(), [0x7A72]);
      expect(await background.activeNotifications(), isEmpty);
    });

    test('a null reply is an empty list', () async {
      final background = TestBackground(channel);

      expect(await background.activeNotifications(), isEmpty);
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
