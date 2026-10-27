import 'dart:convert';

import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/reference_url.dart';
import 'package:taketray/domain/rules/text_limits.dart';

// The backup file format (spec §8.6, D-59), written out by hand. It is not
// the domain models' `toJson`: those may change with the code, while a
// version of this format must read the same forever. Changing what a
// version-1 file means needs `backupSchemaVersion` 2 and a reader for both.

/// The version of the backup file format this app writes, and the newest it
/// can read.
///
/// It is not the database's `schemaVersion`: a migration upgrades the
/// database on the phone; this number tells an older TakeTray that a file is
/// newer than it understands.
const backupSchemaVersion = 1;

/// The `app` value of every TakeTray backup.
const backupAppName = 'TakeTray';

/// Why a backup file was refused.
enum BackupProblem {
  /// The file is not JSON at all.
  notJson,

  /// The file is JSON, but not a TakeTray backup.
  notTakeTray,

  /// The file was written by a newer TakeTray, in a format this one cannot
  /// read.
  newerVersion,

  /// A TakeTray backup this version can read, but something in it is wrong:
  /// a value of the wrong kind, a link to a row that is not in the file, a
  /// duplicate, or text that breaks a rule.
  invalidData,
}

/// Thrown when a backup file cannot be imported. Nothing was changed.
class BackupException implements Exception {
  const new(this.problem, {this.where});

  final BackupProblem problem;

  /// For [BackupProblem.invalidData], where in the file the problem is, e.g.
  /// `clips[3].source`: a path made of format keys and list positions, never
  /// a value from the file, so it is safe to log (D-10).
  final String? where;

  @override
  String toString() =>
      'BackupException(${problem.name}${where == null ? '' : ' at $where'})';
}

/// Everything a backup holds, as the database rows it becomes.
class BackupData {
  const new({
    required this.reels,
    required this.references,
    required this.clips,
    required this.clipReels,
    required this.inbox,
    required this.settings,
    required this.zoneTimeline,
    this.inboxRowsDropped = 0,
    this.orphanClipsDropped = 0,
    this.referencesDropped = 0,
  });

  final List<ReelRow> reels;
  final List<ReelReferenceRow> references;
  final List<ClipRow> clips;
  final List<ClipReelRow> clipReels;
  final List<InboxRow> inbox;
  final AppSettings settings;
  final List<ZoneTimelineRow> zoneTimeline;

  /// `inbox` rows in the file that [decodeBackup] left out because their clip
  /// is in a reel.
  final int inboxRowsDropped;

  /// Clips in the file that [decodeBackup] left out because they were in no
  /// reel and no list.
  final int orphanClipsDropped;

  /// References in the file that [decodeBackup] left out because a reference
  /// with a lower id on the same reel has the same cleaned link.
  final int referencesDropped;
}

