import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'own_texts.dart';
import 'shade_geometry.dart';
import 'test_background.dart';

/// TakeTray's own notifications in the notification shade, found and tapped by
/// their text only (the phone rule).
///
/// What these never do: list the shade, read a notification's text for
/// anything but the one string asked about, or tap anything that is not
/// (a) a notification found by a text only TakeTray writes, matched exactly
/// (`OwnText`, never a part of a text), or (b) TakeTray's own Still shooting?
/// button, tapped at the spot two looks agreed on (`tapOwnButton`). Nothing is
/// printed from the shade: failures say how many views matched, not what they
/// said.
///
/// Opening the shade takes the focus from the app, and Android gives it back
/// when the shade closes: the app sees a pause and a resume, scans, and
/// removes the new-clips notification. A test that needs that notification
/// to stay asks the debug channel (`TestBackground.activeNotifications`)
/// instead of the shade.

/// Opens the shade.
Future<void> openShade(PatrolIntegrationTester $) =>
    $.platform.mobile.openNotifications();

/// Closes the shade, and is harmless when it is closed already: it presses
/// Home. Not Back (Patrol's own shade closer is a Back key press): with the
/// shade closed, Back finishes the app's root activity, which stops
/// the Flutter engine and kills the running test (`EOFException`, seen on the
/// S24, 2026-11-06). Home leaves the app alive in the background; a flow that
/// needs it in front calls `openApp`.
Future<void> closeShade(PatrolIntegrationTester $) =>
    $.platform.mobile.pressHome();

/// The views [selector] finds, flattened. Empty when none (Patrol reports
/// "nothing matches" in different ways).
Future<List<AndroidNativeView>> _views(
  PatrolIntegrationTester $,
  AndroidSelector selector,
) async {
  try {
    final response = await $.platform.android.getNativeViews(selector);
    final all = <AndroidNativeView>[];
    void walk(AndroidNativeView view) {
      all.add(view);
      view.children.forEach(walk);
    }

    response.roots.forEach(walk);
    return all;
  } on Object {
    return const [];
  }
}

/// The screen bounds of the views whose text is exactly [text].
Future<List<Rect>> _boundsOf(PatrolIntegrationTester $, String text) async =>
    (await _views(
      $,
      AndroidSelector(text: text),
    )).where((v) => v.text == text).map(_bounds).toList();

/// Whether the open shade shows a view whose text is exactly [text].
Future<bool> shadeShows(PatrolIntegrationTester $, OwnText text) async {
  final views = await _views($, AndroidSelector(text: text.value));
  return views.any((v) => text.matches(v.text));
}

/// Waits until the open shade shows [text] and returns how long it took
/// since [since] started; fails after [timeout]. A poll is a few hundred
/// milliseconds, so the time is that precise.
Future<Duration> waitForShade(
  PatrolIntegrationTester $,
  OwnText text, {
  required Stopwatch since,
  Duration timeout = const Duration(seconds: 60),
  TestBackground? background,
}) async {
  // A wait for the job's notification is read against the phone's heat: a
  // hot phone fails at once, and a timeout says what the heat was.
  await background?.requireCool();
  final deadline = DateTime.now().add(timeout);
  while (!await shadeShows($, text)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for the shade to show '
        'a TakeTray notification'
        '${await background?.thermalNote() ?? ''}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return since.elapsed;
}

/// Waits until the open shade no longer shows [text]; fails after [timeout].
Future<void> waitForShadeToLose(
  PatrolIntegrationTester $,
  OwnText text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (await shadeShows($, text)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for a TakeTray '
        'notification to leave the shade',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

/// Taps the notification whose text is exactly [text] (open shade).
Future<void> tapNotification(
  PatrolIntegrationTester $,
  OwnText text, {
  Duration timeout = const Duration(seconds: 10),
}) => $.platform.mobile.tapOnNotificationBySelector(
  AndroidSelector(text: text.value),
  timeout: timeout,
);

Rect _bounds(AndroidNativeView v) => Rect.fromLTRB(
  v.visibleBounds.minX,
  v.visibleBounds.minY,
  v.visibleBounds.maxX,
  v.visibleBounds.maxY,
);

/// Taps [button] of TakeTray's own notification whose text is exactly
/// [ownText] (open shade).
///
/// It looks at the shade twice (the views with [ownText], with the button's
/// label and with its sibling's label, each by its exact text) and taps a
/// point, not a selector: the centre of the one view both looks agree is
/// TakeTray's own button (`ownButtonTapPoint`: below TakeTray's own text, on
/// one row with TakeTray's other button). A selector would be resolved again
/// by Android, in its own order, and could reach another app's "Turn off".
/// The point is a fraction of the real display, read from the phone right
/// after the second look ([background]'s `display`): Flutter's own size goes
/// stale while the app is in the background. The phone must be upright
/// (rotation 0, portrait) and that size must be Flutter's display's.
///
/// When the looks find no such view, or disagree, or the display is not
/// upright or cannot be read, the test fails and nothing is tapped. A phone
/// that hides a notification's buttons until it is expanded fails here,
/// saying so.
Future<void> tapOwnButton(
  PatrolIntegrationTester $, {
  required OwnText ownText,
  required StillButton button,
  required TestBackground background,
}) async {
  Future<ShadeLook> look() async => ShadeLook(
    anchors: await _boundsOf($, ownText.value),
    buttons: await _boundsOf($, button.label),
    siblings: await _boundsOf($, button.sibling.label),
  );

  final first = await look();
  final second = await look();
  PhoneDisplay? display;
  try {
    display = await background.display();
  } on Object {
    display = null; // Unknown: never a guess.
  }
  // Pixels only: what the guard measured, for the run's log.
  debugPrint('shade look 1: ${first.numbers}');
  debugPrint('shade look 2: ${second.numbers}');
  final point = ownButtonTapPoint(
    first: first,
    second: second,
    display: display,
    flutterDisplay: $.tester.view.display.size,
  );
  if (point == null) {
    final upright =
        display != null &&
        display.rotation == 0 &&
        display.height > display.width;
    final state = display == null
        ? 'unknown'
        : (upright ? 'upright' : 'not upright');
    throw TestFailure(
      'No own button tapped: ${second.anchors.length} own text(s), '
      '${second.buttons.length} candidate(s), ${second.siblings.length} '
      'sibling(s), display $state. '
      'Is the phone upright with auto-rotate off, the notification expanded '
      'and the shade still?',
    );
  }
  await $.platform.android.tapAt(point);
}
