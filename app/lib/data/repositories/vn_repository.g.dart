// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vn_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vnRepository)
final vnRepositoryProvider = VnRepositoryProvider._();

final class VnRepositoryProvider
    extends $FunctionalProvider<VnRepository, VnRepository, VnRepository>
    with $Provider<VnRepository> {
  VnRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vnRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vnRepositoryHash();

  @$internal
  @override
  $ProviderElement<VnRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VnRepository create(Ref ref) {
    return vnRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VnRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VnRepository>(value),
    );
  }
}

String _$vnRepositoryHash() => r'047f8258dd977a38b4adb72f55b4cc6e0819bb09';
