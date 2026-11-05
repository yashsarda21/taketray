import 'package:meta/meta.dart';

/// How long a re-match window stays open after the rebuild that opened it
/// (D-108). Android re-indexes a volume in minutes; a day is far more than
/// that, and short enough that a clip whose video is really gone stops
/// costing reads soon.
const rematchWindowLength = Duration(hours: 24);

/// The time after a rebuild of a volume's media library in which the scan
/// matches the clips the rebuild could not find again (D-108, I-3).
///
/// A rebuild resync that detaches clips opens one: [openedAt] is the
/// resync's time, [clipIds] the clips it detached, and [generation] the
/// volume's generation when they were last matched against everything on it
/// (the resync's, then each re-match's). The scan matches them again only
/// while the window is open and only when the volume's generation is not
/// [generation]: the same generation means the same videos, so a second read
/// would find nothing new.
@immutable
class RematchWindow {
  RematchWindow({
    required this.openedAt,
    required Set<int> clipIds,
    required this.generation,
  }) : clipIds = Set.unmodifiable(clipIds);

  final DateTime openedAt;
  final Set<int> clipIds;
  final int generation;

  /// Whether the window is open at [now]: from [openedAt] (inclusive) for
  /// [rematchWindowLength] (exclusive). A [now] before [openedAt] (the clock
  /// went back, or a stored time in the future) is closed: a window that
  /// cannot be timed must not stay open for good.
  bool isOpenAt(DateTime now) =>
      !now.isBefore(openedAt) &&
      now.isBefore(openedAt.add(rematchWindowLength));

  @override
  bool operator ==(Object other) =>
      other is RematchWindow &&
      other.openedAt.isAtSameMomentAs(openedAt) &&
      other.generation == generation &&
      other.clipIds.length == clipIds.length &&
      other.clipIds.containsAll(clipIds);

  @override
  int get hashCode => Object.hash(
    openedAt.millisecondsSinceEpoch,
    generation,
    Object.hashAllUnordered(clipIds),
  );

  /// Counts only: a clip id or a time says nothing a log needs (D-10).
  @override
  String toString() =>
      'RematchWindow(${clipIds.length} clips, generation $generation)';
}
