# TakeTray: Design Add-on 1 (rename + reference reels)

> **How to use this file:** give this document to the design session **together with the existing design** in `reel-helper/design/` (tokens, Compose theme, prototype). The original brief is `reel-helper/docs/design-prompt.md`; everything in it still applies unless this add-on changes it. **Update the existing design in place. Do not start over.** Keep the design system (colours, type, spacing, components) unless a change below needs something new.
>
> Published prototype to update (same URL): https://claude.ai/artifact/BbMuEuHNhBeoZHkFvDVQTL

This add-on has two changes:
1. The app is renamed from **Reel Helper** to **TakeTray**.
2. A new feature: saving **reference reels** (for example an Instagram reel you want to recreate) inside a reel.

---

## Change 1: Rename to TakeTray

**The name:** *TakeTray*. "Takes" is the film word for clips; the app is a tray where your takes collect, sorted by reel. One word, capital T twice: **TakeTray** **(fixed)**.

**Update everywhere:**
- App name on the splash screen, onboarding, Home, Settings → About, and every notification title.
- All copy that says "Reel Helper" (for example "Share to Reel Helper" becomes "Share to TakeTray").
- **The VN copy folder** becomes `Movies/TakeTray/<Reel name>`, including the VN instruction screens.
- **App icon:** new concepts that fit the name (a tray, stacked clips, a clapper "take"…). Provide the adaptive icon (foreground + background layers), the monochrome themed-icon version for Android 13+, and the notification small icon. Check it reads at 24 dp and 48 dp.
- **Handoff files:** rename the tokens file (`reel-helper.tokens.json` → `taketray.tokens.json`), the Compose theme identifiers (e.g. `ReelHelperTheme` → `TakeTrayTheme`), the build script references, the README and the prototype title. Regenerate the Compose theme so it still passes the existing contrast check.
- **Brand colours and font:** keep them unless the new icon genuinely needs an adjustment; if you change anything, note it in the decisions list.
- **The word "reel" stays** inside the app. Users still create reels; only the app's name changes.
- Optional: propose a short tagline. Current draft: *"Every clip you shoot, sorted into the right reel."*

---

## Change 2: Reference reels

### Why
Creators often see a reel on Instagram and think "I want to make something like this". Today that reel gets lost in their saved posts. TakeTray lets them **attach that reel to one of their own reels as a reference**, so while shooting they can re-watch it and remember which shots to take.

### Rules (fixed)
| Rule | Detail |
|---|---|
| **What a reference is** | A saved **link** (plus an optional short label the user writes, e.g. "Fast cuts, food close-ups"). |
| **How many** | A reel can have **zero or more** references; typically 1–3. |
| **Sources** | Mainly Instagram reels. Any link is accepted (YouTube Shorts, TikTok and others); each reference shows its source name ("Instagram", "YouTube", or "Link" for anything else). |
| **No downloading, no preview** | TakeTray **only stores the link**. It never downloads the video and doesn't fetch a thumbnail or title (Instagram doesn't allow other apps to do that). The reference card is therefore a designed card, not a video thumbnail. |
| **Opening** | Tapping a reference opens it in the Instagram app if installed (or the matching app for other sources), otherwise in the browser. |
| **Shot ideas** | The existing description / shot ideas field is where the user writes the shots they need. The reference section should nudge them to fill it ("Write the shots you need"). |
| **Branding** | You may show the source app's icon as provided by the phone, and the plain text "Instagram". Don't draw or imitate Instagram's logo or styling. |
| **Not needed** | Video permission is **not** needed to save a reference, so saving works even before onboarding is finished. |

### Flows

**A. Save from Instagram (main flow)**
1. In Instagram, on a reel: **Share → TakeTray** (TakeTray appears in Android's share list).
2. TakeTray opens a **Save reference** sheet over Instagram:
   - shows the link and its source ("Instagram reel"),
   - **New reel** (name field, required) **or** pick an **existing reel** (list, Recording reels first),
   - optional label,
   - **Save**.
3. Confirmation: "Saved to London Food" with **Open reel** and **Done** (Done returns the user to Instagram).

**B. Add manually**
- In reel detail: **Add reference** → paste a link (if the clipboard holds a link, offer it: "Paste link from clipboard?") → optional label → Save.
- In Create / edit reel: an optional **Reference link** field.

**C. Use and manage**
- Reel detail shows a **References** section near the top (above the clips): one card per reference with source, label (or the link if no label) and an **Open** action.
- Card menu: **Edit label**, **Copy link**, **Remove** (Undo snackbar; no confirmation dialog needed).
- When a reel has references but an empty shot ideas field, show a gentle prompt to write the shots.

**D. Quick access while shooting (fixed)**
- The **Shooting mode card** on Home gets a **References** entry (e.g. "References · 4") when Shooting mode is on and any **Recording** reel has references.
- It opens a **References sheet** listing references from **all Recording reels, grouped by reel**, each with its shot ideas visible (collapsible). Tap a reference to open it; tap the reel name to go to the reel.
- This does **not** introduce a "currently shooting for" reel; it simply shows every Recording reel. No pinning.
- The small reference indicator on a Home reel card is tappable and jumps to that reel's References section.

### Edge cases to design
- The shared text isn't a link → explain and don't save.
- The same link is already saved in that reel → "Already saved in London Food".
- No reels exist yet → the sheet goes straight to **New reel**.
- Shared into TakeTray on first launch, before onboarding → save the reference and reel first. On the confirmation, **Done** returns to Instagram (onboarding waits until the user next opens TakeTray); **Open reel** runs onboarding first, then lands on the reel. The new reel already appears in the onboarding "Create your reels" list.
- Link is an Instagram post or profile rather than a reel → accept it as "Instagram".
- The source app isn't installed → opens in the browser (no error).
- Very long labels or links → truncate gracefully.

### Screens to add
1. **Save reference sheet** (from the share list). States: choose new reel; choose existing reel; no reels exist; not a link; already saved; saved confirmation.
2. **Add / edit reference sheet** (paste link + label). States: empty; clipboard link offered; invalid link; editing an existing label.
3. **References sheet from the Shooting mode card** (flow D). States: one reel with references; several reels; a reel with references but no shot ideas.

### Screens to update
1. **Reel detail:** References section with states: none (small "Add reference" entry, not a big empty block), one reference, several references; the shot-ideas prompt.
2. **Create / edit reel:** optional Reference link field.
3. **Home reel card:** a small, tappable indicator when a reel has references (e.g. an icon with a count). Keep it subtle.
4. **Shooting mode card:** the References entry (flow D).
4. **Empty reel state:** mention that you can share a reel from Instagram as a reference.
5. **Onboarding "Create your reels":** a one-line tip: "Tip: share any Instagram reel to TakeTray to save it as a reference."
6. **Navigation map:** add the share-sheet entry point into TakeTray.

### Out of scope (don't design)
- Automatic shot lists from a reference (AI). Possible later.
- Downloading or playing reference videos inside TakeTray.
- Copying a reference's editing style or music (Instagram's "Use template" and CapCut templates already do this).

---

## Deliverables
1. All screens updated with the new name, plus the new and updated screens above, each with every listed state, at 360 dp, light and dark.
2. New **app icon** set for TakeTray (adaptive, monochrome, notification icon).
3. Renamed and regenerated **tokens file and Compose theme**, still passing the contrast check.
4. A clickable prototype flow for **"Save a reference from Instagram"** (flow A), added to the existing prototype hub.
5. The published prototype updated **at the same URL**.
6. An updated **decisions and questions** list.
