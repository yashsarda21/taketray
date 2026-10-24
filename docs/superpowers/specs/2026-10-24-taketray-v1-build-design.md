# TakeTray v1: Build Design (Android, Flutter)

Status: draft for approval · 2026-10-24
Owner: the developer (product owner). Implementation: Sonnet subagents. Orchestration and review: Claude (Opus), with Opus review subagents.

---

## 1. Intent

Build **TakeTray version 1** as a complete, Play Store–ready Android app that looks and behaves exactly like the approved design, built to an enterprise standard: clear architecture, a reusable design system, tests at every layer, and phased delivery where each phase is finished and reviewed before the next starts.

**What the app does (one paragraph):** creators turn on **Shooting mode** and film with their normal camera. Every new video lands in **To tag**. In spare moments they watch each clip and tag it into one or more **reels** (projects like "London Food"), or skip it. At edit time they pick a reel's clips and send them to **CapCut** or **Instagram Edits** (originals, shared directly) or **VN** (temporary copies in a folder). Reels can hold **reference links** (e.g. an Instagram reel shared into TakeTray). Original videos are never modified, moved or deleted.

## 2. Sources of truth (product)

In order of precedence (a later item yields to an earlier one):
1. **This document** (including the overrides in §3).
2. The **design hub decisions**: `reel-helper/design/prototype/index.html` → "Decisions and questions", and the chosen options recorded in `reel-helper/design/README.md`.
3. `reel-helper/docs/design-prompt-addon-1.md` (rename to TakeTray, reference reels).
4. `reel-helper/docs/design-prompt.md` (the full v1 brief: flows §6, screens §7, rules §5).

**Visual source of truth:** the prototype in `reel-helper/design/prototype/` (screens 1–37 with every state, light and dark, in the **custom TakeTray style**, `assets/tt-style.css`), plus the tokens in `reel-helper/design/tokens/taketray.tokens.json`. The final app must match the prototype screen for screen and state for state.

## 3. Decisions made in brainstorming (override the sources above)

| Topic | Decision |
|---|---|
| Goal | Complete v1 for the Play Store. Not tied to a trip date. Quality over speed. |
| Existing code (`reel-helper/app`) | Keep the **look** (generated tokens, TakeTray-style widgets, screen layouts as reference). **Rebuild the internals**: the current app is a prototype on sample data with a single global state class. |
| Privacy | **Fully offline.** No analytics, no crash reporting, no network calls. The **release build has no `INTERNET` permission** (removed in the main manifest; debug/profile keep it for tooling). Play data-safety: "No data collected". |
| Bug reports | A **local error log** (rotating file in app storage, no video names or paths in log lines) that the user can send from Settings via the Android share sheet. |
| Money | v1 is **free, no payments**. Code must not make adding Play Billing later hard, but nothing billing-related is built now. |
| Status names | **Collecting** (was "Recording"), **Ready to edit**, **Published**. New reels start as Collecting. |
| App icon | The **tray** concept (`reel-helper/design/handoff/icons/tray/`). |
| Tagline | "Shoot now. Sort later." |
| References sheet (from Shooting mode card) | Collecting reels first, then Ready to edit reels. |
| Reference label | Max 60 characters. |
| "Pick several" in the tag player | **Sticky**: stays on between clips until turned off. |
| Published reels in the tag player | Folded under "Other reels" by default. |
| Evening reminder | 9 pm by default; fires when **≥ 1** clip is waiting. |
| CapCut | Shown whenever installed (no country logic). |
| VN folder name clash | Second folder gets " (2)", then " (3)"… |
| "New clips" notification | Android's standard **BigPictureStyle** on all brands; no custom layouts. |
| Version control | **Local git** now. GitHub (and CI there) after phase 2. Until then, the same checks run locally via a script. |
| Test device | The owner's **Samsung Galaxy S24 Ultra** stays connected over USB (adb) during phases; build agents may install builds and run Patrol tests on it themselves. `adb` isn't on PATH, so scripts call it through `tool/adb` (Android SDK platform-tools). Emulators (API 30, 33, 34+) are set up by the builder in phase 0. Owner checks are still done at each phase end. |
| Play Store | The owner owns the Play Console account, the release signing key and the privacy-policy page. **Details are decided when needed** (CI design after phase 2; release in phase 11). Until then: never commit keystores or secrets. |
| Platform | Android only. Minimum **Android 11 (API 30)**. Package `app.taketray`. iOS is parked (`docs/ios-plan.md`); avoid Android-only assumptions in Dart domain code where it costs nothing. |

