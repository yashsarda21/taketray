# Phase 3: Android Media Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** TakeTray finds the user's real videos. With Shooting mode on and full video access, every new video shot with the phone's camera appears in To tag, with its thumbnail. Access states (full, limited, denied), a rebuilt media library, deleted videos and unmounted SD cards are all handled without ever showing the wrong video. Done when real videos appear in To tag on the S24 Ultra (spec §9, phase 3).

**Owner request (2026-10-28): "Add earlier videos".**
- After Shooting mode is turned on, the card offers **Add earlier videos**. The same action is always in To tag's ⋮ menu.
- It opens a sheet: **Today**, **Last 2 days** or **Last 7 days**, each with the number of new videos it would add.
- It adds videos from the watched folders shot in that window to To tag:
  - A clip already tagged into a reel, skipped or pending is never added again.
  - The Shooting mode switch stays one tap, and the baselines are not touched.
- It needs full access; in Manual mode it is hidden. The owner chose this placement over asking at every turn-on, or a setting.
- It isn't in the prototype, so its copy is fixed in Task 10 and recorded as a decision.

**Architecture:**
- **Native (Kotlin):** one Pigeon host API, `MediaHostApi`, in `app/android/app/src/main/kotlin/app/taketray/media/`. It is a thin pipe: it reads the permission state, the volumes, MediaStore rows, thumbnails and the zone-change list, and returns raw values. It makes no decisions about what is new, missing or the same video.
- **Dart:**
  - `lib/platform/` wraps the generated API behind a `MediaBridge` interface, so everything else is tested with a fake.
  - `lib/domain/rules/` holds the decisions as pure functions: the shooting date, the per-volume plan, how far the baseline may advance, and "is this the same video".
  - `lib/data/media/` holds the services that run them: the scanner, the verifier, zone sync and the thumbnail cache.
  - `lib/data/repositories/` gains phone state (Shooting mode, baselines) and the new clip writes.
- **UI:** the first real To tag screen (a flat grid; Phase 5 adds scenes and tagging), the Shooting mode card at the top of the Reels tab (Phase 4 builds the rest of Home), and the access banner.

