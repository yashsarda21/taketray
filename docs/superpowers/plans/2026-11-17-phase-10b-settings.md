# Phase 10B: Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every setting the app already reads can be changed in a full Settings screen. The user can choose which folders Shooting mode watches, make and restore a backup, and send the error log through Android's share sheet. Done when the build design's Phase 10 is complete: first launch (10A) plus Settings, help and the error log.

**Architecture:**
- **Data:**
  - two new user settings (`stillReminderEnabled`, `copiesReminderEnabled`), read by `BackgroundSync` and the in-app "Still shooting?" prompt;
  - `lastExport` as phone state;
  - `BackupService` imports keep phone state, run on `MediaWorkQueue`, and are refused while a copy job runs.
- **Native:** one new Pigeon API, `FilesHostApi` (`pigeons/files_api.dart`), on Android platform APIs only:
  - share a file through a `FileProvider` (`ACTION_SEND` in a chooser);
  - save a document (`ACTION_CREATE_DOCUMENT`) and open one (`ACTION_OPEN_DOCUMENT`);
  - learn a folder's path (`ACTION_OPEN_DOCUMENT_TREE`, keeping no grant);
  - read the app's version and the Android release.
- **Screens:** `lib/features/settings/`:
  - the full Settings screen, in the prototype's order;
  - Watched folders;
  - Export and import;
  - "Send error log" as a Help row.

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; Drift (schema v2, unchanged); go_router; gen-l10n; alchemist goldens (app screen goldens macOS-only, D-97); Pigeon 29.0.11; Kotlin with platform APIs (`androidx.core` `FileProvider` only if already on the classpath); Robolectric 4.17 (`tool/test_android`); Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-11-15-phase-10-onboarding-settings-design.md` (the 10B part, owner-approved 2026-11-15, including the builder-check answers). Visual source: `design/prototype/assets/screens.js` (`routes.settings`, `routes.watched`, `routes.backup`, `routes['notif-help']`, `routes['vn-storage']`), `app.js` (`setToggle`, `watchToggle`, `exportData`, `importData`, `allowAccess`). Phase 10 items: `docs/later.md` "Phase 10 (onboarding and settings)".

## Global Constraints

- **Branch:** `phase-10b-settings`, stacked on `phase-10a-first-launch`, in worktree `.claude/worktrees/phase-10b`. Merge `phase-10a-first-launch` in whenever it changes (its phone run is pending). The PR goes to `main` after 10A's PR has merged.
- **Dependencies:** no new pub package. No new Gradle dependency, except declaring `androidx.core:core` explicitly if `FileProvider` needs it on the compile classpath, at the version Gradle already resolves.
- **Pigeon:** one new file, `pigeons/files_api.dart`, generated with the repo's existing command.
- **Release permissions unchanged:** `tool/check_release_permissions` must end `RELEASE PERMISSIONS OK`. The `FileProvider` is `exported="false"` with `grantUriPermissions="true"`, and its paths cover only `cache/shared/`. No `INTERNET`, no storage permission. Reading or writing a user-chosen document needs none.
- **Schema stays v2. Backup schema stays version 1.**
  - The three existing setting keys stay required.
  - `stillReminderEnabled` and `copiesReminderEnabled` are read leniently: missing means default `true`.
- **An import replaces only `SettingsRepository.exportedKeys`.** It keeps every phone-state key except `shootingMode` and `copyJobPlan`, which it removes.
- **Logs (D-10):** never folder names or paths, file names, URIs, reel names or the phone maker. Counts, types and key names only. The error log a user sends is the existing log files, joined: nothing new is added to them.
- **No existing behaviour changes for a user who changes no setting.** Every existing test stays green.
- **UI:**
  - Design tokens only (`tool/check_styles`); every string through `app_en.arb`; 48 dp targets; semantics labels.
  - Text scaling to 200 %, light and dark.
  - Copy is the prototype's, verbatim. New copy is given in the task.
  - Times follow the phone's 12/24-hour setting (`MediaQuery.alwaysUse24HourFormatOf`).
- **Strict TDD:**
  - Write **all** of a change's edge-case tests red first, record the RED run, then implement once. Never draft code and tests together.
  - Mutation-check the key lines, one mutant at a time, naming the test that kills each. A surviving mutant gets a test in the same task.
  - Never weaken a test.
- **Models:**
  - Opus: the implementers of Task 4 (native files bridge) and Task 7 (Export and import).
  - Sonnet: the implementers of Tasks 2, 3, 5, 6, 8 and 9; all fixes; every task review and re-review.
  - Opus: the whole-phase final review and its re-review (resume the same reviewer).
  - Never Haiku. Always pass the model.
- **Review findings:** fix Critical and Important now. Park Minors for one batch before the final review.
- **Docs, every task:**
  - its D-number in `docs/decisions.md` (Task 2 D-145 … Task 9 D-152);
  - `docs/flow.md`;
  - its section of `docs/learn/phase-10b-settings.md`;
  - `docs/later.md`: delete what is done.
- **Phone rules:**
  - Only `app.taketray.dev` runs tests. Never uninstall or clear `app.taketray`.
  - Logcat with `--pid=` only. No screenshots. Never list shared storage or read other apps' files.
  - Patrol uses only `Movies/TakeTray Test/`.
  - Pass `-s RZCY80PHWCZ`.
  - After every Patrol run: build debug, `install -r`, `pm clear app.taketray.dev`.
  - Run each Patrol file once per round. No test waits on Android's scheduler.
- **The phone is the very last step** (owner, 2026-11-16).
  - Write and review Task 9's Patrol files with no device.
  - Finish the Minors batch, the final review and its fixes.
  - Only then ask for the S24 once. If 10A's phone run is still pending, run both phases in that one session.
- **Git:**
  - Push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push. Never change git config.
  - Commits end `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The PR ends `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
  - Merging needs the owner's go.

## Review Focus

1. **An import fails or is interrupted.** A bad file, a newer format, a file of tens of MB, the app closed during the import, or a scan already running when it starts. Expected: nothing changes unless the import commits; no scan writes into the half-imported data; onboarding is not re-run afterwards; and "X of Y clips found" never shows for an import that did not happen. (Tasks 3, 7.)
2. **A watched folder set is changed while Shooting mode is on.** Turning WhatsApp Video on pulls in only videos that arrive after the change, never its whole history. Turning every folder off is allowed, and the user is told nothing will be found. A folder that has disappeared from the phone can still be turned off. (Task 6.)
3. **The user leaves for Android's own screens and comes back.** These are the document picker, the share sheet, the folder picker and the app's settings page. Cancelling any of them changes nothing and shows no error. Returning after Android killed TakeTray in the background does not crash. (Tasks 4, 6, 7, 8.)
4. **The switches reach the background.** Evening reminder off, the still-shooting reminder off and the copies reminder off each stop their notification, even when the app is not opened again. An evening time of 00:00 or 23:59 is kept exactly. (Tasks 2, 5.)
5. **The error log the user sends:** no log yet, one file, two files, or a file being written while it is joined. The shared file holds only what the logs hold, and never a path, reel name or video name. (Task 8.)

---

### Task 1: Scope and docs (controller, no review)

**Files:**
- Create: the branch and worktree.
- Modify: `docs/decisions.md` (D-144).
- Create: `docs/learn/phase-10b-settings.md` (stub with 10A's shape: "How to read this guide", Contents, sections 2–9).
- Modify: `docs/later.md` (point each Phase 10 item at its 10B task).
- Add: this plan.

- [ ] **Step 1:** Create `phase-10b-settings` from `phase-10a-first-launch` in `.claude/worktrees/phase-10b`.
- [ ] **Step 2:** Write D-144. It records:
  - the 10B scope;
  - the stacking on 10A and the merge order;
  - the owner's answer that chat-app folders are watchable with a warning;
  - the design's builder-check calls: import keeps phone state; refuse while copying; backup schema stays v1; Watched folders without full access; the Home-tip-style "Got it" pattern is not used here;
  - the D-number of each task.
- [ ] **Step 3:** Commit `docs: Phase 10B scope and D-144`.

---

### Task 2: The two new settings reach the background

**Model:** Sonnet. **D-145.**

**Files:**
- Modify:
  - `app/lib/domain/models/app_settings.dart`
  - `app/lib/data/repositories/settings_repository.dart`
  - `app/lib/data/repositories/phone_state_repository.dart`
  - `app/lib/data/background/background_sync.dart`
  - `app/lib/features/notifications/view_models/still_shooting_prompt.dart`
  - `app/lib/data/backup/backup_format.dart`
- Test:
  - `app/test/data/repositories/settings_repository_test.dart`
  - `app/test/data/repositories/phone_state_repository_test.dart`
  - `app/test/data/background/background_sync_test.dart`
  - `app/test/features/notifications/view_models/still_shooting_prompt_test.dart`
  - `app/test/data/backup/backup_format_test.dart`

**Interfaces:**
- Produces:
  - `AppSettings`: `@Default(true) bool stillReminderEnabled` and `@Default(true) bool copiesReminderEnabled`.
  - `SettingsRepository`:
    - keys `stillReminderEnabledKey = 'stillReminderEnabled'` and `copiesReminderEnabledKey = 'copiesReminderEnabled'`, both in `exportedKeys`;
    - `save` writes all five in one transaction;
    - a corrupt value's warning is logged **once per key per repository instance**, not on every `watch` emission (later.md item).
  - `PhoneStateRepository`:
    - key `lastExportKey = 'lastExport'`;
    - `Future<DateTime?> lastExport()` (UTC millis as JSON int; unreadable is null);
    - `Future<void> recordExport(DateTime at)`.
  - `BackgroundSync._read`:
    - `stillReminderEnabled: settings.stillReminderEnabled`;
    - `copiesReminders`: an empty list when `!settings.copiesReminderEnabled`.
  - `StillShootingPrompt`: shows nothing when `stillReminderEnabled` is false.
  - Backup format:
    - writes both new keys;
    - reads them leniently: a missing key is `true`, a wrong type is refused like the other keys (`BackupProblem.invalidData`);
    - stays at version 1.

- [ ] **Step 1: Write the failing tests:**
  - **Round trip:**
    - five-setting `save`/`load`;
    - a v1 backup without the new keys decodes to both `true`;
    - a backup with `"stillReminderEnabled": "yes"` is refused as `invalidData`.
  - **Corrupt value:** a corrupt `eveningReminderMinutes` row read through `watch` three times (three emissions) logs one warning.
  - **`lastExport`:** none → null; record → read back the same UTC instant; corrupt → null with the key name logged.
  - **`BackgroundSync`:**
    - still switch off → the written state has `stillReminderEnabled: false`;
    - copies switch off with two sessions holding copies → `copiesReminders: []`;
    - switching back on → the two reminders return.
  - **`StillShootingPrompt`:** due, but switch off → no prompt; switch on → prompt as before.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/data test/features/notifications`. Expected: FAIL.
