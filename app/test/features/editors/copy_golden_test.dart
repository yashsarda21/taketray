import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';

import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import 'copy_support.dart';
import 'editors_support.dart';

/// The VN copy screens (prototype `vn-space`, `vn-copy`, `vn-ready` and
/// `dialogs.stopCopy`, D-127): enough space, not enough, copying, the Stop
/// dialog, storage full, TakeTray stopped mid-copy, one clip that failed, no
/// clip copied and the ready steps, at text 1x and 2x and in dark.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens: the
/// images are made with real text on the owner's Mac (`goldens/macos/`). Make
/// or update them with `tool/flutter test --update-goldens
/// test/features/editors/copy_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const int _mb = 1000000;

void main() {
  late VmHarness h;
  late ProviderContainer app;

  setUp(() {
    h = reelHarness();
    h.copy.allowAll();
    h.editors
      ..allow({
        'freeBytes',
        'copyFolderNames',
        'filesInCopyFolders',
        'existingCopies',
        'deleteCopies',
      })
      ..bytesFree = 6200 * _mb;
  });

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

  /// Lets the thumbnails load for real.
  Future<void> showPictures(WidgetTester tester) async {
    bool pending() => find
        .byType(Image)
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderImage>()
        .any((r) => r.image == null);
    // At least 400 ms: the cache and the pictures answer after the first frame.
    for (var i = 0; i < 40 && (i < 8 || pending()); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await settleApp(tester);
  }

  /// "Goa food trip" with [count] clips of [each] bytes, shot an hour apart.
  Future<(Reel, List<int>)> goa(
    WidgetTester tester, {
    int count = 8,
    int each = 150 * _mb,
  }) async {
    final colours = [
      for (final (x, y) in [
        (0xFF3A6EA5, 0xFF1B2A41),
        (0xFFC06C3A, 0xFF3B1F14),
        (0xFF4E8B5F, 0xFF16301F),
        (0xFF8E5BA8, 0xFF2A1836),
      ])
        (await tester.runAsync(() => picture(Color(x), Color(y))))!,
    ];
    final reel = (await tester.runAsync(
      () => h.container.read(reelsRepositoryProvider).create('Goa food trip'),
    ))!;
    final videos = [
      for (var i = 0; i < count; i++)
        sizedVideo(
          i + 1,
          shot: DateTime.utc(2026, 10, 25, 8 + i, 12),
          size: each,
        ),
    ];
    for (final v in videos) {
      h.bridge.thumbnails[(phone, v.mediaStoreId)] =
          colours[v.mediaStoreId % colours.length];
    }
    // A fixed zone, so the time of a failed clip reads the same on any Mac.
    final ids = (await tester.runAsync(
      () => putInReel(h, reel.id, videos, zoneId: 'Asia/Kolkata'),
    ))!;
    return (reel, ids);
  }

  Future<void> start(
    WidgetTester tester, {
    required double scale,
    required Brightness brightness,
  }) async {
    app = await pumpScreen(
      tester,
      const Scaffold(body: Text('home')),
      overrides: h.appOverrides,
      copyScreens: true,
      textScale: scale,
      brightness: brightness,
      settle: false,
    );
    followJob(app);
    await settleApp(tester);
  }

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(routerOf(tester).push(location));
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
    testApp('the space check, enough space ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copySpaceOf(reel.id, EditorApp.vn, ids));
      await golden(tester, 'copy_space_enough_$suffix');
    }, skip: !_goldens);

    testApp('the space check, not enough space ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      h.editors.bytesFree = 900 * _mb;
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copySpaceOf(reel.id, EditorApp.vn, ids));
      await golden(tester, 'copy_space_short_$suffix');
    }, skip: !_goldens);

    testApp('copying ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      final job = await startVnJob(tester, h, reel, ids);
      h.copy.job = job.report(copied: [0, 1, 2], bytesDone: 520 * _mb);
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyProgressOf(job.jobId));
      await golden(tester, 'copy_progress_$suffix');
    }, skip: !_goldens);

    testApp('copying, the Stop dialog ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      final job = await startVnJob(tester, h, reel, ids);
      h.copy.job = job.report(copied: [0, 1, 2], bytesDone: 520 * _mb);
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyProgressOf(job.jobId));
      await tester.tap(find.text('Cancel'));
      await settleApp(tester);
      await golden(tester, 'copy_stop_dialog_$suffix');
    }, skip: !_goldens);

    testApp('phone storage is full ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      final job = await startVnJob(tester, h, reel, ids);
      h.copy.job = job.report(
        state: CopyState.spaceFull,
        copied: [0, 1, 2, 3, 4],
      );
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyProgressOf(job.jobId));
      await golden(tester, 'copy_space_full_$suffix');
    }, skip: !_goldens);

    testApp('copying stopped (interrupted) ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      final job = await startVnJob(tester, h, reel, ids);
      // The job a restart's recovery builds: TakeTray was closed (M-3).
      h.copy.job = job
          .report(state: CopyState.interrupted, copied: [0, 1, 2, 3])
          .copyWith(wasClosed: true);
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyProgressOf(job.jobId));
      await golden(tester, 'copy_interrupted_$suffix');
    }, skip: !_goldens);

    testApp('one clip could not be copied ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      final job = await startVnJob(tester, h, reel, ids);
      h.copy.job = job.report(
        state: CopyState.finished,
        copied: [0, 1, 2, 3, 4, 5, 7],
        failed: [6],
      );
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyProgressOf(job.jobId));
      await golden(tester, 'copy_one_failed_$suffix');
    }, skip: !_goldens);

    testApp('no clip could be copied ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      final job = await startVnJob(tester, h, reel, ids);
      h.copy.job = job.report(
        state: CopyState.finished,
        failed: [0, 1, 2, 3, 4, 5, 6, 7],
      );
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyProgressOf(job.jobId));
      await golden(tester, 'copy_all_failed_$suffix');
    }, skip: !_goldens);

    testApp('the space check for CapCut ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      await real(tester, () async {
        final sessions = h.container.read(editSessionsRepositoryProvider);
        await sessions.startSession(reel.id, EditorApp.capcut, 'Goa food trip');
        await sessions.recordSent(reel.id, ids.sublist(0, 5));
      });
      await start(tester, scale: scale, brightness: brightness);
      await push(
        tester,
        Routes.copySpaceOf(reel.id, EditorApp.capcut, ids.sublist(5)),
      );
      await golden(tester, 'copy_space_capcut_enough_$suffix');
    }, skip: !_goldens);

    testApp('ready to add in CapCut ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      await real(tester, () async {
        final sessions = h.container.read(editSessionsRepositoryProvider);
        await sessions.startSession(reel.id, EditorApp.capcut, 'Goa food trip');
        await sessions.recordSent(reel.id, ids.sublist(0, 5));
        await sessions.recordCopies([
          for (final (i, id) in ids.sublist(5).indexed)
            EditCopy(
              reelId: reel.id,
              clipId: id,
              copyMediaStoreId: 700 + i,
              fileName: 'c$i.mp4',
              sizeBytes: 150 * _mb,
              copiedAt: DateTime.utc(2026, 10, 30),
            ),
        ]);
      });
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyReadyOf(reel.id));
      await golden(tester, 'copy_ready_capcut_$suffix');
    }, skip: !_goldens);

    testApp('ready for VN ($suffix)', (tester) async {
      final (reel, ids) = await goa(tester);
      await real(tester, () async {
        final sessions = h.container.read(editSessionsRepositoryProvider);
        await sessions.startSession(reel.id, EditorApp.vn, 'Goa food trip');
        await sessions.recordCopies([
          for (final (i, id) in ids.indexed)
            EditCopy(
              reelId: reel.id,
              clipId: id,
              copyMediaStoreId: 700 + i,
              fileName: 'c$i.mp4',
              sizeBytes: 150 * _mb,
              copiedAt: DateTime.utc(2026, 10, 30),
            ),
        ]);
      });
      await start(tester, scale: scale, brightness: brightness);
      await push(tester, Routes.copyReadyOf(reel.id));
      await golden(tester, 'copy_ready_$suffix');
    }, skip: !_goldens);
  }

  testApp('ready to add in Instagram Edits (2x)', (tester) async {
    final (reel, ids) = await goa(tester);
    await real(tester, () async {
      final sessions = h.container.read(editSessionsRepositoryProvider);
      await sessions.startSession(reel.id, EditorApp.edits, 'Goa food trip');
      await sessions.recordSent(reel.id, ids.sublist(0, 5));
      await sessions.recordCopies([
        for (final (i, id) in ids.sublist(5).indexed)
          EditCopy(
            reelId: reel.id,
            clipId: id,
            copyMediaStoreId: 700 + i,
            fileName: 'c$i.mp4',
            sizeBytes: 150 * _mb,
            copiedAt: DateTime.utc(2026, 10, 30),
          ),
      ]);
    });
    await start(tester, scale: 2, brightness: Brightness.light);
    await push(tester, Routes.copyReadyOf(reel.id));
    await golden(tester, 'copy_ready_edits_2x');
  }, skip: !_goldens);
}
