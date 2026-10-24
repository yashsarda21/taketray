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

### D-25 · Style rule enforced by a line-based regex check, not an analyzer plugin
- Date: 2026-10-24 · Phase: 0
- Decision: `tool/check_styles` (`tool/lib/src/style_rules.dart`, CLI `tool/bin/check_styles.dart`) scans `app/lib/features/**/*.dart` (skipping `*.g.dart`, `*.freezed.dart`; a missing directory is clean) with one regex per rule: `raw-color`, `raw-text-style`, `raw-insets`, `raw-size`, `raw-radius`, `raw-duration`. Trailing `//` comments are stripped before matching. A line is exempt when it or the line above contains `// style-check: allow <reason>`; the reason is mandatory by convention and reviewed like any other code.
- Why: the rule only needs to catch raw literals in feature code (D-19), which a pattern on a line does reliably; it runs in milliseconds, is plain Dart in the existing `tool` package, and is trivially unit-tested.
- Alternatives: `custom_lint` or an analyzer plugin (precise AST rules, but heavy, tied to analyzer internals that break across SDK upgrades, and slower in `tool/check`); grep in a shell script (untested, awkward allow-list).
- Consequences: calls split across lines are not seen (for example `EdgeInsets.all(` with the argument on the next line), and a literal inside a longer expression can be flagged; both are accepted trade-offs of a line-based check. If misses prove common, move the rules to an analyzer plugin; the rule ids and the allow comment stay the same.

### D-26 · `tool/check` skips steps whose paths do not exist yet
- Date: 2026-10-24 · Phase: 0
- Decision: `tool/check` format-checks only those of `app/lib`, `app/test`, `tool` that exist, and runs `app` tests only when `app/test` holds a `*_test.dart` (otherwise prints `app: no tests yet (skipped)`). It still stops at the first failure and ends with `ALL CHECKS PASSED`.
- Why: the Flutter test runner and the formatter fail on missing paths, which would break the check before the first app test exists.
- Alternatives: create empty placeholder test files (noise, fake coverage).
- Consequences: once tests exist the step runs unconditionally in practice; no later change is needed.

