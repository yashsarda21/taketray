import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/platform/files_bridge.dart';

import '../../patrol_test/support/patrol_files_bridge.dart';
import '../../patrol_test/support/share_sheet.dart';

/// The fakes the Settings Patrol flows use in place of Android's pickers
/// (D-152, ruling R2): they must never reach outside the folder they are
/// given, and must behave as the real pickers do on a cancel and a failure.
void main() {
  late Directory cache;
  late PatrolFilesBridge bridge;

  setUp(() async {
    cache = Directory.systemTemp.createTempSync('patrol-files-test');
    bridge = await PatrolFilesBridge.create(cache: cache);
  });

  tearDown(() async {
    await bridge.dispose();
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  });

  group('pickFolder', () {
    test('answers the test folder when nothing is queued', () async {
      expect(await bridge.pickFolder(), 'Movies/TakeTray Test');
      expect(await bridge.pickFolder(), 'Movies/TakeTray Test');
    });

    test('answers the queue in order: a path, a cancel, a failure', () async {
      bridge
        ..answerFolder('DCIM/Camera')
        ..answerFolder(null)
        ..answerFolder(
          const FileBridgeException(FilesProblem.unsupportedFolder),
        );
      expect(await bridge.pickFolder(), 'DCIM/Camera');
      expect(await bridge.pickFolder(), isNull);
      await expectLater(
        bridge.pickFolder(),
        throwsA(const FileBridgeException(FilesProblem.unsupportedFolder)),
      );
      expect(await bridge.pickFolder(), 'Movies/TakeTray Test');
      expect(bridge.calls, everyElement('pickFolder'));
    });
  });

  group('documents', () {
    test('saves into the cache and reads the same text back', () async {
      final address = await bridge.saveDocument('a/b.json', 'x/y', '{"a":1}');
      expect(address, isNotNull);
      expect(address, startsWith(cache.path), reason: 'only the cache');
      expect(File(address!).existsSync(), isTrue);
      expect(bridge.saves, 1);
      expect(await bridge.lastSavedText(), '{"a":1}');
      expect(await bridge.openDocument(['*/*'], 100), '{"a":1}');
    });

    test('a cancelled save writes nothing and counts nothing', () async {
      bridge.cancelNextSave();
      expect(await bridge.saveDocument('a.json', 'x/y', 'text'), isNull);
      expect(bridge.saves, 0);
      expect(await bridge.lastSavedText(), isNull);
      // Only the next call is cancelled.
      expect(await bridge.saveDocument('a.json', 'x/y', 'text'), isNotNull);
      expect(bridge.saves, 1);
    });

    test(
      'a cancelled open answers null once; with nothing saved, null',
      () async {
        expect(await bridge.openDocument(['*/*'], 100), isNull);
        await bridge.saveDocument('a.json', 'x/y', 'text');
        bridge.cancelNextOpen();
        expect(await bridge.openDocument(['*/*'], 100), isNull);
        expect(await bridge.openDocument(['*/*'], 100), 'text');
      },
    );

    test(
      'a document over maxBytes is tooLarge; exactly maxBytes is read',
      () async {
        await bridge.saveDocument('a.json', 'x/y', 'abcd');
        await expectLater(
          bridge.openDocument(['*/*'], 3),
          throwsA(const FileBridgeException(FilesProblem.tooLarge)),
        );
        expect(await bridge.openDocument(['*/*'], 4), 'abcd');
      },
    );

    test('a name with slashes stays inside the folder', () async {
      final address = await bridge.saveDocument('../../evil.json', 'x/y', 't');
      expect(File(address!).parent.parent.path, cache.path);
    });

    test(
      'create deletes what an earlier run left; dispose deletes all',
      () async {
        await bridge.saveDocument('a.json', 'x/y', 'old');
        final again = await PatrolFilesBridge.create(cache: cache);
        expect(await again.openDocument(['*/*'], 100), isNull);
        expect(Directory('${cache.path}/patrol-files').listSync(), isEmpty);
        await again.saveDocument('b.json', 'x/y', 'new');
        await again.dispose();
        expect(Directory('${cache.path}/patrol-files').existsSync(), isFalse);
        await again.dispose();
      },
    );
  });

  group('shareFile', () {
    test('fails the flow instead of opening a share sheet', () {
      expect(
        () => bridge.shareFile('p', 'text/plain', 's', 't'),
        throwsStateError,
      );
      expect(bridge.calls, ['shareFile']);
    });

    test('without realShareSheet the real bridge is never asked', () async {
      final real = _RecordingBridge();
      final fake = await PatrolFilesBridge.create(cache: cache, real: real);
      expect(
        () => fake.shareFile('p', 'text/plain', 's', 't'),
        throwsStateError,
      );
      expect(real.shares, isEmpty, reason: 'no real share sheet by mistake');
      await fake.dispose();
    });

    // Flow 4 (Send error log) needs Android's real share sheet: the one
    // flow that opts in passes the call to the real bridge as it is.
    test('with realShareSheet the call reaches the real bridge', () async {
      final real = _RecordingBridge();
      final fake = await PatrolFilesBridge.create(
        cache: cache,
        real: real,
        realShareSheet: true,
      );
      await fake.shareFile('/c/shared/a.txt', 'text/plain', 'S', 'T');
      expect(real.shares, [
        ['/c/shared/a.txt', 'text/plain', 'S', 'T'],
      ]);
      expect(fake.calls, ['shareFile']);
      await fake.dispose();
    });

    test('with realShareSheet a real failure reaches the caller', () async {
      final real = _RecordingBridge(
        shareError: const FileBridgeException(FilesProblem.invalidPath),
      );
      final fake = await PatrolFilesBridge.create(
        cache: cache,
        real: real,
        realShareSheet: true,
      );
      await expectLater(
        fake.shareFile('p', 'text/plain', 's', 't'),
        throwsA(const FileBridgeException(FilesProblem.invalidPath)),
      );
      expect(real.shares, hasLength(1));
      await fake.dispose();
    });

    test('with realShareSheet the pickers stay fake', () async {
      final real = _RecordingBridge();
      final fake = await PatrolFilesBridge.create(
        cache: cache,
        real: real,
        realShareSheet: true,
      );
      expect(await fake.pickFolder(), 'Movies/TakeTray Test');
      expect(await fake.saveDocument('a.json', 'x/y', 't'), isNotNull);
      expect(await fake.openDocument(['*/*'], 100), 't');
      expect(real.others, isEmpty, reason: 'only shareFile is real');
      await fake.dispose();
    });
  });

  group('the share sheet ids', () {
    test('the chooser is told by AOSP resource ids only', () {
      expect(isChooserId('android:id/resolver_list'), isTrue);
      expect(isChooserId('android:id/profile_pager'), isTrue);
      expect(isChooserId('com.android.intentresolver:id/contentPanel'), isTrue);
      expect(isChooserId('app.taketray.dev:id/anything'), isFalse);
      expect(isChooserId('android:id/content'), isFalse);
      expect(
        isChooserId('com.android.permissioncontroller:id/permission_allow'),
        isFalse,
      );
      expect(isChooserId(null), isFalse);
    });

    test('a second signal needs no id: the app is covered', () {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
      ]) {
        expect(sheetIsUp(chooserViewSeen: false, lifecycle: state), isTrue);
      }
      expect(
        sheetIsUp(chooserViewSeen: false, lifecycle: AppLifecycleState.resumed),
        isFalse,
      );
      expect(sheetIsUp(chooserViewSeen: false), isFalse, reason: 'unknown');
      expect(
        sheetIsUp(chooserViewSeen: false),
        isFalse,
        reason: 'a null state (Patrol wipes it between tests) is not covered',
      );
      expect(appIsCovered(null), isFalse);
      expect(appIsCovered(AppLifecycleState.resumed), isFalse);
      expect(appIsCovered(AppLifecycleState.paused), isTrue);
      expect(
        sheetIsUp(chooserViewSeen: true),
        isTrue,
        reason: 'the id signal still counts with a null state',
      );
      expect(
        sheetIsUp(chooserViewSeen: true, lifecycle: AppLifecycleState.resumed),
        isTrue,
      );
    });
  });
}

/// A real bridge stand-in that records what reached it.
class _RecordingBridge implements FilesBridge {
  _RecordingBridge({this.shareError});

  final FileBridgeException? shareError;
  final List<List<String>> shares = [];
  final List<String> others = [];

  @override
  Future<void> shareFile(
    String path,
    String mimeType,
    String subject,
    String text,
  ) async {
    shares.add([path, mimeType, subject, text]);
    if (shareError != null) throw shareError!;
  }

  @override
  Future<String?> saveDocument(
    String suggestedName,
    String mimeType,
    String text,
  ) async {
    others.add('saveDocument');
    return null;
  }

  @override
  Future<String?> openDocument(List<String> mimeTypes, int maxBytes) async {
    others.add('openDocument');
    return null;
  }

  @override
  Future<String?> pickFolder() async {
    others.add('pickFolder');
    return null;
  }

  @override
  Future<AppInfo> appInfo() async =>
      const AppInfo(versionName: '1', androidRelease: '17');
}
