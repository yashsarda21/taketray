# Phase 8: Editor Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reel's clips go to an editor in shooting order. CapCut and Instagram Edits get the originals in one direct share (a new project). VN gets temporary copies in `Movies/TakeTray/<Reel>`, made while TakeTray stays open. TakeTray remembers which clips are in the edit, splits the reel page into "New since you started editing" and "In your edit", copies only later clips into the reel's folder, reminds after 3 days, and deletes every copy on Done editing or from the storage screen. Done when clips open in one CapCut/Edits project, VN shows the folder, and copies are cleaned up (spec §9, phase 8).

**Architecture:**
- **Kotlin** (`android/.../editors/`): two thin Pigeon APIs. `EditorsHostApi` finds the editors, shares, opens apps and does every read and delete in `Movies/TakeTray/` through one guard that can only touch TakeTray's own copies. `CopyHostApi` drives `CopyEngine`, which copies on a background thread in the app's own process with `IS_PENDING`, reports progress and finished files, can be cancelled, keeps the screen on through the activity's window, and never writes the database (D-18, D-103). No foreground service in v1 (owner, 2026-11-12).
- **Dart rules** (`lib/domain/rules/`): folder names, copy file names, the space check, sizes, and the reel split. **Data**: schema **v2** (the first schema change) adds the editor of a session, the time of each copy and the clips sent directly. `EditSessionService` (`lib/data/editors/`) is the one place that starts, grows and ends an editing session, on its own serial queue.
- **Screens** (`lib/features/editors/`): clip selection, the editor sheet, the copy screens, the storage screen. The reel page (`lib/features/reels/`) gains the editing banner, the split and Done editing.

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; Drift with `make-migrations` (schema v1 → v2); freezed; go_router; gen-l10n; alchemist goldens (macOS plus CI sets, D-61; app screen goldens macOS-only, D-97); Pigeon 29.0.11; Kotlin with platform APIs and kotlinx-coroutines only; Robolectric 4.17 (`tool/test_android`); Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`: §1, §3 (CapCut shown whenever installed; VN folder clash " (2)"), §8.1 (`vn_sessions`, `vn_copies`), §8.2 `EditorsApi`, §8.4 (VN file names), §8.5 (VN copies reminder), §8.6 (orphaned VN copies), §9 phase 8, §11 (package names may change → "Other app…"). Visual source: `design/prototype/assets/screens.js` (`edit-select`, `vn-space`, `vn-copy`, `vn-ready`, `vn-storage`, `sheets.editor`, `sheets.share`, dialogs `doneEditing`, `markStatus`, `stopCopy`, `editorMissing`, `deleteReel`, the reel page VN banner, `menus.reelSel`, the viewer's Share), `ui.js` (`reelCard` pill, the tile's VN mark), `app.js` (`editVideo`, `selEdit`, `editContinue`, `pickEditor`, `vnAddConfirm`, `vnCopy`, `copyTick`, `finishCopy`, `cancelVN`, `vnAddMore`, `confirmDoneEditing`, `copiedInfo`, `notifTap` `vn`), `states.js` group "Sending to editors" (screens 18 to 23, 26). Owner decisions: `.superpowers/sdd/phase-8-design/owner-decisions.md` in the main checkout (binding; they override the prototype where they differ).

**Owner decisions (2026-11-12, recorded as D-118):**
1. VN cannot take several shared clips; CapCut and Edits can (owner tested). VN gets copies of every picked clip in `Movies/TakeTray/<Reel>`.
2. **Changed after the first plan (2026-11-12): no foreground service in v1.** Copying runs in the app while the user keeps TakeTray open; the copy screen keeps the screen on (`FLAG_KEEP_SCREEN_ON`, no permission) and says to keep TakeTray open. No new release permissions. If Android stops the app mid-copy, pending files are removed, finished copies kept, and Try again copies only the rest. Background copying with a foreground service is parked in later.md.
3. CapCut/Edits' first send is **direct** (`ACTION_SEND_MULTIPLE`, originals, shooting order): a new project, no copies.
4. Clips added to the reel later, while editing: copy **only those** into the reel's folder; the user adds them from that album. Never copy the whole reel for CapCut.
5. While editing, the reel page is split in two: "New since you started editing" (top, with the add button) and "In your edit".
6. TakeTray remembers which clips were sent to CapCut/Edits (schema v2). Done editing exists for CapCut/Edits too.
7. The add-later picker shows **every** live reel clip: new ones pre-ticked; already-sent ones selectable (ticking copies it); clips whose copy is in the folder show "In the folder" (nothing to copy); a copy deleted outside TakeTray can be copied again. VN works the same way.
8. Parked (later.md "After v1"): moving originals into a reel album.
9. Patrol tests are written first with no device and reviewed; only then the owner is asked for the S24.

**Rulings made for the owner (record in D-118; the owner checks them while reading):**
- R1. **One editing session per reel**, one folder per reel. The folder name is reserved when the session starts, for every editor, and stays until Done editing (a rename does not move it). While a reel is being edited, **Edit video** is hidden (FAB and ⋮); Done editing comes first, then another editor.
- R2. **Copy names** use the clip's local shooting time (`yyyy-MM-dd_HH-mm-ss`, the time the viewer shows) and keep the source's extension (a `.mov` stays `.mov`; unknown → `.mp4`; the spec's ".mp4" assumed MP4 sources). A clash adds `_2`, `_3`. MediaStore's own rename is read back and stored.
- R3. **Space check** keeps **500 MB** free for the phone; sizes show in decimal MB/GB as the prototype (`fmt.size`).
- R4. **One copy job at a time** across all reels. The copy screen keeps the screen on from the moment it shows until the job finishes, fails or is cancelled, or the screen is left. Leaving the app does not stop copying while Android keeps the process; when the user comes back, a result that is waiting opens the copy screen. The running job's plan is saved as a phone-state row (never exported) so a restart can recover.
- R5. For CapCut/Edits, the session and its sent clips are written **before** the share and rolled back if the share fails. **Other app…** and **Share** make no session and ask no status question.
- R6. **The 3-day reminder** fires once per copy batch, 3 days after the last copy, for any session with copies (VN, or CapCut/Edits folder copies). Its on/off switch waits for Phase 10's Settings.
- R7. The storage screen keeps the prototype's title "VN copies" and also lists CapCut/Edits folder copies ("for CapCut"). Copies TakeTray no longer knows (after a reinstall or import) are deleted only through Android's consent dialog.
- R8. Removing or moving a clip out of an editing reel deletes its copy first (nothing is removed if the copy cannot be deleted). Undo brings the clip back under "New since you started editing", not into the folder. Deleting a reel deletes its copies first; Undo restores the reel without its editing session. Names: "Instagram Edits" in the sheet, snacks and dialogs; "Edits" in the card pill, banner and section button.

## Global Constraints

- **Schema v2**, the first change: `AppDatabase.schemaVersion = 2`, migration through `dart run drift_dev make-migrations` (`stepByStep`), generated step tests and a hand-filled data test. A newer database (a downgrade) is still refused and left untouched. The later.md "Before the first schema change (v2)" item is done in Task 3. Export format stays v1: editing sessions are never exported (spec §8.6).
- No new Gradle or pub dependency. Pigeon regenerated with the repo's existing command; two new Pigeon files (`editors_api.dart`, `copy_api.dart`).
- **Release permissions unchanged.** No `Service`, no foreground service, no copy notification. `tool/check_release_permissions` keeps its permission lists exactly (`FOREGROUND_SERVICE` and `WAKE_LOCK` stay forbidden; Task 4 only adds two debug-dex strings) and must end `RELEASE PERMISSIONS OK`. The screen stays on through the window flag `FLAG_KEEP_SCREEN_ON`, which needs no permission. Writing to `Movies/TakeTray/` needs no permission on API 30+ (scoped storage, app-owned rows).
- **Originals are never modified, moved or deleted** (D-04). Originals are opened read-only. Every delete goes through `CopyFolder`'s guard (Task 4): a row is deleted only when its `RELATIVE_PATH` is `Movies/TakeTray/<folder>/`, its `DISPLAY_NAME` is the recorded file name and it is owned by TakeTray; anything else is refused and never deleted. The only other deletes are the copy engine's (Task 5): a row it created itself in this job (a cancel, a failed file), and `deletePendingIn`, which deletes only TakeTray-owned `IS_PENDING` rows in exactly `Movies/TakeTray/<folder>/`. Orphans (not owned, or not recorded) go only through `MediaStore.createDeleteRequest`, after the user's consent.
- **Native never writes the database** (D-18, D-103). Dart records each copy as its "file finished" event arrives, and before a job starts saves its plan (job id, reel, folder, each clip's file name) as a phone-state row (D-71, never exported). After a restart, TakeTray's own finished rows in the folder, matched to that plan by file name, are the record; there is no journal file.
- Package names live in Dart (`EditorApp.packageName`): CapCut `com.lemon.lvoverseas`, Edits `com.instagram.basel`, VN `com.frontrow.vlog`, each in the manifest's `<queries>` as `<package>`. A missing editor greys out; **Other app…** always works (spec §11).
- Logs (D-10): never video names, file names, folder or reel names, paths, URIs or the phone maker. Ids, counts, bytes, the editor enum name and error types only.
- Notifications: only the copies reminder, on the Reminders channel, once per copy batch, private on the lock screen (D-101). Native copy in `strings.xml`. Copying has no notification.
- Strict TDD: write **all** of a change's edge-case tests red first, see them fail, then implement once. Never steer one case per fix round. Mutation-check the key lines, one mutant at a time, naming the test that fails; a surviving mutant gets a test in the same task. Never weaken a test to pass.
- Models: implementers of the heavy **Tasks 3, 4, 5, 6 and 11** on **Opus**; implementers of Tasks 2, 7, 8, 9, 10, 12, 13 and 14, on-phone testing, all fixes and every task review and re-review on **Sonnet**. Only the whole-phase final review and its re-review on **Opus** (re-reviews resume the same reviewer). Never Haiku. Always pass the model explicitly. A fixer reviews its own fix in per-task rounds; the final fix wave gets a separate re-review.
- Review findings: Critical and Important fixed now; Minors parked for one batch before the final review. A step review may be skipped only where no code, phone safety or privacy is touched.
- **Parallel worktrees:** after Task 2, Tasks 3, 4, 5 and 8 may run in parallel (Task 8 can also start beside Task 2). Task 7 may run beside Task 6. Task 13 (it reuses Task 11's Done editing dialog) may run beside the gate and Task 12. Tasks 9, 10 and 11 run in order. Expected merge conflicts (resolved by the controller, both sides kept): `MainActivity.kt`, `DebugEditorHooks.kt`, `app_en.arb`, `routes.dart`, `docs/*`. Each task keeps its own D-number below, so parallel tasks never clash.
- Docs every task: its D-number in `docs/decisions.md`, `docs/flow.md`, its section of `docs/learn/phase-8-editor-handoff.md`, and `docs/later.md` (delete what is done).
- UI: design tokens only (`TtMetrics` and friends; `tool/check_styles`), l10n for every string, 48 dp targets, semantics labels, text scaling to 200 %, light and dark, reduced motion. Copy comes from the prototype verbatim where it exists; new copy is given in each task.
- Phone rules: only `app.taketray.dev` runs tests. Never uninstall or clear `app.taketray`. Logcat with `--pid=` only. No screenshots. Never list shared storage or read other apps' files. Patrol videos only in `Movies/TakeTray Test/`; Patrol's copy folders are named `TakeTray Test <timestamp>` reels and deleted in the tear-down. Tests never start CapCut, Edits, VN, the Play Store or the share sheet: a debug-only hook records the outgoing intent instead (Task 4). After every Patrol run: build debug, `install -r`, `pm clear app.taketray.dev`.
- **Patrol first, phone later:** Task 14 writes every flow with no device (`analyze`, offline `flutter build apk --debug --target=patrol_test/...`, Sonnet review) before the owner is asked for the S24. Short phone runs: each Patrol file once per round; no test waits on Android's scheduler.
- Git: work on `phase-8-editor-handoff` (stacked on `phase-7-add-videos`; merge 7 in if it changes). Push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push. Never change git config. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The PR targets `main` after Phase 7 lands; merging needs the owner's go.

## Review Focus

1. **Android stops TakeTray mid-copy** (the user left the app and the system reclaimed it, a swipe from recents, a force stop, a crash), or the activity is re-created while the copy goes on. At the next start no pending file is left, every finished copy is recorded, none twice, the session never stays stuck with no copies, and Try again copies only the rest; the screen-on flag never stays set after the copy screen is gone. (Tasks 5, 6, 10.)
2. **A delete can only hit TakeTray's own copy**, even with a wrong id from Dart, a MediaStore id reused after a media rebuild, or a copy row left from before an import: the guard checks folder, name and owner. (Tasks 4, 6.)
3. **Two actions on one reel at once:** Done editing, delete reel, or remove a clip while that reel's copy job runs; Cancel racing the last file; a double tap on Copy, Continue, an editor row or Done editing. One outcome, no lost or orphaned file. (Tasks 5, 6, 9, 11.)
4. **The clips change under the flow:** an original deleted or gone missing between selection and send or copy, a picked clip's grant lost, the reel renamed (the folder stays) or deleted while its screens are open. A calm message, never a wrong file. (Tasks 6, 9, 10.)
5. **Storage limits and big batches:** just enough space, space running out mid-file, 200 clips / 20 GB, several clips in one second, the repeated hour at a DST change, an SD-card original copied to phone storage. (Tasks 2, 5.)

---

### Task 1: Scope and docs (controller, no review)

**Files:** `docs/decisions.md` (D-118), `docs/later.md`, `docs/learn/phase-8-editor-handoff.md` (stub with Phase 7's section shape: "How to read this guide", Contents, sections 2 to 14 as headings).

- [ ] **Step 1:** D-118 records the owner decisions 1 to 9 and rulings R1 to R8 above, the D-number of each task (Task 2 D-119 … Task 14 D-131), and the gate before Task 12.
- [ ] **Step 2:** `docs/later.md`: add to Phase 10: "VN copies reminder switch" (the Settings row and its setting; `BackgroundSync` writes reminders always until then); "Import and editing sessions" (an import deletes the session rows, so the copies become orphans on the storage screen; warn before import or delete copies first); "Storage used by VN copies" moves into the full Settings screen. Add to "After v1 (only if users ask for it)": "Copy in the background with a foreground service so the user can leave the app (needs FOREGROUND_SERVICE + a typed permission, a Play declaration, and a WAKE_LOCK decision for screen-off)".
- [ ] **Step 3:** Commit `docs: Phase 8 scope and rulings`.

---

### Task 2: Editing rules

**Model:** Sonnet. **Files:**
- Create: `lib/domain/models/editor_app.dart`, `lib/domain/models/clip_ref.dart`, `lib/domain/rules/edit_folder_name.dart`, `copy_file_names.dart`, `space_check.dart`, `byte_size.dart`, `edit_split.dart`.
- Test: the matching files under `test/domain/rules/`, `test/domain/models/editor_app_test.dart` and `clip_ref_test.dart`.

**Interfaces (produces):**
```dart
// How the native side finds a clip's video (Tasks 4 and 5 both use it).
class ClipRef { String? volumeName; int? mediaStoreId; String? pickerUri; String mimeType;
  factory ClipRef.of(Clip clip); }
enum EditorApp { capcut, edits, vn }               // stored by name (Task 3)
extension EditorAppFacts on EditorApp {
  String get packageName;      // com.lemon.lvoverseas / com.instagram.basel / com.frontrow.vlog
  bool get takesShares;        // capcut, edits: true; vn: false
}
String safeFolderName(String reelName);
String copyExtension(String displayName, String mimeType);
class CopyNameSource { int clipId; DateTime localShotAt; String extension; }
Map<int, String> copyFileNames(List<CopyNameSource> inShootingOrder, Set<String> taken);
const int copyReserveBytes = 500 * 1000 * 1000;
class SpaceCheck { bool enough; int freeAfterBytes; int shortByBytes; }
SpaceCheck spaceCheck({required int needBytes, required int freeBytes});
enum ByteUnit { mb, gb }
class ByteSize { ByteUnit unit; String number; }   // "900", "1.2"; the view adds the l10n unit
ByteSize byteSize(int bytes);
class EditSplit<T> { List<T> newClips; List<T> inEdit; }
EditSplit<T> splitForEditing<T>(List<T> clips, int Function(T) idOf,
    {required Set<int> sentIds, required Set<int> liveCopyIds});
enum AddPick { fresh, sentNotCopied, inFolder }
Map<int, AddPick> addPicks(List<int> liveClipIds,
    {required Set<int> sentIds, required Set<int> liveCopyIds});
```

- [ ] **Step 1: Write the failing tests:**
  - `safeFolderName`: each of `/ \ : * ? " < > |` becomes `-` ("London/Paris" → "London-Paris"); C0 controls and U+007F are removed; runs of spaces become one; spaces and dots trimmed at both ends ("Goa." → "Goa", "  Goa  " → "Goa"); empty, ".", ".." and "..." become "Reel"; emoji and accents kept ("Goa 🌴", "Café"); a 40-character name stays whole; never longer than its input.
  - `copyExtension`: lower-cased extension of the display name when it is one of `mp4 mov m4v 3gp mkv webm` (`IMG_1.MOV` → `mov`); otherwise by MIME (`video/mp4` mp4, `video/quicktime` mov, `video/3gpp` 3gp, `video/x-matroska` mkv, `video/webm` webm); otherwise `mp4`; a name with no dot or a trailing dot falls back to MIME.
  - `copyFileNames`: `2026-10-12_14-32-05.mp4` with zero padding (`2026-01-02_03-04-05`); two clips in one second → second gets `_2`, a third `_3`, in the order given; a `taken` name blocks it case-insensitively (`…05.MP4`); `taken` holding `…05.mp4` and `…05_2.mp4` gives `_3`; the same stem with different extensions does not clash; the repeated hour at a DST change gives `_2`, never an overwrite; keys are the clip ids; an empty list gives `{}`.
  - `spaceCheck`: enough exactly at `need + reserve == free`; one byte more is short with `shortByBytes == 1`; `freeAfterBytes = free - need`; `need == 0` is enough; a free below the reserve is short even for a tiny need.
  - `byteSize` (decimal, as `fmt.size`): 0 → "0" MB; any non-zero below 1 MB (499,999) → "1" MB; 900,000,000 → "900" MB; 999,499,999 → "999" MB; 1,000,000,000 → "1" GB (".0" dropped); 1,250,000,000 → "1.3" GB (half up); 12,000,000,000 → "12" GB.
  - `splitForEditing`: nothing sent or copied → all new; a sent clip and a clip with a live copy are in the edit; a copied clip whose copy is gone (not in `liveCopyIds`) and not sent → new; order kept in both lists; ids in the sets that are not in the list are ignored.
  - `addPicks`: fresh (neither), sentNotCopied, inFolder (a live copy wins over sent).
  - `EditorApp`: the three package names exactly; `takesShares` false only for VN; `EditorApp.values.byName` round-trips.
  - `ClipRef.of`: a MediaStore clip gives volume and id (no URI); a picked clip gives its URI only, also when its `volumeName` is set (D-57's rule); the MIME type is the clip's.
- [ ] **Step 2:** Run `cd app && ../tool/flutter test test/domain/`. Expected: FAIL (files do not exist).
- [ ] **Step 3:** Implement. Grapheme-safe trimming with `characters`.
- [ ] **Step 4:** Run them and `tool/check`. Expected: PASS. Mutation-check: the `-` replacement set (drop `:`), the `_2` start number, `<=` in `spaceCheck`, the half-up rounding.
- [ ] **Step 5:** Docs: D-119 (the folder name rule, R2's names and extensions, R3's reserve and units, the split and pick states); `flow.md`; guide section 2. Commit `feat(editors): rules for folders, copy names, space and the edit split`.

---

### Task 3: Schema v2 and the editing sessions repository (heavy)

**Model:** Opus. **Files:**
- Modify: `lib/data/database/tables.dart`, `app_database.dart`, `lib/domain/models/undo_record.dart`, `lib/data/repositories/reels_repository.dart` (delete record), `lib/data/repositories/undo_writer.dart`, `lib/data/backup/backup_service.dart` (clears ten tables), `tool/check_generated`, `tool/test/check_generated_test.dart`.
- Rename: `lib/domain/models/vn_session.dart` → `edit_session.dart`, `vn_copy.dart` → `edit_copy.dart`, `lib/data/repositories/vn_repository.dart` → `edit_sessions_repository.dart` (and their tests). SQL table names stay `vn_sessions` and `vn_copies` (spec §8.1; no table rename in the migration).
- Create: `lib/domain/models/sent_clip.dart`, generated `drift_schemas/taketray/drift_schema_v2.json`, `lib/data/database/app_database.steps.dart`, `test/drift/taketray/generated/schema_v2.dart`, `test/drift/taketray/migration_test.dart` (generated, then filled).
- Test: `test/data/repositories/edit_sessions_repository_test.dart`, extend `test/data/repositories/reels_repository_test.dart`, `test/data/backup/backup_service_test.dart`, `test/drift/taketray/schema_test.dart`.

**Interfaces (consumes):** `EditorApp` (Task 2), `uniqueFolderName`. **Produces:**
```dart
// tables.dart: Dart classes renamed, SQL names kept.
class EditSessions extends Table { tableName 'vn_sessions'; reelId PK FK reels cascade;
  TextColumn editor = textEnum<EditorApp>().withDefault(const Constant('vn'))(); folderName; createdAt; }
class EditCopies extends Table { tableName 'vn_copies'; reelId FK cascade; clipId (no FK, D-54);
  copyMediaStoreId; fileName; sizeBytes; IntColumn copiedAt (UTC ms, NOT NULL DEFAULT 0); }
class SentClips extends Table { tableName 'sent_clips'; reelId FK edit_sessions cascade; clipId (no FK);
  sentAt; PK (reelId, clipId); index sent_clips_clip_id; }

class EditSession { int reelId; EditorApp editor; String folderName; DateTime createdAt; }
class EditCopy { int reelId; int clipId; int copyMediaStoreId; String fileName; int sizeBytes; DateTime copiedAt; }
class SentClip { int reelId; int clipId; DateTime sentAt; }
class EditState { EditSession session; List<EditCopy> copies; Set<int> sentIds; }
class EditSessionSummary { int reelId; String reelName; EditorApp editor; String folderName;
  DateTime createdAt; int copyCount; int copyBytes; DateTime? lastCopiedAt; }

class EditSessionsRepository {
  Future<EditSession> startSession(int reelId, EditorApp editor, String baseFolderName,
      {Iterable<String> alsoTaken = const []});
  Future<EditSession?> sessionOf(int reelId);
  Stream<EditState?> watchEditState(int reelId);
  Stream<Map<int, EditorApp>> watchEditors();              // reel id → editor, for cards
  Stream<List<EditSessionSummary>> watchSummaries();       // storage screen, reminder
  Future<void> recordSent(int reelId, Iterable<int> clipIds);
  Future<void> recordCopies(List<EditCopy> copies);
  Future<void> removeCopies(int reelId, Iterable<int> copyMediaStoreIds);
  Future<List<EditCopy>> copiesOf(int reelId);
  Future<void> endSession(int reelId);
}
// DeleteReelUndo: vnSession/vnCopies → editSession/editCopies/sentClips.
```

- [ ] **Step 1: Write the failing repository tests** (in-memory database):
  - `startSession` keeps today's rules (trim, blank throws, `uniqueFolderName` against every session and `alsoTaken`, ignoring case; no reel or a second session throws `StateError`, saving nothing) and stores `editor`.
  - `recordSent`: idempotent (a clip sent twice keeps its first `sentAt`); no session throws `StateError`; the same clip id in two reels is two rows; ids of clips that are gone are kept (no FK).
  - `recordCopies`: all or nothing in one transaction; a row equal to one already stored (same reel, clip and `copyMediaStoreId`) is ignored; the same reel and clip with a **different** copy id throws `StateError` and stores none of the batch; no session throws.
  - `removeCopies` removes only the given copy ids of that reel; unknown ids do nothing.
  - `watchEditState`: null without a session; emits after each send, copy and removal; `sentIds` is a set.
  - `watchSummaries`: only sessions, with `copyCount`, `copyBytes` (sum) and `lastCopiedAt` (max, null with no copies), the reel's current name; newest session first.
  - `endSession` cascades copies and sent rows; deleting the reel does too (foreign keys on).
  - Undo of a reel delete restores the session with its editor, every copy row (also one whose clip cannot come back, D-54) and every sent row.
  - Backup import deletes `sent_clips` rows too; export has no editing data; the v1 fixture still imports to the same summary.
- [ ] **Step 2: Write the failing migration tests.** Bump `schemaVersion` to 2, run `cd app && ../tool/dart run drift_dev make-migrations` (writes the v2 dump, `app_database.steps.dart`, `schema_v2.dart` and `migration_test.dart`), then fill the generated data test:
  - `migration from v1 to v2 does not corrupt data`: v1 rows (a reel, two clips, a session "Goa" created at T, two copies) become v2 rows with `editor = vn`, each copy's `copiedAt = T` (the session's `createdAt`), no sent rows, and every other table unchanged.
  - after the upgrade, deleting the reel still cascades the session, copies and sent rows (`PRAGMA foreign_keys` on);
  - `a version 3 database is refused and left untouched`: opening throws `UnsupportedError` and `user_version` is still 3;
  - `schema_test.dart` passes for v1 and v2 (`validateDropped: true`).
- [ ] **Step 3: Write the failing `check_generated` tests** (`tool/test/check_generated_test.dart`): a stale or missing `lib/**/*.steps.dart` fails; a stale `test/drift/*/generated/schema_v*.dart` fails; a hand-filled `migration_test.dart` and `schema_test.dart` are never deleted or rewritten.
- [ ] **Step 4:** Run `cd app && ../tool/flutter test test/data test/drift` and `cd tool && ../tool/dart test test/check_generated_test.dart`. Expected: FAIL.
- [ ] **Step 5:** Implement. `onUpgrade`: `if (from > to) throw UnsupportedError(...)`, then `stepByStep(from1To2: (m, schema) async { addColumn editor; addColumn copiedAt; customStatement('UPDATE vn_copies SET copied_at = (SELECT created_at FROM vn_sessions s WHERE s.reel_id = vn_copies.reel_id)'); createTable sentClips; createIndex })`, all in Drift's migration transaction. `tool/check_generated` hashes `*.steps.dart` under `lib/`, deletes them and `test/drift/*/generated/` before regenerating, and keeps `drift_schemas/` and the hand-written tests (update its header comment).
- [ ] **Step 6:** Run `tool/check_generated`, `tool/check`. Expected: PASS. Mutation-check: the `from > to` guard, the `copied_at` UPDATE, the "different copy id throws" branch, `sent_clips` in the backup delete list.
- [ ] **Step 7:** Docs: D-120 (v2's columns and table, why the SQL names stay, the downgrade guard, copies and sent rows not exported, the check_generated change); amend D-54 (v2) and D-59 (ten tables); `flow.md` "Database open and migrations"; guide section 3; delete the later.md v2 section. Commit `feat(data): schema v2 for editing sessions, with a tested migration`.

---

### Task 4: The editors bridge and the copy folder guard (heavy)

**Model:** Opus. **Files:**
- Create: `app/pigeons/editors_api.dart`, `android/.../editors/EditorsHostApiImpl.kt`, `EditorApps.kt`, `ShareIntents.kt`, `CopyFolder.kt`, `DeleteRequests.kt`, `ActivityStarter.kt`; `android/app/src/debug/kotlin/app/taketray/DebugEditorHooks.kt`; `lib/platform/editors_bridge.dart`; `test/support/fake_editors_bridge.dart`.
- Modify: `AndroidManifest.xml` (`<queries>` packages), `MainActivity.kt` (set up the API; forward the delete-request result), `src/debug/.../DebugHooks.kt`, `tool/check_release_permissions` (`FORBIDDEN_DEX_STRINGS += DebugEditorHooks test_editors`).
- Test: `android/app/src/test/kotlin/app/taketray/editors/{EditorAppsTest,ShareIntentsTest,CopyFolderTest,DeleteRequestsTest}.kt`, `ManifestTest.kt` (extend), `DebugEditorHooksTest.kt`, `test/platform/editors_bridge_test.dart`, `test/platform/editor_packages_manifest_test.dart`.

**Interfaces (consumes):** `ClipRef`, `EditorApp` (Task 2). **Produces, Dart (Pigeon messages mirror them):**
```dart
class CopyFileRef { int mediaStoreId; String folderName; String fileName; }
class InstalledApp { String packageName; bool installed; Uint8List? iconPng; }
enum SendResult { sent, notInstalled, failed }
class DeleteReport { Set<int> deleted; Set<int> gone; Set<int> refused; Set<int> failed; }
class CopyFolderFile { int mediaStoreId; String folderName; String fileName; int sizeBytes; bool ownedByTakeTray; }

