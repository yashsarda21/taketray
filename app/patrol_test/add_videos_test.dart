import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/browse_folders.dart';
import 'package:taketray/features/add_videos/view_models/add_folders_controller.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray/features/add_videos/views/add_grid_screen.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/system_dialogs.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// Add videos on the S24 (phase 7, Task 7): pick videos from a folder into To
/// tag and into a reel, the marks on videos already added, and WhatsApp's
/// Sent folder staying hidden.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`), started from cleared app data. The videos are the
/// test fixture, put into `Movies/TakeTray Test/` (one into its
/// `WhatsApp/Sent/` sub-folder, the only sub-folder the hook accepts) through
/// the debug channel (D-77) and deleted again, also when a test fails
/// (`TestMedia.start` registers it, and `_cleanUp` runs it at the end of the
/// body). Nothing else on the phone is deleted or written.
///
/// - The only folder the test taps is `TakeTray Test`, by its exact text, and
///   no other folder or video name is read, compared or printed. Add videos
///   itself lists every folder with videos, as it must (it needs full access,
///   given the way a user gives it: To tag's **Allow full access**, then
///   "Allow all"); the test scrolls its folder list to reach the test row but
///   reads nothing from the other rows.
/// - The watched folder is set to the test folder first and put back at the
///   end, as in the other Patrol files (`watchOnlyTestFolder`).
/// - The test reel is made through the reels repository and deleted at the
///   end of the body, with a one-off select (see `tagging_test.dart`).
/// - Counts and error types only are printed (D-10).
///
/// **The photo picker is not driven.** It lists the owner's videos, so Manual
/// mode's picker is a hand check (`docs/dev-setup.md`, Phase 7).
///
/// **Timing.** An add shows a snack with **Undo** for 6 seconds. The only
/// step that needs the snack is the first test's Undo, which taps it as soon
/// as it shows; the marks are read after a second add, from the grid, which
/// does not need a snack. No step waits on Android's scheduler.
///
/// The words are the app's own (`AppLocalizations`), never typed twice.
void main() {
  patrolTest(
    'Add videos to To tag: pick 2 of 3, Add 2, Undo takes them off; add them '
    'again, the 2 are marked In To tag, the third is not, a marked tile says '
    'Already added',
    config: _liveConfig,
    ($) => _scenario($, (env) async {
      final videos = await env.media.insertMany(3);
      final picked = videos.sublist(0, 2);
      final third = videos[2];
      final toTagTiles = _tilesOn(ToTagScreen);

      // Round 1: the folder list names the test folder with 3 videos; the
      // grid has 3 unmarked tiles and nothing picked; pick 2; Add 2.
      await _openAddVideos($, env, from: ToTagScreen);
      await _openTestFolder($, env, videos: 3);
      await _waitForGridTiles($, videos);
      expect(_count(_inGrid(_l10n.addMarkInToTag)), 0, reason: 'no marks yet');
      expect(_count(find.text(_l10n.addBarNonePicked)), 1);
      expect(_count(find.text(_l10n.addBarMarkedHint)), 1);
      expect($.tester.widget<TtButton>(_addButton).onPressed, isNull);
      await _pick($, picked[0], count: 1);
      await _pick($, picked[1], count: 2);
      expect(_count(_inButton(_l10n.addBarAddCount(2))), 1);
      await $(_addButton).tap();

      // To tag has the 2, with the snack; the folder screens are gone. The
      // Undo is tapped at once: the snack only stays 6 seconds.
      final snack = _l10n.addVideosAddedSnack(2, _l10n.navToTag);
      final undo = find.text(_l10n.undo);
      await waitFor(
        $,
        () =>
            _count(find.text(snack)) == 1 &&
            _count(undo) == 1 &&
            _count(toTagTiles) == 2,
        what: '"$snack" with Undo and 2 tiles on To tag',
      );
      expect(_count(find.byType(AddFoldersScreen)), 0);
      expect(_count(find.byType(AddGridScreen)), 0);
      await $(undo).tap();
      await waitFor(
        $,
        () => _count(toTagTiles) == 0,
        what: 'To tag to be empty after Undo',
      );
      expect(await env.pendingMediaStoreIds(), isEmpty);
      expect(await env.skippedMediaStoreIds(), isEmpty);

      // Round 2: the same two again; this time they stay.
      await _openAddVideos($, env, from: ToTagScreen);
      await _openTestFolder($, env, videos: 3);
      await _waitForGridTiles($, videos);
      expect(_count(_inGrid(_l10n.addMarkInToTag)), 0, reason: 'Undo unmarked');
      await _pick($, picked[0], count: 1);
      await _pick($, picked[1], count: 2);
      await $(_addButton).tap();
      await waitFor(
        $,
        () => _count(find.text(snack)) == 1 && _count(toTagTiles) == 2,
        what: '"$snack" and 2 tiles on To tag',
      );
      expect(await env.pendingMediaStoreIds(), {
        for (final v in picked) v.mediaStoreId,
      }, reason: 'To tag holds exactly the two picked videos');
      expect(await env.skippedMediaStoreIds(), isEmpty);
      expect(
        (await env.pendingMediaStoreIds()).contains(third.mediaStoreId),
        isFalse,
        reason: 'the third video was not added',
      );

      // The grid marks the 2 as In To tag and leaves the third alone.
      await _openAddVideos($, env, from: ToTagScreen);
      await _openTestFolder($, env, videos: 3);
      await _waitForGridTiles($, videos);
      await waitFor(
        $,
        () => _count(_inGrid(_l10n.addMarkInToTag)) == 2,
        what: 'two tiles marked "${_l10n.addMarkInToTag}"',
      );
      for (final v in picked) {
        expect(
          _count(_inTile(v, _l10n.addMarkInToTag)),
          1,
          reason: 'a picked video shows "${_l10n.addMarkInToTag}"',
        );
      }
      expect(
        _count(_inTile(third, _l10n.addMarkInToTag)),
        0,
        reason: 'the third video has no mark',
      );
      expect(_count(find.text(_l10n.addBarNonePicked)), 1);

      // Already added: a tap on a marked tile says so and picks nothing.
      expect(_count(find.text(_l10n.addVideosAlreadyAdded)), 0);
      await $(_gridTile(picked[0])).tap();
      await waitFor(
        $,
        () => _count(find.text(_l10n.addVideosAlreadyAdded)) == 1,
        what: '"${_l10n.addVideosAlreadyAdded}" after a tap on a marked tile',
      );
      expect(_count(find.text(_l10n.addBarNonePicked)), 1);
      expect($.tester.widget<TtButton>(_addButton).onPressed, isNull);
      // The unmarked one can still be picked (and un-picked).
      await _pick($, third, count: 1);
      await _pick($, third, count: 0);

      // Back twice: To tag still holds the 2 and nothing else.
      await _tapBack($);
      await waitFor(
        $,
        () => _count(find.byType(AddGridScreen)) == 0,
        what: 'the grid to close on Back',
      );
      await _tapBack($);
      await waitFor(
        $,
        () => _count(find.byType(AddFoldersScreen)) == 0,
        what: 'the folder list to close on Back',
      );
      expect(_count(toTagTiles), 2);
      expect(await env.pendingMediaStoreIds(), hasLength(2));
    }),
  );

  patrolTest(
    'Add videos to a reel: pick 1 of 2, it is in the reel with a picture and '
    'not in To tag',
    config: _liveConfig,
    ($) => _scenario($, (env) async {
      final videos = await env.media.insertMany(2);
      final reel = await env.reels.create(_reelName);

      // The reel's page, from its card on Reels.
      await $(TtNavPill).$(_l10n.navReels).tap();
      final card = $(TtReelCard).containing(_reelName);
      await waitFor($, () => card.exists, what: 'the "$_reelName" card');
      await card.tap();
      await waitFor(
        $,
        () =>
            $(ReelDetailScreen).exists &&
            $(ReelDetailScreen).$(_reelName).exists,
        what: 'the page of "$_reelName"',
      );

      await _openAddVideos($, env, from: ReelDetailScreen);
      expect(
        _count(find.text(_l10n.addVideosToReel(_reelName))),
        1,
        reason: 'Add videos says it adds to the reel',
      );
      await _openTestFolder($, env, videos: 2);
      await _waitForGridTiles($, videos);
      await _pick($, videos[0], count: 1);
      await $(_addButton).tap();

      final snack = _l10n.addVideosAddedSnack(1, _reelName);
      final tiles = _tilesOn(ReelDetailScreen);
      await waitFor(
        $,
        () => _count(find.text(snack)) == 1 && _count(tiles) == 1,
        what: '"$snack" and 1 tile on the reel page',
      );
      expect(_count(find.byType(AddGridScreen)), 0);
      expect(_count(find.byType(AddFoldersScreen)), 0);

      // In the reel: the database holds exactly that video, and To tag and
      // Skipped hold nothing.
      final inReel = await env.clips.watchReelClips(reel.id).first;
      expect(
        [for (final c in inReel) c.clip.mediaStoreId],
        [videos[0].mediaStoreId],
      );
      expect(await env.pendingMediaStoreIds(), isEmpty);
      expect(await env.skippedMediaStoreIds(), isEmpty);

      // With a picture: the tile uses the thumbnail cache and it decodes.
      await _expectPictureLoads($, tiles);
    }),
  );

  patrolTest(
    "Add videos hides WhatsApp's Sent folder: the list has no such row",
    config: _liveConfig,
    ($) => _scenario($, (env) async {
      final shown = await env.media.insert();
      final sent = await env.media.insert(inWhatsAppSent: true);

      // The phone has both folders, 1 video each (so the hiding is real, not
      // an empty folder).
      Future<Map<String, int>> phoneFolders() async => {
        for (final f in await env.bridge.videoFolders())
          if (_isUnderTestFolder(f.relativePath))
            _norm(f.relativePath): f.videoCount,
      };
      expect(await phoneFolders(), {
        _norm(testFolder): 1,
        _norm(testSentFolder): 1,
      });

      // The list shows the test folder alone, with 1 video: the Sent video is
      // not counted in it and its folder has no row.
      await _openAddVideos($, env, from: ToTagScreen);
      await _openTestFolder($, env, videos: 1);
      final rows = await env.testFolderRows();
      expect(
        [for (final r in rows) (_norm(r.relativePath), r.name, r.videoCount)],
        [(_norm(testFolder), _testFolderName, 1)],
        reason: 'Add videos lists the test folder only, 1 video',
      );
      expect(
        _count(
          find.descendant(
            of: find.byType(AddFoldersScreen),
            matching: find.text('Sent'),
          ),
        ),
        0,
        reason: 'no row named Sent is built',
      );

      // Its grid holds the one video that is in the folder, not the Sent one.
      await _waitForGridTiles($, [shown]);
      expect(_count(_gridTiles), 1, reason: 'one tile in the folder');
      expect(
        _count(_gridTile(sent)),
        0,
        reason: 'the Sent video is not listed',
      );
      await _tapBack($);
      await _tapBack($);

      // The Sent video goes now (the clean-up would do it too); the phone has
      // only the test folder left.
      expect(await env.media.delete(sent), isTrue);
      expect(await phoneFolders(), {_norm(testFolder): 1});
    }),
  );
}

