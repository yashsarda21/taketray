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

### Database open and migrations

Nothing opens the database yet: repositories (Tasks 6 to 8) read `appDatabaseProvider`, and the first screen that uses one opens it. See D-54.

1. `data/database/connection.dart › appDatabase` (`appDatabaseProvider`, kept alive): `AppDatabase(driftDatabase(name: 'taketray'))`, which is `taketray.sqlite` in the app's private documents folder (drift_flutter, SQLite from the `sqlite3` package's build hooks); `ref.onDispose(db.close)`. Tests call `test/support/test_database.dart › testDatabase` instead, which passes `NativeDatabase.memory()`.
2. Drift opens the file lazily, on the first query, and reads `PRAGMA user_version` (0 for a new file).
3. `data/database/app_database.dart › AppDatabase.migration`:
   1. `user_version` 0 (new file): `onCreate` runs `m.createAll()`, which creates the nine tables of `data/database/tables.dart` (with the `clips` identity `CHECK`s) and the indexes `clips_date_taken_utc`, `clip_reels_reel_id` and `vn_copies_clip_id`.
   2. `user_version` equal to `schemaVersion` (1): nothing to migrate.
   3. Any other version: `onUpgrade` throws `UnsupportedError` (only a database from a newer TakeTray gets here at version 1). Drift writes the new `user_version` only after `onUpgrade` succeeds, so the file is left as it was and the query fails.
   4. `beforeOpen`: `PRAGMA foreign_keys = ON`, on every open, so `ON DELETE CASCADE` works (`vn_copies.clip_id` has no foreign key on purpose, D-54).
4. Drift sets `user_version` to `schemaVersion` and runs the waiting query. Instants are read and written through `data/database/converters.dart › UtcMillisConverter` (UTC milliseconds in int columns), enums through `textEnum` (by name).

Changing the schema (by hand, `cd app`):
1. Edit `data/database/tables.dart` and bump `AppDatabase.schemaVersion`.
2. `../tool/dart run build_runner build`, then `../tool/dart run drift_dev make-migrations`: it dumps the new version to `drift_schemas/taketray/drift_schema_v<N>.json`, writes `lib/data/database/app_database.steps.dart` (the `stepByStep` helper), the schema helpers in `test/drift/taketray/generated/` and, once, `test/drift/taketray/migration_test.dart`.
3. Replace the throwing `onUpgrade` with `stepByStep(from1To2: …)` and write each step; fill in the generated data-integrity test.
4. `../tool/flutter test test/drift`: `migration_test.dart` migrates every older dump to every newer one and checks the schema; `schema_test.dart` opens every dump with today's `AppDatabase` and compares the result with the tables in code.
5. Commit the code, the dump and the generated files together; `tool/check_generated` (step 4 of "Local checks") fails while any of them is stale. Editing a table without bumping the version fails there too: `make-migrations` exits with "A schema for version 1 of the taketray database already exists and differs from the current schema", and `schema_test.dart` reports the differing column.

### Deleting a reel

Nothing calls this yet; the reel screens (phase 4 onwards) will. See D-56.

1. Phase 8 only, before step 2: the caller deletes the reel's VN copy files from `Movies/TakeTray/` (the `vn_copies` rows say which). Once the reel is deleted, nothing records them.
2. `data/repositories/reels_repository.dart › ReelsRepository.delete(id)`: opens `_db.transaction`, so steps 3 and 4 both happen or neither does.
3. Deletes the `reels` row (the call returns how many reels it deleted: 0 for an unknown id). SQLite's `ON DELETE CASCADE` (foreign keys are on, D-54) removes its `clip_reels`, `reel_references` and `vn_sessions` rows, and the `vn_copies` rows of those sessions.
4. `data/database/housekeeping.dart › AppDatabase.deleteOrphanClips`: deletes every clip that has no `clip_reels` row and no `inbox` row, and returns how many. A clip still in another reel, in To tag or in Skipped stays. `vn_copies` rows are not touched (no foreign key to `clips`, D-54). This runs even when the id was unknown, so it also removes any orphan that was already there.
5. The transaction commits; the repository logs the reel id, how many reels and how many clips were removed (never the name, D-10). Any `watchAll` / `watchById` stream re-queries and emits again.

### Tagging data changes

Nothing calls this yet; detection (phase 3), the tag player (phase 5) and the reel screens (phase 4 onwards) will. All in `data/repositories/clips_repository.dart › ClipsRepository`; every method that writes is one transaction, and every stream re-queries after any of the tables it reads change. See D-57. A clip's identity is `volumeName` + `mediaStoreId` (or `pickerUri`); "find" below means looking a clip up by that.

| Method | Writes |
|---|---|
| `addDetectedClips(clips)` | For each clip: if found, nothing (its id is returned). If new: one `clips` row (`firstSeenAt` = now) and one `inbox` row `pending`. Never touches `clip_reels`, `reels`. |
| `addNewClipsToReel(reelId, clips)` | For each clip: find, or insert a `clips` row. Then a `clip_reels` row (`addedAt` = now) for each clip the reel did not have, and `reels.updatedAt` = now if any was added. No `inbox` row is created; the clips' existing `inbox` rows (pending or skipped) are deleted. |
| `tagClip(clipId, reelIds)` | Deletes the `clip_reels` rows of reels not in `reelIds`; inserts rows (`addedAt` = now) for reels the clip was not in; rows that stay are not touched (`addedAt` kept). Deletes the clip's `inbox` row. `reels.updatedAt` = now for every reel that gained or lost the clip. `ArgumentError` if `reelIds` is empty. |
| `untagToInbox(clipId)` | Deletes all the clip's `clip_reels` rows; writes its `inbox` row as `pending` (`addedAt` = now); `reels.updatedAt` = now for the reels that lost it. |
| `skip(ids)` / `restore(ids)` | `inbox.state` = `skipped` / `pending` for the ids that have an `inbox` row. Nothing else. |
| `addClipsToReel(reelId, ids)` | A `clip_reels` row for each clip the reel did not have; `reels.updatedAt` = now if any was added. The clips' `inbox` rows (pending or skipped) are deleted. |
| `removeClipsFromReel(reelId, ids)` | Deletes those `clip_reels` rows; `reels.updatedAt` = now if any was removed; then `deleteOrphanClips()` (a clip in no reel and no list is deleted; its `vn_copies` row stays). |
| `recordVerification(found:, missing:)` | `clips.missing` and `clips.lastVerifiedAt` = now for the listed clips. |

Streams (`watchInbox(state)`, `watchPendingCount()`, `watchReelClips(reelId)`, `watchReelIdsOf(clipId)`) write nothing. The first and third sort by `clips.dateTakenUtc`, ties by `clips.id`.

Unknown ids: an unknown reel throws `StateError` in `addNewClipsToReel`, `tagClip`, `addClipsToReel` and `removeClipsFromReel`; an unknown clip throws `StateError` in `tagClip`, `untagToInbox` and `addClipsToReel`. Each check runs before the first write, so nothing is changed. `skip`, `restore`, `removeClipsFromReel` and `recordVerification` ignore clip ids that do not exist (`skip`/`restore` also ignore clips with no `inbox` row).

### References, VN folders, settings and time zones

Nothing calls these yet; the reference screens (phase 4 onwards), the VN copy flow (phase 8), settings (phase 10) and the native zone writer (phase 3) will. See D-58. Each is its own class in `data/repositories/`, built from `(AppDatabase, Clock)`.

