// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_redirect.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one [OnboardingGate], fed by `onboardingControllerProvider`.
/// Kept alive and never rebuilt, so the router that listens to it is never
/// rebuilt by a flag change.

@ProviderFor(onboardingGate)
final onboardingGateProvider = OnboardingGateProvider._();

/// The app's one [OnboardingGate], fed by `onboardingControllerProvider`.
/// Kept alive and never rebuilt, so the router that listens to it is never
/// rebuilt by a flag change.

final class OnboardingGateProvider
    extends $FunctionalProvider<OnboardingGate, OnboardingGate, OnboardingGate>
    with $Provider<OnboardingGate> {
  /// The app's one [OnboardingGate], fed by `onboardingControllerProvider`.
  /// Kept alive and never rebuilt, so the router that listens to it is never
  /// rebuilt by a flag change.
  OnboardingGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingGateHash();

  @$internal
  @override
  $ProviderElement<OnboardingGate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OnboardingGate create(Ref ref) {
    return onboardingGate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingGate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingGate>(value),
    );
  }
}

String _$onboardingGateHash() => r'53d307638080bc4fd5d788b832b0a7238d38072b';
