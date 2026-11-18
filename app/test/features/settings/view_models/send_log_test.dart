import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/features/settings/view_models/send_log.dart';
import 'package:taketray/platform/files_bridge.dart';

import '../../../support/fake_files_bridge.dart';
import '../../../support/fixed_clock.dart';

/// A [SendLog] on fakes: the bridge, two temp folders and a clock.
class _Rig {
  _Rig({Directory? cache}) {
    root = Directory.systemTemp.createTempSync('taketray_send_log_test');
    logDir = Directory('${root.path}/support')..createSync();
    cacheDir = cache ?? (Directory('${root.path}/cache')..createSync());
    container = ProviderContainer.test(
      overrides: [
        filesBridgeProvider.overrideWithValue(files),
        logDirectoryProvider.overrideWith((ref) async => logDir),
        cacheDirectoryProvider.overrideWith((ref) async => cacheDir),
        clockProvider.overrideWithValue(
          FixedClock(DateTime(2026, 11, 17, 14, 30)),
        ),
      ],
    );
  }

  late final Directory root;
  late final Directory logDir;
  late final Directory cacheDir;
  late final ProviderContainer container;
  final FakeFilesBridge files = FakeFilesBridge();

  void writeLog(int index, String text) =>
      File('${logDir.path}/taketray-$index.log').writeAsStringSync(text);

