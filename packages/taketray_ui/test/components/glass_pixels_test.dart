import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/saturation.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_glass_pixels.dart';

// Pixel tests for every glass piece in the package (Phase 12, D-173).
//
// Each piece sits over sharp black and white stripes at 360 x 800 and a pixel
// ratio of 1. The stripes are `ttStripes()` behind a free-standing piece, and
// an image of the same stripes (`_stripesImage`) behind a piece that sits on
// a picture (the reel cover, the shooting card's backdrop).
//
// The sample is a strip of the glass free of glyphs (the glyphs' own box is
// measured, not guessed), 2 dp inside the glass edge. A strip at least
// 5 dp wide always holds both a black and a white stripe, so its sharp
// contrast is the full 1; every test also asserts that.

const _blur8 = 8.0;

/// What the snack's elevation 3 shadow may take off the stripes' contrast
/// just outside the panel's corner (measured: under .02; its alphas are .30
/// and .15, and it fades out).
const _snackShadow = .1;

/// The corner radius of the pills (`tt.radii.s`).
const _pillRadius = 8.0;

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A PNG of [width] x 2000 px of the stripes, which change colour along x
/// (black for the first 4 px), to sit behind glass as a picture. Shown at
/// [width] dp wide with `BoxFit.cover` the picture is drawn 1:1.
Future<MemoryImage> _stripesImage(WidgetTester tester, int width) async {
  const height = 2000;
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final white = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = false;
    final black = Paint()
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height * 1.0), white);
    for (var x = 0.0; x < width; x += ttStripePeriod) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, ttStripePeriod / 2, height * 1.0),
        black,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
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

Future<void> _decode(WidgetTester tester, ImageProvider image, Type of) async {
  await tester.runAsync(
    () => precacheImage(
      image,
      tester.element(find.byType(of)),
      onError: (_, _) {},
    ),
  );
  // The picture is in the image cache now; settle is not used (the shooting
  // card's record dot never stops animating).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The strip of [glass] (a `BackdropFilter` finder, clipped to a corner
/// [radius]) that holds no glyph, 2 dp inside the glass edge and between the
/// rounded corners: the left one, or the right one when the left is
/// under 5 dp wide. Fails when neither is 5 dp wide.
Rect _freeStrip(WidgetTester tester, Finder glass, {double radius = 0}) {
  final box = tester.getRect(glass);
  // The rows start where the rounded corner is less than 2 dp in from the
  // straight edge.
  final rows = radius <= 2 ? 2.0 : radius - 2 * math.sqrt(radius - 1);
  Rect? glyphs;
  for (final kind in [find.byType(Icon), find.byType(RichText)]) {
    final found = find.descendant(of: glass, matching: kind);
    for (var i = 0; i < found.evaluate().length; i++) {
      final rect = tester.getRect(found.at(i));
      glyphs = glyphs == null ? rect : glyphs.expandToInclude(rect);
    }
  }
  expect(glyphs, isNotNull, reason: 'the glass has a glyph to keep clear of');
  final left = Rect.fromLTRB(
    box.left + 2,
    box.top + rows,
    glyphs!.left,
    box.bottom - rows,
  );
  final right = Rect.fromLTRB(
    glyphs.right,
    box.top + rows,
    box.right - 2,
    box.bottom - rows,
  );
  final strip = left.width >= 5 ? left : right;
  expect(
    strip.width,
    greaterThanOrEqualTo(5),
    reason: 'a strip free of glyphs, with room for a black and a white stripe',
  );
  return strip;
}

/// The strip of [glass] between its last text and its last icon (a card
/// row's gap before the arrow), 2 dp inside its top and bottom edges. Far
/// enough from the glass's edges that its blur cannot lean on the edge pixels.
Rect _gapStrip(WidgetTester tester, Finder glass) {
  final box = tester.getRect(glass);
  final texts = find.descendant(of: glass, matching: find.byType(Text));
  final icons = find.descendant(of: glass, matching: find.byType(Icon));
  var from = box.left;
  for (var i = 0; i < texts.evaluate().length; i++) {
    // The paragraph's box can fill the room it is given: measure the glyphs.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: texts.at(i), matching: find.byType(RichText)),
    );
    final text = paragraph.text.toPlainText();
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final left = paragraph.localToGlobal(Offset.zero).dx;
    for (final box in boxes) {
      from = math.max(from, left + box.right);
    }
  }
  var to = box.left;
  for (var i = 0; i < icons.evaluate().length; i++) {
    to = math.max(to, tester.getRect(icons.at(i)).left);
  }
  final strip = Rect.fromLTRB(from + 2, box.top + 2, to - 2, box.bottom - 2);
  expect(strip.width, greaterThanOrEqualTo(2 * ttStripePeriod));
  return strip;
}

