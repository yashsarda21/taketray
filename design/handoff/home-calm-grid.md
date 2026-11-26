# Home, the calm grid: handoff

Owner's pick, 25 Nov 2026 (D-187). The owner liked Home but wanted it "clean to use and smooth to feel". Of three options (A calm grid, B shelves, C list), the owner chose **A**. It includes D-186 (no "N clips to tag" strip).

**Where to see it:**
- **Hub:** screen 6, every state. The last state is the previous Home, for comparison.
- **Prototype:** any flow, then the Reels tab.
- **Source:** `design/prototype/assets/home2.js` and `home2.css`.

## What changes

| Part | Before | Now |
|---|---|---|
| Shooting mode card, on | Media block: title row, Open camera, References row, Add earlier videos row, marigold "N clips to tag" strip (about 190 dp) | **One row** (REC dot, "Shooting", "Since 9:12 am", switch), then **Open camera** and up to two quiet chips, **References · 4** and **Earlier videos** (about 120 dp) |
| Shooting mode card, off | Grey card with a two-line explanation, plus a separate marigold "N clips to tag" banner when clips wait | **One row**: "Shooting mode" over "Off · 23 clips still to tag", or "Off · turn it on before you film"; no separate banner |
| New reel | Extended FAB over the reels | **"+ New"** tonal pill in the header |
| Filters | Outlined filter chips | **Quiet tabs**: the chosen one filled, the others plain text |
| Reel card | Status pill, VN pill and reference badge on the cover | **The cover alone**; under it the name, one status mark, details, and a line only when it applies |

The count of waiting clips is on the To tag tab's badge (Phase 12, D-184 on `phase-12-ui-refresh`).

## Layout (360 dp)

**Header:**
- The big "Reels" title (headlineMedium).
- On the right, **+ New**: a tonal pill (secondaryContainer / onSecondaryContainer), 40 dp tall with a 48 dp target, the `add` icon 20 and the labelLarge text "New", 12 dp from the edge.
- It opens the New reel form.

**The access banner**, when access isn't full, sits above the card (unchanged).

**Shooting mode card:** margins 4 / 16 / 12, radius 24.

**Off:** `surfaceContainerLow`, padding 10 / 6 / 10 / 12, one row:
- a 40 dp rounded-square icon (secondaryContainer, `videocam` 22);
- "Shooting mode" (titleMedium) over the line (bodySmall, onSurfaceVariant): "Off · {n} clips still to tag", or "Off · turn it on before you film";
- the switch.

**On:** black with the latest clip at 55 % and the existing brand gradient (160°: primary-dark 86 %, then 40 %, then black 55 %). Padding 12, gap 12.
- **Row 1:**
  - the icon on 16 % white glass, with the live REC dot at its corner;
  - "Shooting" (titleMedium, weight 800) over "Since 9:12 am" (white at 85 %), plus " · Manual mode" when access isn't full;
  - the switch (inverse).
- **Row 2** (wraps), gap 8:
  - **Open camera**: a white pill, 40 dp, `videocam` 20 + labelLarge, black text.
  - **References · {n}**: shown when Collecting reels have references. It opens the References sheet.
  - **Earlier videos**: shown when access is full and nothing was added this session. It opens Add earlier videos.
  - The two chips are glass: 14 % white with a blur of 10, white text, `link` / `history` 18.

**Tabs:**
- "All {n} · Collecting {n} · Ready {n} · Published {n}".
- Each is a 40 dp pill (48 dp target) with 14 sides and labelLarge text; the count is tabular, at 80 %.
- The chosen one is filled secondaryContainer; the others are transparent and onSurfaceVariant.
- They scroll sideways in one row with padding 0 12 and no scrollbar.
- **An empty tab:** "No reels marked {status} yet." and **Show all reels** (tonal).

**Grid:** two columns, padding 0 16, gaps 16 (rows) × 12 (columns), aligned to the top.

