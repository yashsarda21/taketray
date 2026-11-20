import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_steps.dart';
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

  group('existing reels with their reference counts (D-168)', () {
    late ReferencesRepository refs;

    setUp(() => refs = ReferencesRepository(h.media.db, h.media.clock));

    Future<void> addRefs(int reelId, int count) async {
      for (var i = 0; i < count; i++) {
        await refs.add(reelId, 'https://example.com/$reelId/$i');
      }
    }

    test('none: no existing reels', () async {
      step();
      await settle();
      expect(state().existing, isEmpty);
      expect(state().existingNames, isEmpty);
    });

    test('counts read 0, 1 and 3 for the reels they belong to', () async {
      final a = await reels.create('A');
      h.media.clock.advance(const Duration(minutes: 1));
      final b = await reels.create('B');
      h.media.clock.advance(const Duration(minutes: 1));
      final c = await reels.create('C');
      await addRefs(b.id, 1);
      await addRefs(c.id, 3);
      expect(a.id, isNot(b.id));
      step();
      await until(() => state().existing.length == 3);
      await until(() => state().existing.last.referenceCount == 3);
      expect(state().existing, [
        (name: 'A', referenceCount: 0),
        (name: 'B', referenceCount: 1),
        (name: 'C', referenceCount: 3),
      ]);
    });

    test('oldest first, by creation, not by the last change', () async {
      final a = await reels.create('A');
      h.media.clock.advance(const Duration(minutes: 1));
      await reels.create('B');
      h.media.clock.advance(const Duration(minutes: 1));
      await reels.create('C');
      // A reference moves A to the top of the database's own order.
      h.media.clock.advance(const Duration(minutes: 1));
      await addRefs(a.id, 1);
      expect((await saved()).first.name, 'A');
      step();
      await until(() => state().existing.length == 3);
      await until(() => state().existing.first.referenceCount == 1);
      expect([for (final e in state().existing) e.name], ['A', 'B', 'C']);
    });

    test('reels made in the same instant go by id, oldest first', () async {
      await reels.create('Second made');
      await reels.create('Third made');
      await reels.create('Fourth made');
      step();
      await until(() => state().existing.length == 3);
      expect(
        [for (final e in state().existing) e.name],
        ['Second made', 'Third made', 'Fourth made'],
      );
    });

    test('existingNames is the names of existing, in the same order', () async {
      await reels.create('Goa');
      h.media.clock.advance(const Duration(minutes: 1));
      await reels.create('Paris');
      step();
      await until(() => state().existing.length == 2);
      expect(state().existingNames, ['Goa', 'Paris']);
      expect(state().hasExistingReels, isTrue);
    });

    test('a reel made while the step is open appears, and a new '
        'reference moves its count', () async {
      step();
      await settle();
      expect(state().existing, isEmpty);
      final goa = await reels.create('Goa');
      await until(() => state().existing.length == 1);
      expect(state().existing.single, (name: 'Goa', referenceCount: 0));
      await addRefs(goa.id, 2);
      await until(() => state().existing.single.referenceCount == 2);
      await reels.delete(goa.id);
      await until(() => state().existing.isEmpty);
    });

    test('a reel is never shown with a count that is not yet read', () async {
      final goa = await reels.create('Goa');
      await addRefs(goa.id, 3);
      final seen = <ReelsStepState>[];
      container
        ..listen(reelsStepControllerProvider, (_, next) => seen.add(next))
        ..listen(onboardingControllerProvider, (_, _) {})
        ..read(reelsStepControllerProvider);
      await until(() => state().existing.isNotEmpty);
      await settle();
      expect(state().existing.single.referenceCount, 3);
      for (final s in seen) {
        for (final e in s.existing) {
          expect(e.referenceCount, 3, reason: 'no 0 before the real count');
        }
      }
    });

    test('a count read that fails shows the reels with 0', () async {
      await reels.create('Goa');
      final c = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          reelsRepositoryProvider.overrideWithValue(reels),
          referencesRepositoryProvider.overrideWithValue(
            _FailingCounts(h.media.db, h.media.clock),
          ),
          onboardingControllerProvider.overrideWith(() => onboarding),
        ],
      )..listen(reelsStepControllerProvider, (_, _) {});
      await until(
        () => c.read(reelsStepControllerProvider).existing.isNotEmpty,
      );
      expect(c.read(reelsStepControllerProvider).existing.single, (
        name: 'Goa',
        referenceCount: 0,
      ));
    });

    test('ideas still skip the names of existing reels', () async {
      await reels.create('Food');
      step();
      await until(() => state().existing.isNotEmpty);
      expect(state().ideas, isNot(contains('Food')));
    });

    test('state equality counts the existing reels', () {
      const a = ReelsStepState(existing: [(name: 'Goa', referenceCount: 1)]);
      const b = ReelsStepState(existing: [(name: 'Goa', referenceCount: 1)]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const ReelsStepState(existing: [(name: 'Goa', referenceCount: 2)]),
        ),
      );
      expect(a.existingNames, ['Goa']);
    });

    test('a refused Create reads the reels again with their counts', () async {
      final controller = withNames(['Goa']);
      final goa = await reels.create('goa');
      await addRefs(goa.id, 2);
      await controller.create();
      expect(state().error, ReelNameProblem.duplicate);
      await until(() => state().existing.isNotEmpty);
      await until(() => state().existing.single.referenceCount == 2);
    });
  });

  group('counts that never answer (M21, D-168)', () {
    final goa = Reel(
      id: 7,
      name: 'Goa',
      status: ReelStatus.collecting,
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );

    /// Runs [body] in fake time with the reels read at once and the counts
    /// stream held open by [silent].
    void run(
      void Function(
        FakeAsync async,
        ProviderContainer c,
        StreamController<Map<int, int>> silent,
        List<String> logged,
      )
      body, {
      bool reelsAnswer = true,
    }) {
      fakeAsync((async) {
        final silent = StreamController<Map<int, int>>();
        final logged = <String>[];
        final previous = Logger.root.level;
        Logger.root.level = Level.ALL;
        final sub = Logger.root.onRecord.listen(
          (r) => logged.add('${r.loggerName} ${r.message} ${r.error}'),
        );
        final c = ProviderContainer(
          overrides: [
            ...h.overrides,
            reelsRepositoryProvider.overrideWithValue(
              _FixedReels(h.media.db, h.media.clock, [
                goa,
              ], answer: reelsAnswer),
            ),
            referencesRepositoryProvider.overrideWithValue(
              _SilentCounts(h.media.db, h.media.clock, silent.stream),
            ),
            onboardingControllerProvider.overrideWith(() => onboarding),
          ],
        )..listen(reelsStepControllerProvider, (_, _) {});
        async.flushMicrotasks();
        try {
          body(async, c, silent, logged);
        } finally {
          c.dispose();
          unawaited(silent.close());
          unawaited(sub.cancel());
          Logger.root.level = previous;
          async.flushMicrotasks();
        }
      });
    }

    ReelsStepState stateIn(ProviderContainer c) =>
        c.read(reelsStepControllerProvider);

    test('the reels show with count 0 after the step-read limit, logged, '
        'and the duplicate check and Continue work', () {
      run((async, c, silent, logged) {
        async.elapse(stepReadLimit - const Duration(milliseconds: 100));
        expect(stateIn(c).existing, isEmpty, reason: 'still within the limit');
        expect(stateIn(c).hasExistingReels, isFalse);

        async
          ..elapse(const Duration(milliseconds: 200))
          ..flushMicrotasks();

        expect(stateIn(c).existing, [(name: 'Goa', referenceCount: 0)]);
        expect(stateIn(c).hasExistingReels, isTrue);
        final notifier = c.read(reelsStepControllerProvider.notifier);
        expect(notifier.add('goa'), isFalse);
        expect(stateIn(c).error, ReelNameProblem.duplicate);
        expect(stateIn(c).clashingName, 'Goa');
        expect(
          logged.where((l) => l.contains('reelsStep')),
          hasLength(1),
          reason: 'logged once',
        );
        expect(logged.join('\n'), isNot(contains('Goa')));
      });
    });

    test('counts that arrive after the limit update the rows', () {
      run((async, c, silent, logged) {
        async.elapse(stepReadLimit + const Duration(seconds: 1));
        expect(stateIn(c).existing.single.referenceCount, 0);

        silent.add({7: 3});
        async.flushMicrotasks();

        expect(stateIn(c).existing, [(name: 'Goa', referenceCount: 3)]);
      });
    });

    test('counts that answer in time show the reels at once, with no limit '
        'left running, nothing logged', () {
      run((async, c, silent, logged) {
        async.elapse(const Duration(seconds: 1));
        expect(stateIn(c).existing, isEmpty);

        silent.add({7: 2});
        async.flushMicrotasks();

        expect(stateIn(c).existing, [(name: 'Goa', referenceCount: 2)]);
        expect(async.pendingTimers, isEmpty, reason: 'the limit was cancelled');
        async.elapse(stepReadLimit * 2);
        expect(stateIn(c).existing.single.referenceCount, 2);
        expect(logged.where((l) => l.contains('reelsStep')), isEmpty);
      });
    });

    test('the limit does not outlive the step', () {
      run((async, c, silent, logged) {
        c.dispose();
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
        async.elapse(stepReadLimit * 2);
        expect(logged.where((l) => l.contains('reelsStep')), isEmpty);
      });
    });

    test('reels that never answer show nothing, limit or not', () {
      run((async, c, silent, logged) {
        async.elapse(stepReadLimit * 2);

        expect(stateIn(c).existing, isEmpty);
      }, reelsAnswer: false);
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

/// A reels repository whose `watchAll` answers [reels] at once (or never).
class _FixedReels extends ReelsRepository {
  // ignore: use_super_parameters, the same reason
  _FixedReels(AppDatabase db, Clock clock, this.reels, {this.answer = true})
    : super(db, clock);

  final List<Reel> reels;
  final bool answer;

  @override
  Stream<List<Reel>> watchAll() =>
      answer ? Stream.value(reels) : const Stream<List<Reel>>.empty();
}

/// A references repository whose `watchCounts` is [counts], held by a test.
class _SilentCounts extends ReferencesRepository {
  // ignore: use_super_parameters, the same reason
  _SilentCounts(AppDatabase db, Clock clock, this.counts) : super(db, clock);

  final Stream<Map<int, int>> counts;

  @override
  Stream<Map<int, int>> watchCounts() => counts;
}

/// A references repository whose `watchCounts` always fails.
class _FailingCounts extends ReferencesRepository {
  // ignore: use_super_parameters, the same reason
  _FailingCounts(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Stream<Map<int, int>> watchCounts() => Stream.error(StateError('no read'));
}
