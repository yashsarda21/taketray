import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/edit_folder_name.dart';

void main() {
  group('safeFolderName', () {
    test('each forbidden character becomes a dash', () {
      for (final ch in ['/', r'\', ':', '*', '?', '"', '<', '>', '|']) {
        expect(safeFolderName('a${ch}b'), 'a-b', reason: 'for $ch');
      }
      expect(safeFolderName('London/Paris'), 'London-Paris');
    });

    test('a name of only forbidden characters becomes dashes', () {
      expect(safeFolderName('?'), '-');
      expect(safeFolderName('::'), '--');
    });

    test('C0 controls and DEL are removed', () {
      expect(safeFolderName('Go\u0000a'), 'Goa');
      expect(safeFolderName('G\to\na\r'), 'Goa');
      expect(safeFolderName('Go\u001Fa\u007F'), 'Goa');
      expect(safeFolderName('Go a'), 'Go a');
    });

    test('a control between two spaces leaves one space', () {
      expect(safeFolderName('Goa \u0000 trip'), 'Goa trip');
    });

    test('runs of spaces become one', () {
      expect(safeFolderName('Goa    trip'), 'Goa trip');
      expect(safeFolderName('a  b   c'), 'a b c');
    });

    test('spaces and dots are trimmed at both ends', () {
      expect(safeFolderName('Goa.'), 'Goa');
      expect(safeFolderName('  Goa  '), 'Goa');
      expect(safeFolderName('. Goa .'), 'Goa');
      expect(safeFolderName('..Goa..'), 'Goa');
      expect(safeFolderName(' . . Goa . . '), 'Goa');
    });

    test('inner dots and spaces stay', () {
      expect(safeFolderName('Goa 2.0 trip'), 'Goa 2.0 trip');
    });

    test('empty, dot-only and space-only names become Reel', () {
      expect(safeFolderName(''), 'Reel');
      expect(safeFolderName('.'), 'Reel');
      expect(safeFolderName('..'), 'Reel');
      expect(safeFolderName('...'), 'Reel');
      expect(safeFolderName('   '), 'Reel');
      expect(safeFolderName(' . '), 'Reel');
      expect(safeFolderName('\u0000\u0007'), 'Reel');
    });

    test('emoji and accents are kept', () {
      expect(safeFolderName('Goa 🌴'), 'Goa 🌴');
      expect(safeFolderName('Café'), 'Café');
      expect(safeFolderName('🌴.'), '🌴');
      expect(safeFolderName('👨‍👩‍👧 trip'), '👨‍👩‍👧 trip');
      expect(safeFolderName('Café'), 'Café');
    });

    test('a 40-character name stays whole', () {
      final name = 'abcdefghij' * 4;
      expect(safeFolderName(name), name);
    });

    test('a clean name is returned unchanged', () {
      expect(safeFolderName('Goa'), 'Goa');
    });

    test('never longer than its input, except Reel', () {
      for (final input in [
        'London/Paris',
        '  Goa  ',
        'a\u0000b',
        'Goa.',
        '🌴🌴.',
        'x' * 40,
        'a  b',
      ]) {
        expect(
          safeFolderName(input).length <= input.length,
          isTrue,
          reason: input,
        );
      }
      expect(safeFolderName('.'), 'Reel');
    });
  });
}
