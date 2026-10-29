import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';

import '../../../support/fake_media_bridge.dart';

/// A real 1x1 PNG; the image codec recognises it by content.
final Uint8List onePixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class SizeRecordingBridge extends FakeMediaBridge {
  final List<(int, int)> sizes = [];

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) {
    sizes.add((widthPx, heightPx));
    return super.thumbnail(volumeName, mediaStoreId, widthPx, heightPx);
  }
}

Clip clipOf({int mediaStoreId = 42, int sizeBytes = 1000000}) => Clip(
  id: 1,
  source: ClipSource.mediaStore,
  mediaStoreId: mediaStoreId,
  volumeName: 'external_primary',
  fingerprint: ClipFingerprint(
    sizeBytes: sizeBytes,
    durationMs: 5000,
    dateTakenUtc: DateTime.utc(2026, 5, 1, 12),
    displayName: 'VID.mp4',
  ),
  width: 1920,
  height: 1080,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 5, 2),
  missing: false,
);

/// Lets the file reads and the decoder (real asynchrony) finish, and builds
/// the frames that follow.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory root;
  late SizeRecordingBridge bridge;
  late ThumbnailCache cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('thumb_image_test');
    bridge = SizeRecordingBridge();
    cache = ThumbnailCache(bridge, Directory('${root.path}/thumbs'));
  });

  tearDown(() {
    imageCache
      ..clear()
      ..clearLiveImages();
    root.deleteSync(recursive: true);
  });

  ClipThumbnailImage providerFor(Clip clip, {double size = 100}) =>
      ClipThumbnailImage(clip: clip, logicalSize: size, cache: cache);

  /// Resolves [provider] and completes with the first image, or fails with
  /// the first error. The listener goes away afterwards, as a disposed `Image`
  /// would, so Flutter's image cache keeps nothing alive.
  Future<ImageInfo> resolve(ClipThumbnailImage provider, double dpr) {
    final done = Completer<ImageInfo>();
    final stream = provider.resolve(ImageConfiguration(devicePixelRatio: dpr));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        done.complete(info);
      },
      onError: (error, _) {
        stream.removeListener(listener);
        done.completeError(error);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  group('ClipThumbnailImage', () {
    testWidgets('provider resolves to an image at dpr 3', (tester) async {
      bridge.thumbnails[('external_primary', 42)] = onePixel;

      final info = await tester.runAsync(
        () => resolve(providerFor(clipOf()), 3),
      );

      expect(info!.image.width, 1);
      expect(info.scale, 3, reason: 'the 300 px picture is drawn at 100 dp');
      expect(bridge.sizes, [(300, 300)]);
    });

    testWidgets('a widget shows the picture and not the placeholder', (
      tester,
    ) async {
      bridge.thumbnails[('external_primary', 42)] = onePixel;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Image(
            image: providerFor(clipOf()),
            errorBuilder: (_, _, _) => const Text('placeholder'),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('placeholder'), findsNothing);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image,
        isNotNull,
        reason: 'the frame was decoded and drawn',
      );
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image,
        isNotNull,
        reason: 'the frame was decoded and drawn',
      );
      expect(bridge.sizes, [(200, 200)]);
    });

    testWidgets('null bytes give an image error and the placeholder', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf()), 3),
          throwsA(isA<Object>()),
        );
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Image(
            image: providerFor(clipOf()),
            errorBuilder: (_, _, _) => const Text('placeholder'),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('placeholder'), findsOneWidget);
    });

    testWidgets('a failed load is not kept: the next resolve asks again', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf()), 3),
          throwsA(isA<Object>()),
        );
        bridge.thumbnails[('external_primary', 42)] = onePixel;

        final info = await resolve(providerFor(clipOf()), 3);

        expect(info.image.width, 1);
      });
    });

    testWidgets('invalid bytes give an error, not a crash', (tester) async {
      bridge.thumbnails[('external_primary', 42)] = Uint8List.fromList([
        1,
        2,
        3,
      ]);

      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf()), 3),
          throwsA(isA<Object>()),
        );
      });
    });

    testWidgets('a detached clip gives an image error without a bridge call', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf(mediaStoreId: -3)), 3),
          throwsA(isA<Object>()),
        );
      });

      expect(bridge.calls, isEmpty);
    });

    test('same clip and size are equal; a changed fingerprint is not', () {
      final a = providerFor(clipOf());
      final b = providerFor(clipOf());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(providerFor(clipOf(sizeBytes: 5))));
      expect(a, isNot(providerFor(clipOf(mediaStoreId: 43))));
      expect(a, isNot(providerFor(clipOf(), size: 120)));
    });

    test(
      'the keys are equal at one pixel ratio and differ across ratios',
      () async {
        final a = providerFor(clipOf());
        final b = providerFor(clipOf());

        final a3 = await a.obtainKey(
          const ImageConfiguration(devicePixelRatio: 3),
        );
        final b3 = await b.obtainKey(
          const ImageConfiguration(devicePixelRatio: 3),
        );
        final a2 = await a.obtainKey(
          const ImageConfiguration(devicePixelRatio: 2),
        );

        expect(a3, b3);
        expect(a3.hashCode, b3.hashCode);
        expect(a3, isNot(a2));
        expect(a3.sizePx, 300);
        expect(a2.sizePx, 200);
      },
    );

    test('a missing pixel ratio counts as 1', () async {
      final key = await providerFor(clipOf())
          .obtainKey(ImageConfiguration.empty);

      expect(key.sizePx, 100);
    });

    test('the key does not depend on the clip row id or the cache', () async {
      final other = ThumbnailCache(bridge, Directory('${root.path}/other'));
      final a = await providerFor(clipOf()).obtainKey(ImageConfiguration.empty);
      final b = await ClipThumbnailImage(
        clip: clipOf().copyWith(id: 99),
        logicalSize: 100,
        cache: other,
      ).obtainKey(ImageConfiguration.empty);

      expect(a, b);
    });
  });
}
