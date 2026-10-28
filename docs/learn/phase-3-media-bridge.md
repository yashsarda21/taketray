# Learning guide: Phase 3, the media bridge

This guide explains how TakeTray finds your videos. Phase 2 stored facts about clips; phase 3 builds the bridge to Android's media library, so the app can see new videos, show their thumbnails, notice when one is deleted, and put them in the To tag list. TakeTray still never copies or changes a video.

**Status: skeleton.** The guide is written section by section, each one in the same commit as the code it explains. Sections that say "Written in Task N" are not written yet. Sections 1 and 2 are done.

You don't need to know Kotlin, Android or Pigeon to follow it. Basic programming knowledge is enough. When a word is new, the section explains it, and the [Glossary](#glossary) at the end collects them all.

## How to read this guide

- **Order.** Read the big picture first. Then sections 1 to 11 follow the order the phase was built: the safety rules and checks (1, 2), the contract between Flutter and Android (3), the Android side (4), the rules for deciding which video is which (5), the database additions (6), the scan (7), thumbnails (8), the view models and app lifecycle (9), the screens (10) and the proof on the phone (11).
- **Names you will meet.**
  - `D-xx` is an entry in `docs/decisions.md`, where each decision is written down with its reasons.
  - "Phase 4", "phase 5" and so on are the later stages of building TakeTray. Phase 4 builds the reel screens; phase 5 the tagging screen and player.
  - "Spec §4" means a section of the product spec, `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`.
  - "Review Focus 1" to "5" are the five risky situations this phase is reviewed against (for example, "an SD card removed" or "a video still being recorded when TakeTray scans").
- **`tool/check`.** The one script that checks the whole project: generated files are fresh, then formatting, analysis and tests, and test coverage. `tool/check_release_permissions` is the slower check of the release build's manifest, run at the end of the phase.
- **Commands.** Run every command from the repository root (the folder that contains `app/` and `tool/`), always through the wrappers in `tool/` (`tool/flutter`, `tool/dart`), never a `flutter` found on your `PATH`. Some "Try it yourself" steps break the code on purpose to show that a check notices. Each one tells you how to put the file back (`git checkout -- <file>`). Check with `git status` that nothing is left over.

## How each section is written

Every section below uses the same shape:

- **What we built:** two or three sentences.
- **Why TakeTray needs it:** the real problem it solves.
- **Key ideas:** the concepts, explained plainly, each with a short snippet from the real code.
- **Where it lives:** file paths.
- **Try it yourself:** one command you can run, and what you should see.
- **Decisions:** the `D-xx` entries in `docs/decisions.md`.

## Contents