- [ ] **Step 3: Implement.** Regenerate freezed and Riverpod code.
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - lenient read turned strict (the v1 test fails);
  - `copiesReminders` kept when off;
  - the warn-once guard removed.
- [ ] **Step 6: Docs and commit** `feat(settings): still-shooting and copies reminder switches reach the background`. D-145; flow.md "Background bridge" and "Backup format"; guide §2; later.md loses "VN copies reminder switch" and "Remind me to turn it off feeds stillReminderEnabled".

---

### Task 3: Imports keep phone state, wait for media work, and refuse while copying

**Model:** Sonnet. **D-146.**

**Files:**
- Modify:
  - `app/lib/data/backup/backup_service.dart`
  - `app/lib/data/media/media_work_queue.dart` (only if a helper is needed)
- Create: `app/lib/data/backup/backup_actions.dart`
- Test:
  - `app/test/data/backup/backup_service_test.dart`
  - `app/test/data/backup/backup_actions_test.dart`

**Interfaces:**
- Consumes:
  - `MediaWorkQueue.run`;
  - `MediaVerifier.verifyAll() → VerifyOutcome{found, missing, skipped}`;
  - `PhoneStateRepository.copyJobPlan()` and `recordExport`;
  - `guarded`.
- Produces:
  - `BackupService._replaceAll` deletes only the rows whose key is in `SettingsRepository.exportedKeys`, plus `shootingMode` and `copyJobPlan`. Every other `settings` row survives an import. That includes `onboardingDone`, `introPlayed`, `homeTipSeen`, `lastExport`, `notificationsAsked`, `folderTipSeen`, `mediaAccessWasFull`, the volume versions and the rematch windows.
  - `sealed class ImportResult`, with these cases:
    - `ImportDone(ImportSummary summary, int found, int total)`;
    - `ImportRefused(BackupProblem problem)`;
    - `ImportBusyCopying()`;
    - `ImportTooLarge()`.
  - `@riverpod BackupActions backupActions(Ref ref)` with:
    - `Future<String> exportJson()`: `BackupService.exportJson`, then `recordExport(now)` after the file is saved. The save itself is the screen's, Task 7.
    - `Future<ImportResult> importJson(String json)`:
      1. Over **20 MB** of UTF-16 code units → `ImportTooLarge`.
      2. `copyJobPlan() != null` → `ImportBusyCopying`, with nothing read.
      3. Decode in `Isolate.run`. A `BackupException` → `ImportRefused`.
      4. `MediaWorkQueue.run(() => service.importDecoded(data))`, so no scan, verify or grant clean-up overlaps it.
      5. Then `MediaVerifier.verifyAll()` through `guarded`; a failure counts `found` as 0 and logs the type.
      6. `ImportDone`.
    - `Future<bool> hasCopies()`: any `vn_copies` row, so the screen can warn.
  - `BackupService.importDecoded(BackupData data) → Future<ImportSummary>` is split out of `importJson`. `importJson` keeps working for existing callers and tests.

