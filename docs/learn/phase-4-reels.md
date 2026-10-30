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

**What we built:** the pieces the reel screens and the clip viewer are made of, in `packages/taketray_ui`, so that each screen only arranges them:

- **A status menu item.** `TtMenuItem` can have a second line (`subtitle`), a filled icon and a `checked` state. This is the "Collecting / Ready to edit / Published" menu.
- **A rule for the floating button.** `TtNavPill.fabBottom(context)` says where a FAB sits above the nav pill, and `TtFab` rises out of the way of a snack by itself.
- **`TtReelHeader`.** The reel's name, status pill, "12 clips · 4:32", "2 missing", and the Shot ideas with "Show more".
- **The viewer's dark pieces.** `TtReelTag` (and `TtReelTagRow`) and `TtViewerActions`.
- **`TtReelPickRow` and `TtReelPickNewRow`.** The rows of the "add to reel" sheet.

**Why TakeTray needs it:** Home, the reel page, the viewer and the picker all show the same few things. If each screen drew its own, they would drift apart, and every one would have to get 2× text, dark mode and screen readers right by itself. The design package does it once, with goldens and accessibility tests.

**Key ideas:**

- **A screen reader needs to be told that a menu entry is a choice.** A menu entry that is one of several (the current status) is `menuitemradio` with a checked state. Flutter's `MenuItemButton` merges everything inside it into one node, so the semantics go in the *child*:

  ```dart
  return Semantics(
    role: SemanticsRole.menuItemRadio,
    checked: checked,
    inMutuallyExclusiveGroup: true,
    child: text,
  );
  ```

  `checked` is a `bool?`: `null` is an ordinary entry, `false` and `true` are choices. That also keeps every older `TtMenuItem` working with no change.

- **A floating button has a fixed place, and it gets out of a snack's way.** The place is a function, so every tab uses the same number:

  ```dart
  static double fabBottom(BuildContext context) =>
      reservedHeight(context) + context.tt.spacing.m;
  ```

  The snack's height is not fixed: it depends on the message, the width and the text size. So `TtSnack` measures itself and reports it, once for each `ScaffoldMessenger`, and `TtFab` listens:

  ```dart
  final gap = context.tt.spacing.s;
  return ValueListenableBuilder<double>(
    valueListenable: TtSnackHeight.of(context),
    child: button,
    builder: (context, snack, child) =>
        _Lift(lift: snack > 0 ? snack + gap : 0, child: child!),
  );
  ```

  The lift itself is a paint-time shift that animates with the theme's motion (so "remove animations" makes it a jump): `Transform.translate(offset: Offset(0, -value), child: child)` inside a `TweenAnimationBuilder`. A `Transform` moves how the button is drawn and touched but not the space it takes. That is why a test finds the lifted button by its label and not with `getRect(find.byType(TtFab))`. `liftBy` is only an override for a fixed number.

- **"Show more" is a measurement, not a character count.** Whether a text needs more than two lines depends on the font, the width and the text size. `TextPainter` can lay the text out the way `Text` will and say `didExceedMaxLines`:

  ```dart
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: maxLines,
  )..layout(maxWidth: width);
  final exceeded = painter.didExceedMaxLines;
  ```

  The width is only known during layout, so a small render object (`TextOverflowSwitch`) asks this question there and shows one of two layouts: the text alone, or the clamped text with the button. A `LayoutBuilder` would be the usual tool, but it cannot answer an `IntrinsicHeight`'s questions, which the golden harness asks.

- **The viewer is always dark.** The viewer's pieces use the video colours (`tt.colors.onVideo`, white) instead of the theme's, so the same screen looks the same in light and dark mode. A bar of three actions is equal columns of at least 64 dp, so every action is a 48 dp target at any text size; `TtViewerActions` has an `assert` that there are three or four of them. If the widest word still does not fit its column (four actions at 2× text), `EqualColumns` shrinks all the actions by one scale, so no label is smaller than another.

- **A row that can be one of several, or the only one.** `TtReelPickRow` shows `TtCheckMark` when `multi` and `TtRadioMark` when not, and sets the matching semantics from the same two booleans:

  ```dart
  checked: selected,
  inMutuallyExclusiveGroup: !multi,
  ```

**Where it lives:**