/// The name of the test folder's row: its last path segment.
final String _testFolderName = testFolder.split('/').last;

/// The test reel's name.
const String _reelName = 'Patrol Add Reel';

final Finder _app = find.byType(TakeTrayApp);

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The Shooting mode card pulses and a snack counts down: never wait for the
// screen to settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

// ---- finders ----

/// How many widgets [finder] matches now. Used instead of `expect(finder, …)`
/// so a failure prints a number, never the widgets (a tile could carry a name).
int _count(Finder finder) => finder.evaluate().length;

/// The clip tiles on the screen of type [screen].
Finder _tilesOn(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byType(TtClipTile));

final Finder _gridTiles = _tilesOn(AddGridScreen);

/// [text] anywhere on the Add videos grid.
Finder _inGrid(String text) =>
    find.descendant(of: find.byType(AddGridScreen), matching: find.text(text));

/// The grid's tile of [video] (the key the screen gives it).
Finder _gridTile(InsertedVideo video) =>
    find.byKey(ValueKey<String>('add-video-${video.mediaStoreId}'));

/// [text] inside the grid's tile of [video].
Finder _inTile(InsertedVideo video, String text) =>
    find.descendant(of: _gridTile(video), matching: find.text(text));

/// The grid's **Add** button (its key).
final Finder _addButton = find.byKey(const ValueKey<String>('add-videos-add'));