- [ ] **Step 1: Write the failing tests:**
  - **What an import keeps:**
    - it keeps `onboardingDone`, `introPlayed`, `homeTipSeen`, `lastExport`, `notificationsAsked`, `folderTipSeen` and `mediaAccessWasFull` (later.md M-9), and one volume-version and one rematch row;
    - it removes `shootingMode` and `copyJobPlan`;
    - it replaces the five exported keys.
  - **Copy plan saved** → `ImportBusyCopying`, and the database is byte-for-byte unchanged (row counts plus settings dump).
  - **Bad files:**
    - not JSON → `ImportRefused(notJson)`;
    - a newer version → `ImportRefused(newerVersion)`;
    - over 20 MB → `ImportTooLarge` without decoding.
  - **Queue order:** a scan queued on `MediaWorkQueue` before the import finishes before the import's transaction starts. Pin this with a gate `Completer` and an event log.
  - **Verify:** the verify fails → `ImportDone` with `found: 0`.
  - **`exportJson`:** records `lastExport` once.
- [ ] **Step 2: Run** `../tool/flutter test test/data/backup`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - delete every `settings` row again (the keep test fails);
  - the copy-plan guard removed;
  - the import run outside the queue (the order test fails).
- [ ] **Step 6: Docs and commit** `feat(backup): imports keep phone state, wait for media work and refuse while copying`. D-146; flow.md "Backup import"; guide §3; later.md loses:
  - "Backup import must run through MediaWorkQueue";
  - "A backup import resets mediaAccessWasFull";
  - "Phase 10's import must not run beside the grant clean-up";
  - "A backup import wipes the copy plan and the editing rows";
  - the decode-off-isolate part of "The Export/Import buttons".

