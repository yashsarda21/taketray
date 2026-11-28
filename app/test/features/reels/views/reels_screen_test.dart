import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/references/view_models/shooting_references.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixed_onboarding.dart';
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

/// One Collecting reel's references, for the References chip.
List<ReferenceGroup> _references(int count) => [
  ReferenceGroup(
    reel: testSummary(90, name: 'Goa'),
    references: [
      for (var i = 0; i < count; i++)
        ReelReference(
          id: i + 1,
          reelId: 90,
          url: 'https://example.com/$i',
          source: ReferenceSource.link,
          createdAt: DateTime.utc(2026),
        ),
    ],
  ),
];

/// Home with fake view models. [reels] null: the list is still loading.
Future<FakeShooting> pumpHome(
  WidgetTester tester, {
  List<ReelSummary>? reels = const [],
  ShootingState shooting = ShootingState.off,
  MediaAccessLevel access = MediaAccessLevel.full,
  bool cameraOpens = true,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool settle = true,
  bool animations = false,
  Map<int, EditorApp> editors = const {},
  Map<int, int> referenceCounts = const {},
  List<ReferenceGroup> references = const [],
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
      mediaAccessControllerProvider.overrideWith(() => FakeAccess(access)),
      pendingClipsProvider.overrideWith((ref) => Stream.value(const [])),
      firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
      reelEditorsProvider.overrideWith((ref) => Stream.value(editors)),
      referenceCountsProvider.overrideWith(
        (ref) => Stream.value(referenceCounts),
      ),
      shootingReferencesProvider.overrideWith(
        (ref) => Stream.value(references),
      ),
      clockProvider.overrideWithValue(FixedClock(_now)),
      onboardingControllerProvider.overrideWith(FixedOnboarding.onboarded),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
    settle: settle,
    animations: animations,
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

Finder get _tabs => find.byType(TtQuietTabs<ReelFilter>);

Finder get _pill => find.descendant(
  of: find.byType(TtLargeSliverAppBar),
  matching: find.byType(TtHeaderPill),
);

/// The tab labelled [label].
Finder tab(String label) =>
    find.descendant(of: _tabs, matching: find.text(label));

/// Taps the tab labelled [label], scrolling the tabs sideways first if it is
/// off the right edge (they scroll, as in the prototype).
Future<void> tapTab(WidgetTester tester, String label) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (tester.getCenter(tab(label)).dx > width - 24) {
    await tester.drag(_tabs, const Offset(-300, 0));
    await tester.pumpAndSettle();
  }
  await tester.tap(tab(label));
  await tester.pumpAndSettle();
}

List<String> cardNames(WidgetTester tester) => [
  for (final c in tester.widgetList<TtReelCard>(find.byType(TtReelCard)))
    c.name,
];

/// The page title while the header is expanded: the copy of "Reels" that is
/// not in the bar's toolbar.
Finder get _expandedTitle => find.byElementPredicate(
  (e) =>
      e.widget is Text &&
      (e.widget as Text).data == 'Reels' &&
      e.findAncestorWidgetOfExactType<NavigationToolbar>() == null,
  description: 'the expanded "Reels" title',
);

/// The screen title in the collapsed bar.
Finder get _toolbarTitle => find.descendant(
  of: find.byType(NavigationToolbar),
  matching: find.text('Reels'),
);

/// Where the header is drawn: the first sliver, so from the top of the
/// screen down to the height it paints (152 dp expanded, 64 collapsed).
Rect _barRect(WidgetTester tester) {
  final sliver = tester.renderObject<RenderSliver>(find.byType(SliverAppBar));
  return Rect.fromLTWH(0, 0, 360, sliver.geometry!.paintExtent);
}

/// `expectTtAccessible` for Home, whose header is expanded at the top
/// (D-195): there Material also builds the bar's small title at opacity 0,
/// text on its own colour (ratio 1), so every text that can be seen is
/// measured and that one alone is left out. Then, when the page can scroll
/// past the 88 dp where the small title shows, the whole helper runs there.
Future<void> expectHomeAccessible(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    final samples = await measureTtTextContrast(tester);
    expect([
      for (final s in samples)
        if (s.ratio <= 1) s.text,
    ], everyElement('Reels'));
    final seen = [
      for (final s in samples)
        if (s.ratio > 1) s,
    ];
    expect(seen, isNotEmpty);
    for (final sample in seen) {
      expect(
        sample.ratio,
        greaterThanOrEqualTo(sample.required - 0.01),
        reason: '$sample',
      );
    }
  } finally {
    semantics.dispose();
  }
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  if (position.maxScrollExtent >= 100) {
    position.jumpTo(100);
    await tester.pumpAndSettle();
    await expectTtAccessible(tester);
  }
}

