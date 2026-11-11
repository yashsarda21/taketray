import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/media/picked_grants.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/clip_setup.dart';
import '../../support/fake_media_bridge.dart';
import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';
import 'media_harness.dart';

const String _a =
    'content://media/picker/0/com.android.providers.media.photopicker/media/1';
const String _b =
    'content://media/picker/0/com.android.providers.media.photopicker/media/2';
const String _c =
    'content://media/picker/0/com.android.providers.media.photopicker/media/3';
const String _d =
    'content://media/picker/0/com.android.providers.media.photopicker/media/4';
const String _e =
    'content://com.android.providers.media.documents/document/video%3A5';

NewClip _picked(String uri) => NewClip.picker(
  pickerUri: uri,
  fingerprint: ClipFingerprint(
    sizeBytes: 2000,
    durationMs: 8000,
    dateTakenUtc: DateTime.utc(2026, 5, 1, 9),
    displayName: 'picked.mp4',
  ),
  width: 0,
  height: 0,
  mimeType: 'video/mp4',
);

PickedVideo _pick(String uri, {bool persisted = true}) => PickedVideo(
  uri: uri,
  sizeBytes: 2000,
  displayName: 'picked.mp4',
  persisted: persisted,
  durationMs: 8000,
  dateTakenMs: DateTime.utc(2026, 5, 1, 9).millisecondsSinceEpoch,
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
);

/// A bridge whose `persistedUris` throws something that is not a
/// `PlatformException`.
class _BrokenSaved extends RecordingBridge {
  @override
  Future<List<String>> persistedUris() async {
    calls.add('persistedUris');
    throw StateError('broken');
  }
}

/// A second database next to the harness's, on purpose: silences drift's
/// warning for the test, and puts it back after.
void allowSecondDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  addTearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
}

