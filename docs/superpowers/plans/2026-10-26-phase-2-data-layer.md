# Phase 2: Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store reels, clips, the To tag list, references, VN sessions, settings and the time-zone timeline in a Drift database behind tested repositories, with a versioned JSON export/import that round-trips. Clear the "before phase 2" and "phase 2" items in `docs/later.md`, and prepare GitHub + CI.

**Architecture:**
- **Database:** `app/lib/data/` owns the Drift database (schema v1, schema dumps in `app/drift_schemas/`, generated migration tests).
- **Repositories:** they live in `app/lib/data/repositories/` because several features share them. Each repository is a Riverpod provider over the database, returns domain models and never exposes Drift row classes.
- **Domain:** `app/lib/domain/` holds freezed models and pure rules (validation, URL normalisation, zone lookup, folder-name clashes) with no Flutter or Drift imports.
- **Export/import:** a service in `app/lib/data/backup/` turns the whole database into versioned JSON and back. Choosing a file (Storage Access Framework) belongs to the Settings screen in phase 10. The "X of Y clips found" count needs the media bridge, so it comes in phase 3.

**Tech Stack:**
- Flutter 3.47.7 / Dart 3.13.5 via `tool/flutter`
- drift 2.35.x, drift_flutter 0.3.x, drift_dev 2.35.x
- freezed 4.0.x, freezed_annotation, json_serializable 6.15.x, json_annotation
- Riverpod 3 codegen (already in the app)
- GitHub Actions (CI)

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md` (§3, §5, §6, §8.1, §8.3a, §8.6, §9 phase 2, §10). Parked items: `docs/later.md` ("Before phase 2", "Phase 2").

## Global Constraints

- **SDK:** use `tool/flutter` and `tool/dart` only (Flutter **3.47.7**). Never use the `flutter` on PATH, and never touch `~/flutter`.
- **Packages:** take the newest versions that resolve with the pinned SDK, found by `tool/flutter pub add`. A dry run on 2026-10-26 resolved drift 2.35.3, drift_dev 2.35.2, drift_flutter 0.3.1, freezed 4.0.1 and json_serializable 6.15.2. No package that makes network calls at runtime.
- **Fully offline:** the release manifest still has no `INTERNET` permission, and `tool/check_release_permissions` must still pass.
- **Privacy in logs (D-10):** log lines never contain a reel name, clip display name, file path, URL or reference label. Log ids and counts only.
- **Layers:**
  - `domain/` imports neither Flutter nor Drift.
  - Repositories return domain models, never Drift data classes.
  - Feature code (later phases) reaches the database only through repositories.
- **Time:**
  - Every stored instant is UTC milliseconds since the epoch, in an `IntColumn` mapped to `DateTime` (UTC) by one shared `TypeConverter`. Don't use Drift's default `DateTime` columns, which store seconds.
  - "Now" comes from the `clockProvider` (Task 4), so tests can fix the time.
- **Text limits:** count characters (`String.characters.length`, from the `characters` package) after trimming. Reel name: 1–40. Reference label: 0–60, where empty means none.
- **Generated code:** `*.g.dart`, `*.freezed.dart` and `drift_schemas/**` are committed, and the freshness check (Task 2) fails when they are stale.
- **Coverage:** at least 80 % line coverage for `app/lib/domain/` and `app/lib/data/`, excluding generated files. Task 10 enforces it.
- **Living docs:**
  - Any meaningful decision gets the next free `D-xx` entry in `docs/decisions.md` (the last is D-51).
  - Any added or changed flow updates `docs/flow.md`.
  - Each item from `docs/later.md` that is done is deleted from that file.
  - Docs go in the same commit as the code.
- **Models:** Tasks 4 and 9 and the phase review run on Opus. Every other task runs on Sonnet.
- **Git:** work on branch `phase-2-data-layer` and stay local until the "After merge" step. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Phone:** only `app.taketray`, `app.taketray.dev` (after Task 1) and `app.taketray.widgetbook` may be installed, cleared or run on the S24.

## Review Focus

1. **The same Instagram reel shared twice with different tracking parameters** (`?igsh=...`) → it is saved once and the second save reports "already saved". Owner: Task 5 (`normalizeReferenceUrl`) and Task 8 (repository).
2. **Importing a file from a newer TakeTray, a file that isn't TakeTray JSON, or one with broken links** (a clip–reel link to a missing clip) → the import fails before touching anything, and every existing reel is still there. Owner: Task 9.
3. **Removing a clip from its last reel while it isn't in To tag** → the clip row is deleted, with no orphans. Deleting a reel whose clips are also in other reels → those clips stay. Owner: Task 7.
4. **Reel names with emoji or accents at the 40-character limit, and surrounding spaces** → 40 emoji are accepted and 41 are rejected. "  Goa  " is saved as "Goa". A name made only of spaces is rejected. Owner: Task 5 and Task 6.
5. **A detected clip that is already known** (the same MediaStore id seen again, after a rescan or a crash between insert and baseline advance) → no duplicate clip row and no second To tag entry. Owner: Task 7.

---

## File structure

```
app/
  build.yaml                         drift: databases + schema dir; freezed/json options
  drift_schemas/taketray/drift_schema_v1.json      (generated by make-migrations)
  lib/core/clock.dart                Clock + clockProvider
  lib/domain/models/                 reel.dart clip.dart inbox.dart reference.dart vn.dart zone.dart app_settings.dart
  lib/domain/rules/                  text_limits.dart reference_url.dart zone_lookup.dart folder_names.dart
  lib/data/database/
    app_database.dart                @DriftDatabase, schemaVersion 1, migration strategy
    tables.dart                      all tables
    converters.dart                  UtcMillisConverter, enum converters
    connection.dart                  openAppDatabase() (drift_flutter) + appDatabaseProvider
  lib/data/repositories/             reels_repository.dart clips_repository.dart references_repository.dart
                                     vn_repository.dart settings_repository.dart zone_repository.dart
  lib/data/backup/                   backup_format.dart backup_service.dart
  test/drift/taketray/               (generated migration tests + schema helpers)
  test/domain/  test/data/           unit tests; test/support/test_database.dart (in-memory DB + fixed clock)
  patrol_test/database_test.dart     on-device smoke test
tool/
  check                              + generated-files step, + coverage step
  check_generated                    regenerates and fails if anything changed
  bin/check_coverage.dart            lcov threshold for given prefixes
.github/workflows/check.yml          runs tool/check on ubuntu
```

---

### Task 1: A separate dev app for debug builds and Patrol

Patrol's `clearPackageData` wipes the app it tests. Debug builds become `app.taketray.dev`, so tests can never touch the owner's real `app.taketray` data.

**Files:**
- Modify: `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, `app/pubspec.yaml` (`patrol: android: package_name`), `docs/dev-setup.md`, `docs/decisions.md`, `docs/flow.md` ("On-device test"), `docs/later.md`

- [ ] **Step 1: Configure the debug build type**

  Add a `debug` build type with `applicationIdSuffix = ".dev"` and `manifestPlaceholders["appLabel"] = "TakeTray Dev"`. Release gets `manifestPlaceholders["appLabel"] = "TakeTray"`. The manifest's `android:label` becomes `${appLabel}`. The `namespace` stays `app.taketray`, so Kotlin packages don't change. Profile builds use the release label and id.

- [ ] **Step 2: Point Patrol at the dev id**

  Set `patrol: android: package_name: app.taketray.dev` in `app/pubspec.yaml`.

- [ ] **Step 3: Verify without a phone**

  Run `cd app && ../tool/flutter build apk --debug`, then dump the badging with `aapt2` from the SDK's build-tools. Expected: `package: name='app.taketray.dev'` and `application-label:'TakeTray Dev'`. Then run `tool/check_release_permissions`. Expected: it passes, and the release badging still says `app.taketray` / `TakeTray`.

- [ ] **Step 4: Update the docs**

  - Add **D-52**: debug builds are `app.taketray.dev` "TakeTray Dev"; Patrol and `flutter run` never touch the owner's data.
  - Update the dev-setup and flow notes to say debug installs appear as a second app on the phone.
  - Delete the matching `docs/later.md` line.

- [ ] **Step 5: Run `tool/check`, then commit**

  Expect `ALL CHECKS PASSED`. Commit message: `build(android): debug builds and Patrol use app.taketray.dev`.

The on-device run of this is in Task 12.

---

### Task 2: Generated-file freshness and `tool/check` hygiene

**Files:**
- Create: `tool/check_generated`, `tool/test/check_generated_test.dart` (or a shell-level test in the existing CLI test style)
- Modify: `tool/check`, `tool/test/style_rules_test.dart`, `docs/flow.md` ("Local checks"), `docs/decisions.md`, `docs/later.md`

- [ ] **Step 1: Write the `tool/check_generated` script**

  It works for every Flutter member that has `build_runner` in its `dev_dependencies`. For now that is `app`.
  1. Hash every generated file: `*.g.dart` and `*.freezed.dart` under `lib/` and `test/`, plus everything under `drift_schemas/`.
  2. Run `dart run build_runner build --delete-conflicting-outputs`.
  3. If `build.yaml` configures drift databases, also run `dart run drift_dev make-migrations`.
  4. Hash again. Comparing hashes, not `git status`, means a dirty working tree doesn't cause a false failure.
  5. If any file changed, appeared or disappeared, print `stale: <path>` for each and exit 1 with "generated files were out of date and have been regenerated; review and commit them". Otherwise print `generated files fresh`.

  Hashing uses `shasum`, which exists on macOS and Ubuntu.

- [ ] **Step 2: Call it from `tool/check`**

  Add the step `generated files fresh`, right after `pub get` and before format.

- [ ] **Step 3: Write a test that the script catches a stale file**

  Use a copy of a small fixture package in a temp dir, or edit `app/lib/router/app_router.g.dart` in a temp copy of the repo, whichever fits the existing CLI test style. Prove that the script exits 1 on a stale file and 0 on fresh ones.

- [ ] **Step 4: Clear the hygiene items in `docs/later.md` "Phase 2" that touch `tool/check`**

  - Replace `"$OLDPWD/tool/flutter"` with a `root` variable that is set once.
  - A member listed in both `FLUTTER_MEMBERS` and `DART_MEMBERS` fails with a clear message.
  - Add a `Duration(days:)` case to `style_rules_test.dart`.

- [ ] **Step 5: Run `tool/check` and update the docs**

  `tool/check` must pass, including the new step. Then:
  - Add **D-53**: generated files are committed and checked by hash after regeneration.
  - Update the "Local checks" section of `docs/flow.md`.
  - Delete the done lines from `docs/later.md`.

- [ ] **Step 6: Commit**

  Commit message: `build(tool): fail tool/check on stale generated files; check script hygiene`.

---

### Task 3: Design-system test hygiene (parked items)

These are small and independent, so they go to one subagent.

**Files:** `design/tools/build_tokens.py`, `packages/taketray_ui/test/support/*` (the `fixtureThumb` and `expectTtAccessible` helpers), `widgetbook/test/catalog_coverage_test.dart`, `widgetbook/test/catalog_use_cases_test.dart`, `docs/later.md`

- [ ] **Step 1: Fix `build_tokens.py`**

  - It rejects unknown flags: `argparse` exits 2 on an unknown argument.
  - `--check` also reports orphaned outputs, meaning files in its generated folders that it would not write, as `orphan: <path>`.
  - Prove both with a quick run: `python3 design/tools/build_tokens.py --chek` exits 2, and `--check` passes on the current tree.

- [ ] **Step 2: Make `fixtureThumb` independent of the working directory**

  Resolve the fixture path from the package root, found by walking up from `Directory.current` to the `pubspec.yaml` named `taketray_ui`. Add a test that changes `Directory.current` to the package's `test/` folder and still loads the fixture.

- [ ] **Step 3: Test that `expectTtAccessible` really fails**

  Add negative tests for an unlabelled icon button (`labeledTapTargetGuideline`) and for low-contrast text (`textContrastGuideline`). Each must fail when wrapped in `expectLater(..., throwsA(...))`, or by the pattern the existing tap-target negative test uses.

- [ ] **Step 4: Make the Widgetbook coverage test check registration**

  Walk `ttCatalog` (folders → components) and assert that every package component file maps to a registered `WidgetbookComponent` name. Importing the file is no longer enough.

- [ ] **Step 5: Size the use-case test window from content**

  Replace the fixed 2400 window with one sized from content, or a scroll. Each use case is pumped inside a `SingleChildScrollView` with an unbounded height. The test must still fail when a use case throws.

- [ ] **Step 6: Drop the doc-comment item**

  Delete the "doc comments hard-code token values" line from `docs/later.md`, with the ruling "opportunistic; not worth a pass", recorded in the commit message.

- [ ] **Step 7: Run `tool/check`, then commit**

  Expect it to pass. Commit message: `test: design-system and token tool hygiene (parked phase 1 items)`.

---

### Task 4: Database foundation (critical, Opus)

**Files:**
- Modify: `app/pubspec.yaml` (add `drift`, `drift_flutter`, `freezed_annotation`, `json_annotation`, `characters`; dev: `drift_dev`, `freezed`, `json_serializable`)
- Create: `app/build.yaml`, `app/lib/core/clock.dart`, `app/lib/data/database/{tables,converters,app_database,connection}.dart`, `app/drift_schemas/…`, `app/test/drift/…` (generated), `app/test/support/test_database.dart`, `app/test/data/database/app_database_test.dart`

**Interfaces (produced):**
- `class Clock { const Clock(); DateTime now() /* UTC */ }`
- `@Riverpod(keepAlive: true) Clock clock(Ref ref)`. In tests, `FixedClock(DateTime)` extends `Clock` and lives in `test/support/`.
- `class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor e); int get schemaVersion => 1; }`
- `@Riverpod(keepAlive: true) AppDatabase appDatabase(Ref ref)`: opens `driftDatabase(name: 'taketray')` and closes on dispose.
- `AppDatabase testDatabase()` in `test/support/test_database.dart`: `NativeDatabase.memory()` with `PRAGMA foreign_keys = ON`.

**Tables** (spec §8.1; names are exact; times are `UtcMillisConverter` int columns):

| Table | Columns | Notes |
|---|---|---|
| `reels` | `id` int PK autoinc; `name` text; `description` text nullable; `status` text (`collecting`/`ready`/`published`); `createdAt`; `updatedAt` | |
| `clips` | `id` int PK autoinc; `source` text (`mediaStore`/`picker`); `mediaStoreId` int nullable; `volumeName` text nullable; `pickerUri` text nullable; `sizeBytes` int; `durationMs` int; `dateTakenUtc`; `displayName` text; `width` int; `height` int; `mimeType` text; `timeZoneId` text nullable; `generationAdded` int nullable; `firstSeenAt`; `missing` bool default false; `lastVerifiedAt` nullable | unique (`volumeName`, `mediaStoreId`); unique (`pickerUri`); index on `dateTakenUtc` |
| `clip_reels` | `clipId` → clips ON DELETE CASCADE; `reelId` → reels ON DELETE CASCADE; `addedAt` | PK (`clipId`, `reelId`); index on `reelId` |
| `inbox` | `clipId` PK → clips ON DELETE CASCADE; `state` text (`pending`/`skipped`); `addedAt` | |
| `reel_references` | `id` int PK; `reelId` → reels CASCADE; `url` text; `source` text (`instagram`/`youtube`/`tiktok`/`link`); `label` text nullable; `createdAt` | unique (`reelId`, `url`). Not named `references`, which is an SQL keyword. |
| `vn_sessions` | `reelId` PK → reels CASCADE; `folderName` text; `createdAt` | |
| `vn_copies` | `reelId` → vn_sessions CASCADE; `clipId` → clips CASCADE; `copyMediaStoreId` int; `fileName` text; `sizeBytes` int | PK (`reelId`, `clipId`) |
| `settings` | `key` text PK; `value` text (JSON-encoded) | |
| `zone_timeline` | `at` PK; `zoneId` text | Dart mirror of the native timeline (§8.3a). Native code fills it from phase 3. |

Enums are stored by `name` through enum converters, so reordering an enum never corrupts data.

- [ ] **Step 1: Add the packages and `app/build.yaml`**

  `build.yaml` declares `drift_dev` `databases: { taketray: lib/data/database/app_database.dart }`, `schema_dir: drift_schemas/`, `test_dir: test/drift/`, and `store_date_time_values_as_text: false`.

- [ ] **Step 2: Write the failing database tests in `test/data/database/app_database_test.dart`**

  - `foreign keys are on`: `PRAGMA foreign_keys` returns 1.
  - `deleting a reel cascades its links, references and VN session` (insert raw rows, delete the reel, count rows).
  - `a clip identity is unique`: inserting the same `volumeName` + `mediaStoreId` twice throws.
  - `times round-trip in UTC milliseconds`: store `DateTime.utc(2026, 10, 26, 9, 30, 15, 123)` and read it back equal, with `isUtc` true.

- [ ] **Step 3: Implement the tables, converters, database and providers, then run `build_runner`**

  `MigrationStrategy`: `onCreate: m.createAll()`, and `beforeOpen` runs `PRAGMA foreign_keys = ON`. Use drift's `stepByStep` scaffold, with an empty `onUpgrade` for v1.

- [ ] **Step 4: Run `dart run drift_dev make-migrations`**

  This writes `drift_schemas/taketray/drift_schema_v1.json` and the generated migration test. The generated test must pass.

- [ ] **Step 5: Run the tests**

  Run `cd app && ../tool/flutter test test/data test/drift`. Expected: PASS. Host tests load SQLite through the `sqlite3` package's build hooks; if that fails on macOS, report BLOCKED with the error and don't work around it.

- [ ] **Step 6: Update the docs**

  - Add **D-54**: Drift schema v1, UTC-millis times, enums by name, foreign keys on, `zone_timeline` mirrored in Drift, repositories in `data/repositories/`.
  - Add a "Database open and migrations" section to `docs/flow.md`.

- [ ] **Step 7: Run `tool/check`, then commit**

  Expect it to pass. Commit message: `feat(data): Drift database schema v1, clock, providers and migration tests`.

---

### Task 5: Domain models and pure rules

**Files:** create `app/lib/domain/models/*.dart` and `app/lib/domain/rules/*.dart`, with tests under `app/test/domain/`.

**Interfaces (produced):**

**Models** (freezed, all immutable, times are UTC `DateTime`):
- `ReelStatus { collecting, ready, published }`
- `Reel(id, name, description?, status, createdAt, updatedAt)`
- `ClipSource { mediaStore, picker }`
- `ClipFingerprint(sizeBytes, durationMs, dateTakenUtc, displayName)`
- `Clip(id, source, mediaStoreId?, volumeName?, pickerUri?, fingerprint, width, height, mimeType, timeZoneId?, generationAdded?, firstSeenAt, missing, lastVerifiedAt?)`
- `NewClip`: the same fields without `id`, `firstSeenAt`, `missing` and `lastVerifiedAt`. It has named constructors `NewClip.mediaStore(...)` and `NewClip.picker(...)`, which assert that the identity fields are present.
- `InboxState { pending, skipped }`
- `ReferenceSource { instagram, youtube, tiktok, link }`
- `ReelReference(id, reelId, url, source, label?, createdAt)`
- `VnSession(reelId, folderName, createdAt)`
- `VnCopy(reelId, clipId, copyMediaStoreId, fileName, sizeBytes)`
- `ZoneEntry(at, zoneId)`
- `AppSettings(watchedFolders: List<String> = ['DCIM/Camera'], eveningReminderEnabled = true, eveningReminderMinutes = 1260)`. 1260 minutes is 21:00.

**Rules:**
- `String normalizeName(String raw)`: trims.
- `ReelNameProblem? checkReelName(String raw)`: `{ empty, tooLong }`, with a limit of 40 characters after trimming.
- `ReferenceLabelProblem? checkReferenceLabel(String? raw)`: `{ tooLong }` at 60. Empty and null are fine.
- `ReferenceUrlProblem { invalid }`: used when `normalizeReferenceUrl` returns null.
- `class InvalidInputException implements Exception { final Enum problem; }`
- `Uri? normalizeReferenceUrl(String raw)`:
  - trims
  - must be http or https with a host, otherwise it returns null
  - lowercases the host
  - drops a fragment
  - for Instagram hosts (`instagram.com`, `www.instagram.com`, `instagr.am`), drops the query and any trailing slash duplication, so `https://www.instagram.com/reel/ABC/?igsh=x` → `https://www.instagram.com/reel/ABC/`
  - keeps the query for other hosts
- `ReferenceSource referenceSourceOf(Uri url)`:
  - `instagram.com`, `instagr.am` and subdomains → instagram
  - `youtube.com`, `youtu.be` → youtube
  - `tiktok.com` and subdomains → tiktok
  - anything else → link
- `String? zoneAt(List<ZoneEntry> timeline, DateTime instant)`: the `zoneId` of the last entry with `at <= instant`, or null. The timeline is sorted ascending.
- `String uniqueFolderName(String base, Set<String> taken)`: returns `base`, then `base (2)`, `base (3)` and so on (spec §3).

- [ ] **Step 1: Write the failing tests, one file per rule**

  Include these cases:
  - 40 emoji pass and 41 fail
  - `'  Goa  '` → `'Goa'`
  - `'   '` → empty
  - the `igsh` example
  - `youtu.be/x` → youtube
  - `ftp://x` → null
  - `'not a url'` → null
  - `zoneAt` before the first entry → null; exactly at an entry → that entry
  - `uniqueFolderName('Goa', {'Goa', 'Goa (2)'})` → `'Goa (3)'`
  - model JSON round-trips for every model

- [ ] **Step 2: Implement, run `build_runner`, run the tests**

  Run `cd app && ../tool/flutter test test/domain`. Expected: PASS.

- [ ] **Step 3: Add D-55**

  Reference URL normalisation (Instagram query dropped) and text limits by characters.

- [ ] **Step 4: Run `tool/check`, then commit**

  Commit message: `feat(domain): models and pure rules for reels, clips, references and zones`.

---

### Task 6: Reels repository

**Files:** create `app/lib/data/repositories/reels_repository.dart`, `app/lib/data/database/housekeeping.dart` and `app/test/data/repositories/reels_repository_test.dart`.

**Interfaces (produced):** `ReelsRepository(AppDatabase db, Clock clock)` and `@Riverpod(keepAlive: true) ReelsRepository reelsRepository(Ref)`, with:
- `Future<Reel> create(String name, {String? description})`:
  - validates and trims the name
  - an empty description is stored as null
  - status is `collecting`, and `createdAt` = `updatedAt` = now
- `Future<void> rename(int id, String name)`, `setDescription(int id, String? description)`, `setStatus(int id, ReelStatus status)`. Each bumps `updatedAt`. An unknown id throws `StateError`.
- `Future<void> delete(int id)`:
  - removes the reel, its links, references and VN rows in one transaction, then deletes orphaned clips
  - the doc comment says the caller (phase 8) deletes VN copy files first
- `Future<Reel?> getById(int id)`, `Stream<Reel?> watchById(int id)`, and `Stream<List<Reel>> watchAll()`, sorted by `updatedAt` descending with ties broken by `id` descending.

**Orphan rule (shared with Task 7):** add `Future<void> deleteOrphanClips()` as an `AppDatabase` extension in `app/lib/data/database/housekeeping.dart`. It deletes every clip with no `clip_reels` row and no `inbox` row.

- [ ] **Step 1: Write the failing tests**

  - create trims and defaults
  - a 41-character name throws `InvalidInputException` with `ReelNameProblem.tooLong`
  - rename bumps `updatedAt`: use `FixedClock`, then advance it
  - `watchAll` emits in the new order after an edit
  - deleting a reel keeps a clip that is still in another reel and removes a clip that was only in this reel (Review Focus 3)
  - duplicate names are allowed (D-56)

- [ ] **Step 2: Implement and run**

  Run `../tool/flutter test test/data/repositories/reels_repository_test.dart`. Expected: PASS.

- [ ] **Step 3: Add D-56**

  Reel names are not unique (VN folder clashes are handled by `uniqueFolderName`). `updatedAt` moves on edits and on clip-link changes.

- [ ] **Step 4: Run `tool/check`, then commit**

  Commit message: `feat(data): reels repository`.

---

### Task 7: Clips and To tag repository

**Files:** create `app/lib/data/repositories/clips_repository.dart` and `app/test/data/repositories/clips_repository_test.dart`.

**Interfaces (produced):** `ClipsRepository(AppDatabase db, Clock clock)` and its provider, with:
- `Future<List<int>> addDetectedClips(List<NewClip> clips)`:
  - one transaction
  - a clip whose identity already exists is not inserted or re-added to the inbox, and its existing id is returned
  - new clips get `firstSeenAt = now` and an `inbox` row `pending`
  - returns ids in input order
- `Future<List<int>> upsertClips(List<NewClip> clips)`: the same identity rule, but no inbox row. Phase 7 uses it to add to a reel directly.
- `Future<void> tagClip(int clipId, Set<int> reelIds)`:
  - `reelIds` must be non-empty (`ArgumentError`)
  - replaces the clip's links, keeping `addedAt` for links that stay
  - deletes its inbox row
  - bumps `updatedAt` of every reel that gained or lost the clip
- `Future<void> untagToInbox(int clipId)` (Undo): deletes all its links and sets the inbox to `pending`.
- `Future<void> skip(Iterable<int> clipIds)` and `restore(Iterable<int> clipIds)` (skipped → pending).
- `Future<void> addClipsToReel(int reelId, Iterable<int> clipIds)` and `removeClipsFromReel(int reelId, Iterable<int> clipIds)`. Both bump the reel's `updatedAt`, and remove runs `deleteOrphanClips`.
- `Future<void> recordVerification({required Set<int> found, required Set<int> missing})`: sets `missing` and `lastVerifiedAt = now`.

**Streams:**
- `Stream<List<Clip>> watchInbox(InboxState state)`: sorted by `dateTakenUtc` ascending, ties by `id`.
- `Stream<int> watchPendingCount()`.
- `Stream<List<Clip>> watchReelClips(int reelId)`: shooting time ascending (spec §8.4).
- `Stream<Set<int>> watchReelIdsOf(int clipId)`.

**Tests** (in the new test file):

- [ ] **Step 1: Write the failing tests**

  - Adding the same `NewClip` twice → one clip, one inbox row, and the same id both times (Review Focus 5).
  - `tagClip` with two reels → two links and no inbox row. Calling it again with one of them → one link, and the kept link's `addedAt` is unchanged.
  - `untagToInbox` → no links and pending.
  - Skip, then restore → pending.
  - `removeClipsFromReel` of a clip's last reel, with no inbox row → the clip is deleted. With another reel left → it stays (Review Focus 3).
  - `watchReelClips` ordering, including two clips with an identical `dateTakenUtc`.
  - `recordVerification` flags.
  - `tagClip({})` → `ArgumentError`.

- [ ] **Step 2: Implement and run the tests**

  Expect PASS.

- [ ] **Step 3: Update the docs**

  - Add **D-57**: clip identity (`volumeName` + `mediaStoreId`, or `pickerUri`), idempotent detection, and the orphan rule.
  - Add a "Tagging data changes" section to `docs/flow.md` that lists what each method writes.

- [ ] **Step 4: Run `tool/check`, then commit**

  Commit message: `feat(data): clips and To tag repository`.

---

### Task 8: References, VN, settings and zone repositories

**Files:** create `app/lib/data/repositories/{references,vn,settings,zone}_repository.dart`, with tests.

**Interfaces (produced):** each takes `(AppDatabase, Clock)` and has a keepAlive provider.

**`ReferencesRepository`:**
- `Future<AddReferenceResult> add(int reelId, String rawUrl, {String? label})`:
  - normalises the URL, picks the source and checks the label
  - an invalid URL throws `InvalidInputException(ReferenceUrlProblem.invalid)`
  - returns `sealed AddReferenceResult` = `ReferenceAdded(ReelReference)` | `ReferenceAlreadySaved(ReelReference existing)`
- `setLabel(int id, String? label)`, `delete(int id)`, `Stream<List<ReelReference>> watchForReel(int reelId)` (newest first), and `Stream<Map<int, int>> watchCounts()` (reelId → count).

**`VnRepository`:**
- `Future<VnSession> startSession(int reelId, String baseFolderName)`: uses `uniqueFolderName` against existing sessions' folder names. Phase 8 also passes on-disk names.
- `Future<void> addCopy(VnCopy copy)`, `Future<List<VnCopy>> copiesOf(int reelId)` and `Future<void> endSession(int reelId)`.
- `Future<VnSession?> sessionOf(int reelId)`.

**`SettingsRepository`:**
- `Future<AppSettings> load()`: defaults for missing keys, and a corrupt value falls back to its default and logs the key name only.
- `Future<void> save(AppSettings s)` and `Stream<AppSettings> watch()`.
- Keys: `watchedFolders`, `eveningReminderEnabled`, `eveningReminderMinutes`.
- `static const exportedKeys = {...those three...}`. Keys added later for phone state (Shooting mode, baselines) are never in that set.

**`ZoneRepository`:**
- `Future<void> record(DateTime at, String zoneId)`: appends only when `zoneId` differs from the entry in effect at `at`.
- `Future<String?> zoneAt(DateTime instant)`, which uses the domain `zoneAt`.
- `Future<List<ZoneEntry>> all()`.

- [ ] **Step 1: Write the failing tests**

  - The igsh duplicate → `ReferenceAlreadySaved` (Review Focus 1).
  - The same URL in two different reels → both saved.
  - A 61-character label → throws.
  - A second VN session for a reel with the same name → folder `"Goa (2)"`.
  - Settings defaults, a save/load round-trip, and a corrupt JSON value → default.
  - `record` of the same zone twice → one entry; `zoneAt` lookups.

- [ ] **Step 2: Implement and run the tests**

  Expect PASS.

- [ ] **Step 3: Add D-58**

  Settings keys and the exported set; references dedupe on the normalised URL.

- [ ] **Step 4: Run `tool/check`, then commit**

  Commit message: `feat(data): references, VN, settings and zone repositories`.

---

### Task 9: Export and import (critical, Opus)

**Files:** create `app/lib/data/backup/{backup_format,backup_service}.dart`, `app/test/data/backup/backup_service_test.dart` and `app/test/data/backup/fixtures/backup_v1.json`.

**Interfaces (produced):**
- `const backupSchemaVersion = 1;`
- `BackupService(AppDatabase db, Clock clock)` and its provider.
- `Future<String> exportJson()`: pretty-printed with a 2-space indent and stable key order.
- `Future<ImportSummary> importJson(String json)`.
- `ImportSummary(reels, clips, references, inboxPending, inboxSkipped)` counts.
- `class BackupException implements Exception { final BackupProblem problem; }` with `BackupProblem { notJson, notTakeTray, newerVersion, invalidData }`.

**Format v1:** top-level keys, exact. Times are ISO-8601 UTC strings with milliseconds. Ids are the database ids.

```json
{
  "app": "TakeTray",
  "schemaVersion": 1,
  "exportedAt": "…Z",
  "reels": [{"id","name","description","status","createdAt","updatedAt"}],
  "references": [{"id","reelId","url","source","label","createdAt"}],
  "clips": [{"id","source","mediaStoreId","volumeName","pickerUri","sizeBytes","durationMs","dateTakenUtc","displayName","width","height","mimeType","timeZoneId","generationAdded","firstSeenAt","missing","lastVerifiedAt"}],
  "clipReels": [{"clipId","reelId","addedAt"}],
  "inbox": [{"clipId","state","addedAt"}],
  "settings": {"watchedFolders": [...], "eveningReminderEnabled": true, "eveningReminderMinutes": 1260},
  "zoneTimeline": [{"at","zoneId"}]
}
```

**What export leaves out:**
- `vn_sessions` and `vn_copies`
- settings outside `SettingsRepository.exportedKeys`

**How import works:**
1. Parse the file.
2. Check `app == "TakeTray"` (otherwise `notTakeTray`).
3. Check `schemaVersion`. Greater than 1 → `newerVersion`; missing or less than 1 → `notTakeTray`.
4. Validate everything before writing anything:
   - every field has its type
   - enums are known
   - every link and inbox `clipId` exists in `clips`
   - every `reelId` exists in `reels`
   - names and labels are within their limits

   Any failure → `invalidData`, and the database is untouched.
5. Then, in **one transaction**, delete every row from every table (including VN and phone-state settings) and insert everything, keeping the ids.

Unknown extra keys are ignored, so later versions can add fields.

- [ ] **Step 1: Write the failing tests**

  - **Round-trip:** seed a database with every kind of row (two reels, one in each of two statuses, a shared clip, a pending clip, a skipped clip, a picker clip, references with and without a label, a VN session, a zone timeline and non-default settings). Then export, import into a fresh database and export again. The two exports must be identical strings except `exportedAt`, and the VN session must be absent after the import.
  - **Golden fixture:** importing `fixtures/backup_v1.json` (hand-written, committed) gives the expected `ImportSummary`. This pins format v1 so later phases can't change it by accident.
  - **Failures leave data untouched (Review Focus 2):** for `notJson` (`'nope'`), `notTakeTray` (`{"app":"Other"}`), `newerVersion` (`schemaVersion: 2`) and `invalidData` (a clipReel pointing at clip 999, and a 41-character reel name): the right problem is thrown, and `watchAll()` still shows the original seeded reels.
  - **Import replaces:** import a backup into a database that already has other reels, and only the backup's reels remain.

- [ ] **Step 2: Implement and run the tests**

  Expect PASS.

- [ ] **Step 3: Update the docs**

  - Add **D-59**: backup format v1, its exclusions, validate-then-replace in one transaction, and that ids are kept.
  - Add a "Backup export and import" section to `docs/flow.md`. Note that file choosing is phase 10 and "X of Y clips found" is phase 3 or 10.

- [ ] **Step 4: Run `tool/check`, then commit**

  Commit message: `feat(data): versioned JSON export and import`.

---

### Task 10: Coverage gate

**Files:** create `tool/bin/check_coverage.dart` and `tool/test/check_coverage_test.dart`. Modify `tool/check` and `docs/flow.md`.

**Interfaces:** `dart run taketray_tool:check_coverage <lcov.info> <min-percent> <prefix>...` exits 1 when any prefix is below `min-percent`. It prints one line per prefix with its percentage and hit/found lines. Files ending in `.g.dart` or `.freezed.dart` are excluded. A prefix with no files fails ("no coverage data for <prefix>"), so a typo can't pass.

- [ ] **Step 1: Write the failing tests with small lcov strings**

  - above the threshold → passes
  - below → fails
  - generated files are excluded
  - an unknown prefix → fails

- [ ] **Step 2: Implement and wire it in**

  In `tool/check`, run the app's tests with `--coverage`, then:

  `tool/dart run taketray_tool:check_coverage app/coverage/lcov.info 80 lib/domain/ lib/data/`

  Leave a comment that phase 4 adds `lib/features/*/view_models/` once it exists (spec §10).

- [ ] **Step 3: Run `tool/check`**

  Expect it to pass, with both prefixes at 80 % or more. Write tests if they are short.

- [ ] **Step 4: Update the docs and commit**

  Update `docs/flow.md`. Commit message: `build(tool): coverage gate for domain and data`.

---

### Task 11: CI workflow (ready to push, not pushed)

**Files:** create `.github/workflows/check.yml`. Modify `docs/dev-setup.md`, `docs/decisions.md` and `docs/later.md` (the CI-related items, as each is cleared).

- [ ] **Step 1: Write the workflow**

  - Trigger on `push` and `pull_request`, running on `ubuntu-latest` with a 30-minute timeout.
  - Steps:
    1. checkout
    2. install Flutter 3.47.7 with `git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$HOME/development/flutter"`, the same path `tool/flutter` uses, so no wrapper change is needed
    3. cache `~/.pub-cache`
    4. run `tool/check` with `CI=true`, which turns off macOS goldens (D-39)
  - On failure, upload `**/test/**/failures/**` as an artifact.
  - No secrets and no deploy steps.

