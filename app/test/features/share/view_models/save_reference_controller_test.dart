import 'dart:async';

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/shared_link_kind.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/share/view_models/save_reference_controller.dart';

import '../../../support/vm_harness.dart';

/// A references repository that counts its writes and can be held or failed.
class _Refs extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _Refs(AppDatabase db, Clock clock) : super(db, clock);

  int adds = 0;
  Object? failWith;

  /// Holds a write until it completes (a slow database).
  Completer<void>? hold;

  /// Holds the read of one reel's references until it completes.
  final Map<int, Completer<void>> holdRead = {};

  @override
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    adds++;
    await hold?.future;
    final failure = failWith;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    return await super.add(reelId, rawUrl, label: label);
  }

  @override
  Stream<List<ReelReference>> watchForReel(int reelId) {
    final gate = holdRead[reelId];
    if (gate == null) return super.watchForReel(reelId);
    return Stream.fromFuture(gate.future)
        .asyncExpand((_) => super.watchForReel(reelId));
  }
}

/// A reels repository that can be held or failed, and can make another
/// reel just before it creates one (a name taken after typing).
class _Reels extends ReelsRepository {
  // ignore: use_super_parameters, the parameters of ReelsRepository are private
  _Reels(AppDatabase db, Clock clock) : super(db, clock);

  int creates = 0;
  Object? failWith;
  Future<void> Function()? beforeCreate;
  Object? failList;

  /// Holds the list of reels until it completes.
  Completer<void>? holdList;

  @override
  Future<Reel> createWithReference(
    String name, {
    required String url,
    String? description,
    String? label,
  }) async {
    creates++;
    await beforeCreate?.call();
    final failure = failWith;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    return await super.createWithReference(
      name,
      url: url,
      description: description,
      label: label,
    );
  }

  @override
  Stream<List<Reel>> watchAll() {
    final failure = failList;
    if (failure != null) return Stream.error(failure);
    final gate = holdList;
    if (gate != null) {
      return Stream.fromFuture(gate.future)
          .asyncExpand((_) => super.watchAll());
    }
    return super.watchAll();
  }
}

