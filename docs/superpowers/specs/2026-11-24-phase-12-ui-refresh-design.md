# Phase 12: UI refresh: glass everywhere and the full-screen tag player (design)

Date: 2026-11-24 · Owner-approved (2026-11-24, "yes design approved") · Builds on D-171 and its handoff (`design/handoff/tag-player-full-screen.md`), the prototype's glass rules (`design/prototype/assets/tt-style.css`, `player2.css`), and a blur audit of design against app (2026-11-24; its findings are folded in below).

## Intent

The owner compared the app on the S24 with the design and found that much of the design's frosted-glass look is missing. For example, the page behind a dialog (hub screens 9 "Delete reel" and 14 "Skip all") is blurred in the design but looks merely dimmed on the phone. The owner's words: "I want it everywhere just like our design". The owner has also redesigned the tag player (D-171): the clip fills the screen, the reels sit in a dock, Skip and Same are glass buttons on the right, and you swipe up and down.

Both are UI-only and both rely on the same glass pieces, so they are one phase. It merges before Phase 13 (photos, option B, agreed 2026-11-24). Phase 11 (release prep) stays last, as Phase 10 came before Phase 9 (D-134).

## Goals

- Every blur drawn inside the phone in the design exists in the app with the design's values, light and dark, and is **visible on the S24** (owner's side-by-side check against the prototype).
- The tag player matches D-171's handoff in every state on hub screen 12, with the session logic (D-96) unchanged.
- CI proves each blur by its pixels, not only that a `BackdropFilter` widget exists, so a lost blur fails a test.

## Non-goals

- Subscription screens (D-170), photos (Phase 13).
- Android's own UI: the notification shade and the permission dialogs (their blur in the hub is Android's look, not ours).
- Glass on panels that are solid in the design: sheets, dialogs and menus have solid fills there; only what is **behind** them blurs. The hub page's sentence "sheets, dialogs, menus and toasts float with blur" overstates this; the CSS is the authority.
- Restyling the one Material dialog that is not in the design (the reminder time picker). Parked in `docs/later.md`.
- Any change to tagging logic, Undo, Pick several or the "All done!" screen.

## Anti-goals

