// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_work_queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one queue every media job shares. Kept alive: a second queue would
/// let jobs overlap.

@ProviderFor(mediaWorkQueue)
final mediaWorkQueueProvider = MediaWorkQueueProvider._();

/// The one queue every media job shares. Kept alive: a second queue would
/// let jobs overlap.

final class MediaWorkQueueProvider
    extends $FunctionalProvider<MediaWorkQueue, MediaWorkQueue, MediaWorkQueue>
    with $Provider<MediaWorkQueue> {
  /// The one queue every media job shares. Kept alive: a second queue would
  /// let jobs overlap.
  MediaWorkQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaWorkQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaWorkQueueHash();

  @$internal
  @override
  $ProviderElement<MediaWorkQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaWorkQueue create(Ref ref) {
    return mediaWorkQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaWorkQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaWorkQueue>(value),
    );
  }
}

String _$mediaWorkQueueHash() => r'fa6d6f2412d1d08d735da1882014b600f7121f61';
