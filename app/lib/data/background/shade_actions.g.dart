// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shade_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one [ShadeActions].

@ProviderFor(shadeActions)
final shadeActionsProvider = ShadeActionsProvider._();

/// The one [ShadeActions].

final class ShadeActionsProvider
    extends $FunctionalProvider<ShadeActions, ShadeActions, ShadeActions>
    with $Provider<ShadeActions> {
  /// The one [ShadeActions].
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

String _$shadeActionsHash() => r'6c0f9089b96c66722df6fc7576c6b9248a8432f6';
