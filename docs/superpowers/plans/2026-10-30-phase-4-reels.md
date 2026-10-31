# Phase 4: Reels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the user can plan and manage their reels. Phase 4 builds:
- **Home**, the Reels tab: the Shooting mode card, the clips-waiting banner, status filters with counts, reel cards and the **New reel** button.
- **Creating, editing, changing the status of, and deleting** a reel.
- **Reel detail:** clips grouped by the day they were shot, "in N reels" badges, missing tiles, and multi-select with Add, Move and Remove.
- **The full-screen clip viewer.**

Every remove, move and delete can be undone. The phase is done when the screens match the prototype and the Patrol flows pass on the S24 Ultra (spec §9, phase 4).

**Architecture:**
- **Pure rules** in `app/lib/domain/rules/`: shooting days, day numbers, home filters, and the zone city name.
- **Data:**
  - `ReelsRepository` and `ClipsRepository` gain summary streams, move, and **undo records**. An undo record is a snapshot taken inside the same transaction as the change, and restored with the same ids.
  - The clip-time service turns a clip's UTC time into the local time where it was shot. It asks Kotlin for the zone offsets, in batches (`java.time`, the phone's own time-zone rules).
- **View models** (Riverpod codegen) per screen, in `app/lib/features/reels/` and `app/lib/features/clips/`.
- **Screens** are built only from `taketray_ui` components and tokens. The design-system debts that `docs/later.md` parks for Phase 4 are paid first.
- **The clip viewer** plays the original video through `video_player` (ExoPlayer) from its `content://` URI. It never copies the video.

