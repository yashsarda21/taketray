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

To be written in Task 3 (decision D-120).

## 4. The editors bridge and the copy folder guard

To be written in Task 4 (decision D-121).

## 5. Copying in the app

To be written in Task 5 (decision D-122).

## 6. EditSessionService

To be written in Task 6 (decision D-123).

## 7. The copies reminder and the Done editing tap

To be written in Task 7 (decision D-124).

## 8. Design-system pieces for editors

To be written in Task 8 (decision D-125).

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
