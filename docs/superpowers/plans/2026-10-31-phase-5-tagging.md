# Phase 5: Tagging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the core loop. The user sorts a day's clips into reels quickly. Phase 5 builds:
- **To tag v2:** clips grouped into **scenes** (and days), the summary row, **Tag scene**, **Start tagging**, tapping a tile to tag from it, long-press multi-select (Tag / Skip), the ⋮ menu (Add earlier videos, Select clips, Skipped (n), Skip all), Skip all with a confirmation and Undo, and an error state.
- **The tag player:** the clip plays muted, one tap on a reel chip tags it and moves on, sticky **Pick several**, **Same as previous**, **Skip**, **+ New reel**, the progress "n of N" with scenes, previous/next without tagging, Undo that goes back to the clip, and the **All done!** screen.
- **The Skipped list:** grouped by day, Restore one, multi-select Restore, each with Undo.
- **The reel picker's tag mode** (parked in Phase 4).

The phase is done when a day of 40 clips can be tagged quickly and the Patrol flow passes on the S24 Ultra (spec §9, phase 5).

**Architecture:**
- **Pure rules** in `app/lib/domain/rules/`: `scenes.dart` (grouping by the 10-minute gap and the local day) and `tag_queue.dart` (which clip is next, previous, or the end, given the session order and what is still pending).
- **Data:**
  - Tagging reuses `ClipsRepository.addClipsToReels` and its `AddUndo` records (D-84). Undo puts the clip back in To tag with its own `inbox` row.
  - Skip, Skip all and Restore return a new `InboxUndo` record, restored by `UndoWriter`.
