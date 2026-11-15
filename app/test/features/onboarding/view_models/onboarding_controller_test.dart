import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';

import '../../../support/vm_harness.dart';

const _none = OnboardingFlags(
  done: false,
  introPlayed: false,
  homeTipSeen: false,
);

void main() {
  late VmHarness h;

  setUp(() {
    h = VmHarness();
  });

  /// A container whose phone state is [phone], on the harness's database.
  ProviderContainer containerWith(PhoneStateRepository phone) {
    return ProviderContainer.test(
      overrides: [
        ...h.overrides,
        phoneStateRepositoryProvider.overrideWithValue(phone),
      ],
    )..listen(onboardingControllerProvider, (_, _) {});
  }

  OnboardingFlags? shown(ProviderContainer c) =>
      c.read(onboardingControllerProvider).value;

  group('OnboardingFlags', () {
    test('equal when all three flags are equal, with the same hash', () {
      const a = OnboardingFlags(
        done: true,
        introPlayed: false,
        homeTipSeen: true,
      );
      const b = OnboardingFlags(
        done: true,
        introPlayed: false,
        homeTipSeen: true,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const OnboardingFlags(
            done: false,
            introPlayed: false,
            homeTipSeen: true,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const OnboardingFlags(
            done: true,
            introPlayed: true,
            homeTipSeen: true,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const OnboardingFlags(
            done: true,
            introPlayed: false,
            homeTipSeen: false,
          ),
        ),
      );
    });
  });

  group('build', () {
    test('reads all three flags from the phone state', () async {
      final phone = h.media.phoneState;
      await phone.markIntroPlayed();
      await phone.markHomeTipSeen();
      final container = containerWith(phone);

      final flags = await container.read(onboardingControllerProvider.future);

      expect(
        flags,
        const OnboardingFlags(
          done: false,
          introPlayed: true,
          homeTipSeen: true,
        ),
      );
    });

    test('an empty table is all false', () async {
      final container = containerWith(h.media.phoneState);

      expect(await container.read(onboardingControllerProvider.future), _none);
    });

    test('a read that throws is all false, never an AsyncError, logged by '
        'type', () async {
      final records = captureLogs();
      final container = containerWith(
        _Failing(h.media.db, h.media.clock, failRead: true),
      );

      final flags = await container.read(onboardingControllerProvider.future);

      expect(flags, _none);
      expect(
        container.read(onboardingControllerProvider),
        isA<AsyncData<OnboardingFlags>>(),
      );
      expect(
        logText(records),
        contains('Reading onboarding failed: StateError'),
      );
      expect(logText(records), isNot(contains('/storage/secret')));
    });
  });

  group('marks', () {
    test(
      'finish() shows done before the write completes, then writes',
      () async {
        final gate = Completer<void>();
        final phone = _Failing(h.media.db, h.media.clock, gate: gate);
        final container = containerWith(phone);
        await container.read(onboardingControllerProvider.future);

        final finishing = container
            .read(onboardingControllerProvider.notifier)
            .finish();
        await settle();

        expect(shown(container)!.done, isTrue);
        expect(phone.writes, ['done']);
        expect(await h.media.phoneState.onboardingDone(), isFalse);

        gate.complete();
        await finishing;

        expect(await h.media.phoneState.onboardingDone(), isTrue);
        expect(shown(container)!.done, isTrue);
      },
    );

    test('markIntroPlayed() and markHomeTipSeen() show first, then '
        'write', () async {
      final gate = Completer<void>();
      final phone = _Failing(h.media.db, h.media.clock, gate: gate);
      final container = containerWith(phone);
      await container.read(onboardingControllerProvider.future);
      final notifier = container.read(onboardingControllerProvider.notifier);

      final intro = notifier.markIntroPlayed();
      final tip = notifier.markHomeTipSeen();
      await settle();

      expect(
        shown(container),
        const OnboardingFlags(
          done: false,
          introPlayed: true,
          homeTipSeen: true,
        ),
      );
      expect(await h.media.phoneState.introPlayed(), isFalse);
      expect(await h.media.phoneState.homeTipSeen(), isFalse);

      gate.complete();
      await Future.wait([intro, tip]);

      expect(await h.media.phoneState.introPlayed(), isTrue);
      expect(await h.media.phoneState.homeTipSeen(), isTrue);
      expect(await h.media.phoneState.onboardingDone(), isFalse);
    });

    test('a write that throws keeps the flag in this session and logs '
        'the type', () async {
      final records = captureLogs();
      final container = containerWith(
        _Failing(h.media.db, h.media.clock, failWrite: true),
      );
      await container.read(onboardingControllerProvider.future);

      await container.read(onboardingControllerProvider.notifier).finish();

      expect(shown(container)!.done, isTrue);
      expect(
        container.read(onboardingControllerProvider),
        isA<AsyncData<OnboardingFlags>>(),
      );
      expect(
        logText(records),
        contains('Saving onboarding failed: StateError'),
      );
      expect(logText(records), isNot(contains('/storage/secret')));
      expect(await h.media.phoneState.onboardingDone(), isFalse);
    });

    test('a failed intro or tip write also keeps its flag', () async {
      final records = captureLogs();
      final container = containerWith(
        _Failing(h.media.db, h.media.clock, failWrite: true),
      );
      await container.read(onboardingControllerProvider.future);
      final notifier = container.read(onboardingControllerProvider.notifier);

      await notifier.markIntroPlayed();
      await notifier.markHomeTipSeen();

      expect(
        shown(container),
        const OnboardingFlags(
          done: false,
          introPlayed: true,
          homeTipSeen: true,
        ),
      );
      expect(
        'Saving onboarding failed'.allMatches(logText(records)),
        hasLength(2),
      );
    });

    test('marking the same flag twice writes once', () async {
      final phone = _Failing(h.media.db, h.media.clock);
      final container = containerWith(phone);
      await container.read(onboardingControllerProvider.future);
      final notifier = container.read(onboardingControllerProvider.notifier);

      await notifier.markIntroPlayed();
      await notifier.markIntroPlayed();
      await notifier.finish();
      await notifier.finish();
      await notifier.markHomeTipSeen();
      await notifier.markHomeTipSeen();

      expect(phone.writes, ['intro', 'done', 'tip']);
    });

    test(
      'a flag that was already true on build is not written again',
      () async {
        await h.media.phoneState.markOnboardingDone();
        final phone = _Failing(h.media.db, h.media.clock);
        final container = containerWith(phone);
        await container.read(onboardingControllerProvider.future);

        await container.read(onboardingControllerProvider.notifier).finish();

        expect(phone.writes, isEmpty);
      },
    );

    test('two marks at once keep both flags', () async {
      final container = containerWith(h.media.phoneState);
      await container.read(onboardingControllerProvider.future);
      final notifier = container.read(onboardingControllerProvider.notifier);

      await Future.wait([notifier.markIntroPlayed(), notifier.finish()]);

      expect(
        shown(container),
        const OnboardingFlags(
          done: true,
          introPlayed: true,
          homeTipSeen: false,
        ),
      );
      expect(await h.media.phoneState.introPlayed(), isTrue);
      expect(await h.media.phoneState.onboardingDone(), isTrue);
    });

    test('a mark before the first read finishes keeps what was read', () async {
      await h.media.phoneState.markHomeTipSeen();
      final container = containerWith(h.media.phoneState);

      await container.read(onboardingControllerProvider.notifier).finish();

      expect(
        shown(container),
        const OnboardingFlags(
          done: true,
          introPlayed: false,
          homeTipSeen: true,
        ),
      );
      expect(await h.media.phoneState.homeTipSeen(), isTrue);
      expect(await h.media.phoneState.onboardingDone(), isTrue);
    });
  });
}

/// A phone state that counts the onboarding writes by name, and can hold,
/// fail or pass them, and fail the reads. Its error carries a path so a test
/// can prove only the type is logged.
class _Failing extends PhoneStateRepository {
  // The super constructor's parameters are private.
  // ignore: use_super_parameters
  _Failing(
    AppDatabase db,
    Clock clock, {
    this.gate,
    this.failWrite = false,
    this.failRead = false,
  }) : super(db, clock);

  final Completer<void>? gate;
  final bool failWrite;
  final bool failRead;
  final List<String> writes = [];

  Future<void> _write(String name, Future<void> Function() real) async {
    writes.add(name);
    await gate?.future;
    if (failWrite) throw StateError('/storage/secret');
    await real();
  }

  @override
  Future<bool> onboardingDone() => failRead
      ? Future.error(StateError('/storage/secret'))
      : super.onboardingDone();

  @override
  Future<void> markOnboardingDone() => _write('done', super.markOnboardingDone);

  @override
  Future<void> markIntroPlayed() => _write('intro', super.markIntroPlayed);

  @override
  Future<void> markHomeTipSeen() => _write('tip', super.markHomeTipSeen);
}
