import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/fake_media_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getApplicationCacheDirectory');
          return '/data/user/0/app.taketray/cache';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('the folder is getApplicationCacheDirectory()/thumbs', () async {
    final container = ProviderContainer.test();

    final dir = await container.read(thumbnailCacheDirProvider.future);

    expect(dir.path, '/data/user/0/app.taketray/cache/thumbs');
  });

  test(
    'thumbnailCacheProvider builds a cache on that folder and the bridge',
    () async {
      final bridge = FakeMediaBridge();
      final container = ProviderContainer.test(
        overrides: [mediaBridgeProvider.overrideWithValue(bridge)],
      );

      final cache = await container.read(thumbnailCacheProvider.future);

      expect(cache.maxBytes, 64 * 1024 * 1024);
      // Pruning a folder that is not there yet is fine.
      expect(
        Directory('/data/user/0/app.taketray/cache/thumbs').existsSync(),
        isFalse,
      );
      await cache.prune();
    },
  );
}
