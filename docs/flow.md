# TakeTray: Code Flow

How execution moves between files and functions in the TakeTray app. Updated by every task that adds or changes a flow, in the same commit as the code.

**Rules for this file**
- One section per flow (app start, scan for new clips, tag a clip, send to VN…).
- Write each flow as numbered steps: `file › function` and what it does or hands on, in call order. Mark the Dart ↔ Kotlin boundary with **[bridge]**.
- Paths are relative to `app/` unless they start with `packages/` or `tool/`.
- When code moves or is renamed, update the flow in the same commit. A flow that no longer matches the code is a bug.

---

## Flows

### App start

1. `main.dart › main`: calls `runAppWithLogging(body, logDir: getApplicationSupportDirectory)` and nothing else; `ensureInitialized` happens inside the guarded zone (see "Error logging").
2. `core/logging/logging_setup.dart › runAppWithLogging`: runs `body` in that zone, which calls `runApp(const ProviderScope(child: TakeTrayApp()))`.
3. `app.dart › TakeTrayApp.build`: `ref.watch(appRouterProvider)` and builds `MaterialApp.router` with `AppLocalizations` delegates, locales, `onGenerateTitle` and the TakeTray themes: `theme: TakeTrayTheme.light()`, `darkTheme: TakeTrayTheme.dark()`; `themeMode` is left at its default, `ThemeMode.system`, so the app follows the phone's light/dark setting (D-50).
4. `router/app_router.dart › appRouter` (`appRouterProvider`, kept alive): creates the `GoRouter` with `initialLocation: Routes.reels`, the `onException` handler and the `StatefulShellRoute.indexedStack` with branches reels, toTag, settings; disposes the router with the provider.
5. `router/app_router.dart › onException`: called by go_router for any location no route matches (unknown top-level paths such as `/nope` and unknown paths below a tab root such as `/reels/stale` or `/to-tag/a/b`); logs `Logger('router').warning` without the location and calls `router.go(Routes.reels)`, so go_router's error page never shows.
6. `features/shell/views/app_shell.dart › AppShell.build`: builds a `Scaffold(extendBody: true)` whose body is the active branch (`navigationShell`) and whose `bottomNavigationBar` is the floating `TtNavPill` (items Reels, To tag, Settings with the `navReels`/`navToTag`/`navSettings` labels; the To tag badge count is a constant 0 until phase 5, and its semantics label is `toTagBadgeSemantics`). The body is wrapped in a `MediaQuery` that gives back the device's plain bottom inset, because `extendBody` otherwise adds the pill's height to it and `TtNavPill.reservedHeight` would count the pill twice (D-50). The branch shows its placeholder screen (`features/{reels,tagging,settings}/views/*_placeholder_screen.dart`): a `Scaffold` with a large `TtAppBar` titled with the localized tab name.

### Tab navigation

