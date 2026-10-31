# Parked work

Items that reviews found and parked for a later phase. When a phase is planned, read its section and put each item into a task (or say in the plan why it is dropped). Delete an item once it is done.

Sources: the Phase 1 task reviews and its final whole-branch review (2026-10-26), the Phase 2 task reviews and its final whole-branch review (2026-10-27), and the Phase 3 learning guide (2026-10-29).

## Phase 4

- Phase 3 left these (D-76):
  - The Shooting mode card's `rows` slot (D-79) holds the Add earlier videos row; Phase 4/5 puts References first in the same list.
- The reel page (D-87) verifies its clips when it opens, not when the app returns to the front while it stays open (To tag does both, D-75). Add the resume check to `ReelDetailController` if the owner wants it.

## Phase 5 (tagging and the player)

- Phase 4 left these (final review M-6, D-80):
  - The reel picker's **tag mode** (hidden in Phase 4).
  - The empty reel's copy says "Tag clips from To tag…", which only makes sense once tagging exists; check it then.
  - Until tagging exists, clips get into a reel only from code (tests, a backup import): no screen in Phase 4 puts a To tag clip into a reel. The first caller of `addClipsToReel` with a To tag clip is the tag mode (its undo puts the clip back in To tag, D-84 point 9).
- Phase 3 left these (D-76):
  - To tag has no error state when its list stream fails (a database error): skeletons stay. Needs copy and a design for an error state.
- Scrub bar:
  - it reads `position / duration` as "slash"
  - its semantics lack `value` and `increasedValue`

  Fix before the player ships.
- Scrub row: it is 48 dp (the CSS says 22). Also: the quick-row padding, a redundant `SizedBox`, and the thumb sits half outside the gesture area.
- Video scrim: the tokens (.7 / .55, linear) disagree with the CSS (.78 / .6, solid). **The owner picks one.**
- `TtTagPanel`:
  - make it a semantics group
  - budget its height cap of up to 520 dp at large text
  - add the "Other reels" label, the empty state and the dashed "New reel" chip (R8)
- Before the dashed "New reel" chip, deduplicate the dashed-outline painters and the scrim widgets into `internal/`.
- The nav badge's spoken label drops the tab name ("7 clips to tag" instead of "To tag, 7 clips").
- The snack has no drop shadow. Add one or record why in D-48.
- Add `expectTtAccessible` to `video_surface_test`. Relabel or drop the reel-chip 164 dp scenarios that can't happen at 2×.

## Phase 6 (background detection)

- Phase 3 left this (D-71, D-72): the background job reuses `ZoneChangeStore` (the native zone list) and the baselines. The baselines exist only in the database (the `shootingMode` setting), which native code cannot read, and nothing writes them to native state yet. `BackgroundApi` must write them there (with Shooting mode on or off and the watched folders, spec §8.2), and keep them in step whenever Dart moves a baseline (`PhoneStateRepository.advanceBaseline`, compare-and-set) or turns Shooting mode on or off.

