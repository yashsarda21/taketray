import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'last_tags.g.dart';

/// The reels of the last tag, in the order they were chosen (D-96): what
/// "Same as previous" in the tag player offers next.
///
/// Set by every tag of the player and of the reel picker's tag mode. Kept for
/// the app session, never stored: a restart starts with none. A reel deleted
/// since stays in the list; whoever uses it keeps only the ids that still
/// exist (`TagSessionController.sameAsPrevious` does).
@Riverpod(keepAlive: true)
class LastTags extends _$LastTags {
  @override
  List<int> build() => const [];

  /// The last tag's reels, for a holder of the notifier (a controller that
  /// may outlive its own `ref`).
  List<int> get current => state;

  /// Remembers [reelIds] (copied) as the last tag, and returns the list now
  /// held (for [undo]).
  List<int> set(List<int> reelIds) => state = List.unmodifiable(reelIds);

  /// The Undo of the tag that [set] [current]: puts [previous] back, unless
  /// another tag has been remembered since.
  void undo({required List<int> current, required List<int> previous}) {
    if (identical(state, current)) state = previous;
  }
}
