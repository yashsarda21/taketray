# Learning guide: Phase 2, the data layer

This guide explains how TakeTray remembers things: your reels, the clips in them, the To tag list, saved Instagram references and your settings. It is written alongside the code, one section per task, so every snippet here is real code from this repository.

You don't need to know Drift, Riverpod or SQL to follow it. Basic programming knowledge is enough.

> **Status:** sections marked *(coming in Task N)* are filled in as each task is built.

---

## The big picture

TakeTray never copies or changes your videos. It only stores **facts about them**: which video it is (an id from Android's media library), when it was shot, and which reels it belongs to. Those facts live in a small database file inside the app's private storage on the phone.

The code is split into layers. Each layer only talks to the one below it:

```mermaid
flowchart TD
    UI["Screens (phase 4 onwards)<br/>Home, To tag, tag player…"]
    REPO["Repositories<br/>ReelsRepository, ClipsRepository, …<br/><i>app/lib/data/repositories/</i>"]
    DOMAIN["Domain: models and rules<br/>Reel, Clip, name limits, URL clean-up<br/><i>app/lib/domain/</i>"]
    DB["Drift database (SQLite file on the phone)<br/><i>app/lib/data/database/</i>"]
    BACKUP["Backup: export / import JSON<br/><i>app/lib/data/backup/</i>"]

    UI --> REPO
    REPO --> DB
    REPO -. uses .-> DOMAIN
    BACKUP --> DB
    BACKUP -. uses .-> DOMAIN
```

Why split it this way?
- **Screens never write SQL.** They ask a repository ("tag this clip into these reels"), and the repository makes sure the rules are kept, for example that a clip doesn't end up in To tag twice.
- **Rules live in one place.** "A reel name is at most 40 characters" is written once in the domain layer and used everywhere.
- **Everything is testable on a laptop.** Tests run against a database that lives only in memory, so they're fast and never touch your phone.

## The life of a clip

How a video moves through TakeTray's data. Phase 3 does the detecting; this phase builds the storage it writes to.

```mermaid
stateDiagram-v2
    [*] --> ToTag: detected while Shooting mode is on
    ToTag --> InReels: tagged into one or more reels
    ToTag --> Skipped: Skip
    Skipped --> ToTag: Restore
    InReels --> ToTag: Undo
    InReels --> InReels: added to / removed from more reels
    InReels --> [*]: removed from its last reel (the clip's record is deleted, the video is not)
```

---

## How each section is written

Every task section below uses the same shape:

- **What we built:** two or three sentences.
- **Why TakeTray needs it:** the real problem it solves.
- **Key ideas:** the concepts, explained plainly, each with a short snippet from the real code.
- **Where it lives:** file paths.
- **Try it yourself:** one command you can run, and what you should see.
- **Decisions:** the `D-xx` entries in `docs/decisions.md`.

---

## 1. A separate test copy of the app

Task 1 is a build setting, not data. In short: debug builds and the automatic phone tests install as **TakeTray Dev** (`app.taketray.dev`), a separate app with its own storage, so tests can never wipe your real TakeTray data. See D-52.

The change is a few lines in `app/android/app/build.gradle.kts`:

```kotlin
debug {
    applicationIdSuffix = ".dev"
    manifestPlaceholders["appLabel"] = "TakeTray Dev"
}
```

Release and profile builds keep `app.taketray` and the name "TakeTray", which is the default set in `defaultConfig` (it can't sit on `release`, because Flutter's profile build doesn't inherit it). The manifest reads the name from the placeholder (`android:label="${appLabel}"`).

**Where it lives:** `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, and the `patrol:` block in `app/pubspec.yaml` (`package_name: app.taketray.dev`).

**Decisions:** D-52.

**Try it yourself:** from the repo root run `(cd app && ../tool/flutter build apk --debug)`, then `$HOME/Library/Android/sdk/build-tools/36.0.0/aapt2 dump badging app/build/app/outputs/flutter-apk/app-debug.apk | grep -E "^package:|application-label:"`. You should see `package: name='app.taketray.dev'` and `application-label:'TakeTray Dev'`.

## 2. Keeping generated code honest

**What we built:** a script, `tool/check_generated`, that `tool/check` runs right after `pub get`. It re-runs the code generators and fails if any committed generated file would change. We also tidied three small things in `tool/check` itself.

**Why TakeTray needs it:** from this phase on, a lot of the app's code is written by tools, not by hand: the database (Drift), the immutable models (Freezed), the JSON conversion and the Riverpod providers. If you change a source file and forget to regenerate, the generated file is silently out of date. The app may still compile and then behave like the old code. We want that to be impossible to forget.

**Key ideas:**

- **Code generation.** Some Dart code is boring and repetitive (for example the `==` and `copyWith` of a model class). Instead of writing it, you write a short description and a tool called `build_runner` writes the rest into files ending in `.g.dart` or `.freezed.dart`. The router already works this way: `app/lib/router/app_router.g.dart` starts with `// GENERATED CODE - DO NOT MODIFY BY HAND`.
- **Why the generated files are committed.** A fresh clone builds straight away, with no generation step, and when a generator changes, the change shows up in the diff where you can read it. Drift also needs its schema snapshots (`drift_schemas/`) in git so migrations can be tested later.
- **How the check works.** It does not use `git status`, because that would complain whenever you have unrelated uncommitted work. It takes a fingerprint (a SHA-1 hash from `shasum`) of every generated file, deletes the `.g.dart` and `.freezed.dart` ones, runs the generators, takes the fingerprints again, and compares. Deleting first matters: a generated file that nothing writes any more (say its source was removed) is not recreated, so it shows up as "disappeared" and is reported. It checks the files in your folder, not what is committed, so remember to `git add` the files it regenerates. Any file whose fingerprint changed, that appeared, or that disappeared is reported as stale. The generator step looks like this:

```bash
(cd "$m" && "$root/tool/dart" run build_runner build)
if [ -f "$m/build.yaml" ] && grep -q 'databases:' "$m/build.yaml"; then
  (cd "$m" && "$root/tool/dart" run drift_dev make-migrations)
fi
```

- **What is fingerprinted.** `*.g.dart` and `*.freezed.dart` under `lib/` and `test/`, everything in `drift_schemas/`, and everything in `test/drift/` (where Drift's migration tool writes helper files). The Drift files are never deleted before regenerating, because old schema snapshots cannot be rebuilt. The Drift parts are skipped until the database exists (Task 4). The translations in `app/lib/l10n/gen/` are not checked: they are not committed at all, `pub get` rebuilds them (D-27).
- **A failed check fixes itself.** The generators leave the new files on disk, so after a failure you just look at `git status`, review the changes and commit them. Running the check again passes.
- **Testing the check.** `tool/test/check_generated_test.dart` builds a throwaway repo whose `tool/dart` is a stand-in generator that always writes the same content. That lets the tests prove the exit code is 1 for an edited, missing or leftover file and 0 for fresh ones, without waiting for the real generators.

The same task also: made `tool/check` find the repo root once (`root="$(pwd)"`) instead of relying on `$OLDPWD`; made it refuse a member that is listed as both a Flutter and a Dart member; and added a test that the style check flags `Duration(days: 1)`.

**Where it lives:** `tool/check_generated`, `tool/check` (step "generated files fresh"), `tool/test/check_generated_test.dart`, `tool/test/check_script_test.dart`, `docs/flow.md` ("Generated-file freshness").

**Try it yourself:** from the repo root run `echo '// stale' >> app/lib/router/app_router.g.dart && tool/check_generated; git status --short`. You should see `stale: app/lib/router/app_router.g.dart`, the message "generated files were out of date and have been regenerated; review and commit them", and no change in `git status` for that file, because regenerating removed your edit. Run `tool/check_generated` again and it prints `generated files fresh`.

**Decisions:** D-53.

## 3. The database

**What we built:** the database itself: nine tables (reels, clips, which clip is in which reel, the To tag list, saved links, VN copies, settings and a time-zone history), the code that opens it, the rules for how times and fixed choices are stored, and a test that stops the tables from changing by accident. Nothing reads or writes it yet; the repositories in Tasks 6 to 8 do that.

**Why TakeTray needs it:** every reel you make and every clip you tag has to survive the app being closed, the phone restarting and the app being updated. And once the app is on your phone, the shape of this data is on your phone too: a later version can't just change it, it has to convert what is already there.

**Key ideas:**

- **SQLite: the database is a file, not a server.** With MySQL or MongoDB on a website, the database is a separate program on a server, and your code talks to it over the network with a host name, a user and a password. SQLite has no server. It is a library built into the app, and the whole database is one file, `taketray.sqlite`, in TakeTray's private folder on the phone. No other app can read it, there is no password and no network (TakeTray has no internet permission at all), and only one user ever uses it. It still speaks the same SQL as MySQL: tables, rows, `SELECT`, `JOIN`, indexes, transactions. We use tables and joins rather than MongoDB-style documents because the data is relational: one clip can be in many reels, and one reel has many clips.

- **Drift: tables written in Dart.** Instead of writing `CREATE TABLE` by hand, you describe each table as a Dart class, and Drift's code generator writes the SQL, a typed class for each row and the query code (in `app_database.g.dart`, about 6,500 lines nobody edits). This is the reels table:

  ```dart
  @DataClassName('ReelRow')
  class Reels extends Table {
    IntColumn get id => integer().autoIncrement()();
    TextColumn get name => text()();
    TextColumn get description => text().nullable()();
    TextColumn get status => textEnum<ReelStatus>()();
    IntColumn get createdAt => integer().map(const UtcMillisConverter())();
    IntColumn get updatedAt => integer().map(const UtcMillisConverter())();
  }
  ```

  and this is the SQL Drift creates from it on the phone (read back from a test database's `sqlite_master`):

  ```sql
  CREATE TABLE "reels" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "description" TEXT NULL, "status" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL)
  ```

  The gain over writing SQL strings is that mistakes are caught when the code compiles, not when you tap a button: a misspelt column (`db.reels.nmae`) or a text where a number belongs does not compile, and every row comes back as a `ReelRow` with real Dart types (`DateTime createdAt`, `ReelStatus status`). The row classes end in `Row` so they don't clash with the app's own `Reel` and `Clip` models (Task 5); repositories turn one into the other.

- **The tables at a glance** (all in `app/lib/data/database/tables.dart`):

  | Table | One row is… | Key |
  |---|---|---|
  | `reels` | a reel: name, description, status, dates | `id` |
  | `clips` | facts about one video (never the video): its MediaStore id or picker link, size, length, when it was shot, its zone | `id`; unique (`volume_name`, `media_store_id`), unique `picker_uri` |
  | `clip_reels` | "this clip is in this reel" | (`clip_id`, `reel_id`) |
  | `inbox` | a clip in To tag (`pending`) or Skipped (`skipped`) | `clip_id` |
  | `reel_references` | a saved link for a reel (not called `references`, which is an SQL keyword) | `id`; unique (`reel_id`, `url`) |
  | `vn_sessions` | the folder a reel's clips were copied into for VN | `reel_id` |
  | `vn_copies` | one copied file of that session | (`reel_id`, `clip_id`) |
  | `settings` | one setting, its value stored as JSON text | `key` |
  | `zone_timeline` | "from this moment, the phone was in this time zone" | `at` |

  The unique keys on `clips` are what will stop the same video being added twice (Review Focus 5 in Task 7). They have one gap: SQLite treats two NULLs as different, so a detected clip saved without its `volume_name` would never match anything. Two `CHECK` rules close it, so the database itself refuses such a row (the test `a clip identity is never half empty`):

  ```dart
  "CHECK (source <> 'mediaStore' OR "
      '(volume_name IS NOT NULL AND media_store_id IS NOT NULL))',
  "CHECK (source <> 'picker' OR picker_uri IS NOT NULL)",
  ```

- **Foreign keys and cascade.** `clip_reels` points at a clip and a reel. Declaring those as foreign keys means SQLite refuses a link to a reel that doesn't exist, and `ON DELETE CASCADE` means deleting a reel also deletes its links, its saved links and its VN session (and that session's copies) in the same statement:

  ```dart
  IntColumn get reelId =>
      integer().references(Reels, #id, onDelete: KeyAction.cascade)();
  ```

  One SQLite surprise if you come from MySQL: it does **not** enforce foreign keys unless every connection switches them on. So the database runs this each time it opens, and a test (`foreign keys are on`) checks it:

  ```dart
  beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  ```

  Deleting a clip, in turn, deletes its reel links and its To tag row. Deleting a reel does not delete its clips: a clip may be in other reels. Clearing out clips that end up in no reel is a repository rule (Task 6).

  One link is deliberately *not* a foreign key: `vn_copies.clip_id` is a plain number (`IntColumn get clipId => integer()();`). A `vn_copies` row is TakeTray's only note of a file it copied into `Movies/TakeTray/` for VN. If removing a clip from its last reel deleted that note too, the app would lose track of a file it created. Clip ids are never reused (`AUTOINCREMENT`), so the leftover number can't point at the wrong clip (the test `deleting a clip keeps the record of its VN copy`).

- **Times are UTC milliseconds.** Every moment (when a clip was shot, when a reel was created) is stored as a plain number: milliseconds since 1 January 1970 in UTC, like a `BIGINT` epoch column in MySQL. One small converter turns it into a Dart `DateTime` and back:

  ```dart
  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
  ```

  UTC means a reel made in London and opened in Goa still sorts correctly. Milliseconds matter because Drift's built-in date column keeps only whole seconds, and two clips shot in the same second would lose their order. The test `times round-trip in UTC milliseconds` stores `DateTime.utc(2026, 10, 26, 9, 30, 15, 123)` and checks that exactly that comes back, still in UTC. Showing a time in your local zone is the screen's job.

- **Fixed choices are stored by name.** A reel's status is stored as the text `collecting`, `ready` or `published`, not as 0, 1, 2. If a later version adds a status in the middle of the list, numbers would shift and every saved reel would silently change status; names don't. The enums themselves are plain Dart in `app/lib/domain/models/enums.dart`.

- **What a migration is.** On a server, a migration is a script you run once against the one production database (Rails, Laravel or Flyway migrations) before deploying the new code. On phones there are thousands of databases, one per phone, and each one is converted by the app itself the first time the new version opens it, with nobody watching. The database file remembers which shape it has in a number, `PRAGMA user_version`, and the app knows which shape it expects:

  ```dart
  @override
  int get schemaVersion => 1;
  ```

  When the app opens the file, Drift compares the two: an empty file gets `onCreate` (create all tables), an equal number needs nothing, and any other number runs `onUpgrade`: an older one so it can convert the old tables step by step, or a newer one, when a file written by a newer TakeTray is opened by an older build (a downgrade). At version 1 nothing is older, so the only way into `onUpgrade` is that newer file, and it refuses: stamping a newer file "version 1" would damage it. Drift only writes the new number after `onUpgrade` succeeds, so the file is left untouched (the test `a database from a newer app version is not opened` checks both).

- **How the tests protect your data on upgrade.** `dart run drift_dev make-migrations` saves a snapshot of the tables, `app/drift_schemas/taketray/drift_schema_v1.json`. That file is committed, and from then on it is a promise: "a phone with version 1 has exactly these tables". Two checks hold us to it:
  - `tool/check_generated` runs `make-migrations` again. If someone edits a table but forgets to raise `schemaVersion`, it stops with "A schema for version 1 of the taketray database already exists and differs from the current schema".
  - `app/test/drift/taketray/schema_test.dart` builds a database exactly as each snapshot describes, opens it with today's `AppDatabase` (which runs any migrations) and compares the result with the tables in today's code:

    ```dart
    final schema = await verifier.schemaAt(version);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await db.validateDatabaseSchema(
      options: const ValidationOptions(validateDropped: true),
    );
    ```

    We tried it: adding a column `extra` to `reels` without a migration makes it fail with `Schema does not match`, naming `reels`, the column `extra`, and "The actual schema does not contain anything with this name."

  When version 2 comes, `make-migrations` saves `drift_schema_v2.json` and generates more: a `stepByStep` helper to write the upgrade with, and `migration_test.dart`, which upgrades a version 1 database to version 2 and checks the result, plus a template for checking that rows survive the upgrade. So a broken migration fails on a laptop, not on your phone. At version 1 those files don't exist yet, because there is nothing to upgrade from; the test helpers in `test/drift/taketray/generated/` were made with `dart run drift_dev schema generate --data-classes --companions` (D-54).

- **"Now" comes from a provider.** Code that stores a time asks `clockProvider` for it instead of calling `DateTime.now()`, so a test can swap in a `FixedClock` and know exactly which time gets saved. The database is a provider too, `appDatabaseProvider`, which opens the file once and keeps it open while the app runs. Tests use `testDatabase()`, a fresh database that lives only in memory.

**Where it lives:** `app/lib/data/database/` (`tables.dart`, `converters.dart`, `app_database.dart`, `connection.dart`), `app/lib/domain/models/enums.dart`, `app/lib/core/clock.dart`, `app/build.yaml`, `app/drift_schemas/taketray/`, `app/test/drift/taketray/`, `app/test/data/database/app_database_test.dart`, `app/test/support/`. The open-and-migrate steps are in `docs/flow.md` ("Database open and migrations").

**Try it yourself:** from the repo root run `(cd app && ../tool/flutter test test/data/database test/drift)`. You should see the eleven database tests (foreign keys, the reel cascade, unique clips, half-empty identities, the clip cascade, the kept VN copy record, picked clips, UTC milliseconds, a local time read back in UTC, enums by name, the newer-version refusal) and `a version 1 database opens as the current schema`, ending in `+12: All tests passed!`.

**Decisions:** D-15 (Drift), D-53 (generated files and schema dumps are committed and checked), D-54 (this schema).

## 4. Models and rules

**What we built:** the app's own words for its data, and the small rules about them. Nine immutable model classes (`Reel`, `Clip`, `NewClip`, `ClipFingerprint`, `ReelReference`, `VnSession`, `VnCopy`, `ZoneEntry`, `AppSettings`) and five pure rules: how long a name may be, how a pasted link is cleaned, which site a link is from, which time zone the phone was in at a moment, and what to call a second VN folder with the same name. None of it touches the database yet; the repositories in Tasks 6 to 8 will use it.

**Why TakeTray needs it:** the screens should be able to say `reel.status` and `clip.fingerprint.durationMs` without knowing there are tables underneath, and the rules ("40 characters", "the same Instagram reel is one reference") must be written once, so the reel form, the importer and the share handler all agree.

**Key ideas:**

- **A model is not a row.** Section 3 made `ReelRow`, which is exactly one line of the `reels` table: its field types are chosen to fit SQLite. `Reel` is the same information as the app thinks of it. Today they look alike; they will drift apart (a `Clip` will hold a `ClipFingerprint` object, while its row holds four flat columns). Keeping both means a change in how we store things does not ripple into every screen, and the `domain/` folder imports neither Flutter nor Drift, so it can be tested with nothing but Dart. A repository's job is to turn one into the other.

- **What `freezed` writes for you.** This is the whole source of a model:

  ```dart
  @freezed
  abstract class ZoneEntry with _$ZoneEntry {
    const factory ZoneEntry({
      required DateTime at,
      required String zoneId,
    }) = _ZoneEntry;

    factory ZoneEntry.fromJson(Map<String, dynamic> json) =>
        _$ZoneEntryFromJson(json);
  }
  ```

  From those few lines the generators (`zone_entry.freezed.dart` and `zone_entry.g.dart`, never edited by hand) write the real class: `==` and `hashCode` that compare every field, `toString`, `copyWith`, and `toJson`/`fromJson`. If you know TypeScript, think of a `readonly` interface plus a spread-copy helper (`{...entry, zoneId: 'UTC'}`), but checked by the compiler.

- **Why immutable helps.** Once built, a model can never change. If the To tag screen holds a `Clip`, no other code can quietly alter it while the screen is drawing. To "change" something you make a changed copy, and the old one is untouched:

  ```dart
  final c = a.copyWith(zoneId: 'Asia/Kolkata');
  expect(c.zoneId, 'Asia/Kolkata');
  expect(a.zoneId, 'UTC');
  ```

  Two models with the same fields are equal (`expect(a, b)`), which is what lets the UI skip redrawing something that did not change, and lets tests compare whole objects in one line. Even the list inside `AppSettings` is locked: adding to `settings.watchedFolders` throws.

- **`Clip` and `NewClip`.** A clip that is about to be saved has no `id` yet (the database hands it out), no `firstSeenAt` and so on. So there are two types: `Clip` is one that is stored, `NewClip` is one that is not yet. `NewClip` has two ways to build it, one per source, each asking for exactly the identity that source has:

  ```dart
  NewClip.mediaStore(mediaStoreId: 1, volumeName: 'external_primary', fingerprint: ...)
  NewClip.picker(pickerUri: 'content://...', fingerprint: ...)
  ```

  Section 3's database `CHECK` rules refuse a clip without its identity; `NewClip` refuses it one step earlier, in Dart, with a clear message (`a picker clip needs pickerUri`).

- **Counting characters, not code.** Rule: a reel name is 1 to 40 characters after trimming spaces and invisible characters (a zero-width space, for example, which you cannot see but which would otherwise make a blank name look filled in). In code, "length" is not what a person sees. This is real output from the tests:

  ```dart
  // 👨‍👩‍👧 is 5 code points and 8 UTF-16 units; 🇮🇳 is 2 code points.
  expect(checkReelName('👨‍👩‍👧' * 40), isNull);
  const decomposed = 'e\u0301';            // "e" + a combining accent: looks like é
  expect(decomposed * 40, hasLength(80));   // 40 of them are 80 code units long
  expect(checkReelName(decomposed * 40), isNull);
  ```

  Dart's `String.length` counts 16-bit units, so a family emoji is 8 and an `é` typed as two pieces is 2. The rule uses the `characters` package, which counts what you see:

  ```dart
  final length = normalizeName(raw).characters.length;
  if (length == 0) return ReelNameProblem.empty;
  if (length > reelNameMaxLength) return ReelNameProblem.tooLong;
  ```

  So 40 emoji pass and 41 fail, `'  Goa  '` is saved as `Goa`, and a name of only spaces is "empty". The label on a saved link works the same way with 60 as the limit, and empty or `null` simply means "no label".

  A rule returns a *problem* (an enum value) or `null` for "fine". The screen turns the problem into a message in the user's language; the rule never contains text meant for the user. When a repository has to refuse, it throws `InvalidInputException(problem)` carrying that same enum.

- **Cleaning a pasted link.** When you share an Instagram reel into TakeTray, the link carries tracking. Two shares of the same reel look different:

  ```
  https://www.instagram.com/reel/ABC/?igsh=one
  https://www.instagram.com/reel/ABC/?igsh=two&utm_source=ig
  ```

  Different apps even spell the address differently (`http://instagram.com/reel/ABC?utm_source=ig_web_copy_link`, `https://m.instagram.com/reel/ABC/`, `https://instagr.am/reel/ABC/`). `normalizeReferenceUrl` turns all of these into the one form `https://www.instagram.com/reel/ABC/` (always `https`, always the `www.instagram.com` host, no query, exactly one trailing slash), so the second save is reported as "already saved" instead of adding a duplicate. Only those four Instagram hosts (`instagram.com`, `www.`, `m.` and `instagr.am`) are rewritten and lose their query; a YouTube link would break without `?v=`:

  ```dart
  if (!_instagramHosts.contains(parsed.host)) return withoutFragment;
  ```

  Edge cases the tests pin down: text with a space in it is not a link (`'not a url'`, or a pasted sentence), `ftp://x` and `mailto:` are refused (only `http` and `https`), `instagram.com/reel/ABC` with no `https://` is refused (it has no scheme), the path is kept as typed (letters keep their case: `ABC` and `abc` are different reels) except that an Instagram link always ends in exactly one `/` (so `.../ABC`, `.../ABC/` and `.../ABC//` match), and `l.instagram.com/?u=...` is left alone because its query *is* the link. One honest limit: `/p/ABC/`, `/reel/ABC/` and `/someuser/reel/ABC/` can be the same video and are still treated as three different links. The function returns `null` for anything unusable, so the caller can't forget to check.

  `referenceSourceOf` then picks the label (Instagram, YouTube, TikTok, or plain link) from the host. It matches the domain or a subdomain of it (`m.youtube.com`, `vm.tiktok.com`), and never a look-alike: `notinstagram.com` is a plain link.

- **Which time zone was the phone in?** The phone records a *timeline* of "from this moment, in this zone" (`ZoneEntry`), oldest first. `zoneAt` finds the zone for a clip by taking the last entry that is not after the clip's time:

  ```dart
  expect(zoneAt(timeline, DateTime.utc(2026, 2, 28, 23, 59)), isNull);        // before the first entry
  expect(zoneAt(timeline, DateTime.utc(2026, 3, 10, 12)), 'Europe/London');   // exactly at an entry
  expect(zoneAt(timeline, DateTime.utc(2026, 3, 15)), 'Europe/London');       // between entries
  ```

  Before the first entry we do not know, so the answer is `null`, not a guess. It finds the entry by repeatedly halving the list (binary search) rather than walking all of it, so it stays quick when the timeline has years of travel in it.

- **"Goa (2)".** VN gets a folder per reel, named after the reel. If a second session for a reel called "Goa" needs a folder, `uniqueFolderName` tries `Goa`, then `Goa (2)`, `Goa (3)` and so on:

  ```dart
  expect(uniqueFolderName('Goa', {'Goa', 'Goa (2)'}), 'Goa (3)');
  expect(uniqueFolderName('Goa', {'Goa', 'Goa (3)'}), 'Goa (2)');   // a gap is filled
  expect(uniqueFolderName('Goa', {'goa'}), 'Goa (2)');              // case does not matter
  ```

  Case is ignored because Android's shared storage treats `Goa` and `goa` as the same folder.

**Where it lives:** `app/lib/domain/models/` (one file per model, plus `enums.dart` from Section 3) and `app/lib/domain/rules/` (`text_limits.dart`, `reference_url.dart`, `zone_lookup.dart`, `folder_names.dart`). Tests are in `app/test/domain/`, one file per rule and one for all the models.

**Try it yourself:** from the repo root run `(cd app && ../tool/flutter test test/domain)`. You should see `+76: All tests passed!`. Then break a rule on purpose: in `app/lib/domain/rules/text_limits.dart` change `const reelNameMaxLength = 40;` to `39`, run the same command, and watch `40 emoji pass and 41 fail` and the other limit tests fail. Change it back.

**Decisions:** D-55.

## 5. Saving reels *(coming in Task 6)*

## 6. Clips and the To tag list *(coming in Task 7)*

## 7. References, VN folders, settings and time zones *(coming in Task 8)*

## 8. Backup: export and import *(coming in Task 9)*

## 9. Measuring test coverage *(coming in Task 10)*

## 10. Automatic checks on GitHub *(coming in Task 11)*

## 11. Proving it works on the phone *(coming in Task 12)*

---

## Glossary *(completed in Task 13)*
