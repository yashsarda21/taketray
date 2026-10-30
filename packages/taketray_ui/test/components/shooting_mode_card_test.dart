import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longSubtitle =
    'On since 9:41 AM · Manual mode: add clips yourself, because TakeTray '
    'cannot see new videos on its own right now';

Widget _card({
  bool on = true,
  String subtitle = 'On since 9:41 AM',
  ImageProvider? backdrop,
  ValueChanged<bool>? onChanged,
  VoidCallback? onOpenCamera,
  bool rows = false,
  bool earlier = false,
  VoidCallback? onEarlier,
  bool camera = true,
}) => Center(
  child: SizedBox(
    width: 328,
    child: TtShootingModeCard(
      on: on,
      title: on ? 'Shooting mode on' : 'Shooting mode',
      subtitle: subtitle,
      switchSemanticLabel: 'Shooting mode',
      onChanged: onChanged ?? (_) {},
      backdrop: backdrop,
      cameraLabel: camera ? 'Open camera' : null,
      onOpenCamera: camera ? (onOpenCamera ?? () {}) : null,
      rows: [
        if (rows)
          TtCardRow(
            icon: Symbols.link_rounded,
            title: 'References · 4',
            subtitle: 'From 2 Recording reels',
            semanticLabel: 'References, 4, from your Recording reels',
            onPressed: () {},
          ),
        if (earlier)
          TtCardRow(
            icon: Symbols.history_rounded,
            title: 'Add earlier videos',
            subtitle: 'Shot before Shooting mode was on',
            semanticLabel:
                'Add earlier videos, shot before Shooting mode was on',
            onPressed: onEarlier ?? () {},
          ),
      ],
      toTagStrip: rows
          ? TtCardRow(
              icon: Symbols.sell_rounded,
              title: '3 clips to tag',
              trailingText: 'Tag now',
              onPressed: () {},
            )
          : null,
    ),
  ),
);

