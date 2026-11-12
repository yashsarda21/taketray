import 'package:characters/characters.dart';

const _forbidden = {'/', r'\', ':', '*', '?', '"', '<', '>', '|'};

/// A reel's name as a folder name under `Movies/TakeTray/` (D-119).
///
/// Android's shared storage and the file systems under it refuse some
/// characters, so each of `/ \ : * ? " < > |` becomes `-`; control
/// characters (U+0000 to U+001F and U+007F) are removed; runs of spaces
/// become one; spaces and dots are trimmed at both ends; a name that ends up
/// empty (it was empty, `.`, `..`, spaces only…) becomes `Reel`. Emoji and
/// accents are kept. The result is never longer than [reelName], except
/// `Reel`.
///
/// Trimming works on graphemes, so a dot that carries a combining mark is
/// kept with its mark rather than split from it.
String safeFolderName(String reelName) {
  final cleaned = StringBuffer();
  for (final unit in reelName.runes) {
    if (unit < 0x20 || unit == 0x7F) continue;
    final ch = String.fromCharCode(unit);
    cleaned.write(_forbidden.contains(ch) ? '-' : ch);
  }
  final collapsed = cleaned.toString().replaceAll(RegExp(' {2,}'), ' ');
  final trimmed = collapsed.characters
      .skipWhile(_isSpaceOrDot)
      .skipLastWhile(_isSpaceOrDot)
      .toString();
  return trimmed.isEmpty ? 'Reel' : trimmed;
}

bool _isSpaceOrDot(String grapheme) => grapheme == ' ' || grapheme == '.';
