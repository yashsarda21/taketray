# Tag player, full screen: handoff

Owner's pick, 24 Nov 2026 (D-171). This replaces the tag player layout of D-97 (screen 12 v1).

**Where to see it:**
- **Hub:** screen 12, every state. The last state is the old design, for comparison.
- **Prototype:** Start from: "Tag a day's clips".
- **Source:** `design/prototype/assets/player2.js` and `player2.css`.

**Why:**
- The owner found the old player awkward.
- A vertical clip showed at 203 × 360 on a 360 × 800 screen, a quarter of it, between blurred copies of itself.
- Four bands of controls sat under it: the scrub bar, Skip and Same as previous, the panel header, and the reels.

Three layouts were tried: A full screen, B clip card, C trays. The owner chose **A** and dropped B and C.

**What does not change:**
- The session logic (`TagSessionController`, D-96).
- Tapping a reel: a tick for 400 ms, then the next clip.
- Long press, Pick several (sticky, D-91), Same as previous, Skip, and Undo on the snack.
- Opening one clip ahead.
- Close and Back.
- "All done!".

**Only the layout, the gestures and two small components change.**

## Layout (360 × 800, edge to edge)

**The root is a `Stack`, always dark on black (`VideoTheme`), under the status bar**, so the status bar's light icons sit on the top scrim. It holds three layers, back to front:

| Layer | What | Position |
|---|---|---|
| Stage | The clip (rules below) | fills the screen |
| Top | Progress segments, Close, ‹ "3 of 23" + scene line ›, Mute | top; padded by the status bar inset |
| Dock | Skip / Same rail, snack, scrub line, header, reels | bottom; padded by the gesture bar inset |

### The clip

**Vertical clips cover the screen** (`BoxFit.cover`, centred), as in Instagram Reels. On a 20:9 phone a 9:16 clip loses about 9–10 % at each side.

**If covering would trim more than 20 % of the clip**, show it whole (`BoxFit.contain`) on black. This is the case for horizontal, square and 3:4 clips.
- Trimmed fraction: `crop = 1 − min(screenW / (clipW × s), screenH / (clipH × s))`, with `s = max(screenW / clipW, screenH / clipH)`.
- A contained clip is centred in the space above the dock, not behind it.

**Never blur.** Remove the stage's `ImageFiltered` blur and these metrics:
- `TtMetrics.tagStageBlur`
- `TtMetrics.tagStageBlurScale`
- `TtMetrics.tagStageVideoShadowBlur`

**Taps and states** (unchanged):
- A tap plays or pauses. Paused shows the 64 dp play disc.
- Loading shows the spinner.
- "This video can't be played" shows as before.

### Top

**Scrim:** `LinearGradient` (top → bottom). Black at 78 %, then 70 % until 24 dp above the bottom of the area, then transparent.

**Contents:**
- `TtSegmentBar`: margins 16, height 3.
- A 56 dp row:
  - Close (`TtIconButton`, `onVideo`).
  - In the middle: **‹** (Previous clip), the title and **›** (Next clip). The title is "{i} of {N}" in titleSmall, over the scene line "Scene {s} of {S} · {range}" in bodySmall, white at 82 %. The scene line **wraps, never cuts**.
  - Mute.
- ‹ › are 48 dp icon buttons. At either end of the session they are dimmed to 35 % and announced as unavailable.

### Dock

**Scrim:** `LinearGradient` from transparent, to black at 74 % at 26 dp, then 90 % from halfway down.

**Padding:** 28 top, 12 sides, 22 bottom plus the gesture inset.

**Gap between rows:** 8.

**Rows, top to bottom:**
1. **Scrub line.** The existing scrub bar. It turns large, with "Drag to skim", over 2 minutes.
2. **Header**, 40 dp:
   - "Add to reel" (titleSmall).
   - **Pick several**, a text button with the `library_add_check` icon, shown only when there are 2 or more reels.
   - **All reels**, a text button with the `apps` icon, shown when there are more than three Collecting reels or any other reel.
3. **Reels:** 2 columns, gap 8.
   - Up to three Collecting reels, newest first (`orderedReels`), then **New reel**.
   - Chips are `TtReelChip` with a new **`onVideo` style**:
     - glass: `Color(0xD61E2024)` (rgba 30, 32, 36, .84) with a `BackdropFilter` blur of 14;
     - white text, and the count in white at 78 %;
     - 52 dp tall, with a 30 × 40 cover;
     - the done and picked colours unchanged.
   - New reel: the same glass at 55 %, with a 1.5 dp dashed white border at 55 %.

**No reels:** "You don't have any reels yet. Create one and this clip goes into it." Then a full-width New reel.

**Pick several:**
- The header becomes "Pick reels", All reels and Cancel.
- The grid is the first three Collecting reels plus any reel picked from All reels.
- Footer: "Add to {n} reels & next" (filled, full width).
- The rail is hidden.

### Skip and Same as previous (the rail)

