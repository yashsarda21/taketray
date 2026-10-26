import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/text_limits.dart';

void main() {
  group('normalizeName', () {
    test('trims surrounding spaces', () {
      expect(normalizeName('  Goa  '), 'Goa');
    });

    test('keeps spaces inside the name', () {
      expect(normalizeName(' London  Food '), 'London  Food');
    });
  });

  group('checkReelName', () {
    test('a normal name is fine', () {
      expect(checkReelName('Goa'), isNull);
    });

    test('an empty name is empty', () {
      expect(checkReelName(''), ReelNameProblem.empty);
    });

    test('a name of only spaces is empty', () {
      expect(checkReelName('   '), ReelNameProblem.empty);
    });

    test('surrounding spaces do not count towards the limit', () {
      expect(checkReelName('  ${'a' * 40}  '), isNull);
    });

    test('40 characters pass and 41 fail', () {
      expect(checkReelName('a' * 40), isNull);
      expect(checkReelName('a' * 41), ReelNameProblem.tooLong);
    });

    test('40 emoji pass and 41 fail (an emoji is one character)', () {
      expect(checkReelName('😀' * 40), isNull);
      expect(checkReelName('😀' * 41), ReelNameProblem.tooLong);
    });

    test('a family emoji and a flag are one character each', () {
      // 👨‍👩‍👧 is 5 code points and 8 UTF-16 units; 🇮🇳 is 2 code points.
      expect(checkReelName('👨‍👩‍👧' * 40), isNull);
      expect(checkReelName('🇮🇳' * 40), isNull);
      expect(checkReelName('🇮🇳' * 41), ReelNameProblem.tooLong);
    });

    test('an accented letter written as two code points is one character', () {
      // Written as an escape on purpose: "e" followed by U+0301 (combining
      // acute accent) looks like one "é" but is two code points, and an
      // editor that normalises text would silently merge a literal one.
      const decomposed = 'e\u0301';
      expect(decomposed * 40, hasLength(80));
      expect(checkReelName(decomposed * 40), isNull);
      expect(checkReelName(decomposed * 41), ReelNameProblem.tooLong);
    });

    test('a precomposed "é" counts once too', () {
      expect(checkReelName('\u00e9' * 40), isNull);
      expect(checkReelName('\u00e9' * 41), ReelNameProblem.tooLong);
    });

    test('a name of only invisible characters is empty', () {
      for (final blank in ['\u200B', '\u200C', '\u200D', '\u2060', '\uFEFF']) {
        expect(checkReelName(blank * 3), ReelNameProblem.empty, reason: blank);
      }
      expect(checkReelName(' \u200B\uFEFF \u2060'), ReelNameProblem.empty);
    });

    test('invisible characters at the ends are trimmed, not counted', () {
      expect(normalizeName('\u200BGoa\u200D\uFEFF'), 'Goa');
      expect(checkReelName('\u200B${'a' * 40}\u2060'), isNull);
    });

    test('an invisible character inside a name is kept and counted', () {
      expect(normalizeName('a\u200Bb'), 'a\u200Bb');
    });
  });

  group('checkReferenceLabel', () {
    test('null and empty are fine (no label)', () {
      expect(checkReferenceLabel(null), isNull);
      expect(checkReferenceLabel(''), isNull);
      expect(checkReferenceLabel('   '), isNull);
    });

    test('60 characters pass and 61 fail', () {
      expect(checkReferenceLabel('a' * 60), isNull);
      expect(checkReferenceLabel('a' * 61), ReferenceLabelProblem.tooLong);
    });

    test('60 emoji pass and 61 fail', () {
      expect(checkReferenceLabel('🎬' * 60), isNull);
      expect(checkReferenceLabel('🎬' * 61), ReferenceLabelProblem.tooLong);
    });

    test('surrounding spaces do not count', () {
      expect(checkReferenceLabel(' ${'a' * 60} '), isNull);
      expect(checkReferenceLabel('\u200B${'a' * 60}\uFEFF'), isNull);
      expect(checkReferenceLabel('\u200B\u200C'), isNull);
    });
  });

  test('InvalidInputException carries the problem', () {
    const error = InvalidInputException(ReelNameProblem.empty);
    expect(error.problem, ReelNameProblem.empty);
  });
}
