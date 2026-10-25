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
