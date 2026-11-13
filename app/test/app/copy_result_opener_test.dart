import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/features/editors/views/copy_progress_screen.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';

import '../features/editors/copy_support.dart';
import '../support/test_app.dart';
import '../support/vm_harness.dart';

const int _mb = 1000000;

void main() {
  late VmHarness h;

  setUp(() {
    h = VmHarness(now: DateTime.utc(2026, 10, 30, 12));
    h.copy.allowAll();
    h.editors
      ..allow({
        'freeBytes',
        'copyFolderNames',
        'filesInCopyFolders',
        'existingCopies',
        'deleteCopies',
      })
      ..bytesFree = 64000 * _mb;
  });

  /// A VN job of four clips, started, with the app not yet running.
  Future<VnJob> startedJob(WidgetTester tester) async {
    final (reel, ids) = await reelWithClips(tester, h);
    return await startVnJob(tester, h, reel, ids);
  }

  Future<ProviderContainer> startApp(WidgetTester tester) async {
    final container = ProviderContainer(overrides: h.appOverrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TakeTrayApp(),
      ),
    );
    await settleApp(tester);
    return container;
  }

  Future<void> resumeApp(WidgetTester tester) => leaveAndReturn(tester);

  testApp('a result waiting at the start opens its screen: Phone storage is '
      'full', (tester) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(state: CopyState.spaceFull, copied: [0, 1]);

    await startApp(tester);

    expect(find.byType(CopyProgressScreen), findsOneWidget);
    expect(find.text('Phone storage is full'), findsOneWidget);
    expect(h.copy.screenOnCalls, isEmpty);
  });

  testApp('after a restart (the engine empty, the plan saved): the recovered '
      'job opens as "Copying stopped"', (tester) async {
    final job = await startedJob(tester);
    h.copy.job = null;
    h.copy.folders[job.folder] = [
      FolderRow(
        mediaStoreId: 700,
        fileName: job.request.items[0].fileName,
        sizeBytes: 100 * _mb,
        pending: false,
      ),
      FolderRow(
        mediaStoreId: 701,
        fileName: job.request.items[1].fileName,
        sizeBytes: 100 * _mb,
        pending: true,
      ),
    ];

    await startApp(tester);

    expect(find.text('Copying stopped'), findsOneWidget);
    expect(
      find.text(
        'TakeTray was closed before copying finished. 1 of 4 clips were '
        'copied.',
      ),
      findsOneWidget,
    );
    expect(h.copy.folders[job.folder]!.where((r) => r.pending), isEmpty);
  });

  testApp('a clean result waiting at the start finishes into the ready '
      'screen', (tester) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(state: CopyState.finished, copied: [0, 1, 2, 3]);

    await startApp(tester);

    expect(find.text('Ready for VN'), findsOneWidget);
  });

  testApp('a job still running at the start (the app was re-created): its '
      'screen opens and keeps the screen on', (tester) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(copied: [0]);

    await startApp(tester);

    expect(find.text('Copying clips for VN'), findsOneWidget);
    expect(find.text('1 of 4 clips'), findsOneWidget);
    expect(h.copy.screenOnCalls, [true]);
  });

  testApp('no job, no screen', (tester) async {
    await startApp(tester);

    expect(find.byType(CopyProgressScreen), findsNothing);
  });

  testApp('a result that stops while the app is away opens when it comes '
      'back, once', (tester) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(copied: [0]);
    final container = await startApp(tester);
    expect(find.text('Copying clips for VN'), findsOneWidget);
    // The user leaves this screen some other way.
    container.read(appRouterProvider).go(Routes.reels);
    await settleApp(tester);
    expect(find.byType(CopyProgressScreen), findsNothing);

    h.copy.emit(job.report(state: CopyState.spaceFull, copied: [0, 1]));
    await settleApp(tester);
    expect(find.byType(CopyProgressScreen), findsOneWidget);
    expect(find.text('Phone storage is full'), findsOneWidget);

    // Seen: leaving it and coming back to the front does not open it again.
    container.read(appRouterProvider).go(Routes.reels);
    await settleApp(tester);
    await resumeApp(tester);
    await resumeApp(tester);
    expect(find.byType(CopyProgressScreen), findsNothing);
  });

  testApp('the screen that is already open is not opened twice', (
    tester,
  ) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(state: CopyState.spaceFull, copied: [0]);
    final container = await startApp(tester);

    await resumeApp(tester);
    await resumeApp(tester);

    expect(find.byType(CopyProgressScreen), findsOneWidget);
    // One screen on the stack, not two (the offstage one would show here).
    expect(
      find.byType(CopyProgressScreen, skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete copies and stop'));
    await settleApp(tester);
    expect(find.byType(CopyProgressScreen, skipOffstage: false), findsNothing);
    expect(container.read(appRouterProvider), isNotNull);
  });

  testApp('a copy started from the space screen (its screen is open, not '
      'opened by the app): the app coming back to the front, and the result, '
      'open no second screen', (tester) async {
    // The data first: a write while the app's streams run needs a frame
    // between each step, and this test needs none.
    final (reel, _) = await reelWithClips(tester, h);
    final container = await startApp(tester);
    final jobId = '${reel.id}-1793361600000';
    CopyJob report(CopyState state, int done) => CopyJob(
      jobId: jobId,
      reelId: reel.id,
      folderName: 'Goa',
      state: state,
      total: 4,
      done: done,
      bytesDone: done * 100,
      bytesTotal: 400,
      copied: const [],
      failedClipIds: const [],
      undeleted: const [],
    );
    h.copy.emit(report(CopyState.running, 1));
    await settleApp(tester);
    expect(
      find.byType(CopyProgressScreen),
      findsNothing,
      reason: 'events alone',
    );
    // As the space screen does after Copy.
    unawaited(
      container.read(appRouterProvider).push(Routes.copyProgressOf(jobId)),
    );
    await settleApp(tester);
    expect(find.text('Copying clips for VN'), findsOneWidget);

    await resumeApp(tester);
    await resumeApp(tester);
    expect(
      find.byType(CopyProgressScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'a running job whose screen is open is left alone',
    );

    h.copy.emit(report(CopyState.spaceFull, 2));
    await settleApp(tester);
    expect(find.text('Phone storage is full'), findsOneWidget);
    expect(
      find.byType(CopyProgressScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'a result whose screen is open is shown on that screen',
    );
  });

  testApp('a job that runs when the app returns to the front (its events '
      'were dropped while away): the engine is read and its screen opens, '
      'with the screen kept on', (tester) async {
    final (reel, _) = await reelWithClips(tester, h);
    await startApp(tester);
    expect(find.byType(CopyProgressScreen), findsNothing);
    final jobId = '${reel.id}-1793361600000';
    // The engine has the job; no event reached Dart.
    h.copy.job = CopyJob(
      jobId: jobId,
      reelId: reel.id,
      folderName: 'Goa',
      state: CopyState.running,
      total: 4,
      done: 1,
      bytesDone: 100,
      bytesTotal: 400,
      copied: const [],
      failedClipIds: const [],
      undeleted: const [],
    );

    await resumeApp(tester);

    expect(find.byType(CopyProgressScreen), findsOneWidget);
    expect(find.text('1 of 4 clips'), findsOneWidget);
    expect(h.copy.screenOnCalls.first, isTrue);

    // Back to the front again: still one screen.
    await resumeApp(tester);
    expect(
      find.byType(CopyProgressScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  testApp('after Try again the new result is shown again (same job id)', (
    tester,
  ) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(state: CopyState.spaceFull, copied: [0]);
    final container = await startApp(tester);
    await tester.tap(find.text('Try again'));
    await settleApp(tester);
    expect(find.text('Copying clips for VN'), findsOneWidget);
    // The user leaves; the job ends in another state while away.
    container.read(appRouterProvider).go(Routes.reels);
    await settleApp(tester);

    h.copy.emit(job.report(state: CopyState.spaceFull, copied: [0, 1]));
    await settleApp(tester);

    expect(find.text('Phone storage is full'), findsOneWidget);
  });

  testApp('a job of a reel that is gone opens nothing', (tester) async {
    final job = await startedJob(tester);
    h.copy.job = job.report(state: CopyState.spaceFull, copied: [0]);
    await real(
      tester,
      () => h.container
          .read(editSessionServiceProvider)
          .beforeReelDelete(job.reel.id),
    );
    h.copy.job = null;

    await startApp(tester);

    expect(find.byType(CopyProgressScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testApp('a recovery that fails opens nothing and breaks nothing', (
    tester,
  ) async {
    await startedJob(tester);
    h.copy.job = null;
    h.copy.failNext('deletePendingIn');

    await startApp(tester);

    expect(find.byType(CopyProgressScreen), findsNothing);
    expect(tester.takeException(), isNull);
    // The plan is kept for the next start.
    final again = await startApp(tester);
    expect(again, isNotNull);
  });
}