- The clip in the tag player is never blurred (D-171), and the old blurred stage goes.
- Glass must not cost smoothness: each `BackdropFilter` sits in a clip of its own size (no full-screen blur except the modal scrim and the menu layer), and the tag player keeps 60 fps on the S24 while swiping.
- Text on glass and scrims keeps AA contrast (the handoff's worst cases: 6.4:1, 10:1, 7.8:1).
- No new permissions; `tool/check_release_permissions` still ends `RELEASE PERMISSIONS OK`. No third-party plugins.

## Constraints

- Stack and process as in Phase 9: `tool/flutter`, Riverpod 3, go_router, Pigeon, Kotlin platform APIs only; strict TDD with every edge case red first and mutation checks; goldens light and dark (app goldens macOS-only, package CI goldens via the "update goldens" workflow); Patrol flows written and reviewed before the phone; the phone is the last step; `docs/decisions.md` and `docs/flow.md` updated with the code; learning guide `docs/learn/phase-12-ui-refresh.md`; README row at the end.
- Values come from the CSS and the handoff, never eyeballed. Metrics live in `TtMetrics` with the CSS line they copy, as today.

## Approaches (decided)

1. **One phase, one branch, one PR; glass first, then the tag player** (owner agreed the outline, 2026-11-24). The player's chips and rail reuse the glass pieces, so they are built and proven first.
2. **The faint dialog blur: find the cause before changing anything.** The code already blurs behind every dialog and sheet with the design's values (3 dp, black at 50 %, `ttBlurredBarrier` in `dialog.dart` and `sheet.dart`), and every app dialog and sheet goes through it. Nothing in the code explains why it can't be seen. The first task proves where it goes wrong, with these checks on the S24 (debug build of TakeTray Dev):
   - Does the nav pill's blur (18) show over scrolling content? Does the reel card pill's (8)?
   - The sigma the barrier actually uses, logged once (a number only, D-10).
   - The same dialog with Impeller off (`--no-enable-impeller`).
   - The same dialog with the sigma temporarily at 12.
   The fix follows the evidence: a renderer problem gets a workaround (and a Flutter issue link); a "real but too subtle" result is shown to the owner next to the prototype, and the owner sets the strength. This needs the phone once, early (see "For the owner").
3. **Blur behind open menus: yes.** In the design the whole page blurs 3 px behind an open menu, without dimming (the scrim is made transparent, but its blur stays). It may have been a CSS side effect, but the owner wants the design everywhere, so it is built. `MenuAnchor` has no barrier, so menus open through a TakeTray menu route whose barrier is the blurred scrim with a transparent colour. Tap outside and Back still close it, and keyboard and TalkBack behave as today.
4. **The share screen over Instagram blurs too (amends D-167).** D-167 said there was nothing of ours behind the see-through window to blur. Android 12 and later can blur whatever is behind a window (`windowBlurBehindEnabled` with a radius). `ShareActivity` turns it on when `WindowManager.isCrossWindowBlurEnabled` is true, at the design's 3 dp, and listens for the phone turning it off (battery saver), falling back to the dim alone, as today. Older Androids keep the dim alone.
5. **Snackbar glass (amends D-48).** `TtSnack` gets the design's 12 px blur under its 94 % fill, clipped to its shape. Where the snack's fade hides the blur mid-fade, the resting state is what must match.
6. **Nav pill:** add the design's `saturate(1.4)` (a saturation `ColorFilter` composed with the blur), and stop its drop shadow showing through the glass (the shadow is painted only outside the pill, as CSS does).
7. **The tag player is built from the D-171 handoff**, which is this part's spec: the full-screen stage (cover, or contain when covering trims more than 20 %), top and bottom scrims, the dock with up to three Collecting reels, New reel and All reels, `TtRailButton`, the `onVideo` reel chip, vertical swipes and slides, the large-text and accessibility rules. The old `TtTagPanel` blur, the stage `ImageFiltered` blur and their metrics (`tagPanelBlur`, `tagStageBlur`, `tagStageBlurScale`, `tagStageVideoShadowBlur`) are deleted. `TtTagPanel` itself goes if nothing else uses it.

## What the phone showed (2026-11-24, owner's eyes, throwaway test build of TakeTray Dev)

The test build drew sharp black and white stripes, with each blur over them. The renderer was Impeller on Vulkan (Adreno), and the screen scale was printed on screen.

| Test | Owner saw |
|---|---|
| D: a plain `BackdropFilter` box, sigma 3, clipped | soft |
| E: the nav pill's `TtGlass`, 18 | soft |
| F: `TtStatusPill(onMedia: true)`, 8 (the reel cover pill) | **sharp** |
| K: a plain 24 dp `ClipRRect` + `BackdropFilter` 8 box over a `Container` fill | soft |
| T: `TtGlassPill` ("Editing in VN"), 8, with a `ColoredBox` inside | soft |
| A: `showTtDialog`, today's ramped blur 3 | **only darker** |
| J: the same, wrapped in a `ClipRect` | **only darker** |
| G: `showTtDialog`, ramped blur 6 / B: ramped blur 12 | soft / soft |
| H: a whole-screen plain `BackdropFilter` 3 in a see-through page route | soft |
| S: a `DialogRoute` with a steady `BackdropFilter` 3 barrier and a plain `Card` | soft |
| Q: a `PopupRoute` using Flutter's own `filter:` blur 3 | soft |
| U: `showTtDialog` with the blur held steady at 3 (no ramp) | soft |
| V: a plain `Card` dialog with the same ramped blur 3 as `ttBlurredBarrier` | soft |

The barrier's sigma was logged at rest: `3.0` with the animation at `1.0`.

**What this shows:**
- **The renderer blurs correctly at 3** (D, H, S, Q, U).
- **The dialog scrim fails only when the ramped blur meets the TakeTray dialog** (A, J). Held steady, the same dialog is soft (U); with a plain card, the same ramp is soft (V). Why the two together lose the blur is not known. The ramp ends at the right sigma.
- **So the fix is a steady scrim blur** for every dialog and sheet, with the dim alone fading in, or Flutter's own route `filter`. It is proven on this phone; the side-by-side at the end confirms it on screens 9 and 14.
- **The reel cover pill (F) is a second bug.** Its `BackdropFilter` has a `Material` child, and the same values with a `ColoredBox` child blur (K, T). It is rebuilt like `TtGlassPill`: a `ColoredBox` fill, with the ink on a transparent `Material`.
- **The other glass pieces that have a `Material` or ink child are checked the same way** in the glass task.

Approach 2 is settled by this; the hard gate in call 1 below is met.

## Calls made after the builder check (mine; the owner can change any)

1. **The diagnosis is a hard gate.** No glass task starts until it has a result, because the menu layer, the snack and the player's glass all use the same blur mechanism. If the cause is a renderer bug with no direct workaround, the scrim falls back to a blur that doesn't need the live backdrop: a snapshot of the page, taken as the dialog opens and blurred as an image. If that fails too, I stop and bring it to the owner. If the owner sets a stronger strength after the side-by-side, it applies to the blurs that share the design's 3 px (the dialog and sheet scrim, the menu layer and the share window), not to the glass pieces, which keep their own design values unless the same check shows them faint as well.
2. **The device proof is the owner's eyes.** The phone rules allow no screenshots, so the on-phone proof is the diagnosis plus the owner's side-by-side check. CI's pixel tests guard against regressions in code.
3. **Menus:** the menu layer blurs whatever is under it. That includes the app bar and the nav pill, as in the design, where the layer covers the whole screen inside the phone frame. It also includes a sheet, when the menu opens inside one, so the two blurs stack. Like the dialog scrim today, the layer covers the status bar's area too.
4. **The share window:** Flutter's 50 % dim stays and Android's window blur is added under it. The design's 3 dp is converted to Android's blur radius with Android's own sigma-to-radius rule at the phone's density, and the owner checks it by eye.
5. **Swiping in the tag player:** the clip coming in shows its thumbnail (the frame the clip tiles already use) while the finger moves. The real player takes over when the swipe settles. The next clip's player is already open (D-96), and the previous one opens on arrival, as Undo does today.
6. **Scrim timing:** the end state must match the design. The blur's ramp follows the same curve as the dim (today it is linear while the dim eases), so the two arrive together.

## What already matches (kept, and covered by the new pixel tests)

Reel card status pill and "Editing in VN" pill (8), reel card references badge (8), Shooting mode card icon tile (8) and references row (6), the nav pill's blur, fill, hairline and radius (18).

## Testing

- **Pixel tests for glass.** Each blur is drawn over a sharp striped background and compared with the same background unblurred: the area behind the glass must lose its sharp edges, with the design's sigma (asserting the `ImageFilter` values too). This covers the dialog and sheet scrim, the menu layer, the snack, the nav pill (with saturation), the reel card pills and badge, the Shooting mode tile and row, and the new rail button and dock chips.
- **Goldens:** the components in light and dark; screen 12's states from the handoff (dark, 1× and 2× text); the menu open over a page; a dialog over the reel page.
- **Widget tests:** the handoff's list (vertical swipes on and back, horizontal does nothing, ‹ › at the ends, the dock's three reels and when All reels shows, tagging from All reels, the snack clear of the rail, the cover-or-contain sum for 9:16, 16:9, 1:1 and 3:4, one column at large text); the menu closes on outside tap and Back; the share screen asks for window blur only when Android allows it (Robolectric for the Kotlin side).
- **Patrol (S24):** the existing tagging flows updated to the new player (swipes, dock, rail), written and reviewed before the phone.
- **Hand checks on the S24:** each glass element side by side with the prototype (the owner judges); a day's clips tagged one-handed; a horizontal clip; a very bright clip; the back gesture from both edges; a share from Instagram with blur on and with battery saver on.

## Left to the builder

- How the menu route positions itself against its anchor (it must match today's menu placement).
- How the shadow is kept out of the nav pill's glass.
- How the pixel tests measure "blurred" (any robust measure, such as edge contrast across the stripes, with a threshold that a missing blur fails and the real one passes).
- File and component names beyond those the handoff names.

## For the owner

- **The early phone visit is done** (2026-11-24, above). The phone is next needed at the end, for the Patrol flows and the side-by-side hand checks.
