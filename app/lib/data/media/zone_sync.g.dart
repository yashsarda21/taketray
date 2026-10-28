// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(zoneSync)
final zoneSyncProvider = ZoneSyncProvider._();

final class ZoneSyncProvider
    extends $FunctionalProvider<ZoneSync, ZoneSync, ZoneSync>
    with $Provider<ZoneSync> {
  ZoneSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneSyncHash();

  @$internal
  @override
  $ProviderElement<ZoneSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ZoneSync create(Ref ref) {
    return zoneSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ZoneSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ZoneSync>(value),
    );
  }
}

String _$zoneSyncHash() => r'ac22803f2316c084fce62ea04e7c8b7d269cbc32';
