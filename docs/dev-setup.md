# TakeTray: Developer setup

Everything goes through the wrappers in `tool/`. The `flutter` on `PATH` is 2.8.1 and must never be used.

| Wrapper | Runs |
|---|---|
| `tool/flutter`, `tool/dart` | the pinned SDK in `~/development/flutter` (Flutter 3.47.7) |
| `tool/adb` | `~/Library/Android/sdk/platform-tools/adb` |
| `tool/patrol` | `patrol_cli` with the pinned Flutter first on `PATH` |

## Commands

- `tool/check`: generated-file and token freshness, format, analysis, style rules, all tests and the coverage gate; must end with `ALL CHECKS PASSED`. GitHub runs the same script (below).
- `tool/check_release_permissions`: builds the release APK and fails if it contains `android.permission.INTERNET`; must end with `RELEASE PERMISSIONS OK`. Slow; run at the end of every phase.
- Run the catalogue on the phone: `cd widgetbook && ../tool/flutter run -d <device>` (list device ids with `tool/adb devices`). It installs as "TakeTray UI" (`app.taketray.widgetbook`) next to the app.
- `tool/patrol doctor`: shows the CLI version and the Flutter it uses (must say 3.47.7).
- `tool/patrol test -d <device id>`: runs every on-device test in `app/patrol_test` (`app_shell_test.dart`, the tab smoke test, and `database_test.dart`, the real database on Android; flow: "On-device test (Patrol)" in `docs/flow.md`). Add `-t patrol_test/<file>.dart` to run one. List device ids with `tool/adb devices`. `tool/patrol` adds `--no-uninstall` to `test` and `develop` (unless you pass `--uninstall` or `--no-uninstall` yourself), so the dev app (`app.taketray.dev`) stays installed on the phone afterwards; patrol_cli's default uninstalls it before and after every run.

## Automatic checks on GitHub (D-60)

`.github/workflows/check.yml` runs on every push and pull request (Ubuntu, 30-minute limit, read-only token, no secrets). It installs Flutter 3.47.7 into `~/development/flutter`, the folder the wrappers use, and runs `tool/check` with `CI=true`: the same script as on your Mac, so a green local run is expected to be green there (the CI golden images are a separate set made on Linux, see "Goldens" below).

- **Runs on CI:** everything in `tool/check` (generated-file and token freshness, format, analysis, style rules, all tests with only the `goldens/ci/` images (Linux-made, D-61), the coverage gate). The drift tests download a prebuilt SQLite when they are built, so the runner needs the network; the app itself stays offline.
- **Does not run on CI:** the Patrol smoke test and anything that needs the phone (they stay local, on the S24, D-32), the macOS goldens (switched off by `CI`, D-61) and `tool/check_release_permissions` (it needs the Android SDK; run it by hand at the end of each phase).
- **Same run on your Mac:** plain `tool/check`. It compares `goldens/macos/` only; `goldens/ci/` is for GitHub (D-61). `CI=true tool/check` on the Mac compares the Linux images and is expected to fail on pixels.
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