## 4. Goals, non-goals, anti-goals

**Goals**
- Pixel-faithful to the prototype, light and dark, at 360 dp and up.
- Tagging is fast and smooth (the core loop).
- Reliable: no lost tags, no wrong clips shown, no crashes on permission changes or deleted media.
- A design system that makes inconsistent UI hard to write.
- Every phase ends shippable-quality for its scope, with tests and a review.

**Non-goals (v1)** — same as `design-prompt.md` §4 "Not in version 1": photos, iOS, search, pinning, collections, archive, custom covers, renaming clips, manual reordering, best-take stars, notes lists, missing-clip recovery, VN "Save space" mode, cloud, accounts, payments, ads, widgets.

**Anti-goals (failure even if it "works")**
- Any data leaving the phone.
- Any change to the user's original videos.
- Noisy notifications (sound or vibration after the first, duplicates).
- Feature code with hand-picked colours, sizes or text styles.
- A clip in a reel pointing to the **wrong** video.

## 5. Tech stack (builder's calls, approved by the owner)

| Concern | Choice |
|---|---|
| Flutter | 3.47.7 (installed at `~/development/flutter`; the `flutter` on PATH is an old 2.8.1, so all scripts call the pinned SDK via `tool/flutter`). Dart 3.13+. |
| Architecture | Flutter's recommended app architecture: **feature-first** folders, each with UI (views + view models) and data (repositories + services). Domain models shared. |
| State + DI | **Riverpod** (with code generation). View models are Notifiers; repositories and services are providers, overridable in tests. |
| Database | **Drift** (SQLite), with versioned migrations and migration tests. |
| Models / JSON | **freezed** + **json_serializable** (domain models, export/import format). |
| Navigation | **go_router** (deep links from notifications and share intents). |
| Native Android | **Kotlin**, exposed to Dart through **Pigeon** (type-safe host/Flutter APIs). |
| Background work | Native **JobScheduler** content-URI trigger + **WorkManager** for scheduled reminders. Background code runs **without** a Flutter engine. |
| Video playback | **video_player** (ExoPlayer on Android). |
| Thumbnails | Native `ContentResolver.loadThumbnail`, cached in memory + disk cache in app storage. |
| Strings | `flutter gen-l10n`, English ARB; no user-facing string literals in widgets. |
| Logging | `logging` package → rotating file sink (2 × 512 KB). |
| Lints | **very_good_analysis** (strict) plus a project check that forbids raw styling in feature code (§7). |
| Tests | `flutter_test` (unit, widget), **alchemist** (golden tests), Drift in-memory DBs, fakes for the native bridge, **Patrol** (on-device integration tests incl. system permission dialogs). |
| Component catalogue | **Widgetbook** app showing every design-system component and state. |
| Fonts / icons | Plus Jakarta Sans bundled; Material Symbols bundled (no network). |

## 6. Repository layout (pub workspace)

```
reel-helper/                      (git root)
  pubspec.yaml                    (workspace root)
  app/                            the TakeTray app
    lib/
      main.dart, app.dart         bootstrap, ProviderScope, router, theme
      core/                       logging, errors, result types, clock, l10n
      data/                       Drift database, DAOs, migrations
      platform/                   Pigeon-generated APIs + Dart wrappers (media, background, editors, share)
      domain/                     models (freezed) and pure logic (scenes, fingerprint, ordering)
      features/
        onboarding/ home/ reels/ tagging/ clips/ add_videos/
        editors/ references/ settings/ shooting_mode/
          (each: data/, view_models/, views/, widgets/)
    android/app/src/main/kotlin/app/taketray/...  (media, background, editors, share)
    test/  integration_test/ (Patrol)
  packages/
    taketray_ui/                  the design system package (tokens, theme, components)
  widgetbook/                     component catalogue app
  tool/                           flutter wrapper, check scripts, token sync
  design/  docs/  marketing/      (existing)
```

