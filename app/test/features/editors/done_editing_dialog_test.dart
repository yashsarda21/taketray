import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/views/done_editing_dialog.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/spy_edit_session_service.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import '../reels/edit_session_support.dart';
import 'copy_support.dart' show startVnJob;

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late SpyEditSessionService spy;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    spy = SpyEditSessionService(h);
  });

  /// "Goa" with four clips; returns the reel and the clip ids.
  Future<(Reel, List<int>)> goaReel(
    WidgetTester tester, {
    String name = 'Goa',
    ReelStatus status = ReelStatus.collecting,
  }) async {
    final goa = await real(tester, () => reels.create(name));
    if (status != ReelStatus.collecting) {
      await real(tester, () => reels.setStatus(goa.id, status));
    }
    final ids = await real(
      tester,
      () => putInReel(h, goa.id, [for (var i = 1; i <= 4; i++) reelVideo(i)]),
    );
    return (goa, ids);
  }

  /// A page with a "go" button that asks Done editing for reel [id].
  Future<void> pumpHost(
    WidgetTester tester,
    int id, {
    bool suggestPublished = true,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => showDoneEditingDialog(
              context,
              ref,
              id,
              suggestPublished: suggestPublished,
            ),
            child: const Text('go'),
          ),
        ),
      ),
      overrides: [
        ...h.appOverrides,
        editSessionServiceProvider.overrideWithValue(spy),
      ],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.tap(find.text('go'));
    await settleApp(tester);
  }

  /// Moves the fake clock on by [ms] in 100 ms steps, letting the database
  /// answer between them.
  Future<void> waitMs(WidgetTester tester, int ms) async {
    for (var gone = 0; gone < ms; gone += 100) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(settle);
    }
  }

  /// Taps [label] in the dialog without settling (which would move the clock
  /// on while the snack animates), then lets Done editing run.
  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.runAsync(settle);
    await tester.pump();
    await tester.runAsync(settle);
    await tester.pump();
  }

  /// Lets the Published offer come and go, so no timer is left.
  Future<void> flushOffer(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1500));
    await settleApp(tester);
  }

  Future<EditState?> editState(WidgetTester tester, int reelId) => real(
    tester,
    () => h.container.read(editSessionsRepositoryProvider).editState(reelId),
  );

  /// The dialog's text, no-break spaces made plain, bold parts included.
  String dialogText(WidgetTester tester) => [
    for (final e
        in find
            .descendant(
              of: find.byType(TtDialog<bool>),
              matching: find.byType(RichText),
            )
            .evaluate())
      (e.widget as RichText).text.toPlainText(),
  ].join('\n').replaceAll(RegExp('[  ]'), ' ');

  group('VN with copies', () {
    testApp('"Have you exported your video?": the project, the size, the '
        'safe note, Not yet and Delete copies', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(
        dialogText(tester),
        contains(
          "Once the copies are deleted, the VN project for Goa can't be "
          'edited any more. This frees 600 MB.',
        ),
      );
      // The name is bold.
      final body = find.descendant(
        of: find.byType(TtDialog<bool>),
        matching: find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().startsWith('Once the copies'),
        ),
      );
      final spans = <TextSpan>[];
      tester.widget<RichText>(body).text.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      expect(
        spans.singleWhere((s) => s.text == 'Goa').style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        find.text('Your original clips are safe in your gallery.'),
        findsOneWidget,
      );
      expect(find.text('Not yet'), findsOneWidget);
      final delete = tester.widget<TtButton>(
        find.widgetWithText(TtButton, 'Delete copies'),
      );
      expect(delete.kind, TtButtonKind.danger);
    });

    testApp('a copy deleted outside TakeTray is not counted in the size, '
        'though the page never checked yet (T11-m3)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      // Only the first copy is still on the phone.
      final copies = (await editState(tester, goa.id))!.copies;
      h.editors
        ..allow({'existingCopies'})
        ..existing = {copies.first.copyMediaStoreId};
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(dialogText(tester), contains('This frees 300 MB.'));
      expect(dialogText(tester), isNot(contains('600 MB')));
    });

    testApp('when the check itself fails the dialog still asks, with the '
        'recorded size (T11-m3)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      h.editors
        ..allow({'existingCopies'})
        ..failNext('existingCopies');
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(dialogText(tester), contains('This frees 600 MB.'));
    });

    testApp('when every copy was deleted outside TakeTray the question is '
        'the no-copies one (T11-m3)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors
        ..allow({'existingCopies'})
        ..existing = {};
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Have you exported your video?'), findsNothing);
      expect(find.text('Done editing Goa?'), findsOneWidget);
    });

    testApp('Not yet deletes nothing and says nothing', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await pumpHost(tester, goa.id);
      await ask(tester);

      await tester.tap(find.text('Not yet'));
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(spy.calls, isEmpty);
      expect((await editState(tester, goa.id))!.copies, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testApp('Delete copies runs once on a double tap, says what it freed, '
        'and 0.9 s later offers Published, not before', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      h.editors.allow({'deleteCopies'});
      await pumpHost(tester, goa.id);
      await ask(tester);

      await tester.tap(find.text('Delete copies'));
      await tester.tap(find.text('Delete copies'), warnIfMissed: false);
      await tester.runAsync(settle);
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pump();

      expect(spy.calls, ['done ${goa.id}']);
      expect(h.editors.calls.where((c) => c == 'deleteCopies'), hasLength(1));
      expect(await editState(tester, goa.id), isNull);
      expect(find.text('Copies deleted · 600 MB freed'), findsOneWidget);

      await waitMs(tester, 700);
      expect(find.textContaining('Mark Goa'), findsNothing);

      await waitMs(tester, 300);
      await settleApp(tester);
      expect(find.text('Mark Goa as Published?'), findsOneWidget);
      expect(
        find.text(
          'It moves to the Published filter. You can change this any time.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Mark as Published'));
      await settleApp(tester);
      final reel = await real(tester, () => reels.getById(goa.id));
      expect(reel!.status, ReelStatus.published);
    });

    testApp('suggestPublished: false offers nothing', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors.allow({'deleteCopies'});
      await pumpHost(tester, goa.id, suggestPublished: false);
      await ask(tester);

      await confirm(tester, 'Delete copies');
      await flushOffer(tester);

      expect(find.textContaining('Copies deleted'), findsOneWidget);
      expect(find.textContaining('Mark Goa'), findsNothing);
    });

    testApp('a reel that is Published already is not asked', (tester) async {
      final (goa, ids) = await goaReel(tester, status: ReelStatus.published);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors.allow({'deleteCopies'});
      await pumpHost(tester, goa.id);
      await ask(tester);

      await confirm(tester, 'Delete copies');
      await flushOffer(tester);

      expect(find.textContaining('Mark Goa'), findsNothing);
    });

    testApp('copies that cannot be deleted: "Couldn\'t delete the copies. '
        'Try again.", the session stays, no offer; a retry works', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors
        ..allow({'deleteCopies'})
        ..failNext('deleteCopies');
      await pumpHost(tester, goa.id);
      await ask(tester);

      await confirm(tester, 'Delete copies');
      await flushOffer(tester);

      expect(
        find.text("Couldn't delete the copies. Try again."),
        findsOneWidget,
      );
      expect(find.textContaining('Copies deleted'), findsNothing);
      expect(find.textContaining('Mark Goa'), findsNothing);
      expect((await editState(tester, goa.id))!.copies, hasLength(1));

      await ask(tester);
      await confirm(tester, 'Delete copies');
      // The failure's snack makes way for the new one.
      await tester.pumpAndSettle();
      expect(find.textContaining('Copies deleted'), findsOneWidget);
      expect(await editState(tester, goa.id), isNull);
      await flushOffer(tester);
    });

    testApp('any other error says the same and keeps the session', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      spy.failDone = StateError('Copy job is not cleared yet');
      await pumpHost(tester, goa.id);
      await ask(tester);

      await confirm(tester, 'Delete copies');
      await flushOffer(tester);

      expect(
        find.text("Couldn't delete the copies. Try again."),
        findsOneWidget,
      );
      expect(await editState(tester, goa.id), isNotNull);
    });

    testApp('copies the guard left behind are told after the size', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors.allow({'deleteCopies'});
      spy.doneResult = const DoneEditingResult(
        editor: EditorApp.vn,
        freedBytes: 300 * 1000 * 1000,
        leftBehind: 2,
      );
      await pumpHost(tester, goa.id, suggestPublished: false);
      await ask(tester);

      await confirm(tester, 'Delete copies');

      expect(
        find.text(
          'Copies deleted · 300 MB freed. 2 files were changed outside '
          'TakeTray, so they were left in the folder.',
        ),
        findsOneWidget,
      );
      await flushOffer(tester);
    });
  });

  group('CapCut and Edits', () {
    testApp('CapCut with copies: the CapCut wording', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.capcut,
          sent: [ids[0]],
          copied: [ids[1]],
        ),
      );
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(
        dialogText(tester),
        contains(
          'Once the copies are deleted, clips you added to your CapCut '
          'project from the folder may show as missing. This frees 300 MB.',
        ),
      );
      expect(find.text('Delete copies'), findsOneWidget);
    });

    testApp('CapCut with no copies: "Done editing {name}?", Nothing is '
        'deleted, and "Done editing {name}" after', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.capcut, sent: ids),
      );
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Done editing Goa?'), findsOneWidget);
      expect(
        find.text(
          'TakeTray stops showing which clips are in your CapCut project. '
          'Nothing is deleted.',
        ),
        findsOneWidget,
      );
      expect(find.text('Not yet'), findsOneWidget);
      final done = tester.widget<TtButton>(
        find.widgetWithText(TtButton, 'Done editing'),
      );
      expect(done.kind, TtButtonKind.filled);

      await confirm(tester, 'Done editing');

      expect(find.text('Done editing Goa'), findsOneWidget);
      expect(await editState(tester, goa.id), isNull);
      expect(h.editors.calls, isEmpty);
      await waitMs(tester, 1000);
      await settleApp(tester);
      expect(find.text('Mark Goa as Published?'), findsOneWidget);
    });

    testApp('Edits is "Instagram Edits" in a dialog', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.edits, sent: ids),
      );
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(
        find.text(
          'TakeTray stops showing which clips are in your Instagram Edits '
          'project. Nothing is deleted.',
        ),
        findsOneWidget,
      );
    });

    testApp('a failure with no copies is "Something went wrong"', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.capcut, sent: ids),
      );
      spy.failDone = StateError('the write failed');
      await pumpHost(tester, goa.id);
      await ask(tester);

      await confirm(tester, 'Done editing');
      await flushOffer(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.textContaining('Mark Goa'), findsNothing);
      expect(await editState(tester, goa.id), isNotNull);
    });
  });

  group('when nothing is asked', () {
    testApp('a VN session with no copies left gets the no-copies question', (
      tester,
    ) async {
      final (goa, _) = await goaReel(tester);
      await real(tester, () => startEditing(h, goa.id, EditorApp.vn));
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.text('Done editing Goa?'), findsOneWidget);
      expect(
        find.text(
          'TakeTray stops showing which clips are in your VN project. '
          'Nothing is deleted.',
        ),
        findsOneWidget,
      );
    });

    testApp('a reel with no session shows nothing', (tester) async {
      final (goa, _) = await goaReel(tester);
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(spy.calls, isEmpty);
    });

    testApp('a reel whose copy job runs shows nothing', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await startVnJob(tester, h, goa, ids);
      await pumpHost(tester, goa.id);
      await ask(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(spy.calls, isEmpty);
      // The reel's page has its banner for it: no snack unless asked for.
      expect(find.byType(SnackBar), findsNothing);
    });

    testApp('a reel whose copy job runs: sayWhenCopying says why nothing '
        'opens (T13-M1b)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await startVnJob(tester, h, goa, ids);
      await pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => showDoneEditingDialog(
                context,
                ref,
                goa.id,
                sayWhenCopying: true,
              ),
              child: const Text('go'),
            ),
          ),
        ),
        overrides: [
          ...h.appOverrides,
          editSessionServiceProvider.overrideWithValue(spy),
        ],
        settle: false,
      );
      await settleApp(tester);
      await ask(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(
        find.text('Copying is still running. Try again when it finishes.'),
        findsOneWidget,
      );
    });

    testApp('asked twice at once: one dialog', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await pumpHost(tester, goa.id);

      final button = tester.widget<TextButton>(find.byType(TextButton));
      button.onPressed!();
      button.onPressed!();
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await settleApp(tester);

      // Closed: it can be asked again.
      await ask(tester);
      expect(find.byType(TtDialog<bool>), findsOneWidget);
    });
  });

  group('the look', () {
    for (final (scale, brightness) in [
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
    ]) {
      testApp('at ${scale}x ${brightness.name}: nothing cut, accessible', (
        tester,
      ) async {
        final (goa, ids) = await goaReel(tester, name: 'Goa food trip 2026');
        await real(
          tester,
          () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
        );
        await pumpHost(
          tester,
          goa.id,
          textScale: scale,
          brightness: brightness,
        );
        await ask(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Have you exported your video?'), findsOneWidget);
        await expectTtAccessible(tester);
      });
    }
  });

  testApp('the logs never name the reel', (tester) async {
    final logs = captureLogs();
    final (goa, ids) = await goaReel(tester, name: 'Secret Goa');
    await real(
      tester,
      () => startEditing(
        h,
        goa.id,
        EditorApp.vn,
        copied: [ids[0]],
        folder: 'Secret Goa',
      ),
    );
    h.editors
      ..allow({'deleteCopies'})
      ..failNext('deleteCopies');
    await pumpHost(tester, goa.id);
    await ask(tester);
    await confirm(tester, 'Delete copies');
    await flushOffer(tester);

    expect(logText(logs), isNot(contains('Secret')));
  });
}
