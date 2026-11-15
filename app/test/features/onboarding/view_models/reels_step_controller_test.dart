import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/view_models/reels_step_controller.dart';

import '../../../support/reels_step_spies.dart';
import '../../../support/vm_harness.dart';

/// Onboarding's last step (Task 8, D-141): the names typed so far, the rules
/// the reel form has, Create (one `createAll`, then `finish`), Skip and
/// Continue.

void main() {
  late VmHarness h;
  late List<String> events;
  late SpyReels reels;
  late SpyOnboarding onboarding;
  late ProviderContainer container;

  setUp(() {
    h = VmHarness();
    events = [];
    reels = SpyReels(h.media.db, h.media.clock, events);
    onboarding = SpyOnboarding(events);
    container = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        reelsRepositoryProvider.overrideWithValue(reels),
        onboardingControllerProvider.overrideWith(() => onboarding),
      ],
    );
  });

  ReelsStepController step() {
    container
      ..listen(reelsStepControllerProvider, (_, _) {})
      ..listen(onboardingControllerProvider, (_, _) {});
    return container.read(reelsStepControllerProvider.notifier);
  }

  ReelsStepState state() => container.read(reelsStepControllerProvider);

  Future<List<Reel>> saved() => reels.watchAll().first;

  /// The controller, with [names] already added.
  ReelsStepController withNames(List<String> names) {
    final controller = step();
    for (final name in names) {
      expect(controller.add(name), isTrue);
    }
    return controller;
  }

  group('add', () {
    test('stores the name trimmed', () {
      final controller = step();
      expect(controller.add('  Goa '), isTrue);
      expect(state().names, ['Goa']);
      expect(state().error, isNull);
    });

    test('keeps the order and the inside of a name', () {
      step()
        ..add('London  Food')
        ..add('Goa');
      expect(state().names, ['London  Food', 'Goa']);
    });

    for (final blank in ['', '   ', '​‍', ' ⁠ ']) {
      test('"${blank.runes.join(',')}" is empty and not added', () {
        final controller = withNames(['Goa']);
        expect(controller.add(blank), isFalse);
        expect(state().error, ReelNameProblem.empty);
        expect(state().names, ['Goa']);
      });
    }

    test('41 characters is too long, 40 is fine', () {
      final controller = step();
      expect(controller.add('x' * 41), isFalse);
      expect(state().error, ReelNameProblem.tooLong);
      expect(state().names, isEmpty);
      expect(controller.add('x' * 40), isTrue);
      expect(state().error, isNull);
    });

    test('emoji count once: 40 pass, 41 do not', () {
      final controller = step();
      expect(controller.add('🎬' * 41), isFalse);
      expect(state().error, ReelNameProblem.tooLong);
      expect(controller.add('🎬' * 40), isTrue);
      expect(state().names, ['🎬' * 40]);
    });

    test('a name already in the list in another case is a duplicate that '
        'names the one in the list', () {
      final controller = withNames(['Goa']);
      expect(controller.add('goa'), isFalse);
      expect(state().error, ReelNameProblem.duplicate);
      expect(state().clashingName, 'Goa');
      expect(state().names, ['Goa']);
      expect(controller.add('  GOA '), isFalse);
      expect(state().clashingName, 'Goa');
    });

    test('non-ASCII case folds too', () {
      final controller = withNames(['Café']);
      expect(controller.add('CAFÉ'), isFalse);
      expect(state().error, ReelNameProblem.duplicate);
    });

    test('a name an existing reel has is a duplicate that names the '
        'reel as saved', () async {
      await reels.create('London Food');
      final controller = step();
      await until(() => state().hasExistingReels);
      expect(controller.add(' london FOOD'), isFalse);
      expect(state().error, ReelNameProblem.duplicate);
      expect(state().clashingName, 'London Food');
      expect(state().names, isEmpty);
    });

    test('a good name clears an earlier error and clashing name', () {
      final controller = withNames(['Goa'])..add('goa');
      expect(state().error, isNotNull);
      expect(controller.add('Paris'), isTrue);
      expect(state().error, isNull);
      expect(state().clashingName, isNull);
    });

    test('clearError forgets the error and the clash', () {
      withNames(['Goa'])
        ..add('goa')
        ..clearError();
      expect(state().error, isNull);
      expect(state().clashingName, isNull);
      expect(state().names, ['Goa']);
    });

    test('adds nothing while a create is running', () async {
      reels.gate = Completer<void>();
      final controller = withNames(['Goa']);
      final running = controller.create();
      expect(state().busy, isTrue);
      expect(controller.add('Paris'), isFalse);
      expect(state().names, ['Goa']);
      reels.gate!.complete();
      await running;
    });
  });

  group('remove', () {
    test('takes the name out by its place', () {
      withNames(['Goa', 'Paris', 'Rome']).remove(1);
      expect(state().names, ['Goa', 'Rome']);
    });

    test('a place outside the list does nothing', () {
      withNames(['Goa'])
        ..remove(-1)
        ..remove(1)
        ..remove(7);
      expect(state().names, ['Goa']);
    });

    test('a name can be added again once removed, and the error goes', () {
      final controller = withNames(['Goa'])
        ..add('goa')
        ..remove(0);
      expect(state().error, isNull);
      expect(controller.add('goa'), isTrue);
      expect(state().names, ['goa']);
    });

    test('does nothing while a create is running', () async {
      reels.gate = Completer<void>();
      final controller = withNames(['Goa']);
      final running = controller.create();
      controller.remove(0);
      expect(state().names, ['Goa']);
      reels.gate!.complete();
      await running;
    });
  });

  group('ideas', () {
    test('the constant is the five of the prototype, in order', () {
      expect(onboardingIdeas, [
        'Day 1 Vlog',
        'Food',
        'Cinematic',
        'Behind the scenes',
        'Get ready with me',
      ]);
    });

    test('with no names the first four show', () {
      step();
      expect(state().ideas, [
        'Day 1 Vlog',
        'Food',
        'Cinematic',
        'Behind the scenes',
      ]);
    });

    test('an idea in the list goes and the next one takes its place', () {
      withNames(['Day 1 Vlog']);
      expect(state().ideas, [
        'Food',
        'Cinematic',
        'Behind the scenes',
        'Get ready with me',
      ]);
    });

    test('the filter is by key: another case or edge spaces hide it', () {
      withNames(['food', '  CINEMATIC ']);
      expect(state().ideas, [
        'Day 1 Vlog',
        'Behind the scenes',
        'Get ready with me',
      ]);
    });

    test('they hide at five names, show at four', () {
      final controller = withNames(['a', 'b', 'c', 'd']);
      expect(state().ideas, isNotEmpty);
      controller.add('e');
      expect(state().ideas, isEmpty);
      controller.remove(0);
      expect(state().ideas, isNotEmpty);
    });

    test('an idea an existing reel has is not offered', () async {
      await reels.create('Food');
      step();
      await until(() => state().hasExistingReels);
      expect(state().ideas, [
        'Day 1 Vlog',
        'Cinematic',
        'Behind the scenes',
        'Get ready with me',
      ]);
    });

    test('addIdea adds it like a typed name', () {
      step().addIdea('Food');
      expect(state().names, ['Food']);
      expect(state().ideas, isNot(contains('Food')));
    });

    test('addIdea of a name already there shows the duplicate', () {
      withNames(['food']).addIdea('Food');
      expect(state().names, ['food']);
      expect(state().error, ReelNameProblem.duplicate);
      expect(state().clashingName, 'food');
    });
  });

  group('existing reels', () {
    test('none until a reel exists, then true, and again false', () async {
      step();
      await settle();
      expect(state().hasExistingReels, isFalse);
      final goa = await reels.create('Goa');
      await until(() => state().hasExistingReels);
      await reels.delete(goa.id);
      await until(() => !state().hasExistingReels);
    });

    test('a read that fails leaves the step working', () async {
      final failing = _FailingWatch(h.media.db, h.media.clock, events);
      final c = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          reelsRepositoryProvider.overrideWithValue(failing),
          onboardingControllerProvider.overrideWith(() => onboarding),
        ],
      )..listen(reelsStepControllerProvider, (_, _) {});
      await settle();
      final controller = c.read(reelsStepControllerProvider.notifier);
      expect(controller.add('Goa'), isTrue);
      expect(c.read(reelsStepControllerProvider).hasExistingReels, isFalse);
    });
  });

  group('create', () {
    test(
      'creates the names in order with one createAll, then finishes',
      () async {
        final controller = withNames(['  Goa ', 'Paris', 'rome']);
        await controller.create();
        expect(reels.calls, [
          ['Goa', 'Paris', 'rome'],
        ]);
        expect(events, ['createAll', 'createAll done', 'finish']);
        expect(
          {for (final r in await saved()) r.name},
          {'Goa', 'Paris', 'rome'},
        );
        expect(state().finished, isTrue);
        expect(state().busy, isFalse);
        expect(onboarding.finishes, 1);
      },
    );

    test('createAll completes before finish', () async {
      reels.gate = Completer<void>();
      final controller = withNames(['Goa']);
      final running = controller.create();
      await settle();
      expect(events, ['createAll']);
      expect(onboarding.finishes, 0);
      expect(state().busy, isTrue);
      reels.gate!.complete();
      await running;
      expect(events, ['createAll', 'createAll done', 'finish']);
    });

    test('create twice quickly makes one createAll and one finish', () async {
      reels.gate = Completer<void>();
      final controller = withNames(['Goa', 'Paris']);
      final first = controller.create();
      final second = controller.create();
      reels.gate!.complete();
      await Future.wait([first, second]);
      expect(reels.calls, hasLength(1));
      expect(onboarding.finishes, 1);
      expect(await saved(), hasLength(2));
    });

    test('create again after it is done does nothing', () async {
      final controller = withNames(['Goa']);
      await controller.create();
      await controller.create();
      expect(reels.calls, hasLength(1));
      expect(onboarding.finishes, 1);
      expect(await saved(), hasLength(1));
    });

    test('with no names it does nothing', () async {
      final controller = step();
      await controller.create();
      expect(reels.calls, isEmpty);
      expect(onboarding.finishes, 0);
      expect(state().finished, isFalse);
    });

    test('a reel made elsewhere meanwhile: the error is shown, the names '
        'stay, nothing is finished, and fixing the list works', () async {
      final controller = withNames(['Goa', 'Paris']);
      // Made after the step looked, as by a share or another screen.
      reels.failWith = const InvalidInputException(ReelNameProblem.duplicate);
      await reels.create('goa');
      await controller.create();
      expect(state().error, ReelNameProblem.duplicate);
      expect(state().clashingName, 'goa');
      expect(state().names, ['Goa', 'Paris']);
      expect(state().busy, isFalse);
      expect(state().finished, isFalse);
      expect(state().failed, isFalse);
      expect(onboarding.finishes, 0);
      expect(events, isNot(contains('finish')));

      reels.failWith = null;
      controller.remove(0);
      expect(state().error, isNull);
      await controller.create();
      expect(state().finished, isTrue);
      expect(onboarding.finishes, 1);
      expect({for (final r in await saved()) r.name}, {'goa', 'Paris'});
    });

    test('an unexpected failure is told, nothing is finished, and the step '
        'can try again', () async {
      reels.failWith = StateError('disk full');
      final controller = withNames(['Goa']);
      await controller.create();
      expect(state().failed, isTrue);
      expect(state().error, isNull);
      expect(state().busy, isFalse);
      expect(state().finished, isFalse);
      expect(state().names, ['Goa']);
      expect(onboarding.finishes, 0);

      reels.failWith = null;
      await controller.create();
      expect(state().failed, isFalse);
      expect(state().finished, isTrue);
      expect(await saved(), hasLength(1));
    });

    test('typing or adding clears the failure line', () async {
      reels.failWith = StateError('disk full');
      final controller = withNames(['Goa']);
      await controller.create();
      expect(state().failed, isTrue);
      controller.add('Paris');
      expect(state().failed, isFalse);
    });

    test('a finish that fails after the reels were made does not make '
        'them again: the list is cleared and Continue finishes', () async {
      onboarding.failWith = StateError('no');
      final controller = withNames(['Goa']);
      await controller.create();
      expect(state().names, isEmpty);
      expect(state().failed, isTrue);
      expect(state().busy, isFalse);
      expect(state().finished, isFalse);
      expect(reels.calls, hasLength(1));
      await until(() => state().hasExistingReels);

      onboarding.failWith = null;
      await controller.create();
      await controller.skip();
      expect(reels.calls, hasLength(1));
      expect(await saved(), hasLength(1));
      expect(state().finished, isTrue);
    });
  });

  group('the next run after a kill between Create and the flag', () {
    test('the reels exist: Continue, the same names are refused, and '
        'skip writes no more reels', () async {
      await reels.createAll(['Goa', 'Paris']);
      events.clear();
      final controller = step();
      await until(() => state().hasExistingReels);
      expect(state().names, isEmpty);
      expect(controller.add('goa'), isFalse);
      expect(state().error, ReelNameProblem.duplicate);
      expect(state().clashingName, 'Goa');
      await controller.skip();
      expect(reels.calls, hasLength(1));
      expect(await saved(), hasLength(2));
      expect(onboarding.finishes, 1);
    });

    test('a user who types the same names again gets one set of reels at '
        'most: the repository refuses a second Create', () async {
      await reels.createAll(['Goa', 'Paris']);
      reels.calls.clear();
      // The step did not know yet (its read had not come back): add passes.
      final c =
          ProviderContainer.test(
              overrides: [
                ...h.overrides,
                reelsRepositoryProvider.overrideWithValue(reels),
                onboardingControllerProvider.overrideWith(() => onboarding),
              ],
            )
            ..listen(reelsStepControllerProvider, (_, _) {})
            ..listen(onboardingControllerProvider, (_, _) {});
      final controller = c.read(reelsStepControllerProvider.notifier)
        ..add('Goa')
        ..add('Paris');
      await controller.create();
      final after = c.read(reelsStepControllerProvider);
      expect(after.error, ReelNameProblem.duplicate);
      expect(after.finished, isFalse);
      expect(onboarding.finishes, 0);
      expect(await saved(), hasLength(2));
    });
  });

  group('skip', () {
    test('finishes and writes no reels, even with names typed', () async {
      final controller = withNames(['Goa']);
      await controller.skip();
      expect(reels.calls, isEmpty);
      expect(await saved(), isEmpty);
      expect(onboarding.finishes, 1);
      expect(state().finished, isTrue);
      expect(state().busy, isFalse);
    });

    test('twice quickly finishes once', () async {
      final controller = step();
      final first = controller.skip();
      final second = controller.skip();
      await Future.wait([first, second]);
      expect(onboarding.finishes, 1);
    });

    test('does nothing while a create is running', () async {
      reels.gate = Completer<void>();
      final controller = withNames(['Goa']);
      final running = controller.create();
      await controller.skip();
      expect(onboarding.finishes, 0);
      reels.gate!.complete();
      await running;
      expect(onboarding.finishes, 1);
    });

    test('a finish that fails is told and the step can try again', () async {
      onboarding.failWith = StateError('no');
      final controller = step();
      await controller.skip();
      expect(state().failed, isTrue);
      expect(state().busy, isFalse);
      expect(state().finished, isFalse);
      onboarding.failWith = null;
      await controller.skip();
      expect(state().finished, isTrue);
    });
  });

  group('logs', () {
    test('never hold a typed name (D-10)', () async {
      final logs = captureLogs();
      reels.failWith = StateError('could not save Secret Trip');
      final controller = withNames(['Secret Trip']);
      await controller.create();
      expect(logs, isNotEmpty);
      for (final record in logs) {
        expect('${record.message} ${record.error}', isNot(contains('Secret')));
      }
    });
  });

  test('state equality: the same fields are equal with one hash', () {
    const a = ReelsStepState(names: ['Goa'], busy: true);
    const b = ReelsStepState(names: ['Goa'], busy: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const ReelsStepState(names: ['Goa'])));
    expect(a, isNot(const ReelsStepState(names: ['Paris'], busy: true)));
  });
}

/// A repository whose `watchAll` always fails.
class _FailingWatch extends SpyReels {
  // ignore: use_super_parameters, the same reason
  _FailingWatch(AppDatabase db, Clock clock, List<String> events)
    : super(db, clock, events);

  @override
  Stream<List<Reel>> watchAll() => Stream.error(StateError('no read'));
}
