import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/backup_screen.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/features/settings/views/watched_folders_screen.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/files_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/onboarded.dart';
import 'support/patrol_files_bridge.dart';
import 'support/share_sheet.dart';
import 'support/system_dialogs.dart';
import 'support/test_background.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// Settings on the S24 (Phase 10B, Task 9, D-152): the switches and the
/// reminder time, what the switches do to the background, a watched folder,
/// Export and import, and Send error log.
///
/// Every flow pumps the app onboarded (`onboardedOverrides`), and each starts
/// by putting the settings it touches in a known state and ends (also when it
/// fails) by putting them back, so no flow depends on another or on the
/// order. The words are the app's own (`AppLocalizations`), never typed
/// twice.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`). The flows read and write its own database, its own
/// cache and the test videos in `Movies/TakeTray Test/` (through the debug
/// channel, D-77), and answer Android's permission dialogs by their resource
/// ids. Nothing else on the phone is read, listed, written or deleted, no
/// screenshot is taken, and no name or path is printed.
///
/// - **Android's folder picker and document picker are never opened**
///   (ruling R2). `filesBridgeProvider` is overridden with
///   `PatrolFilesBridge` (`support/patrol_files_bridge.dart`): its folder
///   answer is `Movies/TakeTray Test`, and "saved" documents are written into
///   the app's own cache and read back from there. The real pickers and
///   where an export lands are on the owner's hand-check list
///   (`docs/dev-setup.md`, "Phase 10B check").
/// - **Send error log uses the real bridge** (flow 4): the share sheet opens
///   (found by Android's chooser resource ids, never by text), then Back
///   closes it. No app is chosen, so nothing is sent.
/// - **No flow waits for Android's scheduler.** The background is reached
///   through the debug hooks (`app.taketray/test_background`): the receiver
///   runs now, and the app's own list of notifications and jobs says what it
///   did.
///
/// **Flows** (each a `patrolTest`):
/// 1. Switches: the evening reminder off and on, its time set to 07:30
///    through Flutter's time picker (stored as 450), a cancelled picker, the
///    still-shooting and copies switches off and on, one switch never
///    undoing another, and the saved values shown again after a restart.
/// 1b. The switches reach the background: the evening reminder and "Remind
///    me to turn it off" off stop their notification, on brings it back (the
///    copies reminder needs an editing session: hand check).
/// 2. Watched folder: Add a folder (a fake pick), no duplicate, a cancelled
///    pick and an unsupported folder change nothing, the folder off and on,
///    Shooting mode on, a new test video reaches To tag, and a video that
///    arrives while the folder is off does not.
/// 3. Export then import: a cancelled export saves nothing, export, a
///    cancelled import changes nothing, import brings back the reel and the
///    settings, "X of Y clips found", and onboarding does not come back.
/// 4. Send error log: the share sheet opens, Back, nothing is chosen.
///
/// **Closed midway.** As in the other files, a restart is simulated by a
/// fresh `ProviderScope` on the same database.
void main() {
  _flowTest('1. Switches and the reminder time', _switches);
  _flowTest(
    '1b. The switches reach the background',
    _background,
    media: true,
    shootingMayBeOn: true,
  );
  _flowTest(
    '2. Watched folder: add, switch, Shooting mode finds a new video',
    _watchedFolder,
    start: const AppSettings(watchedFolders: []),
    media: true,
    shootingMayBeOn: true,
  );
  _flowTest(
    '3. Export then import',
    _exportImport,
    onboardingInDatabase: true,
    resetLastExport: true,
  );
  _flowTest('4. Send error log opens the share sheet', _sendErrorLog);
}

// =============================================================== the flows

/// What every flow but the folder one starts from: the test folder watched,
/// everything else at its default (evening on at 21:00, both other reminders
/// on).
const AppSettings _defaults = AppSettings(watchedFolders: [testFolder]);

