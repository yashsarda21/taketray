// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaBridge)
final mediaBridgeProvider = MediaBridgeProvider._();

final class MediaBridgeProvider
    extends $FunctionalProvider<MediaBridge, MediaBridge, MediaBridge>
    with $Provider<MediaBridge> {
  MediaBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaBridgeHash();

  @$internal
  @override
  $ProviderElement<MediaBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaBridge create(Ref ref) {
    return mediaBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaBridge>(value),
    );
  }
}

String _$mediaBridgeHash() => r'c3fe5accab4ad9e0aa0b26def2057fed60978a29';
