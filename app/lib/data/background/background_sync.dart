import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/background/shade_actions.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_bridge.dart';

part 'background_sync.g.dart';

// Error types only: never a folder, a volume version, a time or a count of a
// named reel (D-10).
final Logger _log = Logger('backgroundSync');

/// Keeps the phone's copy of the background state (D-103) in step with the
/// database (D-106). Dart is the truth; Kotlin only reads the copy.
///
/// - **What:** a [BackgroundState] made of Shooting mode
///   (`PhoneStateRepository`: on, its start, the baselines, the Still
///   shooting? answer), the settings (`SettingsRepository`: the watched
///   folders, the evening reminder) and when the clips waiting in To tag
///   were shot (`ClipsRepository.pendingShotTimes`). `stillReminderEnabled`
///   is true until Settings has a switch for it (Phase 10).
/// - **When:** [start] follows `watchShooting`, `SettingsRepository.watch`
///   and `watchPendingShotTimes`; each change asks for a write. The state is
///   read from the database when the write starts, so a write never carries
///   a value older than the database, even when one stream delivers before
///   another.
/// - **Only a change:** a state equal to the last one written is not written
///   again; the first one after [start] always is (every app start re-arms
///   the job and the alarms).
/// - **One at a time:** while a write runs, any number of changes cost one
///   more write after it, of the newest state.
/// - **A shade action first:** before each write, [ShadeActions.apply] runs.
///   A Turn off tapped while the app is open has written the copy "off";
///   writing the database's "on" over it would re-arm the job. Applying it
///   first ends the session, and the write says off. Its own changes to the
///   database ask for one more write, which finds the action gone and the
///   state already written, so it does not loop. While a Turn off for the
///   current session is still waiting (its end failed, or could not run),
///   the copy is written off.
/// - **Errors:** a failed apply is logged by type and the write goes on
///   (off while a Turn off waits); a failed read or write is logged by type
///   and nothing is marked written, so the next change (or [flush]) tries
///   again. When the action cannot be read, nothing is written.
class BackgroundSync {
  new(this._bridge, this._phone, this._settings, this._clips, this._shade);

  final BackgroundBridge _bridge;
  final PhoneStateRepository _phone;
  final SettingsRepository _settings;
  final ClipsRepository _clips;
  final ShadeActions _shade;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _started = false;
  bool _disposed = false;

  /// The last state the phone took, or null: none yet, or the last write
  /// failed (the phone may hold part of it), so the next one is written.
  BackgroundState? _written;

  /// The write loop: running, and asked for one more pass.
  Completer<void>? _idle;
  bool _again = false;

  /// Follows the database from now on. Called once, at app start
  /// (`TakeTrayApp`); a second call does nothing.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscriptions.addAll([
      _phone.watchShooting().listen((_) => _request(), onError: _streamError),
      _settings.watch().listen((_) => _request(), onError: _streamError),
      _clips.watchPendingShotTimes().listen(
        (_) => _request(),
        onError: _streamError,
      ),
    ]);
  }

  /// Writes the database's state now, if the phone does not have it yet,
  /// and completes once the newest state is written (or its write failed
  /// and was logged; it never throws).
  ///
  /// It reads the database itself, so it does not wait for the streams:
  /// after a scan, the lifecycle flushes before it removes the new-clips
  /// notification, so the job never counts with the old baselines.
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    _request();
    return _idle?.future ?? Future<void>.value();
  }

  /// Stops following the database. A write already running finishes.
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }

  void _streamError(Object error) =>
      _log.warning('Following the database failed: ${error.runtimeType}');

  /// Starts the write loop, or asks the running one for one more pass.
  void _request() {
    if (_idle != null) {
      _again = true;
      return;
    }
    _idle = Completer<void>();
    unawaited(_loop());
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await _writeOnce();
      } while (_again && !_disposed);
    } finally {
      final idle = _idle!;
      _idle = null;
      idle.complete();
    }
  }

  Future<void> _writeOnce() async {
    try {
      try {
        await _shade.apply();
      } on Object catch (e) {
        _log.warning('Applying the shade action failed: ${e.runtimeType}');
      }
      // A Turn off the apply could not finish (a volume did not answer)
      // stays waiting: the copy says off meanwhile, as the shade wrote it.
      final waiting = await _bridge.pendingShadeAction();
      final shooting = await _phone.loadShooting();
      var state = await _read(shooting);
      if (waiting?.kind == ShadeActionKind.turnOff &&
          shooting.isSession(waiting!.since)) {
        state = state.copyWith(
          shootingOn: false,
          since: null,
          baselines: const {},
          stillAnswered: false,
        );
      }
      if (state == _written) return;
      _written = null;
      await _bridge.writeState(state);
      _written = state;
      _log.fine('Wrote the background copy');
    } on Object catch (e) {
      _log.warning('Writing the background copy failed: ${e.runtimeType}');
    }
  }

  Future<BackgroundState> _read(ShootingState shooting) async {
    final settings = await _settings.load();
    final shots = await _clips.pendingShotTimes();
    return BackgroundState(
      shootingOn: shooting.on,
      since: shooting.on ? shooting.since : null,
      baselines: shooting.on ? shooting.baselines : const {},
      watchedFolders: settings.watchedFolders,
      waitingShots: shots,
      eveningEnabled: settings.eveningReminderEnabled,
      eveningMinutes: settings.eveningReminderMinutes,
      // Settings has no switch for it until Phase 10.
      stillReminderEnabled: true,
      stillAnswered: shooting.on && shooting.stillAnswered,
    );
  }
}

/// The one [BackgroundSync]. Kept alive: it follows the database for the
/// app's lifetime once `TakeTrayApp` starts it.
@Riverpod(keepAlive: true)
BackgroundSync backgroundSync(Ref ref) {
  final sync = BackgroundSync(
    ref.watch(backgroundBridgeProvider),
    ref.watch(phoneStateRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(clipsRepositoryProvider),
    ref.watch(shadeActionsProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
}