- `packages/taketray_ui/lib/src/components/`: `menu.dart` and `internal/menu_panel.dart` (the menu items), `buttons.dart` (`TtFab`), `nav_pill.dart`, `reel_header.dart`, `viewer_chrome.dart`, `reel_pick_row.dart`, `internal/text_overflow_switch.dart`, `internal/snack_height.dart`, `internal/equal_columns.dart`.
- Their tests and goldens: `packages/taketray_ui/test/components/` (the `*_test.dart` and `*_golden_test.dart` files with the same names).
- The Widgetbook use cases: `widgetbook/lib/components/` (`reel_header.dart`, `viewer_chrome.dart`, `reel_pick_row.dart`, and the new "Status menu" use case in `menu.dart`).

**Try it yourself:**

```bash
(cd packages/taketray_ui && ../../tool/flutter test test/components/reel_header_test.dart)
```

It ends with `All tests passed!`. Now in `packages/taketray_ui/lib/src/components/internal/text_overflow_switch.dart`, make `exceeds` return `true` always (replace its first line, `if (!width.isFinite || ...) return false;`, with `return true;`) and run the same command. `shot ideas shows Show more only when clamped` fails with `Expected: no matching candidates`, `Actual: _TextWidgetFinder:<Found 1 widget with text "Show more"`: the button shows for text that fits. Put the file back with `git checkout -- packages/taketray_ui/lib/src/components/internal/text_overflow_switch.dart`; this works once the task is committed, and until then undo your edit by hand.

To see the pieces, run the catalogue (`docs/dev-setup.md`) and open `TtReelHeader` (try a long text, then a narrow phone and a big text size), `TtMenuButton / Status menu`, `TtFab` (the "lift by" slider) and `TtViewerActions` (switch on four actions and raise the text size).

