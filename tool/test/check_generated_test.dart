import 'dart:io';

import 'package:test/test.dart';

// tool/check_generated runs against a throwaway repo whose tool/dart is a
// stand-in for build_runner, drift_dev and pigeon: it rewrites the generated
// files to a fixed "canonical" content, like a real regeneration would. That
// makes the hash comparison the thing under test, not build_runner itself.
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
  "run pigeon")
    [ -f ../fail_pigeon ] && exit 4
    mkdir -p lib/platform android/app/src/main/kotlin/app/media
    printf 'canonical\n' > lib/platform/media_api.g.dart
    printf 'canonical\n' > android/app/src/main/kotlin/app/media/MediaApi.g.kt
    ;;
  "run drift_dev")
    # Like make-migrations from schema v2 on: the dump, the steps helper next
    # to the database class, the schema helpers, and the migration test only
    # when there is none yet.
    mkdir -p drift_schemas/db test/drift/db/generated lib/data
    printf 'canonical\n' > drift_schemas/db/drift_schema_v1.json
    printf 'canonical\n' > lib/data/db.steps.dart
    printf 'canonical\n' > test/drift/db/generated/schema.dart
    printf 'canonical\n' > test/drift/db/generated/schema_v1.dart
    [ -f test/drift/db/migration_test.dart ] ||
      printf 'template\n' > test/drift/db/migration_test.dart
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

  test('does not run pigeon without pigeon in dev_dependencies', () async {
    _write('app/pigeons/media_api.dart', '// contract\n');
    await _run();
    expect(_log(), isNot(contains('pigeon')));
  });

  test('does not run drift_dev without databases in build.yaml', () async {
    await _run();
    expect(_log(), contains('run build_runner build'));
    expect(_log(), isNot(contains('drift_dev')));
  });

  group('with pigeon in dev_dependencies', () {
    const dartOut = 'app/lib/platform/media_api.g.dart';
    const kotlinOut = 'app/android/app/src/main/kotlin/app/media/MediaApi.g.kt';

    setUp(() {
      _write(
        'app/pubspec.yaml',
        'name: app\ndev_dependencies:\n  build_runner: ^2.0.0\n'
            '  pigeon: 29.0.11\n',
      );
      _write('app/pigeons/media_api.dart', '// contract\n');
      _write(dartOut, 'canonical\n');
      _write(kotlinOut, 'canonical\n');
    });

    test(
      'runs pigeon for the contract before build_runner, and passes',
      () async {
        final result = await _run();
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(result.stdout, contains('generated files fresh'));
        final log = _log();
        expect(log, contains('run pigeon --input pigeons/media_api.dart'));
        expect(
          log.indexOf('run pigeon'),
          lessThan(log.indexOf('run build_runner')),
        );
      },
    );

    test('formats the Dart output Pigeon wrote, before build_runner', () async {
      await _run();
      final log = _log();
      expect(log, contains('format $dartOut'));
      expect(log.indexOf('run pigeon'), lessThan(log.indexOf('format ')));
      expect(log.indexOf('format '), lessThan(log.indexOf('run build_runner')));
    });

    test('runs pigeon for every file in pigeons/', () async {
      _write('app/pigeons/other_api.dart', '// another contract\n');
      await _run();
      expect(_log(), contains('--input pigeons/media_api.dart'));
      expect(_log(), contains('--input pigeons/other_api.dart'));
    });

    test('fails on an edited Dart output, and regenerates it', () async {
      _write(dartOut, 'edited by hand\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: $dartOut'));
      expect(File('${repo.path}/$dartOut').readAsStringSync(), 'canonical\n');
    });

    test('fails on an edited Kotlin output', () async {
      _write(kotlinOut, 'edited by hand\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: $kotlinOut'));
      expect(result.stdout, isNot(contains('media_api.g.dart')));
    });

    test('fails on a Kotlin output that was never committed', () async {
      File('${repo.path}/$kotlinOut').deleteSync();
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: $kotlinOut'));
    });

    test(
      'fails on a leftover Kotlin file that is no longer produced',
      () async {
        const orphan = 'app/android/app/src/main/kotlin/app/media/Old.g.kt';
        _write(orphan, 'old\n');
        final result = await _run();
        expect(result.exitCode, 1);
        expect(result.stdout, contains('stale: $orphan'));
        expect(File('${repo.path}/$orphan').existsSync(), isFalse);
      },
    );

    test('ignores hand-written Kotlin files', () async {
      _write('app/android/app/src/main/kotlin/app/media/Impl.kt', 'class A\n');
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('fails, and never says fresh, when pigeon fails', () async {
      _write('fail_pigeon', '');
      final result = await _run();
      expect(result.exitCode, isNot(0));
      expect(result.stdout, isNot(contains('generated files fresh')));
    });

    test('finds a member that has pigeon but not build_runner', () async {
      // No build_runner here, so its outputs are not expected either.
      File('${repo.path}/app/lib/a.g.dart').deleteSync();
      File('${repo.path}/app/lib/b.freezed.dart').deleteSync();
      _write(
        'app/pubspec.yaml',
        'name: app\ndev_dependencies:\n  pigeon: 29.0.11\n',
      );
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(_log(), contains('run pigeon'));
      expect(_log(), isNot(contains('build_runner')));
    });

    test('ignores pigeon outside dev_dependencies', () async {
      _write(
        'app/pubspec.yaml',
        'name: app\ndependencies:\n  pigeon: 29.0.11\n',
      );
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stderr, contains('no member with build_runner'));
    });
  });

  group('with drift databases in build.yaml', () {
    const steps = 'app/lib/data/db.steps.dart';
    const helper = 'app/test/drift/db/generated/schema_v1.dart';
    const migrationTest = 'app/test/drift/db/migration_test.dart';
    const schemaTest = 'app/test/drift/db/schema_test.dart';

    setUp(() {
      _write('app/build.yaml', 'options:\n  databases:\n    app: x.dart\n');
      _write('app/drift_schemas/db/drift_schema_v1.json', 'canonical\n');
      _write(steps, 'canonical\n');
      _write('app/test/drift/db/generated/schema.dart', 'canonical\n');
      _write(helper, 'canonical\n');
      _write(migrationTest, 'filled in by hand\n');
      _write(schemaTest, 'written by hand\n');
    });

    test('runs make-migrations and passes when fresh', () async {
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(_log(), contains('run drift_dev make-migrations'));
    });

    test('keeps old schema dumps, which cannot be regenerated', () async {
      _write('app/drift_schemas/db/drift_schema_v0.json', 'old dump\n');
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('${repo.path}/app/drift_schemas/db/drift_schema_v0.json')
            .existsSync(),
        isTrue,
      );
    });

    test('fails on a stale drift schema', () async {
      _write('app/drift_schemas/db/drift_schema_v1.json', 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('stale: app/drift_schemas/db/drift_schema_v1.json'),
      );
    });

    test('fails on a stale schema helper under test/drift', () async {
      _write('app/test/drift/db/generated/schema.dart', 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('stale: app/test/drift/db/generated/schema.dart'),
      );
    });

    test(
      'fails on a stale schema_v*.dart helper, and regenerates it',
      () async {
        _write(helper, 'old\n');
        final result = await _run();
        expect(result.exitCode, 1);
        expect(result.stdout, contains('stale: $helper'));
        expect(File('${repo.path}/$helper').readAsStringSync(), 'canonical\n');
      },
    );

    test('fails on a leftover schema helper that is no longer produced, and '
        'deletes it', () async {
      const orphan = 'app/test/drift/db/generated/schema_v9.dart';
      _write(orphan, 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: $orphan'));
      expect(File('${repo.path}/$orphan').existsSync(), isFalse);
    });

    test(
      'fails on a stale *.steps.dart under lib/, and regenerates it',
      () async {
        _write(steps, 'edited by hand\n');
        final result = await _run();
        expect(result.exitCode, 1);
        expect(result.stdout, contains('stale: $steps'));
        expect(result.stdout, isNot(contains('migration_test')));
        expect(File('${repo.path}/$steps').readAsStringSync(), 'canonical\n');
      },
    );

    test('fails on a *.steps.dart that was never committed', () async {
      File('${repo.path}/$steps').deleteSync();
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: $steps'));
    });

    test('fails on a leftover *.steps.dart that is no longer produced, and '
        'deletes it', () async {
      const orphan = 'app/lib/data/old.steps.dart';
      _write(orphan, 'old\n');
      final result = await _run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('stale: $orphan'));
      expect(File('${repo.path}/$orphan').existsSync(), isFalse);
    });

    test('never deletes or rewrites the hand-filled migration_test.dart and '
        'schema_test.dart', () async {
      final result = await _run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('generated files fresh'));
      expect(
        File('${repo.path}/$migrationTest').readAsStringSync(),
        'filled in by hand\n',
      );
      expect(
        File('${repo.path}/$schemaTest').readAsStringSync(),
        'written by hand\n',
      );
    });
  });
}