**Tech Stack:**
- Flutter 3.47.7 / Dart 3.13.5 via `tool/flutter`.
- Riverpod 3 codegen, Drift (schema **stays v1**, so there are no migrations), freezed, go_router, gen-l10n, and alchemist goldens (macOS plus CI sets, D-61).
- Pigeon 29.0.11 (one new method on `MediaHostApi`), Kotlin, and Robolectric 4.17 on SDK 30/33/34/35.
- **`video_player`** (new). Use the newest stable 2.x release that is at least two weeks old, pinned with a caret, and record the version in the decision.
- Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`: §3 (status names, "Collecting"), §4, §7, §8.1, §8.3 (missing media), §8.3a (zone and "London time"), §8.4 (ordering by shooting day), §9 phase 4, §10 and §11.

**Also read:**
- `docs/design-prompt.md` §5 (rules), §6.5, §7 screens 6–10 and 16, and §8 (copy).
- The prototype `design/prototype/`, which is the visual source of truth:
  - `assets/screens.js`: `routes.home`, `routes.reel`, `routes.viewer`, `sheets.reelForm`, `sheets.picker`, `dialogs.deleteReel`, `menus.status`, `menus.reelMore` and `menus.reelSel`;
  - `assets/ui.js`: `STATUS`, `tile` and `reelCard`;
  - `assets/app.js`: the actions and snack texts quoted below;
  - `proto.css` and `tt-style.css`.
- Parked items: the "Phase 4" section of `docs/later.md`.

## Global Constraints

- **SDK:**
  - Use `tool/flutter`, `tool/dart`, `tool/adb` and `tool/patrol` only. Never use the `flutter` on PATH, and never touch `~/flutter`.
  - Iterate on Android with `tool/test_android -ProbolectricSdks=35`. All four SDKs and `tool/check` must be green before a commit.
- **Status names (spec §3):**
  - The prototype's "Recording" is **Collecting** everywhere: the pill, the filter chip, the status menu, the picker's section header, and the copy ("New reels start as Collecting.").
  - Status descriptions:
    - Collecting: "Still shooting clips for it"
    - Ready to edit: "All the clips are in"
    - Published: "Posted on Instagram"
- **Out of scope in Phase 4.** These are hidden, not disabled, and each goes in D-80 with the phase that builds it:
  - **Edit video:** the FAB, and the multi-select ⋮ item (Phase 8).
  - **Share:** the viewer action and the multi-select item (Phase 8, generic share).
  - **Add videos** on reel detail (Phase 7).
  - **Editing in VN:** the banner, the card pill, and the delete-dialog line (Phase 8).
  - **References:** the reel card badge, the form's link field, and the Shot ideas references section (Phase 9).
  - **Tag mode** of the reel picker (Phase 5).

  The viewer shows three actions (Add to reel, Move, Remove) in a three-column bar.
- **Duplicate names are not allowed (owner, 2026-10-30; amends D-56).**
  - Two reels can't have the same name, ignoring case and the spaces at either end.
  - `ReelsRepository.create` and `rename` throw `InvalidInputException(ReelNameProblem.duplicate)`. Renaming a reel to its own name, in any case, is fine.
  - The form shows "You already have a reel called {name}" (`validName` in `app.js`).
  - Backup import still loads a file that has duplicates. It never fails over them, because a restore must not lose data.
- **Copy approved by the owner at plan review (2026-10-30):** "Couldn't open the camera.", "They stay in this reel too.", and "Added to {A}, {B} and {n} more".
- **The description cap is 1,000 characters** (my call; `docs/later.md` asks for one). It is enforced in `ReelsRepository` (`InvalidInputException(ReelDescriptionProblem.tooLong)`) and in the form, which shows the counter.
- **Undo (owner rule, design-prompt §5):** every remove, move, add-to-reel and reel delete shows a snack with **Undo**:
  - Undo restores exactly what that action changed, using the same ids, and never creates a duplicate clip.
  - Undo works after navigating away, until the snack closes.
  - A status change shows "Marked as {status}" with no Undo, as in the prototype.
- **Times (spec §8.3a, §8.4):**
  - A clip's time and its shooting day are in the zone where it was shot (`Clip.timeZoneId`). If that is null or unknown, the phone's current zone is used.
  - Day numbers count calendar days ("Day 1" is the first clip's local day), never 24-hour periods.
  - Dates and times follow the phone's locale and 24-hour setting (D-76 and D-79 helpers). A date shows its year only when it is not this year.
- **Wrong video is the worst bug (spec §4):**
  - The viewer plays a clip only from its stored identity: `volumeName` and `mediaStoreId` > 0, or its picker URI.
  - A clip with no usable identity, or one flagged missing, is never played. It shows the can't-play or missing state.
- **Privacy (D-10):**
  - Log lines never contain a reel name, a description, a display name, a path, a URI or a zone city. Ids and counts are fine.
  - The video plays straight from the gallery and is never copied.
- **No Haiku, ever.** Tasks 4 and 5 and the final review run on **Opus**. Every other task runs on **Sonnet**. Always name the model when dispatching.
- **Reviews (owner rules):**
  - Every code task gets a fresh task reviewer. Docs-only tasks (1 and 12) skip it, and the ledger says why.
  - A per-task fix round is self-reviewed by the fixer. The final review's fix wave gets a separate re-review.
- **Tight testing (owner's rule):**
  - Each listed test is written red first, then made green, and the report quotes both runs.
  - Each task's report names at least two **mutation checks**, each applied alone and then reverted, with the failing output quoted.
  - Never loosen, skip or delete a test to get green.
  - Android behaviour is proven on the S24 in Task 11.
- **Style rules:**
  - Feature code has no raw colours, sizes, text styles, radii, `EdgeInsets` numbers or animation durations (`tool/check_styles`).
  - Each new component has goldens (light and dark, at 1× and 2× text, macOS **and** CI sets, D-61), a Widgetbook use case, and passes `expectTtAccessible`.
  - Every user-facing string is in `app_en.arb`.
- **Phone rule:**
  - Only `app.taketray`, `app.taketray.dev` and `app.taketray.widgetbook` may be installed, cleared or run on the S24. Never uninstall or clear `app.taketray`.
  - Logcat is read only through a pid filter for TakeTray. No screenshots, and no reading of other apps or of shared storage.
  - Patrol tests may create and delete only their own videos, in `Movies/TakeTray Test/`, through the debug channel (D-77). Every bridge query in a test stays inside that folder.
  - The limited-access Patrol test stays skipped.
  - After a Patrol run, reinstall the normal debug build (`docs/dev-setup.md`).
- **Coverage:** at least 80 % for `lib/domain/`, `lib/data/`, `lib/platform/` (excluding `*.g.dart`) and `lib/features/*/view_models/`.
- **Living docs:**
  - The next free decision number is **D-80**, and each task takes the next free numbers in order.
  - Every changed flow updates `docs/flow.md`. Every finished `docs/later.md` item is deleted, in the same commit as the code.
- **Learning guide:** `docs/learn/phase-4-reels.md`.
  - Task 1 stubs one section per task. Tasks 2–11 each fill in their own section, using the Phase 3 template (what we built / why / key ideas with short real snippets / where it lives / try it yourself / decisions).
  - A wrong explanation is a review defect.
- **Git (D-63):**
  - Work on branch `phase-4-reels` and push after every task commit:

    ```bash
    git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u origin phase-4-reels
    ```

  - The controller watches CI. A task is complete only when CI is green on its commit.
  - Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never force-push.
  - The phase lands through a pull request after the owner approves.

## Review Focus

1. **Undo after a clip has left the app.** Removing a reel's only link to a clip deletes the clip row (the orphan rule, D-56). Expected: Undo puts back the same clip id with every field, its `addedAt`, its reel count and its thumbnail key. If the same video was added again in between (Add earlier videos), Undo links the existing clip and never inserts a second one. Owner: Task 5 (`undo remove restores an orphan-swept clip with its id`, `undo remove links the existing clip when the video came back`).
2. **A clip shot abroad, or on a daylight-saving day.** Expected:
   - A London clip tagged later in India shows London time, and the city "London time" in the viewer.
   - Its day header is its London calendar day.
   - "Day N" counts calendar days across a DST change and across zones.
   - An unknown zone id falls back to the phone's zone and does not crash.

   Owner: Task 4 (`offsets come from the phone's zone rules`, `unknown zone falls back`, `day numbers across the London DST change`).
3. **A video deleted from the gallery while its reel or the viewer is open.** Expected:
   - Opening a reel verifies its clips, and a gone one turns into the missing tile.
   - The viewer never plays a different video. It shows "This video can't be played", and paging skips missing clips.

   Owner: Task 8 (`opening a reel verifies its clips`), Task 10 (`player error shows the can't-play state`, `missing clips are not in the pager`).
4. **Double taps and racing changes.** Examples: Delete tapped twice, Save tapped twice, Move then Undo while the list stream redraws, and Undo after leaving the screen. Expected: each action runs once, Undo still works, and nothing throws. Owner: Task 7 (`double Save creates one reel`, `delete twice deletes once`) and Task 9 (`Undo after leaving the reel restores`).
5. **Large and awkward data:**
   - 25 reels and 300 clips over 20 days;
   - a 40-character name made of emoji;
   - a 1,000-character description;
   - 2× text at 360 dp.

   Expected: lazy slivers (only a screenful built), no overflow, and every name fully readable somewhere (the body title wraps where the app bar clamps). Owner: Task 6 (`20+ reels build lazily`, `2× text`), Task 8 (`300 clips build lazily`, `long name wraps in the body`).

---

## File structure

**Create (app):**
- `lib/domain/rules/shooting_days.dart`: `ShootingDay`, `groupByShootingDay`, and `dayNumber`.
- `lib/domain/rules/zone_city.dart`: `zoneCity`.
- `lib/domain/rules/reel_filters.dart`: `ReelFilter`, `filterCounts`, and `applyFilter`.
- `lib/domain/models/reel_summary.dart`: `ReelSummary` and `ReelClip`.
- `lib/domain/models/undo_record.dart`: the sealed `UndoRecord`.
- `lib/data/media/clip_time.dart`: `ClipTimeService` and `ClipLocalTime`.
- `lib/features/reels/view_models/`: `home_controller.dart`, `reel_form_controller.dart`, `reel_detail_controller.dart`, `reel_selection.dart`, and `undo_snacks.dart`.
- `lib/features/reels/views/`: `reels_screen.dart`, `reel_form_sheet.dart`, `reel_detail_screen.dart`, `reel_picker_sheet.dart`, and `delete_reel_dialog.dart`.
- `lib/features/clips/view_models/clip_viewer_controller.dart` and `lib/features/clips/views/clip_viewer_screen.dart`.
- `lib/core/midnight_tick.dart`: `localDayProvider`.
- `docs/learn/phase-4-reels.md`.
- `patrol_test/reels_test.dart`.

**Modify (app):**
- `lib/data/repositories/reels_repository.dart` and `clips_repository.dart`.
- `lib/platform/media_bridge.dart` and `pigeons/media_api.dart` (one method).
- `lib/router/app_router.dart` and `routes.dart`.
- `lib/features/shooting_mode/views/shooting_mode_section.dart`.
- `lib/features/tagging/views/to_tag_screen.dart` (tile time in the clip's zone).
- `lib/l10n/app_en.arb` and `pubspec.yaml`.
- Delete `lib/features/reels/views/reels_placeholder_screen.dart`.

**Kotlin:** `MediaHostApiImpl.kt`, plus `ZoneOffsets.kt` with `ZoneOffsetsTest.kt`.

**taketray_ui** (Tasks 2–3): `text_field.dart`, `menu.dart`, `status_pill.dart`, `reel_card.dart`, `clip_tile.dart`, `shooting_mode_card.dart`, `grouped_rows.dart`, `nav_pill.dart`, `buttons.dart`, and new files `reel_header.dart`, `viewer_chrome.dart` and `reel_pick_row.dart`, each with tests, goldens and Widgetbook stories.

---

### Task 1: Plan, decisions and the learning-guide stub (docs only, done by the controller)

**Model:** the controller, inline. No task review: the change is docs-only, recorded in the ledger.

- [ ] **Step 1:** Commit this plan and the `docs/later.md` Phase 7 section (owner requests from 2026-10-30).
- [ ] **Step 2:** Create `docs/learn/phase-4-reels.md`, with one stub section per Task 2–11.
- [ ] **Step 3:** Add **D-80 · Phase 4 scope**. It covers:
  - the out-of-scope list above, with the phase that builds each item;
  - Collecting;
  - duplicate names not allowed (owner; Task 5 amends D-56);
  - the 1,000-character description cap;
  - Undo on every remove, move, add and delete, but not on a status change;
  - Home sorted by `createdAt`, newest first (ties: highest id first), as the prototype's `routes.home` does. The repository's `watchAll` order (by update) is unchanged.
- [ ] **Step 4:** Commit as `docs: Phase 4 plan, scope decision and learning guide stub`, then push.

---

### Task 2: Design-system debts parked for Phase 4

**Model:** Sonnet.

**Files:** the `taketray_ui` files named in each item, their tests and goldens, and `widgetbook/test/`.

Each bullet below is a `docs/later.md` "Phase 4" item. Fix it, test it, and delete the item:

- **`TtTextField`:**
  - The error goes into the field's semantics.
  - Swapping the `controller` keeps the text: the old controller's text moves to the new one only when the new one is empty and was created by the widget.
  - The error icon scales with text.
- **Package-composed strings come from the caller:**
  - the progress `%`;
  - the reel card's references badge fallback;
  - the reference card's label;
  - the text-field counter (`counterText: String Function(int length, int max)`).

  `referencesSemanticLabel` is required when `referenceCount > 0` (an assert).
- **A font-weight helper** `TtTextStyles.weight(FontWeight)` returns `fontWeight` and the `wght` variation together. Use it everywhere a weight is set in `taketray_ui`.
- **`TtMenuButton`:** `onClose` during build is deferred with `addPostFrameCallback`.
- **Doc comments** that still say "glass circle" (`bar_scope.dart`, `tt_metrics.dart`) are corrected.
- **Status pill:** the caret gap is 6 dp (`TtSpacing`), not 2.
- **At 2× text:**
  - the missing tile wraps instead of truncating;
  - the stat strip's action keeps its full label (its text goes to two lines first);
  - on empty art, the reel card's status pill clears the film icon;
  - the pill-tab overflow test is rewritten so it can fail (mutation: remove the wrap and see it fail).
- **Tests:**
  - buttons: the fill-1 glyph, the pressed colour, and each kind's colours;
  - `TtReelCard` accessibility: cover, missing and status;
  - the start-only padding of the VN mark.
- **Semantics:** `TtShootingModeCard` gets a top-level label: "Shooting mode, on/off", passed in by the caller. The icon-only `TtGlassPill` gets a semantics doc and a required `semanticLabel`.
- **`TtCardRow`:** its look is chosen by an explicit `TtCardRowKind { link, strip }` instead of by `trailingText`. Update the callers.
- **Widgetbook tests:**
  - `catalog_use_cases_test.dart` checks that each tap selected its use case (the `WidgetbookState` expectation quoted in `docs/later.md`).
  - `catalog_coverage_test.dart` checks per class, with an allow-list of classes deliberately left out of the catalogue.

- [ ] **Step 1:** Write each failing test (red), named after its item, e.g. `text field error is in semantics`, `swapping controller keeps text`, `status pill caret gap is 6`, `missing tile wraps at 2x`, `use case tap selects it`, `second class in a registered file is caught`.
- [ ] **Step 2:** Make them pass, regenerate the goldens that change (macOS now; the CI set is made by the controller with `update-goldens.yml` after the push), and run `tool/check`.
- [ ] **Step 3:** Add D-81 (the counter callback, `TtCardRowKind`, and the weight helper). Fill in the guide's Section 2. Delete the done `docs/later.md` items. Commit as `fix(ui): Phase 4 design-system debts`, then push.

**Mutations (at least):**
- the text-field error not added to semantics;
- the caret gap back to 2;
- the coverage test's per-file check restored.

---

### Task 3: New components for reels and the viewer

**Model:** Sonnet.

**Files:**
- `packages/taketray_ui/lib/src/components/`: `menu.dart`, `buttons.dart`/`nav_pill.dart` (the FAB contract), and new files `reel_header.dart`, `viewer_chrome.dart` and `reel_pick_row.dart`.
- Exports, tests, goldens (macOS) and Widgetbook use cases for each.

Build each from the prototype's CSS and markup (cited), in light and dark:

1. **`TtMenuItem` additions:**
   - `subtitle` (the `.mi.tall .sub` line) and `checked`, which shows a trailing check and gives the semantics of a `menuitemradio` with checked state. This is for `menus.status`.
   - The leading icon may be filled (`iconFilled`).
2. **The FAB contract** (a `docs/later.md` item):
   - Add `TtNavPill.fabBottom(BuildContext)`: the distance from the bottom of the screen to the FAB's baseline (the pill's reserved height plus `TtSpacing`, as `fab(..., { nav: true })` positions it).
   - `TtFab` gains `lifted`: when a snack is showing, it rises by the snack's height with the motion token. Respect reduced motion.
   - Record it in D-82.
3. **`TtReelHeader`** (`.rd-head` and `.desc`):
   - the name as a wrapping title, 800 30/36 (a token style);
   - a meta row with a large status pill and caret, "N clips · duration", and an optional "N missing" (error colour plus icon, never colour alone);
   - an optional **Shot ideas** block with the lightbulb, clamped to 2 lines with **Show more** / **Show less** when the text is longer than 2 lines at the current width (measured, not counted: the prototype's 90 characters is a stand-in);
   - all text comes from the caller.
4. **`TtViewerChrome`** pieces, always dark, on black (`.viewer`):
   - `TtReelTag`: the `.tagc` "In" chip.
   - `TtViewerActions`: the `.vacts` grid of 3 or 4 equal columns, icon over label, min height 64, 48 dp targets.
   - Reuse `TtPlayerHeader`, `TtStageArrow`, `TtScrubBar` and `TtVideoSurface` from Phase 1.
5. **`TtReelPickRow`** (`sheets.picker` `row`): a 40×52 cover (or the movie icon), the name (1 line), "N clips", and a trailing `TtCheckMark` (multi) or `TtRadioMark` (single). Its semantics are checkbox or radio with the checked state. Also add `TtReelPickNewRow`, the "+ New reel" row with the secondary-container box.

- [ ] **Step 1:** Write the failing widget and golden tests. For each component:
  - each state, light and dark, at 1× and 2× text at 360 dp, with no overflow;
  - `expectTtAccessible`;
  - the semantics.

  Also:
  - `status menu item is a checked menuitemradio`;
  - `fab lifts by the snack height and not under reduced motion`;
  - `shot ideas shows Show more only when clamped`;
  - `viewer actions keep 48 dp targets at 2x`.
- [ ] **Step 2:** Implement, add Widgetbook use cases (the coverage test must pass), and run `tool/check`.
- [ ] **Step 3:** Add D-82 (the FAB contract and the new components). Fill in Section 3. Commit as `feat(ui): reel header, viewer chrome, reel pick rows, status menu items, FAB contract`, then push.

**Mutations (at least):**
- Show more is always shown;
- the FAB is not lifted;
- the pick row is missing its checked semantics.

---

### Task 4: The time where a clip was shot (critical, Opus)

**Model:** Opus.

**Interfaces:**
- **Pigeon** (`pigeons/media_api.dart`, on `MediaHostApi`): `List<int?> zoneOffsetsMs(List<String> zoneIds, List<int> instantsMs)`.
  - The two lists are the same length.
  - Each entry is the UTC offset in ms of `zoneIds[i]` at `instantsMs[i]`, from `ZoneId.of(id).rules.getOffset(Instant.ofEpochMilli(ms))`.
  - An entry is null when the id is not a valid region id (`DateTimeException`). Lists of different lengths throw `IllegalArgumentException`.
  - The call runs off the main thread (`@async`).
- **`MediaBridge.zoneOffsetsMs`** has the same shape, and the fake implements it with a fixed table.
- **`ClipTimeService`** (`lib/data/media/clip_time.dart`, a Riverpod provider):
  - `Future<Map<int, ClipLocalTime>> localTimes(List<Clip> clips)`;
  - `ClipLocalTime { DateTime wallClock /* a non-UTC DateTime whose fields are the local wall-clock time where the clip was shot */, String? zoneId /* the zone used */, bool isPhoneZone }`.

  How it works:
  1. It asks once, in one batch, for every clip whose `(zoneId, dateTakenUtc)` is not already cached. The cache is in memory, keyed by `(zoneId, ms)`, and capped at 4,096 entries (LRU).
  2. Null or unknown zone ids use the phone's current zone (`MediaBridge.currentZoneId`, read once per call).
  3. If the bridge fails, every clip uses the phone's zone, a warning is logged (types and counts only), and nothing throws.
- **Pure rules:**
  - `lib/domain/rules/shooting_days.dart`:
    - `List<ShootingDay> groupByShootingDay(List<ReelClip> clips, Map<int, ClipLocalTime> times)`. Clips are in the order given (oldest first). A day is the calendar date of `wallClock`. Each `ShootingDay` holds the `DateTime date` (date only), `int number` and `List<ReelClip> clips`.
    - `int dayNumber(DateTime firstDay, DateTime day)` is the number of calendar days between the two, plus 1, computed from `DateTime.utc(y, m, d)` values so DST cannot shift it.
    - A clip whose local date is earlier than the previous clip's still goes in its own date's group. The groups are sorted by date, and clips within a group keep their order.
  - `lib/domain/rules/zone_city.dart`: `String? zoneCity(String zoneId)` returns the last `/` segment with `_` replaced by a space ("America/New_York" → "New York", "Asia/Kolkata" → "Kolkata"). It returns null for ids with no `/` (such as "UTC") or `Etc/…`.
- **To tag:** its tile times use `ClipTimeService` too, which fixes D-76's "phone zone" gap. Amend D-76 with "Amended by D-83".

- [ ] **Step 1: Kotlin tests (red)** in `ZoneOffsetsTest.kt`, on all 4 SDKs:
  - `london summer and winter offsets`: 2026-07-01 is +3,600,000; 2026-12-01 is 0;
  - `the exact London DST instant`: 2026-10-25T01:00:00Z is 0 and 00:59:59.999Z is +3,600,000;
  - `kolkata half hour`: +19,800,000;
  - `invalid id is null`: "Not/AZone" and "";
  - `length mismatch throws`;
  - `empty lists give empty`.
- [ ] **Step 2: Dart tests (red):**
  - `clip_time_test.dart`:
    - `uses the clip zone`;
    - `null zone uses the phone zone`;
    - `unknown zone falls back` (the bridge returns null);
    - `one bridge call for many clips`;
    - `cache avoids a second call`;
    - `bridge error falls back and does not throw`;
    - `cache evicts beyond 4096`.
  - `shooting_days_test.dart` (in the London `DST_TESTS` run too):
    - `same local date groups together`;
    - `23:30 London and 00:30 London next day are two days`;
    - `day numbers across the London DST change` (24 and 25 Oct 2026 are Day 1 and Day 2; 26 Oct is Day 3);
    - `a gap of 3 empty days gives Day 1 then Day 5`;
    - `clips shot in two zones group by their own local date`;
    - `out-of-order local dates still sort the groups by date`.
  - `zone_city_test.dart`: the examples above, plus "Europe/Isle_of_Man" → "Isle of Man".
- [ ] **Step 3:** Implement the Kotlin (`ZoneOffsets.kt`, wired in `MediaHostApiImpl`), regenerate Pigeon (`tool/check_generated`), the bridge, the service and the rules. Switch the To tag tiles.
- [ ] **Step 4:** Run `tool/test_android` (all SDKs) and `tool/check`. Add **D-83** (native offsets from the phone's rules instead of a bundled tz database: always current, nothing to update, one batched call; the fallback; the cache). Amend D-76. Fill in Section 4 and update `docs/flow.md`. Commit as `feat: show clips in the time where they were shot`, then push.

**Mutations (at least):**
- `dayNumber` from `Duration.inDays` of local `DateTime`s, which the London run must catch;
- the unknown zone falling back to UTC instead of the phone zone;
- the cache key without the instant.

---

### Task 5: Reel and clip data for the screens, with undo (critical, Opus)

**Model:** Opus.

**Interfaces** (all in `ReelsRepository` / `ClipsRepository`; every change runs in one transaction):
- **`Stream<List<ReelSummary>> watchReelSummaries()`** (`ReelsRepository`):
  - `ReelSummary { Reel reel; int clipCount; int missingCount; int liveDurationMs; Clip? cover }`.
  - `cover` is the oldest clip that is not missing and has a usable identity (the same rule as `watchFirstShowableClip`).
  - It is one query with aggregates plus one cover query, not one query per reel, and is ordered as Home shows it (createdAt desc, id desc).
- **`Stream<List<ReelClip>> watchReelClips(int reelId)`** (`ClipsRepository`) replaces the `Clip` version:
  - `ReelClip { Clip clip; int reelCount; DateTime addedAt }`, in the same order as before.
  - Update the callers.
- **Duplicate names:** `create` and `rename` reject a name that matches another reel's, ignoring case (`toLowerCase` after `normalizeName`), with `ReelNameProblem.duplicate`. The check runs inside the write's transaction. Backup import and Undo of a delete bypass it: restoring the user's data wins over the rule, even if a reel with the same name was created in between.
- **The description cap:** `create` and `setDescription` throw `InvalidInputException(ReelDescriptionProblem.tooLong)` above 1,000 characters (counted with `String.characters` after `normalizeName`).
- **Every action that changes links returns an `UndoRecord`** (`lib/domain/models/undo_record.dart`, a sealed class holding only plain row data), and `Future<void> undo(UndoRecord record)` restores it:
  - **`Future<RemoveUndo> removeClipsFromReel(int reelId, Iterable<int> clipIds)`:**
    - The record holds the removed links (with their `addedAt`), the full rows of the clips the orphan sweep deleted, and the reel's previous `updatedAt`.
    - Undo:
      - re-inserts each swept clip **with its old id**. If a clip with the same identity now exists (another id), it links that clip instead and inserts nothing;
      - re-inserts the links with their old `addedAt`;
      - restores `updatedAt`.
  - **`Future<MoveUndo> moveClips(int fromReelId, int toReelId, Iterable<int> clipIds)`:**
    - It adds the links to the target first, then removes them from the source, so no clip is ever swept in between.
    - The record holds the links created in the target (not the ones that already existed), the removed source links, and both reels' `updatedAt`.
    - Undo deletes only the created links and restores the source ones.
    - `fromReelId == toReelId` throws `ArgumentError`.
  - **`Future<AddUndo> addClipsToReel(int reelId, Iterable<int> clipIds)`:** the record holds the links created (not existing ones) and the inbox rows that were deleted. Undo deletes those links, re-inserts those inbox rows, then sweeps orphans.
  - **`Future<DeleteReelUndo> delete(int reelId)`** (`ReelsRepository`):
    - The record holds the reel row, its links, references and VN session rows (the tables already exist; Phase 8 deletes files first, so before Phase 8 a VN session cannot exist; restore the rows anyway), and the swept clips.
    - Undo re-inserts the reel **with its old id**, then the clips, links and references as above.
    - An unknown id returns a record that restores nothing.
  - **Undo of a record whose reel no longer exists** (the user deleted it meanwhile) restores nothing for that reel, logs a warning, and does not throw. Undo is idempotent: a second undo of the same record changes nothing.

- [ ] **Step 1: Write the failing tests** (in-memory Drift, the fixed clock):
  - Summaries:
    - `summaries count clips, missing and live duration`;
    - `cover is the oldest showable clip`;
    - `a reel with no clips has a null cover and zeros`;
    - `summaries order by createdAt desc then id desc`;
    - `summaries update after a link change`;
    - `one query per emission` (count the statements with a query interceptor; the count must not grow with the number of reels).
  - Reel clips:
    - `reel clips carry reelCount and addedAt`;
    - `duplicate name is rejected ignoring case and edge spaces`;
    - `rename to its own name in another case is fine`;
    - `import with duplicate names still loads`;
    - `undo delete restores even when the name was reused meanwhile`;
    - `description over 1000 is rejected and saves nothing`;
    - `1000 emoji description is accepted`.
  - Remove:
    - `undo remove restores an orphan-swept clip with its id and every field`;
    - `undo remove restores addedAt and updatedAt`;
    - `undo remove links the existing clip when the video came back`;
    - `undo remove twice changes nothing`.
  - Move:
    - `move keeps the clip when it is only in the source`;
    - `move to a reel that already has the clip`;
    - `undo move deletes only the created links`;
    - `move to the same reel throws`.
  - Add:
    - `add undo restores inbox rows`;
    - `add undo sweeps a clip it orphaned`.
  - Delete:
    - `delete undo restores the reel with its id, links, references and swept clips`;
    - `undo after the reel was deleted again restores nothing and does not throw`.
  - Atomicity: `a failing step rolls back everything` (inject a failure after the first statement).
- [ ] **Step 2:** Implement, then run `tool/check`. Coverage stays at 80 % or more.
- [ ] **Step 3:** Add **D-84** (duplicate names rejected, amending D-56; undo records: snapshots in the same transaction, same-id restore, the identity check, idempotent, a gone reel restores nothing; move adds first; summaries as one aggregate). Fill in Section 5 and update `docs/flow.md` ("Undo"). Commit as `feat(data): reel summaries, move, and undo for remove, move, add and delete`, then push.

**Mutations (at least):**
- the swept clip re-inserted without its id;
- move removing before adding;
- undo move deleting links that existed before;
- the description check `>=` instead of `>`.

---

### Task 6: Home, the Reels tab

**Model:** Sonnet.

**Interfaces:**
- `HomeController`, `@riverpod`:
  - It exposes `HomeState { List<ReelSummary> reels; ReelFilter filter; Map<ReelFilter, int> counts; Map<int, ImageProvider?> covers }`. Covers use `clipThumbnail` (D-76).
  - `void setFilter(ReelFilter f)`.
  - `ReelFilter { all, collecting, ready, published }` in `reel_filters.dart`, with the pure functions `filterCounts` and `applyFilter`.
- `localDayProvider` (`lib/core/midnight_tick.dart`) emits the local date now, and again at each next local midnight (a `Timer` from `clockProvider`). `ShootingModeSection` watches it, so "On since" and "Shooting since" update at midnight (a `docs/later.md` item).

**Screen** (`routes.home`, in this order):
1. A large app bar, "Reels".
2. `MediaAccessBanner`.
3. `ShootingModeSection`.
4. The filter chips, only when at least one reel exists: `TtPillTabs`, "All", "Collecting", "Ready to edit" and "Published", each with its count.
5. A two-column grid of `TtReelCard` (`.reelgrid`), as a lazy sliver:
   - cover;
   - status pill;
   - meta "{n} clips · {duration}" (the duration of the clips that aren't missing, `fmt.dur`: `m:ss`, `h:mm:ss`), or "0 clips";
   - "{n} missing";
   - the label "{name}. {status}. {n} clips[, {m} missing]".

   Tapping a card opens reel detail.
6. **Empty states:**
   - **No reels:** the `noreels` illustration, "Plan your first reel", "A reel is a video you're planning, like London Food or Day 1 Vlog. Clips you tag go into it.", and a **New reel** button. No FAB.
   - **A filter with no reels:** the `emptyreel` illustration and "No reels marked {status}", with this body:
     - Published: "When you post a reel, mark it as Published from its page."
     - Ready to edit: "When a reel has all its clips, mark it as Ready to edit."
     - Collecting: "New reels start as Collecting."

     Plus **Show all reels** (tonal), which sets All.
7. **FAB** "New reel" (add icon), only when reels exist, placed by `TtNavPill.fabBottom` and lifted over snacks. It opens the form sheet (Task 7).

Also:
- **The camera snack:** `openCamera()` returning false shows the snack "Couldn't open the camera." (owner-approved copy, 2026-10-30). This applies on Home and on To tag (a `docs/later.md` item).
- Delete `ReelsPlaceholderScreen` and point the `/reels` route at `ReelsScreen`.
- The tab keeps its scroll position.

- [ ] **Step 1: Write the failing tests:**
  - `reel_filters_test.dart`:
    - `counts per status`;
    - `all keeps the createdAt order`;
    - `filter keeps order`.
  - `home_controller_test.dart`: `state follows the repository`, `setFilter`.
  - `midnight_tick_test.dart`: `emits at the next local midnight` (`fakeAsync`; across the London DST night too), `cancels its timer on dispose`.
  - Widget tests:
    - `first-time empty state and its New reel button`;
    - `filter with no results shows its copy and Show all reels`;
    - `cards show cover, status, meta and missing`;
    - `card opens reel detail`;
    - `chips hidden with no reels`;
    - `FAB only with reels`;
    - `20+ reels build lazily` (25 summaries; fewer than 25 cards built);
    - `2x text at 360 dp, light and dark, no overflow`;
    - `expectTtAccessible`;
    - `on-since text changes at midnight`;
    - `camera failure shows the snack` (Home and To tag).
- [ ] **Step 2:** Implement, update the ARB, and run `tool/check`.
- [ ] **Step 3:** Add D-85 (Home: the order, filters, empty states, the midnight tick, and the camera snack). Fill in Section 6 and update `docs/flow.md` ("Home"). Delete the done later.md items. Commit as `feat(reels): Home with filters, reel cards and the New reel button`, then push.

**Mutations (at least):**
- `applyFilter` ignoring `ready`;
- the FAB shown with no reels;
- the tick scheduled 24 h after the start instead of at the next midnight.

---

### Task 7: Create, edit, status and delete

**Model:** Sonnet.

**Interfaces:**
- `ReelFormController` (`@riverpod`, family on `int? reelId`):
  - `Future<Reel?> save({required String name, String? description, ReelStatus? status})`.
  - It returns the reel, or null when there was a validation problem, which is exposed as `nameError` / `descriptionError` (an enum, mapped to copy in the view).
  - Saving is single-flight: a second call while one runs returns the first call's future.
- `showReelForm(BuildContext, {Reel? reel})`.
- `showDeleteReelDialog(BuildContext, Reel)`.
- `confirmDelete` returns the `DeleteReelUndo` from Task 5.
- The status menu uses `TtMenuButton` with the Task 3 items.
- **Undo snacks:** `showUndoSnack(context, message, UndoRecord)` (`undo_snacks.dart`) shows the snack on the shell's `ScaffoldMessenger`, so it survives navigation. Its Undo calls `undo(record)`. If that fails, it shows "Couldn't undo. Try again." (the existing ARB key).

**Sheet** (`sheets.reelForm`, without the reference field, which is Phase 9):
- **Title:** "New reel", or "Reel details" when editing.
- **Name field:** "Reel name", hint "For example: London Food", counter 40, autofocus.
  - Empty → "Give this reel a name".
  - Too long → "Use 40 characters or fewer".
  - Duplicate → "You already have a reel called {name}", using the existing reel's name as stored. The form checks this live against the summaries, and the repository's `duplicate` error is the backstop. An edit doesn't clash with the reel's own name.
  - All three strings are the prototype's `validName` (`app.js:413`).
- **Shot ideas:** "Shot ideas (optional)", multiline, hint "Concept, shots to get, songs to try…", help "Only you see this.", counter shown from 900 characters, max 1,000.
- **Status radios** (edit mode only): "Status", one row per status with its pill and description.
- **Buttons:** Cancel, and **Create reel** / **Save**.
- **After saving:**
  - Create closes the sheet and shows "{name} created".
  - Save shows "Saved".
- **The keyboard** never covers the fields (`viewInsets`).

**Status change** (tap the status pill on reel detail):
- the status menu, with the current status checked;
- choosing one sets it and shows "Marked as {status}" (no Undo).

**Delete** (`dialogs.deleteReel`, without the VN line):
- the delete icon and "Delete {name}?";
- a safe line: "Your videos stay in your gallery. Only this reel and its tags are removed.";
- **Cancel** and **Delete reel** (danger).

Confirming goes back to Home and shows "{name} deleted" with **Undo**, which restores the reel. Confirming twice deletes once.

- [ ] **Step 1: Write the failing tests:**
  - Controller:
    - `empty name error`;
    - `41 characters error`;
    - `duplicate name error ignores case and edge spaces`;
    - `editing keeps its own name without a clash`;
    - `40 emoji ok`;
    - `blank description saved as null`;
    - `double Save creates one reel`;
    - `edit saves name, description and status in one go`.
  - Widget:
    - `create flow shows the created snack`;
    - `edit shows Reel details with status radios`;
    - `status radios are a radiogroup with checked state`;
    - `status menu marks and shows the snack`;
    - `delete dialog copy`;
    - `delete twice deletes once`;
    - `delete Undo restores the reel and its clips` (whole app, `testApp`);
    - `Undo after leaving the screen still works`;
    - `undo failure shows Couldn't undo`;
    - `keyboard does not cover the name field at 2x text, 360 dp`;
    - `expectTtAccessible`.
