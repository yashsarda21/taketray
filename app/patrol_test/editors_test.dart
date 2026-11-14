import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/features/editors/views/copy_progress_screen.dart';
import 'package:taketray/features/editors/views/copy_ready_screen.dart';
import 'package:taketray/features/editors/views/edit_select_screen.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/views/clip_viewer_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/editors_hooks.dart';
import 'support/own_texts.dart';
import 'support/shade.dart';
import 'support/system_dialogs.dart';
import 'support/test_background.dart';
import 'support/test_media.dart';
import 'support/waiting.dart';

/// Editor handoff on the S24 (phase 8, Task 14): sending a reel's clips to
/// CapCut, the VN copy, Cancel, adding clips later, removing a clip during a
/// session, Share and the copies reminder.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`), started from cleared app data. The videos are the
/// test fixture, put into `Movies/TakeTray Test/` through the debug channel
/// (D-77) and deleted again, also when a flow fails (`TestMedia.start`
/// registers it, and `_cleanUp` runs it at the end of the body). Every reel
/// is called `TakeTray Test <timestamp>`. Nothing else on the phone is read,
/// written or deleted:
///
/// - **No editor, store or share sheet ever opens.** The editors hook
///   (`app.taketray/test_editors`, `DebugEditorHooks.kt`) records every
///   intent instead of starting it, and shows CapCut, Instagram Edits and VN
///   as installed (`setInstalledOverride`) whatever the phone has. Both are
///   put back at the end of every flow, also a failed one.
/// - **The copies** are made by the real copy engine, from the test videos
///   into `Movies/TakeTray/<test reel>/`, which only TakeTray Dev writes
///   to. `CopyBridge.ownRowsIn(folder)` lists only TakeTray-owned rows of that
///   one folder (a test reel's), so no other folder, file or app is listed.
///   A flow that cancels slows the engine down (`setCopyThrottleMs`) so the
///   copy is still running when Cancel is tapped.
/// - **Tear-down.** Each flow's last step is Done editing on every test reel
///   through the app's own guarded delete (`EditSessionService.doneEditing`,
///   after stopping a copy that still runs), then the folders are checked
///   empty, then the test videos go. It runs even when the flow failed.
/// - **The notification shade** is opened by one flow, to tap TakeTray's own
///   copies reminder by its own exact text (`OwnText.copiesBody`), and only
///   after the app's own list of its notifications (`activeNotifications`,
///   which never shows another app's) holds that reminder and nothing else.
///   Nothing in the shade is listed or read.
/// - **No test waits for Android's scheduler** (WorkManager, alarms, jobs):
///   the reminder is posted by the debug trigger (`showCopiesReminderNow`).
/// - **Logs (D-10).** Only counts are printed; no reel name, folder, path or
///   address is, in a log or a failure message.
///
/// The watched folder is set to the test folder first and put back at the end
/// (`watchOnlyTestFolder`). Full access is never asked for: in Manual mode
/// Android still answers for TakeTray Dev's own test videos, and the reel
/// page does not verify the clips.
///
/// The words are the app's own (`AppLocalizations`), never typed twice.
void main() {
  patrolTest(
    'CapCut send: 3 clips go in one share to CapCut, in shooting order, '
    'and Done editing ends it',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _capcutSend($, env)),
  );

  patrolTest(
    'CapCut not installed: its row is greyed out and says Not installed',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _notInstalled($, env)),
  );

  patrolTest(
    'VN copy for real: 3 copies in the folder, the ready screen, Open VN '
    'is recorded, Done editing deletes them',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _vnCopy($, env)),
  );

  patrolTest(
    'Cancel a VN copy: the screen stays on while it runs, Stop deletes '
    'every copy',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _cancelCopy($, env)),
  );

  patrolTest(
    'Add later: a 4th clip is new since you started editing, Copy to VN '
    'folder adds it',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _addLater($, env)),
  );

  patrolTest(
    'Remove during a session: the clip leaves the reel and its copy leaves '
    'the folder',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _removeDuringSession($, env)),
  );

  patrolTest(
    "Share from the viewer: Android's chooser around ACTION_SEND for 1 clip",
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _share($, env)),
  );

  patrolTest(
    "The copies reminder: tapping TakeTray's notification opens the reel and "
    'asks Done editing',
    config: _liveConfig,
    timeout: _testTimeout,
    ($) => _scenario($, (env) => _reminderTap($, env)),
  );
}

// ============================================================ the flows

