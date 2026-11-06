import 'dart:math';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/library_resync.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/media/zone_sync.dart';
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
import 'package:taketray/platform/background_bridge.dart';
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

/// The scan was put off: the shade action could not be read, so nothing was
/// read or written (D-106). The next trigger tries again.
final class ScanDeferred extends ScanOutcome {
  const ScanDeferred();
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
    this._zoneSync,
    this._queue,
    this._clock,
    this._shade,
  );

  final MediaBridge _bridge;
  final ClipsRepository _clips;
  final PhoneStateRepository _phone;
  final SettingsRepository _settings;
  final ZoneRepository _zones;
  final ZoneSync _zoneSync;
  final MediaWorkQueue _queue;
  final Clock _clock;

  /// Where the shade's Still shooting? buttons are read and cleared (D-106).
  final BackgroundBridge _shade;
  late final LibraryResync _rebuilds = LibraryResync(_bridge, _clips, _phone);

  /// Rows asked for per page of `videosAddedAfter`.
  static const pageSize = 500;

  /// The largest page: a page stalled inside one generation is asked again
  /// with twice the limit, up to this (D-70).
  static const maxPageLimit = 16000;

  /// The scan that is queued but has not started yet, if any.
  Future<ScanOutcome>? _queued;

  /// How many counted failures in a row ending a session from the shade
  /// had, which session (its `since` in milliseconds) they were for, and when
  /// the last one was counted.
  int _failedEnds = 0;
  int? _failedEndsFor;
  DateTime? _lastCountedFailure;

  /// After this many counted failures in this process, a Turn off from the
  /// shade ends the session with what could be read (D-106).
  static const maxEndAttempts = 3;

  /// A failed end counts toward [maxEndAttempts] only this long after the
  /// last counted one, so the tries of one start or resume (the lifecycle's
  /// scan, To tag's, the copy's write) count once, and three counted
  /// failures mean the volume failed for at least 10 minutes (D-106).
  static const endRetryGap = Duration(minutes: 5);

  /// Looks for new videos on every volume (D-72).
  ///
  /// Calls never run side by side. While a scan runs, the first call queues
  /// one more scan, which starts after it; every later call until that scan
  /// starts gets the same future. So any number of triggers during one run
  /// cost exactly one more run, and that run sees everything they wanted it
  /// to see.
  ///
  /// Every scan first looks for a shade action, inside its own job, so no
  /// trigger can scan past a Turn off tapped in the shade (D-106):
  /// - a Turn off for the current session is applied in place of the scan
  ///   (the end capped at the tap), and its outcome is the
  ///   answer;
  /// - a Keep on for the current session is stored, then the scan runs;
  /// - an action for another session is cleared, then the scan runs;
  /// - when the action cannot be read, nothing is read or written and the
  ///   answer is [ScanDeferred]: the next trigger tries again.
  Future<ScanOutcome> scan() => _queued ??= _queue.run(() {
    _queued = null;
    return _gatedScan();
  });

  Future<ScanOutcome> _gatedScan() async {
    final ShadeAction? action;
    try {
      action = await _shade.pendingShadeAction();
    } on Object catch (e) {
      _log.warning(
        'Scan deferred: the shade action was not read (${e.runtimeType})',
      );
      return const ScanDeferred();
    }
    if (action != null) {
      final ended = await _applyShade(action);
      if (ended != null) return ended;
    }
    return await _scanOnce();
  }

  /// Applies the waiting shade action, if any, as [scan] does, but scans
  /// nothing else (`ShadeActions.apply`). One job on the media queue; it
  /// throws when the phone does not answer, and the action then stays.
  Future<void> applyShadeAction() => _queue.run(() async {
    final action = await _shade.pendingShadeAction();
    if (action != null) await _applyShade(action);
  });

  /// Applies [action], inside a queue job. Returns the end's outcome when a
  /// Turn off for the current session took the place of a scan, else null.
  ///
  /// An action for another session (or with Shooting mode off) is only
  /// cleared. A Keep on is stored (`markStillAnswered`) and cleared. Either
  /// failing is logged by type and never blocks the scan: the action stays
  /// for the next try. A Turn off ends the session capped at the tap, and is
  /// cleared unless the end was kept for another try; only it may block a
  /// scan. Clearing names the tap, so a newer one stays.
  Future<ScanOutcome?> _applyShade(ShadeAction action) async {
    final kind = action.kind.name;
    final session = await _phone.loadShooting();
    if (!session.isSession(action.since)) {
      _log.info('Shade action $kind dropped: it was for another session');
      await _guardedStep(
        'Clearing a stale shade action',
        () => _shade.clearShadeAction(action.at),
      );
      return null;
    }
    switch (action.kind) {
      case ShadeActionKind.keepOn:
        await _guardedStep('Applying shade action $kind', () async {
          await _phone.markStillAnswered(action.since);
          await _shade.clearShadeAction(action.at);
          _log.info('Shade action $kind applied');
        });
        return null;
      case ShadeActionKind.turnOff:
        final (outcome, kept) = await _endCapped(session, action.generations);
        if (kept) return outcome;
        await _shade.clearShadeAction(action.at);
        _log.info('Shade action $kind applied');
        return outcome;
    }
  }

  /// Runs [step]; a failure is logged by type only (never its message, D-10)
  /// and goes no further.
  Future<void> _guardedStep(String what, Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (e) {
      _log.warning('$what failed: ${e.runtimeType}; left for the next try');
    }
  }

  /// Ends [session] capped at [generations], inside a queue job. Returns the
  /// outcome, and whether the session was kept for another try.
  ///
  /// A volume that fails (or a phone that does not answer before the
  /// volumes are read, which is rethrown) keeps the session, so the next
  /// trigger tries again; the [maxEndAttempts]th failure in a row for the
  /// session ends it with what could be read. Without full access it ends
  /// at once.
  Future<(ScanOutcome, bool)> _endCapped(
    ShootingState session,
    Map<String, int> generations,
  ) async {
    final since = session.since!;
    ScanOutcome outcome;
    // The phone did not answer and this try's failure is already noted, so
    // the volume check below must not count (or log "too soon") a second time.
    var counted = false;
    try {
      final run = await _prepare(session, 'Ending the session');
      if (run == null) {
        outcome = const ScanNoAccess();
      } else if (!await _stillSession(session)) {
        _log.info(
          'Ending the session stopped: Shooting mode changed meanwhile',
        );
        return (const ScanShootingOff(), false);
      } else {
        outcome = await _scanVolumes(run.$1, run.$2, caps: generations);
      }
    } on PlatformException {
      counted = true;
      if (_keepAfterFailure(since)) rethrow;
      // Nothing was read: every volume of the session counts as failed, so
      // the new-clips notification is not cleared for them.
      outcome = ScanDone(0, const {}, {
        ...generations.keys,
        ...session.baselines.keys,
      });
    }
    if (!counted &&
        outcome is ScanDone &&
        outcome.failedVolumes.isNotEmpty &&
        _keepAfterFailure(since)) {
      _log.warning(
        'Ending the session: ${outcome.failedVolumes.length} volumes failed; '
        'kept for the next try ($_failedEnds of $maxEndAttempts)',
      );
      return (outcome, true);
    }
    if (_failedEnds >= maxEndAttempts) {
      _log.warning(
        'Ending the session after $maxEndAttempts attempts: '
        '${outcome is ScanDone ? outcome.failedVolumes.length : 0} '
        'volumes not read',
      );
    }
    // The count is forgotten only once the session is really ended: when the
    // database refuses, the next try is still the 4th and not the 1st.
    final ended = await _phone.endSession(since);
    _failedEnds = 0;
    _failedEndsFor = null;
    _lastCountedFailure = null;
    _log.info(
      'Ended the session from the shade: '
      '${ended ? 'off' : 'left on, it had changed'}',
    );
    return (outcome, false);
  }

  /// Notes one failed end of the session that started at [since]; true
  /// while it is to be kept for another try (fewer than [maxEndAttempts]
  /// counted failures in a row). A failure counts only [endRetryGap] or
  /// more from the last counted one (by the injected clock, in either
  /// direction: a clock set back by that much must not hold the next counts
  /// off until it catches up); a closer one is logged and not counted.
  bool _keepAfterFailure(DateTime since) {
    final ms = since.millisecondsSinceEpoch;
    if (_failedEndsFor != ms) {
      _failedEndsFor = ms;
      _failedEnds = 0;
      _lastCountedFailure = null;
    }
    final now = _clock.now();
    final last = _lastCountedFailure;
    if (last == null || now.difference(last).abs() >= endRetryGap) {
      _failedEnds++;
      _lastCountedFailure = now;
    } else {
      _log.info('Ending the session failed again, too soon: not counted');
    }
    return _failedEnds < maxEndAttempts;
  }

  Future<ScanOutcome> _scanOnce() async {
    final session = await _phone.loadShooting();
    if (!session.on) {
      _log.info('Scan skipped: Shooting mode is off');
      return const ScanShootingOff();
    }
    final run = await _prepare(session, 'Scan');
    if (run == null) return const ScanNoAccess();

    // Shooting mode may have gone off (and on) while the phone answered: then
    // this scan belongs to no session and writes nothing at all (M6).
    if (!await _stillSession(session)) {
      _log.info('Scan stopped: Shooting mode changed while it ran');
      return const ScanShootingOff();
    }
    return await _scanVolumes(run.$1, run.$2);
  }

  /// What every volume of one run shares, and the volumes, read from the
  /// phone. Null without full access (logged as [what] skipped). A phone
  /// that does not answer is logged and rethrown.
  Future<(_ScanContext, List<MediaVolume>)?> _prepare(
    ShootingState session,
    String what,
  ) async {
    try {
      final access = await _bridge.accessReport();
      if (access.level != MediaAccessLevel.full) {
        _log.info('$what skipped: access is ${access.level.name}');
        return null;
      }
      await _phone.markAccessWasFull();
      // The zone changes the phone saw while the app was away must be in the
      // timeline before it is read, or a new clip gets the old zone for good.
      await _syncZones();
      final context = _ScanContext(
        session: session,
        folders: (await _settings.load()).watchedFolders,
        timeline: await _zones.all(),
        currentZone: await _bridge.currentZoneId(),
        now: _clock.now(),
      );
      return (context, await _bridge.volumes());
    } on PlatformException catch (e) {
      _log.warning('$what stopped: the phone did not answer (${e.code})');
      rethrow;
    }
  }

  /// Whether [session] is still the stored one.
  Future<bool> _stillSession(ShootingState session) async {
    final still = await _phone.loadShooting();
    final since = session.since;
    return still.on &&
        since != null &&
        still.since != null &&
        still.since!.isAtSameMomentAs(since);
  }

  /// Scans [volumes], one at a time: the per-volume part of a scan and of
  /// the capped end.
  ///
  /// With [caps] (volume name to generation), only the volumes in it are
  /// scanned, each up to its cap; any other volume is left alone (logged).
  /// A volume that fails is named in [ScanDone.failedVolumes] and does not
  /// stop the others.
  Future<ScanDone> _scanVolumes(
    _ScanContext context,
    List<MediaVolume> volumes, {
    Map<String, int>? caps,
  }) async {
    final recorded = await _phone.volumeVersions();

    var added = 0;
    final resynced = <String>{};
    final failed = <String>{};
    for (final volume in volumes) {
      if (caps != null && !caps.containsKey(volume.name)) {
        _log.info('Volume ${volume.name}: not in the tap, left alone');
        continue;
      }
      final baseline = context.session.baselines[volume.name];
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
            added += await _startNewVolume(
              context,
              volume,
              cap: caps?[volume.name],
            );
          case ScanAfter(:final generation):
            // Never in the capped end: it ends the session, so a repair that
            // reads the whole volume can wait for the next session's scan.
            if (caps == null) await _rematchDetached(context, volume);
            added += await _scanAfter(
              context,
              baseline!,
              volume,
              generation,
              cap: caps?[volume.name],
            );
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

  /// A volume with no baseline while Shooting mode is on (its read failed at
  /// switch-on, an import left none, or an SD card was inserted later): the
  /// clips shot since the session started are new (D-108, M-8), and its
  /// current generation becomes the baseline. Returns how many clips are new.
  ///
  /// The phone is asked once, `videosShotSince` the session's start; the rows
  /// are narrowed by [shotSinceSession] and then saved as a scan saves them
  /// (`_commit`), so a clip that is already stored is not added again.
  ///
  /// The baseline never holds here: it moves to `captured`. A row that would
  /// hold it ([holdsBaseline]: no length or size yet; pending rows are not in
  /// the answer at all) is not added, and is not seen again. Holding would
  /// make the next scan a plain `ScanAfter` from below that row, with no
  /// date filter, and every video shot before the session above it on the
  /// card would come in as new (a card indexes in no order). That gap is
  /// D-108's; "Add earlier videos" recovers it.
  ///
  /// A [cap] (the capped end) is honoured like `_scanAfter` does: no row
  /// above it is kept and the baseline goes no higher. A failure of the
  /// phone or the database leaves the volume without a baseline, and the
  /// next scan tries again.
  Future<int> _startNewVolume(
    _ScanContext context,
    MediaVolume volume, {
    int? cap,
  }) async {
    final since = context.session.since;
    final captured = cap == null
        ? volume.generation
        : min(volume.generation, cap);
    final read = since == null
        ? const <MediaVideo>[]
        : await _bridge.videosShotSince(
            volume.name,
            context.folders,
            since.millisecondsSinceEpoch,
          );
    final rows = shotSinceSession(
      read,
      since: since,
      captured: captured,
      now: context.now,
    );
    _log.info(
      'Volume ${volume.name}: first seen in this session, ${read.length} '
      'videos asked for since the start, ${rows.length} shot since',
    );
    return await _commit(
      context,
      volume,
      baseline: null,
      from: 0,
      captured: captured,
      rows: rows,
      read: '${rows.length} rows shot since the start',
      hold: false,
    );
  }

  /// Matches the clips a rebuild detached against everything now on the
  /// volume, before the page of new videos is read (D-108, I-3): so a video
  /// that is back ahead of the baseline is found to be a clip already, not
  /// added a second time. At most one read of the volume per scan, and only
  /// inside the rebuild's re-match window when the volume's generation has
  /// moved (`LibraryResync.reattach`).
  ///
  /// It is a repair: a failure is logged by type and the scan carries on,
  /// the clips stay detached and the next scan tries again. It never fails
  /// the volume: a repair must not hold the volume's baseline, and the new
  /// clips behind it, for as long as the phone cannot answer it. (It never
  /// runs in the capped end, so it has nothing to do with keeping a session
  /// open.)
  Future<void> _rematchDetached(
    _ScanContext context,
    MediaVolume volume,
  ) async {
    try {
      await _rebuilds.reattach(volume, now: context.now);
    } on Object catch (e) {
      _log.warning(
        'Volume ${volume.name}: matching detached clips again failed with '
        '${e.runtimeType}; left for the next scan',
      );
    }
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
  ///   A [cap] (the capped end: the generation at the shade's tap) lowers
  ///   `captured` to it, so a row added after the tap is never kept, and the
  ///   baseline moves no higher than the cap.
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
    int from, {
    int? cap,
  }) async {
    final captured = cap == null
        ? volume.generation
        : min(volume.generation, cap);
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

    return await _commit(
      context,
      volume,
      baseline: baseline,
      from: from,
      captured: captured,
      rows: seen.values.toList(),
      truncated: truncated,
      read: '${seen.length} rows on $pages pages',
      hold: true,
    );
  }

  /// Saves the usable [rows] as clips, and only then moves the baseline: the
  /// end of `_scanAfter` and of a volume's first scan, so both follow one
  /// rule. Returns how many clips are new.
  ///
  /// [baseline] is the one stored for the volume, or null when it has none.
  /// [from] is the generation the read started after, [captured] the one it
  /// stopped at, [truncated] whether it stopped early, and [read] what the
  /// read found, for the log. With [hold] (a `ScanAfter`), a row that holds
  /// the baseline holds it below the oldest such row ([advanceBaseline]);
  /// without it (a volume's first scan) the baseline moves to [captured]
  /// whatever the rows are. A crash or a failure while saving leaves the
  /// baseline where it was, and the next scan sees the rows again; the move
  /// itself is a compare-and-set, so a stale scan writes nothing.
  Future<int> _commit(
    _ScanContext context,
    MediaVolume volume, {
    required VolumeBaseline? baseline,
    required int from,
    required int captured,
    required List<MediaVideo> rows,
    required String read,
    required bool hold,
    bool truncated = false,
  }) async {
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
      seen: hold ? rows : const [],
      now: context.now,
      truncated: truncated,
    );
    final pending = rows
        .where((v) => holdsBaseline(v, now: context.now))
        .length;
    var moved = 'kept';
    if (baseline == null || generation != baseline.generation) {
      final wrote = await _phone.advanceBaseline(
        volume.name,
        expectedSession: context.session,
        expected: baseline,
        next: VolumeBaseline(
          version: baseline?.version ?? volume.version!,
          generation: generation,
        ),
      );
      moved = wrote ? 'moved' : 'left: it had changed';
    }
    final summary =
        'Volume ${volume.name}: $read, '
        '${usable.length} usable, $added new, '
        '$pending ${hold ? 'held' : 'not finished, left out'}, '
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
  /// tag, and returns the ids of the new clips (for Undo). Writes nothing
  /// to the Shooting state (D-90 dropped the one-use mark), and never reads
  /// or moves a baseline. Throws [StateError] without full access and
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
    await _syncZones();
    final timeline = await _zones.all();
    final currentZone = await _bridge.currentZoneId();
    final saved = await _save(videos, timeline, currentZone, now);
    _log.info(
      'Earlier videos (${_kind(range)}): added ${saved.inserted.length}, '
      '${saved.detached.length} stored clips were other videos',
    );
    return saved.inserted;
  });

  /// Brings the phone's zone changes into the timeline, inside the queued
  /// job, right before the timeline is read (D-72, I-2). `MediaLifecycle`
  /// syncs too, and a second sync changes nothing that is stored, so the
  /// scan does not depend on it having finished. A failure is logged (its
  /// type only) and the job goes on with the timeline it has: a zone off by
  /// a trip is better than no clips.
  Future<void> _syncZones() async {
    try {
      await _zoneSync.sync();
    } on Object catch (e) {
      _log.warning(
        'The zone sync failed with ${e.runtimeType}; going on with the '
        'zones already known',
      );
    }
  }

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
  ///
  /// Each mounted volume is first brought up to its current library version
  /// (`LibraryResync.catchUp`, as the scan and the verifier do): the version
  /// is recorded when none is (so a rebuild right after the first clips came
  /// from here is detected, M-3), and clips stored under an older version
  /// are matched again before their numbers are compared.
  Future<List<MediaVideo>> _earlierVideos(
    EarlierBounds bounds,
    DateTime now,
  ) async {
    final folders = (await _settings.load()).watchedFolders;
    final recorded = await _phone.volumeVersions();
    final candidates = <MediaVideo>[];
    for (final volume in await _bridge.volumes()) {
      if (!volume.isMounted) continue;
      final List<MediaVideo> rows;
      try {
        await _rebuilds.catchUp(volume, recorded, now: now);
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
  ref.watch(zoneSyncProvider),
  ref.watch(mediaWorkQueueProvider),
  ref.watch(clockProvider),
  ref.watch(backgroundBridgeProvider),
);
