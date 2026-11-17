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

## 4. The files bridge

## 5. The full Settings screen

## 6. Watched folders

## 7. Export and import

## 8. Send error log

## 9. On the S24