abstract interface class EditorsBridge {
  Future<List<InstalledApp>> apps(List<String> packageNames, {required int iconPx});
  Future<SendResult> sendTo(String packageName, List<ClipRef> clipsInOrder);
  Future<bool> shareWithChooser(List<ClipRef> clipsInOrder, String chooserTitle);
  Future<bool> openApp(String packageName);
  Future<bool> openStoreListing(String packageName);
  Future<int> freeBytes();                                  // primary external volume
  Future<List<String>> copyFolderNames();                   // under Movies/TakeTray/
  Future<Set<int>> existingCopies(List<CopyFileRef> refs);  // throws on failure, never "gone"
  Future<DeleteReport> deleteCopies(List<CopyFileRef> refs);
  Future<List<CopyFolderFile>> filesInCopyFolders();
  Future<bool> requestDelete(List<CopyFileRef> refs);       // system consent; true when allowed and done
}
```

- [ ] **Step 1: Write the failing Robolectric tests:**
  - `EditorApps`: installed or not per package (shadow package manager); an icon is drawn to a PNG of `iconPx`; a package that disappears mid-call is `installed = false`; the call never throws for an unknown package.
  - `ShareIntents.send(pkg, uris)`: one clip → `ACTION_SEND` with `EXTRA_STREAM`; several → `ACTION_SEND_MULTIPLE` with `EXTRA_STREAM` as an `ArrayList<Uri>` **in the given order**; type `video/*`; `setPackage(pkg)`; `FLAG_GRANT_READ_URI_PERMISSION`; `ClipData` holding every URI in the same order; a MediaStore clip's URI is `MediaStore.Video.Media.getContentUri(volume)` + id; a picker clip uses its picker URI. `ActivityNotFoundException` → `notInstalled`; `SecurityException` and others → `failed`.
  - `ShareIntents.chooser(uris, title)`: `Intent.createChooser` around the same send intent, grants on both; no app → false.
  - `openApp`: the launch intent of the package, false when none; `openStoreListing`: `market://details?id=<pkg>` only (no web URL), false when nothing handles it.
  - `CopyFolder` guard (fake `ContentResolver` provider): `deleteCopies` deletes a row only when `RELATIVE_PATH` equals `Movies/TakeTray/<folder>/` (case-insensitive), `DISPLAY_NAME` equals the file name and `OWNER_PACKAGE_NAME` is TakeTray's package; a row in `Movies/TakeTray Test/`, in `DCIM/Camera/`, in a deeper folder, with another name or another owner is **refused** and untouched; an id with no row is `gone`; a delete that throws is `failed` and the rest continue. `existingCopies` uses the same match (a reused id with another name is not present); a failing query throws.
  - `copyFolderNames`: distinct first segments under `Movies/TakeTray/`, never `TakeTray Test`; `filesInCopyFolders`: one level deep only, with size and `ownedByTakeTray`.
  - `freeBytes`: `StatFs(Environment.getExternalStorageDirectory()).availableBytes`.
  - `DeleteRequests`: `createDeleteRequest` only for rows that pass the folder match (any owner); refused rows are never in the request; a result arriving with no caller is dropped; a second request while one is open fails with `busy`.
  - `DebugEditorHooks` (debug only, channel `app.taketray/test_editors`): `setInstalledOverride(Map<String,bool>?)`, `recordIntents(bool)`, `takeRecordedIntents()` returns each intent's action, package, type, the URIs as `volume:id` or `picker`, the grant flag and the `ClipData` count; while recording, no activity starts (`ActivityStarter` is replaced).
  - `ManifestTest`: the three `<package>` queries are present.
- [ ] **Step 2: Write the failing Dart tests:** the bridge maps messages to domain types and passes `PlatformException` through unchanged; `editor_packages_manifest_test.dart` reads `android/app/src/main/AndroidManifest.xml` and finds every `EditorApp.packageName` in `<queries>`.
- [ ] **Step 3:** Run `tool/test_android` and the Dart tests. Expected: FAIL.
- [ ] **Step 4:** Add the Pigeon file, regenerate, implement. All binder work off the main thread. The fake bridge records calls and has settable `installed`, `freeBytes`, `existing`, `deleteReport` and a `sendResult`.
- [ ] **Step 5:** Run `tool/test_android`, `tool/check`, `tool/check_release_permissions`. Expected: PASS. Mutation-check (each alone): the order of `EXTRA_STREAM`, the owner check, the name check, `RELATIVE_PATH` equality (make it a prefix match: the `TakeTray Test` and deeper-folder tests must fail), the `busy` guard.
- [ ] **Step 6:** Docs: D-121 (two Pigeon files instead of one `EditorsApi`, so Tasks 4 and 5 can run in parallel; the guard; `market://` only; the debug intent recorder); `flow.md`; guide section 4. Commit `feat(editors): editors bridge with a guarded copy folder`.

---

### Task 5: Copying in the app (heavy)

**Model:** Opus (it writes into shared storage and deletes files; a mistake can leave half files or delete a copy the user still needs). **Files:**
- Create: `app/pigeons/copy_api.dart`, `android/.../editors/CopyEngine.kt` (a process-wide object owning at most one job), `CopyJob.kt` (the loop), `CopyStore.kt` (interface + MediaStore implementation), `CopyHostApiImpl.kt`; `lib/platform/copy_bridge.dart`; `test/support/fake_copy_bridge.dart`.
- Modify: `MainActivity.kt` (set up the API; give it the activity's window for the screen-on flag), `src/debug/.../DebugEditorHooks.kt` (`setCopyThrottleMs(int)`, `keepScreenOnFlag()` reading the window flag).
- Test: `android/app/src/test/kotlin/app/taketray/editors/{CopyJobTest,CopyEngineTest,CopyStoreTest,KeepScreenOnTest}.kt`, `ManifestTest.kt` (extend), `test/platform/copy_bridge_test.dart`.
- No manifest change, no `Service`, no notification, no permission: `tool/check_release_permissions` is not touched.

**Interfaces (consumes):** `ClipRef` (Task 2). **Produces, Dart:**
```dart
class CopyItem { int clipId; ClipRef source; String fileName; int sizeBytes; }
class CopyRequest { String jobId; int reelId; String folderName; List<CopyItem> items; }
enum CopyState { running, finished, spaceFull, interrupted, cancelled }
class CopiedFile { int clipId; int copyMediaStoreId; String fileName; int sizeBytes; DateTime copiedAt; }
class CopyJob { String jobId; int reelId; String folderName; CopyState state; int total; int done;
  int bytesDone; int bytesTotal; List<CopiedFile> copied; List<int> failedClipIds;
  List<CopiedFile> undeleted; }  // after a cancel: copies it could not delete
class CopyBusy implements Exception {}
class FolderRow { int mediaStoreId; String fileName; int sizeBytes; bool pending; }
abstract interface class CopyBridge {
  Future<void> start(CopyRequest request);  // CopyBusy while a job runs or its result waits
  Future<CopyJob?> current();               // this process's running job or waiting result; null after a restart
  Future<CopyJob> cancel(String jobId);     // stops; deletes this job's copies
  Future<void> resume(String jobId);        // after spaceFull: the remaining items of this job
  Future<void> clear(String jobId);         // forget the result; another id does nothing
  Future<List<FolderRow>> ownRowsIn(String folderName);   // TakeTray-owned rows in Movies/TakeTray/<folder>/, pending ones included
  Future<int> deletePendingIn(String folderName);          // deletes only TakeTray-owned IS_PENDING rows there
  Future<void> keepScreenOn(bool on);       // FLAG_KEEP_SCREEN_ON on the activity's window
  Stream<CopyJob> get changes;
}
```

The job lives in `CopyEngine`, not in the activity: it goes on while the process lives, also when the user leaves the app or the activity is re-created, and the next engine reads it with `current()`. Events are dropped while no Dart side is attached. If Android stops the process, the job is gone; Task 6 recovers from the folder (`ownRowsIn`, `deletePendingIn`) and the plan Dart saved before starting. No journal file: TakeTray's own finished rows in the folder are the record.

The loop, per item in order (the part the tests do not fully determine):
```
check space: availableBytes >= item.sizeBytes + 50 MB, else state = spaceFull, stop
insert pending row (RELATIVE_PATH Movies/TakeTray/<folder>/, DISPLAY_NAME, IS_PENDING 1)
open source "r"; open target "w"; copy in 1 MiB chunks, checking the cancel flag per chunk
source unreadable / bytes written != source length → delete the row, item failed, continue
ENOSPC → delete the row, state = spaceFull, stop
update IS_PENDING 0; read back _ID and DISPLAY_NAME → item done (CopiedFile), event
```

- [ ] **Step 1: Write the failing Robolectric tests** (fake `CopyStore` and sources):
  - happy path: every item copied in order, names read back (a MediaStore rename "x (1).mp4" is what is reported), `copied` in item order, state `finished`, one event per finished file plus progress events with `done` and `bytesDone` rising;
  - a source that cannot be opened (also a picked clip whose grant is gone), or is shorter than reported, is in `failedClipIds`, its pending row deleted, and the job goes on;
  - space: the pre-check stops before the file (no row made); `ENOSPC` mid-file deletes that pending row; both give `spaceFull` with the earlier copies kept; `resume` continues with the remaining items only and fails again at once when space is still short;
  - cancel mid-file: the pending row and every copy of **this job** are deleted, earlier jobs' files untouched, state `cancelled`, `copied` lists what was deleted; a copy that cannot be deleted is in `undeleted`;
  - cancel after `finished` but before `clear`: deletes this job's copies (Stop always means "delete the copies made so far");
  - cancel, resume or clear with an unknown id: nothing changes;
  - `start` while running or while a result waits → `busy`, nothing changes;
  - the engine outlives the activity: a job started, the host API torn down (`onHostGone`) and set up again; the job is still running, `current()` returns it, and events reach the new listener only;
  - `ownRowsIn` lists only TakeTray-owned rows in exactly `Movies/TakeTray/<folder>/`, pending ones included (`QUERY_ARG_MATCH_PENDING`); never `Movies/TakeTray Test/`, a deeper folder or another owner's row;
  - `deletePendingIn` deletes only owned rows with `IS_PENDING = 1` in that folder; a finished row, another folder's pending row and another owner's row stay;
  - `keepScreenOn(true)` sets `FLAG_KEEP_SCREEN_ON` on the window, `false` clears it, both on the main thread; with no activity it does nothing and does not throw;
  - the debug throttle sleeps per chunk only in debug builds;
  - an original on another volume (an SD card) is copied to the primary volume, and the space check reads the primary volume;
  - a 200-item job: progress events are throttled (at most one per 250 ms during a file) and every finished file still gets its event;
  - `ManifestTest`: still no `<service>` and no foreground-service permission.
- [ ] **Step 2:** Write the failing Dart bridge tests (mapping, the `busy` error, the event stream).
- [ ] **Step 3:** Run `tool/test_android` and the Dart tests. Expected: FAIL.
- [ ] **Step 4:** Implement. One worker coroutine on `Dispatchers.IO` in `CopyEngine`; cancel sets a flag the loop reads; file deletes after a cancel run on the same worker, after the loop ends, so they never race the file being written. `CopyFlutterApi.onCopyChanged` is called on the main thread, at most every 250 ms during a file, and always when a file finishes or the state changes.
- [ ] **Step 5:** Run `tool/test_android`, `tool/check`, `tool/check_release_permissions` (unchanged; must end `RELEASE PERMISSIONS OK`). Mutation-check (each alone): publish (`IS_PENDING 0`) before the length check; skip deleting the pending row on cancel; `resume` restarting from item 0; `deletePendingIn` without the pending filter; the space margin.
- [ ] **Step 6:** Docs: D-122 (copying in the app process with no foreground service, owner's change of 2026-11-12; the engine outliving the activity; the folder as the record after a restart; the loop; the screen-on flag; R4); `flow.md` a new "Copying clips" flow; guide section 5. Commit `feat(editors): copying in the app, with progress, cancel and the screen kept on`.

---

### Task 6: `EditSessionService` (heavy)

**Model:** Opus. **Files:**
- Create: `lib/data/editors/edit_session_service.dart`, `lib/features/editors/view_models/copy_job_controller.dart`.
- Modify: `lib/features/reels/view_models/reel_clip_actions.dart`, `reel_actions.dart`, `reel_detail_controller.dart` (`removeMissing`), `lib/app/media_lifecycle.dart` (start and resume), `lib/data/repositories/phone_state_repository.dart` (the `copyJobPlan` key).
- Test: `test/data/editors/edit_session_service_test.dart`, `test/features/editors/copy_job_controller_test.dart`, extend the reels view-model tests.

**Interfaces (consumes):** Tasks 2 to 5. **Produces:**
```dart
class EditorChoice { EditorApp editor; bool installed; Uint8List? icon; }
class SendOutcome { SendResult result; int sentCount; }
class CopyPlan { int reelId; EditorApp editor; List<int> clipIds; int needBytes; int freeBytes;
  SpaceCheck space; String folderName; bool startsSession; }
class DoneEditingResult { EditorApp editor; int freedBytes; }
class OrphanFolder { String folderName; int fileCount; int bytes; List<CopyFileRef> files; }
class StorageOverview { List<EditSessionSummary> sessions; List<OrphanFolder> orphans; }
class CopiesNotDeleted implements Exception { int count; }
// Phone state (D-71), never exported; one at a time (R4).
class CopyJobPlan { String jobId; int reelId; String folderName; bool startedSession;
  List<({int clipId, String fileName, int sizeBytes})> items; }

class EditSessionService {
  Future<List<EditorChoice>> editorChoices();
  Future<SendOutcome> sendOriginals(int reelId, EditorApp editor, List<int> clipIds); // capcut/edits only
  Future<bool> share(List<int> clipIds, String chooserTitle);
  Future<CopyPlan> planCopy(int reelId, EditorApp editor, List<int> clipIds);
  Future<String> startCopy(CopyPlan plan);              // returns the job id
  Future<void> cancelCopy(String jobId);
  Future<void> resumeCopy(String jobId);                // the in-process job, or a new job for the plan's items not yet recorded
  Future<void> applyJob(CopyJob job);                   // records the copies made; idempotent; called on every finished-file event
  Future<void> finishJob(String jobId);                 // apply, then clear
  Future<DoneEditingResult> doneEditing(int reelId);
  Future<void> verifyCopies(int reelId);
  Future<void> beforeClipsLeaveReel(int reelId, Set<int> clipIds);
  Future<void> beforeReelDelete(int reelId);
  Future<StorageOverview> storage();
  Future<int> deleteOrphans(OrphanFolder folder);       // freed bytes; 0 when declined
  Future<void> recoverAtStart();                        // returns the interrupted job (from the plan) or null
}
@Riverpod(keepAlive: true) class CopyJobController { CopyJob? build(); bool takeUnseenResult(); }
// After a restart the controller holds an `interrupted` CopyJob built from the plan and the folder.
```

Every mutating method runs on the service's own serial queue, so two of them never interleave.

- [ ] **Step 1: Write the failing service tests** (in-memory database, fake bridges, fake clock):
  - `sendOriginals`: clips sent in shooting order (`inShootingOrder`), missing clips left out and not counted, gone ids dropped; the session (editor, reserved folder name from `safeFolderName` + `copyFolderNames`) and sent rows are written **before** the share; `notInstalled` or `failed` rolls both back; zero live clips sends nothing and returns `failed` with `sentCount 0`; VN or a reel that already has a session throws `StateError`; a double call sends once (single-flight per reel).
  - `share`: live clips only, in shooting order, no session; all missing → false without a bridge call.
  - `planCopy`: drops clips with a live copy in this reel's folder and missing clips; `needBytes` is the sum of `sizeBytes`; `startsSession` true for a reel with no session (VN only); an existing session of another editor than asked throws `StateError`; the folder name is the session's (a renamed reel keeps it).
  - `startCopy`: starts the session first when `startsSession`; items in shooting order; names from `copyFileNames` (local shot times from `ClipTimeService.localTimes`, D-83; a clip with no time yet uses the phone's zone) with `taken` = the session's copy names plus the folder's current file names; the plan is saved (`copyJobPlan`) **before** `start`; `CopyBusy` or any other start failure ends a session it just started, removes the plan and rethrows; a double call starts one job.
  - `applyJob`: called for each finished-file event and for the result; records each `CopiedFile` once (a second apply of the same job adds nothing); a copy whose clip has **left the reel** or whose session is gone is deleted through `deleteCopies` and not recorded; `undeleted` files stay recorded; a cancelled job removes its deleted copies' rows.
  - `cancelCopy` of a job that started its session: when the session ends with no copies and no sent rows, it is ended.
  - `doneEditing`: deletes every copy (`deleteCopies`), then ends the session; `gone` counts as deleted; any `refused` or `failed` → `CopiesNotDeleted`, the session and the failed rows stay, the deleted rows go; refuses with `StateError` while a job for this reel runs; `freedBytes` sums deleted copies; works with no copies (CapCut).
  - `verifyCopies`: rows whose file is gone (`existingCopies`) are removed; a throwing bridge changes nothing.
  - `beforeClipsLeaveReel`: deletes those clips' copies and rows first; a failure throws `CopiesNotDeleted` and removes nothing; a reel with no session does nothing; sent rows are kept.
  - `beforeReelDelete`: cancels this reel's running job, deletes every copy, ends the session; any failure throws and nothing is ended.
  - `storage`: sessions from `watchSummaries` (first value); orphans = files in copy folders whose id is not a recorded copy, grouped by folder, with counts and bytes; a bridge failure gives sessions with no orphans (logged).
  - `deleteOrphans`: `requestDelete` with that folder's files; declined → 0.
  - `recoverAtStart` with an in-process job (`current()` not null; the activity was re-created): applies it, nothing deleted.
  - `recoverAtStart` after a restart (`current()` null, a plan saved): `deletePendingIn(folder)` first; then `ownRowsIn(folder)` finished rows whose file name is a plan item's are recorded for that item's clip (an already recorded copy id is not added twice); a finished row matching no plan item is left for the storage screen (an orphan), never deleted; the result is an `interrupted` job listing the recorded items; no plan → nothing to recover.
  - after recovery, `resumeCopy` starts a new job with only the plan items not yet recorded, keeping their file names; when all were recorded it finishes at once; `cancelCopy` of the recovered job deletes the copies it recorded (guarded `deleteCopies`) and their rows;
  - the plan is removed only after `finishJob`, `cancelCopy` or a failed start; a crash between recording and removing the plan leaves nothing recorded twice;
  - `recoverAtStart` also ends sessions with no copies, no sent rows and no plan; a throwing bridge is logged and changes nothing (the plan stays for the next start).
- [ ] **Step 2: Write the failing controller and hook tests:**
  - `CopyJobController` follows `changes` (calling `applyJob` for each event with a new finished file), reads `current()` on build and on resume, holds the interrupted job `recoverAtStart` returned, and `takeUnseenResult()` is true once per job id per process for a non-running job;
  - `ReelClipActions.removeFromReel` and `moveToReel` call `beforeClipsLeaveReel(from, ids)` first and remove nothing when it throws; `ReelDetailController.removeMissing` too; `ReelActions.confirmDelete` calls `beforeReelDelete` first and deletes nothing when it throws; the Undo of such a delete restores the reel with no session;
  - `media_lifecycle` runs `recoverAtStart` once per start, guarded, after the scan step.
- [ ] **Step 3:** Run the tests. Expected: FAIL.
- [ ] **Step 4:** Implement. Job ids are `'<reelId>-<UTC ms>'`. Never log names or paths.
- [ ] **Step 5:** Run `tool/check`. Expected: PASS, coverage ≥ 80 % for the service. Mutation-check (each alone): write-before-share order, the rollback, the plan saved after `start` instead of before, recovery without `deletePendingIn`, recovery matching by size instead of file name, "clip left the reel" in `applyJob`, `doneEditing` ending the session after a failed delete, `beforeClipsLeaveReel` swallowing the error.
- [ ] **Step 6:** Docs: D-123 (the service's queue, R1, R5, R8, the plan row, record-per-file then clear, recovery from the folder after a restart, what each failure leaves); amend D-56 and D-85's delete; `flow.md` "Editing a reel"; guide section 6. Commit `feat(editors): editing sessions, copies and their clean-up`.

---

### Task 7: The copies reminder and the Done editing tap

**Model:** Sonnet. **Files:**
- Modify: `app/pigeons/background_api.dart`, `android/.../background/{BackgroundState,BackgroundStateStore,Arming,ReminderScheduler,ReminderTimes,ReminderReceiver,Notifier,LaunchActions}.kt`, `res/values/strings.xml`, `src/debug/.../DebugBackgroundHooks.kt` (`showCopiesReminderNow(reelId)`), `lib/data/background/background_sync.dart`, `lib/platform/background_bridge.dart`, `lib/features/notifications/view_models/launch_actions.dart`, `lib/app.dart`, `lib/router/routes.dart`.
- Test: the matching Kotlin tests (`ReminderSchedulerTest`, `ReminderTimesTest`, `ReminderReceiverTest`, `NotifierTest`, `LaunchActionsTest`, `BackgroundStateStoreTest`), `test/data/background/background_sync_test.dart`, `test/features/notifications/launch_actions_test.dart`.

**Interfaces (produces):**
```dart
class CopiesReminderMsg { int reelId; String reelName; int copyBytes; int lastCopiedAtMs; }
// BackgroundStateMsg gains: List<CopiesReminderMsg> copiesReminders;
enum LaunchActionMsg { toTag, reels, doneEditing }
class LaunchMsg { LaunchActionMsg action; int? reelId; }   // takeLaunchAction / onLaunchAction use it
// routes.dart
static const reelDoneParameter = 'done';
static String reelDoneEditing(int id) => '${reel(id)}?done=1';
```

- [ ] **Step 1: Write the failing tests:**
  - `BackgroundSync` writes one `CopiesReminderMsg` per session with copies (none for a CapCut session without copies), and writes again when copies change or a session ends;
  - `ReminderTimes.copiesDueAt(lastCopiedAtMs) = lastCopiedAtMs + 3 days`; one inexact alarm for the earliest due reminder not yet shown; a reminder is shown once per `(reelId, lastCopiedAtMs)` (stored), so a new copy batch re-arms it and a reboot does not repeat it; a reel dropped from the mirror cancels its alarm and its notification;
  - the notification on the Reminders channel: title "%1$s copies are using %2$s" (`Formatter.formatShortFileSize`), text "Done editing? Tap to clean up.", action "Done editing"; private lock-screen version "TakeTray" / "Copies for an edit are still on your phone"; both taps launch `doneEditing` with the reel id; one notification per reel (id from the reel id);
  - Dart: `doneEditing` with a reel that still exists opens `Routes.reelDoneEditing(id)` (the reel page; Task 11 makes it show the Done editing dialog once when the reel still has a session); a reel that is gone, an unknown or a null reel id opens Reels.
- [ ] **Step 2:** Run them (`tool/test_android`, Dart tests). Expected: FAIL.
- [ ] **Step 3:** Implement on the Phase 6 patterns (D-105, D-106). The launch action stays an allow-list: the reel id is the only payload.
- [ ] **Step 4:** Run `tool/test_android`, `tool/check`. Expected: PASS. Mutation-check the 3-day constant and the shown-once key.
- [ ] **Step 5:** Docs: D-124 (R6, the payload, the private version); `flow.md` "Notification taps" and "Reminders"; guide section 7. Commit `feat(editors): copies reminder after 3 days, with Done editing`.

---

### Task 8: Design-system pieces for editors

**Model:** Sonnet. **Files:**
- Create in `packages/taketray_ui/lib/src/components/`: `storage_bar.dart`, `bottom_bar.dart`, `illustrated_steps.dart`, `status_layout.dart`, `app_icon.dart`; tokens they need in `TtMetrics`.
- Modify: `app/lib/features/add_videos/views/add_grid_screen.dart` (its bottom bar becomes `TtBottomBar`, goldens unchanged), the package barrel, Widgetbook.
- Test: goldens for each state, light and dark, 1x and 2x text; widget tests; `widgetbook/test/catalog_coverage_test.dart` stays green.

**Interfaces (produces):**
```dart
TtStorageBar.enough({required double needFraction, required String needLabel, required String freeAfterLabel, required String semanticLabel});
TtStorageBar.short({required double haveFraction, required String haveLabel, required String shortLabel, required String semanticLabel});
TtBottomBar({required String title, required String subtitle, required Widget action});
TtIllustratedSteps({required List<TtIllustratedStep> steps});
TtIllustratedStep.newProject({required String number, required String title, required String body});
TtIllustratedStep.folders({..., required List<String> folders, required int highlighted});
TtIllustratedStep.tiles({..., required List<ImageProvider> thumbnails});   // numbered 1..n, up to 6
TtStatusLayout({required IconData icon, required TtStatusTone tone, required String title, Widget? body, required List<Widget> actions});
enum TtStatusTone { primary, error, warning, success }
TtAppIcon({Uint8List? png, required String fallbackLetters});              // 40 dp, the prototype's placeholder when null
```

- [ ] **Step 1: Write the failing widget tests and goldens:** storage bar enough (need share at least 4 % wide, the legend's two items) and short (solid "have", hatched error "short"), each with its `semanticLabel` as one node; bottom bar wraps both lines at 2x and keeps the button 48 dp; steps with the highlighted folder announced; status layout per tone (centred, actions full width); app icon with bytes and with the fallback.
- [ ] **Step 2:** Run `cd packages/taketray_ui && ../../tool/flutter test`. Expected: FAIL.
- [ ] **Step 3:** Implement to `proto.css` (`.storage`, `.bottombar`, `.vsteps`/`.vstep`/`.mock`, the `vn-copy` centred column, `editorIcon`). Add Widgetbook use cases with knobs.
- [ ] **Step 4:** Run the package tests, `tool/check`, macOS goldens, then the CI goldens (`gh workflow run update-goldens.yml --ref <branch>`, `tool/pull_ci_goldens <run>`). Expected: PASS; the add grid's goldens unchanged.
- [ ] **Step 5:** Docs: D-125; guide section 8. Commit `feat(ui): storage bar, bottom bar, illustrated steps, status layout, app icon`.

---

### Task 9: Picking clips, the editor sheet, CapCut/Edits and Share

**Model:** Sonnet. **Files:**
- Create: `lib/features/editors/views/edit_select_screen.dart`, `editor_sheet.dart`, `mark_status_dialog.dart`, `editor_missing_dialog.dart`, `open_share.dart`; `view_models/edit_select_controller.dart`, `editor_choices.dart`.
- Modify: `lib/router/routes.dart`, `app_router.dart`, `lib/features/reels/views/reel_detail_screen.dart` (FAB and ⋮), `clip_viewer_screen.dart` (Share), `lib/l10n/app_en.arb`.
- Test: `test/features/editors/{edit_select_screen_test,editor_sheet_test,mark_status_dialog_test}.dart`, extend the reel page and viewer tests; macOS goldens for the screen and the sheet (light, dark, 1x, 2x).

**Interfaces (consumes):** `EditSessionService.editorChoices`, `sendOriginals`, `share`; `TtBottomBar`, `TtAppIcon`. **Produces:** `Routes.editSelect = '/edit'` (root route, `?reel=<id>`, optional `&clips=<id,id,…>` preselected, `&add=1` for Task 11's add mode), `Routes.editSelectOf(int reelId, {Iterable<int> clipIds = const [], bool add = false})`; the location constants and builders Task 10 registers: `Routes.copySpace = '/edit/space'` with `copySpaceOf(int reelId, EditorApp editor, Iterable<int> clipIds)`, `Routes.copyProgress = '/edit/copying'` with `copyProgressOf(String jobId)`, `Routes.copyReady = '/edit/ready'` with `copyReadyOf(int reelId)`; `showEditorSheet(BuildContext, {required int reelId, required List<int> clipIds}) → Future<void>`; `showMarkStatusDialog(BuildContext, WidgetRef, int reelId, ReelStatus status) → Future<void>`; `showEditorMissingDialog(BuildContext, EditorApp) → Future<void>`.

Copy, verbatim from the prototype: app bar "Pick clips to edit", subtitle the reel's name, **Select all** / **Clear**; info bar "Clips go to your editor in the order you shot them."; bottom bar "No clips picked" / "Tap the clips you want to edit", then "{n} clips · {duration}" / "{size} · in shooting order", button **Continue**; sheet "Edit {n} clips in…" / "{duration} · in shooting order"; rows "CapCut" and "Instagram Edits" "Gets your original clips", "VN" "Makes temporary copies · {size}", "Other app…" "Opens Android's share menu"; "Not installed"; "Editors you don't have are greyed out."; snack "Sent {n} clips to {editor}"; dialog "Mark {name} as Ready to edit?" / "Helps you find it under Ready to edit. You can change this any time." **Not now** / **Mark as Ready to edit**, snack "Marked as Ready to edit"; "{editor} isn't installed" / "Install {editor} from the Play Store, or choose another editor." **Choose another** / **Open Play Store**; FAB "Edit video"; ⋮ items "Edit video", "Select all", "Share"; viewer action "Share". New: chooser title "Share {n} videos" (one: "Share video"); "Couldn't open {editor}. Try again."; "These clips are missing from your phone."

- [ ] **Step 1: Write the failing tests:**
  - FAB shows only with at least one live clip, no selection and **no session** (R1); ⋮ "Edit video" is hidden during a session; ⋮ order Edit video, Select all, Share;
  - the screen lists live clips only, by day, all unticked from the FAB, the selection preselected from ⋮ (missing ones dropped); **Select all** ticks every clip and becomes **Clear**; a clip that goes missing meanwhile leaves the selection; a reel deleted while open pops to Reels;
  - bottom bar counts, duration and size; **Continue** disabled at zero; tapping it opens the sheet with the clips in shooting order;
  - sheet: installed editors tappable, others greyed with "Not installed" and the footnote; all installed → no footnote; a failed `editorChoices` shows all three as installed (the share decides);
  - CapCut: `sendOriginals` once on a double tap; `sent` → back to the reel page, the snack, then after 1.3 s the Ready dialog only when the reel is Collecting; `notInstalled` → the missing dialog (**Open Play Store** calls `openStoreListing`; a false result shows nothing more); `failed` → "Couldn't open CapCut. Try again." and the screen stays;
  - VN → pushes `Routes.copySpaceOf(reelId, EditorApp.vn, clipIds)` (the test router has a stub route there until Task 10 registers the screen); Other app… → `share`, no session, no dialog;
  - viewer Share and ⋮ Share: chooser through `share`; a missing clip's Share is disabled; all chosen missing → "These clips are missing from your phone.".
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. Thumbnails through `ClipThumbnailImage`; `GridView.builder`.
- [ ] **Step 4:** Run `tool/check` and goldens. Expected: PASS. Mutation-check the "no session" FAB rule and the Collecting-only dialog.
- [ ] **Step 5:** Docs: D-126; `flow.md`; guide section 9; delete the later.md Share / Edit video item. Commit `feat(editors): pick clips, choose an editor, send to CapCut or Edits, share`.

---

### Task 10: The VN copy screens

**Model:** Sonnet. **Files:**
- Create: `lib/features/editors/views/copy_space_screen.dart`, `copy_progress_screen.dart`, `copy_ready_screen.dart`, `stop_copy_dialog.dart`; `view_models/copy_space_controller.dart`.
- Modify: `routes.dart`, `app_router.dart`, `lib/app.dart` (open the copy screen for an unseen result on start and resume), `app_en.arb`.
- Test: `test/features/editors/{copy_space_screen_test,copy_progress_screen_test,copy_ready_screen_test}.dart`; macOS goldens for every state.

**Interfaces (consumes):** `planCopy`, `startCopy`, `cancelCopy`, `resumeCopy`, `finishJob`, `CopyJobController`, `CopyBridge.keepScreenOn` (Task 5), Task 8's pieces, and Task 9's `copySpace` / `copyProgress` / `copyReady` locations. **Produces:** the three root routes registered in `app_router.dart`.

Copy, verbatim: "Copy clips for VN"; "These {n} clips need {size}" / "You have {free} free."; legend "Copies: {size}", "Free after copying: {size}"; callouts "Why copies?" "VN needs all the clips in one folder. TakeTray copies them to **Movies/TakeTray/{folder}**. Your original clips stay where they are." and "Copies are temporary" "After you export from VN, tap Done editing and TakeTray deletes them."; **Copy {n} clips** / **Back**; "Not enough space" / "These {n} clips need {size}. You have {free} free."; "You have {free}", "Short by {size}"; "What you can do" "Select fewer clips, or free up space on your phone and try again."; **Select fewer clips** / **Cancel**; "Copying clips for VN" / "{done} of {total} clips" / "{doneSize} of {allSize} · into Movies/TakeTray/{folder}" / **Cancel**; "Stop copying?" / "The {n} copies made so far will be deleted. Your original clips aren't affected." **Keep copying** / **Stop**; snack "Copying stopped. No copies were kept."; "Phone storage is full" / "{done} of {total} clips were copied before space ran out. Free up some space, then try again." **Try again** / **Delete copies and stop**; "1 clip couldn't be copied" / "The clip from {time} may have been deleted or moved. The other {n} clips were copied." **Continue with {n} clips** / **Cancel**; "Ready for VN" / "In VN, tap **New project** and open the **{folder}** folder."; steps "Open VN, tap New project" "It's the big + button.", "Open the {folder} folder" "Inside Movies › TakeTray.", "Select all the clips" "They're already in shooting order."; **Open VN** / **Done**. New: on the copying screen, in place of the prototype's "This takes up to a minute. You can leave the app; copying continues.": "Keep TakeTray open until copying finishes. The screen stays on until then."; the reserve line "TakeTray keeps 500 MB free for your phone."; "{n} clips couldn't be copied" / "They may have been deleted or moved. The other {m} clips were copied."; all failed: "The clips couldn't be copied" / "They may have been deleted or moved." **Back**; interrupted (Android stopped TakeTray mid-copy): "Copying stopped" / "TakeTray was closed before copying finished. {done} of {total} clips were copied." **Try again** / **Delete copies and stop**; "Couldn't start copying. Try again."; add-job cancel snack "Copying stopped. The new copies were deleted."

- [ ] **Step 1: Write the failing tests:**
  - space: enough and short from `planCopy` (the reserve applied, Task 2), the bar's labels and semantics; **Copy** starts once on a double tap and replaces the route with progress; `CopyBusy` or any start failure → "Couldn't start copying. Try again."; **Select fewer clips** pops to the selection;
  - progress follows the controller (`done`, sizes, progress bar semantics); **Cancel** and system back open the Stop dialog; **Keep copying** changes nothing; **Stop** → `cancelCopy`, the reel page and the snack (first job) or the add-job snack;
  - the screen is kept on (`CopyBridge.keepScreenOn(true)`) when progress shows a running job, and cleared (`false`) on each of: finished (clean or with failed clips), all failed, `spaceFull`, `interrupted`, Stop (cancel), leaving the screen (pop or replace) and dispose; **Try again** sets it again; it is never left on after the route is gone (a fake bridge records the calls in order);
  - results: `spaceFull` and `interrupted` (also the one `recoverAtStart` built after a restart, opened on start through `takeUnseenResult`) → **Try again** calls `resumeCopy` and returns to progress; **Delete copies and stop** cancels; finished with failures → the "couldn't be copied" screen (time in the clip's local time), **Continue** calls `finishJob`; all failed → **Back** cancels (the empty session ends); finished cleanly → `finishJob` then the ready screen (first job) or the reel page with "{n} clips added to the VN folder" (add job);
  - ready: the session's folder name (also after a rename), up to six numbered thumbnails, **Open VN** calls `openApp` (false → the missing dialog), **Done** and close go to the reel page;
  - the app coming to the front with an unseen result opens the progress route for it, once;
  - the reel deleted while a copy screen is open (the job is cancelled by Task 6's delete hook): the screen pops to Reels without an error.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement with `TtStatusLayout`, `TtStorageBar`, `TtIllustratedSteps`.
- [ ] **Step 4:** Run `tool/check` and goldens. Expected: PASS. Mutation-check the back-opens-Stop rule, first-job vs add-job routing, and the screen-on clear on `spaceFull` and on dispose (each alone).
- [ ] **Step 5:** Docs: D-127; `flow.md`; guide section 10. Commit `feat(editors): VN space check, copying, results and ready steps`.

---

### Task 11: The reel page while editing (heavy, the biggest UI task)

**Model:** Opus. **Files:**
- Create: `lib/features/reels/views/reel_edit_banner.dart`, `reel_edit_sections.dart`, `lib/features/editors/views/done_editing_dialog.dart`; `lib/features/reels/view_models/reel_edit_state.dart`.
- Modify: `reel_detail_screen.dart` (split it so it stays under ~700 lines), `reel_detail_controller.dart` (verify copies on open), `reels_screen.dart` (card pill), `delete_reel_dialog.dart`, `edit_select_screen.dart` and `edit_select_controller.dart` (VN add mode), `undo_snacks.dart`, `app_en.arb`.
- Test: `test/features/reels/{reel_edit_sections_test,reel_edit_banner_test}.dart`, `test/features/editors/done_editing_dialog_test.dart`, extend the reel page, Home, delete dialog and edit-select tests; macOS goldens for the editing reel page (VN and CapCut, with and without new clips), the add picker and both dialogs.

**Interfaces (consumes):** `watchEditState`, `watchEditors`, `splitForEditing`, `addPicks`, `doneEditing`, `verifyCopies`, `CopyJobController`, `Routes.reelDoneParameter` (Task 7), Tasks 9 and 10. **Produces:** `showDoneEditingDialog(BuildContext, WidgetRef, int reelId) → Future<void>` (Task 7 and Task 13 call it); `reelEditStateProvider(reelId)`.

Copy, verbatim from the prototype: banner "Editing in VN · {size}" / "{n} copies in Movies/TakeTray/{folder}", **Done editing** / **Add more clips**; card pill "Editing in VN"; add mode "Add clips to VN folder", tile mark "In VN folder", "{n} new clips to copy" / "{size} · copies are added, never renamed", "Pick clips to add" / "{n} already in the VN folder", button **Copy**, snack "Already in the VN folder. Copies are deleted when you tap Done editing."; "Have you exported your video?" / "Once the copies are deleted, the VN project for **{name}** can't be edited any more. This frees {size}." / "Your original clips are safe in your gallery." **Not yet** / **Delete copies**; snack "Copies deleted · {size} freed"; "Mark {name} as Published?" / "It moves to the Published filter. You can change this any time." **Not now** / **Mark as Published**; delete line "The {n} VN copies ({size}) will also be deleted, and the VN project can't be edited after that." New copy: sections "New since you started editing" / "{n} clips · not in your edit yet" with **Copy to VN folder** (VN) or **Add to your CapCut project** / **Add to your Edits project**, and "In your edit" / "{n} clips · in the VN folder" (VN) or "{n} clips · sent to {editor} on {date}"; banner for CapCut/Edits "Editing in CapCut" (plus " · {size}" with copies) / "Sent on {date}" (plus " · {n} copies in Movies/TakeTray/{folder}"), **Done editing**; pills "Editing in CapCut", "Editing in Edits"; running job banner "Copying clips for VN" / "{done} of {total} clips", action **Show**; CapCut with copies "Have you exported your video?" / "Once the copies are deleted, clips you added to your CapCut project from the folder may show as missing. This frees {size}."; CapCut without copies "Done editing {name}?" / "TakeTray stops showing which clips are in your CapCut project. Nothing is deleted." **Not yet** / **Done editing**, snack "Done editing {name}"; delete line for CapCut copies "The {n} copies in Movies/TakeTray/{folder} ({size}) will also be deleted."; "Couldn't delete the copies. Try again."; remove snack suffix " Its copy in the folder was deleted." / " Their copies in the folder were deleted."

- [ ] **Step 1: Write the failing tests:**
  - no session: today's page, unchanged goldens; with a session: the banner above the clips; the split from `splitForEditing` (sent ∪ live copies), each section with its own day headers; no new clips → only "In your edit"; missing clips stay in their section; a clip tagged in meanwhile appears under "New since…" at once;
  - opening the page verifies copies (`verifyCopies`), guarded; a copy deleted outside TakeTray moves its clip (not sent) to "New since…";
  - `Routes.reelDoneEditing(id)` (Task 7's notification tap) shows the Done editing dialog once when the reel has a session, and just the page when it has none; going back and forth does not show it again;
  - add mode (from the section button and **Add more clips**): every live clip; fresh ones pre-ticked; in-folder tiles ticked, locked, marked, tapping shows the snack; sent-not-copied selectable (CapCut only, Task 12); the bottom bar counts only clips to copy; **Copy** → Task 10's space route with only those clips;
  - a running job for this reel replaces the banner's actions with **Show** (opens progress); **Done editing** is not offered while it runs;
  - Done editing: the right dialog per editor and copies; **Delete copies** runs once on a double tap; success → the snack (freed size) and, after 0.9 s, the Published dialog unless already Published; `CopiesNotDeleted` → "Couldn't delete the copies. Try again." and the banner stays;
  - delete dialog: the VN or folder line only with copies; a failed copy delete keeps the reel and shows the error in the dialog;
  - remove and move during a session: the snack gets the suffix when a copy was deleted; `CopiesNotDeleted` → "Couldn't delete the copies. Try again." and nothing removed; Undo brings the clip back under "New since…";
  - Home: the card pill per editor and the label "{name}. {status}. {n} clips[, {m} missing]. Editing in VN";
  - text at 2x: banner actions under the text, section buttons wrap, nothing cut.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. The section header is `TtSceneHeader` (title, subtitle, action).
- [ ] **Step 4:** Run `tool/check` and goldens. Expected: PASS. Mutation-check the split's union, the locked in-folder tiles, and Done editing hidden while copying.
- [ ] **Step 5:** Docs: D-128 (the split's headlines, R1, R8, the dialogs per editor); `flow.md` "Opening a reel" and "The delete reel dialog"; guide section 11; delete the later.md VN-pieces, sanitise and remove-copy items. Commit `feat(reels): the reel page while editing, Done editing and VN add-later`.

---

### Gate before Task 12 (the owner's hand checks)

The plan assumes **(a) true**: CapCut's and Edits' "add media to a project" pickers show an album for `Movies/TakeTray/<Reel>` (one test video copied there by a debug build), in shooting order, with select-all or quick multi-select; and **(b) false**: sharing to CapCut or Edits always opens a new project and never offers "add to an existing project". The controller asks the owner for both answers before dispatching Task 12, and records them in D-129.

- **(a) false** (no album, or no usable order): skip Task 12's copy flow. For CapCut/Edits sessions the "New since you started editing" button becomes **Send to {editor}** (a direct share of the new clips; they open in a new project, recorded as sent), with the subtitle "{n} clips · {editor} opens them in a new project"; the add picker stays VN-only; R6's reminder and the storage screen then only ever see VN copies.
- **(b) true** (sharing can add to an existing project): no copies for CapCut/Edits at all. The button becomes **Add to your {editor} project** as a direct share of the chosen clips (recorded as sent, no space check, no folder); Task 12 shrinks to that share and its tests.
- Both answers as assumed: Task 12 as written.

---

### Task 12: CapCut/Edits add-later through the folder (gated)

**Model:** Sonnet. **Files:**
- Modify: `edit_select_screen.dart` / `edit_select_controller.dart` (CapCut/Edits add mode), `copy_space_screen.dart`, `copy_progress_screen.dart`, `copy_ready_screen.dart`, `reel_edit_sections.dart`, `app_en.arb`.
- Test: extend the four screens' tests and goldens.

**Interfaces (consumes):** Tasks 6, 10, 11 (all already editor-aware: `planCopy` and `startCopy` take `EditorApp`).

Copy (new): add mode "Add clips to your CapCut project" / "Add clips to your Edits project"; tile mark "In the folder"; bottom bar "{n} clips to copy" / "{size} · into Movies/TakeTray/{folder}", "Pick clips to add" / "{n} already in the folder"; locked-tile snack "Already in the folder. Copies are deleted when you tap Done editing."; space title "Copy clips for {editor}"; callout "Why copies?" "{editor} adds clips to a project from an album. TakeTray copies the clips you picked to **Movies/TakeTray/{folder}**. Your original clips stay where they are." and "Copies are temporary" "After you export from {editor}, tap Done editing and TakeTray deletes them."; progress "Copying clips for {editor}"; ready "Ready to add in {editor}" / "In your {editor} project, tap **+** and open the **{folder}** album."; steps "Open your project in {editor}" "The one you started from TakeTray.", "Open the {folder} album" "It's in Movies › TakeTray.", "Pick the new clips" "They're in shooting order."; **Open {editor}** / **Done**.

- [ ] **Step 1: Write the failing tests:** sent-not-copied clips are selectable and copy when ticked; fresh pre-ticked; in-folder locked with "In the folder"; a copy gone outside TakeTray is selectable again; the space and progress copy per editor; the ready screen per editor with the session's folder; a second batch adds to the same folder with new names only (`_2` against existing names), never renaming earlier copies.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `tool/check` and goldens. Expected: PASS.
- [ ] **Step 5:** Docs: D-129 (the gate's answers and what was built); `flow.md`; guide section 12. Commit `feat(editors): add later clips to a CapCut or Edits project through the reel's folder`.

---

### Task 13: The VN copies storage screen

**Model:** Sonnet. **Files:**
- Create: `lib/features/editors/views/copies_storage_screen.dart`, `view_models/copies_storage_controller.dart`.
- Modify: `lib/features/settings/views/settings_screen.dart` (an interim "Clips" group with one row), `routes.dart`, `app_router.dart`, `app_en.arb`.
- Test: `test/features/editors/copies_storage_screen_test.dart`, extend the Settings test; macOS goldens (with copies, with orphans, empty).

**Interfaces (consumes):** `EditSessionService.storage`, `deleteOrphans`, `showDoneEditingDialog`. **Produces:** `Routes.copiesStorage = '/settings/vn-copies'` (above the shell, like the help screen).

Copy, verbatim: row "Storage used by VN copies" / "{size} in {n} reels" or "None"; title "VN copies"; "{size}" / "used by VN copies in {n} reels"; row "{n} copies · {size} · since {date}", **Delete**; "Copies are only for VN. Deleting them never touches your original clips."; empty "No VN copies" / "When you edit a reel in VN, its temporary copies show up here.". New: CapCut/Edits rows "{n} copies for {editor} · {size} · since {date}"; orphan group "Not linked to a reel" with the line "Left from an earlier install or a backup import. Android asks before deleting them."; orphan row the folder name and "{n} files · {size}", **Delete**; without full access, the callout "With full video access, TakeTray can also find copies left from an earlier install."; snack "Copies deleted · {size} freed".

- [ ] **Step 1: Write the failing tests:** total and per-session rows from `storage()`, newest first, cover thumbnails; **Delete** opens the Done editing dialog (same rules, Task 11) and the row leaves after success; orphans grouped by folder, **Delete** → `deleteOrphans` (declined → no snack, row stays; allowed → snack, row leaves); a failed `storage()` → the error with **Try again**; resume re-reads; the Settings row's summary; empty state.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `tool/check` and goldens. Expected: PASS.
- [ ] **Step 5:** Docs: D-130 (R7, the orphan route); `flow.md`; guide section 13. Commit `feat(editors): VN copies storage screen with orphaned copies`.

---

### Task 14: On the S24

**Model:** Sonnet (phone safety rules apply). **Files:** `app/patrol_test/editors_test.dart`, `app/patrol_test/support/` (helpers for the editors hook), `docs/dev-setup.md` (the Phase 8 checks), `docs/decisions.md` (D-131), guide section 14.

- [ ] **Step 1: Write every flow with no device**, in one file, using only `Movies/TakeTray Test/` videos and reels named `TakeTray Test <timestamp>`. The editors hook is on (`recordIntents(true)`, `setInstalledOverride({all three: true})`), so no editor, store or share sheet ever opens.
  - **CapCut send:** 3 test videos tagged into a new reel; **Edit video**, **Select all**, **Continue**, **CapCut**. The recorded intent: `ACTION_SEND_MULTIPLE`, package `com.lemon.lvoverseas`, 3 URIs in shooting order, the grant flag, `ClipData` of 3. Snack "Sent 3 clips to CapCut"; Ready dialog **Not now**; the page shows "In your edit". **Done editing** → **Done editing**; Published dialog **Not now**.
  - **Not installed:** override CapCut false; its row is greyed and says "Not installed".
  - **VN copy, for real:** a new reel of 3 test videos; VN; the space screen; **Copy 3 clips**; the real copy runs in the app; the ready screen names the folder and `keepScreenOnFlag()` is false there; the hook counts exactly 3 rows in that one folder (queried by its exact path only). **Open VN** is recorded, not started. **Done editing** → **Delete copies**; the folder count is 0 and "Copies deleted · … freed" shows.
  - **Cancel:** `setCopyThrottleMs(200)`; start a 3-clip copy; `keepScreenOnFlag()` is true while it runs; **Cancel** → **Stop**; folder count 0; "Copying stopped. No copies were kept."; `keepScreenOnFlag()` is false.
  - **Add later:** during a VN session, tag a 4th test clip into the reel; "New since you started editing" shows 1; **Copy to VN folder**; the picker pre-ticks it; **Copy**; "1 clip added to the VN folder"; folder count 4.
  - **Remove during a session:** remove one clip; folder count drops by 1.
  - **Share:** the viewer's Share records a chooser around `ACTION_SEND` with 1 URI and the grant.
  - **Reminder tap:** `showCopiesReminderNow(reelId)` (debug hook); tap the notification body while it is TakeTray's only notification; the reel page and the Done editing dialog show; **Not yet**.
  - Tear-down: Done editing on every test reel through the app (its own guarded delete), then the test media hook removes the test videos.
- [ ] **Step 2:** `cd app && ../tool/flutter analyze patrol_test` and `../tool/flutter build apk --debug --target=patrol_test/editors_test.dart` (offline, no device). Then a **Sonnet review** of the file against the phone rules. Fix, then ask the owner for the S24.
- [ ] **Step 3:** Run `tool/patrol test -d RZCY80PHWCZ -t patrol_test/editors_test.dart` **once**, then the after-run steps. On failure, at most 2 fix attempts on the same flow, then report. One deliberate wrong expectation fails on the fastest flow, then is reverted.
- [ ] **Step 4:** Run all other Patrol files **once**, back to back, with the after-run steps at the end; report failures rather than debugging them. Run `tool/check_release_permissions` (unchanged permissions; must end `RELEASE PERMISSIONS OK`).
- [ ] **Step 5:** The owner's hand checks in `docs/dev-setup.md` (only real editors can show these):
  1. CapCut: 5 clips of a reel, including one added through the photo picker in Phase 7, open in **one** new project in shooting order (this proves the picker-URI grant).
  2. Instagram Edits: the same.
  3. VN: **New project** shows `Movies › TakeTray › <Reel>`, its clips in shooting order, and select all works; after Done editing the folder is gone from VN's picker.
  4. Copy about 2 GB with TakeTray open: the screen stays on and dims back to normal once copying finishes, is stopped or fails; the progress and the "Keep TakeTray open" line show.
  5. Leave TakeTray (Home button) during a copy and come back: copying went on, or the result is shown. Then swipe TakeTray away from recents during a copy and reopen: "Copying stopped" shows, no half file is in the folder, the finished copies are kept, and **Try again** copies only the rest.
  6. CapCut/Edits add-later through the folder, per the gate's answers (Task 12).
  7. The 3-day reminder (or its debug trigger) and its **Done editing** button.
  8. Reinstall the dev build with copies on the phone: the storage screen lists the folder under "Not linked to a reel"; **Delete** shows Android's dialog and the files go.
- [ ] **Step 6:** D-131 (what the phone showed; what is proven by hand only); guide section 14. Commit `test(editors): Patrol flows on the S24`, push.

---

### Task 15: Phase end (controller)

- [ ] **Step 1:** Minors batch on Sonnet (one agent, self-reviewed). Then the final whole-branch review on **Opus**. One fix wave on Sonnet. Re-review on the same Opus reviewer.
- [ ] **Step 2:** Docs: README (Phase 8 ✅ Done, Phase 9 Next, a Phase 8 section listing what it added: sending to CapCut and Edits, VN copies made with the app open, the editing reel page, Done editing, the reminder, the storage screen, schema v2); the guide's intro; `docs/later.md` (delete the Phase 8 section once empty).
- [ ] **Step 3:** CI goldens, CI green on the branch, a PR to `main` (after Phase 7 lands). Merge only after the owner says so. Then install the release APK over `app.taketray` with `install -r`. List every ruling made on the owner's behalf in the final message.
