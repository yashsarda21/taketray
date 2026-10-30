# Learning guide: Phase 4, reels

This guide explains how TakeTray shows and manages reels: the Reels tab (Home), creating, editing and deleting a reel, the reel's page with its clips grouped by the day they were shot, selecting several clips, and the full-screen clip viewer. It also explains how every remove, move and delete can be undone, and how a clip's time is shown in the place where it was shot.

Each section is filled in by the step that builds it, and Task 12 turns them into one read-through. The shape of every section is the same as in Phase 3: **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Design-system debts](#2-design-system-debts)
3. [New components for reels and the viewer](#3-new-components-for-reels-and-the-viewer)
4. [The time where a clip was shot](#4-the-time-where-a-clip-was-shot)
5. [Reel data and undo](#5-reel-data-and-undo)
6. [Home](#6-home)
7. [Create, edit, status and delete](#7-create-edit-status-and-delete)
8. [Reel detail](#8-reel-detail)
9. [Multi-select and the reel picker](#9-multi-select-and-the-reel-picker)
10. [The clip viewer](#10-the-clip-viewer)
11. [On the phone](#11-on-the-phone)

## 2. Design-system debts

**What we built:** a clean-up of the design package (`packages/taketray_ui`) before any reel screen is built on it. Earlier reviews had parked about twenty small defects and gaps for "Phase 4"; this section lists how each was fixed. The main changes are:

- **Words come from the caller.** The package no longer writes any text a person reads: not the `n/max` counter of a text field, not the `%` of a progress bar, not the label of a reference tile or a glass pill.
- **One place sets a font weight.** `TtTextStyles.weight(...)`.
- **`TtCardRow` has an explicit look.** `TtCardRowKind.link` or `.strip`.
- **A text field is complete.** It reads its error aloud, keeps the text when its controller changes, and grows its error icon with the text size.
- **Text at 2×.** Four places that broke at double text size now hold together.
- **The Widgetbook tests check more.** They now fail when a tap opens the wrong use case, or when a second widget in a file is left out of the catalogue.

**Why TakeTray needs it:** the reel form (Task 7) is the first screen with a real text field, and Home (Task 6) is the first with reel cards, status filters and a Shooting mode card used for real. The app is meant to be translated, so a package that says "40/40" or "40%" by itself would break in another language. A text field that does not tell a screen reader what is wrong is a bug a blind user meets on the first form. These are cheap to fix now and expensive once ten screens copy the old API.

**Key ideas:**

- **A string that depends on a number becomes a function.** A caller (the app, with its translations) owns the words, and the package only says *what* to say it about. The counter is the model:

  ```dart
  final String Function(int length, int max)? counterText;
  ...
  }) : assert(
         maxLength == null || counterText != null,
         'A field with a maxLength needs a counterText',
       );
  ```

  `assert` only runs in debug builds and in tests, so a forgotten argument is caught the first time the screen is drawn while you work, at no cost in the release app. `TtProgressBar.percentText` and `TtReelCard.referencesSemanticLabel` (needed when `referenceCount > 0`) work the same way. The Shooting mode card's group label is a localized *select* message in the app: `"Shooting mode, {state, select, on{on} other{off}}"`, called with `'on'` or `'off'`.

- **A variable font has two weight settings, and they must agree.** Plus Jakarta Sans is one file whose weight is a continuous axis called `wght`. Flutter also has `fontWeight`. If only one is set, the two can disagree and the text looks wrong. The helper sets both:

  ```dart
  static TextStyle weight(FontWeight weight) => TextStyle(
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );
  ```

  You use it by **merging** it over a style, which changes only those two properties: `tt.text.navLabel.merge(TtTextStyles.weight(TtMetrics.badgeFontWeight))`. A test reads every file under `lib/src` and fails if any of them, other than the helper and the generated type scale, writes `FontVariation(` by hand, so the rule cannot be forgotten later. (The TakeTray display styles are built with the helper too, so their constructor is no longer `const`.)

- **A widget that can swap what it owns must decide what happens to the contents.** `TtTextField` has its own `TextEditingController` unless the caller gives one. If the caller starts or stops giving one while the field is on screen, the text must not vanish. The rules, in `didUpdateWidget`:

  ```dart
  if (old == null && given != null) {
    // own -> given: the caller's text wins, unless it is empty
    if (own != null && given.text.isEmpty && own.text.isNotEmpty) {
      given.value = own.value;
    }
    own?.dispose();
    _own = null;
  } else if (old != null && given == null) {
    // given -> own: keep what showed
    _own = TextEditingController.fromValue(old.value);
  }
  // given -> another given: the caller owns both, leave them alone
  ```

  The copy into the caller's controller is made after the frame (`addPostFrameCallback`), not inside `didUpdateWidget`, because that runs in the middle of a build and a listener of the caller's controller (a `ListenableBuilder` or a view model above the field) must not be told of a change there. The deferred copy is dropped if the controller changed again meanwhile. The three tests are named after the three cases. The counter listens to whichever controller is current, and there is a test that it follows a swap.

- **Semantics: a node says one thing.** The error text under a field is drawn by a separate widget, so a screen reader reading the field did not know about it. Material's own `errorText` puts the error into the field's semantics as a *hint*; since TakeTray draws its own help row, it does the same by wrapping the field: `Semantics(hint: widget.error, child: TextField(...))`. The error row also stays a live region, so it is announced when it appears. The Shooting mode card and the glass pill got labels the same way: the card is a group (`Semantics(container: true, explicitChildNodes: true, label: ...)`) so the switch and buttons inside it are still separate things you can focus.

- **An icon does not grow with the text unless you make it.** Text scales with the phone's font size, icons do not. The error icon is next to a line of text, so it takes the size from the same scale: `MediaQuery.textScalerOf(context).scale(TtMetrics.textFieldHelpIconSize)`. The test pumps the field at 1× and 2× and checks that the icon is twice as wide.

- **At 2×, move or shrink; never cut.** There were four breakages:
  - **Missing-clip tile:** the label used to get one line at large text, so "Missing from phone" became "Missing fr…". It now wraps over as many lines as it needs, and only between words. A text "Remove" button broke its own word ("Rem / ove") in a tile this narrow, so from a text scale of 1.5 the button is just an icon (`playlist_remove`, a 48 dp target) that keeps the tooltip and the screen-reader name "Remove". The same icon takes over at normal text when the word does not fit the tile (a long translation, say), instead of ending in "Remov…": `FitOrFallback` shows its `preferred` child if that child's natural width fits the room and its `fallback` if not, decided while laying out, like a `LayoutBuilder` but without the `LayoutBuilder`'s refusal to answer intrinsic size questions. The tile has a fixed 3:4 shape (it sits in a grid), so if the content is still too big it is shrunk. `FitHeight` does that: like a `FittedBox(fit: BoxFit.scaleDown)`, except that its child keeps the box's *width* (so text wraps), it also shrinks when one word is wider than the box, and it passes on its child's baseline, scaled. It is a few dozen lines of `RenderBox` code, because a `LayoutBuilder` cannot answer the "how tall are you?" questions that some parents (`IntrinsicHeight`) ask. In a three-column cell on 360 dp the content does not fit at real 2× and is shown at about 0.7; `docs/later.md` has the follow-up (rows that grow with the text).
  - **Stat strip:** the action no longer squeezes the text to a few letters. From a text scale of 1.5 it goes *under* the text, as `TtBanner` already does; a test at 1.3× checks that below that it stays beside the text with nothing cut.
  - **Reel card with empty art:** the pills used to float over the film icon. They are now at the top of the same column, so the empty art takes the room between the pills and the caption.
  - **Pill tabs:** the old test put a long label in a *scrolling* row, which can never overflow, so it could not fail. The new tests use `wrapAtLargeText` and check that each tab is inside the 360 dp screen, and, for the scrolling mode, that the row really scrolls (`maxScrollExtent > 0`).

- **Tests that can fail.** Several debts were *tests that could not fail*. A test is only worth keeping if you have seen it fail: for each new test the code was written or broken first and the failure watched. For example, the caret gap of the status pill was already correct in the code (6 dp), so the test was proven by changing `statusPillCaretGap` to 2 and watching `Expected: <6>  Actual: <2.0>`.

- **Widgetbook tests that check what they claim.** The use-case test used to tap each use case and only check that nothing threw. It now also checks that the tap *selected* it:

  ```dart
  expect(
    WidgetbookState.of(tester.element(find.byType(Scaffold).first)).useCase?.name,
    name,
  );
  ```

  The coverage test used to pass a file if *any* of its classes was in the catalogue, so a second widget added to a registered file was never noticed. It now checks each public `Tt...` class, minus an allow-list (`_notInCatalogue`) of data classes with the reason for each. A second test makes sure the allow-list holds no class that has gone or has been added to the catalogue since. Running the first version of the new check found two widgets, `TtGroupLabel` and `TtRowIcon`, that were shown only inside another component's use case; the component is now named `TtGroupedRows / TtGroupLabel / TtRowIcon`.

**Where it lives:** `packages/taketray_ui/lib/src/theme/tt_text_styles.dart` (the helper), `lib/src/components/text_field.dart`, `progress.dart`, `reel_card.dart`, `reference_card.dart`, `glass.dart`, `shooting_mode_card.dart` (`TtCardRowKind`, the card's label), `menu.dart`, `stat_strip.dart`, `clip_tile.dart` (`TtMissingClipTile`), `internal/fit_height.dart`. The tests are beside them in `packages/taketray_ui/test/` (`theme/tt_text_styles_test.dart` is new). The app's new key is `shootingModeCardSemantics` in `app/lib/l10n/app_en.arb`, used in `app/lib/features/shooting_mode/views/shooting_mode_section.dart`. The Widgetbook tests are `widgetbook/test/catalog_use_cases_test.dart` and `catalog_coverage_test.dart`.

**Try it yourself:** see the per-class coverage check catch a forgotten widget. From the repo root:

```bash
(cd widgetbook && ../tool/flutter test test/catalog_coverage_test.dart)
```

It ends with `All tests passed!`. Now, in `widgetbook/test/catalog_coverage_test.dart`, delete the line `'TtNavItem': ...` from `_notInCatalogue`, and run the same command. It fails with `Actual: ['nav_pill.dart: TtNavItem']`: the check now names the class and its file. Put the file back with `git checkout -- widgetbook/test/catalog_coverage_test.dart`, and check with `git status` that nothing is left over.

**Decisions:** D-81 (the caller's words, the weight helper, `TtCardRowKind`, text at 2×, and the Widgetbook checks), with D-46 (the reel card's text limit), D-50 (the app bar circle) and D-79 (off rows, the card's rows) as background.

## 3. New components for reels and the viewer

*To be written in Task 3.*

## 4. The time where a clip was shot

*To be written in Task 4.*

## 5. Reel data and undo

*To be written in Task 5.*

## 6. Home

*To be written in Task 6.*

## 7. Create, edit, status and delete

*To be written in Task 7.*

## 8. Reel detail

*To be written in Task 8.*

## 9. Multi-select and the reel picker

*To be written in Task 9.*

## 10. The clip viewer

*To be written in Task 10.*

## 11. On the phone

*To be written in Task 11.*
