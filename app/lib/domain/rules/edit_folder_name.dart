import 'dart:convert';

import 'package:characters/characters.dart';

/// The longest folder name [safeFolderName] gives, in UTF-8 bytes.
///
/// Android limits a path component by bytes (255), not by characters, and
/// Android shortens an over-long one itself, which would make the real
/// folder differ from the name TakeTray recorded. 200 leaves room for the
/// ` (2)` that `uniqueFolderName` may add.
const int safeFolderNameMaxBytes = 200;

const _forbidden = {'/', r'\', ':', '*', '?', '"', '<', '>', '|'};

/// A reel's name as a folder name under `Movies/TakeTray/` (D-119).
///
/// Android's shared storage and the file systems under it refuse some
/// characters, so each of `/ \ : * ? " < > |` becomes `-`. Tab, line feed
/// and carriage return become a space (so words never glue together); the
/// other control characters (U+0000 to U+001F and U+007F), the Unicode bidi
/// controls (U+200E, U+200F, U+202A to U+202E, U+2066 to U+2069) and lone
/// surrogates are removed. Runs of spaces become one; spaces and dots are
/// trimmed at both ends; the result is cut at a whole grapheme so it is at
/// most [safeFolderNameMaxBytes] UTF-8 bytes, then trimmed again; a name
/// that ends up empty (it was empty, `.`, `..`, `...`, only spaces or
/// controls, or one grapheme longer than the cap) becomes `Reel`. Emoji and
/// accents stay. The result is never longer than [reelName], except `Reel`.
///
/// Trimming and cutting work on graphemes, so a dot that carries a combining
/// mark is kept with its mark, and a cut never splits an emoji or a letter
/// from its marks.
String safeFolderName(String reelName) {
  final cleaned = StringBuffer();
  for (final rune in reelName.runes) {
    if (rune == 0x09 || rune == 0x0A || rune == 0x0D) {
      cleaned.write(' ');
    } else if (rune < 0x20 || rune == 0x7F || _isBidiOrSurrogate(rune)) {
      continue;
    } else {
      final ch = String.fromCharCode(rune);
      cleaned.write(_forbidden.contains(ch) ? '-' : ch);
    }
  }
  final collapsed = cleaned.toString().replaceAll(RegExp(' {2,}'), ' ');
  final trimmed = _trim(collapsed.characters);
  final capped = _trim(_capBytes(trimmed, safeFolderNameMaxBytes).characters);
  return capped.isEmpty ? 'Reel' : capped;
}

bool _isBidiOrSurrogate(int rune) =>
    rune == 0x200E ||
    rune == 0x200F ||
    (rune >= 0x202A && rune <= 0x202E) ||
    (rune >= 0x2066 && rune <= 0x2069) ||
    (rune >= 0xD800 && rune <= 0xDFFF);

String _trim(Characters text) =>
    text.skipWhile(_isSpaceOrDot).skipLastWhile(_isSpaceOrDot).toString();

/// The longest start of [text] that is whole graphemes and at most
/// [maxBytes] UTF-8 bytes.
String _capBytes(String text, int maxBytes) {
  final kept = StringBuffer();
  var used = 0;
  for (final grapheme in text.characters) {
    used += utf8.encode(grapheme).length;
    if (used > maxBytes) break;
    kept.write(grapheme);
  }
  return kept.toString();
}

bool _isSpaceOrDot(String grapheme) => grapheme == ' ' || grapheme == '.';
