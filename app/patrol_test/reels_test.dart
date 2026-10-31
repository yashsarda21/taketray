import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/features/reels/views/clip_viewer_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:video_player/video_player.dart';

import 'support/test_media.dart';
import 'support/waiting.dart';

/// Reels on the S24 (phase 4, Task 11): create, edit, mark ready, add a real
/// video, play it in the viewer, Remove with Undo, Delete with Undo.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`), started from cleared app data, so the reels are its
/// own and nothing else is on the screen. The one video is the test fixture,
/// put into `Movies/TakeTray Test/` through the debug channel (D-77) and
/// deleted again, also when the test fails (`TestMedia.start` registers it).
/// The reel is deleted in a tear-down too. Nothing else on the phone is read,
/// written or deleted:
///
/// - The watched folder is set to the test folder before anything else, so no
///   query the app makes could name another folder.
/// - The media permission is never asked for. Without it the app is in Manual
///   mode: it does not scan, and opening a reel does not verify (the verifier
///   skips without full access). The only MediaStore read is
///   `videosByIds` for the id of the test video, which Android answers for
///   TakeTray Dev's own files without a permission.
/// - The viewer plays the test video from its `content://` address, as it
///   plays any clip.
///
/// The words are the app's own (`AppLocalizations`), never typed twice.
void main() {
  patrolTest(
    'Reels: create, rename, mark ready, add a video, play it in the viewer, '
    'Remove and Undo, Delete and Undo',
    config: _liveConfig,
    ($) async {
      final media = await TestMedia.start();
      await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
      final container = ProviderScope.containerOf($.tester.element(_app));
      final reels = container.read(reelsRepositoryProvider);
      final clips = container.read(clipsRepositoryProvider);
      final bridge = container.read(mediaBridgeProvider);
      // Whatever happens below, the test's reels go (the app's own database;
      // this app's data is cleared at the start of every test anyway).
      addTearDown(() => _deleteTestReels(reels));

      // 0. Only our folder watched, before anything else.
      await container
          .read(settingsRepositoryProvider)
          .save(const AppSettings(watchedFolders: [testFolder]));

      // 1. Create "Patrol Reel" from the empty Home.
      final home = $(ReelsScreen);
      await waitFor(
        $,
        () => home.$(_l10n.reelsNewReel).exists,
        what: 'the New reel button on an empty Home',
      );
      expect(home.$(_l10n.reelsEmptyTitle).exists, isTrue);
      await home.$(_l10n.reelsNewReel).tap();
      await _enterReelName($, _reelName);
      await $(TtSheet).$(_l10n.reelCreateButton).tap();
      await _waitForSheetToClose($);

      // The card on Home, and the reel in the database.
      final card = $(TtReelCard).containing(_reelName);
      final renamedCard = $(TtReelCard).containing(_renamed);
      // The meta line is "1 clip · 0:02": look for the start of it.
      final oneClipOnCard = find.descendant(
        of: find.byType(TtReelCard),
        matching: find.textContaining(_l10n.reelCardClips(1)),
      );
      await waitFor(
        $,
        () => card.exists,
        what: 'the "$_reelName" card on Home',
      );
      expect(card.$(_l10n.statusCollecting).exists, isTrue);
      final created = (await reels.watchAll().first).singleWhere(
        (r) => r.name == _reelName,
      );
      final reelId = created.id;
      expect(created.status, ReelStatus.collecting);

      // Open it: the name, the status pill and "No clips yet".
      await card.tap();
      final detail = $(ReelDetailScreen);
      await waitFor(
        $,
        () => detail.exists && detail.$(_reelName).exists,
        what: 'the reel page named "$_reelName"',
      );
      expect(detail.$(TtStatusPill).$(_l10n.statusCollecting).exists, isTrue);
      expect(detail.$(TtEmptyState).$(_l10n.reelNoClips).exists, isTrue);

      // Rename it through ⋮ > Reel details.
      await detail.$(Symbols.more_vert_rounded).tap();
      await $(_l10n.reelMenuDetails).tap();
      await _enterReelName($, _renamed);
      await $(TtSheet).$(_l10n.reelSaveButton).tap();
      await _waitForSheetToClose($);
      await waitFor(
        $,
        () => detail.$(_renamed).exists && !detail.$(_reelName).exists,
        what: 'the reel page to say "$_renamed"',
      );
      expect((await reels.getById(reelId))?.name, _renamed);

      // Mark it Ready to edit through the status pill's menu.
      await detail.$(TtStatusPill).tap();
      await $(_l10n.statusReady).tap();
      await waitFor(
        $,
        () => detail.$(TtStatusPill).$(_l10n.statusReady).exists,
        what: 'the status pill to say "${_l10n.statusReady}"',
      );
      expect((await reels.getById(reelId))?.status, ReelStatus.ready);

      // 2. Back to Home, add one real video, open the reel.
      await _tapIconButton($, _l10n.navBack);
      await waitFor(
        $,
        () => home.exists && renamedCard.exists,
        what: 'Home with the renamed card',
      );
      final video = await media.insert();
      final row = await rowOf(bridge, video);
      expect(row, isNotNull, reason: 'MediaStore has the test video');
      // Only a video in the test folder is ever added (D-77).
      expect(
        _isTestFolder(row!.relativePath),
        isTrue,
        reason: 'the video is in the test folder',
      );
      expect(isUsable(row), isTrue, reason: 'finished, with a length');
      final ids = await clips.addNewClipsToReel(reelId, [
        newClipFrom(row, now: DateTime.now().toUtc(), zoneId: null),
      ]);
      final clipId = ids.single;

      await waitFor(
        $,
        () => oneClipOnCard.evaluate().isNotEmpty,
        what: 'the card to say "${_l10n.reelCardClips(1)}"',
      );
      await renamedCard.tap();
      await waitFor(
        $,
        () => detail.exists && detail.$(_renamed).exists,
        what: 'the reel page with the clip',
      );
      final tiles = find.byType(TtClipTile);
      await waitFor(
        $,
        () => tiles.evaluate().isNotEmpty,
        what: 'the clip as a tile',
      );
      expect(tiles, findsOneWidget, reason: 'exactly one tile');
      final dayHeader = find.descendant(
        of: find.byType(TtDayHeader),
        matching: find.textContaining(_l10n.reelDayTitle(1, '')),
      );
      expect(dayHeader, findsOneWidget, reason: 'a "Day 1 · …" header');

      // 3. The viewer: "1 of 1", and the video plays.
      await $(tiles).tap();
      await waitFor(
        $,
        () => $(ClipViewerScreen).exists,
        what: 'the clip viewer',
      );
      await waitFor(
        $,
        () => $(_l10n.viewerTitle(1, 1, _renamed)).exists,
        what: '"1 of 1" in the viewer header',
      );
      await _expectVideoPlays($);
      await _tapIconButton($, _l10n.navBack);
      await waitFor(
        $,
        () => !$(ClipViewerScreen).exists && tiles.evaluate().isNotEmpty,
        what: 'the reel page again, with its tile',
      );

      // 4. Long press the tile, Remove: the reel is empty. Undo: the tile is
      // back, and it is the same clip (same id), not a second one.
      await $(tiles).longPress();
      await waitFor(
        $,
        () => detail.$(_l10n.selectionCount(1)).exists,
        what: '"${_l10n.selectionCount(1)}" after the long press',
      );
      await _tapIconButton($, _l10n.selectionRemove);
      final undo = find.text(_l10n.undo);
      await waitFor(
        $,
        () => tiles.evaluate().isEmpty && undo.evaluate().isNotEmpty,
        what: 'the reel to be empty with an Undo snack',
      );
      expect(detail.$(TtEmptyState).$(_l10n.reelNoClips).exists, isTrue);
      expect(await clips.watchReelClips(reelId).first, isEmpty);
      await $(undo.first).tap();
      await waitFor(
        $,
        () => tiles.evaluate().isNotEmpty,
        what: 'the tile to come back after Undo',
      );
      expect(tiles, findsOneWidget, reason: 'Undo adds one tile, not two');
      final back = await clips.watchReelClips(reelId).first;
      expect(
        [for (final c in back) c.clip.id],
        [clipId],
        reason: 'Undo puts back the same clip',
      );

      // 5. Delete the reel: Home has no card. Undo: the card is back, with
      // its clip.
      await _deleteReelFromItsPage($, _renamed);
      await waitFor(
        $,
        () => home.exists && !renamedCard.exists && undo.evaluate().isNotEmpty,
        what: 'Home without the card and an Undo snack',
      );
      expect(await reels.getById(reelId), isNull);
      await $(undo.first).tap();
      await waitFor(
        $,
        () => renamedCard.exists,
        what: 'the card to come back after Undo',
      );
      expect(
        oneClipOnCard.evaluate(),
        isNotEmpty,
        reason: 'the card says "${_l10n.reelCardClips(1)}"',
      );
      expect((await reels.getById(reelId))?.name, _renamed);
      expect(
        [for (final c in await clips.watchReelClips(reelId).first) c.clip.id],
        [clipId],
        reason: 'Undo of the delete puts the clip back',
      );

      // Then for good: delete again and leave the snack alone.
      await renamedCard.tap();
      await waitFor(
        $,
        () => detail.exists && detail.$(_renamed).exists,
        what: 'the reel page again',
      );
      await _deleteReelFromItsPage($, _renamed);
      await waitFor(
        $,
        () => home.exists && !renamedCard.exists,
        what: 'Home without the card, for good',
      );
      expect(await reels.getById(reelId), isNull);

      // The test video goes too (the tear-down would, this proves it).
      expect(await media.delete(video), isTrue);
      expect(await rowOf(bridge, video), isNull);
    },
  );
}

