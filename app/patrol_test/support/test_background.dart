import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  /// `PowerManager.THERMAL_STATUS_MODERATE`: from here the system holds the
  /// new-clips job (the job's `Restricted due to: thermal`), so a wait for it
  /// proves nothing about the app.
  static const int thermalModerate = 2;

  /// `PowerManager.THERMAL_STATUS_*` by number; `unknown` for any other.
  static String thermalName(int status) => switch (status) {
    0 => 'none',
    1 => 'light',
    2 => 'moderate',
    3 => 'severe',
    4 => 'critical',
    5 => 'emergency',
    6 => 'shutdown',
    _ => 'unknown',
  };

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

  /// The phone's thermal status now (`PowerManager.getCurrentThermalStatus`,
  /// 0 to 6). A reply that is no number is a `StateError`, never 0.
  Future<int> thermalStatus() async {
    final reply = await _channel.invokeMethod<int>('thermalStatus');
    return reply ?? (throw StateError('thermalStatus gave no number'));
  }

  TestFailure _tooHot(int status) => TestFailure(
    'The phone is too hot to time the new-clips job: phone too hot, let it '
    'cool (thermal status $status, ${thermalName(status)}; wanted below '
    '$thermalModerate) and run the test again',
  );

  /// Fails the test, naming the heat, when the phone is at
  /// [thermalModerate] or above: the system holds the job then, and a wait
  /// for its notification would time out for a reason that is not the app's.
  /// A status that cannot be read is an error too (it is not "cool").
  /// Prints the status (a number) so a run's log shows the heat.
  Future<void> requireCool() async {
    final status = await thermalStatus();
    debugPrint('thermal status before the wait: $status');
    if (status >= thermalModerate) throw _tooHot(status);
  }

  /// Waits, with the phone idle, until the thermal status is below
  /// [thermalModerate], for at most [limit]; returns how long it waited.
  /// Fails with the same "phone too hot" failure when it does not cool in
  /// time. It is for the start of a flow: it never lengthens a wait for the
  /// job itself, which [requireCool] guards.
  Future<Duration> waitUntilCool({
    Duration limit = const Duration(minutes: 10),
    Duration poll = const Duration(seconds: 5),
  }) async {
    final clock = Stopwatch()..start();
    var polls = 0;
    while (true) {
      final status = await thermalStatus();
      if (status < thermalModerate) {
        if (polls > 0) {
          debugPrint(
            'phone cooled to thermal status $status after '
            '${clock.elapsed.inSeconds} s',
          );
        }
        return clock.elapsed;
      }
      if (clock.elapsed >= limit) throw _tooHot(status);
      polls++;
      await Future<void>.delayed(poll);
    }
  }

  /// A sentence for a timeout message: the thermal status now, or that it is
  /// unknown. Never throws.
  Future<String> thermalNote() async {
    try {
      final status = await thermalStatus();
      return ' (thermal status $status, ${thermalName(status)})';
    } on Object {
      return ' (thermal status unknown)';
    }
  }

  Future<List<int>> _ids(String method) async {
    final reply = await _channel.invokeListMethod<int>(method);
    return reply ?? const <int>[];
  }
}
