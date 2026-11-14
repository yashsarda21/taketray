import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/space_check.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/platform/editors_bridge.dart';

import '../../support/fake_copy_bridge.dart';
import '../../support/fake_editors_bridge.dart';
import '../../support/reel_videos.dart';
import '../../support/vm_harness.dart';

/// The copy names of the default test videos: shot at 09:`id` UTC on
/// 2026-10-28, named in the phone's zone (UTC) unless a test says otherwise.
String nameOf(int videoId, {int hour = 9, String ext = 'mp4'}) =>
    '2026-10-28_${hour.toString().padLeft(2, '0')}-'
    '${videoId.toString().padLeft(2, '0')}-00.$ext';

late VmHarness h;
late FakeEditorsBridge editors;
late FakeCopyBridge copy;
late EditSessionsRepository sessions;
late ReelsRepository reels;
late EditSessionService service;

EditSessionService make({
  EditorsBridge? editorsBridge,
  CopyBridge? copyBridge,
}) {
  final made = EditSessionService(
    sessions,
    h.media.clips,
    reels,
    h.media.phoneState,
    editorsBridge ?? editors,
    copyBridge ?? copy,
    ClipTimeService(h.bridge),
    h.media.clock,
  );
  addTearDown(made.dispose);
  return made;
}

/// A new process: the engine has no job (`current()` is null) but the
/// folder's rows are still on the phone, and the service is new.
EditSessionService restart() {
  final old = copy;
  copy = FakeCopyBridge();
  copy.folders.addAll(old.folders);
  return service = make();
}

CopiedFile copied(int clipId, int copyId, String fileName, {int size = 10}) =>
    CopiedFile(
      clipId: clipId,
      copyMediaStoreId: copyId,
      fileName: fileName,
      sizeBytes: size,
      copiedAt: DateTime.utc(2026, 10, 30, 11),
    );

/// The engine reports [files] as copied so far for the job it holds.
CopyJob progress(
  List<CopiedFile> files, {
  CopyState state = CopyState.running,
}) {
  final next = copy.job!.copyWith(
    copied: files,
    done: files.length,
    state: state,
  );
  copy.emit(next);
  return next;
}

Future<List<EditCopy>> copiesOf(int reelId) => sessions.copiesOf(reelId);

Future<Set<int>> copyIdsOf(int reelId) async => {
  for (final c in await copiesOf(reelId)) c.copyMediaStoreId,
};

Future<int> reel(String name) async => (await reels.create(name)).id;

/// Saves videos [videoIds] (MediaStore ids, shot at 09:`id`) into [reelId].
Future<List<int>> clipsIn(
  int reelId,
  List<int> videoIds, {
  String? zoneId,
  Map<int, DateTime> shot = const {},
}) => putInReel(h, reelId, [
  for (final id in videoIds) reelVideo(id, shot: shot[id]),
], zoneId: zoneId);

Future<ClipRef> refOf(int clipId) async =>
    ClipRef.of(await h.media.clip(clipId));

Future<void> recordCopy(int reelId, int clipId, int copyId, String name) =>
    sessions.recordCopies([
      EditCopy(
        reelId: reelId,
        clipId: clipId,
        copyMediaStoreId: copyId,
        fileName: name,
        sizeBytes: 100,
        copiedAt: DateTime.utc(2026, 10, 29),
      ),
    ]);

/// Plans and starts a VN copy of [clipIds] of [reelId]; returns the job id.
Future<String> startVn(int reelId, List<int> clipIds) async => await service
    .startCopy(await service.planCopy(reelId, EditorApp.vn, clipIds));

/// A copy bridge whose `clear` is ignored [ignored] times, as the engine does
/// for a job that is still deleting its copies.
class _StubbornClear extends FakeCopyBridge {
  int ignored = 0;

  @override
  Future<void> clear(String jobId) async {
    if (ignored > 0) {
      ignored--;
      calls.add('clear:ignored');
      return;
    }
    return await super.clear(jobId);
  }
}

/// An editors bridge that reads the edit state when the share happens.
class _ShareSpy extends FakeEditorsBridge {
  _ShareSpy(this.reelId);

  final int reelId;
  EditState? atSend;

  @override
  Future<SendResult> sendTo(String packageName, List<ClipRef> clips) async {
    atSend = await sessions.editState(reelId);
    return await super.sendTo(packageName, clips);
  }
}

/// A copy bridge that reads the saved plan when the job starts.
class _PlanSpy extends FakeCopyBridge {
  CopyJobPlan? planAtStart;
  bool readAtStart = false;

  @override
  Future<void> start(CopyRequest request) async {
    planAtStart = await h.media.phoneState.copyJobPlan();
    readAtStart = true;
    return await super.start(request);
  }
}

/// An editors bridge whose `deleteCopies` waits for [gate].
class _GatedEditors extends FakeEditorsBridge {
  Completer<void>? gate;

  @override
  Future<DeleteReport> deleteCopies(List<CopyFileRef> refs) async {
    final g = gate;
    if (g != null) {
      calls.add('deleteCopies:waiting');
      await g.future;
    }
    return await super.deleteCopies(refs);
  }
}

/// An editors bridge whose `existingCopies` throws a plain `StateError`
/// instead of a platform error (a bug, not the phone).
class _ThrowingExisting extends FakeEditorsBridge {
  @override
  Future<Set<int>> existingCopies(List<CopyFileRef> refs) async {
    calls.add('existingCopies');
    throw StateError('boom');
  }
}

