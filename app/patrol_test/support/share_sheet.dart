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

/// Whether the share sheet is on the screen now.
Future<bool> shareSheetVisible(PatrolIntegrationTester $) async {
  try {
    final response = await $.platform.android.getNativeViews(null);
    var found = false;
    void walk(AndroidNativeView view) {
      if (isChooserId(view.resourceName)) found = true;
      view.children.forEach(walk);
    }

    response.roots.forEach(walk);
    return found;
  } on Object {
    // A screen that cannot be read is not "the sheet is up": the wait below
    // fails with the ids on the screen when that is not there either.
    return false;
  }
}

/// Waits until the share sheet is on the screen. The app is behind the sheet,
/// so no frame is pumped meanwhile. Fails with the resource ids on the screen
/// (no text) when it does not show.
Future<void> waitForShareSheet(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await shareSheetVisible($)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'The share sheet did not show after ${timeout.inSeconds} s. Resource '
        'ids on the screen: ${await describeNativeScreen($)}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

/// Waits until the share sheet is gone from the screen.
Future<void> waitForShareSheetToClose(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (await shareSheetVisible($)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'The share sheet stayed after Back (${timeout.inSeconds} s). Resource '
        'ids on the screen: ${await describeNativeScreen($)}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
