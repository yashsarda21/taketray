import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/still_shooting.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/platform/background_bridge.dart';

part 'still_shooting_prompt.g.dart';

// Error types only: never a time or a session (D-10).
final Logger _log = Logger('stillShooting');

/// The in-app "Still shooting?" question (D-107): whether to ask now, and what
/// the two answers do.
///
/// **When:** [claim] gives the Shooting mode session to ask about, at most
/// once per app session (this process), and only when
/// - `stillShootingDue`: on, not answered, at least 14 days;
/// - no shade button for this session is waiting. The phone may have posted
///   the "Still shooting?" notification at about the same time as the app
///   started; if the user answered it first, that answer is a shade action
///   that the scan has not applied yet, and asking again would be a double
///   prompt. A shade action for an older session is not an answer to this
///   one. When the waiting action cannot be read, nothing is asked: the next
///   check tries again.
///
/// The shade action is read first and the state after it. The scan applies
/// an action by storing it and then clearing it, so an action that was just
/// cleared has already changed the state this check reads next.
///
/// **The other order:** a question answered here goes through
/// [keepOn] (`markStillAnswered`) or [turnOff]; `BackgroundSync` then writes
/// `stillAnswered` or "off" to the phone's copy, and the phone cancels its
/// notification (D-105, D-106).
///
/// A claim that was not used (the screen was gone before the dialog opened)
/// is given back with [release]. Two checks at the same moment give it to
/// one. No method throws.
class StillShootingPrompt {
  new(this._ref);

  final Ref _ref;

  /// Whether a dialog was claimed in this app session, and not given back.
  bool _claimed = false;

  /// Whether a [claim] is running.
  bool _checking = false;

  /// The session to ask about now, or null: not due, answered in the shade,
  /// already asked in this app session, or a check is running.
  Future<DateTime?> claim() async {
    if (_claimed || _checking) return null;
    _checking = true;
    try {
      final now = _ref.read(clockProvider).now();
      // The controller's state is the cheap first look; the database decides.
      final shown = await _firstLook();
      if (!stillShootingDue(shown, now)) return null;

      final bridge = _ref.read(backgroundBridgeProvider);
      final ShadeAction? waiting;
      try {
        waiting = await bridge.pendingShadeAction();
      } on Object catch (error) {
        _log.warning(
          'Reading the shade action failed: ${error.runtimeType}; not asking',
        );
        return null;
      }
      final current = await _ref
          .read(phoneStateRepositoryProvider)
          .loadShooting();
      final since = current.since;
      if (since == null || !stillShootingDue(current, now)) return null;
      if (waiting != null && current.isSession(waiting.since)) {
        _log.info('Still shooting? was answered in the shade; not asking');
        return null;
      }
      _claimed = true;
      return since;
    } on Object catch (error) {
      _log.warning('The Still shooting? check failed: ${error.runtimeType}');
      return null;
    } finally {
      _checking = false;
    }
  }

  /// Shooting mode as the controller has it, waiting for its first value. The
  /// listener keeps the stream running meanwhile: a provider nobody listens
  /// to is paused, and its first value would never come.
  Future<ShootingState> _firstLook() async {
    final subscription = _ref.listen(shootingModeControllerProvider, (_, _) {});
    try {
      return await _ref.read(shootingModeControllerProvider.future);
    } finally {
      subscription.close();
    }
  }

  /// Gives back the claim of [claim], when its dialog was not shown.
  void release() => _claimed = false;

  /// "Keep it on" (and Back, and a tap outside): the session that started at
  /// [since] is answered, so the phone's notification goes away and nothing
  /// asks again in it.
  Future<void> keepOn(DateTime since) => guarded(
    _log,
    'Storing Keep it on',
    () => _ref.read(phoneStateRepositoryProvider).markStillAnswered(since),
  );

  /// "Turn off": Shooting mode off, as the switch on the Reels screen does.
  ///
  /// Returns whether Shooting mode is off now. `setOn` never throws (it logs
  /// a failure and leaves the stored state), so the outcome is read back from
  /// the database: the screen must not say "off" about a Shooting mode that
  /// is still on. A read that fails counts as not off.
  Future<bool> turnOff() async {
    final off = await guarded(
      _log,
      'Turning off from Still shooting?',
      () async {
        await _ref.read(shootingModeControllerProvider.notifier).setOn(false);
        return !(await _ref.read(phoneStateRepositoryProvider).loadShooting())
            .on;
      },
    );
    return off ?? false;
  }
}

/// The one [StillShootingPrompt], for the whole app session: it remembers
/// that the question was asked.
@Riverpod(keepAlive: true)
StillShootingPrompt stillShootingPrompt(Ref ref) => StillShootingPrompt(ref);
