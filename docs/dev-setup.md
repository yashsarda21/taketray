# TakeTray: Developer setup

Everything goes through the wrappers in `tool/`. The `flutter` on `PATH` is 2.8.1 and must never be used.

| Wrapper | Runs |
|---|---|
| `tool/flutter`, `tool/dart` | the pinned SDK in `~/development/flutter` (Flutter 3.47.7) |
| `tool/adb` | `~/Library/Android/sdk/platform-tools/adb` |
| `tool/patrol` | `patrol_cli` with the pinned Flutter first on `PATH` |

## Commands

- `tool/check`: generated-file and token freshness, format, analysis, style rules, all tests (including the Android unit tests, `tool/test_android`) and the coverage gate; must end with `ALL CHECKS PASSED`. GitHub runs the same script (below). The Android unit tests need a JDK (17 or newer; Gradle uses `JAVA_HOME`) and the Android SDK, and their first run downloads Gradle and Robolectric's Android framework jars (about 650 MB into `~/.m2`, D-67).
- `tool/check_release_permissions`: builds the release APK and fails on a forbidden permission (`INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `READ_MEDIA_IMAGES`, `MANAGE_EXTERNAL_STORAGE`, `ACCESS_MEDIA_LOCATION`), a missing or wrong media permission (D-68), Google backup turned on (D-64) or on-device test code in the release build (`TestMedia`, `test_media`, `DebugBackgroundHooks`, `test_background`; D-77); must end with `RELEASE PERMISSIONS OK`. Slow; run at the end of every phase.
- `tool/make_test_video`: makes the 2 second test video that the on-device media tests put on the phone and writes it as `app/patrol_test/fixtures/test_video.dart` (needs `ffmpeg`, for example `brew install ffmpeg`; refuses to touch the file without it). `tool/make_test_video --check` writes nothing and fails if the committed file differs from what this ffmpeg makes (a different ffmpeg build can give other bytes, which is harmless).
- Run the catalogue on the phone: `cd widgetbook && ../tool/flutter run -d <device>` (list device ids with `tool/adb devices`). It installs as "TakeTray UI" (`app.taketray.widgetbook`) next to the app.
- `tool/patrol doctor`: shows the CLI version and the Flutter it uses (must say 3.47.7).
- `tool/patrol build android`: builds the debug app and the Patrol test APK without a phone. It is the compile check for `patrol_test/` and for the debug-only Kotlin; it installs nothing.
- `tool/patrol test -d <device id>`: runs every on-device test in `app/patrol_test` (`app_shell_test.dart`, the tab smoke test, `database_test.dart`, the real database on Android, and since phase 3 `media_access_test.dart` and `media_scan_test.dart`, and since phase 5 `tagging_test.dart`, which put their own test videos into `Movies/TakeTray Test/` and delete them again, D-77; flow: "On-device test (Patrol)" in `docs/flow.md`). The limited-access test in `media_access_test.dart` is skipped and must stay so until it verifies which item it picks (the define `--dart-define=LIMITED_ACCESS=true` is only for developing that). Add `-t patrol_test/<file>.dart` to run one. List device ids with `tool/adb devices`. `tool/patrol` adds `--no-uninstall` to `test` and `develop` (unless you pass `--uninstall` or `--no-uninstall` yourself), so the dev app (`app.taketray.dev`) stays installed on the phone afterwards; patrol_cli's default uninstalls it before and after every run.

## Automatic checks on GitHub (D-60)

`.github/workflows/check.yml` runs on every push and pull request (Ubuntu, 30-minute limit, read-only token, no secrets). It installs Flutter 3.47.7 into `~/development/flutter`, the folder the wrappers use, and runs `tool/check` with `CI=true`: the same script as on your Mac, so a green local run is expected to be green there (the CI golden images are a separate set made on Linux, see "Goldens" below).

- **Runs on CI:** everything in `tool/check` (generated-file and token freshness, format, analysis, style rules, all tests with only the `goldens/ci/` images (Linux-made, D-61), the Android unit tests on Temurin JDK 17 and the image's Android SDK, with Gradle and Robolectric files cached (D-67), the coverage gate). The drift tests download a prebuilt SQLite when they are built, so the runner needs the network; the app itself stays offline.
- **Does not run on CI:** the Patrol smoke test and anything that needs the phone (they stay local, on the S24, D-32), the macOS goldens (switched off by `CI`, D-61) and `tool/check_release_permissions` (it needs a full release build, which is slow; run it by hand at the end of each phase).
- **Same run on your Mac:** plain `tool/check`. It compares `goldens/macos/` only; `goldens/ci/` is for GitHub (D-61). `CI=true tool/check` on the Mac compares the Linux images and is expected to fail on pixels.
- **Text contrast is checked the same way on both:** `expectTtAccessible` measures every shown text from its real text and background colours (`ttTextContrastGuideline`, D-62), so the numbers do not depend on how the machine draws fonts. It fails when more than 2 % of a text's fully covered pixels are under the WCAG ratio, so a contrast failure on GitHub also fails on your Mac with plain `tool/check`. It does not prove the glyphs themselves look the same: the Mac additionally runs Flutter's pixel-guessing `textContrastGuideline`, which is not run on Linux because there it reports readable thin text as 1.2:1.
- **When it fails on golden images:** the run uploads the `failures/` folders as an artifact named `golden-failures` (on the run's summary page).
- **Changing the Flutter version:** edit `FLUTTER_VERSION` in the workflow and `EXPECTED_FLUTTER` in `tool/check` together. Packages are cached by `pubspec.lock`, Flutter by its version.
- **The first run** on a new Flutter version is slow because nothing is cached yet.

## Goldens

The component tests in `packages/taketray_ui/test/` compare screenshots with PNGs in `test/components/goldens/` and `test/theme/goldens/` (D-39). There are two sets, and the `CI` environment variable picks which one runs (D-61):

- **`goldens/macos/`** (real text and icons) runs on your Mac when `CI` is not set. It is tied to the macOS version and font rendering of the Mac that made it. After a macOS update every macOS golden can turn red with no code change: regenerate them and review the diff before committing.
- **`goldens/ci/`** (text drawn as blocks) runs only when `CI` is set, which GitHub does. It is made on GitHub's Linux runner, never on the Mac: the Mac's images differ from Linux's by a few pixels (anti-aliasing and image scaling), and both sets are compared with zero tolerance.

Update the macOS set after an intended visual change, from the package, with the pinned SDK: `cd packages/taketray_ui && ../../tool/flutter test --update-goldens test/components/<name>_test.dart`. Then run the same test without the flag, and look at the new PNGs before committing. This writes only `goldens/macos/`, because `CI` is not set.

Update the CI set (needed whenever a visual change alters a component):

1. Push the branch. On GitHub open Actions, "update goldens", "Run workflow" on that branch (or `gh workflow run update-goldens.yml --ref <branch>`). It makes the images on Linux and uploads them as the artifact `ci-goldens`; it commits nothing.
2. When the run is green, take its id from the URL (or `gh run list --workflow update-goldens.yml`) and run `tool/pull_ci_goldens <run-id>` in the repo. It needs `gh` installed and logged in (`gh auth login`), and refuses to run if `goldens/ci/` has uncommitted changes. It copies the images in and prints which files changed.
3. Look at the changed PNGs, commit them, push. The `check` workflow then passes on them.

A failing golden writes `*_masterImage.png`, `*_testImage.png`, `*_isolatedDiff.png` and `*_maskedDiff.png` to a `failures/` folder next to the test file (for example `packages/taketray_ui/test/components/failures/`). It is git-ignored; never commit it. On GitHub the `check` run uploads these folders as the artifact `golden-failures`.

## One-time: Patrol CLI

1. Install the pinned CLI version:

   ```
   tool/dart pub global activate patrol_cli 4.8.0
   ```

   Keep the `patrol` package in `app/pubspec.yaml` and the CLI compatible (Patrol compatibility table: `patrol_cli` 4.7.0+ works with `patrol` 4.9.0+). Currently `patrol_cli` 4.8.0 with `patrol` 4.10.0; change both together and update this pin.

2. Turn Patrol's usage analytics off for good. `tool/patrol` sets `PATROL_ANALYTICS_ENABLED=false`, but that only covers runs through the wrapper. When the variable is unset (for example running `patrol` directly or from an IDE), patrol_cli 4.8.0 reads `~/.config/patrol_cli/analytics.json`. Check it once:

   ```
   cat ~/.config/patrol_cli/analytics.json
   ```

   It must contain `"enabled":false`, for example `{"clientId":"<any uuid>","enabled":false}` (patrol_cli needs both keys; a file without `clientId` makes it fail). If the file does not exist, the first `tool/patrol` run creates it with `"enabled":false` (the first run of a bare `patrol` creates it with `true`). If it says `true`, change it to `false` and keep the `clientId`. This is a file in your home directory, outside the repo; nothing in the repo writes it.

## Physical device (Samsung Galaxy S24 Ultra, `RZCY80PHWCZ`)

1. Settings › About phone › Software information: tap **Build number** 7 times to enable Developer options.
2. Settings › Developer options: turn on **USB debugging**.
3. Settings › Security and privacy › **Auto Blocker**: turn it off (it blocks USB commands and installs from the computer).
4. Connect by USB, unlock the phone and accept the **Allow USB debugging?** prompt (tick "Always allow from this computer").
5. `tool/adb devices` must list `RZCY80PHWCZ   device` (not `unauthorized` or `offline`).

If an install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (an older build signed with a different key), uninstall the app that failed (for a debug or Patrol run that is `app.taketray.dev`, with `tool/adb -s RZCY80PHWCZ uninstall app.taketray.dev`) and run again; this removes that app's data.

Debug builds (`flutter run`, Patrol) are a separate app, **TakeTray Dev** (`app.taketray.dev`), and show up as a second icon next to the real **TakeTray** (`app.taketray`, release and profile builds); each has its own data (D-52). The Patrol run installs the debug app and a test APK (`app.taketray.dev.test`) and leaves both installed (`--no-uninstall`, added by `tool/patrol`). Patrol's orchestrator clears the app's data between tests (`clearPackageData`), so a Patrol run wipes the data of TakeTray Dev only; the real TakeTray is never touched. Because patrol_cli no longer uninstalls first, a build signed with a different key fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`; uninstall as described above.

**After a Patrol run, reinstall the normal debug build.** Patrol leaves its test-bundle APK installed as TakeTray Dev, and that build waits on the logo (its `main` is the Patrol test runner, not the app). Put the real debug app back and wipe what the tests left in TakeTray Dev (never the real TakeTray):

```
tool/flutter build apk --debug                     # in app/
tool/adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
tool/adb shell pm clear app.taketray.dev
```

Do these after **every** Patrol run, also when you re-run straight away (a second run on top of the first run's leftovers starts from the wrong state). Then open TakeTray Dev and allow video access again. Do this before the Phase 3 check below, and before any other hand check in TakeTray Dev.
- **The reinstall:** found by the owner, 2026-10-29.
- **The `pm clear`:** found by the owner, 2026-10-31. The tests make TakeTray Dev watch only `Movies/TakeTray Test`, so that no query ever names a folder with your videos, and that setting survives `install -r`. The tests now put the camera folder back at the end, but a run that fails halfway cannot. Without the clear, To tag and "Add earlier videos" find nothing in TakeTray Dev.

## Emulators

Emulators (API 30, 33, 34+) are deferred: low disk; the existing `Pixel_3a_API_32` AVD's system image is missing. Tests run on the S24 only for now (decision D-32). When disk allows, create AVDs with `sdkmanager`/`avdmanager` (Google APIs, arm64) and run the same `tool/patrol test` command with the emulator's id.

## Phase 1 check

Phase 1 is the design system: the shared look of the app and a catalogue that lists every component. The controller installs two APKs on the phone with `tool/adb install -r`: the TakeTray release app (`app/build/app/outputs/flutter-apk/app-release.apk`) and the "TakeTray UI" catalogue (`widgetbook/build/app/outputs/flutter-apk/app-release.apk`). Then check each of these on the phone:

1. Open TakeTray. It should open on Reels, with the floating pill of tabs at the bottom. In the status bar, the clock and battery icons must be readable: dark on the light theme, light on the dark theme (D-51).
2. Tap each tab. The screen should switch each time. Press back: you should return to Reels.
3. Switch the phone's dark mode on and off (Settings > Display). TakeTray should change between the light and dark look to match.
4. Open "TakeTray UI". Every component should be listed in the catalogue.
5. In the catalogue, switch between light, dark and video, and set the text size to 2.0. No layout should break: no text cut off or overlapping, and nothing sticking out of its box.
6. Look at the buttons, cards, the shooting card and the tag player controls. They should look like the prototype (`design/prototype/index.html`).

## Phase 2 check

Phase 2 is the data layer: the database that stores reels, clips and settings. It has no screens yet, so there is almost nothing to see. The controller has already run the on-device test (`app/patrol_test/database_test.dart`) on the phone: it opened the real database inside TakeTray Dev, saved a reel, closed and reopened the database, read the reel back and exported it. It then installed the TakeTray release app again. Check these on the phone:

1. The phone shows **TakeTray** and **TakeTray Dev** (the test copy that Patrol installs). The Phase 1 catalogue, **TakeTray UI**, may be there too.
2. TakeTray opens as before, on Reels, with the floating pill of tabs.
3. Nothing else is visible this phase: the data layer has no screens yet. If TakeTray opens and does not crash, the check passes.

## Phase 3 check

Phase 3 connects TakeTray to the phone's videos: Shooting mode, finding new clips, their thumbnails, noticing a deleted video, the Manual mode banner and Add earlier videos. The controller runs the on-device tests (`app/patrol_test/media_access_test.dart` and `media_scan_test.dart`, with the older two) on the phone. They put their own test videos into `Movies/TakeTray Test/` and delete them again, and they check the permission dialog, the folder query (a folder in another case still finds the video), the volume generation and the clip's picture. Then the controller installs the release TakeTray again. Check these yourself on the S24, in **TakeTray Dev** (the debug copy; your real TakeTray is not used for this check):

1. On the To tag tab, tap **Allow full access** and choose **Allow all**. The "Manual mode" banner goes away.
2. On the Reels tab, turn **Shooting mode** on.
3. Tap **Open camera** and film two short videos.
4. Come back to TakeTray. Both appear in To tag with thumbnails, oldest first.
5. Delete one in the Gallery app, then come back. It leaves To tag.
6. Tap **Add earlier videos** on the card (a history icon, the words, "Shot before Shooting mode was on" and a chevron), then **Choose dates…** ("Up to 10 years back"). The calendar opens on nothing, with "Tap the first day". Tap yesterday, then today: the line at the top says "{day} – {day}" and "2 days", and the days after today are struck through and do nothing. Try **Yesterday**, **Last week**, **This month** and **Last month**: each fills the calendar and nothing else happens. Swipe the days sideways: the month changes; tap the month name to jump to another year and month. Tap **Find videos**: the Choose dates… row shows your dates with "Checking…" and a spinner, then a box says "N videos found. Add them to To tag?" (for example "3 videos found"). Tap **Cancel**: nothing is added and the sheet stays open. Open **Choose dates…** again: **the calendar is already on the dates you chose**. Tap **Find videos** again and tap **Add**: the videos you filmed yesterday and today appear, and the two from step 3 aren't added twice. Choose dates with no videos (for example a week in the past): a box says "No new videos between Oct 20 and Oct 24." with one **OK** (on a phone set to English (India) the dates read "20 Oct"; a date from another year shows its year, such as "Dec 30, 2025"); choosing a single day (tap it twice, or once and **Find videos**) says "No new videos on Oct 20." Today is still a one-tap row, with the date under it, that adds straight away.
7. In Android Settings → Apps → TakeTray Dev → Permissions → Photos and videos, choose "Always ask" or "Don't allow". Come back: the banner says Manual mode, and the other clip is still there.
8. Time zone while closed. Close TakeTray Dev (swipe it away in the recent apps). In Android Settings, change the time zone (turn off the automatic time zone and pick another one). Film a clip with the camera app, then open TakeTray Dev again: the clip appears in To tag. Then put the time zone back. (TakeTray learns of the change from a receiver that runs while the app is closed, and needs it to date the clip.)
9. How the new parts look. With Shooting mode on and full access, the dark Shooting mode card ends with an **Add earlier videos** row (a history icon, the words, the line "Shot before Shooting mode was on", a chevron). Tapping it opens a sheet with the title, the line "From your camera folders. Clips you already tagged or skipped stay where they are." and two tall rows: **Today**, with its date under it and "N new" in a pill at the right (or "none", which stays easy to read, because off rows are not faded, and does nothing), and **Choose dates…**, with "Up to 10 years back" and a chevron. While the count loads, Today shows a grey bar and both rows are off. **Choose dates…** opens a full-screen calendar: a title bar with ✕, "Choose dates" and (once you tap a day) **Clear**; a summary line; the four quick ranges; a month with 48 dp days (the colours of the rest of the app, light and dark; your first and last day are filled circles, the days between are shaded, today has a ring, and the days after today are grey and struck through); and a **Find videos** button fixed to the bottom, which is off until a day is chosen. Close it with ✕ or Back: nothing is counted, and the focus returns to **Choose dates…**. Turn on TalkBack: the screen starts at the title "Choose dates"; each day is read as its full date and its state ("Thursday 8 October 2026, first day", "…, in the range", "…, today", "…, not available"), and the summary line is read when it changes. The box with **Cancel** and **Add** follows. Adding closes the sheet and shows "N clips added to To tag" with **Undo**; the card's row is then gone for this Shooting session. The To tag menu (the three dots) has the same item and sheet, with Shooting mode on or off. Compare the card, the sheet, the banner and the calendar with the prototype (`design/prototype/index.html`, screens 38 to 40): spacing, colours, light and dark mode, and large text (Settings → Display → Font size and style; at the largest size the title "Choose dates" wraps onto two lines (nothing is cut off) and the four quick ranges wrap onto more lines).
10. Limited access, (the Patrol limited-access test is skipped, so this is done by hand). Start fresh: in Settings → Apps → TakeTray Dev → Storage, tap **Clear data** (this only empties TakeTray Dev; it should also take its photo and video permission away; if the banner does not show Manual mode afterwards, revoke the permission under Settings → Apps → TakeTray Dev → Permissions), then open TakeTray Dev. On To tag, tap **Allow full access** and choose **Select photos and videos** (or "Allow limited access"), pick one video and confirm. The banner still says **Manual mode**. Turn Shooting mode on: the card says "On since … · Manual mode: add clips yourself". Back on To tag, tap **Allow full access** again: the system dialog shows again. Choose **Allow all**: the banner goes.

If a step does not behave like this, write down the step number and what you saw. Do not delete anything in `Movies/TakeTray Test/` by hand while the tests run; if a test says the folder holds a file it cannot delete, delete the folder in a file manager.

## Phase 4 check

Phase 4 is reels: the Reels tab, creating, editing and deleting a reel, a reel's page with its clips by shooting day, choosing several clips, the reel picker and the full-screen clip viewer, with Undo on every remove, move and delete. The controller runs the on-device test `app/patrol_test/reels_test.dart` on the phone (see below). It puts one test video into `Movies/TakeTray Test/` and deletes it again. It checks that a reel can be created, renamed and marked Ready to edit, that its tile and "Day 1" header show, that the viewer says "1 of 1" and the video really plays, and that Remove and Delete each work and can be undone. Then the controller reinstalls the normal debug build. Check these yourself on the S24, in **TakeTray Dev** (the debug copy; your real TakeTray is not used for this check):

1. **Create.** On the Reels tab, tap **New reel** (the button on an empty Home, or the floating button once a reel exists). Type a name, for example "London Food", and tap **Create reel**. A card appears with the status **Collecting**. Try an empty name ("Give this reel a name") and the same name again, in another case ("You already have a reel called london food"): the sheet stays open and explains.
2. **Edit.** Open the reel. Tap the three dots, then **Reel details**. Change the name, add a note in Shot ideas, pick **Ready to edit**, tap **Save**. The page shows the new name and the Shot ideas block, and the pill says **Ready to edit**. Tap the pill: the menu lists Collecting, Ready to edit and Published, each with a line saying what it means. Choose **Published**: "Marked as Published".
3. **Filter.** Make a second reel. On Reels, the chips (All, Collecting, Ready to edit, Published) show how many reels each holds. Tap **Published**: only the published reel shows. Tap a status no reel has: "No reels marked …" with **Show all reels**.
4. **Open.** Phase 4 has no way yet to put clips into a reel from the app: tagging is Phase 5, and Add videos is Phase 7. So steps 4–7 can only be checked by hand from Phase 5 on. `reels_test.dart` covers them on the phone now. Once clips are in a reel, open it:
   - clips are grouped by the day they were shot ("Day 1 · Sat 12 Oct"), with the time and length on each tile;
   - delete a clip you shot only for this check (never a real one) in the Gallery app and come back: its tile turns into a "Missing" tile with **Remove**;
   - Remove shows "Missing clip removed" with **Undo**.

   The owner chose to rely on the automated phone test for Phase 4 (2026-10-31).
5. **The viewer.** Tap a tile. The video plays with sound; tap to pause and play, drag the bar to seek, use the speaker to mute, swipe or use the arrows for the next clip. The top says "2 of 5 · {reel}" and the day and time where the clip was shot. If you have a clip shot abroad (the phone was in another time zone), it says the city: "… · London time", and it is on the day it was shot there. Turn the phone's airplane mode on to check it still plays: it is played from the gallery, never copied. Press back.
6. **Choose several, Move, Undo.** Long press a tile, tap two more. The bar says "3 selected". Tap **Move to another reel**, pick a reel (or **New reel** in the picker and type a name) and confirm. "Moved to {reel}" appears with **Undo**: tap **Undo** and the three clips are back in the first reel and gone from the second. Do the same with **Add to another reel** ("Added to …") and **Remove from this reel** (the videos stay in the Gallery).
7. **Delete, Undo.** Open the reel, three dots, **Delete reel**, **Delete reel** again. You are back on Reels, the card is gone and "{name} deleted" has **Undo**. Tap **Undo**: the card is back with its clips. Delete it again and wait for the message to go: it is gone for good, and the videos are still in the Gallery.
8. **Dark mode and large text.** Switch the phone to dark mode (Settings > Display). Look at Reels, a reel's page, the picker and the viewer in both looks, then set the font size to the largest (Settings > Display > Font size and style). Nothing should be cut off or overlap: long names wrap on the reel's page; the app bar clips them.

If a step does not behave like this, write down the step number and what you saw.

### Running `reels_test.dart` (the controller does this)

```
tool/patrol test -d RZCY80PHWCZ -t patrol_test/reels_test.dart
```

The phone must be unlocked, on the home screen, with USB debugging allowed. It installs TakeTray Dev and its test APK, clears TakeTray Dev's data (never the real TakeTray), and shows the app while it taps through the flows. It never asks for the photo permission, and only ever creates and deletes its own video in `Movies/TakeTray Test/` (D-77); its bridge calls ask for that video's id alone. If a run stops halfway, the video and the reel are deleted anyway; if it says the test folder holds a file TakeTray Dev does not own, delete the folder in a file manager.

**After the run, reinstall the normal debug build and clear TakeTray Dev's data.** The three commands are in "After a Patrol run" above. Until then TakeTray Dev waits on the logo, and it would watch only the test folder.

## Phase 5 check

Phase 5 is tagging: To tag in scenes, the tag player (one clip at a time, with the reel chips, Pick several, Same as previous, Skip and Undo), Tag scene, Skip all and the Skipped list. The controller runs the on-device test `app/patrol_test/tagging_test.dart` on the phone (see below). It puts 40 short test videos into `Movies/TakeTray Test/` (3 or 4 for the smaller flows) and deletes them again, makes two reels ("Patrol A" and "Patrol B") and deletes them, and checks five flows: **tag a day** (40 clips: 30 one-tap tags alternating the two reels, 5 with Pick several into both, 3 with Same as previous, 2 skipped; All done shows "40 clips sorted", "+23" twice and Skipped 2; To tag is empty; the reels hold exactly the clips that were tapped), **undo goes back** (the player returns to the clip and it is waiting again), **skip all and restore** (Cancel, Skip all with Undo, Skip all, Skipped, a tap restores one), **tag scene** (the scene goes into the reel and leaves To tag) and **undo after switching tabs** (the Tag scene message is still there on the Reels tab and its Undo brings the clips back). It also times the player: how long from a tap on a reel to the next clip playing. The numbers are in D-100. Then the controller reinstalls the normal debug build. Check these yourself on the S24, in **TakeTray Dev** (the debug copy; your real TakeTray is not used for this check). You need some clips of your own in To tag, for example 8 to 12 short videos you filmed today, and two reels (make them on Reels):

1. **To tag in scenes.** Open To tag. Under the title, "{n} clips · {s} scenes · {time}". Each scene has a header with its times ("1:05–1:20 PM"), "{n} clips · {m:ss}" and a **Tag scene** button. Clips shot more than 10 minutes apart are in separate scenes; a new day starts a new scene and has its own day header.
2. **Start tagging.** Tap **Start tagging** (the floating button), or tap a clip. The tag player opens on black: "1 of {N}" with "Scene 1 of {S} · {times}" at the top, the video playing (muted) and looping, the reel panel at the bottom. Tap the video: it pauses; tap again: it plays. Tap the speaker: it is heard. Swipe sideways, or use the ‹ › arrows: the previous and next clip.
3. **Tag with one tap.** Tap a reel chip. The chip shows a check for a moment, "Added to {reel}" appears with **Undo**, and the next clip is already playing (it should start straight away, under a second). The Patrol test only proves this for its tiny 160 x 90 clips, so this step, on your own 1080p or 4K clips, is the real proof of how it feels: note it if a clip is slow to start or shows a black frame. Tap **Undo**: the player goes **back to that clip**, and it is in To tag again.
4. **Pick several, Same as previous, Skip.** Tap **Pick several**: the panel says "Pick reels for this clip". Tap two reels, then "Add to 2 reels & next". The next clip is still picking (it stays on until you tap **Cancel**). Tap **Cancel**. Tap **Same as previous**: the clip goes into the same two reels (their names are under the button). Tap **Skip**: "Skipped" with **Undo**. Long press a chip: it turns on Pick several.
5. **Closing cancels the tap.** Tap a reel chip and at once tap the close (X) button: no "Added to" message appears and the clip is still in To tag. Do it again with the back gesture: a quick swipe back right after the tap cancels it too. (A very slow back swipe, held longer than the tick, can still tag; that is a known item in `docs/later.md`.)
6. **New reel.** In the panel tap **New reel**, type a name, **Create and add**: the clip goes into the new reel.
7. **All done.** Tag or skip the last clip: "All done!", "{n} clips sorted. Nice work.", a row for each reel with "+{n}" and a "Skipped" row. **See your reels** opens Reels (the clips are in them); **Back to To tag** goes back.
8. **Tag scene.** Back on To tag, tap **Tag scene** on one scene: "Tag {n} clips" opens with "Pick one or more reels."; pick a reel and tap **Tag {n} clips**. "{n} clips added to {reel}" appears with **Undo**, and the scene leaves To tag. Switch to Reels at once: the message is still there; **Undo** brings the clips back.
9. **Select, Skip all, Skipped.** Three dots on To tag: **Select clips** (long press a tile does the same), choose a few, **Skip**: "{n} clips skipped", **Undo**. Three dots, **Skip all**: "Skip all {n} clips?", **Cancel** changes nothing; **Skip all** moves everything, "Your videos stay in your gallery" is true (open the Gallery app). Tap **Skipped ({n})**: the clips by day, newest first. Tap a clip: "Restored to To tag", **Undo**. **Select**, choose two, **Restore**.
10. **Dark mode and large text.** Switch the phone to dark mode, then set the font size to the largest. Look at To tag, the player (the video keeps its room and the panel scrolls), All done and Skipped. Nothing should be cut off or overlap.

If a step does not behave like this, write down the step number and what you saw.

### Running `tagging_test.dart` (the controller does this)

```
tool/patrol test -d RZCY80PHWCZ -t patrol_test/tagging_test.dart
```

The phone must be unlocked, on the home screen, with USB debugging allowed, and it must stay connected for the whole run (about 3 minutes; a cable that drops mid-run makes the next run find no tests). The test sets TakeTray Dev to watch only `Movies/TakeTray Test/` **before** it asks for the photo permission (it taps **Allow full access** and "Allow all" as you do), turns Shooting mode on, and puts the test videos in through the debug channel (D-77). It creates two reels, taps through the flows, then deletes the reels and the videos and puts the watched folders back at the end of each test body. It never reads another folder. The limited-access test stays skipped.

**After the run, reinstall the normal debug build and clear TakeTray Dev's data.** The three commands are in "After a Patrol run" above. Do them after **every** run, also when you start another run straight away.

## Phase 6 check

Phase 6 is background detection and notifications: with Shooting mode on and TakeTray closed, Android tells the app when a new video appears and TakeTray posts one quiet notification, "{n} new clips to tag". It also has the evening reminder ("You shot {n} clips today. Tag them?"), "Still shooting?" after 14 days, and the help screen for phones that stop apps in the background. The controller runs the on-device test `app/patrol_test/background_test.dart` on the phone (see below); it puts 1 to 3 short test videos into `Movies/TakeTray Test/` per flow and deletes them again, and checks seven flows: **new clips notification appears and opens To tag** (two videos while TakeTray is in the background, "2 new clips to tag" in the shade, a tap opens To tag with the 2 clips and the notification goes; it prints how long the notification took), **turning off removes the notification**, **evening reminder counts today's clips** (the reminder is sent through a debug hook, so the receiver and its rules run), **still shooting turn off from the shade** (Turn off in the shade, then one more video that must stay out of To tag), **still shooting dialog** (Keep it on, and it is not asked again), **evening reminder fires at its set time** (the real alarm, two minutes ahead) and **one new-clips job stays pending through several insert bursts**. Then the controller reinstalls the normal debug build. Check these yourself on the S24, in **TakeTray Dev** (the debug copy; your real TakeTray is not used for this check). Allow notifications when TakeTray Dev asks (the first time you turn Shooting mode on), and give it video access (To tag › **Allow full access**):

1. **Film with TakeTray closed.** Open Reels and turn **Shooting mode** on. Close TakeTray (swipe it away in Recents). Open the camera and film 3 short clips, one after another. Pull down the shade after each one. Within about 5 to 30 seconds of the first clip, one notification appears: "1 new clip to tag" (with a small picture of the newest clip), and its number goes up as you film ("2 new clips to tag", then 3). It makes no sound or vibration, and there is only ever one. Tap it: TakeTray opens on To tag with the 3 clips, and the notification goes. Then lock the phone and film one more: on the lock screen the notification reads "TakeTray" and "1 new clip to tag", with no picture.
2. **Restart the phone.** With Shooting mode still on, restart the phone and unlock it. Do **not** open TakeTray. Film one more clip. The notification appears the same way (the job is re-armed at boot). Open TakeTray: the clip is in To tag.
3. **Evening reminder at the next minutes.** There is no Settings row for the evening time until Phase 10, so the debug build can set it: build and install the debug app with the number of minutes ahead, then open it once:

   ```
   cd app
   ../tool/flutter build apk --debug --dart-define=TAKETRAY_EVENING_IN_MINUTES=2
   ../tool/adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

   Every time TakeTray Dev starts, this build sets the evening reminder to 2 minutes ahead and switches it on. Make sure at least one clip you filmed **today** is waiting in To tag (film one with Shooting mode on and open the app so it is scanned). Open TakeTray Dev, then close it (swipe away) and wait. About 2 minutes later (Android may be a minute or two late, never early), the notification "You shot {n} clips today. Tag them?" appears, with the number of today's clips waiting; tap it and To tag opens. It posts once a local day: to see it again the same day, clear TakeTray Dev's data. On a day with no clip shot today it stays quiet even if older clips wait. **Afterwards** put the normal build back (no `--dart-define`) with the commands in "After a Patrol run" above, which also clears the data and with it the 2-minute evening time.
4. **The help screen.** Settings › **Notifications not arriving?** (under Help). The Samsung card has the steps ("Open Settings › Battery › Background usage limits." and the next two) and the button **Open battery settings**, which opens the phone's battery settings; **Open app info** opens TakeTray Dev's app info. Under Permissions, **Notifications** says "Allowed" with a check; turn notifications off for TakeTray Dev in the phone's settings and come back: it says "Not allowed" with an **Allow** button.

If a step does not behave like this, write down the step number and what you saw.

### Running `background_test.dart` (the controller does this)

```
tool/patrol test -d RZCY80PHWCZ -t patrol_test/background_test.dart
```

The phone must be unlocked, on the home screen, with USB debugging allowed, and stay connected for the whole run (about 10 minutes: the evening alarm flow waits up to 7 minutes for the real alarm). The test sets TakeTray Dev to watch only `Movies/TakeTray Test/` **before** it asks for the video permission, turns Shooting mode on (answering the notification permission dialog with Allow), and puts the test videos in through the debug channel (D-77). Notifications are found and tapped by their own text only, and the two shade buttons ("Turn off") only when they sit below TakeTray's text and next to TakeTray's own "Keep on"; nothing else in the shade is listed or read. It turns Shooting mode off, deletes the videos and puts the watched folders back at the end of each test body. The limited-access test stays skipped.

**After the run, reinstall the normal debug build and clear TakeTray Dev's data.** The three commands are in "After a Patrol run" above. Do them after **every** run, also when you start another run straight away.
