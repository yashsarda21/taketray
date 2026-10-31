import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/scenes.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/domain/rules/tag_queue.dart';
import 'package:taketray/features/tagging/view_models/last_tags.dart';
import 'package:taketray_ui/taketray_ui.dart' show TtMotion;

part 'tag_session_controller.freezed.dart';
part 'tag_session_controller.g.dart';

// Ids and counts only, never a reel name or anything about a video (D-10).
final Logger _log = Logger('tagSession');

/// How long a tapped chip shows its check before the tag is written (D-96):
/// the `medium4` motion token, 400 ms, the prototype's `chip` delay. A
/// second tap in that time is ignored, and closing the player in it tags
/// nothing.
final Duration tagHold = TtMotion.standardSet.medium4;

/// [tagHold] when the phone asks to remove animations (the prototype's
/// reduced-motion delay): still a short wait, so the check is seen before
/// the clip changes.
// style-check: allow a wait before a write, not an animation (prototype chip)
const Duration tagHoldReduced = Duration(milliseconds: 120);

/// Makes the timer of a chip's hold. A provider so a test can hold the time
/// still and end the hold when it wants.
typedef HoldTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// The real timer.
@Riverpod(keepAlive: true)
HoldTimerFactory holdTimer(Ref ref) => Timer.new;

/// What a tag or a skip did, for its snack (D-96): "Added to {names}" or
/// "Skipped", each with Undo. Only the latest action's snack offers Undo.
@immutable
class TagOutcome {
  TagOutcome({
    required List<UndoRecord> records,
    required List<int> reelIds,
    required List<String> reelNames,
    required this.clipId,
    required this.skipped,
  }) : records = List.unmodifiable(records),
       reelIds = List.unmodifiable(reelIds),
       reelNames = List.unmodifiable(reelNames);

  /// What Undo hands back to [TagSessionController.undo]: one `AddUndo` for
  /// each reel of a tag (undone last to first, in one transaction), or the
  /// `InboxUndo` of a skip.
  final List<UndoRecord> records;

  /// The reels the clip went into, in the order they were chosen (empty for
  /// a skip).
  final List<int> reelIds;

  /// Their names, in the same order: the snack's `{names}`.
  final List<String> reelNames;

  /// The clip the action was about: the one showing when it was tapped.
  final int clipId;

  /// Whether this was a skip ("Skipped") rather than a tag.
  final bool skipped;
}

/// What the tag player shows (D-96).
@freezed
abstract class TagSessionState with _$TagSessionState {
  const factory TagSessionState({
    /// The clips that were in To tag when the player opened, in shooting
    /// order. Fixed for the session: clips that arrive later are not in it.
    required List<int> session,

    /// The clip showing, an index into [session].
    @Default(0) int index,

    /// "Pick several" is on. Sticky: it stays on from clip to clip until the
    /// user turns it off (owner ruling, D-91).
    @Default(false) bool multi,

    /// The reels picked for the clip showing, in the order picked. Cleared at
    /// every new clip.
    @Default(<int>[]) List<int> picked,

    /// The reel whose chip was just tapped, during its hold (the chip shows
    /// a check). Null otherwise.
    int? confirmingReelId,

    /// A write is running (a tag, a skip, a new reel, an Undo).
    @Default(false) bool busy,

    /// Nothing in the session is waiting any more: "All done!".
    @Default(false) bool done,

    /// How many clips this session put into each reel, by reel id (the done
    /// screen's "+{n}" rows).
    @Default(<int, int>{}) Map<int, int> taggedPerReel,

    /// How many clips this session skipped.
    @Default(0) int skipped,

    /// The clip of the last tag or skip.
    int? lastActedClipId,

    /// The ids of [session] still in To tag.
    @Default(<int>{}) Set<int> pending,

    /// The session's clips by id. A waiting clip's row is refreshed at each
    /// change of To tag, so the player plays it from its current identity.
    @Default(<int, Clip>{}) Map<int, Clip> clips,

    /// The time where each clip was shot (D-83), once `ClipTimeService` has
    /// answered; empty until then.
    @Default(<int, ClipLocalTime>{}) Map<int, ClipLocalTime> times,

    /// All the session's clips in scenes (D-95), also the ones that have
    /// left To tag. Until [times] arrive they use the phone's time.
    @Default(<Scene>[]) List<Scene> scenes,
  }) = _TagSessionState;

  const TagSessionState._();

  /// The id of the clip showing, or null when the session is done.
  int? get currentClipId => done || session.isEmpty ? null : session[index];

