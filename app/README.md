# TakeTray (Flutter app)

The Android app for TakeTray. Build, run and test it only through the wrappers in [`../tool/`](../tool/), which use the pinned Flutter 3.47.7; the `flutter` on `PATH` is an old version and must not be used.

- Setup, device connection and commands: [`../docs/dev-setup.md`](../docs/dev-setup.md)
- How the code runs: [`../docs/flow.md`](../docs/flow.md)
- Why it is built this way: [`../docs/decisions.md`](../docs/decisions.md)

Quick reference (from the repo root):

```sh
tool/check                     # format, analysis, style rules, all tests
(cd app && ../tool/flutter run -d <device>)   # run on a phone (ids: tool/adb devices)
tool/patrol test -t patrol_test/app_shell_test.dart -d <device>   # on-device tests
```

The earlier prototype with sample data is kept for reference in [`../reference/`](../reference/) (decision D-33).
