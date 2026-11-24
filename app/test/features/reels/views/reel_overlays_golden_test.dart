import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../../editors/editors_support.dart';
import '../edit_session_support.dart';

/// A reel's page under a dialog, to see the scrim's blur over real content
/// (Phase 12, D-172): the "Delete reel" dialog, light and dark, at text 1x.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens:
/// make or update them with `tool/flutter test --update-goldens
/// test/features/reels/views/reel_overlays_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late VmHarness h;

  setUp(() => h = reelHarness());

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

  /// Waits until every picture on screen has a decoded image.
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

  /// "Goa food trip" with six clips over two days, each with a gradient
  /// thumbnail.
  Future<Reel> goaReel(WidgetTester tester) async {
    final colours = [
      for (final (x, y) in [
        (0xFF3A6EA5, 0xFF1B2A41),
        (0xFFC06C3A, 0xFF3B1F14),
        (0xFF4E8B5F, 0xFF16301F),
        (0xFF8E5BA8, 0xFF2A1836),
      ])
        (await tester.runAsync(() => picture(Color(x), Color(y))))!,
    ];
    final goa = await real(
      tester,
      () => h.container.read(reelsRepositoryProvider).create('Goa food trip'),
    );
    final shots = [
      DateTime.utc(2026, 10, 25, 9, 12),
      DateTime.utc(2026, 10, 25, 9, 41),
      DateTime.utc(2026, 10, 25, 13, 5),
      DateTime.utc(2026, 10, 26, 8, 30),
      DateTime.utc(2026, 10, 26, 12, 15),
      DateTime.utc(2026, 10, 26, 18, 2),
    ];
    final videos = [
      for (var i = 0; i < shots.length; i++)
        sizedVideo(
          i + 1,
          shot: shots[i],
          seconds: [14, 32, 9, 21, 6, 48][i],
          size: [180, 410, 95, 260, 70, 640][i] * 1000000,
        ),
    ];
    for (final v in videos) {
      h.bridge.thumbnails[(phone, v.mediaStoreId)] =
          colours[v.mediaStoreId % colours.length];
    }
    await real(tester, () => putInReel(h, goa.id, videos));
    return goa;
  }

  for (final (brightness, name) in [
    (Brightness.light, 'reel_delete_dialog_light'),
    (Brightness.dark, 'reel_delete_dialog_dark'),
  ]) {
    testApp("the Delete reel dialog over a reel's page ($name)", (
      tester,
    ) async {
      final goa = await goaReel(tester);
      await pumpScreen(
        tester,
        ReelDetailScreen(reelId: goa.id),
        overrides: h.appOverrides,
        brightness: brightness,
        settle: false,
      );
      await settleApp(tester);
      await showPictures(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'More options',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete reel'));
      await settleApp(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/macos/$name.png'),
      );
    }, skip: !_goldens);
  }
}
