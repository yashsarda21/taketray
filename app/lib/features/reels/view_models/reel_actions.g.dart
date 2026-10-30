// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reelActions)
final reelActionsProvider = ReelActionsProvider._();

final class ReelActionsProvider
    extends $FunctionalProvider<ReelActions, ReelActions, ReelActions>
    with $Provider<ReelActions> {
  ReelActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reelActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reelActionsHash();

  @$internal
  @override
  $ProviderElement<ReelActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReelActions create(Ref ref) {
    return reelActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReelActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReelActions>(value),
    );
  }
}

String _$reelActionsHash() => r'45d5b1ebcfecf59ecf4ef57f15160ee3a8a37c04';
