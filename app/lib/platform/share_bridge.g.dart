// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(shareBridge)
final shareBridgeProvider = ShareBridgeProvider._();

final class ShareBridgeProvider
    extends $FunctionalProvider<ShareBridge, ShareBridge, ShareBridge>
    with $Provider<ShareBridge> {
  ShareBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareBridgeHash();

  @$internal
  @override
  $ProviderElement<ShareBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShareBridge create(Ref ref) {
    return shareBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareBridge>(value),
    );
  }
}

String _$shareBridgeHash() => r'9b61f812b3bb25cfc7451c318f9234340b2355d1';