  /// The clip showing, or null when the session is done.
  Clip? get currentClip => clips[currentClipId];

  /// Whether a waiting clip comes before the one showing ("Previous clip").
  bool get hasPrevious =>
      !done && TagQueue(session).previous(index, pending) != null;

  /// Whether a waiting clip comes after the one showing ("Next clip").
  bool get hasNext => !done && TagQueue(session).next(index, pending) != null;

  /// How many of the session's clips have left To tag: "{n} clips sorted".
  int get sortedCount => session.length - pending.length;

  /// The scene of the clip at [index] (D-95): "Scene {number} of {total}"
  /// and the scene itself (for its time range). Null for an index outside
  /// the session.
  (int number, int total, Scene scene)? sceneOf(int index) {
    if (index < 0 || index >= session.length) return null;
    final id = session[index];
    for (var i = 0; i < scenes.length; i++) {
      if (scenes[i].clips.any((clip) => clip.id == id)) {
        return (i + 1, scenes.length, scenes[i]);
      }
    }
    return null;
  }
}

/// What one tag or skip of this session counted, so its Undo can take it
/// back once.
class _Counted {
  _Counted({required this.reelIds, required this.skip, this.lastTags});

  final List<int> reelIds;
  final bool skip;

  /// "Same as previous" before the tag and the list the tag stored (null
  /// for a skip).
  final (List<int> before, List<int> after)? lastTags;
}

/// The tag player's session (D-96): the clips to tag, one at a time, and
/// what each tap does.
///
/// - **The session is fixed when the player opens:** the clips in To tag
///   then, in shooting order (`inShootingOrder`), starting at
///   `startClipId` (or the first). Clips that arrive later are not in it. A
///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
///   by a verify) is passed over (`TagQueue`, D-95).
/// - **One action at a time, on the clip that was showing.** Every action
///   reads the clip's id and position **before** it awaits anything, and is
///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
///   second tap in the hold does nothing, and closing the player in the
///   hold cancels it and tags nothing.
/// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
///   waiting clip, else the first one from the start, else done), clears the
///   picks and keeps "Pick several" on.
/// - **Undo** waits for the action that is running, puts the records back in
///   one transaction and returns to that clip (owner ruling, D-91), also
///   after "All done!".
/// - **The clip showing leaving To tag** without this controller acting (a
///   verify, a tag from elsewhere, also during a hold) moves the player on,
///   as after an action. While a write runs, the action moves it instead.
/// - **A failure** leaves the clip showing, clears `busy` and is thrown to
///   the screen ("Something went wrong. Try again.").
///
/// Auto-disposes with the player's route.
@Riverpod(retry: noRetry)
class TagSessionController extends _$TagSessionController {
  late ClipsRepository _clips;
  late ReelsRepository _reels;
  late LastTags _lastTags;
  late TagQueue _queue;
  late List<Clip> _latest;

  /// The action running (a hold and its write, a write, an Undo), or null.
  Completer<void>? _running;

  /// The chip hold while it lasts, and what its tap waits for.
  Timer? _hold;
  Completer<TagOutcome?>? _holdResult;

  /// What each record of this session counted, by identity.
  final Map<UndoRecord, _Counted> _counted = Map.identity();

  @override
  Future<TagSessionState> build(int? startClipId) async {
    _clips = ref.watch(clipsRepositoryProvider);
    _reels = ref.watch(reelsRepositoryProvider);
    _lastTags = ref.read(lastTagsProvider.notifier);
    final first = Completer<void>();
    final watch = _clips
        .watchInbox(InboxState.pending)
        .listen(
          (waiting) {
            _latest = waiting;
            if (!first.isCompleted) {
              first.complete();
            } else {
              _onPending(waiting);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!first.isCompleted) {
              first.completeError(error, stack);
            } else {
              _log.warning('Watching To tag failed: ${error.runtimeType}');
            }
          },
        );
    ref.onDispose(() {
      unawaited(watch.cancel());
      _cancelHold();
    });
    await first.future;

    final waiting = inShootingOrder(_latest);
    final session = [for (final clip in waiting) clip.id];
    _queue = TagQueue(session);
    final at = startClipId == null ? -1 : session.indexOf(startClipId);
    unawaited(_loadTimes(waiting));
    _log.info('Tagging ${session.length} clips');
    return TagSessionState(
      session: session,
      index: at < 0 ? 0 : at,
      done: session.isEmpty,
      pending: session.toSet(),
      clips: {for (final clip in waiting) clip.id: clip},
      scenes: groupIntoScenes(waiting, const {}),
    );
  }

