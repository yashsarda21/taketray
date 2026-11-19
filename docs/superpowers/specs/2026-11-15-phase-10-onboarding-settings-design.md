# Phase 10: first launch and Settings (design)

Date: 2026-11-15 · Owner-approved in conversation (brainstorming, 2026-11-15) · Builds on the v1 build design (`docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`, phase table row 10), D-133 (`design/handoff/launch-and-welcome-motion.md`), the prototype (`design/prototype/assets/screens.js`: `ob-welcome`, `ob-video`, `ob-notif`, `ob-reels`, `settings`, `watched`, `backup`; `welcome.js` B · Tray; `intro.js`) and the Phase 10 items in `docs/later.md`.

## Intent

Phase 10 makes TakeTray ready for someone who installs it from the Play Store and has never seen it. Today a fresh install opens straight on Reels, video access is asked through the Manual-mode banner or the Shooting mode switch, and Settings has three interim rows. After Phase 10 a new user is welcomed, asked for access and notifications in their own words, invited to plan their reels, and pointed at Shooting mode; and every setting the app already reads has a place to change it.

**Order.** The owner moved Phase 10 ahead of Phase 9 (References). Nothing in Phase 10 needs references. Phase 9 later plugs its "save a reference on first launch" flow into this onboarding.

**Split.** Two branches, one after the other, each with its own plan, reviews, PR and S24 check:
- **10A, first launch:** splash, welcome, onboarding steps, the Home tip, and the parked items about the access and notification asks.
- **10B, Settings:** the full Settings screen, Watched folders, Export and import, Send error log, and the rest of the parked Phase 10 items.

10A merges before 10B starts.

## Goals