/// CapCut send. 3 test clips in a new reel; **Edit video**, **Select all**,
/// **Continue**, **CapCut**: one `ACTION_SEND_MULTIPLE` to CapCut with the 3
/// clips in shooting order, the read grant and a ClipData of 3; the snack, the
/// Ready to edit question (Not now), the banner and "In your edit"; then Done
/// editing (the banner's, then the dialog's) and the Published question (Not
/// now).
Future<void> _capcutSend(PatrolIntegrationTester $, _Env env) async {
  final reel = await env.reelWithClips(3);
  await _openReel($, reel);
  await _pickAllAndContinue($, 3);
  await $(_editorRow(EditorApp.capcut)).tap();

  final snack = _l10n.editorSentSnack(3, _l10n.editorNameCapcut);
  await waitFor(
    $,
    () => _count(find.text(snack)) == 1 && _count(_pickScreen) == 0,
    what: 'the "Sent 3 clips to CapCut" snack, with the picking screen gone',
  );

  final recorded = await env.editors.takeRecordedIntents();
  expect(recorded.length, 1, reason: 'one intent, to CapCut');
  final intent = recorded.single;
  expect(intent.action, RecordedIntent.actionSendMultiple);
  expect(intent.package, EditorApp.capcut.packageName);
  expect(intent.type, 'video/*');
  expect(intent.uris.length, 3);
  expect(
    listEquals(intent.uris, reel.labels),
    isTrue,
    reason: 'the 3 clips, each once, in shooting order',
  );
  expect(intent.grantRead, isTrue, reason: 'read access is granted');
  expect(intent.clipDataCount, 3);
  expect(intent.data, isNull, reason: 'not the store');

  // The reel is still Collecting, so it offers Ready to edit; Not now.
  await _answerMarkDialog(
    $,
    title: _l10n.markStatusTitle(reel.name, _l10n.statusReady),
    what: 'the Ready to edit question',
  );

  // The page: the banner and "In your edit" (no copies: the originals went).
  await waitFor(
    $,
    () =>
        _count(_inBanner(_l10n.reelEditingIn(_l10n.editorNameCapcut))) == 1 &&
        _count(_inSection(_inEditSection, _l10n.reelInEditTitle)) == 1,
    what: 'the CapCut banner and the "In your edit" section',
  );
  final state = await env.editState(reel.id);
  expect(state, isNotNull, reason: 'the session is stored');
  expect(state!.session.editor, EditorApp.capcut);
  expect(state.copies.length, 0, reason: 'CapCut gets the originals');
  expect(state.sentIds.length, 3);

  // Done editing: the banner's button, then the dialog's (both say it).
  await $(_inBanner(_l10n.reelDoneEditing)).tap();
  await _waitForDialog(
    $,
    _l10n.doneEditingTitle(reel.name),
    what: 'the Done editing question',
  );
  await $(_dialog).$(_l10n.reelDoneEditing).tap();
  await waitFor(
    $,
    () => _count(_banner) == 0,
    what: 'the editing banner to go after Done editing',
  );
  expect(
    await env.editState(reel.id) == null,
    isTrue,
    reason: 'the session ended',
  );

  // Then Published; Not now.
  await _answerMarkDialog(
    $,
    title: _l10n.markStatusTitle(reel.name, _l10n.statusPublished),
    what: 'the Published question',
  );
}

/// With CapCut shown as not installed: its row is greyed out, says "Not
/// installed", does nothing when tapped, and the others are not greyed out.
Future<void> _notInstalled(PatrolIntegrationTester $, _Env env) async {
  await env.editors.setInstalled({
    EditorApp.capcut: false,
    EditorApp.edits: true,
    EditorApp.vn: true,
  });
  final reel = await env.reelWithClips(3);
  await _openReel($, reel);
  await _pickAllAndContinue($, 3);

  // The sheet draws every row as installed until the phone answers: wait for
  // the answer before tapping anything.
  final capcut = _editorRow(EditorApp.capcut);
  await waitFor(
    $,
    () => _count(_notInstalledIn(capcut)) == 1,
    what: 'the CapCut row to say "${_l10n.editorNotInstalled}"',
  );
  expect(
    _count(_notInstalledIn(_editorRow(EditorApp.edits))),
    0,
    reason: 'Instagram Edits is not greyed out',
  );
  expect(
    _count(_notInstalledIn(_editorRow(EditorApp.vn))),
    0,
    reason: 'VN is not greyed out',
  );
  expect(_count(find.text(_l10n.editorGreyedNote)), 1, reason: 'the note');

  // A tap on the greyed row sends nothing and opens nothing.
  await $(capcut).tap();
  await pumpFor($, const Duration(seconds: 2));
  expect(
    (await env.editors.takeRecordedIntents()).length,
    0,
    reason: 'nothing was sent to CapCut',
  );
  expect(_count(_dialog), 0, reason: 'no dialog opened');
  expect(
    await env.editState(reel.id) == null,
    isTrue,
    reason: 'no session started',
  );
  expect(
    _count(find.text(_l10n.editorSheetTitle(3))),
    1,
    reason: 'the sheet is still open',
  );
}

