import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/views/edit_select_screen.dart';

import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import 'editors_support.dart';

/// The clip picking screen and the editor sheet (prototype screens 18 and 19,
/// D-126): nothing picked, clips picked, and the sheet with and without an
/// editor missing, at text 1x and 2x and in dark.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens: the
/// images are made with real text on the owner's Mac (`goldens/macos/`). Make
/// or update them with `tool/flutter test --update-goldens
/// test/features/editors/editors_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late VmHarness h;

  setUp(() => h = reelHarness());

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// A picture for a thumbnail: a diagonal gradient of the given colours.
  Future<Uint8List> picture(Color from, Color to) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(240, 320);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 320), [
          from,
          to,
        ]),
    );
    final image = await recorder.endRecording().toImage(240, 320);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Lets the thumbnails load for real: waits until every picture on screen
  /// has a decoded image.
  Future<void> showPictures(WidgetTester tester) async {
    bool pending() => find
        .byType(Image)
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderImage>()
        .any((r) => r.image == null);
    for (var i = 0; i < 40 && (i < 2 || pending()); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await settleApp(tester);
  }

  /// "Goa food trip" with seven clips over two days (one horizontal, one
  /// missing that is not shown); returns the reel and the live clip ids.
  Future<(Reel, List<int>)> goaReel(WidgetTester tester) async {
    final colours = [
      for (final (x, y) in [
        (0xFF3A6EA5, 0xFF1B2A41),
        (0xFFC06C3A, 0xFF3B1F14),
        (0xFF4E8B5F, 0xFF16301F),
        (0xFF8E5BA8, 0xFF2A1836),
      ])
        (await tester.runAsync(() => picture(Color(x), Color(y))))!,
    ];
    final goa = (await tester.runAsync(
      () => h.container.read(reelsRepositoryProvider).create('Goa food trip'),
    ))!;
    final shots = [
      DateTime.utc(2026, 10, 25, 9, 12),
      DateTime.utc(2026, 10, 25, 9, 41),
      DateTime.utc(2026, 10, 25, 13, 5),
      DateTime.utc(2026, 10, 26, 8, 30),
      DateTime.utc(2026, 10, 26, 12, 15),
      DateTime.utc(2026, 10, 26, 18, 2),
      DateTime.utc(2026, 10, 26, 19, 40),
    ];
    final videos = [
      for (var i = 0; i < shots.length; i++)
        sizedVideo(
          i + 1,
          shot: shots[i],
          seconds: [14, 32, 9, 21, 6, 48, 12][i],
          size: [180, 410, 95, 260, 70, 640, 150][i] * 1000000,
        ),
    ];
    for (final v in videos) {
      h.bridge.thumbnails[(phone, v.mediaStoreId)] =
          colours[v.mediaStoreId % colours.length];
    }
    final ids = (await tester.runAsync(() => putInReel(h, goa.id, videos)))!;
    return (goa, ids);
  }

  Future<void> openScreen(
    WidgetTester tester,
    Reel reel,
    List<int> ticked, {
    required double scale,
    required Brightness brightness,
  }) async {
    await pumpScreen(
      tester,
      EditSelectScreen(reelId: reel.id, clipIds: ticked),
      overrides: h.appOverrides,
      textScale: scale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    await showPictures(tester);
  }

  for (final (scale, brightness, suffix) in [
    (1.0, Brightness.light, '1x'),
    (2.0, Brightness.light, '2x'),
    (1.0, Brightness.dark, 'dark_1x'),
  ]) {
    testApp('the picking screen, some clips picked ($suffix)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await openScreen(
        tester,
        goa,
        [ids[0], ids[1], ids[3], ids[5]],
        scale: scale,
        brightness: brightness,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/macos/edit_select_picked_$suffix.png'),
      );
    }, skip: !_goldens);

    testApp('the editor sheet, CapCut missing ($suffix)', (tester) async {
      h.editors
        ..allow({'apps'})
        ..installed = {
          EditorApp.capcut.packageName: false,
          EditorApp.edits.packageName: true,
          EditorApp.vn.packageName: true,
        };
      final (goa, ids) = await goaReel(tester);
      await openScreen(
        tester,
        goa,
        [ids[0], ids[1], ids[3], ids[5]],
        scale: scale,
        brightness: brightness,
      );
      await tester.tap(find.text('Continue'));
      await settleApp(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/macos/editor_sheet_missing_$suffix.png'),
      );
    }, skip: !_goldens);
  }

  testApp('the picking screen, nothing picked (1x)', (tester) async {
    final (goa, _) = await goaReel(tester);
    await openScreen(
      tester,
      goa,
      const [],
      scale: 1,
      brightness: Brightness.light,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/edit_select_none_1x.png'),
    );
  }, skip: !_goldens);

  testApp('the editor sheet, every editor installed (1x)', (tester) async {
    h.editors
      ..allow({'apps'})
      ..installed = {
        EditorApp.capcut.packageName: true,
        EditorApp.edits.packageName: true,
        EditorApp.vn.packageName: true,
      };
    final (goa, ids) = await goaReel(tester);
    await openScreen(tester, goa, ids, scale: 1, brightness: Brightness.light);
    await tester.tap(find.text('Continue'));
    await settleApp(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/editor_sheet_all_1x.png'),
    );
  }, skip: !_goldens);
}
