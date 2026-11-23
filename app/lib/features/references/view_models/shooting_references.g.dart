// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shooting_references.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every reference of every reel, newest first, again after every change
/// (`ReferencesRepository.watchAll`).

@ProviderFor(allReferences)
final allReferencesProvider = AllReferencesProvider._();

/// Every reference of every reel, newest first, again after every change
/// (`ReferencesRepository.watchAll`).

final class AllReferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReelReference>>,
          List<ReelReference>,
          Stream<List<ReelReference>>
        >
    with
        $FutureModifier<List<ReelReference>>,
        $StreamProvider<List<ReelReference>> {
  /// Every reference of every reel, newest first, again after every change
  /// (`ReferencesRepository.watchAll`).
  AllReferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allReferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allReferencesHash();

  @$internal
  @override
  $StreamProviderElement<List<ReelReference>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ReelReference>> create(Ref ref) {
    return allReferences(ref);
  }
}

String _$allReferencesHash() => r'0af1461b0ea9cfa2530d8d2d2f8459e9f61cf423';

/// The References of the Collecting and Ready to edit reels, grouped by reel
/// (D-160), again after every change to reels, clips or references.
///
/// The reels come from `reelSummariesProvider`, Home's own stream, so the
/// order within a status is Home's. The Shooting mode card's row and the sheet
/// both read it.

@ProviderFor(shootingReferences)
final shootingReferencesProvider = ShootingReferencesProvider._();

/// The References of the Collecting and Ready to edit reels, grouped by reel
/// (D-160), again after every change to reels, clips or references.
///
/// The reels come from `reelSummariesProvider`, Home's own stream, so the
/// order within a status is Home's. The Shooting mode card's row and the sheet
/// both read it.

final class ShootingReferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReferenceGroup>>,
          List<ReferenceGroup>,
          Stream<List<ReferenceGroup>>
        >
    with
        $FutureModifier<List<ReferenceGroup>>,
        $StreamProvider<List<ReferenceGroup>> {
  /// The References of the Collecting and Ready to edit reels, grouped by reel
  /// (D-160), again after every change to reels, clips or references.
  ///
  /// The reels come from `reelSummariesProvider`, Home's own stream, so the
  /// order within a status is Home's. The Shooting mode card's row and the sheet
  /// both read it.
  ShootingReferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shootingReferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shootingReferencesHash();

  @$internal
  @override
  $StreamProviderElement<List<ReferenceGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ReferenceGroup>> create(Ref ref) {
    return shootingReferences(ref);
  }
}

String _$shootingReferencesHash() =>
    r'e61942251fdf337ba7ffaf02c6ad84b2b7c87305';