/// Flow 1: every switch of Settings and the reminder time.
Future<void> _switches(_Env env) async {
  final $ = env.$;
  var expected = _defaults;
  await _openSettings($);
  final evening = _l10n.settingsEveningTitle;
  final reminderTime = _l10n.settingsReminderTimeTitle;
  expect(
    _row($, reminderTime).exists,
    isTrue,
    reason: 'on: the time row shows',
  );

  // 1. The evening reminder off: stored, the time row goes. On: both back.
  await _switchOf($, evening).tap();
  expected = expected.copyWith(eveningReminderEnabled: false);
  await _expectStored(env, expected, 'the evening reminder stored as off');
  await waitFor(
    $,
    () => !_isOn($, evening) && !_row($, reminderTime).exists,
    what: 'the switch off and the Reminder time row gone',
  );
  await _switchOf($, evening).tap();
  expected = expected.copyWith(eveningReminderEnabled: true);
  await _expectStored(env, expected, 'the evening reminder stored as on');
  await waitFor(
    $,
    () => _isOn($, evening) && _row($, reminderTime).exists,
    what: 'the switch on and the Reminder time row back',
  );

  // 2. A cancelled picker changes nothing; 07:30 is stored as 450 and shown.
  await _openTimePicker($, reminderTime);
  await _cancelTimePicker($);
  await pumpFor($, const Duration(seconds: 1));
  await _expectStored(env, expected, 'the time unchanged after Cancel');
  await _openTimePicker($, reminderTime);
  await _pickTime($, hour: 7, minute: 30);
  expected = expected.copyWith(eveningReminderMinutes: 450);
  await _expectStored(env, expected, 'the reminder time stored as 450');
  final shown = _timeText($, 450);
  await waitFor(
    $,
    () => $(SettingsScreen).$(shown).exists,
    what: 'the Reminder time row to show the new time',
  );
  expect(
    (await _stored(env)).eveningReminderMinutes,
    450,
    reason: '07:30 is 7 * 60 + 30 minutes after midnight',
  );

  // 3. "Remind me to turn it off": off and on. The others stay as they were.
  final still = _l10n.settingsStillTitle;
  await _switchOf($, still).tap();
  expected = expected.copyWith(stillReminderEnabled: false);
  await _expectStored(env, expected, 'the still reminder stored as off');
  await waitFor($, () => !_isOn($, still), what: 'the still switch off');
  await _switchOf($, still).tap();
  expected = expected.copyWith(stillReminderEnabled: true);
  await _expectStored(env, expected, 'the still reminder stored as on');
  await waitFor($, () => _isOn($, still), what: 'the still switch on');

  // 4. "VN copies reminder": off and on.
  final copies = _l10n.settingsCopiesReminderTitle;
  await _switchOf($, copies).tap();
  expected = expected.copyWith(copiesReminderEnabled: false);
  await _expectStored(env, expected, 'the copies reminder stored as off');
  await waitFor($, () => !_isOn($, copies), what: 'the copies switch off');
  await _switchOf($, copies).tap();
  expected = expected.copyWith(copiesReminderEnabled: true);
  await _expectStored(env, expected, 'the copies reminder stored as on');
  await waitFor($, () => _isOn($, copies), what: 'the copies switch on');

  // 5. Leave the two that can differ off, then restart: the screen shows what
  // is stored (07:30 proves the settings were read: the default is 21:00).
  await _switchOf($, still).tap();
  await _switchOf($, copies).tap();
  expected = expected.copyWith(
    stillReminderEnabled: false,
    copiesReminderEnabled: false,
  );
  await _expectStored(env, expected, 'both reminders stored as off');
  await _restart(env);
  await _openSettings($);
  await waitFor(
    $,
    () => $(SettingsScreen).$(_timeText($, 450)).exists,
    what: 'the stored 07:30 after a restart',
  );
  expect(_isOn($, evening), isTrue);
  expect(_isOn($, still), isFalse, reason: 'stored off, shown off');
  expect(_isOn($, copies), isFalse, reason: 'stored off, shown off');
  expect(await _stored(env), expected);
}

/// Flow 1b: the switches reach the background. Shooting mode is on and a clip
/// shot today waits in To tag. Each reminder is fired through its own
/// receiver (the debug hook); the app's own list of its notifications says
/// what it did. Turning a switch off stops the notification without the app
/// being opened again, turning "Remind me to turn it off" back on brings it.
///
/// The copies reminder needs an editing session with copies: hand check.
Future<void> _background(_Env env) async {
  final $ = env.$;
  final bg = TestBackground();
  await _ensureFullAccess(env);
  await _showTab($, _l10n.navReels);
  await _setShootingMode(env, on: true);
  await _flush(env);
  await _waitUntil(
    $,
    () async => (await bg.pendingJobs()).contains(TestBackground.newClipsJobId),
    what: 'the new-clips job to be armed by Shooting mode',
  );

  // 1. One clip shot today waits in To tag (so the evening reminder has one).
  final video = await env.media!.insert();
  await _waitForClip(env, video, what: 'the test video in To tag');
  await _flush(env);
  await _showTab($, _l10n.navReels);

  // 2. "Remind me to turn it off" off: Still shooting? is not posted.
  await _openSettings($);
  final still = _l10n.settingsStillTitle;
  await _switchOf($, still).tap();
  await _expectStored(
    env,
    _defaults.copyWith(stillReminderEnabled: false),
    'the still reminder stored as off',
  );
  await _flush(env);
  await bg.fireStill();
  await _expectNever(
    $,
    () async => (await bg.activeNotifications()).contains(
      TestBackground.stillShootingId,
    ),
    const Duration(seconds: 4),
    'Still shooting? was posted with its switch off',
  );

  // 3. On again: the same receiver posts it (so the 4 s above were not a dead
  // hook).
  await _switchOf($, still).tap();
  await _expectStored(env, _defaults, 'the still reminder stored as on');
  await _flush(env);
  await bg.fireStill();
  await _waitUntil(
    $,
    () async => (await bg.activeNotifications()).contains(
      TestBackground.stillShootingId,
    ),
    what: 'Still shooting? to be posted with its switch on',
    timeout: const Duration(seconds: 30),
  );

  // 4. The evening reminder on: today's clip is counted and it is posted.
  // (Once per evening: a second run the same day on this data needs the
  // app's data cleared first, as after every Patrol run.)
  await bg.fireEvening();
  await _waitUntil(
    $,
    () async =>
        (await bg.activeNotifications()).contains(TestBackground.eveningId),
    what: 'the evening reminder to be posted with its switch on',
    timeout: const Duration(seconds: 30),
  );

  // 5. The evening reminder off: the one in the shade goes, without the app
  // being opened, and the receiver posts nothing more.
  final evening = _l10n.settingsEveningTitle;
  await _switchOf($, evening).tap();
  await _expectStored(
    env,
    _defaults.copyWith(eveningReminderEnabled: false),
    'the evening reminder stored as off',
  );
  await _flush(env);
  await _waitUntil(
    $,
    () async =>
        !(await bg.activeNotifications()).contains(TestBackground.eveningId),
    what: 'the evening reminder to go when its switch is off',
    timeout: const Duration(seconds: 30),
  );
  await bg.fireEvening();
  await _expectNever(
    $,
    () async =>
        (await bg.activeNotifications()).contains(TestBackground.eveningId),
    const Duration(seconds: 4),
    'the evening reminder was posted with its switch off',
  );
}

