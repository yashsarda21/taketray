import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_api.g.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../support/fake_background_bridge.dart';

/// A [BackgroundHostApi] whose answers a test sets, and which remembers the
/// arguments it was called with.
class _StubApi extends BackgroundHostApi {
  ShadeActionMsg? shadeAction;
  NotificationAccessMsg access = NotificationAccessMsg(
    granted: false,
    canAsk: true,
    sdkInt: 34,
  );
  String maker = 'samsung';
  bool batteryOpens = true;
  LaunchActionMsg? startAction;

  /// Completes `takeLaunchAction`; null answers at once.
  Completer<void>? takeGate;

  /// How many `takeLaunchAction` calls fail before one answers.
  int takeFailures = 0;
  Exception? error;

  final List<String> calls = [];
  final List<Object?> args = [];

  void _record(String name, [Object? argument]) {
    calls.add(name);
    args.add(argument);
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<void> writeState(BackgroundStateMsg state) async =>
      _record('writeState', state);

  @override
  Future<ShadeActionMsg?> pendingShadeAction() async {
    _record('pendingShadeAction');
    return shadeAction;
  }

  @override
  Future<void> clearShadeAction(int atMs) async =>
      _record('clearShadeAction', atMs);

  @override
  Future<void> clearNewClipsNotification() async =>
      _record('clearNewClipsNotification');

  @override
  Future<NotificationAccessMsg> notificationAccess() async {
    _record('notificationAccess');
    return access;
  }

  @override
  Future<NotificationAccessMsg> requestNotificationAccess() async {
    _record('requestNotificationAccess');
    return access;
  }

  @override
  Future<void> openNotificationSettings() async =>
      _record('openNotificationSettings');

  @override
  Future<String> phoneMaker() async {
    _record('phoneMaker');
    return maker;
  }

  @override
  Future<bool> openBatterySettings() async {
    _record('openBatterySettings');
    return batteryOpens;
  }

  @override
  Future<LaunchActionMsg?> takeLaunchAction() async {
    _record('takeLaunchAction');
    if (takeFailures > 0) {
      takeFailures--;
      throw PlatformException(code: 'channel-error');
    }
    final gate = takeGate;
    if (gate != null) await gate.future;
    return startAction;
  }
}

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const flutterChannel =
      'dev.flutter.pigeon.taketray.BackgroundFlutterApi.onLaunchAction';

  late _StubApi api;
  late PigeonBackgroundBridge bridge;

  setUp(() {
    api = _StubApi();
    bridge = PigeonBackgroundBridge(
      api: api,
      takeRetryDelay: const Duration(milliseconds: 5),
    );
  });

  tearDown(() => bridge.dispose());

