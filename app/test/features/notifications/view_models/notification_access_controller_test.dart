import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../../support/vm_harness.dart';

NotificationAccess _access({
  bool granted = false,
  bool canAsk = true,
  int sdk = 34,
}) => NotificationAccess(granted: granted, canAsk: canAsk, sdkInt: sdk);

void main() {
  late VmHarness h;
  late NotificationAccessController controller;

  setUp(() {
    h = VmHarness();
  });

  /// Reads the controller with [access] on the phone, kept alive as a screen
  /// would.
  Future<void> start(NotificationAccess access) async {
    h.background.access = access;
    controller = h.container.read(
      notificationAccessControllerProvider.notifier,
    );
    h.container.listen(notificationAccessControllerProvider, (_, _) {});
    await h.container.read(notificationAccessControllerProvider.future);
  }

  NotificationAccess? shown() =>
      h.container.read(notificationAccessControllerProvider).value;

  int calls(String method) =>
      h.background.calls.where((c) => c == method).length;

  group('state and refresh', () {
    test('starts with what the phone says', () async {
      await start(_access(granted: true, canAsk: false));

      expect(shown(), _access(granted: true, canAsk: false));
      expect(calls('requestNotificationAccess'), 0);
    });

    test('refresh reads the phone again', () async {
      await start(_access());

      h.background.access = _access(granted: true, canAsk: false);
      await controller.refresh();

      expect(shown()!.granted, isTrue);
    });

    test('a refresh that fails changes nothing and does not throw', () async {
      await start(_access(granted: true, canAsk: false));
      final records = captureLogs();
      h.background.failNext('notificationAccess');

      await controller.refresh();

      expect(shown()!.granted, isTrue);
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
    });

    test('a first read that fails is an error until a refresh works', () async {
      h.background.failNext('notificationAccess');
      h.container.listen(notificationAccessControllerProvider, (_, _) {});
      controller = h.container.read(
        notificationAccessControllerProvider.notifier,
      );
      await settle();
      expect(
        h.container.read(notificationAccessControllerProvider),
        isA<AsyncError<NotificationAccess>>(),
      );

      await controller.refresh();

      expect(shown(), isNotNull);
    });
  });

  group('Allow', () {
    test('asks when Android will show its dialog', () async {
      await start(_access());
      h.background.onRequestNotificationAccess = () =>
          _access(granted: true, canAsk: false);

      final ok = await controller.allow();

      expect(ok, isTrue);
      expect(calls('requestNotificationAccess'), 1);
      expect(calls('openNotificationSettings'), 0);
      expect(shown()!.granted, isTrue);
    });

    test('a denied answer is shown, and nothing else opens', () async {
      await start(_access());
      h.background.onRequestNotificationAccess = () => _access(canAsk: false);

      final ok = await controller.allow();

      expect(ok, isTrue);
      expect(shown(), _access(canAsk: false));
      expect(calls('openNotificationSettings'), 0);
    });

    test('Allow opens settings when Android will not ask', () async {
      await start(_access(canAsk: false));

      final ok = await controller.allow();

      expect(ok, isTrue);
      expect(calls('openNotificationSettings'), 1);
      expect(calls('requestNotificationAccess'), 0);
    });

    test('below Android 13 Allow opens settings too', () async {
      await start(_access(canAsk: false, sdk: 31));

      await controller.allow();

      expect(calls('openNotificationSettings'), 1);
    });

    test('reads the phone fresh: what the screen shows may be old', () async {
      await start(_access());
      // Allowed in the phone's settings meanwhile.
      h.background.access = _access(granted: true, canAsk: false);

      final ok = await controller.allow();

      expect(ok, isTrue);
      expect(calls('requestNotificationAccess'), 0);
      expect(calls('openNotificationSettings'), 0);
      expect(shown()!.granted, isTrue);
    });

    test('settings that cannot open give false, and no error', () async {
      await start(_access(canAsk: false));
      final records = captureLogs();
      h.background.failNext('openNotificationSettings');

      final ok = await controller.allow();

      expect(ok, isFalse);
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
    });

    test('a request that fails gives false and keeps the last view', () async {
      await start(_access());
      h.background.failNext('requestNotificationAccess');

      final ok = await controller.allow();

      expect(ok, isFalse);
      expect(shown(), _access());
    });

    test('a read that fails still tries the settings page', () async {
      await start(_access());
      h.background.failNext('notificationAccess');

      final ok = await controller.allow();

      expect(ok, isTrue);
      expect(calls('openNotificationSettings'), 1);
    });
  });

  group('asking once', () {
    test('asks on Android 13 and later, and remembers it', () async {
      await start(_access());

      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 1);
      expect(await h.media.phoneState.notificationsAsked(), isTrue);
    });

    test('shows the answer', () async {
      await start(_access());
      h.background.onRequestNotificationAccess = () =>
          _access(granted: true, canAsk: false);

      await controller.askOnce();

      expect(shown()!.granted, isTrue);
    });

    test('not asked below 33', () async {
      await start(_access(canAsk: false, sdk: 32));

      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 0);
      expect(await h.media.phoneState.notificationsAsked(), isFalse);
    });

    test('exactly Android 13 (33) asks', () async {
      await start(_access(sdk: 33));

      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 1);
    });

    test('not asked when already allowed, and the key stays unset', () async {
      await start(_access(granted: true, canAsk: false));

      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 0);
      expect(await h.media.phoneState.notificationsAsked(), isFalse);
    });

    test('not asked twice', () async {
      await start(_access());
      await controller.askOnce();
      h.background.access = _access();

      await controller.askOnce();
      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 1);
    });

    test('not asked again after an earlier session asked', () async {
      await h.media.phoneState.markNotificationsAsked();
      await start(_access());

      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 0);
    });

    test('two calls at the same moment ask once', () async {
      await start(_access());
      final gate = h.background.gate('requestNotificationAccess');

      final first = controller.askOnce();
      final second = controller.askOnce();
      await settle();
      gate.complete();
      await Future.wait([first, second]);

      expect(calls('requestNotificationAccess'), 1);
    });

    test(
      'a request that fails is not asked again, and does not throw',
      () async {
        await start(_access());
        final records = captureLogs();
        h.background.failNext('requestNotificationAccess');

        await controller.askOnce();
        await controller.askOnce();

        expect(calls('requestNotificationAccess'), 1);
        expect(await h.media.phoneState.notificationsAsked(), isTrue);
        expect(logText(records), contains('PlatformException'));
      },
    );

    test('an access read that fails asks nothing and does not throw', () async {
      await start(_access());
      h.background.failNext('notificationAccess');

      await controller.askOnce();

      expect(calls('requestNotificationAccess'), 0);
      expect(await h.media.phoneState.notificationsAsked(), isFalse);
    });
  });
}
