import 'package:flutter_test/flutter_test.dart';
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

  test('a record before the first entry is compared with nothing', () async {
    await repo.record(_at(10), 'Europe/London');
    await repo.record(_at(5), 'Europe/London');

    expect((await repo.all()).map((e) => e.at), [_at(5), _at(10)]);
  });

  test('a second record at the same instant replaces the first', () async {
    await repo.record(_at(5), 'Asia/Kolkata');
    await repo.record(_at(5), 'Europe/London');

    expect(await repo.all(), [ZoneEntry(at: _at(5), zoneId: 'Europe/London')]);
  });

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
}