/// The glass's contrast over the stripes, and the same rect's contrast with
/// the piece absent (`sharp`, which must be at least `minSharp`: a scrim over
/// a picture takes some of the stripes' contrast). Ends with the piece on
/// screen again, for the filter checks.
Future<({double blurred, double sharp})> _measure(
  WidgetTester tester, {
  required Widget Function({required bool piece}) build,
  required Type of,
  required Finder Function() glass,
  ImageProvider? picture,
  double minSharp = .95,
  double radius = 0,
}) async {
  _phone(tester);
  await tester.pumpWidget(ttPixelApp(build(piece: true)));
  if (picture != null) await _decode(tester, picture, of);
  final rect = _freeStrip(tester, glass(), radius: radius);
  final blurred = (await TtPixels.capture(tester)).edgeContrast(rect);
  await tester.pumpWidget(ttPixelApp(build(piece: false)));
  if (picture != null) await _decode(tester, picture, of);
  final sharp = (await TtPixels.capture(tester)).edgeContrast(rect);
  expect(
    sharp,
    greaterThan(minSharp),
    reason: 'the stripes are sharp without it',
  );
  await tester.pumpWidget(ttPixelApp(build(piece: true)));
  if (picture != null) await _decode(tester, picture, of);
  return (blurred: blurred, sharp: sharp);
}

Finder _glassIn(Type piece) => find.descendant(
  of: find.byType(piece),
  matching: find.byType(BackdropFilter),
);

