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

A Flutter build compiles only the files `main.dart` reaches, so `main.dart` exports `shareMain`, and `ShareActivity` says which file it is in (`package:taketray/share_main.dart`).

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

**6. Two engines, two log files.** Both engines run in the same app process, each in its own Dart isolate, and both write logs. If they shared one file, both would try to rotate it. So the share engine writes `share-0.log` and `share-1.log` (128 KiB each) beside the app's `taketray-*.log`, and Send error log joins all four. The shared text never reaches either log: only its length.

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
