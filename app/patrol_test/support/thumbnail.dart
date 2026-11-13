import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';

import 'waiting.dart';

/// The one tile [tiles] matches shows its picture: the thumbnail cache is
/// ready, and the tile's `ClipThumbnailImage` decodes to a picture with a real
/// size and without an error.
///
/// [tiles] must match exactly one tile (one `Image` inside it). Failures name
/// the error's type only, never a message that could hold a path (D-10).
Future<void> expectPictureLoads(PatrolIntegrationTester $, Finder tiles) async {
  final image = find.descendant(of: tiles, matching: find.byType(Image));
  await waitFor(
    $,
    () =>
        image.evaluate().isNotEmpty &&
        $.tester.widget<Image>(image).image is ClipThumbnailImage,
    what: 'the tile to use the thumbnail cache (ClipThumbnailImage)',
  );
  final provider = $.tester.widget<Image>(image).image;
  final stream = provider.resolve(
    createLocalImageConfiguration($.tester.element(image)),
  );
  final done = Completer<ImageInfo>();
  final listener = ImageStreamListener(
    (info, _) {
      if (!done.isCompleted) done.complete(info);
    },
    onError: (error, stack) {
      // The type only: a message could hold a path (D-10).
      if (!done.isCompleted) {
        done.completeError(
          TestFailure('The thumbnail failed to load: ${error.runtimeType}'),
        );
      }
    },
  );
  stream.addListener(listener);
  try {
    final info = await done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TestFailure('The thumbnail did not load in 20 s'),
    );
    expect(info.image.width, greaterThan(0));
    expect(info.image.height, greaterThan(0));
  } finally {
    stream.removeListener(listener);
  }
}