/// [text] inside the **Add** button.
Finder _inButton(String text) =>
    find.descendant(of: _addButton, matching: find.text(text));

/// A [TtIconButton] by the label a screen reader gives it (it has no text).
Finder _iconButtonLabelled(String label) => find.byWidgetPredicate(
  (w) => w is TtIconButton && w.semanticLabel == label,
  description: 'TtIconButton labelled "$label"',
);

// ---- the app and its clean-up ----

/// What a test needs: the app, its repositories and the test media.
class _Env {
  _Env({required this.media, required this.container});

  final TestMedia media;
  final ProviderContainer container;

  ClipsRepository get clips => container.read(clipsRepositoryProvider);
  ReelsRepository get reels => container.read(reelsRepositoryProvider);
  MediaBridge get bridge => container.read(mediaBridgeProvider);

  /// The MediaStore ids of the clips waiting in To tag now (a one-off read
  /// of the database: the screen's own provider is gone when To tag is not
  /// open).
  Future<Set<int>> pendingMediaStoreIds() async => {
    for (final c in await clips.watchInbox(InboxState.pending).first)
      ?c.mediaStoreId,
  };

  /// The MediaStore ids of the clips in Skipped now.
  Future<Set<int>> skippedMediaStoreIds() async => {
    for (final c in await clips.watchInbox(InboxState.skipped).first)
      ?c.mediaStoreId,
  };

