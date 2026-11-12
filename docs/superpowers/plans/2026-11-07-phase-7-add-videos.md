# Phase 7: Add Videos and Manual Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any video on the phone can be added by hand, to To tag or to a reel: friends' WhatsApp and Quick Share videos, and clips from any shooting device. With full access, through a folder browser (prototype screen 17). In Manual mode (limited or no access), through Android's photo picker. The phase is done when friends' videos can be added on the S24 (spec §9, phase 7).

**Architecture:**
- **Kotlin** (`android/.../media/`): the media bridge gains one folder query and a small `PickedVideos` class for the photo picker and its persisted URI grants. It only reads and reports (D-66).
- **Dart rules:** `lib/domain/rules/browse_folders.dart` decides which folders show and what they are called. `AddVideosService` (`lib/data/media/add_videos_service.dart`) does every add on the media queue, so it cannot interleave with a scan.
- **Picked clips become full citizens:** they get thumbnails, covers, verification and a clean-up of unused grants. Clips with `source = picker` already exist in the schema, and the bridge already gives them a playable URI (`media_bridge.dart:120`), so the schema **stays v1**.
- **Screens** (`lib/features/add_videos/`): folder list, video grid, and the "Pick videos yourself" sheet.

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; Drift (schema v1, unchanged); freezed; go_router; gen-l10n; alchemist goldens (macOS plus CI sets, D-61; app screen goldens macOS-only, D-97); Pigeon 29.0.11; Kotlin with platform APIs only; Robolectric 4.17 (`tool/test_android`); Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`: §8.1 (`clips.source`), §8.2 `MediaApi` (folders, photo picker, persisted grants), §9 phase 7, and the Play policy risk (the app must work in Manual mode). Visual source of truth: `design/prototype/assets/screens.js` (`add-folders`, `add-grid`, `sheets.manualPick`), `app.js` (`addVideos`, `addPicked`, `alreadyAdded`), `states.js` screen 17.

**Owner rulings (2026-11-07, D-111):**
1. Friends' videos come in **by hand only**. Nothing new is watched automatically. Automatic folders are Phase 10's Watched folders screen.
2. **Any shooting device, no brand-specific code.** GoPro, Insta360, DJI, a mirrorless camera or a second phone all work as folders. The browser lists every folder with videos on every indexed volume (phone, SD card, USB drive). Big batches must work.
3. WhatsApp's **Sent** folders are hidden from the list.
4. **Dates stay as the phone reports them.** No "received" label and no date fix. A device with a wrong clock shows the wrong day.

## Global Constraints

- Schema stays v1. No new Gradle or pub dependency. Pigeon regenerated with the repo's existing command.
- Release permissions unchanged. `tool/check_release_permissions` must end `RELEASE PERMISSIONS OK` (exact allow-list, D-110 M-5). The photo picker needs no permission.
- Offline: no INTERNET, ACCESS_NETWORK_STATE or WAKE_LOCK.
- Logs (D-10): never video names, paths, URIs, folders, reel names, cities or the phone maker. Counts and error types only.
- Strict TDD: write **all** of a change's edge-case tests red first, see them fail, then implement once. Mutation-check the key lines. Never steer one case per fix round.
- Models: implementers of Tasks 2, 6 and 7, on-phone testing, all fixes and every task review and re-review on **Sonnet**; implementers of the heavy Tasks 3, 4 and 5 on **Opus**. Only the whole-phase final review and its re-review on **Opus** (re-reviews resume the same reviewer). Never Haiku. Always pass the model explicitly.
- Review findings: Critical and Important fixed now; Minors parked for one batch before the final review.
- Docs every task: `docs/decisions.md`, `docs/flow.md`, `docs/learn/phase-7-add-videos.md`, `docs/later.md`.
- UI: design tokens only (`TtMetrics` and friends), l10n for every string, 48 dp targets, semantics labels, text scaling to 200%, light and dark. Copy comes from the prototype verbatim where it exists.
- Phone rules: only `app.taketray.dev` runs tests. Never uninstall or clear `app.taketray`. Logcat with `--pid=` only. No screenshots. Never list shared storage or read other apps' files. Patrol videos only in `Movies/TakeTray Test/`. After every Patrol run: build debug, `install -r`, `pm clear app.taketray.dev`.
- **Short phone runs:** the S24 heats up and USB drops. Each Patrol file runs once per round. No test waits on Android's scheduler. No flow prints or taps other folders' names. Debug hooks stay debug-only.
- Git: push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Merging to main needs the owner's go.

## Review Focus

1. **A folder with thousands of videos.** Scrolling stays smooth and memory stays flat: the grid pages from Kotlin and loads thumbnails lazily. A selection survives paging. (Task 5.)
2. **The same video by two routes.** Add twice with a double tap, Add racing a scan, a video added by hand and then seen by Shooting mode's scan: always one clip, one place, and Undo removes only what this add created. (Task 3.)
3. **Access changes mid-flow.** Access removed while the browser is open, or the app killed while the photo picker is open: no crash, no wrong clips, and the user lands on a sensible screen. (Tasks 5, 6.)
4. **An SD card or USB drive removed** while its folder is open, or a picked video deleted or its grant lost: a calm empty or missing state, never a wrong video or a crash. (Tasks 2, 4, 5.)
5. **The grant clean-up never revokes a grant still in use**, even after a failed read or an import. (Task 4.)

---

### Task 1: Scope and docs (controller, no review)

**Files:** `docs/decisions.md` (D-111), `docs/later.md`, `docs/learn/phase-7-add-videos.md` (stub with the same section shape as Phase 6's guide).

- [ ] **Step 1:** D-111 records the four owner rulings above, and that a video added by hand from a folder is `ClipSource.mediaStore` (same identity as a detected one) while a photo-picker one is `ClipSource.picker`.
- [ ] **Step 2:** In `docs/later.md`: move "Friends' videos" (automatic pick-up) and "Action cameras" to Phase 10 under Watched folders, with the rulings. Add: a wrong device clock has no fix (owner's call; revisit when it bites).
- [ ] **Step 3:** Commit `docs: Phase 7 scope and rulings`.

---

### Task 2: Media bridge: folder pages and the photo picker

**Model:** Sonnet. **Files:**
- Modify: `app/pigeons/media_api.dart`, `android/.../media/MediaHostApiImpl.kt`, `VideoQueries.kt`, `Thumbnails.kt`, `android/.../MainActivity.kt`, `lib/platform/media_bridge.dart`, `test/support/fake_media_bridge.dart`.
- Create: `android/.../media/PickedVideos.kt`.
- Test: `android/app/src/test/kotlin/app/taketray/media/PickedVideosTest.kt`, `VideoQueriesTest.kt` (extend), `test/platform/media_bridge_test.dart` (extend).

**Interfaces (produces), Pigeon and the same in `MediaBridge` with domain types:**
```dart
class PickedVideoMsg { String uri; int sizeBytes; int? durationMs; int? dateTakenMs;
  String displayName; int? width; int? height; String? mimeType; bool persisted; }

