import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The share Patrol flows cannot run here (no device), so the rules that keep
/// them safe are guarded in the source (D-169): no real link is ever opened,
/// only the test's own reels are touched, the share screen is never closed or
/// driven by Android's Back, a tap is never at a point, and the tear-down runs
/// every step and leaves the app onboarded.
void main() {
  final source = File('patrol_test/share_test.dart').readAsStringSync();
  final screen = File('patrol_test/support/share_screen.dart')
      .readAsStringSync();

  /// The text of the function that starts with [signature], to its end.
  String bodyOf(String signature, [String? text]) {
    final from = text ?? source;
    final start = from.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0), reason: '$signature exists');
    return from.substring(start, from.indexOf('\n}\n', start));
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
    expect(source, isNot(contains('PigeonLinksBridge')));
    expect(source, isNot(contains('LinksHostApi')));
    expect(
      bodyOf('void _flowTest('),
      contains('final links = PatrolLinksBridge();'),
    );
  });

  test('only an onboarded flow gets the onboarded override', () {
    final start = bodyOf('Future<void> _startApp(');
    expect(start, contains('if (onboarded) ...onboardedOverrides'));
  });

  test('the flows touch only TakeTray Test Share reels', () {
    expect(
      source,
      contains("const String _reelPrefix = 'TakeTray Test Share ';"),
    );
    final delete = bodyOf('Future<void> _deleteTestReels(');
    expect(delete, contains('reel.name.startsWith(_reelPrefix)'));
    // Deleted before the flow (in _prepare) and after it (in _tearDown).
    expect(bodyOf('Future<void> _prepare('), contains('_deleteTestReels('));
    expect(bodyOf('Future<void> _tearDown('), contains('_deleteTestReels('));
    // Every reel a flow makes is one of the three constants.
    expect(RegExp('_reel[ABC] =').allMatches(source), hasLength(3));
    for (final name in ['A', 'B', 'C']) {
      expect(
        source,
        contains("const String _reel$name = '\${_reelPrefix}$name';"),
      );
    }
  });

  test('a share is only started through the debug hook, with test texts', () {
    expect(
      RegExp(r'startShare\((\w+)\)').allMatches(source).map((m) => m.group(1)),
      ['_shareLinkA', '_shareLinkB', '_captionAlone', '_shareLinkC'],
    );
    // The shared links are made-up Instagram codes, never a real reel.
    final links = RegExp(r'https://[^\s,\x27]+').allMatches(source);
    expect(links, isNotEmpty);
    for (final link in links) {
      expect(
        link.group(0),
        matches(r'^https://www\.instagram\.com/(reel|p)/TTTEST\d/'),
      );
    }
    expect(source, isNot(contains('Intent(')));
    expect(source, isNot(contains('adb')));
  });

  test('nothing is tapped at a point, through adb or with Android Back', () {
    for (final text in [source, screen]) {
      expect(text, isNot(contains('tapAt(')));
      expect(text, isNot(contains('adb')));
      expect(text, isNot(contains('pressBack')));
      expect(text, isNot(contains('PlatformAutomator')));
      expect(text, isNot(contains('pressHome')));
    }
  });

  test('the share screen is typed into with the keyboard left alone', () {
    // The default closes the keyboard with Back, which closes the sheet.
    expect(screen, contains('keyboardBehavior: KeyboardBehavior.alternative'));
    expect(screen, isNot(contains('showAndDismiss')));
    expect(RegExp(r'enterText\(').allMatches(source), hasLength(2));
    // The app's own fields are never typed into.
    expect(source, isNot(contains(r'$(field)')));
    expect(source, isNot(contains('hideKeyboard')));
  });

  test('no flow turns Shooting mode on or off, and one reads it back', () {
    expect(source, isNot(contains('turnShootingOn')));
    expect(source, isNot(contains('turnShootingOff')));
    expect(source, isNot(contains('.setOn(')));
    expect(bodyOf('Future<void> _prepare('), contains('phone.loadShooting()'));
    final tearDown = bodyOf('Future<void> _tearDown(');
    expect(tearDown, contains('phone.loadShooting()'));
    expect(tearDown, contains("throw TestFailure('Shooting mode changed"));
  });

  test('the tear-down runs every step and throws the first error last', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    expect(tearDown, contains('first ??= (error, stack)'));
    // An open share screen first, then the app's settings and the background,
    // then the app closed, then the database with a container of its own.
    final order = [
      'env.screen.closeIfOpen(',
      'settingsRepositoryProvider)\n          .save(before)',
      'backgroundSyncProvider',
      'SizedBox.shrink()',
      '_deleteTestReels(',
    ].map(tearDown.indexOf).toList();
    expect(order, everyElement(greaterThanOrEqualTo(0)));
    expect(order, orderedEquals([...order]..sort()));
    expect(tearDown, contains('Error.throwWithStackTrace(error, stack)'));
  });

  test('onboarding is done after every flow, flow 4 included', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    final last = tearDown.indexOf('_withDatabase(');
    expect(last, greaterThanOrEqualTo(0));
    final closure = tearDown.substring(last);
    expect(closure, contains('phone.markOnboardingDone()'));
    expect(closure, contains('phone.markIntroPlayed()'));
    // Before anything in the closure that could throw and skip it.
    expect(
      closure.indexOf('markOnboardingDone'),
      lessThan(closure.indexOf('_deleteTestReels(')),
    );
    expect(
      closure.indexOf('markOnboardingDone'),
      lessThan(closure.indexOf('shootingBefore')),
    );
    // Flow 4 is the one that starts not onboarded.
    final flows = bodyOf('void main()');
    expect(flows, contains('_beforeOnboarding'));
    final four = flows.substring(flows.indexOf('_beforeOnboarding'));
    expect(four, contains('onboarded: false'));
    expect(
      RegExp('onboarded: false').allMatches(flows),
      hasLength(1),
      reason: 'no other flow un-onboards the app',
    );
  });

  test('flow 4 deletes only the three first-launch flags', () {
    final prepare = bodyOf('Future<void> _prepare(');
    for (final key in [
      'onboardingDoneKey',
      'introPlayedKey',
      'homeTipSeenKey',
    ]) {
      expect(prepare, contains('PhoneStateRepository.$key'));
    }
    expect(prepare, isNot(contains('shootingModeKey')));
    expect(prepare, isNot(contains('notificationsAskedKey')));
  });

  test('a share screen left open is closed only by its own words', () {
    final tearDown = bodyOf('Future<void> _tearDown(');
    expect(tearDown, contains('title: _l10n.saveReferenceTitle'));
    expect(tearDown, contains('title: _l10n.saveReferenceNotALinkTitle'));
    expect(tearDown, contains('title: _l10n.saveReferenceSavedTitle'));
    expect(tearDown, contains('button: _l10n.cancel'));
    expect(tearDown, contains('button: _l10n.saveReferenceClose'));
    expect(tearDown, contains('button: _l10n.saveReferenceDone'));
    // The close goes through the guarded call, never a bare tap.
    expect(tearDown, isNot(contains('.tap(')));
    final close = bodyOf('Future<bool> closeIfOpen(', screen);
    expect(close, contains('if (open == null) return closed;'));
  });

  test('flows 2 and 4 need an empty phone and say so', () {
    final prepare = bodyOf('Future<void> _prepare(');
    expect(prepare, contains('if (needsNoReels)'));
    expect(prepare, contains('clear the data of app.taketray.dev'));
    final flows = bodyOf('void main()');
    expect(RegExp('needsNoReels: true').allMatches(flows), hasLength(2));
  });

  test('an absent check follows a positive one on the same screen', () {
    // Flow 3: the Save button is absent only after the "not a link" title.
    final flow = bodyOf('Future<void> _notALink(');
    final title = flow.indexOf('_l10n.saveReferenceNotALinkTitle');
    final absent = flow.indexOf(
      'await screen.isShown(_l10n.referenceSaveButton)',
    );
    expect(title, greaterThanOrEqualTo(0));
    expect(absent, greaterThan(title));
    // Flow 4: "held, not opened" follows the welcome's own wait.
    final four = bodyOf('Future<void> _beforeOnboarding(');
    final waitWelcome = four.indexOf(
      'the welcome, still showing after Open reel',
    );
    expect(waitWelcome, greaterThanOrEqualTo(0));
    final held = four.indexOf(r'expect($(ReelDetailScreen).exists, isFalse');
    expect(held, greaterThan(waitWelcome));
  });

  test('a sheet that was saved is waited for before Done and Open reel', () {
    for (final flow in ['_existingReel', '_newReel', '_beforeOnboarding']) {
      final body = bodyOf('Future<void> $flow(');
      final saved = body.indexOf('waitFor(\n    _l10n.saveReferenceSavedTitle');
      expect(saved, greaterThanOrEqualTo(0), reason: flow);
      final leave = body.contains('saveReferenceDone')
          ? body.indexOf('saveReferenceDone')
          : body.indexOf('saveReferenceOpenReel');
      expect(leave, greaterThan(saved), reason: flow);
      // After leaving it waits for the sheet to be gone.
      expect(body, contains('waitGone('), reason: flow);
    }
  });

  group('the four flows are skipped (D-169 item 8)', () {
    // A Patrol build cannot start ShareActivity's shareMain: Flutter drops the
    // library uri and looks it up in the root library, which in a Patrol build
    // is test_bundle.dart. The flows stay written, but must not run, and must
    // not silently start running or silently disappear.
    test('one shared reason constant holds the reason', () {
      expect(
        RegExp('const String _skipReason =').allMatches(source),
        hasLength(1),
      );
      final start = source.indexOf('const String _skipReason =');
      final reason = source.substring(start, source.indexOf(';\n', start));
      for (final phrase in [
        'D-169 item 8',
        'shareMain',
        'root library',
        'test_bundle.dart',
        'Phase 9B hand checks',
      ]) {
        expect(reason, contains(phrase));
      }
    });

    test('every flow goes through _flowTest, and there are exactly four', () {
      final calls = RegExp(
        r'^  _flowTest\(',
        multiLine: true,
      ).allMatches(bodyOf('void main() {')).toList();
      expect(calls, hasLength(4));
      // The only patrolTest in the file is the one _flowTest makes.
      expect(RegExp(r'patrolTest\(').allMatches(source), hasLength(1));
      expect(
        RegExp(r'patrolTest\(').allMatches(bodyOf('void _flowTest(')),
        hasLength(1),
      );
    });

    test('_flowTest skips on the reason, with no way to run a flow', () {
      final flow = bodyOf('void _flowTest(');
      // Patrol 4.10 takes a bool: a non-empty reason means skipped.
      expect(flow, contains('final skip = _skipReason.isNotEmpty;'));
      expect(flow, contains('patrolTest(description, skip: skip,'));
      expect(source, isNot(contains('skip: false')));
      expect(source, isNot(contains('skip = false')));
      // No flow can opt out of the skip.
      expect(flow, isNot(contains('bool skip')));
      expect(bodyOf('void main() {'), isNot(contains('skip')));
    });

    test(
      'dev-setup says the flows are skipped and the hand checks prove it',
      () {
        final setup = File('../docs/dev-setup.md').readAsStringSync();
        final start = setup.indexOf('### Running `share_test.dart`');
        expect(start, greaterThanOrEqualTo(0));
        final next = setup.indexOf('\n### ', start + 1);
        final section = setup.substring(start, next < 0 ? setup.length : next);
        expect(section, contains('skipped'));
        expect(section, contains('D-169 item 8'));
        expect(section, contains('test_bundle.dart'));
        expect(section, contains('hand checks'));
        // The old run instruction is gone: nothing tells anyone to run it.
        expect(section, isNot(contains('tool/patrol test')));
      },
    );
  });
}
