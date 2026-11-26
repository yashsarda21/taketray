# Learning guide: Phase 12B, the edit flow and the calm Home

This guide explains the second half of Phase 12. After the glass and the full-screen tag player were done on the S24, the owner chose two more designs. The first makes sending clips to an editor faster: **Edit video** now opens the editor sheet at once with every clip of the reel, and choosing only some clips happens on the reel's own page, with a **dock** of labelled actions at the bottom and an **Edit {n} clips** button that says how long they are. The second makes Home calmer: one compact Shooting mode card, quiet tabs, a **+ New** pill in a header that shrinks as you scroll, and reel cards that are only a cover with the words under it.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The task sections follow the order the phase was built: the edit flow first (Tasks 1 to 5), then Home (Tasks 6 to 9), then the phone tests written without a phone (Task 10). After them come the deep dives that several tasks share, and the closing summary.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's are D-188 to D-197 (the owner's choice of the two designs is D-185 to D-187). The specs are `design/handoff/edit-flow.md` and `design/handoff/home-calm-grid.md`, and the hub's screens 6, 8, 18 and 19 show the result.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`. A test in the design system package runs with `cd packages/taketray_ui && ../../tool/flutter test <file>`; one in the app with `cd app && ../tool/flutter test <file>`.
- **Four words.** The **editor sheet** is the bottom sheet that lists CapCut, Instagram Edits, VN and Other app…. The **dock** is the bar that slides up at the bottom of a reel's page while you choose clips. A **chip** is a small rounded button on the Shooting mode card. **Glass** is a see-through panel that blurs what is behind it, as in Phase 12 (see `docs/learn/phase-12-ui-refresh.md`).
- **Every task section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.
- **Test-driven.** Every task wrote its edge-case tests first and saw them fail ("red"), then wrote the code, then broke the code on purpose to see that a test noticed (a "mutation check"). The "try it yourself" parts name some of those mutants.
- **Numbers come from the design.** Every size, colour and duration is a named constant (`TtMetrics.…`) with the line of the design's CSS that it copies written above it, so nobody has to guess a number from a picture.

## Contents

1. [Task 1: Choosing that stays on](#task-1-choosing-that-stays-on)
2. [Task 2: The editor sheet for every clip](#task-2-the-editor-sheet-for-every-clip)
3. [Task 3: The selection dock](#task-3-the-selection-dock)
4. [Task 4: The reel page, Edit video and the dock](#task-4-the-reel-page-edit-video-and-the-dock)
5. [Task 5: The picking screen is only for adding](#task-5-the-picking-screen-is-only-for-adding)
6. [Task 6: The compact Shooting mode card](#task-6-the-compact-shooting-mode-card)
7. [Task 7: The calm reel card](#task-7-the-calm-reel-card)
8. [Task 8: Quiet tabs, the New pill and the collapsing header](#task-8-quiet-tabs-the-new-pill-and-the-collapsing-header)
9. [Task 9: Home, the calm grid](#task-9-home-the-calm-grid)
10. [Task 10: The Patrol flows on the new controls](#task-10-the-patrol-flows-on-the-new-controls)
11. [Why the dock lives in the shell](#why-the-dock-lives-in-the-shell)
12. [A sheet that answers instead of navigating](#a-sheet-that-answers-instead-of-navigating)
13. [A phone habit, not a setting](#a-phone-habit-not-a-setting)
14. [Keeping a switch's focus through a layout change](#keeping-a-switchs-focus-through-a-layout-change)
15. [A grid whose rows fit their cards](#a-grid-whose-rows-fit-their-cards)
16. [What the phase leaves you with](#what-the-phase-leaves-you-with)

## Task 1: Choosing that stays on

### What we built

A small rule change in the object that remembers which clips of a reel are chosen (`ReelSelection`). Choosing now has a flag, `fromSheet`, that is true when it was started by **Choose clips instead** on the editor sheet. From the sheet, un-choosing the last clip no longer ends choosing; and a new action, `clearChosen`, empties the choice but keeps choosing on.

### Why TakeTray needs it

The person who taps **Choose clips instead** has just seen a sheet that said "all clips". An empty choice is the place to start picking from, not a reason to throw them back to the plain page. Before this task, choosing ended the moment nothing was chosen (the rule from Phase 4, D-88, still right for a long press: you held a clip, changed your mind, and un-choosing it again ends it).

### Key ideas

**1. One function decides what an empty choice means.** `toggle` and `_prune` (which runs when a chosen clip goes missing) both end in the same small function:

```dart
ReelSelectionState _after(Set<int> chosen) {
  if (chosen.isEmpty && !state.fromSheet) return const ReelSelectionState();
  return ReelSelectionState(
    selecting: true,
    selected: chosen,
    fromSheet: state.fromSheet,
  );
}
```

Both paths share it, so the rule cannot be right in one and wrong in the other. A test per path proves it.

**2. A flag that is part of equality.** `fromSheet` is in `==` and `hashCode`. If it were not, two states that differ only in the flag would count as equal, and Riverpod would not tell the page that the state changed.

**3. Which method takes the flag.** `begin({bool fromSheet = false})` is the way into choosing with nothing chosen (the sheet and ⋮ **Select clips**); `start(id)` is the long press, which is never from the sheet. While already choosing, `begin(fromSheet: true)` keeps the chosen clips and sets the flag, and a plain `begin()` changes nothing.

### Where it lives

- `app/lib/features/reels/view_models/reel_selection.dart` and its generated `.g.dart`.
- `app/test/features/reels/view_models/reel_selection_test.dart` (35 tests; 16 are new).

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/reels/view_models/reel_selection_test.dart
```

Then break it: make `clearChosen` call `clear()`. A test notices that choosing ended.

### Decisions

- D-188 (amends D-88).

## Task 2: The editor sheet for every clip

### What we built

The editor sheet got three things. It can be opened for **every clip of a reel** ("Edit all 5 clips in…") and then has a **Choose clips instead** button. It puts the **editor you used last first**, with a **Last used** pill. And it no longer closes the page under it when it sends clips: it returns an answer, and the caller decides what to do.

### Why TakeTray needs it

The owner's design sends a whole reel to the editor in two taps (Edit video, then CapCut). Before, Edit video opened a picking screen where you ticked clips and pressed **Continue**, which is four taps for the common case. The last-used editor saves the habit one more look.

### Key ideas

**1. Order and pill follow each other.** `editorRows` puts the last pick first and says whether to show the pill. If the last editor is not installed any more, it goes back to its normal place with no pill, so the list never says "Last used" about a row the person cannot use:

```dart
EditorRows editorRows(EditorPick? last, List<EditorChoice> choices) {
  const defaults = EditorPick.values;
  final installed =
      last != null &&
      (last == EditorPick.other ||
          choices.any((c) => c.editor == last.app && c.installed));
  if (!installed) return (rows: defaults, lastUsed: null);
  return (
    rows: [last, ...defaults.where((pick) => pick != last)],
    lastUsed: last,
  );
}
```

**2. The title rule.** "Edit all {n} clips in…" and the button appear only when the sheet was opened for every clip and there is more than one (`e.all && n > 1` in the prototype). One clip, or clips you chose, say "Edit {n} clips in…" and have no button.

**3. The pill is a new part of a list row.** `TtListRow.titleTag` draws the pill after the title in a `Wrap`, so at large text it drops under the title instead of squeezing it.

**4. The sheet is also covered in "A sheet that answers instead of navigating" and "A phone habit, not a setting" below.**

### Where it lives

- `app/lib/domain/models/editor_app.dart` (`EditorPick`), `app/lib/data/repositories/phone_state_repository.dart` (`lastEditor`, `recordLastEditor`).
- `app/lib/features/editors/view_models/editor_choices.dart` (`editorRows`), `views/editor_sheet.dart`.
- `packages/taketray_ui/lib/src/components/grouped_rows.dart` (`TtListRow.titleTag`).

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/editors/editor_sheet_test.dart
```

Then break it: drop the installed check in `editorRows`. Several tests ("last used CapCut, now not installed") fail.

### Decisions

- D-189 (amends D-126).

## Task 3: The selection dock

### What we built

`TtSelectionDock`, a new piece of the design system: the bar that holds the actions for the clips you chose. It has four labelled actions in a row (Share, Add to, Move, Remove), and under them either a large **Edit {n} clips** button with the length of the chosen clips, or a note.

### Why TakeTray needs it

In Phase 4 the reel page's top bar held three unlabelled icons and a ⋮ menu while you chose. The design puts words under the icons and makes Edit the biggest thing on the screen, because sending clips to an editor is what choosing is usually for.

### Key ideas

**1. The API enforces the shape.** A dock has exactly four actions, and exactly one of `edit` or `note`:

```dart
}) : assert(actions.length == 4, 'a dock has exactly four actions'),
```

The dock has no words of its own: the reel page passes every string through l10n, so the package stays free of language.

**2. An off action has no tap action.** The handoff says an action with nothing chosen is "38 %, not focusable as actions". The dock draws it at 38 % and gives it **no tap action at all** (the `Semantics` has a null `onTap`), so TalkBack still reads the label but does not offer a double-tap that does nothing.

**3. Large text changes the layout.** From a text scale of 1.5 the four actions go two by two, and Edit's content is a `Wrap`, so the length drops under the label.

**4. The slide moves the panel, not the widget.** `SlideTransition` is the outermost widget, so the dock's own box stays where its parent put it and the panel is drawn lower until it arrives. A test measures the panel (the first `DecoratedBox`), not the widget's box. The duration is read from the theme, so "Remove animations" makes the dock simply appear.

### Where it lives

- `packages/taketray_ui/lib/src/components/selection_dock.dart`; its metrics in `tt_metrics.dart` under "Selection dock".
- `widgetbook/lib/components/selection_dock.dart`.

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/selection_dock_test.dart
```

