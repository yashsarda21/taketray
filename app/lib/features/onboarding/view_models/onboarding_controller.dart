import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';

part 'onboarding_controller.g.dart';

// Flags, steps and error types only: never a reel name (D-10).
final Logger _log = Logger('onboarding');

/// The three first-launch flags of this phone (D-135).
@immutable
class OnboardingFlags {
  const OnboardingFlags({
    required this.done,
    required this.introPlayed,
    required this.homeTipSeen,
  });

  /// Onboarding was finished (or skipped): the app opens on Reels.
  final bool done;

  /// The welcome's intro animation has played: later opens show its final
  /// frame.
  final bool introPlayed;

  /// Home's first-launch tip was dismissed.
  final bool homeTipSeen;

  OnboardingFlags _with({bool? done, bool? introPlayed, bool? homeTipSeen}) =>
      OnboardingFlags(
        done: done ?? this.done,
        introPlayed: introPlayed ?? this.introPlayed,
        homeTipSeen: homeTipSeen ?? this.homeTipSeen,
      );

  @override
  bool operator ==(Object other) =>
      other is OnboardingFlags &&
      other.done == done &&
      other.introPlayed == introPlayed &&
      other.homeTipSeen == homeTipSeen;

  @override
  int get hashCode => Object.hash(done, introPlayed, homeTipSeen);
}

/// The first-launch flags (`PhoneStateRepository.onboardingDone`,
/// `introPlayed`, `homeTipSeen`), read once and kept alive: the router's
/// redirect and the onboarding screens share the one state.
///
/// A read that fails is "not onboarded yet" (all false), logged by type: the
/// welcome shows, never an error screen. Each mark sets the state **first**
/// and then writes, so a failed write still lets the user through this
/// session; the welcome then shows again at most once on the next open. A
/// flag that is already true is not written again.
@Riverpod(keepAlive: true, retry: noRetry)
class OnboardingController extends _$OnboardingController {
  @override
  Future<OnboardingFlags> build() async {
    final phone = ref.read(phoneStateRepositoryProvider);
    try {
      return OnboardingFlags(
        done: await phone.onboardingDone(),
        introPlayed: await phone.introPlayed(),
        homeTipSeen: await phone.homeTipSeen(),
      );
    } on Object catch (error) {
      _log.warning('Reading onboarding failed: ${error.runtimeType}');
      return const OnboardingFlags(
        done: false,
        introPlayed: false,
        homeTipSeen: false,
      );
    }
  }

  /// The welcome's intro finished playing.
  Future<void> markIntroPlayed() => _mark(
    (flags) => flags.introPlayed,
    (flags) => flags._with(introPlayed: true),
    (phone) => phone.markIntroPlayed(),
  );

  /// The last step was finished, or onboarding was skipped.
  Future<void> finish() => _mark(
    (flags) => flags.done,
    (flags) => flags._with(done: true),
    (phone) => phone.markOnboardingDone(),
  );

  /// Home's first-launch tip was dismissed.
  Future<void> markHomeTipSeen() => _mark(
    (flags) => flags.homeTipSeen,
    (flags) => flags._with(homeTipSeen: true),
    (phone) => phone.markHomeTipSeen(),
  );

  Future<void> _mark(
    bool Function(OnboardingFlags) isSet,
    OnboardingFlags Function(OnboardingFlags) set,
    Future<void> Function(PhoneStateRepository) write,
  ) async {
    await future;
    // Read the state after the wait, not the value the wait returned: a mark
    // that ran meanwhile must not be overwritten.
    final current = state.requireValue;
    if (isSet(current)) return;
    // The state first: a slow or failed write never holds the user back.
    state = AsyncData(set(current));
    final phone = ref.read(phoneStateRepositoryProvider);
    await guarded(_log, 'Saving onboarding', () => write(phone));
  }
}
