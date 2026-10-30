import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'zone_sync.g.dart';

/// Brings the time zone changes the native side saw (while the app was not
/// running) into the zone timeline, and adds the phone's zone now (D-72).
class ZoneSync {
  new(this._bridge, this._zones, this._clock);

  final MediaBridge _bridge;
  final ZoneRepository _zones;
  final Clock _clock;

  /// 1. Reads the native list (`pendingZoneChanges`) and the current zone.
  /// 2. Merges the list, plus (now, current zone), into the timeline with
  ///    `recordAll` (time order; repeated neighbours dropped).
  /// 3. Only after that succeeded, tells the native side to forget its
  ///    entries up to the newest one *it* reported. The (now, current zone)
  ///    entry is not native, so it never moves the cut, and with an empty
  ///    list nothing is cleared.
  ///
  /// A failure at any step throws, and the native list stays (the next sync
  /// merges it again, which changes nothing that is already stored).
  Future<void> sync() async {
    final pending = await _bridge.pendingZoneChanges();
    final current = await _bridge.currentZoneId();
    await _zones.recordAll([
      ...pending,
      ZoneEntry(at: _clock.now(), zoneId: current),
    ]);
    if (pending.isEmpty) return;
    await _bridge.clearZoneChangesUpTo(
      pending.map((e) => e.at.millisecondsSinceEpoch).reduce(max),
    );
  }
}

@Riverpod(keepAlive: true)
ZoneSync zoneSync(Ref ref) => ZoneSync(
  ref.watch(mediaBridgeProvider),
  ref.watch(zoneRepositoryProvider),
  ref.watch(clockProvider),
);