- Phase 3's final review left these (D-72). Phase 6 reworks when scans run (background, after a reboot or a system update), which is when all four matter more:
  - **A rebuild resync that runs while Android is still re-indexing detaches clips it cannot see yet (I-3).** After a library reset `getVersion` changes at once, but `allVideos` returns only what the media scanner has indexed so far. `matchAfterRebuild` loses every clip it cannot find, `applyRebuildMatch` detaches it (`-id`, missing; inbox-only clips are deleted), and nothing looks at a detached clip again (`mediaStoreClipsOn` needs id > 0). When the videos appear a minute later they come in as new clips past the baseline: reel clips stay "missing" and the same videos return to To tag as duplicates. No file is touched. Why Phase 6: a background job that wakes up after a reboot or an update is the likeliest time to meet a half-built index. The idea for the fix: let a later resync or verify re-match detached, missing clips by fingerprint when the match is unique, and un-flag them (the new id replaces `-id`). The design problem is the duplicate: by then the same video may already be a new clip in To tag (or tagged into a reel), so re-matching must decide which row survives (probably keep the old clip, because it holds the user's reel links and order, and remove the new one when it is still untouched in To tag). It would also repair a clip whose original was edited in place.
  - **A clip trashed in a gallery and restored does not come back (M-6).** The queries leave out `IS_TRASHED` rows, so the verifier takes a trashed video for gone and removes an inbox-only clip. Restoring it does not give the row a newer generation, so the scan never adds it again. A clip in a reel recovers (the next verify un-flags it).
  - **Undo plus a stuck pending row can add the videos again (M-7).** A crashed recording's pending row can hold the baseline below it for days. `undoEarlierAdd` deletes the clips, and a later scan sees the same rows again past the held baseline. Only videos shot after the stuck row are affected. Fix idea: Undo records a "do not add again" marker, or the scan skips clips that Undo removed.
  - **A volume read that fails when Shooting mode is turned on leaves that volume without a baseline (M-8).** It then starts from "now" at the first scan, so videos shot between the switch and that scan are skipped. Very rare.

## Before the first schema change (v2)

- `tool/check_generated` must also hash `app/lib/data/database/app_database.steps.dart`, which `make-migrations` writes from v2. At v1 it also never regenerates `app/test/drift/.../generated/`.

## Phase 7 (add videos and Manual mode)

- Phase 4 left these (final review M-6, D-80):
  - **Add videos** on the reel page (hidden in Phase 4).
  - **Covers exclude picked clips** (Ruling D, D-84 point 3: `hasPicture` needs a MediaStore number). When picked clips can be added, decide how a cover gets a picture for them: they need a thumbnail path of their own.

Owner requests (2026-10-30). Discuss these with the owner while planning Phase 7, before deciding anything.

- **Friends' videos.** Pick up videos the owner didn't shoot, such as WhatsApp downloads and Quick Share, behind a Settings switch. Today only `DCIM/Camera` is watched, so these never reach To tag. This may be done through Phase 10's editable watched folders. Open risks:
  - busy groups and forwards could flood To tag;
  - WhatsApp's "Sent" copies would duplicate the owner's own camera clips;
  - WhatsApp strips the original shooting date, so a clip would be dated when it was received.
- **Action cameras (GoPro, Insta360).** Open points:
  - their phone apps save to their own folders;
  - Insta360's raw 360° files must be reframed and exported first, so only the exported clip is useful;
  - a whole day of clips is often copied at once;
  - camera clocks and time zones are often wrong, which would put clips on the wrong day.

## Phase 8 (editor handoff)

- Phase 4 left these (final review M-6, D-80): **Share** (the viewer action and the multi-select item, generic share), **Edit video** (the FAB and the multi-select ⋮ item), and the VN pieces: the "Editing in VN" banner, the card pill and the delete dialog's line.

- Sanitise a reel name before using it as a VN folder name (`/`, `:` and other characters Android storage rejects); `uniqueFolderName` only handles clashes.

- Removing a clip from a reel during a VN session (or deleting it as an orphan) must delete its VN copy file first. The `vn_copies` row survives the clip (D-54), so the storage screen can still find the file, but the normal flow should not rely on that.

## Phase 9 (references)

- Phase 4 left these (final review M-6, D-80): the reel card's **references badge**, the Reel details form's **link field**, and the **References section** on the reel page (under Shot ideas).
- The share handler must take the first `http(s)` URL out of shared text before calling `ReferencesRepository.add`: TikTok and YouTube share text such as "Title https://vm.tiktok.com/…", and `normalizeReferenceUrl` rightly refuses anything with a space in it.
- The reference card's "Open" button takes half the row at 2×.
- The banner margin is not configurable (`refs.js` overrides it).

## Phase 10 (onboarding and settings)

- Phase 3 asks for video access when the user turns Shooting mode on (`ShootingModeController`, through `MediaAccessController.askIfDenied`, D-75) and from the banner's Allow button. Onboarding replaces the "Turn on, then ask for access" step: ask once, in its own step with its own words, and then decide whether the switch should still ask.
- Backup import must run through `MediaWorkQueue`, or block the media jobs while it runs. It replaces the clips and the settings in one transaction, but a scan or a verify that is already running has read the old clips and baselines. The compare-and-set refuses the baseline write (an import turns Shooting mode off), yet the clips that job writes could still land in the freshly imported data. The same screen calls `MediaVerifier.verifyAll` for "X of Y clips found": like `verify` it throws on a bridge or database error, so wrap it in `guarded` (D-75).

- A backup import resets `mediaAccessWasFull` (M-9): an import deletes every `settings` row (D-59), including this one, so a user whose video access was removed sees "Manual mode" instead of "TakeTray can't see your videos" until access is full again. Cosmetic. Keep the key through an import, or re-read it after.

- The Export/Import buttons: decode and validate the backup JSON off the UI isolate (`compute`/`Isolate.run`) so a large file doesn't freeze the screen; show "X of Y clips found" after the media check.

- When the Settings screen watches `SettingsRepository.watch()`, a corrupt stored value logs its "Setting … is corrupt" warning on every emission, not once. Log it once per key (or repair the row on first read).

- The reminder-time form must keep `eveningReminderMinutes` within 0 to 1439 itself: `AppSettings` does not check it, and `SettingsRepository.save` throws `ArgumentError` for anything else.

- `.ib.tonal` icon button.
- `TtListRow` tall and disabled variants.
- The disabled-on `TtSwitch` tick is at full opacity.

## Phase 11 (polish and release)

- **Shooting card rows clamp to one line at 2× text.** "Add earlier vid…", "References · 4" and "3 clips… Tag now" are cut short. This was true of the on card since Phase 1/3, and is now true of the off card too (D-90). Let a row wrap to two lines at large text, or stack its trailing part, and check it with TalkBack.
- **Empty Reels at large text.** The off card is one row taller now (D-90), so on a short screen at a large font the empty Home's **New reel** button can sit below the fold. It can still be scrolled to. Check it on the S24 and one small screen.

- **Accessibility and the phone pass** (Phase 4 final review M-6; check each on the S24 with TalkBack):
  - the reel page's app bar has an empty title until it scrolls (the name is in the body): what TalkBack reads there;
  - focus order of the chips in Home's filter row;
  - a text field's error (the Reel details form) may be read twice;
  - the screen stays on while a long clip plays in the viewer;
  - the sound at the start of a swipe in the viewer (the outgoing clip now pauses at the middle of the swipe; check nothing is heard from both before that).

- `packages/taketray_ui/test/components/buttons_test.dart` has four tests that fail when `flutter test` is run from the repo root but pass from the package folder, which is how `tool/check` runs them ("TtButton at large text a stacked TtButtonRow button wraps too", "... wraps to two lines from the large-text scale", "TtButton the dialog size has 12 dp sides and wraps to two lines", "TtButtonRow puts buttons side by side, equal widths, 8 dp apart"). They fail at HEAD too (before Task 3). The cause has not been diagnosed; find it, and make the tests independent of the working folder.

- The Play Console declaration for video access (`READ_MEDIA_VIDEO`). The Phase 3 research rates approval at about 50/50. The case to make: TakeTray's core feature is continuous detection of new camera clips as they are shot, which the one-off system photo picker cannot do. Say too that Manual mode (limited or denied access) already works without the permission, so a refusal costs the automatic detection and leaves the rest of the app working (spec: Play policy).

- `design/tools/build_tokens.py --check` scans only `design/tokens/colour-options/` and `design/handoff/compose/` for orphans. Add `packages/taketray_ui/lib/src/tokens/` (it holds only `tokens.g.dart`) to `GENERATED_DIRS`.
- Release as an app bundle or split per ABI (the APK is 48.9 MB for 3 ABIs).
- Build warnings: CupertinoIcons not bundled, and the Patrol plugin applies KGP.
- `TtGlass`: the shadow bleeds through the translucent fill.
- Wrapped two-line buttons need more vertical padding. The `TtSwitch` focus highlight is taller than the track.
- `TtThemeData` value equality; badge `TextPainter` re-measures on every build.
- Zone-id aliases after a tz data rename (D-83). `Europe/Kiev` and `Europe/Kyiv` are the same zone but compare unequal as strings. So a clip stored with the old id on a phone that now reports the new one gets `isPhoneZone` false, and the viewer would say "Kiev time". Fix it by canonicalising both ids on the native side in a batch like `zoneOffsetsMs` (`android.icu.util.TimeZone.getCanonicalID(id)`, which follows the tz data's links; `ZoneId.normalized()` only turns a fixed-offset id into a `ZoneOffset` and does not resolve aliases), or by comparing the zones' offset rules (`ZoneId.of(a).rules == ZoneId.of(b).rules`) instead of their ids.
- The theme doc should steer feature code to `Tt*` widgets, since stock Switch, Checkbox, TextField and AlertDialog are not themed.
