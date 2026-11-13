// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_job_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The copy job the copy screens follow (D-123): the engine's job, or the
/// one `EditSessionService` built itself (the interrupted job a restart
/// recovered, a resumed job that finished at once, a recovered job that was
/// cancelled). Null when there is none.
///
/// It follows the engine's `changes` and the service's `localJobs`, and
/// reads the engine's job when it is built and on [onResume] (the engine
/// drops its events while no Dart side listens, D-122). For each engine
/// event with a new finished file (or undeleted file, or a new end state) it
/// calls `EditSessionService.applyJob`, which records the copies; progress
/// alone records nothing. An event of an older job than the one held (job ids
/// are `<reelId>-<UTC ms>`) is ignored.
///
/// Kept alive: the app's start builds it (`MediaLifecycle`), so a job is
/// followed and recorded whether or not a copy screen is open.

@ProviderFor(CopyJobController)
final copyJobControllerProvider = CopyJobControllerProvider._();

/// The copy job the copy screens follow (D-123): the engine's job, or the
/// one `EditSessionService` built itself (the interrupted job a restart
/// recovered, a resumed job that finished at once, a recovered job that was
/// cancelled). Null when there is none.
///
/// It follows the engine's `changes` and the service's `localJobs`, and
/// reads the engine's job when it is built and on [onResume] (the engine
/// drops its events while no Dart side listens, D-122). For each engine
/// event with a new finished file (or undeleted file, or a new end state) it
/// calls `EditSessionService.applyJob`, which records the copies; progress
/// alone records nothing. An event of an older job than the one held (job ids
/// are `<reelId>-<UTC ms>`) is ignored.
///
/// Kept alive: the app's start builds it (`MediaLifecycle`), so a job is
/// followed and recorded whether or not a copy screen is open.
final class CopyJobControllerProvider
    extends $NotifierProvider<CopyJobController, CopyJob?> {
  /// The copy job the copy screens follow (D-123): the engine's job, or the
  /// one `EditSessionService` built itself (the interrupted job a restart
  /// recovered, a resumed job that finished at once, a recovered job that was
  /// cancelled). Null when there is none.
  ///
  /// It follows the engine's `changes` and the service's `localJobs`, and
  /// reads the engine's job when it is built and on [onResume] (the engine
  /// drops its events while no Dart side listens, D-122). For each engine
  /// event with a new finished file (or undeleted file, or a new end state) it
  /// calls `EditSessionService.applyJob`, which records the copies; progress
  /// alone records nothing. An event of an older job than the one held (job ids
  /// are `<reelId>-<UTC ms>`) is ignored.
  ///
  /// Kept alive: the app's start builds it (`MediaLifecycle`), so a job is
  /// followed and recorded whether or not a copy screen is open.
  CopyJobControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'copyJobControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$copyJobControllerHash();

  @$internal
  @override
  CopyJobController create() => CopyJobController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CopyJob? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CopyJob?>(value),
    );
  }
}

String _$copyJobControllerHash() => r'a037aa0d4fbfa7ec857da1aa0ce58370c080a019';

/// The copy job the copy screens follow (D-123): the engine's job, or the
/// one `EditSessionService` built itself (the interrupted job a restart
/// recovered, a resumed job that finished at once, a recovered job that was
/// cancelled). Null when there is none.
///
/// It follows the engine's `changes` and the service's `localJobs`, and
/// reads the engine's job when it is built and on [onResume] (the engine
/// drops its events while no Dart side listens, D-122). For each engine
/// event with a new finished file (or undeleted file, or a new end state) it
/// calls `EditSessionService.applyJob`, which records the copies; progress
/// alone records nothing. An event of an older job than the one held (job ids
/// are `<reelId>-<UTC ms>`) is ignored.
///
/// Kept alive: the app's start builds it (`MediaLifecycle`), so a job is
/// followed and recorded whether or not a copy screen is open.

abstract class _$CopyJobController extends $Notifier<CopyJob?> {
  CopyJob? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CopyJob?, CopyJob?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CopyJob?, CopyJob?>,
              CopyJob?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
