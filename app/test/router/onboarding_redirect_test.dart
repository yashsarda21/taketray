import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/router/onboarding_redirect.dart';
import 'package:taketray/router/routes.dart';

import '../support/fixed_onboarding.dart';

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

  group('OnboardingGate.known (D-136)', () {
    test('a known value answers at once', () async {
      final gate = OnboardingGate()..value = _done;
      addTearDown(gate.dispose);

      expect(await gate.known(), _done);
    });

    test('waits for the first value, then answers every waiter', () async {
      final gate = OnboardingGate();
      addTearDown(gate.dispose);
      final first = gate.known();
      final second = gate.known();

      gate.value = _notDone;

      expect(await first, _notDone);
      expect(await second, _notDone);
    });

    test('stopWaiting() answers waiters with "not onboarded"; a known value '
        'stays', () async {
      final gate = OnboardingGate();
      addTearDown(gate.dispose);
      final waiting = gate.known();

      gate.stopWaiting();
      expect(await waiting, notOnboarded);

      gate
        ..value = _done
        ..stopWaiting();
      expect(gate.value, _done);
    });

    test('a gate disposed first releases each waiting tap as "not '
        'onboarded" (the tap is then dropped)', () async {
      final gate = OnboardingGate();
      final first = gate.known();
      final second = gate.known();

      gate.dispose();

      const wait = Duration(milliseconds: 200);
      expect(await first.timeout(wait), notOnboarded);
      expect(await second.timeout(wait), notOnboarded);
    });

    test('known() on a disposed gate answers instead of throwing', () async {
      final gate = OnboardingGate()..dispose();

      expect(
        await gate.known().timeout(const Duration(milliseconds: 200)),
        notOnboarded,
      );
    });
  });

  group('what the gate tells the router (D-136)', () {
    test('only "done" and known/unknown notify; the value always follows', () {
      var notified = 0;
      final gate = OnboardingGate()..addListener(() => notified++);
      addTearDown(gate.dispose);

      gate.value = _notDone;
      expect(notified, 1, reason: 'unknown to known');

      gate.value = const OnboardingFlags(
        done: false,
        introPlayed: true,
        homeTipSeen: false,
      );
      expect(notified, 1, reason: 'introPlayed alone');
      expect(gate.value!.introPlayed, isTrue, reason: 'but the value follows');

      gate.value = const OnboardingFlags(
        done: false,
        introPlayed: true,
        homeTipSeen: true,
      );
      expect(notified, 1, reason: 'homeTipSeen alone');
      expect(gate.value!.homeTipSeen, isTrue);

      gate.value = _done;
      expect(notified, 2, reason: 'done turns true');
      expect(gate.value, _done);

      gate.value = _done;
      expect(notified, 2, reason: 'the same value');
    });

    test('done turning back false notifies too', () {
      var notified = 0;
      final gate = OnboardingGate()
        ..value = _done
        ..addListener(() => notified++);
      addTearDown(gate.dispose);

      gate.value = _notDone;

      expect(notified, 1);
    });

    test('stopWaiting() notifies once; a known value is left alone', () {
      var notified = 0;
      final gate = OnboardingGate()..addListener(() => notified++);
      addTearDown(gate.dispose);

      gate.stopWaiting();
      expect(notified, 1);
      gate.stopWaiting();
      expect(notified, 1);
    });

    test('through the provider: marking the intro or the Home tip does not '
        'wake the router, finishing does', () async {
      final container = ProviderContainer.test(
        overrides: [
          onboardingControllerProvider.overrideWith(FixedOnboarding.fresh),
        ],
      );
      await container.read(onboardingControllerProvider.future);
      final gate = container.read(onboardingGateProvider);
      var notified = 0;
      gate.addListener(() => notified++);
      final onboarding = container.read(onboardingControllerProvider.notifier);

      await onboarding.markIntroPlayed();
      await onboarding.markHomeTipSeen();
      expect(notified, 0);
      expect(gate.value!.introPlayed, isTrue);
      expect(gate.value!.homeTipSeen, isTrue);

      await onboarding.finish();
      expect(notified, 1);
      expect(gate.value!.done, isTrue);
    });
  });
}