  /// Kotlin calling `BackgroundFlutterApi.onLaunchAction(action)`.
  Future<void> nativeSends(LaunchActionMsg action) async {
    final reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      flutterChannel,
      BackgroundFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[action]),
      reply.complete,
    );
    await reply.future;
  }

  test('bridge maps state to the message', () async {
    // A local time: the message carries UTC milliseconds whatever the zone.
    final since = DateTime(2026, 11, 5, 9, 30, 0, 123);
    await bridge.writeState(
      BackgroundState(
        shootingOn: true,
        since: since,
        baselines: const {
          'external_primary': VolumeBaseline(version: 'abc', generation: 90210),
          '1a2b-3c4d': VolumeBaseline(version: 'v2', generation: 7),
        },
        watchedFolders: const ['DCIM/Camera/', 'Movies/Café/'],
        // Out of order: the message lists them ascending.
        waitingShots: [_utc(3000), _utc(1000), _utc(2000).toLocal()],
        eveningEnabled: true,
        eveningMinutes: 1439,
        stillReminderEnabled: false,
        stillAnswered: true,
      ),
    );

    expect(api.calls, ['writeState']);
    final msg = api.args.single! as BackgroundStateMsg;
    expect(msg.shootingOn, isTrue);
    expect(msg.sinceMs, since.millisecondsSinceEpoch);
    // Sorted by volume name, so the same state is the same message.
    expect(msg.baselines.map((b) => b.volumeName), [
      '1a2b-3c4d',
      'external_primary',
    ]);
    expect(msg.baselines.map((b) => b.version), ['v2', 'abc']);
    expect(msg.baselines.map((b) => b.generation), [7, 90210]);
    expect(msg.watchedFolders, ['DCIM/Camera/', 'Movies/Café/']);
    expect(msg.waitingShotMs, [1000, 2000, 3000]);
    expect(msg.eveningEnabled, isTrue);
    expect(msg.eveningMinutes, 1439);
    expect(msg.stillReminderEnabled, isFalse);
    expect(msg.stillAnswered, isTrue);

    // Off, with nothing: a null since and empty lists.
    await bridge.writeState(
      const BackgroundState(
        shootingOn: false,
        since: null,
        baselines: {},
        watchedFolders: [],
        waitingShots: [],
        eveningEnabled: false,
        eveningMinutes: 0,
        stillReminderEnabled: true,
        stillAnswered: false,
      ),
    );
    final off = api.args.last! as BackgroundStateMsg;
    expect(off.shootingOn, isFalse);
    expect(off.sinceMs, isNull);
    expect(off.baselines, isEmpty);
    expect(off.waitingShotMs, isEmpty);
    expect(off.eveningMinutes, 0);
    expect(off.stillReminderEnabled, isTrue);
  });

  test('every answer maps to the domain', () async {
    expect(await bridge.pendingShadeAction(), isNull);
    api.shadeAction = ShadeActionMsg(
      kind: ShadeActionKindMsg.turnOff,
      sinceMs: 1780000000123,
      atMs: 1781000000000,
      generations: [
        VolumeGenerationMsg(volumeName: 'external_primary', generation: 90300),
        VolumeGenerationMsg(volumeName: '1a2b-3c4d', generation: 9),
      ],
    );
    expect(
      await bridge.pendingShadeAction(),
      ShadeAction(
        kind: ShadeActionKind.turnOff,
        since: _utc(1780000000123),
        at: _utc(1781000000000),
        generations: const {'external_primary': 90300, '1a2b-3c4d': 9},
      ),
    );
    expect((await bridge.pendingShadeAction())!.at.isUtc, isTrue);
    api.shadeAction = ShadeActionMsg(
      kind: ShadeActionKindMsg.keepOn,
      sinceMs: 1,
      atMs: 2,
      generations: [],
    );
    expect(
      await bridge.pendingShadeAction(),
      ShadeAction(
        kind: ShadeActionKind.keepOn,
        since: _utc(1),
        at: _utc(2),
        generations: const {},
      ),
    );

    await bridge.clearShadeAction(_utc(1781000000000).toLocal());
    expect(api.args.last, 1781000000000);

    for (final (granted, canAsk) in [(true, false), (false, true)]) {
      api.access = NotificationAccessMsg(
        granted: granted,
        canAsk: canAsk,
        sdkInt: 33,
      );
      final expected = NotificationAccess(
        granted: granted,
        canAsk: canAsk,
        sdkInt: 33,
      );
      expect(await bridge.notificationAccess(), expected);
      expect(await bridge.requestNotificationAccess(), expected);
    }

    expect(await bridge.phoneMaker(), 'samsung');
    expect(await bridge.openBatterySettings(), isTrue);
    api.batteryOpens = false;
    expect(await bridge.openBatterySettings(), isFalse);
    await bridge.openNotificationSettings();
    await bridge.clearNewClipsNotification();
    expect(
      api.calls,
      containsAllInOrder([
        'notificationAccess',
        'requestNotificationAccess',
        'phoneMaker',
        'openBatterySettings',
        'openNotificationSettings',
        'clearNewClipsNotification',
      ]),
    );
  });

  test('bridge maps errors like the media bridge', () async {
    final error = PlatformException(code: 'busy', message: 'already asking');
    api.error = error;
    final calls = <Future<Object?> Function()>[
      () => bridge.writeState(
        const BackgroundState(
          shootingOn: false,
          since: null,
          baselines: {},
          watchedFolders: [],
          waitingShots: [],
          eveningEnabled: false,
          eveningMinutes: 0,
          stillReminderEnabled: false,
          stillAnswered: false,
        ),
      ),
      bridge.pendingShadeAction,
      () => bridge.clearShadeAction(_utc(1)),
      bridge.clearNewClipsNotification,
      bridge.notificationAccess,
      bridge.requestNotificationAccess,
      bridge.openNotificationSettings,
      bridge.phoneMaker,
      bridge.openBatterySettings,
    ];
    for (final call in calls) {
      // The same exception, unchanged: the caller decides.
      await expectLater(call(), throwsA(same(error)));
    }
    // The start action's failure reaches the stream's listener.
    await expectLater(bridge.launchActions, emitsError(same(error)));
  });

  group('through the generated channels', () {
    const prefix = 'dev.flutter.pigeon.taketray.BackgroundHostApi';
    const codec = BackgroundHostApi.pigeonChannelCodec;

    tearDown(() {
      for (final name in ['phoneMaker', 'writeState']) {
        messenger.setMockMessageHandler('$prefix.$name', null);
      }
    });

    test('an error reply becomes a PlatformException, unchanged', () async {
      messenger.setMockMessageHandler('$prefix.phoneMaker', (message) async {
        return codec.encodeMessage(<Object?>[
          'native-error',
          'phoneMaker failed: IllegalStateException',
          null,
        ]);
      });
      await expectLater(
        PigeonBackgroundBridge().phoneMaker(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'native-error')
              .having(
                (e) => e.message,
                'message',
                'phoneMaker failed: IllegalStateException',
              ),
        ),
      );
    });

    test('a channel nobody answers is a channel-error', () {
      expect(
        PigeonBackgroundBridge().openBatterySettings(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'channel-error',
          ),
        ),
      );
    });

    test('the state survives the wire', () async {
      List<Object?>? received;
      messenger.setMockMessageHandler('$prefix.writeState', (message) async {
        received = codec.decodeMessage(message)! as List<Object?>;
        return codec.encodeMessage(<Object?>[]);
      });
      await PigeonBackgroundBridge().writeState(
        BackgroundState(
          shootingOn: true,
          since: _utc(5),
          baselines: const {
            'external_primary': VolumeBaseline(version: 'abc', generation: 1),
          },
          watchedFolders: const ['DCIM/Camera/'],
          waitingShots: [_utc(6)],
          eveningEnabled: true,
          eveningMinutes: 1260,
          stillReminderEnabled: true,
          stillAnswered: false,
        ),
      );
      final msg = received!.single! as BackgroundStateMsg;
      expect(msg.sinceMs, 5);
      expect(msg.baselines.single.version, 'abc');
      expect(msg.waitingShotMs, [6]);
    });
  });

  group('launch actions', () {
    test('launch actions stream yields the start action first', () async {
      api.startAction = LaunchActionMsg.reels;
      final gate = api.takeGate = Completer<void>();
      final seen = <LaunchAction>[];
      final sub = bridge.launchActions.listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(api.calls, ['takeLaunchAction']);

      // A tap arrives while the start action is still on its way.
      await nativeSends(LaunchActionMsg.toTag);
      expect(seen, isEmpty);

      gate.complete();
      await pumpEventQueue();
      expect(seen, [LaunchAction.reels, LaunchAction.toTag]);

      // Later taps come through the Flutter API, in order.
      await nativeSends(LaunchActionMsg.reels);
      await pumpEventQueue();
      expect(seen, [
        LaunchAction.reels,
        LaunchAction.toTag,
        LaunchAction.reels,
      ]);
      // The start action is taken once, however often the stream is
      // listened to.
      final again = bridge.launchActions.listen((_) {});
      await pumpEventQueue();
      await again.cancel();
      expect(api.calls.where((c) => c == 'takeLaunchAction'), hasLength(1));
    });

    test('no start action: only the taps', () async {
      final seen = <LaunchAction>[];
      final sub = bridge.launchActions.listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await nativeSends(LaunchActionMsg.toTag);
      await pumpEventQueue();
      expect(seen, [LaunchAction.toTag]);
    });

    group('a take that fails', () {
      // Kotlin keeps taps until Dart has taken the start action once (D-103).
      // A take that fails before it reaches Kotlin would strand every later
      // tap until the app restarts, so the bridge tries again.
      test('is tried again, and the start action still arrives', () async {
        api
          ..takeFailures = 2
          ..startAction = LaunchActionMsg.reels;
        final seen = <LaunchAction>[];
        final errors = <Object>[];
        final sub = bridge.launchActions.listen(seen.add, onError: errors.add);
        addTearDown(sub.cancel);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(api.calls.where((c) => c == 'takeLaunchAction'), hasLength(3));
        expect(seen, [LaunchAction.reels]);
        expect(errors, isEmpty);
        // Later taps come through as usual.
        await nativeSends(LaunchActionMsg.toTag);
        await pumpEventQueue();
        expect(seen, [LaunchAction.reels, LaunchAction.toTag]);
      });

      test(
        'a retry that finds no start action adds none and no error',
        () async {
          api.takeFailures = 1;
          final seen = <LaunchAction>[];
          final errors = <Object>[];
          final sub = bridge.launchActions.listen(
            seen.add,
            onError: errors.add,
          );
          addTearDown(sub.cancel);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(api.calls.where((c) => c == 'takeLaunchAction'), hasLength(2));
          expect(seen, isEmpty);
          expect(errors, isEmpty);
        },
      );

      test('three failures in a row reach the stream once, and taps '
          'still come through', () async {
        api.takeFailures = 10;
        final seen = <LaunchAction>[];
        final errors = <Object>[];
        final sub = bridge.launchActions.listen(seen.add, onError: errors.add);
        addTearDown(sub.cancel);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(api.calls.where((c) => c == 'takeLaunchAction'), hasLength(3));
        expect(errors, hasLength(1));
        expect(errors.single, isA<PlatformException>());
        await nativeSends(LaunchActionMsg.toTag);
        await pumpEventQueue();
        expect(seen, [LaunchAction.toTag]);
      });

      test(
        'a tap that arrives during the retries follows the start action',
        () async {
          api
            ..takeFailures = 1
            ..startAction = LaunchActionMsg.reels;
          final seen = <LaunchAction>[];
          final sub = bridge.launchActions.listen(seen.add);
          addTearDown(sub.cancel);
          await pumpEventQueue();
          await nativeSends(LaunchActionMsg.toTag);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(seen, [LaunchAction.reels, LaunchAction.toTag]);
        },
      );

      test(
        'dispose while waiting stops the retries and throws nothing',
        () async {
          api.takeFailures = 10;
          final sub = bridge.launchActions.listen((_) {});
          addTearDown(sub.cancel);
          await pumpEventQueue();
          expect(api.calls.where((c) => c == 'takeLaunchAction'), hasLength(1));
          bridge.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(api.calls.where((c) => c == 'takeLaunchAction'), hasLength(1));
        },
      );
    });

    test('nothing is asked before someone listens', () async {
      expect(bridge.launchActions, isA<Stream<LaunchAction>>());
      await pumpEventQueue();
      expect(api.calls, isEmpty);
    });

    test('dispose stops listening for taps', () async {
      final sub = bridge.launchActions.listen((_) {});
      addTearDown(sub.cancel);
      await pumpEventQueue();
      bridge.dispose();
      // Nobody answers on the channel any more: Kotlin's send fails, and
      // Kotlin then keeps the action for the next take.
      ByteData? reply;
      await messenger.handlePlatformMessage(
        flutterChannel,
        BackgroundFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[
          LaunchActionMsg.reels,
        ]),
        (data) => reply = data,
      );
      expect(reply, isNull);
    });
  });

  test('backgroundBridgeProvider builds the Pigeon bridge, once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(backgroundBridgeProvider);
    expect(first, isA<PigeonBackgroundBridge>());
    expect(container.read(backgroundBridgeProvider), same(first));
  });

  group('FakeBackgroundBridge', () {
    late FakeBackgroundBridge fake;

    setUp(() => fake = FakeBackgroundBridge());

    test('fake records writes', () async {
      final on = BackgroundState(
        shootingOn: true,
        since: _utc(1),
        baselines: const {},
        watchedFolders: const ['DCIM/Camera/'],
        waitingShots: const [],
        eveningEnabled: true,
        eveningMinutes: 1260,
        stillReminderEnabled: true,
        stillAnswered: false,
      );
      final off = on.copyWith(shootingOn: false, since: null);
      await fake.writeState(on);
      await fake.writeState(off);
      expect(fake.writes, [on, off]);
      expect(fake.state, off);

      // A failed write is logged as a call, not recorded as written.
      fake.failNext('writeState');
      await expectLater(fake.writeState(on), throwsA(isA<PlatformException>()));
      expect(fake.writes, [on, off]);
      expect(fake.calls, ['writeState', 'writeState', 'writeState']);
    });

    test('the shade action clears only for its own time', () async {
      final action = ShadeAction(
        kind: ShadeActionKind.turnOff,
        since: _utc(1),
        at: _utc(2),
        generations: const {'external_primary': 3},
      );
      fake.shadeAction = action;
      await fake.clearShadeAction(_utc(3));
      expect(await fake.pendingShadeAction(), action);
      await fake.clearShadeAction(_utc(2));
      expect(await fake.pendingShadeAction(), isNull);
      expect(fake.clearedShadeActions, [_utc(3), _utc(2)]);
    });

    test('the shade action clears by milliseconds, as on the phone', () async {
      // The phone keeps `atMs` only: a local DateTime of the same instant,
      // or one with extra microseconds, names the same tap.
      final action = ShadeAction(
        kind: ShadeActionKind.keepOn,
        since: _utc(1),
        at: DateTime.fromMicrosecondsSinceEpoch(2000123, isUtc: true),
        generations: const {},
      );
      fake.shadeAction = action;
      await fake.clearShadeAction(
        DateTime.fromMillisecondsSinceEpoch(2000).toLocal(),
      );
      expect(await fake.pendingShadeAction(), isNull);
    });

    test('the fake emits launch actions, the start action first', () async {
      fake.startAction = LaunchAction.reels;
      final seen = <LaunchAction>[];
      final sub = fake.launchActions.listen(seen.add);
      addTearDown(sub.cancel);
      fake.emit(LaunchAction.toTag);
      await pumpEventQueue();
      expect(seen, [LaunchAction.reels, LaunchAction.toTag]);
    });

    test('the fake answers the rest from its fields', () async {
      fake
        ..access = const NotificationAccess(
          granted: false,
          canAsk: true,
          sdkInt: 34,
        )
        ..onRequestNotificationAccess = (() =>
            const NotificationAccess(granted: true, canAsk: false, sdkInt: 34))
        ..maker = 'xiaomi'
        ..batteryOpens = false;
      expect((await fake.notificationAccess()).canAsk, isTrue);
      expect((await fake.requestNotificationAccess()).granted, isTrue);
      expect((await fake.notificationAccess()).granted, isTrue);
      expect(await fake.phoneMaker(), 'xiaomi');
      expect(await fake.openBatterySettings(), isFalse);
      await fake.openNotificationSettings();
      await fake.clearNewClipsNotification();
      expect(fake.calls, [
        'notificationAccess',
        'requestNotificationAccess',
        'notificationAccess',
        'phoneMaker',
        'openBatterySettings',
        'openNotificationSettings',
        'clearNewClipsNotification',
      ]);
    });
  });
}
