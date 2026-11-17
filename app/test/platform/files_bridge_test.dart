import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/platform/files_api.g.dart';
import 'package:taketray/platform/files_bridge.dart';

/// A [FilesHostApi] whose answers a test sets, and which remembers the
/// arguments it was called with.
class _StubApi extends FilesHostApi {
  String? saved = 'content://doc/1';
  String? opened = '{}';
  String? folder = 'DCIM/Camera';
  AppInfoMsg info = AppInfoMsg(versionName: '1.2.3', androidRelease: '15');
  Exception? error;

  final List<String> calls = [];
  List<Object?> args = [];

  void _record(String name, [List<Object?> arguments = const []]) {
    calls.add(name);
    args = arguments;
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<void> shareFile(
    String path,
    String mimeType,
    String subject,
    String text,
  ) async => _record('shareFile', [path, mimeType, subject, text]);

  @override
  Future<String?> saveDocument(
    String suggestedName,
    String mimeType,
    String text,
  ) async {
    _record('saveDocument', [suggestedName, mimeType, text]);
    return saved;
  }

  @override
  Future<String?> openDocument(List<String> mimeTypes, int maxBytes) async {
    _record('openDocument', [mimeTypes, maxBytes]);
    return opened;
  }

  @override
  Future<String?> pickFolder() async {
    _record('pickFolder');
    return folder;
  }

  @override
  Future<AppInfoMsg> appInfo() async {
    _record('appInfo');
    return info;
  }
}

void main() {
  late _StubApi api;
  late PigeonFilesBridge bridge;

  setUp(() {
    api = _StubApi();
    bridge = PigeonFilesBridge(api);
  });

  /// One call of each method.
  List<Future<Object?> Function()> everyCall() => [
    () => bridge.shareFile('/cache/shared/a.txt', 'text/plain', 's', 't'),
    () => bridge.saveDocument('a.json', 'application/json', '{}'),
    () => bridge.openDocument(['application/json'], 10),
    bridge.pickFolder,
    bridge.appInfo,
  ];

  test('shareFile passes the path, type, subject and text', () async {
    await bridge.shareFile(
      '/data/cache/shared/log.txt',
      'text/plain',
      'TakeTray error log',
      'TakeTray 1.2.3 on Android 15',
    );
    expect(api.calls, ['shareFile']);
    expect(api.args, [
      '/data/cache/shared/log.txt',
      'text/plain',
      'TakeTray error log',
      'TakeTray 1.2.3 on Android 15',
    ]);
  });

  test('saveDocument passes its arguments and answers the address', () async {
    expect(
      await bridge.saveDocument('b.json', 'application/json', '{"a":1}'),
      'content://doc/1',
    );
    expect(api.args, ['b.json', 'application/json', '{"a":1}']);
    api.saved = null;
    expect(await bridge.saveDocument('b.json', 'application/json', ''), null);
  });

  test(
    'openDocument passes the types and the limit and answers the text',
    () async {
      expect(
        await bridge.openDocument(['application/json', '*/*'], 20000000),
        '{}',
      );
      expect(api.args, [
        ['application/json', '*/*'],
        20000000,
      ]);
      api.opened = null;
      expect(await bridge.openDocument(['*/*'], 1), null);
    },
  );

  test('pickFolder answers the path, the root and a cancel', () async {
    expect(await bridge.pickFolder(), 'DCIM/Camera');
    api.folder = '';
    expect(await bridge.pickFolder(), '');
    api.folder = null;
    expect(await bridge.pickFolder(), null);
  });

  test('appInfo maps the message', () async {
    expect(
      await bridge.appInfo(),
      const AppInfo(versionName: '1.2.3', androidRelease: '15'),
    );
  });

  test(
    'each PlatformException code becomes its FilesProblem, on every call',
    () async {
      const problems = {
        'invalid_path': FilesProblem.invalidPath,
        'too_large': FilesProblem.tooLarge,
        'unsupported_folder': FilesProblem.unsupportedFolder,
        // Everything else is a failure the user can only retry.
        'busy': FilesProblem.failed,
        'host-gone': FilesProblem.failed,
        'no-activity': FilesProblem.failed,
        'native-error': FilesProblem.failed,
        'channel-error': FilesProblem.failed,
        'something-new': FilesProblem.failed,
        'INVALID_PATH': FilesProblem.failed,
      };
      for (final MapEntry(key: code, value: problem) in problems.entries) {
        api.error = PlatformException(code: code, message: 'x failed');
        for (final call in everyCall()) {
          await expectLater(
            call(),
            throwsA(
              isA<FileBridgeException>().having(
                (e) => e.problem,
                code,
                problem,
              ),
            ),
          );
        }
      }
    },
  );

  test('an error that is not a PlatformException passes through', () async {
    final error = Exception('not a channel error');
    api.error = error;
    for (final call in everyCall()) {
      await expectLater(call(), throwsA(same(error)));
    }
    expect(api.calls, hasLength(5));
  });

  test('the value types compare by value and say no path (D-10)', () {
    expect(
      const FileBridgeException(FilesProblem.tooLarge),
      const FileBridgeException(FilesProblem.tooLarge),
    );
    expect(
      const FileBridgeException(FilesProblem.tooLarge).hashCode,
      const FileBridgeException(FilesProblem.tooLarge).hashCode,
    );
    expect(
      const FileBridgeException(FilesProblem.tooLarge),
      isNot(const FileBridgeException(FilesProblem.failed)),
    );
    expect(
      const FileBridgeException(FilesProblem.invalidPath).toString(),
      'FileBridgeException(invalidPath)',
    );
    expect(
      const AppInfo(versionName: '1', androidRelease: '15'),
      isNot(const AppInfo(versionName: '1', androidRelease: '14')),
    );
    expect(
      const AppInfo(versionName: '1', androidRelease: '15').hashCode,
      const AppInfo(versionName: '1', androidRelease: '15').hashCode,
    );
    expect(
      const AppInfo(versionName: '1.0.0', androidRelease: '15').toString(),
      'AppInfo(1.0.0, Android 15)',
    );
  });

  test('the provider builds the Pigeon bridge and keeps it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(filesBridgeProvider);
    expect(first, isA<PigeonFilesBridge>());
    expect(container.read(filesBridgeProvider), same(first));
  });
}
