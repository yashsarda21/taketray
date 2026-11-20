# Phase 9B: Sharing in Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In Instagram (or YouTube, TikTok, any app), Share → TakeTray opens a see-through Save reference sheet over that app. It saves the link to an existing or a new reel, even on a fresh install before onboarding, and Done goes back to where the user was. Done when the build design's Phase 9 holds: "Sharing an Instagram reel saves it".

**Architecture:**
- **Native:**
  - a new exported `ShareActivity` (a `FlutterActivity` with a transparent background) takes `ACTION_SEND` `text/plain`;
  - a new Pigeon `ShareHostApi` hands the shared text to Dart once, finishes the activity, and opens a reel in the app through a new `openReel` launch action.
- **Dart:**
  - a second entry point, `shareMain`, runs a share-only `ShareApp`, which holds only the Save reference sheet;
  - both engines open the database through drift's `shareAcrossIsolates`, proven on an emulator first;
  - the share engine logs to its own `share-*.log` files.
- **App side:**
  - an `openReel` launch action held through onboarding;
  - onboarding's reels step lists existing reels and shows the Instagram tip.

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; Drift (schema v2, unchanged); drift_flutter 0.3.1 (`DriftNativeOptions.shareAcrossIsolates`); go_router; gen-l10n; alchemist goldens (app goldens macOS-only, D-97; package CI goldens by workflow at the end, D-61); Pigeon 29.0.11; Kotlin platform APIs only; Robolectric (`tool/test_android`); Patrol 4.10; the AVD `Pixel_3a_API_32_arm64-v8a` for Task 3's proof.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-9-references-design.md` (the 9B part and the builder-check answers, owner-approved 2026-11-19). The owner approved this plan in advance (2026-11-20: "just continue … wait for my phone again at the end").
- Visual source: `design/prototype/assets/refs.js` (`sheets.saveRef`, `sheets.sysShare`, `RH.findUrl`, `RH.src`, actions `shareToTT`, `saveMode`, `savePick`, `saveRefSave`, `saveDone`, `saveOpenDup`, `saveOpenReel`) and `screens.js` (`routes['ob-reels']`).
- `app.js` flow `reference-first`.
- Phase 9 items: `docs/later.md`.

## Global Constraints

- **Branch:**
  - `phase-9b-sharing`, stacked on `phase-9a-references`, in worktree `.claude/worktrees/phase-9b`;
  - merge `phase-9a-references` in whenever it changes;
  - the PR goes to `main` after #9 has merged;
  - push only at the end.
- **Dependencies:** no new pub package and no new Gradle dependency.
- **Pigeon:** one new file, `pigeons/share_api.dart`.
- **Release permissions unchanged:**
  - `tool/check_release_permissions` must end `RELEASE PERMISSIONS OK`;
  - `ShareActivity` is the only new exported component: one `<intent-filter>` for `android.intent.action.SEND`, category `DEFAULT`, `mimeType="text/plain"`;
  - no streams, images or other MIME types;
  - nothing test-only in `src/main` or `src/release` (test hooks only in `src/debug`).
- **Schema stays v2.** Backup format unchanged.
- **Logs (D-10):** never shared text, a link, a label or a reel name, in either engine. Ids, counts and error types only.
- **The share engine never changes onboarding flags,** never scans media, never arms the background, and shows no splash.
- **Copy:**
  - the prototype's "Recording" is **Collecting**;
  - strings are given in each task, verbatim, through `app_en.arb`;
  - limits: reel name 40, label 60.
- **UI:**
  - design tokens only; 48 dp targets; semantics labels;
  - 200 % text, light and dark, at 360 dp;
  - the share sheet follows the phone's light or dark setting, like the app.
- **Strict TDD:** all edge-case tests red first, record RED, implement once, mutation-check key lines (name the killing test), never weaken a test.
- **Models:**
  - Opus: the implementers of Task 2 (the share entry) and Task 3 (two engines, one database);
  - Sonnet: every other implementer, all fixes, all task reviews and re-reviews;
  - Opus: the final review and its re-review (resume the same reviewer);
  - never Haiku; always pass the model.
