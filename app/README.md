# TakeTray (Flutter app)

The Android app for TakeTray, built with Flutter so an iPhone version can share the same code later. The design lives in [`../design/`](../design/).

## What's in this first build

Sample data only (the same London trip as the design prototype; no real gallery access yet):

- **Reels (Home)**: Shooting mode card (REC dot, Open camera, References · 4, "23 clips to tag" strip), status filters, reel cards with status, VN and reference badges.
- **To tag**: scenes with time range and **Tag scene** (reel picker), clip tiles, **Start tagging**.
- **Tag player**: always dark. Tap a reel to tag the clip and move to the next one; **Pick several** (or long-press a reel); **Same as previous**; **Skip**; **Undo**; **New reel** on the spot; swipe or arrows to move between clips; scene progress; **All done!** summary.
- **Reel detail** (first pass) and **Settings** with the **brand colour** options and Light / Dark / System.

## Run it on your phone

1. On the phone: **Settings › About phone**, tap **Build number** 7 times. Then **Settings › System › Developer options** (the path can differ by brand) and turn on **USB debugging**.
2. Connect the phone by USB and accept the "Allow USB debugging?" prompt on the phone.
3. On the Mac:

```sh
export PATH="$HOME/development/flutter/bin:$PATH"   # Flutter 3.47 (your old ~/flutter is untouched)
cd reel-helper/app
flutter devices        # your phone should be listed
flutter run            # builds, installs and opens TakeTray
```

While `flutter run` is open, press `r` to reload after code changes, or `q` to quit. To install without the Mac afterwards: `flutter build apk --release`, then copy `build/app/outputs/flutter-apk/app-release.apk` to the phone.

## Code

| Path | What it is |
|---|---|
| `lib/theme/tokens.g.dart` | **Generated** from the design tokens (`python3 ../design/tools/build_tokens.py`): Material 3 colour schemes for every brand option, type, radii, spacing, motion. Don't edit by hand. |
| `lib/theme/app_theme.dart` | Builds the Material 3 `ThemeData` from the tokens. |
| `lib/state/app_state.dart` | App state: reels, clips, To tag, tagging, skipping, Undo, settings. |
| `lib/screens/` | Home, To tag, Tag player, Reel detail, Settings. |
| `lib/widgets/common.dart` | Clip tile, reel card, status pill, REC dot, formatting. |
| `assets/sample/` | Sample data and thumbnails exported from the design prototype. |
| `assets/fonts/` | Plus Jakarta Sans (variable font, OFL licence). |
| `test/` | Widget test of the tagging flow, and screen previews (`flutter test --update-goldens test/screen_previews_test.dart` writes PNGs to `test/previews/`). |

Android: package `app.taketray`, minimum Android 11 (API 30), adaptive TakeTray icon from `../design/handoff/icons/tray/`.

## Next

Real gallery access (new videos while Shooting mode is on), reel detail actions, sending clips to CapCut, Edits and VN, references, notifications and onboarding.