/// Writes [data] as a version-1 backup file: JSON with a 2-space indent and
/// the keys always in the same order.
///
/// Rows are written in the order given; the caller sorts them, so the same
/// database always gives the same file. Times are UTC ISO-8601 with
/// milliseconds and a `Z`.
String encodeBackup(
  BackupData data,
  DateTime exportedAt,
) => const JsonEncoder.withIndent('  ').convert({
  'app': backupAppName,
  'schemaVersion': backupSchemaVersion,
  'exportedAt': _time(exportedAt),
  'reels': [
    for (final r in data.reels)
      {
        'id': r.id,
        'name': r.name,
        'description': r.description,
        'status': r.status.name,
        'createdAt': _time(r.createdAt),
        'updatedAt': _time(r.updatedAt),
      },
  ],
  'references': [
    for (final r in data.references)
      {
        'id': r.id,
        'reelId': r.reelId,
        'url': r.url,
        'source': r.source.name,
        'label': r.label,
        'createdAt': _time(r.createdAt),
      },
  ],
  'clips': [
    for (final c in data.clips)
      {
        'id': c.id,
        'source': c.source.name,
        'mediaStoreId': c.mediaStoreId,
        'volumeName': c.volumeName,
        'pickerUri': c.pickerUri,
        'sizeBytes': c.sizeBytes,
        'durationMs': c.durationMs,
        'dateTakenUtc': _time(c.dateTakenUtc),
        'displayName': c.displayName,
        'width': c.width,
        'height': c.height,
        'mimeType': c.mimeType,
        'timeZoneId': c.timeZoneId,
        'generationAdded': c.generationAdded,
        'firstSeenAt': _time(c.firstSeenAt),
        'missing': c.missing,
        'lastVerifiedAt': _nullableTime(c.lastVerifiedAt),
      },
  ],
  'clipReels': [
    for (final l in data.clipReels)
      {'clipId': l.clipId, 'reelId': l.reelId, 'addedAt': _time(l.addedAt)},
  ],
  'inbox': [
    for (final i in data.inbox)
      {'clipId': i.clipId, 'state': i.state.name, 'addedAt': _time(i.addedAt)},
  ],
  'settings': {
    SettingsRepository.watchedFoldersKey: data.settings.watchedFolders,
    SettingsRepository.eveningReminderEnabledKey:
        data.settings.eveningReminderEnabled,
    SettingsRepository.eveningReminderMinutesKey:
        data.settings.eveningReminderMinutes,
  },
  'zoneTimeline': [
    for (final z in data.zoneTimeline) {'at': _time(z.at), 'zoneId': z.zoneId},
  ],
});

/// Reads a backup file, checking all of it, and returns its rows.
///
/// Throws [BackupException]: [BackupProblem.notJson] when [text] is not JSON,
/// [BackupProblem.notTakeTray] when it is not an object with `app`
/// "TakeTray" and a whole-number `schemaVersion` of at least 1,
/// [BackupProblem.newerVersion] when `schemaVersion` is above
/// [backupSchemaVersion] (checked before anything else is read), and
/// [BackupProblem.invalidData] for anything wrong in the contents.
///
/// Every key of the format must be there, with a value of its kind (`null`
/// only where the format allows it). Keys the format does not know are
/// ignored, so a later version can add fields. Text is stored the way the
/// repositories store it: reel names, descriptions and labels trimmed (a
/// blank description or label is none), links cleaned with
/// `normalizeReferenceUrl`, times cut to whole milliseconds (as the database
/// stores them).
///
/// Three states the app never makes are brought back to its rules instead of
/// refusing the file: of two references of one reel with the same cleaned
/// link, only the one with the lower id is kept; a clip that is in a reel
/// loses its `inbox` row; and a clip in no reel and no list is left out (the
/// orphan rule, D-56). The returned rows are exactly what is stored.
BackupData decodeBackup(String text) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    throw const BackupException(BackupProblem.notJson);
  }
  if (root is! Map<String, Object?> || root['app'] != backupAppName) {
    throw const BackupException(BackupProblem.notTakeTray);
  }
  final version = root['schemaVersion'];
  if (version is! int || version < 1) {
    throw const BackupException(BackupProblem.notTakeTray);
  }
  if (version > backupSchemaVersion) {
    throw const BackupException(BackupProblem.newerVersion);
  }
  try {
    return _readV1(_Fields(root, ''));
  } on _Invalid catch (e) {
    throw BackupException(BackupProblem.invalidData, where: e.where);
  }
}