/// VN copy for real. 3 test clips; **Edit video**, **Select all**,
/// **Continue**, **VN**, the space screen, **Copy 3 clips**: the engine copies
/// in the app, the ready screen shows the folder with the screen no longer
/// kept on, and the folder holds exactly 3 finished TakeTray-owned copies.
/// **Open VN** is recorded and not started. Done editing (the banner's) >
/// **Delete copies**: the folder is empty and "Copies deleted" shows.
Future<void> _vnCopy(PatrolIntegrationTester $, _Env env) async {
  final reel = await env.reelWithClips(3);
  final folder = await _startVnSession($, env, reel);

  // The ready screen: VN, the folder named, the window no longer kept on.
  final ready = find.byType(CopyReadyScreen);
  expect(
    _count(
      find.descendant(
        of: ready,
        matching: find.text(_l10n.copyReadyTitle(_l10n.editorNameVn)),
      ),
    ),
    1,
    reason: 'the ready screen says Ready for VN',
  );
  expect(
    _count(
      find.descendant(
        of: ready,
        matching: find.textContaining(folder, findRichText: true),
      ),
    ),
    greaterThan(0),
    reason: 'the ready screen names the folder',
  );
  await _waitForFlag($, env, wanted: false, what: 'the screen no longer on');

  // The folder: exactly 3 finished rows, every one TakeTray's own.
  final rows = await env.rowsIn(folder);
  expect(rows.length, 3, reason: 'three copies in the folder');
  expect(rows.every((r) => !r.pending), isTrue, reason: 'all finished');
  expect(rows.every((r) => r.sizeBytes > 0), isTrue, reason: 'none empty');
  final state = await env.editState(reel.id);
  expect(state!.session.editor, EditorApp.vn);
  expect(state.copies.length, 3, reason: 'the session records 3 copies');

  // Open VN: recorded, not started (the app stays in front).
  await $(
    find.widgetWithText(TtButton, _l10n.copyOpenEditor(_l10n.editorNameVn)),
  ).tap();
  await _expectOpenVnRecorded($, env);
  expect(_count(ready), 1, reason: 'the ready screen is still on top');

  // Done: the reel's page and its banner.
  await $(find.widgetWithText(TtButton, _l10n.copyDone)).tap();
  await waitFor(
    $,
    () =>
        _count(_banner) == 1 &&
        _count(_inBanner(_l10n.reelEditingCopies(3, folder))) == 1,
    what: 'the VN banner with 3 copies',
  );

  // Done editing > Delete copies.
  final size = byteSizeText(
    _l10n,
    state.copies.fold<int>(0, (sum, c) => sum + c.sizeBytes),
  );
  await $(_inBanner(_l10n.reelDoneEditing)).tap();
  await _waitForDialog(
    $,
    _l10n.doneEditingExportedTitle,
    what: 'the "Have you exported your video?" question',
  );
  await $(_dialog).$(_l10n.doneEditingDeleteCopies).tap();
  await waitFor(
    $,
    () => _count(_freedSnack) == 1 && _count(_banner) == 0,
    what: 'the "Copies deleted · … freed" snack and no banner',
  );
  expect(
    _count(find.text(_l10n.doneEditingFreedSnack(size))),
    1,
    reason: 'the snack names the size of the 3 copies',
  );
  expect((await env.rowsIn(folder)).length, 0, reason: 'the folder is empty');
  expect(
    await env.editState(reel.id) == null,
    isTrue,
    reason: 'the session ended',
  );

  await _answerMarkDialog(
    $,
    title: _l10n.markStatusTitle(reel.name, _l10n.statusPublished),
    what: 'the Published question',
  );
}

/// Cancel. The engine pauses after each chunk (a test video is one chunk, so
/// 4 s a clip); a 3-clip copy is started; the screen is kept on while it
/// runs; **Cancel** > **Stop** deletes every copy, the reel's page says
/// "Copying stopped. No copies were kept." and the screen is let go.
Future<void> _cancelCopy(PatrolIntegrationTester $, _Env env) async {
  await env.copy.setThrottleMs(_slowCopyMs);
  final reel = await env.reelWithClips(3);
  await _openReel($, reel);
  await _pickAllAndContinue($, 3);
  await $(_editorRow(EditorApp.vn)).tap();
  await _startCopyFromSpaceScreen($, 3);

  // Copying: the progress screen, and the window kept on.
  final progress = find.byType(CopyProgressScreen);
  await waitFor(
    $,
    () =>
        _count(
          find.descendant(
            of: progress,
            matching: find.text(_l10n.copyProgressTitle(_l10n.editorNameVn)),
          ),
        ) ==
        1,
    what: 'the "Copying clips for VN" screen',
  );
  await _waitForFlag($, env, wanted: true, what: 'the screen kept on');
  final job = await env.copyBridge.current();
  expect(job, isNotNull, reason: 'the engine holds the job');
  expect(job!.state, CopyState.running, reason: 'the copy is running');
  final folder = job.folderName;
  env.folders.add(folder);
  expect(
    _count(
      find.descendant(of: progress, matching: find.text(_l10n.copyKeepOpen)),
    ),
    1,
    reason: 'the Keep TakeTray open line shows',
  );

  // Cancel > Stop.
  await $(find.descendant(of: progress, matching: find.text(_l10n.cancel)))
      .tap();
  await _waitForDialog(
    $,
    _l10n.copyStopTitle,
    what: 'the Stop copying? question',
  );
  await $(_dialog).$(_l10n.copyStop).tap();

  await waitFor(
    $,
    () =>
        _count(find.text(_l10n.copyStoppedFirst)) == 1 &&
        _count(progress) == 0 &&
        _count(find.byType(ReelDetailScreen)) == 1,
    what: 'the reel page with "Copying stopped. No copies were kept."',
    timeout: const Duration(seconds: 60),
  );
  expect((await env.rowsIn(folder)).length, 0, reason: 'no copy was kept');
  await _waitForFlag($, env, wanted: false, what: 'the screen let go');
  expect(
    await env.editState(reel.id) == null,
    isTrue,
    reason: 'no session was kept',
  );
  expect(_count(_banner), 0, reason: 'no editing banner');
}

