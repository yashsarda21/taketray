import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/vm_harness.dart';

void main() {
  late VmHarness h;

  setUp(() {
    h = VmHarness();
    h.bridge.put([fakeVideo(id: 1, generation: 5)]);
  });

  /// Opens To tag like the screen does and keeps it open.
  ProviderSubscription<AsyncValue<List<Clip>>> open() =>
      h.container.listen(toTagControllerProvider, (_, _) {});

  List<int?> shownIds() => [
    for (final c in h.container.read(toTagControllerProvider).value ?? <Clip>[])
      c.mediaStoreId,
  ];

  int firstCall(String method) => h.bridge.calls.indexOf(method);

  test('shows the clips waiting in To tag, oldest first', () async {
    await h.media.store([
      fakeVideo(id: 2, generation: 2, dateTakenMs: 1780000200000),
      fakeVideo(id: 3, generation: 3, dateTakenMs: 1780000100000),
    ]);
    open();

    await h.container.read(toTagControllerProvider.future);

    expect(shownIds(), [3, 2]);
  });

  test('scans, then verifies the waiting clips, when it opens', () async {
    await h.media.turnOnNow();
    h.bridge.put([fakeVideo(id: 6, generation: 6)]);
    await h.media.store([fakeVideo(id: 1, generation: 5)]);
    open();

    await settle();

    expect(h.bridge.count('videosAddedAfter'), 1);
    expect(h.bridge.count('videosByIds'), 1);
    expect(firstCall('videosAddedAfter'), lessThan(firstCall('videosByIds')));
  });

  test('a video shot while Shooting mode is on appears', () async {
    await h.media.turnOnNow();
    h.bridge.put([fakeVideo(id: 6, generation: 6)]);
    open();

    await settle();

    expect(shownIds(), [6]);
  });

  test('a video that left the phone leaves the list', () async {
    await h.media.store([
      fakeVideo(id: 1, generation: 5),
      fakeVideo(id: 9, generation: 9),
    ]);
    open();

    await settle();

    expect(shownIds(), [1], reason: 'video 9 is not on the phone');
  });

  test('opens once per build, not once per reader', () async {
    await h.media.turnOnNow();
    open();
    h.container.read(toTagControllerProvider);
    h.container.listen(toTagControllerProvider, (_, _) {});

    await settle();

    expect(h.bridge.count('videosAddedAfter'), 1);
  });

  test('opening To tag again after it was closed scans again', () async {
    await h.media.turnOnNow();
    open().close();
    await settle();

    open();
    await settle();

    expect(h.bridge.count('videosAddedAfter'), 2);
  });

  test('onResume repeats the scan and the verify', () async {
    await h.media.turnOnNow();
    await h.media.store([fakeVideo(id: 1, generation: 5)]);
    open();
    await settle();
    final scans = h.bridge.count('videosAddedAfter');
    final verifies = h.bridge.count('videosByIds');

    await h.container.read(toTagControllerProvider.notifier).onResume();

    expect(h.bridge.count('videosAddedAfter'), scans + 1);
    expect(h.bridge.count('videosByIds'), verifies + 1);
  });

  test(
    'a scan that throws is logged, the list still shows, verify runs',
    () async {
      final records = captureLogs();
      await h.media.turnOnNow();
      await h.media.store([fakeVideo(id: 1, generation: 5)]);
      h.bridge.failNext('volumes');
      open();

      await settle();

      expect(shownIds(), [1]);
      expect(h.bridge.count('videosByIds'), 1);
      expect(logText(records), contains('The scan failed: PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
    },
  );

  test('a verify that throws is logged, the list still shows', () async {
    final records = captureLogs();
    await h.media.store([fakeVideo(id: 1, generation: 5)]);
    // Shooting mode is off, so the scan reads nothing; the verify's first call
    // is its access check.
    h.bridge.failNext('accessReport');
    open();

    await settle();

    expect(shownIds(), [1]);
    expect(logText(records), contains('The verify failed: PlatformException'));
  });

  test('no clips and no phone: an empty list, no error', () async {
    open();

    expect(await h.container.read(toTagControllerProvider.future), isEmpty);
  });
}
