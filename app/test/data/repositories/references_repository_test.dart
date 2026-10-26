import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/reference_url.dart';
import 'package:taketray/domain/rules/text_limits.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);

late AppDatabase db;
late FixedClock clock;
late ReferencesRepository repo;
late int goa;
late int paris;

void main() {
  setUp(() async {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = ReferencesRepository(db, clock);
    final reels = ReelsRepository(db, clock);
    goa = (await reels.create('Goa')).id;
    paris = (await reels.create('Paris')).id;
  });

  Future<ReelReference> added(int reelId, String url, {String? label}) async {
    final result = await repo.add(reelId, url, label: label);
    return (result as ReferenceAdded).reference;
  }

  group('add', () {
    test('saves a link with its source, label and time', () async {
      final ref = await added(
        goa,
        'https://www.youtube.com/watch?v=abc',
        label: '  Slow pans  ',
      );

      expect(ref.reelId, goa);
      expect(ref.url, 'https://www.youtube.com/watch?v=abc');
      expect(ref.source, ReferenceSource.youtube);
      expect(ref.label, 'Slow pans');
      expect(ref.createdAt, _t0);
      expect(await repo.watchForReel(goa).first, [ref]);
    });

    test('a blank or missing label is stored as no label', () async {
      expect((await added(goa, 'https://example.com/a')).label, isNull);
      expect(
        (await added(goa, 'https://example.com/b', label: '')).label,
        isNull,
      );
      expect(
        (await added(goa, 'https://example.com/c', label: ' ​ ')).label,
        isNull,
      );
    });

    test('the same Instagram reel shared with different tracking, host or '
        'path is already saved (Review Focus 1)', () async {
      final first = await added(
        goa,
        'https://www.instagram.com/reel/ABC123/?igsh=MWRzdG9tYQ%3D%3D',
      );
      expect(first.url, 'https://www.instagram.com/p/ABC123/');
      expect(first.source, ReferenceSource.instagram);

      for (final again in [
        'https://www.instagram.com/reel/ABC123/?igsh=ZGlmZmVyZW50',
        'https://instagram.com/reel/ABC123?utm_source=ig_web_copy_link',
        'http://m.instagram.com/someuser/reel/ABC123/',
        'https://www.instagram.com/p/ABC123',
        '  https://instagram.com/reels/ABC123/#top  ',
      ]) {
        final result = await repo.add(goa, again);
        expect(result, isA<ReferenceAlreadySaved>(), reason: again);
        expect((result as ReferenceAlreadySaved).existing, first);
      }
      expect(await repo.watchForReel(goa).first, [first]);
    });

    test('an already saved link keeps its original label and time', () async {
      final first = await added(goa, 'https://example.com/a', label: 'One');
      clock.advance(const Duration(hours: 1));

      final result = await repo.add(goa, 'https://example.com/a', label: 'Two');

      expect((result as ReferenceAlreadySaved).existing, first);
      expect((await repo.watchForReel(goa).first).single.label, 'One');
    });

    test('the same link in two different reels is saved in both', () async {
      final inGoa = await added(goa, 'https://example.com/a');
      final inParis = await added(paris, 'https://example.com/a');

      expect(inGoa.id, isNot(inParis.id));
      expect(await repo.watchForReel(goa).first, [inGoa]);
      expect(await repo.watchForReel(paris).first, [inParis]);
    });

    test(
      'a link that is not an http(s) link throws and saves nothing',
      () async {
        for (final bad in [
          '',
          'not a link',
          'ftp://example.com/a',
          'https://',
        ]) {
          await expectLater(
            repo.add(goa, bad),
            throwsA(
              isA<InvalidInputException>().having(
                (e) => e.problem,
                'problem',
                ReferenceUrlProblem.invalid,
              ),
            ),
            reason: bad,
          );
        }
        expect(await repo.watchForReel(goa).first, isEmpty);
      },
    );

    test('a 61-character label throws, 60 is accepted', () async {
      await expectLater(
        repo.add(goa, 'https://example.com/a', label: 'x' * 61),
        throwsA(
          isA<InvalidInputException>().having(
            (e) => e.problem,
            'problem',
            ReferenceLabelProblem.tooLong,
          ),
        ),
      );
      expect(await repo.watchForReel(goa).first, isEmpty);

      final ok = await added(goa, 'https://example.com/a', label: 'x' * 60);
      expect(ok.label, 'x' * 60);
    });

    test('60 emoji are accepted as a label, 61 are not', () async {
      expect(
        await added(goa, 'https://example.com/a', label: '🎬' * 60),
        isA<ReelReference>(),
      );
      await expectLater(
        repo.add(goa, 'https://example.com/b', label: '🎬' * 61),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('an unknown reel throws StateError and saves nothing', () async {
      await expectLater(
        repo.add(999, 'https://example.com/a'),
        throwsStateError,
      );
      expect(await db.select(db.reelReferences).get(), isEmpty);
    });
  });

  group('setLabel', () {
    test('sets, trims and clears a label', () async {
      final ref = await added(goa, 'https://example.com/a');

      await repo.setLabel(ref.id, '  Hook  ');
      expect((await repo.watchForReel(goa).first).single.label, 'Hook');

      await repo.setLabel(ref.id, '  ');
      expect((await repo.watchForReel(goa).first).single.label, isNull);

      await repo.setLabel(ref.id, 'Again');
      await repo.setLabel(ref.id, null);
      expect((await repo.watchForReel(goa).first).single.label, isNull);
    });

    test('a too long label throws and keeps the old one', () async {
      final ref = await added(goa, 'https://example.com/a', label: 'Keep');

      await expectLater(
        repo.setLabel(ref.id, 'x' * 61),
        throwsA(isA<InvalidInputException>()),
      );
      expect((await repo.watchForReel(goa).first).single.label, 'Keep');
    });

    test('an unknown id throws StateError', () async {
      await expectLater(repo.setLabel(999, 'x'), throwsStateError);
    });
  });

  group('delete', () {
    test('removes one reference and lets the link be saved again', () async {
      final ref = await added(goa, 'https://example.com/a');
      final other = await added(goa, 'https://example.com/b');

      await repo.delete(ref.id);

      expect(await repo.watchForReel(goa).first, [other]);
      expect(
        await repo.add(goa, 'https://example.com/a'),
        isA<ReferenceAdded>(),
      );
    });

    test('an unknown id does nothing', () async {
      final ref = await added(goa, 'https://example.com/a');
      await repo.delete(999);
      expect(await repo.watchForReel(goa).first, [ref]);
    });

    test('deleting the reel deletes its references', () async {
      await added(goa, 'https://example.com/a');
      await ReelsRepository(db, clock).delete(goa);
      expect(await db.select(db.reelReferences).get(), isEmpty);
    });
  });

  group('watchForReel', () {
    test('lists newest first, ties by newest id, and only that reel', () async {
      final a = await added(goa, 'https://example.com/a');
      clock.advance(const Duration(minutes: 1));
      final b = await added(goa, 'https://example.com/b');
      final c = await added(goa, 'https://example.com/c'); // same instant as b
      await added(paris, 'https://example.com/p');

      expect(await repo.watchForReel(goa).first, [c, b, a]);
    });

    test('emits again after a change', () async {
      final emitted = <int>[];
      final sub = repo
          .watchForReel(goa)
          .listen((refs) => emitted.add(refs.length));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await added(goa, 'https://example.com/a');
      await pumpEventQueue();

      expect(emitted, [0, 1]);
    });
  });

  group('watchCounts', () {
    test('maps reel id to how many references it has', () async {
      expect(await repo.watchCounts().first, isEmpty);

      await added(goa, 'https://example.com/a');
      await added(goa, 'https://example.com/b');
      await added(paris, 'https://example.com/a');

      expect(await repo.watchCounts().first, {goa: 2, paris: 1});
    });

    test('a reel drops out when its last reference is deleted', () async {
      final ref = await added(paris, 'https://example.com/a');
      await added(goa, 'https://example.com/a');

      await repo.delete(ref.id);

      expect(await repo.watchCounts().first, {goa: 1});
    });
  });
}
