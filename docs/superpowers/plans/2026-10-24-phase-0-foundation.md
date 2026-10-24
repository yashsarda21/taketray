# Phase 0 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `reel-helper/` into a git-tracked pub workspace whose `app/` launches to an empty, localized, router-driven shell (Reels / To tag / Settings), with strict lints, a style check, a rotating local error log, a one-command local check, a release build without `INTERNET`, and Patrol running on the S24 Ultra.

**Architecture:** Pub workspace at `reel-helper/` with two members: `app/` (Flutter app, feature-first) and `tool/` (Dart package for project checks). The prototype code is moved out of `app/lib` into `reference/prototype-app/` (not compiled) to serve as a layout reference for later phases. Riverpod provides DI; go_router's `StatefulShellRoute.indexedStack` provides the three tabs. The shell uses Flutter's stock `NavigationBar` **as a placeholder**; phase 1 replaces it with the TakeTray floating nav pill from the design system.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 (pinned via `tool/flutter`), flutter_riverpod + riverpod_annotation + riverpod_generator + build_runner, go_router, logging, path_provider, flutter_localizations + intl (gen-l10n), very_good_analysis, patrol + patrol_cli.

**Spec:** `reel-helper/docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md` (§3, §5, §6, §7 rule 1, §9 phase 0, §10).

## Global Constraints

- All Flutter/Dart commands go through `tool/flutter` / `tool/dart` (pinned SDK `~/development/flutter`, Flutter **3.47.7**). The `flutter` on PATH is 2.8.1 and must never be used.
- `adb` is called through `tool/adb` (`~/Library/Android/sdk/platform-tools/adb`).
- Dart SDK constraint `^3.13.5`. Android `applicationId` `app.taketray`, `minSdk = 30`. App label "TakeTray".
- **Release build has no `android.permission.INTERNET`**; debug and profile keep it.
- **Fully offline:** no package that sends data off the device (no analytics, crash reporting, remote config).
- No user-facing string literals in widgets; all copy via `AppLocalizations` (English ARB).
- `very_good_analysis` with **zero** analyzer issues; `dart format` clean.
- Feature code (`app/lib/features/**`) obeys the style rule (spec §7 rule 1), enforced by `tool/check_styles`.
- Never commit keystores, `key.properties`, `local.properties`, build output or golden-failure images.
- Git is **local only** in this phase (no remote).
- **Living docs:** any task that makes a meaningful decision adds a `D-xx` entry to `docs/decisions.md` (what, why, alternatives, consequences); any task that adds or changes an execution flow updates `docs/flow.md` (numbered `file › function` steps). Same commit as the code. Reviewers reject a task that skips this.

## Review Focus

1. **Wrong Flutter SDK picked up** (PATH has 2.8.1) → `tool/check` must verify the SDK version first and fail loudly. Test in Task 4.
2. **Unknown deep link** (e.g. a stale notification route) → the app must land on Reels, not a red error screen. Test in Task 7.
3. **Android back on a non-Reels tab** → returns to the Reels tab before leaving the app. Test in Task 7.
4. **Log file growing without bound / logging a crash that happens before `runApp`** → rotation caps disk use at 2 × 512 KB and early errors still reach the file. Tests in Task 6.
5. **A plugin's manifest silently re-adding `INTERNET` to release** (manifest merge) → a release-permission check script fails the build. Task 8.

---

### Task 1: Git baseline, SDK wrappers, prototype moved to `reference/`

**Files:**
- Create: `reel-helper/.gitignore`, `reel-helper/tool/flutter`, `reel-helper/tool/dart`, `reel-helper/tool/adb`, `reel-helper/reference/README.md`
- Move: `app/lib/{data,screens,state,theme,widgets}` and `app/test/{screen_previews_test.dart,widget_test.dart,previews}` → `reference/prototype-app/lib/…` and `reference/prototype-app/test/…`
- Delete: `app/test/failures/`, `app/taketray.iml`
- Modify: `app/lib/main.dart` (temporary minimal app so the project compiles)

**Interfaces:**
- Produces: `tool/flutter`, `tool/dart`, `tool/adb` — executable bash wrappers that `exec` the pinned binaries with `"$@"`. Every later task uses them.

