import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/views/copy_progress_screen.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/spy_edit_session_service.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import '../reels/edit_session_support.dart' show startEditing;
import 'copy_support.dart';

const int _mb = 1000000;

/// The real service that counts how often a copy was asked for.
class _CountingService extends SpyEditSessionService {
  _CountingService(super.h);

  int starts = 0;

  @override
  Future<String> startCopy(CopyPlan plan) {
    starts++;
    return super.startCopy(plan);
  }
}

/// The real service whose next plans fail once [failPlans] is set.
class _ReplanService extends SpyEditSessionService {
  _ReplanService(super.h);

  bool failPlans = false;

  @override
  Future<CopyPlan> planCopy(int reelId, EditorApp editor, List<int> clipIds) {
    if (failPlans) throw StateError('the phone could not say');
    return super.planCopy(reelId, editor, clipIds);
  }
}

void main() {
  late VmHarness h;

  setUp(() {
    h = reelHarness();
    h.editors.allow({'freeBytes', 'copyFolderNames', 'filesInCopyFolders'});
    h.copy.allowAll();
    h.editors.bytesFree = 6200 * _mb;
  });

  /// Opens the space check of [reel] over a "home" page, so Back has
  /// somewhere to go.
  Future<void> open(
    WidgetTester tester,
    Reel reel,
    List<int> ids, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
    EditorApp editor = EditorApp.vn,
  }) async {
    await pumpScreen(
      tester,
      const Scaffold(body: Text('home')),
      overrides: h.appOverrides,
      copyScreens: true,
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    unawaited(routerOf(tester).push(Routes.copySpaceOf(reel.id, editor, ids)));
    await settleApp(tester);
  }

  TtStorageBar bar(WidgetTester tester) =>
      tester.widget<TtStorageBar>(find.byType(TtStorageBar));

  TtButton button(WidgetTester tester, String label) =>
      tester.widget<TtButton>(find.widgetWithText(TtButton, label));

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(TtButton, label));
    await settleApp(tester);
  }

  /// [count] clips of [each] bytes (ids in shooting order).
  Future<(Reel, List<int>)> clips(
    WidgetTester tester,
    int count,
    int each, {
    String name = 'Goa',
  }) => reelWithClips(tester, h, name: name, count: count, sizeBytes: each);

  group('enough space', () {
    testApp('the title, the numbers, the bar, the notes and the buttons', (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 3, 300 * _mb);
      await open(tester, goa, ids);

      expect(find.text('Copy clips for VN'), findsOneWidget);
      expect(find.text('These 3 clips need 900 MB'), findsOneWidget);
      expect(find.text('You have 6.2 GB free.'), findsOneWidget);
      expect(bar(tester).needFraction, closeTo(900 / 6200, 0.0001));
      expect(bar(tester).needLabel, 'Copies: 900 MB');
      expect(bar(tester).freeAfterLabel, 'Free after copying: 5.3 GB');
      expect(
        bar(tester).semanticLabel,
        'Free space 6.2 GB, copies need 900 MB',
      );
      expect(
        find.text('TakeTray keeps 500 MB free for your phone.'),
        findsOneWidget,
      );
      expect(find.text('Why copies?'), findsOneWidget);
      expect(
        findPlain(
          'VN needs all the clips in one folder. TakeTray copies them to '
          'Movies/TakeTray/Goa. Your original clips stay where they are.',
        ),
        findsOneWidget,
      );
      expect(find.text('Copies are temporary'), findsOneWidget);
      expect(
        find.text(
          'After you export from VN, tap Done editing and TakeTray deletes '
          'them.',
        ),
        findsOneWidget,
      );
      expect(button(tester, 'Copy 3 clips').onPressed, isNotNull);
      expect(button(tester, 'Back').onPressed, isNotNull);
      // The short wording is not here.
      expect(find.text('Not enough space'), findsNothing);
      expect(find.text('Select fewer clips'), findsNothing);
    });

    testApp('the folder in "Why copies?" is in bold', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await open(tester, goa, ids);

      final why = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText() ?? '').startsWith('VN needs all'),
        ),
      );
      final spans = <TextSpan>[];
      why.textSpan!.visitChildren((span) {
        if (span is TextSpan && (span.text ?? '').isNotEmpty) spans.add(span);
        return true;
      });
      final bold = spans.where(
        (s) => (s.style?.fontWeight?.value ?? 400) > 500,
      );
      expect([for (final s in bold) s.text], ['Movies/TakeTray/Goa']);
    });

    testApp('one clip says "This clip needs" and "Copy 1 clip"', (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 1, 300 * _mb);
      await open(tester, goa, ids);

      expect(find.text('This clip needs 300 MB'), findsOneWidget);
      expect(button(tester, 'Copy 1 clip').onPressed, isNotNull);
    });

    testApp('only the clips with no copy are counted: the ones already '
        'copied are left out', (tester) async {
      final (goa, ids) = await clips(tester, 3, 300 * _mb);
      await real(tester, () async {
        final sessions = h.container.read(editSessionsRepositoryProvider);
        await sessions.startSession(goa.id, EditorApp.vn, 'Goa');
      });
      // Reel "Goa" has a VN session already, with no copy.
      await open(tester, goa, ids);
      expect(find.text('These 3 clips need 900 MB'), findsOneWidget);
    });

    testApp('just enough: the need plus 500 MB is enough, one byte less is '
        'short', (tester) async {
      final (goa, ids) = await clips(tester, 2, 250 * _mb);
      h.editors.bytesFree = 1000 * _mb;
      await open(tester, goa, ids);
      expect(find.text('Copy 2 clips'), findsOneWidget);
      expect(find.text('Not enough space'), findsNothing);
    });

    testApp('one byte under the need plus 500 MB is short', (tester) async {
      final (goa, ids) = await clips(tester, 2, 250 * _mb);
      h.editors.bytesFree = 1000 * _mb - 1;
      await open(tester, goa, ids);
      expect(find.text('Not enough space'), findsOneWidget);
      expect(find.text('Copy 2 clips'), findsNothing);
    });

    testApp("a renamed reel shows its session's folder, not its name", (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await real(tester, () async {
        await h.container
            .read(editSessionsRepositoryProvider)
            .startSession(goa.id, EditorApp.vn, 'Goa');
        await h.container.read(reelsRepositoryProvider).rename(goa.id, 'Goa 2');
      });
      await open(tester, goa, ids);

      expect(
        findPlain(
          'VN needs all the clips in one folder. TakeTray copies them to '
          'Movies/TakeTray/Goa. Your original clips stay where they are.',
        ),
        findsOneWidget,
      );
    });

    testApp('Back goes back', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await open(tester, goa, ids);

      await tapButton(tester, 'Back');

      expect(find.text('home'), findsOneWidget);
      expect(h.copy.calls, isNot(contains('start')));
    });

    testApp('the close button goes back', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await open(tester, goa, ids);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Close',
        ),
      );
      await settleApp(tester);

      expect(find.text('home'), findsOneWidget);
    });
  });

  group('not enough space', () {
    testApp('free above the need but under the reserve: the bar has the '
        'reserve taken off', (tester) async {
      // Free 1.2 GB, need 1 GB: (1.2 GB - 500 MB) / 1 GB = 0.7 of the need.
      final (goa, ids) = await clips(tester, 4, 250 * _mb);
      h.editors.bytesFree = 1200 * _mb;
      await open(tester, goa, ids);

      expect(find.text('Not enough space'), findsOneWidget);
      expect(
        find.text('These 4 clips need 1 GB. You have 1.2 GB free.'),
        findsOneWidget,
      );
      expect(bar(tester).haveFraction, closeTo(0.7, 0.0001));
      expect(bar(tester).haveLabel, 'You have 1.2 GB');
      expect(bar(tester).shortLabel, 'Short by 300 MB');
      expect(
        bar(tester).semanticLabel,
        'Copies need 1 GB, you have 1.2 GB, short by 300 MB',
      );
      expect(find.text('What you can do'), findsOneWidget);
      expect(
        find.text(
          'Select fewer clips, or free up space on your phone and try again.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('TakeTray keeps 500 MB free for your phone.'),
        findsOneWidget,
      );
      expect(button(tester, 'Select fewer clips').onPressed, isNotNull);
      expect(button(tester, 'Cancel').onPressed, isNotNull);
      // No Copy button, no "Why copies?".
      expect(find.textContaining('Copy 4'), findsNothing);
      expect(find.text('Why copies?'), findsNothing);
    });

    testApp('free under the reserve: the solid part is 0', (tester) async {
      final (goa, ids) = await clips(tester, 1, 100 * _mb);
      h.editors.bytesFree = 400 * _mb;
      await open(tester, goa, ids);

      expect(bar(tester).haveFraction, 0);
      expect(bar(tester).shortLabel, 'Short by 200 MB');
      expect(bar(tester).haveLabel, 'You have 400 MB');
    });

    testApp('no free space at all: 0 MB, solid part 0, no crash', (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 1, 100 * _mb);
      h.editors.bytesFree = 0;
      await open(tester, goa, ids);

      expect(bar(tester).haveFraction, 0);
      expect(bar(tester).haveLabel, 'You have 0 MB');
      expect(bar(tester).shortLabel, 'Short by 600 MB');
      expect(tester.takeException(), isNull);
    });

    testApp('Select fewer clips goes back to the picking screen', (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 4, 250 * _mb);
      h.editors.bytesFree = 1200 * _mb;
      await open(tester, goa, ids);

      await tapButton(tester, 'Select fewer clips');

      expect(find.text('home'), findsOneWidget);
    });

    testApp("Cancel goes to the reel's page and says nothing", (tester) async {
      final (goa, ids) = await clips(tester, 4, 250 * _mb);
      h.editors.bytesFree = 1200 * _mb;
      await open(tester, goa, ids);

      await tapButton(tester, 'Cancel');

      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(find.textContaining('Copying stopped'), findsNothing);
      expect(h.copy.calls, isNot(contains('cancel')));
    });
  });

  group('Copy', () {
    testApp('starts one job on a double tap and replaces the screen with the '
        'progress', (tester) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      await open(tester, goa, ids);
      final held = h.copy.gate('start');

      await tester.tap(find.text('Copy 3 clips'));
      await tester.pump();
      await tester.tap(find.text('Copy 3 clips'), warnIfMissed: false);
      await tester.pump();
      held.complete();
      await settleApp(tester);

      expect(h.copy.starts, hasLength(1));
      expect(h.copy.starts.single.items, hasLength(3));
      final job = h.copy.starts.single.jobId;
      expect(
        tester
            .widget<CopyProgressScreen>(find.byType(CopyProgressScreen))
            .jobId,
        job,
      );
      expect(find.text('Copying clips for VN'), findsOneWidget);
      // Replaced, not pushed: Back from the progress is the page below.
      routerOf(tester).pop();
      await settleApp(tester);
      expect(find.text('home'), findsOneWidget);
    });

    testApp('two taps in the same frame ask for one copy', (tester) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      final service = _CountingService(h);
      await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: [
          ...h.appOverrides,
          editSessionServiceProvider.overrideWithValue(service),
        ],
        copyScreens: true,
        settle: false,
      );
      unawaited(
        routerOf(tester).push(Routes.copySpaceOf(goa.id, EditorApp.vn, ids)),
      );
      await settleApp(tester);

      // No frame between the two taps: the button is still on for the second.
      await tester.tap(find.text('Copy 3 clips'));
      await tester.tap(find.text('Copy 3 clips'), warnIfMissed: false);
      await settleApp(tester);

      expect(service.starts, 1);
      expect(h.copy.starts, hasLength(1));
    });

    testApp('a re-plan that fails while the copy is starting shows no error '
        'flash and no empty screen (T10-M5)', (tester) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      final service = _ReplanService(h);
      await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: [
          ...h.appOverrides,
          editSessionServiceProvider.overrideWithValue(service),
        ],
        copyScreens: true,
        settle: false,
      );
      unawaited(
        routerOf(tester).push(Routes.copySpaceOf(goa.id, EditorApp.vn, ids)),
      );
      await settleApp(tester);
      final held = h.copy.gate('start');

      await tester.tap(find.text('Copy 3 clips'));
      await tester.pump();
      // The reel changes while the start waits: the plan is made again, and
      // that fails.
      service.failPlans = true;
      await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).rename(goa.id, 'Goa 2'),
      );
      await settleApp(tester);

      expect(find.text("Couldn't start copying. Try again."), findsNothing);
      expect(find.text('Copy clips for VN'), findsOneWidget);
      expect(button(tester, 'Copy 3 clips').onPressed, isNull);

      held.complete();
      await settleApp(tester);
      expect(find.byType(CopyProgressScreen), findsOneWidget);
    });

    testApp('a re-plan that fails when no copy is starting still says '
        "Couldn't start copying (T10-M5)", (tester) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      final service = _ReplanService(h);
      await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: [
          ...h.appOverrides,
          editSessionServiceProvider.overrideWithValue(service),
        ],
        copyScreens: true,
        settle: false,
      );
      unawaited(
        routerOf(tester).push(Routes.copySpaceOf(goa.id, EditorApp.vn, ids)),
      );
      await settleApp(tester);

      service.failPlans = true;
      await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).rename(goa.id, 'Goa 2'),
      );
      await settleApp(tester);

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
    });

    testApp('while it starts, the buttons and the system back do nothing', (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      await open(tester, goa, ids);
      final held = h.copy.gate('start');

      await tester.tap(find.text('Copy 3 clips'));
      await tester.pump();
      await tester.pump();

      expect(button(tester, 'Back').onPressed, isNull);
      expect(button(tester, 'Copy 3 clips').onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Copy clips for VN'), findsOneWidget);

      held.complete();
      await settleApp(tester);
      expect(h.copy.starts, hasLength(1));
    });

    testApp('a busy engine: "Couldn\'t start copying. Try again." and the '
        'screen stays; a second try works', (tester) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      await open(tester, goa, ids);
      // Another job's result still waits in the engine.
      h.copy.job = const CopyJob(
        jobId: '99-1',
        reelId: 99,
        folderName: 'Other',
        state: CopyState.finished,
        total: 1,
        done: 1,
        bytesDone: 1,
        bytesTotal: 1,
        copied: [],
        failedClipIds: [],
        undeleted: [],
      );

      await tapButton(tester, 'Copy 3 clips');

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(find.text('Copy clips for VN'), findsOneWidget);
      expect(button(tester, 'Copy 3 clips').onPressed, isNotNull);
      // Nothing was left behind: no session for the reel.
      final session = await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).sessionOf(goa.id),
      );
      expect(session, isNull);

      h.copy.job = null;
      await tapButton(tester, 'Copy 3 clips');
      expect(h.copy.starts, hasLength(1));
      expect(find.text('Copying clips for VN'), findsOneWidget);
    });

    testApp('a stopped job whose screen was replaced: Copy on another reel '
        'opens the held job, where Try again works (I-1)', (tester) async {
      final (goa, goaIds) = await clips(tester, 3, 100 * _mb);
      final job = await startVnJob(tester, h, goa, goaIds);
      final app = await pumpScreen(
        tester,
        const Scaffold(body: Text('home')),
        overrides: h.appOverrides,
        copyScreens: true,
        settle: false,
      );
      followJob(app);
      await settleApp(tester);
      unawaited(routerOf(tester).push(Routes.copyProgressOf(job.jobId)));
      await settleApp(tester);
      h.copy.emit(job.report(state: CopyState.spaceFull, copied: [0]));
      await settleApp(tester);
      expect(find.widgetWithText(TtButton, 'Try again'), findsOneWidget);
      // A notification tap replaces the whole stack, the result screen too.
      routerOf(tester).go(Routes.toTag);
      await settleApp(tester);
      expect(find.widgetWithText(TtButton, 'Try again'), findsNothing);

      final (bali, baliIds) = await clips(tester, 2, 100 * _mb, name: 'Bali');
      unawaited(
        routerOf(tester)
            .push(Routes.copySpaceOf(bali.id, EditorApp.vn, baliIds)),
      );
      await settleApp(tester);
      await tapButton(tester, 'Copy 2 clips');

      expect(find.text("Couldn't start copying. Try again."), findsNothing);
      // The held job's own screen, not the generic failure.
      expect(find.widgetWithText(TtButton, 'Try again'), findsOneWidget);
      expect(
        find.widgetWithText(TtButton, 'Delete copies and stop'),
        findsOneWidget,
      );
      await tapButton(tester, 'Try again');
      expect(h.copy.calls.where((c) => c == 'resume'), hasLength(1));
    });

    testApp('a copy that is still running for another reel: Copy opens its '
        'progress, not the generic failure (I-1)', (tester) async {
      final (goa, goaIds) = await clips(tester, 3, 100 * _mb);
      final job = await startVnJob(tester, h, goa, goaIds);
      final (bali, baliIds) = await clips(tester, 2, 100 * _mb, name: 'Bali');
      await open(tester, bali, baliIds);

      await tapButton(tester, 'Copy 2 clips');

      expect(find.text("Couldn't start copying. Try again."), findsNothing);
      expect(find.text('Copying clips for VN'), findsOneWidget);
      expect(find.text('0 of 3 clips'), findsOneWidget);
      expect(job.jobId, startsWith('${goa.id}-'));
      expect(h.copy.starts, hasLength(1));
    });

    testApp('any other start failure says the same and stays', (tester) async {
      final (goa, ids) = await clips(tester, 3, 100 * _mb);
      await open(tester, goa, ids);
      h.copy.failNext('start');

      await tapButton(tester, 'Copy 3 clips');

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(find.text('Copy clips for VN'), findsOneWidget);
      expect(button(tester, 'Copy 3 clips').onPressed, isNotNull);
    });

    testApp('clips that went missing after the check: the same calm '
        'message, nothing started', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await open(tester, goa, ids);
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));

      await tapButton(tester, 'Copy 2 clips');

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(h.copy.starts, isEmpty);
    });
  });

  group("when the numbers can't be had", () {
    testApp('no live clip: Nothing to copy, with Back', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));
      await open(tester, goa, ids);

      expect(find.text('Nothing to copy'), findsOneWidget);
      expect(
        find.text(
          'These clips are already copied, or missing from your phone.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Copy 0'), findsNothing);
      await tapButton(tester, 'Back');
      expect(find.text('home'), findsOneWidget);
    });

    testApp('the phone does not answer: a calm message, Try again asks '
        'again, Back goes back', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      h.editors.failNext('freeBytes');
      await open(tester, goa, ids);

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(find.textContaining('Copy 2'), findsNothing);

      await tapButton(tester, 'Try again');
      expect(find.text('Copy clips for VN'), findsOneWidget);
      expect(find.text('Copy 2 clips'), findsOneWidget);

      await tapButton(tester, 'Back');
      expect(find.text('home'), findsOneWidget);
    });

    testApp('a reel that is in another editor already: the same message, no '
        'crash', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await real(tester, () async {
        await h.container
            .read(editSessionsRepositoryProvider)
            .startSession(goa.id, EditorApp.capcut, 'Goa');
      });
      await open(tester, goa, ids);

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testApp('a reel that is deleted while the screen is open goes to Reels', (
      tester,
    ) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);
      await open(tester, goa, ids);

      await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).delete(goa.id),
      );
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('for CapCut and Edits (D-129)', () {
    ReelsRepository reelsOf(VmHarness h) =>
        h.container.read(reelsRepositoryProvider);

    /// A reel of [count] clips of 100 MB in a [editor] session: the first
    /// clip sent, so the session exists as after the first share.
    Future<(Reel, List<int>)> sessionReel(
      WidgetTester tester,
      EditorApp editor, {
      int count = 3,
    }) async {
      final (goa, ids) = await clips(tester, count, 100 * _mb);
      await real(
        tester,
        () => startEditing(h, goa.id, editor, sent: [ids.first]),
      );
      return (goa, ids);
    }

    for (final (editor, name) in [
      (EditorApp.capcut, 'CapCut'),
      (EditorApp.edits, 'Instagram Edits'),
    ]) {
      testApp('$name: the title and both notes name the editor and the '
          "session's folder, never VN", (tester) async {
        final (goa, ids) = await sessionReel(tester, editor);
        await real(tester, () => reelsOf(h).rename(goa.id, 'Goa 2'));

        await open(tester, goa, ids, editor: editor);

        expect(find.text('Copy clips for $name'), findsOneWidget);
        expect(find.text('Why copies?'), findsOneWidget);
        expect(
          findPlain(
            '$name adds clips to a project from an album. TakeTray copies the '
            'clips you picked to Movies/TakeTray/Goa. Your original clips '
            'stay where they are.',
          ),
          findsOneWidget,
        );
        expect(find.text('Copies are temporary'), findsOneWidget);
        expect(
          find.text(
            'After you export from $name, tap Done editing and TakeTray '
            'deletes them.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('VN'), findsNothing);
        expect(button(tester, 'Copy 3 clips').onPressed, isNotNull);
      });
    }

    testApp('the folder in "Why copies?" is in bold', (tester) async {
      final (goa, ids) = await sessionReel(tester, EditorApp.capcut);
      await open(tester, goa, ids, editor: EditorApp.capcut);

      final why = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText() ?? '').startsWith('CapCut adds'),
        ),
      );
      final bold = <String>[];
      why.textSpan!.visitChildren((span) {
        if (span is TextSpan &&
            (span.text ?? '').isNotEmpty &&
            (span.style?.fontWeight?.value ?? 400) > 500) {
          bold.add(span.text!);
        }
        return true;
      });
      expect(bold, ['Movies/TakeTray/Goa']);
    });

    testApp("Copy starts one job in the session's folder, with the session "
        'kept, and shows the progress for the editor', (tester) async {
      final (goa, ids) = await sessionReel(tester, EditorApp.capcut);
      await real(tester, () => reelsOf(h).rename(goa.id, 'Goa 2'));
      await open(tester, goa, ids, editor: EditorApp.capcut);

      await tapButton(tester, 'Copy 3 clips');

      expect(h.copy.starts, hasLength(1));
      expect(h.copy.starts.single.folderName, 'Goa');
      expect(h.copy.starts.single.items, hasLength(3));
      expect(find.text('Copying clips for CapCut'), findsOneWidget);
      final session = await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).sessionOf(goa.id),
      );
      expect(session!.editor, EditorApp.capcut);
      expect(session.folderName, 'Goa');
    });

    testApp('not enough space: the short state, nothing started, the '
        'session untouched', (tester) async {
      final (goa, ids) = await sessionReel(tester, EditorApp.edits, count: 4);
      h.editors.bytesFree = 700 * _mb;
      await open(tester, goa, ids, editor: EditorApp.edits);

      expect(find.text('Not enough space'), findsOneWidget);
      expect(find.text('Select fewer clips'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.textContaining('Copy 4'), findsNothing);
      expect(h.copy.starts, isEmpty);
      final state = await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).editState(goa.id),
      );
      expect(state!.sentIds, {ids.first});
    });

    testApp('a start that fails says "Couldn\'t start copying. Try again." '
        'and keeps the session and its sent rows', (tester) async {
      final (goa, ids) = await sessionReel(tester, EditorApp.edits);
      await open(tester, goa, ids, editor: EditorApp.edits);
      h.copy.failNext('start');

      await tapButton(tester, 'Copy 3 clips');

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(find.text('Copy clips for Instagram Edits'), findsOneWidget);
      final state = await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).editState(goa.id),
      );
      expect(state!.session.editor, EditorApp.edits);
      expect(state.sentIds, {ids.first});
      expect(state.copies, isEmpty);
    });

    testApp('CapCut with no session (it starts with a share): the same '
        'calm message', (tester) async {
      final (goa, ids) = await clips(tester, 2, 100 * _mb);

      await open(tester, goa, ids, editor: EditorApp.capcut);

      expect(find.text("Couldn't start copying. Try again."), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testApp('CapCut enough and short are accessible at text $scale x', (
        tester,
      ) async {
        final (goa, ids) = await sessionReel(tester, EditorApp.capcut);
        await open(
          tester,
          goa,
          ids,
          editor: EditorApp.capcut,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
      });
    }
  });

  group('looks', () {
    for (final scale in [1.0, 2.0]) {
      testApp('enough and short are accessible at text $scale x', (
        tester,
      ) async {
        final (goa, ids) = await clips(tester, 4, 250 * _mb);
        await open(tester, goa, ids, textScale: scale);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      });

      testApp('short is accessible at text $scale x', (tester) async {
        final (goa, ids) = await clips(tester, 4, 250 * _mb);
        h.editors.bytesFree = 1200 * _mb;
        await open(tester, goa, ids, textScale: scale);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testApp('dark: accessible', (tester) async {
      final (goa, ids) = await clips(tester, 4, 250 * _mb);
      await open(tester, goa, ids, brightness: Brightness.dark);
      await expectTtAccessible(tester);
    });

    testApp('a long reel name does not break the layout', (tester) async {
      final (goa, ids) = await clips(
        tester,
        2,
        100 * _mb,
        name: 'A very long reel name goes on and on now',
      );
      await open(tester, goa, ids, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