/// The reel's name when it is made, and after Reel details renames it.
const String _reelName = 'Patrol Reel';
const String _renamed = 'Patrol Reel Edited';

final Finder _app = find.byType(TakeTrayApp);

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The viewer plays a video and a snack counts down: never wait for the screen
// to settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

/// A [TtIconButton] by the label a screen reader gives it (it has no text).
Finder _iconButtonLabelled(String label) => find.byWidgetPredicate(
  (w) => w is TtIconButton && w.semanticLabel == label,
  description: 'TtIconButton labelled "$label"',
);

Future<void> _tapIconButton(PatrolIntegrationTester $, String label) =>
    $(_iconButtonLabelled(label)).tap();

/// Types [name] in the name field (the first field) of the open reel sheet.
Future<void> _enterReelName(PatrolIntegrationTester $, String name) async {
  await waitFor($, () => $(TtSheet).exists, what: 'the reel sheet');
  final field = find
      .descendant(of: find.byType(TtSheet), matching: find.byType(TextField))
      .first;
  await $(field).enterText(name);
}

Future<void> _waitForSheetToClose(PatrolIntegrationTester $) =>
    waitFor($, () => !$(TtSheet).exists, what: 'the sheet to close');

/// ⋮ > Delete reel > Delete reel, on the page of the reel called [name].
Future<void> _deleteReelFromItsPage(
  PatrolIntegrationTester $,
  String name,
) async {
  await $(ReelDetailScreen).$(Symbols.more_vert_rounded).tap();
  await $(_l10n.reelMenuDelete).tap();
  final dialog = find.byWidgetPredicate(
    (w) => w is TtDialog,
    description: 'TtDialog',
  );
  await waitFor(
    $,
    () => $(dialog).$(_l10n.deleteReelTitle(name)).exists,
    what: 'the "${_l10n.deleteReelTitle(name)}" dialog',
  );
  await $(dialog).$(_l10n.deleteReelConfirm).tap();
}

