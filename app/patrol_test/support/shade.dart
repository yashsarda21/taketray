import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'shade_geometry.dart';

/// TakeTray's own notifications in the notification shade, found and tapped by
/// their text only (the phone rule).
///
/// What these never do: list the shade, read a notification's text for
/// anything but the one string asked about, or tap anything that is not
/// (a) a notification found by a string only TakeTray writes, or (b) a button
/// on the same row as TakeTray's own second button, below TakeTray's own text
/// (`tapOwnButton`). Nothing is printed from the shade: failures say how many
/// views matched, not what they said.
///
/// Opening the shade takes the focus from the app, and Android gives it back
/// when the shade closes: the app sees a pause and a resume, scans, and
/// removes the new-clips notification. A test that needs that notification
/// to stay asks the debug channel (`TestBackground.activeNotifications`)
/// instead of the shade.

/// Opens the shade.
Future<void> openShade(PatrolIntegrationTester $) =>
    $.platform.mobile.openNotifications();

/// Closes the shade. Not an error when it is closed already.
Future<void> closeShade(PatrolIntegrationTester $) async {
  try {
    await $.platform.mobile.closeNotifications();
  } on Object {
    // Closed already (a tap on a notification closes it): nothing to do.
  }
}

/// The views whose text contains `text`, flattened. Empty when none (Patrol
/// reports "nothing matches" in different ways).
Future<List<AndroidNativeView>> _viewsWithText(
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

/// Whether the open shade shows a view whose text contains [text].
Future<bool> shadeShows(PatrolIntegrationTester $, String text) async {
  final views = await _viewsWithText($, AndroidSelector(textContains: text));
  return views.any((v) => (v.text ?? '').contains(text));
}

/// Waits until the open shade shows [text] and returns how long it took
/// since [since] started; fails after [timeout]. A poll is a few hundred
/// milliseconds, so the time is that precise.
Future<Duration> waitForShade(
  PatrolIntegrationTester $,
  String text, {
  required Stopwatch since,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await shadeShows($, text)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for the shade to show '
        'a TakeTray notification',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return since.elapsed;
}

/// Waits until the open shade no longer shows [text]; fails after [timeout].
Future<void> waitForShadeToLose(
  PatrolIntegrationTester $,
  String text, {
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

/// Taps the notification whose text contains [text] (open shade).
Future<void> tapNotification(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 10),
}) => $.platform.mobile.tapOnNotificationBySelector(
  AndroidSelector(textContains: text),
  timeout: timeout,
);

Rect _bounds(AndroidNativeView v) => Rect.fromLTRB(
  v.visibleBounds.minX,
  v.visibleBounds.minY,
  v.visibleBounds.maxX,
  v.visibleBounds.maxY,
);

/// Taps [button] of TakeTray's own notification whose text contains
/// [ownText] (open shade). Only a view with exactly the text [button] that
/// lies below that text and shares a row with a [sibling] button (TakeTray's
/// other button) is tapped (`ownButtonIndex`); with no such view the test
/// fails and taps nothing. A phone that hides a notification's buttons until
/// it is expanded fails here, saying so.
Future<void> tapOwnButton(
  PatrolIntegrationTester $, {
  required String ownText,
  required String button,
  required String sibling,
}) async {
  final anchors = await _viewsWithText(
    $,
    AndroidSelector(textContains: ownText),
  );
  final anchor = anchors.where((v) => (v.text ?? '').contains(ownText));
  if (anchor.length != 1) {
    throw TestFailure(
      'Expected one TakeTray notification text in the shade, found '
      '${anchor.length}',
    );
  }
  final buttons = (await _viewsWithText(
    $,
    AndroidSelector(text: button),
  )).where((v) => v.text == button).toList();
  final siblings = (await _viewsWithText(
    $,
    AndroidSelector(text: sibling),
  )).where((v) => v.text == sibling).toList();
  final index = ownButtonIndex(
    anchor: _bounds(anchor.single),
    candidates: buttons.map(_bounds).toList(),
    siblings: siblings.map(_bounds).toList(),
  );
  if (index == null) {
    throw TestFailure(
      'No own button in the shade: ${buttons.length} candidate(s), '
      '${siblings.length} sibling(s). Is the notification collapsed?',
    );
  }
  await $.platform.android.tap(AndroidSelector(text: button, instance: index));
}
