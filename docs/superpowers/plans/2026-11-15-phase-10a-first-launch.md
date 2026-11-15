# Phase 10A: First Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fresh install opens on an animated splash, then the B · Tray welcome with its 3.6 s intro, then asks for video access and notifications in its own words, lets the user plan their reels, and lands on Reels with a one-time Shooting mode tip. Done when first launch works end to end on a fresh install (spec §9 row 10, 10A part).

**Architecture:**
- **Android:** `core-splashscreen` with a `Theme.SplashScreen` launch theme and an `animated-vector` icon; `MainActivity` installs it and fades it out in 200 ms. Nothing else native changes.
- **State:** three phone-state flags (`onboardingDone`, `introPlayed`, `homeTipSeen`) in `PhoneStateRepository`, held by one kept-alive `OnboardingController`. The app defers Flutter's first frame until the flags are read, so the system splash covers the read and no wrong screen flashes.
- **Routing:** four root routes (`/welcome`, `/onboarding/access`, `/onboarding/notifications`, `/onboarding/reels`). One pure redirect function sends every other location to `/welcome` while onboarding is not done, and the onboarding routes to Reels once it is. Steps are pushed, so Back goes to the previous step.
- **Screens:** `lib/features/onboarding/`. The welcome's picture is a static `WelcomeTrayArt` driven by one `AnimationController` (D-133). The Home tip lives on the Reels tab beside the Shooting mode card.

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; go_router; gen-l10n; alchemist goldens (app screen goldens macOS-only, D-97); Kotlin with platform APIs plus `androidx.core:core-splashscreen:1.0.1`; Robolectric 4.17 (`tool/test_android`); Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-11-15-phase-10-onboarding-settings-design.md` (the 10A part, owner-approved 2026-11-15), and through it `design/handoff/launch-and-welcome-motion.md` (D-133: every number for the splash and the intro is there; tasks point at its sections instead of copying them). Visual source: `design/prototype/assets/welcome.js` (B · Tray), `intro.js`, `proto.css` (`.wel-tray`, `.ob`, the "Launch and welcome motion" section), `screens.js` (`obDots`, `ob-video`, `ob-notif`, `ob-reels`, the Home tip at line 152), `app.js` (`obNext`, `askVideo`, `obManual`, `obAddName`, `obCreate`, `obFinish`, `dismissHint`).

## Global Constraints

- One new dependency only: `androidx.core:core-splashscreen:1.0.1` (Gradle). No new pub package. No new Pigeon file.
- Release permissions unchanged: `tool/check_release_permissions` must end `RELEASE PERMISSIONS OK`. No `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, no foreground service.
- Schema stays v2. The flags are rows in the `settings` table through `PhoneStateRepository` (D-71: phone state, never in `SettingsRepository.exportedKeys`).
- No existing behaviour changes for an onboarded user: every existing widget, golden and Patrol test stays green, with onboarding marked done in its harness (Task 3).
- Logs (D-10): never reel names, typed names, video names, paths, URIs or the phone maker. Flags, step names, counts and error types only.
- UI: design tokens only (`tool/check_styles`), every string through `app_en.arb`, 48 dp targets, semantics labels, text scaling to 200 % (the steps scroll; the buttons stay at the bottom), light and dark, reduced motion. Copy is the prototype's, verbatim; new copy is given in the task.
- Strict TDD: write **all** of a change's edge-case tests red first, see them fail, then implement once. Mutation-check the key lines one mutant at a time, naming the test that kills each; a surviving mutant gets a test in the same task. Never weaken a test.
- Models: Tasks 3 and 6 implementers on **Opus**; Tasks 2, 4, 5, 7, 8, 9, 10, on-phone testing, all fixes and every task review and re-review on **Sonnet**; the whole-phase final review and its re-review on **Opus** (re-review resumes the same reviewer). Never Haiku. Always pass the model. A fixer reviews its own fix in per-task rounds; the final fix wave gets a separate re-review.
- Review findings: Critical and Important fixed now; Minors parked for one batch before the final review.
- One agent at a time unless the owner allows parallel work. If allowed, Task 4 (Android only) may run beside Tasks 2–3; expected conflicts: `docs/*`.
- Docs every task: its D-number in `docs/decisions.md` (Task 2 D-135 … Task 10 D-143), `docs/flow.md`, its section of `docs/learn/phase-10a-first-launch.md`, and `docs/later.md` (delete what is done).
- Phone rules: only `app.taketray.dev` runs tests. Never uninstall or clear `app.taketray`. Logcat with `--pid=` only. No screenshots. Never list shared storage or read other apps' files. Pass `-s RZCY80PHWCZ`. After every Patrol run: build debug, `install -r`, `pm clear app.taketray.dev`. Each Patrol file once per round; no test waits on Android's scheduler.
- **Patrol first, phone later:** Task 10 writes every flow with no device and gets it reviewed before the owner is asked for the S24.
- Git: branch `phase-10a-first-launch` from `main`, in the worktree `.claude/worktrees/phase-10a`. Push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push. Never change git config. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; the PR ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Merging needs the owner's go.

