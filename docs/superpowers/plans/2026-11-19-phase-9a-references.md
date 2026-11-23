# Phase 9A: References in the app Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reel's saved links are visible and usable everywhere in the app. The reel page has a References section with add, edit label, copy, remove with Undo, and open. The reel form takes a link. Home's reel cards show a badge. The Shooting mode card has a References row that opens a sheet of every Collecting and Ready to edit reel's references with their shot ideas.

**Architecture:**
- **Data:**
  - `ReferencesRepository.delete` returns a new `ReferenceRemoveUndo` record that `UndoWriter` restores;
  - `ReelsRepository.createWithReference` makes a reel and its first link in one transaction;
  - `ReferencesRepository.watchAll` feeds the Shooting mode sheet;
  - pure rules in `domain/rules/reference_links.dart` extract, complete and display links.
- **Native:**
  - one new Pigeon API, `LinksHostApi.openLink` (`ACTION_VIEW`);
  - the source apps' icons come from the existing `EditorsBridge.apps(packages, iconPx)`, with four packages added to `<queries>`.
- **UI:**
  - `TtReferenceCard` gets a real menu and a large-text Open mark;
  - the app gets `lib/features/references/` (the Add / edit sheet, the section, the Shooting mode sheet, open and copy helpers);
  - the reel page, the reel form, Home and the Shooting mode section plug them in.

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; Drift (schema v2, unchanged); go_router; gen-l10n; alchemist goldens (app screen goldens macOS-only, D-97; package goldens made by the "update goldens" CI workflow and pulled with `tool/pull_ci_goldens <run-id>`, D-61); Pigeon 29.0.11; Kotlin with platform APIs only; Robolectric 4.17 (`tool/test_android`); Patrol 4.10 on the S24.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-9-references-design.md` (the 9A part, owner-approved 2026-11-19, including the builder-check answers). Visual source: `design/prototype/assets/refs.js` (`h.refCard`, `h.refsSection`, `sheets.addRef`, `sheets.refsList`, `RH.menus.refMenu`, the actions `openRef`, `refCopy`, `refRemove`, `addRefSave`, `openRefsSheet`) and `screens.js` (`sheets.reelForm`'s `rref` field). Phase 9 items: `docs/later.md` "Phase 9 (references)".

## Global Constraints

- **Branch:** `phase-9a-references` from `main` (4ecca71), in worktree `.claude/worktrees/phase-9a`. Push only at the end; PR to `main`; merging needs the owner's go.
- **Dependencies:** no new pub package and no new Gradle dependency.
- **Pigeon:** one new file, `pigeons/links_api.dart`, generated with the repo's existing command.
- **Release permissions unchanged:** `tool/check_release_permissions` must end `RELEASE PERMISSIONS OK`. `<queries>` entries need no permission.
- **Schema stays v2. Backup format unchanged** (references are already in it).
- **Copy:**
  - The prototype's "Recording" is **Collecting** everywhere (D-80).
  - Strings are given in each task, verbatim, and go through `app_en.arb`.
  - Limits: reel name 40, reference label 60 (`text_limits.dart`).
- **Logs (D-10):** never a link, a label, clipboard text or a reel name. Ids, counts and error types only.
- **The clipboard is read only when the user taps Paste** (spec approach 2A). Nothing reads it on open.
- **Never draw a source's logo.** Only the icon the phone supplies, or the generic link symbol.
- **UI:**
  - Design tokens only (`tool/check_styles`); 48 dp targets; semantics labels.
  - Text scaling to 200 %, light and dark, at 360 dp.
  - "Remove animations" (`MediaQuery.disableAnimationsOf`) turns the section flash off.
- **No existing behaviour changes** beyond what a task names. Every existing test stays green.
- **Strict TDD:**
  - Write **all** of a change's edge-case tests red first, record the RED run, then implement once. Never draft code and tests together.
  - Mutation-check the key lines, one mutant at a time, naming the test that kills each. A surviving mutant gets a test in the same task.
  - Never weaken a test.
- **Models:**
  - Opus: the implementer of Task 6 (the reel page section).
  - Sonnet: every other implementer, all fixes, every task review and re-review.
  - Opus: the whole-phase final review and its re-review (resume the same reviewer).
  - Never Haiku. Always pass the model.
- **Review findings:** fix Critical and Important now. Park Minors for one batch before the final review.
- **Docs, every task:**
  - its D-number in `docs/decisions.md` (Task 1 D-153, Task 2 D-154 … Task 9 D-161);
  - `docs/flow.md`;
  - its section of `docs/learn/phase-9a-references.md`;
  - `docs/later.md`: delete what is done.
- **Phone rules:**
  - Only `app.taketray.dev` runs tests. Never uninstall or clear `app.taketray`.
  - Logcat with `--pid=` only. No screenshots. Never list shared storage or read other apps' files.
  - Patrol uses only `Movies/TakeTray Test/`.
  - Pass `-s RZCY80PHWCZ`.
  - After every Patrol run: build debug, `install -r`, `pm clear app.taketray.dev`.
  - Run each Patrol file once per round. No test waits on Android's scheduler.
- **The phone is the very last step:**
  - Write and review Task 9's Patrol file with no device.
  - Finish the Minors batch, the final review and its fixes.
  - Only then ask the owner for the S24, once.
- **Git:**
  - Push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push. Never change git config.
  - Commits end `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The PR ends `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **Awkward links:**
   - a link with text around it, or with a trailing `)` or `.`;
   - a 2,000-character link;
   - a link with no label, whose title is the short link;
   - an emoji or right-to-left label at 60 characters;
   - all at 2× text.

   Expected: the card clamps (title 2 lines, subtitle 1), nothing overflows, and the Open mark never squeezes the title to a sliver. (Tasks 2, 4, 6.)
2. **Undo after the world moved.** Remove a reference, then:
   - Undo after the same link was saved again: no duplicate, no error;
   - Undo after the reel was deleted: nothing comes back, no crash;
   - Undo after the reel was edited: the edit's `updatedAt` is kept.

   (Tasks 2, 6.)
3. **Paste with odd clipboards:** empty, an image, a caption with no link, a caption with two links (the first wins), or a very long text. Expected: no crash, the right message, and nothing read until Paste is tapped. (Task 5.)
4. **Open with nothing to open it:** no browser and no matching app installed, or a link Android refuses. Expected: "No app on this phone can open this link.", with no crash and nothing logged but the error type. (Tasks 3, 6.)
5. **Live changes while a sheet is open.** A reference is removed, or a reel changes status or is deleted, while the Shooting mode References sheet or the Add sheet is open. Expected: the Shooting sheet updates (or shows its empty line); the Add sheet's Save on a deleted reel says "Couldn't save the reference." and nothing is saved. (Tasks 5, 8.)

---

### Task 1: Scope and docs (controller, no review)

**Files:**
- Modify: `docs/decisions.md` (D-153), `docs/later.md` (point each Phase 9 item at its task or at 9B).
- Create: `docs/learn/phase-9a-references.md` (a stub in the shape of `phase-10b-settings.md`: "How to read this guide", Contents, sections 2–9).
- Add: the spec and this plan.

- [ ] **Step 1:** Write D-153. It records:
  - the 9A/9B split and order;
  - the two owner choices (the share screen, approach 1; Paste only on tap, approach 2A);
  - the spec's calls: Collecting and Ready to edit, real app icons, Open reel replaces what is open, the link rule;
  - this plan's ruling on Instagram labels (Task 2): stored `/p/` links read "Instagram";
  - the D-number of each task.
- [ ] **Step 2:** Commit `docs: Phase 9 design, Phase 9A plan and D-153`.

---

### Task 2: Reference data: link rules, remove with Undo, create with a link, watch all

**Model:** Sonnet. **D-154.**

**Files:**
- Create: `app/lib/domain/rules/reference_links.dart`
- Modify:
  - `app/lib/domain/models/undo_record.dart`
  - `app/lib/data/repositories/undo_writer.dart`
  - `app/lib/data/repositories/references_repository.dart`
  - `app/lib/data/repositories/reels_repository.dart`
- Test:
  - `app/test/domain/rules/reference_links_test.dart`
  - `app/test/data/repositories/references_repository_test.dart`
  - `app/test/data/repositories/reels_repository_test.dart`
  - `app/test/data/repositories/undo_writer_test.dart`

**Interfaces:**
- Consumes: `normalizeReferenceUrl`, `referenceSourceOf`, `ReelTouch`, `UndoWriter.undoAll`, `checkReferenceLabel`, the reel-name checks in `ReelsRepository.create`.
- Produces:
  - `String? firstLinkIn(String text)`: the first `http://` or `https://` run of non-space characters (case-insensitive scheme), with trailing `)`, `.`, `,` and `!` stripped. Null when there is none. No other cleaning: callers pass the result to `normalizeReferenceUrl`.
  - `String? typedLink(String text)`:
    - text with a link in it → `firstLinkIn`;
    - otherwise trimmed text with no whitespace that contains a `.` → `https://` + text;
    - otherwise null.
  - `String shortLink(String url)`: drops the scheme, a leading `www.` or `m.`, the query, the fragment and trailing slashes. For example `https://www.instagram.com/p/ABC/` → `instagram.com/p/ABC`.
  - `enum ReferenceKind { instagram, instagramProfile, youtubeShort, youtubeVideo, tiktok, link }` and `ReferenceKind referenceKindOf(Uri url)`:
    - Instagram post paths (`/p/` after `normalizeReferenceUrl`) are `instagram`; any other Instagram path is `instagramProfile`;
    - YouTube `/shorts/…` is `youtubeShort`, other YouTube is `youtubeVideo`;
    - TikTok is `tiktok`; the rest is `link`.
    - **Ruling:** normalisation turns `/reel/` into `/p/`, so a stored link can no longer tell a reel from a post; both read "Instagram". The finer "Instagram reel" label is 9B's, from the raw shared link.
  - `final class ReferenceRemoveUndo extends UndoRecord`:
    - fields `ReelReference reference` (every field, with `createdAt`) and `ReelTouch? touch`;
    - `isEmpty` is false.
  - `Future<ReferenceRemoveUndo?> ReferencesRepository.delete(int id)`: returns the record, or null for an unknown id. **Breaking:** this used to return `void`; update the callers.
  - `UndoWriter` restores a `ReferenceRemoveUndo`:
    - the row comes back with its id, label and `createdAt`;
    - it is skipped (no error) when the reel already has the same `url`, or the reel is gone (a warning with ids only);
    - the reel's `updatedAt` follows the `ReelTouch` rule.
  - `Future<Reel> ReelsRepository.createWithReference(String name, {String? description, required String url, String? label})`:
    - one transaction, so a bad `url` (`ReferenceUrlProblem.invalid`) or label saves no reel;
    - the reel is Collecting.
  - `Stream<List<ReelReference>> ReferencesRepository.watchAll()`: every reference, newest first (ties: highest id first).

