# TakeTray: Developer setup

Everything goes through the wrappers in `tool/`. The `flutter` on `PATH` is 2.8.1 and must never be used.

| Wrapper | Runs |
|---|---|
| `tool/flutter`, `tool/dart` | the pinned SDK in `~/development/flutter` (Flutter 3.47.7) |
| `tool/adb` | `~/Library/Android/sdk/platform-tools/adb` |
| `tool/patrol` | `patrol_cli` with the pinned Flutter first on `PATH` |

## Commands

- `tool/check`: format, analysis, style rules and all tests; must end with `ALL CHECKS PASSED`.
- `tool/check_release_permissions`: builds the release APK and fails if it contains `android.permission.INTERNET`; must end with `RELEASE PERMISSIONS OK`. Slow; run at the end of every phase.
- Run the catalogue on the phone: `cd widgetbook && ../tool/flutter run -d <device>` (list device ids with `tool/adb devices`). It installs as "TakeTray UI" (`app.taketray.widgetbook`) next to the app.
- `tool/patrol doctor`: shows the CLI version and the Flutter it uses (must say 3.47.7).
- `tool/patrol test -t patrol_test/app_shell_test.dart -d <device id>`: the on-device smoke test (flow: "On-device test (Patrol)" in `docs/flow.md`). List device ids with `tool/adb devices`. `tool/patrol` adds `--no-uninstall` to `test` and `develop` (unless you pass `--uninstall` or `--no-uninstall` yourself), so `app.taketray` stays installed on the phone afterwards; patrol_cli's default uninstalls it before and after every run.

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

If an install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (an older build signed with a different key), uninstall with `tool/adb -s RZCY80PHWCZ uninstall app.taketray` and run again; this removes the app's data.

The Patrol run installs the debug app and a test APK (`app.taketray.test`) and leaves both installed (`--no-uninstall`, added by `tool/patrol`). Patrol's orchestrator clears the app's data between tests (`clearPackageData`), so a Patrol run on the phone wipes TakeTray's data there even though the app stays. Because patrol_cli no longer uninstalls first, a build signed with a different key fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`; uninstall as described above.

## Emulators

Emulators (API 30, 33, 34+) are deferred: low disk; the existing `Pixel_3a_API_32` AVD's system image is missing. Tests run on the S24 only for now (decision D-32). When disk allows, create AVDs with `sdkmanager`/`avdmanager` (Google APIs, arm64) and run the same `tool/patrol test` command with the emulator's id.