**Reel card** (one button, its accessible name below):
- **The cover:** full width, 3:4, radius 20, **nothing on it**. A reel with no clips shows `movie` 28 on surfaceContainerHigh.
- **Under it**, padding 0 4, gap 2:
  1. the name (titleSmall, up to 2 lines);
  2. **the status mark**: a 14 dp filled icon and labelMedium onSurfaceVariant. The icon carries the colour (Collecting `radio_button_checked` in error, Ready to edit `content_cut` in tertiary, Published `check_circle` in primary); the word is always there;
  3. "{n} clips · {length}", or "No clips yet" (bodySmall, onSurfaceVariant, tabular);
  4. **only when it applies**, a wrapping line (labelSmall):

     | Item | Icon | Colour |
     |---|---|---|
     | In VN | `folder_copy` | primary |
     | {n} missing | `error` | error |
     | {n} references | `link` + the number | onSurfaceVariant |

**Large text (≥ 1.5):** one column.

## Smooth to feel

| Moment | Motion |
|---|---|
| Scrolling | The big "Reels" title shrinks into the app bar (Flutter `SliverAppBar.large`); + New stays in the bar. |
| Pressing a card | Scale to 98 % over `short3` with the standard easing, and back. |
| Opening a reel | Container transform from the card (400 ms, unchanged). |
| Switching tabs | The grid crossfades (`short4`); nothing slides sideways. |
| The card switching on or off | Its height animates (`medium2`, emphasized), and Open camera and the chips fade in. |
| Covers loading | Fixed 3:4 boxes with a skeleton, so nothing jumps. |
| Reduced motion | Crossfades only. |

## Accessibility

- **Reel card:** one button, named "London Food. Collecting. 14 clips, 2 missing. Editing in VN. 2 references". The separate reference badge button goes; the card's name says it, and the reel page has the section.
- **The tabs:** a group named "Show reels"; each tab is a toggle with `aria-pressed` and its count.
- **+ New:** named "New reel".
- **The chips** keep their full names ("References, 4, from your Collecting reels"; "Add earlier videos, shot before Shooting mode was on").
- **Contrast:** status words are onSurfaceVariant on surface (AA). The glass chips and white text sit on the dark card (AA, as in Phase 12's glass rules).

## Code to change

- `app/lib/features/reels/views/reels_screen.dart`:
  - the header gets **+ New**;
  - the FAB goes;
  - tabs replace the filter chips;
  - the separate To tag banner goes.
- `app/lib/features/shooting_mode/views/shooting_mode_section.dart`: the compact layout.
  - On: a row, then the Open camera pill and chips instead of `rows`.
  - Off: one row with the count line.
  - No `toTagStrip` (D-186).
- **taketray_ui:**
  - `TtShootingModeCard` gets the compact layout. Keep the glass from Phase 12 (`TtGlassFill`).
  - `TtReelCard` becomes the calm card: no overlays, plus the status mark and the optional line.
  - A `TtPillTabs` for the quiet tabs, if the existing pill tabs don't already match.
  - Remove the reference badge from the card.
- **Strings:**

  | Where | Text |
  |---|---|
  | Header button | New |
  | Card, on | Shooting · Since {time} |
  | Card, off | Off · {n} clips still to tag / Off · turn it on before you film |
  | Card chip | Earlier videos |
  | Empty tab | No reels marked {status} yet. · Show all reels |
- `docs/flow.md`: the Reels tab section, in the same commit.

## Tests

- **Goldens:** every state on screen 6, light and dark, 1× and 2×.
- **Widget tests:**
  - + New opens the form;
  - the tabs filter, and an empty tab offers Show all reels;
  - the card's chips show only when they apply;
  - the off line counts waiting clips;
  - no strip and no banner;
  - the card's accessible name includes the references.
- **On the S24, by hand:** scroll (the title collapses smoothly), press cards, switch Shooting mode on and off, and check that 20+ reels scroll at 120 Hz without dropped frames.
