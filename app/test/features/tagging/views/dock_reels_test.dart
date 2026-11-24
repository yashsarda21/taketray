import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/tagging/views/dock_reels.dart';

import '../../../support/reel_summaries.dart';

/// What the full-screen tag player's dock shows (D-181, handoff "Dock",
/// `player2.js` `full()`), from the reels in Home's order, newest first.
void main() {
  /// Reel [id], Collecting unless [status] says otherwise.
  ReelSummary reel(int id, [ReelStatus status = ReelStatus.collecting]) =>
      testSummary(id, status: status);

  List<int> ids(List<ReelSummary> reels) => [for (final r in reels) r.reel.id];

  test('no reels: an empty grid, New reel, no All reels, no Pick several', () {
    final dock = dockReels(const [], multi: false, picked: const []);

    expect(dock.grid, isEmpty);
    expect(dock.newReel, isTrue);
    expect(dock.allReels, isFalse);
    expect(dock.pickSeveral, isFalse);
  });

  test('one Collecting reel: it and New reel; no Pick several', () {
    final dock = dockReels([reel(1)], multi: false, picked: const []);

    expect(ids(dock.grid), [1]);
    expect(dock.newReel, isTrue);
    expect(dock.allReels, isFalse);
    expect(dock.pickSeveral, isFalse);
  });

  test('three Collecting: all three, no All reels', () {
    final dock = dockReels(
      [reel(3), reel(2), reel(1)],
      multi: false,
      picked: const [],
    );

    expect(ids(dock.grid), [3, 2, 1]);
    expect(dock.newReel, isTrue);
    expect(dock.allReels, isFalse);
    expect(dock.pickSeveral, isTrue);
  });

  test('four Collecting: the three newest, All reels', () {
    final dock = dockReels(
      [reel(4), reel(3), reel(2), reel(1)],
      multi: false,
      picked: const [],
    );

    expect(ids(dock.grid), [4, 3, 2]);
    expect(dock.newReel, isTrue);
    expect(dock.allReels, isTrue);
    expect(dock.pickSeveral, isTrue);
  });

  test('two Collecting and one Ready: both, All reels', () {
    // Home's order puts the newest first, whatever its status.
    final dock = dockReels(
      [reel(3, ReelStatus.ready), reel(2), reel(1)],
      multi: false,
      picked: const [],
    );

    expect(ids(dock.grid), [2, 1]);
    expect(dock.newReel, isTrue);
    expect(dock.allReels, isTrue);
    expect(dock.pickSeveral, isTrue);
  });

  test(
    'only Ready reels: an empty grid, New reel, All reels, Pick several',
    () {
      final dock = dockReels(
        [reel(2, ReelStatus.ready), reel(1, ReelStatus.published)],
        multi: false,
        picked: const [],
      );

      expect(dock.grid, isEmpty);
      expect(dock.newReel, isTrue);
      expect(dock.allReels, isTrue);
      expect(dock.pickSeveral, isTrue);
    },
  );

  test('picking: the three plus a picked Ready reel and a picked 5th '
      'Collecting, in Home order', () {
    final ordered = [
      reel(7),
      reel(6, ReelStatus.ready),
      reel(5),
      reel(4),
      reel(3, ReelStatus.published),
      reel(2),
      reel(1),
    ];

    // Picked in another order than Home's: the 5th Collecting reel (1), then
    // the Ready one (6). Reel 3 (Published) is not picked.
    final dock = dockReels(ordered, multi: true, picked: const [1, 6]);

    expect(ids(dock.grid), [7, 5, 4, 6, 1]);
    expect(dock.newReel, isFalse);
    expect(dock.allReels, isTrue);
    expect(dock.pickSeveral, isTrue);
  });

  test('picking: a picked reel among the three is not repeated; no New '
      'reel', () {
    final ordered = [reel(4), reel(3), reel(2), reel(1)];

    final dock = dockReels(ordered, multi: true, picked: const [3, 1]);

    expect(ids(dock.grid), [4, 3, 2, 1]);
    expect(dock.newReel, isFalse);
    expect(dock.allReels, isTrue);
  });

  test('picking with two Collecting reels and nothing else: All reels '
      '(New reel is only there while picking)', () {
    final dock = dockReels([reel(2), reel(1)], multi: true, picked: const []);

    expect(ids(dock.grid), [2, 1]);
    expect(dock.newReel, isFalse);
    expect(dock.allReels, isTrue);
  });

  test('not picking: picks are ignored', () {
    // A stale pick list (the controller clears it, but the rule stands alone).
    final dock = dockReels(
      [reel(5), reel(4), reel(3), reel(2), reel(1)],
      multi: false,
      picked: const [1],
    );

    expect(ids(dock.grid), [5, 4, 3]);
  });

  test('picking: a picked id that is no reel any more is left out', () {
    final dock = dockReels([reel(2), reel(1)], multi: true, picked: const [99]);

    expect(ids(dock.grid), [2, 1]);
  });
}