/// Whether [relativePath] is the test folder, ignoring case and slashes at
/// either end (the same match MediaStore queries make).
bool _isTestFolder(String relativePath) =>
    relativePath.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase() ==
    testFolder.toLowerCase();

/// Checks that the viewer's video really plays: the player has opened it
/// without an error, and its position moves past zero within 5 seconds. It
/// reads the app's own `VideoPlayerController` (the one the `VideoPlayer`
/// widget on the screen draws), not a picture of the screen.
///
/// The position is also watched by a listener, because the test video is 2 s
/// long and the player stops at its end.
Future<void> _expectVideoPlays(PatrolIntegrationTester $) async {
  final player = find.byType(VideoPlayer);
  await waitFor(
    $,
    () => player.evaluate().isNotEmpty,
    what: 'the video player in the viewer (the video opened)',
    timeout: const Duration(seconds: 30),
  );
  final controller = $.tester.widget<VideoPlayer>(player).controller;
  var peak = Duration.zero;
  void watch() {
    final position = controller.value.position;
    if (position > peak) peak = position;
  }

  controller.addListener(watch);
  try {
    watch();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (peak == Duration.zero) {
      final value = controller.value;
      // Never the error text: it can hold a content address (D-10).
      expect(value.hasError, isFalse, reason: 'the player reported an error');
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure(
          'The video did not play: the position stayed at 0 for 5 s '
          '(initialized: ${value.isInitialized}, playing: ${value.isPlaying}, '
          'length: ${value.duration.inMilliseconds} ms)',
        );
      }
      await $.tester.pump(const Duration(milliseconds: 100));
      watch();
    }
  } finally {
    controller.removeListener(watch);
  }
  expect(peak, greaterThan(Duration.zero));
}

/// Deletes the reels this test makes, by their two names, in the app's own
/// database. Never throws: the clean-up of the test video does not depend on
/// it, and the app's data is cleared at the start of the next test.
Future<void> _deleteTestReels(ReelsRepository reels) async {
  try {
    final all = await reels.watchAll().first.timeout(
      const Duration(seconds: 10),
    );
    for (final reel in all) {
      if (reel.name == _reelName || reel.name == _renamed) {
        await reels.delete(reel.id);
      }
    }
  } on Object {
    // The database may be closed with the app: nothing more to do.
  }
}
