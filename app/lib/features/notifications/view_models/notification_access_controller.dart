import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/platform/background_bridge.dart';

part 'notification_access_controller.g.dart';

// Types only: never an error message (D-10).
final Logger _log = Logger('notificationAccess');

/// The first Android version with the notification permission dialog
/// (Android 13, `TIRAMISU`). Before it, notifications are allowed unless the
/// user turned them off in the phone's settings.
const int _permissionSdk = 33;

/// Whether TakeTray may post notifications, for the Notifications row in
/// Settings and the one question asked when Shooting mode is first turned on
/// (D-107).
///
/// Kept alive, like `MediaAccessController`: the app start, a resume and the
/// screens all use the one state. The bridge's answers are read fresh on every
/// call; only the last call to finish writes the state, so an older answer
/// arriving late never replaces a newer one. A first read that fails leaves
/// an `AsyncError` until a refresh works.
///
/// No method throws: an error is logged by type and the last view stays.
@Riverpod(keepAlive: true, retry: noRetry)
class NotificationAccessController extends _$NotificationAccessController {
  int _latest = 0;

  /// The newest view a call has published, and which call made it, so a
  /// `build` that finishes after a refresh does not overwrite it.
  int _published = 0;
  NotificationAccess? _publishedView;

  /// The [askOnce] that is running, so a second call joins it.
  Future<void>? _asking;

  @override
  Future<NotificationAccess> build() async {
    final call = ++_latest;
    try {
      final view = await ref
          .read(backgroundBridgeProvider)
          .notificationAccess();
      final newer = _publishedView;
      return _published > call && newer != null ? newer : view;
    } on Object catch (error) {
      final newer = _publishedView;
      if (_published > call && newer != null) {
        _log.warning('The first read failed: ${error.runtimeType}');
        return newer;
      }
      rethrow;
    }
  }

  /// Reads the permission again (app start, resume: the user may have
  /// changed it in the phone's settings).
  Future<void> refresh() async {
    final call = ++_latest;
    try {
      _publish(
        call,
        await ref.read(backgroundBridgeProvider).notificationAccess(),
      );
    } on Object catch (error, stack) {
      _log.warning('Reading the permission failed: ${error.runtimeType}');
      if (call == _latest && ref.mounted && !state.hasValue) {
        state = AsyncError(error, stack);
      }
    }
  }

  /// The "Allow" button in Settings.
  ///
  /// Reads a fresh answer first (what the screen shows may be old). Then:
  /// - allowed already: shows it, nothing to ask;
  /// - Android would show its dialog: asks, and shows the answer;
  /// - otherwise (blocked after two refusals, or below Android 13 with
  ///   notifications turned off): opens this app's notification settings.
  ///
  /// Returns false when the dialog or the settings page could not be opened,
  /// so the screen can say so; true otherwise. A read that fails goes to the
  /// settings page.
  Future<bool> allow() async {
    final bridge = ref.read(backgroundBridgeProvider);
    final call = ++_latest;
    NotificationAccess? access;
    try {
      access = await bridge.notificationAccess();
    } on Object catch (error) {
      _log.warning('Reading the permission failed: ${error.runtimeType}');
    }
    if (access != null && access.granted) {
      _publish(call, access);
      return true;
    }
    try {
      if (access != null && access.canAsk) {
        _publish(call, await bridge.requestNotificationAccess());
      } else {
        if (access != null) _publish(call, access);
        await bridge.openNotificationSettings();
      }
      return true;
    } on Object catch (error) {
      _log.warning('Allowing notifications failed: ${error.runtimeType}');
      return false;
    }
  }

  /// Asks for the permission, once in the life of this install (D-107): when
  /// Shooting mode is turned on. Used by `ShootingModeController`.
  ///
  /// It asks only if the phone has Android's dialog (Android 13 and later),
  /// notifications are not allowed yet, and no earlier call asked (the stored
  /// `notificationsAsked`). The key is stored before the question, so a
  /// question that was cut short by the app closing is not asked again. After
  /// that the only way is the Allow button in Settings. A second call while
  /// one runs joins it. Never throws.
  Future<void> askOnce() {
    final running = _asking;
    if (running != null) return running;
    final next = _askOnce().whenComplete(() => _asking = null);
    return _asking = next;
  }

  Future<void> _askOnce() =>
      guarded(_log, 'Asking for notifications', () async {
        final bridge = ref.read(backgroundBridgeProvider);
        final phone = ref.read(phoneStateRepositoryProvider);
        final call = ++_latest;
        final access = await bridge.notificationAccess();
        if (access.sdkInt < _permissionSdk || access.granted) return;
        if (await phone.notificationsAsked()) return;
        await phone.markNotificationsAsked();
        _publish(call, await bridge.requestNotificationAccess());
      });

  /// Shows [view] if no call started after [call].
  void _publish(int call, NotificationAccess view) {
    if (call != _latest || !ref.mounted) return;
    _published = call;
    _publishedView = view;
    state = AsyncData(view);
  }
}
