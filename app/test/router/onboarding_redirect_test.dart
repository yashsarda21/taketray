import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/router/onboarding_redirect.dart';
import 'package:taketray/router/routes.dart';

const _notDone = OnboardingFlags(
  done: false,
  introPlayed: false,
  homeTipSeen: false,
);

const _done = OnboardingFlags(done: true, introPlayed: true, homeTipSeen: true);

void main() {
  group('Routes for onboarding', () {
    test('the four locations', () {
      expect(Routes.welcome, '/welcome');
      expect(Routes.onboardingAccess, '/onboarding/access');
      expect(Routes.onboardingNotifications, '/onboarding/notifications');
      expect(Routes.onboardingReels, '/onboarding/reels');
    });

    for (final path in [
      '/welcome',
      '/onboarding/access',
      '/onboarding/notifications',
      '/onboarding/reels',
      '/welcome?x=1',
      '/onboarding/reels?x=1',
      '/onboarding/access?',
    ]) {
      test('$path is an onboarding location', () {
        expect(Routes.isOnboarding(path), isTrue);
      });
    }

    for (final path in [
      '/welcomex',
      '/onboarding',
      '/onboarding/',
      '/onboardingx',
      '/onboarding/accessx',
      '/onboarding/reels/5',
      '/welcome/',
      '/x/welcome',
      'welcome',
      '/reels',
      '/',
      '',
    ]) {
      test('"$path" is not an onboarding location', () {
        expect(Routes.isOnboarding(path), isFalse);
      });
    }
  });

  group('onboardingRedirect (D-136)', () {
    // Each location with what the redirect gives while the flags are still
    // being read, while onboarding is not done, and once it is done.
    final table = <String, (String?, String?, String?)>{
      '/reels': (null, Routes.welcome, null),
      '/reels/5?done=1': (null, Routes.welcome, null),
      '/to-tag/play?from=3': (null, Routes.welcome, null),
      '/settings/vn-copies': (null, Routes.welcome, null),
      '/add-videos': (null, Routes.welcome, null),
      '/welcome': (null, null, Routes.reels),
      '/onboarding/access': (null, null, Routes.reels),
      '/onboarding/reels?x=1': (null, null, Routes.reels),
      '/nope': (null, Routes.welcome, null),
      '/welcomex': (null, Routes.welcome, null),
      '/onboarding': (null, Routes.welcome, null),
    };

    for (final MapEntry(key: location, value: (reading, notDone, done))
        in table.entries) {
      test('$location: reading → $reading, not done → $notDone, done → '
          '$done', () {
        final uri = Uri.parse(location);
        expect(onboardingRedirect(uri, null), reading);
        expect(onboardingRedirect(uri, _notDone), notDone);
        expect(onboardingRedirect(uri, _done), done);
      });
    }

    test('only "done" decides; the other two flags never do', () {
      for (final introPlayed in [false, true]) {
        for (final homeTipSeen in [false, true]) {
          final notDone = OnboardingFlags(
            done: false,
            introPlayed: introPlayed,
            homeTipSeen: homeTipSeen,
          );
          final done = OnboardingFlags(
            done: true,
            introPlayed: introPlayed,
            homeTipSeen: homeTipSeen,
          );
          expect(
            onboardingRedirect(Uri.parse('/to-tag'), notDone),
            Routes.welcome,
          );
          expect(onboardingRedirect(Uri.parse('/welcome'), notDone), isNull);
          expect(onboardingRedirect(Uri.parse('/welcome'), done), Routes.reels);
          expect(onboardingRedirect(Uri.parse('/to-tag'), done), isNull);
        }
      }
    });
  });
}