Then break it: let an off action keep its `onTap` in the `Semantics`. 'an off action is at .38 and has no tap action' fails.

### Decisions

- D-190.

## Task 4: The reel page, Edit video and the dock

### What we built

The reel page now uses the pieces of Tasks 1 to 3. **Edit video** opens the editor sheet with every clip. **Choose clips instead**, a long press and ⋮ **Select clips** all start choosing. While choosing, the dock takes the nav pill's place at the bottom and the top bar has **Select all** (or **Clear** when every clip is chosen). A hint ("Tap the clips you want to edit") explains choosing that came from the sheet.

### Why TakeTray needs it

This is the task that makes the two taps real. It also moves what the top bar's three icons did (Share, Add to, Move, Remove) onto the dock with words, and keeps every guard they had (one tap at a time, the copies first on Remove, a failure keeps the choice).

### Key ideas

**1. The dock lives in the shell, not in the page.** This is the main idea of the task; see "Why the dock lives in the shell" below.

**2. The page tells the shell, never while building.** A Riverpod provider must not change while a widget is being built. The page keeps the notifier from `initState`, and calls `show` and `hide` from a listener on its selection, from one post-frame call (a page that opens already choosing gets its dock one frame later) and from a post-frame call in `dispose`:

```dart
void hide(int reelId) {
  if (!ref.mounted || state != reelId) return;
  state = null;
}
```

