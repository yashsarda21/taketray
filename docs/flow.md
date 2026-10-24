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

Run from anywhere; the script changes to the repo root and stops at the first failing step.

1. `tool/check` › SDK version: runs `tool/flutter --version`; fails with `Expected Flutter <x>` unless the output contains `Flutter 3.47.7` (`EXPECTED_FLUTTER` in the script).
2. `tool/check` › `tool/flutter pub get` at the root (resolves the whole workspace into the single `pubspec.lock`).
3. `tool/check` › `tool/dart format --output=none --set-exit-if-changed` over those of `app/lib`, `app/test`, `tool` that exist.
4. `tool/check` › `tool/flutter analyze` in `app/` (rules from `app/analysis_options.yaml`).
5. `tool/check` › `tool/dart analyze --fatal-infos` in `tool/` (plain `dart analyze` exits 0 on infos, so the flag keeps the zero-issue bar) (rules from `tool/analysis_options.yaml`).
6. `tool/check` › `tool/dart run taketray_tool:check_styles app/lib/features`:
   1. `tool/bin/check_styles.dart › main`: lists `**/*.dart` under the directory (skips `*.g.dart`, `*.freezed.dart`; a missing directory is clean).
   2. `tool/lib/src/style_rules.dart › findStyleViolations`: per file, per line, strips `//` comments, honours `// style-check: allow <reason>` on the line or the line above, and applies the rule regexes.
   3. Back in `main`: prints `path:line rule snippet` per violation and exits 1, otherwise exits 0.
7. `tool/check` › `tool/dart test` in `tool/` (includes `tool/test/style_rules_test.dart`).
8. `tool/check` › `tool/flutter test` in `app/`, only if `app/test` contains a `*_test.dart`; otherwise prints `app: no tests yet (skipped)`.
9. `tool/check` › prints `ALL CHECKS PASSED`.