  // ---------------------------------------------------------------- actions

  /// The chip of reel [reelId] was tapped (not in "Pick several"): it shows
  /// a check for the hold ([reducedMotion]: `MediaQuery.disableAnimations`),
  /// then the clip that was showing goes into that reel. Completes with the
  /// outcome, or with null when the tap was ignored or the player closed in
  /// the hold.
  Future<TagOutcome?> tapReel(int reelId, {bool reducedMotion = false}) {
    final s = _idle();
    if (s == null || s.multi) return Future.value();
    final clipId = s.session[s.index];
    final from = s.index;
    _begin();
    _set(s.copyWith(confirmingReelId: reelId));
    final result = _holdResult = Completer<TagOutcome?>();
    _hold = ref.read(holdTimerProvider)(
      reducedMotion ? tagHoldReduced : tagHold,
      () {
        _hold = null;
        _holdResult = null;
        result.complete(_tag(clipId, from, (_) => [reelId]));
      },
    );
    return result.future;
  }

  /// A chip was pressed and held: "Pick several" turns on with that reel
  /// picked.
  void longPressReel(int reelId) {
    final s = _idle();
    if (s == null) return;
    _set(s.copyWith(multi: true, picked: [reelId]));
  }

  /// Turns "Pick several" on or off (Cancel). Either way the picks go.
  // The switch's value, as the Task 7 contract names it.
  // ignore: avoid_positional_boolean_parameters
  void setMulti(bool on) {
    final s = _idle();
    if (s == null) return;
    _set(s.copyWith(multi: on, picked: const []));
  }

  /// Picks or unpicks reel [reelId] in "Pick several".
  void togglePick(int reelId) {
    final s = _idle();
    if (s == null || !s.multi) return;
    final picked = [...s.picked];
    if (!picked.remove(reelId)) picked.add(reelId);
    _set(s.copyWith(picked: picked));
  }

  /// "Add to {k} reels & next": the clip showing goes into every picked
  /// reel, in one transaction. Null when nothing is picked.
  Future<TagOutcome?> confirmPicks() {
    final s = _idle();
    if (s == null || !s.multi || s.picked.isEmpty) return Future.value();
    final picked = s.picked;
    _begin();
    return _tag(s.session[s.index], s.index, (_) => picked);
  }

  /// "Same as previous": the clip showing goes into the reels of the last
  /// tag that still exist. Null (nothing happens) when there are none.
  Future<TagOutcome?> sameAsPrevious() {
    final s = _idle();
    if (s == null) return Future.value();
    final last = ref.read(lastTagsProvider);
    if (last.isEmpty) return Future.value();
    _begin();
    return _tag(
      s.session[s.index],
      s.index,
      (existing) => [
        for (final id in last)
          if (existing.contains(id)) id,
      ],
    );
  }

  /// "Skip": the clip showing goes to Skipped.
  Future<TagOutcome?> skip() {
    final s = _idle();
    if (s == null) return Future.value();
    final clipId = s.session[s.index];
    _begin();
    return _act(clipId, s.index, () async {
      final record = await _clips.skipClips([clipId]);
      _counted[record] = _Counted(reelIds: const [], skip: true);
      _log.info('Skipped clip $clipId');
      return TagOutcome(
        records: [record],
        reelIds: const [],
        reelNames: const [],
        clipId: clipId,
        skipped: true,
      );
    });
  }

  /// "Previous clip": the nearest waiting clip before this one, untagged.
  void previous() => _moveTo(_queue.previous);

  /// "Next clip": the nearest waiting clip after this one, untagged.
  void next() => _moveTo(_queue.next);

  /// "+ New reel" from the player: creates the reel [name], then picks it in
  /// "Pick several" (and returns null) or tags the clip showing into it. A
  /// name that is not acceptable throws `InvalidInputException` for the form
  /// (D-85); nothing is created and nothing moves.
  Future<TagOutcome?> createReelAndTag(String name) async {
    final s = _idle();
    if (s == null) return null;
    _begin();
    if (!s.multi) {
      return await _tag(
        s.session[s.index],
        s.index,
        (_) => const [],
        create: name,
      );
    }
    _set(s.copyWith(busy: true));
    try {
      final reel = await _reels.create(name);
      _log.info('Created reel ${reel.id} to pick');
      _update((now) => now.copyWith(picked: [...now.picked, reel.id]));
      return null;
    } on Object catch (error) {
      _log.warning('Creating a reel to pick failed: ${error.runtimeType}');
      rethrow;
    } finally {
      _update((now) => now.copyWith(busy: false));
      _end();
    }
  }

