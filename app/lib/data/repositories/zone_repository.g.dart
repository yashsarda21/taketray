// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(zoneRepository)
final zoneRepositoryProvider = ZoneRepositoryProvider._();

final class ZoneRepositoryProvider
    extends $FunctionalProvider<ZoneRepository, ZoneRepository, ZoneRepository>
    with $Provider<ZoneRepository> {
  ZoneRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneRepositoryHash();

  @$internal
  @override
  $ProviderElement<ZoneRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ZoneRepository create(Ref ref) {
    return zoneRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ZoneRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ZoneRepository>(value),
    );
  }
}

String _$zoneRepositoryHash() => r'4bf99e3e12c3eb9cd629390634057f0a627b66fa';
