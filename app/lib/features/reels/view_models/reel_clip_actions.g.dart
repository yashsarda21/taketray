// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_clip_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reelClipActions)
final reelClipActionsProvider = ReelClipActionsProvider._();

final class ReelClipActionsProvider
    extends
        $FunctionalProvider<ReelClipActions, ReelClipActions, ReelClipActions>
    with $Provider<ReelClipActions> {
  ReelClipActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reelClipActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reelClipActionsHash();

  @$internal
  @override
  $ProviderElement<ReelClipActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReelClipActions create(Ref ref) {
    return reelClipActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReelClipActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReelClipActions>(value),
    );
  }
}

String _$reelClipActionsHash() => r'24b8a796ae56a415a30f07e28e7b393682686f1c';
