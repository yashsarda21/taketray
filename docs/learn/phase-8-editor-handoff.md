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

- **A leading dot goes, a trailing one with a mark stays.** A folder whose name starts with a dot is hidden on Android, so `safeFolderName` drops a leading dot together with any combining marks after it. At the end, a dot with a mark is kept (the name no longer ends in a dot, which is what the file system minds). The Arabic letter mark, the line and paragraph separators and the byte order mark are removed too.

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

- **A write that changes nothing wakes nobody.** `watchEditors` (which reel is in which editor, for the cards on Home) only emits when that map changes, so saving a session's folder name does not redraw every card. Copies and sessions are turned into models by one shared pair of functions, so a new column is added in one place.

**Where it lives:** `app/lib/data/database/` (`tables.dart`, `app_database.dart`, and the generated `app_database.steps.dart`), `app/lib/data/repositories/edit_sessions_repository.dart` and `app/lib/domain/models/` (`edit_session.dart`, `edit_copy.dart`, `sent_clip.dart`). The schema dumps are in `app/drift_schemas/taketray/`; the migration tests are in `app/test/drift/taketray/`.

**Try it yourself:** `cd app && ../tool/flutter test test/drift`. Then, in `app_database.dart`, change the UPDATE to set `copied_at` to just the `(SELECT created_at ...)` part, without the `COALESCE`, and run it again: the test with a copy row that has no session fails, because the whole upgrade now fails on it. Put it back. Or change `await transaction(` to `await (` in `onUpgrade` and watch the "fails half way" test fail.

**Decisions:** D-120, with D-54 (schema v1) and D-59 (the backup) as background.

## 4. The editors bridge and the copy folder guard

**What we built:** the Android side that talks to the editors and to TakeTray's copy folders, and the Dart wrapper the screens use (`EditorsBridge`).

- **Which editors are installed** (`EditorApps`), with each app's icon drawn to a small PNG for the editor sheet.
- **The shares** (`ShareIntents`): one Android "send" of the chosen clips to CapCut or Edits, the same through Android's share sheet (**Other app...**), an editor's own launcher, and its Play Store page.
- **The copy folders** (`CopyFolder`): which folders exist under `Movies/TakeTray/`, which recorded copies are still there, deleting copies, and every file in the folders for the storage screen.
- **The guard**: the one check every delete TakeTray makes goes through.
- **Android's consent dialog** (`DeleteRequests`) for copies TakeTray may not delete itself.
- **A debug-only intent recorder**, so the phone tests can check what would be sent without opening another app.

**Why TakeTray needs it:** TakeTray promises never to touch your original videos (D-04), but VN gets *copies*, and copies have to be cleaned up. A delete with the wrong number would remove someone's real video. So deleting is the most dangerous thing this phase does, and it is done in one place, behind one check.

**Key ideas:**

- **Three facts must all match before anything is deleted.** A copy is recorded as "MediaStore id, folder, file name". Before deleting, the guard reads the row with that id and checks its folder, its name and who made it:

  ```kotlin
  ): Boolean = inPlace(rowPath, rowName, ref) && CopyFolderPath.isOwn(rowOwner, ourPackage)
  ```

  ```kotlin
  plainSegment(ref.folderName) &&
      CopyFolderPath.isInFolder(rowPath, ref.folderName) &&
      rowName != null &&
      rowName == ref.fileName
  ```

  Android records which app created each file (`OWNER_PACKAGE_NAME`), and only TakeTray can have created a file under its own name. If Android rebuilt its media list and gave the number to another video, the name or the owner will not match, and the row is **refused**: reported, never touched.

- **"In the folder" means exactly that folder.** `CopyFolderPath` is one tiny shared rule (the copy engine in section 5 uses the same file):

  ```kotlin
  fun relativePath(folder: String): String = "$ROOT$folder/"
  ```

  ```kotlin
  rowRelativePath != null && rowRelativePath.equals(relativePath(folder), ignoreCase = true)
  ```

  Comparing the whole path (and not "starts with") is what keeps `Movies/TakeTray/Goa/sub/`, `Movies/TakeTray/Goa2/` and the tests' own `Movies/TakeTray Test/` out. A test that turns it into a "starts with" check proves the tests notice.

- **Check, then delete only if it is still the same.** Between reading a row and deleting it, the row could change. So the delete itself repeats the three facts as its condition, and deletes nothing if they no longer hold:

  ```kotlin
  "${MediaColumns.RELATIVE_PATH} = ? AND ${MediaColumns.DISPLAY_NAME} = ? AND ${MediaColumns.OWNER_PACKAGE_NAME} = ?",
  ```

- **A failed read is never "gone".** If Android's media list does not answer, the bridge reports an error instead of an empty list. Otherwise TakeTray would think every copy had vanished and forget them.

- **Files TakeTray no longer knows ask you first.** After a reinstall, TakeTray's old copies belong to "nobody" as far as Android is concerned. TakeTray never deletes those itself; it asks Android to show its own "Allow TakeTray to delete these?" dialog, and only for files that are in a copy folder with their exact name.

- **Order is the whole point of a share.** CapCut and Edits build one project from the clips in the order they arrive, so the list goes to Android in shooting order, and the same order goes into the second list Android uses for access (`ClipData`):

  ```kotlin
  Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
  ```

  The share also says which app it is for (`setPackage`), and grants that app permission to *read* those clips, never to change them.

- **Android 11 hides other apps.** An app can only see another app if its manifest names it in `<queries>`. Without the three `<package>` lines, CapCut would always look "not installed". A Dart test checks that every editor in `EditorApp` is in the manifest.

- **Slow work off the main thread, screens on it.** Reading the package list, the media list or the free space can take a moment, so it runs on a background thread (`Dispatchers.IO`); opening another app stays on the main thread, where Android expects it.

- **Testing without a phone.** The Kotlin tests run on the laptop (Robolectric) against a small real SQLite table set up the strict way Android's media provider sets one up, so a query Android would reject fails on the laptop too. On the phone, the Patrol tests turn on the debug recorder and read back what *would* have been sent ("2 clips, `external_primary:30`, `external_primary:4`, read granted"), so a test never opens CapCut.

