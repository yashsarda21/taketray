import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';

/// How long a step waits for a bridge read (the video access, the Android
/// version, the notification permission) before it shows its "unknown" look
/// (D-140): a read that never answers must not leave a blank step.
// style-check: allow a time limit, not a motion duration
const Duration stepReadLimit = Duration(seconds: 5);

/// Which of the four looks the video access step has (D-140, the prototype's
/// `ob-video` states `before`, `limited`, `denied` and the last one).
enum AccessStep {
  /// Access is not given and Android would still show its dialog: "Allow
  /// access".
  before,

  /// Only some videos are allowed: "Allow all videos" or Manual mode.
  some,

  /// Access was refused (here, or Android will not ask again): "Open
  /// settings" or Manual mode.
  denied,

  /// TakeTray sees every video.
  allSet,
}

/// The step that tells the truth about [view] now.
///
/// - full: [AccessStep.allSet], whenever and however it came (asked here, set
///   in Android's settings, kept from an earlier install);
/// - limited: [AccessStep.some];
/// - denied: [AccessStep.denied] when the user was asked on this step
///   ([askedHere]) or Android will not show its dialog again
///   (`!canAskAgain`), otherwise [AccessStep.before].
AccessStep accessStepFor(MediaAccessView view, {required bool askedHere}) =>
    switch (view.level) {
      MediaAccessLevel.full => AccessStep.allSet,
      MediaAccessLevel.limited => AccessStep.some,
      MediaAccessLevel.denied =>
        askedHere || !view.canAskAgain ? AccessStep.denied : AccessStep.before,
    };

/// The first Android version with the notification permission dialog
/// (Android 13, `TIRAMISU`).
const int notificationPermissionSdk = 33;

/// The first Android version whose video permission dialog says "Allow all"
/// (Android 14, `UPSIDE_DOWN_CAKE`); before it the word is "Allow".
const int allowAllSdk = 34;

/// Whether the notifications step has anything to ask for [access]: Android
/// 13 and later, and not allowed yet.
bool asksForNotifications(NotificationAccess access) =>
    access.sdkInt >= notificationPermissionSdk && !access.granted;

/// Whether Android's video dialog on [sdkInt] has the choice "Allow all"
/// (otherwise it is "Allow").
bool hasAllowAllChoice(int sdkInt) => sdkInt >= allowAllSdk;

/// Where Continue and Manual mode go after the access step: the
/// notifications step when it has something to ask, the reels step otherwise
/// (Android 11 and 12, already allowed, or no answer yet).
String nextAfterAccess(NotificationAccess? access) =>
    access != null && asksForNotifications(access)
    ? Routes.onboardingNotifications
    : Routes.onboardingReels;
