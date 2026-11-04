import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _names = [
  'Lisbon trip',
  'Autumn recipes',
  'Summer weekend',
  'Garden',
  'Birthday',
];

Widget _chipFor(String name, {VoidCallback? onTap}) => TtReelChip(
  name: name,
  countText: '12 clips',
  semanticLabel: 'Add to $name, 12 clips',
  cover: fixtureThumb(1 + name.length % 6),
  onTap: onTap ?? () {},
);

Widget _newReel({bool fullWidth = false, VoidCallback? onTap}) => TtNewReelChip(
  title: 'New reel',
  subtitle: fullWidth ? null : 'Add this clip to it',
  fullWidth: fullWidth,
  onTap: onTap ?? () {},
);

TtOtherReelsToggle _toggle({
  bool expanded = false,
  String? label,
  VoidCallback? onToggle,
}) => TtOtherReelsToggle(
  label: label ?? (expanded ? 'Other reels' : 'Other reels (4)'),
  expanded: expanded,
  onToggle: onToggle ?? () {},
);

Widget _panel({
  int chips = 5,
  String title = 'Add to reel',
  bool action = true,
  bool footer = true,
  double? height,
  bool longNames = false,
  void Function(int)? onChip,
  bool newReel = false,
  bool newReelFull = false,
  String? emptyText,
  TtOtherReelsToggle? toggle,
  int folded = 0,
}) => Align(
  alignment: Alignment.bottomLeft,
  child: SizedBox(
    width: 360,
    height: height,
    child: TtVideoSurface(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: TtTagPanel(
          title: title,
          semanticLabel: 'Reels',
          emptyText: emptyText,
          toggle: toggle,
          foldedChips: [
            for (var i = 0; i < folded; i++)
              _chipFor('Other reel $i', onTap: () => onChip?.call(100 + i)),
          ],
          chips: [
            for (var i = 0; i < chips; i++)
              _chipFor(
                longNames
                    ? 'Lisbon food market number $i'
                    : i < _names.length
                    ? _names[i]
                    : 'Reel number $i',
                onTap: () => onChip?.call(i),
              ),
            if (newReel || newReelFull) _newReel(fullWidth: newReelFull),
          ],
          headerAction: action
              ? TtButton(
                  label: 'Pick several',
                  icon: Symbols.library_add_check_rounded,
                  kind: TtButtonKind.text,
                  size: TtButtonSize.small,
                  onPressed: () {},
                )
              : null,
          footer: footer
              ? TtButton(
                  label: 'Add to 2 reels & next',
                  expand: true,
                  onPressed: () {},
                )
              : null,
        ),
      ),
    ),
  ),
);

Widget _same({
  String label = 'Same as previous',
  String? detail = 'Lisbon trip, Garden, Birthday',
  VoidCallback? onPressed,
  double width = 328,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    child: TtVideoSurface(
      child: TtSameAsPreviousButton(
        label: label,
        detail: detail,
        semanticLabel: 'Same as previous: ${detail ?? ''}',
        onPressed: onPressed,
      ),
    ),
  ),
);

