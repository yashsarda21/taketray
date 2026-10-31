import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/tagging/view_models/tag_player_muted.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../support/fake_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform platform;
  final first = Uri.parse('content://media/external_primary/video/media/1');
  final second = Uri.parse('content://media/external_primary/video/media/2');

  setUp(() {
    platform = FakeVideoPlayerPlatform.install();
    // The binding is shared by the tests of this file: start in front.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  /// A container that keeps [uri]'s player open, like the screen does.
  ProviderContainer open(Uri uri, {ProviderContainer? into}) {
    return (into ?? ProviderContainer.test())
      ..listen(clipPlayerProvider(uri), (_, _) {});
  }

  group('the player', () {
    test('plays the content uri, with sound, from the start', () async {
      final c = open(first);

      final player = await c.read(clipPlayerProvider(first).future);

      expect(platform.uris, [first.toString()]);
      expect(player.value.isInitialized, isTrue);
      expect(platform.calls, contains('play:1'));
      expect(platform.player(1).playing, isTrue);
      expect(platform.player(1).volume, 1);
    });

    test('an error while opening is an error, not another video', () async {
      platform.failUris.add(first.toString());
      final c = open(first);

      await expectLater(
        c.read(clipPlayerProvider(first).future),
        throwsA(anything),
      );
      // The only player ever asked for is this clip's.
      expect(platform.uris, [first.toString()]);
    });

    test('a player that failed to open is disposed too', () async {
      platform.failUris.add(first.toString());
      final c = open(first);
      await expectLater(
        c.read(clipPlayerProvider(first).future),
        throwsA(anything),
      );

      c.dispose();
      await pumpEventQueue();

      expect(platform.live, isEmpty);
    });

    test('one controller alive: disposed when the page is left', () async {
      final c = ProviderContainer.test();
      final sub1 = c.listen(clipPlayerProvider(first), (_, _) {});
      await c.read(clipPlayerProvider(first).future);
      expect(platform.live.map((p) => p.id), [1]);

      // Page change: the screen stops listening to one and listens to the
      // next.
      sub1.close();
      c.listen(clipPlayerProvider(second), (_, _) {});
      await c.read(clipPlayerProvider(second).future);
      await pumpEventQueue();

      expect(platform.calls, contains('dispose:1'));
      expect(platform.live.map((p) => p.id), [2]);
      expect(platform.uris, [first.toString(), second.toString()]);
    });

    test('disposed when the container goes (the screen is popped)', () async {
      final c = open(first);
      await c.read(clipPlayerProvider(first).future);

      c.dispose();
      await pumpEventQueue();

      expect(platform.live, isEmpty);
      expect(platform.calls, contains('dispose:1'));
    });

    test('disposed while it was still opening', () async {
      platform.hold = true;
      final c = open(first);
      await pumpEventQueue();
      expect(platform.live, hasLength(1));

      c.dispose();
      await pumpEventQueue();

      expect(platform.live, isEmpty);
    });

    test('pauses on app pause, and does not start by itself again', () async {
      final c = open(first);
      await c.read(clipPlayerProvider(first).future);
      expect(platform.player(1).playing, isTrue);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await pumpEventQueue();
      expect(platform.player(1).playing, isFalse);
      expect(platform.calls.where((c) => c == 'pause:1'), isNotEmpty);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await pumpEventQueue();
      expect(platform.player(1).playing, isFalse);
      c.dispose();
    });

    test('the app leaving while the video opens: it never plays', () async {
      platform.hold = true;
      final c = open(first);
      await pumpEventQueue();
      expect(platform.live, hasLength(1));

      // Home is pressed while the video is still opening.
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      platform
          .player(1)
          .events
          .add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: platform.duration,
            ),
          );
      final player = await c.read(clipPlayerProvider(first).future);
      await pumpEventQueue();

      expect(player.value.isInitialized, isTrue);
      expect(platform.calls.where((c) => c.startsWith('play:')), isEmpty);
      expect(platform.player(1).playing, isFalse);

      // Back in the app it still waits for a tap.
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await pumpEventQueue();
      expect(platform.player(1).playing, isFalse);
      c.dispose();
    });

    test('a video that opens while the app is in front plays', () async {
      platform.hold = true;
      final c = open(first);
      await pumpEventQueue();
      TestWidgetsFlutterBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      platform
          .player(1)
          .events
          .add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: platform.duration,
            ),
          );

      await c.read(clipPlayerProvider(first).future);

      expect(platform.player(1).playing, isTrue);
      c.dispose();
    });

    test('the pause listener goes with the player', () async {
      final c = open(first);
      await c.read(clipPlayerProvider(first).future);
      c.dispose();
      await pumpEventQueue();
      final before = platform.calls.length;

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await pumpEventQueue();

      expect(platform.calls, hasLength(before));
    });
  });

  group('mute', () {
    test('sound starts on', () {
      final c = ProviderContainer.test();

      expect(c.read(viewerMutedProvider), isFalse);
    });

    test('the toggle mutes and unmutes the playing video', () async {
      final c = open(first);
      await c.read(clipPlayerProvider(first).future);

      c.read(viewerMutedProvider.notifier).toggle();
      await pumpEventQueue();
      expect(c.read(viewerMutedProvider), isTrue);
      expect(platform.player(1).volume, 0);

      c.read(viewerMutedProvider.notifier).toggle();
      await pumpEventQueue();
      expect(platform.player(1).volume, 1);
      c.dispose();
    });

    test('muted stays muted on the next clip, for the session', () async {
      final c = ProviderContainer.test();
      c.read(viewerMutedProvider.notifier).toggle();
      final sub1 = c.listen(clipPlayerProvider(first), (_, _) {});
      await c.read(clipPlayerProvider(first).future);
      expect(platform.player(1).volume, 0);

      sub1.close();
      c.listen(clipPlayerProvider(second), (_, _) {});
      await c.read(clipPlayerProvider(second).future);

      expect(platform.player(2).volume, 0);
      expect(c.read(viewerMutedProvider), isTrue);
      c.dispose();
    });

    test('a new session starts with sound on', () {
      final a = ProviderContainer.test();
      a.read(viewerMutedProvider.notifier).toggle();

      final b = ProviderContainer.test();

      expect(b.read(viewerMutedProvider), isFalse);
    });
  });

  group('tagging (D-96)', () {
    ProviderContainer openTagging(Uri uri) => ProviderContainer.test()
      ..listen(clipPlayerProvider(uri, use: ClipPlayerUse.tagging), (_, _) {});

    test('the tag player starts muted and loops the clip', () async {
      final c = openTagging(first);

      await c.read(
        clipPlayerProvider(first, use: ClipPlayerUse.tagging).future,
      );

      expect(platform.uris, [first.toString()]);
      expect(platform.player(1).volume, 0);
      expect(platform.player(1).looping, isTrue);
      expect(platform.player(1).playing, isTrue);
      c.dispose();
    });

    test('it follows its own switch, not the viewer one', () async {
      final c = openTagging(first);
      await c.read(
        clipPlayerProvider(first, use: ClipPlayerUse.tagging).future,
      );

      c.read(viewerMutedProvider.notifier).toggle();
      await pumpEventQueue();
      expect(platform.player(1).volume, 0);

      c.read(tagPlayerMutedProvider.notifier).toggle();
      await pumpEventQueue();
      expect(platform.player(1).volume, 1);
      c.dispose();
    });

    test('the viewer does not loop', () async {
      final c = open(first);

      await c.read(clipPlayerProvider(first).future);

      expect(platform.player(1).looping, isFalse);
      c.dispose();
    });
  });
}
