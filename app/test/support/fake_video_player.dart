import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// One player the fake platform made.
class FakePlayer {
  FakePlayer(this.id, this.uri) : events = StreamController<VideoEvent>();

  final int id;

  /// The address it was asked to play (`content://...`).
  final String? uri;

  final StreamController<VideoEvent> events;

  bool disposed = false;
  bool playing = false;
  double volume = 1;
  bool looping = false;
  Duration position = Duration.zero;

  /// The positions it was asked to seek to, in order.
  final List<Duration> seeks = [];
}

/// A [VideoPlayerPlatform] with no player behind it, for tests (the unit and
/// widget tests never touch ExoPlayer; Patrol proves real playback).
///
/// - Every `create` makes a [FakePlayer] in [players]. It reports
///   `initialized` with [duration] at once, unless the address is in
///   [failUris] (an error, as a video the phone cannot decode gives) or
///   [hold] is true (it never initializes).
/// - [calls] logs `create`, `play`, `pause`, `seekTo`, `setVolume`,
///   `setLooping` and `dispose` as `name:playerId`, in order.
/// - [live] is the players not disposed yet: a leak shows here.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  /// Installs a fresh fake as the platform for the rest of the test, and
  /// puts the old one back when it ends.
  factory install() {
    final previous = VideoPlayerPlatform.instance;
    final fake = FakeVideoPlayerPlatform._();
    VideoPlayerPlatform.instance = fake;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    return fake;
  }

  FakeVideoPlayerPlatform._();

  /// How long every video is.
  Duration duration = const Duration(seconds: 10);

  /// The size every video reports (a vertical phone video by default; a
  /// horizontal test sets 1920 x 1080).
  Size size = const Size(1080, 1920);

  /// Addresses whose player reports an error instead of initializing.
  final Set<String> failUris = {};

  /// Never initialize (a slow open).
  bool hold = false;

  final List<FakePlayer> players = [];
  final List<String> calls = [];

  List<FakePlayer> get live => [
    for (final p in players)
      if (!p.disposed) p,
  ];

  /// The addresses asked for, in order.
  List<String?> get uris => [for (final p in players) p.uri];

  FakePlayer player(int id) => players.firstWhere((p) => p.id == id);

  /// Makes player [id] report an error now, as ExoPlayer does mid-play.
  void failPlayer(int id, [String message = 'decoder error']) =>
      player(id).events
          .addError(PlatformException(code: 'E', message: message));

  /// Makes player [id] report that it reached the end.
  void complete(int id) =>
      player(id).events.add(VideoEvent(eventType: VideoEventType.completed));

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final player = FakePlayer(players.length + 1, options.dataSource.uri);
    players.add(player);
    calls.add('create:${player.id}');
    if (failUris.contains(player.uri)) {
      player.events.addError(
        PlatformException(code: 'VideoError', message: 'Source error'),
      );
    } else if (!hold) {
      player.events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: duration,
          size: size,
        ),
      );
    }
    return player.id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      player(playerId).events.stream;

  @override
  Future<void> dispose(int playerId) async {
    final p = player(playerId)
      ..disposed = true
      ..playing = false;
    calls.add('dispose:$playerId');
    await p.events.close();
  }

  @override
  Future<void> play(int playerId) async {
    player(playerId).playing = true;
    calls.add('play:$playerId');
  }

  @override
  Future<void> pause(int playerId) async {
    player(playerId).playing = false;
    calls.add('pause:$playerId');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    player(playerId).volume = volume;
    calls.add('setVolume:$playerId:$volume');
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    player(playerId).looping = looping;
    calls.add('setLooping:$playerId:$looping');
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    player(playerId)
      ..position = position
      ..seeks.add(position);
    calls.add('seekTo:$playerId');
  }

  @override
  Future<Duration> getPosition(int playerId) async => player(playerId).position;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      _picture(options.playerId);

  @override
  Widget buildView(int playerId) => _picture(playerId);

  /// A surface for the "picture": a gradient that differs by player, so a
  /// golden shows where the video is. Tests find it by its key.
  Widget _picture(int playerId) {
    const colors = [
      [Color(0xFF3A6EA5), Color(0xFF1B2A41)],
      [Color(0xFFC06C3A), Color(0xFF3B1F14)],
      [Color(0xFF4F8F6B), Color(0xFF13261C)],
    ];
    final pair = colors[playerId % colors.length];
    return SizedBox.expand(
      key: ValueKey('fake-video-$playerId'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pair,
          ),
        ),
      ),
    );
  }
}