void main() {
  group('TtTagPanel', () {
    testWidgets('has a 28 dp radius at the top only', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel()));
      final clips = tester
          .widgetList<ClipRRect>(
            find.descendant(
              of: find.byType(TtTagPanel),
              matching: find.byType(ClipRRect),
            ),
          )
          .map((c) => c.borderRadius)
          .toList();
      expect(
        clips,
        contains(const BorderRadius.vertical(top: Radius.circular(28))),
      );
    });

    testWidgets('has a glass fill: surface container at 92 %, blurred', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_panel()));
      expect(
        find.descendant(
          of: find.byType(TtTagPanel),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      final scheme = tester.element(find.byType(TtTagPanel)).scheme;
      final fills = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(TtTagPanel),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((c) => c.color);
      expect(fills, contains(scheme.surfaceContainer.withValues(alpha: 0.92)));
    });

    testWidgets('lays the chips out in two columns 164 dp wide', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_panel()));
      final panel = tester.getRect(find.byType(TtTagPanel));
      expect(panel.width, 360);
      final rects = [
        for (final e in find.byType(TtReelChip).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      expect(rects, hasLength(5));
      for (final r in rects) {
        expect(r.width, 164);
      }
      expect(rects[0].left, panel.left + 12);
      expect(rects[1].left, panel.left + 12 + 164 + 8);
      expect(rects[1].right, panel.right - 12);
      expect(rects[2].left, rects[0].left);
      expect(rects[2].top - rects[0].bottom, 8);
      expect(rects[3].top, rects[2].top);
      expect(rects[4].left, rects[0].left);
      expect(rects[4].top - rects[2].bottom, 8);
    });

    testWidgets('pads 12 at the top and sides and 26 at the bottom', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_panel(action: false, footer: false)));
      final panel = tester.getRect(find.byType(TtTagPanel));
      final title = tester.getRect(find.text('Add to reel'));
      // The header is 40 dp high with 8 dp in, below the 12 dp padding.
      expect(title.left - panel.left, 12 + 8);
      expect(
        tester.getCenter(find.text('Add to reel')).dy,
        closeTo(panel.top + 12 + 20, 0.5),
      );
      final last = tester.getRect(find.byType(TtReelChip).last);
      // 4 dp under the grid, then 26 dp of padding.
      expect(panel.bottom - last.bottom, 4 + 26);
    });

    testWidgets('shows the title as a heading, the action and the footer', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_panel()));
      expect(find.text('Add to reel'), findsOneWidget);
      expect(find.text('Pick several'), findsOneWidget);
      expect(find.text('Add to 2 reels & next'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('Add to reel'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      // The action sits at the end of the header, the footer under the grid.
      final panel = tester.getRect(find.byType(TtTagPanel));
      final action = tester.getRect(find.text('Pick several'));
      final title = tester.getRect(find.text('Add to reel'));
      expect(action.left, greaterThan(title.right));
      expect(action.right, lessThan(panel.right));
      expect(
        tester.getRect(find.text('Add to 2 reels & next')).top,
        greaterThan(tester.getRect(find.byType(TtReelChip).last).bottom),
      );
      handle.dispose();
    });

    testWidgets('has no action or footer when none is given', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(action: false, footer: false)));
      expect(find.text('Pick several'), findsNothing);
      expect(find.byType(TtButton), findsNothing);
    });

    testWidgets('an odd chip count leaves the last cell empty', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 3)));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtReelChip).last).width, 164);
    });

    testWidgets('no chips draws only the header', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 0)));
      expect(tester.takeException(), isNull);
      expect(find.byType(TtReelChip), findsNothing);
    });

    testWidgets('is at most 340 dp high; many chips scroll', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        ttTestApp(_panel(chips: 30, onChip: (i) => tapped = i)),
      );
      expect(tester.getSize(find.byType(TtTagPanel)).height, 340);
      expect(tester.takeException(), isNull);
      // A late chip scrolls into reach.
      await tester.dragFrom(
        tester.getCenter(find.byType(TtReelChip).first),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reel number 29'));
      expect(tapped, 29);
    });

    testWidgets('tapping a chip calls its own handler', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(ttTestApp(_panel(onChip: (i) => tapped = i)));
      await tester.tap(find.text('Garden'));
      expect(tapped, 3);
    });

    testWidgets('at 2x text it does not overflow', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 8), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TtTagPanel)).height,
        lessThanOrEqualTo(520),
      );
    });

    testWidgets('at 2x text the chips are one per row, as wide as the '
        'panel inside its padding', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(), textScale: 2));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(TtTagPanel));
      final chips = [
        for (final e in find.byType(TtReelChip).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      expect(chips, isNotEmpty);
      for (final r in chips) {
        expect(r.width, panel.width - 24);
        expect(r.left, panel.left + 12);
      }
      // No two chips share a row.
      for (var i = 1; i < chips.length; i++) {
        expect(chips[i].top, greaterThanOrEqualTo(chips[i - 1].bottom));
      }
    });

    testWidgets('the layout switches to one column at 1.5x and not below', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_panel(), textScale: 1.49));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TtReelChip).at(1)).left,
        greaterThan(tester.getRect(find.byType(TtReelChip).at(0)).right),
      );
      await tester.pumpWidget(ttTestApp(_panel(), textScale: 1.5));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TtReelChip).at(1)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(TtReelChip).at(0)).bottom,
        ),
      );
    });

    testWidgets('at 1x the panel keeps two columns and a 340 dp cap', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 30)));
      final first = tester.getRect(find.byType(TtReelChip).at(0));
      final second = tester.getRect(find.byType(TtReelChip).at(1));
      expect(first.width, 164);
      expect(second.top, first.top);
      expect(tester.getSize(find.byType(TtTagPanel)).height, 340);
    });

    testWidgets('at 2x the cap grows so three chips with two-line names '
        'show under the header on a 780 dp screen', (tester) async {
      tester.view.physicalSize = const Size(360, 780) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(_panel(chips: 12, longNames: true), textScale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byType(TtTagPanel));
      expect(panel.height, greaterThan(340));
      expect(panel.height, lessThanOrEqualTo(520));
      final header = tester.getRect(find.text('Add to reel'));
      var whole = 0;
      for (final e in find.byType(TtReelChip).evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        if (r.top >= header.bottom && r.bottom <= panel.bottom - 26) whole++;
      }
      expect(whole, greaterThanOrEqualTo(3));
    });

    testWidgets('panel is one semantics group', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_panel(newReel: true, toggle: _toggle(), folded: 1)),
      );
      final group = tester.getSemantics(find.byType(TtTagPanel));
      final data = group.getSemanticsData();
      // The group is named by the caller and does not swallow its children:
      // its own label is only that name.
      expect(data.label, 'Reels');
      expect(data.flagsCollection.isHeader, isFalse);
      final labels = <String>[];
      void walk(SemanticsNode node) {
        node.visitChildren((child) {
          final label = child.getSemanticsData().label;
          if (label.isNotEmpty) labels.add(label);
          walk(child);
          return true;
        });
      }

      walk(group);
      expect(
        labels,
        containsAll([
          'Add to reel',
          'Pick several',
          'Add to Lisbon trip, 12 clips',
          'Add to Birthday, 12 clips',
          'New reel',
          'Other reels (4)',
          'Add to 2 reels & next',
        ]),
      );
      // Each chip is a node of its own inside the group.
      expect(
        labels.where((l) => l.startsWith('Add to ') && l.contains('clips')),
        hasLength(5),
      );
      handle.dispose();
    });

    testWidgets('panel caps its height at 2x and scrolls', (tester) async {
      tester.view.physicalSize = const Size(360, 780) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var tapped = -1;
      await tester.pumpWidget(
        ttTestApp(
          _panel(
            chips: 30,
            newReel: true,
            toggle: _toggle(expanded: true),
            folded: 10,
            onChip: (i) => tapped = i,
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The budget at 2x text is 520 dp (D-47), so the video keeps the rest.
      expect(tester.getSize(find.byType(TtTagPanel)).height, 520);
      // The header and the footer stay; the grid scrolls between them.
      final header = tester.getRect(find.text('Add to reel'));
      // The last folded chip is under the cap, out of sight, until scrolled.
      expect(
        tester.getRect(find.text('Other reel 9')).top,
        greaterThan(tester.getRect(find.byType(TtTagPanel)).bottom),
      );
      await tester.dragFrom(
        tester.getCenter(find.byType(TtReelChip).first),
        const Offset(0, -6000),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Add to reel')), header);
      expect(find.text('Add to 2 reels & next'), findsOneWidget);
      expect(tester.getSize(find.byType(TtTagPanel)).height, 520);
      expect(
        tester.getRect(find.text('Other reel 9')).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TtTagPanel)).bottom),
      );
      await tester.tap(find.text('Other reel 9'));
      expect(tapped, 109);
    });

    testWidgets('the cap also gives way to a short parent', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              height: 260,
              child: _panel(chips: 30, newReel: true),
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TtTagPanel)).height,
        lessThanOrEqualTo(260),
      );
    });

    testWidgets('the toggle sits between the open chips and the folded ones; '
        'folded chips show only while it is expanded', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_panel(chips: 3, toggle: _toggle(), folded: 2)),
      );
      expect(find.text('Other reel 0'), findsNothing);
      expect(find.text('Other reels (4)'), findsOneWidget);
      await tester.pumpWidget(
        ttTestApp(_panel(chips: 3, toggle: _toggle(expanded: true), folded: 2)),
      );
      final last = tester.getRect(find.text('Summer weekend'));
      final toggle = tester.getRect(find.byType(TtOtherReelsToggle));
      final first = tester.getRect(find.text('Other reel 0'));
      expect(toggle.top, greaterThan(last.bottom));
      expect(first.top, greaterThan(toggle.bottom));
      // The toggle takes the whole row; the folded chips start on a new row
      // in the two columns.
      final panel = tester.getRect(find.byType(TtTagPanel));
      expect(toggle.width, panel.width - 24);
      final a = tester.getRect(find.byType(TtReelChip).at(3));
      final b = tester.getRect(find.byType(TtReelChip).at(4));
      expect(a.width, 164);
      expect(b.top, a.top);
      expect(b.left, greaterThan(a.right));
    });

    testWidgets('folded chips with no toggle are all shown', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 1, folded: 2)));
      expect(find.byType(TtReelChip), findsNWidgets(3));
    });

    testWidgets('the empty text spans the row above the chips', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _panel(
            chips: 0,
            newReelFull: true,
            emptyText:
                "You don't have any reels yet. Create one and this clip "
                'goes into it.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byType(TtTagPanel));
      final text = tester.getRect(find.textContaining("You don't have"));
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(text.bottom, lessThanOrEqualTo(chip.top));
      expect(chip.width, panel.width - 24);
      final style = tester
          .widget<Text>(find.textContaining("You don't have"))
          .textAlign;
      expect(style, TextAlign.center);
      // 8 dp inside the row at each side.
      expect(text.left, greaterThanOrEqualTo(panel.left + 12 + 8));
      expect(text.right, lessThanOrEqualTo(panel.right - 12 - 8));
    });

    testWidgets('new reel chip spans the row when fullWidth', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 2, newReelFull: true)));
      final panel = tester.getRect(find.byType(TtTagPanel));
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.left, panel.left + 12);
      expect(chip.width, panel.width - 24);
      // The two chips before it fill their row; it starts a new one.
      expect(
        chip.top,
        greaterThan(tester.getRect(find.byType(TtReelChip).last).bottom),
      );
      // Not full width: it takes a cell like any chip, 164 dp.
      await tester.pumpWidget(ttTestApp(_panel(chips: 2, newReel: true)));
      expect(tester.getSize(find.byType(TtNewReelChip)).width, 164);
      expect(
        tester.getRect(find.byType(TtNewReelChip)).top,
        tester.getRect(find.byType(TtReelChip).first).top +
            tester.getSize(find.byType(TtReelChip).first).height +
            8,
      );
    });

    testWidgets('a full-width new reel chip after an odd count does not '
        'leave a hole', (tester) async {
      await tester.pumpWidget(ttTestApp(_panel(chips: 3, newReelFull: true)));
      expect(tester.takeException(), isNull);
      final third = tester.getRect(find.byType(TtReelChip).at(2));
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.top - third.bottom, 8);
    });

    testWidgets('at 2x every slot is one per row, the toggle and the new '
        'reel chip included', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _panel(
            chips: 3,
            newReel: true,
            toggle: _toggle(expanded: true),
            folded: 2,
            emptyText: 'No reels',
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byType(TtTagPanel));
      final rects = [
        tester.getRect(find.byType(TtNewReelChip)),
        tester.getRect(find.byType(TtOtherReelsToggle)),
        for (final e in find.byType(TtReelChip).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      for (final r in rects) {
        expect(r.width, panel.width - 24);
      }
      // No two share a row.
      final tops = rects.map((r) => r.top).toSet();
      expect(tops, hasLength(rects.length));
    });

    testWidgets('a plain panel has no empty text, toggle or new reel chip', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_panel()));
      expect(find.byType(TtNewReelChip), findsNothing);
      expect(find.byType(TtOtherReelsToggle), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_panel(), brightness: brightness));
        await expectTtAccessible(tester);
      });

      testWidgets('with every slot it passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            _panel(
              chips: 2,
              newReel: true,
              toggle: _toggle(expanded: true),
              folded: 2,
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });

      testWidgets('with no reels it passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            _panel(
              chips: 0,
              action: false,
              newReelFull: true,
              emptyText: "You don't have any reels yet.",
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtOtherReelsToggle', () {
    Widget host(Widget toggle) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 336, child: TtVideoSurface(child: toggle)),
    );

    testWidgets('other reels toggle reports expanded', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(host(_toggle())));
      var data = tester
          .getSemantics(find.byType(TtOtherReelsToggle))
          .getSemanticsData();
      expect(data.label, 'Other reels (4)');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, ui.Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.pumpWidget(ttTestApp(host(_toggle(expanded: true))));
      data = tester
          .getSemantics(find.byType(TtOtherReelsToggle))
          .getSemanticsData();
      expect(data.label, 'Other reels');
      expect(data.flagsCollection.isExpanded, ui.Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('shows expand_more while folded and expand_less while open', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(host(_toggle())));
      expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(host(_toggle(expanded: true))));
      expect(find.byIcon(Symbols.expand_less_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsNothing);
    });

    testWidgets('is drawn 36 dp high inside a 48 dp target', (tester) async {
      await tester.pumpWidget(ttTestApp(host(_toggle())));
      final target = tester.getSize(find.byType(TtOtherReelsToggle));
      expect(target.height, 48);
      expect(target.width, 336);
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-other-reels-row'))).height,
        36,
      );
      // A tap near the top and bottom of the 48 dp target still toggles.
      var taps = 0;
      await tester.pumpWidget(ttTestApp(host(_toggle(onToggle: () => taps++))));
      final box = tester.getRect(find.byType(TtOtherReelsToggle));
      await tester.tapAt(box.topCenter + const Offset(0, 2));
      await tester.tapAt(box.bottomCenter - const Offset(0, 2));
      expect(taps, 2);
    });

    testWidgets('a long label ellipsises at 2x without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          host(_toggle(label: 'Other reels that are folded away (1204)')),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TtOtherReelsToggle)).height,
        greaterThanOrEqualTo(48),
      );
    });

    for (final brightness in Brightness.values) {
      for (final expanded in [false, true]) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, expanded $expanded)', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              host(_toggle(expanded: expanded)),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }
  });

  group('TtSameAsPreviousButton', () {
    testWidgets('has two lines: the label over the detail', (tester) async {
      await tester.pumpWidget(ttTestApp(_same(onPressed: () {})));
      expect(find.text('Same as previous'), findsOneWidget);
      expect(find.text('Lisbon trip, Garden, Birthday'), findsOneWidget);
      expect(find.byIcon(Symbols.repeat_rounded), findsOneWidget);
      final label = tester.getRect(find.text('Same as previous'));
      final detail = tester.getRect(find.text('Lisbon trip, Garden, Birthday'));
      expect(detail.top, greaterThanOrEqualTo(label.bottom - 1));
      expect(label.left, detail.left);
    });

    testWidgets('is at least 48 dp high, the width it is given, with a 24 dp '
        'radius', (tester) async {
      await tester.pumpWidget(ttTestApp(_same(onPressed: () {})));
      final size = tester.getSize(find.byType(TtSameAsPreviousButton));
      expect(size.width, 328);
      expect(size.height, greaterThanOrEqualTo(48));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtSameAsPreviousButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        material.shape,
        isA<RoundedRectangleBorder>().having(
          (s) => s.borderRadius,
          'radius',
          BorderRadius.circular(24),
        ),
      );
    });

    testWidgets('both lines ellipsise instead of overflowing', (tester) async {
      const label = 'Same as the previous clip you tagged a moment ago';
      await tester.pumpWidget(
        ttTestApp(
          _same(
            label: label,
            detail:
                'Lisbon trip, Autumn recipes, Summer weekend, Garden, '
                'Birthday party, Saturday morning market walk',
            width: 230,
            onPressed: () {},
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(TtSameAsPreviousButton),
          matching: find.byType(Text),
        ),
      )) {
        // At large text the label may take two lines, the detail one.
        expect(text.maxLines, text.data == label ? 2 : 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }
    });

    testWidgets('at 2x the label grows to two lines instead of clipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_same(width: 200, onPressed: () {}), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Same as previous'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.getSize(find.byType(TtSameAsPreviousButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('below large text the label is one line', (tester) async {
      await tester.pumpWidget(ttTestApp(_same(onPressed: () {})));
      expect(tester.widget<Text>(find.text('Same as previous')).maxLines, 1);
    });

    testWidgets('works without a detail', (tester) async {
      await tester.pumpWidget(ttTestApp(_same(detail: null, onPressed: () {})));
      expect(tester.takeException(), isNull);
      expect(find.text('Same as previous'), findsOneWidget);
    });

    testWidgets('a tap calls onPressed; disabled does nothing', (tester) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_same(onPressed: () => taps++)));
      await tester.tap(find.byType(TtSameAsPreviousButton));
      expect(taps, 1);
      await tester.pumpWidget(ttTestApp(_same()));
      await tester.tap(find.byType(TtSameAsPreviousButton));
      expect(taps, 1);
    });

    testWidgets('disabled draws dimmer than enabled', (tester) async {
      await tester.pumpWidget(ttTestApp(_same(onPressed: () {})));
      final on = tester
          .widget<Text>(find.text('Same as previous'))
          .style!
          .color!;
      await tester.pumpWidget(ttTestApp(_same()));
      final off = tester
          .widget<Text>(find.text('Same as previous'))
          .style!
          .color!;
      expect(off.a, lessThan(on.a));
    });

    testWidgets('semantics: a button named by semanticLabel; disabled when '
        'there is no handler', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_same(onPressed: () {})));
      var data = tester
          .getSemantics(find.byType(TtSameAsPreviousButton))
          .getSemanticsData();
      expect(data.label, 'Same as previous: Lisbon trip, Garden, Birthday');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.pumpWidget(ttTestApp(_same()));
      data = tester
          .getSemantics(find.byType(TtSameAsPreviousButton))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('passes the accessibility guidelines', (tester) async {
      await tester.pumpWidget(ttTestApp(_same(onPressed: () {})));
      await expectTtAccessible(tester);
    });
  });
}
