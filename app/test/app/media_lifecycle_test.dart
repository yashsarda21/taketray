import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app/media_lifecycle.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/media/picked_grants.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../support/fake_background_bridge.dart';
import '../support/fake_media_bridge.dart';
import '../support/vm_harness.dart';

/// A cache that only counts how often it is pruned.
class _CountingCache extends ThumbnailCache {
  _CountingCache(MediaBridge bridge) : super(bridge, Directory('/nowhere'));

  int prunes = 0;

  @override
  Future<void> prune() async => prunes++;
}

/// A background bridge that notes the copy the phone held when the app
/// cleared the new-clips notification.
class _ClearRecorder extends FakeBackgroundBridge {
  final List<BackgroundState?> heldAtClear = [];

  @override
  Future<void> clearNewClipsNotification() {
    heldAtClear.add(state);
    return super.clearNewClipsNotification();
  }
}

/// The media bridge and the background bridge write the order of their calls
/// to one list.
class _OrderedMedia extends RecordingBridge {
  _OrderedMedia(this.order);

  final List<String> order;

  @override
  Future<MediaAccess> accessReport() {
    order.add('accessReport');
    return super.accessReport();
  }

  @override
  Future<List<MediaVideo>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  ) {
    order.add('videosAddedAfter');
    return super.videosAddedAfter(volumeName, afterGeneration, folders, limit);
  }
}

class _OrderedBackground extends FakeBackgroundBridge {
  _OrderedBackground(this.order);

  final List<String> order;

  @override
  Future<NotificationAccess> notificationAccess() {
    order.add('notificationAccess');
    return super.notificationAccess();
  }
}

/// A second harness next to the one `setUp` made, on purpose: silences
/// drift's warning for the test, and puts it back after.
void allowSecondDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  addTearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
}

