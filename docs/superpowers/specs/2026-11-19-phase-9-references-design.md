# Phase 9: References (design)

Date: 2026-11-19 · Owner-approved choices in conversation (brainstorming, 2026-11-19) · Builds on the v1 build design (`docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`, phase table row 9 and the decisions table), design add-on 1 (`docs/design-prompt-addon-1.md`, Change 2), the prototype (`design/prototype/assets/refs.js`; `screens.js`: `ob-reels`, `sheets.reelForm`; `app.js`: the `reference` and `reference-first` flows) and the Phase 9 items in `docs/later.md`.

## Intent

A creator sees a reel on Instagram and thinks "I want to make something like this". Today that reel gets lost among their saved posts. After Phase 9 they tap **Share → TakeTray** in Instagram, pick one of their reels (or name a new one), and the link is saved there. Later, on the reel page or from the Shooting mode card while they are out filming, they re-watch it and remember which shots to take.

The data side already exists (Phase 2): `ReferencesRepository` saves, labels, deletes and watches links, `normalizeReferenceUrl` cleans them so the same reel shared twice is one reference (D-55, D-58), backups carry them, and `taketray_ui` has `TtReferenceCard`, the reel card's references badge and the Shooting mode card's link row. Phase 9 builds the screens and the share entry on top.

**Split.** Two branches, one after the other, each with its own plan, reviews, PR and S24 check (as Phase 10):
- **9A, references in the app:** the References section on the reel page, the Add / edit reference sheet, the reference card's menu, opening a reference, the reel form's link field, the Home card badge, and the Shooting mode References row and sheet.
- **9B, sharing in:** the share entry (a see-through share screen over the sharing app), the Save reference sheet with all its states, saving before onboarding, the onboarding changes, and the "Open reel" hand-off into the app.

