import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/system_dialogs.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// Android finds new videos for TakeTray, on the S24 (phase 3, Task 11).
///
/// The watched folder is `Movies/TakeTray Test` alone, so the scan never
/// returns one of the owner's videos, and the test videos are the only ones in
/// it (`TestMedia.start` makes sure of that, and deletes them again even when a
/// test fails). Every test starts from cleared app data, so none has the media
/// permission at first.
void main() {
  patrolTest(
    'Shooting mode: a new video shows in To tag with its picture and leaves '
    'when deleted; Add earlier videos (Choose dates…, today) adds one, Undo '
    'takes it back',
    config: _liveConfig,
    ($) async {
      final media = await TestMedia.start();
      await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
      final container = ProviderScope.containerOf($.tester.element(_app));
      final bridge = container.read(mediaBridgeProvider);
      final toTag = $(ToTagScreen);

      // 1. Only our folder watched (before access is given, so no query the
      // app makes ever names another folder), then full access, the way a user
      // gives it.
      await container
          .read(settingsRepositoryProvider)
          .save(const AppSettings(watchedFolders: [testFolder]));
      await $(TtNavPill).$('To tag').tap();
      await waitFor(
        $,
        () => toTag.$('Manual mode').exists,
        what: 'the Manual mode banner on To tag',
      );
      await toTag.$('Allow full access').tap();
      await allowAllInDialog($);
      await waitFor(
        $,
        () => !toTag.$('Manual mode').exists,
        what: 'the Manual mode banner to go after Allow all',
      );

      // 2. Shooting mode on (the switch on the Reels card), then a video.
      await $(TtNavPill).$('Reels').tap();
      await _setShootingMode($, container, on: true);
      final first = await media.insert();

      // 3. To tag shows exactly that video, with its picture.
      await $(TtNavPill).$('To tag').tap();
      await waitFor(
        $,
        () => _tiles.evaluate().isNotEmpty,
        what: 'the new video as a tile on To tag',
      );
      await pumpFor($, const Duration(seconds: 2));
      expect(_tiles, findsOneWidget, reason: 'exactly one tile');
      await _expectPictureLoads($);

      // 4. Delete the video, come back to the app: the clip leaves the list.
      expect(await media.delete(first), isTrue);
      await $.platform.mobile.pressHome();
      await $.platform.mobile.openApp();
      await waitFor(
        $,
        () => _tiles.evaluate().isEmpty && toTag.$('All caught up').exists,
        what: 'To tag to be empty (All caught up) after the video was deleted',
      );
      expect(await rowOf(bridge, first), isNull);

      // 5. Add earlier videos. Shooting mode off, a second video.
      await $(TtNavPill).$('Reels').tap();
      await _setShootingMode($, container, on: false);
      await media.insert();
      await $(TtNavPill).$('To tag').tap();
      expect(_tiles, findsNothing, reason: 'Shooting mode was off');

      await toTag.$(Symbols.more_vert_rounded).tap();
      await $('Add earlier videos').tap();
      // Today stays a one-tap row; the dates come from Choose dates… (D-78).
      final today = $(TtListRow).containing('Today');
      await waitFor(
        $,
        () => today.containing('1 new').exists,
        what: 'the Today row to say 1 new',
      );
      await $('Choose dates…').tap();
      // TakeTray's own picker (D-79) opens on this month. Today to today is
      // one day: tap it, then Find videos. The query stays in the test folder
      // (the watched folders were set to it above).
      final todayCell = find.byKey(
        ValueKey<DateTime>(DateUtils.dateOnly(DateTime.now())),
      );
      await waitFor(
        $,
        () => todayCell.evaluate().isNotEmpty,
        what: "today's day in the date picker",
      );
      await $(todayCell).tap();
      await $('Find videos').tap();
      await waitFor(
        $,
        () => $('1 video found').exists,
        what: 'the dialog to say 1 video found',
      );
      expect(_tiles, findsNothing, reason: 'nothing is added before Add');
      await $('Add').tap();
      await waitFor(
        $,
        () => _tiles.evaluate().isNotEmpty,
        what: 'the added video as a tile on To tag',
      );
      expect(_tiles, findsOneWidget);

      // 6. Undo: the clip goes again.
      await $('Undo').tap();
      await waitFor(
        $,
        () => _tiles.evaluate().isEmpty,
        what: 'the added clip to go after Undo',
      );
    },
  );

  // The folder query on the real MediaProvider: an exact folder, ignoring
  // case (SQLite's COLLATE NOCASE works there), and never a parent or a prefix
  // of it. Both the scan's query and Add earlier videos' query.
  patrolTest('the watched folder is matched exactly, ignoring case', ($) async {
    final media = await TestMedia.start();
    final bridge = PigeonMediaBridge();
    await _grantAccess($, bridge);
    final video = await media.insert();

    Future<List<int>> scan(List<String> folders) async => [
      for (final v in await bridge.videosAddedAfter(
        video.volumeName,
        0,
        folders,
        1000,
      ))
        v.mediaStoreId,
    ];
    Future<List<int>> earlier(List<String> folders) async => [
      for (final v in await bridge.videosShotSince(
        video.volumeName,
        folders,
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      ))
        v.mediaStoreId,
    ];

    for (final folder in [
      testFolder,
      'movies/takeTray test',
      'MOVIES/TAKETRAY TEST',
      '/Movies/TakeTray Test/',
    ]) {
      expect(await scan([folder]), [video.mediaStoreId], reason: folder);
      expect(await earlier([folder]), [video.mediaStoreId], reason: folder);
    }
    // Never `Movies` itself or any broad folder: with full access that would
    // return the owner's own videos. These two cannot hold any.
    for (final folder in ['Movies/TakeTray', 'Movies/TakeTray Test/deeper']) {
      expect(await scan([folder]), isEmpty, reason: folder);
      expect(await earlier([folder]), isEmpty, reason: folder);
    }
  });

  // The scan's baseline is the volume generation when Shooting mode is turned
  // on; a video added afterwards must have a higher generation than that. It
  // only holds if the volume's generation is never behind the row's.
  patrolTest('the volume generation is not behind a fresh row', ($) async {
    final media = await TestMedia.start();
    final bridge = PigeonMediaBridge();
    await _grantAccess($, bridge);

    final before = await _generation(bridge, 'external_primary');
    final video = await media.insert();
    final row = await rowOf(bridge, video);
    final after = await _generation(bridge, video.volumeName);

    expect(row, isNotNull);
    expect(row!.isPending, isFalse, reason: 'the insert publishes the row');
    expect(
      row.generationAdded,
      greaterThan(before),
      reason: 'a new video is above the baseline taken before it',
    );
    expect(
      after,
      greaterThanOrEqualTo(row.generationAdded),
      reason: 'the volume generation covers the new row',
    );
  });
}