BackupData _readV1(_Fields file) {
  file.time('exportedAt');

  final reels = <ReelRow>[];
  final reelIds = <int>{};
  for (final r in file.objects('reels')) {
    final id = r.id('id');
    if (!reelIds.add(id)) throw r.invalid('id');
    final name = r.string('name');
    if (checkReelName(name) != null) throw r.invalid('name');
    reels.add(
      ReelRow(
        id: id,
        name: normalizeName(name),
        description: _blankToNull(r.nullableString('description')),
        status: r.choice('status', ReelStatus.values),
        createdAt: r.time('createdAt'),
        updatedAt: r.time('updatedAt'),
      ),
    );
  }

  final references = <ReelReferenceRow>[];
  final referenceIds = <int>{};
  for (final r in file.objects('references')) {
    final id = r.id('id');
    if (!referenceIds.add(id)) throw r.invalid('id');
    final reelId = r.id('reelId');
    if (!reelIds.contains(reelId)) throw r.invalid('reelId');
    final url = normalizeReferenceUrl(r.string('url'))?.toString();
    if (url == null) throw r.invalid('url');
    final label = r.nullableString('label');
    if (checkReferenceLabel(label) != null) throw r.invalid('label');
    references.add(
      ReelReferenceRow(
        id: id,
        reelId: reelId,
        url: url,
        source: r.choice('source', ReferenceSource.values),
        label: _blankToNull(label),
        createdAt: r.time('createdAt'),
      ),
    );
  }

  final clips = <ClipRow>[];
  final clipIds = <int>{};
  final mediaStoreIdentities = <(String, int)>{};
  final pickerUris = <String>{};
  for (final c in file.objects('clips')) {
    final id = c.id('id');
    if (!clipIds.add(id)) throw c.invalid('id');
    final source = c.choice('source', ClipSource.values);
    final mediaStoreId = c.nullableInteger('mediaStoreId');
    final volumeName = c.nullableString('volumeName');
    final pickerUri = c.nullableString('pickerUri');
    // The rules of the `clips` CHECKs and unique keys (D-54, D-57): a clip's
    // identity is never half empty, and no two clips share one.
    switch (source) {
      case ClipSource.mediaStore:
        if (volumeName == null) throw c.invalid('volumeName');
        if (mediaStoreId == null) throw c.invalid('mediaStoreId');
      case ClipSource.picker:
        if (pickerUri == null) throw c.invalid('pickerUri');
    }
    if (volumeName != null &&
        mediaStoreId != null &&
        !mediaStoreIdentities.add((volumeName, mediaStoreId))) {
      throw c.invalid('mediaStoreId');
    }
    if (pickerUri != null && !pickerUris.add(pickerUri)) {
      throw c.invalid('pickerUri');
    }
    clips.add(
      ClipRow(
        id: id,
        source: source,
        mediaStoreId: mediaStoreId,
        volumeName: volumeName,
        pickerUri: pickerUri,
        sizeBytes: c.count('sizeBytes'),
        durationMs: c.count('durationMs'),
        dateTakenUtc: c.time('dateTakenUtc'),
        displayName: c.string('displayName'),
        width: c.count('width'),
        height: c.count('height'),
        mimeType: c.string('mimeType'),
        timeZoneId: c.nullableString('timeZoneId'),
        generationAdded: c.nullableInteger('generationAdded'),
        firstSeenAt: c.time('firstSeenAt'),
        missing: c.boolean('missing'),
        lastVerifiedAt: c.nullableTime('lastVerifiedAt'),
      ),
    );
  }

  final clipReels = <ClipReelRow>[];
  final links = <(int, int)>{};
  for (final l in file.objects('clipReels')) {
    final clipId = l.id('clipId');
    if (!clipIds.contains(clipId)) throw l.invalid('clipId');
    final reelId = l.id('reelId');
    if (!reelIds.contains(reelId)) throw l.invalid('reelId');
    if (!links.add((clipId, reelId))) throw l.invalid('reelId');
    clipReels.add(
      ClipReelRow(clipId: clipId, reelId: reelId, addedAt: l.time('addedAt')),
    );
  }

  final inbox = <InboxRow>[];
  final inboxClipIds = <int>{};
  for (final i in file.objects('inbox')) {
    final clipId = i.id('clipId');
    if (!clipIds.contains(clipId) || !inboxClipIds.add(clipId)) {
      throw i.invalid('clipId');
    }
    inbox.add(
      InboxRow(
        clipId: clipId,
        state: i.choice('state', InboxState.values),
        addedAt: i.time('addedAt'),
      ),
    );
  }

  final zoneTimeline = <ZoneTimelineRow>[];
  final zoneMoments = <DateTime>{};
  for (final z in file.objects('zoneTimeline')) {
    final at = z.time('at');
    if (!zoneMoments.add(at)) throw z.invalid('at');
    zoneTimeline.add(ZoneTimelineRow(at: at, zoneId: z.string('zoneId')));
  }

  final settings = _readSettings(file.object('settings'));

  // A valid file can still describe a state the app never makes (edited by
  // hand, or a slip in some version). Refusing it would leave the user with
  // no restorable backup, and importing it as it is misbehaves later (D-59),
  // so it is brought back to the app's rules:
  // - one reel has one reference per page: of the references whose cleaned
  //   links are the same, the one with the lowest id (the first saved) is
  //   kept, as `ReferencesRepository.add` would have kept it. A file can
  //   hold such a pair when a later version cleans links differently (D-55);
  // - a clip in a reel is not also in To tag or Skipped: the link wins, as
  //   in `tagClip` and `addClipsToReel` (D-57);
  // - a clip in no reel and no list is left out, the rule of
  //   `deleteOrphanClips` (D-56). Only `clip_reels` and `inbox` name clips,
  //   so nothing else points at it.
  final firstSaved = <(int, String), ReelReferenceRow>{};
  for (final r in references) {
    final kept = firstSaved[(r.reelId, r.url)];
    if (kept == null || r.id < kept.id) firstSaved[(r.reelId, r.url)] = r;
  }
  final keptReferences = [
    for (final r in references)
      if (identical(firstSaved[(r.reelId, r.url)], r)) r,
  ];

  final linked = {for (final l in clipReels) l.clipId};
  final keptInbox = [
    for (final i in inbox)
      if (!linked.contains(i.clipId)) i,
  ];
  final placed = {...linked, for (final i in keptInbox) i.clipId};
  final keptClips = [
    for (final c in clips)
      if (placed.contains(c.id)) c,
  ];

  return BackupData(
    reels: reels,
    references: keptReferences,
    clips: keptClips,
    clipReels: clipReels,
    inbox: keptInbox,
    settings: settings,
    zoneTimeline: zoneTimeline,
    inboxRowsDropped: inbox.length - keptInbox.length,
    orphanClipsDropped: clips.length - keptClips.length,
    referencesDropped: references.length - keptReferences.length,
  );
}