- [ ] **Step 2:** Implement, update the ARB, and run `tool/check`.
- [ ] **Step 3:** Add D-86 (the form, its validation copy and cap, single-flight saves, the status menu, delete with Undo, and snacks on the shell messenger). Fill in Section 7. Delete the later.md description-cap item. Commit as `feat(reels): create, edit, status and delete with Undo`, then push.

**Mutations (at least):**
- the save not single-flight;
- the snack shown on the route's messenger, which is lost on pop;
- the status radios without checked semantics.

---

### Task 8: Reel detail

**Model:** Sonnet.

**Interfaces:**
- `ReelDetailController` (`@riverpod`, family on `int reelId`):
  - `ReelDetailState { Reel reel; List<ShootingDay> days; int clipCount; int missingCount; int liveDurationMs; bool descriptionOpen }`;
  - `null` once the reel is gone, and the screen then pops to Home;
  - `Future<RemoveUndo> removeMissing(int clipId)`.

  Building it **verifies the reel's clips** through `MediaVerifier` on the `MediaWorkQueue` (spec §8.3, "verified when a reel is shown"). It reuses the verifier's rules: full access only, and an error never means missing.
- **Routes:**
  - `/reels/:reelId`, inside the Reels branch, so the nav pill stays visible as in the prototype.
  - An unknown or deleted id goes to `/reels`.

