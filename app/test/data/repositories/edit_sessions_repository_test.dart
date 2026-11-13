import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

late AppDatabase db;
late FixedClock clock;
late EditSessionsRepository repo;
late ReelsRepository reels;

EditCopy _copy(
  int reelId,
  int clipId, {
  int? copyId,
  String? fileName,
  int? sizeBytes,
  DateTime? copiedAt,
}) => EditCopy(
  reelId: reelId,
  clipId: clipId,
  copyMediaStoreId: copyId ?? 500 + clipId,
  fileName: fileName ?? '2026-10-2${clipId}_10-00-00.mp4',
  sizeBytes: sizeBytes ?? 1000 * clipId,
  copiedAt: copiedAt ?? _t0,
);

/// A reel saved straight into the table, the way a backup import can bring
/// two reels with one name (`create` refuses a duplicate since D-84).
Future<ReelRow> sameNameReel(String name) => db
    .into(db.reels)
    .insertReturning(
      ReelsCompanion.insert(
        name: name,
        status: ReelStatus.collecting,
        createdAt: _t0,
        updatedAt: _t0,
      ),
    );

/// Every `sent_clips` row as (reel, clip, sentAt), sorted.
Future<List<(int, int, DateTime)>> sentRows() async {
  final rows = await db.select(db.sentClips).get();
  return [for (final r in rows) (r.reelId, r.clipId, r.sentAt)]
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
}