- [ ] **Step 1:** Write the three wrappers (`#!/usr/bin/env bash`, `set -euo pipefail`, `exec "$HOME/development/flutter/bin/flutter" "$@"` etc.), `chmod +x`.
- [ ] **Step 2:** Run `../tool/flutter clean` in `app/` to drop the 3 GB `build/` folder (disk is tight: ~15 GB free). Expected: `app/build` no longer exists.
- [ ] **Step 3:** Write root `.gitignore`: `.DS_Store`, `**/build/`, `**/.dart_tool/`, `**/.flutter-plugins*`, `**/coverage/`, `**/test/failures/`, `*.iml`, `.idea/`, `**/android/local.properties`, `**/android/key.properties`, `*.jks`, `*.keystore`, `**/android/.gradle/`, `.superpowers/sdd/`.
- [ ] **Step 4:** `git init` in `reel-helper/`, `git add -A`, commit `chore: snapshot of prototype and design before rebuild`. Verify `git status` is clean and `git ls-files | grep -c build/` prints `0`.
- [ ] **Step 5:** `git mv` the prototype folders listed above into `reference/prototype-app/`; delete `app/test/failures/` and `app/taketray.iml`. Write `reference/README.md` (2 lines: "Prototype app code kept as a layout reference for phases 1–10. Not compiled or analysed. Delete after phase 10.").
- [ ] **Step 6:** Replace `app/lib/main.dart` with a minimal `runApp(const SizedBox())`-style placeholder that compiles (Task 7 replaces it). Remove `material_symbols_icons` and `shared_preferences` from `app/pubspec.yaml` (unused now; phase 1 re-adds icons). Keep `assets:` and `fonts:` sections.
- [ ] **Step 7:** Run `cd app && ../tool/flutter analyze`. Expected: no errors (lint warnings are fine until Task 3).
- [ ] **Step 8:** Commit `chore: move prototype code to reference/, add pinned SDK wrappers`.

### Task 2: Pub workspace with `app` and `tool` members

**Files:**
- Create: `reel-helper/pubspec.yaml`, `reel-helper/tool/pubspec.yaml`, `reel-helper/tool/lib/taketray_tool.dart`, `reel-helper/tool/test/smoke_test.dart`
- Modify: `app/pubspec.yaml` (add `resolution: workspace`; environment `sdk: ^3.13.5`, `flutter: 3.47.7`)

**Interfaces:**
- Produces: workspace root `pubspec.yaml` (`name: taketray_workspace`, `publish_to: none`, `environment: sdk: ^3.13.5`, `workspace: [app, tool]`); package `taketray_tool` (pure Dart, `resolution: workspace`, dev dependency `test`).

- [ ] **Step 1:** Write `tool/test/smoke_test.dart`: `test('workspace resolves', () => expect(toolPackageName, 'taketray_tool'));`
- [ ] **Step 2:** Run `cd tool && ../tool/dart test`. Expected: FAIL (`toolPackageName` undefined).
- [ ] **Step 3:** Create the root and `tool` pubspecs; in `tool/lib/taketray_tool.dart` define `const toolPackageName = 'taketray_tool';`. Run `tool/flutter pub get` at the root (one lockfile at the root; delete `app/pubspec.lock`).
- [ ] **Step 4:** Run `cd tool && ../tool/dart test` → PASS; `cd app && ../tool/flutter analyze` → no errors.
- [ ] **Step 5:** Commit `build: pub workspace with app and tool packages`.

### Task 3: Strict lints

**Files:**
- Modify: `app/analysis_options.yaml`, create `tool/analysis_options.yaml`
- Modify: `app/pubspec.yaml`, `tool/pubspec.yaml` (dev dependency `very_good_analysis`)

