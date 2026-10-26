import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/vn_repository.dart';
import 'package:taketray/domain/models/vn_copy.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);

late AppDatabase db;
late FixedClock clock;
late VnRepository repo;
late ReelsRepository reels;

VnCopy _copy(int reelId, int clipId, {String? fileName}) => VnCopy(
  reelId: reelId,
  clipId: clipId,
  copyMediaStoreId: 500 + clipId,
  fileName: fileName ?? '2026-10-2${clipId}_10-00-00.mp4',
  sizeBytes: 1000 * clipId,
);

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = VnRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  group('startSession', () {
    test('saves the folder name and the time', () async {
      final reel = await reels.create('Goa');

      final session = await repo.startSession(reel.id, 'Goa');

      expect(session.reelId, reel.id);
      expect(session.folderName, 'Goa');
      expect(session.createdAt, _t0);
      expect(await repo.sessionOf(reel.id), session);
    });

    test(
      'a second reel with the same name gets "Goa (2)", then "Goa (3)"',
      () async {
        final first = await reels.create('Goa');
        final second = await reels.create('Goa');
        final third = await reels.create('Goa');

        expect((await repo.startSession(first.id, 'Goa')).folderName, 'Goa');
        expect(
          (await repo.startSession(second.id, 'Goa')).folderName,
          'Goa (2)',
        );
        expect(
          (await repo.startSession(third.id, 'Goa')).folderName,
          'Goa (3)',
        );
      },
    );

    test('compares folder names without regard to case', () async {
      final first = await reels.create('Goa');
      final second = await reels.create('goa');
      await repo.startSession(first.id, 'Goa');

      expect((await repo.startSession(second.id, 'goa')).folderName, 'goa (2)');
    });

    test('a folder name is free again after its session ends', () async {
      final first = await reels.create('Goa');
      final second = await reels.create('Goa');
      await repo.startSession(first.id, 'Goa');
      await repo.endSession(first.id);

      expect((await repo.startSession(second.id, 'Goa')).folderName, 'Goa');
    });

    test('also avoids names already on disk', () async {
      final reel = await reels.create('Goa');

      final session = await repo.startSession(
        reel.id,
        'Goa',
        alsoTaken: {'goa', 'Goa (2)'},
      );

      expect(session.folderName, 'Goa (3)');
    });

    test('trims the base name; a blank one throws ArgumentError', () async {
      final reel = await reels.create('Goa');

      await expectLater(
        repo.startSession(reel.id, '  ​ '),
        throwsArgumentError,
      );
      expect(await repo.sessionOf(reel.id), isNull);

      expect((await repo.startSession(reel.id, '  Goa  ')).folderName, 'Goa');
    });

    test('an unknown reel throws StateError', () async {
      await expectLater(repo.startSession(999, 'Goa'), throwsStateError);
    });

    test(
      'a reel that already has a session throws StateError and keeps it',
      () async {
        final reel = await reels.create('Goa');
        final session = await repo.startSession(reel.id, 'Goa');

        await expectLater(
          repo.startSession(reel.id, 'Other'),
          throwsStateError,
        );
        expect(await repo.sessionOf(reel.id), session);
      },
    );
  });

  group('sessionOf', () {
    test('is null for a reel with no session', () async {
      final reel = await reels.create('Goa');
      expect(await repo.sessionOf(reel.id), isNull);
      expect(await repo.sessionOf(999), isNull);
    });
  });

  group('copies', () {
    test('addCopy and copiesOf round-trip, ordered by file name', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, 'Goa');
      final later = _copy(reel.id, 2, fileName: '2026-10-26_12-00-00.mp4');
      final earlier = _copy(reel.id, 1, fileName: '2026-10-26_08-00-00.mp4');

      await repo.addCopy(later);
      await repo.addCopy(earlier);

      expect(await repo.copiesOf(reel.id), [earlier, later]);
    });

    test("copiesOf only returns that reel's copies", () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, 'Goa');
      await repo.startSession(paris.id, 'Paris');
      await repo.addCopy(_copy(goa.id, 1));
      await repo.addCopy(_copy(paris.id, 2));

      expect((await repo.copiesOf(goa.id)).single.clipId, 1);
      expect(await repo.copiesOf(999), isEmpty);
    });

    test(
      'addCopy without a session throws StateError and saves nothing',
      () async {
        final reel = await reels.create('Goa');

        await expectLater(repo.addCopy(_copy(reel.id, 1)), throwsStateError);
        expect(await db.select(db.vnCopies).get(), isEmpty);
      },
    );

    test(
      'a second copy of the same clip in a session throws StateError',
      () async {
        final reel = await reels.create('Goa');
        await repo.startSession(reel.id, 'Goa');
        final first = _copy(reel.id, 1);
        await repo.addCopy(first);

        await expectLater(
          repo.addCopy(_copy(reel.id, 1, fileName: 'other.mp4')),
          throwsStateError,
        );
        expect(await repo.copiesOf(reel.id), [first]);
      },
    );

    test('a copy may name a clip that does not exist (D-54)', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, 'Goa');

      await repo.addCopy(_copy(reel.id, 77));

      expect((await repo.copiesOf(reel.id)).single.clipId, 77);
    });
  });

  group('endSession', () {
    test("deletes the session and its copies, not other reels'", () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, 'Goa');
      await repo.startSession(paris.id, 'Paris');
      await repo.addCopy(_copy(goa.id, 1));
      final keep = _copy(paris.id, 2);
      await repo.addCopy(keep);

      await repo.endSession(goa.id);

      expect(await repo.sessionOf(goa.id), isNull);
      expect(await repo.copiesOf(goa.id), isEmpty);
      expect(await repo.sessionOf(paris.id), isNotNull);
      expect(await repo.copiesOf(paris.id), [keep]);
    });

    test('an unknown reel does nothing', () async {
      await repo.endSession(999);
    });

    test('deleting the reel removes its session and copies too', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, 'Goa');
      await repo.addCopy(_copy(reel.id, 1));

      await reels.delete(reel.id);

      expect(await db.select(db.vnSessions).get(), isEmpty);
      expect(await db.select(db.vnCopies).get(), isEmpty);
    });
  });
}