void main() {
  late VmHarness h;
  late _Refs refs;
  late _Reels reels;
  late ProviderContainer container;
  late List<LogRecord> logs;
  late StreamSubscription<LogRecord> logSub;

  setUp(() {
    h = VmHarness();
    refs = _Refs(h.media.db, h.media.clock);
    reels = _Reels(h.media.db, h.media.clock);
    container = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        referencesRepositoryProvider.overrideWithValue(refs),
        reelsRepositoryProvider.overrideWithValue(reels),
      ],
    );
    logs = [];
    Logger.root.level = Level.ALL;
    logSub = Logger.root.onRecord.listen(logs.add);
    addTearDown(logSub.cancel);
  });

  SaveReferenceController controller() {
    container.listen(saveReferenceControllerProvider, (_, _) {});
    return container.read(saveReferenceControllerProvider.notifier);
  }

  SaveReferenceState state() => container.read(saveReferenceControllerProvider);

  Future<List<ReelReference>> stored(int reelId) =>
      refs.watchForReel(reelId).first;

  Future<List<ReelReference>> storedAll() => refs.watchAll().first;

  Future<int> makeReel(String name) async => (await reels.create(name)).id;

  const reelLink = 'https://www.instagram.com/reel/ABC/?igsh=zz';
  const storedReelLink = 'https://www.instagram.com/p/ABC/';

  group('start', () {
    test('a title and a link gives the form, from the first link', () async {
      await makeReel('Goa');
      await controller().start('Title https://vm.tiktok.com/x/');

      expect(state().step, SaveStep.form);
      expect(state().kind, SharedLinkKind.tiktokVideo);
      expect(state().url, 'https://vm.tiktok.com/x/');
      expect(state().mode, SaveMode.existing);
      expect(state().pickedReelId, isNull);
      expect(state().alreadyIn, isNull);
      expect(state().failed, isFalse);
    });

    test('the kind is read from the raw link, the url is normalised', () async {
      await controller().start('Look $reelLink wow');
      expect(state().kind, SharedLinkKind.instagramReel);
      expect(state().url, storedReelLink);
    });

    test('an Instagram post, video and profile keep their own kinds', () async {
      final c = controller();
      await c.start('https://www.instagram.com/p/AAA/');
      expect(state().kind, SharedLinkKind.instagramPost);
      await c.start('https://www.instagram.com/tv/AAA/');
      expect(state().kind, SharedLinkKind.instagramVideo);
      await c.start('https://www.instagram.com/someone/');
      expect(state().kind, SharedLinkKind.instagramProfile);
      await c.start('https://youtube.com/shorts/abc');
      expect(state().kind, SharedLinkKind.youtubeShort);
      await c.start('https://example.com/a');
      expect(state().kind, SharedLinkKind.link);
    });

    test(
      'several links: the first; a link in brackets and a full stop',
      () async {
        await controller().start(
          'a (https://youtu.be/AAA). b https://youtu.be/BBB',
        );
        expect(state().url, 'https://youtu.be/AAA');
        expect(state().kind, SharedLinkKind.youtubeVideo);
      },
    );

    for (final text in <String?>[
      'Best breakfast 🔥',
      null,
      '',
      '   \n\t ',
      'https://hello',
      'see https://hello.',
      'instagram.com/reel/ABC',
      'http://localhost/a',
    ]) {
      test('${text == null ? 'null' : '"$text"'} is not a link', () async {
        await makeReel('Goa');
        await controller().start(text);

        expect(state().step, SaveStep.notALink);
        expect(state().text, text);
        expect(state().url, '');
        // Nothing to save to: no write is possible from this state.
        await controller().save(name: 'X', label: '');
        expect(state().step, SaveStep.notALink);
        expect(await storedAll(), isEmpty);
        expect(refs.adds, 0);
        expect(reels.creates, 0);
      });
    }

    test(
      'a 10,000-character caption with a link at the end is found',
      () async {
        final caption = '${'word ' * 2000}https://www.tiktok.com/@a/video/1';
        expect(caption.length, greaterThan(10000));
        await controller().start(caption);
        expect(state().step, SaveStep.form);
        expect(state().url, 'https://www.tiktok.com/@a/video/1');
      },
    );

    test('a 10,000-character caption with no link is not a link', () async {
      await controller().start('word ' * 2000);
      expect(state().step, SaveStep.notALink);
    });

    test('no reels: it starts in New reel mode', () async {
      await controller().start('https://example.com/a');
      expect(state().mode, SaveMode.newReel);
    });

    test('with reels: it starts in Existing reel mode', () async {
      await makeReel('Goa');
      await controller().start('https://example.com/a');
      expect(state().mode, SaveMode.existing);
    });

    test('a failing read of the reels still gives the form', () async {
      reels.failList = StateError('closed');
      await controller().start('https://example.com/a');
      expect(state().step, SaveStep.form);
      expect(state().failed, isFalse);
      expect(logs.map((r) => r.message).join('\n'), contains('StateError'));
    });

    test('a second share starts afresh: nothing of the first stays', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start('https://example.com/a');
      await c.pick(goa);
      await c.save(name: '', label: 'First');
      expect(state().step, SaveStep.saved);

      await c.start('Other https://youtu.be/b');
      expect(state().step, SaveStep.form);
      expect(state().url, 'https://youtu.be/b');
      expect(state().pickedReelId, isNull);
      expect(state().savedReelId, isNull);
      expect(state().savedReelName, isNull);
      expect(state().savedLabel, isNull);
      expect(state().alreadyIn, isNull);
      expect(state().failed, isFalse);
      expect(state().saving, isFalse);
    });
  });

  group('start, when the sheet goes away mid-read', () {
    test(
      'a start whose sheet is gone does not touch the disposed state',
      () async {
        final gate = Completer<void>();
        reels.holdList = gate;
        final sub = container.listen(
          saveReferenceControllerProvider,
          (_, _) {},
        );
        final running = container
            .read(saveReferenceControllerProvider.notifier)
            .start(reelLink);
        sub.close();
        container.invalidate(saveReferenceControllerProvider);
        await Future<void>.delayed(Duration.zero);
        gate.complete();

        await expectLater(running, completes);
      },
    );
  });

  group('pick and mode', () {
    test('picking a reel that has the link sets alreadyIn', () async {
      final goa = await makeReel('Goa');
      await refs.add(goa, storedReelLink);
      final c = controller();
      await c.start(reelLink);

      await c.pick(goa);
      expect(state().pickedReelId, goa);
      expect(state().alreadyIn, 'Goa');
    });

    test('the link is compared by its normalised url', () async {
      final goa = await makeReel('Goa');
      await refs.add(goa, 'https://instagram.com/reel/ABC?utm_source=x');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);
      expect(state().alreadyIn, 'Goa');
    });

    test(
      'picking a reel without it, or another, takes alreadyIn away',
      () async {
        final goa = await makeReel('Goa');
        final lisbon = await makeReel('Lisbon');
        await refs.add(goa, storedReelLink);
        await refs.add(lisbon, 'https://example.com/other');
        final c = controller();
        await c.start(reelLink);

        await c.pick(goa);
        expect(state().alreadyIn, 'Goa');
        await c.pick(lisbon);
        expect(state().pickedReelId, lisbon);
        expect(state().alreadyIn, isNull);
      },
    );

    test(
      'a slow answer for a reel that is no longer picked is ignored',
      () async {
        final goa = await makeReel('Goa');
        final lisbon = await makeReel('Lisbon');
        await refs.add(goa, storedReelLink);
        refs.holdRead[goa] = Completer<void>();
        final c = controller();
        await c.start(reelLink);

        final slow = c.pick(goa);
        await c.pick(lisbon);
        refs.holdRead[goa]!.complete();
        await slow;

        expect(state().pickedReelId, lisbon);
        expect(state().alreadyIn, isNull);
      },
    );

    test(
      'a pick that cannot be read says nothing and does not crash',
      () async {
        final goa = await makeReel('Goa');
        refs.holdRead[goa] = Completer<void>();
        final c = controller();
        await c.start(reelLink);
        final picking = c.pick(goa);
        refs.holdRead[goa]!.completeError(StateError('x'));
        await picking;
        expect(state().pickedReelId, goa);
        expect(state().alreadyIn, isNull);
      },
    );

    test('a picked reel that is no longer in the list is forgotten, with its '
        'banner (M13)', () async {
      final goa = await makeReel('Goa');
      final lisbon = await makeReel('Lisbon');
      await refs.add(goa, storedReelLink);
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);
      expect(state().alreadyIn, 'Goa');

      c.dropPickIfGone({lisbon});

      expect(state().pickedReelId, isNull);
      expect(state().alreadyIn, isNull);
      expect(state().step, SaveStep.form);
      expect(state().url, storedReelLink);
    });

    test('a pick that is still in the list stays (M13)', () async {
      final goa = await makeReel('Goa');
      final lisbon = await makeReel('Lisbon');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);

      c.dropPickIfGone({goa, lisbon});
      expect(state().pickedReelId, goa);
      // Another reel gone is no reason to forget this pick.
      c.dropPickIfGone({goa});
      expect(state().pickedReelId, goa);
    });

    test('with nothing picked, a changed list changes nothing (M13)', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      final before = state();

      c.dropPickIfGone({goa});
      c.dropPickIfGone(const {});

      expect(identical(state(), before), isTrue);
    });

    test('an empty list forgets the pick (M13)', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);

      c.dropPickIfGone(const {});

      expect(state().pickedReelId, isNull);
    });

    test(
      'a slow answer for a pick that was forgotten is ignored (M13)',
      () async {
        final goa = await makeReel('Goa');
        await refs.add(goa, storedReelLink);
        refs.holdRead[goa] = Completer<void>();
        final c = controller();
        await c.start(reelLink);
        final slow = c.pick(goa);
        c.dropPickIfGone(const {});

        refs.holdRead[goa]!.complete();
        await slow;

        expect(state().pickedReelId, isNull);
        expect(state().alreadyIn, isNull);
      },
    );

    test(
      'once saved, a changed list leaves the saved state alone (M13)',
      () async {
        final goa = await makeReel('Goa');
        final c = controller();
        await c.start(reelLink);
        await c.pick(goa);
        await c.save(name: '', label: '');
        expect(state().step, SaveStep.saved);

        c.dropPickIfGone(const {});

        expect(state().step, SaveStep.saved);
        expect(state().savedReelId, goa);
      },
    );

    test(
      'setMode switches, and clears the name error and the failure',
      () async {
        await makeReel('Goa');
        final c = controller();
        await c.start(reelLink);
        c.setMode(SaveMode.newReel);
        expect(state().mode, SaveMode.newReel);
        await c.save(name: '', label: '');
        expect(state().nameError, ReelNameProblem.empty);

        c.setMode(SaveMode.existing);
        expect(state().mode, SaveMode.existing);
        expect(state().nameError, isNull);
        expect(state().clashingName, isNull);
      },
    );

    test('clearErrors forgets the name error and the failure only', () async {
      await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      c.setMode(SaveMode.newReel);
      await c.save(name: '', label: '');
      expect(state().nameError, isNotNull);

      c.clearErrors();
      expect(state().nameError, isNull);
      expect(state().url, storedReelLink);
      expect(state().mode, SaveMode.newReel);
    });
  });

  group('save to a new reel', () {
    test(
      'with no reels it creates a Collecting reel with the reference',
      () async {
        final c = controller();
        await c.start('Look $reelLink');
        expect(state().mode, SaveMode.newReel);

        await c.save(name: '  London Food ', label: ' Fast cuts ');

        expect(state().step, SaveStep.saved);
        expect(state().failed, isFalse);
        expect(state().saving, isFalse);
        final all = await reels.watchAll().first;
        expect(all, hasLength(1));
        expect(all.single.name, 'London Food');
        expect(all.single.status, ReelStatus.collecting);
        expect(state().savedReelId, all.single.id);
        expect(state().savedReelName, 'London Food');
        expect(state().savedLabel, 'Fast cuts');
        final rows = await stored(all.single.id);
        expect(rows.single.url, storedReelLink);
        expect(rows.single.label, 'Fast cuts');
      },
    );

    test('a blank label is no label', () async {
      final c = controller();
      await c.start('https://example.com/a');
      await c.save(name: 'Goa', label: '   ');
      expect(state().savedLabel, isNull);
      expect((await storedAll()).single.label, isNull);
    });

    test('an empty name shows on the field and saves nothing', () async {
      final c = controller();
      await c.start('https://example.com/a');
      await c.save(name: '   ', label: '');
      expect(state().step, SaveStep.form);
      expect(state().nameError, ReelNameProblem.empty);
      expect(state().failed, isFalse);
      expect(state().saving, isFalse);
      expect(reels.creates, 0);
      expect(await reels.watchAll().first, isEmpty);
    });

    test('a name over 40 characters shows on the field', () async {
      final c = controller();
      await c.start('https://example.com/a');
      await c.save(name: 'x' * 41, label: '');
      expect(state().nameError, ReelNameProblem.tooLong);
      expect(await reels.watchAll().first, isEmpty);
    });

    test(
      "a duplicate name shows the other reel's name, nothing saved",
      () async {
        await makeReel('London Food');
        final c = controller();
        await c.start('https://example.com/a');
        c.setMode(SaveMode.newReel);
        await c.save(name: '  london FOOD ', label: '');

        expect(state().step, SaveStep.form);
        expect(state().nameError, ReelNameProblem.duplicate);
        expect(state().clashingName, 'London Food');
        expect(reels.creates, 0);
        expect(await reels.watchAll().first, hasLength(1));
        expect(await storedAll(), isEmpty);
      },
    );

    test(
      "a name taken after typing: the repository's duplicate error",
      () async {
        final c = controller();
        await c.start('https://example.com/a');
        // Another engine saves the name between the check and the write.
        reels.beforeCreate = () async {
          reels.beforeCreate = null;
          await ReelsRepository(h.media.db, h.media.clock).create('Goa');
        };
        await c.save(name: 'goa', label: '');

        expect(state().step, SaveStep.form);
        expect(state().nameError, ReelNameProblem.duplicate);
        expect(state().clashingName, 'Goa');
        expect(state().failed, isFalse);
        expect(state().saving, isFalse);
        // Only the other reel: no half-made reel, no reference.
        expect(await reels.watchAll().first, hasLength(1));
        expect(await storedAll(), isEmpty);
      },
    );

    test('after a name problem the user can fix it and save', () async {
      await makeReel('Goa');
      final c = controller();
      await c.start('https://example.com/a');
      c.setMode(SaveMode.newReel);
      await c.save(name: 'Goa', label: '');
      expect(state().nameError, ReelNameProblem.duplicate);

      c.clearErrors();
      await c.save(name: 'Goa 2', label: '');
      expect(state().step, SaveStep.saved);
      expect(state().savedReelName, 'Goa 2');
    });

    test(
      'a database that is busy ends in failed, logging the type only',
      () async {
        final c = controller();
        await c.start('https://secret.example/private-path');
        reels.failWith = SqliteException(
          extendedResultCode: 5,
          message: 'database is locked',
        );
        await c.save(name: 'Secret Reel', label: 'Secret label');

        expect(state().step, SaveStep.form);
        expect(state().failed, isTrue);
        expect(state().saving, isFalse);
        expect(state().nameError, isNull);
        final logged = logs
            .map((r) => '${r.message} ${r.error ?? ''}')
            .join('\n');
        expect(logged, contains('SqliteException'));
        expect(logged, isNot(contains('Secret')));
        expect(logged, isNot(contains('secret')));
        expect(logged, isNot(contains('private-path')));
        expect(logged, isNot(contains('locked')));
      },
    );

    test('after a failure, saving again works', () async {
      final c = controller();
      await c.start('https://example.com/a');
      reels.failWith = SqliteException(
        extendedResultCode: 5,
        message: 'database is locked',
      );
      await c.save(name: 'Goa', label: '');
      expect(state().failed, isTrue);

      reels.failWith = null;
      await c.save(name: 'Goa', label: '');
      expect(state().failed, isFalse);
      expect(state().step, SaveStep.saved);
    });

    test('a label over 60 characters is a failure, nothing saved', () async {
      final c = controller();
      await c.start('https://example.com/a');
      await c.save(name: 'Goa', label: 'x' * 61);
      expect(state().failed, isTrue);
      expect(await reels.watchAll().first, isEmpty);
    });
  });

  group('save to an existing reel', () {
    test('adds the reference, says where, and the reel is touched', () async {
      final goa = await makeReel('Goa');
      final lisbon = await makeReel('Lisbon');
      final before = (await reels.getById(goa))!.updatedAt;
      h.media.clock.advance(const Duration(minutes: 5));
      final c = controller();
      await c.start('Look $reelLink');
      await c.pick(goa);

      await c.save(name: 'ignored', label: ' Slow pans ');

      expect(state().step, SaveStep.saved);
      expect(state().savedReelId, goa);
      expect(state().savedReelName, 'Goa');
      expect(state().savedLabel, 'Slow pans');
      final rows = await stored(goa);
      expect(rows.single.url, storedReelLink);
      expect(rows.single.label, 'Slow pans');
      expect(await stored(lisbon), isEmpty);
      // The reel is the most recently updated one (D-58).
      expect((await reels.getById(goa))!.updatedAt.isAfter(before), isTrue);
      expect((await reels.watchAll().first).first.id, goa);
      // No new reel was made by an existing-reel save.
      expect(reels.creates, 0);
    });

    test(
      'Save with nothing picked saves nothing and changes nothing',
      () async {
        await makeReel('Goa');
        final c = controller();
        await c.start(reelLink);
        await c.save(name: '', label: '');
        expect(state().step, SaveStep.form);
        expect(state().failed, isFalse);
        expect(refs.adds, 0);
      },
    );

    test(
      'a reel that already has the link: alreadyIn, nothing added',
      () async {
        final goa = await makeReel('Goa');
        await refs.add(goa, storedReelLink, label: 'First');
        final c = controller();
        await c.start(reelLink);
        await c.pick(goa);
        refs.adds = 0;

        await c.save(name: '', label: 'Second');

        expect(state().step, SaveStep.form);
        expect(state().alreadyIn, 'Goa');
        expect(state().failed, isFalse);
        final rows = await stored(goa);
        expect(rows, hasLength(1));
        expect(rows.single.label, 'First');
      },
    );

    test('the same link saved from two shares is one row', () async {
      final goa = await makeReel('Goa');
      // Two share screens over one database: both picked Goa before either
      // saved, so neither saw the other's row.
      final other = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          referencesRepositoryProvider.overrideWithValue(refs),
          reelsRepositoryProvider.overrideWithValue(reels),
        ],
      )..listen(saveReferenceControllerProvider, (_, _) {});
      final second = other.read(saveReferenceControllerProvider.notifier);
      final first = controller();
      await first.start(reelLink);
      await second.start(reelLink);
      await first.pick(goa);
      await second.pick(goa);
      expect(other.read(saveReferenceControllerProvider).alreadyIn, isNull);

      await first.save(name: '', label: 'First');
      await second.save(name: '', label: 'Second');

      expect(state().step, SaveStep.saved);
      final late = other.read(saveReferenceControllerProvider);
      expect(late.step, SaveStep.form);
      expect(late.alreadyIn, 'Goa');
      expect(late.failed, isFalse);
      final rows = await storedAll();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'First');
    });

    test('a double Save is one row (single-flight)', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);
      refs.hold = Completer<void>();

      final one = c.save(name: '', label: '');
      final two = c.save(name: '', label: '');
      expect(state().saving, isTrue);
      refs.hold!.complete();
      await Future.wait([one, two]);

      expect(refs.adds, 1);
      expect(await stored(goa), hasLength(1));
      expect(state().step, SaveStep.saved);
      expect(state().saving, isFalse);
    });

    test('a double Save of a new reel makes one reel', () async {
      final c = controller();
      await c.start(reelLink);
      final gate = Completer<void>();
      reels.beforeCreate = () => gate.future;

      final one = c.save(name: 'Goa', label: '');
      final two = c.save(name: 'Goa', label: '');
      gate.complete();
      await Future.wait([one, two]);

      expect(reels.creates, 1);
      expect(await reels.watchAll().first, hasLength(1));
      expect(await storedAll(), hasLength(1));
      expect(state().nameError, isNull);
    });

    test('Save works again after the first one ended', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);
      refs.failWith = StateError('x');
      await c.save(name: '', label: '');
      expect(state().failed, isTrue);

      refs.failWith = null;
      await c.save(name: '', label: '');
      expect(state().step, SaveStep.saved);
      expect(await stored(goa), hasLength(1));
    });

    test('the picked reel deleted before Save: failed, no row', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);
      await reels.delete(goa);

      await c.save(name: '', label: '');

      expect(state().step, SaveStep.form);
      expect(state().failed, isTrue);
      expect(state().saving, isFalse);
      expect(await storedAll(), isEmpty);
    });

    test('a busy database is failed, logging the type only', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start('https://secret.example/private');
      await c.pick(goa);
      refs.failWith = SqliteException(
        extendedResultCode: 5,
        message: 'database is locked',
      );

      await c.save(name: '', label: 'Secret label');

      expect(state().failed, isTrue);
      expect(state().step, SaveStep.form);
      final logged = logs
          .map((r) => '${r.message} ${r.error ?? ''}')
          .join('\n');
      expect(logged, contains('SqliteException'));
      expect(logged, isNot(contains('Secret')));
      expect(logged, isNot(contains('secret')));
      expect(logged, isNot(contains('Goa')));
      expect(logged, isNot(contains('locked')));
    });

    test('a failure goes at the next edit or pick', () async {
      final goa = await makeReel('Goa');
      final c = controller();
      await c.start(reelLink);
      await c.pick(goa);
      refs.failWith = StateError('x');
      await c.save(name: '', label: '');
      expect(state().failed, isTrue);

      c.clearErrors();
      expect(state().failed, isFalse);

      refs.failWith = StateError('x');
      await c.save(name: '', label: '');
      expect(state().failed, isTrue);
      await c.pick(goa);
      expect(state().failed, isFalse);
    });
  });
}
