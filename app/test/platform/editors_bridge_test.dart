import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/editors_api.g.dart';
import 'package:taketray/platform/editors_bridge.dart';

/// An [EditorsHostApi] whose answers a test sets, and which remembers the
/// arguments it was called with.
class _StubApi extends EditorsHostApi {
  List<InstalledAppMsg> appList = [];
  SendResultMsg sendResult = SendResultMsg.sent;
  bool boolResult = true;
  int free = 0;
  List<String> folders = [];
  List<int> existing = [];
  DeleteReportMsg report = DeleteReportMsg(
    deleted: [],
    gone: [],
    refused: [],
    failed: [],
  );
  List<CopyFolderFileMsg> files = [];
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
  Future<List<InstalledAppMsg>> apps(
    List<String> packageNames,
    int iconPx,
  ) async {
    _record('apps', [packageNames, iconPx]);
    return appList;
  }

  @override
  Future<SendResultMsg> sendTo(
    String packageName,
    List<ShareClipMsg> clips,
  ) async {
    _record('sendTo', [packageName, clips]);
    return sendResult;
  }

  @override
  Future<bool> shareWithChooser(
    List<ShareClipMsg> clips,
    String chooserTitle,
  ) async {
    _record('shareWithChooser', [clips, chooserTitle]);
    return boolResult;
  }

  @override
  Future<bool> openApp(String packageName) async {
    _record('openApp', [packageName]);
    return boolResult;
  }

  @override
  Future<bool> openStoreListing(String packageName) async {
    _record('openStoreListing', [packageName]);
    return boolResult;
  }

  @override
  Future<int> freeBytes() async {
    _record('freeBytes');
    return free;
  }

  @override
  Future<List<String>> copyFolderNames() async {
    _record('copyFolderNames');
    return folders;
  }

  @override
  Future<List<int>> existingCopies(List<CopyFileRefMsg> refs) async {
    _record('existingCopies', [refs]);
    return existing;
  }

  @override
  Future<DeleteReportMsg> deleteCopies(List<CopyFileRefMsg> refs) async {
    _record('deleteCopies', [refs]);
    return report;
  }

  @override
  Future<List<CopyFolderFileMsg>> filesInCopyFolders() async {
    _record('filesInCopyFolders');
    return files;
  }

  @override
  Future<bool> requestDelete(List<CopyFileRefMsg> refs) async {
    _record('requestDelete', [refs]);
    return boolResult;
  }
}

const _detected = ClipRef(
  volumeName: 'external_primary',
  mediaStoreId: 30,
  mimeType: 'video/mp4',
);
const _picked = ClipRef(
  pickerUri: 'content://media/picker/0/x/media/42',
  mimeType: 'video/quicktime',
);
const _ref = CopyFileRef(
  mediaStoreId: 7,
  folderName: 'Goa',
  fileName: '2026-10-12_14-32-05.mp4',
);