`hide` does nothing when another reel's page is the one shown, so a page that goes never takes away the dock of the page that came after it.

**3. R1 inside the dock.** While a reel has an editing session, Edit would start a second one. The dock shows the note "This reel is being edited in VN. Tap Done editing at the top before sending clips again." in Edit's place, and the four actions still work. While the session is still loading, Edit shows and is off.

**4. A dismissed sheet keeps the choice.** The dock clears the choice only when the sheet's outcome says an editor was picked (`isPicked`), so closing the sheet by mistake does not lose three taps of work.

### Where it lives

- `app/lib/features/shell/view_models/choosing_reel.dart`, `views/app_shell.dart`.
- `app/lib/features/reels/views/reel_choosing_dock.dart`, `reel_detail_screen.dart`.
- Tests: `app/test/features/reels/views/reel_selection_screen_test.dart` (group "Edit video and the dock"), `app/test/features/shell/views/app_shell_test.dart`, and the golden tests `reel_choosing_golden_test.dart` (macOS only).

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/shell/views/app_shell_test.dart test/features/reels/views/reel_selection_screen_test.dart
```

Then break it, two ways. In `AppShell` drop the branch check (`index == 0 ? … : null`): the test "on another tab while a reel page is choosing: the nav pill, not the dock" fails. In the page's `dispose`, call `hide` at once instead of after the frame: "the page going away while choosing gives the nav pill back" fails with "Tried to modify a provider while the widget tree was building."

### Decisions

- D-191 (amends D-87, D-88, D-126 and D-184).

## Task 5: The picking screen is only for adding

### What we built

The old picking screen, where you ticked clips and pressed **Continue**, lost its normal mode. It is now only the screen that adds clips to a reel that is being edited ("Add clips to a VN edit"). The route to it changed, and an old link to the normal mode opens the reel instead.

### Why TakeTray needs it

With the dock and the sheet doing the choosing, a second screen for the same job is a detour with its own bar and words. Keeping one screen for one job also removes a lot of code (a mode flag, a bottom bar, six strings and four goldens).

### Key ideas

**1. Characterize before you cut.** The screen's tests mixed the two modes. Before changing any code the task split them (no assertion changed) and ran the add-mode tests green. Those tests are the proof that add mode did not change while a mode was deleted around it.

**2. An old location is sent somewhere kind.** The router sends a location it can no longer build to the reel's page, and logs a line with no location in it (D-10: the location can name a reel):

```dart
if (query[Routes.editAddParameter] != '1' ||
    query.containsKey(Routes.editClipsParameter)) {
  _log.warning('Picking screen without add mode; showing the reel');
  return Routes.reel(reel);
}
```

A location that names no valid reel still goes to Reels, as any unknown location does.

**3. What the old tests also pinned stays.** A deleted mode's tests also checked things add mode still needs (a missing clip leaves the list, the clips to copy are in shooting order). Those were kept as add-mode tests, not deleted with the mode.

### Where it lives

- `app/lib/features/editors/views/edit_select_screen.dart`, `view_models/edit_select_controller.dart`.
- `app/lib/router/routes.dart` (`Routes.editAddOf`), `app_router.dart`.

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/editors/edit_select_screen_test.dart test/features/editors/edit_select_controller_test.dart test/router/app_router_test.dart
```

