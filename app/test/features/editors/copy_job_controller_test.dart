import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/platform/copy_bridge.dart';

import '../../support/reel_videos.dart';
import '../../support/spy_edit_session_service.dart';
import '../../support/vm_harness.dart';

CopyJob job(
  String id, {
  CopyState state = CopyState.running,
  List<CopiedFile> copied = const [],
  int bytesDone = 0,
}) => CopyJob(
  jobId: id,
  reelId: 1,
  folderName: 'Goa',
  state: state,
  total: 3,
  done: copied.length,
  bytesDone: bytesDone,
  bytesTotal: 300,
  copied: copied,
  failedClipIds: const [],
  undeleted: const [],
);

CopiedFile file(int clipId) => CopiedFile(
  clipId: clipId,
  copyMediaStoreId: 600 + clipId,
  fileName: 'f$clipId.mp4',
  sizeBytes: 100,
  copiedAt: DateTime.utc(2026, 10, 30),
);

void main() {
  late VmHarness h;
  late SpyEditSessionService service;
  late ProviderContainer container;

  setUp(() {
    h = reelHarness();
    service = SpyEditSessionService(h);
    container = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        editSessionServiceProvider.overrideWithValue(service),
      ],
    );
  });

  CopyJob? read() => container.read(copyJobControllerProvider);
  CopyJobController notifier() =>
      container.read(copyJobControllerProvider.notifier);

  test("reads the engine's job on build and applies it", () async {
    final held = job('1-2000', copied: [file(1)]);
    h.copy.job = held;

    expect(read(), isNull);
    await settle();

    expect(read(), held);
    expect(service.applied, [held]);
  });

  test('follows changes and calls applyJob for each event with a new '
      'finished file or a new end state, not for progress alone', () async {
    read();
    await settle();

    h.copy.emit(job('1-2000'));
    h.copy.emit(job('1-2000', bytesDone: 50));
    await settle();
    expect(read()!.bytesDone, 50);
    expect(service.applied, isEmpty);

    h.copy.emit(job('1-2000', copied: [file(1)], bytesDone: 100));
    h.copy.emit(job('1-2000', copied: [file(1)], bytesDone: 150));
    await settle();
    expect(service.applied, hasLength(1));

    h.copy.emit(job('1-2000', copied: [file(1)], state: CopyState.spaceFull));
    h.copy.emit(job('1-2000', copied: [file(1)], state: CopyState.cancelled));
    await settle();
    expect(
      [for (final j in service.applied) j.state],
      [CopyState.running, CopyState.spaceFull, CopyState.cancelled],
    );
    expect(read()!.state, CopyState.cancelled);
  });

  test('ignores the events of an older job', () async {
    read();
    h.copy.emit(job('1-2000'));
    await settle();

    h.copy.emit(job('1-1000', copied: [file(1)], state: CopyState.finished));
    await settle();

    expect(read()!.jobId, '1-2000');
    expect(service.applied, isEmpty);

    h.copy.emit(job('2-3000'));
    await settle();
    expect(read()!.jobId, '2-3000');
  });

  test('holds the interrupted job recoverAtStart built after a restart, '
      'built before or after the recovery', () async {
    final sessions = EditSessionsRepository(h.media.db, h.media.clock);
    final reels = h.container.read(reelsRepositoryProvider);
    final goa = (await reels.create('Goa')).id;
    final [a, b] = await putInReel(h, goa, [reelVideo(1), reelVideo(2)]);
    await sessions.startSession(goa, EditorApp.vn, 'Goa');
    await h.media.phoneState.saveCopyJobPlan(
      CopyJobPlan(
        jobId: '$goa-5000',
        reelId: goa,
        editor: EditorApp.vn,
        folderName: 'Goa',
        startedSession: true,
        items: [
          (clipId: a, fileName: 'a.mp4', sizeBytes: 1001),
          (clipId: b, fileName: 'b.mp4', sizeBytes: 1002),
        ],
      ),
    );
    h.copy.folders['Goa'] = [
      const FolderRow(
        mediaStoreId: 601,
        fileName: 'a.mp4',
        sizeBytes: 1001,
        pending: false,
      ),
    ];

    read();
    final recovered = await service.recoverAtStart();
    await settle();

    expect(recovered!.state, CopyState.interrupted);
    expect(read(), recovered);

    // A controller built after the recovery starts from it too.
    final later = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        editSessionServiceProvider.overrideWithValue(service),
      ],
    );
    expect(later.read(copyJobControllerProvider), recovered);
  });

  test('onResume reads the engine again and applies what it holds (events '
      'are dropped while no Dart side listens)', () async {
    read();
    await settle();
    final held = job('1-2000', copied: [file(1), file(2)]);
    h.copy.job = held;

    await notifier().onResume();

    expect(read(), held);
    expect(service.applied, [held]);
  });

  test('takeUnseenResult is true once per job id, only for a job that is '
      'not running', () async {
    read();
    await settle();
    expect(notifier().takeUnseenResult(), isFalse);

    h.copy.emit(job('1-2000'));
    await settle();
    expect(notifier().takeUnseenResult(), isFalse);

    h.copy.emit(job('1-2000', state: CopyState.interrupted));
    await settle();
    expect(notifier().takeUnseenResult(), isTrue);
    expect(notifier().takeUnseenResult(), isFalse);

    h.copy.emit(job('1-2000', state: CopyState.finished));
    await settle();
    expect(notifier().takeUnseenResult(), isFalse);

    h.copy.emit(job('1-3000', state: CopyState.finished));
    await settle();
    expect(notifier().takeUnseenResult(), isTrue);
  });

  test('a failing applyJob is logged by type and the next event still '
      'applies', () async {
    final logs = captureLogs();
    read();
    service.failApply = StateError('boom');
    h.copy.emit(job('1-2000', copied: [file(1)]));
    await settle();
    service.failApply = null;
    h.copy.emit(job('1-2000', copied: [file(1), file(2)]));
    await settle();

    expect(service.applied, hasLength(2));
    expect(read()!.copied, hasLength(2));
    expect(logs.map((r) => r.message).join('\n'), contains('StateError'));
  });

  test(
    'is kept alive: the job is followed with no screen watching it',
    () async {
      container.listen(copyJobControllerProvider, (_, _) {}).close();
      await settle();
      h.copy.emit(job('1-2000', copied: [file(1)]));
      await settle();

      expect(read()!.jobId, '1-2000');
      expect(service.applied, hasLength(1));
    },
  );
}
