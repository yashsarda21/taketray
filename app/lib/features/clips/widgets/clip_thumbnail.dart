import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';

/// The picture of [clip] for a tile, [logicalSize] logical pixels square.
///
/// [cache] is what `thumbnailCacheProvider` has given so far (it is a
/// `Future`): a [ClipThumbnailImage] once there is one, until then a picture
/// that fails at once, which a tile shows as its placeholder (D-74, D-76).
/// Both fail the same silent way, so the tile does not need to know which it
/// has.
ImageProvider clipThumbnail({
  required Clip clip,
  required double logicalSize,
  required ThumbnailCache? cache,
}) => cache == null
    ? const _NoThumbnailYet()
    : ClipThumbnailImage(clip: clip, logicalSize: logicalSize, cache: cache);

/// A picture that is not there (yet): its stream ends in an error, which an
/// `Image` shows through its `errorBuilder`.
@immutable
class _NoThumbnailYet extends ImageProvider<_NoThumbnailYet> {
  const _NoThumbnailYet();

  @override
  Future<_NoThumbnailYet> obtainKey(ImageConfiguration configuration) =>
      Future.error(StateError('The thumbnail cache is not ready yet'));

  @override
  ImageStreamCompleter loadImage(
    _NoThumbnailYet key,
    ImageDecoderCallback decode,
  ) => throw StateError('A picture with no key cannot be loaded');

  @override
  bool operator ==(Object other) => other is _NoThumbnailYet;

  @override
  int get hashCode => 0;
}
