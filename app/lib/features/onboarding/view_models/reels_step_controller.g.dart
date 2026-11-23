// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reels_step_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The reels step of onboarding (D-141): the names the user plans, checked
/// with the reel form's rules, then made in one go.
///
/// - **[add]** trims the name, then refuses it as `empty`, `tooLong` or
///   `duplicate` (a name in the list or an existing reel, ignoring case and
///   edge spaces, [reelNameKey]); the state says why.
/// - **[create]** makes every name with one `createAll` (all or none), and only
///   then calls `finish()`. A second call while it runs, or once it is done,
///   does nothing. A reel made elsewhere meanwhile is shown as a duplicate and
///   nothing is finished; any other failure is `failed`.
/// - **existing reels** are read live from `ReelsRepository.watchAll` and
///   `ReferencesRepository.watchCounts` and shown oldest first with their
///   reference counts (D-168). Nothing shows until both have answered, so a
///   reel never appears with a count that is about to change; a count read
///   that fails counts as none. A count read that has not answered within
///   [stepReadLimit] is taken as none too (logged), so the rows, the duplicate
///   check and "Continue" never wait for it for good; the counts that arrive
///   later update the rows.
/// - **[skip]** (also the "Continue" of a phone that already has reels) calls
///   `finish()` and writes no reel.
///
/// A phone killed after the reels were made and before onboarding was marked
/// done opens this step again: the reels exist, so the step offers
/// "Continue", and typing the same names is refused as a duplicate, so one
/// Create never makes a second set.

@ProviderFor(ReelsStepController)
final reelsStepControllerProvider = ReelsStepControllerProvider._();

/// The reels step of onboarding (D-141): the names the user plans, checked
/// with the reel form's rules, then made in one go.
///
/// - **[add]** trims the name, then refuses it as `empty`, `tooLong` or
///   `duplicate` (a name in the list or an existing reel, ignoring case and
///   edge spaces, [reelNameKey]); the state says why.
/// - **[create]** makes every name with one `createAll` (all or none), and only
///   then calls `finish()`. A second call while it runs, or once it is done,
///   does nothing. A reel made elsewhere meanwhile is shown as a duplicate and
///   nothing is finished; any other failure is `failed`.
/// - **existing reels** are read live from `ReelsRepository.watchAll` and
///   `ReferencesRepository.watchCounts` and shown oldest first with their
///   reference counts (D-168). Nothing shows until both have answered, so a
///   reel never appears with a count that is about to change; a count read
///   that fails counts as none. A count read that has not answered within
///   [stepReadLimit] is taken as none too (logged), so the rows, the duplicate
///   check and "Continue" never wait for it for good; the counts that arrive
///   later update the rows.
/// - **[skip]** (also the "Continue" of a phone that already has reels) calls
///   `finish()` and writes no reel.
///
/// A phone killed after the reels were made and before onboarding was marked
/// done opens this step again: the reels exist, so the step offers
/// "Continue", and typing the same names is refused as a duplicate, so one
/// Create never makes a second set.
final class ReelsStepControllerProvider
    extends $NotifierProvider<ReelsStepController, ReelsStepState> {
  /// The reels step of onboarding (D-141): the names the user plans, checked
  /// with the reel form's rules, then made in one go.
  ///
  /// - **[add]** trims the name, then refuses it as `empty`, `tooLong` or
  ///   `duplicate` (a name in the list or an existing reel, ignoring case and
  ///   edge spaces, [reelNameKey]); the state says why.
  /// - **[create]** makes every name with one `createAll` (all or none), and only
  ///   then calls `finish()`. A second call while it runs, or once it is done,
  ///   does nothing. A reel made elsewhere meanwhile is shown as a duplicate and
  ///   nothing is finished; any other failure is `failed`.
  /// - **existing reels** are read live from `ReelsRepository.watchAll` and
  ///   `ReferencesRepository.watchCounts` and shown oldest first with their
  ///   reference counts (D-168). Nothing shows until both have answered, so a
  ///   reel never appears with a count that is about to change; a count read
  ///   that fails counts as none. A count read that has not answered within
  ///   [stepReadLimit] is taken as none too (logged), so the rows, the duplicate
  ///   check and "Continue" never wait for it for good; the counts that arrive
  ///   later update the rows.
  /// - **[skip]** (also the "Continue" of a phone that already has reels) calls
  ///   `finish()` and writes no reel.
  ///
  /// A phone killed after the reels were made and before onboarding was marked
  /// done opens this step again: the reels exist, so the step offers
  /// "Continue", and typing the same names is refused as a duplicate, so one
  /// Create never makes a second set.
  ReelsStepControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reelsStepControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reelsStepControllerHash();

  @$internal
  @override
  ReelsStepController create() => ReelsStepController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReelsStepState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReelsStepState>(value),
    );
  }
}

String _$reelsStepControllerHash() =>
    r'8d85a366996e9fdc3f5da777fa583f1a0a8edaeb';

/// The reels step of onboarding (D-141): the names the user plans, checked
/// with the reel form's rules, then made in one go.
///
/// - **[add]** trims the name, then refuses it as `empty`, `tooLong` or
///   `duplicate` (a name in the list or an existing reel, ignoring case and
///   edge spaces, [reelNameKey]); the state says why.
/// - **[create]** makes every name with one `createAll` (all or none), and only
///   then calls `finish()`. A second call while it runs, or once it is done,
///   does nothing. A reel made elsewhere meanwhile is shown as a duplicate and
///   nothing is finished; any other failure is `failed`.
/// - **existing reels** are read live from `ReelsRepository.watchAll` and
///   `ReferencesRepository.watchCounts` and shown oldest first with their
///   reference counts (D-168). Nothing shows until both have answered, so a
///   reel never appears with a count that is about to change; a count read
///   that fails counts as none. A count read that has not answered within
///   [stepReadLimit] is taken as none too (logged), so the rows, the duplicate
///   check and "Continue" never wait for it for good; the counts that arrive
///   later update the rows.
/// - **[skip]** (also the "Continue" of a phone that already has reels) calls
///   `finish()` and writes no reel.
///
/// A phone killed after the reels were made and before onboarding was marked
/// done opens this step again: the reels exist, so the step offers
/// "Continue", and typing the same names is refused as a duplicate, so one
/// Create never makes a second set.

abstract class _$ReelsStepController extends $Notifier<ReelsStepState> {
  ReelsStepState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReelsStepState, ReelsStepState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReelsStepState, ReelsStepState>,
              ReelsStepState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
