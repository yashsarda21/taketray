import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';

import '../../../support/reel_summaries.dart';

List<int> ids(List<ReelSummary> reels) => [for (final r in reels) r.reel.id];

void main() {
  // Newest first, as the repository gives them (D-84).
  final reels = [
    testSummary(9, status: ReelStatus.published),
    testSummary(8),
    testSummary(7, status: ReelStatus.ready),
    testSummary(5),
    testSummary(4, status: ReelStatus.published),
    testSummary(2, status: ReelStatus.published),
  ];

  group('filterCounts', () {
    test('counts per status', () {
      expect(filterCounts(reels), {
        ReelFilter.all: 6,
        ReelFilter.collecting: 2,
        ReelFilter.ready: 1,
        ReelFilter.published: 3,
      });
    });

    test('no reels: every filter is there, with zero', () {
      expect(filterCounts(const []), {for (final f in ReelFilter.values) f: 0});
    });

    test('a status nobody has counts zero, not missing', () {
      final counts = filterCounts([testSummary(1, status: ReelStatus.ready)]);

      expect(counts[ReelFilter.collecting], 0);
      expect(counts[ReelFilter.published], 0);
      expect(counts[ReelFilter.ready], 1);
      expect(counts[ReelFilter.all], 1);
    });
  });

  group('applyFilter', () {
    test('all keeps the createdAt order', () {
      expect(ids(applyFilter(reels, ReelFilter.all)), [9, 8, 7, 5, 4, 2]);
    });

    test('filter keeps order', () {
      expect(ids(applyFilter(reels, ReelFilter.collecting)), [8, 5]);
      expect(ids(applyFilter(reels, ReelFilter.ready)), [7]);
      expect(ids(applyFilter(reels, ReelFilter.published)), [9, 4, 2]);
    });

    test('a filter nobody matches gives an empty list', () {
      final collecting = [testSummary(1), testSummary(2)];

      expect(applyFilter(collecting, ReelFilter.published), isEmpty);
    });

    test('does not change the list it is given', () {
      final given = [...reels];

      applyFilter(given, ReelFilter.ready);

      expect(ids(given), ids(reels));
    });

    test('each filter shows exactly as many reels as it counts', () {
      final counts = filterCounts(reels);

      for (final f in ReelFilter.values) {
        expect(applyFilter(reels, f), hasLength(counts[f]), reason: '$f');
      }
    });
  });
}