**Screen** (`routes.reel`):
- **App bar:** back, plus the ⋮ menu (`menus.reelMore`): **Reel details** (the form), **Select clips** (Task 9), and **Delete reel** (danger, Task 7).
- **`TtReelHeader`:**
  - the name, which always wraps fully in the body (a `docs/later.md` item: the app bar title clamps at 1.5×);
  - the status pill, which opens the menu;
  - "{n} clips · {duration}" or "No clips yet";
  - "{m} missing";
  - Shot ideas with Show more / Show less.
- **Clips:** for each `ShootingDay`, a `TtDayHeader` "Day {n} · {date}" (MMMEd in the phone locale, with the year when it is not this year, using the D-79 helper) with the trailing "{k} clips". Then a 3-column grid of `TtClipTile`:
  - the time from `ClipTimeService`;
  - the duration;
  - `reelCount`;
  - `horizontal` when width > height;
  - the label "Clip, {time}, {duration}", plus ", in {k} reels" when k > 1.

  A missing clip is a `TtMissingClipTile` with **Remove**, which shows the snack "Missing clip removed" with Undo. All of this is lazy slivers.
- **Loading:** a skeleton day header and 9 skeleton tiles.
- **Empty:** the `emptyreel` illustration, "No clips yet", "Tag clips from To tag, or add videos from your phone." (the reference sentence is Phase 9), and **Go to To tag** (tonal, `sell`). Add videos is Phase 7, so this state has one button.
- **Taps:**
  - tapping a tile opens the viewer (Task 10) on that clip;
  - a long press starts multi-select (Task 9).

