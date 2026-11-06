import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/features/tagging/views/skipped_screen.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:video_player/video_player.dart';

import 'support/system_dialogs.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// Tagging on the S24 (phase 5, Task 10): a whole day of clips tagged in the
/// tag player, Undo going back, Skip all and Skipped, and Tag scene.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`), started from cleared app data. The videos are the
/// test fixture, put into `Movies/TakeTray Test/` through the debug channel
/// (D-77) and deleted again at the end of the test body (and, if a test fails,
/// by the tear-down `TestMedia.start` registers). Nothing else on the phone is
/// read, written or deleted:
///
/// - The watched folder is set to the test folder **before** the media
///   permission is asked for, so no query the app makes could name another
///   folder. It is put back at the end of the test body (never in a
///   tear-down: see [watchOnlyTestFolder]).
/// - Full access is given the way a user gives it (To tag's **Allow full
///   access**, then "Allow all"), and Shooting mode is turned on, so the scan
///   finds the test videos.
/// - The test reels ("Patrol A", "Patrol B") are made through the reels
///   repository and deleted at the end of the body, with a one-off select (a
///   stream opened after the database is closed throws a
///   `ConcurrentModificationError`).
///
/// The words are the app's own (`AppLocalizations`), never typed twice.
///
/// **Taps in the player are raw** (`tester.tap`, then one frame), not Patrol's
/// `$().tap()`: the player never settles (a video plays and the scrub bar
/// moves), and Patrol's tap would wait its whole settle time after each one,
/// which would make the "tap to next clip" timing a measurement of the wait.
void main() {
  patrolTest(
    'tag a day: 40 clips, 30 one-tap tags into 2 reels, 5 Pick several into '
    'both, 3 Same as previous, 2 skipped',
    config: _liveConfig,
    ($) async {
      await _scenario($, clips: 40, body: (env) => _tagADay($, env));
    },
  );

  patrolTest('undo goes back: the player is on that clip again, pending', (
    $,
  ) async {
    await _scenario($, clips: 3, body: (env) => _undoGoesBack($, env));
  }, config: _liveConfig);

  patrolTest('skip all and restore: Skip all with Undo, Skip all, Skipped, '
      'restore one', ($) async {
    await _scenario($, clips: 4, body: (env) => _skipAllAndRestore($, env));
  }, config: _liveConfig);

  patrolTest('tag scene: the scene goes into the reel and leaves To tag', (
    $,
  ) async {
    await _scenario($, clips: 4, body: (env) => _tagScene($, env));
  }, config: _liveConfig);

  // The minors batch could not add this as a widget test (the snack lives in
  // the app's messenger, and a widget test cannot switch tabs under it).
  patrolTest(
    'undo after switching tabs: the Tag scene snack is still there on '
    'Reels, and its Undo brings the clips back',
    config: _liveConfig,
    ($) async {
      await _scenario($, clips: 3, body: (env) => _undoAfterTabSwitch($, env));
    },
  );
}

// =============================================================== the flows

/// Names of the two test reels.
const String _nameA = 'Patrol A';
const String _nameB = 'Patrol B';

