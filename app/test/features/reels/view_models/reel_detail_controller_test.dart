import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

import '../../../support/reel_videos.dart';
import '../../../support/spy_edit_session_service.dart';
import '../../../support/vm_harness.dart';
import '../edit_session_support.dart';

/// A verifier that only records what it was asked about.
class _RecordingVerifier implements MediaVerifier {
  final List<Set<int>> asked = [];

  @override
  Future<VerifyOutcome> verify(Iterable<Clip> clips) async {
    final ids = {for (final c in clips) c.id};
    asked.add(ids);
    return VerifyOutcome(found: ids, missing: const {}, skipped: const {});
  }

  @override
  Future<VerifyOutcome> verifyAll() => throw UnimplementedError();
}

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
  });

  /// Opens the page of reel [id] like the screen does and keeps it open.
  ProviderContainer open(int id, {List<Override> extra = const []}) =>
      ProviderContainer.test(overrides: [...h.overrides, ...extra])
        ..listen(reelDetailControllerProvider(id), (_, _) {});

  Future<ReelDetailState?> stateOf(ProviderContainer c, int id) =>
      c.read(reelDetailControllerProvider(id).future);

  group('opening a reel verifies its clips', () {
    test('opening a reel verifies its clips', () async {
      final goa = await reels.create('Goa');
      final other = await reels.create('London');
      final goaIds = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      await putInReel(h, other.id, [reelVideo(3)]);
      final verifier = _RecordingVerifier();
      final container = open(
        goa.id,
        extra: [mediaVerifierProvider.overrideWithValue(verifier)],
      );

      await stateOf(container, goa.id);
      await settle();

      // Once, for this reel's clips and no other.
      expect(verifier.asked, [goaIds.toSet()]);
    });

    test('a reel with no clips asks nothing', () async {
      final goa = await reels.create('Goa');
      final verifier = _RecordingVerifier();
      final container = open(
        goa.id,
        extra: [mediaVerifierProvider.overrideWithValue(verifier)],
      );

      await stateOf(container, goa.id);
      await settle();

      expect(verifier.asked, isEmpty);
    });

    test(
      'a change of the list or of the times does not verify again',
      () async {
        final goa = await reels.create('Goa');
        await putInReel(h, goa.id, [reelVideo(1)]);
        final verifier = _RecordingVerifier();
        final container = open(
          goa.id,
          extra: [mediaVerifierProvider.overrideWithValue(verifier)],
        );
        await stateOf(container, goa.id);
        await settle();

        await putInReel(h, goa.id, [reelVideo(2)]);
        await settle();
        await reels.setStatus(goa.id, (await reels.getById(goa.id))!.status);
        await settle();

        expect(verifier.asked, hasLength(1));
        expect(
          container.read(reelDetailControllerProvider(goa.id)).value!.clipCount,
          2,
          reason: 'the new clip is shown',
        );
      },
    );

    test('opening it again verifies again', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      final verifier = _RecordingVerifier();
      final overrides = [mediaVerifierProvider.overrideWithValue(verifier)];

      for (var i = 0; i < 2; i++) {
        final container = open(goa.id, extra: overrides);
        await stateOf(container, goa.id);
        await settle();
        container.dispose();
      }

      expect(verifier.asked, hasLength(2));
    });

    test('a video that is gone from the phone is shown as missing', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      await putInReel(h, goa.id, [reelVideo(2)], onPhone: false);
      final container = open(goa.id);

      await stateOf(container, goa.id);
      await settle();

      final state = container.read(reelDetailControllerProvider(goa.id)).value!;
      expect(state.clipCount, 2);
      expect(state.missingCount, 1);
      final byNumber = {
        for (final d in state.days)
          for (final c in d.clips) c.clip.mediaStoreId!: c.clip.missing,
      };
      expect(byNumber, {1: false, 2: true});
    });

    test('no verify without full access: nothing is missing, the phone is '
        'not asked', () async {
      final goa = await reels.create('Goa');
      // Neither video is on the phone, but a limited query could not say so.
      await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)], onPhone: false);
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );
      final container = open(goa.id);

      await stateOf(container, goa.id);
      await settle();

      final state = container.read(reelDetailControllerProvider(goa.id)).value!;
      expect(state.missingCount, 0);
      expect(h.bridge.count('videosByIds'), 0);
      expect(h.bridge.calls, contains('accessReport'));
    });

    test('an error while checking never means missing', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      h.bridge.failNext('videosByIds');
      final container = open(goa.id);

      await stateOf(container, goa.id);
      await settle();

      final state = container.read(reelDetailControllerProvider(goa.id)).value!;
      expect(state.missingCount, 0);
      expect(h.bridge.count('videosByIds'), 1, reason: 'it did try');
    });

    test('a verify that throws leaves the page as it is', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      final container = open(
        goa.id,
        extra: [mediaVerifierProvider.overrideWithValue(_ThrowingVerifier())],
      );

      final state = await stateOf(container, goa.id);
      await settle();

      expect(state!.clipCount, 1);
      expect(
        container.read(reelDetailControllerProvider(goa.id)).hasError,
        isFalse,
      );
    });
  });

  group('opening a reel checks its copies (R8)', () {
    test('a copy deleted outside TakeTray is forgotten', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final copies = await startEditing(h, goa.id, EditorApp.vn, copied: ids);
      // The second copy is gone from the folder.
      h.editors.existing = {copies[0]};
      final container = open(goa.id);

      await stateOf(container, goa.id);
      await settle();

      final state = await container
          .read(editSessionsRepositoryProvider)
          .editState(goa.id);
      expect([for (final c in state!.copies) c.clipId], [ids[0]]);
      expect(h.editors.calls.where((c) => c == 'existingCopies'), hasLength(1));
    });

    test('once per open, not again when the clips change', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      await startEditing(h, goa.id, EditorApp.vn, copied: ids);
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      await putInReel(h, goa.id, [reelVideo(2)]);
      await settle();

      expect(h.editors.calls.where((c) => c == 'existingCopies'), hasLength(1));
      container.dispose();

      final again = open(goa.id);
      await stateOf(again, goa.id);
      await settle();
      expect(h.editors.calls.where((c) => c == 'existingCopies'), hasLength(2));
    });

    test('a reel with no session asks the phone nothing', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      final container = open(goa.id);

      await stateOf(container, goa.id);
      await settle();

      expect(h.editors.calls, isEmpty);
    });

    test('a check that fails leaves the page and the copies as they are, '
        'and logs the error type only', () async {
      final goa = await reels.create('Goa Secret Trip');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      await startEditing(
        h,
        goa.id,
        EditorApp.vn,
        copied: ids,
        folder: 'Goa Secret Trip',
      );
      h.editors.failNext('existingCopies');
      final logs = captureLogs();
      final container = open(goa.id);

      final state = await stateOf(container, goa.id);
      await settle();

      expect(state!.clipCount, 1);
      expect(
        container.read(reelDetailControllerProvider(goa.id)).hasError,
        isFalse,
      );
      final edit = await container
          .read(editSessionsRepositoryProvider)
          .editState(goa.id);
      expect(edit!.copies, hasLength(1));
      final text = logText(logs);
      expect(text, contains('PlatformException'));
      expect(text, isNot(contains('Goa Secret Trip')));
    });
  });

  group('the state', () {
    test('days grouped with Day numbers and counts', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [
        reelVideo(1, shot: DateTime.utc(2026, 10, 25, 9)),
        reelVideo(2, shot: DateTime.utc(2026, 10, 25, 10)),
        // Two empty days between: Day 1 and Day 4, not Day 2.
        reelVideo(3, shot: DateTime.utc(2026, 10, 28, 9)),
      ]);
      final container = open(goa.id);

      final state = (await stateOf(container, goa.id))!;

      expect(state.days.map((d) => d.number), [1, 4]);
      expect(state.days.map((d) => d.clips.length), [2, 1]);
      expect(state.days.map((d) => d.date), [
        DateTime.utc(2026, 10, 25),
        DateTime.utc(2026, 10, 28),
      ]);
      expect(state.clipCount, 3);
      expect(state.reel.name, 'Goa');
    });

    test('the length counts only the clips that are on the phone', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [
        reelVideo(1, durationMs: 32000),
        reelVideo(2, durationMs: 33000),
      ]);
      await putInReel(h, goa.id, [
        reelVideo(3, durationMs: 90000),
      ], onPhone: false);
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final state = container.read(reelDetailControllerProvider(goa.id)).value!;

      expect(state.clipCount, 3);
      expect(state.missingCount, 1);
      expect(state.liveDurationMs, 65000);
    });

    test('an empty reel has no days', () async {
      final goa = await reels.create('Goa');
      final container = open(goa.id);

      final state = (await stateOf(container, goa.id))!;

      expect(state.days, isEmpty);
      expect(state.clipCount, 0);
      expect(state.missingCount, 0);
      expect(state.liveDurationMs, 0);
    });

    test('the day is the day where the clip was shot', () async {
      final goa = await reels.create('Goa');
      // 23:30 UTC on 1 July is 00:30 on 2 July in London (BST), and still
      // 1 July where the phone is (UTC).
      await putInReel(h, goa.id, [
        reelVideo(1, shot: DateTime.utc(2026, 7, 1, 23, 30)),
      ], zoneId: 'Europe/London');
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final state = container.read(reelDetailControllerProvider(goa.id)).value!;

      expect(state.days.single.date, DateTime.utc(2026, 7, 2));
      final time = state.times.values.single;
      expect(time.wallClock, DateTime.utc(2026, 7, 2, 0, 30));
      expect(time.isPhoneZone, isFalse);
    });

    test('the clips show at once, grouped in the phone zone, and regroup '
        'when the times arrive', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [
        reelVideo(1, shot: DateTime.utc(2026, 7, 1, 23, 30)),
      ], zoneId: 'Europe/London');
      final held = h.bridge.gate('zoneOffsetsMs');
      final container = open(goa.id);

      final first = (await stateOf(container, goa.id))!;

      // The times are still being read: the clip is there, on the day it has
      // in the phone's own zone (Dart's local time), and has no time yet.
      final local = DateTime.utc(2026, 7, 1, 23, 30).toLocal();
      expect(first.days.single.clips, hasLength(1));
      expect(
        first.days.single.date,
        DateTime.utc(local.year, local.month, local.day),
      );
      expect(first.times, isEmpty);

      held.complete();
      await settle();

      final then = container.read(reelDetailControllerProvider(goa.id)).value!;
      expect(then.days.single.date, DateTime.utc(2026, 7, 2));
      expect(then.times, hasLength(1));
    });

    test(
      'times that cannot be read leave the clips on the phone zone',
      () async {
        final goa = await reels.create('Goa');
        await putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 23, 30)),
        ], zoneId: 'Europe/London');
        h.bridge
          ..failNext('zoneOffsetsMs')
          ..failNext('currentZoneId');
        final container = open(goa.id);

        final state = (await stateOf(container, goa.id))!;
        await settle();

        expect(state.clipCount, 1);
        expect(
          container.read(reelDetailControllerProvider(goa.id)).hasError,
          isFalse,
        );
      },
    );

    test('the in-N-reels count comes with each clip', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      await clips.addClipsToReel(london.id, [ids.first]);
      final container = open(goa.id);

      final state = (await stateOf(container, goa.id))!;

      final counts = {
        for (final c in state.days.single.clips) c.clip.id: c.reelCount,
      };
      expect(counts, {ids[0]: 2, ids[1]: 1});
    });
  });

  group('a reel that is gone', () {
    test('an id with no reel gives null', () async {
      final container = open(999);

      expect(await stateOf(container, 999), isNull);
    });

    test('a reel deleted while open becomes null', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      final container = open(goa.id);
      expect(await stateOf(container, goa.id), isNotNull);

      await reels.delete(goa.id);
      await settle();

      final now = container.read(reelDetailControllerProvider(goa.id));
      expect(now.hasValue, isTrue);
      expect(now.value, isNull);
    });

    test('a rename and a status change show', () async {
      final goa = await reels.create('Goa');
      final container = open(goa.id);
      await stateOf(container, goa.id);

      await reels.rename(goa.id, 'Goa trip');
      await settle();

      expect(
        container.read(reelDetailControllerProvider(goa.id)).value!.reel.name,
        'Goa trip',
      );
    });
  });

  group('removeMissing', () {
    test('removes the link and returns what Undo needs', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final removal = await container
          .read(reelDetailControllerProvider(goa.id).notifier)
          .removeMissing(ids.single);
      await settle();
      final record = removal.record;

      expect(removal.copiesDeleted, 0, reason: 'no session, no copy');
      expect(record.isEmpty, isFalse);
      expect(record.reelId, goa.id);
      expect(record.removedLinks.single.clipId, ids.single);
      // A reel with no editing session touches no bridge (D-123).
      expect(h.editors.calls, isEmpty);
      expect(h.copy.calls, isEmpty);
      expect(
        container.read(reelDetailControllerProvider(goa.id)).value!.clipCount,
        0,
      );

      await reels.undo(record);
      await settle();
      final back = container.read(reelDetailControllerProvider(goa.id)).value!;
      expect(back.clipCount, 1);
      expect(back.days.single.clips.single.clip.id, ids.single);
      expect(back.missingCount, 1, reason: 'the same clip, still missing');
    });

    test('a clip that is on the phone is not removed', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final removal = await container
          .read(reelDetailControllerProvider(goa.id).notifier)
          .removeMissing(ids.single);

      expect(removal.record.isEmpty, isTrue);
      expect(removal.copiesDeleted, 0);
      expect(
        container.read(reelDetailControllerProvider(goa.id)).value!.clipCount,
        1,
      );
    });

    test('a clip that is not in the reel is not removed', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      final other = await putInReel(h, london.id, [
        reelVideo(2),
      ], onPhone: false);
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final removal = await container
          .read(reelDetailControllerProvider(goa.id).notifier)
          .removeMissing(other.single);

      expect(removal.record.isEmpty, isTrue);
      expect(removal.copiesDeleted, 0);
      expect(
        (await clips.watchReelClips(london.id).first).map((c) => c.clip.id),
        other,
      );
    });

    test('two taps at once remove once and share the record', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();
      final notifier = container.read(
        reelDetailControllerProvider(goa.id).notifier,
      );

      final first = notifier.removeMissing(ids.single);
      final second = notifier.removeMissing(ids.single);

      expect(identical(first, second), isTrue);
      expect((await first).record.removedLinks, hasLength(1));
      expect((await second).record.removedLinks, hasLength(1));
    });

    test('a failure is thrown, and a retry works', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      final container = open(
        goa.id,
        extra: [clipsRepositoryProvider.overrideWithValue(_FailingOnce(h))],
      );
      await stateOf(container, goa.id);
      await settle();
      final notifier = container.read(
        reelDetailControllerProvider(goa.id).notifier,
      );

      await expectLater(notifier.removeMissing(ids.single), throwsStateError);
      final record = (await notifier.removeMissing(ids.single)).record;

      expect(record.removedLinks, hasLength(1));
    });

    test("deletes the clip's copy first (R8); when that fails nothing is "
        'removed (p8-task6)', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      final spy = SpyEditSessionService(h)
        ..failLeave = const CopiesNotDeleted(1);
      final container = open(
        goa.id,
        extra: [editSessionServiceProvider.overrideWithValue(spy)],
      );
      await stateOf(container, goa.id);
      await settle();
      final notifier = container.read(
        reelDetailControllerProvider(goa.id).notifier,
      );

      await expectLater(
        notifier.removeMissing(ids.single),
        throwsA(isA<CopiesNotDeleted>()),
      );
      expect(spy.calls, ['leave ${goa.id} ${ids.single}']);
      expect(await clips.clipIdsOfReel(goa.id), {ids.single});

      spy.failLeave = null;
      final record = (await notifier.removeMissing(ids.single)).record;
      expect(spy.calls, hasLength(2));
      expect(spy.reelClipsAtLeave.last, {ids.single});
      expect(record.removedLinks, hasLength(1));
    });

    test('a clip that is not removed asks for no clean-up', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final spy = SpyEditSessionService(h);
      final container = open(
        goa.id,
        extra: [editSessionServiceProvider.overrideWithValue(spy)],
      );
      await stateOf(container, goa.id);
      await settle();

      await container
          .read(reelDetailControllerProvider(goa.id).notifier)
          .removeMissing(ids.single);

      expect(spy.calls, isEmpty);
    });

    test("during a session the clip's copy is deleted and counted "
        '(p8-task11-fix)', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
      ], onPhone: false);
      final copies = await startEditing(
        h,
        goa.id,
        EditorApp.vn,
        copied: [ids[0], ids[1]],
      );
      h.editors.allow({'deleteCopies'});
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final removal = await container
          .read(reelDetailControllerProvider(goa.id).notifier)
          .removeMissing(ids[0]);

      expect(removal.copiesDeleted, 1, reason: 'only its own copy');
      expect(removal.record.removedLinks.single.clipId, ids[0]);
      expect(h.editors.existing, {copies[1]});
    });

    test('a session where the clip has no copy counts none '
        '(p8-task11-fix)', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
      ], onPhone: false);
      await startEditing(h, goa.id, EditorApp.vn, copied: [ids[1]]);
      h.editors.allow({'deleteCopies'});
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();

      final removal = await container
          .read(reelDetailControllerProvider(goa.id).notifier)
          .removeMissing(ids[0]);

      expect(removal.copiesDeleted, 0);
      expect(removal.record.isEmpty, isFalse);
    });

    test('two taps at once share one count (p8-task11-fix)', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      await startEditing(h, goa.id, EditorApp.vn, copied: [ids.single]);
      h.editors.allow({'deleteCopies'});
      final container = open(goa.id);
      await stateOf(container, goa.id);
      await settle();
      final notifier = container.read(
        reelDetailControllerProvider(goa.id).notifier,
      );

      final first = notifier.removeMissing(ids.single);
      final second = notifier.removeMissing(ids.single);

      expect((await first).copiesDeleted, 1);
      expect((await second).copiesDeleted, 1);
    });
  });
}

class _ThrowingVerifier implements MediaVerifier {
  @override
  Future<VerifyOutcome> verify(Iterable<Clip> clips) =>
      Future.error(StateError('the check failed'));

  @override
  Future<VerifyOutcome> verifyAll() => throw UnimplementedError();
}

/// A clips repository whose first `removeClipsFromReel` throws.
class _FailingOnce extends ClipsRepository {
  _FailingOnce(VmHarness h) : super(h.media.db, h.media.clock);

  bool _failed = false;

  @override
  Future<RemoveUndo> removeClipsFromReel(int reelId, Iterable<int> clipIds) {
    if (!_failed) {
      _failed = true;
      throw StateError('the write failed');
    }
    return super.removeClipsFromReel(reelId, clipIds);
  }
}
