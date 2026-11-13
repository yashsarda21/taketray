import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/platform/copy_bridge.dart';

import 'vm_harness.dart';

/// The real [EditSessionService] on a [VmHarness]'s database and fake
/// bridges, which notes the hooks the reel screens and the app start call
/// (in [calls], in order) and can make one fail.
///
/// - `beforeClipsLeaveReel` notes `leave <reel> <sorted ids>` and the reel's
///   clip ids at that moment in [reelClipsAtLeave]; [failLeave] makes it
///   throw that error instead.
/// - `beforeReelDelete` notes `reelDelete <reel>`; [failReelDelete] throws.
/// - `recoverAtStart` notes `recover`; [failRecover] throws.
/// - `applyJob` notes each job in [applied] (and then applies it), or
///   throws [failApply].
class SpyEditSessionService extends EditSessionService {
  SpyEditSessionService(this.h)
    : super(
        EditSessionsRepository(h.media.db, h.media.clock),
        h.media.clips,
        ReelsRepository(h.media.db, h.media.clock),
        h.media.phoneState,
        h.editors,
        h.copy,
        ClipTimeService(h.bridge),
        h.media.clock,
      );

  final VmHarness h;
  final List<String> calls = [];
  final List<Set<int>> reelClipsAtLeave = [];
  final List<CopyJob> applied = [];

  /// The media bridge's calls so far, each time `recoverAtStart` ran.
  final List<List<String>> mediaCallsAtRecover = [];
  Object? failLeave;
  Object? failReelDelete;
  Object? failRecover;
  Object? failApply;

  @override
  Future<int> beforeClipsLeaveReel(int reelId, Set<int> clipIds) async {
    calls.add('leave $reelId ${(clipIds.toList()..sort()).join(',')}');
    reelClipsAtLeave.add(await h.media.clips.clipIdsOfReel(reelId));
    final fail = failLeave;
    if (fail != null) Error.throwWithStackTrace(fail, StackTrace.current);
    return await super.beforeClipsLeaveReel(reelId, clipIds);
  }

  @override
  Future<void> beforeReelDelete(int reelId) async {
    calls.add('reelDelete $reelId');
    final fail = failReelDelete;
    if (fail != null) Error.throwWithStackTrace(fail, StackTrace.current);
    return await super.beforeReelDelete(reelId);
  }

  @override
  Future<CopyJob?> recoverAtStart() async {
    calls.add('recover');
    mediaCallsAtRecover.add(List.of(h.bridge.calls));
    final fail = failRecover;
    if (fail != null) Error.throwWithStackTrace(fail, StackTrace.current);
    return await super.recoverAtStart();
  }

  @override
  Future<void> applyJob(CopyJob job) async {
    applied.add(job);
    final fail = failApply;
    if (fail != null) Error.throwWithStackTrace(fail, StackTrace.current);
    return await super.applyJob(job);
  }
}
