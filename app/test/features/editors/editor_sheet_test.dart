import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/view_models/editor_choices.dart';
import 'package:taketray/features/editors/views/edit_select_screen.dart';
import 'package:taketray/features/editors/views/editor_missing_dialog.dart';
import 'package:taketray/features/editors/views/editor_sheet.dart';
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

/// What the host page of these tests shows: it stays while the sheet comes
/// and goes, and after a send.
const String _hostMarker = 'the host page';

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

  /// What each sheet this test opened ended with, in order.
  late List<EditorSheetOutcome> outcomes;

  setUp(() => outcomes = []);

  /// Opens the editor sheet for [ids] from a plain host page (a button that
  /// calls `showEditorSheet`, as the reel page does), not through the
  /// picking screen. With [allClips] the sheet is the whole reel's.
  Future<void> openSheet(
    WidgetTester tester,
    Reel reel,
    List<int> ids, {
    bool allClips = false,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    List<Override> extraOverrides = const [],
  }) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text(_hostMarker),
              TextButton(
                onPressed: () async => outcomes.add(
                  await showEditorSheet(
                    context,
                    reelId: reel.id,
                    clipIds: ids,
                    allClips: allClips,
                  ),
                ),
                child: const Text('Open the sheet'),
              ),
            ],
          ),
        ),
      ),
      overrides: [...h.appOverrides, ...extraOverrides],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    await tester.tap(find.text('Open the sheet'));
    await settleApp(tester);
  }

  /// Opens the picking screen with [ids] ticked and taps Continue: the
  /// editor sheet is up.
  Future<void> openViaPicking(
    WidgetTester tester,
    Reel reel,
    List<int> ids,
  ) async {
    await pumpScreen(
      tester,
      EditSelectScreen(reelId: reel.id, clipIds: ids),
      overrides: h.appOverrides,
      settle: false,
    );
    await settleApp(tester);
    await tester.tap(find.text('Continue'));
    await settleApp(tester);
  }

  /// The rows of the open sheet, top to bottom, by editor name.
  List<String> rowOrder(WidgetTester tester) => [
    for (final r in tester.widgetList<TtListRow>(find.byType(TtListRow)))
      (r.key! as ValueKey<String>).value.replaceFirst('editor-row-', ''),
  ];

  /// What `lastEditor` holds in the phone's database.
  Future<EditorPick?> storedLastEditor(WidgetTester tester) => real(
    tester,
    () => h.container.read(phoneStateRepositoryProvider).lastEditor(),
  );

  Future<void> storeLastEditor(WidgetTester tester, EditorPick pick) => real(
    tester,
    () => h.container.read(phoneStateRepositoryProvider).recordLastEditor(pick),
  );

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

  /// Reel "Goa" with [count] clips of 4 s each (MediaStore ids 1 to [count],
  /// shot an hour apart). Returns the reel and the clip ids.
  Future<(Reel, List<int>)> manyClips(WidgetTester tester, int count) async {
    final goa = await real(tester, () => reels.create('Goa'));
    final ids = await real(
      tester,
      () => putInReel(h, goa.id, [
        for (var i = 1; i <= count; i++)
          sizedVideo(
            i,
            shot: DateTime.utc(2026, 10, 28, 6).add(Duration(hours: i)),
            size: 100000000,
          ),
      ]),
    );
    return (goa, ids);
  }

  /// Captures log lines (the raw message, so a leak cannot hide).
  List<LogRecord> record() {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);
    return records;
  }

  group(
    'every clip, Choose clips instead and the last used editor (D-189)',
    () {
      // A send asks for the folders already taken, then shares.
      setUp(() => h.editors.allow({'sendTo', 'copyFolderNames'}));

      Finder chooseInstead() =>
          find.widgetWithText(TtButton, 'Choose clips instead');

      testApp('every clip: "Edit all 14 clips in…" and Choose clips instead', (
        tester,
      ) async {
        final (goa, ids) = await manyClips(tester, 14);

        await openSheet(tester, goa, ids, allClips: true);

        expect(find.text('Edit all 14 clips in…'), findsOneWidget);
        expect(find.text('Edit 14 clips in…'), findsNothing);
        expect(chooseInstead(), findsOneWidget);
        final button = tester.widget<TtButton>(chooseInstead());
        expect(button.kind, TtButtonKind.text);
        expect(button.icon, Symbols.checklist_rounded);
        expect(button.onPressed, isNotNull);
        // Under the subtitle, not above it.
        expect(
          tester.getTopLeft(chooseInstead()).dy,
          greaterThan(tester.getTopLeft(find.textContaining('in shooting')).dy),
        );
      });

      testApp('every clip but only one: "Edit 1 clip in…", no Choose clips '
          'instead', (tester) async {
        final (goa, ids) = await manyClips(tester, 1);

        await openSheet(tester, goa, ids, allClips: true);

        expect(find.text('Edit 1 clip in…'), findsOneWidget);
        expect(find.textContaining('Edit all'), findsNothing);
        expect(chooseInstead(), findsNothing);
      });

      testApp('chosen clips: "Edit 3 clips in…", no Choose clips instead', (
        tester,
      ) async {
        final (goa, ids) = await manyClips(tester, 5);

        await openSheet(tester, goa, ids.take(3).toList());

        expect(find.text('Edit 3 clips in…'), findsOneWidget);
        expect(find.textContaining('Edit all'), findsNothing);
        expect(chooseInstead(), findsNothing);
      });

      testApp('chosen clips that happen to be every clip are still "Edit 5 '
          'clips in…" without the button (allClips is the caller\'s word)', (
        tester,
      ) async {
        final (goa, ids) = await manyClips(tester, 5);

        await openSheet(tester, goa, ids);

        expect(find.text('Edit 5 clips in…'), findsOneWidget);
        expect(chooseInstead(), findsNothing);
      });

      testApp('Choose clips instead returns chooseInstead; nothing sent or '
          'stored', (tester) async {
        final (goa, ids) = await manyClips(tester, 3);
        await storeLastEditor(tester, EditorPick.vn);
        await openSheet(tester, goa, ids, allClips: true);

        await tester.tap(chooseInstead());
        await settleApp(tester);

        expect(outcomes, [EditorSheetOutcome.chooseInstead]);
        expect(EditorSheetOutcome.chooseInstead.isPicked, isFalse);
        expect(find.byType(TtSheet), findsNothing);
        expect(find.text(_hostMarker), findsOneWidget);
        expect(h.editors.sent, isEmpty);
        expect(h.editors.chooserShares, isEmpty);
        expect(find.byType(TtSnack), findsNothing);
        expect(await real(tester, () => sessions().sessionOf(goa.id)), isNull);
        // The habit from before is untouched.
        expect(await storedLastEditor(tester), EditorPick.vn);
        await tester.pump(const Duration(milliseconds: 1500));
        await settleApp(tester);
        expect(find.textContaining('Mark Goa'), findsNothing);
      });

      testApp('Choose clips instead does nothing while a send runs', (
        tester,
      ) async {
        h.editors.hold('sendTo');
        final (goa, ids) = await manyClips(tester, 3);
        await openSheet(tester, goa, ids, allClips: true);
        await tester.tap(row('CapCut'));
        await tester.runAsync(settle);
        await tester.pump();

        await tester.tap(chooseInstead(), warnIfMissed: false);
        await tester.runAsync(settle);
        await tester.pump();

        expect(outcomes, isEmpty);
        expect(find.text('Edit all 3 clips in…'), findsOneWidget);
        h.editors.release('sendTo');
        await settleApp(tester);
        // The send went through, and only the send.
        expect(outcomes, [EditorSheetOutcome.sent]);
        expect(h.editors.sent, hasLength(1));
        await flushOffer(tester);
      });

      testApp('no last editor: the default order, no pill', (tester) async {
        final (goa, ids) = await manyClips(tester, 3);

        await openSheet(tester, goa, ids, allClips: true);

        expect(rowOrder(tester), ['capcut', 'edits', 'vn', 'other']);
        for (final r in tester.widgetList<TtListRow>(find.byType(TtListRow))) {
          expect(r.titleTag, isNull);
        }
        expect(find.text('Last used'), findsNothing);
      });

      testApp('Instagram Edits last used: first, with the pill, read '
          '"Instagram Edits, last used"', (tester) async {
        final handle = tester.ensureSemantics();
        final (goa, ids) = await manyClips(tester, 3);
        await storeLastEditor(tester, EditorPick.edits);

        await openSheet(tester, goa, ids, allClips: true);

        expect(rowOrder(tester), ['edits', 'capcut', 'vn', 'other']);
        final edits = tester.widget<TtListRow>(row('Instagram Edits'));
        expect(edits.titleTag, 'Last used');
        expect(edits.semanticLabel, 'Instagram Edits, last used');
        expect(find.text('Last used'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Instagram Edits, last used'),
          findsOneWidget,
        );
        // The others have no pill and no label of their own.
        for (final title in ['CapCut', 'VN', 'Other app…']) {
          final r = tester.widget<TtListRow>(row(title));
          expect(r.titleTag, isNull, reason: title);
          expect(r.semanticLabel, isNull, reason: title);
        }
        // It is still a working row.
        expect(edits.onTap, isNotNull);
        expect(edits.subtitle, 'Gets your original clips');
        handle.dispose();
      });

      testApp('Other app… last used: first, with the pill', (tester) async {
        final (goa, ids) = await manyClips(tester, 3);
        await storeLastEditor(tester, EditorPick.other);

        await openSheet(tester, goa, ids);

        expect(rowOrder(tester), ['other', 'capcut', 'edits', 'vn']);
        final other = tester.widget<TtListRow>(row('Other app…'));
        expect(other.titleTag, 'Last used');
        expect(other.semanticLabel, 'Other app…, last used');
      });

      testApp('last used CapCut, now not installed: default order, no pill', (
        tester,
      ) async {
        h.editors.installed = {_capcut: false, _edits: true, _vn: true};
        final (goa, ids) = await manyClips(tester, 3);
        await storeLastEditor(tester, EditorPick.capcut);

        await openSheet(tester, goa, ids, allClips: true);

        expect(rowOrder(tester), ['capcut', 'edits', 'vn', 'other']);
        expect(find.text('Last used'), findsNothing);
        final capcut = tester.widget<TtListRow>(row('CapCut'));
        expect(capcut.titleTag, isNull);
        expect(capcut.semanticLabel, 'CapCut, not installed');
      });

      testApp('last used Instagram Edits, now not installed: it goes back to '
          'its place, no pill', (tester) async {
        h.editors.installed = {_capcut: true, _edits: false, _vn: true};
        final (goa, ids) = await manyClips(tester, 3);
        await storeLastEditor(tester, EditorPick.edits);

        await openSheet(tester, goa, ids);

        expect(rowOrder(tester), ['capcut', 'edits', 'vn', 'other']);
        expect(find.text('Last used'), findsNothing);
      });

      testApp('last used VN while asking the phone failed: vn first (the '
          'share decides)', (tester) async {
        h.editors.failNext('apps');
        final (goa, ids) = await manyClips(tester, 3);
        await storeLastEditor(tester, EditorPick.vn);

        await openSheet(tester, goa, ids);

        expect(rowOrder(tester), ['vn', 'capcut', 'edits', 'other']);
        expect(tester.widget<TtListRow>(row('VN')).titleTag, 'Last used');
      });

      testApp('while lastEditor loads: the default order, no pill; then it '
          'moves', (tester) async {
        final pending = Completer<EditorPick?>();
        final (goa, ids) = await manyClips(tester, 3);

        await openSheet(
          tester,
          goa,
          ids,
          extraOverrides: [
            lastEditorProvider.overrideWith((ref) => pending.future),
          ],
        );

        expect(rowOrder(tester), ['capcut', 'edits', 'vn', 'other']);
        expect(find.text('Last used'), findsNothing);
        pending.complete(EditorPick.vn);
        await settleApp(tester);
        expect(rowOrder(tester), ['vn', 'capcut', 'edits', 'other']);
        expect(find.text('Last used'), findsOneWidget);
      });

      testApp('a lastEditor that cannot be read is none: the default order, '
          'and the log has the type only', (tester) async {
        final records = record();
        final (goa, ids) = await manyClips(tester, 3);

        await openSheet(
          tester,
          goa,
          ids,
          extraOverrides: [
            phoneStateRepositoryProvider.overrideWithValue(
              _FailingPhone(h.media.db, h.media.clock, read: true),
            ),
          ],
        );

        expect(rowOrder(tester), ['capcut', 'edits', 'vn', 'other']);
        expect(find.text('Last used'), findsNothing);
        final lines = records.map((r) => r.message).join('\n');
        expect(lines, contains('StateError'));
        expect(lines, isNot(contains('secret-detail')));
      });

      testApp('sent to CapCut: lastEditor capcut, outcome sent, the snack, '
          'the host page stays', (tester) async {
        final (goa, ids) = await twoClips(tester);
        await storeLastEditor(tester, EditorPick.vn);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'CapCut');

        expect(await storedLastEditor(tester), EditorPick.capcut);
        expect(outcomes, [EditorSheetOutcome.sent]);
        expect(EditorSheetOutcome.sent.isPicked, isTrue);
        expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
        expect(find.text(_hostMarker), findsOneWidget);
        expect(find.byType(TtSheet), findsNothing);
        await flushOffer(tester);
      });

      testApp('sent to Instagram Edits: lastEditor edits', (tester) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'Instagram Edits');

        expect(await storedLastEditor(tester), EditorPick.edits);
        await flushOffer(tester);
      });

      testApp('VN: lastEditor vn, outcome openedVn, the space check pushed', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, [ids[1], ids[0]]);

        await tapRow(tester, 'VN');

        expect(await storedLastEditor(tester), EditorPick.vn);
        expect(outcomes, [EditorSheetOutcome.openedVn]);
        expect(EditorSheetOutcome.openedVn.isPicked, isTrue);
        expect(
          find.text(copySpaceRouteMarker(goa.id, 'vn', '${ids[1]},${ids[0]}')),
          findsOneWidget,
        );
      });

      testApp('Other app…: lastEditor other, outcome shared', (tester) async {
        h.editors.allow({'shareWithChooser'});
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'Other app…');

        expect(await storedLastEditor(tester), EditorPick.other);
        expect(outcomes, [EditorSheetOutcome.shared]);
        expect(EditorSheetOutcome.shared.isPicked, isTrue);
        expect(h.editors.chooserShares, hasLength(1));
        expect(find.text(_hostMarker), findsOneWidget);
      });

      testApp('not installed, failed and dismissed leave lastEditor alone', (
        tester,
      ) async {
        final (goa, ids) = await twoClips(tester);
        await storeLastEditor(tester, EditorPick.vn);
        await openSheet(tester, goa, ids);

        // Not installed after all: the dialog, the sheet stays.
        h.editors.sendResult = SendResult.notInstalled;
        await tapRow(tester, 'CapCut');
        expect(find.text("CapCut isn't installed"), findsOneWidget);
        expect(await storedLastEditor(tester), EditorPick.vn);
        await tester.tap(find.text('Choose another'));
        await settleApp(tester);

        // The editor did not open: a line in the sheet.
        h.editors.sendResult = SendResult.failed;
        await tapRow(tester, 'Instagram Edits');
        expect(
          find.text("Couldn't open Instagram Edits. Try again."),
          findsOneWidget,
        );
        expect(await storedLastEditor(tester), EditorPick.vn);

        // A share that throws.
        h.editors.failNext('sendTo');
        await tapRow(tester, 'Instagram Edits');
        expect(await storedLastEditor(tester), EditorPick.vn);

        // Dismissed.
        await tester.tapAt(const Offset(180, 20));
        await settleApp(tester);
        expect(find.byType(TtSheet), findsNothing);
        expect(outcomes, [EditorSheetOutcome.dismissed]);
        expect(EditorSheetOutcome.dismissed.isPicked, isFalse);
        expect(await storedLastEditor(tester), EditorPick.vn);
      });

      testApp('a dismissed sheet with no habit stores nothing', (tester) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tester.tapAt(const Offset(180, 20));
        await settleApp(tester);

        expect(await storedLastEditor(tester), isNull);
        expect(
          await real(tester, () async {
            final rows = await h.media.db.select(h.media.db.settings).get();
            return rows.any((r) => r.key == 'lastEditor');
          }),
          isFalse,
        );
      });

      testApp('a lastEditor write that throws still sends; the log has the '
          'type only', (tester) async {
        final records = record();
        final (goa, ids) = await twoClips(tester);
        await openSheet(
          tester,
          goa,
          ids,
          extraOverrides: [
            phoneStateRepositoryProvider.overrideWithValue(
              _FailingPhone(h.media.db, h.media.clock, write: true),
            ),
          ],
        );

        await tapRow(tester, 'CapCut');

        expect(outcomes, [EditorSheetOutcome.sent]);
        expect(h.editors.sent, hasLength(1));
        expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
        final lines = records.map((r) => r.message).join('\n');
        expect(lines, contains('StateError'));
        expect(lines, isNot(contains('secret-detail')));
        await flushOffer(tester);
      });

      testApp('a lastEditor write that throws still opens the VN space '
          'check', (tester) async {
        final (goa, ids) = await twoClips(tester);
        await openSheet(
          tester,
          goa,
          [ids[1], ids[0]],
          extraOverrides: [
            phoneStateRepositoryProvider.overrideWithValue(
              _FailingPhone(h.media.db, h.media.clock, write: true),
            ),
          ],
        );

        await tapRow(tester, 'VN');

        expect(outcomes, [EditorSheetOutcome.openedVn]);
        expect(
          find.text(copySpaceRouteMarker(goa.id, 'vn', '${ids[1]},${ids[0]}')),
          findsOneWidget,
        );
      });

      for (final scale in [1.0, 2.0]) {
        testApp('every clip with a last used editor, ${scale}x text: nothing '
            'overflows, accessible', (tester) async {
          h.editors.installed = {_capcut: false, _edits: true, _vn: true};
          final (goa, ids) = await manyClips(tester, 14);
          await storeLastEditor(tester, EditorPick.edits);

          await openSheet(tester, goa, ids, allClips: true, textScale: scale);

          expect(find.text('Edit all 14 clips in…'), findsOneWidget);
          expect(find.text('Last used'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectTtAccessible(tester, includeDisabledText: true);
        });
      }

      testApp('every clip with a last used editor, dark: accessible', (
        tester,
      ) async {
        final (goa, ids) = await manyClips(tester, 14);
        await storeLastEditor(tester, EditorPick.edits);

        await openSheet(
          tester,
          goa,
          ids,
          allClips: true,
          brightness: Brightness.dark,
        );

        expect(find.text('Last used'), findsOneWidget);
        await expectTtAccessible(tester, includeDisabledText: true);
      });
    },
  );

  group('the picking screen under the sheet', () {
    // A send asks for the folders already taken, then shares.
    setUp(() => h.editors.allow({'sendTo', 'copyFolderNames'}));

    testApp('a send pops the picking screen back to the page under it', (
      tester,
    ) async {
      final (goa, ids) = await twoClips(tester);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text(_hostMarker),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          EditSelectScreen(reelId: goa.id, clipIds: ids),
                    ),
                  ),
                  child: const Text('Open picking'),
                ),
              ],
            ),
          ),
        ),
        overrides: h.appOverrides,
        settle: false,
      );
      await settleApp(tester);
      await tester.tap(find.text('Open picking'));
      await settleApp(tester);
      await tester.tap(find.text('Continue'));
      await settleApp(tester);

      await tapRow(tester, 'CapCut');

      expect(find.byType(EditSelectScreen), findsNothing);
      expect(find.text(_hostMarker), findsOneWidget);
      expect(find.text('Sent 2 clips to CapCut'), findsOneWidget);
      await flushOffer(tester);
    });

    testApp('Other app… leaves the picking screen where it is', (tester) async {
      h.editors.allow({'shareWithChooser'});
      final (goa, ids) = await twoClips(tester);
      await openViaPicking(tester, goa, ids);

      await tapRow(tester, 'Other app…');

      expect(h.editors.chooserShares, hasLength(1));
      expect(find.byType(EditSelectScreen), findsOneWidget);
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
      await openViaPicking(tester, goa, ids);
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
          'the host page stays, with a snack', (tester) async {
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
        // The sheet is gone and the page that opened it stays: no route is
        // popped any more (D-189).
        expect(find.text(_hostMarker), findsOneWidget);
        expect(find.byType(TtSheet), findsNothing);
        expect(outcomes, [EditorSheetOutcome.sent]);
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
      expect(find.text(_hostMarker), findsOneWidget);
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
      expect(find.text(_hostMarker), findsOneWidget);
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
        expect(find.text(_hostMarker), findsOneWidget);

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
        // The sheet and the page under it are still there.
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
      expect(find.text(_hostMarker), findsOneWidget);
      await flushOffer(tester);
    });

    group('failed', () {
      testApp('the editor did not open: a line in the sheet, the sheet and '
          'the page stay, and nothing is left behind', (tester) async {
        h.editors.sendResult = SendResult.failed;
        final (goa, ids) = await twoClips(tester);
        await openSheet(tester, goa, ids);

        await tapRow(tester, 'CapCut');

        expect(find.text("Couldn't open CapCut. Try again."), findsOneWidget);
        expect(find.text('Edit 2 clips in…'), findsOneWidget);
        expect(find.text(_hostMarker), findsOneWidget);
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

      testApp("one clip missing and the share fails: Couldn't open (a clip "
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
      await openSheet(tester, goa, [ids[1], ids[0]]);

      await tapRow(tester, 'VN');

      // The caller's order goes on as it is: video 2 (09:00) first, its clip
      // id is ids[1].
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
      // Back from it lands on the host page, not on another space check.
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
      // The sheet is closed; the host page stays; no status question.
      expect(find.byType(TtSheet), findsNothing);
      expect(find.text(_hostMarker), findsOneWidget);
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
      // The second tap did not pop the page under the sheet.
      expect(find.text(_hostMarker), findsOneWidget);
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

/// A phone state that cannot read or write the last editor, with a message
/// that must never reach the log.
class _FailingPhone extends PhoneStateRepository {
  // The base class's fields are private, so its names are not ours to match.
  // ignore: matching_super_parameters
  _FailingPhone(super.db, super.clock, {this.read = false, this.write = false});

  final bool read;
  final bool write;

  @override
  Future<EditorPick?> lastEditor() {
    if (read) return Future.error(StateError('secret-detail'));
    return super.lastEditor();
  }

  @override
  Future<void> recordLastEditor(EditorPick pick) async {
    if (write) throw StateError('secret-detail');
    await super.recordLastEditor(pick);
  }
}
