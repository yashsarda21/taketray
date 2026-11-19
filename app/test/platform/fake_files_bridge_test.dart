import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/platform/files_bridge.dart';

import '../support/fake_files_bridge.dart';

void main() {
  late FakeFilesBridge fake;

  setUp(() => fake = FakeFilesBridge());

  test('every call is recorded in order with its arguments', () async {
    await fake.shareFile('/c/shared/a.txt', 'text/plain', 's', 't');
    await fake.saveDocument('a.json', 'application/json', '{}');
    await fake.openDocument(['application/json'], 10);
    await fake.pickFolder();
    await fake.appInfo();
    // A record's List field compares by identity: compare the arguments deeply.
    expect(
      [for (final c in fake.calls) c.args],
      [
        ['/c/shared/a.txt', 'text/plain', 's', 't'],
        ['a.json', 'application/json', '{}'],
        [
          ['application/json'],
          10,
        ],
        <Object?>[],
        <Object?>[],
      ],
    );
    expect(fake.methods, [
      'shareFile',
      'saveDocument',
      'openDocument',
      'pickFolder',
      'appInfo',
    ]);
  });

  test('the defaults: saved, cancelled pickers, a version', () async {
    expect(
      await fake.saveDocument('a.json', 'application/json', '{}'),
      isNotNull,
    );
    expect(await fake.openDocument(['*/*'], 10), isNull);
    expect(await fake.pickFolder(), isNull);
    expect(
      await fake.appInfo(),
      const AppInfo(versionName: '1.0.0', androidRelease: '15'),
    );
  });

  test('the answers are what the test sets', () async {
    fake
      ..saveAnswer = null
      ..openAnswer = '{"a":1}'
      ..folderAnswer = 'Movies/TakeTray Test'
      ..appInfoAnswer = const AppInfo(versionName: '2', androidRelease: '16');
    expect(await fake.saveDocument('a.json', 'application/json', '{}'), null);
    expect(await fake.openDocument(['*/*'], 10), '{"a":1}');
    expect(await fake.pickFolder(), 'Movies/TakeTray Test');
    expect(
      await fake.appInfo(),
      const AppInfo(versionName: '2', androidRelease: '16'),
    );
  });

  test('saved keeps what each answered save wrote, and only those', () async {
    await fake.saveDocument('a.json', 'application/json', 'one');
    fake.saveAnswer = null;
    await fake.saveDocument('b.json', 'application/json', 'cancelled');
    fake
      ..saveAnswer = 'content://x'
      ..failNext('saveDocument');
    await expectLater(
      fake.saveDocument('c.json', 'application/json', 'failed'),
      throwsA(isA<FileBridgeException>()),
    );
    expect(fake.saved, [(name: 'a.json', text: 'one')]);
  });

  test(
    'failNext fails the next calls of one method with the problem',
    () async {
      fake
        ..failNext('pickFolder', FilesProblem.unsupportedFolder)
        ..failNext('pickFolder');
      await expectLater(
        fake.pickFolder(),
        throwsA(const FileBridgeException(FilesProblem.unsupportedFolder)),
      );
      await expectLater(
        fake.pickFolder(),
        throwsA(const FileBridgeException(FilesProblem.failed)),
      );
      expect(await fake.pickFolder(), isNull);
      // Another method is not touched, and a failed call is still recorded.
      expect(await fake.appInfo(), isA<AppInfo>());
      expect(fake.methods, [
        'pickFolder',
        'pickFolder',
        'pickFolder',
        'appInfo',
      ]);
    },
  );

  test('every method can fail', () async {
    const methods = [
      'shareFile',
      'saveDocument',
      'openDocument',
      'pickFolder',
      'appInfo',
    ];
    for (final method in methods) {
      fake.failNext(method, FilesProblem.tooLarge);
    }
    final calls = <Future<Object?> Function()>[
      () => fake.shareFile('p', 'text/plain', 's', 't'),
      () => fake.saveDocument('a', 'application/json', '{}'),
      () => fake.openDocument(['*/*'], 1),
      fake.pickFolder,
      fake.appInfo,
    ];
    for (final call in calls) {
      await expectLater(
        call(),
        throwsA(const FileBridgeException(FilesProblem.tooLarge)),
      );
    }
  });

  test(
    'hold keeps a call waiting, after it is recorded, until release',
    () async {
      fake
        ..openAnswer = 'text'
        ..hold('openDocument');
      var done = false;
      final open = fake.openDocument(['*/*'], 1).then((t) {
        done = true;
        return t;
      });
      await pumpEventQueue();
      expect(fake.methods, ['openDocument']);
      expect(done, isFalse);
      fake.release('openDocument');
      expect(await open, 'text');
      // Released: the next call answers at once.
      expect(await fake.openDocument(['*/*'], 1), 'text');
    },
  );

  test('a held call that is set to fail fails after the release', () async {
    fake
      ..hold('shareFile')
      ..failNext('shareFile');
    final share = fake.shareFile('p', 'text/plain', 's', 't');
    unawaited(fake.pumpRelease('shareFile'));
    await expectLater(share, throwsA(isA<FileBridgeException>()));
  });
}

extension on FakeFilesBridge {
  Future<void> pumpRelease(String method) async {
    await pumpEventQueue();
    release(method);
  }
}
