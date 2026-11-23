import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/reference_url.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/view_models/reel_form_controller.dart';

import '../../../support/vm_harness.dart';

/// A repository that counts its writes and can be made to fail.
class _CountingReels extends ReelsRepository {
  // The parameters of ReelsRepository are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  _CountingReels(AppDatabase db, Clock clock) : super(db, clock);

  int creates = 0;
  int renames = 0;
  int descriptions = 0;
  int statuses = 0;
  int createsWithReference = 0;
  Error? failWith;

  /// When set, the next [watchAll] shows this list (a reel made a moment
  /// after the form looked).
  List<Reel>? staleOnce;

  /// When set, the [watchAll] after the stale one fails (the read the form
  /// does when the repository refuses a name).
  Error? failAfterStale;
  bool _wasStale = false;

  @override
  Stream<List<Reel>> watchAll() {
    if (_wasStale && failAfterStale != null) {
      _wasStale = false;
      return Stream.error(failAfterStale!);
    }
    final stale = staleOnce;
    if (stale != null) _wasStale = true;
    if (stale == null) return super.watchAll();
    staleOnce = null;
    return Stream.value(stale);
  }

  @override
  Future<Reel> create(String name, {String? description}) async {
    creates++;
    final failure = failWith;
    if (failure != null) throw failure;
    return await super.create(name, description: description);
  }

  @override
  Future<Reel> createWithReference(
    String name, {
    required String url,
    String? description,
    String? label,
  }) async {
    createsWithReference++;
    return await super.createWithReference(
      name,
      url: url,
      description: description,
      label: label,
    );
  }

  @override
  Future<void> rename(int id, String name) async {
    renames++;
    await super.rename(id, name);
  }

  @override
  Future<void> setDescription(int id, String? description) async {
    descriptions++;
    await super.setDescription(id, description);
  }

  @override
  Future<void> setStatus(int id, ReelStatus status) async {
    statuses++;
    await super.setStatus(id, status);
  }
}

/// A references repository that counts its adds and can be made to fail.
class _CountingReferences extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _CountingReferences(AppDatabase db, Clock clock) : super(db, clock);

  int adds = 0;
  Error? failWith;

  @override
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    adds++;
    final failure = failWith;
    if (failure != null) throw failure;
    return await super.add(reelId, rawUrl, label: label);
  }
}

