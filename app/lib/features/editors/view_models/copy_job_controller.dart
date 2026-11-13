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
/// alone records nothing. An event of an older job than the one held (job ids
/// are `<reelId>-<UTC ms>`) is ignored.
///
/// Kept alive: the app's start builds it (`MediaLifecycle`), so a job is
/// followed and recorded whether or not a copy screen is open.
@Riverpod(keepAlive: true)
class CopyJobController extends _$CopyJobController {
  final Set<String> _seen = {};

  /// What the last `applyJob` call was for: job id, copied count,
  /// undeleted count, and the end state (null while running).
  (String, int, int, CopyState?)? _applied;

  @override
  CopyJob? build() {
    final service = ref.watch(editSessionServiceProvider);
    final bridge = ref.watch(copyBridgeProvider);
    final engine = bridge.changes.listen(_onEngine);
    final local = service.localJobs.listen(_onLocal);
    ref.onDispose(() {
      unawaited(engine.cancel());
      unawaited(local.cancel());
    });
    unawaited(_readEngine());
    return service.lastLocalJob;
  }

  /// Reads the engine's job again (the app came back to the front) and
  /// records what it holds.
  Future<void> onResume() => _readEngine();

  /// True once per job id in this process, for a job that is not running:
  /// the result the app opens the copy screen for (on start or resume).
  bool takeUnseenResult() {
    final job = state;
    if (job == null || job.state == CopyState.running) return false;
    return _seen.add(job.jobId);
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
    if (!ref.mounted || _isOlder(job)) return;
    state = job;
  }

  void _onEngine(CopyJob job) {
    if (!ref.mounted || _isOlder(job)) return;
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

  /// Whether [job] is older than the job held: its id's time is earlier.
  bool _isOlder(CopyJob job) {
    final held = state;
    if (held == null || held.jobId == job.jobId) return false;
    final heldAt = _startedAt(held.jobId);
    final jobAt = _startedAt(job.jobId);
    return heldAt != null && jobAt != null && jobAt < heldAt;
  }

  /// The UTC ms of a job id `<reelId>-<UTC ms>`, or null.
  static int? _startedAt(String jobId) {
    final dash = jobId.lastIndexOf('-');
    return dash < 0 ? null : int.tryParse(jobId.substring(dash + 1));
  }
}
