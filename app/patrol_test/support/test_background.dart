import 'package:flutter/services.dart';

import 'shade_geometry.dart';

/// The debug-only channel `app.taketray/test_background`
/// (`DebugBackgroundHooks.kt`, Phase 6 Task 9): it reaches the same Android
/// code the alarms, the notification shade and the job scheduler reach, which
/// an app cannot be made to trigger on demand any other way.
///
/// Nothing here carries a name, a path or a folder. Errors are
/// `PlatformException`s with the code `no-session` (Still shooting? needs
/// Shooting mode on), `native-error` (the class of the exception only) or a
/// missing plugin in a build without the hooks.
class TestBackground {
  TestBackground([this._channel = const MethodChannel(channelName)]);

  /// The name of the debug-only channel.
  static const String channelName = 'app.taketray/test_background';

  /// The notification ids the app posts under (`Notifier.kt`).
  static const int newClipsId = 1;
  static const int eveningId = 2;
  static const int stillShootingId = 3;

  /// The new-clips job's id (`NewClipsJobService.JOB_ID`, 0x7A72).
  static const int newClipsJobId = 0x7A72;

  final MethodChannel _channel;

  /// Sends the broadcast the evening alarm carries to the app's receiver,
  /// which counts today's waiting clips and posts the reminder (or nothing).
  /// Returns when the broadcast is sent: the receiver posts a moment later.
  Future<void> fireEvening() => _channel.invokeMethod<void>('fireEvening');

  /// The same for Still shooting?, for the stored Shooting mode session.
  /// `PlatformException(no-session)` when Shooting mode is off.
  Future<void> fireStill() => _channel.invokeMethod<void>('fireStill');

  /// Runs the new-clips job's work now (the system's own run cannot be forced
  /// by an app). Returns when the run, and the arming of the next one, is over.
  Future<void> runNewClipsJob() =>
      _channel.invokeMethod<void>('runNewClipsJob');

  /// The ids of the app's own notifications in the shade, sorted. Only this
  /// app's: Android never gives an app another app's notifications.
  Future<List<int>> activeNotifications() => _ids('activeNotifications');

  /// The ids of the app's pending jobs, sorted.
  Future<List<int>> pendingJobs() => _ids('pendingJobs');

  /// The default display now: its real size and rotation (`PhoneDisplay`),
  /// for the one tap at a point (`tapOwnButton`). Null when the reply is not
  /// those three numbers; `PlatformException(no-display)` when the phone has
  /// no default display.
  Future<PhoneDisplay?> display() async => PhoneDisplay.fromReply(
    await _channel.invokeMethod<Object?>('displaySize'),
  );

  Future<List<int>> _ids(String method) async {
    final reply = await _channel.invokeListMethod<int>(method);
    return reply ?? const <int>[];
  }
}
