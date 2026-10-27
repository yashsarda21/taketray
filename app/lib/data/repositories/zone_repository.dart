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
  // Takes a Clock like every repository, but instants are passed in.
  new(this._db, Clock _);

  final AppDatabase _db;

  /// Notes that the phone was in [zoneId] at [at]. Does nothing when that is
  /// already the zone in effect at [at] (the last entry at or before it), so
  /// repeating the current zone never grows the timeline.
  ///
  /// The timeline never holds two neighbours with the same zone: an entry at
  /// exactly [at] with another zone is replaced, the replacement is dropped
  /// when the entry before it has [zoneId], and the entry after [at] is
  /// deleted when it has [zoneId] (it no longer marks a change). So recording
  /// London at the 8th between Kolkata (5th) and London (12th) leaves
  /// Kolkata (5th), London (8th).
  Future<void> record(DateTime at, String zoneId) async {
    final millis = at.millisecondsSinceEpoch;
    final recorded = await _db.transaction(() async {
      final inEffect =
          await (_db.select(_db.zoneTimeline)
                ..where((e) => e.at.isSmallerOrEqualValue(millis))
                ..orderBy([(e) => OrderingTerm.desc(e.at)])
                ..limit(1))
              .getSingleOrNull();
      if (inEffect?.zoneId == zoneId) return false;

      final before =
          await (_db.select(_db.zoneTimeline)
                ..where((e) => e.at.isSmallerThanValue(millis))
                ..orderBy([(e) => OrderingTerm.desc(e.at)])
                ..limit(1))
              .getSingleOrNull();
      if (before?.zoneId == zoneId) {
        // Only reached when an entry at [at] has another zone: it goes.
        await (_db.delete(
          _db.zoneTimeline,
        )..where((e) => e.at.equalsValue(at))).go();
      } else {
        await _db
            .into(_db.zoneTimeline)
            .insertOnConflictUpdate(
              ZoneTimelineCompanion.insert(at: Value(at), zoneId: zoneId),
            );
      }

      final after =
          await (_db.select(_db.zoneTimeline)
                ..where((e) => e.at.isBiggerThanValue(millis))
                ..orderBy([(e) => OrderingTerm.asc(e.at)])
                ..limit(1))
              .getSingleOrNull();
      if (after?.zoneId == zoneId) {
        await (_db.delete(
          _db.zoneTimeline,
        )..where((e) => e.at.equalsValue(after!.at))).go();
      }
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