/// Flow 2: a watched folder, from "Add a folder" to a new video in To tag.
Future<void> _watchedFolder(_Env env) async {
  final $ = env.$;
  final folders = $(WatchedFoldersScreen);
  final row = find.byKey(const ValueKey('watched-row:$testFolder'));

  // 0. A video is in the test folder before anything is watched, so the
  // folder is on the phone's list (and keeps its row when it is turned off),
  // and it is there before Shooting mode goes on: it must never be pulled in.
  final before = await env.media!.insert();
  await _openSettings($);

  // 1. Nothing is watched: Settings says "None", the screen says nothing is
  // found. (A phone that already gave full access lists its folders here, by
  // name on the screen: the test reads none of them.)
  await waitFor(
    $,
    () =>
        _row($, _l10n.settingsWatchedTitle).$(_l10n.settingsWatchedNone).exists,
    what: 'the Watched folders row to say None',
  );
  await _row($, _l10n.settingsWatchedTitle).tap();
  await waitFor(
    $,
    () => folders.$(_l10n.watchedAdd).exists,
    what: 'the Watched folders list (its Add a folder row)',
  );
  expect(
    folders.$(_l10n.watchedNoneWatched).exists,
    isTrue,
    reason: 'with no folder on, the user is told nothing will be found',
  );

  // 2. Without full access the screen asks for it: Allow all, Android's
  // dialog, and the banner goes. (Skipped when an earlier flow gave it.)
  if (folders.$(_l10n.watchedAccessBanner).exists) {
    await folders.$(_l10n.settingsVideoAllowAll).tap();
    await allowAllInDialog($);
    await waitFor(
      $,
      () => !folders.$(_l10n.watchedAccessBanner).exists,
      what: 'the access banner to go after Allow all',
    );
  }

  // 3. A cancelled pick, an unsupported folder and the TakeTray copies
  // folder change nothing and say so; a failure says it too.
  env.files.answerFolder(null);
  await _tapScrolled($, folders.$(_l10n.watchedAdd));
  await pumpFor($, const Duration(seconds: 1));
  expect(await _stored(env), const AppSettings(watchedFolders: []));
  expect(
    $(_l10n.watchedAddFailed).exists,
    isFalse,
    reason: 'a cancelled picker is not an error',
  );
  env.files.answerFolder(
    const FileBridgeException(FilesProblem.unsupportedFolder),
  );
  await _tapScrolled($, folders.$(_l10n.watchedAdd));
  await waitFor(
    $,
    () => $(_l10n.watchedUnsupported).exists,
    what: 'the unsupported folder message',
  );
  env.files.answerFolder('Movies/TakeTray');
  await _tapScrolled($, folders.$(_l10n.watchedAdd));
  await waitFor(
    $,
    () => $(_l10n.watchedOwnFolder).exists,
    what: "the message that TakeTray's own copies cannot be watched",
  );
  expect(await _stored(env), const AppSettings(watchedFolders: []));

  // 4. Add a folder: the fake picks Movies/TakeTray Test. It is watched and
  // on; the "nothing watched" bar goes; picking it again adds no second one.
  await _tapScrolled($, folders.$(_l10n.watchedAdd));
  await _expectStored(
    env,
    const AppSettings(watchedFolders: [testFolder]),
    'the picked folder stored as watched',
  );
  await waitFor(
    $,
    () => row.evaluate().isNotEmpty && _folderOn($, row),
    what: 'the folder row with its switch on',
  );
  await waitFor(
    $,
    () => !folders.$(_l10n.watchedNoneWatched).exists,
    what: 'the "nothing watched" bar to go',
  );
  await _tapScrolled($, folders.$(_l10n.watchedAdd));
  await pumpFor($, const Duration(seconds: 1));
  expect((await _stored(env)).watchedFolders, [
    testFolder,
  ], reason: 'the same folder is not added twice');
  expect(
    env.files.calls.where((c) => c == 'pickFolder').length,
    5,
    reason: 'every Add a folder asked the picker once',
  );

  // 5. The folder's own switch: off then on.
  await _tapScrolled($, $(row).$(TtSwitch));
  await _expectStored(
    env,
    const AppSettings(watchedFolders: []),
    'the folder stored as not watched',
  );
  await waitFor(
    $,
    () => folders.$(_l10n.watchedNoneWatched).exists && !_folderOn($, row),
    what: 'the switch off and the "nothing watched" bar back',
  );
  await _tapScrolled($, $(row).$(TtSwitch));
  await _expectStored(
    env,
    const AppSettings(watchedFolders: [testFolder]),
    'the folder stored as watched again',
  );

  // 6. Back to Settings, which names the folder.
  await _tapBack($);
  await waitFor(
    $,
    () => _row($, _l10n.settingsWatchedTitle).$(_folderName).exists,
    what: 'the Watched folders row to name the folder',
  );

  // 7. Shooting mode on: a new test video reaches To tag, and the one that
  // was in the folder already does not (only videos that arrive after).
  await _showTab($, _l10n.navReels);
  await _setShootingMode(env, on: true);
  final first = await env.media!.insert();
  await _waitForClip(env, first, what: 'the new video in To tag');
  expect(
    await _pendingIds(env),
    isNot(contains(before.mediaStoreId)),
    reason: 'a video that was there before Shooting mode is not pulled in',
  );

  // 8. The folder off while Shooting mode is on: a video that arrives now
  // does not reach To tag. (A negative: it proves something because the first
  // video did arrive the same way.)
  await _showTab($, _l10n.navSettings);
  await _row($, _l10n.settingsWatchedTitle).tap();
  await waitFor($, () => row.evaluate().isNotEmpty, what: 'the folder row');
  await _tapScrolled($, $(row).$(TtSwitch));
  await _expectStored(
    env,
    const AppSettings(watchedFolders: []),
    'the folder stored as not watched',
  );
  await _flush(env);
  final second = await env.media!.insert();
  await _expectNever(
    $,
    () async => (await _pendingIds(env)).contains(second.mediaStoreId),
    const Duration(seconds: 6),
    'a video that arrived while its folder was off reached To tag',
  );
}

