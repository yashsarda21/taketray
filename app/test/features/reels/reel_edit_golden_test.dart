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
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';
import '../editors/editors_support.dart';
import 'edit_session_support.dart';

/// The reel page while editing (D-128): VN and CapCut, with and without new
/// clips; the add picker; the Done editing dialog and the delete dialog with
/// the VN line.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens:
/// make or update them with `tool/flutter test --update-goldens
/// test/features/reels/reel_edit_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

void main() {
  late VmHarness h;

  setUp(() => h = reelHarness());

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
    for (var i = 0; i < 40 && (i < 2 || pending()); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await settleApp(tester);
  }

  /// "Goa food trip" with six clips over two days; returns the reel and the
  /// clip ids in shooting order.
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
    final ids = await real(tester, () => putInReel(h, goa.id, videos));
    return (goa, ids);
  }

  Future<void> openPage(
    WidgetTester tester,
    Reel reel, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      ReelDetailScreen(reelId: reel.id),
      overrides: h.appOverrides,
      textScale: scale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    await showPictures(tester);
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/macos/$name.png'),
  );

  for (final (scale, brightness, suffix) in [
    (1.0, Brightness.light, '1x'),
    (2.0, Brightness.light, '2x'),
    (1.0, Brightness.dark, 'dark_1x'),
  ]) {
    testApp('VN, with new clips ($suffix)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: ids.sublist(0, 4),
          folder: 'Goa food trip',
        ),
      );
      await openPage(tester, goa, scale: scale, brightness: brightness);

      await shot(tester, 'reel_editing_vn_new_$suffix');
    }, skip: !_goldens);

    testApp('the add picker ($suffix)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: ids.sublist(0, 4),
          folder: 'Goa food trip',
        ),
      );
      await pumpScreen(
        tester,
        EditSelectScreen(reelId: goa.id, addMode: true),
        overrides: h.appOverrides,
        textScale: scale,
        brightness: brightness,
        settle: false,
      );
      await settleApp(tester);
      await showPictures(tester);

      await shot(tester, 'reel_editing_add_picker_$suffix');
    }, skip: !_goldens);

    testApp('the Done editing dialog, VN ($suffix)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.vn,
          copied: ids.sublist(0, 3),
          folder: 'Goa food trip',
        ),
      );
      await openPage(tester, goa, scale: scale, brightness: brightness);
      await tester.tap(find.text('Done editing'));
      await settleApp(tester);

      await shot(tester, 'reel_editing_done_vn_$suffix');
    }, skip: !_goldens);
  }

  for (final (scale, brightness, suffix) in [
    (1.0, Brightness.light, '1x'),
    (2.0, Brightness.light, '2x'),
    (1.0, Brightness.dark, 'dark_1x'),
  ]) {
    testApp('the add picker, CapCut ($suffix)', (tester) async {
      final (goa, ids) = await goaReel(tester);
      await real(
        tester,
        () => startEditing(
          h,
          goa.id,
          EditorApp.capcut,
          copied: ids.sublist(0, 2),
          sent: ids.sublist(0, 4),
          folder: 'Goa food trip',
        ),
      );
      await pumpScreen(
        tester,
        EditSelectScreen(reelId: goa.id, addMode: true),
        overrides: h.appOverrides,
        textScale: scale,
        brightness: brightness,
        settle: false,
      );
      await settleApp(tester);
      await showPictures(tester);

      await shot(tester, 'reel_editing_capcut_add_picker_$suffix');
    }, skip: !_goldens);
  }

  testApp('the page, Edits with new clips and copies (2x)', (tester) async {
    final (goa, ids) = await goaReel(tester);
    await real(
      tester,
      () => startEditing(
        h,
        goa.id,
        EditorApp.edits,
        copied: ids.sublist(0, 2),
        sent: ids.sublist(0, 4),
        folder: 'Goa food trip',
      ),
    );
    await openPage(tester, goa, scale: 2);

    await shot(tester, 'reel_editing_edits_new_2x');
  }, skip: !_goldens);

  testApp('VN, no new clips (1x)', (tester) async {
    final (goa, ids) = await goaReel(tester);
    await real(
      tester,
      () => startEditing(
        h,
        goa.id,
        EditorApp.vn,
        copied: ids,
        folder: 'Goa food trip',
      ),
    );
    await openPage(tester, goa);

    await shot(tester, 'reel_editing_vn_all_1x');
  }, skip: !_goldens);

  testApp('CapCut, with new clips (1x)', (tester) async {
    final (goa, ids) = await goaReel(tester);
    await real(
      tester,
      () => startEditing(h, goa.id, EditorApp.capcut, sent: ids.sublist(0, 4)),
    );
    await openPage(tester, goa);

    await shot(tester, 'reel_editing_capcut_new_1x');
  }, skip: !_goldens);

  testApp('CapCut, no new clips (1x)', (tester) async {
    final (goa, ids) = await goaReel(tester);
    await real(
      tester,
      () => startEditing(h, goa.id, EditorApp.capcut, sent: ids),
    );
    await openPage(tester, goa);

    await shot(tester, 'reel_editing_capcut_all_1x');
  }, skip: !_goldens);

  testApp('the Done editing dialog, CapCut with no copies (1x)', (
    tester,
  ) async {
    final (goa, ids) = await goaReel(tester);
    await real(
      tester,
      () => startEditing(h, goa.id, EditorApp.capcut, sent: ids),
    );
    await openPage(tester, goa);
    await tester.tap(find.text('Done editing'));
    await settleApp(tester);

    await shot(tester, 'reel_editing_done_capcut_1x');
  }, skip: !_goldens);

  testApp('the delete dialog with the VN line (1x)', (tester) async {
    final (goa, ids) = await goaReel(tester);
    await real(
      tester,
      () => startEditing(
        h,
        goa.id,
        EditorApp.vn,
        copied: ids.sublist(0, 3),
        folder: 'Goa food trip',
      ),
    );
    await openPage(tester, goa);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is TtIconButton && w.semanticLabel == 'More options',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete reel'));
    await settleApp(tester);

    await shot(tester, 'reel_editing_delete_vn_1x');
  }, skip: !_goldens);
}
