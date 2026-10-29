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
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/baseline.dart';
import 'package:taketray/domain/rules/clip_date.dart';
import 'package:taketray/domain/rules/earlier_window.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/domain/rules/zone_lookup.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'media_scanner.g.dart';

// Volume names, generations, error codes and counts only: never a display
// name, a folder, a URI or a MediaStore version (D-10).
final Logger _log = Logger('scanner');

/// What one scan did.
@immutable
sealed class ScanOutcome {
  const ScanOutcome();
}

/// Shooting mode is off: nothing was read.
final class ScanShootingOff extends ScanOutcome {
  const ScanShootingOff();
}

/// TakeTray may not read every video (limited or denied): nothing was read
/// or written.
final class ScanNoAccess extends ScanOutcome {
  const ScanNoAccess();
}

/// The scan ran. [added] counts the clips that are new in To tag;
/// [resynced] names the volumes whose rebuilt library was matched again;
/// [failedVolumes] names the volumes that did not answer (their baselines
/// did not move, so the next scan tries them again).
final class ScanDone extends ScanOutcome {
  const ScanDone(this.added, this.resynced, this.failedVolumes);

  final int added;
  final Set<String> resynced;
  final Set<String> failedVolumes;

  @override
  String toString() =>
      'ScanDone($added, resynced: $resynced, failed: $failedVolumes)';
}

/// What every volume of one scan shares: read once per scan.
class _ScanContext {
  _ScanContext({
    required this.session,
    required this.folders,
    required this.timeline,
    required this.currentZone,
    required this.now,
  });

  final ShootingState session;
  final List<String> folders;
  final List<ZoneEntry> timeline;
  final String currentZone;
  final DateTime now;
}

/// Finds new phone videos while Shooting mode is on, and finds stored clips
/// again after Android rebuilds its media library (D-72). Also "Add earlier
/// videos" (D-73).
///
/// Every job runs on the shared [MediaWorkQueue], one at a time. On top of
/// it, [scan] coalesces: calls made while a scan waits in the queue share it.
class MediaScanner {
  new(
    this._bridge,
    this._clips,
    this._phone,
    this._settings,
    this._zones,
    this._queue,
    this._clock,
  );

  final MediaBridge _bridge;
  final ClipsRepository _clips;
  final PhoneStateRepository _phone;
  final SettingsRepository _settings;
  final ZoneRepository _zones;
  final MediaWorkQueue _queue;
  final Clock _clock;
  late final LibraryResync _rebuilds = LibraryResync(_bridge, _clips, _phone);

  /// Rows asked for per page of `videosAddedAfter`.
  static const pageSize = 500;

  /// The largest page: a page stalled inside one generation is asked again
  /// with twice the limit, up to this (D-70).
  static const maxPageLimit = 16000;

  /// The scan that is queued but has not started yet, if any.
  Future<ScanOutcome>? _queued;

  /// Looks for new videos on every volume (D-72).
  ///
  /// Calls never run side by side. While a scan runs, the first call queues
  /// one more scan, which starts after it; every later call until that scan
  /// starts gets the same future. So any number of triggers during one run
  /// cost exactly one more run, and that run sees everything they wanted it
  /// to see.
  Future<ScanOutcome> scan() => _queued ??= _queue.run(() {
    _queued = null;
    return _scanOnce();
  });