/// Every `BackdropFilter` [glass] finds (at least one) blurs by [sigma].
void _expectSigma(Finder glass, double sigma) {
  expect(glass, findsAtLeastNWidgets(1));
  for (final element in glass.evaluate()) {
    expect(
      (element.widget as BackdropFilter).filter,
      ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
  }
}

Finder _glassOver(IconData icon) =>
    find.ancestor(of: find.byIcon(icon), matching: find.byType(BackdropFilter));

Widget _onStripes(Widget piece) => Stack(
  fit: StackFit.expand,
  children: [
    ttStripes(),
    Positioned(left: 16, top: 96, child: piece),
  ],
);

TtStatusPill _statusPill({VoidCallback? onPressed}) => TtStatusPill(
  kind: TtStatusKind.ready,
  label: 'Ready to edit',
  onMedia: true,
  onPressed: onPressed,
);

Widget _reelCard(ImageProvider cover, {int references = 0, String? vnLabel}) =>
    Stack(
      children: [
        Positioned(
          left: 16,
          top: 96,
          width: 158,
          child: TtReelCard(
            name: 'Lisbon trip',
            semanticLabel: 'Lisbon trip. Collecting. 12 clips',
            status: TtStatusKind.collecting,
            statusLabel: 'Collecting',
            meta: '12 clips · 1:03',
            emptyLabel: 'No clips yet',
            cover: cover,
            vnLabel: vnLabel,
            referenceCount: references,
            referencesSemanticLabel: '$references references in Lisbon trip',
            onTap: () {},
            onReferencesTap: () {},
          ),
        ),
      ],
    );

Widget _shootingCard(ImageProvider backdrop) => Stack(
  children: [
    Positioned(
      left: 16,
      top: 96,
      width: 328,
      child: TtShootingModeCard(
        on: true,
        title: 'Shooting mode on',
        subtitle: 'On since 9:41 AM',
        semanticLabel: 'Shooting mode, on',
        switchSemanticLabel: 'Shooting mode',
        onChanged: (_) {},
        backdrop: backdrop,
        rows: [
          TtCardRow(
            kind: TtCardRowKind.link,
            icon: Symbols.link_rounded,
            title: 'References · 4',
            subtitle: 'From 2 Recording reels',
            semanticLabel: 'References, 4, from your Recording reels',
            onPressed: () {},
          ),
        ],
        toTagStrip: TtCardRow(
          kind: TtCardRowKind.strip,
          icon: Symbols.sell_rounded,
          title: '3 clips to tag',
          trailingText: 'Tag now',
          onPressed: () {},
        ),
      ),
    ),
  ],
);

Widget _navPill() => Stack(
  fit: StackFit.expand,
  children: [
    ttStripes(),
    Align(
      alignment: Alignment.bottomCenter,
      child: TtNavPill(
        currentIndex: 1,
        onSelected: (_) {},
        items: const [
          TtNavItem(icon: Symbols.video_library_rounded, label: 'Reels'),
          TtNavItem(icon: Symbols.sell_rounded, label: 'To tag'),
          TtNavItem(icon: Symbols.settings_rounded, label: 'Settings'),
        ],
      ),
    ),
  ],
);

void main() {
  group('every BackdropFilter has a plain fill first', () {
    // A Material first lost the blur on the S24 (the reel cover pill);
    // a ColoredBox or a coloured DecoratedBox kept it.
    final pieces = <String, Widget Function(WidgetTester)>{
      'TtStatusPill on media': (_) => _onStripes(_statusPill()),
      'TtStatusPill on media, pressable': (_) =>
          _onStripes(_statusPill(onPressed: () {})),
      'TtGlassPill': (_) => _onStripes(
        const TtGlassPill(
          icon: Symbols.folder_copy_rounded,
          text: 'Editing in VN',
          semanticLabel: 'Editing in VN',
        ),
      ),
      'TtNavPill': (_) => _navPill(),
    };
    for (final MapEntry(:key, :value) in pieces.entries) {
      testWidgets(key, (tester) async {
        _phone(tester);
        await tester.pumpWidget(ttPixelApp(value(tester)));
        expectGlassStructure(tester, find.byType(Scaffold));
      });
    }

    testWidgets('TtReelCard with 3 references and a VN pill', (tester) async {
      _phone(tester);
      final cover = await _stripesImage(tester, 158);
      await tester.pumpWidget(
        ttPixelApp(_reelCard(cover, references: 3, vnLabel: 'Editing in VN')),
      );
      await _decode(tester, cover, TtReelCard);
      // The status pill, the VN pill and the badge: three filters.
      expect(_glassIn(TtReelCard), findsNWidgets(3));
      expectGlassStructure(tester, find.byType(TtReelCard));
    });

    testWidgets('TtShootingModeCard on, with a references row', (tester) async {
      _phone(tester);
      final backdrop = await _stripesImage(tester, 328);
      await tester.pumpWidget(ttPixelApp(_shootingCard(backdrop)));
      await _decode(tester, backdrop, TtShootingModeCard);
      // The icon tile and the references row: two filters.
      expect(_glassIn(TtShootingModeCard), findsNWidgets(2));
      expectGlassStructure(tester, find.byType(TtShootingModeCard));
    });
  });

  group('the glass blurs what is behind it', () {
    testWidgets('status pill on media blurs by 8 under its .58 fill', (
      tester,
    ) async {
      final c = await _measure(
        tester,
        build: ({required piece}) =>
            _onStripes(piece ? _statusPill() : const SizedBox.shrink()),
        of: Scaffold,
        glass: () => _glassIn(TtStatusPill),
        radius: _pillRadius,
      );
      expectBlurred(c.blurred, sharp: c.sharp, fillOpacity: .58);
      _expectSigma(_glassIn(TtStatusPill), _blur8);
    });

    testWidgets('Editing in VN pill blurs by 8', (tester) async {
      final cover = await _stripesImage(tester, 158);
      final c = await _measure(
        tester,
        build: ({required piece}) =>
            _reelCard(cover, vnLabel: piece ? 'Editing in VN' : null),
        of: TtReelCard,
        glass: () => _glassOver(Symbols.folder_copy_rounded),
        radius: _pillRadius,
        picture: cover,
        minSharp: .2,
      );
      expectBlurred(c.blurred, sharp: c.sharp, fillOpacity: .58);
      _expectSigma(_glassIn(TtGlassPill), _blur8);
    });

    testWidgets('reel card references badge blurs by 8', (tester) async {
      final cover = await _stripesImage(tester, 158);
      final c = await _measure(
        tester,
        build: ({required piece}) =>
            _reelCard(cover, references: piece ? 3 : 0),
        of: TtReelCard,
        glass: () => _glassOver(Symbols.link_rounded),
        radius: _pillRadius,
        picture: cover,
        minSharp: .2,
      );
      expectBlurred(c.blurred, sharp: c.sharp, fillOpacity: .58);
      _expectSigma(_glassOver(Symbols.link_rounded), _blur8);
    });

    testWidgets('Shooting mode icon tile blurs by 8', (tester) async {
      _phone(tester);
      final backdrop = await _stripesImage(tester, 328);
      await tester.pumpWidget(ttPixelApp(_shootingCard(backdrop)));
      await _decode(tester, backdrop, TtShootingModeCard);
      final tile = _glassOver(Symbols.videocam_rounded);
      // The card's own picture is behind the tile, so the sharp reference is
      // the strip of the card beside the tile, in the same rows.
      final strip = _freeStrip(
        tester,
        tile,
        radius: TtMetrics.shootingIconRadius,
      );
      final beside = Rect.fromLTRB(
        tester.getRect(find.byType(TtShootingModeCard)).left + 2,
        strip.top,
        tester.getRect(tile).left - 2,
        strip.bottom,
      );
      final photo = await TtPixels.capture(tester);
      final sharp = photo.edgeContrast(beside);
      expect(sharp, greaterThan(.2), reason: 'the picture is sharp beside it');
      expectBlurred(photo.edgeContrast(strip), sharp: sharp, fillOpacity: .16);
      _expectSigma(tile, _blur8);
    });

    testWidgets('Shooting mode references row blurs by 6', (tester) async {
      _phone(tester);
      final backdrop = await _stripesImage(tester, 328);
      await tester.pumpWidget(ttPixelApp(_shootingCard(backdrop)));
      await _decode(tester, backdrop, TtShootingModeCard);
      final row = _glassOver(Symbols.link_rounded);
      final tile = _glassOver(Symbols.videocam_rounded);
      final beside = _freeStrip(
        tester,
        tile,
        radius: TtMetrics.shootingIconRadius,
      );
      final photo = await TtPixels.capture(tester);
      // Sharp: the picture beside the icon tile, with the same left edge as
      // the card's (the stripes change along x only).
      final sharp = photo.edgeContrast(
        Rect.fromLTRB(
          tester.getRect(find.byType(TtShootingModeCard)).left + 2,
          beside.top,
          tester.getRect(tile).left - 2,
          beside.bottom,
        ),
      );
      expect(sharp, greaterThan(.2), reason: 'the picture is sharp beside it');
      expectBlurred(
        photo.edgeContrast(_gapStrip(tester, row)),
        sharp: sharp,
        fillOpacity: .25,
      );
      _expectSigma(row, 6);
    });

    testWidgets('nav pill blurs by 18 under its .78 glass', (tester) async {
      final c = await _measure(
        tester,
        build: ({required piece}) => piece
            ? _navPill()
            : Stack(fit: StackFit.expand, children: [ttStripes()]),
        of: Scaffold,
        glass: () => _glassIn(TtNavPill),
        radius: TtMetrics.navPillRadius,
      );
      expectBlurred(c.blurred, sharp: c.sharp, fillOpacity: .78);
      // Blur 18, then saturate 1.4, as the CSS `blur(18px) saturate(1.4)`
      // (D-175; the stripes' period cannot tell 18 from 12, so the filter is
      // pinned by equality).
      final filters = _glassIn(TtNavPill).evaluate().toList();
      expect(filters, hasLength(1));
      expect(
        (filters.single.widget as BackdropFilter).filter,
        ui.ImageFilter.compose(
          outer: ui.ColorFilter.matrix(ttSaturationMatrix(1.4)),
          inner: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        ),
      );
    });

    group('the nav pill over a flat colour (D-175)', () {
      /// The point 3 dp inside the pill's left end, on its middle line: past
      /// the hairline, left of the first item, and where the shadow's blurred
      /// edge used to show through the glass.
      Future<({TtPixels photo, Rect pill, Color fill})> pillOver(
        WidgetTester tester,
        Color background,
      ) {
        _phone(tester);
        return ttWithBlurredShadows(() async {
          await tester.pumpWidget(
            ttPixelApp(
              Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: background),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TtNavPill(
                      currentIndex: 1,
                      onSelected: (_) {},
                      items: const [
                        TtNavItem(
                          icon: Symbols.video_library_rounded,
                          label: 'Reels',
                        ),
                        TtNavItem(icon: Symbols.sell_rounded, label: 'To tag'),
                        TtNavItem(
                          icon: Symbols.settings_rounded,
                          label: 'Settings',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          final fill = tester.element(find.byType(TtNavPill)).tt.colors.glass;
          return (
            photo: await TtPixels.capture(tester),
            pill: tester.getRect(find.byType(TtGlass)),
            fill: fill,
          );
        });
      }

      int chroma(Color c) {
        final channels = [c.r, c.g, c.b].map((v) => (v * 255).round());
        return channels.reduce(math.max) - channels.reduce(math.min);
      }

      void expectClose(Color actual, Color expected, int tolerance) {
        for (final (name, a, e) in [
          ('r', actual.r, expected.r),
          ('g', actual.g, expected.g),
          ('b', actual.b, expected.b),
        ]) {
          expect(
            (a * 255).round(),
            closeTo((e * 255).round(), tolerance),
            reason: 'channel $name of $actual vs $expected',
          );
        }
      }

      /// `saturate(1.4)` of an opaque [c], as the CSS filter computes it.
      Color saturated(Color c) {
        final m = ttSaturationMatrix(TtMetrics.navPillSaturation);
        final rgb = [c.r * 255, c.g * 255, c.b * 255];
        int channel(int row) {
          final v =
              m[row * 5] * rgb[0] +
              m[row * 5 + 1] * rgb[1] +
              m[row * 5 + 2] * rgb[2];
          return v.round().clamp(0, 255);
        }

        return Color.fromARGB(255, channel(0), channel(1), channel(2));
      }

      testWidgets('the glass is more saturated than the plain blend', (
        tester,
      ) async {
        const background = Color(0xFF8A5CC2);
        final shot = await pillOver(tester, background);
        final at = Offset(shot.pill.left + 3, shot.pill.center.dy);
        final seen = shot.photo.colorAt(at);
        expectClose(
          seen,
          Color.alphaBlend(shot.fill, saturated(background)),
          3,
        );
        final plain = Color.alphaBlend(shot.fill, background);
        expect(chroma(seen), greaterThan(chroma(plain) + 2));
      });

      testWidgets('the shadow is not under the glass', (tester) async {
        const white = Color(0xFFFFFFFF);
        final shot = await pillOver(tester, white);
        final at = Offset(shot.pill.left + 3, shot.pill.center.dy);
        // Saturating white leaves it white, so only the fill shows.
        expectClose(
          shot.photo.colorAt(at),
          Color.alphaBlend(shot.fill, white),
          2,
        );
        // Under the pill the shadow still falls: offset 10, blur 30, spread -8.
        final below = shot.photo.colorAt(
          Offset(shot.pill.center.dx, shot.pill.bottom + 6),
        );
        expect((below.r * 255).round(), lessThan(255 - 4));
      });
    });
  });

  group('the pressable status pill on media', () {
    testWidgets('a tap still ripples and calls onPressed', (tester) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(
        ttPixelApp(
          // The test renderer draws no sparkle shader; the ordinary ripple
          // shows the same ink.
          Builder(
            builder: (context) => Theme(
              data: Theme.of(context)
                  .copyWith(splashFactory: InkRipple.splashFactory),
              child: _onStripes(_statusPill(onPressed: () => taps++)),
            ),
          ),
        ),
      );
      final pill = find.byType(TtStatusPill);
      final glass = _glassIn(TtStatusPill);
      final rect = tester.getRect(glass);
      final at = tester.getCenter(glass);
      final idle = await TtPixels.capture(tester);
      // Hold a finger down: the ink paints its highlight over the fill.
      final finger = await tester.startGesture(at);
      // The press registers after 100 ms and the ripple grows over the next
      // frames, so pump in steps.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final pressed = await TtPixels.capture(tester);
      expect(
        (pressed.meanLuma(rect) - idle.meanLuma(rect)).abs(),
        greaterThan(.02),
        reason: 'the ink shows over the glass fill',
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      // And an ordinary tap, as a user does it.
      await tester.tap(pill);
      expect(taps, 2);
      // The ink is in a transparent Material inside the fill.
      final material = find.descendant(
        of: find.descendant(of: glass, matching: find.byType(ColoredBox)),
        matching: find.byType(Material),
      );
      expect(material, findsOneWidget);
      expect(tester.widget<Material>(material).type, MaterialType.transparency);
      expect(
        find.descendant(of: material, matching: find.byType(InkWell)),
        findsOneWidget,
      );
    });
  });

  group('the snack (D-174)', () {
    /// A 3 dp band just inside the panel's top edge, 24 dp in from each end:
    /// away from the glyphs, the action and the rounded corners.
    Rect topBand(Rect panel) => Rect.fromLTRB(
      panel.left + 24,
      panel.top,
      panel.right - 24,
      panel.top + 3,
    );

    Future<void> show(
      WidgetTester tester, {
      String message = 'Clip deleted',
      double textScale = 1,
    }) async {
      _phone(tester);
      await tester.pumpWidget(
        ttPixelApp(Scaffold(body: ttStripes()), textScale: textScale),
      );
      showTtSnack(
        tester.element(find.byType(Scaffold).last),
        message: message,
        actionLabel: 'Undo',
        onAction: () {},
      );
      await tester.pumpAndSettle();
    }

    /// The same rect with no snack on screen: the bare stripes.
    Future<double> bare(WidgetTester tester, Rect rect) async {
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      return (await TtPixels.capture(tester)).edgeContrast(rect);
    }

    testWidgets('the snack blurs by 12 under its 94 % fill, at rest', (
      tester,
    ) async {
      await show(tester);
      final panel = tester.getRect(find.byType(TtSnack));
      final band = topBand(panel);
      final blurred = (await TtPixels.capture(tester)).edgeContrast(band);
      expectBlurFilter(tester, find.byType(TtSnack), 12);
      expectGlassStructure(tester, find.byType(TtSnack));
      final sharp = await bare(tester, band);
      expect(sharp, greaterThan(.95), reason: 'sharp without the snack');
      expectBlurred(blurred, sharp: sharp, fillOpacity: .94);
    });

    // The floating snack bar's own Material clips what it holds to the same
    // 18 dp corners, which would hide a missing clip of the snack's own; so
    // the snack is drawn on its own over the stripes, as in the catalogue.
    Widget alone({required bool snack}) => Stack(
      fit: StackFit.expand,
      children: [
        ttStripes(),
        if (snack)
          Positioned(
            left: 16,
            bottom: 12,
            width: 328,
            child: TtSnack(
              message: 'Clip deleted',
              actionLabel: 'Undo',
              onAction: () {},
            ),
          ),
      ],
    );

    testWidgets('the blur stays inside the 18 dp corners', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttPixelApp(alone(snack: true)));
      final panel = tester.getRect(find.byType(TtSnack));
      // A 4 x 4 rect whose nearest corner is 1 dp outside the top-left arc,
      // on the diagonal (the arc's centre is 18 dp in from both edges).
      const edge = 18 - 19 / math.sqrt2;
      final corner = Rect.fromLTRB(
        panel.left + edge - 4,
        panel.top + edge - 4,
        panel.left + edge,
        panel.top + edge,
      );
      // And the 8 dp gap above the panel (a 3 dp band of it, 5 dp up).
      final gap = Rect.fromLTRB(
        panel.left + 24,
        panel.top - 8,
        panel.right - 24,
        panel.top - 5,
      );
      final photo = await TtPixels.capture(tester);
      final atCorner = photo.edgeContrast(corner);
      final atGap = photo.edgeContrast(gap);
      // The same rects with no snack: the bare stripes.
      await tester.pumpWidget(ttPixelApp(alone(snack: false)));
      final bareStripes = await TtPixels.capture(tester);
      final bareCorner = bareStripes.edgeContrast(corner);
      final bareGap = bareStripes.edgeContrast(gap);
      expect(bareCorner, greaterThan(.95));
      expect(bareGap, greaterThan(.95));
      // The elevation 3 shadow darkens what is just outside the panel (its
      // alphas are .30 and .15), which scales the stripes' contrast; a blur
      // would take almost all of it.
      expectSharp(atCorner, sharp: bareCorner, fillOpacity: _snackShadow);
      expectSharp(atGap, sharp: bareGap, fillOpacity: _snackShadow);
      // The panel itself is blurred (so the clip is what holds it back).
      expectBlurred(
        photo.edgeContrast(topBand(panel)),
        sharp: bareStripes.edgeContrast(topBand(panel)),
        fillOpacity: .94,
      );
    });

    testWidgets('a long message at 2x: still one blurred panel, no overflow', (
      tester,
    ) async {
      await show(
        tester,
        message: 'Removed 3 clips from "Autumn recipes and other long names"',
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Undo'), findsOneWidget);
      final panel = tester.getRect(find.byType(TtSnack));
      expect(panel.height, greaterThan(56), reason: 'the message wrapped');
      expect(
        find.descendant(
          of: find.byType(TtSnack),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expectBlurFilter(tester, find.byType(TtSnack), 12);
      expectGlassStructure(tester, find.byType(TtSnack));
      final band = topBand(panel);
      final blurred = (await TtPixels.capture(tester)).edgeContrast(band);
      final sharp = await bare(tester, band);
      expectBlurred(blurred, sharp: sharp, fillOpacity: .94);
    });

    testWidgets('a persistent snack (screen reader) is blurred too', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await show(tester);
      // Well past its 6 s: it stays, and still blurs.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(TtSnack), findsOneWidget);
      final panel = tester.getRect(find.byType(TtSnack));
      final band = topBand(panel);
      final blurred = (await TtPixels.capture(tester)).edgeContrast(band);
      expectBlurFilter(tester, find.byType(TtSnack), 12);
      expectGlassStructure(tester, find.byType(TtSnack));
      final sharp = await bare(tester, band);
      expectBlurred(blurred, sharp: sharp, fillOpacity: .94);
    });
  });
}
