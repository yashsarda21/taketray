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
| 3 | Finding your videos (Android media bridge) | ✅ Done |
| 4 | Reels screens | ✅ Done |
| 5 | Tagging (To tag and the tag player) | ✅ Done |
| 6 | Background detection and notifications | ✅ Done |
| 7 | Adding friends' videos (Add videos and Manual mode) | ✅ Done |
| 8 | Sending clips to editors (CapCut, Edits, VN) | Next |
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
- **GitHub checks**: every push runs the full `tool/check` on GitHub's Linux machines. Screenshot tests keep a separate, exact set of pictures for Linux, and text readability (contrast) is measured from the real colours, so it gives the same result on every computer. How it all works: [docs/learn/github-automatic-checks.md](docs/learn/github-automatic-checks.md).

### Phase 3: Finding your videos
- **Shooting mode**: a switch on the Reels tab. Turn it on and film with your phone's normal camera; TakeTray looks for the videos you shoot from that moment on. The card shows since when it has been on and has an **Open camera** button.
- **To tag**: the new videos land here, oldest first, as a grid with each video's picture, the time it was shot and its length. Open the tab and TakeTray checks for new videos first. When Shooting mode is off but videos are waiting, a banner on the Reels tab says how many and how much video that is. (Tagging itself comes in Phase 5.)
- **Thumbnails**: a small picture for every video, made once and kept on the phone (up to 64 MB, tidied up each time the app starts). If Android ever gives a number to a different video, the old picture is never shown for it.
- **Manual mode and the access banner**: TakeTray asks Android for permission to see your videos, and only videos. If you share only some of them ("Select photos and videos") or say no, a banner says **Manual mode** and offers **Allow full access**. If Android takes the permission away later, the banner says **TakeTray can't see your videos**. Either way, nothing is removed just because TakeTray cannot see it.
- **Add earlier videos**: from the Shooting mode card (on or off, whenever TakeTray has full video access; it stays after use) or the ⋮ menu of To tag. **Today** adds at once; **Choose dates…** opens a calendar for any from-to range, counts the videos first and asks "N videos found. Add them to To tag?" before adding anything. A snack with **Undo** follows.
- **Noticing deleted videos**: a video you delete in the Gallery leaves To tag when you come back to TakeTray. A clip that is already in a reel stays there, marked as missing. If Android rebuilds its media library, TakeTray finds your clips again by their size, length and date. When it is not sure, it calls the clip missing instead of showing the wrong video.
- **Time zones**: a clip is dated in the zone you were in when you shot it, even if you changed zone while TakeTray was closed.
- **No Google backup**: Android no longer copies TakeTray's data to Google or to a new phone, because its video numbers only mean something on the phone that made them. Export / Import (Phase 10) is the same-phone backup.
- **Phone tests**: on-device tests on the S24 give TakeTray access through the real Android dialog, put a test video into a folder of its own (`Movies/TakeTray Test`), check that it appears in To tag with its picture and leaves when deleted, and try Add earlier videos and Undo. They never read or delete your own videos, and the release check fails if any of this test code ends up in the app that ships.
- **Quality gates**:
  - more than 100 tests of the Android side run on a laptop in every `tool/check` and on GitHub, the video ones as four Android versions
  - the coverage check now counts files that no test loads
  - the release check also confirms the app asks only for video access and has no internet permission
  - the date logic is tested again with the clock set to London, where the clocks change
- **Learning guide**: [docs/learn/phase-3-media-bridge.md](docs/learn/phase-3-media-bridge.md) explains the whole phase in plain English, with the real code.

### Phase 4: Reels
- **Home (the Reels tab)**:
  - the Shooting mode card at the top;
  - filters (All, Collecting, Ready to edit, Published), each with its count;
  - your reels as cards: the oldest clip as the cover, the status, how many clips, how much video, and how many are missing;
  - a **New reel** button, which moves up out of the way when a message shows at the bottom;
  - "On since" updates at midnight;
  - if the camera can't be opened, TakeTray says so.
- **Creating and editing a reel**:
  - a name of up to 40 characters; two reels can't share a name;
  - optional shot ideas, up to 1,000 characters;
  - the status (Collecting, Ready to edit, Published).
  - If saving fails, the message shows inside the sheet, with what you typed kept.
- **Deleting a reel**: it asks first and says your videos stay in your gallery. **Undo** brings the reel back with all its clips.
- **Reel page**:
  - the full name, the status (tap it to change it), the clip count and length, and the shot ideas;
  - clips grouped by the day they were shot ("Day 1 · Sat 12 Oct");
  - an "in 2 reels" badge on a clip that is in more than one reel;
  - a grey tile with **Remove** for a clip whose video is gone.
  - Opening a reel checks that its videos are still on the phone.
