# Learning guide: Phase 8, handing a reel to an editor

This guide explains how TakeTray hands a reel's clips to a video editor: CapCut and Instagram Edits get the original clips in one direct share, VN gets temporary copies in a folder, and TakeTray remembers which clips are in the edit, cleans the copies up and reminds the user about them.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-118 (the owner's decisions and the rulings made for the owner), so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-118.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Editing rules](#2-editing-rules)
3. [Schema v2 and the editing sessions repository](#3-schema-v2-and-the-editing-sessions-repository)
4. [The editors bridge and the copy folder guard](#4-the-editors-bridge-and-the-copy-folder-guard)
5. [Copying in the app](#5-copying-in-the-app)
6. [EditSessionService](#6-editsessionservice)
7. [The copies reminder and the Done editing tap](#7-the-copies-reminder-and-the-done-editing-tap)
8. [Design-system pieces for editors](#8-design-system-pieces-for-editors)
9. [Picking clips, the editor sheet, CapCut/Edits and Share](#9-picking-clips-the-editor-sheet-capcutedits-and-share)
10. [The VN copy screens](#10-the-vn-copy-screens)
11. [The reel page while editing](#11-the-reel-page-while-editing)
12. [CapCut/Edits add-later through the folder](#12-capcutedits-add-later-through-the-folder)
13. [The VN copies storage screen](#13-the-vn-copies-storage-screen)
14. [On the S24](#14-on-the-s24)

## 2. Editing rules

**What we built:** the small, pure pieces of logic that every later step of this phase leans on. They do no file or phone work; they take numbers and text and give back an answer.

- **`safeFolderName`**: turns a reel's name into a name Android's storage accepts for a folder (no forbidden characters, no hidden direction marks, at most 200 bytes).
- **`copyExtension` and `copyFileNames`**: decide what each copied file is called.
- **`spaceCheck`**: decides whether the copies fit and still leave the phone some room.
- **`byteSize`**: turns a number of bytes into "900 MB" or "1.3 GB" (the screen adds the unit word).
- **`splitForEditing` and `addPicks`**: decide which clips are "In your edit" and which are "New since you started editing", and what the add-later picker shows for each clip.
- **`EditorApp`** (CapCut, Edits, VN) and **`ClipRef`** (how the Android side finds a clip's video).

**Why TakeTray needs it:** a wrong answer here can overwrite a file, fill the phone, or hide a clip. Because they are plain functions, we can test every odd case (two clips shot in the same second, a reel called `Goa.`, exactly enough free space) on a laptop, long before any screen or phone code exists.

**Key ideas:**

- **A time held in a UTC box.** A clip's "when it was shot" is the clock on the wall where it was shot (D-83). It is stored in a `DateTime` marked UTC, but only because that type has no gaps: the number inside is just the wall-clock reading, not a real moment. So the file name reads the fields and never converts:

  ```dart
  return '$year-${two(t.month)}-${two(t.day)}_'
      '${two(t.hour)}-${two(t.minute)}-${two(t.second)}';
  ```

  Converting it to "local" would shift it by the phone's time zone and give a different name on a different phone.

- **Two clips, one second.** Names are `2026-10-12_14-32-05.mp4`. When the next clip has the same name (burst shots, or the hour that happens twice when clocks go back), it becomes `..._2.mp4`, then `_3`, in shooting order, and a name already in the folder counts too. Android treats `A.mp4` and `a.MP4` as the same file, so names are compared in lower case:

  ```dart
  for (var n = 2; used.contains(name.toLowerCase()); n++) {
    name = '${stem}_$n.${clip.extension}';
  }
  ```

- **Round first, then pick the unit.** If 999,500,000 bytes were rounded as MB it would read "1000 MB"; as GB it is "1 GB". So `byteSize` rounds to whole MB first and only then decides the unit. It uses whole-number maths only, because decimals like 0.1 cannot be stored exactly and rounding them can go wrong at the edge. One deliberate difference from the prototype: anything above 0 shows at least "1 MB".

- **Enough means enough plus 500 MB.** `spaceCheck` is true exactly when `free >= need + 500,000,000`. One byte less is short by exactly 1 byte, which a test checks.

- **A copy that is gone is not a copy.** `splitForEditing` and `addPicks` only look at the copies that still exist (`liveCopyIds`). If the user deleted a copy, the clip is "new" again (or "sent, not copied"), so TakeTray never claims a file is in the folder when it is not.

- **Bytes, not letters.** The app limits a reel name to 40 characters, but Android limits a folder name to 255 *bytes*, and a character can be many bytes (a family emoji is 18). `safeFolderName` drops whole characters from the end until the name is at most 200 bytes, so Android never shortens it behind our back (which would make the folder differ from the name we saved, and TakeTray would refuse to delete its copies).

- **Strings stored in the database are a promise.** `EditorApp.vn.name` is `"vn"`, and a test pins all three spellings, so renaming an enum value cannot silently orphan saved sessions.

**Where it lives:** `app/lib/domain/rules/` (`edit_folder_name.dart`, `copy_file_names.dart`, `space_check.dart`, `byte_size.dart`, `edit_split.dart`) and `app/lib/domain/models/` (`editor_app.dart`, `clip_ref.dart`), with tests in the matching `app/test/domain/` folders.

**Try it yourself:** `cd app && ../tool/flutter test test/domain/rules/copy_file_names_test.dart`. Then change `var n = 2` to `3` in `copy_file_names.dart` and run it again: the clash tests fail. Put it back.

**Decisions:** D-119, with D-118 (R2 names, R3 space) and D-83 (the wall-clock time) as background.

## 3. Schema v2 and the editing sessions repository

**What we built:** the app's first database migration, and the repository that remembers a reel's editing session.

- **Schema v2.** A session now records **which editor** it is for (`editor`: `capcut`, `edits` or `vn`), each copy records **when it was made** (`copied_at`), and a new table `sent_clips` records **which clips were sent** to the editor, and when.
- **`EditSessionsRepository`** (it was `VnRepository`): start a session, record sent clips and copies, remove copies, end the session, and three live streams: one reel's state, every reel's editor (for the cards) and a summary per session (for the storage screen and the copies reminder).

**Why TakeTray needs it:** phones already have version 1 databases full of reels and clips. The new app version must turn every one of them into version 2 **without losing or bending a single row**, and a phone can be switched off, or the app killed, in the middle of anything.

**Key ideas:**

- **Rename in code, not on the phone.** In Dart the tables are now `EditSessions` and `EditCopies`, but in SQL they stay `vn_sessions` and `vn_copies`. Renaming a table on a user's phone means rebuilding it; that is risk for no gain, so one line keeps the old name:

  ```dart
  @override
  String get tableName => 'vn_sessions';
  ```

- **Old rows get honest values.** Every version 1 session was a VN one, so `editor` defaults to `'vn'`. Version 1 never wrote down when a copy was made, so each copy takes its own session's start, the closest time we know:

  ```sql
  UPDATE vn_copies SET copied_at = COALESCE(
    (SELECT created_at FROM vn_sessions s
      WHERE s.reel_id = vn_copies.reel_id),
    0)
  ```

  `COALESCE(..., 0)` is a seat belt: a copy row with no session should never exist, but if one did, the upgrade would otherwise fail on it, and the app would fail to open every time after.

- **All or nothing.** Drift does not wrap a migration in a transaction by itself. Without one, a failure after the first `ADD COLUMN` would leave that column behind while the file still says "version 1"; the next start would try to add it again, fail with "duplicate column", and the app could never open its data. So the steps run in one transaction:

  ```dart
  await transaction(
    () => m.runMigrationSteps(
      from: from,
      to: to,
      steps: migrationSteps(from1To2: _from1To2),
    ),
  );
  ```

  Drift writes the new version number inside that same transaction, so "the steps ran" and "the file says version 2" always go together.

- **Never open a newer file.** If someone installs an older TakeTray over a newer one, the database is from the future. Opening it would stamp the wrong version on it, so the app refuses and leaves the file alone (`from > to` throws).

- **Recording twice is safe.** After a restart, TakeTray reads its copies back from the folder and records them again. `recordCopies` skips a copy it already has (same reel, clip and copy id), and `recordSent` keeps the first time a clip was sent. But a *different* copy for a clip that already has one is refused, with nothing saved: two rows would hide one of the files.

- **Backups stay the same.** Editing sessions describe files on *this* phone, so they are never exported. An import wipes all ten tables itself, `sent_clips` included, because those rows hold clip ids that would point at the wrong clips after the import.

**Where it lives:** `app/lib/data/database/` (`tables.dart`, `app_database.dart`, and the generated `app_database.steps.dart`), `app/lib/data/repositories/edit_sessions_repository.dart` and `app/lib/domain/models/` (`edit_session.dart`, `edit_copy.dart`, `sent_clip.dart`). The schema dumps are in `app/drift_schemas/taketray/`; the migration tests are in `app/test/drift/taketray/`.

**Try it yourself:** `cd app && ../tool/flutter test test/drift`. Then, in `app_database.dart`, change the UPDATE to set `copied_at` to just the `(SELECT created_at ...)` part, without the `COALESCE`, and run it again: the test with a copy row that has no session fails, because the whole upgrade now fails on it. Put it back. Or change `await transaction(` to `await (` in `onUpgrade` and watch the "fails half way" test fail.

**Decisions:** D-120, with D-54 (schema v1) and D-59 (the backup) as background.

## 4. The editors bridge and the copy folder guard

To be written in Task 4 (decision D-121).

## 5. Copying in the app

To be written in Task 5 (decision D-122).

## 6. EditSessionService

To be written in Task 6 (decision D-123).

## 7. The copies reminder and the Done editing tap

To be written in Task 7 (decision D-124).

## 8. Design-system pieces for editors

**What we built:** five small widgets that the editor screens (sections 9 to 13) share, all in `packages/taketray_ui`:

- **`TtStorageBar`**, the bar on the "Copy clips for VN" screen. When the copies fit, the bar is your free space and the copies are a violet part of it. When they don't, the bar is what the copies need: the part your phone has is grey, and the part it lacks is red stripes.
- **`TtBottomBar`**, the bar at the bottom of a picking screen ("3 videos picked", and the **Add** button). It was already on the Add videos grid; now it is a shared widget and the grid uses it.
- **`TtIllustratedSteps`**, the three little pictures on the "Ready for VN" screen: a phone with a big **+**, a folder list with one folder lit, and a grid of numbered clips.
- **`TtStatusLayout`**, a whole screen with an icon, a title, a few words and buttons at the bottom ("Phone storage is full", "Copying clips for VN").
- **`TtAppIcon`**, an editor's icon, or its first letters on a tile when Android gives us no picture.

**Why TakeTray needs it:** VN needs the clips copied, and that needs a space check, a copy screen, an error screen and a "now do this in VN" screen. Other editors reuse the same pieces. If each screen drew its own, they would drift apart and each would need its own tests for 2x text and dark mode.

**Key ideas:**

- **No wording in the package.** The package never holds a sentence. Every text is a parameter:

  ```dart
  TtStorageBar.short(
    haveFraction: 0.6,
    haveLabel: 'You have 1.8 GB',
    shortLabel: 'Short by 1.2 GB',
    semanticLabel: 'Copies need 3 GB, you have 1.8 GB, short by 1.2 GB',
  );
  ```

  Read it like this: the screen decides what the words are, in the user's language, and the bar only draws.

- **A fraction you can't misdraw.** `haveFraction` must be at least 0 and under 1. A share of 1 would mean "it fits", which is the other look, so the constructor refuses it (`assert`, in debug). In a release build there are no asserts, so a share that is NaN (a division by zero somewhere) or out of range goes through `unitShare` first, which turns it into something a layout can use. The copies' share in the other look is never drawn narrower than 4 %, or 8 MB next to 4 GB would be invisible:

  ```dart
  final share = math.max(
    unitShare(needFraction!),
    TtMetrics.storageMinNeedFraction,
  );
  ```

- **Odd input never crashes a screen.** A reel can have any number of clips, so `TtIllustratedStep.tiles` shows the first six and, with none, a plain picture. `TtStatusLayout` works in a list too (as tall as its content, with the buttons under it) instead of throwing when it has no height to fill.

- **One node for the bar.** A screen reader hears one sentence ("Free space 4.3 GB, copies need 1.2 GB"), not the bar, then each legend item again. The bar and legend sit under `ExcludeSemantics` inside one `Semantics(label: ...)`.

- **Pictures that don't grow.** At 2x text the sentences next to the pictures wrap and the step gets taller, but the pictures stay 112 by 132. They are drawings; their tiny text (9.5 and 8 dp) is inside `MediaQuery.withNoTextScaling`. A screen reader skips the pictures, except the folder list: the folder you must open is announced as **selected**, and Android supplies that word in the user's language.

- **A content area that scrolls, buttons that don't.** `TtStatusLayout` centres its block in the space above the buttons. At 2x on a short screen the block is taller than the space, so it scrolls and the buttons stay where they are.

- **A broken picture is not a broken icon.** `TtAppIcon` shows the letters tile when the bytes are empty, or when Flutter cannot decode them. A test gives it three garbage bytes and checks that the letters appear and nothing throws.

- **Tests that can fail.** All the tests were written first against empty stand-ins and failed for the right reasons (a missing widget, a wrong size, a missing assert). Then key lines were broken on purpose, one at a time, and each broke a named test: the 4 % minimum (removed, and lowered to 2 %), the solid and hatched parts swapped, each part of the `haveFraction` assert, the stripe angle and its start, `unitShare`'s NaN and clamp, the first-six cut, the padding numbers of the status layout, the legend's line gap and the step title's margin, the one-node semantics, the hatch's second stripe, the live region, the bottom inset, the selected folder, the badge numbers, the picture's text scaling, the warning colour, the scrolling, the heading, and the icon's two fallbacks.

**Where it lives:** `packages/taketray_ui/lib/src/components/` (`storage_bar.dart`, `bottom_bar.dart`, `illustrated_steps.dart`, `status_layout.dart`, `app_icon.dart`, and `internal/hatch_painter.dart`), their numbers in `lib/src/theme/tt_metrics.dart`, the Add videos grid in `app/lib/features/add_videos/views/add_grid_screen.dart`, the Widgetbook use cases in `widgetbook/lib/components/`. Tests: `packages/taketray_ui/test/components/*_test.dart` and `*_golden_test.dart`.

**Try it yourself:** see the 4 % minimum work. From the repo root:

```bash
cd packages/taketray_ui && ../../tool/flutter test test/components/storage_bar_test.dart --plain-name "at least 4 %"
```

It ends with `All tests passed!`. Now open `lib/src/components/storage_bar.dart`, find `_enough`, and change `math.max(needFraction!, TtMetrics.storageMinNeedFraction)` to just `needFraction!`. Run the test again: it fails, because a copy of 0.1 % now draws a bar a third of a dp wide. Put the line back and run it again to see it pass.

**Decisions:** D-125 (all of this section), with D-118 (the Phase 8 decisions), D-19 (design tokens only), D-42 (the Widgetbook covers every component) and D-61 (CI goldens) as background.

## 9. Picking clips, the editor sheet, CapCut/Edits and Share

To be written in Task 9 (decision D-126).

## 10. The VN copy screens

To be written in Task 10 (decision D-127).

## 11. The reel page while editing

To be written in Task 11 (decision D-128).

## 12. CapCut/Edits add-later through the folder

To be written in Task 12 (decision D-129), after the owner's two hand checks (the gate before Task 12).

## 13. The VN copies storage screen

To be written in Task 13 (decision D-130).

## 14. On the S24

To be written in Task 14 (decision D-131).
