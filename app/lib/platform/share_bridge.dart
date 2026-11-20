import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/platform/share_api.g.dart';

part 'share_bridge.g.dart';

// Lengths and error codes only: never the shared text (D-10).
final Logger _log = Logger('shareBridge');

/// The share screen's way to Android (D-163): the text another app shared,
/// and closing the screen. Only the share engine (`shareMain`) has it; the
/// app's own engine never registers the Kotlin side. Tests use a fake.
abstract interface class ShareBridge {
  /// The text of the share, once: `EXTRA_TEXT` of a `text/plain` share, cut
  /// to 20,000 characters. Null when there is none, when it was already
  /// read (until a new share arrives), and when Android failed (logged by
  /// its error code only).
  Future<String?> sharedText();

  /// Closes the share screen, back to the app that shared. A failure is
  /// logged by its code and swallowed.
  Future<void> finish();

  /// Closes the share screen and opens the reel [reelId] in TakeTray (Task 4
  /// completes the opening; until then it only closes). A failure is logged
  /// by its code and swallowed.
  Future<void> openReel(int reelId);
}

/// The [ShareBridge] that talks to Kotlin through the Pigeon-generated
/// [ShareHostApi].
class PigeonShareBridge implements ShareBridge {
  /// [api] defaults to a real [ShareHostApi]; tests pass a stub.
  PigeonShareBridge([ShareHostApi? api]) : _api = api ?? ShareHostApi();

  final ShareHostApi _api;

  @override
  Future<String?> sharedText() async {
    try {
      final text = await _api.sharedText();
      _log.info(
        text == null
            ? 'Shared text: none'
            : 'Shared text: ${text.length} characters',
      );
      return text;
    } on PlatformException catch (e) {
      _log.warning('Reading the shared text failed: ${e.code}');
      return null;
    }
  }

  @override
  Future<void> finish() async {
    try {
      await _api.finish();
    } on PlatformException catch (e) {
      _log.warning('Closing the share screen failed: ${e.code}');
    }
  }

  @override
  Future<void> openReel(int reelId) async {
    try {
      await _api.openReel(reelId);
    } on PlatformException catch (e) {
      _log.warning('Opening the reel from a share failed: ${e.code}');
    }
  }
}

@Riverpod(keepAlive: true)
ShareBridge shareBridge(Ref ref) => PigeonShareBridge();
