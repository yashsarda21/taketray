import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/view_models/reel_actions.dart';

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
    actions = ReelActions(reels);
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
}
