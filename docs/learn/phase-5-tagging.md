# Learning guide: Phase 5, tagging

This guide explains how TakeTray turns a day's clips into sorted reels: the To tag tab with its scenes, the tag player (one tap per clip), Skip, Skip all and the Skipped list, and how every tag and skip can be undone.

Every snippet is real code from this repository. You don't need to know Flutter well to follow it; basic programming knowledge is enough.

## How to read this guide

- **The big picture first.** Phase 3 found your new videos and put them in To tag. Phase 4 built the reels. Phase 5 joins the two:
  - a **scene** is a run of clips shot close together (less than 10 minutes apart, on the same day);
  - **tagging** puts a clip into one or more reels, and takes it out of To tag;
  - **skipping** moves a clip to the Skipped list, where it can be restored;
  - every tag, skip and restore returns an **undo record**, so the message at the bottom can offer **Undo**.
- **Order.** The sections follow the order the phase was built, from Section 2 on. Step 1 was the plan and decision D-91 (what Phase 5 builds now and what waits), so it has no section here.
  - the design-system pieces (2, 3);
  - the data: skip, skip all, restore and undo (4);
  - the rules: scenes and the order of clips (5);
  - the tag player's logic (6) and screen (7);
  - To tag (8) and Skipped (9);
  - the proof on the phone (10).
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-91. "Spec §8.4" is a section of `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`.
- **Commands.** Run them from the repository root, through the wrappers in `tool/` (`tool/flutter`, `tool/check`). Run a single test file from `app/` (`cd app && ../tool/flutter test test/...`).
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Player chrome debts](#2-player-chrome-debts)
3. [The tag panel, done summary and info bar](#3-the-tag-panel-done-summary-and-info-bar)
4. [Skip, skip all and restore with undo](#4-skip-skip-all-and-restore-with-undo)
5. [Scenes, the tag queue and time ranges](#5-scenes-the-tag-queue-and-time-ranges)
6. [The tag session](#6-the-tag-session)
7. [The tag player screen and All done](#7-the-tag-player-screen-and-all-done)
8. [To tag with scenes, and the picker's tag mode](#8-to-tag-with-scenes-and-the-pickers-tag-mode)
9. [The Skipped list](#9-the-skipped-list)
10. [On the S24](#10-on-the-s24)

## 2. Player chrome debts

**What we built:** the clean-up of the pieces the tag player stands on, in `packages/taketray_ui`, before the player itself (Tasks 3 to 7) is built on them. Each was a small defect or gap parked in `docs/later.md`:

- **The scrub bar says what it is.** A screen reader now finds a slider named "Playback position" whose value is "1:12 of 4:32", and can step it forward or back by 5 % of the clip.
- **The scrub bar is 48 dp to touch and 22 dp drawn.** The thumb at the very start or end is now inside the area that takes the finger.
- **The video scrims are the prototype's.** The top is 60 % black fading out; the bottom is 78 % black, solid in its lower part.
- **One dashed-outline painter and one scrim widget** in `components/internal/`, instead of copies.
- **The snack has its shadow.**
- **The To tag tab reads "To tag, 7 clips"** to a screen reader.
- **`video_surface_test` checks accessibility** like every other component.

**Why TakeTray needs it:** the tag player is the app's core loop: a creator taps a reel chip for each clip, again and again. Its scrub bar is under their thumb the whole time, and its video is full screen with white controls over footage that can be bright. A seek bar a blind user cannot understand, a thumb you cannot grab at the end of the clip, and text that fades into a white sky are all bugs the player would inherit. The dashed painter is also needed by Task 3's dashed "New reel" chip, so the copies had to become one first.

**Key ideas:**

- **The caller writes the words, again (D-81).** The package must not compose a sentence a person hears, because the app is meant to be translated. So the slider takes its name and its value as strings. The package keeps only what is the same in every language: the *stepping*.

  ```dart
  Semantics(
    container: true,
    excludeSemantics: true,
    slider: true,
    label: semanticLabel,          // "Playback position"
    value: semanticValue,          // "1:12 of 4:32"
    increasedValue: semanticIncreasedValue,
    decreasedValue: semanticDecreasedValue,
    onIncrease: seek == null ? null : () => step(TtMetrics.scrubSemanticStep),
    onDecrease: seek == null ? null : () => step(-TtMetrics.scrubSemanticStep),
  ```

  `increasedValue` is what the slider *will* say after a step; a screen reader can announce it as it moves. Only the caller knows how to write a time, so with `onSeek` the constructor asserts that both are given. The clip viewer builds them from one ARB string, `"{position} of {duration}"`, and from the position moved by 5 % (`app/lib/features/reels/views/clip_viewer_screen.dart`).

- **A touch area is not a drawing.** Material guidance wants a 48 dp target, but the prototype draws the bar 22 dp tall. The widget has both: the outer box is 48 dp and holds the `GestureDetector`, and a keyed 22 dp row in the middle holds the track, fill and thumb.

  ```dart
  SizedBox(
    height: box.maxHeight,                  // 48: the gesture area
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: TtMetrics.scrubTrackOverhang),
      child: Center(
        child: SizedBox(
          key: const ValueKey('tt-scrub-row'),
          height: TtMetrics.scrubRowHeight, // 22: what is drawn
  ```

  Flutter does not look for a tap outside a widget's own box, so you cannot draw a small bar and give it a bigger invisible target from outside; the bigger box has to *be* the widget that holds the detector.

- **A thumb that overhangs the track needs room on the sides too.** At 0 % and 100 % the thumb's centre is on the end of the track, so half of it (7 dp, or 10 dp for the large thumb) was outside the box that took the touch. The gesture area is now 10 dp wider than the track at each end (`scrubTrackOverhang`), and the position maths subtracts it, so a touch in that margin clamps to the very start or end:

  ```dart
  final width = box.maxWidth - 2 * TtMetrics.scrubTrackOverhang;
  final fraction = ((at.dx - TtMetrics.scrubTrackOverhang) / width).clamp(0.0, 1.0);
  ```

  The margin takes the place of the 10 dp gap between the track and the time, so the drawn bar looks exactly as before. The test `scrub thumb stays inside the gesture area` checks the thumb's rectangle against the gesture area's at 0 %, 50 % and 100 %, for both sizes. (A first version of that test used `Rect.contains`, which treats the right and bottom edges as outside, and failed for a thumb that exactly fitted.)

- **Design values live in one file, and a change is regenerated, never hand-edited.** The scrim colours are in `design/tools/build_tokens.py`; running `python3 design/tools/build_tokens.py` writes the JSON, the CSS and `tokens.g.dart`, and `--check` (part of `tool/check`) fails if any of them is stale. The owner's ruling (D-91) was that the prototype wins over the first tokens: top `rgba(0,0,0,0.6)`, bottom `rgba(0,0,0,0.78)`. The bottom one also has a solid part, which a plain two-colour gradient cannot express, so the shared widget takes `solid`:

  ```dart
  LinearGradient(
    begin: edge,
    end: inner,
    colors: solid == 0
        ? [color, color.withValues(alpha: 0)]
        : [color, color, color.withValues(alpha: 0)],
    stops: solid == 0 ? null : [0, solid, 1],
  )
  ```

  `solid: 0.7` means "70 % of the height from the edge stays at full strength, then it fades". That is the CSS `linear-gradient(transparent, rgba(0,0,0,.78) 30%)` seen from the bottom edge. Why a scrim at all: white text on a white sky is unreadable; 60 % black over white leaves a dark grey (#666666), which gives white text a contrast of 5.7 to 1, above the 4.5 to 1 that WCAG asks for. The note in `build_tokens.py` says this.

  One thing to know: the owner's words in D-91 said "top 0.78, bottom 0.6", but the prototype's CSS has `.vtop` 0.6 and `.vbot` 0.78 (and the old tokens were top 0.55, bottom 0.70, so the numbers were always a bottom-first pair). The code follows the CSS; D-92 records it.

- **Move code without changing what it draws, and prove it.** The dedupe was done first, with no change of look, and the whole suite run: the golden images (screenshots the tests compare with) had to stay identical. Only then did any look change. If a golden had changed during the move, the move would have been wrong. `DashedBorderPainter` takes the constants the two copies differed in as arguments:

  ```dart
  const new({
    required this.color, required this.radius,
    required this.width, required this.dash, required this.gap,
  });
  ```

  The clip tile and the add-reference tile call it with their own constants. The pill tabs' dashed painter draws a stadium (a different path), so it stays as it is. The reel card's scrim, first kept apart for its own colour, now uses `Scrim` too (minors batch). A fade with no solid part is always written top to bottom, because a gradient written the other way round lands a few pixels differently, and the reel card's goldens had to stay the same to prove the swap changed nothing. `scrim_test.dart` and `dashed_border_test.dart` test the two directly (the plain fade, the solid part, the `assert`, and `shouldRepaint` for each value).

- **A shadow is a token, too.** The CSS gives the snack `box-shadow: var(--elev-3)`, which is two layers. Rather than copy two numbers by hand into a component, the token script now writes all six elevation levels as `TtElevationTokens` and the snack uses `boxShadow: TtElevationTokens.level3`. A test reads the two layers back (offsets, blur, spread, opacity).

- **A label that replaces another must contain it.** `TtNavItem.badgeSemanticLabel` is what a screen reader says *instead of* the tab's name while there is a count. The app's text was "7 clips to tag", so a blind user lost the word "To tag". It is now `"To tag, {count, plural, =0{no clips} =1{1 clip} other{{count} clips}}"`. A package test checks that the whole label is passed on untouched; an app test checks the real string starts with the tab's name for 0, 1, 7 and 120.

- **Tests that can fail.** Each new test was run red first and then green, and each of three changes was undone once to see the right test fail: the slider's value removed, the scrims put back to .7 and .55, and the badge label without the tab name. Tests of behaviour that was already right (the 5 % step) were kept as guards and proven the same way.

**Where it lives:** `packages/taketray_ui/lib/src/components/player_chrome.dart` (`TtScrubBar`), `video_surface.dart`, `snack.dart`, `nav_pill.dart`, `clip_tile.dart`, `reference_card.dart`, `internal/dashed_border.dart` and `internal/scrim.dart` (new), `lib/src/theme/tt_metrics.dart` (`scrubRowHeight`, `scrubTrackOverhang`, `videoScrimBottomSolid`), `design/tools/build_tokens.py` and the files it writes (`lib/src/tokens/tokens.g.dart`, `design/tokens/taketray.tokens.json`, `design/prototype/assets/tokens.js`). The app side: `app/lib/features/reels/views/clip_viewer_screen.dart` (`_Scrubber`) and `app/lib/l10n/app_en.arb` (`viewerScrubLabel`, `viewerScrubValue`, `toTagBadgeSemantics`). Tests: `packages/taketray_ui/test/components/player_chrome_test.dart`, `video_surface_test.dart`, `snack_test.dart`, `nav_pill_test.dart`, and `app/test/l10n/app_localizations_test.dart` and `app/test/features/reels/views/clip_viewer_screen_test.dart`.

**Try it yourself:** see the scrim test notice a wrong value. From the repo root:

```bash
(cd packages/taketray_ui && ../../tool/flutter test test/components/video_surface_test.dart --plain-name "scrim uses the prototype stops")
```

It ends with `All tests passed!`. Now open `design/tools/build_tokens.py`, change `'scrimBottom': 'rgba(0,0,0,0.78)'` to `'rgba(0,0,0,0.70)'`, run `python3 design/tools/build_tokens.py`, and run the same command again. It fails with `Expected: a numeric value within <0.00392...> of <0.78>` and an `Actual` near 0.7. Put it back with `git checkout -- design packages/taketray_ui/lib/src/tokens`, and check with `git status` that nothing is left over.

**Decisions:** D-92 (all of this section), amending D-47 (the scrub bar and the first scrim values) and D-48 (the snack), with D-81 (the caller's words) and D-91 (the owner's ruling on the scrim) as background.

## 3. The tag panel, done summary and info bar

**What we built:** the pieces of the tag player's bottom half and its last screen, in `packages/taketray_ui`, before the screens that use them (Tasks 7 to 9):

- **The tag panel is a named group with room for everything the player needs.** Besides the reel chips it now has a slot for a message ("You don't have any reels yet..."), for an **Other reels (4)** row that folds more chips away, and for the folded chips themselves.
- **`TtNewReelChip`:** the dashed "New reel" chip, in a normal cell or across the whole row when there are no reels yet.
- **`TtOtherReelsToggle`:** the "Other reels" row, which says whether it is open.
- **`TtTagDone`:** the "All done!" screen: a green check, a title, a line, a summary list ("Lisbon trip +5") and two buttons.
- **`TtInfoBar`:** the one-line note the Skipped list will show. It was already built, so this task only checked it.
- **`TtSceneHeader`:** a test that its action can be the text **Select all** / **Unselect** button.
- **The reel chip's pictures at 2x text** now show the width the panel really gives (336 dp), not 164 dp.

**Why TakeTray needs it:** tagging is a loop of one tap per clip. A creator with 25 reels must not see 25 chips push the video away, so the reels they are collecting into stay open and the rest fold into one row (the owner's ruling, D-91). A creator with no reels yet needs a clear way to make the first one. A blind user needs the panel read as "Reels", with each chip a separate button, and needs to hear whether "Other reels" is open. And the end of a session should say what was sorted, in words and numbers a screen reader reads in the right order.

**Key ideas:**

- **A group is a name, not a merge.** To read the panel as one thing without gluing all its chips into one sentence, the panel is a *container* whose children stay separate:

  ```dart
  Semantics(
    container: true,
    explicitChildNodes: true,
    label: semanticLabel,   // "Reels", written by the caller (D-81)
    child: SizedBox(...
  ```

  `container: true` makes the panel one node; `explicitChildNodes: true` says "keep my children as nodes of their own". Without the second line a screen reader would hear one long label. The test `panel is one semantics group` walks the node tree and checks the label is only "Reels" and the chips, the title and the footer are all below it, each with its own label.

- **Large text gets a second line where a word must not be cut** (minors batch). `TtSameAsPreviousButton` lets its label take two lines from the 1.5x text scale, so "Same as previous" is never "Same as pre…", and `TtPlayerHeader` takes `wrapSubtitle` (the tag player sets it; the viewer, whose header sits over the video, does not). The done screen's count is bold, as the prototype's `<b>`: `tt.text.numeric(text).merge(TtTextStyles.weight(FontWeight.w700))`.

- **A folded group is shown only when its toggle says so.** The toggle is a widget the panel can read, and the panel decides what to draw:

  ```dart
  final showFolded = toggle?.expanded ?? true;
  ...
  if (showFolded) ..._gridRows(foldedChips, large: large, gap: tt.spacing.xs),
  ```

  So the app cannot pass "expanded: false" to the toggle and still draw the chips, and what a screen reader hears ("collapsed") always matches the screen. With no toggle the folded chips are simply shown.

- **Two columns, except when the chip says otherwise.** Chips go two to a row. The no-reels chip must take the whole row, and the chip before it, if alone, must not leave a hole. `_gridRows` keeps one chip waiting for a partner:

  ```dart
  if (chip is TtNewReelChip && chip.fullWidth) {
    if (waiting != null) rows.add(pair(waiting, null));
    waiting = null;
    rows.add(chip);
  } else if (waiting == null) { waiting = chip; }
  else { rows.add(pair(waiting, chip)); waiting = null; }
  ```

  From text scale 1.5 (D-47) it skips all this and returns one chip per row. A test counts the rows with every slot present at 2x: no two share a top.

- **The height cap, and why it scrolls inside.** The panel's job is to leave the video its space. It never grows past 340 dp (up to 520 dp at 2x text), and the part between the header and the footer scrolls. `ConstrainedBox` takes the smaller of its own limit and the parent's, so a short parent also wins. The test `panel caps its height at 2x and scrolls` puts 30 chips, the new chip, the toggle and 10 folded chips in a 2x panel on a 780 dp screen and checks the height is exactly 520, the title does not move when you scroll, and the last folded chip can still be tapped.

- **A small look, a big target.** The "Other reels" row is drawn 36 dp high, but a finger needs 48 dp. In Flutter a widget cannot be tapped outside its own box, so the *outer* box is the 48 dp one and holds the `InkWell`; the 36 dp row is drawn inside it:

  ```dart
  InkWell(
    onTap: onToggle,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),      // 48
      child: Center(heightFactor: 1, child: ConstrainedBox(
        key: const ValueKey('tt-other-reels-row'),
        constraints: const BoxConstraints(minHeight: TtMetrics.otherReelsToggleHeight), // 36
  ```

  `heightFactor: 1` stops `Center` from growing to fill a tall parent (a first version did, and the test saw 600 dp). My first attempt put the `InkWell` on the 36 dp row; the test that taps 2 dp from the top of the 48 dp box found it did nothing.

- **"Expanded" is a flag of its own.** `Semantics(expanded: expanded, button: true, ...)` makes TalkBack say "collapsed" or "expanded" after the label, so the label is only "Other reels (4)". The test reads `flagsCollection.isExpanded` as a three-state value (true, false, or not applicable).

- **A dashed outline is a painter, not a border.** CSS has `border: 1.5px dashed`; Flutter does not. The chip uses the shared `DashedBorderPainter` (Task 2), drawn over the chip as a `foregroundPainter`:

  ```dart
  CustomPaint(
    foregroundPainter: DashedBorderPainter(
      color: scheme.outline, radius: TtMetrics.reelChipRadius,
      width: TtMetrics.newReelChipBorder, dash: TtMetrics.newReelChipDash, gap: TtMetrics.newReelChipDashGap),
  ```

  The chip keeps the 1 dp inset of a normal chip, so it is exactly as tall (58 dp) and the cover lines up with the chips beside it. The prototype's border is half a dp thicker; the difference is invisible, and keeping two chips of one height in a row is not.

- **One screen that cannot be light.** `TtTagDone` wraps itself in `TtVideoSurface`, which applies the dark video theme, so even in the light app theme the test finds black and white text. Its white "Back to To tag" button is not hand-coloured: the button reads the theme's *primary* colour, so that button gets a copy of the theme where primary is white.

- **Order for the ears.** Each summary row is a `MergeSemantics` of two texts, so a screen reader says "Lisbon trip, plus 5" as one item, name first. The test `done rows read name then count` checks the merged label is `'Lisbon trip\n+5'` (Flutter joins merged texts with a new line). The green badge is decoration, so it is hidden from screen readers; the title is a heading. Under "remove animations" the badge shows at full size at once (`tt.motion.long2` is zero then), and a test starts a fresh widget to prove it, because Flutter keeps the animation state of a widget it reuses.

- **Show a test what the screen really does.** The reel chip used to be photographed at 164 dp in the 2x column, a size that cannot happen: at 2x the panel gives it 336 dp. The golden helper now takes a `largeWidth` per scenario, so each picture shows the real width. The overflow test is run at 336 dp, and the 164 dp case is kept but named as a squeeze test, so nobody mistakes it for a screen.

- **Look before building.** `TtInfoBar` was already in `banners.dart` with its tests, its golden and its Widgetbook entry. The task text listed it as new, but a second copy would only drift from the first. Check what exists first; say so in the record (D-93) when the plan was wrong.

- **Tests that can fail.** The new tests were run before the code and failed to compile, because the names did not exist. Three changes were then undone one at a time to see the right test fail: the height cap removed, the toggle's expanded flag dropped, and the dashed painter taken off the new chip. The `Select all` test passes at once, since the header already took any widget; it was proved the same way, by removing the action from the row.

**Where it lives:** `packages/taketray_ui/lib/src/components/tag_panel.dart` (`TtTagPanel`, `TtOtherReelsToggle`, `TtSameAsPreviousButton`), `reel_chip.dart` (`TtNewReelChip`), `tag_done.dart` (`TtTagDone`, `TtTagDoneRow`), `banners.dart` (`TtInfoBar`), `headers.dart` (`TtSceneHeader`), the measurements in `lib/src/theme/tt_metrics.dart` (`newReelChip*`, `otherReelsToggle*`, `tagDone*`). Tests and pictures: `test/components/tag_panel_test.dart`, `reel_chip_test.dart`, `tag_done_test.dart`, `headers_test.dart` and the `*_golden_test.dart` files; `test/support/tt_golden.dart` (`largeWidth`, `brightnesses`). Catalogue: `widgetbook/lib/components/tag_panel.dart`, `reel_chip.dart`, `tag_done.dart`, `headers.dart`.

**Try it yourself:** remove the cap and watch the test notice. From the repo root:

```bash
(cd packages/taketray_ui && ../../tool/flutter test test/components/tag_panel_test.dart --plain-name "panel caps its height at 2x and scrolls")
```

It ends with `All tests passed!`. Now open `packages/taketray_ui/lib/src/components/tag_panel.dart`, find the line `constraints: BoxConstraints(maxHeight: maxHeight),` and change `maxHeight` to `double.infinity`. Run the same command: it fails with `Expected: <520>` and `Actual: <780.0>` (the whole screen). Put the file back with `git checkout -- packages/taketray_ui/lib/src/components/tag_panel.dart` and check with `git status` that nothing is left over.

**Decisions:** D-93 (all of this section), amending D-47 (the panel's layout), with D-81 (the caller's words), D-91 (folded Other reels, Pick several) and D-92 (the shared dashed painter) as background.

## 4. Skip, skip all and restore with undo

**What we built:** the data side of three actions, in `ClipsRepository`, each giving back what Undo needs:

- **`skipClips(ids)`** moves clips from To tag to Skipped (the player's **Skip**, and **Skip** on a selection in To tag);
- **`skipAllPending()`** moves *every* clip in To tag to Skipped (the menu's **Skip all**);
- **`restoreClips(ids)`** moves clips from Skipped back to To tag (a tap on a tile in Skipped, or **Restore** on a selection);
- each returns an **`InboxUndo`**: the rows it moved, as they were, and the state it gave them;
- **Undo** (`ClipsRepository.undo` / `undoAll`, written in `UndoWriter`) puts those rows back, but only the ones nothing else has touched since.

Tagging needed no new data code: the player tags with `addClipsToReels`, built in Phase 4, whose `AddUndo` already puts a clip back in To tag.

**Why TakeTray needs it:** a creator sorts dozens of clips in a few minutes, and a wrong tap must cost nothing. The spec's two worst bugs are a lost tag and the wrong clip (spec §4). Undo makes both harder: by the time someone taps it, a scan may have added new clips, or the same clip may have been tagged from another screen. Undo must put back exactly what the action did and nothing else.

**Key ideas:**

- **Where a clip lives.** Every clip is in exactly one place: To tag (an `inbox` row with state `pending`), Skipped (an `inbox` row with state `skipped`) or one or more reels (`clip_reels` rows, and no `inbox` row). So skip and restore change one column, `state`, and nothing else. In particular they keep `addedAt`, the time the clip arrived, so a restored clip goes back to its old place in the list:

  ```dart
  .write(InboxCompanion(state: Value(to)));
  ```

  `InboxCompanion` is Drift's "these columns only" object: a column you don't name is not written.

- **An undo record is a snapshot.** The action reads the rows it is about to change, *in the same transaction*, and returns them as plain values (D-84):

  ```dart
  final class InboxUndo extends UndoRecord {
    InboxUndo({required List<InboxEntry> before, required this.after})
      : before = List.unmodifiable(before);
    final List<InboxEntry> before;
    final InboxState after;
    @override
    bool get isEmpty => before.isEmpty;
  }
  ```

  `UndoRecord` is `sealed`: Dart knows every subclass, so the `switch` in `UndoWriter.undoAll` would not compile until it handled the new one. The snack keeps the record until it closes; nothing stores it.

- **Read and write in one transaction.** A *transaction* is a group of statements the database runs as one: other callers see all of it or none of it, and they wait while it runs. Skip all reads every pending row, then skips them, inside one:

  ```dart
  final record = await _db.transaction(() async {
    final rows = await (_db.select(_db.inbox)
          ..where((i) => i.state.equalsValue(InboxState.pending)) ...).get();
    if (rows.isNotEmpty) {
      final moved = await (_db.update(_db.inbox)
            ..where((i) => i.state.equalsValue(InboxState.pending)))
          .write(const InboxCompanion(state: Value(InboxState.skipped)));
      if (moved != rows.length) {
        throw StateError('Skipped $moved clips but read ${rows.length}');
      }
    }
  ```

  Why it matters: the scanner can save a new clip at any moment. If the read ran *before* the transaction, a clip saved between the read and the write would be skipped but missing from the record, and Undo could never bring it back. Inside the transaction, the scan waits until skip all is finished, so its clip stays in To tag. The count check says the same thing in code: the write must move exactly the rows the read saw.

- **Undo only what is still yours.** Between the skip and the Undo, the user may have tagged the clip, or restored it (for a restore's Undo: skipped it). Undo updates a row only while it is still exactly as the action left it: in the state the action set (`after`) and with the same `addedAt`:

  ```dart
  await (_db.update(_db.inbox)..where(
        (i) =>
            i.clipId.equals(entry.clipId) &
            i.state.equalsValue(record.after) &
            i.addedAt.equalsValue(entry.addedAt),
      ))
      .write(InboxCompanion(state: Value(entry.state)));
  ```

  A clip tagged since has no `inbox` row, so the update finds nothing. That is why it is an `UPDATE` and never an insert: an insert would give a clip in a reel a second place. A clip a scan added after skip all is not in the record at all. The task's brief asked only for the state check; the `addedAt` check was added because `untagToInbox` can put a clip back in To tag as `pending` with a new `addedAt`, and undoing an older restore must not pull that clip into Skipped (D-94). Only the state is written: the `WHERE` already matched `addedAt`.

  One case still matches: a row that went back and forth to exactly the state the action left (skipped, restored, skipped again, with the same `addedAt`). An old record would undo it. That is accepted because each action's snack replaces the one before, so only the latest action offers Undo.

- **A second Undo does nothing.** `undoAll` marks each record it has undone in an `Expando` (a side table keyed by the object, which does not keep it alive; D-84). A double tap, or the same snack's Undo after the clip was skipped again by a new action, finds the mark and skips the record. The test `undo is idempotent` covers both.

- **How to test a race.** The test `skip all takes every pending in one transaction` has to make a scan happen *between* skip all's read and its write. A small Drift interceptor runs a hook right after the next `SELECT` from `inbox`. The hook starts a real scan as another caller and waits up to 200 ms for it:

  ```dart
  _hook.armed = () async {
    scan = outside.run(() => clips.saveDetected([shot(5)]));
    await Future.any<Object?>([
      scan!,
      Future<void>.delayed(const Duration(milliseconds: 200)),
    ]);
  };
  ```

  `outside` is the test's own zone. Drift finds the current transaction through the *zone* (Dart's per-call context), so a call made from inside the hook would join skip all's transaction. Run from `outside`, it is a separate caller that has to wait. With the read inside the transaction, the scan can't run until skip all is finished, and its clip stays pending. With the read moved outside (a mutation check), the scan runs at once and is skipped behind the record's back, and the test fails.

- **Tests that can fail.** Each new test was run against stubs first (the old state change, an empty record, an Undo that did nothing) and failed on its own assertion. Four kinds of change were then made one at a time, and each was caught: an Undo with no "still as left" check, an Undo that upserts, skip all reading outside its transaction (caught by the count check, and with that check removed too, by the test's own assertion), and a skip that overwrites `addedAt`. The test that pins Phase 4's add Undo passed from the start, so it was proved by breaking that code's `addedAt`.

**Where it lives:** `app/lib/domain/models/undo_record.dart` (`InboxUndo`, `InboxEntry`), `app/lib/data/repositories/clips_repository.dart` (`skipClips`, `skipAllPending`, `restoreClips`, `_moveInbox`), `app/lib/data/repositories/undo_writer.dart` (`_undoInbox`). Tests: `app/test/data/repositories/clips_repository_inbox_test.dart` and `undo_writer_inbox_test.dart`. Flow: "Tagging data changes" and "Undo" in `docs/flow.md`.

**Try it yourself:** watch the race test catch a read outside the transaction. From the repo root:

```bash
(cd app && ../tool/flutter test test/data/repositories/clips_repository_inbox_test.dart --plain-name "skip all takes every pending in one transaction")
```

It ends with `All tests passed!`. Now open `app/lib/data/repositories/clips_repository.dart`, find `skipAllPending`, and move the `final rows = await (_db.select(_db.inbox) ... .get();` statement up, above `final record = await _db.transaction(() async {`. Run the same command again. It fails with `Bad state: Skipped 3 clips but read 2`: the scan's clip was skipped, but the record held only two. Put the file back with `git checkout -- app/lib/data/repositories/clips_repository.dart`, and check with `git status` that nothing is left over.

**Decisions:** D-94 (all of this section), extending D-84 (undo records, the `Expando`, `undoAll`, `Clock.storedNow()`), with D-57 (one place per clip) and D-10 (logs hold ids and counts only) as background.

## 5. Scenes, the tag queue and time ranges

**What we built:** three small pieces of logic, with no screen yet, that To tag (Task 8) and the tag player (Tasks 6 and 7) build on:

- **`groupIntoScenes`** cuts a list of clips into *scenes*: runs of clips shot close together, each with a start time, an end time and a day.
- **`TagQueue`** is the player's "which clip next?" The clips in a tagging session are fixed when it starts, but some leave To tag as you go. The queue finds the next and previous clip that is still waiting.
- **`timeRangeText`** writes a scene's times for its header: "1:05–1:20 PM". **`minutesText`** writes a length for the summary: "45 s", "12 min", "1 h 5 min".

**Why TakeTray needs it:** a creator who filmed a market for twenty minutes does not want forty separate clips; they want "the market" as one thing to tag with one tap. A pause in filming is the natural edge of a scene. And tagging is a loop: after each clip the player must go to the next one that still needs a tag, even if one of the clips changed meanwhile (tagged somewhere else, or taken out by the verifier).

**Key ideas:**

- **The gap runs from the end of one clip to the start of the next.** Two clips are in one scene unless there are 10 minutes or more between them:

  ```dart
  final previousEnd = previous.fingerprint.dateTakenUtc.add(
    Duration(milliseconds: previous.fingerprint.durationMs),
  );
  final apart = next.fingerprint.dateTakenUtc.difference(previousEnd);
  return apart >= gap || !sameDay;
  ```

  Why the end? A 5-minute clip that starts at 10:00 and a clip started at 10:12 are 12 minutes apart start to start but only 7 minutes apart in real time, so they belong together. If two clips overlap, the gap is *negative*, and a negative number is less than 10 minutes, so they stay in one scene with no special case. The gap is measured on UTC instants (real moments), so a clip in another zone is placed by when it really happened.

- **A new day is always a new scene,** and "day" means the day where the clip was shot. `ClipLocalTime.wallClock` (Phase 4) is a UTC-flagged `DateTime` whose fields are the clock on the wall. A scene compares those fields, `year`, `month` and `day`, and never calls `toLocal()` on them. So 23:55 and 00:02 are seven minutes apart but two scenes, and a clip shot at 19:02 in New York (00:02 UTC) joins a 23:55 UTC clip from London, because it was still "the 28th" there. If the phone does not know a clip's zone yet, the phone's local time is used, written in the same shape, so every `Scene.start` is a wall-clock value.

- **A scene's range is first start to last start.** `end` is when the last clip *started*, not when it finished; the header matches the times on the tiles. Clips are first put in shooting order (`inShootingOrder`: oldest first, then the lower id), so clips with the same second keep a steady order.

- **The queue stores a fixed list, and asks what is still pending.** The session is the clip ids, in order, at the moment "Start tagging" was tapped. The queue never changes. What changes is a set of ids still in To tag:

  ```dart
  int? next(int from, Set<int> pending) {
    for (var i = from < -1 ? 0 : from + 1; i < session.length; i++) {
      if (pending.contains(session[i])) return i;
    }
    return null;
  }
  ```

  A clip tagged elsewhere is simply not in `pending`, so it is passed over. New clips from a scan are not in the session, so they never appear in the middle of a run. `afterAction` is the prototype's `advance`: `next(from, pending) ?? next(-1, pending)`, the next waiting clip, else the first waiting clip from the start (one the user skipped past with "Previous"), else `null`, which is the "All done!" screen.

- **A range shares the AM/PM only when it is true and the locale allows it.** "1:05–1:20 PM" is one period for two times. The first time is the locale's own 12-hour pattern with the period cut off (`h:mm a` becomes `h:mm`), so the separators stay the locale's. "11:50 AM–12:10 PM" crosses noon, so both are written in full. On a 24-hour phone it is "13:05–13:20". If the locale writes the period first (Korean: "오후 1:05"), cutting it would be wrong, so both times are written in full. Under a minute apart, the range is just one time.

- **No new strings for lengths.** The Reels banner already wrote "45 s / 3 min / 1 h 5 min" (`waitingDurationText`, Phase 3). `minutesText` is that function under the name this screen uses; two copies could drift apart.

**Where it lives:** `app/lib/domain/rules/scenes.dart`, `tag_queue.dart` and `shooting_order.dart` (`inShootingOrder` moved here from `pending_clips.dart`, which still exports it); `app/lib/features/tagging/views/time_range_text.dart`. Tests: `app/test/domain/rules/scenes_test.dart` and `tag_queue_test.dart`, `app/test/features/tagging/views/time_range_text_test.dart`. `scenes_test.dart` also runs in London time inside `tool/check`.

**Try it yourself:** make the gap run from start to start and watch the right tests fail. From the repo root:

```bash
(cd app && ../tool/flutter test test/domain/rules/scenes_test.dart)
```

It ends with `All tests passed!`. Now open `app/lib/domain/rules/scenes.dart`, find `_startsNewScene`, and replace `previousEnd` in the `difference` call with `previous.fingerprint.dateTakenUtc`. Run the command again. `gap is measured from the previous clip's end` fails with `Expected: [[1, 2]]  Actual: [[1], [2]]`, because a 5-minute clip and the one 12 minutes after its start were wrongly cut apart. Put the file back with `git checkout -- app/lib/domain/rules/scenes.dart` (once committed) and check with `git status` that nothing is left over.

**Decisions:** D-95 (all of this section), extending D-83 (times where shot) and D-76 (time helpers, `waitingDurationText`).

## 6. The tag session

**What we built:** the brain of the tag player, with no screen yet (that is Section 7). `TagSessionController` is a Riverpod view model that knows:

- **which clips this session tags**, in which order, and which one is showing;
- **what each button does:** tap a reel chip, press and hold one, Pick several, Same as previous, Skip, Previous, Next, + New reel, and Undo;
- **when it is done**, and what the "All done!" screen counts.

Two small providers come with it: **`LastTags`** (the reels of the last tag, for "Same as previous") and **`TagPlayerMuted`** (the player's sound, off at first). And `clipPlayer`, Phase 4's video provider, learned a second use: `ClipPlayerUse.tagging` loops the clip and follows the tag player's own mute switch.

**Why TakeTray needs it:** tagging is the app's core loop. A creator taps through forty clips in two minutes, often with a thumb, often twice by accident. The spec's worst bugs are a lost tag and a tag on the wrong clip (spec §4). So the rules here are strict: one tag per tap, always onto the clip that was showing, nothing lost, and an Undo that takes you back to the clip you got wrong.

**Key ideas:**

- **The session is a fixed list.** When the player opens, the controller asks the database once for the clips in To tag, sorts them in shooting order, and keeps their ids as `session`. It never changes after that. What changes is `pending`, the ids still waiting, which the controller keeps up to date from the same database stream. Section 5's `TagQueue` walks `session` and skips anything not in `pending`, so a clip tagged from another screen is simply passed over, and a clip that a scan adds meanwhile never appears in the middle of a run.

- **Read the clip first, then wait.** Every action starts by reading which clip is showing, *before* it awaits anything:

  ```dart
  final s = _idle();
  if (s == null || s.multi) return Future.value();
  final clipId = s.session[s.index];
  final from = s.index;
  ```

  `await` lets other code run in the gap: a stream answer, a timer, a second tap. If the tag read `state.index` after the wait instead, and the player had moved on meanwhile, the tag would land on the *next* clip. That is exactly the "wrong clip" bug, and a test (`tag goes to the clip shown when tapped`) fails if anyone writes it that way.

- **One action at a time.** `_idle()` returns the state only when nothing else is running and no chip is held; otherwise the action is ignored and returns `null` at once:

  ```dart
  if (_running != null || s.busy || s.confirmingReelId != null) return null;
  ```

  `_running` is set when an action begins and cleared when it ends, success or failure (a `finally`). So a double tap on a chip tags once, and Skip during a tag does nothing.

- **The 400 ms hold.** Tapping a chip doesn't tag at once. The chip shows a check (`confirmingReelId`) for 400 ms, the `medium4` motion token (120 ms when the phone asks for less motion), so the user sees what they tapped before the clip changes. The hold is a `Timer`, and the controller cancels it when it is disposed:

  ```dart
  ref.onDispose(() {
    unawaited(watch.cancel());
    _cancelHold();
  });
  ```

  Closing the player during the hold therefore tags nothing. The timer comes from a provider (`holdTimerProvider`, normally `Timer.new`), so a test can hold the time still and end the hold when it chooses, while the real in-memory database keeps running.

- **After a tag: next clip, picks cleared, Pick several kept.** `TagQueue.afterAction(from, pending)` gives the next waiting clip, or the first one from the start, or `null` (done). The owner ruled that Pick several is *sticky*: it stays on until Cancel, which helps a run of clips that all go into the same two reels. The picks themselves are cleared at each new clip.

- **Undo waits its turn, then goes back.** Undo is the one action that is never ignored: if the next tag is still writing, Undo waits for it, then puts its own records back in one transaction and moves the player back to that clip:

  ```dart
  while (_running != null) {
    await _running!.future;
  }
  ```

  Ignoring it would be worse: the snack disappears when tapped, so the user would believe the wrong tag was gone. Undo after "All done!" reopens the session on that clip.

- **A clip can leave under you.** If the clip showing leaves To tag without the player doing it (the verifier found its video gone, or it was tagged from the reel picker), the stream tells the controller and it moves on, as after a tag. During a hold the tap is cancelled instead (minors batch ruling): the clip you tapped is gone from To tag, so the tap is treated as if it never happened, nothing is tagged, and a queued Undo may run. Another clip of the session leaving during the hold does not touch it.

- **New reel tags the clip the sheet was opened for.** `createReelAndTag(name, clipId:)` gets the clip that was showing when the sheet opened. If that clip has left To tag by the time you tap **Create and add**, the reel is still made (you asked for it) and nothing is tagged, not even the clip showing now. It returns the reel, so the form never has to look it up by its name.

- **Undo counts back only what is no longer true.** After the Undo the controller asks where the clip is: a skip comes off the done screen's count only if the clip is back in To tag, and a reel's "+1" only if the clip has left that reel. Undo never takes a clip's last place, so sometimes it changes nothing, and then the counts stay.

- **Muted by default, looping.** The design prompt asks for muted autoplay. `TagPlayerMuted` starts `true` and keeps the choice until the app restarts. The tag player's `clipPlayer` also loops the clip, so a 3-second clip keeps playing while you decide.

- **Tests that can fail.** Each of the brief's 25 tests was run against stubs first and failed on its own assertion (the stub for "same as previous does nothing with none" did nothing, so its red run used a naive version that tags with whatever `LastTags` holds). Then four mistakes were made one at a time, and each was caught: the hold not blocking a second tap (three holds instead of one), the tag reading `index` after the wait (the tag went to clip 2), Pick several turned off after a tag, and an Undo that does not move back.

**Where it lives:** `app/lib/features/tagging/view_models/tag_session_controller.dart` (`TagSessionController`, `TagSessionState`, `TagOutcome`, `tagHold`, `holdTimerProvider`), `last_tags.dart`, `tag_player_muted.dart`; `app/lib/features/reels/view_models/clip_player.dart` (`ClipPlayerUse`). Tests: `app/test/features/tagging/view_models/tag_session_controller_test.dart` and the "tagging" group of `app/test/features/reels/view_models/clip_player_test.dart`. Flow: "The tag player's session" in `docs/flow.md`.

**Try it yourself:** let a hold outlive its clip, and watch the test catch it. From the repo root:

```bash
(cd app && ../tool/flutter test test/features/tagging/view_models/tag_session_controller_test.dart --plain-name "a clip leaving during the hold cancels the tap")
```

It ends with `All tests passed!`. Now open `app/lib/features/tagging/view_models/tag_session_controller.dart`, find `_onPending`, and delete the two lines `_cancelHold();` and `_update((now) => now.copyWith(confirmingReelId: null));`. Run the command again. It fails with `Expected: true  Actual: <false>`: the clip was tagged elsewhere during the hold, and the hold was not cancelled, so the tap would still have tagged it. Put the file back with `git checkout -- app/lib/features/tagging/view_models/tag_session_controller.dart`, and check with `git status` that nothing is left over.

**Decisions:** D-96 (all of this section), with D-91 (sticky Pick several, Undo goes back, a clip leaving moves on), D-94 (`InboxUndo`, tagging through `addClipsToReels`), D-95 (`TagQueue`, scenes), D-89 (`clipPlayer`) and D-85 (a failure is "Something went wrong. Try again.") as background.

## 7. The tag player screen and All done

**What we built:** the screen you will use most, on top of Section 6's brain:

- the **tag player**: a progress bar of segments, a header ("3 of 12", "Scene 1 of 2 · 9:01–9:20 AM"), the clip itself with ‹ › arrows, a scrub bar, **Skip** and **Same as previous**, and the panel of reel chips, with **New reel**, **Other reels** and **Pick several**;
- the **snacks** ("Added to London Food", "Skipped") with an Undo that takes you back to the clip;
- the **"All done!"** screen: how many clips you sorted, what went into each reel, and two buttons;
- a **New reel** form made for the player, which makes the reel *and* tags the clip.

It is a route at `/to-tag/play`, drawn above the tab bar like the clip viewer. Task 8 adds the buttons that open it.

**Why TakeTray needs it:** tagging is one tap per clip, and everything on this screen is there to make that tap safe and quick. The worst things it can do are to play the wrong video, tag the wrong clip, or lose a tag. So the video address comes from one function, the tag goes to the clip that was showing when you tapped, and Undo puts back exactly what that tap did.

**Key ideas:**

- **The video comes from one place.** The stage never builds an address itself. It asks `clipVideoUri(clip)` for the clip the session is showing, and that function returns nothing for a clip that is flagged missing or has no usable identity:

  ```dart
  final uri = clip == null ? null : clipVideoUri(clip);
  ...
  if (clip == null || address == null) {
    video = const _CantPlay();
  }
  ```

  No address means "This video can't be played", never another video. The stage is also keyed by the clip *and* its address (`ValueKey((clip?.id, uri))`), so a new clip is a new stage with its own player, and nothing from the last clip carries over.

- **One clip ahead, paused.** Opening a video takes a moment, so while you look at clip 4 the player opens clip 5 in the background. But `clipPlayer` normally *plays* as soon as it opens, and a clip you cannot see must not make a sound. So it got a flag, `autoplay`, and the tag player always asks with `autoplay: false`, for the clip showing and the clip ahead alike. That matters: both are the same entry in Riverpod's family, so when clip 5 comes up, it is the controller that was already opened, not a second one. The stage plays it once, when it appears:

  ```dart
  if (!away && widget.controller.value.isInitialized) {
    unawaited(widget.controller.play());
  }
  ```

  Which clip is "ahead"? The one the player will go to after a tag or a skip, which is `TagQueue.afterAction(index, pending − current)`, not just `index + 1`: after the last clip it wraps to the first one still waiting. It is opened a moment (200 ms) *after* the frame, once the clip that was left has let go of its player; opened inside the build, it would be a third controller for a moment. When settled there are at most two alive (the one showing and the one ahead).

- **A clip you leave must stop.** After Previous (or Undo) the clip you just left becomes the "clip ahead", and its controller can still be alive, still looping. So when a stage goes away it pauses its clip and rewinds it:

  ```dart
  await controller.pause();
  await controller.seekTo(Duration.zero);
  ```

  wrapped so that a controller that was let go in the meantime is no problem. The clip ahead is therefore never heard and never moves; it waits at the start.

- **The check mark belongs to the clip you tapped.** When you tap a chip it shows a check for 400 ms. If that clip is tagged from somewhere else during those 400 ms, Section 6's controller cancels the hold and clears `confirmingReelId` before it moves on, so the *new* clip's chip never shows a check it did not earn. (Task 7 first kept a `_heldClipId` in the screen for this; the minors batch moved the rule into the controller, where it also stops the tag.)

  ```dart
  final held = state.confirmingReelId == id;
  ```

- **A swipe is far and fast** (minors batch). A quick jitter of the thumb can be fast enough to count as a fling, so `_SwipeArea` also wants the finger to travel `kTouchSlop * 4` (72 dp) from where it touched down. It is a layer over the video, and only that layer stays out of the system's back-gesture edges: the video itself is not moved. Taps go through it to the video.

- **Room for the video at 2x.** At 1.5x text and up the header says only the time range (it may wrap), Same as previous may take two lines, and the reel panel stops at 40 % of the screen instead of 45 %, so on a 360 × 800 phone the video keeps at least 200 dp. If the session cannot load, the player says so and offers **Try again**.

- **Snacks that say what happened, with an Undo that goes back.** `showTagOutcome` builds the words from the `TagOutcome` of that action ("Added to London Food and Goa" or "Skipped"), never from what is on screen now. Its Undo calls `TagSessionController.undo(records, clipId)`, which puts the clip back in To tag and shows it again. The screen reads the controller's notifier *before* it awaits the tag, so the snack still holds it after you close the player; Section 6's `undo` knows it may run after the player has gone. A new snack replaces the old one (`showTtSnackOn` hides the one showing first), so only the latest action can be undone. That rule comes from Section 4: an old skip's Undo could otherwise pull back a clip that has since been skipped, restored and skipped again.

- **Look things up before `await`.** `_act` is the one function Skip, Same as previous and Pick several go through. It reads the snack's messenger, the words and the session notifier first, then awaits the action, so it works even if the player closed in between:

  ```dart
  final snacks = ReelSnacks.of(context);
  final session = ref.read(_provider.notifier);
  try {
    final outcome = await action();
  ```

- **Everything the screen watches is read at the top of `build`.** Riverpod's `ref.watch` and `ref.listen` only work while the widget itself is building. The screen wraps its body in a `Theme(TakeTrayTheme.video())` and a `Builder`, and the `Builder`'s callback runs later, so the watches happen before the `Theme`, and the `Builder` only receives the values.

- **A form that tags.** "New reel" from the player opens the Phase 4 form with `forClip: true`: a different subtitle ("This clip will be added to it."), only the name field, and **Create and add**. The form still checks the name (empty, too long, already taken) and tells you under the field. When the name is fine it does not call `ReelsRepository.create` but a function the player hands it, `createReelAndTag`, which makes the reel and tags the clip in one go, then the form closes. If the form had created the reel itself and the player had tagged afterwards, a failure in between would leave a reel with no clip and a second try would be told that the name is taken.

- **The panel may not eat the video.** At 2x text the tag panel is allowed 520 dp, which would leave nothing for the video on a phone. The screen puts the panel alone (the scrub bar and the quick row stay at full size) in a box of at most 45 % of the screen's height; the panel scrolls inside its box, and its header and footer stay put.

- **Screenshots only on your Mac.** The eight screens (first clip, mid-scene, Pick several, no reels, loading, a long clip, a horizontal clip, All done!) are compared as images in `app/test/features/tagging/views/goldens/macos/`, at 1x and 2x text. They are skipped on GitHub's CI, which has no images for the app's screens (Section 2's image sets are for components). A fake video platform draws a coloured gradient where the video would be, and real thumbnails are served, so the images show where things are.

- **Tests that can fail.** The screen's 58 widget tests were run first against a screen that was an empty black box: 56 failed (the two that passed do so by nature: "nothing is offered" and the accessibility check of a blank page). Then three mistakes were made on purpose, one at a time, and each was caught: an Undo that does not go through the session (the player stayed on clip 2 after "Undo"), Other reels open by default (25 chips instead of 5), and the preload taken out (one player instead of two). A later fix was proved the same way: without the pause-and-rewind, Next then Previous left the clip ahead playing.

**Where it lives:** `app/lib/features/tagging/views/tag_player_screen.dart` (`TagPlayerScreen`), `tag_done_view.dart`, `tagging_snacks.dart`; `app/lib/features/clips/widgets/clip_scrubber.dart`; `app/lib/features/reels/views/reel_form_sheet.dart` (`forClip`) and `reel_form_controller.dart` (`createWith`); `app/lib/features/reels/views/undo_snacks.dart` (`undo:`); `clip_player.dart` (`autoplay`); `app/lib/router/` (`Routes.tagPlayer`, `Routes.tagFrom`). Tests: `app/test/features/tagging/views/tag_player_screen_test.dart`, `tag_player_golden_test.dart`, and the "from the tag player" group of `app/test/features/reels/views/reel_forms_test.dart`. Flow: "The tag player screen and All done" in `docs/flow.md`.

**Try it yourself:** take the preload out and watch a test notice. From the repo root:

```bash
(cd app && ../tool/flutter test test/features/tagging/views/tag_player_screen_test.dart --plain-name "the clip one ahead is open, muted and never playing")
```

It ends with `All tests passed!`. Now open `app/lib/features/tagging/views/tag_player_screen.dart`, find `build`, and delete the line `_preload(state);` (the one under the comment "After the clip showing"). Run the command again. It fails with `Expected: an object with length of <2>  Actual: [Instance of 'FakePlayer']`: without the preload only the clip showing has a player. Put the file back with `git checkout -- app/lib/features/tagging/views/tag_player_screen.dart` (if you have not committed your own changes to it) and check with `git status`.

**Decisions:** D-97 (all of this section), with D-96 (the session), D-93 (the panel and the done screen), D-92 (the scrub bar), D-89 (the viewer, `clipVideoUri`, the can't-play state), D-85 (snacks on the root messenger, the form's failure line) and D-86 (`OpenOnce`) as background.

## 8. To tag with scenes, and the picker's tag mode

**What we built:** the To tag tab, grown up. It used to be a plain grid of clips that did nothing when you tapped them. Now:

- the clips are grouped into **scenes** (Section 5), each under a header with its time range ("9:41–9:50 AM"), its clip count and length, and a **Tag scene** button; when the clips come from more than one day there is a **day header** too ("Today · Wed, Oct 28");
- a **summary row** on top: "8 clips · 3 scenes · 3 min", with **Skipped (n)** beside it when anything is skipped;
- a **tile tap** opens the tag player (Section 7) on that clip, and a **Start tagging** button opens it on the first one;
- **choosing**: a long press on a tile (or **Select clips** in the ⋮ menu) turns the top bar into "2 selected" with **Skip** and **Tag**; each scene header becomes **Select all** / **Unselect**;
- **Skip all** (with a question first) and **Skip** both put clips in Skipped, with an Undo;
- the **reel picker's tag mode**: "Tag 3 clips", "Pick one or more reels.", and a snack "3 clips added to London Food" with Undo;
- an **error state** ("Couldn't load your clips", **Try again**) and a small stand-in **Skipped** screen (Section 9 fills it).

**Why TakeTray needs it:** most days, a shoot is a handful of scenes, and most scenes belong to one reel. Tagging a scene is one tap and one pick, which is far faster than one tap per clip; the player is for the clips that need a closer look. The selection is for the odd clips that do not follow the scene. And because nothing here deletes a video (a skip only moves a row, a tag only adds a link), every action can offer **Undo**.

**Key ideas:**

- **The scenes never wait for the times.** Each clip is placed by the time where it was shot (Section 5), but that answer comes from the phone and can be slow. `toTagScenesProvider` takes whatever times it has and falls back to the phone's own time for the rest, so the list shows at once and regroups in place when the answer arrives:

  ```dart
  final clips = ref.watch(toTagControllerProvider).value;
  if (clips == null) return null;
  final times = ref.watch(toTagTimesProvider).value ?? const {};
  return groupIntoScenes(clips, times);
  ```

  `null` means "not read yet", which the screen shows as skeleton tiles.

- **One flat list, so it stays lazy.** 300 clips over 60 scenes must not build 300 tiles. A grid for each scene would make 180 slivers whose headers are all built at once. So the screen turns the scenes into one flat list of rows and gives it to a single `SliverList.builder`, which builds only the rows on screen:

  ```dart
  for (final scene in scenes) {
    if (days.length > 1 && scene.day != lastDay) rows.add(_DayRow(scene));
    lastDay = scene.day;
    rows.add(_SceneRow(scene));
    for (var from = 0; from < scene.clips.length; from += _columns) {
      rows.add(_TilesRow(scene, from));
    }
  }
  ```

  The condition `days.length > 1` is the whole rule for "day headers only when the clips span days". One day, however many scenes, shows none.

- **The selection follows the list.** `ToTagSelection` is the reel page's selection (Phase 4) on the waiting clips. The important part is that it *listens* to the list and drops what has left it:

  ```dart
  ref.listen(toTagControllerProvider, (_, next) {
    final clips = next.value;
    if (clips != null) _prune(_liveIds(clips));
  });
  ```

  Without that, a clip that you tagged in the player would stay "chosen" in an invisible way, and **Skip** or **Tag** would act on a clip that is no longer there. Also: a missing clip can never be chosen, and un-choosing the last clip ends choosing (but a scene's **Unselect** may leave 0 chosen, because it is not the last tap of a choice).

- **Ask first, then skip.** Skip all moves every waiting clip, so it asks. The dialog is a separate function that returns `true` only for the **Skip all** button; **Cancel**, a tap outside and the back button all give `false` or `null`:

  ```dart
  final confirmed = await showSkipAllDialog(context, count: count);
  if (confirmed != true) return;
  final record = await clips.skipClips(ids);
  ```

  `ids` are the clips waiting when the dialog opened (minors batch): a clip a scan adds while you read the question stays in To tag, so "Skip all 5 clips?" and "5 clips skipped" agree. The snack counts what really moved (`record.before.length`), not what you saw on screen, and **Undo** uses the record from Section 4, which only puts back rows that are still exactly as the skip left them.

- **Tag mode is the picker with nothing excluded.** The reel picker (Phase 4) was made for clips that are already in a reel, so it hid that reel. Clips in To tag are in no reel, so tag mode passes `null` for the reel to hide, and add and move assert that they got one. Confirming calls the same `addToReels` as the player, so several reels are one transaction, and then remembers the reels for **Same as previous**:

  ```dart
  if (lastTags != null) {
    tagBefore = lastTags.current;
    tagSet = lastTags.set(reelIds);
  }
  ```

  The snack's Undo does what the player's does: takes the tag back, and puts the remembered reels back unless a later tag has replaced them.

- **The tagged tiles leave one by one.** The prototype's "Scene tagging" motion makes the scene's tiles fade, 30 ms after one another. There is a catch: the database drops the clips the instant you confirm, which is *before* the sheet has closed, so the tiles would be gone before anyone could see them go. So the screen keeps the list as it was (`_held`) from the moment a tag begins, and plays the tagged tiles out when the sheet has closed. Each tile gets its own slice of one animation:

  ```dart
  spans[leaving[i]] = (
    begin: begin.inMicroseconds / total.inMicroseconds,
    end: (begin + each).inMicroseconds / total.inMicroseconds,
  );
  ```

  The 30 ms step is the design token `TtMotion.stagger` (zero under reduced motion). A row whose tiles are all leaving also folds up. With "remove animations" they only fade, together, over 150 ms, and no row folds, so nothing on screen moves. Taps are ignored while this plays.

- **Small things the minors batch added.** Above the app bar's text cap, **Skip** and **Tag** become icon buttons that keep their names for a screen reader, so "2 selected" stays whole; **Select all** / **Unselect** are announced with the scene ("Select all, 9:41–9:50 AM, 3 clips"); choosing with nothing chosen ends when the list empties; the tag snack counts the clips that really got a new place; the loading state has the prototype's summary and scene-header lines; and To tag and Skipped share one tile row widget, `ClipTileRow`.

- **Tests that can fail.** The new screen tests were first run against the old screen: 30 of the 101 in `to_tag_screen_test.dart` failed (the others check what did not change, such as the access banner), and all 27 of the first version of `to_tag_actions_test.dart` failed. Then three mistakes were made on purpose, one at a time: day headers always shown (the "one day has none" test caught it), the selection not following the list (the "selection drops a clip that leaves To tag" test caught it) and Skip all without the dialog (seven tests caught it, because the dialog and "nothing moved" are both asserted). A fourth, for the motion: with no stagger, the tiles all faded together and the "one tile after another" test caught it.

**Where it lives:** `app/lib/features/tagging/views/to_tag_screen.dart` (`ToTagScreen`), `skip_all_dialog.dart`, `day_header_text.dart`, `skipped_screen.dart` (the stand-in); `app/lib/features/tagging/view_models/to_tag_scenes.dart`, `to_tag_selection.dart`, `to_tag_controller.dart` (`retry`), `pending_clips.dart` (`skippedCountProvider`); `app/lib/features/reels/views/reel_picker_sheet.dart` (`ReelPickerMode.tag`, `pickAndPerform`, `joinedNamesText`) and `view_models/reel_picker.dart`; `app/lib/router/` (`Routes.skipped`). Tests: `app/test/features/tagging/views/to_tag_screen_test.dart` (the display, with fake view models), `to_tag_actions_test.dart` (tagging, skipping and the motion, over a real in-memory database), `to_tag_golden_test.dart` (macOS images in `goldens/macos/`), and `app/test/router/app_router_test.dart`. Flow: "To tag, the Shooting mode card and Add earlier videos" and "Managing clips in a reel" in `docs/flow.md`.

**Try it yourself:** break the day-header rule and watch a test notice. From the repo root:

```bash
(cd app && ../tool/flutter test test/features/tagging/views/to_tag_screen_test.dart --plain-name "one day has none")
```

It ends with `All tests passed!`. Now open `app/lib/features/tagging/views/to_tag_screen.dart`, find `_rows`, and change `if (days.length > 1 && scene.day != lastDay) rows.add(_DayRow(scene));` to `if (scene.day != lastDay) rows.add(_DayRow(scene));`. Run the command again. It fails with `Expected: no matching candidates` and `Found 1 widget with type "TtDayHeader"`: with one day, a header still shows. Put the file back with `git checkout -- app/lib/features/tagging/views/to_tag_screen.dart` (if you have not committed your own changes to it) and check with `git status`.

**Decisions:** D-98 (all of this section), with D-95 (the scenes), D-94 (skip and its Undo), D-96 (`LastTags`), D-97 (the player the tiles open), D-88 (the picker and the selection it copies), D-87 (day headers), D-86 (`OpenOnce`), D-85 (snacks on the root messenger, the failure in the sheet), D-82 (the button that lifts over a snack) and D-76 (the first To tag) as background.

## 9. The Skipped list

**What we built:** the screen behind **Skipped ({n})** on To tag. Until now it was a bar with a back button and nothing under it. Now it shows every skipped clip, grouped by the day it was shot, newest day first ("Today · Fri, Oct 30", "Yesterday · …", "Wed, Oct 28"), each day with "{n} clips". Under the bar is a one-line note: "Skipped clips are still in your gallery. Restore any you want to tag."

- **Tap a clip** and it goes back to To tag; a message says "Restored to To tag" and offers **Undo**.
- **Select** (or a long press) lets you pick several; the bar shows "{n} selected" and **Restore**, and the message says "3 clips restored to To tag" with **Undo**.
- With nothing skipped there is an empty state: "No skipped clips".
- When you open the screen, TakeTray checks that the skipped clips still exist on the phone, as To tag does. A skipped clip whose video was deleted leaves the list.

**Why TakeTray needs it:** **Skip** and **Skip all** (Sections 4 and 8) only feel safe if getting a clip back is as easy as skipping it. Nothing here deletes a video: a skip moves one row in the database, and a restore moves it back, so the clip lands in To tag where it was, in shooting order.

**Key ideas:**

- **A pure rule for the days.** Cutting a list into days is a small rule, so it lives in `domain/` and has its own tests. The day is the date where the clip was shot (Section 5), not where the phone is now. The only subtle line is that days are keyed by *date*:

  ```dart
  final byDay = <DateTime, List<Clip>>{};
  for (final clip in newestFirst) {
    (byDay[_dayOf(clip, times)] ??= []).add(clip);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  ```

  Why not just start a new day whenever the date changes while walking the list? Because the list is sorted by the *instant* a clip was shot. A clip shot in India at 07:00 on the 29th and one shot in New York at 21:00 on the 29th are 19 hours apart as instants, with a clip from another day sometimes in between. Walking in order would show "Thu, Oct 29" twice. A map keyed by date cannot.

- **Newest first, also inside a day.** To tag lists a day oldest first, because you tag in the order you shot. Skipped is a pile you dig through for one clip, and the prototype sorts it newest first and then cuts it into days, so each day's clips are newest first too. The controller hands the screen the database's list reversed:

  ```dart
  return clips
      .watchInbox(InboxState.skipped)
      .map((oldestFirst) => oldestFirst.reversed.toList(growable: false));
  ```

- **One restore for each clip at a time.** A double tap on a tile must not write twice. The screen keeps the set of clips it is restoring right now and leaves those out:

  ```dart
  final todo = ids.difference(_restoring);
  if (todo.isEmpty) return;
  ...
  _restoring.addAll(todo);
  try {
    final controller = ref.read(skippedControllerProvider.notifier);
    final selection = ref.read(skippedSelectionProvider.notifier);
    final record = await controller.restore(todo);
  ```

  (The two lookups sit inside the `try`, so if one of them throws, the clips are still taken out of `_restoring` in the `finally`.) Only the selection's **Restore** ends choosing afterwards: a tap restores one clip outside a choice, and must not end a choice you began while it wrote.

  A set (not one yes/no flag) means a second, different tile does not have to wait for the first. The database would also say "nothing moved" for a clip that is not skipped any more, but the guard stops the second call before it is made, which the test checks by counting calls.

- **Look things up before you wait.** `_restore` fetches the messenger for the message (`ReelSnacks.of(context)`), the controller and the selection *before* the `await` on the write. After an `await` the screen may be gone (the user pressed Back), and a lost `context` or a disposed provider throws. Because the message lives on the app's root messenger and holds the undo record itself (Section 4's `InboxUndo`), **Undo still works after you have left the screen**. A test leaves the screen and then taps Undo.

  The message also counts what *really* moved: `record.before.length`. If the clip was restored or tagged somewhere else a moment before, nothing moved and no message is shown, which is better than a "Restored" that is not true.

- **The selection follows the list, and ends with it.** `SkippedSelection` is To tag's selection (Section 8) on this list: a clip that leaves Skipped (restored, or removed by the check) is dropped from the choice. One case is new. If the whole list empties while you are choosing, choosing ends, even with nothing chosen, because there is nothing left to choose:

  ```dart
  void _prune(Set<int> live) {
    if (live.isEmpty) {
      clear();
      return;
    }
  ```

- **A count that stays readable at big text.** The selection bar draws its title at most 1.5 times larger. To tag's bar has two buttons next to the count, and at 2x text it showed "2 sele…". Here there is only **Restore**, so above 1.5x it becomes an icon with the label "Restore" for a screen reader, and "{n} selected" fits whole:

  ```dart
  final compact =
      MediaQuery.textScalerOf(context).scale(1) > TtMetrics.appBarMaxTextScale;
  ```

  Two other ways were tried first and rejected (D-99 point 5): letting the title wrap, which the Scaffold's fixed-height bar clips, and putting the bar in the body, which broke the word in the middle ("sele-cted").

- **A tap that moves a clip says so to a screen reader.** The tile is announced "Skipped clip, 5:14 PM, 0:24. Restores it to To tag", because a tap that silently moves something would be a surprise. While you are choosing it is the plain "Clip, …".

- **Tests that can fail.** The seven screen tests of the plan were first run against the old stand-in screen, with the new screen's tests written: 27 of 29 failed (the two that passed only check that the empty bar fits and that Back leaves). Then five mistakes were made on purpose, one at a time: a tap with no message (`tap restores with undo` caught it), oldest day first (`newest day first` and four tests of the rule caught it), no check on open (`missing skipped clip is verified away` and two controller tests caught it), no double-tap guard (two tests caught it, by counting the repository's restore calls) and the list not reversed (the controller test caught it).

**Where it lives:** `app/lib/features/tagging/views/skipped_screen.dart` (`SkippedScreen`); `app/lib/features/tagging/view_models/skipped_controller.dart` (`SkippedController`, `skippedTimes`, `skippedDays`) and `skipped_selection.dart`; `app/lib/domain/rules/skipped_days.dart` (`groupIntoDays`); the route `Routes.skipped` in `app/lib/router/`. Tests: `app/test/features/tagging/views/skipped_screen_test.dart` (the screen over a real in-memory database), `skipped_golden_test.dart` (macOS images in `goldens/macos/`), `app/test/features/tagging/view_models/skipped_controller_test.dart` and `app/test/domain/rules/skipped_days_test.dart`. Flow: "Skipped" under "To tag, the Shooting mode card and Add earlier videos" in `docs/flow.md`.

**Try it yourself:** break the day order and watch two tests notice. From the repo root:

```bash
(cd app && ../tool/flutter test test/domain/rules/skipped_days_test.dart)
```

It ends with `All tests passed!`. Now open `app/lib/domain/rules/skipped_days.dart`, find `final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));` and change `b.compareTo(a)` to `a.compareTo(b)`. Run the command again. It fails, with lines like `Expected: ['2026-10-29: [4]', '2026-10-28: [3, 2]', '2026-10-27: [1]']` and `Actual: ['2026-10-27: [1]', '2026-10-28: [3, 2]', '2026-10-29: [4]']`: the oldest day came first. Put the file back with `git checkout -- app/lib/domain/rules/skipped_days.dart` (if you have not committed your own changes to it) and check with `git status`.

**Decisions:** D-99 (all of this section), with D-98 (the stand-in it replaces, the selection it copies, `toTagDayText`), D-94 (`restoreClips` and the `InboxUndo`), D-72 (the check on open), D-85 (messages on the root messenger), D-87 (day headers) and D-83 (the time where a clip was shot) as background.

## 10. On the S24

**What we built:** the proof on the owner's phone. A new on-device test, `app/patrol_test/tagging_test.dart`, taps through the real app on the Samsung Galaxy S24 Ultra: it puts 40 short test videos into the phone's `Movies/TakeTray Test/` folder, opens the tag player and tags the whole day, then checks that every clip is where it should be. Four smaller tests do the same for Undo, Skip all with the Skipped list, Tag scene, and the Undo that survives a change of tab. While it runs it also stops a clock: how long from a tap on a reel to the next clip playing.

**Why TakeTray needs it:** a widget test runs on your Mac with a fake video player. The tag player's whole job is to keep up with a person who taps once per clip, so only the real phone, with the real video decoder, can say whether "the next clip is already playing" is true. And "wrong video is the worst bug" (Section 7) is a promise about what the phone really shows, so the test also checks that the video on screen was opened from the address of the clip the player says it is showing.

**Key ideas:**

- **A plan, written down as the test goes.** For each tap the test notes which clip was showing and which reels it should end up in. At the end it asks the database what each reel holds and compares the two lists clip by clip. A count alone (23 and 23) would pass if two clips swapped places; the lists cannot.

  ```dart
  Future<void> tagInto(String kind, Set<int> reels, Future<void> Function() tap) async {
    final id = player.currentId!;
    plan[id] = reels;
    await player.act(kind, tap);
  }
  ```

- **Raw taps in the player.** Patrol's own `$().tap()` waits for the screen to "settle" after the tap, up to two seconds. The player never settles (a video plays and the scrub bar moves), so every tap would cost two seconds, and the clock would measure the wait instead of the app. The test taps with `tester.tap(finder)`, which does not wait, and then pumps frames in a loop of 4 ms until the app has moved on.
- **What "playing" means.** After a tap the test waits for the player to show the next clip, then for a `VideoPlayer` on screen whose controller was opened from that clip's address, is initialised and is playing. The plugin's `isPlaying` flips as soon as `play()` is called, so the test then asks ExoPlayer itself, over the channel, for its position until it is past zero. That second number is the honest "frames are moving".
- **Counting controllers.** At most two video controllers should be alive (the clip showing and the one ahead, Section 7). The test asks the Riverpod container whether `clipPlayerProvider` exists for each of the session's clips, on every poll, and keeps the highest count.
- **Clean-up at the end of the body.** The reels and videos are deleted in a `finally` at the end of the test body, the watched folders are put back there too, and never in a tear-down, because by then the app has closed its database (Phase 4 found that the hard way). The reels are found with a one-off `select`, not a stream, for the same reason.
- **A read that outlives its screen.** The first version of two tests read "how many clips wait" from `toTagControllerProvider`, which only lives while To tag is on screen. Off screen the provider is created, read, and thrown away again before its first value arrives, so the test saw 0 and failed. The test now reads the database directly (`watchInbox(pending).first`); the provider is for screens.

**Where it lives:** `app/patrol_test/tagging_test.dart` (the five tests and the `_Player` that taps and times), `app/patrol_test/support/test_media.dart` (`insertMany`), `docs/dev-setup.md` ("Phase 5 check", "Running `tagging_test.dart`").

**Try it yourself:** with the S24 connected, unlocked, on its home screen:

```
tool/patrol test -d RZCY80PHWCZ -t patrol_test/tagging_test.dart
```

It ends with `Successful: 5`. Then make it fail: in `_tagScene` change `expect((await env.reelClipIds(env.a)).length, total);` to `total + 1` and run again. One test fails with `Expected: <5>  Actual: <4>` and the other four pass. Put the line back. Afterwards run the three commands in "After a Patrol run" (`docs/dev-setup.md`) so TakeTray Dev is the normal debug app again.

**What the phone said (2026-11-01):**

- All five tests pass. The 40-clip day takes **47 s from Start tagging to All done** (40 actions), and about a minute with the set-up (40 videos inserted and scanned).
- A tap on a reel chip to the next clip playing: **519 ms on average (p95 564, worst 598)**. Of that, 400 ms is the deliberate check on the chip (`tagHold`); the write and the move on take about 110 ms. ExoPlayer's position is past zero 560 ms after the tap (worst 686). Pick several's confirm, Same as previous and Skip have no hold: 94 to 133 ms on average.
- Not one of the 39 clip changes took a second (target: under 1 s). The next clip's player was always already open: from the moment the player showed the next clip to the moment it was playing, 0 ms.
- At most **two** clip controllers were alive at any sample; the third that the design allows for a moment was never seen (it would have to fall between two polls 4 ms and 20 ms apart).

**Decisions:** D-100 (all of this section), with D-77 (the debug channel), D-96 and D-97 (the session and the player this test drives) and D-91 (Pick several is sticky).
