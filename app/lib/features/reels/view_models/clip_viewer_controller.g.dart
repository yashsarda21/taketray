// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_viewer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The reels (by name) that clip [clipId] is in, in the order the reels were
/// made, again after every change to the links or a rename.

@ProviderFor(clipReelNames)
final clipReelNamesProvider = ClipReelNamesFamily._();

/// The reels (by name) that clip [clipId] is in, in the order the reels were
/// made, again after every change to the links or a rename.

final class ClipReelNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// The reels (by name) that clip [clipId] is in, in the order the reels were
  /// made, again after every change to the links or a rename.
  ClipReelNamesProvider._({
    required ClipReelNamesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'clipReelNamesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clipReelNamesHash();

  @override
  String toString() {
    return r'clipReelNamesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as int;
    return clipReelNames(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ClipReelNamesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clipReelNamesHash() => r'ca8c3f7a7e2064ac1cdd51a708d37e20d6461082';

/// The reels (by name) that clip [clipId] is in, in the order the reels were
/// made, again after every change to the links or a rename.

final class ClipReelNamesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, int> {
  ClipReelNamesFamily._()
    : super(
        retry: null,
        name: r'clipReelNamesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The reels (by name) that clip [clipId] is in, in the order the reels were
  /// made, again after every change to the links or a rename.

  ClipReelNamesProvider call(int clipId) =>
      ClipReelNamesProvider._(argument: clipId, from: this);

  @override
  String toString() => r'clipReelNamesProvider';
}

@ProviderFor(_reelIdsOf)
final _reelIdsOfProvider = _ReelIdsOfFamily._();

final class _ReelIdsOfProvider
    extends
        $FunctionalProvider<AsyncValue<Set<int>>, Set<int>, Stream<Set<int>>>
    with $FutureModifier<Set<int>>, $StreamProvider<Set<int>> {
  _ReelIdsOfProvider._({
    required _ReelIdsOfFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'_reelIdsOfProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$_reelIdsOfHash();

  @override
  String toString() {
    return r'_reelIdsOfProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Set<int>> create(Ref ref) {
    final argument = this.argument as int;
    return _reelIdsOf(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is _ReelIdsOfProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$_reelIdsOfHash() => r'eaf0ed0aed8f0f94823a2be03dd95de6cac9f61c';

final class _ReelIdsOfFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Set<int>>, int> {
  _ReelIdsOfFamily._()
    : super(
        retry: null,
        name: r'_reelIdsOfProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  _ReelIdsOfProvider call(int clipId) =>
      _ReelIdsOfProvider._(argument: clipId, from: this);

  @override
  String toString() => r'_reelIdsOfProvider';
}

@ProviderFor(_allReels)
final _allReelsProvider = _AllReelsProvider._();

final class _AllReelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reel>>,
          List<Reel>,
          Stream<List<Reel>>
        >
    with $FutureModifier<List<Reel>>, $StreamProvider<List<Reel>> {
  _AllReelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_allReelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_allReelsHash();

  @$internal
  @override
  $StreamProviderElement<List<Reel>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Reel>> create(Ref ref) {
    return _allReels(ref);
  }
}

String _$_allReelsHash() => r'1a4c3242fac725609744ecd4df8f81ee167f5b33';

/// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
///
/// - **The pager is the reel's clips that are not missing**, in the reel's
///   order, from the database's own streams, so it follows every change.
/// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
///   the reel, or the reel is gone, the state is `null` and the screen goes
///   back: it never opens another clip in its place (spec §4, the wrong video
///   is the worst bug).
/// - **It stays on its clip by id.** The index is looked up from the list
///   each time, so a clip joining or leaving elsewhere in the reel does not
///   move the viewer.
/// - **Leaving a clip** (removed or moved here or elsewhere, or turned
///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
///   clip that now stands in its place, the next one, or the one before it
///   when the last was left. With none left the state is `null`: the screen
///   goes back.
/// - **The times never hold it back** (as in D-87): the viewer opens at once,
///   and a clip's time appears when `ClipTimeService` has answered. If
///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
///   screen shows the phone's time (never while they are only loading).
///
/// [goTo] is the page changing. Auto-disposes with the screen.

@ProviderFor(ClipViewerController)
final clipViewerControllerProvider = ClipViewerControllerFamily._();

/// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
///
/// - **The pager is the reel's clips that are not missing**, in the reel's
///   order, from the database's own streams, so it follows every change.
/// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
///   the reel, or the reel is gone, the state is `null` and the screen goes
///   back: it never opens another clip in its place (spec §4, the wrong video
///   is the worst bug).
/// - **It stays on its clip by id.** The index is looked up from the list
///   each time, so a clip joining or leaving elsewhere in the reel does not
///   move the viewer.
/// - **Leaving a clip** (removed or moved here or elsewhere, or turned
///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
///   clip that now stands in its place, the next one, or the one before it
///   when the last was left. With none left the state is `null`: the screen
///   goes back.
/// - **The times never hold it back** (as in D-87): the viewer opens at once,
///   and a clip's time appears when `ClipTimeService` has answered. If
///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
///   screen shows the phone's time (never while they are only loading).
///
/// [goTo] is the page changing. Auto-disposes with the screen.
final class ClipViewerControllerProvider
    extends $AsyncNotifierProvider<ClipViewerController, ClipViewerState?> {
  /// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
  ///
  /// - **The pager is the reel's clips that are not missing**, in the reel's
  ///   order, from the database's own streams, so it follows every change.
  /// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
  ///   the reel, or the reel is gone, the state is `null` and the screen goes
  ///   back: it never opens another clip in its place (spec §4, the wrong video
  ///   is the worst bug).
  /// - **It stays on its clip by id.** The index is looked up from the list
  ///   each time, so a clip joining or leaving elsewhere in the reel does not
  ///   move the viewer.
  /// - **Leaving a clip** (removed or moved here or elsewhere, or turned
  ///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
  ///   clip that now stands in its place, the next one, or the one before it
  ///   when the last was left. With none left the state is `null`: the screen
  ///   goes back.
  /// - **The times never hold it back** (as in D-87): the viewer opens at once,
  ///   and a clip's time appears when `ClipTimeService` has answered. If
  ///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
  ///   screen shows the phone's time (never while they are only loading).
  ///
  /// [goTo] is the page changing. Auto-disposes with the screen.
  ClipViewerControllerProvider._({
    required ClipViewerControllerFamily super.from,
    required (int, int) super.argument,
  }) : super(
         retry: noRetry,
         name: r'clipViewerControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clipViewerControllerHash();

  @override
  String toString() {
    return r'clipViewerControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ClipViewerController create() => ClipViewerController();

  @override
  bool operator ==(Object other) {
    return other is ClipViewerControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clipViewerControllerHash() =>
    r'051b133fe57033aa51a0e4e82ef948da9e52f12a';

/// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
///
/// - **The pager is the reel's clips that are not missing**, in the reel's
///   order, from the database's own streams, so it follows every change.
/// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
///   the reel, or the reel is gone, the state is `null` and the screen goes
///   back: it never opens another clip in its place (spec §4, the wrong video
///   is the worst bug).
/// - **It stays on its clip by id.** The index is looked up from the list
///   each time, so a clip joining or leaving elsewhere in the reel does not
///   move the viewer.
/// - **Leaving a clip** (removed or moved here or elsewhere, or turned
///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
///   clip that now stands in its place, the next one, or the one before it
///   when the last was left. With none left the state is `null`: the screen
///   goes back.
/// - **The times never hold it back** (as in D-87): the viewer opens at once,
///   and a clip's time appears when `ClipTimeService` has answered. If
///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
///   screen shows the phone's time (never while they are only loading).
///
/// [goTo] is the page changing. Auto-disposes with the screen.

final class ClipViewerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ClipViewerController,
          AsyncValue<ClipViewerState?>,
          ClipViewerState?,
          FutureOr<ClipViewerState?>,
          (int, int)
        > {
  ClipViewerControllerFamily._()
    : super(
        retry: noRetry,
        name: r'clipViewerControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
  ///
  /// - **The pager is the reel's clips that are not missing**, in the reel's
  ///   order, from the database's own streams, so it follows every change.
  /// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
  ///   the reel, or the reel is gone, the state is `null` and the screen goes
  ///   back: it never opens another clip in its place (spec §4, the wrong video
  ///   is the worst bug).
  /// - **It stays on its clip by id.** The index is looked up from the list
  ///   each time, so a clip joining or leaving elsewhere in the reel does not
  ///   move the viewer.
  /// - **Leaving a clip** (removed or moved here or elsewhere, or turned
  ///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
  ///   clip that now stands in its place, the next one, or the one before it
  ///   when the last was left. With none left the state is `null`: the screen
  ///   goes back.
  /// - **The times never hold it back** (as in D-87): the viewer opens at once,
  ///   and a clip's time appears when `ClipTimeService` has answered. If
  ///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
  ///   screen shows the phone's time (never while they are only loading).
  ///
  /// [goTo] is the page changing. Auto-disposes with the screen.

  ClipViewerControllerProvider call(int reelId, int clipId) =>
      ClipViewerControllerProvider._(argument: (reelId, clipId), from: this);

  @override
  String toString() => r'clipViewerControllerProvider';
}

/// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
///
/// - **The pager is the reel's clips that are not missing**, in the reel's
///   order, from the database's own streams, so it follows every change.
/// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
///   the reel, or the reel is gone, the state is `null` and the screen goes
///   back: it never opens another clip in its place (spec §4, the wrong video
///   is the worst bug).
/// - **It stays on its clip by id.** The index is looked up from the list
///   each time, so a clip joining or leaving elsewhere in the reel does not
///   move the viewer.
/// - **Leaving a clip** (removed or moved here or elsewhere, or turned
///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
///   clip that now stands in its place, the next one, or the one before it
///   when the last was left. With none left the state is `null`: the screen
///   goes back.
/// - **The times never hold it back** (as in D-87): the viewer opens at once,
///   and a clip's time appears when `ClipTimeService` has answered. If
///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
///   screen shows the phone's time (never while they are only loading).
///
/// [goTo] is the page changing. Auto-disposes with the screen.

abstract class _$ClipViewerController extends $AsyncNotifier<ClipViewerState?> {
  late final _$args = ref.$arg as (int, int);
  int get reelId => _$args.$1;
  int get clipId => _$args.$2;

  FutureOr<ClipViewerState?> build(int reelId, int clipId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ClipViewerState?>, ClipViewerState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ClipViewerState?>, ClipViewerState?>,
              AsyncValue<ClipViewerState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