/// Flow 3: Export and import, with the fake document picker (the app's own
/// cache). Reels only: the test makes no clip.
Future<void> _exportImport(_Env env) async {
  final $ = env.$;
  final container = env.container;
  final reels = container.read(reelsRepositoryProvider);
  final phone = container.read(phoneStateRepositoryProvider);
  final settings = container.read(settingsRepositoryProvider);
  final backupScreen = $(BackupScreen);

  // 1. Something to back up: a reel and settings that are not the defaults.
  final reel = await reels.create(_reelBackup);
  const exported = AppSettings(
    watchedFolders: [testFolder],
    eveningReminderMinutes: 450,
    stillReminderEnabled: false,
    copiesReminderEnabled: false,
  );
  await settings.save(exported);
  final total =
      (await container.read(clipsRepositoryProvider).allClipIds()).length;
  expect(await phone.lastExport(), isNull, reason: 'the flow starts clean');

  // 2. Settings, then Export and import: "No backup yet".
  await _openSettings($);
  await waitFor(
    $,
    () => _row($, _l10n.settingsBackupTitle).$(_l10n.settingsBackupNone).exists,
    what: 'the Export and import row to say "No backup yet"',
  );
  final backupRow = _row($, _l10n.settingsBackupTitle);
  await backupRow.scrollTo(view: _settingsScroll());
  await backupRow.tap();
  await waitFor($, () => backupScreen.exists, what: 'the backup screen');

  // 3. A cancelled export saves nothing and records no date.
  env.files.cancelNextSave();
  await backupScreen.$(_l10n.backupExportButton).tap();
  await waitFor(
    $,
    () => env.files.calls.contains('saveDocument'),
    what: 'the document picker to be asked',
  );
  await pumpFor($, const Duration(seconds: 1));
  expect(env.files.saves, 0, reason: 'a cancelled picker writes nothing');
  expect($(_l10n.backupSaved).exists, isFalse);
  expect(await phone.lastExport(), isNull, reason: 'no date for a cancel');

  // 4. Export: "Backup saved", the file holds the reel and the settings, the
  // date is recorded.
  await backupScreen.$(_l10n.backupExportButton).tap();
  await waitFor(
    $,
    () => $(_l10n.backupSaved).exists,
    what: '"Backup saved" after the export',
  );
  expect(env.files.saves, 1);
  final text = (await env.files.lastSavedText())!;
  expect(
    jsonDecode(text),
    isA<Map<String, dynamic>>(),
    reason: 'a backup is one JSON object',
  );
  expect(text, contains(_reelBackup), reason: 'the reel is in the backup');
  final recorded = await phone.lastExport();
  expect(recorded, isNotNull, reason: 'the export date is recorded');
  await waitFor(
    $,
    () => !backupScreen.$(_l10n.settingsBackupNone).exists,
    what: 'the screen to show the date instead of "No backup yet"',
  );

  // 5. Change things, then a cancelled import: nothing changes.
  await reels.delete(reel.id);
  const changed = AppSettings(
    watchedFolders: [],
    eveningReminderEnabled: false,
    eveningReminderMinutes: 0,
  );
  await settings.save(changed);
  env.files.cancelNextOpen();
  await backupScreen.$(_l10n.backupImportButton).tap();
  await waitFor(
    $,
    () => $(_l10n.backupConfirmTitle).exists,
    what: 'the question before an import',
  );
  await $(_l10n.backupConfirmImport).tap();
  await waitFor(
    $,
    () => env.files.calls.contains('openDocument'),
    what: 'the document picker to be asked for the import',
  );
  await pumpFor($, const Duration(seconds: 1));
  expect($(_l10n.backupImportedTitle).exists, isFalse);
  expect(await _reelNames(env), isNot(contains(_reelBackup)));
  expect(
    await _stored(env),
    changed,
    reason: 'a cancelled import changes nothing',
  );

  // 6. The import: the reel and the settings come back, "X of Y clips found"
  // (Y is the clips the database held: this flow made none), and onboarding
  // is not shown again (the flag is a phone state an import keeps).
  await backupScreen.$(_l10n.backupImportButton).tap();
  await waitFor(
    $,
    () => $(_l10n.backupConfirmTitle).exists,
    what: 'the question before an import',
  );
  await $(_l10n.backupConfirmImport).tap();
  await waitFor(
    $,
    () => $(_l10n.backupImportedTitle).exists,
    what: '"Backup imported"',
  );
  expect(
    find.textContaining(' of $total clip'),
    findsOneWidget,
    reason: '"X of $total clips found." says how many clips the phone has',
  );
  await $(_l10n.backupResultOk).tap();
  expect(await _reelNames(env), contains(_reelBackup));
  await _expectStored(env, exported, 'the backup settings after the import');
  expect(
    await phone.onboardingDone(),
    isTrue,
    reason: 'an import keeps the phone state, onboarding included',
  );
  expect($(WelcomeScreen).exists, isFalse);
  expect(await phone.lastExport(), recorded, reason: 'the date is kept');

  // 7. Back on Settings, the imported time is the one shown.
  await _tapBack($);
  await waitFor(
    $,
    () => $(SettingsScreen).$(_timeText($, 450)).exists,
    what: 'Settings to show the imported reminder time',
  );
}