Future<void> _tagADay(PatrolIntegrationTester $, _Env env) async {
  const total = 40;
  final toTag = $(ToTagScreen);
  expect((await env.pending()).length, total, reason: 'all 40 wait in To tag');

  // Start tagging: the first waiting clip.
  final wall = Stopwatch()..start();
  await $(_l10n.toTagStartTagging).tap();
  final player = await _Player.open($, env);
  final plan = <int, Set<int>>{}; // clip id -> reels it must be in
  final skipped = <int>{};

  Future<void> tagInto(
    String kind,
    Set<int> reels,
    Future<void> Function() tap,
  ) async {
    final id = player.currentId!;
    plan[id] = reels;
    await player.act(kind, tap);
  }

  // 1. Thirty clips, one tap each, alternating the two reels.
  for (var i = 0; i < 30; i++) {
    final reel = i.isEven ? env.a : env.b;
    await tagInto('chip', {
      reel.id,
    }, () => $.tester.tap(_chip(reel.name).first));
  }

  // 2. Five with Pick several into both. It is sticky: the second clip is
  // still picking, with nothing picked.
  await _tap($, _button(_l10n.tagPickSeveral));
  expect(player.state.multi, isTrue, reason: 'Pick several is on');
  for (var i = 0; i < 5; i++) {
    expect(player.state.multi, isTrue, reason: 'still on at pick clip $i');
    expect(player.state.picked, isEmpty, reason: 'no picks at clip $i');
    await _tap($, _chip(env.a.name));
    await _tap($, _chip(env.b.name));
    expect(player.state.picked, [env.a.id, env.b.id]);
    await tagInto('pick several', {
      env.a.id,
      env.b.id,
    }, () => $.tester.tap(_button(_l10n.tagPickConfirm(2)).first));
  }
  expect(player.state.multi, isTrue, reason: 'sticky after the confirm');
  await _tap($, _button(_l10n.cancel));
  expect(player.state.multi, isFalse, reason: 'Cancel turns it off');

  // 3. Three with Same as previous (the last tag was both reels).
  for (var i = 0; i < 3; i++) {
    await tagInto('same as previous', {
      env.a.id,
      env.b.id,
    }, () => $.tester.tap(_sameAsPrevious.first));
  }

  // 4. Two skipped.
  for (var i = 0; i < 2; i++) {
    skipped.add(player.currentId!);
    await player.act(
      'skip',
      () => $.tester.tap(_button(_l10n.tagPlayerSkip).first),
    );
  }

  // 5. All done.
  await waitFor(
    $,
    () => $(_l10n.tagDoneTitle).exists,
    what: 'the All done! screen',
  );
  wall.stop();
  expect($(_l10n.tagDoneBody(total)).exists, isTrue, reason: '40 sorted');
  // "+23" is on two rows (both reels), and Skipped says 2.
  expect(find.text(_l10n.tagDoneAdded(23)), findsNWidgets(2));
  expect($(_l10n.tagDoneSkippedRow).exists, isTrue);
  expect(find.text(_l10n.tagDoneSkippedCount(2)), findsOneWidget);
  player.report(wall.elapsed);

  // The database agrees with what was tapped, clip by clip.
  expect(await env.clips.watchPendingCount().first, 0);
  final inA = await env.reelClipIds(env.a);
  final inB = await env.reelClipIds(env.b);
  expect(inA, {
    for (final e in plan.entries)
      if (e.value.contains(env.a.id)) e.key,
  }, reason: 'the clips in Patrol A are the ones tagged into it');
  expect(inB, {
    for (final e in plan.entries)
      if (e.value.contains(env.b.id)) e.key,
  }, reason: 'the clips in Patrol B are the ones tagged into it');
  expect(inA.length, 23);
  expect(inB.length, 23);
  final skippedNow = {
    for (final c in await env.clips.watchInbox(InboxState.skipped).first) c.id,
  };
  expect(skippedNow, skipped);
  expect(skippedNow.length, 2);
  expect(plan.length + skipped.length, total);

  // Back to To tag: nothing waits, and Skipped (2) is there.
  await $(_l10n.tagDoneBack).tap();
  await waitFor(
    $,
    () => toTag.$(_l10n.toTagEmptyOnTitle).exists,
    what: 'To tag to be empty (All caught up)',
  );
  expect(
    toTag.$(_l10n.toTagSkippedButton(2)).exists,
    isTrue,
    reason: 'the Skipped (2) button under the empty state',
  );
}

Future<void> _undoGoesBack(PatrolIntegrationTester $, _Env env) async {
  await $(_l10n.toTagStartTagging).tap();
  final player = await _Player.open($, env);
  final first = player.currentId!;
  expect($(_l10n.tagPlayerTitle(1, 3)).exists, isTrue);

  await player.act('chip', () => $.tester.tap(_chip(env.a.name).first));
  expect(player.currentId, isNot(first), reason: 'moved on to the next clip');
  expect(player.state.pending, isNot(contains(first)));
  expect(await env.reelClipIds(env.a), {first});
  await waitFor(
    $,
    () => find.text(_l10n.addedToOneSnack(env.a.name)).evaluate().isNotEmpty,
    what: 'the "Added to Patrol A" snack',
  );

  await $.tester.tap(find.text(_l10n.undo).first);
  await waitFor(
    $,
    () => player.currentId == first,
    what: 'the player to go back to the clip Undo restored',
  );
  await _waitForVideo($, player, first);
  expect(player.state.pending, contains(first), reason: 'pending again');
  expect(await env.reelClipIds(env.a), isEmpty, reason: 'out of Patrol A');
  expect(await env.clips.watchPendingCount().first, 3);
  expect($(_l10n.tagPlayerTitle(1, 3)).exists, isTrue, reason: '1 of 3 again');

  // And the same for a skip.
  await player.act(
    'skip',
    () => $.tester.tap(_button(_l10n.tagPlayerSkip).first),
  );
  await waitFor(
    $,
    () => find.text(_l10n.tagSkippedSnack).evaluate().isNotEmpty,
    what: 'the Skipped snack',
  );
  expect(await env.clips.watchSkippedCount().first, 1);
  await $.tester.tap(find.text(_l10n.undo).first);
  await waitFor(
    $,
    () => player.currentId == first && player.state.pending.contains(first),
    what: 'the player on the skipped clip again, pending',
  );
  expect(await env.clips.watchSkippedCount().first, 0);
}

