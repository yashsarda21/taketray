import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/rules/shooting_order.dart';

/// Clips shot at least this long apart (end of one to start of the next) are
/// in different scenes (D-95; the prototype's `q.scenes` uses 10 minutes).
const Duration sceneGap = Duration(minutes: 10);

/// A run of clips shot close together: To tag's scene header and the tag
/// player's "Scene s of S" (D-95).
@immutable
class Scene {
  const Scene({
    required this.clips,
    required this.start,
    required this.end,
    required this.day,
  });

  /// The scene's clips in shooting order (never empty).
  final List<Clip> clips;

  /// When the first clip started, as the clock read where it was shot: a
  /// **UTC-flagged** `DateTime` holding wall-clock fields, like
  /// `ClipLocalTime.wallClock`. Never convert it.
  final DateTime start;

  /// When the **last clip started** (not when it ended), in the same
  /// wall-clock form. The header's range is "first start to last start".
  final DateTime end;

  /// The date of [start], as `DateTime.utc(year, month, day)`.
  final DateTime day;
}

/// [clips] grouped into scenes, in shooting order (D-95).
///
/// - The clips are put in shooting order first (`inShootingOrder`: the UTC
///   instant they were taken, then the lower id), so equal times keep id
///   order.
/// - A new scene starts when the next clip starts [gap] or more after the
///   **previous clip ended** (its `dateTakenUtc` plus its `durationMs`), on
///   UTC instants, so a clip in another zone is placed by when it happened.
///   Clips that overlap (a negative gap) stay together. The gap is measured
///   from the clip just before, not from the scene's longest clip.
/// - A new scene also starts when the next clip's calendar day, where it was
///   shot, differs from the previous one's (D-83): a scene never crosses
///   midnight.
/// - A clip missing from [times] uses the phone's local time (Dart's local
///   time) for its day and for [Scene.start] / [Scene.end], written as a
///   UTC-flagged wall clock like the rest, so a clip is never dropped.
List<Scene> groupIntoScenes(
  List<Clip> clips,
  Map<int, ClipLocalTime> times, {
  Duration gap = sceneGap,
}) {
  final scenes = <Scene>[];
  var current = <Clip>[];
  var start = DateTime.utc(0);
  var end = start;
  Clip? previous;
  var previousWall = start;

  void close() {
    if (current.isEmpty) return;
    scenes.add(
      Scene(
        clips: List.unmodifiable(current),
        start: start,
        end: end,
        day: DateTime.utc(start.year, start.month, start.day),
      ),
    );
  }

  for (final clip in inShootingOrder(clips)) {
    final wall = _wallClockOf(clip, times);
    if (previous != null &&
        _startsNewScene(previous, previousWall, clip, wall, gap)) {
      close();
      current = [];
    }
    if (current.isEmpty) start = wall;
    current.add(clip);
    end = wall;
    previous = clip;
    previousWall = wall;
  }
  close();
  return List.unmodifiable(scenes);
}

/// True when [next] is in a different scene from [previous]: [gap] or more
/// between the previous clip's end and its start (UTC), or another shot day.
bool _startsNewScene(
  Clip previous,
  DateTime previousWall,
  Clip next,
  DateTime nextWall,
  Duration gap,
) {
  final previousEnd = previous.fingerprint.dateTakenUtc.add(
    Duration(milliseconds: previous.fingerprint.durationMs),
  );
  final apart = next.fingerprint.dateTakenUtc.difference(previousEnd);
  final sameDay =
      previousWall.year == nextWall.year &&
      previousWall.month == nextWall.month &&
      previousWall.day == nextWall.day;
  return apart >= gap || !sameDay;
}

/// Where [clip] was shot, as a UTC-flagged wall clock: its `ClipLocalTime`
/// when known, else the phone's local time with the same shape.
DateTime _wallClockOf(Clip clip, Map<int, ClipLocalTime> times) {
  final known = times[clip.id]?.wallClock;
  if (known != null) return known;
  final local = clip.fingerprint.dateTakenUtc.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  );
}
