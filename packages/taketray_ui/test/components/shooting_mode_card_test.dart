import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_glass_pixels.dart';
import '../support/tt_test_app.dart';
import '../support/tt_text_contrast.dart';

const _longSubtitle =
    'On since 9:41 AM · Manual mode: add clips yourself, because TakeTray '
    'cannot see new videos on its own right now';

const _referencesLabel = 'References, 4, from your Collecting reels';
const _earlierLabel = 'Add earlier videos, shot before Shooting mode was on';

List<TtShootingCardChip> _chips(int count, {List<VoidCallback>? taps}) => [
  if (count > 0)
    TtShootingCardChip(
      icon: Symbols.link_rounded,
      label: 'References · 4',
      semanticLabel: _referencesLabel,
      onPressed: taps == null ? () {} : () => taps.add(() {}),
    ),
  if (count > 1)
    TtShootingCardChip(
      icon: Symbols.history_rounded,
      label: 'Earlier videos',
      semanticLabel: _earlierLabel,
      onPressed: () {},
    ),
];

Widget _card({
  bool on = true,
  String subtitle = 'Since 9:41 AM',
  ImageProvider? backdrop,
  ValueChanged<bool>? onChanged,
  VoidCallback? onOpenCamera,
  int chips = 0,
  List<VoidCallback>? chipTaps,
  bool camera = true,
}) => Center(
  child: SizedBox(
    width: 328,
    child: TtShootingModeCard(
      on: on,
      title: on ? 'Shooting' : 'Shooting mode',
      subtitle: subtitle,
      semanticLabel: on ? 'Shooting mode, on' : 'Shooting mode, off',
      switchSemanticLabel: 'Shooting mode',
      onChanged: onChanged ?? (_) {},
      backdrop: backdrop,
      cameraLabel: camera ? 'Open camera' : null,
      onOpenCamera: camera ? (onOpenCamera ?? () {}) : null,
      chips: _chips(chips, taps: chipTaps),
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

/// A PNG of one flat colour, as a backdrop.
Future<MemoryImage> _flatImage(WidgetTester tester, Color color) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
        .drawRect(const Rect.fromLTWH(0, 0, 328, 200), Paint()..color = color);
    final picture = recorder.endRecording();
    final image = await picture.toImage(328, 200);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
  return MemoryImage(bytes!);
}

/// The chip's glass fill at fade [progress]: white .14 (home2.css:28) over a
/// black .23 that is there for AA (R12B-6, D-193).
Color _chipFill(double progress) => Color.alphaBlend(
  const Color(0xFFFFFFFF)
      .withValues(alpha: TtMetrics.shootingChipFillOpacity * progress),
  const Color(0xFF000000)
      .withValues(alpha: TtMetrics.shootingChipShadeOpacity * progress),
);

final Finder _theCard = find.byType(TtShootingModeCard);

/// The 40 dp icon tile: the nearest 40 x 40 box around the videocam glyph.
Finder get _tile => find
    .ancestor(
      of: find.byIcon(Symbols.videocam_rounded).first,
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 40 && w.height == 40,
      ),
    )
    .first;

/// The white Open camera pill's `Material`.
Finder get _pill => find
    .ancestor(of: find.text('Open camera'), matching: find.byType(Material))
    .first;

/// The glass of the chip with [label].
Finder _chipGlass(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(BackdropFilter))
    .first;

/// The 48 dp tap target around the thing that holds [of].
Finder _target(Finder of) =>
    find.ancestor(of: of, matching: find.byType(GestureDetector)).first;

/// The widgets between [filter] (exclusive) and the card (exclusive).
List<Widget> _above(Element filter) {
  final found = <Widget>[];
  filter.visitAncestorElements((e) {
    if (e.widget is TtShootingModeCard) return false;
    found.add(e.widget);
    return true;
  });
  return found;
}

bool _fades(Widget w) =>
    w is Opacity ||
    w is FadeTransition ||
    w is AnimatedOpacity ||
    w is ShaderMask;

double _fillAlpha(WidgetTester tester, Finder glass) => tester
    .widget<ColoredBox>(
      find.descendant(of: glass, matching: find.byType(ColoredBox)).first,
    )
    .color
    .a;

void main() {
  group('TtShootingModeCard, off', () {
    testWidgets('one row: a 40 dp tile on secondaryContainer, the texts and '
        'a switch, on surfaceContainerLow, padding 10/6/10/12, radius 24, '
        'no border', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(on: false, subtitle: 'Off · turn it on before you')),
      );
      final context = tester.element(_theCard);
      final scheme = context.scheme;
      final tt = context.tt;

      // The tile: 40 dp, radius 14, secondaryContainer, glyph 22 filled.
      expect(tester.getSize(_tile), const Size(40, 40));
      final tile = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _tile, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .single;
      expect(tile.color, scheme.secondaryContainer);
      expect(tile.borderRadius, BorderRadius.circular(14));
      final glyph = tester.widget<Icon>(
        find.descendant(of: _tile, matching: find.byType(Icon)),
      );
      expect(glyph.icon, Symbols.videocam_rounded);
      expect(glyph.fill, 1);
      expect(glyph.size, 22);
      expect(glyph.color, scheme.onSecondaryContainer);

      // The texts: titleMedium over bodySmall in onSurfaceVariant.
      final title = tester.widget<Text>(find.text('Shooting mode')).style!;
      expect(title.fontSize, tt.text.material.titleMedium!.fontSize);
      expect(title.color, scheme.onSurface);
      final subtitle = tester
          .widget<Text>(find.text('Off · turn it on before you'))
          .style!;
      expect(subtitle.fontSize, tt.text.material.bodySmall!.fontSize);
      expect(subtitle.color, scheme.onSurfaceVariant);
      final sw = tester.widget<TtSwitch>(find.byType(TtSwitch));
      expect(sw.value, isFalse);
      expect(sw.inverted, isFalse);

      // The surface, the corners, the padding, no border.
      expect(
        find.descendant(
          of: _theCard,
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == scheme.surfaceContainerLow,
          ),
        ),
        findsOneWidget,
      );
      expect(TtMetrics.shootingCardRadius, 24);
      expect(
        tester
            .widget<ClipRRect>(
              find
                  .descendant(of: _theCard, matching: find.byType(ClipRRect))
                  .first,
            )
            .borderRadius,
        BorderRadius.circular(24),
      );
      expect(
        tester
            .widget<AnimatedPadding>(
              find.descendant(
                of: _theCard,
                matching: find.byType(AnimatedPadding),
              ),
            )
            .padding
            .resolve(TextDirection.ltr),
        const EdgeInsets.fromLTRB(12, 10, 6, 10),
      );
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(of: _theCard, matching: find.byType(DecoratedBox)),
      )) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) expect(decoration.border, isNull);
        if (decoration is ShapeDecoration) {
          final shape = decoration.shape;
          if (shape is RoundedRectangleBorder) {
            expect(shape.side, BorderSide.none);
          }
        }
      }
      // One row: the switch's 48 dp plus the padding.
      expect(tester.getSize(_theCard).height, 10 + 48 + 10);
      expect(find.byType(TtRecDot), findsNothing);
    });

    testWidgets('no camera and no chips, even when given', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(on: false, chips: 2)));
      expect(find.text('Open camera'), findsNothing);
      expect(find.text('References · 4'), findsNothing);
      expect(find.text('Earlier videos'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(TtRecDot), findsNothing);
      expect(find.byIcon(Symbols.videocam_rounded), findsOneWidget);
      expect(tester.getSize(_theCard).height, 68);
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
    testWidgets('row 1, then Open camera (a white pill, 40 dp, black text), '
        'then the chips', (tester) async {
      var cameraTaps = 0;
      final chipTaps = <VoidCallback>[];
      await tester.pumpWidget(
        ttTestApp(
          _card(chips: 2, onOpenCamera: () => cameraTaps++, chipTaps: chipTaps),
        ),
      );
      final context = tester.element(_theCard);
      final tt = context.tt;
      expect(find.text('Shooting'), findsOneWidget);
      expect(find.text('Since 9:41 AM'), findsOneWidget);

      // Row 1, then the pill, then the chips, in reading order.
      final row1 = tester.getRect(find.byType(TtSwitch));
      final pill = tester.getRect(_pill);
      final first = tester.getRect(_chipGlass('References · 4'));
      expect(pill.top, greaterThanOrEqualTo(row1.bottom));
      expect(first.top >= pill.top, isTrue);
      expect(first.left > pill.right || first.top >= pill.bottom, isTrue);
      final second = tester.getRect(_chipGlass('Earlier videos'));
      expect(second.left > first.right || second.top >= first.bottom, isTrue);
      // At least 8 dp between neighbours (home2.css:25).
      if (first.top == pill.top) {
        expect(first.left - pill.right, 8);
      }

      // The pill: white, a stadium, 40 dp, a 20 dp videocam, black label.
      final material = tester.widget<Material>(_pill);
      expect(material.color, tt.colors.onMedia);
      expect(material.shape, const StadiumBorder());
      expect(tester.getSize(_pill).height, 40);
      final label = tester.widget<Text>(find.text('Open camera')).style!;
      expect(label.color, tt.colors.videoBackground);
      expect(label.fontSize, tt.text.material.labelLarge!.fontSize);
      final icon = tester.widget<Icon>(
        find.descendant(of: _pill, matching: find.byType(Icon)),
      );
      expect(icon.icon, Symbols.videocam_rounded);
      expect(icon.size, 20);
      expect(icon.color, tt.colors.videoBackground);
      // 12 before the icon, 16 after the text (home2.css:26).
      expect(
        tester.getTopLeft(find.byIcon(Symbols.videocam_rounded).last).dx -
            pill.left,
        12,
      );
      expect(pill.right - tester.getTopRight(find.text('Open camera')).dx, 16);
      // Its tap target is 48 dp tall.
      expect(tester.getSize(_target(_pill)).height, 48);

      await tester.tap(find.text('Open camera'));
      expect(cameraTaps, 1);
      await tester.tap(find.text('References · 4'));
      expect(chipTaps, hasLength(1));
    });

    testWidgets('with no chips: Open camera alone', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.text('Open camera'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNWidgets(1)); // the tile's
      // 12 + row 1 (48) + the pill's 48 dp target less its 4 dp slack above
      // and below, so the visible gaps stay 12.
      expect(tester.getSize(_theCard).height, 12 + 48 + 8 + 48 + 8);
    });

    testWidgets('with no camera label and no chips: row 1 alone', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(camera: false)));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Open camera'), findsNothing);
      expect(tester.getSize(_theCard).height, 12 + 48 + 12);
    });

    testWidgets('a chip: 40 dp, a 48 dp target, white text, an 18 dp icon, '
        'one button named its semanticLabel', (tester) async {
      final semantics = tester.ensureSemantics();
      final taps = <VoidCallback>[];
      await tester.pumpWidget(ttTestApp(_card(chips: 1, chipTaps: taps)));
      final tt = tester.element(_theCard).tt;
      final glass = _chipGlass('References · 4');

      expect(tester.getSize(glass).height, 40);
      expect(tester.getSize(_target(glass)).height, 48);
      expect(tester.getSize(_target(glass)).width, greaterThanOrEqualTo(48));
      final text = tester.widget<Text>(find.text('References · 4')).style!;
      expect(text.color, tt.colors.onMedia);
      expect(text.fontSize, tt.text.material.labelLarge!.fontSize);
      final icon = tester.widget<Icon>(
        find.descendant(of: glass, matching: find.byIcon(Symbols.link_rounded)),
      );
      expect(icon.size, 18);
      expect(icon.color, tt.colors.onMedia);
      // 10 before the icon, 14 after the text, 6 between (home2.css:28).
      final rect = tester.getRect(glass);
      final iconRect = tester.getRect(find.byIcon(Symbols.link_rounded));
      expect(iconRect.left - rect.left, 10);
      expect(
        rect.right - tester.getRect(find.text('References · 4')).right,
        14,
      );
      expect(
        tester.getRect(find.text('References · 4')).left - iconRect.right,
        6,
      );
      // A stadium of white .14 over black .23 (D-193), over a blur of 10.
      expect(_fillAlpha(tester, glass), closeTo(_chipFill(1).a, 1e-9));
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(of: glass, matching: find.byType(ColoredBox))
                  .first,
            )
            .color,
        _chipFill(1),
      );
      expect(
        tester
            .widget<ClipRRect>(
              find
                  .descendant(
                    of: _target(glass),
                    matching: find.byType(ClipRRect),
                  )
                  .first,
            )
            .borderRadius,
        BorderRadius.circular(tt.radii.full),
      );

      // One node: a button named its semanticLabel.
      expect(find.bySemanticsLabel(_referencesLabel), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel(_referencesLabel));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().label, _referencesLabel);
      expect(find.bySemanticsLabel('References · 4'), findsNothing);

      await tester.tapAt(
        tester.getTopLeft(_target(glass)) + const Offset(2, 2),
      );
      expect(taps, hasLength(1), reason: 'the margin of the target taps too');
      semantics.dispose();
    });

    testWidgets('three chips are refused', (tester) async {
      expect(
        () => TtShootingModeCard(
          on: true,
          title: 't',
          subtitle: 's',
          semanticLabel: 'x',
          switchSemanticLabel: 'x',
          onChanged: (_) {},
          chips: [
            for (var i = 0; i < 3; i++)
              TtShootingCardChip(
                icon: Symbols.link_rounded,
                label: '$i',
                semanticLabel: '$i',
                onPressed: () {},
              ),
          ],
        ),
        throwsAssertionError,
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

    testWidgets('the card is black with white texts: the title weight 800, '
        'the subtitle white at 85 %', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      final tt = tester.element(_theCard).tt;
      final title = tester.widget<Text>(find.text('Shooting')).style!;
      expect(title.fontWeight, FontWeight.w800);
      expect(title.color, tt.colors.onMedia);
      expect(title.fontSize, tt.text.material.titleMedium!.fontSize);
      final subtitle = tester.widget<Text>(find.text('Since 9:41 AM')).style!;
      expect(subtitle.color, tt.colors.onMedia.withValues(alpha: .85));
      expect(subtitle.fontSize, tt.text.material.bodySmall!.fontSize);
      expect(
        find.descendant(
          of: _theCard,
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == tt.colors.videoBackground,
          ),
        ),
        findsWidgets,
      );
      // On: 12 on every side of row 1 (the bottom, under the pill's target,
      // is 8 so the visible gap is 12).
      expect(
        tester
            .widget<AnimatedPadding>(
              find.descendant(
                of: _theCard,
                matching: find.byType(AnimatedPadding),
              ),
            )
            .padding
            .resolve(TextDirection.ltr),
        const EdgeInsets.fromLTRB(12, 12, 12, 8),
      );
    });

    testWidgets(
      'the tile is white 16 % glass, blur 8, a 22 dp white videocam',
      (tester) async {
        await tester.pumpWidget(ttTestApp(_card(camera: false)));
        final tt = tester.element(_theCard).tt;
        expect(tester.getSize(_tile), const Size(40, 40));
        final glass = find.descendant(
          of: _tile,
          matching: find.byType(BackdropFilter),
        );
        expect(glass, findsOneWidget);
        expect(
          tester.widget<BackdropFilter>(glass).filter,
          ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        );
        expect(
          tester
              .widget<ColoredBox>(
                find
                    .descendant(of: glass, matching: find.byType(ColoredBox))
                    .first,
              )
              .color,
          tt.colors.onMedia.withValues(alpha: .16),
        );
        final glyph = tester.widget<Icon>(
          find.descendant(of: _tile, matching: find.byType(Icon)),
        );
        expect(glyph.size, 22);
        expect(glyph.fill, 1);
        expect(glyph.color, tt.colors.onMedia);
      },
    );

    for (final direction in TextDirection.values) {
      testWidgets("the REC dot sits 2 dp outside the tile's top end corner, "
          'with a 2 dp black ring (${direction.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(Directionality(textDirection: direction, child: _card())),
        );
        final tt = tester.element(_theCard).tt;
        final tile = tester.getRect(_tile);
        final dot = tester.getRect(find.byType(TtRecDot));
        expect(dot.size, const Size.square(10));
        expect(dot.top, tile.top - 2);
        if (direction == TextDirection.ltr) {
          expect(dot.right, tile.right + 2);
        } else {
          expect(dot.left, tile.left - 2);
        }
        final ring = tester.widget<TtRecDot>(find.byType(TtRecDot)).outline;
        expect(ring, tt.colors.videoBackground);
        expect(ring, const Color(0xFF000000));
        expect(TtMetrics.recDotOutlineWidth, 2);
      });
    }

    testWidgets('the backdrop is drawn at 55 % opacity', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(backdrop: fixtureThumb(2))));
      await _decode(tester, fixtureThumb(2));
      final image = find.descendant(of: _theCard, matching: find.byType(Image));
      expect(image, findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: image, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, closeTo(0.55, 1e-9));
    });

    testWidgets('no backdrop builds no image', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(
        find.descendant(of: _theCard, matching: find.byType(Image)),
        findsNothing,
      );
    });

    testWidgets('a backdrop that fails to load leaves the plain black card', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_card(backdrop: brokenImage, chips: 1)),
      );
      await tester.runAsync(
        () => precacheImage(
          brokenImage,
          tester.element(_theCard),
          onError: (_, _) {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Shooting'), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
      expect(find.text('References · 4'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('the tint is 160°, .86 then .40 at 60 % then black .55 '
          '(${brightness.name})', (tester) async {
        // The values are the CSS's (home2.css:11).
        expect(TtMetrics.shootingTintAngle, 160);
        expect(TtMetrics.shootingTintStartOpacity, .86);
        expect(TtMetrics.shootingTintMiddleOpacity, .40);
        expect(TtMetrics.shootingTintMiddleStop, .60);
        expect(TtMetrics.shootingTintEndOpacity, .55);
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ttPixelApp(_card(), brightness: brightness, disableAnimations: true),
        );
        // home2.css:11: rgba(36, 49, 66, …) in light and dark alike.
        const tint = Color.fromARGB(255, 36, 49, 66);
        final box = tester.getRect(_theCard);
        final photo = await TtPixels.capture(tester);

        // Where each probe lies along the 160° line, and what the CSS
        // gradient gives there over black. The probes are in the card's
        // empty corners and gutter, away from the tile, the texts and the
        // switch, and inside the rounded corners.
        const angle = 160 * math.pi / 180;
        final direction = Offset(math.sin(angle), -math.cos(angle));
        final length = box.width * direction.dx + box.height * direction.dy;
        double along(Offset p) =>
            ((p - box.center).dx * direction.dx +
                (p - box.center).dy * direction.dy +
                length / 2) /
            length;
        double expectedChannel(double t, double Function(Color) channel) {
          // Unpremultiplied stops: tint .86, tint .40 at .6, black .55.
          final double alpha;
          final double value;
          if (t <= .6) {
            final u = t / .6;
            alpha = .86 + (.40 - .86) * u;
            value = channel(tint);
          } else {
            final u = (t - .6) / .4;
            alpha = .40 + (.55 - .40) * u;
            value = channel(tint) * (1 - u);
          }
          return value * alpha; // over black
        }

        final probes = [
          Offset(box.left + 4, box.top + 14),
          Offset(box.left + 4, box.bottom - 14),
          Offset(box.right - 5, box.top + 30),
        ];
        expect(along(probes[0]), lessThan(.1));
        expect(along(probes[2]), closeTo(.6, .03));
        for (final p in probes) {
          final t = along(p);
          final got = photo.colorAt(p);
          for (final (name, channel, actual) in [
            ('red', (Color c) => c.r, got.r),
            ('green', (Color c) => c.g, got.g),
            ('blue', (Color c) => c.b, got.b),
          ]) {
            expect(
              actual,
              closeTo(expectedChannel(t, channel), .02),
              reason: '$name at t=${t.toStringAsFixed(2)} ($p)',
            );
          }
        }
        // The end of the line is darker than the middle: black .55.
        final end = photo.colorAt(Offset(box.right - 5, box.bottom - 30));
        final middle = photo.colorAt(probes[2]);
        expect(end.r + end.g + end.b, lessThan(middle.r + middle.g + middle.b));
      });
    }

    testWidgets('switching on: the same TtSwitch element; the height '
        'animates over medium2', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(on: false, chips: 2)));
      final element = tester.element(find.byType(TtSwitch));
      final off = tester.getSize(_theCard).height;
      expect(off, 68);

      await tester.pumpWidget(ttTestApp(_card(chips: 2)));
      await tester.pump();
      expect(tester.element(find.byType(TtSwitch)), same(element));
      expect(tester.getSize(_theCard).height, off, reason: 'frame 0');
      await tester.pump(const Duration(milliseconds: 100));
      final early = tester.getSize(_theCard).height;
      expect(early, greaterThan(off));
      await tester.pump(const Duration(milliseconds: 150));
      final late = tester.getSize(_theCard).height;
      expect(late, greaterThan(early));
      await tester.pump(const Duration(milliseconds: 50));
      final done = tester.getSize(_theCard).height;
      expect(done, greaterThanOrEqualTo(late));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getSize(_theCard).height,
        done,
        reason: 'settled at 300 ms',
      );
      expect(done, greaterThan(150));
      expect(tester.element(find.byType(TtSwitch)), same(element));

      // And back: the same element again.
      await tester.pumpWidget(ttTestApp(_card(on: false, chips: 2)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(_theCard).height, lessThan(done));
      expect(tester.element(find.byType(TtSwitch)), same(element));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(_theCard).height, off);
    });

    testWidgets("no Opacity or FadeTransition above a chip's BackdropFilter, "
        'also mid-fade; sigma 10 from the first frame', (tester) async {
      final steady = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
      await tester.pumpWidget(ttTestApp(_card(on: false, chips: 2)));
      await tester.pumpWidget(ttTestApp(_card(chips: 2)));

      final filters = {
        for (final label in ['References · 4', 'Earlier videos'])
          label: _chipGlass(label),
      };
      final firstElements = <String, Element>{};
      Future<void> check(String when) async {
        for (final MapEntry(:key, :value) in filters.entries) {
          final element = tester.element(value);
          expect(
            (element.widget as BackdropFilter).filter,
            steady,
            reason: '$key $when',
          );
          expect(
            _above(element).where(_fades),
            isEmpty,
            reason: '$key $when: a fade above the filter',
          );
          expect(
            element,
            same(firstElements.putIfAbsent(key, () => element)),
            reason: '$key $when: the same filter widget',
          );
        }
      }

      await check('on the first frame');
      await tester.pump();
      await check('after the first pump');
      var previous = -1.0;
      for (final ms in [16, 100, 100, 100, 100]) {
        await tester.pump(Duration(milliseconds: ms));
        await check('after +$ms ms');
        final alpha = _fillAlpha(tester, filters['References · 4']!);
        expect(alpha, greaterThanOrEqualTo(previous), reason: 'only grows');
        previous = alpha;
      }
      expect(
        previous,
        closeTo(_chipFill(1).a, 1e-9),
        reason: 'ends at the chip fill',
      );
    });

    testWidgets('the chips fade in by their fill and content, over medium2', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(on: false, chips: 1)));
      await tester.pumpWidget(ttTestApp(_card(chips: 1)));
      final glass = _chipGlass('References · 4');
      await tester.pump();
      expect(_fillAlpha(tester, glass), closeTo(0, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _fillAlpha(tester, glass);
      expect(mid, inExclusiveRange(0, _chipFill(1).a));
      // The content fades inside the fill.
      final content = tester.widget<Opacity>(
        find.descendant(of: glass, matching: find.byType(Opacity)).first,
      );
      expect(content.opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_fillAlpha(tester, glass), closeTo(_chipFill(1).a, 1e-9));
    });

    testWidgets('reduced motion: no size animation, the fades still run '
        'over short4', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(on: false, chips: 1), disableAnimations: true),
      );
      await tester.pumpWidget(
        ttTestApp(_card(chips: 1), disableAnimations: true),
      );
      await tester.pump();
      final settled = tester.getSize(_theCard).height;
      expect(settled, greaterThan(68), reason: 'the size is final at once');
      final glass = _chipGlass('References · 4');
      expect(_fillAlpha(tester, glass), closeTo(0, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(_theCard).height, settled);
      final mid = _fillAlpha(tester, glass);
      expect(
        mid,
        inExclusiveRange(0, _chipFill(1).a),
        reason: 'the fade still runs',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fillAlpha(tester, glass), closeTo(_chipFill(1).a, 1e-9));
      expect(tester.getSize(_theCard).height, settled);
    });

    testWidgets('2x text at 360: the chips wrap, no overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final backdrop in [null, fixtureThumb(2)]) {
        await tester.pumpWidget(
          ttTestApp(
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TtShootingModeCard(
                  on: true,
                  title: 'Shooting',
                  subtitle: _longSubtitle,
                  semanticLabel: 'Shooting mode, on',
                  switchSemanticLabel: 'Shooting mode',
                  onChanged: (_) {},
                  backdrop: backdrop,
                  cameraLabel: 'Open camera',
                  onOpenCamera: () {},
                  chips: _chips(2),
                ),
              ),
            ),
            textScale: 2,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        final tops = [
          tester.getRect(_pill).top,
          tester.getRect(_chipGlass('References · 4')).top,
          tester.getRect(_chipGlass('Earlier videos')).top,
        ];
        expect(tops[1], greaterThan(tops[0]), reason: 'the first chip wraps');
        expect(tops[2], greaterThan(tops[1]), reason: 'the second chip wraps');
        expect(
          tester.getRect(_theCard).right,
          lessThanOrEqualTo(360 - 16 + .01),
        );
      }
    });

    // R12B-6: the handoff's AA line wins over home2.css's chip fill (white
    // .14). Over a pure white frame (sky, snow) the chips sit where the tint
    // is lightest, and at .14 their text was 4.27:1 ("References · 4") and
    // 4.14:1 ("Earlier videos"); see D-193 for the fill that clears it.
    for (final (name, chips, textScale) in [
      ('both chips', 2, 1.0),
      ('one chip', 1, 1.0),
      ('both chips at 2x', 2, 2.0),
    ]) {
      testWidgets('white chip text is AA over a white backdrop ($name)', (
        tester,
      ) async {
        final white = await _flatImage(tester, const Color(0xFFFFFFFF));
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            ttTestApp(
              SingleChildScrollView(
                child: _card(backdrop: white, chips: chips),
              ),
              brightness: brightness,
              disableAnimations: true,
              textScale: textScale,
            ),
          );
          await _decode(tester, white);
          await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
        }
      });
    }

    testWidgets('the chips measure at least 4.5:1 over white, the ratio '
        'pinned', (tester) async {
      final white = await _flatImage(tester, const Color(0xFFFFFFFF));
      for (final (chips, textScale) in [(2, 1.0), (1, 1.0), (2, 2.0)]) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            ttTestApp(
              SingleChildScrollView(
                child: _card(backdrop: white, chips: chips),
              ),
              brightness: brightness,
              disableAnimations: true,
              textScale: textScale,
            ),
          );
          await _decode(tester, white);
          final samples = await measureTtTextContrast(tester);
          for (final sample in samples.where(
            (s) => s.text == 'References · 4' || s.text == 'Earlier videos',
          )) {
            // Measured with white .14 over black .23: 5.70 and 5.53 (both
            // chips), 5.88 (one chip), 4.56 and 5.68 at 2x (the worst, the
            // first chip, where the tint is lightest). Without the black
            // (white .14 alone) they were 4.27, 4.14, 4.44 and 3.29. A drop
            // under 4.5 means the chips' fill got too light again.
            expect(
              sample.ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${sample.text} ($chips chips, ${textScale}x, '
                  '${brightness.name})',
            );
          }
          expect(samples.map((s) => s.text), containsAll(['Open camera']));
        }
      }
    });

    testWidgets('the card has a top-level label; the switch keeps its own '
        'node', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        for (final on in [true, false]) {
          await tester.pumpWidget(ttTestApp(_card(on: on, chips: 1)));
          final node = tester.getSemantics(
            find.bySemanticsLabel(
              on ? 'Shooting mode, on' : 'Shooting mode, off',
            ),
          );
          final data = node.getSemanticsData();
          expect(node.childrenCount, greaterThan(0));
          expect(data.flagsCollection.isToggled, ui.Tristate.none);
          final switchData = tester
              .getSemantics(find.byType(TtSwitch))
              .getSemanticsData();
          expect(switchData.label, 'Shooting mode');
          expect(
            switchData.flagsCollection.isToggled,
            on ? ui.Tristate.isTrue : ui.Tristate.isFalse,
          );
        }
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Open camera is a button named its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_card()));
      final node = tester.getSemantics(find.bySemanticsLabel('Open camera'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('with no animations the dot does not pulse', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: off accessible', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(on: false), brightness: brightness),
      );
      await expectTtAccessible(tester);
    });

    testWidgets('${brightness.name}: on accessible, with both chips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _card(chips: 2, backdrop: fixtureThumb(2)),
          brightness: brightness,
          disableAnimations: true,
        ),
      );
      await _decode(tester, fixtureThumb(2));
      await expectTtAccessible(tester);
    });

    testWidgets('${brightness.name}: on accessible, at 2x', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          SingleChildScrollView(child: _card(chips: 2)),
          brightness: brightness,
          disableAnimations: true,
          textScale: 2,
        ),
      );
      await expectTtAccessible(tester);
    });
  }
}
