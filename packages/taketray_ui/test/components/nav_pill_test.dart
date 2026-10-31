import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

List<TtNavItem> _items({int badge = 0, String third = 'Settings'}) => [
  const TtNavItem(icon: Symbols.video_library_rounded, label: 'Reels'),
  TtNavItem(
    icon: Symbols.sell_rounded,
    label: 'To tag',
    badgeCount: badge,
    badgeSemanticLabel: '$badge clips waiting',
  ),
  TtNavItem(icon: Symbols.settings_rounded, label: third),
];

/// A phone-sized screen with the pill at the bottom of a Scaffold.
Future<void> _pump(
  WidgetTester tester, {
  int currentIndex = 0,
  List<TtNavItem>? items,
  ValueChanged<int>? onSelected,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double safeBottom = 0,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ttTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: EdgeInsets.only(bottom: safeBottom)),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TtNavPill(
              items: items ?? _items(),
              currentIndex: currentIndex,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
      textScale: textScale,
      brightness: brightness,
      disableAnimations: disableAnimations,
    ),
  );
}

/// The badge on the 'To tag' item.
Finder get _toTagBadge => find.descendant(
  of: find.ancestor(of: find.text('To tag'), matching: find.byType(InkWell)),
  matching: find.byType(TtCountBadge),
);

