import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
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

  setUp(() {
    h = reelHarness();
    h.editors.allow({'openApp', 'openStoreListing'});
  });

  /// Reel [name] with [count] clips, a VN session in folder [folder] and a
  /// recorded copy of each clip.
  Future<(Reel, List<int>)> readyReel(
    WidgetTester tester, {
    int count = 4,
    String name = 'Goa',
    String folder = 'Goa',
    bool copies = true,
    EditorApp editor = EditorApp.vn,
  }) async {
    final (reel, ids) = await reelWithClips(
      tester,
      h,
      name: name,
      count: count,
    );
    await real(tester, () async {
      final sessions = h.container.read(editSessionsRepositoryProvider);
      await sessions.startSession(reel.id, editor, folder);
      if (editor.takesShares) await sessions.recordSent(reel.id, ids);
      if (copies) {
        await sessions.recordCopies([
          for (final (i, id) in ids.indexed)
            EditCopy(
              reelId: reel.id,
              clipId: id,
              copyMediaStoreId: 700 + i,
              fileName: 'c$i.mp4',
              sizeBytes: 100 * _mb,
              copiedAt: DateTime.utc(2026, 10, 30),
            ),
        ]);
      }
    });
    return (reel, ids);
  }

  Future<void> open(
    WidgetTester tester,
    int reelId, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
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
    unawaited(routerOf(tester).push(Routes.copyReadyOf(reelId)));
    await settleApp(tester);
  }

  Finder buttonOf(String label) => find.widgetWithText(TtButton, label);

  group('the steps', () {
    testApp('Ready for VN, the line with the folder in bold, three steps '
        'with the folder in them', (tester) async {
      final (reel, _) = await readyReel(tester);
      await open(tester, reel.id);

      expect(find.text('Ready for VN'), findsOneWidget);
      expect(
        findPlain('In VN, tap New project and open the Goa folder.'),
        findsOneWidget,
      );
      final intro = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText() ?? '').startsWith('In VN, tap'),
        ),
      );
      final bold = <String>[];
      intro.textSpan!.visitChildren((span) {
        if (span is TextSpan &&
            (span.text ?? '').isNotEmpty &&
            (span.style?.fontWeight?.value ?? 400) > 500) {
          bold.add(span.text!);
        }
        return true;
      });
      expect(bold, ['New project', 'Goa']);

      final steps = tester.widget<TtIllustratedSteps>(
        find.byType(TtIllustratedSteps),
      );
      expect(
        [for (final s in steps.steps) s.number],
        ['Step 1', 'Step 2', 'Step 3'],
      );
      expect(
        [for (final s in steps.steps) s.title],
        [
          'Open VN, tap New project',
          'Open the Goa folder',
          'Select all the clips',
        ],
      );
      expect(
        [for (final s in steps.steps) s.body],
        [
          "It's the big + button.",
          'Inside Movies › TakeTray.',
          "They're already in shooting order.",
        ],
      );
      expect(steps.steps[1].folders, [
        'Camera',
        'Download',
        'Goa',
        'WhatsApp Video',
      ]);
      expect(steps.steps[1].highlighted, 2);
    });

    testApp("the session's folder, also after the reel was renamed", (
      tester,
    ) async {
      final (reel, _) = await readyReel(tester);
      await real(
        tester,
        () => h.container
            .read(reelsRepositoryProvider)
            .rename(reel.id, 'Goa trip 2'),
      );
      await open(tester, reel.id);

      expect(
        findPlain('In VN, tap New project and open the Goa folder.'),
        findsOneWidget,
      );
      expect(find.text('Open the Goa folder'), findsOneWidget);
      expect(find.textContaining('Goa trip 2'), findsNothing);
    });

    testApp('a folder with a number in its name ("Goa (2)") is shown as it '
        'is', (tester) async {
      final (reel, _) = await readyReel(tester, folder: 'Goa (2)');
      await open(tester, reel.id);

      expect(find.text('Open the Goa (2) folder'), findsOneWidget);
    });

    testApp('up to six numbered pictures, the first six in shooting order', (
      tester,
    ) async {
      final (reel, ids) = await readyReel(tester, count: 8);
      await open(tester, reel.id);

      final steps = tester.widget<TtIllustratedSteps>(
        find.byType(TtIllustratedSteps),
      );
      // The step is given the first six (the picture holds six).
      expect(steps.steps[2].thumbnails, hasLength(6));
      expect(find.byKey(const ValueKey('tt-step-tile-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('tt-step-tile-6')), findsNothing);
      expect(ids, hasLength(8));
    });

    testApp('fewer than six clips show that many pictures', (tester) async {
      final (reel, _) = await readyReel(tester, count: 2);
      await open(tester, reel.id);

      expect(find.byKey(const ValueKey('tt-step-tile-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('tt-step-tile-2')), findsNothing);
    });

    testApp('clips that went missing are not pictured', (tester) async {
      final (reel, ids) = await readyReel(tester, count: 3);
      await real(tester, () => flagForTest(h, {ids[0]}, missing: true));
      await open(tester, reel.id);

      expect(find.byKey(const ValueKey('tt-step-tile-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('tt-step-tile-2')), findsNothing);
    });

    testApp('every clip gone: no pictures and no crash', (tester) async {
      final (reel, ids) = await readyReel(tester, count: 2);
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));
      await open(tester, reel.id);

      expect(find.byKey(const ValueKey('tt-step-tile-0')), findsNothing);
      expect(find.text('Select all the clips'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testApp('accessible and no overflow at text 1x, 2x and in dark', (
      tester,
    ) async {
      final (reel, _) = await readyReel(tester);
      for (final (scale, brightness) in [
        (1.0, Brightness.light),
        (2.0, Brightness.light),
        (1.0, Brightness.dark),
      ]) {
        await open(tester, reel.id, textScale: scale, brightness: brightness);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('for CapCut and Edits (D-129)', () {
    for (final (editor, name) in [
      (EditorApp.capcut, 'CapCut'),
      (EditorApp.edits, 'Instagram Edits'),
    ]) {
      testApp('$name: the title, the line with the + and the album in bold, '
          "the three steps with the session's folder", (tester) async {
        final (reel, _) = await readyReel(tester, editor: editor);
        await real(
          tester,
          () => h.container
              .read(reelsRepositoryProvider)
              .rename(reel.id, 'Goa trip 2'),
        );
        await open(tester, reel.id);

        expect(find.text('Ready to add in $name'), findsOneWidget);
        expect(
          findPlain('In your $name project, tap + and open the Goa album.'),
          findsOneWidget,
        );
        final intro = tester.widget<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.textSpan?.toPlainText() ?? '').startsWith('In your'),
          ),
        );
        final bold = <String>[];
        intro.textSpan!.visitChildren((span) {
          if (span is TextSpan &&
              (span.text ?? '').isNotEmpty &&
              (span.style?.fontWeight?.value ?? 400) > 500) {
            bold.add(span.text!);
          }
          return true;
        });
        expect(bold, ['+', 'Goa']);

        final steps = tester.widget<TtIllustratedSteps>(
          find.byType(TtIllustratedSteps),
        );
        expect(
          [for (final s in steps.steps) s.number],
          ['Step 1', 'Step 2', 'Step 3'],
        );
        expect(
          [for (final s in steps.steps) s.title],
          [
            'Open your project in $name',
            'Open the Goa album',
            'Pick the new clips',
          ],
        );
        expect(
          [for (final s in steps.steps) s.body],
          [
            'The one you started from TakeTray.',
            "It's in Movies › TakeTray.",
            "They're in shooting order.",
          ],
        );
        expect(steps.steps[1].folders, [
          'Camera',
          'Download',
          'Goa',
          'WhatsApp Video',
        ]);
        expect(steps.steps[1].highlighted, 2);
        expect(find.textContaining('VN'), findsNothing);
        expect(find.textContaining('Goa trip 2'), findsNothing);
        expect(find.text('Open $name'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      });
    }

    testApp('Open CapCut opens CapCut, not VN', (tester) async {
      final (reel, _) = await readyReel(tester, editor: EditorApp.capcut);
      await open(tester, reel.id);

      await tester.tap(buttonOf('Open CapCut'));
      await settleApp(tester);

      expect(h.editors.openedApps, [EditorApp.capcut.packageName]);
      expect(find.text('Ready to add in CapCut'), findsOneWidget);
    });

    testApp('Edits missing: the "Instagram Edits isn\'t installed" dialog', (
      tester,
    ) async {
      final (reel, _) = await readyReel(tester, editor: EditorApp.edits);
      h.editors.openAppResult = false;
      await open(tester, reel.id);

      await tester.tap(buttonOf('Open Instagram Edits'));
      await settleApp(tester);

      expect(find.text("Instagram Edits isn't installed"), findsOneWidget);
      await tester.tap(find.text('Choose another'));
      await settleApp(tester);
      expect(find.text('Ready to add in Instagram Edits'), findsOneWidget);
    });

    testApp('the pictures are the clips that have a copy, in shooting order, '
        'up to six', (tester) async {
      final (reel, _) = await readyReel(
        tester,
        count: 8,
        editor: EditorApp.capcut,
      );
      await open(tester, reel.id);

      final steps = tester.widget<TtIllustratedSteps>(
        find.byType(TtIllustratedSteps),
      );
      expect(steps.steps[2].thumbnails, hasLength(6));
    });

    testApp("Done goes to the reel's page and deletes nothing", (tester) async {
      final (reel, _) = await readyReel(tester, editor: EditorApp.capcut);
      await open(tester, reel.id);

      await tester.tap(buttonOf('Done'));
      await settleApp(tester);

      expect(find.text(reelRouteMarker(reel.id)), findsOneWidget);
      final state = await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).editState(reel.id),
      );
      expect(state!.copies, hasLength(4));
      expect(state.sentIds, hasLength(4));
    });

    testApp('accessible and no overflow at text 1x, 2x and in dark', (
      tester,
    ) async {
      final (reel, _) = await readyReel(tester, editor: EditorApp.edits);
      for (final (scale, brightness) in [
        (1.0, Brightness.light),
        (2.0, Brightness.light),
        (1.0, Brightness.dark),
      ]) {
        await open(tester, reel.id, textScale: scale, brightness: brightness);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('the buttons', () {
    testApp('Open VN opens VN once and stays', (tester) async {
      final (reel, _) = await readyReel(tester);
      await open(tester, reel.id);

      await tester.tap(buttonOf('Open VN'));
      await settleApp(tester);

      expect(h.editors.openedApps, [EditorApp.vn.packageName]);
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp('VN missing (openApp false): the "VN isn\'t installed" dialog, '
        'Choose another closes it', (tester) async {
      final (reel, _) = await readyReel(tester);
      h.editors.openAppResult = false;
      await open(tester, reel.id);

      await tester.tap(buttonOf('Open VN'));
      await settleApp(tester);

      expect(find.text("VN isn't installed"), findsOneWidget);
      await tester.tap(find.text('Choose another'));
      await settleApp(tester);
      expect(find.text("VN isn't installed"), findsNothing);
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp('Open VN that throws: a calm snack, the screen stays', (
      tester,
    ) async {
      final (reel, _) = await readyReel(tester);
      h.editors.failNext('openApp');
      await open(tester, reel.id);

      await tester.tap(buttonOf('Open VN'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Ready for VN'), findsOneWidget);
    });

    testApp("Done goes to the reel's page", (tester) async {
      final (reel, _) = await readyReel(tester);
      await open(tester, reel.id);

      await tester.tap(buttonOf('Done'));
      await settleApp(tester);

      expect(find.text(reelRouteMarker(reel.id)), findsOneWidget);
      // Done only leaves: the session and the copies stay.
      final state = await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).editState(reel.id),
      );
      expect(state!.copies, hasLength(4));
    });

    testApp("the close button goes to the reel's page", (tester) async {
      final (reel, _) = await readyReel(tester);
      await open(tester, reel.id);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Close',
        ),
      );
      await settleApp(tester);

      expect(find.text(reelRouteMarker(reel.id)), findsOneWidget);
    });

    testApp("the system back goes to the reel's page too", (tester) async {
      final (reel, _) = await readyReel(tester);
      await open(tester, reel.id);

      await tester.binding.handlePopRoute();
      await settleApp(tester);

      expect(find.text(reelRouteMarker(reel.id)), findsOneWidget);
    });
  });

  group('when the session or the reel is gone', () {
    testApp("no session any more (Done editing ran elsewhere): the reel's "
        'page', (tester) async {
      final (reel, _) = await readyReel(tester, copies: false);
      await real(
        tester,
        () => h.container
            .read(editSessionsRepositoryProvider)
            .endSession(reel.id),
      );
      await open(tester, reel.id);

      expect(find.text(reelRouteMarker(reel.id)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testApp('the reel is deleted while the screen is open: Reels', (
      tester,
    ) async {
      final (reel, _) = await readyReel(tester);
      await open(tester, reel.id);

      await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).delete(reel.id),
      );
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testApp('a reel that never existed: Reels', (tester) async {
      await open(tester, 4242);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });
  });
}
