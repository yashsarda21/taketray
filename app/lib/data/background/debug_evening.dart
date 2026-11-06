import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/settings_repository.dart';

// Never the minutes: a time of day says when the owner shoots (D-10).
final Logger _log = Logger('debugEvening');

/// The minute of the day [inMinutes] after [now] on the phone's clock
/// (minutes after local midnight, 0 to 1439). Seconds are ignored; past
/// midnight it wraps to the early minutes of the day.
int eveningMinutesIn(DateTime now, int inMinutes) =>
    (now.hour * 60 + now.minute + inMinutes) % Duration.minutesPerDay;

/// The debug build's way to set the evening reminder "to the next minutes"
/// (Phase 6, Task 9): Settings has no row for the time until Phase 10, so the
/// owner's hand check builds the debug app with
/// `--dart-define=TAKETRAY_EVENING_IN_MINUTES=2`, and `TakeTrayApp` calls
/// this at app start (debug builds only).
///
/// Switches the evening reminder on and sets its time to [inMinutes] minutes
/// after [now]; the other settings stay. Returns whether it changed anything:
/// false (and nothing is written) for 0 or less. `BackgroundSync` then
/// writes the new time to the phone, which arms the alarm. A failed save
/// is thrown for the caller to log.
Future<bool> applyDebugEvening(
  SettingsRepository settings, {
  required int inMinutes,
  required DateTime now,
}) async {
  if (inMinutes <= 0) return false;
  final current = await settings.load();
  await settings.save(
    current.copyWith(
      eveningReminderEnabled: true,
      eveningReminderMinutes: eveningMinutesIn(now, inMinutes),
    ),
  );
  _log.info('Set the evening reminder from the debug build');
  return true;
}
