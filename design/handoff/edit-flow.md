# Sending clips to an editor, simplified: handoff

Owner's request, 25 Nov 2026 (D-185). This changes the entry points of D-126 and the reel page's choosing (D-88).

**Where to see it:**
- **Hub:**
  - screen 8 (reel page), states "Choosing clips…", "Choose clips…", "Every clip chosen", "Choosing while editing in VN" and 2×;
  - screen 19 (editor sheet);
  - screen 18 (now only "Add clips to a VN edit").
- **Prototype:** Start from: "Send a reel to VN".
- **Source:** `design/prototype/assets/editflow.js` and `editflow.css`.

## What was annoying

**From Edit video:**
1. A separate "Pick clips to edit" screen opened with **nothing ticked**.
2. You picked the clips there.
3. Then Continue.
4. Then the editor sheet.

**From holding a clip:**
- The selection bar showed Add to, Move and Remove as unlabelled icons, and **Edit was hidden in its ⋮ menu**.
- That ⋮ item sent you to the same picking screen again, so the clips were picked twice.

## The new flow

| From | Before | Now |
|---|---|---|
| Edit video (the whole reel) | Edit video → pick screen → Select all → Continue → editor | **Edit video → editor** (2 taps) |
| Some clips, by holding | hold → tap clips → ⋮ → Edit video → pick screen → Continue → editor | **hold → tap clips → Edit {n} clips → editor** |
| Some clips, from Edit video | Edit video → pick screen → tap clips → Continue → editor | Edit video → **Choose clips instead** → tap clips → Edit {n} clips → editor |

The editor used last is first in the sheet, so the usual send is **Edit video, then that editor**.

## 1. Edit video opens the editor sheet with every clip

**The FAB:** **Edit video** (the extended FAB, as today) calls `showEditorSheet` straight away. It passes every live clip of the reel, in shooting order, with `allClips: true`. It is still hidden during an editing session (R1).

**The sheet** (screen 19):
- **Title:** "Edit all {n} clips in…" when `allClips` and n > 1; otherwise "Edit {n} clips in…".
- **Subtitle:** "{length} · in shooting order".
- **Under it, only with `allClips`:** **Choose clips instead**, a text button with the `checklist` icon. It closes the sheet and starts choosing on the reel page with nothing chosen (section 2, "from the sheet").
- **Rows:** CapCut, Instagram Edits, VN, Other app… (unchanged: not installed is greyed, with "Not installed").
- **Last used:**
  - The editor used last comes **first**, with a "Last used" pill after its name (tertiaryContainer / onTertiaryContainer, labelSmall).
  - Store `lastEditor` (capcut, edits, vn or other) in the settings table when an editor is picked.
  - An editor that is no longer installed loses its place and its pill.
  - Accessible name: "Instagram Edits, last used".

## 2. Choosing clips on the reel page

**Starting:** hold a clip tile, or **Choose clips instead** from the sheet. `ReelSelection` (D-88) gets a `fromSheet` flag.
- Started by **holding**: as today, un-choosing the last clip ends choosing.
- Started **from the sheet**: choosing stays on with nothing chosen until Close or Back. A hint banner (`TtBanner` info, `touch_app` icon) sits at the top of the clips: "Tap the clips you want to edit / Next time, hold a clip to start choosing straight away."

**Top bar** (`TtAppBar(selection: true)`):
- Close.
- "{n} selected" ("Choose clips" when nothing is chosen).
- **Select all**, which reads **Clear** when every live clip is chosen.
- The Add to, Move and Remove icons and the ⋮ menu are **removed** from the top bar.
- At font scale ≥ 1.5, Select all / Clear is its icon alone (`select_all` / `deselect`), still with its name, so it never runs into the count.

**Bottom bar: a new `TtSelectionDock`** (taketray_ui)

It slides up (`medium2`, emphasizedDecelerate) on `surfaceContainer`, with 28 dp top corners and padding 10 / 16 / 22 plus the gesture inset. Two rows:
1. **Four labelled actions**, evenly spaced. Each is a 56 dp tall button with a 24 dp icon (onSurfaceVariant) over a labelMedium label:

   | Action | Icon | Opens |
   |---|---|---|
   | Share | `share` | Android's share menu |
   | Add to | `library_add` | the reel picker |
   | Move | `drive_file_move` | the reel picker |
   | Remove | `playlist_remove` | the existing confirm with Undo |

   With nothing chosen they are off (38 %, not focusable as actions).
