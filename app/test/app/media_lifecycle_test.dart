import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app/media_lifecycle.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../support/fake_media_bridge.dart';
import '../support/vm_harness.dart';

/// A cache that only counts how often it is pruned.
class _CountingCache extends ThumbnailCache {
  _CountingCache(MediaBridge bridge) : super(bridge, Directory('/nowhere'));

  int prunes = 0;

  @override
  Future<void> prune() async => prunes++;
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          thumbnailCacheProvider.overrideWith(
            (ref) => thumbnails == null ? cache : thumbnails(),
          ),
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
}
