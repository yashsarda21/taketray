// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The references of reel [reelId], newest first (ties: the highest id
/// first), again after every change (`ReferencesRepository.watchForReel`).

@ProviderFor(reelReferences)
final reelReferencesProvider = ReelReferencesFamily._();

/// The references of reel [reelId], newest first (ties: the highest id
/// first), again after every change (`ReferencesRepository.watchForReel`).

final class ReelReferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReelReference>>,
          List<ReelReference>,
          Stream<List<ReelReference>>
        >
    with
        $FutureModifier<List<ReelReference>>,
        $StreamProvider<List<ReelReference>> {
  /// The references of reel [reelId], newest first (ties: the highest id
  /// first), again after every change (`ReferencesRepository.watchForReel`).
  ReelReferencesProvider._({
    required ReelReferencesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelReferencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelReferencesHash();

  @override
  String toString() {
    return r'reelReferencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ReelReference>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ReelReference>> create(Ref ref) {
    final argument = this.argument as int;
    return reelReferences(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelReferencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelReferencesHash() => r'f49455a4acfa3f57be8b5fda8eb9332a2fe6053c';

/// The references of reel [reelId], newest first (ties: the highest id
/// first), again after every change (`ReferencesRepository.watchForReel`).

final class ReelReferencesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ReelReference>>, int> {
  ReelReferencesFamily._()
    : super(
        retry: null,
        name: r'reelReferencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The references of reel [reelId], newest first (ties: the highest id
  /// first), again after every change (`ReferencesRepository.watchForReel`).

  ReelReferencesProvider call(int reelId) =>
      ReelReferencesProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelReferencesProvider';
}

@ProviderFor(referenceActions)
final referenceActionsProvider = ReferenceActionsProvider._();

final class ReferenceActionsProvider
    extends
        $FunctionalProvider<
          ReferenceActions,
          ReferenceActions,
          ReferenceActions
        >
    with $Provider<ReferenceActions> {
  ReferenceActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referenceActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referenceActionsHash();

  @$internal
  @override
  $ProviderElement<ReferenceActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReferenceActions create(Ref ref) {
    return referenceActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferenceActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferenceActions>(value),
    );
  }
}

String _$referenceActionsHash() => r'47bca522226b3138288cffa570da0f90c1690bdb';