The current `app/lib` prototype code is ported, not deleted wholesale: its widgets move into `taketray_ui` (refactored to the rules in §7); its screens serve as layout references; sample data becomes a debug-only seed and Widgetbook fixtures.

## 7. Design system

- **Tokens:** `design/tools/build_tokens.py` stays the single source. It already generates Dart (`tokens.g.dart`); its output moves into `packages/taketray_ui/lib/src/tokens/`. Generated files are never edited by hand.
- **Theme:** one `TakeTrayTheme` building `ThemeData` (light, dark) from the shipped brand (Graphite & marigold), plus `ThemeExtension`s for what Material doesn't cover: spacing scale, radii, motion durations/curves, elevation/glass effects, and extended colours (marigold "clips waiting", REC red, success green, video-surface black).
- **Access:** a `BuildContext` extension (e.g. `context.tt.spacing.m`, `context.tt.colors.waiting`) so feature code never touches raw values.
- **Components** (in `taketray_ui`, each with every state from the prototype): buttons (primary, secondary, text, icon), glass pill, floating nav pill with badge, pill tabs / status filter, status pill, reel chip (tap / sticky multi-select), clip tile (thumbnail, duration, time, "in N reels", selected, missing, in VN folder), scene header, reel card, Shooting mode card, reference card, floating sheet, dialogs, snackbar with Undo, empty states, permission banner, progress (copy/download), section/grouped rows, text fields, the tag player chrome, the video surface.
- **Rules (enforced):**
  1. Feature code (`app/lib/features/**`) may not create `Color(...)`, `TextStyle(...)` with explicit sizes, numeric `EdgeInsets`/`SizedBox` dimensions, `BorderRadius.circular(<number>)` or `Duration` literals for animation. A script in `tool/check_styles.dart` fails the build on violations (with an allow-list comment for justified exceptions).
  2. Every component has golden tests for each state in light and dark, at 1.0× and 2.0× text scale.
  3. Every component appears in Widgetbook with knobs for its states.
- **Accessibility:** 48 dp minimum touch targets, AA contrast (already enforced by the token build), semantics labels on icon buttons, no meaning by colour alone, text scaling to 200%, reduced motion respected.

## 8. Core technical design