- [ ] **Step 1:** Both `analysis_options.yaml` files: `include: package:very_good_analysis/analysis_options.yaml`; `analyzer: exclude: ["**/*.g.dart", "**/*.freezed.dart", "lib/l10n/gen/**", "build/**"]`. Disable only `public_member_api_docs` in `app` (app code, not a library).
- [ ] **Step 2:** Run `tool/flutter analyze` in `app/` and `tool/dart analyze` in `tool/`. Expected: `No issues found!` in both (fix anything in the placeholder `main.dart`).
- [ ] **Step 3:** Commit `build: very_good_analysis for app and tool`.

### Task 4: Style check (`tool/check_styles`) and the one-command `tool/check`

**Files:**
- Create: `tool/lib/src/style_rules.dart`, `tool/bin/check_styles.dart`, `tool/test/style_rules_test.dart`, `reel-helper/tool/check` (bash)

**Interfaces:**
- Produces:
  - `List<StyleViolation> findStyleViolations(String source, {required String path})` in `style_rules.dart`
  - `class StyleViolation { final String path; final int line; final String rule; final String snippet; }`
  - CLI `tool/dart run taketray_tool:check_styles <dir>` → exit 0 if clean, 1 with `path:line rule snippet` lines otherwise. Scans `**/*.dart` under the given dir, skipping `*.g.dart`, `*.freezed.dart`.
  - `tool/check` — runs, in order, stopping at the first failure: SDK version check (`tool/flutter --version` must contain `Flutter 3.47.7`), `tool/flutter pub get` (root), `tool/dart format --output=none --set-exit-if-changed app/lib app/test tool`, `tool/flutter analyze` (app), `tool/dart analyze` (tool), `check_styles app/lib/features`, `tool/dart test` (tool), `tool/flutter test` (app). Prints `ALL CHECKS PASSED` at the end.

Rules (rule id → what is forbidden on a line, unless the line or the line above contains `// style-check: allow <reason>`):
`raw-color` → `Color(`, `Color.fromARGB(`, `Color.fromRGBO(`, `Colors.` ; `raw-text-style` → `TextStyle(` ; `raw-insets` → `EdgeInsets.` / `EdgeInsetsDirectional.` followed by a numeric literal argument ; `raw-size` → `SizedBox(` with `width:`/`height:` numeric literal ; `raw-radius` → `BorderRadius.circular(` / `Radius.circular(` with a numeric literal ; `raw-duration` → `Duration(` with `milliseconds:`/`seconds:` literal.

- [ ] **Step 1: Write the failing tests** in `style_rules_test.dart`, one per rule plus allow-list and clean cases, e.g.:
```dart
test('flags raw colours', () {
  final v = findStyleViolations('final c = Color(0xFF000000);', path: 'a.dart');
  expect(v.single.rule, 'raw-color');
  expect(v.single.line, 1);
});
test('allows a justified exception', () {
  const src = '// style-check: allow video surface must be pure black\nfinal c = Colors.black;';
  expect(findStyleViolations(src, path: 'a.dart'), isEmpty);
});
test('token-based code is clean', () {
  const src = 'Padding(padding: EdgeInsets.all(context.tt.spacing.m))';
  expect(findStyleViolations(src, path: 'a.dart'), isEmpty);
});
```
Also: `EdgeInsets.symmetric(horizontal: 16)` → `raw-insets`; `SizedBox(height: 8)` → `raw-size`; `SizedBox.shrink()` → clean; `BorderRadius.circular(12)` → `raw-radius`; `Duration(milliseconds: 300)` → `raw-duration`; `TextStyle(fontSize: 14)` → `raw-text-style`; a commented-out line `// Color(0xFF...)` → clean.
- [ ] **Step 2:** Run `cd tool && ../tool/dart test test/style_rules_test.dart` → FAIL.
- [ ] **Step 3:** Implement `findStyleViolations` (line-based regexes; strip `//` comments before matching; honour the allow comment on the same or previous line) and the CLI.
- [ ] **Step 4:** Run the tests → PASS. Run `tool/dart run taketray_tool:check_styles app/lib/features` → exit 0 (folder may not exist yet: treat a missing dir as clean).
- [ ] **Step 5:** Write `tool/check` with the SDK check as its first command (Review Focus 1). Verify the guard: temporarily change the expected version to `9.9.9` → `tool/check` exits non-zero printing `Expected Flutter 9.9.9`. Restore the real value.
- [ ] **Step 6:** Run `tool/check` → `ALL CHECKS PASSED`.
- [ ] **Step 7:** Commit `build: style check and one-command local check`.