**Tech Stack:**
- Flutter 3.47.7 / Dart 3.13.5 via `tool/flutter`
- **pigeon 29.0.11**, pinned exactly (no caret): the Dart and Kotlin sides must come from the same version
- Kotlin (JVM 17)
- **Robolectric 4.17** with JUnit 4 for Android unit tests (SDKs 30, 33, 34, 35)
- Riverpod 3 codegen, Drift, freezed (already in the app)
- Patrol 4.10 on the S24

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`: §3, §4 (anti-goals), §5, §8.1, §8.2 (MediaApi), §8.3 (detection), §8.3a (zones), §8.6 ("X of Y found"), §9 phase 3, §10, §11. Parked items: the "Phase 3" section of `docs/later.md`. Research notes, with sources, are in the session scratchpad (`phase3-research.md`), and their conclusions are copied into this plan.

## Global Constraints

- **SDK:** use `tool/flutter`, `tool/dart`, `tool/adb` and `tool/patrol` only. Never use the `flutter` on PATH, and never touch `~/flutter`.
- **Platform facts (from research, 2026-10-28):**
  - Flutter 3.47.7 defaults to compileSdk 36 and targetSdk 36. minSdk stays 30.
  - `MediaStore.getVersion(context, volume)` is an opaque string (per app on Android 16+), so only ever compare it for equality. It can be null for an unmounted volume.
  - `MediaStore.getGeneration` only grows within one version. Generations never report deletions.
  - Under limited access, queries return only the rows the user selected.
  - `loadThumbnail` throws `FileNotFoundException`/`IOException` for a gone item, and may also throw `SecurityException` or `OperationCanceledException`. The bitmap can be larger than requested.
- **Permissions** (manifest, main):
  - `READ_EXTERNAL_STORAGE` with `android:maxSdkVersion="32"`
  - `READ_MEDIA_VIDEO`
  - `READ_MEDIA_VISUAL_USER_SELECTED`

  Nothing else media-related: no `READ_MEDIA_IMAGES`, no `MANAGE_EXTERNAL_STORAGE`, no `ACCESS_MEDIA_LOCATION`. The release build still has no `INTERNET`.
- **No Haiku, ever.** Every subagent runs on Sonnet or Opus, named explicitly when dispatched. Tasks 4, 5 and 7 and the phase review run on Opus; every other task runs on Sonnet.
- **Tight testing (owner's rule, 2026-10-26):**
  - Every test listed in a task is written first and shown failing (red), then passing (green). The report quotes both runs.
  - Each task's report names at least two **mutation checks**: a deliberate one-line break in the new code (an off-by-one, a flipped condition, a removed guard) that a named test catches. The report quotes the failing output, and the break is reverted.
  - Never loosen, skip or delete a test to get green.
  - Anything that depends on Android behaviour is proven on the S24 in Task 11.
- **Wrong video is the worst bug (spec §4 anti-goal):** when TakeTray is unsure whether a MediaStore row is a stored clip's video, the clip is treated as missing, never matched.
- **Privacy:**
  - Log lines never contain a display name, a relative path or folder, a URI or a reel name (D-10). Volume names, ids, generations and counts are fine.
  - The MediaStore version string isn't logged either; log "changed" or "same".
- **Phone rule:**
  - Only `app.taketray`, `app.taketray.dev` and `app.taketray.widgetbook` may be installed, cleared or run on the S24. Logcat is read only through a pid filter for TakeTray.
  - No screenshots, and no reading of other apps or of shared storage.
  - The only exception, once the owner has approved it: Patrol tests create and then delete their own test videos in `Movies/TakeTray Test/`.
- **Time:** "now" comes from `clockProvider`. Stored instants are UTC.
- **Generated code:**
  - Pigeon output (`app/lib/platform/media_api.g.dart` and `app/android/app/src/main/kotlin/app/taketray/media/MediaApi.g.kt`) is committed, like other generated code.
  - `tool/check_generated` regenerates it and fails when it is stale.
- **Coverage:** at least 80 % for `lib/domain/`, `lib/data/`, `lib/platform/` (excluding `*.g.dart`) and `lib/features/*/view_models/`. Task 2 makes unloaded files count and adds the wildcard.
- **Living docs:**
  - The next free decision number is **D-63**. Task 1 takes D-63 and D-64; later tasks take the next free numbers in order.
  - Every changed flow updates `docs/flow.md`. Every done `docs/later.md` item is deleted.
  - Docs go in the same commit as the code.
- **Learning guide (owner's request):**
  - Task 1 creates `docs/learn/phase-3-media-bridge.md` with stubbed sections. Tasks 2–11 each fill in their own section, in the same commit as their code.
  - Template, as in Phase 2: what we built / why TakeTray needs it / key ideas with short real snippets / where it lives / one working "try it yourself" / decisions.
  - Reviewers check each section against the code, and a wrong explanation is a defect. Task 12 turns the sections into one guide.
- **Git (D-63):**
  - Work on branch `phase-3-media-bridge`, created from `main`, and push it to `origin` after every task commit:

    ```bash
    git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u origin phase-3-media-bridge
    ```

  - CI must be green on the branch before the next task starts. A red CI run is fixed in that task.
  - Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never force-push.
  - The phase lands on `main` through a pull request after the owner approves.

## Review Focus

1. **Limited or denied access while clips exist.** The user picks "Select photos and videos", or Android removes access after months unused. Expected:
   - No clip is marked missing, because the verifier skips everything unless access is full.
   - The scan finds nothing and doesn't move the baselines.
   - The banner says "Manual mode" or "TakeTray can't see your videos".

   Owner: Task 7 (`verifier skips without full access`, `scan does nothing without full access`) and Task 9 (banner rule).
2. **A video still being recorded when TakeTray scans.** Camera apps insert an `IS_PENDING` row at the start of a recording. Expected: the video appears in To tag after it is finished. It is never skipped forever because the baseline moved past it. Owner: Task 5 (`advanceBaseline holds before the oldest pending row`) and Task 7 (`pending video appears on the next scan`).
3. **Android rebuilds its media library** (a new version string, after a restore or a database reset). Expected:
   - No flood of "new" clips.
   - Stored clips are found again by fingerprint.
   - A clip with two equally good candidates, or none, becomes missing.
   - A clip's old MediaStore number can never pick up a different video later.

   Owner: Task 5 (`matchAfterRebuild`), Task 6 (`applyRebuildMatch`, detach) and Task 7 (`version change resyncs, adds nothing`).
4. **Shooting mode turned off and on while a scan runs, or three triggers at once** (app start, resume and opening To tag). Expected:
   - No clip shot while Shooting mode was off ever appears.
   - No duplicates.
   - A baseline never moves backwards, and a stale scan never overwrites a new session's baseline.

   Owner: Task 6 (`advanceBaseline is compare-and-set`) and Task 7 (`concurrent scans coalesce`, `scan started before off/on cannot write the new session's baseline`).
5. **An SD card removed, or a video deleted from the gallery.** Expected:
   - Clips on an unmounted volume are left alone, not marked missing.
   - A deleted video that was only in To tag or Skipped leaves the list.
   - A deleted video in a reel is flagged missing.
   - Thumbnails never show a different video after a renumbering.

   Owner: Task 7 (`unmounted volume is skipped`, `missing inbox clip leaves To tag`) and Task 8 (`cache key changes when the fingerprint changes`).

---

## File structure

```
app/
  pubspec.yaml                          + pigeon 29.0.11 (dev, exact)
  pigeons/media_api.dart                Pigeon contract (input)
  lib/platform/media_api.g.dart         generated
  lib/platform/media_bridge.dart        MediaBridge interface + PigeonMediaBridge + provider
  lib/domain/models/media.dart          MediaAccessLevel, MediaAccess, MediaVolume, MediaVideo, VideoFolder,
                                        VolumeBaseline, ShootingState (freezed)
  lib/domain/rules/clip_date.dart       shotAt (R4g fallback + clamp)
  lib/domain/rules/media_clip.dart      newClipFrom
  lib/domain/rules/baseline.dart        VolumePlan, planVolume, advanceBaseline
  lib/domain/rules/fingerprint_match.dart   sameVideo, matchAfterRebuild, RebuildMatch
  lib/data/repositories/phone_state_repository.dart   Shooting mode, baselines, access memory
  lib/data/repositories/clips_repository.dart         + mediaStoreClipsOn, applyRebuildMatch, detach,
                                                        removeMissingFromLists
  lib/data/repositories/zone_repository.dart          + recordAll (time-ordered merge)
  lib/data/media/media_scanner.dart     MediaScanner, ScanOutcome
  lib/data/media/media_verifier.dart    MediaVerifier, VerifyOutcome
  lib/data/media/zone_sync.dart         ZoneSync
  lib/data/media/thumbnail_cache.dart   ThumbnailCache
  lib/features/media_access/view_models/media_access_controller.dart
  lib/features/media_access/widgets/media_access_banner.dart
  lib/features/shooting_mode/view_models/shooting_mode_controller.dart
  lib/features/shooting_mode/widgets/shooting_mode_section.dart
  lib/features/tagging/view_models/to_tag_controller.dart
  lib/features/tagging/views/to_tag_screen.dart        (replaces to_tag_placeholder_screen.dart)
  lib/features/clips/widgets/clip_thumbnail_image.dart  ImageProvider over ThumbnailCache
  lib/app/media_lifecycle.dart          start/resume: zone sync, access refresh, scan
  test/support/fake_media_bridge.dart
  android/app/src/main/AndroidManifest.xml             permissions, backup rules, zone receiver
  android/app/src/main/res/xml/data_extraction_rules.xml, backup_rules.xml
  android/app/src/main/kotlin/app/taketray/MainActivity.kt   registers the API, permission results
  android/app/src/main/kotlin/app/taketray/media/      MediaApi.g.kt, MediaHostApiImpl.kt, MediaAccessChecker.kt,
                                                        VideoQueries.kt, Volumes.kt, Thumbnails.kt,
                                                        ZoneChangeStore.kt, TimeZoneChangedReceiver.kt
  android/app/src/test/kotlin/app/taketray/media/      Robolectric tests
  android/app/src/debug/kotlin/app/taketray/DebugHooks.kt     test-media helper (debug only)
  android/app/src/{release,profile}/kotlin/app/taketray/DebugHooks.kt   no-op
  patrol_test/media_access_test.dart, patrol_test/media_scan_test.dart, patrol_test/fixtures/test_video.dart
tool/check, tool/check_generated, tool/check_release_permissions, tool/test_android, tool/bin/check_coverage.dart
.github/workflows/check.yml             + Java 17, Gradle cache
docs/learn/phase-3-media-bridge.md
```

---

### Task 1: Branch workflow, Google backup off, release manifest checks

**Model:** Sonnet.

**Files:**
- Create: `app/android/app/src/main/res/xml/data_extraction_rules.xml`, `app/android/app/src/main/res/xml/backup_rules.xml`, and `docs/learn/phase-3-media-bridge.md` (a skeleton)
- Modify: `app/android/app/src/main/AndroidManifest.xml`, `tool/check_release_permissions`, `docs/decisions.md`, `docs/flow.md` ("Release permission check"), `docs/later.md`

- [ ] **Step 1: Create the branch and record D-63 (the first commit)**

  - `git switch -c phase-3-media-bridge` from an up-to-date `main`.
  - Add **D-63, phase branch → pull request**: each phase works on `phase-N-…`, which is pushed after every task commit so CI runs on it. The phase ends with a PR into `main` that must be green. The owner approves before merging, and the branch is deleted after the merge. Why: the owner asked for it on 2026-10-27, so `main` only gets CI-green, reviewed code.
  - Commit as `docs: D-63 phase branches land through green pull requests`, push with `-u`, and confirm CI starts with `gh run list -R yashsarda21/taketray --branch phase-3-media-bridge --limit 1`.

- [ ] **Step 2: Write the failing release check**

  Extend `tool/check_release_permissions`. After the build, dump the merged manifest with `aapt2 dump xmltree --file AndroidManifest.xml <apk>` and fail, naming the problem, unless all of these hold:
  - `android:allowBackup` is false.
  - `android:dataExtractionRules` and `android:fullBackupContent` are set.
  - `READ_MEDIA_VIDEO` and `READ_MEDIA_VISUAL_USER_SELECTED` are present, and `READ_EXTERNAL_STORAGE` has `maxSdkVersion` 32. (Before Task 4 adds them, write this permission part as a list the script reads, and enable it in Task 4. This step only adds the backup checks.)
  - None of `INTERNET`, `READ_MEDIA_IMAGES`, `MANAGE_EXTERNAL_STORAGE` or `ACCESS_MEDIA_LOCATION` is present.

  Run it. Expected: FAIL with "allowBackup is not false".

- [ ] **Step 3: Turn Google backup off (owner's decision, 2026-10-28)**

  - In the manifest's `<application>`, set:
    - `android:allowBackup="false"`
    - `android:dataExtractionRules="@xml/data_extraction_rules"` (API 31+)
    - `android:fullBackupContent="@xml/backup_rules"` (API 30)
  - In both XML files, exclude every domain:
    - `data_extraction_rules.xml` excludes `root`, `file`, `database`, `sharedpref` and `external` (path `.`), in both `<cloud-backup>` and `<device-transfer>`.
    - `backup_rules.xml` has the same `<exclude>`s inside `<full-backup-content>`.
  - Comment why: drift_flutter's file lives under `app_flutter/` (`context.getDir("flutter")`), which is backup domain `root` (`file` is only `files/`), with `-wal`/`-shm` sidecars. On another phone, its MediaStore ids would point at other videos.

- [ ] **Step 4: Run the check again**

  Expected: `RELEASE PERMISSIONS OK`. Also run `tool/check`.

- [ ] **Step 5: Write the learning-guide skeleton**

  Create `docs/learn/phase-3-media-bridge.md` with:
  - the title, "How to read this guide" and the section template
  - a Contents list
  - "The big picture" (a Mermaid diagram of Kotlin ↔ Pigeon ↔ `MediaBridge` ↔ scanner/verifier ↔ repositories ↔ screens)
  - stub sections 1–11 (one per task 1–11): `## N. <title>` plus `_Written in Task N._`
  - "Glossary" and "What's next" stubs

  Fill in Section 1 now: why Google backup is off, in plain words, with the manifest snippet. Export/Import is a same-phone backup (spec §8.6); moving phones isn't supported in v1.

- [ ] **Step 6: Update the docs and commit**

  - Add **D-64, no Google backup or device transfer of app data**. It records the owner's choice, the alternative (copy the data and re-match by fingerprint) and why it lost (a wrong video is possible, and only helps when the videos moved too). Consequence: a new phone starts empty; Export/Import is a same-phone backup, and moving phones isn't supported in v1 (spec §8.6).
  - Update "Release permission check" in `docs/flow.md`.
  - Delete the Auto Backup line from `docs/later.md`.
  - Commit as `build(android): no Google backup of app data; release manifest checks (D-64)`, then push.

**Edge cases to prove:** the check fails when any one rule is broken. Prove it with three temporary edits: `allowBackup` removed, `READ_MEDIA_IMAGES` added, and `dataExtractionRules` removed. Each must be caught, then reverted. This is the task's mutation check.

---

### Task 2: Parked hygiene: logging, the coverage gate, banners

**Model:** Sonnet.

**Files:**
- Modify: `app/lib/core/logging/logging_setup.dart`, `app/test/core/logging/logging_setup_test.dart`, `tool/check`, `tool/bin/check_coverage.dart` and its tests in `tool/test/`, `packages/taketray_ui/lib/src/components/banners.dart` and its tests and goldens, `docs/later.md`, `docs/flow.md`

- [ ] **Step 1: Logging hardening (failing tests first)**

  - `privacy test reads the raw LogRecord.message`: assert on `record.message`, not on `formatRecord` output.
  - `an error whose toString throws does not escape the listener`: log with `error: _ThrowingToString()`. The listener must still write a line, containing `<unprintable error>`, and must not throw.
  - `tearDown` resets `driftRuntimeOptions.dontWarnAboutMultipleDatabases` to its earlier value.

  Then guard `formatRecord` in the listener with try/catch, falling back to `'<unprintable error>'` for the error part.

- [ ] **Step 2: Make unloaded files count in the coverage gate**

  - Before the coverage test run, `tool/check` writes a temporary `app/test/_coverage_imports_test.dart`. It imports every non-generated `.dart` file under the gated prefixes and holds one empty test. `trap` deletes it on exit, success or failure.
  - `tool/bin/check_coverage.dart` takes prefixes that may contain `*` for exactly one path segment, such as `lib/features/*/view_models/`.
  - The `tool/check` prefixes become `lib/domain/ lib/data/ lib/platform/ lib/features/*/view_models/`.
  - `*.g.dart` and `*.freezed.dart` stay excluded.
  - A prefix that matches no file yet passes with "no files", because `lib/platform/` and the view models arrive in Tasks 3 and 9. Test: `prefix with no files passes`.
  - Tests in `tool/test/check_coverage_test.dart`:
    - `wildcard matches one segment only`: `lib/features/a/view_models/x.dart` matches; `lib/features/a/b/view_models/x.dart` doesn't.
    - `a file with zero hits lowers the total`
    - `enum-only file with no lines is ignored`

  Prove the whole thing once: add an untested file `lib/data/_probe.dart` holding 30 executable lines and confirm the gate's total drops. Then delete it.

- [ ] **Step 3: `TtBanner`**

  - Assert in the constructor that `onTap` and `action` are not both set. Test: `TtBanner with onTap and action asserts`.
  - Match each banner's prototype icon and fill:
    - waiting: `sell`, filled
    - Manual mode: `lock`, outlined
    - "can't see your videos": `no_photography`, outlined

    Fill is a parameter (`iconFilled`, default true); the callers choose.
  - Update the macOS goldens with `--update-goldens`. Push, run the **update goldens** workflow on the branch (`gh workflow run update-goldens.yml -R yashsarda21/taketray --ref phase-3-media-bridge`), pull the result with `tool/pull_ci_goldens <run-id>`, and look at the changed images before committing them.

- [ ] **Step 4: Run `tool/check`, update the docs, commit and push**

  - `tool/check` must pass.
  - Update `docs/flow.md` ("Local checks", step 10).
  - Delete the done `docs/later.md` lines.
  - Fill in learning-guide Section 2, which covers why a file nobody tests used to be invisible to the gate.
  - Commit as `chore: logging hardening, coverage counts unloaded files, banner icons`, then push, and CI must be green.

---

### Task 3: The Pigeon contract and the Dart bridge

**Model:** Sonnet.

**Files:**
- Create: `app/pigeons/media_api.dart`, `app/lib/platform/media_api.g.dart` (generated), `app/android/app/src/main/kotlin/app/taketray/media/MediaApi.g.kt` (generated), `app/lib/platform/media_bridge.dart`, `app/lib/domain/models/media.dart`, `app/test/support/fake_media_bridge.dart`, `app/test/platform/media_bridge_test.dart`, `app/test/domain/models/media_test.dart`
- Modify: `app/pubspec.yaml` (dev: `pigeon: 29.0.11`), `tool/check_generated`, `docs/decisions.md`, `docs/flow.md`

**Interfaces (produced):**

Pigeon contract (`pigeons/media_api.dart`). Kotlin package `app.taketray.media`, Dart output `lib/platform/media_api.g.dart`:

```dart
enum MediaAccessLevelMsg { full, limited, denied }
class AccessReportMsg { MediaAccessLevelMsg level; bool canAskAgain; int sdkInt; }
class VolumeMsg { String volumeName; String? version; int generation; }
class VideoRowMsg {
  String volumeName; int mediaStoreId; int generationAdded; int sizeBytes;
  int? durationMs; int? dateTakenMs; int? dateAddedSec; int? dateModifiedSec;
  String displayName; String relativePath; int? width; int? height;
  String? mimeType; bool isPending;
}
class VideoFolderMsg { String volumeName; String relativePath; int videoCount; }
class ZoneChangeMsg { int atMs; String zoneId; }

@HostApi()
abstract class MediaHostApi {
  AccessReportMsg accessReport();
  @async AccessReportMsg requestAccess();
  void openAppSettings();
  List<VolumeMsg> volumes();
  /// GENERATION_ADDED > afterGeneration, IS_PENDING rows included, rows in
  /// one of [folders] (exact folder, case-insensitive), ordered by
  /// GENERATION_ADDED asc, at most [limit] rows.
  @async List<VideoRowMsg> videosAddedAfter(String volumeName, int afterGeneration, List<String> folders, int limit);
  @async List<VideoRowMsg> videosByIds(String volumeName, List<int> ids);
  /// Every non-pending video on the volume (for the rebuild resync).
  @async List<VideoRowMsg> allVideos(String volumeName);
  /// Non-pending videos in one of [folders] whose DATE_TAKEN (ms) or
  /// DATE_ADDED/DATE_MODIFIED (s) is >= sinceMs, or whose DATE_ADDED is null:
  /// a superset that Dart narrows with shotAt ("Add earlier videos").
  @async List<VideoRowMsg> videosShotSince(String volumeName, List<String> folders, int sinceMs);
  @async List<VideoFolderMsg> videoFolders();
  /// JPEG bytes, or null when the video is gone or unreadable.
  @async Uint8List? thumbnail(String volumeName, int mediaStoreId, int widthPx, int heightPx);
  String currentZoneId();
  List<ZoneChangeMsg> pendingZoneChanges();
  void clearZoneChangesUpTo(int atMs);
  bool openVideoCamera();
}
```

Domain models in `lib/domain/models/media.dart` (freezed; no Flutter or Pigeon imports):
- `enum MediaAccessLevel { full, limited, denied }`
- `MediaAccess(level, canAskAgain, sdkInt)`
- `MediaVolume(name, version?, generation)`, where `isMounted` is `version != null`
- `MediaVideo`: the same fields as `VideoRowMsg`, with `mimeType` defaulting to `'video/*'` when null
- `VideoFolder(volumeName, relativePath, videoCount)`
- `VolumeBaseline(version, generation)`
- `ShootingState(on, since?, baselines: Map<String, VolumeBaseline>, earlierAdded: bool = false)`, where `ShootingState.off` is `on: false, since: null, baselines: {}, earlierAdded: false`. `earlierAdded` hides the card's "Add earlier videos" link once it was used in this Shooting session.

Bridge in `lib/platform/media_bridge.dart`:
- `abstract interface class MediaBridge` has the same methods as the host API, in domain types. `Future` everywhere, `List<int>` for ids, and `ZoneEntry` for zone changes.
- `class PigeonMediaBridge implements MediaBridge` maps both ways.
- `@Riverpod(keepAlive: true) MediaBridge mediaBridge(Ref ref)`.
- Pigeon's `PlatformException` passes through unchanged. Callers decide what to do with it.

`FakeMediaBridge` in `test/support/` (used by Tasks 7–10):
- It has settable `access`, `volumes` and a per-volume list of `MediaVideo`, and it applies `videosAddedAfter` filtering the way the contract says.
- `thumbnails` is a map. `failNext(String method)` makes the next call throw `PlatformException`.
- `calls` logs method names.
- `onRequestAccess` returns a programmable result.
- `zoneChanges` and `currentZone` are settable.
- `Completer` gates let a test pause a call midway (for the race tests in Task 7).

- [ ] **Step 1: Write the failing tests**

  - `media_bridge_test.dart`: a fake `MediaHostApi`, via Pigeon's generated `setUp` on a test binary messenger, or by injecting the api object. Tests:
    - `every message field maps to the domain model and back` covers every field, including all the nulls.
    - `null mimeType becomes video/*`
    - `zone changes map to ZoneEntry with UTC instants`
  - `fake_media_bridge` self-tests:
    - `videosAddedAfter filters by generation, folder (case-insensitive, exact), and limit, in generation order`
    - `failNext throws once`
  - `media_test.dart` covers JSON round-trips for `VolumeBaseline` and `ShootingState`, which are stored as JSON in Task 6.

- [ ] **Step 2: Generate, then implement the bridge**

  Generate with `cd app && ../tool/dart run pigeon --input pigeons/media_api.dart`. The output paths are set in the file's `@ConfigurePigeon`.

  The Kotlin output compiles only once Task 4 implements the interface. Until then, add an empty `MediaHostApiImpl` stub that throws `NotImplementedError` for every method, so `tool/flutter build apk --debug` still compiles. Register nothing yet.

- [ ] **Step 3: Make `tool/check_generated` cover Pigeon**

  It hashes both generated files, re-runs Pigeon for every `pigeons/*.dart` in a member, and compares the hashes. Prove it catches a stale file: hand-edit one line of `media_api.g.dart`, confirm the check fails, then revert.

- [ ] **Step 4: Run the tests, `tool/check` and a debug APK build; update the docs; commit and push**

  - Add **D-65, the native bridge**:
    - one Pigeon host API, pinned exactly
    - a thin Kotlin pipe, with every decision in Dart
    - `MediaBridge` as the seam for tests
    - the generated files committed and checked
  - Update the "Native bridge" section of `docs/flow.md` (new).
  - Fill in learning-guide Section 3, which covers what Pigeon generates and why a fake bridge makes the logic testable without a phone.
  - Commit as `feat(platform): Pigeon media API contract and Dart bridge`.

---

### Task 4: The Kotlin media bridge and Android unit tests (critical, Opus)

**Model:** Opus.

**Files:**
- Create in `app/android/app/src/main/kotlin/app/taketray/media/`: `MediaHostApiImpl.kt`, `MediaAccessChecker.kt`, `VideoQueries.kt`, `Volumes.kt`, `Thumbnails.kt`, `ZoneChangeStore.kt`, `TimeZoneChangedReceiver.kt`
- Create the tests in `app/android/app/src/test/kotlin/app/taketray/media/`, and the script `tool/test_android`
- Modify: `MainActivity.kt`, `AndroidManifest.xml`, `app/android/app/build.gradle.kts`, `tool/check`, `.github/workflows/check.yml`, `tool/check_release_permissions` (turn on the permission list), `docs/*`

**Interfaces:** this task implements `MediaHostApi` from Task 3 exactly. Internal pieces:
- `object MediaAccessChecker`
  - `fun level(sdkInt: Int, granted: (String) -> Boolean): MediaAccessLevelMsg`
    - API 30–32: `READ_EXTERNAL_STORAGE` → full, else denied.
    - API 33: `READ_MEDIA_VIDEO` → full, else denied.
    - API 34+: `READ_MEDIA_VIDEO` → full; else `READ_MEDIA_VISUAL_USER_SELECTED` → limited; else denied.
  - `fun permissionsToRequest(sdkInt: Int): Array<String>`
    - 30–32: `[READ_EXTERNAL_STORAGE]`
    - 33: `[READ_MEDIA_VIDEO]`
    - 34+: `[READ_MEDIA_VIDEO, READ_MEDIA_VISUAL_USER_SELECTED]`, requested together
- `object VideoQueries`
  - `fun addedAfterSelection(afterGeneration: Long, folders: List<String>): Pair<String, Array<String>>`
    - It selects `GENERATION_ADDED > ?` AND `(RELATIVE_PATH = ? COLLATE NOCASE OR …)`.
    - Each folder is normalised with `trim('/')` + `"/"`.
    - An empty folder list matches nothing (`0`).
  - The query passes `QUERY_ARG_MATCH_PENDING = MATCH_INCLUDE` and `QUERY_ARG_MATCH_TRASHED = MATCH_EXCLUDE`, sorts by `GENERATION_ADDED ASC` and sets `QUERY_ARG_LIMIT`.
  - `fun shotSinceSelection(folders: List<String>, sinceMs: Long): Pair<String, Array<String>>` uses the same folder clause AND `(DATE_TAKEN >= ? OR DATE_ADDED >= ? OR DATE_MODIFIED >= ? OR DATE_ADDED IS NULL)`, with seconds for the last two (`sinceMs / 1000`, rounded down). Pending rows are excluded.
  - `fun idsSelection(ids: List<Long>)` builds `_ID IN (?,…)` with at most 500 ids. The impl chunks larger lists.
  - `fun rowFrom(cursor: Cursor, volumeName: String): VideoRowMsg`
    - It reads columns by name.
    - A null `DURATION`, `DATE_TAKEN`, `WIDTH`, `HEIGHT` or `MIME_TYPE` stays null.
    - `IS_PENDING` 1 becomes true.
- `interface Volumes { fun names(): Set<String>; fun version(volume: String): String?; fun generation(volume: String): Long }`, with the real `MediaStoreVolumes(context)`.
  - `version` returns null, never throws, when the volume is unmounted or `getVersion` throws `IllegalArgumentException`/`IllegalStateException`.
  - `volumes()` lists `MediaStore.getExternalVolumeNames`, and the impl skips any volume whose `generation` throws.
- `object Thumbnails`
  - `fun load(resolver, uri, w, h): ByteArray?`
  - It returns JPEG at quality 85, scaled down so its longer side is ≤ max(w, h), because `loadThumbnail` may return a bigger bitmap.
  - It returns null on `FileNotFoundException`, `IOException`, `SecurityException` or `OperationCanceledException`. Any other exception goes back to Dart as an error.
- `class ZoneChangeStore(prefs: SharedPreferences)`
  - `fun record(atMs: Long, zoneId: String)` appends only when `zoneId` differs from the last entry, and keeps at most 500 entries by dropping the oldest.
  - `fun pending(): List<ZoneChangeMsg>` and `fun clearUpTo(atMs: Long)`.
  - It is stored as a JSON array under one key in `taketray_native` prefs. Corrupt JSON reads as empty and is overwritten on the next record.
- `TimeZoneChangedReceiver` is a manifest receiver for `ACTION_TIMEZONE_CHANGED`, which is exempt from the implicit-broadcast limits. It records `(System.currentTimeMillis(), TimeZone.getDefault().id)`.
- `MainActivity`
  - `configureFlutterEngine` calls `MediaHostApi.setUp(messenger, MediaHostApiImpl(this))`.
  - `requestAccess` uses `requestPermissions`/`onRequestPermissionsResult` with one pending callback. A second request while one is pending fails with `PlatformException("busy")`.
  - After the result, `canAskAgain` is `shouldShowRequestPermissionRationale(first permission)` when not full, and true when full.
  - `openAppSettings` starts `ACTION_APPLICATION_DETAILS_SETTINGS` for this package.
  - `openVideoCamera` starts `MediaStore.INTENT_ACTION_VIDEO_CAMERA`, returning false on `ActivityNotFoundException`.
- Threading: every `@async` method runs on one background `Executor` and replies on the main thread.
- `DebugHooks.register(engine)`: an empty object in `src/release` and `src/profile`. Task 11 fills in the debug one. Call it from `configureFlutterEngine` now.

- [ ] **Step 1: Set up Robolectric and write the failing tests**

  Add `testImplementation` for `junit:junit:4.13.2`, `org.robolectric:robolectric:4.17` and `androidx.test:core`, with `testOptions.unitTests.isIncludeAndroidResources = true`. `tool/test_android` runs `cd app/android && ./gradlew :app:testDebugUnitTest --console=plain`. If Gradle needs `local.properties`, it first runs `tool/flutter build apk --debug --config-only`.

  Tests (named exactly):
  - `MediaAccessCheckerTest`, which covers:
    - `level` for each SDK 30, 32, 33, 34, 35 × each grant combination, including "34 with only VISUAL_USER_SELECTED is limited" and "33 with READ_EXTERNAL_STORAGE only is denied"
    - `permissionsToRequest` for 30, 33 and 34
  - `VideoQueriesTest`, which covers:
    - the selection and args for one folder and for two folders
    - trailing and leading slashes are normalised
    - an empty folder list matches nothing
    - `shotSinceSelection` args are ms for DATE_TAKEN and whole seconds for the other two (`sinceMs` 1 999 → 1)
    - `idsSelection` at 1 and 500 ids, and that 501 is refused
    - `rowFrom` on a `MatrixCursor` with every column null-able column null, and again with all set
    - `isPending` mapping
  - `ZoneChangeStoreTest` (Robolectric prefs), which covers:
    - the same zone is not appended twice in a row
    - A→B→A gives 3 entries
    - the cap at 500 drops the oldest
    - `clearUpTo` keeps later entries
    - corrupt JSON reads as empty, and the next record works
  - `ThumbnailsTest`, which covers:
    - a resolver that throws `FileNotFoundException` → null
    - `SecurityException` → null
    - a 1024×768 bitmap with a 256 request → the longer side is ≤ 256
  - `VolumesTest`: a `version` that throws gives null.

  Run `tool/test_android`. Expected: FAIL (classes missing).

- [ ] **Step 2: Implement the Kotlin side, the manifest permissions and the receiver**

  Then run `tool/test_android` again. Expected: PASS.

- [ ] **Step 3: Add Android tests to `tool/check` and CI**

  - `tool/check` gets the step `android unit tests` (`tool/test_android`) after the Flutter tests.
  - `check.yml` gets:
    - `actions/setup-java@v4`, Temurin 17
    - a Gradle cache (`~/.gradle/caches`, `~/.gradle/wrapper`, keyed on `app/android/**/*.gradle.kts` and `gradle-wrapper.properties`)
    - `ANDROID_HOME` from the runner image

  If CI time grows by more than 6 minutes, record it in the decision and in `docs/later.md` for Phase 11.

- [ ] **Step 4: Turn on the permission list in `tool/check_release_permissions`**

  Run it: it must pass. Then prove it bites: remove `maxSdkVersion` from `READ_EXTERNAL_STORAGE` and confirm the check fails, then revert.

- [ ] **Step 5: Update the docs, commit and push; CI must be green**

  - Add **D-66, Android unit tests**: Robolectric in `tool/check` and CI, for the logic that depends on the Android version, because the emulators are still deferred (D-32).
  - Add **D-67, the permission model**: the three levels per SDK, requesting both media permissions together on 34+, and `canAskAgain`.
  - Fill in learning-guide Section 4, which covers how Android asks for video access on 11–12, 13 and 14+, and what "a thin native pipe" means.
  - Commit as `feat(android): Kotlin media bridge, permissions, zone receiver, Android unit tests`.

**Edge cases:** an unmounted SD card (`version` null), a second permission request while one is pending, a gone thumbnail, a cursor with nulls, the zone store cap, and over 500 ids. Mutation checks to report: flip `>` to `>=` in the generation selection (`VideoQueriesTest` catches it), and drop the API 34 limited branch (`MediaAccessCheckerTest` catches it).

---

### Task 5: Pure media rules (critical, Opus)

**Model:** Opus.

**Files:**
- Create: `app/lib/domain/rules/{clip_date,media_clip,baseline,fingerprint_match}.dart`
- Create the tests in `app/test/domain/rules/`
- Modify: the doc comments in `app/lib/domain/models/clip.dart` and `clip_fingerprint.dart` (point them at `shotAt`), `docs/later.md`, `docs/decisions.md`

**Interfaces (produced):**
- `DateTime shotAt(MediaVideo v, {required DateTime now})` returns the UTC shooting time:
  - `dateTakenMs` if it is plausible
  - else `dateAddedSec * 1000` if plausible
  - else `dateModifiedSec * 1000` if plausible
  - else `now`

  A value is plausible when it is ≥ 0 (1970-01-01) and ≤ `now + 1 day`. This is the R4g rule plus the clamp.
- `NewClip newClipFrom(MediaVideo v, {required DateTime now, required String? zoneId})` gives `NewClip.mediaStore` with:
  - fingerprint `(sizeBytes, durationMs ?? 0, shotAt(v), displayName)`
  - width/height `?? 0`
  - `mimeType`
  - `generationAdded`
  - `timeZoneId: zoneId`
- `sealed class VolumePlan`: `StartFromNow`, `SkipVolume` (unmounted), `Resync` and `ScanAfter(int generation)`.
  - `VolumePlan planVolume(VolumeBaseline? baseline, MediaVolume current)` decides, in this order:
    1. not mounted → `SkipVolume`
    2. no baseline → `StartFromNow`
    3. version differs → `Resync`
    4. `current.generation < baseline.generation` → `Resync`, as a defence
    5. otherwise → `ScanAfter(baseline.generation)`
- `bool isUsable(MediaVideo v)` is `!v.isPending && (v.durationMs ?? 0) > 0`.
- `int advanceBaseline({required int from, required int captured, required List<MediaVideo> seen})`:
  - With a pending row in `seen`: `max(from, minPendingGenerationAdded - 1)`.
  - Otherwise: `max(from, captured, max(seen.generationAdded))`.
  - It never returns less than `from`.
- `bool sameVideo(ClipFingerprint f, MediaVideo v, {required DateTime now})`
  - True when `f.sizeBytes == v.sizeBytes`, `f.durationMs == (v.durationMs ?? 0)` and `f.dateTakenUtc == shotAt(v, now: now)`.
  - The display name is ignored, because a rename is still the same video.
- `class RebuildMatch { Map<int, int> remap; Set<int> lost; }`, keyed by clip id and mapping to the new MediaStore id.
  - `RebuildMatch matchAfterRebuild(List<Clip> stored, List<MediaVideo> current, {required DateTime now})`:
    1. Candidates are the usable videos where `sameVideo` holds.
    2. With more than one candidate, keep those with an equal `displayName`.
    3. A clip with exactly one candidate claims it.
    4. A video claimed by two or more clips is given to none of them (all become `lost`).
    5. Every other clip is `lost`.
    6. Every stored clip ends in exactly one of `remap` or `lost`.
- `enum EarlierRange { today, lastTwoDays, lastSevenDays }`.
  - `DateTime earlierWindowStart(EarlierRange r, DateTime nowLocal)` counts calendar days in the phone's local time:
    - `today` → local midnight of today
    - `lastTwoDays` → local midnight of yesterday
    - `lastSevenDays` → local midnight six days ago

    It returns the result in UTC and uses `DateTime(y, m, d - n)`, so daylight-saving days are right. (Ruling: creators think "yesterday and today", not "48 hours".)
  - `bool shotInWindow(MediaVideo v, DateTime startUtc, {required DateTime now})` is `!shotAt(v, now: now).isBefore(startUtc) && isUsable(v)`.

- [ ] **Step 1: Write the failing tests**

  - `clip_date_test.dart`:
    - `uses DATE_TAKEN when plausible`
    - `falls back to DATE_ADDED when DATE_TAKEN is null`
    - `… when DATE_TAKEN is before 1970` (−1 ms)
    - `… when DATE_TAKEN is a QuickTime-epoch value (1904)`
    - `… when DATE_TAKEN is more than a day ahead` (now + 1 day + 1 ms falls back; now + 1 day exactly is kept)
    - `falls back to DATE_MODIFIED when DATE_ADDED is also bad`
    - `uses now when all three are bad or null`
    - `result is UTC`
  - `media_clip_test.dart`:
    - `null duration and size map to 0`
    - `null mime type is video/*`
    - `zone id passed through`
    - `identity is volume + id`
  - `baseline_test.dart`:
    - each of the five `planVolume` branches
    - `version compared by equality only` (two different strings of equal length → `Resync`)
    - `advanceBaseline`:
      - `no rows → captured`
      - `rows beyond captured → max row`
      - `holds before the oldest pending row` (pending at 7 and 9, `from` 3 → 6)
      - `never moves backwards` (pending at 2, `from` 5 → 5)
  - `fingerprint_match_test.dart`:
    - `sameVideo ignores display name`
    - `sameVideo rejects one byte off / one ms off`
    - `matchAfterRebuild`:
      - `single candidate remaps`
      - `two candidates, one same name → remap to that one`
      - `two candidates, both same name → lost`
      - `two clips claim one video → both lost`
      - `pending or zero-duration candidates ignored`
      - `no candidate → lost`
      - `every stored clip is in exactly one set` (a property loop over 200 seeded random cases)
  - `earlier_window_test.dart`:
    - `today starts at local midnight`
    - `last 2 days starts at yesterday's midnight` (at 00:05 and at 23:55)
    - `last 7 days spans a month and a year boundary` (2027-01-03 → 2026-12-28)
    - `a daylight-saving day still starts at midnight` (run with `TZ=Europe/London` for the 2026-10-25 change; see Step 2)
    - `shotInWindow`:
      - `includes exactly the start`
      - `excludes 1 ms before`
      - `uses the fallback date when DATE_TAKEN is junk`
      - `excludes pending and zero-length`

- [ ] **Step 2: Implement and run the tests**

  Run `cd app && ../tool/flutter test test/domain`. Expected: PASS. Also run the DST test once with `TZ=Europe/London ../tool/flutter test test/domain/rules/earlier_window_test.dart`. That test must skip itself, with a reason, when the zone is not London, so `tool/check` passes in any zone.

- [ ] **Step 3: Update the docs, run `tool/check`, commit and push**

  - Add **D-68, shooting date and same-video rules**. It covers the clamp, the fallback order, which fingerprint fields count and why the display name doesn't, and the rule "ambiguous → missing".
  - Add **D-69, the per-volume baseline plan**. It covers the pending hold, "no baseline → from now" (this also covers after an import), and an unmounted volume being skipped.
  - Delete the two date lines and the "missing baseline" line from `docs/later.md`.
  - Fill in learning-guide Section 5, using the life of a new video as a worked example: a generation number, a pending row, a baseline.
  - Commit as `feat(domain): shooting date, baseline and same-video rules`.

**Mutation checks to report:** remove the pending branch of `advanceBaseline`, and drop the "claimed twice" rule in `matchAfterRebuild`.

---

### Task 6: Phone state and the new clip writes

**Model:** Sonnet.

**Files:**
- Create: `app/lib/data/repositories/phone_state_repository.dart` and its test
- Modify: `clips_repository.dart`, `zone_repository.dart`, `backup_format.dart` (only if a test shows a negative `mediaStoreId` is refused), and their tests; `docs/later.md`, `docs/decisions.md`, `docs/flow.md` ("Tagging data changes")

**Interfaces (produced):**
- `PhoneStateRepository(AppDatabase, Clock)` and `phoneStateRepositoryProvider` (keep-alive). It uses the `settings` table under keys `shootingMode` and `mediaAccessWasFull`. Neither key is ever in `SettingsRepository.exportedKeys`.
  - `Future<ShootingState> loadShooting()`
  - `Stream<ShootingState> watchShooting()` emits distinct values. A missing or corrupt value reads as `ShootingState.off`, and only the key name is logged.
  - `Future<ShootingState> turnShootingOn(Map<String, VolumeBaseline> baselines)` sets `since` = now. If Shooting mode is already on, it returns the current state unchanged.
  - `Future<void> turnShootingOff()`
  - `Future<bool> advanceBaseline(String volume, {required ShootingState expectedSession, required VolumeBaseline? expected, required VolumeBaseline next})` is a compare-and-set in one transaction. It writes only when all of these hold:
    - Shooting mode is on with the same `since` as `expectedSession`.
    - The stored baseline for `volume` equals `expected`.
    - `next.generation >= expected?.generation` when the versions match.

    It returns whether it wrote.
  - `Future<bool> accessWasFull()` and `Future<void> markAccessWasFull()`.
  - `Future<void> markEarlierAdded()` sets `earlierAdded` when Shooting mode is on, and does nothing when it is off. `turnShootingOn` always starts with `earlierAdded: false`.
- `ClipsRepository` additions:
  - `Future<List<Clip>> mediaStoreClipsOn(String volumeName)` returns clips with `mediaStoreId > 0`.
  - `Future<void> applyRebuildMatch(String volumeName, RebuildMatch match)` runs in one transaction:
    1. Every clip in `remap` gets `mediaStoreId = -clipId` (a temporary value, so swaps can't clash).
    2. Then each gets its new id, `missing = false` and `lastVerifiedAt = now`.
    3. Every clip in `lost` gets `mediaStoreId = -clipId`, `missing = true` and `lastVerifiedAt = now`.

    If a clip outside the match holds a target id, it throws `StateError` and changes nothing.
  - `Future<void> detach(Set<int> clipIds)` does the same as `lost`. It is used when a verified id now holds a different video.
  - `Future<int> removeMissingFromLists(Set<int> clipIds)` deletes the `inbox` rows of those clips, then runs `deleteOrphanClips`. It returns how many clips were deleted. A clip in a reel is untouched.
- `ZoneRepository.recordAll(Iterable<ZoneEntry> entries)` runs in one transaction:
  1. Read the whole timeline.
  2. Add the entries, cut to milliseconds. An entry at an existing instant replaces it.
  3. Sort by time and drop every entry whose zone equals the one before it.
  4. Rewrite the table.

  `record` stays as it is.

- [ ] **Step 1: Write the failing tests**

  - `phone_state_repository_test.dart`:
    - `off by default`
    - `on stores since=now and baselines`
    - `turning on twice keeps the first since`
    - `off clears baselines`
    - `corrupt JSON reads as off and logs the key only`
    - `phone-state keys are not exported`, which asserts against `SettingsRepository.exportedKeys` and checks that a backup export doesn't contain `shootingMode`
    - `import turns Shooting mode off` (import a fixture over a DB with Shooting mode on)
    - `markEarlierAdded sets the flag, a new session clears it, off ignores it`
    - `advanceBaseline is compare-and-set`, with these cases:
      - it writes on a match
      - it refuses after off/on (the `since` differs)
      - it refuses when the stored baseline changed
      - it refuses when moving backwards
      - it writes for a volume with no baseline when `expected` is null
  - `clips_repository_test.dart` additions:
    - `applyRebuildMatch swaps two ids without a unique clash` (clip A 10→20, clip B 20→10)
    - `lost clips become missing with a negative id`
    - `a detached clip's old id can be detected again as a new clip` (`addDetectedClips` with that id inserts a new row and doesn't find the old one)
    - `applyRebuildMatch fails atomically on an outside clash`
    - `removeMissingFromLists deletes an inbox-only clip and keeps one in a reel`
    - `mediaStoreClipsOn excludes detached and other volumes`
  - `zone_repository_test.dart`:
    - `recordAll merges out of order without losing a later observation` (the D-58 caveat case: London 12th recorded before Kolkata 5th)
    - `recordAll drops repeated neighbours`
    - `recordAll with nothing new changes nothing`
  - `backup_service_test.dart`: `a detached clip (negative mediaStoreId) round-trips`.

- [ ] **Step 2: Implement and run the tests**

  Run `../tool/flutter test test/data`. Expected: PASS.

- [ ] **Step 3: Update the docs, run `tool/check`, commit and push**

  - Add **D-70, phone state and detached clips**. It covers:
    - Shooting mode and baselines live in one key, so they change atomically
    - the compare-and-set baseline
    - a lost clip keeps its row with `mediaStoreId = -id`, so its old number can never match a new video
    - an inbox-only missing clip leaves To tag
  - Update D-58's out-of-order caveat to point at `recordAll`.
  - Delete the matching zone line from `docs/later.md`.
  - Fill in learning-guide Section 6.
  - Commit as `feat(data): phone state, rebuild remap, detach, time-ordered zone merge`.

---

### Task 7: Scanner, verifier and zone sync (critical, Opus)

**Model:** Opus.

**Files:**
- Create: `app/lib/data/media/{media_scanner,media_verifier,zone_sync}.dart` and their tests in `app/test/data/media/`
- Modify: `docs/flow.md` (new "Finding new clips" and "Checking clips still exist" sections), `docs/decisions.md`

**Interfaces (produced):**
- `MediaScanner(MediaBridge, ClipsRepository, PhoneStateRepository, SettingsRepository, ZoneRepository, Clock)` and `mediaScannerProvider` (keep-alive).
  - `Future<ScanOutcome> scan()`
  - `sealed ScanOutcome` = `ScanShootingOff` | `ScanNoAccess` | `ScanDone(int added, Set<String> resynced, Set<String> failedVolumes)`
- The scan algorithm:
  1. Load Shooting mode. If it is off, return `ScanShootingOff`.
  2. Read the access level. If it isn't `full`, return `ScanNoAccess` and touch nothing. Otherwise call `markAccessWasFull`.
  3. Load the watched folders and the zone timeline once.
  4. For each `volumes()` entry, call `planVolume`:
     - `SkipVolume`: nothing.
     - `StartFromNow`: `advanceBaseline(expected: null, next: current)`.
     - `Resync`: run `allVideos`, then `matchAfterRebuild` against `mediaStoreClipsOn`, then `applyRebuildMatch`, then advance the baseline to `(current.version, current.generation)` with compare-and-set against the stored one. **Add no clips.**
     - `ScanAfter(g)`: page `videosAddedAfter(g, folders, 500)`. The next page starts after the last row's `generationAdded`, and paging stops at a short page. Then:
       1. Turn the usable rows into `newClipFrom(zoneId: zoneAt(timeline, shotAt) ?? currentZoneId)` and call `addDetectedClips`.
       2. **Only after that succeeds**, advance the baseline to `advanceBaseline(from: g, captured: current.generation, seen: allRows)`, with compare-and-set.
  5. A `PlatformException` on one volume is logged by volume name and the volume is added to `failedVolumes`. Its baseline is untouched, and the other volumes still run.
- **Coalescing:**
  - If a scan is running, `scan()` returns a future for one more scan that starts after it.
  - Any number of calls during one run share that single follow-up.
  - Calls never run in parallel.
- **Add earlier videos** (owner request), on `MediaScanner`:
  - `Future<Map<EarlierRange, int>> countEarlier()` and `Future<List<int>> addEarlier(EarlierRange range)`.
  - Both run through the same serial queue as `scan()`, so they never overlap a scan, and both need full access. Without it, `addEarlier` throws `StateError` and `countEarlier` returns zeros.
  - Steps:
    1. On every mounted volume, call `videosShotSince(folders, earlierWindowStart(lastSevenDays))` once.
    2. Narrow the rows with `shotInWindow`.
    3. Drop videos whose identity is already stored. These are known ids from `mediaStoreClipsOn`, so tagged, skipped and pending clips never come back.
  - `countEarlier` returns the count per range. `addEarlier` calls `addDetectedClips` for that range and then `markEarlierAdded`, and returns the ids of the clips it inserted, for Undo.
  - Baselines are never read or written.
- `MediaVerifier(MediaBridge, ClipsRepository, Clock)` and its provider.
  - `Future<VerifyOutcome> verify(Iterable<Clip> clips)`, where `VerifyOutcome(found, missing, skipped)`. Steps:
    1. If access isn't `full`, everything is `skipped` and nothing is written.
    2. Picker clips and detached clips (`mediaStoreId <= 0`) are skipped.
    3. Clips on unmounted or unknown volumes are skipped.
    4. The rest are grouped by volume and sent to `videosByIds` in chunks of 500. A returned row that passes `sameVideo` is found. A returned row that fails it is detached (counted as missing). A row that isn't returned is missing.
    5. Then `recordVerification(found, missing-not-detached)` runs, followed by `removeMissingFromLists(all missing)`.
  - `Future<VerifyOutcome> verifyAll()` checks every clip. Phase 10's "X of Y clips found" after an import uses it.
- `ZoneSync(MediaBridge, ZoneRepository, Clock)`: `Future<void> sync()`.
  1. `recordAll(pendingZoneChanges + (now, currentZoneId))`.
  2. Then `clearZoneChangesUpTo(max atMs)`, only after `recordAll` succeeded.

- [ ] **Step 1: Write the failing tests**

  These use `FakeMediaBridge` and a test DB.

  **Scanner:**
  - `off → ScanShootingOff, no bridge media calls`
  - `scan does nothing without full access` (limited, then denied); the baselines are unchanged
  - `first scan after turning on starts from now` (existing videos are not added)
  - `new camera video lands in To tag with its zone`
  - `video outside watched folders is ignored but baseline passes it`
  - `pending video appears on the next scan` (pending at scan 1, finished at scan 2 → added once)
  - `zero-duration video is never added`
  - `version change resyncs, adds nothing` (Review Focus 3: 50 videos in the "new" library → 0 added; stored clips remapped)
  - `paging: 1200 new videos → all added, baseline at the last`
  - `a failing volume keeps its baseline, others proceed`
  - `addDetectedClips failure leaves baseline unmoved` (inject a DB failure)
  - `concurrent scans coalesce` (three calls during one paused run → exactly two runs, in order)
  - `scan started before off/on cannot write the new session's baseline` (pause after the query, toggle off/on, resume → the new session's baseline is untouched and the clips from that scan aren't from the off period)
  - `after an import (no baseline) scan starts from now`
  - `log lines carry no display name or folder` (capture the records)

  **Add earlier videos:**
  - `counts per range exclude known clips`, where the known clips are one tagged, one skipped and one pending in the window
  - `addEarlier(today) adds only today's new videos and returns their ids`
  - `a tagged clip in the window does not return to To tag`
  - `a skipped clip stays skipped`
  - `addEarlier does not move any baseline`
  - `addEarlier while a scan runs waits for it, and the video is added once`
  - `without full access: count is zeros, add throws StateError`
  - `pending and zero-length videos in the window are not counted`
  - `works with Shooting mode off and leaves earlierAdded false`

  **Verifier:**
  - `verifier skips without full access`
  - `found / missing / detached sorting`
  - `unmounted volume is skipped`
  - `missing inbox clip leaves To tag, missing reel clip is flagged`
  - `1201 ids → 3 batches`
  - `detached clips are skipped`
  - `verifyAll counts`

  **Zone sync:**
  - `merges native changes then clears`
  - `does not clear when recordAll throws`
  - `current zone recorded at now`

- [ ] **Step 2: Implement and run the tests**

  Run `../tool/flutter test test/data/media`. Expected: PASS.

- [ ] **Step 3: Update the docs, run `tool/check`, commit and push**

  - Add **D-71, scan and verify**. It covers:
    - the triggers (Task 10 wires start, resume and opening To tag)
    - only with full access
    - coalescing
    - the baseline moves after the insert
    - the verifier never runs on partial access
    - an unmounted volume is left alone
  - Add **D-72, Add earlier videos (owner request)**. It covers:
    - the placement (a card link plus To tag's menu), chosen over asking at every turn-on or a setting
    - calendar-day windows in local time
    - known clips are never re-added, and the baselines are never touched
    - full access only

    The thumbnail decision in Task 8 then takes the next number.
  - Add three `docs/flow.md` sections ("Finding new clips", "Checking clips still exist", "Adding earlier videos"), each a step list with what is read and written.
  - Fill in learning-guide Section 7, with a Mermaid sequence diagram of one scan.
  - Commit as `feat(data): media scanner, verifier and zone sync`.

**Mutation checks to report:** advance the baseline before `addDetectedClips`, drop the access check in `verify`, and remove coalescing (run in parallel).

---

### Task 8: Thumbnails

**Model:** Sonnet.

**Files:**
- Create: `app/lib/data/media/thumbnail_cache.dart`, `app/lib/features/clips/widgets/clip_thumbnail_image.dart`, and tests

**Interfaces (produced):**
- `ThumbnailCache(MediaBridge, Directory dir, {int maxBytes = 64 * 1024 * 1024})` and `thumbnailCacheProvider`, using `getApplicationCacheDirectory()/thumbs`.
  - `Future<Uint8List?> load(Clip clip, int sizePx)` works like this:
    1. The disk file is named `<volume>_<mediaStoreId>_<sizeBytes>_<dateTakenMs>_<sizePx>.jpg`, so a renumbered id or a changed video never reuses a picture.
    2. On a disk hit, it returns the bytes and touches the mtime.
    3. On a miss, it calls `bridge.thumbnail`. If the result isn't null, it writes a temp file and renames it into place.
    4. It returns null for detached or picker clips, for a null result, or for a `PlatformException`.
  - Concurrent loads of one key share one bridge call.
  - `Future<void> prune()` deletes the oldest files by mtime until the total is ≤ `maxBytes`. It runs once at app start (Task 10).
- `class ClipThumbnailImage extends ImageProvider<ClipThumbnailKey>`:
  - It takes a clip and a logical size, and multiplies the size by the device pixel ratio from `ImageConfiguration`.
  - Null bytes give an image error, which the tile shows as its placeholder.
  - The key equality uses the same fields as the file name.

- [ ] **Step 1: Write the failing tests**

  - `disk hit avoids the bridge`
  - `cache key changes when the fingerprint changes`
  - `null thumbnail is not cached`
  - `PlatformException → null`
  - `two concurrent loads → one bridge call`
  - `prune removes oldest first down to the cap`
  - `partial write never leaves a corrupt file` (the temp-and-rename write: kill it between the two steps)
  - `provider resolves to an image at dpr 3` (widget test)

- [ ] **Step 2: Implement, run, update the docs, commit and push**

  - Add the next free decision (**D-73**), the thumbnail cache: the key, the 64 MB cap, and pruning at start.
  - Fill in learning-guide Section 8.
  - Commit as `feat(data): thumbnail disk cache and image provider`.

---

### Task 9: View models and app lifecycle

**Model:** Sonnet.

**Files:**
- Create: the three view models listed in the file structure, `app/lib/app/media_lifecycle.dart`, and tests
- Modify: `app/lib/app.dart`

**Interfaces (produced):**
- `MediaAccessController` (`AsyncNotifier<MediaAccessView>`) produces `MediaAccessView(level, banner, canAskAgain)`.
  - `enum AccessBanner { none, manual, lost }`. The rule:
    - full → none
    - limited → manual
    - denied with `accessWasFull` → lost
    - denied without it → manual
  - `Future<void> allow()`:
    - When `canAskAgain` is true or the level is limited, it calls `requestAccess`. If the result is full, it marks `accessWasFull` and starts a scan.
    - Otherwise it calls `openAppSettings`.
  - `Future<void> refresh()` re-reads the access level.
- `ShootingModeController` (`AsyncNotifier<ShootingState>`) watches `watchShooting`.
  - `Future<void> setOn(bool on)`:
    - Turning on:
      1. If access is denied and `canAskAgain`, request access first.
      2. Then `turnShootingOn` with the current mounted volumes as baselines, or `{}` if `volumes()` throws.
      3. Then scan.
    - Turning off calls `turnShootingOff` and leaves To tag alone.
  - `Future<bool> openCamera()`.
- `EarlierVideosController` (`AutoDisposeAsyncNotifier<Map<EarlierRange, int>>`) loads `countEarlier()` when the sheet opens.
  - `Future<List<int>> add(EarlierRange r)` returns the new ids.
  - `Future<void> undo(List<int> ids)` calls `removeMissingFromLists(ids.toSet())`, which removes just-added clips from To tag. They are pending inbox-only clips, so the orphan sweep deletes them.
- `ToTagController` (`AsyncNotifier<List<Clip>>`) watches `watchInbox(pending)`. On build, it scans and then verifies the pending clips once. `onResume()` repeats both.
- `MediaLifecycle` is a widget placed in `TakeTrayApp` above the router. It uses `AppLifecycleListener`:
  - On first frame: `ZoneSync.sync`, then `MediaAccessController.refresh`, then `MediaScanner.scan`, plus `ThumbnailCache.prune`, all unawaited and with errors logged.
  - On resume: the same, without the prune.
  - Errors never reach the UI.

- [ ] **Step 1: Write the failing tests**

  These use provider overrides with `FakeMediaBridge`:
  - `banner rule for each level × wasFull`
  - `allow requests when it can ask, opens settings when it can't`
  - `allow on limited re-requests`
  - `granting full triggers one scan`
  - `turning on with denied access asks first, then turns on even if still denied`
  - `turning on records mounted volumes only`
  - `turning on twice is a no-op`
  - `off keeps To tag`
  - `To tag scans then verifies on open`
  - `lifecycle runs zone sync before scan on start and on resume`
  - `a throwing scan is logged, not surfaced`
  - `earlier: counts load, add returns ids, undo removes exactly those and leaves older To tag clips`

- [ ] **Step 2: Implement, run, update the docs, commit and push**

  - Add **D-74, the access banner rule and the Shooting-on flow**.
  - Add a "App start and resume" section to `docs/flow.md`.
  - Fill in learning-guide Section 9.
  - Commit as `feat: access, Shooting mode and To tag view models; lifecycle triggers`.

---

### Task 10: To tag v1, the Shooting mode card and the access banner

**Model:** Sonnet.

**Files:**
- Create: `to_tag_screen.dart`, `shooting_mode_section.dart`, `media_access_banner.dart`, and widget tests
- Modify: `app/lib/l10n/app_en.arb`, `app/lib/router/app_router.dart` (To tag route → `ToTagScreen`), `reels_placeholder_screen.dart` (the Shooting section at the top)
- Delete: `to_tag_placeholder_screen.dart`

**Exact copy** (from `design/prototype/assets/screens.js`), as ARB keys with placeholders:

| Where | Text |
|---|---|
| Banner, manual | **Manual mode** · New clips aren't found automatically. · button **Allow full access** |
| Banner, lost | **TakeTray can't see your videos** · Allow access to find new clips. · button **Allow** |
| Card, off | **Shooting mode** · Off. Turn on before you start filming, and new videos wait in To tag. |
| Card, on | **Shooting mode on** · On since {time} · with " · Manual mode: add clips yourself" when access isn't full · **Open camera** |
| Card strip | {count, plural, one{1 clip} other{{count} clips}} to tag · Tag now |
| Switch label | Shooting mode |
| To tag strip, on | Shooting since {time} · **Open camera** |
| To tag strip, off with clips | Shooting mode off · **Turn on** |
| Empty, on | **All caught up** · New clips you shoot will show up here. · **Open camera** |
| Empty, off | **Nothing to tag** · Turn on Shooting mode before you start filming. New videos will show up here. · **Turn on Shooting mode** |

**Add earlier videos.** This copy is new; the owner approved the feature on 2026-10-28, and it goes in the decision:

| Where | Text |
|---|---|
| Card link (on, full access, not used yet this session) | Add earlier videos |
| To tag ⋮ menu item (full access only) | Add earlier videos |
| Sheet title · subtitle | **Add earlier videos** · From your camera folders. Clips you already tagged or skipped stay where they are. |
| Rows | Today · Last 2 days · Last 7 days, each trailing {count, plural, =0{none} one{1 new} other{{count} new}}; a row with 0 is disabled |
| Snack after adding | {count, plural, one{1 clip added to To tag} other{{count} clips added to To tag}} · Undo |

Build the sheet from `TtSheet` and the list-row components. The counts show skeleton placeholders while loading.

`{time}` uses `DateFormat.jm` in the device locale. "Add videos" (Phase 7), Skipped (Phase 5), scenes and the summary row (Phase 5) are not built. The doc comment of `ToTagScreen` says so.

**Screen behaviour:**
- **To tag:** a large app bar "To tag", then the banner (if any), the strip, then a three-column grid of `TtClipTile` in shooting order with `ClipThumbnailImage` and the duration. Tapping a tile does nothing yet. The empty states are as in the table.
- **Reels tab:** `ShootingModeSection` uses `TtShootingModeCard`, with the latest pending clip's thumbnail as the backdrop when there is one, then the banner below it.
- The style rules hold: no raw values in feature code.

- [ ] **Step 1: Write the failing widget tests**

  - To tag:
    - `shows the banner for each AccessBanner`
    - `empty on / empty off states`
    - `grid lists pending clips oldest first`
    - `strip on / off`
    - `Turn on Shooting mode calls setOn(true)`
    - `Allow calls allow()`
  - Reels tab:
    - `card off / on texts`
    - `on with limited access adds the Manual mode suffix`
    - `strip shows the count and opens To tag`
    - `Open camera calls openCamera`
  - Add earlier videos:
    - `card link shows only when on, full access, and not used yet`
    - `To tag menu item hidden in Manual mode`
    - `sheet shows counts; a zero row is disabled`
    - `tapping Last 2 days adds and shows the snack with the right count`
    - `Undo removes them`
  - Both screens:
    - `at 2× text nothing overflows`
    - `expectTtAccessible` (tap targets, labels, contrast)
  - `l10n` test: every new key has a non-empty English value.

- [ ] **Step 2: Implement, run `tool/check`, update the docs, commit and push**

  - Add **D-75, the first To tag screen and the Shooting card's place before Phase 4/5**.
  - Fill in learning-guide Section 10.
  - Commit as `feat(ui): To tag v1, Shooting mode card, access banner`.

---

### Task 11: On the S24 (needs the phone and the owner's go)

**Model:** Sonnet, with me watching the phone steps.

**Files:**
- Create: `app/android/app/src/debug/kotlin/app/taketray/DebugHooks.kt`, `app/patrol_test/fixtures/test_video.dart`, `tool/make_test_video`, `app/patrol_test/media_access_test.dart`, `app/patrol_test/media_scan_test.dart`
- Modify: `tool/check_release_permissions` (assert `TestMedia` classes are absent from the release dex), `docs/dev-setup.md` ("Phase 3 check"), `docs/flow.md` ("On-device test")

**Interfaces:**
- **Debug `DebugHooks`:**
  - Registers the method channel `app.taketray/test_media` with `insertVideo(bytes, displayName)` → `{volumeName, mediaStoreId}` and `deleteVideo(mediaStoreId)`.
  - `insertVideo` inserts into `Movies/TakeTray Test/` with `IS_PENDING` 1, writes the bytes, then sets `IS_PENDING` 0.
  - The files belong to `app.taketray.dev`, so deleting them needs no consent dialog.
- `tool/make_test_video` makes a two-second 160×90 H.264 MP4 with ffmpeg (a test pattern, no audio) and writes `patrol_test/fixtures/test_video.dart` as a base64 constant.

- [ ] **Step 1: Write the Patrol tests**

  `media_access_test.dart`, on a fresh install (`clearPackageData`):
  1. To tag shows the "Manual mode" banner.
  2. Tap **Allow full access**, then tap the system dialog's allow-all button with `$.platform.mobile.grantPermissionWhenInUse()`. If One UI doesn't match, find its id with `getNativeViews` and tap it by resource name.
  3. The banner is gone.

  `media_scan_test.dart`:
  1. Grant access the same way. Set the watched folders to `['Movies/TakeTray Test']` through `SettingsRepository`, so the scan never returns the owner's videos.
  2. Turn Shooting mode on and insert the test video.
  3. Open To tag. Expect exactly one tile, with its thumbnail resolved (the `ClipThumbnailImage` completes without error).
  4. Delete the video, resume the app and expect To tag to be empty (the clip left the list).
  5. Add earlier videos:
     1. Turn Shooting mode off and insert a second test video.
     2. Open To tag's ⋮ menu, then **Add earlier videos**. **Today** shows "1 new". Tap it, and To tag shows that one tile.
     3. Tap **Undo**, and it is gone.
  5. `tearDown` always deletes any video the test inserted.

- [ ] **Step 2: Release check**

  `tool/check_release_permissions` also fails if the release APK's dex contains `TestMedia` or `test_media`. Check with `dexdump` from the build-tools, or by grepping `classes*.dex` with `unzip -p`. Prove it bites by temporarily calling the debug hook from `main`.

- [ ] **Step 3: Run it all**

  Expected:
  - `tool/check` passes.
  - `tool/check_release_permissions` passes.
  - `tool/patrol test -d RZCY80PHWCZ` passes all Patrol tests (old and new) and installs only **TakeTray Dev**.
  - `tool/adb shell pm list packages app.taketray` still shows both apps.
  - The release TakeTray is reinstalled and opens.

- [ ] **Step 4: Owner check (add it to `docs/dev-setup.md` as "Phase 3 check")**

  The owner does this on the S24, in **TakeTray Dev**:
  1. On the To tag tab, tap **Allow full access** and choose **Allow all**.
  2. On the Reels tab, turn **Shooting mode** on.
  3. Tap **Open camera** and film two short videos.
  4. Come back to TakeTray. Both appear in To tag with thumbnails, oldest first.
  5. Delete one in the Gallery app, then come back. It leaves To tag.
  6. Tap **Add earlier videos** on the card, then **Last 2 days**. Videos you filmed yesterday and today appear, and the two from step 3 aren't added twice.
  7. In Android Settings → Apps → TakeTray Dev → Permissions → Photos and videos, choose "Always ask" or "Don't allow". Come back: the banner says Manual mode, and the other clip is still there.

- [ ] **Step 5: Update the docs, commit and push**

  - Add **D-76, test videos on the phone**: debug-only, own folder, deleted in `tearDown`, and absent from the release build.
  - Fill in learning-guide Section 11.
  - Commit as `test(device): Patrol media access and scan on the S24; Phase 3 check`.

---

### Task 12: Finish the learning guide and the README

**Model:** Sonnet.

**Files:** modify `docs/learn/phase-3-media-bridge.md` and `README.md`.

- [ ] **Step 1: Make the guide read as one**

  - Read the whole guide and the code it points to.
  - Even out the voice and remove repetition.
  - Make every path and snippet match HEAD.
  - Fill in the Glossary: MediaStore, volume, generation, version, baseline, IS_PENDING, fingerprint, detached clip, Pigeon, host API, Robolectric, compare-and-set, coalescing, Manual mode and others.
  - Write "What's next".
  - Run every "try it yourself" command.

- [ ] **Step 2: Update the README**

  - Phase 3 becomes ✅ Done and Phase 4 becomes Next.
  - Add a "Phase 3: Finding your videos" bullet list in the style of Phases 0–2, with a link to the guide.
  - Add `app/pigeons/` and the Kotlin `media/` folder to the project map.

- [ ] **Step 3: Commit and push**

  Commit as `docs: Phase 3 learning guide and README progress`.

---

## After the tasks

1. **Final whole-branch review** (Opus) against this plan, the spec and the Review Focus. One fix wave, then a scoped re-review.
2. **Green CI on the branch**, then the owner's phone check (Task 11 Step 4), if it wasn't done during Task 11.
3. **Pull request** `phase-3-media-bridge` → `main`. The title is "Phase 3: Android media bridge". The body lists what was built, the decisions (D-63 to the last one), the check results and the owner check, and ends with the Claude Code attribution line. It must be green. The owner approves, then it is merged and the branch is deleted (D-63).
4. **Known gaps, written into `docs/later.md`:**
   - Phase 6 reuses `ZoneChangeStore` and the baseline keys for the background job, so it must write the baselines to native state through BackgroundApi.
   - Phase 10's onboarding replaces "Turn on → ask for access".
   - The Play Console video-permission declaration (Phase 11). The research rates approval at about 50/50; the case to make is continuous detection of new camera clips, which the one-off photo picker cannot do. Manual mode already works without the permission.
