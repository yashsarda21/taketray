import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/app_settings.dart';

part 'settings_repository.g.dart';

// Only a key's name is logged, never its value (D-10).
final Logger _log = Logger('settings');

/// Loads, saves and watches the user's settings.
///
/// Each setting is one row in the key/value `settings` table, its value
/// written as JSON. A key with no row has its default (the one in
/// [AppSettings]); a row that cannot be read as the right kind of value is
/// treated as missing, and its key name is logged (D-58).
class SettingsRepository {
  new(this._db, this._clock);

  final AppDatabase _db;

  // Kept so every repository takes (AppDatabase, Clock) and Task 9's backup can
  // build them the same way; settings carry no times.
  // ignore: unused_field
  final Clock _clock;

  static const watchedFoldersKey = 'watchedFolders';
  static const eveningReminderEnabledKey = 'eveningReminderEnabled';
  static const eveningReminderMinutesKey = 'eveningReminderMinutes';

  /// The keys of the user's settings, and the only ones a backup exports.
  ///
  /// The `settings` table will also hold state that belongs to this phone
  /// (Shooting mode, the baselines, from phase 3). Those keys must never be
  /// added here: restoring them on another phone would be wrong.
  static const Set<String> exportedKeys = {
    watchedFoldersKey,
    eveningReminderEnabledKey,
    eveningReminderMinutesKey,
  };

  /// The settings now. A missing or corrupt value is its default.
  Future<AppSettings> load() async => _fromRows(await _selectExported().get());

  /// Writes all three settings in one transaction. Other keys in the table are
  /// left alone. Throws [ArgumentError], saving nothing, when
  /// `eveningReminderMinutes` is not a minute of the day (0 to 1439).
  Future<void> save(AppSettings settings) async {
    if (!_validMinutes(settings.eveningReminderMinutes)) {
      throw ArgumentError.value(
        settings.eveningReminderMinutes,
        'eveningReminderMinutes',
        'must be 0 to 1439',
      );
    }
    await _db.transaction(() async {
      await _put(watchedFoldersKey, settings.watchedFolders);
      await _put(eveningReminderEnabledKey, settings.eveningReminderEnabled);
      await _put(eveningReminderMinutesKey, settings.eveningReminderMinutes);
    });
    _log.info('Saved the settings');
  }

  /// The settings now and each time they change. Writes to other keys, and
  /// saves that change nothing, do not emit.
  Stream<AppSettings> watch() =>
      _selectExported().watch().map(_fromRows).distinct();

  SimpleSelectStatement<$SettingsTable, SettingRow> _selectExported() =>
      _db.select(_db.settings)..where((s) => s.key.isIn(exportedKeys));

  Future<void> _put(String key, Object value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: jsonEncode(value)),
      );

  AppSettings _fromRows(List<SettingRow> rows) {
    final raw = {for (final row in rows) row.key: row.value};
    const defaults = AppSettings();
    return AppSettings(
      watchedFolders:
          _read<List<String>>(raw, watchedFoldersKey, _asStrings) ??
          defaults.watchedFolders,
      eveningReminderEnabled:
          _read<bool>(raw, eveningReminderEnabledKey, _asBool) ??
          defaults.eveningReminderEnabled,
      eveningReminderMinutes:
          _read<int>(raw, eveningReminderMinutesKey, _asMinutes) ??
          defaults.eveningReminderMinutes,
    );
  }

  /// The decoded value of [key], or null when it is missing or corrupt (a
  /// corrupt one is logged by name).
  T? _read<T>(Map<String, String> raw, String key, T? Function(Object?) cast) {
    final text = raw[key];
    if (text == null) return null;
    try {
      final value = cast(jsonDecode(text));
      if (value != null) return value;
    } on FormatException {
      // Not JSON: fall through to the log line.
    }
    _log.warning('Setting $key is corrupt, using its default');
    return null;
  }

  List<String>? _asStrings(Object? value) =>
      value is List && value.every((e) => e is String)
      ? value.cast<String>()
      : null;

  bool? _asBool(Object? value) => value is bool ? value : null;

  int? _asMinutes(Object? value) =>
      value is int && _validMinutes(value) ? value : null;

  bool _validMinutes(int minutes) => minutes >= 0 && minutes < 24 * 60;
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
);
