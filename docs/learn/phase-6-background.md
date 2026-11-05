# Learning guide: Phase 6, background detection and notifications

This guide explains how TakeTray notices new clips while it is closed, and how it reminds you without nagging: the new-clips notification, the evening reminder, the 14-day "Still shooting?" question, and what happens after a restart. It also covers the help screen for phones that stop apps in the background.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **The big picture first.** Until Phase 5, TakeTray only looked for new videos while it was open. Phase 6 adds a small piece of Android code that runs **without** the Flutter part of the app:
  - Dart keeps a **copy** of what that code needs (Shooting mode on or off, where each volume's scan stopped, the watched folders, the reminder settings) in Android's own storage;
  - an Android **job** wakes up when the phone's video library changes, counts the new videos and updates one quiet notification;
  - **alarms** fire the reminders;
  - the database stays Dart's alone: the only thing that flows back from Android is a button tapped in the notification shade.
- **Order.** The sections follow the order the phase was built, from Section 2 on. Step 1 was the plan and decision D-101 (what Phase 6 builds now and what waits), so it has no section here.
  - the design-system pieces (2);
  - the bridge between Dart and Android (3);
  - the new-clips job (4) and the reminders (5), in Kotlin;
  - Dart keeping the copy in step (6);
  - the screens: taps, the dialog, the permission and the help screen (7);
  - two media repairs parked from Phase 3 (8);
  - the proof on the phone (9).
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-101. "Spec §8.3" is a section of `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`.
- **Commands.** Run them from the repository root, through the wrappers in `tool/` (`tool/flutter`, `tool/check`, `tool/test_android`). Run a single Dart test file from `app/` (`cd app && ../tool/flutter test test/...`).
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Expandable card, step list and the success callout](#2-expandable-card-step-list-and-the-success-callout)
3. [The background bridge, the native state store and launch actions](#3-the-background-bridge-the-native-state-store-and-launch-actions)
4. [The new-clips job and notification](#4-the-new-clips-job-and-notification)
5. [Reminders, shade actions and re-arming](#5-reminders-shade-actions-and-re-arming)
6. [Dart keeps the native copy in step](#6-dart-keeps-the-native-copy-in-step)
7. [Notification taps, Still shooting?, the permission and the help screen](#7-notification-taps-still-shooting-the-permission-and-the-help-screen)
8. [Parked media repairs](#8-parked-media-repairs)
9. [On the S24](#9-on-the-s24)

## 2. Expandable card, step list and the success callout

**What we built:** three small pieces in `packages/taketray_ui`, ready for the "Notifications not arriving?" help screen (Task 7):

- **`TtExpandCard`**: a card with a header (a title, an optional small label such as "Your phone", and an arrow) that opens to show whatever you put inside it. Tap the header and it opens or closes.
- **`TtStepList`**: a numbered list, "1.", "2.", "3.", with the text lined up so a long step wraps under its own words and not under its number.
- **`TtCallout(success: true)`**: the existing note box with a new green look, for good news such as "Your clips are never lost".

**Why TakeTray needs it:** some phones (Samsung, Xiaomi, Oppo and others) stop apps in the background to save battery, so the "new clips" notification can be late or missing. The help screen has one card per phone brand, each with the steps for that brand and a button that opens the right Android settings page. The brand that matches the phone gets a "Your phone" label. At the top, a green note tells you the clips are safe either way. Screens in TakeTray never draw their own boxes and colours; they use package components, so these three had to exist first.

**Key ideas:**

- **The card does not remember whether it is open.** The caller keeps that fact and passes it in. This is the usual Flutter way: the screen can then keep one card open at a time, which the help screen wants, and a test can set either state directly.

  ```dart
  TtExpandCard(
    title: 'Samsung',
    badge: 'Your phone',
    expanded: open == 'samsung',
    onToggle: () => setState(() => open = 'samsung'),
    child: const TtStepList(['Open Settings...', 'Tap Never sleeping apps...']),
  )
  ```

- **A closed card does not build its body at all.** `if (expanded) Padding(...)` is in the card's column, so there is nothing hidden: no text for a screen reader to find, and no cost. The test `collapsed card hides the body` checks that the body text is not in the tree.

- **A screen reader hears one button, with its state.** The header is a `Semantics` node that is a button, says whether it is `expanded`, and has a label made of the title and the badge. Its own parts (the arrow, the badge) are hidden from the screen reader so they are not read twice:

  ```dart
  Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    expanded: expanded,
    label: [title, ?badge].join(', '),   // "Samsung, Your phone"
    onTap: onToggle,
  ```

  `?badge` is Dart's "add this only if it is not null". TalkBack then says "Samsung, Your phone, expanded" or "collapsed", because the `expanded` flag is what makes Android say that word. Two tests guard it: `expand card reports expanded` and `badge is read with the title`.

- **At least 56 dp tall, and the whole header is the tap target.** The CSS says `min-height: 56px`. A `ConstrainedBox(minHeight: 56)` inside an `InkWell` makes the full-width header the touch area, comfortably over Android's 48 dp.

- **Large text needed three small changes the prototype never had to think about.** The prototype does not scale its text; real phones do (spec §7 rule 2, and every golden is drawn at 1x and 2x). At 2x on a 360 dp phone the "Your phone" label next to "Samsung" left the title so little room that it broke into "Samsu" and "ng". The first golden showed it. So from a text scale of 1.5 the label moves under the title:

  ```dart
  final badgeBelow = badgeChip != null &&
      MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
  ```

  The step list does the same kind of thing: its number column is 20 dp at 1x, and 20 times the text scale at larger sizes, so a bigger "1." never touches the text. The header also has a little padding above and below that the CSS does not have, which changes nothing at normal size (the 56 dp minimum is already taller) and keeps a two-line title away from the card's edge.

- **A list that is a list.** Flutter has semantic roles; the step list is marked `SemanticsRole.list` and each item `SemanticsRole.listItem`, and each item's label is one string, "1. Tap Never sleeping apps...", so the number is read together with its step and not as a separate "1." The number and the text are two `Text` widgets side by side (so the second line of a long step hangs under the text), and `excludeSemantics: true` hides them from the screen reader so only the joined label is read.

  ```dart
  Semantics(
    container: true,
    role: SemanticsRole.listItem,
    excludeSemantics: true,
    label: '${i + 1}. ${steps[i]}',
  ```

  The `i + 1` matters: the list is numbered from 1. A test (`step list numbers its items`) fails if the numbers start at 0.

- **The success look is two colours from the theme, and the icon takes the text's colour.** A normal callout paints its icon in the accent colour; a warning and a success paint it in the container's text colour (`.callout.ok .ms { color: inherit }`). `warning` and `success` together make no sense, so the constructor has an `assert`:

  ```dart
  assert(!(warning && success), 'A callout is a warning or a success, not both'),
  ```

  An `assert` runs in debug and test builds and stops the program there; the test `warning and success assert` checks that.

- **Tests that can fail.** Each test was written first and run red (the new names did not exist yet), then green. Then each of five changes was made alone, to see the right tests fail, and undone: the `expanded` flag removed from the semantics ("Expected: Tristate.isFalse, Actual: Tristate.none"), the step numbers started at 0 (`Found 0 widgets with text "3."`), the success callout painted in the plain container, the badge left out of the label ("Expected: 'Samsung, Your phone', Actual: 'Samsung'"), and the body always built.

**Where it lives:** `packages/taketray_ui/lib/src/components/expand_card.dart` (`TtExpandCard`), `step_list.dart` (`TtStepList`) and `banners.dart` (`TtCallout`, the `success` flag); the few sizes that are not in the shared tokens are in `lib/src/theme/tt_metrics.dart` (`expandCardHeaderMinHeight`, `expandCardBadgeRadius`, `expandCardBadgePaddingVertical`, `stepListGap`). Tests: `packages/taketray_ui/test/components/expand_card_test.dart`, `step_list_test.dart`, `banners_test.dart` and `expand_card_golden_test.dart`. Widgetbook (the catalogue of components): `widgetbook/lib/components/expand_card.dart`, `step_list.dart` and `banners.dart`.

**Try it yourself:** see the test notice a missing "expanded" flag. From the repo root:

```bash
(cd packages/taketray_ui && ../../tool/flutter test test/components/expand_card_test.dart --plain-name "expand card reports expanded")
```

It ends with `All tests passed!`. Now open `packages/taketray_ui/lib/src/components/expand_card.dart`, delete the line `expanded: expanded,` inside the `Semantics(...)`, and run the same command. It fails with `Expected: Tristate:<Tristate.isFalse>` and `Actual: Tristate:<Tristate.none>`: without the flag a screen reader cannot say "collapsed". Put the line back, and run it again to see it pass.

**Decisions:** D-102 (all of this section), with D-101 (Phase 6's scope) as background.

## 3. The background bridge, the native state store and launch actions

_Filled in by Task 3._

## 4. The new-clips job and notification

_Filled in by Task 4._

## 5. Reminders, shade actions and re-arming

_Filled in by Task 5._

## 6. Dart keeps the native copy in step

_Filled in by Task 6._

## 7. Notification taps, Still shooting?, the permission and the help screen

_Filled in by Task 7._

## 8. Parked media repairs

_Filled in by Task 8._

## 9. On the S24

_Filled in by Task 9._
