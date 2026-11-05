import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/rules/still_shooting.dart';
import 'package:taketray/features/notifications/view_models/still_shooting_prompt.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../../support/vm_harness.dart';

final DateTime _start = DateTime.utc(2026, 6, 1, 9);

void main() {
  late VmHarness h;
  late StillShootingPrompt prompt;
  late DateTime since;

  setUp(() async {
    h = VmHarness(now: _start);
    since = (await h.media.turnOnNow()).since!;
    prompt = h.container.read(stillShootingPromptProvider);
  });

  void daysLater(int days, {int minutes = 0}) =>
      h.media.clock.advance(Duration(days: days, minutes: minutes));

  ShadeAction shade(ShadeActionKind kind, {DateTime? forSession}) =>
      ShadeAction(
        kind: kind,
        since: forSession ?? since,
        at: DateTime.utc(2026, 6, 15, 10),
        generations: const {},
      );

  group('when it is due', () {
    test('due after 14 days: the session to ask about, once', () async {
      daysLater(14);

      expect(await prompt.claim(), since);
      expect(await prompt.claim(), isNull, reason: 'once per app session');
    });

    test('not before 14 days, and the claim is not used up', () async {
      daysLater(13, minutes: 23 * 60 + 59);

      expect(await prompt.claim(), isNull);

      h.media.clock.advance(const Duration(minutes: 1));
      expect(await prompt.claim(), since);
    });

    test('not when Shooting mode is off', () async {
      daysLater(20);
      await h.media.phoneState.turnShootingOff();

      expect(await prompt.claim(), isNull);
    });

    test('not when it was answered in this session', () async {
      daysLater(20);
      await h.media.phoneState.markStillAnswered(since);

      expect(await prompt.claim(), isNull);
    });

    test('a new session starts the 14 days again', () async {
      daysLater(20);
      await h.media.phoneState.turnShootingOff();
      await h.media.turnOnNow();
      daysLater(3);

      expect(await prompt.claim(), isNull);
    });

    test('two checks at the same moment give it to one', () async {
      daysLater(15);

      final results = await Future.wait([prompt.claim(), prompt.claim()]);

      expect(results.whereType<DateTime>(), hasLength(1));
    });

    test('release gives the claim back', () async {
      daysLater(15);
      expect(await prompt.claim(), since);

      prompt.release();

      expect(await prompt.claim(), since);
    });
  });

  group('answered in the shade first', () {
    test('a waiting Keep on for this session: no question', () async {
      daysLater(15);
      h.background.shadeAction = shade(ShadeActionKind.keepOn);

      expect(await prompt.claim(), isNull);
    });

    test('a waiting Turn off for this session: no question', () async {
      daysLater(15);
      h.background.shadeAction = shade(ShadeActionKind.turnOff);

      expect(await prompt.claim(), isNull);
    });

    test(
      'the claim is not used up: after the action, nothing is due',
      () async {
        daysLater(15);
        h.background.shadeAction = shade(ShadeActionKind.keepOn);
        expect(await prompt.claim(), isNull);

        // The scan applies it: the session is answered.
        await h.media.phoneState.markStillAnswered(since);
        h.background.shadeAction = null;

        expect(await prompt.claim(), isNull);
      },
    );

    test('a waiting action of another session does not count', () async {
      daysLater(15);
      h.background.shadeAction = shade(
        ShadeActionKind.turnOff,
        forSession: _start.subtract(const Duration(days: 30)),
      );

      expect(await prompt.claim(), since);
    });

    test('the action applied while we look: still no question', () async {
      daysLater(15);
      final gate = h.background.gate('pendingShadeAction');

      final claim = prompt.claim();
      await settle();
      // The scan applied a Keep on and cleared it, just before the read
      // answers "nothing waiting".
      await h.media.phoneState.markStillAnswered(since);
      gate.complete();

      expect(await claim, isNull);
    });

    test('an action we cannot read: no question, and no claim used', () async {
      daysLater(15);
      final records = captureLogs();
      h.background.failNext('pendingShadeAction');

      expect(await prompt.claim(), isNull);
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));

      expect(await prompt.claim(), since, reason: 'the next check tries again');
    });
  });

  group('the answers', () {
    test('Keep it on marks the session answered', () async {
      daysLater(15);
      await prompt.claim();

      await prompt.keepOn(since);

      final state = await h.media.phoneState.loadShooting();
      expect(state.stillAnswered, isTrue);
      expect(state.on, isTrue);
      expect(stillShootingDue(state, h.media.clock.now()), isFalse);
    });

    test('Keep it on for a session that ended changes nothing', () async {
      daysLater(15);
      await prompt.claim();
      await h.media.phoneState.turnShootingOff();
      await h.media.turnOnNow();

      await prompt.keepOn(since);

      expect(
        (await h.media.phoneState.loadShooting()).stillAnswered,
        isFalse,
        reason: 'the new session was not asked',
      );
    });

    test('Turn off switches Shooting mode off', () async {
      daysLater(15);
      await prompt.claim();

      await prompt.turnOff();

      expect(
        await h.media.phoneState.loadShooting().then((s) => s.on),
        isFalse,
      );
    });

    test('Keep it on does not throw when the write fails', () async {
      daysLater(15);
      final failing = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          phoneStateRepositoryProvider.overrideWithValue(
            _FailingPhoneState(h.media.db, h.media.clock),
          ),
        ],
      );
      final records = captureLogs();

      await failing.read(stillShootingPromptProvider).keepOn(since);

      expect(logText(records), contains('Storing Keep it on failed'));
      expect(logText(records), contains('StateError'));
      expect(logText(records), isNot(contains('secret')));
    });
  });
}

/// A phone state whose write of Keep it on fails with a message that holds a
/// path.
class _FailingPhoneState extends PhoneStateRepository {
  // The super constructor's parameters are private, so they cannot be passed
  // on as super parameters.
  // ignore: use_super_parameters
  _FailingPhoneState(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<bool> markStillAnswered(DateTime since) =>
      Future.error(StateError('/storage/emulated/0/secret'));
}
