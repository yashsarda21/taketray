import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// The Android permission dialog is drawn by the system's permission
/// controller; these are the resource ids of its buttons (AOSP names, which
/// Patrol's own `grantPermissionWhenInUse` also uses).
const String _permissionIds = 'com.android.permissioncontroller:id/';

/// "Allow all" (the full-access answer to the photos and videos question).
const String allowAllButton = '${_permissionIds}permission_allow_all_button';

/// "Select photos and videos" / "Allow limited access" (Android 14 and up).
const String allowSelectedButton =
    '${_permissionIds}permission_allow_selected_button';

/// "Don't allow".
const String denyButton = '${_permissionIds}permission_deny_button';

/// Every view of the native screen, flattened. Only resource ids and class
/// names are ever read from it (no text), and only to find a button or to say
/// what was on the screen when a step failed.
Future<List<AndroidNativeView>> _nativeViews(
  PatrolIntegrationTester $, {
  AndroidSelector? selector,
}) async {
  final response = await $.platform.android.getNativeViews(selector);
  final all = <AndroidNativeView>[];
  void walk(AndroidNativeView view) {
    all.add(view);
    view.children.forEach(walk);
  }

  response.roots.forEach(walk);
  return all;
}

/// Whether a native view with this resource id is on the screen now.
Future<bool> nativeViewVisible(
  PatrolIntegrationTester $,
  String resourceId,
) async {
  try {
    final views = await _nativeViews(
      $,
      selector: AndroidSelector(resourceName: resourceId),
    );
    return views.any((v) => v.resourceName == resourceId);
  } on Object {
    // Patrol reports "nothing matches" in different ways; a screen that
    // really cannot be read fails in waitForNativeView, with its ids.
    return false;
  }
}

/// Waits until a native view with [resourceId] is on the screen, or fails
/// with a list of the resource ids that are (no text), so the right id can be
/// found on a new phone.
Future<void> waitForNativeView(
  PatrolIntegrationTester $,
  String resourceId, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await nativeViewVisible($, resourceId)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'No native view with id $resourceId after ${timeout.inSeconds} s. '
        'Resource ids on the screen: ${await describeNativeScreen($)}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

/// The resource ids and classes on the native screen now, for a failure
/// message. No text, no content descriptions.
Future<String> describeNativeScreen(PatrolIntegrationTester $) async {
  final views = await _nativeViews($);
  final ids = {
    for (final v in views)
      if (v.resourceName != null) v.resourceName!,
  }.toList()..sort();
  return ids.isEmpty ? '(none)' : ids.join(', ');
}

/// Taps the native view with [resourceId] once it is there.
Future<void> tapNativeView(PatrolIntegrationTester $, String resourceId) async {
  await waitForNativeView($, resourceId);
  await $.platform.android.tap(AndroidSelector(resourceName: resourceId));
}

/// Answers the media permission dialog with "Allow all".
///
/// First Patrol's own `grantPermissionWhenInUse`, which knows the AOSP button
/// ids (`permission_allow_all_button` among them). If One UI's dialog does not
/// match, it taps [allowAllButton] by resource id, and fails with the ids on
/// the screen when that is not there either.
Future<void> allowAllInDialog(PatrolIntegrationTester $) async {
  try {
    await $.platform.mobile.grantPermissionWhenInUse();
  } on Object {
    await tapNativeView($, allowAllButton);
  }
}

/// The packages that can draw Android's photo picker, the screen "Select
/// photos and videos" opens (the Google one on a phone with Google services).
const List<String> _pickerPackages = [
  'com.google.android.providers.media.module',
  'com.android.providers.media.module',
];

/// In the system's photo picker, selects the newest item and confirms.
///
/// Best effort, written from the AOSP picker's resource ids
/// (`icon_thumbnail`, `button_add`): One UI may draw its own. Fails with the
/// resource ids on the screen when it does not recognise the picker. It only
/// ever taps the first tile and the confirm button; it reads nothing.
Future<void> pickNewestInSystemPicker(PatrolIntegrationTester $) async {
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  String? package;
  while (package == null) {
    for (final candidate in _pickerPackages) {
      if (await nativeViewVisible($, '$candidate:id/icon_thumbnail')) {
        package = candidate;
        break;
      }
    }
    if (package != null) break;
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'The photo picker did not show. Resource ids on the screen: '
        '${await describeNativeScreen($)}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  await $.platform.android.tap(
    AndroidSelector(resourceName: '$package:id/icon_thumbnail', instance: 0),
  );
  await tapNativeView($, '$package:id/button_add');
}

/// Answers the notification permission dialog (Android 13 and later) with
/// "Allow", if it shows within [timeout]. Returns whether it did: false on a
/// phone that does not ask (below Android 13) or that already allowed.
Future<bool> allowNotificationsInDialog(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (!await $.platform.mobile.isPermissionDialogVisible(timeout: timeout)) {
    return false;
  }
  try {
    await $.platform.mobile.grantPermissionWhenInUse();
  } on Object {
    await tapNativeView($, '${_permissionIds}permission_allow_button');
  }
  return true;
}
