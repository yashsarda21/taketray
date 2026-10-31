import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_summaries.dart';
import '../../../support/view_model_fakes.dart';

final DateTime _now = DateTime(2026, 10, 28, 15, 30);

const String _cameraSnack = "Couldn't open the camera.";

ShootingState _on() => ShootingState(
  on: true,
  baselines: const {},
  since: DateTime(2026, 10, 28, 9, 41).toUtc(),
);

/// A 40-character name made of emoji (the longest the field allows).
final String _emojiName = List.filled(40, '🎬').join();

/// Home with fake view models. [reels] null: the list is still loading.
Future<FakeShooting> pumpHome(
  WidgetTester tester, {
  List<ReelSummary>? reels = const [],
  ShootingState shooting = ShootingState.off,
  bool cameraOpens = true,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool settle = true,
}) async {
  final fakeShooting = FakeShooting(shooting, cameraOpens: cameraOpens);
  await pumpScreen(
    tester,
    const ReelsScreen(),
    overrides: <Override>[
      reelSummariesProvider.overrideWith(
        (ref) => reels == null ? const Stream.empty() : Stream.value(reels),
      ),
      shootingModeControllerProvider.overrideWith(() => fakeShooting),
      mediaAccessControllerProvider.overrideWith(
        () => FakeAccess(MediaAccessLevel.full),
      ),
      pendingClipsProvider.overrideWith((ref) => Stream.value(const [])),
      firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
      clockProvider.overrideWithValue(FixedClock(_now)),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
    settle: settle,
  );
  return fakeShooting;
}

List<ReelSummary> mixed() => [
  testSummary(
    5,
    name: 'London Food',
    clipCount: 3,
    missingCount: 2,
    liveDurationMs: 65000,
    cover: testClip(1),
  ),
  testSummary(4, name: 'Day 1 Vlog', status: ReelStatus.ready, clipCount: 1),
  testSummary(
    3,
    name: 'Goa',
    status: ReelStatus.published,
    clipCount: 12,
    liveDurationMs: 3725000,
  ),
  testSummary(2, name: 'Empty one'),
];

Finder chip(String label) => find.text(label);

/// Taps a filter chip, scrolling the chips sideways first if it is off the
/// right edge (they scroll, as in the prototype).
Future<void> tapChip(WidgetTester tester, String label) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (tester.getCenter(chip(label)).dx > width - 24) {
    await tester.drag(
      find.byType(TtPillTabs<ReelFilter>),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(chip(label));
  await tester.pumpAndSettle();
}

void main() {
  group('no reels', () {
    testWidgets('first-time empty state and its New reel button', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Plan your first reel'), findsOneWidget);
      expect(
        find.text(
          "A reel is a video you're planning, like London Food or Day 1 "
          'Vlog. Clips you tag go into it.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TtEmptyState>(find.byType(TtEmptyState)).illustration,
        TtIllustrationKind.noReels,
      );
      expect(find.widgetWithText(TtButton, 'New reel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TtButton, 'New reel'));
      await tester.pumpAndSettle();

      expect(find.text('Create reel'), findsOneWidget);
      expect(find.text('Reel name'), findsOneWidget);
    });

    testWidgets('chips hidden with no reels', (tester) async {
      await pumpHome(tester);

      expect(find.byType(TtPillTabs<ReelFilter>), findsNothing);
      expect(find.text('Collecting'), findsNothing);
      expect(find.text('Published'), findsNothing);
    });

    testWidgets('FAB only with reels: none without', (tester) async {
      await pumpHome(tester);

      expect(find.byType(TtFab), findsNothing);
    });

    testWidgets('while the list loads nothing says "no reels" yet', (
      tester,
    ) async {
      await pumpHome(tester, reels: null);

      expect(find.text('Plan your first reel'), findsNothing);
      expect(find.byType(TtFab), findsNothing);
      expect(find.byType(TtReelCard), findsNothing);
      // The Shooting mode card is there all the same.
      expect(find.text('Shooting mode'), findsOneWidget);
    });
  });

  group('with reels', () {
    testWidgets('FAB only with reels: New reel opens the form', (tester) async {
      await pumpHome(tester, reels: mixed());

      expect(find.byType(TtFab), findsOneWidget);
      expect(find.text('Plan your first reel'), findsNothing);
      final fab = tester.widget<TtFab>(find.byType(TtFab));
      expect(fab.label, 'New reel');
      expect(fab.icon, Symbols.add_rounded);

      await tester.tap(find.byType(TtFab));
      await tester.pumpAndSettle();

      expect(find.text('Create reel'), findsOneWidget);
    });

    testWidgets('the FAB sits at TtNavPill.fabBottom from the bottom', (
      tester,
    ) async {
      await pumpHome(tester, reels: mixed());

      final context = tester.element(find.byType(TtFab));
      final fabBottom = tester.getBottomRight(find.byType(TtFab)).dy;
      expect(
        tester.view.physicalSize.height - fabBottom,
        TtNavPill.fabBottom(context),
      );
    });

    testWidgets('the screen is in order: banner, Shooting mode, chips, cards', (
      tester,
    ) async {
      await pumpHome(tester, reels: mixed());

      final shooting = tester.getTopLeft(find.byType(TtShootingModeCard)).dy;
      final chips = tester.getTopLeft(find.text('All 4')).dy;
      final firstCard = tester.getTopLeft(find.byType(TtReelCard).first).dy;
      expect(shooting, lessThan(chips));
      expect(chips, lessThan(firstCard));
      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).large, isTrue);
      expect(find.text('Reels'), findsWidgets);
    });

    testWidgets('chips show the counts and All is selected', (tester) async {
      await pumpHome(tester, reels: mixed());

      expect(chip('All 4'), findsOneWidget);
      expect(chip('Collecting 2'), findsOneWidget);
      expect(chip('Ready to edit 1'), findsOneWidget);
      expect(chip('Published 1'), findsOneWidget);
      final tabs = tester.widget<TtPillTabs<ReelFilter>>(
        find.byType(TtPillTabs<ReelFilter>),
      );
      expect(tabs.tabs.map((t) => t.label), [
        'All 4',
        'Collecting 2',
        'Ready to edit 1',
        'Published 1',
      ]);
    });

    testWidgets('a chip narrows the cards and keeps their order', (
      tester,
    ) async {
      await pumpHome(tester, reels: mixed());
      expect(find.byType(TtReelCard), findsNWidgets(4));

      await tapChip(tester, 'Collecting 2');

      final names = [
        for (final c in tester.widgetList<TtReelCard>(find.byType(TtReelCard)))
          c.name,
      ];
      expect(names, ['London Food', 'Empty one']);
      // The counts do not change with the filter.
      expect(chip('Published 1'), findsOneWidget);
    });

    testWidgets('cards show cover, status, meta and missing', (tester) async {
      await pumpHome(tester, reels: mixed());

      final cards = tester
          .widgetList<TtReelCard>(find.byType(TtReelCard))
          .toList();
      expect(cards.map((c) => c.name), [
        'London Food',
        'Day 1 Vlog',
        'Goa',
        'Empty one',
      ]);

      final london = cards[0];
      expect(london.cover, isA<ClipThumbnailImage>());
      expect(london.status, TtStatusKind.collecting);
      expect(london.statusLabel, 'Collecting');
      expect(london.meta, '3 clips · 1:05');
      expect(london.missingText, '2 missing');
      expect(london.emptyLabel, 'No clips yet');

      final vlog = cards[1];
      expect(vlog.cover, isNull);
      expect(vlog.status, TtStatusKind.ready);
      expect(vlog.statusLabel, 'Ready to edit');
      expect(vlog.meta, '1 clip · 0:00');
      expect(vlog.missingText, isNull);

      final goa = cards[2];
      expect(goa.status, TtStatusKind.published);
      expect(goa.statusLabel, 'Published');
      expect(goa.meta, '12 clips · 1:02:05');

      final empty = cards[3];
      expect(empty.meta, '0 clips');
      expect(empty.missingText, isNull);
      expect(empty.cover, isNull);
    });

    testWidgets('a reel whose clips are all missing shows them as missing', (
      tester,
    ) async {
      await pumpHome(
        tester,
        reels: [testSummary(1, name: 'Gone', clipCount: 2, missingCount: 2)],
      );

      final card = tester.widget<TtReelCard>(find.byType(TtReelCard));
      expect(card.meta, '2 clips · 0:00');
      expect(card.missingText, '2 missing');
    });

    testWidgets('each card is read as name, status, clips and missing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, reels: mixed());

      final labels = [
        for (final c in tester.widgetList<TtReelCard>(find.byType(TtReelCard)))
          c.semanticLabel,
      ];
      expect(labels, [
        'London Food. Collecting. 3 clips, 2 missing',
        'Day 1 Vlog. Ready to edit. 1 clip',
        'Goa. Published. 12 clips',
        'Empty one. Collecting. 0 clips',
      ]);
      // And that is what a screen reader gets, as one button.
      final node = tester.getSemantics(find.byType(TtReelCard).first);
      expect(node.label, 'London Food. Collecting. 3 clips, 2 missing');
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('card opens reel detail', (tester) async {
      await pumpHome(tester, reels: mixed());

      await tester.tap(find.byType(TtReelCard).at(2));
      await tester.pumpAndSettle();

      expect(find.text(reelRouteMarker(3)), findsOneWidget);
    });

    testWidgets('a double tap on a card opens one reel page', (tester) async {
      await pumpHome(tester, reels: mixed());

      // Two taps in one frame: both reach the card before the page is built.
      await tester.tap(find.byType(TtReelCard).at(2));
      await tester.tap(find.byType(TtReelCard).at(2));
      await tester.pumpAndSettle();

      final page = find.text(reelRouteMarker(3), skipOffstage: false);
      expect(page, findsOneWidget);

      // One Back is enough, and the guard is free again once it returns.
      GoRouter.of(tester.element(find.text(reelRouteMarker(3)))).pop();
      await tester.pumpAndSettle();
      expect(page, findsNothing);
      await tester.tap(find.byType(TtReelCard).at(2));
      await tester.pumpAndSettle();
      expect(find.text(reelRouteMarker(3)), findsOneWidget);
    });

    testWidgets('a long emoji name is on the card, clamped', (tester) async {
      await pumpHome(
        tester,
        reels: [testSummary(1, name: _emojiName, clipCount: 1)],
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TtReelCard>(find.byType(TtReelCard)).name,
        _emojiName,
      );
    });

    testWidgets('20+ reels build lazily', (tester) async {
      await pumpHome(
        tester,
        reels: [for (var i = 25; i >= 1; i--) testSummary(i)],
      );

      final built = tester.widgetList(find.byType(TtReelCard)).length;
      expect(built, greaterThan(0));
      expect(built, lessThan(25));

      // The last one is still reachable.
      await tester.scrollUntilVisible(
        find.text('Reel 1'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Reel 1'), findsWidgets);
    });
  });

  group('a filter with no reels', () {
    final collecting = [testSummary(1), testSummary(2)];
    final published = [testSummary(3, status: ReelStatus.published)];

    Future<void> empty(
      WidgetTester tester,
      List<ReelSummary> reels,
      String chipLabel,
      String title,
      String body,
    ) async {
      await pumpHome(tester, reels: reels);

      await tapChip(tester, chipLabel);

      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(find.byType(TtReelCard), findsNothing);
      expect(
        tester.widget<TtEmptyState>(find.byType(TtEmptyState)).illustration,
        TtIllustrationKind.emptyReel,
      );
      // The chips and the FAB stay.
      expect(find.byType(TtPillTabs<ReelFilter>), findsOneWidget);
      expect(find.byType(TtFab), findsOneWidget);
    }

    testWidgets('Published: its copy and Show all reels', (tester) async {
      await empty(
        tester,
        collecting,
        'Published 0',
        'No reels marked Published',
        'When you post a reel, mark it as Published from its page.',
      );

      await tester.tap(find.widgetWithText(TtButton, 'Show all reels'));
      await tester.pumpAndSettle();

      expect(find.byType(TtReelCard), findsNWidgets(2));
      expect(find.text('No reels marked Published'), findsNothing);
    });

    testWidgets('Ready to edit: its copy', (tester) async {
      await empty(
        tester,
        collecting,
        'Ready to edit 0',
        'No reels marked Ready to edit',
        'When a reel has all its clips, mark it as Ready to edit.',
      );
    });

    testWidgets('Collecting: its copy', (tester) async {
      await empty(
        tester,
        published,
        'Collecting 0',
        'No reels marked Collecting',
        'New reels start as Collecting.',
      );
    });

    testWidgets('Show all reels is tonal and sets All', (tester) async {
      await pumpHome(tester, reels: collecting);
      await tapChip(tester, 'Published 0');

      final show = tester.widget<TtButton>(
        find.widgetWithText(TtButton, 'Show all reels'),
      );
      expect(show.kind, TtButtonKind.tonal);
      final tabs = tester.widget<TtPillTabs<ReelFilter>>(
        find.byType(TtPillTabs<ReelFilter>),
      );
      expect(tabs.value, ReelFilter.published);

      show.onPressed!();
      await tester.pumpAndSettle();

      final after = tester.widget<TtPillTabs<ReelFilter>>(
        find.byType(TtPillTabs<ReelFilter>),
      );
      expect(after.value, ReelFilter.all);
    });
  });

  group('the camera', () {
    testWidgets('camera failure shows the snack (Home)', (tester) async {
      final shooting = await pumpHome(
        tester,
        reels: mixed(),
        shooting: _on(),
        cameraOpens: false,
      );

      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();

      expect(shooting.cameraOpened, 1);
      expect(find.text(_cameraSnack).hitTestable(), findsOneWidget);
    });

    testWidgets('a camera that opens shows no snack', (tester) async {
      final shooting = await pumpHome(tester, reels: mixed(), shooting: _on());

      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();

      expect(shooting.cameraOpened, 1);
      expect(find.text(_cameraSnack), findsNothing);
    });

    testWidgets('the snack lifts the FAB, which drops back after it', (
      tester,
    ) async {
      await pumpHome(
        tester,
        reels: mixed(),
        shooting: _on(),
        cameraOpens: false,
      );
      // The button as it is drawn: the lift moves the paint, not the layout.
      final drawn = find
          .descendant(of: find.byType(TtFab), matching: find.byType(Material))
          .first;
      final before = tester.getRect(drawn);

      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();
      final snack = tester.getRect(find.byType(TtSnack));
      final during = tester.getRect(drawn);
      expect(during.bottom, lessThanOrEqualTo(snack.top - 12 + 0.01));
      expect(during.bottom, lessThan(before.bottom));

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(_cameraSnack), findsNothing);
      expect(tester.getRect(drawn), before);
    });
  });

  group('look', () {
    for (final brightness in Brightness.values) {
      testWidgets('2x text at 360 dp, ${brightness.name}, no overflow', (
        tester,
      ) async {
        await pumpHome(
          tester,
          reels: [
            ...mixed(),
            testSummary(1, name: _emojiName, clipCount: 3, missingCount: 1),
          ],
          shooting: _on(),
          brightness: brightness,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.byType(TtReelCard).last,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('2x text, the empty state fits, ${brightness.name}', (
        tester,
      ) async {
        await pumpHome(tester, brightness: brightness, textScale: 2);

        expect(tester.takeException(), isNull);
      });

      testWidgets('${brightness.name}: with reels, accessible', (tester) async {
        await pumpHome(tester, reels: mixed(), brightness: brightness);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: empty, accessible', (tester) async {
        await pumpHome(tester, brightness: brightness);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: a filter with none, accessible', (
        tester,
      ) async {
        await pumpHome(tester, reels: [testSummary(1)], brightness: brightness);
        await tapChip(tester, 'Published 0');

        await expectTtAccessible(tester);
      });
    }
  });
}