**New `TtRailButton`** (taketray_ui):
- 64 × 64, radius 20.
- Glass `Color(0xBD121316)` (rgba 18, 19, 22, .74) with a blur of 12.
- Icon 24.
- Label in labelMedium. Optional second line in labelSmall, white at 85 %, one line, ellipsis.

**Placement:** two of them, 10 apart, 12 dp from the right edge, with their bottom 4 dp above the dock's top.

| Button | Icon | Label | Second line | When off | Accessible name |
|---|---|---|---|---|---|
| Skip | `redo` | "Skip" | — | — | "Skip this clip" |
| Same | `repeat` | "Same" | the reel names | Nothing tagged yet: 45 % opacity | "Same as previous: {names}" / "Same as previous: nothing tagged yet" |

### Snack

"Added to London Food · Undo" and "Skipped · Undo" are floating snacks just above the dock, inset 12 on the left and **88 on the right**, so they never cover the rail. Measure the dock's height with a `LayoutBuilder` or `GlobalKey`; don't hard-code it.

### All reels (sheet)

A `TtSheet` in `VideoTheme`, with:
- the title "Add to reel" ("Pick reels for this clip" while picking);
- "Collecting" with its chips, New reel, then "Other reels" with its chips (Ready and Published);
- while picking: checkboxes and **Done**.

Tapping a reel in single mode closes the sheet, then tags as usual.

## Gestures

- **Swipe up: the next clip. Swipe down: the previous one.** Like Reels, and it never fights Android's side back gesture. Horizontal drags do nothing.
- The clip **follows the finger** while dragging (translateY, with the next or previous clip coming in). A drag over 64 dp, or a fling over 800 dp/s, goes. Less springs back with the standard easing.
- ‹ › do the same without a gesture (the gesture alternative). At the ends of the session the clip springs back.
- A tap on the clip plays or pauses. The progress segments are not tappable (unchanged).

## Motion

| Moment | Motion |
|---|---|
| Next (tag, Skip, swipe up, ›) | The current clip slides up and out (`short4`, emphasizedAccelerate). The next slides up from 16 % below and fades in (`medium2`, emphasizedDecelerate). |
| Previous (Undo, swipe down, ‹) | The mirror image: slides down from above. |
| Reduced motion | A 150 ms crossfade, no travel (as before). |

## Large text (font scale ≥ 1.5)

- The reel grid goes to **one column** and scrolls inside the dock, which grows to at most 260 dp of reels. Anything else is in All reels.
- The header wraps.
- The rail keeps its place and grows with its text.

## Accessibility

- The dock is a group named "Reels". The title and scene line are a polite live region (unchanged).
- **Focus order:** Close, Previous, the title, Next, Mute, the clip, Skip, Same, Pick several, All reels, the reels, New reel.
- **Contrast**, worst case on a pure white frame:

  | Text | Contrast |
  |---|---|
  | Scene line on the top scrim | 6.4:1 |
  | Dock text on the dock scrim | 10:1 |
  | Rail second line on its glass | 7.8:1 |

  Keep the scrims' stops as given: they are what makes these numbers true.
- **Targets:**

  | Control | Size |
  |---|---|
  | Icon buttons | 48 dp |
  | Rail buttons | 64 dp |
  | Reel chips | 52 dp tall, half the width |
  | Text buttons | 48 dp touch height |

## Code to change

- `app/lib/features/tagging/views/tag_player_screen.dart`:
  - `build` becomes the `Stack` above.
  - `_Stage` loses the blur, takes the cover or contain rule, and moves the swipe to the vertical axis (`_SwipeArea`, `_SlideIn`).
  - The Skip / Same row and `TtTagPanel` give way to the dock and the rail.
- **taketray_ui:**
  - `TtReelChip` gets an `onVideo` style.
  - New `TtRailButton`.
  - New `TtReelDock`: the header, grid and footer, with the large-text rules.
  - `TtPlayerHeader` gets optional leading and trailing chevrons around the title.
  - `TtTagPanel` stays only if anything else uses it; otherwise remove it with its goldens.
- `docs/flow.md` › "The tag player screen and All done": update it in the same commit.

## Tests

- **Goldens:** screen 12's states (first clip, just tagged, the tap moment, picking several, loading, a long clip, horizontal, no reels, All reels, paused), in the dark theme at 1× and 2× text.
- **Widget tests:**
  - a vertical swipe moves on and back, and a horizontal one does nothing;
  - ‹ › at the ends are off;
  - the dock shows at most three Collecting reels plus New reel, and All reels only when needed;
  - tagging from All reels closes it and tags;
  - the snack's right edge stays clear of the rail;
  - the cover or contain rule for 9:16, 16:9, 1:1 and 3:4 (unit-test the crop sum);
  - at large text the grid is one column.
- **On the S24, by hand:**
  - a day's clips, one-handed;
  - a horizontal clip;
  - a very bright clip, to check the text reads;
  - the back gesture from both edges, which must still leave the player.
