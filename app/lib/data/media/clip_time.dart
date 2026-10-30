import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/media/thumbnail_cache.dart'
    show defaultBridgeTimeout;
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/platform/media_bridge.dart';

export 'package:taketray/domain/models/clip_local_time.dart';

part 'clip_time.g.dart';

// Counts and error codes only: never a zone id or a city, which tell where
// someone was (D-10).
final Logger _log = Logger('clipTime');

/// How many `(zone, instant)` offsets [ClipTimeService] keeps (D-83).
const int clipTimeCacheSize = 4096;

/// One cache entry: a zone id and a UTC instant in milliseconds.
typedef _Key = (String zoneId, int instantMs);

/// Each clip's time where it was shot (spec §8.3a, D-83).
///
/// The zone offsets come from the phone's own time-zone rules through one
/// batched bridge call (`MediaBridge.zoneOffsetsMs`), so TakeTray bundles no
/// zone database. Offsets are cached in memory, by `(zone id, instant)`, for
/// the newest [cacheSize] entries (least recently used goes first).
class ClipTimeService {
  /// [cacheSize] and [bridgeTimeout] are for tests.
  ClipTimeService(
    this._bridge, {
    @visibleForTesting this.cacheSize = clipTimeCacheSize,
    @visibleForTesting Duration bridgeTimeout = defaultBridgeTimeout,
  }) : _timeout = bridgeTimeout;

  final MediaBridge _bridge;
  final Duration _timeout;

  /// How many offsets the cache keeps.
  final int cacheSize;

  /// Offset in ms, or null for a zone the phone does not know. Insertion
  /// order is use order: the first key is the least recently used.
  final LinkedHashMap<_Key, int?> _cache = LinkedHashMap();

  /// The local time of every clip in [clips], by clip id.
  ///
  /// 1. Reads the phone's zone once (`currentZoneId`).
  /// 2. Asks, in one batch, for every `(zone, date taken)` not in the cache:
  ///    the clip's own `timeZoneId`, or the phone's zone when it has none.
  /// 3. A clip whose zone the phone does not know (the answer is null) uses
  ///    the phone's zone instead; only then, and only for the instants not
  ///    already cached, a second batch asks for the phone's zone. The unknown
  ///    answer is cached, so next time that takes no call.
  /// 4. If a bridge call fails, times out or answers with the wrong length,
  ///    the clips it was for use the phone's zone through Dart's own local
  ///    time (`DateTime.toLocal`). The same happens when the phone's zone
  ///    cannot be read. A warning is logged (counts and codes), nothing is
  ///    cached, and nothing throws.
  ///
  /// No clips: no bridge call.
  Future<Map<int, ClipLocalTime>> localTimes(List<Clip> clips) async {
    if (clips.isEmpty) return {};
    final phone = await _phoneZone();
    final known = <_Key, int?>{};

    await _fill({
      for (final c in clips)
        if (c.timeZoneId ?? phone case final zone?) (zone, _ms(c)),
    }, known);

    final unknown = [
      for (final c in clips)
        if (c.timeZoneId case final own?)
          if (known.containsKey((own, _ms(c))) && known[(own, _ms(c))] == null)
            c,
    ];
    if (unknown.isNotEmpty) {
      _log.info(
        '${unknown.length} clips have a time zone the phone does not know; '
        "using the phone's",
      );
      if (phone != null) {
        await _fill({for (final c in unknown) (phone, _ms(c))}, known);
      }
    }

    return {for (final c in clips) c.id: _timeOf(c, phone, known)};
  }

  ClipLocalTime _timeOf(Clip clip, String? phone, Map<_Key, int?> known) {
    final ms = _ms(clip);
    for (final zone in [clip.timeZoneId, phone]) {
      if (zone == null) continue;
      final offset = known[(zone, ms)];
      if (offset != null) {
        return ClipLocalTime(
          wallClock: DateTime.fromMillisecondsSinceEpoch(
            ms + offset,
            isUtc: true,
          ),
          zoneId: zone,
          isPhoneZone: zone == phone,
        );
      }
    }
    // The phone's zone, as Dart knows it.
    final l = clip.fingerprint.dateTakenUtc.toLocal();
    return ClipLocalTime(
      wallClock: DateTime.utc(
        l.year,
        l.month,
        l.day,
        l.hour,
        l.minute,
        l.second,
        l.millisecond,
        l.microsecond,
      ),
      zoneId: phone,
      isPhoneZone: true,
    );
  }

  static int _ms(Clip clip) =>
      clip.fingerprint.dateTakenUtc.millisecondsSinceEpoch;

  /// The phone's zone id, or null (logged) when it cannot be read.
  Future<String?> _phoneZone() async {
    try {
      return await _bridge.currentZoneId().timeout(_timeout);
    } on Exception catch (e) {
      _log.warning("Couldn't read the phone's time zone: ${_reason(e)}");
      return null;
    }
  }

  /// Puts the offset of every key of [keys] into [known]: from the cache
  /// (which counts as a use), else from one bridge call for all the rest,
  /// whose answers go into the cache too. On a failure the rest stay out of
  /// [known] and out of the cache.
  Future<void> _fill(Set<_Key> keys, Map<_Key, int?> known) async {
    final misses = <_Key>[];
    for (final key in keys) {
      if (_cache.containsKey(key)) {
        final offset = _cache.remove(key);
        known[key] = _cache[key] = offset;
      } else {
        misses.add(key);
      }
    }
    if (misses.isEmpty) return;
    final List<int?> answers;
    try {
      answers = await _bridge
          .zoneOffsetsMs(
            [for (final k in misses) k.$1],
            [for (final k in misses) k.$2],
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      _log.warning(
        "Couldn't read the zone offsets of ${misses.length} clips: "
        "${_reason(e)}; using the phone's zone",
      );
      return;
    }
    if (answers.length != misses.length) {
      _log.warning(
        'The phone gave ${answers.length} zone offsets for ${misses.length} '
        "clips; using the phone's zone",
      );
      return;
    }
    for (var i = 0; i < misses.length; i++) {
      known[misses[i]] = answers[i];
      _remember(misses[i], answers[i]);
    }
  }

  void _remember(_Key key, int? offset) {
    _cache[key] = offset;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// An error's code or type, never its message (D-10).
  static String _reason(Exception e) => switch (e) {
    PlatformException(:final code) => code,
    TimeoutException() => 'timeout',
    _ => '${e.runtimeType}',
  };
}

/// The app's one [ClipTimeService], kept for the whole run so its cache is.
@Riverpod(keepAlive: true)
ClipTimeService clipTimeService(Ref ref) =>
    ClipTimeService(ref.watch(mediaBridgeProvider));
