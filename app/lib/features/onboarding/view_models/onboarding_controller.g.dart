// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The first-launch flags (`PhoneStateRepository.onboardingDone`,
/// `introPlayed`, `homeTipSeen`), read once and kept alive: the router's
/// redirect and the onboarding screens share the one state.
///
/// A read that fails is "not onboarded yet" (all false), logged by type: the
/// welcome shows, never an error screen. Each mark sets the state **first**
/// and then writes, so a failed write still lets the user through this
/// session; the welcome then shows again at most once on the next open. A
/// flag that is already true is not written again.

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

/// The first-launch flags (`PhoneStateRepository.onboardingDone`,
/// `introPlayed`, `homeTipSeen`), read once and kept alive: the router's
/// redirect and the onboarding screens share the one state.
///
/// A read that fails is "not onboarded yet" (all false), logged by type: the
/// welcome shows, never an error screen. Each mark sets the state **first**
/// and then writes, so a failed write still lets the user through this
/// session; the welcome then shows again at most once on the next open. A
/// flag that is already true is not written again.
final class OnboardingControllerProvider
    extends $AsyncNotifierProvider<OnboardingController, OnboardingFlags> {
  /// The first-launch flags (`PhoneStateRepository.onboardingDone`,
  /// `introPlayed`, `homeTipSeen`), read once and kept alive: the router's
  /// redirect and the onboarding screens share the one state.
  ///
  /// A read that fails is "not onboarded yet" (all false), logged by type: the
  /// welcome shows, never an error screen. Each mark sets the state **first**
  /// and then writes, so a failed write still lets the user through this
  /// session; the welcome then shows again at most once on the next open. A
  /// flag that is already true is not written again.
  OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'onboardingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();
}

String _$onboardingControllerHash() =>
    r'2a30c97b23193b37e0d9653ab5c3f5de2451fdcf';

/// The first-launch flags (`PhoneStateRepository.onboardingDone`,
/// `introPlayed`, `homeTipSeen`), read once and kept alive: the router's
/// redirect and the onboarding screens share the one state.
///
/// A read that fails is "not onboarded yet" (all false), logged by type: the
/// welcome shows, never an error screen. Each mark sets the state **first**
/// and then writes, so a failed write still lets the user through this
/// session; the welcome then shows again at most once on the next open. A
/// flag that is already true is not written again.

abstract class _$OnboardingController extends $AsyncNotifier<OnboardingFlags> {
  FutureOr<OnboardingFlags> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<OnboardingFlags>, OnboardingFlags>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<OnboardingFlags>, OnboardingFlags>,
              AsyncValue<OnboardingFlags>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
