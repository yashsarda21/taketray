import 'dart:io';

/// Fails when the line coverage of any path prefix is below a minimum.
///
/// Usage:
///
/// ```text
/// tool/dart run taketray_tool:check_coverage <lcov.info> <min-percent> <prefix>...
/// ```
///
/// Reads an lcov file (as written by `flutter test --coverage`), adds up the
/// lines of every file whose path starts with a prefix, and prints one line
/// per prefix: `prefix  percent  hit/found lines`. Files ending in `.g.dart`
/// or `.freezed.dart` are generated and are not counted.
///
/// A prefix must end in `/`. A segment that is exactly `*` matches one path
/// segment (so `lib/features/*/view_models/` matches
/// `lib/features/a/view_models/x.dart` but not
/// `lib/features/a/b/view_models/x.dart`); a `*` anywhere else is refused. The
/// minimum must be a number from 0 to 100. Otherwise it prints the usage and
/// exits 64.
///
/// A prefix that matches no file with executable lines prints
/// `prefix  no files` and passes: a folder may not exist yet (`lib/platform/`
/// arrives in a later task). `tool/check` makes every file under a prefix
/// count by importing it in a test, so a file no test loads shows up here with
/// every line at 0.
///
/// Exits 1 when a prefix is below the minimum, when no prefix at all matches a
/// file with lines (a typo or the wrong lcov file cannot pass), or when the
/// lcov file does not exist.
void main(List<String> args) {
  final min = args.length < 3 ? null : double.tryParse(args[1]);
  // A NaN or out-of-range minimum would make every comparison pass.
  // A prefix must end in `/`, or `lib/data` would also match `lib/database_x/`.
  if (min == null ||
      min.isNaN ||
      min < 0 ||
      min > 100 ||
      !args.skip(2).every(_isValidPrefix)) {
    stderr.writeln(
      'usage: check_coverage <lcov.info> <min-percent 0-100> <prefix/>...',
    );
    exit(64);
  }
  final lcov = File(args[0]);
  if (!lcov.existsSync()) {
    stderr.writeln('check_coverage: ${args[0]} not found');
    exit(1);
  }
  final files = _parseLcov(lcov.readAsLinesSync());

  final results = <String, _Lines>{};
  for (final prefix in args.skip(2)) {
    final matches = _prefixPattern(prefix);
    var found = 0;
    var hit = 0;
    for (final entry in files.entries) {
      if (matches.hasMatch(entry.key)) {
        found += entry.value.found;
        hit += entry.value.hit;
      }
    }
    results[prefix] = (found: found, hit: hit);
  }

  var failed = false;
  // One empty prefix is a folder that does not exist yet. All of them empty is
  // a typo, or an lcov file from some other project.
  final anyData = results.values.any((lines) => lines.found > 0);
  for (final MapEntry(key: prefix, value: (:found, :hit)) in results.entries) {
    if (found == 0) {
      if (anyData) {
        stdout.writeln('$prefix  no files');
      } else {
        stderr.writeln('check_coverage: no coverage data for $prefix');
        failed = true;
      }
      continue;
    }
    final percent = hit * 100 / found;
    stdout.writeln(
      '$prefix  ${percent.toStringAsFixed(1)}%  $hit/$found lines',
    );
    if (percent < min) {
      stderr.writeln('check_coverage: $prefix is below $min%');
      failed = true;
    }
  }
  if (failed) exit(1);
}

typedef _Lines = ({int found, int hit});

/// A prefix ends in `/`, and each `*` is a whole segment.
bool _isValidPrefix(String prefix) =>
    prefix.endsWith('/') &&
    prefix
        .split('/')
        .every((segment) => segment == '*' || !segment.contains('*'));

/// Matches a path that starts with [prefix], where a `*` segment is exactly one
/// non-empty path segment. Everything else is literal text.
RegExp _prefixPattern(String prefix) {
  final segments = prefix
      .split('/')
      .map((segment) => segment == '*' ? '[^/]+' : RegExp.escape(segment));
  return RegExp('^${segments.join('/')}');
}

/// Line counts per source file, with generated files left out.
Map<String, _Lines> _parseLcov(List<String> lines) {
  final result = <String, _Lines>{};
  String? file;
  var found = 0;
  var hit = 0;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      file = line.substring(3);
      found = 0;
      hit = 0;
    } else if (line.startsWith('DA:')) {
      // `DA:<line number>,<times run>[,<checksum>]`
      final count = int.tryParse(line.substring(3).split(',')[1]);
      if (count != null) {
        found++;
        if (count > 0) hit++;
      }
    } else if (line == 'end_of_record' && file != null) {
      if (!file.endsWith('.g.dart') && !file.endsWith('.freezed.dart')) {
        result[file] = (found: found, hit: hit);
      }
      file = null;
    }
  }
  return result;
}