**Decisions:** D-82 (the FAB contract and these components), with D-81 (the weight helper and the caller's words), D-80 (what Phase 4 shows and hides) and D-79 (the nav pill) as background.

## 4. The time where a clip was shot

**What we built:** every clip's time and shooting day, in the zone where it was shot:

- **A native question.** `zoneOffsetsMs(zoneIds, instantsMs)` asks Android, in one call, "how far ahead of UTC was this zone at this moment?" for a whole list of clips.
- **`ClipTimeService`.** It turns clips into `ClipLocalTime`s (the clock time where each was shot, which zone that is, and whether it is the phone's zone), and remembers the answers.
- **Shooting days.** `groupByShootingDay` puts a reel's clips under their local calendar dates and numbers them "Day 1", "Day 2"…; `dayNumber` counts calendar days.
- **`zoneCity`.** "Europe/Isle_of_Man" becomes "Isle of Man", for the viewer's "London time".
- **To tag** now shows each tile's time where the clip was shot.

**Why TakeTray needs it:** a creator shoots in London, flies to India and tags there. A clip shot at 23:30 in London must say 23:30 and sit on its London day, not 05:00 the next day. Videos do not record their zone, so Phase 3 gave each clip one from the zone timeline (D-71, D-72); this task turns that zone into a time.

**Key ideas:**

- **An offset depends on the zone *and* the moment.** London is UTC+1 in summer and UTC+0 in winter, and the switch happens at an exact instant (01:00 UTC on 25 October 2026). So we never store "London is +1"; we ask for each `(zone, instant)` pair. The phone already knows every zone's rules, kept current by Android's own updates, so Kotlin just asks it:

  ```kotlin
  rules?.getOffset(Instant.ofEpochMilli(instantsMs[i]))?.totalSeconds?.times(MS_PER_SECOND)
  ```

  An id the phone does not know (`ZoneId.of` throws a `DateTimeException`) answers null at its own index, so the list still lines up with the clips.

- **One call for a whole screen, and a cache.** A platform call costs a round trip, so `localTimes` collects every `(zone, instant)` it has not seen and asks once. The answers go in an LRU cache (least recently used goes first) of 4,096 entries. A `LinkedHashMap` keeps keys in insertion order, so "use" means take it out and put it back at the end:

  ```dart
  if (_cache.containsKey(key)) {
    final offset = _cache.remove(key);
    known[key] = _cache[key] = offset;
  }
  ```

  The key is the pair, never the zone alone: with only the zone, a winter clip would reuse a summer clip's +1 hour.

- **When something is missing, use the phone's zone.** No zone on the clip, a zone the phone does not know, or a bridge call that fails: the clip is shown in the phone's zone, and if even the bridge is broken, Dart's own `toLocal()` gives that. A warning is logged with counts and error codes only. A zone id is never logged: "Asia/Kolkata" says where someone was (D-10).

- **A wall clock is not an instant.** `ClipLocalTime.wallClock` is a UTC `DateTime` whose *fields* are the local time: 13:00 in London is `DateTime.utc(2026, 7, 1, 13)`. Why not a local `DateTime`? A local one is read in the phone's zone, and some clock times do not exist there: 01:30 on 28 March 2027 never happened in London (clocks jumped from 01:00 to 02:00), so `DateTime(2027, 3, 28, 1, 30)` on a London phone becomes 02:30. UTC has no such gaps. The rule that follows: format its fields as they are, and never call `toLocal()` on it.

  ```dart
  String wallClockTimeText(DateTime wallClock, {...}) =>
      _timeOfDay(wallClock, locale: locale, use24Hour: use24Hour);
  ```

  `timeOfDayText` (the phone's time) is the same with `time.toLocal()` first; the 24-hour rule (D-76) is in the shared `_timeOfDay`.

- **Days are calendar days, not 24-hour periods.** On a clock-change day a local day is 23 or 25 hours long. Counting between local midnights with `Duration.inDays` rounds 23 hours down to 0, so the day after the spring change would be "Day 1" again. Counting between UTC dates, which are always 24 hours apart, cannot go wrong:

  ```dart
  final from = DateTime.utc(firstDay.year, firstDay.month, firstDay.day);
  final to = DateTime.utc(day.year, day.month, day.day);
  return to.difference(from).inDays + 1;
  ```

  Clips are grouped by their *own* local date, so a reel shot in two zones can have a clip with an earlier date after one with a later date (a later moment further west). The groups are sorted by date, and Day 1 is the earliest one.

- **One function for any kind of row.** `groupByShootingDay<T>(items, clipOf, times)` takes a function that finds the clip in an item. The tests pass plain clips with `(c) => c`; the reel page (Task 8) will pass its own rows.

**Where it lives:**

- Kotlin: `app/android/app/src/main/kotlin/app/taketray/media/ZoneOffsets.kt`, wired in `MediaHostApiImpl.zoneOffsetsMs`; the contract in `app/pigeons/media_api.dart`.
- Dart: `app/lib/platform/media_bridge.dart` (`zoneOffsetsMs`), `app/lib/data/media/clip_time.dart` (`ClipTimeService`, `clipTimeServiceProvider`), `app/lib/domain/models/clip_local_time.dart`, `app/lib/domain/rules/shooting_days.dart`, `app/lib/domain/rules/zone_city.dart`.
- To tag: `app/lib/features/tagging/view_models/to_tag_times.dart` and `app/lib/features/shooting_mode/views/shooting_time_text.dart` (`wallClockTimeText`).
- Tests: `ZoneOffsetsTest.kt`, `app/test/data/media/clip_time_test.dart`, `app/test/domain/rules/shooting_days_test.dart`, `app/test/domain/rules/zone_city_test.dart`, and new cases in `to_tag_screen_test.dart` and `shooting_time_text_test.dart`. `tool/check` runs the three time files again with `TZ=Europe/London`.

**Try it yourself:**

```bash
(cd app && TZ=Europe/London ../tool/flutter test --run-skipped test/domain/rules/shooting_days_test.dart)
```

It ends with `All tests passed!`. Now, in `app/lib/domain/rules/shooting_days.dart`, change the two `DateTime.utc(` in `dayNumber` to `DateTime(` (local dates) and run it again. `day numbers across the London spring change (a 23-hour day)` fails with `at location [2] is (DateTime, int, String):<(2027-03-29 00:00:00.000Z, 2, 3)> instead of (DateTime, int, String):<(2027-03-29 00:00:00.000Z, 3, 3)>`: 29 March became Day 2, like 28 March. Run it without `TZ=Europe/London` (on a machine in a zone with no clock change, such as CI's UTC) and it passes, which is why `tool/check` runs it in London too. Undo your edit with `git checkout -- app/lib/domain/rules/shooting_days.dart`.

**Decisions:** D-83 (native offsets, the cache, the fallback, the wall clock, shooting days), which amends D-76 (the To tag tile's time); D-71 and D-72 (the zone timeline that gives each clip its zone) as background.

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
