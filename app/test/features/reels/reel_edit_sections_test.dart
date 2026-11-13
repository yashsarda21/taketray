import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/views/reel_edit_sections.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import '../editors/copy_support.dart' show startVnJob;
import 'edit_session_support.dart';

/// Tall enough that every part of the page is built (the slivers are lazy).
const Size _tall = Size(360, 2400);

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
  });

  /// "Goa" with clips 1–3 shot on 28 Oct and 4–5 on 29 Oct. The clips at
  /// the positions in [missing] are gone from the phone and flagged missing.
  Future<(Reel, List<int>)> goaReel(
    WidgetTester tester, {
    Set<int> missing = const {},
  }) async {
    final goa = await real(tester, () => reels.create('Goa'));
    final ids = <int>[];
    for (final (i, (id, day, hour)) in [
      (1, 28, 9),
      (2, 28, 10),
      (3, 28, 11),
      (4, 29, 9),
      (5, 29, 10),
    ].indexed) {
      final [clip] = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(id, shot: DateTime.utc(2026, 10, day, hour)),
        ], onPhone: !missing.contains(i)),
      );
      ids.add(clip);
    }
    if (missing.isNotEmpty) {
      await real(
        tester,
        () => flagForTest(h, {for (final i in missing) ids[i]}, missing: true),
      );
    }
    return (goa, ids);
  }

  /// Every section header as (title, subtitle).
  List<(String, String)> sections(WidgetTester tester) => [
    for (final s in tester.widgetList<ReelEditSectionHeader>(
      find.byType(ReelEditSectionHeader),
    ))
      (s.title, s.subtitle.replaceAll(RegExp('[  ]'), ' ')),
  ];

  /// The day headers' titles, no-break spaces made plain.
  List<String> days(WidgetTester tester) => [
    for (final d in tester.widgetList<TtDayHeader>(find.byType(TtDayHeader)))
      d.title.replaceAll(RegExp('[  ]'), ' '),
  ];

  /// The clip id of every tile and missing tile, top to bottom.
  List<int> tileIds(WidgetTester tester) => [
    for (final e
        in find
            .byWidgetPredicate((w) => w is TtClipTile || w is TtMissingClipTile)
            .evaluate())
      (e.widget.key! as ValueKey<int>).value,
  ];

  Finder sectionButton(String label) => find.descendant(
    of: find.byType(ReelEditSectionHeader),
    matching: find.widgetWithText(TtButton, label),
  );

  Finder barButton(String label) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == label,
  );

  Future<Set<int>> clipIdsOf(WidgetTester tester, int reelId) =>
      real(tester, () => clips.clipIdsOfReel(reelId));

  group('VN', () {
    testApp('"New since you started editing" first with Copy to VN folder, '
        'then "In your edit", each with its own day headers', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: [ids[0], ids[1], ids[3]],
        ),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('New since you started editing', '2 clips · not in your edit yet'),
        ('In your edit', '3 clips · in the VN folder'),
      ]);
      expect(sectionButton('Copy to VN folder'), findsOneWidget);
      expect(days(tester), [
        'Day 1 · Wed, Oct 28',
        'Day 2 · Thu, Oct 29',
        'Day 1 · Wed, Oct 28',
        'Day 2 · Thu, Oct 29',
      ]);
      expect(tileIds(tester), [ids[2], ids[4], ids[0], ids[1], ids[3]]);
      final newTop = tester.getTopLeft(
        find.text('New since you started editing'),
      );
      final editTop = tester.getTopLeft(find.text('In your edit'));
      expect(newTop.dy, lessThan(editTop.dy));
    });

    testApp('no new clips: only "In your edit"', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: ids),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('In your edit', '5 clips · in the VN folder'),
      ]);
      expect(find.text('Copy to VN folder'), findsNothing);
    });

    testApp('one clip is "1 clip"', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: [ids[0], ids[1], ids[2], ids[3]],
        ),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('New since you started editing', '1 clip · not in your edit yet'),
        ('In your edit', '4 clips · in the VN folder'),
      ]);
    });

    testApp('Copy to VN folder opens the picking screen in add mode', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      await tester.tap(sectionButton('Copy to VN folder'));
      await tester.tap(sectionButton('Copy to VN folder'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.text(editSelectRouteMarker('${goa.id}', null, '1')),
        findsOneWidget,
      );
    });

    testApp('missing clips stay in their part; Copy is off when every new '
        'clip is missing', (tester) async {
      final (goa, ids) = await goaReel(tester, missing: {0, 3, 4});
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: [ids[0], ids[1], ids[2]],
        ),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('New since you started editing', '2 clips · not in your edit yet'),
        ('In your edit', '3 clips · in the VN folder'),
      ]);
      expect(tileIds(tester), [ids[3], ids[4], ids[0], ids[1], ids[2]]);
      expect(find.byType(TtMissingClipTile), findsNWidgets(3));
      expect(
        tester.widget<TtButton>(sectionButton('Copy to VN folder')).onPressed,
        isNull,
      );
    });

    testApp('a clip tagged in meanwhile is under "New since…" at once', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: ids),
      );
      await openReelPage(tester, h, goa.id, size: _tall);
      expect(find.text('New since you started editing'), findsNothing);

      final [late] = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(9, shot: DateTime.utc(2026, 10, 29, 20)),
        ]),
      );
      await settleApp(tester);

      expect(sections(tester).first, (
        'New since you started editing',
        '1 clip · not in your edit yet',
      ));
      expect(tileIds(tester).first, late);
    });

    testApp('a copy deleted outside TakeTray: on open its clip is new', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      final copies = await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      h.editors.existing = {copies[1]};

      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('New since you started editing', '4 clips · not in your edit yet'),
        ('In your edit', '1 clip · in the VN folder'),
      ]);
      expect(tileIds(tester).last, ids[1]);
    });

    testApp('Copy to VN folder is off while a copy job of the reel runs', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await startVnJob(tester, h, goa, ids, clipIds: [ids[0]]);
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(
        tester.widget<TtButton>(sectionButton('Copy to VN folder')).onPressed,
        isNull,
      );
    });
  });

  group('CapCut and Edits', () {
    testApp('"New since…" has its title and subtitle and no button; "In your '
        'edit" says when they were sent', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.capcut,
          sent: [ids[0], ids[1], ids[2]],
        ),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('New since you started editing', '2 clips · not in your edit yet'),
        ('In your edit', '3 clips · sent to CapCut on Oct 30'),
      ]);
      expect(sectionButton('Copy to VN folder'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ReelEditSectionHeader),
          matching: find.byType(TtButton),
        ),
        findsNothing,
      );
    });

    testApp('Edits says "Edits"', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.edits, sent: ids),
      );
      await openReelPage(tester, h, goa.id, size: _tall);

      expect(sections(tester), [
        ('In your edit', '5 clips · sent to Edits on Oct 30'),
      ]);
    });
  });

  group('removing and moving while editing (R8)', () {
    testApp('remove: the snack says the copy was deleted; Undo brings the '
        'clip back under "New since…"', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      h.editors.allow({'deleteCopies'});
      await openReelPage(tester, h, goa.id, size: _tall);
      // The first tile of "In your edit" is clip 1.
      final tile = find.byWidgetPredicate(
        (w) => w is TtClipTile && w.key == ValueKey(ids[0]),
      );
      await tester.longPress(tile);
      await tester.pumpAndSettle();

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);

      expect(
        find.text(
          '1 clip removed from Goa. The video is still in your gallery. Its '
          'copy in the folder was deleted.',
        ),
        findsOneWidget,
      );
      expect(sections(tester).last, (
        'In your edit',
        '1 clip · in the VN folder',
      ));

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(await clipIdsOf(tester, goa.id), ids.toSet());
      expect(sections(tester), [
        ('New since you started editing', '4 clips · not in your edit yet'),
        ('In your edit', '1 clip · in the VN folder'),
      ]);
    });

    testApp('remove of two copied clips: "Their copies…"', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      h.editors.allow({'deleteCopies'});
      await openReelPage(tester, h, goa.id, size: _tall);
      await tester.longPress(
        find.byWidgetPredicate(
          (w) => w is TtClipTile && w.key == ValueKey(ids[0]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtClipTile && w.key == ValueKey(ids[1]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);

      expect(
        find.text(
          '2 clips removed from Goa. The videos are still in your gallery. '
          'Their copies in the folder were deleted.',
        ),
        findsOneWidget,
      );
    });

    testApp('a remove whose copy cannot be deleted removes nothing and says '
        'so', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors
        ..allow({'deleteCopies'})
        ..failNext('deleteCopies');
      await openReelPage(tester, h, goa.id, size: _tall);
      await tester.longPress(
        find.byWidgetPredicate(
          (w) => w is TtClipTile && w.key == ValueKey(ids[0]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);

      expect(
        find.text("Couldn't delete the copies. Try again."),
        findsOneWidget,
      );
      expect(find.textContaining('removed from Goa'), findsNothing);
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
      // The choice is kept to try again.
      expect(find.text('1 selected'), findsOneWidget);
    });

    testApp('a clip sent to CapCut that is removed and put back is in your '
        'edit again: its sent row stays', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.capcut, sent: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id, size: _tall);
      await tester.longPress(
        find.byWidgetPredicate(
          (w) => w is TtClipTile && w.key == ValueKey(ids[0]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(barButton('Remove from this reel'));
      await settleApp(tester);
      // No copy, so no word about one.
      expect(
        find.text(
          '1 clip removed from Goa. The video is still in your gallery.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(sections(tester).last, (
        'In your edit',
        '1 clip · sent to CapCut on Oct 30',
      ));
      expect(tileIds(tester).last, ids[0]);
    });

    testApp('move: the snack says the copy was deleted; a move whose copy '
        'cannot be deleted says so in the sheet and moves nothing', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      final london = await real(tester, () => reels.create('London'));
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0], ids[1]]),
      );
      h.editors
        ..allow({'deleteCopies'})
        ..failNext('deleteCopies');
      await openReelPage(tester, h, goa.id, size: _tall);
      await tester.longPress(
        find.byWidgetPredicate(
          (w) => w is TtClipTile && w.key == ValueKey(ids[0]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(barButton('Move to another reel'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);

      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text("Couldn't delete the copies. Try again."),
        ),
        findsOneWidget,
      );
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
      expect(await clipIdsOf(tester, london.id), isEmpty);

      // The retry works, and the snack says the copy went.
      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);
      expect(
        find.text('Moved to London. Its copy in the folder was deleted.'),
        findsOneWidget,
      );
      expect(await clipIdsOf(tester, london.id), {ids[0]});
    });

    testApp("a missing clip whose copy cannot be deleted stays, and it's "
        'said', (tester) async {
      final (goa, ids) = await goaReel(tester, missing: {0});
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      h.editors
        ..allow({'deleteCopies'})
        ..failNext('deleteCopies');
      await openReelPage(tester, h, goa.id, size: _tall);

      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(
        find.text("Couldn't delete the copies. Try again."),
        findsOneWidget,
      );
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });
  });

  group('choosing clips while editing', () {
    testApp('Select all chooses the clips of both parts', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id, size: _tall);
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'More options',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('5 selected'), findsOneWidget);
      // Edit video is not offered during a session (R1).
      expect(find.text('Edit video'), findsNothing);
    });
  });

  group('the look', () {
    for (final (scale, brightness) in [
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
    ]) {
      testApp('at ${scale}x ${brightness.name}: the section button wraps '
          'under the title, nothing cut, accessible', (tester) async {
        final (goa, ids) = await goaReel(tester);
        await real(
          tester,
          () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
        );
        await openReelPage(
          tester,
          h,
          goa.id,
          textScale: scale,
          brightness: brightness,
          size: _tall,
        );

        expect(tester.takeException(), isNull);
        final title = find.text('New since you started editing');
        final subtitle = find.text('4 clips · not in your edit yet');
        expect(subtitle, findsOneWidget);
        if (scale >= 2) {
          expect(
            tester.getTopLeft(sectionButton('Copy to VN folder')).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(subtitle).dy),
          );
        }
        // Neither the title nor the subtitle is cut short.
        for (final text in [title, subtitle]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        await expectTtAccessible(tester);
      });
    }
  });
}
