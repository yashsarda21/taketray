import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'shooting_mode_controller.g.dart';

// Counts and error types only, never a message, a path or a version (D-10).
final Logger _log = Logger('shootingMode');

/// Shooting mode for the card on the Reels screen: whether it is on, the
/// switch, and the camera shortcut (D-75).
///
/// The state is the stored Shooting mode
/// (`PhoneStateRepository.watchShooting`), so it is right at app start and
/// follows every change, including one made by someone else.
///
/// Kept alive, like the access controller it calls. If the stored-state
/// stream itself fails (a database error), the state is an `AsyncError` and
/// stays one until the provider is invalidated: there is no retry (`noRetry`).
@Riverpod(keepAlive: true, retry: noRetry)
class ShootingModeController extends _$ShootingModeController {
  /// The last [setOn] call. Calls run one after another, in the order they
  /// were made, so taps in quick succession end in the last one's state.
  Future<void> _tail = Future<void>.value();

  @override
  Stream<ShootingState> build() =>
      ref.watch(phoneStateRepositoryProvider).watchShooting();

  /// The Shooting mode switch.
  ///
  /// Turning on, in this order:
  /// 1. when access is denied and Android would still show its dialog, asks
  ///    for it (the answer is shown on the card's banner);
  /// 2. asks for the notification permission, once ever (Android 13 and
  ///    later, not allowed yet, never asked: `askOnce`, D-107). After that
  ///    only the Settings row asks;
  /// 3. stores Shooting mode with a baseline for each mounted volume (its
  ///    version and generation now), or with none when the volume list cannot
  ///    be read: the next scan then starts each volume from now. It is turned
  ///    on whatever the answers to 1 and 2 were: without full access the scan
  ///    simply does nothing, and the card says "Manual mode"; without the
  ///    notification permission nothing is posted;
  /// 4. starts a scan (not waited for).
  ///
  /// Turning on while it is on keeps the first session (`turnShootingOn`).
  /// Turning off forgets the session and leaves To tag alone.
  ///
  /// Never throws: an error is logged by type, and the card shows what is
  /// really stored. The returned future completes when this call's change is
  /// stored, after the calls made before it.
  // The switch's value, as the Task 9 contract names it.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setOn(bool on) {
    final run = _tail.then((_) => on ? _turnOn() : _turnOff());
    _tail = run;
    return run;
  }

  Future<void> _turnOn() async {
    final access = ref.read(mediaAccessControllerProvider.notifier);
    final notifications = ref.read(
      notificationAccessControllerProvider.notifier,
    );
    final bridge = ref.read(mediaBridgeProvider);
    final phone = ref.read(phoneStateRepositoryProvider);
    final scanner = ref.read(mediaScannerProvider);
    await guarded(_log, 'Turning Shooting mode on', () async {
      await access.askIfDenied();
      await notifications.askOnce();
      await phone.turnShootingOn(await _baselines(bridge));
      unawaited(guarded(_log, 'The scan after turning on', scanner.scan));
    });
  }

  Future<void> _turnOff() async {
    final phone = ref.read(phoneStateRepositoryProvider);
    await guarded(_log, 'Turning Shooting mode off', phone.turnShootingOff);
  }

  /// Where each mounted volume stands now. An unmounted volume (no version)
  /// has no baseline. A bridge error gives none at all.
  Future<Map<String, VolumeBaseline>> _baselines(MediaBridge bridge) async {
    final volumes = await guarded(_log, 'Reading the volumes', bridge.volumes);
    return {
      for (final v in volumes ?? const <MediaVolume>[])
        if (v.version != null)
          v.name: VolumeBaseline(version: v.version!, generation: v.generation),
    };
  }

  /// Opens the phone's camera in video mode. False, never an error, when no
  /// app could open or the call failed.
  Future<bool> openCamera() async {
    final bridge = ref.read(mediaBridgeProvider);
    return await guarded(_log, 'Opening the camera', bridge.openVideoCamera) ??
        false;
  }
}