AppSettings _readSettings(_Fields s) {
  const foldersKey = SettingsRepository.watchedFoldersKey;
  const minutesKey = SettingsRepository.eveningReminderMinutesKey;
  final folders = s.value<List<Object?>>(foldersKey);
  if (!folders.every((f) => f is String)) throw s.invalid(foldersKey);
  final minutes = s.integer(minutesKey);
  if (minutes < 0 || minutes >= Duration.minutesPerDay) {
    throw s.invalid(minutesKey);
  }
  return AppSettings(
    watchedFolders: List<String>.from(folders),
    eveningReminderEnabled: s.boolean(
      SettingsRepository.eveningReminderEnabledKey,
    ),
    eveningReminderMinutes: minutes,
  );
}

String? _blankToNull(String? text) {
  if (text == null) return null;
  final trimmed = normalizeName(text);
  return trimmed.isEmpty ? null : trimmed;
}

/// [instant] as UTC ISO-8601 with exactly three fraction digits and a `Z`.
/// Microseconds (the real clock has them) are dropped, as the database drops
/// them.
String _time(DateTime instant) => DateTime.fromMillisecondsSinceEpoch(
  instant.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

String? _nullableTime(DateTime? instant) =>
    instant == null ? null : _time(instant);

/// A date and time with seconds, an optional fraction, and a `Z` or an
/// explicit offset (D-55: a time without one is never guessed to be UTC).
///
/// The year is written the way `DateTime.toIso8601String` writes it: four
/// digits for 0 to 9999, `-0001` for a year before 0 down to -9999, and a
/// sign with six digits beyond that (`+010001`, `-271821`). A video's date
/// comes from its file and can be any of these.
final _instant = RegExp(
  r'^([+-]\d{6}|-?\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?'
  r'(?:Z|[+-](\d{2}):?(\d{2}))$',
);

/// [text] as a UTC instant cut to whole milliseconds (what the database
/// stores, so two times that would be stored the same compare equal), or null
/// when it is not an [_instant], names a date or time that does not exist
/// (`DateTime.parse` would roll 30 February over into March), or lies outside
/// what a `DateTime` can hold (about 271,821 BC to AD 275,760).
DateTime? _parseInstant(String text) {
  final match = _instant.firstMatch(text);
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (var g = 1; g <= 6; g++) int.parse(match.group(g)!),
  ];
  final offsetHours = int.parse(match.group(7) ?? '0');
  final offsetMinutes = int.parse(match.group(8) ?? '0');
  final DateTime asWritten;
  final DateTime instant;
  try {
    asWritten = DateTime.utc(year, month, day, hour, minute, second);
    instant = DateTime.parse(text);
  } on Object {
    // Past the last instant a DateTime can hold (`ArgumentError` or
    // `FormatException`, depending on which side of the offset it falls).
    return null;
  }
  // The date must be the one written. A year far past the range does not
  // always throw: it can wrap around to another date (`+999999` becomes a
  // day in 169110 BC), which this comparison also refuses.
  if (asWritten.year != year ||
      asWritten.month != month ||
      asWritten.day != day ||
      asWritten.hour != hour ||
      asWritten.minute != minute ||
      asWritten.second != second ||
      offsetHours > 23 ||
      offsetMinutes > 59) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    instant.millisecondsSinceEpoch,
    isUtc: true,
  );
}

