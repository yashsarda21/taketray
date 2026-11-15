import 'package:taketray/platform/copy_bridge.dart';

/// What a copy job asks the copy screen to show (D-127).
enum CopyStage {
  /// Copying: the progress screen, the screen kept on.
  running,

  /// Every clip was copied.
  finished,

  /// It ended, but some clips could not be copied and the rest were.
  someFailed,

  /// It ended and not one clip could be copied.
  allFailed,

  /// The phone's storage filled up; Try again can go on.
  spaceFull,

  /// TakeTray was stopped mid-copy (a restart's recovery, or a copy that
  /// failed for a reason that is not the clip's); Try again can go on.
  interrupted,

  /// Stopped by the user (or the reel was deleted): nothing to show.
  cancelled,
}

/// The stage of [job]: its state, and for a finished job whether any clip
/// failed (and whether every one did).
CopyStage copyStageOf(CopyJob job) {
  switch (job.state) {
    case CopyState.running:
      return CopyStage.running;
    case CopyState.spaceFull:
      return CopyStage.spaceFull;
    case CopyState.interrupted:
      return CopyStage.interrupted;
    case CopyState.cancelled:
      return CopyStage.cancelled;
    case CopyState.finished:
      final failed = copyFailedCount(job);
      if (failed == 0) return CopyStage.finished;
      return failed >= job.total ? CopyStage.allFailed : CopyStage.someFailed;
  }
}

/// How many clips of [job] could not be copied (each clip counted once).
int copyFailedCount(CopyJob job) => job.failedClipIds.toSet().length;
