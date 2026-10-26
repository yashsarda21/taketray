# Parked work

Items that reviews found and parked for a later phase. When a phase is planned, read its section and put each item into a task (or say in the plan why it is dropped). Delete an item once it is done.

Sources: the Phase 1 task reviews and its final whole-branch review (2026-10-26).

## Before phase 2

- A freshness check for committed `*.g.dart` files.

## Phase 2 (with GitHub and CI)

- `tool/check`: stop using `$OLDPWD` to find the repo root. A member listed in both arrays runs twice.
- Add a test for the style check's `Duration(days:)` rule.
- `build_tokens.py --check` ignores unknown flags and can't detect orphaned outputs.
- `fixtureThumb` paths are relative to the working directory, so they break if CI runs from another folder.
- `expectTtAccessible` has negative tests only for the tap target.
- The Widgetbook coverage test checks the import, not that the component is registered in `ttCatalog`.
- The Widgetbook use-case test window (2400) is fragile.
- Doc comments hard-code token values. Fix them opportunistically.

## Phase 3

- `TtBanner`: assert that `onTap` and an action are not both set, since the action would nest a button.
- Banner and callout icons are always filled. Match each banner's prototype icon.

## Phase 4

- Decide the FAB contract: where it sits above the nav pill and how it lifts over a snack. Either a `TtNavPill.fabBottom(context)` helper or the shell hosts the FAB. Record the choice as a decision.
- App bar titles clamp at 1.5× text, so show the full reel name in the body at large text.
- `TtTextField`:
  - the error is not in the field's semantics
  - swapping the controller loses the text
  - the error icon doesn't scale

  Fix before the first form.
- Package-composed strings: progress `%`, the reel-card references badge fallback, the reference-card label and the text-field counter. Take them from the caller. Make `referencesSemanticLabel` required when the count is > 0.
- A font weight helper, so `fontWeight` and the `wght` variation come from one place.
- `TtMenuButton`: `onClose` calls `setState` during build when the window size changes (debug-only assert). Defer it to after the frame.
- Doc comments still say "glass circle" (`bar_scope.dart:4`, `tt_metrics.dart:23`).
- Status pill caret gap is 2 dp; the CSS says 6.
- At 2× text:
  - the missing tile truncates
  - the stat-strip action squeezes its text
  - on empty art, the reel card's status pill touches the film icon
  - the pill-tab overflow test can't fail
- Tests:
  - the fill-1 glyph, pressed colour and per-kind colours on buttons
  - `TtReelCard` accessibility beyond empty art
  - guarding the VN-mark start-only padding
- The shooting card needs a top-level semantics label. The icon-only `TtGlassPill` needs a semantics doc.
- Review the `TtCardRow` API: its look is currently chosen by `trailingText`.

## Phase 5 (tagging and the player)

- Scrub bar:
  - it reads `position / duration` as "slash"
  - its semantics lack `value` and `increasedValue`

  Fix before the player ships.
- Scrub row: it is 48 dp (the CSS says 22). Also: the quick-row padding, a redundant `SizedBox`, and the thumb sits half outside the gesture area.
- Video scrim: the tokens (.7 / .55, linear) disagree with the CSS (.78 / .6, solid). **The owner picks one.**
- `TtTagPanel`:
  - make it a semantics group
  - budget its height cap of up to 520 dp at large text
  - add the "Other reels" label, the empty state and the dashed "New reel" chip (R8)
- Before the dashed "New reel" chip, deduplicate the dashed-outline painters and the scrim widgets into `internal/`.
- The nav badge's spoken label drops the tab name ("7 clips to tag" instead of "To tag, 7 clips").
- The snack has no drop shadow. Add one or record why in D-48.
- Add `expectTtAccessible` to `video_surface_test`. Relabel or drop the reel-chip 164 dp scenarios that can't happen at 2×.

## Phase 9 (references)

- The reference card's "Open" button takes half the row at 2×.
- The banner margin is not configurable (`refs.js` overrides it).

## Phase 10 (onboarding and settings)

- `.ib.tonal` icon button.
- `TtListRow` tall and disabled variants.
- The disabled-on `TtSwitch` tick is at full opacity.

## Phase 11 (polish and release)

- Release as an app bundle or split per ABI (the APK is 48.9 MB for 3 ABIs).
- Build warnings: CupertinoIcons not bundled, and the Patrol plugin applies KGP.
- `TtGlass`: the shadow bleeds through the translucent fill.
- Wrapped two-line buttons need more vertical padding. The `TtSwitch` focus highlight is taller than the track.
- `TtThemeData` value equality; badge `TextPainter` re-measures on every build.
- The theme doc should steer feature code to `Tt*` widgets, since stock Switch, Checkbox, TextField and AlertDialog are not themed.