Future<void> _skipAllAndRestore(PatrolIntegrationTester $, _Env env) async {
  const total = 4;
  final toTag = $(ToTagScreen);
  final dialog = find.byWidgetPredicate(
    (w) => w is TtDialog,
    description: 'TtDialog',
  );

  Future<void> skipAll() async {
    await toTag.$(Symbols.more_vert_rounded).tap();
    await $(_l10n.toTagMenuSkipAll).tap();
    await waitFor(
      $,
      () => $(dialog).$(_l10n.skipAllTitle(total)).exists,
      what: 'the "Skip all $total clips?" dialog',
    );
    expect($(dialog).$(_l10n.skipAllBody).exists, isTrue);
    expect($(dialog).$(_l10n.skipAllSafe).exists, isTrue);
  }

  // Cancel changes nothing.
  await skipAll();
  await $(dialog).$(_l10n.cancel).tap();
  await waitFor($, () => !$(dialog).exists, what: 'the dialog to close');
  expect(await env.clips.watchPendingCount().first, total);

  // Skip all, then Undo.
  await skipAll();
  await $(dialog).$(_l10n.skipAllConfirm).tap();
  await waitFor(
    $,
    () => find.text(_l10n.toTagClipsSkippedSnack(total)).evaluate().isNotEmpty,
    what: 'the "$total clips skipped" snack',
  );
  expect(await env.clips.watchPendingCount().first, 0);
  expect(await env.clips.watchSkippedCount().first, total);
  await $.tester.tap(find.text(_l10n.undo).first);
  await _waitForPending($, env, total, 'the clips back in To tag after Undo');
  expect(await env.clips.watchSkippedCount().first, 0);

  // Skip all again, for good; the empty state offers Skipped (4).
  await skipAll();
  await $(dialog).$(_l10n.skipAllConfirm).tap();
  await waitFor(
    $,
    () => toTag.$(_l10n.toTagEmptyOnTitle).exists,
    what: 'To tag to be empty after Skip all',
  );
  expect(await env.clips.watchSkippedCount().first, total);
  await toTag.$(_l10n.toTagSkippedButton(total)).tap();
  final skippedScreen = $(SkippedScreen);
  await waitFor(
    $,
    () => skippedScreen.exists && skippedScreen.$(_l10n.skippedInfo).exists,
    what: 'the Skipped screen with its info bar',
  );
  final tiles = find.byType(TtClipTile);
  await waitFor(
    $,
    () => tiles.evaluate().length == total,
    what: '$total skipped tiles',
  );

  // A tap on a tile restores that clip.
  final before = {
    for (final c in await env.clips.watchInbox(InboxState.skipped).first) c.id,
  };
  await $.tester.tap(tiles.first);
  await waitFor(
    $,
    () => find.text(_l10n.skippedRestoredOne).evaluate().isNotEmpty,
    what: 'the "Restored to To tag" snack',
  );
  expect(await env.clips.watchPendingCount().first, 1);
  expect(await env.clips.watchSkippedCount().first, total - 1);
  final pending = await env.pending();
  expect(pending.length, 1);
  expect(before, contains(pending.single), reason: 'the restored clip');
  await waitFor(
    $,
    () => tiles.evaluate().length == total - 1,
    what: 'the restored tile to leave Skipped',
  );

  // Back to To tag: that one clip waits.
  await $(
    find.byWidgetPredicate(
      (w) => w is TtIconButton && w.semanticLabel == _l10n.navBack,
    ),
  ).tap();
  await waitFor(
    $,
    () => toTag.exists && find.byType(TtClipTile).evaluate().length == 1,
    what: 'To tag with the one restored clip',
  );
}

