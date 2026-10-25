import 'dart:io';

import 'package:taketray_tool/src/style_rules.dart';

/// Scans `**/*.dart` under the given directory for style violations.
///
/// Usage: `tool/dart run taketray_tool:check_styles <dir>`.
/// Exits 0 when clean (or the directory does not exist), 1 otherwise.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: check_styles <dir>');
    exit(64);
  }
  final dir = Directory(args.single);
  if (!dir.existsSync()) {
    stdout.writeln('check_styles: ${args.single} not found (clean)');
    return;
  }
  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final violations = [
    for (final f in files)
      ...findStyleViolations(f.readAsStringSync(), path: f.path),
  ];
  if (violations.isNotEmpty) {
    violations.forEach(stdout.writeln);
    stdout.writeln('check_styles: ${violations.length} violation(s)');
    exit(1);
  }
}
