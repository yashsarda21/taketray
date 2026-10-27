import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/zone_lookup.dart';

void main() {
  final timeline = [
    ZoneEntry(at: DateTime.utc(2026, 3), zoneId: 'Asia/Kolkata'),
    ZoneEntry(at: DateTime.utc(2026, 3, 10, 12), zoneId: 'Europe/London'),
    ZoneEntry(at: DateTime.utc(2026, 3, 20), zoneId: 'Asia/Kolkata'),
  ];

  test('an empty timeline gives null', () {
    expect(zoneAt([], DateTime.utc(2026, 3, 5)), isNull);
  });

  test('before the first entry gives null', () {
    expect(zoneAt(timeline, DateTime.utc(2026, 2, 28, 23, 59)), isNull);
  });

  test('exactly at an entry gives that entry', () {
    expect(zoneAt(timeline, DateTime.utc(2026, 3)), 'Asia/Kolkata');
    expect(zoneAt(timeline, DateTime.utc(2026, 3, 10, 12)), 'Europe/London');
  });

  test('one millisecond before an entry gives the previous one', () {
    final instant = DateTime.utc(
      2026,
      3,
      10,
      12,
    ).subtract(const Duration(milliseconds: 1));
    expect(zoneAt(timeline, instant), 'Asia/Kolkata');
  });

  test('between entries gives the earlier one', () {
    expect(zoneAt(timeline, DateTime.utc(2026, 3, 15)), 'Europe/London');
  });

  test('after the last entry gives the last one', () {
    expect(zoneAt(timeline, DateTime.utc(2027)), 'Asia/Kolkata');
  });

  test('a single entry', () {
    final one = [ZoneEntry(at: DateTime.utc(2026), zoneId: 'UTC')];
    expect(zoneAt(one, DateTime.utc(2025, 12, 31)), isNull);
    expect(zoneAt(one, DateTime.utc(2026)), 'UTC');
  });

  test('with two entries at the same instant the later one wins', () {
    final twins = [
      ZoneEntry(at: DateTime.utc(2026), zoneId: 'A/First'),
      ZoneEntry(at: DateTime.utc(2026), zoneId: 'A/Second'),
    ];
    expect(zoneAt(twins, DateTime.utc(2026)), 'A/Second');
  });

  test('a local-time instant is compared as the same moment', () {
    final local = DateTime.utc(2026, 3, 10, 12).toLocal();
    expect(zoneAt(timeline, local), 'Europe/London');
  });
}
