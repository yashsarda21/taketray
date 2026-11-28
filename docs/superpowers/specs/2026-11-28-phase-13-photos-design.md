# Phase 13: photos in reels (design)

Owner-approved direction, 2026-11-28 (option B, copy folder A). Branch `phase-13-photos`, stacked on `phase-12-ui-refresh` (12B is not merged yet; its phone check is still pending). Decisions take the next free numbers after D-197.

## Why

The owner, in their own words: "it happens sometimes that I add photos into reel along with videos." Today a reel can only hold videos. When a reel needs a photo, the owner leaves TakeTray, and the photo never shows up in the reel's order or in the hand-off to the editor.

Success: a user adds the 2 or 3 photos a reel needs from inside that reel. The photos sit among the videos in shooting order, and they go to VN, CapCut or Edits with the videos, in the same order, in one hand-off.

## Goals

- **Add photos** on a reel page, through Android's own photo picker, for as many photos as the picker allows.
- Photos are stored, ordered, chosen, moved, removed, verified, exported and imported the way picked videos are.
- A video shows its length and a photo shows a photo icon, wherever clips are drawn. TalkBack says "Video, 15 seconds" or "Photo".
- The full-screen viewer shows a photo as a still.
- The editor hand-off includes photos: VN copies them, and CapCut, Edits and Other app… receive them.

## Non-goals

- Photos never reach To tag, Shooting mode, the background scan, Add earlier videos, notifications, references or the tag player.
- No sharing a photo from Gallery straight into TakeTray (later, if asked).
- No zoom or editing in the photo viewer.
- No subscription gate (subscriptions are designed but not built, D-170).

## Anti-goals (a failure even if it works)

- TakeTray asks for any photo permission (`READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED` beyond what the video flow already declares, or `READ_EXTERNAL_STORAGE` for images). `tool/check_release_permissions` must still end `RELEASE PERMISSIONS OK` with an unchanged list.
- A video flow behaves differently for a reel with no photos. The one intended change is the copy folder (below).
- Photos flood anything automatically.

## Constraints

- The picker is the only way in (`ACTION_PICK_IMAGES` with `image/*` on Android 11+ with the photo-picker extension, as `PickedVideos` does for videos; the same fallback `PickedVideos` uses on older phones). A persistable read grant is taken for each photo, as for picked videos, and released when the photo leaves every reel and the database.
- No new packages. Photos are drawn through the existing thumbnail bridge, and the viewer's full-size still is decoded natively, downscaled to the screen, and handed to Flutter as bytes.
- Logs never contain a file name, URI or reel name (D-10). Counts and types only.
- Strict TDD with every edge case red first, mutation checks, docs every task, and a learning guide `docs/learn/phase-13-photos.md`, as in every phase.
- The phone is touched only by the controller with the owner. Patrol works only in its test folders.

## Approaches considered

