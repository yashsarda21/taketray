# Hyperframes Composition Brief: TakeTray

## Objective
Create a short launch-style brag video for TakeTray, to replace the "REPLAY COMING SOON" placeholder on the owner's portfolio.

## Output
- Composition directory: `marketing/brag/composition/`
- Rendered video: `marketing/brag/brag.mp4` (poster baked as frame 0 from `brag.jpg`)
- Format: landscape, 2400x768 (3.125:1; the portfolio `MediaSlot` is 230 px tall and `object-cover`, ~720 px wide on desktop, ~358 px on phones, so the readable core sits in the centre 1200 px)
- Duration: 23.5 s, 30 fps

## Source Material
- Project root: `/Users/sardap/Documents/github/reel-helper` (read-only for `design/`, `packages/`)
- Primary files read: `README.md`, `docs/decisions.md`, `docs/flow.md`, `design/README.md`, `design/prototype/` (index.html, assets/states.js, welcome, tokens), `design/tokens/taketray.tokens.json`, `docs/assets/taketray-logo.svg`, `marketing/threads/day-02/`
- Product name: TakeTray
- Tagline / strongest claim: "One tray for every take." (chosen welcome B · Tray copy). "Every clip you shoot, sorted into the right reel." (README). The tagline is not final, so "Shoot now. Sort later." is not used.
- Key UI moments: Tray welcome; Home with Shooting mode on and "23 clips to tag"; To tag grouped into scenes; the dark tag player with the "Added to London Food · Undo" snackbar.
- Copy that must appear verbatim: "One tray for every take." / "Turn on Shooting mode." / "New videos land in To tag." / "Shot less than 10 minutes apart? Same scene." / "One tap tags a clip." / "Wrong one? Undo." / "Every clip you shoot, sorted into the right reel."
- Screens are real prototype screens captured with Playwright at 1080x2400 (dark theme, driven through the real interaction). The status chip reads "Collecting" (the shipped name, D-08) rather than the prototype's older "Recording".

## Creative Direction
- Tone preset: polished, leaning app-store
- Creative direction: quiet premium product film for a software engineer's portfolio
- Interpretation: five scenes, long holds, soft blur-swaps, a single marigold accent, no jokes.
- Hook: phone rises with the Tray welcome while "One tray for every take." lands word by word.
- Outro: TakeTray mark, the README line, the stack, "Android app · Personal project · In development".
- Avoid: generic SaaS language; invented users, downloads, ratings, store availability or AI claims; abstract filler.

## Visual Identity
- Background #121316, text #E0E3E6 / #C1C7CF, accent marigold #FFB952, graphite-blue #B8C8DD
- Display and body font: Plus Jakarta Sans (variable TTF from `packages/taketray_ui/fonts`, bundled in `assets/fonts`)

## Storyboard
See `brag-plan.md`. 1 Hook 0-4.39; 2 Shooting mode 4.39-8.74; 3 Scenes 8.74-13.11; 4 One tap 13.11-18.56; 5 Outro 18.56-23.5.

## Audio
- Audio role: warm bed with sparse professional accents
- Music: `happy-beats-business-moves-vol-12-by-ende-dot-app.mp3` (CC BY 4.0, Sascha Ende, ende.app; credited in the outro)
- Music treatment: from 0:00, volume 0.30, fade in 0.4 s, fade out 1.8 s; final mix normalised to about -16 LUFS (measured -15.1 LUFS, true peak about -1.4 dB).
- Music cue guidance: preset `assets/music/cues/...vol-12...music-cues.json`; beat-locked 8.74 s, 13.11 s, 18.56 s; taps on the grid at 14.73 s and 16.38 s.
- Audio-reactive treatment: subtle; bass energy (media-use `extract-audio-data.py`, first 24 s) breathes the glow behind the phone and the side tiles.
- SFX: drop_001 (0.5 s), impactSoft_medium_001 (13.08 s), click_003 x2 (taps), bong_001 (18.75 s). Files copied into `composition/assets/sfx/`.