/// Add later. In a VN session with 3 copies, a 4th test clip is added to the
/// reel: "New since you started editing" shows 1; **Copy to VN folder** opens
/// the picker with the new clip ticked; **Copy** copies it; "1 clip added to
/// the VN folder"; the folder holds 4 finished copies.
Future<void> _addLater(PatrolIntegrationTester $, _Env env) async {
  final reel = await env.reelWithClips(3);
  final folder = await _startVnSession($, env, reel);
  await $(find.widgetWithText(TtButton, _l10n.copyDone)).tap();
  await waitFor(
    $,
    () => _count(_banner) == 1 && _count(find.byType(ReelDetailScreen)) == 1,
    what: 'the reel page with its banner',
  );

  // The 4th clip, tagged into the reel while the session runs.
  final newIds = await env.addToReel(reel, await env.media.insertMany(1));
  await waitFor(
    $,
    () =>
        _count(_newSection) == 1 &&
        _count(_inSection(_newSection, _l10n.reelNewSinceSubtitle(1))) == 1,
    what: '"New since you started editing" with 1 clip',
  );

  // Copy to VN folder: the picker, the new clip ticked, 1 to copy.
  await $(
    find.descendant(
      of: _newSection,
      matching: find.widgetWithText(
        TtButton,
        _l10n.reelCopyToFolder(_l10n.editorNameVn),
      ),
    ),
  ).tap();
  final bar = find.byKey(const ValueKey<String>('edit-select-bottom-bar'));
  await waitFor(
    $,
    () =>
        _count(_pickScreen) == 1 &&
        _count(
              find.descendant(
                of: bar,
                matching: find.text(_l10n.editAddBarCount(1)),
              ),
            ) ==
            1,
    what: 'the add picker saying "1 new clip to copy"',
  );
  final fresh = $.tester.widget<TtClipTile>(
    find.byKey(ValueKey<int>(newIds.single)),
  );
  expect(fresh.selected, isTrue, reason: 'the new clip is pre-ticked');
  expect(
    _count(find.descendant(of: _pickScreen, matching: find.byType(TtClipTile))),
    4,
    reason: 'every live clip is listed',
  );
  await $(find.byKey(const ValueKey<String>('edit-select-continue'))).tap();

  // The space screen, then "1 clip added to the VN folder".
  await _startCopyFromSpaceScreen($, 1);
  final snack = _l10n.copyAddedSnack(1, _l10n.editorNameVn);
  await waitFor(
    $,
    () =>
        _count(find.text(snack)) == 1 &&
        _count(find.byType(CopyProgressScreen)) == 0 &&
        _count(find.byType(ReelDetailScreen)) == 1,
    what: 'the reel page with "1 clip added to the VN folder"',
    timeout: const Duration(seconds: 60),
  );
  final rows = await env.rowsIn(folder);
  expect(rows.length, 4, reason: 'four copies in the folder');
  expect(rows.every((r) => !r.pending), isTrue, reason: 'all finished');
  expect((await env.editState(reel.id))!.copies.length, 4);
  await waitFor(
    $,
    () => _count(_inBanner(_l10n.reelEditingCopies(4, folder))) == 1,
    what: 'the banner saying 4 copies',
  );
}

/// Remove during a session. In a VN session with 3 copies, one clip is
/// removed from the reel: its copy is deleted first, so the folder drops by 1.
Future<void> _removeDuringSession(PatrolIntegrationTester $, _Env env) async {
  final reel = await env.reelWithClips(3);
  final folder = await _startVnSession($, env, reel);
  await $(find.widgetWithText(TtButton, _l10n.copyDone)).tap();
  await waitFor(
    $,
    () => _count(_banner) == 1 && _count(find.byType(ReelDetailScreen)) == 1,
    what: 'the reel page with its banner',
  );
  final before = (await env.rowsIn(folder)).length;
  expect(before, 3);

  // ⋮ > Select clips > the first tile > Remove from this reel.
  await $(find.byType(ReelDetailScreen)).$(Symbols.more_vert_rounded).tap();
  await $(_l10n.reelMenuSelectClips).tap();
  final tile = find.descendant(
    of: find.byType(ReelDetailScreen),
    matching: find.byType(TtClipTile),
  );
  await waitFor(
    $,
    () => _count(tile) == 3,
    what: 'the 3 clips as tiles while choosing',
  );
  await $(tile.first).tap();
  await waitFor(
    $,
    () => _count(find.text(_l10n.selectionCount(1))) == 1,
    what: 'the bar saying 1 selected',
  );
  await $(_iconButtonLabelled(_l10n.selectionRemove)).tap();

  final snack = _l10n.removedWithCopies(
    _l10n.clipsRemovedSnack(1, reel.name),
    _l10n.copiesDeletedSuffix(1),
  );
  await waitFor(
    $,
    () => _count(find.text(snack)) == 1,
    what: 'the snack saying the clip left and its copy was deleted',
  );
  final after = await env.rowsIn(folder);
  expect(after.length, before - 1, reason: 'the folder dropped by 1');
  expect((await env.editState(reel.id))!.copies.length, 2);
  await waitFor($, () => _count(tile) == 2, what: 'the reel to show 2 clips');
}