### Task 5: Localization (gen-l10n)

**Files:**
- Create: `app/l10n.yaml`, `app/lib/l10n/app_en.arb`
- Modify: `app/pubspec.yaml` (`flutter_localizations`, `intl`; `flutter: generate: true`)
- Test: `app/test/l10n/app_localizations_test.dart`

**Interfaces:**
- Produces: `AppLocalizations` (import `package:taketray/l10n/gen/app_localizations.dart`), with keys `appTitle` = "TakeTray", `navReels` = "Reels", `navToTag` = "To tag", `navSettings` = "Settings", `toTagBadgeSemantics` = "{count} clips to tag" (plural-aware: `=0{No clips to tag} =1{1 clip to tag} other{{count} clips to tag}`).
- `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-dir: lib/l10n/gen`, `output-localization-file: app_localizations.dart`, `nullable-getter: false`.

- [ ] **Step 1:** Write the test: pump a `MaterialApp` with `AppLocalizations.localizationsDelegates`/`supportedLocales`, read `AppLocalizations.of(context)`, expect `navToTag == 'To tag'`, `toTagBadgeSemantics(1) == '1 clip to tag'`, `toTagBadgeSemantics(23) == '23 clips to tag'`.
- [ ] **Step 2:** Run `tool/flutter test test/l10n` → FAIL.
- [ ] **Step 3:** Add config + ARB, run `tool/flutter gen-l10n`.
- [ ] **Step 4:** Run the test → PASS; `tool/check` → passes.
- [ ] **Step 5:** Commit `feat(l10n): English ARB and generated localizations`.

### Task 6: Local error log (rotating file) and error hooks

**Files:**
- Create: `app/lib/core/logging/log_file_sink.dart`, `app/lib/core/logging/logging_setup.dart`
- Test: `app/test/core/logging/log_file_sink_test.dart`, `app/test/core/logging/logging_setup_test.dart`
- Modify: `app/pubspec.yaml` (`logging`, `path_provider`)

**Interfaces:**
- Produces:
  - `class LogFileSink { LogFileSink(Directory dir, {int maxBytes = 512 * 1024, int maxFiles = 2}); Future<void> write(String line); Future<String> readAll(); Future<File> exportFile(); }` — files `taketray-0.log` (current) and `taketray-1.log` (previous). When the current file would exceed `maxBytes`, it becomes `taketray-1.log` (replacing the old one) and a new current file starts. `readAll` returns previous + current, oldest first. `exportFile` writes that into `taketray-log.txt` in the same dir (for the Settings share action in phase 10).
  - `String formatRecord(LogRecord r)` → `2026-10-24T09:12:03.120Z LEVEL logger: message` plus `\n  error: …\n  stack: …` when present.
  - `Future<void> runAppWithLogging(FutureOr<void> Function() body, {required Future<Directory> Function() logDir})` — sets `Logger.root.level = Level.INFO`, wires `Logger.root.onRecord` to the sink, `FlutterError.onError` and `PlatformDispatcher.instance.onError` to `Logger('crash').severe`, and runs `body` inside `runZonedGuarded`. Errors thrown before the sink is ready are buffered and flushed once it is.

- [ ] **Step 1: Failing tests** (`log_file_sink_test.dart`, using `Directory.systemTemp.createTempSync`):
  - writes then `readAll()` returns the line;
  - with `maxBytes: 100`, writing 30 lines of 10 bytes leaves exactly two files, total size ≤ 200, and `readAll()` ends with the last line written;
  - `exportFile()` content equals `readAll()`.
  `logging_setup_test.dart`: inside `runAppWithLogging`, `throw StateError('boom')` asynchronously → after pumping, the sink content contains `SEVERE crash` and `boom`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement. Sink writes are serialized (a single `Future` chain) so concurrent `write` calls never interleave.
