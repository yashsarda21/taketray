import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/zone_lookup.dart' as rules;

part 'zone_repository.g.dart';

// Counts only (D-10).
final Logger _log = Logger('zones');

/// The zone timeline (spec §8.3a): "from this moment on, the phone was in this
/// time zone". It answers "which zone was the phone in when this clip was
/// shot?" so the clip viewer can show "London time".
///
/// From phase 3 the native side also appends to this table; this class is the
/// Dart side of the same rule.
class ZoneRepository {
  new(this._db, this._clock);

  final AppDatabase _db;

  // Kept so every repository takes (AppDatabase, Clock); instants are passed
  // in.
  // ignore: unused_field
  final Clock _clock;

  /// Notes that the phone was in [zoneId] at [at]. Does nothing when that is
  /// already the zone in effect at [at] (the last entry at or before it), so
  /// repeating the current zone never grows the timeline.
  ///
  /// An entry at exactly [at] with another zone is replaced.
  Future<void> record(DateTime at, String zoneId) async {
    final recorded = await _db.transaction(() async {
      final inEffect =
          await (_db.select(_db.zoneTimeline)
                ..where(
                  (e) => e.at.isSmallerOrEqualValue(at.millisecondsSinceEpoch),
                )
                ..orderBy([(e) => OrderingTerm.desc(e.at)])
                ..limit(1))
              .getSingleOrNull();
      if (inEffect?.zoneId == zoneId) return false;
      await _db
          .into(_db.zoneTimeline)
          .insertOnConflictUpdate(
            ZoneTimelineCompanion.insert(at: Value(at), zoneId: zoneId),
          );
      return true;
    });
    _log.info(recorded ? 'Recorded a time zone change' : 'Zone unchanged');
  }

  /// The zone the phone was in at [instant], or null when [instant] is before
  /// the first entry (or there are none).
  Future<String?> zoneAt(DateTime instant) async =>
      rules.zoneAt(await all(), instant);

  /// The whole timeline, oldest first.
  Future<List<ZoneEntry>> all() async {
    final rows = await (_db.select(
      _db.zoneTimeline,
    )..orderBy([(e) => OrderingTerm.asc(e.at)])).get();
    return [for (final row in rows) ZoneEntry(at: row.at, zoneId: row.zoneId)];
  }
}

@Riverpod(keepAlive: true)
ZoneRepository zoneRepository(Ref ref) =>
    ZoneRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