  Future<ScanOutcome> _scanOnce() async {
    final session = await _phone.loadShooting();
    if (!session.on) {
      _log.info('Scan skipped: Shooting mode is off');
      return const ScanShootingOff();
    }
    final _ScanContext context;
    final List<MediaVolume> volumes;
    try {
      final access = await _bridge.accessReport();
      if (access.level != MediaAccessLevel.full) {
        _log.info('Scan skipped: access is ${access.level.name}');
        return const ScanNoAccess();
      }
      await _phone.markAccessWasFull();
      context = _ScanContext(
        session: session,
        folders: (await _settings.load()).watchedFolders,
        timeline: await _zones.all(),
        currentZone: await _bridge.currentZoneId(),
        now: _clock.now(),
      );
      volumes = await _bridge.volumes();
    } on PlatformException catch (e) {
      _log.warning('Scan stopped: the phone did not answer (${e.code})');
      rethrow;
    }

    // Shooting mode may have gone off (and on) while the phone answered: then
    // this scan belongs to no session and writes nothing at all (M6).
    final still = await _phone.loadShooting();
    final since = session.since;
    if (!still.on ||
        since == null ||
        still.since == null ||
        !still.since!.isAtSameMomentAs(since)) {
      _log.info('Scan stopped: Shooting mode changed while it ran');
      return const ScanShootingOff();
    }
    final recorded = await _phone.volumeVersions();

    var added = 0;
    final resynced = <String>{};
    final failed = <String>{};
    for (final volume in volumes) {
      final baseline = session.baselines[volume.name];
      final plan = planVolume(baseline, volume);
      if (plan is SkipVolume) {
        _log.info('Volume ${volume.name}: not mounted, left alone');
        continue;
      }
      try {
        if (plan is Resync) {
          await _resync(context, baseline!, volume);
          resynced.add(volume.name);
          continue;
        }
        // Rebuilt since the clips were last matched (while Shooting mode was
        // off, say): match them again before anything else (Ruling V).
        if (await _rebuilds.catchUp(volume, recorded, now: context.now) !=
            null) {
          resynced.add(volume.name);
        }
        switch (plan) {
          case StartFromNow():
            await _startFromNow(context, volume);
          case ScanAfter(:final generation):
            added += await _scanAfter(context, baseline!, volume, generation);
          case SkipVolume():
          case Resync():
          // Handled above.
        }
      } on PlatformException catch (e) {
        failed.add(volume.name);
        _log.warning(
          'Volume ${volume.name}: the phone did not answer (${e.code}), '
          'its baseline stays',
        );
      } on Object catch (e) {
        // Anything else (a database surprise, a bug) must not stop the other
        // volumes either (Ruling X); only its type is logged.
        failed.add(volume.name);
        _log.warning(
          'Volume ${volume.name}: failed with ${e.runtimeType}, '
          'its baseline stays',
        );
      }
    }
    _log.info(
      'Scanned ${volumes.length} volumes: $added new clips, '
      '${resynced.length} resynced, ${failed.length} failed',
    );
    return ScanDone(added, resynced, failed);
  }

  /// A volume with no baseline: its current position becomes the baseline,
  /// and nothing on it is new.
  Future<void> _startFromNow(_ScanContext context, MediaVolume volume) async {
    final wrote = await _phone.advanceBaseline(
      volume.name,
      expectedSession: context.session,
      expected: null,
      next: _positionOf(volume),
    );
    _log.info(
      'Volume ${volume.name}: first seen in this session, starting at '
      'generation ${volume.generation}${wrote ? '' : ' (not written)'}',
    );
  }

  /// Android rebuilt the volume's library: find the stored clips again by
  /// fingerprint, then start from the volume's current position. No clip is
  /// added, so the rebuilt library does not flood To tag.
  Future<void> _resync(
    _ScanContext context,
    VolumeBaseline baseline,
    MediaVolume volume,
  ) async {
    final match = await _rebuilds.resync(volume, now: context.now);
    // If Shooting mode was switched off and on meanwhile this writes nothing;
    // the remap above stands, because it is true whatever the session.
    final wrote = await _phone.advanceBaseline(
      volume.name,
      expectedSession: context.session,
      expected: baseline,
      next: _positionOf(volume),
      rebuilt: true,
    );
    final why = baseline.version == volume.version
        ? 'generation went back'
        : 'version changed';
    _log.info(
      'Volume ${volume.name}: library rebuilt ($why), '
      '${match.remap.length} found, ${match.lost.length} lost; baseline '
      '${wrote ? 'moved' : 'left: it had changed'}',
    );
  }

