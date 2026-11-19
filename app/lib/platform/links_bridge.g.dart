// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'links_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(linksBridge)
final linksBridgeProvider = LinksBridgeProvider._();

final class LinksBridgeProvider
    extends $FunctionalProvider<LinksBridge, LinksBridge, LinksBridge>
    with $Provider<LinksBridge> {
  LinksBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linksBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linksBridgeHash();

  @$internal
  @override
  $ProviderElement<LinksBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinksBridge create(Ref ref) {
    return linksBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinksBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinksBridge>(value),
    );
  }
}

String _$linksBridgeHash() => r'17a02818dcd63de63d01cf4103e0ba9b2e346884';