/// Collects every value of [stream] until the test ends.
List<T> collect<T>(Stream<T> stream) {
  final values = <T>[];
  final sub = stream.listen(values.add);
  addTearDown(sub.cancel);
  return values;
}

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = EditSessionsRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  group('startSession', () {
    test('saves the editor, the folder name and the time', () async {
      final reel = await reels.create('Goa');

      final session = await repo.startSession(reel.id, EditorApp.capcut, 'Goa');

      expect(
        session,
        EditSession(
          reelId: reel.id,
          editor: EditorApp.capcut,
          folderName: 'Goa',
          createdAt: _t0,
        ),
      );
      expect(await repo.sessionOf(reel.id), session);
    });

    test('stores every editor by its name', () async {
      for (final editor in EditorApp.values) {
        final reel = await reels.create('Reel ${editor.name}');
        await repo.startSession(reel.id, editor, 'Reel');

        expect((await repo.sessionOf(reel.id))!.editor, editor);
        final raw = await db
            .customSelect(
              'SELECT editor FROM vn_sessions WHERE reel_id = ${reel.id}',
            )
            .getSingle();
        expect(raw.read<String>('editor'), editor.name);
      }
    });

    test('a second reel with the same name gets "Goa (2)", then "Goa (3)", '
        'whatever the editor', () async {
      final first = await reels.create('Goa');
      final second = await sameNameReel('Goa');
      final third = await sameNameReel('Goa');

      expect(
        (await repo.startSession(first.id, EditorApp.vn, 'Goa')).folderName,
        'Goa',
      );
      expect(
        (await repo.startSession(
          second.id,
          EditorApp.capcut,
          'Goa',
        )).folderName,
        'Goa (2)',
      );
      expect(
        (await repo.startSession(third.id, EditorApp.edits, 'Goa')).folderName,
        'Goa (3)',
      );
    });

    test('compares folder names without regard to case', () async {
      final first = await reels.create('Goa');
      final second = await sameNameReel('goa');
      await repo.startSession(first.id, EditorApp.vn, 'Goa');

      expect(
        (await repo.startSession(second.id, EditorApp.vn, 'goa')).folderName,
        'goa (2)',
      );
    });

    test('a folder name is free again after its session ends', () async {
      final first = await reels.create('Goa');
      final second = await sameNameReel('Goa');
      await repo.startSession(first.id, EditorApp.vn, 'Goa');
      await repo.endSession(first.id);

      expect(
        (await repo.startSession(second.id, EditorApp.vn, 'Goa')).folderName,
        'Goa',
      );
    });

    test('also avoids names already on disk, ignoring case', () async {
      final reel = await reels.create('Goa');

      final session = await repo.startSession(
        reel.id,
        EditorApp.vn,
        'Goa',
        alsoTaken: {'goa', 'GOA (2)'},
      );

      expect(session.folderName, 'Goa (3)');
    });

    test('trims the base name; a blank one throws ArgumentError and saves '
        'nothing', () async {
      final reel = await reels.create('Goa');

      await expectLater(
        repo.startSession(reel.id, EditorApp.vn, '  ​ '),
        throwsArgumentError,
      );
      await expectLater(
        repo.startSession(reel.id, EditorApp.vn, ''),
        throwsArgumentError,
      );
      expect(await repo.sessionOf(reel.id), isNull);

      expect(
        (await repo.startSession(reel.id, EditorApp.vn, '  Goa  ')).folderName,
        'Goa',
      );
    });

    test('an unknown reel throws StateError and saves nothing', () async {
      await expectLater(
        repo.startSession(999, EditorApp.vn, 'Goa'),
        throwsStateError,
      );
      expect(await db.select(db.editSessions).get(), isEmpty);
    });

    test('a reel that already has a session throws StateError and keeps it, '
        'editor and all', () async {
      final reel = await reels.create('Goa');
      final session = await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      clock.advance(_minute);

      await expectLater(
        repo.startSession(reel.id, EditorApp.capcut, 'Other'),
        throwsStateError,
      );
      expect(await repo.sessionOf(reel.id), session);
      expect(await db.select(db.editSessions).get(), hasLength(1));
    });
  });

  group('startSession, called twice at once (a double tap)', () {
    test('two calls for one reel give one session and one StateError, not '
        'a database error', () async {
      final reel = await reels.create('Goa');

      final results = await Future.wait([
        repo
            .startSession(reel.id, EditorApp.capcut, 'Goa')
            .then<Object>((s) => s, onError: (Object e) => e),
        repo
            .startSession(reel.id, EditorApp.edits, 'Goa')
            .then<Object>((s) => s, onError: (Object e) => e),
      ]);

      expect(results.whereType<EditSession>(), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(1));
      expect(await db.select(db.editSessions).get(), hasLength(1));
      // The one that won is the one that is stored, editor and all.
      expect(
        await repo.sessionOf(reel.id),
        results.whereType<EditSession>().single,
      );
    });

    test('two reels with one name at once get two different folders', () async {
      final first = await reels.create('Goa');
      final second = await sameNameReel('Goa');

      final sessions = await Future.wait([
        repo.startSession(first.id, EditorApp.vn, 'Goa'),
        repo.startSession(second.id, EditorApp.vn, 'Goa'),
      ]);

      expect({for (final s in sessions) s.folderName}, {'Goa', 'Goa (2)'});
    });
  });

  group('sessionOf', () {
    test('is null for a reel with no session', () async {
      final reel = await reels.create('Goa');
      expect(await repo.sessionOf(reel.id), isNull);
      expect(await repo.sessionOf(999), isNull);
    });
  });

  group('recordSent', () {
    test('records each clip with the time it was first sent', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
      clock.advance(_minute);

      await repo.recordSent(reel.id, [3, 1]);

      expect(await sentRows(), [
        (reel.id, 1, _t0.add(_minute)),
        (reel.id, 3, _t0.add(_minute)),
      ]);
    });

    test('is idempotent: a clip sent again keeps its first sentAt', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
      await repo.recordSent(reel.id, [1]);
      clock.advance(_minute);

      await repo.recordSent(reel.id, [1, 2, 2]);

      expect(await sentRows(), [
        (reel.id, 1, _t0),
        (reel.id, 2, _t0.add(_minute)),
      ]);
    });

    test('without a session throws StateError and saves nothing', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(paris.id, EditorApp.capcut, 'Paris');

      await expectLater(repo.recordSent(goa.id, [1]), throwsStateError);
      await expectLater(repo.recordSent(999, [1]), throwsStateError);
      await expectLater(repo.recordSent(goa.id, []), throwsStateError);
      expect(await sentRows(), isEmpty);
    });

    test('the same clip id in two reels is two rows', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.capcut, 'Goa');
      await repo.startSession(paris.id, EditorApp.edits, 'Paris');

      await repo.recordSent(goa.id, [1]);
      await repo.recordSent(paris.id, [1]);

      expect(await sentRows(), [(goa.id, 1, _t0), (paris.id, 1, _t0)]);
    });

    test('keeps ids of clips that do not exist (no foreign key)', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');

      await repo.recordSent(reel.id, [77]);

      expect(await sentRows(), [(reel.id, 77, _t0)]);
    });

    test('an empty list with a session writes nothing', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');

      await repo.recordSent(reel.id, const []);

      expect(await sentRows(), isEmpty);
    });

    test('returns only the ids this call added, never one already sent, '
        'whichever call sent it', () async {
      final reel = await reels.create('Goa');
      final other = await reels.create('Paris');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
      await repo.startSession(other.id, EditorApp.edits, 'Paris');
      await repo.recordSent(other.id, [1]);

      expect(await repo.recordSent(reel.id, [1, 2, 2]), {1, 2});
      expect(await repo.recordSent(reel.id, [1, 2]), isEmpty);
      expect(await repo.recordSent(reel.id, [2, 3, 4]), {3, 4});
      expect(await repo.recordSent(reel.id, const []), isEmpty);
    });

    test('logs how many it really added', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
      final messages = <String>[];
      final sub = Logger.root.onRecord.listen((r) {
        if (r.loggerName == 'editSessions') messages.add(r.message);
      });
      addTearDown(sub.cancel);

      await repo.recordSent(reel.id, [1, 2]);
      await repo.recordSent(reel.id, [1, 2]);
      await repo.recordSent(reel.id, [1, 3]);

      expect(messages, [
        'Recorded 2 new of 2 sent clips for reel ${reel.id}',
        'Recorded 0 new of 2 sent clips for reel ${reel.id}',
        'Recorded 1 new of 2 sent clips for reel ${reel.id}',
      ]);
    });

    test('two calls at once never both claim a clip, and leave one row '
        'each', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');

      final added = await Future.wait([
        repo.recordSent(reel.id, [1, 2, 3]),
        repo.recordSent(reel.id, [2, 3, 4]),
      ]);

      expect(added[0].intersection(added[1]), isEmpty);
      expect({...added[0], ...added[1]}, {1, 2, 3, 4});
      expect(await sentRows(), [
        for (final id in [1, 2, 3, 4]) (reel.id, id, _t0),
      ]);
    });

    test('racing the end of the session gives a StateError or a clean '
        'record, never a database error', () async {
      for (final endFirst in [true, false]) {
        final reel = await reels.create('Goa $endFirst');
        await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
        final end = repo.endSession(reel.id);
        final send = repo.recordSent(reel.id, [1]);

        Object? outcome;
        try {
          if (endFirst) await end;
          outcome = await send;
          await end;
        } on Object catch (e) {
          outcome = e;
          await end;
        }

        expect(outcome, anyOf(isA<Set<int>>(), isA<StateError>()));
        // Either way nothing outlives the session.
        expect(await repo.sessionOf(reel.id), isNull);
        expect((await sentRows()).where((r) => r.$1 == reel.id), isEmpty);
      }
    });
  });

  group('removeSent', () {
    test('removes only the given ids of that reel, so a failed share rolls '
        'back what it added and nothing else', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.capcut, 'Goa');
      await repo.startSession(paris.id, EditorApp.edits, 'Paris');
      await repo.recordSent(goa.id, [1, 2, 3]);
      await repo.recordSent(paris.id, [2, 3]);
      clock.advance(_minute);

      final added = await repo.recordSent(goa.id, [3, 4, 5]);
      await repo.removeSent(goa.id, added);

      expect(await sentRows(), [
        (goa.id, 1, _t0),
        (goa.id, 2, _t0),
        (goa.id, 3, _t0),
        (paris.id, 2, _t0),
        (paris.id, 3, _t0),
      ]);
    });

    test('unknown ids, an empty list, an unknown reel and a reel with no '
        'session do nothing and do not throw', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.capcut, 'Goa');
      await repo.recordSent(goa.id, [1]);

      await repo.removeSent(goa.id, [9]);
      await repo.removeSent(goa.id, const []);
      await repo.removeSent(999, [1]);
      await repo.removeSent(paris.id, [1]);

      expect(await sentRows(), [(goa.id, 1, _t0)]);
    });

    test('a clip removed can be sent again with a fresh time', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
      await repo.recordSent(reel.id, [1]);
      await repo.removeSent(reel.id, [1]);
      clock.advance(_minute);

      expect(await repo.recordSent(reel.id, [1]), {1});

      expect(await sentRows(), [(reel.id, 1, _t0.add(_minute))]);
    });

    test('leaves the session and its copies alone, and the edit state '
        'follows', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.capcut, 'Goa');
      await repo.recordCopies([_copy(reel.id, 1)]);
      await repo.recordSent(reel.id, [1, 2]);
      final states = collect(repo.watchEditState(reel.id));
      await pumpEventQueue();

      await repo.removeSent(reel.id, [2]);
      await pumpEventQueue();

      expect(states.last!.sentIds, {1});
      expect(states.last!.copies, [_copy(reel.id, 1)]);
      expect(await repo.sessionOf(reel.id), isNotNull);
    });
  });

  group('recordCopies', () {
    test('stores every field, and copiesOf orders by file name', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      final later = _copy(
        reel.id,
        2,
        fileName: '2026-10-26_12-00-00.mp4',
        copiedAt: _t0.add(_minute),
      );
      final earlier = _copy(reel.id, 1, fileName: '2026-10-26_08-00-00.mp4');

      await repo.recordCopies([later, earlier]);

      expect(await repo.copiesOf(reel.id), [earlier, later]);
    });

    test("copiesOf only returns that reel's copies", () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.startSession(paris.id, EditorApp.vn, 'Paris');

      await repo.recordCopies([_copy(goa.id, 1), _copy(paris.id, 2)]);

      expect((await repo.copiesOf(goa.id)).single.clipId, 1);
      expect((await repo.copiesOf(paris.id)).single.clipId, 2);
      expect(await repo.copiesOf(999), isEmpty);
    });

    test('a row equal to one already stored is ignored and the first '
        'stays', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      final first = _copy(reel.id, 1);
      await repo.recordCopies([first]);

      // The same reel, clip and copy id again (a restart reading the folder
      // back), even with a later time: nothing changes.
      await repo.recordCopies([
        first.copyWith(copiedAt: _t0.add(_minute)),
        _copy(reel.id, 2),
      ]);
      await repo.recordCopies([first, first]);

      expect(await repo.copiesOf(reel.id), [first, _copy(reel.id, 2)]);
    });

    test('the same clip with a different copy id throws StateError and '
        'stores none of the batch', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      final first = _copy(reel.id, 1);
      await repo.recordCopies([first]);

      await expectLater(
        repo.recordCopies([_copy(reel.id, 2), _copy(reel.id, 1, copyId: 999)]),
        throwsStateError,
      );

      expect(await repo.copiesOf(reel.id), [first]);
    });

    test('the same clip twice in one batch with different copy ids throws '
        'StateError and stores nothing', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');

      await expectLater(
        repo.recordCopies([
          _copy(reel.id, 1, copyId: 600),
          _copy(reel.id, 1, copyId: 601),
        ]),
        throwsStateError,
      );

      expect(await db.select(db.editCopies).get(), isEmpty);
    });

    test('another clip with a copy id the reel already holds throws '
        'StateError and stores none of the batch', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      final first = _copy(reel.id, 1, copyId: 500);
      await repo.recordCopies([first]);

      await expectLater(
        repo.recordCopies([_copy(reel.id, 3), _copy(reel.id, 2, copyId: 500)]),
        throwsStateError,
      );

      expect(await repo.copiesOf(reel.id), [first]);
    });

    test('one copy id for two clips in one batch throws StateError and '
        'stores nothing', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');

      await expectLater(
        repo.recordCopies([
          _copy(reel.id, 1, copyId: 500),
          _copy(reel.id, 2, copyId: 500),
        ]),
        throwsStateError,
      );

      expect(await db.select(db.editCopies).get(), isEmpty);
    });

    test('the StateError names ids only, never a file name (D-10)', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      await repo.recordCopies([
        _copy(reel.id, 1, copyId: 500, fileName: 'Secret one.mp4'),
      ]);

      await expectLater(
        repo.recordCopies([
          _copy(reel.id, 2, copyId: 500, fileName: 'Secret two.mp4'),
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('500'), isNot(contains('Secret'))),
          ),
        ),
      );
    });

    test('the same copy id in two reels is allowed, and a re-record of the '
        'same clip and copy id still just skips', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.startSession(paris.id, EditorApp.vn, 'Paris');
      final first = _copy(goa.id, 1, copyId: 500);

      await repo.recordCopies([first, _copy(paris.id, 2, copyId: 500)]);
      await repo.recordCopies([first, _copy(goa.id, 3, copyId: 501)]);

      expect(await repo.copiesOf(goa.id), [
        first,
        _copy(goa.id, 3, copyId: 501),
      ]);
      expect((await repo.copiesOf(paris.id)).single.copyMediaStoreId, 500);
    });

    test(
      'a copy id is free for another clip once its row was removed',
      () async {
        final reel = await reels.create('Goa');
        await repo.startSession(reel.id, EditorApp.vn, 'Goa');
        await repo.recordCopies([_copy(reel.id, 1, copyId: 500)]);
        await repo.removeCopies(reel.id, [500]);

        await repo.recordCopies([_copy(reel.id, 2, copyId: 500)]);

        expect((await repo.copiesOf(reel.id)).single.clipId, 2);
      },
    );

    test('copiesOf puts copies with one file name in clip order, whatever '
        'order they were stored in', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      const name = '2026-10-26_08-00-00.mp4';

      await repo.recordCopies([
        _copy(reel.id, 5, fileName: name),
        _copy(reel.id, 2, fileName: name),
        _copy(reel.id, 9, fileName: name),
      ]);

      expect(
        [for (final c in await repo.copiesOf(reel.id)) c.clipId],
        [2, 5, 9],
      );
    });

    test('without a session throws StateError and stores none of the '
        'batch', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');

      await expectLater(
        repo.recordCopies([_copy(goa.id, 1), _copy(paris.id, 2)]),
        throwsStateError,
      );
      await expectLater(repo.recordCopies([_copy(999, 3)]), throwsStateError);

      expect(await db.select(db.editCopies).get(), isEmpty);
    });

    test('a copy may name a clip that does not exist (D-54)', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');

      await repo.recordCopies([_copy(reel.id, 77)]);

      expect((await repo.copiesOf(reel.id)).single.clipId, 77);
    });

    test('an empty batch writes nothing', () async {
      await repo.recordCopies(const []);

      expect(await db.select(db.editCopies).get(), isEmpty);
    });
  });

  group('removeCopies', () {
    test('removes only the given copy ids of that reel', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.startSession(paris.id, EditorApp.vn, 'Paris');
      await repo.recordCopies([
        _copy(goa.id, 1, copyId: 600),
        _copy(goa.id, 2, copyId: 601),
        _copy(goa.id, 3, copyId: 602),
        // Another reel's row with a copy id given for Goa below.
        _copy(paris.id, 4, copyId: 601),
      ]);
      await repo.recordSent(goa.id, [1, 2]);

      await repo.removeCopies(goa.id, [601, 600]);

      expect(
        [for (final c in await repo.copiesOf(goa.id)) c.copyMediaStoreId],
        [602],
      );
      expect(
        [for (final c in await repo.copiesOf(paris.id)) c.copyMediaStoreId],
        [601],
      );
      expect(await sentRows(), hasLength(2), reason: 'sent rows stay');
      expect(await repo.sessionOf(goa.id), isNotNull);
    });

    test('unknown ids, an empty list or an unknown reel do nothing', () async {
      final goa = await reels.create('Goa');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.recordCopies([_copy(goa.id, 1, copyId: 600)]);

      await repo.removeCopies(goa.id, [123]);
      await repo.removeCopies(goa.id, const []);
      await repo.removeCopies(999, [600]);

      expect(await repo.copiesOf(goa.id), [_copy(goa.id, 1, copyId: 600)]);
    });
  });

  group('watchEditState', () {
    test('is null without a session, then follows every send, copy and '
        'removal, and is null again after the end', () async {
      final reel = await reels.create('Goa');
      final states = collect(repo.watchEditState(reel.id));
      await pumpEventQueue();
      expect(states, [null]);

      final session = await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      await pumpEventQueue();
      expect(
        states.last,
        EditState(session: session, copies: const [], sentIds: const {}),
      );

      await repo.recordSent(reel.id, [1, 2]);
      await pumpEventQueue();
      expect(states.last!.sentIds, {1, 2});

      final copy = _copy(reel.id, 1, copyId: 600);
      await repo.recordCopies([copy]);
      await pumpEventQueue();
      expect(states.last!.copies, [copy]);
      expect(states.last!.sentIds, {1, 2});

      await repo.removeCopies(reel.id, [600]);
      await pumpEventQueue();
      expect(states.last!.copies, isEmpty);

      await repo.endSession(reel.id);
      await pumpEventQueue();
      expect(states.last, isNull);
      expect(states, hasLength(6));
    });

    test('sentIds is a set and the copies are in file-name order', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      await repo.recordSent(reel.id, [5, 3, 5]);
      await repo.recordCopies([
        _copy(reel.id, 2, fileName: 'b.mp4'),
        _copy(reel.id, 1, fileName: 'a.mp4'),
      ]);

      final state = (await repo.watchEditState(reel.id).first)!;

      expect(state.sentIds, isA<Set<int>>());
      expect(state.sentIds, {3, 5});
      expect([for (final c in state.copies) c.fileName], ['a.mp4', 'b.mp4']);
    });

    test("only that reel's rows, and no repeat for another reel's "
        'change', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.startSession(paris.id, EditorApp.vn, 'Paris');
      await repo.recordSent(goa.id, [1]);
      final states = collect(repo.watchEditState(goa.id));
      await pumpEventQueue();
      expect(states, hasLength(1));

      await repo.recordSent(paris.id, [9]);
      await repo.recordCopies([_copy(paris.id, 9)]);
      await pumpEventQueue();

      expect(states, hasLength(1));
      expect(states.single!.sentIds, {1});
      expect(states.single!.copies, isEmpty);
    });
  });

  group('watchEditors', () {
    test('maps each reel with a session to its editor, after every '
        'change', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final maps = collect(repo.watchEditors());
      await pumpEventQueue();

      await repo.startSession(goa.id, EditorApp.capcut, 'Goa');
      await pumpEventQueue();
      await repo.startSession(paris.id, EditorApp.vn, 'Paris');
      await pumpEventQueue();
      await repo.endSession(goa.id);
      await pumpEventQueue();

      expect(maps, [
        <int, EditorApp>{},
        {goa.id: EditorApp.capcut},
        {goa.id: EditorApp.capcut, paris.id: EditorApp.vn},
        {paris.id: EditorApp.vn},
      ]);
    });
  });

  group('watchSummaries', () {
    test('lists only sessions, newest first, with copy count, bytes and the '
        'last copy time', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await reels.create('No session');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      clock.advance(_minute);
      await repo.startSession(paris.id, EditorApp.edits, 'Paris');
      await repo.recordCopies([
        _copy(goa.id, 1, sizeBytes: 1500, copiedAt: _t0.add(_minute * 5)),
        _copy(goa.id, 2, sizeBytes: 2500, copiedAt: _t0.add(_minute * 9)),
        _copy(goa.id, 3, sizeBytes: 3000, copiedAt: _t0.add(_minute * 7)),
      ]);
      await repo.recordSent(paris.id, [1]);

      final summaries = await repo.watchSummaries().first;

      expect(summaries, [
        EditSessionSummary(
          reelId: paris.id,
          reelName: 'Paris',
          editor: EditorApp.edits,
          folderName: 'Paris',
          createdAt: _t0.add(_minute),
          copyCount: 0,
          copyBytes: 0,
        ),
        EditSessionSummary(
          reelId: goa.id,
          reelName: 'Goa',
          editor: EditorApp.vn,
          folderName: 'Goa',
          createdAt: _t0,
          copyCount: 3,
          copyBytes: 7000,
          lastCopiedAt: _t0.add(_minute * 9),
        ),
      ]);
    });

    test('a copy over 2 GB sums without overflow', () async {
      final goa = await reels.create('Goa');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.recordCopies([
        _copy(goa.id, 1, sizeBytes: 3000000000),
        _copy(goa.id, 2, sizeBytes: 4000000000),
      ]);

      final summary = (await repo.watchSummaries().first).single;

      expect(summary.copyBytes, 7000000000);
    });

    test("shows the reel's current name, and the same createdAt puts the "
        'higher reel id first', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      await repo.startSession(paris.id, EditorApp.vn, 'Paris');
      final lists = collect(repo.watchSummaries());
      await pumpEventQueue();

      await reels.rename(goa.id, 'Goa trip');
      await pumpEventQueue();

      expect([for (final s in lists.last) s.reelId], [paris.id, goa.id]);
      expect(lists.last.last.reelName, 'Goa trip');
      expect(lists.last.last.folderName, 'Goa');
    });

    test('follows copies, removals and the end of a session', () async {
      final goa = await reels.create('Goa');
      await repo.startSession(goa.id, EditorApp.vn, 'Goa');
      final lists = collect(repo.watchSummaries());
      await pumpEventQueue();

      await repo.recordCopies([_copy(goa.id, 1, copyId: 600)]);
      await pumpEventQueue();
      expect(lists.last.single.copyCount, 1);

      await repo.removeCopies(goa.id, [600]);
      await pumpEventQueue();
      expect(lists.last.single.copyCount, 0);
      expect(lists.last.single.lastCopiedAt, isNull);

      await repo.endSession(goa.id);
      await pumpEventQueue();
      expect(lists.last, isEmpty);
    });
  });

  group('endSession', () {
    test(
      "deletes the session, its copies and sent rows, not other reels'",
      () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        await repo.startSession(goa.id, EditorApp.vn, 'Goa');
        await repo.startSession(paris.id, EditorApp.capcut, 'Paris');
        await repo.recordCopies([_copy(goa.id, 1)]);
        await repo.recordSent(goa.id, [1]);
        final keep = _copy(paris.id, 2);
        await repo.recordCopies([keep]);
        await repo.recordSent(paris.id, [2]);

        await repo.endSession(goa.id);

        expect(await repo.sessionOf(goa.id), isNull);
        expect(await repo.copiesOf(goa.id), isEmpty);
        expect(await repo.sessionOf(paris.id), isNotNull);
        expect(await repo.copiesOf(paris.id), [keep]);
        expect(await sentRows(), [(paris.id, 2, _t0)]);
      },
    );

    test('an unknown reel does nothing', () async {
      await repo.endSession(999);
    });

    test('deleting the reel removes its session, copies and sent rows '
        'too', () async {
      final reel = await reels.create('Goa');
      await repo.startSession(reel.id, EditorApp.vn, 'Goa');
      await repo.recordCopies([_copy(reel.id, 1)]);
      await repo.recordSent(reel.id, [1]);

      await reels.delete(reel.id);

      expect(await db.select(db.editSessions).get(), isEmpty);
      expect(await db.select(db.editCopies).get(), isEmpty);
      expect(await db.select(db.sentClips).get(), isEmpty);
    });
  });
}