  /// Pages through the videos added after [from], saves the usable ones as
  /// clips, and only then moves the baseline. Returns how many clips are new.
  ///
  /// - The volume's generation was read before the first page (`captured`).
  ///   A row added after it belongs to the next scan: it is not kept, and a
  ///   page that reaches one is the last. So a scan that pages on after
  ///   Shooting mode went off and on cannot pick up a video shot in between.
  /// - The scan cursor is separate from the baseline. After a full page it
  ///   moves to [nextPageCursor] (one below the page's highest generation,
  ///   because rows written together share one), and rows that come back on
  ///   the next page are counted once, by MediaStore id.
  /// - A full page stalled inside one generation is asked again with twice
  ///   the limit, up to [maxPageLimit]. If it is still stalled there, the
  ///   scan stops: it saves what it saw and holds the baseline below that
  ///   generation (`truncated`), and logs it.
  /// - A page shorter than its limit is the end.
  Future<int> _scanAfter(
    _ScanContext context,
    VolumeBaseline baseline,
    MediaVolume volume,
    int from,
  ) async {
    final captured = volume.generation;
    final seen = <int, MediaVideo>{};
    var cursor = from;
    var limit = pageSize;
    var pages = 0;
    var truncated = false;
    while (true) {
      final page = await _bridge.videosAddedAfter(
        volume.name,
        cursor,
        context.folders,
        limit,
      );
      pages++;
      var pastCaptured = false;
      for (final v in page) {
        if (v.generationAdded > captured) {
          pastCaptured = true;
        } else {
          seen[v.mediaStoreId] = v;
        }
      }
      if (page.length < limit || pastCaptured) break;
      final next = nextPageCursor(cursor: cursor, page: page);
      if (next != null) {
        cursor = next;
        limit = pageSize;
      } else if (limit < maxPageLimit) {
        limit = min(limit * 2, maxPageLimit);
      } else {
        truncated = true;
        break;
      }
    }

    final rows = seen.values.toList();
    final usable = [
      for (final v in rows)
        if (isUsable(v)) v,
    ];
    var added = 0;
    var detached = 0;
    if (usable.isNotEmpty) {
      final saved = await _save(
        usable,
        context.timeline,
        context.currentZone,
        context.now,
      );
      added = saved.inserted.length;
      detached = saved.detached.length;
    }

    // Only now that the clips are saved: a crash or a failure above leaves
    // the baseline where it was, and the next scan sees the rows again.
    final generation = advanceBaseline(
      from: from,
      captured: captured,
      seen: rows,
      now: context.now,
      truncated: truncated,
    );
    final pending = rows
        .where((v) => holdsBaseline(v, now: context.now))
        .length;
    var moved = 'kept';
    if (generation != baseline.generation) {
      final wrote = await _phone.advanceBaseline(
        volume.name,
        expectedSession: context.session,
        expected: baseline,
        next: VolumeBaseline(version: baseline.version, generation: generation),
      );
      moved = wrote ? 'moved' : 'left: it had changed';
    }
    final summary =
        'Volume ${volume.name}: ${rows.length} rows on $pages pages, '
        '${usable.length} usable, $added new, $pending held, '
        '$detached stored clips were other videos; '
        'baseline $moved';
    if (truncated) {
      _log.warning(
        '$summary. Stopped early: one generation holds more than '
        '$maxPageLimit rows; held at $generation',
      );
    } else {
      _log.info(summary);
    }
    return added;
  }

  /// Counts the videos "Add earlier videos" would add today (D-73). Without
  /// full access it is 0 and nothing is read.
  Future<int> countEarlier() => countEarlierIn(const EarlierToday());

  /// Counts the videos [range] would add: the usable videos shot in it that
  /// no stored clip holds (D-73, D-78). Without full access it is 0 and
  /// nothing is read. Throws [ArgumentError] for a range whose "from" is
  /// after its "to" or after today.
  Future<int> countEarlierIn(EarlierRange range) => _queue.run(() async {
    final now = _clock.now();
    final bounds = earlierWindowBounds(range, now);
    if (!await _hasFullAccess()) return 0;
    final count = (await _earlierVideos(bounds, now)).length;
    _log.info('Earlier videos (${_kind(range)}): $count found');
    return count;
  });

  /// Adds the videos shot in [range] that TakeTray does not know yet to To
  /// tag, and returns the ids of the new clips (for Undo). Notes the use in
  /// the Shooting session when something was added (D-73). Never reads or
  /// moves a baseline. Throws [StateError] without full access and
  /// [ArgumentError] for an impossible range (see [countEarlierIn]).
  Future<List<int>> addEarlier(EarlierRange range) => _queue.run(() async {
    final now = _clock.now();
    final bounds = earlierWindowBounds(range, now);
    if (!await _hasFullAccess()) {
      throw StateError('Adding earlier videos needs full access');
    }
    final videos = await _earlierVideos(bounds, now);
    if (videos.isEmpty) {
      _log.info('Earlier videos (${_kind(range)}): none to add');
      return const <int>[];
    }
    final timeline = await _zones.all();
    final currentZone = await _bridge.currentZoneId();
    final saved = await _save(videos, timeline, currentZone, now);
    await _phone.markEarlierAdded();
    _log.info(
      'Earlier videos (${_kind(range)}): added ${saved.inserted.length}, '
      '${saved.detached.length} stored clips were other videos',
    );
    return saved.inserted;
  });

