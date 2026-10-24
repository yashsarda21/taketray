# TakeTray on iPhone: agreed plan (parked until Android is done)

> Status: **parked**. Decided 2026-10-24. Android ships first; pick this up when iOS work starts.
> Next step when resuming: write an iOS design add-on prompt (only what differs from Android), then build.

The app is Flutter, so screens, tagging, reels, references and the design carry over. Below is only what differs on iPhone.

## Decisions

| Area | iPhone version | Android version (for comparison) |
|---|---|---|
| **Sending clips to editors** | One **Photos album per reel**, inside a **"TakeTray" folder** in Photos. No copies. The same flow for CapCut, VN and Instagram Edits: "Open your editor and choose the London Food album." | CapCut/Edits: multi-share of originals. VN: temporary copy folder + "Done editing". |
| **When albums exist** | **Only while editing.** Created when the user taps **Edit** in a reel (with the clips they pick); removed when the reel is marked **Published**. Removing an album never deletes videos. | n/a |
| **Finding new clips** | When the app opens, using Photos' **persistent change history** (iOS 16+): everything added since Shooting mode was turned on goes to To tag. Fall back to a fetch by creation date if the change token expires. | Background content triggers + scan on open. |
| **"New clips" notification** | **Not automatic.** Optional: the user sets up a Shortcuts personal automation "App → Camera → Is Closed → Run Immediately" that runs a TakeTray App Intent (counts new clips, posts a local notification). TakeTray shows a setup guide in Settings and offers it once when Shooting mode is first turned on. Evening reminder for everyone (wording without a count: "Shooting mode is on. Tag today's clips?"). | Live notification (best effort) + evening reminder. |
| **Shooting mode** | In-app switch **plus** an iOS 18 Control Center / Lock Screen / Action button control (ControlWidgetToggle). | In-app switch. |
| **Open camera** | **Not possible** (apps can't open the Camera app). No "Open camera" button; suggest putting Apple's Camera control next to the TakeTray control. | "Open camera" button. |
| **iCloud "Optimize iPhone Storage"** | TakeTray never downloads for the editor flow (the editor downloads on import). Full-screen playback inside TakeTray shows download progress; add timeouts/retry/cancel (iCloud requests can stall). | n/a |
| **References from Instagram** | Share Extension: Instagram "Share to…" → TakeTray panel saves the link to the App Group ("Saved to London Food ✓") and closes; the app picks it up on next launch. Accept URL and text items. | Android share target. |
| **Permissions** | **Full Access required** (limited access can't create or see albums, and change history only covers selected items). Clear pre-prompt screen. Limited mode: explain, allow manual add via the limited picker; editor fallback = export copies + share sheet. Use `authorizationStatus(for: .readWrite)`; set `NSPhotoLibraryUsageDescription` and `PHPhotoLibraryPreventAutomaticLimitedAccessAlert`. | Full access; Manual mode with the system photo picker. |
| **Look** | Same TakeTray design, adapted to iPhone habits: edge-swipe back, iOS share sheet, safe areas (notch, home bar). | — |

## Confirmed by testing
- **VN, CapCut and Instagram Edits on iPhone all import from a specific Photos album** (a friend tested this, 2026-10-24). This was the main risk.

## Build notes
- **Flutter plugins:** `photo_manager` (albums, folders, add/remove without copying, delete album, change callbacks, limited picker, iCloud progress), `receive_sharing_intent` (Share Extension; needs an Xcode target and App Groups), `flutter_local_notifications`.
- **Native Swift needed:** persistent change history (method channel), the App Intent for the Shortcuts automation (runs without the Flutter engine; share state through App Group UserDefaults), the Control Center control.
- **Tools and costs:** Xcode needs about 30–40 GB of free disk; Apple Developer Program $99/year (TestFlight, App Store, installing on other people's iPhones).
- **App Review:** expect questions about full library access (guideline 5.1.1). Explain in the purpose string and review notes that auto-detection and albums need it. Mention where the Shortcuts feature lives.

## Testing
- **Simulator can test:** screens, permissions (incl. limited), adding test videos (`xcrun simctl addmedia booted *.mov`), change history, albums, local notifications, Share Extension from Safari, Control Center control (mostly). App Shortcuts are reported broken in some recent simulator runtimes (use an iOS 18.6 or 26.3 runtime).
- **Simulator can't test:** Instagram/CapCut/VN/Edits (no App Store), iCloud Optimize Storage, the Camera "Is Closed" automation, Action button, real performance.
- **Before release, on a borrowed iPhone:**
  1. Album handoff with iCloud-only clips in each editor (order, clip limits), and with an editor on limited access.
  2. Removing an album: any dialog? Videos stay?
  3. Camera "Is Closed" automation fires with no prompt (also after using the Lock Screen camera) and posts the notification within ~30 s.
  4. Instagram "Share to…" lists TakeTray; what item type arrives.
  5. Full-screen playback of an iCloud-only 4K clip on mobile data.
  6. Shooting mode control on Lock Screen and Action button.

## Risks still open
- Few users will set up the Shortcuts automation, so most iPhone users rely on opening the app and the evening reminder.
- Editors with only limited Photos access can't see TakeTray's albums (tell users to give the editor full access).
- iCloud downloads can be slow or stall.
