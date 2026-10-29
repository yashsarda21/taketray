import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';

/// A clip's thumbnail as an [ImageProvider], read through a [ThumbnailCache]
/// (D-74).
///
/// [logicalSize] is the side of the square in logical pixels; the picture is
/// asked for at that size times the device pixel ratio of the
/// [ImageConfiguration], and drawn with that scale, so it fills [logicalSize].
///
/// When there is no picture (the video is gone, the clip is detached or
/// picked, the volume is out, access is refused) the stream reports an error,
/// which an `Image` shows through its `errorBuilder`: the tile's placeholder.
/// Nothing is reported to the log, and a failure is not kept by Flutter's
/// image cache, so the next time the tile is built it asks again.
///
/// Two providers are equal when they are for the same video (volume, number,
/// size and date taken) at the same [logicalSize]; the clip's row id and the
/// cache do not count. Their keys are equal when, besides, the pixel size is
/// the same.
@immutable
class ClipThumbnailImage extends ImageProvider<ClipThumbnailKey> {
  const ClipThumbnailImage({
    required this.clip,
    required this.logicalSize,
    required this.cache,
  });

  final Clip clip;
  final double logicalSize;
  final ThumbnailCache cache;

  @override
  Future<ClipThumbnailKey> obtainKey(ImageConfiguration configuration) {
    final dpr = configuration.devicePixelRatio ?? 1.0;
    final key = ClipThumbnailKey.of(clip, (logicalSize * dpr).round());
    if (key == null) {
      return Future.error(StateError('This clip has no thumbnail to ask for'));
    }
    return Future.value(key);
  }

  @override
  ImageStreamCompleter loadImage(
    ClipThumbnailKey key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _decode(key, decode),
    scale: key.sizePx / logicalSize,
    debugLabel: key.fileName,
  );

  Future<ui.Codec> _decode(
    ClipThumbnailKey key,
    ImageDecoderCallback decode,
  ) async {
    Uint8List? bytes;
    try {
      bytes = await cache.load(clip, key.sizePx);
      if (bytes == null) {
        throw StateError('No thumbnail for ${key.fileName}');
      }
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } on Object {
      // Bytes that do not decode would be read from the disk again by every
      // tile, for ever: delete that file so the next tile asks the bridge.
      if (bytes != null) await cache.discard(clip, key.sizePx);
      // Flutter's image cache would keep this failed load for the key and
      // replay the error to every later tile (as `NetworkImage` also avoids).
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ClipThumbnailImage &&
      other.logicalSize == logicalSize &&
      other.clip.volumeName == clip.volumeName &&
      other.clip.mediaStoreId == clip.mediaStoreId &&
      other.clip.fingerprint.sizeBytes == clip.fingerprint.sizeBytes &&
      other.clip.fingerprint.dateTakenUtc == clip.fingerprint.dateTakenUtc;

  @override
  int get hashCode => Object.hash(
    clip.volumeName,
    clip.mediaStoreId,
    clip.fingerprint.sizeBytes,
    clip.fingerprint.dateTakenUtc,
    logicalSize,
  );

  @override
  String toString() =>
      'ClipThumbnailImage(${clip.volumeName}/${clip.mediaStoreId}, $logicalSize)';
}
