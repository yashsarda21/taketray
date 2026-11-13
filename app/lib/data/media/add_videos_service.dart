import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/library_resync.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/media/zone_sync.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/domain/rules/zone_lookup.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'add_videos_service.g.dart';

// Counts, the kind of target, reel ids and error types only: never a video's
// name, folder or address, nor a reel's name (D-10).
final Logger _log = Logger('addVideos');

/// Where Add videos puts what the user picks.
@immutable
sealed class AddTarget {
  const AddTarget();
}

/// To tag.
final class AddToToTag extends AddTarget {
  const AddToToTag();

  @override
  bool operator ==(Object other) => other is AddToToTag;

  @override
  int get hashCode => (AddToToTag).hashCode;

  @override
  String toString() => 'To tag';
}

/// The reel [reelId].
final class AddToReel extends AddTarget {
  const AddToReel(this.reelId);

  final int reelId;

  @override
  bool operator ==(Object other) =>
      other is AddToReel && other.reelId == reelId;

  @override
  int get hashCode => reelId.hashCode;

  @override
  String toString() => 'reel $reelId';
}

/// Why a video in the folder grid is already added (prototype `markFor`).
enum AddMark { inThisReel, inToTag, inAReel }

/// The mark of a stored clip at [place] for an add to [target], or null when
/// the add would still put it somewhere (D-113), in the prototype's order:
///
/// 1. to a reel it is in: [AddMark.inThisReel];
/// 2. in To tag: [AddMark.inToTag], whatever the target;
/// 3. to To tag, in any reel: [AddMark.inAReel].
///
/// A clip in Skipped has no mark (an add brings it back), nor one only in
/// other reels when the target is a reel (an add links it there too).
AddMark? addMarkFor(ClipPlace place, AddTarget target) {
  if (target case AddToReel(:final reelId)
      when place.reelIds.contains(reelId)) {
    return AddMark.inThisReel;
  }
  if (place.inbox == InboxState.pending) return AddMark.inToTag;
  if (target is AddToToTag && place.reelIds.isNotEmpty) return AddMark.inAReel;
  return null;
}

/// What one add did. Only the three counts are for the screen; the rest is
/// what [AddVideosService.undo] needs.
///
/// [added] videos are now where the add put them, [alreadyThere] were there
/// already (nothing changed), and [notKept] could not be added: a picked
/// video whose read grant Android would not keep, or a folder video that is
/// unfinished, has no length or size, or whose volume is gone.
@immutable
class AddResult {
  const AddResult._(this.added, this.alreadyThere, this.notKept, this._undo);

  final int added;
  final int alreadyThere;
  final int notKept;
  final HandAddUndo? _undo;

  @override
  String toString() =>
      'AddResult($added added, $alreadyThere already there, '
      '$notKept not kept)';
}

/// Adds videos the user picked by hand (Phase 7, D-111, D-113): from a folder
/// (full access) or from Android's photo picker (any access), to To tag or to
/// a reel, and takes an add back (Undo).
///
/// Every add and every Undo is one job on the shared [MediaWorkQueue], so it
/// never runs beside a scan, a verify or another add: a double tap, or an add
/// racing Shooting mode's scan, ends with one clip in one place. The writes
/// of one add are one transaction (`ClipsRepository.addByHand`).
class AddVideosService {
  new(
    this._bridge,
    this._clips,
    this._phone,
    this._zones,
    this._zoneSync,
    this._queue,
    this._clock,
  );

  final MediaBridge _bridge;
  final ClipsRepository _clips;
  final PhoneStateRepository _phone;
  final ZoneRepository _zones;
  final ZoneSync _zoneSync;
  final MediaWorkQueue _queue;
  final Clock _clock;
  late final LibraryResync _rebuilds = LibraryResync(_bridge, _clips, _phone);

  /// The marks of the videos [mediaStoreIds] of volume [volumeName] for an
  /// add to [target] ([addMarkFor]), by MediaStore id; an unmarked video is
  /// not in the map. Only attached clips that are not missing count: a
  /// missing clip's number may now be another video, so the add decides it
  /// by fingerprint instead (D-113).
  ///
  /// A plain read, **not** on the media queue: the grid asks it while it
  /// pages, and a long scan must not hold the marks back. A mark that a
  /// running job changes is caught by the add, which decides each video in
  /// its own job.
  Future<Map<int, AddMark>> marks(
    String volumeName,
    List<int> mediaStoreIds,
    AddTarget target,
  ) async {
    if (mediaStoreIds.isEmpty) return const {};
    final places = await _clips.placesOf(volumeName, mediaStoreIds);
    return {
      for (final MapEntry(key: number, value: place) in places.entries)
        number: ?addMarkFor(place, target),
    };
  }