- **View models** (Riverpod codegen) in `app/lib/features/tagging/`: `TagSessionController` (the player's state machine), `ToTagSelection`, `SkippedController`, `LastTags` (the reels of the last tag, for "Same as previous").
- **Screens** are built from `taketray_ui` components and tokens only. The Phase 5 design-system debts in `docs/later.md` are paid first (Tasks 2–3).
- **The tag player** plays the original through `video_player` (D-89's `clipPlayer`), muted by default, and keeps the next clip's player ready so tagging feels instant.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 via `tool/flutter`; Riverpod 3 codegen; Drift (schema **stays v1**, no migration); freezed; go_router; gen-l10n; alchemist goldens (macOS plus CI sets, D-61); `video_player` 2.14.1 (D-89); Patrol 4.10 on the S24. No new package.

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`: §3 ("Pick several" sticky; Published folded under "Other reels"), §4, §7, §8.1 (`inbox`), §8.3 (missing media), §8.3a (times where shot), §8.4 (scenes, tag player), §9 phase 5, §10, §11.

**Also read:**
- `docs/design-prompt.md` §5 (rules), §6.3 (tagging, the most important flow), §7 screens 11–15, §8 (copy).
- The prototype `design/prototype/`, the visual source of truth:
  - `assets/screens.js`: `routes.totag`, `routes.player`, `routes['player-done']`, `routes.skipped`, `sheets.picker` (tag mode), `sheets.reelForm` (`from: 'player'`), `dialogs.skipAll`, `menus.totagMore`;
  - `assets/ui.js`: `sceneHeader`, `reelChip`, `tile`;
  - `assets/data.js`: `q.scenes`, `fmt.range`, `fmt.mins`, `fmt.dayRel`;
  - `assets/app.js`: `playerStart`, `findNext`, `advance`, `tagCurrent`, `chip`, `chipLong`, `multi*`, `sameAsPrev`, `skipClip`, `selSkip`, `confirmSkipAll`, `restoreOne`, `restoreSel`, `pickerConfirm` (tag);
  - `index.html` → Motion (the 400 ms chip hold, scene tagging), Accessibility (labels), Handoff (tag player sizes);
  - `proto.css` and `tt-style.css`.
- Parked items: the "Phase 5" section of `docs/later.md`.

## Global Constraints

- **SDK:** `tool/flutter`, `tool/dart`, `tool/adb`, `tool/patrol` only. Never the `flutter` on PATH; never touch `~/flutter`. Iterate with `tool/test_android -ProbolectricSdks=35`; all four SDKs and `tool/check` green before a commit.
- **Owner rulings (spec §3 and plan review 2026-10-31):**
  - **"Pick several" is sticky:** it stays on from clip to clip until the user taps Cancel (overrides the prototype, which resets it). The picks are cleared at each new clip.
  - **"Other reels"** holds Ready to edit **and** Published reels, folded by default ("Other reels (4)"); Collecting reels are always open. With no Collecting reel, Other reels is open. As the reel picker does (D-88).
  - **Player Undo goes back:** Undo on "Added to …" or "Skipped" puts the clip back in To tag **and** the player returns to that clip (when the player is still open).
  - **Video scrim:** the prototype's values win: top `rgba(0,0,0,0.78)`, bottom `rgba(0,0,0,0.6)`, solid fade as in `proto.css`. Change the token source (`design/tools/build_tokens.py`), regenerate, and update D-47's note.
  - **To tag error state copy:** title "Couldn't load your clips", body "Your videos are safe in your gallery.", button "Try again".
- **Copy (prototype, verbatim; "Recording" is "Collecting", D-80):**
  - To tag: summary "{n} clips · {s} scenes · {mins}"; scene header "{range}" over "{n} clips · {m:ss}" with **Tag scene** (semantics "Tag scene {range}, {n} clips"); FAB **Start tagging**; selection bar "{n} selected", **Skip**, **Tag**; scene header in selection: **Select all** / **Unselect**; menu **Add earlier videos** (full access only), **Select clips**, **Skipped ({n})**, **Skip all**; empty states unchanged plus a **Skipped ({n})** button under them when any are skipped.
  - Skip all dialog: "Skip all {n} clips?", "They move to Skipped, and you can restore them any time.", the green "Your videos stay in your gallery.", **Cancel** / **Skip all**. Snack "{n} clips skipped" with Undo.
  - Multi-select skip snack "{n} clips skipped" with Undo.
  - Picker tag mode: title "Tag {n} clips", subtitle "Pick one or more reels.", confirm "Tag {n} clips" (one reel picked) or "Tag into {k} reels" (more); snack "{n} clips added to {names}" with Undo, `{names}` joined as Phase 4's `addedToText` joins them ("A", "A and B", "A, B and {k} more").
  - Player: header "{i} of {N}" over "Scene {s} of {S} · {range}"; **Close tagging**; **Mute** / **Unmute**; **Previous clip** / **Next clip**; video label "Pause clip, {time}, {m:ss}" / "Play clip, …"; panel title **Add to reel** with **Pick several** (only when there are 2+ reels); in Pick several: "Pick reels for this clip" with **Cancel**, footer "Add to {k} reels & next" or, disabled, "Pick one or more reels"; **New reel** chip "Add this clip to it"; **Other reels ({n})** / **Other reels**; no reels: "You don't have any reels yet. Create one and this clip goes into it."; quick row **Skip** (semantics "Skip this clip") and **Same as previous** with the reel names under it (semantics "Same as previous: {names}"); chip semantics "Add to {name}, {n} clips".
  - Player snacks: "Added to {names}" (`addedToText`) and "Skipped", each with Undo.
  - Reel form from the player: title "New reel", subtitle "This clip will be added to it.", only the name field, button **Create and add**.
  - Done: "All done!", "{n} clips sorted. Nice work.", one row per reel "{name}" "+{n}", a "Skipped" row "{n}" when any, **See your reels**, **Back to To tag**.
  - Skipped: app bar "Skipped" with back and **Select**; info bar "Skipped clips are still in your gallery. Restore any you want to tag."; day headers "{day}" with "{n} clips"; tap a tile restores it: snack "Restored to To tag" with Undo; selection bar "{n} selected" with **Restore**: snack "{n} clips restored to To tag" with Undo; empty "No skipped clips" / "Clips you skip in To tag show up here, in case you change your mind."
  - Plurals through ICU (`{count, plural, one{1 clip} other{{count} clips}}`). Durations: `formatClipDuration` (m:ss); `{mins}` is the prototype's `fmt.mins` ("45 s", "12 min", "1 h 5 min").
- **Times (spec §8.3a, D-83):** scene ranges, tile times, day headers and the player's range use the time where the clip was shot (`ClipTimeService`), the phone's zone until the answer arrives. The 10-minute gap is measured on UTC instants; a new local day always starts a new scene. Ranges follow the phone's locale and 24-hour setting; in 12-hour time a shared am/pm is written once ("1:05–1:20 pm"); a range under a minute is one time.
- **Wrong video is the worst bug (spec §4):** the player plays a clip only from its stored identity (`clipVideoUri`, D-89). A clip flagged missing, or with no usable identity, shows the can't-play state and is never replaced by another video. A tag always goes to the clip whose id the player shows, never "the current index" read after an await.
- **No lost tags (spec §4):** every tag, skip, skip all and restore is one transaction; Undo restores with the same ids and `addedAt`; a double tap tags once.
- **Privacy (D-10):** log lines never hold a reel name, display name, path, URI or zone city. Ids and counts only.
- **Accessibility:** 48 dp targets; every icon-only button labelled; snacks are polite live regions; the player's "{i} of {N}" is a polite live region; each gesture has a button (swipe → arrows, long-press → Select clips / Pick several); reduced motion: the chip hold is 120 ms, no slide.
- **No Haiku, ever.** Tasks 4 and 6 and the final review run on **Opus**. Every other code task runs on **Sonnet**. Always name the model.
- **Reviews (owner rules):** every code task gets a fresh task reviewer; docs-only tasks (1 and 11) skip it, with a ledger line. Per-task fix rounds are self-reviewed by the fixer. **Hybrid rule:** Critical and Important findings are fixed in the task's loop; Minor findings are parked in the ledger and fixed in **one minors batch** before the final review, by one agent that reviews its own fixes. The final review's fix wave gets a separate re-review.
- **Tight testing (owner's rule):** each listed test red first, then green, both runs quoted in the report; at least two **mutation checks** per task, each applied alone then reverted, with the failing output quoted; never loosen, skip or delete a test to get green; Android behaviour proven on the S24 in Task 10.
- **Style rules:** no raw colours, sizes, text styles, radii, `EdgeInsets` numbers or animation durations in feature code (`tool/check_styles`); each new or changed component has goldens (light/dark, 1× and 2× text, macOS **and** CI sets, D-61), a Widgetbook use case, and passes `expectTtAccessible`; every string in `app_en.arb`.
- **Phone rule:** only `app.taketray`, `app.taketray.dev`, `app.taketray.widgetbook` may be installed, cleared or run; never uninstall or clear `app.taketray`. Logcat only through a TakeTray pid filter. No screenshots; no reading of other apps or shared storage. Patrol tests create and delete only their own videos in `Movies/TakeTray Test/` (D-77), and every bridge query stays in that folder. Settings a test changes are restored **at the end of the test body** (`watchOnlyTestFolder`), never in a tear-down. The limited-access test stays skipped. After any Patrol run: `tool/flutter build apk --debug`, `tool/adb install -r …app-debug.apk`, `tool/adb shell pm clear app.taketray.dev` (`docs/dev-setup.md`).
- **Coverage:** ≥ 80 % for `lib/domain/`, `lib/data/`, `lib/platform/` (excluding `*.g.dart`) and `lib/features/*/view_models/`.
- **Living docs:** the next free decision number is **D-91**; tasks take the next free numbers in order. Every changed flow updates `docs/flow.md`. Every finished `docs/later.md` item is deleted in the same commit as its code.
- **Learning guide:** `docs/learn/phase-5-tagging.md`. Task 1 stubs one section per task; Tasks 2–10 each fill their own section with the Phase 4 template (what we built / why / key ideas with short real snippets / where it lives / try it yourself / decisions). A wrong explanation is a review defect.
- **Git (D-63):** branch `phase-5-tagging`; push after every task commit with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u origin phase-5-tagging`. A task is complete only when CI is green on its commit. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never force-push. The phase lands through a PR after the owner approves.

## Review Focus

1. **Racing taps in the player.** A chip tapped twice, a chip then Skip within the 400 ms hold, Same as previous while a tag is writing, Undo tapped while the next tag writes, the back button during the hold. Expected: one action per clip, the tag lands on the clip that was showing, Undo restores exactly that one, nothing throws. Owner: Task 6 (`double tap on a chip tags once`, `skip during the hold is ignored`, `tag goes to the clip shown when tapped`, `undo while the next tag writes restores the right clip`, `closing during the hold tags nothing`).
2. **The list changes under the player.** A scan adds clips, the verifier removes a missing one, or a clip in the session is tagged from elsewhere. Expected: the session order is fixed at start; clips no longer pending are passed over; the clip on screen leaving To tag moves the player on; new clips are not in this session and the done screen says "Back to To tag". Owner: Task 5 (`next skips clips no longer pending`, `wraps to the first pending before the current`), Task 6 (`current clip leaving To tag moves on`).
3. **Scenes across midnight, zones and odd clips.** A 23:55 clip and a 00:02 clip; a London clip next to an Indian one; clips with the same time; a 0 ms or 2-hour clip; one clip. Expected: a new local day is a new scene; the gap is end-of-previous to start-of-next on UTC; equal times keep id order; the range is first start to last start. Owner: Task 5 (`midnight splits a scene`, `gap is measured from the previous clip's end`, `exactly 10 minutes starts a new scene`, `zones use the shot zone's day`).
4. **Undo after things moved on.** Skip all, then a scan adds clips, then Undo; skip a clip, tag it from the picker, then Undo the skip; restore from Skipped, then tag it, then Undo. Expected: Undo restores only rows still in the state the action left them; it never pulls a newly tagged clip back into Skipped, never touches clips that arrived later, and a second Undo changes nothing. Owner: Task 4 (`undo skip all leaves new clips pending`, `undo skip does not untag a clip tagged since`, `undo restore leaves a tagged clip alone`, `undo is idempotent`).
5. **Large and awkward data:** 300 pending clips over 6 days and 60 scenes; 25 reels (5 Collecting, 20 folded); a 40-character emoji reel name on a chip; 2× text at 360 dp in the player. Expected: lazy slivers; the tag panel caps its height and scrolls so the video keeps its space; chips go one column at ≥ 1.5×; nothing overflows. Owner: Task 3 (`panel caps its height at 2x and scrolls`), Task 7 (`25 reels: only Collecting chips open`), Task 8 (`300 clips build lazily`).

---

## File structure

**Create (app):**
- `lib/domain/rules/scenes.dart`: `Scene`, `groupIntoScenes`, `sceneGap`.
- `lib/domain/rules/tag_queue.dart`: `TagQueue`.
- `lib/domain/rules/time_range_text.dart`: `timeRangeText`, `minutesText`.
- `lib/features/tagging/view_models/`: `tag_session_controller.dart`, `last_tags.dart`, `to_tag_selection.dart`, `to_tag_scenes.dart`, `skipped_controller.dart`, `tag_player_muted.dart`.
- `lib/features/tagging/views/`: `tag_player_screen.dart`, `tag_done_view.dart`, `skip_all_dialog.dart`, `skipped_screen.dart`, `tagging_snacks.dart`.
- `docs/learn/phase-5-tagging.md`, `patrol_test/tagging_test.dart`.

**Modify (app):**
- `lib/domain/models/undo_record.dart` (`InboxUndo`), `lib/data/repositories/clips_repository.dart`, `undo_writer.dart`.
- `lib/features/tagging/views/to_tag_screen.dart`, `view_models/to_tag_controller.dart`.
- `lib/features/reels/views/reel_picker_sheet.dart`, `view_models/reel_picker.dart` (tag mode), `reel_form_sheet.dart` (from the player), `view_models/clip_player.dart` (mute source per use).
- `lib/router/app_router.dart`, `routes.dart`; `lib/l10n/app_en.arb`.

**taketray_ui** (Tasks 2–3): `player_chrome.dart`, `video_surface.dart`, `nav_pill.dart`, `snack.dart`, `tag_panel.dart`, `reel_chip.dart`, `headers.dart`, `clip_tile.dart`, new `tag_done.dart` and `info_bar.dart`, and `internal/dashed_border.dart`, `internal/scrim.dart`; tests, goldens, Widgetbook.

---

### Task 1: Plan, scope decision and the learning-guide stub (docs only, by the controller)

**Model:** the controller, inline. No task review (docs only; ledger line).

- [ ] **Step 1:** Commit this plan.
- [ ] **Step 2:** Create `docs/learn/phase-5-tagging.md` with a "How to read" intro and one stub section per Task 2–10.
- [ ] **Step 3:** Add **D-91 · Phase 5 scope**: what this phase builds (Goal list); what waits (Add videos and the picker in Manual mode: Phase 7; notifications and the evening reminder: Phase 6; editing: Phase 8); the owner rulings in Global Constraints (sticky Pick several, Other reels, Undo goes back, prototype scrim, error copy); the clip on screen leaving To tag moves the player on.
- [ ] **Step 4:** Commit `docs: Phase 5 plan, scope decision and learning guide stub`, push.

---

### Task 2: Player chrome debts (design system)

**Model:** Sonnet.

**Files:** `packages/taketray_ui/lib/src/components/player_chrome.dart`, `video_surface.dart`, `nav_pill.dart`, `snack.dart`, `clip_tile.dart`, `tag_panel.dart` (painter move only), new `internal/dashed_border.dart` and `internal/scrim.dart`; `design/tools/build_tokens.py` and its generated outputs; tests, goldens, Widgetbook.

Each bullet is a `docs/later.md` "Phase 5" item. Fix it, test it, delete the item:
- **Scrub bar semantics:** the value reads "{position} of {duration}" (the caller passes `semanticValue`; the package composes no string, D-81), with `increasedValue` / `decreasedValue` for a 5 % step and `onIncrease` / `onDecrease` calling `onSeek`.
- **Scrub row:** 22 dp tall visually (CSS `.scrub`) inside a 48 dp gesture area; the thumb sits fully inside the gesture area; remove the redundant `SizedBox`; the quick-row padding as in `.qrow`.
- **Video scrim:** top `.78`, bottom `.6`, solid fade (owner ruling) in the token source; regenerate (`python3 design/tools/build_tokens.py`), and the contrast note in `build_tokens.py` follows.
- **Dedupe:** the dashed-outline painters (`clip_tile.dart` `_DashedBorderPainter` and any in `tag_panel.dart`) become `internal/dashed_border.dart`; the scrim widgets (`video_surface.dart` `_Scrim`, `clip_tile.dart` `_Scrim`) become `internal/scrim.dart`. Goldens must not change from the dedupe alone.
- **Nav badge label:** the To tag tab reads "To tag, 7 clips" (the caller passes the whole label).
- **Snack shadow:** add the elevation-3 shadow token as in `tt-style.css` `.snack`, or, if the CSS has none, record why in D-48. Check the CSS first.
- `video_surface_test` uses `expectTtAccessible`.

- [ ] **Step 1:** Failing tests: `scrub bar value reads position of duration`, `scrub bar increase seeks forward 5 percent`, `scrub thumb stays inside the gesture area`, `scrub row is 48 dp to touch and 22 dp drawn`, `scrim uses the prototype stops`, `nav badge label keeps the tab name`, `video surface is accessible`.
- [ ] **Step 2:** Implement; regenerate the goldens that change (macOS; the controller makes the CI set after push); `tool/check`.
- [ ] **Step 3:** Add **D-92** (the scrub semantics, the scrim values with the owner's ruling, amending D-47; the shared internal painters). Fill guide Section 2. Delete the done later items. Commit `fix(ui): player chrome debts for tagging`, push.

**Mutations:** scrub semantics value removed; scrim back to .7/.55; badge label drops the tab name.

---

### Task 3: The tag panel, done summary, info bar and scene header selection (design system)

**Model:** Sonnet.

**Files:** `tag_panel.dart`, `reel_chip.dart`, `headers.dart`, new `tag_done.dart` and `info_bar.dart`; exports, tests, goldens, Widgetbook.

Build from `routes.player`, `routes['player-done']`, `routes.skipped` and the CSS (`.tagpanel`, `.chipgrid`, `.rchip.new`, `.lbl`, `.multi-foot`, `.done-scr`, `.sum`, `.infobar`):
1. **`TtTagPanel`** (later items):
   - a semantics group labelled by the caller (`semanticLabel`, "Reels");
   - a height cap: at most `size.tagPanelMax` (340 dp at 1×, budgeted up to 520 dp at large text as D-47 says), and its chip grid scrolls inside it;
   - slots for: the chips of the open group, an **`TtOtherReelsToggle`** (label text, `expanded`, `onToggle`, `aria-expanded` semantics, expand_more/less icon, 36 dp tall with a 48 dp target), the folded chips, a full-width **empty message** (`emptyText`), and the footer;
   - **`TtNewReelChip`**: the dashed "New reel" chip (`.rchip.new`), title and subtitle from the caller, a `fullWidth` variant for the no-reels state, using `internal/dashed_border.dart`.
2. **`TtReelChip`:** relabel or drop the 164 dp scenarios that cannot happen at 2× (later item).
3. **`TtSceneHeader`:** its `action` stays a widget; add a test for the selection variant (a text **Select all** / **Unselect** button).
4. **`TtTagDone`** (`.done-scr`): the check badge, title, body, a summary list of rows (name, "+n"), and two actions; always dark (inside `TakeTrayTheme.video()`).
5. **`TtInfoBar`** (`.infobar`): info icon plus a wrapping line.

- [ ] **Step 1:** Failing tests, per component: each state, light and dark (the panel and done are dark only), 1× and 2× at 360 dp, no overflow, `expectTtAccessible`, semantics. Also `panel caps its height at 2x and scrolls`, `other reels toggle reports expanded`, `panel is one semantics group`, `new reel chip spans the row when fullWidth`, `done rows read name then count`.
- [ ] **Step 2:** Implement, Widgetbook use cases (the coverage test must pass), `tool/check`.
- [ ] **Step 3:** Add **D-93** (the panel's slots and cap, the toggle, `TtTagDone`, `TtInfoBar`). Fill Section 3. Delete the done later items. Commit `feat(ui): tag panel groups, new reel chip, done summary, info bar`, push.

**Mutations:** the cap removed; the toggle's expanded semantics dropped; the new-reel chip loses its dashed border.

---

### Task 4: Skip, Skip all and Restore with Undo (data, critical, Opus)

**Model:** Opus.

**Files:** `lib/domain/models/undo_record.dart`, `lib/data/repositories/clips_repository.dart`, `undo_writer.dart`; `test/data/repositories/clips_repository_inbox_test.dart`, `test/data/repositories/undo_writer_inbox_test.dart`.

**Interfaces:**
- Produces:
  - `final class InboxUndo extends UndoRecord { InboxUndo({required List<InboxEntry> before, required InboxState after}); final List<InboxEntry> before; final InboxState after; bool get isEmpty => before.isEmpty; }`: the rows the action changed, as they were, and the state it set.
  - `ClipsRepository.skipClips(Iterable<int> clipIds) → Future<InboxUndo>`: pending → skipped for the given ids that are pending; others ignored. One transaction.
  - `ClipsRepository.skipAllPending() → Future<InboxUndo>`: every pending row → skipped, in one transaction (reads and writes inside it, so a scan's insert either is in the record or stays pending).
  - `ClipsRepository.restoreClips(Iterable<int> clipIds) → Future<InboxUndo>`: skipped → pending for the given ids that are skipped.
  - Each sets the changed rows' `addedAt` unchanged (the state is what moves), logs counts only.
  - `UndoWriter` restores an `InboxUndo`: for each entry, if the clip still has an `inbox` row **in state `after`**, set it back to `before.state` and `before.addedAt`; otherwise leave it (it was tagged, restored or skipped since). Through `undo` and `undoAll` like the others; idempotent (Expando, D-84).
  - The old `skip` / `restore` (Phase 2, no record) are replaced by the new ones; update their callers and tests.
- Consumes: `addClipsToReels` / `AddUndo` unchanged (tagging).

- [ ] **Step 1:** Failing tests: `skip moves pending to skipped and returns them`, `skip ignores tagged and skipped clips`, `skip all takes every pending in one transaction`, `restore moves skipped to pending`, `undo skip puts them back pending with addedAt`, `undo skip all leaves new clips pending`, `undo skip does not untag a clip tagged since`, `undo restore leaves a tagged clip alone`, `undo is idempotent`, `undoAll of an add and a skip is one transaction`, `empty ids give an empty record`, `undo add after tag puts the clip back in To tag with its addedAt` (pins the player's Undo on existing code).
- [ ] **Step 2:** Implement. `tool/check`.
- [ ] **Step 3:** Add **D-94** (`InboxUndo` and its "only rows still in the after state" rule; skip all in one transaction; tagging reuses `addClipsToReels`). Update `docs/flow.md` (skip, skip all, restore, undo). Fill Section 4. Commit `feat(data): skip, skip all and restore with undo records`, push.

**Mutations:** undo ignores the "still in after state" check; skip all reads outside the transaction (a test interleaves an insert); `addedAt` overwritten on skip.

---

### Task 5: Scenes, the tag queue and time ranges (pure rules)

**Model:** Sonnet.

**Files:** `lib/domain/rules/scenes.dart`, `tag_queue.dart`, `time_range_text.dart`; tests under `test/domain/rules/`.

**Interfaces:**
- `const Duration sceneGap = Duration(minutes: 10);`
- `class Scene { final List<Clip> clips; final DateTime start; final DateTime end; final DateTime day; }`: `start`/`end` are wall-clock times where shot (`ClipLocalTime.wallClock`, or the phone's local time when unknown) of the first and **last clip's start**; `day` is the date of `start`.
- `List<Scene> groupIntoScenes(List<Clip> clips, Map<int, ClipLocalTime> times, {Duration gap = sceneGap})`: `clips` sorted by shooting order first (`inShootingOrder`); a new scene starts when `next.dateTakenUtc − (prev.dateTakenUtc + prev.durationMs) ≥ gap` (UTC), or the local day differs. A negative gap (overlap) stays in the scene.
- `class TagQueue { TagQueue(List<int> session); int? next(int from, Set<int> pending); int? previous(int from, Set<int> pending); int? afterAction(int from, Set<int> pending); }`: indexes into the fixed `session`. `next`/`previous` find the nearest pending index in that direction, or null. `afterAction` is the prototype's `advance`: the next pending after `from`, else the first pending from the start, else null (done).
- `String timeRangeText(DateTime start, DateTime end, {required String locale, required bool use24Hour})`: under a minute apart → one time; 12-hour with the same am/pm → "1:05–1:20 pm" (the period once, after the second); otherwise "11:50 am–12:10 pm"; 24-hour → "13:05–13:20". Uses the D-76 time helpers' formatting.
- `String minutesText(AppLocalizations l10n, int totalMs)`: `fmt.mins` through ARB strings ("45 s", "12 min", "1 h 5 min").

- [ ] **Step 1:** Failing tests: `one clip is one scene`, `gap is measured from the previous clip's end`, `exactly 10 minutes starts a new scene`, `9 minutes 59 seconds stays`, `overlapping clips stay together`, `midnight splits a scene`, `zones use the shot zone's day`, `unknown time uses the phone's local day`, `equal times keep id order`, `range is first start to last start`; `next skips clips no longer pending`, `previous skips too`, `afterAction wraps to the first pending before the current`, `afterAction is null when none pending`, `empty session`; `range shares am/pm`, `range across noon`, `range under a minute is one time`, `24-hour range`, `minutes text 45 s / 12 min / 1 h 5 min`.
- [ ] **Step 2:** Implement. `tool/check`.
- [ ] **Step 3:** Add **D-95** (the scene rule: gap from end to start on UTC, a new local day splits, range to the last start; `TagQueue`). Fill Section 5. Commit `feat(domain): scenes, the tag queue and time ranges`, push.

**Mutations:** gap measured start-to-start; midnight split removed; `afterAction` without the wrap.

---

### Task 6: The tag session (view model, critical, Opus)

**Model:** Opus.

**Files:** `lib/features/tagging/view_models/tag_session_controller.dart`, `last_tags.dart`, `tag_player_muted.dart`; `lib/features/reels/view_models/clip_player.dart`; tests under `test/features/tagging/view_models/`.

**Interfaces:**
- Consumes: `TagQueue`, `groupIntoScenes`, `ClipTimeService`, `ClipsRepository.addClipsToReels` / `skipClips` / `undoAll`, `ReelsRepository.create`, `watchReelSummaries`, `watchInbox(pending)`, `Clock`.
- Produces:
  - `@Riverpod(keepAlive: true) class LastTags`: `List<int>` of the reels of the last tag (player or picker tag mode), `set(List<int>)`; not stored. `sameAsPrevious` uses the ids that still exist.
  - `@Riverpod(keepAlive: true) class TagPlayerMuted`: starts **true** (design brief §6.3), `toggle()`, kept for the app session.
  - `clipPlayer(Ref, Uri uri, {ClipPlayerUse use = ClipPlayerUse.viewer})`: `ClipPlayerUse { viewer, tagging }` picks the mute provider; tagging **loops** the clip. The viewer is unchanged.
  - `@riverpod class TagSessionController` (family on `int? startClipId`; auto-dispose with the route). State `TagSessionState` (freezed):
    - `List<int> session` (pending ids in shooting order at start, fixed), `int index`, `bool multi`, `List<int> picked`, `int? confirmingReelId`, `bool busy`, `bool done`, `Map<int, int> taggedPerReel`, `int skipped`, `int? lastActedClipId`.
    - Start: `session` = pending in shooting order; `index` = position of `startClipId`, else 0. An empty session is `done` at once.
  - Actions (each ignored while `busy` or during the hold, and each acting on `session[index]` captured **before** any await):
    - `tapReel(int reelId)`: not in `multi`. Sets `confirmingReelId`, waits the hold (`TtMotion` 400 ms; 120 ms when `MediaQuery.disableAnimations`, passed in as `reducedMotion`), then tags `{reelId}`.
    - `longPressReel(int reelId)`: turns `multi` on with `picked = [reelId]`.
    - `setMulti(bool)`, `togglePick(int reelId)`, `confirmPicks()` (tags `picked`).
    - `sameAsPrevious()`: tags the existing ids of `LastTags`; no-op when none.
    - `skip()`: `skipClips([id])`.
    - `previous()`, `next()`: move without tagging (`TagQueue.previous/next`); clear `picked`; keep `multi`.
    - `createReelAndTag(String name)`: `ReelsRepository.create(name)`, then in `multi` add it to `picked`, else tag `{newId}`; a name problem is thrown to the form (D-85).
    - `undo(List<UndoRecord> records, int clipId)`: `undoAll(records)`, then if `clipId` is pending and in `session`, `index` = its position and `done` = false.
  - After a tag or skip: update `taggedPerReel` / `skipped`, `LastTags.set` (tags only), `index = afterAction`, `done` when null, `picked = []`, `multi` **kept** (sticky), `confirmingReelId = null`. Return the records and the names for the snack (`TagOutcome { List<UndoRecord> records; List<String> reelNames; int clipId; bool skipped }`).
  - A failure: `busy = false`, nothing moves, the error is thrown to the screen (it shows "Something went wrong. Try again.").
  - **Watching pending:** when the clip at `index` leaves pending without this controller acting (a verify, a tag elsewhere), move to `afterAction`. Clips added after start are not in `session`.
  - Scenes for the header: `sceneOf(index) → (int number, int total, Scene scene)` over the session's clips.
  - Logs: ids and counts only.

- [ ] **Step 1:** Failing tests (fake repositories / in-memory Drift, a fake clock, a fake timer): `starts at the tapped clip`, `empty session is done`, `tap tags after the hold and advances`, `double tap on a chip tags once`, `skip during the hold is ignored`, `tag goes to the clip shown when tapped`, `closing during the hold tags nothing` (dispose cancels the hold), `reduced motion holds 120 ms`, `pick several stays on after advance and clears picks`, `long press starts pick several with that reel`, `confirm picks tags into all in one transaction`, `same as previous uses the last tags that still exist`, `same as previous does nothing with none`, `skip advances and counts`, `last clip goes to done`, `wraps to an earlier pending clip`, `undo goes back to the clip`, `undo while the next tag writes restores the right clip`, `undo after done reopens the session`, `current clip leaving To tag moves on`, `new clips are not added to the session`, `create reel and tag`, `create reel in pick several picks it`, `failure keeps the clip and clears busy`, `muted starts on and is kept`.
- [ ] **Step 2:** Implement. `tool/check`.
- [ ] **Step 3:** Add **D-96** (the session's fixed order, the hold and single-flight, sticky Pick several, `LastTags`, Undo goes back, a clip leaving moves on, muted by default, the loop, one clip ahead preloaded by the screen). Update `docs/flow.md` (the tag player flow). Fill Section 6. Commit `feat(tagging): the tag session`, push.

**Mutations:** the hold does not block a second tap; the tag reads `index` after the await; `multi` reset on advance; undo does not move back.

---

### Task 7: The tag player screen and the done screen

**Model:** Sonnet.

**Files:** `lib/features/tagging/views/tag_player_screen.dart`, `tag_done_view.dart`, `tagging_snacks.dart`; `lib/features/reels/views/reel_form_sheet.dart` (from the player); `lib/router/app_router.dart`, `routes.dart`; `lib/l10n/app_en.arb`; widget tests and goldens under `test/features/tagging/views/`.

**Interfaces:**
- Consumes: `TagSessionController`, `TagPlayerMuted`, `clipPlayer(use: tagging)`, `ClipTimeService`, `watchReelSummaries`, Task 2–3 components, `ReelSnacks` (root messenger, D-85), `addedToText`.
- Produces:
  - `Routes.tagPlayer = '/to-tag/play'`, with `Routes.tagFrom(int? clipId)` → `/to-tag/play?from=<id>`; a root-navigator route (`parentNavigatorKey: rootNavigatorKey`), like the viewer (D-89).
  - `showReelForm(context, {Reel? reel, bool forClip = false})`: `forClip` shows "New reel", "This clip will be added to it.", only the name, **Create and add**; returns the created `Reel` through `onSaved` as today. The player calls `createReelAndTag` from it.
- Layout (`routes.player`, Handoff sizes), always dark (`TakeTrayTheme.video()`), its own `Scaffold` for the snacks (D-89): body = `TtSegmentBar`, `TtPlayerHeader` (close, "{i} of {N}" as a polite live region, "Scene {s} of {S} · {range}", mute), the stage (`TtVideoSurface(scrims: true)` with the video at 9:16, 16:9 letterboxed, the blurred thumbnail behind, ‹ › `TtStageArrow`s disabled at the ends, tap to pause/play, horizontal swipe = previous/next outside the system back-gesture edges, a spinner while loading); bottom bar = `TtScrubBar` (large with the "Drag to skim" hint over 2 minutes), the quick row (**Skip**, `TtSameAsPreviousButton`), the `TtTagPanel`.
- Chips: Collecting reels newest first, then the `TtNewReelChip`, then the Other reels toggle and (when open) Ready/Published; no reels → the empty text and a full-width New reel chip. Chip states: `done` for the reel in the hold, `pick` in Pick several. Cover = the reel's cover thumbnail.
- The next clip's player is created one clip ahead (at most two controllers); the previous one is disposed.
- Snacks: "Added to {names}" / "Skipped" with Undo through `ReelSnacks.showUndoAll`, whose Undo calls `TagSessionController.undo(records, clipId)` while the player is open, else only restores. The last Undo snack stays on the done screen. Failures: "Something went wrong. Try again.".
- Done (`TtTagDone`): "All done!", "{n} clips sorted. Nice work.", the per-reel rows and Skipped; **See your reels** goes to the Reels tab, **Back to To tag** pops.
- Back and close pop to To tag; a hold in progress is cancelled.

- [ ] **Step 1:** Failing widget tests (fake bridge, in-memory Drift): `opens on the tapped clip`, `tap a chip tags and shows the snack`, `undo snack goes back to the clip`, `pick several footer counts and is disabled with none`, `same as previous shows the names`, `no reels shows the prompt and full-width new reel`, `25 reels: only Collecting chips open`, `other reels toggle opens them`, `new reel from the player tags the clip`, `missing clip shows can't play and never another video`, `arrows disabled at the ends`, `close during the hold tags nothing`, `done shows per-reel counts and skipped`, `see your reels goes to Reels`, `2x text: chips one column and no overflow`, `header is a live region`; goldens: first clip, mid-scene, Pick several, no reels, loading, long clip, horizontal, done (dark, 1× and 2×).
- [ ] **Step 2:** Implement. `tool/check`.
- [ ] **Step 3:** Add **D-97** (the route, the layout, the snacks and the done screen's kept Undo, one clip preloaded, the form's `forClip`). Update `docs/flow.md`. Fill Section 7. Delete the done later items. Commit `feat(tagging): the tag player and All done`, push.

**Mutations:** the Undo snack does not call the session's undo; Other reels open by default; the preload removed (a test counts controllers: never more than two).

---

### Task 8: To tag v2 and the picker's tag mode

**Model:** Sonnet.

**Files:** `lib/features/tagging/views/to_tag_screen.dart`, `skip_all_dialog.dart`; `view_models/to_tag_controller.dart`, `to_tag_selection.dart`, `to_tag_scenes.dart`; `lib/features/reels/views/reel_picker_sheet.dart`, `view_models/reel_picker.dart`; ARB; tests and goldens.

**Interfaces:**
- Consumes: `groupIntoScenes`, `timeRangeText`, `minutesText`, `skipClips`, `skipAllPending`, `addClipsToReels`, `LastTags`, `Routes.tagFrom`, `ReelSnacks`.
- Produces:
  - `toTagScenesProvider`: the scenes of the pending list with times (phone time until known; never blocks).
  - `ToTagSelection` (ids; `start(id)`, `toggle(id)`, `toggleScene(ids)`, `clear()`; clears ids that leave pending).
  - `ReelPickerMode.tag`; `showReelPicker`'s `excludeReelId` and `pickAndPerform`'s `fromReelId` become `int?` (tag mode passes null and excludes nothing; add and move still require one, asserted). Tag mode's title, subtitle and confirm text are the Global Constraints copy. `pickAndPerform` gains the tag path: `addClipsToReels`, `LastTags.set`, snack "{n} clips added to {names}" with Undo.
  - `ToTagController.retry()` for the error state.
- Screen (`routes.totag`): the summary row with **Skipped ({n})** when any; day headers (`ttDayWeekdayText` with Today / Yesterday as Phase 4's day headers do) only when the scenes span 2+ days; per scene a `TtSceneHeader` with **Tag scene** (or **Select all** / **Unselect** while selecting) and its tiles; a tile tap opens the player on it (`OpenOnce`, D-86); long-press starts selection; selection bar "{n} selected", **Skip**, **Tag**; the **Start tagging** FAB (lifted over a snack, D-82) when clips wait and nothing is selected; the ⋮ menu: Add earlier videos (full access), **Select clips**, **Skipped ({n})**, **Skip all**; the Skip all dialog; the error state (owner copy) with **Try again**; the Skipped button under both empty states. Android back clears a selection first.
- Delete the D-76 "tapping a tile does nothing yet" text.

- [ ] **Step 1:** Failing tests: `scenes and summary row`, `day headers only across days`, `tile tap opens the player on it`, `start tagging opens on the first clip`, `tag scene opens the picker in tag mode and tags`, `picker tag confirm text one reel and several`, `tag snack undo puts them back`, `long press selects and shows the bar`, `select all in a scene`, `selection skip with undo`, `skip all asks then skips with undo`, `cancel skip all changes nothing`, `skipped button shows with a count`, `error state retries`, `back clears selection`, `300 clips build lazily`, `2x text no overflow`; goldens: scenes, selection, error, skip-all dialog, picker tag mode.
- [ ] **Step 2:** Implement. `tool/check`.
- [ ] **Step 3:** Add **D-98** (scenes on To tag, the selection, tag mode, the error state; amends D-76 and D-88). Update `docs/flow.md`. Fill Section 8. Delete the done later items (tag mode, the error state, the empty-reel copy check: "Tag clips from To tag…" now makes sense, keep it). Commit `feat(tagging): To tag scenes, selection, skip all and tag mode`, push.

**Mutations:** day headers always shown; selection kept after a clip leaves; Skip all without the dialog.

---

### Task 9: The Skipped list

**Model:** Sonnet.

**Files:** `lib/features/tagging/views/skipped_screen.dart`, `view_models/skipped_controller.dart`; routes (`Routes.skipped = '/to-tag/skipped'`, inside the To tag tab); ARB; tests and goldens.

**Interfaces:**
- Consumes: `watchInbox(skipped)`, `restoreClips`, `ClipTimeService`, `TtInfoBar`, `ReelSnacks`.
- Produces: `SkippedController` (stream of skipped clips newest first; `restore(ids) → InboxUndo`), the screen per `routes.skipped`: back, **Select**, the info bar, day groups newest day first with "{n} clips", tile tap restores (snack "Restored to To tag" with Undo), selection with **Restore** (snack "{n} clips restored to To tag" with Undo), the empty state. The skipped clips are verified on open like To tag (a missing one leaves, D-72).

- [ ] **Step 1:** Failing tests: `newest day first`, `tap restores with undo`, `select and restore several`, `restored clip shows in To tag`, `empty state`, `missing skipped clip is verified away`, `2x text no overflow`; goldens: list, selection, empty.
- [ ] **Step 2:** Implement. `tool/check`.
- [ ] **Step 3:** Add **D-99**. Update `docs/flow.md`. Fill Section 9. Commit `feat(tagging): the Skipped list`, push.

**Mutations:** tap restore without a snack; oldest day first.

---

### Task 10: On the S24: Patrol flows and the 40-clip check

**Model:** Sonnet.

**Files:** `patrol_test/tagging_test.dart`, `patrol_test/support/test_media.dart` (bulk insert helper if needed); `docs/dev-setup.md` (Phase 5 check).

- [ ] **Step 1:** Patrol, only `Movies/TakeTray Test/` watched (`watchOnlyTestFolder`, restored at the end of the body), full access, Shooting mode on, test reels created by the test and deleted at the end of the body:
  - `tag a day`: insert 40 short test videos; Start tagging; tag 30 with one tap each (alternating 2 reels), 5 with Pick several into both, 3 with Same as previous, skip 2; All done shows the counts; To tag is empty; the reels hold the right clips. Record the wall time and the average time from tap to the next clip's first frame in the report (target under 1 s on the S24).
  - `undo goes back`: tag, Undo, the player is on that clip again and it is pending.
  - `skip all and restore`: Skip all with Undo, then Skip all, open Skipped, restore one.
  - `tag scene`: Tag scene into a reel; the scene leaves To tag.
- [ ] **Step 2:** Run on the S24 (`tool/patrol test -t patrol_test/tagging_test.dart`), all Patrol files green (the limited-access test skipped). Then reinstall debug and `pm clear app.taketray.dev`.
- [ ] **Step 3:** Add the Phase 5 check to `docs/dev-setup.md`, record the timings in D-100 and Section 10. Commit `test(tagging): Patrol flows on the S24`, push.

**Mutations:** none on device; the report quotes one run where a deliberate wrong expectation fails, then reverts it.

---

### Task 11: Phase end (docs only, by the controller)

- [ ] **Step 1:** Minors batch (hybrid rule), then the final whole-branch review (Opus), one fix wave, a separate re-review.
- [ ] **Step 2:** README: Phase 5 ✅ Done, Phase 6 Next, a Phase 5 section with the logo kept. The learning guide's intro and Section 11 (S24 results). `docs/later.md`: delete the Phase 5 section once empty; add anything parked.
- [ ] **Step 3:** CI goldens, CI green, PR to `main`; merge only after the owner says so; then the release APK over `app.taketray` with `install -r`.