  /// Undo of a tag or skip of clip [clipId] (its snack's [records]): waits
  /// for the action that is running, puts the records back in one
  /// transaction, and goes back to that clip if it is waiting again, also
  /// after "All done!". A failure is thrown, and nothing moves. After the
  /// player has closed it still undoes (the snack outlives it).
  Future<void> undo(List<UndoRecord> records, int clipId) async {
    // `state` throws once the player has closed: check `ref.mounted` first.
    if (ref.mounted && state.value == null) await future;
    while (_running != null) {
      await _running!.future;
    }
    _begin();
    _update((now) => now.copyWith(busy: true));
    try {
      await _clips.undoAll(records);
      final waiting = await _clips.watchInbox(InboxState.pending).first;
      _log.info('Undid ${records.length} records of clip $clipId');
      _uncount(records);
      _update((now) {
        final pending = _pendingOf(now, waiting);
        final at = now.session.indexOf(clipId);
        if (at >= 0 && pending.contains(clipId)) {
          return now.copyWith(
            pending: pending,
            index: at,
            done: false,
            picked: const [],
          );
        }
        return now.copyWith(pending: pending);
      });
    } on Object catch (error) {
      _log.warning('Undo of clip $clipId failed: ${error.runtimeType}');
      rethrow;
    } finally {
      _update((now) => _followed(now.copyWith(busy: false)));
      _end();
    }
  }

  // ---------------------------------------------------------------- helpers

  /// The state, when an action may start now: the player open, loaded, not
  /// done, nothing running and no chip held. Else null, and the action is
  /// ignored.
  TagSessionState? _idle() {
    // After the player closed, `state` throws; an action then does nothing.
    if (!ref.mounted) return null;
    final s = state.value;
    if (s == null || s.done || s.session.isEmpty) return null;
    if (_running != null || s.busy || s.confirmingReelId != null) return null;
    return s;
  }

  void _begin() => _running = Completer<void>();

  void _end() {
    final running = _running;
    _running = null;
    running?.complete();
  }

  /// Tags clip [clipId] (at [from]) into the reels [choose] picks from the
  /// ids of the reels that exist now; or, with [create], into a reel made
  /// with that name first.
  Future<TagOutcome?> _tag(
    int clipId,
    int from,
    List<int> Function(Set<int> existing) choose, {
    String? create,
  }) => _act(clipId, from, () async {
    final List<int> reelIds;
    final Map<int, String> names;
    if (create != null) {
      final reel = await _reels.create(create);
      _log.info('Created reel ${reel.id} to tag into');
      reelIds = [reel.id];
      names = {reel.id: reel.name};
    } else {
      names = {
        for (final reel in await _reels.watchAll().first) reel.id: reel.name,
      };
      reelIds = choose(names.keys.toSet());
      if (reelIds.isEmpty) return null;
      for (final id in reelIds) {
        if (!names.containsKey(id)) throw StateError('No reel with id $id');
      }
    }
    final records = await _clips.addClipsToReels(reelIds.toSet(), [clipId]);
    final before = _lastTags.current;
    final after = _lastTags.set(reelIds);
    final counted = _Counted(
      reelIds: reelIds,
      skip: false,
      lastTags: (before, after),
    );
    for (final record in records) {
      _counted[record] = counted;
    }
    _log.info('Tagged clip $clipId into ${reelIds.length} reels');
    return TagOutcome(
      records: records,
      reelIds: reelIds,
      reelNames: [for (final id in reelIds) names[id]!],
      clipId: clipId,
      skipped: false,
    );
  });

  /// Runs [write] for clip [clipId] (at [from]) with `busy` on, then counts
  /// it and moves on. The caller began the action; it ends here.
  Future<TagOutcome?> _act(
    int clipId,
    int from,
    Future<TagOutcome?> Function() write,
  ) async {
    _update((now) => now.copyWith(busy: true));
    try {
      final outcome = await write();
      if (outcome != null) _advance(outcome, from);
      return outcome;
    } on Object catch (error) {
      _log.warning('An action on clip $clipId failed: ${error.runtimeType}');
      rethrow;
    } finally {
      _update(
        (now) => _followed(now.copyWith(busy: false, confirmingReelId: null)),
      );
      _end();
    }
  }