- **Several clips at once**: long-press a clip to select it. Then:
  - **Add to another reel** (to one or more reels);
  - **Move to another reel**;
  - **Remove from this reel**;
  - **+ New reel** right in the picker.
  - Every change shows a message with **Undo**, which still works after you leave the page.
- **Clip viewer**:
  - full screen on black, playing the original video straight from your gallery (never a copy);
  - swipe or tap the arrows between clips; sound on or off; a scrubber;
  - the reels the clip is in;
  - Add to reel, Move and Remove.
  - If a video can't be played, it says so and offers to remove it from the reel.
- **Times where you shot**: a clip filmed in London and tagged later in India shows London time and sits under its London day. The viewer adds "London time". The phone's own time-zone rules are used, so nothing needs updating.
- **Undo you can trust**: Undo puts back exactly what changed, with the same clips. If Android gave a clip's number to a different video in the meantime, the clip comes back as missing, never as the wrong video.
- **Phone tests**: on the S24, the app creates a reel, renames it, marks it Ready to edit, adds a test video, plays it in the viewer, removes it and undoes that, then deletes the reel and undoes that. The whole on-phone suite passes (8 tests, 1 skipped on purpose).
- **Quality gates**:
  - the release check now also rejects the network-state and keep-awake permissions that the video player library tries to add; TakeTray never goes online;
  - more date tests run with the clock set to London.
- **Learning guide**: [docs/learn/phase-4-reels.md](docs/learn/phase-4-reels.md) explains the whole phase in plain English, with the real code.

### Phase 5: Tagging
- **To tag, grouped into scenes**:
  - clips shot less than 10 minutes apart on the same day form a scene, with its time range ("1:05–1:20 PM"), clip count and length;
  - a day header when the clips span several days, and a summary line ("23 clips · 4 scenes · 12 min");
  - **Tag scene** puts a whole scene into one or more reels at once;
  - **Start tagging**, or tap any clip to start tagging from it;
  - long-press to select clips, then **Tag** or **Skip** them;
  - **Skip all** asks first, then moves everything to Skipped, with **Undo**;
  - if the list can't load, it says so and offers **Try again**.
- **The tag player** (full screen, on black):
  - the clip plays muted (tap to unmute) and loops while you decide;
  - **one tap on a reel** tags the clip and moves to the next; a short tick on the chip first, so a double tap tags only once;
  - **Pick several** (or long-press a reel) puts one clip into several reels, and stays on from clip to clip until you turn it off;
  - **Same as previous** repeats the last clip's reels; **Skip** moves it to Skipped;
  - **+ New reel** right in the player, and the clip goes into it;
  - Collecting reels are open; Ready to edit and Published reels are folded under "Other reels";
  - "4 of 23" with the scene, a progress bar, arrows and swipe to move without tagging;
  - **Undo** takes the clip back out of the reel and returns you to it, even after you've closed the player;
  - closing the player during the tick cancels the tap;
  - **All done!** shows how many clips went into each reel.
- **Skipped**: skipped clips by day; tap one to put it back in To tag, or select several and **Restore**, each with **Undo**. Your videos stay in your gallery.
- **Phone tests** on the S24: tag a day of 40 test clips (one tap, Pick several, Same as previous, Skip), Undo going back, Skip all and Restore, Tag scene, and Undo after switching tabs. The whole on-phone suite passes (13 tests, 1 skipped on purpose). On the tiny test clips the next clip starts within about half a second of a tap; real camera clips are checked by hand.
- **Learning guide**: [docs/learn/phase-5-tagging.md](docs/learn/phase-5-tagging.md) explains the whole phase in plain English, with the real code.

### Phase 6: Background detection and notifications
- **New clips while TakeTray is closed**: with Shooting mode on, a notification ("2 new clips to tag") appears 5 minutes after your last clip (each new clip restarts the wait, so never in the middle of a shoot), with the normal notification sound once, and not while a take is still being recorded (a camera app that adds its video only when you stop cannot be seen mid-take); later count changes are silent, and tapping it opens To tag. The evening reminder waits for the same quiet, and is skipped when the quiet only comes after midnight. Android runs this check when it chooses, so a hot phone can delay it; the next app open always finds every clip.
- **Evening reminder**: once a day at the evening time, "You shot 3 clips today. Tag them?" if clips shot today are waiting. It leaves the shade once you tag them, the next day, or when the reminder is off.
- **Still shooting?**: a reminder in the shade when Shooting mode has been on for a long time, with **Turn off** and **Keep on**. Turn off from the shade adds only the clips shot before the tap, from every storage, even an SD card put in mid-shoot. In the app, a dialog asks once.
- **Notification permission**: asked once, the first time you turn Shooting mode on. The Settings screen shows whether notifications are allowed, and a help screen explains, phone by phone (with a Samsung button), how to stop the system from silencing them.
- **Survives restarts**: reminders and the new-clips check are set up again after a phone restart, an app update or a time change.
- **Safer scans**: clips that lose their link when Android rebuilds its media library are matched back (within 24 h), and a new SD card starts at the shoot's start, so old videos don't flood To tag.
- **Still offline and light**: only two permissions added (notifications, and starting after a restart). No exact alarms, no always-running service, no internet.
- **Phone tests** on the S24: the new-clips notification opening To tag, turning off removing it, the evening reminder's count, the real evening alarm, Still shooting? Turn off adding only pre-tap clips, the dialog, and one waiting check after bursts of new videos. Every on-phone test file passes. The physical buttons in the shade and opening from a notification are checked by hand ([docs/dev-setup.md](docs/dev-setup.md)).
- **Learning guide**: [docs/learn/phase-6-background.md](docs/learn/phase-6-background.md) explains the whole phase in plain English, with the real code.

