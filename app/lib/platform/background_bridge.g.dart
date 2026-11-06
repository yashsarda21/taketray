// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backgroundBridge)
final backgroundBridgeProvider = BackgroundBridgeProvider._();

final class BackgroundBridgeProvider
    extends
        $FunctionalProvider<
          BackgroundBridge,
          BackgroundBridge,
          BackgroundBridge
        >
    with $Provider<BackgroundBridge> {
  BackgroundBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundBridgeHash();

  @$internal
  @override
  $ProviderElement<BackgroundBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackgroundBridge create(Ref ref) {
    return backgroundBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundBridge>(value),
    );
  }
}

String _$backgroundBridgeHash() => r'c421c1768da1046dd65818e08d97e5a86b1e1809';