### Decisions

- D-192 (amends D-126).

## Task 6: The compact Shooting mode card

### What we built

The Shooting mode card on Home is now one calm row when it is off (a tile, "Shooting mode" over a line, the switch) and a black card when it is on: the same row, then an **Open camera** pill and up to two **glass chips**. The card's rows, its "N clips to tag" strip and the old `TtCardRow` are gone from the package.

### Why TakeTray needs it

The old card was a stack of rows (Add earlier videos, References, a strip) that made the top of Home heavy. The new design keeps the card to its one job, the switch, and moves the extras to chips that appear only while you are shooting.

### Key ideas

**1. One tree, on and off.** The card is the same widget tree in both states, so the switch is the same element before and after a toggle; see "Keeping a switch's focus through a layout change".

**2. A fade must never wrap a filter.** Phase 12 learned on the S24 that a blur under an `Opacity` or a growing blur is lost. The chips are glass, so they follow the rule: no `Opacity`, `FadeTransition` or `AnimatedOpacity` above a chip's `BackdropFilter`; its blur is a steady 10 from the first frame; only its fill's alpha (0 to .14) and an `Opacity` on its content, inside the fill, change.

**3. The chip fill differs from the CSS, on purpose (AA).** The CSS says white at 14 %. Over a bright clip (a white wall, snow) the white text measured under 4.5:1. The tint stays as designed; only the chip's own fill changed, a little black under the white 14 % (ruling R12B-6). The test uses a pure white stand-in for the backdrop, the worst case.

