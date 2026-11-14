import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import 'copy_support.dart';

const int _mb = 1000000;

void main() {
  late VmHarness h;
  late ProviderContainer app;

  setUp(() {
    h = reelHarness();
    h.copy.allowAll();
    h.editors.allow({
      'freeBytes',
      'copyFolderNames',
      'filesInCopyFolders',
      'existingCopies',
      'deleteCopies',
      'openApp',
    });
    h.editors.bytesFree = 64000 * _mb;
  });

  /// A first VN job of [count] clips of 100 MB each, started and running.
  Future<VnJob> firstJob(
    WidgetTester tester, {
    int count = 4,
    String name = 'Goa',
    String? zoneId,
  }) async {
    final (reel, ids) = await reelWithClips(
      tester,
      h,
      name: name,
      count: count,
      zoneId: zoneId,
    );
    return await startVnJob(tester, h, reel, ids);
  }

  /// An add job: the reel's first clip has a recorded copy already, so the
  /// session exists and the job copies the other [count] - 1 clips.
  Future<VnJob> addJob(WidgetTester tester, {int count = 4}) async {
    final (reel, ids) = await reelWithClips(tester, h, count: count);
    await real(tester, () async {
      final sessions = h.container.read(editSessionsRepositoryProvider);
      await sessions.startSession(reel.id, EditorApp.vn, 'Goa');
      await sessions.recordCopies([
        EditCopy(
          reelId: reel.id,
          clipId: ids.first,
          copyMediaStoreId: 500,
          fileName: 'old.mp4',
          sizeBytes: 100 * _mb,
          copiedAt: DateTime.utc(2026, 10, 29),
        ),
      ]);
    });
    h.editors.existing = {500};
    return await startVnJob(tester, h, reel, ids);
  }

  /// An add job for a CapCut or Edits session (the share started it): the
  /// first clip was sent and has a recorded copy already, so the job copies
  /// the other three.
  Future<VnJob> editorAddJob(WidgetTester tester, EditorApp editor) async {
    final (reel, ids) = await reelWithClips(tester, h);
    await real(tester, () async {
      final sessions = h.container.read(editSessionsRepositoryProvider);
      await sessions.startSession(reel.id, editor, 'Goa');
      await sessions.recordSent(reel.id, [ids.first]);
      await sessions.recordCopies([
        EditCopy(
          reelId: reel.id,
          clipId: ids.first,
          copyMediaStoreId: 500,
          fileName: 'old.mp4',
          sizeBytes: 100 * _mb,
          copiedAt: DateTime.utc(2026, 10, 29),
        ),
      ]);
    });
    h.editors.existing = {500};
    final service = h.container.read(editSessionServiceProvider);
    return await real(tester, () async {
      final plan = await service.planCopy(reel.id, editor, ids);
      final jobId = await service.startCopy(plan);
      return VnJob(reel, plan.clipIds, jobId, h.copy.starts.last);
    });
  }

  /// Opens the progress of [job] over a "home" page.
  Future<void> open(
    WidgetTester tester,
    String jobId, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    app = await pumpScreen(
      tester,
      const Scaffold(body: Text('home')),
      overrides: h.appOverrides,
      copyScreens: true,
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    // As in the app, the controller already follows the engine.
    followJob(app);
    await settleApp(tester);
    unawaited(routerOf(tester).push(Routes.copyProgressOf(jobId)));
    await settleApp(tester);
  }

  Future<void> emit(WidgetTester tester, CopyJob job) async {
    h.copy.emit(job);
    await settleApp(tester);
  }

  Finder buttonOf(String label) => find.widgetWithText(TtButton, label);

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(buttonOf(label));
    await settleApp(tester);
  }

  Future<void> stopViaDialog(WidgetTester tester) async {
    await tapButton(tester, 'Cancel');
    expect(find.text('Stop copying?'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await settleApp(tester);
  }

  EditSessionService service() => app.read(editSessionServiceProvider);

  EditSessionsRepository sessions() =>
      h.container.read(editSessionsRepositoryProvider);

  group('while it copies', () {
    testApp('the title, the count, the sizes, the bar, the keep-open line '
        'and Cancel', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0, 1]));

      expect(find.text('Copying clips for VN'), findsOneWidget);
      expect(find.text('2 of 4 clips'), findsOneWidget);
      expect(
        find.text('200 MB of 400 MB · into Movies/TakeTray/Goa'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Keep TakeTray open until copying finishes. The screen stays on '
          'until then.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('leave the app'), findsNothing);
      final bar = tester.widget<TtProgressBar>(find.byType(TtProgressBar));
      expect(bar.value, 0.5);
      expect(bar.semanticLabel, '2 of 4 clips');
      expect(bar.percentText!(50), '50%');
      expect(buttonOf('Cancel'), findsOneWidget);
    });

    testApp('it follows the engine: more done, more bytes', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      expect(find.text('0 of 4 clips'), findsOneWidget);
      expect(tester.widget<TtProgressBar>(find.byType(TtProgressBar)).value, 0);

      await emit(tester, job.report(copied: [0], bytesDone: 150 * _mb));
      expect(find.text('1 of 4 clips'), findsOneWidget);
      expect(
        find.text('150 MB of 400 MB · into Movies/TakeTray/Goa'),
        findsOneWidget,
      );
      expect(
        tester.widget<TtProgressBar>(find.byType(TtProgressBar)).value,
        0.25,
      );
    });

    testApp("the folder is the session's, not the reel's name", (tester) async {
      final job = await addJob(tester);
      await real(
        tester,
        () => h.container
            .read(reelsRepositoryProvider)
            .rename(job.reel.id, 'Goa 2'),
      );
      await open(tester, job.jobId);

      expect(find.textContaining('into Movies/TakeTray/Goa'), findsOneWidget);
      expect(find.textContaining('Goa 2'), findsNothing);
    });

    testApp('accessible and no overflow at text 1x, 2x and in dark', (
      tester,
    ) async {
      final job = await firstJob(tester);
      for (final (scale, brightness) in [
        (1.0, Brightness.light),
        (2.0, Brightness.light),
        (1.0, Brightness.dark),
      ]) {
        await open(tester, job.jobId, textScale: scale, brightness: brightness);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });

    testApp('the screen is on (and only once) while it copies', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0]));
      await emit(tester, job.report(copied: [0, 1]));

      expect(h.copy.screenOnCalls, [true]);
    });

    testApp('the app coming back to the front asks for the screen on again '
        '(the activity may be a new one)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await leaveAndReturn(tester);

      expect(h.copy.screenOnCalls, [true, true]);
    });

    testApp('a screen-on call that fails does not break the screen', (
      tester,
    ) async {
      final job = await firstJob(tester);
      h.copy.failNext('keepScreenOn');
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0]));

      expect(find.text('1 of 4 clips'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("the job's editor", () {
    testApp('a CapCut job: the title names CapCut; its first clean finish '
        'opens the ready screen for CapCut, not the VN add snack', (
      tester,
    ) async {
      final (reel, ids) = await reelWithClips(tester, h);
      final job = await startVnJob(
        tester,
        h,
        reel,
        ids,
        editor: EditorApp.capcut,
      );
      await open(tester, job.jobId);

      expect(find.text('Copying clips for CapCut'), findsOneWidget);
      expect(find.text('Copying clips for VN'), findsNothing);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2, 3]),
      );

      // The session already existed (the share started it), but the clips
      // are added from the album, so the steps come next (D-129).
      expect(find.text('Ready to add in CapCut'), findsOneWidget);
      expect(find.text('4 clips added to the CapCut folder'), findsNothing);
      expect(find.text(reelRouteMarker(reel.id)), findsNothing);
    });

    testApp('an Edits job: "Instagram Edits" in the title and the ready '
        'screen', (tester) async {
      final job = await editorAddJob(tester, EditorApp.edits);
      await open(tester, job.jobId);

      expect(find.text('Copying clips for Instagram Edits'), findsOneWidget);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2]),
      );

      expect(find.text('Ready to add in Instagram Edits'), findsOneWidget);
    });

    testApp('a CapCut add job that finished with a clip that failed: '
        'Continue goes to the ready screen too', (tester) async {
      final job = await editorAddJob(tester, EditorApp.capcut);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1], failed: [2]),
      );
      await tapButton(tester, 'Continue with 2 clips');

      expect(find.text('Ready to add in CapCut'), findsOneWidget);
      final state = await real(tester, () => sessions().editState(job.reel.id));
      // The earlier copy and the two new ones.
      expect(state!.copies, hasLength(3));
    });

    testApp('Stop on a CapCut add job: the new copies are deleted, the '
        'session, the sent row and the earlier copy stay', (tester) async {
      final job = await editorAddJob(tester, EditorApp.capcut);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0]));

      await stopViaDialog(tester);

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(
        find.text('Copying stopped. The new copies were deleted.'),
        findsOneWidget,
      );
      final state = await real(tester, () => sessions().editState(job.reel.id));
      expect(state!.session.editor, EditorApp.capcut);
      expect([for (final c in state.copies) c.copyMediaStoreId], [500]);
      expect(state.sentIds, hasLength(1));
    });

    testApp('every clip of a CapCut add job failed: Back keeps the session '
        'it did not start', (tester) async {
      final job = await editorAddJob(tester, EditorApp.capcut);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, failed: [0, 1, 2]),
      );

      await tapButton(tester, 'Back');

      final state = await real(tester, () => sessions().editState(job.reel.id));
      expect(state, isNotNull);
      expect(state!.sentIds, hasLength(1));
      expect([for (final c in state.copies) c.copyMediaStoreId], [500]);
    });

    testApp('a VN job still says VN', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      expect(find.text('Copying clips for VN'), findsOneWidget);
    });
  });

  group('a late event while Stop runs', () {
    testApp('a running event during the cancel does not turn the screen on '
        'again', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      expect(h.copy.screenOnCalls, [true]);
      final held = h.copy.gate('cancel');

      await tapButton(tester, 'Cancel');
      await tester.tap(find.text('Stop'));
      await settleApp(tester);
      expect(h.copy.screenOnCalls, [true, false]);

      // The engine reports more progress while the cancel is in flight.
      h.copy.emit(job.report(copied: [0, 1]));
      await settleApp(tester);
      expect(h.copy.screenOnCalls, [true, false]);

      held.complete();
      await settleApp(tester);
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(h.copy.screenOnCalls, [true, false]);
    });
  });

  group('the screen is let go on every way out', () {
    testApp('finished cleanly', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2, 3]),
      );

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('finished with a clip that failed', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 3], failed: [2]),
      );

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('every clip failed', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, failed: [0, 1, 2, 3]),
      );

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp("the phone's storage is full", (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('Android stopped TakeTray mid-copy (interrupted)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(tester, job.report(state: CopyState.interrupted, copied: [0]));

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('Stop', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await stopViaDialog(tester);

      expect(h.copy.screenOnCalls, [true, false]);
      expect(h.copy.screenOn, isFalse);
    });

    testApp('Try again turns it on again, and the next stop turns it off', (
      tester,
    ) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));

      await tapButton(tester, 'Try again');
      expect(h.copy.screenOnCalls, [true, false, true]);

      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));
      expect(h.copy.screenOnCalls, [true, false, true, false]);
    });

    testApp('the screen is replaced by another page', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      routerOf(tester).go(Routes.toTag);
      await settleApp(tester);

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('the screen is popped', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      routerOf(tester).pop();
      await settleApp(tester);

      expect(find.text('home'), findsOneWidget);
      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('the whole app goes away (dispose)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('the job was cleared elsewhere (a reel delete cancels it)', (
      tester,
    ) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await real(tester, () => service().beforeReelDelete(job.reel.id));
      await settleApp(tester);

      expect(h.copy.screenOnCalls, [true, false]);
    });

    testApp('a result that is already there never turns it on', (tester) async {
      final job = await firstJob(tester);
      h.copy.emit(job.report(state: CopyState.spaceFull, copied: [0]));
      await open(tester, job.jobId);

      expect(h.copy.screenOnCalls, isEmpty);
    });

    testApp('a Stop that fails while the copy goes on keeps the screen on '
        'again', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      h.copy.failNext('cancel');

      await stopViaDialog(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(h.copy.screenOnCalls, [true, false, true]);
    });
  });

  group('Cancel, back and the Stop dialog', () {
    testApp('Cancel opens it: the title, the copies made so far, the two '
        'buttons', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0, 1]));

      await tapButton(tester, 'Cancel');

      expect(find.text('Stop copying?'), findsOneWidget);
      expect(
        find.text(
          'The 2 copies made so far will be deleted. Your original clips '
          "aren't affected.",
        ),
        findsOneWidget,
      );
      expect(find.text('Keep copying'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    testApp('one copy, and none yet, are worded as they are', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await tapButton(tester, 'Cancel');
      expect(
        find.text(
          "No copies have been made yet. Your original clips aren't affected.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep copying'));
      await settleApp(tester);

      await emit(tester, job.report(copied: [0]));
      await tapButton(tester, 'Cancel');
      expect(
        find.text(
          'The 1 copy made so far will be deleted. Your original clips '
          "aren't affected.",
        ),
        findsOneWidget,
      );
    });

    testApp('the system back opens the same dialog and the screen stays', (
      tester,
    ) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await tester.binding.handlePopRoute();
      await settleApp(tester);

      expect(find.text('Stop copying?'), findsOneWidget);
      expect(find.text('Copying clips for VN'), findsOneWidget);
      expect(h.copy.calls, isNot(contains('cancel')));
    });

    testApp('Keep copying changes nothing: no cancel, still on, the screen '
        'stays on', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0]));
      final before = List.of(h.copy.calls);

      await tapButton(tester, 'Cancel');
      await tester.tap(find.text('Keep copying'));
      await settleApp(tester);

      expect(find.text('Stop copying?'), findsNothing);
      expect(find.text('1 of 4 clips'), findsOneWidget);
      expect(h.copy.calls, before);
      expect(h.copy.screenOnCalls, [true]);
      expect(h.copy.job!.state, CopyState.running);
    });

    testApp('a tap outside the dialog keeps copying too', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await tapButton(tester, 'Cancel');
      await tester.tapAt(const Offset(4, 4));
      await settleApp(tester);

      expect(find.text('Stop copying?'), findsNothing);
      expect(h.copy.calls, isNot(contains('cancel')));
    });

    testApp('the job finishes while the dialog is open: nothing moves until '
        'the user answers', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await tapButton(tester, 'Cancel');

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2, 3]),
      );

      expect(find.text('Stop copying?'), findsOneWidget);
      expect(h.copy.calls, isNot(contains('clear')));

      await tester.tap(find.text('Keep copying'));
      await settleApp(tester);

      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp("Stop (first job): cancels, the reel's page, the snack, and the "
        'session the job started is gone', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0, 1]));

      await stopViaDialog(tester);

      expect(h.copy.calls.where((c) => c == 'cancel'), hasLength(1));
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(
        find.text('Copying stopped. No copies were kept.'),
        findsOneWidget,
      );
      final session = await real(
        tester,
        () => sessions().sessionOf(job.reel.id),
      );
      expect(session, isNull);
    });

    testApp('Stop (add job): the new copies are deleted, the session and '
        'the old copy stay, and the snack says so', (tester) async {
      final job = await addJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0]));

      await stopViaDialog(tester);

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(
        find.text('Copying stopped. The new copies were deleted.'),
        findsOneWidget,
      );
      final state = await real(tester, () => sessions().editState(job.reel.id));
      expect(state, isNotNull);
      expect([for (final c in state!.copies) c.copyMediaStoreId], [500]);
    });

    testApp('Stop twice in a row (a double tap) cancels once', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      final held = h.copy.gate('cancel');

      await tapButton(tester, 'Cancel');
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump();
      // The dialog is closed and the screen is busy: nothing more to tap.
      expect(find.text('Stop copying?'), findsNothing);
      held.complete();
      await settleApp(tester);

      expect(h.copy.calls.where((c) => c == 'cancel'), hasLength(1));
    });

    testApp('a Stop that fails: the screen stays, a calm snack, and Stop '
        'can be tried again', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      h.copy.failNext('cancel');

      await stopViaDialog(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Copying clips for VN'), findsOneWidget);
      expect(find.text(reelRouteMarker(job.reel.id)), findsNothing);

      await stopViaDialog(tester);
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
    });

    testApp('Stop that cancelled but could not clear: the screen stays with '
        'Try again, which finishes the stop', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      h.copy.failNext('clear');

      await stopViaDialog(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(buttonOf('Try again'), findsOneWidget);
      expect(find.text(reelRouteMarker(job.reel.id)), findsNothing);

      await tapButton(tester, 'Try again');

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(
        find.text('Copying stopped. No copies were kept.'),
        findsOneWidget,
      );
    });
  });

  group('when the storage is full or TakeTray was stopped', () {
    testApp('Phone storage is full: the words, Try again and Delete copies '
        'and stop', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.spaceFull, copied: [0, 1]),
      );

      expect(find.text('Phone storage is full'), findsOneWidget);
      expect(
        find.text(
          '2 of 4 clips were copied before space ran out. Free up some '
          'space, then try again.',
        ),
        findsOneWidget,
      );
      expect(buttonOf('Try again'), findsOneWidget);
      expect(buttonOf('Delete copies and stop'), findsOneWidget);
      expect(find.text('Copying clips for VN'), findsNothing);
    });

    testApp('Try again resumes the job and goes back to the progress', (
      tester,
    ) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.spaceFull, copied: [0, 1]),
      );

      await tapButton(tester, 'Try again');

      expect(h.copy.calls.where((c) => c == 'resume'), hasLength(1));
      expect(find.text('Copying clips for VN'), findsOneWidget);
      expect(find.text('2 of 4 clips'), findsOneWidget);
    });

    testApp('Try again that fails: the result stays, a calm snack, and it can '
        'be tried again', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));
      h.copy.failNext('resume');

      await tapButton(tester, 'Try again');

      expect(find.text('Phone storage is full'), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(h.copy.screenOnCalls, [true, false]);

      await tapButton(tester, 'Try again');
      expect(find.text('Copying clips for VN'), findsOneWidget);
    });

    testApp('Try again with another job holding the engine: the same calm '
        'snack, the result stays', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));
      // The engine now holds another job (its id is later).
      h.copy.job = job.report().copyWith(
        jobId: '${job.reel.id}-99999999999999',
      );

      await tapButton(tester, 'Try again');

      expect(find.text('Phone storage is full'), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    });

    testApp('Delete copies and stop cancels, like Stop', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));

      await tapButton(tester, 'Delete copies and stop');

      expect(h.copy.calls.where((c) => c == 'cancel'), hasLength(1));
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(
        find.text('Copying stopped. No copies were kept.'),
        findsOneWidget,
      );
    });

    testApp('the system back on this screen asks "Stop copying?" too', (
      tester,
    ) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(state: CopyState.spaceFull, copied: [0]));

      await tester.binding.handlePopRoute();
      await settleApp(tester);

      expect(find.text('Stop copying?'), findsOneWidget);
      expect(find.text('Phone storage is full'), findsOneWidget);
    });

    testApp('Copying stopped (interrupted): the words and the same two '
        'buttons', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.interrupted, copied: [0, 1, 2]),
      );

      expect(find.text('Copying stopped'), findsOneWidget);
      expect(
        find.text(
          'TakeTray was closed before copying finished. 3 of 4 clips were '
          'copied.',
        ),
        findsOneWidget,
      );
      expect(buttonOf('Try again'), findsOneWidget);
      expect(buttonOf('Delete copies and stop'), findsOneWidget);
      await tapButton(tester, 'Try again');
      expect(h.copy.calls, contains('resume'));
      expect(find.text('Copying clips for VN'), findsOneWidget);
    });

    testApp('after a restart: the recovered job opens as "Copying stopped" '
        'with what was recorded, and Try again copies only the rest', (
      tester,
    ) async {
      final job = await firstJob(tester);
      // The process died: the engine holds nothing, two files are finished.
      h.copy.job = null;
      h.copy.folders[job.folder] = [
        for (final i in [0, 1])
          FolderRow(
            mediaStoreId: 700 + i,
            fileName: job.request.items[i].fileName,
            sizeBytes: 100 * _mb,
            pending: false,
          ),
      ];
      app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      followJob(app);
      await settleApp(tester);
      await real(tester, () => service().recoverAtStart());
      await settleApp(tester);

      unawaited(routerOf(tester).push(Routes.copyProgressOf(job.jobId)));
      await settleApp(tester);

      expect(find.text('Copying stopped'), findsOneWidget);
      expect(
        find.text(
          'TakeTray was closed before copying finished. 2 of 4 clips were '
          'copied.',
        ),
        findsOneWidget,
      );

      await tapButton(tester, 'Try again');

      // A new engine job, the same id, only the two clips left.
      expect(h.copy.starts, hasLength(2));
      expect(h.copy.starts.last.jobId, job.jobId);
      expect(h.copy.starts.last.items, hasLength(2));
      expect(find.text('Copying clips for VN'), findsOneWidget);
      expect(find.text('0 of 2 clips'), findsOneWidget);
    });

    testApp('after a restart: Delete copies and stop deletes what was '
        'recorded and ends the session', (tester) async {
      final job = await firstJob(tester);
      h.copy.job = null;
      h.copy.folders[job.folder] = [
        FolderRow(
          mediaStoreId: 700,
          fileName: job.request.items[0].fileName,
          sizeBytes: 100 * _mb,
          pending: false,
        ),
      ];
      h.editors.existing = {700};
      app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      followJob(app);
      await settleApp(tester);
      await real(tester, () => service().recoverAtStart());
      await settleApp(tester);
      unawaited(routerOf(tester).push(Routes.copyProgressOf(job.jobId)));
      await settleApp(tester);

      await tapButton(tester, 'Delete copies and stop');

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(h.editors.calls, contains('deleteCopies'));
      final session = await real(
        tester,
        () => sessions().sessionOf(job.reel.id),
      );
      expect(session, isNull);
    });
  });

  group('when some clips could not be copied', () {
    testApp('one clip: its time where it was shot, the other clips, Continue '
        'with N and Cancel', (tester) async {
      // Shot at 12:00 UTC, which is 5:30 PM in India.
      final job = await firstJob(tester, zoneId: 'Asia/Kolkata');
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );

      expect(find.text("1 clip couldn't be copied"), findsOneWidget);
      expect(
        findPlain(
          'The clip from 5:30 PM may have been deleted or moved. The other 3 '
          'clips were copied.',
        ),
        findsOneWidget,
      );
      expect(buttonOf('Continue with 3 clips'), findsOneWidget);
      expect(buttonOf('Cancel'), findsOneWidget);
    });

    testApp('several clips: the count, and "They may have been deleted or '
        'moved."', (tester) async {
      final job = await firstJob(tester, count: 5);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(
          state: CopyState.finished,
          copied: [0, 1, 2],
          failed: [3, 4],
        ),
      );

      expect(find.text("2 clips couldn't be copied"), findsOneWidget);
      expect(
        find.text(
          'They may have been deleted or moved. The other 3 clips were '
          'copied.',
        ),
        findsOneWidget,
      );
      expect(buttonOf('Continue with 3 clips'), findsOneWidget);
    });

    testApp('one clip failed and one copied: "Continue with 1 clip"', (
      tester,
    ) async {
      final job = await firstJob(tester, count: 2);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0], failed: [1]),
      );

      expect(buttonOf('Continue with 1 clip'), findsOneWidget);
      expect(find.textContaining('The other clip was copied.'), findsOneWidget);
    });

    testApp('a failed clip with no clip row (it is not known any more): the '
        'same screen with no time', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job
            .report(state: CopyState.finished, copied: [0, 1, 2])
            .copyWith(done: 4, failedClipIds: [987654]),
      );

      expect(find.text("1 clip couldn't be copied"), findsOneWidget);
      expect(
        find.text(
          'It may have been deleted or moved. The other 3 clips were copied.',
        ),
        findsOneWidget,
      );
    });

    testApp('Continue finishes the job and opens the ready screen (first '
        'job)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );

      await tapButton(tester, 'Continue with 3 clips');

      expect(find.text('Ready for VN'), findsOneWidget);
      expect(h.copy.job, isNull, reason: 'the engine forgot the result');
      final state = await real(tester, () => sessions().editState(job.reel.id));
      expect(state!.copies, hasLength(3));
    });

    testApp('Continue (add job): the reel\'s page and "3 clips added to the '
        'VN folder"', (tester) async {
      final job = await addJob(tester, count: 5);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );

      await tapButton(tester, 'Continue with 3 clips');

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(find.text('3 clips added to the VN folder'), findsOneWidget);
      expect(find.text('Ready for VN'), findsNothing);
    });

    testApp("Cancel stops the job: the copies are deleted, the reel's page "
        'and the snack', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );

      await tapButton(tester, 'Cancel');

      expect(h.copy.calls, contains('cancel'));
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(
        find.text('Copying stopped. No copies were kept.'),
        findsOneWidget,
      );
    });

    testApp('Continue that fails: the screen stays, a calm snack, and Continue '
        'can be tapped again', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );
      h.copy.failNext('clear');

      await tapButton(tester, 'Continue with 3 clips');

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Ready for VN'), findsNothing);
      expect(find.text("1 clip couldn't be copied"), findsOneWidget);

      await tapButton(tester, 'Continue with 3 clips');
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp('the system back asks "Stop copying?", it does not drop the '
        'copies by itself', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );

      await tester.binding.handlePopRoute();
      await settleApp(tester);

      expect(find.text('Stop copying?'), findsOneWidget);
      expect(
        find.text(
          'The 3 copies made so far will be deleted. Your original clips '
          "aren't affected.",
        ),
        findsOneWidget,
      );
      expect(h.copy.calls, isNot(contains('cancel')));
    });

    testApp('a double tap on Continue finishes once', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2], failed: [3]),
      );
      final held = h.copy.gate('clear');

      await tester.tap(buttonOf('Continue with 3 clips'));
      await tester.pump();
      await tester.tap(buttonOf('Continue with 3 clips'), warnIfMissed: false);
      await tester.pump();
      held.complete();
      await settleApp(tester);

      expect(h.copy.calls.where((c) => c == 'clear'), hasLength(1));
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp('every clip failed: the words, and Back cancels (the empty '
        'session ends)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, failed: [0, 1, 2, 3]),
      );

      expect(find.text("The clips couldn't be copied"), findsOneWidget);
      expect(find.text('They may have been deleted or moved.'), findsOneWidget);
      expect(buttonOf('Continue with 0 clips'), findsNothing);
      expect(buttonOf('Cancel'), findsNothing);

      await tapButton(tester, 'Back');

      expect(h.copy.calls, contains('cancel'));
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      final session = await real(
        tester,
        () => sessions().sessionOf(job.reel.id),
      );
      expect(session, isNull);
    });

    testApp('every clip failed: the system back is the Back button (nothing '
        'to lose)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, failed: [0, 1, 2, 3]),
      );

      await tester.binding.handlePopRoute();
      await settleApp(tester);

      expect(find.text('Stop copying?'), findsNothing);
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
    });

    testApp('the only clip failed: "The clip couldn\'t be copied"', (
      tester,
    ) async {
      final job = await firstJob(tester, count: 1);
      await open(tester, job.jobId);

      await emit(tester, job.report(state: CopyState.finished, failed: [0]));

      expect(find.text("The clip couldn't be copied"), findsOneWidget);
      expect(find.text('It may have been deleted or moved.'), findsOneWidget);
    });
  });

  group('when it finished cleanly', () {
    testApp('first job: the ready screen, the job finished, the engine '
        'cleared', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2, 3]),
      );

      expect(find.text('Ready for VN'), findsOneWidget);
      expect(h.copy.job, isNull);
      expect(h.copy.calls.where((c) => c == 'clear'), hasLength(1));
      final state = await real(tester, () => sessions().editState(job.reel.id));
      expect(state!.copies, hasLength(4));
      // The plan is gone: nothing is left to recover.
      final context = await real(tester, () => service().jobContext(job.jobId));
      expect(context, isNull);
    });

    testApp('add job: the reel\'s page and "{n} clips added to the VN '
        'folder"', (tester) async {
      final job = await addJob(tester);
      await open(tester, job.jobId);

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2]),
      );

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(find.text('3 clips added to the VN folder'), findsOneWidget);
      expect(find.text('Ready for VN'), findsNothing);
    });

    testApp('add job of one clip: "1 clip added to the VN folder"', (
      tester,
    ) async {
      final job = await addJob(tester, count: 2);
      await open(tester, job.jobId);

      await emit(tester, job.report(state: CopyState.finished, copied: [0]));

      expect(find.text('1 clip added to the VN folder'), findsOneWidget);
    });

    testApp('a result seen twice finishes once (the engine repeats a '
        'snapshot)', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      final done = job.report(state: CopyState.finished, copied: [0, 1, 2, 3]);

      h.copy.emit(done);
      h.copy.emit(done);
      await settleApp(tester);

      expect(h.copy.calls.where((c) => c == 'clear'), hasLength(1));
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp('already finished when the screen opens (an unseen result): the '
        'same finish', (tester) async {
      final job = await firstJob(tester);
      h.copy.emit(job.report(state: CopyState.finished, copied: [0, 1, 2, 3]));

      await open(tester, job.jobId);

      expect(find.text('Ready for VN'), findsOneWidget);
      expect(h.copy.screenOnCalls, isEmpty);
    });

    testApp('finishJob that fails: the screen stays with Try again, then '
        'goes on', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      h.copy.failNext('clear');

      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2, 3]),
      );

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Ready for VN'), findsNothing);
      expect(h.copy.screenOnCalls, [true, false]);

      await tapButton(tester, 'Try again');
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp('after a restart: a recovered job that had everything copied '
        'finishes through Try again to the ready screen', (tester) async {
      final job = await firstJob(tester, count: 2);
      h.copy.job = null;
      h.copy.folders[job.folder] = [
        for (var i = 0; i < 2; i++)
          FolderRow(
            mediaStoreId: 700 + i,
            fileName: job.request.items[i].fileName,
            sizeBytes: 100 * _mb,
            pending: false,
          ),
      ];
      app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      followJob(app);
      await settleApp(tester);
      await real(tester, () => service().recoverAtStart());
      await settleApp(tester);
      unawaited(routerOf(tester).push(Routes.copyProgressOf(job.jobId)));
      await settleApp(tester);
      expect(find.text('Copying stopped'), findsOneWidget);

      await tapButton(tester, 'Try again');

      expect(find.text('Ready for VN'), findsOneWidget);
      expect(h.copy.starts, hasLength(1), reason: 'no engine job was needed');
    });

    testApp('after a restart: the recovered job of an add job finishes to '
        "the reel's page with the snack", (tester) async {
      final job = await addJob(tester, count: 3);
      h.copy.job = null;
      h.copy.folders[job.folder] = [
        for (var i = 0; i < job.request.items.length; i++)
          FolderRow(
            mediaStoreId: 700 + i,
            fileName: job.request.items[i].fileName,
            sizeBytes: 100 * _mb,
            pending: false,
          ),
      ];
      app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      followJob(app);
      await settleApp(tester);
      await real(tester, () => service().recoverAtStart());
      await settleApp(tester);
      unawaited(routerOf(tester).push(Routes.copyProgressOf(job.jobId)));
      await settleApp(tester);

      await tapButton(tester, 'Try again');

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(find.text('2 clips added to the VN folder'), findsOneWidget);
    });
  });

  group('when the job or the reel is gone', () {
    testApp('no job at all for that id: the reel it names, no error', (
      tester,
    ) async {
      final job = await firstJob(tester);
      h.copy.job = null;
      app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      await settleApp(tester);

      unawaited(routerOf(tester).push(Routes.copyProgressOf(job.jobId)));
      await settleApp(tester);

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(h.copy.screenOnCalls, isEmpty);
    });

    testApp('a job id that names no reel and no job: Reels', (tester) async {
      app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      await settleApp(tester);

      unawaited(routerOf(tester).push(Routes.copyProgressOf('nonsense')));
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('another job holds the engine: this screen goes to its reel', (
      tester,
    ) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);

      h.copy.emit(
        job.report().copyWith(jobId: '${job.reel.id}-99999999999999'),
      );
      await settleApp(tester);

      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
    });

    testApp('the reel is deleted while copying: the job is cancelled, the '
        "screen leaves to the reel's page (which goes to Reels itself) "
        'with no word and no error', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await emit(tester, job.report(copied: [0]));

      // As the app deletes a reel (`ReelActions.confirmDelete`): the job and
      // the copies first, then the reel. The test pumps in between, because
      // the drift queries the open screen follows are scheduled on the test
      // clock and must run before the next write can start.
      await real(
        tester,
        () =>
            app.read(editSessionServiceProvider).beforeReelDelete(job.reel.id),
      );
      await settleApp(tester);
      await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).delete(job.reel.id),
      );
      await settleApp(tester);

      // The job was cleared before the reel went, so the screen left for the
      // reel's page; the real page sees the reel is gone and goes to Reels
      // (D-87), which this test's stand-in page does not.
      expect(find.text(reelRouteMarker(job.reel.id)), findsOneWidget);
      expect(find.text('Copying clips for VN'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('Copying stopped. No copies were kept.'), findsNothing);
      expect(h.copy.screenOnCalls.last, isFalse);
    });

    testApp('Stop on a reel that was deleted meanwhile: Reels', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).delete(job.reel.id),
      );
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('a clean finish for a reel that is gone: Reels, no ready '
        'screen', (tester) async {
      final job = await firstJob(tester);
      await open(tester, job.jobId);
      await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).delete(job.reel.id),
      );
      // The delete took the reel while the engine's result is still coming.
      h.copy.job = null;
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(find.text('Ready for VN'), findsNothing);
    });
  });

  group('the ready and the logs', () {
    testApp('nothing in the logs names a reel, a folder or a file', (
      tester,
    ) async {
      final logs = captureLogs();
      final job = await firstJob(tester, name: 'Secret Reel Name');
      await open(tester, job.jobId);
      await emit(
        tester,
        job.report(state: CopyState.finished, copied: [0, 1, 2, 3]),
      );

      final text = logText(logs);
      expect(text, isNot(contains('Secret Reel Name')));
      for (final item in job.request.items) {
        expect(text, isNot(contains(item.fileName)));
      }
    });
  });
}
