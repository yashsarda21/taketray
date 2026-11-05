import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/media/media_scanner.dart';

part 'shade_actions.g.dart';

/// Applies a "Still shooting?" button tapped in the notification shade
/// (D-105, D-106).
///
/// The shade's receiver cannot write the database (D-103: Dart is the
/// truth), so it stores the tap as a `ShadeAction`, and Dart applies it here:
/// at every app start and resume (`MediaLifecycle`), before every write of
/// the native copy (`BackgroundSync`), and first in every scan
/// (`MediaScanner.scan`).
class ShadeActions {
  new(this._scanner);

  final MediaScanner _scanner;

  /// Applies the waiting shade action, if any, only to its own Shooting
  /// mode session, as one job on the media queue
  /// (`MediaScanner.applyShadeAction`; every scan does the same first):
  /// - **Turn off:** the end capped at the tap (the clips shot before it
  ///   arrive, none after), then off. A volume that fails keeps the session
  ///   and the action for the next try, up to `MediaScanner.maxEndAttempts`;
  /// - **Keep on:** `PhoneStateRepository.markStillAnswered`.
  ///
  /// Then the action is cleared by the time of its tap, so a newer tap
  /// stays. An action for another session (Shooting mode was turned off, or
  /// off and on again, since the notification was posted) is only cleared.
  /// It throws when the phone does not answer; the action then stays.
  Future<void> apply() => _scanner.applyShadeAction();
}

/// The one [ShadeActions].
@Riverpod(keepAlive: true)
ShadeActions shadeActions(Ref ref) =>
    ShadeActions(ref.watch(mediaScannerProvider));
