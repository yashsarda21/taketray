// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `getApplicationCacheDirectory()/thumbs`: Android may empty the cache
/// folder, which the cache survives (D-74).

@ProviderFor(thumbnailCacheDir)
final thumbnailCacheDirProvider = ThumbnailCacheDirProvider._();

/// `getApplicationCacheDirectory()/thumbs`: Android may empty the cache
/// folder, which the cache survives (D-74).

final class ThumbnailCacheDirProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// `getApplicationCacheDirectory()/thumbs`: Android may empty the cache
  /// folder, which the cache survives (D-74).
  ThumbnailCacheDirProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thumbnailCacheDirProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thumbnailCacheDirHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return thumbnailCacheDir(ref);
  }
}

String _$thumbnailCacheDirHash() => r'706438624165131f8aa1593f8ee61b3cf1c02bca';

/// The one [ThumbnailCache] of the app. `MediaLifecycle` calls `prune()` on
/// it once at start (D-75).

@ProviderFor(thumbnailCache)
final thumbnailCacheProvider = ThumbnailCacheProvider._();

/// The one [ThumbnailCache] of the app. `MediaLifecycle` calls `prune()` on
/// it once at start (D-75).

final class ThumbnailCacheProvider
    extends
        $FunctionalProvider<
          AsyncValue<ThumbnailCache>,
          ThumbnailCache,
          FutureOr<ThumbnailCache>
        >
    with $FutureModifier<ThumbnailCache>, $FutureProvider<ThumbnailCache> {
  /// The one [ThumbnailCache] of the app. `MediaLifecycle` calls `prune()` on
  /// it once at start (D-75).
  ThumbnailCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thumbnailCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thumbnailCacheHash();

  @$internal
  @override
  $FutureProviderElement<ThumbnailCache> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ThumbnailCache> create(Ref ref) {
    return thumbnailCache(ref);
  }
}

String _$thumbnailCacheHash() => r'1fbc71e861b365321e318586e2052a99aa3210c2';
