import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/background/shade_actions.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../support/clip_setup.dart';
import '../../support/fake_background_bridge.dart';
import '../../support/fake_media_bridge.dart';
import '../../support/shots.dart';
import '../media/media_harness.dart';

// `BackgroundSync` (D-106): Dart keeps the native copy of the background state
// (D-103) in step with the database, and applies a shade action before it
// writes.

late MediaHarness h;
late FakeBackgroundBridge native;
late ShadeActions actions;
late BackgroundSync sync;
late EditSessionsRepository edits;
late ReelsRepository reels;

MediaVideo _video(int id, int generation) =>
    fakeVideo(id: id, generation: generation, sizeBytes: 1000000 + id);

BackgroundSync _newSync() {
  final made = BackgroundSync(
    native,
    h.phoneState,
    h.settings,
    h.clips,
    actions,
    edits,
  );
  addTearDown(made.dispose);
  return made;
}

int _writes() => native.calls.where((c) => c == 'writeState').length;

Future<void> _setMinutes(int minutes) async => await h.settings.save(
  (await h.settings.load()).copyWith(eveningReminderMinutes: minutes),
);

void main() {
  setUp(() {
    h = MediaHarness();
    native = h.background;
    actions = ShadeActions(h.scanner);
    edits = EditSessionsRepository(h.db, h.clock);
    reels = ReelsRepository(h.db, h.clock);
    sync = _newSync();
    h.bridge.put([_video(1, 10)]);
  });

  group('what is written', () {
    test('start rewrites the copy', () async {
      final session = await h.turnOnNow();
      await h.phoneState.markStillAnswered(session.since!);
      await h.settings.save(
        const AppSettings(
          watchedFolders: ['DCIM/Camera', 'Movies'],
          eveningReminderEnabled: false,
          eveningReminderMinutes: 1200,
        ),
      );
      final shot = DateTime.utc(2026, 5, 30, 8);
      await h.clips.saveDetected([mediaStoreShot(7, at: shot)]);

      sync.start();
      await settle();

      expect(native.writes, hasLength(1));
      expect(
        native.state,
        BackgroundState(
          shootingOn: true,
          since: session.since,
          baselines: {
            phone: const VolumeBaseline(version: 'v1', generation: 10),
          },
          watchedFolders: const ['DCIM/Camera', 'Movies'],
          waitingShots: [shot],
          eveningEnabled: false,
          eveningMinutes: 1200,
          stillReminderEnabled: true,
          stillAnswered: true,
        ),
      );

      // The next app start writes it again, even though it is the same: the
      // phone may have lost its alarms and job (re-arm at app start).
      sync.dispose();
      _newSync().start();
      await settle();
      expect(native.writes, hasLength(2));
      expect(native.writes.last, native.writes.first);
    });

    test('off is written with no session and no baselines', () async {
      sync.start();
      await settle();

      final state = native.state!;
      expect(state.shootingOn, isFalse);
      expect(state.since, isNull);
      expect(state.baselines, isEmpty);
      expect(state.stillAnswered, isFalse);
      expect(state.stillReminderEnabled, isTrue);
      expect(state.watchedFolders, const AppSettings().watchedFolders);
    });

    test('copy follows a baseline move', () async {
      final session = await h.turnOnNow();
      sync.start();
      await settle();

      await h.phoneState.advanceBaseline(
        phone,
        expectedSession: session,
        expected: session.baselines[phone],
        next: const VolumeBaseline(version: 'v1', generation: 14),
      );
      await settle();

      expect(native.state!.baselines[phone]!.generation, 14);
      expect(native.writes, hasLength(2));
    });

    test('copy follows Shooting mode going on and off', () async {
      sync.start();
      await settle();
      final session = await h.turnOnNow();
      await settle();
      expect(native.state!.shootingOn, isTrue);
      expect(native.state!.since, session.since);

      await h.phoneState.turnShootingOff();
      await settle();
      expect(native.state!.shootingOn, isFalse);
      expect(native.state!.since, isNull);
    });

    test('copy follows settings and tagging', () async {
      sync.start();
      await settle();

      await _setMinutes(1300);
      await settle();
      expect(native.state!.eveningMinutes, 1300);

      final a = DateTime.utc(2026, 5, 30, 8);
      final b = DateTime.utc(2026, 5, 29, 8);
      final [first, _] = await h.clips.saveDetected([
        mediaStoreShot(7, at: a),
        mediaStoreShot(8, at: b),
      ]);
      await settle();
      expect(native.state!.waitingShots, [b, a]);

      await h.clips.skipClips([first]);
      await settle();
      expect(native.state!.waitingShots, [b]);
    });

    test('same state is not written twice', () async {
      sync.start();
      await settle();
      expect(_writes(), 1);

      // A save that changes nothing, a write to a key the copy does not
      // hold, and a flush with nothing new: no second write.
      await h.settings.save(await h.settings.load());
      await h.phoneState.markAccessWasFull();
      await h.phoneState.recordVolumeVersion(phone, 'v1');
      await settle();
      await sync.flush();

      expect(_writes(), 1);
    });

    test('logs no folder, version or time', () async {
      final records = captureLogs();
      await h.turnOnNow();
      native.failNext('writeState');
      sync.start();
      await settle();
      await _setMinutes(1300);
      await settle();

      final text = logText(records);
      expect(text, contains('PlatformException'));
      expect(text, isNot(contains('DCIM')));
      expect(text, isNot(contains('v1')));
      expect(text, isNot(contains('2026')));
      expect(text, isNot(contains('failed on purpose')));
    });
  });

  group('one write at a time', () {
    test('writes are serialised, last wins', () async {
      final gate = native.gate('writeState');
      sync.start();
      await until(() => _writes() == 1);

      // Three changes while the first write is held.
      for (final minutes in [1000, 1001, 1002]) {
        await _setMinutes(minutes);
      }
      await settle();
      expect(_writes(), 1, reason: 'nothing beside the held write');

      gate.complete();
      await settle();

      // Only the newest waiting state is written after it.
      expect(_writes(), 2);
      expect(native.writes.last.eveningMinutes, 1002);
    });

    test('a failed write is retried on the next change', () async {
      sync.start();
      await settle();
      native.failNext('writeState');

      await _setMinutes(1300);
      await settle();
      expect(native.writes, hasLength(1), reason: 'the write of 1300 failed');

      await h.clips.saveDetected([
        mediaStoreShot(7, at: DateTime.utc(2026, 5, 30, 8)),
      ]);
      await settle();

      expect(native.writes, hasLength(2));
      expect(native.state!.eveningMinutes, 1300);
      expect(native.state!.waitingShots, hasLength(1));
    });

    test('after a failed write the next state is written, even the one '
        'before it', () async {
      sync.start();
      await settle();
      final first = native.state!;

      // The phone may have kept the failed state, or part of it.
      native.failNext('writeState');
      await _setMinutes(1300);
      await settle();
      await _setMinutes(first.eveningMinutes);
      await settle();

      expect(native.writes, [first, first]);
    });

    test('dispose stops following the database', () async {
      sync.start();
      await settle();
      sync.dispose();

      await _setMinutes(1300);
      await settle();

      expect(_writes(), 1);
    });

    test('start twice follows once', () async {
      sync
        ..start()
        ..start();
      await settle();
      await _setMinutes(1300);
      await settle();

      expect(_writes(), 2);
    });
  });

  group('flush', () {
    test(
      'a flush writes a change the streams have not delivered yet',
      () async {
        final session = await h.turnOnNow();
        sync.start();
        await settle();

        await h.phoneState.advanceBaseline(
          phone,
          expectedSession: session,
          expected: session.baselines[phone],
          next: const VolumeBaseline(version: 'v1', generation: 14),
        );
        await sync.flush();

        expect(native.state!.baselines[phone]!.generation, 14);
      },
    );

    test('a flush with nothing pending completes without a write', () async {
      sync.start();
      await settle();

      await sync.flush();

      expect(_writes(), 1);
    });

    test('a flush before start writes the database state', () async {
      await h.turnOnNow();

      await sync.flush();

      expect(native.state!.shootingOn, isTrue);
    });

    test('a flush while a write is failing completes and logs', () async {
      sync.start();
      await settle();
      final records = captureLogs();
      for (var i = 0; i < 5; i++) {
        native.failNext('writeState');
      }

      await _setMinutes(1300);
      await sync.flush();

      expect(native.writes, hasLength(1), reason: 'only the start write');
      expect(logText(records), contains('PlatformException'));

      // Every flush tries again: once the phone answers, it has the state.
      for (var i = 0; i < 5; i++) {
        await sync.flush();
      }
      expect(native.state!.eveningMinutes, 1300);
    });

    test('a flush racing a newer change writes the newest state', () async {
      final session = await h.turnOnNow();
      final gate = native.gate('writeState');
      sync.start();
      await until(() => _writes() == 1);

      // The held write read the database before these.
      await h.phoneState.advanceBaseline(
        phone,
        expectedSession: session,
        expected: session.baselines[phone],
        next: const VolumeBaseline(version: 'v1', generation: 14),
      );
      final flushed = sync.flush();
      await _setMinutes(1300);
      var done = false;
      flushed.whenComplete(() => done = true).ignore();
      await settle();
      expect(done, isFalse, reason: 'the flush waits for the held write');

      gate.complete();
      await flushed;

      expect(native.state!.baselines[phone]!.generation, 14);
      await settle();
      expect(native.state!.eveningMinutes, 1300);
    });
  });

  group('a shade action first', () {
    late ShootingState session;

    setUp(() async {
      session = await h.turnOnNow();
      // 11 shot before the tap (generation 11 then), 12 after it.
      h.bridge.put([_video(11, 11), _video(12, 12)]);
    });

    ShadeAction turnOff({DateTime? forSession}) => ShadeAction(
      kind: ShadeActionKind.turnOff,
      since: forSession ?? session.since!,
      at: DateTime.utc(2026, 6, 1, 18),
      generations: {phone: 11},
    );

    /// What the shade's receiver writes on Turn off: the copy, off.
    void tapTurnOff({DateTime? forSession}) {
      native.shadeAction = turnOff(forSession: forSession);
      native.state = native.state?.copyWith(shootingOn: false, since: null);
    }

    test('a shade turn off while the app is open is applied before the next '
        'write', () async {
      sync.start();
      await settle();
      final before = native.writes.length;
      tapTurnOff();

      // Any change in the app: a write is due.
      await _setMinutes(1300);
      await settle();

      final after = native.writes.sublist(before);
      expect(after, isNotEmpty);
      expect(after.where((s) => s.shootingOn), isEmpty);
      expect(native.state!.shootingOn, isFalse);
      expect(native.state!.eveningMinutes, 1300);
      expect(native.shadeAction, isNull);
      expect([for (final c in await h.toTag()) c.mediaStoreId], [11]);
      expect(await h.phoneState.loadShooting(), ShootingState.off);
    });

    test(
      'an action pending at start is applied before the first write',
      () async {
        tapTurnOff();

        sync.start();
        await settle();

        expect(native.writes.where((s) => s.shootingOn), isEmpty);
        expect(native.state!.shootingOn, isFalse);
        expect(native.shadeAction, isNull);
      },
    );

    test('an action for another session is cleared and the copy is '
        'written', () async {
      tapTurnOff(forSession: session.since!.subtract(const Duration(days: 1)));

      sync.start();
      await settle();

      expect(native.shadeAction, isNull);
      expect(native.state!.shootingOn, isTrue);
      expect(native.state!.since, session.since);
      expect(await h.allClips(), isEmpty);
    });

    test('an action that arrives during a write is applied before the next '
        'write', () async {
      final gate = native.gate('writeState');
      sync.start();
      await until(() => _writes() == 1);

      tapTurnOff();
      await _setMinutes(1300);
      gate.complete();
      await settle();

      expect(native.writes.last.shootingOn, isFalse);
      expect(native.writes.last.eveningMinutes, 1300);
      expect(native.shadeAction, isNull);
    });

    test('two writes queued behind the apply become one', () async {
      tapTurnOff();
      final gate = h.bridge.gate('videosAddedAfter');
      sync.start();
      await until(() => h.bridge.count('videosAddedAfter') == 1);

      await _setMinutes(1300);
      await _setMinutes(1301);
      await settle();
      expect(native.writes, isEmpty, reason: 'the apply comes first');

      gate.complete();
      await settle();

      expect(native.writes, hasLength(1));
      expect(native.state!.shootingOn, isFalse);
      expect(native.state!.eveningMinutes, 1301);
    });

    test('a failing apply writes the copy off and is tried again on the '
        'next change', () async {
      sync.start();
      await settle();
      tapTurnOff();
      h.bridge.failNext('volumes');
      final records = captureLogs();

      await _setMinutes(1300);
      await settle();

      // The phone's "off" is not overwritten with the database's "on".
      expect(native.state!.shootingOn, isFalse);
      expect(native.writes.last.eveningMinutes, 1300);
      expect(native.shadeAction, isNotNull);
      expect((await h.phoneState.loadShooting()).on, isTrue);
      expect(logText(records), contains('PlatformException'));

      await _setMinutes(1301);
      await settle();

      expect(native.state!.shootingOn, isFalse);
      expect(native.shadeAction, isNull);
      expect([for (final c in await h.toTag()) c.mediaStoreId], [11]);
    });

    test('while a turn off is pending the native copy says off', () async {
      sync.start();
      await settle();
      expect(native.state!.shootingOn, isTrue);
      tapTurnOff();
      // The end fails on the volume: the session and the action are kept.
      h.bridge.failNext('videosAddedAfter');

      await _setMinutes(1300);
      await settle();

      expect((await h.phoneState.loadShooting()).on, isTrue);
      expect(native.shadeAction, isNotNull);
      final last = native.writes.last;
      expect(last.shootingOn, isFalse);
      expect(last.since, isNull);
      expect(last.baselines, isEmpty);
      expect(last.eveningMinutes, 1300);
      expect(
        native.writes.skipWhile((s) => s.eveningMinutes != 1300),
        everyElement(
          isA<BackgroundState>().having((s) => s.shootingOn, 'on', isFalse),
        ),
      );
    });

    test('applying an action does not loop', () async {
      tapTurnOff();

      sync.start();
      await settle();
      final calls = native.calls.length;
      await settle();
      await settle();

      expect(native.calls.length, calls, reason: 'quiet once applied');
      expect(_writes(), 1);
    });

    test('a keep on that cannot be cleared does not loop', () async {
      native
        ..shadeAction = ShadeAction(
          kind: ShadeActionKind.keepOn,
          since: session.since!,
          at: DateTime.utc(2026, 6, 1, 18),
          generations: const {},
        )
        ..failNext('clearShadeAction');

      sync.start();
      await settle();
      final calls = native.calls.length;
      await settle();
      await settle();

      expect(native.calls.length, calls);
      expect((await h.phoneState.loadShooting()).stillAnswered, isTrue);
    });
  });
  group('copies reminders (Phase 8, D-124)', () {
    EditCopy copy(
      int reelId,
      int clipId, {
      required DateTime at,
      int bytes = 1000,
    }) => EditCopy(
      reelId: reelId,
      clipId: clipId,
      copyMediaStoreId: 900 + clipId,
      fileName: 'copy$clipId.mp4',
      sizeBytes: bytes,
      copiedAt: at,
    );

    Future<int> reelWithSession(
      String name,
      EditorApp editor, {
      String? folder,
    }) async {
      final reel = await reels.create(name);
      await edits.startSession(reel.id, editor, folder ?? name);
      return reel.id;
    }

    List<CopiesReminder> reminders() => native.state!.copiesReminders;

    test('one per session with copies: the reel, its name now, the total size '
        'and the newest copy', () async {
      final wedding = await reelWithSession('Wedding', EditorApp.vn);
      final trip = await reelWithSession('Trip', EditorApp.vn);
      await edits.recordCopies([
        copy(wedding, 1, at: DateTime.utc(2026, 6, 1, 8), bytes: 1500),
        copy(wedding, 2, at: DateTime.utc(2026, 6, 1, 9, 30), bytes: 2500),
        copy(trip, 3, at: DateTime.utc(2026, 5, 30, 7), bytes: 700),
      ]);

      sync.start();
      await settle();

      expect(reminders(), [
        CopiesReminder(
          reelId: wedding,
          reelName: 'Wedding',
          copyBytes: 4000,
          lastCopiedAt: DateTime.utc(2026, 6, 1, 9, 30),
        ),
        CopiesReminder(
          reelId: trip,
          reelName: 'Trip',
          copyBytes: 700,
          lastCopiedAt: DateTime.utc(2026, 5, 30, 7),
        ),
      ]);
    });

    test('a session without copies has none, whatever its editor', () async {
      await reelWithSession('Capcut reel', EditorApp.capcut);
      await reelWithSession('Edits reel', EditorApp.edits);
      await reelWithSession('Vn reel', EditorApp.vn);

      sync.start();
      await settle();

      expect(reminders(), isEmpty);
    });

    test('CapCut and Edits sessions with copies have one too', () async {
      final capcut = await reelWithSession('Capcut reel', EditorApp.capcut);
      final instagram = await reelWithSession('Edits reel', EditorApp.edits);
      await edits.recordCopies([
        copy(capcut, 1, at: DateTime.utc(2026, 6, 1, 8)),
        copy(instagram, 2, at: DateTime.utc(2026, 6, 1, 9)),
      ]);

      sync.start();
      await settle();

      expect(reminders().map((r) => r.reelId), [capcut, instagram]);
    });

    test(
      'a reel with no session has none, and Shooting mode is not needed',
      () async {
        await reels.create('Plain');
        final reel = await reelWithSession('Edited', EditorApp.vn);
        await edits.recordCopies([
          copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
        ]);

        sync.start();
        await settle();

        expect(native.state!.shootingOn, isFalse);
        expect(reminders().map((r) => r.reelId), [reel]);
      },
    );

    test(
      'written again when copies are added, with the new time and size',
      () async {
        final reel = await reelWithSession('Wedding', EditorApp.vn);
        await edits.recordCopies([
          copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
        ]);
        sync.start();
        await settle();
        expect(reminders().single.copyBytes, 1000);

        await edits.recordCopies([
          copy(reel, 2, at: DateTime.utc(2026, 6, 3, 10), bytes: 5000),
        ]);
        await settle();

        expect(reminders().single.copyBytes, 6000);
        expect(reminders().single.lastCopiedAt, DateTime.utc(2026, 6, 3, 10));
        expect(_writes(), 2);
      },
    );

    test(
      'written again when copies are removed, and when the session ends',
      () async {
        final reel = await reelWithSession('Wedding', EditorApp.vn);
        await edits.recordCopies([
          copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
          copy(reel, 2, at: DateTime.utc(2026, 6, 1, 9), bytes: 3000),
        ]);
        sync.start();
        await settle();

        await edits.removeCopies(reel, [902]);
        await settle();
        expect(reminders().single.copyBytes, 1000);
        expect(reminders().single.lastCopiedAt, DateTime.utc(2026, 6, 1, 8));

        await edits.removeCopies(reel, [901]);
        await settle();
        expect(reminders(), isEmpty, reason: 'no copies left');

        await edits.recordCopies([
          copy(reel, 3, at: DateTime.utc(2026, 6, 4, 8)),
        ]);
        await settle();
        expect(reminders(), hasLength(1));

        await edits.endSession(reel);
        await settle();
        expect(reminders(), isEmpty, reason: 'the session ended');
      },
    );

    test(
      'written again when the reel is renamed, and when it is deleted',
      () async {
        final reel = await reelWithSession('Wedding', EditorApp.vn);
        await edits.recordCopies([
          copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
        ]);
        sync.start();
        await settle();
        expect(reminders().single.reelName, 'Wedding');

        await reels.rename(reel, 'Goa wedding');
        await settle();
        expect(reminders().single.reelName, 'Goa wedding');

        await reels.delete(reel);
        await settle();
        expect(reminders(), isEmpty);
      },
    );

    test('nothing that does not change a reminder writes again', () async {
      final reel = await reelWithSession('Wedding', EditorApp.vn);
      await edits.recordCopies([
        copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
      ]);
      sync.start();
      await settle();
      final writes = _writes();

      // A send to the editor and a copy recorded twice change no reminder.
      await edits.recordSent(reel, [1]);
      await edits.recordCopies([
        copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
      ]);
      await settle();

      expect(_writes(), writes);
    });

    test('the same state again is the same message: sorted by reel', () async {
      final a = await reelWithSession('A', EditorApp.vn);
      final b = await reelWithSession('B', EditorApp.vn);
      await edits.recordCopies([
        copy(b, 1, at: DateTime.utc(2026, 6, 1, 8)),
        copy(a, 2, at: DateTime.utc(2026, 6, 2, 8)),
      ]);
      sync.start();
      await settle();
      expect(reminders().map((r) => r.reelId), [a, b]);
    });

    test('flush writes them without waiting for the streams', () async {
      final reel = await reelWithSession('Wedding', EditorApp.vn);
      await edits.recordCopies([
        copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
      ]);

      await sync.flush();

      expect(reminders().single.reelId, reel);
    });

    test('a failed read is logged by type, writes nothing, and the next change '
        'tries again; no reel name is logged', () async {
      final reel = await reelWithSession('Zq Secret Reel', EditorApp.vn);
      await edits.recordCopies([
        copy(reel, 1, at: DateTime.utc(2026, 6, 1, 8)),
      ]);
      final records = captureLogs();
      sync.dispose();
      final failing = BackgroundSync(
        native,
        h.phoneState,
        h.settings,
        h.clips,
        actions,
        _FailingEdits(h.db, h.clock),
      );
      addTearDown(failing.dispose);

      await failing.flush();

      expect(native.writes, isEmpty);
      expect(logText(records), contains('StateError'));
      expect(logText(records), isNot(contains('Zq')));

      // The healthy one writes the same session, name and all.
      await _newSync().flush();
      expect(reminders().single.reelName, 'Zq Secret Reel');
      expect(logText(records), isNot(contains('Zq')));
    });
  });
}

class _FailingEdits extends EditSessionsRepository {
  // The base class's fields are private, so super parameters cannot be named.
  // ignore: use_super_parameters
  _FailingEdits(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Stream<List<EditSessionSummary>> watchSummaries() =>
      Stream.error(StateError('summaries unreadable'));

  @override
  Future<List<EditSessionSummary>> summaries() =>
      Future.error(StateError('summaries unreadable'));
}
