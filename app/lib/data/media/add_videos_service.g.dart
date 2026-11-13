// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_videos_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The service, on the shared [mediaWorkQueueProvider].

@ProviderFor(addVideosService)
final addVideosServiceProvider = AddVideosServiceProvider._();

/// The service, on the shared [mediaWorkQueueProvider].

final class AddVideosServiceProvider
    extends
        $FunctionalProvider<
          AddVideosService,
          AddVideosService,
          AddVideosService
        >
    with $Provider<AddVideosService> {
  /// The service, on the shared [mediaWorkQueueProvider].
  AddVideosServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addVideosServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addVideosServiceHash();

  @$internal
  @override
  $ProviderElement<AddVideosService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AddVideosService create(Ref ref) {
    return addVideosService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddVideosService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddVideosService>(value),
    );
  }
}

String _$addVideosServiceHash() => r'e71cdf6f6930e208c949c372999a05c32fcf8c5b';
