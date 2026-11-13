import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/copy_api.g.dart';
import 'package:taketray/platform/copy_bridge.dart';

/// A [CopyHostApi] whose answers a test sets, and which remembers what it
/// was called with.
class _StubApi extends CopyHostApi {
  CopyJobMsg? job;
  CopyJobMsg? cancelled;
  List<FolderRowMsg> rows = [];
  int deleted = 0;
  Exception? error;

  final List<String> calls = [];
  final List<Object?> args = [];

  void _record(String name, [Object? argument]) {
    calls.add(name);
    args.add(argument);
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<void> start(CopyRequestMsg request) async => _record('start', request);

  @override
  Future<CopyJobMsg?> current() async {
    _record('current');
    return job;
  }

  @override
  Future<CopyJobMsg?> cancel(String jobId) async {
    _record('cancel', jobId);
    return cancelled;
  }

  @override
  Future<void> resume(String jobId) async => _record('resume', jobId);

  @override
  Future<void> clear(String jobId) async => _record('clear', jobId);

  @override
  Future<List<FolderRowMsg>> ownRowsIn(String folderName) async {
    _record('ownRowsIn', folderName);
    return rows;
  }

  @override
  Future<int> deletePendingIn(String folderName) async {
    _record('deletePendingIn', folderName);
    return deleted;
  }

  @override
  Future<void> keepScreenOn(bool on) async => _record('keepScreenOn', on);
}

CopiedFileMsg _copiedMsg(int clipId, {int at = 1780000000123}) => CopiedFileMsg(
  clipId: clipId,
  copyMediaStoreId: 900 + clipId,
  fileName: '2026-10-12_14-32-0$clipId.mp4',
  sizeBytes: 1000 * clipId,
  copiedAtMs: at,
);

CopiedFile _copied(int clipId, {int at = 1780000000123}) => CopiedFile(
  clipId: clipId,
  copyMediaStoreId: 900 + clipId,
  fileName: '2026-10-12_14-32-0$clipId.mp4',
  sizeBytes: 1000 * clipId,
  copiedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
);

CopyJobMsg _jobMsg({CopyStateMsg state = CopyStateMsg.running}) => CopyJobMsg(
  jobId: 'job-1',
  reelId: 7,
  folderName: 'Goa 🌴',
  state: state,
  total: 3,
  done: 2,
  bytesDone: 3000,
  bytesTotal: 6000,
  copied: [_copiedMsg(1)],
  failedClipIds: [2],
  undeleted: [_copiedMsg(3, at: 5)],
);

CopyJob _job({CopyState state = CopyState.running}) => CopyJob(
  jobId: 'job-1',
  reelId: 7,
  folderName: 'Goa 🌴',
  state: state,
  total: 3,
  done: 2,
  bytesDone: 3000,
  bytesTotal: 6000,
  copied: [_copied(1)],
  failedClipIds: const [2],
  undeleted: [_copied(3, at: 5)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const flutterChannel =
      'dev.flutter.pigeon.taketray.CopyFlutterApi.onCopyChanged';

  late _StubApi api;
  late PigeonCopyBridge bridge;

  setUp(() {
    api = _StubApi();
    bridge = PigeonCopyBridge(api: api);
  });

  tearDown(() => bridge.dispose());

  /// Kotlin calling `CopyFlutterApi.onCopyChanged(job)`.
  Future<void> nativeSends(CopyJobMsg job) async {
    final reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      flutterChannel,
      CopyFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[job]),
      reply.complete,
    );
    await reply.future;
  }

  test('start maps the request, detected and picked clips alike', () async {
    await bridge.start(
      const CopyRequest(
        jobId: 'job-1',
        reelId: 7,
        folderName: 'Goa 🌴',
        items: [
          CopyItem(
            clipId: 11,
            source: ClipRef(
              volumeName: '1a2b-3c4d',
              mediaStoreId: 4242,
              mimeType: 'video/mp4',
            ),
            fileName: '2026-10-12_14-32-05.mp4',
            sizeBytes: 123456789012,
          ),
          CopyItem(
            clipId: 12,
            source: ClipRef(
              pickerUri: 'content://media/picker/0/x/media/9',
              mimeType: 'video/quicktime',
            ),
            fileName: '2026-10-12_14-32-05_2.mov',
            sizeBytes: 0,
          ),
        ],
      ),
    );
    expect(api.calls, ['start']);
    final msg = api.args.single! as CopyRequestMsg;
    expect(msg.jobId, 'job-1');
    expect(msg.reelId, 7);
    expect(msg.folderName, 'Goa 🌴');
    expect(msg.items.map((i) => i.clipId), [11, 12]);
    expect(msg.items.map((i) => i.fileName), [
      '2026-10-12_14-32-05.mp4',
      '2026-10-12_14-32-05_2.mov',
    ]);
    expect(msg.items.map((i) => i.sizeBytes), [123456789012, 0]);
    final a = msg.items[0].source;
    expect(
      [a.volumeName, a.mediaStoreId, a.pickerUri, a.mimeType],
      ['1a2b-3c4d', 4242, null, 'video/mp4'],
    );
    final b = msg.items[1].source;
    expect(
      [b.volumeName, b.mediaStoreId, b.pickerUri, b.mimeType],
      [null, null, 'content://media/picker/0/x/media/9', 'video/quicktime'],
    );
  });

