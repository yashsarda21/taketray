// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_session_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(editSessionService)
final editSessionServiceProvider = EditSessionServiceProvider._();

final class EditSessionServiceProvider
    extends
        $FunctionalProvider<
          EditSessionService,
          EditSessionService,
          EditSessionService
        >
    with $Provider<EditSessionService> {
  EditSessionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editSessionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editSessionServiceHash();

  @$internal
  @override
  $ProviderElement<EditSessionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EditSessionService create(Ref ref) {
    return editSessionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditSessionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditSessionService>(value),
    );
  }
}

String _$editSessionServiceHash() =>
    r'2e1f29ec504647b591949b58347a11fa658de4b0';
