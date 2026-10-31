import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/features/tagging/view_models/tag_player_muted.dart';
import 'package:video_player/video_player.dart';

part 'clip_player.g.dart';

// Error types only, never an address, a name or a message (D-10).
final Logger _log = Logger('clipPlayer');

/// Whether the viewer's sound is off. It starts on and is kept for the
/// session: the next clip, and the next time the viewer opens, are muted if
/// this one was. Not stored; a restart starts with sound.
@Riverpod(keepAlive: true)
class ViewerMuted extends _$ViewerMuted {
  @override
  bool build() => false;

  /// Mutes, or unmutes.
  void toggle() => state = !state;
}

/// The player of the clip at [uri] (D-89): one `VideoPlayerController`
/// (ExoPlayer, from the gallery by its `content://` address, never copied),
/// opened, with the sound as the viewer's mute switch says, and playing.
///
/// - **One at a time.** The viewer watches the player of the page it shows
///   and nothing else. When the page changes it stops watching, the provider
///   is disposed, and the controller is disposed with it; when the screen is
///   popped the same happens. A page that was never shown never makes one.
/// - **A failure is an error value.** A video the phone cannot play
///   (damaged, an unsupported format, gone) makes the future throw. The
///   screen shows "This video can't be played"; it never plays another video.
/// - **It pauses when the app goes to the background** (`paused`, and
///   `hidden` just before it) and does not start again by itself when the
///   app returns: the user taps to play. The plugin's own lifecycle handling
///   is switched off (`allowBackgroundPlayback`), because it would resume a
///   video the user left.
/// - **The mute switch** is followed while the player lives.
///
/// - **[use]** says whose player it is: the clip viewer's
///   ([ClipPlayerUse.viewer], the default, unchanged) or the tag player's
///   ([ClipPlayerUse.tagging], D-96), which follows its own mute switch
///   (`TagPlayerMuted`, muted at first) and **loops** the clip, so a short
///   clip keeps playing while the user decides.
///
/// - **[autoplay]** false opens the clip and leaves it paused (muted as the
///   switch says, looping for the tag player): the tag player keeps the next
///   clip open one ahead, and it must not be heard or move off screen. The
///   tag player always asks with it off, for the clip showing and the one
///   ahead alike (the same family entry, so the clip that comes up is the
///   controller that was opened), and plays the one showing itself.
///
/// Auto-disposes, and never retries: a video that failed once would open
/// again and again. The address is not logged.

@Riverpod(retry: noRetry)
Future<VideoPlayerController> clipPlayer(
  Ref ref,
  Uri uri, {
  ClipPlayerUse use = ClipPlayerUse.viewer,
  bool autoplay = true,
}) async {
  final mutedSwitch = switch (use) {
    ClipPlayerUse.viewer => viewerMutedProvider,
    ClipPlayerUse.tagging => tagPlayerMutedProvider,
  };
  final controller = VideoPlayerController.contentUri(
    uri,
    videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
  );
  final pauser = _PauseInBackground(controller)..start();
  ref
    ..onDispose(() {
      pauser.stop();
      unawaited(controller.dispose());
    })
    ..listen<bool>(
      mutedSwitch,
      (_, muted) => unawaited(_setSound(controller, muted: muted)),
    );
  try {
    await controller.initialize();
  } on Object catch (error) {
    _log.warning('A clip could not be opened: ${error.runtimeType}');
    rethrow;
  }
  await _setSound(controller, muted: ref.read(mutedSwitch));
  if (use == ClipPlayerUse.tagging) await controller.setLooping(true);
  // The app may have gone to the background while the video was opening:
  // the observer found nothing to pause then, and the plugin's own check is
  // off, so playing now would be heard from the background.
  if (autoplay && !pauser.inBackground) await controller.play();
  return controller;
}

/// Whose player a [clipPlayer] is: it picks the mute switch, and whether the
/// clip loops.
enum ClipPlayerUse {
  /// The clip viewer of a reel (D-89): its own mute switch, plays once.
  viewer,

  /// The tag player (D-96): muted at first, loops.
  tagging,
}

Future<void> _setSound(
  VideoPlayerController controller, {
  required bool muted,
}) async {
  if (!controller.value.isInitialized) return;
  await controller.setVolume(muted ? 0 : 1);
}

/// Pauses [_controller] when the app leaves the screen, and remembers that it
/// is away until it is back, so a video that finishes opening in the
/// background is not started.
class _PauseInBackground with WidgetsBindingObserver {
  _PauseInBackground(this._controller);

  final VideoPlayerController _controller;

  /// Whether the app is hidden or paused (not just inactive).
  bool inBackground = false;

  void start() {
    final binding = WidgetsBinding.instance..addObserver(this);
    final now = binding.lifecycleState;
    inBackground =
        now == AppLifecycleState.paused || now == AppLifecycleState.hidden;
  }

  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        inBackground = true;
        if (_controller.value.isInitialized) unawaited(_controller.pause());
      case AppLifecycleState.resumed:
        inBackground = false;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
