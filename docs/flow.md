# TakeTray: Code Flow

How execution moves between files and functions in the TakeTray app. Updated by every task that adds or changes a flow, in the same commit as the code.

**Rules for this file**
- One section per flow (app start, scan for new clips, tag a clip, send to VN…).
- Write each flow as numbered steps: `file › function` and what it does or hands on, in call order. Mark the Dart ↔ Kotlin boundary with **[bridge]**.
- Paths are relative to `app/` unless they start with `packages/` or `tool/`.
- When code moves or is renamed, update the flow in the same commit. A flow that no longer matches the code is a bug.

---

## Flows

*(Phase 0 adds "App start" and "Tab navigation".)*

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

### Error logging

Installed once at start-up by `runAppWithLogging`; `main` calls it in Task 7 of phase 0 and runs the app inside `body`.

Setup (synchronous part first, so nothing is missed while the directory resolves):
1. `core/logging/logging_setup.dart › runAppWithLogging`: sets `Logger.root.level = INFO` and subscribes to `Logger.root.onRecord`. Until the sink exists, each record is formatted and held in an in-memory list (max 200).
2. Same function: sets `FlutterError.onError` and `PlatformDispatcher.instance.onError` to call `Logger('crash').severe(message, error, stack)`.
3. Same function: awaits `logDir()` (`path_provider` application support directory, passed in by `main`), creates the `LogFileSink`, writes the buffered lines in order, then switches the subscription to write directly. If `logDir()` throws, the buffer is dropped and the app still runs.
4. Same function: runs `body` inside `runZonedGuarded`, whose error handler also calls `Logger('crash').severe`.

A log record (any `Logger('x').info/warning/severe`):
1. `package:logging › Logger.root.onRecord` delivers the `LogRecord` to the subscription from step 1 above.
2. `core/logging/logging_setup.dart › formatRecord`: `2026-10-24T09:12:03.120Z LEVEL logger: message`, plus indented `error:` and `stack:` lines when present.
3. `core/logging/log_file_sink.dart › LogFileSink.write`: chains onto the previous write (writes never interleave), reads the current file size once, then:
   1. if the line would push `taketray-0.log` past `maxBytes` (512 KiB), `_rotate` deletes `taketray-1.log` and renames `taketray-0.log` to `taketray-1.log`;
   2. appends the line to `taketray-0.log` and flushes.

An uncaught error:
1. Flutter framework error → `FlutterError.onError`; async error outside the framework → `PlatformDispatcher.onError` (returns `true`, handled); error escaping `body`'s zone → the `runZonedGuarded` handler.
2. Each calls `Logger('crash').severe(...)`, which continues at "A log record" step 1.

Reading the log: `LogFileSink.readAll` returns `taketray-1.log` then `taketray-0.log` (oldest first); `LogFileSink.exportFile` writes that text to `taketray-log.txt` for the Settings share action (phase 10).