- [ ] **Step 1: Write the failing tests:**
  - **`firstLinkIn`:**
    - `"Title https://vm.tiktok.com/ZM8x/"` → the link;
    - `"see (https://youtu.be/a1)."` → `https://youtu.be/a1`;
    - `"a https://x.com/1 b https://y.com/2"` → the first;
    - `"HTTPS://X.COM/a"` → found;
    - `"www.instagram.com/reel/a"` → null;
    - `""` and `"no link here"` → null.
  - **`typedLink`:**
    - `"instagram.com/reel/abc"` → `https://instagram.com/reel/abc`;
    - `"  https://x.com/a  "` → `https://x.com/a`;
    - `"hello world"` → null;
    - `"hello"` → null.
  - **`shortLink`:** the example above; `https://m.youtube.com/watch?v=1#t` → `youtube.com/watch`; `https://example.com` → `example.com`.
  - **`referenceKindOf`:** one case per kind, plus `https://www.instagram.com/someuser/` → `instagramProfile`.
  - **`delete` and Undo:**
    - delete then `undoAll([record])` → the same id, label and `createdAt`, and the reel's `updatedAt` back to its value before;
    - delete twice → the second returns null;
    - Undo after the same link was re-added → still one row, no throw;
    - Undo after the reel was deleted → nothing inserted, no throw;
    - Undo after a rename of the reel → the rename's `updatedAt` kept.
  - **`createWithReference`:**
    - success → one reel (Collecting) and one reference;
    - invalid url → `InvalidInputException(ReferenceUrlProblem.invalid)` and zero reels;
    - a 61-character label → `ReferenceLabelProblem.tooLong` and zero reels;
    - a duplicate name → `ReelNameProblem.duplicate` and no reference.
  - **`watchAll`:** order, and a new emission after `add`.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/domain/rules test/data/repositories`. Expected: FAIL.
- [ ] **Step 3: Implement.** Add the new case to every exhaustive switch over `UndoRecord`.
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop the trailing-punctuation strip;
  - the duplicate-url skip in the restore;
  - the `ReelTouch` guard;
  - `createWithReference` outside its transaction.
- [ ] **Step 6: Docs and commit** `feat(references): link rules, remove with Undo, create with a link`. D-154; flow.md "References"; guide §2.

---

### Task 3: Open a link, and the source apps' icons

**Model:** Sonnet. **D-155.**

**Files:**
- Create:
  - `app/pigeons/links_api.dart`
  - `app/lib/platform/links_bridge.dart` (plus generated `links_api.g.dart`)
  - `app/android/app/src/main/kotlin/app/taketray/links/LinksHostApiImpl.kt` (plus generated Kotlin)
  - `app/lib/features/references/view_models/source_icons.dart`
- Modify:
  - `MainActivity.kt` (register the API)
  - `AndroidManifest.xml` (`<queries>` and its comment)
  - `app/test/platform/editor_packages_manifest_test.dart`
- Test:
  - `app/test/platform/links_bridge_test.dart`
  - `app/android/app/src/test/kotlin/app/taketray/links/LinksHostApiImplTest.kt`
  - `app/test/features/references/view_models/source_icons_test.dart`

**Interfaces:**
- Produces:
  - Pigeon `LinksHostApi`:
    - `@async bool openLink(String url)`;
    - the Kotlin side refuses anything not `http`/`https` (returns false) and starts `ACTION_VIEW` with `CATEGORY_BROWSABLE`;
    - an `ActivityNotFoundException` returns false; any other exception becomes a `PlatformException` with the class name only.
  - `abstract interface class LinksBridge { Future<bool> openLink(String url); }`, `PigeonLinksBridge`, and `@Riverpod(keepAlive: true) LinksBridge linksBridge(Ref ref)`. A `PlatformException` is logged by code only and returns false.
  - `const Map<ReferenceSource, List<String>> sourceAppPackages`:
    - `instagram: ['com.instagram.android']`;
    - `youtube: ['com.google.android.youtube']`;
    - `tiktok: ['com.zhiliaoapp.musically', 'com.ss.android.ugc.trill']`;
    - `link: []`.
  - `@Riverpod(keepAlive: true) Future<Map<ReferenceSource, Uint8List>> sourceIcons(Ref ref)`:
    - one `EditorsBridge.apps(allPackages, 48)` call for the app's life;
    - each source maps to the PNG of its first installed package;
    - a failed call gives an empty map, with the error type logged.
  - `<queries>` names the three editors and the four source packages. The manifest test expects `EditorApp` packages plus `sourceAppPackages` values, and nothing else.
- [ ] **Step 1: Write the failing tests:**
  - **Kotlin:**
    - `https://x.com` starts an `ACTION_VIEW` with the uri and `CATEGORY_BROWSABLE`;
    - `javascript:x` and `file:///a` return false and start nothing;
    - no handler (Robolectric's empty package manager) returns false.
  - **Dart:**
    - the bridge maps a `PlatformException` to false;
    - `sourceIcons` picks TikTok's second package when only it is installed, omits uninstalled sources, and returns `{}` on a throwing bridge;
    - the manifest test as above.
- [ ] **Step 2: Run** `../tool/flutter test test/platform test/features/references` and `../tool/test_android`. Expected: FAIL.
- [ ] **Step 3: Implement.** Generate Pigeon, register in `MainActivity.configureFlutterEngine`.
- [ ] **Step 4: Run** `../tool/check`, `../tool/test_android` and `../tool/check_release_permissions`. Expected: `ALL CHECKS PASSED` and `RELEASE PERMISSIONS OK`.
- [ ] **Step 5: Mutation checks:**
  - the scheme check removed;
  - `ActivityNotFoundException` not caught;
  - first installed package replaced by the first listed.
- [ ] **Step 6: Docs and commit** `feat(references): open links and read the source apps' icons`. D-155; flow.md "Platform bridges"; guide §3.

---

### Task 4: `TtReferenceCard`: a real menu and a large-text Open mark

**Model:** Sonnet. **D-156.**

**Files:**
- Modify: `packages/taketray_ui/lib/src/components/reference_card.dart`, its Widgetbook use case.
- Test: `packages/taketray_ui/test/components/reference_card_test.dart` and its golden file.

**Interfaces:**
- Produces:
  - `TtReferenceCard<T>` replaces `onMore` with `List<TtMenuItem<T>>? moreItems` and `ValueChanged<T>? onMoreSelected`. When both are given, the more button is a `TtMenuButton<T>`, keeping `moreSemanticLabel` and a 48 dp target. Its assert is kept: items need a label.
  - When `MediaQuery.textScalerOf(context).scale(14) >= 21` (150 %), the Open mark shows only its icon, and the main button's semantics are unchanged.
  - The title clamps to 2 lines and the subtitle to 1, as today.
- [ ] **Step 1: Write the failing tests:**
  - choosing a menu item calls `onMoreSelected` with its value;
  - no items → no more button;
  - at 150 % and 200 % the "Open" word is absent and the open icon present; at 140 % the word shows;
  - a 2,000-character title at 200 % and 360 dp does not overflow;
  - goldens: no label, label, menu, 200 %, light and dark.
- [ ] **Step 2: Run** `cd packages/taketray_ui && ../../tool/flutter test`. Expected: FAIL.
- [ ] **Step 3: Implement.** Update every existing caller (Widgetbook only, today).
- [ ] **Step 4: Goldens:** run the "update goldens" workflow on the branch, then `tool/pull_ci_goldens <run-id>`. Never commit failure images.
- [ ] **Step 5: Run** `../../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 6: Mutation check:** the 150 % threshold moved to 200 %.
- [ ] **Step 7: Docs and commit** `feat(ui): reference card menu and large-text Open`. D-156; guide §4; later.md loses "The reference card's Open button takes half the row at 2×".

---

### Task 5: The Add / edit reference sheet

**Model:** Sonnet. **D-157.**

**Files:**
- Create:
  - `app/lib/features/references/views/reference_sheet.dart`
  - `app/lib/features/references/view_models/reference_form_controller.dart`
- Modify: `app/lib/l10n/app_en.arb`
- Test:
  - `app/test/features/references/views/reference_sheet_test.dart` (with goldens)
  - `app/test/features/references/view_models/reference_form_controller_test.dart`

**Interfaces:**
- Consumes: `typedLink`, `firstLinkIn`, `shortLink`, `referenceKindOf` (Task 2); `sourceIcons` (Task 3); `ReferencesRepository.add`, `setLabel`; `ReelSnacks.show`, `showUndo`; `showTtSheet`, `TtTextField.trailing`.
- Produces:
  - `Future<void> showReferenceSheet(BuildContext context, {required int reelId, ReelReference? editing})`. With `editing`, it is the Edit label sheet.
  - `ReferenceFormController` (`@Riverpod(retry: noRetry)`, family on `reelId`, single-flight save like `ReelFormController`):
    - `Future<ReferenceSaveResult> saveNew(String linkText, String label)` → `ReferenceSaved(ReelReference)` | `ReferenceNotALink` | `ReferenceAlreadyIn(String reelName)` | `ReferenceLabelTooLong` | `ReferenceSaveFailed`;
    - `Future<bool> saveLabel(int id, String label)`.
  - Paste:
    - `Clipboard.getData(Clipboard.kTextPlain)` only in the Paste button's handler;
    - `firstLinkIn` → the field, then focus Label;
    - no link → the helper error.
  - Shared helpers, used by Tasks 6 and 8:
    - `Widget referenceSourceIcon(BuildContext, ReferenceSource, {double size})` (the phone's icon or `Symbols.link_rounded`);
    - `String referenceKindText(AppLocalizations, Uri url)` (the kind labels below; the host for `link`);
    - `({String title, String subtitle}) referenceCardText(AppLocalizations, ReelReference)`: the title is the label, or `shortLink` when there is none. The subtitle is "{kind} · {shortLink}" with a label, or the kind alone without one.
- **Copy (verbatim):**
  - titles: "Add reference" with subtitle "to {reelName}"; "Edit label" with subtitle "{reelName}";
  - fields: "Link", help "Instagram, YouTube or any other link", hint "https://www.instagram.com/reel/…"; "Label (optional)", hint "Fast cuts, food close-ups", counter 60;
  - buttons: "Paste", "Cancel", "Save";
  - errors:
    - "That isn't a link. In Instagram: Share › Copy link, then paste it here."
    - "There's no link on your clipboard."
    - "Already saved in {reelName}"
    - "Couldn't save the reference."
  - snacks: "Reference saved" (with **Undo**, which calls `delete` on the new id), "Label saved".
  - The source row in edit mode uses the kind labels: "Instagram", "Instagram profile", "YouTube Short", "YouTube video", "TikTok video", and the host for a link.
- [ ] **Step 1: Write the failing tests:**
  - **Controller:** each result case; a double Save makes one row; a reel deleted before Save → `ReferenceSaveFailed`.
  - **Sheet:**
    - nothing touches the clipboard until Paste. Use a mock `SystemChannels.platform` handler that counts `Clipboard.getData` calls: 0 after open, 1 after Paste;
    - Paste with the caption "Look https://instagram.com/reel/A1 wow" fills the link;
    - Paste with an empty, null or non-text clipboard → "There's no link on your clipboard.";
    - Save with an empty or not-a-link field → the not-a-link error;
    - Enter in Label saves;
    - edit mode shows the source row and the prefilled label, and blank clears it;
    - Undo on "Reference saved" removes it;
    - goldens of empty, error, edit, light and dark, and 200 %.
- [ ] **Step 2: Run** `../tool/flutter test test/features/references`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - a clipboard read moved to `initState`;
  - `typedLink` replaced by `firstLinkIn` in Save;
  - the single-flight guard removed.
- [ ] **Step 6: Docs and commit** `feat(references): add and edit reference sheet`. D-157; flow.md "References"; guide §5.

---

### Task 6: The reel page's References section, opening, and the Home badge

**Model:** Opus. **D-158.**

**Files:**
- Create:
  - `app/lib/features/references/views/references_section.dart`
  - `app/lib/features/references/view_models/reference_actions.dart` (open, copy, remove)
- Modify:
  - `app/lib/features/reels/views/reel_detail_screen.dart`
  - `app/lib/router/routes.dart` and `app_router.dart`
  - `app/lib/features/reels/views/reels_screen.dart`
  - `app/lib/features/reels/view_models/home_controller.dart`
  - `app/lib/l10n/app_en.arb`
- Test:
  - `app/test/features/references/views/references_section_test.dart` (goldens)
  - `app/test/features/references/view_models/reference_actions_test.dart`
  - `app/test/features/reels/views/reel_detail_screen_test.dart`
  - `app/test/features/reels/views/reels_screen_test.dart`
  - `app/test/router/routes_test.dart`

**Interfaces:**
- Consumes: Tasks 2–5; `ReferencesRepository.watchForReel`, `watchCounts`; `showReelForm` (description focus, below).
- Produces:
  - **Route:** `Routes.reelReferences(int id)` → `/reels/$id?refs=1`, and `ReelDetailScreen.focusReferences`. On first build with data, the section is scrolled into view (`Scrollable.ensureVisible`) and flashes once (a 600 ms highlight). With `disableAnimations`, it scrolls with no flash and no animation.
  - **Section:** `ReferencesSection(reel: Reel)`, a sliver under the header, before the edit banner and clips. It has three states (none, cards, cards plus prompt), per the spec.
  - **Actions:** `ReferenceActions` (`@riverpod`):
    - `Future<bool> open(ReelReference)` (`LinksBridge.openLink`);
    - `Future<void> copy(ReelReference)` (`Clipboard.setData`);
    - `Future<ReferenceRemoveUndo?> remove(int id)`.
  - **The card menu:** Edit label, Copy link, Remove (destructive).
  - **`showReelForm`** gains `bool focusDescription = false`; "Write shot ideas" opens it on the reel with this true.
  - **Home:**
    - `ReelSummary` rows get a reference count from `watchCounts()`, joined in the Home provider (not in SQL);
    - `TtReelCard.referenceCount` is set, and its badge tap opens `Routes.reelReferences(id)`.
  - **The empty reel state's body** gains a second paragraph (below).
- **Copy (verbatim):**
  - the empty-state row: "Add reference" / "Save a reel you want to recreate";
  - the header "References · {count}" and the button "Add";
  - the prompt: "Write the shots you need" / "Watch your references, then list the shots to get while you're out." with "Write shot ideas";
  - the open label "Open"; the open semantics "Open reference: {title}, {source}"; more "More options for {title}";
  - menu: "Edit label", "Copy link", "Remove";
  - snacks:
    - "Reference removed" (Undo);
    - "Link copied", shown only when `AndroidSdk` < 33;
    - "No app on this phone can open this link.";
  - the badge semantics "{count, plural, =1{1 reference} other{{count} references}}, open them";
  - the empty reel line: "You can also share a reel from Instagram to TakeTray to save it as a reference."
- [ ] **Step 1: Write the failing tests:**
  - **Section:**
    - none → only the Add row; one; three in newest-first order;
    - a description present → no prompt; references with an empty description → the prompt;
    - "Write shot ideas" → the form with the description focused;
    - each menu item;
    - Remove then Undo → back in place;
    - open false → the snack;
    - copy on SDK 33 → no snack, on SDK 32 → the snack;
    - goldens: none, one, three plus prompt, light and dark, and 200 % with a 2,000-character link and a 60-character emoji label.
  - **Route:** `?refs=1` parses, and the section is visible after the first frame. Use a reel with 40 clips, so the section starts off screen. With `disableAnimations`, there is no flash animation (no ticker).
  - **Home:**
    - the badge shows 2 for a reel with 2 references and is absent at 0;
    - tapping it pushes `Routes.reelReferences`;
    - the card's own tap still opens the reel.
  - **Logs:** a test that `remove` and `open` log no link or label (capture the `Logger` records).
- [ ] **Step 2: Run** `../tool/flutter test test/features test/router`. Expected: FAIL.
- [ ] **Step 3: Implement.** Remove the "Not built: References (Phase 9)" line from the screen's doc.
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - the prompt shown with a description;
  - the flash with `disableAnimations`;
  - the badge count from the wrong reel id;
  - the SDK 33 condition inverted.
- [ ] **Step 6: Docs and commit** `feat(references): References section, open, and the Home badge`. D-158; flow.md "Reel page" and "Home"; guide §6; later.md loses the badge and section items.

---

### Task 7: The reel form's Reference link field

**Model:** Sonnet. **D-159.**

**Files:**
- Modify:
  - `app/lib/features/reels/views/reel_form_sheet.dart`
  - `app/lib/features/reels/view_models/reel_form_controller.dart`
  - `app/lib/l10n/app_en.arb`
- Test:
  - `app/test/features/reels/views/reel_form_sheet_test.dart` (goldens)
  - `app/test/features/reels/view_models/reel_form_controller_test.dart`

**Interfaces:**
- Consumes: `typedLink`, `ReelsRepository.createWithReference`, `ReferencesRepository.add` (Task 2), `watchCounts`.
- Produces:
  - `ReelFormController.save` gains `String? link`, and `ReelFormState` gains `linkError` (a `ReferenceUrlProblem?`).
  - All three errors (name, description, link) are found in one Save.
  - **Create** with a link uses `createWithReference`.
  - **Edit** saves the reel, then calls `add`; `ReferenceAlreadySaved` is not an error.
  - The field is hidden when `onCreateForClip` is given (the tag player).
- **Copy (verbatim):**
  - the label "Reference link (optional)" and hint "Paste an Instagram reel link";
  - help on create, and on edit with no references: "A reel you want to recreate. You can add more later.";
  - help on edit with N > 0: "{count, plural, =1{1 reference saved} other{{count} references saved}}. Add another, or manage them on the reel.";
  - the error is Task 5's not-a-link sentence.
- [ ] **Step 1: Write the failing tests:**
  - create with a link → reel and reference;
  - create with "hello world" → the link error, no reel, and the name error shown too when the name is empty;
  - edit with a new link → added;
  - edit with an already saved link → saved with no error;
  - an empty field → no reference call;
  - the tag-player form has no field;
  - the help text with 0, 1 and 3 references;
  - goldens: create with error, and edit with 2 references.
- [ ] **Step 2: Run** the two test files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - the link checked after the name returns early;
  - `ReferenceAlreadySaved` treated as an error.
- [ ] **Step 6: Docs and commit** `feat(reels): reference link field in the reel form`. D-159; flow.md "Reel form"; guide §7; later.md loses the link field item.

---

### Task 8: Shooting mode: the References row and sheet

**Model:** Sonnet. **D-160.**

**Files:**
- Create:
  - `app/lib/features/references/views/shooting_references_sheet.dart`
  - `app/lib/features/references/view_models/shooting_references.dart`
- Modify:
  - `app/lib/features/shooting_mode/views/shooting_mode_section.dart`
  - `app/lib/l10n/app_en.arb`
- Test:
  - `app/test/features/references/view_models/shooting_references_test.dart`
  - `app/test/features/references/views/shooting_references_sheet_test.dart` (goldens)
  - `app/test/features/shooting_mode/views/shooting_mode_section_test.dart`

**Interfaces:**
- Consumes: `ReferencesRepository.watchAll`, `ReelsRepository.watchReelSummaries` (Home's order); `referenceSourceIcon`, `ReferenceActions.open` (Tasks 5, 6); `Routes.reelReferences`; `showReelForm(focusDescription: true)`.
- Produces:
  - `@riverpod Stream<List<ReferenceGroup>> shootingReferences(Ref ref)`:
    - groups of `(ReelSummary reel, List<ReelReference> references)`;
    - Collecting reels first, then Ready to edit, each in Home's order;
    - only reels with at least one reference; Published is never included.
  - `int shootingReferenceCount(List<ReferenceGroup>)`.
  - The row:
    - `TtCardRow(kind: TtCardRowKind.link, icon: Symbols.link_rounded, title: "References · {count}")`, first in `rows`, before Add earlier videos;
    - only while Shooting mode is on and the count > 0;
    - its tap opens the sheet.
  - `Future<void> showShootingReferencesSheet(BuildContext context)`:
    - the collapsed groups are local state, and all groups start open;
    - it updates live;
    - with no groups left it shows the empty line.
- **Copy (verbatim):**
  - title "References", subtitle "From your Collecting and Ready to edit reels, with their shot ideas";
  - "Shot ideas"; "No shot ideas yet."; "Write the shots you need";
  - toggle semantics: "Show {reelName}'s references" / "Hide {reelName}'s references";
  - empty: "No references in your Collecting or Ready to edit reels."
- [ ] **Step 1: Write the failing tests:**
  - **Grouping:** Collecting before Ready to edit; Published left out; a reel with 0 references left out; order within a status equals Home's; the count sums the groups.
  - **Live:** removing the last reference of the only group → the empty line; a reel moved to Published → its group goes.
  - **Section:** the row present when on with a count of 2; absent when off; absent when on with 0; first before Add earlier videos.
  - **Sheet:**
    - a header tap → closes and pushes `Routes.reelReferences`;
    - a card tap → `open`;
    - "Write the shots you need" → the form with focus;
    - collapse hides the cards and the shot ideas;
    - goldens: one reel, several, one without shot ideas, light and dark, and 200 %.
- [ ] **Step 2: Run** the test files. Expected: FAIL.
- [ ] **Step 3: Implement.** Replace the comment "References (Phase 4/5) will come first in this list."
- [ ] **Step 4: Run** `../tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - Published included;
  - the order of the two statuses swapped;
  - the row shown when off.
- [ ] **Step 6: Docs and commit** `feat(shooting): References row and sheet`. D-160; flow.md "Shooting mode"; guide §8; later.md loses the "Phase 4/5 puts References first" item under Phase 4.

---

### Task 9: Patrol flows, guide, README (no device)

**Model:** Sonnet. **D-161.**

**Files:**
- Create: `app/patrol_test/references_test.dart`
- Modify:
  - `docs/learn/phase-9a-references.md` (§9 and the closing summary)
  - `README.md` (progress: "Phase 9A done"; Next: "Phase 9B Sharing in")
  - `docs/dev-setup.md` ("Phase 9A check", the hand checks below)

**Interfaces:**
- Consumes: `patrol_test/support/onboarded.dart`, `lifecycle.dart` (`restoreResumedLifecycle`).
- **Produces four flows:**
  1. Add a reference with a typed link and a label → the card shows → Edit label → Remove → Undo → back.
  2. Paste:
     - the test puts a caption with a link on the clipboard with `Clipboard.setData`;
     - Paste → Save → the card;
     - the Home badge shows 1 → its tap lands on the reel with the section visible.
  3. The reel form: create a reel with a reference link → the section shows it.
  4. Shooting mode on with two Collecting reels holding references:
     - the card's References row → the sheet;
     - collapse one → a header tap opens that reel.

  Text entry uses `enterText(..., hideKeyboard: false)` (the 10A harness rule). No flow opens a real link; `LinksBridge` is faked in the Patrol harness.
- **Hand checks for `dev-setup.md`:**
  1. Open a reference with Instagram installed; with YouTube.
  2. A non-Instagram link opens in the browser.
  3. Paste shows Android's paste message only after the tap.
  4. TalkBack on the section, the card menu and the Shooting sheet.
  5. 200 % text on the section and the sheet.
  6. Dark mode.
  7. The release build installs over `app.taketray` with data kept, and references survive.
- [ ] **Step 1:** Write the four flows. `../tool/flutter analyze` must be clean. Do not run them (no device).
- [ ] **Step 2:** Review them against the hand checks for vacuous negatives: every "absent" check is preceded by a positive wait on the same screen.
- [ ] **Step 3: Docs and commit** `test(patrol): references flows; Phase 9A guide and README`. D-161.

---

### After Task 9 (controller)

1. The Minors batch (one Sonnet fixer, one Sonnet re-review).
2. The Opus final review, one fix wave, and the Opus re-review.
3. Push the branch; CI green; open the PR.
4. Ask the owner for the S24: run `references_test.dart` once (the phone rules above), then the owner's hand checks.
5. Merge on the owner's go.
