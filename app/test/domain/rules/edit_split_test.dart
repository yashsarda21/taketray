import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/edit_split.dart';

void main() {
  int idOf(int v) => v;

  group('splitForEditing', () {
    test('nothing sent or copied: all new', () {
      final s = splitForEditing<int>(
        [1, 2, 3],
        idOf,
        sentIds: {},
        liveCopyIds: {},
      );
      expect(s.newClips, [1, 2, 3]);
      expect(s.inEdit, isEmpty);
    });

    test('a sent clip and a clip with a live copy are in the edit', () {
      final s = splitForEditing<int>(
        [1, 2, 3],
        idOf,
        sentIds: {1},
        liveCopyIds: {2},
      );
      expect(s.newClips, [3]);
      expect(s.inEdit, [1, 2]);
    });

    test('a copied clip whose copy is gone and that was not sent is new', () {
      // The copy is not in liveCopyIds, so the clip is only "copied once".
      final s = splitForEditing<int>(
        [1, 2],
        idOf,
        sentIds: {},
        liveCopyIds: {2},
      );
      expect(s.newClips, [1]);
      expect(s.inEdit, [2]);
      final gone = splitForEditing<int>(
        [1, 2],
        idOf,
        sentIds: {},
        liveCopyIds: {},
      );
      expect(gone.newClips, [1, 2]);
    });

    test('a sent clip stays in the edit when its copy is gone', () {
      final s = splitForEditing<int>([1], idOf, sentIds: {1}, liveCopyIds: {});
      expect(s.inEdit, [1]);
      expect(s.newClips, isEmpty);
    });

    test('a clip both sent and copied is in the edit once', () {
      final s = splitForEditing<int>([1], idOf, sentIds: {1}, liveCopyIds: {1});
      expect(s.inEdit, [1]);
      expect(s.newClips, isEmpty);
    });

    test('the order is kept in both lists', () {
      final s = splitForEditing<int>(
        [9, 4, 7, 2, 5, 1],
        idOf,
        sentIds: {4, 2},
        liveCopyIds: {1},
      );
      expect(s.newClips, [9, 7, 5]);
      expect(s.inEdit, [4, 2, 1]);
    });

    test('ids in the sets that are not in the list are ignored', () {
      final s = splitForEditing<int>(
        [1, 2],
        idOf,
        sentIds: {50},
        liveCopyIds: {60},
      );
      expect(s.newClips, [1, 2]);
      expect(s.inEdit, isEmpty);
    });

    test('an empty list gives two empty lists', () {
      final s = splitForEditing<int>([], idOf, sentIds: {1}, liveCopyIds: {1});
      expect(s.newClips, isEmpty);
      expect(s.inEdit, isEmpty);
    });

    test('works on any item type through idOf', () {
      final s = splitForEditing<String>(
        ['a1', 'b2'],
        (v) => int.parse(v.substring(1)),
        sentIds: {2},
        liveCopyIds: {},
      );
      expect(s.newClips, ['a1']);
      expect(s.inEdit, ['b2']);
    });
  });

  group('addPicks', () {
    test('fresh when neither sent nor copied', () {
      expect(addPicks([1], sentIds: {}, liveCopyIds: {}), {1: AddPick.fresh});
    });

    test('sentNotCopied when sent without a live copy', () {
      expect(addPicks([1], sentIds: {1}, liveCopyIds: {}), {
        1: AddPick.sentNotCopied,
      });
    });

    test('inFolder when a live copy exists', () {
      expect(addPicks([1], sentIds: {}, liveCopyIds: {1}), {
        1: AddPick.inFolder,
      });
    });

    test('a live copy wins over sent', () {
      expect(addPicks([1], sentIds: {1}, liveCopyIds: {1}), {
        1: AddPick.inFolder,
      });
    });

    test('mixed, in the order given, ignoring unknown ids', () {
      final picks = addPicks(
        [3, 1, 2, 4],
        sentIds: {1, 99},
        liveCopyIds: {2, 98},
      );
      expect(picks.keys.toList(), [3, 1, 2, 4]);
      expect(picks, {
        3: AddPick.fresh,
        1: AddPick.sentNotCopied,
        2: AddPick.inFolder,
        4: AddPick.fresh,
      });
    });

    test('an empty list gives an empty map', () {
      expect(addPicks([], sentIds: {1}, liveCopyIds: {1}), isEmpty);
    });
  });
}
