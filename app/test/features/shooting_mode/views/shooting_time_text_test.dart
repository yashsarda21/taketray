import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';

/// intl 0.20 writes a narrow no-break space before AM/PM; the tests compare
/// with a plain space.
String plain(String s) => s.replaceAll(' ', ' ');

// All local times: the rule is about the phone's calendar day.
final DateTime _now = DateTime(2026, 10, 28, 15, 30);

String text(DateTime since, {String locale = 'en'}) =>
    plain(shootingTimeText(since: since, now: _now, locale: locale));

void main() {
  setUpAll(initializeDateFormatting);

  group('shootingTimeText', () {
    test('today: the time alone', () {
      expect(text(DateTime(2026, 10, 28, 9, 41)), '9:41 AM');
    });

    test('exactly local midnight today still counts as today', () {
      expect(text(DateTime(2026, 10, 28)), '12:00 AM');
    });

    test('23:59 yesterday adds the date', () {
      expect(text(DateTime(2026, 10, 27, 23, 59)), 'Oct 27, 11:59 PM');
    });

    test('an older day adds the date', () {
      expect(text(DateTime(2026, 10, 27, 21, 41)), 'Oct 27, 9:41 PM');
      expect(text(DateTime(2026, 9, 3, 8, 5)), 'Sep 3, 8:05 AM');
    });

    test('the same day number in another month is not today', () {
      expect(text(DateTime(2026, 9, 28, 9, 41)), 'Sep 28, 9:41 AM');
    });

    test('the same day and month in another year is not today', () {
      expect(text(DateTime(2025, 10, 28, 9, 41)), 'Oct 28, 9:41 AM');
    });

    test('a UTC instant is shown in local time', () {
      // Built from a local time, so it holds in any time zone.
      final utc = DateTime(2026, 10, 28, 9, 41).toUtc();
      expect(text(utc), '9:41 AM');
    });

    test('now given in UTC still compares local calendar days', () {
      final nowUtc = DateTime(2026, 10, 28, 15, 30).toUtc();
      expect(
        plain(
          shootingTimeText(
            since: DateTime(2026, 10, 28, 9, 41),
            now: nowUtc,
            locale: 'en',
          ),
        ),
        '9:41 AM',
      );
    });

    test('the device locale decides the format', () {
      expect(text(DateTime(2026, 10, 28, 21, 41), locale: 'de'), '21:41');
      expect(
        text(DateTime(2026, 10, 27, 21, 41), locale: 'de'),
        contains('21:41'),
      );
    });
  });
}
