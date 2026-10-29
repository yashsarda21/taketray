import 'dart:math';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/library_resync.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'media_verifier.g.dart';

// Volume names, error codes and counts only (D-10).
final Logger _log = Logger('verifier');

/// What one verify found, as sets of clip ids. Every clip asked about is in
/// exactly one of them.
///
/// [missing] holds the clips whose video is gone *and* the ones whose number
/// now holds a different video (those are also detached). [skipped] holds
/// the clips that could not be checked: no full access, a picked or detached
/// clip, a volume that is not mounted or did not answer, a clip that no longer
/// exists.
@immutable
class VerifyOutcome {
  const VerifyOutcome({
    required this.found,
    required this.missing,
    required this.skipped,
  });

  final Set<int> found;
  final Set<int> missing;
  final Set<int> skipped;

  @override
  String toString() =>
      'VerifyOutcome(found: ${found.length}, missing: ${missing.length}, '
      'skipped: ${skipped.length})';
}

/// Checks that stored clips' videos still exist on the phone (D-72).
///
/// Every check runs on the shared [MediaWorkQueue], so it never overlaps a
/// scan: a scan that remaps clips after a rebuild finishes first, and the
/// verify then reads the clips' new numbers.
class MediaVerifier {
  new(this._bridge, this._clips, this._phone, this._queue, this._clock);

  final MediaBridge _bridge;
  final ClipsRepository _clips;
  final PhoneStateRepository _phone;
  final MediaWorkQueue _queue;
  final Clock _clock;
  late final LibraryResync _rebuilds = LibraryResync(_bridge, _clips, _phone);

  /// How many MediaStore ids one `videosByIds` call asks for.
  static const batchSize = 500;

  /// Checks [clips]. Only their ids are used: each clip is read again from
  /// the database when the job runs, because a scan queued before it may have
  /// given it a new MediaStore number (or detached it).
  Future<VerifyOutcome> verify(Iterable<Clip> clips) {
    final ids = {for (final c in clips) c.id};
    return _queue.run(() => _verify(ids));
  }

  /// Checks every stored clip ("X of Y clips found" after an import).
  Future<VerifyOutcome> verifyAll() =>
      _queue.run(() async => await _verify(await _clips.allClipIds()));

