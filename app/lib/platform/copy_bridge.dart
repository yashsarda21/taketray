import 'dart:async';

import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/copy_api.g.dart';

part 'copy_bridge.freezed.dart';
part 'copy_bridge.g.dart';

/// One clip to copy: [source] is how Android finds its video, [fileName]
/// the name Dart chose (D-119, R2), [sizeBytes] its size as Dart knows it.
@freezed
abstract class CopyItem with _$CopyItem {
  const factory CopyItem({
    required int clipId,
    required ClipRef source,
    required String fileName,
    required int sizeBytes,
  }) = _CopyItem;
}

/// A copy job: [items] in shooting order into
/// `Movies/TakeTray/<folderName>/`. [jobId] names it in every later call.
@freezed
abstract class CopyRequest with _$CopyRequest {
  const factory CopyRequest({
    required String jobId,
    required int reelId,
    required String folderName,
    required List<CopyItem> items,
  }) = _CopyRequest;
}

/// Where a job is. `running` until it ends `finished`, `spaceFull` (less
/// than the file plus 50 MB was free, or the disk filled mid-file),
/// `interrupted` (storage failed for a reason that is not the clip's) or
/// `cancelled`. Only `spaceFull` and `interrupted` can be resumed.
enum CopyState { running, finished, spaceFull, interrupted, cancelled }

/// One finished copy: MediaStore's id and the name it really has (MediaStore
/// may add " (1)" on a clash). [copiedAt] is UTC.
@freezed
abstract class CopiedFile with _$CopiedFile {
  const factory CopiedFile({
    required int clipId,
    required int copyMediaStoreId,
    required String fileName,
    required int sizeBytes,
    required DateTime copiedAt,
  }) = _CopiedFile;
}

/// A job as Kotlin reports it. [done] counts the items handled (copied or
/// failed) out of [total]; [bytesDone] never goes back while it runs.
/// [failedClipIds] are clips whose original could not be read (gone, its
/// grant lost, or shorter than it said). After a cancel, [copied] lists the
/// copies that were deleted and [undeleted] the ones that could not be.
@freezed
abstract class CopyJob with _$CopyJob {
  const factory CopyJob({
    required String jobId,
    required int reelId,
    required String folderName,
    required CopyState state,
    required int total,
    required int done,
    required int bytesDone,
    required int bytesTotal,
    required List<CopiedFile> copied,
    required List<int> failedClipIds,
    required List<CopiedFile> undeleted,
  }) = _CopyJob;
}

/// [CopyBridge.start] while a job runs or its result waits (R4: one job at
/// a time), or [CopyBridge.deletePendingIn] while a job runs.
class CopyBusy implements Exception {
  const CopyBusy();

  @override
  String toString() => 'CopyBusy';
}

/// A TakeTray-owned row in a copy folder, finished or still pending.
@freezed
abstract class FolderRow with _$FolderRow {
  const factory FolderRow({
    required int mediaStoreId,
    required String fileName,
    required int sizeBytes,
    required bool pending,
  }) = _FolderRow;
}

/// Copying clips into `Movies/TakeTray/<folder>/`, in the app's own process
/// (D-122). Kotlin never writes the database: Dart records each copy as its
/// event arrives. A failure other than [CopyBusy] arrives as a
/// `PlatformException`, unchanged. Tests use `FakeCopyBridge`. Never log a
/// file, folder or reel name (D-10).
abstract interface class CopyBridge {
  /// Starts [request]; [CopyBusy] while a job runs or its result waits.
  Future<void> start(CopyRequest request);

  /// This process's running job or waiting result; null after a restart.
  Future<CopyJob?> current();

  /// Stops the job and deletes the copies it made; answers once they are
  /// deleted. Null for an unknown id.
  Future<CopyJob?> cancel(String jobId);

  /// After `spaceFull` or `interrupted`: copies the remaining items.
  Future<void> resume(String jobId);

  /// Forgets the result; another id, or a running job, is left alone.
  Future<void> clear(String jobId);

  /// TakeTray-owned rows in exactly `Movies/TakeTray/<folderName>/`, pending
  /// ones included.
  Future<List<FolderRow>> ownRowsIn(String folderName);

  /// Deletes only TakeTray-owned pending rows there; returns how many.
  /// [CopyBusy] while a job runs.
  Future<int> deletePendingIn(String folderName);

  /// Keeps the screen on (or lets it sleep) through the activity's window.
  // ignore: avoid_positional_boolean_parameters
  Future<void> keepScreenOn(bool on);

  /// Every change of the job: at most every 250 ms during a file, and always
  /// when a file finishes or the state changes. Nothing arrives while no one
  /// listens.
  Stream<CopyJob> get changes;
}