void main() {
  group('the header', () {
    for (final (name, reels) in [
      ('no reels', const <ReelSummary>[]),
      ('reels', mixed()),
    ]) {
      testWidgets('+ New in the header opens the form, with or without reels; '
          'read "New reel" ($name)', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHome(tester, reels: reels);

        expect(_pill, findsOneWidget);
        final pill = tester.widget<TtHeaderPill>(_pill);
        expect(pill.label, 'New');
        expect(pill.icon, Symbols.add_rounded);
        expect(pill.semanticLabel, 'New reel');
        expect(
          find.descendant(
            of: _pill,
            matching: find.bySemanticsLabel('New reel'),
          ),
          findsOneWidget,
        );
        expect(_pill.hitTestable(), findsOneWidget);

        await tester.tap(_pill);
        await tester.pumpAndSettle();
        expect(find.text('Create reel'), findsOneWidget);
        expect(find.text('Reel name'), findsOneWidget);
        handle.dispose();
      });
    }

    for (final (name, reels) in [
      ('no reels', const <ReelSummary>[]),
      ('reels', mixed()),
      ('loading', null),
    ]) {
      testWidgets('no FAB ($name)', (tester) async {
        await pumpHome(tester, reels: reels);

        expect(find.byType(TtFab), findsNothing);
        expect(_pill, findsOneWidget);
      });
    }

    testWidgets('the title collapses on scroll; + New stays in the bar, '
        'hit-testable', (tester) async {
      await pumpHome(
        tester,
        reels: [for (var i = 25; i >= 1; i--) testSummary(i)],
      );
      expect(_barRect(tester).height, 152);
      expect(_expandedTitle, findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final bar = _barRect(tester);
      expect(bar.height, 64);
      expect(bar.top, 0);
      expect(_pill.hitTestable(), findsOneWidget);
      final pill = tester.getRect(_pill);
      expect(pill.top, greaterThanOrEqualTo(bar.top));
      expect(pill.bottom, lessThanOrEqualTo(bar.bottom));

      await tester.tap(_pill);
      await tester.pumpAndSettle();
      expect(find.text('Create reel'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('2x text, ${brightness.name}: the header title is not '
          'clipped or cut, expanded and collapsed', (tester) async {
        await pumpHome(
          tester,
          reels: [for (var i = 25; i >= 1; i--) testSummary(i)],
          brightness: brightness,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);

        // Expanded: the whole title is inside the bar, on one line.
        final bar = _barRect(tester);
        final title = tester.getRect(_expandedTitle);
        expect(title.top, greaterThanOrEqualTo(bar.top));
        expect(title.bottom, lessThanOrEqualTo(bar.bottom));
        expect(title.left, greaterThanOrEqualTo(0));
        expect(title.right, lessThanOrEqualTo(tester.getRect(_pill).left));
        final expanded = tester.renderObject<RenderParagraph>(_expandedTitle);
        expect(expanded.didExceedMaxLines, isFalse);

        // Collapsed: the screen title fits the 64 dp bar, before + New.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final small = _barRect(tester);
        expect(small.height, 64);
        final collapsed = tester.getRect(_toolbarTitle);
        expect(collapsed.top, greaterThanOrEqualTo(small.top));
        expect(collapsed.bottom, lessThanOrEqualTo(small.bottom));
        expect(collapsed.right, lessThanOrEqualTo(tester.getRect(_pill).left));
        expect(
          tester.renderObject<RenderParagraph>(_toolbarTitle).didExceedMaxLines,
          isFalse,
        );
        expect(_pill.hitTestable(), findsOneWidget);
      });
    }
  });

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

    testWidgets('tabs hidden with no reels', (tester) async {
      await pumpHome(tester);

      expect(_tabs, findsNothing);
      expect(find.text('Collecting'), findsNothing);
      expect(find.text('Published'), findsNothing);
    });

    testWidgets('while the list loads nothing says "no reels" yet', (
      tester,
    ) async {
      await pumpHome(tester, reels: null);

      expect(find.text('Plan your first reel'), findsNothing);
      expect(find.byType(TtFab), findsNothing);
      expect(find.byType(TtReelCard), findsNothing);
      expect(_tabs, findsNothing);
      // The Shooting mode card and the header are there all the same.
      expect(find.text('Shooting mode'), findsOneWidget);
      expect(_pill, findsOneWidget);
    });
  });

  group('with reels', () {
    testWidgets('the screen is in order: header, banner, Shooting mode, tabs, '
        'cards', (tester) async {
      await pumpHome(tester, reels: mixed(), access: MediaAccessLevel.limited);

      final header = _barRect(tester).bottom;
      final banner = tester.getTopLeft(find.byType(TtBanner)).dy;
      final shooting = tester.getTopLeft(find.byType(TtShootingModeCard)).dy;
      final tabs = tester.getTopLeft(_tabs).dy;
      final firstCard = tester.getTopLeft(find.byType(TtReelCard).first).dy;
      expect(header, lessThanOrEqualTo(banner));
      expect(banner, lessThan(shooting));
      expect(shooting, lessThan(tabs));
      expect(tabs, lessThan(firstCard));
      expect(find.byType(TtLargeSliverAppBar), findsOneWidget);
      expect(find.byType(TtAppBar), findsNothing);
      expect(
        tester
            .widget<TtLargeSliverAppBar>(find.byType(TtLargeSliverAppBar))
            .title,
        'Reels',
      );
    });

    testWidgets('tabs: All 4, Collecting 2, Ready 1, Published 1; All chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, reels: mixed());

      final tabs = tester.widget<TtQuietTabs<ReelFilter>>(_tabs);
      expect(tabs.semanticLabel, 'Show reels');
      expect(tabs.value, ReelFilter.all);
      expect(
        [for (final t in tabs.tabs) (t.value, t.label, t.count)],
        [
          (ReelFilter.all, 'All', 4),
          (ReelFilter.collecting, 'Collecting', 2),
          (ReelFilter.ready, 'Ready', 1),
          (ReelFilter.published, 'Published', 1),
        ],
      );
      expect(
        [for (final t in tabs.tabs) t.semanticLabel],
        [
          'All, 4 reels',
          'Collecting, 2 reels',
          'Ready to edit, 1 reel',
          'Published, 1 reel',
        ],
      );
      expect(find.bySemanticsLabel('Show reels'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a tab narrows the cards, and the counts do not change', (
      tester,
    ) async {
      await pumpHome(tester, reels: mixed());
      expect(find.byType(TtReelCard), findsNWidgets(4));

      await tapTab(tester, 'Collecting');
      expect(cardNames(tester), ['London Food', 'Empty one']);
      expect(
        tester.widget<TtQuietTabs<ReelFilter>>(_tabs).value,
        ReelFilter.collecting,
      );
      // The counts do not change with the filter.
      expect(
        [
          for (final t in tester.widget<TtQuietTabs<ReelFilter>>(_tabs).tabs)
            t.count,
        ],
        [4, 2, 1, 1],
      );
    });

    testWidgets('a tab with no reels says "No reels marked Published yet." '
        'and offers Show all reels', (tester) async {
      await pumpHome(tester, reels: [testSummary(1), testSummary(2)]);
      await tapTab(tester, 'Published');

      expect(find.byType(TtReelCard), findsNothing);
      final words = find.text('No reels marked Published yet.');
      expect(words, findsOneWidget);
      final text = tester.widget<Text>(words);
      final context = tester.element(words);
      expect(text.textAlign, TextAlign.center);
      expect(
        text.style?.fontSize,
        Theme.of(context).textTheme.bodyMedium!.fontSize,
      );
      expect(text.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
      expect(find.byType(TtEmptyState), findsNothing);
      // The tabs stay, and no FAB comes back.
      expect(_tabs, findsOneWidget);
      expect(find.byType(TtFab), findsNothing);

      final show = find.widgetWithText(TtButton, 'Show all reels');
      expect(tester.widget<TtButton>(show).kind, TtButtonKind.tonal);
      // home2.css:46: .h2-none { margin: 24px 16px; gap: 8px }: the words
      // sit 24 dp under the tabs, and the button 8 dp under the words.
      expect(tester.getTopLeft(words).dy - tester.getBottomLeft(_tabs).dy, 24);
      expect(tester.getTopLeft(show).dy - tester.getBottomLeft(words).dy, 8);

      await tester.tap(show);
      await tester.pumpAndSettle();

      expect(find.byType(TtReelCard), findsNWidgets(2));
      expect(find.text('No reels marked Published yet.'), findsNothing);
      expect(
        tester.widget<TtQuietTabs<ReelFilter>>(_tabs).value,
        ReelFilter.all,
      );
    });

    testWidgets('an empty tab names its status in full: Ready to edit', (
      tester,
    ) async {
      await pumpHome(tester, reels: [testSummary(1)]);
      await tapTab(tester, 'Ready');

      expect(find.text('No reels marked Ready to edit yet.'), findsOneWidget);
    });

    testWidgets('two columns, 16 × 12, top aligned: a two-line name does not '
        'stretch its neighbour', (tester) async {
      await pumpHome(
        tester,
        reels: [
          testSummary(3, name: 'A reel with a name long enough for two lines'),
          testSummary(2, name: 'Short'),
          testSummary(1, name: 'Third'),
        ],
      );

      final cards = find.byType(TtReelCard);
      final long = tester.getRect(cards.at(0));
      final short = tester.getRect(cards.at(1));
      final third = tester.getRect(cards.at(2));
      // Padding 0 16 and a 12 dp gap between the two columns.
      expect(long.left, 16);
      expect(short.right, 360 - 16);
      expect(short.left - long.right, 12);
      expect(long.width, (360 - 32 - 12) / 2);
      expect(short.width, long.width);
      // Top aligned, each card its own height.
      expect(short.top, long.top);
      expect(long.height, greaterThan(short.height));
      // The next row is 16 dp under the taller card of the row above.
      expect(third.top - long.bottom, 16);
      expect(third.left, 16);
    });

    testWidgets('2x text: one column', (tester) async {
      await pumpHome(tester, reels: mixed(), textScale: 2);

      final first = tester.getRect(find.byType(TtReelCard).first);
      expect(first.left, 16);
      expect(first.width, 360 - 32);
      await tester.scrollUntilVisible(
        find.text('Day 1 Vlog'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final second = tester.getRect(find.byType(TtReelCard).at(1));
      expect(second.left, 16);
      expect(second.width, 360 - 32);
      expect(
        second.top - tester.getRect(find.byType(TtReelCard).at(0)).bottom,
        16,
      );
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
      expect(_missingOf(london), '2 missing');

      final vlog = cards[1];
      expect(vlog.cover, isNull);
      expect(vlog.status, TtStatusKind.ready);
      expect(vlog.statusLabel, 'Ready to edit');
      expect(vlog.meta, '1 clip · 0:00');
      expect(_missingOf(vlog), isNull);

      final goa = cards[2];
      expect(goa.status, TtStatusKind.published);
      expect(goa.statusLabel, 'Published');
      expect(goa.meta, '12 clips · 1:02:05');

      final empty = cards[3];
      expect(empty.meta, 'No clips yet');
      expect(_missingOf(empty), isNull);
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
      expect(_missingOf(card), '2 missing');
    });

    testWidgets('the card is read "London Food. Collecting. 14 clips, 2 '
        'missing. Editing in VN. 2 references"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(
        tester,
        reels: [
          testSummary(5, name: 'London Food', clipCount: 14, missingCount: 2),
          testSummary(4, name: 'Goa', clipCount: 1),
        ],
        editors: {5: EditorApp.vn},
        referenceCounts: {5: 2, 4: 1},
      );

      const london =
          'London Food. Collecting. 14 clips, 2 missing. Editing in VN. '
          '2 references';
      expect(
        tester.widget<TtReelCard>(find.byType(TtReelCard).first).semanticLabel,
        london,
      );
      final node = tester.getSemantics(find.byType(TtReelCard).first);
      expect(node.label, london);
      expect(node.flagsCollection.isButton, isTrue);
      expect(
        tester.widget<TtReelCard>(find.byType(TtReelCard).at(1)).semanticLabel,
        'Goa. Collecting. 1 clip. 1 reference',
      );
      handle.dispose();
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
      handle.dispose();
    });

    testWidgets('notes: In VN, 2 missing, 2; none for a plain reel', (
      tester,
    ) async {
      await pumpHome(
        tester,
        reels: [
          testSummary(5, name: 'London Food', clipCount: 14, missingCount: 2),
          testSummary(4, name: 'Plain', clipCount: 3),
        ],
        editors: {5: EditorApp.vn},
        referenceCounts: {5: 2},
      );

      final cards = tester
          .widgetList<TtReelCard>(find.byType(TtReelCard))
          .toList();
      expect(cards[0].notes.map((n) => (n.kind, n.text)), [
        (TtReelCardNoteKind.editing, 'In VN'),
        (TtReelCardNoteKind.missing, '2 missing'),
        (TtReelCardNoteKind.references, '2'),
      ]);
      expect(cards[1].notes, isEmpty);
    });

    testWidgets('a reel being edited shows its editor on the card, and is '
        'read with it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(
        tester,
        reels: mixed(),
        editors: {5: EditorApp.vn, 4: EditorApp.capcut, 3: EditorApp.edits},
      );

      final cards = tester
          .widgetList<TtReelCard>(find.byType(TtReelCard))
          .toList();
      expect(
        [for (final c in cards) _editingOf(c)],
        ['In VN', 'In CapCut', 'In Edits', null],
      );
      expect(
        [for (final c in cards) c.semanticLabel],
        [
          'London Food. Collecting. 3 clips, 2 missing. Editing in VN',
          'Day 1 Vlog. Ready to edit. 1 clip. Editing in CapCut',
          'Goa. Published. 12 clips. Editing in Edits',
          'Empty one. Collecting. 0 clips',
        ],
      );
      handle.dispose();
    });

    testWidgets('while the sessions are not known, no card has a note', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ReelsScreen(),
        overrides: <Override>[
          reelSummariesProvider.overrideWith((ref) => Stream.value(mixed())),
          shootingModeControllerProvider.overrideWith(
            () => FakeShooting(ShootingState.off),
          ),
          mediaAccessControllerProvider.overrideWith(
            () => FakeAccess(MediaAccessLevel.full),
          ),
          pendingClipsProvider.overrideWith((ref) => Stream.value(const [])),
          firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
          reelEditorsProvider.overrideWith((ref) => const Stream.empty()),
          referenceCountsProvider.overrideWith((ref) => Stream.value(const {})),
          clockProvider.overrideWithValue(FixedClock(_now)),
          onboardingControllerProvider.overrideWith(FixedOnboarding.onboarded),
          thumbnailCacheForTests,
        ],
      );

      expect(find.byType(TtReelCard), findsNWidgets(4));
      expect([
        for (final c in tester.widgetList<TtReelCard>(find.byType(TtReelCard)))
          _editingOf(c),
      ], everyElement(isNull));
    });

    testWidgets('card opens reel detail', (tester) async {
      await pumpHome(tester, reels: mixed());

      await tester.tap(find.byType(TtReelCard).at(2));
      await tester.pumpAndSettle();

      expect(find.text(reelRouteMarker(3)), findsOneWidget);
    });

    testWidgets('a card press scales to .98 and opens the reel once (double '
        'tap too)', (tester) async {
      await pumpHome(
        tester,
        reels: [
          testSummary(2, name: 'Goa'),
          testSummary(1, name: 'Lisbon'),
        ],
        animations: true,
      );
      final card = find.byType(TtReelCard).first;
      double scale() => tester
          .widget<AnimatedScale>(
            find.descendant(of: card, matching: find.byType(AnimatedScale)),
          )
          .scale;
      expect(scale(), 1);

      final press = await tester.startGesture(tester.getCenter(card));
      // The press shows once the tap is sure not to be a scroll.
      await tester.pump(kPressTimeout);
      await tester.pump();
      expect(scale(), 0.98);
      await press.up();
      await tester.pumpAndSettle();
      expect(find.text(reelRouteMarker(2)), findsOneWidget);

      // Back, then two taps in one frame: one page.
      GoRouter.of(tester.element(find.text(reelRouteMarker(2)))).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(
        find.text(reelRouteMarker(2), skipOffstage: false),
        findsOneWidget,
      );
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

    for (final animations in [true, false]) {
      testWidgets('switching tabs fades the grid in over short4 '
          '(${animations ? 'motion' : 'reduced motion: a crossfade still'})', (
        tester,
      ) async {
        await pumpHome(
          tester,
          reels: [
            testSummary(3, name: 'Goa'),
            testSummary(2, name: 'Lisbon', status: ReelStatus.published),
            testSummary(1, name: 'Paris'),
          ],
          animations: animations,
        );
        double opacity() => tester
            .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
            .opacity
            .value;
        // No fade on the first build.
        expect(opacity(), 1);

        await tester.tap(tab('Collecting'));
        await tester.pump();
        expect(opacity(), 0);
        final left = tester.getTopLeft(find.byType(TtReelCard).first).dx;

        await tester.pump(const Duration(milliseconds: 100));
        expect(opacity(), inExclusiveRange(0, 1));
        // Nothing slides: the first card is where it will stay.
        expect(tester.getTopLeft(find.byType(TtReelCard).first).dx, left);

        await tester.pump(const Duration(milliseconds: 100));
        expect(opacity(), 1);
        expect(cardNames(tester), ['Goa', 'Paris']);
        expect(tester.getTopLeft(find.byType(TtReelCard).first).dx, left);
      });
    }

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

    testWidgets('the last row clears the nav pill', (tester) async {
      await pumpHome(
        tester,
        reels: [for (var i = 25; i >= 1; i--) testSummary(i)],
      );

      await tester.scrollUntilVisible(
        find.text('Reel 1'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ReelsScreen));
      final last = tester.getRect(find.byType(TtReelCard).last);
      expect(
        last.bottom,
        lessThanOrEqualTo(800 - TtNavPill.reservedHeight(context)),
      );
    });
  });

  group('photos on the card (Phase 13, D-200)', () {
    TtReelCard card(WidgetTester tester) =>
        tester.widget<TtReelCard>(find.byType(TtReelCard));

    testWidgets('card: "8 clips · 2 photos · 2:10", read "Goa. Collecting. '
        '8 clips and 2 photos"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(
        tester,
        reels: [
          testSummary(
            1,
            name: 'Goa',
            clipCount: 10,
            photoCount: 2,
            liveDurationMs: 130000,
          ),
        ],
      );

      expect(card(tester).meta, '8 clips · 2 photos · 2:10');
      expect(
        card(tester).semanticLabel,
        'Goa. Collecting. 8 clips and 2 photos',
      );
      expect(
        tester.getSemantics(find.byType(TtReelCard)).label,
        'Goa. Collecting. 8 clips and 2 photos',
      );
      handle.dispose();
    });

    testWidgets('with a missing photo: "…, 1 missing"; the editing and '
        'references parts follow', (tester) async {
      await pumpHome(
        tester,
        reels: [
          testSummary(
            1,
            name: 'Goa',
            clipCount: 10,
            photoCount: 2,
            missingCount: 1,
            liveDurationMs: 130000,
          ),
        ],
        editors: {1: EditorApp.vn},
        referenceCounts: {1: 2},
      );

      expect(card(tester).meta, '8 clips · 2 photos · 2:10');
      expect(_missingOf(card(tester)), '1 missing');
      expect(
        card(tester).semanticLabel,
        'Goa. Collecting. 8 clips and 2 photos, 1 missing. Editing in VN. '
        '2 references',
      );
    });

    testWidgets('photos only: the card "2 photos", read "Goa. Collecting. 2 '
        'photos"', (tester) async {
      await pumpHome(
        tester,
        reels: [testSummary(1, name: 'Goa', clipCount: 2, photoCount: 2)],
      );

      expect(card(tester).meta, '2 photos');
      expect(card(tester).semanticLabel, 'Goa. Collecting. 2 photos');
    });

    testWidgets('one video and one photo: "1 clip · 1 photo · 0:04"', (
      tester,
    ) async {
      await pumpHome(
        tester,
        reels: [
          testSummary(
            1,
            name: 'Goa',
            clipCount: 2,
            photoCount: 1,
            liveDurationMs: 4000,
          ),
        ],
      );

      expect(card(tester).meta, '1 clip · 1 photo · 0:04');
      expect(card(tester).semanticLabel, 'Goa. Collecting. 1 clip and 1 photo');
    });
  });

  group('references on the card (D-158, D-196)', () {
    Map<String, String?> countsByName(WidgetTester tester) => {
      for (final c in tester.widgetList<TtReelCard>(find.byType(TtReelCard)))
        c.name: _noteOf(c, TtReelCardNoteKind.references),
    };

    String location(WidgetTester tester, int reelId) =>
        GoRouterState.of(tester.element(find.text(reelRouteMarker(reelId)))).uri
            .toString();

    testWidgets("each card counts its own reel's references; none is no "
        'note', (tester) async {
      await pumpHome(tester, reels: mixed(), referenceCounts: {5: 2, 3: 1});

      expect(countsByName(tester), {
        'London Food': '2',
        'Day 1 Vlog': null,
        'Goa': '1',
        'Empty one': null,
      });
    });

    testWidgets('a count for no shown reel gives no note', (tester) async {
      await pumpHome(tester, reels: mixed(), referenceCounts: {99: 4});

      expect(countsByName(tester).values, everyElement(isNull));
    });

    testWidgets('no references button of its own: the card opens the reel '
        'page, not its References section', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, reels: mixed(), referenceCounts: {5: 2});

      expect(find.textContaining('open them'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('open them')), findsNothing);

      await tester.tap(find.text('London Food'));
      await tester.pumpAndSettle();

      expect(find.text(reelRouteMarker(5)), findsOneWidget);
      expect(location(tester, 5), '/reels/5');
      handle.dispose();
    });

    testWidgets('the cards with references pass the accessibility checks', (
      tester,
    ) async {
      await pumpHome(tester, reels: mixed(), referenceCounts: {5: 2, 4: 12});

      await expectHomeAccessible(tester);
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
  });

  group('look', () {
    for (final brightness in Brightness.values) {
      testWidgets('2x text at 360 with Shooting mode on, both chips and a '
          'long name: one column, no overflow, + New reachable, '
          '${brightness.name}', (tester) async {
        await pumpHome(
          tester,
          reels: [
            ...mixed(),
            testSummary(1, name: _emojiName, clipCount: 3, missingCount: 1),
          ],
          shooting: _on(),
          brightness: brightness,
          textScale: 2,
          editors: {5: EditorApp.capcut, 1: EditorApp.edits},
          referenceCounts: {5: 3, 1: 12},
          references: _references(4),
        );
        expect(tester.takeException(), isNull);
        final shootingCard = tester.widget<TtShootingModeCard>(
          find.byType(TtShootingModeCard),
        );
        expect(
          [for (final c in shootingCard.chips) c.label],
          ['References · 4', 'Earlier videos'],
        );
        expect(_pill.hitTestable(), findsOneWidget);
        final cardRect = tester.getRect(find.byType(TtShootingModeCard));
        expect(cardRect.right, lessThanOrEqualTo(360));

        await tester.scrollUntilVisible(
          find.byType(TtReelCard).last,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        for (final e in find.byType(TtReelCard).evaluate()) {
          final rect = tester.getRect(find.byElementPredicate((x) => x == e));
          expect(rect.width, 360 - 32);
          expect(rect.left, 16);
        }
        expect(_pill.hitTestable(), findsOneWidget);
      });

      testWidgets('2x text, the empty state fits, ${brightness.name}', (
        tester,
      ) async {
        await pumpHome(tester, brightness: brightness, textScale: 2);

        expect(tester.takeException(), isNull);
      });

      testWidgets('${brightness.name}: with reels, accessible', (tester) async {
        await pumpHome(tester, reels: mixed(), brightness: brightness);

        await expectHomeAccessible(tester);
      });

      testWidgets('${brightness.name}: empty, accessible', (tester) async {
        await pumpHome(tester, brightness: brightness);

        await expectHomeAccessible(tester);
      });

      testWidgets('${brightness.name}: a tab with none, accessible', (
        tester,
      ) async {
        await pumpHome(tester, reels: [testSummary(1)], brightness: brightness);
        await tapTab(tester, 'Published');

        await expectHomeAccessible(tester);
      });
    }
  });
}

/// The text of a card's note of [kind], or null when it has none.
String? _noteOf(TtReelCard card, TtReelCardNoteKind kind) =>
    card.notes.where((n) => n.kind == kind).map((n) => n.text).firstOrNull;

String? _missingOf(TtReelCard card) =>
    _noteOf(card, TtReelCardNoteKind.missing);

String? _editingOf(TtReelCard card) =>
    _noteOf(card, TtReelCardNoteKind.editing);
