import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/vm_harness.dart';

MediaAccess access(MediaAccessLevel level, {bool canAskAgain = true}) =>
    MediaAccess(level: level, canAskAgain: canAskAgain, sdkInt: 34);

const MediaAccessLevel full = MediaAccessLevel.full;
const MediaAccessLevel limited = MediaAccessLevel.limited;
const MediaAccessLevel denied = MediaAccessLevel.denied;

/// A bridge whose first `accessReport` waits until [release] is called and
/// then fails (a slow first read that fails late); later calls are normal.
class _SlowFirstFails extends RecordingBridge {
  final Completer<void> release = Completer<void>();
  bool _first = true;

  @override
  Future<MediaAccess> accessReport() async {
    if (_first) {
      _first = false;
      calls.add('accessReport');
      await release.future;
      throw PlatformException(code: 'slow', message: '/storage/secret');
    }
    return await super.accessReport();
  }
}

void main() {
  group('bannerFor', () {
    // Every level x wasFull. Limited is manual either way; only a denied
    // phone that once had full access is "lost".
    final table = <(MediaAccessLevel, bool, AccessBanner)>[
      (full, false, AccessBanner.none),
      (full, true, AccessBanner.none),
      (limited, false, AccessBanner.manual),
      (limited, true, AccessBanner.manual),
      (denied, false, AccessBanner.manual),
      (denied, true, AccessBanner.lost),
    ];
    for (final (level, wasFull, banner) in table) {
      test('${level.name}, wasFull=$wasFull -> ${banner.name}', () {
        expect(bannerFor(level, wasFull: wasFull), banner);
      });
    }
  });

  late VmHarness h;
  late MediaAccessController controller;

  setUp(() => h = VmHarness());

  Future<MediaAccessView> viewAfterBuild() async {
    final view = await h.container.read(mediaAccessControllerProvider.future);
    controller = h.container.read(mediaAccessControllerProvider.notifier);
    return view;
  }

  MediaAccessView? current() =>
      h.container.read(mediaAccessControllerProvider).value;

  group('build', () {
    test('full access: no banner, and "was full" is remembered', () async {
      h.bridge.access = access(full);

      final view = await viewAfterBuild();

      expect(view.level, full);
      expect(view.banner, AccessBanner.none);
      expect(await h.media.phoneState.accessWasFull(), isTrue);
    });

    test('denied and never full: manual', () async {
      h.bridge.access = access(denied);

      final view = await viewAfterBuild();

      expect(view.banner, AccessBanner.manual);
      expect(view.canAskAgain, isTrue);
      expect(await h.media.phoneState.accessWasFull(), isFalse);
    });

    test('denied after full was seen: lost', () async {
      await h.media.phoneState.markAccessWasFull();
      h.bridge.access = access(denied, canAskAgain: false);

      final view = await viewAfterBuild();

      expect(view.banner, AccessBanner.lost);
      expect(view.canAskAgain, isFalse);
    });

    test('a bridge error is an error state, not an uncaught error', () async {
      h.bridge.failNext('accessReport');

      await expectLater(
        h.container.read(mediaAccessControllerProvider.future),
        throwsA(anything),
      );

      expect(
        h.container.read(mediaAccessControllerProvider),
        isA<AsyncError<MediaAccessView>>(),
      );
    });
  });

  group('refresh', () {
    test('access lost while in the background: lost after resume', () async {
      h.bridge.access = access(full);
      await viewAfterBuild();
      expect(current()!.banner, AccessBanner.none);

      h.bridge.access = access(denied, canAskAgain: false);
      await controller.refresh();

      expect(current()!.banner, AccessBanner.lost);
      expect(current()!.canAskAgain, isFalse);
    });

    test('access granted in the settings page: full, and remembered', () async {
      h.bridge.access = access(denied, canAskAgain: false);
      await viewAfterBuild();

      h.bridge.access = access(full);
      await controller.refresh();

      expect(current()!.banner, AccessBanner.none);
      expect(await h.media.phoneState.accessWasFull(), isTrue);
    });

    test('an error keeps the last view and logs only the type', () async {
      final records = captureLogs();
      h.bridge.access = access(limited);
      await viewAfterBuild();

      h.bridge.failNext('accessReport');
      await controller.refresh();

      expect(current()!.level, limited);
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
    });

    test(
      'an older answer arriving late cannot overwrite a newer one',
      () async {
        h.bridge.access = access(full);
        await viewAfterBuild();

        final gate = h.bridge.gate('accessReport');
        final slow = controller.refresh(); // reads "full", then waits
        await settle();
        h.bridge.access = access(denied, canAskAgain: false);
        await controller.refresh(); // reads "denied", finishes first
        gate.complete();
        await slow;

        expect(current()!.level, denied);
      },
    );
  });

  group('recovery from a failed first read', () {
    Future<void> failFirstRead() async {
      h.bridge.failNext('accessReport');
      h.container.listen(mediaAccessControllerProvider, (_, _) {});
      controller = h.container.read(mediaAccessControllerProvider.notifier);
      await expectLater(
        h.container.read(mediaAccessControllerProvider.future),
        throwsA(anything),
      );
      expect(
        h.container.read(mediaAccessControllerProvider),
        isA<AsyncError<MediaAccessView>>(),
      );
    }

    test('a later refresh turns the error into a view', () async {
      await failFirstRead();
      h.bridge.access = access(denied);

      await controller.refresh();

      expect(current()!.level, denied);
      expect(
        h.container.read(mediaAccessControllerProvider),
        isA<AsyncData<MediaAccessView>>(),
      );
    });

    test('a later allow turns the error into a view', () async {
      await failFirstRead();
      h.bridge.access = access(denied, canAskAgain: false);

      await controller.allow();

      expect(current()!.banner, AccessBanner.manual);
      expect(
        h.container.read(mediaAccessControllerProvider),
        isA<AsyncData<MediaAccessView>>(),
      );
    });

    test(
      'a refresh that fails too leaves the error, without throwing',
      () async {
        await failFirstRead();
        h.bridge.failNext('accessReport');

        await controller.refresh();

        expect(
          h.container.read(mediaAccessControllerProvider),
          isA<AsyncError<MediaAccessView>>(),
        );
      },
    );

    test('a refresh that fails while the first read is still waiting '
        'shows the error, and the first read can still fix it', () async {
      final gate = h.bridge.gate('accessReport'); // the first read waits
      h.container.listen(mediaAccessControllerProvider, (_, _) {});
      controller = h.container.read(mediaAccessControllerProvider.notifier);
      await settle();
      h.bridge.failNext('accessReport');

      await controller.refresh();
      expect(
        h.container.read(mediaAccessControllerProvider),
        isA<AsyncError<MediaAccessView>>(),
      );

      gate.complete();
      await settle();
      expect(current()!.level, full);
    });

    test('a first read that fails late cannot replace a newer view', () async {
      final slow = _SlowFirstFails();
      final local = VmHarness(bridge: slow);
      local.container.listen(mediaAccessControllerProvider, (_, _) {});
      final notifier = local.container.read(
        mediaAccessControllerProvider.notifier,
      );
      await settle(); // the first read is waiting
      slow.access = access(limited);

      await notifier.refresh(); // publishes a view
      expect(
        local.container.read(mediaAccessControllerProvider).value?.level,
        limited,
      );
      slow.release.complete(); // the first read now fails
      await settle();

      final state = local.container.read(mediaAccessControllerProvider);
      expect(state, isA<AsyncData<MediaAccessView>>());
      expect(state.value!.level, limited);
    });
  });

  group('allow', () {
    test('requests when it can ask again', () async {
      h.bridge.access = access(denied);
      await viewAfterBuild();
      h.bridge.onRequestAccess = () => access(denied);

      await controller.allow();

      expect(h.bridge.count('requestAccess'), 1);
      expect(h.bridge.count('openAppSettings'), 0);
    });

    test('opens the settings page when it cannot ask again', () async {
      h.bridge.access = access(denied, canAskAgain: false);
      await viewAfterBuild();

      await controller.allow();

      expect(h.bridge.count('openAppSettings'), 1);
      expect(h.bridge.count('requestAccess'), 0);
    });

    test('limited is always askable, even when canAskAgain is false', () async {
      h.bridge.access = access(limited, canAskAgain: false);
      await viewAfterBuild();
      h.bridge.onRequestAccess = () => access(limited, canAskAgain: false);

      await controller.allow();

      expect(h.bridge.count('requestAccess'), 1);
      expect(h.bridge.count('openAppSettings'), 0);
    });

    test('reads a fresh report, not the one shown', () async {
      h.bridge.access = access(denied); // the view says "can ask again"
      await viewAfterBuild();
      // The user chose "don't ask again" in the background.
      h.bridge.access = access(denied, canAskAgain: false);

      await controller.allow();

      expect(h.bridge.count('requestAccess'), 0);
      expect(h.bridge.count('openAppSettings'), 1);
    });

    test(
      'granting full marks it, shows no banner, and starts one scan',
      () async {
        h.bridge.access = access(denied);
        h.bridge.put([fakeVideo(id: 1)]);
        await h.media.turnOnNow();
        await viewAfterBuild();
        h.bridge.onRequestAccess = () => access(full);
        final before = h.bridge.count('videosAddedAfter');

        await controller.allow();
        await settle();

        expect(current()!.banner, AccessBanner.none);
        expect(await h.media.phoneState.accessWasFull(), isTrue);
        expect(h.bridge.count('videosAddedAfter') - before, 1);
      },
    );

    test('already full (the screen showed denied): shows it, scans once, '
        'asks nothing', () async {
      h.bridge.access = access(denied);
      h.bridge.put([fakeVideo(id: 1)]);
      await h.media.turnOnNow();
      await viewAfterBuild();
      expect(current()!.banner, AccessBanner.manual);
      // The user allowed it in the phone's settings meanwhile.
      h.bridge.access = access(full);
      final before = h.bridge.count('videosAddedAfter');

      await controller.allow();
      await settle();

      expect(h.bridge.count('requestAccess'), 0);
      expect(h.bridge.count('openAppSettings'), 0);
      expect(current()!.level, full);
      expect(current()!.banner, AccessBanner.none);
      expect(await h.media.phoneState.accessWasFull(), isTrue);
      expect(h.bridge.count('videosAddedAfter') - before, 1);
    });

    test('granting only limited: manual, not remembered, no scan', () async {
      h.bridge.access = access(denied);
      h.bridge.put([fakeVideo(id: 1)]);
      await h.media.turnOnNow();
      await viewAfterBuild();
      h.bridge.onRequestAccess = () => access(limited);

      await controller.allow();
      await settle();

      expect(current()!.level, limited);
      expect(current()!.banner, AccessBanner.manual);
      expect(await h.media.phoneState.accessWasFull(), isFalse);
      expect(h.bridge.count('videosAddedAfter'), 0);
    });

    test('still denied after asking: lost if it was full once', () async {
      await h.media.phoneState.markAccessWasFull();
      h.bridge.access = access(denied);
      await viewAfterBuild();
      h.bridge.onRequestAccess = () => access(denied, canAskAgain: false);

      await controller.allow();

      expect(current()!.banner, AccessBanner.lost);
      expect(current()!.canAskAgain, isFalse);
    });

    test(
      'a request already in flight (busy): no crash, state unchanged',
      () async {
        final records = captureLogs();
        h.bridge.access = access(denied);
        await viewAfterBuild();
        final before = current();
        // The first request is still waiting on the dialog; the Kotlin side
        // answers a second one with a "busy" PlatformException.
        h.bridge.failNext('requestAccess');

        await controller.allow();

        expect(current(), before);
        expect(await h.media.phoneState.accessWasFull(), isFalse);
        expect(logText(records), contains('PlatformException'));
      },
    );

    test('an error from the fresh report is logged, not thrown', () async {
      h.bridge.access = access(denied);
      await viewAfterBuild();
      final before = current();
      h.bridge.failNext('accessReport');

      await controller.allow();

      expect(current(), before);
      expect(h.bridge.count('requestAccess'), 0);
    });

    test('an error from the settings page is logged, not thrown', () async {
      h.bridge.access = access(denied, canAskAgain: false);
      await viewAfterBuild();
      h.bridge.failNext('openAppSettings');

      await controller.allow();

      expect(current()!.level, denied);
    });
  });

  group('MediaAccessView', () {
    test('has value equality', () {
      const a = MediaAccessView(
        level: full,
        banner: AccessBanner.none,
        canAskAgain: true,
      );
      const b = MediaAccessView(
        level: full,
        banner: AccessBanner.none,
        canAskAgain: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const MediaAccessView(
            level: full,
            banner: AccessBanner.none,
            canAskAgain: false,
          ),
        ),
      );
      expect(a.toString(), contains('full'));
    });
  });
}
