# Learning guide: Phase 9B, Sharing into TakeTray

This guide explains how a link shared from Instagram (or any app) reaches TakeTray: the see-through share screen with its own Flutter engine, how two engines share one database, the Save reference sheet, opening the saved reel through onboarding, and the reels step that lists reels made by a share. It ends with how it was checked on a real Samsung Galaxy S24 Ultra.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-162, so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-162.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [The share entry](#2-the-share-entry)
3. [Two engines, one database](#3-two-engines-one-database)
4. [Open reel, held through onboarding](#4-open-reel-held-through-onboarding)
5. [The Save reference sheet](#5-the-save-reference-sheet)
6. [The share screen over the sharing app](#6-the-share-screen-over-the-sharing-app)
7. [Onboarding: reels made by a share](#7-onboarding-reels-made-by-a-share)
8. [Patrol flows](#8-patrol-flows)
9. [On the S24](#9-on-the-s24)

## 2. The share entry

### What we built

The door a share comes in through. In Instagram (or any app) you tap **Share**, pick **TakeTray**, and Android starts a new screen of TakeTray's, `ShareActivity`. It has its own Flutter engine, which runs a second Dart entry point, `shareMain`, instead of the app's `main`. Its window is see-through, so the app you shared from stays visible behind it.

A small bridge, `ShareHostApi`, lets Dart ask for the shared text and close the screen. The share engine also writes its own log files, and Settings › Send error log now sends both engines' logs.

The screen is still empty here: Back closes it. The Save reference sheet arrives in sections 5 and 6.

### Why TakeTray needs it

Saving a reel you saw on Instagram should take two taps and leave you where you were. That rules out opening the whole app: it would cover Instagram, and whatever you had open in TakeTray (a half-tagged clip, say) would be disturbed. A separate, see-through screen in Instagram's own task does neither. When it closes, you are back on the reel you shared.

### Key ideas

**1. Two entry points, one app.** `main()` starts the app; `shareMain()` starts the share screen. Android only knows a function by its name, so `ShareActivity` names it, and Dart must keep it in a release build even though no Dart code calls it:

```dart
@pragma('vm:entry-point')
Future<void> shareMain() => runAppWithLogging(
  () => runApp(const ProviderScope(child: ShareApp())),
  logDir: getApplicationSupportDirectory,
  filePrefix: shareLogPrefix,
  maxLogBytes: 128 * 1024,
);
```

That function is `runShareScreen` in `share_main.dart`. The name Android runs, `shareMain`, is declared in `main.dart` itself:

```dart
@pragma('vm:entry-point')
Future<void> shareMain() => runShareScreen();
```

Why there? `ShareActivity` says which file its entry point is in (`package:taketray/share_main.dart`), but Flutter throws that away and looks the name up in the app's **root library**, `main.dart`. At first `main.dart` only re-exported `shareMain` from `share_main.dart`. That works in a debug build, which finds names a library re-exports, so every check on the emulator and in TakeTray Dev passed. A release build is compiled ahead of time and finds only what `main.dart` declares itself, so in the real TakeTray the share screen stayed empty and the log said "Could not resolve main entrypoint function" (D-163 item 12). The lesson: an entry point Android names must be a real function in the root library, and only a release build proves it.

**2. An exported screen is a door for every app.** Any app on the phone can start `ShareActivity`, with any extras in the intent. `FlutterActivity` reads several settings from those extras: a route to open, a cached engine to use (an unknown one crashes the process), flags for the engine. `ShareActivity` fixes every one of them in code, so an intent can only bring text:

```kotlin
override fun getInitialRoute(): String? = null
override fun getCachedEngineId(): String? = null
override fun getFlutterShellArgs(): FlutterShellArgs = FlutterShellArgs(emptyArray<String>())
```

**3. In the sharing app's task, out of Recents.** The manifest gives `ShareActivity` no `taskAffinity` and the standard launch mode, so it opens on top of Instagram in Instagram's task. `excludeFromRecents` keeps it out of the Recents list. When Instagram started it in a task of its own, closing uses `finishAndRemoveTask()`, so that task goes too:

```kotlin
if (host.isTaskRoot) host.finishAndRemoveTask() else host.finish()
```

**4. See-through, with no splash.** The app's launch screen has a splash. The share screen must not: it should look like a sheet sliding up over Instagram. `ShareTheme` is translucent, with a transparent background, no title and `windowDisablePreview`, so Android draws no starting window either. The Flutter view is transparent too (`BackgroundMode.transparent`).

**5. The text is read once.** `sharedText()` remembers which intent it answered for. A second call gets null, so the same share is never shown twice. If you share again while the screen is open, `onNewIntent` swaps in the new intent, and the next call gets the new text:

```kotlin
val intent = host("sharedText").intent
if (intent == null || intent === read) return@guardedWith null
read = intent
```

It is cut to 20,000 characters (a long caption is not a link anyway), never in the middle of an emoji.

**6. Two engines, two log files.** Both engines run in the same app process, each in its own Dart isolate, and both write logs. If they shared one file, both would try to rotate it. So the share engine writes `share-0.log` and `share-1.log` (128 KiB each) beside the app's `taketray-*.log`, and Send error log joins all four. The shared text never reaches either log: only its length. Two share screens open at once share one `share-0.log`, so the sink reads the file's size before every write instead of keeping its own count, which the other engine's writes would make wrong.

### Where it lives

- `app/pigeons/share_api.dart`: the contract.
- `app/android/app/src/main/kotlin/app/taketray/share/`: `ShareActivity.kt`, `ShareHostApiImpl.kt`, `ShareBridges.kt`.
- `app/android/app/src/main/AndroidManifest.xml` and `res/values{,-night}/styles.xml` (`ShareTheme`).
- `app/lib/share_main.dart`, `app/lib/features/share/share_app.dart`, `app/lib/platform/share_bridge.dart`.
- `app/lib/core/logging/`: `log_file_sink.dart` (the prefix), `logging_setup.dart`, `log_bundle.dart`.
- Docs: `docs/flow.md` ("Sharing into TakeTray"), D-163.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/platform/share_bridge_test.dart \
  test/features/share test/share_main_test.dart test/core/logging
cd .. && tool/test_android --tests 'app.taketray.share.*' --tests 'app.taketray.ManifestTest'
```

Then break one thing on purpose. In `ShareHostApiImpl.kt`, delete the line that checks the type (`normalizeMimeType`) and run the Kotlin tests: "another type, or none, is null" fails, because a shared photo would now be read as text. Put it back.

### Decisions

- D-163: `ShareActivity` and its manifest entry, the fixed engine settings, `ShareTheme`, the share bridge (read once, the 20,000 cap, closing with the task), the three bridges the share engine has, `shareMain` and `ShareApp`, and the share log.

## 3. Two engines, one database

### What we built

The app and the share screen each run their own Flutter engine (section 2), and both need TakeTray's database: the share saves a reel or a reference, and Home shows it. Each engine now opens its own connection to the one file, `taketray.sqlite`, set up so that the two never trip over each other. When an engine comes back to the front, it re-reads the reels and their references, so it shows what the other engine saved meanwhile.

### Why TakeTray needs it

You can share from Instagram while TakeTray is open behind it, or with TakeTray closed. Either way the reel must be saved once, never lost, and Home must show it when you go back. Two connections writing to one SQLite file at the same moment can fail with "database is locked", and a screen in one engine has no idea the other engine wrote anything.

### Key ideas

**1. Two engines are two separate worlds.** Each engine runs its own Dart code with its own memory. Riverpod's providers are built once per engine, so `appDatabaseProvider` makes one connection in the app and another in the share screen. Drift offers a way to share one connection between isolates (`shareAcrossIsolates`), but its own docs say it does not work across independent engines, and its connection would belong to whichever engine opened it first. We meant to test it on the emulator first; the emulator had no system image and the disk had no room for one, so we took the plan's fallback (D-164).

**2. SQLite's own rules keep two connections safe.** Every connection, as it opens, sets two things:

```dart
final DriftNativeOptions appDatabaseOptions = DriftNativeOptions(
  setup: (db) => db
    ..busyHandler = busyWait()
    ..execute('PRAGMA journal_mode = WAL'),
);
```

WAL (write-ahead logging) lets one engine read while the other writes. The busy wait makes a write wait up to 5 seconds for the other engine's write to finish, instead of failing at once. Drift starts every transaction with `BEGIN IMMEDIATE`, so a transaction waits at its start and never fails half way through. The order matters: switching to WAL needs a moment alone with the file, so the wait must already be in place.

**Why not SQLite's own `PRAGMA busy_timeout = 5000`?** It was the first version, and it passed on a Mac but failed on GitHub's Linux runner with "database is locked" in about 60 ms. SQLite's wait never looks at a clock: it adds up the sleeps it *asked* for (1, 2, 5, 10 ms … then 100 ms) until they make 5 s. On Linux and Android the Dart VM's profiler, which `flutter test` and `flutter run` switch on, sends every thread a signal about every millisecond, and a signal ends SQLite's sleep early. So 60 "sleeps" of under a millisecond each counted as 5 seconds. `busyWait` (in `busy_wait.dart`) takes the same steps but asks a `Stopwatch` how long it has really waited, and sleeps with Dart's `sleep`, which carries on after a signal. A release build has no profiler, but the app should not depend on that.

**3. Streams only hear their own connection.** Home watches the reels with a drift `watch` stream. Drift re-runs it after a write on the same connection, but it never hears about the other engine's writes. So `DatabaseRefresh` tells the database, each time the engine comes back to the front, that the reels and references may have changed:

```dart
void _refresh() {
  if (!ref.exists(appDatabaseProvider)) return;
  final db = ref.read(appDatabaseProvider);
  db.notifyUpdates({
    TableUpdate.onTable(db.reels),
    TableUpdate.onTable(db.reelReferences),
  });
}
```

Every stream on those tables runs its query again. Both apps have exactly one `DatabaseRefresh`, above their `MaterialApp`. The share screen covers the app while it is open, so "when the app comes back" is exactly when you could see the new reel.

**4. Two engines can open the file at the same moment.** On a fresh install, both could find the file empty and both try to create the tables; the second would fail with "already exists", and drift would keep that error for the engine's whole life. So creating the schema now happens in a transaction that checks the version again and writes it inside:

```dart
onCreate: (m) => transaction(() async {
  if (await _storedVersion() != 0) return;
  await m.createAll();
  await customStatement('PRAGMA user_version = $schemaVersion');
}),
```

The second engine's transaction waits for the first, then sees version 2 and does nothing. Upgrades do the same: the steps run from the version read inside the transaction.

### Where it lives

- `app/lib/data/database/connection.dart`: `appDatabaseOptions` and `appDatabaseProvider`.
- `app/lib/data/database/busy_wait.dart`: `busyWait`, the 5 s wait on a real clock.
- `app/lib/data/database/app_database.dart`: the migration strategy (`onCreate`, `onUpgrade`).
- `app/lib/app/database_refresh.dart`: `DatabaseRefresh`; used in `app/lib/app.dart` and `app/lib/features/share/share_app.dart`.
- Docs: `docs/flow.md` ("Database open and migrations", step 5), D-164.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/data/database/connection_test.dart \
  test/app/database_refresh_test.dart test/drift
```

`connection_test.dart` uses two provider containers as two engines on one temporary file. One test holds the write lock from a third connection while both "engines" open, so both read the version before either can create the tables.

Then break one thing on purpose. In `connection.dart`, delete the `busyHandler` line and run `connection_test.dart` again: the test where both engines write 40 times at once fails with `database is locked`. Put it back. Then try `busy_wait_test.dart`: its "sleeps cut short by signals" test is the Linux runner's case on a fake clock; make `busyWait` add up its sleeps instead of reading the clock, and it fails.

### Decisions

- D-164: why there is no device proof, a connection per engine with WAL and a 5 s busy wait (point 7: why it is not SQLite's `busy_timeout`), the re-read on resume, migrations that are safe on two connections, and the checks left for the S24.

## 4. Open reel, held through onboarding

### What we built

The share screen has an **Open reel** button. It now really opens TakeTray on the reel you just saved to, on that reel's References. If TakeTray has never been through onboarding, the reel waits in memory and opens the moment onboarding ends.

### Why TakeTray needs it

The share screen runs in its own engine and cannot show TakeTray's screens. It can only ask the app to open one. TakeTray already has one safe way for something outside the app to ask: a launch action, an allow-listed word plus, at most, a reel number (D-103). Open reel is a fourth word, `openReel`. The catch is onboarding: a first-time user sees the welcome and steps, and D-136 says a tap that arrives then is dropped so it cannot pull them off their step. For Open reel that would throw the user's one tap away, so this one action is held instead.

### Key ideas

**1. One more word on the allow-list.** Kotlin's `LaunchActions` knows `toTag`, `reels`, `doneEditing` and now `openReel`. Like `doneEditing` it carries a reel id, and only a number from 1 to `MAX_REEL_ID` counts:

```kotlin
val reelId = if (hasReel(action) && reel in 1..BackgroundState.MAX_REEL_ID) reel else null
```

Another app can start the exported `MainActivity` with anything, so a bad id still gives an `openReel` launch, just with no reel, and Dart opens the reels list.

**2. The share screen starts MainActivity, then goes away.**

```kotlin
host.startActivity(LaunchActions.intent(host, LaunchActionMsg.OPEN_REEL, reelId))
...
close(host)
```

An id outside the range starts nothing and only closes the screen, with a log line that says why and nothing else. The screen closes the same way `finish()` does, so nothing is left in Recents.

**3. Dart decides the screen.** `routeFor` turns the launch into a route and checks the reel still exists: `Routes.reelReferences(id)` if it does, `Routes.reels` if it was deleted or the id is unusable.

**4. Held, not dropped.** In `LaunchActionsListener`, while onboarding is not done:

```dart
if (launch.action != LaunchAction.openReel) {
  _log.info('A tap during onboarding was dropped');
  return;
}
_held = launch; // the newest wins
```

The listener also listens to the onboarding gate. When it reports done, the held launch goes through the same queue as any tap, once, and is cleared. Nothing is written anywhere, so if Android kills the app during onboarding the held reel is forgotten (the reel itself was already saved by the share).

### Where it lives

- `app/pigeons/background_api.dart`, `app/lib/platform/background_api.g.dart`, `app/android/.../background/BackgroundApi.g.kt`: `openReel` in the launch enum.
- `app/android/app/src/main/kotlin/app/taketray/background/LaunchActions.kt` and `.../share/ShareHostApiImpl.kt`.
- `app/lib/platform/background_bridge.dart`, `app/lib/features/notifications/view_models/launch_actions.dart` (`routeFor`), `app/lib/app.dart` (`LaunchActionsListener`).
- Docs: `docs/flow.md` ("Launch actions", items 7 and 8), D-165.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/app_test.dart test/app/launch_actions_test.dart
../tool/test_android --tests 'app.taketray.background.LaunchActionsTest' --tests 'app.taketray.share.ShareHostApiImplTest'
```

Then break one thing on purpose. In `app.dart`, change the held branch so `openReel` is dropped like the others (`if (true) {`) and run `app_test.dart`: the tests in "openReel held through onboarding" fail because nothing opens after onboarding. Put it back.

### Decisions

- D-165: the fourth launch action, how the share screen starts MainActivity, why an `openReel` is held in memory through onboarding (amending D-136 for this action only), and what a kill forgets.

## 5. The Save reference sheet

### What we built

The sheet the share screen shows: **Save reference**. It has every state a share can end in. The form lets you add an optional label and choose where the link goes: an existing reel from a list, or a new reel you name. "Already saved in {reel}" warns you when the reel you picked has the link. If the shared text has no link ("Best breakfast"), a "This isn't a link" explanation says nothing was saved. After a save you see "Saved to {reel}" with **Open reel** and **Done**, and, if you have never opened TakeTray, a short welcome note.

Along the way two small things changed elsewhere: a reference whose host holds accented letters now shows them (`café.fr`, not `caf%C3%A9.fr`), and `TtBanner` can take a margin.

### Why TakeTray needs it

A share is two taps in Instagram, so the sheet must be quick and must never lose or double a save. It also has to be honest about the odd cases: a caption with no link, a reel you already saved, a reel you deleted a moment ago, a database that another part of the app is writing to.

### Key ideas

**1. All the rules live in one controller, not in the widget.** `SaveReferenceController` holds a small immutable state (which step, the link, which reel is picked, any error), and the sheet only draws it. That way a plain test can drive every case with no screen:

```dart
await c.start('Title https://vm.tiktok.com/x/');
expect(state().step, SaveStep.form);
expect(state().kind, SharedLinkKind.tiktokVideo);
```

**2. The kind of link is read before cleaning.** TakeTray cleans a saved link so the same reel shared twice is one reference, and cleaning rewrites an Instagram `/reel/` link to `/p/`. After that a reel looks like a post. So the sheet asks `sharedLinkKindOf` about the link as it arrived:

```dart
kind: sharedLinkKindOf(Uri.parse(link)), // the raw link
url: url.toString(),                      // the cleaned one
```

**3. A double tap is one save.** `save` is single-flight: while one save runs, a second call just gets the first call's future back.

```dart
final running = _inFlight;
if (running != null) return running;
```

**4. Races end in a clear state, not a crash.** The name you typed can be taken by the time you press Save: the repository says "duplicate" and the sheet shows it under the field. The reel you picked can be deleted in the app first: the write fails and the sheet says "Couldn't save the reference." The other engine can hold the database past the 5 second wait (section 3): that is the same failure message, and the log gets the error's type (`SqliteException`) and nothing else, never a link or a name.

**5. A slow answer for an old pick is ignored.** Picking a reel reads its references to find out whether it already has the link. If you pick another reel before the first read finishes, a counter tells the first one it is out of date.

**6. A percent-encoded host is decoded for display only.** Dart keeps `café.fr` as `caf%C3%A9.fr` in a link. `displayHost` turns it back for the card and the sheet, and refuses anything odd (`%C3.com` is not valid text, `a%2Fb.com` would hide a slash), so what you read is never misleading. The stored link is not touched.

**7. The welcome note is read, never written.** The share screen must not mark onboarding done. The sheet reads the flag once through `PhoneStateRepository.onboardingDone()` and shows the note when it is false.

### Where it lives

- `app/lib/features/share/view_models/save_reference_controller.dart` and `app/lib/features/share/views/save_reference_sheet.dart`.
- `app/lib/domain/rules/shared_link_kind.dart`, `app/lib/domain/rules/reference_links.dart` (`displayHost`, `shortLink`), `app/lib/features/references/views/reference_text.dart`.
- `packages/taketray_ui/lib/src/components/banners.dart` (`TtBanner.margin`) and `app/lib/l10n/app_en.arb` (the `saveReference...` strings).
- Docs: `docs/flow.md` ("Sharing into TakeTray", the Save reference sheet), D-166.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/features/share test/domain/rules/shared_link_kind_test.dart \
  test/domain/rules/reference_links_test.dart
cd ../packages/taketray_ui && ../../tool/flutter test test/components/banners_test.dart
```

Then break one thing on purpose. In `save_reference_controller.dart`, change `kind: sharedLinkKindOf(Uri.parse(link))` to `sharedLinkKindOf(url)` and run the share tests: "the kind is read from the raw link" fails, because every Instagram reel is now a post. Put it back.

### Decisions

- D-166: the controller and its states, the raw-link kind, the decoded host for display, why the list shows no covers in the share engine, and `TtBanner.margin`.

## 6. The share screen over the sharing app

### What we built

The screen that holds the sheet. When you share a reel from Instagram, Instagram stays on screen, dimmed, and the **Save reference** sheet comes up from the bottom. It follows the phone's light or dark setting, slides in like TakeTray's other sheets (and just appears if you have "Remove animations" on), and sits above the keyboard when you type. Back, a tap on the dimmed part, **Done**, **Cancel** and **Close** all close it and put you back in Instagram. **Open reel** closes it and opens TakeTray on that reel.

### Why TakeTray needs it

This screen runs in its own small engine that lives and dies with the Android screen. If it closed in the middle of a save, the database could be left locked for the app. And a second share can arrive in two different ways. So closing and "a new share" need care that an ordinary screen does not.

### Key ideas

**1. Every way out is one function.** Back, the scrim, Done, Cancel and Close all end in `_leave`. It does its work once: a second tap, or Back after a tap, does nothing.

```dart
Future<void> _leave(Future<void> Function() go) async {
  if (_closing) return;
  _closing = true;
  await _whenIdle();   // a running save finishes first
  await go();
}
```

**2. A save is never cut off.** If you press Back while a save runs, the screen waits for the save, then closes. The engine then ends with nothing half-written, and the lock on the database is let go (section 3).

**3. A second share, two ways.** Most of the time a second share opens a second share screen with a fresh engine, so nothing special is needed. But a sender can ask Android to reuse the open screen. Android then says the screen came back to the front, and the screen asks Kotlin for the text again. If there is new text (even an empty one, which shows "This isn't a link") the sheet starts over; if there is none, it stays as it was, with what you typed.

```dart
if (state == AppLifecycleState.resumed) unawaited(_readNewShare());
```

**4. The dim page is the app's.** The scrim uses the theme's `scrim` colour at the opacity `showTtSheet` uses (`TtMetrics.scrimOpacity`), so a share looks like TakeTray's other sheets, but without the blur: there is nothing of ours behind it to blur.

**5. No onboarding changes.** This screen never writes an onboarding flag. A test gives it a phone state that throws on any call but the one the welcome note makes, and runs every path.

**6. One small move.** `resolvePhoneLocale` now lives in `lib/core/locale.dart`, so the share engine does not import `app.dart` (which pulls in the background, media and router code).

### Where it lives

- `app/lib/features/share/share_app.dart` and `app/lib/core/locale.dart`.
- `app/test/features/share/share_app_test.dart` and its goldens in `app/test/features/share/goldens/macos/`.
- Docs: `docs/flow.md` ("Sharing into TakeTray", the share screen), D-167.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/features/share/share_app_test.dart
```

Then break one thing on purpose. In `share_app.dart` delete `if (_closing) return;` from `_leave` and run the tests: "every way twice is still one finish" fails, because the second tap finishes again. Put it back.

### Decisions

- D-167: the layout, the one close path, the second share both ways, the missing blur, and the controller's disposed-state guard.

## 7. Onboarding: reels made by a share

### What we built

Onboarding's last step, "What reels are you planning?", now lists the reels that already exist. That happens when you share an Instagram reel before ever opening the app: the share made a reel, and onboarding should show it. Each row has a link icon, the name, how many references it holds ("No references", "1 reference saved", "3 references saved") and a check mark that a screen reader calls "Already created". There is no remove button. Under the list, always, a small tip says: "Tip: share any Instagram reel to TakeTray to save it as a reference."

The buttons follow the old rule: with existing reels and nothing typed, the main button is **Continue**.

### Why TakeTray needs it

Section 4 explained that a share can arrive before onboarding. If the step ignored that reel, a new user would see an empty list and might make a second reel with the same name. Showing it tells them nothing was lost, and the tip teaches the share path at the moment they choose reels.

### Key ideas

**1. One list from two streams.** The reels come from `watchAll` and the counts from `watchCounts`. The controller keeps the last answer of each and publishes only when both have arrived, so a row never shows "No references" and then jumps to "3 references saved".

```dart
void _publish() {
  final reels = _reels;
  final counts = _counts;
  if (reels == null || counts == null) return;
  state = state._with(existing: _existingFrom(reels, counts));
}
```

**2. Oldest first needs its own sort.** The database orders reels by last change, and saving a reference counts as a change, so the oldest reel can come first or last. The controller sorts by creation time, then by id.

```dart
final byTime = a.createdAt.compareTo(b.createdAt);
return byTime != 0 ? byTime : a.id.compareTo(b.id);
```

**3. Old names, new source.** `existingNames` is now computed from `existing`, so the duplicate check and the idea chips did not need to change.

**4. A failed count is not a failed screen.** If the counts cannot be read, the reels still show, each with "No references".

### Where it lives

- `app/lib/features/onboarding/view_models/reels_step_controller.dart` (`ExistingReel`, `ReelsStepState.existing`) and `app/lib/features/onboarding/views/reels_step_screen.dart` (`_ExistingRow`, `_ShareTip`).
- `app/lib/l10n/app_en.arb` (`reelsStepExistingCount`, `reelsStepExistingDone`, `reelsStepShareTip`).
- Docs: `docs/flow.md` ("Onboarding steps", the reels step), D-168.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/features/onboarding/view_models/reels_step_controller_test.dart \
  test/features/onboarding/views/reels_step_screen_test.dart
```

Then break one thing on purpose. In `reels_step_controller.dart` change `if (reels == null || counts == null) return;` to `if (reels == null) return;` (and read `_counts ?? const {}`): "a reel is never shown with a count that is not yet read" fails, because a row now shows 0 before the real count arrives. Put it back.

### Decisions

- D-168: the existing rows and their counts, the sort, the wait for both reads, the always-shown tip, and no remove button.

## 8. Patrol flows

### What we built

Four on-device flows for sharing, in `app/patrol_test/share_test.dart`, and the three small pieces they stand on: a debug-only way to start the share screen, a driver that can touch the share screen, and the safety rules of Phase 9A carried over. The flows are written and checked on a computer, but they are **skipped**: a Patrol build cannot start the share screen (section 8's last idea, and section 9). Sharing is proven by the hand checks instead.

- **Existing reel.** A reel exists. The test shares `Look https://www.instagram.com/reel/TTTEST1/?igsh=x`. The sheet opens, the test taps the reel's row, presses **Save**, sees "Saved to TakeTray Test Share A", presses **Done**, and then checks, from the app's side, that the reel holds that one reference.
- **New reel.** There are no reels, so the sheet opens on **New reel**. The test types a name, presses **Save**, then **Open reel**, and checks that the app opens that reel at its References with the link on a card.
- **Not a link.** A caption with no link is shared. The sheet says "This isn't a link" and has no **Save**; **Close** ends it, and nothing was added.
- **Before onboarding.** Onboarding is undone, the app sits on its welcome, and a share makes a new reel. The saved screen carries the welcome note. **Open reel** leaves the welcome showing (the reel is held). The test goes through onboarding's steps, where the reels step lists the shared reel, and when onboarding ends the reel's References open.

### Why TakeTray needs it

A share crosses two Flutter engines, an Android task and another app. A widget test draws one screen; only a phone shows that the sheet really opens, that its write reaches the app's database, and that Open reel survives onboarding.

### Key ideas

**1. A hook to start a share without another app.** Starting the real Instagram would need an account and the network, and would load a real page. Instead the debug build has a small channel that starts the share screen with a text, as Instagram's Share does:

```kotlin
val intent =
    Intent(Intent.ACTION_SEND)
        .setClassName(context, ShareActivity::class.java.name)
        .setType("text/plain")
        .putExtra(Intent.EXTRA_TEXT, text)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
context.startActivity(intent)
```

The one difference from a real share: an app's own context may only start an activity as a **new task**. So in the test the share screen sits in a task of its own over TakeTray, while a real one sits in Instagram's task over Instagram. What a real share returns to is a hand check. The release build has none of this code, and `tool/check_release_permissions` fails if its names (`DebugShareHooks`, `test_share`) show up in the release dex.

**2. The share screen is invisible to Patrol's finders.** Patrol's `$(...)` looks inside the app's own Flutter engine, and the share screen is another one. What can see it is Android's accessibility tree, which Flutter fills with each widget's words. So `share_screen.dart` finds a node by its words, trying both places Flutter may put them:

```dart
List<AndroidSelector> selectorsFor(String words, {bool contains = false, bool enabled = false}) {
  final only = enabled ? true : null;
  if (contains) {
    return [
      AndroidSelector(textContains: words, isEnabled: only),
      AndroidSelector(contentDescriptionContains: words, isEnabled: only),
    ];
  }
  return [
    AndroidSelector(text: words, isEnabled: only),
    AndroidSelector(contentDescription: words, isEnabled: only),
  ];
}
```

Only an **enabled** node counts for **Save**, because a disabled Save has the same words and a tap on it does nothing. Every wait fails with a sentence saying what it waited for and which resource ids are on the screen (never any text), because the first run on the phone may need these selectors adjusted.

**3. Words that are not unique are a trap.** Behind the sheet, Home is still on screen, and it has a "New reel" button and a card with the reel's name. So the flows tap the row by its full words, "TakeTray Test Share A, No references" (Home's card reads differently), and flow 2 starts with no reels so there is no "New reel" switch to confuse with Home's button.

**4. Back is dangerous here.** Patrol normally closes the keyboard after typing by pressing Back. With no keyboard up, Back reaches the share screen and closes it. So typing into the sheet uses `KeyboardBehavior.alternative`, which leaves the keyboard alone, and a unit test fails if `showAndDismiss`, `pressBack` or a tap at a point ever appears.

**5. A tear-down that can close a forgotten sheet.** If a flow fails with the sheet open, the next flow would start under it. The tear-down first closes it, but only when one of the sheet's own titles is on the screen, so it never taps an app button that happens to be called Done:

```dart
if (open == null) return closed;
await tap(open.button, what: 'the button that closes a share screen left open', timeout: buttonTimeout);
```

**6. Onboarding is put back.** Flow 4 needs onboarding undone, so it deletes the three first-launch flags. Every flow's tear-down marks onboarding done again, even when the flow failed, so after any flow the app is onboarded. Shooting mode is never switched; the tear-down only reads it before and after and fails if it changed.

**7. The flows are skipped: a Patrol build cannot start the share screen.** On the S24 all four flows waited for a sheet that never came. By hand, the plain debug build drew the sheet, so the driver and the second engine were fine. The cause is in Flutter. `ShareActivity` says where its entry point lives (`getDartEntrypointLibraryUri`, `package:taketray/share_main.dart`), but Flutter's `FlutterEngineGroup` throws that away and looks `shareMain` up in the build's **root library**. The app gets away with it because its root, `main.dart`, declares `shareMain` (at first it only re-exported it, which worked in debug but not in the release build: section 2, D-163 item 12). A Patrol build's root is a file Patrol generates (`test_bundle.dart`), which cannot re-export anything, so the share process logs "Could not resolve main entrypoint function" and draws nothing. The test's own proof: a debug build whose root re-exports `shareMain` works, and one whose root defines its own `shareMain` runs that one instead.

The owner chose **not to change `ShareActivity` or any product code** just so a test can run. So the flows stay in the repository, all four skipped with one reason (`_skipReason`; Patrol 4.10's `skip` is only a yes or no, so a non-empty reason means skipped), and a test in `share_source_test.dart` pins that there are four, that they stay skipped, and that `docs/dev-setup.md` says so. They cannot quietly start running or quietly disappear. A future fix would be for `ShareActivity` to build its own engine and start it with the library address, which changes how the release app starts the share screen. That would need a release build proved on the phone before the skip comes out.

### Where it lives

- `app/android/app/src/debug/kotlin/app/taketray/DebugShareHooks.kt` and its one line in `DebugHooks.kt`; `app/android/app/src/test/kotlin/app/taketray/DebugShareHooksTest.kt`.
- `app/patrol_test/share_test.dart` (the flows), `support/test_share.dart` (the channel's Dart side), `support/share_screen.dart` (the driver).
- `app/test/patrol_support/test_share_test.dart`, `share_screen_test.dart` (the driver against a fake phone) and `share_source_test.dart` (the safety rules, read from the source).
- `docs/dev-setup.md` ("Phase 9B check"), D-169.

### Try it yourself

From the repository root:

```sh
tool/test_android --tests 'app.taketray.DebugShareHooksTest'
cd app && ../tool/flutter test test/patrol_support/test_share_test.dart \
  test/patrol_support/share_screen_test.dart test/patrol_support/share_source_test.dart
```

Then break things on purpose. In `DebugShareHooks.kt` delete `.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)`: "it is started as a new task, which a non-activity context needs" fails. In `share_screen.dart` replace `if (open == null) return closed;` with `open ??= states.last;`: "taps nothing when no share screen is up (the app has a Done)" fails, which is exactly the mistake that would press the app's own Done. In `share_test.dart` delete the line `linksBridgeProvider.overrideWithValue(env.links),` from `_startApp`: the test "every app that is pumped has the fake links bridge" in `share_source_test.dart` fails, printing `Expected: contains 'linksBridgeProvider.overrideWithValue(env.links)'` followed by the text of `_startApp` it was looking in. That is exactly the mistake that would let a real link open during a flow, caught without a phone. Last, in `_flowTest` change `skip: skip` to `skip: false`: "_flowTest skips on the reason, with no way to run a flow" fails, so a flow cannot start running by accident. (Put all four back.)

### Decisions

- D-169: the hook and how it differs from a real share, the driver, the four flows, the safety rules, and the eighteen hand checks.

## 9. On the S24


**Hand checks (2026-11-23):** the owner made the Phase 9B hand checks on the S24 and all passed (1 to 10, 12, 12a, 12b, 13 to 18), including real shares from Instagram, YouTube and TikTok and the film icons in the reel rows. The release build over the real TakeTray (check 11) then caught the one bug no debug build could: the share screen did not start in a release build, because Android looks the share screen's entry point up in the app's main file and a release build does not follow a re-export. With `shareMain` declared in `main.dart` (D-163 item 12) the release share worked end to end, from Instagram to a new reel to first-time setup.
**What we built:** the hand checks for sharing. The Patrol test `app/patrol_test/share_test.dart` is written but skipped (section 8, D-169 item 8), so the list "Phase 9B check" in `docs/dev-setup.md` is the proof that sharing works. 9A's references flows ran on the S24 (4 of 4 passed); the share flows ran once (0 of 4) and showed the cause in section 8.

**Phone results.** None from the flows, and none can come until the share screen can start in a Patrol build. The owner's answers to the eighteen hand checks (and 12a and 12b) are still to come; they go here and in D-169.

**What this teaches:** a test that passes or fails tells you about the test's setup as much as the app. Here the app was right and the test build was the odd one out, and the way to see it was to start the real screen by hand, then change one thing at a time in the build until the failure moved. And when the only fix is in the product, not the test, the owner decides: that choice, and what it would take later, is written down where the next person will look (D-169 item 8).

## What the phase leaves you with

- **One door for a share.** Any app that shares text can open one see-through screen of TakeTray's, and that screen takes nothing from the intent but the text. Back, the scrim, Done, Cancel and Close all leave through one path that waits for a save to finish.
- **Two engines, one database.** The share screen and the app are separate Flutter engines in one process, each with its own connection to the same file. A write on one is read by the other, and a re-read when TakeTray comes back to the front keeps Home from showing old data.
- **A link is a plain, tested rule.** The sheet finds the first usable link in whatever was shared, shows what it is, and saves it through the same rules as 9A's references: a reel is picked or made, and nothing is half saved when two shares race.
- **A share can come before the app has ever been opened.** It saves, tells a new user what comes next, and Open reel is held in memory until onboarding is done. Onboarding's reels step then lists the reel, so it is not made twice.
- **The phone test cannot open a real link or touch another app.** A debug-only hook starts the share screen with a text, a fake stands in for the links bridge, and the tear-down closes a sheet left open and puts onboarding back to done.
- **What only a person can judge is a numbered list.** A real Instagram, YouTube and TikTok share, where Done returns to, Recents, TalkBack, large text, dark mode, the keyboard and the release build over the real app are on "Phase 9B check", to be answered by number.
