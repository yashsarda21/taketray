import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/views/reel_edit_banner.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import '../editors/copy_support.dart' show startVnJob;
import 'edit_session_support.dart';

void main() {
  late VmHarness h;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
  });

  /// "Goa" with four clips shot on 28 Oct; returns the reel and the ids.
  Future<(Reel, List<int>)> goaReel(WidgetTester tester) async {
    final goa = await real(tester, () => reels.create('Goa'));
    final ids = await real(
      tester,
      () => putInReel(h, goa.id, [for (var i = 1; i <= 4; i++) reelVideo(i)]),
    );
    return (goa, ids);
  }

  Finder banner() => find.byType(ReelEditBanner);

  TtBanner ttBanner(WidgetTester tester) => tester.widget<TtBanner>(
    find.descendant(of: banner(), matching: find.byType(TtBanner)),
  );

  String plain(String text) => text.replaceAll(RegExp('[  ]'), ' ');

  Finder buttonIn(String label) => find.descendant(
    of: banner(),
    matching: find.widgetWithText(TtButton, label),
  );

  Finder fab() => find.byType(TtFab);

  group('no session', () {
    testApp("the page is today's: no banner, no sections, the FAB", (
      tester,
    ) async {
      final (goa, _) = await goaReel(tester);
      await openReelPage(tester, h, goa.id);

      expect(banner(), findsNothing);
      expect(find.text('Done editing'), findsNothing);
      expect(find.text('In your edit'), findsNothing);
      expect(find.text('New since you started editing'), findsNothing);
      expect(find.byType(TtDayHeader), findsOneWidget);
      expect(find.byType(TtClipTile), findsNWidgets(4));
      expect(fab(), findsOneWidget);
    });
  });

  group('VN', () {
    testApp('"Editing in VN · {size}" over "{n} copies in the folder", Done '
        'editing and Add more clips, above the clips', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: [ids[0], ids[1]],
          folder: 'Goa (2)',
        ),
      );
      await openReelPage(tester, h, goa.id);

      expect(plain(ttBanner(tester).title), 'Editing in VN · 600 MB');
      expect(ttBanner(tester).body, '2 copies in Movies/TakeTray/Goa (2)');
      expect(ttBanner(tester).kind, TtBannerKind.vn);
      expect(buttonIn('Done editing'), findsOneWidget);
      expect(buttonIn('Add more clips'), findsOneWidget);
      expect(
        tester.widget<TtButton>(buttonIn('Done editing')).kind,
        TtButtonKind.filled,
      );
      // Above the clips (and the sections' headers), under the reel's header.
      final bannerBottom = tester.getBottomLeft(banner()).dy;
      expect(
        bannerBottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TtClipTile).first).dy),
      );
      expect(
        bannerBottom,
        lessThanOrEqualTo(tester.getTopLeft(find.text('In your edit')).dy),
      );
      expect(
        tester.getTopLeft(banner()).dy,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(find.byWidgetPredicate((w) => w is TtReelHeader))
              .dy,
        ),
      );
      // Edit video waits for Done editing (R1).
      expect(fab(), findsNothing);
    });

    testApp('one copy is "1 copy"', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id);

      expect(plain(ttBanner(tester).title), 'Editing in VN · 300 MB');
      expect(ttBanner(tester).body, '1 copy in Movies/TakeTray/Goa');
    });

    testApp('Add more clips opens the picking screen in add mode, once', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id);

      await tester.tap(buttonIn('Add more clips'));
      await tester.tap(buttonIn('Add more clips'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.text(editSelectRouteMarker('${goa.id}', null, '1')),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(banner(), findsOneWidget);
    });

    testApp('Done editing opens the Done editing dialog, once', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id);

      await tester.tap(buttonIn('Done editing'));
      await tester.tap(buttonIn('Done editing'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(find.byType(TtDialog<bool>), findsOneWidget);
    });
  });

  group('CapCut and Edits', () {
    testApp('no copies: "Editing in CapCut" over "Sent on {date}", Done '
        'editing only', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.capcut, sent: ids),
      );
      await openReelPage(tester, h, goa.id);

      expect(ttBanner(tester).title, 'Editing in CapCut');
      expect(plain(ttBanner(tester).body!), 'Sent on Oct 30');
      expect(buttonIn('Done editing'), findsOneWidget);
      expect(buttonIn('Add more clips'), findsOneWidget);
      expect(
        tester.widget<TtButton>(buttonIn('Done editing')).kind,
        TtButtonKind.filled,
      );
      expect(
        tester.widget<TtButton>(buttonIn('Add more clips')).kind,
        TtButtonKind.text,
      );
      expect(fab(), findsNothing);
    });

    testApp('with copies: the size and the copies are added', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.capcut,
          sent: [ids[0], ids[1]],
          copied: [ids[2]],
        ),
      );
      await openReelPage(tester, h, goa.id);

      expect(plain(ttBanner(tester).title), 'Editing in CapCut · 300 MB');
      expect(
        plain(ttBanner(tester).body!),
        'Sent on Oct 30 · 1 copy in Movies/TakeTray/Goa',
      );
      expect(buttonIn('Done editing'), findsOneWidget);
      expect(buttonIn('Add more clips'), findsOneWidget);
    });

    for (final editor in [EditorApp.capcut, EditorApp.edits]) {
      testApp('${editor.name}: Add more clips opens the picking screen in '
          'add mode, once', (tester) async {
        final (goa, ids) = await goaReel(tester);
        await real(
          tester,
          () => startEditing(h, goa.id, editor, sent: [ids[0]]),
        );
        await openReelPage(tester, h, goa.id);

        await tester.tap(buttonIn('Add more clips'));
        await tester.tap(buttonIn('Add more clips'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.text(editSelectRouteMarker('${goa.id}', null, '1')),
          findsOneWidget,
        );
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(banner(), findsOneWidget);
      });
    }

    testApp('Done editing still opens its dialog, once', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.capcut, sent: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id);

      await tester.tap(buttonIn('Done editing'));
      await tester.tap(buttonIn('Done editing'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsOneWidget);
    });

    testApp('Edits is "Edits" on the banner', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.edits, sent: ids),
      );
      await openReelPage(tester, h, goa.id);

      expect(ttBanner(tester).title, 'Editing in Edits');
    });
  });

  group('a copy job of this reel', () {
    testApp('while it runs: "Copying clips for VN", "{done} of {total} '
        'clips" and Show, which opens its progress; no Done editing', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      final job = await startVnJob(tester, h, goa, ids);
      await openReelPage(tester, h, goa.id);

      expect(ttBanner(tester).title, 'Copying clips for VN');
      expect(ttBanner(tester).body, '0 of 4 clips');
      expect(find.text('Done editing'), findsNothing);
      expect(find.text('Add more clips'), findsNothing);

      h.copy.emit(job.report(copied: [0]));
      await settleApp(tester);
      expect(ttBanner(tester).body, '1 of 4 clips');

      await tester.tap(buttonIn('Show'));
      await tester.pumpAndSettle();
      expect(find.text(copyProgressRouteMarker(job.jobId)), findsOneWidget);
    });

    for (final (editor, name) in [
      (EditorApp.capcut, 'CapCut'),
      (EditorApp.edits, 'Edits'),
    ]) {
      testApp('a ${editor.name} add job: "Copying clips for $name"', (
        tester,
      ) async {
        final (goa, ids) = await goaReel(tester);
        await startVnJob(tester, h, goa, ids, editor: editor);
        await openReelPage(tester, h, goa.id);

        expect(ttBanner(tester).title, 'Copying clips for $name');
        expect(ttBanner(tester).body, '0 of 4 clips');
        expect(find.text('Done editing'), findsNothing);
        expect(find.text('Add more clips'), findsNothing);
      });
    }

    testApp("the job's own editor is named even when the page has no session "
        'for it (the session ended, or is not known yet), never a guess of '
        'VN', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await startVnJob(tester, h, goa, ids, editor: EditorApp.capcut);
      await real(
        tester,
        () =>
            h.container.read(editSessionsRepositoryProvider).endSession(goa.id),
      );
      await openReelPage(tester, h, goa.id);

      expect(ttBanner(tester).title, 'Copying clips for CapCut');
      expect(find.textContaining('VN'), findsNothing);
    });

    testApp('the first VN job (no session read yet) still says VN', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await startVnJob(tester, h, goa, ids);
      await openReelPage(tester, h, goa.id);

      expect(ttBanner(tester).title, 'Copying clips for VN');
    });

    testApp('once it is over, Done editing is back', (tester) async {
      final (goa, ids) = await goaReel(tester);
      final job = await startVnJob(tester, h, goa, ids);
      await openReelPage(tester, h, goa.id);
      expect(find.text('Done editing'), findsNothing);

      h.copy.emit(job.report(state: CopyState.finished, copied: [0, 1, 2, 3]));
      await settleApp(tester);

      expect(ttBanner(tester).title, startsWith('Editing in VN'));
      expect(buttonIn('Done editing'), findsOneWidget);
      expect(find.text('Show'), findsNothing);
    });

    testApp("another reel's job leaves this banner as it is", (tester) async {
      final (goa, ids) = await goaReel(tester);
      final london = await real(tester, () => reels.create('London'));
      final londonIds = await real(
        tester,
        () => putInReel(h, london.id, [reelVideo(9)]),
      );
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await startVnJob(tester, h, london, londonIds);
      await openReelPage(tester, h, goa.id);

      expect(ttBanner(tester).title, startsWith('Editing in VN'));
      expect(buttonIn('Done editing'), findsOneWidget);
    });
  });

  group('asked from the copies reminder (?done=1)', () {
    testApp('a reel with a session: the Done editing dialog, once', (
      tester,
    ) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
      );
      await openReelPage(tester, h, goa.id, askDoneEditing: true);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await settleApp(tester);
      expect(find.byType(TtDialog<bool>), findsNothing);

      // The page redraws (the clips change): no second dialog.
      await real(tester, () => putInReel(h, goa.id, [reelVideo(8)]));
      await settleApp(tester);
      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(banner(), findsOneWidget);
    });

    testApp('a reel with no session: just the page', (tester) async {
      final (goa, _) = await goaReel(tester);
      await openReelPage(tester, h, goa.id, askDoneEditing: true);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(find.byType(TtClipTile), findsNWidgets(4));
      // A session that starts later is not asked about.
      await real(
        tester,
        () => h.container
            .read(editSessionsRepositoryProvider)
            .startSession(goa.id, EditorApp.capcut, 'Goa'),
      );
      await settleApp(tester);
      expect(find.byType(TtDialog<bool>), findsNothing);
    });

    testApp('not while a copy job of the reel runs', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await startVnJob(tester, h, goa, ids);
      await openReelPage(tester, h, goa.id, askDoneEditing: true);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(ttBanner(tester).title, 'Copying clips for VN');
    });
  });

  group('the look', () {
    for (final (scale, brightness) in [
      (2.0, Brightness.light),
      (1.0, Brightness.dark),
      (2.0, Brightness.dark),
    ]) {
      testApp('at ${scale}x ${brightness.name}: the actions under the text, '
          'nothing cut, accessible', (tester) async {
        final (goa, ids) = await goaReel(tester);
        await real(
          tester,
          () => startEditing(
            h,
            goa.id,
            EditorApp.vn,
            copied: [ids[0]],
            folder: 'Goa food trip with friends',
          ),
        );
        await openReelPage(
          tester,
          h,
          goa.id,
          textScale: scale,
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        final title = find.descendant(
          of: banner(),
          matching: find.textContaining('Editing in VN'),
        );
        final done = buttonIn('Done editing');
        final more = buttonIn('Add more clips');
        expect(done, findsOneWidget);
        expect(more, findsOneWidget);
        expect(
          tester.getTopLeft(done).dy,
          greaterThan(tester.getBottomLeft(title).dy - 1),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
