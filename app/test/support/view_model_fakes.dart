import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/platform/background_bridge.dart';

/// The view a phone with [level] has (the banner rule, D-75, with access that
/// was never full before).
MediaAccessView accessView(MediaAccessLevel level) => MediaAccessView(
  level: level,
  banner: switch (level) {
    MediaAccessLevel.full => AccessBanner.none,
    MediaAccessLevel.limited => AccessBanner.manual,
    MediaAccessLevel.denied => AccessBanner.lost,
  },
  canAskAgain: true,
);

/// A [MediaAccessController] that shows [level] (null: the first read
/// failed), counts the Allow taps, and shows what a test pushes with [show].
class FakeAccess extends MediaAccessController {
  FakeAccess(this.level);

  final MediaAccessLevel? level;
  int allowed = 0;

  @override
  Future<MediaAccessView> build() async {
    final l = level;
    if (l == null) throw StateError('the first read failed');
    return accessView(l);
  }

  @override
  Future<void> allow() async => allowed++;

  void show(MediaAccessLevel l) => state = AsyncData(accessView(l));
}

/// A [NotificationAccessController] that shows [access] (null: the first
/// read failed; [loading]: the first read never ends), counts the Allow taps
/// and answers them with [allowResult], and shows what a test pushes with
/// [show].
class FakeNotificationAccess extends NotificationAccessController {
  FakeNotificationAccess(
    this.access, {
    this.allowResult = true,
    this.loading = false,
  });

  final NotificationAccess? access;
  final bool loading;
  bool allowResult;
  int allowed = 0;

  @override
  Future<NotificationAccess> build() {
    if (loading) return Completer<NotificationAccess>().future;
    final a = access;
    if (a == null) return Future.error(StateError('the first read failed'));
    return Future.value(a);
  }

  @override
  Future<bool> allow() async {
    allowed++;
    return allowResult;
  }

  void show(NotificationAccess a) => state = AsyncData(a);
}

/// A [ShootingModeController] that starts at [initial], shows what a test
/// pushes into [states], and records the switch and the camera button.
class FakeShooting extends ShootingModeController {
  /// [cameraOpens] false: no camera app can open, as on a phone without one.
  FakeShooting(this.initial, {this.cameraOpens = true});

  final ShootingState initial;
  final bool cameraOpens;
  final StreamController<ShootingState> states = StreamController.broadcast();
  final List<bool> switched = [];
  int cameraOpened = 0;

  @override
  Stream<ShootingState> build() async* {
    yield initial;
    yield* states.stream;
  }

  @override
  Future<void> setOn(bool on) async => switched.add(on);

  @override
  Future<bool> openCamera() async {
    cameraOpened++;
    return cameraOpens;
  }
}

/// A [ToTagController] that shows what a test pushes into [clips] (nothing at
/// first: still loading), without scanning, and counts [onResume] calls.
class FakeToTag extends ToTagController {
  FakeToTag([List<Clip>? first]) : _first = first;

  final List<Clip>? _first;
  final StreamController<List<Clip>> clips = StreamController.broadcast();
  int resumes = 0;

  @override
  Stream<List<Clip>> build() async* {
    final first = _first;
    if (first != null) yield first;
    yield* clips.stream;
  }

  @override
  Future<void> onResume() async => resumes++;
}
