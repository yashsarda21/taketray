import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/domain/models/copy_job_plan.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/copy_file_names.dart';
import 'package:taketray/domain/rules/edit_folder_name.dart';
import 'package:taketray/domain/rules/folder_names.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/domain/rules/space_check.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/platform/editors_bridge.dart';

export 'package:taketray/domain/models/copy_job_plan.dart';

part 'edit_session_service.g.dart';

// Ids, counts, bytes, the editor's enum name and error types only: never a
// reel, folder or file name, a path or an address (D-10).
final Logger _log = Logger('editSessions.service');

/// An editor as the editor sheet shows it.
@immutable
class EditorChoice {
  const EditorChoice({
    required this.editor,
    required this.installed,
    this.icon,
  });

  final EditorApp editor;
  final bool installed;

  /// The app's icon as PNG bytes, when it is installed and could be drawn.
  final Uint8List? icon;

  @override
  bool operator ==(Object other) =>
      other is EditorChoice &&
      other.editor == editor &&
      other.installed == installed &&
      listEquals(other.icon, icon);

  @override
  int get hashCode => Object.hash(
    editor,
    installed,
    icon == null ? null : Object.hashAll(icon!),
  );

  @override
  String toString() => 'EditorChoice(${editor.name}, installed: $installed)';
}

/// How a direct share to CapCut or Edits went: [sentCount] is how many clips
/// went (0 unless [result] is `sent`).
@immutable
class SendOutcome {
  const SendOutcome(this.result, this.sentCount);

  final SendResult result;
  final int sentCount;

  @override
  bool operator ==(Object other) =>
      other is SendOutcome &&
      other.result == result &&
      other.sentCount == sentCount;

  @override
  int get hashCode => Object.hash(result, sentCount);

  @override
  String toString() => 'SendOutcome(${result.name}, $sentCount)';
}

/// What copying [clipIds] into the reel's folder would take (the space
/// screen's numbers), before anything is written.
@immutable
class CopyPlan {
  CopyPlan({
    required this.reelId,
    required this.editor,
    required List<int> clipIds,
    required this.needBytes,
    required this.freeBytes,
    required this.space,
    required this.folderName,
    required this.startsSession,
  }) : clipIds = List.unmodifiable(clipIds);

  final int reelId;
  final EditorApp editor;

  /// The clips to copy, in shooting order: live clips of the reel that have
  /// no live copy in its folder.
  final List<int> clipIds;

  /// The sum of their sizes.
  final int needBytes;
  final int freeBytes;
  final SpaceCheck space;

  /// The session's folder, or the one a new session would get.
  final String folderName;

  /// True when the reel has no session yet: the copy starts it (VN only).
  final bool startsSession;

  // No folder name in a log line (D-10).
  @override
  String toString() =>
      'CopyPlan(reel $reelId, ${editor.name}, ${clipIds.length} clips, '
      '$needBytes bytes, startsSession: $startsSession)';
}

/// What Done editing did.
@immutable
class DoneEditingResult {
  const DoneEditingResult({
    required this.editor,
    required this.freedBytes,
    this.leftBehind = 0,
  });

  final EditorApp editor;

  /// The sizes of the copies it deleted.
  final int freedBytes;

  /// How many copies the guard refused to delete (the file in that place is
  /// no longer TakeTray's copy): their rows are gone with the session and
  /// the files stay for the storage screen (R7).
  final int leftBehind;

  @override
  bool operator ==(Object other) =>
      other is DoneEditingResult &&
      other.editor == editor &&
      other.freedBytes == freedBytes &&
      other.leftBehind == leftBehind;

  @override
  int get hashCode => Object.hash(editor, freedBytes, leftBehind);

  @override
  String toString() =>
      'DoneEditingResult(${editor.name}, $freedBytes bytes, '
      '$leftBehind left behind)';
}

/// Files in one copy folder that no session records (left from an earlier
/// install or a backup import): deleted only through Android's consent
/// dialog (R7).
@immutable
class OrphanFolder {
  OrphanFolder({
    required this.folderName,
    required this.fileCount,
    required this.bytes,
    required List<CopyFileRef> files,
  }) : files = List.unmodifiable(files);

  final String folderName;
  final int fileCount;
  final int bytes;
  final List<CopyFileRef> files;

  @override
  bool operator ==(Object other) =>
      other is OrphanFolder &&
      other.folderName == folderName &&
      other.fileCount == fileCount &&
      other.bytes == bytes &&
      listEquals(other.files, files);

  @override
  int get hashCode =>
      Object.hash(folderName, fileCount, bytes, Object.hashAll(files));

  // No folder name in a log line (D-10).
  @override
  String toString() => 'OrphanFolder($fileCount files, $bytes bytes)';
}

/// What Android answered to the consent dialog for an orphan folder's files:
/// whether the user [allowed] it, and the bytes freed (0 when declined). The
/// two are separate: allowed files may report a size of 0 (a file Android has
/// not finished scanning), and that is still allowed.
@immutable
class OrphanDeleteResult {
  const OrphanDeleteResult.allowed(this.freedBytes) : allowed = true;

  const OrphanDeleteResult.declined() : allowed = false, freedBytes = 0;

  final bool allowed;
  final int freedBytes;

  @override
  bool operator ==(Object other) =>
      other is OrphanDeleteResult &&
      other.allowed == allowed &&
      other.freedBytes == freedBytes;

  @override
  int get hashCode => Object.hash(allowed, freedBytes);

  @override
  String toString() => 'OrphanDeleteResult(allowed: $allowed, $freedBytes)';
}

/// What the storage screen shows: every session and the orphan folders.
@immutable
class StorageOverview {
  StorageOverview({
    required List<EditSessionSummary> sessions,
    required List<OrphanFolder> orphans,
  }) : sessions = List.unmodifiable(sessions),
       orphans = List.unmodifiable(orphans);

  final List<EditSessionSummary> sessions;
  final List<OrphanFolder> orphans;

  @override
  String toString() =>
      'StorageOverview(${sessions.length} sessions, '
      '${orphans.length} orphan folders)';
}

/// Some copies could not be deleted (the guard refused them, or the delete
/// failed): nothing that depends on them went ahead.
class CopiesNotDeleted implements Exception {
  const CopiesNotDeleted(this.count);

  /// How many copies are still there.
  final int count;

  @override
  String toString() => 'CopiesNotDeleted($count)';
}

/// The icon size `editorChoices` asks for, in pixels: the 40 dp tile at the
/// S24's density, with room to spare.
const int editorIconPx = 144;

