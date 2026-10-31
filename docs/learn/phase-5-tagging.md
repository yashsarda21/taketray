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

  The clip tile and the add-reference tile call it with their own constants. The pill tabs' dashed painter draws a stadium (a different path), and the reel card's scrim uses a colour of its own, so those two stay as they are; D-92 says why.

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

_Filled in by Task 3._

## 4. Skip, skip all and restore with undo

_Filled in by Task 4._

## 5. Scenes, the tag queue and time ranges

_Filled in by Task 5._

## 6. The tag session

_Filled in by Task 6._

## 7. The tag player screen and All done

_Filled in by Task 7._

## 8. To tag with scenes, and the picker's tag mode

_Filled in by Task 8._

## 9. The Skipped list

_Filled in by Task 9._

## 10. On the S24

_Filled in by Task 10._