/// The [CopyBridge] over the Pigeon-generated [CopyHostApi] and
/// [CopyFlutterApi]. It only converts between message and domain types, and
/// turns Kotlin's `busy` into [CopyBusy].
class PigeonCopyBridge implements CopyBridge {
  /// [api] defaults to a real [CopyHostApi]; tests pass a stub. [messenger]
  /// is the channel for both directions (the default one when null).
  new({CopyHostApi? api, BinaryMessenger? messenger})
    : _api = api ?? CopyHostApi(binaryMessenger: messenger),
      _messenger = messenger;

  final CopyHostApi _api;
  final BinaryMessenger? _messenger;

  late final StreamController<CopyJob> _changes =
      StreamController<CopyJob>.broadcast(onListen: _listen);
  bool _listening = false;

  @override
  Future<void> start(CopyRequest request) => _busyAware(
    () => _api.start(
      CopyRequestMsg(
        jobId: request.jobId,
        reelId: request.reelId,
        folderName: request.folderName,
        items: [
          for (final item in request.items)
            CopyItemMsg(
              clipId: item.clipId,
              source: CopySourceMsg(
                volumeName: item.source.volumeName,
                mediaStoreId: item.source.mediaStoreId,
                pickerUri: item.source.pickerUri,
                mimeType: item.source.mimeType,
              ),
              fileName: item.fileName,
              sizeBytes: item.sizeBytes,
            ),
        ],
      ),
    ),
  );

  @override
  Future<CopyJob?> current() async {
    final msg = await _api.current();
    return msg == null ? null : _job(msg);
  }

  @override
  Future<CopyJob?> cancel(String jobId) async {
    final msg = await _api.cancel(jobId);
    return msg == null ? null : _job(msg);
  }

  @override
  Future<void> resume(String jobId) => _api.resume(jobId);

  @override
  Future<void> clear(String jobId) => _api.clear(jobId);

  @override
  Future<List<FolderRow>> ownRowsIn(String folderName) async => [
    for (final row in await _api.ownRowsIn(folderName))
      FolderRow(
        mediaStoreId: row.mediaStoreId,
        fileName: row.fileName,
        sizeBytes: row.sizeBytes,
        pending: row.pending,
      ),
  ];

  @override
  Future<int> deletePendingIn(String folderName) =>
      _busyAware(() => _api.deletePendingIn(folderName));

  @override
  Future<void> keepScreenOn(bool on) => _api.keepScreenOn(on);

  @override
  Stream<CopyJob> get changes => _changes.stream;

  /// On the first listen: Kotlin's events start reaching the stream.
  void _listen() {
    if (_listening) return;
    _listening = true;
    CopyFlutterApi.setUp(
      _ChangeListener((job) {
        if (!_changes.isClosed) _changes.add(job);
      }),
      binaryMessenger: _messenger,
    );
  }

  /// Stops receiving events (the provider is disposed).
  void dispose() {
    if (_listening) CopyFlutterApi.setUp(null, binaryMessenger: _messenger);
    unawaited(_changes.close());
  }
}

/// [call], with Kotlin's `busy` as [CopyBusy]; any other failure unchanged.
Future<T> _busyAware<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (e) {
    if (e.code == 'busy') throw const CopyBusy();
    rethrow;
  }
}

class _ChangeListener implements CopyFlutterApi {
  _ChangeListener(this._onJob);

  final void Function(CopyJob) _onJob;

  @override
  void onCopyChanged(CopyJobMsg job) => _onJob(_job(job));
}

CopiedFile _copied(CopiedFileMsg msg) => CopiedFile(
  clipId: msg.clipId,
  copyMediaStoreId: msg.copyMediaStoreId,
  fileName: msg.fileName,
  sizeBytes: msg.sizeBytes,
  copiedAt: DateTime.fromMillisecondsSinceEpoch(msg.copiedAtMs, isUtc: true),
);

CopyJob _job(CopyJobMsg msg) => CopyJob(
  jobId: msg.jobId,
  reelId: msg.reelId,
  folderName: msg.folderName,
  state: switch (msg.state) {
    CopyStateMsg.running => CopyState.running,
    CopyStateMsg.finished => CopyState.finished,
    CopyStateMsg.spaceFull => CopyState.spaceFull,
    CopyStateMsg.interrupted => CopyState.interrupted,
    CopyStateMsg.cancelled => CopyState.cancelled,
  },
  total: msg.total,
  done: msg.done,
  bytesDone: msg.bytesDone,
  bytesTotal: msg.bytesTotal,
  copied: [for (final c in msg.copied) _copied(c)],
  failedClipIds: List.unmodifiable(msg.failedClipIds),
  undeleted: [for (final c in msg.undeleted) _copied(c)],
);

@Riverpod(keepAlive: true)
CopyBridge copyBridge(Ref ref) {
  final bridge = PigeonCopyBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
}