## Review Focus

1. **The app is closed or killed in the middle of onboarding** (after Get started, on Android's dialog, after Create but before the flag write finished). The next open shows the welcome's final frame, never Reels, never a half-created set of reels, never a second "Create 3 reels" that makes duplicates. (Tasks 2, 3, 8.)
2. **The flag read or write fails** (database error, corrupt value). A failed read shows the welcome; a failed write still lets the user through this session (the in-memory state wins) and onboarding shows again at most once on the next open; never a blank app, never a loop. (Tasks 2, 3.)
3. **Access changes outside the step:** the user picks "Allow all" in Android settings and comes back; the grant is already full from an earlier install; the user revokes access while the step is open; Android 11's dialog has no "some videos" option. The step always shows what is true now. (Task 7.)
4. **Notification taps and launch actions during onboarding** (a stale copies reminder, a leftover Android back stack, a restored activity): never open a reel or the tag player over onboarding; dropped, not replayed. (Task 3.)
5. **Reel names on step 4:** blanks, 41 characters, emoji, a name already in the list in another case, a name an existing reel already has, tapping Create twice. One reel per name, the existing rules' messages, no duplicate reels. (Task 8.)

---

### Task 1: Scope and docs (controller, no review)

**Files:** `docs/decisions.md` (D-133 amended, D-134), `docs/later.md`, `docs/superpowers/specs/2026-11-15-phase-10-onboarding-settings-design.md`, this plan, the uncommitted D-133 design files from the main checkout (`design/README.md`, `design/prototype/assets/proto.css`, `design/prototype/index.html`, `design/prototype/assets/intro.js`, `design/handoff/launch-and-welcome-motion.md`), `docs/learn/phase-10a-first-launch.md` (stub), the spec's phase table.

- [ ] **Step 1:** Create the branch and worktree; carry the uncommitted D-133 files and the spec and plan into it (leave `marketing/brag/` alone).
- [ ] **Step 2:** D-133: change "to be built next, before Phase 10" to "built in Phase 10A (owner, 2026-11-15: Phase 10 before Phase 9)". D-134 records: the Phase 10 → 9 order and the 10A/10B split; the owner's answers (existing installs get onboarding once; chat-app folders watchable, for 10B); approaches A/A from the design; the calls listed in the design's "builder's note" lines; the D-number of each task (Task 2 D-135 … Task 10 D-143).
- [ ] **Step 3:** `docs/later.md`: remove the section "Next, ahead of the phase order"; under Phase 10 replace the notification-ask and access-ask items with "10A builds onboarding; see D-134" once Task 9 lands (leave a pointer now). Spec phase table: row 9 and 10 order note; row 11 loses "splash".
- [ ] **Step 4:** Guide stub `docs/learn/phase-10a-first-launch.md` with Phase 8's shape ("How to read this guide", Contents, one heading per task 2–10).
- [ ] **Step 5:** Commit `docs: Phase 10A scope, D-133 design files and D-134`.

---

### Task 2: Onboarding flags and creating several reels

**Model:** Sonnet. **D-135.**

**Files:**
- Modify: `app/lib/data/repositories/phone_state_repository.dart`
- Create: `app/lib/features/onboarding/view_models/onboarding_controller.dart`
- Modify: `app/lib/data/repositories/reels_repository.dart`
- Test: `app/test/data/repositories/phone_state_repository_test.dart`, `app/test/features/onboarding/view_models/onboarding_controller_test.dart`, `app/test/data/repositories/reels_repository_test.dart`

**Interfaces:**
- Produces:
  - `PhoneStateRepository`: keys `onboardingDoneKey = 'onboardingDone'`, `introPlayedKey = 'introPlayed'`, `homeTipSeenKey = 'homeTipSeen'`; `Future<bool> onboardingDone()`, `Future<void> markOnboardingDone()`, `Future<bool> introPlayed()`, `Future<void> markIntroPlayed()`, `Future<bool> homeTipSeen()`, `Future<void> markHomeTipSeen()`. Same shape as `folderTipSeen`/`markFolderTipSeen` (unreadable → false, key name logged).
  - `@immutable class OnboardingFlags { const OnboardingFlags({required bool done, required bool introPlayed, required bool homeTipSeen}); }` with `==`/`hashCode`, in `onboarding_controller.dart`.
  - `@Riverpod(keepAlive: true, retry: noRetry) class OnboardingController` → `Future<OnboardingFlags> build()`; `Future<void> markIntroPlayed()`, `Future<void> finish()`, `Future<void> markHomeTipSeen()`. Each mark sets the state **first**, then writes; a failed write is logged by type and the state stays (the session goes on). A failed `build` read gives `OnboardingFlags(done: false, introPlayed: false, homeTipSeen: false)` and logs by type (never an `AsyncError`). Repeated marks write once.
  - `ReelsRepository.createAll(List<String> names) → Future<List<Reel>>`: every name checked as `create` checks it (and against each other by `reelNameKey`), all inserted in **one** transaction in the given order; any problem throws `InvalidInputException` and saves none. Empty list → `[]`, no transaction.

- [ ] **Step 1: Write the failing tests** (all red first):
  - repository: each flag false on an empty table; true after its mark; `"yes"` and `not json` read as false and log the key name only; the three keys are not in `SettingsRepository.exportedKeys`.
  - controller: `build` reads all three; `finish()` → state `done: true` before the write completes (pin with a repository whose write waits on a `Completer`); a throwing write leaves `done: true` and logs `'Saving onboarding failed: <Type>'`; a throwing read → all false, no `AsyncError`; `markIntroPlayed()` twice → one write.
  - `createAll(['Food', 'Goa'])` → two reels, `collecting`, in that order; `createAll(['Food', ' food '])` → `InvalidInputException(ReelNameProblem.duplicate)`, zero reels; a name equal to an existing reel → duplicate, zero new reels; `''` and a 41-character name → `empty`/`tooLong`, zero reels; 40 emoji pass; `[]` → `[]`.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/data/repositories/phone_state_repository_test.dart test/features/onboarding test/data/repositories/reels_repository_test.dart` → FAIL (undefined names).
- [ ] **Step 3: Implement** the interfaces above. Log lines: `'Marked onboarding done'`, `'Marked the intro played'`, `'Marked the Home tip seen'`, `'Created <n> reels'`.
- [ ] **Step 4: Run** the same command → PASS; `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:** state set after the write instead of before; `createAll` outside one transaction (insert one by one); the in-list duplicate check removed. Each must fail a named test.
- [ ] **Step 6: Docs and commit** `feat(onboarding): phone-state flags and creating several reels at once` (D-135, flow.md "Onboarding flags", guide §2).

---

### Task 3: Routes, the redirect and the first frame

**Model:** Opus. **D-136.**

**Files:**
- Modify: `app/lib/router/routes.dart`, `app/lib/router/app_router.dart`, `app/lib/app.dart`
- Create: `app/lib/router/onboarding_redirect.dart`, `app/lib/features/onboarding/views/welcome_screen.dart`, `access_step_screen.dart`, `notifications_step_screen.dart`, `reels_step_screen.dart` (stand-ins in this task: a `Scaffold` with the step's title text and, on the welcome, a working Get started; Tasks 5–8 fill them)
- Modify (harnesses): `app/test/support/vm_harness.dart`, every Patrol file that pumps `TakeTrayApp` (`app_shell_test`, `add_videos_test`, `media_access_test` ×2, `background_test`, `media_scan_test`, `editors_test`, `reels_test`, `tagging_test`), new `app/patrol_test/support/onboarded.dart`
- Test: `app/test/router/onboarding_redirect_test.dart`, `app/test/router/app_router_test.dart`, `app/test/app_test.dart`

**Interfaces:**
- Consumes: `onboardingControllerProvider`, `OnboardingFlags` (Task 2).
- Produces:
  - `Routes.welcome = '/welcome'`, `Routes.onboardingAccess = '/onboarding/access'`, `Routes.onboardingNotifications = '/onboarding/notifications'`, `Routes.onboardingReels = '/onboarding/reels'`, `Routes.isOnboarding(String path) → bool` (the four paths exactly, with or without a query).
  - `String? onboardingRedirect(Uri location, OnboardingFlags? flags)`: `flags == null` (still reading) → null; not done and not an onboarding path → `Routes.welcome`; not done and an onboarding path → null; done and an onboarding path → `Routes.reels`; done otherwise → null.
  - Routes on the root navigator, outside the shell: `WelcomeScreen()`, `AccessStepScreen()`, `NotificationsStepScreen()`, `ReelsStepScreen()`. Steps open with `context.push`; finishing uses `go(Routes.reels)`.
  - `final onboardedOverrides = <Override>[onboardingControllerProvider.overrideWith(() => FixedOnboarding(done: true, introPlayed: true, homeTipSeen: true))]` in `patrol_test/support/onboarded.dart`, and the same in `VmHarness.appOverrides`. `FixedOnboarding` lives in `test/support/fixed_onboarding.dart` (Patrol imports it as the other test supports are shared).

- [ ] **Step 1: Write the failing tests:**
  - `onboarding_redirect_test`: a table over `null`/not done/done × `/reels`, `/reels/5?done=1`, `/to-tag/play?from=3`, `/settings/vn-copies`, `/add-videos`, `/welcome`, `/onboarding/access`, `/onboarding/reels?x=1`, `/nope` with the expected result; `/welcomex` and `/onboarding` are not onboarding paths.
  - `app_router_test`: not done → the app opens on `WelcomeScreen`; `router.go(Routes.reel(5))` → still `WelcomeScreen`; done → `ReelsScreen`, and `go(Routes.welcome)` → `ReelsScreen`; flags changing from not done to done (`finish()`) while on `/onboarding/reels` with `go(Routes.reels)` → `ReelsScreen`; Back on `AccessStepScreen` pushed from the welcome → `WelcomeScreen`.
  - `app_test`: while the controller's `build` waits on a `Completer`, `tester.binding.sendFramesToEngine` is false; after it completes, true. A `build` that never completes → frames allowed after **2 s** (`_firstFrameLimit`), with the not-done flags (welcome). A launch action (`Launch.toTag`) delivered while not done leaves `WelcomeScreen` showing; after `finish()` no tag player opens (dropped, not replayed).
- [ ] **Step 2: Run** `../tool/flutter test test/router test/app_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
  - The router (kept alive) gets `refreshListenable`: a `ValueNotifier<OnboardingFlags?>` fed by `ref.listen(onboardingControllerProvider, …)`, disposed with the router; `redirect` calls `onboardingRedirect(state.uri, notifier.value)` before any route redirect. The router is never rebuilt by a flag change.
  - `TakeTrayApp.initState`: `WidgetsBinding.instance.deferFirstFrame()`; `allowFirstFrame()` exactly once, when the controller first has a value, or after `_firstFrameLimit = Duration(seconds: 2)`, whichever comes first.
  - Update every harness listed above so all existing tests run onboarded.
  - `MediaLifecycle`, `BackgroundSync` and `CopyResultOpener` start as today during onboarding (with no access the scan finds nothing; with Shooting mode off there is no baseline). No change; D-136 says so, and one app test pins that the first scan still runs while the welcome shows.
- [ ] **Step 4: Run** `../tool/check` → `ALL CHECKS PASSED`; `../tool/flutter analyze patrol_test` clean.
- [ ] **Step 5: Mutation checks:** the redirect's done/not-done branches swapped; `isOnboarding` as `startsWith('/onboarding')` (must fail on `/onboardingx`); `allowFirstFrame` called twice (assertion) or never on timeout.
- [ ] **Step 6: Docs and commit** `feat(onboarding): routes, redirect and holding the first frame` (D-136; flow.md "App start" step 3–4 and new "Onboarding redirect"; guide §3).

---

### Task 4: The animated splash

**Model:** Sonnet. **D-137.**

**Files:**
- Modify: `app/android/app/build.gradle.kts` (dependency), `app/android/app/src/main/res/values/styles.xml`, `values-night/styles.xml`, `app/android/app/src/main/kotlin/app/taketray/MainActivity.kt`
- Create: `res/drawable/splash_icon_animated.xml` (and its `animator/` / `interpolator/` files or inline `aapt:attr`), `res/drawable/splash_wordmark.xml` (or density PNGs), `res/values/colors.xml` + `values-night/colors.xml` entries
- Test: `app/android/app/src/test/kotlin/app/taketray/SplashTest.kt`

**Interfaces:** none for Dart.

Everything follows `design/handoff/launch-and-welcome-motion.md` §1 exactly (attributes table, the three groups and their pivot, the seven animations and two interpolators, the exit). Colours: window background = the theme's `primary` (light `#516072`, dark `#B8C8DD` from `TtColors`), icon background = the tray launcher background (`ic_launcher_background.xml`'s colour). Wordmark: "TakeTray" in Plus Jakarta Sans ExtraBold (800), `on-primary`-coloured, 200 × 80 dp branding area; drawn from the font's glyph outlines (a throwaway script outside the repo) or rendered per density, sharp at xxxhdpi. `postSplashScreenTheme` = `@style/NormalTheme`; the manifest keeps `LaunchTheme` as the activity theme and Flutter's `NormalTheme` meta-data.

- [ ] **Step 1: Write the failing Robolectric tests:** on API 31+ and 30 the activity starts with `LaunchTheme` whose parent is `Theme.SplashScreen` and whose `windowSplashScreenAnimationDuration` is 900 (≤ 1000); `splash_icon_animated` inflates as an `AnimatedVectorDrawable` (API 31) with groups `back`, `front`, `tray` and the tray's pivot (54, 82); `MainActivity.onCreate` installs the splash before `super.onCreate` (an `installSplashScreen` spy or the compat `SplashScreen` attached); the exit listener's animation is alpha → 0 over 200 ms and removes the view at the end; no keep-on-screen condition is set.
- [ ] **Step 2: Run** `tool/test_android` → FAIL.
- [ ] **Step 3: Implement** per the handoff.
- [ ] **Step 4: Run** `tool/test_android` → PASS; `tool/check` → `ALL CHECKS PASSED`; `tool/flutter build apk --release` then `tool/check_release_permissions` → `RELEASE PERMISSIONS OK`. Run `./gradlew :app:clean` after mutation runs.
- [ ] **Step 5: Mutation checks:** duration 900 → 1200 (the ≤ 1000 test fails); fade 200 → 0; `installSplashScreen` after `super.onCreate`.
- [ ] **Step 6: Docs and commit** `feat(android): animated splash icon and 200 ms fade` (D-137; flow.md "App start" step 0 (Android, before Dart); guide §4; later.md drops the Phase 11 splash item).

---

### Task 5: The welcome's picture and page (final frame)

**Model:** Sonnet. **D-138.**

**Files:**
- Create: `app/assets/welcome/take_london_food.png`, `take_cinematic.png`, `take_day1_vlog.png`, `take_extra.png` (4th, for Task 7's notification art), each the prototype's `RH.thumb(theme, seed, 'v')` for the welcome's three clips (`welcome.js` `T('food', 52)`, `T('river', 57)`, `T('selfie', 63)`) and one more from `screens.js`'s `ob-notif`, rasterised once at **300 × 534 px** (3× of 100 × 178 dp) by a throwaway script outside the repo; `app/pubspec.yaml` `assets:` (the comment "the app has no assets" is updated, D-40 amended in D-138).
- Create: `packages/taketray_ui/lib/src/components/brand_mark.dart` (`TtBrandMark({required double size})`: the tray launcher icon in a circle, painted from `design/handoff/icons/tray/ic_launcher_foreground.svg`'s paths and its background colour; decoration, excluded from semantics), exported from `taketray_ui.dart`, with a Widgetbook use case and goldens at 28 and 144.
- Create: `app/lib/features/onboarding/views/welcome_tray_art.dart`, `step_dots.dart`; fill `welcome_screen.dart` with the static final frame.
- Test: `app/test/features/onboarding/views/welcome_screen_test.dart`, goldens `welcome_final_{light,dark}`.

**Interfaces:**
- Produces:
  - `class WelcomeTrayArt extends StatelessWidget { const WelcomeTrayArt({required WelcomeArtFrame frame}); }` and `@immutable class WelcomeArtFrame` holding every animated value from the handoff's table (disc scale/opacity, tray dy/opacity/scaleX/scaleY, per take dy/opacity, per tab scale/opacity, `int count`, `double reelsOpacity`, `double glint` (−1…1, null when not sweeping)); `static const WelcomeArtFrame end` (the final frame). Task 6 computes frames; this task only draws them.
  - `class StepDots extends StatelessWidget { const StepDots({required int index, int count = 4}); }`: semantics label "Step {n} of 4".
- Layout from `proto.css` `.wel-tray`: art 372 dp tall on `primaryContainer`, disc 300 dp at right −96 / top −120 (`tertiaryContainer` 0.5 light, `primary` 0.2 dark), takes 100 × 164 dp at left 30/130/230 (scaled to the screen width from a 360 dp design width), bottoms 96/104/96, rotations −8°/1°/8°, the middle one on top; tabs 24 dp tall above each take; the tray 100 dp tall at 18 dp sides, 26 dp from the bottom, trapezoid `0 0, 100% 0, 93% 100%, 7% 100%`, `tertiaryContainer` with a 12 dp inner top shade (on-tertiary-container 12 %), label "23 takes · 3 reels" in label-large, tabular figures, the number right-aligned in 2 ch. Body: `StepDots(index: 0)`, the wordmark row (`TtBrandMark(size: 28)` + "TakeTray" 800 16 sp), headline, text; foot: Get started (filled, large, full width).
- Copy (`app_en.arb`): `welcomeHeadline` "One tray for every take", `welcomeBody` "Film with your phone's camera as usual. New clips land in your tray, ready to sort into the reels you plan.", `welcomeGetStarted` "Get started", `welcomeTakeLondonFood` "London Food", `welcomeTakeCinematic` "Cinematic", `welcomeTakeDayOneVlog` "Day 1 Vlog", `welcomeTakesCount` "{count} takes" (plural), `welcomeReelsCount` " · 3 reels", `welcomeArtLabel` "Three takes standing in a tray, labelled London Food, Cinematic and Day 1 Vlog", `onboardingStepLabel` "Step {step} of {count}".

- [ ] **Step 1: Write the failing tests:** goldens final frame light/dark and at 2× text; semantics: the picture is one image node with `welcomeArtLabel` and no child nodes; headline, body and Get started are present; Get started pushes `Routes.onboardingAccess`; `TtBrandMark` goldens; the wordmark scales with text at 2× without overflow.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Docs and commit** `feat(onboarding): the B · Tray welcome, final frame` (D-138, flow.md "Welcome", guide §5).

---

### Task 6: The welcome intro (3.6 s)

**Model:** Opus. **D-139.**

**Files:**
- Create: `app/lib/features/onboarding/views/welcome_intro.dart`
- Modify: `welcome_screen.dart`
- Test: `app/test/features/onboarding/views/welcome_intro_test.dart`, goldens `welcome_intro_{400,1000,1500,1950,2500,3100}_{light,dark}`

**Interfaces:**
- Consumes: `WelcomeTrayArt`, `WelcomeArtFrame`, `WelcomeArtFrame.end` (Task 5); `onboardingControllerProvider.markIntroPlayed`, `OnboardingFlags.introPlayed` (Task 2).
- Produces: `WelcomeArtFrame welcomeFrameAt(double t)` (`t` = controller value 0…1; pure); `const introDuration = Duration(milliseconds: 3600)` and the other local constants named in the handoff ("Durations").

Everything follows `design/handoff/launch-and-welcome-motion.md` §2: one `AnimationController(duration: introDuration)`, the interval table, the drop `TweenSequence` (70/15/15), the three tray dips, the tab pops, the count, "· 3 reels", the rise of wordmark/headline/text (dots fade only), the glint clipped to the tray, the whole-screen 200 ms fade, and every rule (first launch only, tap to skip, reduced motion, TalkBack with `FadeTransition(alwaysIncludeSemantics: true)`, `TickerMode`, dispose).

- [ ] **Step 1: Write the failing tests:**
  - `welcomeFrameAt`: at 0 every element hidden (disc scale 0.5, opacity 0; takes above the picture; count 0); at 1.0 equals `WelcomeArtFrame.end`; count is 0 before 650 ms, 23 from 1900 ms, monotonic in between; take 1 at 600 + 0.70 × 650 ms is at +6 dp; the tray dips 5 dp at 1050 + 0.4 × 240 ms; the glint is null before 2900 ms and after 3600 ms.
  - The handoff's five widget tests (Get started enabled at value 0; a tap on the picture → value 1; `disableAnimations` → value 1 and no ticker active; flags `introPlayed: true` → value 1; the headline in the semantics tree at value 0).
  - `markIntroPlayed` called once when the intro starts, once when skipped first (not twice); covered by a route (`TickerMode` off) the controller stops; uncovered again → value 1.
  - Goldens at 0.4, 1.0, 1.5, 1.95, 2.5, 3.1 s (`controller.value = t / 3.6`) light and dark, compared by eye against the hub's Motion page frames before committing.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:** count end 23 → 22; skip sets 0.99; the reduced-motion branch calls `forward()`; `alwaysIncludeSemantics` false.
- [ ] **Step 6: Docs and commit** `feat(onboarding): the 3.6 s welcome intro` (D-139; flow.md "Welcome" › intro; guide §6).

---

### Task 7: Video access and notification steps

**Model:** Sonnet. **D-140.**

**Files:**
- Create: `app/lib/features/onboarding/view_models/onboarding_steps.dart`, `app/lib/platform/android_sdk.dart` (`androidSdkProvider`)
- Modify: `access_step_screen.dart`, `notifications_step_screen.dart`, `app_en.arb`
- Test: `app/test/features/onboarding/view_models/onboarding_steps_test.dart`, `.../views/access_step_screen_test.dart`, `notifications_step_screen_test.dart`, goldens for each state light/dark

**Interfaces:**
- Consumes: `MediaAccessController` (`allow()`, state `MediaAccessView`), `NotificationAccessController` (`askOnce()`, state `NotificationAccess` with `sdkInt`, `granted`), `Routes.*` (Task 3), `StepDots` (Task 5), `TtIllustration(kind: permission)`.
- Produces:
  - `enum AccessStep { before, some, denied, allSet }`; `AccessStep accessStepFor(MediaAccessView view, {required bool askedHere})`: full → `allSet`; limited → `some`; denied with `askedHere` or `!canAskAgain` → `denied`; denied otherwise → `before`.
  - `String nextAfterAccess(NotificationAccess? access)`: `null`, `sdkInt < 33` or `granted` → `Routes.onboardingReels`; otherwise `Routes.onboardingNotifications`.
  - `@Riverpod(keepAlive: true) Future<int> androidSdk(Ref ref)`: `(await mediaBridge.accessReport()).sdkInt`.
- Access step (`ob-video`, `StepDots(index: 1)`): art `TtIllustration.permission` on `surfaceContainer` (260 dp), or the success check (success colours) for `allSet`. Buttons per state as in the prototype: `before` → "Allow access" (`allow()`, then `askedHere = true`) and the hint "On the next screen, choose **Allow all**." (`sdk >= 34`) / "**Allow**."; `some` → "Allow all videos" (`allow()`) + "Continue in Manual mode"; `denied` → "Open settings" (`allow()`, which opens the app's page) + "Continue in Manual mode"; `allSet` → "Continue". Continue and Manual mode push `nextAfterAccess(...)`. The screen watches `mediaAccessControllerProvider`; the existing resume refresh (`MediaLifecycle`) updates it. While `allow()` runs the buttons are disabled (a double tap asks once).
- Notifications step (`ob-notif`, `StepDots(index: 2)`): the notification card art (app icon `sell`, "TakeTray · now", "5 new clips to tag", "Tap to tag them into your reels.", four take thumbnails from Task 5 + "+1"; `excludeSemantics`), "Allow notifications" (`askOnce()`, then push reels step whatever the answer) and "Not now" (push reels step). Opened directly on Android 11–12 or when already granted (a leftover route) → it replaces itself with the reels step.
- Copy (verbatim, `screens.js` 79–118): `accessBeforeTitle` "Let TakeTray see your videos", `accessBeforeBody` "To find new clips you shoot, TakeTray needs access to all your videos.", callout "Your videos stay on your phone" / "TakeTray only reads them. It never uploads, moves or deletes them.", `accessAllow` "Allow access", hint "On the next screen, choose {label}."; `accessSomeTitle` "TakeTray can see only some videos", body "You allowed access to selected videos, so TakeTray can't find new clips by itself. You can still add videos yourself. We call this Manual mode.", callout "Want new clips found for you?" / "Choose Allow all in the next step or in Android settings.", "Allow all videos", "Continue in Manual mode"; `accessDeniedTitle` "TakeTray can't see your videos", body "Without video access, new clips aren't found automatically. You can still pick videos yourself in Manual mode.", callout "To allow access later" / "Settings › Apps › TakeTray › Permissions › Photos and videos › {label}.", "Open settings"; `accessAllSetTitle` "All set", body "TakeTray can now find the new clips you shoot while Shooting mode is on.", "Continue"; notifications "Know when clips are waiting", "One quiet notification when new clips are waiting, and a reminder at 9 pm if you haven't tagged them. No sound.", "Allow notifications", "Not now".

- [ ] **Step 1: Write the failing tests:** `accessStepFor` table (3 levels × askedHere × canAskAgain); `nextAfterAccess` (null, 30, 32 not granted, 33 granted, 33 not granted, 35); access screen: each state's title and buttons; the hint says "Allow all" at 34 and "Allow" at 33; "Allow access" calls `allow()` once on a double tap; access already full when opened → "All set" with no ask; the view changing from denied to full while open (resume) → "All set"; full → limited while open → `some`; Continue and Manual mode push the right next route; notifications: Allow calls `askOnce()` once then shows the reels step; Not now never asks; opened with sdk 32 or granted → reels step without showing itself; goldens for `before`/`some`/`denied`/`allSet` and the notifications step, light and dark, and `denied` at 2× text.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:** `!canAskAgain` dropped from `accessStepFor`; `sdkInt < 33` → `<= 33`; the in-flight guard removed.
- [ ] **Step 6: Docs and commit** `feat(onboarding): video access and notification steps` (D-140; flow.md "Onboarding steps"; guide §7).

---

### Task 8: "What reels are you planning?" and finishing

**Model:** Sonnet. **D-141.**

**Files:**
- Create: `app/lib/features/onboarding/view_models/reels_step_controller.dart`
- Modify: `reels_step_screen.dart`, `app_en.arb`
- Test: `app/test/features/onboarding/view_models/reels_step_controller_test.dart`, `.../views/reels_step_screen_test.dart`, goldens

**Interfaces:**
- Consumes: `ReelsRepository.createAll`, `reelNameKey`, `checkReelName`, `reelNameErrorText`'s messages (`reelNameEmpty`, `reelNameTooLong`, `reelNameDuplicate`), `OnboardingController.finish()`, `Routes.reels`, `StepDots(index: 3)`.
- Produces:
  - `@riverpod class ReelsStepController` → state `ReelsStepState { List<String> names; ReelNameProblem? error; String? clashingName; bool hasExistingReels; bool busy; }`; `bool add(String typed)` (true when added; sets `error` otherwise), `void remove(int index)`, `void addIdea(String name)`, `Future<void> create()`, `Future<void> skip()`.
  - `const onboardingIdeas = ['Day 1 Vlog', 'Food', 'Cinematic', 'Behind the scenes', 'Get ready with me']`; shown: the ideas whose `reelNameKey` is not in the list, first four, only while fewer than 5 names.
  - Button rule: names not empty → "Create {count} reels" (plural: "Create 1 reel"); else `hasExistingReels` → "Continue"; else "Create reels", disabled.
  - `create()`: `busy` true; `createAll(names)`; then `finish()`; then the screen goes to `Routes.reels` with the Home tip armed. A second call while busy does nothing. `createAll` throwing `InvalidInputException` (a reel made elsewhere meanwhile) → `error` set, nothing finished. `skip()` and "Continue": `finish()` and go, no reels written.
- Screen (`ob-reels`): body padding-top 28; headline "What reels are you planning?", text "Add the reels for your next trip or shoot. You can change them later.", the field (label "Reel name", hint "London Food", 40-character limit, helper "Press Enter to add the next one", trailing tonal add button "Add reel"; Enter adds and keeps focus), the rows (`radio_button_checked` lead, the name, a close button "Remove {name}"), "Ideas" with the chips; foot: the main button and "Skip for now". The "share any Instagram reel" tip is not built (Phase 9).

- [ ] **Step 1: Write the failing tests:** `add('  Goa ')` stores `Goa`; `add('')` → `empty`; 41 characters → `tooLong`; `add('goa')` after `Goa` → `duplicate` with `clashingName: 'Goa'`; a name an existing reel has → `duplicate`; ideas filter by key and hide at 5 names; the button label for 0/1/3 names with and without existing reels; `create()` twice quickly → one `createAll`; `createAll` throws → error shown, `finish()` not called; `create()` order: `createAll` completes before `finish()`; screen: Enter adds and the field keeps focus, the error text under the field, tapping an idea adds it, Skip for now → `ReelsScreen` with no new reels; goldens empty / three names / with existing reels / error, light and dark, 2× text with the keyboard up (the buttons stay visible).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:** `finish()` before `createAll`; the busy guard removed; the idea filter by exact string instead of key.
- [ ] **Step 6: Docs and commit** `feat(onboarding): plan your reels and finish` (D-141; flow.md "Onboarding steps" › finish; guide §8).

---

### Task 9: The Home tip and the old first-time asks

**Model:** Sonnet. **D-142.**

**Files:**
- Create: `app/lib/features/shooting_mode/views/shooting_tip.dart`
- Modify: `app/lib/features/shooting_mode/views/shooting_mode_section.dart` (or `ReelsScreen`, wherever the card sits), `packages/taketray_ui/lib/src/components/shooting_mode_card.dart` only if a highlight parameter is needed (`highlighted`), `app_en.arb`
- Test: `app/test/features/shooting_mode/views/shooting_tip_test.dart`, `app/test/features/shooting_mode/view_models/shooting_mode_controller_test.dart`, goldens

**Interfaces:**
- Consumes: `OnboardingFlags.homeTipSeen`, `OnboardingController.markHomeTipSeen()`, `ShootingModeController.setOn`.
- Produces: the tip shows when `done && !homeTipSeen` and Shooting mode is off: a tooltip under the Shooting mode card's switch (`screens.js:152`, `.tooltip.right`), title "Going out to shoot?", text "Turn on Shooting mode first. New videos will wait in To tag.", a "Got it" text button; the card highlighted (the prototype's `.shoot.hint`). It never blocks touches outside its own box: the switch under it works. "Got it" or Shooting mode turning on → `markHomeTipSeen()`. TalkBack reads it as a note after the card.

- [ ] **Step 1: Write the failing tests:** shown for done/not seen/off; hidden when seen, when not done, when Shooting mode is on; "Got it" → `markHomeTipSeen` once and hidden; tapping the switch while the tip shows turns Shooting mode on **and** hides the tip; goldens light/dark and 2× text. Old asks: with `notificationsAsked` already true (onboarding asked), turning Shooting mode on calls `requestNotificationAccess` zero times; with it false (Not now), once; turning it on with access `limited` (Manual mode chosen) does not ask (`askIfDenied` asks only on denied), with `denied` and `canAskAgain` asks once (pins today's behaviour; no code change expected).
- [ ] **Step 2: Run** → FAIL (the tip tests; the asks tests may already pass, which is recorded). **Step 3: Implement.** **Step 4: Run** `../tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 5: Docs and commit** `feat(reels): the one-time Shooting mode tip` (D-142; flow.md "Home tip", and the D-107/D-75 ask notes updated; later.md: remove the two "Onboarding takes over …" items; guide §9).

---

### Task 10: Patrol flows and the S24

**Model:** Sonnet. **D-143.**

**Files:**
- Create: `app/patrol_test/onboarding_test.dart`
- Modify: `docs/dev-setup.md` (new "## Phase 10A check" with the hand checks)

**Interfaces:** Consumes the screens' texts; `patrol_test/support/system_dialogs.dart` for Android's permission dialogs.

- [ ] **Step 1: Write the flows with no device:**
  1. Fresh (`pm clear` before the run): welcome → Get started → Allow access → Android dialog "Allow all" → All set → Continue → notifications → Allow → Android dialog Allow → type "TakeTray Test A", Enter, tap idea "Food" → Create 2 reels → Reels shows both and the tip → Got it.
  2. Manual mode: … → Allow access → "Select photos and videos" picking none (or Don't allow) → Continue in Manual mode → Not now → Skip for now → Reels with the Manual mode banner.
  3. Closed midway: Get started → leave with Back to the welcome → restart the app (`$.native.pressHome`, relaunch) → the welcome's final frame (no intro), Get started works.
  Tear-down deletes reels named `TakeTray Test *`. No flow uses `Movies/` at all.
- [ ] **Step 2:** `../tool/flutter analyze patrol_test` clean; offline `../tool/flutter build apk --debug --target=patrol_test/onboarding_test.dart` builds. Sonnet review of the flows (phone safety, flakiness, waits).
- [ ] **Step 3:** Hand checks in `docs/dev-setup.md` "## Phase 10A check": cold start shows the splash animation and fade; the welcome intro plays once; Back from the access step shows the final frame; "Remove animations" on → still splash icon and the welcome's final frame at once; warm start shows no splash; TalkBack reads the welcome's headline straight away; the release build installed with `install -r` over `app.taketray` shows onboarding once (the owner's dummy data stays).
- [ ] **Step 4: Ask the owner for the S24.** Run `tool/patrol test -d RZCY80PHWCZ --target patrol_test/onboarding_test.dart` once; fix and re-run per round; then the debug build, `install -r`, `pm clear app.taketray.dev`. Run every other Patrol file once (the onboarded harness must keep them green).
- [ ] **Step 5: Docs and commit** `test(onboarding): Patrol flows and Phase 10A hand checks` (D-143 with the phone results; guide §10).

---

### Task 11: Minors, final review, README (controller)

- [ ] **Step 1:** One Sonnet batch for the parked Minors.
- [ ] **Step 2:** Opus final review of the whole branch; one fix wave; Opus re-review (same reviewer).
- [ ] **Step 3:** README: Phase 10A ✅ with what it added; "Next: Phase 10B (Settings)". Guide intro and Contents complete.
- [ ] **Step 4:** Push, open the PR to `main`, CI green, owner's hand checks, owner's go to merge; after the merge build the release from `main`, `tool/check_release_permissions`, `install -r` on the S24.
