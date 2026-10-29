# Parked work

Items that reviews found and parked for a later phase. When a phase is planned, read its section and put each item into a task (or say in the plan why it is dropped). Delete an item once it is done.

Sources: the Phase 1 task reviews and its final whole-branch review (2026-10-26), and the Phase 2 task reviews and its final whole-branch review (2026-10-27).

## Phase 4

- Phase 3 left these (D-76):
  - `TtListRow` has no disabled state: the "Add earlier videos" sheet fakes it with an `Opacity` and a disabled semantics node. Add one to `taketray_ui` (`.li.dis`, opacity 0.45, announced disabled) and use it there.
  - `openCamera()` returning false (no camera app, or the call failed) shows nothing. Needs copy for a snack; the owner approves it.
  - "On since {time}" and "Shooting since {time}" are built once per build, so they do not change at midnight until something redraws the screen. Rebuild the card at the next local midnight (a timer, or a clock provider that ticks).
  - `TtShootingModeCard.referencesRow` also holds the "Add earlier videos" row. When References land, decide how the two rows share the card (the owner's design).
- Reel description has no length limit at the repository (D-56). The create/edit form should cap it; record the cap in a decision.

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
- Widgetbook tests, when screens grow the catalogue:
  - `widgetbook/test/catalog_use_cases_test.dart` taps each use case but never checks the tap selected it. After the pump, add `expect(WidgetbookState.of(tester.element(find.byType(Scaffold).first)).useCase?.name, name)` (checked in a scratch copy during the Phase 2 Task 3 review).
  - `widgetbook/test/catalog_coverage_test.dart` (`_unregisteredFiles`) is satisfied by any one registered class in a file, so a second widget added to a registered file goes unnoticed. Check per class, with an allow-list of classes that are deliberately not in the catalogue.

## Phase 5 (tagging and the player)

- Phase 3 left these (D-76):
  - The time on a To tag tile is in the phone's time zone. Show it in the zone the clip was shot in (`Clip.timeZoneId`, D-58).
  - To tag has no error state when its list stream fails (a database error): skeletons stay. Needs copy and a design for an error state.
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

## Before the first schema change (v2)

- `tool/check_generated` must also hash `app/lib/data/database/app_database.steps.dart`, which `make-migrations` writes from v2. At v1 it also never regenerates `app/test/drift/.../generated/`.

## Phase 8 (editor handoff)

- Sanitise a reel name before using it as a VN folder name (`/`, `:` and other characters Android storage rejects); `uniqueFolderName` only handles clashes.

- Removing a clip from a reel during a VN session (or deleting it as an orphan) must delete its VN copy file first. The `vn_copies` row survives the clip (D-54), so the storage screen can still find the file, but the normal flow should not rely on that.

## Phase 9 (references)

- The share handler must take the first `http(s)` URL out of shared text before calling `ReferencesRepository.add`: TikTok and YouTube share text such as "Title https://vm.tiktok.com/…", and `normalizeReferenceUrl` rightly refuses anything with a space in it.
- The reference card's "Open" button takes half the row at 2×.
- The banner margin is not configurable (`refs.js` overrides it).

## Phase 10 (onboarding and settings)

- The Export/Import buttons: decode and validate the backup JSON off the UI isolate (`compute`/`Isolate.run`) so a large file doesn't freeze the screen; show "X of Y clips found" after the media check.

- When the Settings screen watches `SettingsRepository.watch()`, a corrupt stored value logs its "Setting … is corrupt" warning on every emission, not once. Log it once per key (or repair the row on first read).

- The reminder-time form must keep `eveningReminderMinutes` within 0 to 1439 itself: `AppSettings` does not check it, and `SettingsRepository.save` throws `ArgumentError` for anything else.

- `.ib.tonal` icon button.
- `TtListRow` tall and disabled variants.
- The disabled-on `TtSwitch` tick is at full opacity.

## Phase 11 (polish and release)

- `design/tools/build_tokens.py --check` scans only `design/tokens/colour-options/` and `design/handoff/compose/` for orphans. Add `packages/taketray_ui/lib/src/tokens/` (it holds only `tokens.g.dart`) to `GENERATED_DIRS`.
- Release as an app bundle or split per ABI (the APK is 48.9 MB for 3 ABIs).
- Build warnings: CupertinoIcons not bundled, and the Patrol plugin applies KGP.
- `TtGlass`: the shadow bleeds through the translucent fill.
- Wrapped two-line buttons need more vertical padding. The `TtSwitch` focus highlight is taller than the track.
- `TtThemeData` value equality; badge `TextPainter` re-measures on every build.
- The theme doc should steer feature code to `Tt*` widgets, since stock Switch, Checkbox, TextField and AlertDialog are not themed.