Future<void> _tagScene(PatrolIntegrationTester $, _Env env) async {
  const total = 4;
  await _tagSceneInto($, env, env.a, total);
  await waitFor(
    $,
    () => find.byType(TtClipTile).evaluate().isEmpty,
    what: 'the scene to leave To tag',
  );
  expect($(ToTagScreen).$(_l10n.toTagEmptyOnTitle).exists, isTrue);
  expect(await env.clips.watchPendingCount().first, 0);
  expect((await env.reelClipIds(env.a)).length, total);
  expect(await env.reelClipIds(env.b), isEmpty);
}

/// Tag scene on the one scene of [total] clips, into [reel], through the
/// picker; leaves with the snack showing.
Future<void> _tagSceneInto(
  PatrolIntegrationTester $,
  _Env env,
  Reel reel,
  int total,
) async {
  expect(
    find.byType(TtSceneHeader),
    findsOneWidget,
    reason: 'the clips are one scene (not a run across midnight)',
  );
  await $(_l10n.toTagTagScene).tap();
  await waitFor(
    $,
    () => $(TtSheet).$(_l10n.pickerSubtitleTag).exists,
    what: 'the picker in tag mode',
  );
  expect($(TtSheet).$(_l10n.pickerTitleTag(total)).exists, isTrue);
  await $.tester.tap(
    find
        .byWidgetPredicate((w) => w is TtReelPickRow && w.name == reel.name)
        .first,
  );
  await $.tester.pump();
  await $.tester.tap(
    find
        .descendant(
          of: find.byType(TtSheet),
          matching: _button(_l10n.pickerTitleTag(total)),
        )
        .first,
  );
  await waitFor(
    $,
    () => find
        .text(_l10n.tagClipsAddedSnack(total, reel.name))
        .evaluate()
        .isNotEmpty,
    what: 'the "$total clips added to ${reel.name}" snack',
  );
}

Future<void> _undoAfterTabSwitch(PatrolIntegrationTester $, _Env env) async {
  const total = 3;
  await _tagSceneInto($, env, env.a, total);
  expect((await env.reelClipIds(env.a)).length, total);

  // Straight to the Reels tab: the snack belongs to the app, not to the tab.
  await $(TtNavPill).$(_l10n.navReels).tap();
  await waitFor($, () => $(ReelsScreen).exists, what: 'the Reels tab');
  expect(
    find.text(_l10n.undo),
    findsOneWidget,
    reason: 'the Undo snack is still showing after the tab switch',
  );
  await $.tester.tap(find.text(_l10n.undo).first);
  await _waitForPending(
    $,
    env,
    total,
    'the clips back in To tag after Undo from the Reels tab',
  );
  expect(await env.reelClipIds(env.a), isEmpty, reason: 'out of Patrol A');

  // And they are tiles on To tag again.
  await $(TtNavPill).$(_l10n.navToTag).tap();
  await waitFor(
    $,
    () => find.byType(TtClipTile).evaluate().length == total,
    what: '$total tiles on To tag after Undo',
  );
}

// ============================================================ the scaffold

final Finder _app = find.byType(TakeTrayApp);

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The player plays a video and the scrub bar moves, and the Shooting mode
// strip pulses: never wait for the screen to settle, only for the thing the
// test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

/// A [TtButton] by its label.
Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is TtButton && w.label == label,
  description: 'TtButton "$label"',
);

/// The reel chip of the tag player for the reel called [name].
Finder _chip(String name) => find.byWidgetPredicate(
  (w) => w is TtReelChip && w.name == name,
  description: 'TtReelChip "$name"',
);

final Finder _sameAsPrevious = find.byType(TtSameAsPreviousButton);

/// A raw tap, then one frame: for buttons whose timing does not matter.
Future<void> _tap(PatrolIntegrationTester $, Finder finder) async {
  await $.tester.tap(finder.first);
  await $.tester.pump();
}

/// What a scenario needs: the app, its repositories and the two test reels.
class _Env {
  _Env({
    required this.media,
    required this.container,
    required this.a,
    required this.b,
  });

  final TestMedia media;
  final ProviderContainer container;
  final Reel a;
  final Reel b;

