import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/views/edit_select_screen.dart';
import 'package:taketray/features/editors/views/editor_missing_dialog.dart';
import 'package:taketray/platform/editors_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import 'editors_support.dart';

final String _capcut = EditorApp.capcut.packageName;
final String _edits = EditorApp.edits.packageName;
final String _vn = EditorApp.vn.packageName;

void main() {
  late VmHarness h;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    h.editors
      ..allow({'apps'})
      ..installed = {_capcut: true, _edits: true, _vn: true};
  });

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  /// Reel "Goa" with two clips: the one with MediaStore id 1 was shot at
  /// 11:00 (400 MB), the one with id 2 at 09:00 (500 MB), so the shooting
  /// order is the reverse of the ids. Returns the reel and the clip ids
  /// `[a, b]` of videos 1 and 2.
  Future<(Reel, List<int>)> twoClips(
    WidgetTester tester, {
    ReelStatus status = ReelStatus.collecting,
  }) async {
    final goa = await real(tester, () => reels.create('Goa'));
    final ids = await real(
      tester,
      () => putInReel(h, goa.id, [
        sizedVideo(1, shot: DateTime.utc(2026, 10, 28, 11), size: 400000000),
        sizedVideo(2, shot: DateTime.utc(2026, 10, 28, 9), size: 500000000),
      ]),
    );
    if (status != ReelStatus.collecting) {
      await real(tester, () => reels.setStatus(goa.id, status));
    }
    return (goa, ids);
  }

  /// Opens the picking screen with [ids] ticked and taps Continue: the
  /// editor sheet is up.
  Future<void> openSheet(
    WidgetTester tester,
    Reel reel,
    List<int> ids, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      EditSelectScreen(reelId: reel.id, clipIds: ids),
      overrides: h.appOverrides,
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    await tester.tap(find.text('Continue'));
    await settleApp(tester);
  }

  /// The row titled [title], by the key the sheet gives it.
  Finder row(String title) => find.byKey(
    ValueKey<String>(switch (title) {
      'CapCut' => 'editor-row-capcut',
      'Instagram Edits' => 'editor-row-edits',
      'VN' => 'editor-row-vn',
      _ => 'editor-row-other',
    }),
  );

  Future<void> tapRow(WidgetTester tester, String title) async {
    await tester.tap(row(title));
    await settleApp(tester);
  }

  /// Lets the offer of "Mark as Ready to edit" (1.3 s after a send) run its
  /// course, so no timer is left pending when a test ends.
  Future<void> flushOffer(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1500));
    await settleApp(tester);
  }

  EditSessionsRepository sessions() =>
      h.container.read(editSessionsRepositoryProvider);

  group('the sheet', () {
    testApp('the title, the length, the four rows and what each does', (
      tester,
    ) async {
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, ids);

      expect(find.text('Edit 2 clips in…'), findsOneWidget);
      expect(find.text('0:08 · in shooting order'), findsOneWidget);
      for (final (title, sub) in [
        ('CapCut', 'Gets your original clips'),
        ('Instagram Edits', 'Gets your original clips'),
        ('VN', 'Makes temporary copies · 900\u00a0MB'),
        ('Other app…', "Opens Android's share menu"),
      ]) {
        final r = tester.widget<TtListRow>(row(title));
        expect(r.subtitle, sub, reason: title);
        expect(r.onTap, isNotNull, reason: title);
        expect(r.off, isFalse, reason: title);
      }
      // All three installed: no note.
      expect(find.text('Not installed'), findsNothing);
      expect(find.textContaining('greyed out'), findsNothing);
    });

    testApp('the title says one clip for one clip', (tester) async {
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, [ids[0]]);

      expect(find.text('Edit 1 clip in…'), findsOneWidget);
      expect(find.text('0:04 · in shooting order'), findsOneWidget);
      expect(
        tester.widget<TtListRow>(row('VN')).subtitle,
        'Makes temporary copies · 400\u00a0MB',
      );
    });

    testApp('an editor that is not installed is greyed out with Not '
        'installed, and a note says so; the others stay tappable', (
      tester,
    ) async {
      h.editors.installed = {_capcut: false, _edits: true, _vn: true};
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, ids);

      final capcut = tester.widget<TtListRow>(row('CapCut'));
      expect(capcut.off, isTrue);
      expect(capcut.onTap, isNull);
      expect(capcut.subtitle, 'Not installed');
      expect(capcut.semanticLabel, 'CapCut, not installed');
      expect(tester.widget<TtListRow>(row('VN')).onTap, isNotNull);
      expect(tester.widget<TtListRow>(row('Instagram Edits')).onTap, isNotNull);
      expect(
        find.text("Editors you don't have are greyed out."),
        findsOneWidget,
      );

      // Other app… is never greyed out.
      expect(tester.widget<TtListRow>(row('Other app…')).onTap, isNotNull);
    });

    testApp('each of the three editors alone greys out its own row', (
      tester,
    ) async {
      h.editors.installed = {_capcut: true, _edits: false, _vn: false};
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, ids);

      expect(tester.widget<TtListRow>(row('CapCut')).off, isFalse);
      expect(tester.widget<TtListRow>(row('Instagram Edits')).off, isTrue);
      expect(tester.widget<TtListRow>(row('VN')).off, isTrue);
      expect(find.text('Not installed'), findsNWidgets(2));
    });

    testApp('a greyed-out row does nothing when tapped', (tester) async {
      h.editors.installed = {_capcut: false, _edits: true, _vn: true};
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tester.tap(row('CapCut'));
      await settleApp(tester);

      expect(find.text('Edit 2 clips in…'), findsOneWidget);
      expect(h.editors.sent, isEmpty);
      expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
    });

    testApp('when asking the phone fails, all three rows work and say '
        'nothing about being installed (the share decides)', (tester) async {
      h.editors.failNext('apps');
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, ids);

      for (final title in ['CapCut', 'Instagram Edits', 'VN', 'Other app…']) {
        final r = tester.widget<TtListRow>(row(title));
        expect(r.off, isFalse, reason: title);
        expect(r.onTap, isNotNull, reason: title);
      }
      expect(find.text('Not installed'), findsNothing);
      expect(find.textContaining('greyed out'), findsNothing);
    });

    testApp('coming back to the app (after the Play Store) asks the phone '
        'again: a row that was greyed out works once it is installed '
        '(T9-m4)', (tester) async {
      h.editors.installed = {_capcut: false, _edits: true, _vn: true};
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);
      expect(tester.widget<TtListRow>(row('CapCut')).off, isTrue);
      final asks = h.editors.calls.where((c) => c == 'apps').length;

      // The user installs CapCut and comes back.
      h.editors.installed = {_capcut: true, _edits: true, _vn: true};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settleApp(tester);
      expect(
        h.editors.calls.where((c) => c == 'apps').length,
        asks,
        reason: 'going away asks nothing',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(h.editors.calls.where((c) => c == 'apps').length, asks + 1);
      final capcut = tester.widget<TtListRow>(row('CapCut'));
      expect(capcut.off, isFalse);
      expect(capcut.onTap, isNotNull);
      expect(find.text('Not installed'), findsNothing);
    });

    testApp('an installed editor shows its icon; one without shows a '
        'letters tile', (tester) async {
      h.editors.icons = {
        _capcut: Uint8List.fromList([1, 2, 3]),
      };
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, ids);

      final icons = tester
          .widgetList<TtAppIcon>(find.byType(TtAppIcon))
          .toList();
      expect([for (final i in icons) i.fallbackLetters], ['C', 'E', 'VN']);
      expect(icons[0].png, isNotNull);
      expect(icons[1].png, isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testApp('${scale}x text: nothing overflows, accessible', (tester) async {
        h.editors.installed = {_capcut: false, _edits: true, _vn: true};
        final (goa, ids) = await twoClips(tester);

        await openSheet(tester, goa, ids, textScale: scale);

        expect(find.text('Edit 2 clips in…'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester, includeDisabledText: true);
      });
    }

    testApp('dark: accessible', (tester) async {
      h.editors.installed = {_capcut: false, _edits: true, _vn: true};
      final (goa, ids) = await twoClips(tester);

      await openSheet(tester, goa, ids, brightness: Brightness.dark);

      expect(find.text('Edit 2 clips in…'), findsOneWidget);
      await expectTtAccessible(tester, includeDisabledText: true);
    });
  });

  group('Continue (T9-m5)', () {
    testApp('two taps before the phone has answered open one sheet', (
      tester,
    ) async {
      h.editors.hold('apps');
      final (goa, ids) = await twoClips(tester);
      await pumpScreen(
        tester,
        EditSelectScreen(reelId: goa.id, clipIds: ids),
        overrides: h.appOverrides,
        settle: false,
      );
      await settleApp(tester);

      final button = find.widgetWithText(TtButton, 'Continue');
      final onPressed = tester.widget<TtButton>(button).onPressed!;
      // Two taps, back to back: the second arrives while the first is still
      // opening the sheet.
      onPressed();
      onPressed();
      await tester.pump();
      h.editors.release('apps');
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
      // Closing it leaves the picking screen alone, with no second sheet.
      await tester.tapAt(const Offset(180, 20));
      await settleApp(tester);
      expect(find.byType(TtSheet), findsNothing);
      expect(find.byType(EditSelectScreen), findsOneWidget);
    });

    testApp('after the sheet closes, Continue opens it again', (tester) async {
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);
      await tester.tapAt(const Offset(180, 20));
      await settleApp(tester);
      expect(find.byType(TtSheet), findsNothing);

      await tester.tap(find.text('Continue'));
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
    });
  });

  group('CapCut and Instagram Edits', () {
    // A send asks for the folders already taken, then shares.
    setUp(() => h.editors.allow({'sendTo', 'copyFolderNames'}));

    for (final (title, name, package) in [
      ('CapCut', 'CapCut', _capcut),
      ('Instagram Edits', 'Instagram Edits', _edits),
    ]) {
      testApp('$title: the originals go in one share, in shooting order; '
          'back to the reel with a snack', (tester) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, title);

        // One share, to the editor's package, in shooting order (the clip
        // shot at 09:00 has MediaStore id 2).
        expect(h.editors.sent, hasLength(1));
        expect(h.editors.sent.single.$1, package);
        expect(
          [for (final c in h.editors.sent.single.$2) c.mediaStoreId],
          [2, 1],
        );
        // Back on the reel's page, the sheet and the picking screen gone.
        expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
        expect(find.byType(EditSelectScreen), findsNothing);
        expect(find.byType(TtSheet), findsNothing);
        expect(find.text('Sent 2 clips to $name'), findsOneWidget);
        // The session and the sent clips were recorded before the share.
        final state = await real(tester, () => sessions().editState(goa.id));
        expect(
          state!.session.editor.name,
          title == 'CapCut' ? 'capcut' : 'edits',
        );
        expect(state.sentIds, ids.toSet());
        // Nothing else of the dialog yet.
        expect(find.textContaining('Mark Goa'), findsNothing);
        await flushOffer(tester);
      });
    }

    testApp('the Sent snack has the open-in-new icon, as the prototype, '
        'not the check mark (T9-m1)', (tester) async {
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tapRow(tester, 'CapCut');

      final snack = find.ancestor(
        of: find.text('Sent 2 clips to CapCut'),
        matching: find.byType(TtSnack),
      );
      expect(snack, findsOneWidget);
      expect(
        find.descendant(
          of: snack,
          matching: find.byIcon(Symbols.open_in_new_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: snack,
          matching: find.byIcon(Symbols.check_circle_rounded),
        ),
        findsNothing,
      );
      await flushOffer(tester);
    });

    testApp('one clip: "Sent 1 clip to CapCut"', (tester) async {
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, [ids[1]]);

      await tapRow(tester, 'CapCut');

      expect(find.text('Sent 1 clip to CapCut'), findsOneWidget);
      await flushOffer(tester);
    });

    testApp('a second tap on the same editor while it opens shares once, '
        'and leaves once', (tester) async {
      h.editors.hold('sendTo');
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tester.tap(row('CapCut'));
      await tester.runAsync(settle);
      await tester.tap(row('CapCut'), warnIfMissed: false);
      await tester.runAsync(settle);
      h.editors.release('sendTo');
      await settleApp(tester);

      expect(h.editors.sent, hasLength(1));
      expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      await flushOffer(tester);
    });

    testApp('a tap on another editor while one opens does nothing', (
      tester,
    ) async {
      h.editors.hold('sendTo');
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tester.tap(row('CapCut'));
      await tester.runAsync(settle);
      await tester.tap(row('Instagram Edits'), warnIfMissed: false);
      await tester.runAsync(settle);
      h.editors.release('sendTo');
      await settleApp(tester);

      expect(h.editors.sent, hasLength(1));
      expect(h.editors.sent.single.$1, _capcut);
      expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
      expect(find.textContaining('Instagram Edits'), findsNothing);
      await flushOffer(tester);
    });

    testApp('the sheet cannot be dragged away while a send runs', (
      tester,
    ) async {
      h.editors.hold('sendTo');
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);
      await tester.tap(row('CapCut'));
      await tester.runAsync(settle);
      await tester.pump();

      // The system Back key does not close it while the send runs.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Edit 2 clips in…'), findsOneWidget);

      h.editors.release('sendTo');
      await settleApp(tester);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      await flushOffer(tester);
    });

    group('the Ready to edit offer', () {
      testApp('a Collecting reel: 1.3 s after the send, not before', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        // No settling here: it would move the clock on while a snack
        // animates, and this test counts the time.
        await tester.tap(row('CapCut'));
        await tester.runAsync(settle);
        await tester.pump();
        expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);

        Future<void> waitMs(int ms) async {
          for (var gone = 0; gone < ms; gone += 100) {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(settle);
          }
        }

        await waitMs(1100);
        expect(find.textContaining('Mark Goa'), findsNothing);

        await waitMs(400);
        await settleApp(tester);
        expect(find.text('Mark Goa as Ready to edit?'), findsOneWidget);
        expect(
          find.text(
            'Helps you find it under Ready to edit. You can change this any '
            'time.',
          ),
          findsOneWidget,
        );
      });

      for (final status in [ReelStatus.ready, ReelStatus.published]) {
        testApp('a ${status.name} reel gets no offer', (tester) async {
          final (goa, ids) = await twoClips(tester, status: status);
          await openSheet(tester, goa, ids);
          await tapRow(tester, 'Instagram Edits');

          await tester.pump(const Duration(milliseconds: 1500));
          await settleApp(tester);

          expect(find.textContaining('Mark Goa'), findsNothing);
          expect(find.text('Sent 2 clips to Instagram Edits'), findsOneWidget);
        });
      }

      testApp('Mark as Ready to edit sets the status and says so', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');
        await tester.pump(const Duration(milliseconds: 1400));
        await settleApp(tester);

        await tester.tap(find.text('Mark as Ready to edit'));
        await settleApp(tester);

        expect(
          (await real(tester, () => reels.getById(goa.id)))!.status,
          ReelStatus.ready,
        );
        expect(find.text('Marked as Ready to edit'), findsOneWidget);
        expect(find.textContaining('Mark Goa'), findsNothing);
      });

      testApp('Not now changes nothing', (tester) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');
        await tester.pump(const Duration(milliseconds: 1400));
        await settleApp(tester);

        await tester.tap(find.text('Not now'));
        await settleApp(tester);

        expect(
          (await real(tester, () => reels.getById(goa.id)))!.status,
          ReelStatus.collecting,
        );
        expect(find.textContaining('Mark Goa'), findsNothing);
        expect(find.text('Marked as Ready to edit'), findsNothing);
      });

      testApp('a reel whose status changed during the wait gets no offer', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');

        await real(tester, () => reels.setStatus(goa.id, ReelStatus.ready));
        await tester.pump(const Duration(milliseconds: 1400));
        await settleApp(tester);

        expect(find.textContaining('Mark Goa'), findsNothing);
      });

      testApp('a reel deleted during the wait gets no offer and no error', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');

        await real(tester, () => reels.delete(goa.id));
        await tester.pump(const Duration(milliseconds: 1400));
        await settleApp(tester);

        expect(find.textContaining('Mark '), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('not installed', () {
      testApp('the editor is not installed after all: the dialog, with no '
          'session left behind', (tester) async {
        h.editors.sendResult = SendResult.notInstalled;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'CapCut');

        expect(find.text("CapCut isn't installed"), findsOneWidget);
        expect(
          find.text(
            'Install CapCut from the Play Store, or choose another editor.',
          ),
          findsOneWidget,
        );
        expect(find.text('Choose another'), findsOneWidget);
        expect(find.text('Open Play Store'), findsOneWidget);
        // The sheet and the picking screen are still there.
        expect(find.text('Edit 2 clips in…'), findsOneWidget);
        expect(find.textContaining('Sent'), findsNothing);
        expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
      });

      testApp('Instagram Edits is called by its full name', (tester) async {
        h.editors.sendResult = SendResult.notInstalled;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'Instagram Edits');

        expect(find.text("Instagram Edits isn't installed"), findsOneWidget);
      });

      testApp("Open Play Store opens the editor's listing", (tester) async {
        h.editors
          ..allow({'openStoreListing'})
          ..sendResult = SendResult.notInstalled;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');

        await tester.tap(find.text('Open Play Store'));
        await settleApp(tester);

        expect(h.editors.openedListings, [_capcut]);
        expect(find.text("CapCut isn't installed"), findsNothing);
      });

      testApp('Open Play Store with no store to open shows nothing more', (
        tester,
      ) async {
        h.editors
          ..allow({'openStoreListing'})
          ..sendResult = SendResult.notInstalled
          ..storeResult = false;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');

        await tester.tap(find.text('Open Play Store'));
        await settleApp(tester);

        expect(h.editors.openedListings, [_capcut]);
        expect(find.byType(TtSnack), findsNothing);
        expect(find.text("CapCut isn't installed"), findsNothing);
        expect(find.text('Edit 2 clips in…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testApp('Open Play Store that throws shows nothing more either', (
        tester,
      ) async {
        h.editors
          ..allow({'openStoreListing'})
          ..sendResult = SendResult.notInstalled
          ..failNext('openStoreListing');
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');

        await tester.tap(find.text('Open Play Store'));
        await settleApp(tester);

        expect(find.byType(TtSnack), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testApp('Choose another closes the dialog, keeps the sheet and asks '
          'the phone again', (tester) async {
        h.editors.sendResult = SendResult.notInstalled;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await tapRow(tester, 'CapCut');
        // Now the phone says so too.
        h.editors.installed = {_capcut: false, _edits: true, _vn: true};

        await tester.tap(find.text('Choose another'));
        await settleApp(tester);

        expect(find.text("CapCut isn't installed"), findsNothing);
        expect(find.text('Edit 2 clips in…'), findsOneWidget);
        expect(tester.widget<TtListRow>(row('CapCut')).off, isTrue);
        expect(h.editors.openedListings, isEmpty);
      });
    });

    testApp('after Not installed and Choose another, the rows work again: a '
        'send to another editor goes through', (tester) async {
      h.editors.sendResult = SendResult.notInstalled;
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);
      await tapRow(tester, 'CapCut');
      await tester.tap(find.text('Choose another'));
      await settleApp(tester);
      expect(find.text('Edit 2 clips in…'), findsOneWidget);

      h.editors.sendResult = SendResult.sent;
      await tapRow(tester, 'Instagram Edits');

      expect(h.editors.sent.map((s) => s.$1), [_capcut, _edits]);
      expect(find.text('Sent 2 clips to Instagram Edits'), findsOneWidget);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      await flushOffer(tester);
    });

    group('failed', () {
      testApp('the editor did not open: a line in the sheet, the sheet and '
          'the screen stay, and nothing is left behind', (tester) async {
        h.editors.sendResult = SendResult.failed;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'CapCut');

        expect(find.text("Couldn't open CapCut. Try again."), findsOneWidget);
        expect(find.text('Edit 2 clips in…'), findsOneWidget);
        expect(find.byType(EditSelectScreen), findsOneWidget);
        expect(find.textContaining('Sent'), findsNothing);
        expect(find.textContaining('Mark Goa'), findsNothing);
        expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
      });

      testApp('a share that throws says the same, and a retry can work', (
        tester,
      ) async {
        h.editors.failNext('sendTo');
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'Instagram Edits');
        expect(
          find.text("Couldn't open Instagram Edits. Try again."),
          findsOneWidget,
        );

        await tapRow(tester, 'Instagram Edits');

        expect(find.textContaining("Couldn't open"), findsNothing);
        expect(find.text('Sent 2 clips to Instagram Edits'), findsOneWidget);
        // The attempt that threw is not recorded by the fake.
        expect(h.editors.sent, hasLength(1));
        await flushOffer(tester);
      });

      testApp('every clip gone meanwhile: the send fails calmly', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await real(tester, () => flagForTest(h, ids.toSet(), missing: true));

        await tapRow(tester, 'CapCut');

        // Nothing was written or shared (the service drops missing clips).
        // Retrying cannot work, so the line says what is wrong (T9-m7).
        expect(h.editors.sent, isEmpty);
        expect(
          find.text('These clips are missing from your phone.'),
          findsOneWidget,
        );
        expect(find.textContaining("Couldn't open"), findsNothing);
        expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
      });

      testApp('a share that fails while the clips are still there says '
          "Couldn't open, not missing (T9-m7)", (tester) async {
        h.editors.sendResult = SendResult.failed;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'CapCut');

        expect(find.text("Couldn't open CapCut. Try again."), findsOneWidget);
        expect(find.textContaining('missing from your phone'), findsNothing);
      });

      testApp('one clip missing and the share fails: Couldn\'t open (a clip '
          'is still there, T9-m7)', (tester) async {
        h.editors.sendResult = SendResult.failed;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await real(tester, () => flagForTest(h, {ids[0]}, missing: true));

        await tapRow(tester, 'CapCut');

        expect(find.text("Couldn't open CapCut. Try again."), findsOneWidget);
      });

      testApp('a clip that went missing is left out of the share', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);
        await real(tester, () => flagForTest(h, {ids[0]}, missing: true));

        await tapRow(tester, 'CapCut');

        expect([for (final c in h.editors.sent.single.$2) c.mediaStoreId], [2]);
        expect(find.text('Sent 1 clip to CapCut'), findsOneWidget);
        await flushOffer(tester);
      });
    });
  });

  group('VN', () {
    testApp('goes to the space check with the clips in shooting order, and '
        'copies nothing yet', (tester) async {
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tapRow(tester, 'VN');

      // Video 2 (09:00) first: its clip id is ids[1].
      expect(
        find.text(copySpaceRouteMarker(goa.id, 'vn', '${ids[1]},${ids[0]}')),
        findsOneWidget,
      );
      expect(find.byType(TtSheet), findsNothing);
      expect(h.editors.sent, isEmpty);
      expect(h.editors.chooserShares, isEmpty);
      expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
    });

    testApp('a double tap pushes one route', (tester) async {
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tester.tap(row('VN'));
      await tester.tap(row('VN'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.textContaining('the space check of reel'), findsOneWidget);
      // Back from it lands on the picking screen, not on another space check.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('the space check of reel'), findsNothing);
    });
  });

  group('Other app…', () {
    testApp("opens Android's share menu with no session and no dialog", (
      tester,
    ) async {
      h.editors.allow({'shareWithChooser'});
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tapRow(tester, 'Other app…');

      expect(h.editors.chooserShares, hasLength(1));
      final (clips, title) = h.editors.chooserShares.single;
      expect(title, 'Share 2 videos');
      expect([for (final c in clips) c.mediaStoreId], [2, 1]);
      expect(h.editors.sent, isEmpty);
      expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
      // The sheet is closed; the picking screen stays; no status question.
      expect(find.byType(TtSheet), findsNothing);
      expect(find.byType(EditSelectScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await settleApp(tester);
      expect(find.textContaining('Mark Goa'), findsNothing);
      expect(find.byType(TtSnack), findsNothing);
    });

    testApp('one clip: the title says Share video', (tester) async {
      h.editors.allow({'shareWithChooser'});
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, [ids[0]]);

      await tapRow(tester, 'Other app…');

      expect(h.editors.chooserShares.single.$2, 'Share video');
    });

    testApp('a double tap shares once', (tester) async {
      h.editors.allow({'shareWithChooser'});
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);

      await tester.tap(row('Other app…'));
      await tester.tap(row('Other app…'), warnIfMissed: false);
      await settleApp(tester);

      expect(h.editors.chooserShares, hasLength(1));
      // The second tap did not pop the picking screen under the sheet.
      expect(find.byType(EditSelectScreen), findsOneWidget);
    });

    testApp('every clip gone meanwhile: the missing snack, no share', (
      tester,
    ) async {
      h.editors.allow({'shareWithChooser'});
      final (goa, ids) = await twoClips(tester);
      await openSheet(tester, goa, ids);
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));

      await tapRow(tester, 'Other app…');

      expect(h.editors.chooserShares, isEmpty);
      expect(
        find.text('These clips are missing from your phone.'),
        findsOneWidget,
      );
    });
  });

  group('the editor is missing dialog', () {
    Future<void> openDialog(WidgetTester tester, EditorApp editor) async {
      await pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => showEditorMissingDialog(context, editor),
              child: const Text('go'),
            ),
          ),
        ),
        overrides: h.appOverrides,
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    for (final (editor, name) in [
      (EditorApp.capcut, 'CapCut'),
      (EditorApp.edits, 'Instagram Edits'),
      (EditorApp.vn, 'VN'),
    ]) {
      testApp('$name: the words and the two buttons', (tester) async {
        await openDialog(tester, editor);

        expect(find.text("$name isn't installed"), findsOneWidget);
        expect(
          find.text(
            'Install $name from the Play Store, or choose another editor.',
          ),
          findsOneWidget,
        );
        expect(find.text('Choose another'), findsOneWidget);
        expect(find.text('Open Play Store'), findsOneWidget);
      });
    }

    testApp("Open Play Store opens that editor's listing and closes", (
      tester,
    ) async {
      h.editors.allow({'openStoreListing'});
      await openDialog(tester, EditorApp.vn);

      await tester.tap(find.text('Open Play Store'));
      await tester.pumpAndSettle();

      expect(h.editors.openedListings, [_vn]);
      expect(find.textContaining("isn't installed"), findsNothing);
    });

    testApp('Choose another only closes it', (tester) async {
      await openDialog(tester, EditorApp.vn);

      await tester.tap(find.text('Choose another'));
      await tester.pumpAndSettle();

      expect(h.editors.openedListings, isEmpty);
      expect(find.textContaining("isn't installed"), findsNothing);
    });
  });
}