### Phase 7: Add videos and Manual mode
- **Add videos**: a button on To tag and on a reel's page for clips TakeTray did not see you shoot (a friend's WhatsApp or Quick Share video, a clip from an action camera or an SD card):
  - a list of your phone's video folders, with how many videos each holds;
  - open a folder to see its videos as a grid (newest first; it loads a page at a time, so a folder with thousands of videos stays smooth), tick the ones you want and tap **Add**;
  - clips already in To tag or in a reel are marked ("In To tag", "In this reel"), and tapping one says "Already added";
  - WhatsApp's **Sent** folder is never shown, because it holds copies of your own videos;
  - **Undo** takes back only what that add made, and still works after you leave the screen;
  - a one-time tip, "Keep friends' clips sharp", suggests asking friends to send videos as HD or by Quick Share to keep full quality.
- **Manual mode**: when you share only some of your videos with TakeTray, or none, **Add videos** opens a sheet that opens Android's own photo picker. You choose videos there and TakeTray adds them, with the same message and **Undo**. **Allow full access instead** asks Android for full access, so next time you get the folder list. What you pick is kept even if you close the sheet while the picker is open.
- **Picked videos stay yours to keep**: they keep working after you close the app or restart the phone, they get a picture like any other clip, and TakeTray gives back Android's saved permission for a picked video only when no clip uses it any more.
- **If a picked video can't be read** (deleted in the gallery, or an SD card or USB drive taken out), its tile is shown as missing, never deleted for you. In To tag, in Skipped and in a reel, a missing tile has **Remove**, with **Undo**, and it comes back by itself if the video can be read again.
- **Clear messages**: "3 videos added to To tag", "Already added", or "Couldn't add 2 videos." when some could not be kept. A reel's page now shows the same banner as To tag when TakeTray can't see your videos, so a screen closing because access was lost always says why.
- **Phone tests** on the S24: adding from a folder to To tag, with the marks, "Already added" and Undo; adding to a reel; and the Sent folder staying hidden. All three passed the first time, and a deliberately wrong expectation failed as it should. Every other on-phone test file passes except one flow in the background tests that timed out while the phone was warm (the heat hold from Phase 6); its re-run on a cool phone is **pending**. The photo picker itself can't be used by a test, so the owner checked it by hand ([docs/dev-setup.md](docs/dev-setup.md), Phase 7 check, 14 steps): all behaved as written.
- **Quality gates**: the whole `tool/check` suite is now about 3,040 tests, and the release check still confirms no internet permission and no test-only code.
- **Still to come**: friends' and other devices' folders are added by hand only; watching them automatically belongs to the Watched folders screen in Phase 10.
- **Learning guide**: [docs/learn/phase-7-add-videos.md](docs/learn/phase-7-add-videos.md) explains the whole phase in plain English, with the real code.

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
| `app/pigeons/` | The contract between Flutter and Android for reading videos (Pigeon writes the code on both sides from it) |
| `app/android/app/src/main/kotlin/app/taketray/media/` | The Kotlin side: permissions, video queries, thumbnails, time zone changes |
| `app/android/app/src/main/kotlin/app/taketray/background/` | The Kotlin side of Phase 6: the new-clips job, notifications, reminders, shade buttons, re-arming after a restart |
| `packages/taketray_ui/` | The design system (theme and components) |
| `widgetbook/` | The "TakeTray UI" component catalogue |
| `tool/` | Flutter wrappers and check scripts |
| `design/` | Design tokens, the clickable prototype and icons |
| `docs/decisions.md` | Every meaningful decision and why |
| `docs/flow.md` | How each part of the app runs, step by step |
| `docs/later.md` | Work parked for later phases |
| `docs/learn/` | Learning guides: one per phase, plus how GitHub's automatic checks work |
| `.github/workflows/` | GitHub's automatic checks |
| `docs/superpowers/` | The build design and the phase plans |
