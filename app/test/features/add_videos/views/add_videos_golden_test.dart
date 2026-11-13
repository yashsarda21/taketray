import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/media_clip.dart';

import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

/// Add videos' screenshots (prototype screen 17, D-114): the folder list with
/// its tip, the grid with marks and a choice, an empty folder, and the Manual
/// mode sheet (D-115), at text 1x and 2x, and the list, the grid and the sheet
/// also in dark.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens:
/// the images are made with real text on the owner's Mac (`goldens/macos/`).
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/add_videos/views/add_videos_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late AddHarness a;

  setUp(() => a = AddHarness());

  final today = DateTime(addNow.year, addNow.month, addNow.day);
  final yesterday = today.subtract(const Duration(days: 1));

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

  /// Folders like a phone's: the camera (12), WhatsApp (8), a GoPro (3) and a
  /// card's camera folder (2), each with pictures; the WhatsApp videos are
  /// the ones the grid shows.
  Future<List<MediaVideo>> phoneFolders(WidgetTester tester) async {
    final colours = [
      for (final (x, y) in [
        (0xFF3A6EA5, 0xFF1B2A41),
        (0xFFC06C3A, 0xFF3B1F14),
        (0xFF4E8B5F, 0xFF16301F),
        (0xFF8E5BA8, 0xFF2A1836),
      ])
        (await tester.runAsync(() => picture(Color(x), Color(y))))!,
    ];
    MediaVideo video(
      int id,
      DateTime shot, {
      String folder = whatsAppFolder,
      String volume = phone,
      int seconds = 5,
      bool horizontal = false,
    }) {
      a.bridge.thumbnails[(volume, id)] = colours[id % colours.length];
      return folderVideo(
        id,
        shot,
        folder: folder,
        volume: volume,
        seconds: seconds,
        horizontal: horizontal,
      );
    }

    final whatsApp = [
      video(1, today.add(const Duration(hours: 13, minutes: 12)), seconds: 14),
      video(2, today.add(const Duration(hours: 12, minutes: 41)), seconds: 32),
      video(
        3,
        today.add(const Duration(hours: 11, minutes: 5)),
        seconds: 9,
        horizontal: true,
      ),
      video(4, today.add(const Duration(hours: 9, minutes: 50)), seconds: 21),
      video(
        5,
        yesterday.add(const Duration(hours: 20, minutes: 4)),
        seconds: 6,
      ),
      video(6, yesterday.add(const Duration(hours: 18, minutes: 30))),
      video(7, yesterday.add(const Duration(hours: 18, minutes: 2))),
      video(8, yesterday.add(const Duration(hours: 17)), seconds: 48),
    ];
    a.bridge
      ..putFolder('DCIM/Camera/', [
        for (var i = 0; i < 12; i++)
          video(
            20 + i,
            yesterday.add(Duration(hours: 9, minutes: i)),
            folder: 'DCIM/Camera/',
          ),
      ])
      ..putFolder(whatsAppFolder, whatsApp)
      ..putFolder('DCIM/GoPro/', [
        for (var i = 0; i < 3; i++)
          video(
            40 + i,
            yesterday.add(Duration(hours: 7, minutes: i)),
            folder: 'DCIM/GoPro/',
          ),
      ])
      ..putFolder('DCIM/Camera/', [
        for (var i = 0; i < 2; i++)
          video(
            50 + i,
            yesterday.add(Duration(hours: 6, minutes: i)),
            folder: 'DCIM/Camera/',
            volume: card,
          ),
      ], volume: card);
    return whatsApp;
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
        await body(tester, scale, brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/add_videos_${name}_$suffix.png'),
        );
      }, skip: !_goldens);
    }
  }

  both('the folder list, with the tip', 'folders', (
    tester,
    scale,
    brightness,
  ) async {
    await phoneFolders(tester);
    final goa = await a.makeReel(tester, 'Goa trip');
    await a.pumpOrigin(
      tester,
      AddToReel(goa.id),
      textScale: scale,
      brightness: brightness,
    );
    await openBrowser(tester);
    await showPictures(tester);
  }, dark: true);

  both('the grid, some marked and some picked', 'grid', (
    tester,
    scale,
    brightness,
  ) async {
    final videos = await phoneFolders(tester);
    final goa = await a.makeReel(tester, 'Goa trip');
    await tester.runAsync(
      () => a.h.media.clips.addNewClipsToReel(goa.id, [
        newClipFrom(videos[3], now: addNow, zoneId: null),
      ]),
    );
    await tester.runAsync(() => a.h.media.store([videos[5]]));
    await tester.runAsync(a.h.media.phoneState.markFolderTipSeen);
    await a.pumpOrigin(
      tester,
      AddToReel(goa.id),
      textScale: scale,
      brightness: brightness,
    );
    await openBrowser(tester);
    await openFolder(tester, 'WhatsApp Video');
    await tapAndSettle(tester, tileOf(1));
    await tapAndSettle(tester, tileOf(3));
    await showPictures(tester);
  }, dark: true);

  both('a folder with no videos', 'empty', (tester, scale, brightness) async {
    a.bridge.putFolder('Movies/Old/', [
      fakeVideo(id: 1, folder: 'Movies/Old/', pending: true),
    ]);
    await a.pumpOrigin(
      tester,
      const AddToToTag(),
      textScale: scale,
      brightness: brightness,
    );
    await openBrowser(tester);
    await openFolder(tester, 'Old');
  });

  both('the Manual mode sheet', 'manual', (tester, scale, brightness) async {
    a.bridge.access = const MediaAccess(
      level: MediaAccessLevel.limited,
      canAskAgain: true,
      sdkInt: 34,
    );
    await a.pumpOrigin(
      tester,
      const AddToToTag(),
      textScale: scale,
      brightness: brightness,
    );
    await openBrowser(tester);
  }, dark: true);
}
