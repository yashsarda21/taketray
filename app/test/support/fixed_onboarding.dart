import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';

/// An [OnboardingController] with fixed first-launch flags and no database:
/// `build` gives the flags it was made with, and each mark sets its flag in
/// the state without writing anything.
///
/// The test harnesses put [FixedOnboarding.onboarded] into every app they
/// pump (`VmHarness.appOverrides`), so the app opens on Reels as it did
/// before onboarding existed (D-136). A test of onboarding itself passes
/// [FixedOnboarding.fresh] or its own flags.
class FixedOnboarding extends OnboardingController {
  FixedOnboarding({
    required this.done,
    required this.introPlayed,
    required this.homeTipSeen,
  });

  /// Onboarding finished, the intro played and the Home tip seen.
  factory FixedOnboarding.onboarded() =>
      FixedOnboarding(done: true, introPlayed: true, homeTipSeen: true);

  /// A phone that has never been through onboarding.
  factory FixedOnboarding.fresh() =>
      FixedOnboarding(done: false, introPlayed: false, homeTipSeen: false);

  final bool done;
  final bool introPlayed;
  final bool homeTipSeen;

  @override
  Future<OnboardingFlags> build() async => OnboardingFlags(
    done: done,
    introPlayed: introPlayed,
    homeTipSeen: homeTipSeen,
  );

  @override
  Future<void> finish() => _set(done: true);

  @override
  Future<void> markIntroPlayed() => _set(introPlayed: true);

  @override
  Future<void> markHomeTipSeen() => _set(homeTipSeen: true);

  /// Like the real marks: after the first read, then the state only.
  Future<void> _set({bool? done, bool? introPlayed, bool? homeTipSeen}) async {
    await future;
    final now = state.requireValue;
    state = AsyncData(
      OnboardingFlags(
        done: done ?? now.done,
        introPlayed: introPlayed ?? now.introPlayed,
        homeTipSeen: homeTipSeen ?? now.homeTipSeen,
      ),
    );
  }
}
