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

/// Marker that exempts its own line and the line below from every rule.
/// It must be followed by a reason: `// style-check: allow <reason>`.
const _allowMarker = '// style-check: allow';

// A numeric literal that is a standalone token (not part of an identifier,
// a member access such as `spacing.x2`, or an interpolation).
const _num = r'(?<![\w.$])-?\d';

final _rules = <String, RegExp>{
  'raw-color': RegExp(
    r'(?<!\w)(?:Color\(|Color\.fromARGB\(|Color\.fromRGBO\(|Colors\.)',
  ),
  'raw-text-style': RegExp(r'(?<!\w)TextStyle\('),
  'raw-insets': RegExp(r'(?<!\w)EdgeInsets(?:Directional)?\.\w+\([^)]*' + _num),
  'raw-size': RegExp(r'(?<!\w)SizedBox\([^)]*\b(?:width|height):\s*' + _num),
  'raw-radius': RegExp(r'(?<!\w)(?:BorderRadius|Radius)\.circular\(\s*' + _num),
  'raw-duration': RegExp(
    r'(?<!\w)Duration\([^)]*\b(?:milliseconds|seconds):\s*' + _num,
  ),
};

/// Finds style-rule violations in [source], a Dart file at [path].
///
/// Rules are applied line by line to the code part of each line (`//`
/// comments are ignored). A line is exempt when it, or the line above it,
/// contains `// style-check: allow <reason>`.
List<StyleViolation> findStyleViolations(
  String source, {
  required String path,
}) {
  final lines = source.split('\n');
  final violations = <StyleViolation>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.contains(_allowMarker)) continue;
    if (i > 0 && lines[i - 1].contains(_allowMarker)) continue;
    final code = _stripLineComment(raw);
    for (final MapEntry(key: rule, value: pattern) in _rules.entries) {
      if (pattern.hasMatch(code)) {
        violations.add(
          StyleViolation(
            path: path,
            line: i + 1,
            rule: rule,
            snippet: raw.trim(),
          ),
        );
      }
    }
  }
  return violations;
}

/// Removes a trailing `//` comment, ignoring `//` inside string literals.
String _stripLineComment(String line) {
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}