- **Review findings:** fix Critical and Important now; park Minors for one batch before the final review.
- **Docs, every task:**
  - its D-number in `docs/decisions.md` (Task 1 D-162 … Task 8 D-169);
  - `docs/flow.md`;
  - its section of `docs/learn/phase-9b-sharing.md`;
  - `docs/later.md`: delete what is done.
- **Devices:**
  - **No phone until the very end** (owner, 2026-11-20). 9A's and 9B's phone checks run together then.
  - Task 3 uses **only the emulator** (`-s emulator-5554`, AVD `Pixel_3a_API_32_arm64-v8a`), with `app.taketray.dev` only.
  - Logcat `--pid=` only. No screenshots.
- **Phone rules (for the end):**
  - only `app.taketray.dev` runs tests; never uninstall or clear `app.taketray`;
  - Patrol uses only `Movies/TakeTray Test/`;
  - `-s RZCY80PHWCZ`;
  - after every Patrol run: debug build, `install -r`, `pm clear app.taketray.dev`;
  - each Patrol file once per round;
  - no test waits on Android's scheduler.
- **Git:**
  - push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`; never force-push; never change git config;
  - commits end `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; the PR ends `🤖 Generated with [Claude Code](https://claude.com/claude-code)`;
  - merging needs the owner's go.

## Review Focus

1. **Odd shared text:**
   - text with no link;
   - several links;
   - a link wrapped in punctuation;
   - a 10,000-character caption;
   - an empty or missing `EXTRA_TEXT`;
   - an `EXTRA_TEXT` that is a `CharSequence` with spans.

   Expected: the first usable http(s) link with a dotted host, or the "This isn't a link" state. No crash and nothing logged but counts. (Tasks 2, 5.)
2. **The share screen's life:**
   - Back, a scrim tap, Done, Cancel and Close all finish it;
   - Android kills the process while the sheet is open;
   - the share is opened twice in a row;
   - a share arrives while TakeTray is open on any screen.

   Expected: TakeTray's own screen is untouched, nothing is left in Recents, and a second share shows its own text. (Tasks 2, 6.)
3. **Two engines, one database:**
   - a reel saved from the share appears on an open Home;
   - the app's write during an open share is seen by the sheet's reel list;
   - either engine is destroyed first.

   Expected: no "database is locked" error and no lost write. (Task 3.)
4. **Saving races:**
   - a double tap on Save;
   - a new reel name taken between typing and Save;
   - the picked reel deleted in the app before Save;
   - the same link saved from two shares.

   Expected: one reel and one reference at most, a clear message, nothing half-saved. (Task 5.)
5. **Before onboarding:**
   - share on a never-opened install, then Done, then open the app → onboarding from the welcome, with the shared reel listed in "Create your reels";
   - Open reel → onboarding, then the reel's References;
   - the app killed during onboarding → the held reel is forgotten, the reel itself saved.

   (Tasks 4, 7.)

---

### Task 1: Scope and docs (controller, no review)

**Files:**
- Modify: `docs/decisions.md` (D-162), `docs/later.md`.
- Create: `docs/learn/phase-9b-sharing.md` (stub: How to read, Contents §2–§9).
- Add: this plan.

- [ ] **Step 1:** Write D-162. It records:
  - the 9B scope;
  - the stacking on 9A;
  - the owner's advance approval and the joint phone run at the end;
  - Task 3's proof-first rule and its fallback (spec);
  - the D-number of each task.
