import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

/// Manual mode (Phase 7, Task 6, D-111, D-115): without full access Add videos
/// opens a sheet that sends the user to Android's photo picker.
void main() {
  late AddHarness a;

  setUp(() => a = AddHarness());

  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Finder snackContaining(String text) => find.descendant(
    of: find.byType(SnackBar),
    matching: find.textContaining(text),
  );

  Finder sheetButton(String label) =>
      find.descendant(of: find.byType(TtSheet), matching: find.text(label));

  /// Sets the phone's access to [level].
  void access(MediaAccessLevel level) => a.bridge.access = MediaAccess(
    level: level,
    canAskAgain: true,
    sdkInt: 34,
  );

  /// Opens Add videos from the host page with the access [level], and leaves
  /// the sheet (or the browser) open.
  Future<void> openWith(
    WidgetTester tester, {
    MediaAccessLevel level = MediaAccessLevel.limited,
    AddTarget target = const AddToToTag(),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    access(level);
    await a.pumpOrigin(
      tester,
      target,
      textScale: textScale,
      brightness: brightness,
    );
    await openBrowser(tester);
  }

  Future<void> tapPicker(WidgetTester tester) =>
      tapAndSettle(tester, sheetButton('Open photo picker'));

  /// The addresses of the clips in To tag.
  Future<List<String?>> pendingUris(WidgetTester tester) async => [
    for (final c in (await tester.runAsync(a.h.media.toTag))!) c.pickerUri,
  ];

  group('openAddVideos picks the screen by access', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testApp('${level.name}: the Manual mode sheet opens, not the browser', (
        tester,
      ) async {
        await openWith(tester, level: level);

        expect(find.byType(TtSheet), findsOneWidget);
        expect(find.text('Pick videos yourself'), findsOneWidget);
        expect(find.byType(AddFoldersScreen), findsNothing);
      });
    }

    testApp('full: the folder browser opens, not the sheet', (tester) async {
      a.bridge.putFolder(whatsAppFolder, [folderVideo(1, addNow)]);
      await openWith(tester, level: MediaAccessLevel.full);

      expect(find.byType(AddFoldersScreen), findsOneWidget);
      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Pick videos yourself'), findsNothing);
    });

    testApp('a failed access read opens the sheet (the picker needs no '
        'permission)', (tester) async {
      await a.pumpOrigin(tester, const AddToToTag());
      a.bridge.failNext('accessReport');

      await openBrowser(tester);

      expect(find.text('Pick videos yourself'), findsOneWidget);
      expect(find.byType(AddFoldersScreen), findsNothing);
    });
  });

  group('the sheet', () {
    testApp('says what it does, with the callout and both buttons', (
      tester,
    ) async {
      await openWith(tester);

      expect(find.text('Pick videos yourself'), findsOneWidget);
      expect(
        find.text(
          'TakeTray can see only some of your videos (Manual mode), so it '
          "opens Android's photo picker.",
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TtCallout),
          matching: find.text(
            "The photo picker doesn't show folder counts, and it can't mark "
            "videos you've already added.",
          ),
        ),
        findsOneWidget,
      );
      expect(sheetButton('Open photo picker'), findsOneWidget);
      expect(sheetButton('Allow full access instead'), findsOneWidget);
    });

    testApp('the title is a header and the buttons are 48 dp tall', (
      tester,
    ) async {
      await openWith(tester);

      expect(
        tester.getSemantics(find.text('Pick videos yourself')),
        matchesSemantics(isHeader: true, label: 'Pick videos yourself'),
      );
      for (final label in ['Open photo picker', 'Allow full access instead']) {
        final button = find.ancestor(
          of: sheetButton(label),
          matching: find.byType(TtButton),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
    });

    testApp('Open photo picker opens the picker once and adds what was '
        'picked: the snack has Undo', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1), pickedVideo(2)];

      await tapPicker(tester);

      expect(a.bridge.calls.where((c) => c == 'pickVideos'), hasLength(1));
      expect(find.byType(TtSheet), findsNothing);
      expect(snack('2 videos added to To tag'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect((await pendingUris(tester)).toSet(), {
        pickedVideo(1).uri,
        pickedVideo(2).uri,
      });
      expect(a.service.pickedAdds, hasLength(1));
    });

    testApp('to a reel: the snack names the reel', (tester) async {
      final goa = await a.makeReel(tester, 'Goa');
      await openWith(tester, target: AddToReel(goa.id));
      a.bridge.picked = [pickedVideo(1)];

      await tapPicker(tester);

      expect(snack('1 video added to Goa'), findsOneWidget);
    });

    testApp('Undo takes the picked videos back out', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1), pickedVideo(2)];
      await tapPicker(tester);

      await tapAndSettle(tester, find.text('Undo'));

      expect(await pendingUris(tester), isEmpty);
    });

    testApp('cancel: nothing changes and no snack', (tester) async {
      await openWith(tester);
      a.bridge.picked = [];

      await tapPicker(tester);

      expect(a.bridge.calls.where((c) => c == 'pickVideos'), hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
      expect(await pendingUris(tester), isEmpty);
      expect(a.service.pickedAdds, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testApp('every video was already added: "Already added", no Undo', (
      tester,
    ) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1)];
      await tapPicker(tester);
      await openBrowser(tester);

      await tapPicker(tester);

      expect(snack('Already added'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(await pendingUris(tester), [pickedVideo(1).uri]);
    });

    testApp('some not kept: "Couldn\'t add 2 videos." is shown beside what '
        'was added, and Undo is still there', (tester) async {
      await openWith(tester);
      a.bridge.picked = [
        pickedVideo(1),
        pickedVideo(2, persisted: false),
        pickedVideo(3, persisted: false),
      ];

      await tapPicker(tester);

      expect(snackContaining('1 video added to To tag'), findsOneWidget);
      expect(snackContaining("Couldn't add 2 videos."), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(await pendingUris(tester), [pickedVideo(1).uri]);
    });

    testApp('one not kept says "Couldn\'t add 1 video."', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1), pickedVideo(2, persisted: false)];

      await tapPicker(tester);

      expect(snackContaining("Couldn't add 1 video."), findsOneWidget);
      expect(snackContaining("Couldn't add 1 videos"), findsNothing);
    });

    testApp('none kept: only "Couldn\'t add 2 videos.", no Undo and not '
        '"Already added"', (tester) async {
      await openWith(tester);
      a.bridge.picked = [
        pickedVideo(1, persisted: false),
        pickedVideo(2, persisted: false),
      ];

      await tapPicker(tester);

      expect(snackContaining("Couldn't add 2 videos."), findsOneWidget);
      expect(find.textContaining('Already added'), findsNothing);
      expect(snackContaining('added to'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(await pendingUris(tester), isEmpty);
    });

    testApp('already there and some not kept: both are said', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1)];
      await tapPicker(tester);
      await openBrowser(tester);
      a.bridge.picked = [pickedVideo(1), pickedVideo(2, persisted: false)];

      await tapPicker(tester);

      expect(snackContaining('Already added'), findsOneWidget);
      expect(snackContaining("Couldn't add 1 video."), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testApp('a double tap opens the picker once', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1)];
      final gate = a.bridge.gate('pickVideos');

      await tester.tap(sheetButton('Open photo picker'));
      await tester.tap(sheetButton('Open photo picker'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(sheetButton('Open photo picker'));
      await tester.pump();
      gate.complete();
      await settleApp(tester);

      expect(a.bridge.calls.where((c) => c == 'pickVideos'), hasLength(1));
      expect(a.service.pickedAdds, hasLength(1));
      expect(await pendingUris(tester), [pickedVideo(1).uri]);
    });

    testApp('while the picker is open the sheet buttons are off', (
      tester,
    ) async {
      await openWith(tester);
      final gate = a.bridge.gate('pickVideos');

      await tester.tap(sheetButton('Open photo picker'));
      await tester.pump();

      final buttons = tester.widgetList<TtButton>(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.byType(TtButton),
        ),
      );
      expect(buttons.map((b) => b.onPressed), everyElement(isNull));

      gate.complete();
      await settleApp(tester);
    });

    testApp('the picker answers busy: nothing is said, nothing added, and '
        'the sheet can try again', (tester) async {
      await openWith(tester);
      a.bridge.pickerBusy = true;

      await tapPicker(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(a.service.pickedAdds, isEmpty);

      a.bridge
        ..pickerBusy = false
        ..picked = [pickedVideo(1)];
      await tapPicker(tester);

      expect(snack('1 video added to To tag'), findsOneWidget);
    });

    testApp('the picker fails: "Couldn\'t add videos. Try again."', (
      tester,
    ) async {
      await openWith(tester);
      a.bridge.failNext('pickVideos');

      await tapPicker(tester);

      expect(snack("Couldn't add videos. Try again."), findsOneWidget);
      expect(find.byType(TtSheet), findsNothing);
      expect(a.service.pickedAdds, isEmpty);
      expect(await pendingUris(tester), isEmpty);
    });

    testApp('the add fails: "Couldn\'t add videos. Try again.", nothing is '
        'added, and a second try works', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1)];
      a.service.failNextPicked = true;

      await tapPicker(tester);

      expect(snack("Couldn't add videos. Try again."), findsOneWidget);
      expect(await pendingUris(tester), isEmpty);

      await openBrowser(tester);
      await tapPicker(tester);

      expect(snack('1 video added to To tag'), findsOneWidget);
    });

    testApp('the reel was deleted meanwhile: the add fails calmly', (
      tester,
    ) async {
      final goa = await a.makeReel(tester, 'Goa');
      await openWith(tester, target: AddToReel(goa.id));
      a.bridge.picked = [pickedVideo(1)];
      final gate = a.bridge.gate('pickVideos');
      await tester.tap(sheetButton('Open photo picker'));
      await tester.pump();
      await tester.runAsync(
        () => a.h.container.read(reelsRepositoryProvider).delete(goa.id),
      );
      gate.complete();
      await settleApp(tester);

      expect(snack("Couldn't add videos. Try again."), findsOneWidget);
      expect(await tester.runAsync(a.h.media.allClips), isEmpty);
    });

    testApp('Allow full access instead asks for access and closes the '
        'sheet, picking nothing', (tester) async {
      await openWith(tester);

      await tapAndSettle(tester, sheetButton('Allow full access instead'));

      expect(a.fakeAccess.allowed, 1);
      expect(find.byType(TtSheet), findsNothing);
      expect(a.bridge.calls.where((c) => c == 'pickVideos'), isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testApp('closing the sheet while the picker is open still adds what was '
        'picked, and says so', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1)];
      final gate = a.bridge.gate('pickVideos');
      await tester.tap(sheetButton('Open photo picker'));
      await tester.pump();

      Navigator.of(
        tester.element(find.byType(TtSheet)),
        rootNavigator: true,
      ).pop();
      await settleApp(tester);
      expect(find.byType(TtSheet), findsNothing);
      gate.complete();
      await settleApp(tester);

      expect(snack('1 video added to To tag'), findsOneWidget);
      expect(await pendingUris(tester), [pickedVideo(1).uri]);
      expect(tester.takeException(), isNull);
    });

    testApp('a pick followed by an add never runs the grant clean-up in '
        'between (nor after)', (tester) async {
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1), pickedVideo(2)];
      final gate = a.bridge.gate('pickVideos');
      await tester.tap(sheetButton('Open photo picker'));
      await tester.pump();

      void expectNoSweep() {
        expect(a.bridge.calls, isNot(contains('persistedUris')));
        expect(a.bridge.calls, isNot(contains('releaseUris')));
        expect(a.bridge.released, isEmpty);
      }

      expectNoSweep();
      gate.complete();
      await settleApp(tester);

      expect(a.service.pickedAdds, hasLength(1));
      expectNoSweep();
      // The grants the pick took are still held.
      expect(a.bridge.persisted, {pickedVideo(1).uri, pickedVideo(2).uri});
    });

    testApp('logs: counts and error types only, never an address or a name '
        '(D-10)', (tester) async {
      final records = captureLogs();
      await openWith(tester);
      a.bridge.picked = [pickedVideo(1), pickedVideo(2, persisted: false)];
      await tapPicker(tester);
      await openBrowser(tester);
      a.bridge.failNext('pickVideos');
      await tapPicker(tester);

      final text = logText(records);
      expect(text, isNot(contains('content://')));
      expect(text, isNot(contains('PICKED')));
      expect(text, isNot(contains('photopicker')));
    });

    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testApp('meets the accessibility guidelines at text ${scale}x, '
            '${brightness.name}', (tester) async {
          await openWith(tester, textScale: scale, brightness: brightness);

          expect(find.byType(TtSheet), findsOneWidget);
          await expectTtAccessible(tester);
        });
      }
    }
  });
}