/// Runs every editing session (D-123): sending originals to CapCut or Edits,
/// planning, starting and recording copies, Done editing, the clean-up
/// before clips or a reel go, the storage screen, and recovery after Android
/// stopped TakeTray mid-copy.
///
/// Every method that writes runs on this service's own serial queue, so two
/// of them never interleave (a remove racing a copy's record, Done editing
/// racing a cancel). [editorChoices], [share], [jobContext] and
/// [deleteOrphans] write nothing of TakeTray's own and run beside it
/// ([deleteOrphans] waits on Android's consent dialog, which must not hold
/// the queue and with it every copy's record).
///
/// The copy job's plan (`PhoneStateRepository.copyJobPlan`) is saved before
/// the engine starts and removed only by [finishJob], [cancelCopy] or a
/// failed [startCopy] (or by a recovery that finds the reel's session gone).
/// A copy is recorded as its "file finished" event arrives ([applyJob]), only
/// for the job whose plan is saved; after a restart the folder's own finished
/// rows, matched to the plan by file name, are the record ([recoverAtStart]).
class EditSessionService {
  EditSessionService(
    this._sessions,
    this._clips,
    this._reels,
    this._phone,
    this._editors,
    this._copy,
    this._times,
    this._clock,
  );

  final EditSessionsRepository _sessions;
  final ClipsRepository _clips;
  final ReelsRepository _reels;
  final PhoneStateRepository _phone;
  final EditorsBridge _editors;
  final CopyBridge _copy;
  final ClipTimeService _times;
  final Clock _clock;

  final StreamController<CopyJob> _local = StreamController.broadcast();
  final StreamController<String> _cleared = StreamController.broadcast();
  CopyJob? _lastLocal;

  Future<void> _tail = Future<void>.value();
  final Map<String, Future<SendOutcome>> _sending = {};
  final Map<String, Future<String>> _starting = {};

  /// Copy ids this process deleted or found gone: an event of the running
  /// job that still lists one never records it again.
  final Set<int> _forgotten = {};

  /// Jobs this service builds itself, not the engine: the interrupted job
  /// [recoverAtStart] found, a resumed job with nothing left to copy
  /// (finished at once) and a recovered job [cancelCopy] cancelled.
  Stream<CopyJob> get localJobs => _local.stream;

  /// The last job sent on [localJobs], or null.
  CopyJob? get lastLocalJob => _lastLocal;

  /// Ids of jobs that ended for good: finished, cancelled or settled by Done
  /// editing (the plan is removed and the engine's result cleared). The copy
  /// job controller drops such a job.
  Stream<String> get clearedJobs => _cleared.stream;

  /// Runs [body] after every call queued before it, whatever they did.
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// The key of a call: the reel, the editor and the clips (in any order).
  /// Only a call for the same thing is a double tap; another editor or other
  /// clips for the reel is its own call, and the queue and the state it finds
  /// decide its answer (T6-M5).
  static String _flightKey(int reelId, EditorApp editor, Iterable<int> ids) =>
      '$reelId/${editor.name}/${(ids.toSet().toList()..sort()).join(',')}';

