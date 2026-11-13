import 'dart:async';

import 'package:flutter/services.dart';
import 'package:taketray/platform/copy_bridge.dart';

/// A [CopyBridge] with no phone, for tests. It keeps the native engine's
/// rules (D-122) but copies nothing by itself: a test moves the job with
/// [emit].
///
/// - `start` records the request in [starts] and makes [job] a running job
///   with nothing done; [CopyBusy] while [job] is set (running or a waiting
///   result), as on the phone.
/// - [emit] sets [job] and sends it on [changes] (Kotlin's event).
/// - `cancel` of [job]'s id makes it `cancelled` (with [cancelUndeleted]
///   moved out of `copied` into `undeleted`) and returns it; another id
///   returns null. `resume` makes a `spaceFull` or `interrupted` job running;
///   `clear` forgets a job that is not running. Other ids change nothing.
/// - [folders] holds each folder's rows for `ownRowsIn`; `deletePendingIn`
///   removes the pending ones and returns how many ([CopyBusy] while a job
///   runs).
/// - [screenOn] is the last `keepScreenOn` value (null before any).
/// - [calls] logs every call by name, in order, including one that fails.
///   [failNext] makes the next call of a method throw a `PlatformException`;
///   [gate] makes it wait until the returned completer completes.
class FakeCopyBridge implements CopyBridge {
  CopyJob? job;

  final List<CopyRequest> starts = [];

  final Map<String, List<FolderRow>> folders = {};

  /// Clip ids whose copies "cannot be deleted" on the next cancel.
  Set<int> cancelUndeleted = {};

  bool? screenOn;

  final List<String> calls = [];

  final Map<String, int> _failures = {};
  final Map<String, Completer<void>> _gates = {};

  final StreamController<CopyJob> _changes =
      StreamController<CopyJob>.broadcast();

  void failNext(String method) =>
      _failures[method] = (_failures[method] ?? 0) + 1;

  Completer<void> gate(String method) => _gates[method] = Completer<void>();

  /// Kotlin reports [next]: it becomes [job] and goes to [changes].
  void emit(CopyJob next) {
    job = next;
    _changes.add(next);
  }

  Future<T> _call<T>(String method, T Function() answer) async {
    calls.add(method);
    final gate = _gates.remove(method);
    if (gate != null) await gate.future;
    final failures = _failures[method] ?? 0;
    if (failures > 0) {
      _failures[method] = failures - 1;
      throw PlatformException(
        code: 'fake-failure',
        message: '$method failed on purpose',
      );
    }
    return answer();
  }

  @override
  Future<void> start(CopyRequest request) => _call('start', () {
    if (job != null) throw const CopyBusy();
    starts.add(request);
    job = CopyJob(
      jobId: request.jobId,
      reelId: request.reelId,
      folderName: request.folderName,
      state: CopyState.running,
      total: request.items.length,
      done: 0,
      bytesDone: 0,
      bytesTotal: request.items.fold(0, (sum, i) => sum + i.sizeBytes),
      copied: const [],
      failedClipIds: const [],
      undeleted: const [],
    );
  });

  @override
  Future<CopyJob?> current() => _call('current', () => job);

  @override
  Future<CopyJob?> cancel(String jobId) => _call('cancel', () {
    final now = job;
    if (now == null || now.jobId != jobId) return null;
    if (now.state == CopyState.cancelled) return now;
    final kept = now.copied
        .where((c) => cancelUndeleted.contains(c.clipId))
        .toList();
    final cancelled = now.copyWith(
      state: CopyState.cancelled,
      copied: now.copied
          .where((c) => !cancelUndeleted.contains(c.clipId))
          .toList(),
      undeleted: [...now.undeleted, ...kept],
    );
    job = cancelled;
    return cancelled;
  });

  @override
  Future<void> resume(String jobId) => _call('resume', () {
    final now = job;
    if (now == null || now.jobId != jobId) return;
    if (now.state == CopyState.spaceFull ||
        now.state == CopyState.interrupted) {
      job = now.copyWith(state: CopyState.running);
    }
  });

  @override
  Future<void> clear(String jobId) => _call('clear', () {
    final now = job;
    if (now != null && now.jobId == jobId && now.state != CopyState.running) {
      job = null;
    }
  });

  @override
  Future<List<FolderRow>> ownRowsIn(String folderName) =>
      _call('ownRowsIn', () => List.of(folders[folderName] ?? const []));

  @override
  Future<int> deletePendingIn(String folderName) =>
      _call('deletePendingIn', () {
        if (job?.state == CopyState.running) throw const CopyBusy();
        final rows = folders[folderName] ?? const <FolderRow>[];
        final gone = rows.where((r) => r.pending).length;
        folders[folderName] = rows.where((r) => !r.pending).toList();
        return gone;
      });

  @override
  Future<void> keepScreenOn(bool on) =>
      _call('keepScreenOn', () => screenOn = on);

  @override
  Stream<CopyJob> get changes => _changes.stream;
}