- **One answer per file.** If the same copy is named twice in one delete call, `deleteCopies` looks at it once, so a file is never both "deleted" and "gone".

**Where it lives:** `app/pigeons/editors_api.dart` (the contract), `app/lib/platform/editors_bridge.dart` (Dart), `app/android/app/src/main/kotlin/app/taketray/editors/` (Kotlin: `CopyFolder.kt`, `CopyFolderPath.kt`, `ShareIntents.kt`, `EditorApps.kt`, `DeleteRequests.kt`, `EditorsHostApiImpl.kt`, `ActivityStarter.kt`), `app/android/app/src/debug/kotlin/app/taketray/DebugEditorHooks.kt` (debug only), the `<queries>` in `app/android/app/src/main/AndroidManifest.xml`. Tests: `app/android/app/src/test/kotlin/app/taketray/editors/` and `app/test/platform/editors_bridge_test.dart`.

**Try it yourself:** `tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.editors.CopyFolderTest'`. Then, in `CopyFolder.kt`, delete `&& CopyFolderPath.isOwn(rowOwner, ourPackage)` and run it again: the test with another app's file fails, because that file would now be deleted. Put it back.

**Decisions:** D-121, with D-04 (originals are never touched), D-57 (a picked clip is read only through its grant) and D-77 (the same owner-and-folder rule for the test videos) as background.

## 5. Copying in the app

**What we built:** the Android code that copies a reel's clips into `Movies/TakeTray/<Reel>/` for VN, while TakeTray stays open:

- **`CopyEngine`**: one object for the whole app process that owns at most one copy job.
- **`CopyJob`**: the loop that copies one clip after another.
- **`CopyStore`**: everything the loop asks of Android's media library (make a file, open the original, publish, delete), behind one interface so the loop can be tested without a phone.
- **`CopyHostApiImpl`** and **`copy_bridge.dart`**: the bridge between Dart and Kotlin (a Pigeon contract, `pigeons/copy_api.dart`), and **`KeepScreenOn`**, which keeps the screen on while the copy screen shows.

**Why TakeTray needs it:** VN cannot take several shared clips at once, so it gets copies in a folder. Copying gigabytes is the one place this phase writes and deletes files in shared storage, so a mistake here could leave half a video in the gallery or delete something the user still needs.

**Key ideas:**

- **Invisible until complete.** Each copy starts as a *pending* row (`IS_PENDING 1`): other apps cannot see it. Only when every byte is written, and the count matches the original, does TakeTray publish it. A half file is never visible, and if anything goes wrong the pending row is deleted:

  ```kotlin
  val expected = if (source.length >= 0) source.length else item.sizeBytes.takeIf { it > 0 }
  if (expected != null && written != expected) {
      Log.w(COPY_LOG_TAG, "copy item failed: length differs")
      return Outcome.FAILED
  }
  val published = store.publish(rowId)
  ```

  The length check comes **before** `publish`; a test fails if the two lines swap.

- **The job outlives the screen.** The job lives in `CopyEngine.shared(context)`, not in the activity. When the phone rotates or the user leaves the app, the activity is destroyed and re-made, but the process (and the copy) goes on; the new screen asks `current()` and gets the job. If Android kills the whole process, the job is gone. There is no journal file: TakeTray's own finished files in the folder are the record, and the pending ones are cleaned up on the next start (`ownRowsIn`, `deletePendingIn`, used by the next task).

- **Stop means "delete what was copied".** Pressing Stop sets a flag; the loop checks it before every 1 MB chunk. Then, on the same background worker (so it never deletes a file it is still writing), it deletes the pending file and every copy *this job* made. A copy that cannot be deleted is reported in `undeleted`, never silently forgotten.

- **Only ever our own file.** Every delete first looks the row up and checks three things: it is in exactly `Movies/TakeTray/<Reel>/` (not `TakeTray Test`, not a sub-folder), it was made by TakeTray, and it has the name we recorded. Anything else is left alone.

- **Two safety margins.** Before the job, Dart keeps 500 MB free (section 2). During the job, Kotlin refuses a file unless the file plus 50 MB fits, and treats "no space left on device" while writing as "space full": the earlier copies stay and **Try again** (`resume`) continues from the clip that did not fit, never from the start.

- **Progress without flooding.** The screen gets an update at most every 250 ms while a file copies, and always when a file finishes. A 200-clip job does not send thousands of messages.

- **The screen stays on without a permission.** `FLAG_KEEP_SCREEN_ON` on the activity's window keeps the phone awake while the window shows; it needs no permission and no notification (unlike a foreground service, which the owner chose not to use).

- **Two refusals in a row mean it is not the names.** If MediaStore refuses one file's name, that clip fails and the copy goes on; if it refuses two in a row, TakeTray stops (resumable) because the cause is somewhere else. A hung read of an original can still hold the Stop button; that is parked for later, not fixed.

**Where it lives:** `app/android/app/src/main/kotlin/app/taketray/editors/` (`CopyEngine.kt`, `CopyJob.kt`, `CopyStore.kt`, `CopyHostApiImpl.kt`, `CopyFolderPath.kt`), `app/pigeons/copy_api.dart`, `app/lib/platform/copy_bridge.dart`, the debug hooks in `app/android/app/src/debug/kotlin/app/taketray/DebugCopyHooks.kt`, and the tests in `app/android/app/src/test/kotlin/app/taketray/editors/` and `app/test/platform/copy_bridge_test.dart`.

**Try it yourself:** `tool/test_android --tests 'app.taketray.editors.CopyJobTest'`. Then, in `CopyJob.kt`, change `item.sizeBytes + NATIVE_FLOOR_BYTES` to `item.sizeBytes` and run it again: the space-floor test fails. Put it back.

**Decisions:** D-122, with D-118 (no foreground service, R4 one job at a time) and D-119 (names and the 500 MB reserve) as background.

## 6. EditSessionService