void main() {
  late MediaHarness h;
  late PickedGrants grants;
  late ReelsRepository reels;

  setUp(() {
    h = MediaHarness();
    grants = PickedGrants(h.bridge, h.db, h.queue);
    reels = ReelsRepository(h.db, h.clock);
  });

  var reelCount = 0;

  /// Picked clips at [uris] in a new reel; returns their ids.
  Future<List<int>> inReel(List<String> uris) async {
    final reel = await reels.create('Reel ${++reelCount}');
    return await h.clips.addNewClipsToReel(reel.id, [
      for (final u in uris) _picked(u),
    ]);
  }

  group('sweep', () {
    test('releases only the saved grants that no clip row holds', () async {
      // A in a reel, B in To tag, C a missing picked clip in a reel.
      final ids = await inReel([_a, _c]);
      await h.clips.saveDetected([_picked(_b)]);
      await flagClips(h.db, {ids[1]}, missing: true, at: h.clock.now());
      h.bridge.persisted = {_a, _b, _c, _d, _e};

      final released = await grants.sweep();

      expect(released, 2);
      expect(h.bridge.released, [
        unorderedEquals([_d, _e]),
      ]);
      expect(h.bridge.persisted, {_a, _b, _c});
    });

    test('a grant held by a skipped clip is kept', () async {
      final ids = await h.clips.saveDetected([_picked(_a)]);
      await h.clips.skipClips(ids);
      h.bridge.persisted = {_a};

      expect(await grants.sweep(), 0);
      expect(h.bridge.released, isEmpty);
    });

    test('nothing unused: releaseUris is not called', () async {
      await inReel([_a, _b]);
      h.bridge.persisted = {_a, _b};

      expect(await grants.sweep(), 0);
      expect(h.bridge.calls, isNot(contains('releaseUris')));
      expect(h.bridge.persisted, {_a, _b});
    });

    test('no saved grants: nothing to release', () async {
      await inReel([_a]);

      expect(await grants.sweep(), 0);
      expect(h.bridge.calls, isNot(contains('releaseUris')));
    });

    test('no clip rows: every saved grant is released', () async {
      h.bridge.persisted = {_a, _b};

      expect(await grants.sweep(), 2);
      expect(h.bridge.persisted, isEmpty);
    });

    test('MediaStore clips never count as holding a grant', () async {
      await h.store([fakeVideo(id: 1)]);
      h.bridge.persisted = {_a};

      expect(await grants.sweep(), 1);
    });

    test('an address held in an equivalent spelling is kept', () async {
      // The row as Android gave it at the pick; the saved grant written with
      // another case of the host and of a percent escape.
      await inReel([_e]);
      h.bridge.persisted = {
        'content://COM.android.providers.media.documents/document/video%3a5',
      };

      expect(await grants.sweep(), 0);
      expect(h.bridge.released, isEmpty);
    });

    test('a grant listed twice is released once', () async {
      final bridge = _TwiceSaved()..persisted = {_d};
      final twice = PickedGrants(bridge, h.db, h.queue);

      expect(await twice.sweep(), 1);
      expect(bridge.released, [
        [_d],
      ]);
    });

    test('a failed persistedUris throws and releases nothing', () async {
      await inReel([_a]);
      h.bridge
        ..persisted = {_a, _d}
        ..failNext('persistedUris');

      await expectLater(grants.sweep(), throwsA(isA<PlatformException>()));
      expect(h.bridge.calls, isNot(contains('releaseUris')));
      expect(h.bridge.persisted, {_a, _d});
    });

    test('any other throw from persistedUris releases nothing', () async {
      final bridge = _BrokenSaved()..persisted = {_d};
      final broken = PickedGrants(bridge, h.db, h.queue);

      await expectLater(broken.sweep(), throwsA(isA<StateError>()));
      expect(bridge.released, isEmpty);
    });

    test('a failed database read throws and releases nothing', () async {
      allowSecondDatabase();
      final db = testDatabase();
      final clips = ClipsRepository(db, h.clock);
      final reel = await ReelsRepository(db, h.clock).create('Goa');
      await clips.addNewClipsToReel(reel.id, [_picked(_a)]);
      final bridge = FakeMediaBridge()..persisted = {_a, _d};
      final closed = PickedGrants(bridge, db, MediaWorkQueue());
      await db.close();

      await expectLater(closed.sweep(), throwsA(anything));
      expect(bridge.calls, isNot(contains('releaseUris')));
      expect(bridge.persisted, {_a, _d});
    });

    test('a failed releaseUris is thrown, not swallowed', () async {
      h.bridge
        ..persisted = {_d}
        ..failNext('releaseUris');

      await expectLater(grants.sweep(), throwsA(isA<PlatformException>()));
    });

    test('a releaseUris that never returns times out, ends the sweep and '
        'does not hold the media queue', () async {
      h.bridge.persisted = {_d};
      h.bridge.gate('releaseUris'); // never completed
      final short = PickedGrants(
        h.bridge,
        h.db,
        h.queue,
        bridgeTimeout: const Duration(milliseconds: 30),
      );
      var ran = false;

      final sweeping = short.sweep();
      final after = h.queue.run(() async => ran = true);

      await expectLater(sweeping, throwsA(isA<TimeoutException>()));
      await after;
      expect(ran, isTrue, reason: 'the job behind the sweep ran');
      expect(h.bridge.count('releaseUris'), 1, reason: 'it was asked');
    });

    test(
      'after a pick and an add it keeps every address the new rows hold',
      () async {
        h.bridge.picked = [_pick(_a), _pick(_b), _pick(_c)];
        final picked = await h.bridge.pickVideos();
        // The add stores two of them (one to To tag, one to a reel); the third
        // was picked but never stored.
        await h.clips.saveDetected([_picked(picked[0].uri)]);
        await inReel([picked[1].uri]);

        expect(await grants.sweep(), 1);
        expect(h.bridge.persisted, {_a, _b});
        expect(h.bridge.released, [
          [_c],
        ]);
      },
    );

    test('after a backup import it keeps every address the imported rows '
        'hold, and releases the ones only the replaced rows held', () async {
      allowSecondDatabase();
      // The backup: picked clips A and B in a reel.
      final source = testDatabase();
      addTearDown(source.close);
      final clock = FixedClock(DateTime.utc(2026, 6));
      final sourceReel = await ReelsRepository(source, clock).create('Goa');
      await ClipsRepository(
        source,
        clock,
      ).addNewClipsToReel(sourceReel.id, [_picked(_a), _picked(_b)]);
      final json = await BackupService(source, clock).exportJson();
      // This phone held C before the import.
      await inReel([_c]);
      h.bridge.persisted = {_a, _b, _c};

      await BackupService(h.db, h.clock).importJson(json);
      final released = await grants.sweep();

      expect(released, 1);
      expect(h.bridge.persisted, {_a, _b});
    });

    test('runs on the media queue: a job queued before it finishes first, '
        'and its rows are seen', () async {
      final hold = Completer<void>();
      h.bridge.persisted = {_a, _d};
      final job = h.queue.run(() async {
        await hold.future;
        await inReel([_a]);
      });

      final sweeping = grants.sweep();
      await Future<void>.delayed(Duration.zero);
      expect(
        h.bridge.calls,
        isNot(contains('persistedUris')),
        reason: 'waits for the queue',
      );
      hold.complete();
      await job;

      expect(await sweeping, 1);
      expect(h.bridge.persisted, {_a});
    });

    test('a job queued after it waits until it is done', () async {
      h.bridge.persisted = {_d};
      final gate = h.bridge.gate('persistedUris');
      var ran = false;

      final sweeping = grants.sweep();
      final after = h.queue.run(() async => ran = true);
      await Future<void>.delayed(Duration.zero);
      expect(ran, isFalse);
      gate.complete();
      await sweeping;
      await after;

      expect(ran, isTrue);
    });

    test('logs counts only, never an address', () async {
      final logs = captureLogs();
      await inReel([_a]);
      h.bridge.persisted = {_a, _d, _e};

      await grants.sweep();

      final text = logText(logs);
      expect(text, contains('2'));
      expect(text, isNot(contains('content')));
      expect(text, isNot(contains('picker')));
      expect(text, isNot(contains('document')));
      expect(text, isNot(contains('/')));
    });
  });

  test('pickedGrantsProvider builds one sweeper, kept alive, on the shared '
      'queue', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final bridge = FakeMediaBridge()..persisted = {_d};
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBridgeProvider.overrideWithValue(bridge),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026))),
      ],
    );

    final first = container.read(pickedGrantsProvider);
    expect(container.read(pickedGrantsProvider), same(first));

    final hold = Completer<void>();
    unawaited(container.read(mediaWorkQueueProvider).run(() => hold.future));
    final sweeping = first.sweep();
    await Future<void>.delayed(Duration.zero);
    expect(bridge.calls, isEmpty, reason: 'behind the shared queue');
    hold.complete();
    expect(await sweeping, 1);
  });
}

/// A bridge that lists each saved grant twice.
class _TwiceSaved extends FakeMediaBridge {
  @override
  Future<List<String>> persistedUris() async {
    final once = await super.persistedUris();
    return [...once, ...once];
  }
}
