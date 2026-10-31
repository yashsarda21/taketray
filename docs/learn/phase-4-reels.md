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

**What we built:** the data the reel screens read, and Undo for every action that changes a reel's clips:

- **`watchReelSummaries()`** gives every reel with its clip count, missing count, the length of its playable clips and a cover clip, for Home's cards, newest first.
- **`watchReelClips(reelId)`** now gives `ReelClip`s: the clip, how many reels it is in (the "in 2 reels" badge) and when it joined this reel.
- **`moveClips(from, to, ids)`** moves clips between reels.
- **No duplicate names.** "Goa" and " GOA " cannot both be reels; a description is at most 1,000 characters.
- **Undo records.** `removeClipsFromReel`, `moveClips`, `addClipsToReel` and `ReelsRepository.delete` each return an `UndoRecord`, and `undo(record)` puts back exactly what that action changed, with the same ids.

**Why TakeTray needs it:** every remove, move, add and delete shows a snack with Undo (D-80). Undo is easy to get wrong here, because removing a clip from its only reel deletes the clip's row (the orphan rule, D-56). If Undo inserted it again with a new id, its "in N reels" count, its thumbnail key and any VN copy row pointing at it would break, or a second row for the same video could appear. The owner also ruled that two reels can't share a name, because they'd be confused in the picker.

**Key ideas:**

- **Snapshot inside the same transaction.** The record is read in the action's own transaction, just before the change. For the orphan sweep that means reading the rows it is about to delete with the very same rule, then deleting them:

  ```dart
  final rows = await _db.selectOrphanClips();
  final deleted = await _db.deleteOrphanClips();
  ```

  Both use one private predicate in `housekeeping.dart`, so "which clips are orphans" is still written once. Inside a transaction nothing can change between the two statements.

- **Plain records, not database rows.** `UndoRecord` is a `sealed` class in `domain/models/`: `RemoveUndo`, `MoveUndo`, `AddUndo`, `DeleteReelUndo`. They hold domain models (`Clip`, `Reel`, …) and small value classes (`ClipLink`, `InboxEntry`, `ReelTouch`), never Drift's `ClipRow`. A `switch` over a sealed class must cover every case, so adding a fifth record later will not compile until `undo` handles it.

- **Same id, unless the video came back.** Putting a swept clip back follows a fixed order:

  ```dart
  if (atId != null && _sameClip(atId, clip)) return clip.id;
  final holder = await _identityHolder(clip);
  if (holder != null &&
      sameFingerprint(_fingerprintOf(holder), clip.fingerprint)) {
    return holder.id;
  }
  ```

  If "Add earlier videos" found the same video again in the meantime, it already has a new row with the same volume and MediaStore number. That row is linked and nothing is inserted: two rows for one video is the bug this avoids. But a number alone is not proof: after Android rebuilds its media library, number 10 can belong to a different video. So the holder is linked only when its fingerprint (size, length, shooting instant; the name is ignored, D-69) is the swept clip's. When it is not, the clip comes back with its old id but detached and missing (`mediaStoreId = -id`, the D-71 shape): the reel shows the missing tile, never the other video. With no holder at all, the clip is inserted with its old id (`id: Value(clip.id)`). Ids are `AUTOINCREMENT`, so an old id is never given to another clip; only a backup import could, and then the clip is skipped with a warning rather than linking the wrong video.

- **Undo never deletes a clip.** Undoing a move or an add removes a link it created only if the clip has another place (a link or To tag/Skipped). Add X to Paris, remove X from Goa, then undo the add: Paris is X's only place now, so X keeps that link instead of being swept.

- **Idempotent, twice over.** Every restore step is "insert if it is not there", so running it again changes nothing. On top of that, an `Expando` (a side table keyed by object identity that does not keep the object alive) marks a record once its undo commits. That matters for "delete, Undo, delete again, then the first Undo once more": without the mark, the first record would bring the reel back a second time.

- **Move adds before it removes.** The removal step runs the global orphan sweep, so the target link must exist first:

  ```dart
  final created = await _link(toReelId, inSource, now);
  final (removed, swept) = await _unlinkAndSweep(fromReelId, inSource, now);
  ```

  Swap the two lines and a clip that was only in the source is deleted before it can be linked (the test fails with a `FOREIGN KEY constraint failed`).

- **One query for Home, not one per reel.** `watchReelSummaries` is a single SQL statement: one CTE (a named sub-query in a `WITH`) counts each reel's clips, another uses `ROW_NUMBER() OVER (PARTITION BY reel ORDER BY date taken, id)` to pick each reel's oldest clip with a picture. The "has a picture" rule (`hasPicture`) is a Drift expression shared with the Shooting card's backdrop and written into the SQL with Drift's `GenerationContext`, so it exists once.

- **Case-insensitive names in Dart, not SQL.** SQLite's `lower()` only folds A–Z, so "CAFÉ" and "Café" would look different to it. The check reads the names and compares `normalizeName(name).toLowerCase()` in Dart, inside the same transaction as the insert, so two Saves at once can't both take the name.

**Where it lives:**

- `app/lib/domain/models/undo_record.dart`, `reel_summary.dart`, `reel_clip.dart`; `app/lib/domain/rules/text_limits.dart` (`reelNameKey`, `checkReelDescription`).
- `app/lib/data/repositories/undo_writer.dart` (`UndoWriter`: snapshots and `undo`), `reels_repository.dart` (`watchReelSummaries`, the name and description checks, `delete`), `clips_repository.dart` (`moveClips`, `watchReelClips`, the records), `app/lib/data/database/housekeeping.dart` (`selectOrphanClips`), `app/lib/data/database/clip_rules.dart` (`hasPicture`).
- Tests: `app/test/data/repositories/undo_test.dart`, new groups in `reels_repository_test.dart` and `clips_repository_test.dart`, and `import with duplicate names still loads` in `backup_service_test.dart`. `app/test/support/statement_log.dart` counts statements and injects failures.

**Try it yourself:**

```bash
(cd app && ../tool/flutter test test/data/repositories/undo_test.dart)
```

It ends with `All tests passed!`. Now, in `app/lib/data/repositories/undo_writer.dart`, delete the line `id: Value(clip.id),` in `_clipCompanion` and run it again. `undo remove restores an orphan-swept clip with its id and every field` fails with `Bad state: No element`: the clip came back under a new id, so nothing is found under the old one, and its link (which still names the old id) is not restored either. Undo your edit with `git checkout -- app/lib/data/repositories/undo_writer.dart`.