  Future<SendLogOutcome> send() => container.read(sendLogProvider).send();

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

void main() {
  late _Rig rig;

  setUp(() => rig = _Rig());
  tearDown(() => rig.dispose());

  group('sharing', () {
    test(
      'the bundle is shared with the subject and the version text',
      () async {
        rig
          ..writeLog(1, 'old\n')
          ..writeLog(0, 'new\n');

        final outcome = await rig.send();

        expect(outcome, SendLogOutcome.shared);
        expect(rig.files.methods, ['appInfo', 'shareFile']);
        final share = rig.files.calls.last.args;
        expect(share, [
          '${rig.cacheDir.path}/shared/taketray-log-2026-11-17-1430.txt',
          'text/plain',
          'TakeTray error log',
          'TakeTray 1.0.0 on Android 15',
        ]);
        expect(File(share.first! as String).readAsStringSync(), 'old\nnew\n');
      },
    );

    test(
      'the text carries the version and release the phone answers',
      () async {
        rig.writeLog(0, 'a\n');
        rig.files.appInfoAnswer = const AppInfo(
          versionName: '2.4.1',
          androidRelease: '13',
        );

        await rig.send();

        expect(rig.files.calls.last.args[3], 'TakeTray 2.4.1 on Android 13');
      },
    );

    test(
      'the share text is the version and release and nothing else',
      () async {
        rig.writeLog(0, 'a\n');

        await rig.send();

        final text = rig.files.calls.last.args[3]! as String;
        expect(text, matches(RegExp(r'^TakeTray [\d.]+ on Android \d+$')));
      },
    );

    test('appInfo fails: the text has no version, and the log is still '
        'shared', () async {
      rig.writeLog(0, 'a\n');
      rig.files.failNext('appInfo');

      final outcome = await rig.send();

      expect(outcome, SendLogOutcome.shared);
      expect(rig.files.calls.last.args[3], 'TakeTray on Android');
    });

    test('a blank version or release is left out of the text', () async {
      rig.writeLog(0, 'a\n');
      rig.files.appInfoAnswer = const AppInfo(
        versionName: '',
        androidRelease: '15',
      );
      await rig.send();
      rig.files.appInfoAnswer = const AppInfo(
        versionName: '1.0.0',
        androidRelease: '',
      );
      await rig.send();
      rig.files.appInfoAnswer = const AppInfo(
        versionName: '',
        androidRelease: '',
      );
      await rig.send();

      expect(
        [
          for (final c in rig.files.calls)
            if (c.method == 'shareFile') c.args[3],
        ],
        [
          'TakeTray on Android 15',
          'TakeTray 1.0.0 on Android',
          'TakeTray on Android',
        ],
      );
    });

    test('each send shares the bundle made then, and keeps one', () async {
      rig.writeLog(0, 'first\n');
      await rig.send();
      rig.writeLog(0, 'first\nsecond\n');

      await rig.send();

      final shared = Directory('${rig.cacheDir.path}/shared').listSync();
      expect(shared, hasLength(1));
      expect((shared.single as File).readAsStringSync(), 'first\nsecond\n');
    });
  });

  group('nothing to send', () {
    test('no log yet: nothing, and the share sheet is not opened', () async {
      final outcome = await rig.send();

      expect(outcome, SendLogOutcome.nothing);
      expect(rig.files.methods, isNot(contains('shareFile')));
    });

    test('empty logs: nothing', () async {
      rig
        ..writeLog(1, '')
        ..writeLog(0, '');

      expect(await rig.send(), SendLogOutcome.nothing);
      expect(rig.files.methods, isNot(contains('shareFile')));
    });
  });

  group('failures', () {
    for (final problem in FilesProblem.values) {
      test('shareFile throws $problem: failed', () async {
        rig.writeLog(0, 'a\n');
        rig.files.failNext('shareFile', problem);

        expect(await rig.send(), SendLogOutcome.failed);
      });
    }

    test('a bundle that cannot be written: failed, and no share', () async {
      rig.writeLog(0, 'a\n');
      // `shared` cannot be made inside a file.
      final blocker = File('${rig.root.path}/blocker')..writeAsStringSync('x');
      final broken = _Rig(cache: Directory(blocker.path));
      addTearDown(broken.dispose);
      broken.writeLog(0, 'a\n');

      expect(await broken.send(), SendLogOutcome.failed);
      expect(broken.files.methods, isNot(contains('shareFile')));
    });

    test('a log folder that cannot be found: failed', () async {
      final container = ProviderContainer.test(
        overrides: [
          filesBridgeProvider.overrideWithValue(rig.files),
          logDirectoryProvider.overrideWith(
            (ref) async => throw const FileSystemException('gone'),
          ),
          cacheDirectoryProvider.overrideWith((ref) async => rig.cacheDir),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 17))),
        ],
      );

      expect(
        await container.read(sendLogProvider).send(),
        SendLogOutcome.failed,
      );
      expect(rig.files.calls, isEmpty);
    });
  });

  group('what is logged (D-10)', () {
    test('outcomes only: never a path or a name from the log', () async {
      final records = <String>[];
      final sub = Logger.root.onRecord.listen(
        (r) => records.add('${r.message} ${r.error ?? ''}'),
      );
      addTearDown(sub.cancel);
      Logger.root.level = Level.ALL;
      rig.writeLog(0, 'secret reel name\n');
      await rig.send();
      rig.files.failNext('shareFile');
      await rig.send();
      await rig.send();
      await pumpEventQueue();

      expect(records, isNotEmpty);
      for (final record in records) {
        expect(record, isNot(contains(rig.root.path)));
        expect(record, isNot(contains('taketray-log')));
        expect(record, isNot(contains('secret reel name')));
      }
    });
  });

  group('the folders', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final asked = <String>[];

    setUp(() {
      asked.clear();
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            asked.add(call.method);
            return switch (call.method) {
              'getApplicationSupportDirectory' => '/files',
              'getTemporaryDirectory' => '/cache',
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'the logs are in the support folder, where main writes them',
      () async {
        final container = ProviderContainer.test();

        final dir = await container.read(logDirectoryProvider.future);

        expect(dir.path, '/files');
        expect(asked, ['getApplicationSupportDirectory']);
      },
    );

    test('the bundle goes to the temporary folder, the cache that Android '
        'shares from', () async {
      final container = ProviderContainer.test();

      final dir = await container.read(cacheDirectoryProvider.future);

      expect(dir.path, '/cache');
      expect(asked, ['getTemporaryDirectory']);
    });
  });
}