  /// After a tag or skip of the clip at [from]: counts it and goes to the
  /// next waiting clip (`afterAction`, given the waiting clips without this
  /// one), or to done.
  void _advance(TagOutcome outcome, int from) {
    _update((now) {
      final pending = {...now.pending}..remove(outcome.clipId);
      final to = _queue.afterAction(from, pending);
      final tagged = {...now.taggedPerReel};
      for (final id in outcome.reelIds) {
        tagged[id] = (tagged[id] ?? 0) + 1;
      }
      return now.copyWith(
        pending: pending,
        index: to ?? now.index,
        done: to == null,
        picked: const [],
        confirmingReelId: null,
        lastActedClipId: outcome.clipId,
        taggedPerReel: tagged,
        skipped: now.skipped + (outcome.skipped ? 1 : 0),
      );
    });
  }

  /// After the Undo of [records]: takes back what this session counted for
  /// them, once, and puts "Same as previous" back unless a later tag has
  /// changed it.
  void _uncount(List<UndoRecord> records) {
    final undone = <_Counted>{};
    for (final record in records) {
      final counted = _counted.remove(record);
      if (counted != null) undone.add(counted);
    }
    if (undone.isEmpty) return;
    for (final counted in undone) {
      final last = counted.lastTags;
      if (last != null) _lastTags.undo(current: last.$2, previous: last.$1);
    }
    _update((now) {
      final tagged = {...now.taggedPerReel};
      var skipped = now.skipped;
      for (final counted in undone) {
        if (counted.skip) skipped--;
        for (final id in counted.reelIds) {
          final n = (tagged[id] ?? 0) - 1;
          if (n > 0) {
            tagged[id] = n;
          } else {
            tagged.remove(id);
          }
        }
      }
      return now.copyWith(taggedPerReel: tagged, skipped: skipped);
    });
  }

  void _moveTo(int? Function(int from, Set<int> pending) find) {
    final s = _idle();
    if (s == null) return;
    final to = find(s.index, s.pending);
    if (to == null) return;
    _set(s.copyWith(index: to, picked: const []));
  }

  /// To tag changed: the session's waiting ids and clip rows follow it, and
  /// the player moves on if the clip showing has left (not while a write
  /// runs: the action moves it then).
  void _onPending(List<Clip> waiting) {
    _update((now) {
      final fresh = {
        for (final clip in waiting)
          if (now.clips.containsKey(clip.id)) clip.id: clip,
      };
      return _followed(
        now.copyWith(
          pending: fresh.keys.toSet(),
          clips: {...now.clips, ...fresh},
        ),
      );
    });
  }

  /// [s], moved on when the clip showing is no longer waiting. Unchanged
  /// while a write runs or once done.
  TagSessionState _followed(TagSessionState s) {
    if (s.done || s.busy || s.session.isEmpty) return s;
    final showing = s.session[s.index];
    if (s.pending.contains(showing)) return s;
    final to = _queue.afterAction(s.index, s.pending);
    _log.info('Clip $showing left To tag; moving on');
    return to == null
        ? s.copyWith(done: true, picked: const [])
        : s.copyWith(index: to, picked: const []);
  }

  Set<int> _pendingOf(TagSessionState s, List<Clip> waiting) {
    final ids = {for (final clip in waiting) clip.id};
    return {
      for (final id in s.session)
        if (ids.contains(id)) id,
    };
  }

  /// Reads the times where the clips were shot, then puts them and the
  /// scenes built with them into the state. The player never waits for it.
  Future<void> _loadTimes(List<Clip> clips) async {
    if (clips.isEmpty) return;
    final service = ref.read(clipTimeServiceProvider);
    try {
      final times = await service.localTimes(clips);
      _update(
        (now) =>
            now.copyWith(times: times, scenes: groupIntoScenes(clips, times)),
      );
    } on Object catch (error) {
      _log.warning('Reading the clip times failed: ${error.runtimeType}');
    }
  }

  /// The player closed: a chip hold ends without a tag.
  void _cancelHold() {
    _hold?.cancel();
    _hold = null;
    final result = _holdResult;
    _holdResult = null;
    if (result != null && !result.isCompleted) {
      result.complete(null);
      _end();
    }
  }

  void _set(TagSessionState s) {
    if (ref.mounted) state = AsyncData(s);
  }

  void _update(TagSessionState Function(TagSessionState now) change) {
    if (!ref.mounted) return;
    final now = state.value;
    if (now != null) state = AsyncData(change(now));
  }
}
