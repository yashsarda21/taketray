// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_clips.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clips waiting in To tag, as the database has them, for the Shooting
/// mode card (its count and its backdrop).
///
/// Unlike `ToTagController` it only reads: building it does not scan or
/// verify, so the card on the Reels tab never takes the place of "To tag was
/// opened" (D-76).

@ProviderFor(pendingClips)
final pendingClipsProvider = PendingClipsProvider._();

/// The clips waiting in To tag, as the database has them, for the Shooting
/// mode card (its count and its backdrop).
///
/// Unlike `ToTagController` it only reads: building it does not scan or
/// verify, so the card on the Reels tab never takes the place of "To tag was
/// opened" (D-76).

final class PendingClipsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Clip>>,
          List<Clip>,
          Stream<List<Clip>>
        >
    with $FutureModifier<List<Clip>>, $StreamProvider<List<Clip>> {
  /// The clips waiting in To tag, as the database has them, for the Shooting
  /// mode card (its count and its backdrop).
  ///
  /// Unlike `ToTagController` it only reads: building it does not scan or
  /// verify, so the card on the Reels tab never takes the place of "To tag was
  /// opened" (D-76).
  PendingClipsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingClipsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingClipsHash();

  @$internal
  @override
  $StreamProviderElement<List<Clip>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Clip>> create(Ref ref) {
    return pendingClips(ref);
  }
}

String _$pendingClipsHash() => r'2ad7ae7aa6f19a44eb7baa14a3059bc24836c8a0';

/// How many clips are in Skipped, for To tag's **Skipped ({n})** button
/// (D-98). Only reads, like [pendingClips].

@ProviderFor(skippedCount)
final skippedCountProvider = SkippedCountProvider._();

/// How many clips are in Skipped, for To tag's **Skipped ({n})** button
/// (D-98). Only reads, like [pendingClips].

final class SkippedCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// How many clips are in Skipped, for To tag's **Skipped ({n})** button
  /// (D-98). Only reads, like [pendingClips].
  SkippedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skippedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skippedCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return skippedCount(ref);
  }
}

String _$skippedCountHash() => r'9416815c6f5f68609dfc5aa6855ef6e4cd976c7b';

/// The first stored clip that has a picture (`watchFirstShowableClip`): what
/// the Shooting mode card's backdrop falls back to when no clip waits in To
/// tag, as the prototype does (D-76). Null when there is none.

@ProviderFor(firstShowableClip)
final firstShowableClipProvider = FirstShowableClipProvider._();

/// The first stored clip that has a picture (`watchFirstShowableClip`): what
/// the Shooting mode card's backdrop falls back to when no clip waits in To
/// tag, as the prototype does (D-76). Null when there is none.

final class FirstShowableClipProvider
    extends $FunctionalProvider<AsyncValue<Clip?>, Clip?, Stream<Clip?>>
    with $FutureModifier<Clip?>, $StreamProvider<Clip?> {
  /// The first stored clip that has a picture (`watchFirstShowableClip`): what
  /// the Shooting mode card's backdrop falls back to when no clip waits in To
  /// tag, as the prototype does (D-76). Null when there is none.
  FirstShowableClipProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstShowableClipProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstShowableClipHash();

  @$internal
  @override
  $StreamProviderElement<Clip?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Clip?> create(Ref ref) {
    return firstShowableClip(ref);
  }
}

String _$firstShowableClipHash() => r'627cb81530e7ba13fe37a75c2b9c3fa479efd473';