void main() {
  group('TtNavPill', () {
    testWidgets('tapping an item calls onSelected with its index', (
      tester,
    ) async {
      final taps = <int>[];
      await _pump(tester, onSelected: taps.add);
      await tester.tap(find.text('To tag'));
      await tester.tap(find.text('Settings'));
      // The selected item is tappable too (the shell resets its stack).
      await tester.tap(find.text('Reels'));
      expect(taps, [1, 2, 0]);
    });

    testWidgets('is a 320 x 64 glass pill, 20 dp in and 10 dp up', (
      tester,
    ) async {
      await _pump(tester);
      final glass = tester.getRect(find.byType(TtGlass));
      expect(glass.left, 20);
      expect(360 - glass.right, 20);
      expect(780 - glass.bottom, 10);
      expect(glass.size, const Size(320, 64));
      expect(tester.widget<TtGlass>(find.byType(TtGlass)).radius, 32);
    });

    testWidgets('sits above the safe area', (tester) async {
      await _pump(tester, safeBottom: 24);
      expect(780 - tester.getRect(find.byType(TtGlass)).bottom, 24 + 10);
    });

    testWidgets('items have 6 dp padding, 4 dp gaps and equal widths', (
      tester,
    ) async {
      await _pump(tester);
      final glass = tester.getRect(find.byType(TtGlass));
      final items = [
        for (final label in ['Reels', 'To tag', 'Settings'])
          tester.getRect(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          ),
      ];
      expect(items[0].left - glass.left, 6);
      expect(items[1].left - items[0].right, 4);
      expect(items[2].left - items[1].right, 4);
      expect(items[0].width, items[1].width);
      expect(items[1].width, items[2].width);
      expect(items[0].height, 64 - 12);
    });

    testWidgets('the selected item has a primaryContainer fill, radius 26', (
      tester,
    ) async {
      await _pump(tester, currentIndex: 1);
      final scheme = Theme.of(tester.element(find.byType(TtNavPill)))
          .colorScheme;
      Color? fillOf(String label) {
        final box = find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first;
        final decoration = tester.widget<AnimatedContainer>(box).decoration;
        return (decoration as BoxDecoration?)?.color;
      }

      expect(fillOf('To tag'), scheme.primaryContainer);
      expect(fillOf('Reels'), isNot(scheme.primaryContainer));
      expect(fillOf('Settings'), isNot(scheme.primaryContainer));
      final box = find
          .ancestor(
            of: find.text('To tag'),
            matching: find.byType(AnimatedContainer),
          )
          .first;
      expect(
        (tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(26),
      );
    });

    testWidgets('only the selected icon is filled', (tester) async {
      await _pump(tester, currentIndex: 2);
      double fillOf(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).fill!;
      expect(fillOf(Symbols.settings_rounded), 1);
      expect(fillOf(Symbols.video_library_rounded), 0);
      expect(fillOf(Symbols.sell_rounded), 0);
    });

    testWidgets(
      'selected and other items use the primaryContainer and variant text',
      (tester) async {
        await _pump(tester);
        final scheme = Theme.of(tester.element(find.byType(TtNavPill)))
            .colorScheme;
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.video_library_rounded)).color,
          scheme.onPrimaryContainer,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.sell_rounded)).color,
          scheme.onSurfaceVariant,
        );
      },
    );

    group('badge', () {
      testWidgets('is hidden at 0 and shown at 7 and 99+ at 120', (
        tester,
      ) async {
        await _pump(tester, items: _items());
        expect(find.text('0'), findsNothing);
        expect(tester.getSize(_toTagBadge), Size.zero);
        await _pump(tester, items: _items(badge: 7));
        expect(find.text('7'), findsOneWidget);
        expect(tester.getSize(_toTagBadge), isNot(Size.zero));
        await _pump(tester, items: _items(badge: 120));
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('sits on the icon: 4 dp right of its middle, 4 dp above', (
        tester,
      ) async {
        await _pump(tester, items: _items(badge: 7));
        final icon = tester.getRect(find.byIcon(Symbols.sell_rounded));
        final badge = tester.getRect(_toTagBadge);
        expect(badge.left - icon.left, 12 + 4);
        expect(badge.top - icon.top, -4);
      });

      testWidgets('stays small at 2x text and clear of most of the icon', (
        tester,
      ) async {
        await _pump(tester, items: _items(badge: 7), textScale: 2);
        final icon = tester.getRect(find.byIcon(Symbols.sell_rounded));
        final badge = tester.getRect(_toTagBadge);
        expect(badge.height, lessThan(20));
        // It covers the icon's top-right corner, never its lower half.
        expect(badge.bottom, lessThanOrEqualTo(icon.center.dy + 3));
        expect(badge.left, greaterThanOrEqualTo(icon.center.dx));
      });
    });

    group('semantics', () {
      testWidgets('an item says its label, and is selected or not', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, currentIndex: 1);
        SemanticsData dataOf(String label) => tester
            .getSemantics(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(InkWell),
              ),
            )
            .getSemanticsData();
        expect(dataOf('Reels').label, 'Reels');
        expect(dataOf('Reels').flagsCollection.isSelected, ui.Tristate.isFalse);
        expect(dataOf('To tag').flagsCollection.isSelected, ui.Tristate.isTrue);
        expect(dataOf('Reels').flagsCollection.isButton, isTrue);
        semantics.dispose();
      });

      testWidgets('the badge label is used when the count is above 0', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, items: _items(badge: 7));
        expect(find.bySemanticsLabel('7 clips waiting'), findsOneWidget);
        expect(find.bySemanticsLabel('To tag'), findsNothing);
        await _pump(tester, items: _items());
        expect(find.bySemanticsLabel('To tag'), findsOneWidget);
        expect(find.bySemanticsLabel('0 clips waiting'), findsNothing);
        semantics.dispose();
      });
    });

    testWidgets('a selection change animates over motion.short4', (
      tester,
    ) async {
      await _pump(tester);
      await _pump(tester, currentIndex: 1);
      await tester.pump();
      // Halfway through the 250 ms the fill is still changing.
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('under disableAnimations a change finishes in one frame', (
      tester,
    ) async {
      await _pump(tester, disableAnimations: true);
      await _pump(tester, currentIndex: 1, disableAnimations: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reservedHeight is 64 + 10 + the bottom safe area', (
      tester,
    ) async {
      late double height;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
          child: Builder(
            builder: (context) {
              height = TtNavPill.reservedHeight(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(height, 64 + 10 + 24);
    });

    testWidgets('reservedHeight equals the space the pill takes', (
      tester,
    ) async {
      await _pump(tester, safeBottom: 24);
      final context = tester.element(find.byType(TtNavPill));
      final taken = 780 - tester.getRect(find.byType(TtGlass)).top;
      expect(TtNavPill.reservedHeight(context), taken);
    });

    testWidgets('fabBottom is the reserved height plus 16', (tester) async {
      late double bottom;
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: const EdgeInsets.only(bottom: 24)),
              child: Builder(
                builder: (context) {
                  bottom = TtNavPill.fabBottom(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(bottom, 64 + 10 + 24 + 16);
    });

    testWidgets('a fab placed at fabBottom sits 16 dp above the pill', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: const EdgeInsets.only(bottom: 24)),
              child: Builder(
                builder: (context) => Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: TtNavPill(
                        items: _items(),
                        currentIndex: 0,
                        onSelected: (_) {},
                      ),
                    ),
                    PositionedDirectional(
                      end: 16,
                      bottom: TtNavPill.fabBottom(context),
                      child: TtFab(
                        label: 'New reel',
                        icon: Symbols.add_rounded,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final pillTop = tester.getRect(find.byType(TtGlass)).top;
      final fabBottom = tester.getRect(find.byType(TtFab)).bottom;
      // (no lift here: liftBy is 0)
      expect(pillTop - fabBottom, 16);
      expect(
        780 - fabBottom,
        TtNavPill.fabBottom(tester.element(find.byType(TtFab))),
      );
    });

    testWidgets('a long label ends in an ellipsis and nothing overflows', (
      tester,
    ) async {
      await _pump(
        tester,
        items: _items(third: 'Settings and preferences'),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtGlass)).height, 64);
    });

    testWidgets('at 2x the labels stay inside the pill', (tester) async {
      await _pump(tester, textScale: 2, items: _items(badge: 7));
      final glass = tester.getRect(find.byType(TtGlass));
      for (final label in ['Reels', 'To tag', 'Settings']) {
        final text = tester.getRect(find.text(label));
        expect(text.bottom, lessThanOrEqualTo(glass.bottom - 6));
        expect(text.top, greaterThanOrEqualTo(glass.top + 6));
      }
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await _pump(
          tester,
          currentIndex: 1,
          brightness: brightness,
          items: _items(badge: 7),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