Future<void> _decode(WidgetTester tester, ImageProvider image) async {
  await tester.runAsync(
    () => precacheImage(
      image,
      tester.element(find.byType(TtShootingModeCard)),
      onError: (_, _) {},
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('TtShootingModeCard, off', () {
    testWidgets('shows the videocam icon, texts and a switch that is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_card(on: false, subtitle: 'Off. Turn on before filming')),
      );
      expect(find.byIcon(Symbols.videocam_rounded), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.videocam_rounded)).fill,
        1,
      );
      expect(find.text('Shooting mode'), findsOneWidget);
      expect(find.text('Off. Turn on before filming'), findsOneWidget);
      final sw = tester.widget<TtSwitch>(find.byType(TtSwitch));
      expect(sw.value, isFalse);
      expect(sw.inverted, isFalse);
      // None of the on parts.
      expect(find.byType(TtRecDot), findsNothing);
      expect(find.text('Open camera'), findsNothing);
    });

    testWidgets('the card is a 28 dp rounded hairline surface', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(on: false)));
      final scheme = tester.element(find.byType(TtShootingModeCard)).scheme;
      final tt = tester.element(find.byType(TtShootingModeCard)).tt;
      final decorated = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(TtShootingModeCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<ShapeDecoration>()
          .toList();
      final surface = decorated.firstWhere(
        (d) => d.color == scheme.surfaceContainerHigh,
      );
      final shape = surface.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(28));
      expect(shape.side.color, tt.colors.hairline);
    });

    testWidgets('the switch calls onChanged(true)', (tester) async {
      final values = <bool>[];
      await tester.pumpWidget(
        ttTestApp(_card(on: false, onChanged: values.add)),
      );
      await tester.tap(find.byType(TtSwitch));
      expect(values, [true]);
    });
  });

  group('TtShootingModeCard, on', () {
    testWidgets('is a black hero with the rec dot, texts and camera button', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.text('Shooting mode on'), findsOneWidget);
      expect(find.text('On since 9:41 AM'), findsOneWidget);
      expect(find.byType(TtRecDot), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
      final tt = tester.element(find.byType(TtShootingModeCard)).tt;
      expect(
        tester.widget<Text>(find.text('Shooting mode on')).style,
        isA<TextStyle>()
            .having((s) => s.fontSize, 'size', 19)
            .having((s) => s.fontWeight, 'weight', FontWeight.w800)
            .having((s) => s.color, 'colour', tt.colors.onMedia),
      );
      expect(
        find.descendant(
          of: find.byType(TtShootingModeCard),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == tt.colors.videoBackground,
          ),
        ),
        findsWidgets,
      );
    });

    testWidgets('the switch is the inverted one and calls onChanged(false)', (
      tester,
    ) async {
      final values = <bool>[];
      await tester.pumpWidget(ttTestApp(_card(onChanged: values.add)));
      final sw = tester.widget<TtSwitch>(find.byType(TtSwitch));
      expect(sw.inverted, isTrue);
      expect(sw.value, isTrue);
      await tester.tap(find.byType(TtSwitch));
      expect(values, [false]);
    });

    testWidgets('the camera button is white with dark text and calls back', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_card(onOpenCamera: () => taps++)));
      final tt = tester.element(find.byType(TtShootingModeCard)).tt;
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final context = tester.element(find.byType(FilledButton));
      final states = <WidgetState>{};
      expect(button.style!.backgroundColor!.resolve(states), tt.colors.onMedia);
      expect(
        button.style!.foregroundColor!.resolve(states),
        tt.colors.videoBackground,
      );
      expect(context, isNotNull);
      await tester.tap(find.text('Open camera'));
      expect(taps, 1);
      expect(find.byIcon(Symbols.videocam_rounded), findsNWidgets(2));
    });

    testWidgets('no camera button without cameraLabel', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(camera: false)));
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the backdrop is drawn at 62 % opacity', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(backdrop: fixtureThumb(2))));
      await _decode(tester, fixtureThumb(2));
      final image = find.descendant(
        of: find.byType(TtShootingModeCard),
        matching: find.byType(Image),
      );
      expect(image, findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: image, matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, closeTo(0.62, 1e-9));
    });

    testWidgets('no backdrop builds no image', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(
        find.descendant(
          of: find.byType(TtShootingModeCard),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
    });

    testWidgets('a backdrop that fails to load leaves the plain black card', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(backdrop: brokenImage)));
      await tester.runAsync(
        () => precacheImage(
          brokenImage,
          tester.element(find.byType(TtShootingModeCard)),
          onError: (_, _) {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      // Texts and button are still there.
      expect(find.text('Shooting mode on'), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
    });

    testWidgets('shows the references row and the to-tag strip', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(rows: true)));
      expect(find.text('References · 4'), findsOneWidget);
      expect(find.text('3 clips to tag'), findsOneWidget);
      expect(find.text('Tag now'), findsOneWidget);
    });

    testWidgets('rows: none, one or two, in order, above the strip', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.byType(TtCardRow), findsNothing);

      await tester.pumpWidget(ttTestApp(_card(earlier: true)));
      expect(find.text('Add earlier videos'), findsOneWidget);
      expect(find.text('Shot before Shooting mode was on'), findsOneWidget);
      expect(find.byIcon(Symbols.history_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);

      await tester.pumpWidget(ttTestApp(_card(rows: true, earlier: true)));
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('References · 4'), lessThan(top('Add earlier videos')));
      expect(top('Add earlier videos'), lessThan(top('3 clips to tag')));
      // Three bands, all the card's width, one under the other.
      final rects = [
        for (final title in [
          'References · 4',
          'Add earlier videos',
          '3 clips to tag',
        ])
          tester.getRect(
            find
                .ancestor(
                  of: find.text(title),
                  matching: find.byType(Semantics),
                )
                .first,
          ),
      ];
      expect(rects[0].bottom, lessThanOrEqualTo(rects[1].top));
      expect(rects[1].bottom, lessThanOrEqualTo(rects[2].top));
    });

    testWidgets('the Add earlier videos row is a button with its label and '
        'calls back', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(_card(earlier: true, onEarlier: () => taps++)),
      );

      final node = tester.getSemantics(
        find.bySemanticsLabel(
          'Add earlier videos, shot before Shooting mode was on',
        ),
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      await tester.tap(find.text('Add earlier videos'));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('three rows are refused', (tester) async {
      expect(
        () => TtShootingModeCard(
          on: true,
          title: 't',
          subtitle: 's',
          switchSemanticLabel: 'x',
          onChanged: (_) {},
          rows: [
            for (var i = 0; i < 3; i++)
              TtCardRow(
                icon: Symbols.link_rounded,
                title: '$i',
                onPressed: () {},
              ),
          ],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('the card with two rows and a strip passes accessibility', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            _card(rows: true, earlier: true, backdrop: fixtureThumb(2)),
            brightness: brightness,
            disableAnimations: true,
          ),
        );
        await expectTtAccessible(tester);
      }
    });

    testWidgets('a long subtitle wraps and does not overflow at 2x', (
      tester,
    ) async {
      for (final backdrop in [null, fixtureThumb(2)]) {
        await tester.pumpWidget(
          ttTestApp(
            // The card is taller than the screen here, as in a list.
            SingleChildScrollView(
              child: _card(
                subtitle: _longSubtitle,
                rows: true,
                backdrop: backdrop,
              ),
            ),
            textScale: 2,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('with no animations the dot does not pulse', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('semantics: the switch is named and toggled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_card()));
      final data = tester
          .getSemantics(find.byType(TtSwitch))
          .getSemanticsData();
      expect(data.label, 'Shooting mode');
      expect(data.flagsCollection.isToggled, ui.Tristate.isTrue);
      handle.dispose();
    });
  });

  group('TtCardRow', () {
    Widget row({
      String? subtitle,
      String? trailingText,
      VoidCallback? onPressed,
      String? semanticLabel,
    }) => Center(
      child: SizedBox(
        width: 328,
        child: TtCardRow(
          icon: Symbols.link_rounded,
          title: 'References · 4',
          subtitle: subtitle,
          trailingText: trailingText,
          semanticLabel: semanticLabel,
          onPressed: onPressed ?? () {},
        ),
      ),
    );

    testWidgets('a references row: title, subtitle and a chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(row(subtitle: 'From 2 Recording reels')),
      );
      expect(find.text('References · 4'), findsOneWidget);
      expect(find.text('From 2 Recording reels'), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_forward_rounded), findsNothing);
      expect(tester.getSize(find.byType(TtCardRow)).height, 56);
    });

    testWidgets('a strip: trailing text, an arrow and tertiary colours', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(row(trailingText: 'Tag now')));
      expect(find.text('Tag now'), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
      expect(tester.getSize(find.byType(TtCardRow)).height, 52);
      final tt = tester.element(find.byType(TtCardRow)).tt;
      expect(
        find.descendant(
          of: find.byType(TtCardRow),
          matching: find.byWidgetPredicate(
            (w) => w is Material && w.color == tt.colors.waitingContainer,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(row(onPressed: () => taps++)));
      await tester.tap(find.byType(TtCardRow));
      expect(taps, 1);
    });

    testWidgets('semantics: a button named semanticLabel, else its texts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(row(semanticLabel: 'Refs, four')));
      var data = tester.getSemantics(find.byType(TtCardRow)).getSemanticsData();
      expect(data.label, 'Refs, four');
      expect(data.flagsCollection.isButton, isTrue);
      await tester.pumpWidget(
        ttTestApp(row(subtitle: 'From 2 Recording reels')),
      );
      data = tester.getSemantics(find.byType(TtCardRow)).getSemanticsData();
      expect(data.label, 'References · 4, From 2 Recording reels');
      handle.dispose();
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('off card passes the accessibility guidelines '
        '(${brightness.name})', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(on: false), brightness: brightness),
      );
      await expectTtAccessible(tester);
    });

    testWidgets('on card passes the accessibility guidelines '
        '(${brightness.name})', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _card(rows: true),
          brightness: brightness,
          disableAnimations: true,
        ),
      );
      await expectTtAccessible(tester);
    });
  }
}
