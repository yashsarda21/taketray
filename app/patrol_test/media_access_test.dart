import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/system_dialogs.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// The limited-access test drives One UI's "Select photos and videos" picker
/// by resource id, which is unproven on the S24, and it taps a tile in the
/// system picker. It is written but skipped, and it must stay skipped until it
/// verifies that the tile it picks is the inserted test video (see the note on
/// the test). The `LIMITED_ACCESS` define is only for developing that check:
///
///     tool/patrol test -d RZCY80PHWCZ --dart-define=LIMITED_ACCESS=true \
///       -t patrol_test/media_access_test.dart
///
/// Until then the owner does the same steps by hand (docs/dev-setup.md,
/// "Phase 3 check", step 10).
const bool _driveLimitedAccess = bool.fromEnvironment('LIMITED_ACCESS');

// Every test starts from cleared app data (`clearPackageData`), so it starts
// with no media permission.
void main() {
  patrolTest(
    'a fresh install is in Manual mode; Allow full access, then Allow all, '
    'ends it',
    ($) async {
      await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
      final toTag = await _openToTag($);

      // 1. The banner.
      await waitFor(
        $,
        () => toTag.$('Manual mode').exists,
        what: 'the Manual mode banner on To tag',
      );
      expect(toTag.$('Allow full access').exists, isTrue);

      // 2. The system dialog.
      await toTag.$('Allow full access').tap();
      await allowAllInDialog($);

      // 3. The banner is gone, on both tabs.
      await waitFor(
        $,
        () => !toTag.$('Manual mode').exists,
        what: 'the Manual mode banner to go after Allow all',
      );
      expect(toTag.$('Allow full access').exists, isFalse);
      await $(TtNavPill).$('Reels').tap();
      expect($(ReelsScreen).$('Manual mode').exists, isFalse);
    },
  );

  // The call comes back once the dialog is answered. Android hands the answer
  // to MainActivity.onRequestPermissionsResult; if MainActivity did not pass
  // it on, requestAccess would wait for ever and the app would look hung.
  patrolTest('requestAccess comes back after Allow all', ($) async {
    final bridge = PigeonMediaBridge();
    final before = await bridge.accessReport();
    expect(
      before.level,
      isNot(MediaAccessLevel.full),
      reason: 'a fresh install should not have the permission yet',
    );

    final request = bridge.requestAccess();
    await allowAllInDialog($);
    final after = await request.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TestFailure(
        'requestAccess did not come back 20 s after the dialog was answered '
        '(MainActivity.onRequestPermissionsResult not passed on?)',
      ),
    );

    expect(after.level, MediaAccessLevel.full);
    expect((await bridge.accessReport()).level, MediaAccessLevel.full);
  });

  // DO NOT ENABLE (remove the skip) until this test verifies that the item it
  // picks is the inserted test video: the first tile in the picker can be one
  // of the owner's own videos, and tapping it would select (and so share with
  // the app) something that is not ours.
  patrolTest(
    'limited access keeps Manual mode; Allow full access asks again',
    skip: !_driveLimitedAccess,
    ($) async {
      // The picker lists the newest videos first: put one of ours there.
      final media = await TestMedia.start();
      await media.insert();
      final bridge = PigeonMediaBridge();

      await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
      final toTag = await _openToTag($);
      await waitFor(
        $,
        () => toTag.$('Manual mode').exists,
        what: 'the Manual mode banner on To tag',
      );

      // "Select photos and videos", then pick one video in the picker.
      await toTag.$('Allow full access').tap();
      await tapNativeView($, allowSelectedButton);
      await pickNewestInSystemPicker($);

      await _waitForLevel($, bridge, MediaAccessLevel.limited);
      await waitFor(
        $,
        () => toTag.$('Manual mode').exists,
        what: 'Manual mode to still show with limited access',
      );

      // The button asks again: the system dialog is back.
      await toTag.$('Allow full access').tap();
      await waitForNativeView($, allowAllButton);
      await tapNativeView($, allowAllButton);
      await waitFor(
        $,
        () => !toTag.$('Manual mode').exists,
        what: 'the Manual mode banner to go after Allow all',
      );
      expect((await bridge.accessReport()).level, MediaAccessLevel.full);
    },
  );
}

/// Opens the To tag tab and returns a finder for its screen.
Future<PatrolFinder> _openToTag(PatrolIntegrationTester $) async {
  await $(TtNavPill).$('To tag').tap();
  return $(ToTagScreen);
}

/// Waits until the bridge reports [level].
Future<void> _waitForLevel(
  PatrolIntegrationTester $,
  MediaBridge bridge,
  MediaAccessLevel level,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while ((await bridge.accessReport()).level != level) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Access did not become ${level.name} within 20 s');
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}
