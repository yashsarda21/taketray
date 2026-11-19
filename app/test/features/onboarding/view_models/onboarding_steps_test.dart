import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_steps.dart';
import 'package:taketray/platform/android_sdk.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray/router/routes.dart';

import '../../../support/fake_media_bridge.dart';

/// The pure rules of onboarding's access and notification steps (Task 7,
/// D-140) and the Android version they read.

MediaAccessView _view(MediaAccessLevel level, {required bool canAskAgain}) =>
    MediaAccessView(
      level: level,
      banner: AccessBanner.none,
      canAskAgain: canAskAgain,
    );

NotificationAccess _notif({required int sdk, required bool granted}) =>
    NotificationAccess(granted: granted, canAsk: !granted, sdkInt: sdk);

void main() {
  group('accessStepFor', () {
    // Level x askedHere x canAskAgain, all twelve.
    final table = <(MediaAccessLevel, bool, bool, AccessStep)>[
      (MediaAccessLevel.full, false, false, AccessStep.allSet),
      (MediaAccessLevel.full, false, true, AccessStep.allSet),
      (MediaAccessLevel.full, true, false, AccessStep.allSet),
      (MediaAccessLevel.full, true, true, AccessStep.allSet),
      (MediaAccessLevel.limited, false, false, AccessStep.some),
      (MediaAccessLevel.limited, false, true, AccessStep.some),
      (MediaAccessLevel.limited, true, false, AccessStep.some),
      (MediaAccessLevel.limited, true, true, AccessStep.some),
      // Denied and Android would still show its dialog, never asked here:
      // the step before asking.
      (MediaAccessLevel.denied, false, true, AccessStep.before),
      // Asked here (and refused), or Android will not show its dialog again:
      // the way left is the settings page.
      (MediaAccessLevel.denied, true, true, AccessStep.denied),
      (MediaAccessLevel.denied, false, false, AccessStep.denied),
      (MediaAccessLevel.denied, true, false, AccessStep.denied),
    ];
    for (final (level, asked, canAsk, expected) in table) {
      test('${level.name}, askedHere $asked, canAskAgain $canAsk '
          'is ${expected.name}', () {
        expect(
          accessStepFor(_view(level, canAskAgain: canAsk), askedHere: asked),
          expected,
        );
      });
    }

    test('the banner of the view does not matter', () {
      for (final banner in AccessBanner.values) {
        expect(
          accessStepFor(
            MediaAccessView(
              level: MediaAccessLevel.denied,
              banner: banner,
              canAskAgain: true,
            ),
            askedHere: false,
          ),
          AccessStep.before,
        );
      }
    });
  });

  group('nextAfterAccess', () {
    test('no answer yet (null) goes to the reels step', () {
      expect(nextAfterAccess(null), Routes.onboardingReels);
    });

    test('Android 11 and 12 have no permission dialog: reels', () {
      expect(
        nextAfterAccess(_notif(sdk: 30, granted: false)),
        Routes.onboardingReels,
      );
      expect(
        nextAfterAccess(_notif(sdk: 31, granted: false)),
        Routes.onboardingReels,
      );
      expect(
        nextAfterAccess(_notif(sdk: 32, granted: false)),
        Routes.onboardingReels,
      );
    });

    test('Android 13 not granted asks on the notifications step', () {
      expect(
        nextAfterAccess(_notif(sdk: 33, granted: false)),
        Routes.onboardingNotifications,
      );
    });

    test('Android 13 already granted skips the step', () {
      expect(
        nextAfterAccess(_notif(sdk: 33, granted: true)),
        Routes.onboardingReels,
      );
    });

    test('later versions follow the same rule', () {
      expect(
        nextAfterAccess(_notif(sdk: 35, granted: false)),
        Routes.onboardingNotifications,
      );
      expect(
        nextAfterAccess(_notif(sdk: 35, granted: true)),
        Routes.onboardingReels,
      );
    });
  });

  group('asksForNotifications', () {
    test('is the same rule on its own', () {
      expect(asksForNotifications(_notif(sdk: 32, granted: false)), isFalse);
      expect(asksForNotifications(_notif(sdk: 33, granted: false)), isTrue);
      expect(asksForNotifications(_notif(sdk: 34, granted: true)), isFalse);
    });
  });

  group('hasAllowAllChoice', () {
    test('Android 14 and later have "Allow all"; earlier have "Allow"', () {
      expect(hasAllowAllChoice(33), isFalse);
      expect(hasAllowAllChoice(34), isTrue);
      expect(hasAllowAllChoice(35), isTrue);
      expect(hasAllowAllChoice(30), isFalse);
    });
  });

  group('androidSdk', () {
    ProviderContainer containerOn(FakeMediaBridge bridge) =>
        ProviderContainer.test(
          overrides: [mediaBridgeProvider.overrideWithValue(bridge)],
        );

    test('is the sdkInt of the bridge access report', () async {
      final bridge = FakeMediaBridge()
        ..access = const MediaAccess(
          level: MediaAccessLevel.denied,
          canAskAgain: true,
          sdkInt: 33,
        );
      final c = containerOn(bridge);
      expect(await c.read(androidSdkProvider.future), 33);
    });

    test('is read once and kept', () async {
      final bridge = FakeMediaBridge();
      final c = containerOn(bridge);
      await c.read(androidSdkProvider.future);
      await c.read(androidSdkProvider.future);
      expect(bridge.calls.where((m) => m == 'accessReport'), hasLength(1));
    });

    test('a failed read is an error, not a made-up version', () async {
      final bridge = FakeMediaBridge()..failNext('accessReport');
      final c = containerOn(bridge)..listen(androidSdkProvider, (_, _) {});
      await expectLater(c.read(androidSdkProvider.future), throwsA(anything));
      expect(c.read(androidSdkProvider).hasError, isTrue);
    });
  });
}