@async List<VideoRowMsg> videosInFolder(String volumeName, String relativePath, int limit, int offset);
@async List<PickedVideoMsg> pickVideos();        // [] on cancel; throws code 'busy' if one is open
@async Uint8List? thumbnailOfUri(String uri, int widthPx, int heightPx);
@async List<String> readableUris(List<String> uris);   // the subset still readable
@async List<String> persistedUris();
@async void releaseUris(List<String> uris);
```

- [ ] **Step 1: Write the failing Robolectric tests:**
  - `videosInFolder`: non-pending, DURATION > 0 only; exact folder, case-insensitive; newest first by the shot-time order (`DATE_TAKEN`, then `DATE_ADDED`), id as tie-break so pages never repeat; `limit`/`offset` honoured; a volume that is gone returns `[]`, never throws.
  - `PickedVideos.intent(sdk, extensionLevel)`: `ACTION_PICK_IMAGES` with type `video/*` and `EXTRA_PICK_IMAGES_MAX = getPickImagesMaxLimit()` on API 33+ or API 30–32 with R extension ≥ 2; otherwise `ACTION_OPEN_DOCUMENT` with `video/*`, `EXTRA_ALLOW_MULTIPLE` and the persistable flag.
  - Result handling: `clipData` of many, a single `data`, and cancel (`[]`). A second `pickVideos` while one is open fails with `busy`. A result with no waiting caller (the process died) is dropped silently.
  - Facts: read from `PickerMediaColumns` / `MediaColumns`; a missing size or name still returns the row; a URI whose `takePersistableUriPermission` throws gives `persisted = false`.
  - `readableUris` drops a URI whose query throws `SecurityException` or returns no row. A failure of the whole call throws, so "failed" is never read as "gone".
  - `releaseUris` releases only the given URIs; one failure does not stop the rest.
- [ ] **Step 2:** Run `tool/test_android`. Expected: FAIL (types do not exist).
- [ ] **Step 3:** Add the Pigeon methods, regenerate, implement `PickedVideos` and the queries. `MainActivity.onActivityResult` forwards to the media bridge. All binder work is off the main thread.
- [ ] **Step 4:** Extend `MediaBridge`, its fake (with a settable picked list, `readable` set and `busy`), and the Dart tests for the domain mapping.
- [ ] **Step 5:** Run `tool/test_android` and `tool/check`. Expected: PASS. Mutation-check the shot-time order, the `busy` guard and the `SecurityException` branch.
- [ ] **Step 6:** Docs: D-112 (why `ACTION_PICK_IMAGES` with an `OPEN_DOCUMENT` fallback and no androidx dependency); `flow.md`; guide Section 2. Commit `feat(media): folder pages and the photo picker on the bridge`.

---

### Task 3: Adding by hand: folder rules and `AddVideosService`

**Model:** Sonnet. **Files:**
- Create: `lib/domain/rules/browse_folders.dart`, `lib/data/media/add_videos_service.dart`.
- Modify: `lib/data/repositories/clips_repository.dart`, `lib/data/media/media_scanner.dart` (share `_clipFrom` as a public `clipFromVideo`, not a copy).
- Test: `test/domain/rules/browse_folders_test.dart`, `test/data/media/add_videos_service_test.dart`, `test/data/repositories/clips_repository_test.dart` (extend).

**Interfaces (produces):**
```dart
class BrowseFolder { String volumeName; String relativePath; int videoCount;
  String name; String? detail; }
List<BrowseFolder> browseFolders(List<VideoFolder> all);

sealed class AddTarget; class AddToToTag extends AddTarget; class AddToReel extends AddTarget { int reelId; }
enum AddMark { inThisReel, inToTag, inAReel }

class AddVideosService {
  Future<Map<int, AddMark>> marks(String volumeName, List<int> mediaStoreIds, AddTarget target);
  Future<AddResult> addFromFolder(List<MediaVideo> videos, AddTarget target);
  Future<AddResult> addPicked(List<PickedVideo> videos, AddTarget target);
  Future<void> undo(AddResult result);
}
class AddResult { int added; int alreadyThere; int notKept; /* + what undo needs */ }
```
`AddResult` is opaque to the UI apart from the three counts.

- [ ] **Step 1: Write the failing rule tests.** `browseFolders`:
  - hides a folder whose last segment is `Sent` under a path with a segment starting `WhatsApp`, case-insensitive (`Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Sent/`, `WhatsApp Business Video/Sent/`, `Movies/WhatsApp/Sent/`); keeps `DCIM/Sent/`, `Movies/Sent stuff/` and `WhatsApp Video/`;
  - hides a folder with no videos;
  - `name` is the last path segment; the root (`''`) gets the l10n-free key that the view shows as "Main folder";
  - two folders with one name get a `detail` (the parent segment, plus the volume when they differ); a unique name has none;
  - `DCIM/Camera` first, then by count, descending, with the name as tie-break, so the order is stable.
- [ ] **Step 2: Write the failing service tests**, on the in-memory database and fake bridge:
  - a new video to To tag: one clip with `source = mediaStore`, an `inbox(pending)` row, the zone from the timeline, and `shotAt` from the same rule as a scan;
  - a new video to a reel: one clip, one link, **no** inbox row;
  - **double add** (the same list twice, and two concurrent calls): one clip, one place; the second reports `alreadyThere`;
  - **add, then the scan sees it** (a watched folder with Shooting mode on): still one clip, one place; added to a reel it does not appear in To tag;
  - a video in **Skipped**, added to To tag: back to pending, and Undo returns it to skipped;
  - a video in Skipped, added to a reel: linked and out of Skipped, and Undo restores both;
  - a clip that is `missing` at this number with a different fingerprint is handled by the scanner's `sameVideo` rule (the stored clip detaches, the new one inserts);
  - **Undo** removes only what this add created, keeps a clip tagged meanwhile, and a second Undo changes nothing;
  - `marks` returns `inThisReel`, `inToTag`, and (target To tag) `inAReel` per the prototype's `markFor`; a skipped video has no mark;
  - `addPicked`: `source = picker` with the URI; `persisted = false` counts as `notKept` and adds nothing; a missing date falls back as `clip_time` already does; a missing name or size never throws;
  - an add while access is lost throws `StateError` for the folder route and still works for the picker route;
  - a batch of 500 videos runs in one transaction with `idBatch` batching.
- [ ] **Step 3:** Run `cd app && ../tool/flutter test test/domain/rules/browse_folders_test.dart test/data/media/add_videos_service_test.dart`. Expected: FAIL.
- [ ] **Step 4:** Implement. Every add and undo runs through `MediaWorkQueue`. Repository additions go in one transaction (D-57: an inserted clip gets its place in the same transaction).
- [ ] **Step 5:** Run them and `tool/check`. Expected: PASS. Mutation-check the Sent rule, the "no inbox row for a reel" line, and Undo's "only what this add created".
- [ ] **Step 6:** Docs: D-113 (the marks, Skipped's behaviour, which Undo restores what); `flow.md`; guide Section 3. Commit `feat(media): add videos by hand, with Undo`.

---

### Task 4: Picked clips are full citizens

**Model:** Sonnet. **Files:**
- Modify: `lib/data/media/thumbnail_cache.dart`, `lib/features/clips/widgets/clip_thumbnail_image.dart`, `lib/data/database/clip_rules.dart`, `lib/data/media/media_verifier.dart`, `lib/app/media_lifecycle.dart` (the start-up work), `docs/decisions.md` (amend D-74 and D-84 point 3).
- Create: `lib/data/media/picked_grants.dart`.
- Test: extend the matching files under `test/data/`, and create `test/data/media/picked_grants_test.dart`.

**Interfaces (produces):** `class PickedGrants { Future<int> sweep(); }`. `ClipThumbnailKey.of` now returns a key for a picked clip.

- [ ] **Step 1: Write the failing tests:**
  - thumbnails: a picked clip gets a key that is a hash of the URI (never the URI in a file name) plus the fingerprint and size; a null from the bridge is "no picture" as today;
  - `hasPicture`: a picked, non-missing clip is true (covers and the Shooting mode backdrop use it); a picked missing clip is false; existing cases unchanged;
  - verify: a picked clip absent from `readableUris` becomes `missing`; present again un-flags it; a thrown `readableUris` changes nothing and counts as skipped (never "gone");
  - sweep: releases only URIs in `persistedUris` that no clip row holds; **a failed database read or bridge call releases nothing**; after an import it keeps every URI the new rows hold; it logs counts only.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. `sweep` runs once per app start on the media queue, after the first frame's work. Its failure is logged by type and never blocks the app.
- [ ] **Step 4:** Handle the Phase 5 picker gap from `docs/later.md`: the reel picker drops clip ids that have gone before it writes. Test first; then remove the item from `later.md`.
- [ ] **Step 5:** Run `tool/check` and mutation-check the sweep's "held by a row" filter and the verify's "throw means skipped".
- [ ] **Step 6:** Docs: amend D-74 and D-84 point 3; `flow.md`; guide Section 4. Remove "Covers exclude picked clips" from `later.md`. Commit `feat(media): picked clips get pictures, verification and a grant clean-up`.

---

### Task 5: The folder browser

**Model:** Sonnet. **Files:**
- Create: `lib/features/add_videos/views/add_folders_screen.dart`, `add_grid_screen.dart`; `view_models/add_folders_controller.dart`, `add_grid_controller.dart`.
- Modify: `lib/router/routes.dart`, `app_router.dart`, `lib/features/tagging/views/to_tag_screen.dart`, `lib/features/reels/views/reel_detail_screen.dart`, `lib/l10n/app_en.arb`, `lib/data/repositories/phone_state_repository.dart`.
- Test: matching `test/features/add_videos/...` widget tests; macOS goldens for both screens, light and dark, 1x and 2x text.

**Interfaces (consumes):** `browseFolders`, `AddVideosService`, `videosInFolder`. **Produces:** `Routes.addVideos = '/add-videos'` (root route, with a query parameter `reel` for a reel target), `Routes.addVideosFolder`; and `openAddVideos(BuildContext, WidgetRef, AddTarget)`, which Task 6 extends.

Copy, verbatim from the prototype: app bar "Add videos", subtitle "to To tag" / "to {reel}"; the tip "Keep friends' clips sharp" / "Ask friends to send videos as HD or by Quick Share to keep full quality." / **Got it**; grid subtitle "Tap videos to pick them"; marks "In this reel", "In To tag", "In a reel"; a marked tile's snack "Already added"; bottom bar "No videos picked" / "Videos already added are marked", then "{n} videos picked" / "{duration} · added in shooting order", button **Add** / **Add {n}**; empty "No videos in this folder" / "Videos saved here will show up when you come back."; the snack "{n} videos added to {target}" with **Undo**.

- [ ] **Step 1: Write the failing widget tests:**
  - folder list: name, count, a 2×2 preview from the first four videos of that folder (fetched lazily per row; a failure shows the folder icon), the tip once (`folderTipSeen` persisted, gone after **Got it**), a failed read shows **Try again**;
  - grid: day headers, newest first; paging loads the next page near the end and **keeps the selection**; marked tiles cannot be picked and show their label; tapping one shows "Already added";
  - bottom bar counts and total duration; **Add** disabled at zero;
  - Add success: returns to where the user came from, with the snack; **Undo** works after switching tabs (the existing undo snack path);
  - **Add disabled while running** (a double tap adds once); a failed add stays on the grid with "Couldn't add videos. Try again." and keeps the selection;
  - a resume re-reads the folder; a video gone from the folder leaves the selection; a removed volume shows the empty state;
  - access lost while open: the screen pops to its origin, where the banner explains;
  - a reel deleted while its target screen is open: the add fails calmly and pops.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. Page size 200; `GridView.builder`; thumbnails through the existing `ClipThumbnailImage` path. Show the `library_add` action on To tag and the reel page, and replace the "Not built" doc comments. Update the empty-reel body to "Tag clips from To tag, or add videos from your phone." (References wording stays out until Phase 9).
- [ ] **Step 4:** Run `tool/check`, generate goldens locally, then the CI goldens (`gh workflow run update-goldens.yml --ref <branch>`, `tool/pull_ci_goldens <run>`). Expected: PASS.
- [ ] **Step 5:** Docs: `flow.md`; guide Section 5. Commit `feat(add-videos): folder browser for To tag and reels`.

---

### Task 6: Manual mode

**Model:** Sonnet. **Files:**
- Create: `lib/features/add_videos/views/manual_pick_sheet.dart`.
- Modify: `openAddVideos` (Task 5), the Shooting mode card, `lib/l10n/app_en.arb`.
- Test: `test/features/add_videos/manual_pick_sheet_test.dart`, and extend the Shooting mode card test; goldens as in Task 5.

Copy, verbatim: "Pick videos yourself"; "TakeTray can see only some of your videos (Manual mode), so it opens Android's photo picker."; callout "The photo picker doesn't show folder counts, and it can't mark videos you've already added."; **Open photo picker**; **Allow full access instead**; card "On since {time} · Manual mode: add clips yourself".

- [ ] **Step 1: Write the failing tests:**
  - `openAddVideos` with limited or denied access opens the sheet; with full access, the browser; a failed access read shows the sheet (the picker needs no permission);
  - **Open photo picker** → `addPicked` → the snack "{n} videos added to {target}" with **Undo**;
  - cancel: nothing changes and no snack;
  - all already added: the snack "Already added";
  - some `notKept`: "Couldn't add {n} videos." is shown beside what was added;
  - `busy`: a double tap opens the picker once;
  - a bridge failure: "Couldn't add videos. Try again.";
  - **Allow full access instead** calls `MediaAccessController.allow()` and closes the sheet;
  - the card line shows only when access is not full.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement, using `TtSheet` patterns from `add_earlier_videos.dart`.
- [ ] **Step 4:** Run `tool/check` and goldens. Expected: PASS. Mutation-check the access branch.
- [ ] **Step 5:** Docs: D-114 (a picked clip and its folder twin can both exist after full access comes back; the fingerprint is not an identity, D-57; accepted, with an entry in `later.md`); `flow.md`; guide Section 6. Commit `feat(add-videos): Manual mode through the photo picker`.

---

### Task 7: On the S24

**Model:** Sonnet (phone safety rules apply). **Files:** `app/patrol_test/add_videos_test.dart`, `docs/dev-setup.md` (the Phase 7 check), `docs/decisions.md` (D-115), guide Section 7.

- [ ] **Step 1:** Patrol flows, in one file, using only `Movies/TakeTray Test/` and tapping only that folder by its exact text. The test prints no other folder name.
  - **Add to To tag from a folder:** insert 3 test videos, Add videos, open the test folder, pick 2, **Add 2**. To tag has 2; the third has no mark and the 2 show "In To tag". **Undo** removes them.
  - **Add to a reel:** new reel, Add videos, pick 1. It is in the reel with a picture, and not in To tag.
  - **A hidden Sent folder:** put a test video in `Movies/TakeTray Test/WhatsApp/Sent/` through the test media hook. The list has no such row. Delete it in the teardown.
  - **Already added:** tap a marked tile; "Already added".
- [ ] **Step 2:** Run `tool/patrol test -d RZCY80PHWCZ -t patrol_test/add_videos_test.dart` **once**, then the after-run steps. If it fails, at most 2 fix attempts on the same flow, then report. One deliberate wrong expectation fails on the fastest flow, then is reverted.
- [ ] **Step 3:** Run all other Patrol files **once**, back to back, with the after-run steps at the end. Report failures rather than debugging them; the controller rules. Run `tool/check_release_permissions`.
- [ ] **Step 4:** The owner's hand checks in `docs/dev-setup.md` (the Patrol tests cannot use the picker, because it shows the owner's videos):
  1. Add a real WhatsApp video to To tag and to a reel; it plays, with a picture.
  2. WhatsApp's Sent folder does not appear.
  3. Add a clip from another device's folder, or an SD card if available.
  4. Set TakeTray Dev to "Select photos and videos": the sheet appears, the picker opens, the picked clip plays with a picture, and it survives closing the app and a phone restart.
  5. Add a picked video to a reel, then delete it in the gallery: in the reel its tile shows as missing with Remove. A picked video in To tag stays as a missing tile too (it is only flagged, never removed, D-116); To tag's missing tile has no Remove yet (`later.md`). If a USB drive or SD card is at hand: pick a video from it into To tag, unplug it, open To tag (the tile shows as missing), plug it back (the tile comes back).
- [ ] **Step 5:** D-115 (what the phone showed, what is proven by hand only); guide Section 7. Commit `test(add-videos): Patrol flows on the S24`, push.

---

### Task 8: Phase end (controller)

- [ ] **Step 1:** Minors batch on Sonnet (one agent, self-reviewed). Then the final whole-branch review on Opus. One fix wave on Sonnet. Re-review on the same Opus reviewer.
- [ ] **Step 2:** Docs: README (Phase 7 ✅ Done, Phase 8 Next, a Phase 7 section); the guide's intro; `docs/later.md` (delete the Phase 7 section once empty).
- [ ] **Step 3:** CI goldens, CI green, a PR to `main`. Merge only after the owner says so. Then install the release APK over `app.taketray` with `install -r`. List every ruling made on the owner's behalf in the final message.
