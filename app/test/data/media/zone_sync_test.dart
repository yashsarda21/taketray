import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/zone_sync.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/fake_media_bridge.dart';
import '../../support/test_database.dart';
import 'media_harness.dart';

/// A zone repository whose `recordAll` fails like a full disk.
class _FailingZones extends ZoneRepository {
  _FailingZones(super._db, super._);

  @override
  Future<void> recordAll(Iterable<ZoneEntry> entries) async =>
      throw StateError('database is full');
}

ZoneEntry entry(DateTime at, String zoneId) =>
    ZoneEntry(at: at, zoneId: zoneId);

MediaHarness? _built;

/// Built on first use, so a test that makes its own harness never has two
/// databases open.
MediaHarness get h => _built ??= MediaHarness();

ZoneSync get sync => ZoneSync(h.bridge, h.zones, h.clock);

void main() {
  final t1 = DateTime.utc(2026, 5, 20, 8);
  final t2 = DateTime.utc(2026, 5, 25, 8);

  setUp(() => _built = null);

  test('merges native changes then clears', () async {
    h.bridge
      // Out of order, as a list could arrive.
      ..zoneChanges = [entry(t2, 'Europe/London'), entry(t1, 'Europe/Paris')]
      ..currentZone = 'Europe/London';

    await sync.sync();

    expect(await h.zones.all(), [
      entry(t1, 'Europe/Paris'),
      entry(t2, 'Europe/London'),
    ]);
    // Up to the newest native entry, not to now.
    expect(h.bridge.clearedUpTo, [t2.millisecondsSinceEpoch]);
    expect(h.bridge.zoneChanges, isEmpty);
    final recordedAt = h.bridge.calls.indexOf('clearZoneChangesUpTo');
    expect(recordedAt, h.bridge.calls.length - 1, reason: 'clear comes last');
  });

  test('current zone recorded at now', () async {
    h.bridge.currentZone = 'Asia/Kolkata';

    await sync.sync();

    expect(await h.zones.all(), [entry(h.clock.now(), 'Asia/Kolkata')]);
    expect(h.bridge.calls, isNot(contains('clearZoneChangesUpTo')));
  });

  test('a later current zone follows the native ones', () async {
    h.bridge
      ..zoneChanges = [entry(t1, 'Europe/Paris')]
      ..currentZone = 'Asia/Tokyo';

    await sync.sync();

    expect(await h.zones.all(), [
      entry(t1, 'Europe/Paris'),
      entry(h.clock.now(), 'Asia/Tokyo'),
    ]);
  });

  test('does not clear when recordAll throws', () async {
    final h = MediaHarness(zones: _FailingZones.new);
    final sync = ZoneSync(h.bridge, h.zones, h.clock);
    h.bridge.zoneChanges = [entry(t1, 'Europe/Paris')];

    await expectLater(sync.sync(), throwsStateError);

    expect(h.bridge.calls, isNot(contains('clearZoneChangesUpTo')));
    expect(h.bridge.zoneChanges, [entry(t1, 'Europe/Paris')]);
  });

  test('a failing native read records nothing and clears nothing', () async {
    h.bridge
      ..zoneChanges = [entry(t1, 'Europe/Paris')]
      ..failNext('pendingZoneChanges');

    await expectLater(sync.sync(), throwsA(isA<PlatformException>()));

    expect(await h.zones.all(), isEmpty);
    expect(h.bridge.calls, isNot(contains('clearZoneChangesUpTo')));
  });

  test(
    'a zone the native side records again after a clear is not doubled',
    () async {
      h.bridge
        ..zoneChanges = [entry(t1, 'Europe/London')]
        ..currentZone = 'Europe/London';
      await sync.sync();
      // The native list was cleared, so it no longer knows its last zone and
      // records London again on the next change broadcast.
      h.bridge.zoneChanges = [entry(t2, 'Europe/London')];
      h.clock.advance(const Duration(days: 10));

      await sync.sync();

      expect(await h.zones.all(), [entry(t1, 'Europe/London')]);
      expect(h.bridge.clearedUpTo, [
        t1.millisecondsSinceEpoch,
        t2.millisecondsSinceEpoch,
      ]);
    },
  );

  test('zoneSyncProvider builds one zone sync', () {
    final db = testDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBridgeProvider.overrideWithValue(FakeMediaBridge()),
      ],
    );
    addTearDown(container.dispose);
    final first = container.read(zoneSyncProvider);
    expect(container.read(zoneSyncProvider), same(first));
  });
}