  /// 1. Without full access everything is skipped and nothing is written: a
  ///    limited query returns only the picked videos, so every other clip
  ///    would look gone (Review Focus 1).
  /// 2. Picked and detached clips, clips whose volume is not mounted, and ids
  ///    that no longer exist are skipped.
  /// 3. Per volume, first the library version (Ruling V): when the version
  ///    recorded for it differs from the current one, Android rebuilt it, so
  ///    the old numbers mean nothing. The volume's clips are matched again by
  ///    fingerprint (`LibraryResync`, the scanner's own rule) before any
  ///    number is looked up; a clip that match cannot find is missing (it is
  ///    detached in place, as after any rebuild). No version recorded: the
  ///    current one is recorded.
  /// 4. The volume's clips (read again after a resync) are asked for in
  ///    batches of [batchSize]. A returned row that is `sameVideo` is found;
  ///    one that is not means the number holds another video; a clip whose
  ///    row is not returned is gone. When anything about a volume fails, its
  ///    unchecked clips are skipped: an error never means "missing".
  /// 5. One write (`applyVerification`): detach the other-video clips, flag
  ///    found and gone, take gone and detached clips out of the lists.
  Future<VerifyOutcome> _verify(Set<int> ids) async {
    if (ids.isEmpty) {
      return const VerifyOutcome(found: {}, missing: {}, skipped: {});
    }
    final access = await _bridge.accessReport();
    if (access.level != MediaAccessLevel.full) {
      _log.info('Skipped ${ids.length} clips: access is ${access.level.name}');
      return VerifyOutcome(found: const {}, missing: const {}, skipped: ids);
    }

    final clips = await _clips.clipsByIds(ids);
    final skipped = {...ids}..removeAll(clips.map((c) => c.id));
    final mounted = {
      for (final v in await _bridge.volumes())
        if (v.isMounted) v.name: v,
    };
    final recorded = await _phone.volumeVersions();
    final byVolume = <String, List<Clip>>{};
    for (final clip in clips) {
      final volume = clip.volumeName;
      if (_checkable(clip) && mounted.containsKey(volume)) {
        (byVolume[volume!] ??= []).add(clip);
      } else {
        skipped.add(clip.id);
      }
    }

    final now = _clock.now();
    final found = <int>{};
    final gone = <int>{};
    final otherVideo = <int>{};
    final lost = <int>{};
    for (final MapEntry(key: volume, value: group) in byVolume.entries) {
      final lostHere = <int>{};
      try {
        var current = group;
        final match = await _rebuilds.catchUp(
          mounted[volume]!,
          recorded,
          now: now,
        );
        if (match != null) {
          final groupIds = {for (final c in group) c.id};
          lostHere.addAll(match.lost.intersection(groupIds));
          current = [
            for (final c in await _clips.clipsByIds(
              groupIds.difference(lostHere),
            ))
              if (_checkable(c)) c,
          ];
        }
        final rows = await _rowsOf(volume, [
          for (final c in current) c.mediaStoreId!,
        ]);
        for (final clip in current) {
          final row = rows[clip.mediaStoreId];
          if (row == null) {
            gone.add(clip.id);
          } else if (sameVideo(clip.fingerprint, row, now: now)) {
            found.add(clip.id);
          } else {
            otherVideo.add(clip.id);
          }
        }
        skipped.addAll(
          group
              .map((c) => c.id)
              .where(
                (id) =>
                    !lostHere.contains(id) &&
                    !found.contains(id) &&
                    !gone.contains(id) &&
                    !otherVideo.contains(id),
              ),
        );
      } on PlatformException catch (e) {
        _skipRest(group, lostHere, skipped);
        _log.warning(
          'Volume $volume did not answer (${e.code}): skipped its clips',
        );
      } on Object catch (e) {
        // Anything else must not stop the other volumes either (Ruling X);
        // only its type is logged.
        _skipRest(group, lostHere, skipped);
        _log.warning(
          'Volume $volume failed with ${e.runtimeType}: skipped its clips',
        );
      }
      lost.addAll(lostHere);
    }

    final removed = await _clips.applyVerification(
      found: found,
      gone: gone,
      otherVideo: otherVideo,
    );
    final missing = {...gone, ...otherVideo, ...lost};
    _log.info(
      'Verified ${ids.length} clips: ${found.length} found, '
      '${gone.length} gone, ${otherVideo.length} now another video, '
      '${lost.length} lost in a rebuild, ${skipped.length} skipped, '
      '$removed left the lists',
    );
    return VerifyOutcome(found: found, missing: missing, skipped: skipped);
  }

  /// A MediaStore clip that still holds a number (not picked, not detached).
  static bool _checkable(Clip clip) =>
      clip.source == ClipSource.mediaStore &&
      clip.volumeName != null &&
      (clip.mediaStoreId ?? 0) > 0;

  /// After a failure: every clip of [group] not already found lost in a
  /// rebuild is skipped. Nothing of the volume was classified yet, because
  /// the rows are only sorted once all of them have arrived.
  static void _skipRest(List<Clip> group, Set<int> lost, Set<int> skipped) =>
      skipped.addAll(group.map((c) => c.id).where((id) => !lost.contains(id)));

  /// The rows of [numbers] on [volume] that exist, by MediaStore id, asked
  /// in batches of [batchSize].
  Future<Map<int, MediaVideo>> _rowsOf(String volume, List<int> numbers) async {
    final rows = <int, MediaVideo>{};
    for (var start = 0; start < numbers.length; start += batchSize) {
      final batch = numbers.sublist(
        start,
        min(start + batchSize, numbers.length),
      );
      for (final row in await _bridge.videosByIds(volume, batch)) {
        rows[row.mediaStoreId] = row;
      }
    }
    return rows;
  }
}

/// The verifier, on the shared [mediaWorkQueueProvider].
@Riverpod(keepAlive: true)
MediaVerifier mediaVerifier(Ref ref) => MediaVerifier(
  ref.watch(mediaBridgeProvider),
  ref.watch(clipsRepositoryProvider),
  ref.watch(phoneStateRepositoryProvider),
  ref.watch(mediaWorkQueueProvider),
  ref.watch(clockProvider),
);
