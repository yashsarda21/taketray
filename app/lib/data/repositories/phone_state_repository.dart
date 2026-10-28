import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/media.dart';

part 'phone_state_repository.g.dart';

// Counts only. A key's name may be logged, its value never: a MediaStore
// version, a volume's baseline or a time says nothing the log needs (D-10).
final Logger _log = Logger('phoneState');

/// What belongs to this phone, not to the user: whether Shooting mode is on,
/// where each volume stood when it was switched on, and whether the app ever
/// had full access to the videos.
///
/// It lives in the `settings` table under two keys, `shootingMode` and
/// `mediaAccessWasFull`. Neither is in `SettingsRepository.exportedKeys`, so a
/// backup never holds them, and an import deletes them (D-71): after a restore
/// Shooting mode is off, because the baselines belong to the phone's own media
/// library.
///
/// `shootingMode` holds the whole [ShootingState] as one JSON value, so
/// switching on, the start time and the baselines change together or not at
/// all. A missing or unreadable value is [ShootingState.off]; only the key's
/// name is logged.
class PhoneStateRepository {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static const shootingModeKey = 'shootingMode';
  static const mediaAccessWasFullKey = 'mediaAccessWasFull';

  /// Shooting mode now. A missing or corrupt value is [ShootingState.off].
  Future<ShootingState> loadShooting() async =>
      _parseShooting(await _rawValue(shootingModeKey));

  /// Shooting mode now and each time it changes. Writes to other keys, and
  /// writes that change nothing, do not emit.
  Stream<ShootingState> watchShooting() =>
      (_db.select(_db.settings)..where((s) => s.key.equals(shootingModeKey)))
          .watchSingleOrNull()
          .map((row) => _parseShooting(row?.value))
          .distinct();

  /// Switches Shooting mode on: `since` is now, [baselines] are the volumes'
  /// positions (by volume name) and `earlierAdded` is false.
  ///
  /// If Shooting mode is already on, nothing is written and the current state
  /// is returned: the first `since`, baselines and `earlierAdded` stay, so a
  /// second tap (or a second caller) cannot move the start of the session.
  Future<ShootingState> turnShootingOn(
    Map<String, VolumeBaseline> baselines,
  ) async {
    final (state, started) = await _db.transaction(() async {
      final current = await loadShooting();
      if (current.on) return (current, false);
      final state = ShootingState(
        on: true,
        since: _clock.now(),
        baselines: Map.unmodifiable(baselines),
      );
      await _putShooting(state);
      return (state, true);
    });
    _log.info(
      started
          ? 'Shooting mode on, ${baselines.length} volumes'
          : 'Shooting mode was already on',
    );
    return state;
  }

  /// Switches Shooting mode off and forgets the baselines and the start time.
  Future<void> turnShootingOff() async {
    await (_db.delete(
      _db.settings,
    )..where((s) => s.key.equals(shootingModeKey))).go();
    _log.info('Shooting mode off');
  }

  /// Moves [volume]'s baseline to [next], only if nothing changed since the
  /// caller read the state (compare-and-set, D-71). Returns whether it wrote.
  ///
  /// All of this is checked and written in one transaction, so two scans can
  /// never both pass the checks:
  /// - Shooting mode is on, and its `since` is the one in [expectedSession]
  ///   (a scan that started before an off and on must not write the new
  ///   session's baseline);
  /// - the stored baseline of [volume] equals [expected] (null: none stored);
  /// - when [expected] and [next] have the same version, `next.generation` is
  ///   not below `expected.generation` (a baseline never moves backwards). A
  ///   different version is a resync, whose generations start over, so any
  ///   generation may be written then.
  ///
  /// Other volumes and `earlierAdded` are kept.
  Future<bool> advanceBaseline(
    String volume, {
    required ShootingState expectedSession,
    required VolumeBaseline? expected,
    required VolumeBaseline next,
  }) async {
    final wrote = await _db.transaction(() async {
      final since = expectedSession.since;
      if (!expectedSession.on || since == null) return false;
      final current = await loadShooting();
      final currentSince = current.since;
      if (!current.on ||
          currentSince == null ||
          !currentSince.isAtSameMomentAs(since)) {
        return false;
      }
      if (current.baselines[volume] != expected) return false;
      if (expected != null &&
          expected.version == next.version &&
          next.generation < expected.generation) {
        return false;
      }
      await _putShooting(
        current.copyWith(baselines: {...current.baselines, volume: next}),
      );
      return true;
    });
    _log.info(wrote ? 'Moved a baseline' : 'Left the baseline: it had changed');
    return wrote;
  }

  /// Whether TakeTray ever saw full access to the videos on this phone.
  /// Unreadable counts as no.
  Future<bool> accessWasFull() async {
    final text = await _rawValue(mediaAccessWasFullKey);
    if (text == null) return false;
    try {
      final value = jsonDecode(text);
      if (value is bool) return value;
    } on FormatException {
      // Not JSON: fall through to the log line.
    }
    _log.warning('Setting $mediaAccessWasFullKey is corrupt, reading it as no');
    return false;
  }

  /// Remembers that full access was seen. It is never cleared by Shooting
  /// mode going off.
  Future<void> markAccessWasFull() async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: mediaAccessWasFullKey,
            value: jsonEncode(true),
          ),
        );
    _log.info('Marked that access was full');
  }

  /// Notes that "Add earlier videos" was used in this Shooting session.
  /// Does nothing when Shooting mode is off. A new session starts with it
  /// false again ([turnShootingOn]).
  Future<void> markEarlierAdded() async {
    final wrote = await _db.transaction(() async {
      final current = await loadShooting();
      if (!current.on || current.earlierAdded) return false;
      await _putShooting(current.copyWith(earlierAdded: true));
      return true;
    });
    _log.info(wrote ? 'Marked earlier videos added' : 'Earlier mark unchanged');
  }

  Future<String?> _rawValue(String key) async => (await (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _putShooting(ShootingState state) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: shootingModeKey,
          value: jsonEncode(state.toJson()),
        ),
      );

  /// The state in [text], or [ShootingState.off] when there is none or it
  /// cannot be read (logged by key name only). A state that says "on" without
  /// a start time is unreadable too: nothing could be compared with it.
  ShootingState _parseShooting(String? text) {
    if (text == null) return ShootingState.off;
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        final state = ShootingState.fromJson(json);
        if (!state.on) return ShootingState.off;
        if (state.since != null) return state;
      }
    } on FormatException {
      // Not JSON, or a date that is not a date: fall through.
      // ignore: avoid_catching_errors
    } on TypeError {
      // json_serializable's generated `fromJson` signals JSON of the wrong
      // shape with a cast error, and a number too big for a double (1e400 is
      // Infinity) with `UnsupportedError` from `toInt`. There is no other way
      // to ask "is this readable?", so both are caught: fall through.
      // ignore: avoid_catching_errors
    } on UnsupportedError {
      // See above.
    }
    _log.warning('Setting $shootingModeKey is corrupt, reading it as off');
    return ShootingState.off;
  }
}

@Riverpod(keepAlive: true)
PhoneStateRepository phoneStateRepository(Ref ref) => PhoneStateRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
);
