import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/own_texts.dart';
import 'support/shade.dart';
import 'support/system_dialogs.dart';
import 'support/test_background.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// Background detection and notifications on the S24 (phase 6, Task 9).
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`), started from cleared app data. The videos are the
/// test fixture, put into `Movies/TakeTray Test/` through the debug channel
/// (D-77) and deleted again at the end of the test body (and, if a test
/// fails, by the tear-down `TestMedia.start` registers). Nothing else on the
/// phone is read, written or deleted:
///
/// - Only the test folder is watched (`watchOnlyTestFolder`), before the
///   media permission is asked for, and the settings are put back at the end
///   of the body. Full access is given the way a user gives it (To tag's
///   **Allow full access**, then "Allow all"); the notification permission
///   through its system dialog when Shooting mode is turned on (Android 13
///   and later asks once, D-107).
/// - **The shade.** Only TakeTray's own notifications are found and tapped,
///   by a whole text only TakeTray writes, matched exactly (`OwnText`,
///   `support/shade.dart`). Nothing in the shade is listed, printed or
///   stored. The Still shooting? "Turn off" is tapped only at the spot two
///   looks at the shade agree is TakeTray's own button: directly below
///   TakeTray's own text, on one row with TakeTray's own "Keep on". What a
///   test needs to know without opening the shade, it asks the app itself:
///   `activeNotifications` and `pendingJobs` return only this app's own
///   notifications and jobs.
/// - **Shooting mode** is turned off again at the end of the body, which
///   cancels the job and the notification.
/// - **The hooks** (`app.taketray/test_background`) reach the same code the
///   alarm, the receiver and the job use (`DebugBackgroundHooks.kt`), so a
///   hook is only used where the system cannot be made to do it on demand
///   (an alarm at a fixed time, a forced job run).
/// - Nothing is printed that holds a name, a path, a folder or a count of a
///   named reel (D-10). No screenshots.
///
/// **Timing.** The first flow prints how long a new video takes to show as a
/// notification in the shade ("insert-to-notification"), from the real
/// content trigger. The sixth prints how late the real evening alarm came.
/// Opening the shade costs a little: the polls are a quarter of a second
/// apart, and each asks Android's UI automation for one view.
///
/// **Opening the shade moves the app's focus** (Android tells the app it is
/// inactive, then resumed), and a resume scans and removes the new-clips
/// notification. So the flow that has to find the notification still showing
/// while the app is open (`turning off removes the notification`) never
/// opens the shade before turning Shooting mode off.
void main() {
  patrolTest(
    'new clips notification appears and opens To tag',
    config: _liveConfig,
    ($) async {
      await _scenario($, body: (env) => _newClipsOpensToTag($, env));
    },
  );

  patrolTest('turning off removes the notification', config: _liveConfig, (
    $,
  ) async {
    await _scenario($, body: (env) => _turningOffRemoves($, env));
  });

  patrolTest("evening reminder counts today's clips", config: _liveConfig, (
    $,
  ) async {
    await _scenario($, body: (env) => _eveningCounts($, env));
  });

  patrolTest('still shooting turn off from the shade', config: _liveConfig, (
    $,
  ) async {
    await _scenario($, body: (env) => _stillTurnOffFromShade($, env));
  });

  patrolTest('still shooting dialog', config: _liveConfig, ($) async {
    await _scenario($, body: (env) => _stillDialog($, env));
  });

  // Not one of the five in the plan: the real alarm, at a time that is set,
  // which no hook can stand in for (the hook only proves the receiver).
  patrolTest('evening reminder fires at its set time', config: _liveConfig, (
    $,
  ) async {
    await _scenario($, body: (env) => _eveningAlarmFires($, env));
  });

  // Not one of the five in the plan: several bursts of inserts leave exactly
  // one new-clips job pending (spec §8.3, D-104).
  patrolTest(
    'one new-clips job stays pending through several insert bursts',
    config: _liveConfig,
    ($) async {
      await _scenario($, body: (env) => _oneJobPending($, env));
    },
  );
}

// =============================================================== the flows

final _oneNewClip = OwnText.newClips(1);
final _twoNewClips = OwnText.newClips(2);
final _eveningTwoClips = OwnText.evening(2);

Future<void> _newClipsOpensToTag(PatrolIntegrationTester $, _Env env) async {
  // 1. Shooting mode is on (the scenario did it), the app on Reels. Home,
  // then two videos; the shade open meanwhile so the first poll sees the
  // notification at once.
  await _showReels($);
  await $.platform.mobile.pressHome();
  await openShade($);
  final clock = Stopwatch()..start();
  await env.media.insert();
  await env.media.insert();
  final inserted = clock.elapsed;
  expect(await env.bg.pendingJobs(), [
    TestBackground.newClipsJobId,
  ], reason: 'the insert burst left exactly one job armed');

  // 2. The real content trigger (not a hook) posts "2 new clips to tag".
  final took = await waitForShade(
    $,
    _twoNewClips,
    since: clock,
    background: env.bg,
  );
  debugPrint(
    'insert-to-notification: ${took.inMilliseconds} ms from the first insert '
    '(${(took - inserted).inMilliseconds} ms after the last of 2)',
  );
  expect(await env.bg.pendingJobs(), [
    TestBackground.newClipsJobId,
  ], reason: 'the job armed its successor after the run');

  // 3. A tap opens To tag with the two clips; the notification is gone.
  await tapNotification($, _twoNewClips);
  await _expectToTagOpened($, 2, 'the new-clips notification');
  await _waitUntil(
    $,
    () async => !(await env.bg.activeNotifications()).contains(
      TestBackground.newClipsId,
    ),
    what: 'the new-clips notification to be removed by the scan',
  );
  await openShade($);
  await waitForShadeToLose($, _twoNewClips);
  await closeShade($);
}

Future<void> _turningOffRemoves(PatrolIntegrationTester $, _Env env) async {
  // 1. The app stays open on Reels. A video arrives; the real trigger posts
  // the notification. The shade is not opened (see the file comment): the
  // app's own list of its notifications says it is showing.
  await env.media.insert();
  await _waitUntil(
    $,
    () async => (await env.bg.activeNotifications()).contains(
      TestBackground.newClipsId,
    ),
    what: 'the new-clips notification to show',
    heat: env.bg,
    timeout: const Duration(seconds: 60),
  );

  // 2. Shooting mode off in the app: the notification is gone, and the job.
  await _setShootingMode($, env.container, on: false);
  await _waitUntil(
    $,
    () async => !(await env.bg.activeNotifications()).contains(
      TestBackground.newClipsId,
    ),
    what: 'the new-clips notification to go when Shooting mode is off',
    timeout: const Duration(seconds: 30),
  );
  await _waitUntil(
    $,
    () async => (await env.bg.pendingJobs()).isEmpty,
    what: 'the new-clips job to be cancelled when Shooting mode is off',
    timeout: const Duration(seconds: 30),
  );

  // 3. A run of the job after Off does not post it again.
  await env.bg.runNewClipsJob();
  expect(
    await env.bg.activeNotifications(),
    isNot(contains(TestBackground.newClipsId)),
    reason: 'a job run with Shooting mode off posts nothing',
  );

  // 4. The shade agrees (one video: "1 new clip to tag").
  await openShade($);
  await waitForShadeToLose($, _oneNewClip);
  await closeShade($);
}

Future<void> _eveningCounts(PatrolIntegrationTester $, _Env env) async {
  // 1. Two clips shot today wait in To tag.
  await env.media.insert();
  await env.media.insert();
  await $(TtNavPill).$('To tag').tap();
  await _waitForPending($, env, 2, 'To tag to hold the 2 test videos');
  // The phone's copy has the waiting clips and the new baselines together.
  await env.container.read(backgroundSyncProvider).flush();
  // Back to Reels: Android brings the app back on its last screen, so only
  // a tap that routes can show To tag again.
  await _showReels($);

  // 2. The evening reminder, through its own receiver; the shade shows it.
  await $.platform.mobile.pressHome();
  await openShade($);
  final clock = Stopwatch()..start();
  await env.bg.fireEvening();
  await waitForShade(
    $,
    _eveningTwoClips,
    since: clock,
    timeout: const Duration(seconds: 30),
  );

  // 3. A tap opens To tag, with the 2 clips.
  await tapNotification($, _eveningTwoClips);
  await _expectToTagOpened($, 2, 'the evening reminder');
}

Future<void> _stillTurnOffFromShade(PatrolIntegrationTester $, _Env env) async {
  // 1. Still shooting? in the shade, for the stored session.
  await $.platform.mobile.pressHome();
  await openShade($);
  final clock = Stopwatch()..start();
  await env.bg.fireStill();
  await waitForShade(
    $,
    OwnText.stillBody,
    since: clock,
    timeout: const Duration(seconds: 30),
  );

  // 2. One video, then Turn off in the shade (the app stays closed). The
  // video's own notification ("1 new clip to tag") is posted first, so it
  // cannot move the Still shooting? row between the looks and the tap; and
  // the first video is then known to be seen before Off.
  final first = await env.media.insert();
  await _waitUntil(
    $,
    () async => (await env.bg.activeNotifications()).contains(
      TestBackground.newClipsId,
    ),
    what: 'the new-clips notification for the first video',
    heat: env.bg,
    timeout: const Duration(seconds: 60),
    pump: false,
  );
  // The shade's own animation for the new row.
  await Future<void>.delayed(const Duration(seconds: 1));
  await tapOwnButton(
    $,
    ownText: OwnText.stillBody,
    button: StillButton.turnOff,
    background: env.bg,
  );
  await closeShade($);

  // 3. One more video, after the tap: it must stay out.
  await env.media.insert();
  await Future<void>.delayed(const Duration(seconds: 3));

  // 4. The app opens: Shooting mode is off, and only the first video waits.
  await $.platform.mobile.openApp();
  await waitFor(
    $,
    () => env.container.read(shootingModeControllerProvider).value?.on == false,
    what: 'Shooting mode to be off after the shade Turn off',
    timeout: const Duration(seconds: 60),
  );
  await _waitForPending($, env, 1, 'To tag to hold only the first video');
  await pumpFor($, const Duration(seconds: 3));
  final waiting = await env.pending();
  expect(waiting, hasLength(1), reason: 'the video after the tap stays out');
  expect(
    waiting.single.mediaStoreId,
    first.mediaStoreId,
    reason: 'the one waiting is the video from before the tap',
  );
  expect(
    await env.bg.pendingJobs(),
    isEmpty,
    reason: 'Shooting mode off stops the job',
  );
}

Future<void> _stillDialog(PatrolIntegrationTester $, _Env env) async {
  // 1. The session started 15 days ago (the stored start, through the same
  // table the repository writes).
  final db = env.container.read(appDatabaseProvider);
  final shooting = await env.container
      .read(phoneStateRepositoryProvider)
      .loadShooting();
  expect(shooting.on, isTrue);
  await db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: PhoneStateRepository.shootingModeKey,
          value: jsonEncode(
            shooting
                .copyWith(
                  since: DateTime.now().toUtc().subtract(
                    const Duration(days: 15),
                  ),
                )
                .toJson(),
          ),
        ),
      );

  // 2. Reels is asked to look again: away to To tag and back.
  await $(TtNavPill).$('To tag').tap();
  await $(TtNavPill).$('Reels').tap();
  await waitFor(
    $,
    () => $('Still shooting?').exists,
    what: 'the Still shooting? dialog on Reels',
  );
  expect($('Keep it on').exists, isTrue);
  expect($('Turn off').exists, isTrue);

  // 3. Keep it on: the answer is stored, Shooting mode stays on.
  await $('Keep it on').tap();
  await waitFor(
    $,
    () => !$('Still shooting?').exists,
    what: 'the dialog to close after Keep it on',
  );
  await _waitUntil($, () async {
    final now = await env.container
        .read(phoneStateRepositoryProvider)
        .loadShooting();
    return now.on && now.stillAnswered;
  }, what: 'Keep it on to be stored for the session');

  // 4. It does not show again after a resume.
  await $.platform.mobile.pressHome();
  await $.platform.mobile.openApp();
  await pumpFor($, const Duration(seconds: 4));
  expect(
    $('Still shooting?').exists,
    isFalse,
    reason: 'asked once per session, and answered',
  );
}

Future<void> _eveningAlarmFires(PatrolIntegrationTester $, _Env env) async {
  final start = DateTime.now();
  if (start.hour * 60 + start.minute + 4 >= Duration.minutesPerDay) {
    throw TestFailure(
      'Too close to midnight for an evening alarm two minutes from now: run '
      'this test again after midnight',
    );
  }

  // 1. Two clips shot today wait in To tag.
  await env.media.insert();
  await env.media.insert();
  await $(TtNavPill).$('To tag').tap();
  await _waitForPending($, env, 2, 'To tag to hold the 2 test videos');
  // Back to Reels, so that only the tap can open To tag (as in flow 3).
  await _showReels($);

  // 2. The evening reminder is set two minutes ahead, through the settings
  // (the folders are restored by the clean-up).
  final settings = env.container.read(settingsRepositoryProvider);
  final now = DateTime.now();
  final minutes = now.hour * 60 + now.minute + 2;
  await settings.save(
    (await settings.load()).copyWith(
      eveningReminderEnabled: true,
      eveningReminderMinutes: minutes,
    ),
  );
  await env.container.read(backgroundSyncProvider).flush();
  final due = DateTime(now.year, now.month, now.day, 0, minutes);

  // 3. The app goes away; the real alarm brings the reminder. The app's own
  // list says when it is there (the shade stays closed until it is).
  await $.platform.mobile.pressHome();
  await _waitUntil(
    $,
    () async =>
        (await env.bg.activeNotifications()).contains(TestBackground.eveningId),
    what: 'the evening reminder to come from the alarm',
    timeout: const Duration(minutes: 7),
    pump: false,
  );
  final delay = DateTime.now().difference(due);
  debugPrint(
    'evening alarm: ${delay.inSeconds} s after the minute it was set for',
  );
  expect(
    delay,
    greaterThanOrEqualTo(Duration.zero),
    reason: 'an inexact alarm never comes early',
  );

  // 4. The shade shows the count of today's clips; a tap opens To tag.
  await openShade($);
  await waitForShade(
    $,
    _eveningTwoClips,
    since: Stopwatch()..start(),
    timeout: const Duration(seconds: 30),
  );
  await tapNotification($, _eveningTwoClips);
  await _expectToTagOpened($, 2, 'the evening reminder from the alarm');
}

Future<void> _oneJobPending(PatrolIntegrationTester $, _Env env) async {
  final jobs = [TestBackground.newClipsJobId];
  expect(await env.bg.pendingJobs(), jobs, reason: 'armed by Shooting mode');

  // Three bursts of inserts, a little apart: still exactly one job.
  for (var burst = 0; burst < 3; burst++) {
    await env.media.insert();
    expect(
      await env.bg.pendingJobs(),
      jobs,
      reason: 'one job after burst ${burst + 1}',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  // The run that follows posts the count of all three, and arms one successor.
  await _waitUntil(
    $,
    () async => (await env.bg.activeNotifications()).contains(
      TestBackground.newClipsId,
    ),
    what: 'the new-clips notification after the bursts',
    heat: env.bg,
    timeout: const Duration(seconds: 60),
    pump: false,
  );
  await _waitUntil(
    $,
    () async => (await env.bg.pendingJobs()).length == 1,
    what: 'exactly one job pending after the run',
    timeout: const Duration(seconds: 15),
    pump: false,
  );
  expect(await env.bg.pendingJobs(), jobs);
}

// ============================================================ the set-up

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

class _Env {
  _Env({required this.media, required this.container, required this.bg});

  final TestMedia media;
  final ProviderContainer container;
  final TestBackground bg;

  /// The clips waiting in To tag now (a one-off read).
  Future<List<Clip>> pending() => container
      .read(clipsRepositoryProvider)
      .watchInbox(InboxState.pending)
      .first;
}

/// Sets the app up, runs [body], and always cleans up at the end of the test
/// body (Shooting mode off, the videos, the watched folders).
Future<void> _scenario(
  PatrolIntegrationTester $, {
  required Future<void> Function(_Env env) body,
}) async {
  // A hot phone makes the system hold the new-clips job (seen on the S24
  // after a few flows in a row): wait, idle, for it to cool before a flow
  // starts. Each wait for the job is still guarded on its own
  // (`requireCool`), and no timeout is longer for it.
  await TestBackground().waitUntilCool();
  final media = await TestMedia.start();
  await $.pumpWidget(const ProviderScope(child: TakeTrayApp()));
  final container = ProviderScope.containerOf($.tester.element(_app));
  final restoreFolders = await watchOnlyTestFolder(
    container.read(settingsRepositoryProvider),
  );
  final toTag = $(ToTagScreen);
  final env = _Env(media: media, container: container, bg: TestBackground());

  (Object, StackTrace)? failure;
  try {
    // Full access, the way a user gives it.
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

    // Shooting mode on; its first question is the notification permission.
    await $(TtNavPill).$('Reels').tap();
    await _turnShootingOn($, container);
    await container.read(backgroundSyncProvider).flush();
    await _waitUntil(
      $,
      () async =>
          (await env.bg.pendingJobs()).contains(TestBackground.newClipsJobId),
      what: 'the new-clips job to be armed',
    );

    await body(env);
  } on Object catch (error, stack) {
    failure = (error, stack);
  }
  await _cleanUp($, env, restoreFolders, failure: failure);
}

/// The end of the test body. Each step runs even when one before it threw
/// (the folders above all), and then the first error is thrown: the test's
/// own [failure] when there is one.
Future<void> _cleanUp(
  PatrolIntegrationTester $,
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

  await step(() => closeShade($));
  // Shooting mode off cancels the job and the new-clips notification (the
  // settings are restored below; the other notifications go with the data).
  await step(() async {
    await env.container
        .read(shootingModeControllerProvider.notifier)
        .setOn(false)
        .timeout(const Duration(seconds: 15));
    await env.container
        .read(backgroundSyncProvider)
        .flush()
        .timeout(const Duration(seconds: 15));
  });
  await step(env.media.cleanUp);
  await step(restoreFolders);
  if (first case (final error, final stack)) {
    Error.throwWithStackTrace(error, stack);
  }
}

/// Turns Shooting mode on from the Reels switch and answers the notification
/// permission dialog that follows (asked once, the first time).
Future<void> _turnShootingOn(
  PatrolIntegrationTester $,
  ProviderContainer container,
) async {
  bool? stored() => container.read(shootingModeControllerProvider).value?.on;
  await waitFor(
    $,
    () => stored() != null,
    what: 'the stored Shooting mode to be read',
  );
  await $(ReelsScreen).$(TtSwitch).tap();
  await allowNotificationsInDialog($);
  await waitFor(
    $,
    () => stored() ?? false,
    what: 'Shooting mode to be stored as on',
  );
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
  }
  await waitFor(
    $,
    () => stored() == on,
    what: 'Shooting mode to be stored as ${on ? 'on' : 'off'}',
  );
}

/// Leaves for Reels and waits until Reels, not To tag, is on screen. Android
/// brings an app back on its last screen, so a flow that then proves a tap
/// "opens To tag" must not start from To tag.
Future<void> _showReels(PatrolIntegrationTester $) async {
  await $(TtNavPill).$('Reels').tap();
  await waitFor(
    $,
    () => $(ReelsScreen).exists && !$(ToTagScreen).exists,
    what: 'Reels, not To tag, on screen before the app goes away',
  );
}

/// After a notification tap (the app was left on Reels, `_showReels`): To
/// tag is on screen instead of Reels, with exactly [count] clips.
Future<void> _expectToTagOpened(
  PatrolIntegrationTester $,
  int count,
  String tapped,
) async {
  await waitFor(
    $,
    () => $(ToTagScreen).exists && !$(ReelsScreen).exists,
    what: 'To tag to open from $tapped',
  );
  await waitFor(
    $,
    () => _tiles.evaluate().length == count,
    what: 'the $count clips as tiles on To tag',
    timeout: const Duration(seconds: 60),
  );
  await pumpFor($, const Duration(seconds: 2));
  expect(find.byType(ToTagScreen), findsOneWidget, reason: 'still on To tag');
  expect(find.byType(ReelsScreen), findsNothing, reason: 'Reels is gone');
  expect(_tiles, findsNWidgets(count), reason: 'exactly the $count clips');
}

/// Waits until exactly [count] clips are waiting in the database.
Future<void> _waitForPending(
  PatrolIntegrationTester $,
  _Env env,
  int count,
  String what,
) => _waitUntil(
  $,
  () async => (await env.pending()).length == count,
  what: what,
  timeout: const Duration(seconds: 120),
);

/// Waits until [done] is true, asking every quarter of a second; [pump] draws
/// the app meanwhile (not wanted while the app is in the background).
///
/// With [heat] (the wait is for the new-clips job, which the system holds
/// while the phone is hot) the wait first fails if the phone is at
/// `thermalModerate` or above, and a timeout names the thermal status.
Future<void> _waitUntil(
  PatrolIntegrationTester $,
  Future<bool> Function() done, {
  required String what,
  Duration timeout = const Duration(seconds: 45),
  bool pump = true,
  TestBackground? heat,
}) async {
  await heat?.requireCool();
  final deadline = DateTime.now().add(timeout);
  while (!await done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what'
        '${await heat?.thermalNote() ?? ''}',
      );
    }
    if (pump) {
      await $.tester.pump(const Duration(milliseconds: 250));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}
