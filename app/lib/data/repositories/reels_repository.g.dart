// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reels_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reelsRepository)
final reelsRepositoryProvider = ReelsRepositoryProvider._();

final class ReelsRepositoryProvider
    extends
        $FunctionalProvider<ReelsRepository, ReelsRepository, ReelsRepository>
    with $Provider<ReelsRepository> {
  ReelsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reelsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reelsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReelsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReelsRepository create(Ref ref) {
    return reelsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReelsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReelsRepository>(value),
    );
  }
}

String _$reelsRepositoryHash() => r'14952861dbae396c1e6563378be140a3b71a812e';
