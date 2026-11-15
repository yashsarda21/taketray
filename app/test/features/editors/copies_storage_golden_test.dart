import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/editors/views/copies_storage_screen.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/platform/editors_bridge.dart';

import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/view_model_fakes.dart';
import '../../support/vm_harness.dart';
import '../reels/edit_session_support.dart';
import 'editors_support.dart';

/// The VN copies storage screen (prototype `vn-storage`, D-130): with copies
/// (VN, CapCut and Edits rows with their covers), with files no reel records
/// and no full access, and empty, at text 1x and 2x and in dark.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens:
/// the images are made with real text on the owner's Mac (`goldens/macos/`).
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/editors/copies_storage_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const int _mb = 1000 * 1000;

void main() {
  late VmHarness h;

  setUp(() {
    h = reelHarness();
    h.editors.allow({'filesInCopyFolders', 'existingCopies', 'requestDelete'});
  });

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

  Future<void> showPictures(WidgetTester tester) async {
    bool pending() => find
        .byType(Image)
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderImage>()
        .any((r) => r.image == null);
    for (var i = 0; i < 40 && (i < 8 || pending()); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await settleApp(tester);
  }

  /// Three reels with sessions: Goa (VN, 4 copies), Hampi (CapCut, 3 copies)
  /// and a reel with no cover (Edits, 2 copies).
  Future<void> reelsWithCopies(WidgetTester tester) async {
    final colours = [
      for (final (x, y) in [
        (0xFF3A6EA5, 0xFF1B2A41),
        (0xFFC06C3A, 0xFF3B1F14),
        (0xFF4E8B5F, 0xFF16301F),
      ])
        (await tester.runAsync(() => picture(Color(x), Color(y))))!,
    ];
    var video = 1;
    var copy = 500;
    for (final (name, editor, count, cover) in [
      ('Goa food trip', EditorApp.vn, 4, true),
      ('Hampi weekend', EditorApp.capcut, 3, true),
      ('Rooftop sunset', EditorApp.edits, 2, false),
    ]) {
      final reel = (await tester.runAsync(
        () => h.container.read(reelsRepositoryProvider).create(name),
      ))!;
      final videos = [
        for (var i = 0; i < count; i++)
          sizedVideo(
            video + i,
            shot: DateTime.utc(2026, 10, 20 + video, 8 + i, 12),
            size: 300 * _mb,
          ),
      ];
      if (cover) {
        h.bridge.thumbnails[(phone, video)] = colours[(video + 1) % 3];
      }
      final ids = (await tester.runAsync(
        () => putInReel(h, reel.id, videos, onPhone: cover),
      ))!;
      await tester.runAsync(() async {
        final sessions = h.container.read(editSessionsRepositoryProvider);
        final started = await sessions.startSession(reel.id, editor, name);
        await sessions.recordCopies([
          for (var i = 0; i < count; i++)
            EditCopy(
              reelId: reel.id,
              clipId: ids[i],
              copyMediaStoreId: copy + i,
              fileName: 'copy_${copy}_$i.mp4',
              sizeBytes: 300 * _mb,
              copiedAt: started.createdAt,
            ),
        ]);
      });
      video += count;
      copy += 100;
    }
  }

  Future<void> start(
    WidgetTester tester, {
    required double scale,
    required Brightness brightness,
    MediaAccessLevel access = MediaAccessLevel.full,
  }) async {
    await pumpScreen(
      tester,
      const CopiesStorageScreen(),
      // At 2x the list is long: a tall view shows all of it.
      size: Size(360, scale > 1 ? 2600 : 800),
      overrides: [
        ...h.appOverrides,
        mediaAccessControllerProvider.overrideWith(() => FakeAccess(access)),
      ],
      textScale: scale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    await showPictures(tester);
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/macos/$name.png'),
  );

  for (final (scale, brightness, suffix) in [
    (1.0, Brightness.light, '1x'),
    (2.0, Brightness.light, '2x'),
    (1.0, Brightness.dark, 'dark_1x'),
  ]) {
    testApp('with copies ($suffix)', (tester) async {
      await reelsWithCopies(tester);
      await start(tester, scale: scale, brightness: brightness);
      await golden(tester, 'copies_storage_copies_$suffix');
    }, skip: !_goldens);

    testApp('with files no reel records, without full access ($suffix)', (
      tester,
    ) async {
      await reelsWithCopies(tester);
      h.editors.files = [
        const CopyFolderFile(
          mediaStoreId: 900,
          folderName: 'Old Goa trip',
          fileName: 'a.mp4',
          sizeBytes: 420 * _mb,
          ownedByTakeTray: false,
        ),
        const CopyFolderFile(
          mediaStoreId: 901,
          folderName: 'Old Goa trip',
          fileName: 'b.mp4',
          sizeBytes: 380 * _mb,
          ownedByTakeTray: false,
        ),
        const CopyFolderFile(
          mediaStoreId: 902,
          folderName: 'Beach clips',
          fileName: 'c.mp4',
          sizeBytes: 250 * _mb,
          ownedByTakeTray: false,
        ),
      ];
      await start(
        tester,
        scale: scale,
        brightness: brightness,
        access: MediaAccessLevel.limited,
      );
      await golden(tester, 'copies_storage_orphans_$suffix');
    }, skip: !_goldens);

    testApp('empty ($suffix)', (tester) async {
      await start(tester, scale: scale, brightness: brightness);
      await golden(tester, 'copies_storage_empty_$suffix');
    }, skip: !_goldens);
  }
}