/// Share from the viewer: a chooser around `ACTION_SEND` with 1 clip and the
/// read grant. No session starts.
Future<void> _share(PatrolIntegrationTester $, _Env env) async {
  final reel = await env.reelWithClips(2);
  await _openReel($, reel);
  final tile = find.descendant(
    of: find.byType(ReelDetailScreen),
    matching: find.byType(TtClipTile),
  );
  await waitFor($, () => _count(tile) == 2, what: 'the 2 clips as tiles');
  await $(tile.first).tap();
  await waitFor(
    $,
    () => _count(find.byType(ClipViewerScreen)) == 1,
    what: 'the clip viewer',
  );
  await $(find.text(_l10n.viewerShare)).tap();

  final recorded = await _takeIntents(
    $,
    env,
    what: 'the chooser to be recorded',
  );
  expect(recorded.length, 1, reason: 'one chooser');
  final intent = recorded.single;
  expect(intent.action, RecordedIntent.actionChooser);
  expect(intent.targetAction, RecordedIntent.actionSend);
  expect(intent.uris.length, 1);
  expect(
    listEquals(intent.uris, [reel.labels.first]),
    isTrue,
    reason: 'the clip the viewer showed',
  );
  expect(intent.grantRead, isTrue, reason: 'read access is granted');
  expect(intent.package, isNull, reason: 'a chooser names no app');
  expect(
    await env.editState(reel.id) == null,
    isTrue,
    reason: 'Share starts no session',
  );
}

/// The reminder. In a VN session with copies, TakeTray's own copies reminder is
/// posted by the debug trigger; with it the only notification TakeTray has,
/// the shade is opened and its body tapped: the reel's page and the Done
/// editing question show, **Not yet** keeps everything.
Future<void> _reminderTap(PatrolIntegrationTester $, _Env env) async {
  final reel = await env.reelWithClips(3);
  final folder = await _startVnSession($, env, reel);
  await $(find.widgetWithText(TtButton, _l10n.copyDone)).tap();
  await waitFor(
    $,
    () => _count(_banner) == 1 && _count(find.byType(ReelDetailScreen)) == 1,
    what: 'the reel page with its banner',
  );

  await _allowNotifications($, env);
  await _postReminder($, env, reel.id);

  // The only notification TakeTray has: the app's own list says so.
  final ids = await env.bg.activeNotifications();
  expect(
    listEquals(ids, [_copiesIdBase + reel.id]),
    isTrue,
    reason: "the reminder is TakeTray's only notification",
  );

  var shadeOpen = false;
  try {
    await openShade($);
    shadeOpen = true;
    final text = OwnText.copiesBody();
    await waitForShade(
      $,
      text,
      since: Stopwatch()..start(),
      timeout: const Duration(seconds: 30),
    );
    await tapNotification($, text);
    shadeOpen = false;
  } finally {
    if (shadeOpen) await closeShade($);
  }

  // The reel's page and the Done editing question.
  await _waitForDialog(
    $,
    _l10n.doneEditingExportedTitle,
    what: 'the Done editing question from the reminder',
    timeout: const Duration(seconds: 60),
  );
  expect(_count(find.byType(ReelDetailScreen)), greaterThan(0));
  await $(_dialog).$(_l10n.doneEditingNotYet).tap();
  await waitFor(
    $,
    () => _count(_dialog) == 0,
    what: 'the question to close on Not yet',
  );
  expect(
    await env.editState(reel.id),
    isNotNull,
    reason: 'Not yet keeps the session',
  );
  expect((await env.rowsIn(folder)).length, 3);
}

// ============================================================ the set-up

final Finder _app = find.byType(TakeTrayApp);

/// A stuck step ends the flow (and so runs its clean-up) instead of hanging.
const Timeout _testTimeout = Timeout(Duration(minutes: 6));

/// A pause after each copied chunk for the flow that cancels: a test video is
/// one chunk, so a 3-clip copy takes 12 s.
const int _slowCopyMs = 4000;

/// The copies reminder's notification id is this plus the reel's id
/// (`Notifier.COPIES_ID_BASE`).
const int _copiesIdBase = 1000;

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

/// A reel of test clips.
class _TestReel {
  _TestReel({required this.id, required this.name, required this.videos});

  final int id;

  /// `TakeTray Test <timestamp>`. Never printed.
  final String name;
  final List<InsertedVideo> videos;

  /// The clips as the recorder writes them (`volume:id`), in shooting order
  /// (the order they were inserted in).
  List<String> get labels => [
    for (final v in videos) '${v.volumeName}:${v.mediaStoreId}',
  ];
}

/// What a flow needs: the app, its repositories, the hooks and the test media.
class _Env {
  _Env({required this.media, required this.container});

  final TestMedia media;
  final ProviderContainer container;
  final EditorsHooks editors = EditorsHooks();
  final CopyHooks copy = CopyHooks();
  final TestBackground bg = TestBackground();

  /// The test reels made, for the clean-up.
  final List<int> reelIds = [];

  /// The copy folders seen, for the clean-up's check that they are empty.
  final Set<String> folders = {};

