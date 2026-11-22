import 'package:flutter/services.dart';

// The share screen's Dart, in the Patrol build. A Patrol build's Dart is
// `test_bundle.dart`, not `main.dart`, and a library nothing in it imports is
// not in the build: ShareActivity's engine then logs "Could not resolve main
// entrypoint function" and draws nothing (the S24, 2026-11-22, D-169). Every
// flow that starts a share imports this file, so the entry point comes with
// it, as `main.dart` brings it into the app's own build.
export 'package:taketray/share_main.dart' show shareMain;

/// The debug-only channel `app.taketray/test_share`
/// (`DebugShareHooks.kt`, Phase 9B Task 8, D-169): it starts the share screen
/// with a text, as another app's Share › TakeTray does, so a flow needs no
/// other app (and so no real Instagram link is ever opened or loaded).
///
/// The text goes to Android as it is and is never printed (D-10). Errors are
/// `PlatformException`s with the code `bad-args` (a text that is not a
/// string) or `native-error` (the class of the exception only), or a
/// `MissingPluginException` in a build without the hooks.
class TestShare {
  TestShare([this._channel = const MethodChannel(channelName)]);

  /// The name of the debug-only channel.
  static const String channelName = 'app.taketray/test_share';

  final MethodChannel _channel;

  /// Starts `ShareActivity` with an `ACTION_SEND` of `text/plain` carrying
  /// [text]. Returns when Android has been asked to start it; the screen and
  /// its own Flutter engine come up a moment later.
  ///
  /// It starts from the app's context with `FLAG_ACTIVITY_NEW_TASK`, so the
  /// screen is the root of a task of its own over TakeTray, not over a
  /// sharing app (D-169).
  Future<void> startShare(String text) =>
      _channel.invokeMethod<void>('startShare', text);
}
