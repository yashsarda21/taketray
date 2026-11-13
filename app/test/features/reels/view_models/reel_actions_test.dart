import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/view_models/reel_actions.dart';

import '../../../support/reel_videos.dart';
import '../../../support/spy_edit_session_service.dart';
import '../../../support/vm_harness.dart';

class _SlowReels extends ReelsRepository {
  // The parameters of ReelsRepository are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  _SlowReels(AppDatabase db, Clock clock) : super(db, clock);

  int deletes = 0;
  bool fail = false;
  final Completer<void> gate = Completer<void>();

  @override
  Future<DeleteReelUndo> delete(int id) async {
    deletes++;
    await gate.future;
    if (fail) throw StateError('disk full');
    return await super.delete(id);
  }

  @override
  Future<void> setStatus(int id, ReelStatus status) async {
    if (fail) throw StateError('disk full');
    await super.setStatus(id, status);
  }
}

void main() {
  late VmHarness h;
  late _SlowReels reels;
  late ReelActions actions;

  setUp(() {
    h = VmHarness();
    reels = _SlowReels(h.media.db, h.media.clock);
    actions = ReelActions(reels, h.container.read(editSessionServiceProvider));
  });

  test('two deletes at once delete once and share the record', () async {
    final goa = await reels.create('Goa');
    final first = actions.confirmDelete(goa.id);
    final second = actions.confirmDelete(goa.id);
    expect(identical(first, second), isTrue);
    reels.gate.complete();
    final records = await Future.wait([first, second]);
    expect(reels.deletes, 1);
    expect(identical(records[0], records[1]), isTrue);
    expect(records[0].reel!.id, goa.id);
  });

  test('a delete after the first finished runs and finds nothing', () async {
    final goa = await reels.create('Goa');
    reels.gate.complete();
    final first = await actions.confirmDelete(goa.id);
    expect(first.isEmpty, isFalse);
    final again = await actions.confirmDelete(goa.id);
    expect(reels.deletes, 2);
    // The reel was already gone: nothing to undo.
    expect(again.isEmpty, isTrue);
  });

  test('different reels delete independently', () async {
    final goa = await reels.create('Goa');
    final paris = await reels.create('Paris');
    final a = actions.confirmDelete(goa.id);
    final b = actions.confirmDelete(paris.id);
    reels.gate.complete();
    await Future.wait([a, b]);
    expect(reels.deletes, 2);
  });

  test('a failed delete is thrown, then the next call runs again', () async {
    final goa = await reels.create('Goa');
    reels.fail = true;
    reels.gate.complete();
    await expectLater(
      actions.confirmDelete(goa.id),
      throwsA(isA<StateError>()),
    );
    reels.fail = false;
    final record = await actions.confirmDelete(goa.id);
    expect(record.reel!.id, goa.id);
    expect(reels.deletes, 2);
  });

  test('setStatus writes the status and rethrows a failure', () async {
    final goa = await reels.create('Goa');
    await actions.setStatus(goa.id, ReelStatus.published);
    expect((await reels.getById(goa.id))!.status, ReelStatus.published);
    reels.fail = true;
    await expectLater(
      actions.setStatus(goa.id, ReelStatus.ready),
      throwsA(isA<StateError>()),
    );
    expect((await reels.getById(goa.id))!.status, ReelStatus.published);
  });
  group('editing session (R8, D-123, p8-task6)', () {
    late SpyEditSessionService spy;

    setUp(() {
      spy = SpyEditSessionService(h);
      actions = ReelActions(reels, spy);
      reels.gate.complete();
    });

    test("ends the reel's session (its copies deleted) before the delete, "
        'and Undo restores the reel with no session', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final sessions = EditSessionsRepository(h.media.db, h.media.clock);
      await sessions.startSession(goa.id, EditorApp.vn, 'Goa');
      await sessions.recordCopies([
        EditCopy(
          reelId: goa.id,
          clipId: ids.single,
          copyMediaStoreId: 501,
          fileName: 'c.mp4',
          sizeBytes: 10,
          copiedAt: reelTestNow,
        ),
      ]);
      h.editors.existing = {501};

      final record = await actions.confirmDelete(goa.id);

      expect(spy.calls, ['reelDelete ${goa.id}']);
      expect(h.editors.existing, isEmpty);
      expect(record.editSession, isNull);
      expect(record.editCopies, isEmpty);
      await reels.undo(record);
      expect(await reels.getById(goa.id), isNotNull);
      expect(await sessions.sessionOf(goa.id), isNull);
    });

    test('when the copies cannot be deleted nothing is deleted', () async {
      final goa = await reels.create('Goa');
      spy.failReelDelete = const CopiesNotDeleted(2);

      await expectLater(
        actions.confirmDelete(goa.id),
        throwsA(isA<CopiesNotDeleted>()),
      );
      expect(reels.deletes, 0);
      expect(await reels.getById(goa.id), isNotNull);
    });

    test('a double tap cleans up once', () async {
      final goa = await reels.create('Goa');

      await Future.wait([
        actions.confirmDelete(goa.id),
        actions.confirmDelete(goa.id),
      ]);

      expect(spy.calls, ['reelDelete ${goa.id}']);
      expect(reels.deletes, 1);
    });
  });
}
