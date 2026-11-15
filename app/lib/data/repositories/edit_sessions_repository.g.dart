// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_sessions_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(editSessionsRepository)
final editSessionsRepositoryProvider = EditSessionsRepositoryProvider._();

final class EditSessionsRepositoryProvider
    extends
        $FunctionalProvider<
          EditSessionsRepository,
          EditSessionsRepository,
          EditSessionsRepository
        >
    with $Provider<EditSessionsRepository> {
  EditSessionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editSessionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editSessionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<EditSessionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EditSessionsRepository create(Ref ref) {
    return editSessionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditSessionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditSessionsRepository>(value),
    );
  }
}

String _$editSessionsRepositoryHash() =>
    r'3d2e0e0677d11e24d4b29c35a5d0aa01c5bec444';
