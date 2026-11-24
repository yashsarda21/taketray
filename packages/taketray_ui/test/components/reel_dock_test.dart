import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/player_scrims.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_glass_pixels.dart';
import '../support/tt_test_app.dart';
import '../support/tt_text_contrast.dart';

// TtReelDock, the header chevrons and the two scrims (Phase 12, Task 8,
// D-179): the bottom of the full-screen tag player. The values are
// player2.css's; the glass of the chips is measured in
// glass_pixels_test.dart (D-178).

const _phone = Size(360, 800);

void _viewport(WidgetTester tester) {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [child] in the player's own (always dark) theme.
Widget _player(Widget child) =>
    Theme(data: TakeTrayTheme.video(), child: child);

TtReelChip _chip(int n, {String? name}) => TtReelChip(
  name: name ?? 'Reel $n',
  countText: '$n clips',
  semanticLabel: 'Add to Reel $n, $n clips',
  style: TtReelChipStyle.onVideo,
  onTap: () {},
);

TtNewReelChip _newChip({bool fullWidth = false}) => TtNewReelChip(
  title: 'New reel',
  semanticLabel: 'New reel',
  fullWidth: fullWidth,
  style: TtReelChipStyle.onVideo,
  onTap: () {},
);

TtButton _action(String label, {IconData? icon}) => TtButton(
  label: label,
  icon: icon,
  kind: TtButtonKind.text,
  size: TtButtonSize.small,
  onPressed: () {},
);

const _black = Color(0xFF000000);
const _scrubKey = ValueKey<String>('scrub');
const _footerKey = ValueKey<String>('footer');

TtReelDock _dock({
  String title = 'Add to reel',
  List<Widget>? chips,
  Widget? scrub,
  List<Widget> actions = const [],
  String? emptyText,
  Widget? footer,
}) => TtReelDock(
  title: title,
  semanticLabel: 'Reels',
  chips: chips ?? [for (var i = 1; i <= 4; i++) _chip(i)],
  scrub: scrub,
  actions: actions,
  emptyText: emptyText,
  footer: footer,
);

/// The dock at the bottom of the page, in the player's theme.
Widget _atBottom(Widget dock) => _player(
  Align(
    alignment: Alignment.bottomLeft,
    child: SizedBox(width: 360, child: dock),
  ),
);

/// [child] on a pure white frame, the worst case for a clip under it.
Widget _onWhite(Widget child) => ColoredBox(
  color: const Color(0xFFFFFFFF),
  child: Align(alignment: Alignment.bottomCenter, child: child),
);

Finder get _grid => find.descendant(
  of: find.byType(TtReelDock),
  matching: find.byType(SingleChildScrollView),
);

Finder _inDock(Finder matching) =>
    find.descendant(of: find.byType(TtReelDock), matching: matching);

Future<List<TtTextContrastSample>> _contrast(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    return await measureTtTextContrast(tester);
  } finally {
    semantics.dispose();
  }
}

CustomPaint _paintOf(WidgetTester tester, Type owner, Type painter) {
  final paints = find
      .descendant(of: find.byType(owner), matching: find.byType(CustomPaint))
      .evaluate()
      .map((e) => e.widget as CustomPaint)
      .where((p) => p.painter.runtimeType == painter);
  expect(paints, hasLength(1), reason: '$painter in $owner');
  return paints.single;
}

/// Whether a touch at [at] reaches a [RenderCustomPaint] drawing [painter].
bool _touchReachesPainter(WidgetTester tester, Offset at, Type painter) {
  final result = tester.hitTestOnBinding(at);
  return result.path.any((entry) {
    final target = entry.target;
    return target is RenderCustomPaint && target.painter.runtimeType == painter;
  });
}

