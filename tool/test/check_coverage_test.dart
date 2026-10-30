import 'dart:io';

import 'package:test/test.dart';

/// One lcov record: `hits` lists the hit count of each executable line.
String _record(String path, List<int> hits) {
  final lines = [
    for (var i = 0; i < hits.length; i++) 'DA:${i + 1},${hits[i]}',
  ];
  return 'SF:$path\n${lines.join('\n')}\nend_of_record\n';
}

/// Writes [lcov] to a temp file, runs `check_coverage` on it and returns the
/// result.
ProcessResult _run(String lcov, List<String> rest) {
  final dir = Directory.systemTemp.createTempSync('check_coverage_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/lcov.info')..writeAsStringSync(lcov);
  return Process.runSync(Platform.resolvedExecutable, [
    'run',
    'bin/check_coverage.dart',
    file.path,
    ...rest,
  ]);
}

void main() {
  test('passes when every prefix is at or above the threshold', () {
    // 4 of 5 lines hit = 80 %, exactly on the bar.
    final result = _run(
      _record('lib/data/a.dart', [1, 2, 0, 3, 1]) +
          _record('lib/domain/b.dart', [1, 1]),
      ['80', 'lib/domain/', 'lib/data/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('lib/data/'));
    expect(result.stdout, contains('80.0%'));
    expect(result.stdout, contains('4/5'));
    expect(result.stdout, contains('lib/domain/'));
    expect(result.stdout, contains('100.0%'));
    expect(result.stdout, contains('2/2'));
  });

  test('fails when a prefix is below the threshold, and names it', () {
    // 3 of 5 = 60 % for data; domain is fine.
    final result = _run(
      _record('lib/data/a.dart', [1, 0, 0, 1, 1]) +
          _record('lib/domain/b.dart', [1, 1]),
      ['80', 'lib/domain/', 'lib/data/'],
    );
    expect(result.exitCode, 1);
    expect(result.stdout, contains('60.0%'));
    expect(result.stdout, contains('3/5'));
    expect(result.stderr, contains('lib/data/'));
    expect(result.stderr, contains('below 80'));
    expect(result.stderr, isNot(contains('lib/domain/')));
  });

  test('adds up all the files under a prefix', () {
    // 1/2 and 3/3 together are 4/5 = 80 %, although the first file is 50 %.
    final result = _run(
      _record('lib/data/a.dart', [1, 0]) +
          _record('lib/data/b.dart', [2, 2, 2]),
      ['80', 'lib/data/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('4/5'));
  });

  test('generated files are excluded', () {
    // Without the exclusion data would be 6/10 = 60 % and fail.
    final result = _run(
      _record('lib/data/a.dart', [1, 1, 1, 1]) +
          _record('lib/data/a.g.dart', [0, 0, 0, 0, 0, 0]) +
          _record('lib/data/m.freezed.dart', [0, 0]),
      ['80', 'lib/data/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('4/4'));
  });

  test('a prefix with only generated files has no files and passes', () {
    // lib/platform/ and the view-model folders arrive in later tasks; until
    // then their prefixes match nothing.
    final result = _run(
      _record('lib/data/a.dart', [1, 1]) +
          _record('lib/domain/a.g.dart', [1, 1]),
      ['80', 'lib/data/', 'lib/domain/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('lib/domain/  no files'));
    expect(result.stdout, contains('lib/data/  100.0%'));
  });

  test('prefix with no files passes', () {
    final result = _run(_record('lib/data/a.dart', [1, 1, 1, 1]), [
      '80',
      'lib/data/',
      'lib/platform/',
      'lib/features/*/view_models/',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('lib/platform/  no files'));
    expect(result.stdout, contains('lib/features/*/view_models/  no files'));
    expect(result.stdout, contains('4/4'));
  });

  test('no prefix with any file fails, so a wrong lcov file cannot pass', () {
    final result = _run(_record('lib/data/a.dart', [1, 1]), [
      '80',
      'lib/platform/',
      'lib/features/*/view_models/',
    ]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('no coverage data for lib/platform/'));
  });

  test('an unknown prefix on its own fails, so a typo cannot pass', () {
    final result = _run(_record('lib/data/a.dart', [1, 1]), ['80', 'lib/dat/']);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('no coverage data for lib/dat/'));
  });

  test('a file with zero hits lowers the total', () {
    // A file no test loads: tool/check imports it, so lcov lists it with
    // every line at 0. 4 of 10 lines = 40 %.
    final result = _run(
      _record('lib/data/tested.dart', [1, 1, 1, 1]) +
          _record('lib/data/_probe.dart', [0, 0, 0, 0, 0, 0]),
      ['80', 'lib/data/'],
    );
    expect(result.exitCode, 1);
    expect(result.stdout, contains('40.0%'));
    expect(result.stdout, contains('4/10'));
    expect(result.stderr, contains('below 80'));
  });

  test('enum-only file with no lines is ignored', () {
    // An enum or an abstract interface has no executable lines: lcov lists the
    // file with LF:0, or not at all. It must not count and must not be an
    // error.
    final result = _run(
      _record('lib/domain/kind.dart', []) +
          _record('lib/domain/rule.dart', [1, 1, 1, 1, 0]),
      ['80', 'lib/domain/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('4/5'));
  });

  test('a prefix whose only file has no lines has no files and passes', () {
    final result = _run(
      _record('lib/platform/kind.dart', []) +
          _record('lib/data/a.dart', [1, 1]),
      ['80', 'lib/data/', 'lib/platform/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('lib/platform/  no files'));
  });

  test('wildcard matches one segment only', () {
    // Only the first file matches lib/features/*/view_models/: the second has
    // two segments where the star is.
    final result = _run(
      _record('lib/features/a/view_models/x.dart', [1, 1]) +
          _record('lib/features/a/b/view_models/x.dart', [0, 0, 0, 0, 0, 0]),
      ['80', 'lib/features/*/view_models/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('2/2'));
    expect(result.stdout, isNot(contains('/8')));
  });

  test('wildcard adds up several features and nested view-model files', () {
    final result = _run(
      _record('lib/features/a/view_models/x.dart', [1, 1, 1]) +
          _record('lib/features/b/view_models/sub/y.dart', [1, 0]) +
          _record('lib/features/c/views/z.dart', [0, 0, 0, 0]),
      ['50', 'lib/features/*/view_models/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('4/5'));
  });

  test('a wildcard matches a segment that is not empty', () {
    final result = _run(
      _record('lib/features//view_models/x.dart', [0, 0]) +
          _record('lib/features/a/view_models/y.dart', [1, 1]),
      ['80', 'lib/features/*/view_models/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('2/2'));
  });

  test('a star that is not a whole segment prints usage', () {
    for (final prefix in ['lib/feat*/view_models/', 'lib/**/view_models/']) {
      final result = _run(_record('lib/features/a/view_models/x.dart', [1]), [
        '80',
        prefix,
      ]);
      expect(result.exitCode, 64, reason: prefix);
      expect(result.stderr, contains('usage'), reason: prefix);
    }
  });

  test('regex characters in a prefix are plain text', () {
    // `.` must not match any character: lib.data/ is not lib/data/.
    final result = _run(
      _record('lib/data/a.dart', [1, 1]) + _record('libXdata/b.dart', [0, 0]),
      ['80', 'lib.data/', 'lib/data/'],
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('lib.data/  no files'));
  });

  test('fails when the lcov file is missing', () {
    final result = Process.runSync(Platform.resolvedExecutable, [
      'run',
      'bin/check_coverage.dart',
      'this/file/does/not/exist.info',
      '80',
      'lib/data/',
    ]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('not found'));
  });

  test('wrong arguments print usage', () {
    final result = _run('', ['not-a-number', 'lib/data/']);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('usage'));
  });

  test('fewer than three arguments print usage', () {
    final result = _run(_record('lib/data/a.dart', [1]), ['80']);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('usage'));
  });

  test('a minimum that is not a number from 0 to 100 prints usage', () {
    for (final min in ['NaN', '-1', '101', 'abc']) {
      final result = _run(_record('lib/data/a.dart', [1]), [min, 'lib/data/']);
      expect(result.exitCode, 64, reason: 'min $min');
      expect(result.stderr, contains('usage'), reason: 'min $min');
    }
  });

  test('a prefix without a trailing slash prints usage', () {
    final result = _run(_record('lib/database_x/a.dart', [1]), [
      '80',
      'lib/data',
    ]);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('usage'));
  });

  test('a prefix only matches whole folders', () {
    // lib/data/ must not pick up lib/database_x/, which would pass at 100 %.
    final result = _run(
      _record('lib/data/a.dart', [1, 0]) +
          _record('lib/database_x/b.dart', [1, 1, 1, 1, 1, 1, 1, 1]),
      ['80', 'lib/data/'],
    );
    expect(result.exitCode, 1);
    expect(result.stdout, contains('1/2'));
  });
}
