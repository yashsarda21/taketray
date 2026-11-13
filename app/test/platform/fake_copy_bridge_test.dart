import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/copy_bridge.dart';

import '../support/fake_copy_bridge.dart';

/// The fake keeps the native engine's rules, so tests built on it (Task 6
/// on) see what the phone would do.
void main() {
  const item = CopyItem(
    clipId: 1,
    source: ClipRef(
      volumeName: 'external_primary',
      mediaStoreId: 5,
      mimeType: 'video/mp4',
    ),
    fileName: 'a.mp4',
    sizeBytes: 100,
  );
  const request = CopyRequest(
    jobId: 'job-1',
    reelId: 7,
    folderName: 'Goa',
    items: [item, item],
  );
  final file = CopiedFile(
    clipId: 1,
    copyMediaStoreId: 900,
    fileName: 'a.mp4',
    sizeBytes: 100,
    copiedAt: DateTime.utc(2026, 11, 12),
  );

  test(
    'one job at a time; resume, clear and cancel follow the engine',
    () async {
      final fake = FakeCopyBridge();
      expect(await fake.current(), isNull);
      await fake.start(request);
      final started = (await fake.current())!;
      expect(started.state, CopyState.running);
      expect(started.total, 2);
      expect(started.bytesTotal, 200);
      await expectLater(fake.start(request), throwsA(isA<CopyBusy>()));
      expect(fake.starts, [request]);

      // Running: clear and resume leave it.
      await fake.clear('job-1');
      await fake.resume('job-1');
      expect((await fake.current())!.state, CopyState.running);
      await expectLater(fake.deletePendingIn('Goa'), throwsA(isA<CopyBusy>()));

      final seen = <CopyJob>[];
      fake.changes.listen(seen.add);
      fake.emit(started.copyWith(state: CopyState.spaceFull, copied: [file]));
      await pumpEventQueue();
      expect(seen.single.state, CopyState.spaceFull);
      await fake.resume('other');
      expect(fake.job!.state, CopyState.spaceFull);
      await fake.resume('job-1');
      expect(fake.job!.state, CopyState.running);

      expect(await fake.cancel('other'), isNull);
      fake.cancelUndeleted = {1};
      final cancelled = (await fake.cancel('job-1'))!;
      expect(cancelled.state, CopyState.cancelled);
      expect(cancelled.copied, isEmpty);
      expect(cancelled.undeleted, [file]);
      expect(await fake.cancel('job-1'), cancelled);

      await fake.clear('other');
      expect(fake.job, isNotNull);
      await fake.clear('job-1');
      expect(fake.job, isNull);
    },
  );

  test('start, resume and cancel send the events the phone sends', () async {
    final fake = FakeCopyBridge();
    final seen = <CopyJob>[];
    fake.changes.listen(seen.add);

    // Kotlin sends the first snapshot at once.
    await fake.start(request);
    await pumpEventQueue();
    expect(seen.map((j) => j.state), [CopyState.running]);
    expect(seen.single.jobId, 'job-1');

    // Nothing to resume, nothing sent: running, another id, no job state.
    await fake.resume('job-1');
    await fake.resume('other');
    await pumpEventQueue();
    expect(seen, hasLength(1));

    fake.emit(fake.job!.copyWith(state: CopyState.interrupted, copied: [file]));
    await pumpEventQueue();
    expect(seen.map((j) => j.state), [
      CopyState.running,
      CopyState.interrupted,
    ]);

    // A resume sends the running snapshot.
    await fake.resume('other');
    await pumpEventQueue();
    expect(seen, hasLength(2));
    await fake.resume('job-1');
    await pumpEventQueue();
    expect(seen, hasLength(3));
    expect(seen.last.state, CopyState.running);
    expect(seen.last.copied, [file]);
    expect(fake.job, seen.last);

    // An unknown id sends nothing.
    expect(await fake.cancel('other'), isNull);
    await pumpEventQueue();
    expect(seen, hasLength(3));

    // A cancel sends the cancelled snapshot, the one it answers with.
    fake.cancelUndeleted = {1};
    final cancelled = (await fake.cancel('job-1'))!;
    await pumpEventQueue();
    expect(seen, hasLength(4));
    expect(seen.last, cancelled);
    expect(seen.last.state, CopyState.cancelled);
    expect(seen.last.undeleted, [file]);
    expect(fake.job, cancelled);

    // Cancelling a cancelled job answers it again and sends nothing; nor does
    // resume, nor clear.
    expect(await fake.cancel('job-1'), cancelled);
    await fake.resume('job-1');
    await fake.clear('job-1');
    await pumpEventQueue();
    expect(seen, hasLength(4));
    expect(fake.job, isNull);
  });

  test('folders, the screen flag, failures and gates', () async {
    final fake = FakeCopyBridge()
      ..folders['Goa'] = const [
        FolderRow(
          mediaStoreId: 1,
          fileName: 'a.mp4',
          sizeBytes: 1,
          pending: true,
        ),
        FolderRow(
          mediaStoreId: 2,
          fileName: 'b.mp4',
          sizeBytes: 2,
          pending: false,
        ),
      ];
    expect(await fake.ownRowsIn('Goa'), hasLength(2));
    expect(await fake.ownRowsIn('Paris'), isEmpty);
    expect(await fake.deletePendingIn('Goa'), 1);
    expect((await fake.ownRowsIn('Goa')).single.mediaStoreId, 2);

    expect(fake.screenOn, isNull);
    await fake.keepScreenOn(true);
    expect(fake.screenOn, isTrue);

    fake.failNext('start');
    await expectLater(fake.start(request), throwsA(isA<PlatformException>()));
    expect(fake.job, isNull);

    final gate = fake.gate('start');
    var done = false;
    final started = fake.start(request).then((_) => done = true);
    await pumpEventQueue();
    expect(done, isFalse);
    gate.complete();
    await started;
    expect(fake.job, isNotNull);
    expect(fake.calls, [
      'ownRowsIn',
      'ownRowsIn',
      'deletePendingIn',
      'ownRowsIn',
      'keepScreenOn',
      'start',
      'start',
    ]);
  });
}