  ClipsRepository get clips => container.read(clipsRepositoryProvider);
  ReelsRepository get reels => container.read(reelsRepositoryProvider);
  MediaBridge get mediaBridge => container.read(mediaBridgeProvider);
  CopyBridge get copyBridge => container.read(copyBridgeProvider);
  EditSessionService get service => container.read(editSessionServiceProvider);

  /// The reel's session and copies now (a one-off read); the folder it uses
  /// is remembered for the clean-up.
  Future<EditState?> editState(int reelId) async {
    final state = await container
        .read(editSessionsRepositoryProvider)
        .editState(reelId);
    if (state != null) {
      folders.add(state.session.folderName);
    }
    return state;
  }

  /// The TakeTray-owned rows of exactly this copy folder.
  Future<List<FolderRow>> rowsIn(String folder) => copyBridge.ownRowsIn(folder);

  /// A new reel named `TakeTray Test <timestamp>` holding [count] new test
  /// clips, in the order they were made.
  Future<_TestReel> reelWithClips(int count) async {
    final name = 'TakeTray Test ${DateTime.now().millisecondsSinceEpoch}';
    final reel = await reels.create(name);
    reelIds.add(reel.id);
    final videos = await media.insertMany(count);
    final test = _TestReel(id: reel.id, name: name, videos: videos);
    await addToReel(test, videos);
    return test;
  }

  /// Tags [videos] (test videos only) into [reel]; the clips' ids, in order.
  Future<List<int>> addToReel(
    _TestReel reel,
    List<InsertedVideo> videos,
  ) async {
    final rows = <NewClip>[];
    for (final video in videos) {
      final row = await rowOf(mediaBridge, video);
      expect(row, isNotNull, reason: 'MediaStore has the test video');
      // Only a video in the test folder is ever added (D-77).
      expect(_isTestFolder(row!.relativePath), isTrue);
      expect(isUsable(row), isTrue, reason: 'finished, with a length');
      rows.add(newClipFrom(row, now: DateTime.now().toUtc(), zoneId: null));
    }
    if (videos.any((v) => !reel.videos.contains(v))) {
      reel.videos.addAll(videos.where((v) => !reel.videos.contains(v)));
    }
    return await clips.addNewClipsToReel(reel.id, rows);
  }
}

/// Whether [relativePath] is the test folder, ignoring case and slashes at
/// either end (the same match MediaStore queries make).
bool _isTestFolder(String relativePath) =>
    relativePath.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase() ==
    testFolder.toLowerCase();

/// Sets the app up, runs [body], and always cleans up at the end (Done
/// editing on every test reel, the copy folders, the test videos, the hooks,
/// the watched folders). Everything after the hooks were changed is inside
/// the `try`, so a failure while setting up still cleans up.
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

  // The flow's own failure: reported after the clean-up, which runs anyway.
  (Object, StackTrace)? failure;
  try {
    // Nothing is ever started: intents are recorded, and every editor looks
    // installed. Both are put back by the clean-up.
    await env.editors.recordIntents(true);
    await env.editors.allInstalled();
    await env.copy.setThrottleMs(0);
    await body(env);
  } on Object catch (error, stack) {
    failure = (error, stack);
  }
  await _cleanUp(env, restoreFolders, failure: failure);
}

/// The end of the flow. Each step runs even when one before it threw, then
/// the first error is thrown: the flow's own [failure] when there is one, so
/// a clean-up error never hides it.
Future<void> _cleanUp(
  _Env env,
  Future<void> Function() restoreFolders, {
  (Object, StackTrace)? failure,
}) async {
  var first = failure;
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run().timeout(const Duration(seconds: 60));
    } on Object catch (error, stack) {
      // The step's name and the error's type only (D-10).
      debugPrint('clean-up "$name" failed: ${error.runtimeType}');
      first ??= (error, stack);
    }
  }

  // Quick copies first: a copy still running (a failed Cancel flow) is
  // stopped at once, not after a long pause per chunk.
  await step('copy speed', () => env.copy.setThrottleMs(0));
  for (final reelId in List.of(env.reelIds)) {
    await step('done editing', () => _endEditing(env, reelId));
  }
  await step('copy folders empty', () async {
    var left = 0;
    for (final folder in env.folders) {
      left += (await env.rowsIn(folder)).length;
    }
    if (left > 0) {
      throw TestFailure(
        '$left test copy file(s) are still in the copy folders: delete them '
        "from TakeTray Dev's storage screen (Settings, Storage used by VN "
        'copies)',
      );
    }
  });
  await step('reminder', () async {
    // The mirror no longer holds the reels: their reminders go from the shade.
    await env.container.read(backgroundSyncProvider).flush();
  });
  await step('test reels', () async {
    for (final reelId in env.reelIds) {
      await env.reels.delete(reelId);
    }
  });
  await step('test videos', env.media.cleanUp);
  await step('editors hook', () async {
    await env.editors.recordIntents(false);
    await env.editors.clearInstalledOverride();
  });
  await step('watched folders', restoreFolders);
  if (first case (final error, final stack)) {
    Error.throwWithStackTrace(error, stack);
  }
}

