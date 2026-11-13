// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'picked_grants.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one [PickedGrants] of the app, on the shared [mediaWorkQueueProvider].

@ProviderFor(pickedGrants)
final pickedGrantsProvider = PickedGrantsProvider._();

/// The one [PickedGrants] of the app, on the shared [mediaWorkQueueProvider].

final class PickedGrantsProvider
    extends $FunctionalProvider<PickedGrants, PickedGrants, PickedGrants>
    with $Provider<PickedGrants> {
  /// The one [PickedGrants] of the app, on the shared [mediaWorkQueueProvider].
  PickedGrantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pickedGrantsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pickedGrantsHash();

  @$internal
  @override
  $ProviderElement<PickedGrants> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PickedGrants create(Ref ref) {
    return pickedGrants(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PickedGrants value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PickedGrants>(value),
    );
  }
}

String _$pickedGrantsHash() => r'2e3fa716c6fbffdcc4fbbb5045f43784309c0655';