**Adding a reference** (`references_repository.dart › ReferencesRepository.add(reelId, rawUrl, {label})`):

1. `normalizeReferenceUrl(rawUrl)` cleans the link (D-55). `null` throws `InvalidInputException(ReferenceUrlProblem.invalid)`.
2. `checkReferenceLabel(label)`; a label over 60 characters throws `InvalidInputException(ReferenceLabelProblem.tooLong)`. Both throws happen before the database is touched.
3. `_db.transaction`: an unknown reel throws `StateError`. Then it looks for a `reel_references` row with the same `reelId` and cleaned `url`.
4. Found: returns `ReferenceAlreadySaved(existing)`; nothing is written and the new label is ignored.
5. Not found: inserts the row (`source` from `referenceSourceOf`, `label` trimmed and null when blank, `createdAt` = now), sets `reels.updatedAt` = now in the same transaction, and returns `ReferenceAdded(reference)`. `ReferenceAlreadySaved` does not touch the reel.

`setLabel(id, label)` checks the label, then in a transaction updates the row and sets its reel's `updatedAt` = now (unknown id: `StateError`, nothing changes). `delete(id)` deletes one row and sets its reel's `updatedAt` = now in the same transaction (unknown id: nothing changes). `watchForReel` is newest first; `watchCounts` is reel id to count, without the reels that have none.

**VN session** (`vn_repository.dart › VnRepository`):

| Method | Writes |
|---|---|
| `startSession(reelId, base, {alsoTaken})` | Trims `base` (blank: `ArgumentError`). One transaction: unknown reel or a reel that already has a session throws `StateError`; the folder is `uniqueFolderName(base, {every vn_sessions.folderName} + alsoTaken)`; inserts the `vn_sessions` row. |
| `addCopy(copy)` | Inserts a `vn_copies` row. `StateError` when the reel has no session or already has a copy of that clip. |
| `endSession(reelId)` | Deletes the `vn_sessions` row; `ON DELETE CASCADE` deletes its `vn_copies` rows. The caller has deleted the files first. |

`sessionOf` and `copiesOf` only read.

**Settings** (`settings_repository.dart › SettingsRepository`): `load()` reads the rows whose key is in `exportedKeys` and decodes each value from JSON; a missing key, bad JSON, a wrong type or minutes outside 0 to 1439 gives that setting's default, and a corrupt one logs the key name. `save(settings)` upserts the three rows in one transaction and leaves other keys alone. `watch()` re-queries when the `settings` table changes and emits only when the result differs from the last one. Only `exportedKeys` (the three keys) is ever exported by a backup.

**Zone timeline** (`zone_repository.dart › ZoneRepository.record(at, zoneId)`): in a transaction, reads the last `zone_timeline` row at or before `at`; if its `zoneId` equals the new one nothing is written. Otherwise: if the last row strictly before `at` already has the new zone, the row at exactly `at` is deleted (it was the only way to get here); else a row `(at, zoneId)` is inserted (replacing a row at exactly `at`). Then the first row after `at` is deleted when it has the new zone, so the timeline never has two neighbours with the same zone. `zoneAt(instant)` reads the whole timeline, oldest first, and runs the domain `zoneAt` on it.

### Backup export and import

Nothing calls this yet. The Settings screen (phase 10) will choose the file with the Storage Access Framework and show the warning before an import; the "X of Y clips found" report after an import needs the media bridge (phase 3) and that screen (phase 10). See D-59. All in `data/backup/`.

**Export** (`backup_service.dart › BackupService.exportJson()`):

1. `_db.transaction` (one consistent snapshot) reads `reels`, `reel_references` and `clips` by id, `clip_reels` by clip then reel, `inbox` by clip, `zone_timeline` by time, and the settings through `SettingsRepository.load()` (only `exportedKeys`; a missing or corrupt one is its default). `vn_sessions`, `vn_copies` and every other `settings` key are not read.
2. `backup_format.dart › encodeBackup(data, clock.now())` writes the v1 object (`app`, `schemaVersion`, `exportedAt`, then the seven sections) with `JsonEncoder.withIndent('  ')`; times are UTC ISO-8601 with milliseconds and `Z` (`DateTime.toIso8601String`, so a year outside 0000 to 9999 is `-0001` or `+010001`).
3. Logs the row counts (never names, links, labels or file names, D-10) and returns the text.

**Import** (`backup_service.dart › BackupService.importJson(json)`):

1. `backup_format.dart › decodeBackup(json)` reads the whole file before the database is touched:
   1. `jsonDecode`; a `FormatException` → `BackupException(notJson)`.
   2. Not an object, or `app` is not "TakeTray" → `notTakeTray`. `schemaVersion` missing, not a whole number or below 1 → `notTakeTray`; above `backupSchemaVersion` (1) → `newerVersion`, without reading the rest.
   3. `_readV1`: `exportedAt`, then `reels`, `references`, `clips`, `clipReels`, `inbox`, `zoneTimeline` and `settings`, each through `_Fields`, whose getters throw `_Invalid('<path>')` for a missing key or a wrong type; the section loops check ids (1 to 2^53, unique), links to `reels` and `clips` read earlier, duplicates, names, labels, links, the clip identity rule, minutes and times (D-59 lists them). Any `_Invalid` → `BackupException(invalidData, where: path)`. Text is trimmed, links cleaned as the repositories do, and times cut to whole milliseconds (as stored), so a duplicate zone instant is caught here. A time is read by `_parseInstant`: the `_instant` pattern (year `dddd`, `-dddd` or `±dddddd`), then `DateTime.utc` of the fields must give back the same fields (no 30 February, no wrapped year) and `DateTime.parse` must not throw (a time past what a `DateTime` holds is invalid, not a crash).
   4. Normalising: of the references of one reel with the same cleaned link, all but the one with the lowest id are dropped; an `inbox` row whose clip has a `clip_reels` row is dropped (the link wins, D-57); then every clip with neither a link nor an `inbox` row is dropped (the orphan rule, D-56). `BackupData.referencesDropped`, `inboxRowsDropped` and `orphanClipsDropped` count them.
   5. On any `BackupException`: logs the problem and path (no values) and rethrows. Nothing was written.
2. `_replaceAll` › `_db.transaction`: deletes every row of `vn_copies`, `vn_sessions`, `clip_reels`, `inbox`, `reel_references`, `clips`, `reels`, `settings` and `zone_timeline` (children first), then one `batch` inserts `reels`, `clips`, `clip_reels`, `inbox`, `reel_references`, the three settings rows (each value `jsonEncode`d, as `SettingsRepository.save` writes them) and `zone_timeline`, all with the file's ids. Any failure rolls the whole transaction back. A `SqliteException` with result code `SQLITE_CONSTRAINT` (directly, or as the `remoteCause` of drift's `DriftRemoteException` when the database runs on its background isolate) is logged by its code only and rethrown as `BackupException(invalidData)`; any other error is rethrown as it is.
3. Imported ids may be ids used before the import; that is safe because `vn_copies`, the only table where a clip id outlives its clip, was emptied in the same transaction (D-54). SQLite moves each `AUTOINCREMENT` counter (`sqlite_sequence`) up to the highest inserted id and never down, so rows added later get ids above every imported one.
4. Logs the counts (and the dropped inbox rows, orphan clips and duplicate references) and returns `ImportSummary(reels, clips, references, inboxPending, inboxSkipped)`. Every `watch…` stream re-queries. Shooting mode is off afterwards (its key is gone); phase 3 resets the baselines.

