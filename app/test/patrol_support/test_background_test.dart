import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/shade_geometry.dart';
import '../../patrol_test/support/test_background.dart';

/// The helpers of the on-device background tests (patrol_test/support): the
/// channel wrapper sends exactly the method names the Kotlin hooks answer to,
/// and the geometry guard picks only a button of TakeTray's own notification.
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

  group('ownButtonIndex', () {
    // A notification text at y 400; its buttons on one row at y 520.
    const anchor = Rect.fromLTWH(100, 400, 800, 40);
    const keepOn = Rect.fromLTWH(500, 510, 150, 50);
    const turnOff = Rect.fromLTWH(200, 510, 150, 50);

    test('picks the button on the row of its sibling, below the text', () {
      expect(
        ownButtonIndex(
          anchor: anchor,
          candidates: [turnOff],
          siblings: [keepOn],
        ),
        0,
      );
    });

    test('ignores another apps button above the anchor', () {
      const above = Rect.fromLTWH(200, 100, 150, 50);
      expect(
        ownButtonIndex(
          anchor: anchor,
          candidates: [above, turnOff],
          siblings: [const Rect.fromLTWH(500, 100, 150, 50), keepOn],
        ),
        1,
      );
    });

    test('ignores a button far below the anchor (another notification)', () {
      const far = Rect.fromLTWH(200, 1400, 150, 50);
      expect(
        ownButtonIndex(
          anchor: anchor,
          candidates: [far],
          siblings: [const Rect.fromLTWH(500, 1400, 150, 50)],
        ),
        isNull,
      );
    });

    test('a button with no sibling on its row is not ours', () {
      // Another app's lone "Turn off" just below, with no "Keep on" next to it.
      const lone = Rect.fromLTWH(200, 470, 150, 50);
      expect(
        ownButtonIndex(anchor: anchor, candidates: [lone], siblings: [keepOn]),
        isNull,
      );
    });

    test('no candidate or no sibling is null', () {
      expect(
        ownButtonIndex(anchor: anchor, candidates: [], siblings: [keepOn]),
        isNull,
      );
      expect(
        ownButtonIndex(anchor: anchor, candidates: [turnOff], siblings: []),
        isNull,
      );
    });

    test('several fit: the nearest one', () {
      const next = Rect.fromLTWH(200, 700, 150, 50);
      expect(
        ownButtonIndex(
          anchor: anchor,
          candidates: [next, turnOff],
          siblings: [const Rect.fromLTWH(500, 700, 150, 50), keepOn],
        ),
        1,
      );
    });
  });
}