### 8.1 Data model (Drift)
- `reels`: id, name (≤ 40), description (nullable), status (collecting/ready/published), createdAt, updatedAt.
- `clips`: id, source (`mediaStore` | `picker`), mediaStoreId + volumeName (or picker URI), fingerprint (sizeBytes, durationMs, dateTakenUtc, displayName), width, height, mimeType, **timeZoneId** (IANA, e.g. `Europe/London`, for "time where it was shot", see §8.3a), generationAdded, firstSeenAt, missing flag, lastVerifiedAt.
- `clip_reels`: (clipId, reelId) primary key, addedAt. A clip may be in many reels.
- `inbox`: clipId (PK), state (`pending` | `skipped`), addedAt. Tagging removes the row; Skip sets `skipped`; Restore sets `pending`.
- `references`: id, reelId, url, source (instagram/youtube/tiktok/link), label (≤ 60), createdAt; unique (reelId, url).
- `vn_sessions`: reelId (PK), folderName, createdAt; `vn_copies`: (reelId, clipId), copyMediaStoreId, fileName, sizeBytes.
- `settings`: key/value for Dart-only settings.
- A clip that leaves its last reel (and isn't in the inbox) is deleted from `clips`. Deleting a reel cascades its `clip_reels`, references and VN session (copies deleted first).

### 8.2 Native bridge (Pigeon APIs, Kotlin)
- **MediaApi:** permission state (full / limited / denied, per Android version), request permissions, query videos (by generation, by folder, by IDs), MediaStore version/generation per volume, folders with video counts, thumbnails, verify existence, open system photo picker (Manual mode; persist URI grants).
- **BackgroundApi:** enable/disable new-clip watching, write the small "background state" the native side needs (shooting mode on/off, baseline generations, watched folders, pending count), schedule/cancel reminders (evening, 14-day, VN 3-day).
- **EditorsApi:** installed editors (CapCut `com.lemon.lvoverseas`, Edits `com.instagram.basel`, VN `com.frontrow.vlog`; `<queries>` in the manifest), send originals (`ACTION_SEND_MULTIPLE`, explicit package, ordered by shooting time, read-URI grants), VN copy session (space check via StatFs, copy into `Movies/TakeTray/<Reel>` with `IS_PENDING`, progress stream, cancel, delete own copies), generic share sheet.
- **ShareInApi:** delivers shared text/links (from `ACTION_SEND text/plain`) to Dart; "Done" returns the user to the sharing app (finish the task).
- All long operations report progress through a Pigeon Flutter API or event stream, and are cancellable.

### 8.3 New-clip detection
- **Shooting mode on:** record, per external volume, `MediaStore.getVersion()` and `getGeneration()` as the baseline, plus the start time.
- **Scan** (on app start, on resume, and when the user opens To tag): query videos with `GENERATION_ADDED > baseline`, `IS_PENDING = 0`, `DURATION > 0`, in watched folders (default: the camera folder(s), `DCIM/Camera`, editable in Settings). Insert into `clips` + `inbox(pending)`; advance the baseline. All DB writes happen in Dart.
- **Version change** (media DB rebuilt, restore): never treat everything as new. Re-match existing clips by fingerprint; unmatched clips become missing; new baseline from now.
- **Background (native, no Flutter):** while Shooting mode is on, a JobScheduler content-URI job on `MediaStore.Video` (re-scheduled every run, re-armed on boot and on app start) counts new videos since the last **scanned** generation and posts/updates the "N new clips to tag" notification (silent channel, `setOnlyAlertOnce`, BigPictureStyle with the newest thumbnail, actions: open To tag, Open camera). It does not touch the Drift database.
- **§8.3a Time zone where a clip was shot (best effort, builder's call):** videos don't record their zone, and detection may happen days later. So the phone keeps a small **zone timeline**: the native side appends `(timestamp, zoneId)` whenever the zone differs from the last entry — on `ACTION_TIMEZONE_CHANGED` (manifest receiver), every background job run, and every app start. A clip's zone = the timeline entry in effect at its shooting time; fallback = the current zone. The clip viewer shows "London time" (city derived from the zone ID) only when it differs from the phone's current zone. Known gap: if neither the receiver, job nor app ran while abroad, the zone falls back to the current one.
- **Missing media:** verified when a reel or To tag is shown (batched ID lookup); missing clips render the grey tile with Remove.

### 8.4 Domain logic (pure Dart, fully unit-tested)
- **Scenes:** consecutive inbox clips with a gap < 10 minutes form a scene (constant, configurable in code).
- **Ordering:** reels' clips by shooting time, oldest first; grouped by local day of shooting.
- **Tag player:** tap a reel = tag + auto-advance (Undo); sticky "Pick several"; "Same as previous" applies the previous clip's reel set; Skip; "+ New reel" inline; progress "n of N"; continues across scenes.
- **VN file names:** shooting time `yyyy-MM-dd_HH-mm-ss.mp4` (suffix on collision), never renamed once created; adding clips only adds copies; folder name fixed until Done editing.

### 8.5 Notifications
Channels: **New clips** (low importance, silent) and **Reminders** (default importance). Notifications: new clips; evening reminder; VN copies reminder (3 days after copying); Shooting mode still on (14 days). Tapping deep-links via go_router.

### 8.6 Export / import
Storage Access Framework (create/open document). JSON (versioned schema, `schemaVersion` field) containing: reels (name, description, status, dates), references, clips (references + fingerprints + zone), clip–reel links, **the To tag and Skipped lists**, settings (watched folders, reminder settings), and the zone timeline. **Not included:** Shooting mode on/off and its MediaStore baselines (phone state; on import Shooting mode is off and baselines reset to "now"), and VN sessions. Import replaces all data after a warning, then reports "X of Y clips found". Same-phone backup only. (Builder's call.)

**Orphaned VN copies:** after a reinstall or import, copies in `Movies/TakeTray/` are no longer owned by the app. The storage screen lists them (by folder) and deletes them through the system consent dialog (`MediaStore.createDeleteRequest`). (Builder's call.)

## 9. Delivery phases

Each phase: **plan** (superpowers:writing-plans) → **build** (Sonnet implementer subagents, one task at a time) → **task reviews** → **Opus phase review** → **owner check on the S24 Ultra** against a short demo checklist → next phase.

| # | Phase | Done when |
|---|---|---|
| 0 | **Foundation:** git, pub workspace, pinned Flutter wrapper, very_good_analysis, style check, local check script, l10n, logging, router shell with bottom nav, Riverpod bootstrap | `tool/check` (analyze, style check, tests) passes; app launches to an empty shell |
| 1 | **Design system:** `taketray_ui` package, tokens, theme + extensions, every component with goldens, Widgetbook | All components match the prototype in Widgetbook, light/dark, goldens committed |
| 2 | **Data layer:** Drift schema, DAOs, repositories, migrations + tests, export/import | Repository tests pass; export/import round-trips — *then move to GitHub + CI* |
| 3 | **Android media bridge:** permissions (full/limited/denied), video queries, thumbnails, folders, scan-on-open, version-change resync, missing detection | Real gallery videos appear in To tag after Shooting mode on, on the S24 Ultra |
| 4 | **Reels:** Home (Shooting mode card, filters, cards), create/edit/delete, reel detail (days, badges, missing tiles, multi-select), clip viewer | Matches screens; Patrol flows pass |
| 5 | **Tagging:** To tag (scenes, multi-select, Skip all + Undo, Skipped list), tag player (all behaviours in §8.4) | A day of 40 clips can be tagged quickly; Patrol flow passes |
| 6 | **Background + notifications:** content trigger, boot re-arm, new-clips notification, evening / 14-day reminders, help screen for OEM battery settings | Notification appears after filming on the S24 Ultra; reminders fire |
| 7 | **Add videos + Manual mode:** folder browser, system photo picker fallback | Friends' WhatsApp/Quick Share videos can be added |
| 8 | **Editor handoff:** clip selection, editor chooser, CapCut/Edits multi-share, VN copy flow (space, progress, ready, Editing-in-VN state, Done editing, reminder, storage screen) | Clips open in one CapCut/Edits project; VN shows the folder; copies are cleaned up |
| 9 | **References:** share target, Save reference sheet (incl. first launch), add/edit sheet, References section, Shooting mode References sheet | Sharing an Instagram reel saves it |
| 10 | **Onboarding, Settings, help, error log** | First launch end to end on a fresh install |
| 11 | **Release prep:** icon, splash, release signing, R8, no-INTERNET release manifest check, performance pass (500-clip grid smooth, cold start), accessibility pass, Play Console material (privacy policy, data safety, photo/video permission declaration, listing assets) | Signed app bundle ready to upload |

## 10. Quality bar (every phase)

- `tool/check` green: `dart analyze` with zero warnings, style check, all unit/widget/golden tests.
- Coverage ≥ 80% for `domain/`, `data/` and view models.
- Every screen state from the prototype that the phase touches has a widget or golden test.
- Patrol flows for the phase's main user journey, run on the S24 Ultra and on emulators for API 30, 33 and 34+.
- No `TODO` without a linked follow-up in the ledger; no dead code from the prototype left behind.
- `docs/decisions.md` has an entry for every meaningful decision the phase made, and `docs/flow.md` describes every execution flow the phase added or changed.
- Opus phase review finds no Critical/Important issues open.

## 11. Constraints and risks

- **Play policy:** broad video access (READ_MEDIA_VIDEO) needs a declaration; the app must work in Manual mode when access is limited/denied.
- **OEM background limits** (Samsung, Xiaomi…): detection must never depend on the background job; the scan on open is the source of truth.
- **Package names of editors** may change; detection must degrade to "Other app…".
- **Single test phone** (Samsung S24 Ultra); emulators cover API levels; other brands are a known gap until beta.

## 12. Left to the builder (decide in the plans, record in the ledger)

Exact file and class names; Pigeon API method signatures; Riverpod provider granularity; Drift DAO split; thumbnail cache sizes; animation implementation details within the motion tokens; how Widgetbook is organised; emulator setup.