9A merges before 9B starts. (Order is my call: 9B's "Open reel" lands on the reel page, so the References section should already be there when the owner checks 9B on the phone. The owner heard the parts as "9A sharing in, 9B inside the app"; only the order changed.)

## Goals

- Sharing an Instagram reel saves it (the build design's "done when" for Phase 9), on the S24, including on a fresh install before onboarding.
- Every screen and state in add-on 1's "Screens to add" and "Screens to update", at 360 dp and up, light and dark, matching the prototype.
- A reference opens in its app when installed (Instagram, YouTube, TikTok), otherwise in the browser, with no error.
- The Phase 9 items in `docs/later.md` are done or dropped with a reason.

## Non-goals

- Fetching anything about a link: no thumbnail, title, preview or download (add-on 1; the release build has no `INTERNET`).
- Automatic shot lists, playing reference videos inside TakeTray, copying a reference's style or music (add-on 1 "Out of scope").
- A "currently shooting for" reel or pinning (add-on 1 flow D).
- Sharing videos or images into TakeTray. Only text (a link) is accepted.

## Anti-goals

- The share must never leave the user stranded in TakeTray: Done and Cancel go back to the app they shared from, at the same place.
- A share must never disturb what is open in TakeTray (a half-tagged clip, an open sheet).
- No surprise clipboard reads: TakeTray reads the clipboard only when the user taps Paste (owner's choice, below).
- Logs never contain a link, a label, shared text or a reel name (D-10). Ids and counts only.
- No new permissions; the release permission check stays "RELEASE PERMISSIONS OK". No third-party Android plugins.
- Never draw or imitate Instagram's (or any source's) logo.

## Constraints

- Stack as today: Flutter through `tool/flutter`, Riverpod 3 codegen, Drift (schema v2; the `reel_references` table already exists, so no migration is expected), go_router, freezed, Pigeon; Kotlin uses Android platform APIs only.
- Strict TDD with mutation checks; goldens light and dark; Patrol flows written and reviewed before the phone is used; the phone is the very last step; `docs/decisions.md` and `docs/flow.md` updated with the code; a learning guide per part (`docs/learn/phase-9a-…md`, `phase-9b-…md`); README progress at the end.
- Copy uses the app's status names: the prototype's "Recording" is **Collecting** everywhere (D-80).
- Text limits as today: reel name 40, reference label 60 (`text_limits.dart`).

## Approaches (decided)

1. **How the share opens** (owner picked 1).
   - **1. A separate see-through share screen (chosen).** A new `ShareActivity` takes Android's share intent and runs its own Flutter engine with a small share-only app. The sheet floats over the sharing app; Done finishes the activity and the user is back where they were. TakeTray's own screen, if it is open, is never touched. Costs: a second engine while the sheet is open; the database connection becomes shared between engines (below); the error log must be safe with two writers.
   - 2. MainActivity takes the share and shows the sheet over the whole app. Rejected: the app jumps up behind the sheet instead of Instagram, whatever screen was open is covered, Done relies on sending the task back, and first launch would have to slip past the onboarding redirect.
   - 3. One engine shared by both activities (`FlutterEngineCache`). Rejected: an engine attaches to one activity at a time, so TakeTray open in the background would be torn down by a share.
2. **The clipboard in Add reference** (owner picked A).
   - **A. A Paste button (chosen).** The Link field has a Paste action; the clipboard is read only on that tap, so Android 12+'s "TakeTray pasted from your clipboard" message only ever follows the user's own tap. It cannot show which link is waiting.
   - B. The prototype's "Paste link from clipboard?" card, which shows the link on open. Rejected: Android's paste message would appear every time the sheet opens.
   - C. No offer. Rejected: one tap is worth having.

## 9A: references in the app

### Reel page: the References section

Under the description / shot ideas, above the clips (`h.refsSection`). Replaces the "Not built: References (Phase 9)" gap in `reel_detail_screen.dart` (D-80).
- **No references:** one compact "Add reference" row ("Save a reel you want to recreate"), not an empty block.
- **One or more:** a header "References · N" with an **Add** text button, then one `TtReferenceCard` per reference, newest first (`watchForReel`'s order).
- **Shot-ideas prompt:** when the reel has references and an empty description, a callout under the cards: "Write the shots you need" / "Watch your references, then list the shots to get while you're out." with **Write shot ideas**, which opens the reel form with the description focused.
- Arriving from the Home badge or the References sheet scrolls the section into view and flashes it once (the prototype's `focus: 'refs'`); with "Remove animations" on, no flash.

### The reference card

`TtReferenceCard` as built in Phase 1. Title: the label, or the short link (no scheme, `www.`/`m.`, query or trailing slash) when there is none. Subtitle: "{source label} · {short link}" with a label, otherwise the source label. Source labels from the link (`RH.src`): "Instagram reel" / "Instagram post" / "Instagram video" / "Instagram profile", "YouTube Short" / "YouTube video", "TikTok video", and the host for anything else. The stored `ReferenceSource` stays the four-value enum; the finer label is derived from the URL for display only.

**Source icon:** the source app's own launcher icon as the phone supplies it, when that app is installed; otherwise the generic link symbol. This needs a Pigeon call returning an app's icon as PNG bytes, and `<queries>` entries for the source apps' packages: `com.instagram.android`, `com.google.android.youtube`, `com.zhiliaoapp.musically` and `com.ss.android.ugc.trill` (TikTok's two). The `<queries>` comment and the tests that check it are updated to name them. The icon is rendered at 48 px, cached in memory per package for the app's life, and a failed or missing lookup silently shows the link symbol. (My call: add-on 1 allows the phone-supplied icon, and the prototype shows one. Cost if wrong: drop the call and the queries; the link symbol remains.)

**The card's main tap opens the reference** (below). **More** (⋮) opens a menu:
- **Edit label:** the Add / edit sheet in edit mode.
- **Copy link:** puts the stored link on the clipboard; a "Link copied" snack on Android 12 and lower only (Android 13+ shows its own confirmation).
- **Remove:** deletes at once, "Reference removed" snack with **Undo** (no dialog). Undo puts it back with its label and its original time, so it keeps its place in the list. This needs a new `ReferencesRepository` restore method (my call); Undo also puts back the reel's previous `updatedAt`, so Home's order is as it was before the remove, the same rule as the app's other Undos.

**The later.md item:** the card's "Open" mark takes half the row at 2× text. At large text the Open mark shrinks to its icon (or moves under the title); check at 2× with a golden and on the S24.

### Opening a reference

An `ACTION_VIEW` intent with the stored link, through Pigeon. Android routes Instagram, YouTube and TikTok links to their apps when installed (their verified app links) and otherwise to the browser. No `<queries>` are needed for this. If nothing at all can open it, a snack: "No app on this phone can open this link." Nothing else is shown.

### Add / edit reference sheet

Opened from the section's Add row or Add button.
- **Add:** title "Add reference", subtitle "to {reel name}". A **Link** field (help "Instagram, YouTube or any other link") with a **Paste** action (approach 2A), then **Label (optional)** with a 60-character counter, **Cancel** and **Save**.
  - Paste reads the clipboard's text and puts the first http(s) link in it into the field (the same extraction as the share, below), then moves focus to Label. If the clipboard holds no link, the field shows "There's no link on your clipboard." and nothing is pasted.
  - Save with no link in the field: the field error "That isn't a link. In Instagram: Share › Copy link, then paste it here." A link already on this reel: "Already saved in {reel name}". Otherwise it saves, closes, and shows "Reference saved" with **Undo**.
- **Edit label:** title "Edit label", subtitle the reel name; the source row (icon, source label, short link) instead of the Link field; the Label field prefilled. Save stores the label (blank clears it) and shows "Label saved".
- The link typed in the field may contain text around it: the first http(s) link is taken, as for shares.

### Reel form: the Reference link field

`showReelForm` (create and edit) gets an optional **Reference link** field under the description, not shown when the form is opened from the tag player (as the prototype). Help text: "A reel you want to recreate. You can add more later." on create; on edit of a reel with references, "{N} references saved. Add another, or manage them on the reel."
- A filled field must hold a link, or the form shows the field error above and saves nothing.
- On Save the reel is created or updated, then the link is added. An already-saved link on edit is not an error (nothing more to do). The reel and its first reference are saved in one transaction on create, so a failure saves neither.

### Home reel card badge

`TtReelCard.referenceCount` from `ReferencesRepository.watchCounts()`. The badge is its own button ("{N} references, open them"); its tap opens the reel page at the References section.

### Shooting mode: the References row and sheet

- **The row:** in the Shooting mode card's rows slot, first (before Add earlier videos, D-79): "References · N", where N counts the references of every **Collecting** and **Ready to edit** reel. Shown only while Shooting mode is on and N > 0. (Add-on 1 says "Recording reels"; the build design's decisions table, which is later and binding, says "Collecting reels first, then Ready to edit reels". This design follows the build design.)
- **The sheet** ("References", "From your Collecting and Ready to edit reels, with their shot ideas"): one group per reel that has references, Collecting reels first, then Ready to edit, each in Home's order. A group header shows the reel's cover and name (tap: close the sheet, open the reel at its References section) and a collapse toggle; groups start open. Under it, the shot ideas ("Shot ideas" and the description) or, when empty, "No shot ideas yet." with **Write the shots you need** (opens the reel form on that reel with the description focused). Then the reference cards, without the ⋮ menu; a tap opens the reference.
- The sheet updates live if a reference or reel changes while it is open; if no group is left, it shows "No references in your Collecting or Ready to edit reels." Collapsed groups are not remembered after the sheet closes.

### Empty reel state

The empty reel page's text gains a line: "You can also share a reel from Instagram to TakeTray to save it as a reference." (add-on 1 "Screens to update" 4).

## 9B: sharing in

### The share entry

- **`ShareActivity`** (Kotlin, `FlutterActivity` subclass): exported, one intent filter for `android.intent.action.SEND` with `text/plain`, a translucent theme, a transparent Flutter background, `excludeFromRecents`, and opened in the sharing app's task so Back and Done return to it. Its label in Android's share list is "TakeTray". It runs a separate Dart entry point (`shareMain`, `@pragma('vm:entry-point')`) with a share-only widget tree: the Save reference sheet over a dimmed transparent background. No splash, no onboarding redirect, no background sync, no media scanning.
- **What it reads:** `Intent.EXTRA_TEXT` only, once, through a Pigeon call. Any other content (streams, images) is not accepted; the manifest filter is text only.
- **Link extraction** (`docs/later.md`): the first `http://` or `https://` link in the shared text, trailing `).,!` stripped, then `normalizeReferenceUrl`. TikTok's and YouTube's "Title https://…" share text works. No link → the "not a link" state.
- **Closing:** Done, Cancel, Close, Back and a tap on the dim background all finish the activity. A finished share leaves nothing behind in Recents.
- **Open reel** finishes the share activity and starts MainActivity with a new allow-listed launch action, `openReel` with the reel id (`LaunchActions.kt` and `LaunchAction` in Dart gain the value; the id is checked in Kotlin and in Dart as for `doneEditing`). The app comes up and opens that reel's page at its References section. It replaces whatever TakeTray had open, as `doneEditing` does (my call: the user asked to go to the reel; tags are saved as they are made, so nothing is lost). The anti-goal about not disturbing TakeTray covers Save, Done and Cancel, which never touch it.
- **Link rule (my call):** a share needs an `http://` or `https://` link (Instagram, YouTube and TikTok always share one). The typed Link field in 9A is kinder: text with no spaces and no scheme gets `https://` put in front before `normalizeReferenceUrl`, so a hand-typed `instagram.com/reel/abc` works. Pasted text is treated as a share (the first http(s) link in it).

### Sharing the database and the log between two engines

- **Database:** both engines open the database through `driftDatabase(name: 'taketray', native: DriftNativeOptions(shareAcrossIsolates: true))` (drift_flutter 0.3.1 supports it), so they talk to one drift server in the process and each one's watch streams see the other's writes: a reel saved from the share appears on Home at once if TakeTray is open behind.
- **Prove it first (my call).** 9B's first task is a spike on an emulator, not the S24 (the phone stays the last step): two real engines in one process, the share engine writes, the app engine's watch stream sees it, and the database keeps working after either engine is destroyed first (the share finishing while the app stays open, and the app closed while a share is open). `IsolateNameServer` is process-wide, but whether the server isolate outlives the engine that spawned it is exactly what the spike answers.
- **Fallback if the spike fails (my call):** each engine opens its own ordinary connection to the same file (SQLite in WAL mode, with a busy timeout, already safe for two connections in one process). The share engine only writes. The app, when it returns to the front, tells drift that the reels and references tables changed (`notifyUpdates`), so its streams re-read. The cost: a reel saved from a share appears in an open TakeTray when it comes back to the front, not while it sits behind the share, which is the same thing to the user.
- **Log:** the share engine must not race the app's `LogFileSink` rotation. My call: the share engine writes its own rotating file set in the same directory (e.g. `share-0.log`, `share-1.log`, smaller cap), and Send error log bundles both. Cost if wrong: one more file in the bundle.

### The Save reference sheet

States from the prototype (`sheets.saveRef`):
- **Form.** Title "Save reference". A source row: the source app's icon (9A's call), the source label ("Instagram reel"), the short link. **Label (optional)** with a 60 counter. "Save to" with a two-way switch **Existing reel** / **New reel**:
  - **Existing reel:** a radio list of reels under "Collecting", then "Other reels" (Ready to edit and Published), each with its cover and its references count. Nothing is picked at first; Save is disabled until a reel is picked.
  - **New reel:** a "New reel name" field (40 counter, "For example: London Food") with the existing reel-name rules (empty, too long, duplicate: "You already have a reel called {name}").
  - **No reels exist:** the switch is hidden and the sheet opens in New reel with the name field focused.
  - **Already saved** (the picked reel already has this link, by the normalised URL): a warning banner "Already saved in {reel}" / "Pick another reel, or open this one." with **Open reel**; Save is disabled. (The later.md item "the banner margin is not configurable" is settled here: the banner component takes the margin the sheet needs.)
  - **Cancel** and **Save**. Enter in the name or label field saves.
- **Not a link.** "This isn't a link" / "TakeTray saves links to reels and videos. This looks like a caption:", the shared text quoted (clamped), "In Instagram, tap Share on the reel itself, then choose TakeTray. Nothing was saved." and **Close**.
- **Saved.** A check, "Saved to {reel}", the label or the source label, **Open reel** and **Done**. On a share before onboarding is done, a callout: "Welcome to TakeTray" / "Next time you open the app, it takes about a minute to set up the rest."
- A save failure the user cannot fix shows "Couldn't save the reference." in the sheet and keeps the form.
- Saving with **New reel** creates the reel and its reference in one transaction (a new repository method, shared with 9A's reel-form create path). The new reel is Collecting, as every new reel. Saving to an existing reel moves it to the top of Home (`add` already touches `updatedAt`, D-58).

### Saving before onboarding

Video access is not needed to save a reference (add-on 1), so the share works on a fresh install that was never opened.
- The share engine never changes the onboarding flags. **Done** returns to the sharing app; the next time the user opens TakeTray, onboarding runs from the welcome (intro included).
- **Open reel** before onboarding is done: the app runs onboarding first, and when it finishes it opens the reel. This amends Phase 10A's "launch actions during onboarding are dropped": an `openReel` action that arrives while onboarding is not done is held in memory and applied once onboarding finishes. Other launch actions are still dropped. A held action is lost if the app is killed before onboarding finishes (the reel itself is saved).
- **Onboarding's reels step** lists the reels that already exist above the typed names, each with a check ("Already created") and "{N} references saved" under its name, not removable. With such reels and nothing typed, the button is "Continue" (already the behaviour for existing reels, D-141). This shows every existing reel, not only ones made by a share (my call: on a fresh install every existing reel came from a share; an install with reels that comes back to this step after a kill already treats them as existing).
- **The onboarding tip** under the reels list: "Tip: share any Instagram reel to TakeTray to save it as a reference." (hidden since Phase 10, D-141).

## Testing

- **Unit:** link extraction from share text (TikTok/YouTube "Title https://…", trailing punctuation, several links → the first, none, `www.` without a scheme → none in a share, accepted in the typed field), the derived source labels, the Collecting/Ready to edit grouping and count, the held `openReel` launch action, the create-with-reference transaction (a failing reference saves no reel).
- **Widget and golden:** every state above, light and dark, at 360 dp; the card at 2× text; the section's three states; the sheets' every state; the onboarding reels step with existing reels.
- **Two engines:** a test that a write through one shared-isolate connection reaches the other's watch stream.
- **Patrol (written before the phone):** 9A: add, edit label, remove + Undo, open from the Home badge, the Shooting mode sheet. 9B: start `ShareActivity` with a `SEND` intent carrying test text (no real Instagram needed), save to an existing reel, save to a new reel, the not-a-link state, and the before-onboarding path through Open reel. The intent is fired from the test harness side (adb or instrumentation); nothing test-only goes into the release manifest or release code (my call).
- **By hand on the S24 (the owner):** a real share from Instagram, from YouTube and from TikTok if installed; Done returns to the sharing app at the same reel; opening a reference with Instagram installed; Paste and Android's paste message; TalkBack on the section and the sheets.

## Left to the builder

- Widget structure, file layout, provider shapes, Pigeon API names.
- The exact way the Open mark adapts at 2×.
- The share sheet's motion (it enters as the app's other sheets do).
- How the share entry point builds its theme and l10n (it must match the app's).