2. **Edit {n} clips**, a large filled button, 56 dp, full width: the `movie_edit` icon, then "Edit {n} clips", then the length at 80 % in tabular figures.
   - It opens the editor sheet with the chosen clips in shooting order, and **choosing ends** when the editor is picked.
   - With nothing chosen it reads "Tap the clips you want to edit" and is off (surfaceContainerHighest / onSurfaceVariant).
   - Accessible name: "Edit 3 clips, 1:38".

**During an editing session** (R1): the Edit button is replaced by a note with an `info` icon: "This reel is being edited in VN. Tap Done editing at the top before sending clips again." The four actions stay.

**Large text:** the four actions go two by two.

**The page:** its last row is padded so the bar never hides a clip (about 190 dp). **Snacks** ("Sent 3 clips to Instagram Edits", Undo snacks) float above the bar.

**Back and Close** end choosing first (unchanged).

## 3. The picking screen keeps only add mode

`edit_select_screen.dart` (`Routes.editSelect`) is now reached only in **add mode** (`&add=1`), from the editing banner's **Add more clips** / **Copy to VN folder** / **Add to your … project** (D-128, D-129). Add mode is unchanged.
- Remove the normal mode, its strings ("Pick clips to edit", "Tap the clips you want to edit" bottom bar, Continue), its route parameters and tests.
- Hub screen 18 is retitled "Add clips to a VN edit".

## After picking an editor (unchanged)

- **CapCut / Instagram Edits:** the snack "Sent {n} clips to {editor}", then the "Mark as Ready to edit?" prompt if the reel is Collecting.
- **VN:** the space check (screen 20) with those clips.
- **Other app…:** Android's share menu.

## New strings

| Where | Text |
|---|---|
| Editor sheet title, every clip | Edit all {n} clips in… |
| Editor sheet, switch to choosing | Choose clips instead |
| Editor row pill | Last used |
| Top bar, nothing chosen | Choose clips |
| Top bar, every clip chosen | Clear |
| Dock button | Edit {n} clips |
| Dock button, nothing chosen | Tap the clips you want to edit |
| Dock actions | Share · Add to · Move · Remove |
| Hint banner | Tap the clips you want to edit / Next time, hold a clip to start choosing straight away. |
| During a VN edit | This reel is being edited in VN. Tap Done editing at the top before sending clips again. |

## Code to change

- `app/lib/features/reels/views/reel_detail_screen.dart`:
  - `_selectionBar` loses the three action icons and the ⋮ (`_SelectionAction`). It gains Select all / Clear.
  - Add the `TtSelectionDock` while choosing.
  - **Edit video** calls `showEditorSheet(…, allClips: true)` instead of `Routes.editSelect`.
- `app/lib/features/reels/view_models/reel_selection.dart`: `start(fromSheet: true)` keeps choosing when empty; `clear` / `selectAll` as today.
- `app/lib/features/editors/views/editor_sheet.dart`:
  - the `allClips` title and **Choose clips instead**;
  - `lastEditor` first, with the pill;
  - storing `lastEditor` on pick.
- `app/lib/features/editors/views/edit_select_screen.dart` and the router: add mode only.
- **taketray_ui:** new `TtSelectionDock`, with goldens in light and dark at 1× and 2×.
- `docs/flow.md`: the reel page's choosing and the editor handoff sections, in the same commit.

## Tests

- **Widget tests:**
  - Edit video opens the sheet with every live clip (missing clips left out), in shooting order, titled "Edit all {n} clips in…".
  - Choose clips instead starts choosing with nothing chosen and the hint; the dock's Edit is off until a clip is chosen; un-choosing to zero keeps choosing.
  - Holding a clip starts choosing with that clip, and un-choosing the last one ends it.
  - Edit {n} clips opens the sheet with exactly the chosen clips, in shooting order.
  - Picking CapCut ends choosing and shows the snack.
  - Select all becomes Clear, and Clear empties.
  - During a VN session the dock shows the note and no Edit.
  - The last-used editor is first and has the pill; not installed loses it.
  - Snacks sit above the dock.
- **Goldens:** the dock (some chosen, none chosen, VN session) and the sheet (every clip, chosen clips, last used), light and dark, 1× and 2×.
- **On the S24, by hand:** send a whole reel to CapCut in two taps; hold, choose three and send to Edits; Choose clips instead, then VN.
