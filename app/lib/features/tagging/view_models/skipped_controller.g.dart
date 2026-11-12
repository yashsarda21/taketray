// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skipped_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clips in Skipped, **newest first** (D-99).
///
/// The state is the database's own list (`watchInbox(skipped)`, reversed), so
/// it shows at once and follows every change: a restore, a clip tagged
/// elsewhere, a verify that removes a clip whose video is gone.
///
/// Each time the state is built (the screen opens it) it also checks, once,
/// that the skipped clips still exist (D-72): a clip that is only in Skipped
/// and whose video is gone leaves the list. The check never blocks the list
/// and cannot fail it; an error is logged by type and the list stays as the
/// database has it. It runs on the shared media queue, so it never overlaps a
/// scan. (Unlike To tag it does not scan: a scan adds to To tag, and this
/// screen has nothing to do with new videos.)

@ProviderFor(SkippedController)
final skippedControllerProvider = SkippedControllerProvider._();

/// The clips in Skipped, **newest first** (D-99).
///
/// The state is the database's own list (`watchInbox(skipped)`, reversed), so
/// it shows at once and follows every change: a restore, a clip tagged
/// elsewhere, a verify that removes a clip whose video is gone.
///
/// Each time the state is built (the screen opens it) it also checks, once,
/// that the skipped clips still exist (D-72): a clip that is only in Skipped
/// and whose video is gone leaves the list. The check never blocks the list
/// and cannot fail it; an error is logged by type and the list stays as the
/// database has it. It runs on the shared media queue, so it never overlaps a
/// scan. (Unlike To tag it does not scan: a scan adds to To tag, and this
/// screen has nothing to do with new videos.)
final class SkippedControllerProvider
    extends $StreamNotifierProvider<SkippedController, List<Clip>> {
  /// The clips in Skipped, **newest first** (D-99).
  ///
  /// The state is the database's own list (`watchInbox(skipped)`, reversed), so
  /// it shows at once and follows every change: a restore, a clip tagged
  /// elsewhere, a verify that removes a clip whose video is gone.
  ///
  /// Each time the state is built (the screen opens it) it also checks, once,
  /// that the skipped clips still exist (D-72): a clip that is only in Skipped
  /// and whose video is gone leaves the list. The check never blocks the list
  /// and cannot fail it; an error is logged by type and the list stays as the
  /// database has it. It runs on the shared media queue, so it never overlaps a
  /// scan. (Unlike To tag it does not scan: a scan adds to To tag, and this
  /// screen has nothing to do with new videos.)
  SkippedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'skippedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skippedControllerHash();

  @$internal
  @override
  SkippedController create() => SkippedController();
}

String _$skippedControllerHash() => r'b5fc654cd9f884f32c2a02ac9c5f606319e59574';

/// The clips in Skipped, **newest first** (D-99).
///
/// The state is the database's own list (`watchInbox(skipped)`, reversed), so
/// it shows at once and follows every change: a restore, a clip tagged
/// elsewhere, a verify that removes a clip whose video is gone.
///
/// Each time the state is built (the screen opens it) it also checks, once,
/// that the skipped clips still exist (D-72): a clip that is only in Skipped
/// and whose video is gone leaves the list. The check never blocks the list
/// and cannot fail it; an error is logged by type and the list stays as the
/// database has it. It runs on the shared media queue, so it never overlaps a
/// scan. (Unlike To tag it does not scan: a scan adds to To tag, and this
/// screen has nothing to do with new videos.)

abstract class _$SkippedController extends $StreamNotifier<List<Clip>> {
  Stream<List<Clip>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Clip>>, List<Clip>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Clip>>, List<Clip>>,
              AsyncValue<List<Clip>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The time where each skipped clip was shot, by clip id (D-83): the day
/// headers and the tiles' times. Follows the list; the service's cache
/// answers the clips it has seen. A clip missing from the map (a list that
/// arrived while its times are still being read) uses the phone's time.

@ProviderFor(skippedTimes)
final skippedTimesProvider = SkippedTimesProvider._();

/// The time where each skipped clip was shot, by clip id (D-83): the day
/// headers and the tiles' times. Follows the list; the service's cache
/// answers the clips it has seen. A clip missing from the map (a list that
/// arrived while its times are still being read) uses the phone's time.

final class SkippedTimesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, ClipLocalTime>>,
          Map<int, ClipLocalTime>,
          FutureOr<Map<int, ClipLocalTime>>
        >
    with
        $FutureModifier<Map<int, ClipLocalTime>>,
        $FutureProvider<Map<int, ClipLocalTime>> {
  /// The time where each skipped clip was shot, by clip id (D-83): the day
  /// headers and the tiles' times. Follows the list; the service's cache
  /// answers the clips it has seen. A clip missing from the map (a list that
  /// arrived while its times are still being read) uses the phone's time.
  SkippedTimesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skippedTimesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skippedTimesHash();

  @$internal
  @override
  $FutureProviderElement<Map<int, ClipLocalTime>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, ClipLocalTime>> create(Ref ref) {
    return skippedTimes(ref);
  }
}

String _$skippedTimesHash() => r'58bb54f4a5a912b113851604329285f1e21747e3';

/// The skipped clips cut into days, newest day first (`groupIntoDays`): null
/// until the list has been read (loading, or it could not be). Like To tag's
/// scenes it **never waits for the times**: a clip whose time is not known
/// yet uses the phone's, and the days regroup in place when the answer
/// arrives.

@ProviderFor(skippedDays)
final skippedDaysProvider = SkippedDaysProvider._();

/// The skipped clips cut into days, newest day first (`groupIntoDays`): null
/// until the list has been read (loading, or it could not be). Like To tag's
/// scenes it **never waits for the times**: a clip whose time is not known
/// yet uses the phone's, and the days regroup in place when the answer
/// arrives.

final class SkippedDaysProvider
    extends
        $FunctionalProvider<
          List<SkippedDay>?,
          List<SkippedDay>?,
          List<SkippedDay>?
        >
    with $Provider<List<SkippedDay>?> {
  /// The skipped clips cut into days, newest day first (`groupIntoDays`): null
  /// until the list has been read (loading, or it could not be). Like To tag's
  /// scenes it **never waits for the times**: a clip whose time is not known
  /// yet uses the phone's, and the days regroup in place when the answer
  /// arrives.
  SkippedDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skippedDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skippedDaysHash();

  @$internal
  @override
  $ProviderElement<List<SkippedDay>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SkippedDay>? create(Ref ref) {
    return skippedDays(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SkippedDay>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SkippedDay>?>(value),
    );
  }
}

String _$skippedDaysHash() => r'a06cf07b50684c3592d5f09ebd74ea6b17d31dad';