  /// The rows of the open folder list that are in the test folder or under it
  /// (nothing about any other row is read).
  Future<List<BrowseFolder>> testFolderRows() async {
    final folders = container.read(addFoldersControllerProvider).value;
    if (folders == null) throw TestFailure('The folder list is not loaded');
    return [
      for (final f in folders)
        if (_isUnderTestFolder(f.relativePath)) f,
    ];
  }
}

/// Lower case, with no slash at either end: how folders are compared.
String _norm(String relativePath) =>
    relativePath.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();

/// Whether [relativePath] is the test folder or a folder under it.
bool _isUnderTestFolder(String relativePath) {
  final folder = _norm(testFolder);
  final path = _norm(relativePath);
  return path == folder || path.startsWith('$folder/');
}

/// Sets the app up, runs [body], and always cleans up at the end (the test
/// reel, the test videos, the watched folders; the order the other Patrol
/// files use). Everything after the watched folders were changed is inside
/// the `try`, so a failure while giving access still cleans up.
///
/// Set-up, as a user would: only the test folder watched, full access from
/// To tag's own button, To tag open.
Future<void> _scenario(
  PatrolIntegrationTester $,
  Future<void> Function(_Env env) body,
) async {
  final media = await TestMedia.start();
  await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
  final container = ProviderScope.containerOf($.tester.element(_app));
  final restoreFolders = await watchOnlyTestFolder(
    container.read(settingsRepositoryProvider),
  );
  final env = _Env(media: media, container: container);

  // The test's own failure: reported after the clean-up, which runs anyway.
  (Object, StackTrace)? failure;
  try {
    final toTag = $(ToTagScreen);
    await $(TtNavPill).$(_l10n.navToTag).tap();
    await waitFor(
      $,
      () => toTag.$(_l10n.accessManualTitle).exists,
      what: 'the Manual mode banner on To tag',
    );
    await toTag.$(_l10n.accessManualAction).tap();
    await allowAllInDialog($);
    await waitFor(
      $,
      () => !toTag.$(_l10n.accessManualTitle).exists,
      what: 'the Manual mode banner to go after Allow all',
    );
    await body(env);
  } on Object catch (error, stack) {
    failure = (error, stack);
  }
  await _cleanUp(env, restoreFolders, failure: failure);
}

/// The end of the test body: the test reel, the test videos, and the camera
/// folders watched again. Each step runs even when one before it threw, and
/// then the first error is thrown: the test's own [failure] when there is
/// one, so a clean-up error never hides it.
Future<void> _cleanUp(
  _Env env,
  Future<void> Function() restoreFolders, {
  (Object, StackTrace)? failure,
}) async {
  var first = failure;
  Future<void> step(Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (error, stack) {
      first ??= (error, stack);
    }
  }

  await step(() => _deleteTestReel(env.container));
  await step(env.media.cleanUp);
  await step(restoreFolders);
  if (first case (final error, final stack)) {
    Error.throwWithStackTrace(error, stack);
  }
}

