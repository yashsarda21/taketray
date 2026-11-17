import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/platform/files_bridge.dart';

part 'settings_controller.g.dart';

/// The user's settings for the Settings screen (Phase 10B, D-148): the
/// settings now, and again each time they change (`SettingsRepository.watch`).
/// While the first read runs the state is loading; if it fails, an error.
///
/// Every setter is a read-modify-save of the **latest stored** settings, not
/// of the state, which may not have heard of a save made a moment ago. The
/// calls run one after the other, in the order they were made, so two quick
/// changes (two switches tapped in the same frame) never overwrite each
/// other. A save that fails reaches the caller of that setter only; the
/// calls after it still run.
///
/// The background jobs read the stored settings each time they run, so what
/// is saved here is what they use, even when the app is not opened again
/// (D-145).
@Riverpod(retry: noRetry)
class SettingsController extends _$SettingsController {
  /// The end of the last change asked for. It never fails, so one failed
  /// save does not stop the changes after it.
  Future<void> _tail = Future.value();

  @override
  Stream<AppSettings> build() => ref.watch(settingsRepositoryProvider).watch();

  /// The evening reminder on or off.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setEvening(bool enabled) =>
      _change((s) => s.copyWith(eveningReminderEnabled: enabled));

  /// The time of the evening reminder, in minutes after local midnight.
  /// Throws [ArgumentError], saving nothing, unless it is 0 to 1439 (a time
  /// that is not a minute of the day would never fire, or fire at the wrong
  /// time).
  Future<void> setEveningMinutes(int minutes) async {
    if (minutes < 0 || minutes >= 24 * 60) {
      throw ArgumentError.value(minutes, 'minutes', 'must be 0 to 1439');
    }
    await _change((s) => s.copyWith(eveningReminderMinutes: minutes));
  }

  /// The "Still shooting?" reminder on or off.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setStillReminder(bool enabled) =>
      _change((s) => s.copyWith(stillReminderEnabled: enabled));

  /// The reminder to delete VN copies on or off.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCopiesReminder(bool enabled) =>
      _change((s) => s.copyWith(copiesReminderEnabled: enabled));

  /// Runs [change] on the stored settings and saves the result, after the
  /// changes asked for before it.
  Future<void> _change(AppSettings Function(AppSettings) change) {
    final repository = ref.read(settingsRepositoryProvider);
    final run = _tail.then((_) async {
      final latest = await repository.load();
      await repository.save(change(latest));
    });
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}

/// When a backup file was last saved on this phone, or null (none, or not
/// readable), for the Export and import row. Read again when the backup
/// screen is left (`ref.invalidate`).
@Riverpod(retry: noRetry)
Future<DateTime?> lastExport(Ref ref) =>
    ref.watch(phoneStateRepositoryProvider).lastExport();

/// The app's version and Android's release, for the About row. Read once; an
/// error is the state ("Version" alone is shown).
@Riverpod(keepAlive: true, retry: noRetry)
Future<AppInfo> appInfo(Ref ref) => ref.watch(filesBridgeProvider).appInfo();
