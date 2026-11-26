import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';

part 'earlier_added.g.dart';

/// Whether Add earlier videos added clips while this Shooting mode session
/// was on: the "on" card's **Earlier videos** chip then hides (the handoff,
/// `home-calm-grid.md:46`, and the prototype's `earlierUsed`; D-196, ruling
/// R12B-2).
///
/// - [markAdded] (called by the sheet after an add) sets it.
/// - It clears whenever Shooting mode turns on or off, so a new session shows
///   the chip again, and an add made while it was off (from To tag's menu)
///   never hides the chip of a later session. A new state of the same
///   session (the stored state written again) keeps it.
/// - Undo does not clear it, and it is never stored: a restart shows the chip
///   again. The old stored `earlierAdded` flag (before D-90) is not read.
///
/// Kept alive: Home is not always on screen when the sheet adds (To tag's
/// menu opens it too).
@Riverpod(keepAlive: true)
class EarlierAddedThisSession extends _$EarlierAddedThisSession {
  /// Shooting mode as last known (null until its state is read). A failed or
  /// pending read in between is not a change.
  bool? _on;

  @override
  bool build() {
    _on = ref.read(shootingModeControllerProvider).value?.on;
    ref.listen<AsyncValue<ShootingState>>(shootingModeControllerProvider, (
      _,
      next,
    ) {
      final on = next.value?.on;
      if (on == null || on == _on) return;
      _on = on;
      state = false;
    });
    return false;
  }

  /// Notes that the sheet added clips. It sets the flag whatever Shooting
  /// mode is: the clear on every turn on or off is what limits it to one
  /// session, so an add made while Shooting mode is off is forgotten when it
  /// turns on.
  void markAdded() => state = true;
}
