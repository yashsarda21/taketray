import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/platform/background_bridge.dart';

part 'shade_actions.g.dart';

// The kind of action and what was done only: never a time, a session or a
// generation (D-10).
final Logger _log = Logger('shadeActions');

/// Applies a "Still shooting?" button tapped in the notification shade
/// (D-105, D-106).
///
/// The shade's receiver cannot write the database (D-103: Dart is the
/// truth), so it stores the tap as a [ShadeAction], and Dart applies it here:
/// at every app start and resume (`MediaLifecycle`), and before every write
/// of the native copy (`BackgroundSync`).
class ShadeActions {
  new(this._bridge, this._phone, this._scanner);

  final BackgroundBridge _bridge;
  final PhoneStateRepository _phone;
  final MediaScanner _scanner;

  /// The apply that is running, if any: a call made meanwhile shares it.
  Future<void>? _running;

  /// Reads the waiting shade action, if any, and applies it only to its own
  /// Shooting mode session:
  /// - **Turn off:** `MediaScanner.endSessionAt` with the generations of the
  ///   tap (the clips shot before it arrive, none after), then off;
  /// - **Keep on:** `PhoneStateRepository.markStillAnswered`.
  ///
  /// Then it clears the action by the time of its tap, so a newer tap stays.
  /// An action for another session (Shooting mode was turned off, or off and
  /// on again, since the notification was posted) is dropped: only cleared.
  ///
  /// It throws when the bridge or the scan fails; the action then stays for
  /// the next try (a Turn off whose session has ended by then is dropped as
  /// stale). Calls made while one runs share it.
  Future<void> apply() =>
      _running ??= _applyOnce().whenComplete(() => _running = null);

  Future<void> _applyOnce() async {
    final action = await _bridge.pendingShadeAction();
    if (action == null) return;
    final kind = action.kind.name;
    final session = await _phone.loadShooting();
    if (!session.isSession(action.since)) {
      _log.info('Shade action $kind dropped: it was for another session');
    } else {
      switch (action.kind) {
        case ShadeActionKind.turnOff:
          await _scanner.endSessionAt(
            since: action.since,
            generations: action.generations,
          );
        case ShadeActionKind.keepOn:
          await _phone.markStillAnswered(action.since);
      }
      _log.info('Shade action $kind applied');
    }
    await _bridge.clearShadeAction(action.at);
  }
}

/// The one [ShadeActions]. Kept alive: the apply that calls share lives in
/// it.
@Riverpod(keepAlive: true)
ShadeActions shadeActions(Ref ref) => ShadeActions(
  ref.watch(backgroundBridgeProvider),
  ref.watch(phoneStateRepositoryProvider),
  ref.watch(mediaScannerProvider),
);
