# TakeTray: Screen Design Prompt (Android, Version 1)

> **How to use this file:** give this whole document to a design session (for example Claude with design skills, or a designer). It describes every screen, flow, state and rule for version 1. The designer should produce the deliverables listed in section 9. Product decisions in this document are settled; visual and interaction details are open for the designer to propose, unless marked **(fixed)**.

---

## 1. What you are designing

You are designing **TakeTray**, an Android app (version 1, videos only) for Instagram reel creators.

**The problem it solves:** A creator on a trip shoots dozens of videos a day, planning several different reels ("London Food", "London Cinematic", "Day 1 Vlog"). Everything lands mixed in the phone gallery among thousands of other videos. At editing time, they waste time hunting for clips and often **miss the good clip** entirely.

**What TakeTray does:**
1. The creator creates **reels** (named projects) in the app, usually before or during a trip.
2. They switch on **Shooting mode** and film with the phone's **normal camera app** (full quality, all camera modes). TakeTray never records video itself.
3. Every new video shot while Shooting mode is on lands in a **To tag** list. A combined notification ("12 new clips to tag") reminds them.
4. Whenever they have a free moment (on a bus, on a train, in the evening), they open the To tag list, **watch each clip and tag it into one or more reels**, or skip it.
5. At editing time, a reel already holds all its clips. They pick the clips they want and **send them to their editor**: CapCut, Instagram Edits or VN.

**One-line pitch (draft):** *"Every clip you shoot, sorted into the right reel, so you never lose the good shot."*

**What it is not:** not a camera, not a video editor, not a cloud backup, not a social network. It never copies, moves or deletes the user's original videos (with one temporary exception for VN, see 6.4).

---

## 2. Who uses it

- **Primary user:** an Instagram creator in India, shooting 10–40 clips a day on trips. They tag in spare moments, often one-handed, sometimes in bright sunlight or a moving vehicle, often with sound off.
- **Phones:** mid-range and budget Android phones are common (Samsung, Xiaomi, Realme, Vivo, OnePlus). Design for a **360 dp wide** screen first, and check that layouts scale to 412 dp and larger. Assume 720p–1080p screens and modest performance.
- **Minimum Android version: Android 11** **(fixed)**. Design the permission variants: Android 11–12 (no notification permission dialog, no "limited access"), Android 13 (notification permission dialog), Android 14+ (video access can be "limited").
- **Editors they use:** VN, CapCut (outside India, banned in India), Instagram Edits.
- **First real user:** the developer, building it for themselves first. It may be published on the Play Store later, so it should look like a real product, not a prototype.

---

## 3. Design principles (in priority order)

1. **Tagging must be fast.** The To tag flow is where the user spends most of their time. Every tap saved per clip matters across 40 clips a day. One-handed use, big tap targets, minimal reading.
2. **Videos are the hero.** Thumbnails and playback should dominate; chrome should recede.
3. **Never scare the user about their videos.** Wherever something is removed or deleted, the copy must make clear the original video in the gallery is safe.
4. **Quiet by default.** Notifications are silent and update in place. No nagging.
5. **Simple over clever.** No feature should need a tutorial. If a concept needs explaining, simplify the concept.

---

## 4. Version 1 scope