  test(
    'busy from Kotlin is CopyBusy; any other failure passes unchanged',
    () async {
      api.error = PlatformException(code: 'busy', message: 'a job runs');
      await expectLater(
        bridge.start(
          const CopyRequest(jobId: 'j', reelId: 1, folderName: 'F', items: []),
        ),
        throwsA(isA<CopyBusy>()),
      );
      await expectLater(bridge.deletePendingIn('F'), throwsA(isA<CopyBusy>()));
      // A resume while the folder sweep runs is busy too.
      await expectLater(bridge.resume('j'), throwsA(isA<CopyBusy>()));

      final other = PlatformException(code: 'bad-request', message: 'x');
      api.error = other;
      await expectLater(
        bridge.start(
          const CopyRequest(jobId: 'j', reelId: 1, folderName: 'F', items: []),
        ),
        throwsA(same(other)),
      );
      for (final call in <Future<Object?> Function()>[
        bridge.current,
        () => bridge.cancel('j'),
        () => bridge.resume('j'),
        () => bridge.clear('j'),
        () => bridge.ownRowsIn('F'),
        () => bridge.deletePendingIn('F'),
        () => bridge.keepScreenOn(true),
      ]) {
        await expectLater(call(), throwsA(same(other)));
      }
    },
  );

  test('every answer maps to the domain', () async {
    expect(await bridge.current(), isNull);
    for (final (msg, state) in [
      (CopyStateMsg.running, CopyState.running),
      (CopyStateMsg.finished, CopyState.finished),
      (CopyStateMsg.spaceFull, CopyState.spaceFull),
      (CopyStateMsg.interrupted, CopyState.interrupted),
      (CopyStateMsg.cancelled, CopyState.cancelled),
    ]) {
      api.job = _jobMsg(state: msg);
      expect(await bridge.current(), _job(state: state));
    }
    expect((await bridge.current())!.copied.single.copiedAt.isUtc, isTrue);

    expect(await bridge.cancel('job-1'), isNull);
    api.cancelled = _jobMsg(state: CopyStateMsg.cancelled);
    expect(await bridge.cancel('job-1'), _job(state: CopyState.cancelled));

    api.rows = [
      FolderRowMsg(
        mediaStoreId: 5,
        fileName: 'a.mp4',
        sizeBytes: 10,
        pending: true,
      ),
      FolderRowMsg(
        mediaStoreId: 6,
        fileName: 'b (1).mp4',
        sizeBytes: 0,
        pending: false,
      ),
    ];
    expect(await bridge.ownRowsIn('Goa'), const [
      FolderRow(
        mediaStoreId: 5,
        fileName: 'a.mp4',
        sizeBytes: 10,
        pending: true,
      ),
      FolderRow(
        mediaStoreId: 6,
        fileName: 'b (1).mp4',
        sizeBytes: 0,
        pending: false,
      ),
    ]);
    api.deleted = 3;
    expect(await bridge.deletePendingIn('Goa'), 3);

    await bridge.resume('job-1');
    await bridge.clear('job-1');
    await bridge.keepScreenOn(true);
    await bridge.keepScreenOn(false);
    expect(api.calls, [
      ...List.filled(7, 'current'),
      'cancel',
      'cancel',
      'ownRowsIn',
      'deletePendingIn',
      'resume',
      'clear',
      'keepScreenOn',
      'keepScreenOn',
    ]);
    expect(api.args.sublist(7), [
      'job-1',
      'job-1',
      'Goa',
      'Goa',
      'job-1',
      'job-1',
      true,
      false,
    ]);
  });

  test('changes carry Kotlin events once someone listens', () async {
    // Before anyone listens, an event finds no handler and is dropped.
    await nativeSends(_jobMsg());

    final seen = <CopyJob>[];
    final sub = bridge.changes.listen(seen.add);
    await nativeSends(_jobMsg());
    await nativeSends(_jobMsg(state: CopyStateMsg.finished));
    await pumpEventQueue();
    expect(seen, [_job(), _job(state: CopyState.finished)]);

    // A second listener (the stream is broadcast) gets later events too.
    final seen2 = <CopyJob>[];
    final sub2 = bridge.changes.listen(seen2.add);
    await nativeSends(_jobMsg(state: CopyStateMsg.cancelled));
    await pumpEventQueue();
    expect(seen.last.state, CopyState.cancelled);
    expect(seen2, [_job(state: CopyState.cancelled)]);
    await sub.cancel();
    await sub2.cancel();
  });

  test('dispose stops the events', () async {
    final seen = <CopyJob>[];
    bridge.changes.listen(seen.add, onDone: () => seen.add(_job()));
    bridge.dispose();
    await pumpEventQueue();
    // Done once, and the handler is gone: a later event goes nowhere.
    expect(seen, [_job()]);
    await nativeSends(_jobMsg());
    await pumpEventQueue();
    expect(seen, [_job()]);
  });

  test('CopyBusy says only what it is', () {
    expect(const CopyBusy().toString(), 'CopyBusy');
  });

  test('the provider builds the Pigeon bridge', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(copyBridgeProvider), isA<PigeonCopyBridge>());
  });
}
