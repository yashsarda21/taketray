# Phase 6: Background Detection and Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** TakeTray notices new clips while it is closed, and reminds the user without nagging. Phase 6 builds:
- **The background state:** Dart keeps a small native copy of what the background code needs: Shooting mode on or off and since when, the baselines, the watched folders, the shot times of the clips waiting in To tag, and the reminder settings. Dart writes it at every app start and on every change.
- **The new-clips notification:** a native JobScheduler content-URI job (no Flutter engine) counts the videos added since the last scan and posts or updates "N new clips to tag". It is silent, updated in place, shows the newest thumbnail (BigPictureStyle) and has **Open camera** and **Tag now**.
- **Reminders:** the evening reminder (9 pm by default) and the 14-day "Still shooting?" reminder. **Turn off** and **Keep on** work from the notification shade.
- **Re-arming** after a reboot, an app update, a clock change or a time-zone change.
- **In the app:**
  - notification taps open To tag or Reels;
  - the in-app "Still shooting?" dialog;
  - the notification permission (Android 13+);
  - the **Notifications not arriving?** help screen, with steps for each phone brand.
- **Parked media repairs** from `docs/later.md` (Task 8).

The phase is done when a notification appears after filming on the S24 Ultra and the reminders fire (spec §9, phase 6).

**Architecture:**
- **Native (Kotlin, `android/.../background/`):** a thin, Flutter-free layer.
  - `BackgroundStateStore` holds Dart's copy of the state, as JSON in the existing `taketray_native` preferences.
  - `NewClipsJobService` counts videos and updates the notification.
  - `ReminderReceiver` and `ReminderScheduler` handle the reminders (AlarmManager).
  - `ShadeActionReceiver` handles Turn off and Keep on.
  - `BootReceiver` re-arms everything.
  - Native code never writes the Drift database. The one thing that flows back to Dart is a **shade action** (Turn off / Keep on), which Dart applies at the next start and then clears.
- **The bridge:**
  - a new Pigeon contract, `pigeons/background_api.dart`;
  - `BackgroundHostApi` (state, shade actions, notification access, launch actions, phone maker, battery settings) and `BackgroundFlutterApi` (a notification tapped while the app runs);
  - the Dart wrapper is `lib/platform/background_bridge.dart`.
- **Dart:**
  - `BackgroundSync` (in `lib/data/background/`) watches the database and writes the native copy;
  - `MediaLifecycle` applies shade actions before its scan, and clears the new-clips notification after it;
  - new screens and dialogs in `lib/features/notifications/` and `lib/features/settings/`.

