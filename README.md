<p align="center">
  <img src="docs/assets/taketray-logo.svg" width="128" height="128" alt="TakeTray logo: clip cards dropping into a marigold tray">
</p>

<h1 align="center">TakeTray</h1>

<p align="center"><b>Shoot now. Sort later.</b><br>
Every clip you shoot, sorted into the right reel.</p>

---

## What it is

TakeTray is an Android app for Instagram reel creators who film a lot and lose the good clips among thousands of videos.

1. **Turn on Shooting mode** and film with your phone's normal camera.
2. **New videos land in To tag.** In spare moments, watch each one and tap the reel it's for (*London Food*, *Day 1 Vlog*…), or skip it.
3. **At edit time**, send a reel's clips straight to **CapCut** or **Instagram Edits**, or to **VN** through a temporary folder that is cleaned up afterwards.
4. **Save reference reels** by sharing an Instagram link into TakeTray.

Your original videos are never changed, moved or deleted. TakeTray only remembers which clip belongs to which reel.

**Fully offline and private:** no account, no analytics, no ads, and the release app has no internet permission. Everything stays on your phone.

Built with Flutter, for Android 11 and newer. v1 is free.

## Progress

The app is built in phases. Each phase is planned, built in small tested steps, reviewed, checked on a real phone (Samsung Galaxy S24 Ultra), and only then merged.

| Phase | What it covers | Status |
|---|---|---|
| 0 | Foundation | ✅ Done |
| 1 | Design system | ✅ Done |
| 2 | Data layer | ✅ Done |
| 3 | Finding your videos (Android media bridge) | Next |
| 4 | Reels screens | Planned |
| 5 | Tagging (To tag and the tag player) | Planned |
| 6 | Background detection and notifications | Planned |
| 7 | Adding friends' videos | Planned |
| 8 | Sending clips to editors (CapCut, Edits, VN) | Planned |
| 9 | Reference reels | Planned |
| 10 | Onboarding, settings, error log | Planned |
| 11 | Release prep for the Play Store | Planned |

### Phase 0: Foundation
- Project set-up as a workspace, with a pinned Flutter version (3.47.7).
- One command, `tool/check`, runs formatting, strict analysis, style rules and every test.
- The app starts on a simple shell with three tabs (Reels, To tag, Settings), with app-wide strings, navigation and state handling in place.
- A local, private error log (no video names or paths in it).
- On-device tests with Patrol on the S24.

### Phase 1: Design system
- `packages/taketray_ui`: the TakeTray look as reusable building blocks, including colours and fonts from the design tokens, light and dark themes, and about 30 components (buttons, reel cards, clip tiles, the tag panel, player controls, sheets, dialogs and more).
- Every component has screenshot tests in light and dark, at normal and extra-large text, plus accessibility checks (tap-target size, labels, contrast).
- **TakeTray UI**: a catalogue app (Widgetbook) that shows every component and state.
- The app shell uses the new look: a floating tab pill, and status-bar icons that stay readable.

### Phase 2: Data layer
- **The database**: a SQLite file on the phone (via Drift) holding reels, clips, the To tag list, reference links, VN folders, settings and a time-zone record. It has upgrade (migration) safety checks for future versions.
- **Rules**:
  - Reel names are up to 40 characters, and each emoji counts as one.
  - Every form of the same Instagram link is saved once.
  - A second VN folder with the same name becomes "Goa (2)".
- **Repositories**: safe ways to create reels, tag clips (with Undo), skip and restore, add references and change settings. Lists update themselves. A clip that's in no reel and not in To tag is cleaned up automatically.
- **Backup**: export everything to one JSON file and import it back. A broken file is refused before anything is touched, so data is never lost.
- **Quality gates**:
  - at least 80 % test coverage for the data and rules code (currently about 97 % and 90 %)
  - a check that generated code is up to date
  - automatic checks on GitHub for every push
- **TakeTray Dev**: debug builds and on-device tests install as a separate app, so tests never touch your real data.
- **Learning guide**: [docs/learn/phase-2-data-layer.md](docs/learn/phase-2-data-layer.md) explains the whole phase in plain English, with the real code.

## Running the checks

Use the pinned Flutter through the wrappers in `tool/` (never a global `flutter`):

```bash
tool/check                      # format, analyze, style rules, generated files, all tests, coverage
tool/check_release_permissions  # builds the release APK and confirms it has no INTERNET permission
tool/patrol test -d <device>    # on-device tests (install as "TakeTray Dev")
```

Set-up details: [docs/dev-setup.md](docs/dev-setup.md).

## Project map

| Path | What's there |
|---|---|
| `app/` | The TakeTray Android app |
| `packages/taketray_ui/` | The design system (theme and components) |
| `widgetbook/` | The "TakeTray UI" component catalogue |
| `tool/` | Flutter wrappers and check scripts |
| `design/` | Design tokens, the clickable prototype and icons |
| `docs/decisions.md` | Every meaningful decision and why |
| `docs/flow.md` | How each part of the app runs, step by step |
| `docs/later.md` | Work parked for later phases |
| `docs/learn/` | Learning guides, one per phase |
| `docs/superpowers/` | The build design and the phase plans |