- First launch end to end on a fresh install (the build design's "done when" for Phase 10), on the S24 and on emulators for API 30, 33 and 34+.
- D-133 built as specified: the animated splash and the B · Tray welcome intro.
- Every user setting the app reads (evening reminder and time, 14-day "still shooting" reminder, VN copies reminder, watched folders) can be changed in Settings, and the background side honours it.
- A user can send the error log and make and restore a backup.

## Non-goals

- References (Phase 9), including the onboarding tip "share any Instagram reel" and the prototype's `reference-first` flow.
- Moving to a new phone (backups only work on the same phone; the backup screen already says so).
- Release signing, R8, Play Console material (Phase 11).
- The prototype's full-screen "Allow video access again" (`perm-lost`). The existing banner "TakeTray can't see your videos" stays (builder's note: my call, the banner already works and is tested).

## Anti-goals

- The intro must never make anyone wait: Get started works from frame 0, nothing loops, the splash never waits for its animation.
- No network, no new permissions, no third-party Android plugins (release permission check must stay "RELEASE PERMISSIONS OK").
- Logs never contain video names, paths, URIs, folder names, reel names, cities or the phone maker (D-10). That includes the error log a user sends.
- Onboarding must never lose data: existing reels and clips stay as they are.

## Constraints

- Stack as today: Flutter through `tool/flutter`, Riverpod 3 codegen, Drift (schema v2, unchanged unless the builder finds a reason), go_router, freezed, Pigeon; Kotlin uses Android platform APIs only.
- Phone-only state goes in `PhoneStateRepository` (never exported); user settings go in `SettingsRepository.exportedKeys` (exported).
- Strict TDD with mutation checks; goldens light and dark; Patrol flows written before the phone is used; `docs/decisions.md` and `docs/flow.md` updated with the code.
- Release manifest: no `INTERNET`, `ACCESS_NETWORK_STATE` or `WAKE_LOCK`; no foreground service.

## Approaches (decided)

1. **How onboarding takes over the app.**
   - **A. Router redirect (chosen).** Onboarding steps are ordinary go_router routes. While onboarding is not done, the router's redirect sends every location to the right onboarding step: notification taps, launch actions and restored back stacks included. Back between steps comes from the router.
   - B. A gate widget in front of `MaterialApp.router` with its own navigator. Rejected: notification taps, `MediaLifecycle`, the root messenger and `LaunchActionsListener` live inside the app it replaces, so each would need a special case.
2. **Sharing the log and choosing backup files.**
   - **A. Android APIs through Pigeon (chosen):** the share sheet through a `FileProvider` (`ACTION_SEND`), and the document picker (`ACTION_CREATE_DOCUMENT` to export, `ACTION_OPEN_DOCUMENT` to import).
   - B. `share_plus` / `file_picker`. Rejected: third-party Android code and manifest entries the release permission check would have to vet.

## 10A: first launch

### Splash (every launch)

Exactly D-133 part 1 (`design/handoff/launch-and-welcome-motion.md` §1): `androidx.core:core-splashscreen`, a `Theme.SplashScreen` launch theme (light and night), `splash_icon_animated.xml` in three groups, the still wordmark as the branding image, `installSplashScreen()` before `super.onCreate` in `MainActivity`, and a 200 ms fade exit. No `setKeepOnScreenCondition`. Android 11 and "Remove animations" show the still icon. This was a Phase 11 item in the build design; it moves here because its fade leads into the welcome.

### The steps

| # | Route (suggested) | Screen | Leaves by |
|---|---|---|---|
| 1 | `/welcome` | B · Tray welcome with the D-133 intro | Get started → 2 |
| 2 | `/onboarding/access` | "Let TakeTray see your videos" (prototype `ob-video`) | see below |
| 3 | `/onboarding/notifications` | "Know when clips are waiting" (`ob-notif`), Android 13+ only | Allow / Not now → 4 |
| 4 | `/onboarding/reels` | "What reels are you planning?" (`ob-reels`) | Create N reels / Continue / Skip for now → Reels tab |

**Step 2, video access.** Copy as in the prototype. "Allow access" asks Android (the existing `MediaBridge.requestAccess`). The button hint says "choose **Allow all**" on Android 14+ and "**Allow**" below. Outcomes:
- full → "All set" with a Continue button (the prototype's success art). Continue → step 3 (or 4 on Android 11–12).
- some videos only → "TakeTray can see only some videos": Allow all videos (asks again) or Continue in Manual mode.
- denied → "TakeTray can't see your videos": Open settings (`MediaBridge.openAppSettings`) or Continue in Manual mode. When the user comes back from Android settings with access given, the step updates to its new state.
- Already full when the step opens (a reinstall that kept the grant): show "All set" straight away.

**Step 3, notifications.** Android 13+ only; on Android 11–12 the step is skipped (notifications need no permission there). "Allow notifications" asks once through the existing `NotificationAccessController` and records `notificationsAsked`; either answer, or "Not now", goes to step 4. Already allowed → skipped.

**Step 4, reels.** A text field (40 characters, Enter adds the name and keeps focus), the added names as rows with a remove button, and up to four idea chips (Day 1 Vlog, Food, Cinematic, Behind the scenes, Get ready with me, minus names already added; hidden once 5 names are added). The button says "Create N reels" when names were added, "Continue" when none were added but reels already exist (an install that has reels, like the owner's), and is disabled otherwise; "Skip for now" always finishes. Names follow the existing reel-name rules (`showReelForm`'s validation: trimmed, not empty, duplicates refused case-insensitively against existing reels and the list). The "share any Instagram reel" tip is hidden until Phase 9.

**Finishing.** Create writes the reels in one go through the existing reels repository, then onboarding is marked done and the app goes to the Reels tab with the one-time Home tip. Skip for now does the same without creating.

**Home tip.** Once, after onboarding finishes: the prototype's tooltip beside the Shooting mode card (`screens.js` `u.hint === 'shoot'`): "Going out to shoot?" / "Turn on Shooting mode first. New videos will wait in To tag." with a "Got it" text button, and the card highlighted. It does not block touches: the switch under it works, and turning Shooting mode on also dismisses the tip. "Got it" or turning it on sets `homeTipSeen`; it never returns.

**Step dots.** Four dots (welcome, access, notifications, reels). On Android 11–12 the notifications dot is still shown and skipped over (builder's call if a 3-dot version reads better; record it).

### Rules

- **Flags** (all in `PhoneStateRepository`, never exported; 10B makes the import keep them, see "Export and import"):
  - `introPlayed`: set when the intro starts or is skipped. Set → the welcome builds on its final frame.
  - `onboardingDone`: set only when step 4 finishes (Create or Skip for now).
  - `homeTipSeen`: set when the Home tip is dismissed.
- **Existing installs.** No special case: any install without `onboardingDone` gets onboarding once, whatever it already holds. The owner's own TakeTray has dummy data and will go through it; its data is left as is (and step 4 shows "Continue" because reels exist).
- **Redirect.** While `onboardingDone` is false, every location outside the onboarding routes goes to `/welcome`. While it is true, the onboarding routes go to the Reels tab. Closing the app midway reopens on `/welcome` (final frame, since `introPlayed` is set). The redirect must not show a wrong first frame while the flag is being read (builder decides how: read before `runApp`, or a neutral first frame).
- **Back.** Back goes to the previous step; on the welcome, Back closes the app. Back from step 2's system dialog is Android's own.
- **Launch actions during onboarding** (a notification tap is possible only after step 3, but a stale action or the copies reminder can still arrive): kept and dropped, not replayed after onboarding (builder's note: my call; nothing a new user has can be waiting).
- **The old first-time asks** (later.md, D-75, D-107):
  - Shooting mode's switch keeps `MediaAccessController.askIfDenied`: turning it on is when access is needed, and a user who chose Manual mode in onboarding gets asked again there (only while Android can still show its dialog, as today).
  - Shooting mode's `NotificationAccessController.askOnce` stays as the fallback for someone who tapped "Not now". It still asks only once overall: if onboarding asked, `notificationsAsked` is already set and the switch does not ask.
- **Media work during onboarding.** `MediaLifecycle` keeps starting as today. With no access the scan finds nothing; with full access but Shooting mode off it has no baseline. Nothing new to guard (builder confirms).

### The welcome intro

Exactly D-133 part 2 (handoff §2): one `AnimationController` of 3600 ms, the interval table, the drop `TweenSequence`, tap to skip, reduced motion, TalkBack labels, `TickerMode`, the local duration constants. The take pictures are the prototype's three procedural thumbnails (`RH.thumb` for London Food, Cinematic, Day 1 Vlog), exported once to small bundled images (builder chooses format and size; they must be sharp at 3× on the S24).

### D-133 ownership

10A builds all of D-133; there is no earlier branch for it. The `docs/later.md` section "Next, ahead of the phase order" (and its "Get started goes on to the existing first-run path" line) is superseded: 10A's first commit moves the item under Phase 10 and points D-133 at this design. Get started goes to step 2.

### Checks for 10A

- Goldens: the welcome at 0.4, 1.0, 1.5, 1.95, 2.5, 3.1 s and final, light and dark; each onboarding step in each state (before, some, denied, all set; notifications; reels empty, with names, with existing reels) light and dark.
- Widget tests: the handoff's five; the redirect (not done → `/welcome` from any location, including a launch action; done → onboarding routes go to Reels); Back between steps; step 2's states from each access report; step 3 skipped on Android 11–12 and when already allowed; step 4's button label rules, duplicates, Enter, ideas; the flags written at the right moments.
- Robolectric: `MainActivity` installs the splash and the fade listener.
- Patrol on the S24: fresh `app.taketray.dev` (after `pm clear`) through all four steps with full access; the Manual mode path; reopening after closing midway.
- By hand on the S24: cold start with the splash's animation and fade; the welcome intro; "Remove animations" on; a warm start shows no splash.

## 10B: Settings

### The Settings screen

The prototype's `routes.settings`, in its order. The three existing rows (Notifications not arriving?, Notifications, VN copies storage) keep their behaviour and tests and move into place.

| Group | Row | Behaviour |
|---|---|---|
| Shooting mode | Remind me to turn it off | Switch, stored as a user setting (`stillReminderEnabled`, default on). `BackgroundSync` writes it instead of the constant `true`; the in-app "Still shooting?" prompt follows it too. |
| Reminders | Evening reminder | Switch (`eveningReminderEnabled`). Subtitle "21:00, only if clips are waiting" in the phone's 12/24-hour format. |
| | Reminder time | Shown only while the evening reminder is on. Opens the Material time picker; the stored value stays within 0–1439 (later.md). |
| | VN copies reminder | Switch, new user setting (`copiesReminderEnabled`, default on). `BackgroundSync` sends no copies reminders while it is off. |
| Clips | Watched folders | Opens the Watched folders screen. Subtitle lists the watched folders' names, or "None". |
| | Storage used by VN copies | The existing screen; moves here from the interim group. |
| Help | Notifications not arriving? | Existing. |
| | Send error log | New (below). |
| Your data | Export and import | Opens the backup screen. Subtitle "Last backup: <date>" or "No backup yet". |
| Permissions | Video access | "All videos" with a tick; "Some videos only · Manual mode" with Allow all; "Not allowed" with Allow. Uses `MediaAccessController.allow`. |
| | Notifications | Existing row. |
| About | Your videos never leave your phone | The privacy line, no action. |
| | TakeTray | "Version 1.0.0" from the app's real version. |

New user settings (`stillReminderEnabled`, `copiesReminderEnabled`) join `SettingsRepository.exportedKeys` and the backup format. The backup schema stays at version 1: the three existing keys stay required, the two new ones are read leniently (missing → default), so an older backup restores their defaults. The builder confirms an older reader ignores the extra keys, and records it. `lastExport` is phone state (a backup made on this phone), not exported.

### Watched folders

The prototype's `routes.watched`: an info bar ("While Shooting mode is on, new videos saved in these folders go to To tag."), one row per video folder on the phone (icon, name, path, video count, switch), "Add a folder", and the pro-camera tip.
- The list comes from the existing folder listing (Add videos, Phase 7), which already hides `Movies/TakeTray/` and WhatsApp's Sent folders. Watched folders that no longer exist on the phone still show (so they can be turned off), marked as empty.
- Camera (`DCIM/Camera`) is on by default, as today.
- **Chat-app folders can be watched** (owner, 2026-11-15). Their rows say that clips from chat apps are dated by when they arrived and that busy groups and forwards also land in To tag. Which folders count as chat-app folders is decided by path, never by phone maker: a fixed list of path patterns (at least WhatsApp and WhatsApp Business media video folders, Telegram, Signal, Messenger, Snapchat) kept in one place with a test table; the builder writes the final list in `docs/decisions.md`.
- **Without full video access** the folder list cannot be read. The screen then shows the saved watched folders with their switches (so they can be turned off), a banner "Allow all videos to see your other folders" with Allow all (`MediaAccessController.allow`), and "Add a folder".
- "Add a folder" opens Android's folder picker (`ACTION_OPEN_DOCUMENT_TREE`) only to learn the folder's path; it keeps no grant (builder confirms this works for MediaStore relative paths; otherwise it lists folders as Add videos does).
- Turning a folder on does not pull in its older videos: like the camera today, only videos added after the change count (the scanner's baselines; builder confirms how a newly watched folder gets its baseline so its whole history does not flood To tag).
- Changing the list updates `BackgroundSync` (it already writes `watchedFolders`).

### Export and import

The prototype's `routes.backup`, using the existing `BackupService`.
- **Export:** `exportJson` → the document picker to save `taketray-backup-<date>.json` → writes it → records `lastExport` → snack "Backup saved".
- **Import:** a dialog first ("Import replaces everything in TakeTray now. Your videos are not touched."), then the document picker → decode and validate off the UI isolate → run the import on `MediaWorkQueue` (so no scan, verify or grant clean-up runs beside it) → `MediaVerifier.verifyAll` through `guarded` → a summary "X of Y clips found".
- **Phone state survives an import.** Today `BackupService._replaceAll` deletes every `settings` row, phone-state keys included. 10B changes it to replace only `SettingsRepository.exportedKeys` and keep every phone-state key (`onboardingDone`, `introPlayed`, `homeTipSeen`, `lastExport`, `notificationsAsked`, `folderTipSeen`, `mediaAccessWasFull` (later.md M-9), the volume versions and rematch windows), except two: `shootingMode` is removed (an import turns Shooting mode off, as today) and `copyJobPlan` is removed (the editing rows it refers to are gone). Tests pin each kept and each removed key.
- **Editing sessions** (later.md, Phase 8 final review M-6): the import is refused while a copy job is running (a `copyJobPlan` is saved): a dialog "Copying is still running. Try again when it finishes." and nothing changes. When VN copies exist, the confirm dialog adds that the copies stay on the phone and show on the VN copies screen to delete. The import itself never deletes files.
- A file that is not a TakeTray backup, or is newer than this app: an error dialog, nothing changed (the existing `BackupException`s).

### Send error log

A row under Help. It joins the rotating log files (`taketray-0.log`, `-1`, at most 2 × 512 KB) oldest first into one shareable file in the app's cache, and opens Android's share sheet through a `FileProvider` with a subject such as "TakeTray error log" and the app version and Android version in the text (nothing else about the phone). No log yet → a snack "Nothing to send yet". The user picks where it goes; TakeTray sends nothing itself.

### The rest of later.md's Phase 10 items

- A corrupt setting logs its warning once per key, not on every emission.
- Keep `Movies/TakeTray/` out of the watched-folder list (covered above).
- The disabled-on `TtSwitch` tick, `TtListRow` tall and disabled variants, the `.ib.tonal` icon button: built as the screens need them, with goldens.
- Parked items not listed here (automatic device-folder detection, a date shift for a wrong camera clock, folding the Still shooting? notification, a picked clip and its folder twin) stay parked; the plan says so.

### Checks for 10B

- Goldens for Settings (access full / Manual / denied; evening on / off; light, dark, 2× text), Watched folders, the backup screen, the dialogs.
- Unit tests: the new settings round-trip and export; `BackgroundSync` writes each switch; the import runs on the queue and keeps `mediaAccessWasFull`; the log join (order, empty, one file, two files).
- Robolectric: the share intent and `FileProvider` URI; the document picker intents.
- Patrol on the S24: turn the evening reminder off and back, change its time; watch a folder and see a new video in it reach To tag with Shooting mode on; export then import; send the error log to the share sheet (cancelled there).

## Left to the builder

- Route names, file layout, and widget split, following the existing feature folders (`features/onboarding/`, `features/settings/`).
- How the redirect avoids a wrong first frame.
- Image format and sizes for the welcome's take pictures and the splash wordmark.
- How a newly watched folder gets its baseline.
- Copy not given by the prototype (Send error log row text, snacks, dialogs), in the app's plain style, through l10n.
- Each call above marked "builder's call" goes in `docs/decisions.md`.
