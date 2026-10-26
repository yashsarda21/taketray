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
/// Exits 1 when a prefix is below the minimum, when it matches no counted
/// file (so a typo cannot pass), or when the lcov file does not exist.
void main(List<String> args) {
  final min = args.length < 3 ? null : double.tryParse(args[1]);
  if (min == null) {
    stderr.writeln(
      'usage: check_coverage <lcov.info> <min-percent> <prefix>...',
    );
    exit(64);
  }
  final lcov = File(args[0]);
  if (!lcov.existsSync()) {
    stderr.writeln('check_coverage: ${args[0]} not found');
    exit(1);
  }
  final files = _parseLcov(lcov.readAsLinesSync());

  var failed = false;
  for (final prefix in args.skip(2)) {
    var found = 0;
    var hit = 0;
    for (final entry in files.entries) {
      if (entry.key.startsWith(prefix)) {
        found += entry.value.found;
        hit += entry.value.hit;
      }
    }
    if (found == 0) {
      stderr.writeln('check_coverage: no coverage data for $prefix');
      failed = true;
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
