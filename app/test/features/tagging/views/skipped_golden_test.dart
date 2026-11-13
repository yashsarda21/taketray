import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/features/tagging/view_models/skipped_controller.dart';
import 'package:taketray/features/tagging/views/skipped_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import 'skipped_screen_test.dart' show DbSkipped;

/// The Skipped screen's screenshots (Task 9, D-99): the list, choosing and
/// the empty state, at text 1x and 2x (the list and choosing also in dark).
///
/// **macOS only, and not on CI** (D-61), like To tag's and the tag player's:
/// the images are made with real text on the owner's Mac (`goldens/macos/`).
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/tagging/views/skipped_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late VmHarness h;
  late Directory cacheFolder;

  setUp(() {
    h = reelHarness();
    cacheFolder = Directory.systemTemp.createTempSync('taketray_golden');
    addTearDown(() => cacheFolder.deleteSync(recursive: true));
  });

  /// A picture for a thumbnail: a diagonal gradient of the given colours.
  Future<Uint8List> picture(Color a, Color b) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(240, 320);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 320), [
          a,
          b,
        ]),
    );
    final image = await recorder.endRecording().toImage(240, 320);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pump();
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

  /// Eight skipped clips over three days: Wed Oct 28 (three), Yesterday (four)
  /// and Today (one; the phone's day is Fri Oct 30), 4 to 40 s long.
  Future<void> skipped(WidgetTester tester) async {
    final a = (await tester.runAsync(
      () => picture(const Color(0xFF3A6EA5), const Color(0xFF1B2A41)),
    ))!;
    final b = (await tester.runAsync(
      () => picture(const Color(0xFFC06C3A), const Color(0xFF3B1F14)),
    ))!;
    final shots = [
      DateTime.utc(2026, 10, 28, 12, 5),
      DateTime.utc(2026, 10, 28, 12, 9),
      DateTime.utc(2026, 10, 28, 15, 30),
      DateTime.utc(2026, 10, 29, 11, 41),
      DateTime.utc(2026, 10, 29, 11, 44),
      DateTime.utc(2026, 10, 29, 13, 5),
      DateTime.utc(2026, 10, 29, 19, 12),
      DateTime.utc(2026, 10, 30, 10, 15),
    ];
    final videos = [
      for (var i = 0; i < shots.length; i++)
        reelVideo(i + 1, shot: shots[i], durationMs: 4000 + i * 5000),
    ];
    for (final v in videos) {
      h.bridge.thumbnails[('external_primary', v.mediaStoreId)] =
          v.mediaStoreId.isEven ? a : b;
    }
    final ids = (await tester.runAsync(() => h.media.store(videos)))!;
    await tester.runAsync(
      () => h.container.read(clipsRepositoryProvider).skipClips(ids),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      const SkippedScreen(),
      overrides: [
        ...h.overrides,
        thumbnailCacheProvider.overrideWith(
          (ref) async => ThumbnailCache(h.media.bridge, cacheFolder),
        ),
        skippedControllerProvider.overrideWith(DbSkipped.new),
      ],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    await showPictures(tester);
  }

  /// Registers [body] at text 1x and 2x (and, with [dark], also dark at 1x).
  void both(
    String description,
    String name,
    Future<void> Function(WidgetTester tester, double scale, Brightness b)
    body, {
    bool dark = false,
  }) {
    for (final (scale, brightness, suffix) in [
      (1.0, Brightness.light, '1x'),
      (2.0, Brightness.light, '2x'),
      if (dark) (1.0, Brightness.dark, 'dark_1x'),
    ]) {
      testApp('$description ($suffix)', (tester) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await body(tester, scale, brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/skipped_${name}_$suffix.png'),
        );
      }, skip: !_goldens);
    }
  }

  both('the list', 'list', (tester, scale, brightness) async {
    await skipped(tester);
    await open(tester, textScale: scale, brightness: brightness);
  }, dark: true);

  both('choosing clips', 'selection', (tester, scale, brightness) async {
    await skipped(tester);
    await open(tester, textScale: scale, brightness: brightness);
    await tester.longPress(find.byType(TtClipTile).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TtClipTile).at(2));
    await tester.pumpAndSettle();
    await showPictures(tester);
  }, dark: true);

  // The missing tile with its Remove button (D-116), among picture tiles.
  both('a missing clip with Remove', 'missing', (
    tester,
    scale,
    brightness,
  ) async {
    await skipped(tester);
    await tester.runAsync(() => flagInPlaceForTest(h, {8}));
    await open(tester, textScale: scale, brightness: brightness);
    expect(find.byType(TtMissingClipTile), findsOneWidget);
  });

  both('nothing skipped', 'empty', (tester, scale, brightness) async {
    await open(tester, textScale: scale, brightness: brightness);
  });
}
