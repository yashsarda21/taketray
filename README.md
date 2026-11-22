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
| 8 | Sending clips to editors (CapCut, Edits, VN) | ✅ Done |
| 10 | Onboarding and Settings: 10A first launch, 10B Settings (moved ahead of Phase 9, D-134) | ✅ Done |
| 9 | Reference reels: 9A references in the app, 9B Sharing in | 9A built, S24 tests passed (4/4), owner's hand checks pending, **Next: Phase 9B Sharing in** |
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
- **Phone tests** on the S24: adding from a folder to To tag, with the marks, "Already added" and Undo; adding to a reel; and the Sent folder staying hidden. All three passed the first time, and a deliberately wrong expectation failed as it should. Every other on-phone test file passes, and the background tests, where one flow timed out while the phone was warm (the heat hold from Phase 6), passed 7 of 7 when re-run on a cool phone (thermal status 0, 2026-11-13). The photo picker itself can't be used by a test, so the owner checked it by hand ([docs/dev-setup.md](docs/dev-setup.md), Phase 7 check, 14 steps): all behaved as written.
- **Quality gates**: the whole `tool/check` suite is now about 3,040 tests, and the release check still confirms no internet permission and no test-only code.
- **Still to come**: friends' and other devices' folders are added by hand only; watching them automatically belongs to the Watched folders screen in Phase 10.
- **Learning guide**: [docs/learn/phase-7-add-videos.md](docs/learn/phase-7-add-videos.md) explains the whole phase in plain English, with the real code.