1. **How photos get in.** A: Shooting mode picks up camera photos automatically (needs photo permission, floods To tag, about Phase 9's size plus a privacy change). **B: Add photos by hand in a reel through the picker. Chosen by the owner:** photos are only sometimes needed, and B needs no permission.
2. **Where photos are stored.** **As rows of the existing `clips` table, marked by their MIME type (chosen, my call):** ordering, reel membership, missing checks, the selection dock, export and copying all already work on clips. A separate `photos` table would duplicate every one of those paths.
3. **Where VN copies go.** Android does not allow image files under `Movies/`. **A: every copy, video or photo, goes to `Pictures/TakeTray/<folder>/`. Chosen by the owner:** VN shows one album with the whole reel in shooting order. B (videos in `Movies/TakeTray/<folder>/`, photos in `Pictures/TakeTray/<folder>/`) was rejected: two albums with one name, and the order across them is lost.
4. **The entry point.** **Its own Add photos button next to Add videos in the reel's top bar (chosen, my call):** one tap, and as easy to find as Add videos. A single Add button asking Videos or Photos costs every video add a second tap.

## The design

### 1. Adding photos

- The reel page's top bar gets **Add photos** (the `add_photo_alternate` symbol, named "Add photos") next to **Add videos**. It opens once however fast it is tapped (the existing `OpenOnce`).
- The picker shows photos only, with multiple selection. Cancel adds nothing and shows nothing.
- Each picked photo becomes a clip:
  - `source = picker` and `pickerUri`;
  - `mimeType` as reported (`image/jpeg`, `image/heic` and so on);
  - `durationMs = 0`;
  - `width`, `height` and `sizeBytes`;
  - `dateTakenUtc` from the picker's `DATE_TAKEN`, else the file's last modified time, else the time it was added;
  - `timeZoneId` as videos get it.
- The photo is added straight to that reel. It is never put in To tag.
- **The same photo picked again** for a reel that already holds it (same `pickerUri`) is not added twice and counts as "Already added". The same photo in another reel is the same clip in two reels, as for videos.
- **The snack** follows Add videos: "{n} photos added to {reel}" with **Undo**. Undo removes exactly the photos this add brought in. When some could not be kept, it says "Couldn't add {n} photos." When every pick was already there, it says "Already added".
- **A grant that cannot be kept** (the provider refuses a persistable grant): that photo is not added and counts as not kept.

### 2. Telling photos from videos

- A clip is a photo when its `mimeType` starts with `image/`. One getter (`Clip.isPhoto`) answers it everywhere, with a test.
- **Tiles** (the reel page grid, the selection dock's lists and the editor add picker) show the photo symbol in the corner where a video shows its length.
- **TalkBack:** the existing tile label replaces "{length}" with "Photo".
- **The reel page header:** "8 videos · 2 photos · 2:10". The total length counts videos only. With no photos it reads as today. With photos only: "2 photos".
- **The Home reel card's details line:** "{n} clips · {length}" stays for videos. With photos it becomes "8 clips · 2 photos · 2:10", and with photos only "2 photos". The card's accessible name says the same.
- **Day and scene grouping** on the reel page treat a photo like any clip: by time taken, so an old gallery photo makes its own earlier day at the top. *(As agreed: "photos sit among the videos by the time they were taken".)*

### 3. The viewer

- The full-screen viewer (`clip_viewer_screen.dart`, D-89) pages through photos and videos in reel order.
- A photo page shows the still fitted whole on black, with no play, pause or mute control and no progress bar. The bottom controls that act on the clip (remove, add to, move, the clip's facts) are the same.
- While the still decodes, the page shows the thumbnail. If it cannot be read, the page shows the existing "missing" state.

### 4. Choosing, moving, removing

The selection dock (D-190, D-191), Add to, Move, Remove, Undo and Select all treat photos as clips. Nothing photo-specific is added except the counts.

### 5. Missing photos

The existing verification of picked clips covers photos: the address no longer opens, or the grant is gone, marks the clip missing. A missing photo looks and behaves like a missing video, and the add picker leaves it out.

### 6. The editor hand-off

- **The editor sheet's title** counts clips. When photos are among them: "Edit 8 clips and 2 photos in…" (and the every-clip variant "Edit all 8 clips and 2 photos in…"). With photos only: "Edit 2 photos in…".
- **The copy root, for every editor:** every copy TakeTray makes (VN copies and the CapCut and Edits add-later copies of D-129) goes to `Pictures/TakeTray/<folder>/`. The strings that name `Movies › TakeTray` (the ready-screen steps, "Why copies?", the delete-reel text) change with it. *(My call, from the builder check: "every copy" means every editor, so a reel never has two albums.)*
- **The root is recorded per session** *(my call)*: a schema migration adds a root column to `vn_sessions` (the existing session rows default to Movies). The native copy messages carry the root with the folder name. Refs, deletes and "existing copies" are always resolved under the session's root, never by probing.
- **VN:**
  - Copies go to the session's root, `Pictures/TakeTray/<folder>/` for every new session. Photos are copied byte for byte and named in shooting order like videos. The space check includes the photos' sizes. Add-later (add mode) can add photos.
  - **The legacy root:** copies made before this phase are still in `Movies/TakeTray/<folder>/`. The VN copies storage screen lists both roots, and the "delete copies" and Done editing paths delete from both, with the same strict path, name and owner checks for each root as `CopyFolder` has for Movies today (no other folder, no `TakeTray Test` folder).
  - A reel whose edit (any editor) started before the update keeps adding to the root its session was made in, so one edit never spans two albums.
  - **Copies stay out of the clips** *(my call)*: the rules that keep `Movies/TakeTray/` out of the watched folders, the folder browser and the native scan (D-130) cover `Pictures/TakeTray/` too, and still never `TakeTray Test`.
  - **Photo copies TakeTray did not make** *(my call)*: without photo permission, Android shows TakeTray only its own image rows. The storage screen and the cleanup see and delete only TakeTray's own photo copies. Photo copies left by an earlier install, or by the other build (Dev against release), are not seen. This is recorded in `later.md`; the user can delete them in Gallery.
- **CapCut, Edits and Other app…:**
  - The share carries every chosen address. The intent's type is `video/*` when all are videos, `image/*` when all are photos, and `*/*` when mixed.
  - Whether CapCut and Edits accept a mixed share is proven on the S24 before the hand-off task is built (see "Prove first"). **If an editor refuses a mixed share** *(my call)*, that editor gets the videos by the share as today and the photos as copies in the session folder, the D-129 add-later path, and the Sent snack says "Add the 2 photos from Pictures › TakeTray". It stays one tap for the user, with no second share sheet.
- **Copy and Ready offers** count photos with the clips. "Sent 8 clips and 2 photos to CapCut".

### 7. Export and import

Photos are clip rows, so a backup holds them with their `mimeType` and an import restores them. A backup made before this phase has no photos and imports as today. The backup format's version changes only if a field is added (none is planned).

### 8. Accessibility and look

- Every new control has a 48 dp target and a name.
- Text stays AA, including the photo symbol over a thumbnail (it uses the same scrim as the length).
- 2× text and dark mode are checked like the rest.
- The photo symbol and the "Add photos" button use existing package parts (`TtClipTile`, `TtAppBar` actions). New metrics are `TtMetrics` constants.

## Prove first on the S24 (before the tasks that depend on it)

1. Picking photos with `ACTION_PICK_IMAGES` gives persistable grants that survive a restart.
2. A video and a photo can be inserted under `Pictures/TakeTray/<folder>/` through MediaStore, and VN's import lists them in one album, in name order.
3. CapCut, Instagram Edits and the share sheet accept a mixed `*/*` share of videos and photos, and HEIC photos.
4. CapCut's and Edits' album pickers list `Pictures/TakeTray/<folder>/` (D-129's gate (a) proved only `Movies`).

**If a spike fails** *(my calls)*:
- A video cannot be inserted under `Pictures/`: every copy goes to `DCIM/TakeTray/<folder>/` instead, which Android allows for both. It is still one root and one album.
- An editor or VN refuses HEIC: TakeTray converts that photo to JPEG natively (Android's own decoder and encoder, no package) for that hand-off only. Everything else stays byte for byte.
- An editor refuses a mixed share: see section 6.

The builder orders the tasks so these spikes run as soon as the phone is free. Work that does not depend on them comes first: the model, adding, tiles, the viewer and export. The spikes are throwaway code. What they prove goes into a decision.

## Left to the builder

- Exact symbol choices and string wording beyond the ones given here (in the app's plain voice).
- How the native still decoder downsizes (target the screen's longest side).
- The order of tasks, within the "prove first" rule.
- Test fixtures for photos: host tests use fakes, and Patrol gets a photo in its own test folder (`Pictures/TakeTray Test/`, the photo twin of `Movies/TakeTray Test/`).
