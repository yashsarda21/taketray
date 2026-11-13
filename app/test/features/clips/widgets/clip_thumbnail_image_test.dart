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

/// A real 1x1 JPEG, like the bridge returns; the codec recognises it by
/// content.
final Uint8List onePixel = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDgqKKK8M/VD//Z',
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

  @override
  Future<Uint8List?> thumbnailOfUri(String uri, int widthPx, int heightPx) {
    sizes.add((widthPx, heightPx));
    return super.thumbnailOfUri(uri, widthPx, heightPx);
  }
}

const String pickedUri =
    'content://media/picker/0/com.android.providers.media.photopicker/'
    'media/1000017';

Clip pickedOf({String uri = pickedUri, int id = 1}) => Clip(
  id: id,
  source: ClipSource.picker,
  pickerUri: uri,
  fingerprint: ClipFingerprint(
    sizeBytes: 2000000,
    durationMs: 8000,
    dateTakenUtc: DateTime.utc(2026, 5, 3, 8),
    displayName: 'picked.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 5, 4),
  missing: false,
);

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
      expect(bridge.sizes, [(200, 200)]);
    });

    testWidgets('null bytes give an image error and the placeholder', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf()), 3),
          throwsA(isA<StateError>()),
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
          throwsA(isA<StateError>()),
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
          throwsA(isA<Exception>()),
        );
      });
    });

    testWidgets(
      'garbage on disk: first resolve errors, then the picture shows',
      (tester) async {
        final key = ClipThumbnailKey.of(clipOf(), 300)!;
        final file = File('${root.path}/thumbs/${key.fileName}')
          ..createSync(recursive: true)
          ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3, 4]);
        bridge.thumbnails[('external_primary', 42)] = onePixel;

        await tester.runAsync(() async {
          await expectLater(
            resolve(providerFor(clipOf()), 3),
            throwsA(isA<Exception>()),
          );
          expect(
            bridge.calls,
            isEmpty,
            reason: 'the first answer came from disk',
          );
          expect(file.existsSync(), isFalse, reason: 'discarded');

          final info = await resolve(providerFor(clipOf()), 3);

          expect(info.image.width, 1);
          expect(bridge.calls, ['thumbnail']);
          expect(file.readAsBytesSync(), onePixel, reason: 'rewritten whole');
        });
      },
    );

    testWidgets('undecodable bridge bytes: the next resolve asks again', (
      tester,
    ) async {
      bridge.thumbnails[('external_primary', 42)] = Uint8List.fromList([
        0xFF,
        0xD8,
        1,
        2,
        3,
      ]);

      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf()), 3),
          throwsA(isA<Exception>()),
        );
        bridge.thumbnails[('external_primary', 42)] = onePixel;

        final info = await resolve(providerFor(clipOf()), 3);

        expect(info.image.width, 1);
        expect(bridge.sizes, [(300, 300), (300, 300)]);
      });
    });

    testWidgets('a detached clip gives an image error without a bridge call', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(clipOf(mediaStoreId: -3)), 3),
          throwsA(isA<StateError>()),
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

    testWidgets('a picked clip resolves to an image from thumbnailOfUri', (
      tester,
    ) async {
      bridge.uriThumbnails[pickedUri] = onePixel;

      final info = await tester.runAsync(
        () => resolve(providerFor(pickedOf()), 3),
      );

      expect(info!.image.width, 1);
      expect(info.scale, 3);
      expect(bridge.sizes, [(300, 300)]);
      expect(bridge.calls, ['thumbnailOfUri']);
    });

    testWidgets('a picked clip with no picture gives an image error', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          resolve(providerFor(pickedOf()), 3),
          throwsA(isA<StateError>()),
        );
      });

      expect(bridge.calls, ['thumbnailOfUri']);
    });

    test('picked providers are equal for one address; another address or a '
        'MediaStore clip is not', () {
      final a = providerFor(pickedOf());
      final b = providerFor(pickedOf(id: 99));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(providerFor(pickedOf(uri: '${pickedUri}8'))));
      expect(a, isNot(providerFor(clipOf())));
      expect(providerFor(clipOf()), isNot(a));
    });

    test('a picked provider and its key never print the address', () async {
      final provider = providerFor(pickedOf());
      final key = await provider.obtainKey(ImageConfiguration.empty);

      for (final text in [provider.toString(), key.toString()]) {
        expect(text, isNot(contains('content')));
        expect(text, isNot(contains('photopicker')));
        expect(text, isNot(contains('1000017')));
        expect(text, isNot(contains('/')));
      }
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