- [ ] **Step 1: Write the failing tests:**
  - `opening a reel verifies its clips` (the fake verifier is called once for this reel's clip ids);
  - `no verify without full access`;
  - `days grouped with Day numbers and counts`;
  - `tile time uses the clip zone`;
  - `in-2-reels badge and label`;
  - `horizontal mark`;
  - `missing tile Remove shows Undo and Undo restores`;
  - `empty state and Go to To tag`;
  - `loading skeleton`;
  - `deleted reel pops to Home`;
  - `unknown id route goes to Reels`;
  - `long name wraps in the body at 2x`;
  - `300 clips build lazily`;
  - `Show more toggles`;
  - `2x text at 360 dp, light and dark`;
  - `expectTtAccessible`.
- [ ] **Step 2:** Implement, update the ARB, and run `tool/check`.
- [ ] **Step 3:** Add D-87 (the route inside the Reels branch, verify on open, day headers, the missing Remove with Undo, and the body title). Fill in Section 8 and update `docs/flow.md` ("Opening a reel"). Delete the later.md title item. Commit as `feat(reels): reel detail with shooting days, badges and missing tiles`, then push.

**Mutations (at least):**
- no verify on open;
- the day header from the UTC date;
- the missing Remove without Undo.

---

### Task 9: Multi-select and the reel picker

**Model:** Sonnet.

**Interfaces:**
- `ReelSelection` (`@riverpod`, family on `int reelId`): `Set<int> selected`, plus `start(int clipId)`, `toggle(int clipId)`, `selectAll()` (clips that are not missing), and `clear()`.
  - Selection ends when it becomes empty, as `toggleSel` does.
  - Missing tiles cannot be selected.
- `Future<List<int>?> showReelPicker(BuildContext, {required ReelPickerMode mode, required int clipCount, required int excludeReelId})`, where `ReelPickerMode { add, move }`. Tag mode is Phase 5. It returns the picked reel ids, or null.

**Selection mode** (`routes.reel`, `sel`):
- **App bar:** `TtAppBar(selection: true)`, "{n} selected", close, and actions:
  - **Add to another reel** (`library_add`);
  - **Move to another reel** (`drive_file_move`);
  - **Remove from this reel** (`playlist_remove`);
  - ⋮ with **Select all**. Edit video and Share are Phase 8.
- **Tiles** show the check and `aria-pressed`. Back or close ends the selection.
- **Remove** shows "{n} clips removed from {reel}. The videos are still in your gallery." with Undo (a plural key; "1 clip").

**Picker** (`sheets.picker`):
- **Title:**
  - add: "Add clip to reels" or "Add {n} clips to reels";
  - move: "Move clip to" or "Move {n} clips to".
- **Subtitle:**
  - add: "It stays in this reel too." (and for several, "They stay in this reel too.", owner-approved);
  - move: "It leaves {reel}." or "They leave {reel}."
- **Rows:**
  - first "+ New reel", which opens an inline name field (`pkname`) with **Create**: the reel is created, picked, and the field closes;
  - then the "Collecting" section;
  - then "Other reels".

  The current reel is excluded. Rows are multi-select for add and single-select for move.
- **Buttons:**
  - Cancel;
  - add: **Add** / "Add to {n} reels" (`Add to 1 reel`);
  - move: **Move**.

  The confirm button is disabled until something is picked.
- **After confirming:**
  - add: "Added to {A}" / "Added to {A} and {B}" / "Added to {A}, {B} and {n} more" (the prototype joins with "and"; the form for more than two reels is owner-approved);
  - move: "Moved to {A}".

  Each snack has Undo, and the selection ends.

- [ ] **Step 1: Write the failing tests:**
  - Selection:
    - `long press starts selection`;
    - `toggle to empty ends selection`;
    - `select all skips missing`;
    - `missing tile cannot be selected`.
  - Picker:
    - `picker excludes the current reel`;
    - `picker sections Collecting then Other reels`;
    - `move is single-select`;
    - `confirm disabled until picked`;
    - `new reel inline creates and picks it`;
    - `empty new reel name shows the error`.
  - Actions:
    - `add snack copy for 1, 2 and 3 reels`;
    - `move removes from this reel and Undo puts it back`;
    - `remove snack copy and Undo`;
    - `Undo after leaving the reel restores`.
  - `2x text at 360 dp`; `expectTtAccessible`.
- [ ] **Step 2:** Implement, update the ARB, and run `tool/check`.
- [ ] **Step 3:** Add D-88 (selection rules, the picker modes, new-reel inline, and the snack copy). Fill in Section 9 and update `docs/flow.md` ("Managing clips in a reel"). Commit as `feat(reels): multi-select, Add to reel, Move and Remove with Undo`, then push.

**Mutations (at least):**
- select all including missing clips;
- move as multi-select;
- the current reel not excluded.

---

### Task 10: The clip viewer

**Model:** Sonnet.

**Interfaces:**
- **Route:** `/reels/:reelId/clip/:clipId`, a full-screen route above the shell (no nav pill), always dark.
- **`ClipViewerController`** (family on `(reelId, clipId)`):
  - the reel's clips that are **not missing**, in order;
  - the current index;
  - each clip's `ClipLocalTime`;
  - the reels the current clip is in (names, from `watchReelIdsOf` plus the reels).
- **`clipVideoUri(Clip)`** (`lib/platform/media_bridge.dart`):
  - returns `content://media/{volumeName}/video/media/{mediaStoreId}` for a MediaStore clip with `mediaStoreId > 0`;
  - returns `Uri.parse(pickerUri)` for a picked clip;
  - returns null otherwise.

  Prove on the S24 that the URI plays (Task 11).
- **`video_player`:**
  - `VideoPlayerController.contentUri`, one controller for the visible page, disposed on page change and on leaving.
  - Pause when the app goes to the background.
  - Sound starts on, and the mute toggle is kept for the session.

**Screen** (`routes.viewer`, always dark):
- **Top:** back, "{i} of {n} · {reel}", the date and time (from `ClipLocalTime`), plus " · {city} time" when `!isPhoneZone && zoneCity != null`, and the mute toggle with its label ("Mute" / "Unmute").
- **The stage:**
  - fits vertical and horizontal videos (`.vstage.h`);
  - swipe left or right between clips (`PageView`), plus the ‹ › stage arrows, disabled at the ends;
  - tap to play or pause.
- **Bottom:**
  - the scrubber (`TtScrubBar`, position / duration, seek);
  - "In" with a `TtReelTag` per reel;
  - `TtViewerActions`: **Add to reel**, **Move** and **Remove**.
- **Actions:**
  - Add opens the picker in add mode (Task 9).
  - Move opens it in move mode; after moving, the viewer goes to the next clip (or the previous one at the end, or closes when none is left: `viewerAfterLeave`).
  - Remove shows "Removed from {reel}. The video is still in your gallery." with Undo, then leaves the same way.
- **Can't play** (a player error, or no usable URI): the error icon, "This video can't be played", "It may be damaged, or in a format your phone doesn't support. The file is still in your gallery.", and **Remove from reel** (tonal).
- **Semantics:** the arrows ("Previous clip", "Next clip"), the scrubber, and the clip label.

- [ ] **Step 1: Write the failing tests:**
  - `clipVideoUri`:
    - `builds the MediaStore content uri`;
    - `picker uri passes through`;
    - `detached id gives null`;
    - `missing flag gives null`.
  - Controller and widget (a fake `VideoPlayerPlatform`):
    - `missing clips are not in the pager`;
    - `opens on the tapped clip`;
    - `swipe and arrows move; arrows disabled at the ends`;
    - `header shows London time only when the zone differs`;
    - `in-reels chips`;
    - `player error shows the can't-play state and Remove from reel`;
    - `remove leaves to the next clip, then the previous, then closes`;
    - `move leaves the same way`;
    - `one controller alive; disposed on page change and on pop`;
    - `pauses on app pause`;
    - `mute toggle label`;
    - `2x text at 360 dp`;
    - `expectTtAccessible` (on dark).
- [ ] **Step 2:** Add `video_player`, implement, update the ARB, and run `tool/check`. `tool/check_release_permissions` must still pass: no INTERNET, and `video_player` must not add it to the release manifest. Prove that with the merged-manifest check.
- [ ] **Step 3:** Add D-89 (playing the original from its content URI, one controller, the leave rule, the can't-play state, the city label, and the `video_player` version). Fill in Section 10 and update `docs/flow.md` ("Watching a clip"). Commit as `feat(clips): full-screen clip viewer`, then push.

**Mutations (at least):**
- the detached id builds a URI;
- the controller not disposed on page change;
- the city shown when the zone is the phone's.

---

### Task 11: On the S24 (needs the phone; the controller runs it)

**Model:** Sonnet writes the Patrol test. The controller runs it on the phone.

- [ ] **Step 1:** Write `patrol_test/reels_test.dart`. Every bridge query stays inside `Movies/TakeTray Test/` (D-77), and the test cleans up in its tear-down.
  1. **Create:** create the reel "Patrol Reel", check the card, open it, rename it through Reel details, mark it Ready to edit, and check the pill.
  2. **Clips:** make one test video (`tool/make_test_video` fixture), add it to the reel through `ClipsRepository.addNewClipsToReel` with its MediaStore row (the test's own provider container), open the reel, and check the Day 1 header and the tile.
  3. **Viewer:** open the viewer, check that the video plays (the position advances past 0 within 5 s), and that "1 of 1" shows.
  4. **Remove:** Remove, check that the reel is empty, then Undo and check that the tile is back.
  5. **Delete:** delete the reel, check that Home has no card, then Undo and check that the card is back. Then delete it for good, and delete the test video.
- [ ] **Step 2:** The controller runs the test on the S24 and reinstalls the normal debug build afterwards.
- [ ] **Step 3:** Update the `docs/dev-setup.md` Phase 4 owner check, about 8 steps: create, edit, filter, open, viewer with a real clip shot abroad if available, multi-select Move with Undo, delete with Undo, and dark mode. Fill in Section 11. Commit as `test(e2e): reels flows on the phone`, then push.

---

### Task 12: Finish the learning guide and the README (docs only, done by the controller)

- [ ] Join the guide's sections into one read-through.
- [ ] README: Phase 4 **Done** with what it added; Phase 5 **Next**. Keep the logo.
- [ ] Commit as `docs: Phase 4 learning guide and README`, then push.

---

## After the tasks

1. **Final whole-branch review** (Opus) against this plan, the spec and the Review Focus. One fix wave, then a fresh re-review.
2. **Green CI** on the branch, then the owner's phone check (`docs/dev-setup.md` Phase 4).
3. **Pull request** `phase-4-reels` → `main`, titled "Phase 4: Reels". It ends with the Claude Code line, must be green, and the owner approves. Then merge and delete the branch.
4. **Known gaps go into `docs/later.md`:** Share, Edit video, the VN pieces (Phase 8), Add videos (Phase 7), the references pieces (Phase 9), and the picker's tag mode (Phase 5).
