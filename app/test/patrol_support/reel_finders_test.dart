import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/references/views/references_section.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../patrol_test/support/player_finders.dart' show canBeTapped;
import '../../patrol_test/support/reel_finders.dart';
import '../features/reels/edit_session_support.dart';
import '../support/reel_videos.dart';
import '../support/test_app.dart';
import '../support/vm_harness.dart';

/// The finders the Patrol flows tap and wait on (D-161, D-197), checked here
/// against the widgets they find on the phone: the S24 run of 2026-11-22 timed
/// out on both of the references flows' old finders, and Phase 12B moved the
/// New reel button, the reel card and the chosen-clips actions to new widgets.
void main() {
  group('Home: newReelButton, reelCardOf', () {
    late VmHarness h;

    setUp(() {
      h = VmHarness();
      h.editors.allowOnly({'apps'});
    });

    Future<void> settleApp(WidgetTester tester) async {
      await tester.runAsync(settle);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpHome(WidgetTester tester, {required int reels}) async {
      // Tall enough that both cards are on the screen (a finder that asks for
      // a hit-testable one needs it there).
      tester.view
        ..physicalSize = const Size(360, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = h.container.read(reelsRepositoryProvider);
      await tester.runAsync(() async {
        if (reels > 0) await repository.create('Goa');
        if (reels > 1) await repository.create('London');
      });
      await tester.pumpWidget(
        ProviderScope(overrides: h.appOverrides, child: const TakeTrayApp()),
      );
      await settleApp(tester);
    }

    testApp('newReelButton finds one, on an empty Home and with reels', (
      tester,
    ) async {
      await pumpHome(tester, reels: 0);
      // The empty state has a New reel button of its own with the same words:
      // the finder is the header's pill, never both.
      expect(find.text('New reel'), findsOneWidget);
      expect(newReelButton(), findsOneWidget);
      expect(tester.widget(newReelButton()), isA<TtHeaderPill>());
      expect(canBeTapped(newReelButton()), isTrue);

      // With reels there is only the pill; it is still one, and still tappable.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpHome(tester, reels: 2);
      expect(find.text('New reel'), findsNothing);
      expect(newReelButton(), findsOneWidget);
      expect(canBeTapped(newReelButton()), isTrue);
    });

    testApp('newReelButton is the one that opens the New reel form', (
      tester,
    ) async {
      await pumpHome(tester, reels: 2);

      await tester.tap(newReelButton());
      await settleApp(tester);

      expect(find.byType(TtSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text('New reel'),
        ),
        findsOneWidget,
      );
    });

    testApp('reelCardOf finds the one card of that name, hit-testable, and '
        'a tap on it opens that reel', (tester) async {
      await pumpHome(tester, reels: 2);

      expect(reelCardOf('Goa'), findsOneWidget);
      expect(reelCardOf('London'), findsOneWidget);
      expect(canBeTapped(reelCardOf('Goa')), isTrue);
      expect(canBeTapped(reelCardOf('London')), isTrue);
      expect(reelCardOf('Paris'), findsNothing);
      expect(
        tester.widget<TtReelCard>(reelCardOf('London')).name,
        'London',
        reason: 'the card, not a text inside it',
      );

      await tester.tap(reelCardOf('London'));
      await settleApp(tester);

      expect(find.byType(ReelDetailScreen), findsOneWidget);
      final page = tester.widget<ReelDetailScreen>(
        find.byType(ReelDetailScreen),
      );
      final london = await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).watchAll().first,
      );
      expect(page.reelId, london!.singleWhere((r) => r.name == 'London').id);
    });
  });

  group('a reel page while choosing: dockAction, dockEdit', () {
    late VmHarness h;

    setUp(() => h = reelHarness());

    /// "Goa" with three clips, open in the shell with the first one chosen
    /// (a hold), the dock settled in.
    Future<int> choosing(WidgetTester tester) async {
      final goa = await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      );
      await real(
        tester,
        () => putInReel(h, goa.id, [for (var i = 1; i <= 3; i++) reelVideo(i)]),
      );
      await openReelPage(
        tester,
        h,
        goa.id,
        size: const Size(360, 1600),
        inShell: true,
      );
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      return goa.id;
    }

    testApp('each of the four actions is found once, by its visible words, '
        'and is hit-testable', (tester) async {
      await choosing(tester);

      expect(find.byType(TtSelectionDock), findsOneWidget);
      for (final label in ['Share', 'Add to', 'Move', 'Remove']) {
        expect(dockAction(label), findsOneWidget, reason: label);
        expect(canBeTapped(dockAction(label)), isTrue, reason: label);
      }
      expect(dockAction('Choose'), findsNothing);
    });

    testApp("dockAction is the dock's, not a button of the page with the same "
        'words', (tester) async {
      await choosing(tester);
      // "Select all" is on the page's selection bar, not in the dock.
      expect(find.text('Select all'), findsWidgets);
      expect(dockAction('Select all'), findsNothing);
    });

    testApp('dockEdit finds the one Edit button, hit-testable; its words '
        'follow what is chosen', (tester) async {
      await choosing(tester);

      expect(dockEdit(), findsOneWidget);
      expect(canBeTapped(dockEdit()), isTrue);
      expect(
        find.descendant(of: dockEdit(), matching: find.text('Edit 1 clip')),
        findsOneWidget,
      );

      await tester.tap(find.byType(TtClipTile).at(2));
      await tester.pumpAndSettle();
      expect(dockEdit(), findsOneWidget);
      expect(
        find.descendant(of: dockEdit(), matching: find.text('Edit 2 clips')),
        findsOneWidget,
      );
    });

    testApp('while the reel is being edited the dock has a note, so there is '
        'no Edit button to find (R1)', (tester) async {
      final goa = await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      );
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await real(
        tester,
        () => startEditing(h, goa.id, EditorApp.vn, copied: [ids.first]),
      );
      await openReelPage(
        tester,
        h,
        goa.id,
        size: const Size(360, 1600),
        inShell: true,
      );
      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(TtSelectionDock), findsOneWidget);
      expect(dockEdit(), findsNothing);
      // The four actions are still there.
      expect(dockAction('Remove'), findsOneWidget);
    });

    testApp('no dock, no finders: before a hold nothing is found', (
      tester,
    ) async {
      final goa = await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      );
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await openReelPage(tester, h, goa.id, size: const Size(360, 1600));

      expect(dockAction('Remove'), findsNothing);
      expect(dockEdit(), findsNothing);
      expect(canBeTapped(dockEdit()), isFalse);
    });
  });

  group('reelPageOf', () {
    late VmHarness h;

    setUp(() {
      h = VmHarness();
      // Home asks which editor apps are on the phone.
      h.editors.allowOnly({'apps'});
    });

    Future<void> settleApp(WidgetTester tester) async {
      await tester.runAsync(settle);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testApp('finds the page opened at its References, with the name scrolled '
        'away', (tester) async {
      final reels = h.container.read(reelsRepositoryProvider);
      final references = h.container.read(referencesRepositoryProvider);
      final ids = await tester.runAsync(() async {
        final goa = await reels.create(
          'Goa',
          description: 'Wide shot of the harbour at dawn',
        );
        final other = await reels.create('London');
        await references.add(goa.id, 'https://example.com/a1');
        await references.add(goa.id, 'https://example.com/a2');
        return (goa: goa.id, other: other.id);
      });
      await tester.pumpWidget(
        ProviderScope(overrides: h.appOverrides, child: const TakeTrayApp()),
      );
      await settleApp(tester);
      unawaited(
        GoRouter.of(tester.element(find.byType(ReelsScreen)))
            .push(Routes.reelReferences(ids!.goa)),
      );
      await settleApp(tester);

      // As on the S24: the page scrolled to its References section, and the
      // header with the name went off the screen (a finder skips it then).
      expect(find.byType(ReferencesSection), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReelDetailScreen),
          matching: find.text('Goa'),
        ),
        findsNothing,
      );
      expect(reelPageOf(ids.goa, 'Goa'), findsOneWidget);
      expect(reelPageOf(ids.other, 'London'), findsNothing);
    });
  });
}