  /// What [start] returns, shared by every call for [key] while it runs (a
  /// double tap).
  static Future<T> _singleFlight<T>(
    Map<String, Future<T>> running,
    String key,
    Future<T> Function() start,
  ) {
    final current = running[key];
    if (current != null) return current;
    final run = start();
    running[key] = run;
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        running.removeWhere((k, v) => k == key && identical(v, run));
      }),
    );
    return run;
  }

  void _emit(CopyJob job) {
    _lastLocal = job;
    if (!_local.isClosed) _local.add(job);
  }

  void _emitCleared(String jobId) {
    if (!_cleared.isClosed) _cleared.add(jobId);
  }

  /// Each editor in [EditorApp] order, installed or not, with its icon.
  Future<List<EditorChoice>> editorChoices() async {
    const editors = EditorApp.values;
    final apps = await _editors.apps([
      for (final e in editors) e.packageName,
    ], iconPx: editorIconPx);
    final byPackage = {for (final a in apps) a.packageName: a};
    return [
      for (final e in editors)
        EditorChoice(
          editor: e,
          installed: byPackage[e.packageName]?.installed ?? false,
          icon: byPackage[e.packageName]?.iconPng,
        ),
    ];
  }

  /// Shares the live clips of [clipIds] (in reel [reelId]) to CapCut or
  /// Edits, in shooting order (R5).
  ///
  /// The session (started now, or the reel's session of the same editor) and
  /// the sent rows are written **before** the share. `notInstalled`,
  /// `failed` or a share that throws take back what this call wrote: the
  /// session it started, or the sent rows it added (rows sent before stay);
  /// a throw is then passed on. Missing clips, ids of clips that are gone or
  /// not in the reel are left out and not counted; with none left nothing is
  /// written or shared and the outcome is `failed` with 0. VN, or a reel in
  /// another editor's session, throws [StateError]. A second call for the
  /// same reel, editor and clips while one runs gets the first call's answer
  /// (a double tap); any other call waits its turn and answers for itself.
  Future<SendOutcome> sendOriginals(
    int reelId,
    EditorApp editor,
    List<int> clipIds,
  ) => _singleFlight(
    _sending,
    _flightKey(reelId, editor, clipIds),
    () => _serial(() => _send(reelId, editor, clipIds)),
  );

  Future<SendOutcome> _send(
    int reelId,
    EditorApp editor,
    List<int> clipIds,
  ) async {
    if (!editor.takesShares) {
      throw StateError('${editor.name} takes no shares');
    }
    final existing = await _sessions.sessionOf(reelId);
    if (existing != null && existing.editor != editor) {
      throw StateError(
        'Reel $reelId is being edited in ${existing.editor.name}',
      );
    }
    final clips = await _live(clipIds, reelId: reelId);
    if (clips.isEmpty) {
      _log.info('Nothing to send for reel $reelId: no live clip');
      return const SendOutcome(SendResult.failed, 0);
    }
    var started = false;
    var added = <int>{};
    Future<void> rollBack() async {
      try {
        if (started) {
          await _sessions.endSession(reelId);
        } else {
          await _sessions.removeSent(reelId, added);
        }
      } on Object catch (e) {
        _log.warning('Taking back a failed send failed: ${e.runtimeType}');
      }
    }

    try {
      if (existing == null) {
        await _sessions.startSession(
          reelId,
          editor,
          safeFolderName(await _reelName(reelId)),
          alsoTaken: await _editors.copyFolderNames(),
        );
        started = true;
      }
      added = await _sessions.recordSent(reelId, [for (final c in clips) c.id]);
      final result = await _editors.sendTo(editor.packageName, [
        for (final c in clips) ClipRef.of(c),
      ]);
      if (result == SendResult.sent) {
        _log.info(
          'Sent ${clips.length} clips of reel $reelId to ${editor.name}',
        );
        return SendOutcome(SendResult.sent, clips.length);
      }
      await rollBack();
      _log.info('Sending to ${editor.name} gave ${result.name}; taken back');
      return SendOutcome(result, 0);
    } on Object catch (e) {
      _log.warning('Sending to ${editor.name} failed: ${e.runtimeType}');
      await rollBack();
      rethrow;
    }
  }

  /// Shares the live clips of [clipIds] through Android's chooser, in
  /// shooting order, with no session (R5). False when none is live (no
  /// bridge call). A chooser that did not open (no address to share, or the
  /// phone could not start it) throws [StateError]: it is a failure, not
  /// "no clip left" (T9-m3).
  Future<bool> share(List<int> clipIds, String chooserTitle) async {
    final clips = await _live(clipIds);
    if (clips.isEmpty) {
      _log.info('Nothing to share: no live clip');
      return false;
    }
    final opened = await _editors.shareWithChooser([
      for (final c in clips) ClipRef.of(c),
    ], chooserTitle);
    if (!opened) {
      _log.warning('The share menu did not open for ${clips.length} clips');
      throw StateError('The share menu did not open');
    }
    return true;
  }

  /// What copying [clipIds] of reel [reelId] for [editor] would take.
  ///
  /// First verifies the reel's copies (on this queue): a copy deleted outside
  /// TakeTray loses its row, so its clip is offered again; when the check
  /// itself fails the rows stay (logged) and their clips are not offered.
  /// Then keeps the reel's live clips with no copy, in shooting order. With
  /// no session the copy starts one (VN only): CapCut or Edits with no
  /// session, or a session of another editor, throw [StateError].
  Future<CopyPlan> planCopy(int reelId, EditorApp editor, List<int> clipIds) =>
      _serial(() async {
        final session = await _sessions.sessionOf(reelId);
        if (session != null && session.editor != editor) {
          throw StateError(
            'Reel $reelId is being edited in ${session.editor.name}',
          );
        }
        if (session == null && editor.takesShares) {
          throw StateError(
            '${editor.name} starts with a share, not with copies',
          );
        }
        final name = await _reelName(reelId);
        if (session != null) {
          try {
            await _verify(reelId);
          } on Object catch (e) {
            _log.warning(
              'Checking the copies of reel $reelId failed: ${e.runtimeType}',
            );
          }
        }
        final withCopy = await _copiedClipIds(reelId);
        final clips = [
          for (final c in await _live(clipIds, reelId: reelId))
            if (!withCopy.contains(c.id)) c,
        ];
        final need = clips.fold(0, (sum, c) => sum + c.fingerprint.sizeBytes);
        final free = await _editors.freeBytes();
        final folder = session?.folderName ?? await _newFolderName(name);
        _log.info(
          'Planned ${clips.length} copies for reel $reelId '
          '(${editor.name}), $need bytes, $free free',
        );
        return CopyPlan(
          reelId: reelId,
          editor: editor,
          clipIds: [for (final c in clips) c.id],
          needBytes: need,
          freeBytes: free,
          space: spaceCheck(needBytes: need, freeBytes: free),
          folderName: folder,
          startsSession: session == null,
        );
      });

  /// Starts copying [plan]'s clips and returns the job id
  /// (`<reelId>-<UTC ms>`).
  ///
  /// Starts the session first when [CopyPlan.startsSession]. The clips still
  /// live, in the reel and with no copy go in shooting order, named by
  /// `copyFileNames` from their local shot times (D-83) against the names
  /// the session's copies and the folder already have. The plan is saved
  /// **before** the engine starts. [CopyBusy] while another job's plan is
  /// saved (R4), writing nothing. A start that fails ([CopyBusy] from the
  /// engine or anything else) removes the plan and ends a session it just
  /// started, then rethrows. Nothing left to copy: [StateError], nothing
  /// written. A second call for the same reel, editor and clips while one
  /// runs gets the same id; another plan for the reel waits its turn (and is
  /// [CopyBusy] once the first one's plan is saved).
  Future<String> startCopy(CopyPlan plan) => _singleFlight(
    _starting,
    _flightKey(plan.reelId, plan.editor, plan.clipIds),
    () => _serial(() => _start(plan)),
  );

  /// The id of the copy job whose plan is saved, or null when none is: the
  /// job that makes every other start [CopyBusy] (I-1). The copy screens use
  /// it to open that job's own screen when a start finds it in the way.
  Future<String?> heldJobId() async => (await _phone.copyJobPlan())?.jobId;

  Future<String> _start(CopyPlan plan) async {
    final reelId = plan.reelId;
    if (await _phone.copyJobPlan() != null) throw const CopyBusy();
    // A new job: MediaStore may give an id an earlier job's copy had back.
    _forgotten.clear();
    var session = await _sessions.sessionOf(reelId);
    if (plan.startsSession && session != null) {
      throw StateError('Reel $reelId already has an editing session');
    }
    if (!plan.startsSession &&
        (session == null || session.editor != plan.editor)) {
      throw StateError('Reel $reelId has no ${plan.editor.name} session');
    }
    final state = await _sessions.editState(reelId);
    final withCopy = {
      for (final c in state?.copies ?? const <EditCopy>[]) c.clipId,
    };
    final clips = [
      for (final c in await _live(plan.clipIds, reelId: reelId))
        if (!withCopy.contains(c.id)) c,
    ];
    if (clips.isEmpty) {
      throw StateError('Nothing left to copy for reel $reelId');
    }
    var started = false;
    String? savedJob;
    try {
      if (plan.startsSession) {
        session = await _sessions.startSession(
          reelId,
          plan.editor,
          safeFolderName(await _reelName(reelId)),
          alsoTaken: await _editors.copyFolderNames(),
        );
        started = true;
      }
      final folder = session!.folderName;
      final inFolder = folder.toLowerCase();
      final taken = {
        for (final c in state?.copies ?? const <EditCopy>[]) c.fileName,
        for (final f in await _editors.filesInCopyFolders())
          if (f.folderName.toLowerCase() == inFolder) f.fileName,
      };
      final times = await _times.localTimes(clips);
      final names = copyFileNames([
        for (final c in clips)
          CopyNameSource(
            clipId: c.id,
            localShotAt: times[c.id]!.wallClock,
            extension: copyExtension(c.fingerprint.displayName, c.mimeType),
          ),
      ], taken);
      final jobId = '$reelId-${_clock.now().millisecondsSinceEpoch}';
      final items = [
        for (final c in clips)
          (
            clipId: c.id,
            fileName: names[c.id]!,
            sizeBytes: c.fingerprint.sizeBytes,
          ),
      ];
      await _phone.saveCopyJobPlan(
        CopyJobPlan(
          jobId: jobId,
          reelId: reelId,
          editor: plan.editor,
          folderName: folder,
          startedSession: started,
          items: items,
        ),
      );
      savedJob = jobId;
      await _copy.start(
        CopyRequest(
          jobId: jobId,
          reelId: reelId,
          folderName: folder,
          items: [
            for (final (i, c) in clips.indexed)
              CopyItem(
                clipId: c.id,
                source: ClipRef.of(c),
                fileName: items[i].fileName,
                sizeBytes: items[i].sizeBytes,
              ),
          ],
        ),
      );
      _log.info('Started copy job $jobId: ${items.length} clips');
      return jobId;
    } on Object catch (e) {
      _log.warning('Starting a copy for reel $reelId failed: ${e.runtimeType}');
      try {
        if (savedJob != null) await _phone.removeCopyJobPlan(savedJob);
        if (started) await _endIfEmpty(reelId);
      } on Object catch (undo) {
        _log.warning('Taking back a failed start failed: ${undo.runtimeType}');
      }
      rethrow;
    }
  }

  /// Stops job [jobId] and deletes its copies.
  ///
  /// The engine's own job: its answer is applied (the deleted copies' rows
  /// go, a copy it could not delete stays recorded) and the result cleared.
  /// A job recovered after a restart: the copies recorded for its items are
  /// deleted through the guard (`deleteCopies`) and their rows go; one that
  /// could not be deleted stays recorded. Then a session the job started
  /// ends when nothing is left in it, and the plan is removed. An engine or
  /// delete that throws leaves the plan for another try.
  Future<void> cancelCopy(String jobId) => _serial(() => _cancel(jobId));

  Future<void> _cancel(String jobId) async {
    final plan = await _phone.copyJobPlan();
    final mine = plan != null && plan.jobId == jobId;
    final answer = await _copy.cancel(jobId);
    if (answer != null) {
      await _apply(answer);
      await _clearEngine(jobId);
    } else if (mine) {
      // After a restart the recovery may not have run yet (or failed): run
      // it first, as Done editing does, so the finished files the plan names
      // are recorded and deleted and the half-written rows are swept, never
      // left as orphans (M-2). A recovery that fails throws and keeps the plan.
      await _recover(plan);
      await _cancelRecovered(plan);
    }
    if (mine) {
      if (plan.startedSession) await _endIfEmpty(plan.reelId);
      await _phone.removeCopyJobPlan(jobId);
    }
    if (answer != null || mine) _emitCleared(jobId);
    _log.info('Cancelled copy job $jobId');
  }

  Future<void> _cancelRecovered(CopyJobPlan plan) async {
    final items = {for (final i in plan.items) i.clipId};
    final state = await _sessions.editState(plan.reelId);
    final copies = [
      for (final c in state?.copies ?? const <EditCopy>[])
        if (items.contains(c.clipId)) c,
    ];
    var done = <int>{};
    if (copies.isNotEmpty) {
      final report = await _editors.deleteCopies([
        for (final c in copies) _ref(c, plan.folderName),
      ]);
      done = {...report.deleted, ...report.gone};
      _forgotten.addAll(done);
      await _sessions.removeCopies(plan.reelId, done);
    }
    final deleted = [
      for (final c in copies)
        if (done.contains(c.copyMediaStoreId)) _file(c),
    ];
    final kept = [
      for (final c in copies)
        if (!done.contains(c.copyMediaStoreId)) _file(c),
    ];
    final base = _jobFrom(plan, CopyState.cancelled, deleted);
    _emit(base.copyWith(undeleted: kept));
  }

  /// Copies again what job [jobId] has not copied yet (Try again).
  ///
  /// The engine's own job (`spaceFull` or `interrupted`) resumes there. After
  /// a restart, a new engine job with the same id copies only the plan's
  /// items with no recorded copy, keeping their names; when there are none
  /// left (or none can be read any more) the job finishes at once, as a
  /// `finished` job on [localJobs]. [CopyBusy] while another job holds the
  /// engine; [StateError] for a job with no plan.
  Future<void> resumeCopy(String jobId) => _serial(() async {
    final current = await _copy.current();
    if (current != null) {
      if (current.jobId != jobId) throw const CopyBusy();
      await _copy.resume(jobId);
      return;
    }
    final plan = await _phone.copyJobPlan();
    if (plan == null || plan.jobId != jobId) {
      throw StateError('No saved plan for copy job $jobId');
    }
    if (await _sessions.sessionOf(plan.reelId) == null) {
      throw StateError('Reel ${plan.reelId} has no editing session');
    }
    final recorded = await _copiedClipIds(plan.reelId);
    final left = [
      for (final i in plan.items)
        if (!recorded.contains(i.clipId)) i,
    ];
    final clips = {
      for (final c in await _live([
        for (final i in left) i.clipId,
      ], reelId: plan.reelId))
        c.id: c,
    };
    final items = [
      for (final i in left)
        if (clips[i.clipId] case final clip?)
          CopyItem(
            clipId: i.clipId,
            source: ClipRef.of(clip),
            fileName: i.fileName,
            sizeBytes: i.sizeBytes,
          ),
    ];
    if (items.isEmpty) {
      final job = await _recordedJob(plan, CopyState.finished);
      _emit(
        job.copyWith(
          done: job.total,
          failedClipIds: [for (final i in left) i.clipId],
        ),
      );
      _log.info('Copy job $jobId had nothing left: finished');
      return;
    }
    await _copy.start(
      CopyRequest(
        jobId: jobId,
        reelId: plan.reelId,
        folderName: plan.folderName,
        items: items,
      ),
    );
    _log.info('Resumed copy job $jobId: ${items.length} clips left');
  });

  /// Records the copies [job] made so far; called for every "file finished"
  /// event and for the result. Idempotent: a copy already recorded is not
  /// added again.
  ///
  /// Only the job whose plan is saved counts (an old job's event is
  /// ignored). A copy whose clip has left the reel, or whose reel has no
  /// session any more, is deleted through the guard and not recorded (if it
  /// cannot be deleted and the session exists, it is recorded so Done
  /// editing finds it). A copy this process already deleted or found gone is
  /// never recorded again. A cancelled job's deleted copies lose their rows;
  /// the copies it could not delete stay recorded.
  Future<void> applyJob(CopyJob job) => _serial(() => _apply(job));

  Future<void> _apply(CopyJob job) async {
    final plan = await _phone.copyJobPlan();
    if (plan == null || plan.jobId != job.jobId) {
      _log.fine('Ignored an event of copy job ${job.jobId}: not the plan');
      return;
    }
    if (job.state == CopyState.cancelled) {
      final gone = {for (final c in job.copied) c.copyMediaStoreId};
      _forgotten.addAll(gone);
      await _sessions.removeCopies(plan.reelId, gone);
      await _keep(plan.reelId, plan.folderName, job.undeleted);
      return;
    }
    await _keep(plan.reelId, plan.folderName, job.copied);
  }

  /// Records [files] of reel [reelId], or deletes the ones that must not
  /// stay (see [applyJob]).
  Future<void> _keep(int reelId, String folder, List<CopiedFile> files) async {
    final fresh = [
      for (final f in files)
        if (!_forgotten.contains(f.copyMediaStoreId)) f,
    ];
    if (fresh.isEmpty) return;
    final state = await _sessions.editState(reelId);
    final recorded = {
      for (final c in state?.copies ?? const <EditCopy>[])
        (c.clipId, c.copyMediaStoreId),
    };
    final todo = [
      for (final f in fresh)
        if (!recorded.contains((f.clipId, f.copyMediaStoreId))) f,
    ];
    if (todo.isEmpty) return;
    final inReel = state == null
        ? const <int>{}
        : await _clips.clipIdsOfReel(reelId);
    final stray = [
      for (final f in todo)
        if (!inReel.contains(f.clipId)) f,
    ];
    final keep = [
      for (final f in todo)
        if (inReel.contains(f.clipId)) f,
      if (state != null) ...await _deleteStray(folder, stray),
    ];
    if (state == null) await _deleteStray(folder, stray);
    var added = 0;
    for (final f in keep) {
      try {
        await _sessions.recordCopies([
          EditCopy(
            reelId: reelId,
            clipId: f.clipId,
            copyMediaStoreId: f.copyMediaStoreId,
            fileName: f.fileName,
            sizeBytes: f.sizeBytes,
            copiedAt: f.copiedAt,
          ),
        ]);
        added++;
        // `recordCopies` refuses a second copy of a clip, or a copy id held
        // under another clip, with a StateError (D-120): the file is then
        // left for the storage screen, never recorded twice.
        // ignore: avoid_catching_errors, see above
      } on StateError catch (e) {
        // Ids only (D-10): the message names no file.
        _log.warning('Copy ${f.copyMediaStoreId} not recorded: ${e.message}');
      }
    }
    _log.info('Reel $reelId: recorded $added copies, ${stray.length} not kept');
  }

  /// Deletes [files] through the guard; returns the ones still there.
  Future<List<CopiedFile>> _deleteStray(
    String folder,
    List<CopiedFile> files,
  ) async {
    if (files.isEmpty) return const [];
    final DeleteReport report;
    try {
      report = await _editors.deleteCopies([
        for (final f in files)
          CopyFileRef(
            mediaStoreId: f.copyMediaStoreId,
            folderName: folder,
            fileName: f.fileName,
          ),
      ]);
    } on Object catch (e) {
      _log.warning(
        'Deleting ${files.length} copies not kept failed: ${e.runtimeType}',
      );
      return files;
    }
    final done = {...report.deleted, ...report.gone};
    _forgotten.addAll(done);
    final left = [
      for (final f in files)
        if (!done.contains(f.copyMediaStoreId)) f,
    ];
    if (left.isNotEmpty) {
      _log.warning('${left.length} copies not kept could not be deleted');
    }
    return left;
  }

  /// Ends job [jobId]: records its result, deletes a copy of a clip that
  /// left the reel while it ran, clears the engine's result, ends a session
  /// the job started that holds nothing, and removes the plan. A job still
  /// running throws [StateError] and stays.
  Future<void> finishJob(String jobId) => _serial(() async {
    final plan = await _phone.copyJobPlan();
    final mine = plan != null && plan.jobId == jobId;
    final current = await _copy.current();
    if (current != null && current.jobId == jobId) {
      if (current.state == CopyState.running) {
        throw StateError('Copy job $jobId is still running');
      }
      await _apply(current);
    }
    if (mine) await _sweepLeft(plan);
    if (current != null && current.jobId == jobId) {
      await _clearEngine(jobId);
    }
    if (mine) {
      if (plan.startedSession) await _endIfEmpty(plan.reelId);
      await _phone.removeCopyJobPlan(jobId);
    }
    _emitCleared(jobId);
    _log.info('Finished copy job $jobId');
  });

  /// Deletes the copies of [plan]'s clips that are no longer in the reel
  /// (recorded just before a remove's clean-up ran). One that cannot be
  /// deleted stays recorded.
  Future<void> _sweepLeft(CopyJobPlan plan) async {
    final state = await _sessions.editState(plan.reelId);
    if (state == null) return;
    final items = {for (final i in plan.items) i.clipId};
    final inReel = await _clips.clipIdsOfReel(plan.reelId);
    final stray = [
      for (final c in state.copies)
        if (items.contains(c.clipId) && !inReel.contains(c.clipId)) _file(c),
    ];
    if (stray.isEmpty) return;
    final left = {
      for (final f in await _deleteStray(plan.folderName, stray))
        f.copyMediaStoreId,
    };
    await _sessions.removeCopies(plan.reelId, [
      for (final f in stray)
        if (!left.contains(f.copyMediaStoreId)) f.copyMediaStoreId,
    ]);
  }

  /// Done editing: deletes every copy of reel [reelId] through the guard,
  /// then ends the session. A copy already gone counts as deleted;
  /// `freedBytes` sums the ones deleted now.
  ///
  /// It is never stuck behind a job that is over. A copy job of this reel
  /// that runs ([CopyState.running]) throws [StateError]. Any other job of the
  /// reel (finished and never continued, cancelled, `spaceFull`,
  /// `interrupted`, or a plan left after a restart) is settled first on this
  /// queue: the engine's result is applied (so its copies are deleted too),
  /// cleared, and the plan removed (D-123).
  ///
  /// A copy the guard refuses (the file in that place is no longer
  /// TakeTray's) does not stop it: its row goes with the session, the file
  /// stays for the storage screen (R7) and [DoneEditingResult.leftBehind]
  /// counts it. A copy whose delete failed (or a delete that throws)
  /// throws [CopiesNotDeleted]: the session and the rows not deleted stay
  /// (the refused ones too), the deleted rows go, and Done editing can be
  /// tried again. [StateError] with no session.
  Future<DoneEditingResult> doneEditing(int reelId) => _serial(() async {
    await _settleJobOf(reelId);
    final state = await _sessions.editState(reelId);
    if (state == null) {
      throw StateError('Reel $reelId has no editing session');
    }
    final (_, freed, refused) = await _deleteCopies(
      reelId,
      state.session.folderName,
      state.copies,
      dropRefused: true,
    );
    await _sessions.endSession(reelId);
    _log.info(
      'Done editing reel $reelId (${state.session.editor.name}): '
      '$freed bytes freed, $refused left behind',
    );
    return DoneEditingResult(
      editor: state.session.editor,
      freedBytes: freed,
      leftBehind: refused,
    );
  });

  /// Settles the copy job of reel [reelId] that is over, for [doneEditing]
  /// (see there); throws [StateError] for one that runs.
  ///
  /// With the engine holding the job, its result is applied and cleared. With
  /// a saved plan of this reel and no engine job (after a restart, before
  /// [recoverAtStart] ran or after it failed), the recovery step runs first:
  /// the half-written rows go and the finished files the plan names are
  /// recorded, so the caller deletes them and counts their bytes. A recovery
  /// that fails throws and leaves the plan, so the files are never forgotten.
  /// An engine that still holds the job after `clear` (it is still deleting
  /// its copies) also throws, leaving the plan: Done editing can be tried
  /// again, and no `CopyBusy` is left behind.
  Future<void> _settleJobOf(int reelId) async {
    final current = await _copy.current();
    if (current != null &&
        current.reelId == reelId &&
        current.state == CopyState.running) {
      throw StateError('A copy job for reel $reelId is still running');
    }
    final plan = await _phone.copyJobPlan();
    if (plan == null || plan.reelId != reelId) return;
    if (current != null && current.jobId == plan.jobId) {
      await _apply(current);
      await _clearEngine(plan.jobId);
    } else if (current == null) {
      await _recover(plan);
    }
    await _phone.removeCopyJobPlan(plan.jobId);
    _emitCleared(plan.jobId);
    _log.info('Settled copy job ${plan.jobId} for Done editing');
  }

  /// Clears the engine's result for [jobId]. The engine ignores that for a
  /// job still deleting its copies; then this throws [StateError] (the
  /// caller keeps the plan), instead of leaving the engine holding a job
  /// nobody will clear (every later start would be `CopyBusy`).
  Future<void> _clearEngine(String jobId) async {
    await _copy.clear(jobId);
    final left = await _copy.current();
    if (left != null && left.jobId == jobId) {
      throw StateError('Copy job $jobId is not cleared yet');
    }
  }

  /// Deletes [copies] of reel [reelId] through the guard and removes the
  /// rows of the ones deleted or gone; returns how many, the bytes freed and
  /// how many the guard refused and [dropRefused] let go (their rows are
  /// removed too, the files stay). Throws [CopiesNotDeleted] when any is
  /// left; then a refused row stays as well.
  Future<(int, int, int)> _deleteCopies(
    int reelId,
    String folder,
    List<EditCopy> copies, {
    bool dropRefused = false,
  }) async {
    if (copies.isEmpty) return (0, 0, 0);
    final DeleteReport report;
    try {
      report = await _editors.deleteCopies([
        for (final c in copies) _ref(c, folder),
      ]);
    } on Object catch (e) {
      _log.warning(
        'Deleting ${copies.length} copies of reel $reelId failed: '
        '${e.runtimeType}',
      );
      throw CopiesNotDeleted(copies.length);
    }
    final done = {...report.deleted, ...report.gone};
    _forgotten.addAll(done);
    final asked = {for (final c in copies) c.copyMediaStoreId};
    final letGo = dropRefused ? report.refused.intersection(asked) : <int>{};
    final unsettled = copies.length - done.length - letGo.length;
    final rows = unsettled > 0 ? done : {...done, ...letGo};
    await _sessions.removeCopies(reelId, rows);
    final removed = [
      for (final c in copies)
        if (done.contains(c.copyMediaStoreId)) c,
    ];
    final freed = [
      for (final c in removed)
        if (report.deleted.contains(c.copyMediaStoreId)) c.sizeBytes,
    ].fold(0, (sum, size) => sum + size);
    final left = copies.length - removed.length;
    if (unsettled > 0) {
      _log.warning(
        'Reel $reelId: ${removed.length} copies deleted, $left not '
        '(refused ${report.refused.length}, failed ${report.failed.length})',
      );
      throw CopiesNotDeleted(left);
    }
    if (letGo.isNotEmpty) {
      _log.warning(
        'Reel $reelId: ${letGo.length} copies left behind (refused)',
      );
    }
    return (removed.length, freed, letGo.length);
  }

  /// Forgets the copies of reel [reelId] whose files are gone (deleted
  /// outside TakeTray). A failing check changes nothing and is passed on.
  Future<void> verifyCopies(int reelId) => _serial(() => _verify(reelId));

  Future<void> _verify(int reelId) async {
    final state = await _sessions.editState(reelId);
    if (state == null || state.copies.isEmpty) return;
    final folder = state.session.folderName;
    final existing = await _editors.existingCopies([
      for (final c in state.copies) _ref(c, folder),
    ]);
    final gone = {
      for (final c in state.copies)
        if (!existing.contains(c.copyMediaStoreId)) c.copyMediaStoreId,
    };
    if (gone.isEmpty) return;
    _forgotten.addAll(gone);
    await _sessions.removeCopies(reelId, gone);
    _log.info('Reel $reelId: ${gone.length} copies were gone');
  }

  /// Before [clipIds] leave reel [reelId] (a remove, a move, a missing
  /// clip's removal): deletes their copies and rows, and returns how many
  /// (R8). Sent rows stay. With no session, nothing. A copy that cannot be
  /// deleted throws [CopiesNotDeleted]: the caller removes nothing.
  Future<int> beforeClipsLeaveReel(int reelId, Set<int> clipIds) =>
      _serial(() async {
        final state = await _sessions.editState(reelId);
        if (state == null) return 0;
        final copies = [
          for (final c in state.copies)
            if (clipIds.contains(c.clipId)) c,
        ];
        final (count, _, _) = await _deleteCopies(
          reelId,
          state.session.folderName,
          copies,
          dropRefused: true,
        );
        if (count > 0) {
          _log.info('Reel $reelId: deleted $count copies of leaving clips');
        }
        return count;
      });

  /// Before reel [reelId] is deleted: cancels its copy job, deletes every
  /// copy and ends the session (R8: Undo brings the reel back with no
  /// session). Any failure throws and nothing is ended.
  Future<void> beforeReelDelete(int reelId) => _serial(() async {
    final plan = await _phone.copyJobPlan();
    final current = await _copy.current();
    if (current != null && current.reelId == reelId) {
      await _cancel(current.jobId);
    } else if (plan != null && plan.reelId == reelId) {
      await _cancel(plan.jobId);
    }
    final state = await _sessions.editState(reelId);
    if (state == null) return;
    await _deleteCopies(
      reelId,
      state.session.folderName,
      state.copies,
      dropRefused: true,
    );
    await _sessions.endSession(reelId);
    _log.info('Reel $reelId: session ended before its delete');
  });

  /// Every session, and the files in the copy folders that no session
  /// records, grouped by folder (by name). The folder of a running job or a
  /// saved plan is never listed (its copies may not be recorded yet). When
  /// the folders cannot be read: the sessions, no orphans (logged).
  Future<StorageOverview> storage() => _serial(() async {
    final summaries = await _sessions.summaries();
    final List<CopyFolderFile> files;
    try {
      files = await _editors.filesInCopyFolders();
    } on Object catch (e) {
      _log.warning('Reading the copy folders failed: ${e.runtimeType}');
      return StorageOverview(sessions: summaries, orphans: const []);
    }
    final recorded = <int>{
      for (final s in summaries)
        for (final c in await _sessions.copiesOf(s.reelId)) c.copyMediaStoreId,
    };
    final busy = <String>{};
    final plan = await _phone.copyJobPlan();
    if (plan != null) busy.add(plan.folderName.toLowerCase());
    try {
      final current = await _copy.current();
      if (current != null) busy.add(current.folderName.toLowerCase());
    } on Object catch (e) {
      _log.warning('Reading the copy job failed: ${e.runtimeType}');
    }
    final byFolder = <String, List<CopyFolderFile>>{};
    for (final f in files) {
      if (recorded.contains(f.mediaStoreId)) continue;
      if (busy.contains(f.folderName.toLowerCase())) continue;
      byFolder.putIfAbsent(f.folderName, () => []).add(f);
    }
    final names = byFolder.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final orphans = [
      for (final name in names)
        OrphanFolder(
          folderName: name,
          fileCount: byFolder[name]!.length,
          bytes: byFolder[name]!.fold(0, (sum, f) => sum + f.sizeBytes),
          files: [
            for (final f in byFolder[name]!)
              CopyFileRef(
                mediaStoreId: f.mediaStoreId,
                folderName: f.folderName,
                fileName: f.fileName,
              ),
          ],
        ),
    ];
    _log.info(
      'Storage: ${summaries.length} sessions, ${orphans.length} orphan '
      'folders',
    );
    return StorageOverview(sessions: summaries, orphans: orphans);
  });

  /// Asks Android to delete [folder]'s files (its consent dialog, R7). The
  /// answer says whether the user allowed it and, apart from that, the bytes
  /// freed, so an allowed delete of files that report no size is still
  /// allowed (D-130).
  Future<OrphanDeleteResult> deleteOrphans(OrphanFolder folder) async {
    final allowed = await _editors.requestDelete(folder.files);
    _log.info(
      allowed
          ? 'Deleted ${folder.fileCount} orphan copies'
          : 'Deleting ${folder.fileCount} orphan copies was declined',
    );
    return allowed
        ? OrphanDeleteResult.allowed(folder.bytes)
        : const OrphanDeleteResult.declined();
  }

  /// Once per app start, after the scan (D-123).
  ///
  /// - The engine still holds a job (the activity was re-created, the
  ///   process lived on): it is applied, nothing is deleted; null.
  /// - Otherwise, with a saved plan (Android stopped TakeTray mid-copy):
  ///   first the folder's pending rows are deleted (`deletePendingIn`), then
  ///   its finished rows whose file name is a plan item's are recorded for
  ///   that item's clip, at the clock (a copy already recorded is not added
  ///   twice); a finished row matching no item is left for the storage
  ///   screen. The answer is an `interrupted` job listing the items with a
  ///   recorded copy, also sent on [localJobs]. If the reel's session is
  ///   gone, the copies found are deleted and the plan is removed (null).
  /// - Then sessions with no copies, no sent rows and no plan end.
  ///
  /// A failure is logged by type and changes nothing more: the plan stays,
  /// the answer is null and [recoveryFailed] is true until a later call
  /// works (the app's next resume calls it again).
  Future<CopyJob?> recoverAtStart() => _serial(() async {
    try {
      final job = await _recoverAtStart();
      _recoveryFailed = false;
      return job;
    } on Object catch (e) {
      _recoveryFailed = true;
      _log.warning('Recovering the copy job failed: ${e.runtimeType}');
      return null;
    }
  });

  bool _recoveryFailed = false;

  /// Whether the last [recoverAtStart] failed (it logs the failure and
  /// answers null, so the answer alone cannot tell). False before the first
  /// call. `MediaLifecycle` calls it again on a resume while this is true.
  bool get recoveryFailed => _recoveryFailed;

  Future<CopyJob?> _recoverAtStart() async {
    final current = await _copy.current();
    final plan = await _phone.copyJobPlan();
    if (current != null) {
      await _apply(current);
      await _endEmptySessions({current.reelId, ?plan?.reelId});
      _log.info('Copy job ${current.jobId} is still in this process');
      return null;
    }
    if (plan == null) {
      await _endEmptySessions(const {});
      return null;
    }
    final job = await _recover(plan);
    await _endEmptySessions({if (job != null) plan.reelId});
    if (job != null) _emit(job);
    return job;
  }

  Future<CopyJob?> _recover(CopyJobPlan plan) async {
    final swept = await _copy.deletePendingIn(plan.folderName);
    final rows = {
      for (final r in await _copy.ownRowsIn(plan.folderName))
        if (!r.pending) r.fileName: r,
    };
    final at = _clock.storedNow();
    final found = [
      for (final i in plan.items)
        if (rows[i.fileName] case final row?)
          CopiedFile(
            clipId: i.clipId,
            copyMediaStoreId: row.mediaStoreId,
            fileName: row.fileName,
            sizeBytes: row.sizeBytes,
            copiedAt: at,
          ),
    ];
    if (await _sessions.sessionOf(plan.reelId) == null) {
      final left = await _deleteStray(plan.folderName, found);
      await _phone.removeCopyJobPlan(plan.jobId);
      _log.warning(
        'Copy job ${plan.jobId} had no session: ${found.length - left.length} '
        'copies deleted, ${left.length} left; plan removed',
      );
      return null;
    }
    await _keep(plan.reelId, plan.folderName, found);
    final recorded = await _recordedJob(plan, CopyState.interrupted);
    // Every item has its copy: the job did finish, only the finish never
    // reached Dart (M-4). It is shown as finished, so the normal finish runs.
    final job = recorded.total > 0 && recorded.done >= recorded.total
        ? recorded.copyWith(state: CopyState.finished)
        : recorded.copyWith(wasClosed: true);
    _log.info(
      'Recovered copy job ${plan.jobId}: $swept pending rows removed, '
      '${found.length} finished rows found, ${job.done} of ${job.total} '
      'recorded',
    );
    return job;
  }

  /// [plan] as a job in [state], listing the items with a recorded copy.
  Future<CopyJob> _recordedJob(CopyJobPlan plan, CopyState state) async {
    final byClip = {
      for (final c in await _sessions.copiesOf(plan.reelId)) c.clipId: c,
    };
    return _jobFrom(plan, state, [
      for (final i in plan.items)
        if (byClip[i.clipId] case final copy?) _file(copy),
    ]);
  }

  CopyJob _jobFrom(CopyJobPlan plan, CopyState state, List<CopiedFile> done) =>
      CopyJob(
        jobId: plan.jobId,
        reelId: plan.reelId,
        folderName: plan.folderName,
        state: state,
        total: plan.items.length,
        done: done.length,
        bytesDone: done.fold(0, (sum, f) => sum + f.sizeBytes),
        bytesTotal: plan.items.fold(0, (sum, i) => sum + i.sizeBytes),
        copied: done,
        failedClipIds: const [],
        undeleted: const [],
      );

  /// Ends every session, except those of [keep], with no copies and no sent
  /// rows (a send or a first copy that never finished).
  Future<void> _endEmptySessions(Set<int> keep) async {
    var ended = 0;
    for (final s in await _sessions.summaries()) {
      if (s.copyCount > 0 || keep.contains(s.reelId)) continue;
      if (await _endIfEmpty(s.reelId)) ended++;
    }
    if (ended > 0) _log.info('Ended $ended empty editing sessions');
  }

  /// Ends reel [reelId]'s session when it holds no copy and no sent clip.
  Future<bool> _endIfEmpty(int reelId) async {
    final state = await _sessions.editState(reelId);
    if (state == null || state.copies.isNotEmpty || state.sentIds.isNotEmpty) {
      return false;
    }
    await _sessions.endSession(reelId);
    return true;
  }

  /// The saved plan's editor and whether it started its session, while job
  /// [jobId]'s plan is saved (also after a restart); null otherwise.
  Future<({EditorApp editor, bool startedSession})?> jobContext(
    String jobId,
  ) async {
    final plan = await _phone.copyJobPlan();
    if (plan == null || plan.jobId != jobId) return null;
    return (editor: plan.editor, startedSession: plan.startedSession);
  }

  /// The clips of [clipIds] that exist and are not missing (and are in reel
  /// [reelId] when given), in shooting order.
  Future<List<Clip>> _live(Iterable<int> clipIds, {int? reelId}) async {
    final inReel = reelId == null ? null : await _clips.clipIdsOfReel(reelId);
    final clips = [
      for (final c in await _clips.clipsByIds(clipIds))
        if (!c.missing && (inReel == null || inReel.contains(c.id))) c,
    ];
    return inShootingOrder(clips);
  }

  Future<Set<int>> _copiedClipIds(int reelId) async => {
    for (final c in await _sessions.copiesOf(reelId)) c.clipId,
  };

  Future<String> _reelName(int reelId) async {
    final reel = await _reels.getById(reelId);
    if (reel == null) throw StateError('No reel with id $reelId');
    return reel.name;
  }

  /// The folder a new session of a reel named [reelName] would get.
  Future<String> _newFolderName(String reelName) async =>
      uniqueFolderName(normalizeName(safeFolderName(reelName)), {
        for (final s in await _sessions.summaries()) s.folderName,
        ...await _editors.copyFolderNames(),
      });

  static CopyFileRef _ref(EditCopy c, String folder) => CopyFileRef(
    mediaStoreId: c.copyMediaStoreId,
    folderName: folder,
    fileName: c.fileName,
  );

  static CopiedFile _file(EditCopy c) => CopiedFile(
    clipId: c.clipId,
    copyMediaStoreId: c.copyMediaStoreId,
    fileName: c.fileName,
    sizeBytes: c.sizeBytes,
    copiedAt: c.copiedAt,
  );

  /// Stops [localJobs] (the provider is disposed).
  void dispose() {
    unawaited(_local.close());
    unawaited(_cleared.close());
  }
}

@Riverpod(keepAlive: true)
EditSessionService editSessionService(Ref ref) {
  final clips = ref.watch(clipsRepositoryProvider);
  final reels = ref.watch(reelsRepositoryProvider);
  final service = EditSessionService(
    ref.watch(editSessionsRepositoryProvider),
    clips,
    reels,
    ref.watch(phoneStateRepositoryProvider),
    ref.watch(editorsBridgeProvider),
    ref.watch(copyBridgeProvider),
    ref.watch(clipTimeServiceProvider),
    ref.watch(clockProvider),
  );
  // The paths that take a clip out of a reel without a screen of their own
  // (an undo, a merge) run the copy clean-up first (R8, D-123). The
  // repositories cannot read this provider (it reads them), so it hands
  // them the hook.
  Future<void> beforeLeave(int reelId, Set<int> clipIds) async {
    await service.beforeClipsLeaveReel(reelId, clipIds);
  }

  clips.beforeLeave = beforeLeave;
  reels.beforeLeave = beforeLeave;
  ref.onDispose(() {
    clips.beforeLeave = null;
    reels.beforeLeave = null;
    service.dispose();
  });
  return service;
}
