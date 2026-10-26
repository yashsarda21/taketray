// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'references_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(referencesRepository)
final referencesRepositoryProvider = ReferencesRepositoryProvider._();

final class ReferencesRepositoryProvider
    extends
        $FunctionalProvider<
          ReferencesRepository,
          ReferencesRepository,
          ReferencesRepository
        >
    with $Provider<ReferencesRepository> {
  ReferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReferencesRepository create(Ref ref) {
    return referencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferencesRepository>(value),
    );
  }
}

String _$referencesRepositoryHash() =>
    r'6307e8a725db18a92ad375160bd9f8cd21a454e3';
