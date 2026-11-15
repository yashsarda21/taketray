import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';

/// The launcher icon's colours (`design/handoff/icons/tray/`, graphite).
const _background = Color(0xFF516072);
const _backClip = Color(0xFFB8C8DD);
const _white = Color(0xFFFFFFFF);
const _trayBody = Color(0xFFFFB952);
const _trayRim = Color(0xFFE89B00);

/// The mark drawn at 108 dp (the icon's own viewport, so one pixel is one
/// viewport unit), as pixels.
Future<_Pixels> _paint(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(108, 108);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ttTestApp(
      brightness: brightness,
      RepaintBoundary(key: key, child: const TtBrandMark(size: 108)),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ByteData data;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    data = (await image.toByteData())!;
  });
  return _Pixels(data);
}

class _Pixels {
  new(this.data);
  final ByteData data;

  /// The colour at viewport point ([x], [y]).
  Color at(int x, int y) {
    final i = (y * 108 + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }
}

void main() {
  group('TtBrandMark size', () {
    for (final size in [28.0, 144.0, 1.0, 0.0]) {
      testWidgets('is $size dp square', (tester) async {
        await tester.pumpWidget(
          ttTestApp(Center(child: TtBrandMark(size: size))),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(TtBrandMark)), Size.square(size));
      });
    }

    testWidgets('keeps its size at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtBrandMark(size: 28)), textScale: 2),
      );
      expect(tester.getSize(find.byType(TtBrandMark)), const Size.square(28));
    });

    testWidgets('a negative size is refused', (tester) async {
      expect(() => TtBrandMark(size: -1), throwsAssertionError);
    });
  });

  group('TtBrandMark drawing', () {
    testWidgets('is the launcher icon: graphite circle, clips, tray', (
      tester,
    ) async {
      final p = await _paint(tester);
      // Background: inside the circle, clear of every shape.
      expect(p.at(54, 12), _background);
      expect(p.at(20, 54), _background);
      // The back clip (rotated -12 degrees about 52,47) shows above-left.
      expect(p.at(44, 40), _backClip);
      // The front clip is white, the play mark on it graphite.
      expect(p.at(70, 60), _white);
      expect(p.at(62, 52), _background);
      // The tray body and its rim line.
      expect(p.at(54, 75), _trayBody);
      expect(p.at(54, 68), _trayRim);
    });

    testWidgets('the clips lean the right ways: the back one left (-12), the '
        'front one right (7), and the back one reaches down behind the tray', (
      tester,
    ) async {
      final p = await _paint(tester);
      // A point inside each clip as rotated, and outside the mirrored one.
      expect(p.at(39, 33), _backClip, reason: 'back clip leans -12');
      expect(p.at(74, 35), _white, reason: 'front clip leans 7');
      expect(p.at(44, 62), _backClip, reason: 'back clip is 38 dp tall');
    });

    testWidgets('the tray is a trapezoid: its top edge is 60 wide, 24 to 84', (
      tester,
    ) async {
      final p = await _paint(tester);
      expect(p.at(82, 64), _trayBody);
      expect(p.at(26, 64), _trayBody);
      // Narrower at the bottom: 29.4 to 78.6, and clear outside.
      expect(p.at(28, 80), _background);
      expect(p.at(80, 80), _background);
      expect(p.at(40, 80), _trayBody);
    });

    testWidgets('is clipped to a circle: the corners are clear', (
      tester,
    ) async {
      final p = await _paint(tester);
      for (final (x, y) in [(1, 1), (106, 1), (1, 106), (106, 106)]) {
        expect(p.at(x, y).a, 0, reason: '($x, $y)');
      }
      // Just inside the circle's edge at the top.
      expect(p.at(54, 3).a, 1);
    });

    testWidgets('has the same colours in the dark theme', (tester) async {
      final light = await _paint(tester);
      final dark = await _paint(tester, brightness: Brightness.dark);
      for (final (x, y) in [(54, 12), (44, 40), (70, 60), (54, 75), (54, 68)]) {
        expect(dark.at(x, y), light.at(x, y), reason: '($x, $y)');
      }
    });
  });

  group('TtBrandMark semantics', () {
    testWidgets('is decoration: no node, no label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtBrandMark(size: 28))),
      );
      final node = tester.getSemantics(find.byType(TtBrandMark));
      expect(node.label, isEmpty);
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });

    testWidgets('is not tappable and has no text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtBrandMark(size: 28))),
      );
      expect(
        find.descendant(
          of: find.byType(TtBrandMark),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TtBrandMark),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });
}
