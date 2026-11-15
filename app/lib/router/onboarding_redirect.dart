import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/router/routes.dart';

part 'onboarding_redirect.g.dart';

/// Where onboarding sends [location] (D-136), or null to stay.
///
/// - [flags] null (still being read): stay. The first frame is held meanwhile
///   (`TakeTrayApp`), so nothing wrong is seen.
/// - Not done: every location outside onboarding goes to [Routes.welcome]; the
///   welcome and the steps stay.
/// - Done: the welcome and the steps go to [Routes.reels]; every other
///   location stays.
///
/// Only [OnboardingFlags.done] decides. The location is never logged (D-10).
String? onboardingRedirect(Uri location, OnboardingFlags? flags) {
  if (flags == null) return null;
  final onboarding = Routes.isOnboarding(location.path);
  if (flags.done) return onboarding ? Routes.reels : null;
  return onboarding ? null : Routes.welcome;
}

/// The flags of a phone that has never been through onboarding.
const OnboardingFlags notOnboarded = OnboardingFlags(
  done: false,
  introPlayed: false,
  homeTipSeen: false,
);

/// The onboarding flags the app acts on (D-136): null until
/// `OnboardingController` first has a value, then that value and each change
/// of it.
///
/// The router redirects with it (its `refreshListenable`), the app holds its
/// first frame until it is known, and notification taps wait for it. If the
/// read takes too long, [stopWaiting] makes it "not onboarded", so the app
/// shows the welcome rather than nothing; a value that comes later still
/// replaces it.
class OnboardingGate extends ValueNotifier<OnboardingFlags?> {
  OnboardingGate() : super(null);

  /// Called when the flags took too long: [notOnboarded] if nothing is known
  /// yet; a known value stays.
  void stopWaiting() => value ??= notOnboarded;

  /// The flags, as soon as they are known.
  Future<OnboardingFlags> known() {
    final now = value;
    if (now != null) return Future.value(now);
    final known = Completer<OnboardingFlags>();
    void listener() {
      final flags = value;
      if (flags == null) return;
      removeListener(listener);
      known.complete(flags);
    }

    addListener(listener);
    return known.future;
  }
}

/// The app's one [OnboardingGate], fed by `onboardingControllerProvider`.
/// Kept alive and never rebuilt, so the router that listens to it is never
/// rebuilt by a flag change.
@Riverpod(keepAlive: true)
OnboardingGate onboardingGate(Ref ref) {
  final gate = OnboardingGate();
  ref
    ..listen(onboardingControllerProvider, (_, next) {
      final flags = next.value;
      if (flags != null) gate.value = flags;
    }, fireImmediately: true)
    ..onDispose(gate.dispose);
  return gate;
}
