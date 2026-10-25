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
- `tool/patrol doctor`: shows the CLI version and the Flutter it uses (must say 3.47.7).
- `tool/patrol test -t patrol_test/app_shell_test.dart -d <device id>`: the on-device smoke test (flow: "On-device test (Patrol)" in `docs/flow.md`). List device ids with `tool/adb devices`.

## One-time: Patrol CLI

```
tool/dart pub global activate patrol_cli
```

Keep the `patrol` package in `app/pubspec.yaml` and the CLI compatible (Patrol compatibility table: `patrol_cli` 4.7.0+ works with `patrol` 4.9.0+). Currently `patrol_cli` 4.8.0 with `patrol` 4.10.0. `tool/patrol` sets `PATROL_ANALYTICS_ENABLED=false`, because the project is offline by design.

## Physical device (Samsung Galaxy S24 Ultra, `RZCY80PHWCZ`)

1. Settings › About phone › Software information: tap **Build number** 7 times to enable Developer options.
2. Settings › Developer options: turn on **USB debugging**.
3. Settings › Security and privacy › **Auto Blocker**: turn it off (it blocks USB commands and installs from the computer).
4. Connect by USB, unlock the phone and accept the **Allow USB debugging?** prompt (tick "Always allow from this computer").
5. `tool/adb devices` must list `RZCY80PHWCZ   device` (not `unauthorized` or `offline`).

If an install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (an older build signed with a different key), uninstall with `tool/adb -s RZCY80PHWCZ uninstall app.taketray` and run again; this removes the app's data.

The Patrol run installs the debug app and a test APK (`app.taketray.test`); Patrol clears the app's data between tests.

## Emulators

Emulators (API 30, 33, 34+) are deferred: low disk; the existing `Pixel_3a_API_32` AVD's system image is missing. Tests run on the S24 only for now (decision D-32). When disk allows, create AVDs with `sdkmanager`/`avdmanager` (Google APIs, arm64) and run the same `tool/patrol test` command with the emulator's id.
