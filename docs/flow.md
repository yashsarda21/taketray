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
3. `app.dart › TakeTrayApp.build`: `ref.watch(appRouterProvider)` and builds `MaterialApp.router` with `AppLocalizations` delegates, locales and `onGenerateTitle` (placeholder theme, phase 1 replaces it).
4. `router/app_router.dart › appRouter` (`appRouterProvider`, kept alive): creates the `GoRouter` with `initialLocation: Routes.reels`, the `redirect` and the `StatefulShellRoute.indexedStack` with branches reels, toTag, settings; disposes the router with the provider.
5. `router/app_router.dart › redirect`: any path that is not a tab root (`/reels`, `/to-tag`, `/settings`) or below one is sent to `Routes.reels`.
6. `features/shell/views/app_shell.dart › AppShell.build`: shows the active branch (`navigationShell`) above the placeholder `NavigationBar`; the branch shows its placeholder screen (`features/{reels,tagging,settings}/views/*_placeholder_screen.dart`), which only prints its localized tab title.

### Tab navigation

1. `features/shell/views/app_shell.dart › NavigationBar.onDestinationSelected`: calls `navigationShell.goBranch(target, initialLocation: target == currentIndex)`. Each branch keeps its own navigator, so a tab returns to where it was; tapping the active tab again resets it to its root.
2. Android back on a tab other than Reels: `GoRouterDelegate.popRoute` first offers the pop to the branch navigator (a pushed route in that tab closes first); if that has nothing to pop, the root navigator reaches `AppShell`'s `PopScope` (`canPop: currentIndex == 0`).
3. `AppShell › PopScope.onPopInvokedWithResult`: when `didPop` is false (index is not 0) it calls `navigationShell.goBranch(0)`, so the app stays open on Reels. On Reels, `canPop` is true and the system closes the app as usual.
4. Code that calls `router.go('/to-tag')` etc. lands on the same branch switch; an unknown path goes through the redirect in "App start" step 5.

### Local checks (`tool/check`)

Run from anywhere; the script changes to the repo root and stops at the first failing step. A fresh clone, or any ARB edit, needs `tool/flutter pub get` (or `tool/flutter gen-l10n`) before analyze or IDE use, because `app/lib/l10n/gen/` is generated, not committed (D-27); `tool/check` does the `pub get` itself.

1. `tool/check` › SDK version: runs `tool/flutter --version`; fails with `Expected Flutter <x>` unless the output contains `Flutter 3.47.7` (`EXPECTED_FLUTTER` in the script).
2. `tool/check` › `tool/flutter pub get` at the root (resolves the whole workspace into the single `pubspec.lock`).
3. `tool/check` › `tool/dart format --output=none --set-exit-if-changed` over those of `app/lib`, `app/test`, `tool` that exist.
4. `tool/check` › `tool/flutter analyze` in `app/` (rules from `app/analysis_options.yaml`).
5. `tool/check` › `tool/dart analyze --fatal-infos` in `tool/` (plain `dart analyze` exits 0 on infos, so the flag keeps the zero-issue bar) (rules from `tool/analysis_options.yaml`).
6. `tool/check` › `tool/dart run taketray_tool:check_styles app/lib/features`:
   1. `tool/bin/check_styles.dart › main`: lists `**/*.dart` under the directory (skips `*.g.dart`, `*.freezed.dart`; a missing directory is clean).
   2. `tool/lib/src/style_rules.dart › findStyleViolations`: per file, blanks comments out of the whole text (`_blankComments`, offsets kept), runs each rule regex over the full text so multi-line calls match, maps each match start to its line, and skips it when `// style-check: allow <reason>` is on that line or on a comment-only line above.
   3. Back in `main`: prints `path:line rule snippet` per violation and exits 1, otherwise exits 0.
7. `tool/check` › `tool/dart test` in `tool/` (includes `tool/test/style_rules_test.dart`).
8. `tool/check` › `tool/flutter test` in `app/`, only if `app/test` contains a `*_test.dart`; otherwise prints `app: no tests yet (skipped)`.
9. `tool/check` › prints `ALL CHECKS PASSED`.

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
2. Same function: sets `FlutterError.onError` (also `presentError` in debug mode) and `PlatformDispatcher.instance.onError` to call `Logger('crash').severe(message, error, stack)`.
3. Same function: enters `runZonedGuarded` (its error handler also calls `Logger('crash').severe`), calls `WidgetsFlutterBinding.ensureInitialized()` inside it, and starts `_attachSink` without awaiting it.
4. Same function: runs `body` immediately, so start-up errors thrown by `body` land in the buffer through step 2/3.
5. `_attachSink` (concurrently): awaits `logDir()` (`path_provider` application support directory, passed in by `main`) with a 5 s timeout. On success it creates the `LogFileSink`, writes the buffered lines in order, switches the subscription to write directly and calls `onSinkReady(sink)` (a throwing callback is ignored). If `logDir()` throws or times out it drops the buffer, disables buffering and prints one `debugPrint` line.

A log record (any `Logger('x').info/warning/severe`):
1. `package:logging › Logger.root.onRecord` delivers the `LogRecord` to the subscription from step 1 above.
2. `core/logging/logging_setup.dart › formatRecord`: `2026-10-24T09:12:03.120Z LEVEL logger: message`, plus indented `error:` and `stack:` lines when present. Message and error text go through `_redact` (paths, URIs become `<path>`; a `FileSystemException` is rendered without its path), stack traces are kept as they are, and a record over 8 KiB is cut with `…[truncated]`.
3. `core/logging/log_file_sink.dart › LogFileSink.write`: chains onto the previous write (writes never interleave), reads the current file size once, then:
   1. if the line would push `taketray-0.log` past `maxBytes` (512 KiB), `_rotate` deletes `taketray-1.log` and renames `taketray-0.log` to `taketray-1.log`;
   2. appends the line to `taketray-0.log` and flushes.

An uncaught error:
1. Flutter framework error → `FlutterError.onError`; async error outside the framework → `PlatformDispatcher.onError` (returns `true`, handled); error escaping `body`'s zone → the `runZonedGuarded` handler.
2. Each calls `Logger('crash').severe(...)`, which continues at "A log record" step 1.

Reading the log: `LogFileSink.readAll` returns `taketray-1.log` then `taketray-0.log` (oldest first); `LogFileSink.exportFile` writes that text to `taketray-log.txt` for the Settings share action (phase 10, using the sink from `onSinkReady`).