/// Flow 4: Send error log, with the real bridge. The share sheet opens (found
/// by Android's chooser resource ids), Back closes it, nothing is chosen.
Future<void> _sendErrorLog(_Env env) async {
  final $ = env.$;
  final support = await getApplicationSupportDirectory();
  final cache = await getTemporaryDirectory();

  // 1. There is a log to send. The app under Patrol is not started by its
  // `main`, so its log files may not exist: write one line (restored at the
  // end), and a reel whose name must never reach the file.
  final (restoreLog, wroteLine) = await _ensureLogLine(support);
  env.cleanUps.add(restoreLog);
  env.cleanUps.add(() => _deleteBundles(cache));
  await env.container.read(reelsRepositoryProvider).create(_reelLog);

  // 2. Settings, Help, Send error log.
  await _openSettings($);
  final send = _row($, _l10n.settingsErrorLogTitle);
  await send.scrollTo(view: _settingsScroll());
  await send.tap();

  // 3. The share sheet shows (no frame is pumped behind it).
  await waitForShareSheet($);

  // 4. What it was given holds the log and nothing else: one bundle in the
  // cache's `shared/` folder, with the log line, and no reel name.
  final bundles = _bundles(cache);
  expect(bundles, hasLength(1), reason: 'one bundle is shared, never more');
  final content = bundles.single.readAsStringSync();
  expect(content, isNotEmpty);
  if (wroteLine) expect(content, contains(_logLine));
  expect(content, isNot(contains(_reelLog)), reason: 'no reel name in a log');
  expect(content, isNot(contains('taketray-test-')), reason: 'no video name');

  // 5. Back closes the sheet (Back is pressed only now that the sheet is up:
  // on the app's own root screen it would finish the activity). Nothing is
  // chosen, and Settings shows no message.
  await $.platform.android.pressBack();
  await waitForShareSheetToClose($);
  await waitFor(
    $,
    () => $(SettingsScreen).exists,
    what: 'Settings after the share sheet closed',
  );
  await pumpFor($, const Duration(seconds: 1));
  expect($(_l10n.settingsErrorLogNothing).exists, isFalse);
  expect($(_l10n.settingsErrorLogFailed).exists, isFalse);
}

// ============================================================ the test frame

/// What a flow's body gets: the tester, the fake document and folder bridge,
/// the test media (flows that ask for it) and a list of clean-ups that run
/// at the end, in order, whatever happened.
class _Env {
  _Env(this.$, this.files, this.media);

  final PatrolIntegrationTester $;
  final PatrolFilesBridge files;
  final TestMedia? media;
  final List<Future<void> Function()> cleanUps = [];

  ProviderContainer get container => _container($);
}

/// What [_prepare] changed, for the tear-down to put back.
class _Prep {
  AppSettings? settingsBefore;
  bool onboardingWasDone = true;
  bool onboardingChanged = false;
  DateTime? lastExportBefore;
  bool lastExportChanged = false;
}

/// A test that starts from [start] settings, runs [body] and always runs the
/// tear-down, also when [body] fails.
///
/// With [media] the test videos are made available (and always removed);
/// [shootingMayBeOn] turns Shooting mode off first in the tear-down;
/// [onboardingInDatabase] stores onboarding as done in the database too (the
/// app is pumped onboarded either way), so a flow can prove an import keeps
/// it; [resetLastExport] starts with no "last backup" date and puts the old
/// one back.
void _flowTest(
  String description,
  Future<void> Function(_Env env) body, {
  AppSettings start = _defaults,
  bool media = false,
  bool shootingMayBeOn = false,
  bool onboardingInDatabase = false,
  bool resetLastExport = false,
}) {
  patrolTest(description, config: _liveConfig, ($) async {
    final prep = _Prep();
    PatrolFilesBridge? files;
    TestMedia? testMedia;
    _Env? env;
    (Object, StackTrace)? failure;
    try {
      // Inside the try: a throw while preparing (a database that will not
      // open, a test folder that holds another app's file) still reaches the
      // tear-down, which puts back what was changed so far.
      if (media) testMedia = await TestMedia.start();
      await _prepare(
        prep,
        start: start,
        onboardingInDatabase: onboardingInDatabase,
        resetLastExport: resetLastExport,
      );
      files = await PatrolFilesBridge.create();
      env = _Env($, files, testMedia);
      await _startApp(env);
      await waitFor($, () => $(ReelsScreen).exists, what: 'Reels (onboarded)');
      await body(env);
    } on Object catch (error, stack) {
      failure = (error, stack);
    }
    await _tearDown(
      $,
      prep,
      env: env,
      files: files,
      media: testMedia,
      shootingMayBeOn: shootingMayBeOn,
      failure: failure,
    );
  });
}

