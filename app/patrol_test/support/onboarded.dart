import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';

/// An onboarded phone for the Patrol flows that start on Reels (D-136): the
/// app's onboarding flags are fixed at done, so it opens on Reels and never
/// on the welcome, whatever the phone's own database says (it is cleared
/// before each run). The flows of onboarding itself (Task 10) do not use it.
final List<Override> onboardedOverrides = [
  onboardingControllerProvider.overrideWith(
    () => FixedOnboarding(done: true, introPlayed: true, homeTipSeen: true),
  ),
];

/// An [OnboardingController] with fixed flags and no database: `build` gives
/// the flags it was made with, and each mark sets its flag in the state
/// without writing anything.
///
/// The unit tests have their own copy (`test/support/fixed_onboarding.dart`):
/// the Patrol and unit test trees import nothing from each other.
class FixedOnboarding extends OnboardingController {
  FixedOnboarding({
    required this.done,
    required this.introPlayed,
    required this.homeTipSeen,
  });

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