- [ ] **Step 2: Validate locally**

  Run `ruby -ryaml -e 'YAML.load_file(".github/workflows/check.yml")'`, or the Python equivalent. Expected: no error.

- [ ] **Step 3: Update the docs and commit**

  - Add **D-60**: CI runs `tool/check` on Ubuntu with CI goldens only, and Patrol stays local on the S24.
  - Update the dev-setup note on what CI checks.
  - Commit message: `ci: run tool/check on GitHub Actions`.

---

### Task 12: Phase 2 verification (needs the phone)

**Files:** create `app/patrol_test/database_test.dart`. Modify `docs/dev-setup.md` (a "Phase 2 check" section).

- [ ] **Step 1: Write a Patrol test that opens the real database on Android**

  It opens `appDatabaseProvider` on the device, creates a reel, reads it back through `ReelsRepository`, exports, and asserts the export contains the reel. This proves SQLite is packaged on Android.

- [ ] **Step 2: Run everything on the S24**

  Expected:
  - `tool/check` passes.
  - `tool/check_release_permissions` passes.
  - The release APK contains `lib/arm64-v8a/libsqlite3.so` (`unzip -l`).
  - `tool/patrol test -d RZCY80PHWCZ` (all Patrol tests) passes and installs **TakeTray Dev**, so `app.taketray` is untouched (`tool/adb shell pm list packages app.taketray` shows both).
  - The release TakeTray is reinstalled and opens on Reels.

- [ ] **Step 3: Owner check, added to `docs/dev-setup.md`**

  1. The phone shows two apps: TakeTray, and TakeTray Dev (the test copy).
  2. TakeTray opens as before.
  3. Nothing else is visible this phase: the data layer has no screens yet.

- [ ] **Step 4: Commit**

  Commit message: `test: phase 2 on-device database check`.

---

## After merge: move to GitHub (owner gate)

This happens only after the owner chooses "merge" at the end of the phase. It is not a subagent task.

1. Confirm with the owner: repository name `taketray`, **private**, under `yashsarda21`.
2. Run `gh repo create yashsarda21/taketray --private --source . --remote origin`, then `git push -u origin main`.
3. Watch the first Actions run with `gh run watch`. If it fails, fix it on a branch and merge.
4. Update the memory and `docs/dev-setup.md` with the repo URL.