  /// Adds [videos] from a folder to [target], as `ClipSource.mediaStore`
  /// clips: the same clip a scan would save (`clipFromVideo`), so a later scan
  /// finds it rather than adding it again (D-111). One job on the queue.
  ///
  /// Throws [StateError], writing nothing, without full access, and when the
  /// target reel is gone. A video that is not usable (`isUsable`) or whose
  /// volume is not mounted is [AddResult.notKept]. Each volume is first
  /// brought up to its current library version (`LibraryResync.catchUp`, as
  /// "Add earlier videos" does), so a stored clip is compared under the
  /// numbers it has now, and a volume's first clips record its version.
  Future<AddResult> addFromFolder(List<MediaVideo> videos, AddTarget target) =>
      _queue.run(() async {
        if ((await _bridge.accessReport()).level != MediaAccessLevel.full) {
          _log.info('Folder add refused: no full access');
          throw StateError('Adding from a folder needs full access');
        }
        final now = _clock.now();
        final mounted = {
          for (final v in await _bridge.volumes())
            if (v.isMounted) v.name: v,
        };
        final usable = <MediaVideo>[];
        var notKept = 0;
        for (final v in videos) {
          if (isUsable(v) && mounted.containsKey(v.volumeName)) {
            usable.add(v);
          } else {
            notKept++;
          }
        }
        final recorded = await _phone.volumeVersions();
        for (final name in {for (final v in usable) v.volumeName}) {
          await _rebuilds.catchUp(mounted[name]!, recorded, now: now);
        }
        if (usable.isEmpty) return _nothing('folder', target, notKept);
        final byIdentity = {
          for (final v in usable) (v.volumeName, v.mediaStoreId): v,
        };
        final (timeline, zone) = await _zonesNow();
        return await _add(
          'folder',
          [
            for (final v in byIdentity.values)
              clipFromVideo(v, timeline, zone, now),
          ],
          target,
          notKept,
          sameVideo: (stored, incoming) => sameVideo(
            stored.fingerprint,
            byIdentity[(incoming.volumeName!, incoming.mediaStoreId!)]!,
            now: now,
          ),
        );
      });

  /// Adds [videos] picked in the photo picker to [target], as
  /// `ClipSource.picker` clips identified by their address. Needs no media
  /// access (Manual mode). One job on the queue.
  ///
  /// A video whose grant Android would not keep (`persisted == false`) is
  /// [AddResult.notKept] and adds nothing: its address would stop working
  /// when the app closes. Throws [StateError], writing nothing, when the
  /// target reel is gone.
  Future<AddResult> addPicked(List<PickedVideo> videos, AddTarget target) =>
      _queue.run(() async {
        final kept = [
          for (final p in videos)
            if (p.persisted) p,
        ];
        final notKept = videos.length - kept.length;
        if (kept.isEmpty) return _nothing('picker', target, notKept);
        final now = _clock.now();
        final (timeline, zone) = await _zonesNow();
        return await _add(
          'picker',
          [
            for (final p in kept)
              newClipFromPicked(
                p,
                now: now,
                zoneId: zoneAt(timeline, pickedShotAt(p, now: now)) ?? zone,
              ),
          ],
          target,
          notKept,
          // Never called: `ClipsRepository.addByHand` asks `sameVideo` only
          // for MediaStore clips, because a picked clip's address is its
          // identity (D-57), so a known one is this video. The answer is
          // `true` to say that, should it ever be asked.
          sameVideo: (_, _) => true,
        );
      });

  /// Takes back what the add [result] did (`ClipsRepository.undoHandAdd`):
  /// only what it created, never a clip the user tagged, skipped or put in
  /// another reel since. A second Undo changes nothing. One job on the queue;
  /// it reads nothing from the phone, so it works whatever the access.
  Future<void> undo(AddResult result) async {
    final record = result._undo;
    if (record == null) return;
    await _queue.run(() => _clips.undoHandAdd(record));
  }

  Future<AddResult> _add(
    String route,
    List<NewClip> clips,
    AddTarget target,
    int notKept, {
    required bool Function(Clip stored, NewClip incoming) sameVideo,
  }) async {
    final reelId = switch (target) {
      AddToToTag() => null,
      AddToReel(:final reelId) => reelId,
    };
    final add = await _clips.addByHand(
      clips,
      reelId: reelId,
      sameVideo: sameVideo,
    );
    _log.info(
      'Add ($route) to $target: ${add.added} added, '
      '${add.alreadyThere} already there, $notKept not kept',
    );
    return AddResult._(add.added, add.alreadyThere, notKept, add.undo);
  }

  /// An add with nothing left to save: nothing more is read or written.
  AddResult _nothing(String route, AddTarget target, int notKept) {
    _log.info('Add ($route) to $target: nothing to add, $notKept not kept');
    return AddResult._(0, 0, notKept, null);
  }

  /// The zone timeline and the phone's zone now, with the phone's pending
  /// zone changes brought in first (as a scan does). A failed sync is logged
  /// by type and the add goes on with the zones already known.
  Future<(List<ZoneEntry>, String)> _zonesNow() async {
    try {
      await _zoneSync.sync();
    } on Object catch (e) {
      _log.warning(
        'The zone sync failed with ${e.runtimeType}; going on with the '
        'zones already known',
      );
    }
    return (await _zones.all(), await _bridge.currentZoneId());
  }
}

/// The service, on the shared [mediaWorkQueueProvider].
@Riverpod(keepAlive: true)
AddVideosService addVideosService(Ref ref) => AddVideosService(
  ref.watch(mediaBridgeProvider),
  ref.watch(clipsRepositoryProvider),
  ref.watch(phoneStateRepositoryProvider),
  ref.watch(zoneRepositoryProvider),
  ref.watch(zoneSyncProvider),
  ref.watch(mediaWorkQueueProvider),
  ref.watch(clockProvider),
);
