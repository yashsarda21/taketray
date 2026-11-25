# Learning guide: Phase 12, UI refresh: glass everywhere and the full-screen tag player

This guide explains two things the owner asked for after comparing the app on a real phone with the design: the frosted-glass look that was missing (the page behind a dialog only went darker, a menu did not blur anything, the status pill on a reel's cover was sharp), and the tag player redesigned so that the clip fills the screen, the reels sit in a dock, Skip and Same are glass buttons on the right, and you swipe up and down between clips. It also explains how a test can prove that something is blurred, which is harder than it sounds.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The task sections follow the order the phase was built: first the glass (Tasks 1 to 6 and 6A), then the pieces of the tag player (Tasks 7 to 10), then moving between clips (Task 11) and the phone tests (Task 12). After them come the deep dives that several tasks share, and the closing summary.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's are D-172 to D-184. The spec is `docs/superpowers/specs/2026-11-24-phase-12-ui-refresh-design.md` and the tag player's design is `design/handoff/tag-player-full-screen.md` (D-171).
- **Commands.** Run them from the repository root, through the wrappers in `tool/`. A test in the design system package runs with `cd packages/taketray_ui && ../../tool/flutter test <file>`; one in the app with `cd app && ../tool/flutter test <file>`.
- **Two words.** **Glass** is a see-through panel that blurs what is behind it (in Flutter a `BackdropFilter`). **Scrim** is the dark layer behind a dialog or sheet, or a dark fade over a video so that white text can be read.
- **Every task section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.
- **Test-driven.** Every task wrote its edge-case tests first and saw them fail ("red"), then wrote the code, then broke the code on purpose to see that a test noticed (a "mutation check"). The "try it yourself" parts name some of those mutants.

## Contents

1. [Task 1: A steady blur behind dialogs and sheets](#task-1-a-steady-blur-behind-dialogs-and-sheets)
2. [Task 2: The reel cover pill and the glass order](#task-2-the-reel-cover-pill-and-the-glass-order)
3. [Task 3: The snack is glass](#task-3-the-snack-is-glass)
4. [Task 4: The nav pill saturates, and its shadow stays outside](#task-4-the-nav-pill-saturates-and-its-shadow-stays-outside)
5. [Task 5: Menus blur the page](#task-5-menus-blur-the-page)
6. [Task 6: The share screen blurs the app behind it](#task-6-the-share-screen-blurs-the-app-behind-it)
7. [Task 6A: The To tag count on the nav pill](#task-6a-the-to-tag-count-on-the-nav-pill)
8. [Task 7: The rail button and the on-video reel chips](#task-7-the-rail-button-and-the-on-video-reel-chips)
9. [Task 8: The reel dock, the chevrons and the scrims](#task-8-the-reel-dock-the-chevrons-and-the-scrims)
10. [Task 9: The stage](#task-9-the-stage)
11. [Task 10: The full-screen player](#task-10-the-full-screen-player)
12. [Task 11: Swiping up and down](#task-11-swiping-up-and-down)
13. [Task 12: The Patrol flows](#task-12-the-patrol-flows)
14. [Why the dialog blur was invisible on the phone](#why-the-dialog-blur-was-invisible-on-the-phone)
15. [How CI proves a blur](#how-ci-proves-a-blur)
16. [Glass and ink](#glass-and-ink)
17. [Window blur on Android](#window-blur-on-android)
18. [Cover or contain](#cover-or-contain)
19. [Following the finger](#following-the-finger)
20. [On the S24](#on-the-s24)
21. [What the phase leaves you with](#what-the-phase-leaves-you-with)

## Task 1: A steady blur behind dialogs and sheets

### What we built

The blur behind every dialog and sheet is now the same from the first frame of opening to the last frame of closing. Before, its strength grew from nothing to 3 dp while the route opened; the dim (black at 50 %) faded in on its own. Now only the dim fades.

The task also built the tool every later task uses: a test helper that draws sharp stripes behind a piece of glass, photographs the result and measures how much of the stripes' contrast is left.

### Why TakeTray needs it

The owner looked at the Delete reel dialog on the S24 and the page behind it looked darker, not blurred. The code asked for a blur of 3 dp, the design's value, and nothing in it explained why it could not be seen. Guessing would have changed numbers that were already right, so the phase started by finding the cause on the phone with a throwaway build (see "Why the dialog blur was invisible on the phone").

### Key ideas

**1. Steady, with no animation.** The blur is a `BackdropFilter` with one fixed sigma, around the barrier the route already builds:

```dart
Widget ttBlurredBarrier({required Widget barrier}) => BackdropFilter(
  filter: ui.ImageFilter.blur(
    sigmaX: TtMetrics.scrimBlur,
    sigmaY: TtMetrics.scrimBlur,
  ),
  child: barrier,
);
```

The dim still fades, because Flutter's own `AnimatedModalBarrier` does that. The blur leaves at once when a close ends; nobody sees it, because the dim has already faded.

**2. The test renderer is not the phone.** The new pixel test passed on the old, ramped code too: the renderer the tests use drew the blur correctly. So the test that failed first (the "red") checks the structure the phone proved: the scrim's `BackdropFilter` exists from the first frame, has sigma 3 on every frame to the end of the close, and is the same widget each time. The phone decides in the end (Task 14).

**3. One helper for every later glass task.** `test/support/tt_glass_pixels.dart` is described in "How CI proves a blur".

### Where it lives

- `packages/taketray_ui/lib/src/components/internal/blur_barrier.dart`: `ttBlurredBarrier`; the dialog and the sheet route call it.
- `packages/taketray_ui/test/support/tt_glass_pixels.dart` (shared with the app as `app/test/support/glass_pixels.dart`): the stripes, the photograph, `expectBlurred`, `expectSteadyScrimBlur`.
- An app golden of the Delete reel dialog over a reel's page, light and dark: `reel_overlays_golden_test.dart` (macOS only).

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/glass_pixels_test.dart
```

The helper tests itself first: a blur of 0 and of 1 must count as "not blurred", and 3 and 12 as blurred.

### Decisions

- D-172: the cause, the steady blur, why the guard is structural, and what is left to the phone.

## Task 2: The reel cover pill and the glass order

### What we built

The status pill that sits on a reel's cover now blurs the cover, and every other piece of glass in the design system is built in the same order. One shared widget, `TtGlassFill`, builds it.

### Why TakeTray needs it

On the phone the pill on a reel cover was sharp, while the "Editing in VN" pill next to it, with the same blur and fill, was soft. The only difference was what the blur filter held: the sharp pill held a `Material` that painted its own colour; the soft one held a plain coloured box. See "Glass and ink".

### Key ideas

**1. The rule.** The first thing a `BackdropFilter` paints must be a plain fill (a `ColoredBox`, or a coloured `DecoratedBox` when the glass has a border). Ink (the ripple of a press) goes on a transparent `Material` inside the fill.

**2. One helper instead of five copies.** `TtGlassFill` is `ClipRRect` → `BackdropFilter` → `ColoredBox` → transparent `Material` → child:

```dart
return ClipRRect(
  borderRadius: corners,
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
    child: ColoredBox(
      color: fill,
      child: Material(type: MaterialType.transparency, child: child),
    ),
  ),
);
```

The status pill, the "Editing in VN" pill, the references badge and the Shooting mode card's icon tile use it. The nav pill and the card rows keep their own structure, because their fill has a hairline border, but they follow the same order.

**3. An audit, not a guess.** Every `BackdropFilter` in the design system was listed with its first painting child (the table is in D-173). Only the status pill broke the rule.

**4. Two tests, two jobs.** `expectGlassStructure` fails if a `Material` comes first (the one that was red). The pixel tests check that each piece blurs by its design value (8, 8, 8, 8, 6 and 18).

### Where it lives

- `packages/taketray_ui/lib/src/components/internal/glass_fill.dart`
- `packages/taketray_ui/lib/src/components/status_pill.dart`, `glass.dart` (`TtGlassPill`), `reel_card.dart`, `shooting_mode_card.dart`
- `packages/taketray_ui/test/components/glass_pixels_test.dart`

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/glass_pixels_test.dart
```

Then break it: in `glass_fill.dart` swap the `ColoredBox` for `Material(color: fill)` and run it again. The structure check fails, although the pixels still look blurred in the test renderer.

### Decisions

- D-173: the rule, the audit table, the proof.

## Task 3: The snack is glass

### What we built

The snack (the message bar with "Undo") has the design's 12 dp blur under its 94 % fill, clipped to its rounded shape. The shadow stays outside the clip.

### Why TakeTray needs it

The design's snack is glass; ours was a flat dark bar (D-48 had left the blur out). It also matters for the new player, where the snack floats over a playing video.

### Key ideas

**1. The order of the layers.** A box with the shadow, then the `TtGlassFill` inside it. If the shadow sat on the clipped glass, the clip would cut it off.

**2. Where a missing clip shows.** Inside Flutter's own `SnackBar` the corners are clipped anyway, so a forgotten `ClipRRect` would show nothing. A test therefore draws the snack on its own over stripes and looks just outside its rounded corner: it must still be as sharp as the bare stripes.

**3. The fade can hide the blur.** The snack fades in and out, so the test measures it at rest, after the animation.

### Where it lives

- `packages/taketray_ui/lib/src/components/snack.dart`
- Tests: `glass_pixels_test.dart` (group "the snack"), `snack_test.dart`

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/snack_test.dart test/components/glass_pixels_test.dart
```

### Decisions

- D-174 (amends D-48).

## Task 4: The nav pill saturates, and its shadow stays outside

### What we built

Two fixes to the floating bottom bar. Its glass now does what the CSS `backdrop-filter: blur(18px) saturate(1.4)` does: after blurring, colours are pushed 40 % further from grey. And the pill's drop shadow is painted only outside the pill, as a CSS `box-shadow` is, so it no longer darkens the inside of the glass.

### Why TakeTray needs it

Next to the prototype the nav pill looked flat and grey. It also looked dirty: Flutter paints a `BoxShadow` under the whole box, and a 78 % fill let it show through.

### Key ideas

**1. Saturation is a colour matrix.** The W3C Filter Effects module defines `saturate` as a 4 × 5 matrix. The code copies it row by row:

```dart
List<double> ttSaturationMatrix(double amount) {
  final s = amount;
  return [
    0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0, 0, //
    0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0, 0,
    0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
```

At `s = 1` it is the identity.

**2. Blur first, then saturate.** CSS applies `blur()` and then `saturate()`; in Flutter the first is the inner filter of a composition:

```dart
filter: saturation == 1
    ? blurFilter
    : ui.ImageFilter.compose(
        outer: ui.ColorFilter.matrix(ttSaturationMatrix(saturation)),
        inner: blurFilter,
      ),
```

The tests pin this by equality, because stripes with a period of 8 cannot tell a blur of 12 from one of 18; they also check the swapped order is not what is built.

**3. A shadow outside the box only.** `OutsideShadowPainter` clips the canvas to "a big rectangle minus the box" and then paints each shadow as Flutter would. It sits in a `CustomPaint` outside the glass's own clip, so the clip does not cut the shadow.

**4. A trap in the test binding.** `flutter test` turns shadow blurs off, so a shadow is a sharp copy of its shape. The tests that measure a soft shadow's reach switch blurs back on for the photograph (`ttWithBlurredShadows`) and put the flag back before the test ends, because the binding fails a test that leaves it changed.

### Where it lives

- `packages/taketray_ui/lib/src/components/internal/saturation.dart`, `internal/outside_shadow.dart`, `glass.dart`
- `TtMetrics.navPillSaturation` (1.4)
- Tests: `glass_test.dart`, `glass_pixels_test.dart` (group "the nav pill over a flat colour")

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/glass_test.dart test/components/glass_pixels_test.dart
```

### Decisions

- D-175.

## Task 5: Menus blur the page

### What we built

An open menu (the three-dots menus on the reel page, To tag and the references cards) now blurs the whole page behind it by 3 dp, with no dimming, as in the design. A menu is a route of TakeTray's own, `TtMenuRoute`, instead of Flutter's `MenuAnchor`.

### Why TakeTray needs it

`MenuAnchor` draws its menu in an overlay with no barrier, so there was nothing to put a blur on. A route has a barrier, and the barrier is where Task 1's steady blur lives.

### Key ideas

**1. A route with a see-through, blurring barrier.** It has no dim colour, no animation (a ramped blur failed on the phone), and its barrier is the same helper as the dialogs':

```dart
@override
Widget buildModalBarrier() =>
    ttBlurredBarrier(barrier: super.buildModalBarrier());
```

**2. The same place as before.** `TtMenuLayout` copies `MenuAnchor`'s placement number for number: the panel's top-start corner on the anchor's bottom-start corner, flipping above when it does not fit. A characterization test pins four placements; it was green on `MenuAnchor` before the change and green after it with the same rectangles.

**3. What a route gives for free, and what it does not.** Tap outside, Back and Escape close it. It did not give TalkBack an announcement or a scrolling panel; the review found both missing, and the fix wrapped the page in `Semantics(role: menu, scopesRoute, namesRoute, ...)` and put the items in a scroll view with the panel capped to the safe area.

**4. A menu is now a popup route.** The "Still shooting?" dialog looks at the popup tracker before opening, and now sees a menu too, so it no longer opens over an open menu.

### Where it lives

- `packages/taketray_ui/lib/src/components/internal/menu_route.dart`, `menu.dart`
- Tests: `menu_test.dart`; the app golden `reel_menu_light` / `reel_menu_dark`

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/menu_test.dart
```

### Decisions

- D-176 (amends D-48 and D-51).

## Task 6: The share screen blurs the app behind it

### What we built

On Android 12 and later the share screen (the see-through sheet over Instagram) asks Android to blur the app behind it by 3 dp. Where Android cannot (older versions, or battery saver on), the dim alone remains, as before.

### Why TakeTray needs it

D-167 left the blur out because Flutter can only blur its own pixels, and Instagram's window is another app's. Android can blur what is behind a window, so the design's blur is possible after all. See "Window blur on Android".

### Key ideas

**1. Ask the window, not Flutter.** `ShareWindowBlur` sets a flag and a radius on the activity's window attributes.

**2. The listener.** Android tells `ShareActivity` at once whether blur is allowed and again whenever that changes (battery saver), so the request is withdrawn and restored while the sheet is open.

### Where it lives

- `app/android/app/src/main/kotlin/app/taketray/share/ShareWindowBlur.kt`, `ShareActivity.kt`
- Tests: `app/android/app/src/test/kotlin/app/taketray/share/ShareWindowBlurTest.kt`

### Try it yourself

```sh
tool/test_android --tests 'app.taketray.share.ShareWindowBlurTest'
```

### Decisions

- D-177 (amends D-167). The registration in `ShareActivity` and the look of the radius can only be proved on the phone: hand check 8 of "Phase 12 check" in `docs/dev-setup.md`.

## Task 6A: The To tag count on the nav pill

### What we built

The To tag tab on the nav pill now shows how many clips wait, as the design draws it. It was always blank.

### Why TakeTray needs it

This task was added in the middle of the phase, at the owner's request: the design shows the count (`h.navbar(tab, s.toTag.length)` in the prototype) and the app never did. The cause was a leftover from Phase 0:

```dart
int _clipsToTag() => 0; // until the tagging feature supplies it in phase 5
```

Phase 5 never wired it up. The nav pill already knew how to draw the badge ("99+" above 99, the screen reader label "To tag, 7 clips"), so this is plumbing and not new UI.

### Key ideas

**1. One source of truth.** The count is the length of the same read-only list the Shooting mode card's strip uses, so the badge and "N clips to tag" on the card always agree:

```dart
final toTagCount = ref.watch(pendingClipsProvider).value?.length ?? 0;
```

`AppShell` became a `ConsumerWidget` to `watch` it.

**2. What it must not do.** Building To tag's own controller scans and verifies clips, which counts as "the user opened To tag" (D-76). The plain list only reads, so the badge can be on every tab all day.

**3. Loading and failure show nothing.** While the list loads, or if it has never answered, the count is 0 and the badge is hidden: never a spinner or an error in the nav pill.

### Where it lives

- `app/lib/features/shell/views/app_shell.dart`
- Tests: `app/test/features/shell/views/app_shell_test.dart`

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/shell/views/app_shell_test.dart
```

### Decisions

- D-184. Numbered out of order because the task was added after the plan: the other tasks keep D-178 to D-183.

## Task 7: The rail button and the on-video reel chips

### What we built

Two new glass pieces for the tag player. `TtRailButton` is a 64 dp button of icon, label and optional second line on the right side of the clip (Skip and Same). `TtReelChip` and `TtNewReelChip` gain an `onVideo` style: the reel chips of the dock, dark glass over the clip.

### Why TakeTray needs it

In the new player the buttons sit on top of the playing video. They must stay readable over a white clip and must blur the clip under their own small shapes (never the whole clip).

### Key ideas

**1. Built on `TtGlassFill`.** Rail glass is `railGlass` (74 % dark) at blur 12 with 20 dp corners; a dock chip is `dockChipGlass` (84 % dark) at blur 14 with 18 dp corners.

**2. Off is faded in the colours, not with an `Opacity`.** An `Opacity` wrapped round a `BackdropFilter` can drop the blur. A disabled rail button keeps 45 % of the alpha of its fill, icon and text. The mutant with an `Opacity` failed the off-state pixel test.

**3. Grow with the text.** The CSS limits the second line to 56 dp; at 2× text that would leave a few letters, so the limit is 56 dp times the text scale.

**4. Contrast was measured, not trusted.** The handoff says the rail's second line reads 7.8:1; the measured value is about 6.4:1, which still passes AA (4.5:1). The New reel chip passes AA only over the dock's scrim, so the dock must keep painting it.

### Where it lives

- `packages/taketray_ui/lib/src/components/rail_button.dart`, `reel_chip.dart`
- Tests: `rail_button_test.dart`, `reel_chip_test.dart`, `glass_pixels_test.dart`

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/rail_button_test.dart test/components/reel_chip_test.dart
```

### Decisions

- D-178.

## Task 8: The reel dock, the chevrons and the scrims

### What we built

`TtReelDock` is the panel at the bottom of the player: a scrub line, a header ("Add to reel" with its text buttons), a grid of reel chips and an optional footer, on a dark fade. `TtHeaderChevron` and `TtPlayerHeader` add the ‹ and › at the top. Two painters draw the dark fades at the top and the bottom.

### Why TakeTray needs it

The old player had a bordered panel under a blurred video. The new one has text over the clip itself, which is readable only on a scrim that fades smoothly.

### Key ideas

**1. A fade that has a length in dp.** A `LinearGradient` can only say "30 % of the height". The handoff's dock fade is 26 dp long, whatever the dock's height, so the scrims are painters that work their stops out from the height they are drawn at, with a clamp for a dock shorter than 52 dp.

**2. The scrim takes no touches and says nothing to TalkBack.** Both painters return false from `hitTest` and have no semantics.

**3. Large text.** From 1.5× the grid is one column of full-width chips. The review found that the header's title was squashed to a letter a line at 1.3× with Pick several and All reels beside it, so the header is a `Wrap` at any scale above 1×, a deliberate deviation from the handoff ("from 1.5"). The scene line is 82 % white (the review caught 78 %).

**4. The grid scrolls past 260 dp at every scale**, so the clip keeps its room even when Pick several holds many reels.

### Where it lives

- `packages/taketray_ui/lib/src/components/reel_dock.dart`, `player_chrome.dart`, `internal/player_scrims.dart`, `internal/chip_grid.dart`
- Tests: `reel_dock_test.dart`, `player_chrome_test.dart`, and the goldens

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/reel_dock_test.dart test/components/player_chrome_test.dart
```

### Decisions

- D-179.

## Task 9: The stage

### What we built

The clip is now shown by a stage that fills its space: it covers it (like Instagram Reels) or, when covering would cut off too much, shows the clip whole on black. The clip is never blurred; the old blurred background, the rounded corners and the shadow are gone, with their metrics. The paused disc and the loading picture were redone too. See "Cover or contain".

### Why TakeTray needs it

The design's player is the clip itself, edge to edge. A horizontal clip covering a phone would be unwatchable, so there is a rule for when to cover and when to show whole.

### Key ideas

**1. Two small pure functions** decide the fit (see "Cover or contain"), so the rule is tested with numbers and not with screens.

**2. The clip's shape comes from the player once it starts.** A clip stored as portrait whose file is really 16:9 switches from cover to contain as soon as the player reports its size.

**3. At this task the stage was not full-screen yet.** It was the band between the header and the panel, so the tests that needed a covering vertical clip used a taller screen. Task 10 made it full-screen and added the test that a contained clip sits above the dock.

### Where it lives

- `app/lib/features/tagging/views/stage_fit.dart`, `tag_player_screen.dart` (`_Stage`, `_ClipRoom`, `_Loading`, `_PlayDisc`)
- Tests: `stage_fit_test.dart`, `tag_player_screen_test.dart` (group "the clip showing")

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/tagging/views/stage_fit_test.dart
```

### Decisions

- D-180.

## Task 10: The full-screen player

### What we built

The tag player is rebuilt from the handoff: the clip under the status bar, the top (segments, Close, ‹ title ›, Mute) and the dock on their scrims, the rail (Skip and Same) on the right, and All reels, a sheet with every reel. `TtTagPanel` and the two small widgets that went with it are deleted.

### Why TakeTray needs it

This is the redesign the owner asked for (D-171): a one-handed player, with the clip as big as the phone allows and the reels under the thumb.

### Key ideas

**1. Measured, never a constant.** The dock's height, the rail's size and the top's height change with the text size, the number of reels and the phone. A small proxy object measures them after layout and tells the screen, which rebuilds once. The dock's height is what the stage keeps clear of, where the rail sits and where the snack goes.

**2. What the dock shows is a plain function.** `dockReels` takes the reels in Home's order and returns the grid, whether New reel and Pick several show, and whether All reels does:

```dart
return (
  grid: [ ...shown, /* picked reels from All reels while picking */ ],
  newReel: !multi,
  allReels:
      multi ||
      collecting.length > dockCollectingReels ||
      collecting.length < ordered.length,
  pickSeveral: ordered.length >= 2,
);
```

At most three Collecting reels are in the dock; All reels appears when a reel is not in it. While picking, All reels is always there, because it is New reel's only way in (a review ruling, so that the handoff's "Pick reels, All reels and Cancel" has no condition).

**3. The snack and the rail.** The snack must never cover the rail. At normal text it sits beside it, with a right margin measured from the rail's width. From 1.5× text the rail can be 120 dp wide and a snack beside it would wrap a word a line, so then the snack sits above the rail, full width (a ruling).

**4. Phones held sideways.** Nothing locks the orientation. A phone on its side left the dock about 107 dp where it needs about 168, so no reels showed. The dock now has a floor (its header plus one row of reels), measured from an offstage copy of the dock that is laid out, never painted, hit or announced. The phone must show whether this costs smoothness (hand check 20 of "Phase 12 check").

**5. A tap on the blank part of the dock goes through to the clip**, so a near miss of a chip pauses the clip, and never tags.

**6. The order a screen reader follows.** Top, clip, rail, dock, by sort keys on four groups.

### Where it lives

- `app/lib/features/tagging/views/tag_player_screen.dart`, `dock_reels.dart`, `all_reels_sheet.dart`
- Tests: `tag_player_screen_test.dart`, `dock_reels_test.dart`, `tag_player_golden_test.dart` (macOS goldens at 1× and 2× text)

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/tagging/views/dock_reels_test.dart test/features/tagging/views/tag_player_screen_test.dart
```

### Decisions

- D-181 (amends D-97's layout), with the three fix-round rulings: the snack above the rail at large text, All reels while picking, and the dock's floor.

## Task 11: Swiping up and down

### What we built

You swipe up for the next clip and down for the previous one, like Reels, and the clip follows your finger. A drag of more than 64 dp, or a fling faster than 800 dp/s, goes; less springs back. ‹ › do the same without a gesture, and at the ends of the session the clip springs back. Moves without a swipe (a tag, Skip, Same, Undo) slide the clip vertically too. See "Following the finger".

### Why TakeTray needs it

A sideways swipe fights Android's back gesture from the screen's edges; a vertical one cannot. It is also what Instagram's own Reels do, so the thumb already knows it.

### Key ideas

**1. Only the stage layer moves.** The swipe holds its offset in its own `AnimationController`, and rebuilds two `Transform`s. The screen itself is not rebuilt for each frame of a drag.

**2. The next clip is a picture, not a video.** While the finger moves, the clip coming in is its thumbnail one stage height away. The next clip's player is already open (the session keeps one ahead), so it takes over when the swipe settles; the previous clip's player opens on arrival, as after Undo does.

**3. A swipe remembers where it started.** The review found a hole: a Skip, ‹ › or Undo that landed in the 200 ms between the release and the commit moved the session once, then the swipe moved it again and a clip was passed over. Now the swipe holds the clip it started on and drops itself if the session is somewhere else.

**4. Reduced motion.** With "Remove animations" the clip does not follow the finger and nothing travels; every move is a 150 ms crossfade.

### Where it lives

- `app/lib/features/tagging/views/tag_player_screen.dart` (`_VerticalSwipe`, `_ClipMotion`, `_Thumbnail`)
- `TtMetrics.tagSwipeDistance`, `tagSwipeVelocity`
- Tests: `tag_player_screen_test.dart` (group "moving between clips")

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/tagging/views/tag_player_screen_test.dart --plain-name "moving between clips"
```

Then break it: change `tagSwipeDistance` from 64 to 32 in `tt_metrics.dart`, and the test that a 50 dp slow drag springs back fails. Or add a horizontal drag recognizer that moves the session, and the test that horizontal flings do nothing fails.

### Decisions

- D-182 (amends D-97 point 3), and its fix round.

## Task 12: The Patrol flows

### What we built

The on-phone tagging tests were updated to the new player, and a sixth flow was added: swipe up, swipe down, swipe sideways (which must do nothing), and a Ready reel tagged from the All reels sheet. They are written and checked on the computer; the phone runs them in Task 14.

### Why TakeTray needs it

Phase 5's flows found "Same as previous" and a reel chip by their text. In the new player that text is in two places at once (the dock and the All reels sheet) and the buttons are different widgets.

### Key ideas

**1. Finders that name a place.** `railButton(label)`, `dockChip(name)`, `sheetChip(name)`, `dockAction(label)` and `stageCentre(tester)` live in one file and are checked on the host by `player_finders_test.dart`. A finder that did not look inside the dock or the sheet would find two widgets once All reels is open; the mutants that removed the "inside" killed those tests.

**2. A swipe must start on the clip.** A swipe that begins on the header or the dock belongs to them, so `stageCentre` is the point halfway between the top's bottom edge and the dock's top.

**3. A check that nothing happened comes after one that something did.** The sideways swipe is checked after the first clip plays and its title shows, so "nothing moved" proves the gesture was made and ignored, not that the app was not ready.

### Where it lives

- `app/patrol_test/support/player_finders.dart`, `app/patrol_test/tagging_test.dart`
- Tests: `app/test/patrol_support/player_finders_test.dart`

### Try it yourself

```sh
cd app && ../tool/flutter test test/patrol_support/player_finders_test.dart
```

The phone run is in `docs/dev-setup.md`, "Running `tagging_test.dart`".

### Decisions

- D-183.

## Why the dialog blur was invisible on the phone

The owner saw the page go darker behind a dialog and no blur. The code looked right: blur 3 dp, black at 50 %. Instead of guessing, a throwaway build of TakeTray Dev drew sharp black and white stripes with a different blur over each, and the owner said what they saw. A few of the cases (the full table is in the spec):

| Case | What it was | The owner saw |
|---|---|---|
| D | a plain `BackdropFilter`, blur 3 | soft |
| A | the real dialog, with the blur growing from 0 to 3 as it opens | only darker |
| U | the real dialog with the blur held at 3 | soft |
| V | a plain card as the dialog, with the same growing blur | soft |
| F | the status pill on a reel cover, whose filter held a `Material` | sharp |
| K, T | the same sizes and colours with a coloured box inside | soft |

How to read it, the way a detective would:

- **D** says the phone's renderer can blur at 3. It is not "Android cannot do it".
- **A against U** is the same dialog; the only difference is the growing blur. Held steady, it works.
- **A against V** is the same growing blur; the only difference is the dialog. With a plain card it works.
- So the failure needs both together: the growing blur and TakeTray's dialog. Why, nobody knows, and no one needs to know to fix it: the ramp ends at the right value, so it is simply not needed. A steady blur (U) is proven on the phone.
- **F against K and T** is a second bug with a different cause: a `Material` as the first thing the filter paints.

The lesson is about method: change one thing at a time, and write down what each change showed. It also left a rule for later work: when the phone and the tests disagree (they did here, because the test renderer blurred correctly in every case), the test cannot prove the fix, so write down which structure the phone proved, and test for that structure.

## How CI proves a blur

A test that checks only that a `BackdropFilter` is in the tree proves nothing about the pixels, and the pixels are the whole point. So each piece of glass is drawn over stripes and photographed.

**The stripes.** Black and white stripes, 4 dp each, so a period of 8 dp. Sharp stripes have the highest contrast a picture can have, and a blur is exactly what removes contrast.

**The measure.** The test takes a thin strip of the glass with no text in it (between the rounded corners), measures how much the stripes still differ from one another (their edge contrast), and measures the same strip with the glass left out. The glass's fill lets a known share through: a 94 % fill leaves 6 % of the contrast, and the blur must take most of that.

**The 0.5 share.** The blur passes when what is left is under half of what the fill alone lets through:

```dart
const double ttBlurredShare = 0.5;
// ...
final limit = ttBlurredShare * (1 - fillOpacity) * sharp;
if (!(contrast < limit)) {
  throw TestFailure('Not blurred: ...');
}
```

A blur of 3 over stripes of period 8 leaves about a tenth, so it passes with a wide margin; a blur of 1 leaves about 87 %, so it fails. The helper tests its own thresholds (blur 0, 1, 3 and 12, and a 94 % fill) so that nobody can quietly weaken it.

**What pixels cannot tell.** At period 8, a blur of 12 and one of 14 cannot be told apart, because both erase the stripes. Where the exact value matters, the tests also pin the filter by equality (`expectBlurFilter`, and the nav pill's compose of saturation and blur).

**The structure check.** `expectGlassStructure` looks at the first thing every `BackdropFilter` paints and fails for a `Material`. This is the guard for what the phone proved and the test renderer cannot show.

**The scrim check.** `expectSteadyScrimBlur` checks the scrim's filter is present from the first frame, has sigma 3 on every frame to the end of the close, and is the same widget each time.

**A rule that came out of it:** when a test passes before the fix as well as after it (here, the pixel tests), the test is a guard against new mistakes, not proof of the fix. Say so in the decision (D-172, D-173 do) and let the phone settle it.

## Glass and ink

A `Material` in Flutter is a surface that paints its own colour and lets ink effects (the ripple of a press) show on it. A `BackdropFilter` blurs what is behind it and then paints its child over the result. On the S24, when the first thing a filter painted was a `Material` with a colour, the blur was lost: the pill was sharp. The same colour in a `ColoredBox` blurred. Why is not known, and the fix does not need it.

The rule that came out of it, in `TtGlassFill`:

1. clip (`ClipRRect`) so the blur stays in the rounded shape,
2. the `BackdropFilter`,
3. a `ColoredBox` with the fill, the first thing painted,
4. a **transparent** `Material` (`MaterialType.transparency`), which paints nothing itself but gives the `InkWell` inside it something to draw on,
5. the content.

The ripple still shows, over the fill. A test presses the pill for 400 ms and checks the photograph changes (the ink is painted) and that a release calls `onPressed`.

For glass that has a border (the nav pill's hairline, a card row's top border) the fill is a coloured `DecoratedBox`. The check accepts it, because it is a plain fill that paints first.

## Window blur on Android

Flutter can only blur its own pixels: a `BackdropFilter` sees what Flutter drew below it. The share screen sits over Instagram, which is another app's window, so no Flutter filter can reach it. Android can: from Android 12 a window can ask the system to blur whatever is behind it, with a flag and a radius.

```kotlin
attributes.flags = attributes.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
attributes.blurBehindRadius = radiusPx
```

**A radius is not a sigma.** The design says 3 dp, which is a sigma (the spread of the blur). Android's radius is converted to a sigma by its own rule, sigma = 0.57735 × radius + 0.5 (in pixels), so `ShareWindowBlur` inverts it:

```kotlin
fun radiusForSigma(sigmaPx: Float): Int =
    if (sigmaPx <= 0.5f) 0 else ((sigmaPx - 0.5f) / 0.57735f).roundToInt()
```

On the S24's density of 2.8125, 3 dp is 8.4375 px, and the radius is 14. The tests prove 4, 10 and 15 at densities 1, 2 and 3.

**The system can say no.** Battery saver turns cross-window blur off. A window listener (`addCrossWindowBlurEnabledListener`) reports the current state at once and again whenever it changes, so the request is withdrawn (flag cleared, radius 0) and the screen falls back to Flutter's own 50 % dim, and restored when it comes back. Android 11 and below ask for nothing.

**What the computer cannot prove.** The test environment's window manager has no blur state to change, and a Flutter activity cannot start there, so the registration and how the 14 looks are hand checks on the phone.

## Cover or contain

The player's stage has to decide how to fit a clip into a screen of a different shape. Two ways:

- **Cover** fills the whole screen and cuts what falls outside, like Reels.
- **Contain** shows the whole clip, with black bars.

A vertical 9:16 clip on a 360 × 800 phone covers with almost no loss. A horizontal clip would lose most of itself if it covered, so it is shown whole. The handoff draws the line at 20 %: if covering would cut more than a fifth of the clip, contain.

The sum: scale the clip until it covers (`s` is the larger of the two ratios), then see how much of the scaled clip sticks out.

```dart
double coverCrop({required Size area, required Size clip}) {
  if (!_known(area) || !_known(clip)) return 0;
  final s = math.max(area.width / clip.width, area.height / clip.height);
  return 1 -
      math.min(area.width / (clip.width * s), area.height / (clip.height * s));
}

BoxFit stageFit({required Size area, required Size clip}) =>
    coverCrop(area: area, clip: clip) >
        TtMetrics.tagStageMaxCoverCrop + _rounding
    ? BoxFit.contain
    : BoxFit.cover;
```

**Exactly 20 % covers.** A 9:16 clip on a 360 × 800 screen loses exactly 20 %, and "more than 20 %" means it must cover. In floating point an exact 20 % can land on either side of 0.2 (a 1080 × 1920 clip on 360 × 800 gives a number a hair under it), so the comparison allows a rounding of 1e-9 and a test pins the boundary from both sides.

**Unknown sizes cover.** A clip with no size yet, an empty or a negative one, or an unbounded area: nothing is known to be cut, so `coverCrop` is 0 and the clip covers.

**The player's shape wins once it starts.** The size stored when the clip was scanned is only a first guess; a rotated file can report the other way round. Once the player has a size, that size decides, so such a clip switches to contain instead of being cut by three quarters.

**Where a contained clip sits.** Centred in the room above the dock, not in the middle of the screen, and it follows the dock when the dock grows.

## Following the finger

A gesture that moves something should feel attached to it. Four decisions make the swipe feel right.

**The recognizer.** One vertical drag recognizer, with the distance counted from the touch-down (so a slow start does not eat the first dp) and a drag that starts only after a touch slop up or down. There is no horizontal recognizer at all, so a sideways swipe never meets it, and the old layer that kept clear of the system's back gesture is gone.

**The rule to go.** On release:

```dart
final far = dy.abs() > TtMetrics.tagSwipeDistance;
final fast =
    velocity.abs() > TtMetrics.tagSwipeVelocity && velocity.sign == dy.sign;
final there = next ? widget.hasNext : widget.hasPrevious;
if (dy != 0 && there && widget.idle && (far || fast)) {
  _go(next: next);
}
```

A long drag goes. A short drag goes only if it was a fling the same way. The session must be idle (not saving a tag, not holding a 400 ms tap). There must be a clip that way; at either end the clip springs back over black.

**What moves.** Only the stage layer. The screen does not rebuild for each frame of the drag, and the clip coming in is drawn as a thumbnail, so there is never a third video player. When the swipe settles, the next clip's video is already there.

**What comes after the finger lifts.** The stage goes off by one stage height over a short curve, and 200 ms later the session moves. In that window another move can land (Skip, ‹, a tag, Undo), so the swipe checks the session is still on the clip it started from, and drops itself if not (the Important finding of Task 11's review).

**Without a finger.** A tag, Skip, Same or Undo slides the clip up and out and the next one in from a little below, fading from 30 %. That is the same motion as a swipe, and a swipe that settles does not slide in a second time. With "Remove animations" there is no travel: a 150 ms crossfade.

## On the S24

The glass and the player are proved in code by about as much as a test renderer can prove. What it cannot prove is the phone's own renderer, so the last task is the phone: the Patrol flows, then the owner's side-by-side check of each glass element with the prototype.

**Phone tests: done (2026-11-25, Samsung S24, TakeTray Dev).** The numbered list "Phase 12 check" in `docs/dev-setup.md` holds the hand checks, and "Running `tagging_test.dart`" the commands.

**The Patrol flows.** They ran in two rounds, and all 13 files ended green. In round 1 `reels_test.dart`, `references_test.dart` (4/4), `editors_test.dart`, `add_videos_test.dart` (3/3) and `settings_test.dart` (5/5) passed, and `tagging_test.dart` passed 5 of 6. The flow that failed was the new "swipe and All reels": it timed out waiting for the All reels sheet to close. The fault was in the test. The flow tapped a reel chip as soon as the chip existed, but the sheet was still sliding in, and on a live phone, where frames run between the finger going down and coming up, the moving chip lost the tap. The host test had passed because fake time hides the slide. The app does the same thing for a Ready reel and a Collecting one: it closes the sheet and tags. The fix (51ce3f0) makes the flows' tap helper wait until the target can be hit and its rectangle is the same on two frames in a row. The rest of round 1 did not run at all, because `patrol_cli` could not reach pub.dev (a proxy 502), which was the environment and not the app. Round 2 gave `tagging_test.dart` 6/6, `app_shell_test.dart` 1/1, `onboarding_test.dart` 4/4, `background_test.dart` 7/7, `media_access_test.dart` 2/2 (and 1 skipped, as always), `media_scan_test.dart` 3/3 and `database_test.dart` 1/1; `share_test.dart` stays skipped (D-169). After every run the debug build was reinstalled with `install -r` and TakeTray Dev's data cleared with `pm clear app.taketray.dev`. The lesson is the one the phase kept teaching: a test that passes on the computer has not met a moving screen.

**The hand checks.** All 24 passed (the owner's word was "lgtm" for each group): the glass (checks 1 to 9), the tag player (10 to 17) and the rest (18 to 24), including the share blur with battery saver switched on and off and a second share. Three verdicts were asked for. The blur's strength (check 7): the owner kept the designed 3 dp (D-172). The reverse fling (check 14.7), where a drag up past 64 dp that is flicked back down still goes to the next clip: the owner kept it as it is (D-182). The large-text and sideways layouts that differ from the handoff (check 19): the owner is happy with them, so `docs/later.md` lists them as confirmed. The player is in D-181 and D-182, and the To tag count in D-184.

**What it is likely to teach.** In this phase the tests and the phone disagreed twice before the phone was asked (the dialog blur and the cover pill passed in the test renderer and failed on the S24), so a green `tool/check` is not the same as "it looks right". Things that only the phone can show are listed as hand checks and not claimed: smoothness while swiping, a possible black flash when a neighbouring thumbnail is not yet decoded on the first drag frame, the soft thumbnail against the live video, the 35 % dim while a clip loads after a swipe down, the To tag count on the nav pill matching the Shooting mode card and updating at once, the large-text layouts and the phone held sideways, TalkBack announcing a menu, and the share blur with battery saver.

## What the phase leaves you with

- **A blur is a measurement, not a hope.** Every glass piece is drawn over stripes and its sharpness measured, with the exact filter pinned beside it, so a lost blur fails a test.
- **A steady scrim.** Dialogs, sheets and menus blur the page by a fixed 3 dp from the first frame; only the dim fades.
- **One glass order.** `TtGlassFill` is the one way to build glass: clip, filter, plain fill, transparent `Material`, content. Any new glass gets a structure check and a pixel check.
- **Menus and the share screen blur too**, with a TakeTray route for menus and Android's own window blur on Android 12 and later (falling back to the dim alone).
- **The To tag count works.** A Phase 0 placeholder that was always 0 is wired to the same list the Shooting mode card reads.
- **The tag player is full-screen.** The clip fills the phone (or is shown whole above the dock when covering would cut over a fifth), the top and the dock sit on scrims, Skip and Same are a glass rail, and the reels are a dock with an All reels sheet.
- **A vertical swipe, like Reels.** The clip follows the finger, goes on a 64 dp drag or an 800 dp/s fling, and a late Skip or Undo never makes a swipe skip a clip.
- **What only a person can judge is a numbered list.** The glass, the large-text and sideways layouts, the smoothness and the screen reader are "Phase 12 check" in `docs/dev-setup.md`, to be answered by number.
