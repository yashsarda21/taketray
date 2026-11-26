import 'package:flutter/widgets.dart';
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

    test('an end before the start is the start alone', () {
      // Mixed zones: the last clip's wall clock can read earlier than the
      // first's (a London clip after an Indian one).
      expect(range(wall(13, 20), wall(13, 5)), '1:20 PM');
      expect(range(wall(13, 20), wall(9, 0), use24Hour: true), '13:20');
    });

    test('the same locale and setting give the same text again', () {
      // The formats are made once per locale and clock setting.
      expect(range(wall(13, 5), wall(13, 20)), '1:05–1:20 PM');
      expect(range(wall(13, 5), wall(13, 20), use24Hour: true), '13:05–13:20');
      expect(range(wall(13, 5), wall(13, 20)), '1:05–1:20 PM');
      expect(
        range(wall(13, 5), wall(13, 20), locale: 'ja'),
        isNot('1:05–1:20 PM'),
      );
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

  group('keepRangeTogether', () {
    String joined(String text) => keepRangeTogether(text);

    test('every space is a no-break space and a dash holds its neighbours', () {
      expect(joined('1:05–1:20 PM'), '1:05–\u20601:20\u00a0PM');
      expect(joined('11:50 AM–12:10 PM'), '11:50\u00a0AM–\u206012:10\u00a0PM');
      expect(joined('13:05–13:20'), '13:05–\u206013:20');
      expect(joined('오후 1:05–오후 1:20'), '오후\u00a01:05–\u2060오후\u00a01:20');
    });

    test('a narrow no-break space (intl) is left as it is', () {
      expect(joined('1:05–1:20\u202fPM'), '1:05–\u20601:20\u202fPM');
    });

    test('one time, or nothing, is not changed', () {
      expect(joined('13:05'), '13:05');
      expect(joined(''), '');
    });

    test('taking the joiners out gives the range back', () {
      for (final text in ['1:05–1:20 PM', '11:50 AM–12:10 PM', '13:05–13:20']) {
        expect(
          joined(text).replaceAll('\u2060', '').replaceAll('\u00a0', ' '),
          text,
        );
      }
    });

    testWidgets('a line never breaks inside the joined range, at any width', (
      tester,
    ) async {
      for (final range in [
        '9:01–9:08 AM',
        '11:50 AM–12:10 PM',
        '13:05–13:20',
      ]) {
        const lead = 'Scene 12 of 40 · ';
        final line = '$lead${joined(range)}';
        final single = TextPainter(
          text: TextSpan(
            text: joined(range),
            style: const TextStyle(fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Any width at which the range itself fits on a line.
        for (
          var width = single.width.ceilToDouble();
          width <= 400;
          width += 3
        ) {
          final painter = TextPainter(
            text: TextSpan(text: line, style: const TextStyle(fontSize: 12)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: width);
          var at = 0;
          while (at < line.length) {
            final end = painter.getLineBoundary(TextPosition(offset: at)).end;
            // A line ends before the range, or after all of it.
            expect(
              end <= lead.length || end >= line.length,
              isTrue,
              reason: '"$range" broke at $end in a width of $width',
            );
            if (end <= at) break;
            at = end;
          }
        }
      }
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
