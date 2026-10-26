/// A single breach of a style rule.
class StyleViolation {
  /// Creates a violation.
  const new({
    required this.path,
    required this.line,
    required this.rule,
    required this.snippet,
  });

  /// File the violation was found in.
  final String path;

  /// One-based line number.
  final int line;

  /// Rule id, for example `raw-color`.
  final String rule;

  /// The offending source line, trimmed.
  final String snippet;

  @override
  String toString() => '$path:$line $rule $snippet';
}

/// Matches an allow marker that carries a non-empty reason:
/// `// style-check: allow <reason>`.
final _allowMarker = RegExp(r'// style-check: allow[ \t]+\S');

// Any run of call arguments up to a top-level comma, tolerating one level of
// nested parentheses so `child: Foo(), height: 8` is still seen.
const _args = r'(?:[^()]|\([^()]*\))*?';

// A numeric literal that is a whole argument: `8`, `-4`, `8.0`, `16,` or
// `16)`; `2 * tokens.y` and `spacing.m * 2` are not literals in this sense.
const _lit = r'-?\d[\w.]*\s*[,)]';

final _rules = <String, RegExp>{
  'raw-color': RegExp(
    r'(?<!\w)(?:Color\(|Color\.fromARGB\(|Color\.fromRGBO\(|Colors\.)',
  ),
  'raw-text-style': RegExp(r'(?<!\w)TextStyle\('),
  'raw-insets': RegExp(
    r'(?<!\w)EdgeInsets(?:Directional)?\.\w+\((?:' +
        _args +
        r',)?\s*(?:\w+:\s*)?' +
        _lit,
  ),
  'raw-size': RegExp(
    r'(?<!\w)SizedBox(?:\((?:' +
        _args +
        r',)?\s*(?:width|height)|\.square\((?:' +
        _args +
        r',)?\s*dimension):\s*' +
        _lit,
  ),
  'raw-radius': RegExp(
    r'(?<!\w)(?:BorderRadius(?:Directional)?|Radius)\.circular\(\s*' + _lit,
  ),
  'raw-duration': RegExp(
    r'(?<!\w)Duration\((?:' +
        _args +
        r',)?\s*(?:microseconds|milliseconds|seconds|minutes|hours|days):\s*' +
        _lit,
  ),
};

/// Finds style-rule violations in [source], a Dart file at [path].
///
/// Comments are blanked out of the whole text (offsets and newlines are
/// preserved), the rule patterns run over the full text so calls split across
/// lines are seen, and each match is reported on the line where it starts.
/// A match is exempt when its start line contains
/// `// style-check: allow <reason>`, or the line above is a comment-only line
/// containing it. A marker on a line that also holds code exempts that line
/// only.
List<StyleViolation> findStyleViolations(
  String source, {
  required String path,
}) {
  final lines = source.split('\n');
  final codeLines = _blankComments(source).split('\n');
  final lineStarts = <int>[];
  var offset = 0;
  for (final l in codeLines) {
    lineStarts.add(offset);
    offset += l.length + 1;
  }
  final code = codeLines.join('\n');

  int lineOf(int at) {
    var lo = 0;
    var hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (lineStarts[mid] <= at) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  bool allowed(int i) {
    if (_allowMarker.hasMatch(lines[i])) return true;
    return i > 0 &&
        _allowMarker.hasMatch(lines[i - 1]) &&
        codeLines[i - 1].trim().isEmpty;
  }

  final seen = <String>{};
  final violations = <StyleViolation>[];
  for (final MapEntry(key: rule, value: pattern) in _rules.entries) {
    for (final m in pattern.allMatches(code)) {
      final i = lineOf(m.start);
      if (allowed(i) || !seen.add('$rule:$i')) continue;
      violations.add(
        StyleViolation(
          path: path,
          line: i + 1,
          rule: rule,
          snippet: lines[i].trim(),
        ),
      );
    }
  }
  return violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Replaces comments with spaces, keeping every newline and offset.
/// String literals are skipped so `//` inside them is not a comment.
String _blankComments(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    final next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < src.length && src[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (c == '/' && next == '*') {
      final end = src.indexOf('*/', i + 2);
      final stop = end == -1 ? src.length : end + 2;
      for (; i < stop; i++) {
        out.write(src[i] == '\n' ? '\n' : ' ');
      }
    } else if (c == "'" || c == '"') {
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < src.length) {
        if (src[i] == r'\') {
          out.write(src.substring(i, i + 2 > src.length ? i + 1 : i + 2));
          i += 2;
        } else if (src.startsWith(quote, i)) {
          out.write(quote);
          i += quote.length;
          break;
        } else if (!triple && src[i] == '\n') {
          break; // unterminated: stop at end of line
        } else {
          out.write(src[i]);
          i++;
        }
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}