**What we built:** the one class that runs an editing session from start to finish, `EditSessionService`, and the `CopyJobController` the copy screens follow:

- sending the original clips to CapCut or Edits, and sharing to any app;
- planning a copy (which clips, how much space, which folder), starting it, recording each copy as it finishes, finishing, cancelling and trying again;
- Done editing (delete the copies, end the session);
- deleting a clip's copy before the clip leaves the reel, and every copy before a reel is deleted;
- the numbers for the storage screen, with the "orphan" copies no session knows;
- and, after Android stopped TakeTray in the middle of a copy, putting the record straight at the next start.

**Why TakeTray needs it:** the earlier sections built the pieces (the rules, the tables, the guard, the copy engine). Each piece is safe alone, but the order in which they are used decides whether a file is ever lost track of. This service is that order, in one place.

**Key ideas:**

- **One queue.** Every method that writes waits for the one before it to finish (`_serial`). So "remove this clip" can never run half way through "record the copy that just finished", and Done editing can never interleave with Stop. It is the simplest lock there is: a chain of futures.

  ```dart
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }
  ```

  The second line keeps the queue going when a call fails.

- **Write the record first, then act; take it back if the act fails.** A share to CapCut first writes the session and the "sent" rows, then shares. If CapCut is not installed, the service removes exactly what it added (`recordSent` tells it which rows were new), so clips sent earlier stay "In your edit".

- **The plan is saved before the copy starts.** The copy runs in Android; if Android stops TakeTray mid-copy, the job is gone. So before starting, Dart saves the plan (which folder, which clip gets which file name) in the settings table. At the next start TakeTray deletes the half-written (pending) files, reads the finished ones in the folder, and matches them to the plan **by file name**, never by size (two clips can have the same size). Each finished copy is recorded once: recording one that is already recorded changes nothing.

- **Copies go first.** Before a clip leaves an editing reel, its copy is deleted; if it cannot be, the clip stays (and the user sees "Couldn't delete the copies"). Before a reel is deleted, its copy job is stopped, its copies deleted and its session ended, so Undo brings the reel back without a session.

- **Done editing is never stuck.** A copy job that is over (finished but never continued, cancelled, stopped for space, or left from before a restart) does not block Done editing: the service settles it first (records its copies, clears it, removes its plan), then deletes the copies. Only a job that is still running makes it refuse. A copy Android's guard will not delete (the file in that place is no longer TakeTray's) does not block it either: it is reported in `leftBehind` and the file is left for the storage screen.
- **Every way out of a reel deletes the copies first.** Remove, move, a missing clip's removal and a reel delete do it from their screens; Undo of an add or a move, Undo of an add by hand, tagging a clip out of a reel, sending it back to To tag and merging a duplicate do it through a hook the repositories hold (`BeforeClipsLeave`), which the service sets when it is built.
- **A resumed job keeps its id.** The copy screen follows the id, so the controller counts a result as "unseen" per id and end state: a job that went back to running and finished is shown again, and a job that ended for good (`clearedJobs`) is dropped so no screen opens for it.

- **Nothing stuck.** A session with no copies and no sent clips (a first copy that never finished, a share that was interrupted) is ended at the next start.