/// Done editing on [reelId] through the app's own guarded delete: a copy that
/// still runs is stopped first (Done editing refuses a running one), and a
/// reel with no session needs nothing.
Future<void> _endEditing(_Env env, int reelId) async {
  final job = await env.copyBridge.current();
  if (job != null) {
    env.folders.add(job.folderName);
    if (job.reelId == reelId && job.state == CopyState.running) {
      await env.service.cancelCopy(job.jobId);
    }
  }
  if (await env.editState(reelId) != null) {
    await env.service.doneEditing(reelId);
  } else {
    // No session: a stopped or half-made copy job may still hold files.
    await env.service.beforeReelDelete(reelId);
  }
}

// ============================================================ finders

/// How many widgets [finder] matches now. Used instead of `expect(finder, …)`
/// so a failure prints a number, never the widgets (a tile could carry a name).
int _count(Finder finder) => finder.evaluate().length;

final Finder _dialog = find.byWidgetPredicate(
  (w) => w is TtDialog,
  description: 'TtDialog',
);

/// A [TtIconButton] by the label a screen reader gives it (it has no text).
Finder _iconButtonLabelled(String label) => find.byWidgetPredicate(
  (w) => w is TtIconButton && w.semanticLabel == label,
  description: 'TtIconButton labelled "$label"',
);

/// The editing banner of the reel's page (its key).
final Finder _banner = find.byKey(const ValueKey<String>('reel-edit-banner'));

/// [text] inside the editing banner.
Finder _inBanner(String text) =>
    find.descendant(of: _banner, matching: find.text(text));

/// The reel page's "New since you started editing" and "In your edit" headers
/// (their keys).
final Finder _newSection = find.byKey(
  const ValueKey<String>('reel-new-section'),
);
final Finder _inEditSection = find.byKey(
  const ValueKey<String>('reel-in-edit-section'),
);

/// [text] inside the section header [section].
Finder _inSection(Finder section, String text) =>
    find.descendant(of: section, matching: find.text(text));

/// The editor sheet's row of [editor] (its key).
Finder _editorRow(EditorApp editor) =>
    find.byKey(ValueKey<String>('editor-row-${editor.name}'));

/// "Not installed" inside [row].
Finder _notInstalledIn(Finder row) =>
    find.descendant(of: row, matching: find.text(_l10n.editorNotInstalled));

/// The clip picking screen, in either of its modes.
final Finder _pickScreen = find.byType(EditSelectScreen);

/// The "Copies deleted · {size} freed" snack, whatever the size.
final Finder _freedSnack = () {
  const mark = '\u0000';
  final parts = _l10n.doneEditingFreedSnack(mark).split(mark);
  return find.byWidgetPredicate(
    (w) =>
        w is Text &&
        (w.data?.startsWith(parts.first) ?? false) &&
        (w.data?.endsWith(parts.last) ?? false),
    description: 'the Copies deleted snack',
  );
}();

// ============================================================ steps

/// From the Reels tab, opens the page of [reel] and waits for its tiles.
Future<void> _openReel(PatrolIntegrationTester $, _TestReel reel) async {
  await $(TtNavPill).$(_l10n.navReels).tap();
  final card = $(TtReelCard).containing(reel.name);
  await waitFor($, () => card.exists, what: "the test reel's card on Reels");
  await card.tap();
  await waitFor(
    $,
    () => $(ReelDetailScreen).exists && $(ReelDetailScreen).$(reel.name).exists,
    what: 'the page of the test reel',
  );
  final tiles = find.descendant(
    of: find.byType(ReelDetailScreen),
    matching: find.byType(TtClipTile),
  );
  await waitFor(
    $,
    () => _count(tiles) == reel.videos.length,
    what: 'the ${reel.videos.length} test clips as tiles',
  );
}

/// On a reel's page: **Edit video**, **Select all**, **Continue**; waits for
/// the editor sheet of [count] clips.
Future<void> _pickAllAndContinue(PatrolIntegrationTester $, int count) async {
  await $(TtFab).tap();
  await waitFor(
    $,
    () =>
        _count(_pickScreen) == 1 &&
        _count(
              find.descendant(
                of: _pickScreen,
                matching: find.byType(TtClipTile),
              ),
            ) ==
            count,
    what: 'the picking screen with $count clips',
  );
  await $(
    find.descendant(
      of: _pickScreen,
      matching: find.widgetWithText(TtButton, _l10n.selectionSelectAll),
    ),
  ).tap();
  final next = find.byKey(const ValueKey<String>('edit-select-continue'));
  await waitFor(
    $,
    () => $.tester.widget<TtButton>(next).onPressed != null,
    what: 'Continue to be on once the clips are ticked',
  );
  await $(next).tap();
  await waitFor(
    $,
    () => _count(find.text(_l10n.editorSheetTitle(count))) == 1,
    what: 'the "Edit $count clips in…" sheet',
  );
}

/// On the space screen: **Copy {count} clips** (the space is checked first).
Future<void> _startCopyFromSpaceScreen(
  PatrolIntegrationTester $,
  int count,
) async {
  final start = find.widgetWithText(TtButton, _l10n.copyStart(count));
  await waitFor(
    $,
    () => _count(start) == 1,
    what: 'the space screen with "Copy $count clips"',
    timeout: const Duration(seconds: 60),
  );
  await $(start).tap();
}

