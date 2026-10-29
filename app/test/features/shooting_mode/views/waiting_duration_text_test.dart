import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/shooting_mode/views/waiting_duration_text.dart';
import 'package:taketray/l10n/gen/app_localizations_en.dart';

/// The prototype's `fmt.mins(sec)`, in milliseconds:
///   sec < 60: round(sec) + ' s'
///   m = round(sec / 60); m < 60: m + ' min'
///   else floor(m / 60) + ' h ' + (m % 60) + ' min'
String text(int ms) => waitingDurationText(AppLocalizationsEn(), ms);

void main() {
  group('waitingDurationText (fmt.mins)', () {
    test('none is 0 s', () => expect(text(0), '0 s'));

    test('under a minute is rounded seconds', () {
      expect(text(1000), '1 s');
      expect(text(32000), '32 s');
      expect(text(59000), '59 s');
      expect(text(1499), '1 s');
      expect(text(1500), '2 s', reason: 'half rounds up');
    });

    test('59.5 s rounds to 60 s, as the prototype does', () {
      expect(text(59499), '59 s');
      expect(text(59500), '60 s');
      expect(text(59999), '60 s');
    });

    test('a minute and over is rounded minutes', () {
      expect(text(60000), '1 min');
      expect(text(89999), '1 min');
      expect(text(90000), '2 min', reason: '1.5 min rounds up');
      expect(text(3 * 60000), '3 min');
      expect(text(59 * 60000), '59 min');
    });

    test('59.5 min rounds up to an hour', () {
      expect(text(59 * 60000 + 29999), '59 min');
      expect(text(59 * 60000 + 30000), '1 h 0 min');
    });

    test('an hour or more is hours and minutes', () {
      expect(text(3600000), '1 h 0 min');
      expect(text(3900000), '1 h 5 min');
      expect(text(2 * 3600000 + 59 * 60000), '2 h 59 min');
      expect(text(25 * 3600000), '25 h 0 min');
    });
  });
}
