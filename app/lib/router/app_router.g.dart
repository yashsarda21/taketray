// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's router: three tabs, each with its own navigation stack, and
/// onboarding's four screens above them.
///
/// Kept alive so the navigation state survives when nothing is watching for a
/// frame. Onboarding (D-136): every location first goes through
/// [onboardingRedirect] with the [OnboardingGate]'s flags, and the gate is the
/// router's `refreshListenable`, so a change of the flags (the first read,
/// `finish()`) redirects the current location again. The gate is never
/// rebuilt, so neither is the router.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The app's router: three tabs, each with its own navigation stack, and
/// onboarding's four screens above them.
///
/// Kept alive so the navigation state survives when nothing is watching for a
/// frame. Onboarding (D-136): every location first goes through
/// [onboardingRedirect] with the [OnboardingGate]'s flags, and the gate is the
/// router's `refreshListenable`, so a change of the flags (the first read,
/// `finish()`) redirects the current location again. The gate is never
/// rebuilt, so neither is the router.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app's router: three tabs, each with its own navigation stack, and
  /// onboarding's four screens above them.
  ///
  /// Kept alive so the navigation state survives when nothing is watching for a
  /// frame. Onboarding (D-136): every location first goes through
  /// [onboardingRedirect] with the [OnboardingGate]'s flags, and the gate is the
  /// router's `refreshListenable`, so a change of the flags (the first read,
  /// `finish()`) redirects the current location again. The gate is never
  /// rebuilt, so neither is the router.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'fe202c3449f079950fa09f30bb02f5d98beb423f';
