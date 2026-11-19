import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/onboarding/views/welcome_tray_art.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Art tests (Task 5, D-138): the picture of the B · Tray welcome is drawn
/// from a [WelcomeArtFrame], so each test sets a frame and reads what was
/// drawn.

const _artLabel =
    'Three takes standing in a tray, labelled London Food, Cinematic and '
    'Day 1 Vlog';

Future<void> _pumpArt(
  WidgetTester tester,
  WelcomeArtFrame frame, {
  double width = 360,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  AssetBundle? bundle,
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget art = WelcomeTrayArt(frame: frame);
  if (boundary != null) art = RepaintBoundary(key: boundary, child: art);
  Widget home = Scaffold(
    body: Align(alignment: Alignment.topLeft, child: art),
  );
  if (bundle != null) home = DefaultAssetBundle(bundle: bundle, child: home);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TakeTrayTheme.light(),
      darkTheme: TakeTrayTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: home,
    ),
  );
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(WelcomeTrayArt))).colorScheme;

Matrix4 _matrix(WidgetTester tester, Key key) =>
    tester.widget<Transform>(find.byKey(key)).transform;

double _opacity(WidgetTester tester, Key key) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first,
    )
    .opacity;

Positioned _positioned(WidgetTester tester, Key key) =>
    tester.widget<Positioned>(
      find
          .ancestor(of: find.byKey(key), matching: find.byType(Positioned))
          .first,
    );

/// A frame whose three takes differ, so a take drawn with another take's
/// values shows.
const _odd = WelcomeArtFrame(
  discScale: 0.7,
  discOpacity: 0.4,
  trayDy: 12,
  trayOpacity: 0.6,
  trayScaleX: 1.01,
  trayScaleY: 0.97,
  takes: [
    WelcomeTakeFrame(dy: -100, opacity: 0.2, tabScale: 0.5, tabOpacity: 0.3),
    WelcomeTakeFrame(dy: -40, opacity: 0.5, tabScale: 0.8, tabOpacity: 0.6),
    WelcomeTakeFrame(dy: 6, opacity: 0.9, tabScale: 0.9, tabOpacity: 0.95),
  ],
  count: 17,
  reelsOpacity: 0.35,
  glint: 0.25,
);

class _Pixels {
  _Pixels(this.data, this.width);
  final ByteData data;
  final int width;

  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }
}

Future<_Pixels> _pixels(WidgetTester tester, GlobalKey boundary) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ByteData data;
  late int width;
  await tester.runAsync(() async {
    final image = await render.toImage();
    width = image.width;
    data = (await image.toByteData())!;
  });
  return _Pixels(data, width);
}

void _expectClose(Color actual, Color expected, {int tolerance = 4}) {
  int c(double v) => (v * 255).round();
  expect(
    [c(actual.r), c(actual.g), c(actual.b)],
    [
      closeTo(c(expected.r), tolerance),
      closeTo(c(expected.g), tolerance),
      closeTo(c(expected.b), tolerance),
    ],
    reason: '$actual is not close to $expected',
  );
}

class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw FlutterError('no asset: $key');
}

