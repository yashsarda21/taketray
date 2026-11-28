# Phase 13: photos in reels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user add the 2 or 3 photos a reel needs from inside that reel, through Android's photo picker, and have them sit among the videos in shooting order and go to VN, CapCut, Edits or Other app… with the videos in one hand-off.

**Architecture:**
- **A photo is a clip** (a `clips` row with `source = picker` and an `image/…` type, `durationMs = 0`). One getter, `Clip.isPhoto`, tells it apart. Ordering, reel membership, verifying, the dock, Undo and backups already work on clips, so they carry photos with tests and no new paths (Task 1).
- **Built before the phone is free** (Tasks 1–4): the model, **Add photos** (the picker for `image/*`, the service, the reel page's button), how a photo looks and counts (the tile's photo symbol, TalkBack, the reel header, Home's card, the editor sheet's title, the dock's Edit), and the viewer's photo page (a still decoded natively, downscaled to the screen).
- **Task 5: the four S24 spikes** with the owner, on throwaway code. Their answers choose the copy root (`Pictures`, or `DCIM` if a spike fails), whether a mixed share works, and whether HEIC needs converting.
- **Then the hand-off** (Tasks 6–11):
  - every new copy goes to `<root>/TakeTray/<folder>/`; the root is recorded per editing session (schema v3), so an edit started before the update stays in `Movies`;
  - the native copy folder, its guard and the copy store learn the root and the Images collection;
  - VN copies photos byte for byte, named in shooting order;
  - shares carry `video/*`, `image/*` or `*/*`;
  - the copy roots stay out of the clips (D-130).
  - Tasks 10 and 11 are built only if a spike says an editor refuses a mixed share or HEIC.
- **Last:** Patrol without a device (Task 12), docs (Task 13), the S24 with the owner (Task 14).

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; drift (schema v3 with committed dumps); Pigeon; Kotlin with Robolectric (`tool/test_android`); gen-l10n; alchemist goldens (package CI set by the "update goldens" workflow, macOS set locally, D-61; app goldens macOS-only, D-97); Patrol 4.10.

**Spec:** `docs/superpowers/specs/2026-11-28-phase-13-photos-design.md` (owner-approved 2026-11-28, option B, copy folder A). Its "(my call)" items are binding, and so are its "Prove first on the S24" and "If a spike fails" sections.

## Global Constraints

- **Branch:**
  - `phase-13-photos` in worktree `.claude/worktrees/phase-13`. It is stacked on `phase-12-ui-refresh` at 5651f80, with the spec at e1084e8. 12B is not merged, and its phone check is pending.
  - Push the branch, CI runs on it, and it merges through a green PR after the owner approves.
- **Dependencies:** "No new packages". No pub package, Gradle dependency or third-party plugin. "Photos are drawn through the existing thumbnail bridge, and the viewer's full-size still is decoded natively, downscaled to the screen, and handed to Flutter as bytes."
- **No photo permission (anti-goal):**
  - TakeTray never declares or asks for `READ_MEDIA_IMAGES`, nor any `READ_MEDIA_VISUAL_USER_SELECTED` or `READ_EXTERNAL_STORAGE` use beyond what the video flow already has.
  - `tool/check_release_permissions` must still end `RELEASE PERMISSIONS OK` with an unchanged list. Task 2 adds the Robolectric test for this, and the controller runs the script after Task 13 and in Task 14.
- **Videos unchanged (anti-goal):** a reel with no photos behaves exactly as before: every string, the share type `video/*`, the copy names and the header. "The one intended change is the copy folder": new sessions copy to the new root.
- **No flooding (anti-goal):** photos never reach To tag, Shooting mode, the background scan, Add earlier videos, notifications, references or the tag player. Copies never become clips.
- **Logs (D-10):** "Counts and types only". A log line never holds a file name, URI, folder, reel name or MIME type. "{n} photos" counts and error class names are fine.
- **Phone rules:**
  - The phone is used **only in Task 5 and Task 14**, by the controller with the owner.
  - S24 `-s RZCY80PHWCZ`, and only TakeTray Dev (`app.taketray.dev`). Never uninstall or clear `app.taketray`.
  - Logcat with `--pid=` only. No screenshots.
  - Never read shared storage or other apps' data. Patrol uses only `Movies/TakeTray Test/` and the new `Pictures/TakeTray Test/`, plus TakeTray Dev's own copy folders under `<root>/TakeTray/`, as `editors_test.dart` already does.
  - After every Patrol run: debug build, `install -r`, `pm clear app.taketray.dev`. Each Patrol file runs once per round.
- **Never:**
  - modify `~/flutter` (or `~/development/flutter`);
  - commit keystores, `key.properties`, `local.properties`, secrets, build output or golden failure images (`**/failures/`);
  - merge or push the spike branch (Task 5).
- **Commits:**
  - each commit ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - the PR ends `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Strict TDD:**
  - every edge-case test of a task is written red first and the RED is recorded; then the code is written once;
  - each task names mutation checks (a key line broken, and the test that kills it);
  - never weaken a test;
  - characterization tests that must pass before and after a change are marked as such and recorded green first.
- **Docs in the same task:**
  - each task writes its D-number in `docs/decisions.md` and its `docs/flow.md` lines in the same commit:
    - Task 1 D-198, Task 2 D-199, Task 3 D-200, Task 4 D-201;
    - Task 5 D-202 (the spike answers);
    - Task 6 D-203, Task 7 D-204, Task 8 D-205, Task 9 D-206;
    - Task 10 D-207 and Task 11 D-208 (conditional);
    - Task 12 D-209.
  - A conditional task that is not built still gets its number, as a one-line entry: "Not built: Spike 3 showed …".
  - An amended decision gets an "Amended by D-…" line.
- **Values:**
  - every new number is a `TtMetrics` constant (colours in `TtColors`), with its source quoted above it: a `proto.css` line or a spec line;
  - the style rules (D-19: no raw colour, inset, size, radius or duration in `app/lib/features` or `components`) hold.
- **Glass (Phase 12 rules):**
  - every `BackdropFilter`'s first painting child is a plain fill (`TtGlassFill`), never a `Material`;
  - never put an `Opacity` above a `BackdropFilter`;
  - this phase adds no glass. Existing glass pieces it reuses (`TtIconButtonStyle.circle`, `onVideo`, the player header) keep their `expectGlassStructure` tests green.
- **Contrast and access:**
  - text is AA, including the photo symbol over a thumbnail ("it uses the same scrim as the length");
  - every new control has a 48 dp target and a name;
  - light and dark; text 1× and 2×; 360 dp wide;
  - reduced motion (`MediaQuery.disableAnimations`, `tt.motion` durations zero) removes movement only, and crossfades remain.
- **Copy:** strings are given verbatim in each task, through `app/lib/l10n/app_en.arb`, then `cd app && ../tool/flutter gen-l10n`. In every mixed count, "clips" counts the videos ("8 clips and 2 photos", ruling R13-1).
- **Commands:**
  - package: `cd packages/taketray_ui && ../../tool/flutter test <file>`;
  - app: `cd app && ../tool/flutter test <file>`;
  - Kotlin: `cd app && ../tool/test_android --tests '<class>'`;
  - Pigeon: `cd app && ../tool/dart run pigeon --input pigeons/<file>.dart`, then `../tool/dart format` on its `.g.dart`;
  - codegen: `cd app && ../tool/dart run build_runner build --delete-conflicting-outputs`;
  - drift: after a schema change, `cd app && ../tool/dart run drift_dev make-migrations` (it dumps `drift_schemas/taketray/drift_schema_v3.json` and rewrites `lib/data/database/app_database.steps.dart` and `test/drift/taketray/generated/`). From v3 on, the data test is added to `test/drift/taketray/migration_test.dart` by hand (`docs/flow.md`, "Database open and migrations");
  - `tool/check_generated` fails on any stale output;
  - all checks: `tool/check` from the repo root, which ends `ALL CHECKS PASSED`.
- **Goldens:**
  - app goldens are macOS-only (`--update-goldens` locally), and package macOS goldens are updated in the task;
  - package CI goldens come once, at the end, from the "update goldens" workflow, pulled with `tool/pull_ci_goldens`;
  - every changed golden is looked at by eye before the commit.
- **Models (never Haiku; always pass the model):**
  - Opus: the implementers of Tasks 2, 3, 4, 6, 7, 10 and 11;
  - Sonnet: Tasks 1, 8, 9, 12 and 13, every fix and every task review;
  - Opus: the whole-phase review and its re-review (resume the same reviewer).
- **Reviews:**
  - Critical and Important findings are fixed now; Minors are parked for one batch before the final review;
  - a per-step fixer reviews its own fix, and the final review's fix wave gets a separate re-review;
  - the step review may be skipped for Task 13 (docs only), never for code, phone safety, privacy or the final review.

## Rulings on the spec's gaps

The spec's authority wins wherever it speaks. These rulings fill its silences, and each one is recorded in the named decision.

- **R13-1 (D-200), the counts:**
  - in a mixed count, "clips" means videos: "8 clips and 2 photos", "8 videos · 2 photos · 2:10";
  - with photos only: "2 photos", with no length;
  - the choosing bar's "{n} selected" and the reel picker's titles count every item;
  - with no photos, every string is today's.
- **R13-2 (D-200), TalkBack:**
  - a photo tile reads "Clip, {time}, Photo", following §2 to the letter ("replaces {length} with Photo");
  - video tiles keep "Clip, {time}, {duration}". The Goals' "Video, 15 seconds" would change every video tile, which is an anti-goal.
- **R13-3 (D-198), a picked photo's facts:**
  - a type that is null or does not start with `image/` is stored as `image/*` (the picker was asked for images only), so it is always a photo;
  - "else the time it was added" is the add's own time (`now`);
  - the last-modified date and the orientation swap (90° or 270° swaps width and height) are read for photo picks only, so video picks are unchanged.
- **R13-4 (D-201), the viewer:** the "missing" state for a photo is the existing Can't-play layout, with photo words and **Remove from reel**.
- **R13-5 (D-200), removing:** a remove that holds only photos says "photo"; a mixed one says "They're still in your gallery".
- **R13-6 (D-203), the folder names:**
  - `copyFolderNames` is the union of both roots, so a new folder name is free in each;
  - the guard reads the Video **and** Images collections, not `Files`: Android's consent dialog needs item URIs per type.
- **R13-7 (D-202), the spikes:**
  - Spike 1 has no fallback in the spec: if it fails, stop and ask the owner;
  - VN's HEIC answer is part of Spike 2;
  - if Spike 4 fails, it is retried on `DCIM/TakeTray/`, like Spike 2's fallback. If neither root passes both spikes, stop and ask the owner.
- **R13-8 (D-205), old watched folders:** a watched folder inside a copy root (saved before this phase, or brought in by an import) is skipped by the scans and the native counter. It is not deleted from Settings.
- **R13-9 (D-206), photo addresses:** a photo with no picker address is left out of a share. It is never built as a Video URI.
- **R13-10 (D-205), same-second names:** when a photo and another clip share a second, the later one in shooting order takes `_2` whatever its extension, so VN's name order is the shooting order. Video-only names do not change.
- **R13-11 (D-199), where Add photos lives:** only in the reel page's top bar (the spec's one entry point), not among the empty state's buttons.
- **R13-12 (D-208), HEIC for a share:** a HEIC photo for an editor that refuses HEIC goes as a JPEG copy in the session's folder. The share carries that copy's address, in its shooting place.
- **R13-13 (controller), the PR's base:** the PR targets `phase-12-ui-refresh` while that PR is open, and is retargeted to `main` once it merges.

## Review Focus

1. **A photo pick with no type, or a type that is not `image/…`.**
   - Some providers give null or `application/octet-stream`.
   - The clip must still be a photo: `image/*`, the photo symbol, no player, the photo extension in a copy, and in the `image/*` part of a share. It is never a 0:00 video that fails to play.
   - (Task 1 `'a photo pick with no type or a non-image type is image/*'`; Task 2 `'a photo pick whose provider gives no type adds a photo'`.)
2. **A watched folder already inside `Pictures/TakeTray/`.**
   - It was saved before this phase, or comes from an import. After the update, VN copies land there, and a scan would pull them into To tag.
   - The scans, Add earlier videos and the native counter must skip it, while Settings still lists it.
   - (Task 8 `'a stored watched folder inside a copy root is never scanned or counted'`.)
3. **An edit that started before the update.**
   - A VN session in `Movies/TakeTray/Goa/`, a CapCut session with add-later copies there, and a copy job the update interrupted (its saved plan has no root).
   - Add more clips, the existing-copies check, Resume, Done editing and the delete-reel text all stay in `Movies`. One edit never spans two albums.
   - (Task 7 `'a session from before the update keeps Movies for add-later, checks, resume and Done editing'`, `'a saved plan with no root resumes into Movies'`.)
4. **Swiping between a video and a photo in the viewer.**
   - The video pauses, and no video player is ever opened for the photo's address. The photo has no mute and no scrubber. Back on the video, it plays.
   - A still that cannot be decoded shows the can't-show state, never a spinner for ever.
   - A 50-megapixel photo is decoded at screen size, never at full size.
   - (Task 4 `'video → photo → video: pause, no player for the photo, play again'`, `'a still that cannot be read: "This photo can't be shown"'`, Kotlin `'targetSize never upscales and keeps the longest side at most maxSide'`.)
5. **A reel of photos only.**
   - Edit video shows (photos are live clips). The sheet reads "Edit 2 photos in…", the dock "Edit 2 photos" with no length, the header and Home "2 photos" without "0:00".
   - VN's space check counts the photos' bytes, and the share is `image/*`.
   - (Task 3 `'photos only: header "2 photos", the sheet "Edit 2 photos in…"'`, `'photos only: the card "2 photos", read "Goa. Collecting. 2 photos"'`, `'dock Edit, photos only: "Edit 2 photos", no length'`; Task 8 `'photos only: the plan counts their bytes'`; Task 9 `'photos only: image/*'`.)

---

## File map

| Area | Create | Modify |
|---|---|---|
| Photo model | `domain/rules/photo_clip.dart` | `domain/models/clip.dart`, `domain/models/media.dart`, `domain/rules/media_clip.dart` |
| Picker | — | `pigeons/media_api.dart`, `media/PickedVideos.kt`, `media/MediaHostApiImpl.kt`, `platform/media_bridge.dart`, `test/support/fake_media_bridge.dart` |
| Add photos | `features/add_videos/views/add_photos.dart` | `data/media/add_videos_service.dart`, `features/reels/views/reel_detail_screen.dart` |
| Tiles, counts | `features/clips/widgets/media_counts.dart` | `components/clip_tile.dart`, `tt_metrics.dart`, `reel_edit_sections.dart`, `edit_select_screen.dart`, `domain/models/reel_summary.dart`, `reels_repository.dart`, `reel_detail_controller.dart`, `reels_screen.dart`, `editor_sheet.dart`, `reel_choosing_dock.dart`, `clip_viewer_screen.dart` (snack) |
| Viewer | `media/PhotoStills.kt` | `pigeons/media_api.dart`, `clip_viewer_screen.dart`, `clip_viewer_controller.dart` |
| Copy root, native | `domain/models/copy_root.dart` | `pigeons/copy_api.dart`, `pigeons/editors_api.dart`, `editors/CopyFolderPath.kt`, `CopyFolder.kt`, `CopyStore.kt`, `CopyEngine.kt`, `CopyHostApiImpl.kt`, `EditorsHostApiImpl.kt`, `DebugCopyHooks.kt`, `platform/copy_bridge.dart`, `platform/editors_bridge.dart` |
| Copy root, app | `test/l10n/copy_root_strings_test.dart` | `tables.dart`, `app_database.dart`, `domain/models/edit_session.dart`, `copy_job_plan.dart`, `edit_sessions_repository.dart`, `edit_session_service.dart`, the copy screens, `reel_edit_banner.dart`, `delete_reel_dialog.dart`, `copies_storage_*` |
| VN, exclusion | — | `domain/rules/copy_file_names.dart`, `chat_folders.dart`, `browse_folders.dart`, `media_scanner.dart`, `background_sync.dart` |
| Shares | — | `pigeons/editors_api.dart` (`ShareClipMsg`), `editors/ShareIntents.kt`, `edit_session_service.dart` (`SendOutcome`), `editor_sheet.dart` |
| Patrol | `patrol_test/photos_test.dart` | `debug/.../TestMedia.kt`, `TestMediaHandler.kt`, `patrol_test/support/test_media.dart`, `patrol_test/editors_test.dart` |

App paths are under `app/lib/` unless written in full. Component paths are under `packages/taketray_ui/lib/src/`. Kotlin paths are under `app/android/app/src/main/kotlin/app/taketray/`.

---

### Task 1: Photo clips: `isPhoto`, a picked photo's facts, and photos as rows everywhere

**Model:** Sonnet. **D-198** (extends D-57, D-113).

**Files:**
- Create: `app/lib/domain/rules/photo_clip.dart`, `app/test/domain/rules/photo_clip_test.dart`.
- Modify:
  - `app/lib/domain/models/clip.dart` (a `const Clip._();` and the getter)
  - `app/lib/domain/models/media.dart` (`PickedVideo.dateModifiedMs`)
  - `app/lib/domain/models/clip_ref.dart` (`isPhoto`)
  - `app/lib/domain/rules/media_clip.dart`
- Test: `test/domain/models/models_test.dart`, `test/domain/rules/media_clip_test.dart`, `test/data/repositories/clips_repository_test.dart`, `test/data/media/media_verifier_test.dart`, `test/data/media/picked_grants_test.dart`, `test/data/backup/backup_service_test.dart`.

**Interfaces:**
- Produces:
  ```dart
  // photo_clip.dart
  const String defaultPhotoMimeType = 'image/*';
  /// True when [mimeType] starts with `image/`, ignoring ASCII case.
  bool isPhotoMimeType(String mimeType);
  /// [reported] when it is an image type, else `image/*` (R13-3).
  String photoMimeTypeOf(String? reported);
  /// The first plausible of [PickedVideo.dateTakenMs] and [PickedVideo.dateModifiedMs]
  /// (the `shotAtFrom` rule: not before 0, not after now + 24 h), else [now].
  DateTime pickedPhotoShotAt(PickedVideo p, {required DateTime now});

  // clip.dart (Clip gets `const Clip._();`)
  bool get isPhoto; // isPhotoMimeType(mimeType)
  // clip_ref.dart
  bool get isPhoto;

  // media.dart, PickedVideo: a new optional field, null for every video pick
  int? dateModifiedMs,

  // media_clip.dart
  /// A picked photo as a clip: picker identity, durationMs 0, its size, name,
  /// width and height (0 when unknown), photoMimeTypeOf(type), pickedPhotoShotAt.
  NewClip newClipFromPickedPhoto(PickedVideo p, {required DateTime now, required String? zoneId});
  ```
- **Rules:** `newClipFromPicked` (videos) is unchanged. It never reads `dateModifiedMs`.

- [ ] **Step 1: Write the failing tests.**
  - `photo_clip_test.dart`:
    ```dart
    test('isPhotoMimeType: image/jpeg, image/heic, IMAGE/PNG, image/* yes; video/mp4, video/*, "", "imagex/y" no', …)
    test('a photo pick with no type or a non-image type is image/*', …)  // null, 'application/octet-stream', 'video/mp4' → 'image/*'; 'image/heic' kept
    test('pickedPhotoShotAt: taken wins when plausible', …)              // taken 1700000000000 → that instant, UTC
    test('pickedPhotoShotAt: an impossible taken date falls to the modified date', …) // taken -1 or now+2 days; modified 1690000000000
    test('pickedPhotoShotAt: neither plausible → now', …)
    test('pickedPhotoShotAt: now + 24 h exactly is still plausible; one ms more is not', …)
    ```
  - `media_clip_test.dart`:
    ```dart
    test('newClipFromPickedPhoto: picker identity, durationMs 0, type, size, name, width, height, zone', …)
    test('newClipFromPicked (videos) ignores dateModifiedMs', …) // characterization: taken null, modified set → now
    ```
  - `models_test.dart`: `'Clip.isPhoto follows the type; ClipRef.isPhoto too'`.
  - Characterization, photos as rows (each with `mimeType: 'image/jpeg'`, `durationMs: 0`; green before the change is recorded, since they need no code. If one is red, it is a finding to fix in this task):
    - `clips_repository_test.dart`:
      - `'a photo added by hand to a reel has no inbox row'`;
      - `'removing a photo from its only reel deletes its row; it never goes to To tag'`;
      - `'move and Undo carry a photo like a video'`.
    - `media_verifier_test.dart`: `'a photo whose address no longer opens is flagged missing; a readable one is not'`.
    - `picked_grants_test.dart`: `'a photo row holds its grant; a photo no row holds is released'`.
    - `backup_service_test.dart`:
      - `'a photo round-trips: image/heic, durationMs 0, picker uri'`;
      - `'fixtures/backup_v1.json (no photos) imports as before'`.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/domain test/data/repositories/clips_repository_test.dart test/data/media/media_verifier_test.dart test/data/media/picked_grants_test.dart test/data/backup/backup_service_test.dart`. Expected: the new domain tests FAIL (undefined names). Record which characterization tests pass.
- [ ] **Step 3: Implement** `photo_clip.dart`, the getters, the field, `newClipFromPickedPhoto`; then run `build_runner`.
- [ ] **Step 4: Run** the same command, then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - `startsWith('image/')` without the case fold: the `IMAGE/PNG` case fails;
  - `photoMimeTypeOf` returning `reported ?? 'image/*'`: `'… non-image type is image/*'` fails;
  - modified tried before taken: `'taken wins when plausible'` fails.
- [ ] **Step 6: Docs and commit** `feat(clips): a photo is a clip with an image type`.
  - **D-198:**
    - why photos are `clips` rows (spec approach 2);
    - `isPhoto`, R13-3 and the date order;
    - which paths carry photos unchanged, with their tests;
    - the backup format stays version 1, because no field is added.
  - `flow.md`: "Picked clips: pictures, checks and the grant clean-up" names photos; "Backup export and import" says photos are clip rows.

---

### Task 2: Add photos: the picker, the service and the reel page's button

**Model:** Opus. **D-199** (extends D-111, D-112, D-113).

**Files:**
- Create:
  - `app/lib/features/add_videos/views/add_photos.dart`
  - `app/test/features/add_videos/views/add_photos_test.dart`
- Modify:
  - `app/pigeons/media_api.dart`, and the generated `media_api.g.dart` and `MediaApi.g.kt`
  - `media/PickedVideos.kt`, `media/MediaHostApiImpl.kt`
  - `app/lib/platform/media_bridge.dart`, `app/test/support/fake_media_bridge.dart`
  - `app/lib/data/media/add_videos_service.dart`
  - `app/lib/features/reels/views/reel_detail_screen.dart`
  - `app/lib/l10n/app_en.arb`
- Test:
  - Kotlin: `PickedVideosTest.kt`, `MediaHostApiImplTest.kt`, `ManifestTest.kt`
  - Dart: `test/platform/media_bridge_test.dart`, `test/platform/fake_media_bridge_test.dart`, `test/data/media/add_videos_service_test.dart`, `test/features/reels/views/reel_detail_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 (`newClipFromPickedPhoto`, `PickedVideo.dateModifiedMs`).
- Produces:
  ```dart
  // pigeons/media_api.dart: PickedVideoMsg gains `int? dateModifiedMs;`
  /// Android's photo picker for photos only (image/*, multiple), or the
  /// document picker where it is missing; [] when cancelled; `busy` while any
  /// pick (videos or photos) is open; `host-gone` as pickVideos.
  @async List<PickedVideoMsg> pickPhotos();

  // MediaBridge
  Future<List<PickedVideo>> pickPhotos();

  // AddVideosService: one job on the media queue, like addPicked.
  /// Adds picked photos straight to reel [reelId] (never To tag). Not
  /// persisted → notKept; a known address in that reel → alreadyThere; the
  /// same address in another reel → linked (one clip, two reels).
  /// StateError when the reel is gone, writing nothing. Logs "photos" counts.
  Future<AddResult> addPhotos(List<PickedVideo> photos, int reelId);

  // add_photos.dart
  /// Opens the photo picker once, adds what was picked to [reelId], and shows
  /// the snack on the root messenger. A cancel adds and shows nothing; `busy`
  /// shows nothing; any other failure shows addPhotosFailed.
  Future<void> addPhotosToReel(BuildContext context, WidgetRef ref, int reelId);
  ```
  - Kotlin:
    - `PickedVideos.intent(sdk, extensionLevel, maxLimit, type: String = VIDEO_TYPE)` with `PHOTO_TYPE = "image/*"`;
    - `describe(resolver, grants, uris, photos: Boolean = false)`.
- **Rules:**
  - **Native:**
    - photos use the same picker slot and request code as videos, so one pick at a time;
    - for `photos = true`, `dateModifiedMs` is the document's `COLUMN_LAST_MODIFIED` (ms) when the cursor has it, else `MediaColumns.DATE_MODIFIED` × 1000, else null;
    - an `orientation` column of 90 or 270 swaps width and height (photos only);
    - video picks never set either (R13-3).
  - **The button:** a `TtIconButton(icon: Symbols.add_photo_alternate_rounded, semanticLabel: addPhotosTitle, style: circle)` right after **Add videos** in the reel page's top bar. It is shown when the reel is known, not while choosing, and goes through its own `OpenOnce.openSlow`. R13-11: not in the empty state.
  - **The snack** (`ReelSnacks`, as `openAddVideos`'s `announce`):
    - `added > 0`: `addPhotosAddedSnack(n, reel)` with **Undo** (`service.undo(result)`), plus `addPhotosNotKept(k)` under it when k > 0;
    - `added == 0`: `addVideosAlreadyAdded` when something was there (or nothing was kept back), with `addPhotosNotKept(k)` under it when k > 0;
    - a reel deleted during the add: nothing.
- **Strings:**
  - `addPhotosTitle`: `"Add photos"`
  - `addPhotosAddedSnack`: `"{count, plural, one{1 photo added to {reel}} other{{count} photos added to {reel}}}"`
  - `addPhotosNotKept`: `"{count, plural, one{Couldn't add 1 photo.} other{Couldn't add {count} photos.}}"`
  - `addPhotosFailed`: `"Couldn't add photos. Try again."`

- [ ] **Step 1: Write the failing Kotlin tests.**
  - `PickedVideosTest.kt`:
    ```kotlin
    @Test fun `photo intent on 33: ACTION_PICK_IMAGES, image star, the system max`()
    @Test fun `photo intent on 30 with extension 1: OPEN_DOCUMENT, image star, multiple, persistable read`()
    @Test fun `video intent is unchanged on every level`()                // characterization
    @Test fun `a photo pick reads the modified date: document ms, else MediaStore seconds times 1000`()
    @Test fun `a photo with orientation 90 or 270 has width and height swapped; 0 and 180 do not`()
    @Test fun `a video pick never sets dateModifiedMs and never swaps`()
    @Test fun `a photo whose grant is refused is persisted false; the others are kept`()
    ```
  - `MediaHostApiImplTest.kt`:
    - `'pickPhotos while a video pick is open is busy, and the other way round'`;
    - `'pickPhotos cancelled answers an empty list'`.
  - `ManifestTest.kt`, the no-photo-permission guard:
    ```kotlin
    @Test fun `no photo permission: the media permissions are exactly READ_EXTERNAL_STORAGE max 32, READ_MEDIA_VIDEO and READ_MEDIA_VISUAL_USER_SELECTED`()
    @Test fun `READ_MEDIA_IMAGES is never declared`()
    ```
- [ ] **Step 2: Write the failing Dart tests.**
  - `media_bridge_test.dart`: `'pickPhotos maps every field, dateModifiedMs included'`.
  - `add_videos_service_test.dart`:
    ```dart
    test('addPhotos: 3 picked → 3 photos in the reel, no inbox row, each image/… with durationMs 0', …)
    test('the same address again in that reel → alreadyThere 1, added 0', …)
    test('a photo already in another reel is linked, not copied: one row, two reels', …)
    test('a photo not persisted → notKept, nothing written for it', …)
    test('a photo pick whose provider gives no type adds a photo', …)  // Review Focus 1: image/*
    test('Undo removes exactly the photos this add brought in', …)    // one already there stays
    test('the reel is gone → StateError, nothing written', …)
    test('the log has counts only: no address, name or type', …)
    ```
  - `add_photos_test.dart`:
    ```dart
    testWidgets('3 added: "3 photos added to Goa" with Undo; Undo takes them off', …)
    testWidgets('2 added, 1 not kept: two lines, "Couldn't add 1 photo."', …)
    testWidgets('all already there: "Already added"', …)
    testWidgets('cancelled: nothing added, no snack', …)
    testWidgets('busy: no snack; any other PlatformException: "Couldn't add photos. Try again."', …)
    ```
  - `reel_detail_screen_test.dart`:
    ```dart
    testWidgets('Add photos sits after Add videos, read "Add photos", 48 dp', …)
    testWidgets('Add photos opens one picker however fast the taps', …)  // fake pickPhotosCalls == 1
    testWidgets('no Add photos while choosing, or before the reel is read', …)
    testWidgets('2x text at 360: the top bar has Back, Add videos, Add photos and ⋮, no overflow', …)
    ```
- [ ] **Step 3: Run** `cd app && ../tool/test_android --tests 'app.taketray.media.*' --tests 'app.taketray.ManifestTest'` and `cd app && ../tool/flutter test test/platform test/data/media/add_videos_service_test.dart test/features/add_videos test/features/reels/views/reel_detail_screen_test.dart`. Expected: FAIL (undefined names; no button). The two `ManifestTest` cases pass already: record them as characterization.
- [ ] **Step 4: Implement** the Pigeon change and regenerate, then the Kotlin intent and `describe`, `MediaHostApiImpl.pickPhotos`, the bridge and fake, `addPhotos`, `add_photos.dart`, the button and the strings.
- [ ] **Step 5: Run** both commands, then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 6: Mutation checks:**
  - photo intent with `VIDEO_TYPE`: `'photo intent on 33 …'` fails;
  - swap on 180 too: `'… 0 and 180 do not'` fails;
  - `addPhotos` through `AddToToTag`: `'… no inbox row …'` fails;
  - Undo through `undoAll` on every photo of the reel: `'Undo removes exactly the photos this add brought in'` fails.
- [ ] **Step 7: Docs and commit** `feat(reels): Add photos, through Android's photo picker`.
  - **D-199:**
    - the button's place (spec approach 4; R13-11);
    - one picker slot for both kinds;
    - the native facts (R13-3);
    - why `addPhotos` takes a reel and never a target;
    - the snack and Undo;
    - the no-permission guard tests.
  - D-112 and D-113 get "Amended by D-199".
  - `flow.md`: "Folder pages and the photo picker" (`pickPhotos`), "Adding videos by hand" (`addPhotos`), "Opening a reel" (the button).

---

### Task 3: How a photo shows and counts: tiles, TalkBack, the header, Home, the sheet and the dock

**Model:** Opus. **D-200** (amends D-87, D-189, D-191 and D-194 for the counts).

**Files:**
- Create:
  - `app/lib/features/clips/widgets/media_counts.dart`
  - `app/test/features/clips/widgets/media_counts_test.dart`
- Modify:
  - Package: `packages/taketray_ui/lib/src/components/clip_tile.dart`, `tt_metrics.dart`, `widgetbook/lib/components/clip_tile.dart`
  - Tiles: `app/lib/features/reels/views/reel_edit_sections.dart`, `app/lib/features/editors/views/edit_select_screen.dart` (the add picker's tiles)
  - Counts: `app/lib/domain/models/reel_summary.dart`, `app/lib/data/repositories/reels_repository.dart` (`watchReelSummaries`), `app/lib/features/reels/view_models/reel_detail_controller.dart`, `reel_detail_screen.dart` (`_header`, `_openEditorSheet`), `reels_screen.dart` (the card)
  - Hand-off pieces: `app/lib/features/editors/views/editor_sheet.dart` (title), `app/lib/features/reels/views/reel_choosing_dock.dart` (Edit)
  - Remove snacks: `clip_viewer_screen.dart` and the dock's Remove
  - `app/lib/l10n/app_en.arb`
- Test:
  - Package: `packages/taketray_ui/test/components/clip_tile_test.dart`, `clip_tile_golden_test.dart`
  - Repositories and view models: `reels_repository_test.dart`, `test/features/reels/view_models/` (the detail controller)
  - Screens: `reel_detail_screen_test.dart`, `reels_screen_test.dart`, `editor_sheet_test.dart`, `reel_selection_screen_test.dart`, `edit_select_screen_test.dart`, `clip_viewer_screen_test.dart`
  - Goldens: `home_golden_test.dart`, `reel_choosing_golden_test.dart`, `editors_golden_test.dart`

**Interfaces:**
- Consumes: Task 1 (`Clip.isPhoto`).
- Produces:
  ```dart
  // TtClipTile: a photo shows the photo symbol where a video shows its length.
  final bool photo; // default false; assert(!photo || durationText == null)
  // ReelSummary
  @Default(0) int photoCount; // every photo in the reel, missing ones too
  // ReelDetailState
  final int photoCount;
  // media_counts.dart
  /// "8 clips and 2 photos", "1 photo", or, with photos 0, exactly reelCardClips(videos).
  String clipsAndPhotosText(AppLocalizations l10n, {required int videos, required int photos});
  // showEditorSheet gains:
  int photoCount = 0, // how many of clipIds are photos
  ```
- **Rules:**
  - **The tile:**
    - `photo: true` draws `Symbols.image_rounded` (filled, `tt.colors.onMedia`, with the text's shadow) at the length's place (`end: clipTileTextInset`, `bottom: clipTileTextBottom`), over the same `_TileScrim`;
    - hidden when selected or marked, like the length;
    - a thumbnail that fails shows `Symbols.image_rounded` in the placeholder, not the movie one;
    - the app passes `photo: clip.isPhoto` and `durationText: null` for a photo, and the label `clipTileSemantics(time, clipKindPhoto)` (or `…InReels`), per R13-2;
    - the horizontal badge follows width > height for photos too.
  - **Grouping:** a photo is grouped by its time taken, like any clip ("an old gallery photo makes its own earlier day at the top").
  - **The reel header:**
    - no photos: today's `reelCardMeta(reelCardClips(n), length)`;
    - videos and photos: `reelMetaWithPhotos(reelHeaderVideos(v), photoCount(p), length)`;
    - photos only: `photoCount(p)`;
    - `v = clipCount − photoCount`, and the length counts live videos.
  - **The Home card:**
    - meta: no photos, today's; with photos, `reelMetaWithPhotos(reelCardClips(v), photoCount(p), length)`; photos only, `photoCount(p)`;
    - its accessible name: with photos, `reelCardSemanticsCounts(name, status, clipsAndPhotosText(…))` (or `…CountsMissing`). The editing and references suffixes follow as today.
    - `photoCount` comes from the summary query: `SUM(CASE WHEN c.mime_type LIKE 'image/%' THEN 1 ELSE 0 END)` (`LIKE` ignores ASCII case, as `isPhoto` does).
  - **The editor sheet's title:**
    - `photoCount == 0`: today's;
    - videos and photos: `editorSheetTitleAllWith(counts)` when `allClips && clipIds.length > 1`, else `editorSheetTitleWith(counts)`;
    - photos only: `editorSheetTitleWith(photoCount(p))`. "With photos only: 'Edit 2 photos in…'" (no "all");
    - both callers pass `photoCount`.
  - **The dock's Edit:**
    - no chosen photos: today's;
    - with photos: label `selectionDockEditWith(counts)`, `detail` the live videos' length, read `selectionDockEditWithSemantics(counts, length)`;
    - photos only: no detail, read `selectionDockEditWith(counts)`.
  - **Remove snacks (R13-5):**
    - the viewer's Remove of a photo: `viewerPhotoRemovedSnack(reel)`;
    - the dock's Remove: `clipsRemovedSnackWithPhotos(counts, reel)` when any is a photo; today's string otherwise.
- **Strings:**
  - `clipKindPhoto`: `"Photo"`
  - `photoCount`: `"{count, plural, one{1 photo} other{{count} photos}}"`
  - `clipsAndPhotos`: `"{clips} and {photos}"`
  - `reelHeaderVideos`: `"{count, plural, one{1 video} other{{count} videos}}"`
  - `reelMetaWithPhotos`: `"{clips} · {photos} · {duration}"`
  - `reelCardSemanticsCounts`: `"{name}. {status}. {counts}"`
  - `reelCardSemanticsCountsMissing`: `"{name}. {status}. {counts}, {missing} missing"`
  - `editorSheetTitleWith`: `"Edit {counts} in…"`
  - `editorSheetTitleAllWith`: `"Edit all {counts} in…"`
  - `selectionDockEditWith`: `"Edit {counts}"`
  - `selectionDockEditWithSemantics`: `"Edit {counts}, {duration}"`
  - `viewerPhotoRemovedSnack`: `"Removed from {reel}. The photo is still in your gallery."`
  - `clipsRemovedSnackWithPhotos`: `"{counts} removed from {reel}. They're still in your gallery."`
- **Metrics** (`tt_metrics.dart`):
  ```dart
  /// Size of the photo symbol where a video's length is.
  // proto.css:457: .tile .du { font: 700 12px/16px … } (the length's 16 px line)
  static const double clipTilePhotoIconSize = 16;
  ```

- [ ] **Step 1: Characterization first.** Run the existing `clip_tile_test.dart`, `reels_screen_test.dart`, `reel_detail_screen_test.dart`, `editor_sheet_test.dart` and `reel_selection_screen_test.dart`. Expected: PASS. They are the "no photos, as today" proof and stay unchanged.
- [ ] **Step 2: Write the failing tests.**
  - `clip_tile_test.dart`:
    ```dart
    testWidgets('photo: the image symbol where the length is, 16 dp, onMedia, over the scrim', …)
    testWidgets('photo selected or marked: no symbol, like the length', …)
    testWidgets('photo with a failed thumbnail: the image placeholder, not the movie one', …)
    testWidgets('photo at 2x text at 360: no overflow; the time still shows', …)
    for (final b in Brightness.values) testWidgets('${b.name}: photo tile accessible', …) // expectTtAccessible
    ```
    Golden: add **photo**, **photo selected** and **photo horizontal** to `clip_tile_golden_test.dart`.
  - `media_counts_test.dart`:
    - `'8 and 2: "8 clips and 2 photos"'`;
    - `'1 and 1: "1 clip and 1 photo"'`;
    - `'0 and 2: "2 photos"'`;
    - `'5 and 0: exactly reelCardClips(5)'`.
  - `reels_repository_test.dart`:
    - `'photoCount counts image types in any case, missing ones too; liveDurationMs counts videos'`;
    - `'the cover is never a photo'` (characterization: picker clips are not covers).
  - `reel_detail_screen_test.dart`:
    ```dart
    testWidgets('a photo tile: the photo symbol, no length, read "Clip, 9:41 AM, Photo"', …)
    testWidgets('header: "8 videos · 2 photos · 2:10"; no photos: "8 clips · 2:10" as today', …)
    testWidgets('photos only: header "2 photos", the sheet "Edit 2 photos in…"', …) // Review Focus 5; Edit video still shows
    testWidgets('an old photo makes its own earlier day at the top', …)
    testWidgets('Edit video passes photoCount: "Edit all 3 clips and 1 photo in…"', …)
    ```
  - `reels_screen_test.dart`:
    - `'card: "8 clips · 2 photos · 2:10", read "Goa. Collecting. 8 clips and 2 photos"'`;
    - `'with a missing photo: "…, 1 missing"'`;
    - `'photos only: the card "2 photos", read "Goa. Collecting. 2 photos"'` (Review Focus 5).
  - `editor_sheet_test.dart`:
    - `'chosen with photos: "Edit 2 clips and 1 photo in…"'`;
    - `'every clip but one video and one photo: "Edit all 1 clip and 1 photo in…"'`;
    - `'one photo: "Edit 1 photo in…"'`.
  - `reel_selection_screen_test.dart`:
    - `'dock Edit with photos: "Edit 2 clips and 1 photo", the videos' length, read "Edit 2 clips and 1 photo, 0:40"'`;
    - `'dock Edit, photos only: "Edit 2 photos", no length'`;
    - `'the dock's Remove with a photo: "1 clip and 1 photo removed from Goa. They're still in your gallery."'`.
  - `clip_viewer_screen_test.dart`: `'Remove on a photo: "Removed from Goa. The photo is still in your gallery."'`.
  - `edit_select_screen_test.dart`: `'add mode: a photo tile has the photo symbol and its label'`.
  - Goldens: `home_golden_test.dart` gets `home_photos_{light,dark}_1x` (a card with photos); `reel_choosing_golden_test.dart` gets `reel_choosing_photos_light` (a photo tile chosen and one not).
- [ ] **Step 3: Run** `cd packages/taketray_ui && ../../tool/flutter test test/components/clip_tile_test.dart` and `cd app && ../tool/flutter test test/features/clips test/data/repositories/reels_repository_test.dart test/features/reels test/features/editors`. Expected: FAIL.
- [ ] **Step 4: Implement** the tile and metric, the widgetbook photo state, `media_counts.dart`, `photoCount` in the summary and the detail state, and the header, card, sheet, dock, snacks and strings.
- [ ] **Step 5: Run** the same commands, then update and look at the package macOS goldens (`clip_tile_*`) and the app goldens (`home_photos_*`, `reel_choosing_photos_light`, and any `editors_golden_test` image whose title changed; none should). Run `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 6: Mutation checks:**
  - pass `durationText` for a photo: `'a photo tile: … no length …'` fails (the assert);
  - count photos in `reelCardClips`'s number: `'card: "8 clips · 2 photos · 2:10" …'` fails;
  - drop the photos-only branch in the header: `'photos only: header "2 photos" …'` fails ("0:00" shows);
  - `editorSheetTitleAllWith` for photos only: `'one photo: "Edit 1 photo in…"'` fails.
- [ ] **Step 7: Docs and commit** `feat(reels): photos show a photo symbol and count beside the videos`.
  - **D-200:** the tile rule and its metric line; R13-1, R13-2 and R13-5; every string and where it shows; the query.
  - D-87, D-189, D-191 and D-194 get "Amended by D-200 (photo counts)".
  - `flow.md`: "Opening a reel" (header), "Home, the Reels tab" (card), "Picking clips and the editor sheet" (title), "Managing clips in a reel" (dock).

---

### Task 4: The viewer: a photo page with a still decoded natively

**Model:** Opus. **D-201** (amends D-89).

**Files:**
- Create: `media/PhotoStills.kt`, `app/android/app/src/test/kotlin/app/taketray/media/PhotoStillsTest.kt`.
- Modify:
  - `app/pigeons/media_api.dart` (+ generated), `media/MediaHostApiImpl.kt`
  - `app/lib/platform/media_bridge.dart`, `test/support/fake_media_bridge.dart`
  - `app/lib/features/reels/view_models/clip_viewer_controller.dart` (+ `.g.dart`), `app/lib/features/reels/views/clip_viewer_screen.dart`
  - `app/lib/l10n/app_en.arb`
- Test: `test/features/reels/views/clip_viewer_screen_test.dart`, `test/platform/media_bridge_test.dart`, `MediaHostApiImplTest.kt`.

**Interfaces:**
- Consumes: Task 1 (`isPhoto`), Task 3 (`viewerPhotoRemovedSnack`).
- Produces:
  ```dart
  // pigeons/media_api.dart
  /// A content [uri]'s picture, decoded by Android (ImageDecoder, EXIF
  /// orientation applied), scaled down so its longer side is at most
  /// [maxSidePx] (never up), as JPEG bytes. Null when the address is not
  /// content:, is gone, its grant is lost, or it cannot be decoded.
  @async Uint8List? photoStill(String uri, int maxSidePx);
  // MediaBridge
  Future<Uint8List?> photoStill(String uri, int maxSidePx);
  // clip_viewer_controller.dart
  @riverpod Future<Uint8List?> photoStill(Ref ref, String uri, int maxSidePx); // autoDispose
  ```
  - Kotlin:
    - `object PhotoStills { fun targetSize(width: Int, height: Int, maxSide: Int): Size; fun decode(resolver: ContentResolver, uri: String, maxSide: Int, decodeBitmap: (Uri, (Size) -> Size) -> Bitmap = …): ByteArray? }`;
    - JPEG quality `STILL_JPEG_QUALITY = 90`.
- **Rules:**
  - **Decoding:**
    - `maxSidePx = (MediaQuery.sizeOf.longestSide × devicePixelRatio).ceil()`, the screen's longest side;
    - Kotlin decodes with `ImageDecoder.setTargetSize(targetSize(…))` and the software allocator, so a large photo is never decoded at full size;
    - `IOException`, `SecurityException`, `ImageDecoder.DecodeException` and a non-content address give null. Any other exception goes to Dart.
  - **A photo page** (`clip.isPhoto`):
    - the still is fitted whole (`BoxFit.contain`) on black;
    - while it decodes: the clip's thumbnail (`clipThumbnail(clip:, logicalSize: MediaQuery.sizeOf(context).shortestSide, cache:)`), fitted the same;
    - null or an error: `_CantShow`, with the error icon, `viewerCantShowTitle`, `viewerCantShowBody` and **Remove from reel** (R13-4);
    - Semantics: an image named `viewerStagePhoto(i, n)`, with no tap action, value or hint;
    - no play overlay, and a tap does nothing.
  - **Players:**
    - `clipPlayerProvider` is never read for a photo, and neither are `_pause` and `_resume` (they act on video pages only);
    - swiping away from a video pauses it, as today.
  - **The controls on a photo page:**
    - the mute button is not in the header;
    - the scrubber is not shown;
    - "In", **Add to reel**, **Move**, **Remove** and **Share** are as for a video;
    - title and time are unchanged.
- **Strings:**
  - `viewerStagePhoto`: `"Photo {index} of {count}"`
  - `viewerCantShowTitle`: `"This photo can't be shown"`
  - `viewerCantShowBody`: `"It may have been moved, deleted or damaged."`

- [ ] **Step 1: Write the failing Kotlin tests** (`PhotoStillsTest.kt`):
  ```kotlin
  @Test fun `targetSize never upscales and keeps the longest side at most maxSide`() // 8160x6120, 2340 → 2340x1755; 800x600, 2340 → 800x600
  @Test fun `targetSize keeps a side of at least 1`()                                  // 10000x1, 100 → 100x1
  @Test fun `decode asks the decoder for the target size and gives JPEG bytes`()
  @Test fun `decode is null for a gone file, a lost grant, an undecodable file and a non-content address`()
  @Test fun `decode passes any other exception on`()
  ```
  and `MediaHostApiImplTest.kt`: `'photoStill runs off the main thread and answers null for a file address'`.
- [ ] **Step 2: Write the failing Dart tests** (`clip_viewer_screen_test.dart`, with a fake still and a fake player):
  ```dart
  testWidgets('a photo page: the still fitted whole, read "Photo 2 of 3", no play, no mute, no scrubber', …)
  testWidgets('while the still decodes the thumbnail shows', …)
  testWidgets('a still that cannot be read: "This photo can't be shown" and Remove from reel', …)
  testWidgets('a still that throws: the same can't-show state', …)
  testWidgets('video → photo → video: pause, no player for the photo, play again', …) // Review Focus 4
      // the fake player factory never sees the photo's address
  testWidgets('the still is asked at the screen's longest side in pixels', …)       // 400x800 at 3.0 → 2400
  testWidgets('Remove, Move and Add to work on a photo page, and Move goes to the next clip', …)
  testWidgets('2x text: a photo page's bottom controls scroll, nothing overflows', …)
  ```
  `media_bridge_test.dart`: `'photoStill passes uri and size through'`.
- [ ] **Step 3: Run** `cd app && ../tool/test_android --tests 'app.taketray.media.PhotoStillsTest' --tests 'app.taketray.media.MediaHostApiImplTest'` and `cd app && ../tool/flutter test test/features/reels/views/clip_viewer_screen_test.dart test/platform/media_bridge_test.dart`. Expected: FAIL.
- [ ] **Step 4: Implement** the Pigeon method and regenerate, then `PhotoStills`, the host call, the bridge and fake, the provider, `_PhotoStage`, `_CantShow`, the header and bottom rules, and the strings.
- [ ] **Step 5: Run** the same commands, then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 6: Mutation checks:**
  - `targetSize` returning `maxSide` for a smaller picture: `'… never upscales …'` fails;
  - call `_resume(clipVideoUri(photo))` on a page change: `'video → photo → video …'` fails;
  - show the mute button always: `'a photo page … no mute …'` fails.
- [ ] **Step 7: Docs and commit** `feat(viewer): photos show as stills in the clip viewer`.
  - **D-201:** the decode path and why it is native (no new package); the size rule; the null cases; the page rules; R13-4.
  - D-89 gets "Amended by D-201".
  - `flow.md`: "Watching a clip" (photo pages), "Native bridge" (`photoStill`).

---

### Task 5: The four S24 spikes (controller with the owner)

**Model:** Sonnet (the controller, with the owner at the phone). The throwaway code may go to one Sonnet implementer. **D-202** (the answers).

Runs as soon as the phone is free, after Task 4. **Tasks 6–12 wait on it** (see "Which tasks wait" below).

**Safety (repeat before each command):** `-s RZCY80PHWCZ`, `app.taketray.dev` only, logcat `--pid=` only, no screenshots, no reading of shared storage or other apps. The spike writes only into `<root>/TakeTray/TakeTray Spike/`, which TakeTray Dev owns, and deletes it at the end.

**Throwaway code:**
- Branch `spike/phase-13-photos` from the Task 4 commit. It is **never pushed or merged**, and is deleted after Step 6.
- On it, a debug-build-only Settings row **"Phase 13 spike"** acts on the clips of a reel named **Spike**, with four buttons:
  1. **Copy to Pictures**: inserts a byte copy of each clip into `Pictures/TakeTray/TakeTray Spike/` through MediaStore (Video collection for a video, Images for a photo), named by `copyFileNames`;
  2. **Copy to DCIM**: the same into `DCIM/TakeTray/TakeTray Spike/`;
  3. **Share mixed**: `ACTION_SEND_MULTIPLE`, type `*/*`, read grant, to CapCut, Edits or the chooser (pick in a dialog);
  4. **Share photos only**: the same with `image/*`.
- It logs only counts and the insert or share result's class.

**Test media:**
- The owner shoots, just for the spike, a 3-second video, a JPEG photo and a HEIC photo (Camera › Settings › High efficiency pictures on), of something with no people.
- They are deleted in Gallery at the end.

- [ ] **Step 1: Spike 1, picker grants** (on the Task 4 build, before the throwaway branch).
  - Make a reel **Spike**. Add the video with Add videos, then both photos with **Add photos**: "2 photos added to Spike".
  - Then `tool/adb -s RZCY80PHWCZ shell am force-stop app.taketray.dev`, reopen, and reboot the phone once: the photo tiles, thumbnails and viewer stills are still there.
  - Also note:
    - the same two photos picked again give "Already added" (the address is stable);
    - the HEIC photo's tile and still show;
    - a photo taken in portrait shows without the horizontal badge (orientation).
- [ ] **Step 2: Spike 2, `Pictures` (and VN).**
  - **Copy to Pictures**: every insert succeeds, the video included.
  - In VN: New project. One album, `TakeTray Spike`, shows the video and both photos in name order, which is shooting order. Import all three. Note whether VN accepts the HEIC photo.
- [ ] **Step 3: Spike 3, mixed shares and HEIC.**
  - **Share mixed** to CapCut, then to Edits, then through the chooser: each opens with all three items, in order. Note any item left out, and the HEIC photo in particular.
  - **Share photos only** to CapCut and to Edits.
- [ ] **Step 4: Spike 4, the album pickers.** In CapCut's and in Edits' add-media pickers (inside a project), the `TakeTray Spike` album under Pictures is listed with the three items.
- [ ] **Step 5: Fallback runs, only when needed.**
  - If Step 2's video insert failed, or Step 4 did not list the album: **Copy to DCIM**, then repeat Steps 2 and 4 on `DCIM/TakeTray/TakeTray Spike/`.
- [ ] **Step 6: Clean up.**
  - Delete `TakeTray Spike` from each root it was made in, through the app's own delete (owner rows), then confirm both folders are gone in Files.
  - Delete the reel, and the owner deletes the three test items in Gallery.
  - `git branch -D spike/phase-13-photos`.
- [ ] **Step 7: Record D-202 and commit** `docs: Phase 13 spike answers (D-202)`.
  - D-202 holds each spike's answer as pass or fail, per app and per format, and the choices below.

**What each outcome changes** (the spec's "If a spike fails", and R13-7):

| Spike | Passes | Fails |
|---|---|---|
| 1 Picker grants survive a restart | Task 2 stands | Stop: no fallback in the spec; the owner decides before Task 6 |
| 2 A video and a photo under `Pictures/`, one VN album in name order | Root = `pictures` | Video refused under `Pictures/`: root = `dcim` (`DCIM/TakeTray/<folder>/`) if Step 5 passes. VN refuses HEIC: Task 11 for VN. Two albums or the wrong order: stop, ask the owner |
| 3 CapCut, Edits and the chooser take `*/*` and HEIC | Task 9 as written; Tasks 10 and 11 not built (unless Spike 2 needs 11) | An editor refuses mixed: Task 10 for that editor. An editor refuses HEIC: Task 11 for that editor |
| 4 CapCut's and Edits' pickers list `Pictures/TakeTray/<folder>/` | Root stays `pictures` | Retry on `DCIM` (Step 5); passes: root = `dcim`; neither root passes 2 and 4: stop, ask the owner |

**Which tasks wait:**
- Task 6, Task 7 and Task 8 wait on Spikes 2 and 4 (the root). If the root is `dcim`, read `dcim` / `"DCIM"` wherever this plan says `pictures` / `"Pictures"`.
- Task 9 and Task 10 wait on Spike 3.
- Task 11 waits on Spikes 2 and 3.
- Task 12 waits on all four (its assertions name the root and the share type).

---

### Task 6: The copy root, native: per-root folders, photo copies and the bridge

**Model:** Opus. **D-203** (amends D-121, D-122). **Waits on:** Spikes 2 and 4.

**Files:**
- Create: `app/lib/domain/models/copy_root.dart`, `app/test/domain/models/copy_root_test.dart`.
- Modify:
  - Pigeon: `app/pigeons/copy_api.dart`, `app/pigeons/editors_api.dart` (+ generated)
  - Kotlin: `editors/CopyFolderPath.kt`, `CopyFolder.kt`, `CopyStore.kt`, `CopyEngine.kt`, `CopyJob.kt`, `CopyHostApiImpl.kt`, `EditorsHostApiImpl.kt`, `app/android/app/src/debug/kotlin/app/taketray/DebugCopyHooks.kt`
  - Dart: `app/lib/platform/copy_bridge.dart`, `app/lib/platform/editors_bridge.dart`, `test/support/fake_copy_bridge.dart`, `test/support/fake_editors_bridge.dart`, `app/lib/data/editors/edit_session_service.dart` (passes `CopyRoot.movies` everywhere: the stop-gap until Task 7)
- Test:
  - Kotlin: `CopyFolderPathTest.kt`, `CopyFolderTest.kt` (+ `CopyFolderProvider.kt`), `CopyStoreTest.kt`, `CopyEngineTest.kt`, `CopyJobTest.kt`, `CopyHostApiImplTest.kt`, `EditorsHostApiImplTest.kt`, `DebugCopyHooksTest.kt`
  - Dart: `test/platform/copy_bridge_test.dart`, `editors_bridge_test.dart`, `fake_copy_bridge_test.dart`, `fake_editors_bridge_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // copy_root.dart (stored by name; never reorder-sensitive)
  enum CopyRoot { movies, pictures }
  extension CopyRootDir on CopyRoot { String get dir; } // 'Movies', 'Pictures'
  /// Where every new editing session copies (D-202's answer).
  const CopyRoot newCopyRoot = CopyRoot.pictures;
  /// "Pictures/TakeTray/Goa": the path shown to the user.
  String copyFolderPath(CopyRoot root, String folder);
  ```
  - Pigeon:
    - `enum CopyRootMsg { movies, pictures }`;
    - `CopyRequestMsg.root`, `CopyFileRefMsg.root`, `CopyFolderFileMsg.root`;
    - `ownRowsIn(CopyRootMsg root, String folderName)` and `deletePendingIn(CopyRootMsg root, String folderName)`;
    - `copyFolderNames()`: the union of both roots, sorted (R13-6);
    - `filesInCopyFolders()`: both roots, each file with its root.
  - Dart bridge models gain `CopyRoot root`: `CopyRequest`, `CopyFileRef`, `CopyFolderFile`. `CopyBridge.ownRowsIn(CopyRoot root, String folderName)` and `deletePendingIn(CopyRoot root, String folderName)`.
  - Kotlin:
    ```kotlin
    enum class CopyRoot(val dir: String) { MOVIES("Movies"), PICTURES("Pictures") }
    object CopyFolderPath {
      fun rootPath(root: CopyRoot): String                   // "Pictures/TakeTray/"
      fun relativePath(root: CopyRoot, folder: String): String
      fun isInFolder(rowRelativePath: String?, root: CopyRoot, folder: String): Boolean
      fun startsWithRoot(path: String, root: CopyRoot): Boolean
    }
    // CopyStore.insertPending(root, folder, fileName, mimeType); ownRowsIn(root, folder); deletePendingIn(root, folder)
    ```
- **Rules:**
  - **The guard, per root:**
    - exactly `<root>/TakeTray/<folder>/` in ASCII case, no Unicode lookalike, never deeper, never `<root>/TakeTray Test/`, with the exact name and our owner (D-121);
    - a Movies ref never touches a Pictures row, and the other way round.
  - **Two collections (R13-6):**
    - `CopyFolder` reads the Video and the Images collections and keeps each row's collection;
    - deletes and `deletableUris` use that collection's item URI;
    - the delete's selection repeats path, name and owner as today.
  - **Inserting:**
    - an `image/…` source goes into the Images collection, anything else into Video;
    - the bytes are copied as they are, and the progress and space checks are unchanged;
    - `CopyJob` passes the item's `mimeType` (already in `CopySourceMsg`).
  - **No change for Movies:** every existing Kotlin test passes with `CopyRoot.MOVIES` added to its calls, and nothing else. The Dart side passes `CopyRoot.movies`, so the app behaves exactly as before this task.
  - **`DebugCopyHooks`** follows the root argument. It still refuses `TakeTray Test` folders.

- [ ] **Step 1: Characterization first.** Run `cd app && ../tool/test_android --tests 'app.taketray.editors.*' --tests 'app.taketray.DebugCopyHooksTest'`. Expected: PASS, recorded. Then add the `MOVIES` argument only and run again: still PASS.
- [ ] **Step 2: Write the failing Kotlin tests.**
  - `CopyFolderPathTest.kt`:
    ```kotlin
    @Test fun `Pictures root: exactly Pictures slash TakeTray slash folder, any ASCII case`()
    @Test fun `Pictures slash TakeTray Test, DCIM slash TakeTray and a deeper folder are never a Pictures copy folder`()
    @Test fun `a Kelvin sign or a dotless i never matches either root`()
    ```
  - `CopyFolderTest.kt`:
    ```kotlin
    @Test fun `an own photo copy in Pictures slash TakeTray slash Goa passes the guard and is deleted through the Images collection`()
    @Test fun `an own video copy in Pictures slash TakeTray slash Goa passes the guard`()
    @Test fun `a Movies ref never deletes a Pictures row with the same id path or name, and the other way round`()
    @Test fun `a photo row in Pictures slash TakeTray Test is refused and untouched`()
    @Test fun `existingCopies finds a photo copy and a video copy in Pictures`()
    @Test fun `filesInCopyFolders lists both roots and both collections, each file with its root`()
    @Test fun `copyFolderNames is the union of both roots, sorted`()
    @Test fun `deletableUris gives an Images item URI for a photo row and a Video one for a video`()
    ```
  - `CopyStoreTest.kt`:
    ```kotlin
    @Test fun `a photo is inserted pending into the Images collection under its root; a video into Video`()
    @Test fun `ownRowsIn Pictures Goa reads both collections, own rows only`()
    @Test fun `deletePendingIn deletes own pending rows of both collections and nothing else`()
    ```
  - `CopyJobTest.kt`: `'a Pictures job copies a photo byte for byte and a video, in order, and reports both'`.
  - `CopyHostApiImplTest.kt` and `EditorsHostApiImplTest.kt`: `'every message's root reaches the store and the guard'`.
- [ ] **Step 3: Write the failing Dart tests.**
  - `copy_root_test.dart`:
    - `'dir: Movies, Pictures'`;
    - `'copyFolderPath(pictures, "Goa") is "Pictures/TakeTray/Goa"'`;
    - `'the stored names are movies and pictures'`.
  - `copy_bridge_test.dart` and `editors_bridge_test.dart`: `'root is mapped both ways on every message and call'`; the fakes record it.
- [ ] **Step 4: Run** the Kotlin command and `cd app && ../tool/flutter test test/platform test/domain/models/copy_root_test.dart`. Expected: FAIL.
- [ ] **Step 5: Implement** the Pigeon changes and regenerate; then `CopyFolderPath`, `CopyFolder`, `CopyStore`, `CopyEngine`, `CopyJob`, the host APIs and the debug hooks; then the Dart enum, bridges and fakes, with `CopyRoot.movies` at every call in `edit_session_service.dart`.
- [ ] **Step 6: Run** both commands and `cd app && ../tool/flutter test test/data/editors`, then `tool/check`. Expected: PASS (the service tests are unchanged); `ALL CHECKS PASSED`.
- [ ] **Step 7: Mutation checks:**
  - `isInFolder` ignoring the root: `'a Movies ref never deletes a Pictures row …'` fails;
  - insert every source into Video: `'a photo is inserted pending into the Images collection …'` fails;
  - `copyFolderNames` from Movies only: `'… union of both roots …'` fails;
  - `deletableUris` always from Video: its test fails.
- [ ] **Step 8: Docs and commit** `feat(editors): copy folders under Movies or Pictures, and photo copies`.
  - **D-203:** the root enum and why it is a message field (spec: "The native copy messages carry the root with the folder name"); the guard per root; the two collections (R13-6); the stop-gap.
  - D-121 and D-122 get "Amended by D-203".
  - `flow.md`: "Editors bridge and the copy folder guard", "Copying clips".

---

### Task 7: The copy root in the app: schema v3, the session's root, plans and strings

**Model:** Opus. **D-204** (amends D-120, D-123, D-127, D-128, D-129 and D-130). **Waits on:** Spikes 2 and 4.

**Files:**
- Create: `app/test/l10n/copy_root_strings_test.dart`, `app/drift_schemas/taketray/drift_schema_v3.json` (by `make-migrations`).
- Modify:
  - Database: `app/lib/data/database/tables.dart`, `app_database.dart` (+ `.steps.dart`, `.g.dart`)
  - Models and repository: `app/lib/domain/models/edit_session.dart`, `app/lib/domain/models/copy_job_plan.dart`, `app/lib/data/repositories/edit_sessions_repository.dart`
  - Service: `app/lib/data/editors/edit_session_service.dart` (`CopyPlan.root`, `OrphanFolder.root`)
  - Screens: `copy_space_screen.dart`, `copy_progress_screen.dart`, `copy_ready_screen.dart`, `edit_select_screen.dart`, `edit_select_controller.dart`, `reel_edit_banner.dart`, `delete_reel_dialog.dart`, `copies_storage_controller.dart`, `copies_storage_screen.dart`
  - `app/lib/l10n/app_en.arb`
  - The comments naming `Movies/TakeTray/` in `tables.dart`, `undo_writer.dart`, `backup_actions.dart`, `edit_folder_name.dart`, `editors_bridge.dart` and `copy_bridge.dart`
- Test:
  - Database: `test/drift/taketray/migration_test.dart`, `schema_test.dart` (regenerated helpers)
  - Data: `test/data/repositories/edit_sessions_repository_test.dart`, `test/data/editors/edit_session_service_test.dart`
  - Screens and strings: `test/features/editors/*`, `test/features/reels/reel_edit_banner_test.dart`, `delete_reel_test.dart`, `test/l10n/vn_copy_strings_test.dart`, `capcut_add_strings_test.dart`, `reel_editing_strings_test.dart`, `copies_storage_strings_test.dart`
  - Goldens: `copy_golden_test.dart`, `copies_storage_golden_test.dart`

**Interfaces:**
- Consumes: Task 6 (`CopyRoot`, `newCopyRoot`, `copyFolderPath`, the bridge's `root`).
- Produces:
  ```dart
  // tables.dart, EditSessions (SQL vn_sessions), added in v3:
  TextColumn get copyRoot => textEnum<CopyRoot>().withDefault(const Constant('movies'))();
  // AppDatabase.schemaVersion = 3; _from2To3: addColumn(vnSessions.copyRoot)
  // EditSession
  @Default(CopyRoot.movies) CopyRoot root,
  // EditSessionsRepository.startSession(reelId, editor, folder, {required CopyRoot root, alsoTaken})
  // CopyJobPlan: final CopyRoot root; JSON key 'root'; missing → movies
  // CopyPlan: final CopyRoot root;  OrphanFolder: final CopyRoot root;
  ```
- **Rules:**
  - **New sessions** (a VN copy, a CapCut or Edits send) are made with `root: newCopyRoot`.
  - **Every later step reads `session.root`:** add-later plans, `existingCopies`, `deleteCopies`, Done editing, the delete-reel copies, `verifyCopies` and the copy job's request. The saved plan carries it too. Nothing probes the other root.
  - **A new folder's name** is checked against `copyFolderNames()`, which already holds both roots (R13-6).
  - **The storage screen (D-130):**
    - sessions as today;
    - "Not linked to a reel" lists the folders of both roots. Each row is the folder's name over `copiesStorageOrphanWhere(root)`, and `deleteOrphans` asks the consent dialog for that root's files;
    - the callout is unchanged.
  - **The strings:**
    - each string that names `Movies/TakeTray` or `Movies › TakeTray` takes `{root}`, filled with `root.dir`;
    - `vnCopyWhyBody` and `projectCopyWhyBody` get `copyFolderPath(plan.root, folder)` (`copy_space_screen.dart:265` stops hard-coding `Movies`).
  - **Backups:** unchanged. Sessions are never exported (D-120), and an import ends them as today.
- **Strings** (each the current text with `{root}`):
  - `copyProgressBytes`: `"{done} of {all} · into {root}/TakeTray/{folder}"`
  - `vnStep2Body`: `"Inside {root} › TakeTray."`
  - `projectStep2Body`: `"It's in {root} › TakeTray."`
  - `reelEditingCopies`: `"{count, plural, one{1 copy in {root}/TakeTray/{folder}} other{{count} copies in {root}/TakeTray/{folder}}}"`
  - `reelEditingSentOnCopies`: `"Sent on {date} · {count, plural, one{1 copy in {root}/TakeTray/{folder}} other{{count} copies in {root}/TakeTray/{folder}}}"`
  - `editAddFolderBarDetail`: `"{size} · into {root}/TakeTray/{folder}"`
  - `deleteReelFolderCopies`: `"{count, plural, one{The 1 copy in {root}/TakeTray/{folder} ({size}) will also be deleted.} other{The {count} copies in {root}/TakeTray/{folder} ({size}) will also be deleted.}}"`
  - new `copiesStorageOrphanWhere`: `"In {root} › TakeTray"`
  - the `vnCopyWhyBody` and `projectCopyWhyBody` descriptions name both roots.

- [ ] **Step 1: Write the failing tests.**
  - `migration_test.dart` (by hand; the generated loop covers v1→v3 and v2→v3 schemas):
    ```dart
    test('migration from v2 to v3 keeps every row; every session is in Movies', …) // real-looking v2 rows: a VN and a CapCut session with copies and sent rows
    test('a v3 step that fails half way leaves the v2 file as it was', …)
    ```
  - `edit_sessions_repository_test.dart`: `'startSession stores the root; sessionOf and summaries read it'`.
  - `edit_session_service_test.dart`:
    ```dart
    test('a new VN copy starts a Pictures session and sends Pictures in the request', …)
    test('a new CapCut send starts a Pictures session', …)
    test('a session from before the update keeps Movies for add-later, checks, resume and Done editing', …) // Review Focus 3
    test('a saved plan with no root resumes into Movies', …)
    test('deleting a reel deletes its copies under its session's root', …)
    test('storage: orphans from both roots, each with its root; deleteOrphans asks for that root', …)
    test('a new folder name skips names taken in either root', …)
    ```
  - `copy_root_strings_test.dart`:
    - `'no string in app_en.arb names Movies'` (it reads the file);
    - `'each copy-path string renders with Pictures and with Movies'`.
  - Screens:
    - `'the space screen's Why copies? names Pictures/TakeTray/Goa for a new edit and Movies/TakeTray/Goa for an old one'`;
    - the same pair for the progress line, the ready steps, the reel banner, the add bar and the delete-reel text;
    - `'the storage screen lists a Movies folder and a Pictures folder, each read with its root'`.
  - The existing `test/l10n/*_strings_test.dart` pins are updated to the `{root}` text, rendered with Movies (the old words) and with Pictures.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/drift test/data test/features/editors test/features/reels test/l10n`. Expected: FAIL.
- [ ] **Step 3: Implement:**
  - the column and the version bump;
  - `build_runner`, then `make-migrations`, and commit the v3 dump;
  - `_from2To3`;
  - the model, repository, plan and service changes (the stop-gap from Task 6 goes);
  - the screens and the strings.
- [ ] **Step 4: Run** the same command, then `--update-goldens` for `copy_golden_test.dart` and `copies_storage_golden_test.dart` (look at them: the paths now read Pictures, and the storage screen has a root line), then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - start sessions with `CopyRoot.movies`: `'a new VN copy starts a Pictures session …'` fails;
  - build add-later refs with `newCopyRoot` instead of `session.root`: `'a session from before the update keeps Movies …'` fails;
  - read a plan's missing root as `pictures`: `'a saved plan with no root resumes into Movies'` fails;
  - put "Movies" back in `vnStep2Body`: `'no string in app_en.arb names Movies'` fails.
- [ ] **Step 6: Docs and commit** `feat(editors): every new copy goes to Pictures/TakeTray; old edits stay in Movies`.
  - **D-204:**
    - the column, its default and why per session (spec §6, "(my call)");
    - "every copy" means every editor;
    - the legacy rules;
    - the storage screen's two roots;
    - the strings;
    - backups unchanged.
  - D-120, D-123, D-127, D-128, D-129 and D-130 get "Amended by D-204".
  - `flow.md`:
    - "Database open and migrations" (v3, `_from2To3`);
    - "Editing a reel";
    - "The VN copy screens";
    - "The VN copies storage screen".

---

### Task 8: VN with photos, and copies stay out of the clips

**Model:** Sonnet. **D-205** (amends D-119, D-130's point 10 and D-149's own-folder rule). **Waits on:** Spikes 2 and 4 (the root). It is built without HEIC conversion. Task 11 adds that if Spike 2 says VN refuses HEIC.

**Files:**
- Modify:
  - Copy names: `app/lib/domain/rules/copy_file_names.dart`, and its callers in `edit_session_service.dart` (`CopyNameSource.photo`)
  - The exclusion: `app/lib/domain/rules/chat_folders.dart`, `app/lib/domain/rules/browse_folders.dart`, `app/lib/data/media/media_scanner.dart` (the two watched-folder reads), `app/lib/data/background/background_sync.dart`
  - Copy counts: `app/lib/features/editors/views/copy_space_screen.dart`, the add-mode bar in `edit_select_screen.dart`, and the copied snack
  - `app/lib/l10n/app_en.arb`
- Test:
  - Rules: `test/domain/rules/copy_file_names_test.dart`, `chat_folders_test.dart`, `browse_folders_test.dart`
  - Scans: `test/data/media/media_scanner_test.dart`, `add_earlier_test.dart`, `test/data/background/` (the state written)
  - Hand-off: `test/data/editors/edit_session_service_test.dart`, `test/features/editors/copy_space_screen_test.dart`, `edit_select_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 (`isPhoto`), Task 3 (`clipsAndPhotosText`), Task 6 (`CopyRoot`), Task 7 (session root).
- Produces:
  ```dart
  // copy_file_names.dart
  String copyExtension(String displayName, String mimeType); // photos added, videos unchanged
  class CopyNameSource { … final bool photo; } // default false
  // chat_folders.dart
  /// <any copy root dir>/TakeTray, first two segments, A to Z case only.
  bool isOwnCopyFolder(String relativePath);
  /// [folders] without the ones isOwnCopyFolder rejects (R13-8).
  List<String> scannableFolders(List<String> folders);
  ```
- **Rules:**
  - **Photo extensions:**
    - the display name's, lower-cased, when it is one of `jpg jpeg heic heif png webp gif avif dng`;
    - else from the type: `image/jpeg` → `jpg`, `image/heic` → `heic`, `image/heif` → `heif`, `image/png` → `png`, `image/webp` → `webp`, `image/gif` → `gif`, `image/avif` → `avif`;
    - else, for an image type, `jpg`;
    - a video's extension is unchanged (`mp4` fallback), and a video named `x.jpg` still gets the video rule.
  - **Names (R13-10):** a stem already used by a clip earlier in shooting order, with any extension, makes the next one `_2` when either of the two is a photo. Two videos keep D-119's rule.
  - **VN's plan:**
    - photos are live clips of the reel, so they are planned, sized (the space check counts their bytes) and copied in shooting order;
    - add mode offers a photo not yet copied (with Task 3's symbol);
    - the copy is byte for byte.
  - **The exclusion:**
    - `isOwnCopyFolder` and `browse_folders`' own-copy check cover every `CopyRoot.dir` (Movies, Pictures; DCIM if that is the root) with `TakeTray` as the second segment;
    - `TakeTray Test`, `TakeTrayX` and other roots' `TakeTray` stay;
    - the scanner's two reads of `watchedFolders` and `background_sync`'s state write go through `scannableFolders`.
  - **Copy counts:** with photos among the copies, use the strings below; without photos, today's.
- **Strings:**
  - `copyStartWith`: `"Copy {counts}"`
  - `copySpaceNeedWith`: `"{counts} need {size}"`
  - `copyAddedSnackWith`: `"{counts} added to the {editor} folder"`

- [ ] **Step 1: Write the failing tests.**
  - `copy_file_names_test.dart`:
    ```dart
    test('photo extensions: IMG_1.HEIC → heic, a.jpeg → jpeg, no name + image/png → png, no name + image/x-foo → jpg', …)
    test('a video keeps its rule: x.jpg + video/mp4 → mp4', …)                       // characterization
    test('a photo and a video in the same second: the later in shooting order takes _2', …) // 10-00-00.mp4, 10-00-00_2.jpg
    test('two videos in the same second with different extensions keep D-119's rule', …)    // characterization
    ```
  - `chat_folders_test.dart` / `browse_folders_test.dart`:
    ```dart
    test('Pictures/TakeTray and Pictures/TakeTray/Goa are own copy folders; any ASCII case', …)
    test('Pictures/TakeTray Test, Pictures/TakeTrayX, DCIM/TakeTray (unless DCIM is the root) are not', …)
    test('browseFolders leaves out Pictures/TakeTray/Goa on the phone's volume only', …)
    test('scannableFolders drops own copy folders and keeps the order of the rest', …)
    ```
  - `media_scanner_test.dart`, `add_earlier_test.dart`, background:
    - `'a stored watched folder inside a copy root is never scanned or counted'` (Review Focus 2: the scan, Add earlier videos and the native state all leave it out; Settings still lists it).
  - `edit_session_service_test.dart`:
    ```dart
    test('VN plan with photos: in shooting order, photo names with their extension', …)
    test('photos only: the plan counts their bytes', …)  // Review Focus 5
    test('add mode plans a photo added after the first copy', …)
    ```
  - `copy_space_screen_test.dart`: `'with photos: "Copy 3 clips and 2 photos", "3 clips and 2 photos need 1.2 GB"; without: as today'`.
  - `edit_select_screen_test.dart`: `'add mode copied snack: "1 clip and 1 photo added to the VN folder"'`.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/domain/rules test/data/media test/data/background test/data/editors test/features/editors`. Expected: FAIL.
- [ ] **Step 3: Implement** the extensions and the same-second rule, `CopyNameSource.photo` at the caller, the folder rules and `scannableFolders` at the three reads, and the count strings.
- [ ] **Step 4: Run** the same command, then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop `scannableFolders` from the scanner: `'a stored watched folder inside a copy root …'` fails;
  - check only `movies` in `isOwnCopyFolder`: `'Pictures/TakeTray … are own copy folders'` fails;
  - apply the same-second rule to two videos: the D-119 characterization fails.
- [ ] **Step 6: Docs and commit** `feat(editors): VN copies photos in shooting order; copy folders stay out of the clips`.
  - **D-205:** the extension table; R13-10; the space check; add mode; R13-8 and why the folder stays in Settings; the copy counts.
  - D-119, D-130 and D-149 get "Amended by D-205".
  - `flow.md`: "Editing rules", "Watched folders", "Finding new clips", "The folder browser".

---

### Task 9: CapCut, Edits and Other app…: the share's types, and the Sent snack

**Model:** Sonnet. **D-206** (amends D-121, D-126). **Waits on:** Spike 3. If Spike 3 says an editor refuses a mixed share, this task still builds the types, and Task 10 then changes that editor's path.

**Files:**
- Modify:
  - Share: `app/pigeons/editors_api.dart` (`ShareClipMsg.mimeType`, + generated), `editors/ShareIntents.kt`, `app/android/app/src/debug/kotlin/app/taketray/DebugEditorHooks.kt` (the recorder shows the type)
  - Dart: `app/lib/platform/editors_bridge.dart`, `test/support/fake_editors_bridge.dart`, `app/lib/data/editors/edit_session_service.dart` (`SendOutcome`), `app/lib/features/editors/views/editor_sheet.dart` (`_Sent`)
  - `app/lib/l10n/app_en.arb`
- Test: `ShareIntentsTest.kt`, `EditorsHostApiImplTest.kt`, `DebugEditorHooksTest.kt`, `test/platform/editors_bridge_test.dart`, `test/data/editors/edit_session_service_test.dart`, `test/features/editors/editor_sheet_test.dart`, `test/features/reels/views/clip_viewer_screen_test.dart` (Share).

**Interfaces:**
- Consumes: Task 1 (`ClipRef.isPhoto`), Task 3 (`clipsAndPhotosText`).
- Produces:
  ```dart
  // ShareClipMsg gains `String mimeType;`
  // SendOutcome
  const SendOutcome(this.result, this.sentCount, {this.sentPhotos = 0}); // sentPhotos in ==, hashCode
  ```
  - Kotlin:
    - `ShareIntents.typeOf(clips: List<ShareClipMsg>): String`: `"video/*"` when none is a photo, `"image/*"` when all are, `"*/*"` when mixed;
    - `TYPE` stays `"video/*"` for videos.
- **Rules:**
  - The send and chooser intents take `typeOf(clips)`. ClipData's description lists `video/*` and/or `image/*` for the kinds present, in that order. Order and read grant are as today.
  - A photo is read from its picker address only. With none, it is left out (R13-9), and counted in the left-out log line.
  - `sendOriginals` counts live photos into `sentPhotos`, and `sentCount` stays the number of items sent. `_Sent` shows `editorSentSnackWith(counts, editor)` when `sentPhotos > 0`, else today's `editorSentSnack`.
  - The viewer's **Share** and **Other app…** use the same intents, so a photo alone is `image/*`.
- **Strings:**
  - `editorSentSnackWith`: `"Sent {counts} to {editor}"`

- [ ] **Step 1: Write the failing tests.**
  - `ShareIntentsTest.kt`:
    ```kotlin
    @Test fun `videos only: video star, as before`()                    // characterization
    @Test fun `photos only: image star`()
    @Test fun `mixed: star star, ClipData lists video star then image star, order kept`()
    @Test fun `a photo with no picker address is left out, never a Video URI`()
    @Test fun `the chooser carries the same type and grant`()
    ```
  - `DebugEditorHooksTest.kt`: `'the recorded intent has the type'`.
  - `edit_session_service_test.dart`:
    - `'CapCut with 2 videos and 1 photo: one share, sentCount 3, sentPhotos 1, in shooting order'`;
    - `'a missing photo is not sent or counted'`.
  - `editor_sheet_test.dart`:
    - `'Sent with photos: "Sent 2 clips and 1 photo to CapCut"'`;
    - `'Sent without photos: as today'`;
    - `'photos only: image/*'` (the fake bridge's recorded clips are all photos and the snack reads "Sent 2 photos to Edits").
- [ ] **Step 2: Run** `cd app && ../tool/test_android --tests 'app.taketray.editors.ShareIntentsTest' --tests 'app.taketray.DebugEditorHooksTest'` and `cd app && ../tool/flutter test test/platform test/data/editors test/features/editors test/features/reels/views/clip_viewer_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the Pigeon field and regenerate, then `typeOf` and the ClipData types, the recorder, the mapping, `sentPhotos` and the snack.
- [ ] **Step 4: Run** both commands, then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - `typeOf` that ignores photos: `'mixed: star star …'` fails;
  - build a Video URI for a photo with no address: its test fails;
  - leave `sentPhotos` out of `==`: the service test fails.
- [ ] **Step 6: Docs and commit** `feat(editors): shares carry photos with the videos`.
  - **D-206:** the type rule and Spike 3's answer; R13-9; the snack.
  - D-121 and D-126 get "Amended by D-206".
  - `flow.md`: "Editors bridge and the copy folder guard" (share), "Picking clips and the editor sheet" (snack).

---

### Task 10 (only if Spike 3 shows an editor refusing a mixed share): photos as copies for that editor

**Model:** Opus. **D-207** (amends D-129). **Waits on:** Spike 3 and Task 9. If it is not needed, D-207 is one line, "Not built: CapCut and Edits took a mixed share in Spike 3 (D-202)", and this task is skipped.

**Files:**
- Modify: `app/lib/domain/models/editor_app.dart`, `app/lib/data/editors/edit_session_service.dart`, `app/lib/features/editors/views/editor_sheet.dart`, `app/lib/l10n/app_en.arb`.
- Test: `test/domain/models/editor_app_test.dart`, `test/data/editors/edit_session_service_test.dart`, `test/features/editors/editor_sheet_test.dart`.

**Interfaces:**
- Produces:
  ```dart
  extension on EditorApp { bool get takesMixedShares; } // false for the editors D-202 names
  // SendOutcome gains: final String? photoCopyJobId; // the copy job started for the photos, if any
  ```
- **Rules** (the spec's §6 "(my call)"):
  - for an editor with `takesMixedShares == false`, `sendOriginals` shares the live videos as today. In the same call it plans and starts a copy of the live photos into the session's folder (the D-129 add-later path: `planCopy` then `startCopy`). It stays one tap for the user, with no second share sheet;
  - **photos only** to such an editor: the share is skipped if Spike 3 also refused `image/*` for it; else `image/*` as Task 9;
  - **the snack:** `editorSentPhotosAsCopies(clips, editor, photos, root)`. A copy that cannot start (no space, `CopyBusy`) keeps the sent videos and says `editorPhotosNotCopied`;
  - the copies are recorded like any add-later copy, and Done editing deletes them.
- **Strings:**
  - `editorSentPhotosAsCopies`: `"Sent {clips} to {editor}. Add the {photos} from {root} › TakeTray"`. It reads "Sent 8 clips to CapCut. Add the 2 photos from Pictures › TakeTray", the spec's words.
  - `editorPhotosNotCopied`: `"Couldn't copy the photos. Add them from the reel later."`

- [ ] **Step 1: Write the failing tests:**
  ```dart
  test('takesMixedShares: false only for the editors D-202 names', …)
  test('a refusing editor: the videos shared, the photos copied into the session folder, one call', …)
  test('a refusing editor with no space for the photos: the videos stay sent; photoCopyJobId null', …)
  testWidgets('the snack: "Sent 8 clips to CapCut. Add the 2 photos from Pictures › TakeTray"', …)
  testWidgets('one tap: no second share sheet opens', …)
  ```
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/domain/models/editor_app_test.dart test/data/editors test/features/editors`. Expected: FAIL.
- [ ] **Step 3: Implement** the flag, the split send and the snack.
- [ ] **Step 4: Run** the same command, then `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation check:** share the photos too for a refusing editor: `'a refusing editor: the videos shared, the photos copied …'` fails.
- [ ] **Step 6: Docs and commit** `feat(editors): photos reach an editor that refuses a mixed share as copies`. **D-207**, with D-129 amended, and `flow.md` "Editing a reel".

---

### Task 11 (only if Spike 2 or 3 shows a HEIC refusal): HEIC to JPEG for that hand-off

**Model:** Opus. **D-208**. **Waits on:** Spikes 2 and 3, and Tasks 8–10. If it is not needed, D-208 is one line, "Not built: VN, CapCut and Edits took HEIC in Spikes 2 and 3 (D-202)".

**Files:**
- Create: `editors/HeicToJpeg.kt`, `app/android/app/src/test/kotlin/app/taketray/editors/HeicToJpegTest.kt`.
- Modify: `app/pigeons/copy_api.dart` (`CopyItemMsg.toJpeg`, + generated), `editors/CopyJob.kt`, `app/lib/domain/models/editor_app.dart`, `app/lib/domain/rules/copy_file_names.dart`, `app/lib/data/editors/edit_session_service.dart`.
- Test: `CopyJobTest.kt`, `test/domain/rules/copy_file_names_test.dart`, `test/data/editors/edit_session_service_test.dart`.

**Interfaces:**
- Produces:
  - Kotlin: `object HeicToJpeg { fun convert(input: InputStream, output: OutputStream, decode: … = …) }` with Android's own `ImageDecoder` (orientation applied) and `Bitmap.compress(JPEG, 95)`;
  - Dart: `extension on EditorApp { bool get takesHeic; }` and `CopyItemMsg.toJpeg`.
- **Rules:**
  - only `image/heic` and `image/heif` photos, and only for an editor with `takesHeic == false`, are converted, "for that hand-off only". Every other copy stays byte for byte;
  - the converted copy is named `.jpg` and inserted as `image/jpeg`;
  - the space check counts the original's size;
  - for a share (R13-12), the HEIC photos become JPEG copies in the session's folder first. The share carries each copy's MediaStore address in that photo's shooting place, and Done editing deletes the copies;
  - a failed conversion counts as a failed copy, the existing "couldn't be copied" path.

- [ ] **Step 1: Write the failing tests:**
  ```kotlin
  @Test fun `convert writes a JPEG from a HEIC source, orientation applied`()  // fake decoder
  @Test fun `a toJpeg item is converted and inserted as image jpeg; a plain item is byte for byte`()
  @Test fun `a conversion that throws is a failed item; the job goes on`()
  ```
  ```dart
  test('VN refusing HEIC: a HEIC photo's copy is named .jpg and marked toJpeg; a JPEG photo is not', …)
  test('CapCut refusing HEIC: the HEIC photo goes as its JPEG copy's address in its place', …)
  ```
- [ ] **Step 2: Run** `cd app && ../tool/test_android --tests 'app.taketray.editors.*'` and `cd app && ../tool/flutter test test/domain/rules/copy_file_names_test.dart test/data/editors`. Expected: FAIL.
- [ ] **Step 3: Implement** the conversion, the flag, the names and the service's choice.
- [ ] **Step 4: Run** both commands, then `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation check:** convert every photo: `'… a JPEG photo is not'` fails.
- [ ] **Step 6: Docs and commit** `feat(editors): HEIC photos go as JPEG to an editor that refuses HEIC`. **D-208**, and `flow.md` "Copying clips".

---

### Task 12: Patrol: the photo flows (no device)

**Model:** Sonnet. **D-209** (amends D-197's flow lists). **Waits on:** Task 5 (all spikes) and Tasks 6–11.

**Files:**
- Create: `app/patrol_test/photos_test.dart`.
- Modify:
  - Debug Kotlin: `app/android/app/src/debug/kotlin/app/taketray/TestMedia.kt` (`TestMediaGuard.PHOTO_FOLDER`, `insertPhoto`, `deleteLeftovers` covers it), `TestMediaHandler.kt`
  - Patrol: `app/patrol_test/support/test_media.dart` (`insertPhoto`, `InsertedPhoto`), `app/patrol_test/editors_test.dart` (`ownRowsIn(CopyRoot.pictures, …)`; folder assertions under Pictures)
  - Docs: `docs/dev-setup.md` ("Running `photos_test.dart`", and the editors flow's folder), `docs/flow.md` ("On-device test (Patrol)")
- Test: `TestMediaTest.kt`, `TestMediaGuardTest.kt`, `TestMediaHandlerTest.kt`, `app/test/patrol_support/` (any finder added).
- Check only: the other Patrol files compile and assume no copy root. Record "no change needed" or fix what `analyze` shows.

**Interfaces:**
- Produces:
  ```dart
  // test_media.dart
  /// A small JPEG TakeTray Dev makes itself (a plain colour, 96 x 128, DATE_TAKEN
  /// [takenAt]) in `Pictures/TakeTray Test/`; deleted by cleanUp, also on failure.
  Future<InsertedPhoto> insertPhoto({required DateTime takenAt});
  class InsertedPhoto { final int mediaStoreId; final String contentUri; }
  ```
  - Kotlin: `TestMedia.insertPhoto(takenAtMs): Long` writes `Bitmap.compress(JPEG)` bytes into the Images collection at `PHOTO_FOLDER = "Pictures/TakeTray Test/"`. The guard accepts only that folder (any case) and its own rows.
- **The flows** (`photos_test.dart`). Each test makes its reel `TakeTray Test <timestamp>` through the repository, adds the photo as a picker clip whose address is the inserted photo's own content URI (no picker is driven: it lists the owner's photos, D-115), and tears everything down also on failure:
  1. `'A photo among videos: the photo symbol, read "Clip, {time}, Photo"; the header "2 videos · 1 photo · 0:0X"; the viewer shows the still with no play, mute or scrubber; a swipe to the video plays it, a swipe back pauses it'`
  2. `'VN copy with a photo: 3 own rows in <root>/TakeTray/<reel>/, the photo named .jpg, in shooting order; Done editing deletes all 3'`
  3. `'CapCut with a video and a photo: one recorded SEND_MULTIPLE to CapCut, type */* (Spike 3's answer), 2 addresses in shooting order, read grant; "Sent 1 clip and 1 photo to CapCut"'`. If Task 10 was built for CapCut, the flow asserts Task 10's path instead.
  4. `'Remove a photo with Undo, then Move it to a second reel: the counts follow'`
- Keep the files' safety patterns: positive waits before every absent check, tear-downs that run on failure, only the two test folders plus TakeTray Dev's own copy folder, raw taps without settling.

- [ ] **Step 1: Write the failing Kotlin tests:**
  - `TestMediaGuardTest.kt`:
    - `'PHOTO_FOLDER accepts Pictures/TakeTray Test/ in any case and nothing else'`;
    - `'Pictures/TakeTray/ is refused'`.
  - `TestMediaTest.kt`:
    - `'insertPhoto writes a JPEG into the Images collection in PHOTO_FOLDER with DATE_TAKEN'`;
    - `'deleteLeftovers removes own photos and videos from both test folders only'`.
- [ ] **Step 2: Run** `cd app && ../tool/test_android --tests 'app.taketray.TestMedia*'`. Expected: FAIL. Then implement, and they PASS.
- [ ] **Step 3: Write** `photos_test.dart` and the `test_media.dart` support, and update `editors_test.dart`.
- [ ] **Step 4: Run** `cd app && ../tool/flutter analyze patrol_test` and `../tool/patrol build android`. Expected: no issues; the build succeeds. **Do not run on a device.**
- [ ] **Step 5: Mutation check:** let the guard accept `Pictures/TakeTray/`: `'Pictures/TakeTray/ is refused'` fails.
- [ ] **Step 6: Docs and commit** `test(patrol): photos in a reel, the viewer, VN copies and the mixed share`.
  - **D-209:** the four flows; why the picker is not driven; the photo test folder.
  - `dev-setup.md`: `tool/patrol test -d RZCY80PHWCZ -t patrol_test/photos_test.dart`.

---

### Task 13: Docs: the learning guide, README, later.md and the Phase 13 check

**Model:** Sonnet. No new decision. The step review may be skipped (docs only).

**Files:**
- Create: `docs/learn/phase-13-photos.md`.
- Modify: `README.md`, `docs/later.md`, `docs/dev-setup.md` (a new "Phase 13 check"), `docs/flow.md` (consistency pass only).

- [ ] **Step 1: The learning guide,** in the style of `docs/learn/phase-12b-edit-flow-calm-home.md`:
  - How to read;
  - one section per built task, and a line for each conditional task that was not built;
  - "A photo is a clip" (one table, one getter);
  - "A picker that needs no permission";
  - "Decoding a still natively, at screen size";
  - "Recording where copies go, per session" (the migration and the legacy root);
  - "Proving it on the phone first" (the spikes and what they chose);
  - a closing summary.
- [ ] **Step 2: README:**
  - a new row `| 13 | Photos in reels: add photos in a reel, and send them to editors with the videos | Built, phone check pending |`, and 12's "**Next: Phase 13**" moves to this row as "**Next: Phase 11**";
  - a "Phase 13: Photos in reels" section with one plain line per task (the readme-progress rule), "Phone tests: pending (Task 14)", and the learning guide's link.
- [ ] **Step 3: `later.md`:**
  - a "Phase 13" section;
  - **Photo copies TakeTray did not make**: "without photo permission, Android shows TakeTray only its own image rows. The storage screen and the cleanup see and delete only TakeTray's own photo copies. Photo copies left by an earlier install, or by the other build (Dev against release), are not seen; the user can delete them in Gallery." (the spec's words);
  - **Sharing a photo from Gallery into TakeTray** (a non-goal, later if asked);
  - **Zoom in the photo viewer** (a non-goal);
  - the parked Minors that are not fixed in the batch.
- [ ] **Step 4: `dev-setup.md` "Phase 13 check":** Task 14 Step 4's hand checks, numbered, each with what to look at and what passes.
- [ ] **Step 5:** Run `tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 6: Commit** `docs: Phase 13 learning guide, README, later.md and the phone check`.

---

### After Task 13 (controller)

1. The Minors batch (Sonnet), one commit.
2. The whole-phase review (Opus) with the spec, this plan and D-198 to D-209 in hand. Then one fix wave (Sonnet), and the re-review (the same Opus reviewer, resumed).
3. `cd app && ../tool/check_release_permissions`: it ends `RELEASE PERMISSIONS OK`, with the permission list unchanged from 5651f80 (diff the script's printed list against the base). A new permission is a Critical finding.
4. Push `phase-13-photos` with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push.
5. Run the "update goldens" workflow on the branch for the package CI goldens (`clip_tile`), then `tool/pull_ci_goldens`, look at them, commit, push, and wait for CI to go green on the branch.

---

### Task 14: The S24: Patrol flows, then the owner's hand checks

**Model:** Sonnet (controller with the owner). Results go into D-202 (proven on the build), D-204 (legacy root), D-206 (shares) and README.

**Safety (repeat before each command):** `-s RZCY80PHWCZ`, `app.taketray.dev` only, logcat `--pid=` only, no screenshots, no reading of shared storage or other apps, and Patrol only in `Movies/TakeTray Test/`, `Pictures/TakeTray Test/` and TakeTray Dev's own copy folders.

- [ ] **Step 1: Patrol, each file once.** Run `tool/patrol test -d RZCY80PHWCZ -t patrol_test/<file>.dart` for:
  - `photos_test.dart` first, then `editors_test.dart` and `reels_test.dart`;
  - then `add_videos_test.dart`, `tagging_test.dart`, `references_test.dart`, `onboarding_test.dart`, `settings_test.dart`, `app_shell_test.dart`, `background_test.dart`, `media_access_test.dart`, `media_scan_test.dart` and `database_test.dart`.

  (`share_test.dart` stays skipped, D-169.)
- [ ] **Step 2: After every Patrol run**, from the repo root:
  ```
  (cd app && ../tool/flutter build apk --debug)
  tool/adb -s RZCY80PHWCZ install -r app/build/app/outputs/flutter-apk/app-debug.apk
  tool/adb -s RZCY80PHWCZ shell pm clear app.taketray.dev
  ```
  A failure is reported to the owner with its step. A test fault is fixed (and reviewed) before the next round; an app fault goes back to its task. Each file runs again only in a new round.
- [ ] **Step 3: Install for the hand checks, legacy first.**
  1. Build `phase-12-ui-refresh` (5651f80) as a debug APK, `install -r`, and pm clear.
  2. On it, start a VN edit of a 2-clip reel **Old edit** (copies land in `Movies/TakeTray/Old edit/`).
  3. Then build this branch and `install -r` over it, **without** pm clear, so the session survives the update.
  4. Allow video access as before. App info › Permissions shows no Photos permission.
- [ ] **Step 4: The hand checks** (owner, TakeTray Dev, light and dark). Write the verdict per number.
  1. **Add photos:**
     - the button sits next to Add videos, read "Add photos";
     - the picker shows photos only, with multiple selection;
     - Cancel adds and shows nothing;
     - 3 photos: "3 photos added to {reel}" with Undo, and Undo removes exactly those;
     - the same photos again: "Already added".
  2. **Restart:** force-stop and reopen. The photos, thumbnails and stills are still there.
  3. **Tiles:**
     - the photo symbol where a length would be, readable over a bright photo;
     - a chosen photo hides it;
     - a portrait photo has no horizontal badge;
     - TalkBack: "Clip, {time}, Photo".
  4. **Counts:**
     - the header "{n} videos · {m} photos · {length}" and the Home card "{n} clips · {m} photos · {length}", with its TalkBack name;
     - a photos-only reel: "2 photos" in both.
  5. **Order:** an old gallery photo makes its own earlier day at the top; the others sit among the videos by the time taken.
  6. **Viewer:**
     - a photo fitted whole on black, with no play, mute or scrubber;
     - swiping to a video plays it, and back pauses it;
     - a HEIC photo and a large (50 MP) photo show quickly;
     - Remove, Move and Add to work, and the Remove snack says "photo".
  7. **Missing:** the owner deletes one test photo in Gallery. The reel shows it missing, and the add picker leaves it out.
  8. **VN:**
     - Edit video, then VN: the space screen counts the photos;
     - the ready screen says "Pictures › TakeTray";
     - in VN, New project shows **one** album with the videos and photos in shooting order;
     - Done editing deletes the copies.
  9. **The old edit:**
     - **Old edit**'s banner says `Movies/TakeTray/Old edit`;
     - Add more clips (a photo included) copies into Movies;
     - the storage screen lists it;
     - Done editing deletes in Movies.
  10. **CapCut, Edits, Other app…:** a mixed send opens each with every item in order, or follows D-207. The Sent snack: "Sent {n} clips and {m} photos to {editor}".
  11. **Add later for CapCut or Edits:** a photo added later is in the `Pictures › TakeTray` album in the editor's picker.
  12. **Storage screen:** both roots' folders listed with their root lines; a folder delete asks Android first.
  13. **Copies stay out:** after a VN copy, Add videos' folder list has no `Pictures/TakeTray` folder, and To tag gets nothing new.
  14. **Export, then import:** the photos come back in their reels.
  15. **2× text, dark mode, Remove animations:** nothing is cut off; the viewer and the tiles work; no movement is left.
  16. **Release permissions:** `cd app && ../tool/check_release_permissions` ends `RELEASE PERMISSIONS OK`, with the list unchanged.
- [ ] **Step 5: Record** the results:
  - README Phase 13: "Phone tests …", with the run counts and any fault found and fixed;
  - `dev-setup.md`: the verdicts;
  - the D-numbers named above.

  Commit `docs: Phase 13 phone results`, push, and open (or update) the PR when CI is green: base `phase-12-ui-refresh` while its PR is open, retargeted to `main` once it merges (R13-13). It merges only on the owner's go.
