import 'dart:io';

import 'package:test/test.dart';

// tool/check_generated runs against a throwaway repo whose tool/dart is a
// stand-in for build_runner (and drift_dev): it rewrites the generated files
// to a fixed "canonical" content, like a real regeneration would. That makes
// the hash comparison the thing under test, not build_runner itself.
const _fakeDart = r'''
#!/usr/bin/env bash
set -euo pipefail
log="$(dirname "$0")/../stub.log"
echo "$(basename "$PWD") $*" >> "$log"
case "$1 $2" in
  "run build_runner")
    [ -f ../fail_generator ] && exit 3
    printf 'canonical\n' > lib/a.g.dart
    printf 'canonical\n' > lib/b.freezed.dart
    ;;
  "run drift_dev")
    mkdir -p drift_schemas test/drift
    printf 'canonical\n' > drift_schemas/drift_schema_v1.json
    printf 'canonical\n' > test/drift/schema.dart
    ;;
esac
''';

const _freshFiles = {
  'app/lib/a.g.dart': 'canonical\n',
  'app/lib/b.freezed.dart': 'canonical\n',
};

late Directory repo;

void _write(String path, String content) {
  final file = File('${repo.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<ProcessResult> _run([List<String> args = const []]) => Process.run(
  '${repo.path}/tool/check_generated',
  args,
  workingDirectory: repo.path,
);

String _log() {
  final file = File('${repo.path}/stub.log');
  return file.existsSync() ? file.readAsStringSync() : '';
}

void main() {
  setUp(() async {
    repo = Directory.systemTemp.createTempSync('check_generated_test');
    Directory('${repo.path}/tool').createSync();
    File('check_generated').copySync('${repo.path}/tool/check_generated');
    _write('tool/dart', _fakeDart.trimLeft());
    await Process.run('chmod', [
      '+x',
      '${repo.path}/tool/dart',
      '${repo.path}/tool/check_generated',
    ]);
    _write(
      'app/pubspec.yaml',
      'name: app\ndev_dependencies:\n  build_runner: ^2.0.0\n',
    );
    _freshFiles.forEach(_write);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  test('passes when the generated files are fresh', () async {
    final result = await _run();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('generated files fresh'));
    expect(result.stdout, isNot(contains('stale:')));
  });

  test('fails on an edited file, and regenerates it', () async {
    _write('app/lib/a.g.dart', 'edited by hand\n');
    final result = await _run();
    expect(result.exitCode, 1);
    expect(result.stdout, contains('stale: app/lib/a.g.dart'));
    expect(result.stdout, isNot(contains('b.freezed.dart')));
    expect(result.stderr, contains('out of date and have been regenerated'));
    expect(
      File('${repo.path}/app/lib/a.g.dart').readAsStringSync(),
      'canonical\n',
    );
    // Running again finds nothing to fix.
    expect((await _run()).exitCode, 0);
  });

  test('fails on a generated file that was never committed', () async {
    File('${repo.path}/app/lib/b.freezed.dart').deleteSync();
    final result = await _run();
    expect(result.exitCode, 1);
    expect(result.stdout, contains('stale: app/lib/b.freezed.dart'));
  });

  test(
    'fails on a leftover generated file that is no longer produced',
    () async {
      _write('app/lib/orphan.g.dart', 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: app/lib/orphan.g.dart'));
      expect(File('${repo.path}/app/lib/orphan.g.dart').existsSync(), isFalse);
    },
  );

  test('ignores hand-written files', () async {
    _write('app/lib/hand_written.dart', 'void main() {}\n');
    _write('app/test/hand_written_test.dart', 'void main() {}\n');
    final result = await _run();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('fails, and never says fresh, when the generator fails', () async {
    _write('fail_generator', '');
    final result = await _run();
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains('generated files fresh')));
  });

  test('ignores build_runner outside dev_dependencies', () async {
    _write(
      'app/pubspec.yaml',
      'name: app\ndependencies:\n  build_runner: ^2.0.0\n'
          'dev_dependencies:\n  test: ^1.0.0\n',
    );
    final result = await _run();
    expect(result.exitCode, 1);
    expect(result.stderr, contains('no member with build_runner'));
  });

  test('skips members without build_runner', () async {
    _write('packages/other/pubspec.yaml', 'name: other\n');
    _write('packages/other/lib/x.g.dart', 'would be stale\n');
    final result = await _run();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(_log(), isNot(contains('other')));
  });

  test('fails when no member uses build_runner', () async {
    _write('app/pubspec.yaml', 'name: app\n');
    final result = await _run();
    expect(result.exitCode, 1);
    expect(result.stderr, contains('no member with build_runner'));
  });

  test('does not run drift_dev without databases in build.yaml', () async {
    await _run();
    expect(_log(), contains('run build_runner build'));
    expect(_log(), isNot(contains('drift_dev')));
  });

  group('with drift databases in build.yaml', () {
    setUp(() {
      _write('app/build.yaml', 'options:\n  databases:\n    app: x.dart\n');
      _write('app/drift_schemas/drift_schema_v1.json', 'canonical\n');
      _write('app/test/drift/schema.dart', 'canonical\n');
    });

    test('runs make-migrations and passes when fresh', () async {
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(_log(), contains('run drift_dev make-migrations'));
    });

    test('keeps old schema dumps, which cannot be regenerated', () async {
      _write('app/drift_schemas/drift_schema_v0.json', 'old dump\n');
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('${repo.path}/app/drift_schemas/drift_schema_v0.json')
            .existsSync(),
        isTrue,
      );
    });

    test('fails on a stale drift schema', () async {
      _write('app/drift_schemas/drift_schema_v1.json', 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('stale: app/drift_schemas/drift_schema_v1.json'),
      );
    });

    test('fails on a stale schema helper under test/drift', () async {
      _write('app/test/drift/schema.dart', 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: app/test/drift/schema.dart'));
    });
  });
}
