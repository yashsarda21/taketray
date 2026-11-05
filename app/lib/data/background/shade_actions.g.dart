// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shade_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one [ShadeActions]. Kept alive: the apply that calls share lives in
/// it.

@ProviderFor(shadeActions)
final shadeActionsProvider = ShadeActionsProvider._();

/// The one [ShadeActions]. Kept alive: the apply that calls share lives in
/// it.

final class ShadeActionsProvider
    extends $FunctionalProvider<ShadeActions, ShadeActions, ShadeActions>
    with $Provider<ShadeActions> {
  /// The one [ShadeActions]. Kept alive: the apply that calls share lives in
  /// it.
  ShadeActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shadeActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shadeActionsHash();

  @$internal
  @override
  $ProviderElement<ShadeActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShadeActions create(Ref ref) {
    return shadeActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShadeActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShadeActions>(value),
    );
  }
}

String _$shadeActionsHash() => r'76b6ecad00deafa442c32653df208ddc07de4e6e';