### Local checks (`tool/check`)

Run from anywhere; the script changes to the repo root and stops at the first failing step. A fresh clone, or any ARB edit, needs `tool/flutter pub get` (or `tool/flutter gen-l10n`) before analyze or IDE use, because `app/lib/l10n/gen/` is generated, not committed (D-27); `tool/check` does the `pub get` itself.

`tool/check` declares `FLUTTER_MEMBERS=(app packages/taketray_ui widgetbook)` and `DART_MEMBERS=(tool)`, and `DST_MEMBER=app` with `DST_TESTS=(test/domain/rules/earlier_window_test.dart)`, the test files whose daylight-saving cases need Europe/London (step 9b). Every listed member must have a `pubspec.yaml`: a missing one fails the check, so a rename or deletion cannot pass silently (D-34).

1. `tool/check` › workspace guard: reads the `workspace:` list in the root `pubspec.yaml` (the `  - x` lines after `workspace:`, up to the first non-list line). Before that, a member listed in both `FLUTTER_MEMBERS` and `DART_MEMBERS` fails with `FAIL: member <x> is listed in both FLUTTER_MEMBERS and DART_MEMBERS in tool/check; it must be in exactly one`. Any entry that is in neither `FLUTTER_MEMBERS` nor `DART_MEMBERS` fails with `workspace member <x> is not covered by tool/check`, so a new member cannot silently escape the checks. Then fails with `FAIL: <kind> member <x> is listed in tool/check but <x>/pubspec.yaml is missing` for any listed member without a `pubspec.yaml`, with `FAIL: style directory <d> is listed in tool/check but does not exist` for a missing `STYLE_DIRS` entry, and with `FAIL: daylight-saving test <member>/<file> is listed in tool/check but does not exist` for a missing `DST_TESTS` file.
2. `tool/check` › SDK version: runs `tool/flutter --version`; fails with `Expected Flutter <x>` unless the output contains `Flutter 3.47.7` (`EXPECTED_FLUTTER` in the script).
3. `tool/check` › `tool/flutter pub get` at the root (resolves the whole workspace into the single `pubspec.lock`).
4. `tool/check` › `tool/check_generated` (see "Generated-file freshness" below): prints `stale: <path>` and fails when a committed generated file differs from what the generators write now (D-53).
5. `tool/check` › `python3 design/tools/build_tokens.py --check`: regenerates every token output in memory and compares it with disk (see "Token build"); prints `stale: <path>` for each difference and `orphan: <path>` for each leftover file in the generated-only folders, and fails; or fails on a contrast failure. Writes nothing (D-35).
6. `tool/check` › `tool/dart format --output=none --set-exit-if-changed` over `lib`, `test`, `patrol_test` of each Flutter member that has them, plus the whole of each Dart member (`tool`).
7. `tool/check` › analyze each member (rules from its own `analysis_options.yaml`): `tool/flutter analyze` in each Flutter member, `tool/dart analyze --fatal-infos` in each Dart member (plain `dart analyze` exits 0 on infos, so the flag keeps the zero-issue bar).
8. `tool/check` › `tool/dart run taketray_tool:check_styles <dir>` for each of `app/lib/features` and `packages/taketray_ui/lib/src/components` (`STYLE_DIRS`):
   1. `tool/bin/check_styles.dart › main`: lists `**/*.dart` under the directory (skips `*.g.dart`, `*.freezed.dart`; a missing directory prints `check_styles: directory <dir> not found` and exits 1).
   2. `tool/lib/src/style_rules.dart › findStyleViolations`: per file, blanks comments out of the whole text (`_blankComments`, offsets kept), runs each rule regex over the full text so multi-line calls match, maps each match start to its line, and skips it when `// style-check: allow <reason>` is on that line or on a comment-only line above. Covered forms: `Color*`/`Colors.`, `TextStyle(`, `EdgeInsets[Directional].*`, `SizedBox(width|height:)` and `SizedBox.square(dimension:)`, `BorderRadius[Directional].circular` and `Radius.circular`, and `Duration(` in any unit from microseconds to days.
   3. Back in `main`: prints `path:line rule snippet` per violation and exits 1, otherwise exits 0.
9. `tool/check` › tests in each Dart member (`tool/dart test`, which includes `tool/test/style_rules_test.dart`, `check_generated_test.dart`, `check_script_test.dart` and `check_coverage_test.dart`), then in each Flutter member (`tool/flutter test`, which without `CI` runs the `goldens/macos/` comparisons and not `goldens/ci/`, D-61; the member named in `COVERAGE_MEMBER`, `app`, runs `tool/flutter test --coverage`, which also writes `app/coverage/lcov.info`; the folder is git-ignored). A member without a `test/` folder fails with `<member> has no test/ folder`.
9a. `tool/check` › `write_coverage_imports`, just before the `app` test run (and nowhere else, so the format and analyze steps never see the file): writes `app/test/_coverage_imports_test.dart`, a test with one empty case that imports every non-generated `.dart` file under the `COVERAGE_PREFIXES` (relative to `app/`: `lib/domain/`, `lib/data/`, `lib/platform/`, `lib/features/*/view_models/`). A `*` in a prefix expands as a shell glob, so it is exactly one folder name. `*.g.dart` and `*.freezed.dart` are skipped (generated, D-53), and so is any file that starts with `part of` (a part cannot be imported). The script prints one count per prefix, for example `coverage imports: lib/domain/ 13 files, lib/data/ 13 files, lib/platform/ 0 files, lib/features/*/view_models/ 0 files`, so a glob that matches nothing is visible in the log. The task that creates the view models (Task 9) must see its count become non-zero there; a stuck 0 means the files are not being counted. (`lib/platform/` has counted since Task 3: `lib/platform/ 1 files`, `media_bridge.dart`.) The file is deleted right after the test run, by an `EXIT` trap if the run fails, and at the start of the next run if a killed run left it; it is git-ignored and never committed (D-65).
9b. `tool/check` › the step `daylight-saving tests (TZ=Europe/London)`: `(cd app && TZ=Europe/London tool/flutter test --run-skipped test/domain/rules/earlier_window_test.dart)` (the `DST_TESTS`). Its London cases (2026-10-25, clocks go back, a 25-hour day; 2027-03-28, clocks go forward, a 23-hour day; a UTC `now` at 00:30 summer time, which is still the day before in UTC) skip themselves, with a reason, in any other zone, so in the run of step 9 they skip unless the machine is in London (CI runs in UTC). Here they run in London, and `--run-skipped` means they cannot skip: the case `the zone is Europe/London` fails if `TZ` did not take effect, and the others fail with wrong instants. The rest of the file runs a second time too. See D-69.
9c. `tool/check` › `tool/test_android`, the step `android unit tests`: the Kotlin media bridge's Robolectric tests (see "Android unit tests" below, D-67). Needs a JDK and the Android SDK.
10. `tool/check` › `tool/dart run taketray_tool:check_coverage app/coverage/lcov.info 80 lib/domain/ lib/data/ lib/platform/ 'lib/features/*/view_models/'`: at least 80 % of the executable lines under each prefix must have run in a test. Because of step 9a every file under a prefix is loaded, so a file no test uses shows up in lcov with all its lines at 0 and lowers the total.
    1. `tool/bin/check_coverage.dart › main`: needs the lcov file, a minimum from 0 to 100 (not `NaN`) and at least one prefix, otherwise prints `usage: ...` and exits 64. A prefix must end in `/` (so `lib/data` cannot match `lib/database_x/`); a `*` is allowed only as a whole segment (`lib/feat*/` and `lib/**/` are usage errors). A missing lcov file prints `check_coverage: <file> not found` and exits 1.
    2. `_parseLcov`: reads the lcov text, one record per source file (`SF:` path, one `DA:<line>,<times run>` per executable line, `end_of_record`). A file counts every `DA:` line as found and every `DA:` with a count above 0 as hit. Files ending in `.g.dart` or `.freezed.dart` are dropped (generated code, D-53). A file with no `DA:` lines (an enum, an interface) adds nothing.
    3. `_prefixPattern`: turns a prefix into the regular expression `^` plus the prefix, with each `*` segment as `[^/]+` (one non-empty folder name) and everything else escaped, so `lib/features/*/view_models/` matches `lib/features/a/view_models/x.dart` and `.../view_models/sub/y.dart` but not `lib/features/a/b/view_models/x.dart`.
    4. Back in `main`, per prefix: adds up found and hit over the files whose path matches it and prints `<prefix>  <percent>%  <hit>/<found> lines`, for example `lib/domain/  96.9%  62/64 lines`. A prefix that matches no file with lines prints `<prefix>  no files` and passes, because `lib/platform/` and the view-model folders do not exist yet (Tasks 3 and 9). If no prefix at all matches a file, each prints `check_coverage: no coverage data for <prefix>` and the run fails, so a typo or the wrong lcov file cannot pass. A percentage below the minimum prints `check_coverage: <prefix> is below <min>%`. Any failure exits 1 after every prefix has been printed.
