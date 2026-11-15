// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(copyBridge)
final copyBridgeProvider = CopyBridgeProvider._();

final class CopyBridgeProvider
    extends $FunctionalProvider<CopyBridge, CopyBridge, CopyBridge>
    with $Provider<CopyBridge> {
  CopyBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'copyBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$copyBridgeHash();

  @$internal
  @override
  $ProviderElement<CopyBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CopyBridge create(Ref ref) {
    return copyBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CopyBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CopyBridge>(value),
    );
  }
}

String _$copyBridgeHash() => r'e7b21db36e580e4f3a82a75016ad432950c7d9c7';
