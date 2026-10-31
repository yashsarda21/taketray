import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/fake_hold.dart';
import '../../../support/fake_video_player.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The tag player's screenshots (Task 7, D-97), dark, at text 1x and 2x.
///
/// **macOS only, and not on CI** (D-61): the images are made with real text on
/// the owner's Mac (`goldens/macos/`); CI has no set for the app's screens, so
/// there the tests are registered but skipped, as Alchemist skips a set that
/// is off. Make or update them with `tool/flutter test --update-goldens
/// test/features/tagging/views/tag_player_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late VmHarness h;
  late FakeHolds holds;
  late ReelsRepository reels;
  late FakeVideoPlayerPlatform platform;
  late Directory cacheFolder;

  setUp(() {
    h = reelHarness();
    holds = FakeHolds();
    reels = h.container.read(reelsRepositoryProvider);
    platform = FakeVideoPlayerPlatform.install();
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
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [a, b],
        ),
    );
    final image = await recorder.endRecording().toImage(240, 320);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> settleApp(WidgetTester tester, {bool animate = true}) async {
    await tester.runAsync(settle);
    await tester.pump();
    if (animate) await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pump();
  }

  /// Lets the thumbnails load for real and draws them: waits until every
  /// picture on screen has a decoded image.
  Future<void> showPictures(WidgetTester tester, {bool animate = true}) async {
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
    await settleApp(tester, animate: animate);
  }

  Future<List<int>> waiting(
    WidgetTester tester,
    int count, {
    bool horizontal = false,
    int durationMs = 4000,
  }) async {
    final a = await tester.runAsync(
      () => picture(const Color(0xFF3A6EA5), const Color(0xFF1B2A41)),
    );
    final b = await tester.runAsync(
      () => picture(const Color(0xFFC06C3A), const Color(0xFF3B1F14)),
    );
    final videos = [
      for (var i = 1; i <= count; i++)
        reelVideo(i, horizontal: horizontal, durationMs: durationMs),
    ];
    for (final v in videos) {
      h.bridge.thumbnails[('external_primary', v.mediaStoreId)] =
          v.mediaStoreId.isEven ? a : b;
    }
    return (await tester.runAsync(() => h.media.store(videos)))!;
  }

  Future<void> reel(
    WidgetTester tester,
    String name, {
    ReelStatus status = ReelStatus.collecting,
    int clipsInIt = 0,
  }) async {
    await tester.runAsync(() async {
      final made = await reels.create(name);
      if (status != ReelStatus.collecting) {
        await reels.setStatus(made.id, status);
      }
    });
  }

  Future<void> open(
    WidgetTester tester, {
    int? from,
    double textScale = 1,
    bool animate = true,
  }) async {
    await pumpScreen(
      tester,
      TagPlayerScreen(startClipId: from),
      overrides: [
        ...h.overrides,
        thumbnailCacheProvider.overrideWith(
          (ref) async => ThumbnailCache(h.media.bridge, cacheFolder),
        ),
        holdTimerProvider.overrideWithValue(holds.call),
      ],
      textScale: textScale,
      brightness: Brightness.dark,
      settle: false,
    );
    await settleApp(tester, animate: animate);
    await showPictures(tester, animate: animate);
  }

  Finder chip(String name) => find.byWidgetPredicate(
    (w) => w is TtReelChip && w.name == name,
    description: 'the "$name" chip',
  );

  Future<void> tagInto(WidgetTester tester, String name) async {
    await tester.tap(chip(name));
    await tester.pump();
    holds.fireAll();
    await settleApp(tester);
  }

  Future<void> expectGolden(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(TagPlayerScreen),
      matchesGoldenFile('goldens/macos/$name.png'),
    );
  }

  /// Registers [body] twice: at text 1x and at 2x.
  void both(
    String description,
    String name,
    Future<void> Function(WidgetTester tester, double scale) body,
  ) {
    for (final scale in [1.0, 2.0]) {
      final suffix = scale == 1 ? '1x' : '2x';
      testApp('$description ($suffix)', (tester) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await body(tester, scale);
        await expectGolden(tester, '${name}_$suffix');
      }, skip: !_goldens);
    }
  }

  both('the first clip', 'tag_player_first', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await reel(tester, 'Sunsets');
    await reel(tester, 'Old shoot', status: ReelStatus.ready);
    await waiting(tester, 8);
    await open(tester, textScale: scale);
  });

  both('mid-scene, after three tags', 'tag_player_mid', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await reel(tester, 'Sunsets');
    await waiting(tester, 8);
    await open(tester, textScale: scale);
    await tagInto(tester, 'Goa Trip');
    await tagInto(tester, 'Goa Trip');
    await tagInto(tester, 'London Food');
    await showPictures(tester);
  });

  both('Pick several', 'tag_player_pick', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await reel(tester, 'Sunsets');
    await waiting(tester, 8);
    await open(tester, textScale: scale);
    await tester.tap(find.text('Pick several'));
    await settleApp(tester);
    await tester.tap(chip('Goa Trip'));
    await tester.tap(chip('Sunsets'));
    await settleApp(tester);
  });

  both('no reels', 'tag_player_no_reels', (tester, scale) async {
    await waiting(tester, 8);
    await open(tester, textScale: scale);
  });

  both('loading', 'tag_player_loading', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await waiting(tester, 8);
    platform.hold = true;
    await open(tester, textScale: scale, animate: false);
  });

  both('a long clip', 'tag_player_long', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await waiting(tester, 3, durationMs: 272000);
    platform.duration = const Duration(minutes: 4, seconds: 32);
    await open(tester, textScale: scale);
    await tester.tap(find.byKey(const ValueKey('tt-scrub-gesture')));
    await settleApp(tester);
  });

  both('a horizontal clip', 'tag_player_horizontal', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await waiting(tester, 3, horizontal: true);
    platform.size = const Size(1920, 1080);
    await open(tester, textScale: scale);
  });

  both('All done!', 'tag_player_done', (tester, scale) async {
    await reel(tester, 'London Food');
    await reel(tester, 'Goa Trip');
    await waiting(tester, 6);
    await open(tester, textScale: scale);
    await tagInto(tester, 'Goa Trip');
    await tagInto(tester, 'Goa Trip');
    await tagInto(tester, 'London Food');
    await tagInto(tester, 'Goa Trip');
    await tester.tap(find.text('Skip'));
    await settleApp(tester);
    await tester.tap(find.text('Skip'));
    await settleApp(tester);
  });
}
