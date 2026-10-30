import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';

final DateTime _today = DateTime(2026, 10, 28);

/// The text for [day] in an app with [locale].
Future<String> _text(
  WidgetTester tester,
  DateTime day, {
  Locale? locale,
}) async {
  late String text;
  await tester.pumpWidget(
    ttTestApp(
      Builder(
        builder: (context) {
          text = ttDayText(context, day, today: _today);
          return Text(text);
        },
      ),
      locale: locale,
    ),
  );
  return text;
}

void main() {
  group('ttDayText', () {
    testWidgets('a day of this year has no year', (tester) async {
      expect(
        await _text(
          tester,
          DateTime(2026, 1, 2),
          locale: const Locale('en', 'US'),
        ),
        'Jan 2',
      );
      expect(
        await _text(
          tester,
          DateTime(2026, 12, 31),
          locale: const Locale('en', 'US'),
        ),
        'Dec 31',
      );
    });

    testWidgets('a day of another year has its year (yMMMd)', (tester) async {
      expect(
        await _text(
          tester,
          DateTime(2025, 12, 30),
          locale: const Locale('en', 'US'),
        ),
        'Dec 30, 2025',
      );
      expect(
        await _text(tester, DateTime(2027), locale: const Locale('en', 'US')),
        'Jan 1, 2027',
        reason: 'a different year after today counts too',
      );
    });

    testWidgets('the year is by the calendar, not by 365 days', (tester) async {
      // Yesterday's New Year's Eve is last year even a day before today.
      final text = await _text(
        tester,
        DateTime(2025, 12, 31),
        locale: const Locale('en', 'US'),
      );
      expect(text, contains('2025'));
    });

    testWidgets('en-US writes the month first, en-IN the day first', (
      tester,
    ) async {
      expect(
        await _text(
          tester,
          DateTime(2026, 10, 8),
          locale: const Locale('en', 'US'),
        ),
        'Oct 8',
      );
      expect(
        await _text(
          tester,
          DateTime(2026, 10, 8),
          locale: const Locale('en', 'IN'),
        ),
        '8 Oct',
      );
      expect(
        await _text(
          tester,
          DateTime(2026, 10, 8),
          locale: const Locale('en', 'GB'),
        ),
        '8 Oct',
      );
      expect(
        await _text(
          tester,
          DateTime(2025, 12, 30),
          locale: const Locale('en', 'IN'),
        ),
        '30 Dec 2025',
      );
    });

    testWidgets('has no ordinary space, so it cannot wrap', (tester) async {
      for (final locale in const [Locale('en', 'US'), Locale('en', 'IN')]) {
        for (final day in [DateTime(2026, 10, 8), DateTime(2025, 12, 30)]) {
          final text = await _text(tester, day, locale: locale);
          expect(text.contains(' '), isFalse, reason: '$locale $day');
          expect(text.contains(' '), isFalse);
        }
      }
    });

    testWidgets('a date inside a sentence never breaks across lines', (
      tester,
    ) async {
      for (final width in [120.0, 140.0, 160.0, 180.0, 200.0, 220.0]) {
        late String date;
        await tester.pumpWidget(
          ttTestApp(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) {
                    date = ttDayText(
                      context,
                      DateTime(2025, 12, 30),
                      today: _today,
                    );
                    return Text(
                      'Tap the last day, or Find videos for $date only.',
                    );
                  },
                ),
              ),
            ),
            locale: const Locale('en', 'US'),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text)).data!;
        final at = text.indexOf(date);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(Text),
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: at + date.length),
        );
        expect(
          {for (final box in boxes) box.top}.length,
          1,
          reason: 'the date is on one line at $width dp',
        );
      }
    });
  });
}
