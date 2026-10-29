# TakeTray: Developer setup

Everything goes through the wrappers in `tool/`. The `flutter` on `PATH` is 2.8.1 and must never be used.

| Wrapper | Runs |
|---|---|
| `tool/flutter`, `tool/dart` | the pinned SDK in `~/development/flutter` (Flutter 3.47.7) |
| `tool/adb` | `~/Library/Android/sdk/platform-tools/adb` |
| `tool/patrol` | `patrol_cli` with the pinned Flutter first on `PATH` |

## Commands

- `tool/check`: generated-file and token freshness, format, analysis, style rules, all tests (including the Android unit tests, `tool/test_android`) and the coverage gate; must end with `ALL CHECKS PASSED`. GitHub runs the same script (below). The Android unit tests need a JDK (17 or newer; Gradle uses `JAVA_HOME`) and the Android SDK, and their first run downloads Gradle and Robolectric's Android framework jars (about 650 MB into `~/.m2`, D-67).
- `tool/check_release_permissions`: builds the release APK and fails on a forbidden permission (`INTERNET`, `READ_MEDIA_IMAGES`, `MANAGE_EXTERNAL_STORAGE`, `ACCESS_MEDIA_LOCATION`), a missing or wrong media permission (D-68), Google backup turned on (D-64) or on-device test code in the release build (`TestMedia`, `test_media`; D-77); must end with `RELEASE PERMISSIONS OK`. Slow; run at the end of every phase.
- `tool/make_test_video`: makes the 2 second test video that the on-device media tests put on the phone and writes it as `app/patrol_test/fixtures/test_video.dart` (needs `ffmpeg`, for example `brew install ffmpeg`; refuses to touch the file without it). `tool/make_test_video --check` writes nothing and fails if the committed file differs from what this ffmpeg makes (a different ffmpeg build can give other bytes, which is harmless).
- Run the catalogue on the phone: `cd widgetbook && ../tool/flutter run -d <device>` (list device ids with `tool/adb devices`). It installs as "TakeTray UI" (`app.taketray.widgetbook`) next to the app.
- `tool/patrol doctor`: shows the CLI version and the Flutter it uses (must say 3.47.7).
- `tool/patrol build android`: builds the debug app and the Patrol test APK without a phone. It is the compile check for `patrol_test/` and for the debug-only Kotlin; it installs nothing.
- `tool/patrol test -d <device id>`: runs every on-device test in `app/patrol_test` (`app_shell_test.dart`, the tab smoke test, `database_test.dart`, the real database on Android, and since phase 3 `media_access_test.dart` and `media_scan_test.dart`, which put their own test videos into `Movies/TakeTray Test/` and delete them again, D-77; flow: "On-device test (Patrol)" in `docs/flow.md`). The limited-access test in `media_access_test.dart` is skipped and must stay so until it verifies which item it picks (the define `--dart-define=LIMITED_ACCESS=true` is only for developing that). Add `-t patrol_test/<file>.dart` to run one. List device ids with `tool/adb devices`. `tool/patrol` adds `--no-uninstall` to `test` and `develop` (unless you pass `--uninstall` or `--no-uninstall` yourself), so the dev app (`app.taketray.dev`) stays installed on the phone afterwards; patrol_cli's default uninstalls it before and after every run.

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

**After a Patrol run, reinstall the normal debug build.** Patrol leaves its test-bundle APK installed as TakeTray Dev, and that build waits on the logo (its `main` is the Patrol test runner, not the app). Put the real debug app back: `tool/flutter build apk --debug` (in `app/`), then `tool/adb install -r app/build/app/outputs/flutter-apk/app-debug.apk`. Do this before the Phase 3 check below, and before any other hand check in TakeTray Dev (found by the owner, 2026-10-29).

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
6. Tap **Add earlier videos** on the card, then **Choose dates…**. In the calendar tap yesterday, then today (the days after today are greyed out and cannot be picked), then **Find videos**. A box says "N videos found. Add them to To tag?" (for example "3 videos found"). Tap **Cancel**: nothing is added and the sheet stays open. Choose the same dates again and tap **Add**: the videos you filmed yesterday and today appear, and the two from step 3 aren't added twice. Choose dates with no videos (for example a week in the past): a box says "No new videos between Oct 20 and Oct 24." with one **OK**; choosing a single day says "No new videos on Oct 20." Today is still a one-tap row that adds straight away.
7. In Android Settings → Apps → TakeTray Dev → Permissions → Photos and videos, choose "Always ask" or "Don't allow". Come back: the banner says Manual mode, and the other clip is still there.
8. Time zone while closed. Close TakeTray Dev (swipe it away in the recent apps). In Android Settings, change the time zone (turn off the automatic time zone and pick another one). Film a clip with the camera app, then open TakeTray Dev again: the clip appears in To tag. Then put the time zone back. (TakeTray learns of the change from a receiver that runs while the app is closed, and needs it to date the clip.)
9. How the new parts look. With Shooting mode on and full access, the dark Shooting mode card ends with an **Add earlier videos** row (a history icon, the words, a chevron). Tapping it opens a sheet with the title, the line "From your camera folders. Clips you already tagged or skipped stay where they are." and two rows: **Today**, with "none" or "N new" at the right ("none" looks dimmed and does nothing), and **Choose dates…**, with a chevron. **Choose dates…** opens a full-screen calendar (the same colours as the rest of the app, light and dark; the days between your two taps are shaded; the days after today are grey) whose button says **Find videos**, and then the box with **Cancel** and **Add**. Adding closes the sheet and shows "N clips added to To tag" with **Undo**; the card's row is then gone for this Shooting session. The To tag menu (the three dots) has the same item and sheet, with Shooting mode on or off. Compare the card, the sheet, the banner and the tiles with the prototype (`design/prototype/index.html`): spacing, colours, light and dark mode, and large text (Settings → Display → Font size and style).
10. Limited access, (the Patrol limited-access test is skipped, so this is done by hand). Start fresh: in Settings → Apps → TakeTray Dev → Storage, tap **Clear data** (this only empties TakeTray Dev; it should also take its photo and video permission away; if the banner does not show Manual mode afterwards, revoke the permission under Settings → Apps → TakeTray Dev → Permissions), then open TakeTray Dev. On To tag, tap **Allow full access** and choose **Select photos and videos** (or "Allow limited access"), pick one video and confirm. The banner still says **Manual mode**. Turn Shooting mode on: the card says "On since … · Manual mode: add clips yourself". Back on To tag, tap **Allow full access** again: the system dialog shows again. Choose **Allow all**: the banner goes.

If a step does not behave like this, write down the step number and what you saw. Do not delete anything in `Movies/TakeTray Test/` by hand while the tests run; if a test says the folder holds a file it cannot delete, delete the folder in a file manager.
