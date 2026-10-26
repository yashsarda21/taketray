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

  test('a prefix with only generated files has no coverage data', () {
    final result = _run(
      _record('lib/data/a.dart', [1, 1]) +
          _record('lib/domain/a.g.dart', [1, 1]),
      ['80', 'lib/data/', 'lib/domain/'],
    );
    expect(result.exitCode, 1);
    expect(result.stderr, contains('no coverage data for lib/domain/'));
  });

  test('an unknown prefix fails, so a typo cannot pass', () {
    final result = _run(_record('lib/data/a.dart', [1, 1]), ['80', 'lib/dat/']);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('no coverage data for lib/dat/'));
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
}
