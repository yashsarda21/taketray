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

  /// Merges [entries] into the timeline in time order, in one transaction.
  /// It is for entries that arrive in any order, such as the native side's
  /// timeline (phase 3): [record] one at a time can drop a later observation
  /// (D-58), and this cannot.
  ///
  /// 1. The whole timeline is read, and [entries] are added to it. Times are
  ///    cut to milliseconds, like the stored ones. An entry at an instant that
  ///    already has one replaces it; for two new entries at one instant the
  ///    later one in iteration order wins.
  /// 2. Everything is sorted by time, and every entry whose zone equals the
  ///    one before it is dropped (it marks no change).
  /// 3. The table is rewritten, unless the result is what it already holds.
  ///
  /// The result never has two neighbours with the same zone, also when the
  /// stored timeline had some. An empty [entries] changes nothing.
  Future<void> recordAll(Iterable<ZoneEntry> entries) async {
    final added = [
      for (final e in entries) (e.at.millisecondsSinceEpoch, e.zoneId),
    ];
    if (added.isEmpty) return;
    final (before, after) = await _db.transaction(() async {
      final stored = await all();
      final byTime = <int, String>{
        for (final e in stored) e.at.millisecondsSinceEpoch: e.zoneId,
      };
      for (final (millis, zoneId) in added) {
        byTime[millis] = zoneId;
      }
      final times = byTime.keys.toList()..sort();
      final merged = <ZoneEntry>[];
      for (final millis in times) {
        final zoneId = byTime[millis]!;
        if (merged.isNotEmpty && merged.last.zoneId == zoneId) continue;
        merged.add(
          ZoneEntry(
            at: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
            zoneId: zoneId,
          ),
        );
      }
      if (!_sameTimeline(merged, stored)) {
        await _db.delete(_db.zoneTimeline).go();
        await _db.batch(
          (b) => b.insertAll(_db.zoneTimeline, [
            for (final e in merged)
              ZoneTimelineCompanion.insert(at: Value(e.at), zoneId: e.zoneId),
          ]),
        );
      }
      return (stored.length, merged.length);
    });
    _log.info(
      'Merged ${added.length} zone entries: $before entries before, '
      '$after after',
    );
  }

  bool _sameTimeline(List<ZoneEntry> a, List<ZoneEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
