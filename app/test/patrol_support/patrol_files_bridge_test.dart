import 'dart:io';

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

  test('shareFile fails the flow instead of opening a share sheet', () {
    expect(
      () => bridge.shareFile('p', 'text/plain', 's', 't'),
      throwsStateError,
    );
    expect(bridge.calls, ['shareFile']);
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
  });
}