void main() {
  late VmHarness h;
  late _CountingReels reels;
  late _CountingReferences refs;
  late ProviderContainer container;

  setUp(() {
    h = VmHarness();
    reels = _CountingReels(h.media.db, h.media.clock);
    refs = _CountingReferences(h.media.db, h.media.clock);
    container = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        reelsRepositoryProvider.overrideWithValue(reels),
        referencesRepositoryProvider.overrideWithValue(refs),
      ],
    );
  });

  /// The form for [reelId], kept alive for the test (the sheet's `watch`).
  ReelFormController form(int? reelId) {
    final provider = reelFormControllerProvider(reelId);
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier);
  }

  ReelFormState stateOf(int? reelId) =>
      container.read(reelFormControllerProvider(reelId));

  Future<List<Reel>> allReels() => reels.watchAll().first;

  Future<List<ReelReference>> savedLinks(int reelId) =>
      refs.watchForReel(reelId).first;

  group('create', () {
    test('empty name error', () async {
      final saved = await form(null).save(name: '   ');
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.empty);
      expect(await allReels(), isEmpty);
      expect(reels.creates, 0);
    });

    test('41 characters error', () async {
      final saved = await form(null).save(name: 'x' * 41);
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.tooLong);
      expect(await allReels(), isEmpty);
    });

    test('40 emoji ok', () async {
      final saved = await form(null).save(name: '🎬' * 40);
      expect(saved, isNotNull);
      expect(saved!.name, '🎬' * 40);
      expect(stateOf(null).hasErrors, isFalse);
      expect((await allReels()).single.name, '🎬' * 40);
    });

    test('41 emoji error', () async {
      expect(await form(null).save(name: '🎬' * 41), isNull);
      expect(stateOf(null).nameError, ReelNameProblem.tooLong);
    });

    test('duplicate name error ignores case and edge spaces', () async {
      await reels.create('London Food');
      final creates = reels.creates;
      final saved = await form(null).save(name: '  LONDON food ');
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.duplicate);
      // The other reel's name as stored, not what was typed.
      expect(stateOf(null).clashingName, 'London Food');
      expect(await allReels(), hasLength(1));
      // The form found it itself: the repository's backstop never ran.
      expect(reels.creates, creates);
    });

    test('a reel made a moment ago counts as a duplicate', () async {
      final first = form(null);
      expect(await first.save(name: 'Goa'), isNotNull);
      final second = await form(null).save(name: 'goa');
      expect(second, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.duplicate);
    });

    test('the repository refuses a name taken after the form looked', () async {
      await reels.create('Goa');
      // The form's own check sees no reels, but the write finds Goa.
      reels.staleOnce = [];
      final saved = await form(null).save(name: 'goa');
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.duplicate);
      // The backstop looked again and names the reel as stored.
      expect(stateOf(null).clashingName, 'Goa');
      expect(await allReels(), hasLength(1));
    });

    test('a failed re-read after the repository refused a name still '
        'unblocks the form', () async {
      await reels.create('Goa');
      reels
        ..staleOnce = []
        ..failAfterStale = StateError('disk full');
      final controller = form(null);

      await expectLater(
        controller.save(name: 'goa'),
        throwsA(isA<StateError>()),
      );

      expect(stateOf(null).saving, isFalse);
      // The form takes a new save.
      reels.failAfterStale = null;
      expect(await controller.save(name: 'Paris'), isNotNull);
    });

    test('a name and a description problem are both reported', () async {
      final saved = await form(null)
          .save(name: '', description: 'x' * (reelDescriptionMaxLength + 1));
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.empty);
      expect(stateOf(null).descriptionError, ReelDescriptionProblem.tooLong);
      expect(await allReels(), isEmpty);
    });

    test('a 1000 character description is fine', () async {
      final saved = await form(null)
          .save(name: 'Goa', description: 'ä' * reelDescriptionMaxLength);
      expect(saved!.description, 'ä' * reelDescriptionMaxLength);
    });

    test('blank description saved as null', () async {
      final saved = await form(null).save(name: 'Goa', description: '  \n ');
      expect(saved, isNotNull);
      expect(saved!.description, isNull);
      expect((await allReels()).single.description, isNull);
    });

    test('a new reel starts as Collecting', () async {
      final saved = await form(null)
          .save(name: 'Goa', status: ReelStatus.published);
      expect(saved!.status, ReelStatus.collecting);
    });

    test('double Save creates one reel', () async {
      final controller = form(null);
      final first = controller.save(name: 'Goa');
      final second = controller.save(name: 'Goa');
      // The second call is the first call's own future.
      expect(identical(first, second), isTrue);
      expect(stateOf(null).saving, isTrue);
      final saved = await Future.wait([first, second]);
      expect(saved[0]!.id, saved[1]!.id);
      expect(reels.creates, 1);
      expect(await allReels(), hasLength(1));
      expect(stateOf(null).saving, isFalse);
    });

    test('Save works again once the first one is done', () async {
      final controller = form(null);
      expect(await controller.save(name: 'Goa'), isNotNull);
      expect(await controller.save(name: 'Paris'), isNotNull);
      expect(reels.creates, 2);
    });

    test('Save works again after a refused one', () async {
      final controller = form(null);
      expect(await controller.save(name: ''), isNull);
      expect(await controller.save(name: 'Goa'), isNotNull);
      expect(stateOf(null).hasErrors, isFalse);
    });

    test('an unexpected failure is rethrown and unblocks the form', () async {
      reels.failWith = StateError('disk full');
      final controller = form(null);
      await expectLater(
        controller.save(name: 'Goa'),
        throwsA(isA<StateError>()),
      );
      expect(stateOf(null).saving, isFalse);
      reels.failWith = null;
      expect(await controller.save(name: 'Goa'), isNotNull);
      expect(reels.creates, 2);
    });

    test('clearErrors forgets the errors', () async {
      final controller = form(null);
      await controller.save(name: '');
      expect(stateOf(null).hasErrors, isTrue);
      controller.clearErrors();
      expect(stateOf(null).hasErrors, isFalse);
    });

    test('a save that outlives the sheet still finishes', () async {
      final provider = reelFormControllerProvider(null);
      final subscription = container.listen(provider, (_, _) {});
      final pending = container.read(provider.notifier).save(name: 'Goa');
      subscription.close();
      // The sheet is gone and took the provider along.
      expect(await pending, isNotNull);
      expect(await allReels(), hasLength(1));
    });
  });

  group('edit', () {
    late Reel goa;

    setUp(() async {
      goa = await reels.create('Goa', description: 'beaches');
    });

    test('editing keeps its own name without a clash', () async {
      final saved = await form(goa.id)
          .save(name: 'Goa', description: 'beaches');
      expect(saved, isNotNull);
      expect(stateOf(goa.id).hasErrors, isFalse);
      // Nothing changed, so nothing was written.
      expect(reels.renames + reels.descriptions + reels.statuses, 0);
    });

    test('its own name in another case is fine and is saved', () async {
      final saved = await form(goa.id)
          .save(name: ' GOA ', description: 'beaches');
      expect(saved!.name, 'GOA');
      expect(stateOf(goa.id).hasErrors, isFalse);
    });

    test(
      'a reel sharing its name with a restored one can still be edited',
      () async {
        // Delete Goa, make a new Goa, then Undo the delete: two reels are
        // called Goa (D-80: the restore wins over the rule).
        final record = await reels.delete(goa.id);
        final second = await reels.create('Goa');
        await reels.undo(record);
        expect((await allReels()).map((r) => r.name), ['Goa', 'Goa']);

        for (final id in [goa.id, second.id]) {
          final saved = await form(id)
              .save(name: 'Goa', description: 'new beaches $id');
          expect(saved, isNotNull, reason: 'reel $id');
          expect(stateOf(id).hasErrors, isFalse, reason: 'reel $id');
          expect((await reels.getById(id))!.description, 'new beaches $id');
        }
        // Its own name in another case, and the status, save too.
        final saved = await form(second.id)
            .save(name: ' goa ', status: ReelStatus.ready);
        expect(saved!.name, 'goa');
        expect(saved.status, ReelStatus.ready);
        expect((await reels.getById(goa.id))!.name, 'Goa');
      },
    );

    test('a different reel has that name: a clash', () async {
      await reels.create('Paris');
      final saved = await form(goa.id).save(name: 'paris');
      expect(saved, isNull);
      expect(stateOf(goa.id).nameError, ReelNameProblem.duplicate);
      expect(stateOf(goa.id).clashingName, 'Paris');
      expect((await reels.getById(goa.id))!.name, 'Goa');
    });

    test('edit saves name, description and status in one go', () async {
      final saved = await form(goa.id).save(
        name: 'Goa 2027',
        description: 'beaches and food',
        status: ReelStatus.ready,
      );
      expect(saved!.name, 'Goa 2027');
      expect(saved.description, 'beaches and food');
      expect(saved.status, ReelStatus.ready);
      final stored = (await reels.getById(goa.id))!;
      expect(stored.name, 'Goa 2027');
      expect(stored.description, 'beaches and food');
      expect(stored.status, ReelStatus.ready);
    });

    test('clearing the description stores null', () async {
      final saved = await form(goa.id).save(name: 'Goa', description: '');
      expect(saved!.description, isNull);
    });

    test('a refused name saves nothing else', () async {
      await reels.create('Paris');
      await form(goa.id).save(
        name: 'Paris',
        description: 'changed',
        status: ReelStatus.published,
      );
      final stored = (await reels.getById(goa.id))!;
      expect(stored.description, 'beaches');
      expect(stored.status, ReelStatus.collecting);
    });

    test('a reel that is gone fails the save', () async {
      await reels.delete(goa.id);
      await expectLater(
        form(goa.id).save(name: 'Goa'),
        throwsA(isA<StateError>()),
      );
      expect(stateOf(goa.id).saving, isFalse);
    });

    test('double Save writes once', () async {
      final controller = form(goa.id);
      final first = controller.save(name: 'Goa 2', status: ReelStatus.ready);
      final second = controller.save(name: 'Goa 2', status: ReelStatus.ready);
      await Future.wait([first, second]);
      expect(reels.renames, 1);
      expect(reels.statuses, 1);
    });
  });

  group('create with a link (Phase 9A)', () {
    const reelLink = 'https://www.instagram.com/reel/ABC123/?igsh=xyz';
    const cleaned = 'https://www.instagram.com/p/ABC123/';

    test('a link makes the reel and its reference in one save', () async {
      final saved = await form(null)
          .save(name: 'Goa', description: 'beaches', link: reelLink);
      expect(saved, isNotNull);
      expect(saved!.description, 'beaches');
      expect(stateOf(null).hasErrors, isFalse);
      expect(reels.createsWithReference, 1);
      expect(reels.creates, 0);
      final links = await savedLinks(saved.id);
      expect(links.map((r) => r.url), [cleaned]);
      expect(links.single.label, isNull);
    });

    test('a caption with a link in it gives the link', () async {
      final saved = await form(null)
          .save(name: 'Goa', link: 'Love this $reelLink so much!');
      expect((await savedLinks(saved!.id)).single.url, cleaned);
    });

    test('a bare address is given its https://', () async {
      final saved = await form(null)
          .save(name: 'Goa', link: '  instagram.com/reel/ABC123/. ');
      expect((await savedLinks(saved!.id)).single.url, cleaned);
    });

    test('"hello world" is the link error; no reel is made', () async {
      final saved = await form(null).save(name: 'Goa', link: 'hello world');
      expect(saved, isNull);
      expect(stateOf(null).linkError, ReferenceUrlProblem.invalid);
      expect(stateOf(null).nameError, isNull);
      expect(stateOf(null).hasErrors, isTrue);
      expect(await allReels(), isEmpty);
      expect(reels.creates + reels.createsWithReference, 0);
    });

    for (final bad in [
      'hello',
      'https://hello',
      'ftp://example.com/a',
      'user@example.com',
      '3.5',
      'a..com',
    ]) {
      test('"$bad" is not a link', () async {
        expect(await form(null).save(name: 'Goa', link: bad), isNull);
        expect(stateOf(null).linkError, ReferenceUrlProblem.invalid);
        expect(await allReels(), isEmpty);
      });
    }

    test('an empty name and a bad link are both shown at once', () async {
      final saved = await form(null).save(name: '', link: 'hello world');
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.empty);
      expect(stateOf(null).linkError, ReferenceUrlProblem.invalid);
    });

    test('name, description and link are all found in one save', () async {
      final saved = await form(null).save(
        name: 'x' * 41,
        description: 'y' * (reelDescriptionMaxLength + 1),
        link: 'nope nope',
      );
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.tooLong);
      expect(stateOf(null).descriptionError, ReelDescriptionProblem.tooLong);
      expect(stateOf(null).linkError, ReferenceUrlProblem.invalid);
    });

    test('a clashing name and a bad link are both shown', () async {
      await reels.create('Goa');
      final saved = await form(null).save(name: 'goa', link: 'hello world');
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.duplicate);
      expect(stateOf(null).clashingName, 'Goa');
      expect(stateOf(null).linkError, ReferenceUrlProblem.invalid);
    });

    test(
      'a good link with a bad name saves nothing, with no link error',
      () async {
        final saved = await form(null).save(name: '  ', link: reelLink);
        expect(saved, isNull);
        expect(stateOf(null).nameError, ReelNameProblem.empty);
        expect(stateOf(null).linkError, isNull);
        expect(await allReels(), isEmpty);
        expect(reels.createsWithReference, 0);
      },
    );

    test('an empty or blank link is no link: a plain reel', () async {
      for (final (i, blank) in <String?>[null, '', '   \n '].indexed) {
        final saved = await form(null).save(name: 'Reel $i', link: blank);
        expect(saved, isNotNull, reason: 'link $blank');
        expect(await savedLinks(saved!.id), isEmpty);
      }
      expect(reels.createsWithReference, 0);
      expect(reels.creates, 3);
    });

    test('the repository refusing the name after the form looked shows the '
        'name error and makes no reel', () async {
      await reels.create('Goa');
      reels.staleOnce = [];
      final saved = await form(null).save(name: 'goa', link: reelLink);
      expect(saved, isNull);
      expect(stateOf(null).nameError, ReelNameProblem.duplicate);
      expect(await allReels(), hasLength(1));
      expect(await refs.watchAll().first, isEmpty);
    });

    test('the link error goes when the user types again, and a fixed link '
        'saves', () async {
      final controller = form(null);
      await controller.save(name: 'Goa', link: 'hello world');
      expect(stateOf(null).hasErrors, isTrue);
      controller.clearErrors();
      expect(stateOf(null).linkError, isNull);
      expect(stateOf(null).hasErrors, isFalse);
      expect(await controller.save(name: 'Goa', link: reelLink), isNotNull);
      expect(await savedLinks((await allReels()).single.id), hasLength(1));
    });

    test("the tag player's createWith makes the reel with no link", () async {
      final saved = await form(null)
          .save(name: 'Goa', createWith: (name) => reels.create(name));
      expect(saved, isNotNull);
      expect(reels.createsWithReference, 0);
      expect(await refs.watchAll().first, isEmpty);
    });
  });

  group('edit with a link (Phase 9A)', () {
    const reelLink = 'https://www.instagram.com/reel/ABC123/';
    const cleaned = 'https://www.instagram.com/p/ABC123/';
    late Reel goa;

    setUp(() async {
      goa = await reels.create('Goa', description: 'beaches');
    });

    test("a new link is added with the reel's own changes", () async {
      final saved = await form(goa.id).save(
        name: 'Goa 2027',
        description: 'beaches',
        status: ReelStatus.ready,
        link: reelLink,
      );
      expect(saved!.name, 'Goa 2027');
      expect(saved.status, ReelStatus.ready);
      expect((await savedLinks(goa.id)).map((r) => r.url), [cleaned]);
      expect(refs.adds, 1);
      // The reference touched the reel: the returned reel is the stored one.
      expect(saved.updatedAt, (await reels.getById(goa.id))!.updatedAt);
    });

    test('an already saved link saves the reel with no error', () async {
      await refs.add(goa.id, reelLink);
      refs.adds = 0;
      // The same page with tracking added: the same reference (D-58).
      final saved = await form(
        goa.id,
      ).save(name: 'Goa 2', description: 'beaches', link: '$reelLink?igsh=abc');
      expect(saved, isNotNull);
      expect(stateOf(goa.id).hasErrors, isFalse);
      expect(saved!.name, 'Goa 2');
      expect(refs.adds, 1);
      expect(await savedLinks(goa.id), hasLength(1));
    });

    test('an empty or blank link makes no reference call', () async {
      for (final blank in <String?>[null, '', '  ']) {
        await form(goa.id)
            .save(name: 'Goa', description: 'beaches', link: blank);
      }
      expect(refs.adds, 0);
      expect(await savedLinks(goa.id), isEmpty);
    });

    test('a bad link changes nothing, not even the name', () async {
      final saved = await form(goa.id).save(
        name: 'Goa 2027',
        description: 'new',
        status: ReelStatus.published,
        link: 'hello world',
      );
      expect(saved, isNull);
      expect(stateOf(goa.id).linkError, ReferenceUrlProblem.invalid);
      expect(reels.renames + reels.descriptions + reels.statuses, 0);
      expect(refs.adds, 0);
      final stored = (await reels.getById(goa.id))!;
      expect(stored.name, 'Goa');
      expect(stored.description, 'beaches');
      expect(stored.status, ReelStatus.collecting);
    });

    test('a clashing name and a bad link are both shown', () async {
      await reels.create('Paris');
      final saved = await form(goa.id).save(name: 'paris', link: 'nope nope');
      expect(saved, isNull);
      expect(stateOf(goa.id).nameError, ReelNameProblem.duplicate);
      expect(stateOf(goa.id).linkError, ReferenceUrlProblem.invalid);
    });

    test('a good link with a refused name adds nothing', () async {
      await reels.create('Paris');
      await form(goa.id).save(name: 'paris', link: reelLink);
      expect(refs.adds, 0);
      expect(await savedLinks(goa.id), isEmpty);
    });

    test('a database error adding the link: the reel stays saved, the error '
        'is rethrown and the form unblocks', () async {
      refs.failWith = StateError('disk full');
      final controller = form(goa.id);
      await expectLater(
        controller.save(
          name: 'Goa 2027',
          description: 'beaches',
          link: reelLink,
        ),
        throwsA(isA<StateError>()),
      );
      expect(stateOf(goa.id).saving, isFalse);
      expect((await reels.getById(goa.id))!.name, 'Goa 2027');
      expect(await savedLinks(goa.id), isEmpty);
      // Saving again adds the link.
      refs.failWith = null;
      expect(
        await controller.save(
          name: 'Goa 2027',
          description: 'beaches',
          link: reelLink,
        ),
        isNotNull,
      );
      expect(await savedLinks(goa.id), hasLength(1));
    });
  });
}
