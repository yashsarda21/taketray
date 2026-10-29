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
