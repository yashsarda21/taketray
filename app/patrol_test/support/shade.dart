import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'own_texts.dart';
import 'test_background.dart';

/// TakeTray's own notifications in the notification shade, found and tapped by
/// their text only (the phone rule).
///
/// What these never do: list the shade, read a notification's text for
/// anything but the one string asked about, or tap anything that is not a
/// notification found by a text only TakeTray writes, matched exactly
/// (`OwnText`, never a part of a text). The Still shooting? "Turn off" button
/// is not tapped at all: the debug channel fires its `PendingIntent`
/// (`TestBackground.pressStillTurnOff`). Nothing is printed from the shade.
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
