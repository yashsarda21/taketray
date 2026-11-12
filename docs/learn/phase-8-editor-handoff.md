# Learning guide: Phase 8, handing a reel to an editor

This guide explains how TakeTray hands a reel's clips to a video editor: CapCut and Instagram Edits get the original clips in one direct share, VN gets temporary copies in a folder, and TakeTray remembers which clips are in the edit, cleans the copies up and reminds the user about them.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-118 (the owner's decisions and the rulings made for the owner), so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-118.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Editing rules](#2-editing-rules)
3. [Schema v2 and the editing sessions repository](#3-schema-v2-and-the-editing-sessions-repository)
4. [The editors bridge and the copy folder guard](#4-the-editors-bridge-and-the-copy-folder-guard)
5. [Copying in the app](#5-copying-in-the-app)
6. [EditSessionService](#6-editsessionservice)
7. [The copies reminder and the Done editing tap](#7-the-copies-reminder-and-the-done-editing-tap)
8. [Design-system pieces for editors](#8-design-system-pieces-for-editors)
9. [Picking clips, the editor sheet, CapCut/Edits and Share](#9-picking-clips-the-editor-sheet-capcutedits-and-share)
10. [The VN copy screens](#10-the-vn-copy-screens)
11. [The reel page while editing](#11-the-reel-page-while-editing)
12. [CapCut/Edits add-later through the folder](#12-capcutedits-add-later-through-the-folder)
13. [The VN copies storage screen](#13-the-vn-copies-storage-screen)
14. [On the S24](#14-on-the-s24)

## 2. Editing rules

To be written in Task 2 (decision D-119).

## 3. Schema v2 and the editing sessions repository

To be written in Task 3 (decision D-120).

## 4. The editors bridge and the copy folder guard

To be written in Task 4 (decision D-121).

## 5. Copying in the app

To be written in Task 5 (decision D-122).

## 6. EditSessionService

To be written in Task 6 (decision D-123).

## 7. The copies reminder and the Done editing tap

To be written in Task 7 (decision D-124).

## 8. Design-system pieces for editors

**What we built:** five small widgets that the editor screens (sections 9 to 13) share, all in `packages/taketray_ui`:

- **`TtStorageBar`**, the bar on the "Copy clips for VN" screen. When the copies fit, the bar is your free space and the copies are a violet part of it. When they don't, the bar is what the copies need: the part your phone has is grey, and the part it lacks is red stripes.
- **`TtBottomBar`**, the bar at the bottom of a picking screen ("3 videos picked", and the **Add** button). It was already on the Add videos grid; now it is a shared widget and the grid uses it.
- **`TtIllustratedSteps`**, the three little pictures on the "Ready for VN" screen: a phone with a big **+**, a folder list with one folder lit, and a grid of numbered clips.
- **`TtStatusLayout`**, a whole screen with an icon, a title, a few words and buttons at the bottom ("Phone storage is full", "Copying clips for VN").
- **`TtAppIcon`**, an editor's icon, or its first letters on a tile when Android gives us no picture.

**Why TakeTray needs it:** VN needs the clips copied, and that needs a space check, a copy screen, an error screen and a "now do this in VN" screen. Other editors reuse the same pieces. If each screen drew its own, they would drift apart and each would need its own tests for 2x text and dark mode.

**Key ideas:**

- **No wording in the package.** The package never holds a sentence. Every text is a parameter:

  ```dart
  TtStorageBar.short(
    haveFraction: 0.6,
    haveLabel: 'You have 1.8 GB',
    shortLabel: 'Short by 1.2 GB',
    semanticLabel: 'Copies need 3 GB, you have 1.8 GB, short by 1.2 GB',
  );
  ```

  Read it like this: the screen decides what the words are, in the user's language, and the bar only draws.

- **A fraction you can't misdraw.** `haveFraction` must be at least 0 and under 1. A share of 1 would mean "it fits", which is the other look, so the constructor refuses it (`assert`). The copies' share in the other look is never drawn narrower than 4 %, or 8 MB next to 4 GB would be invisible:

  ```dart
  final share = math.min(1, math.max(needFraction!, TtMetrics.storageMinNeedFraction));
  ```

- **One node for the bar.** A screen reader hears one sentence ("Free space 4.3 GB, copies need 1.2 GB"), not the bar, then each legend item again. The bar and legend sit under `ExcludeSemantics` inside one `Semantics(label: ...)`.

- **Pictures that don't grow.** At 2x text the sentences next to the pictures wrap and the step gets taller, but the pictures stay 112 by 132. They are drawings; their tiny text (9.5 and 8 dp) is inside `MediaQuery.withNoTextScaling`. A screen reader skips the pictures, except the folder list: the folder you must open is announced as **selected**, and Android supplies that word in the user's language.

- **A content area that scrolls, buttons that don't.** `TtStatusLayout` centres its block in the space above the buttons. At 2x on a short screen the block is taller than the space, so it scrolls and the buttons stay where they are.

- **A broken picture is not a broken icon.** `TtAppIcon` shows the letters tile when the bytes are empty, or when Flutter cannot decode them. A test gives it three garbage bytes and checks that the letters appear and nothing throws.

- **Tests that can fail.** All the tests were written first against empty stand-ins and failed for the right reasons (a missing widget, a wrong size, a missing assert). Then key lines were broken on purpose, one at a time, and each broke a named test: the 4 % minimum (removed, and lowered to 2 %), the solid and hatched parts swapped, each part of the `haveFraction` assert, the one-node semantics, the hatch's second stripe, the live region, the bottom inset, the selected folder, the badge numbers, the picture's text scaling, the warning colour, the scrolling, the heading, and the icon's two fallbacks.

**Where it lives:** `packages/taketray_ui/lib/src/components/` (`storage_bar.dart`, `bottom_bar.dart`, `illustrated_steps.dart`, `status_layout.dart`, `app_icon.dart`, and `internal/hatch_painter.dart`), their numbers in `lib/src/theme/tt_metrics.dart`, the Add videos grid in `app/lib/features/add_videos/views/add_grid_screen.dart`, the Widgetbook use cases in `widgetbook/lib/components/`. Tests: `packages/taketray_ui/test/components/*_test.dart` and `*_golden_test.dart`.

**Try it yourself:** see the 4 % minimum work. From the repo root:

```bash
cd packages/taketray_ui && ../../tool/flutter test test/components/storage_bar_test.dart --plain-name "at least 4 %"
```

It ends with `All tests passed!`. Now open `lib/src/components/storage_bar.dart`, find `_enough`, and change `math.max(needFraction!, TtMetrics.storageMinNeedFraction)` to just `needFraction!`. Run the test again: it fails, because a copy of 0.1 % now draws a bar a third of a dp wide. Put the line back and run it again to see it pass.

**Decisions:** D-125 (all of this section), with D-118 (the Phase 8 decisions), D-19 (design tokens only), D-42 (the Widgetbook covers every component) and D-61 (CI goldens) as background.

## 9. Picking clips, the editor sheet, CapCut/Edits and Share

To be written in Task 9 (decision D-126).

## 10. The VN copy screens

To be written in Task 10 (decision D-127).

## 11. The reel page while editing

To be written in Task 11 (decision D-128).

## 12. CapCut/Edits add-later through the folder

To be written in Task 12 (decision D-129), after the owner's two hand checks (the gate before Task 12).

## 13. The VN copies storage screen

To be written in Task 13 (decision D-130).

## 14. On the S24

To be written in Task 14 (decision D-131).