  ClipsRepository get clips => container.read(clipsRepositoryProvider);
  ReelsRepository get reels => container.read(reelsRepositoryProvider);

  /// The ids of the clips waiting in To tag now, read from the database (a
  /// one-off read: the screen's own provider is gone when To tag is not open).
  Future<List<int>> pending() async => [
    for (final clip in await clips.watchInbox(InboxState.pending).first)
      clip.id,
  ];

  /// The ids of the clips in [reel] now.
  Future<Set<int>> reelClipIds(Reel reel) async => {
    for (final c in await clips.watchReelClips(reel.id).first) c.clip.id,
  };
}

/// Sets the app up, runs [body], and always cleans up at the end of the test
/// body (the reels, the videos, the watched folders; the order is the one the
/// other Patrol tests use). Everything after the watched folders were changed
/// is inside the `try`, so a failure while giving access, turning Shooting
/// mode on or making the reels still cleans up.
///
/// Set-up, as a user would: only the test folder watched, full access from
/// To tag's own button, Shooting mode on, two reels, [clips] test videos
/// (inserted after Shooting mode is on, so the scan finds them), and To tag
/// open with exactly [clips] clips waiting.
Future<void> _scenario(
  PatrolIntegrationTester $, {
  required int clips,
  required Future<void> Function(_Env env) body,
}) async {
  final media = await TestMedia.start();
  await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
  final container = ProviderScope.containerOf($.tester.element(_app));
  final restoreFolders = await watchOnlyTestFolder(
    container.read(settingsRepositoryProvider),
  );
  final toTag = $(ToTagScreen);

  // The test's own failure: reported after the clean-up, which runs anyway.
  (Object, StackTrace)? failure;
  try {
    // Full access, the way a user gives it.
    await $(TtNavPill).$(_l10n.navToTag).tap();
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

    // Shooting mode on, two reels, the videos.
    await $(TtNavPill).$(_l10n.navReels).tap();
    await _setShootingMode($, container, on: true);
    final reels = container.read(reelsRepositoryProvider);
    final a = await reels.create(_nameA);
    final b = await reels.create(_nameB);
    final env = _Env(media: media, container: container, a: a, b: b);
    await media.insertMany(clips);

    // To tag finds all of them (it scans when it opens).
    await $(TtNavPill).$(_l10n.navToTag).tap();
    await _waitForPending(
      $,
      env,
      clips,
      'To tag to hold the $clips test videos',
      timeout: const Duration(seconds: 120),
    );
    await waitFor(
      $,
      () => find.byType(TtClipTile).evaluate().isNotEmpty,
      what: 'the first tiles on To tag',
    );

    await body(env);
  } on Object catch (error, stack) {
    failure = (error, stack);
  }
  await _cleanUp(container, media, restoreFolders, failure: failure);
}

/// Waits until exactly [count] clips are waiting in the database.
Future<void> _waitForPending(
  PatrolIntegrationTester $,
  _Env env,
  int count,
  String what, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while ((await env.pending()).length != count) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what '
        '(${(await env.pending()).length} waiting, wanted $count)',
      );
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}

/// The end of the test body: the test reels, the test videos, and the camera
/// folders watched again. Each step runs even when one before it threw (the
/// folders above all), and then the first error is thrown: the test's own
/// [failure] when there is one, so a clean-up error never hides it.
Future<void> _cleanUp(
  ProviderContainer container,
  TestMedia media,
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

  await step(() => _deleteTestReels(container));
  await step(media.cleanUp);
  await step(restoreFolders);
  if (first case (final error, final stack)) {
    Error.throwWithStackTrace(error, stack);
  }
}

/// Deletes the two test reels, with a one-off select (a stream opened here
/// would fail with a `ConcurrentModificationError` when the app closes its
/// database). A failure is printed by type and the clean-up goes on.
Future<void> _deleteTestReels(ProviderContainer container) async {
  try {
    final db = container.read(appDatabaseProvider);
    final all = await db
        .select(db.reels)
        .get()
        .timeout(const Duration(seconds: 10));
    final reels = container.read(reelsRepositoryProvider);
    for (final reel in all) {
      if (reel.name == _nameA || reel.name == _nameB) {
        await reels.delete(reel.id);
      }
    }
  } on Object catch (error) {
    debugPrint('Cleaning up the reels failed: ${error.runtimeType}');
  }
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
    await $(ReelsScreen).$(TtSwitch).tap();
    // The first time Shooting mode goes on, the app asks for the
    // notification permission (Android 13 and later; D-107).
    if (on) await allowNotificationsInDialog($);
  }
  await waitFor(
    $,
    () => stored() == on,
    what: 'Shooting mode to be stored as ${on ? 'on' : 'off'}',
  );
}

