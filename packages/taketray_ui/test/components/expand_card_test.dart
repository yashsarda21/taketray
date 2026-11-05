import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _body = 'Open Settings, then Battery.';

Widget _card({
  String title = 'Samsung',
  String? badge,
  bool expanded = false,
  VoidCallback? onToggle,
  Widget child = const Text(_body),
}) => TtExpandCard(
  title: title,
  badge: badge,
  expanded: expanded,
  onToggle: onToggle ?? () {},
  child: child,
);

/// The card's own surface, the first [Material] under it.
Finder _surface() => find
    .descendant(of: find.byType(TtExpandCard), matching: find.byType(Material))
    .first;

/// The ink well of the header.
Finder _header() => find.descendant(
  of: find.byType(TtExpandCard),
  matching: find.byType(InkWell),
);

void _phone(WidgetTester tester, {double height = 1200}) {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('TtExpandCard', () {
    testWidgets('expand card reports expanded', (tester) async {
      final handle = tester.ensureSemantics();
      for (final expanded in [false, true]) {
        await tester.pumpWidget(ttTestApp(_card(expanded: expanded)));
        final data = tester
            .getSemantics(find.bySemanticsLabel('Samsung'))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue, reason: '$expanded');
        expect(
          data.flagsCollection.isExpanded,
          expanded ? ui.Tristate.isTrue : ui.Tristate.isFalse,
          reason: 'expanded: $expanded',
        );
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      }
      handle.dispose();
    });

    testWidgets('the header is one node: no icon or badge of its own', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_card(badge: 'Your phone', expanded: true)),
      );
      // The header is one button; the body is a separate node after it.
      expect(find.bySemanticsLabel('Your phone'), findsNothing);
      expect(find.bySemanticsLabel('Samsung, Your phone'), findsOneWidget);
      expect(find.bySemanticsLabel(_body), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a tap on the header and a semantic tap both toggle', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var calls = 0;
      await tester.pumpWidget(ttTestApp(_card(onToggle: () => calls++)));
      await tester.tap(find.text('Samsung'));
      expect(calls, 1);
      // Anywhere in the header, such as at the far end, past the title.
      final header = tester.getRect(_header());
      await tester.tapAt(Offset(header.right - 2, header.center.dy));
      expect(calls, 2);
      tester.semantics.tap(find.semantics.byLabel('Samsung'));
      await tester.pump();
      expect(calls, 3);
      handle.dispose();
    });

    testWidgets('collapsed card hides the body', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.text(_body), findsNothing);
      expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.expand_less_rounded), findsNothing);

      await tester.pumpWidget(ttTestApp(_card(expanded: true)));
      expect(find.text(_body), findsOneWidget);
      expect(find.byIcon(Symbols.expand_less_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsNothing);
    });

    testWidgets('badge is read with the title', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_card(badge: 'Your phone')));
      expect(
        tester.getSemantics(find.text('Samsung')).getSemanticsData().label,
        'Samsung, Your phone',
      );
      // And it is drawn.
      expect(find.text('Your phone'), findsOneWidget);

      await tester.pumpWidget(ttTestApp(_card()));
      expect(
        tester.getSemantics(find.text('Samsung')).getSemanticsData().label,
        'Samsung',
      );
      expect(find.text('Your phone'), findsNothing);
      handle.dispose();
    });

    testWidgets('header is at least 56 dp', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(tester.getSize(_header()).height, 56);
      expect(tester.getSize(_header()).width, 800);

      // With the body open the header does not grow, and with a badge neither.
      await tester.pumpWidget(
        ttTestApp(_card(badge: 'Your phone', expanded: true)),
      );
      expect(tester.getSize(_header()).height, 56);

      // A title that wraps makes it taller, never shorter.
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(
          _card(
            title: 'Xiaomi, Redmi, POCO and the other brands',
            badge: 'Your phone',
          ),
          textScale: 2,
        ),
      );
      expect(tester.getSize(_header()).height, greaterThan(56));
    });

    testWidgets('is 16 dp round on the low surface container, with no '
        'margin', (tester) async {
      await tester.pumpWidget(
        ttTestApp(Align(alignment: Alignment.topLeft, child: _card())),
      );
      final scheme = tester.element(find.byType(TtExpandCard)).scheme;
      final material = tester.widget<Material>(_surface());
      expect(material.color, scheme.surfaceContainerLow);
      expect(material.borderRadius, BorderRadius.circular(16));
      expect(material.clipBehavior, Clip.antiAlias);
      // The card is as wide as the space it is given, and starts at its edge.
      final box = tester.getRect(_surface());
      expect(box.left, 0);
      expect(box.top, 0);
      expect(box.right, 800);
    });

    testWidgets('title, badge, icon and body use the prototype styles', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_card(badge: 'Your phone', expanded: true)),
      );
      final scheme = tester.element(find.byType(TtExpandCard)).scheme;
      final title = tester.widget<Text>(find.text('Samsung')).style!;
      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w600);
      expect(title.color, scheme.onSurface);

      final badge = tester.widget<Text>(find.text('Your phone')).style!;
      expect(badge.fontSize, 12);
      expect(badge.color, scheme.onTertiaryContainer);
      final badgeBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Your phone'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = badgeBox.decoration as BoxDecoration;
      expect(decoration.color, scheme.tertiaryContainer);
      expect(decoration.borderRadius, BorderRadius.circular(6));
      // 8 dp at the sides and 3 above and below the text.
      final badgeRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Your phone'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final badgeText = tester.getRect(find.text('Your phone'));
      expect(badgeText.left - badgeRect.left, 8);
      expect(badgeRect.right - badgeText.right, 8);
      expect(badgeText.top - badgeRect.top, 3);
      expect(badgeRect.bottom - badgeText.bottom, 3);

      final icon = tester.widget<Icon>(
        find.byIcon(Symbols.expand_less_rounded),
      );
      expect(icon.size, 24);
      expect(icon.color, scheme.onSurface);

      final bodyStyle = DefaultTextStyle.of(tester.element(find.text(_body)))
          .style;
      expect(bodyStyle.fontSize, 14);
      expect(bodyStyle.fontWeight, FontWeight.w400);
      expect(bodyStyle.color, scheme.onSurface);
    });

    testWidgets('the header is 16 dp from the start and 12 from the end, '
        '12 dp between title, badge and icon', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(badge: 'Your phone', expanded: true)),
      );
      final card = tester.getRect(_surface());
      final title = tester.getRect(find.text('Samsung'));
      final icon = tester.getRect(find.byIcon(Symbols.expand_less_rounded));
      final badge = tester.getRect(
        find
            .ancestor(
              of: find.text('Your phone'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(title.left - card.left, 16);
      expect(card.right - icon.right, 12);
      expect(icon.left - badge.right, 12);
    });

    testWidgets('the body sits under the header with 16 dp at the sides and '
        'the bottom', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(alignment: Alignment.topLeft, child: _card(expanded: true)),
        ),
      );
      final card = tester.getRect(_surface());
      final header = tester.getRect(_header());
      final body = tester.getRect(find.text(_body));
      expect(body.left - card.left, 16);
      expect(body.top, header.bottom);
      expect(card.bottom - body.bottom, 16);
      // The text fills its width, so the right side is 16 dp too.
      expect(card.right - body.right, 16);
    });

    testWidgets('at 2x on a 360 dp phone the title and a long body wrap in '
        'full, with no overflow', (tester) async {
      _phone(tester);
      const title = 'Xiaomi, Redmi, POCO and many others';
      const body =
          'Long-press the TakeTray icon, tap App info, then turn on '
          'Autostart so that the app can wake up.';
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            brightness: brightness,
            Padding(
              padding: const EdgeInsets.all(16),
              child: _card(
                title: title,
                badge: 'Your phone',
                expanded: true,
                child: const Text(body),
              ),
            ),
            textScale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        for (final text in [title, body]) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(text))
                .didExceedMaxLines,
            isFalse,
          );
        }
        // Nothing is cut off at the sides of the card.
        final card = tester.getRect(_surface());
        expect(
          tester.getRect(find.text(title)).left,
          greaterThanOrEqualTo(card.left),
        );
        expect(
          tester.getRect(find.text(body)).right,
          lessThanOrEqualTo(card.right),
        );
        expect(tester.getRect(find.text(title)).width, greaterThan(100));
      }
    });

    testWidgets('at large text the badge moves under the title, which keeps '
        'its words whole', (tester) async {
      _phone(tester);
      Future<Rect> titleAt(Widget card, {double scale = 2}) async {
        await tester.pumpWidget(ttTestApp(card, textScale: scale));
        expect(tester.takeException(), isNull);
        return tester.getRect(find.text('Samsung'));
      }

      final alone = await titleAt(_card());
      final withBadge = await titleAt(_card(badge: 'Your phone'));
      // One line, as without a badge: no "Samsu" and "ng".
      expect(withBadge.height, alone.height);
      expect(
        tester.getRect(find.text('Your phone')).top,
        greaterThanOrEqualTo(withBadge.bottom),
      );
      // Lined up with the title: the badge's own 8 dp padding, then its text.
      expect(tester.getRect(find.text('Your phone')).left, withBadge.left + 8);

      // At normal size it stays beside the title.
      await titleAt(_card(badge: 'Your phone'), scale: 1);
      expect(
        tester.getRect(find.text('Your phone')).top,
        lessThan(tester.getRect(find.text('Samsung')).bottom),
      );
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final expanded in [false, true]) {
          await tester.pumpWidget(
            ttTestApp(
              brightness: brightness,
              _card(badge: 'Your phone', expanded: expanded),
            ),
          );
          await expectTtAccessible(tester);
        }
      }
    });
  });
}
