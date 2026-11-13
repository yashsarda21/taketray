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

- **Nothing stuck.** A session with no copies and no sent clips (a first copy that never finished, a share that was interrupted) is ended at the next start.

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
