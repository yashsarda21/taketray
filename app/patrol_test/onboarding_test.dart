import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/access_step_screen.dart';
import 'package:taketray/features/onboarding/views/notifications_step_screen.dart';
import 'package:taketray/features/onboarding/views/reels_step_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_tray_art.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/lifecycle.dart';
import 'support/system_dialogs.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// First launch on the S24 (Phase 10A, Task 10, D-143): the welcome, the video
/// access step, the notifications step, the reels step and the Home tip.
///
/// This is the only Patrol file that sees onboarding: every other file pumps
/// the app with `onboardedOverrides` (`support/onboarded.dart`). Here the real
/// onboarding flags are used, so each flow starts by putting them back to "not
/// done" in the app's own database (see [_prepare]), and does not rely on
/// `clearPackageData` having just run. (Android's runtime permissions are the
/// one thing the test cannot reset itself: they are back to "not asked" only
/// because the orchestrator clears the app's data before each test.)
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`). The flows read and write only its own database, and
/// answer Android's permission dialogs by their resource ids (never their
/// text). Nothing on the phone outside the app is read, listed, written or
/// deleted. The test never creates or lists anything in `Movies/`: there are
/// no test videos. It only names the test folder, as the setting
/// `watchedFolders = ['Movies/TakeTray Test']` (a string in the app's own
/// database), before the app starts, so the flows that give it full access
/// (and turn Shooting mode on) cannot make it query another folder. Android's
/// photo picker is not driven (its resource ids are unproven on One UI): the
/// Manual mode flow answers the dialog with "Don't allow". No screenshots.
///
/// **Cleaning up.** Each flow ends (also when it fails) by turning Shooting
/// mode off where it may be on, closing the app, deleting the reels it made
/// (`TakeTray Test *`, and the idea "Food") and resetting the onboarding
/// flags, then putting the watched folders back.
///
/// **Closed midway.** Patrol cannot kill and relaunch its own process, so a
/// restart is simulated: the widget tree is torn down and a fresh
/// `ProviderScope` with a new `TakeTrayApp` is pumped. All the app's state
/// lives in providers, which go with the old scope, and the database file
/// stays, so the new app reads the flags from disk exactly as a relaunched one
/// would. What the simulation cannot show (the splash, the native side's
/// state after a kill) is on the owner's hand-check list
/// (docs/dev-setup.md, "Phase 10A check").
///
/// The words are the app's own (`AppLocalizations`), never typed twice. No
/// test waits for Android's scheduler, and none prints any user data (only
/// fixed step descriptions).
///
/// **"The welcome's final frame".** The whole screen's opacity is no proof: it
/// reaches 1 after 200 ms of a playing intro. The wordmark, headline, text and
/// step dots stay at 0 until 2.2 to 2.5 s into it, so [_welcomeIsFinal] reads
/// the headline's, the text's and the dots' own opacity, and every check of it
/// is made within about 2 s of the welcome appearing (a playing intro still
/// reads false then; flow 1 proves that first).
void main() {
  _flowTest(
    'Fresh phone: Allow all, notifications Allow, two reels, the tip, Got it',
    _freshFullAccess,
  );
  _flowTest(
    "Manual mode: Don't allow, Continue in Manual mode, Not now, Skip for now",
    _manualMode,
  );
  _flowTest(
    'Closed midway: Back to the welcome, then a restart shows its final frame',
    _closedMidway,
  );
  _flowTest(
    'The Home tip: turning Shooting mode on with its switch hides it for good',
    _tipAndSwitch,
    onboarded: true,
    shootingMayBeOn: true,
  );
}

// =============================================================== the flows

/// Flow 1: the whole first launch on a phone that has been given nothing, with
/// every ask answered "yes", ending on Reels with the tip.
Future<void> _freshFullAccess(PatrolIntegrationTester $) async {
  // 1. The welcome: the headline is there from the first frame; the intro is
  // playing (so the final frame is not showing yet) until a tap on the
  // picture skips it to its final frame. The intro is marked as played when
  // it starts, not when it is skipped.
  final reelsBefore = (await _reelNames($, fresh: true)).length;
  final sinceStart = Stopwatch()..start();
  await _startApp($);
  final welcome = $(WelcomeScreen);
  await waitFor($, () => welcome.exists, what: 'the welcome');
  expect(welcome.$(_l10n.welcomeHeadline).exists, isTrue);
  // The negative check: a fresh, un-skipped welcome is not final yet (its
  // headline starts to show 2.35 s into the intro). If the phone was too slow
  // to get here in time, the positive check below proves nothing, so say so.
  if (sinceStart.elapsed < _finalFrameWindow) {
    expect(
      _welcomeIsFinal($),
      isFalse,
      reason: 'a playing intro has not reached its final frame yet',
    );
  } else {
    debugPrint('skipped: the welcome took over 2 s to show');
  }
  await $(WelcomeTrayArt).tap();
  expect(
    _welcomeIsFinal($),
    isTrue,
    reason: 'a tap on the picture skips the intro to its final frame',
  );
  await _eventually(
    $,
    () => _phone($).introPlayed(),
    what: 'the intro to be marked as played (when it started)',
  );
  expect(
    await _phone($).onboardingDone(),
    isFalse,
    reason: 'onboarding is not done on the welcome',
  );

  // 2. Video access: Allow access, Android's dialog, Allow all, All set.
  await welcome.$(_l10n.welcomeGetStarted).tap();
  final access = $(AccessStepScreen);
  await waitFor(
    $,
    () => access.$(_l10n.accessBeforeTitle).exists,
    what: 'the video access step, before access is asked',
  );
  await access.$(_l10n.accessAllow).tap();
  await allowAllInDialog($);
  await waitFor(
    $,
    () => access.$(_l10n.accessAllSetTitle).exists,
    what: 'the All set look after Allow all',
  );
  await access.$(_l10n.onboardingContinue).tap();

  // 3. Notifications: Allow notifications, Android's dialog, Allow.
  final notifications = $(NotificationsStepScreen);
  await _waitForNotificationsStep($);
  await notifications.$(_l10n.notificationsStepAllow).tap();
  expect(
    await allowNotificationsInDialog($),
    isTrue,
    reason: 'Android 13 and later asks for notifications once, on this step',
  );

  // 4. Reels: type a name and press Enter (it joins the list, the field
  // empties), tap an idea, and Create 2 reels.
  final reelsStep = $(ReelsStepScreen);
  await waitFor(
    $,
    () => reelsStep.exists,
    what: 'the reels step after the notifications answer',
  );
  await _typeAndPressEnter($, _reelA);
  await waitFor(
    $,
    () => find.byKey(ReelsStepScreen.rowKey(0)).evaluate().isNotEmpty,
    what: 'the typed name to join the list',
  );
  expect(
    _fieldText($),
    isEmpty,
    reason: 'Enter adds the name and empties the field',
  );
  expect(
    _editable($).widget.focusNode.hasFocus,
    isTrue,
    reason: 'the field keeps the focus for the next name',
  );
  // The keyboard is up now (the field keeps the focus); close it, as a user
  // does before looking at the ideas, so the chip is not under it.
  FocusManager.instance.primaryFocus?.unfocus();
  await $.tester.pump(const Duration(milliseconds: 500));
  await reelsStep.$(TtSuggestionChip).$(_idea).tap();
  await waitFor(
    $,
    () => reelsStep.$(_l10n.reelsStepCreate(2)).exists,
    what: '"${_l10n.reelsStepCreate(2)}" with two names in the list',
  );
  await reelsStep.$(_l10n.reelsStepCreate(2)).tap();

  // 5. Reels shows both reels and the tip.
  final home = $(ReelsScreen);
  await waitFor($, () => home.exists, what: 'Reels after Create');
  await waitFor(
    $,
    () => home.$(TtReelCard).containing(_reelA).exists,
    what: 'the first new reel on Reels',
  );
  expect(home.$(TtReelCard).containing(_idea).exists, isTrue);
  final names = await _reelNames($);
  expect(names, containsAll([_reelA, _idea]));
  expect(
    names.length,
    reelsBefore + 2,
    reason: 'Create makes exactly the two reels, no extra and no duplicate',
  );
  await _eventually(
    $,
    () => _phone($).onboardingDone(),
    what: 'onboarding to be stored as done',
  );
  expect(
    $(ReelsStepScreen).exists,
    isFalse,
    reason: 'the reels step is gone once Reels shows',
  );
  await waitFor(
    $,
    () => home.$(_l10n.shootingTipTitle).exists,
    what: 'the one-time tip under the Shooting mode card',
  );

  // 6. Got it hides the tip for good: the flag is stored, and a restart
  // (a fresh app on the same database) shows Reels with no tip.
  await home.$(_l10n.shootingTipGotIt).tap();
  await waitFor(
    $,
    () => !home.$(_l10n.shootingTipTitle).exists,
    what: 'the tip to go after Got it',
  );
  await _eventually(
    $,
    () => _phone($).homeTipSeen(),
    what: 'the tip to be stored as seen',
  );
  await _restartApp($);
  await waitFor(
    $,
    () => $(ReelsScreen).$(TtReelCard).containing(_reelA).exists,
    what: 'Reels, not the welcome, after a restart',
  );
  expect($(WelcomeScreen).exists, isFalse);
  // The tip waits for the stored Shooting mode and the flags: wait until both
  // have loaded (a positive signal), so its absence below is not just "not
  // read yet".
  await waitFor(
    $,
    () =>
        _container($).read(shootingModeControllerProvider).value != null &&
        _container($).read(onboardingControllerProvider).value != null,
    what: 'the stored Shooting mode and the flags to load after the restart',
  );
  await $.tester.pump();
  expect(
    $(ReelsScreen).$(_l10n.shootingTipTitle).exists,
    isFalse,
    reason: 'a tip that was dismissed stays hidden after a restart',
  );
}

/// Flow 2: every ask answered "no": Don't allow, Continue in Manual mode,
/// Not now, Skip for now; Reels has the Manual mode banner, no new reel, and
/// the tip.
Future<void> _manualMode(PatrolIntegrationTester $) async {
  final reelsBefore = (await _reelNames($, fresh: true)).length;
  await _startApp($);

  // 1. Welcome, then Get started straight away (it works from frame 0).
  final welcome = $(WelcomeScreen);
  await waitFor($, () => welcome.exists, what: 'the welcome');
  await welcome.$(_l10n.welcomeGetStarted).tap();

  // 2. Allow access, then "Don't allow": the denied look; Manual mode goes on.
  final access = $(AccessStepScreen);
  await waitFor(
    $,
    () => access.$(_l10n.accessBeforeTitle).exists,
    what: 'the video access step, before access is asked',
  );
  await access.$(_l10n.accessAllow).tap();
  await tapNativeView($, denyButton);
  await waitFor(
    $,
    () => access.$(_l10n.accessDeniedTitle).exists,
    what: "the denied look after Don't allow",
  );
  expect(
    access.$(_l10n.accessContinueManual).exists,
    isTrue,
    reason: 'Continue in Manual mode is offered when access is refused',
  );
  await access.$(_l10n.accessContinueManual).tap();

  // 3. Notifications: Not now. No Android dialog follows.
  await _waitForNotificationsStep($);
  await $(NotificationsStepScreen).$(_l10n.notificationsStepNotNow).tap();
  final reelsStep = $(ReelsStepScreen);
  await waitFor(
    $,
    () => reelsStep.exists,
    what: 'the reels step after Not now',
  );
  expect(
    await $.platform.mobile.isPermissionDialogVisible(
      timeout: const Duration(seconds: 2),
    ),
    isFalse,
    reason: 'Not now asks Android for nothing',
  );

  // 4. Skip for now: Reels, in Manual mode, with no reel made and the tip.
  await reelsStep.$(_l10n.reelsStepSkip).tap();
  final home = $(ReelsScreen);
  await waitFor($, () => home.exists, what: 'Reels after Skip for now');
  await waitFor(
    $,
    () => home.$(_l10n.accessManualTitle).exists,
    what: 'the Manual mode banner on Reels',
  );
  expect(home.$(_l10n.accessManualAction).exists, isTrue);
  await _eventually(
    $,
    () => _phone($).onboardingDone(),
    what: 'onboarding to be stored as done',
  );
  expect(
    (await _reelNames($)).length,
    reelsBefore,
    reason: 'Skip for now makes no reel',
  );
  await waitFor(
    $,
    () => home.$(_l10n.shootingTipTitle).exists,
    what: 'the one-time tip, also in Manual mode',
  );
}

/// Flow 3: closed midway. Get started, Back to the welcome (its final frame,
/// no second intro), the app goes to the background and comes back, then a
/// restart (a fresh app on the same database) shows the welcome's final frame
/// again, never Reels, and Get started still works.
Future<void> _closedMidway(PatrolIntegrationTester $) async {
  await _startApp($);
  final welcome = $(WelcomeScreen);
  await waitFor($, () => welcome.exists, what: 'the welcome');

  // 1. Get started at once (no skip first: the intro is still playing and
  // stops under the step), then Android's Back.
  await welcome.$(_l10n.welcomeGetStarted).tap();
  final access = $(AccessStepScreen);
  await waitFor(
    $,
    () => access.$(_l10n.accessBeforeTitle).exists,
    what: 'the video access step',
  );
  await _waitForRouteToSettle($, AccessStepScreen);
  // Back on a pushed step pops it (Back on the welcome itself would finish
  // the activity and end the test run, so it is never pressed there).
  await $.platform.android.pressBack();
  await waitFor(
    $,
    () => welcome.exists && !access.exists,
    what: 'the welcome again after Back',
  );
  expect(
    _welcomeIsFinal($),
    isTrue,
    reason:
        'coming back to the welcome shows its final frame (the intro '
        'stopped under the step; it could not have reached it by itself)',
  );
  await _eventually(
    $,
    () => _phone($).introPlayed(),
    what: 'the intro to be marked as played',
  );
  expect(await _phone($).onboardingDone(), isFalse);

  // 2. Away and back (the process lives on).
  await $.platform.mobile.pressHome();
  await $.platform.mobile.openApp();
  await waitFor($, () => welcome.exists, what: 'the welcome after reopening');

  // 3. Restart: the welcome, final frame at once (the flag says the intro
  // played), not Reels, not a step.
  await _restartApp($);
  await waitFor($, () => welcome.exists, what: 'the welcome after a restart');
  expect($(ReelsScreen).exists, isFalse);
  expect($(AccessStepScreen).exists, isFalse);
  // At once: a replayed intro would read false for the first 2.35 s.
  expect(
    _welcomeIsFinal($),
    isTrue,
    reason: 'a restart shows the welcome at its final frame, no intro',
  );
  expect(welcome.$(_l10n.welcomeHeadline).exists, isTrue);

  // 4. Get started still works.
  await welcome.$(_l10n.welcomeGetStarted).tap();
  await waitFor(
    $,
    () => access.$(_l10n.accessBeforeTitle).exists,
    what: 'the video access step after the restart',
  );
}

/// Flow 4: on an onboarded phone that has not seen the tip, turning Shooting
/// mode on with its switch turns it on and hides the tip, for good (even after
/// Shooting mode is turned off again). Full access is given the way a user
/// does it, from the To tag banner, so the switch asks only for
/// notifications.
Future<void> _tipAndSwitch(PatrolIntegrationTester $) async {
  await _startApp($);
  final home = $(ReelsScreen);
  await waitFor($, () => home.exists, what: 'Reels (onboarding is done)');
  expect($(WelcomeScreen).exists, isFalse);
  await waitFor(
    $,
    () => home.$(_l10n.shootingTipTitle).exists,
    what: 'the tip on an onboarded phone that has not seen it',
  );
  final container = _container($);
  bool? stored() => container.read(shootingModeControllerProvider).value?.on;

  // 1. Full access, from the To tag banner (as in background_test).
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
  await $(TtNavPill).$(_l10n.navReels).tap();
  await waitFor(
    $,
    () => home.exists && home.$(_l10n.shootingTipTitle).exists,
    what: 'Reels with the tip still showing',
  );

  // 2. The switch: Shooting mode turns on (its first question is the
  // notification permission), and the tip is gone and stored as seen.
  await waitFor(
    $,
    () => stored() != null,
    what: 'the stored Shooting mode to be read',
  );
  expect(stored(), isFalse);
  await home.$(TtSwitch).tap();
  expect(
    await allowNotificationsInDialog($),
    isTrue,
    reason: 'the first turn-on asks for notifications once (Android 13+)',
  );
  await waitFor(
    $,
    () => stored() ?? false,
    what: 'Shooting mode to be stored as on',
  );
  await waitFor(
    $,
    () => !home.$(_l10n.shootingTipTitle).exists,
    what: 'the tip to go when Shooting mode turns on',
  );
  await _eventually(
    $,
    () => _phone($).homeTipSeen(),
    what: 'the tip to be stored as seen by the switch',
  );

  // 3. Off again with the switch: the tip does not come back.
  await home.$(TtSwitch).tap();
  await waitFor(
    $,
    () => stored() == false,
    what: 'Shooting mode to be stored as off',
  );
  await pumpFor($, const Duration(seconds: 1));
  expect(
    home.$(_l10n.shootingTipTitle).exists,
    isFalse,
    reason: 'the tip does not come back when Shooting mode goes off',
  );
}

// ============================================================ the test frame

/// A test whose app starts from [_prepare]d, not-onboarded data (or, with
/// [onboarded], from data where onboarding is done and the tip not yet seen),
/// and that always runs [_tearDown], also when [body] fails.
void _flowTest(
  String description,
  Future<void> Function(PatrolIntegrationTester $) body, {
  bool onboarded = false,
  bool shootingMayBeOn = false,
}) {
  patrolTest(description, config: _liveConfig, ($) async {
    final prep = _Prep();
    (Object, StackTrace)? failure;
    try {
      // Inside the try: a throw while preparing (a database that will not
      // open, a timeout) still reaches the tear-down, which puts the watched
      // folders back and clears what was made.
      await _prepare(prep, onboarded: onboarded);
      await body($);
    } on Object catch (error, stack) {
      failure = (error, stack);
    }
    await _tearDown(
      $,
      prep,
      shootingMayBeOn: shootingMayBeOn,
      failure: failure,
    );
  });
}

/// What [_prepare] changed, for [_tearDown] to put back. [settingsBefore] is
/// set as soon as the settings were read, before anything is saved, so it is
/// null only when nothing was changed yet.
class _Prep {
  AppSettings? settingsBefore;
}

/// The rows of the `settings` table that say what the app remembers about the
/// first launch (the three onboarding flags), about asking, and about the
/// media it has seen (the volume versions, the re-match windows) and a copy it
/// planned: all put back to "never" so the flow starts as a fresh install
/// would, with nothing left over from an earlier run on this phone.
const List<String> _firstLaunchKeys = [
  PhoneStateRepository.onboardingDoneKey,
  PhoneStateRepository.introPlayedKey,
  PhoneStateRepository.homeTipSeenKey,
  PhoneStateRepository.notificationsAskedKey,
  PhoneStateRepository.mediaAccessWasFullKey,
  PhoneStateRepository.folderTipSeenKey,
  PhoneStateRepository.shootingModeKey,
  PhoneStateRepository.volumeVersionsKey,
  PhoneStateRepository.rematchWindowsKey,
  PhoneStateRepository.copyJobPlanKey,
];

/// Puts the app's own database in the state a flow starts from, before any
/// app is pumped: the first-launch rows deleted (and, with [onboarded],
/// onboarding and the intro marked done, the tip not seen), the reels of an
/// earlier run deleted, and only the test folder name watched. It uses a
/// container of its own and closes it, so the app opens the database fresh.
/// What it must put back goes into [prep] before it is changed.
Future<void> _prepare(_Prep prep, {required bool onboarded}) =>
    _withDatabase((c) async {
      final db = c.read(appDatabaseProvider);
      final settings = c.read(settingsRepositoryProvider);
      prep.settingsBefore = await settings.load();
      await _resetFlags(db);
      await _deleteTestReels(db, c.read(reelsRepositoryProvider));
      await settings.save(const AppSettings(watchedFolders: [testFolder]));
      if (onboarded) {
        final phone = c.read(phoneStateRepositoryProvider);
        await phone.markOnboardingDone();
        await phone.markIntroPlayed();
      }
    });

/// The end of a flow. Each step runs even when one before it threw, and then
/// the first error is thrown: the flow's own [failure] when there is one.
Future<void> _tearDown(
  PatrolIntegrationTester $,
  _Prep prep, {
  required bool shootingMayBeOn,
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

  // Shooting mode off (it cancels the background job and its notification),
  // while the app is still up.
  if (shootingMayBeOn) {
    await step(() async {
      if (find.byType(TakeTrayApp).evaluate().isEmpty) return;
      final container = _container($);
      await container
          .read(shootingModeControllerProvider.notifier)
          .setOn(false)
          .timeout(const Duration(seconds: 15));
      await container
          .read(backgroundSyncProvider)
          .flush()
          .timeout(const Duration(seconds: 15));
    });
  }
  // Close the app, then clean the database with a container of its own.
  await step(() async {
    await $.tester.pumpWidget(const SizedBox.shrink());
    await $.tester.pump(const Duration(milliseconds: 500));
  });
  await step(
    () => _withDatabase((c) async {
      final db = c.read(appDatabaseProvider);
      await _deleteTestReels(db, c.read(reelsRepositoryProvider));
      await _resetFlags(db);
      final before = prep.settingsBefore;
      if (before != null) {
        await c.read(settingsRepositoryProvider).save(before);
      }
    }),
  );
  if (first case (final error, final stack)) {
    Error.throwWithStackTrace(error, stack);
  }
}

/// Runs [run] with a container that is closed afterwards (the database is
/// closed first, then the container disposed, as `database_test.dart` does).
Future<T> _withDatabase<T>(Future<T> Function(ProviderContainer c) run) async {
  final container = ProviderContainer();
  try {
    return await run(container).timeout(const Duration(seconds: 30));
  } finally {
    await container.read(appDatabaseProvider).close();
    container.dispose();
  }
}

Future<void> _resetFlags(AppDatabase db) =>
    (db.delete(db.settings)..where((s) => s.key.isIn(_firstLaunchKeys))).go();

/// Deletes the reels this file makes: `TakeTray Test *` and the idea "Food".
/// The database is TakeTray Dev's own (never the real app's).
Future<void> _deleteTestReels(AppDatabase db, ReelsRepository reels) async {
  // A one-off read, not a stream (a stream still being cancelled when the
  // database closes fails the test with a ConcurrentModificationError).
  final all = await db.select(db.reels).get();
  for (final reel in all) {
    if (reel.name.startsWith(_reelPrefix) || reel.name == _idea) {
      await reels.delete(reel.id);
    }
  }
}

// ================================================================== helpers

const String _reelPrefix = 'TakeTray Test ';
const String _reelA = '${_reelPrefix}A';

/// The idea chip the flow taps; it makes a reel with this name.
const String _idea = 'Food';

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The welcome's intro and a snack count down: never wait for the screen to
// settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

/// Pumps a fresh app: a new `ProviderScope` (a key of its own, so Flutter
/// never reuses the old container) with no overrides, so the real onboarding
/// flags decide where it opens.
///
/// First the binding gets back the lifecycle state Patrol's test frame wipes
/// ([restoreResumedLifecycle]): without it the app never tells Android it
/// handles Back, and Back on a pushed step finishes the activity (Closed
/// midway).
Future<void> _startApp(PatrolIntegrationTester $) async {
  await restoreResumedLifecycle($);
  expect(
    WidgetsBinding.instance.lifecycleState,
    AppLifecycleState.resumed,
    reason: 'the app is in front, as a real launch reports it',
  );
  await $.pumpWidget(
    ProviderScope(key: UniqueKey(), child: const TakeTrayApp()),
  );
}

/// A restart: the widget tree goes, and a fresh app reads the database again.
Future<void> _restartApp(PatrolIntegrationTester $) async {
  await $.pumpWidget(const SizedBox.shrink());
  await $.tester.pump(const Duration(milliseconds: 500));
  await _startApp($);
}

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(TakeTrayApp)));

PhoneStateRepository _phone(PatrolIntegrationTester $) =>
    _container($).read(phoneStateRepositoryProvider);

/// The names of the reels in the database now. A one-off read, not a stream.
/// With [fresh], through a container of its own (before the app is pumped).
Future<List<String>> _reelNames(
  PatrolIntegrationTester $, {
  bool fresh = false,
}) {
  Future<List<String>> read(AppDatabase db) async => [
    for (final reel in await db.select(db.reels).get()) reel.name,
  ];
  if (fresh) return _withDatabase((c) => read(c.read(appDatabaseProvider)));
  return read(_container($).read(appDatabaseProvider));
}

/// How long after the welcome appears a playing intro still reads "not final":
/// the headline starts to show at 2.35 s and the text and dots at 2.5 s.
const Duration _finalFrameWindow = Duration(seconds: 2);

/// Whether the welcome shows its final frame: the headline, the text and the
/// step dots (the last things the intro shows, from 2.35 and 2.5 s) are all at
/// opacity 1. The whole screen's own opacity is not used: it is 1 after 200 ms
/// of a playing intro. Each is read from its nearest [Opacity].
bool _welcomeIsFinal(PatrolIntegrationTester $) => [
  WelcomeScreen.headlineKey,
  WelcomeScreen.textKey,
  WelcomeScreen.dotsKey,
].every((key) => _nearestOpacity($, key) == 1);

double _nearestOpacity(PatrolIntegrationTester $, Key key) {
  double? opacity;
  $.tester.element(find.byKey(key)).visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Opacity) {
      opacity = widget.opacity;
      return false;
    }
    return true;
  });
  return opacity ?? (throw TestFailure('No Opacity above $key'));
}

/// Waits until the pushed route of the screen [type] has finished its
/// transition, so a Back pressed next pops a settled route.
Future<void> _waitForRouteToSettle(PatrolIntegrationTester $, Type type) async {
  final route = ModalRoute.of($.tester.element(find.byType(type)))!;
  await waitFor(
    $,
    () => route.animation == null || route.animation!.isCompleted,
    what: 'the pushed step to finish sliding in',
  );
}

/// Waits for the notifications step. It shows on Android 13 and later with the
/// permission not given; on other phones the reels step opens in its place,
/// which fails here with that reason (the S24 asks).
Future<void> _waitForNotificationsStep(PatrolIntegrationTester $) async {
  await waitFor(
    $,
    () => $(NotificationsStepScreen).exists || $(ReelsStepScreen).exists,
    what: 'the notifications step',
  );
  expect(
    $(NotificationsStepScreen).exists,
    isTrue,
    reason:
        'an Android 13+ phone that has not been asked shows the '
        'notifications step',
  );
  await waitFor(
    $,
    () => $(NotificationsStepScreen).$(_l10n.notificationsStepTitle).exists,
    what: "the notifications step's title",
  );
}

/// The text field of the reels step.
Finder get _field => find.descendant(
  of: find.byType(ReelsStepScreen),
  matching: find.byType(TextField),
);

String _fieldText(PatrolIntegrationTester $) =>
    $.tester.widget<TextField>(_field.first).controller!.text;

/// Types [text] in the reels step's field and presses the keyboard's Enter
/// ("done"), which adds the name.
///
/// The field must keep the focus: Patrol's `enterText` by default closes the
/// input connection and unfocuses the field when it is done, and an Enter sent
/// then reaches no field (Flutter drops an input action with no connection).
/// With `hideKeyboard: false` the field stays focused with the phone's real
/// input connection, and the Enter (`TextInputAction.done`, the message the
/// keyboard sends; Patrol's binding has no fake keyboard, and a debug build
/// takes the test's client id -1 as the current connection's) reaches it.
Future<void> _typeAndPressEnter(PatrolIntegrationTester $, String text) async {
  await $(_field.first).enterText(text, hideKeyboard: false);
  expect(
    _editable($).widget.focusNode.hasFocus,
    isTrue,
    reason: 'the field keeps the focus, so Enter reaches it',
  );
  await $.tester.testTextInput.receiveAction(TextInputAction.done);
  await $.tester.pump(const Duration(milliseconds: 250));
}

/// The reels step field's [EditableText].
EditableTextState _editable(PatrolIntegrationTester $) =>
    $.tester.state<EditableTextState>(
      find.descendant(of: _field.first, matching: find.byType(EditableText)),
    );

/// Waits until [check] (an async read of the app's database) is true.
Future<void> _eventually(
  PatrolIntegrationTester $,
  Future<bool> Function() check, {
  required String what,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await check()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what',
      );
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
  debugPrint('ok: $what');
}
