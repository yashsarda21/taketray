# TakeTray: Decisions

A log of the meaningful decisions behind TakeTray: what we chose, why, and what we gave up. Newest decisions go at the bottom of their section. When a decision changes, don't delete the old entry; mark it **Superseded by D-xx** and add the new one.

**Format of an entry**

```
### D-xx · Title
- Date: YYYY-MM-DD · Phase/Task: …
- Decision: what we chose.
- Why: the reasons.
- Alternatives considered: what else, and why not.
- Consequences: what this commits us to, or makes harder.
```

---

## Product

### D-01 · Film with the phone's normal camera, never an in-app camera
- Date: 2026-10-22 · Phase: brainstorming
- Decision: TakeTray never records video. Users film with the built-in camera app; TakeTray detects the new videos.
- Why: the built-in camera keeps full quality and every mode (4K/60, slo-mo, cinematic). Android's camera "capture intent" gives a stripped-down camera and one clip per round trip.
- Alternatives considered: capture intent (lower quality, slow); a custom camera (months of work, can't match the stock camera).
- Consequences: we depend on detecting new gallery videos reliably (see D-08).

### D-02 · Tag after shooting, with a manual Shooting mode switch
- Date: 2026-10-23 · Phase: brainstorming
- Decision: while Shooting mode is on, every new video lands in To tag; the user tags each clip into one or more reels, or skips it. Videos shot before switching it on are ignored.
- Why: creators tag in spare moments (bus, train, evening), not at a fixed time; an "active reel" mode was rejected because clips for different reels get mixed within minutes.
- Alternatives considered: active reel assigned by time (rejected by the owner); always-on watching (fills To tag between trips).
- Consequences: the tag player must be fast (auto-advance, "Same as previous", scenes).

### D-03 · Videos only in version 1
- Date: 2026-10-23 · Phase: brainstorming
- Decision: v1 handles videos; photos later.
- Why: creators shoot hundreds of photos, which would bury the to-tag list; videos are the reel material.
- Consequences: data model should not block photos later.

### D-04 · Never copy, move or delete the user's originals
- Date: 2026-10-23 · Phase: brainstorming
- Decision: reels store references to gallery videos. A clip can be in several reels. Removing it from a reel or deleting a reel never touches the video. Only exception: temporary VN copies (D-05).
- Why: no storage cost, no risk to the user's footage, trust.
- Consequences: references can break (deleted videos → grey "Missing clip" tile); fingerprints guard against pointing at the wrong video.

### D-05 · Editor handoff: direct share for CapCut and Edits, temporary copy folder for VN
- Date: 2026-10-23 · Phase: brainstorming
- Decision: CapCut and Instagram Edits receive the original clips via multi-video share (no copies). VN gets copies in `Movies/TakeTray/<Reel>`, deleted only after the user confirms export ("Done editing").
- Why: VN accepts one shared video at a time and opens a new project per share (tested by the owner); its picker does show gallery folders (tested). CapCut and Edits accept several videos at once (tested).
- Alternatives considered: moving originals into a folder (breaks for clips in several reels, Google Photos backup risk); generating editor project files (formats are private).
- Consequences: storage cost only while editing VN; space check and reminders needed.

### D-06 · Reference reels are links only
- Date: 2026-10-23 · Phase: design add-on 1
- Decision: an Instagram reel shared into TakeTray is saved as a link (plus an optional label) on a reel. Never downloaded, never previewed.
- Why: Instagram doesn't allow other apps to download or fetch reels; link-only keeps us within the rules and offline.
- Consequences: reference cards are designed placeholders, not thumbnails.

### D-07 · Name: TakeTray
- Date: 2026-10-23 · Phase: naming
- Decision: the app is called TakeTray ("takes" collected in a tray). Tagline "Shoot now. Sort later." Icon: the tray concept.
- Why: short, memorable, no app found with that name; avoids Instagram trademarks ("Insta", "Gram").
- Consequences: the project folder stays `reel-helper` (owner's choice).

### D-08 · Reel statuses: Collecting, Ready to edit, Published
- Date: 2026-10-24 · Phase: build brainstorming
- Decision: the first status is "Collecting" (was "Recording").
- Why: "Recording" blurred with "Shooting mode".

## Privacy and business

### D-09 · Fully offline; release build has no INTERNET permission
- Date: 2026-10-24 · Phase: build brainstorming
- Decision: no analytics, crash reporting or network calls. The release manifest removes `INTERNET`.
- Why: the promise "your videos never leave your phone"; Android itself then guarantees it; Play data safety can say "no data collected".
- Alternatives considered: Firebase Crashlytics / Sentry (data leaves the phone, must be declared).
- Consequences: bugs are found through a local error log the user can share (D-10).

### D-10 · Local error log, shared manually
- Date: 2026-10-24 · Phase: build brainstorming
- Decision: a rotating log file (2 × 512 KB) in app storage; Settings lets the user send it via the share sheet.
- Why: replaces crash reporting without breaking D-09.

### D-11 · Version 1 is free, no payments
- Date: 2026-10-24 · Phase: build brainstorming
- Decision: no Play Billing in v1; code must not make adding it later hard.

## Engineering

### D-12 · Flutter, Android first
- Date: 2026-10-23 · Phase: tech choice
- Decision: Flutter + Dart; Android only for v1; iOS later from the same code (`docs/ios-plan.md`). Minimum Android 11 (API 30). Package `app.taketray`.
- Why: one codebase for both platforms later; the owner's preference.
- Consequences: platform-specific parts (gallery, background, editors) are written natively and bridged.

### D-13 · Architecture: feature-first, MVVM per Flutter's guide
- Date: 2026-10-24 · Phase: build design
- Decision: `app/lib/features/<feature>/{data,view_models,views,widgets}`; shared `core/`, `domain/`, `data/`, `platform/`.
- Why: Flutter's recommended app architecture; features stay independent and testable.

### D-14 · Riverpod for state and dependency injection
- Date: 2026-10-24 · Phase: build design
- Decision: Riverpod with code generation; view models are Notifiers.
- Why: compile-safe, testable (providers overridable in tests), widely used.
- Alternatives considered: Bloc (more boilerplate), Provider (weaker DI and testing).

### D-15 · Drift (SQLite) for the database
- Date: 2026-10-24 · Phase: build design
- Decision: Drift with versioned migrations and migration tests.
- Why: relational data (one clip in many reels), reactive queries, in-memory DB for tests.
- Alternatives considered: Isar/Hive (weaker relations/migrations), raw sqflite (no type safety).

### D-16 · freezed + json_serializable for models and export
- Date: 2026-10-24 · Phase: build design
- Why: immutable models, equality, and the versioned export/import JSON from the same definitions.

### D-17 · go_router for navigation
- Date: 2026-10-24 · Phase: build design
- Why: deep links from notifications and share intents; tab branches keep their own stacks (`StatefulShellRoute`).

### D-18 · Kotlin + Pigeon for Android-specific work; background runs without Flutter
- Date: 2026-10-24 · Phase: build design
- Decision: gallery queries, background detection, VN copies and editor sharing are Kotlin, exposed to Dart through Pigeon. The background job (JobScheduler content trigger, WorkManager reminders) runs natively without a Flutter engine and never writes the database; the scan when the app opens does.
- Why: existing plugins don't expose MediaStore generations, `IS_PENDING` or content triggers; Pigeon makes the bridge type-safe; native background work is lighter and more reliable.

### D-19 · Design system as its own package, with an enforced style rule
- Date: 2026-10-24 · Phase: build design
- Decision: `packages/taketray_ui` holds tokens, theme and every component, each with golden tests and a Widgetbook entry. Feature code may not use raw colours, text styles, sizes, radii or animation durations; `tool/check_styles` fails the build otherwise.
- Why: one source of visual truth; no repeated or drifting UI code.

### D-20 · Quality tooling
- Date: 2026-10-24 · Phase: build design
- Decision: very_good_analysis (zero warnings), alchemist golden tests, Patrol on-device tests, ≥ 80% coverage for domain, data and view models, one-command `tool/check`.
- Why: enterprise-level quality bar agreed with the owner.

### D-21 · Pinned Flutter SDK via wrapper scripts
- Date: 2026-10-24 · Phase: 0
- Decision: all commands use `tool/flutter` / `tool/dart` (Flutter 3.47.7 at `~/development/flutter`).
- Why: the `flutter` on PATH is an old 2.8.1 install with local changes that must not be touched.

### D-22 · Git local until after phase 2
- Date: 2026-10-24 · Phase: build brainstorming
- Decision: local git now; GitHub and CI after phase 2. `tool/check` runs the same checks locally until then.
- Why: the owner's choice.

### D-23 · Pub workspace with `app` and `tool` members
- Date: 2026-10-24 · Phase: 0
- Decision: the repo root is a Dart pub workspace (`taketray_workspace`) whose members are `app` (the Flutter app) and `tool` (`taketray_tool`, pure-Dart tooling such as `check_styles`). Further members (e.g. `packages/taketray_ui`) join the same list.
- Why: one lockfile and one dependency resolution for everything; one SDK constraint set; the tooling stays a separate package, so app code never depends on it and the boundaries stay clean.
- Alternatives: independent projects each with their own lockfile (versions drift, repeated setup); melos (an extra tool for what pub workspaces now do natively).
- Consequences: `pub get` runs once at the root and writes the single `pubspec.lock` there (members have none). Workspaces share dependency resolution and the lockfile, not lint configuration: each member has its own `analysis_options.yaml` including `very_good_analysis`. Every member needs `resolution: workspace` and an SDK constraint compatible with the root's.

### D-24 · very_good_analysis 11.0.0, `public_member_api_docs` off in `app` only
- Date: 2026-10-24 · Phase: 0
- Decision: `app` and `tool` each include `package:very_good_analysis/analysis_options.yaml` (dev dependency `^11.0.0`, the version pub resolved for the pinned Dart 3.13 SDK). Generated code (`*.g.dart`, `*.freezed.dart`, `lib/l10n/gen/**`) and `build/**` are excluded. `public_member_api_docs` is disabled in `app` only, since it is application code rather than a library; it stays on in `tool`.
- Why: zero-warning quality bar (D-20) without forcing doc comments on every app widget.
- Alternatives: keep `flutter_lints` (weaker); disable more rules (erodes the bar).
- Consequences: `flutter_lints` is removed from `app`. Individual rule opt-outs need their own justification here or an inline `// ignore` with a reason.

### D-25 · Style rule enforced by a regex check over the whole source, not an analyzer plugin
- Date: 2026-10-24 · Phase: 0 · Revised: 2026-10-25
- Decision: `tool/check_styles` (`tool/lib/src/style_rules.dart`, CLI `tool/bin/check_styles.dart`) scans `app/lib/features/**/*.dart` (skipping `*.g.dart`, `*.freezed.dart`; a missing directory is clean) with one regex per rule: `raw-color`, `raw-text-style`, `raw-insets`, `raw-size`, `raw-radius`, `raw-duration`. Comments (`//` and `/* */`, string-aware) are blanked from the whole text keeping offsets, the regexes run over the full text so calls split across lines (the shape `dart format` produces with trailing commas) are caught, and each match is reported on the line where it starts. A numeric literal counts only when it is a whole argument (`8`, `horizontal: 16.0`), so `spacing.m * 2` or `2 * tokens.y` are clean. A match is exempt when its start line, or a comment-only line directly above it, contains `// style-check: allow <reason>`; the reason is required (a bare marker does not exempt) and is reviewed like any other code. A marker on a line that also holds code exempts that line only.
- Why: the rule only needs to catch raw literals in feature code (D-19), which patterns do reliably; it runs in milliseconds, is plain Dart in the existing `tool` package, and is trivially unit-tested. The spec requires the rule to be actually enforced, so split calls must not slip through.
- Alternatives: `custom_lint` or an analyzer plugin (precise AST rules, but heavy, tied to analyzer internals that break across SDK upgrades, and slower in `tool/check`); grep in a shell script (untested, awkward allow-list).
- Consequences: argument matching tolerates one level of nested parentheses, so deeply nested expressions and literals produced by a conditional (`x ? 8 : 4`) are not seen. If misses prove common, move the rules to an analyzer plugin; the rule ids and the allow comment stay the same.

### D-26 · `tool/check` format-checks only paths that exist; app tests always run
- Date: 2026-10-24 · Phase: 0 · Revised: 2026-10-25
- Decision: `tool/check` format-checks only those of `app/lib`, `app/test`, `app/patrol_test`, `tool` that exist. `app` tests run unconditionally (`tool/flutter test` in `app/`). It still stops at the first failure and ends with `ALL CHECKS PASSED`. The on-device tests in `app/patrol_test` are format-checked and analyzed here but run only through `tool/patrol` (D-32).
- Why: the formatter fails on missing paths, which broke the check before every directory existed. Early in phase 0 the app-test step was also skipped while `app/test` held no `*_test.dart` (printing `app: no tests yet (skipped)`); now that app tests exist, a skip would only hide a deleted or emptied test directory, so it was removed.
- Alternatives: create empty placeholder test files (noise, fake coverage); keep the conditional test step (silently passes if tests disappear).
- Consequences: deleting or emptying `app/test` now fails `tool/check`.

### D-27 · gen-l10n output is generated, not committed
- Date: 2026-10-25 · Phase: 0
- Decision: copy lives in `app/lib/l10n/app_en.arb` (English only, template ARB) and `app/l10n.yaml` points gen-l10n at `lib/l10n/gen`; `flutter: generate: true` is set in `app/pubspec.yaml`. `app/lib/l10n/gen/` is git-ignored. `flutter pub get` (which `tool/check` runs first, and which every fresh checkout needs anyway) regenerates it, so `flutter analyze` and `flutter test` work straight after `pub get`; `tool/flutter gen-l10n` regenerates on demand. Plurals use ICU syntax in the ARB (`toTagBadgeSemantics`). `intl` is constrained `^0.20.2`, the range `flutter_localizations` pins.
- Why: generated code in the diff is noise and can drift from the ARB; the only extra requirement is `pub get`, which is already mandatory.
- Alternatives: commit the generated files (works with no step at all, but invites stale or hand-edited output and merge noise).
- Consequences: after editing the ARB, run `pub get` or `gen-l10n` before analyzing; the analyzer excludes `lib/l10n/gen/**` (D-24) so generated code is not linted.

### D-28 · Local error log: size-rotated file, start-up never blocked, paths redacted
- Date: 2026-10-25 · Phase: 0 · Revised: 2026-10-25
- Decision: `LogFileSink` (`app/lib/core/logging/log_file_sink.dart`) writes to `taketray-0.log` and rotates to `taketray-1.log` when a write would pass `maxBytes` (512 KiB), so the log is capped at about 1 MiB; writes are serialized on one future chain. `runAppWithLogging` (`logging_setup.dart`) works in this order: (1) set level INFO, subscribe to `Logger.root.onRecord`, install `FlutterError.onError` and `PlatformDispatcher.onError`; (2) enter `runZonedGuarded`, call `WidgetsFlutterBinding.ensureInitialized()` inside it (so `runApp` in `body` shares the zone) and start resolving `logDir()` concurrently with a 5 s timeout; (3) run `body` immediately. Records and errors produced before the sink exists, including start-up errors thrown by `body`, are formatted and buffered in memory (max 200) and flushed in order once the sink is ready. If `logDir()` throws or times out, logging is disabled: the buffer is dropped, nothing more is buffered (`debugPrint` once, error type only) and the app carries on. A throwing `onSinkReady` callback is reported and ignored. `onSinkReady` hands out the live sink (phase 10's Settings share action uses it for `exportFile`). Console output in debug builds (`kDebugMode`): the `onRecord` listener also `debugPrint`s every formatted record (with its `error:` and `stack:` lines), so uncaught zone and `PlatformDispatcher` errors and ordinary warnings reach the console as well as the file, even when the file log is disabled; framework errors are printed once, by `FlutterError.presentError` (their record carries a private tag object and is not echoed). Release builds print nothing to the console.
- Redaction (D-10): `formatRecord` renders a `FileSystemException` as its type, message and OS error without `path`, and replaces path-like tokens in message and error text with `<path>`: quoted paths or URIs, any `scheme://...` (`content://`, `file://`), `C:\...`, and absolute `/a/b...` paths with at least two slashes. Stack traces are kept verbatim. Each record is cut at 8 KiB (`…[truncated]`) so one record cannot defeat the size cap.
- Why: crashes during start-up are exactly the ones worth keeping, but the log directory is only available asynchronously and a hung lookup must not stop the app starting. A small fixed cap keeps storage bounded without a cleanup job. Video names and locations must never be written to the log.
- Alternatives: resolve the directory before running `body` (loses early errors, can hang start); a third-party crash reporter (violates fully offline); one unbounded file (grows forever).
- Consequences: the console echo uses the redacted line, so a developer sees `<path>` where a path was; debug the raw value with a breakpoint, not by logging it. The redaction is a conservative pattern scrub, not a guarantee: a bare relative file name or a path with spaces that is not quoted may still show (callers must not log them either). Sink failures are swallowed so logging can never crash the app.

### D-29 · Placeholder stock `NavigationBar` for the tab shell until phase 1
- Date: 2026-10-25 · Phase: 0
- Decision: `AppShell` (`app/lib/features/shell/views/app_shell.dart`) uses Material's stock `NavigationBar` with `Icons.*` and `AppLocalizations` labels, and a default `ThemeData(useMaterial3: true)` light/dark theme in `TakeTrayApp`. Phase 1 replaces both with the TakeTray floating nav pill and design tokens.
- Why: the router, back handling and per-tab stacks need a real shell to test now; the design system does not exist yet, and the style rule (D-19) forbids hand-picked colours, sizes and styles in feature code, which the stock widget avoids by using none.
- Alternatives considered: build the floating pill now (needs tokens that phase 1 defines); no visible navigation (cannot demo or test tab switching).
- Consequences: `AppShell`'s public shape (`navigationShell`) and the `PopScope` back behaviour stay; only the bar widget and theme change in phase 1.

### D-30 · Riverpod 3 with code generation, keep-alive router provider
- Date: 2026-10-25 · Phase: 0 · Revised: 2026-10-25
- Decision: state management is `flutter_riverpod` with `riverpod_annotation` and `riverpod_generator` (`@riverpod` functions), run through `build_runner`; generated `*.g.dart` files are committed (the analyzer already excludes them, D-24). `appRouterProvider` is `@Riverpod(keepAlive: true)` and disposes its `GoRouter` with the provider. Navigation uses `go_router` with `StatefulShellRoute.indexedStack`. Any location no route matches (an unknown top-level path such as `/nope`, or an unknown path below a tab root such as `/reels/stale` or `/to-tag/player/123`) is handled by `GoRouter.onException`, which logs a `router` warning without the location and calls `router.go('/reels')`; there is no top-level `redirect`. `riverpod_lint` is not used.
- Why: generated providers give typed, uniform declarations as features grow; keeping the router alive stops an auto-disposed provider from rebuilding the router (and losing every tab's stack) if it briefly has no listener. Committing `*.g.dart` means a fresh checkout analyzes and runs without a build step.
- Alternatives considered: hand-written providers (no codegen step, but inconsistent as the app grows); auto-dispose router (risk of lost navigation state); `riverpod_lint` (extra analyzer plugin weight); a `redirect` that allows any path under a tab root prefix (the first version: `/reels/stale` passed the prefix test, matched no route and showed go_router's "Page Not Found" page); `errorBuilder` (shows a page instead of recovering).
- Consequences: after changing an `@riverpod` declaration run `tool/dart run build_runner build --delete-conflicting-outputs` in `app/` and commit the output. A stale deep link loses its target silently (only the warning records it); when later phases add sub-routes (player, reel detail), they become reachable simply by declaring them, with no allow-list to keep in sync.

### D-31 · INTERNET stripped from release with `tools:node="remove"`, verified by a script
- Date: 2026-10-25 · Phase: 0 · Revised: 2026-10-25
- Decision: `app/android/app/src/main/AndroidManifest.xml` declares `xmlns:tools` and `<uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>`, so the manifest merger removes INTERNET coming from `main` and from lower-priority manifests (plugins and libraries), which makes the release build INTERNET-free even when a plugin's manifest adds it. Debug and profile keep INTERNET: `src/debug` and `src/profile` declare their own `INTERNET` line (hot reload and the debugger need it), and build-type manifests rank above `main`, so the marker does not remove their entry (confirmed with `aapt2` on the debug APK). `tool/check_release_permissions` runs `tool/flutter build apk --release` in `app/`, runs `aapt2 dump permissions` (newest stable `build-tools/x.y.z` that has `aapt2`, found at run time under `$ANDROID_HOME` or `~/Library/Android/sdk`) on `app-release.apk`, and exits 1 with `INTERNET permission found in release build` if `android.permission.INTERNET` is listed; otherwise it prints the list and `RELEASE PERMISSIONS OK`. It is not part of `tool/check` (a release build takes minutes); run it at the end of every phase.
- Why: "fully offline" is a product promise (spec); the strongest enforceable form is that the shipped APK cannot open a socket. Checking the built APK, not the source manifests, also catches permissions merged in by a future plugin.
- Alternatives: rely on the template (INTERNET only in debug/profile), which passes today but silently breaks when a plugin merges it; inspect the merged manifest instead of the APK (does not prove what is packaged).
- Consequences: before this change the release build already had no INTERNET (recorded), so the marker is a guard rather than a fix. A new plugin that really needs the network cannot be added without removing this line, which is a deliberate, visible decision. Real release signing is still phase 11.

### D-32 · Patrol for on-device tests, run on the S24 only for now
- Date: 2026-10-25 · Phase: 0 · Revised: 2026-10-25
- Decision: on-device UI tests use Patrol (`patrol` 4.10.0 as a dev dependency, `patrol_cli` 4.8.0 installed globally), with the Android test orchestrator set up as in Patrol's guide (`PatrolJUnitRunner`, `MainActivityTest`, `androidTestUtil` orchestrator). `tool/patrol` runs the CLI with the pinned Flutter first on `PATH` and `--flutter-command`, sets `PATROL_ANALYTICS_ENABLED=false`, and adds `--no-uninstall` to `test` and `develop` unless the caller chose `--uninstall`/`--no-uninstall`. The environment variable turns analytics off only for runs through `tool/patrol`; any other run reads `~/.config/patrol_cli/analytics.json`, which each developer sets to `"enabled":false` once (`docs/dev-setup.md`). `patrol_cli` is pinned to 4.8.0 at install. Tests live in `app/patrol_test/` and run only on the owner's Samsung Galaxy S24 Ultra; the API 30, 33 and 34+ emulators are not created.
- Why: Patrol drives native UI (permission dialogs, system settings, notifications), which later phases need and `flutter test` / `integration_test` cannot do. Emulators were skipped because only about 14 GB of disk is free and each system image plus AVD costs several GB; the existing `Pixel_3a_API_32` AVD's system image is missing.
- Alternatives considered: plain `integration_test` (no native automation); free disk and create AVDs now (the owner chose not to); Firebase Test Lab or similar (sends the app off the machine, against the offline rule).
- Consequences: the app under test stays installed on the owner's phone after a run (patrol_cli's default uninstall removed it), but the orchestrator's `clearPackageData` still wipes its data, and a differently signed build must be uninstalled by hand. Analytics can still be sent by a bare `patrol` run if the home config file was never set; the repo cannot enforce that file. OS-version coverage is one device (Android 16 on One UI) until emulators exist; minSdk 30 behaviour is untested on old APIs. `patrol` is a dev dependency only, so its `http` and related transitive packages never ship in the app, and the release permission check (D-31) still guards INTERNET. Revisit when disk space allows (or before the first release, phase 11): create API 30 and 34+ AVDs and add them to the run list in `docs/dev-setup.md`.

### D-33 · Prototype app moved to `reference/`, not compiled or analysed
- Date: 2026-10-25 · Phase: 0
- Decision: the earlier prototype app (`app/lib` screens, state, widgets, sample models and its preview tests) was moved unchanged to `reference/prototype-app/` before the rebuild started. It is not part of the pub workspace, is excluded by the repo-root `analysis_options.yaml` (together with `design/**`), and is never built, analysed or tested. Its screens are layout references for phases 1–10; its widgets are re-implemented in the design system to the style rule (D-19); its sample data becomes a debug-only seed and Widgetbook fixtures. `app/assets/sample/` stays in the app for now and moves with that work in phase 1. Delete `reference/` after phase 10.
- Why: the spec ports the prototype rather than discarding it, but its code predates the architecture (D-13), the style rule and the strict lints, so compiling it alongside the new app would mean either fixing throwaway code or weakening the checks. Keeping it in the repo keeps it one click away while porting.
- Alternatives considered: delete it and rely on git history (harder to consult side by side); keep it in `app/lib` and fix it to the lints (wasted work on code that is being rewritten); a separate branch (invisible while working on the main line).
- Consequences: `reference/` code may rot against newer SDKs; that is accepted, because it is only read. An IDE opened at the repo root shows no errors from it (root `analysis_options.yaml`). Nothing in `app` or `tool` may import from `reference/`.

### D-34 · `tool/check` covers every workspace member
- Date: 2026-10-25 · Phase: 1 · Task: 1
- Decision: `tool/check` names its members in two arrays, `FLUTTER_MEMBERS=(app packages/taketray_ui widgetbook)` and `DART_MEMBERS=(tool)`, and runs format, analyze, style rules and tests over each one whose folder exists (a missing member is skipped with a printed note, so later tasks only create folders). A guard at the start reads the root `pubspec.yaml` `workspace:` list and fails with `workspace member <x> is not covered by tool/check` when an entry is in neither array. Format covers `lib`, `test` and `patrol_test` of Flutter members and the whole Dart member; style rules run over `app/lib/features` and `packages/taketray_ui/lib/src/components`; every present member must have a `test/` folder. The style rules also now flag `BorderRadiusDirectional.circular(<n>)`, `SizedBox.square(dimension: <n>)` and `Duration` in microseconds, minutes, hours and days.
- Why: in phase 0 `tool/check` hard-coded `app` and `tool`, so a new package could be added to the workspace and never be formatted, analysed or tested. Failing loudly when a member is unlisted keeps the one-command check honest. The style-rule gaps let a raw radius, square size or long duration bypass the rule.
- Alternatives considered: derive members from the workspace list automatically (cannot tell Flutter from Dart members without parsing each pubspec, and a new member would be checked without anyone deciding how); a YAML parser dependency (heavy for one list); only warn on uncovered members (easy to miss).
- Consequences: adding a workspace member means editing the arrays in `tool/check` in the same change, or `tool/check` fails. The `workspace:` parse expects the plain block list (`  - member`) used today; blank and comment lines inside the list are skipped and the list ends at the next top-level key, but a different YAML style (for example a flow list `workspace: [app, tool]`) yields no members and the guard fails with "no workspace members found" rather than passing silently. The style rules remain regex-based and catch literals in argument position only (D-19).

### D-35 · `taketray_ui` package with generated tokens for the shipped brand only, checked for freshness
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: the design system lives in the workspace member `packages/taketray_ui` (dependencies `flutter` and `material_symbols_icons` 4.2960.0; dev dependencies `flutter_test`, `alchemist` 0.14.1 and `very_good_analysis` 11.0.0, the newest that resolve with Flutter 3.47.7 / Dart 3.13.5). `design/tools/build_tokens.py › write_dart` now writes only `packages/taketray_ui/lib/src/tokens/tokens.g.dart`, for the shipped brand (`SHIPPED`, Graphite & marigold): `ttLightScheme`, `ttDarkScheme` and the `abstract final class` groups `TtColorTokens` (REC red and success green, light and dark, plus the video surface), `TtTypeTokens`, `TtSpaceTokens`, `TtRadiusTokens`, `TtMotionTokens` and `TtSizeTokens`. `BrandOption` and `brandSchemes` are gone from the Dart; the JSON, CSS and JS still carry all five options for the hub. The video surface values moved from an inline literal in `write_json` into a `VIDEO_SURFACE` dict so the JSON and the Dart read one source. Every writer hands its text to `emit()`, and `main` either writes the files (unchanged behaviour) or, with `--check`, compares them with disk, prints `stale: <path>` for each difference and exits 1 without writing. Contrast failures still exit 1 in both modes. `tool/check` runs `--check` right after `pub get`. `design/handoff/flutter/` is deleted; the package is the Flutter hand-off now.
- Why: one generated source for every token, consumed by one package, means the app and Widgetbook cannot drift from the design. The app never switches brand, so the other four options in Dart were dead code. A hand edit to a generated file, or a token change without a regeneration, now fails the one-command check instead of surviving until someone notices a colour.
- Alternatives considered: keep all brand options in Dart for a future switcher (no product need; easy to restore from the script); generate at build time with `build_runner` (needs Python in the Dart build, or a port of the colour maths); commit the tokens without a check (the old state: `app/lib/theme/tokens.g.dart` was silently recreated by the script after the app moved).
- Consequences: changing a token means editing `build_tokens.py`, running it, and committing the regenerated outputs together. The generator must keep producing `dart format`-clean, lint-clean Dart (the file is analysed, not excluded). `tool/check` needs `python3` on the PATH.

### D-36 · Theme architecture: one `TtThemeData` extension read through `context.tt`
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: `TakeTrayTheme.light()`, `.dark()` and `.video()` return cached `ThemeData` built from the generated schemes. Each carries a single `ThemeExtension`, `TtThemeData`, which groups `colors` (`TtColors`: "clips waiting" = the scheme's tertiary roles, REC red, success green, glass and hairline, colours on media and on video), `text` (`TtTextStyles`: the Material type scale with colours applied, plus the TakeTray display styles from `tt-style.css`, which carry no colour and inherit the ambient one), `spacing`, `radii`, `motion` and `sizes`. Widgets read it with `context.tt` and the Material roles with `context.scheme`. `context.tt` returns the extension with `motion` swapped for the `const TtMotion.reduced` (all durations zero, same curves) when `MediaQuery.maybeDisableAnimationsOf` is true, so every widget that animates with theme durations honours "Remove animations" without its own check; widgets can also compare `motion == TtMotion.reduced` (value equality, and the same instance). `context.tt` throws a `FlutterError` when the theme has no `TtThemeData`, so a widget shown under a stock theme fails loudly. The dark theme's OLED override (`tt-style.css` §1: surface = surfaceContainerLowest, surfaceContainerLowest = black, containers one step down) is applied in `TakeTrayTheme`, not in the generator, so the token JSON keeps the stock Material 3 roles that pass the contrast report. `video()` is the dark theme rebuilt with `surface` = `TtColorTokens.videoBackground` (black), so its component themes follow too. The themes also set Material component themes (pill buttons with `labelLarge`, floating snackbar on `inverseSurface` at 94 % with radius 18, transparent bottom sheets without a drag handle, dialogs with radius 32, `scrolledUnderElevation: 0`, `InkSparkle`), so stock widgets look TakeTray. Type styles use `TextLeadingDistribution.even`, which matches how CSS centres a line box.
- Why: one extension keeps `lerp` and `copyWith` in one place and gives components one import and one accessor; resolving reduced motion in the accessor makes Review Focus 5 the default rather than something each component must remember.
- Alternatives considered: several extensions (colours, text, motion) read separately (more boilerplate per widget, easy to miss one in a theme); `InheritedWidget` for TakeTray values (duplicates what `Theme` already animates); OLED surfaces in the generated dark scheme (the JSON and CSS would disagree with stock Material 3 and the hub applies the override itself in `tt-style.css`); falling back to the light values when the extension is missing (hides a wiring mistake).
- Consequences: spacing, radii, sizes and motion are identical in every theme and switch at the midpoint in `lerp`; only colours and text interpolate. Anything that renders TakeTray widgets (app, Widgetbook, tests) must use a `TakeTrayTheme` theme. The app adopts the theme in Task 11; until then `app/lib/app.dart` keeps its placeholder theme.

### D-37 · No user-facing copy in `taketray_ui`
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: the package holds no strings a user sees. Components take every visible string and semantics label as a parameter; the app passes `AppLocalizations` strings, Widgetbook and tests pass English literals. The package has no l10n setup and never imports `app/`, Riverpod or go_router.
- Why: keeps the design system independent of the app's localisation and state, so it can be built, tested and catalogued on its own, and translations stay in one place (`app/lib/l10n`).
- Alternatives considered: give the package its own ARB files (two translation sources); hard-code English defaults (silently untranslated text in the app).
- Consequences: component APIs have more required `String` parameters; a missing label is a compile error rather than a fallback.

### D-38 · `TtMetrics` holds component numbers; the style rule covers components
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: `packages/taketray_ui/lib/src/theme/tt_metrics.dart` defines one `abstract final class TtMetrics` with every non-token number a component or component theme needs, as `static const double`, named with the component as prefix (`glassBlur`, `snackbarRadius`, `dialogRadius`, `buttonMinHeight`…), each with a `// tt-style.css: <selector>` (or `proto.css`) comment naming its source. `tool/check_styles` already runs over `packages/taketray_ui/lib/src/components` (D-34), so components may use only `context.tt`, `context.scheme` and `TtMetrics`. The theme files themselves (`lib/src/theme`) are outside the rule: they are where tokens become values.
- Why: the TakeTray style adds many one-off numbers on top of the tokens; one named, sourced home keeps them reviewable against the CSS and stops raw literals from spreading across widgets.
- Alternatives considered: per-component private constants (not checked, harder to compare with the CSS); promoting each number to a design token (the hub would need them in the generator too, for values used once).
- Consequences: adding a component number means editing `tt_metrics.dart` with its CSS source. Opacities used to build `TtColors` (glass 78 %, hairline 9 %, on-media 82 %, scrim 80 %) live there too.

### D-39 · Goldens with alchemist: CI and macOS images, light and dark at 1.0× and 2.0×
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: `packages/taketray_ui/test/flutter_test_config.dart` configures alchemist for every test: CI goldens (text drawn as blocks, `goldens/ci/`) always on; platform goldens (real text, `goldens/macos/`) only on macOS and off when the `CI` environment variable is set. The same config loads the package's own fonts under `packages/taketray_ui/<family>`, because the test FontManifest lists them under the bare family while the theme names them with `package: 'taketray_ui'`; alchemist loads the bare and dependency-package names (including Material Symbols). The test helper `ttGoldenTest(description, fileName:, scenarios:, width: 360)` registers two golden tests and writes `<fileName>_light.png` and `_dark.png`, each one `GoldenTestGroup` with every `TtScenario` at text scale 1.0 and 2.0 side by side, on the theme's surface with labels in its colours. Before the shot it decodes every `Image` for real (`runAsync` + `precacheImage`, decode errors left to the widget's error builder), then settles; an optional `pumpBeforeTest` replaces that for a widget that never settles. Other helpers: `ttTestApp` (theme, text scale, "remove animations"), `expectTtAccessible` (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`), `fixtureThumb(1..6)` and `brokenImage`.
- Why: macOS images with real text are what a reviewer compares with the prototype; CI images stay stable on any machine. One image per theme with both text scales makes the 2.0× check (spec §7 rule 2) part of every review without doubling the files.
- Alternatives considered: `golden_toolkit` (discontinued); plain `matchesGoldenFile` (no scenario grid, no CI/platform split); one image per scale (four files per component).
- Consequences: goldens are regenerated with `tool/flutter test --update-goldens` in the package; macOS images differ by OS version and must be regenerated on the owner's Mac. `test/failures/` stays ignored.

### D-40 · Font and icons are packaged in `taketray_ui`
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: Plus Jakarta Sans (variable, with its OFL licence) moved from `app/assets/fonts/` to `packages/taketray_ui/fonts/` and is declared in the package pubspec as family `PlusJakartaSans`; styles reference it with `package: 'taketray_ui'` (resolved family `packages/taketray_ui/PlusJakartaSans`) and set weight on both `fontWeight` and `FontVariation('wght', w)`. Icons come from `material_symbols_icons` (Rounded), bundled fonts. The app pubspec no longer declares `fonts:`, `assets:` or `cupertino_icons`; it depends on `taketray_ui` by path.
- Why: the font belongs with the type tokens that name it, and Widgetbook and the package's own goldens need it without the app. Everything stays offline (no `google_fonts`).
- Alternatives considered: keep the font in the app (the package's goldens and Widgetbook could not render it); `google_fonts` (fetches at runtime, against the offline rule).
- Consequences: any text style written outside the generated tokens must also pass `package: 'taketray_ui'` (use `TtTypeTokens.fontFamily` and `fontPackage`).

### D-41 · Sample assets leave the app
- Date: 2026-10-25 · Phase: 1 · Task: 2
- Decision: `app/assets/sample/` (sample JSON and 132 thumbs) moved to `reference/prototype-app/assets/sample/`, next to the prototype code that reads it; six thumbs (`c1`–`c6.jpg`) are copied to `packages/taketray_ui/test/fixtures/thumbs/` for tests and Widgetbook. This completes the move D-33 deferred to phase 1.
- Why: the shipped app must not bundle demo media; tests need a few real images without the asset bundle.
- Alternatives considered: keep them in the app behind a debug flag (still bundled in release); delete them (the prototype and fixtures need them).
- Consequences: the app has no assets of its own. A debug seed, if one is built later, reads its data from somewhere other than `app/assets/sample/`.

### D-42 · Widgetbook catalogue: hand-written, coverage-tested, its own app ID
- Date: 2026-10-25 · Phase: 1 · Task: 3
- Decision: `widgetbook/` is a third pub-workspace member and an Android-only Flutter app (`app.taketray.widgetbook`, label "TakeTray UI", `minSdk` 30 like the app), on `widgetbook` 3.25.0 (newest that resolves with Flutter 3.47.7 / Dart 3.13.5). The catalogue is written by hand, with no `widgetbook_generator`, `build_runner` or annotations: `lib/catalog.dart` holds `ttCatalog` (a `List<WidgetbookNode>` folder tree) and imports one file per component from `lib/components/<name>.dart`, each exposing a `WidgetbookComponent`. `lib/main.dart` uses `Widgetbook.material` with add-ons: `MaterialThemeAddon` ("TakeTray light", "TakeTray dark", "Video"), `TextScaleAddon` (slider with stops 1.0, 1.5, 2.0) and `ViewportAddon` (one 360 x 780 dp phone). `wbThumb(1..12)` (in `lib/fixtures.dart`, re-exported by `catalog.dart`) gives `AssetImage`s from `widgetbook/assets/thumbs/` (copies of `c1`-`c12.jpg`). `widgetbook/test/catalog_coverage_test.dart` fails when a `packages/taketray_ui/lib/src/components/<name>.dart` has no `widgetbook/lib/components/<name>.dart` or `catalog.dart` does not import it; it passes while the package folder is missing or empty. `lib/components/theme.dart` (colour roles and text styles) has no package counterpart, which is allowed. `tool/check` formats, analyses and tests the member. The package also gets `dart_test.yaml` declaring the `golden` tag (Task 2 review ruling R3), which removes the "tag was used" warning.
- Why: the generator needs `build_runner` and annotations on every use case for little gain at this size; a plain list is readable, and the coverage test supplies the one guarantee the generator would (nothing is forgotten). A separate application ID lets the catalogue install next to the app on the phone.
- Alternatives considered: `widgetbook_generator` (extra codegen step and a second `build_runner` target); catalogue inside `app/` (ships catalogue code and assets in the product); no coverage test (components silently missing from the catalogue).
- Consequences: a component task adds its catalogue file and registers it in `catalog.dart` in the same commit, or `tool/check` fails. The Android folder is a plain `flutter create` result minus platform folders other than `android`; the Gradle wrapper jar is not committed (ignored like in `app/`).

### D-43 · Core controls: Material buttons restyled, `filled` means the glyph, glass icon buttons blur, the record dot owns its ticker
- Date: 2026-10-25 · Phase: 1 · Task: 4
- Decision: `TtButton` wraps `FilledButton` (filled, tonal, danger, attention), `OutlinedButton` (outlined, ghost) and `TextButton` (text) with a `ButtonStyle` built from the scheme and `TtMetrics`, so ripple, focus and semantics stay Material's; every size sets `MaterialTapTargetSize.padded`, which keeps a 48 x 48 dp target around the 36 dp small button. The kinds follow `tt-style.css`: tonal is `surfaceContainerHighest` on `onSurface`, outlined is `onSurface` with an `outlineVariant` border, attention is `waitingContainer`, and ghost (from `.qrow .btn.ghost`) is white on a 35 % white border for use on video. Disabled buttons use `onSurface` at 12 % (fill, border) and 38 % (content), white in place of `onSurface` for ghost. `TtIconButton.filled` draws the glyph with `fill: 1` (the `fill` option of `h.ib`, the selected look), not a filled container; `pressed` non-null adds `toggled` semantics and the primary colour. The `glass` icon button is a blurred `colors.glass` circle inset 5 dp in the 48 dp target (the prototype's solid `surface-container-high` circle, made real glass like the nav pill). `TtGlass` ignores the prototype's `saturate(1.4)`, which Flutter's backdrop blur has no equivalent for. `TtRecDot` creates its `AnimationController` once and calls `repeat()` only while `live` and motion is not reduced, and `stop()` otherwise, so under "remove animations" no ticker runs; it then shows the static 3 dp ring. `TtCountBadge` keeps the style's 2 dp ring in `surfaceContainerHigh`, and hides itself at 0 or below. The barrel re-exports `material_symbols_icons/symbols.dart`; the Rounded style is `Symbols.<name>_rounded`.
- Why: Material buttons already provide the tap target, focus and ripple behaviour that accessibility checks expect, and only their look differs. Reading `filled` as the glyph matches both the prototype helper and the global rule that selected icons use `fill: 1`.
- Alternatives considered: hand-built `InkWell` buttons (re-implementing the tap target and semantics); `filled` as a primary container behind the icon (`.ib.filled`, which the FAB and filled buttons already cover); a solid circle for the glass icon button (exact to the CSS, but not glass).
- Consequences: new numbers for these controls are in `TtMetrics` with their CSS sources. The catalogue test `widgetbook/test/catalog_use_cases_test.dart` opens every use case, so later component tasks get a render check from registering their use cases.

### D-44 · Selection and input: a custom switch, notched text field, 48 dp chips, no switch role
- Date: 2026-10-25 · Phase: 1 · Task: 5
- Decision: `TtSwitch` is the prototype's own switch (52 x 32 track, 16 dp thumb that grows to 24 dp with a check), not Material's `Switch`. It is an `InkResponse` inside a 52 x 48 dp target and moves its thumb with `context.tt.motion.short4`, so it jumps under "remove animations". It is announced with `toggled` semantics and its label (this Flutter has no `SemanticsRole.switchRole`). `inverted` is `.sw.inv`: white outline on a 20 % white track, a white thumb, and when on a white track with a black thumb (`videoBackground`) and a white check. Disabled follows the buttons: 12 % `onSurface` for the track and edge, 38 % for the off thumb. `TtCheckMark` and `TtRadioMark` are `ExcludeSemantics` visuals; the row that holds them owns the tap and semantics. `TtPillTabs` is a horizontal `SingleChildScrollView` of 36 dp (more at large text) stadium tabs, each in a 48 x 48 dp minimum tap target and announced as a button with `selected` set only on the active tab. `TtSuggestionChip` has the prototype's plus icon and a dashed 1.5 dp outline drawn by a painter (Flutter has no dashed border), with the dash 4.5 and gap 3 chosen to look like the browser's. `TtTextField` is a Material `TextField` with `floatingLabelBehavior: always`, which gives the prototype's label notched into the top border, a 12 dp outline (1 dp at rest, 2 dp primary when focused, 2 dp error in error), and a custom help row under it. `maxLength` uses `TextField.maxLength` with Material's counter hidden (`counterText: ''`) and the help row's own `n/max` counter; an `error` replaces the helper with an error icon and the text, announced as a live region. Material's own `errorText` is not used because it would add its own helper row and spacing. `TtSuggestionChip` and the pill tabs live in `pill_tabs.dart`, sharing the 48 dp tap-target wrapper.
- Why: the switch has to look like the prototype's and sit on the black card in the Shooting mode; Material's `Switch` has neither the check thumb nor the inverted colours. Reusing `TextField` keeps the keyboard, selection, autofill and IME behaviour, and only the decoration is ours.
- Alternatives considered: a label drawn above the box rather than on its edge (the prototype's `.tf label` is notched into the border); Material `errorText` and `counter` (extra rows, different spacing); a dashed outline from a package (a dependency for one border).
- Consequences: a row using the marks must give the label, the `selected` or `checked` flag and the tap itself. A very short tab ("All") is padded to 48 dp wide so its target is large enough, which widens the gap by about 1 dp. Tabs with the same value would all show as selected.
