import 'dart:async';

import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_api.g.dart';

part 'background_bridge.freezed.dart';
part 'background_bridge.g.dart';

/// What the Android code that runs while TakeTray is closed needs to know
/// (D-103): the new-clips job and the reminders.
///
/// Dart is the truth. Kotlin keeps this as a mirror, re-written at every app
/// start and on every change, and never writes the database.
///
/// - [since] is when Shooting mode was switched on (null while off);
///   [baselines] holds where each volume's scan stopped, by volume name.
/// - [watchedFolders] are the folders the job counts in.
/// - [waitingShots] are when the clips waiting in To tag were shot (their
///   `dateTakenUtc`); the bridge sends them in ascending order.
/// - [eveningMinutes] is the evening reminder's local time, in minutes after
///   midnight (0 to 1439).
/// - [stillAnswered] is true once "Still shooting?" was answered in this
///   Shooting mode session.
@freezed
abstract class BackgroundState with _$BackgroundState {
  const factory BackgroundState({
    required bool shootingOn,
    required DateTime? since,
    required Map<String, VolumeBaseline> baselines,
    required List<String> watchedFolders,
    required List<DateTime> waitingShots,
    required bool eveningEnabled,
    required int eveningMinutes,
    required bool stillReminderEnabled,
    required bool stillAnswered,
  }) = _BackgroundState;
}

/// The two "Still shooting?" buttons in the notification shade.
enum ShadeActionKind { turnOff, keepOn }

/// A "Still shooting?" button tapped in the shade while the app was closed.
///
/// [since] names the Shooting mode session it was for: Dart applies it only
/// if that is still the stored session. [at] is when it was tapped (UTC) and
/// identifies it for `clearShadeAction`. [generations] holds each baselined
/// volume's generation at the tap, by volume name (empty for keepOn).
@freezed
abstract class ShadeAction with _$ShadeAction {
  const factory ShadeAction({
    required ShadeActionKind kind,
    required DateTime since,
    required DateTime at,
    required Map<String, int> generations,
  }) = _ShadeAction;
}

/// Whether TakeTray may post notifications.
///
/// [canAsk] is true only when Android would show its permission dialog
/// (Android 13 and later, not granted, not blocked by two denials); otherwise
/// the only way is the app's notification settings. [sdkInt] is the Android
/// API level.
@freezed
abstract class NotificationAccess with _$NotificationAccess {
  const factory NotificationAccess({
    required bool granted,
    required bool canAsk,
    required int sdkInt,
  }) = _NotificationAccess;
}

/// The screen a notification tap opens. An allow-list: never a route.
enum LaunchAction { toTag, reels }

/// What the app asks Android's background side, in domain types (D-103).
///
/// Every call is a [Future]. A failure on the Kotlin side arrives as a
/// `PlatformException`, unchanged, as from `MediaBridge`: the caller decides
/// what to do with it. Tests use `FakeBackgroundBridge` instead of a phone.
/// Never log a folder, a volume version or the phone maker (D-10).
abstract interface class BackgroundBridge {
  /// Stores [state] natively, then arms the job and the reminders for it.
  Future<void> writeState(BackgroundState state);

  /// The shade action waiting for Dart, if any.
  Future<ShadeAction?> pendingShadeAction();

  /// Forgets the stored shade action only if it was tapped at [at]; a newer
  /// one stays.
  Future<void> clearShadeAction(DateTime at);

  /// Removes the new-clips notification (the app has scanned).
  Future<void> clearNewClipsNotification();

  /// Whether notifications are allowed. Asks the user nothing.
  Future<NotificationAccess> notificationAccess();

  /// Shows Android's permission dialog (Android 13 and later) and returns
  /// the answer; below 13 it returns [notificationAccess]'s answer.
  Future<NotificationAccess> requestNotificationAccess();

  /// Opens this app's notification settings.
  Future<void> openNotificationSettings();

  /// The phone's maker, lower-cased (`samsung`, `xiaomi`), for the help
  /// screen. Never logged.
  Future<String> phoneMaker();

  /// Opens the phone's battery settings; false when nothing could be opened.
  Future<bool> openBatterySettings();

  /// The screens notification taps ask for: first the one the app was
  /// started with (if any), then one per tap while the app runs. Meant for
  /// one listener (the router); the start action is taken once.
  Stream<LaunchAction> get launchActions;
}

/// The [BackgroundBridge] that talks to Kotlin through the Pigeon-generated
/// [BackgroundHostApi] and receives taps through [BackgroundFlutterApi]. It
/// only converts between message and domain types.
class PigeonBackgroundBridge implements BackgroundBridge {
  /// [api] defaults to a real [BackgroundHostApi]; tests pass a stub.
  /// [messenger] is the channel for both directions (the default one when
  /// null).
  new({BackgroundHostApi? api, BinaryMessenger? messenger})
    : _api = api ?? BackgroundHostApi(binaryMessenger: messenger),
      _messenger = messenger;

