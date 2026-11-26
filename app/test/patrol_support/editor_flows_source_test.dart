import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The editors and reels Patrol flows cannot run here (no device), so what
/// moved in Phase 12B (D-197) is guarded in the source: choosing clips is the
/// reel page's dock, the editor sheet opens with every clip, and the picking
/// screen is only for adding clips to an edit.
void main() {
  final editors = File('patrol_test/editors_test.dart').readAsStringSync();
  final reels = File('patrol_test/reels_test.dart').readAsStringSync();

  /// The text of the function of [source] that starts with [signature], to
  /// its end.
  String bodyOf(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0), reason: '$signature exists');
    return source.substring(start, source.indexOf('\n}\n', start));
  }

  group('editors_test.dart', () {
    test('_editAll replaces the picking screen: Edit video, then the sheet '
        'of every clip (a single clip has the plain title)', () {
      expect(editors, isNot(contains('_pickAllAndContinue')));
      final all = bodyOf(editors, 'Future<void> _editAll(');
      expect(all, contains(r'tapWhenStill($, find.byType(TtFab))'));
      expect(all, contains('editorSheetTitleAll(count)'));
      // F9: one clip is not "all": its title is the plain one.
      expect(all, contains('count > 1'));
      expect(all, contains('editorSheetTitle(1)'));
      expect(all, isNot(contains('selectionSelectAll')));
      expect(all, isNot(contains('edit-select-continue')));
      expect(all, isNot(contains('_pickScreen')));
    });

    test('the picking screen is driven only in add mode (Add later)', () {
      final uses = RegExp('edit-select-copy').allMatches(editors).length;
      expect(uses, 1, reason: 'only Copy to the VN folder continues from it');
      expect(
        bodyOf(editors, 'Future<void> _addLater('),
        contains('edit-select-copy'),
      );
      expect(editors, isNot(contains('edit-select-continue')));
      expect(editors, isNot(contains('selectionSelectAll')));
    });

    test('every flow that sends all the clips waits for the every-clip '
        'sheet', () {
      for (final flow in [
        'Future<void> _capcutSend(',
        'Future<void> _notInstalled(',
        'Future<void> _cancelCopy(',
        'Future<String> _startVnSession(',
      ]) {
        expect(bodyOf(editors, flow), contains('_editAll('), reason: flow);
      }
      // The sheet that stays open after a tap on the greyed row is the
      // every-clip one, not "Edit 3 clips in…".
      final off = bodyOf(editors, 'Future<void> _notInstalled(');
      expect(off, contains('editorSheetTitleAll(3)'));
      expect(off, isNot(contains('editorSheetTitle(3)')));
      // After the send the sheet is gone, not the picking screen.
      final send = bodyOf(editors, 'Future<void> _capcutSend(');
      expect(send, contains('editorSheetTitleAll(3)'));
      expect(send, isNot(contains('_pickScreen')));
    });

    test('every editor row is tapped once the sheet has stopped sliding in '
        '(a raw tap on the first frame is lost on the S24)', () {
      // The old flows ran on the S24 with Continue in front of the sheet; the
      // sheet now opens straight from Edit video, so its first frames move.
      expect(
        editors,
        isNot(contains(r'$(_editorRow(')),
        reason: 'no raw Patrol tap of an editor row',
      );
      for (final flow in [
        'Future<void> _capcutSend(',
        'Future<void> _cancelCopy(',
        'Future<String> _startVnSession(',
        'Future<void> _chooseClips(',
      ]) {
        expect(
          bodyOf(editors, flow),
          contains(r'tapWhenStill($, _editorRow('),
          reason: flow,
        );
      }
      // The greyed row is tapped through the tester on purpose (it has no
      // handler to wait for), and the only other row use is a read.
      expect(
        bodyOf(editors, 'Future<void> _notInstalled('),
        contains(r'$.tester.tap(capcut, warnIfMissed: false)'),
      );
    });

    test('the Edit tap waits until the button is on (a tap on the disabled '
        'one is lost and the sheet wait then times out)', () {
      final flow = bodyOf(editors, 'Future<void> _chooseClips(');
      expect(flow, contains(r'tapWhenStill($, dockEdit(), enabled: true)'));
      expect(flow, isNot(contains(r'tapWhenStill($, dockEdit())')));
    });

    test('Remove during a session takes the dock action', () {
      final flow = bodyOf(editors, 'Future<void> _removeDuringSession(');
      expect(
        flow,
        contains(r'tapWhenStill($, dockAction(_l10n.selectionDockRemove))'),
      );
      expect(flow, isNot(contains('selectionRemove)')));
    });

    test('Choose clips: hold one, tap another, Edit 2 clips, then the next '
        'Edit video says Last used', () {
      // The title is one string, written over three lines.
      final joined = editors.replaceAll(RegExp(r"'\s*\n\s*'"), '');
      expect(
        joined,
        contains(
          "'Choose clips: hold one, tap another, Edit 2 clips sends exactly "
          'those to CapCut in shooting order; the next Edit video lists '
          "CapCut first, Last used'",
        ),
      );
      final flow = bodyOf(editors, 'Future<void> _chooseClips(');
      // Hold one, tap another.
      expect(flow, contains('longPress'));
      expect(flow, contains('_l10n.selectionCount(2)'));
      expect(flow, contains('_l10n.selectionDockEdit(2)'));
      // Edit 2 clips from the dock; the sheet is not the every-clip one.
      expect(flow, contains(r'tapWhenStill($, dockEdit(), enabled: true)'));
      expect(flow, contains('_l10n.editorSheetTitle(2)'));
      // Exactly those two, in shooting order, to CapCut.
      expect(flow, contains('EditorApp.capcut.packageName'));
      expect(flow, contains('intent.uris.length, 2'));
      expect(flow, contains('[reel.labels.first, reel.labels.last]'));
      expect(flow, contains('intent.clipDataCount, 2'));
      // The session ends (the tear-down would too), then Edit video again.
      expect(flow, contains('_doneEditing('));
      final end = flow.indexOf('_doneEditing(');
      final again = flow.indexOf('_editAll(', end);
      expect(again, greaterThan(end), reason: 'Edit video after Done editing');
      expect(flow, contains('_l10n.editorLastUsed'));
      expect(flow, contains('getTopLeft'), reason: 'CapCut is listed first');
    });

    test('the new flow is registered once, with the scenario shell', () {
      expect(RegExp(r'_chooseClips\(\$, env\)').allMatches(editors).length, 1);
      expect(editors, contains(r'_scenario($, (env) => _chooseClips('));
    });
  });

  group('reels_test.dart', () {
    test('Remove after the hold is the dock action, not a bar icon', () {
      expect(
        reels,
        contains(r'tapWhenStill($, dockAction(_l10n.selectionDockRemove))'),
      );
      expect(reels, isNot(contains('_l10n.selectionRemove')));
    });

    test("the empty Home keeps the empty state's New reel button", () {
      expect(reels, contains(r'home.$(_l10n.reelsNewReel).tap()'));
      expect(reels, isNot(contains('newReelButton')));
    });
  });
}
