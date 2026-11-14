import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/platform/copy_bridge.dart';

part 'copy_job_controller.g.dart';

// Job ids, counts and error types only (D-10).
final Logger _log = Logger('copyJob');

/// The copy job the copy screens follow (D-123): the engine's job, or the
/// one `EditSessionService` built itself (the interrupted job a restart
/// recovered, a resumed job that finished at once, a recovered job that was
/// cancelled). Null when there is none.
///
/// It follows the engine's `changes` and the service's `localJobs`, and
/// reads the engine's job when it is built and on [onResume] (the engine
/// drops its events while no Dart side listens, D-122). For each engine
/// event with a new finished file (or undeleted file, or a new end state) it
/// calls `EditSessionService.applyJob`, which records the copies; progress
/// alone records nothing. An event of a job the controller saw before the one
/// held is ignored (the order they were followed in, not the time in the id:
/// a phone clock set back must not make a new job look old).
///
/// A job that ended for good (`EditSessionService.clearedJobs`: finished,
/// cancelled, or settled by Done editing) is dropped: the controller holds
/// nothing for it and ignores its late events, so the copy screen is never
/// opened for a job with no plan. A job that keeps its id through Try again
/// is unseen again when it stops in another state (see [takeUnseenResult]).
///
/// Kept alive: the app's start builds it (`MediaLifecycle`), so a job is
/// followed and recorded whether or not a copy screen is open.
@Riverpod(keepAlive: true)
class CopyJobController extends _$CopyJobController {
  /// The end state in which each job id was last shown (taken).
  final Map<String, CopyState> _seen = {};

  /// Ids of jobs that ended for good: their events are ignored.
  final Set<String> _dropped = {};

  /// Job ids in the order they were first followed, oldest first.
  final List<String> _seenOrder = [];

  /// What the last `applyJob` call was for: job id, copied count,
  /// undeleted count, and the end state (null while running).
  (String, int, int, CopyState?)? _applied;

  @override
  CopyJob? build() {
    final service = ref.watch(editSessionServiceProvider);
    final bridge = ref.watch(copyBridgeProvider);
    final engine = bridge.changes.listen(_onEngine);
    final local = service.localJobs.listen(_onLocal);
    final cleared = service.clearedJobs.listen(_onCleared);
    ref.onDispose(() {
      unawaited(engine.cancel());
      unawaited(local.cancel());
      unawaited(cleared.cancel());
    });
    unawaited(_readEngine());
    final last = service.lastLocalJob;
    if (last != null) _see(last.jobId);
    return last;
  }

  /// Reads the engine's job again (the app came back to the front) and
  /// records what it holds.
  Future<void> onResume() => _readEngine();

  /// True once for each stop of a job that is not running: the result the
  /// app opens the copy screen for (on start or resume).
  ///
  /// A resumed job keeps its id (Try again), so "seen" is kept per job id and
  /// end state: a job seen as `spaceFull` that comes back to running and
  /// ends (or is found ended after events were dropped) is unseen again.
  bool takeUnseenResult() {
    final job = state;
    if (job == null || job.state == CopyState.running) return false;
    if (_seen[job.jobId] == job.state) return false;
    _seen[job.jobId] = job.state;
    return true;
  }

  Future<void> _readEngine() async {
    final CopyJob? job;
    try {
      job = await ref.read(copyBridgeProvider).current();
    } on Object catch (e) {
      _log.warning('Reading the copy job failed: ${e.runtimeType}');
      return;
    }
    if (!ref.mounted || job == null) return;
    _onEngine(job);
  }

  void _onLocal(CopyJob job) {
    if (!ref.mounted || _dropped.contains(job.jobId) || _isOlder(job)) return;
    _see(job.jobId);
    state = job;
  }

  void _onCleared(String jobId) {
    if (!ref.mounted) return;
    _dropped.add(jobId);
    if (state?.jobId == jobId) state = null;
  }

  void _onEngine(CopyJob job) {
    if (!ref.mounted || _dropped.contains(job.jobId) || _isOlder(job)) return;
    if (job.state == CopyState.running) _seen.remove(job.jobId);
    _see(job.jobId);
    state = job;
    final key = (
      job.jobId,
      job.copied.length,
      job.undeleted.length,
      job.state == CopyState.running ? null : job.state,
    );
    final last = _applied;
    final before = last != null && last.$1 == job.jobId
        ? last
        : (job.jobId, 0, 0, null);
    if (key == before) return;
    _applied = key;
    unawaited(_apply(job));
  }

  Future<void> _apply(CopyJob job) async {
    try {
      await ref.read(editSessionServiceProvider).applyJob(job);
    } on Object catch (e) {
      _log.warning('Recording copy job ${job.jobId} failed: ${e.runtimeType}');
    }
  }

  /// Whether [job] is older than the job held: it is another job, and the
  /// controller saw it before the held one. The order is the one the jobs
  /// were first seen in, not their ids' times, so a phone clock that was set
  /// back never makes a new job look old (T6-M4). A job never seen is the
  /// newest.
  bool _isOlder(CopyJob job) {
    final held = state;
    if (held == null || held.jobId == job.jobId) return false;
    final heldAt = _seenOrder.indexOf(held.jobId);
    final jobAt = _seenOrder.indexOf(job.jobId);
    return heldAt >= 0 && jobAt >= 0 && jobAt < heldAt;
  }

  /// Notes that [jobId] was followed, newest last.
  void _see(String jobId) {
    if (!_seenOrder.contains(jobId)) _seenOrder.add(jobId);
  }
}