11. `tool/check` › prints `ALL CHECKS PASSED`.

### Automatic checks on GitHub (`.github/workflows/check.yml`)

Runs on every `push` and `pull_request`, and by hand (`workflow_dispatch`); nothing is deployed and there are no secrets. See D-60.

1. Workflow header: `permissions: contents: read`; `concurrency` group `check-<workflow>-<ref>` with `cancel-in-progress` for every ref except `refs/heads/main`, so a newer run on the same branch or pull request cancels the older one, while main runs always finish; `env.CI: "true"` (turns the macOS goldens off and the Linux `goldens/ci/` comparisons on, D-61) and `env.FLUTTER_VERSION: "3.47.7"` (must equal `EXPECTED_FLUTTER` in `tool/check`).
2. Job `check` on `ubuntu-latest`, `timeout-minutes: 30`: `actions/checkout` (`persist-credentials: false`).
3. `actions/cache` on `~/development/flutter`, key `flutter-<os>-<version>`. On a miss, `git clone --depth 1 --branch 3.47.7` into that folder (the path `tool/flutter` and `tool/dart` use).
4. `Prepare Flutter`: `tool/flutter config --disable-analytics`, `tool/flutter precache --universal` (Dart SDK, the test engine `flutter_tester`), `tool/flutter --version`. `tool/check` builds no APK; the Android unit tests use the image's Android SDK (step 9).
5. `actions/cache` on `~/.pub-cache`, key `pub-<os>-<hash of pubspec.lock>`, falling back to the newest `pub-<os>-` entry.
6. `Check required programs`: fails with `missing on the runner: <name>` unless `git`, `python3`, `shasum`, `awk`, `find` and `sort` exist.
7. `actions/setup-java@v4`: Temurin JDK 17, for Gradle and the Android unit tests (D-67).
8. `actions/cache` on `~/.gradle/caches`, `~/.gradle/wrapper` and `~/.m2/repository/org/robolectric` (the Android framework jars Robolectric downloads), key `gradle-<os>-<hash of app/android/**/*.gradle.kts, gradle-wrapper.properties and robolectric.properties>`, falling back to the newest `gradle-<os>-` entry.
9. `Check the Android SDK`: fails unless `ANDROID_HOME` is `/usr/local/lib/android/sdk` with a `platforms/` folder (the ubuntu image provides the SDK there), and fails with `Flutter names NDK '<x>' but ANDROID_NDK_VERSION is '<y>'` unless `env.ANDROID_NDK_VERSION` (`28.2.13676358`) equals the `ndkVersion` in Flutter's `FlutterExtension.kt`; prints the platforms, build-tools, NDKs and `java -version`.
9a. `actions/cache` on `/usr/local/lib/android/sdk/ndk/<ANDROID_NDK_VERSION>`, key `ndk-<os>-<version>`. On a miss, `Install the Android NDK`: `sdkmanager --install "ndk;<version>"`, up to three attempts (a failed one deletes the partial folder), then fails unless the NDK's `source.properties` exists. Gradle needs this NDK even to configure the unit tests, because the `jni` plugin (used by `path_provider_android`) has a native build pinned to `flutter.ndkVersion`.
10. `tool/check` (the "Local checks" flow above), unchanged; with `CI` set it compares `goldens/ci/`, the images made on Linux by the flow below. Its `android unit tests` step writes `local.properties` and `gradlew` with `tool/flutter build apk --debug --config-only` first (they are git-ignored).
11. On failure, `actions/upload-artifact` stores every `failures/` folder under a `test/` folder as `golden-failures`.

Not on CI: Patrol and device tests, and `tool/check_release_permissions`.

### Updating CI goldens (`.github/workflows/update-goldens.yml`, `tool/pull_ci_goldens`)

The `goldens/ci/` images must be made on Linux, the machine that compares them (D-61). Two steps, one on GitHub and one on the Mac; nothing is committed or pushed by either.

1. `.github/workflows/update-goldens.yml` (`workflow_dispatch` only, `permissions: contents: read`; started from the Actions tab or `gh workflow run update-goldens.yml --ref <branch>`):
   1. `env.CI: "true"`, `env.FLUTTER_VERSION: "3.47.7"`; job `update` on `ubuntu-latest`, `timeout-minutes: 30`; checkout, the Flutter and pub caches and the Flutter install and precache exactly as in `check.yml`; `tool/flutter pub get`.
   2. In `packages/taketray_ui`: `../../tool/flutter test --update-goldens --tags golden`. With `CI` set `flutter_test_config.dart` enables only the CI goldens, so only `goldens/ci/` is rewritten. (`packages/taketray_ui` is the only member with CI goldens.)
   3. `find . -path '*/goldens/ci/*.png'` copies every image into `$RUNNER_TEMP/ci-goldens` with `cp --parents`, keeping its repository path, and prints how many; `actions/upload-artifact` stores that folder as `ci-goldens` (fails if it is empty).
2. `tool/pull_ci_goldens <run-id>` on the Mac:
   1. Usage error (exit 64) unless there is exactly one numeric argument. Fails with a clear message if `gh` is not installed or `gh auth status` fails.
   2. Fails and lists the files if `git status --porcelain --untracked-files=all` shows any change under a `goldens/ci/` folder.
   3. `gh run download <run-id> -n ci-goldens -D <temp dir>`; fails if the artifact has no `goldens/ci/*.png`.
   4. Deletes each tracked `goldens/ci/*.png` that the artifact does not have, then copies every artifact image to the same repository path (creating folders for new tests).
   5. Prints the number copied and `git status --short` for the `goldens/ci/` paths. The owner looks at the images, commits and pushes; the `check` run then compares them on Linux.

