import 'dart:convert';

import 'package:characters/characters.dart';
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
      expect(safeFolderName('G\u0001o\u0008a\u000B\u000C'), 'Goa');
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
    test('tab, LF and CR become one space, never glue words', () {
      expect(safeFolderName('Goa\ttrip'), 'Goa trip');
      expect(safeFolderName('Goa\ntrip'), 'Goa trip');
      expect(safeFolderName('Goa\rtrip'), 'Goa trip');
      expect(safeFolderName('Goa\n\ntrip'), 'Goa trip');
      expect(safeFolderName('Goa \r\n trip'), 'Goa trip');
      expect(safeFolderName('Goa\u0000\ttrip'), 'Goa trip');
      expect(safeFolderName('\tGoa\n'), 'Goa');
      expect(safeFolderName('\t\n\r'), 'Reel');
    });

    test('bidi controls are removed', () {
      final bidi = [
        0x200E,
        0x200F,
        for (var c = 0x202A; c <= 0x202E; c++) c,
        for (var c = 0x2066; c <= 0x2069; c++) c,
      ];
      for (final c in bidi) {
        final ch = String.fromCharCode(c);
        expect(safeFolderName('Go${ch}a'), 'Goa', reason: c.toRadixString(16));
      }
      expect(safeFolderName('\u202Eabc'), 'abc');
      expect(safeFolderName('\u202E\u200F'), 'Reel');
    });

    test('neighbours of the bidi ranges are kept', () {
      for (final c in [0x200D, 0x2029, 0x202F, 0x2065, 0x206A, 0x200B]) {
        final name = 'a${String.fromCharCode(c)}b';
        expect(safeFolderName(name), name, reason: c.toRadixString(16));
      }
    });

    test('lone surrogates are removed, pairs are kept', () {
      final high = String.fromCharCode(0xD83C);
      final low = String.fromCharCode(0xDF34);
      expect(safeFolderName('Go${high}a'), 'Goa');
      expect(safeFolderName('Go${low}a'), 'Goa');
      expect(safeFolderName('Goa$high'), 'Goa');
      expect(safeFolderName('${low}Goa'), 'Goa');
      expect(safeFolderName('Goa 🌴'), 'Goa 🌴');
    });

    test('the first and last surrogate code units are removed too', () {
      for (final unit in [0xD800, 0xDBFF, 0xDC00, 0xDFFF]) {
        final ch = String.fromCharCode(unit);
        expect(
          safeFolderName('Go${ch}a'),
          'Goa',
          reason: unit.toRadixString(16),
        );
      }
      for (final unit in [0xD7FF, 0xE000]) {
        final name = 'Go${String.fromCharCode(unit)}a';
        expect(safeFolderName(name), name, reason: unit.toRadixString(16));
      }
    });

    test('trimming is by grapheme: a dot with a combining mark is kept', () {
      expect(safeFolderName('Goa.́'), 'Goa.́');
      expect(safeFolderName('.́Goa'), '.́Goa');
      expect(safeFolderName('.́'), '.́');
      expect(safeFolderName('Goa.́.'), 'Goa.́');
    });
  });

  group('safeFolderName byte cap', () {
    int bytes(String s) => utf8.encode(s).length;

    test('the cap is 200 UTF-8 bytes', () {
      expect(safeFolderNameMaxBytes, 200);
    });

    test('40 family emoji are cut to whole emoji within 200 bytes', () {
      const family = '👨‍👩‍👧';
      final result = safeFolderName(family * 40);
      expect(bytes(family), 18);
      expect(result, family * 11);
      expect(bytes(result) <= 200, isTrue);
    });

    test('40 Devanagari clusters are cut to whole clusters', () {
      const cluster = 'कि';
      expect(cluster.characters.length, 1);
      expect(bytes(cluster), 6);
      final result = safeFolderName(cluster * 40);
      expect(result, cluster * 33);
      expect(result.characters.length, 33);
    });

    test('a name of 200 bytes stays whole, one byte over is cut', () {
      expect(safeFolderName('a' * 200), 'a' * 200);
      expect(safeFolderName('a' * 201), 'a' * 200);
      expect(safeFolderName('é' * 100), 'é' * 100);
    });

    test('exactly at the cap with a multi-byte grapheme stays whole', () {
      expect(safeFolderName('${'a' * 198}é'), '${'a' * 198}é');
    });

    test('one grapheme over the cap is dropped, not split', () {
      expect(safeFolderName('${'a' * 199}é'), 'a' * 199);
      expect(safeFolderName('${'a' * 199}€'), 'a' * 199);
      expect(safeFolderName('é' * 101), 'é' * 100);
      expect(safeFolderName('${'a' * 197}👨‍👩‍👧'), 'a' * 197);
    });

    test('a cut that leaves a trailing space is trimmed again', () {
      expect(safeFolderName('${'a' * 199} bcd'), 'a' * 199);
    });

    test('a cut that leaves trailing dots is trimmed again', () {
      expect(safeFolderName('${'a' * 198}..bcd'), 'a' * 198);
      expect(safeFolderName('${'a' * 197}. .bcd'), 'a' * 197);
    });

    test('leading dots and spaces are trimmed before the cap counts', () {
      expect(safeFolderName('..${'a' * 200}'), 'a' * 200);
      expect(safeFolderName(' ${'a' * 200}'), 'a' * 200);
      expect(safeFolderName('. . ${'a' * 200}'), 'a' * 200);
      expect(safeFolderName('\t${'a' * 200}'), 'a' * 200);
      expect(safeFolderName('..${'a' * 201}'), 'a' * 200);
      expect(safeFolderName('${'a' * 200}..'), 'a' * 200);
      expect(safeFolderName('..${'é' * 100}'), 'é' * 100);
    });

    test('a combining mark is never cut from its base', () {
      expect(safeFolderName('${'a' * 198}é'), 'a' * 198);
      expect(safeFolderName('${'a' * 197}é'), '${'a' * 197}é');
    });

    test('one grapheme longer than the cap leaves Reel', () {
      expect(safeFolderName('a${'́' * 101}'), 'Reel');
    });

    test('a cap cut still gives a result no longer than the input', () {
      final input = 'x' * 500;
      expect(safeFolderName(input).length <= input.length, isTrue);
    });

    test('40 ASCII characters stay whole', () {
      expect(safeFolderName('a' * 40), 'a' * 40);
    });
  });
}