// ========================================================= the tag player

/// One action's timing (milliseconds from the tap).
class _Timing {
  _Timing(
    this.kind,
    this.toNextClip,
    this.toPlaying,
    this.toMoving,
    this.peakControllers,
  );

  final String kind;

  /// Until the player shows the next clip (the hold, the write, the move).
  final int toNextClip;

  /// Until the next clip's own player is on screen, initialized and playing
  /// (its first frame; -1 when the tag was the last clip: All done).
  final int toPlaying;

  /// Until ExoPlayer itself reports a position past zero for that clip (asked
  /// over the channel, not the plugin's 500 ms timer): frames are really
  /// being played (-1 when the tag was the last clip).
  final int toMoving;

  /// The most live clip controllers seen between the tap and then.
  final int peakControllers;
}

/// The open tag player, and the timing of what is done in it.
class _Player {
  _Player._(this.$, this.env, this.startId);

  final PatrolIntegrationTester $;
  final _Env env;
  final int startId;
  final List<_Timing> timings = [];
  late final List<Uri> _uris;
  var _peak = 0;

  /// Waits for the player to open on the first clip and for that clip's video
  /// to play. Fails if it opens on another clip than To tag's first.
  static Future<_Player> open(PatrolIntegrationTester $, _Env env) async {
    await waitFor($, () => $(TagPlayerScreen).exists, what: 'the tag player');
    final startId = $.tester
        .widget<TagPlayerScreen>(find.byType(TagPlayerScreen))
        .startClipId;
    expect(startId, isNotNull, reason: 'Start tagging names its clip');
    final player = _Player._($, env, startId!);
    await waitFor(
      $,
      () => player._session.value != null,
      what: 'the tag session to load',
    );
    player._uris = [
      for (final clip in player.state.clips.values) ?clipVideoUri(clip),
    ];
    expect(player._uris.length, player.state.session.length);
    expect(player.currentId, startId, reason: 'opens on the clip it was told');
    await _waitForVideo($, player, startId);
    return player;
  }

  AsyncValue<TagSessionState> get _session =>
      env.container.read(tagSessionControllerProvider(startId));

  TagSessionState get state => _session.requireValue;

  int? get currentId => state.currentClipId;

  /// How many clip controllers are alive now: the clips whose
  /// `clipPlayerProvider` exists in the container.
  int liveControllers() {
    var live = 0;
    for (final uri in _uris) {
      if (env.container.exists(
        clipPlayerProvider(uri, use: ClipPlayerUse.tagging, autoplay: false),
      )) {
        live++;
      }
    }
    return live;
  }

  /// Whether the video on screen for [clip] is that clip's own: a
  /// `VideoPlayer` whose controller was opened from the clip's address, ready
  /// and playing.
  bool playing(Clip clip) => playingController(clip) != null;

  /// The controller on screen for [clip] when it is ready and playing.
  VideoPlayerController? playingController(Clip clip) {
    final address = clipVideoUri(clip)?.toString();
    if (address == null) return null;
    for (final element in find.byType(VideoPlayer).evaluate()) {
      final controller = (element.widget as VideoPlayer).controller;
      final value = controller.value;
      if (controller.dataSource == address &&
          value.isInitialized &&
          value.isPlaying) {
        return controller;
      }
    }
    return null;
  }

