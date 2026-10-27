import 'package:taketray/domain/models/zone_entry.dart';

/// The zone the phone was in at [instant]: the `zoneId` of the last entry
/// whose `at` is at or before it, or null when [instant] is before the first
/// entry (or the timeline is empty).
///
/// [timeline] must be sorted by `at`, oldest first; it is searched by
/// halving, so a long timeline stays cheap.
String? zoneAt(List<ZoneEntry> timeline, DateTime instant) {
  // Find the first entry strictly after the instant; the one before it wins.
  var low = 0;
  var high = timeline.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (timeline[middle].at.isAfter(instant)) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return low == 0 ? null : timeline[low - 1].zoneId;
}
