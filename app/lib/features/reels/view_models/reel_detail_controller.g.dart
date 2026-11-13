// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reel [reelId] now and after every change; null once it is gone.

@ProviderFor(reelById)
final reelByIdProvider = ReelByIdFamily._();

/// Reel [reelId] now and after every change; null once it is gone.

final class ReelByIdProvider
    extends $FunctionalProvider<AsyncValue<Reel?>, Reel?, Stream<Reel?>>
    with $FutureModifier<Reel?>, $StreamProvider<Reel?> {
  /// Reel [reelId] now and after every change; null once it is gone.
  ReelByIdProvider._({
    required ReelByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelByIdHash();

  @override
  String toString() {
    return r'reelByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Reel?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Reel?> create(Ref ref) {
    final argument = this.argument as int;
    return reelById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelByIdHash() => r'078e51fd585d9fd1bfa9832a9bcbde05c882253f';

/// Reel [reelId] now and after every change; null once it is gone.

final class ReelByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Reel?>, int> {
  ReelByIdFamily._()
    : super(
        retry: null,
        name: r'reelByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reel [reelId] now and after every change; null once it is gone.

  ReelByIdProvider call(int reelId) =>
      ReelByIdProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelByIdProvider';
}

/// The clips of reel [reelId], oldest first, again after every change.

@ProviderFor(reelClips)
final reelClipsProvider = ReelClipsFamily._();

/// The clips of reel [reelId], oldest first, again after every change.

final class ReelClipsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReelClip>>,
          List<ReelClip>,
          Stream<List<ReelClip>>
        >
    with $FutureModifier<List<ReelClip>>, $StreamProvider<List<ReelClip>> {
  /// The clips of reel [reelId], oldest first, again after every change.
  ReelClipsProvider._({
    required ReelClipsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelClipsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelClipsHash();

  @override
  String toString() {
    return r'reelClipsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ReelClip>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ReelClip>> create(Ref ref) {
    final argument = this.argument as int;
    return reelClips(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelClipsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelClipsHash() => r'2bfd2c1f45bdda79747ac37e167a221d1cc95cec';

/// The clips of reel [reelId], oldest first, again after every change.

final class ReelClipsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ReelClip>>, int> {
  ReelClipsFamily._()
    : super(
        retry: null,
        name: r'reelClipsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The clips of reel [reelId], oldest first, again after every change.

  ReelClipsProvider call(int reelId) =>
      ReelClipsProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelClipsProvider';
}

/// The time where each clip of reel [reelId] was shot, by clip id (D-83).
///
/// It follows the reel's clips: each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws.

@ProviderFor(reelClipTimes)
final reelClipTimesProvider = ReelClipTimesFamily._();

/// The time where each clip of reel [reelId] was shot, by clip id (D-83).
///
/// It follows the reel's clips: each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws.

final class ReelClipTimesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, ClipLocalTime>>,
          Map<int, ClipLocalTime>,
          FutureOr<Map<int, ClipLocalTime>>
        >
    with
        $FutureModifier<Map<int, ClipLocalTime>>,
        $FutureProvider<Map<int, ClipLocalTime>> {
  /// The time where each clip of reel [reelId] was shot, by clip id (D-83).
  ///
  /// It follows the reel's clips: each new list asks
  /// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
  /// so only new ones cost a bridge entry. The service never throws.
  ReelClipTimesProvider._({
    required ReelClipTimesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelClipTimesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelClipTimesHash();

  @override
  String toString() {
    return r'reelClipTimesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, ClipLocalTime>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, ClipLocalTime>> create(Ref ref) {
    final argument = this.argument as int;
    return reelClipTimes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelClipTimesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelClipTimesHash() => r'248282a033470c6af569bf2047d7ef1672cfd626';

/// The time where each clip of reel [reelId] was shot, by clip id (D-83).
///
/// It follows the reel's clips: each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws.

final class ReelClipTimesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<int, ClipLocalTime>>, int> {
  ReelClipTimesFamily._()
    : super(
        retry: null,
        name: r'reelClipTimesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The time where each clip of reel [reelId] was shot, by clip id (D-83).
  ///
  /// It follows the reel's clips: each new list asks
  /// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
  /// so only new ones cost a bridge entry. The service never throws.

  ReelClipTimesProvider call(int reelId) =>
      ReelClipTimesProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelClipTimesProvider';
}

/// The page of one reel (D-87): the reel, its clips by shooting day, and the
/// counts of its header.
///
/// - **The state is the database's own** (`watchById`, `watchReelClips`), so
///   it shows at once and follows every change: a rename, a status change, a
///   clip added or removed, a verify that finds a video gone.
/// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
///   that never existed); the screen then goes to Reels. While the first read
///   runs the state is loading.
/// - **The times never hold the clips back.** The days are grouped, and the
///   tiles drawn, with the phone's own time zone until
///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
///   is built again, regrouped by the day where each clip was shot, and
///   [ReelDetailState.times] has the times. A clip whose time is not known
///   yet (a new one while the list's times are read) uses the phone's.
/// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
///   reel is shown"): once per open, through `MediaVerifier` on the shared
///   media queue (D-72), so full access only, and an error never means
///   missing. It never blocks the list and cannot fail it: an error is logged
///   by type. A clip whose video is gone is flagged, the list emits again,
///   and the tile turns into the missing tile. A later change of the list
///   (or of the times) does not verify again; opening the reel again does.
/// - **Opening the reel checks its copies** (D-128): once per open,
///   `EditSessionService.verifyCopies` forgets the copies of the reel's
///   editing session whose files were deleted outside TakeTray, so their
///   clips show under "New since you started editing" again. A reel with no
///   session asks the phone nothing. Like the verify, it never blocks or
///   fails the page: an error is logged by type and the copies stay as they
///   were.

@ProviderFor(ReelDetailController)
final reelDetailControllerProvider = ReelDetailControllerFamily._();

/// The page of one reel (D-87): the reel, its clips by shooting day, and the
/// counts of its header.
///
/// - **The state is the database's own** (`watchById`, `watchReelClips`), so
///   it shows at once and follows every change: a rename, a status change, a
///   clip added or removed, a verify that finds a video gone.
/// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
///   that never existed); the screen then goes to Reels. While the first read
///   runs the state is loading.
/// - **The times never hold the clips back.** The days are grouped, and the
///   tiles drawn, with the phone's own time zone until
///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
///   is built again, regrouped by the day where each clip was shot, and
///   [ReelDetailState.times] has the times. A clip whose time is not known
///   yet (a new one while the list's times are read) uses the phone's.
/// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
///   reel is shown"): once per open, through `MediaVerifier` on the shared
///   media queue (D-72), so full access only, and an error never means
///   missing. It never blocks the list and cannot fail it: an error is logged
///   by type. A clip whose video is gone is flagged, the list emits again,
///   and the tile turns into the missing tile. A later change of the list
///   (or of the times) does not verify again; opening the reel again does.
/// - **Opening the reel checks its copies** (D-128): once per open,
///   `EditSessionService.verifyCopies` forgets the copies of the reel's
///   editing session whose files were deleted outside TakeTray, so their
///   clips show under "New since you started editing" again. A reel with no
///   session asks the phone nothing. Like the verify, it never blocks or
///   fails the page: an error is logged by type and the copies stay as they
///   were.
final class ReelDetailControllerProvider
    extends $AsyncNotifierProvider<ReelDetailController, ReelDetailState?> {
  /// The page of one reel (D-87): the reel, its clips by shooting day, and the
  /// counts of its header.
  ///
  /// - **The state is the database's own** (`watchById`, `watchReelClips`), so
  ///   it shows at once and follows every change: a rename, a status change, a
  ///   clip added or removed, a verify that finds a video gone.
  /// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
  ///   that never existed); the screen then goes to Reels. While the first read
  ///   runs the state is loading.
  /// - **The times never hold the clips back.** The days are grouped, and the
  ///   tiles drawn, with the phone's own time zone until
  ///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
  ///   is built again, regrouped by the day where each clip was shot, and
  ///   [ReelDetailState.times] has the times. A clip whose time is not known
  ///   yet (a new one while the list's times are read) uses the phone's.
  /// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
  ///   reel is shown"): once per open, through `MediaVerifier` on the shared
  ///   media queue (D-72), so full access only, and an error never means
  ///   missing. It never blocks the list and cannot fail it: an error is logged
  ///   by type. A clip whose video is gone is flagged, the list emits again,
  ///   and the tile turns into the missing tile. A later change of the list
  ///   (or of the times) does not verify again; opening the reel again does.
  /// - **Opening the reel checks its copies** (D-128): once per open,
  ///   `EditSessionService.verifyCopies` forgets the copies of the reel's
  ///   editing session whose files were deleted outside TakeTray, so their
  ///   clips show under "New since you started editing" again. A reel with no
  ///   session asks the phone nothing. Like the verify, it never blocks or
  ///   fails the page: an error is logged by type and the copies stay as they
  ///   were.
  ReelDetailControllerProvider._({
    required ReelDetailControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: noRetry,
         name: r'reelDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelDetailControllerHash();

  @override
  String toString() {
    return r'reelDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReelDetailController create() => ReelDetailController();

  @override
  bool operator ==(Object other) {
    return other is ReelDetailControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelDetailControllerHash() =>
    r'370ae572512cd2ca174ad862994caa0b86619849';

/// The page of one reel (D-87): the reel, its clips by shooting day, and the
/// counts of its header.
///
/// - **The state is the database's own** (`watchById`, `watchReelClips`), so
///   it shows at once and follows every change: a rename, a status change, a
///   clip added or removed, a verify that finds a video gone.
/// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
///   that never existed); the screen then goes to Reels. While the first read
///   runs the state is loading.
/// - **The times never hold the clips back.** The days are grouped, and the
///   tiles drawn, with the phone's own time zone until
///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
///   is built again, regrouped by the day where each clip was shot, and
///   [ReelDetailState.times] has the times. A clip whose time is not known
///   yet (a new one while the list's times are read) uses the phone's.
/// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
///   reel is shown"): once per open, through `MediaVerifier` on the shared
///   media queue (D-72), so full access only, and an error never means
///   missing. It never blocks the list and cannot fail it: an error is logged
///   by type. A clip whose video is gone is flagged, the list emits again,
///   and the tile turns into the missing tile. A later change of the list
///   (or of the times) does not verify again; opening the reel again does.
/// - **Opening the reel checks its copies** (D-128): once per open,
///   `EditSessionService.verifyCopies` forgets the copies of the reel's
///   editing session whose files were deleted outside TakeTray, so their
///   clips show under "New since you started editing" again. A reel with no
///   session asks the phone nothing. Like the verify, it never blocks or
///   fails the page: an error is logged by type and the copies stay as they
///   were.

final class ReelDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ReelDetailController,
          AsyncValue<ReelDetailState?>,
          ReelDetailState?,
          FutureOr<ReelDetailState?>,
          int
        > {
  ReelDetailControllerFamily._()
    : super(
        retry: noRetry,
        name: r'reelDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The page of one reel (D-87): the reel, its clips by shooting day, and the
  /// counts of its header.
  ///
  /// - **The state is the database's own** (`watchById`, `watchReelClips`), so
  ///   it shows at once and follows every change: a rename, a status change, a
  ///   clip added or removed, a verify that finds a video gone.
  /// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
  ///   that never existed); the screen then goes to Reels. While the first read
  ///   runs the state is loading.
  /// - **The times never hold the clips back.** The days are grouped, and the
  ///   tiles drawn, with the phone's own time zone until
  ///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
  ///   is built again, regrouped by the day where each clip was shot, and
  ///   [ReelDetailState.times] has the times. A clip whose time is not known
  ///   yet (a new one while the list's times are read) uses the phone's.
  /// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
  ///   reel is shown"): once per open, through `MediaVerifier` on the shared
  ///   media queue (D-72), so full access only, and an error never means
  ///   missing. It never blocks the list and cannot fail it: an error is logged
  ///   by type. A clip whose video is gone is flagged, the list emits again,
  ///   and the tile turns into the missing tile. A later change of the list
  ///   (or of the times) does not verify again; opening the reel again does.
  /// - **Opening the reel checks its copies** (D-128): once per open,
  ///   `EditSessionService.verifyCopies` forgets the copies of the reel's
  ///   editing session whose files were deleted outside TakeTray, so their
  ///   clips show under "New since you started editing" again. A reel with no
  ///   session asks the phone nothing. Like the verify, it never blocks or
  ///   fails the page: an error is logged by type and the copies stay as they
  ///   were.

  ReelDetailControllerProvider call(int reelId) =>
      ReelDetailControllerProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelDetailControllerProvider';
}

/// The page of one reel (D-87): the reel, its clips by shooting day, and the
/// counts of its header.
///
/// - **The state is the database's own** (`watchById`, `watchReelClips`), so
///   it shows at once and follows every change: a rename, a status change, a
///   clip added or removed, a verify that finds a video gone.
/// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
///   that never existed); the screen then goes to Reels. While the first read
///   runs the state is loading.
/// - **The times never hold the clips back.** The days are grouped, and the
///   tiles drawn, with the phone's own time zone until
///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
///   is built again, regrouped by the day where each clip was shot, and
///   [ReelDetailState.times] has the times. A clip whose time is not known
///   yet (a new one while the list's times are read) uses the phone's.
/// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
///   reel is shown"): once per open, through `MediaVerifier` on the shared
///   media queue (D-72), so full access only, and an error never means
///   missing. It never blocks the list and cannot fail it: an error is logged
///   by type. A clip whose video is gone is flagged, the list emits again,
///   and the tile turns into the missing tile. A later change of the list
///   (or of the times) does not verify again; opening the reel again does.
/// - **Opening the reel checks its copies** (D-128): once per open,
///   `EditSessionService.verifyCopies` forgets the copies of the reel's
///   editing session whose files were deleted outside TakeTray, so their
///   clips show under "New since you started editing" again. A reel with no
///   session asks the phone nothing. Like the verify, it never blocks or
///   fails the page: an error is logged by type and the copies stay as they
///   were.

abstract class _$ReelDetailController extends $AsyncNotifier<ReelDetailState?> {
  late final _$args = ref.$arg as int;
  int get reelId => _$args;

  FutureOr<ReelDetailState?> build(int reelId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReelDetailState?>, ReelDetailState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReelDetailState?>, ReelDetailState?>,
              AsyncValue<ReelDetailState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
