import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The references Patrol flows cannot run here (no device), so the rules that
/// keep them safe are guarded in the source (D-161): no real link is ever
/// opened, the text is typed the way the 10A harness needs, and nothing is
/// tapped at a point.
void main() {
  final source = File('patrol_test/references_test.dart').readAsStringSync();

  /// The text of the function that starts with [signature], to its end.
  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0), reason: '$signature exists');
    return source.substring(start, source.indexOf('\n}\n', start));
  }

  test('every app that is pumped has the fake links bridge', () {
    final pumps = RegExp(r'pumpWidget\(').allMatches(source).toList();
    // The app, and the empty widget that closes it in the tear-down.
    expect(pumps, hasLength(2));
    final start = bodyOf('Future<void> _startApp(');
    expect(start, contains('linksBridgeProvider.overrideWithValue(env.links)'));
    expect(start, contains(r'restoreResumedLifecycle(env.$)'));
    expect(
      start.indexOf('restoreResumedLifecycle'),
      lessThan(start.indexOf('pumpWidget')),
      reason: 'the lifecycle state is restored before the app is pumped',
    );
    // The real bridge is never made here.
    expect(source, isNot(contains('PigeonLinksBridge')));
    expect(source, isNot(contains('LinksHostApi')));
  });

  test('the fake bridge is what _flowTest makes, one per flow', () {
    final flow = bodyOf('void _flowTest(');
    expect(flow, contains('final links = PatrolLinksBridge();'));
  });

  test('every enterText keeps the keyboard up (the 10A rule)', () {
    final calls = RegExp(r'enterText\(([^;]*)\)').allMatches(source).toList();
    expect(calls, isNotEmpty);
    for (final call in calls) {
      expect(call.group(1), contains('hideKeyboard: false'));
    }
  });

  test('nothing is tapped at a point, through adb or with Android Back', () {
    expect(source, isNot(contains('tapAt(')));
    expect(source, isNot(contains('adb')));
    expect(source, isNot(contains('pressBack')));
    expect(source, isNot(contains('PlatformAutomator')));
  });

  test('the tear-down empties the clipboard and turns Shooting mode off', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    expect(
      tearDown,
      contains("Clipboard.setData(const ClipboardData(text: ''))"),
    );
    expect(tearDown, contains('.setOn(false)'));
    // Each step runs even when one before it threw.
    expect(tearDown, contains('first ??= (error, stack)'));
  });

  test('the tear-down turns Shooting mode off and reads it back', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    final off = tearDown.indexOf('phone.turnShootingOff()');
    expect(off, greaterThanOrEqualTo(0));
    final closed = tearDown.indexOf('SizedBox.shrink()');
    expect(
      tearDown.substring(closed, off),
      contains('if (shootingMayBeOn)'),
      reason: 'a flow that never turns it on is not forced off',
    );
    final read = tearDown.indexOf('phone.loadShooting()', off);
    expect(read, greaterThan(off), reason: 'read back after the off');
    expect(
      tearDown.indexOf('.on)', read),
      greaterThan(read),
      reason: 'and checks it is off',
    );
    expect(tearDown.indexOf('throw TestFailure', read), greaterThan(read));
    // After the app was closed: the last step, with a container of its own.
    expect(off, greaterThan(tearDown.indexOf('SizedBox.shrink()')));
  });

  int fail0(String closure) => closure.indexOf('throw TestFailure');

  test('Shooting mode is read off first in the last step (M28)', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    final last = tearDown.indexOf('_withDatabase((c) async {');
    expect(last, greaterThanOrEqualTo(0));
    final closure = tearDown.substring(last);
    final off = closure.indexOf('phone.turnShootingOff()');
    expect(off, greaterThanOrEqualTo(0));
    expect(
      closure.indexOf('if (shootingMayBeOn)'),
      lessThan(off),
      reason: 'the guard is the first thing in the closure',
    );
    // Its own failure still lets the clean-up run: the check's error is
    // caught into a local, and the clean-up is a second block after it.
    final caught = closure.indexOf('catch (error, stack)');
    expect(caught, greaterThan(fail0(closure)));
    expect(closure.indexOf('checkError = error'), greaterThan(caught));
    // Before anything that could throw and skip it.
    expect(off, lessThan(closure.indexOf('_deleteTestReels(')));
    expect(off, lessThan(closure.indexOf('settingsRepositoryProvider')));
    // And the read-back and the failure come before that work too, and the
    // work comes after the check's catch, so the failure does not skip it.
    final fail = fail0(closure);
    expect(fail, greaterThan(off));
    expect(fail, lessThan(closure.indexOf('_deleteTestReels(')));
    expect(fail, lessThan(closure.indexOf('settingsRepositoryProvider')));
    expect(caught, lessThan(closure.indexOf('_deleteTestReels(')));
  });

  test(
    'the check failure is thrown first, the clean-up failure after (M29)',
    () {
      final tearDown = bodyOf('Future<void> _tearDown(');
      final closure = tearDown.substring(
        tearDown.indexOf('_withDatabase((c) async {'),
      );
      final cleanUp = closure.indexOf('_deleteTestReels(');
      // A clean-up that throws is swallowed when the check failed, and
      // rethrown when it did not.
      final swallow = closure.indexOf('if (checkError == null) rethrow;');
      expect(swallow, greaterThan(cleanUp), reason: 'guards the clean-up');
      expect(closure.indexOf('catch (', cleanUp), lessThan(swallow));
      // Then the check's error, with its stack, is the one thrown.
      final thrown = closure.indexOf(
        'Error.throwWithStackTrace(checkError',
        swallow,
      );
      expect(thrown, greaterThan(swallow));
      // The clean-up is not in a `finally`: a throw there would replace it.
      expect(closure, isNot(contains('} finally {')));
    },
  );

  test('the clipboard is emptied only when a flow wrote to it (M24)', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    final empty = tearDown.indexOf(
      "Clipboard.setData(const ClipboardData(text: ''))",
    );
    final guard = tearDown.lastIndexOf('if (', empty);
    expect(tearDown.substring(guard, empty), contains('env.clipboardTouched'));
    // No static flag: a flow that failed before writing never touches it.
    expect(tearDown.substring(guard, empty), isNot(contains('clipboard ||')));
    expect(tearDown, isNot(contains('required bool clipboard')));
    expect(bodyOf('void _flowTest('), isNot(contains('clipboard:')));
    expect(source, isNot(contains('clipboard: true')));
  });

  test('flow 2 marks the clipboard touched before it writes', () {
    final flow = bodyOf('Future<void> _paste(');
    final mark = flow.indexOf('env.clipboardTouched = true;');
    final firstWrite = flow.indexOf('Clipboard.setData(');
    expect(mark, greaterThanOrEqualTo(0));
    expect(mark, lessThan(firstWrite), reason: 'a failed write is cleaned up');
  });

  test('flow 2: the Home card is read with its references, and the page is '
      'scrolled to the References section (D-196, D-197)', () {
    final flow = bodyOf('Future<void> _paste(');
    // The card says it has the reference (it has no badge any more).
    final read = flow.indexOf('reelCardSemanticsReferences(');
    expect(read, greaterThanOrEqualTo(0), reason: 'the card is read');
    expect(
      flow.substring(read),
      contains('.semanticLabel'),
      reason: "the card's own semantic label is what is compared",
    );
    final tap = flow.indexOf(r'tapWhenStill($, reelCardOf(_reelPaste))');
    expect(tap, greaterThanOrEqualTo(0), reason: 'the card, by its name');
    expect(read, lessThan(tap), reason: 'read, then opened');
    // Home no longer opens the page at its References: the flow scrolls.
    final after = flow.substring(tap);
    expect(after, contains('.scrollTo('));
    expect(
      after.indexOf('.scrollTo('),
      lessThan(after.indexOf(r'section.$(_l10n.referencesHeader(1)).visible')),
      reason: 'scrolled before it asks for the section on screen',
    );
    expect(after, contains(r'$(reelPageOf(reel.id, _reelPaste)).exists'));
    expect(source, isNot(contains('referencesBadgeOf')));
    expect(source, isNot(contains('reelCardReferences(')));
    expect(
      source,
      isNot(contains('scrolled the References section into view')),
    );
  });

  test('flow 3: the New reel form opens from the header pill, with reels on '
      'Home (D-186)', () {
    final flow = bodyOf('Future<void> _reelForm(');
    expect(flow, contains(r'tapWhenStill($, newReelButton())'));
    expect(flow, isNot(contains(r'home.$(_l10n.reelsNewReel)')));
    // Flow 3's card is opened by its name too.
    expect(flow, contains(r'tapWhenStill($, reelCardOf(_reelFormName))'));
  });

  test('flow 4: the References chip of the Shooting mode card is tapped by '
      'its words, once it is still', () {
    final flow = bodyOf('Future<void> _shootingSheet(');
    expect(flow, contains('_referencesChip(_l10n.referencesHeader(3))'));
    expect(flow, contains(r'tapWhenStill($, chip)'));
    expect(flow, isNot(contains('await row.tap()')));
    final start = source.indexOf('Finder _referencesChip(');
    expect(start, greaterThanOrEqualTo(0));
    final chip = source.substring(start, source.indexOf(';\n', start));
    expect(chip, contains('find.byType(InkWell)'), reason: "the chip's button");
    expect(chip, contains('find.byType(ShootingModeSection)'));
  });

  test('the S24 finders (D-161 item 9): no tap on a count, no page by its '
      'name after an open at References', () {
    // A count lies under a ripple: never hit-testable.
    expect(source, isNot(contains(r".$('1').tap()")));
    // A page opened at References has scrolled its name off the screen.
    expect(source, isNot(contains(r'$(ReelDetailScreen).$(_reelPaste)')));
    expect(source, isNot(contains(r'$(ReelDetailScreen).$(_reelShootA)')));
    expect(
      bodyOf('Future<void> _shootingSheet('),
      contains(r'$(reelPageOf(a.id, _reelShootA)).exists'),
    );
  });

  test('flow 2: the clipboard holds a link while the sheet opens', () {
    final flow = bodyOf('Future<void> _paste(');
    final withLink = flow.indexOf(
      'Clipboard.setData(const ClipboardData(text: _captionWithLink))',
    );
    final open = flow.indexOf(r'section.$(_l10n.referencesAddRowTitle).tap()');
    final empty = flow.indexOf('opening the sheet reads nothing');
    final noLink = flow.indexOf(
      'Clipboard.setData(const ClipboardData(text: _captionWithoutLink))',
    );
    expect(withLink, greaterThanOrEqualTo(0));
    expect(withLink, lessThan(open), reason: 'link on the clipboard first');
    expect(open, lessThan(empty));
    expect(empty, lessThan(noLink), reason: 'no-link caption comes after');
  });
}
