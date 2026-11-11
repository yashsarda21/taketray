import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/rematch_window.dart';

part 'phone_state_repository.g.dart';

// Counts only. A key's name may be logged, its value never: a MediaStore
// version, a volume's baseline or a time says nothing the log needs (D-10).
final Logger _log = Logger('phoneState');

/// What belongs to this phone, not to the user: whether Shooting mode is on,
/// where each volume stood when it was switched on, whether the app ever had
/// full access to the videos, whether it ever asked for the notification
/// permission, which rebuilt volumes have clips to match again, and whether
/// Add videos' folder tip was dismissed.
///
/// It lives in the `settings` table under six keys, `shootingMode`,
/// `mediaAccessWasFull`, `mediaVolumeVersions`, `notificationsAsked`,
/// `mediaRematchWindows` and `folderTipSeen`. None is in
/// `SettingsRepository.exportedKeys`, so a backup never holds them, and an
/// import deletes them (D-71, D-72, D-108):
/// after a restore Shooting mode is off, and no volume version or re-match
/// window is known, because they belong to the phone's own media library.
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
  static const volumeVersionsKey = 'mediaVolumeVersions';
  static const notificationsAskedKey = 'notificationsAsked';
  static const rematchWindowsKey = 'mediaRematchWindows';
  static const folderTipSeenKey = 'folderTipSeen';

  /// The MediaStore version last seen for each volume, by volume name: the
  /// version the stored clips' numbers belong to (D-72, Ruling V). Kept
  /// whether Shooting mode is on or off; a missing or unreadable value is
  /// empty (only the key's name is logged, never a version).
  Future<Map<String, String>> volumeVersions() async {
    final text = await _rawValue(volumeVersionsKey);
    if (text == null) return const {};
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic> &&
          json.values.every((v) => v is String)) {
        return json.cast<String, String>();
      }
    } on FormatException {
      // Not JSON: fall through to the log line.
    }
    _log.warning('Setting $volumeVersionsKey is corrupt, reading it as none');
    return const {};
  }

  /// Remembers that the stored clips of [volume] now belong to [version].
  /// Other volumes are kept; an unreadable value is replaced.
  Future<void> recordVolumeVersion(String volume, String version) async {
    final changed = await _db.transaction(() async {
      final current = await volumeVersions();
      if (current[volume] == version) return false;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: volumeVersionsKey,
              value: jsonEncode({...current, volume: version}),
            ),
          );
      return true;
    });
    if (changed) _log.info('Recorded the version of volume $volume');
  }

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
  /// positions (by volume name).
  ///
  /// If Shooting mode is already on, nothing is written and the current state
  /// is returned: the first `since` and the baselines stay, so a second tap
  /// (or a second caller) cannot move the start of the session.
  Future<ShootingState> turnShootingOn(
    Map<String, VolumeBaseline> baselines,
  ) async {
    final (state, started) = await _db.transaction(() async {
      final current = await loadShooting();
      if (current.on) return (current, false);
      final state = ShootingState(
        on: true,
        // Not `storedNow`: this goes into JSON, which keeps the microseconds,
        // so the value read back equals this one.
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

  /// Switches Shooting mode off and forgets the baselines, the start time and
  /// the Still shooting? answer.
  Future<void> turnShootingOff() async {
    await _deleteShooting();
    _log.info('Shooting mode off');
  }

  Future<void> _deleteShooting() => (_db.delete(
    _db.settings,
  )..where((s) => s.key.equals(shootingModeKey))).go();

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
  ///   generation may be written then. So may one under the same version
  ///   when [rebuilt] is true: the scanner resynced the volume because its
  ///   generation went backwards (D-70), and the old numbers mean nothing.
  ///
  /// Other volumes are kept.
  Future<bool> advanceBaseline(
    String volume, {
    required ShootingState expectedSession,
    required VolumeBaseline? expected,
    required VolumeBaseline next,
    bool rebuilt = false,
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
      if (!rebuilt &&
          expected != null &&
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

  /// Remembers that "Still shooting?" was answered with Keep on, only in the
  /// session that started at [since] (compare-and-set, D-106; compared to the
  /// millisecond, [ShootingState.isSession]). Returns whether it wrote:
  /// false when Shooting mode is off, in another session, or already
  /// answered. The baselines and the start time are kept.
  Future<bool> markStillAnswered(DateTime since) async {
    final wrote = await _db.transaction(() async {
      final current = await loadShooting();
      if (!current.isSession(since) || current.stillAnswered) return false;
      await _putShooting(current.copyWith(stillAnswered: true));
      return true;
    });
    _log.info(
      wrote
          ? 'Still shooting? answered: keep on'
          : 'Still shooting? answer not stored: another session, or already '
                'answered',
    );
    return wrote;
  }

  /// Switches Shooting mode off, as [turnShootingOff] does, only if it is on
  /// in the session that started at [since] (compare-and-set, D-106). Returns
  /// whether it did. A session switched off and on again meanwhile is never
  /// ended by an older request.
  Future<bool> endSession(DateTime since) async {
    final ended = await _db.transaction(() async {
      if (!(await loadShooting()).isSession(since)) return false;
      await _deleteShooting();
      return true;
    });
    _log.info(
      ended
          ? 'Shooting mode off (session ended)'
          : 'Session not ended: changed',
    );
    return ended;
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

  /// Whether TakeTray ever asked for the notification permission on this
  /// phone (D-107): it asks once, the first time Shooting mode is turned on.
  /// Unreadable counts as no.
  Future<bool> notificationsAsked() async {
    final text = await _rawValue(notificationsAskedKey);
    if (text == null) return false;
    try {
      final value = jsonDecode(text);
      if (value is bool) return value;
    } on FormatException {
      // Not JSON: fall through to the log line.
    }
    _log.warning('Setting $notificationsAskedKey is corrupt, reading it as no');
    return false;
  }

  /// Remembers that the permission was asked for. It is never cleared by
  /// Shooting mode going off.
  Future<void> markNotificationsAsked() async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: notificationsAskedKey,
            value: jsonEncode(true),
          ),
        );
    _log.info('Marked that notifications were asked for');
  }

  /// Whether the user dismissed Add videos' tip "Keep friends' clips sharp"
  /// with **Got it** on this phone (D-114). Unreadable counts as no.
  Future<bool> folderTipSeen() async {
    final text = await _rawValue(folderTipSeenKey);
    if (text == null) return false;
    try {
      final value = jsonDecode(text);
      if (value is bool) return value;
    } on FormatException {
      // Not JSON: fall through to the log line.
    }
    _log.warning('Setting $folderTipSeenKey is corrupt, reading it as no');
    return false;
  }

  /// Remembers that the tip was dismissed, so it never shows again.
  Future<void> markFolderTipSeen() async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: folderTipSeenKey,
            value: jsonEncode(true),
          ),
        );
    _log.info('Marked the folder tip as seen');
  }

  /// The re-match window open on [volume], or null when there is none
  /// (D-108). Whether it is still open at a given time is the caller's
  /// question ([RematchWindow.isOpenAt]). A missing value is none; an
  /// unreadable one is none for every volume (only the key's name is
  /// logged) and is removed, so it is logged once and not at every scan.
  Future<RematchWindow?> rematchWindow(String volume) async {
    final windows = await _readRematchWindows();
    if (windows == null) {
      await _dropCorruptRematchWindows();
      return null;
    }
    return windows[volume];
  }

  /// Opens a re-match window on [volume] at [at] for [clipIds], the clips a
  /// rebuild resync just detached, last matched at [generation] (D-108).
  ///
  /// A window still open at [at] (a second rebuild within the day) keeps its
  /// clips: the new one has both, and its 24 hours start at [at]. A window
  /// that has ended is replaced. Other volumes are kept; an unreadable value
  /// is replaced.
  Future<void> openRematchWindow(
    String volume, {
    required Set<int> clipIds,
    required int generation,
    required DateTime at,
  }) async {
    final count = await _db.transaction(() async {
      final windows = await _rematchWindows();
      final old = windows[volume];
      final window = RematchWindow(
        openedAt: at.toUtc(),
        clipIds: {
          if (old != null && old.isOpenAt(at)) ...old.clipIds,
          ...clipIds,
        },
        generation: generation,
      );
      await _putRematchWindows({...windows, volume: window});
      return window.clipIds.length;
    });
    _log.info('Opened a re-match window on volume $volume for $count clips');
  }

  /// Notes that [volume] was matched again at [generation]. Nothing is
  /// written when no window is stored for it.
  Future<void> recordRematch(String volume, int generation) async {
    await _db.transaction(() async {
      final windows = await _rematchWindows();
      final old = windows[volume];
      if (old == null) return;
      await _putRematchWindows({
        ...windows,
        volume: RematchWindow(
          openedAt: old.openedAt,
          clipIds: old.clipIds,
          generation: generation,
        ),
      });
    });
  }

  /// Removes [volume]'s re-match window, if any. The key goes with the last
  /// one.
  Future<void> closeRematchWindow(String volume) async {
    final closed = await _db.transaction(() async {
      final windows = await _rematchWindows();
      if (!windows.containsKey(volume)) return false;
      await _putRematchWindows({...windows}..remove(volume));
      return true;
    });
    if (closed) _log.info('Closed the re-match window on volume $volume');
  }

  /// Every stored window, by volume name, for a write. Unreadable: none,
  /// logged by key (the write replaces it).
  Future<Map<String, RematchWindow>> _rematchWindows() async {
    final windows = await _readRematchWindows();
    if (windows != null) return windows;
    _log.warning('Setting $rematchWindowsKey is corrupt, reading it as none');
    return const {};
  }

  /// Every stored window, by volume name; none stored is empty; null when the
  /// value is unreadable (not JSON, or any entry of the wrong shape).
  Future<Map<String, RematchWindow>?> _readRematchWindows() async {
    final text = await _rawValue(rematchWindowsKey);
    if (text == null) return const {};
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        final windows = <String, RematchWindow>{};
        for (final MapEntry(:key, :value) in json.entries) {
          final window = _parseWindow(value);
          if (window == null) break;
          windows[key] = window;
        }
        if (windows.length == json.length) return windows;
      }
    } on FormatException {
      // Not JSON: unreadable.
    }
    return null;
  }

  /// Removes an unreadable value after logging it once, if it is still
  /// unreadable inside the transaction (a write may have replaced it).
  Future<void> _dropCorruptRematchWindows() async {
    await _db.transaction(() async {
      if (await _readRematchWindows() != null) return;
      _log.warning(
        'Setting $rematchWindowsKey is corrupt, reading it as none and '
        'removing it',
      );
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(rematchWindowsKey))).go();
    });
  }

  static RematchWindow? _parseWindow(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final openedAtMs = json['openedAtMs'];
    final clipIds = json['clipIds'];
    final generation = json['generation'];
    if (openedAtMs is! int ||
        generation is! int ||
        clipIds is! List<dynamic> ||
        !clipIds.every((id) => id is int) ||
        openedAtMs.abs() > _maxEpochMs) {
      return null;
    }
    return RematchWindow(
      openedAt: DateTime.fromMillisecondsSinceEpoch(openedAtMs, isUtc: true),
      clipIds: clipIds.cast<int>().toSet(),
      generation: generation,
    );
  }

  /// The largest time `DateTime` can hold, in milliseconds either side of
  /// 1970.
  static const _maxEpochMs = 8640000000000000;

  Future<void> _putRematchWindows(Map<String, RematchWindow> windows) async {
    if (windows.isEmpty) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(rematchWindowsKey))).go();
      return;
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: rematchWindowsKey,
            value: jsonEncode({
              for (final MapEntry(:key, :value) in windows.entries)
                key: {
                  'openedAtMs': value.openedAt.millisecondsSinceEpoch,
                  'clipIds': (value.clipIds.toList()..sort()),
                  'generation': value.generation,
                },
            }),
          ),
        );
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
