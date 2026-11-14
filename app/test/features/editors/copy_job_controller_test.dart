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
  List<CopiedFile> undeleted = const [],
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
  undeleted: undeleted,
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
    // These tests drive a real service through both fake bridges.
    h.editors.allowAll();
    h.copy.allowAll();
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

  /// A real VN copy job of two clips, started through the service.
  Future<(int, String, int, int)> startedJob() async {
    final goa = (await h.container.read(reelsRepositoryProvider).create('Goa'))
        .id;
    final [a, b] = await putInReel(h, goa, [reelVideo(1), reelVideo(2)]);
    final plan = await service.planCopy(goa, EditorApp.vn, [a, b]);
    final jobId = await service.startCopy(plan);
    return (goa, jobId, a, b);
  }

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

  test('ignores the late events of a job that came before the held one '
      '(the order the controller saw them in)', () async {
    read();
    h.copy.emit(job('1-1000'));
    await settle();
    h.copy.emit(job('1-2000'));
    await settle();
    expect(read()!.jobId, '1-2000');

    h.copy.emit(job('1-1000', copied: [file(1)], state: CopyState.finished));
    await settle();

    expect(read()!.jobId, '1-2000');
    expect(service.applied, isEmpty);

    h.copy.emit(job('2-3000'));
    await settle();
    expect(read()!.jobId, '2-3000');
  });

  test(
    'a phone clock that went back does not make the new job look old: '
    'its events are followed, and the earlier job stays old (T6-M4)',
    () async {
      read();
      h.copy.emit(job('1-2000'));
      await settle();

      // The next job's id has an earlier time (the clock was set back).
      h.copy.emit(job('1-1000', copied: [file(1)]));
      await settle();
      expect(read()!.jobId, '1-1000');
      expect(service.applied, hasLength(1));

      // The job before it, now late, is the old one.
      h.copy.emit(job('1-2000', copied: [file(2)], state: CopyState.finished));
      await settle();
      expect(read()!.jobId, '1-1000');
      expect(service.applied, hasLength(1));
    },
  );

  test('ids that carry no time are ordered the same way (T6-M4)', () async {
    read();
    h.copy.emit(job('first'));
    await settle();
    h.copy.emit(job('second'));
    await settle();
    expect(read()!.jobId, 'second');

    h.copy.emit(job('first', state: CopyState.finished));
    await settle();

    expect(read()!.jobId, 'second');
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

    // The same job id ends in another state (Try again ran in between, the
    // running event may have been dropped): a new result to show.
    h.copy.emit(job('1-2000', state: CopyState.finished));
    await settle();
    expect(notifier().takeUnseenResult(), isTrue);
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

  group('a resumed job keeps its id (fix round 1, I1)', () {
    test(
      'the result of a job that went back to running is unseen again',
      () async {
        read();
        await settle();
        h.copy.emit(job('1-2000', state: CopyState.spaceFull));
        await settle();
        expect(notifier().takeUnseenResult(), isTrue);
        expect(notifier().takeUnseenResult(), isFalse);

        h.copy.emit(job('1-2000'));
        await settle();
        expect(notifier().takeUnseenResult(), isFalse, reason: 'it runs');
        h.copy.emit(
          job('1-2000', copied: [file(1)], state: CopyState.finished),
        );
        await settle();

        expect(notifier().takeUnseenResult(), isTrue);
        expect(notifier().takeUnseenResult(), isFalse);
      },
    );

    test(
      'a second stop of the same kind after a resume is unseen too',
      () async {
        read();
        await settle();
        h.copy.emit(job('1-2000', state: CopyState.spaceFull));
        await settle();
        expect(notifier().takeUnseenResult(), isTrue);

        h.copy.emit(job('1-2000'));
        h.copy.emit(job('1-2000', state: CopyState.spaceFull));
        await settle();

        expect(notifier().takeUnseenResult(), isTrue);
      },
    );

    test('events dropped while the app was away: the engine now holds the '
        'finished job of a stopped id the user already saw', () async {
      read();
      await settle();
      h.copy.emit(job('1-2000', state: CopyState.spaceFull));
      await settle();
      expect(notifier().takeUnseenResult(), isTrue);
      h.copy.job = job('1-2000', copied: [file(1)], state: CopyState.finished);

      await notifier().onResume();

      expect(read()!.state, CopyState.finished);
      expect(notifier().takeUnseenResult(), isTrue);
    });

    test('recovered after a restart, Try again, finished: the screen opens '
        'again for the same id', () async {
      final (goa, jobId, _, _) = await startedJob();
      h.copy.job = null;
      final sessionService = SpyEditSessionService(h);
      final restarted = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          editSessionServiceProvider.overrideWithValue(sessionService),
        ],
      );
      addTearDown(restarted.dispose);
      restarted.read(copyJobControllerProvider);
      await sessionService.recoverAtStart();
      await settle();
      final controller = restarted.read(copyJobControllerProvider.notifier);
      expect(
        restarted.read(copyJobControllerProvider)!.state,
        CopyState.interrupted,
      );
      expect(controller.takeUnseenResult(), isTrue);
      expect(goa, isNonNegative);

      await sessionService.resumeCopy(jobId);
      await settle();
      expect(controller.takeUnseenResult(), isFalse, reason: 'it runs');
      h.copy.emit(h.copy.job!.copyWith(state: CopyState.finished, done: 2));
      await settle();

      expect(restarted.read(copyJobControllerProvider)!.jobId, jobId);
      expect(controller.takeUnseenResult(), isTrue);
    });
  });

  group('a finished job is dropped (fix round 1, I2)', () {
    test('finishJob: the controller holds nothing, and a job that was only '
        'watched (never taken) does not reopen the screen', () async {
      final (_, jobId, a, b) = await startedJob();
      read();
      h.copy.emit(
        h.copy.job!.copyWith(
          state: CopyState.finished,
          copied: [
            CopiedFile(
              clipId: a,
              copyMediaStoreId: 601,
              fileName: 'a.mp4',
              sizeBytes: 1,
              copiedAt: DateTime.utc(2026, 10, 30),
            ),
          ],
          done: 1,
        ),
      );
      await settle();
      expect(read()!.jobId, jobId);

      await service.finishJob(jobId);
      await settle();

      expect(read(), isNull);
      expect(notifier().takeUnseenResult(), isFalse);
      expect(b, isNonNegative);
    });

    test('cancelCopy of the engine job', () async {
      final (_, jobId, _, _) = await startedJob();
      read();
      await settle();
      expect(read()!.state, CopyState.running);

      await service.cancelCopy(jobId);
      await settle();

      expect(read(), isNull);
      expect(notifier().takeUnseenResult(), isFalse);
    });

    test('cancelCopy of a job recovered after a restart (the cancelled job '
        "is the service's own)", () async {
      final (_, jobId, _, _) = await startedJob();
      h.copy.job = null;
      final sessionService = SpyEditSessionService(h);
      final restarted = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          editSessionServiceProvider.overrideWithValue(sessionService),
        ],
      );
      addTearDown(restarted.dispose);
      restarted.read(copyJobControllerProvider);
      await sessionService.recoverAtStart();
      await settle();
      expect(restarted.read(copyJobControllerProvider), isNotNull);

      await sessionService.cancelCopy(jobId);
      await settle();

      expect(restarted.read(copyJobControllerProvider), isNull);
      expect(
        restarted.read(copyJobControllerProvider.notifier).takeUnseenResult(),
        isFalse,
      );
    });

    test('Done editing that settles a job left behind', () async {
      final (goa, _, _, _) = await startedJob();
      read();
      h.copy.emit(h.copy.job!.copyWith(state: CopyState.finished));
      await settle();
      expect(read()!.state, CopyState.finished);

      await service.doneEditing(goa);
      await settle();

      expect(read(), isNull);
      expect(notifier().takeUnseenResult(), isFalse);
    });

    test('a late event of the dropped job changes nothing; a new job is '
        'followed again', () async {
      final (_, jobId, _, _) = await startedJob();
      read();
      h.copy.emit(h.copy.job!.copyWith(state: CopyState.finished));
      await settle();
      await service.finishJob(jobId);
      await settle();
      expect(read(), isNull);

      h.copy.emit(job(jobId, state: CopyState.finished));
      await settle();
      expect(read(), isNull);
      expect(notifier().takeUnseenResult(), isFalse);

      final far = DateTime.now().millisecondsSinceEpoch + 100000;
      h.copy.emit(job('1-$far'));
      await settle();
      expect(read()!.jobId, '1-$far');
    });

    test('a job finished and cleared by someone else leaves the controller '
        'with the next job only', () async {
      final (_, jobId, _, _) = await startedJob();
      read();
      h.copy.emit(h.copy.job!.copyWith(state: CopyState.finished));
      await settle();
      await service.finishJob(jobId);
      await settle();
      h.copy.job = null;

      await notifier().onResume();

      expect(read(), isNull);
    });
  });

  test('a local job the controller saw before the held job is ignored; one '
      'it never saw is the newest (T6-M4)', () async {
    final sessions = EditSessionsRepository(h.media.db, h.media.clock);
    final goa = (await h.container.read(reelsRepositoryProvider).create('Goa'))
        .id;
    final [a] = await putInReel(h, goa, [reelVideo(1)]);
    await sessions.startSession(goa, EditorApp.vn, 'Goa');
    await h.media.phoneState.saveCopyJobPlan(
      CopyJobPlan(
        jobId: '$goa-1000',
        reelId: goa,
        editor: EditorApp.vn,
        folderName: 'Goa',
        startedSession: true,
        items: [(clipId: a, fileName: 'a.mp4', sizeBytes: 1)],
      ),
    );
    read();
    // The engine's job is the one the controller saw first, then a newer one.
    h.copy.emit(job('$goa-1000'));
    await settle();
    h.copy.emit(job('$goa-2000'));
    await settle();
    h.copy.job = null;

    final recovered = await service.recoverAtStart();
    await settle();

    // The recovered job has the id the controller already saw before 2000.
    expect(recovered!.jobId, '$goa-1000');
    expect(read()!.jobId, '$goa-2000');
  });

  /// A saved plan `<reel>-1000` of a reel in a VN session, for
  /// `recoverAtStart` to turn into a local job.
  Future<int> savedPlan() async {
    final sessions = EditSessionsRepository(h.media.db, h.media.clock);
    final goa = (await h.container.read(reelsRepositoryProvider).create('Goa'))
        .id;
    final [a] = await putInReel(h, goa, [reelVideo(1)]);
    await sessions.startSession(goa, EditorApp.vn, 'Goa');
    await h.media.phoneState.saveCopyJobPlan(
      CopyJobPlan(
        jobId: '$goa-1000',
        reelId: goa,
        editor: EditorApp.vn,
        folderName: 'Goa',
        startedSession: true,
        items: [(clipId: a, fileName: 'a.mp4', sizeBytes: 1)],
      ),
    );
    return goa;
  }

  test('a recovered job (a local one) counts as seen: its late engine events '
      'are old once a newer job is held (T6-M4)', () async {
    final goa = await savedPlan();
    read();
    await service.recoverAtStart();
    await settle();
    expect(read()!.jobId, '$goa-1000');

    h.copy.emit(job('$goa-2000'));
    await settle();
    expect(read()!.jobId, '$goa-2000');
    h.copy.emit(job('$goa-1000', state: CopyState.finished));
    await settle();

    expect(read()!.jobId, '$goa-2000');
  });

  test('a job the service already held when the controller was built counts '
      'as seen too (T6-M4)', () async {
    final goa = await savedPlan();
    await service.recoverAtStart();
    expect(service.lastLocalJob!.jobId, '$goa-1000');
    expect(read()!.jobId, '$goa-1000');
    await settle();

    h.copy.emit(job('$goa-2000'));
    await settle();
    h.copy.emit(job('$goa-1000', state: CopyState.finished));
    await settle();

    expect(read()!.jobId, '$goa-2000');
  });

  test('an event whose only news is an undeleted file is applied', () async {
    read();
    await settle();
    h.copy.emit(job('1-2000'));
    await settle();
    expect(service.applied, isEmpty);

    h.copy.emit(job('1-2000', undeleted: [file(1)]));
    await settle();

    expect(service.applied, hasLength(1));
  });

  test('an applyJob that fails with any error type is logged by type and '
      'the next event still applies', () async {
    final logs = captureLogs();
    read();
    service.failApply = const FormatException('boom');
    h.copy.emit(job('1-2000', copied: [file(1)]));
    await settle();
    service.failApply = null;
    h.copy.emit(job('1-2000', copied: [file(1), file(2)]));
    await settle();

    expect(service.applied, hasLength(2));
    expect(logs.map((r) => r.message).join('\n'), contains('FormatException'));
  });

  test("cancelCopy of an id that is neither the engine's nor the saved "
      "plan's drops nothing the controller holds", () async {
    final (_, jobId, _, _) = await startedJob();
    read();
    await settle();
    expect(read()!.jobId, jobId);

    await service.cancelCopy('9-9');
    await settle();

    expect(read()!.jobId, jobId);
    expect(read()!.state, CopyState.running);
  });
}