---

### Task 4: The native files bridge

**Model:** Opus. **D-147.**

**Files:**
- Create:
  - `app/pigeons/files_api.dart`
  - generated `app/lib/platform/files_api.g.dart` and `app/android/app/src/main/kotlin/app/taketray/files/FilesApi.g.kt`
  - `app/lib/platform/files_bridge.dart`
  - `app/android/app/src/main/kotlin/app/taketray/files/FilesHostApiImpl.kt`
  - `res/xml/file_paths.xml`
  - `app/test/support/fake_files_bridge.dart`
- Modify:
  - `AndroidManifest.xml` (the `<provider>`)
  - `MainActivity.kt` (set-up, and `onActivityResult` routing like `media` and `editors`)
- Test:
  - `app/android/app/src/test/kotlin/app/taketray/files/FilesHostApiImplTest.kt`
  - `ManifestTest.kt`
  - `app/test/platform/files_bridge_test.dart`

**Interfaces:**
- Produces:
  - **Pigeon** `@HostApi() abstract class FilesHostApi`, every method `@async`:
    - `void shareFile(String path, String mimeType, String subject, String text)`: the path must be inside `cacheDir/shared/`, otherwise it throws `invalid_path`.
    - `String? saveDocument(String suggestedName, String mimeType, String text)`: create, then write UTF-8; null when cancelled.
    - `String? openDocument(List<String> mimeTypes, int maxBytes)`: returns the text; null when cancelled; throws `too_large` over `maxBytes`.
    - `String? pickFolder()`: the chosen folder's MediaStore relative path, such as `DCIM/Camera` or `Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video`. It keeps no grant (no `takePersistableUriPermission`). Null when cancelled; throws `unsupported_folder` for a tree that is not on the primary or an SD volume's `document` tree.
    - `AppInfoMsg appInfo()`: `versionName` and `androidRelease` (`Build.VERSION.RELEASE`).
  - **Dart** `abstract interface class FilesBridge` mirrors those as `Future`s, with `FileBridgeException(FilesProblem problem)`, where `enum FilesProblem { invalidPath, tooLarge, unsupportedFolder, failed }`. Also `filesBridgeProvider` (kept alive) and `FakeFilesBridge` for tests (records calls, scripted answers).
  - **FileProvider:**
    - authority `${applicationId}.files`, so the dev and release builds never clash;
    - `<cache-path name="shared" path="shared/"/>`.
  - **Activity results:**
    - request codes `4101` save, `4102` open, `4103` folder;
    - one request at a time: a second call while one waits throws `busy`, like `MediaBridge.pickVideos`;
    - a result after the engine was re-created answers nothing, and the call is dropped (log the type).

- [ ] **Step 1: Write the failing tests:**
  - **Robolectric, `shareFile`:**
    - the chooser wraps `ACTION_SEND` with `EXTRA_STREAM` set to a `content://<app>.files/shared/…` URI, `FLAG_GRANT_READ_URI_PERMISSION`, and the subject and text;
    - a path outside `cache/shared` → `invalid_path`.
  - **Robolectric, `saveDocument`:**
    - the request is `ACTION_CREATE_DOCUMENT` with the name and type;
    - OK writes the exact bytes (Robolectric content resolver);
    - cancel → null.
  - **Robolectric, `openDocument`:**
    - reads UTF-8;
    - `maxBytes + 1` → `too_large`;
    - cancel → null.
  - **Robolectric, `pickFolder`:** tree URIs mapped to their relative paths:
    - `content://com.android.externalstorage.documents/tree/primary%3ADCIM%2FCamera` → `DCIM/Camera`;
    - `primary%3A` → `''` (the root);
    - an SD card id → its path;
    - a `downloads` provider tree → `unsupported_folder`.

    No `takePersistableUriPermission` call.
  - **Robolectric, the rest:**
    - `busy` on a second call;
    - `appInfo` returns the package's `versionName`.
  - **Manifest:** the provider is not exported, grants URI permissions, and its authority ends `.files`.
  - **Dart:** `files_bridge_test` maps each `PlatformException` code to its `FilesProblem`.
