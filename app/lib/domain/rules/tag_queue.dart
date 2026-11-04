import 'package:flutter/foundation.dart';

/// The order the tag player walks through (D-95).
///
/// The session is the clips that were in To tag when "Start tagging" was
/// tapped, in shooting order, **fixed for the whole session**. Positions are
/// indexes into it. What changes while the player is open is which of those
/// clips are still waiting, so the methods take that as `pending`, a set of
/// **clip ids** (the clips still in To tag). A clip tagged or skipped, from
/// the player or from somewhere else, drops out of `pending` and is passed
/// over. A clip that arrives later is not in the session and is never shown.
///
/// Every method returns an index into the session, or null.
@immutable
class TagQueue {
  /// [session] is copied; later changes to the given list do not affect the
  /// queue.
  TagQueue(List<int> session) : session = List.unmodifiable(session);

  /// The clip ids, in the order they are shown.
  final List<int> session;

  /// The nearest pending index after [from], or null when there is none
  /// ("Next clip" is then disabled). [from] may be any int, even outside the
  /// session.
  int? next(int from, Set<int> pending) {
    for (var i = from < -1 ? 0 : from + 1; i < session.length; i++) {
      if (pending.contains(session[i])) return i;
    }
    return null;
  }

  /// The nearest pending index before [from], or null when there is none
  /// ("Previous clip" is then disabled).
  int? previous(int from, Set<int> pending) {
    for (
      var i = from > session.length ? session.length - 1 : from - 1;
      i >= 0;
      i--
    ) {
      if (pending.contains(session[i])) return i;
    }
    return null;
  }

  /// Where the player goes after a tag or a skip of the clip at [from]
  /// (the prototype's `advance`): the next pending clip after it; when there
  /// is none, the first pending clip from the start of the session (a clip
  /// the user went back past); and null when nothing is pending, which is
  /// the done screen.
  ///
  /// [pending] must already leave out the clip just tagged or skipped:
  /// otherwise, as the only pending clip, it would be picked again by the
  /// wrap to the start.
  int? afterAction(int from, Set<int> pending) =>
      next(from, pending) ?? next(-1, pending);
}
