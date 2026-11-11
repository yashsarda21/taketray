import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import 'to_tag_actions_test.dart' show DbToTag;
import 'to_tag_screen_test.dart' show FailsOnce;

/// To tag's screenshots (Task 8, D-98): the scenes, choosing, the error
/// state, the Skip all dialog and the reel picker in tag mode, at text 1x and
/// 2x (the scenes also in dark), and (Phase 7) the empty state with Add videos
/// (also in dark).
///
/// **macOS only, and not on CI** (D-61), like the tag player's: the images are
/// made with real text on the owner's Mac (`goldens/macos/`). Make or update
/// them with `tool/flutter test --update-goldens
/// test/features/tagging/views/to_tag_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late Directory cacheFolder;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
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

  /// Eight clips over two days: Tuesday evening (one scene) and Wednesday
  /// (two scenes), 4 to 40 s long.
  Future<void> waiting(WidgetTester tester) async {
    final a = (await tester.runAsync(
      () => picture(const Color(0xFF3A6EA5), const Color(0xFF1B2A41)),
    ))!;
    final b = (await tester.runAsync(
      () => picture(const Color(0xFFC06C3A), const Color(0xFF3B1F14)),
    ))!;
    final shots = [
      DateTime.utc(2026, 10, 27, 18, 5),
      DateTime.utc(2026, 10, 27, 18, 9),
      DateTime.utc(2026, 10, 28, 9, 41),
      DateTime.utc(2026, 10, 28, 9, 44),
      DateTime.utc(2026, 10, 28, 9, 50),
      DateTime.utc(2026, 10, 28, 13, 5),
      DateTime.utc(2026, 10, 28, 13, 12),
      DateTime.utc(2026, 10, 28, 13, 15),
    ];
    final videos = [
      for (var i = 0; i < shots.length; i++)
        reelVideo(i + 1, shot: shots[i], durationMs: 4000 + i * 5000),
    ];
    for (final v in videos) {
      h.bridge.thumbnails[('external_primary', v.mediaStoreId)] =
          v.mediaStoreId.isEven ? a : b;
    }
    await tester.runAsync(() => h.media.store(videos));
  }

  Future<void> reel(WidgetTester tester, String name) async {
    await tester.runAsync(() => reels.create(name));
  }

  Future<void> open(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Override? toTag,
  }) async {
    await pumpScreen(
      tester,
      const ToTagScreen(),
      overrides: [
        ...h.overrides,
        thumbnailCacheProvider.overrideWith(
          (ref) async => ThumbnailCache(h.media.bridge, cacheFolder),
        ),
        toTag ?? toTagControllerProvider.overrideWith(DbToTag.new),
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
          matchesGoldenFile('goldens/macos/to_tag_${name}_$suffix.png'),
        );
      }, skip: !_goldens);
    }
  }

  both('scenes', 'scenes', (tester, scale, brightness) async {
    await waiting(tester);
    await open(tester, textScale: scale, brightness: brightness);
  }, dark: true);

  // Shooting mode off and nothing waiting: "Nothing to tag", with Turn on
  // Shooting mode and, under it, Add videos (Phase 7, D-114).
  both('nothing to tag, with Add videos', 'empty', (
    tester,
    scale,
    brightness,
  ) async {
    await open(tester, textScale: scale, brightness: brightness);
    expect(find.text('Nothing to tag'), findsOneWidget);
    expect(find.widgetWithText(TtButton, 'Add videos'), findsOneWidget);
  }, dark: true);

  both('choosing clips', 'selection', (tester, scale, brightness) async {
    await waiting(tester);
    await open(tester, textScale: scale, brightness: brightness);
    await tester.longPress(find.byType(TtClipTile).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TtClipTile).at(1));
    await tester.pumpAndSettle();
    await showPictures(tester);
  }, dark: true);

  both('the error state', 'error', (tester, scale, brightness) async {
    await open(
      tester,
      textScale: scale,
      brightness: brightness,
      toTag: toTagControllerProvider.overrideWith(
        () => FailsOnce(const <Clip>[]),
      ),
    );
  });

  both('the Skip all dialog', 'skip_all', (tester, scale, brightness) async {
    await waiting(tester);
    await open(tester, textScale: scale, brightness: brightness);
    await tester.tap(find.byIcon(Symbols.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip all'));
    await tester.pumpAndSettle();
  });

  both('the reel picker in tag mode', 'picker', (
    tester,
    scale,
    brightness,
  ) async {
    await waiting(tester);
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await tester.runAsync(() async {
      final old = await reels.create('Old shoot');
      await reels.setStatus(old.id, ReelStatus.ready);
    });
    await open(tester, textScale: scale, brightness: brightness);
    await tester.tap(find.widgetWithText(TtButton, 'Tag scene').at(1));
    await settleApp(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is TtReelPickRow && w.name == 'Goa Trip'),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is TtReelPickRow && w.name == 'London Food',
      ),
    );
    await settleApp(tester);
  });
}