final Finder _app = find.byType(TakeTrayApp);
final Finder _tiles = find.byType(TtClipTile);

// The Shooting mode card pulses a record dot for ever: never wait for the
// screen to settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

/// Gives full access through the bridge and the system dialog.
Future<void> _grantAccess(PatrolIntegrationTester $, MediaBridge bridge) async {
  final request = bridge.requestAccess();
  await allowAllInDialog($);
  final access = await request.timeout(const Duration(seconds: 20));
  expect(access.level, MediaAccessLevel.full);
}

Future<int> _generation(MediaBridge bridge, String volume) async {
  final volumes = await bridge.volumes();
  return volumes.singleWhere((v) => v.name == volume).generation;
}

/// Taps the Shooting mode switch on the Reels tab and waits until the stored
/// state is [on].
Future<void> _setShootingMode(
  PatrolIntegrationTester $,
  ProviderContainer container, {
  required bool on,
}) async {
  bool? stored() => container.read(shootingModeControllerProvider).value?.on;
  await waitFor(
    $,
    () => stored() != null,
    what: 'the stored Shooting mode to be read',
  );
  if (stored() != on) {
    await $(ReelsPlaceholderScreen).$(TtSwitch).tap();
  }
  await waitFor(
    $,
    () => stored() == on,
    what: 'Shooting mode to be stored as ${on ? 'on' : 'off'}',
  );
}

/// The one tile's picture resolves: the thumbnail cache is ready, and the
/// `ClipThumbnailImage` decodes to a picture without an error.
Future<void> _expectPictureLoads(PatrolIntegrationTester $) async {
  final image = find.descendant(of: _tiles, matching: find.byType(Image));
  await waitFor(
    $,
    () =>
        image.evaluate().isNotEmpty &&
        $.tester.widget<Image>(image).image is ClipThumbnailImage,
    what: 'the tile to use the thumbnail cache (ClipThumbnailImage)',
  );
  final provider = $.tester.widget<Image>(image).image;
  final stream = provider.resolve(
    createLocalImageConfiguration($.tester.element(image)),
  );
  final done = Completer<ImageInfo>();
  final listener = ImageStreamListener(
    (info, _) {
      if (!done.isCompleted) done.complete(info);
    },
    onError: (error, stack) {
      // The type only: a message could hold a path (D-10).
      if (!done.isCompleted) {
        done.completeError(
          TestFailure('The thumbnail failed to load: ${error.runtimeType}'),
        );
      }
    },
  );
  stream.addListener(listener);
  try {
    final info = await done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TestFailure('The thumbnail did not load in 20 s'),
    );
    expect(info.image.width, greaterThan(0));
    expect(info.image.height, greaterThan(0));
  } finally {
    stream.removeListener(listener);
  }
}