/// Deletes the test reel, with a one-off select (a stream opened here would
/// fail with a `ConcurrentModificationError` when the app closes its
/// database). A failure is printed by type and the clean-up goes on.
Future<void> _deleteTestReel(ProviderContainer container) async {
  try {
    final db = container.read(appDatabaseProvider);
    final all = await db
        .select(db.reels)
        .get()
        .timeout(const Duration(seconds: 10));
    final reels = container.read(reelsRepositoryProvider);
    for (final reel in all) {
      if (reel.name == _reelName) await reels.delete(reel.id);
    }
  } on Object catch (error) {
    debugPrint('Cleaning up the reel failed: ${error.runtimeType}');
  }
}

// ---- Add videos ----

/// Taps **Add videos** in the app bar of the screen of type [from] (To tag or
/// a reel's page; the icon button, not the empty state's text button).
Future<void> _openAddVideos(
  PatrolIntegrationTester $,
  _Env env, {
  required Type from,
}) async {
  await $(
    find.descendant(
      of: find.byType(from),
      matching: _iconButtonLabelled(_l10n.addVideosTitle),
    ),
  ).tap();
  await waitFor(
    $,
    () => _count(find.byType(AddFoldersScreen)) == 1,
    what: 'the Add videos folder list',
  );
}

/// In the folder list: waits for it to load, scrolls to the test folder's row
/// (the list is lazy, and the owner's own folders are in it: they are scrolled
/// past, never read), checks that the row says [videos] videos, and taps it.
Future<void> _openTestFolder(
  PatrolIntegrationTester $,
  _Env env, {
  required int videos,
}) async {
  await waitFor(
    $,
    () => env.container.read(addFoldersControllerProvider).value != null,
    what: 'the folder list to load',
  );
  final row = find.descendant(
    of: find.byType(AddFoldersScreen),
    matching: find.text(_testFolderName),
  );
  final scrollable = find
      .descendant(
        of: find.byType(AddFoldersScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  await $.tester.scrollUntilVisible(
    row,
    300,
    scrollable: scrollable,
    maxScrolls: 400,
  );
  expect(_count(row), 1, reason: 'one row for the test folder');
  final listRow = find.ancestor(of: row, matching: find.byType(TtListRow));
  expect(
    _count(
      find.descendant(
        of: listRow,
        matching: find.text(_l10n.addFoldersCount(videos)),
      ),
    ),
    1,
    reason: 'the test folder row says "${_l10n.addFoldersCount(videos)}"',
  );
  await $(row).tap();
  await waitFor(
    $,
    () => _count(find.byType(AddGridScreen)) == 1,
    what: "the test folder's grid",
  );
}

/// Waits until the grid shows a tile for every one of [videos].
Future<void> _waitForGridTiles(
  PatrolIntegrationTester $,
  List<InsertedVideo> videos,
) async {
  await waitFor(
    $,
    () => videos.every((v) => _count(_gridTile(v)) == 1),
    what: '${videos.length} tile(s) in the grid',
  );
  expect(_count(_gridTiles), videos.length, reason: 'only the test videos');
}

/// Taps the tile of [video] and waits for the bar to say [count] picked.
Future<void> _pick(
  PatrolIntegrationTester $,
  InsertedVideo video, {
  required int count,
}) async {
  await $(_gridTile(video)).tap();
  final text = count == 0 ? _l10n.addBarNonePicked : _l10n.addBarPicked(count);
  await waitFor(
    $,
    () => _count(find.text(text)) == 1,
    what: 'the bar to say "$text"',
  );
}

Future<void> _tapBack(PatrolIntegrationTester $) =>
    $(_iconButtonLabelled(_l10n.navBack)).tap();

/// The one tile of [tiles] uses the thumbnail cache (`ClipThumbnailImage`)
/// and its picture decodes to a real size. (Same check as
/// `media_scan_test.dart`'s, for any tile finder.)
Future<void> _expectPictureLoads(
  PatrolIntegrationTester $,
  Finder tiles,
) async {
  final image = find.descendant(of: tiles, matching: find.byType(Image));
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