  /// Only the kind of range, never its dates, for the log (D-10).
  String _kind(EarlierRange range) => switch (range) {
    EarlierToday() => 'today',
    EarlierCustom() => 'dates',
  };

  Future<bool> _hasFullAccess() async =>
      (await _bridge.accessReport()).level == MediaAccessLevel.full;

  /// The usable videos shot inside [bounds] on every mounted volume, in the
  /// watched folders, that no stored clip holds. A volume that does not
  /// answer is left out (and logged).
  ///
  /// The phone is asked for everything shot since the start; the end is
  /// applied here.
  Future<List<MediaVideo>> _earlierVideos(
    EarlierBounds bounds,
    DateTime now,
  ) async {
    final folders = (await _settings.load()).watchedFolders;
    final candidates = <MediaVideo>[];
    for (final volume in await _bridge.volumes()) {
      if (!volume.isMounted) continue;
      final List<MediaVideo> rows;
      try {
        rows = await _bridge.videosShotSince(
          volume.name,
          folders,
          bounds.startUtc.millisecondsSinceEpoch,
        );
      } on PlatformException catch (e) {
        _log.warning(
          'Volume ${volume.name}: the phone did not answer (${e.code}), '
          'its earlier videos are left out',
        );
        continue;
      }
      final inWindow = {
        for (final v in rows)
          if (shotInWindow(v, bounds.startUtc, bounds.endUtc, now: now))
            v.mediaStoreId: v,
      };
      final held = await _clips.mediaStoreClipsHolding(
        volume.name,
        inWindow.keys,
      );
      // Known only when the stored clip is this very video (Ruling U); a
      // clip holding the number of another video does not hide it.
      candidates.addAll(
        inWindow.values.where((v) {
          final clip = held[v.mediaStoreId];
          return clip == null || !sameVideo(clip.fingerprint, v, now: now);
        }),
      );
    }
    return candidates;
  }

  /// Saves [videos] as clips with `addCheckedClips`: a stored clip that
  /// holds a video's number is kept only when it is `sameVideo`; otherwise it
  /// is detached and the video saved as a new clip (Ruling U).
  Future<DetectedClips> _save(
    List<MediaVideo> videos,
    List<ZoneEntry> timeline,
    String currentZone,
    DateTime now,
  ) {
    final byIdentity = {
      for (final v in videos) (v.volumeName, v.mediaStoreId): v,
    };
    return _clips.addCheckedClips(
      [for (final v in videos) _clipFrom(v, timeline, currentZone, now)],
      sameVideo: (stored, incoming) => sameVideo(
        stored.fingerprint,
        byIdentity[(incoming.volumeName!, incoming.mediaStoreId!)]!,
        now: now,
      ),
    );
  }

  /// The clip for [v], in the zone the phone was in when it was shot (the
  /// timeline), or the phone's zone now when the timeline does not reach
  /// back that far.
  static NewClip _clipFrom(
    MediaVideo v,
    List<ZoneEntry> timeline,
    String currentZone,
    DateTime now,
  ) => newClipFrom(
    v,
    now: now,
    zoneId: zoneAt(timeline, shotAt(v, now: now)) ?? currentZone,
  );

  static VolumeBaseline _positionOf(MediaVolume volume) =>
      VolumeBaseline(version: volume.version!, generation: volume.generation);
}

/// The scanner, on the shared [mediaWorkQueueProvider]. Kept alive: the
/// queued scan that calls share lives in it.
@Riverpod(keepAlive: true)
MediaScanner mediaScanner(Ref ref) => MediaScanner(
  ref.watch(mediaBridgeProvider),
  ref.watch(clipsRepositoryProvider),
  ref.watch(phoneStateRepositoryProvider),
  ref.watch(settingsRepositoryProvider),
  ref.watch(zoneRepositoryProvider),
  ref.watch(mediaWorkQueueProvider),
  ref.watch(clockProvider),
);
