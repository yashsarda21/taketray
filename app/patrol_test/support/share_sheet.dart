import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'system_dialogs.dart';

/// Android's share sheet (the chooser), found by resource id only, never by
/// text: no app's name, no contact, nothing the sheet suggests is read.
///
/// The chooser is drawn by the system: `android:id/...` up to Android 13, and
/// the `com.android.intentresolver` package from Android 14 (the S24 runs
/// One UI on Android 14 or later). The ids below are AOSP's, written from its
/// layouts; they have not been seen on the S24 yet, which is why
/// [waitForShareSheet] fails with the list of ids on the screen (no text):
/// the phone run of D-152 fixes this list if it needs to.
///
/// Nothing is ever tapped in the sheet. The flow closes it with Android's
/// Back, so no app is chosen and nothing is sent.
const List<String> _chooserIds = [
  'android:id/resolver_list',
  'android:id/profile_pager',
];

/// Any id in this package is the chooser's own (Android 14 and later).
const String _chooserPackagePrefix = 'com.android.intentresolver:id/';

/// Whether [resourceId] is one of the chooser's.
bool isChooserId(String? resourceId) =>
    resourceId != null &&
    (_chooserIds.contains(resourceId) ||
        resourceId.startsWith(_chooserPackagePrefix));

/// Whether something is on top of the app by its lifecycle: the share sheet
/// (or any other screen) makes Flutter's state `inactive` or `paused`. It
/// needs no resource id, so it still holds when the ids above are wrong for
/// this phone. A state not known yet is not "in the background".
bool appIsCovered(AppLifecycleState? state) =>
    state != null && state != AppLifecycleState.resumed;

/// Whether the share sheet is up: a chooser view is on the screen, or
/// (the second signal, [appIsCovered]) the app is behind something.
bool sheetIsUp({required bool chooserViewSeen, AppLifecycleState? lifecycle}) =>
    chooserViewSeen || appIsCovered(lifecycle);

/// Whether a chooser view is on the screen now. A screen that cannot be read
/// throws: it is never taken for "no sheet".
Future<bool> _chooserViewSeen(PatrolIntegrationTester $) async {
  final response = await $.platform.android.getNativeViews(null);
  var found = false;
  void walk(AndroidNativeView view) {
    if (isChooserId(view.resourceName)) found = true;
    view.children.forEach(walk);
  }

  response.roots.forEach(walk);
  return found;
}

/// Whether the share sheet is up now, by either signal. An unreadable screen
/// counts as "not seen" only when the lifecycle does not say the app is
/// covered.
Future<bool> shareSheetUp(PatrolIntegrationTester $) async {
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  var seen = false;
  try {
    seen = await _chooserViewSeen($);
  } on Object {
    seen = false;
  }
  return sheetIsUp(chooserViewSeen: seen, lifecycle: lifecycle);
}

/// Waits until the share sheet is up (a chooser view, or the app covered).
/// The app is behind the sheet, so no frame is pumped meanwhile. Fails with
/// the resource ids on the screen (no text) when neither signal shows. When
/// only the lifecycle says it, the ids on the screen are printed, so the
/// list above can be fixed at the next phone run.
Future<void> waitForShareSheet(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await shareSheetUp($)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'The share sheet did not show after ${timeout.inSeconds} s. Resource '
        'ids on the screen: ${await describeNativeScreen($)}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  var ids = false;
  try {
    ids = await _chooserViewSeen($);
  } on Object {
    ids = false;
  }
  if (!ids) {
    debugPrint(
      'share sheet seen by the app lifecycle only; resource ids on the '
      'screen: ${await describeNativeScreen($)}',
    );
  }
}

/// Waits until the share sheet is gone: no chooser view and the app in front
/// again. A screen that cannot be read is an error here, not "closed".
Future<void> waitForShareSheetToClose(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final seen = await _chooserViewSeen($);
    if (!sheetIsUp(
      chooserViewSeen: seen,
      lifecycle: WidgetsBinding.instance.lifecycleState,
    )) {
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'The share sheet stayed after Back (${timeout.inSeconds} s). Resource '
        'ids on the screen: ${await describeNativeScreen($)}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
