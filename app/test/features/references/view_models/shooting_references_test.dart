import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/references/view_models/shooting_references.dart';

import '../../../support/vm_harness.dart';

/// A references repository whose stream of every reference fails.
class _FailingStream extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _FailingStream(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Stream<List<ReelReference>> watchAll() => Stream.error(StateError('boom'));
}

void main() {
  late VmHarness h;
  late ProviderContainer container;
  late ReelsRepository reels;
  late ReferencesRepository refs;
  var link = 0;
  var started = false;

  setUp(() {
    h = VmHarness();
    container = h.container;
    reels = container.read(reelsRepositoryProvider);
    refs = container.read(referencesRepositoryProvider);
    link = 0;
    started = false;
  });

  /// A reel made a minute after the one before it, so Home's order (newest
  /// first) is the reverse of the order they are made in.
  Future<Reel> reel(String name, {ReelStatus? status}) async {
    h.media.clock.advance(const Duration(minutes: 1));
    final made = await reels.create(name);
    if (status != null) await reels.setStatus(made.id, status);
    return made;
  }

  Future<ReelReference> save(Reel on) async {
    h.media.clock.advance(const Duration(minutes: 1));
    final result = await refs.add(
      on.id,
      'https://www.instagram.com/reel/R${link++}/',
    );
    return (result as ReferenceAdded).reference;
  }

  Future<List<ReferenceGroup>> groups() async {
    if (!started) {
      started = true;
      container
        ..listen(shootingReferencesProvider, (_, _) {})
        ..listen(reelSummariesProvider, (_, _) {});
    }
    await settle();
    return container.read(shootingReferencesProvider).value!;
  }

  Future<List<String>> names() async => [
    for (final g in await groups()) g.reel.reel.name,
  ];

  group('which reels, in which order', () {
    test('no reels at all: no groups, count 0', () async {
      expect(await groups(), isEmpty);
      expect(shootingReferenceCount(await groups()), 0);
    });

    test('Collecting reels come before Ready to edit, even when the Ready '
        'one is newer', () async {
      final older = await reel('Old collecting');
      final ready = await reel('New ready', status: ReelStatus.ready);
      await save(older);
      await save(ready);

      expect(await names(), ['Old collecting', 'New ready']);
    });

    test('Published reels are left out, with their references', () async {
      final live = await reel('Live');
      final done = await reel('Done', status: ReelStatus.published);
      await save(live);
      await save(done);

      expect(await names(), ['Live']);
      expect(shootingReferenceCount(await groups()), 1);
    });

    test('a reel with no reference is left out', () async {
      final bare = await reel('Bare');
      final kept = await reel('Kept');
      await save(kept);

      expect(await names(), ['Kept']);
      expect(bare.id, isNot(kept.id));
    });

    test("inside a status the order is Home's: newest reel first", () async {
      final first = await reel('First');
      final second = await reel('Second');
      final third = await reel('Third');
      for (final r in [first, second, third]) {
        await save(r);
      }
      final got = await names();
      final home = [
        for (final s in container.read(reelSummariesProvider).value!)
          s.reel.name,
      ];

      expect(got, ['Third', 'Second', 'First']);
      expect(got, home);
    });

    test("reels made in the same instant keep Home's tie order (highest "
        'id first)', () async {
      final a = await reels.create('A');
      final b = await reels.create('B');
      final c = await reels.create('C');
      for (final r in [a, b, c]) {
        await save(r);
      }
      final got = await names();
      final home = [
        for (final s in container.read(reelSummariesProvider).value!)
          s.reel.name,
      ];

      expect(got, ['C', 'B', 'A']);
      expect(got, home);
    });

    test("both statuses keep Home's order inside themselves", () async {
      final c1 = await reel('C1');
      final r1 = await reel('R1', status: ReelStatus.ready);
      final c2 = await reel('C2');
      final r2 = await reel('R2', status: ReelStatus.ready);
      for (final r in [c1, r1, c2, r2]) {
        await save(r);
      }

      expect(await names(), ['C2', 'C1', 'R2', 'R1']);
    });

    test("a group holds its reel's references, newest first", () async {
      final goa = await reel('Goa');
      final a = await save(goa);
      final b = await save(goa);
      final c = await save(goa);

      final only = (await groups()).single;
      expect([for (final r in only.references) r.id], [c.id, b.id, a.id]);
      expect(only.reel.reel.id, goa.id);
    });

    test('the count adds up the references of every group', () async {
      final a = await reel('A');
      final b = await reel('B', status: ReelStatus.ready);
      await save(a);
      await save(a);
      await save(b);

      expect(shootingReferenceCount(await groups()), 3);
    });
  });

  group('groupShootingReferences', () {
    ReelSummary summary(int id, ReelStatus status) => ReelSummary(
      reel: Reel(
        id: id,
        name: 'Reel $id',
        status: status,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      clipCount: 0,
      missingCount: 0,
      liveDurationMs: 0,
    );

    ReelReference reference(int id, int reelId) => ReelReference(
      id: id,
      reelId: reelId,
      url: 'https://example.com/$id',
      source: ReferenceSource.link,
      createdAt: DateTime.utc(2026),
    );

    test('a reference of a reel that is not listed is ignored', () {
      final result = groupShootingReferences(
        [summary(1, ReelStatus.collecting)],
        [reference(10, 1), reference(11, 99)],
      );

      expect(result.single.references.map((r) => r.id), [10]);
    });

    test('nothing in, nothing out', () {
      expect(groupShootingReferences(const [], const []), isEmpty);
      expect(
        groupShootingReferences([summary(1, ReelStatus.ready)], const []),
        isEmpty,
      );
    });

    test('the lists given are not changed', () {
      final summaries = [
        summary(1, ReelStatus.ready),
        summary(2, ReelStatus.collecting),
      ];
      final references = [reference(10, 1), reference(11, 2)];
      groupShootingReferences(summaries, references);

      expect(summaries.map((s) => s.reel.id), [1, 2]);
      expect(references.map((r) => r.id), [10, 11]);
    });
  });

  group('it follows the data live', () {
    test(
      'removing the last reference of the only group ends in no groups',
      () async {
        final goa = await reel('Goa');
        final only = await save(goa);
        expect(await names(), ['Goa']);

        await refs.delete(only.id);

        expect(await groups(), isEmpty);
        expect(shootingReferenceCount(await groups()), 0);
      },
    );

    test('removing one of two keeps the group with one', () async {
      final goa = await reel('Goa');
      await save(goa);
      final second = await save(goa);

      await refs.delete(second.id);

      expect((await groups()).single.references, hasLength(1));
    });

    test(
      'a new reference appears, and a first one makes a new group',
      () async {
        final goa = await reel('Goa');
        expect(await groups(), isEmpty);

        await save(goa);

        expect(await names(), ['Goa']);
      },
    );

    test('a reel moved to Published loses its group', () async {
      final goa = await reel('Goa');
      final london = await reel('London');
      await save(goa);
      await save(london);
      expect(await names(), ['London', 'Goa']);

      await reels.setStatus(goa.id, ReelStatus.published);

      expect(await names(), ['London']);
    });

    test(
      'a Published reel moved back to Collecting gets its group back',
      () async {
        final goa = await reel('Goa', status: ReelStatus.published);
        await save(goa);
        expect(await groups(), isEmpty);

        await reels.setStatus(goa.id, ReelStatus.collecting);

        expect(await names(), ['Goa']);
      },
    );

    test(
      'a Collecting reel moved to Ready goes after the Collecting ones',
      () async {
        final a = await reel('A');
        final b = await reel('B');
        await save(a);
        await save(b);
        expect(await names(), ['B', 'A']);

        await reels.setStatus(b.id, ReelStatus.ready);

        expect(await names(), ['A', 'B']);
      },
    );

    test('a deleted reel loses its group', () async {
      final goa = await reel('Goa');
      await save(goa);
      expect(await names(), ['Goa']);

      await reels.delete(goa.id);

      expect(await groups(), isEmpty);
    });

    test('a rename shows in the group', () async {
      final goa = await reel('Goa');
      await save(goa);
      await reels.rename(goa.id, 'Goa trip');

      expect(await names(), ['Goa trip']);
    });
  });

  group('a failure of the streams', () {
    test('is the underlying error, not a ParallelWaitError', () async {
      final failing = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          referencesRepositoryProvider.overrideWithValue(
            _FailingStream(h.media.db, h.media.clock),
          ),
        ],
      )..listen(shootingReferencesProvider, (_, _) {});
      await settle();

      final state = failing.read(shootingReferencesProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<StateError>());
      expect(state.error, isNot(isA<ParallelWaitError<Object?, Object?>>()));
      expect((state.error! as StateError).message, 'boom');
    });
  });
}
