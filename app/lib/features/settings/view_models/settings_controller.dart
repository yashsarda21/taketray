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
/// Every setter is `SettingsRepository.update`: a read-modify-save of the
/// **latest stored** settings in one database transaction, not of the state,
/// which may not have heard of a save made a moment ago. The database runs
/// the updates one after the other, so two quick changes (two switches
/// tapped in the same frame) never overwrite each other, and neither does a
/// change made at the same moment by another screen, such as Watched folders
/// (D-149, ruling R3). A save that fails reaches the caller of that setter
/// only; the calls after it still run.
///
/// The background jobs read the stored settings each time they run, so what
/// is saved here is what they use, even when the app is not opened again
/// (D-145).
@Riverpod(retry: noRetry)
class SettingsController extends _$SettingsController {
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

  /// Runs [change] on the stored settings and saves the result, in one
  /// transaction.
  Future<void> _change(AppSettings Function(AppSettings) change) =>
      ref.read(settingsRepositoryProvider).update(change);
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
