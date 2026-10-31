import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/reels/view_models/reel_picker.dart';

import '../../../support/reel_summaries.dart';

void main() {
  group('pickerSections', () {
    test('picker excludes the current reel', () {
      final sections = pickerSections([
        testSummary(1),
        testSummary(2, status: ReelStatus.ready),
        testSummary(3),
      ], excludeReelId: 3);

      final ids = [...sections.collecting, ...sections.other];
      expect(ids.map((s) => s.reel.id), unorderedEquals([1, 2]));
    });

    test('picker sections Collecting then Other reels', () {
      final sections = pickerSections([
        testSummary(4, status: ReelStatus.published),
        testSummary(3),
        testSummary(2, status: ReelStatus.ready),
        testSummary(1),
      ], excludeReelId: 99);

      expect(sections.collecting.map((s) => s.reel.id), [3, 1]);
      // Ready to edit and Published share "Other reels", in the order given.
      expect(sections.other.map((s) => s.reel.id), [4, 2]);
    });

    test('no reels at all gives two empty sections', () {
      final sections = pickerSections(const [], excludeReelId: 1);

      expect(sections.collecting, isEmpty);
      expect(sections.other, isEmpty);
    });

    test('the only reel being the current one leaves nothing', () {
      final sections = pickerSections([testSummary(1)], excludeReelId: 1);

      expect(sections.collecting, isEmpty);
      expect(sections.other, isEmpty);
    });
  });

  group('togglePick', () {
    test('several reels can be picked, in the order they were picked', () {
      var picked = <int>[];
      picked = togglePick(picked, 5, multi: true);
      picked = togglePick(picked, 2, multi: true);
      picked = togglePick(picked, 9, multi: true);

      expect(picked, [5, 2, 9]);
    });

    test('picking a picked reel again unpicks it', () {
      final picked = togglePick([5, 2, 9], 2, multi: true);

      expect(picked, [5, 9]);
    });

    test('move is single-select: a new pick replaces the old one', () {
      var picked = <int>[];
      picked = togglePick(picked, 5, multi: false);
      picked = togglePick(picked, 2, multi: false);

      expect(picked, [2]);
    });

    test('move keeps the pick when it is tapped again (a radio)', () {
      final picked = togglePick([2], 2, multi: false);

      expect(picked, [2]);
    });

    test('the list given is not changed', () {
      final picked = List<int>.unmodifiable([1]);

      expect(() => togglePick(picked, 2, multi: true), returnsNormally);
      expect(picked, [1]);
    });
  });

  group('pickedAfterCreate', () {
    test('add: the new reel is added to the picks', () {
      expect(pickedAfterCreate([5], 8, multi: true), [5, 8]);
    });

    test('move: the new reel is the only pick', () {
      expect(pickedAfterCreate([5], 8, multi: false), [8]);
    });

    test('add: a reel already picked is not added twice', () {
      expect(pickedAfterCreate([8], 8, multi: true), [8]);
    });
  });
}
