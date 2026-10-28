import 'dart:math';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
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
  new(this._bridge, this._clips, this._queue, this._clock);

  final MediaBridge _bridge;
  final ClipsRepository _clips;
  final MediaWorkQueue _queue;
  final Clock _clock;

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
  /// 3. The rest are asked for by volume, in batches of [batchSize]. A
  ///    returned row that is [sameVideo] is found; one that is not is
  ///    detached (its number holds another video now); a clip whose row is
  ///    not returned is missing. When any batch of a volume fails, that whole
  ///    volume is skipped: an error never means "missing".
  /// 4. Writes: detach, `recordVerification`, then `removeMissingFromLists`
  ///    for every missing clip (detached ones included).
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
        if (v.isMounted) v.name,
    };
    final byVolume = <String, List<Clip>>{};
    for (final clip in clips) {
      final volume = clip.volumeName;
      final number = clip.mediaStoreId;
      if (clip.source != ClipSource.mediaStore ||
          volume == null ||
          number == null ||
          number <= 0 ||
          !mounted.contains(volume)) {
        skipped.add(clip.id);
      } else {
        (byVolume[volume] ??= []).add(clip);
      }
    }

    final now = _clock.now();
    final found = <int>{};
    final gone = <int>{};
    final otherVideo = <int>{};
    for (final MapEntry(key: volume, value: group) in byVolume.entries) {
      final Map<int, MediaVideo> rows;
      try {
        rows = await _rowsOf(volume, [for (final c in group) c.mediaStoreId!]);
      } on PlatformException catch (e) {
        skipped.addAll(group.map((c) => c.id));
        _log.warning(
          'Volume $volume did not answer (${e.code}): '
          'skipped ${group.length} clips',
        );
        continue;
      }
      for (final clip in group) {
        final row = rows[clip.mediaStoreId];
        if (row == null) {
          gone.add(clip.id);
        } else if (sameVideo(clip.fingerprint, row, now: now)) {
          found.add(clip.id);
        } else {
          otherVideo.add(clip.id);
        }
      }
    }

    await _clips.detach(otherVideo);
    if (found.isNotEmpty || gone.isNotEmpty) {
      await _clips.recordVerification(found: found, missing: gone);
    }
    final missing = {...gone, ...otherVideo};
    final removed = await _clips.removeMissingFromLists(missing);
    _log.info(
      'Verified ${ids.length} clips: ${found.length} found, '
      '${gone.length} gone, ${otherVideo.length} now another video, '
      '${skipped.length} skipped, $removed left the lists',
    );
    return VerifyOutcome(found: found, missing: missing, skipped: skipped);
  }

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
  ref.watch(mediaWorkQueueProvider),
  ref.watch(clockProvider),
);