### Phase 8: Editor handoff
- **Edit video**: a button on a reel's page. Tick the clips you want (or **Select all**), tap **Continue** and choose an editor. Clips always go in shooting order, and your originals are never changed.
  - **CapCut and Instagram Edits** get the original clips in one share, so they open in one new project. A grey row says "Not installed" when the editor is missing.
  - **VN** cannot take several shared clips, so TakeTray makes temporary copies in `Movies/TakeTray/<reel name>/`. VN's picker shows that folder.
  - **Share** (in the clip viewer, and for clips ticked on a reel's page) sends clips to any other app through Android's own chooser.
- **Copying for VN, with TakeTray open**: first a screen checks there is enough space and keeps a reserve free. While it copies, a screen shows the progress, keeps the phone awake and says "Keep TakeTray open until copying finishes". There is no background service and no notification. A full phone, a stopped copy and clips that failed each have their own screen with **Try again** (it copies only the rest). If Android closes TakeTray mid-copy, the finished copies are kept and the half-written file is removed. **Cancel**, then **Stop**, deletes what the job copied.
- **The reel page while you edit**: a banner says "Editing in CapCut" (or Instagram Edits, or VN). Clips tagged since you started show under "New since you started editing", and the rest under "In your edit". Removing a clip from the reel deletes its copy too.
- **Done editing**: asks "Have you exported your video?", deletes the copies (the originals stay in your gallery), shows how much space came back, and offers to mark the reel Published.
- **Adding clips later**: for VN, **Copy to VN folder** adds only the new clips to the same folder. For CapCut and Edits, the new clips are copied into the reel's folder, and the editor's **+** shows that folder as an album named after the reel (a second batch works the same way).
- **A reminder after 3 days**: "Wedding copies are using 1.2 GB" over "Done editing? Tap to clean up." One notification per reel; tapping it opens the Done editing question.
- **Storage screen** (Settings, "Storage used by VN copies"): what the copies cost, one row per reel with **Delete** (it asks the same question as Done editing), and copies left from an earlier install under "Not linked to a reel". Those are deleted only after Android's own consent dialog. Add videos never offers TakeTray's own copy folders.
- **Under the hood**: the database is now schema 2 (which editor a reel is in, when each copy was made, which clips were sent). The release check still confirms no internet permission, no foreground service and no wake lock.
- **Phone tests** on the S24: sending 3 clips to CapCut in one share, an editor that is not installed, a real VN copy of 3 clips with the screen kept on, cancelling a copy, adding a clip later, removing a clip during a session, sharing from the viewer, and the reminder's tap. All 8 passed after one fix to the test (a greyed row cannot be tapped like a button), and a deliberately wrong expectation failed as it should. Every other on-phone test file passes (23 tests) and the release check says `RELEASE PERMISSIONS OK`. The real editors, Android's consent dialog and large copies can't be driven by a test, so the owner checked them by hand ([docs/dev-setup.md](docs/dev-setup.md), Phase 8 check, 12 steps, 2026-11-15): all behaved as written. The hand checks also found a red error screen, caused by TakeTray changing a screen's state while the screen was still being built; it is fixed and did not come back.
- **Still to come**: copying in the background with a foreground service, and moving clips into a reel album instead of copying, are parked in [docs/later.md](docs/later.md) until users ask. The on/off switch for the reminder belongs to Settings in Phase 10.
- **Learning guide**: [docs/learn/phase-8-editor-handoff.md](docs/learn/phase-8-editor-handoff.md) explains the whole phase in plain English, with the real code.

### Phase 10A: First launch
Phase 10 was moved ahead of Phase 9 (decision D-134): nothing in it needs reference reels, and Phase 9 will later plug "save a reference on the first launch" into this onboarding. It is built as two branches, 10A (first launch) and 10B (Settings).

- **Animated launch splash**: on every launch the tray icon rises in, two clips drop into it and the tray squashes slightly as it catches them, in under a second (920 ms), once, never looping. When the first screen is ready the splash fades out in 200 ms and never makes you wait for the animation to finish. Android 11 shows the still icon, and "Remove animations" shows the finished icon.
- **The B · Tray welcome**: on the first launch, a welcome screen plays a 3.6 s intro (three clips drop into a tray, each reel tab pops on, the count ticks up to "23 takes · 3 reels", then the headline "One tray for every take" rises into place). **Get started** works from the first frame and a tap on the picture skips to the end. The intro plays once: if you close the app and come back before finishing, you see the welcome's final frame, never a blank app. With "Remove animations" on, it shows the final frame at once.
- **Onboarding steps in TakeTray's own words**: **video access** (why TakeTray needs it, then Android's own question with a hint to choose "Allow all", and a clear look for "not allowed" with a way to carry on in Manual mode), **notifications** (asked on Android 13 and newer, with "Not now" allowed) and **planning your first reels** (type names or tap ideas such as Food, then **Create 2 reels** or **Skip for now**; the reels are saved all together or not at all). Back goes to the previous step; "onboarding done" is saved only when the last step finishes.
- **The Shooting mode tip**: once, on Reels, a small tip with a ring around the Shooting mode card points at the switch. **Got it**, or turning Shooting mode on, removes it for good.
- **Under the hood**: a router redirect keeps every other screen away until onboarding is done; the three first-launch flags are phone state, so an export and import never carries them.
- **Phone tests** on the S24 (Android 17): four on-device flows (a fresh phone, Manual mode, closing midway, and the Home tip with the Shooting mode switch). The first two runs found faults in the test harness, not the app (Patrol's typing closed the keyboard connection, and an empty lifecycle state made Android 16 and newer close the app on Back); both were fixed and the third run passed 4 of 4. All nine older on-device test files passed once more. The splash, the intro's smoothness, TalkBack, a real kill and Android's own settings page cannot be driven by a test, so the owner checked them by hand ([docs/dev-setup.md](docs/dev-setup.md), Phase 10A check): checks 1 to 19 all passed, and the release build installed over the real app showed onboarding once and kept its data. (The blur behind Android's own permission dialog is the system's, not TakeTray's.)
- **Still to come**: the full Settings screen, Watched folders, Export and import and the error log are Phase 10B; reference reels are Phase 9.
- **Learning guide**: [docs/learn/phase-10a-first-launch.md](docs/learn/phase-10a-first-launch.md) explains the whole phase in plain English, with the real code.