**4. Reduced motion keeps the fades.** "Remove animations" removes movement, not fades. The size and padding change at once; the fades still run, over the token `short4` (the theme's own durations are zero then).

### Where it lives

- `packages/taketray_ui/lib/src/components/shooting_mode_card.dart` (`TtShootingModeCard`, `TtShootingCardChip`); metrics `shootingCardRadius` and the rest in `tt_metrics.dart`.
- `packages/taketray_ui/test/components/glass_pixels_test.dart` (a chip blurs by 10 under its .14 white).

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/shooting_mode_card_test.dart test/components/glass_pixels_test.dart
```

Then break it: put `FadeTransition(opacity: AlwaysStoppedAnimation(progress))` around a chip. "no Opacity or FadeTransition above a chip's BackdropFilter" fails.

### Decisions

- D-193 (amends D-46, D-79, D-90 and D-160).

## Task 7: The calm reel card

### What we built

`TtReelCard` is now the cover alone, with the words under it. Nothing sits on the cover any more: the status pill, the "Editing in VN" pill and the references badge are gone (and with them `TtGlassPill`, which nothing else used). Under the cover come the name, the status (a small filled icon and the word), the clip count and length, and, only when they apply, notes: "In VN", "{n} missing" and the number of references.

### Why TakeTray needs it

The owner found the old card busy: glass pills over the picture, a badge button, a scrim. The calm card puts the picture first and lets the words be words, which also helps TalkBack, because nothing inside the card is its own control.

### Key ideas

**1. A cover whose box does not change when the picture lands.** The cover is always 3:4 with radius 20. While the picture decodes, `Image.frameBuilder` shows the same shimmer the clip tiles use, in the same box, so the card's height is the same before and after. A failed decode shows a movie icon.

**2. The press.** While a finger is down the card scales to .98 (`AnimatedScale`, `short3`); never under "Remove animations".

**3. One node for a screen reader.** The card is one `Semantics` button named `semanticLabel`, with `excludeSemantics: true`, so nothing inside it is a node of its own. The Home screen builds the label: "London Food. Collecting. 14 clips, 2 missing. Editing in VN. 2 references".

**4. A skeleton that never stops, in a test.** A test thumbnail is read from the disk, which the test clock never lets finish, so a card with a cover shimmers forever and `pumpAndSettle` never returns. Tests that pump the whole app with a real cover pump a bounded number of frames instead.

### Where it lives

- `packages/taketray_ui/lib/src/components/reel_card.dart`, `status_pill.dart`; metrics `reelCard*`.
- `packages/taketray_ui/test/components/reel_card_test.dart`.

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/reel_card_test.dart
```

Then break it: give the cover `aspectRatio: 0.8` (4:5, which looks close). The 3:4 tests fail, and so do the 2x text tests.

### Decisions

- D-194 (amends D-46, D-158 and D-173).

## Task 8: Quiet tabs, the New pill and the collapsing header

### What we built

Three new pieces for Home. `TtQuietTabs` is a row of filter tabs, each a pill with a label and a count; the chosen one is filled. `TtHeaderPill` is the **+ New** button. `TtLargeSliverAppBar` is the large "Reels" title that shrinks into a pinned bar as the page scrolls.

### Why TakeTray needs it

The old filter was a row of outlined chips and the New reel button floated over the reels. The design wants a quiet filter, a button that is always in reach and a title that gets out of the way.

### Key ideas

**1. A new widget, not a new look for an old one.** `TtPillTabs` is used by the date range picker and keeps its look and its wrap. The quiet tabs have another height, other sides, a count and different semantics, so adding flags to the old widget would have bent both.

**2. `toggled`, not `selected`.** The prototype's filter is a set of buttons that are pressed or not. In Flutter's semantics, `selected` is read as "selected", the wording of a tab bar; `toggled` is read as "on" and "off", the wording of a switch. The tabs are one container named "Show reels" with each tab a button that has `toggled: chosen`:

```dart
return TtPillTapTarget(
  label: tab.semanticLabel,
  toggled: chosen,
  onPressed: onPressed,
  ...
```

**3. `SliverAppBar.large`, not a hand-made header.** The handoff names it, and it brings the status bar, the pinned bar and the safe area. The one subtlety: Material builds the title twice (in the bar and in the flexible space), so a small widget tells them apart, and the expanded one is marked as a heading, because the bar's own title is invisible until the page has scrolled 88 dp.

**4. A helper that could not run.** `expectTtAccessible` restyles every text and lays the page out again in the middle of a frame, which a sliver header cannot take while expanded. The test for the expanded header measures every visible text itself and runs the tap-target guidelines; the collapsed state runs the whole helper.

### Where it lives

- `packages/taketray_ui/lib/src/components/quiet_tabs.dart`, `app_bar.dart`, `components/internal/pill_tap_target.dart`.
- `packages/taketray_ui/test/components/quiet_tabs_test.dart`, `app_bar_test.dart`.

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/quiet_tabs_test.dart test/components/app_bar_test.dart
```

Then break it: drop `toggled:` from the tab. 'a group named "Show reels"; each tab read by its label and toggled when chosen' fails.

### Decisions

- D-195.

## Task 9: Home, the calm grid

### What we built

Home is one scroll: the large header with **+ New**, the Shooting mode section, the quiet tabs, and then the reels in rows of two (one column from a text scale of 1.5). A tab with no reels says "No reels marked … yet." with **Show all reels**. The floating **New reel** button, the filter chips, the strip and banner under the card and the Add earlier videos row are gone.

### Why TakeTray needs it

This is where Tasks 6 to 8 meet the app's data. The off card now says how many clips wait in its own line, so the banner and strip are not needed; the extras are chips; the card opens the reel's page.

### Key ideas

**1. The card's line and the To tag badge count the same clips.** The off line "Off · {n} clips still to tag" reads `pendingClipsProvider`, the same stream as the To tag tab's badge (Phase 12, D-184), so the two cannot disagree. A mutant that added skipped clips to the line is killed by a test that checks the line and the badge together.

**2. "Added this session" lives in memory.** The **Earlier videos** chip hides after you add earlier videos, until Shooting mode is turned off and on. A small provider keeps that flag, clears it whenever the known on/off value changes and is never stored:

```dart
ref.listen<AsyncValue<ShootingState>>(shootingModeControllerProvider, (_, next) {
  final on = next.value?.on;
  if (on == null || on == _on) return;
  _on = on;
  state = false;
});
```

A loading or error value in between is not a change, so a flicker of the state does not bring the chip back. An add from To tag's menu while Shooting mode is off is forgotten when it turns on, so it never hides a later session's chip.

**3. Switching a tab fades; nothing slides.** The grid sits in a `SliverFadeTransition` that restarts when you pick a tab. Under "Remove animations" the fade still runs over `short4`, because only movement is removed.

**4. A tap on a card always opens the reel's page.** Home no longer opens the References section; the number is a note under the cover. The Shooting mode sheet's reel header still opens a reel scrolled to its References.

**5. The container transform is parked.** The design opens a reel by growing the card into the page. That needs the `animations` package, a new dependency this phase may not add, so today's route transition stays and the idea is in `docs/later.md` for the owner (R12B-5).

### Where it lives

- `app/lib/features/reels/views/reels_screen.dart`, `app/lib/features/shooting_mode/views/shooting_mode_section.dart`, `shooting_tip.dart`.
- `app/lib/features/shooting_mode/view_models/earlier_added.dart`.
- Tests: `reels_screen_test.dart`, `reels_tab_test.dart`, `home_golden_test.dart` (macOS only), `shooting_mode_section_test.dart`.

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/reels/views/reels_screen_test.dart test/features/reels/views/reels_tab_test.dart test/features/shooting_mode/views/shooting_mode_section_test.dart
```

Then break it: replace the rows with a `SliverGrid` of a fixed `childAspectRatio`. 'two columns, 16 × 12, top aligned: a two-line name does not stretch its neighbour' fails.

### Decisions

- D-196 (amends D-76, D-86, D-90, D-158 and D-160; carries D-186 and D-187).

## Task 10: The Patrol flows on the new controls

### What we built

The on-device flows for reels, editors and references were rewritten for the new controls, without a phone: **Edit video** then the sheet's "Edit all 3 clips in…", the dock's **Remove**, the header's **+ New**, a Home card found by its name, the References chip. One new flow: hold a clip, tap another, **Edit 2 clips**, CapCut gets exactly those two in shooting order, and the next **Edit video** shows **Last used** on CapCut.

### Why TakeTray needs it

The flows drove the old controls, so on the S24 they would have failed for that reason. The phone run is Task 12; this task makes sure it fails only for real faults.

### Key ideas

**1. Finders that cannot match the wrong thing.** `newReelButton()` is the header pill read "New reel", never a search by the words, because the empty Home's own **New reel** button says the same. `dockAction(label)` is the ink of the dock's action, `dockEdit()` the dock's Edit.

**2. One tap helper that waits for the screen to be still.** Phase 12 found that a tap on a target that is still moving is lost on a live phone (the host test's fake time hides the slide). The dock slides up and the Shooting mode card grows, so every control this task changes is tapped with:

```dart
Future<void> tapWhenStill(PatrolIntegrationTester $, Finder finder) async {
  await waitFor($, () => canBeTapped(finder), what: 'a tap target that can be hit: $finder');
  await waitForStill($, () => [tapTarget($.tester, finder)], what: 'the tap target to stop moving: $finder');
  await $.tester.tap(finder.first);
  await $.tester.pump();
}
```

**3. Guards that run without a device.** `reel_finders_test.dart` checks each finder against the real Home and the real reel page in the shell (found once, can be tapped, with and without reels, while choosing). Two source-reading tests check that the flows use the new finders and the new steps, as the references flows' test already did.

**4. A check that cannot fail on its own.** CapCut is already the default first row, so "CapCut is listed first" proves nothing alone; the **Last used** pill on CapCut's row is what the new flow checks.

### Where it lives

- `app/patrol_test/support/reel_finders.dart`, `reels_test.dart`, `editors_test.dart`, `references_test.dart`.
- `app/test/patrol_support/{reel_finders,references_source,editor_flows_source}_test.dart`.

### Try it yourself

```sh
cd app && ../tool/flutter test test/patrol_support/reel_finders_test.dart test/patrol_support/editor_flows_source_test.dart
```

Then break it: make `newReelButton` also match a `TtButton` labelled "New reel". The test "finds one, on an empty Home and with reels" fails with "Found 2 widgets".

### Decisions

- D-197 (amends D-161 and D-143's flow lists).

## Why the dock lives in the shell

The prototype draws the reel's page with no nav pill, so the dock is simply at the bottom. TakeTray's reel page sits inside the app shell, which owns the nav pill (D-87). There were two ways to put the dock on screen:

- **In the page, over the nav pill.** Two bars at the bottom, one hiding the other, and every snack ("Sent 2 clips to CapCut", the Undo snacks) would have to be lifted by hand to clear the dock.
- **In the shell, instead of the nav pill.** The shell's `Scaffold` already has one slot for a bottom bar. Put the dock in it while a reel page is choosing:

```dart
bottomNavigationBar: choosing != null
    ? ReelChoosingDock(key: ValueKey<int>(choosing), reelId: choosing)
    : TtNavPill(…),
```

Flutter floats a snack above whatever the `Scaffold`'s bottom bar is, and the slot keeps the phone's gesture inset, so both come for free. The cost is that the shell has to know that a page is choosing, which a page deep in a tab can only tell it through a provider. That is `ChoosingReel`, which holds the id of the reel whose page is choosing, or nothing.

Three details come with it:

1. **The branch check.** The reel page stays alive in its tab while you look at To tag or Settings, so the provider can be set while another tab is showing. The shell reads it only when the Reels tab (`index == 0`) is on screen; elsewhere the nav pill stays, and on coming back to Reels the dock is there again.
2. **The padding.** While the dock shows, the shell passes the `Scaffold`'s own bottom padding, which includes the dock's height, down to the body, and the page's last spacer adds it, so the last clip can scroll clear of the dock (at 1x and at 2x, where the dock is tall).
3. **One `MediaQuery`, always.** The body is wrapped in a `MediaQuery` in both cases, so the tabs below it keep their state as the dock comes and goes.

The lesson is general. When two pieces of UI want the same corner of the screen, find the widget that already owns that corner and put the choice there, rather than stacking one on the other and managing the overlap.

## A sheet that answers instead of navigating

In Phase 8 the editor sheet, after a send to CapCut, popped the picking screen under it. That was right when the picking screen was the page that opened the sheet. Now the reel's page opens it, and that page is where the person should stay. So the sheet does not decide what happens next; it answers:

```dart
enum EditorSheetOutcome {
  dismissed,    // dragged away, tapped away or Back: nothing happened
  sent,         // CapCut or Instagram Edits got the originals
  openedVn,     // VN: the space check was pushed
  shared,       // Other app…: Android's share menu was opened
  chooseInstead, // Choose clips instead: the caller starts choosing
}
```

`showEditorSheet` returns the outcome, and the caller reads it: the dock clears its choice when `outcome.isPicked` (the three hand-offs), keeps it when the sheet was dismissed, and the reel page starts `ReelSelection.begin(fromSheet: true)` for `chooseInstead`. After a send the sheet itself shows the snack and the Ready to edit offer and returns; it never touches the navigator's stack.

Why an enum and not a bool or an exception? "What did the person do?" has five answers, and each caller cares about a different subset of them. An enum makes the caller list the cases it handles, and a new answer later is a compile warning wherever it is not handled. It also made the tests short: each case is "open the sheet, do X, expect outcome Y, and the page underneath did not move".

## A phone habit, not a setting

The last editor you used is remembered, but it is not a setting. The difference decides where it is stored:

- A **setting** is something you chose in Settings. It belongs in a backup, so Export carries it to a new install.
- A **phone habit** is something the app noticed. It belongs to this phone and this use, and a backup should not carry it.

`lastEditor` lives in `PhoneStateRepository`, beside the other things the app remembers about itself (the volume versions, the saved copy plan and so on), and is not in `SettingsRepository.exportedKeys`, so a backup never holds it and an import keeps what the phone has. It is stored as the enum's name in JSON, and a test pins the spelling, because a renamed enum value would silently read as "nothing remembered" on every phone that had stored the old name. A missing or unreadable value reads as none, and only the key is logged (D-10).

There is one deliberate difference from the design. The prototype records the editor at the tap. TakeTray records it **after a successful hand-off**:

```dart
await container.read(phoneStateRepositoryProvider).recordLastEditor(pick);
```

so a tap on an editor that turns out not to be installed, or a send that fails, never becomes the habit. The write is not awaited by the hand-off, and a write that fails is logged by its type and changes nothing else. The pill and the order follow each other (see `editorRows` in Task 2): an editor that was last used and is no longer installed goes back to its normal place with no pill.

## Keeping a switch's focus through a layout change

TalkBack puts a focus ring on one control at a time. If that control's widget is **replaced** (a different element, even with the same look), TalkBack loses its place and the person has to find the switch again. The Shooting mode card changes size when you flick its switch, and the flick is the whole point of the card, so the switch must be the same element before and after.

The old card had two trees, a grey one and a black one, swapped for each other. A swap makes a new element. The new card is one tree:

```
ClipRRect
  ColoredBox (the off surface)
    Stack
      Positioned.fill(Opacity(progress, _OnLayer))   // always there, invisible at 0
      AnimatedPadding
        Column [ row 1 (the tile, the title, the TtSwitch) , ClipRect(Align(heightFactor: progress, Wrap(pill, chips))) ]
```

The black layer is always in the tree and simply fades from 0 to 1; the second row's children sit last in their `Column`, so the only things that appear and go are at the end, and the `TtSwitch` in row 1 is never rebuilt as a different element. A test holds on to the switch's element and checks that it is the same one after the toggle:

```
switching on: the same TtSwitch element; the height animates over medium2
```

A mutant that put `key: ValueKey(on)` on the card's body (two keyed trees) is killed by it. The same shape is why the height animates (the second row takes `progress` of its height, so it grows and shrinks with the fade, in both directions) instead of jumping, and why the padding is animated by `AnimatedPadding` and not set by the state.

Two rules from Phase 12 apply to the glass in it. A chip's `BackdropFilter` has nothing that fades above it, and its blur is the same from the first frame. And under "Remove animations" the card changes size at once but still fades (the picture does; the second row simply goes).

## A grid whose rows fit their cards

The old Home used a `SliverGrid` with a fixed aspect ratio for its cards. That works when every card has the same height, which was true when the text sat over the cover. The calm card's text sits under the cover, and the text differs: a name that takes two lines, a note line that only some cards have. A fixed ratio would either cut the longer cards or pad the shorter ones.

The new Home builds its own rows:

```dart
SliverList.builder(
  itemCount: rows,
  itemBuilder: (context, row) => Padding(
    padding: EdgeInsets.only(top: row == 0 ? 0 : TtMetrics.homeGridRowGap),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TtMetrics.homeGridColumnGap,
      children: [
        for (var i = row * columns; i < (row + 1) * columns; i++)
          Expanded(child: i < reels.length ? _ReelCard(…) : const SizedBox.shrink()),
      ],
    ),
  ),
),
```

- Each row is a `Row` of `Expanded` cards with `CrossAxisAlignment.start`, so the two cards of a row share the row's width, sit at the top and are each as tall as their own text. A two-line name does not stretch the card next to it (the test measures both).
- `SliverList.builder` still builds only the rows near the screen, so 20 reels or 200 cost the same.
- The last row of an odd count gets an empty `SizedBox` in the second slot, so the single card keeps half the width and does not stretch to fill the row.
- `columns` is 1 from the large-text scale (1.5), as the design's `.fs2` rule says, and the tests run both.
- The cover's own box is a fixed 3:4, so the card's height changes only with its words, and a picture landing never makes a row jump.

The general idea: use a fixed-ratio grid only when the items are the same shape; when their height depends on content, build the rows and let each one be as tall as it needs.

## What the phase leaves you with

- **Two taps to an editor.** Edit video, then the editor, sends the whole reel; the editor you used last is first and says so.
- **One bar at the bottom.** Choosing clips puts a dock in the place of the nav pill, with labelled actions and an Edit button that shows how many clips and how long; snacks and the gesture inset are right because the dock is the shell's own bottom bar.
- **A sheet that answers.** The editor sheet returns what the person did and leaves navigation to its caller.
- **A habit that stays on the phone.** The last editor is stored after a hand-off that worked, and never travels in a backup.
- **One picking screen, for one job.** It only adds clips to a reel that is being edited; the normal mode and six strings are gone.
- **A calm Home.** A compact Shooting mode card that grows without losing the switch's focus, glass chips that stay sharp-edged and blurred, quiet tabs read as toggles, a **+ New** pill, a header that gets out of the way and reel cards that are only a cover and words.
- **Rows that fit their cards,** one column at large text, and a fade, not a slide, when you change tabs.
- **Flows written for a phone nobody had yet.** The Patrol flows use finders that cannot match the wrong control and a tap that waits until the target stops moving; their first real run is Task 12.
- **What is left for a person to judge** is a numbered list, "Phase 12B check" in `docs/dev-setup.md`, to be answered by number on the S24, and the container transform is parked in `docs/later.md` for the owner.