- [ ] **Step 4:** Run → PASS. `tool/check` → passes.
- [ ] **Step 5:** Add the "Error logging" flow to `docs/flow.md` (record → `Logger.root.onRecord` → `formatRecord` → `LogFileSink.write` → rotation; and uncaught error → `FlutterError.onError`/`PlatformDispatcher.onError`/zone → `Logger('crash')`).
- [ ] **Step 6:** Commit `feat(core): rotating local error log and global error hooks`.

### Task 7: Riverpod bootstrap and router shell

**Files:**
- Create: `app/lib/app.dart`, `app/lib/router/app_router.dart`, `app/lib/router/routes.dart`, `app/lib/features/shell/views/app_shell.dart`, `app/lib/features/reels/views/reels_placeholder_screen.dart`, `app/lib/features/tagging/views/to_tag_placeholder_screen.dart`, `app/lib/features/settings/views/settings_placeholder_screen.dart`
- Modify: `app/lib/main.dart`, `app/pubspec.yaml` (`flutter_riverpod`, `riverpod_annotation`; dev: `riverpod_generator`, `build_runner`, `riverpod_lint` is optional — skip; `go_router`)
- Test: `app/test/router/app_router_test.dart`, `app/test/app_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class Routes { static const reels = '/reels'; static const toTag = '/to-tag'; static const settings = '/settings'; }`
  - `@riverpod GoRouter appRouter(Ref ref)` → `appRouterProvider`; `initialLocation: Routes.reels`; `StatefulShellRoute.indexedStack` with three branches in this order: reels, toTag, settings; unknown locations redirect to `Routes.reels`.
  - `class AppShell extends StatelessWidget { const AppShell({required this.navigationShell}); }` — `Scaffold` with the branch body and a stock `NavigationBar` (placeholder, phase 1 swaps it) with labels from `AppLocalizations` (`navReels`, `navToTag`, `navSettings`). Android back on branch index ≠ 0 goes to branch 0 (via `PopScope`).
  - `class TakeTrayApp extends ConsumerWidget` → `MaterialApp.router(title: 'TakeTray' via l10n onGenerateTitle, routerConfig: ref.watch(appRouterProvider), localizationsDelegates/supportedLocales from AppLocalizations, theme: ThemeData(useMaterial3: true), darkTheme: ThemeData.dark(useMaterial3: true), themeMode: ThemeMode.system, debugShowCheckedModeBanner: false)`. Theme is a placeholder replaced in phase 1.
  - `main()` → `runAppWithLogging(() => runApp(const ProviderScope(child: TakeTrayApp())), logDir: getApplicationSupportDirectory)`.
  - Each placeholder screen shows only its localized tab title (no other copy).

- [ ] **Step 1: Failing tests:**
  - `app_test.dart`: pump `ProviderScope(child: TakeTrayApp())`; expect text `Reels` in the body; tap the `To tag` destination → body shows the To tag placeholder; tap `Settings` → Settings placeholder.
  - `app_router_test.dart`: `router.go('/to-tag')` shows To tag; `router.go('/nope')` shows Reels (Review Focus 2); on the To tag tab, simulate system back (`tester.binding.handlePopRoute()`) → Reels tab is selected and the app did not pop (Review Focus 3); switching tabs keeps each branch's own navigation stack (push a dummy route in Reels branch in the test, switch away and back, it is still there).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement; run `tool/dart run build_runner build --delete-conflicting-outputs` in `app/`. Generated `*.g.dart` files are committed.
- [ ] **Step 4:** Run tests → PASS. `tool/check` → passes.
- [ ] **Step 5:** `tool/flutter run -d <S24 serial>` (see Task 9 for the device) or the `Pixel_3a_API_32_arm64-v8a` emulator: the app opens on Reels, the three tabs switch. Note the result in the report.
- [ ] **Step 6:** Add "App start" (`main` → `runAppWithLogging` → `ProviderScope` → `TakeTrayApp.build` → `appRouterProvider` → `AppShell`) and "Tab navigation" (destination tap → `navigationShell.goBranch`; back on a non-Reels tab → `PopScope` → branch 0) to `docs/flow.md`. Add a decision entry for the placeholder `NavigationBar` (replaced in phase 1).
- [ ] **Step 7:** Commit `feat: Riverpod bootstrap and go_router tab shell`.