- [ ] **Step 2: Run** `tool/test_android` and `../tool/flutter test test/platform`. Expected: FAIL.
- [ ] **Step 3: Implement.** Regenerate Pigeon with the repo's command (`tool/check_generated` must pass).
- [ ] **Step 4: Run** `tool/check` → `ALL CHECKS PASSED`; `tool/flutter build apk --release` then `tool/check_release_permissions` → `RELEASE PERMISSIONS OK`. Run `./gradlew :app:clean` after mutation runs.
- [ ] **Step 5: Mutation checks:**
  - the shared-path guard removed;
  - `takePersistableUriPermission` added;
  - the `maxBytes` check `>` changed to `>=` (pin the boundary: exactly `maxBytes` is allowed).
- [ ] **Step 6: Docs and commit** `feat(android): files bridge for sharing, saving, opening and choosing folders`. D-147; flow.md "Files bridge"; guide §4.

---

### Task 5: The full Settings screen

**Model:** Sonnet. **D-148.**

**Files:**
- Modify:
  - `app/lib/features/settings/views/settings_screen.dart` (split into row widgets under `views/settings_rows/` if it grows past about 300 lines)
  - `app_en.arb`
- Create: `app/lib/features/settings/view_models/settings_controller.dart`
- Test:
  - `app/test/features/settings/view_models/settings_controller_test.dart`
  - `app/test/features/settings/views/settings_screen_test.dart`
  - goldens

**Interfaces:**
- Consumes:
  - `SettingsRepository` (`watch`, `save`);
  - `MediaAccessController` (`allow()`, state `MediaAccessView`);
  - `NotificationAccessController.allow()`;
  - `copiesSummaryProvider`;
  - `PhoneStateRepository.lastExport()`;
  - `FilesBridge.appInfo()` (Task 4);
  - `Routes.notificationsHelp` and `Routes.copiesStorage`;
  - new `Routes.watchedFolders = '/settings/watched-folders'` (Task 6) and `Routes.backup = '/settings/backup'` (Task 7). Add both route constants here, with stand-in screens that Tasks 6 and 7 fill in.
- Produces: `@riverpod class SettingsController`, state `AsyncValue<AppSettings>` from `watch()`, with:
  - `setEvening(bool)`;
  - `setEveningMinutes(int)`, which throws `ArgumentError` outside 0..1439 before saving;
  - `setStillReminder(bool)`;
  - `setCopiesReminder(bool)`.

  Each one is a read-modify-save of the latest settings, serialised so two quick toggles never lose one.
- **Screen rows**, in the prototype's order and with its copy:

  | Group | Row | Details |
  |---|---|---|
  | Shooting mode | Remind me to turn it off | "If Shooting mode stays on for 14 days", switch |
  | Reminders | Evening reminder | "{time}, only if clips are waiting", switch |
  | Reminders | Reminder time | only while the evening reminder is on; opens `showTimePicker` and saves the picked minutes |
  | Reminders | VN copies reminder | "3 days after copying, if copies are still there", switch |
  | Clips | Watched folders | the watched folder names joined with ", " or "None"; opens `Routes.watchedFolders` |
  | Clips | Storage used by VN copies | existing row |
  | Help | Notifications not arriving? | existing row |
  | Help | Send error log | Task 8 adds the action; here the row shows only "Logs from this phone, to send by email or chat" |
  | Your data | Export and import | "Last backup: {date}" or "No backup yet"; opens `Routes.backup` |
  | Permissions | Video access | "All videos" with a check; "Some videos only · Manual mode" with a tonal **Allow all**; or "Not allowed" with a tonal **Allow** |
  | Permissions | Notifications | existing row |
  | About | Your videos never leave your phone | "No account, no cloud, no ads. TakeTray only stores which clips are in which reel." |
  | About | TakeTray | "Version {versionName}"; while `appInfo` is unknown or failed, "Version" alone |

  - Times use the phone's 12/24-hour setting.
  - The "Send error log" title is new copy.
  - Video access buttons call `MediaAccessController.allow()`.

- [ ] **Step 1: Write the failing tests:**
  - **Controller:**
    - two toggles in the same frame both persist;
    - `setEveningMinutes(0)` and `(1439)` are kept exactly;
    - `-1` and `1440` throw and save nothing.
  - **Screen:**
    - the group order matches the prototype;
    - the time row is hidden when the evening reminder is off;
    - the subtitle reads "21:00, only if…" in 24-hour and "9:00 PM, only if…" in 12-hour;
    - the picked time is saved;
    - the three Video access looks, and each button calls `allow()` once on a double tap;
    - "Last backup" shows the date, or "No backup yet";
    - the watched-folder subtitle shows names, or "None" for an empty list;
    - the version shows, or plain "Version" on failure.
  - **Goldens:** access full, Manual and denied; evening on and off; light and dark; 2× text.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4:** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - the read-modify-save queue removed (the two-toggles test fails);
  - the 0..1439 guard `<=` changed to `<`.
