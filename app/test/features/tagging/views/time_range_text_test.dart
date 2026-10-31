import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taketray/features/tagging/views/time_range_text.dart';
import 'package:taketray/l10n/gen/app_localizations_en.dart';

/// intl 0.20 writes a narrow no-break space before AM/PM; the tests compare
/// with a plain space.
String plain(String s) => s.replaceAll(' ', ' ');

/// Wall-clock values, as `ClipLocalTime.wallClock` holds them.
DateTime wall(int h, int m, [int s = 0]) => DateTime.utc(2026, 10, 28, h, m, s);

String range(
  DateTime a,
  DateTime b, {
  bool use24Hour = false,
  String locale = 'en',
}) => plain(timeRangeText(a, b, locale: locale, use24Hour: use24Hour));

void main() {
  setUpAll(initializeDateFormatting);

  group('timeRangeText', () {
    test('range shares am/pm', () {
      expect(range(wall(13, 5), wall(13, 20)), '1:05–1:20 PM');
      expect(range(wall(9, 41), wall(10, 2)), '9:41–10:02 AM');
    });

    test('range across noon', () {
      expect(range(wall(11, 50), wall(12, 10)), '11:50 AM–12:10 PM');
      expect(range(wall(23, 55), wall(23, 58)), '11:55–11:58 PM');
    });

    test('range under a minute is one time', () {
      expect(range(wall(13, 5), wall(13, 5)), '1:05 PM');
      expect(range(wall(13, 5), wall(13, 5, 59)), '1:05 PM');
      expect(range(wall(13, 5), wall(13, 6)), '1:05–1:06 PM');
    });

    test('24-hour range', () {
      expect(range(wall(13, 5), wall(13, 20), use24Hour: true), '13:05–13:20');
      expect(range(wall(9, 5), wall(13, 20), use24Hour: true), '09:05–13:20');
      expect(range(wall(13, 5), wall(13, 5, 30), use24Hour: true), '13:05');
    });

    test('a locale with the period first writes both times in full', () {
      // Korean puts the period before the time ("오후 1:05"): a period written
      // once after the second time would be wrong there.
      expect(range(wall(13, 5), wall(13, 20), locale: 'ko'), '오후 1:05–오후 1:20');
    });

    test('a locale whose 12-hour pattern has no period writes full times', () {
      // Japanese `jm` is already a 24-hour pattern.
      expect(range(wall(13, 5), wall(13, 20), locale: 'ja'), '13:05–13:20');
    });

    test("an English (India) phone follows its locale's period", () {
      final text = range(wall(13, 5), wall(13, 20), locale: 'en_IN');

      expect(text, matches(RegExp(r'^1:05–1:20 [Pp][Mm]$')));
    });
  });

  group('minutesText', () {
    String text(int ms) => minutesText(AppLocalizationsEn(), ms);

    test('minutes text 45 s / 12 min / 1 h 5 min', () {
      expect(text(45000), '45 s');
      expect(text(12 * 60000), '12 min');
      expect(text(65 * 60000), '1 h 5 min');
    });
  });
}