**Tech Stack:**
- Flutter 3.47.7 / Dart 3.13.5 via `tool/flutter`; Riverpod 3 codegen; Drift (schema **stays v1**); freezed; go_router; gen-l10n; alchemist goldens (macOS plus CI sets, D-61); Pigeon 29.0.11.
- Kotlin with the platform APIs only: `JobScheduler`, `AlarmManager`, `Notification.Builder`. **No WorkManager and no new Gradle dependency** (see the D-101 ruling below).
- Robolectric 4.17 (`tool/test_android`); Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`. Relevant sections:
- §3: evening reminder at 9 pm when ≥ 1 clip waits; BigPictureStyle on all brands.
- §4 anti-goals: noisy notifications; data leaving the phone.
- §5: background work without a Flutter engine.
- §8.2 `BackgroundApi`.
- §8.3: scan rules and the background job.
- §8.5 Notifications.
- §9 phase 6; §10; §11 (OEM limits: the scan on open stays the source of truth).

**Also read:**
- `docs/design-prompt.md`: §5 ("No permanent notification", "Quiet by default"), §6.2 (a shooting day), §7 screens 24 and 27 and notifications 30, 31 and 33, §8 (copy).
- The prototype `design/prototype/`:
  - `assets/screens.js`: `routes['notif-help']`, `routes.settings` (the Help and Permissions rows), `dialogs.stillShooting`, the shade cards (`card.new`, `card.evening`, `card.still`), `RH.activeNotifications`;
  - `assets/app.js`: `notifTap`, `notifCam`, `notifStillOff`, `shootOffDialog`, the simulator (`evening`, `still14`);
  - `assets/states.js`: screens 27, 30, 31 and 33 (notes);
  - `index.html` → Handoff → "Notification channels" and the deep links;
  - `proto.css`: `.acc`, `.callout.ok`, `.notif`.
- Parked items: the "Phase 6" section of `docs/later.md`.

## Global Constraints

- **SDK and tools:**
  - Use only `tool/flutter`, `tool/dart`, `tool/adb`, `tool/patrol`. Never the `flutter` on PATH; never touch `~/flutter`.
  - Iterate with `tool/test_android -ProbolectricSdks=35`. All four SDKs and `tool/check` must be green before a commit.
  - Regenerate Pigeon with `cd app && ../tool/dart run pigeon --input pigeons/background_api.dart`. `tool/check_generated` must cover the new contract.
- **Owner rulings (plan review, 2026-11-05):**
  - **Evening reminder:** counts the clips **shot today** (the phone's local day) that are still waiting. It is quiet on a day with none, even if older clips wait.
  - **Notification permission (Android 13+):** asked **once**, the first time Shooting mode is turned on, after the video-access question. After that only from the Settings row. Onboarding (Phase 10) takes this over.
  - **Parked media repairs:** I-3 and M-8 in Task 8; M-6 and M-7 move to Phase 11 with the reason recorded.
- **D-101 rulings (the controller's):**
  - **No WorkManager.** Its manifest merges `WAKE_LOCK` and `ACCESS_NETWORK_STATE`, which the release forbids (D-89), and it cannot fire at a wall-clock time. Reminders use `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, …)`, which is inexact, needs no exact-alarm permission, and fires in Doze. This amends spec §5 ("WorkManager for scheduled reminders").
  - **Flutter's own deep linking is off** (`flutter_deeplinking_enabled` = false on `MainActivity`). The activity is exported for the launcher, so with deep linking on, any app could open any route. Notifications send an allow-listed **launch action** instead.
  - **Native copy** lives in `android/app/src/main/res/values/strings.xml` (English, with `<plurals>`). Notifications are built without a Flutter engine, so they cannot use the ARB. Dart copy stays in `app_en.arb`.
  - **On the lock screen** the new-clips notification is `VISIBILITY_PRIVATE`. Its public version reads "TakeTray" and the count, with no thumbnail.
  - **The new-clips count** is the number of videos added since the stored baselines: clips the app has not scanned yet (spec §8.3). After a scan in the app, the app clears the notification.
- **Copy:** prototype text verbatim; "Recording" is "Collecting" (D-80).
  - **New clips notification** (channel **New clips**, LOW):
    - title "{n} new clips to tag" (plural: "1 new clip to tag");
    - text "Tap to tag them into your reels." (one: "Tap to tag it into a reel.");
    - actions **Open camera** and **Tag now**;
    - the public version: title "TakeTray", text "{n} new clips to tag".
  - **Evening reminder** (channel **Reminders**, DEFAULT):
    - title "You shot {n} clips today. Tag them?" (one: "You shot 1 clip today. Tag it?");
    - text "Takes a few minutes, one tap per clip.";
    - action **Tag now**.
  - **Still shooting? notification:** title "Still shooting?", text "Shooting mode has been on for 14 days. Turn it off?", actions **Turn off** and **Keep on**.
  - **Channel descriptions:**
    - New clips: "One quiet notification when new clips are waiting to be tagged."
    - Reminders: "The evening reminder and the Shooting mode reminder."
  - **Still shooting? dialog:**
    - title "Still shooting?";
    - body "Shooting mode has been on for 14 days. While it's on, every new video goes to To tag.";
    - buttons **Keep it on** and **Turn off**;
    - after Turn off, the snack "Shooting mode off".
  - **Settings (interim rows until Phase 10):**
    - group "Help": "Notifications not arriving?" / "Steps for Samsung, Xiaomi, Realme and more", with a chevron;
    - group "Permissions": "Notifications" / "Allowed" with a check, or "Not allowed" with a tonal **Allow**.
  - **Help screen:**
    - app bar "Notifications not arriving?";
    - intro "Some phones stop apps in the background to save battery. Then the "new clips" notification can be late or missing.";
    - success callout "Your clips are never lost" / "They show up in To tag when you open the app.";
    - one card per brand, with the steps and button text from `routes['notif-help']` verbatim;
    - the label "Your phone";
    - footer "Menu names can be a little different on your phone.";
    - if a settings screen cannot be opened, the snack "Couldn't open settings on this phone." (new copy, D-107).
- **Taps:**
  - New clips (body and Tag now) and the evening reminder open **To tag**.
  - Still shooting? (body) opens **Reels**, where the dialog appears.
  - Open camera opens the phone's video camera directly.
  - Turn off and Keep on run without opening the app.
- **Quiet (anti-goal):**
  - One new-clips notification (fixed id), `setOnlyAlertOnce(true)`, LOW importance (no sound, no vibration). It is never re-posted when the count has not changed, and cancelled when the count is 0, when Shooting mode goes off, or when the app has scanned.
  - Reminders: at most one evening reminder a day, and one Still shooting? per Shooting mode session.
- **Dart is the truth:**
  - The native copy is a mirror, re-written at every app start. A shade action names its session (`sinceMs`), and Dart applies it only if that session is still the stored one.
  - Native code never writes the Drift database.
  - The scan on open stays the source of truth (spec §11). The job only counts.
- **Never count everything as new:** a volume whose MediaStore version differs from its baseline's, a volume without a baseline, or a volume that is not mounted counts 0 in the job.
- **Privacy (D-10):** log lines (Dart and Kotlin `Log`) never hold a display name, path, URI, folder, reel name, zone, phone maker or count of a named reel. Ids, counts and error types only. Notifications never show a file name or a folder.
- **Accessibility:**
  - 48 dp targets.
  - Each expandable card reads its expanded state ("Samsung, your phone, expanded").
  - The step list reads as a list.
  - The dialog follows `TtDialog`.
  - Notification actions have text labels (Android reads them).
- **Models:** no Haiku, ever. Tasks 3, 4, 5, 6, 8 and 9 and the final review run on **Opus**; Tasks 2 and 7 on **Sonnet**. Always name the model.
- **Reviews (owner rules):**
  - Every code task gets a fresh task reviewer. Docs-only tasks (1 and 10) skip it, with a ledger line.
  - Per-task fix rounds are self-reviewed by the fixer.
  - **Hybrid rule:** Critical and Important findings are fixed in the task's loop. Minor findings are parked in the ledger and fixed in **one minors batch** before the final review, by one agent that reviews its own fixes.
  - The final review's fix wave gets a separate re-review.
- **Tight testing (owner's rule):**
  - Each listed test is run red first, then green, with both runs quoted in the report.
  - At least two **mutation checks** per task, each applied alone then reverted, with the failing output quoted.
  - Never loosen, skip or delete a test to get green.
  - Android behaviour is proven in Robolectric (Tasks 3–5) **and** on the S24 (Task 9).
- **Style rules:**
  - No raw colours, sizes, text styles, radii, `EdgeInsets` numbers or animation durations in feature code (`tool/check_styles`).
  - Each new or changed component has goldens (light/dark, 1× and 2× text, macOS **and** CI sets, D-61), a Widgetbook use case, and passes `expectTtAccessible`.
  - Every Dart string is in `app_en.arb`; every notification string is in `strings.xml`.
- **Release manifest:**
  - New permissions `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` only. `tool/check_release_permissions` requires both and still forbids `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` and `FOREGROUND_SERVICE`.
  - Every new receiver and service is `exported="false"`. The job service is protected by `BIND_JOB_SERVICE`.
- **Phone rule:**
  - Only `app.taketray`, `app.taketray.dev` and `app.taketray.widgetbook` may be installed, cleared or run. Never uninstall or clear `app.taketray`.
  - Logcat only through a TakeTray pid filter. No screenshots. No reading of other apps or of shared storage.
  - **The notification shade:** tests find and tap only TakeTray's own notifications by their text (Patrol selectors). They never call a "list all notifications" API, and never print or store another app's notification.
  - Patrol tests create and delete only their own videos in `Movies/TakeTray Test/` (D-77).
  - Settings a test changes are restored at the end of the test body.
  - The limited-access test stays skipped.
  - After any Patrol run: `tool/flutter build apk --debug`, `tool/adb install -r …app-debug.apk`, `tool/adb shell pm clear app.taketray.dev`.
- **Coverage:** ≥ 80 % for `lib/domain/`, `lib/data/`, `lib/platform/` (excluding `*.g.dart`) and `lib/features/*/view_models/`.
- **Living docs:**
  - The next free decision number is **D-101**; tasks take the next free numbers in order.
  - Every changed flow updates `docs/flow.md`.
  - Every finished `docs/later.md` item is deleted in the same commit as its code.
- **Learning guide:** `docs/learn/phase-6-background.md`.
  - Task 1 stubs one section per task.
  - Tasks 2–9 each fill their own section with the Phase 5 template: what we built / why / key ideas with short real snippets / where it lives / try it yourself / decisions.
  - A wrong explanation is a review defect.
- **Git (D-63):**
  - Work on branch `phase-6-background`.
  - Push after every task commit with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u origin phase-6-background`.
  - A task is complete only when CI is green on its commit.
  - Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Never force-push.
  - The phase lands through a PR after the owner approves.

## Review Focus

1. **Noisy or doubled notifications.** Expected: exactly one silent new-clips notification, updated in place; nothing while off; no crash when notifications are not allowed. Situations to test:
   - a burst of 10 clips (each a pending insert and then an update);
   - the job firing again with the same count;
   - the app scanning, then the job running;
   - Shooting mode turned off while the notification shows;
   - notifications not allowed.

   Owner: Task 4 (`same count does not re-post`, `zero cancels`, `off cancels and stops the job`, `not allowed posts nothing and does not throw`, `pending rows are not counted`).
2. **Native copy out of step with the database.** Expected: the database wins, every app start re-writes the copy, and a shade action applies only to its own session. Situations to test:
   - the app dies between a baseline move and the write;
   - Turn off from the shade, then the app is opened and the user turns Shooting mode on again;
   - a shade action from an older session;
   - two writes racing.

   Owner: Task 6 (`start rewrites the copy`, `turn off from the shade applies once`, `shade action for another session is dropped`, `writes are serialised, last wins`, `clips shot after the tap are not added`).
3. **Time arithmetic.** Expected: the evening reminder fires once a day at the local time chosen, and the 14-day reminder lands at the first 10:00 local at or after 14 days. Situations to test:
   - a daylight-saving day (the 21:00 local still fires once);
   - travelling across zones;
   - the phone clock moved;
   - evening minutes 0 and 1439;
   - the reminder time already passed today;
   - 14 days that ends at 03:00.

   Owner: Task 5 (`next evening across spring forward`, `next evening after the time passed is tomorrow`, `minute 0 and 1439`, `still due rounds up to 10:00`, `zone change re-arms`).
4. **The media library under the job.** Expected: such volumes count 0; pending rows, zero-length rows and rows outside the watched folders never count; only videos count. Situations to test:
   - a rebuilt library (new version);
   - an unmounted SD card;
   - a volume with no baseline;
   - a 4-hour pending recording;
   - a video in a folder that is not watched;
   - a photo.

   Owner: Task 4 (`version change counts nothing`, `no baseline counts nothing`, `unwatched folder not counted`, `zero duration not counted`).
5. **Privacy and permission edges.** Expected: no other app can trigger them; the lock screen shows no thumbnail; logs carry counts only; the release passes `tool/check_release_permissions`. Situations to test:
   - the lock screen;
   - another app sending an intent to the exported activity with a route, or a broadcast to the receivers;
   - permission denied twice (Android stops asking);
   - Android 11 and 12 (no runtime permission).

   Owner: Task 3 (`unknown launch action ignored`, `launch action from history ignored`, `deep linking is off`), Task 4 (`public version has no picture`), Task 5 (`receivers are not exported`), Task 7 (`Allow opens settings when Android will not ask`).

---

## File structure

**Create (app):**
- `pigeons/background_api.dart`, which generates `lib/platform/background_api.g.dart` and `android/.../background/BackgroundApi.g.kt`.
- `lib/platform/background_bridge.dart`.
- `lib/data/background/background_sync.dart` and `lib/data/background/shade_actions.dart`.
- `lib/domain/rules/still_shooting.dart` and `lib/domain/rules/phone_brand.dart`.
- `lib/features/notifications/`:
  - `view_models/notification_access_controller.dart`, `launch_actions.dart`, `still_shooting_prompt.dart`;
  - `views/still_shooting_dialog.dart`, `notifications_help_screen.dart`.
- `lib/features/settings/views/settings_screen.dart` (interim; replaces the placeholder).
- **Native**, in `android/app/src/main/kotlin/app/taketray/background/`:
  - `BackgroundState.kt` and `BackgroundStateStore.kt`;
  - `BackgroundHostApiImpl.kt` and `Arming.kt`;
  - `NewClipsCounter.kt`, `NewClipsJobService.kt`, `Notifier.kt`;
  - `ReminderTimes.kt`, `ReminderScheduler.kt`, `ReminderReceiver.kt`;
  - `ShadeActionReceiver.kt`, `BootReceiver.kt`, `LaunchActions.kt`.
- `res/values/strings.xml`; the debug-only `DebugBackgroundHooks` in `src/debug/`.
- `patrol_test/background_test.dart`; `docs/learn/phase-6-background.md`.

**Modify (app):**
- `MainActivity.kt`, `AndroidManifest.xml`, `VideoQueries.kt` (the count query).
- `lib/domain/models/media.dart` (`ShootingState.stillAnswered`), `phone_state_repository.dart`, `clips_repository.dart` (`watchPendingShotTimes`).
- `media_scanner.dart` (`endSessionAt`, the M-8 path), `library_resync.dart` (I-3).
- `lib/app/media_lifecycle.dart`, `app.dart`, the router and routes, `shooting_mode_controller.dart` (the permission ask), `app_en.arb`.
- Tools: `tool/check_release_permissions`, `tool/check_generated`.

**taketray_ui** (Task 2): new `expand_card.dart` (`TtExpandCard`) and `step_list.dart` (`TtStepList`); `banners.dart` (`TtCallout.success`); tests, goldens, Widgetbook.

---

### Task 1: Plan, scope decision and the learning-guide stub (docs only, by the controller)

**Model:** the controller, inline. No task review (docs only; ledger line).

- [ ] **Step 1:** Commit this plan, with the owner's rulings from plan review written into Global Constraints.
- [ ] **Step 2:** Create `docs/learn/phase-6-background.md` with a "How to read" intro and one stub section per Task 2–9.
- [ ] **Step 3:** Add **D-101 · Phase 6 scope**, covering:
  - the Goal list;
  - what waits: the VN 3-day reminder (Phase 8, with the VN copies), the "Remind me to turn it off" switch and the reminder-time form (Phase 10, Settings), onboarding's notification step (Phase 10);
  - the owner rulings;
  - the four controller rulings in Global Constraints (no WorkManager, which amends spec §5; deep linking off; native copy in `strings.xml`; the private lock-screen version).
- [ ] **Step 4:** Commit `docs: Phase 6 plan, scope decision and learning guide stub`, push.

---

### Task 2: Expandable card, step list and the success callout (design system)

**Model:** Sonnet.

**Files:** `packages/taketray_ui/lib/src/components/expand_card.dart`, `step_list.dart`, `banners.dart`; exports; tests, goldens, Widgetbook.

Build from `proto.css` `.acc`, `.acc .ah`, `.acc .ab`, `.acc .ab ol`, `.acc .you` and `.callout.ok`:
- **`TtExpandCard({required String title, String? badge, required bool expanded, required VoidCallback onToggle, required Widget child})`:**
  - a 16 dp-radius card on the low surface container;
  - the header row is at least 56 dp, with the title (title small), an optional **badge** (label medium on the tertiary container, 6 dp radius, for "Your phone") and an expand_more / expand_less icon;
  - when expanded, the body sits under the header with 16 dp sides and bottom;
  - semantics: one button with `expanded` state, whose label is the title and the badge.
  - No outer margin.
- **`TtStepList(List<String> steps)`:** an ordered list ("1." …) with a 20 dp hanging indent and 6 dp between items, in body medium. Each item reads "1. {text}". The list is one semantics group.
- **`TtCallout(success: true)`:** the success container colours, with the icon in the on-container colour. It is the `.callout.ok` look; `warning` and `success` cannot both be set (assert).

- [ ] **Step 1:** Failing tests (light/dark, 1× and 2× at 360 dp, no overflow, `expectTtAccessible`):
  - `expand card reports expanded`;
  - `collapsed card hides the body`;
  - `badge is read with the title`;
  - `header is at least 56 dp`;
  - `step list numbers its items`;
  - `success callout uses the success container`;
  - `warning and success assert`.
- [ ] **Step 2:** Implement; Widgetbook use cases (the coverage test must pass); macOS goldens; `tool/check`.
- [ ] **Step 3:** Add **D-102** and fill Section 2. Commit `feat(ui): expandable card, step list and success callout`, push.

**Mutations:** the card's expanded semantics dropped; the step numbers start at 0; the success callout uses the plain container.

---

### Task 3: The background bridge, the native state store and launch actions (critical, Opus)

**Model:** Opus.

**Files:** `pigeons/background_api.dart`; generated Dart and Kotlin; `lib/platform/background_bridge.dart`; native `BackgroundState.kt`, `BackgroundStateStore.kt`, `BackgroundHostApiImpl.kt`, `LaunchActions.kt`, `Arming.kt` (interface plus a no-op for now); `MainActivity.kt`; `AndroidManifest.xml` (`POST_NOTIFICATIONS`, deep linking off); `tool/check_generated`; `test/support/fake_background_bridge.dart`. Tests: `test/platform/background_bridge_test.dart`, `src/test/kotlin/app/taketray/background/BackgroundStateStoreTest.kt`, `BackgroundHostApiImplTest.kt`, `LaunchActionsTest.kt`.

**Interfaces:**
- **Pigeon** (`@ConfigurePigeon`: `dartOut: lib/platform/background_api.g.dart`, `kotlinOut: …/background/BackgroundApi.g.kt`, package `app.taketray.background`):
  - `class VolumeBaselineMsg { String volumeName; String version; int generation; }`
  - `class VolumeGenerationMsg { String volumeName; int generation; }`
  - `class BackgroundStateMsg { bool shootingOn; int? sinceMs; List<VolumeBaselineMsg> baselines; List<String> watchedFolders; List<int> waitingShotMs; bool eveningEnabled; int eveningMinutes; bool stillReminderEnabled; bool stillAnswered; }`
    - `waitingShotMs`: the UTC instants of the clips pending in To tag (`dateTakenUtc`), in ascending order.
  - `enum ShadeActionKindMsg { turnOff, keepOn }`
  - `class ShadeActionMsg { ShadeActionKindMsg kind; int sinceMs; int atMs; List<VolumeGenerationMsg> generations; }`
    - `generations`: each baselined volume's generation when Turn off was tapped (empty for keepOn).
  - `class NotificationAccessMsg { bool granted; bool canAsk; int sdkInt; }`
  - `enum LaunchActionMsg { toTag, reels }`
  - `@HostApi() abstract class BackgroundHostApi`, with these methods:
    - `@async void writeState(BackgroundStateMsg state)`
    - `ShadeActionMsg? pendingShadeAction()`
    - `void clearShadeAction(int atMs)`: clears only an action with this `atMs`.
    - `void clearNewClipsNotification()`
    - `NotificationAccessMsg notificationAccess()`
    - `@async NotificationAccessMsg requestNotificationAccess()`
    - `void openNotificationSettings()`
    - `String phoneMaker()`
    - `bool openBatterySettings()`
    - `LaunchActionMsg? takeLaunchAction()`
  - `@FlutterApi() abstract class BackgroundFlutterApi { void onLaunchAction(LaunchActionMsg action); }`
- **`BackgroundStateStore(prefs)`** (the `taketray_native` preferences):
  - `state(): BackgroundState` (a corrupt or missing value is "off, nothing");
  - `write(BackgroundState)`;
  - `shadeAction(): ShadeActionMsg?`;
  - `putShadeAction(ShadeActionMsg)`;
  - `clearShadeAction(atMs: Long)`;
  - `postedNewClips(): Int`;
  - `setPostedNewClips(Int)`.
  - Keys `background_state`, `shade_action` and `posted_new_clips`. `commit()`, not `apply()` (a receiver's process may end at once). One lock shared by every instance, as `ZoneChangeStore` has.
- **`Arming`** (`fun interface`): `apply(context, state)`. This task wires a no-op; Tasks 4 and 5 fill it in. `writeState` stores, then calls `Arming.apply`.
- **Notification access:**
  - granted = `NotificationManager.areNotificationsEnabled()`;
  - `canAsk` = SDK ≥ 33, not granted, and either never asked or `shouldShowRequestPermissionRationale`, as `MediaAccessChecker` decides for video;
  - below 33 there is no dialog: `requestNotificationAccess` returns the report unchanged.
  - The request uses its own request code; `MainActivity.onRequestPermissionsResult` forwards to both bridges.
- **`phoneMaker()`:** `Build.MANUFACTURER`, lower-cased and trimmed. Never logged.
- **`openBatterySettings()`:** starts `Intent.ACTION_POWER_USAGE_SUMMARY`. If no activity resolves, it falls back to `ACTION_APPLICATION_DETAILS_SETTINGS` for the package. It returns false if neither starts.
- **Launch actions (`LaunchActions.kt`):**
  - The extra is `app.taketray.extra.OPEN`, with the values `toTag` and `reels`. `LaunchActions.intent(context, action)` builds the explicit `MainActivity` intent that notifications use.
  - `MainActivity` reads the action from `getIntent()` at configure time and in `onNewIntent`:
    - an unknown value is ignored;
    - an intent with `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY` is ignored;
    - after reading, the extra is removed, so a re-created activity does not act twice.
  - While no Dart listener is set up, the action is kept for `takeLaunchAction()`; otherwise `BackgroundFlutterApi.onLaunchAction` is called.
- **Dart `BackgroundBridge`** (provider `backgroundBridgeProvider`, keepAlive):
  - typed wrappers over the host API, with the same error mapping as `MediaBridge`;
  - `Stream<LaunchAction> launchActions` (the Flutter API, plus the one taken at start);
  - domain types `BackgroundState`, `ShadeAction`, `NotificationAccess`, `LaunchAction` in `lib/platform/background_bridge.dart`.
  - `FakeBackgroundBridge` records every write and can emit actions.

- [ ] **Step 1:** Failing tests.
  - Kotlin:
    - `store round trips the state`;
    - `corrupt state reads as off`;
    - `clear shade action only clears the same atMs`;
    - `posted count persists`;
    - `writeState stores then arms`;
    - `notification access below 33 is granted and cannot ask`;
    - `unknown launch action ignored`;
    - `launch action from history ignored`;
    - `extra removed after reading`;
    - `battery settings falls back to app details`.
  - Dart:
    - `bridge maps state to the message`;
    - `bridge maps errors like the media bridge`;
    - `launch actions stream yields the start action first`;
    - `fake records writes`.
  - Manifest test (Robolectric reads the merged manifest): `deep linking is off`.
- [ ] **Step 2:** Implement; regenerate; `tool/check_generated` hashes the new contract; `tool/check`; `tool/test_android`.
- [ ] **Step 3:** Add **D-103** (the contract; the mirror and the one native-to-Dart path; launch actions and deep linking off; the permission's request code). Update `docs/flow.md` (new "Background bridge" section). Fill Section 3. Commit `feat(background): the background bridge, state store and launch actions`, push.

**Mutations:** the history flag check removed; `clearShadeAction` ignores `atMs`; the store uses `apply()` (a test reads it through a fresh instance after a simulated process end, using Robolectric's prefs reload).

---

### Task 4: The new-clips job and notification (native, critical, Opus)

**Model:** Opus.

**Files:** `VideoQueries.kt` (count args); native `NewClipsCounter.kt`, `NewClipsJobService.kt`, `Notifier.kt`, `Arming.kt` (the job part); `strings.xml`; manifest (the service); Robolectric tests `NewClipsCounterTest.kt`, `NewClipsJobServiceTest.kt`, `NotifierTest.kt`, `ArmingTest.kt`.

**Interfaces:**
- **`VideoQueries.newClipsArgs(afterGeneration, folders)`:**
  - `GENERATION_ADDED > ?` AND the folder clause AND `DURATION > 0` AND `SIZE > 0`;
  - pending rows excluded (`MATCH_EXCLUDE`), trashed excluded;
  - ordered `GENERATION_ADDED DESC, _ID DESC`.
- **`NewClipsCounter(resolver, versionOf: (String) -> String?, access: () -> Boolean)`:**
  - `count(state): NewClips(count: Int, newest: Pair<String, Long>?, shotMs: List<Long>)`.
  - For each baseline: skip the volume if `versionOf(volume)` is not equal to the baseline's version (null, meaning not mounted, is not equal); otherwise query.
  - `shotMs` is DATE_TAKEN, or DATE_ADDED × 1000 when DATE_TAKEN is missing.
  - Access not full, or Shooting mode off: `NewClips(0, null, [])`.
- **`Notifier(context)`:**
  - `ensureChannels()` creates the channels `new_clips` (LOW) and `reminders` (DEFAULT) with the copy names and descriptions;
  - `showNewClips(count, thumbnail: Bitmap?)`;
  - `cancelNewClips()`.
  - Notification ids: NEW_CLIPS = 1, EVENING = 2, STILL_SHOOTING = 3.
  - `showNewClips` does nothing when notifications are not enabled. The notification has:
    - small icon `ic_stat_taketray`;
    - the copy title and text;
    - BigPictureStyle with the thumbnail, also as the large icon, and `bigLargeIcon(null)` when expanded;
    - `setOnlyAlertOnce(true)`, auto-cancel, `VISIBILITY_PRIVATE` with the public version;
    - its body and **Tag now** as `PendingIntent.getActivity(LaunchActions.intent(toTag))`;
    - **Open camera** as `PendingIntent.getActivity(Intent(MediaStore.INTENT_ACTION_VIDEO_CAMERA))`.
  - Every PendingIntent is `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT`, with a distinct request code each.
- **`NewClipsJobService`** (job id `0x7A72`):
  - `onStartJob` hands the work to a single background thread:
    - read the state;
    - if Shooting mode is off, cancel the notification and do not re-arm;
    - else count. If the count is 0, cancel and set posted to 0. If the count equals posted, leave the notification. Else load the newest thumbnail (`Thumbnails`, 1024 px longer side; null on failure) and show it, then set posted;
    - record the phone's zone in `ZoneChangeStore` (spec §8.3a: every background job run);
    - then re-arm (schedule again) and call `jobFinished(params, false)`.
  - `onStopJob` re-arms and returns false.
  - Errors are logged by type and never crash; it re-arms anyway.
- **`Arming.apply`, the job part:**
  - With Shooting mode on and full access, schedule the job unless an identical one is pending, using:
    - `addTriggerContentUri(TriggerContentUri(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL), FLAG_NOTIFY_FOR_DESCENDANTS))`;
    - `setTriggerContentUpdateDelay(5_000)` and `setTriggerContentMaxDelay(30_000)`;
    - not persisted (content triggers cannot be).
  - Otherwise cancel the job and `cancelNewClips()`.
  - `clearNewClipsNotification()` (bridge) cancels it and sets posted to 0.

- [ ] **Step 1:** Failing Robolectric tests:
  - `counts videos after the baseline in watched folders`;
  - `pending rows are not counted`;
  - `zero duration not counted`;
  - `unwatched folder not counted`;
  - `version change counts nothing`;
  - `no baseline counts nothing`;
  - `no access counts nothing`;
  - `newest is the highest generation`;
  - `same count does not re-post`;
  - `zero cancels`;
  - `off cancels and stops the job`;
  - `not allowed posts nothing and does not throw`;
  - `notification is silent, only alerts once, private`;
  - `public version has no picture`;
  - `tag now and body open To tag`;
  - `open camera opens the video camera`;
  - `job records the zone`;
  - `job re-arms after every run`;
  - `job re-arms after an error`;
  - `arming schedules the content trigger with the delays`;
  - `arming twice keeps one job`.
- [ ] **Step 2:** Implement; `tool/test_android` (all SDKs); `tool/check`.
- [ ] **Step 3:** Add **D-104** (the count, its exclusions, the delays, re-arming, the lock-screen version). Update `docs/flow.md` ("New clips while TakeTray is closed"). Fill Section 4. Commit `feat(background): the new-clips job and notification`, push.

**Mutations:** the version check removed; the "same count" guard removed (a test counts posts); `setOnlyAlertOnce(false)`.

---

### Task 5: Reminders, shade actions and re-arming (native, critical, Opus)

**Model:** Opus.

**Files:** native `ReminderTimes.kt`, `ReminderScheduler.kt`, `ReminderReceiver.kt`, `ShadeActionReceiver.kt`, `BootReceiver.kt`, `Arming.kt` (the alarms part), `TimeZoneChangedReceiver.kt` (also re-arms); manifest (`RECEIVE_BOOT_COMPLETED`, the receivers); `strings.xml`; `tool/check_release_permissions` (required and forbidden lists); Robolectric tests `ReminderTimesTest.kt` (pure JVM), `ReminderSchedulerTest.kt`, `ReminderReceiverTest.kt`, `ShadeActionReceiverTest.kt`, `BootReceiverTest.kt`, `ManifestTest.kt`.

**Interfaces:**
- **`ReminderTimes`** (pure, `java.time`):
  - `nextEvening(nowMs: Long, minutes: Int, zone: ZoneId): Long`: the next instant strictly after now when the local time is `minutes` past midnight. On a day where that local time does not exist (spring forward), it is the first instant after the gap; on a day where it repeats, it is the first occurrence.
  - `stillDueAt(sinceMs: Long, zone: ZoneId): Long`: the first 10:00 local at or after `since + 14 days`.
  - `startOfToday(nowMs, zone): Long`.
  - `const val STILL_AFTER_DAYS = 14`.
- **`ReminderScheduler(context)`:**
  - `armEvening(state, nowMs)`: if `eveningEnabled`, `setAndAllowWhileIdle(RTC_WAKEUP, nextEvening(...))`; else cancel.
  - `armStill(state)`: if Shooting mode is on, `stillReminderEnabled` and not `stillAnswered`, arm at `stillDueAt(since)` (or at once if that is in the past); else cancel it and cancel its notification.
  - The broadcasts are explicit, to `ReminderReceiver`, with the action names `app.taketray.REMINDER_EVENING` and `app.taketray.REMINDER_STILL`, and the session's `sinceMs` as an extra on the still reminder.
- **`ReminderReceiver`** (uses `goAsync()` and a background thread for the count):
  - **Evening:**
    1. Re-arm the next evening first.
    2. If enabled, count today's waiting clips: the entries of `waitingShotMs` at or after `startOfToday`, plus those of `NewClipsCounter.count(state).shotMs` at or after it.
    3. If the count is ≥ 1, post EVENING with the copy and **Tag now**, opening To tag (auto-cancel).
  - **Still:** if Shooting mode is on, the extra `sinceMs` equals the state's, the reminder is enabled and not answered, post STILL_SHOOTING. Its body opens Reels; **Turn off** and **Keep on** are `PendingIntent.getBroadcast` to `ShadeActionReceiver` with `sinceMs`.
- **`ShadeActionReceiver`:** it acts only if the state is on with that `sinceMs`; otherwise it only cancels STILL_SHOOTING.
  - **Turn off:**
    - read each baselined volume's current generation, where its version still matches (`MediaStore.getGeneration`; skip the volume on an error);
    - `putShadeAction(turnOff, sinceMs, now, generations)`;
    - write the state with `shootingOn = false`;
    - `Arming.apply` (the job stops; the new-clips notification **stays**, because those clips still arrive when the app opens);
    - cancel STILL_SHOOTING.
  - **Keep on:** `putShadeAction(keepOn, sinceMs, now, [])`, write the state with `stillAnswered = true`, cancel the still alarm and STILL_SHOOTING.
- **`BootReceiver`:** handles `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` and `TIME_SET`. Each calls `Arming.apply(context, store.state())`. `TimeZoneChangedReceiver` also calls it, after recording the zone.
- **`Arming.apply`, the alarms part:** `armEvening` and `armStill`.
- **Manifest:**
  - `RECEIVE_BOOT_COMPLETED`;
  - the receivers `exported="false"`, with intent filters for the system broadcasts only.
  - The reminder and shade-action receivers have no intent filter (explicit intents only).
- **`tool/check_release_permissions`:**
  - required: `POST_NOTIFICATIONS:-` and `RECEIVE_BOOT_COMPLETED:-`;
  - forbidden: also `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `FOREGROUND_SERVICE`;
  - also the debug-only strings of Task 9's hooks (`DebugBackgroundHooks`, `test_background`).

- [ ] **Step 1:** Failing tests:
  - `next evening later today`;
  - `next evening after the time passed is tomorrow`;
  - `next evening across spring forward`;
  - `next evening across fall back fires once`;
  - `minute 0 and 1439`;
  - `still due rounds up to 10:00`;
  - `still due exactly at 10:00 stays`;
  - `evening disabled cancels`;
  - `evening counts only today's waiting clips`;
  - `evening with none today posts nothing`;
  - `evening re-arms before posting`;
  - `still for an older session posts nothing`;
  - `still answered posts nothing`;
  - `turn off records the generations and stops the job`;
  - `turn off keeps the new clips notification`;
  - `keep on marks answered and cancels`;
  - `shade action for another session only cancels`;
  - `boot re-arms the job and alarms`;
  - `zone change re-arms`;
  - `receivers are not exported`;
  - `no exact alarm permission`.
- [ ] **Step 2:** Implement; `tool/test_android`; `tool/check`. Run `tool/check_release_permissions` once (slow) and quote its result.
- [ ] **Step 3:** Add **D-105** (the times, inexact alarms, the shade actions and their session check, the re-arm triggers; amends spec §5 as D-101 said). Update `docs/flow.md` ("Reminders" and "Re-arming"). Fill Section 5. Commit `feat(background): reminders, shade actions and re-arming`, push.

**Mutations:** the evening re-arm moved after the post (a test throws in the post); the session check removed from the shade receiver; `stillDueAt` without the 10:00 rounding.

---

### Task 6: Dart keeps the native copy in step, and applies shade actions (data, critical, Opus)

**Model:** Opus.

**Files:** `lib/domain/models/media.dart`, `lib/domain/rules/still_shooting.dart`, `lib/data/repositories/phone_state_repository.dart`, `clips_repository.dart`, `lib/data/media/media_scanner.dart`, new `lib/data/background/background_sync.dart` and `shade_actions.dart`, `lib/app/media_lifecycle.dart`, `lib/app.dart`. Tests: `test/data/background/background_sync_test.dart`, `shade_actions_test.dart`, `test/data/media/media_scanner_end_session_test.dart`, `test/domain/rules/still_shooting_test.dart`, and additions to `phone_state_repository_test.dart` and `media_lifecycle_test.dart`.

**Interfaces:**
- **`ShootingState`:** gains `@Default(false) bool stillAnswered`. It is kept by `advanceBaseline` (`copyWith`) and gone after `turnShootingOff` (the row is deleted). Old JSON without the field reads as false.
- **`PhoneStateRepository.markStillAnswered(DateTime since) → Future<bool>`:** compare-and-set on the session's `since`; true if it wrote.
- **`still_shooting.dart`:** `const stillShootingAfter = Duration(days: 14);` and `bool stillShootingDue(ShootingState s, DateTime now)`: on, not answered, and `now − since ≥ 14 days`.
- **`ClipsRepository.watchPendingShotTimes() → Stream<List<DateTime>>`:** the pending clips' `dateTakenUtc`, in ascending order; it emits only on change.
- **`BackgroundSync`** (keepAlive provider; `start()` is called once from `TakeTrayApp`):
  - combines `watchShooting()`, `SettingsRepository.watch()` and `watchPendingShotTimes()` into a `BackgroundState`, with `stillReminderEnabled: true` until Phase 10;
  - writes through `BackgroundBridge.writeState` when the state differs from the last one written;
  - writes run one at a time, and while one runs only the newest waiting state is kept;
  - the first state after `start()` is always written (re-arm at app start);
  - errors are guarded, logged by type, and retried on the next change.
- **`MediaScanner.endSessionAt({required DateTime since, required Map<String, int> generations}) → Future<ScanOutcome>`:**
  - one job on the media queue, never coalesced with `scan()`;
  - if the stored session's `since` is not `since`, it returns `ScanShootingOff` and changes nothing;
  - else it scans each volume in `generations` as `scan()` would, but ignores rows above that volume's generation, and moves the baseline no higher than it;
  - volumes not in `generations` are skipped (logged);
  - then, in the same job, `turnShootingOff()`.
- **`ShadeActions.apply() → Future<void>`:** reads `pendingShadeAction()`.
  - For `turnOff`: `endSessionAt`.
  - For `keepOn`: `markStillAnswered(since)`.
  - Then `clearShadeAction(atMs)`, also when the session no longer matches (it is stale). A bridge error leaves the action for the next start.
- **`MediaLifecycle._run`**, in order:
  1. `ShadeActions.apply`;
  2. zone sync;
  3. access refresh;
  4. scan;
  5. after a `ScanDone`, `clearNewClipsNotification()`.

  Each step is guarded, as before.

- [ ] **Step 1:** Failing tests:
  - `old shooting json reads stillAnswered false`;
  - `advance keeps stillAnswered`;
  - `mark answered only for the same session`;
  - `due at exactly 14 days`;
  - `not due when answered`;
  - `pending shot times ascending and only on change`;
  - `start rewrites the copy`;
  - `copy follows a baseline move`;
  - `copy follows settings and tagging`;
  - `same state is not written twice`;
  - `writes are serialised, last wins`;
  - `a failed write is retried on the next change`;
  - `turn off from the shade applies once`;
  - `clips shot after the tap are not added`;
  - `clips shot before the tap are added`;
  - `shade action for another session is dropped and cleared`;
  - `keep on marks answered`;
  - `bridge error keeps the action`;
  - `lifecycle applies shade actions before the scan`;
  - `lifecycle clears the notification after a scan`;
  - `no clear when the scan was skipped`.
- [ ] **Step 2:** Implement; `tool/check`.
- [ ] **Step 3:** Add **D-106** (the mirror's contents and when it is written; `endSessionAt` and the cap; `stillAnswered` living in the session; the clear after a scan). Update `docs/flow.md` ("App start and resume", "Finding new clips", "Background bridge"). Fill Section 6. Delete the later.md "BackgroundApi must write them there…" item. Commit `feat(background): keep the native copy in step and apply shade actions`, push.

**Mutations:** the cap ignored in `endSessionAt`; the session check removed in `ShadeActions`; the "differs from the last written" check removed (a test counts writes).

---

### Task 7: Notification taps, the Still shooting? dialog, the permission and the help screen (UI)

**Model:** Sonnet.

**Files:** `lib/features/notifications/view_models/notification_access_controller.dart`, `launch_actions.dart`, `still_shooting_prompt.dart`; `views/still_shooting_dialog.dart`, `notifications_help_screen.dart`; `lib/domain/rules/phone_brand.dart`; `lib/features/settings/views/settings_screen.dart` (replaces the placeholder); `shooting_mode_controller.dart`; `reels_screen.dart` (hosts the prompt); router and routes (`Routes.notificationsHelp = '/settings/notifications-help'`); `app.dart`; ARB. Tests and goldens.

**Interfaces:**
- **`NotificationAccessController`** (keepAlive):
  - its state is `NotificationAccess`;
  - `refresh()`, also called on resume from `MediaLifecycle` after the access refresh;
  - `allow()`: request if `canAsk`, else `openNotificationSettings()`;
  - `askOnce()`: on SDK ≥ 33, if not granted and the phone-state key `notificationsAsked` is not set, set it and request; otherwise do nothing.
- **`ShootingModeController._turnOn`:** after `askIfDenied` (video), it calls `askOnce()` (owner ruling). It never throws.
- **`LaunchActionsListener`** (in `app.dart`, under the router): on each `LaunchAction`, `toTag` goes to `Routes.toTag` and `reels` to `Routes.reels`.
- **`StillShootingPrompt`** (a provider plus a widget on the Reels screen):
  - when the Reels screen is visible, after the first frame and on every resume, if `stillShootingDue(state, clock.now())`, it shows the dialog once per app session;
  - **Keep it on**, Back and the barrier call `markStillAnswered`;
  - **Turn off** calls `setOn(false)` and shows the snack "Shooting mode off".
- **`phone_brand.dart`:** `enum PhoneBrand { samsung, xiaomi, oppo, vivo, oneplus }`. `PhoneBrand? brandOf(String maker)` maps:
  - `samsung` to samsung;
  - `xiaomi`, `redmi` and `poco` to xiaomi;
  - `oppo` and `realme` to oppo;
  - `vivo` and `iqoo` to vivo;
  - `oneplus` to oneplus;
  - anything else to null.
- **The help screen** (`routes['notif-help']`):
  - the intro, then the success callout;
  - one `TtExpandCard` per brand, in the prototype's order. The user's brand is open at first and has the badge "Your phone"; an unknown brand starts with all cards closed. Only one card is open at a time.
  - Each body is a `TtStepList` and a tonal button with an `open_in_new` icon:
    - Samsung and Vivo call `openBatterySettings()`;
    - the others call `MediaBridge.openAppSettings()`.
    - A false return shows the snack.
  - The footer note.
- **Settings (interim):** a large app bar "Settings", then the Help group (the help row) and the Permissions group (the Notifications row, from `NotificationAccessController`). Phase 10 adds the rest around them.

- [ ] **Step 1:** Failing tests:
  - `to tag action opens To tag`;
  - `reels action opens Reels`;
  - `action at start is handled once`;
  - `dialog shows when due on Reels`;
  - `dialog shows once per session`;
  - `keep it on marks answered`;
  - `back counts as keep it on`;
  - `turn off turns off and shows the snack`;
  - `not shown before 14 days`;
  - `turning on asks for notifications once on 33+`;
  - `not asked below 33`;
  - `not asked twice`;
  - `Allow opens settings when Android will not ask`;
  - `brand mapping`;
  - `your phone card is open and badged`;
  - `unknown brand opens none`;
  - `one card open at a time`;
  - `samsung button opens battery settings`;
  - `failure shows the snack`;
  - `settings rows and their states`;
  - `help screen 2x no overflow`.
  - Goldens: the help screen (Samsung open; unknown), the dialog, the Settings rows (allowed; not allowed), light and dark, 1× and 2×.
- [ ] **Step 2:** Implement; `tool/check`.
- [ ] **Step 3:** Add **D-107** (where the dialog shows and when; the permission ask once; the interim Settings rows; the brand groups and buttons). Update `docs/flow.md` ("Notification taps", "Still shooting?", "Notifications help"). Fill Section 7. Add to `docs/later.md` Phase 10: onboarding takes over the notification ask; the "Remind me to turn it off" switch feeds `stillReminderEnabled`; the Settings screen grows around the interim rows. Commit `feat(notifications): taps, still shooting, permission and help`, push.

**Mutations:** the dialog shown on every resume; `askOnce` without the stored key; the user's brand not opened.

---

### Task 8: Parked media repairs (data, critical, Opus)

**Model:** Opus.

**Files:** `lib/data/media/library_resync.dart`, `media_scanner.dart`, `lib/data/repositories/clips_repository.dart`, `lib/domain/rules/fingerprint_match.dart` if needed; tests under `test/data/media/` and `test/data/repositories/`.

Each bullet is a `docs/later.md` "Phase 6" item. Fix it, test it, delete the item. M-6 and M-7 move to the Phase 11 section with the reason (rare; the Phase 6 job only counts and never scans).

- **I-3: a resync that ran while Android was still re-indexing.**
  - A detached clip is one with `mediaStoreId < 0` and missing. When a volume's plan is `ScanAfter` (its index is stable) and it has detached clips, the scan re-matches them against `allVideos(volume)`, by the existing unique-fingerprint rule. This runs at most once per scan per volume, and only while such clips exist.
  - For a detached clip D matched to video V:
    - if no clip holds V, D takes V's identity and is no longer missing;
    - if a clip N holds V and N is in no reel, N is deleted (its `inbox` row too) and D takes V's identity: the old clip keeps the user's reels and order, and the duplicate leaves To tag or Skipped;
    - if N is in reels, D gets the union of both clips' reel links, keeping the earliest `addedAt` for each reel, and N is deleted.
  - All of this is in one transaction per volume (`ClipsRepository.reattachDetached(volume, matches)`), and logs counts only.
- **M-8: a volume with no baseline while Shooting mode is on** (the volume read failed at switch-on, or an SD card was inserted later).
  - Instead of starting from now, the scan adds the watched-folder videos on that volume shot at or after the session's `since` (`videosShotSince`, narrowed by `shotAt ≥ since`, and not already a clip). Then it sets the baseline to the captured generation.
  - Rows that hold the baseline (`holdsBaseline`) are not added this time; the baseline holds before the oldest of them, as `advanceBaseline` does.

- [ ] **Step 1:** Failing tests:
  - `detached clip re-attaches when the video appears`;
  - `duplicate in To tag is removed and the reel clip un-missed`;
  - `duplicate in a reel merges links`;
  - `ambiguous fingerprint leaves both`;
  - `no detached clips does not read all videos` (the fake counts calls);
  - `re-match runs once per scan`;
  - `new volume adds clips shot since the session start`;
  - `new volume skips clips shot before`;
  - `new volume skips existing clips`;
  - `new volume pending row holds the baseline`.
- [ ] **Step 2:** Implement; `tool/check`.
- [ ] **Step 3:** Add **D-108** (amends D-72). Update `docs/flow.md` ("Finding new clips"). Fill Section 8. Move M-6 and M-7 in `docs/later.md`. Commit `fix(media): re-attach detached clips, and a new volume starts at the session`, push.

**Mutations:** the union keeps the newer `addedAt`; the new-volume path ignores `since`; the "only while detached clips exist" check removed.

---

### Task 9: On the S24: Patrol flows, timing and the owner's check

**Model:** Opus (phone safety).

**Files:**
- `patrol_test/background_test.dart`; `patrol_test/support/` helpers.
- The debug-only `src/debug/kotlin/app/taketray/DebugBackgroundHooks.kt`: the channel `app.taketray/test_background`, with:
  - `fireEvening`;
  - `fireStill`;
  - `runNewClipsJob` (`JobScheduler` force-run is not available to apps, so it calls the job's work function directly);
  - empty copies in `src/release` and `src/profile`.
- `DebugHooks.kt`; `docs/dev-setup.md` (the Phase 6 check).

- [ ] **Step 1:** Patrol flows. Common setup:
  - only `Movies/TakeTray Test/` watched (`watchOnlyTestFolder`, restored at the end of the body), full access, notifications granted (the system dialog through Patrol);
  - every notification found and tapped by its text only (the phone rule);
  - the test's videos deleted at the end of the body.

  The flows:
  - **`new clips notification appears and opens To tag`:**
    1. Turn Shooting mode on.
    2. Press Home, insert 2 test videos, and wait up to 60 s for "2 new clips to tag", measuring the time from insert to notification (the real content trigger, not the hook).
    3. Tap the notification. The app opens on To tag with the 2 clips, and the notification is gone.
  - **`turning off removes the notification`:** with the notification showing, turn Shooting mode off in the app. The notification is gone.
  - **`evening reminder counts today's clips`:** with 2 clips waiting, call `fireEvening`. The shade shows "You shot 2 clips today. Tag them?", and tapping it opens To tag.
  - **`still shooting turn off from the shade`:**
    1. Call `fireStill`.
    2. Insert 1 video, then tap **Turn off** in the shade.
    3. Insert 1 more video.
    4. Open the app. Shooting mode is off, and only the first video is in To tag.
  - **`still shooting dialog`:** set the session `since` 15 days back (through the repository, in-process), go to Reels. The dialog shows; Keep it on; it does not show again after a resume.
- [ ] **Step 2:** Run on the S24 (`tool/patrol test -t patrol_test/background_test.dart`), and all Patrol files. Then the after-run steps (build debug, `install -r`, `pm clear app.taketray.dev`), **between runs too**. Run `tool/check_release_permissions` and quote the result.
- [ ] **Step 3:** Add the Phase 6 check to `docs/dev-setup.md`. The owner's hand checks:
  - film 3 clips with Shooting mode on and TakeTray closed, and watch the notification;
  - restart the phone, film one more, and watch it update;
  - set the evening time to the next minutes (through the debug build) and wait for it;
  - open the help screen and its Samsung button.

  Record the insert-to-notification times in **D-109** and Section 9. Commit `test(background): Patrol flows on the S24`, push.

**Mutations:** none on the device. The report quotes one run where a deliberate wrong expectation fails, then reverts it.

---

### Task 10: Phase end (docs only, by the controller)

- [ ] **Step 1:** Minors batch (hybrid rule), then the final whole-branch review (Opus), one fix wave, and a separate re-review.
- [ ] **Step 2:** Docs:
  - README: Phase 6 ✅ Done, Phase 7 Next, and a Phase 6 section.
  - The learning guide's intro.
  - `docs/later.md`: delete the Phase 6 section once it is empty; add anything parked (the VN reminder for Phase 8).
- [ ] **Step 3:** CI goldens, CI green, and a PR to `main`. Merge only after the owner says so; then install the release APK over `app.taketray` with `install -r`.