void main() {
  group('TtMetrics, from player2.css', () {
    test('the dock and the scrims', () {
      expect(TtMetrics.reelDockPaddingTop, 28);
      expect(TtMetrics.reelDockPaddingSide, 12);
      expect(TtMetrics.reelDockPaddingBottom, 22);
      expect(TtMetrics.reelDockGap, 8);
      expect(TtMetrics.reelDockScrimMidOpacity, 0.74);
      expect(TtMetrics.reelDockScrimMidAt, 26);
      expect(TtMetrics.reelDockScrimEndOpacity, 0.90);
      expect(TtMetrics.reelDockScrimEndStop, 0.5);
      expect(TtMetrics.reelDockHeaderHeight, 40);
      expect(TtMetrics.reelDockGridGap, 8);
      expect(TtMetrics.reelDockFooterGap, 4);
      expect(TtMetrics.reelDockGridMaxHeight, 260);
      expect(TtMetrics.reelDockSingleColumnTextScale, 1.5);
      expect(TtMetrics.playerTopScrimStartOpacity, 0.78);
      expect(TtMetrics.playerTopScrimHoldOpacity, 0.70);
      expect(TtMetrics.playerTopScrimFade, 24);
      expect(TtMetrics.playerChevronDisabledOpacity, 0.35);
      expect(TtMetrics.playerChevronTitlePadding, 2);
    });
  });

  group('TtReelDock layout', () {
    testWidgets('padding 28 / 12 / 22 plus the gesture inset, rows 8 apart', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: const EdgeInsets.only(bottom: 34)),
              child: _atBottom(
                _dock(
                  scrub: const SizedBox(key: _scrubKey, height: 22),
                  chips: [_chip(1), _chip(2)],
                  footer: const SizedBox(key: _footerKey, height: 48),
                ),
              ),
            ),
          ),
        ),
      );
      final dock = tester.getRect(find.byType(TtReelDock));
      final scrub = tester.getRect(find.byKey(_scrubKey));
      // 28 above the first row and 12 at each side (the scrub has 4 more).
      expect(scrub.top - dock.top, 28);
      expect(dock.width, 360);
      expect(scrub.left - dock.left, 12 + 4);
      expect(dock.right - scrub.right, 12 + 4);
      // The scrub has 2 dp under it, then 8 to the header.
      final title = tester.getRect(find.text('Add to reel'));
      final chip = tester.getRect(find.byType(TtReelChip).first);
      // The header is 40 dp high, its title in the middle: 2 + 8 under the
      // scrub, then 8 more to the grid.
      expect(title.center.dy, closeTo(scrub.bottom + 2 + 8 + 20, 0.5));
      expect(chip.top, closeTo(scrub.bottom + 2 + 8 + 40 + 8, 0.5));
      // The footer is 8 under the grid and has 4 dp of its own above it.
      final footer = tester.getRect(find.byKey(_footerKey));
      final lastChip = tester.getRect(find.byType(TtReelChip).last);
      expect(footer.top - lastChip.bottom, 8 + 4);
      // 22 under the footer plus the 34 of the gesture inset.
      expect(dock.bottom - footer.bottom, 22 + 34);
      expect(footer.left - dock.left, 12);
    });

    testWidgets('without a gesture inset the bottom padding is 22', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_atBottom(_dock(footer: const SizedBox(key: _footerKey)))),
      );
      final dock = tester.getRect(find.byType(TtReelDock));
      expect(dock.bottom - tester.getRect(find.byKey(_footerKey)).bottom, 22);
    });

    testWidgets('the header is at least 40 dp high and the title takes the '
        'room the actions leave', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _atBottom(
            _dock(
              title: 'Pick reels',
              actions: [
                _action('All reels', icon: Symbols.apps_rounded),
                _action('Cancel'),
              ],
            ),
          ),
        ),
      );
      final title = tester.getRect(find.text('Pick reels'));
      final all = tester.getRect(find.text('All reels'));
      final cancel = tester.getRect(find.text('Cancel'));
      // The title is first, the actions follow in order at the end.
      expect(title.left, 12 + 4);
      expect(all.left, greaterThan(title.right));
      expect(cancel.left, greaterThan(all.right));
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('two columns of 164 dp at 360, 8 apart', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _atBottom(_dock(chips: [for (var i = 1; i <= 4; i++) _chip(i)])),
        ),
      );
      final chips = find.byType(TtReelChip);
      final a = tester.getRect(chips.at(0));
      final b = tester.getRect(chips.at(1));
      final c = tester.getRect(chips.at(2));
      expect(a.width, 164);
      expect(b.width, 164);
      expect(b.left - a.right, 8);
      expect(a.left, 12);
      expect(b.right, 348);
      expect(c.left, a.left);
      expect(c.top - a.bottom, 8);
      expect(a.top, b.top);
    });

    testWidgets('an odd chip leaves its row half empty, not stretched', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_atBottom(_dock(chips: [_chip(1), _chip(2), _chip(3)]))),
      );
      expect(tester.getSize(find.byType(TtReelChip).last).width, 164);
    });

    testWidgets('a full-width New reel takes a row, under the empty text', (
      tester,
    ) async {
      const empty =
          "You don't have any reels yet. Create one and this clip goes "
          'into it.';
      await tester.pumpWidget(
        ttTestApp(
          _atBottom(
            _dock(chips: [_newChip(fullWidth: true)], emptyText: empty),
          ),
        ),
      );
      final text = tester.getRect(find.text(empty));
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.width, 336);
      expect(chip.left, 12);
      // 8 of padding round the text, then the grid's 8.
      expect(chip.top, closeTo(text.bottom + 8 + 8, 0.5));
      // Centred, in white at 85 %.
      expect(text.center.dx, closeTo(180, 0.5));
      final style = tester.widget<Text>(find.text(empty)).style!;
      expect(style.color!.a, closeTo(0.85, 0.005));
      expect(style.color!.r, 1);
      expect(tester.widget<Text>(find.text(empty)).textAlign, TextAlign.center);
    });

    testWidgets('a New reel between two chips ends the row before it', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _atBottom(
            _dock(
              chips: [_chip(1), _chip(2), _chip(3), _newChip(fullWidth: true)],
            ),
          ),
        ),
      );
      final third = tester.getRect(find.byType(TtReelChip).last);
      final fresh = tester.getRect(find.byType(TtNewReelChip));
      expect(third.width, 164);
      expect(fresh.width, 336);
      expect(fresh.top - third.bottom, 8);
    });

    testWidgets('a half-width New reel sits in the grid like a chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _atBottom(_dock(chips: [_chip(1), _chip(2), _chip(3), _newChip()])),
        ),
      );
      expect(tester.getSize(find.byType(TtNewReelChip)).width, 164);
    });
  });

  group('TtReelDock semantics', () {
    testWidgets('one group named Reels; the title is a heading and every '
        'chip its own node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_atBottom(_dock())));
      final group = tester.getSemantics(find.byType(TtReelDock));
      expect(group.label, 'Reels');
      final title = tester.getSemantics(find.text('Add to reel'));
      expect(title.getSemanticsData().flagsCollection.isHeader, isTrue);
      expect(
        tester.getSemantics(find.byType(TtReelChip).first).label,
        'Add to Reel 1, 1 clips',
      );
      handle.dispose();
    });

    testWidgets(
      'the actions and the footer are TtButtons (Patrol finds them)',
      (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            _atBottom(
              _dock(
                actions: [_action('Pick several'), _action('All reels')],
                footer: TtButton(
                  label: 'Add to 2 reels & next',
                  expand: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        expect(_inDock(find.byType(TtButton)), findsNWidgets(3));
      },
    );
  });

  group('the dock scrim', () {
    test('stops: 0 at the top, .74 at 26 dp, .90 from half way (h = 300)', () {
      final g = const DockScrimPainter(_black).gradientFor(300);
      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.stops, [0, 26 / 300, 0.5, 1]);
      expect(g.colors.map((c) => c.a), [0, 0.74, 0.90, 0.90]);
      for (final c in g.colors) {
        expect([c.r, c.g, c.b], [0, 0, 0]);
      }
    });

    test('a short dock clamps the 26 dp stop to half way (h = 40)', () {
      final g = const DockScrimPainter(_black).gradientFor(40);
      expect(g.stops, [0, 0.5, 0.5, 1]);
      // Stops never run backwards, or the gradient is undefined.
      for (var i = 1; i < g.stops!.length; i++) {
        expect(g.stops![i], greaterThanOrEqualTo(g.stops![i - 1]));
      }
    });

    test('at exactly 52 dp the 26 dp stop is half way', () {
      expect(const DockScrimPainter(_black).gradientFor(52).stops, [
        0,
        0.5,
        0.5,
        1,
      ]);
    });

    test('a dock of no height has no gradient to draw', () {
      expect(const DockScrimPainter(_black).gradientFor(0).stops, [
        0,
        0.5,
        0.5,
        1,
      ]);
    });

    testWidgets('is painted behind the content, takes no touch and is not '
        'announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_atBottom(_dock())));
      final paint = _paintOf(tester, TtReelDock, DockScrimPainter);
      expect(paint.painter, isA<DockScrimPainter>());
      // Behind: a painter, not a foreground painter.
      expect(paint.foregroundPainter, isNull);
      expect(paint.painter!.hitTest(const Offset(10, 10)), isFalse);
      expect(paint.painter!.semanticsBuilder, isNull);
      final dock = tester.getRect(find.byType(TtReelDock));
      // Inside the 28 dp of padding, over nothing but the scrim.
      expect(
        _touchReachesPainter(
          tester,
          Offset(180, dock.top + 10),
          DockScrimPainter,
        ),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('draws .74 black at 26 dp, .90 from half way and clear at the '
        'top, over white', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttPixelApp(
          _onWhite(
            _dock(
              chips: [for (var i = 1; i <= 6; i++) _chip(i)],
              footer: const SizedBox(height: 48),
            ),
          ),
        ),
      );
      final pixels = await TtPixels.capture(tester);
      final dock = tester.getRect(find.byType(TtReelDock));
      expect(dock.height, greaterThan(52));
      double blackShare(double y) =>
          1 - pixels.colorAt(Offset(2, y)).r; // over white: 1 - alpha
      expect(blackShare(dock.top), closeTo(0, 0.04));
      expect(blackShare(dock.top + 26), closeTo(0.74, 0.02));
      expect(blackShare(dock.top + dock.height * 0.5 + 6), closeTo(0.90, 0.02));
      expect(blackShare(dock.bottom - 2), closeTo(0.90, 0.02));
    });

    testWidgets('a short dock (under 52 dp) paints without error', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttPixelApp(
          _onWhite(
            const TtReelDock(
              title: 'Pick reels',
              semanticLabel: 'Reels',
              chips: [],
            ),
          ),
        ),
      );
      await TtPixels.capture(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('contrast over a white frame', () {
    testWidgets('the dock text, the chips and the actions read AA, the title '
        'at 10:1 class', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttPixelApp(
          _player(
            _onWhite(
              _dock(
                title: 'Pick reels',
                actions: [
                  _action('All reels', icon: Symbols.apps_rounded),
                  _action('Cancel'),
                ],
                chips: [_chip(1), _chip(2), _chip(3), _newChip()],
                footer: TtButton(
                  label: 'Add to 2 reels & next',
                  expand: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final samples = await _contrast(tester);
      expect(samples, isNotEmpty);
      for (final sample in samples) {
        expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
      }
      final title = samples.singleWhere((s) => s.text == 'Pick reels');
      expect(title.ratio, greaterThan(9));
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
      semantics.dispose();
    });

    testWidgets('the empty text reads AA over the scrim', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttPixelApp(
          _player(
            _onWhite(
              _dock(
                chips: [_newChip(fullWidth: true)],
                emptyText: "You don't have any reels yet.",
              ),
            ),
          ),
        ),
      );
      final samples = await _contrast(tester);
      final empty = samples.singleWhere(
        (s) => s.text == "You don't have any reels yet.",
      );
      expect(empty.ratio, greaterThanOrEqualTo(4.5));
      // The New reel chip is valid only on the scrim (D-178): the dock keeps
      // it there.
      for (final sample in samples) {
        expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
      }
    });
  });

  group('the grid scrolls within 260 dp', () {
    testWidgets('many chips at 1x: the grid scrolls within 260 dp', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(
          _atBottom(_dock(chips: [for (var i = 1; i <= 14; i++) _chip(i)])),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_grid).height, 260);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _grid, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      // The footer and header stay put while the grid scrolls.
      final headerAt = tester.getRect(find.text('Add to reel')).top;
      await tester.drag(_grid, const Offset(0, -120));
      await tester.pump();
      expect(tester.getRect(find.text('Add to reel')).top, headerAt);
    });

    testWidgets('at 1x four chips are two short rows: no cap shows', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_atBottom(_dock())));
      // Two rows of 52+ and the 8 between, far under 260.
      expect(tester.getSize(_grid).height, lessThan(260));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _grid, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.maxScrollExtent, 0);
    });

    testWidgets('2x: one column, scrolls within 260 dp, header wraps', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(
          textScale: 2,
          _atBottom(
            _dock(
              title: 'Pick reels',
              actions: [
                _action(
                  'Pick several',
                  icon: Symbols.library_add_check_rounded,
                ),
                _action('All reels', icon: Symbols.apps_rounded),
              ],
              chips: [for (var i = 1; i <= 8; i++) _chip(i)],
              footer: TtButton(
                label: 'Add to 2 reels & next',
                expand: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // One column: every chip is the full 336 dp, one above the other.
      final first = tester.getRect(find.byType(TtReelChip).first);
      final second = tester.getRect(find.byType(TtReelChip).at(1));
      expect(first.width, 336);
      expect(second.top, greaterThanOrEqualTo(first.bottom));
      expect(second.left, first.left);
      // The grid holds at 260 dp and scrolls.
      expect(tester.getSize(_grid).height, 260);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: _grid, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      // The header is a Wrap: the actions do not fit beside the title.
      expect(_inDock(find.byType(Wrap)), findsOneWidget);
      final title = tester.getRect(find.text('Pick reels'));
      final all = tester.getRect(find.text('All reels'));
      expect(all.top, greaterThanOrEqualTo(title.bottom));
      // Everything stays inside the dock's width.
      final dock = tester.getRect(find.byType(TtReelDock));
      for (final label in ['Pick several', 'All reels']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(dock.left));
        expect(rect.right, lessThanOrEqualTo(dock.right));
      }
    });

    testWidgets('at 1.4 the grid is still two columns and the header a row', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          textScale: 1.4,
          _atBottom(_dock(actions: [_action('Pick several')])),
        ),
      );
      expect(tester.getSize(find.byType(TtReelChip).first).width, 164);
      expect(_inDock(find.byType(Wrap)), findsNothing);
    });

    testWidgets('from 1.5 the grid is one column and the header wraps', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          textScale: 1.5,
          _atBottom(_dock(actions: [_action('Pick several')])),
        ),
      );
      expect(tester.getSize(find.byType(TtReelChip).first).width, 336);
      expect(_inDock(find.byType(Wrap)), findsOneWidget);
    });

    testWidgets('a short grid at 2x is not stretched to 260', (tester) async {
      await tester.pumpWidget(
        ttTestApp(textScale: 2, _atBottom(_dock(chips: [_chip(1)]))),
      );
      expect(tester.getSize(_grid).height, lessThan(260));
    });
  });

  group('TtPlayerHeader chevrons', () {
    Widget header({
      TtHeaderChevron? previous,
      TtHeaderChevron? next,
      String subtitle = 'Scene 2 of 4 · 0:12–0:48',
      bool wrap = true,
      TextDirection? direction,
    }) {
      final bar = TtPlayerHeader(
        leading: TtIconButton(
          icon: Symbols.close_rounded,
          semanticLabel: 'Close tagging',
          style: TtIconButtonStyle.onVideo,
          onPressed: () {},
        ),
        title: '5 of 12',
        subtitle: subtitle,
        wrapSubtitle: wrap,
        previous: previous,
        next: next,
        trailing: TtIconButton(
          icon: Symbols.volume_up_rounded,
          semanticLabel: 'Mute',
          style: TtIconButtonStyle.onVideo,
          onPressed: () {},
        ),
      );
      final page = _player(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 360, child: bar),
        ),
      );
      return direction == null
          ? page
          : Directionality(textDirection: direction, child: page);
    }

    TtHeaderChevron previous({VoidCallback? onPressed}) =>
        TtHeaderChevron(semanticLabel: 'Previous clip', onPressed: onPressed);
    TtHeaderChevron next({VoidCallback? onPressed}) =>
        TtHeaderChevron(semanticLabel: 'Next clip', onPressed: onPressed);

    Finder semanticsNamed(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );

    testWidgets('are 48 dp, one on each side of the title, in focus order', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          header(
            previous: previous(onPressed: () {}),
            next: next(onPressed: () {}),
          ),
        ),
      );
      final close = tester.getRect(find.byIcon(Symbols.close_rounded));
      final prev = tester.getRect(find.byIcon(Symbols.chevron_left_rounded));
      final nextRect = tester.getRect(
        find.byIcon(Symbols.chevron_right_rounded),
      );
      final mute = tester.getRect(find.byIcon(Symbols.volume_up_rounded));
      final title = tester.getRect(find.text('5 of 12'));
      expect(close.right, lessThanOrEqualTo(prev.left));
      expect(prev.right, lessThanOrEqualTo(title.left));
      expect(title.right, lessThanOrEqualTo(nextRect.left));
      expect(nextRect.right, lessThanOrEqualTo(mute.left));
      for (final label in ['Previous clip', 'Next clip']) {
        final size = tester.getSize(semanticsNamed(label).first);
        expect(size, const Size(48, 48), reason: label);
      }
      // The title is still centred between them.
      expect(title.center.dx, closeTo(180, 0.5));
    });

    testWidgets('an enabled chevron is a TtIconButton on video at full '
        'strength', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        ttTestApp(
          header(
            previous: previous(onPressed: () => taps.add('previous')),
            next: next(onPressed: () => taps.add('next')),
          ),
        ),
      );
      final buttons = tester.widgetList<TtIconButton>(
        find.byType(TtIconButton),
      );
      final chevrons = buttons
          .where(
            (b) =>
                b.icon == Symbols.chevron_left_rounded ||
                b.icon == Symbols.chevron_right_rounded,
          )
          .toList();
      expect(chevrons, hasLength(2));
      expect(
        chevrons.map((b) => b.style),
        everyElement(TtIconButtonStyle.onVideo),
      );
      await tester.tap(find.byIcon(Symbols.chevron_left_rounded));
      await tester.tap(find.byIcon(Symbols.chevron_right_rounded));
      expect(taps, ['previous', 'next']);
      expect(
        find.ancestor(
          of: find.byIcon(Symbols.chevron_left_rounded),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('a chevron with no handler is dimmed to 35 %, announced '
        'disabled, and does nothing', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          header(
            previous: previous(),
            next: next(onPressed: () {}),
          ),
        ),
      );
      final dim = tester.widget<Opacity>(
        find.ancestor(
          of: find.byIcon(Symbols.chevron_left_rounded),
          matching: find.byType(Opacity),
        ),
      );
      expect(dim.opacity, 0.35);
      final off = tester.getSemantics(semanticsNamed('Previous clip').first);
      final data = off.getSemanticsData();
      expect(data.label, 'Previous clip');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      final on = tester.getSemantics(semanticsNamed('Next clip').first);
      expect(
        on.getSemanticsData().flagsCollection.isEnabled,
        ui.Tristate.isTrue,
      );
      expect(
        tester.getSize(semanticsNamed('Previous clip').first),
        const Size(48, 48),
      );
      await tester.tap(
        find.byIcon(Symbols.chevron_left_rounded),
        warnIfMissed: false,
      );
      handle.dispose();
    });

    testWidgets('both ends of a session: both dimmed, both announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(header(previous: previous(), next: next())),
      );
      expect(
        find.ancestor(
          of: find.byIcon(Symbols.chevron_right_rounded),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      for (final label in ['Previous clip', 'Next clip']) {
        final data = tester
            .getSemantics(semanticsNamed(label).first)
            .getSemanticsData();
        expect(
          data.flagsCollection.isEnabled,
          ui.Tristate.isFalse,
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('mirror in right-to-left text: Previous is on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          header(
            previous: previous(onPressed: () {}),
            next: next(onPressed: () {}),
            direction: TextDirection.rtl,
          ),
        ),
      );
      final prev = tester.getCenter(find.byIcon(Symbols.chevron_left_rounded));
      final nextAt = tester.getCenter(
        find.byIcon(Symbols.chevron_right_rounded),
      );
      expect(prev.dx, greaterThan(nextAt.dx));
      final icon = tester.widget<Icon>(
        find.byIcon(Symbols.chevron_left_rounded),
      );
      expect(icon.icon!.matchTextDirection, isTrue);
    });

    testWidgets('the scene line wraps and is never cut, at 1x and 2x', (
      tester,
    ) async {
      const scene =
          'Scene 12 of 40 · 12:34:56 PM–12:59:59 PM and a long tail end';
      expect(scene.length, greaterThanOrEqualTo(55));
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ttTestApp(
            textScale: scale,
            header(
              previous: previous(onPressed: () {}),
              next: next(onPressed: () {}),
              subtitle: scene,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'at ${scale}x');
        final text = tester.widget<Text>(find.text(scene));
        expect(text.maxLines, isNull, reason: 'at ${scale}x');
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(scene),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        // More than one line, and all of it is on screen (the header grew).
        expect(
          tester.getSize(find.text(scene)).height,
          greaterThan(2 * 12 * 1.2),
        );
        final header56 = tester.getRect(find.byType(TtPlayerHeader));
        expect(
          tester.getRect(find.text(scene)).bottom,
          lessThanOrEqualTo(header56.bottom),
        );
      }
    });

    testWidgets('without wrapSubtitle the scene line is still one line with '
        'an ellipsis', (tester) async {
      const scene = 'Scene 12 of 40 · 12:34:56 PM–12:59:59 PM and a long tail';
      await tester.pumpWidget(
        ttTestApp(
          textScale: 2,
          header(
            wrap: false,
            previous: previous(onPressed: () {}),
            next: next(onPressed: () {}),
            subtitle: scene,
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(scene));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('without chevrons the header is unchanged (the clip viewer)', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(header(wrap: false)));
      expect(find.byIcon(Symbols.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
      expect(tester.getSize(find.byType(TtPlayerHeader)).height, 56);
      // 360 less 4 at each side, the two 48 dp buttons and the two 4 dp gaps.
      expect(tester.getSize(find.text('5 of 12')).width, 360 - 8 - 96 - 8);
      expect(tester.getCenter(find.text('5 of 12')).dx, closeTo(180, 0.5));
    });

    testWidgets('only one chevron given keeps the title centred', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(header(next: next(onPressed: () {}))));
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_left_rounded), findsNothing);
      expect(tester.getCenter(find.text('5 of 12')).dx, closeTo(180, 0.5));
    });
  });

  group('the top scrim', () {
    test('stops: .78, .70 until 24 dp above the bottom, then clear', () {
      final g = const TopScrimPainter(_black).gradientFor(100);
      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.stops, [0, 76 / 100, 1]);
      expect(g.colors.map((c) => c.a), [0.78, 0.70, 0]);
      for (final c in g.colors) {
        expect([c.r, c.g, c.b], [0, 0, 0]);
      }
    });

    test('a scrim shorter than 24 dp clamps its hold stop to 0', () {
      final g = const TopScrimPainter(_black).gradientFor(20);
      expect(g.stops, [0, 0, 1]);
      expect(const TopScrimPainter(_black).gradientFor(0).stops, [0, 0, 1]);
    });

    testWidgets('paints behind its child, takes no touch, is not announced', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.topCenter,
            child: TtPlayerTopScrim(child: SizedBox(width: 360, height: 100)),
          ),
        ),
      );
      final paint = _paintOf(tester, TtPlayerTopScrim, TopScrimPainter);
      expect(paint.foregroundPainter, isNull);
      expect(paint.painter!.hitTest(const Offset(10, 10)), isFalse);
      expect(paint.painter!.semanticsBuilder, isNull);
      expect(
        _touchReachesPainter(tester, const Offset(180, 50), TopScrimPainter),
        isFalse,
      );
    });

    testWidgets('draws .78 black at the top, .70 until 24 dp above its '
        'bottom, and clear at the bottom, over white', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttPixelApp(
          const ColoredBox(
            color: Color(0xFFFFFFFF),
            child: Align(
              alignment: Alignment.topCenter,
              child: TtPlayerTopScrim(child: SizedBox(width: 360, height: 100)),
            ),
          ),
        ),
      );
      final pixels = await TtPixels.capture(tester);
      double blackShare(double y) => 1 - pixels.colorAt(Offset(2, y)).r;
      expect(blackShare(0), closeTo(0.78, 0.02));
      expect(blackShare(76), closeTo(0.70, 0.02));
      expect(blackShare(99), closeTo(0, 0.04));
    });

    testWidgets('the scene line reads AA on the top scrim over a white frame', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttPixelApp(
          _player(
            ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Align(
                alignment: Alignment.topCenter,
                child: TtPlayerTopScrim(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 34, bottom: 24),
                    child: TtPlayerHeader(
                      leading: TtIconButton(
                        icon: Symbols.close_rounded,
                        semanticLabel: 'Close tagging',
                        style: TtIconButtonStyle.onVideo,
                        onPressed: () {},
                      ),
                      title: '5 of 12',
                      subtitle: 'Scene 2 of 4 · 0:12–0:48',
                      wrapSubtitle: true,
                      previous: const TtHeaderChevron(
                        semanticLabel: 'Previous clip',
                        onPressed: _noop,
                      ),
                      next: const TtHeaderChevron(
                        semanticLabel: 'Next clip',
                        onPressed: _noop,
                      ),
                      trailing: TtIconButton(
                        icon: Symbols.volume_up_rounded,
                        semanticLabel: 'Mute',
                        style: TtIconButtonStyle.onVideo,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final samples = await _contrast(tester);
      final scene = samples.singleWhere((s) => s.text.startsWith('Scene'));
      expect(scene.ratio, greaterThanOrEqualTo(4.5));
      final title = samples.singleWhere((s) => s.text == '5 of 12');
      expect(title.ratio, greaterThanOrEqualTo(4.5));
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
      semantics.dispose();
    });
  });
}

void _noop() {}