- [ ] **Step 2:** In `later.md`, point the two Phase 9 items (the share handler's first link, the banner margin) at Task 5.
- [ ] **Step 3:** Commit `docs: Phase 9B plan and D-162`.

---

### Task 2: The share entry: `ShareActivity`, `ShareHostApi`, `shareMain`, the share log

**Model:** Opus. **D-163.**

**Files:**
- Create:
  - `app/pigeons/share_api.dart`
  - `app/lib/platform/share_bridge.dart` (and the generated `share_api.g.dart`)
  - `app/android/app/src/main/kotlin/app/taketray/share/ShareActivity.kt`
  - `app/android/app/src/main/kotlin/app/taketray/share/ShareHostApiImpl.kt`
  - `app/lib/share_main.dart`
  - `app/lib/features/share/share_app.dart` (a skeleton; Task 6 fills it)
- Modify:
  - `AndroidManifest.xml`
  - `res/values/styles.xml` and `res/values-night/styles.xml` (a `ShareTheme`)
  - `app/lib/core/logging/log_file_sink.dart` and `logging_setup.dart` (a file prefix)
  - `app/lib/core/logging/log_bundle.dart` (bundles both sets)
- Test:
  - `app/android/app/src/test/kotlin/app/taketray/share/ShareHostApiImplTest.kt`
  - `ManifestTest.kt`
  - `app/test/platform/share_bridge_test.dart`
  - `app/test/core/logging/log_file_sink_test.dart`
  - `log_bundle_test.dart`

**Interfaces:**
- Produces:
  - **Pigeon `ShareHostApi`:**
    - `String? sharedText()`: `Intent.EXTRA_TEXT` read once with `getCharSequenceExtra`, then `toString()`, capped at 20,000 characters, from an `ACTION_SEND` intent of type `text/plain` only. Otherwise null. A second call returns null.
    - `void finish()`: `finishAndRemoveTask()` when the activity is the root of its own task, else `finish()`.
    - `void openReel(int reelId)`: starts `MainActivity` with `LaunchActions.intent(context, LaunchActionMsg.OPEN_REEL, reelId)` (added in Task 4; Task 2 adds the enum value and a stub that Task 4 completes), then finishes.
  - **Dart side:**
    - `abstract interface class ShareBridge { Future<String?> sharedText(); Future<void> finish(); Future<void> openReel(int reelId); }`;
    - `PigeonShareBridge` and `@Riverpod(keepAlive: true) ShareBridge shareBridge(Ref ref)`;
    - a `PlatformException` is logged by code only. `sharedText` answers null on one; `finish` and `openReel` swallow it after logging.
  - **`ShareActivity`:**
    - extends `FlutterActivity`;
    - `getDartEntrypointFunctionName() = "shareMain"`, `getBackgroundMode() = BackgroundMode.transparent`;
    - `shouldAttachEngineToActivity` default; it registers only `ShareHostApi`, `LinksHostApi` and `EditorsHostApi` (for icons), and no media, background, copy or files API;
    - `onNewIntent`: `setIntent`, so a second share replaces the first, and Dart re-reads through `sharedText`.
  - **Manifest:**
    - `android:exported="true"`, `android:excludeFromRecents="true"`, `android:theme="@style/ShareTheme"`;
    - `android:launchMode="standard"`, no `taskAffinity`, so it runs in the sharing app's task;
    - `android:label="@string/app_name"` or the app label;
    - `windowSoftInputMode="adjustResize"`;
    - the one SEND `text/plain` filter;
    - `ShareTheme`: translucent, no title, transparent window background, no splash.
  - **`@pragma('vm:entry-point') Future<void> shareMain()`** in `share_main.dart`:
    - `runAppWithLogging(() => runApp(const ProviderScope(child: ShareApp())), logDir: getApplicationSupportDirectory, filePrefix: 'share')`;
    - no background, media or onboarding providers are read.
  - **Logging:**
    - `LogFileSink(dir, {String prefix = 'taketray', int maxBytes = 512 * 1024, int maxFiles = 2})`; the share engine uses `prefix: 'share'` and `maxBytes: 128 * 1024`;
    - `runAppWithLogging` gains `String filePrefix = 'taketray'`;
    - `LogBundle` joins `taketray-*.log` and then `share-*.log`, each set oldest first.
- [ ] **Step 1: Write the failing tests:**
  - **Kotlin (Robolectric):**
    - `sharedText` on SEND `text/plain` with a String gives the text; with a `SpannableString` gives the plain text;
    - a 30,000-character text is cut to 20,000;
    - `ACTION_VIEW`, `image/*` or no extra gives null;
    - a second call gives null;
    - `onNewIntent` with new text makes `sharedText` give the new text once;
    - `finish` finishes the activity;
    - the manifest has exactly one exported `ShareActivity` with exactly the one filter, `excludeFromRecents`, and no `taskAffinity`.
  - **Dart:**
    - the bridge maps `PlatformException` to null and a logged code; a log test proves no shared text reaches a record;
    - `LogFileSink(prefix: 'share')` writes `share-0.log` and rotates to `share-1.log`;
    - the bundle holds both sets in order, and only `taketray-*` when there is no share log.
- [ ] **Step 2: Run** `../tool/test_android` and `../tool/flutter test test/platform test/core/logging`. Expected: FAIL.
- [ ] **Step 3: Implement.** `ShareApp` is a placeholder for now: a transparent `MaterialApp` with the app's themes and l10n, and an empty body that calls `finish` on Back.
- [ ] **Step 4: Run** `../tool/check`, `../tool/test_android` and `../tool/check_release_permissions`. Expected: all pass and `RELEASE PERMISSIONS OK`.
- [ ] **Step 5: Mutation checks:**
  - the MIME check removed;
  - read-once removed;
  - the 20,000 cap removed;
  - the bundle missing share files.
- [ ] **Step 6: Docs and commit** `feat(share): ShareActivity, share bridge, shareMain and the share log`. D-163; flow.md "Sharing into TakeTray"; guide §2.

---

### Task 3: Two engines, one database (emulator proof first)

**Model:** Opus. **D-164.**

**Files:**
- Modify: `app/lib/data/database/connection.dart`, and (fallback only) `app/lib/app.dart` or a lifecycle helper.
- Test: `app/test/data/database/connection_test.dart`.
- Create (only if kept): a debug-only proof hook under `app/android/app/src/debug/`, or nothing (a throwaway branch for the proof).

**Interfaces:**
- Produces:
  - `appDatabaseProvider` opens `driftDatabase(name: 'taketray', native: const DriftNativeOptions(shareAcrossIsolates: true))`.
  - **Fallback (only if the proof fails):**
    - a plain connection per engine, with WAL and `PRAGMA busy_timeout = 5000`;
    - the app engine calls `db.notifyUpdates({TableUpdate.onTable(db.reels), TableUpdate.onTable(db.reelReferences)})` when the app returns to the front.
- [ ] **Step 1: A VM test** that two `AppDatabase`s on one shared-isolate connection see each other's writes in `watch` streams, and that closing the first keeps the second working. Use drift's documented test setup for a shared isolate; if shared isolates cannot run in the VM, say so in the report and rely on Step 2.
- [ ] **Step 2: The proof on the emulator:**
  - **Setup:**
    - boot `Pixel_3a_API_32_arm64-v8a` headless (`-no-window -no-audio`);
    - install a debug build of a throwaway proof (not committed): `shareMain` writes a reel named "TakeTray Test Proof" on start and logs the reel count; the app engine logs its Home reel count on every emission.
  - **Prove, with `adb -s emulator-5554` and logcat `--pid=` only:**
    - (a) with MainActivity open, `am start` of `ShareActivity` with a SEND intent makes the app engine's count go up while the share is open;
    - (b) finish the share; the app still reads and writes;
    - (c) the share open, then MainActivity finished; the share still writes.
  - **Clean up:** `pm clear app.taketray.dev`; shut the emulator down.
  - **Record** the commands and log lines (counts only) in the report and D-164.
- [ ] **Step 3: Decide:**
  - all three hold → keep `shareAcrossIsolates`;
  - any fails → implement the fallback, re-run (a)–(c) for it, and record why.
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Docs and commit** `feat(share): one database for the app and the share screen`. D-164 holds the proof and the decision; flow.md "Database"; guide §3.

---

### Task 4: The `openReel` launch action, held through onboarding

**Model:** Sonnet. **D-165.**

**Files:**
- Modify:
  - `pigeons/background_api.dart` (`LaunchActionMsg.openReel`)
  - `LaunchActions.kt`
  - `app/lib/platform/background_bridge.dart` (`LaunchAction.openReel`)
  - `app/lib/features/notifications/view_models/launch_actions.dart` (`routeFor`)
  - `app/lib/app.dart` (`LaunchActionsListener`)
  - `ShareHostApiImpl.kt` (complete `openReel`)
- Test:
  - `LaunchActionsTest.kt`
  - `ShareHostApiImplTest.kt`
  - `app/test/features/notifications/view_models/launch_actions_test.dart`
  - `app/test/app_launch_actions_test.dart` (or wherever `LaunchActionsListener` is tested today)

**Interfaces:**
- Produces:
  - **Kotlin:** `LaunchActions.VALUES` gains `"openReel"`. `read` keeps a reel id for `OPEN_REEL` exactly as for `DONE_EDITING` (1..`MAX_REEL_ID`, else no reel), and `intent(…, OPEN_REEL, reelId)` requires a valid id. The identifier is `taketray-open-openReel-<id>`.
  - **`routeFor`:** `openReel` with an existing reel gives `Routes.reelReferences(id)`; with a missing or deleted reel it gives `Routes.reels`.
  - **`LaunchActionsListener`:**
    - an `openReel` launch that arrives while onboarding is not done is kept in memory as the newest held reel and logged ("held", id only);
    - when `onboardingGateProvider` reports done, the held one is opened once;
    - every other action during onboarding is still dropped (D-136);
    - nothing is stored, so a kill forgets it.
- [ ] **Step 1: Write the failing tests:**
  - **Kotlin:** `openReel` with id 7 reads back `OPEN_REEL` and 7; with 0, -1, or above `MAX_REEL_ID` it reads `OPEN_REEL` with no reel; from history (`FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`) it is null; `ShareHostApiImpl.openReel(7)` starts `MainActivity` with those extras and finishes.
  - **Dart:**
    - `routeFor` for an existing and a missing reel;
    - the listener: done → goes at once;
    - not done → nothing until done flips, then it goes once, never twice;
    - two `openReel`s while not done → only the newest;
    - `toTag` while not done → dropped even after done.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Regenerate Pigeon.
- [ ] **Step 4: Run** `../tool/check` and `../tool/test_android`. Expected: pass.
- [ ] **Step 5: Mutation checks:**
  - the hold replaced by drop;
  - opening the held reel twice;
  - the id range check removed.
- [ ] **Step 6: Docs and commit** `feat(share): openReel launch action, held through onboarding`. D-165 (amends D-136 for `openReel` only); flow.md "Launch actions"; guide §4.

---

### Task 5: The Save reference sheet

**Model:** Sonnet. **D-166.**

**Files:**
- Create:
  - `app/lib/features/share/view_models/save_reference_controller.dart`
  - `app/lib/features/share/views/save_reference_sheet.dart`
  - `app/lib/domain/rules/shared_link_kind.dart`
- Modify:
  - `packages/taketray_ui/lib/src/components/banners.dart` (`TtBanner.margin`)
  - `app/lib/domain/rules/reference_links.dart` (display decode, the parked M32)
  - `app/lib/features/references/views/reference_text.dart`
  - `app/lib/l10n/app_en.arb`
- Test:
  - `app/test/features/share/view_models/save_reference_controller_test.dart`
  - `app/test/features/share/views/save_reference_sheet_test.dart` (goldens)
  - `app/test/domain/rules/shared_link_kind_test.dart`
  - `reference_links_test.dart`
  - `packages/taketray_ui/test/components/banners_test.dart`

**Interfaces:**
- Consumes:
  - `pastedLink` (9A: the first http(s) link with a dotted host), `normalizeReferenceUrl`, `shortLink`;
  - `ReferencesRepository.add`, `ReelsRepository.createWithReference`, `watchReelSummaries` (Home's order);
  - `referenceSourceIcon` (9A).
- Produces:
  - **Link kind and display:**
    - `enum SharedLinkKind { instagramReel, instagramPost, instagramVideo, instagramProfile, youtubeShort, youtubeVideo, tiktokVideo, link }` and `SharedLinkKind sharedLinkKindOf(Uri raw)`, read from the **raw** link before normalising:
      - Instagram `/reel/` or `/reels/` → reel; `/p/` → post; `/tv/` → video; other paths → profile;
      - YouTube `/shorts/` → Short;
      - TikTok → video.
    - Copy: "Instagram reel", "Instagram post", "Instagram video", "Instagram profile", "YouTube Short", "YouTube video", "TikTok video", the host for `link`.
    - `shortLink` and `referenceKindText` decode a percent-encoded host for display (M32): `caf%C3%A9.fr/x` shows as `café.fr/x`.
  - **`SaveReferenceController`** (`@Riverpod(retry: noRetry)`, single-flight):
    - **state:** `step` (`form` | `notALink` | `saved`), `url` (normalised), `kind`, `mode` (`existing` | `newReel`), `pickedReelId`, `nameError` (`ReelNameProblem?`), `clashingName`, `alreadyIn` (reel name or null), `failed`, `savedReelId`, `savedReelName`;
    - `start(String? sharedText)`;
    - `setMode`, `pick(int reelId)` (sets `alreadyIn` when that reel has the link);
    - `Future<void> save({required String name, required String label})`.
    - **New reel:** `createWithReference`; a name problem shows on the field. **Existing reel:** `add`; `ReferenceAlreadySaved` sets `alreadyIn`. A reel deleted before Save sets `failed` (the reel is no longer listed). Any other error sets `failed`.
    - **No reels at start** → `mode = newReel` and no switch.
  - **`TtBanner`** gains `EdgeInsetsGeometry? margin` (default unchanged); the later.md item is done.
  - **`Widget SaveReferenceSheet({required VoidCallback onDone, required ValueChanged<int> onOpenReel})`:** the states from the spec and the prototype. Enter in the name or label field saves. The "Welcome to TakeTray" callout shows when `onboardingDone` is false (read once, through `PhoneStateRepository`).
- **Copy (verbatim):**
  - **Form:**
    - title "Save reference"; "Label (optional)" (hint "Fast cuts, food close-ups", counter 60);
    - "Save to"; the switch "Existing reel" / "New reel"; the list headers "Collecting" / "Other reels";
    - each row's subtitle "{count, plural, =0{No references} =1{1 reference} other{{count} references}}";
    - "New reel name" (hint "For example: London Food", counter 40);
    - "Cancel", "Save";
    - the banner "Already saved in {reelName}" / "Pick another reel, or open this one." with "Open reel".
  - **Not a link:**
    - "This isn't a link";
    - "TakeTray saves links to reels and videos. This looks like a caption:" followed by the quoted text, clamped to 4 lines;
    - "In Instagram, tap Share on the reel itself, then choose TakeTray. Nothing was saved.";
    - "Close".
  - **Saved:**
    - "Saved to {reelName}", then the label or the kind text;
    - "Open reel", "Done";
    - callout "Welcome to TakeTray" / "Next time you open the app, it takes about a minute to set up the rest.".
  - **Failure:** "Couldn't save the reference."
- [ ] **Step 1: Write the failing tests:**
  - **`sharedLinkKindOf`:** each kind, plus `instagram.com/someuser/reel/X` → reel.
  - **`start`:**
    - "Title https://vm.tiktok.com/x/" → form, tiktok;
    - "Best breakfast 🔥" → `notALink`;
    - null or "" → `notALink`;
    - "https://hello" → `notALink`;
    - a 10,000-character caption with a link at the end → found.
  - **Save:**
    - **No reels** → new mode; save creates a Collecting reel with the reference.
    - **Existing:**
      - the pick list is ordered Collecting first, then others, in Home's order;
      - a pick that already has the link → `alreadyIn` and Save disabled;
      - save adds and moves the reel to Home's top.
    - **Races:**
      - a double Save → one row;
      - a new reel name that is a duplicate → the field error, nothing saved;
      - a name taken after typing → the duplicate error from the repository;
      - the picked reel deleted → `failed`, no row.
  - **Sheet:**
    - every state's widgets;
    - Enter saves;
    - the welcome callout only when not onboarded;
    - goldens (form existing, form new, no reels, already saved, not a link, saved, saved before onboarding), light and dark, and 200 %.
  - **Display:** `shortLink` decodes the host.
  - **`TtBanner`:** default margin unchanged, and a given margin is applied.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** The sheet is plain Flutter; it does not depend on `ShareBridge` (Task 6 wires it).
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`. Make the package's macOS goldens locally if `TtBanner`'s goldens change; the CI goldens come at the end.
- [ ] **Step 5: Mutation checks:**
  - raw versus normalised kind;
  - `alreadyIn` ignored;
  - single-flight removed;
  - the callout shown when onboarded.
- [ ] **Step 6: Docs and commit** `feat(share): the Save reference sheet`. D-166; flow.md "Sharing into TakeTray"; guide §5; later.md loses the two Phase 9 items.

---

### Task 6: `ShareApp`: the sheet over the sharing app

**Model:** Sonnet. **D-167.**

**Files:**
- Modify: `app/lib/features/share/share_app.dart`, `app/lib/l10n/app_en.arb` (only if new copy).
- Test: `app/test/features/share/share_app_test.dart`.

**Interfaces:**
- Consumes:
  - `ShareBridge` (Task 2);
  - `SaveReferenceSheet` and `SaveReferenceController.start` (Task 5);
  - `TakeTrayTheme`, `AppLocalizations`, `resolvePhoneLocale` (app).
- Produces:
  - **Layout:** a transparent `MaterialApp` (themes, l10n, phone locale) whose home is a dimmed scrim (the theme's `scrim` at the app's sheet opacity) with the sheet at the bottom. The sheet enters as the app's sheets do, and with "Remove animations" there is no animation.
  - **Lifecycle:**
    - on start: `sharedText()` → `controller.start`;
    - a `didChangeAppLifecycleState(resumed)` re-reads `sharedText()`, and a non-null result restarts the sheet with the new text (a second share).
  - **Closing:**
    - Done, Cancel, Close, Back and a scrim tap call `finish()` once;
    - a second call does nothing;
    - a scrim tap or Back during a running save waits for the save, then finishes.
  - **Open reel** (the saved state or the already-saved banner): `openReel(id)`.
  - **Keyboard:** the sheet sits above the keyboard (`adjustResize`), and its fields scroll at 200 %.
  - **Onboarding:** the share engine reads no onboarding flag except through Task 5's callout, and writes none. A test fakes `PhoneStateRepository` and asserts no write.
- [ ] **Step 1: Write the failing tests (with a fake `ShareBridge`):**
  - the shared text reaches the sheet;
  - each close path calls `finish` exactly once;
  - Back during a held save finishes after the save;
  - Open reel calls `openReel(savedId)` and not `finish` separately (native finishes);
  - a resume with new text shows the new link;
  - a resume with null keeps the current sheet;
  - no `PhoneStateRepository` write happens in any path;
  - 200 % with the keyboard inset → no overflow;
  - `disableAnimations` → no ticker.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - the finish-once guard removed;
  - the resume re-read removed.
- [ ] **Step 6: Docs and commit** `feat(share): the share screen over the sharing app`. D-167; flow.md; guide §6.

---

### Task 7: Onboarding: existing reels and the Instagram tip

**Model:** Sonnet. **D-168.**

**Files:**
- Modify:
  - `app/lib/features/onboarding/view_models/reels_step_controller.dart`
  - `app/lib/features/onboarding/views/reels_step_screen.dart`
  - `app/lib/l10n/app_en.arb`
- Test: `app/test/features/onboarding/...reels_step_*` (the existing files) with goldens.

**Interfaces:**
- Consumes: `ReelsRepository.watchAll` or the summaries; `ReferencesRepository.watchCounts`.
- Produces:
  - `ReelsStepState.existing`: `List<({String name, int referenceCount})>`, oldest first;
  - `existingNames` stays as today, derived from it.
  - The screen lists existing reels above the typed names. Each row has a link icon, the name (1 line), "{count, plural, =0{No references} =1{1 reference saved} other{{count} references saved}}", and a check marked "Already created" in semantics, with no remove button.
  - The button rules are unchanged (D-141): with existing reels and nothing typed, it reads "Continue".
  - The tip under the list, always shown: "Tip: share any Instagram reel to TakeTray to save it as a reference." with `Symbols.ios_share_rounded`.
- [ ] **Step 1: Write the failing tests:**
  - existing reels show above typed ones, and are not removable;
  - the counts read 0, 1 and 3;
  - with none, there is no existing block;
  - the tip shows with and without names;
  - "Continue" with existing reels and nothing typed;
  - a reel created while the step is open appears (live);
  - goldens with 1 existing reel plus 2 typed, light and dark, and 200 %.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - existing rows removable;
  - the tip hidden.
- [ ] **Step 6: Docs and commit** `feat(onboarding): reels made by a share and the Instagram tip`. D-168 (amends D-141); flow.md "Onboarding"; guide §7.

---

### Task 8: Patrol flows, debug share hook, guide, README (no device)

**Model:** Sonnet. **D-169.**

**Files:**
- Create:
  - `app/android/app/src/debug/kotlin/app/taketray/DebugShareHooks.kt` (channel `app.taketray/test_share`: `startShare(String text)` starts `ShareActivity` with `ACTION_SEND` `text/plain`)
  - `app/patrol_test/support/test_share.dart`
  - `app/patrol_test/share_test.dart`
- Modify:
  - the debug hook registration (as `DebugHooks.kt` does)
  - `docs/learn/phase-9b-sharing.md` (§8, §9 stub, closing summary)
  - `README.md` (9B built, phone check pending; Next: Phase 11)
  - `docs/dev-setup.md` ("Phase 9B check")

**Interfaces:**
- Produces four flows. The share sheet runs in the **second engine**, so it is driven with `$.native` (UiAutomator, by text and description), and results are read through the app engine's repositories:
  1. **Existing reel:** a test reel exists → `startShare("Look https://www.instagram.com/reel/TTTEST1/?igsh=x")` → tap the reel → Save → "Saved to TakeTray Test Share A" → Done → the app engine sees the reference on that reel.
  2. **New reel:** type "TakeTray Test Share B" → Save → Open reel → the app shows the reel's References with the link.
  3. **Not a link:** the caption alone → "This isn't a link" → Close → no reference was added.
  4. **Before onboarding:**
     - with onboarding not done (set through the repository as in `onboarding_test.dart`), share to a new reel → Open reel → the welcome shows;
     - finish onboarding through the steps → the reel's References;
     - "Create your reels" listed it.
- **Hand checks for "Phase 9B check":**
  1. Real Instagram: share a reel, and Done returns to the same reel in Instagram.
  2. YouTube and TikTok (if installed), from their share sheets.
  3. A share while TakeTray is open on To tag: To tag is untouched after Done.
  4. Recents shows no extra TakeTray entry after a share.
  5. A share on a fresh install (`app.taketray.dev` cleared), then Done, then open the app → onboarding, with the reel listed.
  6. Open reel before onboarding.
  7. A caption share → "This isn't a link".
  8. Dark mode and 200 % text on the sheet.
  9. TalkBack on the sheet.
  10. The keyboard does not cover Save.
  11. The release build over `app.taketray`: TakeTray appears in Instagram's share list, and existing data is kept.
- [ ] **Step 1:** Write the hook with a Robolectric test that it starts `ShareActivity` with the extra, and the Dart wrapper with a unit test.
- [ ] **Step 2:** Write the four flows; `../tool/flutter analyze` clean. Do not run them. Follow 9A's `references_test.dart` safety patterns:
  - "TakeTray Test Share *" reels deleted before and after;
  - tear-downs that run on failure;
  - positive waits before every absent check;
  - onboarding put back to done in the tear-down.
- [ ] **Step 3:** Run `../tool/check_release_permissions`. Expected: `RELEASE PERMISSIONS OK` (the hook is debug-only).
- [ ] **Step 4: Docs and commit** `test(patrol): share flows; Phase 9B guide and README`. D-169.

---

### After Task 8 (controller)

1. The Minors batch, then the Opus final review, one fix wave and the Opus re-review.
2. When #9 merges, merge `main` into this branch and push; the "update goldens" workflow if package goldens changed; CI green; open the PR.
3. The S24, once, for 9A and 9B together (owner, 2026-11-20).
4. Merge on the owner's go: #9 first, then 9B.