void main() {
  late _StubApi api;
  late PigeonEditorsBridge bridge;

  setUp(() {
    api = _StubApi();
    bridge = PigeonEditorsBridge(api);
  });

  void expectClips(Object? sent) {
    final clips = sent! as List<ShareClipMsg>;
    expect(clips, hasLength(2));
    expect(clips[0].volumeName, 'external_primary');
    expect(clips[0].mediaStoreId, 30);
    expect(clips[0].pickerUri, isNull);
    expect(clips[1].volumeName, isNull);
    expect(clips[1].mediaStoreId, isNull);
    expect(clips[1].pickerUri, 'content://media/picker/0/x/media/42');
  }

  void expectRefs(Object? sent) {
    final refs = sent! as List<CopyFileRefMsg>;
    expect(refs.single.mediaStoreId, 7);
    expect(refs.single.folderName, 'Goa');
    expect(refs.single.fileName, '2026-10-12_14-32-05.mp4');
  }

  test('apps passes the names and size and maps each answer', () async {
    final png = Uint8List.fromList([1, 2, 3]);
    api.appList = [
      InstalledAppMsg(packageName: 'a', installed: true, iconPng: png),
      InstalledAppMsg(packageName: 'b', installed: false),
    ];

    final apps = await bridge.apps(['a', 'b'], iconPx: 96);

    expect(api.args, [
      ['a', 'b'],
      96,
    ]);
    expect(apps, [
      InstalledApp(packageName: 'a', installed: true, iconPng: png),
      const InstalledApp(packageName: 'b', installed: false),
    ]);
  });

  test('sendTo sends each clip in order and maps every result', () async {
    for (final (msg, result) in [
      (SendResultMsg.sent, SendResult.sent),
      (SendResultMsg.notInstalled, SendResult.notInstalled),
      (SendResultMsg.failed, SendResult.failed),
    ]) {
      api.sendResult = msg;
      expect(await bridge.sendTo('com.x', [_detected, _picked]), result);
      expect(api.args[0], 'com.x');
      expectClips(api.args[1]);
    }
  });

  test('shareWithChooser, openApp and openStoreListing pass through', () async {
    expect(await bridge.shareWithChooser([_detected, _picked], 'Share'), true);
    expectClips(api.args[0]);
    expect(api.args[1], 'Share');

    api.boolResult = false;
    expect(await bridge.openApp('com.x'), false);
    expect(api.args, ['com.x']);
    expect(await bridge.openStoreListing('com.y'), false);
    expect(api.args, ['com.y']);
    expect(api.calls, ['shareWithChooser', 'openApp', 'openStoreListing']);
  });

  test('freeBytes and copyFolderNames pass through', () async {
    api
      ..free = 12345678901
      ..folders = ['Goa', 'Goa (2)'];
    expect(await bridge.freeBytes(), 12345678901);
    expect(await bridge.copyFolderNames(), ['Goa', 'Goa (2)']);
  });

  test('existingCopies sends the refs and answers a set', () async {
    api.existing = [7, 3, 7];
    expect(await bridge.existingCopies([_ref]), {7, 3});
    expectRefs(api.args[0]);
  });

  test('deleteCopies maps the report to sets', () async {
    api.report = DeleteReportMsg(
      deleted: [1, 2],
      gone: [3],
      refused: [4],
      failed: [5],
    );
    expect(
      await bridge.deleteCopies([_ref]),
      const DeleteReport(deleted: {1, 2}, gone: {3}, refused: {4}, failed: {5}),
    );
    expectRefs(api.args[0]);
  });

  test('filesInCopyFolders maps each file', () async {
    api.files = [
      CopyFolderFileMsg(
        mediaStoreId: 9,
        folderName: 'Goa',
        fileName: 'a.mp4',
        sizeBytes: 5,
        ownedByTakeTray: false,
      ),
    ];
    expect(await bridge.filesInCopyFolders(), const [
      CopyFolderFile(
        mediaStoreId: 9,
        folderName: 'Goa',
        fileName: 'a.mp4',
        sizeBytes: 5,
        ownedByTakeTray: false,
      ),
    ]);
  });

  test('requestDelete sends the refs', () async {
    expect(await bridge.requestDelete([_ref]), true);
    expectRefs(api.args[0]);
  });

  test('a PlatformException passes through unchanged', () async {
    final error = PlatformException(code: 'busy', message: 'open');
    api.error = error;
    final calls = <Future<Object?> Function()>[
      () => bridge.apps(['a'], iconPx: 48),
      () => bridge.sendTo('a', [_detected]),
      () => bridge.shareWithChooser([_detected], 't'),
      () => bridge.openApp('a'),
      () => bridge.openStoreListing('a'),
      bridge.freeBytes,
      bridge.copyFolderNames,
      () => bridge.existingCopies([_ref]),
      () => bridge.deleteCopies([_ref]),
      bridge.filesInCopyFolders,
      () => bridge.requestDelete([_ref]),
    ];
    for (final call in calls) {
      await expectLater(call(), throwsA(same(error)));
    }
    expect(api.calls, hasLength(calls.length));
  });

  test('no name, folder or address in a toString (D-10)', () {
    final texts = [
      _ref.toString(),
      const CopyFolderFile(
        mediaStoreId: 9,
        folderName: 'Goa',
        fileName: 'a.mp4',
        sizeBytes: 5,
        ownedByTakeTray: true,
      ).toString(),
      const InstalledApp(packageName: 'com.secret', installed: true).toString(),
      const DeleteReport(deleted: {1}).toString(),
    ];
    for (final text in texts) {
      expect(text, isNot(contains('Goa')));
      expect(text, isNot(contains('a.mp4')));
      expect(text, isNot(contains('2026-10-12')));
      expect(text, isNot(contains('com.secret')));
    }
  });

  test('the value types compare by value', () {
    expect(
      _ref,
      const CopyFileRef(
        mediaStoreId: 7,
        folderName: 'Goa',
        fileName: '2026-10-12_14-32-05.mp4',
      ),
    );
    expect(
      _ref,
      isNot(
        const CopyFileRef(mediaStoreId: 7, folderName: 'Goa', fileName: 'b'),
      ),
    );
    expect(
      InstalledApp(
        packageName: 'a',
        installed: true,
        iconPng: Uint8List.fromList([1]),
      ),
      isNot(
        InstalledApp(
          packageName: 'a',
          installed: true,
          iconPng: Uint8List.fromList([2]),
        ),
      ),
    );
    expect(
      const DeleteReport(deleted: {1, 2}).hashCode,
      const DeleteReport(deleted: {2, 1}).hashCode,
    );
    expect(
      const DeleteReport(gone: {1}),
      isNot(const DeleteReport(failed: {1})),
    );
  });

  test('the provider builds the Pigeon bridge', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(editorsBridgeProvider), isA<PigeonEditorsBridge>());
  });
}
