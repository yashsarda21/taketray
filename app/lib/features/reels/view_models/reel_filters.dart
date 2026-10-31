import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';

/// Which reels Home shows: all of them, or those at one stage.
enum ReelFilter {
  all(null),
  collecting(ReelStatus.collecting),
  ready(ReelStatus.ready),
  published(ReelStatus.published);

  ReelFilter(this.status);

  /// The status a reel needs to pass, or null for [all].
  final ReelStatus? status;
}

/// How many reels each filter shows, over all of [reels]. Every filter is
/// there, with zero when no reel passes it.
Map<ReelFilter, int> filterCounts(List<ReelSummary> reels) => {
  for (final filter in ReelFilter.values)
    filter: applyFilter(reels, filter).length,
};

/// The reels of [reels] that pass [filter], in the order they came: Home gets
/// them newest first, and the filter must not reorder them. A new list;
/// [reels] is not changed.
List<ReelSummary> applyFilter(List<ReelSummary> reels, ReelFilter filter) {
  final status = filter.status;
  return [
    for (final summary in reels)
      if (status == null || summary.reel.status == status) summary,
  ];
}