void main() {
  late VmHarness h;
  late _CountingCache cache;

  setUp(() {
    h = VmHarness();
    cache = _CountingCache(h.bridge);
    h.bridge.put([fakeVideo(id: 1, generation: 5)]);
  });

  Future<void> pumpLifecycle(
    WidgetTester tester, {
    Future<ThumbnailCache> Function()? thumbnails,
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          thumbnailCacheProvider.overrideWith(
            (ref) => thumbnails == null ? cache : thumbnails(),
          ),
          ...extra,
        ],
        child: const MaterialApp(home: MediaLifecycle(child: Text('the app'))),
      ),
    );
  }

  /// Lets the real async work (database, fake bridge) run.
  Future<void> work(WidgetTester tester) => tester.runAsync(settle);

  Future<void> resume(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await work(tester);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  int first(String method) => h.bridge.calls.indexOf(method);

  void expectZoneThenAccessThenScan() {
    expect(first('currentZoneId'), isNonNegative);
    expect(first('currentZoneId'), lessThan(first('accessReport')));
    expect(first('accessReport'), lessThan(first('videosAddedAfter')));
  }

  testWidgets('shows its child', (tester) async {
    await pumpLifecycle(tester);

    expect(find.text('the app'), findsOneWidget);
    await work(tester);
  });

  testWidgets(
    'on the first frame: zone sync, then access, then scan, and a prune',
    (tester) async {
      await h.media.turnOnNow();
      h.bridge.put([fakeVideo(id: 2, generation: 6)]);

      await pumpLifecycle(tester);
      await work(tester);

      expectZoneThenAccessThenScan();
      expect(cache.prunes, 1);
      expect(
        (await tester.runAsync(h.media.toTag))!.map((c) => c.mediaStoreId),
        [2],
      );
    },
  );

  testWidgets('on resume: the same three steps again, but no second prune', (
    tester,
  ) async {
    await h.media.turnOnNow();
    await pumpLifecycle(tester);
    await work(tester);
    h.bridge.calls.clear();

    await resume(tester);
    await work(tester);

    expectZoneThenAccessThenScan();
    expect(cache.prunes, 1);
  });

  group('the notification permission', () {
    final order = <String>[];

    setUp(() {
      order.clear();
      allowSecondDatabase();
      h = VmHarness(
        bridge: _OrderedMedia(order),
        background: _OrderedBackground(order),
      );
      h.bridge.put([fakeVideo(id: 1, generation: 5)]);
    });

    testWidgets(
      'is read on the first frame and on resume, after the access check and '
      'before the scan',
      (tester) async {
        await h.media.turnOnNow();
        h.bridge.put([fakeVideo(id: 2, generation: 6)]);

        await pumpLifecycle(tester);
        await work(tester);
        // The state is built once for the refresh to update, then refreshed.
        final firstRun = order.lastIndexOf('notificationAccess');
        expect(firstRun, isNonNegative);
        expect(order.indexOf('accessReport'), lessThan(firstRun));
        expect(firstRun, lessThan(order.indexOf('videosAddedAfter')));

        order.clear();
        await resume(tester);
        await work(tester);

        expect(order, contains('notificationAccess'));
        expect(
          order.indexOf('accessReport'),
          lessThan(order.indexOf('notificationAccess')),
        );
        expect(
          order.indexOf('notificationAccess'),
          lessThan(order.indexOf('videosAddedAfter')),
        );
      },
    );

    testWidgets('a failing read does not stop the scan', (tester) async {
      await h.media.turnOnNow();
      h.bridge.put([fakeVideo(id: 2, generation: 6)]);
      h.background
        ..failNext('notificationAccess')
        ..failNext('notificationAccess');

      await pumpLifecycle(tester);
      await work(tester);

      expect(tester.takeException(), isNull);
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
    });
  });

  testWidgets('going to the background starts nothing', (tester) async {
    await h.media.turnOnNow();
    await pumpLifecycle(tester);
    await work(tester);
    h.bridge.calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await work(tester);

    expect(h.bridge.calls, isEmpty);
  });

  testWidgets('a throwing scan is logged by type, not surfaced', (
    tester,
  ) async {
    final records = captureLogs();
    await h.media.turnOnNow();
    h.bridge.failNext('volumes'); // the scan's first bridge call

    await pumpLifecycle(tester);
    await work(tester);

    expect(tester.takeException(), isNull);
    expect(logText(records), contains('The scan failed: PlatformException'));
    expect(logText(records), isNot(contains('failed on purpose')));
  });

  testWidgets(
    'a failing zone sync does not stop the access check or the scan',
    (tester) async {
      await h.media.turnOnNow();
      h.bridge.put([fakeVideo(id: 2, generation: 6)]);
      h.bridge.failNext('pendingZoneChanges');

      await pumpLifecycle(tester);
      await work(tester);

      expect(h.bridge.count('accessReport'), greaterThan(0));
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
    },
  );

  testWidgets('a failing access check does not stop the scan', (tester) async {
    await h.media.turnOnNow();
    h.bridge.put([fakeVideo(id: 2, generation: 6)]);
    // The controller reads once when it is built and once for the refresh.
    h.bridge
      ..failNext('accessReport')
      ..failNext('accessReport');

    await pumpLifecycle(tester);
    await work(tester);

    expect(await tester.runAsync(h.media.toTag), hasLength(1));
  });

  testWidgets('a failing prune is logged and changes nothing else', (
    tester,
  ) async {
    final records = captureLogs();
    await h.media.turnOnNow();
    h.bridge.put([fakeVideo(id: 2, generation: 6)]);

    await pumpLifecycle(
      tester,
      thumbnails: () async => throw StateError('/data/cache is gone'),
    );
    await work(tester);

    expect(tester.takeException(), isNull);
    expect(
      logText(records),
      contains('Pruning the thumbnails failed: StateError'),
    );
    expect(logText(records), isNot(contains('/data')));
    expect(await tester.runAsync(h.media.toTag), hasLength(1));
  });

  group('the picked grants clean-up (Phase 7)', () {
    const unused =
        'content://media/picker/0/com.android.providers.media.photopicker/'
        'media/9';

    testWidgets('runs once on the first frame, on the media queue before the '
        "start's scan, and not on resume", (tester) async {
      await h.media.turnOnNow();
      h.bridge
        ..persisted = {unused}
        ..put([fakeVideo(id: 2, generation: 6)]);

      await pumpLifecycle(tester);
      await work(tester);

      expect(h.bridge.released, [
        [unused],
      ]);
      expect(first('persistedUris'), isNonNegative);
      expect(first('persistedUris'), lessThan(first('videosAddedAfter')));
      expect(
        (await tester.runAsync(h.media.toTag))!.map((c) => c.mediaStoreId),
        [2],
      );

      h.bridge.persisted = {unused};
      await resume(tester);
      await work(tester);

      expect(h.bridge.count('persistedUris'), 1);
      expect(h.bridge.released, hasLength(1));
    });

    testWidgets('a failing clean-up is logged by type only and the start '
        'still scans', (tester) async {
      final records = captureLogs();
      await h.media.turnOnNow();
      h.bridge
        ..persisted = {unused}
        ..failNext('persistedUris')
        ..put([fakeVideo(id: 2, generation: 6)]);

      await pumpLifecycle(tester);
      await work(tester);

      expect(tester.takeException(), isNull);
      expect(
        logText(records),
        contains('The picked grants clean-up failed: PlatformException'),
      );
      expect(logText(records), isNot(contains('content')));
      expect(logText(records), isNot(contains('on purpose')));
      expect(h.bridge.released, isEmpty);
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
    });

    testWidgets('a clean-up whose bridge call never answers gives up and '
        'does not hold the scan for ever', (tester) async {
      await h.media.turnOnNow();
      h.bridge
        ..persisted = {unused}
        ..put([fakeVideo(id: 2, generation: 6)]);
      h.bridge.gate('persistedUris'); // never completed
      const timeout = Duration(milliseconds: 50);

      await pumpLifecycle(
        tester,
        extra: [
          pickedGrantsProvider.overrideWith(
            (ref) => PickedGrants(
              ref.watch(mediaBridgeProvider),
              ref.watch(appDatabaseProvider),
              ref.watch(mediaWorkQueueProvider),
              bridgeTimeout: timeout,
            ),
          ),
        ],
      );
      await work(tester);
      // The timeout's timer runs on the test's fake clock.
      await tester.pump(timeout + _slack);
      await work(tester);

      expect(h.bridge.count('persistedUris'), 1, reason: 'it was asked');
      expect(h.bridge.released, isEmpty);
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
    });

    testWidgets('a release call that never returns times out on the fake '
        'clock, is logged by type only, and does not hold the scan', (
      tester,
    ) async {
      final records = captureLogs();
      await h.media.turnOnNow();
      h.bridge
        ..persisted = {unused}
        ..put([fakeVideo(id: 2, generation: 6)]);
      h.bridge.gate('releaseUris'); // never completed
      const timeout = Duration(milliseconds: 50);

      await pumpLifecycle(
        tester,
        extra: [
          pickedGrantsProvider.overrideWith(
            (ref) => PickedGrants(
              ref.watch(mediaBridgeProvider),
              ref.watch(appDatabaseProvider),
              ref.watch(mediaWorkQueueProvider),
              bridgeTimeout: timeout,
            ),
          ),
        ],
      );
      await work(tester);
      // The timeout's timer runs on the test's fake clock.
      await tester.pump(timeout + _slack);
      await work(tester);

      expect(tester.takeException(), isNull);
      expect(h.bridge.count('releaseUris'), 1, reason: 'it was asked');
      expect(
        logText(records),
        contains('The picked grants clean-up failed: TimeoutException'),
      );
      expect(logText(records), isNot(contains('content')));
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
    });
  });

  testWidgets(
    'a resume while the start is still running never scans twice at once',
    (tester) async {
      await h.media.turnOnNow();
      h.bridge.put([fakeVideo(id: 2, generation: 6)]);
      final gate = h.bridge.gate('videosAddedAfter');

      await pumpLifecycle(tester);
      await work(tester);
      expect(
        h.bridge.count('videosAddedAfter'),
        1,
        reason: 'start scan is held',
      );

      // Three resumes while it is held.
      for (var i = 0; i < 3; i++) {
        await resume(tester);
      }
      await work(tester);
      expect(
        h.bridge.count('videosAddedAfter'),
        1,
        reason: 'no second scan beside the held one',
      );
      // The lifecycle's own sync, and the one the scan runs inside its job.
      expect(h.bridge.count('pendingZoneChanges'), 2);

      gate.complete();
      await work(tester);

      // The three resumes cost exactly one more run.
      expect(h.bridge.count('videosAddedAfter'), 2);
      expect(h.bridge.count('pendingZoneChanges'), 4);
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
    },
  );

  testWidgets('removing the widget while a run is in flight does not crash', (
    tester,
  ) async {
    await h.media.turnOnNow();
    final gate = h.bridge.gate('pendingZoneChanges');
    await pumpLifecycle(tester);
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await work(tester);

    expect(tester.takeException(), isNull);
  });
  group('the background copy and the shade (D-106)', () {
    int clears() => h.background.calls
        .where((c) => c == 'clearNewClipsNotification')
        .length;

    testWidgets('lifecycle applies shade actions before the scan', (
      tester,
    ) async {
      final session = await tester.runAsync(h.media.turnOnNow);
      // 2 was shot before the Turn off in the shade (generation 6 then), 3
      // after it.
      h.bridge.put([
        fakeVideo(id: 2, generation: 6, sizeBytes: 2),
        fakeVideo(id: 3, generation: 7, sizeBytes: 3),
      ]);
      h.background.shadeAction = ShadeAction(
        kind: ShadeActionKind.turnOff,
        since: session!.since!,
        at: DateTime.utc(2026, 6, 1, 18),
        generations: const {'external_primary': 6},
      );

      await pumpLifecycle(tester);
      await work(tester);

      // Had the scan run first, 3 would be in To tag too.
      expect(
        (await tester.runAsync(h.media.toTag))!.map((c) => c.mediaStoreId),
        [2],
      );
      expect(
        await tester.runAsync(h.media.phoneState.loadShooting),
        ShootingState.off,
      );
      expect(h.background.shadeAction, isNull);
      // (The permission check, D-107, is a background call before it.)
      expect(
        h.background.calls.firstWhere((c) => c != 'notificationAccess'),
        'pendingShadeAction',
      );
      // The scan's own gate ended the session, reading every volume: that
      // counts as a scan, so the notification is cleared.
      expect(clears(), 1);
    });

    testWidgets('the lifecycle no longer calls apply before the scan', (
      tester,
    ) async {
      // Shooting mode off: the scan reads the action and stops, so nothing
      // after it (the copy's flush) reads it too.

      await pumpLifecycle(tester);
      await work(tester);

      // One read: the scan's gate. A separate apply would read it again.
      expect(
        h.background.calls.where((c) => c == 'pendingShadeAction'),
        hasLength(1),
      );
    });

    testWidgets('one lifecycle run with a failing volume counts one failure', (
      tester,
    ) async {
      final session = await tester.runAsync(h.media.turnOnNow);
      h.bridge.put([fakeVideo(id: 2, generation: 6, sizeBytes: 2)]);
      for (var i = 0; i < 20; i++) {
        h.bridge.failNext('videosAddedAfter');
      }
      h.background.shadeAction = ShadeAction(
        kind: ShadeActionKind.turnOff,
        since: session!.since!,
        at: DateTime.utc(2026, 6, 1, 18),
        generations: const {'external_primary': 6},
      );
      Future<bool> stillOn() async =>
          (await tester.runAsync(h.media.phoneState.loadShooting))!.on;

      await pumpLifecycle(tester); // run 1: counted 1
      await work(tester);
      h.media.clock.advance(const Duration(minutes: 5));
      await resume(tester); // run 2: counted 2
      await work(tester);

      expect(await stillOn(), isTrue);
      expect(h.background.shadeAction, isNotNull);

      h.media.clock.advance(const Duration(minutes: 5));
      await resume(tester); // run 3: counted 3, ends
      await work(tester);
      expect(await stillOn(), isFalse);
    });

    testWidgets(
      'a 3rd-try end that read nothing does not clear the notification',
      (tester) async {
        final session = await tester.runAsync(h.media.turnOnNow);
        for (var i = 0; i < 20; i++) {
          h.bridge.failNext('volumes');
        }
        // No volume could be read at the tap either.
        h.background.shadeAction = ShadeAction(
          kind: ShadeActionKind.turnOff,
          since: session!.since!,
          at: DateTime.utc(2026, 6, 1, 18),
          generations: const {},
        );

        await pumpLifecycle(tester);
        await work(tester);
        for (var i = 0; i < 2; i++) {
          h.media.clock.advance(const Duration(minutes: 5));
          await resume(tester);
          await work(tester);
        }

        expect(
          await tester.runAsync(h.media.phoneState.loadShooting),
          ShootingState.off,
        );
        // Nothing was read: the stored clips are still uncounted.
        expect(clears(), 0);
      },
    );

    testWidgets('lifecycle clears the notification after a scan', (
      tester,
    ) async {
      await h.media.turnOnNow();

      await pumpLifecycle(tester);
      await work(tester);

      expect(clears(), 1);
      await resume(tester);
      await work(tester);
      expect(clears(), 2);
    });

    testWidgets(
      'lifecycle writes the new baselines before clearing the notification',
      (tester) async {
        final recorder = _ClearRecorder();
        allowSecondDatabase();
        h = VmHarness(background: recorder);
        h.bridge.put([fakeVideo(id: 1, generation: 5)]);
        await h.media.turnOnNow();
        h.bridge.put([fakeVideo(id: 2, generation: 6, sizeBytes: 2)]);

        await pumpLifecycle(tester);
        await work(tester);

        expect(recorder.heldAtClear, hasLength(1));
        expect(
          recorder.heldAtClear.single,
          isNotNull,
          reason: 'the copy is written before the notification is cleared',
        );
        final held = recorder.heldAtClear.single!;
        expect(held.shootingOn, isTrue);
        expect(held.baselines['external_primary']!.generation, 6);
        expect(held.waitingShots, hasLength(1));
      },
    );

    testWidgets('no clear when the scan was skipped', (tester) async {
      // Shooting mode off.
      await pumpLifecycle(tester);
      await work(tester);
      expect(clears(), 0);

      // On, but without full access.
      await h.media.turnOnNow();
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );
      await resume(tester);
      await work(tester);
      expect(clears(), 0);
    });

    testWidgets('the notification is not cleared after a scan with failed '
        'volumes', (tester) async {
      await h.media.turnOnNow();
      h.bridge
        ..put([fakeVideo(id: 2, generation: 6, sizeBytes: 2)])
        ..failNext('videosAddedAfter');

      await pumpLifecycle(tester);
      await work(tester);

      // The volume that failed still has clips the job counts.
      expect(clears(), 0);
    });

    testWidgets('no clear when the scan threw', (tester) async {
      await h.media.turnOnNow();
      h.bridge.failNext('volumes');

      await pumpLifecycle(tester);
      await work(tester);

      expect(tester.takeException(), isNull);
      expect(clears(), 0);
    });

    testWidgets('a failing shade read defers the scan; the next run scans', (
      tester,
    ) async {
      final records = captureLogs();
      await h.media.turnOnNow();
      h.bridge.put([fakeVideo(id: 2, generation: 6, sizeBytes: 2)]);
      h.background.failNext('pendingShadeAction');

      await pumpLifecycle(tester);
      await work(tester);

      expect(tester.takeException(), isNull);
      expect(logText(records), contains('Scan deferred'));
      expect(await tester.runAsync(h.media.toTag), isEmpty);
      expect(clears(), 0);

      await resume(tester);
      await work(tester);
      expect(await tester.runAsync(h.media.toTag), hasLength(1));
      expect(clears(), 1);
    });

    testWidgets('a failing clear is logged by type, not surfaced', (
      tester,
    ) async {
      final records = captureLogs();
      await h.media.turnOnNow();
      h.background.failNext('clearNewClipsNotification');

      await pumpLifecycle(tester);
      await work(tester);

      expect(tester.takeException(), isNull);
      expect(
        logText(records),
        contains(
          'Clearing the new clips notification failed: '
          'PlatformException',
        ),
      );
    });
  });
}

const Duration _slack = Duration(milliseconds: 200);
