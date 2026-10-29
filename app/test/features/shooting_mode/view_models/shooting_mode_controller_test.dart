import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/vm_harness.dart';

MediaAccess access(MediaAccessLevel level, {bool canAskAgain = true}) =>
    MediaAccess(level: level, canAskAgain: canAskAgain, sdkInt: 34);

void main() {
  late VmHarness h;
  late ShootingModeController controller;

  setUp(() async {
    h = VmHarness();
    h.bridge.put([fakeVideo(id: 1, generation: 5)]);
    controller = h.container.read(shootingModeControllerProvider.notifier);
    // Keep the stream provider alive and listening, as a screen would.
    h.container.listen(shootingModeControllerProvider, (_, _) {});
    await h.container.read(shootingModeControllerProvider.future);
  });

  ShootingState? shown() =>
      h.container.read(shootingModeControllerProvider).value;

  group('state', () {
    test('starts off and follows the stored Shooting mode', () async {
      expect(shown(), ShootingState.off);

      await h.media.turnOnNow();
      await settle();

      expect(shown()!.on, isTrue);
    });
  });

  group('turning on', () {
    test(
      'records the mounted volumes only, with version and generation',
      () async {
        h.bridge
          ..setVolume(card, version: 'v2', generation: 40)
          ..setVolume('unmounted-card', version: null, generation: 0);

        await controller.setOn(true);

        final state = await h.media.phoneState.loadShooting();
        expect(state.on, isTrue);
        expect(state.baselines, {
          phone: const VolumeBaseline(version: 'v1', generation: 5),
          card: const VolumeBaseline(version: 'v2', generation: 40),
        });
        expect(state.since, h.media.clock.now());
      },
    );

    test(
      'a failing volume list gives no baselines, and it still turns on',
      () async {
        final records = captureLogs();
        h.bridge.failNext('volumes');

        await controller.setOn(true);

        final state = await h.media.phoneState.loadShooting();
        expect(state.on, isTrue);
        expect(state.baselines, isEmpty);
        expect(logText(records), contains('PlatformException'));
        expect(logText(records), isNot(contains('failed on purpose')));
      },
    );

    test('turning on twice keeps the first session', () async {
      await controller.setOn(true);
      final first = await h.media.phoneState.loadShooting();
      h.media.clock.advance(const Duration(hours: 3));
      h.bridge.setVolume(phone, version: 'v1', generation: 99);

      await controller.setOn(true);

      expect(await h.media.phoneState.loadShooting(), first);
    });

    test('asks first when access is denied and Android can still ask, '
        'then turns on even if still denied', () async {
      h.bridge.access = access(MediaAccessLevel.denied);
      h.bridge.onRequestAccess = () => access(MediaAccessLevel.denied);

      await controller.setOn(true);

      expect(h.bridge.count('requestAccess'), 1);
      expect(
        h.bridge.calls.indexOf('requestAccess'),
        lessThan(h.bridge.calls.indexOf('volumes')),
      );
      expect((await h.media.phoneState.loadShooting()).on, isTrue);
    });

    test('does not ask when Android will not show the dialog', () async {
      h.bridge.access = access(MediaAccessLevel.denied, canAskAgain: false);

      await controller.setOn(true);

      expect(h.bridge.count('requestAccess'), 0);
      expect((await h.media.phoneState.loadShooting()).on, isTrue);
    });

    test('does not ask when access is full or limited', () async {
      await controller.setOn(true);
      await controller.setOn(false);
      h.bridge.access = access(MediaAccessLevel.limited);
      await controller.setOn(true);

      expect(h.bridge.count('requestAccess'), 0);
    });

    test(
      'the access banner follows an answer given while turning on',
      () async {
        h.bridge.access = access(MediaAccessLevel.denied);
        h.bridge.onRequestAccess = () => access(MediaAccessLevel.full);

        await controller.setOn(true);
        await settle();

        final view = h.container.read(mediaAccessControllerProvider).value!;
        expect(view.level, MediaAccessLevel.full);
        expect(view.banner, AccessBanner.none);
      },
    );

    test('a failing access check does not stop Shooting mode', () async {
      h.bridge.failNext('accessReport');

      await controller.setOn(true);

      expect((await h.media.phoneState.loadShooting()).on, isTrue);
    });

    test('scans once after it is on', () async {
      await controller.setOn(true);
      await settle();

      expect(h.bridge.count('videosAddedAfter'), 1);
    });

    test('a scan that throws is logged, Shooting mode stays on', () async {
      final records = captureLogs();
      // The first volumes() call reads the baselines, the second is the scan's
      // first bridge call.
      h.bridge
        ..failNext('volumes')
        ..failNext('volumes');

      await controller.setOn(true);
      await settle();

      expect(shown()!.on, isTrue);
      expect(logText(records), contains('The scan after turning on failed'));
    });
  });

  group('turning off', () {
    test('off keeps To tag and forgets the session', () async {
      await controller.setOn(true);
      await h.media.store([fakeVideo(id: 7, generation: 6)]);
      final before = [for (final c in await h.media.toTag()) c.id];

      await controller.setOn(false);
      await settle();

      expect(shown(), ShootingState.off);
      expect([for (final c in await h.media.toTag()) c.id], before);
      expect(before, hasLength(1));
    });

    test('off when already off is harmless', () async {
      await controller.setOn(false);

      expect(shown(), ShootingState.off);
    });
  });

  group('rapid taps', () {
    test('on then off ends off', () async {
      await Future.wait([controller.setOn(true), controller.setOn(false)]);
      await settle();

      expect((await h.media.phoneState.loadShooting()).on, isFalse);
      expect(shown()!.on, isFalse);
    });

    test('off then on ends on, with one session', () async {
      await controller.setOn(true);
      await Future.wait([controller.setOn(false), controller.setOn(true)]);
      await settle();

      expect((await h.media.phoneState.loadShooting()).on, isTrue);
      expect(shown()!.on, isTrue);
    });

    test('on, off, on, off, on ends on', () async {
      await Future.wait([
        for (final on in [true, false, true, false, true]) controller.setOn(on),
      ]);
      await settle();

      expect((await h.media.phoneState.loadShooting()).on, isTrue);
    });
  });

  group('openCamera', () {
    test('true when the camera app opens', () async {
      expect(await controller.openCamera(), isTrue);
      expect(h.bridge.count('openVideoCamera'), 1);
    });

    test('false when the phone has no camera app', () async {
      h.bridge.cameraOpens = false;

      expect(await controller.openCamera(), isFalse);
    });

    test('false, not an error, when the bridge fails', () async {
      h.bridge.failNext('openVideoCamera');

      expect(await controller.openCamera(), isFalse);
    });
  });

  test('a database error while turning on is logged, not thrown', () async {
    final records = captureLogs();
    await h.media.db.close();

    await controller.setOn(true);

    expect(logText(records), contains('Turning Shooting mode on failed'));
  });
}
