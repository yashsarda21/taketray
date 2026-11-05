import 'dart:async';

import 'package:flutter/services.dart';
import 'package:taketray/platform/background_bridge.dart';

/// A [BackgroundBridge] with no phone, for tests.
///
/// - Every successful `writeState` is recorded in [writes], in order, and
///   the last one is [state].
/// - Settable answers: [shadeAction] (cleared by `clearShadeAction` only for
///   its own `at`, as on the phone; every argument is logged in
///   [clearedShadeActions]), [access], [maker], [batteryOpens].
/// - [onRequestNotificationAccess] gives the result of
///   `requestNotificationAccess`, which also becomes the new [access]; by
///   default it answers with the current [access].
/// - [startAction] is what the app was "started with": the first event of
///   [launchActions] when it is listened to (taken once). [emit] sends a tap
///   while the app runs.
/// - [calls] logs the name of every call, in order, including one that
///   fails. [failNext] makes the next call of a method throw a
///   `PlatformException`.
class FakeBackgroundBridge implements BackgroundBridge {
  /// The last state written, or null before any write.
  BackgroundState? state;

  final List<BackgroundState> writes = [];

  ShadeAction? shadeAction;

  final List<DateTime> clearedShadeActions = [];

  NotificationAccess access = const NotificationAccess(
    granted: true,
    canAsk: false,
    sdkInt: 34,
  );

  NotificationAccess Function()? onRequestNotificationAccess;

  String maker = 'samsung';

  bool batteryOpens = true;

  LaunchAction? startAction;

  final List<String> calls = [];

  final Map<String, int> _failures = {};

  late final StreamController<LaunchAction> _launches =
      StreamController<LaunchAction>.broadcast(onListen: _start);
  bool _started = false;

  /// The next call of [method] throws a `PlatformException`. Calling it twice
  /// fails two calls.
  void failNext(String method) =>
      _failures[method] = (_failures[method] ?? 0) + 1;

  /// A notification tapped while the app runs.
  void emit(LaunchAction action) => _launches.add(action);

  Future<T> _call<T>(String method, T Function() answer) async {
    calls.add(method);
    final failures = _failures[method] ?? 0;
    if (failures > 0) {
      _failures[method] = failures - 1;
      throw PlatformException(
        code: 'fake-failure',
        message: '$method failed on purpose',
      );
    }
    return answer();
  }

  void _start() {
    if (_started) return;
    _started = true;
    final start = startAction;
    startAction = null;
    if (start != null) _launches.add(start);
  }

  @override
  Future<void> writeState(BackgroundState state) => _call('writeState', () {
    writes.add(state);
    this.state = state;
  });

  @override
  Future<ShadeAction?> pendingShadeAction() =>
      _call('pendingShadeAction', () => shadeAction);

  @override
  Future<void> clearShadeAction(DateTime at) => _call('clearShadeAction', () {
    clearedShadeActions.add(at);
    if (shadeAction?.at == at) shadeAction = null;
  });

  @override
  Future<void> clearNewClipsNotification() =>
      _call('clearNewClipsNotification', () {});

  @override
  Future<NotificationAccess> notificationAccess() =>
      _call('notificationAccess', () => access);

  @override
  Future<NotificationAccess> requestNotificationAccess() =>
      _call('requestNotificationAccess', () {
        final result = (onRequestNotificationAccess ?? () => access)();
        access = result;
        return result;
      });

  @override
  Future<void> openNotificationSettings() =>
      _call('openNotificationSettings', () {});

  @override
  Future<String> phoneMaker() => _call('phoneMaker', () => maker);

  @override
  Future<bool> openBatterySettings() =>
      _call('openBatterySettings', () => batteryOpens);

  @override
  Stream<LaunchAction> get launchActions => _launches.stream;
}