  /// Runs [tap] (which taps one thing), then waits for the player to go to
  /// the next clip and for that clip's video to play, timing both. The peak
  /// number of live controllers is sampled on every frame meanwhile.
  Future<void> act(String kind, Future<void> Function() tap) async {
    final from = currentId;
    final clock = Stopwatch()..start();
    await tap();
    var toNext = -1;
    var toPlaying = -1;
    var toMoving = -1;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    var peak = liveControllers();
    while (true) {
      await $.tester.pump(const Duration(milliseconds: 4));
      peak = peak < liveControllers() ? liveControllers() : peak;
      final s = state;
      if (toNext < 0 && (s.done || s.currentClipId != from)) {
        toNext = clock.elapsedMilliseconds;
      }
      if (toNext >= 0) {
        if (s.done) break;
        final clip = s.currentClip;
        final controller = clip == null ? null : playingController(clip);
        if (controller != null) {
          toPlaying = clock.elapsedMilliseconds;
          // Ask the player itself, over the channel, until it has moved.
          while ((await controller.position ?? Duration.zero) <=
              Duration.zero) {
            if (DateTime.now().isAfter(deadline)) {
              throw TestFailure('After "$kind" the video never moved');
            }
            await $.tester.pump(const Duration(milliseconds: 2));
            peak = peak < liveControllers() ? liveControllers() : peak;
          }
          toMoving = clock.elapsedMilliseconds;
          break;
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure(
          'After "$kind" the player did not reach the next clip playing in '
          '20 s (moved on: ${toNext >= 0}, clip was $from)',
        );
      }
    }
    // A few more frames, to see the controller left behind go (the third one
    // for a moment is the ruling).
    for (var i = 0; i < 25; i++) {
      await $.tester.pump(const Duration(milliseconds: 20));
      peak = peak < liveControllers() ? liveControllers() : peak;
    }
    if (peak > _peak) _peak = peak;
    timings.add(_Timing(kind, toNext, toPlaying, toMoving, peak));
  }

  /// Prints the numbers (the Phase 5 report reads them from the log).
  void report(Duration wall) {
    // One Patrol log line each (a line over about 4000 characters is cut by
    // logcat and Patrol cannot read it); debugPrint keeps them in logcat too.
    void line(String text) {
      debugPrint(text);
      $.log(text);
    }

    String stats(Iterable<int> values) {
      final sorted = values.toList()..sort();
      if (sorted.isEmpty) return 'none';
      final avg = sorted.reduce((a, b) => a + b) ~/ sorted.length;
      int at(double p) => sorted[((sorted.length - 1) * p).round()];
      return 'n=${sorted.length} avg=$avg ms p50=${at(0.5)} p95=${at(0.95)} '
          'max=${sorted.last}';
    }

    final played = timings.where((t) => t.toPlaying >= 0).toList();
    line(
      'TIMING wall time (Start tagging to All done): '
      '${wall.inMilliseconds} ms for ${timings.length} actions',
    );
    line(
      'TIMING tap to next clip shown: '
      '${stats(played.map((t) => t.toNextClip))}',
    );
    line(
      'TIMING tap to next clip playing: '
      '${stats(played.map((t) => t.toPlaying))}',
    );
    line(
      'TIMING next clip shown to playing: '
      '${stats(played.map((t) => t.toPlaying - t.toNextClip))}',
    );
    for (final kind in {for (final t in timings) t.kind}) {
      line(
        'TIMING   $kind: tap to playing '
        '${stats(played.where((t) => t.kind == kind).map((t) => t.toPlaying))}',
      );
    }
    line(
      'TIMING tap to ExoPlayer position past zero: '
      '${stats(played.map((t) => t.toMoving))}',
    );
    for (final kind in {for (final t in timings) t.kind}) {
      line(
        'TIMING   $kind: tap to position past zero '
        '${stats(played.where((t) => t.kind == kind).map((t) => t.toMoving))}',
      );
    }
    final over = played.where((t) => t.toMoving >= 1000).length;
    line(
      'TIMING clips at or over 1000 ms tap to position past zero: $over of '
      '${played.length}',
    );
    line('TIMING peak live clip controllers: $_peak');
    final each = [
      for (final t in timings)
        '${t.kind}=${t.toNextClip}/${t.toPlaying}/${t.toMoving}',
    ];
    line('TIMING every tap, shown/playing/moving ms, in order: $each');
    final histogram = <int, int>{};
    for (final t in timings) {
      histogram[t.peakControllers] = (histogram[t.peakControllers] ?? 0) + 1;
    }
    line(
      'TIMING controllers peak per action (count: actions): '
      '$histogram',
    );
  }
}

/// Waits until the video on screen is [clipId]'s own and playing.
Future<void> _waitForVideo(
  PatrolIntegrationTester $,
  _Player player,
  int clipId,
) => waitFor(
  $,
  () {
    final clip = player.state.clips[clipId];
    return clip != null && player.playing(clip);
  },
  what: "the clip's own video to play",
  timeout: const Duration(seconds: 30),
);
