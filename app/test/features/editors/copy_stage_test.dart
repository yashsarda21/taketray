import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/editors/view_models/copy_stage.dart';
import 'package:taketray/platform/copy_bridge.dart';

CopyJob _job(
  CopyState state, {
  int total = 3,
  List<int> failed = const [],
  int done = 0,
}) => CopyJob(
  jobId: '1-2000',
  reelId: 1,
  folderName: 'Goa',
  state: state,
  total: total,
  done: done,
  bytesDone: 0,
  bytesTotal: 0,
  copied: const [],
  failedClipIds: failed,
  undeleted: const [],
);

void main() {
  group('the stage of a job', () {
    test('running, spaceFull, interrupted and cancelled are their own', () {
      expect(copyStageOf(_job(CopyState.running)), CopyStage.running);
      expect(copyStageOf(_job(CopyState.spaceFull)), CopyStage.spaceFull);
      expect(copyStageOf(_job(CopyState.interrupted)), CopyStage.interrupted);
      expect(copyStageOf(_job(CopyState.cancelled)), CopyStage.cancelled);
    });

    test('failed clips do not change a job that is not finished', () {
      for (final (state, stage) in [
        (CopyState.running, CopyStage.running),
        (CopyState.spaceFull, CopyStage.spaceFull),
        (CopyState.interrupted, CopyStage.interrupted),
        (CopyState.cancelled, CopyStage.cancelled),
      ]) {
        expect(copyStageOf(_job(state, failed: [1, 2, 3])), stage);
      }
    });

    test('finished with no failed clip is finished, also with no items', () {
      expect(copyStageOf(_job(CopyState.finished)), CopyStage.finished);
      expect(
        copyStageOf(_job(CopyState.finished, total: 0)),
        CopyStage.finished,
      );
    });

    test('finished with some failed clips: some failed', () {
      expect(
        copyStageOf(_job(CopyState.finished, failed: [4])),
        CopyStage.someFailed,
      );
      expect(
        copyStageOf(_job(CopyState.finished, failed: [4, 5])),
        CopyStage.someFailed,
      );
    });

    test('finished with every clip failed: all failed, also with one clip', () {
      expect(
        copyStageOf(_job(CopyState.finished, failed: [4, 5, 6])),
        CopyStage.allFailed,
      );
      expect(
        copyStageOf(_job(CopyState.finished, total: 1, failed: [4])),
        CopyStage.allFailed,
      );
    });

    test('a clip listed twice counts once; more failed than items (a bad '
        'count) is all failed, never a crash', () {
      expect(
        copyStageOf(_job(CopyState.finished, failed: [4, 4])),
        CopyStage.someFailed,
      );
      expect(copyFailedCount(_job(CopyState.finished, failed: [4, 4, 5])), 2);
      expect(
        copyStageOf(_job(CopyState.finished, total: 2, failed: [1, 2, 3])),
        CopyStage.allFailed,
      );
      expect(copyFailedCount(_job(CopyState.finished)), 0);
    });
  });
}