void main() {
  group('WelcomeArtFrame', () {
    test('end is the final frame: everything settled and shown', () {
      const end = WelcomeArtFrame.end;
      expect(end.discScale, 1);
      expect(end.discOpacity, 1);
      expect(end.trayDy, 0);
      expect(end.trayOpacity, 1);
      expect(end.trayScaleX, 1);
      expect(end.trayScaleY, 1);
      expect(end.takes, hasLength(3));
      for (final take in end.takes) {
        expect(take.dy, 0);
        expect(take.opacity, 1);
        expect(take.tabScale, 1);
        expect(take.tabOpacity, 1);
      }
      expect(end.count, 23);
      expect(end.reelsOpacity, 1);
      expect(end.glint, isNull);
    });

    test('start is the first frame: nothing shown yet', () {
      const start = WelcomeArtFrame.start;
      expect(start.discScale, 0.5);
      expect(start.discOpacity, 0);
      expect(start.trayDy, 80);
      expect(start.trayOpacity, 0);
      expect(start.takes, hasLength(3));
      for (final take in start.takes) {
        expect(take.dy, -260);
        expect(take.opacity, 0);
        expect(take.tabScale, 0.4);
        expect(take.tabOpacity, 0);
      }
      expect(start.count, 0);
      expect(start.reelsOpacity, 0);
      expect(start.glint, isNull);
    });

    test('a default frame is the end frame', () {
      // ignore: use_named_constants, the default is what is tested
      expect(const WelcomeArtFrame(), WelcomeArtFrame.end);
    });

    test('frames with the same values are equal, any other value differs', () {
      expect(_odd, _odd);
      expect(_odd.hashCode, _odd.hashCode);
      const same = WelcomeArtFrame(
        discScale: 0.7,
        discOpacity: 0.4,
        trayDy: 12,
        trayOpacity: 0.6,
        trayScaleX: 1.01,
        trayScaleY: 0.97,
        takes: [
          WelcomeTakeFrame(
            dy: -100,
            opacity: 0.2,
            tabScale: 0.5,
            tabOpacity: 0.3,
          ),
          WelcomeTakeFrame(
            dy: -40,
            opacity: 0.5,
            tabScale: 0.8,
            tabOpacity: 0.6,
          ),
          WelcomeTakeFrame(
            dy: 6,
            opacity: 0.9,
            tabScale: 0.9,
            tabOpacity: 0.95,
          ),
        ],
        count: 17,
        reelsOpacity: 0.35,
        glint: 0.25,
      );
      expect(same, _odd);
      expect(same.hashCode, _odd.hashCode);
      final others = <WelcomeArtFrame>[
        const WelcomeArtFrame(discScale: 0.71),
        const WelcomeArtFrame(discOpacity: 0.5),
        const WelcomeArtFrame(trayDy: 1),
        const WelcomeArtFrame(trayOpacity: 0.5),
        const WelcomeArtFrame(trayScaleX: 1.02),
        const WelcomeArtFrame(trayScaleY: 0.98),
        const WelcomeArtFrame(count: 22),
        const WelcomeArtFrame(reelsOpacity: 0.5),
        const WelcomeArtFrame(glint: 0),
        const WelcomeArtFrame(
          takes: [
            WelcomeTakeFrame(dy: 1),
            WelcomeTakeFrame.end,
            WelcomeTakeFrame.end,
          ],
        ),
        const WelcomeArtFrame(
          takes: [
            WelcomeTakeFrame.end,
            WelcomeTakeFrame.end,
            WelcomeTakeFrame(tabScale: 0.9),
          ],
        ),
      ];
      for (final other in others) {
        expect(other, isNot(WelcomeArtFrame.end));
      }
    });

    testWidgets('exactly three takes are drawn', (tester) async {
      for (final takes in [
        const <WelcomeTakeFrame>[],
        const [WelcomeTakeFrame.end],
        List.filled(4, WelcomeTakeFrame.end),
      ]) {
        await _pumpArt(tester, WelcomeArtFrame(takes: takes));
        expect(
          tester.takeException(),
          isA<AssertionError>(),
          reason: '${takes.length} takes',
        );
      }
    });

    test('the glint is -1 to 1, or null', () {
      expect(() => WelcomeArtFrame(glint: -1.01), throwsAssertionError);
      expect(() => WelcomeArtFrame(glint: 1.01), throwsAssertionError);
      expect(const WelcomeArtFrame(glint: -1).glint, -1);
      expect(const WelcomeArtFrame(glint: 1).glint, 1);
    });
  });

  group('WelcomeTrayArt layout (proto.css .wel-tray)', () {
    testWidgets('372 dp tall, full width, on primaryContainer', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(WelcomeTrayArt)), const Size(360, 372));
      final scheme = _scheme(tester);
      final background = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(WelcomeTrayArt),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(background.color, scheme.primaryContainer);
    });

    testWidgets('clips what drops in from above the picture', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.start);
      expect(
        find.descendant(
          of: find.byType(WelcomeTrayArt),
          matching: find.byType(ClipRect),
        ),
        findsWidgets,
      );
      // A take 260 dp above its place starts above the picture's top edge:
      // its top is at 372 - 96 - 164 - 260 = -148.
      final centre = tester.getCenter(
        find.byKey(WelcomeTrayArt.takeTiltKey(0)),
      );
      expect(centre.dy - 82, closeTo(-148, 0.01));
    });

    testWidgets('keeps 372 dp at any width', (tester) async {
      for (final width in [320.0, 360.0, 412.0, 800.0]) {
        await _pumpArt(tester, WelcomeArtFrame.end, width: width);
        expect(tester.takeException(), isNull, reason: '$width');
        expect(
          tester.getSize(find.byType(WelcomeTrayArt)),
          Size(width, 372),
          reason: '$width',
        );
      }
    });

    testWidgets('at 360 dp the takes are 100 x 164 at left 30, 130 and 230, '
        'bottoms 96, 104 and 96', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      const lefts = [30.0, 130.0, 230.0];
      const bottoms = [96.0, 104.0, 96.0];
      for (var i = 0; i < 3; i++) {
        final p = _positioned(tester, WelcomeTrayArt.takeKey(i));
        expect(p.left, closeTo(lefts[i], 0.001), reason: 'take $i');
        expect(p.bottom, bottoms[i], reason: 'take $i');
        expect(p.width, closeTo(100, 0.001), reason: 'take $i');
        expect(p.height, closeTo(164, 0.001), reason: 'take $i');
      }
    });

    testWidgets('the takes scale with the width from a 360 dp design, '
        'centred, up to 1.2x', (tester) async {
      // 412 dp: scale 412 / 360.
      await _pumpArt(tester, WelcomeArtFrame.end, width: 412);
      var scale = 412 / 360;
      for (var i = 0; i < 3; i++) {
        final p = _positioned(tester, WelcomeTrayArt.takeKey(i));
        expect(p.width, closeTo(100 * scale, 0.01));
        expect(p.height, closeTo(164 * scale, 0.01));
        expect(
          p.left,
          closeTo((412 - 360 * scale) / 2 + [30, 130, 230][i] * scale, 0.01),
        );
      }
      // 320 dp: scale 320 / 360.
      await _pumpArt(tester, WelcomeArtFrame.end, width: 320);
      scale = 320 / 360;
      var p = _positioned(tester, WelcomeTrayArt.takeKey(0));
      expect(p.width, closeTo(100 * scale, 0.01));
      expect(p.left, closeTo(30 * scale, 0.01));
      // 800 dp: capped at 1.2x, the group centred.
      await _pumpArt(tester, WelcomeArtFrame.end, width: 800);
      p = _positioned(tester, WelcomeTrayArt.takeKey(2));
      expect(p.width, closeTo(120, 0.01));
      expect(p.height, closeTo(196.8, 0.01));
      expect(p.left, closeTo((800 - 432) / 2 + 230 * 1.2, 0.01));
      // The bottoms do not scale.
      expect(p.bottom, 96);
    });

    testWidgets('the takes lean -8, 1 and 8 degrees and the middle one is on '
        'top of its neighbours', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      const degrees = [-8.0, 1.0, 8.0];
      for (var i = 0; i < 3; i++) {
        final tilt = tester.widget<Transform>(
          find.byKey(WelcomeTrayArt.takeTiltKey(i)),
        );
        // A rotation about z: m[0] = cos, m[1] = sin.
        final angle = math.atan2(
          tilt.transform.storage[1],
          tilt.transform.storage[0],
        );
        expect(angle * 180 / math.pi, closeTo(degrees[i], 0.001));
      }
      // Paint order: take 0, take 2, then take 1, then the tray.
      final order = [
        for (final key in [
          WelcomeTrayArt.takeKey(0),
          WelcomeTrayArt.takeKey(2),
          WelcomeTrayArt.takeKey(1),
          WelcomeTrayArt.trayKey,
        ])
          _childIndex(tester, key),
      ];
      expect(order, [...order]..sort());
      expect(order.toSet(), hasLength(4));
    });

    testWidgets('the tray is 100 dp tall at 18 dp sides and 26 dp from the '
        'bottom', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final p = _positioned(tester, WelcomeTrayArt.trayKey);
      expect(p.left, 18);
      expect(p.right, 18);
      expect(p.bottom, 26);
      expect(p.height, 100);
      expect(
        tester.getRect(find.byKey(WelcomeTrayArt.trayKey)),
        const Rect.fromLTWH(18, 246, 324, 100),
      );
    });

    testWidgets('the tray is a trapezoid: 0 0, 100% 0, 93% 100%, 7% 100%', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final clip = tester.widget<ClipPath>(
        find.byKey(WelcomeTrayArt.trayClipKey),
      );
      const size = Size(324, 100);
      final path = clip.clipper!.getClip(size);
      // Inside: the middle, and both top corners.
      expect(path.contains(const Offset(162, 50)), isTrue);
      expect(path.contains(const Offset(1, 1)), isTrue);
      expect(path.contains(const Offset(323, 1)), isTrue);
      // The bottom corners are cut: 7 % of 324 is 22.7 dp.
      expect(path.contains(const Offset(5, 99)), isFalse);
      expect(path.contains(const Offset(319, 99)), isFalse);
      expect(path.contains(const Offset(24, 99)), isTrue);
      expect(path.contains(const Offset(300, 99)), isTrue);
      // The slanted edge at half height is 3.5 % in: 11.3 dp.
      expect(path.contains(const Offset(9, 50)), isFalse);
      expect(path.contains(const Offset(13, 50)), isTrue);
      expect(clip.clipBehavior, Clip.antiAlias);
    });

    testWidgets('the tray has the 12 dp inner top shade in '
        'on-tertiary-container at 12 %', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final scheme = _scheme(tester);
      final shade = find.byKey(WelcomeTrayArt.trayShadeKey);
      expect(tester.getSize(shade).height, 12);
      expect(tester.getSize(shade).width, 324);
      final color = tester.widget<ColoredBox>(shade).color;
      expect(color.a, closeTo(0.12, 0.001));
      expect(
        color.withValues(alpha: 1),
        scheme.onTertiaryContainer.withValues(alpha: 1),
      );
    });

    testWidgets('the tray is tertiaryContainer in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await _pumpArt(tester, WelcomeArtFrame.end, brightness: brightness);
        final scheme = _scheme(tester);
        final fill = find.descendant(
          of: find.byKey(WelcomeTrayArt.trayClipKey),
          matching: find.byType(ColoredBox),
        );
        expect(
          tester.widgetList<ColoredBox>(fill).first.color,
          scheme.tertiaryContainer,
          reason: brightness.name,
        );
      }
    });
  });

  group('WelcomeTrayArt disc', () {
    testWidgets('300 dp at right -96, top -120, light: tertiaryContainer at '
        '0.5', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final scheme = _scheme(tester);
      final p = _positioned(tester, WelcomeTrayArt.discKey);
      expect(p.right, -96);
      expect(p.top, -120);
      expect(p.width, 300);
      expect(p.height, 300);
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(WelcomeTrayArt.discKey),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      expect(deco.color!.withValues(alpha: 1), scheme.tertiaryContainer);
      expect(deco.color!.a, closeTo(0.5, 0.001));
    });

    testWidgets('dark: primary at 0.2', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end, brightness: Brightness.dark);
      final scheme = _scheme(tester);
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(WelcomeTrayArt.discKey),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color!.withValues(alpha: 1), scheme.primary);
      expect(deco.color!.a, closeTo(0.2, 0.001));
    });
  });

  group('WelcomeTrayArt is drawn from its frame', () {
    testWidgets('the end frame: nothing moved, scaled or faded', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      expect(_matrix(tester, WelcomeTrayArt.discKey).storage[0], 1);
      expect(_opacity(tester, WelcomeTrayArt.discKey), 1);
      expect(_matrix(tester, WelcomeTrayArt.trayKey).getTranslation().y, 0);
      expect(_matrix(tester, WelcomeTrayArt.trayScaleKey).storage[0], 1);
      expect(_matrix(tester, WelcomeTrayArt.trayScaleKey).storage[5], 1);
      expect(_opacity(tester, WelcomeTrayArt.trayKey), 1);
      for (var i = 0; i < 3; i++) {
        expect(
          _matrix(tester, WelcomeTrayArt.takeKey(i)).getTranslation().y,
          0,
        );
        expect(_opacity(tester, WelcomeTrayArt.takeKey(i)), 1);
        expect(_matrix(tester, WelcomeTrayArt.tabKey(i)).storage[0], 1);
        expect(_opacity(tester, WelcomeTrayArt.tabKey(i)), 1);
      }
      expect(_opacity(tester, WelcomeTrayArt.reelsKey), 1);
      expect(find.byKey(WelcomeTrayArt.glintKey), findsNothing);
    });

    testWidgets('every value of the frame reaches its element', (tester) async {
      await _pumpArt(tester, _odd);
      // Disc: scale about its centre, opacity as a share of its own.
      final disc = tester.widget<Transform>(find.byKey(WelcomeTrayArt.discKey));
      expect(disc.transform.storage[0], 0.7);
      expect(disc.transform.storage[5], 0.7);
      expect(disc.alignment, Alignment.center);
      expect(_opacity(tester, WelcomeTrayArt.discKey), 0.4);
      // Tray: translate, then scale about its centre, and opacity.
      expect(_matrix(tester, WelcomeTrayArt.trayKey).getTranslation().y, 12);
      final scale = tester.widget<Transform>(
        find.byKey(WelcomeTrayArt.trayScaleKey),
      );
      expect(scale.transform.storage[0], 1.01);
      expect(scale.transform.storage[5], 0.97);
      expect(scale.alignment, Alignment.center);
      expect(_opacity(tester, WelcomeTrayArt.trayKey), 0.6);
      // Takes and their tabs, one by one.
      const dys = [-100.0, -40.0, 6.0];
      const opacities = [0.2, 0.5, 0.9];
      const tabScales = [0.5, 0.8, 0.9];
      const tabOpacities = [0.3, 0.6, 0.95];
      for (var i = 0; i < 3; i++) {
        expect(
          _matrix(tester, WelcomeTrayArt.takeKey(i)).getTranslation().y,
          dys[i],
          reason: 'take $i dy',
        );
        expect(
          _opacity(tester, WelcomeTrayArt.takeKey(i)),
          opacities[i],
          reason: 'take $i opacity',
        );
        final tab = tester.widget<Transform>(
          find.byKey(WelcomeTrayArt.tabKey(i)),
        );
        expect(tab.transform.storage[0], tabScales[i], reason: 'tab $i');
        expect(tab.transform.storage[5], tabScales[i], reason: 'tab $i');
        expect(tab.alignment, Alignment.bottomLeft, reason: 'tab $i origin');
        expect(
          _opacity(tester, WelcomeTrayArt.tabKey(i)),
          tabOpacities[i],
          reason: 'tab $i opacity',
        );
      }
      // The count and the reels.
      expect(
        tester.widget<Text>(find.byKey(WelcomeTrayArt.countKey)).data,
        '17',
      );
      expect(_opacity(tester, WelcomeTrayArt.reelsKey), 0.35);
      expect(find.byKey(WelcomeTrayArt.glintKey), findsOneWidget);
    });

    testWidgets('the take moves in the screen frame: translate outside the '
        'tilt', (tester) async {
      await _pumpArt(
        tester,
        const WelcomeArtFrame(
          takes: [
            WelcomeTakeFrame(dy: 50),
            WelcomeTakeFrame.end,
            WelcomeTakeFrame.end,
          ],
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(WelcomeTrayArt.takeKey(0)),
          matching: find.byKey(WelcomeTrayArt.takeTiltKey(0)),
        ),
        findsOneWidget,
      );
      // A tilted card dropped 50 dp is 50 dp lower, not moved sideways.
      await _pumpArt(tester, WelcomeArtFrame.end);
      final before = tester.getCenter(
        find.byKey(WelcomeTrayArt.takeTiltKey(0)),
      );
      await _pumpArt(
        tester,
        const WelcomeArtFrame(
          takes: [
            WelcomeTakeFrame(dy: 50),
            WelcomeTakeFrame.end,
            WelcomeTakeFrame.end,
          ],
        ),
      );
      final after = tester.getCenter(find.byKey(WelcomeTrayArt.takeTiltKey(0)));
      expect(after.dx, closeTo(before.dx, 0.001));
      expect(after.dy - before.dy, closeTo(50, 0.001));
    });

    testWidgets('a new frame redraws the same widgets', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.start);
      expect(_opacity(tester, WelcomeTrayArt.trayKey), 0);
      await _pumpArt(tester, WelcomeArtFrame.end);
      expect(_opacity(tester, WelcomeTrayArt.trayKey), 1);
      expect(
        tester.widget<Text>(find.byKey(WelcomeTrayArt.countKey)).data,
        '23',
      );
    });

    testWidgets('the start frame draws without an error', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.start);
      expect(tester.takeException(), isNull);
    });

    testWidgets('extreme values do not throw: a take far away, a tab at 0', (
      tester,
    ) async {
      await _pumpArt(
        tester,
        const WelcomeArtFrame(
          discScale: 0,
          discOpacity: 0,
          trayScaleX: 0.5,
          trayScaleY: 2,
          takes: [
            WelcomeTakeFrame(dy: -2000, opacity: 0, tabScale: 0, tabOpacity: 0),
            WelcomeTakeFrame(dy: 2000),
            WelcomeTakeFrame.end,
          ],
          count: 0,
          glint: 1,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WelcomeTrayArt text', () {
    testWidgets('the tabs are London Food, Cinematic and Day 1 Vlog in '
        'label-medium on the surface', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final scheme = _scheme(tester);
      for (final (i, label) in [
        'London Food',
        'Cinematic',
        'Day 1 Vlog',
      ].indexed) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(WelcomeTrayArt.takeKey(i)),
            matching: find.text(label),
          ),
        );
        final labelMedium = TtTextStyles.materialTextTheme.labelMedium!;
        expect(text.style!.fontSize, labelMedium.fontSize);
        expect(text.style!.color, scheme.onSurface);
        expect(text.softWrap, isFalse);
        expect(text.maxLines, 1);
      }
    });

    testWidgets('each tab is 24 dp tall, 8 dp in from the take and 23 dp '
        "above its top edge (the prototype's top: -23px), with 10 dp "
        'sides and a 8 dp top corner', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final scheme = _scheme(tester);
      for (var i = 0; i < 3; i++) {
        final p = _positioned(tester, WelcomeTrayArt.tabKey(i));
        expect(p.left, 8, reason: 'tab $i');
        expect(p.top, -23, reason: 'tab $i');
        expect(p.height, 24, reason: 'tab $i');
        final deco =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(WelcomeTrayArt.tabKey(i)),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(deco.color, scheme.surface, reason: 'tab $i');
        expect(
          deco.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(8)),
          reason: 'tab $i',
        );
        // 10 dp each side of the label.
        final label = tester.getSize(
          find.descendant(
            of: find.byKey(WelcomeTrayArt.tabKey(i)),
            matching: find.byType(Text),
          ),
        );
        expect(
          tester.getSize(find.byKey(WelcomeTrayArt.tabKey(i))).width,
          closeTo(label.width + 20, 0.01),
          reason: 'tab $i',
        );
      }
    });

    testWidgets('the label is 23 takes · 3 reels in on-tertiary-container', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final scheme = _scheme(tester);
      final number = tester.widget<Text>(find.byKey(WelcomeTrayArt.countKey));
      final word = tester.widget<Text>(find.byKey(WelcomeTrayArt.countWordKey));
      final reels = tester.widget<Text>(find.byKey(WelcomeTrayArt.reelsKey));
      expect(number.data, '23');
      expect(word.data, ' takes');
      expect(reels.data, ' · 3 reels');
      for (final text in [number, word, reels]) {
        expect(text.style!.color, scheme.onTertiaryContainer);
        expect(text.style!.fontSize, 14);
        expect(
          text.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
    });

    testWidgets('the label sits at the tray bottom, centred, 18 dp up', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final tray = tester.getRect(find.byKey(WelcomeTrayArt.trayKey));
      final all = tester.getRect(find.byKey(WelcomeTrayArt.labelKey));
      expect(all.center.dx, closeTo(tray.center.dx, 0.5));
      // The label's line box ends 18 dp above the tray's bottom.
      expect(all.bottom, closeTo(tray.bottom - 18, 0.5));
    });

    testWidgets('the count is plural: 1 take, 0 takes, 2 takes', (
      tester,
    ) async {
      for (final (count, number, word) in [
        (0, '0', ' takes'),
        (1, '1', ' take'),
        (2, '2', ' takes'),
        (23, '23', ' takes'),
      ]) {
        await _pumpArt(tester, WelcomeArtFrame(count: count));
        expect(
          tester.widget<Text>(find.byKey(WelcomeTrayArt.countKey)).data,
          number,
          reason: '$count',
        );
        expect(
          tester.widget<Text>(find.byKey(WelcomeTrayArt.countWordKey)).data,
          word,
          reason: '$count',
        );
      }
    });

    testWidgets('the number is right-aligned in 2 ch: the word does not '
        'move while the count ticks', (tester) async {
      final wordLeft = <int, double>{};
      final numberRight = <int, double>{};
      for (final count in [0, 1, 2, 5, 9, 10, 11, 18, 23]) {
        await _pumpArt(tester, WelcomeArtFrame(count: count));
        wordLeft[count] = tester
            .getTopLeft(find.byKey(WelcomeTrayArt.countWordKey))
            .dx;
        numberRight[count] = tester
            .getTopRight(find.byKey(WelcomeTrayArt.countKey))
            .dx;
      }
      // The number's right edge is the word's left edge, and neither moves
      // between 0 and 23, whatever the digits.
      for (final count in wordLeft.keys) {
        expect(wordLeft[count], closeTo(wordLeft[23]!, 0.01), reason: '$count');
        expect(
          numberRight[count],
          closeTo(wordLeft[23]!, 0.01),
          reason: '$count',
        );
      }
    });

    testWidgets('the count and the reels fit at 2x text without an error '
        'and the picture does not grow', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(WelcomeTrayArt)), const Size(360, 372));
    });

    testWidgets('the picture is a drawing: its text keeps its size at 2x', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final one = tester.getSize(find.byKey(WelcomeTrayArt.countKey));
      final tab = tester.getSize(find.byKey(WelcomeTrayArt.tabKey(0)));
      await _pumpArt(tester, WelcomeArtFrame.end, textScale: 2);
      expect(tester.getSize(find.byKey(WelcomeTrayArt.countKey)), one);
      expect(tester.getSize(find.byKey(WelcomeTrayArt.tabKey(0))), tab);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(WelcomeTrayArt.countKey),
      );
      expect(paragraph.textScaler, TextScaler.noScaling);
    });
  });

  group('WelcomeTrayArt glint', () {
    Future<_Pixels> shot(WidgetTester tester, double? glint) async {
      final boundary = GlobalKey();
      await _pumpArt(tester, WelcomeArtFrame(glint: glint), boundary: boundary);
      return await _pixels(tester, boundary);
    }

    testWidgets('is a white band at 60 % that lights the tray where it is, '
        'and nowhere else', (tester) async {
      final none = await shot(tester, null);
      final mid = await shot(tester, 0);
      final scheme = _scheme(tester);
      // Tray body: 54 dp below its top, in the middle of the band at 0.
      final plain = none.at(180, 300);
      _expectClose(plain, scheme.tertiaryContainer);
      _expectClose(
        mid.at(180, 300),
        Color.lerp(scheme.tertiaryContainer, Colors.white, 0.6)!,
      );
      // Far to the left of the band (120 dp from its centre): unchanged.
      _expectClose(mid.at(60, 300), plain);
    });

    testWidgets('moves by its share of the tray width: 0.25 is 81 dp right', (
      tester,
    ) async {
      final none = await shot(tester, null);
      final moved = await shot(tester, 0.25);
      final scheme = _scheme(tester);
      _expectClose(
        moved.at(261, 300),
        Color.lerp(scheme.tertiaryContainer, Colors.white, 0.6)!,
      );
      _expectClose(moved.at(180, 300), none.at(180, 300));
    });

    testWidgets('at -1 and 1 the band is out of the tray', (tester) async {
      final none = await shot(tester, null);
      for (final glint in [-1.0, 1.0]) {
        final out = await shot(tester, glint);
        for (final (x, y) in [(40, 300), (180, 300), (320, 300), (180, 270)]) {
          _expectClose(out.at(x, y), none.at(x, y));
        }
      }
    });

    testWidgets('is clipped to the tray: not over the picture around it', (
      tester,
    ) async {
      final none = await shot(tester, null);
      final mid = await shot(tester, 0);
      // 20 dp above the tray, and the cut-off bottom corner.
      _expectClose(mid.at(180, 226), none.at(180, 226));
      _expectClose(mid.at(20, 340), none.at(20, 340));
      _expectClose(mid.at(180, 350), none.at(180, 350));
    });

    testWidgets('does not take a tap', (tester) async {
      await _pumpArt(tester, const WelcomeArtFrame(glint: 0));
      final glint = find.ancestor(
        of: find.byKey(WelcomeTrayArt.glintKey),
        matching: find.byType(IgnorePointer),
      );
      expect(glint, findsWidgets);
    });
  });

  group('WelcomeTrayArt takes', () {
    testWidgets('draw the three clips from the app assets, cover-fitted', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      const names = [
        'assets/welcome/take_london_food.png',
        'assets/welcome/take_cinematic.png',
        'assets/welcome/take_day1_vlog.png',
      ];
      for (var i = 0; i < 3; i++) {
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(WelcomeTrayArt.takeKey(i)),
            matching: find.byType(Image),
          ),
        );
        expect((image.image as AssetImage).assetName, names[i]);
        expect(image.fit, BoxFit.cover);
      }
    });

    testWidgets('clip their picture to the 12 dp corners of the card', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      for (var i = 0; i < 3; i++) {
        final clip = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byKey(WelcomeTrayArt.takeCardKey(i)),
            matching: find.byType(ClipRRect),
          ),
        );
        expect(clip.borderRadius, BorderRadius.circular(12), reason: 'take $i');
      }
    });

    testWidgets('are cards: surface fill, 12 dp corners, elevation 3', (
      tester,
    ) async {
      await _pumpArt(tester, WelcomeArtFrame.end);
      final scheme = _scheme(tester);
      final card =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(WelcomeTrayArt.takeKey(1)),
                      matching: find.byKey(WelcomeTrayArt.takeCardKey(1)),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(card.color, scheme.surface);
      expect(card.borderRadius, BorderRadius.circular(12));
      expect(card.boxShadow, TtElevationTokens.level3);
    });

    testWidgets('a clip that fails to load leaves the plain card, no '
        'exception', (tester) async {
      await _pumpArt(tester, WelcomeArtFrame.end, bundle: _FailingBundle());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(WelcomeTrayArt.takeCardKey(0)), findsOneWidget);
    });
  });

  group('WelcomeTrayArt semantics', () {
    testWidgets('is one image node with the label and no child nodes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpArt(tester, WelcomeArtFrame.end);
      final node = tester.getSemantics(find.byType(WelcomeTrayArt));
      expect(node.label, _artLabel);
      expect(node.flagsCollection.isImage, isTrue);
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      handle.dispose();
    });

    testWidgets('the tabs, the count and the reels are not read out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpArt(tester, WelcomeArtFrame.end);
      for (final text in [
        'London Food',
        'Cinematic',
        'Day 1 Vlog',
        '23',
        ' takes',
      ]) {
        expect(find.bySemanticsLabel(text), findsNothing, reason: text);
      }
      handle.dispose();
    });

    testWidgets('has the same label at the first frame', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpArt(tester, WelcomeArtFrame.start);
      expect(find.bySemanticsLabel(_artLabel), findsOneWidget);
      handle.dispose();
    });
  });
}

/// The index of the child of the art's stack that holds [key].
int _childIndex(WidgetTester tester, Key key) {
  final stack = tester.element(
    find
        .descendant(
          of: find.byType(WelcomeTrayArt),
          matching: find.byType(Stack),
        )
        .first,
  );
  final children = <Element>[];
  stack.visitChildElements(children.add);
  final target = tester.element(find.byKey(key));
  for (var i = 0; i < children.length; i++) {
    var found = identical(children[i], target);
    target.visitAncestorElements((ancestor) {
      if (identical(ancestor, children[i])) found = true;
      return !found;
    });
    if (found) return i;
  }
  return -1;
}