- **Retry, and one call at a time.** A recovery that failed (the phone's folder could not be read) is tried again at the next app resume, until it works; the app no longer waits for it before saving the new clip baselines. Two taps on the same send or copy are one call, but a different editor or different clips for the same reel are their own call. Which copy job is "older" is decided by the order the app saw them in, not by the time written in the job's name, so a phone clock set back cannot hide a new job.

**Where it lives:** `app/lib/data/editors/edit_session_service.dart`, `app/lib/features/editors/view_models/copy_job_controller.dart`, `app/lib/domain/models/copy_job_plan.dart`, the `copyJobPlan` key in `app/lib/data/repositories/phone_state_repository.dart`, and the hooks in `app/lib/features/reels/view_models/` and `app/lib/app/media_lifecycle.dart`. Tests: `app/test/data/editors/edit_session_service_test.dart` and `app/test/features/editors/copy_job_controller_test.dart`.

**Try it yourself:** `cd app && ../tool/flutter test test/data/editors/edit_session_service_test.dart`. Then, in `_recover`, change `if (rows[i.fileName] case final row?)` so that it looks the row up by size instead (for example build `rows` keyed by `r.sizeBytes` and look up `i.sizeBytes`) and run it again: "matches by file name, never by size" fails, because a file would be recorded for the wrong clip. Put it back.

**Decisions:** D-123, with D-118 (R1, R4, R5, R8), D-120 (the tables), D-121 (the guard) and D-122 (the copy engine) as background.

## 7. The copies reminder and the Done editing tap

**What we built:** a third reminder, beside "You shot 3 clips today" and "Still shooting?". Three days after the last copies of an edit were made, TakeTray posts one notification per reel: "Wedding copies are using 1.2 GB", "Done editing? Tap to clean up." Tapping it (or its **Done editing** button) opens that reel's page, where the app asks to clean up (the dialog itself comes in section 11).

**Why TakeTray needs it:** VN copies are real files in `Movies/TakeTray/`, and nothing else tells the user they are still taking space. The reminder is the nudge, and it works while the app is closed, like the other two: no Flutter engine runs, the database is never read, only a small copy of the facts Dart keeps written for it (the "mirror", D-103).

**Key ideas:**

- **One new fact in the mirror.** Dart writes one `CopiesReminder` per editing session that has copies: the reel's id and current name, the copies' total size and when the newest was made. A session with no copies (CapCut and Edits only share, until a clip is added later) has none. Phones that stored the mirror before this phase load it with an empty list:

  ```kotlin
  copiesReminders =
      if (!o.has("copiesReminders")) emptyList() else { ... }
  ```

- **Three days is elapsed time.** `copiesDueAt(last) = last + 3 x 24 hours`, nothing fancier: not "10 in the morning", not "three calendar days". It does not move when the phone changes time zone or the clocks go back.
- **Once per batch, not once per day.** The receiver writes down `(reelId, lastCopiedAtMs)` *before* it posts. A reboot, a second delivery or a rewrite of the mirror finds the mark and stays quiet; a new copy batch has a new time, so it is reminded again. Marking before posting means a failed post, or notifications switched off, is not retried for that batch: the same rule Still shooting? has.
- **One alarm, many reels.** The alarm carries no reel. It is set for the earliest reminder that is not shown yet; when it fires, the receiver shows every reminder that is due and then arms the next one. A reel whose session ended in the meantime is not in the mirror any more, so nothing is posted for it, and the next write of the mirror removes its notification too.
- **Ids that cannot collide.** Phase 6 uses notification ids 1 to 3 and request codes up to 303. The copies reminder of reel `r` is notification `1000 + r`, its taps use request codes `1_000_000 + 2r` and `+ 1`, and its one alarm uses 400. A reel id outside 1 to 1_073_241_823 is ignored (it could land on Phase 6's ids, or overflow a request code), and the largest valid one ends exactly at `Int.MAX_VALUE`:

  ```kotlin
  private fun copiesRequestCode(reelId: Long): Int = (COPIES_REQUEST_BASE + 2 * reelId).toInt()
  ```

- **The tap is an allow-list with one payload.** Android sends `doneEditing` and a reel id, never a route (deep linking is off). Kotlin keeps the id only for `doneEditing` and only when it is a usable one; Dart then checks the reel still exists and opens `/reels/<id>?done=1`, or Reels when it does not. Taps are opened in the order they came, because looking up a reel takes a moment and a later tap must not be overtaken.
- **Private on the lock screen.** The reel's name is the one piece of user text in any TakeTray notification. The lock screen shows only "TakeTray" and "Copies for an edit are still on your phone".

- **A new batch removes the old reminder's text.** If more copies arrive after a reminder was shown, its notification (which still says the old size) is taken away, and the new batch gets its own reminder 3 days after its last copy. Taps are opened one after another through a small queue, and a tap that fails is logged by type and does not block the next.

**Where it lives:** `app/android/app/src/main/kotlin/app/taketray/background/` (`BackgroundState.kt`, `BackgroundStateStore.kt`, `ReminderTimes.kt`, `ReminderScheduler.kt`, `ReminderReceiver.kt`, `Arming.kt`, `Notifier.kt`, `LaunchActions.kt`), `app/pigeons/background_api.dart`, `app/lib/data/background/background_sync.dart`, `app/lib/platform/background_bridge.dart`, `app/lib/features/notifications/view_models/launch_actions.dart`, `app/lib/app.dart` and `app/lib/router/routes.dart`. The on-phone hook is `showCopiesReminderNow` in `src/debug`. The tests are `CopiesReminderTest.kt` (the alarm, the receiver, the notification, arming and a reboot) and the matching existing Kotlin and Dart test files.

**Try it yourself:** `tool/test_android --tests 'app.taketray.background.CopiesReminderTest'`. Then, in `ReminderTimes.kt`, change `COPIES_AFTER_DAYS` to 2 and run it again: the alarm tests fail. Put it back, and change the receiver's `store.copiesShown(it.reelId) != it.lastCopiedAtMs` to `== null`: the test for "a new copy batch is reminded again" fails. And in `launch_actions_test.dart` the "taps in a row" test fails if you remove the queue in `app.dart`.

**Decisions:** D-124, with D-101 (notifications), D-103 (the mirror), D-105 (the reminders) and D-118 (R6) as background.

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

**What we built:** the first screens of the hand-off. On a reel's page an **Edit video** button opens a screen where you tick the clips you want ("Pick clips to edit"), with a bar at the bottom that says how many, how long and how big. **Continue** opens a sheet, "Edit 4 clips in…", with **CapCut**, **Instagram Edits**, **VN** and **Other app…**. CapCut and Edits get your original clips in one share, in the order you shot them. VN goes on to the copy screens (section 10). Other app… opens Android's share menu. The viewer also got a **Share** action, and the ⋮ menu of a reel's page, while you are choosing clips, now has **Edit video** and **Share**.

**Why TakeTray needs it:** this is the moment a reel leaves TakeTray. Everything that can go wrong happens here: the editor is not installed, the share fails, a clip went missing a second ago, someone taps twice. The service from section 6 makes sure the writes are right; these screens decide what the user sees for each outcome.

**Key ideas:**

- **Where a failure is told.** A sheet is modal: a snack shown while it is open lies behind its dark curtain, where nobody sees it. So when sending to CapCut fails, the line "Couldn't open CapCut. Try again." appears **inside the sheet**, which stays open for another try. When the send works, the sheet and the picking screen close and the snack goes on the app's root messenger, where it outlives them:

  ```dart
  case SendResult.failed:
    setState(() { _busy = false; _failed = editor; });
  ```

- **The sheet's own guard, because the service has one too.** `sendOriginals` is single-flight per *reel*: a second call while one runs gets the first call's answer, whatever editor it names. A tap on Edits a moment after a tap on CapCut would therefore be told "Sent to Edits" for CapCut's share. So the sheet keeps a `_busy` flag, every row ignores taps while it is set, and the sheet cannot be dragged away while a send runs (`PopScope(canPop: !_busy)`).
- **A question that comes after the screen is gone.** After a send, 1.3 seconds later, TakeTray asks "Mark Goa as Ready to edit?", but only if the reel is still Collecting at that moment. By then the picking screen and the sheet are gone, so the wait cannot belong to them: it is a plain `Future.delayed`, and the dialog is shown from the root navigator's overlay. It takes the app's `ProviderContainer`, not a `WidgetRef`: Riverpod refuses a ref once its widget is disposed.
- **Choosing, not guessing.** The picking screen's choice lives in a controller that follows the reel's clips: a clip that goes missing leaves the choice, a clip from another reel can never be ticked, and the ids handed on are sorted by when they were shot, never by id. Ids in the address (`/edit?reel=3&clips=8,2`) are cut down the same way, so a stale link cannot send a clip that is not there:

  ```dart
  _selected = (_seeded ? _selected : args.preselected.toSet())
      .intersection(liveIds);
  ```

- **No editor is a wall.** An editor the phone lacks is greyed out with "Not installed". If asking the phone fails, all three look installed and the share decides, because a sheet that shows nothing is worse than one that answers "not installed" after a tap. That answer opens a dialog with **Open Play Store** and **Choose another**; the sheet stays, asks the phone again, and the row turns grey.
- **The button hides while you are editing.** A reel can be in one editing session at a time (R1), so **Edit video** is gone from the button and the menu until Done editing. The button also waits until the database has said "no session", so it never flashes and vanishes.

- **Small things that were tightened.** The "Sent" snack uses the open-in-new icon; a send that fails because every picked clip is gone says so (retrying cannot help); coming back from the Play Store refreshes the greyed-out editors; a share menu that fails to open says "Something went wrong" instead of "missing"; clip ids in a location must be plain digits; and at large text the picker's title wraps instead of reading "Pick cli…".

**Where it lives:** `app/lib/features/editors/views/` (`edit_select_screen.dart`, `editor_sheet.dart`, `editor_missing_dialog.dart`, `mark_status_dialog.dart`, `open_share.dart`, `editor_text.dart`), `app/lib/features/editors/view_models/` (`edit_select_controller.dart`, `editor_choices.dart`), `app/lib/router/` (`routes.dart`, `app_router.dart`), and the reel page and viewer in `app/lib/features/reels/views/`. Tests: `app/test/features/editors/` (`edit_select_screen_test.dart`, `editor_sheet_test.dart`, `mark_status_dialog_test.dart`, `edit_select_controller_test.dart`, and the macOS-only `editors_golden_test.dart`), `app/test/router/app_router_test.dart`, and the new groups in `reel_detail_screen_test.dart`, `reel_selection_screen_test.dart` and `clip_viewer_screen_test.dart`.

**Try it yourself:** run the double-tap test, then break its guard:

```bash
cd app && ../tool/flutter test test/features/editors/editor_sheet_test.dart --plain-name "a tap on another editor"
```

It ends with `All tests passed!`. Now open `lib/features/editors/views/editor_sheet.dart`, find `_choose`, and delete the line `if (_busy) return;`. Run it again: it fails, because the second tap (on Instagram Edits) joins CapCut's send and the snack names the wrong editor. Put the line back. For the Ready to edit rule, change `reel.status != ReelStatus.collecting` in `_offerReady` to `false` and run `--plain-name "a published reel gets no offer"`: it fails because a Published reel is asked too.

**Decisions:** D-126 (all of this section), with D-85 (a sheet tells its own failure inside), D-118 (R1 and R5), D-123 (the service) and D-125 (the bottom bar and the app icon) as background.

## 10. The VN copy screens

**What we built:** the three screens a VN copy goes through. First a **space check**: "Copy clips for VN", "These 12 clips need 900 MB", "You have 6.2 GB free.", a bar that shows the copies' share of the free space, two notes (why VN needs copies, and that the copies are temporary) and **Copy 12 clips**. When the phone is too full, the same screen says "Not enough space" instead, with a bar whose red hatched end is what is missing, and **Select fewer clips**. Then the **copying screen**: "Copying clips for VN", "7 of 12 clips", a progress bar, "Keep TakeTray open until copying finishes. The screen stays on until then." and **Cancel**. Last the **ready screen**: "Ready for VN", three pictured steps (tap New project, open the folder, select all the clips) and **Open VN**. In between are the screens for when it does not go well: "Phone storage is full", "Copying stopped" (TakeTray was closed in the middle), "1 clip couldn't be copied" and "The clips couldn't be copied".

**Why TakeTray needs it:** copying is the one job in this app that makes the user wait, and the one that can go wrong in the most ways: the phone fills up, the system closes the app, a video was deleted a minute ago. Without a foreground service (decision 2 of D-118) a copy only goes on while TakeTray runs, so the screen has to say "keep me open", keep the phone awake, and always know what to show when the copy stops.

**Key ideas:**

- **The bar counts the reserve.** TakeTray never fills the last 500 MB of the phone. So when the phone has 1.2 GB free and the copies need 1 GB, the bar shows 0.7 solid ("what you really have") and "Short by 300 MB", not "you have enough". The number is a small pure function of the plan:

  ```dart
  final usable = plan.freeBytes - copyReserveBytes;
  if (usable <= 0) return 0;
  final share = usable / need;
  return share >= 1 ? _belowOne : share;
  ```

- **One word for what a job is doing.** The engine has five states, and a finished job can have failed clips. `copyStageOf(job)` turns that into one of seven stages (`running`, `finished`, `someFailed`, `allFailed`, `spaceFull`, `interrupted`, `cancelled`), and the screen is a `switch` over it. A clip listed twice counts once, and "every clip failed" is `failed >= total`, so a bad count from below can never crash the screen.
- **The phone stays awake only while a copy runs.** Dart decides (`CopyBridge.keepScreenOn`), and the rule is written once, in `_syncScreen`: on for `running`, off for every other stage, off when Stop begins, off when the screen leaves, off in `dispose`. A flag left on would keep the user's screen lit for ever, so the last one is the one that matters. And when the app comes back to the front it asks again, because Android may have made a new activity whose window never got the flag.

  ```dart
  void _setScreen(bool on, {bool force = false}) {
    if (_screenOn == on && !force) return;
    _screenOn = on;
    unawaited(_askBridge(on));
  }
  ```

- **First copy or add?** Stopping a first copy says "No copies were kept." and removes the whole session; stopping an add keeps the older copies and says "The new copies were deleted.". The screen learns which it is from the saved plan (`jobContext(...).startedSession`), and reads it **before** it cancels, because cancelling removes the plan.
- **An exit that fails keeps the screen.** `cancelCopy` and `finishJob` can throw ("not cleared yet"). The screen then says "Something went wrong. Try again." under the words (a snack would cover the buttons) and keeps working. When the engine did cancel but could not clear the result, the Cancel button turns into **Try again**.
- **A job that is gone is a normal ending.** After a finish, a cancel or Done editing, the controller's job is `null`. A screen that sees `null` after it has seen the job goes back to the reel without a word; a screen that has not seen the job yet reads the engine once before it gives up, because the first event can arrive after the start call returns.
- **Results nobody saw.** If Android closed TakeTray mid-copy, the next start builds an `interrupted` job from the folder. `CopyResultOpener` (in the app's `builder`) asks `takeUnseenResult()` and opens the copying screen for it, once. It does the same when the app comes back to the front, and for a copy that still runs with no screen left.
- **Words that other editors reuse.** The titles and the result lines take `{editor}` (VN passes "VN"), so Task 12 does not rewrite them. Bold words inside a translated sentence use two tiny helpers: `boldMark('New project')` wraps a part in a marker character and `boldSpans(text)` turns the marked parts into bold spans.

- **The screen does not guess.** The copy count and the failure line are live regions, so TalkBack says them when they change; the progress title is empty until the job's plan is read (so a CapCut job never says VN for a frame); the ready screen shows no half sentence about a blank folder; and a failed re-plan while a copy is starting does not flash "Couldn't start copying".

**Where it lives:** `app/lib/features/editors/views/` (`copy_space_screen.dart`, `copy_progress_screen.dart`, `copy_ready_screen.dart`, `stop_copy_dialog.dart`, `copy_result_opener.dart`, `editor_text.dart`), `app/lib/features/editors/view_models/` (`copy_space_controller.dart`, `copy_ready_controller.dart`, `copy_stage.dart`, `copy_screens.dart`), `app/lib/router/` (`routes.dart`, `app_router.dart`), `app/lib/app.dart` and `app/lib/l10n/app_en.arb`.

**Try it yourself:** run the screen-on tests, then break the rule that matters most:

```bash
cd app && ../tool/flutter test test/features/editors/copy_progress_screen_test.dart --plain-name "the screen is let go on every way out"
```

They end with `All tests passed!`. Now open `lib/features/editors/views/copy_progress_screen.dart`, find `dispose` and delete the line `_setScreen(false);`. Run the command again: "the whole app goes away (dispose)" fails, because the last call to the bridge is `true`, which on a phone would leave the screen lit. Put the line back. For the reserve, change `plan.freeBytes - copyReserveBytes` in `copy_space_controller.dart` to `plan.freeBytes` and run `test/features/editors/copy_space_screen_test.dart`: the bar test for 1.2 GB against 1 GB fails (it gets 1 instead of 0.7).

**Decisions:** D-127 (all of this section), with D-118 (decision 2, R3, R4, R5), D-122 (copying and the screen flag), D-123 (the service and the job controller) and D-125 (the bar, the status layout and the steps) as background.

## 11. The reel page while editing

**What we built:** the reel's own page while the reel is being edited. Under the reel's name a banner says where the edit is: "Editing in VN · 1.2 GB" over "4 copies in Movies/TakeTray/Goa food trip", with **Done editing** and **Add more clips** (CapCut and Edits: "Editing in CapCut" over "Sent on Oct 30", with **Done editing**). The clips come in two parts: "New since you started editing" (clips the editor does not have yet, with **Copy to VN folder**) and "In your edit". **Done editing** asks "Have you exported your video?", deletes the copies, says "Copies deleted · 900 MB freed" and, a moment later, offers "Mark Goa as Published?". **Add more clips** opens the clip picker in an add mode, where the clips already in the folder are ticked and locked. Around it: Home's cards get an "Editing in VN" pill, the delete dialog says the copies go too, and every remove, move or undo that has to delete a copy first says so, or says "Couldn't delete the copies. Try again." and changes nothing.

**Why TakeTray needs it:** once a reel is in an editor, the question the user has is "what is left to do?". New clips keep arriving (a clip tagged after the first send), copies can be deleted in the gallery, and a copy that stays forever wastes gigabytes. The page answers the question, keeps the folder in step with the reel, and makes the clean-up one tap.

**Key ideas:**

- **The split is one union.** A clip is "in your edit" when it was sent to the editor **or** its copy is in the folder; everything else is new. Missing clips stay where they were, and a clip tagged in meanwhile is new at once, because the split follows the reel's clips:

  ```dart
  final split = splitForEditing<ReelClip>(
    clips,
    (c) => c.clip.id,
    sentIds: edit.sentIds,
    liveCopyIds: {for (final c in edit.copies) c.clipId},
  );
  ```

  A recorded copy counts as live because opening the page checks the copies once (`verifyCopies`): the ones deleted outside TakeTray are forgotten, so their clips are new again.
- **Two parts, one calendar.** Each part has its own day headers, but a part never renumbers its days: Day 2 is still "Day 2" when it is the only day with new clips. `_daysOf` cuts the reel's own days down to a part's clips and drops the empty ones.
- **Done editing is never offered mid-copy.** `doneEditing` refuses a running copy job, so the page does not even show the button then: the banner says "Copying clips for VN", "7 of 12 clips" and **Show**. One tiny function decides it, and both the banner and the dialog use it:

  ```dart
  CopyJob? runningCopyJobOf(CopyJob? job, int reelId) =>
      job != null && job.reelId == reelId && job.state == CopyState.running
      ? job
      : null;
  ```

- **The question fits the editor.** With copies, VN warns that "the VN project for **Goa** can't be edited any more", CapCut that "clips you added to your CapCut project from the folder may show as missing", and both say what it frees. Without copies (CapCut and Edits got the originals) nothing is deleted, so the question is "Done editing Goa?" and the button says **Done editing**. Any failure says "Couldn't delete the copies. Try again." and the session stays, so the user can just tap again.
- **The Published offer outlives the page.** It waits 900 ms on the app (not on the page), then asks from the root navigator with the provider container, the same way the Ready to edit offer works after a send.
- **A locked tile is locked in the controller, not only on screen.** In the add picker a clip whose copy is in the folder is always ticked, and the user's own ticks never contain it:

  ```dart
  void _set(Set<int> next) {
    if (state.value == null) return;
    _selected = next.difference(_inFolder);
    state = AsyncData(_stateNow());
  }
  ```

  So a tap on it (which only says "Already in the VN folder…") can never tick it behind the scenes for the day its copy is deleted in the gallery.
- **A dialog that stays.** The delete dialog now keeps itself open while the delete runs: a `PopScope` in its content turns each button, Back and a tap outside into a decision. When the copies cannot be deleted, the reel is not deleted and the dialog says so under its text, ready for a second try.
- **`?done=1` asks once per page.** The copies reminder opens `/reels/<id>?done=1`. The page decides the first time it knows whether there is a session, and never again, so going to the viewer and back does not ask twice.

- **Check first, then ask.** The Done editing question first checks that the copies are still there, so "This frees 600 MB" is true. A delete dialog taken away from outside still gets its result (Undo snack and Reels). The running-job banner leaves its title empty for the moment before the plan says which editor.

**Where it lives:** `app/lib/features/reels/view_models/reel_edit_state.dart` (the split, `runningCopyJobOf`, the editors for Home), `app/lib/features/reels/views/` (`reel_edit_banner.dart`, `reel_edit_sections.dart`, `reel_detail_screen.dart`, `reels_screen.dart`, `delete_reel_dialog.dart`, `undo_snacks.dart`, `reel_picker_sheet.dart`), `app/lib/features/editors/views/done_editing_dialog.dart`, the add mode in `app/lib/features/editors/{view_models/edit_select_controller,views/edit_select_screen}.dart`, `app/lib/router/app_router.dart` and `app/lib/l10n/app_en.arb`.

**Try it yourself:** run the split's tests, then break the union:

```bash
cd app && ../tool/flutter test test/features/reels/view_models/reel_edit_state_test.dart
```

They end with `All tests passed!`. Now open `lib/features/reels/view_models/reel_edit_state.dart` and change `sentIds: edit.sentIds,` to `sentIds: const {},`. Run it again: "a sent clip with no copy is in the edit (the union, not only copies)" fails, because a clip sent to CapCut would show up as new. Put it back. For the lock, change `_selected = next.difference(_inFolder);` in `edit_select_controller.dart` to `_selected = next;` and run `test/features/editors/edit_select_controller_test.dart`: "a tap on a folder clip never ticks it behind the scenes" fails.

**Decisions:** D-128 (all of this section), with D-118 (decisions 5 and 7, R1, R8), D-119 (the split), D-123 (the service and Done editing), D-124 (the reminder's `?done=1`) and D-126 (the Published offer's way of asking) as background.

## 12. CapCut/Edits add-later through the folder

**What we built:** the same "add more clips later" for a reel being edited in CapCut or Instagram Edits. The first send to these editors is a share of the originals (nothing copied). When more clips arrive afterwards, the reel page's "New since you started editing" part has a button, **Add to your CapCut project** (or **Add to your Edits project**), and the banner has **Add more clips**. Both open the clip picker in add mode: "Add clips to your CapCut project", where a clip whose copy is already in the folder is ticked, locked and marked "In the folder", a fresh clip starts ticked, and a clip that was sent but has no copy can be ticked (the user may have deleted it from the project). The bottom bar says "3 clips to copy" over "450 MB · into Movies/TakeTray/Goa". **Copy** goes through the same space check, copying screen and ready screen as VN, with CapCut's words: "{editor} adds clips to a project from an album", "Copying clips for CapCut", and "Ready to add in CapCut" with three steps: open your project, open the **Goa** album, pick the new clips.

**Why TakeTray needs it:** the owner tried it by hand (the gate before this task). CapCut's and Edits' "add media to a project" pickers do show a `Movies/<folder>` album, in shooting order, so copying the new clips into the reel's folder is enough. But sharing to either app always opens a **new** project and never offers "add to an existing project", so a direct share of the new clips would not land in the user's project. The folder is the only way to add to a project that already exists.

**Key ideas:**

- **The service already did it.** `sendOriginals` starts the session, so a CapCut reel has a session with sent rows, and `planCopy`/`startCopy` already took an `EditorApp`. A second batch goes into the session's folder (a rename of the reel does not move it) and its names are chosen against the names the session's copies and the folder already have, so a clash becomes `_2` and an earlier copy is never renamed. This task is mostly screens learning to say the editor's name.
- **Words by editor, one rule.** The picker, the space check and the ready screen each pick VN's sentence or the project sentence from one boolean (`vn`). New strings take `{editor}` or `{folder}`; the old VN ones stay as they were, so no VN screen changed.
- **A job names its own editor.** The running-job banner used to guess VN when the page had no session yet. Now it asks the job's saved plan (`copyJobEditorProvider`, the same source the copying screen reads), then the session, and VN only as a last resort.
- **Ready after every CapCut or Edits copy.** A VN add goes back to the reel's page with a snack, because VN's folder list is still open in the user's head. A CapCut or Edits copy always goes to "Ready to add in {editor}", because the next thing the user must do is go to the editor and add from the album.
- **Sent is not copied.** The lock is for clips with a live copy only. A clip that was sent but has no copy in the folder is selectable, because the user may have removed it from the project and wants it back:

  ```dart
  : sentIds.contains(id)
      ? AddPick.sentNotCopied
      : AddPick.fresh,
  ```

- **A long title wraps, without losing a button.** "Add clips to your CapCut project" does not fit a one-line app bar next to **Select all**. The title wraps (`wrapTitle`), which needs the bar to be the first child of the body instead of `Scaffold.appBar`, and at large text **Select all** moves under it. A first try that only set `wrapTitle` lost the button at 2x, and no test noticed until a test looked for it.

- **One layout from the first frame.** In add mode the picker's bar is always in the body, so it never jumps when the session (and so the editor's name) is read.

**Where it lives:** `app/lib/features/editors/views/` (`edit_select_screen.dart`, `copy_space_screen.dart`, `copy_progress_screen.dart`, `copy_ready_screen.dart`), `app/lib/features/editors/view_models/edit_select_controller.dart` (`addFolder`), `app/lib/features/reels/views/` (`reel_edit_banner.dart`, `reel_edit_sections.dart`, `reel_detail_screen.dart`), `app/lib/features/reels/view_models/reel_edit_state.dart` (`copyJobEditor`) and `app/lib/l10n/app_en.arb`.

**Try it yourself:** run the folder tests, then break the lock:

```bash
cd app && ../tool/flutter test test/features/editors/edit_select_controller_test.dart --plain-name "CapCut and Edits"
```

They end with `All tests passed!`. Now open `lib/features/editors/view_models/edit_select_controller.dart` and change `if (value == AddPick.inFolder) key,` to `if (value == AddPick.inFolder || value == AddPick.sentNotCopied) key,`. Run it again: "the session is the editor: a clip sent but not copied is selectable…" fails, because a clip the user may want back can no longer be ticked. Put it back. For the folder, open `lib/data/editors/edit_session_service.dart`, change `final folder = session!.folderName;` to `final folder = safeFolderName(await _reelName(reelId));` and run `test/data/editors/edit_session_service_test.dart --plain-name "second batch"`: both tests fail, because a renamed reel would start a second folder.

**Decisions:** D-129 (all of this section), with D-118 (decision 4, R1, R6, R8), D-123 (the service), D-127 (the copy screens) and D-128 (the page and the add picker) as background.

## 13. The VN copies storage screen

**What we built:** a screen that shows what the editing copies take on the phone, and lets the user take the space back. Settings has a new **Clips** group with one row, "Storage used by VN copies", that says "1.8 GB in 3 reels" (or "None") and opens the screen. The screen shows the total, then one row per reel that has copies: its cover, its name and "3 copies · 900 MB · since Oct 5" ("3 copies for CapCut · …" for the other editors), with a red **Delete**. Under the rows, a green note says deleting copies never touches the original clips. If some files in the copy folders belong to no reel (left from an earlier install, a backup import, or files that were changed outside TakeTray), a group "Not linked to a reel" lists them by folder, each with its own **Delete**. Without full video access a callout says TakeTray cannot find the files left from an earlier install.

**Why TakeTray needs it:** copies are big (a 4K clip is hundreds of MB) and live in shared storage, where the user can see them in the gallery. The reminder (section 7) and Done editing (section 11) are the normal ways to delete them, but a user who forgot, or who reinstalled the app, needs one place that shows what is left and what it costs. After a reinstall TakeTray has no record of the old copies at all, and Android does not let one install delete another install's files without asking the user. That is why the files with no reel use Android's own consent dialog.

**Key ideas:**

- **Delete is Done editing.** A reel's **Delete** opens exactly the question the reel page asks ("Have you exported your video?") by calling the same function with one switch turned off:

  ```dart
  showDoneEditingDialog(context, ref, reelId, suggestPublished: false);
  ```

  The switch is the "Mark Goa as Published?" offer that follows on the reel's page. It makes sense there, where the user has just finished a reel, and not here. Nothing else is copied: the words, the guard and the failure message are the dialog's, so they can never drift apart.
- **The list follows the database.** The controller watches the summaries stream and reads `storage()` again whenever it changes. Nobody tells the screen "that row is gone": Done editing ends the session, the stream fires, the screen reads again. The Settings row watches the same stream, so its summary is right the moment the user comes back.
- **A row only when it holds something.** A CapCut session that only sent the originals has no copies, so it takes no space and has no row. The controller keeps the order itself (newest first) instead of trusting the query, so the order is a rule of the screen and is tested without a database.
- **Covers are joined by reel id.** The reel summaries already know each reel's cover clip. The controller looks it up by the row's reel id and builds the same thumbnail Home uses, so the cache holds one file per clip. A reel with no cover, or a stream that fails, shows the movie icon and not an error.
- **Declined means nothing.** `deleteOrphans` returns an `OrphanDeleteResult`: whether the user allowed it, and the bytes freed, kept apart so an allowed delete of files that report size 0 still counts as allowed. The screen keeps the folder and says nothing: a "No" is an answer, not a failure. Only a bridge exception says "Something went wrong". A second tap while the dialog is open is ignored, per folder, so Android is asked once.
- **Never a live copy's files.** While a copy runs, its finished files are not in the database yet, so they look like files with no reel. `storage()` leaves out the folder of a running job and of a saved plan, and a test keeps it that way, so **Delete** is never offered for a copy that is being made.

- **Delete never looks dead.** While a reel's copy job runs, its Delete does nothing but say "Copying is still running. Try again when it finishes." (the controller's ruling for the owner). A failed re-read showing an empty list until Try again is intended.

**Where it lives:** `app/lib/features/editors/view_models/copies_storage_controller.dart`, `app/lib/features/editors/views/copies_storage_screen.dart`, `app/lib/features/settings/views/settings_screen.dart`, `app/lib/router/` (`Routes.copiesStorage`), `app/lib/l10n/app_en.arb`, and `EditSessionService.storage()` / `deleteOrphans` from section 6.

**Try it yourself:** run the screen's tests, then let a "No" delete the row:

```bash
cd app && ../tool/flutter test test/features/editors/copies_storage_screen_test.dart
```

They end with `All tests passed!`. Now open `lib/features/editors/view_models/copies_storage_controller.dart` and change `if (freed > 0 && current != null && ref.mounted) {` to `if (current != null && ref.mounted) {`. Run it again: "declined: no snack and the row stays" fails, because a folder the user did not allow Android to delete would vanish from the screen while its files are still there. Put it back. For the other rule, open `lib/features/editors/views/copies_storage_screen.dart` and replace the body of `_deleteReel` with `ref.read(editSessionServiceProvider).doneEditing(reelId)`: "opens the Done editing question…" fails, because the copies would be deleted with no question at all.

**Decisions:** D-130 (all of this section), with D-118 (R7), D-123 (the service), D-128 (Done editing) and D-129 (CapCut and Edits copies) as background.

## 14. On the S24

To be written in Task 14 (decision D-131).
