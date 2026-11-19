import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/undo_record.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

// Undo of a reference remove (D-154): the row comes back with its id, label
// and createdAt; the reel's updatedAt goes back only while it still holds the
// value the remove wrote; and nothing is restored twice or into a reel that
// is gone.

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _hour = Duration(hours: 1);

late AppDatabase db;
late FixedClock clock;
late ReelsRepository reels;
late ReferencesRepository references;
late int goa;

void main() {
  setUp(() async {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    reels = ReelsRepository(db, clock);
    references = ReferencesRepository(db, clock);
    goa = (await reels.create('Goa')).id;
  });

  Future<ReelReference> added(String url, {String? label, int? reelId}) async =>
      ((await references.add(
        reelId ?? goa,
        url,
        label: label,
      )) as ReferenceAdded).reference;

  Future<DateTime> updatedAt(int reelId) async => (await (db.select(
    db.reels,
  )..where((r) => r.id.equals(reelId))).getSingle()).updatedAt;

  Future<List<ReelReference>> all() => references.watchAll().first;

  group('delete returns the record', () {
    test('every field of the reference and the reel touch', () async {
      final ref = await added('https://example.com/a', label: 'Slow pans');
      clock.advance(_hour);

      final record = await references.delete(ref.id);

      expect(record, isNotNull);
      expect(record!.reference, ref);
      expect(record.reference.createdAt, _t0);
      expect(
        record.touch,
        ReelTouch(reelId: goa, before: _t0, after: _t0.add(_hour)),
      );
      expect(record.isEmpty, isFalse);
    });

    test('an unknown id returns null and changes nothing', () async {
      final ref = await added('https://example.com/a');
      clock.advance(_hour);

      expect(await references.delete(999), isNull);

      expect(await all(), [ref]);
      expect(await updatedAt(goa), _t0);
    });

    test('deleting the same reference twice: the second is null', () async {
      final ref = await added('https://example.com/a');

      expect(await references.delete(ref.id), isNotNull);
      expect(await references.delete(ref.id), isNull);
    });
  });

  group('undo of a reference remove', () {
    test('brings back the same id, label and createdAt and the old '
        'updatedAt', () async {
      final ref = await added('https://example.com/a', label: 'Slow pans');
      await added('https://example.com/b');
      clock.advance(_hour);
      final before = await updatedAt(goa);
      final record = await references.delete(ref.id);
      expect(await updatedAt(goa), isNot(before));

      clock.advance(_hour);
      await reels.undoAll([record!]);

      final back = (await all()).singleWhere((r) => r.id == ref.id);
      expect(back, ref);
      expect(back.label, 'Slow pans');
      expect(back.createdAt, _t0);
      expect(await all(), hasLength(2));
      expect(await updatedAt(goa), before);
    });

    test('a reference with no label comes back with none', () async {
      final ref = await added('https://example.com/a');
      final record = await references.delete(ref.id);

      await reels.undo(record!);

      expect((await all()).single, ref);
    });

    test('a second undo of the same record changes nothing', () async {
      final ref = await added('https://example.com/a');
      final record = await references.delete(ref.id);

      await reels.undo(record!);
      await reels.undo(record);

      expect(await all(), [ref]);
    });

    test('undo after the same link was saved again keeps one row and does '
        'not throw', () async {
      final ref = await added('https://example.com/a', label: 'Old');
      final record = await references.delete(ref.id);
      clock.advance(_hour);
      final again = await added('https://example.com/a', label: 'New');

      await reels.undo(record!);

      expect(await all(), [again]);
      expect(again.id, isNot(ref.id));
    });

    test('undo after the same link was saved again leaves the reel '
        'updatedAt alone, even at the instant the remove wrote', () async {
      final ref = await added('https://example.com/a');
      clock.advance(_hour);
      final record = await references.delete(ref.id);
      // Saved again at the very instant the delete wrote: the reel holds
      // the value the touch guard looks for, so only the skip keeps it.
      await added('https://example.com/a');
      expect(await updatedAt(goa), _t0.add(_hour));

      await reels.undo(record!);

      expect(await updatedAt(goa), _t0.add(_hour));
    });

    test('undo after the reel was deleted restores nothing and does not '
        'throw', () async {
      final ref = await added('https://example.com/a');
      final record = await references.delete(ref.id);
      await reels.delete(goa);

      await reels.undo(record!);

      expect(await all(), isEmpty);
      expect(await db.select(db.reels).get(), isEmpty);
    });

    test("undo after the reel was renamed keeps the rename's "
        'updatedAt', () async {
      final ref = await added('https://example.com/a');
      clock.advance(_hour);
      final record = await references.delete(ref.id);
      clock.advance(_hour);
      await reels.rename(goa, 'Goa trip');
      final renamed = await updatedAt(goa);
      expect(renamed, _t0.add(_hour * 2));

      await reels.undo(record!);

      expect(await all(), [ref]);
      expect(await updatedAt(goa), renamed);
    });

    test(
      'undo after another reference was added keeps that updatedAt',
      () async {
        final ref = await added('https://example.com/a');
        clock.advance(_hour);
        final record = await references.delete(ref.id);
        clock.advance(_hour);
        await added('https://example.com/b');
        final touched = await updatedAt(goa);

        await reels.undo(record!);

        expect(await all(), hasLength(2));
        expect(await updatedAt(goa), touched);
      },
    );

    test('undoAll with a remove and an older record undoes both', () async {
      final a = await added('https://example.com/a');
      final b = await added('https://example.com/b');
      final first = await references.delete(a.id);
      final second = await references.delete(b.id);

      await reels.undoAll([first!, second!]);

      expect((await all()).map((r) => r.id).toSet(), {a.id, b.id});
    });
  });
}