1. `packages/taketray_ui/lib/src/components/nav_pill.dart › TtNavPill` (an item's `InkWell.onTap`, selected or not) calls `onSelected(i)`; `features/shell/views/app_shell.dart` passes `(target) =>` which calls `navigationShell.goBranch(target, initialLocation: target == currentIndex)`. Each branch keeps its own navigator, so a tab returns to where it was; tapping the active tab again resets it to its root.
2. Android back on a tab other than Reels: `GoRouterDelegate.popRoute` first offers the pop to the branch navigator (a pushed route in that tab closes first); if that has nothing to pop, the root navigator reaches `AppShell`'s `PopScope` (`canPop: currentIndex == 0`).
3. `AppShell › PopScope.onPopInvokedWithResult`: when `didPop` is false (index is not 0) it calls `navigationShell.goBranch(0)`, so the app stays open on Reels. On Reels, `canPop` is true and the system closes the app as usual.
4. Code that calls `router.go('/to-tag')` etc. lands on the same branch switch; a location no route matches goes through `onException` in "App start" step 5.

### Android back with a menu open

1. `packages/taketray_ui/lib/src/components/menu.dart › _TtMenuButtonState`: `MenuAnchor.onOpen` / `onClose` keep an `_open` flag, which is the `canPop` of a `PopScope` around the anchor (D-51).
2. System back → `GoRouterDelegate.popRoute` (as in "Tab navigation" step 2) offers the pop to the innermost navigator; the route holding the open menu has a `PopScope` with `canPop: false`, so the page does not pop and `onPopInvokedWithResult(didPop: false)` calls `MenuController.close`. The menu closes and the screen stays. With the menu closed `canPop` is true again, so the next back pops the page (or reaches `AppShell`'s `PopScope`) as before.

### System bar icons

1. `packages/taketray_ui/lib/src/components/app_bar.dart › TtAppBar.build`: wraps the bar in `AnnotatedRegion<SystemUiOverlayStyle>` with `ttSystemUiStyle(background)` for the bar's background (`surface`, or `secondaryContainer` in selection mode).
2. `components/video_surface.dart › TtVideoSurface.build`: the same, for the black `videoBackground`.
3. `components/internal/system_ui.dart › ttSystemUiStyle`: `ThemeData.estimateBrightnessForColor(background)`; a light background gives `SystemUiOverlayStyle.dark` (dark icons), a dark one `.light`. It sets `systemNavigationBarIconBrightness` the same way, because the constants assume a black navigation bar, and makes the status bar, navigation bar and divider transparent with `background.withValues(alpha: 0)`.
4. Each frame, Flutter's `RenderView._updateSystemChrome` reads the style at the middle of the status bar (and, on Android, of the navigation bar); a lone region at the top supplies both. The first region found under a screen's `TtAppBar` or `TtVideoSurface` therefore sets the icon colours for that screen (D-51).

### Local checks (`tool/check`)

Run from anywhere; the script changes to the repo root and stops at the first failing step. A fresh clone, or any ARB edit, needs `tool/flutter pub get` (or `tool/flutter gen-l10n`) before analyze or IDE use, because `app/lib/l10n/gen/` is generated, not committed (D-27); `tool/check` does the `pub get` itself.

`tool/check` declares `FLUTTER_MEMBERS=(app packages/taketray_ui widgetbook)` and `DART_MEMBERS=(tool)`. Every listed member must have a `pubspec.yaml`: a missing one fails the check, so a rename or deletion cannot pass silently (D-34).

1. `tool/check` › workspace guard: reads the `workspace:` list in the root `pubspec.yaml` (the `  - x` lines after `workspace:`, up to the first non-list line). Before that, a member listed in both `FLUTTER_MEMBERS` and `DART_MEMBERS` fails with `FAIL: member <x> is listed in both FLUTTER_MEMBERS and DART_MEMBERS in tool/check; it must be in exactly one`. Any entry that is in neither `FLUTTER_MEMBERS` nor `DART_MEMBERS` fails with `workspace member <x> is not covered by tool/check`, so a new member cannot silently escape the checks. Then fails with `FAIL: <kind> member <x> is listed in tool/check but <x>/pubspec.yaml is missing` for any listed member without a `pubspec.yaml`, and with `FAIL: style directory <d> is listed in tool/check but does not exist` for a missing `STYLE_DIRS` entry.
2. `tool/check` › SDK version: runs `tool/flutter --version`; fails with `Expected Flutter <x>` unless the output contains `Flutter 3.47.7` (`EXPECTED_FLUTTER` in the script).
3. `tool/check` › `tool/flutter pub get` at the root (resolves the whole workspace into the single `pubspec.lock`).
4. `tool/check` › `tool/check_generated` (see "Generated-file freshness" below): prints `stale: <path>` and fails when a committed generated file differs from what the generators write now (D-53).
5. `tool/check` › `python3 design/tools/build_tokens.py --check`: regenerates every token output in memory and compares it with disk (see "Token build"); prints `stale: <path>` for each difference and fails, or fails on a contrast failure. Writes nothing (D-35).
6. `tool/check` › `tool/dart format --output=none --set-exit-if-changed` over `lib`, `test`, `patrol_test` of each Flutter member that has them, plus the whole of each Dart member (`tool`).
7. `tool/check` › analyze each member (rules from its own `analysis_options.yaml`): `tool/flutter analyze` in each Flutter member, `tool/dart analyze --fatal-infos` in each Dart member (plain `dart analyze` exits 0 on infos, so the flag keeps the zero-issue bar).
8. `tool/check` › `tool/dart run taketray_tool:check_styles <dir>` for each of `app/lib/features` and `packages/taketray_ui/lib/src/components` (`STYLE_DIRS`):
   1. `tool/bin/check_styles.dart › main`: lists `**/*.dart` under the directory (skips `*.g.dart`, `*.freezed.dart`; a missing directory prints `check_styles: directory <dir> not found` and exits 1).
   2. `tool/lib/src/style_rules.dart › findStyleViolations`: per file, blanks comments out of the whole text (`_blankComments`, offsets kept), runs each rule regex over the full text so multi-line calls match, maps each match start to its line, and skips it when `// style-check: allow <reason>` is on that line or on a comment-only line above. Covered forms: `Color*`/`Colors.`, `TextStyle(`, `EdgeInsets[Directional].*`, `SizedBox(width|height:)` and `SizedBox.square(dimension:)`, `BorderRadius[Directional].circular` and `Radius.circular`, and `Duration(` in any unit from microseconds to days.
   3. Back in `main`: prints `path:line rule snippet` per violation and exits 1, otherwise exits 0.
9. `tool/check` › tests in each Dart member (`tool/dart test`, which includes `tool/test/style_rules_test.dart`, `check_generated_test.dart` and `check_script_test.dart`), then in each Flutter member (`tool/flutter test`). A member without a `test/` folder fails with `<member> has no test/ folder`.
10. `tool/check` › prints `ALL CHECKS PASSED`.

### Generated-file freshness (`tool/check_generated`)

Run by `tool/check` (step 4), or by hand: `tool/check_generated` (all members) or `tool/check_generated app`. Run `tool/flutter pub get` first. See D-53.

1. `tool/check_generated` › start: `cd`s to the repo root and sets `root`. Without arguments it finds every `pubspec.yaml` up to three levels deep (outside `.dart_tool` and `build`) that has a `  build_runner:` line inside its `dev_dependencies:` section (`has_dev_build_runner`); none found prints `no member with build_runner in dev_dependencies found` and exits 1.
2. Per member, `hash_generated`: lists `*.g.dart` and `*.freezed.dart` under `lib/` and `test/`, everything under `drift_schemas/` and everything under `test/drift/` (folders that do not exist are skipped), sorted, and runs `shasum` on each. The result is `path<TAB>sha1` lines, saved as "before".
3. `delete_generated_code`: deletes every `*.g.dart` and `*.freezed.dart` under `lib/` and `test/` (except under `test/drift/`); `drift_schemas/` and `test/drift/` are kept, because old schema dumps cannot be regenerated. A generated file that no generator writes any more therefore stays gone.
4. `(cd <member> && tool/dart run build_runner build)` regenerates the files. If `<member>/build.yaml` exists and contains `databases:`, `tool/dart run drift_dev make-migrations` runs as well. A failing generator fails the script.
5. `hash_generated` again, saved as "after". An `awk` join of the two lists collects every path whose hash changed, that is only in "before" (disappeared, which includes orphans removed in step 3) or only in "after" (appeared). It checks the working tree, not the commit: a fresh file that was never `git add`ed passes.
6. If any path was collected, prints `stale: <path>` for each and `generated files were out of date and have been regenerated; review and commit them` to stderr, exit 1; the regenerated files stay on disk. Otherwise prints `generated files fresh`, exit 0.

`app/lib/l10n/gen/` is not checked: it is git-ignored and rebuilt by `pub get` (D-27).

### Token build (`design/tools/build_tokens.py`)

Run by hand after changing a token: `python3 design/tools/build_tokens.py`. Paths in this flow are relative to the repo root.

1. `design/tools/build_tokens.py` (module level): builds the tonal palettes from the seeds, the colour roles for every brand option (`SCHEMES`) and picks the shipped one (`SHIPPED` → `LIGHT`, `DARK`, `PALETTES`); defines `TYPE`, `SHAPE`, `SPACING`, `ELEVATION`, `MOTION`, `SIZE`, `VIDEO_SURFACE` and `EXTENDED` (REC red, success green).
2. `build_tokens.py › main`: `check_contrast` for the shipped brand and every option; any pair below its WCAG threshold prints `CONTRAST FAILURES` and exits 1 before anything is generated.
3. `build_tokens.py › generate`: clears `OUTPUTS` and runs the writers, each handing its files to `emit(path, text)`: `write_json` (`design/tokens/taketray.tokens.json`, `design/prototype/assets/tokens.js`, `design/tokens/colour-options/*.json`), `write_css` (`design/prototype/assets/tokens.css`), `write_kotlin` (`design/handoff/compose/*.kt`) and `write_dart` (`packages/taketray_ui/lib/src/tokens/tokens.g.dart`: `ttLightScheme`, `ttDarkScheme`, `TtColorTokens`, `TtTypeTokens`, `TtSpaceTokens`, `TtRadiusTokens`, `TtMotionTokens`, `TtSizeTokens`; shipped brand only).
4. Back in `main`: without `--check`, writes every entry of `OUTPUTS`; with `--check`, `stale_outputs` compares each with the file on disk, prints `stale: <path>` for each difference and exits 1 if any (0 otherwise, silently).
5. `packages/taketray_ui/lib/src/theme/take_tray_theme.dart › TakeTrayTheme.light / dark / video`: build (once, cached) `ThemeData` from `ttLightScheme`, or `ttDarkScheme` after `_oled` (tt-style.css §1), or that with `surface` = `TtColorTokens.videoBackground`. `_build` creates `TtThemeData.fromScheme(scheme)` (`tt_theme_data.dart`), which builds `TtColors.fromScheme` (`tt_colors.dart`, scheme roles + `TtColorTokens` + `TtMetrics` opacities) and `TtTextStyles.fromScheme` (`tt_text_styles.dart`, `TtTypeTokens` with the scheme's `onSurface`), and installs it as the theme's only extension, next to the Material component themes (values in `tt_metrics.dart`).
6. `packages/taketray_ui/lib/src/theme/tt_theme_data.dart › TtBuildContext.tt` (in any widget): `Theme.of(context).extension<TtThemeData>()` (throws a `FlutterError` if missing); when `MediaQuery.maybeDisableAnimationsOf(context)` is true, returns `copyWith(motion: TtMotion.reduced)`. `context.scheme` returns `Theme.of(context).colorScheme`.

### Release permission check (`tool/check_release_permissions`)

Run manually (slow: full release build), at the end of every phase. Not part of `tool/check`. See D-31.

1. `android/app/src/main/AndroidManifest.xml`: `<uses-permission INTERNET tools:node="remove"/>` makes the manifest merger drop INTERNET from the merged release manifest; `src/debug` and `src/profile` manifests still declare it.
2. `tool/check_release_permissions` › start: `cd`s to the repo root, resolves the SDK (`$ANDROID_HOME` or `~/Library/Android/sdk`), picks the newest stable `build-tools/x.y.z` (version sort) that has an executable `aapt2`; if none, prints `No Android build-tools with aapt2 found in <dir>` and exits 1.
3. `tool/check_release_permissions` › `(cd app && ../tool/flutter build apk --release)`; exits on failure (`set -e`), then fails if `app/build/app/outputs/flutter-apk/app-release.apk` is missing.
4. `tool/check_release_permissions` › `aapt2 dump permissions` on the APK.
5. If the output contains `android.permission.INTERNET`: prints the list and `INTERNET permission found in release build` to stderr, exit 1.
6. Otherwise prints the permission list and `RELEASE PERMISSIONS OK`, exit 0.

### Error logging

Installed once at start-up by `runAppWithLogging`; `main` calls it in Task 7 of phase 0 and runs the app inside `body`. It never waits for the log directory before starting the app.

Setup:
1. `core/logging/logging_setup.dart › runAppWithLogging`: sets `Logger.root.level = INFO` and subscribes to `Logger.root.onRecord`. Until the sink exists, each record is formatted and held in an in-memory list (max 200); once logging is disabled (step 5) nothing is buffered.
2. Same function: sets `FlutterError.onError` (also `presentError` in debug mode; its record's message is the private `_frameworkErrorTag`, "Flutter framework error") and `PlatformDispatcher.instance.onError` to call `Logger('crash').severe(message, error, stack)`.
3. Same function: enters `runZonedGuarded` (its error handler also calls `Logger('crash').severe`), calls `WidgetsFlutterBinding.ensureInitialized()` inside it, and starts `_attachSink` without awaiting it.
4. Same function: runs `body` immediately, so start-up errors thrown by `body` land in the buffer through step 2/3.
5. `_attachSink` (concurrently): awaits `logDir()` (`path_provider` application support directory, passed in by `main`) with a 5 s timeout. On success it creates the `LogFileSink`, writes the buffered lines in order, switches the subscription to write directly and calls `onSinkReady(sink)` (a throwing callback is ignored). If `logDir()` throws or times out it drops the buffer, disables buffering and prints one `debugPrint` line.

A log record (any `Logger('x').info/warning/severe`):
1. `package:logging › Logger.root.onRecord` delivers the `LogRecord` to the subscription from step 1 above.
2. `core/logging/logging_setup.dart › formatRecord`: `2026-10-24T09:12:03.120Z LEVEL logger: message`, plus indented `error:` and `stack:` lines when present. Message and error text go through `_redact` (paths, URIs become `<path>`; a `FileSystemException` is rendered without its path), stack traces are kept as they are, and a record over 8 KiB is cut with `…[truncated]`.
3. Same listener, debug builds only (`kDebugMode`): `debugPrint`s the formatted line to the console, unless the record is a framework error (its message object is `_frameworkErrorTag`; `presentError` already printed it). Release builds skip this step. The line then goes to the sink if it exists, otherwise to the buffer (or nowhere once logging is disabled).
4. `core/logging/log_file_sink.dart › LogFileSink.write`: chains onto the previous write (writes never interleave), reads the current file size once, then:
   1. if the line would push `taketray-0.log` past `maxBytes` (512 KiB), `_rotate` deletes `taketray-1.log` and renames `taketray-0.log` to `taketray-1.log`;
   2. appends the line to `taketray-0.log` and flushes.

An uncaught error:
1. Flutter framework error → `FlutterError.onError` (prints it to the console with `presentError` in debug); async error outside the framework → `PlatformDispatcher.onError` (returns `true`, handled); error escaping `body`'s zone → the `runZonedGuarded` handler.
2. Each calls `Logger('crash').severe(...)`, which continues at "A log record" step 1; in debug builds the zone and platform errors reach the console at "A log record" step 3.

Reading the log: `LogFileSink.readAll` returns `taketray-1.log` then `taketray-0.log` (oldest first); `LogFileSink.exportFile` writes that text to `taketray-log.txt` for the Settings share action (phase 10, using the sink from `onSinkReady`).

### On-device test (Patrol)

Run by hand on a connected phone (`docs/dev-setup.md`); not part of `tool/check`.

1. `tool/patrol test -t patrol_test/app_shell_test.dart -d <device>`: puts the pinned Flutter (`~/development/flutter/bin`) and the Android SDK `platform-tools` first on `PATH`, sets `PATROL_ANALYTICS_ENABLED=false` (analytics off for this run; see `docs/dev-setup.md` for the config file), `cd`s to `app/`, inserts `--no-uninstall` after `test`/`develop` unless the caller passed `--uninstall` or `--no-uninstall`, and runs `patrol_cli` (`~/.pub-cache/bin/patrol`) with `--flutter-command` set to the pinned `flutter`. The generated `patrol_test/test_bundle.dart` (git-ignored) is deleted when the command exits, so `tool/check` never sees it.
2. `patrol_cli`: reads the `patrol:` block of `pubspec.yaml` (`app_name: TakeTray`, `android.package_name: app.taketray.dev`), generates `test_bundle.dart` from the requested test file and has Gradle build the debug app APK plus the `androidTest` APK. The debug build type adds `applicationIdSuffix = ".dev"` and the launcher label "TakeTray Dev" (`manifestPlaceholders["appLabel"]`, read by `android:label="${appLabel}"` in the manifest), so the app Patrol installs and tests is a second app next to the owner's `app.taketray` (D-52); release and profile builds keep `app.taketray` and "TakeTray".
3. `android/app/build.gradle.kts` › `defaultConfig.testInstrumentationRunner`: the test APK uses `pl.leancode.patrol.PatrolJUnitRunner`; `testOptions.execution = ANDROIDX_TEST_ORCHESTRATOR` runs each test in a fresh process through the `androidTestUtil` orchestrator (`clearPackageData` wipes the data of `app.taketray.dev` between tests, never that of `app.taketray`).
4. **[bridge]** `android/app/src/androidTest/java/app/taketray/MainActivityTest.java › testCases`: starts `MainActivity` through the runner, waits for the Patrol app service in the app process and lists the Dart tests; `runDartTest` then runs one named test.
5. `patrol_test/app_shell_test.dart › main`: `patrolTest` pumps `ProviderScope(child: TakeTrayApp())`, asserts the Reels screen shows "Reels", taps "To tag" then "Settings" inside the `TtNavPill` (`$(TtNavPill).$('To tag')`, by label text) and asserts each placeholder screen shows its title (finders on the English labels, no sleeps; taps settle the UI).
6. `patrol_cli` prints the per-step results and the summary, and writes an HTML report to `app/build/app/reports/androidTests/connected/debug/index.html`. Because of `--no-uninstall` it neither uninstalls before installing nor after the run: `app.taketray.dev` ("TakeTray Dev" on the phone, next to the real TakeTray) and `app.taketray.dev.test` stay on the device (the dev app's data is still cleared by the orchestrator, step 3; the real app is untouched).

### Catalogue coverage (`widgetbook/test/catalog_coverage_test.dart`)

Runs inside `tool/check` (step "test widgetbook") and with `(cd widgetbook && ../tool/flutter test)`. It keeps the Widgetbook catalogue complete (D-42).

1. `widgetbook/test/catalog_coverage_test.dart › main`: lists the `*.dart` files directly in `packages/taketray_ui/lib/src/components/` (none if the folder does not exist yet).
2. Same test: for each name, checks that `widgetbook/lib/components/<name>.dart` exists.
3. `widgetbook/test/catalog_coverage_test.dart › _imports`: checks that `widgetbook/lib/catalog.dart` has an import of `components/<name>.dart` (`package:taketray_widgetbook/components/...`).
4. Same test: `expect(problems, isEmpty)` fails listing every missing file and every missing import; a component without a catalogue file therefore fails `tool/check`.
5. `widgetbook/lib/catalog.dart › ttCatalog`: the registered components, read by `widgetbook/lib/main.dart › TakeTrayCatalogue` (`Widgetbook.material`) when the catalogue runs.