void main() {
  setUp(() {
    h = reelHarness();
    editors = FakeEditorsBridge();
    copy = FakeCopyBridge();
    sessions = EditSessionsRepository(h.media.db, h.media.clock);
    reels = ReelsRepository(h.media.db, h.media.clock);
    service = make();
  });

  group('editorChoices', () {
    test('every editor in order, installed or not, with the icon of an '
        'installed one, asked at editorIconPx', () async {
      final png = Uint8List.fromList([1, 2, 3]);
      editors
        ..installed = {
          EditorApp.capcut.packageName: true,
          EditorApp.vn.packageName: true,
        }
        ..icons = {EditorApp.capcut.packageName: png};

      expect(await service.editorChoices(), [
        EditorChoice(editor: EditorApp.capcut, installed: true, icon: png),
        const EditorChoice(editor: EditorApp.edits, installed: false),
        const EditorChoice(editor: EditorApp.vn, installed: true),
      ]);
      expect(editorIconPx, 144);
    });
  });

  group('sendOriginals', () {
    test('sends the live clips in shooting order; a missing clip is left '
        'out and not counted, a gone id is dropped', () async {
      final goa = await reel('Goa');
      final [late, early, missing] = await clipsIn(goa, [5, 1, 3]);
      await flagForTest(h, {missing}, missing: true);

      final outcome = await service.sendOriginals(goa, EditorApp.capcut, [
        late,
        missing,
        9999,
        early,
      ]);

      expect(outcome, const SendOutcome(SendResult.sent, 2));
      expect(editors.sent.single.$1, EditorApp.capcut.packageName);
      expect(editors.sent.single.$2, [await refOf(early), await refOf(late)]);
      final state = (await sessions.editState(goa))!;
      expect(state.sentIds, {early, late});
    });

    test('writes the session (editor, folder from safeFolderName and the '
        'folders on disk) and the sent rows before the share', () async {
      final trip = await reel('London/Paris');
      final ids = await clipsIn(trip, [1, 2]);
      final spy = _ShareSpy(trip)..folderNames = ['london-paris'];
      service = make(editorsBridge: spy);

      await service.sendOriginals(trip, EditorApp.edits, ids);

      final at = spy.atSend!;
      expect(at.session.editor, EditorApp.edits);
      expect(at.session.folderName, 'London-Paris (2)');
      expect(at.sentIds, ids.toSet());
      expect(
        spy.calls.indexOf('copyFolderNames'),
        lessThan(spy.calls.indexOf('sendTo')),
      );
    });

    for (final result in [SendResult.notInstalled, SendResult.failed]) {
      test(
        '${result.name} rolls back the session and the sent rows it made',
        () async {
          final goa = await reel('Goa');
          final ids = await clipsIn(goa, [1, 2]);
          editors.sendResult = result;

          final outcome = await service.sendOriginals(
            goa,
            EditorApp.capcut,
            ids,
          );

          expect(outcome, SendOutcome(result, 0));
          expect(await sessions.editState(goa), isNull);
        },
      );
    }

    test('a share that throws rolls back the same way and rethrows', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      editors.failNext('sendTo');

      await expectLater(
        service.sendOriginals(goa, EditorApp.capcut, ids),
        throwsA(isA<PlatformException>()),
      );
      expect(await sessions.editState(goa), isNull);
    });

    test('no live clip (all missing or gone) sends nothing and writes '
        'nothing: failed with sentCount 0', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await flagForTest(h, {a}, missing: true);

      final outcome = await service.sendOriginals(goa, EditorApp.capcut, [
        a,
        9999,
      ]);

      expect(outcome, const SendOutcome(SendResult.failed, 0));
      expect(editors.calls, isNot(contains('sendTo')));
      expect(await sessions.editState(goa), isNull);
    });

    test('VN throws StateError and writes nothing', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);

      await expectLater(
        service.sendOriginals(goa, EditorApp.vn, ids),
        throwsStateError,
      );
      expect(editors.sent, isEmpty);
      expect(await sessions.editState(goa), isNull);
    });

    test("a reel in another editor's session throws StateError and changes "
        'nothing', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');

      await expectLater(
        service.sendOriginals(goa, EditorApp.capcut, ids),
        throwsStateError,
      );
      expect(editors.sent, isEmpty);
      expect((await sessions.editState(goa))!.sentIds, isEmpty);
    });

    test('a session of the same editor gets sent rows only; a failed share '
        "rolls back only this call's new rows", () async {
      final goa = await reel('Goa');
      final [a, b, c] = await clipsIn(goa, [1, 2, 3]);
      await service.sendOriginals(goa, EditorApp.capcut, [a, b]);
      final session = (await sessions.sessionOf(goa))!;

      h.media.clock.advance(const Duration(hours: 1));
      expect(
        await service.sendOriginals(goa, EditorApp.capcut, [c]),
        const SendOutcome(SendResult.sent, 1),
      );
      expect(await sessions.sessionOf(goa), session);
      expect((await sessions.editState(goa))!.sentIds, {a, b, c});

      final [d] = await clipsIn(goa, [4]);
      editors.sendResult = SendResult.failed;
      final failed = await service.sendOriginals(goa, EditorApp.capcut, [b, d]);

      expect(failed, const SendOutcome(SendResult.failed, 0));
      expect(await sessions.sessionOf(goa), session);
      expect((await sessions.editState(goa))!.sentIds, {a, b, c});
    });

    test('a double call sends once (single-flight per reel)', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2]);

      final first = service.sendOriginals(goa, EditorApp.capcut, ids);
      final second = service.sendOriginals(goa, EditorApp.capcut, ids);

      expect(await first, const SendOutcome(SendResult.sent, 2));
      expect(await second, const SendOutcome(SendResult.sent, 2));
      expect(editors.sent, hasLength(1));
      // Done: the next call sends again.
      await service.sendOriginals(goa, EditorApp.capcut, ids);
      expect(editors.sent, hasLength(2));
    });
  });

  group('share', () {
    test(
      'live clips only, in shooting order, with the title; no session',
      () async {
        final goa = await reel('Goa');
        final [late, early, missing] = await clipsIn(goa, [6, 2, 4]);
        await flagForTest(h, {missing}, missing: true);

        expect(
          await service.share([late, missing, early, 9999], 'Share 2 videos'),
          isTrue,
        );
        expect(editors.chooserShares.single.$1, [
          await refOf(early),
          await refOf(late),
        ]);
        expect(editors.chooserShares.single.$2, 'Share 2 videos');
        expect(await sessions.editState(goa), isNull);
      },
    );

    test("the chooser's false is passed on", () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      editors.chooserResult = false;

      expect(await service.share(ids, 'Share video'), isFalse);
    });

    test('all missing: false without a bridge call', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2]);
      await flagForTest(h, ids.toSet(), missing: true);

      expect(await service.share([...ids, 9999], 'Share video'), isFalse);
      expect(editors.calls, isNot(contains('shareWithChooser')));
    });
  });

  group('planCopy', () {
    test('VN with no session: starts one; live clips of the reel in shooting '
        "order, sizes summed, the phone's free space, the folder a new "
        'session would get; nothing written', () async {
      final trip = await reel('Goa: trip');
      final other = await reel('Paris');
      await sessions.startSession(other, EditorApp.vn, 'Goa- trip');
      final [late, early, missing] = await clipsIn(trip, [7, 3, 5]);
      final [elsewhere] = await clipsIn(other, [8]);
      await flagForTest(h, {missing}, missing: true);
      editors
        ..bytesFree = 1600000000
        ..folderNames = ['Goa- trip (2)'];

      final plan = await service.planCopy(trip, EditorApp.vn, [
        late,
        missing,
        elsewhere,
        9999,
        early,
      ]);

      expect(plan.reelId, trip);
      expect(plan.editor, EditorApp.vn);
      expect(plan.clipIds, [early, late]);
      expect(plan.needBytes, 1003 + 1007);
      expect(plan.freeBytes, 1600000000);
      expect(plan.space.enough, isTrue);
      expect(
        plan.space.freeAfterBytes,
        spaceCheck(needBytes: 2010, freeBytes: 1600000000).freeAfterBytes,
      );
      expect(plan.folderName, 'Goa- trip (3)');
      expect(plan.startsSession, isTrue);
      expect(await sessions.editState(trip), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });

    test('the space check keeps the reserve: short when free is need plus '
        'less than 500 MB', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      editors.bytesFree = 1001 + copyReserveBytes - 1;

      final plan = await service.planCopy(goa, EditorApp.vn, ids);

      expect(plan.space.enough, isFalse);
      expect(plan.space.shortByBytes, 1);
    });

    test('runs verifyCopies first: a copy deleted outside TakeTray loses its '
        'row, the clip is offered again and its new copy records without a '
        'StateError', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      editors.existing = {502};

      final plan = await service.planCopy(goa, EditorApp.vn, [a, b]);

      expect(
        editors.calls.indexOf('existingCopies'),
        lessThan(editors.calls.indexOf('freeBytes')),
      );
      expect(plan.clipIds, [a]);
      expect(plan.startsSession, isFalse);
      expect(await copyIdsOf(goa), {502});

      final jobId = await service.startCopy(plan);
      expect(copy.starts.single.items.single.fileName, nameOf(1));
      await service.applyJob(progress([copied(a, 601, nameOf(1))]));
      expect(jobId, isNotEmpty);
      expect(await copyIdsOf(goa), {502, 601});
    });

    test("when the verify's bridge call throws, the row stays and the clip "
        'is not offered', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.failNext('existingCopies');

      final plan = await service.planCopy(goa, EditorApp.vn, [a, b]);

      expect(plan.clipIds, [b]);
      expect(await copyIdsOf(goa), {501});
    });

    test('a VN session keeps its folder after a rename, and does not start '
        'another', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await reels.rename(goa, 'Goa 2026');

      final plan = await service.planCopy(goa, EditorApp.vn, ids);

      expect(plan.folderName, 'Goa');
      expect(plan.startsSession, isFalse);
    });

    test("a CapCut session's later clips: no new session, the session's "
        'folder', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await service.sendOriginals(goa, EditorApp.capcut, [a]);

      final plan = await service.planCopy(goa, EditorApp.capcut, [a, b]);

      expect(plan.clipIds, [a, b]);
      expect(plan.startsSession, isFalse);
      expect(plan.folderName, 'Goa');
    });

    test(
      'a session of another editor throws StateError; CapCut or Edits '
      'with no session throws StateError (their first send is a share)',
      () async {
        final goa = await reel('Goa');
        final ids = await clipsIn(goa, [1]);
        final paris = await reel('Paris');
        final parisIds = await clipsIn(paris, [2]);
        await sessions.startSession(goa, EditorApp.edits, 'Goa');

        await expectLater(
          service.planCopy(goa, EditorApp.vn, ids),
          throwsStateError,
        );
        await expectLater(
          service.planCopy(goa, EditorApp.capcut, ids),
          throwsStateError,
        );
        await expectLater(
          service.planCopy(paris, EditorApp.capcut, parisIds),
          throwsStateError,
        );
      },
    );
  });

  group('startCopy', () {
    test('the first VN copy starts the session, saves the plan before start, '
        'and starts the items in shooting order with their names', () async {
      final spy = _PlanSpy();
      copy = spy;
      service = make();
      final goa = await reel('Goa');
      final [late, early] = await clipsIn(goa, [4, 2]);

      final plan = await service.planCopy(goa, EditorApp.vn, [late, early]);
      final jobId = await service.startCopy(plan);

      final now = h.media.clock.now().millisecondsSinceEpoch;
      expect(jobId, '$goa-$now');
      final session = (await sessions.sessionOf(goa))!;
      expect(session.editor, EditorApp.vn);
      expect(session.folderName, 'Goa');
      final request = spy.starts.single;
      expect(request.jobId, jobId);
      expect(request.reelId, goa);
      expect(request.folderName, 'Goa');
      expect([for (final i in request.items) i.clipId], [early, late]);
      expect(
        [for (final i in request.items) i.fileName],
        [nameOf(2), nameOf(4)],
      );
      expect([for (final i in request.items) i.sizeBytes], [1002, 1004]);
      expect(request.items.first.source, await refOf(early));

      expect(spy.readAtStart, isTrue);
      final saved = spy.planAtStart!;
      expect(saved, await h.media.phoneState.copyJobPlan());
      expect(saved.jobId, jobId);
      expect(saved.reelId, goa);
      expect(saved.editor, EditorApp.vn);
      expect(saved.folderName, 'Goa');
      expect(saved.startedSession, isTrue);
      expect(saved.items, [
        (clipId: early, fileName: nameOf(2), sizeBytes: 1002),
        (clipId: late, fileName: nameOf(4), sizeBytes: 1004),
      ]);
    });

    test("names use each clip's local shot time; a clip with no zone uses "
        "the phone's; names in the session or the folder are taken", () async {
      h.bridge.currentZone = 'Asia/Kolkata';
      final goa = await reel('Goa');
      final [own] = await clipsIn(goa, [1], zoneId: 'Europe/London');
      final [none] = await clipsIn(goa, [2]);
      final [clash] = await clipsIn(goa, [3]);
      final [old] = await clipsIn(goa, [4]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      // 09:03 UTC is 14:33 in Kolkata: a recorded copy has that name.
      await recordCopy(goa, old, 404, '2026-10-28_14-33-00.mp4');
      editors
        ..existing = {404}
        ..files = [
          // 09:02 UTC is 14:32 in Kolkata: a file of another app has it.
          const CopyFolderFile(
            mediaStoreId: 900,
            folderName: 'goa',
            fileName: '2026-10-28_14-32-00.MP4',
            sizeBytes: 1,
            ownedByTakeTray: false,
          ),
          const CopyFolderFile(
            mediaStoreId: 901,
            folderName: 'Paris',
            fileName: '2026-10-28_10-01-00.mp4',
            sizeBytes: 1,
            ownedByTakeTray: true,
          ),
        ];

      await startVn(goa, [own, none, clash]);

      final names = {
        for (final i in copy.starts.single.items) i.clipId: i.fileName,
      };
      // London is UTC+0 on 28 October 2026 (after the change).
      expect(names[own], '2026-10-28_09-01-00.mp4');
      expect(names[none], '2026-10-28_14-32-00_2.mp4');
      expect(names[clash], '2026-10-28_14-33-00_2.mp4');
    });

    for (final editor in [EditorApp.capcut, EditorApp.edits]) {
      test(
        "a ${editor.name} session's second batch goes into the session's "
        'folder (kept after a rename) with new names only: _2 against the '
        'earlier copies and the folder, the earlier copy untouched',
        () async {
          final goa = await reel('Goa');
          final [a, b] = await clipsIn(goa, [1, 2]);
          // Shot at the same minute as the first clip: the same copy name.
          final [twin] = await clipsIn(
            goa,
            [4],
            shot: {4: DateTime.utc(2026, 10, 28, 9, 1)},
          );
          await service.sendOriginals(goa, editor, [a]);
          await recordCopy(goa, a, 501, nameOf(1));
          editors
            ..existing = {501}
            ..files = [
              // The second clip's name is taken by a file of another app.
              CopyFolderFile(
                mediaStoreId: 900,
                folderName: 'goa',
                fileName: nameOf(2),
                sizeBytes: 1,
                ownedByTakeTray: false,
              ),
            ];
          await reels.rename(goa, 'Goa 2026');

          final plan = await service.planCopy(goa, editor, [a, b, twin]);
          final jobId = await service.startCopy(plan);

          expect(plan.startsSession, isFalse);
          expect(plan.folderName, 'Goa');
          final request = copy.starts.single;
          expect(request.jobId, jobId);
          expect(request.folderName, 'Goa');
          // Shooting order: the twin (09:01) before the second clip (09:02).
          expect([for (final i in request.items) i.clipId], [twin, b]);
          expect(
            [for (final i in request.items) i.fileName],
            ['2026-10-28_09-01-00_2.mp4', '2026-10-28_09-02-00_2.mp4'],
          );
          // The earlier copy keeps its name and row; the session is the same.
          final copies = await copiesOf(goa);
          expect([for (final c in copies) c.copyMediaStoreId], [501]);
          expect(copies.single.fileName, nameOf(1));
          final session = (await sessions.sessionOf(goa))!;
          expect(session.editor, editor);
          expect(session.folderName, 'Goa');
          final saved = (await h.media.phoneState.copyJobPlan())!;
          expect(saved.editor, editor);
          expect(saved.startedSession, isFalse);
          expect(saved.folderName, 'Goa');
        },
      );
    }

    test('CopyBusy from start ends the session it just started, removes the '
        'plan and rethrows', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      final plan = await service.planCopy(goa, EditorApp.vn, ids);
      copy.job = const CopyJob(
        jobId: 'native-left',
        reelId: 77,
        folderName: 'x',
        state: CopyState.finished,
        total: 0,
        done: 0,
        bytesDone: 0,
        bytesTotal: 0,
        copied: [],
        failedClipIds: [],
        undeleted: [],
      );

      await expectLater(service.startCopy(plan), throwsA(isA<CopyBusy>()));
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });

    test('any other start failure does the same; an add job keeps the '
        'session it did not start', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      copy.failNext('start');
      await expectLater(startVn(goa, [a]), throwsA(isA<PlatformException>()));
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);

      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.existing = {501};
      copy.failNext('start');
      await expectLater(startVn(goa, [b]), throwsA(isA<PlatformException>()));
      expect(await copyIdsOf(goa), {501});
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });

    test('a double call starts one job', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      final plan = await service.planCopy(goa, EditorApp.vn, ids);

      final first = service.startCopy(plan);
      final second = service.startCopy(plan);

      expect(await second, await first);
      expect(copy.starts, hasLength(1));
    });

    test("while another job's plan is saved: CopyBusy, and nothing is "
        'written', () async {
      final goa = await reel('Goa');
      final paris = await reel('Paris');
      final goaIds = await clipsIn(goa, [1]);
      final parisIds = await clipsIn(paris, [2]);
      final parisPlan = await service.planCopy(paris, EditorApp.vn, parisIds);
      final first = await startVn(goa, goaIds);
      final saved = await h.media.phoneState.copyJobPlan();

      await expectLater(service.startCopy(parisPlan), throwsA(isA<CopyBusy>()));
      expect(await sessions.editState(paris), isNull);
      expect((await h.media.phoneState.copyJobPlan())!.jobId, first);
      expect(await h.media.phoneState.copyJobPlan(), saved);
      expect(copy.starts, hasLength(1));
    });

    test('a clip that went missing after the plan is left out; with none '
        'left: StateError and no session', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final plan = await service.planCopy(goa, EditorApp.vn, [a, b]);
      await flagForTest(h, {a}, missing: true);

      await service.startCopy(plan);
      expect([for (final i in copy.starts.single.items) i.clipId], [b]);

      final paris = await reel('Paris');
      final [c] = await clipsIn(paris, [3]);
      final parisPlan = await service.planCopy(paris, EditorApp.vn, [c]);
      await flagForTest(h, {c}, missing: true);
      await service.cancelCopy(copy.job!.jobId);
      await expectLater(service.startCopy(parisPlan), throwsStateError);
      expect(await sessions.editState(paris), isNull);
    });
  });

  group('applyJob', () {
    test('records each copied file once, with its time; applying the same '
        'job again adds nothing', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);

      final first = progress([copied(a, 601, nameOf(1), size: 1001)]);
      await service.applyJob(first);
      final both = progress([
        copied(a, 601, nameOf(1), size: 1001),
        copied(b, 602, nameOf(2), size: 1002),
      ]);
      await service.applyJob(both);
      await service.applyJob(both);
      await service.applyJob(first);

      final rows = await copiesOf(goa);
      expect([for (final c in rows) c.copyMediaStoreId], [601, 602]);
      expect(rows.first.sizeBytes, 1001);
      expect(rows.first.fileName, nameOf(1));
      expect(rows.first.copiedAt, DateTime.utc(2026, 10, 30, 11));
      expect(editors.calls, isNot(contains('deleteCopies')));
    });

    test('a copy whose clip has left the reel is deleted through '
        'deleteCopies and not recorded', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      await h.media.clips.removeClipsFromReel(goa, [b]);
      editors.existing = {601, 602};

      await service.applyJob(
        progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
      );

      expect(await copyIdsOf(goa), {601});
      expect(editors.deleteAsked.single, [
        CopyFileRef(mediaStoreId: 602, folderName: 'Goa', fileName: nameOf(2)),
      ]);
      expect(editors.existing, {601});
    });

    test('a copy whose session is gone is deleted and not recorded', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await startVn(goa, [a]);
      await sessions.endSession(goa);
      editors.existing = {601};

      await service.applyJob(progress([copied(a, 601, nameOf(1))]));

      expect(await sessions.editState(goa), isNull);
      expect(editors.deleteAsked.single.single.mediaStoreId, 601);
      expect(editors.existing, isEmpty);
    });

    test('a copy of a clip that left the reel which cannot be deleted is '
        'recorded, so Done editing finds it', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      await h.media.clips.removeClipsFromReel(goa, [b]);
      editors.deleteReport = const DeleteReport(refused: {602});

      await service.applyJob(progress([copied(b, 602, nameOf(2))]));
      await service.applyJob(progress([copied(b, 602, nameOf(2))]));

      expect(await copyIdsOf(goa), {602});
      expect(editors.deleteAsked, hasLength(1));
    });

    test("a cancelled job removes its deleted copies' rows; undeleted ones "
        'stay recorded', () async {
      final goa = await reel('Goa');
      final [a, b, c] = await clipsIn(goa, [1, 2, 3]);
      await startVn(goa, [a, b, c]);
      await service.applyJob(
        progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
      );

      final cancelled = copy.job!.copyWith(
        state: CopyState.cancelled,
        copied: [copied(a, 601, nameOf(1))],
        undeleted: [copied(b, 602, nameOf(2)), copied(c, 603, nameOf(3))],
      );
      await service.applyJob(cancelled);

      expect(await copyIdsOf(goa), {602, 603});
    });

    test(
      "a job whose id is not the saved plan's (an old job) is ignored",
      () async {
        final goa = await reel('Goa');
        final [a] = await clipsIn(goa, [1]);
        await startVn(goa, [a]);
        final old = copy.job!.copyWith(
          jobId: '$goa-1',
          copied: [copied(a, 601, nameOf(1))],
        );

        await service.applyJob(old);

        expect(await copiesOf(goa), isEmpty);
      },
    );

    test('a copy whose row a verify removed (deleted outside TakeTray) is not '
        'recorded again by a later event of the same job', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      await service.applyJob(progress([copied(a, 601, nameOf(1))]));
      editors.existing = {};
      await service.verifyCopies(goa);
      expect(await copiesOf(goa), isEmpty);

      await service.applyJob(
        progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
      );

      expect(await copyIdsOf(goa), {602});
    });
  });

  group('finishJob', () {
    test('applies the result, clears the engine, removes the plan; the plan '
        'stays through every event before it', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, [a, b]);
      await service.applyJob(progress([copied(a, 601, nameOf(1))]));
      expect(await h.media.phoneState.copyJobPlan(), isNotNull);
      progress([
        copied(a, 601, nameOf(1)),
        copied(b, 602, nameOf(2)),
      ], state: CopyState.finished);
      expect(await h.media.phoneState.copyJobPlan(), isNotNull);

      await service.finishJob(jobId);

      expect(await copyIdsOf(goa), {601, 602});
      expect(copy.calls, contains('clear'));
      expect(copy.job, isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(await service.jobContext(jobId), isNull);
    });

    test('a running job is not finished: StateError, the plan stays', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, ids);

      await expectLater(service.finishJob(jobId), throwsStateError);
      expect(await h.media.phoneState.copyJobPlan(), isNotNull);
    });

    test('a copy recorded just before its clip left the reel (a race with '
        'remove) is deleted at the finish', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, [a, b]);
      await service.applyJob(
        progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
      );
      editors.existing = {601, 602};
      // The remove's own clean-up ran just before 602 was recorded.
      await h.media.clips.removeClipsFromReel(goa, [b]);
      progress([
        copied(a, 601, nameOf(1)),
        copied(b, 602, nameOf(2)),
      ], state: CopyState.finished);

      await service.finishJob(jobId);

      expect(await copyIdsOf(goa), {601});
      expect(editors.existing, {601});
    });

    test('everything failed: the empty session the job started ends', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, [a]);
      copy.emit(
        copy.job!.copyWith(
          state: CopyState.finished,
          done: 1,
          failedClipIds: [a],
        ),
      );

      await service.finishJob(jobId);

      expect(await sessions.editState(goa), isNull);
    });
  });

  group('cancelCopy', () {
    test('a job that started its session: with nothing left the session '
        'ends; the copies and the plan go and the engine is cleared', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, [a, b]);
      await service.applyJob(progress([copied(a, 601, nameOf(1))]));

      await service.cancelCopy(jobId);

      expect(copy.calls, containsAllInOrder(['cancel', 'clear']));
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(copy.job, isNull);
    });

    test('a copy that could not be deleted keeps the session', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, [a, b]);
      await service.applyJob(
        progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
      );
      copy.cancelUndeleted = {b};

      await service.cancelCopy(jobId);

      expect(await copyIdsOf(goa), {602});
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });

    test('an add job keeps the session and its earlier copies', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.existing = {501};
      final jobId = await startVn(goa, [b]);
      await service.applyJob(progress([copied(b, 602, nameOf(2))]));

      await service.cancelCopy(jobId);

      expect(await copyIdsOf(goa), {501});
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });

    test('a cancel the engine cannot answer keeps the plan', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, ids);
      copy.failNext('cancel');

      await expectLater(
        service.cancelCopy(jobId),
        throwsA(isA<PlatformException>()),
      );
      expect((await h.media.phoneState.copyJobPlan())!.jobId, jobId);
      expect(await sessions.editState(goa), isNotNull);
    });
  });

  group('doneEditing', () {
    test('deletes every copy, then ends the session; gone counts as deleted; '
        'freedBytes sums the deleted copies', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      editors.deleteReport = const DeleteReport(deleted: {501}, gone: {502});

      final result = await service.doneEditing(goa);

      expect(
        result,
        const DoneEditingResult(editor: EditorApp.vn, freedBytes: 100),
      );
      expect(editors.deleteAsked.single, [
        CopyFileRef(mediaStoreId: 501, folderName: 'Goa', fileName: nameOf(1)),
        CopyFileRef(mediaStoreId: 502, folderName: 'Goa', fileName: nameOf(2)),
      ]);
      expect(await sessions.editState(goa), isNull);
    });

    test('a refused or failed copy: CopiesNotDeleted; the session and the '
        'rows not deleted stay, the deleted rows go', () async {
      final goa = await reel('Goa');
      final [a, b, c] = await clipsIn(goa, [1, 2, 3]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      await recordCopy(goa, c, 503, nameOf(3));
      editors.deleteReport = const DeleteReport(
        deleted: {501},
        refused: {502},
        failed: {503},
      );

      await expectLater(
        service.doneEditing(goa),
        throwsA(isA<CopiesNotDeleted>().having((e) => e.count, 'count', 2)),
      );
      expect(await copyIdsOf(goa), {502, 503});
      expect(await sessions.sessionOf(goa), isNotNull);
    });

    test('a delete that throws: CopiesNotDeleted, nothing removed', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.failNext('deleteCopies');

      await expectLater(
        service.doneEditing(goa),
        throwsA(isA<CopiesNotDeleted>().having((e) => e.count, 'count', 1)),
      );
      expect(await copyIdsOf(goa), {501});
    });

    test('refuses with StateError while a job for this reel runs', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      await startVn(goa, ids);

      await expectLater(service.doneEditing(goa), throwsStateError);
      expect(await sessions.sessionOf(goa), isNotNull);
      expect(editors.calls, isNot(contains('deleteCopies')));
    });

    test(
      'works with no copies (CapCut): no delete, the session ends',
      () async {
        final goa = await reel('Goa');
        final ids = await clipsIn(goa, [1]);
        await service.sendOriginals(goa, EditorApp.capcut, ids);

        expect(
          await service.doneEditing(goa),
          const DoneEditingResult(editor: EditorApp.capcut, freedBytes: 0),
        );
        expect(editors.calls, isNot(contains('deleteCopies')));
        expect(await sessions.editState(goa), isNull);
      },
    );

    test('a reel with no session throws StateError', () async {
      final goa = await reel('Goa');

      await expectLater(service.doneEditing(goa), throwsStateError);
    });
  });

  group('verifyCopies', () {
    test('rows whose file is gone are removed, the others stay', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      editors.existing = {502};

      await service.verifyCopies(goa);

      expect(await copyIdsOf(goa), {502});
    });

    test('a throwing bridge changes nothing and is passed on', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.failNext('existingCopies');

      await expectLater(
        service.verifyCopies(goa),
        throwsA(isA<PlatformException>()),
      );
      expect(await copyIdsOf(goa), {501});
    });

    test('no session or no copies: no bridge call', () async {
      final goa = await reel('Goa');
      await service.verifyCopies(goa);
      await sessions.startSession(goa, EditorApp.capcut, 'Goa');
      await service.verifyCopies(goa);

      expect(editors.calls, isEmpty);
    });
  });

  group('beforeClipsLeaveReel', () {
    test("deletes those clips' copies and rows first and says how many: 0, 1 "
        'and several; sent rows stay', () async {
      final goa = await reel('Goa');
      final [a, b, c, d] = await clipsIn(goa, [1, 2, 3, 4]);
      await service.sendOriginals(goa, EditorApp.capcut, [a, b, c, d]);
      await recordCopy(goa, b, 502, nameOf(2));
      await recordCopy(goa, c, 503, nameOf(3));
      await recordCopy(goa, d, 504, nameOf(4));
      editors.existing = {502, 503, 504};

      expect(await service.beforeClipsLeaveReel(goa, {a}), 0);
      expect(editors.calls, isNot(contains('deleteCopies')));
      expect(await service.beforeClipsLeaveReel(goa, {a, b}), 1);
      expect(await service.beforeClipsLeaveReel(goa, {c, d}), 2);

      expect(await copiesOf(goa), isEmpty);
      expect(editors.existing, isEmpty);
      expect((await sessions.editState(goa))!.sentIds, {a, b, c, d});
    });

    test('a copy that cannot be deleted throws CopiesNotDeleted and its row '
        'stays', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      editors.deleteReport = const DeleteReport(refused: {501, 502});

      await expectLater(
        service.beforeClipsLeaveReel(goa, {a, b}),
        throwsA(isA<CopiesNotDeleted>().having((e) => e.count, 'count', 2)),
      );
      expect(await copyIdsOf(goa), {501, 502});
    });

    test(
      'a throwing bridge throws CopiesNotDeleted and removes nothing',
      () async {
        final goa = await reel('Goa');
        final [a] = await clipsIn(goa, [1]);
        await sessions.startSession(goa, EditorApp.vn, 'Goa');
        await recordCopy(goa, a, 501, nameOf(1));
        editors.failNext('deleteCopies');

        await expectLater(
          service.beforeClipsLeaveReel(goa, {a}),
          throwsA(isA<CopiesNotDeleted>()),
        );
        expect(await copyIdsOf(goa), {501});
      },
    );

    test('a reel with no session does nothing', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);

      expect(await service.beforeClipsLeaveReel(goa, ids.toSet()), 0);
      expect(editors.calls, isEmpty);
    });
  });

  group('beforeReelDelete', () {
    test(
      "cancels this reel's job, deletes every copy, ends the session",
      () async {
        final goa = await reel('Goa');
        final [a, b] = await clipsIn(goa, [1, 2]);
        await sessions.startSession(goa, EditorApp.vn, 'Goa');
        await recordCopy(goa, a, 501, nameOf(1));
        editors.existing = {501};
        final jobId = await startVn(goa, [b]);
        await service.applyJob(progress([copied(b, 602, nameOf(2))]));

        await service.beforeReelDelete(goa);

        expect(copy.calls, contains('cancel'));
        expect(editors.existing, isEmpty);
        expect(await sessions.editState(goa), isNull);
        expect(await h.media.phoneState.copyJobPlan(), isNull);
        expect(await service.jobContext(jobId), isNull);
      },
    );

    test("another reel's job is left running", () async {
      final goa = await reel('Goa');
      final paris = await reel('Paris');
      final goaIds = await clipsIn(goa, [1]);
      await service.sendOriginals(goa, EditorApp.capcut, goaIds);
      final parisIds = await clipsIn(paris, [2]);
      await startVn(paris, parisIds);

      await service.beforeReelDelete(goa);

      expect(copy.calls, isNot(contains('cancel')));
      expect(copy.job!.state, CopyState.running);
      expect(await sessions.editState(goa), isNull);
    });

    test('any copy not deleted throws and nothing is ended', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.deleteReport = const DeleteReport(failed: {501});

      await expectLater(
        service.beforeReelDelete(goa),
        throwsA(isA<CopiesNotDeleted>()),
      );
      expect(await copyIdsOf(goa), {501});
    });

    test('no session: nothing to do', () async {
      final goa = await reel('Goa');
      await service.beforeReelDelete(goa);
      expect(editors.calls, isEmpty);
    });
  });

  group('storage', () {
    CopyFolderFile file(int id, String folder, String name, int size) =>
        CopyFolderFile(
          mediaStoreId: id,
          folderName: folder,
          fileName: name,
          sizeBytes: size,
          ownedByTakeTray: id.isEven,
        );

    test('the sessions, and the files no session records grouped by folder '
        'with counts and bytes', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      editors.files = [
        file(501, 'Goa', nameOf(1), 100),
        file(700, 'Old trip', 'a.mp4', 10),
        file(702, 'Beach', 'b.mp4', 20),
        file(701, 'Old trip', 'c.mp4', 30),
        file(703, 'Goa', 'stray.mp4', 5),
      ];

      final overview = await service.storage();

      expect(overview.sessions, await sessions.summaries());
      expect(overview.orphans, [
        OrphanFolder(
          folderName: 'Beach',
          fileCount: 1,
          bytes: 20,
          files: const [
            CopyFileRef(
              mediaStoreId: 702,
              folderName: 'Beach',
              fileName: 'b.mp4',
            ),
          ],
        ),
        OrphanFolder(
          folderName: 'Goa',
          fileCount: 1,
          bytes: 5,
          files: const [
            CopyFileRef(
              mediaStoreId: 703,
              folderName: 'Goa',
              fileName: 'stray.mp4',
            ),
          ],
        ),
        OrphanFolder(
          folderName: 'Old trip',
          fileCount: 2,
          bytes: 40,
          files: const [
            CopyFileRef(
              mediaStoreId: 700,
              folderName: 'Old trip',
              fileName: 'a.mp4',
            ),
            CopyFileRef(
              mediaStoreId: 701,
              folderName: 'Old trip',
              fileName: 'c.mp4',
            ),
          ],
        ),
      ]);
    });

    test(
      'the folder of a running job or a saved plan is never listed',
      () async {
        final goa = await reel('Goa');
        final ids = await clipsIn(goa, [1]);
        await startVn(goa, ids);
        editors.files = [
          file(601, 'goa', nameOf(1), 100),
          file(700, 'Old', 'a.mp4', 10),
        ];

        expect(
          [for (final o in (await service.storage()).orphans) o.folderName],
          ['Old'],
        );

        // After a restart only the plan says which folder is busy.
        restart();
        expect(
          [for (final o in (await service.storage()).orphans) o.folderName],
          ['Old'],
        );
      },
    );

    test('a bridge failure gives the sessions with no orphans, logged by '
        'type', () async {
      final logs = captureLogs();
      final goa = await reel('Goa');
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      editors.failNext('filesInCopyFolders');

      final overview = await service.storage();

      expect(overview.sessions, hasLength(1));
      expect(overview.orphans, isEmpty);
      expect(
        logs.map((r) => r.message).join('\n'),
        contains('PlatformException'),
      );
    });
  });

  group('deleteOrphans', () {
    final folder = OrphanFolder(
      folderName: 'Old trip',
      fileCount: 2,
      bytes: 40,
      files: const [
        CopyFileRef(mediaStoreId: 700, folderName: 'Old trip', fileName: 'a'),
        CopyFileRef(mediaStoreId: 701, folderName: 'Old trip', fileName: 'c'),
      ],
    );

    test(
      "asks Android with that folder's files; allowed frees its bytes",
      () async {
        final result = await service.deleteOrphans(folder);
        expect(result.allowed, isTrue);
        expect(result.freedBytes, 40);
        expect(editors.deleteRequested.single, folder.files);
      },
    );

    test('declined: not allowed, nothing freed', () async {
      editors.requestDeleteResult = false;
      final result = await service.deleteOrphans(folder);
      expect(result.allowed, isFalse);
      expect(result.freedBytes, 0);
    });

    test('allowed for files that report no size: allowed, 0 bytes (not '
        'declined)', () async {
      final empty = OrphanFolder(
        folderName: 'Unscanned',
        fileCount: 1,
        bytes: 0,
        files: const [
          CopyFileRef(
            mediaStoreId: 710,
            folderName: 'Unscanned',
            fileName: 'z',
          ),
        ],
      );
      final result = await service.deleteOrphans(empty);
      expect(result.allowed, isTrue);
      expect(result.freedBytes, 0);
    });
  });

  group('recoverAtStart', () {
    test('an in-process job (the activity was re-created) is applied and '
        'nothing is deleted', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      // Events were dropped while no Dart side listened.
      copy.job = copy.job!.copyWith(
        copied: [copied(a, 601, nameOf(1))],
        done: 1,
      );
      copy.calls.clear();
      editors.calls.clear();
      service = make();

      expect(await service.recoverAtStart(), isNull);

      expect(await copyIdsOf(goa), {601});
      expect(copy.calls, isNot(contains('deletePendingIn')));
      expect(editors.calls, isNot(contains('deleteCopies')));
      expect(await h.media.phoneState.copyJobPlan(), isNotNull);
    });

    test('after a restart: the pending rows go first, then finished rows '
        "named as a plan item are recorded for that item's clip, at the "
        'clock; a row matching no item is left alone', () async {
      final goa = await reel('Goa');
      final [a, b, c] = await clipsIn(goa, [1, 2, 3]);
      final jobId = await startVn(goa, [a, b, c]);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
        FolderRow(
          mediaStoreId: 602,
          fileName: nameOf(2),
          sizeBytes: 400,
          pending: true,
        ),
        const FolderRow(
          mediaStoreId: 650,
          fileName: 'mine.mp4',
          sizeBytes: 9,
          pending: false,
        ),
      ];
      restart();
      h.media.clock.advance(const Duration(minutes: 5));
      final at = h.media.clock.storedNow();

      final job = (await service.recoverAtStart())!;

      expect(copy.calls.take(2), ['current', 'deletePendingIn']);
      expect(
        copy.calls.indexOf('ownRowsIn'),
        greaterThan(copy.calls.indexOf('deletePendingIn')),
      );
      expect(copy.folders['Goa']!.where((r) => r.pending), isEmpty);
      final rows = await copiesOf(goa);
      expect(rows, [
        EditCopy(
          reelId: goa,
          clipId: a,
          copyMediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          copiedAt: at,
        ),
      ]);
      expect(editors.calls, isNot(contains('deleteCopies')));
      expect(editors.calls, isNot(contains('requestDelete')));
      expect(copy.folders['Goa']!.map((r) => r.mediaStoreId), [601, 650]);

      expect(job.jobId, jobId);
      expect(job.reelId, goa);
      expect(job.folderName, 'Goa');
      expect(job.state, CopyState.interrupted);
      expect(job.total, 3);
      expect(job.done, 1);
      expect(job.bytesTotal, 1001 + 1002 + 1003);
      expect(job.copied.map((f) => (f.clipId, f.copyMediaStoreId)), [(a, 601)]);
      expect(service.lastLocalJob, job);
    });

    test('matches by file name, never by size', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      // Item b's name, with item a's size.
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 602,
          fileName: nameOf(2),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      restart();

      await service.recoverAtStart();

      final rows = await copiesOf(goa);
      expect(rows.single.clipId, b);
      expect(rows.single.copyMediaStoreId, 602);
    });

    test('a copy already recorded is not recorded twice (a crash between '
        'recording and removing the plan)', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, [a, b]);
      final first = copied(a, 601, nameOf(1), size: 1001);
      await service.applyJob(progress([first]));
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      restart();
      h.media.clock.advance(const Duration(minutes: 5));

      final job = (await service.recoverAtStart())!;

      final rows = await copiesOf(goa);
      expect(rows, hasLength(1));
      expect(rows.single.copiedAt, first.copiedAt);
      expect(job.copied.single.copyMediaStoreId, 601);

      // A second start finds the same and records nothing more.
      restart();
      await service.recoverAtStart();
      expect(await copiesOf(goa), hasLength(1));
      expect((await h.media.phoneState.copyJobPlan())!.jobId, jobId);
    });

    test('a recorded copy MediaStore renamed is listed by its clip, not by '
        'the name', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      final renamed = nameOf(1).replaceFirst('.mp4', ' (1).mp4');
      await service.applyJob(progress([copied(a, 601, renamed)]));
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: renamed,
          sizeBytes: 10,
          pending: false,
        ),
      ];
      restart();

      final job = (await service.recoverAtStart())!;

      expect(job.copied.single.clipId, a);
      expect(job.done, 1);
      expect(await copiesOf(goa), hasLength(1));
    });

    test('no plan: nothing to recover, and no folder is touched', () async {
      restart();

      expect(await service.recoverAtStart(), isNull);
      expect(copy.calls, isNot(contains('deletePendingIn')));
      expect(copy.calls, isNot(contains('ownRowsIn')));
    });

    test('a throwing bridge is logged and changes nothing; the plan stays '
        'for the next start', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, [a]);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      restart();
      final logs = captureLogs();
      copy.failNext('ownRowsIn');

      expect(await service.recoverAtStart(), isNull);

      expect(await copiesOf(goa), isEmpty);
      expect((await h.media.phoneState.copyJobPlan())!.jobId, jobId);
      expect(
        logs.map((r) => r.message).join('\n'),
        contains('PlatformException'),
      );

      restart();
      expect((await service.recoverAtStart())!.done, 1);
    });

    test('ends sessions with no copies, no sent rows and no plan; keeps the '
        "others and the plan's", () async {
      final empty = await reel('Empty');
      final sent = await reel('Sent');
      final copiedReel = await reel('Copied');
      final planned = await reel('Planned');
      await sessions.startSession(empty, EditorApp.capcut, 'Empty');
      final sentIds = await clipsIn(sent, [1]);
      await service.sendOriginals(sent, EditorApp.edits, sentIds);
      final [c] = await clipsIn(copiedReel, [2]);
      await sessions.startSession(copiedReel, EditorApp.vn, 'Copied');
      await recordCopy(copiedReel, c, 502, nameOf(2));
      final plannedIds = await clipsIn(planned, [3]);
      await startVn(planned, plannedIds);
      restart();

      await service.recoverAtStart();

      expect(await sessions.sessionOf(empty), isNull);
      expect(await sessions.sessionOf(sent), isNotNull);
      expect(await sessions.sessionOf(copiedReel), isNotNull);
      expect(await sessions.sessionOf(planned), isNotNull);
    });

    test("a plan whose reel's session is gone: its finished copies are "
        'deleted, not recorded, and the plan goes', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await startVn(goa, [a]);
      await sessions.endSession(goa);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      editors.existing = {601};
      restart();

      expect(await service.recoverAtStart(), isNull);

      expect(editors.deleteAsked.single.single.mediaStoreId, 601);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });
  });

  group('after a restart', () {
    Future<(int, List<int>, String)> interrupted() async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2, 3]);
      final jobId = await startVn(goa, ids);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
        FolderRow(
          mediaStoreId: 602,
          fileName: nameOf(2),
          sizeBytes: 50,
          pending: true,
        ),
      ];
      restart();
      await service.recoverAtStart();
      return (goa, ids, jobId);
    }

    test('resumeCopy starts the job again with only the items not yet '
        'recorded, keeping their names', () async {
      final (_, [_, b, c], jobId) = await interrupted();

      await service.resumeCopy(jobId);

      final request = copy.starts.single;
      expect(request.jobId, jobId);
      expect(request.folderName, 'Goa');
      expect([for (final i in request.items) i.clipId], [b, c]);
      expect(
        [for (final i in request.items) i.fileName],
        [nameOf(2), nameOf(3)],
      );
      expect([for (final i in request.items) i.sizeBytes], [1002, 1003]);
      expect(request.items.first.source, await refOf(b));
    });

    test('when every item was recorded, it finishes at once', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, [a]);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      restart();
      await service.recoverAtStart();
      final jobs = <CopyJob>[];
      final sub = service.localJobs.listen(jobs.add);
      addTearDown(sub.cancel);

      await service.resumeCopy(jobId);
      await pumpEventQueue();

      expect(copy.starts, isEmpty);
      expect(jobs.single.state, CopyState.finished);
      expect(jobs.single.jobId, jobId);
      expect(jobs.single.copied.single.copyMediaStoreId, 601);
      expect(service.lastLocalJob, jobs.single);

      await service.finishJob(jobId);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(await copyIdsOf(goa), {601});
    });

    test('cancelCopy deletes the copies it recorded (guarded) and their '
        'rows, and ends the session it started', () async {
      final (goa, [a, _, _], jobId) = await interrupted();
      editors.existing = {601};

      await service.cancelCopy(jobId);

      expect(editors.deleteAsked.single, [
        CopyFileRef(mediaStoreId: 601, folderName: 'Goa', fileName: nameOf(1)),
      ]);
      expect(await copiesOf(goa), isEmpty);
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(service.lastLocalJob!.state, CopyState.cancelled);
      expect(service.lastLocalJob!.copied.single.clipId, a);
    });

    test(
      'a recovered copy that cannot be deleted on cancel stays recorded',
      () async {
        final (goa, _, jobId) = await interrupted();
        editors.deleteReport = const DeleteReport(refused: {601});

        await service.cancelCopy(jobId);

        expect(await copyIdsOf(goa), {601});
        expect(await sessions.sessionOf(goa), isNotNull);
        expect(service.lastLocalJob!.undeleted.single.copyMediaStoreId, 601);
      },
    );

    test('jobContext gives the editor and startedSession while the plan is '
        'saved, also after a restart, and null once it is removed', () async {
      final (_, _, jobId) = await interrupted();

      expect(await service.jobContext(jobId), (
        editor: EditorApp.vn,
        startedSession: true,
      ));
      expect(await service.jobContext('1-1'), isNull);

      await service.cancelCopy(jobId);
      expect(await service.jobContext(jobId), isNull);
    });

    test('an add job reports startedSession false', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await service.sendOriginals(goa, EditorApp.capcut, [a]);
      final plan = await service.planCopy(goa, EditorApp.capcut, [b]);
      final jobId = await service.startCopy(plan);

      expect(await service.jobContext(jobId), (
        editor: EditorApp.capcut,
        startedSession: false,
      ));
    });
  });

  group('Android stops TakeTray mid-copy (Review Focus 1)', () {
    test('no pending file is left, every finished copy is recorded once, '
        'none twice, Try again copies only the rest, and the session is '
        'never stuck', () async {
      final goa = await reel('Goa');
      final [a, b, c, d] = await clipsIn(goa, [1, 2, 3, 4]);
      final jobId = await startVn(goa, [a, b, c, d]);
      // a finished and was recorded; b finished but its event never reached
      // Dart; c was half written when Android stopped the process.
      await service.applyJob(progress([copied(a, 601, nameOf(1), size: 1001)]));
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
        FolderRow(
          mediaStoreId: 602,
          fileName: nameOf(2),
          sizeBytes: 1002,
          pending: false,
        ),
        FolderRow(
          mediaStoreId: 603,
          fileName: nameOf(3),
          sizeBytes: 300,
          pending: true,
        ),
      ];
      restart();

      final job = (await service.recoverAtStart())!;
      expect(job.state, CopyState.interrupted);
      expect(job.done, 2);
      expect(copy.folders['Goa']!.where((r) => r.pending), isEmpty);
      expect(await copyIdsOf(goa), {601, 602});

      await service.resumeCopy(jobId);
      expect([for (final i in copy.starts.single.items) i.clipId], [c, d]);
      await service.applyJob(progress([copied(c, 604, nameOf(3))]));
      // The activity is re-created mid-job: the in-process job is applied
      // again.
      service = make();
      expect(await service.recoverAtStart(), isNull);
      progress([
        copied(c, 604, nameOf(3)),
        copied(d, 605, nameOf(4)),
      ], state: CopyState.finished);
      await service.finishJob(jobId);

      final rows = await copiesOf(goa);
      expect([for (final r in rows) r.clipId], [a, b, c, d]);
      expect([for (final r in rows) r.copyMediaStoreId], [601, 602, 604, 605]);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(copy.job, isNull);
      expect(await sessions.sessionOf(goa), isNotNull);
    });

    test('stopped before any copy finished, then Stop: the session ends and '
        'no plan is left', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, ids);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 3,
          pending: true,
        ),
      ];
      restart();

      expect((await service.recoverAtStart())!.done, 0);
      await service.cancelCopy(jobId);

      expect(copy.folders['Goa'], isEmpty);
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
    });
  });

  group('the serial queue', () {
    test('two mutating calls never interleave', () async {
      final gated = _GatedEditors();
      editors = gated;
      service = make();
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      gated
        ..existing = {501, 502}
        ..gate = Completer<void>();

      final leaving = service.beforeClipsLeaveReel(goa, {a});
      final verify = service.verifyCopies(goa);
      await pumpEventQueue();
      expect(gated.calls, ['deleteCopies:waiting']);

      gated.gate!.complete();
      expect(await leaving, 1);
      await verify;
      expect(gated.calls, [
        'deleteCopies:waiting',
        'deleteCopies',
        'existingCopies',
      ]);
      expect(await copyIdsOf(goa), {502});
    });

    test('a failing call does not stop the queue', () async {
      editors = _ThrowingExisting();
      service = make();
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));

      await expectLater(service.verifyCopies(goa), throwsStateError);
      expect(await service.beforeClipsLeaveReel(goa, {a}), 1);
    });
  });

  group('doneEditing is never stuck (fix round 1)', () {
    Future<(int, List<int>, String)> twoCopiesStarted() async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, ids);
      editors.existing = {601, 602};
      return (goa, ids, jobId);
    }

    void expectSettled(int goa, String jobId) {
      expect(copy.job, isNull, reason: 'the engine result is cleared');
    }

    test(
      'a finished job whose Continue was never tapped: its copies are '
      'recorded, deleted, and the plan, the result and the session go',
      () async {
        final (goa, [a, b], jobId) = await twoCopiesStarted();
        progress([
          copied(a, 601, nameOf(1)),
          copied(b, 602, nameOf(2)),
        ], state: CopyState.finished);

        final result = await service.doneEditing(goa);

        expect(
          result,
          const DoneEditingResult(editor: EditorApp.vn, freedBytes: 20),
        );
        expect(editors.existing, isEmpty);
        expect(await sessions.editState(goa), isNull);
        expect(await h.media.phoneState.copyJobPlan(), isNull);
        expect(await service.jobContext(jobId), isNull);
        expectSettled(goa, jobId);
      },
    );

    test(
      'a cancelled job: the copy it could not delete is deleted now',
      () async {
        final (goa, [a, b], jobId) = await twoCopiesStarted();
        progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]);
        editors.existing = {602};
        copy.emit(
          copy.job!.copyWith(
            state: CopyState.cancelled,
            copied: [copied(a, 601, nameOf(1))],
            undeleted: [copied(b, 602, nameOf(2))],
          ),
        );

        await service.doneEditing(goa);

        expect(editors.existing, isEmpty);
        expect(editors.deleteAsked.single.single.mediaStoreId, 602);
        expect(await sessions.editState(goa), isNull);
        expect(await h.media.phoneState.copyJobPlan(), isNull);
        expectSettled(goa, jobId);
      },
    );

    for (final state in [CopyState.spaceFull, CopyState.interrupted]) {
      test(
        'a ${state.name} job: the copies made are deleted, the job goes',
        () async {
          final (goa, [a, _], jobId) = await twoCopiesStarted();
          progress([copied(a, 601, nameOf(1))], state: state);

          final result = await service.doneEditing(goa);

          expect(result.freedBytes, 10);
          expect(editors.existing, {602});
          expect(await sessions.editState(goa), isNull);
          expect(await h.media.phoneState.copyJobPlan(), isNull);
          expectSettled(goa, jobId);
        },
      );
    }

    test('a plan left after a restart (no engine job): the copies recovery '
        'found are deleted and the plan goes', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, ids);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      editors.existing = {601};
      restart();
      await service.recoverAtStart();

      final result = await service.doneEditing(goa);

      expect(result.freedBytes, 1001);
      expect(editors.existing, isEmpty);
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(await service.jobContext(jobId), isNull);
    });

    test(
      'a saved plan and no engine job and no recovery yet: still settled',
      () async {
        final goa = await reel('Goa');
        final ids = await clipsIn(goa, [1]);
        await startVn(goa, ids);
        restart();

        await service.doneEditing(goa);

        expect(await sessions.editState(goa), isNull);
        expect(await h.media.phoneState.copyJobPlan(), isNull);
      },
    );

    test(
      'a running job for the reel still refuses, and settles nothing',
      () async {
        final (goa, [a, _], jobId) = await twoCopiesStarted();
        progress([copied(a, 601, nameOf(1))]);

        await expectLater(service.doneEditing(goa), throwsStateError);

        expect(copy.job!.state, CopyState.running);
        expect(copy.calls, isNot(contains('clear')));
        expect((await h.media.phoneState.copyJobPlan())!.jobId, jobId);
        expect(editors.calls, isNot(contains('deleteCopies')));
      },
    );

    test(
      "another reel's job running does not stop this reel's Done editing",
      () async {
        final goa = await reel('Goa');
        final paris = await reel('Paris');
        final goaIds = await clipsIn(goa, [1]);
        await service.sendOriginals(goa, EditorApp.capcut, goaIds);
        final parisIds = await clipsIn(paris, [2]);
        await startVn(paris, parisIds);

        final result = await service.doneEditing(goa);

        expect(result.editor, EditorApp.capcut);
        expect(await sessions.editState(goa), isNull);
        expect(copy.job!.state, CopyState.running);
        expect(await h.media.phoneState.copyJobPlan(), isNotNull);
        expect(copy.calls, isNot(contains('clear')));
      },
    );

    test(
      'a delete that fails after the stale job was settled: '
      'CopiesNotDeleted once, and the retry works (no job in the way)',
      () async {
        final (goa, [a, b], jobId) = await twoCopiesStarted();
        progress([
          copied(a, 601, nameOf(1)),
          copied(b, 602, nameOf(2)),
        ], state: CopyState.finished);
        editors.failNext('deleteCopies');

        await expectLater(
          service.doneEditing(goa),
          throwsA(isA<CopiesNotDeleted>()),
        );
        expect(await h.media.phoneState.copyJobPlan(), isNull);
        expect(await service.jobContext(jobId), isNull);
        expect(await copyIdsOf(goa), {601, 602});

        final result = await service.doneEditing(goa);
        expect(result.freedBytes, 20);
        expect(await sessions.editState(goa), isNull);
      },
    );

    test('a copy the guard refuses does not block Done editing: it is '
        'reported, its row goes with the session, and the file is an orphan '
        'on the storage screen', () async {
      final goa = await reel('Goa');
      final [a, b, c] = await clipsIn(goa, [1, 2, 3]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      await recordCopy(goa, c, 503, nameOf(3));
      editors
        ..deleteReport = const DeleteReport(
          deleted: {501},
          gone: {503},
          refused: {502},
        )
        ..files = [
          CopyFolderFile(
            mediaStoreId: 502,
            folderName: 'Goa',
            fileName: nameOf(2),
            sizeBytes: 100,
            ownedByTakeTray: true,
          ),
        ];

      final result = await service.doneEditing(goa);

      expect(
        result,
        const DoneEditingResult(
          editor: EditorApp.vn,
          freedBytes: 100,
          leftBehind: 1,
        ),
      );
      expect(await sessions.editState(goa), isNull);
      final overview = await service.storage();
      expect(overview.orphans.single.files.single.mediaStoreId, 502);
    });

    test('refused and failed together: CopiesNotDeleted, the refused row '
        'stays too (the retry reports it)', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      await recordCopy(goa, a, 501, nameOf(1));
      await recordCopy(goa, b, 502, nameOf(2));
      editors.deleteReport = const DeleteReport(refused: {501}, failed: {502});

      await expectLater(
        service.doneEditing(goa),
        throwsA(isA<CopiesNotDeleted>()),
      );
      expect(await copyIdsOf(goa), {501, 502});
      expect(await sessions.sessionOf(goa), isNotNull);
    });
  });

  group('the session-protecting lines of recoverAtStart (fix round 1)', () {
    test('an activity re-created before the first file finished keeps the '
        "running job's session (empty so far); the first file is recorded "
        'afterwards', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await startVn(goa, [a]);
      service = make();

      expect(await service.recoverAtStart(), isNull);

      expect(await sessions.sessionOf(goa), isNotNull);
      editors.existing = {601};
      await service.applyJob(progress([copied(a, 601, nameOf(1))]));
      expect(await copyIdsOf(goa), {601});
      expect(editors.calls, isNot(contains('deleteCopies')));
    });

    test('with no plan at all, a session with no copies and no sent rows (a '
        'share cut short, a first copy that never started) ends; one with '
        'sent rows stays', () async {
      final empty = await reel('Empty');
      final sent = await reel('Sent');
      await sessions.startSession(empty, EditorApp.capcut, 'Empty');
      final sentIds = await clipsIn(sent, [1]);
      await service.sendOriginals(sent, EditorApp.edits, sentIds);
      restart();

      await service.recoverAtStart();

      expect(await sessions.sessionOf(empty), isNull);
      expect(await sessions.sessionOf(sent), isNotNull);
    });
  });

  group('survivors of the review (fix round 1)', () {
    test('sendOriginals leaves out a clip of another reel', () async {
      final goa = await reel('Goa');
      final paris = await reel('Paris');
      final [a] = await clipsIn(goa, [1]);
      final [x] = await clipsIn(paris, [2]);

      final outcome = await service.sendOriginals(goa, EditorApp.capcut, [
        a,
        x,
      ]);

      expect(outcome, const SendOutcome(SendResult.sent, 1));
      expect(editors.sent.single.$2, [await refOf(a)]);
      expect((await sessions.editState(goa))!.sentIds, {a});
    });

    test('startCopy skips a clip that got a copy between the plan and the '
        'start', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      final plan = await service.planCopy(goa, EditorApp.vn, [a, b]);
      await recordCopy(goa, a, 501, nameOf(1));
      editors.existing = {501};

      await service.startCopy(plan);

      expect([for (final i in copy.starts.single.items) i.clipId], [b]);
    });

    test("resumeCopy of the engine's own spaceFull job resumes it", () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, ids);
      progress(const [], state: CopyState.spaceFull);

      await service.resumeCopy(jobId);

      expect(copy.calls, contains('resume'));
      expect(copy.job!.state, CopyState.running);
    });

    test('resumeCopy of another id while the engine holds a job: CopyBusy, '
        'the engine is not touched', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      await startVn(goa, ids);

      await expectLater(service.resumeCopy('9-9'), throwsA(isA<CopyBusy>()));

      expect(copy.calls, isNot(contains('resume')));
      expect(copy.starts, hasLength(1));
    });

    test('resumeCopy after a restart for a plan whose session is gone: '
        'StateError, nothing started', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, ids);
      await sessions.endSession(goa);
      restart();

      await expectLater(service.resumeCopy(jobId), throwsStateError);

      expect(copy.starts, isEmpty);
    });

    test('resumeCopy after a restart for an id that is not the saved plan: '
        'StateError, nothing started', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1]);
      await startVn(goa, ids);
      restart();

      await expectLater(service.resumeCopy('$goa-1'), throwsStateError);

      expect(copy.starts, isEmpty);
    });

    test('a copy of a clip that left the reel, when the delete itself throws, '
        'stays recorded for Done editing', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      await startVn(goa, [a, b]);
      await h.media.clips.removeClipsFromReel(goa, [b]);
      editors.failNext('deleteCopies');

      await service.applyJob(progress([copied(b, 602, nameOf(2))]));

      expect(await copyIdsOf(goa), {602});
    });

    test(
      'a copy deleted for a leaving clip is not recorded again by a later '
      'event of the job, even if the clip is back in the reel (Undo)',
      () async {
        final goa = await reel('Goa');
        final [a, b] = await clipsIn(goa, [1, 2]);
        await startVn(goa, [a, b]);
        await service.applyJob(
          progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
        );
        editors.existing = {601, 602};
        expect(await service.beforeClipsLeaveReel(goa, {b}), 1);

        await service.applyJob(
          progress([copied(a, 601, nameOf(1)), copied(b, 602, nameOf(2))]),
        );

        expect(await copyIdsOf(goa), {601});
      },
    );

    test('a MediaStore id a verify forgot, reused by a copy of a later job, '
        'is recorded', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      final first = await startVn(goa, [a]);
      await service.applyJob(progress([copied(a, 601, nameOf(1))]));
      editors.existing = {};
      await service.verifyCopies(goa);
      progress([copied(a, 601, nameOf(1))], state: CopyState.finished);
      await service.finishJob(first);
      h.media.clock.advance(const Duration(seconds: 1));
      await startVn(goa, [a]);

      await service.applyJob(progress([copied(a, 601, nameOf(1))]));

      expect(await copyIdsOf(goa), {601});
    });

    test(
      'beforeReelDelete cancels the engine job even when no plan is saved',
      () async {
        final goa = await reel('Goa');
        final [a] = await clipsIn(goa, [1]);
        await sessions.startSession(goa, EditorApp.vn, 'Goa');
        await recordCopy(goa, a, 501, nameOf(1));
        editors.existing = {501};
        copy.emit(
          CopyJob(
            jobId: '$goa-9',
            reelId: goa,
            folderName: 'Goa',
            state: CopyState.finished,
            total: 1,
            done: 1,
            bytesDone: 1,
            bytesTotal: 1,
            copied: const [],
            failedClipIds: const [],
            undeleted: const [],
          ),
        );

        await service.beforeReelDelete(goa);

        expect(copy.calls, containsAllInOrder(['cancel', 'clear']));
        expect(copy.job, isNull);
        expect(await sessions.editState(goa), isNull);
      },
    );

    test('beforeReelDelete removes a plan left after a restart (no engine '
        'job), and the copies recovery recorded', () async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2]);
      await startVn(goa, ids);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
      ];
      editors.existing = {601};
      restart();
      await service.recoverAtStart();

      await service.beforeReelDelete(goa);

      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(editors.existing, isEmpty);
      expect(await sessions.editState(goa), isNull);
    });
  });

  group('Done editing before the recovery ran (fix round 2, I5)', () {
    /// A reel with a VN job of three clips that Android stopped: the folder
    /// holds the finished copy of clip 1, a half-written one of clip 2 and a
    /// finished file that is no plan item's.
    Future<(int, String)> stoppedMidCopy() async {
      final goa = await reel('Goa');
      final ids = await clipsIn(goa, [1, 2, 3]);
      final jobId = await startVn(goa, ids);
      copy.folders['Goa'] = [
        FolderRow(
          mediaStoreId: 601,
          fileName: nameOf(1),
          sizeBytes: 1001,
          pending: false,
        ),
        FolderRow(
          mediaStoreId: 602,
          fileName: nameOf(2),
          sizeBytes: 50,
          pending: true,
        ),
        const FolderRow(
          mediaStoreId: 699,
          fileName: 'other.mp4',
          sizeBytes: 77,
          pending: false,
        ),
      ];
      editors
        ..existing = {601, 699}
        ..files = [
          const CopyFolderFile(
            mediaStoreId: 699,
            folderName: 'Goa',
            fileName: 'other.mp4',
            sizeBytes: 77,
            ownedByTakeTray: true,
          ),
        ];
      restart();
      return (goa, jobId);
    }

    test('the finished copy of an item is recorded, then deleted and '
        'counted; the half-written row is swept; a file that is no item '
        'stays and is an orphan; the plan and the session go', () async {
      final (goa, jobId) = await stoppedMidCopy();

      final result = await service.doneEditing(goa);

      expect(result.freedBytes, 1001);
      expect(result.leftBehind, 0);
      expect(editors.deleteAsked.single, [
        CopyFileRef(mediaStoreId: 601, folderName: 'Goa', fileName: nameOf(1)),
      ]);
      expect(editors.existing, {699});
      expect(copy.folders['Goa']!.where((r) => r.pending), isEmpty);
      expect(await sessions.editState(goa), isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);
      expect(await service.jobContext(jobId), isNull);
      final overview = await service.storage();
      expect(overview.orphans.single.files.single.mediaStoreId, 699);
    });

    test(
      'a recovery that fails leaves the plan, the session and the files '
      'alone; Done editing throws, and works once the phone answers',
      () async {
        final (goa, _) = await stoppedMidCopy();
        copy.failNext('ownRowsIn');

        await expectLater(
          service.doneEditing(goa),
          throwsA(isA<PlatformException>()),
        );
        expect(await h.media.phoneState.copyJobPlan(), isNotNull);
        expect(await sessions.sessionOf(goa), isNotNull);
        expect(editors.existing, {601, 699});

        final result = await service.doneEditing(goa);
        expect(result.freedBytes, 1001);
        expect(editors.existing, {699});
      },
    );

    test('when the engine still holds the job there is no recovery: no '
        'deletePendingIn, the job is applied', () async {
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      await startVn(goa, [a]);
      editors.existing = {601};
      progress([copied(a, 601, nameOf(1))], state: CopyState.finished);

      final result = await service.doneEditing(goa);

      expect(result.freedBytes, 10);
      expect(copy.calls, isNot(contains('deletePendingIn')));
    });

    test("a plan of another reel is not recovered by this reel's Done "
        'editing', () async {
      final goa = await reel('Goa');
      final paris = await reel('Paris');
      final goaIds = await clipsIn(goa, [1]);
      await service.sendOriginals(goa, EditorApp.capcut, goaIds);
      final parisIds = await clipsIn(paris, [2]);
      await startVn(paris, parisIds);
      restart();

      await service.doneEditing(goa);

      expect(copy.calls, isNot(contains('deletePendingIn')));
      expect(await h.media.phoneState.copyJobPlan(), isNotNull);
    });
  });

  group('a job the engine will not clear yet (fix round 2, M12)', () {
    late _StubbornClear stubborn;

    setUp(() {
      stubborn = _StubbornClear();
      copy = stubborn;
      service = make();
    });

    test('Done editing keeps the plan and throws; the retry settles it and '
        'copying works again', () async {
      final goa = await reel('Goa');
      final [a, b] = await clipsIn(goa, [1, 2]);
      final jobId = await startVn(goa, [a]);
      progress(const [], state: CopyState.finished);
      stubborn.ignored = 1;

      await expectLater(service.doneEditing(goa), throwsStateError);
      expect((await h.media.phoneState.copyJobPlan())!.jobId, jobId);
      expect(copy.job, isNotNull);
      expect(await sessions.sessionOf(goa), isNotNull);

      await service.doneEditing(goa);
      expect(copy.job, isNull);
      expect(await h.media.phoneState.copyJobPlan(), isNull);

      final next = await service.planCopy(goa, EditorApp.vn, [b]);
      expect(next.startsSession, isTrue);
      await service.startCopy(next);
    });

    test(
      'finishJob keeps the plan and throws; a second try finishes',
      () async {
        final goa = await reel('Goa');
        final [a] = await clipsIn(goa, [1]);
        final jobId = await startVn(goa, [a]);
        progress(const [], state: CopyState.finished);
        stubborn.ignored = 1;

        await expectLater(service.finishJob(jobId), throwsStateError);
        expect(await h.media.phoneState.copyJobPlan(), isNotNull);

        await service.finishJob(jobId);
        expect(copy.job, isNull);
        expect(await h.media.phoneState.copyJobPlan(), isNull);
      },
    );

    test(
      'cancelCopy keeps the plan and throws; a second try cancels',
      () async {
        final goa = await reel('Goa');
        final [a] = await clipsIn(goa, [1]);
        final jobId = await startVn(goa, [a]);
        stubborn.ignored = 1;

        await expectLater(service.cancelCopy(jobId), throwsStateError);
        expect(await h.media.phoneState.copyJobPlan(), isNotNull);

        await service.cancelCopy(jobId);
        expect(copy.job, isNull);
        expect(await h.media.phoneState.copyJobPlan(), isNull);
      },
    );

    test('the job is announced as cleared only when it really was', () async {
      final ids = <String>[];
      final sub = service.clearedJobs.listen(ids.add);
      addTearDown(sub.cancel);
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      final jobId = await startVn(goa, [a]);
      progress(const [], state: CopyState.finished);
      stubborn.ignored = 1;

      await expectLater(service.finishJob(jobId), throwsStateError);
      await pumpEventQueue();
      expect(ids, isEmpty);

      await service.finishJob(jobId);
      await pumpEventQueue();
      expect(ids, [jobId]);
    });
  });

  group('clearedJobs (fix round 1)', () {
    test('finishJob, cancelCopy and a settling Done editing announce the '
        'job once; a cancel of an unknown id announces nothing', () async {
      final ids = <String>[];
      final sub = service.clearedJobs.listen(ids.add);
      addTearDown(sub.cancel);
      final goa = await reel('Goa');
      final [a] = await clipsIn(goa, [1]);
      final first = await startVn(goa, [a]);
      await service.cancelCopy('9-9');
      await pumpEventQueue();
      expect(ids, isEmpty);

      await service.cancelCopy(first);
      await pumpEventQueue();
      expect(ids, [first]);

      h.media.clock.advance(const Duration(seconds: 1));
      final second = await startVn(goa, [a]);
      progress(const [], state: CopyState.finished);
      await service.finishJob(second);
      await pumpEventQueue();
      expect(ids, [first, second]);

      h.media.clock.advance(const Duration(seconds: 1));
      final paris = await reel('Paris');
      final [b] = await clipsIn(paris, [2]);
      final third = await startVn(paris, [b]);
      progress(const [], state: CopyState.finished);
      await service.doneEditing(paris);
      await pumpEventQueue();
      expect(ids, [first, second, third]);
    });
  });

  test('logs ids and counts only: no reel, folder or file name', () async {
    final logs = captureLogs();
    final goa = await reel('Secret Goa');
    final [a, b] = await clipsIn(goa, [1, 2]);
    await service.sendOriginals(goa, EditorApp.capcut, [a]);
    final plan = await service.planCopy(goa, EditorApp.capcut, [b]);
    final jobId = await service.startCopy(plan);
    await service.applyJob(progress([copied(b, 602, nameOf(2))]));
    copy.folders['Secret Goa'] = [
      FolderRow(
        mediaStoreId: 602,
        fileName: nameOf(2),
        sizeBytes: 1,
        pending: false,
      ),
    ];
    restart();
    await service.recoverAtStart();
    await service.cancelCopy(jobId);
    editors.failNext('filesInCopyFolders');
    await service.storage();
    await service.doneEditing(goa);

    final text = logs.map((r) => '${r.message} ${r.error}').join('\n');
    expect(text, isNot(contains('Secret')));
    expect(text, isNot(contains('2026-10-28')));
    expect(text, isNot(contains('.mp4')));
  });
}