### Generated-file freshness (`tool/check_generated`)

Run by `tool/check` (step 4), or by hand: `tool/check_generated` (all members) or `tool/check_generated app`. Run `tool/flutter pub get` first. See D-53. Pigeon outputs are covered too (D-66).

1. `tool/check_generated` › start: `cd`s to the repo root and sets `root`. Without arguments it finds every `pubspec.yaml` up to three levels deep (outside `.dart_tool` and `build`) that has a `  build_runner:` or a `  pigeon:` line inside its `dev_dependencies:` section (`has_dev_dependency`); none found prints `no member with build_runner or pigeon in dev_dependencies found` and exits 1.
2. Per member, `hash_generated`: lists `*.g.dart` and `*.freezed.dart` under `lib/` and `test/`, `*.g.kt` under `android/app/src/` (Pigeon's Kotlin output), everything under `drift_schemas/` and everything under `test/drift/` (folders that do not exist are skipped), sorted, and runs `shasum` on each. The result is `path<TAB>sha1` lines, saved as "before".
3. `delete_generated_code`: deletes every `*.g.dart` and `*.freezed.dart` under `lib/` and `test/` (except under `test/drift/`) and every `*.g.kt` under `android/app/src/`; `drift_schemas/` and `test/drift/` are kept, because old schema dumps cannot be regenerated. A generated file that no generator writes any more therefore stays gone.
4. If the member has `pigeon` in `dev_dependencies`: `(cd <member> && tool/dart run pigeon --input pigeons/<file>.dart)` for every `<member>/pigeons/*.dart`, first, so build_runner sees the Dart output; then `tool/dart format` on the `*.g.dart` files that exist at that moment (only Pigeon's, because step 3 deleted the rest), because Pigeon does not format its output and the format step of `tool/check` would otherwise fail on it. If it has `build_runner`: `tool/dart run build_runner build` regenerates the files. If `<member>/build.yaml` exists and contains `databases:`, `tool/dart run drift_dev make-migrations` runs as well. A failing generator fails the script.
5. `hash_generated` again, saved as "after". An `awk` join of the two lists collects every path whose hash changed, that is only in "before" (disappeared, which includes orphans removed in step 3) or only in "after" (appeared). It checks the working tree, not the commit: a fresh file that was never `git add`ed passes.
6. If any path was collected, prints `stale: <path>` for each and `generated files were out of date and have been regenerated; review and commit them` to stderr, exit 1; the regenerated files stay on disk. Otherwise prints `generated files fresh`, exit 0.

`app/lib/l10n/gen/` is not checked: it is git-ignored and rebuilt by `pub get` (D-27).

### Native bridge (`lib/platform/`, `pigeons/media_api.dart`)

Nothing in Dart calls the bridge yet: the scanner, the verifier and the screens (Tasks 7 to 10) will. The Kotlin side is the real MediaStore reader, registered by `MainActivity` (Task 4, "Kotlin side" below). See D-66. Paths are relative to `app/`.

**Making the contract** (by hand, when a new native question is needed):

1. `pigeons/media_api.dart`: edit the message classes or `MediaHostApi`; `@ConfigurePigeon` names the two outputs and the Kotlin package `app.taketray.media`.
2. `cd app && ../tool/dart run pigeon --input pigeons/media_api.dart` writes `lib/platform/media_api.g.dart` (Dart `MediaHostApi` class that sends on channels named `dev.flutter.pigeon.taketray.MediaHostApi.<method>`, plus the `*Msg` classes) and `android/app/src/main/kotlin/app/taketray/media/MediaApi.g.kt` (the Kotlin `MediaHostApi` interface, with `suspend fun` for `@async` methods, and `MediaHostApi.setUp(binaryMessenger, api)`).
3. `lib/platform/media_bridge.dart`: add the method to `MediaBridge` (domain types) and to `PigeonMediaBridge`; `test/support/fake_media_bridge.dart`: add it to `FakeMediaBridge`.
4. `tool/check_generated` fails (step 4 of "Local checks") when a committed `*.g.dart` or `*.g.kt` of the contract is not what Pigeon writes now.

**One call, for example the scan asking for new videos** (Dart side, today):

1. A caller (Task 7 on) reads `ref.read(mediaBridgeProvider)`, `platform/media_bridge.dart › mediaBridge`, kept alive, which builds `PigeonMediaBridge()`.
2. `media_bridge.dart › PigeonMediaBridge.videosAddedAfter(volumeName, afterGeneration, folders, limit)` calls the same method on its `MediaHostApi` (`media_api.g.dart`).
3. `media_api.g.dart › MediaHostApi.videosAddedAfter` sends `[volumeName, afterGeneration, folders, limit]` on the channel with `BasicMessageChannel` and the generated codec. **[bridge]**
4. Kotlin: `MediaHostApi.setUp` (in `MediaApi.g.kt`) decodes the arguments and launches `MediaHostApiImpl.videosAddedAfter` in a coroutine on `Dispatchers.Main`; the method moves to `Dispatchers.IO` for the query (see "Kotlin side" below), and the reply is sent on the main thread when it returns.
5. The answer returns the other way: a reply list holding the `VideoRowMsg` list, or an error list. `media_api.g.dart › _extractReplyValueOrThrow` throws a `PlatformException` for an error list, for a missing reply (code `channel-error`: nobody answered on the channel) and for a null where a value is required (code `null-error`). `PigeonMediaBridge` does not catch it.
6. `media_bridge.dart › _videos` maps each `VideoRowMsg` to a `MediaVideo` (same fields; a null `mimeType` becomes `video/*`), and other calls map their messages the same way: `_access` for `AccessReportMsg` (level enum), `volumes` to `MediaVolume`, `videoFolders` to `VideoFolder`, `pendingZoneChanges` to `ZoneEntry(at: DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true), zoneId)`.

**Kotlin side** (`android/app/src/main/kotlin/app/taketray/`; D-66, D-67, D-68):

1. `MainActivity.configureFlutterEngine`: `super` (plugins), then `MediaHostApi.setUp(messenger, MediaHostApiImpl(this))`, then `DebugHooks.register(engine)` (empty in `src/debug`, `src/release`, `src/profile`; Task 11 fills the debug one). `cleanUpFlutterEngine` unregisters it (`setUp(messenger, null)`) and calls `onHostGone`.
2. Synchronous methods run on the main thread inside `guarded(method)`: `accessReport`, `openAppSettings`, `currentZoneId`, `pendingZoneChanges`, `clearZoneChangesUpTo`, `openVideoCamera`. The `suspend` ones that read MediaStore (`volumes`, `videosAddedAfter`, `videosByIds`, `allVideos`, `videosShotSince`, `videoFolders`, `thumbnail`) run `withContext(Dispatchers.IO) { guarded(method) { ... } }`. `guarded` turns any exception other than a `FlutterError` into `FlutterError("native-error", "<method> failed: <ExceptionClass>")` and logs the same at warning level under the tag `TakeTrayMedia`; the exception's message (it can hold a URI or path) never leaves Kotlin (D-10).
3. **Access** (`MediaAccessChecker`, D-68): `accessReport` reads `level(SDK_INT) { checkSelfPermission(it) == GRANTED }`; when it is full it clears `media_request_blocked` (in `taketray_native` preferences); then `canAskAgain(level, rationale, blocked)` (true for full, for limited, with a rationale, or when not blocked), where rationale is `activity.shouldShowRequestPermissionRationale(permissionsToRequest(SDK_INT).first())`. `requestAccess` (main thread): no activity → `FlutterError("no-activity")`; a request already waiting → `FlutterError("busy")`; else it reads the rationale (before), stores a `CompletableDeferred`, calls `requestPermissions(permissionsToRequest(SDK_INT), 0x7A71)` inside `guarded` (a throw becomes `native-error` and frees the slot) and awaits. `MainActivity.onRequestPermissionsResult` → `onPermissionResult(requestCode)` completes it (another code, or nothing waiting, is ignored). The level and the rationale (after) are read again, `blocked = blockedAfterRequest(level, before, after, wasBlocked)` (`!full && !after && (before || wasBlocked)`) is saved, and the report returns with `canAskAgain(level, after, blocked)`. `MainActivity.onDestroy` / `cleanUpFlutterEngine` → `onHostGone` fails a waiting request with `FlutterError("host-gone")` and drops the activity.
4. **Volumes** (`Volumes.kt`): `readVolumes(MediaStoreVolumes(context))` takes `MediaStore.getExternalVolumeNames`, sorted; for each, `version` (`MediaStore.getVersion`, null when it throws `IllegalArgumentException` or `IllegalStateException`) and `getGeneration`. A volume whose version or generation read throws anything else is left out (logged by volume name and exception class).
5. **Rows** (`VideoQueries`): every query is `resolver.query(MediaStore.Video.Media.getContentUri(volume), PROJECTION, args, null)` with a `Bundle`: `QUERY_ARG_SQL_SELECTION` / `_ARGS`, `QUERY_ARG_SQL_SORT_ORDER`, `QUERY_ARG_MATCH_PENDING`, and `QUERY_ARG_MATCH_TRASHED = MATCH_EXCLUDE`. A null cursor is `FlutterError("no-cursor")`, never an empty list. Each row goes through `rowFrom` (columns by name; null SIZE → 0, null DISPLAY_NAME / RELATIVE_PATH → "", the other nullable columns stay null, IS_PENDING 1 → true).
   - `videosAddedAfter`: no folders or `limit <= 0` → `[]` without a query. Else `GENERATION_ADDED > ? AND (RELATIVE_PATH = ? COLLATE NOCASE OR ...)`, each folder `trim('/') + "/"`, pending included, `GENERATION_ADDED ASC, _ID ASC`, `QUERY_ARG_LIMIT` (capped at `Int.MAX_VALUE`).
   - `videosShotSince`: no folders → `[]`. Else `(folders) AND (DATE_TAKEN >= ? OR DATE_ADDED >= ? OR DATE_MODIFIED >= ? OR DATE_ADDED IS NULL)` with `sinceMs` and twice `floorDiv(sinceMs, 1000)`, pending excluded, `_ID ASC`.
   - `allVideos`: no selection, pending excluded, `_ID ASC`.
   - `videosByIds`: ids de-duplicated and chunked by 500, `_ID IN (?,...)` per chunk, pending included; the chunks' rows are concatenated (order not part of the contract).
   - `videoFolders`: for each volume in `names()`, reads RELATIVE_PATH of every finished video (pending excluded) and counts per path in Kotlin; sorted by volume, then path.
   - An empty folder list in a selection is `0` (matches nothing), never invalid SQL.
6. **Thumbnails** (`Thumbnails.load`): `ContentUris.withAppendedId(Video.Media.getContentUri(volume), id)`, `resolver.loadThumbnail(uri, Size(w, h), null)` (each side capped at 4096; zero or less is `native-error`); `FileNotFoundException`/`IOException`, `SecurityException` and `OperationCanceledException` → null; the bitmap is scaled down until its longer side is at most `max(w, h)` and encoded as JPEG quality 85.
7. **Zones** (`ZoneChangeStore`, `TimeZoneChangedReceiver`): the manifest receiver (not exported) gets `ACTION_TIMEZONE_CHANGED`, even when the app is closed, and calls `record(System.currentTimeMillis(), EXTRA_TIMEZONE ?: TimeZone.getDefault().id)`. `record` appends only when the zone differs from the last entry and keeps the newest 500; the list is a JSON array under `zone_changes` in `taketray_native` preferences, written with `commit()`; corrupt JSON reads as empty. `pendingZoneChanges` returns it oldest first; `clearZoneChangesUpTo(atMs)` keeps entries after `atMs`. `currentZoneId` is `TimeZone.getDefault().id`.
8. **Camera and Settings**: `openVideoCamera` starts `MediaStore.INTENT_ACTION_VIDEO_CAMERA` and returns false on `ActivityNotFoundException`; `openAppSettings` starts `ACTION_APPLICATION_DETAILS_SETTINGS` for `package:<this app>`.

**In tests:** `test/support/fake_media_bridge.dart › FakeMediaBridge` implements `MediaBridge` from lists the test sets. `videosAddedAfter` keeps rows with a higher generation in a listed folder (each asked folder gets one trailing `/`; the stored path is compared as it is, ignoring the case of A to Z only, like `COLLATE NOCASE`), pending rows included, oldest generation first, at most `limit`; `videosShotSince` is the superset the contract describes and leaves pending rows out; `allVideos` leaves pending rows out; `videosByIds` returns the rows that exist. `failNext(method)` makes the next call throw a `PlatformException`; `gate(method)` pauses the next call until the returned `Completer` completes (the answer is read when the call starts); `calls` is the log of method names. `test/platform/media_bridge_test.dart` tests `PigeonMediaBridge` against a stub `MediaHostApi` and, for the wire format and error replies, against the generated channels with a mock binary messenger.

### Android unit tests (`tool/test_android`)

Run by `tool/check` (step 9c) and so by CI, or by hand: `tool/test_android`, with any extra Gradle arguments (`tool/test_android --tests 'app.taketray.media.VideoQueriesTest'`). See D-67.

1. `tool/test_android` › `cd`s to the repo root. If `app/android/local.properties` is missing, its `flutter.sdk` is not `$HOME/development/flutter` (the Flutter `tool/flutter` runs), or `app/android/gradlew` is missing (both files are git-ignored and written by the Flutter tool), it runs `(cd app && ../tool/flutter build apk --debug --config-only)`.
2. `cd app/android && ./gradlew :app:testDebugUnitTest --console=plain "$@"`. With `unitTests.isIncludeAndroidResources`, Gradle first runs Flutter's `copyFlutterAssetsDebug` (and the Dart build behind it), ordered before `packageDebugUnitTestForUnitTest` by a `dependsOn` in `app/build.gradle.kts`.
3. The tests in `android/app/src/test/kotlin/app/taketray/media/`: `MediaAccessCheckerTest` is plain JUnit (the SDK level is an argument). The others use `RobolectricTestRunner` and run once per SDK level in `src/test/resources/robolectric.properties` (30, 33, 34, 35): `VideoQueriesTest` (selections, query arguments, `rowFrom` on a `MatrixCursor`), `VideoQueriesSqlTest` (the selections on real SQLite through a strict `SQLiteQueryBuilder`), `ZoneChangeStoreTest` (real preferences, and the receiver), `ThumbnailsTest` (`FakeMediaProvider` registered for the media authority throws on open; it also records every query's uri, projection and arguments and answers with a scripted cursor), `VolumesTest` (injected version read, fake `Volumes`) and `MediaHostApiImplTest` (the implementation on a Robolectric `Activity`: the permission request and every blocked transition, intents, zones, the queries it sends and the rows it returns, chunking, unknown volumes, null cursor, thumbnail sizes, error messages). `tool/test_android -ProbolectricSdks=35` runs one SDK level only (a Gradle property that `app/build.gradle.kts` passes on as `robolectric.enabledSdks`), for quick iterations; `tool/check` always runs all four. Robolectric downloads each SDK's framework jar into `~/.m2/repository/org/robolectric` on first use.
4. Gradle exits non-zero on any failing test; reports are in `app/build/app/reports/tests/testDebugUnitTest/` and `app/build/app/test-results/testDebugUnitTest/`.

### Token build (`design/tools/build_tokens.py`)

Run by hand after changing a token: `python3 design/tools/build_tokens.py`. Paths in this flow are relative to the repo root.

1. `design/tools/build_tokens.py` (module level): builds the tonal palettes from the seeds, the colour roles for every brand option (`SCHEMES`) and picks the shipped one (`SHIPPED` → `LIGHT`, `DARK`, `PALETTES`); defines `TYPE`, `SHAPE`, `SPACING`, `ELEVATION`, `MOTION`, `SIZE`, `VIDEO_SURFACE` and `EXTENDED` (REC red, success green).
2. `build_tokens.py › main`: `parse_args` (argparse; an unknown flag, even an abbreviation of `--check`, exits 2 with a usage message before anything runs). Then `check_contrast` for the shipped brand and every option; any pair below its WCAG threshold prints `CONTRAST FAILURES` and exits 1 before anything is generated.
3. `build_tokens.py › generate`: clears `OUTPUTS` and runs the writers, each handing its files to `emit(path, text)`: `write_json` (`design/tokens/taketray.tokens.json`, `design/prototype/assets/tokens.js`, `design/tokens/colour-options/*.json`), `write_css` (`design/prototype/assets/tokens.css`), `write_kotlin` (`design/handoff/compose/*.kt`) and `write_dart` (`packages/taketray_ui/lib/src/tokens/tokens.g.dart`: `ttLightScheme`, `ttDarkScheme`, `TtColorTokens`, `TtTypeTokens`, `TtSpaceTokens`, `TtRadiusTokens`, `TtMotionTokens`, `TtSizeTokens`; shipped brand only).
4. Back in `main`: without `--check`, writes every entry of `OUTPUTS`; with `--check`, `stale_outputs` compares each with the file on disk, prints `stale: <path>` for each difference; then `orphan_outputs` lists files matching `GENERATED_DIRS` (`design/tokens/colour-options/*.json`, `design/handoff/compose/*.kt`, folders that hold nothing hand-written) that are not in `OUTPUTS` and prints `orphan: <path>` for each. Exits 1 if there is any stale or orphan output (0 otherwise, silently). Folders that mix in hand-written files (`design/tokens/`, `design/prototype/assets/`) are not scanned.
5. `packages/taketray_ui/lib/src/theme/take_tray_theme.dart › TakeTrayTheme.light / dark / video`: build (once, cached) `ThemeData` from `ttLightScheme`, or `ttDarkScheme` after `_oled` (tt-style.css §1), or that with `surface` = `TtColorTokens.videoBackground`. `_build` creates `TtThemeData.fromScheme(scheme)` (`tt_theme_data.dart`), which builds `TtColors.fromScheme` (`tt_colors.dart`, scheme roles + `TtColorTokens` + `TtMetrics` opacities) and `TtTextStyles.fromScheme` (`tt_text_styles.dart`, `TtTypeTokens` with the scheme's `onSurface`), and installs it as the theme's only extension, next to the Material component themes (values in `tt_metrics.dart`).
6. `packages/taketray_ui/lib/src/theme/tt_theme_data.dart › TtBuildContext.tt` (in any widget): `Theme.of(context).extension<TtThemeData>()` (throws a `FlutterError` if missing); when `MediaQuery.maybeDisableAnimationsOf(context)` is true, returns `copyWith(motion: TtMotion.reduced)`. `context.scheme` returns `Theme.of(context).colorScheme`.

### Release permission check (`tool/check_release_permissions`)

Run manually (slow: full release build), at the end of every phase. Not part of `tool/check`. See D-31, D-64.

1. `android/app/src/main/AndroidManifest.xml`: `<uses-permission INTERNET tools:node="remove"/>` makes the manifest merger drop INTERNET from the merged release manifest; `src/debug` and `src/profile` manifests still declare it. Its `<application>` sets `allowBackup="false"`, `dataExtractionRules="@xml/data_extraction_rules"` and `fullBackupContent="@xml/backup_rules"`; the two files in `res/xml/` exclude every backup domain (D-64).
2. `tool/check_release_permissions` › start: `cd`s to the repo root, resolves the SDK (`$ANDROID_HOME` or `~/Library/Android/sdk`), picks the newest stable `build-tools/x.y.z` (version sort) that has an executable `aapt2`; if none, prints `No Android build-tools with aapt2 found in <dir>` and exits 1.
3. `tool/check_release_permissions` › `(cd app && ../tool/flutter build apk --release)`; exits on failure (`set -e`), then fails if `app/build/app/outputs/flutter-apk/app-release.apk` is missing.
4. `tool/check_release_permissions` › `aapt2 dump permissions` and `aapt2 dump xmltree --file AndroidManifest.xml` on the APK. An `awk` pass reduces the manifest dump to `application <attribute> <value>` lines and `permission <name> <maxSdkVersion|->` lines. If that pass yields no `permission` line or no `application` line, that is itself a problem (`no permissions were parsed from the manifest dump`), so a changed dump format cannot pass silently.
5. Backup: problems are collected when `allowBackup` is not `false` (including when it is missing), or `dataExtractionRules` or `fullBackupContent` is not set.
6. Forbidden permissions: a problem for each of `INTERNET`, `READ_MEDIA_IMAGES`, `MANAGE_EXTERNAL_STORAGE`, `ACCESS_MEDIA_LOCATION` found in the manifest (`<name> permission found in release build`), and again against `aapt2 dump permissions` (`... (aapt2 dump permissions)`), so a parse miss cannot hide one.
7. Required permissions (on by default since phase 3, Task 4; `ENFORCE_MEDIA_PERMISSIONS=0` switches them off for an experiment, D-68): a problem for each of `READ_MEDIA_VIDEO` and `READ_MEDIA_VISUAL_USER_SELECTED` that is missing, and for `READ_EXTERNAL_STORAGE` when it is missing or its `maxSdkVersion` is not 32.
8. If there are problems: prints the permission list, then one `RELEASE CHECK FAILED: <problem>` line each, to stderr, exit 1.
9. Otherwise prints the permission list and `RELEASE PERMISSIONS OK`, exit 0.

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
2. `core/logging/logging_setup.dart › formatRecord`: `2026-10-24T09:12:03.120Z LEVEL logger: message`, plus indented `error:` and `stack:` lines when present. Message and error text go through `_redact` (paths, URIs become `<path>`; a `FileSystemException` is rendered without its path). `_describeError` rebuilds database errors from their fields: `SqliteException(<code>): <message>` with no statement or values, a `DriftRemoteException` as its cause, an `InvalidDataException` as its failing columns, `CouldNotRollBackException` and `DriftWrappedException` by their causes; any other text containing `Causing statement` is cut there (`<statement removed>`), stack traces are kept as they are, and a record over 8 KiB is cut with `…[truncated]`.
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

1. `tool/patrol test -d <device>` (all tests in `patrol_test`; add `-t patrol_test/<file>.dart` for one): puts the pinned Flutter (`~/development/flutter/bin`) and the Android SDK `platform-tools` first on `PATH`, sets `PATROL_ANALYTICS_ENABLED=false` (analytics off for this run; see `docs/dev-setup.md` for the config file), `cd`s to `app/`, inserts `--no-uninstall` after `test`/`develop` unless the caller passed `--uninstall` or `--no-uninstall`, and runs `patrol_cli` (`~/.pub-cache/bin/patrol`) with `--flutter-command` set to the pinned `flutter`. The generated `patrol_test/test_bundle.dart` (git-ignored) is deleted when the command exits, so `tool/check` never sees it.
2. `patrol_cli`: reads the `patrol:` block of `pubspec.yaml` (`app_name: TakeTray`, `android.package_name: app.taketray.dev`), generates `test_bundle.dart` from the requested test file and has Gradle build the debug app APK plus the `androidTest` APK. The debug build type adds `applicationIdSuffix = ".dev"` and the launcher label "TakeTray Dev" (`manifestPlaceholders["appLabel"]`, read by `android:label="${appLabel}"` in the manifest), so the app Patrol installs and tests is a second app next to the owner's `app.taketray` (D-52); release and profile builds keep `app.taketray` and "TakeTray".
3. `android/app/build.gradle.kts` › `defaultConfig.testInstrumentationRunner`: the test APK uses `pl.leancode.patrol.PatrolJUnitRunner`; `testOptions.execution = ANDROIDX_TEST_ORCHESTRATOR` runs each test in a fresh process through the `androidTestUtil` orchestrator (`clearPackageData` wipes the data of `app.taketray.dev` between tests, never that of `app.taketray`).
4. **[bridge]** `android/app/src/androidTest/java/app/taketray/MainActivityTest.java › testCases`: starts `MainActivity` through the runner, waits for the Patrol app service in the app process and lists the Dart tests; `runDartTest` then runs one named test.
5. `patrol_test/app_shell_test.dart › main`: `patrolTest` pumps `ProviderScope(child: TakeTrayApp())`, asserts the Reels screen shows "Reels", taps "To tag" then "Settings" inside the `TtNavPill` (`$(TtNavPill).$('To tag')`, by label text) and asserts each placeholder screen shows its title (finders on the English labels, no sleeps; taps settle the UI).
6. `patrol_test/database_test.dart › main`: a second on-device test, with no screens. It makes a `ProviderContainer`, creates a reel through `reelsRepositoryProvider` (the first query opens `taketray.sqlite` in the dev app's storage through drift_flutter, loading the bundled `libsqlite3.so`), closes `appDatabaseProvider`, makes a second container, and reads the reel back with `getById` and through `backupServiceProvider.exportJson`. Finding the reel in the second container proves the row reached the file.
7. `patrol_cli` prints the per-step results and the summary, and writes an HTML report to `app/build/app/reports/androidTests/connected/debug/index.html`. Because of `--no-uninstall` it neither uninstalls before installing nor after the run: `app.taketray.dev` ("TakeTray Dev" on the phone, next to the real TakeTray) and `app.taketray.dev.test` stay on the device (the dev app's data is still cleared by the orchestrator, step 3; the real app is untouched).

### Accessibility check in component tests (`expectTtAccessible`)

Called by component tests after pumping a widget (`packages/taketray_ui/test/support/tt_accessibility.dart`). See D-62.

1. `expectTtAccessible`: turns semantics on, then expects, in order, `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `ttTextContrastGuideline` and, only when `Platform.isMacOS`, Flutter's `textContrastGuideline`. Semantics are disposed even when one fails.
2. `tt_text_contrast.dart › TtTextContrastGuideline.evaluate` → `measureTtTextContrast`, per render view:
   1. `_collectTargets`: walks the semantics tree exactly as Flutter's `MinimumTextContrastGuideline` does (skips invisible, merged, hidden and disabled nodes, routes and empty labels; for each label, the hit-testable `Text`/`EditableText` elements whose box meets the node), then `_textTarget` skips text more than 50 px off screen and records the font size and boldness Flutter would use, and the element's `RenderParagraph` or `RenderEditable`.
   2. `_collectShownTexts`: adds every other hit-testable, non-empty `Text` or `EditableText` in the view (text merged into a parent label, or excluded from semantics), unless `_effectiveSemantics` (the node it ends up in after merging) is disabled, hidden or invisible, or it is off screen. A text render object is never added twice.
   3. Collects every `RenderParagraph` and `RenderEditable` in the view and keeps their spans.
   4. `_restyleAll(_Paint.hidden)` gives each one a copy of its spans with the text colour transparent, shadows removed and any `decorationColor` transparent. A span with a `foreground`/`background` paint or a `backgroundColor`, or a run with no colour (own or inherited), throws `StateError`. Layout, compositing bits and paint are flushed; `_shoot` takes the view at one pixel per dp (as Flutter's guideline): the background image.
   5. `_restyleAll(_Paint.boxes)`: the same with `backgroundColor` set to each span's own colour (children inherit it). Second image: each run is a solid box in the text colour, composited like a glyph would be.
   6. `_restyleAll(_Paint.probe)`: the boxes in the inverted colour. Third image.
   7. In `finally`: the original spans are put back and the frame is flushed again, so nothing later sees the restyled text, also when a step threw.
   8. `_worstPair`, per target, inside its paint bounds:
      1. Box pixels are those the second or third image changed. A pixel with a 4-neighbour that is not a box pixel is dropped; if that leaves none (tiny text), all box pixels are used.
      2. Each kept pixel gives a (second-image colour, background colour) pair. Pairs are ranked by contrast ratio (lowest first; equal ratios by colour value).
      3. The worst pairs are skipped while together they make up no more than 2 % (`ignoredShare`) of the kept pixels; the next pair is the sample.
      4. No box pixel at all (the text is clipped away, or fully transparent) gives the background against itself, 1:1.
3. Back in `evaluate`: each sample whose ratio is more than 0.01 under `MinimumTextContrastGuideline.targetContrastRatio(fontSize, bold:)` adds a failure naming the text, the ratio, the font size and both colours (`#rrggbb on #rrggbb`).

### Catalogue coverage (`widgetbook/test/catalog_coverage_test.dart`)

Runs inside `tool/check` (step "test widgetbook") and with `(cd widgetbook && ../tool/flutter test)`. It keeps the Widgetbook catalogue complete (D-42).

1. `widgetbook/test/catalog_coverage_test.dart › main`: lists the `*.dart` files directly in `packages/taketray_ui/lib/src/components/` (none if the folder does not exist yet).
2. Same test: for each name, checks that `widgetbook/lib/components/<name>.dart` exists.
3. `widgetbook/test/catalog_coverage_test.dart › _imports`: checks that `widgetbook/lib/catalog.dart` has an import of `components/<name>.dart` (`package:taketray_widgetbook/components/...`).
4. Same test: `expect(problems, isEmpty)` fails listing every missing file and every missing import; a component without a catalogue file therefore fails `tool/check`.
5. `widgetbook/lib/catalog.dart › ttCatalog`: the registered components, read by `widgetbook/lib/main.dart › TakeTrayCatalogue` (`Widgetbook.material`) when the catalogue runs.
