# Brag Plan: TakeTray

## What is this app?
An offline-first Android app (Flutter) for short-form creators that turns a messy camera roll of raw clips into planned reels: clips are grouped into scenes by recording time, and one tap in a full-screen player tags a clip to a reel, with Undo.

## The angle
A quiet, app-store-clean product film that shows the real working flow instead of describing it: one tray, Shooting mode, scenes, one tap. The screens are the actual TakeTray design prototype (`design/prototype`, 40 screens, graphite and marigold, Plus Jakarta Sans), rendered in the dark theme and driven through the real tagging interaction. No claims beyond what the README, `docs/` and the portfolio already say.

## Hook (first 2-3 seconds)
The Tray welcome screen rising in on the right (three takes standing in a marigold tray, "23 takes · 3 reels") while "One tray for every take." lands word by word on the left. That line is the app's own chosen welcome copy (welcome B · Tray), so it is true and not the still-open tagline.

## Key moments (the middle)
- Home: "Shooting mode on", the marigold "23 clips to tag" strip.
- To tag: clips grouped by scene ("9:20–9:31 am · 4 clips · 1:00"), a marigold outline around the first scene.
- Tag player: tap "London Food", snackbar "Added to London Food · Undo", next clip; tap "London Cinematic", same.

## Outro / punchline
TakeTray mark and wordmark, "Every clip you shoot, sorted into the right reel." (the README's line), then the stack and an honest status line: Flutter, Riverpod, Drift (SQLite), offline-first, Android personal project in development. Music credit (CC BY 4.0) in small type.

## User flow worth showing
Entry (Shooting mode, new clips land in To tag) → key action (open To tag, scenes, tap a reel in the player) → result (clip tagged, advances, Undo available, "21 clips to tag" left).

## Tone
- Preset: polished, leaning app-store
- Creative direction: quiet premium product film for a software engineer's portfolio
- Interpretation: 5 scenes with holds, soft blur-swaps and slides (0.3-0.6 s), one accent colour (marigold), a few quiet SFX only where something is tapped or lands.

## Format: landscape — 2400x768 (3.125:1)
Not 16:9 on purpose. The portfolio replay slot (`MediaSlot`) is `h-57.5` (230 px) tall and `object-cover`, 720 px wide on the 1440 artboard (3.13:1), 1.5:1 to 1.7:1 on phones and tablets. So the frame is a 3.125:1 banner whose readable core (text and phone) sits in the centre 1200 px (1.56:1) and survives the narrowest crop; the sides carry only decorative clip tiles. Bottom ~140 px is kept free of key text because the native video controls overlay it.

## Duration: 23.5 s

## Visual identity (from the project)
- Background: #121316 (dark `background` role)
- Accent: #FFB952 (marigold, dark `tertiary`; `tertiaryContainer` #FAA800)
- Text: #E0E3E6, secondary #C1C7CF; graphite-blue #B8C8DD (dark `primary`)
- Display font: Plus Jakarta Sans 800 (`packages/taketray_ui/fonts/PlusJakartaSans-Variable.ttf`)
- Body font: Plus Jakarta Sans 500-600
- Strongest visual element: the Tray welcome artwork and the dark tag player

## Share copy (draft)
Introducing TakeTray: an Android app that turns a messy gallery of raw clips into planned short-form reels. Built with Flutter, Riverpod and Drift (SQLite), offline-first.

## Audio direction
- Role: warm bed with sparse professional accents
- Music: `happy-beats-business-moves-vol-12-by-ende-dot-app.mp3` (steady and clean, polished)
- Music treatment: starts at 0:00 (cue grid is relative to track start), volume ~0.30, 0.4 s fade-in, 1.6 s fade-out into the end card.
- Music cue guidance: bundled preset read (`vol-12`, ~110 BPM, beat 0.545 s). Strong cues locked: 8.74 s (To tag enters), 13.11 s (tag player enters), 18.56 s (outro). Beat-grid: the two taps at 14.73 s and 16.38 s.
- Audio-reactive treatment: subtle; music RMS/bass gently modulates the warm glow behind the phone and the clip tiles at the sides. No waveform or equalizer visuals.
- SFX posture: sparse, motion-matched. Soft drop when the phone lands, click on each simulated tap, one soft impact when the player screen arrives, one bell on the outro.
- Audio-coupled moments: the two simulated taps; the outro mark.
- Restraint rule: nothing loud; no sound on text pop-ins.

## Storyboard

### Scene 1 — Hook — 4.39s
Dark welcome screen of the phone slides up. "TakeTray" with the tray icon, headline "One tray for every take." (words blur in), sub "An Android app for short-form creators." Side clip tiles fade in.
Sequential/interaction: headline words in one by one (0.1 s apart); then held, dead still.
Audio intent: warm start. Audio-coupled idea: soft drop as the phone lands. Music: bed enters with fade.
Transition mood: soft blur-swap → Scene 2

### Scene 2 — Shooting mode — 4.35s
Phone swaps to Home: Shooting mode on, "23 clips to tag". Text: "Turn on Shooting mode." / "New videos land in To tag." (holds ≥ 2.5 s).
Sequential/interaction: none. Audio intent: calm. Audio-coupled idea: none.
Transition mood: clean → Scene 3

### Scene 3 — Scenes — 4.37s (locks strong cue 8.74)
To tag: clips grouped by scene. Marigold outline draws around the first scene. Text: "Grouped into scenes." / "Shot less than 10 minutes apart? Same scene." (from README/flow).
Sequential/interaction: outline appears around the scene group.
Audio intent: a small lift. Audio-coupled idea: none.
Transition mood: slide → Scene 4

### Scene 4 — One tap — 5.45s (locks strong cue 13.11)
Tag player (dark, on black). Tap "London Food" (press highlight, click): snackbar "Added to London Food · Undo", next clip. Tap "London Cinematic": same. Text: "One tap tags a clip." / "Wrong one? Undo."
Sequential/interaction: yes, two simulated taps on beats 14.73 s and 16.38 s.
Audio intent: the payoff, tactile. Audio-coupled idea: click per tap.
Transition mood: soft slide-out of the phone → Scene 5

### Scene 5 — Outro — 4.94s (locks strong cue 18.56)
Phone leaves. Centre: tray icon, "TakeTray", "Every clip you shoot, sorted into the right reel.", "Flutter · Riverpod · Drift (SQLite) · Offline-first", "Android app · personal project · in development". Small credit: "Music: Sascha Ende, ende.app (CC BY 4.0)". Holds ≥ 3.5 s then music fades.
Sequential/interaction: elements stack in, then still.
Audio intent: resolve. Audio-coupled idea: bell on the mark; music fades under it.

**Music mood for this video:** warm, steady, polished
**Audio summary:** a quiet bed, two tactile clicks where the app is tapped, and a single soft bell on the closing mark.