  final BackgroundHostApi _api;
  final BinaryMessenger? _messenger;

  late final StreamController<LaunchAction> _launches =
      StreamController<LaunchAction>.broadcast(onListen: _start);
  bool _started = false;

  /// Taps that arrive while the start action is still being taken: they
  /// follow it. Null once it has arrived.
  List<LaunchAction>? _early;

  @override
  Future<void> writeState(BackgroundState state) => _api.writeState(
    BackgroundStateMsg(
      shootingOn: state.shootingOn,
      sinceMs: state.since?.millisecondsSinceEpoch,
      baselines: [
        for (final name in state.baselines.keys.toList()..sort())
          VolumeBaselineMsg(
            volumeName: name,
            version: state.baselines[name]!.version,
            generation: state.baselines[name]!.generation,
          ),
      ],
      watchedFolders: state.watchedFolders,
      waitingShotMs: [
        for (final shot in state.waitingShots) shot.millisecondsSinceEpoch,
      ]..sort(),
      eveningEnabled: state.eveningEnabled,
      eveningMinutes: state.eveningMinutes,
      stillReminderEnabled: state.stillReminderEnabled,
      stillAnswered: state.stillAnswered,
    ),
  );

  @override
  Future<ShadeAction?> pendingShadeAction() async {
    final msg = await _api.pendingShadeAction();
    if (msg == null) return null;
    return ShadeAction(
      kind: switch (msg.kind) {
        ShadeActionKindMsg.turnOff => ShadeActionKind.turnOff,
        ShadeActionKindMsg.keepOn => ShadeActionKind.keepOn,
      },
      since: _utc(msg.sinceMs),
      at: _utc(msg.atMs),
      generations: {
        for (final g in msg.generations) g.volumeName: g.generation,
      },
    );
  }

  @override
  Future<void> clearShadeAction(DateTime at) =>
      _api.clearShadeAction(at.millisecondsSinceEpoch);

  @override
  Future<void> clearNewClipsNotification() => _api.clearNewClipsNotification();

  @override
  Future<NotificationAccess> notificationAccess() async =>
      _access(await _api.notificationAccess());

  @override
  Future<NotificationAccess> requestNotificationAccess() async =>
      _access(await _api.requestNotificationAccess());

  @override
  Future<void> openNotificationSettings() => _api.openNotificationSettings();

  @override
  Future<String> phoneMaker() => _api.phoneMaker();

  @override
  Future<bool> openBatterySettings() => _api.openBatterySettings();

  @override
  Stream<LaunchAction> get launchActions => _launches.stream;

  /// On the first listen: set up the Flutter API, then take the start
  /// action. Kotlin sends taps through the Flutter API only after that take,
  /// so none is lost; any that arrive before its answer follow it.
  void _start() {
    if (_started) return;
    _started = true;
    _early = [];
    BackgroundFlutterApi.setUp(
      _TapListener(_onTap),
      binaryMessenger: _messenger,
    );
    unawaited(_takeStartAction());
  }

  Future<void> _takeStartAction() async {
    try {
      final start = await _api.takeLaunchAction();
      if (start != null) _launches.add(_launchAction(start));
    } on Object catch (e, stack) {
      _launches.addError(e, stack);
    } finally {
      final early = _early ?? const [];
      _early = null;
      early.forEach(_launches.add);
    }
  }

  void _onTap(LaunchAction action) {
    final early = _early;
    if (early != null) {
      early.add(action);
    } else {
      _launches.add(action);
    }
  }

  /// Stops receiving taps (the provider is disposed). Kotlin then keeps a
  /// tap for the next take.
  void dispose() {
    if (_started) {
      BackgroundFlutterApi.setUp(null, binaryMessenger: _messenger);
    }
    unawaited(_launches.close());
  }
}

class _TapListener implements BackgroundFlutterApi {
  _TapListener(this._onTap);

  final void Function(LaunchAction) _onTap;

  @override
  void onLaunchAction(LaunchActionMsg action) => _onTap(_launchAction(action));
}

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

NotificationAccess _access(NotificationAccessMsg msg) => NotificationAccess(
  granted: msg.granted,
  canAsk: msg.canAsk,
  sdkInt: msg.sdkInt,
);

LaunchAction _launchAction(LaunchActionMsg msg) => switch (msg) {
  LaunchActionMsg.toTag => LaunchAction.toTag,
  LaunchActionMsg.reels => LaunchAction.reels,
};

@Riverpod(keepAlive: true)
BackgroundBridge backgroundBridge(Ref ref) {
  final bridge = PigeonBackgroundBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
}