/// The largest id a file may hold, far above any real database. SQLite's
/// own limit is 2^63 - 1, and once a table's `AUTOINCREMENT` counter reaches
/// it, every new row in that table fails ("database or disk is full") until
/// the next import; a hand-edited id near it must not do that.
const int _maxId = 1 << 53;

/// A problem in the file at [where]; turned into [BackupException].
class _Invalid implements Exception {
  const new(this.where);

  final String where;
}

/// One JSON object of the file, with typed getters that throw [_Invalid]
/// naming the key when it is missing or has the wrong kind of value.
class _Fields {
  const new(this._map, this._path);

  final Map<String, Object?> _map;

  /// Where this object is in the file, e.g. `clips[3]`; empty for the root.
  final String _path;

  _Invalid invalid(String key) => _Invalid(_path.isEmpty ? key : '$_path.$key');

  /// The value of [key], which must be present and a [T] (`T?` allows null).
  T value<T>(String key) {
    if (!_map.containsKey(key)) throw invalid(key);
    final v = _map[key];
    if (v is! T) throw invalid(key);
    return v;
  }

  int integer(String key) => value<int>(key);

  int? nullableInteger(String key) => value<int?>(key);

  /// A size, length or count: a whole number of at least 0.
  int count(String key) {
    final v = integer(key);
    if (v < 0) throw invalid(key);
    return v;
  }

  /// A database id: a whole number from 1 to [_maxId].
  int id(String key) {
    final v = integer(key);
    if (v < 1 || v > _maxId) throw invalid(key);
    return v;
  }

  String string(String key) => value<String>(key);

  String? nullableString(String key) => value<String?>(key);

  bool boolean(String key) => value<bool>(key);

  T choice<T extends Enum>(String key, List<T> values) =>
      values.asNameMap()[string(key)] ?? (throw invalid(key));

  DateTime time(String key) =>
      _parseInstant(string(key)) ?? (throw invalid(key));

  DateTime? nullableTime(String key) {
    final text = nullableString(key);
    if (text == null) return null;
    return _parseInstant(text) ?? (throw invalid(key));
  }

  _Fields object(String key) {
    final v = value<Map<String, Object?>>(key);
    return _Fields(v, _path.isEmpty ? key : '$_path.$key');
  }

  /// The list at [key], each item of which must be an object.
  List<_Fields> objects(String key) {
    final list = value<List<Object?>>(key);
    final at = _path.isEmpty ? key : '$_path.$key';
    return [
      for (final (i, item) in list.indexed)
        if (item is Map<String, Object?>)
          _Fields(item, '$at[$i]')
        else
          throw _Invalid('$at[$i]'),
    ];
  }
}
