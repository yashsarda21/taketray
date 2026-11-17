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
/// treated as missing, and its key name is logged, once per key (D-58).
class SettingsRepository {
  // Takes a Clock like every repository, but settings carry no times.
  new(this._db, Clock _);

  final AppDatabase _db;

  /// The keys whose corrupt value was already logged by this repository.
  final Set<String> _warned = {};

  static const watchedFoldersKey = 'watchedFolders';
  static const eveningReminderEnabledKey = 'eveningReminderEnabled';
  static const eveningReminderMinutesKey = 'eveningReminderMinutes';
  static const stillReminderEnabledKey = 'stillReminderEnabled';
  static const copiesReminderEnabledKey = 'copiesReminderEnabled';

  /// The keys of the user's settings, and the only ones a backup exports.
  ///
  /// The `settings` table also holds state that belongs to this phone
  /// (`PhoneStateRepository`: Shooting mode, the baselines, whether access was
  /// full). Those keys must never be added here: restoring them on another
  /// phone would be wrong (D-71).
  static const Set<String> exportedKeys = {
    watchedFoldersKey,
    eveningReminderEnabledKey,
    eveningReminderMinutesKey,
    stillReminderEnabledKey,
    copiesReminderEnabledKey,
  };

  /// The settings now. A missing or corrupt value is its default.
  Future<AppSettings> load() async => _fromRows(await _selectExported().get());

  /// Writes all five settings in one transaction. Other keys in the table are
  /// left alone. Throws [ArgumentError], saving nothing, when
  /// `eveningReminderMinutes` is not a minute of the day (0 to 1439).
  ///
  /// It writes every key from [settings] as it is, so a caller that read the
  /// settings earlier can undo a change made since. A change of some of the
  /// settings should go through [update].
  Future<void> save(AppSettings settings) async {
    _validate(settings);
    await _db.transaction(() => _write(settings));
    _log.info('Saved the settings');
  }

  /// Reads the stored settings, applies [change] to them and saves the
  /// result, all in **one database transaction**, and answers what it saved
  /// (D-149, ruling R3).
  ///
  /// Two updates never overlap, however many repositories or screens make
  /// them: the second waits for the first to commit and then reads what the
  /// first saved. So a folder turned on in Watched folders and a switch
  /// turned off in Settings, in the same frame, both stay, which neither
  /// could promise with `load` then `save`.
  ///
  /// [change] runs inside the transaction and must be quick and must not
  /// await anything else (a transaction holds the database). If it throws, or
  /// gives a value [save] would refuse (a time that is not a minute of the
  /// day: [ArgumentError]), nothing is saved and the error reaches the
  /// caller; the updates after it still run.
  Future<AppSettings> update(
    AppSettings Function(AppSettings current) change,
  ) async {
    final saved = await _db.transaction(() async {
      final next = change(_fromRows(await _selectExported().get()));
      _validate(next);
      await _write(next);
      return next;
    });
    _log.info('Saved the settings');
    return saved;
  }

  void _validate(AppSettings settings) {
    if (!_validMinutes(settings.eveningReminderMinutes)) {
      throw ArgumentError.value(
        settings.eveningReminderMinutes,
        'eveningReminderMinutes',
        'must be 0 to 1439',
      );
    }
  }

  Future<void> _write(AppSettings settings) async {
    await _put(watchedFoldersKey, settings.watchedFolders);
    await _put(eveningReminderEnabledKey, settings.eveningReminderEnabled);
    await _put(eveningReminderMinutesKey, settings.eveningReminderMinutes);
    await _put(stillReminderEnabledKey, settings.stillReminderEnabled);
    await _put(copiesReminderEnabledKey, settings.copiesReminderEnabled);
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
      stillReminderEnabled:
          _read<bool>(raw, stillReminderEnabledKey, _asBool) ??
          defaults.stillReminderEnabled,
      copiesReminderEnabled:
          _read<bool>(raw, copiesReminderEnabledKey, _asBool) ??
          defaults.copiesReminderEnabled,
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
    // `watch` reads every row again on each change, so a corrupt row would be
    // logged on every emission: once per key per repository is enough.
    if (_warned.add(key)) {
      _log.warning('Setting $key is corrupt, using its default');
    }
    return null;
  }

  List<String>? _asStrings(Object? value) =>
      value is List && value.every((e) => e is String)
      ? List<String>.from(value)
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
