import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/zone_entry.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

late AppDatabase db;
late ZoneRepository repo;

DateTime _at(int day, [int hour = 0]) => DateTime.utc(2026, 10, day, hour);

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    repo = ZoneRepository(db, FixedClock(_at(26)));
  });

  test('an empty timeline has no zone', () async {
    expect(await repo.all(), isEmpty);
    expect(await repo.zoneAt(_at(26)), isNull);
  });

  test('record appends an entry and all() lists oldest first', () async {
    await repo.record(_at(12), 'Europe/London');
    await repo.record(_at(5), 'Asia/Kolkata');

    expect(await repo.all(), [
      ZoneEntry(at: _at(5), zoneId: 'Asia/Kolkata'),
      ZoneEntry(at: _at(12), zoneId: 'Europe/London'),
    ]);
  });

  test('recording the same zone twice keeps one entry', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(6), 'Asia/Kolkata');
    await repo.record(_at(7), 'Asia/Kolkata');

    expect(await repo.all(), [ZoneEntry(at: _at(5), zoneId: 'Asia/Kolkata')]);
  });

  test('going out and coming back is three entries', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(12), 'Europe/London');
    await repo.record(_at(19), 'Asia/Kolkata');

    expect((await repo.all()).map((e) => e.zoneId), [
      'Asia/Kolkata',
      'Europe/London',
      'Asia/Kolkata',
    ]);
  });

  test(
    'a record before the first entry, in the same zone, moves it back',
    () async {
      await repo.record(_at(10), 'Europe/London');
      await repo.record(_at(5), 'Europe/London');

      expect(await repo.all(), [
        ZoneEntry(at: _at(5), zoneId: 'Europe/London'),
      ]);
    },
  );

  test('a second record at the same instant replaces the first', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(5), 'Europe/London');

    expect(await repo.all(), [ZoneEntry(at: _at(5), zoneId: 'Europe/London')]);
  });

  test('recording between two entries inserts in order and drops a later '
      'entry that no longer marks a change', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(12), 'Europe/London');

    await repo.record(_at(8), 'Europe/Paris');
    expect((await repo.all()).map((e) => (e.at, e.zoneId)), [
      (_at(5), 'Asia/Kolkata'),
      (_at(8), 'Europe/Paris'),
      (_at(12), 'Europe/London'),
    ]);

    await repo.record(_at(10), 'Europe/London');
    expect((await repo.all()).map((e) => (e.at, e.zoneId)), [
      (_at(5), 'Asia/Kolkata'),
      (_at(8), 'Europe/Paris'),
      (_at(10), 'Europe/London'),
    ]);
    expect(await repo.zoneAt(_at(15)), 'Europe/London');
  });

  test('recording the neighbours zone at an entry instant removes the '
      'entry and the redundant ones around it', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(12), 'Europe/London');
    await repo.record(_at(19), 'Asia/Kolkata');

    await repo.record(_at(12), 'Asia/Kolkata');

    expect(await repo.all(), [ZoneEntry(at: _at(5), zoneId: 'Asia/Kolkata')]);
  });

  test(
    "recording at an entry's instant with another zone replaces it",
    () async {
      await repo.record(_at(5), 'Asia/Kolkata');
      await repo.record(_at(12), 'Europe/London');
      await repo.record(_at(19), 'Asia/Kolkata');

      await repo.record(_at(12), 'Europe/Paris');

      expect((await repo.all()).map((e) => (e.at, e.zoneId)), [
        (_at(5), 'Asia/Kolkata'),
        (_at(12), 'Europe/Paris'),
        (_at(19), 'Asia/Kolkata'),
      ]);
    },
  );

  test('zoneAt finds the entry in effect at an instant', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(12), 'Europe/London');
    await repo.record(_at(19), 'Asia/Kolkata');

    expect(await repo.zoneAt(_at(4, 23)), isNull);
    expect(await repo.zoneAt(_at(5)), 'Asia/Kolkata');
    expect(await repo.zoneAt(_at(11, 23)), 'Asia/Kolkata');
    expect(await repo.zoneAt(_at(12)), 'Europe/London');
    expect(await repo.zoneAt(_at(15)), 'Europe/London');
    expect(await repo.zoneAt(_at(19)), 'Asia/Kolkata');
    expect(await repo.zoneAt(_at(30)), 'Asia/Kolkata');
  });

  test('times keep millisecond precision', () async {
    final at = DateTime.utc(2026, 10, 5, 8, 30, 15, 250);
    await repo.record(at, 'Asia/Kolkata');

    expect((await repo.all()).single.at, at);
    expect(
      await repo.zoneAt(at.subtract(const Duration(milliseconds: 1))),
      isNull,
    );
  });

  group('recordAll', () {
    ZoneEntry entry(DateTime at, String zone) =>
        ZoneEntry(at: at, zoneId: zone);

    test('merges out of order without losing a later observation', () async {
      // The D-58 caveat: London on the 12th is recorded before Kolkata on
      // the 5th. One record at a time could drop the later observation.
      await repo.record(_at(12), 'Europe/London');

      await repo.recordAll([entry(_at(5), 'Asia/Kolkata')]);

      expect(await repo.all(), [
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(12), 'Europe/London'),
      ]);
      expect(await repo.zoneAt(_at(8)), 'Asia/Kolkata');
      expect(await repo.zoneAt(_at(15)), 'Europe/London');
    });

    test('the D-58 sequence: A@2, B@8, B@4, A@7 keeps zoneAt(8) = B', () async {
      await repo.recordAll([
        entry(_at(2), 'A'),
        entry(_at(8), 'B'),
        entry(_at(4), 'B'),
        entry(_at(7), 'A'),
      ]);

      // Sorted: A@2, B@4, A@7, B@8.
      expect((await repo.all()).map((e) => (e.at, e.zoneId)), [
        (_at(2), 'A'),
        (_at(4), 'B'),
        (_at(7), 'A'),
        (_at(8), 'B'),
      ]);
      expect(await repo.zoneAt(_at(8)), 'B');
    });

    test('drops repeated neighbours', () async {
      await repo.recordAll([
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(6), 'Asia/Kolkata'),
        entry(_at(7), 'Europe/London'),
        entry(_at(8), 'Europe/London'),
        entry(_at(9), 'Europe/London'),
        entry(_at(10), 'Asia/Kolkata'),
      ]);

      expect((await repo.all()).map((e) => (e.at, e.zoneId)), [
        (_at(5), 'Asia/Kolkata'),
        (_at(7), 'Europe/London'),
        (_at(10), 'Asia/Kolkata'),
      ]);
    });

    test('drops a stored entry that no longer marks a change', () async {
      await repo.record(_at(5), 'Asia/Kolkata');
      await repo.record(_at(12), 'Europe/London');

      await repo.recordAll([entry(_at(8), 'Europe/London')]);

      expect(await repo.all(), [
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(8), 'Europe/London'),
      ]);
    });

    test('an entry at an existing instant replaces it', () async {
      await repo.record(_at(5), 'Asia/Kolkata');
      await repo.record(_at(12), 'Europe/London');

      await repo.recordAll([entry(_at(12), 'Europe/Paris')]);

      expect(await repo.all(), [
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(12), 'Europe/Paris'),
      ]);
    });

    test('with nothing new changes nothing', () async {
      await repo.record(_at(5), 'Asia/Kolkata');
      await repo.record(_at(12), 'Europe/London');
      final changes = <List<ZoneEntry>>[];
      final sub = db
          .select(db.zoneTimeline)
          .watch()
          .listen(
            (rows) => changes.add([
              for (final r in rows) ZoneEntry(at: r.at, zoneId: r.zoneId),
            ]),
          );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      final before = await repo.all();

      await repo.recordAll([
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(13), 'Europe/London'),
        entry(_at(12), 'Europe/London'),
      ]);
      await pumpEventQueue();

      expect(await repo.all(), before);
      expect(changes, hasLength(1), reason: 'the table was not rewritten');
    });

    test('an empty iterable is a no-op, even on an empty timeline', () async {
      await repo.recordAll([]);
      expect(await repo.all(), isEmpty);

      await repo.record(_at(5), 'Asia/Kolkata');
      await repo.recordAll(const []);
      expect(await repo.all(), [entry(_at(5), 'Asia/Kolkata')]);
    });

    test('two entries at the same millisecond: the later one wins', () async {
      await repo.recordAll([
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(5), 'Europe/London'),
      ]);
      expect(await repo.all(), [entry(_at(5), 'Europe/London')]);

      await repo.recordAll([
        entry(_at(9), 'Europe/Paris'),
        entry(_at(9), 'Asia/Kolkata'),
        entry(_at(9), 'Europe/Berlin'),
      ]);
      expect((await repo.all()).map((e) => (e.at, e.zoneId)), [
        (_at(5), 'Europe/London'),
        (_at(9), 'Europe/Berlin'),
      ]);
    });

    test('sub-millisecond precision is truncated', () async {
      final precise = DateTime.utc(2026, 10, 5, 8, 30, 15, 250, 999);

      await repo.recordAll([entry(precise, 'Asia/Kolkata')]);

      final stored = (await repo.all()).single;
      expect(stored.at, DateTime.utc(2026, 10, 5, 8, 30, 15, 250));
      expect(stored.at.microsecond, 0);
    });

    test('two entries in one millisecond but different microseconds '
        'are the same instant', () async {
      await repo.recordAll([
        entry(DateTime.utc(2026, 10, 5, 8, 0, 0, 250, 1), 'Asia/Kolkata'),
        entry(DateTime.utc(2026, 10, 5, 8, 0, 0, 250, 900), 'Europe/London'),
      ]);

      expect(await repo.all(), [
        entry(DateTime.utc(2026, 10, 5, 8, 0, 0, 250), 'Europe/London'),
      ]);
    });

    test('accepts a lazy iterable and local-time instants', () async {
      final local = DateTime.utc(2026, 10, 5, 8).toLocal();

      await repo.recordAll(
        Iterable.generate(
          2,
          (i) => entry(i == 0 ? local : _at(6), 'Asia/Kolkata'),
        ),
      );

      expect(await repo.all(), [entry(_at(5, 8), 'Asia/Kolkata')]);
    });

    test('logs counts only', () async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await repo.recordAll([
        entry(_at(5), 'Asia/Kolkata'),
        entry(_at(6), 'Europe/London'),
      ]);

      final lines = records.map((r) => r.message).join('\n');
      expect(lines, isNotEmpty);
      expect(lines, isNot(contains('Kolkata')));
      expect(lines, isNot(contains('London')));
    });
  });
}
