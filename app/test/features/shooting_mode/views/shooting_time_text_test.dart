import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';

/// intl 0.20 writes a narrow no-break space before AM/PM; the tests compare
/// with a plain space.
String plain(String s) => s.replaceAll(' ', ' ');

// All local times: the rule is about the phone's calendar day.
final DateTime _now = DateTime(2026, 10, 28, 15, 30);

String text(DateTime since, {String locale = 'en', bool use24Hour = false}) =>
    plain(
      shootingTimeText(
        since: since,
        now: _now,
        locale: locale,
        use24Hour: use24Hour,
      ),
    );

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
            use24Hour: false,
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

    test('the phone set to 24 hours: today is the time alone, as HH:mm', () {
      expect(text(DateTime(2026, 10, 28, 9, 41), use24Hour: true), '09:41');
      expect(text(DateTime(2026, 10, 28, 21, 41), use24Hour: true), '21:41');
    });

    test('24 hours: not today adds the date, as Oct 27, 21:41', () {
      expect(
        text(DateTime(2026, 10, 27, 21, 41), use24Hour: true),
        'Oct 27, 21:41',
      );
    });

    test('24 hours, at the day edges: 00:00 today, 23:59 yesterday', () {
      expect(text(DateTime(2026, 10, 28), use24Hour: true), '00:00');
      expect(
        text(DateTime(2026, 10, 27, 23, 59), use24Hour: true),
        'Oct 27, 23:59',
      );
    });

    test('12 hours stays 9:41 AM, with the flag off', () {
      expect(text(DateTime(2026, 10, 28, 21, 41)), '9:41 PM');
    });
  });

  group('timeOfDayText (the time on a tile)', () {
    String tod(DateTime t, {bool use24Hour = false}) =>
        plain(timeOfDayText(t, locale: 'en', use24Hour: use24Hour));

    test('12 hours: 9:41 AM, 9:41 PM, 12:00 AM', () {
      expect(tod(DateTime(2026, 10, 28, 9, 41)), '9:41 AM');
      expect(tod(DateTime(2026, 10, 28, 21, 41)), '9:41 PM');
      expect(tod(DateTime(2026, 10, 28)), '12:00 AM');
    });

    test('24 hours: 09:41, 21:41, 00:00', () {
      expect(tod(DateTime(2026, 10, 28, 9, 41), use24Hour: true), '09:41');
      expect(tod(DateTime(2026, 10, 28, 21, 41), use24Hour: true), '21:41');
      expect(tod(DateTime(2026, 10, 28), use24Hour: true), '00:00');
    });

    test('a UTC instant is shown in local time', () {
      final utc = DateTime(2026, 10, 28, 21, 41).toUtc();
      expect(tod(utc, use24Hour: true), '21:41');
    });
  });

  group('wallClockTimeText (a time where a clip was shot)', () {
    String wall(DateTime t, {bool use24Hour = false}) =>
        plain(wallClockTimeText(t, locale: 'en', use24Hour: use24Hour));

    test('shows the fields as they are, in any machine zone', () {
      // A UTC value whose fields are the wall clock (ClipLocalTime): never
      // converted to the machine's local time.
      expect(wall(DateTime.utc(2026, 10, 28, 21, 41)), '9:41 PM');
      expect(wall(DateTime.utc(2026, 10, 28, 4, 11)), '4:11 AM');
      expect(wall(DateTime.utc(2026, 10, 28)), '12:00 AM');
    });

    test('24 hours: 21:41, 04:11, 00:00', () {
      expect(
        wall(DateTime.utc(2026, 10, 28, 21, 41), use24Hour: true),
        '21:41',
      );
      expect(wall(DateTime.utc(2026, 10, 28, 4, 11), use24Hour: true), '04:11');
      expect(wall(DateTime.utc(2026, 10, 28), use24Hour: true), '00:00');
    });

    test('a wall clock in the London spring-forward gap stays as it is', () {
      // 01:30 on 2027-03-28 never happened on a London clock, but it is a
      // real time in another zone; as a local DateTime in London it would
      // move to 02:30.
      expect(wall(DateTime.utc(2027, 3, 28, 1, 30), use24Hour: true), '01:30');
    });
  });
}
