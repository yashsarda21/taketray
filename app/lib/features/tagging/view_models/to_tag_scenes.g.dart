// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'to_tag_scenes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The waiting clips grouped into scenes (D-95), for To tag: null until the
/// list has been read (loading, or it could not be).
///
/// Each clip is placed by the time where it was shot (D-83), but **the scenes
/// never wait for those times**: until `toTagTimesProvider` has an answer (or
/// when it fails) a clip uses the phone's time, so the list is on screen at
/// once and regroups, in place, when the times arrive.

@ProviderFor(toTagScenes)
final toTagScenesProvider = ToTagScenesProvider._();

/// The waiting clips grouped into scenes (D-95), for To tag: null until the
/// list has been read (loading, or it could not be).
///
/// Each clip is placed by the time where it was shot (D-83), but **the scenes
/// never wait for those times**: until `toTagTimesProvider` has an answer (or
/// when it fails) a clip uses the phone's time, so the list is on screen at
/// once and regroups, in place, when the times arrive.

final class ToTagScenesProvider
    extends $FunctionalProvider<List<Scene>?, List<Scene>?, List<Scene>?>
    with $Provider<List<Scene>?> {
  /// The waiting clips grouped into scenes (D-95), for To tag: null until the
  /// list has been read (loading, or it could not be).
  ///
  /// Each clip is placed by the time where it was shot (D-83), but **the scenes
  /// never wait for those times**: until `toTagTimesProvider` has an answer (or
  /// when it fails) a clip uses the phone's time, so the list is on screen at
  /// once and regroups, in place, when the times arrive.
  ToTagScenesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toTagScenesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toTagScenesHash();

  @$internal
  @override
  $ProviderElement<List<Scene>?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Scene>? create(Ref ref) {
    return toTagScenes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Scene>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Scene>?>(value),
    );
  }
}

String _$toTagScenesHash() => r'27bd33bf7b9c4e4683d274090608843ed635aa5d';