1. [Google backup off and the release checks](#1-google-backup-off-and-the-release-checks)
2. [Hygiene: logging, coverage, banners](#2-hygiene-logging-coverage-banners)
3. [The Pigeon contract and the Dart bridge](#3-the-pigeon-contract-and-the-dart-bridge)
4. [The Kotlin side and Android unit tests](#4-the-kotlin-side-and-android-unit-tests)
5. [The media rules](#5-the-media-rules)
6. [Phone state and clip writes](#6-phone-state-and-clip-writes)
7. [Scanner, verifier and zone sync (and Add earlier videos)](#7-scanner-verifier-and-zone-sync-and-add-earlier-videos)
8. [Thumbnails](#8-thumbnails)
9. [View models and app lifecycle](#9-view-models-and-app-lifecycle)
10. [The To tag screen and the Shooting mode card](#10-the-to-tag-screen-and-the-shooting-mode-card)
11. [Proving it on the phone](#11-proving-it-on-the-phone)

[Glossary](#glossary) · [What's next](#whats-next)

---

## The big picture

Flutter (Dart) cannot read Android's media library on its own. So the phase adds a small Kotlin program inside the app that can, and a typed contract that lets the two sides talk. Dart asks questions ("what videos are new since this number?"); Kotlin answers with plain data. Everything that *decides* something, such as "is this the same video as before?", is Dart code that can be tested on a laptop.

This is the **planned** architecture; each section is written when its part is built.

```mermaid
flowchart TD
    SCREENS["Screens<br/>To tag, Shooting mode card<br/><i>app/lib/features/</i>"]
    VM["View models<br/>(Riverpod)"]
    REPOS["Repositories<br/>clips, settings, zones<br/><i>app/lib/data/repositories/</i>"]
    SCAN["Scanner and verifier<br/>new videos in, missing videos out<br/><i>app/lib/platform/</i>"]
    RULES["Media rules<br/>fingerprints, baselines, rebuild matching<br/><i>app/lib/domain/rules/</i>"]
    BRIDGE["MediaBridge (Dart)<br/>typed calls to Android"]
    PIGEON["Pigeon contract<br/>generated Dart and Kotlin code"]
    KOTLIN["Kotlin MediaStore reader<br/><i>app/android/.../media/</i>"]
    MS["Android MediaStore<br/>the phone's media library"]

    SCREENS --> VM
    VM --> REPOS
    VM --> SCAN
    SCAN --> BRIDGE
    SCAN --> RULES
    SCAN --> REPOS
    BRIDGE --> PIGEON
    PIGEON --> KOTLIN
    KOTLIN --> MS
```

A solid arrow means "calls". The rules layer imports neither Flutter nor Android; the Kotlin side only reads and reports, and never decides what a video "is" to TakeTray.

The rule that shapes the whole phase is the spec §4 anti-goal: **a wrong video is the worst bug.** Whenever TakeTray is unsure whether a row in Android's media library is a stored clip's video, it treats the clip as missing instead of guessing.

---

## 1. Google backup off and the release checks

**What we built:** TakeTray's data is no longer backed up to Google or copied to a new phone by Android. The manifest turns Android's automatic backup off and two small XML files exclude every kind of app data. The release check (`tool/check_release_permissions`) now reads the finished release APK and fails if any of this is wrong, or if the app asks for a permission it must never have.

**Why TakeTray needs it:** the database stores, for each clip, an *id number* from Android's media library. That number only means something on the phone that made it. If Android restored the database on a new phone, clip number 4821 would point at whatever video happens to have that number there: a wrong video, silently. That is the worst bug TakeTray can have. So Android must never restore the database by itself. A new phone starts with an empty TakeTray. TakeTray's own **Export / Import** (Settings, phase 10) is a *same-phone* backup, for example before reinstalling the app. Moving to a new phone is not supported in v1, because the clips would show as missing there (D-64).

**Key ideas:**

- **Auto Backup.** By default, Android copies an app's private files to the user's Google account about once a day, when the phone is idle, charging and on Wi-Fi, and puts them back when the app is installed on a new phone. For most apps that is helpful. For TakeTray the files are the database `taketray.sqlite`, which `drift_flutter` keeps in the app's `app_flutter/` folder (the "documents directory" that the `path_provider` package gives). Android sorts backup files into *domains*, and it counts `app_flutter/` under the `root` domain; the `file` domain is only the app's `files/` folder. So `root` is the exclusion that covers the database, and its two helper files next to it (`-wal` and `-shm`). The other domains are excluded too, so nothing else leaves the phone either (the small settings file that holds the native time-zone list, caches).

- **Turning it off takes three lines, because Android has two rule formats.** Android 12 and newer read `dataExtractionRules`; Android 11 reads `fullBackupContent`. TakeTray's minimum is Android 11 (API 30), so both are set. These are the real attributes in `AndroidManifest.xml`:

  ```xml
  <application
      android:label="${appLabel}"
      android:name="${applicationName}"
      android:icon="@mipmap/ic_launcher"
      android:allowBackup="false"
      android:dataExtractionRules="@xml/data_extraction_rules"
      android:fullBackupContent="@xml/backup_rules">
  ```

- **Excluding every domain.** `allowBackup="false"` should already be enough. The rule files are a second lock: if a future change turned `allowBackup` back on, the files still exclude everything. `data_extraction_rules.xml` has two parts, `<cloud-backup>` (Google's copy) and `<device-transfer>` (the phone-to-phone setup cable or wireless copy), and excludes all five domains in each. (The `device_*` domains are not listed because the app uses no device-protected storage.)

  ```xml
  <cloud-backup>
      <exclude domain="root" path="." />
      <exclude domain="file" path="." />
      <exclude domain="database" path="." />
      <exclude domain="sharedpref" path="." />
      <exclude domain="external" path="." />
  </cloud-backup>
  ```

  `backup_rules.xml` (the Android 11 format) has the same five lines inside `<full-backup-content>`.

- **A check that reads the finished app, not the source.** The manifest you edit is not the manifest that ships: Android's build merges in the manifests of every library TakeTray uses, and a library can add a permission or switch a setting back. So `tool/check_release_permissions` builds the release APK and reads the *merged* manifest from it with `aapt2` (a tool of the Android SDK):

  ```bash
  manifest="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK")"
  ```

  A short `awk` program turns that text into plain lines such as `application allowBackup false` and `permission android.permission.INTERNET -`. Then the script collects every problem it finds and prints each one, so you see all of them at once:

  ```bash
  if [ "$(app_attr allowBackup)" != "false" ]; then
    problems+=("allowBackup is not false (found: '$(app_attr allowBackup)')")
  fi
  ```

  An `allowBackup` that is missing counts as a failure too, because Android's default for a missing attribute is *on*.

- **Permissions it must never have.** The release build must not contain `INTERNET` (TakeTray is fully offline), `READ_MEDIA_IMAGES`, `MANAGE_EXTERNAL_STORAGE` or `ACCESS_MEDIA_LOCATION`. TakeTray only ever needs to read *videos*.

- **A rule that is written but switched off.** The check also knows which permissions TakeTray *should* have: `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`, and `READ_EXTERNAL_STORAGE` limited to Android 12 and older (`maxSdkVersion` 32). The manifest does not declare them yet (Section 4 adds them), so this part is off by default and can be tried early with `ENFORCE_MEDIA_PERMISSIONS=1`. When Section 4 adds the permissions, it turns the default on.

**Where it lives:** `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/src/main/res/xml/data_extraction_rules.xml`, `app/android/app/src/main/res/xml/backup_rules.xml`, `tool/check_release_permissions`.

**Try it yourself:** first look at the three settings in the source, from the repo root:

```bash
grep -n "allowBackup\|dataExtractionRules\|fullBackupContent" app/android/app/src/main/AndroidManifest.xml
```

You should see three lines (plus comment lines that mention the names). Then run the real check (it builds the release app, so it takes a minute or two):

```bash
tool/check_release_permissions
```

The last line should be `RELEASE PERMISSIONS OK`. Now break it on purpose: delete the line `android:allowBackup="false"` from the manifest, run the check again and read the failure, `RELEASE CHECK FAILED: allowBackup is not false (found: '')`. Put the file back with `git checkout -- app/android/app/src/main/AndroidManifest.xml`.

**Decisions:** D-63 (the phase works on its own branch and lands through a green pull request), D-64 (no Google backup).

---

## 2. Hygiene: logging, coverage, banners

**What we built:** three small repairs that earlier reviews had parked, done before the media work starts. The error log can no longer be crashed by an error that cannot print itself. The test-coverage check now counts a file that no test loads, which it used to miss. And the `TtBanner` widget refuses a tap and a button at the same time, and can draw its icon outlined, as the design prototype does.

**Why TakeTray needs it:** phase 3 adds a lot of new code under `lib/platform/` and, later, under the view-model folders, and it logs while it scans your videos. A logger that throws would turn one bad error into a second failure inside the code that was reporting the first. A coverage check that cannot see an untested file would let the new bridge code ship with no tests at all and still show a green result. These had to be fixed first so that the rest of the phase is held to the real rule: at least 80 % of the lines must run in a test.

**Key ideas:**

- **The log listener must never throw.** Every `Logger('x').severe(...)` call runs the app's listener, which turns the record into one line of text. An error object can have a `toString()` that itself throws (a broken platform exception, for example). The `logging` package calls listeners synchronously, but an exception from a listener does not come out of the caller's log call: Dart's zone catches it and reports it as an *uncaught error*. The result is two problems: the log line is lost, and the uncaught error goes to the app's own error handler, which logs again. So the listener goes through a small wrapper with two fallbacks, first without the stack trace (it may be the one that cannot print), then with the error replaced by a fixed placeholder:

  ```dart
  String _formatRecordSafely(LogRecord record) {
    try {
      return formatRecord(record);
    } on Object {
      try {
        return formatRecord(
          LogRecord(record.level, record.message, record.loggerName, record.error),
        );
      } on Object {
        return formatRecord(
          LogRecord(
            record.level,
            record.message,
            record.loggerName,
            record.error == null ? null : _unprintableError,
          ),
        );
      }
    }
  }
  ```

  The message and logger name are always kept. A stack that cannot print is simply left out; an error that cannot print becomes `<unprintable error>`. (The timestamp of such a line is the moment of the fallback, a few microseconds later.)

- **A privacy test must read the raw message.** The log has a privacy rule (D-10): no video name, folder, link or reel name. `formatRecord` hides anything that looks like a path or a link, so a test that checked its output could pass while the *code* was leaking, because the leak was already masked. The privacy test now reads `LogRecord.message`, the text the code wrote itself:

  ```dart
  final lines = records.map((r) => r.message).join('\n');
  ```

  Another test hygiene fix: the logging test sets a drift option (`dontWarnAboutMultipleDatabases`) and now puts it back in `tearDown`, so one test cannot change how the next one behaves.

- **Coverage only lists files that a test loads.** `flutter test --coverage` writes a file called `lcov.info` with one record per source file, and a record only exists for a file that some test caused to be loaded. A new file that nothing imports has no record, so it was not in the total. The fix is a test that imports everything. `tool/check` writes it just before the test run and deletes it afterwards:

  ```bash
  trap 'rm -f "$root/$COVERAGE_IMPORTS_FILE"' EXIT
  ```

  The script prints how many files each prefix gave, for example `coverage imports: lib/domain/ 13 files, lib/data/ 13 files, lib/platform/ 0 files, ...`, so a glob that matches nothing is visible in the log. The generated file is a list of imports and one empty test:

  ```dart
  import 'package:taketray/data/backup/backup_service.dart';
  import 'package:taketray/domain/rules/zone_lookup.dart';
  // ...one line per file...

  void main() {
    test('loads every file under the coverage prefixes', () {});
  }
  ```

  Once a file is loaded, lcov lists each of its executable lines, all with a count of 0, so the file pulls the percentage down. Files ending in `.g.dart` or `.freezed.dart` are generated by tools, not written by hand, and stay out of the count. The imports file is never committed (it is in `app/.gitignore`), and it only exists during the test run, so the formatting and analysis steps never see it.

  To prove it, an untested file `lib/data/_probe.dart` with 29 executable lines was added once: the `lib/data/` total went from `89.7%  867/967 lines` to `87.0%  867/996 lines`. Without the imports file the old run showed no change at all. The probe was then deleted.

- **A `*` in a prefix means exactly one folder name.** The coverage prefixes are now `lib/domain/ lib/data/ lib/platform/ lib/features/*/view_models/`. `check_coverage` turns each prefix into a regular expression, with a `*` segment as "one or more characters that are not a slash":

  ```dart
  final segments = prefix
      .split('/')
      .map((segment) => segment == '*' ? '[^/]+' : RegExp.escape(segment));
  return RegExp('^${segments.join('/')}');
  ```

  So `lib/features/a/view_models/x.dart` matches, and `lib/features/a/b/view_models/x.dart` does not. A `*` that is part of a longer name (`feat*`) or `**` is refused with the usage message.

- **A prefix with no files yet passes, but not all of them.** `lib/platform/` and the view-model folders do not exist until Tasks 3 and 9, so a prefix that matches no file prints `no files` and passes. If *every* prefix matches nothing, the check fails: that means a typo, or the wrong lcov file. An enum (a list of named constants) has no executable lines at all; it is ignored by itself.

- **`TtBanner` rules.** A banner with `onTap` is one big button. An `action` is another button inside it, and two nested buttons confuse both the finger and the screen reader. A constructor `assert` now stops it while you develop (debug builds and tests):

  ```dart
  }) : assert(
         onTap == null || action == null,
         'A banner with onTap is one button; give it onTap or an action, '
         'not both',
       );
  ```

  The icon is drawn filled by default. The prototype fills the "clips to tag" icon (`sell`) and leaves the icons of "Manual mode" (`lock`) and "TakeTray can't see your videos" (`no_photography`) outlined, so the new `iconFilled` parameter lets the caller choose. It is passed to Flutter's `Icon` as the Material Symbols *fill* axis, 1 for filled and 0 for outlined: `fill: iconFilled ? 1 : 0`. Only the banner pictures that contain those two icons changed.

**Where it lives:** `app/lib/core/logging/logging_setup.dart` and `app/test/core/logging/logging_setup_test.dart`; the privacy test in `app/test/data/backup/backup_service_test.dart`; `tool/check` (`COVERAGE_PREFIXES`, `write_coverage_imports`); `tool/bin/check_coverage.dart` and `tool/test/check_coverage_test.dart`; `packages/taketray_ui/lib/src/components/banners.dart` with its tests and the pictures in `packages/taketray_ui/test/components/goldens/`; the Widgetbook knob in `widgetbook/lib/components/banners.dart`.

**Try it yourself:** run the coverage checker on a small hand-made lcov file, from the repo root. It has one tested file (4 of 4 lines run) and one untested file (0 of 6 lines run), which is what `tool/check` now makes visible:

```bash
printf 'SF:lib/data/tested.dart\nDA:1,1\nDA:2,1\nDA:3,1\nDA:4,1\nend_of_record\nSF:lib/data/untested.dart\nDA:1,0\nDA:2,0\nDA:3,0\nDA:4,0\nDA:5,0\nDA:6,0\nend_of_record\n' > /tmp/try.info
tool/dart run taketray_tool:check_coverage /tmp/try.info 80 lib/data/ 'lib/features/*/view_models/'
echo "exit code: $?"
rm /tmp/try.info
```

You should see `lib/data/  40.0%  4/10 lines`, then `check_coverage: lib/data/ is below 80.0%`, then `lib/features/*/view_models/  no files`, and `exit code: 1`. Without the untested file the result would be 100 % and exit code 0. For the real thing, create an untested file with a few dozen lines, run `tool/check` and read the `lib/data/` line (delete the file afterwards):

```bash
python3 -c "print('int probe(int x) {\n  var t = x;\n' + ''.join('  t += %d;\n' % i for i in range(28)) + '  return t;\n}')" > app/lib/data/_probe.dart
tool/check        # the lib/data/ line drops
rm app/lib/data/_probe.dart
```

**Decisions:** D-65 (the coverage gate counts every file under its prefixes through a generated import test; a prefix with no files yet passes).

---

## 3. The Pigeon contract and the Dart bridge

_Written in Task 3._

---

## 4. The Kotlin side and Android unit tests

_Written in Task 4._

---

## 5. The media rules

_Written in Task 5._

---

## 6. Phone state and clip writes

_Written in Task 6._

---

## 7. Scanner, verifier and zone sync (and Add earlier videos)

_Written in Task 7._

---

## 8. Thumbnails

_Written in Task 8._

---

## 9. View models and app lifecycle

_Written in Task 9._

---

## 10. The To tag screen and the Shooting mode card

_Written in Task 10._

---

## 11. Proving it on the phone

_Written in Task 11._

---

## Glossary

_To be filled in as the sections are written (Task 12 makes it one list)._

## What's next

_To be written when the phase is finished._