- [ ] **Step 6: Docs and commit** `feat(settings): the full Settings screen`. D-148; flow.md "Settings"; guide §5; later.md loses:
  - "The Settings screen grows around the interim rows";
  - "Storage used by VN copies moves into the full Settings screen";
  - "The reminder-time form must keep eveningReminderMinutes within 0 to 1439";
  - "When the Settings screen watches SettingsRepository.watch()".

---

### Task 6: Watched folders

**Model:** Sonnet. **D-149.**

**Files:**
- Create:
  - `app/lib/domain/rules/chat_folders.dart`
  - `app/lib/features/settings/view_models/watched_folders_controller.dart`
  - `app/lib/features/settings/views/watched_folders_screen.dart`
- Modify: the stand-in route from Task 5, and `app_en.arb`.
- Test:
  - `app/test/domain/rules/chat_folders_test.dart`
  - `app/test/features/settings/view_models/watched_folders_controller_test.dart`
  - `app/test/features/settings/views/watched_folders_screen_test.dart`
  - goldens

**Interfaces:**
- Consumes:
  - `MediaBridge.videoFolders()`, `browseFolders()` (which already hides `Movies/TakeTray/` and WhatsApp's Sent folders);
  - `SettingsRepository`;
  - `MediaAccessController`;
  - `FilesBridge.pickFolder()` (Task 4).
- Produces:
  - `bool isChatFolder(String relativePath)`: true when any path segment, compared case-insensitively, is one of `WhatsApp`, `WhatsApp Business`, `com.whatsapp`, `com.whatsapp.w4b`, `Telegram`, `org.telegram.messenger`, `Signal`, `org.thoughtcrime.securesms`, `Messenger`, `com.facebook.orca`, `Snapchat` or `com.snapchat.android`.
  - `@riverpod class WatchedFoldersController`. Its state is `WatchedFoldersView`:
    - `List<WatchedRow> rows`, where each row has `relativePath`, `name`, `videoCount` (null when unknown), `watched`, `chat` and `gone`;
    - `bool fullAccess`.

    Rows come from:
    - every `BrowseFolder` on the phone (needs full access);
    - plus every watched path not on the phone, marked `gone: true` with an unknown count.

    Without full access, only the watched paths show.

    Methods:
    - `setWatched(String relativePath, bool)`: read-modify-save, serialised; keeps the list order stable and without duplicates.
    - `addFolder()`: `pickFolder()`. A new path is watched and added. A path already listed just turns on. A cancel does nothing. `unsupportedFolder` → the screen's snack "Choose a folder on this phone or its SD card."
- Screen (`routes.watched`):
  - the info bar "While Shooting mode is on, new videos saved in these folders go to To tag.";
  - rows with folder icons: `photo_camera` for `DCIM/Camera`, `folder` otherwise;
  - each row: name, then path · "{n} videos", with a switch;
  - a chat row adds the warning line "Clips from chat apps are dated when they arrived. Busy groups and forwards land in To tag too.";
  - a gone row says "Not on this phone now";
  - "Add a folder";
  - the pro-camera tip, verbatim;
  - without full access, a banner "Allow all videos to see your other folders" with **Allow all**;
  - when no folder is watched, an extra line under the info bar: "No folder is watched, so Shooting mode finds no new videos."

  **Design-system items (later.md):** the rows use `.li.tall` (a boxed icon, two lines). Add the `TtListRow` tall variant if the existing row cannot draw it. Fix the disabled-on `TtSwitch` tick opacity if a switch here is ever disabled. Add `.ib.tonal` only if a screen in this phase needs it. Each one gets package goldens (macOS) and a Widgetbook use case. List the changed package goldens for the CI regeneration. later.md loses whichever of the three are done.

  **No baseline change is needed:** baselines are per volume generation, so videos already in a newly watched folder sit below the baseline and are never pulled in. Pin that with a test on the scanner, then say so in D-149.

- [ ] **Step 1: Write the failing tests:**
  - **`isChatFolder` table:**
    - true for the WhatsApp Video, WhatsApp Business, Telegram, Signal, Messenger and Snapchat paths;
    - false for `DCIM/Camera`, `Movies/Instagram`, `Pictures/Signals` and `Download`.
  - **Controller:**
    - the rows merge, with a gone path shown;
    - limited access shows only the watched rows;
    - two quick toggles both persist;
    - turning off the last folder saves an empty list;
    - `addFolder` with a new path, an existing path, a cancel, and `unsupportedFolder`.
  - **Scanner** (`media_scanner_test`): Shooting mode on, a folder with old videos (generation below the baseline) gets watched, and the next scan adds 0 clips; a new video there after the change is added.
  - **Screen:** the chat warning on the WhatsApp row only; the gone row; the access banner; the empty-list line.
  - **Goldens:** full access with a chat row; limited; light and dark; 2× text.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4:** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - `isChatFolder` matching substrings instead of whole segments (`Pictures/Signals` fails);
  - gone rows dropped;
  - duplicate paths allowed.
- [ ] **Step 6: Docs and commit** `feat(settings): watched folders, chat apps included`. D-149 (with the chat list); flow.md "Watched folders"; guide §6; later.md loses "Automatic friends' and device folders" (now hand-chosen) and "Keep Movies/TakeTray/ out of the Phase 10 watched-folder chooser".

---

### Task 7: Export and import

**Model:** Opus. **D-150.**

**Files:**
- Create:
  - `app/lib/features/settings/views/backup_screen.dart`
  - `app/lib/features/settings/view_models/backup_controller.dart`
- Modify: `app_en.arb`.
- Test:
  - `app/test/features/settings/view_models/backup_controller_test.dart`
  - `app/test/features/settings/views/backup_screen_test.dart`
  - goldens

**Interfaces:**
- Consumes:
  - `BackupActions` (`exportJson`, `importJson → ImportResult`, `hasCopies`; Task 3);
  - `FilesBridge` (`saveDocument`, `openDocument`; Task 4);
  - `PhoneStateRepository.lastExport()`.
- Produces: `@riverpod class BackupController`, state `BackupState { DateTime? lastExport; bool busy; }`, with:
  - `Future<ExportOutcome> export()`, giving `saved`, `cancelled` or `failed`;
  - `Future<ImportResult?> importFrom()`, which is null when the picker was cancelled.

  A second call while `busy` does nothing.
- **Export:**
  - name `taketray-backup-<yyyy-MM-dd>.json`, in the phone's local date;
  - type `application/json`;
  - `recordExport` only after `saveDocument` returns a URI;
  - snacks: "Backup saved", or "Couldn't save the backup." A cancel shows nothing.
- **Import:**
  1. A confirm dialog: "Import a backup?" / "Importing replaces everything in TakeTray now. Your videos are not touched." When `hasCopies()` is true, it adds "VN copies already on this phone stay there and show on the VN copies screen, where you can delete them." Buttons **Import** and **Cancel**.
  2. Then `openDocument(['application/json', 'text/plain', '*/*'], 20 MB)`, then `importJson`.
  3. The result dialog:
     - `ImportDone`: "Backup imported" / "{found} of {total} clips found.";
     - `ImportBusyCopying`: "Copying is still running. Try again when it finishes.";
     - `ImportRefused(notJson | notTakeTray)`: "This file isn't a TakeTray backup.";
     - `ImportRefused(newerVersion)`: "This backup is from a newer TakeTray. Update the app, then try again.";
     - `ImportRefused(invalidData)`: "This backup is damaged, so nothing was changed.";
     - `ImportTooLarge` and `tooLarge`: "This file is too big to be a TakeTray backup."
- **Screen:** as `routes.backup`, with both sections, "Last backup: {date}" or "No backup yet", and the "Moving to a new phone?" callout. While busy, both buttons are disabled and a `TtProgress` shows in the busy section.

- [ ] **Step 1: Write the failing tests:**
  - **Export:**
    - saved → `lastExport` recorded and the snack shows;
    - cancelled → nothing recorded, no snack;
    - failed → the error snack;
    - the file name follows the local date at 23:59 and at 00:01 (`FixedClock` with a zone).
  - **Import:**
    - confirm, then each `ImportResult` → its dialog text;
    - cancelling the confirm never opens the picker;
    - cancelling the picker shows nothing;
    - `hasCopies` true → the extra sentence;
    - double taps start one job.
  - **Goldens:** the screen, the confirm with copies, and the result dialog; light and dark; 2× text.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4:** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - `recordExport` before the save;
  - the busy guard removed;
  - the copies sentence always shown.
- [ ] **Step 6: Docs and commit** `feat(settings): export and import a backup`. D-150; flow.md "Export and import"; guide §7; later.md loses "Import and editing sessions" and the rest of "The Export/Import buttons".

---

### Task 8: Send error log

**Model:** Sonnet. **D-151.**

**Files:**
- Create: `app/lib/core/logging/log_bundle.dart`, `app/lib/features/settings/view_models/send_log.dart`
- Modify: the Settings Help row (Task 5), and `app_en.arb`.
- Test: `app/test/core/logging/log_bundle_test.dart`, `app/test/features/settings/view_models/send_log_test.dart`

**Interfaces:**
- Consumes:
  - `LogFileSink` file naming (`taketray-<i>.log` in the support directory);
  - `FilesBridge.shareFile` and `appInfo` (Task 4);
  - `path_provider`'s `getTemporaryDirectory` (the cache).
- Produces:
  - `Future<File?> bundleLogs(Directory logDir, Directory cacheDir, DateTime now)`:
    - joins `taketray-1.log` then `taketray-0.log` (oldest first; missing files are skipped) into `cacheDir/shared/taketray-log-<yyyy-MM-dd-HHmm>.txt`;
    - first deletes any older bundle in `shared/`;
    - returns null when both files are missing or empty;
    - reads each file whole at once, so a write during the join is either in or out, never half a line.
  - `@riverpod SendLog sendLog(Ref ref)` with `Future<SendLogOutcome> send()`, giving `shared`, `nothing` or `failed`:
    - subject "TakeTray error log";
    - text "TakeTray {version} on Android {release}" (nothing else about the phone);
    - mime `text/plain`.
  - **The Help row:** "Send error log" / "Logs from this phone, to send by email or chat".
    - Tap → `send()`.
    - `nothing` → snack "Nothing to send yet".
    - `failed` → snack "Couldn't open the share menu on this phone."
    - One tap at a time.

- [ ] **Step 1: Write the failing tests:**
  - **Bundle:**
    - no files → null;
    - an empty `-0` → null;
    - only `-0`;
    - both, in the order `-1` then `-0`;
    - an older bundle is deleted;
    - the name follows `now`;
    - the bundle's bytes are exactly the two files' bytes joined.
  - **Send:**
    - shared → `shareFile` is called with the bundle's path, the subject and the text;
    - `appInfo` failed → the text says "TakeTray on Android" without a version;
    - `shareFile` throws → `failed`.
  - **Row:** the three snacks; a double tap shares once.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4:** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - order `-0` then `-1`;
  - the old-bundle delete removed;
  - empty treated as something to send.
- [ ] **Step 6: Docs and commit** `feat(settings): send the error log through the share sheet`. D-151; flow.md "Error log"; guide §8.

---

### Task 9: Patrol flows and the hand checks (no device)

**Model:** Sonnet. **D-152.**

**Files:**
- Create: `app/patrol_test/settings_test.dart`
- Modify: `docs/dev-setup.md` (new "## Phase 10B check")

- [ ] **Step 1: Write the flows with no device**, onboarded through `onboardedOverrides`:
  1. **Switches:**
     - the evening reminder off and back on;
     - its time set to 07:30 through the picker, with the stored minutes read back as 450;
     - the still and copies switches off and on;
     - the background state written (read through the debug hook already used by `background_test.dart`).
  2. **Watched folder:**
     - "Add a folder" through Android's folder picker, choosing `Movies/TakeTray Test` (created by `TestMedia`);
     - Shooting mode on;
     - a new test video inserted there reaches To tag;
     - the tear-down turns the folder off, turns Shooting mode off and deletes the video.
  3. **Export then import:**
     - export to `Download/TakeTray Test/` through the document picker;
     - import the same file;
     - "X of Y clips found";
     - onboarding is not shown again;
     - the tear-down deletes the file through the picker's own delete, or leaves it in `Download/TakeTray Test/` named for the owner to delete (the controller rules on this after the review).
  4. **Send error log:**
     - the share sheet opens (detected by Android's chooser resource id), then Back;
     - no app is chosen.

  Each flow resets its settings in the tear-down.
- [ ] **Step 2:** Run `../tool/flutter analyze patrol_test` (must be clean). Do an offline `tool/patrol build android --target patrol_test/settings_test.dart --debug`. A Sonnet review follows, for phone safety, flakiness and order independence.
- [ ] **Step 3: Hand checks** in `docs/dev-setup.md` "## Phase 10B check", numbered:
  - the Settings screen against the prototype, light and dark, 2× text;
  - the evening reminder arriving at a time set a few minutes ahead (with the existing debug define if needed);
  - TalkBack on each switch;
  - the WhatsApp warning text;
  - an import of a backup from before 10B;
  - "Send error log" to the owner's own email, checking that the file holds no reel or video names;
  - the release build `install -r` over `app.taketray`.
- [ ] **Step 4 (last, after the final review):** ask the owner for the S24. Run each Patrol file once, do the hand checks, write D-152's results, and complete guide §9.
- [ ] **Step 5: Commit** `test(settings): Patrol flows and Phase 10B hand checks`.

---

### Task 10: Minors, final review, README (controller)

- [ ] **Step 1:** One Sonnet batch for the parked Minors.
- [ ] **Step 2:** Opus final review of `phase-10a-first-launch..phase-10b-settings`. Then one fix wave and an Opus re-review (the same reviewer).
- [ ] **Step 3:** The phone run (Task 9 Step 4), combined with 10A's if it is still pending.
- [ ] **Step 4:** README: Phase 10 ✅ with what 10A and 10B added; "Next: Phase 9 (References)". Complete the guide intro and Contents.
- [ ] **Step 5:** Push, regenerate the CI goldens (`update-goldens`, then `tool/pull_ci_goldens`), open the PR to `main` after 10A's PR merges, get CI green and the owner's go. After the merge: build the release from `main`, run `tool/check_release_permissions`, and `install -r` on the S24.
