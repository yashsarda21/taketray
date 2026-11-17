# Learning guide: Phase 10B, Settings

This guide explains the full Settings screen: the switches for every reminder and how they reach the background, the Watched folders screen (chat apps included), Export and import of a backup, and Send error log through Android's share sheet. It is written as the phase is built; each section is filled in by the task that builds it.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-144, so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-144.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [The two new reminder switches](#2-the-two-new-reminder-switches)
3. [Safe imports](#3-safe-imports)
4. [The files bridge](#4-the-files-bridge)
5. [The full Settings screen](#5-the-full-settings-screen)
6. [Watched folders](#6-watched-folders)
7. [Export and import](#7-export-and-import)
8. [Send error log](#8-send-error-log)
9. [On the S24](#9-on-the-s24)

## 2. The two new reminder switches

### What we built

TakeTray has three reminders: the evening one, "Still shooting?" after two weeks of Shooting mode, and "copies are using space" three days after an editing session's copies were made. Only the evening reminder had a setting. This task adds a setting for each of the other two, and makes them reach the part of the app that runs while TakeTray is closed.

Nothing on screen changes yet. The switches are stored, backed up, and obeyed; the Settings screen that shows them comes in section 5.

### Why TakeTray needs it

A switch the app stores but never reads does nothing. The reminders are posted by Android from alarms, with TakeTray closed, so they cannot ask the database. Dart keeps a copy of what they need in Kotlin's own storage (the "background bridge"), and the switch has to travel in that copy. The rule for the whole phase: turn a reminder off and it stops, even if the app is never opened again.

### Key ideas

**1. A setting is a key in a table, with a default.** `AppSettings` is a plain data class with defaults, and `SettingsRepository` keeps one row per setting. A missing row is the default, so someone who changes nothing sees no change:

```dart
@Default(true) bool stillReminderEnabled,
@Default(true) bool copiesReminderEnabled,
```

**2. The copy sent to the background decides, not Kotlin.** `BackgroundSync` builds the state the phone keeps. For "Still shooting?" the switch is one field. For the copies reminder, the switch turns the whole list empty, and the phone already cancels a reminder that is no longer in the list, so no Kotlin changed:

```dart
stillReminderEnabled: settings.stillReminderEnabled,
// Off: none are written, so the phone cancels any it has posted (D-145).
copiesReminders: settings.copiesReminderEnabled
    ? await _copiesReminders()
    : const [],
```

The copies themselves stay on the phone and in the database. Only the reminder stops.

**3. The in-app question follows the same switch.** "Still shooting?" is also asked inside the app. `StillShootingPrompt.claim()` returns nothing when the switch is off, and it does so before it uses up its once-per-session claim, so turning the switch back on can ask.

**4. A backup may lack a key it did not know yet.** A backup file written before this phase has no `stillReminderEnabled`. Refusing it would make old backups unrestorable, so these two keys are read leniently: missing means on. A key that is there with the wrong kind of value (`"yes"`) is still refused, like any other. The format stays at version 1, because every file a version-1 reader accepted is still accepted:

```dart
bool optionalBoolean(String key, {required bool orElse}) =>
    _map.containsKey(key) ? boolean(key) : orElse;
```

**5. Phone state is not a setting.** `lastExport` records when a backup file was last saved. It belongs to this phone, so it lives in `PhoneStateRepository` and is not in `SettingsRepository.exportedKeys`: a backup never holds it. It is stored as UTC milliseconds, and a value that cannot be read is "never" (only the key's name is logged, never the value).

**6. Log a corrupt value once.** The Settings screen will watch the settings, and a watch re-reads every row on each change. A corrupt row would be logged on every emission. The repository now remembers which keys it already warned about:

```dart
if (_warned.add(key)) {
  _log.warning('Setting $key is corrupt, using its default');
}
```

### Where it lives

- `app/lib/domain/models/app_settings.dart`, `app/lib/data/repositories/settings_repository.dart`: the two settings and the warn-once guard.
- `app/lib/data/repositories/phone_state_repository.dart`: `lastExport()` and `recordExport()`.
- `app/lib/data/background/background_sync.dart`: the two switches in the copy for the phone.
- `app/lib/features/notifications/view_models/still_shooting_prompt.dart`: the in-app question.
- `app/lib/data/backup/backup_format.dart`, `backup_service.dart`: writing and leniently reading the two keys.
- Docs: `docs/flow.md` ("Background bridge", "Backup export and import"), D-145.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/data/background/background_sync_test.dart \
  test/data/backup/backup_service_test.dart \
  test/features/notifications/view_models/still_shooting_prompt_test.dart
```

Then break one thing on purpose and watch a test catch it. In `background_sync.dart`, change the copies line to `copiesReminders: await _copiesReminders(),` and run the first file: the tests under "the reminder switches" fail. Put it back.

### Decisions

- D-145: the two switches reach the background; the backup reads them leniently and stays at version 1; `lastExport` is phone state; a corrupt setting is logged once per key.

## 3. Safe imports

### What we built

Restoring a backup used to delete every row of the `settings` table, run beside whatever the app was doing, and could be started in the middle of a copy. This task makes an import safe. It keeps the phone's own state, waits its turn behind scans and checks, refuses while a copy job is saved, refuses a file that is too large, and reads the file off the main isolate. A new `BackupActions` class wraps the existing `BackupService` with those rules. Nothing on screen changes yet: the Export and import screen (section 7) calls it.

### Why TakeTray needs it

The backup holds the user's work (reels, clips, references, five settings). It does not hold what this phone knows about itself: that onboarding ran, which tips were seen, which volume versions the clips belong to. If the import deleted those, restoring a backup would show the welcome again. If it ran beside a scan, the scan could write clips into the half-restored data. If it ran during a copy, the copy's files would lose the record that names them. And a very large file decoded on the main isolate would freeze the screen.

### Key ideas

**1. Delete only what the import owns.** The `settings` table holds the user's five settings and the phone's own keys. The import now removes only the five exported keys plus the two phone-state rows that must not outlive it: Shooting mode (its baselines belong to the old clips) and the copy plan (it names clip ids the import replaces). Every other row, including a key a later version adds, survives:

```dart
static final Set<String> _removedSettingKeys = {
  ...SettingsRepository.exportedKeys,
  PhoneStateRepository.shootingModeKey,
  PhoneStateRepository.copyJobPlanKey,
};
// ...
await (_db.delete(_db.settings)
      ..where((s) => s.key.isIn(_removedSettingKeys)))
    .go();
```

**2. One queue for every media job.** A scan, a verify and the grant clean-up all run on `MediaWorkQueue`, one at a time, in the order they were queued. The import is now one more job on it, so a scan that was already running finishes first, and nothing starts in the middle of the import's transaction:

```dart
summary = await _queue.run(() => _service.importDecoded(data));
```

`importDecoded` is the old `importJson` minus the decoding, split out so the file can be decoded before the job waits for its turn.

**3. Check cheap things before doing expensive ones.** The order is: size, then a saved copy plan, then decode, then the queued write, then the verify. A file over 20 MiB of UTF-16 code units (a Dart `String.length`) is refused without being decoded. A saved copy plan means a copy job is running or waiting, so the import is refused with nothing read.

**4. Decode in the background.** `Isolate.run` runs `decodeBackup` on another isolate and returns the result. A bad file throws the same `BackupException` as before, and becomes `ImportRefused(problem)`:

```dart
Future<BackupData> decodeBackupInIsolate(String json) =>
    Isolate.run(() => decodeBackup(json));
```

**5. A result the screen can switch on.** `ImportResult` is a sealed class, so the compiler makes the screen handle every case: `ImportDone(summary, found, total)`, `ImportRefused(problem)`, `ImportBusyCopying()` and `ImportTooLarge()`.

**6. A failed check is not a failed import.** After the import, "X of Y clips found" comes from `verifyAll()`, wrapped in `guarded`. If the phone cannot answer, the data is already restored, so the result is still `ImportDone`, with 0 found, and the log holds only the error's type.

**7. Record a backup only when it exists.** `exportJson()` returns the text and records nothing. The screen calls `recordExport()` once the file was really saved, so a cancelled picker never counts.

### Where it lives

- `app/lib/data/backup/backup_actions.dart`: `BackupActions`, `ImportResult` and the isolate decoder.
- `app/lib/data/backup/backup_service.dart`: `importDecoded` and the narrower delete in `_replaceAll`.
- Tests: `app/test/data/backup/backup_service_test.dart` ("an import keeps this phone's state") and `app/test/data/backup/backup_actions_test.dart` (refusals, the queue order, the failed verify).
- Docs: `docs/flow.md` ("Backup export and import"), D-146.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/data/backup
```

Then break one thing on purpose. In `backup_actions.dart`, change the import line to `summary = await _service.importDecoded(data);` (no queue) and run `backup_actions_test.dart`: "a scan queued first finishes before the import starts" fails. Put it back. In `backup_service.dart`, delete the `.where(...)` of the settings delete and the "keeps every other settings row" test fails.

### Decisions

- D-146: imports keep the phone's state except Shooting mode and the copy plan, run on the media queue, are refused while a copy job is saved or when the file is over 20 MiB, and decode off the main isolate.

## 4. The files bridge

### What we built

A new bridge between Dart and Kotlin, `FilesBridge`, for the four things the rest of the phase asks of Android: open the share sheet for one of TakeTray's own files (the error log), let the user save a document (a backup) and open one (to import it), let the user choose a folder (to watch it), and tell the app its version and the Android release. Nothing on screen changes yet; sections 5 to 8 use it.

### Why TakeTray needs it

TakeTray never uses the network and asks for no storage permission. Android has a clean way to do all four jobs without either: its own screens. When the user picks a place to save, a file to open or a folder, that choice is the permission, for that one call. The share sheet works the same way: TakeTray hands one file to the app the user picks, with a read grant on that one address. A plugin such as `share_plus` would bring its own Android code and manifest entries (D-134), so the bridge is about 300 lines of Kotlin on Android's own APIs.

### Key ideas

**1. A contract first.** Like the other bridges, the shape of the calls is written once in `pigeons/files_api.dart`, and Pigeon writes the Dart and the Kotlin plumbing. Every call is `@async`, because each one waits for the user or for storage:

```dart
@async
String? openDocument(List<String> mimeTypes, int maxBytes);

@async
String? pickFolder();
```

**2. A cancel is not an error.** If the user backs out of a picker, the call answers null. Errors are kept for real problems, and Dart turns Kotlin's error codes into one small enum, so a screen can `switch` on it:

```dart
throw FileBridgeException(switch (e.code) {
  'invalid_path' => FilesProblem.invalidPath,
  'too_large' => FilesProblem.tooLarge,
  'unsupported_folder' => FilesProblem.unsupportedFolder,
  _ => FilesProblem.failed,
});
```

**3. Share only from one folder.** The share sheet reads the file through a `FileProvider`, a small content provider from androidx that turns a file into a `content://` address another app may read once. It is told about one folder only, the cache's `shared/`:

```xml
<paths>
    <cache-path name="shared" path="shared/"/>
</paths>
```

Kotlin checks the path before the provider sees it. It resolves `..` and links first, so `cache/shared/../taketray.sqlite` cannot slip through, and a folder that merely starts with the same letters (`cache/sharedx/`) is refused too:

```kotlin
val shared = File(context.cacheDir, SHARED_DIR).canonicalFile
val target = file.canonicalFile
if (!target.path.startsWith(shared.path + File.separator)) return null
return if (target.isFile) target else null
```

The provider's authority is `${applicationId}.files`, so the dev build (`app.taketray.dev`) and the real app never fight over one name.

**4. Read a bounded amount.** A backup can be at most 20 MB. Asking a document "how big are you?" is not reliable (some providers do not know), so Kotlin reads in 64 KiB pieces and stops at the first byte past the limit. Exactly the limit is fine; one byte more is `too_large`. An endless stream can never fill the memory:

```kotlin
total += n
if (total > maxBytes) return null
out.write(buffer, 0, n)
```

**5. A folder, by name only.** The folder picker answers an address such as `content://com.android.externalstorage.documents/tree/primary%3ADCIM%2FCamera`. Its last part, decoded, is `primary:DCIM/Camera`: the volume, then the folder's path, which is exactly how MediaStore names a folder (`DCIM/Camera`). TakeTray keeps that name and nothing else. It never calls `takePersistableUriPermission`, so it keeps no grant: it reads the folder through MediaStore like every other folder. An address from any other provider (Downloads, a cloud drive) cannot be read that way, so it is refused with `unsupported_folder`.

**6. One picker at a time.** Each picker starts with a request code (`4101` save, `4102` open, `4103` folder), and Android sends the answer to `MainActivity.onActivityResult`, which passes it to each bridge. The files bridge has one waiting slot: a second picker call while one is open is `busy`. If Android killed TakeTray while the picker was open, the answer arrives at a new activity where nobody is waiting; it is dropped, and only its type is logged.

**7. A fake for the screens.** `FakeFilesBridge` (in `test/support/`) answers what a test sets, records every call, can fail the next call with a chosen problem, and can hold a call so a test can tap twice while the first is still running.

### Where it lives

- `app/pigeons/files_api.dart`: the contract (generated: `lib/platform/files_api.g.dart`, `android/.../files/FilesApi.g.kt`).
- `app/lib/platform/files_bridge.dart`: `FilesBridge`, `PigeonFilesBridge`, `FilesProblem`, `FileBridgeException`, `AppInfo`, `filesBridgeProvider`.
- `app/android/app/src/main/kotlin/app/taketray/files/FilesHostApiImpl.kt`: the Kotlin side; `MainActivity.kt` sets it up and passes it the picker answers.
- `app/android/app/src/main/AndroidManifest.xml` (the `<provider>`) and `res/xml/file_paths.xml`.
- Tests: `app/test/platform/files_bridge_test.dart`, `fake_files_bridge_test.dart`, `app/test/support/fake_files_bridge.dart`; Kotlin `android/app/src/test/kotlin/app/taketray/files/FilesHostApiImplTest.kt` and `ManifestTest.kt`.
- Docs: `docs/flow.md` ("Files bridge"), D-147.

### Try it yourself

From the repository root:

```sh
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.files.*' --tests 'app.taketray.ManifestTest'
cd app && ../tool/flutter test test/platform/files_bridge_test.dart test/platform/fake_files_bridge_test.dart
```

Then break one thing on purpose. In `FilesHostApiImpl.kt`, change `if (total > maxBytes)` to `if (total >= maxBytes)` and run the Kotlin tests: "openDocument allows exactly maxBytes and refuses one byte more" fails, because a file of exactly the limit is now refused. Put it back. Then delete the `startsWith(shared.path + File.separator)` line: "shareFile refuses every path that is not a file in cache shared" fails. Put it back, and run `./gradlew :app:clean` in `app/android` afterwards.

### Decisions

- D-147: the files bridge: the share sheet through a `FileProvider` on `cache/shared/` only, the document picker to save and open (with a byte limit), the folder picker read as a MediaStore path with no grant kept, one picker at a time, and `androidx.core` declared at the version it already had.


## 5. The full Settings screen

### What we built

The Settings tab now looks like the prototype: seven groups, from "Shooting mode" at the top to "About" at the bottom. The two reminder switches from section 2 are there, with the evening reminder's time (it opens Android's time picker), a "VN copies reminder" switch, "Watched folders", "Export and import", "Send error log", and a "Video access" row next to "Notifications". "Watched folders" and "Export and import" open empty stand-in screens for now; sections 6 and 7 fill them in, and section 8 gives "Send error log" its action.

### Why TakeTray needs it

Until now the reminders could be switched off only by editing the database. A user who finds the evening reminder at the wrong hour, or does not want "Still shooting?", needs a place to say so. The screen also tells them, in one look, what TakeTray can see (all videos, some, none) and when they last made a backup.

### Key ideas

**1. Two quick taps must both stay.** Every switch saves the whole set of five settings. If two taps each read the settings, change one value and save, the second save can overwrite the first. `SettingsController` therefore calls `SettingsRepository.update`, which reads the stored settings (not what the screen shows, which may be a frame behind), changes them and saves them inside one database transaction:

```dart
Future<void> _change(AppSettings Function(AppSettings) change) =>
    ref.read(settingsRepositoryProvider).update(change);
```

The database runs transactions one after the other, so the second tap reads what the first saved. (Task 5 first did this with a queue inside the controller; section 6 explains why that was not enough and was replaced.) A failed save goes only to the caller that asked for it; the next change still runs.

**2. A time that is not a minute of the day is refused.** `setEveningMinutes(1440)` throws `ArgumentError` before it saves anything. The repository checks too, but a guard in the controller means a bug in a caller never reaches the database.

**3. The screen shows what is saved.** A switch's value comes from `SettingsRepository.watch()`, so a switch whose save failed stays where it was. Until the first read arrives the switches are disabled.

**4. The phone's clock style.** "21:00" or "9:00 PM" comes from the phone's 12 or 24-hour setting (`MediaQuery.alwaysUse24HourFormatOf`), as every other time in the app does.

**5. One tap, one call.** The Allow buttons for video access go through `OpenOnce.openSlow`, which lets one call through and ignores the taps while it runs and for a moment after. The row of each permission is left out while its first read runs, and says "Not allowed" with a button if the read failed, so the user can always reach it.

**6. Why not a `ListView`.** A `ListView` builds only the rows near the screen. With thirteen rows, the ones at the bottom would not exist for a screen reader or a test. A plain `SingleChildScrollView` builds them all, which is cheap for a list this short.

### Where it lives

- `app/lib/features/settings/view_models/settings_controller.dart`: `SettingsController`, `lastExportProvider`, `appInfoProvider`.
- `app/lib/features/settings/views/settings_screen.dart` and `settings_rows/`: one widget per group.
- `app/lib/features/settings/views/watched_folders_screen.dart` and `backup_screen.dart`: stand-ins.
- `app/lib/router/routes.dart` and `app_router.dart`: `Routes.watchedFolders` and `Routes.backup`.
- Tests: `app/test/features/settings/view_models/settings_controller_test.dart`, `views/settings_screen_test.dart`, `views/settings_golden_test.dart` (goldens in `views/goldens/macos/`), `app/test/router/app_router_test.dart`; the fake is `app/test/support/fake_settings.dart`.
- Docs: `docs/flow.md` ("Settings"), D-148.

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/settings test/router/app_router_test.dart
```

Then break one thing on purpose. In `settings_controller.dart`, make `_change` call `repository.load()` and `save` directly instead of `update`: "two switches in the same frame both persist" fails, because both calls read the old settings. Or change `minutes >= 24 * 60` to `minutes > 24 * 60`: "1440 throws ArgumentError and saves nothing" fails.

### Decisions

- D-148: the full Settings screen: the prototype's order and copy, a read-modify-save controller (a queue at first, `update` from D-149), the 0..1439 guard, the phone's time format, the Video access row, and stand-in screens for Tasks 6 and 7.

## 6. Watched folders

### What we built

"Watched folders" in Settings now opens a real screen. It lists the folders on the phone that hold videos, each with a switch; the ones that are on are the folders Shooting mode looks in. WhatsApp, Telegram, Signal, Messenger and Snapchat folders are in the list like any other, with a warning: a clip from a chat is dated when it arrived, and busy groups and forwards will land in To tag too. "Add a folder" opens Android's folder picker for anything the list does not show (a pro camera app's own folder, say). A folder that was watched but is no longer on the phone stays in the list as "Not on this phone now", so it can still be turned off. Without full video access only the watched folders show, with a banner to allow all videos.

### Why TakeTray needs it

Until now Shooting mode watched `DCIM/Camera` and nothing else, with no way to change it. People shoot with other apps, and some want a chat folder watched on purpose. The owner chose to allow it and warn, rather than hide it.

### Key ideas

**1. One folder, one row.** A folder is stored as a path with no volume, such as `DCIM/Camera`, because that is all the picker gives back and all the scanner needs. So the phone's `DCIM/Camera` and the SD card's are the same watched folder. The controller compares paths with no slash at either end and A to Z case folded, and adds the counts of both volumes into one row.

**2. Names, not parts of names.** `isChatFolder` is true when any path segment is exactly one of twelve names (`WhatsApp`, `com.whatsapp`, `Telegram`, ...). `Pictures/Signals` is not a chat folder; a test lists a dozen such near misses.

```dart
bool isChatFolder(String relativePath) =>
    _segments(relativePath).any((s) => _chatSegments.contains(_lower(s)));
```

**3. Turning a folder on does not pull in its history.** TakeTray remembers, for each volume, how far MediaStore's generation counter had got when Shooting mode went on. A video already in the folder was added before that, so it is below the line and the scanner never sees it as new. No code was needed; a scanner test pins it, so a later change cannot break it quietly.

**4. Two screens, one settings row set (ruling R3).** `SettingsRepository.save` writes all five keys. Task 5 ordered the Settings switches with a queue inside their own controller, but the Watched folders controller is another object: a folder toggle and an evening switch in the same frame could each read the old settings and one would erase the other. The fix is `SettingsRepository.update(change)`, which reads, changes and writes inside one database transaction, so the second writer waits for the first and then reads what it saved. Both controllers use it.

```dart
final saved = await _db.transaction(() async {
  final next = change(_fromRows(await _selectExported().get()));
  _validate(next);
  await _write(next);
  return next;
});
```

**5. Refusing what cannot work.** The storage root has no folder in MediaStore, so watching it would find nothing; TakeTray's own `Movies/TakeTray/` holds temporary copies that would flood To tag. `addFolder` refuses both, and the folder picker's own "not a phone or SD folder" answer (Downloads, a cloud drive) shows "Choose a folder on this phone or its SD card."

### Where it lives

- `app/lib/domain/rules/chat_folders.dart`: `isChatFolder`, `isOwnCopyFolder`.
- `app/lib/features/settings/view_models/watched_folders_controller.dart`: the rows, `setWatched`, `addFolder`.
- `app/lib/features/settings/views/watched_folders_screen.dart`.
- `app/lib/data/repositories/settings_repository.dart`: `update`.
- Tests: `test/domain/rules/chat_folders_test.dart`, `test/features/settings/view_models/watched_folders_controller_test.dart`, `views/watched_folders_screen_test.dart`, `views/watched_folders_golden_test.dart` (goldens in `views/goldens/macos/watched_*.png`), `test/data/repositories/settings_repository_test.dart` (`update`), `test/data/media/media_scanner_test.dart` (the baseline pin); the fake is `test/support/fake_watched_folders.dart`.
- Docs: `docs/flow.md` ("Watched folders", "Settings"), D-149.

### Try it yourself

```sh
cd app && ../tool/flutter test test/domain/rules/chat_folders_test.dart test/features/settings test/data/repositories/settings_repository_test.dart
```

Then break things on purpose. In `chat_folders.dart` make the check `_lower(s).contains(c)`: `Pictures/Signals` fails. In `settings_repository.dart` take the `_db.transaction(` wrapper off `update`: "two updates at once from two repositories both persist" fails, because both read the old settings. In the controller, drop the `gone: true` row: the "gone path" tests fail.

### Decisions

- D-149: watched folders with chat apps included, the screen and its rules, and `SettingsRepository.update` for every settings change (ruling R3).

## 7. Export and import

## 8. Send error log

## 9. On the S24