**Decisions:** D-84 (all of the above), which amends D-56 (names, the description, delete) and D-57 (the record-returning actions and `ReelClip`); D-80 (the owner's rules for names, the cap and Undo); D-71 (why a detached clip holds `-id` and has no identity to match).

## 6. Home

**What we built:** the Reels tab, which was a placeholder with only the Shooting mode card:

- **The Shooting mode section** on top, reused as it was (D-76): the access banner, the card, the clips-waiting banner.
- **Filter chips**: All, Collecting, Ready to edit, Published, each with a count. They appear once at least one reel exists.
- **The reel cards**, two to a row, newest first: a cover, the status pill, "3 clips · 1:05" and, when clips are gone from the phone, "2 missing". Tapping one opens that reel's page (still a stand-in until Task 8).
- **Two empty states**: "Plan your first reel" with a **New reel** button (no reels at all), and "No reels marked Published" with **Show all reels** (reels exist, but none with that status).
- **The New reel button** (a floating button, only while reels exist) that opens the sheet from Task 7.
- **A midnight tick**, so "On since 9:41 AM" turns into "On since Oct 27, 9:41 PM" when midnight passes while the screen is open.
- **A snack** "Couldn't open the camera." when the phone has no camera app that opens.

**Why TakeTray needs it:** Home is the first screen a person sees, and it has to tell the truth about three things at a glance: how many reels there are, what stage each is at, and whether any clip has gone missing. The two empty states matter as much as the full one: a first-time user must be told what a reel is, and a person looking at "Published" with none must be told how to get one, not shown a blank. The midnight tick and the camera snack are two small lies Phase 3 left behind: a date that stays wrong until something else redraws the screen, and a button that does nothing.

**Key ideas:**

- **The rules are two pure functions, so they can be tested without a screen.** A chip's count is over *all* reels, whatever filter is chosen; the cards are the reels that pass the filter, in the order they came.

  ```dart
  Map<ReelFilter, int> filterCounts(List<ReelSummary> reels) => {
    for (final filter in ReelFilter.values)
      filter: applyFilter(reels, filter).length,
  };

  List<ReelSummary> applyFilter(List<ReelSummary> reels, ReelFilter filter) {
    final status = filter.status; // null for "All"
    return [
      for (final summary in reels)
        if (status == null || summary.reel.status == status) summary,
    ];
  }
  ```

  Because the count *is* `applyFilter(...).length`, a chip can never say "Ready to edit 1" and then show two cards: both numbers come from one rule. The order is never changed here: the repository already sorts (newest created first, then the higher id, D-84).

- **The filter lives in the controller, and a new list does not reset it.** `HomeController` is an `AsyncNotifier`. Its `build` runs again every time the database list changes (a reel was added, a clip went missing) or the thumbnail cache becomes ready, so anything stored only in `build`'s local variables would be lost. The filter is a *field of the notifier object*, which Riverpod keeps across rebuilds:

  ```dart
  ReelFilter _filter = ReelFilter.all;
  List<ReelSummary> _all = const [];

  Future<HomeState> build() async {
    _cache = ref.watch(thumbnailCacheProvider).value;
    _all = await ref.watch(reelSummariesProvider.future);
    return _compose();
  }

  void setFilter(ReelFilter filter) {
    _filter = filter;
    if (state.hasValue) state = AsyncData(_compose());
  }
  ```

  `setFilter` composes a new state from the last list at once; it does not read the database again.

- **Nothing is shown until the first list has arrived.** If the screen drew "Plan your first reel" while the database was still being read, every phone with reels would flash the first-time screen for a few frames. So while `home` is null the screen has the app bar and the Shooting mode card and nothing else. The same goes for the FAB: `if (hasReels)`, never `if (home != null)`. (A mutation test changes exactly that and `FAB only with reels: none without` fails.)

- **Cards are built on demand.** `SliverGrid.builder` asks for a card only when it scrolls near the screen, so 25 reels build a screenful of cards, not 25. The test counts `TtReelCard` widgets and expects "more than zero and fewer than 25".

  ```dart
  SliverGrid.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: tt.spacing.s,
      crossAxisSpacing: tt.spacing.s,
      childAspectRatio: TtMetrics.reelCardAspect, // 4:5
    ),
    itemCount: home.reels.length,
    itemBuilder: (context, index) => _ReelCard(...),
  )
  ```

- **One thumbnail size for every card.** To tag asks for each picture at the tile's real height, which depends on the screen width. Home asks for all covers at `homeCoverSize` (240 logical pixels): a card is 4:5 and 160 to 190 dp wide, so it is never taller than about 240. The thumbnail cache stores one file per size, so one size means one file per video, on every phone. Until the cache is ready (`thumbnailCacheProvider` is a `Future`) `clipThumbnail` returns a picture that fails at once, which the card shows as its empty art; the controller watches the cache, so when it arrives the covers are replaced.

- **A timer that ends at midnight, not 24 hours later.** "On since" needs the date once midnight has passed, so the card must be built again then. `localDayProvider` is a stream that emits the local date now and at every following local midnight:

  ```dart
  void tick() {
    timer?.cancel();
    final now = clock.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    if (today != lastDay) {
      lastDay = today;
      days.add(today);
    }
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    timer = Timer(nextMidnight.difference(now), tick);
  }
  ```

  Two details carry the weight. `DateTime(y, m, d + 1)` is how Dart asks for "the start of tomorrow": it normalises the day number, so `d + 1` on the 31st is the 1st of the next month, and it lands on *local* midnight even when the day was 23 or 25 hours long (the night the clocks change in London). A timer of `Duration(hours: 24)` would be an hour out on those two nights a year. And when the timer fires but the clock still shows the same day (a timer can fire a moment early, or the clock was set back), nothing is emitted and the timer is set again, so a day is never announced twice. `ref.onDispose` cancels the timer when nothing watches the provider.

  `ShootingModeSection` and `ToTagScreen` just `ref.watch(localDayProvider)` and ignore the value: the watch is what makes them rebuild at midnight, and the rebuild reads the clock again.

  **A timer can be late.** On Android a phone that slept through midnight may not run the timer until later. So the provider also adds a `WidgetsBindingObserver` that calls `tick()` when the app is `resumed`: the new day is emitted at once. That is why `tick()` starts with `timer?.cancel()`: a resume must replace the pending timer, not add a second one. The test sets a clock by hand, never lets a timer fire, resumes the app and expects the new day.

- **Testing a timer: fake time, and a clock that follows it.** `fakeAsync` runs a block with a fake clock for `Timer`s: `async.elapse(Duration(hours: 8, minutes: 29, seconds: 59))` moves time forward and fires the timers due. But `Clock.now()` in the app is `DateTime.now()`, which fake time does not move. So the test makes a `Clock` that adds `async.elapsed` to a start time. The two London cases (`the London night in October is 25 hours long`, `... in March is 23 hours long`) only mean something when the computer's zone is London, so `tool/check` runs this file a second time with `TZ=Europe/London` (it is in `DST_TESTS`); in UTC they are skipped.

- **A snack that three buttons share.** `openCameraOrSay(context, ref)` is one function, used by the Shooting mode card, To tag's strip and To tag's "All caught up" button. It looks up the messenger *before* it awaits the camera, as in Task 7, so it can still speak if the screen has changed by the time the answer comes. The FAB moves up over the snack by itself: `TtFab` listens to `TtSnackHeight` (D-82) and Home does nothing for it. The test measures the drawn button (`Material` inside the `TtFab`, because the lift moves the paint, not the layout) and checks that it clears the snack by 12 dp and comes back down.

- **A stand-in page, kept very small.** A card must go somewhere, and the reel page is Task 8. `/reels/:id` is a child of `/reels`, and a bad id (`abc`, `0`, `1.5`, a number too big for an int) is sent back to Reels with the same log line as any unknown location, so a stale link cannot build a page for reel 0. `ReelDetailPlaceholder` is a `Scaffold` with an app bar; Task 8 replaces it.

- **Why a test timer needs care.** The test binding fails a test that ends with a `Timer` pending, and it checks *before* the tear-downs run. Riverpod disposes an unused provider later, through a scope that is already gone. So `pumpScreen` gives widget tests an inert `localDayProvider` (a stream that never emits), and a test about the midnight tick passes `midnightTick: true`, which disposes the container as the tree comes down. Whole-app tests (`tearDownApp`) dispose the containers they find. If you add a provider that owns a timer and a test fails with "A Timer is still pending even after the widget tree was disposed", this is why.

**Where it lives:**

- `app/lib/features/reels/view_models/reel_filters.dart` (`ReelFilter`, `filterCounts`, `applyFilter`) and `home_controller.dart` (`HomeState`, `reelSummariesProvider`, `HomeController`, `homeCoverSize`).
- `app/lib/features/reels/views/reels_screen.dart` (`ReelsScreen`, the chips, the cards) and `reel_detail_placeholder.dart`.
- `app/lib/core/midnight_tick.dart` (`localDayProvider`).
- `app/lib/features/shooting_mode/views/open_camera.dart` (`openCameraOrSay`).
- `app/lib/router/routes.dart` (`Routes.reel`) and `app_router.dart` (the `:id` child route and its redirect).
- Tests: `app/test/features/reels/view_models/reel_filters_test.dart`, `home_controller_test.dart`, `views/reels_screen_test.dart` (fake view models), `views/reels_tab_test.dart` (the whole app on a database), `app/test/core/midnight_tick_test.dart`, and the midnight and camera cases in `shooting_mode_section_test.dart`, `to_tag_screen_test.dart` and `app/test/router/app_router_test.dart`.

**Try it yourself:**

```bash
(cd app && ../tool/flutter test test/features/reels test/core/midnight_tick_test.dart)
(cd app && TZ=Europe/London ../tool/flutter test --run-skipped test/core/midnight_tick_test.dart)
```

Both end with `All tests passed!`. Now, in `app/lib/features/reels/view_models/reel_filters.dart`, change the condition in `applyFilter` to `if (status == null || filter == ReelFilter.ready || summary.reel.status == status) summary` and run `test/features/reels` again. `filter keeps order` fails with `Expected: [7]  Actual: [9, 8, 7, 5, 4, 2]`: the "Ready to edit" chip now shows every reel. Undo your edit with `git checkout -- app/lib/features/reels/view_models/reel_filters.dart`. Then in `app/lib/core/midnight_tick.dart` change the timer line to `timer = Timer(const Duration(hours: 24), tick);` and run the London command: `the London night in October is 25 hours long` fails with `Expected: DateTime:<2026-10-25 00:00:00.000>  Actual: DateTime:<2026-10-24 00:00:00.000>`. Run it in your normal zone and those two tests are skipped. This is why `tool/check` runs the file in London. Undo that edit too (`git checkout -- app/lib/core/midnight_tick.dart`).

**Decisions:** D-86 (all of the above); D-80 (Collecting, Home newest first, what waits for later phases); D-82 (`TtNavPill.fabBottom`, the FAB that follows a snack); D-84 (`watchReelSummaries`, the order); D-85 (`showReelForm`, the root messenger); D-76 (the Shooting mode section and the `m:ss` helper).

## 7. Create, edit, status and delete

**What we built:** the four things you can do to a single reel, plus the snack that lets you take a delete back:

- **The New reel / Reel details sheet** (`showReelForm`): a name (up to 40 characters, a counter), "Shot ideas" (up to 1,000, a counter that appears from 900), and, when editing, three status radios. **Create reel** or **Save** closes the sheet and shows "{name} created" or "Saved".
- **The status menu** (`reelStatusItems`, `changeReelStatus`): Collecting, Ready to edit, Published, each with its pill's icon and a line saying what it means, the current one checked. Choosing one shows "Marked as {status}".
- **The delete dialog** (`showDeleteReelDialog`): "Delete {name}?", a green "Your videos stay in your gallery" line, **Cancel** and **Delete reel**. Confirming goes to Reels and shows "{name} deleted" with **Undo**.
- **`showUndoSnack`**: one helper that every Undo snack in the phase uses (remove, move, add and delete).

Home (Task 6) and the reel page (Task 8) call these; this task builds them and tests them without those screens.

**Why TakeTray needs it:** a reel is the app's one real object, and a user must be able to name it, rename it, move it through its three stages and delete it. Deleting is the dangerous one: it also removes every clip that is in no other reel (D-56), so the owner asked for Undo (D-80). Undo is only worth having if it still works after the screen that deleted has gone, which is the part that needs care.

**Key ideas:**

- **A form that reports every problem in state, not exceptions.** `ReelsRepository.create` throws `InvalidInputException(ReelNameProblem.duplicate)`. That is right for a data layer, but a form wants "everything wrong, at once, in words". So `ReelFormController.save` checks first and puts the result in its state:

  ```dart
  final nameProblem = checkReelName(name) ??
      (clash == null ? null : ReelNameProblem.duplicate);
  final descriptionProblem = checkReelDescription(description);
  if (nameProblem != null || descriptionProblem != null) {
    _set(ReelFormState(nameError: nameProblem, descriptionError: descriptionProblem, clashingName: clash?.name));
    return null;
  }
  ```

  The view maps the enum to copy with a `switch`, which the compiler checks covers every case. The repository's own `duplicate` stays as a **backstop**: if another reel takes the name between this check and the write, the `catch` puts the same problem in the same state. The name in "You already have a reel called {name}" is the *other reel's stored name* (`clashingName`), because you typed "london food" and the reel is "London Food".

- **Single-flight: a second call gets the first call's future.** A double tap on **Create reel** must make one reel.

  ```dart
  final running = _inFlight;
  if (running != null) return running;
  final run = _save(name, description, status);
  _inFlight = run;
  ```

  The slot is cleared when the future ends, whether it returned or threw. `ReelActions.confirmDelete` does the same, per reel id (a map from id to the running delete). Two tricks keep it correct. The clearing goes through `run.then(ok, onError: ignore).then(clear)`, so a failed save does not make a second, unhandled copy of its error. And `_set` only touches the state `if (ref.mounted)`, because the sheet (the provider's only listener) can be dragged away while a save runs; the save still finishes.

- **Write only what changed, the refusable write first.** An edit has up to three writes (`rename`, `setDescription`, `setStatus`). The name goes first because it is the one that can still be refused (a clash after the check). If it is refused, nothing else was written, so the reel is not half edited. Saving a reel under its own name in another case ("goa" to "GOA") is allowed, because the clash check skips the reel being edited (`except: id`) and `rename` allows its own name (D-84).

- **A snack that outlives its screen has to be on the root messenger.** Every `Scaffold` registers with the nearest `ScaffoldMessenger`; the one `MaterialApp.router` makes is the root. A page that wraps itself in its own `ScaffoldMessenger` takes its snacks with it when it pops. So the app owns the key:

  ```dart
  // app.dart
  scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
  ```

  and `ReelSnacks.of(context)` looks the messenger up **once, while the context is alive**, along with the `ProviderContainer` and the words, and afterwards needs no context. This is why `showDeleteReelDialog` captures everything before it awaits the delete: by the time the delete ends, the screen may be gone. Undo calls `container.read(reelsRepositoryProvider).undo(record)`, which does not depend on any widget either. `showTtSnackOn(messenger, ...)` is the half of the package's `showTtSnack` that takes a messenger instead of a context, so it can run late.

- **Delete returns what Undo needs.** `ReelActions.confirmDelete` returns the `DeleteReelUndo` from Task 5. The snack holds that one object and hands it to `undo`. An empty record (`isEmpty`, the reel was already gone) shows no snack: there is nothing to take back.

- **A modal sheet tells its own failure inside itself.** A snack is drawn by the `Scaffold`'s messenger, which sits *behind* a modal sheet and its scrim. A first version showed "Something went wrong" as a snack: the test passed, because `find.text` also finds widgets that are covered, but nobody could see it. The rule is: while a sheet is open, its failure goes in the sheet (`SheetFooter(failure: ...)`, a warning `TtBanner` above the buttons with an icon and a live region); snacks come after it has closed. A test for "the user can see this" must use `.hitTestable()`.

- **Radios are a group of rows with a checked flag.** There is no `SemanticsRole.radio`; a radio is a node with `checked`, `inMutuallyExclusiveGroup` and a tap action, and the rows sit in a node with `role: SemanticsRole.radioGroup` named "Status". `excludeSemantics: true` plus one `label: 'Collecting, Still shooting clips for it'` makes a screen reader say one radio instead of a mark, a pill and a sentence.

**Where it lives:**

- `app/lib/features/reels/view_models/reel_form_controller.dart` (state, validation, single-flight), `reel_actions.dart` (`setStatus`, `confirmDelete`).
- `app/lib/features/reels/views/reel_form_sheet.dart`, `reel_status_menu.dart`, `delete_reel_dialog.dart`, `undo_snacks.dart` (`ReelSnacks`, `showUndoSnack`), `sheet_failure.dart` (`SheetFailure`, `SheetFooter`).
- `app/lib/features/shell/views/root_messenger.dart` (`rootMessengerKeyProvider`, `rootMessengerOf`), used by `app/lib/app.dart`.
- `packages/taketray_ui/lib/src/components/snack.dart` (`showTtSnackOn`) and `dialog.dart` (`TtDialog.icon`, `TtDialogNote`).
- Tests: `app/test/features/reels/view_models/reel_form_controller_test.dart`, `reel_actions_test.dart`, and `views/reel_forms_test.dart`, `views/delete_reel_test.dart`.

**Try it yourself:**

```bash
(cd app && ../tool/flutter test test/features/reels)
```

It ends with `All tests passed!`. Now, in `app/lib/features/shell/views/root_messenger.dart`, change the last line of `rootMessengerOf` to `return ScaffoldMessenger.of(context);` and run `test/features/reels/views/delete_reel_test.dart`. `the snack stays when a page that has its own messenger pops` fails with `Found 0 widgets with text "Goa deleted"`: the snack went to the page's own messenger and left with the page. Undo your edit with `git checkout -- app/lib/features/shell/views/root_messenger.dart`. Then delete the line `if (running != null) return running;` in `reel_form_controller.dart` and run `reel_form_controller_test.dart`: `double Save creates one reel` fails with `Expected: true  Actual: <false>`, because the second call is no longer the first call's future. Undo that edit too (`git checkout -- app/lib/features/reels/view_models/reel_form_controller.dart`).

**Decisions:** D-85 (all of the above), which builds on D-80 (the owner's rules: no duplicate names, the 1,000 limit, Undo on every delete) and D-84 (the repository, `DeleteReelUndo` and `undo`); D-82 (`TtMenuItem.checked` and `subtitle`, which the status menu uses).

## 8. Reel detail

**What we built:** the reel's own page, `/reels/:id`, which replaces Task 6's stand-in. From the top:

- **The app bar** has **Back** and a ⋮ menu (**Reel details**, **Select clips**, **Delete reel**) and no title.
- **The header** has the reel's name (wrapped over as many lines as it needs), the status pill that opens the status menu, "12 clips · 4:32" (or "No clips yet"), "2 missing" in red, and the **Shot ideas** block with **Show more** / **Show less**.
- **The clips** are grouped by the day they were shot: "Day 2 · Wed, Oct 28" and "3 clips", then a three-column grid. A tile shows the time **where the clip was shot**, its length, a layers badge when the clip is in two reels or more, and a mark when it is horizontal.
- **A clip whose video is gone** is a grey dashed tile with **Remove**. Remove takes it out of the reel and shows "Missing clip removed" with **Undo**.
- **Loading** is a skeleton day header and nine skeleton tiles. **No clips** is an illustration, "No clips yet" and a **Go to To tag** button.
- Opening the page **checks that the videos still exist**. A reel that is deleted while you look at it (or a link to one that never existed) sends you back to Reels.

Tapping a tile opens a stand-in for the viewer (Task 10 builds it). **Select clips** and a long press start choosing clips: section 9 explains that.

**Why TakeTray needs it:** this is where a creator decides whether a reel is ready. If a video was deleted from the gallery, the page must say so instead of showing a tile that cannot play (spec §4: a wrong or missing video is the worst bug). If a clip was filmed in London and tagged in India, it has to sit on its London day at its London time (spec §8.3a). And a long reel name or a big text size must never cut anything off.

**Key ideas:**

- **A state that can be "gone".** The page shows one reel, and that reel can disappear while it is open. `ReelDetailController.build` returns `Future<ReelDetailState?>`: `null` means "no such reel". A loading controller and a gone one are told apart with `detail.hasValue && detail.value == null`. The screen reacts in `build`, once, after the frame (the router must not be told during a build):

  ```dart
  final gone = detail.hasValue && state == null;
  if (gone) _leave();   // context.go(Routes.reels), after the frame, once
  ```

  A `ref.listen` would miss a value that is already there when the page first builds.

- **Verify once per open, without holding the page up.** The spec says clips are checked "when a reel is shown". `build` runs again for every change (a new list, the times arriving), and a verify itself changes the list, so a verify inside `build` would loop. The notifier keeps a flag, and a Riverpod notifier keeps its fields across rebuilds:

  ```dart
  if (!_verifyStarted && clips.isNotEmpty) {
    _verifyStarted = true;
    unawaited(_verify([for (final c in clips) c.clip]));
  }
  ```

  `_verify` goes through `guarded` and the existing `MediaVerifier`, so it needs full access, never calls an error "missing" (D-72), and runs on the same queue as scans. When it flags a clip the list stream emits again and the tile turns into the missing tile by itself.

- **Show first, refine later.** The clip times need a call to Android (`ClipTimeService.localTimes`). The controller does not wait for it:

  ```dart
  final times = ref.watch(reelClipTimesProvider(reelId)).value ?? const {};
  ```

  So the first state groups the days and shows the tiles with the phone's own time zone; when the answer comes, the state is built again with `times`, and the days are regrouped. `groupByShootingDay<ReelClip>` reads each clip's `wallClock` date, or the phone's local date for a clip with no time yet, so no clip is ever dropped. `wallClock` is a UTC-flagged `DateTime` whose fields are the clock where the clip was shot, so the code only reads its fields (`wallClockTimeText`, `ttDayWeekdayText`) and never calls `toLocal()` on it.

- **Do the thing only if it is still true.** The Remove button is on a tile that was drawn a moment ago. A verify might have found the video again since. `removeMissing` looks again (is the clip in this reel, and still flagged missing?) and returns an *empty* undo record if not; the screen shows no snack for an empty record. A double tap shares one future (single-flight, as in Task 7), so there is one removal and one record.

- **A grid whose rows follow the text size.** `TtMissingClipTile` holds an icon, a label that wraps to three lines at 2× text, and a 48 dp button. That needs about 192 dp, but a 3:4 cell on a 360 dp phone is 142 dp, so the tile used to shrink to 0.7 of its size. `TtMissingClipTile.heightFor(...)` measures what the tile needs with a `TextPainter` at the phone's text scale. A day with a missing tile gets that as its row height; the picture tiles beside it keep their 3:4 shape at the top of the cell:

  ```dart
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3, mainAxisExtent: max(natural, needed), ...
  ```

  A tile given an exact (tight) height fills it, so the missing tile is not shrunk, and the `Align` around the others loosens the constraint so they stay 3:4. At 1× text the number is smaller than 3:4, so nothing changes.

- **A date with its weekday, and the year only when needed.** The day header reads "Day 2 · Wed, Oct 28". `ttDayWeekdayText` picks the format by comparing years, and keeps the date in one piece by turning every space into a no-break space:

  ```dart
  final format = day.year == today.year
      ? DateFormat.MMMEd(locale)
      : DateFormat.yMMMEd(locale);
  return _keepTogether(format.format(day));
  ```

  The phone's language decides the order (en-IN: "Wed, 28 Oct"). Like `wallClock`, the date is only read, never converted.

- **The name belongs in the body.** An app bar clamps its title to one line at large text. The page's app bar has no title; `TtReelHeader` shows the name with no line limit, so even 40 emoji can be read.

**Where it lives:**

- `app/lib/features/reels/view_models/reel_detail_controller.dart` (`ReelDetailController`, `ReelDetailState`, `reelByIdProvider`, `reelClipsProvider`, `reelClipTimesProvider`).
- `app/lib/features/reels/views/reel_detail_screen.dart` (the page) and `clip_viewer_placeholder.dart` (the stand-in for Task 10).
- `app/lib/router/app_router.dart` and `routes.dart` (`Routes.clip`).
- `packages/taketray_ui/lib/src/components/clip_tile.dart` (`TtMissingClipTile.heightFor`).
- Tests: `app/test/features/reels/view_models/reel_detail_controller_test.dart`, `views/reel_detail_screen_test.dart`, `app/test/router/app_router_test.dart`, and `packages/taketray_ui/test/components/clip_tile_test.dart` (group `heightFor`). Helpers: `app/test/support/reel_videos.dart`.

**Try it yourself:**

```bash
(cd app && ../tool/flutter test test/features/reels/view_models/reel_detail_controller_test.dart)
```

It ends with `All tests passed!`. Now in `reel_detail_controller.dart` comment out the line `unawaited(_verify([for (final c in clips) c.clip]));` and run it again: `opening a reel verifies its clips` fails with `Expected: [Set:[1, 2]] Actual: []`, and `a video that is gone from the phone is shown as missing` fails too, because nothing flags the clip. Put the line back. Then open `reel_detail_screen.dart`, change `needed` in `_dayGrid` to `0.0` and run `reel_detail_screen_test.dart`: `the missing tile at 2x shows at its real size` fails because the text is drawn at a fraction of its height again.

**Decisions:** D-87 (all of the above); D-86 (the route, the stand-in and `localDayProvider`), D-85 (the status menu, the delete dialog, `ReelSnacks` and `SheetFailure`), D-84 (`ReelClip`, `RemoveUndo`, `undo`), D-83 (`ClipTimeService`, `groupByShootingDay`, `wallClock`), D-81 (the first shrinking missing tile) and D-72 (the verifier).

## 9. Multi-select and the reel picker

**What we built:** the way to work on several clips of a reel at once.

- **Choosing.** Long press a tile, or use **Select clips** in the ⋮ menu. The app bar turns into a coloured selection bar: a close button, "3 selected", and three buttons: **Add to another reel**, **Move to another reel** and **Remove from this reel**. A ⋮ has **Select all**. While choosing, a tap chooses or un-chooses a tile (it does not open the viewer), and Back ends choosing before it leaves the page.
- **The reel picker** is a sheet. It says "Add 3 clips to reels" (or "Move 3 clips to") and whether the clips stay or leave. It lists **New reel**, then your **Collecting** reels, then **Other reels**, each with a cover and "12 clips". The reel you are in is not listed. Add lets you tick several reels; Move lets you pick one.
- **New reel** turns into a name field with **Create**: the reel is made and ticked.
- **Every action ends with a snack and Undo:** "Added to London and Paris", "Moved to London", "2 clips removed from Goa. The videos are still in your gallery."

**Why TakeTray needs it:** after a day of shooting, the creator sorts: this clip also belongs in the Paris reel, those three were filed in the wrong reel, that one is bad. Doing it one clip at a time would be slow, and a misplaced tap must never lose a video, so every action can be undone, even after leaving the page.

**Key ideas:**

- **A rule lives in one small place.** What can be chosen is decided by `ReelSelection`, not by the tiles. It asks "is this clip in the reel's list and not missing?" and ignores anything else, so a missing tile cannot be chosen by a tap, a long press or Select all:

  ```dart
  void toggle(int clipId) {
    final next = {...state.selected};
    if (!next.remove(clipId)) {
      if (!_live.contains(clipId)) return;   // missing or not in this reel
      next.add(clipId);
    }
    state = next.isEmpty ? const ReelSelectionState() : ReelSelectionState(selecting: true, selected: next);
  }
  ```

- **A selection follows the data.** `ref.listen(reelClipsProvider(reelId), ...)` drops chosen clips that stop being valid (a verify finds a video gone). Otherwise the bar could say "3 selected" and run the action on a clip that is not there.
- **Pure functions for the picker's rules.** `pickerSections` removes the current reel and splits Collecting from the rest; `togglePick` is add (several, in tap order) or move (one). They are tested without a widget, and the mutation "move as multi-select" fails both a unit test and a screen test.
- **Reuse, don't copy.** The inline name field uses Task 7's `ReelFormController`, so "empty", "too long" and "already have a reel called" are checked in one place, and `reelNameErrorText` turns the problem into words for both the New reel sheet and the picker.
- **A sheet tells its own failure.** A snack shown while a sheet is open is hidden behind the sheet. So `showReelPicker` takes a `perform` function: confirm runs it, and if it throws the sheet stays open and shows the red line above its buttons. The page shows the success snack only after the sheet has closed:

  ```dart
  await widget.perform?.call(picked);
  if (mounted) navigator.pop(picked);
  ```

- **All or nothing across reels.** Adding to three reels is **one** database transaction: `ClipsRepository.addClipsToReels(reelIds, clipIds)` loops over the reels inside a single `_db.transaction`. If the third reel is gone, or a write fails, the transaction rolls back and the first two reels have nothing added either, so an error never leaves the clip in some of the reels and not others, and nothing has to be undone by hand. (The first version added reel by reel and undid the done ones after a failure; an undo that can itself fail is a weaker promise than a transaction.) It returns one `AddUndo` per reel, and the snack's **Undo** undoes every record, last to first (`ReelSnacks.showUndoAll`).
- **A double tap opens one picker, and a move of nothing says nothing.** `_picking` on the page ignores a second tap on Add or Move while a picker is open, as `_removing` does for Remove. If every chosen clip left the reel while the picker was open, the move moved nothing, so no "Moved to London" snack is shown (it would have had no Undo). The selection bar's title "3 selected" is a *live region* (`TtAppBar(liveRegion: true)`, only in selection mode), so a screen reader reads each new count.
- **Look things up before you wait.** The page gets the snack helper, the actions and the selection notifier before it awaits the sheet. The page may be gone by the time the work finishes, but the snack (on the app's root messenger) and its Undo still work.

**Where it lives:**

- `app/lib/features/reels/view_models/`: `reel_selection.dart`, `reel_picker.dart` (pure rules), `reel_clip_actions.dart`.
- `app/lib/features/reels/views/`: `reel_detail_screen.dart` (the selection bar and the three actions), `reel_picker_sheet.dart` (`showReelPicker`, `addedToText`), `undo_snacks.dart` (`showUndoAll`), `reel_form_sheet.dart` (`reelNameErrorText`).
- Tests: `app/test/features/reels/view_models/reel_selection_test.dart`, `reel_picker_test.dart`, `reel_clip_actions_test.dart`, and `views/reel_selection_screen_test.dart`.

**Try it yourself:**

```bash
(cd app && ../tool/flutter test test/features/reels/view_models/reel_selection_test.dart test/features/reels/views/reel_selection_screen_test.dart)
```

It ends with `All tests passed!`. Now in `reel_selection.dart` change `selected: _live` in `selectAll` to choose every clip, missing ones too, and run it again: `select all skips missing` fails with `Expected: Set:[1, 2]  Actual: Set:[1, 2, 3]`. Put it back. In `reel_picker.dart` delete the `if (s.reel.id != excludeReelId)` test: `picker excludes the current reel` fails with `has too many elements (3 > 2)`.

**Decisions:** D-88 (all of the above); D-84 (`addClipsToReel`, `moveClips`, `removeClipsFromReel`, `undo` and the records), D-85 (`ReelSnacks`, `SheetFailure`, `ReelFormController`), D-82 (`TtReelPickRow`, `TtReelPickNewRow`, `TtAppBar(selection: true)`), D-87 (the page).

## 10. The clip viewer

**What we built:** the full-screen viewer that opens when you tap a clip on a reel's page.

- **It plays the original video** straight from your gallery, with sound. Tap to pause and play, drag the bar to seek, and use the speaker button to mute (the viewer stays muted for the rest of the session).
- **Swipe left or right**, or use the ‹ › arrows, to move between the reel's clips. A clip that is missing from the phone is skipped. The arrows are dimmed at the first and last clip.
- **The top** says "2 of 5 · Goa" and, under it, the day and time where the clip was shot. A clip shot in London and looked at in India says "Wed, Jul 1 · 1:00 PM · London time".
- **The bottom** shows the scrubber, which reels the clip is in ("In  Goa  London"), and three actions: **Add to reel**, **Move** and **Remove**. Move and Remove carry on to the next clip (or the one before, at the end), and close the viewer when it was the last. Each ends with a snack with **Undo**.
- **"This video can't be played"** appears when the phone cannot play the file, with **Remove from reel**. It never plays another video instead.
- It is always dark and covers the whole screen, so the nav pill is not there.

**Why TakeTray needs it:** the creator checks a take before putting it in a reel or deciding it is bad. The one thing the viewer must never do is show the wrong video, so it plays only from the clip's stored identity and a missing clip is never played.

**Key ideas:**

- **A pure function decides what may play.** `clipVideoUri` builds `content://media/{volume}/video/media/{id}` from the clip's stored identity, and returns null when there is no usable identity or the clip is flagged missing. MediaStore numbers can be reused by another video after a delete, so a clip we know is gone has no address at all:

  ```dart
  Uri? clipVideoUri(Clip clip) {
    if (clip.missing) return null;
    switch (clip.source) {
      case ClipSource.mediaStore:
        final id = clip.mediaStoreId;
        final volume = clip.volumeName;
        if (id == null || id <= 0 || volume == null || volume.isEmpty) return null;
        return Uri(scheme: 'content', host: 'media', pathSegments: [volume, 'video', 'media', '$id']);
      case ClipSource.picker:
        ...
  ```

- **The pager is a view of the database, not a copy.** `ClipViewerController` takes the reel's clips from the same stream as the reel page and drops the missing ones. It remembers which clip it is on by *id*, and looks up its index each time. So when you remove the clip you are on, it is no longer in the list, and the controller simply picks the clip that took its place (or the last one, or nothing, which closes the screen). The same code handles Undo, another screen removing the clip, and a verify finding the video gone:

  ```dart
  var index = live.indexWhere((rc) => rc.clip.id == (_currentId ?? clipId));
  if (index < 0) {
    if (!_opened || live.isEmpty) return null;   // the asked-for clip cannot play, or none is left
    index = math.min(_lastIndex, live.length - 1);
  }
  ```

  The first clip is different on purpose: if the clip you tapped is not playable, the answer is `null` (go back), never "the nearest clip".
- **One player, owned by a provider.** `clipPlayerProvider(uri)` makes a `VideoPlayerController`, opens it and plays. Only the page showing watches it. When the page changes nobody watches the old one any more, Riverpod disposes it, and the `onDispose` callback disposes the controller. Popping the screen does the same. That is the whole "one controller at a time" rule, with no manual bookkeeping:

  ```dart
  ref.onDispose(() { pauser.stop(); unawaited(controller.dispose()); });
  await controller.initialize();   // throws for a video that cannot be played
  ```

- **Pause when the app is left.** The provider registers a `WidgetsBindingObserver` that pauses on `paused`. The plugin has one too, but it starts the video again when you come back; we turn it off (`allowBackgroundPlayback: true`, which only does that) and use ours, which does not.
- **Time where it was shot, never converted.** The header uses `ClipLocalTime.wallClock` as it is (D-83) and says the city only when `!isPhoneZone`. Until the zone answer arrives the line is empty: the phone's time would be wrong, and a wrong time is worse than none for a moment. But if the answer *fails* (an error, not "still loading") it will never come, so the line then shows the phone's own time, as the reel page's tiles do (`ClipViewerState.timesFailed`).
- **A swipe does not black out the page going away.** A `PageView` calls `onPageChanged` at the *middle* of a swipe, and the viewer then moves to the new clip. If only the page showing had its video, the half-visible old page would turn black at that moment. So the viewer remembers the clip it is leaving (`_outgoingClipId`) and keeps that page's player until the pager says the scroll has ended (`ScrollEndNotification`). For those few hundred milliseconds two players exist; after that, one. Each page's own **Remove** acts on *its* clip, not on "the clip showing", so a button on the old page cannot remove the new clip.
- **The "In" row does not blink.** The names of the reels a clip is in come from a provider made for each clip, so a new clip starts as "loading" and the row would disappear for a frame. The screen keeps the last names it showed and uses them until the new ones arrive.
- **The stage says what it is doing.** For a screen reader the video is a button with the label "Clip 2 of 5", the state "Playing" or "Paused", and the hint "Pause" or "Play": `Semantics(value: ..., hint: ...)`.
- **A clip that goes missing while you watch it** (a verify finds the video gone) leaves the pager like a removed clip: the viewer moves to its neighbour, which starts playing.
- **A fake player for tests.** `FakeVideoPlayerPlatform` replaces the plugin's platform layer, so the tests drive the real `VideoPlayerController` with no ExoPlayer. It records which addresses were opened and which players are still alive, so "disposed on page change" and "never played another clip" are plain assertions.
- **Snacks need a Scaffold.** The Undo snack is shown by the Scaffolds under the app's root messenger. The viewer covers the tab shell, so it has a Scaffold of its own, with the controls as its bottom bar so a snack sits above them.
- **A pop closes the top route.** The reel picker and the viewer are routes of the same navigator. If the viewer decided to go back while the picker was open, the pop would close the picker. So the viewer waits until the picker has closed.

**Where it lives:**

- `app/lib/platform/media_bridge.dart` (`clipVideoUri`).
- `app/lib/features/reels/view_models/`: `clip_viewer_controller.dart` (the pager, the leave rule, `clipReelNamesProvider`), `clip_player.dart` (`clipPlayerProvider`, `viewerMutedProvider`).
- `app/lib/features/reels/views/clip_viewer_screen.dart`; the route is in `app/lib/router/app_router.dart` (`parentNavigatorKey`).
- Tests: `app/test/platform/clip_video_uri_test.dart`, `app/test/features/reels/view_models/clip_viewer_controller_test.dart`, `clip_player_test.dart`, `views/clip_viewer_screen_test.dart`, `app/test/router/app_router_test.dart`, and the fake in `app/test/support/fake_video_player.dart`.

**Try it yourself:**

```bash
(cd app && ../tool/flutter test test/platform/clip_video_uri_test.dart test/features/reels/views/clip_viewer_screen_test.dart)
```

It ends with `All tests passed!`. Now in `clipVideoUri` delete the `if (clip.missing) return null;` line and run it again: `missing flag gives null` fails with `Expected: null  Actual: Uri:<content://media/...>`. Put it back. In `clip_player.dart` replace `unawaited(controller.dispose());` with a comment: `one controller alive; disposed on page change and on pop` fails with `Expected: contains 'dispose:1'`. In `clip_viewer_screen.dart` delete `!shot.isPhoneZone &&` and `header shows London time only when the zone differs` fails with `Actual: 'Thu, Jul 2 · 5:30 PM · Kolkata time'`.

**Decisions:** D-89 (all of the above); D-83 (`ClipLocalTime`, `zoneCity`), D-84 (`watchReelClips`, `watchReelIdsOf`, the undo records), D-85 (the root messenger and `ReelSnacks`), D-87 (the route and the reel page), D-88 (the picker and `ReelClipActions`), D-82 (`TtPlayerHeader`, `TtStageArrow`, `TtScrubBar`, `TtVideoSurface`, `TtReelTagRow`, `TtViewerActions`).

## 11. On the phone

**What we built:** one on-device test, `app/patrol_test/reels_test.dart`, that drives the real app on the Samsung S24 through the reel flows of this phase. The controller runs it on the phone; the unit and widget tests cannot prove the parts that need Android (a real video playing, the real media library, the real touch screen).

It walks through these steps in order:

1. From an empty Home, **New reel**, type "Patrol Reel", **Create reel**. The card shows on Home with the status Collecting.
2. Open the reel, then three dots > **Reel details**, rename it to "Patrol Reel Edited" and **Save**. Tap the status pill and choose **Ready to edit**; the pill changes.
3. Back on Home, one test video is put into the phone's media library and added to the reel. Open the reel: the **Day 1 · …** header and exactly one tile are there.
4. Tap the tile. The viewer says **1 of 1**, and the video plays: the position of the app's own player moves past 0 within 5 seconds.
5. Back on the reel, long press the tile, tap **Remove from this reel**. The reel is empty. Tap **Undo**: the tile is back, and it is the same clip (same id), not a second one.
6. Three dots > **Delete reel** > **Delete reel**. Home has no card. **Undo**: the card is back, with its clip. Then delete it again and let the message go: it is gone for good. The test video is deleted.

**Why TakeTray needs it:** two of the phase's worst bugs can only be seen on a phone. One is playing the wrong video, or none. The other is an Undo that quietly makes a second copy of a clip. A test with a fake player cannot see either. This test reads the real `VideoPlayerController` that the viewer is drawing, so "plays" means the player's own clock moved, not just that a widget was on the screen.

**Key ideas:**

- **Only its own video, in only its own folder (D-77).** The video is the 2-second fixture from `tool/make_test_video`. It goes into `Movies/TakeTray Test/` through a debug-only channel that deletes only files TakeTray Dev made. `TestMedia.start` registers the clean-up before anything can fail, so the video is deleted even if a step throws. The reel is deleted in a tear-down as well (in TakeTray Dev's own database).
- **Nothing broad is asked of the phone.** The watched folder is set to the test folder first. The test never asks for the photo permission, so the app stays in Manual mode: it does not scan, and opening a reel does not verify (the verifier does nothing without full access). The one MediaStore read is the test video's own row, by its id; the test also checks that the row is in the test folder before it uses it:

  ```dart
  final row = await rowOf(bridge, video);
  expect(_isTestFolder(row!.relativePath), isTrue);
  ```

- **The app's own words.** The test looks things up with `AppLocalizations` (`_l10n.reelsNewReel`, `_l10n.viewerTitle(1, 1, name)`), so a changed word changes the test, not the other way round. Icon buttons have no text, so they are found by the label a screen reader gives them:

  ```dart
  find.byWidgetPredicate((w) => w is TtIconButton && w.semanticLabel == label)
  ```

- **The clip is added the way Phase 7 will add one.** `ClipsRepository.addNewClipsToReel` with the video's real row (`newClipFrom`), through the app's own provider container, the way the other Patrol tests reach providers.
- **"Plays" is a number.** The test finds the `VideoPlayer` widget on the viewer, takes its `controller` and watches `value.position`. The video is only 2 seconds long and the player stops at its end, so a listener keeps the largest position seen, and the test fails with the player's state if it stays at 0 for 5 seconds. It never prints the player's error text, which can contain a content address (D-10).
- **No waiting for the screen to settle.** Like `media_scan_test`, it waits for each thing it needs with `waitFor` instead of `pumpAndSettle`, because a playing video and a counting-down snack never let a screen settle.
- **Snacks are timed.** A message with **Undo** stays for 6 seconds, so the test taps Undo straight after checking the result.

**Where it lives:** `app/patrol_test/reels_test.dart`; the helpers are in `app/patrol_test/support/` (`test_media.dart`, `waiting.dart`) and the video in `app/patrol_test/fixtures/test_video.dart`. How to run it, and the reminder to reinstall the normal debug build afterwards, are in `docs/dev-setup.md` ("Phase 4 check").

**Try it yourself:** you cannot run this one without the phone, but the compile check is the same as for the other Patrol tests:

```bash
(cd app && ../tool/flutter analyze patrol_test)
```

It ends with `No issues found!`. With the phone connected, unlocked and on the home screen: `tool/patrol test -d RZCY80PHWCZ -t patrol_test/reels_test.dart`, then reinstall the debug build as `docs/dev-setup.md` says.

**Result:** see the run in Task 11. This section says what the test checks; it does not say it passed. The controller runs it on the phone and reports the result.

**Decisions:** D-77 (the debug-only test-media channel: one folder, owner-only delete), D-89 (the viewer's player), D-84 (Undo records), D-85 (the root messenger for snacks).