### In version 1
- Onboarding (welcome, video access permission, notification permission, create first reels)
- Home: list of reels with status filter, Shooting mode switch, To tag entry point
- Create / edit / delete reels (name required; optional description used for shot ideas; status)
- Reel status: **Recording**, **Ready to edit**, **Published**, set manually **(fixed)**; new reels start as Recording
- Shooting mode on/off, with an "Open camera" shortcut
- To tag list: clips grouped into scenes, tag one clip, tag a whole scene, multi-select, Skip, Skip all, Skipped list with restore
- Tag player: watch a clip, tag it into one or more reels, "Same as previous", auto-advance, create a new reel on the spot
- Add videos manually (friends' clips from WhatsApp, Quick Share, Downloads): into To tag, or directly into a reel
- Reel detail: clips sorted by shooting time (oldest first), grouped by day; play; remove; add to / move to another reel; multi-select
- Full-screen clip viewer with swipe between clips
- Send to editor: CapCut and Instagram Edits get the original clips directly; VN gets a temporary copy folder; "Other app" uses the Android share sheet
- VN copy flow: space check, copying progress, instructions, "Editing in VN" state, "Done editing" cleanup, reminders
- Missing clip placeholder (grey box) with Remove
- Notifications: new clips (best effort), evening reminder, VN copies reminder, Shooting mode still-on reminder
- Settings: watched folders, reminders, storage used by VN copies, notification reliability help, export/import data, permissions, about

### Not in version 1 (do not design, but don't block them later)
- Photos (videos only for now)
- iPhone version
- Search; pinning reels; collections or trip groups; archive
- Custom reel covers (version 1 uses the first clip's thumbnail)
- Renaming clips; reordering clips manually; "best take" stars
- Separate notes lists per reel (version 1 has one description field for shot ideas)
- Recovering missing clips (Google Photos re-download, auto-reconnect, thumbnails of missing clips)
- "Save space" mode for VN (moving instead of copying)
- Cloud sync, accounts, login, payments, ads
- Home screen widgets

---

## 5. Key concepts and rules (the designer must respect these)

| Concept | Rule |
|---|---|
| **Reel** | A named project. Has name (required, max ~40 chars), description (optional, multi-line, for concept and shot ideas), status, creation date. Cover = thumbnail of its oldest clip; placeholder when empty. |
| **Clip** | A reference to a video in the phone's gallery. Shows thumbnail, duration, shooting time. **Can belong to several reels at once.** Removing a clip from a reel never deletes the video. |
| **Shooting mode** | A switch. While **on**, videos shot from the moment it was switched on (in watched folders, default: the phone's Camera folder) enter To tag. While **off**, new videos are ignored. Videos shot before switching on are never added automatically. |
| **To tag** | List of clips waiting to be tagged. A clip leaves To tag when tagged into at least one reel, or skipped. Untagged clips wait with no deadline. |
| **Scene** | Clips in To tag shot close together (gap under ~10 minutes) form a scene. Scenes are only a visual grouping to allow one-tap tagging of the whole group; the user always decides. |
| **Skip** | Removes a clip from To tag. Skipped clips go to a Skipped list where they can be restored. |
| **Status** | Recording / Ready to edit / Published. Manual. Used for the Home filter. Suggested (not forced) at moments like "Done editing" → "Mark as Published?". |
| **Sending to editors** | CapCut and Instagram Edits: originals shared directly in shooting-time order, no copies **(fixed)**. VN: temporary copies in a folder `Movies/TakeTray/<Reel name>`, numbered in shooting-time order, deleted only when the user taps "Done editing" after confirming export **(fixed)**. |
| **Missing clip** | If an original was deleted from the gallery, the clip shows as a grey placeholder in its place, with a Remove action. Nothing else in version 1. |
| **Times** | Show shooting times in the local time where the clip was shot (a London clip tagged later in India still shows London time). |
| **Clip leaving its last reel** | If a clip is removed from the only reel it was in, it leaves the app. It does **not** go back to To tag. Deleting a reel removes its clips from the app unless they are also in other reels. Remove actions offer Undo. |
| **No permanent notification** | Shooting mode does not run a background service, so there is **no always-visible notification** **(fixed)**. The "new clips" notification only appears once clips are waiting. |
| **Video access modes** | **Full access:** everything works. **Limited or denied access → "Manual mode":** no automatic detection; Add videos opens the Android system photo picker instead of the app's folder browser (no folder counts, no "already added" marks); a persistent banner offers "Allow full access". The app stays usable. |
| **VN copy files** | Copies are named by shooting time (e.g. `2026-10-12_14-05-33.mp4`), so they always sort in shooting order and are **never renamed or renumbered** once created (renaming would break the VN project). Adding clips or running Edit → VN again while copies exist only **adds** new copies; already-copied clips are marked "In VN folder", and unticking them does not delete them. Renaming the reel does not rename the folder until Done editing; instructions always show the real folder name. |
| **Export / import** | A backup for the **same phone** (reinstalling the app, resetting it). Import **replaces** all current data after a warning, then shows a summary: "120 of 140 clips found". Moving to a new phone isn't supported in version 1 (clips would show as missing); say so on the screen. |

---

## 6. Main flows

Design each flow end to end, including transitions.

### 6.1 First launch (onboarding)
1. Welcome: what the app does, in one screen (or at most 3 short slides).
2. Video access: explains why the app needs access to **all** videos ("to find new clips you shoot"). System permission dialog. Handle: granted; **"Allow limited access"** chosen (explain that automatic detection won't work, offer to change in settings, allow continuing in Manual mode, see section 5); denied (same: continue in Manual mode, or open settings).
3. Notifications: explain the "new clips to tag" notification and evening reminder. System dialog (Android 13+). Skippable.
4. Create your reels: quick add of several reels at once (e.g. type one name per line, or add rows quickly). Skippable.
5. Land on Home, optionally with a prompt to turn on Shooting mode.

### 6.2 A shooting day
1. Home → switch **Shooting mode on**. Card shows "On since 9:12 am".
2. Tap **Open camera** (opens the phone's normal camera in video mode) or use the camera as usual.
3. New videos appear; the notification "5 new clips to tag" updates silently (no sound, no vibration after the first).
4. Later: tap the notification, or open the app → To tag.
5. In the evening (default 9 pm), if clips are waiting: reminder "You shot 23 clips today. Tag them?"
6. After the trip: switch Shooting mode off. If it has been on for 14 days, the app asks once: "Still shooting? Turn off Shooting mode?"

### 6.3 Tagging (the most important flow)
- **To tag list:** scenes, each with a header like "1:05–1:20 pm · 6 clips" and a **Tag scene** action. Thumbnails show duration and time.
- **Tag a whole scene:** Tag scene → reel picker (multi-select) → all clips in the scene tagged. Undo available.
- **Tag one clip:** tap a thumbnail → Tag player opens on that clip:
  - Video plays automatically, **muted by default**, with an unmute control.
  - Row of reel chips (Recording reels first, then others).
  - **Tap a reel chip = tag the clip into that reel and auto-advance** to the next clip after a short confirmation (e.g. "Added to London Food", with Undo).
  - To put a clip into **more than one reel**: a clear secondary way to add several reels before advancing (e.g. long-press a chip, or a "+ more reels" mode, then "Next"). The designer should propose the clearest pattern; single-reel tagging must stay one tap.
  - **Same as previous:** one button applies the previous clip's reel(s) and advances.
  - **Skip:** removes the clip from To tag and advances.
  - **+ New reel:** create a reel on the spot without leaving the player; the clip is tagged into it.
  - Progress indicator, e.g. "4 of 23". Swipe or buttons to move between clips without tagging.
  - Clips inside a scene play in order; at the end of a scene, continue into the next scene.
- **Multi-select in the grid:** long-press to select several clips → actions: Tag (reel picker), Skip.
- **Skip all:** clears the whole To tag list, with a confirmation and an Undo snackbar.
- **Skipped list:** small entry point ("Skipped (12)") → grid → Restore to To tag.
- **All caught up** empty state when nothing is waiting.

### 6.4 Editing a reel
1. Reel detail → **Edit** (primary action) → selection mode with all clips **unselected** and a **Select all** option. The user ticks the clips they want.
2. Choose editor sheet: shows installed editors among **CapCut**, **Instagram Edits**, **VN**, plus **Other app…** (Android share sheet). Editors not installed are hidden or shown disabled with "Not installed".
3. **CapCut / Instagram Edits:** the selected original clips are handed to the editor in shooting-time order. The editor opens. TakeTray may suggest "Mark as Ready to edit?".
4. **VN:**
   1. Space check: "These 12 clips need 900 MB. You have 6 GB free." → Continue. If not enough space: explain and suggest selecting fewer clips.
   2. Copying progress (seconds to a minute), cancellable.
   3. Ready screen: "In VN, tap **New project** and open the **London Food** folder." with an **Open VN** button. Instructions should be visual (small illustrated steps).
   4. The reel now shows a banner/badge: **"Editing in VN · 900 MB"** with actions **Done editing** and **Add more clips to VN folder**.
   5. **Done editing:** confirmation "Have you exported your video? Once the copies are deleted, the VN project can't be edited any more. Your original clips are safe." → Delete copies → then "Mark as Published?".
   6. If forgotten: reminder notification after 3 days: "London Food copies are using 900 MB. Done editing?"
   7. Re-editing later: **Edit in VN** again recreates the copies in the same folder.

### 6.5 Managing clips in a reel
- Reel detail grid: grouped by day ("Day 1 · Sat 12 Oct"), oldest first. Each tile: thumbnail, duration, time; a small badge if the clip is also in other reels ("in 2 reels").
- Tap → full-screen viewer (swipe between clips). Actions: **Add to another reel**, **Move to another reel**, **Remove from this reel**, **Share**.
- Long-press → multi-select → Add to reel / Move to reel / Remove / Edit (send to editor).
- **Add videos** in a reel: pick videos from the phone (folder browser) and add them straight to this reel.
- Missing clips: grey tile "Clip missing from your phone" with **Remove**.

### 6.6 Adding friends' videos
- From To tag (adds to the list) or from a reel (adds straight to that reel).
- Opens TakeTray's own **folder browser**: folders with video counts (WhatsApp Video, Download, Quick Share, Camera, others) → video grid → multi-select → Add.
- Tip shown once: "Ask friends to send videos as HD or via Quick Share to keep full quality."

---

## 7. Every screen to design

For **each** screen, design: layout, all components, all states listed, interactions (tap, long-press, swipe), transitions, and final copy. Show light and dark themes.

### Onboarding
1. **Splash / app launch:** app icon and name.
2. **Welcome:** value of the app in one glance (illustration or short animation of "clips → reels").
3. **Video access permission:** explanation + button that triggers the system dialog. States: before asking; **limited access chosen**; **denied** (with "Open settings"); granted.
4. **Notification permission:** explanation + system dialog trigger + "Not now".
5. **Create your reels:** quick multi-add (several names at once). States: empty, with a few reels added. "Skip for now".

### Home and reels
6. **Home (Reels list):**
   - **Shooting mode card** at the top: big switch; when on: "On since 9:12 am · 14 clips to tag", **Open camera** button; when off: short explanation.
   - **To tag banner** when clips are waiting: "23 clips to tag →".
   - **Status filter**: All / Recording / Ready to edit / Published, with counts.
   - **Reel cards**: cover thumbnail (or placeholder), name, status pill, clip count, total duration, "Editing in VN" badge when copies exist. Sorted newest first.
   - **New reel** button (e.g. floating action button).
   - States: first-time empty (no reels); filter with no results; many reels (20+); a reel with zero clips; a reel with missing clips.
7. **Create / edit reel** (bottom sheet or full screen): name (required), description / shot ideas (optional, multi-line), status (edit mode only). Validation for empty or duplicate names.
8. **Reel detail:**
   - Header: cover, name, status (tap to change), clip count and total duration, description (collapsible).
   - **Edit** primary action; **Add videos**; overflow menu: Edit reel, Delete reel.
   - "Editing in VN" banner state with **Done editing** / **Add more clips to VN folder**.
   - Clip grid grouped by day; "in 2 reels" badges; missing clip tiles.
   - States: empty reel ("No clips yet. Tag clips from To tag or add videos."), normal, many clips (100+), multi-select mode, editing-in-VN, contains missing clips.
9. **Delete reel confirmation:** "Delete London Food? Your videos stay in your gallery. Only this reel and its tags are removed." If VN copies exist, also say they will be deleted.
10. **Status change** control (menu or segmented control) and the "Mark as Published?" prompt after Done editing.

### Tagging
11. **To tag list:** scene groups with headers and **Tag scene**; thumbnails with duration and time; long-press multi-select (Tag / Skip); **Skip all**; **Add videos**; **Skipped (N)** entry; Shooting mode status shown. States: empty (Shooting mode off: explain how to start; on: "All caught up"); a few clips; 100+ clips; one scene; multi-select; loading thumbnails.
12. **Tag player:** see 6.3. States: first clip; middle of a scene; last clip ("All done!" moment); clip in several reels being chosen; video still loading; very long clip (scrubbing); vertical vs horizontal video; no reels exist yet (prompt to create one).
13. **Reel picker sheet** (used by Tag scene, multi-select Tag, Add to reel, Move to reel): list or chips of reels, Recording first, multi-select where allowed (single-select for Move), **+ New reel** inline, confirm button with count ("Tag 6 clips").
14. **Skip all confirmation and Undo snackbar.**
15. **Skipped list:** grid, multi-select, Restore, plus a note that skipped clips are still in the gallery.

### Clips
16. **Full-screen clip viewer:** video playback with sound control, scrubber, swipe left/right between clips, which reels this clip is in, actions (Add to another reel, Move, Remove from reel, Share). Vertical and horizontal videos.
17. **Add videos: folder browser:** folders with names, video counts and preview thumbnails → video grid → multi-select → Add (count). Clips already in this reel or in To tag are marked. Empty folder state. In Manual mode (limited or denied access), this screen is replaced by the Android system photo picker; design the short explanation shown before it opens.

### Sending to editors
18. **Clip selection mode for Edit:** checkboxes on tiles, Select all, counter, total size and duration of the selection, Continue.
19. **Choose editor sheet:** CapCut, Instagram Edits, VN (installed ones), Other app…; short line under VN: "Makes temporary copies".
20. **VN: space check:** needed space vs free space; not-enough-space state.
21. **VN: copying progress:** progress, cancel; failure state (ran out of space mid-way, copy error).
22. **VN: ready / instructions:** illustrated steps for opening the folder in VN, **Open VN** button.
23. **Done editing confirmation:** see 6.4 step 5.

### Settings and help
24. **Settings home:** Shooting mode reminders, evening reminder (on/off + time), watched folders, storage (VN copies), notifications not arriving?, export/import data, permissions status, about (version, privacy note: "Your videos never leave your phone").
25. **Watched folders:** list with switches; Camera on by default; add other folders (e.g. pro camera apps); each shows its video count.
26. **Storage used by VN copies:** list of reels with copies, size each, total, delete per reel (with the same export warning).
27. **Notifications not arriving? (help):** short explanation that some phones stop apps in the background, and simple per-brand steps (Samsung, Xiaomi, Oppo/Realme, Vivo, OnePlus) with a button to open the relevant settings where possible. Reassure: "Your clips are never lost; they appear when you open the app."
28. **Export / import data:** export reels and tags to a file; import from a file; explain it does not include the videos themselves.
29. **Permission problem screen/banner:** shown anywhere if video access was removed or switched to limited (Android can also remove permissions from apps unused for months). Explains and offers "Allow access".

### Notifications (design the content and actions)
30. **New clips:** "5 new clips to tag" with small thumbnails if possible; tap → To tag; action **Open camera**. Updates in place, silent.
31. **Evening reminder:** "You shot 23 clips today. Tag them?" → To tag.
32. **VN copies reminder:** "London Food copies are using 900 MB. Done editing?" → reel detail.
33. **Shooting mode still on (after 14 days):** "Still shooting? Turn off Shooting mode?" with action **Turn off**.

### System-wide states
34. **Snackbars/toasts** (tagged, undo, skipped, removed), **loading** skeletons for thumbnails, **error** states (video can't play, editor not installed, storage full).

---

## 8. Copy and tone
- Short, friendly, plain English (the user is Indian; avoid idioms that don't translate). No jargon: say "video", "clip", "reel", "folder"; never "MediaStore", "URI", "sync".
- Reassure about originals wherever removing or deleting: "Your videos stay in your gallery."
- Numbers over words: "23 clips · 4 min".
- Provide final copy for every screen, button, empty state, error and notification.

---

## 9. Deliverables expected from the design session

**Format:** interactive **HTML/CSS prototypes** (one page per screen, linked into clickable flows), plus a **design-tokens JSON file** (colours, type, spacing, radii, elevation for light and dark) that maps directly onto a Material 3 / Jetpack Compose theme. Build tokens and components first, so dark mode comes from the tokens. If you work in Figma instead, keep the same structure: tokens as variables, a component library, and linked prototypes.

1. **Design system:** colours (light and dark), typography, spacing, corner radii, elevation, iconography; components (reel card, clip tile with all its badges, scene header, reel chip, status pill, Shooting mode card, bottom sheets, snackbars, dialogs). Based on **Material 3** so it maps to Android (Jetpack Compose); a distinct brand on top is welcome.
2. **App name and icon concepts** (the app is named **TakeTray**). Do not use Instagram, CapCut, VN or Meta branding beyond the editors' own app icons provided by the system.
3. **Navigation map** of all screens and how they connect (suggested: bottom navigation with **Reels**, **To tag** (with a badge count), **Settings**; the designer may propose better).
4. **Every screen in section 7**, with all listed states, at 360 dp width, light and dark.
5. **Interactive prototypes** of the three key flows: tagging a day's clips (6.3), sending a reel to VN including Done editing (6.4), and onboarding (6.1).
6. **Motion notes** for the tag-and-advance moment, scene tagging and Shooting mode switch.
7. **Accessibility:** touch targets at least 48 dp, contrast AA, TalkBack labels for icon buttons, no information by colour alone, font scaling to 200%.
8. **Developer handoff:** spacing and sizes in dp/sp, colour tokens, component specs, and a list of assets.
9. A short list of **design decisions you made** and **questions** for the product owner.

---

## 10. Left to the designer
- Visual style, brand, colours, illustrations, motion.
- Exact layout of every screen within the rules above.
- The exact gesture/pattern for tagging a clip into several reels while keeping single-reel tagging one tap.
- Whether onboarding is one screen or a few slides.
- Whether reel chips, a list or a grid works best in the Tag player for 2 to 20+ reels.
- Bottom navigation vs other navigation, if better justified.
