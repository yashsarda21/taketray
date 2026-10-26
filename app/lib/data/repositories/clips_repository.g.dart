// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clips_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(clipsRepository)
final clipsRepositoryProvider = ClipsRepositoryProvider._();

final class ClipsRepositoryProvider
    extends
        $FunctionalProvider<ClipsRepository, ClipsRepository, ClipsRepository>
    with $Provider<ClipsRepository> {
  ClipsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ClipsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClipsRepository create(Ref ref) {
    return clipsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipsRepository>(value),
    );
  }
}

String _$clipsRepositoryHash() => r'59937edc859cde977ef1871cf10a8538d9315a20';