### Phase 10B: Settings
- **Every reminder switch reaches the background**: besides the evening reminder, "Remind me to turn it off" (Still shooting?) and "VN copies reminder" now have their own switches, and each one changes what the background job and Android's alarms do, not only what is saved. Switching the evening reminder off also removes one that is already showing, without opening the app.
- **The full Settings screen**, in seven groups: Shooting mode, Reminders (with the reminder time, shown in the phone's 12 or 24-hour style), Clips (Watched folders, Storage used by VN copies), Help (Notifications not arriving?, Send error log), Your data (Export and import), Permissions (Video access, Notifications) and About (the privacy line and the version). Every change is saved safely even when two switches are tapped at once.
- **Watched folders**: choose which folders TakeTray looks in for new videos, with an on/off switch for each. Chat-app folders such as WhatsApp Video can be watched, with a warning on the row. Only videos that arrive after a folder is turned on are picked up, and TakeTray's own folders are refused.
- **Export and import**: a backup is one file you save with Android's own document picker, with the date of the last backup shown on the row. An import brings back your reels, clips and settings, says "X of Y clips found" (clips are matched to the videos on this phone), keeps this phone's own state (onboarding, the last backup date) and **refuses while VN copies are being made**. Nothing leaves the phone and no storage permission is needed.
- **Send error log**: shares the log through Android's share sheet (mail, chat or save), with no reel names and no video names in it.
- **Allowed permission rows open Android's settings** (an owner request from the S24): Android does not let an app take back its own permission, so when Video access says "All videos" or Notifications says "Allowed", tapping that row opens TakeTray's page in Android's settings, where it can be turned off.
- **Phone tests** on the S24 (Android 17): five on-device flows (the switches, the switches reaching the background, a watched folder, export then import, and Send error log). The first run passed 4 of 5; the Send error log flow failed because the test's safety fake refused to open the share sheet, a fault in the test and not the app. It now uses the real share sheet, and the second run passed 5 of 5. The real folder and document pickers, the look against the prototype, TalkBack and a real reminder arriving cannot be driven by a test, so the owner checked them by hand ([docs/dev-setup.md](docs/dev-setup.md), Phase 10B check): checks 1 to 18 all passed, including the new permission rows.
- **Learning guide**: [docs/learn/phase-10b-settings.md](docs/learn/phase-10b-settings.md) explains the whole phase in plain English, with the real code.

### Phase 9A: References in the app (S24 tests passed; hand checks pending)
- **References on a reel**: a reel's page has a References section. With none it shows one dashed **Add reference** row ("Save a reel you want to recreate"); with some it shows "References · 3", a small **Add** button and a card per link, newest first. Tapping a card opens the link in the Instagram, YouTube or TikTok app, or the browser, whichever the phone picks; if nothing can, it says so. Each card's ⋮ menu has **Edit label**, **Copy link** and **Remove** (instant, with **Undo**). A reel with links and no shot ideas gets a note, "Write the shots you need", that opens its details on the shot ideas.
- **Add reference sheet**: type or paste a link and give it an optional label of up to 60 characters. **Paste** is the only thing that ever reads the clipboard, so Android's own paste message shows only after you tap it; it takes the first link out of a whole caption. A link that is not a link, or is already saved on the reel, is told under the field. **Edit label** is the same sheet for a link already saved.
- **The reel form's Reference link**: the New reel and Reel details sheets have an optional link box. A new reel is made with its link in one step (all or nothing), and an existing reel keeps the link in its references; the help line says how many it has.
- **The Home badge**: a reel card with references shows a small badge with their number. Tapping it opens the reel at its References section, scrolled into view and flashed once (not with "Remove animations").
- **Shooting mode's References**: while Shooting mode is on and a Collecting or Ready to edit reel has a reference, its card gets a **References · N** row. It opens a sheet that groups the references by reel with each reel's shot ideas, so they can be read while filming; a group can be folded away, a card opens its link and a header opens that reel at its References.
- **The phone's own icons**: a card shows the real icon of the Instagram, YouTube or TikTok app when it is installed, and a plain link symbol otherwise. TakeTray never draws a logo of its own.
- **Under the hood**: a new Links bridge (one Pigeon file, no permission; the app declares the few `<queries>` it needs to read icons) opens links, and the link rules (finding the first link in a caption, cleaning one so the same page is not saved twice, short forms for display) are plain tested functions. The database is unchanged (still schema 2) and a backup already held references.
- **Phone tests**: four on-device flows are written (a typed link, Paste with the Home badge, the reel form's link, and the Shooting mode sheet) with a fake that stands in for the links bridge, so no real link is ever opened; they run on the S24 last, together with the hand checks in [docs/dev-setup.md](docs/dev-setup.md) (Phase 9A check): real Instagram and YouTube, Android's paste message, TalkBack, 200 % text, dark mode, the Shooting mode sheet's colours, the keyboard on opening the New reel sheet, and an install over the release build with references kept.
- **Still to come**: Phase 9B, **Sharing in**: sharing a reel from Instagram straight to TakeTray to save it as a reference.
- **Learning guide**: [docs/learn/phase-9a-references.md](docs/learn/phase-9a-references.md) explains the whole phase in plain English, with the real code.

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