/// A whole VN copy through the screens: [reel]'s page (the app must be on the
/// Reels tab), **Edit video** > **Select all** > **Continue** > **VN** >
/// **Copy 3 clips**, and the wait for "Ready for VN". Returns the folder.
Future<String> _startVnSession(
  PatrolIntegrationTester $,
  _Env env,
  _TestReel reel,
) async {
  await _openReel($, reel);
  await _pickAllAndContinue($, reel.videos.length);
  await $(_editorRow(EditorApp.vn)).tap();
  await _startCopyFromSpaceScreen($, reel.videos.length);
  await waitFor(
    $,
    () =>
        _count(
          find.descendant(
            of: find.byType(CopyReadyScreen),
            matching: find.text(_l10n.copyReadyTitle(_l10n.editorNameVn)),
          ),
        ) ==
        1,
    what: 'the "Ready for VN" screen',
    timeout: const Duration(seconds: 90),
  );
  final state = await env.editState(reel.id);
  expect(state, isNotNull, reason: 'the copy started a session');
  return state!.session.folderName;
}

/// Waits for a dialog titled [title], not asking about a name in its message.
Future<void> _waitForDialog(
  PatrolIntegrationTester $,
  String title, {
  required String what,
  Duration timeout = const Duration(seconds: 30),
}) => waitFor(
  $,
  () => _count(find.descendant(of: _dialog, matching: find.text(title))) == 1,
  what: what,
  timeout: timeout,
);

/// A "Mark {name} as {status}?" question (it comes a moment after the action
/// that offers it): waits for it and taps **Not now**.
Future<void> _answerMarkDialog(
  PatrolIntegrationTester $, {
  required String title,
  required String what,
}) async {
  await _waitForDialog($, title, what: what);
  await $(_dialog).$(_l10n.markStatusNotNow).tap();
  await waitFor(
    $,
    () => _count(_dialog) == 0,
    what: '$what to close on Not now',
  );
}

/// Waits until the window's keep-screen-on flag is [wanted] (the real flag,
/// read from the activity), for at most [timeout].
Future<void> _waitForFlag(
  PatrolIntegrationTester $,
  _Env env, {
  required bool wanted,
  required String what,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (await env.copy.keepScreenOnFlag() != wanted) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for: $what',
      );
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}

/// What the recorder holds, waiting (at most 15 s) until it holds something.
/// Each take empties it, so this returns the first non-empty take.
Future<List<RecordedIntent>> _takeIntents(
  PatrolIntegrationTester $,
  _Env env, {
  required String what,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (true) {
    final recorded = await env.editors.takeRecordedIntents();
    if (recorded.isNotEmpty) return recorded;
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out after 15 s waiting for: $what');
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}

/// After **Open VN**: either the launch was recorded (and not started), or,
/// on a phone with no VN, the app said "VN isn't installed" (no launcher
/// intent exists to record) and that question is closed with **Choose
/// another**, never **Open Play Store**.
Future<void> _expectOpenVnRecorded(PatrolIntegrationTester $, _Env env) async {
  final missing = _l10n.editorMissingTitle(_l10n.editorNameVn);
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (true) {
    final recorded = await env.editors.takeRecordedIntents();
    if (recorded.isNotEmpty) {
      expect(recorded.length, 1, reason: 'one launch');
      expect(recorded.single.package, EditorApp.vn.packageName);
      expect(recorded.single.data, isNull, reason: 'not the store');
      return;
    }
    if (_count(find.descendant(of: _dialog, matching: find.text(missing))) ==
        1) {
      debugPrint(
        'VN is not on this phone: Open VN could not be recorded '
        '(a hand check)',
      );
      await $(_dialog).$(_l10n.editorMissingChoose).tap();
      await waitFor($, () => _count(_dialog) == 0, what: 'the dialog to close');
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Open VN neither recorded a launch nor asked');
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}

/// Makes sure TakeTray Dev may post notifications, the way a user does: when
/// they are not allowed yet, Android's own question, answered "Allow".
Future<void> _allowNotifications(PatrolIntegrationTester $, _Env env) async {
  final bridge = env.container.read(backgroundBridgeProvider);
  if ((await bridge.notificationAccess()).granted) return;
  if (!(await bridge.notificationAccess()).canAsk) {
    throw TestFailure(
      "Notifications are blocked for TakeTray Dev: allow them in the phone's "
      'settings and run the flow again',
    );
  }
  final asked = bridge.requestNotificationAccess();
  final answered = await allowNotificationsInDialog($);
  final access = await asked.timeout(const Duration(seconds: 30));
  expect(
    answered && access.granted,
    isTrue,
    reason: 'notifications were allowed',
  );
}

/// Posts the copies reminder of [reelId] through the debug trigger. The app
/// mirrors its sessions to Android a moment after they change, so the trigger
/// is asked again (for at most 30 s) until the mirror holds the reel.
Future<void> _postReminder(
  PatrolIntegrationTester $,
  _Env env,
  int reelId,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (true) {
    await env.container.read(backgroundSyncProvider).flush();
    try {
      await env.bg.showCopiesReminderNow(reelId);
      return;
    } on PlatformException catch (error) {
      if (error.code != 'no-reminder' || DateTime.now().isAfter(deadline)) {
        throw TestFailure('The reminder was not posted: ${error.code}');
      }
    }
    await $.tester.pump(const Duration(milliseconds: 500));
  }
}
