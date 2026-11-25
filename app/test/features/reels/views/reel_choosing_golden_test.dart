import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../../editors/editors_support.dart';
import '../edit_session_support.dart';

/// A reel's page while clips are chosen (D-191, screen 8): the top bar with
/// the count and Select all, and the dock in the nav pill's place. Three
/// states, light and dark at text 1x, and the first at 2x:
///
/// - **some**: two clips chosen by holding: "2 selected" and "Edit 2 clips";
/// - **none**: Choose clips instead from the sheet: "Choose clips", the hint
///   and the dock off;
/// - **session**: a clip chosen on a reel being edited in VN: the note in
///   place of Edit.
///
/// **macOS only, and not on CI** (D-61, D-97), like the other app screens:
/// make or update them with `tool/flutter test --update-goldens
/// test/features/reels/views/reel_choosing_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

/// What is on the page when the picture is taken.
enum _State { some, none, session }

void main() {
  late VmHarness h;

  setUp(() {
    h = reelHarness();
    h.editors
      ..allow({'apps'})
      ..installed = {
        for (final editor in EditorApp.values) editor.packageName: true,
      };
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
  /// thumbnail. Returns the reel and its clip ids in shooting order.
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

  Finder tile(int clipId) => find.byWidgetPredicate(
    (w) => w is TtClipTile && w.key == ValueKey(clipId),
  );

  for (final (state, brightness, scale, name) in [
    (_State.some, Brightness.light, 1.0, 'reel_choosing_some_light'),
    (_State.some, Brightness.dark, 1.0, 'reel_choosing_some_dark'),
    (_State.some, Brightness.light, 2.0, 'reel_choosing_some_2x'),
    (_State.none, Brightness.light, 1.0, 'reel_choosing_none_light'),
    (_State.none, Brightness.dark, 1.0, 'reel_choosing_none_dark'),
    (_State.session, Brightness.light, 1.0, 'reel_choosing_session_light'),
    (_State.session, Brightness.dark, 1.0, 'reel_choosing_session_dark'),
  ]) {
    testApp("a reel's page while choosing ($name)", (tester) async {
      // The test binding draws shadows sharp (`debugDisableShadows`), which
      // would show the dock's as a hard dark rim; the phone blurs them.
      final shadowsBefore = debugDisableShadows;
      debugDisableShadows = false;
      try {
        final (goa, ids) = await goaReel(tester);
        if (state == _State.session) {
          await real(
            tester,
            () => startEditing(h, goa.id, EditorApp.vn, copied: [ids[0]]),
          );
        }
        await pumpScreen(
          tester,
          ReelDetailScreen(reelId: goa.id),
          overrides: h.appOverrides,
          brightness: brightness,
          textScale: scale,
          settle: false,
          inShell: true,
        );
        await settleApp(tester);
        await showPictures(tester);

        switch (state) {
          case _State.some:
            if (scale > 1) {
              // At 2x the dock covers the first clips: they are scrolled up
              // first, as on the phone.
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -400),
              );
              await tester.pumpAndSettle();
            }
            await tester.longPress(tile(ids[0]));
            await tester.pumpAndSettle();
            await tester.tap(tile(ids[2]));
            await tester.pumpAndSettle();
            expect(find.text('2 selected'), findsOneWidget);
          case _State.none:
            await tester.tap(find.byType(TtFab));
            await settleApp(tester);
            await tester.tap(
              find.widgetWithText(TtButton, 'Choose clips instead'),
            );
            await settleApp(tester);
            expect(find.text('Choose clips'), findsOneWidget);
          case _State.session:
            await tester.longPress(tile(ids[1]));
            await tester.pumpAndSettle();
            expect(find.text('1 selected'), findsOneWidget);
        }
        expect(find.byType(TtSelectionDock), findsOneWidget);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/$name.png'),
        );
      } finally {
        debugDisableShadows = shadowsBefore;
      }
    }, skip: !_goldens);
  }
}