### Task 8: Release build without `INTERNET`

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml` (add `xmlns:tools` and `<uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>`)
- Verify: `app/android/app/src/debug/AndroidManifest.xml` and `profile/AndroidManifest.xml` still declare `INTERNET`
- Create: `reel-helper/tool/check_release_permissions` (bash)

**Interfaces:**
- Produces: `tool/check_release_permissions` — builds `tool/flutter build apk --release` in `app/`, dumps permissions with `~/Library/Android/sdk/build-tools/<latest>/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk`, fails (exit 1, message `INTERNET permission found in release build`) if `android.permission.INTERNET` appears, otherwise prints the permission list and `RELEASE PERMISSIONS OK`. Not part of `tool/check` (slow); run at the end of every phase.

- [ ] **Step 1:** Run the script before the manifest change → it must FAIL with the INTERNET message (the Flutter template adds INTERNET to debug only, but plugins may merge it; if it already passes, record that and continue).
- [ ] **Step 2:** Add the `tools:node="remove"` line.
- [ ] **Step 3:** Run the script → `RELEASE PERMISSIONS OK`. Run `tool/flutter build apk --debug` and confirm with `aapt2` that debug **does** contain INTERNET (hot reload still works).
- [ ] **Step 4:** Commit `build: strip INTERNET from release, add release permission check`.

### Task 9: Devices and Patrol smoke test

**Files:**
- Modify: `app/pubspec.yaml` (dev: `patrol`; `patrol:` config block with `app_name: TakeTray`, `android: package_name: app.taketray`)
- Create: `app/patrol_test/app_shell_test.dart`, Android test instrumentation files required by Patrol's setup guide (`app/android/app/src/androidTest/java/app/taketray/MainActivityTest.java`, `build.gradle(.kts)` changes: `testInstrumentationRunner "pl.leancode.patrol.PatrolJUnitRunner"`, `testOptions { execution "ANDROIDX_TEST_ORCHESTRATOR" }`, `androidTestUtil` orchestrator dependency)
- Create: `reel-helper/tool/patrol` (wrapper: runs `patrol` CLI with the pinned Flutter via `--flutter-command`/`PATH` override so it never picks 2.8.1)
- Create: `reel-helper/docs/dev-setup.md` (devices, emulators, commands)

**Interfaces:**
- Produces: `tool/patrol test -t patrol_test/app_shell_test.dart -d <device>`; the smoke test launches the app, taps `To tag` and `Settings` via Patrol finders and asserts each placeholder title.

- [ ] **Step 1:** Install the CLI: `tool/dart pub global activate patrol_cli` (version matching the `patrol` package). Write the wrapper so `patrol doctor` reports Flutter 3.47.7.
- [ ] **Step 2:** **Ask the owner to connect the S24 Ultra** (USB debugging on, Samsung Auto Blocker off). `tool/adb devices` must list `RZCY80PHWCZ`. If it doesn't, stop this step and report `BLOCKED: device not connected`.
- [ ] **Step 3:** Emulators: check free disk (`df -h /`). Only if ≥ 20 GB free, create AVDs for API 30 and API 34+ (Google APIs, arm64) with `sdkmanager`/`avdmanager`; otherwise use the existing `Pixel_3a_API_32_arm64-v8a` and record "API 30 and 34+ emulators deferred: low disk" in the report. Document what exists in `docs/dev-setup.md`.
- [ ] **Step 4:** Write the Patrol smoke test; run it on the S24 → PASS; run it on one emulator → PASS.
- [ ] **Step 5:** Commit `test: Patrol harness with app shell smoke test`.

---

## Phase 0 owner check (end of phase, on the S24 Ultra)

1. Fresh install opens on **Reels**; tabs **Reels / To tag / Settings** switch; back from To tag returns to Reels, back again leaves the app.
2. The app name under the icon is **TakeTray**.
3. `tool/check` prints `ALL CHECKS PASSED`; `tool/check_release_permissions` prints `RELEASE PERMISSIONS OK`.
4. `git log --oneline` shows one commit per task.