/// Puts the database in the state a flow starts from, before any app is
/// pumped: the reels of an earlier run gone, the settings [start], and, when
/// asked, onboarding stored as done and no last backup date.
Future<void> _prepare(
  _Prep prep, {
  required AppSettings start,
  required bool onboardingInDatabase,
  required bool resetLastExport,
}) => _withDatabase((c) async {
  final db = c.read(appDatabaseProvider);
  final settings = c.read(settingsRepositoryProvider);
  final phone = c.read(phoneStateRepositoryProvider);
  prep.settingsBefore = await settings.load();
  await _deleteTestReels(db, c.read(reelsRepositoryProvider));
  await settings.save(start);
  if (onboardingInDatabase) {
    prep.onboardingWasDone = await phone.onboardingDone();
    if (!prep.onboardingWasDone) {
      prep.onboardingChanged = true;
      await phone.markOnboardingDone();
    }
  }
  if (resetLastExport) {
    prep
      ..lastExportBefore = await phone.lastExport()
      ..lastExportChanged = true;
    await _deleteSetting(db, PhoneStateRepository.lastExportKey);
  }
});

/// The end of a flow. Each step runs even when one before it threw, and then
/// the first error is thrown: the flow's own [failure] when there is one.
Future<void> _tearDown(
  PatrolIntegrationTester $,
  _Prep prep, {
  required _Env? env,
  required PatrolFilesBridge? files,
  required TestMedia? media,
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

  // While the app is still up: Shooting mode off (it cancels the background
  // job and its notification), and the settings back, so the background's
  // copy of them follows (the app writes it) and does not keep a test value.
  await step(() async {
    if (find.byType(TakeTrayApp).evaluate().isEmpty) return;
    final container = _container($);
    if (shootingMayBeOn) {
      await container
          .read(shootingModeControllerProvider.notifier)
          .setOn(false)
          .timeout(const Duration(seconds: 15));
    }
    final before = prep.settingsBefore;
    if (before != null) {
      await container
          .read(settingsRepositoryProvider)
          .save(before)
          .timeout(const Duration(seconds: 15));
    }
    await container
        .read(backgroundSyncProvider)
        .flush()
        .timeout(const Duration(seconds: 15));
  });
  for (final cleanUp in env?.cleanUps ?? const <Future<void> Function()>[]) {
    await step(cleanUp);
  }
  // The test videos (also removed by the tear-down TestMedia registered).
  if (media != null) await step(media.cleanUp);
  if (files != null) await step(files.dispose);
  // Close the app, then clean the database with a container of its own.
  await step(() async {
    await $.tester.pumpWidget(const SizedBox.shrink());
    await $.tester.pump(const Duration(milliseconds: 500));
  });
  await step(
    () => _withDatabase((c) async {
      final db = c.read(appDatabaseProvider);
      await _deleteTestReels(db, c.read(reelsRepositoryProvider));
      final phone = c.read(phoneStateRepositoryProvider);
      if (prep.onboardingChanged) {
        await _deleteSetting(db, PhoneStateRepository.onboardingDoneKey);
      }
      if (prep.lastExportChanged) {
        await _deleteSetting(db, PhoneStateRepository.lastExportKey);
        final before = prep.lastExportBefore;
        if (before != null) await phone.recordExport(before);
      }
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
/// closed first, then the container disposed, as the other files do).
Future<T> _withDatabase<T>(Future<T> Function(ProviderContainer c) run) async {
  final container = ProviderContainer();
  try {
    return await run(container).timeout(const Duration(seconds: 30));
  } finally {
    await container.read(appDatabaseProvider).close();
    container.dispose();
  }
}

Future<void> _deleteSetting(AppDatabase db, String key) =>
    (db.delete(db.settings)..where((s) => s.key.equals(key))).go();

/// Deletes the reels this file makes (`TakeTray Test *`). The database is
/// TakeTray Dev's own.
Future<void> _deleteTestReels(AppDatabase db, ReelsRepository reels) async {
  // A one-off read, not a stream (a stream still being cancelled when the
  // database closes fails the test).
  final all = await db.select(db.reels).get();
  for (final reel in all) {
    if (reel.name.startsWith(_reelPrefix)) await reels.delete(reel.id);
  }
}

// ================================================================== helpers

const String _reelPrefix = 'TakeTray Test ';
const String _reelBackup = '${_reelPrefix}Backup';
const String _reelLog = '${_reelPrefix}Log';

/// The last segment of the test folder: what Settings names it.
const String _folderName = 'TakeTray Test';

/// The one line the flow writes into the app's log when it has none.
const String _logLine = 'patrol settings test: one line of log';

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The Shooting mode card pulses for ever and a snack counts down: never wait
// for the screen to settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

/// Pumps a fresh app: a new `ProviderScope` (a key of its own, so Flutter
/// never reuses the old container), onboarded, with the fake files bridge.
Future<void> _startApp(_Env env) => env.$.pumpWidget(
  ProviderScope(
    key: UniqueKey(),
    overrides: [
      ...onboardedOverrides,
      filesBridgeProvider.overrideWithValue(env.files),
    ],
    child: const TakeTrayApp(),
  ),
);

/// A restart: the widget tree goes, and a fresh app reads the database again.
Future<void> _restart(_Env env) async {
  await env.$.pumpWidget(const SizedBox.shrink());
  await env.$.tester.pump(const Duration(milliseconds: 500));
  await _startApp(env);
  await waitFor(
    env.$,
    () => env.$(ReelsScreen).exists,
    what: 'Reels after a restart',
  );
}

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(TakeTrayApp)));

Future<AppSettings> _stored(_Env env) =>
    env.container.read(settingsRepositoryProvider).load();

/// Waits until the stored settings are [expected]. The failure names the
/// settings that differ, never their values (D-10).
Future<void> _expectStored(_Env env, AppSettings expected, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (true) {
    final stored = await _stored(env);
    if (stored == expected) {
      debugPrint('ok: $what');
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out waiting for: $what (differs in: '
        '${_differing(stored, expected)})',
      );
    }
    await env.$.tester.pump(const Duration(milliseconds: 250));
  }
}

/// The names of the settings that differ between [a] and [b].
String _differing(AppSettings a, AppSettings b) => [
  if (!listEquals(a.watchedFolders, b.watchedFolders)) 'watchedFolders',
  if (a.eveningReminderEnabled != b.eveningReminderEnabled) 'evening',
  if (a.eveningReminderMinutes != b.eveningReminderMinutes) 'eveningTime',
  if (a.stillReminderEnabled != b.stillReminderEnabled) 'still',
  if (a.copiesReminderEnabled != b.copiesReminderEnabled) 'copies',
].join(', ');

Future<void> _flush(_Env env) =>
    env.container.read(backgroundSyncProvider).flush();

/// Waits until [done] (an async read) is true, pumping frames meanwhile.
Future<void> _waitUntil(
  PatrolIntegrationTester $,
  Future<bool> Function() done, {
  required String what,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what',
      );
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
  debugPrint('ok: $what');
}

/// Pumps frames for [duration] and fails with [reason] the moment [happened]
/// is true: a negative check, which proves something only when a positive
/// one beside it proves the check works.
Future<void> _expectNever(
  PatrolIntegrationTester $,
  Future<bool> Function() happened,
  Duration duration,
  String reason,
) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    if (await happened()) throw TestFailure(reason);
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}

// ---------------------------------------------------------------- Settings

/// The Settings tab, on screen.
Future<void> _openSettings(PatrolIntegrationTester $) async {
  await _showTab($, _l10n.navSettings);
  await waitFor($, () => $(SettingsScreen).exists, what: 'Settings');
  // The switches do nothing until the stored settings are read.
  await waitFor(
    $,
    () =>
        $.tester
            .widget<TtSwitch>(_switchOf($, _l10n.settingsEveningTitle))
            .onChanged !=
        null,
    what: 'the stored settings to be read (the switches work)',
  );
}

/// One of the three tabs, by its label.
Future<void> _showTab(PatrolIntegrationTester $, String label) =>
    $(TtNavPill).$(label).tap();

/// The Settings row whose title is [title].
PatrolFinder _row(PatrolIntegrationTester $, String title) =>
    $(SettingsScreen).$(TtListRow).containing(title);

PatrolFinder _switchOf(PatrolIntegrationTester $, String title) =>
    _row($, title).$(TtSwitch);

/// Whether the switch of the row [title] shows on.
bool _isOn(PatrolIntegrationTester $, String title) =>
    $.tester.widget<TtSwitch>(_switchOf($, title)).value;

/// Whether the switch of a Watched folders row shows on.
bool _folderOn(PatrolIntegrationTester $, Finder row) => $.tester
    .widget<TtSwitch>(find.descendant(of: row, matching: find.byType(TtSwitch)))
    .value;

/// The scrollable of the Settings screen, for `scrollTo`.
Finder _settingsScroll() => find
    .descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls the Watched folders list until [target] shows, then taps it (with
/// full access the list holds every folder with videos, so a row near its end
/// is off the screen).
Future<void> _tapScrolled(
  PatrolIntegrationTester $,
  PatrolFinder target,
) async {
  await target.scrollTo(
    view: find
        .descendant(
          of: find.byType(WatchedFoldersScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await target.tap();
}

/// Taps the back button of a pushed screen (Android's Back is kept for the
/// share sheet: on a root screen it would finish the activity).
Future<void> _tapBack(PatrolIntegrationTester $) async {
  final back = find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == _l10n.navBack,
  );
  await $(back).tap();
  await waitFor(
    $,
    () => back.evaluate().isEmpty,
    what: 'the pushed screen to close',
  );
}

/// [minutes] after midnight as the phone shows a time of day (the row's own
/// words: the 12 or 24-hour setting decides).
String _timeText(PatrolIntegrationTester $, int minutes) {
  final context = $.tester.element(find.byType(SettingsScreen));
  return timeOfDayText(
    DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
    locale: Localizations.localeOf(context).toString(),
    use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Taps the Reminder time row and waits for the time picker. The row opens
/// one picker at a time and ignores a tap just after one closed, so a tap
/// that opened nothing within 4 s is made once more.
Future<void> _openTimePicker(PatrolIntegrationTester $, String rowTitle) async {
  final dialog = find.byType(TimePickerDialog);
  for (var attempt = 0; attempt < 2; attempt++) {
    await _row($, rowTitle).tap();
    final end = DateTime.now().add(const Duration(seconds: 4));
    while (dialog.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await $.tester.pump(const Duration(milliseconds: 250));
    }
    if (dialog.evaluate().isNotEmpty) return;
  }
  throw TestFailure('The time picker did not open from the Reminder time row');
}

/// In Flutter's time picker (open): types [hour]:[minute] in its text mode
/// (the dial needs no taps at points), sets AM or PM on a 12-hour phone, and
/// taps OK.
Future<void> _pickTime(
  PatrolIntegrationTester $, {
  required int hour,
  required int minute,
}) async {
  final dialog = find.byType(TimePickerDialog);
  await waitFor($, () => dialog.evaluate().isNotEmpty, what: 'the time picker');
  final context = $.tester.element(dialog);
  final words = MaterialLocalizations.of(context);
  final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
  await $(find.byTooltip(words.inputTimeModeButtonLabel)).tap();
  final fields = find.descendant(of: dialog, matching: find.byType(TextField));
  await waitFor(
    $,
    () => fields.evaluate().length == 2,
    what: "the picker's hour and minute fields",
  );
  String two(int n) => n.toString().padLeft(2, '0');
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  await $(fields.at(0)).enterText(use24 ? two(hour) : '$h12');
  await $(fields.at(1)).enterText(two(minute));
  if (!use24) {
    final period = hour < 12
        ? words.anteMeridiemAbbreviation
        : words.postMeridiemAbbreviation;
    await $(find.descendant(of: dialog, matching: find.text(period))).tap();
  }
  await $(words.okButtonLabel).tap();
  await waitFor(
    $,
    () => dialog.evaluate().isEmpty,
    what: 'the picker to close',
  );
}

/// Closes the open time picker with Cancel.
Future<void> _cancelTimePicker(PatrolIntegrationTester $) async {
  final dialog = find.byType(TimePickerDialog);
  await waitFor($, () => dialog.evaluate().isNotEmpty, what: 'the time picker');
  final words = MaterialLocalizations.of($.tester.element(dialog));
  await $(words.cancelButtonLabel).tap();
  await waitFor(
    $,
    () => dialog.evaluate().isEmpty,
    what: 'the picker to close',
  );
}

// ----------------------------------------------------- Shooting mode, media

/// Full video access, the way a user gives it, from the To tag banner (when
/// an earlier flow did not give it already).
Future<void> _ensureFullAccess(_Env env) async {
  final $ = env.$;
  MediaAccessLevel? level() =>
      env.container.read(mediaAccessControllerProvider).value?.level;
  await waitFor($, () => level() != null, what: 'the video access to be read');
  if (level() == MediaAccessLevel.full) return;
  final toTag = $(ToTagScreen);
  await _showTab($, _l10n.navToTag);
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
}

/// Taps the Shooting mode switch on Reels and waits until the stored state is
/// [on]. The first time it goes on, the app asks for the notification
/// permission (Android 13 and later): it is answered when it is not allowed
/// yet, so a phone that allowed it already never waits for a dialog.
Future<void> _setShootingMode(_Env env, {required bool on}) async {
  final $ = env.$;
  bool? stored() =>
      env.container.read(shootingModeControllerProvider).value?.on;
  await _showTab($, _l10n.navReels);
  await waitFor(
    $,
    () => stored() != null,
    what: 'the stored Shooting mode to be read',
  );
  if (stored() != on) {
    final allowed =
        (await env.container
                .read(backgroundBridgeProvider)
                .notificationAccess())
            .granted;
    await $(ReelsScreen).$(TtSwitch).tap();
    if (on && !allowed) await allowNotificationsInDialog($);
  }
  await waitFor(
    $,
    () => stored() == on,
    what: 'Shooting mode to be stored as ${on ? 'on' : 'off'}',
  );
}

/// The media ids of the clips waiting in To tag now (a one-off read).
Future<List<int?>> _pendingIds(_Env env) async => [
  for (final clip
      in await env.container
          .read(clipsRepositoryProvider)
          .watchInbox(InboxState.pending)
          .first)
    clip.mediaStoreId,
];

/// Waits until [video] is a clip waiting in To tag. (Clips an earlier flow
/// left are in the list too, so a count would say nothing: the id does.)
Future<void> _waitForClip(
  _Env env,
  InsertedVideo video, {
  required String what,
}) async {
  await _showTab(env.$, _l10n.navToTag);
  await _waitUntil(
    env.$,
    () async => (await _pendingIds(env)).contains(video.mediaStoreId),
    what: what,
    timeout: const Duration(seconds: 90),
  );
}

/// The names of the reels in the database now (a one-off read).
Future<List<String>> _reelNames(_Env env) async {
  final db = env.container.read(appDatabaseProvider);
  return [for (final reel in await db.select(db.reels).get()) reel.name];
}

// ------------------------------------------------------------------ the log

/// Makes sure the app has a log line to send. Returns what puts the log
/// files back as they were, and whether the line was written by this call.
/// (The files are the app's own; the line says nothing about the owner.)
Future<(Future<void> Function(), bool)> _ensureLogLine(
  Directory support,
) async {
  final current = File('${support.path}/taketray-0.log');
  final previous = File('${support.path}/taketray-1.log');
  bool hasLine(File f) => f.existsSync() && f.readAsBytesSync().contains(0x0A);
  if (hasLine(current) || hasLine(previous)) return (() async {}, false);
  final before = current.existsSync() ? current.readAsBytesSync() : null;
  await current.writeAsString('$_logLine\n', flush: true);
  Future<void> restore() async {
    if (before == null) {
      if (current.existsSync()) await current.delete();
    } else {
      await current.writeAsBytes(before, flush: true);
    }
  }

  return (restore, true);
}

/// The log bundles in the cache's `shared/` folder.
List<File> _bundles(Directory cache) {
  final shared = Directory('${cache.path}/shared');
  if (!shared.existsSync()) return const [];
  return [
    for (final entry in shared.listSync())
      if (entry is File &&
          entry.uri.pathSegments.last.startsWith('taketray-log-'))
        entry,
  ];
}

Future<void> _deleteBundles(Directory cache) async {
  for (final file in _bundles(cache)) {
    await file.delete();
  }
}
