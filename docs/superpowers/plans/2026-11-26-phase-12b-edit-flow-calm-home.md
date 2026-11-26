# Phase 12B: fewer taps to an editor, and the calm Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the owner's two approved designs on `phase-12-ui-refresh` before its PR merges: sending clips to an editor in fewer taps (D-185) and the calm Home (D-186, D-187).

**Architecture:**
- **The edit flow (Tasks 1–5):**
  - `ReelSelection` learns choosing that started from the editor sheet (stays on when empty) and a Clear that keeps choosing;
  - the editor sheet takes every clip ("Edit all {n} clips in…"), offers **Choose clips instead**, puts the last-used editor first (`lastEditor`, a phone-state key), and returns what happened instead of popping a route;
  - a new `TtSelectionDock` in `taketray_ui`;
  - on the reel page **Edit video** opens the sheet at once, and while choosing the dock takes the nav pill's place in `AppShell` (so snacks float above it);
  - the picking screen keeps only add mode.
- **The calm Home (Tasks 6–9):**
  - `TtShootingModeCard` becomes compact (one row; Open camera and up to two glass chips when on), with no rows and no strip;
  - `TtReelCard` becomes the calm card (the cover alone, the text under it);
  - new `TtQuietTabs`, `TtHeaderPill` and `TtLargeSliverAppBar`;
  - `reels_screen.dart` and `shooting_mode_section.dart` put them together: "+ New" in a collapsing header, no FAB, no strip, no To tag banner, a top-aligned grid, the press and tab motion.
- **Then:** Patrol (Task 10), docs (Task 11), and the S24 last (Task 12).

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; go_router; gen-l10n; alchemist goldens (package: CI set by the "update goldens" workflow, macOS set locally, D-61; app goldens macOS-only, D-97); Patrol 4.10.

**Spec:**
- `design/handoff/edit-flow.md` (D-185), prototype `design/prototype/assets/editflow.js` and `editflow.css`, hub screens 8, 18 and 19.
- `design/handoff/home-calm-grid.md` (D-186, D-187), prototype `design/prototype/assets/home2.js` and `home2.css`, hub screen 6.
- `docs/decisions.md` D-185, D-186 and D-187; `docs/later.md` "Next: sending clips to an editor in fewer taps" and "Next: the calm Home".

## Global Constraints

- **Branch:**
  - `phase-12-ui-refresh` in worktree `.claude/worktrees/phase-12`, from HEAD 6a562e8 (Phase 12 is done on the phone; its PR is not merged).
  - 12B lands on the same branch and goes out in the same PR.
  - Push the branch, CI runs on it, and it merges through a green PR after the owner approves.
- **Dependencies:** no new pub package, Gradle dependency or third-party plugin. This rules out the `animations` package's container transform (see Task 9).
- **Release permissions:**
  - the release manifest has no `INTERNET`, `ACCESS_NETWORK_STATE` or `WAKE_LOCK`, and no new permission;
  - `tool/check_release_permissions` ends `RELEASE PERMISSIONS OK`.
- **Logs (D-10):** ids, counts, an editor's enum name and error types only. No new log line carries a reel name, a path, a link or a setting's value (`lastEditor` is logged by its key only).
- **Phone rules:**
  - The phone is used **only in Task 12**, the last step.
  - S24 `-s RZCY80PHWCZ`, and only TakeTray Dev (`app.taketray.dev`). Never uninstall or clear `app.taketray`.
  - Logcat with `--pid=` only. No screenshots.
  - Never read shared storage or other apps' data. Patrol uses only `Movies/TakeTray Test/`.
  - After every Patrol run: debug build, `install -r`, `pm clear app.taketray.dev`.
  - Each Patrol file runs once per round.
- **Never:**
  - modify `~/flutter` (or `~/development/flutter`);
  - commit keystores, `key.properties`, `local.properties`, secrets, build output or golden failure images (`**/failures/`).
- **Commits:**
  - each commit ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - the PR ends `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Strict TDD:**
  - every edge-case test of a task is written red first, the RED is recorded, then the code is written once;
  - each task names mutation checks (a key line broken, and the test that kills it);
  - never weaken a test;
  - characterization tests that must pass before and after a change (add mode in Task 5) are marked as such and recorded green.
- **Docs in the same task:**
  - each task writes its own D-number in `docs/decisions.md` (Task 1 D-188 … Task 10 D-197) and its `docs/flow.md` lines;
  - an amended decision gets an "Amended by D-…" line.
- **Values come from the CSS and the handoffs, never eyeballed:**
  - every new number is a `TtMetrics` constant (colours in `TtColors`) with the CSS line it copies quoted above it (`// editflow.css:8: .sd-act { … min-height: 56px }`, `// home2.css:28: .h2-chip { … }`);
  - the style rules (D-19: no raw colour, inset, size, radius or duration in `app/lib/features` or `components`) hold.
- **Glass (Phase 12 rules, binding for every glass piece):**
  - every `BackdropFilter`'s first painting child is a plain fill, never a `Material`; build glass with the shared `TtGlassFill` (`components/internal/glass_fill.dart`);
  - never wrap a `BackdropFilter` in `Opacity` (fade with the fill's alpha, or fade a parent that holds no filter);
  - pixel and structure tests use `packages/taketray_ui/test/support/tt_glass_pixels.dart` (`expectGlassStructure`, `expectBlurFilter`, `expectBlurred`);
  - the only new glass is Home's on-card chips: white 14 % with blur 10 (`home2.css:28`). The selection dock is solid `surfaceContainer`.
- **Contrast:**
  - the chips' white text sits on the dark card: AA over a white stand-in for the backdrop (`ttTextContrastGuideline`, D-62);
  - status words are `onSurfaceVariant` on `surface` (AA, `expectTtAccessible`).
- **Behaviour the designs do not change** (each task keeps its tests green):
  - R1: Edit is not offered while a reel has an editing session; Done editing comes first;
  - VN add mode (D-128, D-129) and Done editing;
  - the editor rows after a pick (snack, Ready to edit offer, VN space check, share menu);
  - export and import;
  - the onboarding Home tip (`ShootingTip`, D-142): `home2.js:67` keeps it ("Going out to shoot?");
  - the reel page's ⋮ **Select clips** (`ReelSelection.begin`, D-88): the prototype keeps it (`screens.js:626`).
- **UI:**
  - design tokens only; 48 dp targets; a semantics label on every control;
  - light and dark; text 1× and 2×; 360 dp wide;
  - reduced motion (`MediaQuery.disableAnimations`, `tt.motion` durations zero): crossfades only, no slide, no scale.
- **Copy:** strings are given verbatim in each task, through `app/lib/l10n/app_en.arb`, then `cd app && ../tool/flutter gen-l10n`.
- **Commands:**
  - package: `cd packages/taketray_ui && ../../tool/flutter test <file>`;
  - app: `cd app && ../tool/flutter test <file>`;
  - codegen: `cd app && ../tool/dart run build_runner build --delete-conflicting-outputs` (`tool/check_generated` checks it);
  - all checks: `tool/check` from the repo root, which ends `ALL CHECKS PASSED`.
- **Goldens:**
  - app goldens are macOS-only (`--update-goldens` locally);
  - package macOS goldens are updated locally in the task (`ttGoldenTest` draws 1× and 2×, light and dark);
  - package CI goldens come once, at the end, from the "update goldens" workflow, pulled with `tool/pull_ci_goldens`;
  - a removed piece takes its goldens with it (both sets).
- **Removals** (each in the task that makes it unused, with its tests, goldens, strings and widgetbook use cases, after a `grep` shows no other user):
  - the FAB on Home (`TtFab` itself stays: To tag and the reel page use it);
  - the "N clips to tag" strip (`toTagStrip`, `TtCardRow`, `TtCardRowKind`);
  - the Home To tag banner;
  - the reel card's cover overlays and references badge button;
  - the selection ⋮ menu (`_SelectionAction`);
  - the picking screen outside add mode.
- **Models (never Haiku; always pass the model):**
  - Opus: the implementers of Task 4 (the reel page's choosing and the dock in the shell) and Task 9 (the Home assembly with its scroll and press motion);
  - Sonnet: every other implementer, all fixes and all task reviews;
  - Opus: the whole-12B review and its re-review (resume the same reviewer).
- **Reviews:**
  - Critical and Important findings are fixed now; Minors are parked for one batch before the final review;
  - a per-step fixer reviews its own fix; the final review's fix wave gets a separate re-review;
  - the step review may be skipped for Task 11 (docs only); never for code, phone safety, privacy or the final review.

## Review Focus

1. **Choosing clips on a reel that is being edited (R1).**
   - Hold a clip on a reel with a VN (or CapCut) session: the dock shows the four actions and the note "This reel is being edited in VN. Tap Done editing at the top before sending clips again.", never an Edit button.
   - Remove still deletes the copies first (R8) and says so; a remove whose copies cannot be deleted keeps the choice, and its snack sits above the dock.
   - A session that ends while choosing (Done editing) turns the note into Edit {n} clips without ending the choice.
   - (Task 4 `'during a session the dock has the note and no Edit'`, `'Done editing while choosing brings Edit back'`, `'a snack shown while choosing sits above the dock'`.)
2. **The last-used editor is no longer installed (or the stored value is bad).**
   - It loses its place and its pill; the rows are in the default order; no row is read "last used".
   - A corrupt `lastEditor` reads as none and logs only the key.
   - A send that fails, a "not installed" dialog or a dismissed sheet never changes `lastEditor`.
   - (Task 2 `'last used CapCut, now not installed: default order, no pill'`, `'a corrupt lastEditor is none'`, `'not installed, failed and dismissed leave lastEditor alone'`.)
3. **A reel whose live clips go to 0.**
   - With every clip missing, Edit video is not shown.
   - Clips that go missing after the sheet opened: the send fails in the sheet with "shareClipsMissing", choosing does not start, the page stays.
   - Choosing from the sheet while the last chosen clip goes missing: choosing stays on, the dock is off, the hint shows.
   - (Task 1 `'from the sheet, the last chosen clip going missing keeps choosing'`; Task 4 `'every clip missing: no Edit video'`, `'clips gone after the sheet opened: the failure in the sheet, the page stays'`.)
4. **Home at 2× text with Shooting mode on.**
   - At 360 dp: the on card's row 1 fits (the title, "Since …", the switch), Open camera and both chips wrap, the grid is one column, the collapsed header's title does not run into + New, nothing overflows, and the tip still sits under the card when it is due.
   - (Task 6 `'2x text at 360: the chips wrap, no overflow'`; Task 9 `'2x text at 360 with Shooting mode on, both chips and a long name: one column, no overflow, + New reachable'`.)
5. **The To tag badge and the off card's "{n} clips still to tag" disagree.**
   - Both read `pendingClipsProvider` (D-184); skipped clips count in neither; while it loads or fails, the badge is hidden and the off line says "Off · turn it on before you film".
   - They follow one stream together (3 → 1 → 0).
   - While choosing on a reel page the nav pill (and its badge) gives way to the dock and comes back after.
   - (Task 9 `'the off line and the To tag badge count the same clips and follow them together'`; Task 4 `'the nav pill comes back with its badge when choosing ends'`.)

---

## File map

| Area | Create | Modify |
|---|---|---|
| Choosing | — | `app/lib/features/reels/view_models/reel_selection.dart` |
| Last editor | `app/test/features/editors/editor_rows_test.dart` | `domain/models/editor_app.dart`, `data/repositories/phone_state_repository.dart`, `features/editors/view_models/editor_choices.dart`, `features/editors/views/editor_sheet.dart`, `components/grouped_rows.dart` |
| Dock | `components/selection_dock.dart`, `widgetbook/lib/components/selection_dock.dart` | `tt_metrics.dart`, `taketray_ui.dart`, `widgetbook/lib/catalog.dart` |
| Reel page | `features/shell/view_models/choosing_reel.dart`, `features/reels/views/reel_choosing_dock.dart` | `reel_detail_screen.dart`, `features/shell/views/app_shell.dart`, `app/test/support/pump_screen.dart` |
| Picking screen | — | `edit_select_screen.dart`, `edit_select_controller.dart`, `router/routes.dart`, `router/app_router.dart` |
| Home pieces | `components/quiet_tabs.dart`, `widgetbook/lib/components/quiet_tabs.dart` | `shooting_mode_card.dart`, `reel_card.dart`, `app_bar.dart`, `glass.dart`, `status_pill.dart` |
| Home screen | `app/test/features/reels/views/home_golden_test.dart` | `reels_screen.dart`, `shooting_mode_section.dart` |
| Patrol | — | `reels_test.dart`, `editors_test.dart`, `references_test.dart`, `support/reel_finders.dart` |

App paths are under `app/lib/` unless written in full. Component paths are under `packages/taketray_ui/lib/src/`.

---

### Task 1: `ReelSelection` from the sheet, and a Clear that keeps choosing

**Model:** Sonnet. **D-188** (amends D-88).

**Files:**
- Modify: `app/lib/features/reels/view_models/reel_selection.dart` (and its `.g.dart` if codegen changes it).
- Test: `app/test/features/reels/view_models/reel_selection_test.dart`.

**Interfaces:**
- Produces:
  ```dart
  class ReelSelectionState {
    const ReelSelectionState({this.selecting = false, this.selected = const {}, this.fromSheet = false});
    final bool fromSheet; // started by "Choose clips instead"; part of == and hashCode
  }
  // ReelSelection:
  void begin({bool fromSheet = false}); // ⋮ Select clips (false) or the sheet (true); nothing chosen
  void clearChosen();                   // the top bar's Clear: nothing chosen, still choosing, fromSheet kept
  // start, toggle, selectAll, clear: as today, plus the rules below
  ```
- **Rules:**
  - **From the sheet**, choosing stays on with nothing chosen: un-choosing the last clip (`toggle`) and a prune that empties the choice keep `selecting: true, fromSheet: true`.
  - **Held or ⋮** (fromSheet false): as today, un-choosing the last clip ends choosing, and so does a prune that empties a choice that had clips.
  - `selectAll` keeps `fromSheet`; `clear` (Close, Back, a picked editor) ends choosing and drops it.
  - `begin(fromSheet: true)` while already choosing keeps the chosen clips and sets `fromSheet`.

- [ ] **Step 1: Write the failing tests** in `reel_selection_test.dart`:
  ```dart
  test('begin from the sheet: choosing, nothing chosen, fromSheet', …)
      // state == ReelSelectionState(selecting: true, fromSheet: true)
  test('from the sheet, un-choosing the last clip keeps choosing', …)
      // begin(fromSheet: true); toggle(a); toggle(a) → selecting true, selected {}, fromSheet true
  test('from the sheet, the last chosen clip going missing keeps choosing', …)
      // clip a missing in the stream → selecting true, selected {}
  test('held, the last chosen clip going missing ends choosing', …) // existing rule, kept
  test('clearChosen empties and keeps choosing, held or from the sheet', …)
  test('after clearChosen, held: choose one and un-choose it ends choosing', …)
  test('after clearChosen, from the sheet: choose one and un-choose it stays', …)
  test('selectAll keeps fromSheet; clear drops it', …)
  test('begin from the sheet while choosing keeps the clips', …)
  ```
  The existing tests stay as they are (`'toggle to empty ends selection'` is the held rule).
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/reels/view_models/reel_selection_test.dart`. Expected: FAIL (`fromSheet`, `clearChosen` undefined).
- [ ] **Step 3: Implement** the state field and the four rules in `toggle`, `_prune`, `selectAll`, `begin` and `clearChosen`.
- [ ] **Step 4: Run** the same command, then `tool/check`. Expected: PASS; `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop the `fromSheet` check in `toggle`: `'from the sheet, un-choosing the last clip keeps choosing'` fails;
  - drop it in `_prune`: `'… going missing keeps choosing'` fails;
  - make `clearChosen` call `clear`: `'clearChosen empties and keeps choosing'` fails.
- [ ] **Step 6: Docs and commit** `feat(reels): choosing that starts from the editor sheet stays on when empty`.
  - **D-188:** the four rules, why `begin` takes the flag (not `start`, the long press), and that Clear keeps choosing (`editflow.js:88`, `selNone`).
  - D-88 gets "Amended by D-188".
  - `flow.md` "Managing clips in a reel": the two ways choosing ends.

---

### Task 2: The last-used editor, and the editor sheet for every clip

**Model:** Sonnet. **D-189** (amends D-126).

**Files:**
- Modify:
  - `app/lib/domain/models/editor_app.dart`
  - `app/lib/data/repositories/phone_state_repository.dart`
  - `app/lib/features/editors/view_models/editor_choices.dart` (+ `.g.dart`)
  - `app/lib/features/editors/views/editor_sheet.dart`
  - `app/lib/features/editors/views/edit_select_screen.dart` (`_continue` only, temporary until Task 5)
  - `packages/taketray_ui/lib/src/components/grouped_rows.dart` (`TtListRow.titleTag`), `tt_metrics.dart`, `widgetbook/lib/components/grouped_rows.dart`
  - `app/lib/l10n/app_en.arb`
- Create: `app/test/features/editors/editor_rows_test.dart`.
- Test: `app/test/domain/models/editor_app_test.dart`, `app/test/data/repositories/phone_state_repository_test.dart`, `app/test/features/editors/editor_sheet_test.dart`, `editors_golden_test.dart`, `packages/taketray_ui/test/components/grouped_rows_test.dart` and its golden test.

**Interfaces:**
- Produces:
  ```dart
  /// A row of the editor sheet, stored by name in `lastEditor` (a test pins the spelling).
  enum EditorPick { capcut, edits, vn, other }
  extension EditorPickApp on EditorPick { EditorApp? get app; }    // other → null
  EditorPick editorPickOf(EditorApp? app);                          // null → other

  // PhoneStateRepository (key 'lastEditor', JSON string; not in exportedKeys, so
  // never exported, and an import keeps it, like homeTipSeen):
  static const lastEditorKey = 'lastEditor';
  Future<EditorPick?> lastEditor();            // none, or corrupt → null; logs the key only
  Future<void> recordLastEditor(EditorPick pick);

  // editor_choices.dart:
  @riverpod Future<EditorPick?> lastEditor(Ref ref); // a failed read → null, logged by type
  typedef EditorRows = ({List<EditorPick> rows, EditorPick? lastUsed});
  /// The sheet's rows: [last] first when it is `other` or installed, then the
  /// rest in the default order capcut, edits, vn, other. lastUsed is null when
  /// [last] lost its place.
  EditorRows editorRows(EditorPick? last, List<EditorChoice> choices);

  // editor_sheet.dart:
  enum EditorSheetOutcome { dismissed, sent, openedVn, shared, chooseInstead }
  extension EditorSheetOutcomePicked on EditorSheetOutcome { bool get isPicked; } // sent, openedVn, shared
  Future<EditorSheetOutcome> showEditorSheet(
    BuildContext context, {
    required int reelId,
    required List<int> clipIds, // in shooting order
    bool allClips = false,
  });

  // TtListRow: a pill after the title (tertiaryContainer / onTertiaryContainer, labelSmall).
  final String? titleTag;
  ```
- **Rules:**
  - **Title:** `allClips && clipIds.length > 1` → `editorSheetTitleAll(n)`; otherwise `editorSheetTitle(n)` (as today). The subtitle is unchanged.
  - **Choose clips instead** (a text `TtButton` with `Symbols.checklist_rounded`, under the subtitle, `editflow.css:19`) shows only with `allClips && n > 1`. It closes the sheet with `chooseInstead`; nothing is sent or stored. It does nothing while a send runs.
  - **Order and pill:** the sheet watches `lastEditorProvider` and lays out `editorRows(...)`; the `lastUsed` row has `titleTag: l10n.editorLastUsed` and `semanticLabel: l10n.editorLastUsedSemantics(name)`. While `lastEditor` loads: the default order, no pill.
  - **Stored when the hand-off starts:** after `sent`, `openedVn` or `shared`, `showEditorSheet` calls `recordLastEditor` through the container (the sheet is gone by then); a failing write is logged by type and changes nothing else. Not installed, failed, a dismissed sheet and Choose clips instead store nothing.
  - **No route is popped any more:** `_Sent` shows the snack and the Ready offer, and returns `sent`. The picking screen's `_continue` pops itself on `sent` (it did so through the sheet before), until Task 5 removes it.
- **Strings:**
  - `editorSheetTitleAll`: `"{count, plural, other{Edit all {count} clips in…}}"`
  - `editorChooseInstead`: `"Choose clips instead"`
  - `editorLastUsed`: `"Last used"`
  - `editorLastUsedSemantics`: `"{name}, last used"`
- **Metrics** (`editflow.css:18`, `.ed-last`): `listRowTagGap = 8`, `listRowTagPaddingH = 8`, `listRowTagPaddingV = 1`; the pill is a stadium.

- [ ] **Step 1: Write the failing tests.**
  - `editor_app_test.dart`: `'EditorPick names are capcut, edits, vn, other'`; `'editorPickOf and app round-trip'`.
  - `phone_state_repository_test.dart`:
    ```dart
    test('lastEditor: none is null', …)
    test('recordLastEditor then lastEditor reads it back, each value', …)
    test('a corrupt lastEditor is none, and only the key is logged', …) // 'banana', '3', not JSON
    test('lastEditor is not an exported key', …) // !SettingsRepository.exportedKeys.contains(…)
    ```
    and add `lastEditor` to the kept keys of the existing import test (`grep -rn homeTipSeen app/test/data` finds it).
  - `editor_rows_test.dart`:
    ```dart
    test('no last editor: capcut, edits, vn, other; no lastUsed', …)
    test('last used edits: edits first, the rest in order', …)  // [edits, capcut, vn, other]
    test('last used other: other first', …)
    test('last used CapCut, now not installed: default order, no pill', …)
    test('last used VN while asking the phone failed (all installed): vn first', …)
    ```
  - `editor_sheet_test.dart` (open the sheet from a host page's button calling `showEditorSheet`, not through the picking screen; keep the existing groups on that host):
    ```dart
    testWidgets('every clip: "Edit all 14 clips in…" and Choose clips instead', …)
    testWidgets('every clip but only one: "Edit 1 clip in…", no Choose clips instead', …)
    testWidgets('chosen clips: "Edit 3 clips in…", no Choose clips instead', …)
    testWidgets('Choose clips instead returns chooseInstead; nothing sent or stored', …)
    testWidgets('Instagram Edits last used: first, with the pill, read "Instagram Edits, last used"', …)
    testWidgets('last used CapCut, now not installed: default order, no pill', …)
    testWidgets('sent to CapCut: lastEditor capcut, outcome sent, the snack, the host page stays', …)
    testWidgets('VN: lastEditor vn, outcome openedVn, the space check pushed', …)
    testWidgets('Other app…: lastEditor other, outcome shared', …)
    testWidgets('not installed, failed and dismissed leave lastEditor alone', …)
    testWidgets('a lastEditor write that throws still sends; the log has the type only', …)
    ```
  - `grouped_rows_test.dart`: `'titleTag: a pill after the title in tertiaryContainer, labelSmall'`; `'titleTag at 2x text wraps under the title, no overflow at 360'`. Add a `titleTag` scenario to the grouped rows golden.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/domain/models/editor_app_test.dart test/data/repositories/phone_state_repository_test.dart test/features/editors/editor_rows_test.dart test/features/editors/editor_sheet_test.dart` and the package `grouped_rows_test.dart`. Expected: FAIL (undefined names; the sent test fails because the host page is popped).
- [ ] **Step 3: Implement** the enum, the repository pair, the provider and `editorRows`, `TtListRow.titleTag`, and the sheet's title, button, order, pill, outcome and store; the picking screen's `_continue` pops on `sent`.
- [ ] **Step 4: Run** the same tests, then `cd app && ../tool/flutter test --update-goldens test/features/editors/editors_golden_test.dart` with `editor_sheet_all_{1x,2x,dark_1x}` (every clip, Choose clips instead; the old `editor_sheet_all_1x` is replaced), a new `editor_sheet_last_used_{1x,2x,dark_1x}`, and `editor_sheet_missing_*` kept as the chosen-clips state; check them by eye. Update the package macOS goldens. Run `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop the installed check in `editorRows`: `'… now not installed …'` fails (both);
  - record `lastEditor` before the send's answer: `'not installed, failed and dismissed leave lastEditor alone'` fails;
  - put `router.pop()` back in `_Sent`: `'… the host page stays'` fails.
- [ ] **Step 6: Docs and commit** `feat(editors): the editor sheet for every clip, Choose clips instead, and the last-used editor first`.
  - **D-189:** the outcome enum and why the sheet no longer pops; `lastEditor` in `PhoneStateRepository` (a phone habit, not a user setting: not exported, kept by an import); when it is stored; the n > 1 rule from `editflow.js:62–63`; Other app… counts as an editor.
  - D-126 gets "Amended by D-189".
  - `flow.md`: "Picking clips and the editor sheet" (title, button, order, outcome); the onboarding flags paragraph and "Backup export and import" (the kept keys) name `lastEditor`.

---

### Task 3: `TtSelectionDock`

**Model:** Sonnet. **D-190.**

**Files:**
- Create: `packages/taketray_ui/lib/src/components/selection_dock.dart`, `widgetbook/lib/components/selection_dock.dart`, `packages/taketray_ui/test/components/selection_dock_test.dart`, `selection_dock_golden_test.dart`.
- Modify: `tt_metrics.dart`, `packages/taketray_ui/lib/taketray_ui.dart` (export), `widgetbook/lib/catalog.dart`.

**Interfaces:**
- Produces:
  ```dart
  class TtSelectionDockAction {
    const TtSelectionDockAction({required this.icon, required this.label, required this.semanticLabel, this.onPressed});
    final IconData icon; final String label; final String semanticLabel;
    final VoidCallback? onPressed; // null: off (38 %, no tap action for TalkBack)
  }
  class TtSelectionDockEdit {
    const TtSelectionDockEdit({required this.label, required this.semanticLabel, this.detail, this.onPressed});
    final String label;    // "Edit 3 clips" / "Tap the clips you want to edit"
    final String? detail;  // the length, "1:38"
    final String semanticLabel;
    final VoidCallback? onPressed; // null: off (surfaceContainerHighest / onSurfaceVariant)
  }
  class TtSelectionDock extends StatefulWidget {
    const TtSelectionDock({required this.semanticLabel, required this.actions, this.edit, this.note, super.key})
      : assert(actions.length == 4), assert((edit == null) != (note == null));
    final String semanticLabel;                 // the toolbar: "Chosen clips"
    final List<TtSelectionDockAction> actions;  // row 1, evenly spaced
    final TtSelectionDockEdit? edit;            // row 2: the big button …
    final String? note;                         // … or the R1 note with the info icon
  }
  ```
- **Values** (each a `TtMetrics` constant quoting its line):
  - `editflow.css:5`: `surfaceContainer`; top corners 28; padding 10 / 16 / 22, plus `MediaQuery.viewPaddingOf(context).bottom`; gap 8 between the rows; shadow `0 -8px 24px` black 16 %;
  - `editflow.css:7`: four equal columns, gap 4;
  - `editflow.css:8–10`: each action 56 dp tall, radius 16, a 24 dp icon in `onSurfaceVariant` over a `labelMedium` label in `onSurface`, gap 2, padding 4 / 2; off: opacity .38;
  - `editflow.css:11–13`: the Edit button is a filled button, 56 dp, full width: `movie_edit` icon, the label, then `detail` at 80 % in tabular figures (weight 500), gap 8; off: `surfaceContainerHighest` / `onSurfaceVariant`;
  - `editflow.css:14–15`: the note is `bodySmall` `onSurfaceVariant`, an 18 dp `info` icon, gap 8, padding 2 / 4 / 4;
  - `editflow.css:21–22`: at text scale ≥ `TtMetrics.largeTextScale` the actions go two by two and the Edit button's content wraps.
- **Motion:** on its first build it slides up from 100 % of its height over `tt.motion.medium2` with `tt.motion.emphasizedDecelerate` (`editflow.css:6`); with reduced motion it is there at once.
- **Semantics:** a container named `semanticLabel`; each action is one button named `semanticLabel` (no tap action when off); the Edit button is one button named its `semanticLabel`.

- [ ] **Step 1: Write the failing tests** (`selection_dock_test.dart`):
  ```dart
  testWidgets('four actions, 56 dp tall, icon over label, equal widths', …) // widths within 0.5
  testWidgets('an off action is at .38 and has no tap action', …)
      // tester.getSemantics(...) does not have SemanticsAction.tap; onPressed never called
  testWidgets('Edit: label, then the length at .8 and tabular; read by its semanticLabel', …)
  testWidgets('Edit off: surfaceContainerHighest, onSurfaceVariant, no tap', …)
  testWidgets('a note instead of Edit: the 18 dp info icon and the text; no Edit button', …)
  testWidgets('surfaceContainer, 28 dp top corners, padding 10/16/22 plus the gesture inset', …)
      // with MediaQuery viewPadding.bottom 24: bottom padding 46
  testWidgets('slides up over medium2 with emphasizedDecelerate', …)
      // pump(0): offset ≈ its height; pump(medium2): 0
  testWidgets('reduced motion: there at once', …)
  testWidgets('2x text at 360: two by two, no overflow, the Edit content wraps', …)
  testWidgets('a toolbar container named "Chosen clips"', …)
  for (final b in Brightness.values) testWidgets('${b.name}: accessible', …) // expectTtAccessible
  ```
  Golden (`selection_dock_golden_test.dart`, `ttGoldenTest('Selection dock', fileName: 'selection_dock', …)`): **some chosen** (Edit 3 clips · 1:38), **none chosen** (actions off, "Tap the clips you want to edit"), **editing session** (the note).
- [ ] **Step 2: Run** `cd packages/taketray_ui && ../../tool/flutter test test/components/selection_dock_test.dart`. Expected: FAIL (undefined).
- [ ] **Step 3: Implement** `selection_dock.dart`, the metrics, the export, and the widgetbook page with the three states.
- [ ] **Step 4: Run** the tests, then `--update-goldens test/components/selection_dock_golden_test.dart`, check the images by eye, and `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - give an off action its `onTap`: `'an off action … no tap action'` fails;
  - drop the large-text branch: `'2x text at 360 …'` fails (overflow);
  - drop the gesture inset: the padding test fails.
- [ ] **Step 6: Docs and commit** `feat(ui): TtSelectionDock, the bar for chosen clips`.
  - **D-190:** the API (exactly four actions; Edit or a note), the values table with its CSS lines, and why the off actions have no tap action ("not focusable as actions", the handoff).
  - `flow.md` "Design-system pieces for editors" gains the dock.

---

### Task 4: The reel page: Edit video opens the sheet, choosing with the dock

**Model:** Opus. **D-191** (amends D-87, D-88, D-126 and D-184's "on every tab").

**Files:**
- Create:
  - `app/lib/features/shell/view_models/choosing_reel.dart` (+ `.g.dart`)
  - `app/lib/features/reels/views/reel_choosing_dock.dart`
  - `app/test/features/reels/views/reel_choosing_golden_test.dart` (macOS-only, the pattern of `reel_overlays_golden_test.dart`)
- Modify:
  - `app/lib/features/reels/views/reel_detail_screen.dart`
  - `app/lib/features/shell/views/app_shell.dart`
  - `app/test/support/pump_screen.dart` (`inShell`)
  - `app/lib/l10n/app_en.arb`
- Test: `app/test/features/reels/views/reel_selection_screen_test.dart` (the group `'Edit video and Share in the ⋮ menu (Phase 8)'` becomes `'Edit video and the dock (D-191)'`), `reel_detail_screen_test.dart`, `app/test/features/reels/reel_edit_banner_test.dart`, `app/test/features/shell/views/app_shell_test.dart`, `app/test/router/app_router_test.dart` (the Edit video test at :1005).

**Interfaces:**
- Consumes: Task 1 (`begin(fromSheet:)`, `clearChosen`, `fromSheet`), Task 2 (`showEditorSheet(…, allClips:)`, `EditorSheetOutcome`), Task 3 (`TtSelectionDock`).
- Produces:
  ```dart
  /// The reel whose page is choosing clips, if any: AppShell shows its dock in
  /// place of the nav pill (D-191).
  @Riverpod(keepAlive: true)
  class ChoosingReel extends _$ChoosingReel {
    int? build() => null;
    void show(int reelId);
    void hide(int reelId); // only when [reelId] is the one shown
  }
  /// The dock for reel [reelId]'s chosen clips: Share, Add to, Move, Remove, and
  /// Edit {n} clips or the editing note. It owns the actions the selection bar
  /// had (share, the reel picker, remove with Undo) and their one-tap guards.
  class ReelChoosingDock extends ConsumerStatefulWidget { const ReelChoosingDock({required int reelId, super.key}); }
  // pump_screen.dart: pumpScreen(…, inShell: true) puts [screen] in branch 0 of a
  // StatefulShellRoute with the real AppShell (To tag and Settings branches show markers).
  ```
- **Rules:**
  - **Edit video** (the `TtFab`, as today; shown with a live clip, not while choosing, and only with no session, R1) calls `showEditorSheet(context, reelId:, clipIds: <every live clip in shooting order>, allClips: true)` once however fast the taps. On `chooseInstead`: `begin(fromSheet: true)`. `Routes.editSelectOf(… clipIds:)` is no longer called.
  - **Starting:** a long press (`start`), ⋮ **Select clips** (`begin()`), or the sheet (`begin(fromSheet: true)`).
  - **The top bar** (`TtAppBar(selection: true, liveRegion: true)`): Close; `selectionChooseClips` with nothing chosen, else `selectionCount(n)`; then **Select all** (`selectAll`), or **Clear** (`clearChosen`, the existing `editSelectClear`) when every live clip is chosen. Off while the clips are not read. At text scale ≥ 1.5 it is a `TtIconButton` (`select_all` / `deselect`) with the same name (`editflow.css:24–27`). The Add to, Move and Remove icons and the ⋮ (`_SelectionAction`) are gone.
  - **The hint:** with `fromSheet` and nothing chosen, a `TtBanner(kind: info, icon: Symbols.touch_app_rounded, title: chooseClipsHintTitle, body: chooseClipsHintBody)` is the first sliver after the access banner (`editflow.js:37`).
  - **The dock in the shell:** while `selection.selecting`, the page calls `choosingReelProvider.notifier.show(reelId)`; when it ends, `hide(reelId)`. On dispose it hides after the frame, through the notifier it kept from `initState` (a provider must not change while the tree is finalized). `AppShell` shows `ReelChoosingDock(reelId:)` as its `bottomNavigationBar` instead of `TtNavPill` when `choosing != null` **and the current branch is Reels (0)**. While the dock shows, `AppShell` passes the Scaffold's own bottom padding (which includes the dock) to the body instead of the plain safe inset, and the page's last spacer is `MediaQuery.paddingOf(context).bottom + tt.spacing.m` (about 190 dp at 1×, `editflow.js:39`). The floating snacks sit above the Scaffold's bottom bar, so above the dock, with no extra code.
  - **The dock's content:**
    - actions: Share (`Symbols.share_rounded`, `selectionDockShare`, read `reelMenuShare`), Add to (`library_add`, `selectionDockAddTo`, read `selectionAddTo`), Move (`drive_file_move`, `selectionDockMove`, read `selectionMoveTo`), Remove (`playlist_remove`, `selectionDockRemove`, read `selectionRemove`); off with nothing chosen. Share keeps the choice; Add to, Move and Remove end it as today (a failure keeps it);
    - with no session: Edit with `selectionDockEdit(n)`, `detail: formatClipDuration(live length of the chosen)`, read `selectionDockEditSemantics(n, length)`; with nothing chosen `chooseClipsHintTitle`, read `selectionDockEditNoneSemantics`, off. It opens `showEditorSheet(… clipIds: chosen in shooting order)` (not `allClips`); on `outcome.isPicked` the choice ends (`clear`); on `dismissed` it stays;
    - while the session is still loading: Edit, off;
    - with a session: `note: selectionDockEditingNote(editorShortName(editor))`.
  - **Back and Close** end choosing first (the page's `PopScope`, unchanged).
- **Strings:**
  - `selectionChooseClips`: `"Choose clips"`
  - `selectionDockLabel`: `"Chosen clips"`
  - `selectionDockShare`: `"Share"`, `selectionDockAddTo`: `"Add to"`, `selectionDockMove`: `"Move"`, `selectionDockRemove`: `"Remove"`
  - `selectionDockEdit`: `"{count, plural, one{Edit 1 clip} other{Edit {count} clips}}"`
  - `selectionDockEditSemantics`: `"{count, plural, one{Edit 1 clip, {duration}} other{Edit {count} clips, {duration}}}"`
  - `selectionDockEditNoneSemantics`: `"Edit: choose clips first"`
  - `selectionDockEditingNote`: `"This reel is being edited in {editor}. Tap Done editing at the top before sending clips again."`
  - `chooseClipsHintTitle`: `"Tap the clips you want to edit"`
  - `chooseClipsHintBody`: `"Next time, hold a clip to start choosing straight away."`

- [ ] **Step 1: Write the failing tests.** Tests that need the dock use `pumpScreen(…, inShell: true)`.
  - `app_shell_test.dart`:
    ```dart
    testWidgets('choosing on a reel page: the dock instead of the nav pill', …)
    testWidgets('the nav pill comes back with its badge when choosing ends', …) // badge "7" again
    testWidgets('on another tab while a reel page is choosing: the nav pill, not the dock', …)
        // router.go('/to-tag') with choosingReel set: TtNavPill shown; back to Reels: the dock
    testWidgets('hide for another reel changes nothing', …)
    ```
  - `reel_selection_screen_test.dart`, group `'Edit video and the dock (D-191)'` (replaces the ⋮ group):
    ```dart
    testWidgets('Edit video opens the sheet with every live clip in shooting order, "Edit all 3 clips in…"', …)
        // a missing clip is left out; the sheet's clipIds equal the live ids in shooting order
    testWidgets('every clip missing: no Edit video', …)
    testWidgets('Choose clips instead: choosing, nothing chosen, the hint, the dock off', …)
    testWidgets('from the sheet, un-choosing to zero keeps choosing and the hint comes back', …)
    testWidgets('a long press: that clip chosen, no hint; un-choosing it ends choosing', …)
    testWidgets('Edit 2 clips opens the sheet with exactly those, in shooting order', …)
    testWidgets('picking CapCut ends choosing and shows "Sent 2 clips to CapCut"', …)
    testWidgets('dismissing the sheet keeps the choice', …)
    testWidgets('Select all becomes Clear; Clear empties and keeps choosing', …)
    testWidgets('2x text: Select all is its icon with its name; the count does not overflow', …)
    testWidgets('the top bar has no Add to, Move, Remove or ⋮', …)
    testWidgets('during a session the dock has the note and no Edit', …)        // VN and CapCut sessions
    testWidgets('while the session loads, Edit is off', …)
    testWidgets('Done editing while choosing brings Edit back', …) // the choice stays
    testWidgets('Share keeps the choice; Remove ends it with Undo', …)
    testWidgets('a snack shown while choosing sits above the dock', …)
        // a remove that throws CopiesNotDeleted: the snack's bottom ≤ the dock's top; choice kept
    testWidgets('clips gone after the sheet opened: the failure in the sheet, the page stays', …)
    testWidgets('the last row scrolls clear of the dock, at 1x and 2x', …)
    testWidgets('Back ends choosing, then leaves the page', …)
    ```
    The existing add, move, remove and picker groups find their buttons through the dock (`find.descendant(of: find.byType(TtSelectionDock), …)`); their assertions do not change.
  - `reel_edit_banner_test.dart`: the R1 FAB tests stay; `'Edit video waits for Done editing (R1)'` is unchanged.
  - `app_router_test.dart:1005`: the test becomes `'Edit video opens the editor sheet over the reel page'` (no `EditSelectScreen`, the nav pill stays).
  - The golden `reel_choosing_golden_test.dart`: `reel_choosing_{some,none,session}_{light,dark}` and `reel_choosing_some_2x` (screen 8's states).
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/shell/views/app_shell_test.dart test/features/reels/views/reel_selection_screen_test.dart test/features/reels/views/reel_detail_screen_test.dart test/features/reels/reel_edit_banner_test.dart test/router/app_router_test.dart`. Expected: FAIL (undefined names; the sheet is not opened; no dock).
- [ ] **Step 3: Implement** `ChoosingReel`, `ReelChoosingDock` (the page's `_share`, `_pickReels`, `_removeChosen` and `_chosenInOrder` move into it), `AppShell`'s slot and padding, and the page's Edit video, top bar, hint, `show`/`hide` and spacer. Remove `_SelectionAction`, `_openEdit`'s clip ids and the selection ⋮.
- [ ] **Step 4: Run** the same command, then `--update-goldens test/features/reels/views/reel_choosing_golden_test.dart` (check by eye) and `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop the branch check in `AppShell`: `'on another tab … the nav pill, not the dock'` fails;
  - pass `allClips: false` from Edit video: `'Edit video opens the sheet … "Edit all 3 clips in…"'` fails;
  - clear the choice on `dismissed` too: `'dismissing the sheet keeps the choice'` fails;
  - put back the plain safe inset while the dock shows: `'the last row scrolls clear of the dock'` fails.
- [ ] **Step 6: Docs and commit** `feat(reels): Edit video opens the editor; chosen clips get the dock`.
  - **D-191:** the starting points; the top bar; the hint's place; why the dock takes the nav pill's place in `AppShell` (the prototype's reel page has no nav pill, while the app keeps it, D-87; one bottom bar at a time; snacks above it for free); the branch check; the To tag badge is hidden while choosing (amends D-184 point 4); `Other app…` ends choosing like the other editors; R1 in the dock.
  - D-87, D-88 and D-126 get "Amended by D-191".
  - `flow.md`: "Opening a reel" (Edit video), "Managing clips in a reel" (the dock), "Tab navigation" (the bottom slot).

---

### Task 5: The picking screen keeps only add mode

**Model:** Sonnet. **D-192** (amends D-126).

**Files:**
- Modify: `app/lib/features/editors/views/edit_select_screen.dart`, `app/lib/features/editors/view_models/edit_select_controller.dart` (+ `.g.dart`), `app/lib/router/routes.dart`, `app/lib/router/app_router.dart`, `app/lib/features/reels/views/reel_detail_screen.dart` (`_openAdd`, the one caller), `app/test/support/pump_screen.dart` (the `/edit` marker), `app/lib/l10n/app_en.arb`.
- Test: `edit_select_screen_test.dart`, `edit_select_controller_test.dart`, `editors_golden_test.dart`, `app/test/router/app_router_test.dart`, `app/test/l10n/app_localizations_test.dart`.

**Interfaces:**
- Produces:
  ```dart
  static String editAddOf(int reelId); // '/edit?reel=7&add=1'; editSelectOf is removed
  const EditSelectScreen({required int reelId, super.key}); // always add mode
  // EditSelectController's family argument is `int reelId` (EditSelectArgs goes)
  ```
- **Rules:**
  - The `/edit` route builds add mode only. A location without `add=1` (or with `clips=`) redirects to `Routes.reel(id)` and logs `'Picking screen without add mode; showing the reel'` (no location, D-10). A location with no valid reel still goes to Reels.
  - Remove the normal mode: `preselected`, the `addMode` flag, `pickedInOrder`, `pickedDurationMs`, `pickedBytes`, `_continue`, `_sheetOpen`, the normal bottom bar, Task 2's temporary pop, and their tests and the goldens `edit_select_none_1x.png` and `edit_select_picked_{1x,2x,dark_1x}.png`.
  - Remove the strings `editSelectTitle`, `editBarNone`, `editBarNoneHint`, `editBarPicked`, `editBarPickedDetail` and `editContinue`. `editSelectClear`, `editSelectInfo` and `selectionSelectAll` stay (add mode and Task 4 use them).
  - Add mode's look, words, ticks, locks, Copy and leaving rules do not change.

- [ ] **Step 1: Characterization first:** run the add-mode groups of `edit_select_screen_test.dart` (`'add mode (VN add-later)'`, `'add mode (CapCut and Edits, D-129)'`, `'the app bar (T12-m3)'`) and `edit_select_controller_test.dart`'s add-mode tests. Expected: PASS; record it. They must stay green unchanged except for the constructor and the family argument.
- [ ] **Step 2: Write the failing tests:**
  ```dart
  test('editAddOf(7) is /edit?reel=7&add=1', …)                          // routes
  testWidgets('/edit?reel=7 without add=1 shows the reel page', …)        // app_router_test
  testWidgets('/edit?reel=7&clips=1,2 shows the reel page', …)
  testWidgets('Add more clips opens the picking screen in add mode', …)   // still, through editAddOf
  ```
- [ ] **Step 3: Run** `cd app && ../tool/flutter test test/router/app_router_test.dart test/features/editors/`. Expected: FAIL (`editAddOf` undefined; the redirect is missing).
- [ ] **Step 4: Implement** the route, the screen, the controller and the callers; delete the normal mode, its strings, tests and goldens; regenerate.
- [ ] **Step 5: Run** the same command and `tool/check`. Expected: PASS; the characterization tests still green; `ALL CHECKS PASSED`.
- [ ] **Step 6: Mutation check:** remove the redirect: `'/edit?reel=7 without add=1 shows the reel page'` fails.
- [ ] **Step 7: Docs and commit** `refactor(editors): the picking screen is only for adding clips to an edit`.
  - **D-192:** what goes, the redirect for an old location, and that hub screen 18 is now "Add clips to a VN edit".
  - D-126 gets "Amended by D-192".
  - `flow.md` "Picking clips and the editor sheet": add mode only.

---

### Task 6: The compact Shooting mode card

**Model:** Sonnet. **D-193** (amends D-46, D-79, D-90's off row, D-160's row).

**Files:**
- Modify: `packages/taketray_ui/lib/src/components/shooting_mode_card.dart`, `tt_metrics.dart`, `widgetbook/lib/components/shooting_mode_card.dart`.
- Test: `packages/taketray_ui/test/components/shooting_mode_card_test.dart`, `shooting_mode_card_golden_test.dart` (delete `shooting_mode_card_off_rows_*` in both sets), `glass_pixels_test.dart` (the references-row case becomes the chip case).
- Callers: `app/lib/features/shooting_mode/views/shooting_mode_section.dart` is changed in Task 9; until then it compiles against a stop-gap: pass `chips: const []` and drop `rows` / `toTagStrip`. Its tests for the rows, the strip and the banner are marked `skip: 'Task 9'` here; Task 9 rewrites them for the chips and the off line, or deletes those whose behaviour the design removes (the strip, the banner), naming each in its report.

**Interfaces:**
- Produces:
  ```dart
  class TtShootingCardChip {
    const TtShootingCardChip({required this.icon, required this.label, required this.semanticLabel, required this.onPressed});
  }
  TtShootingModeCard({
    required bool on, required String title, required String subtitle,
    required String semanticLabel, required String switchSemanticLabel,
    required ValueChanged<bool> onChanged,
    ImageProvider? backdrop, String? cameraLabel, VoidCallback? onOpenCamera,
    List<TtShootingCardChip> chips = const [], // ≤ 2; shown only when on
  })
  ```
  Removed: `rows`, `toTagStrip`, `TtCardRow`, `TtCardRowKind`, `_OffCardScope`, and the `cardRow*` / `cardStrip*` metrics.
- **Values** (`home2.css`, each quoted):
  - `:8`: radius 24 (`tt.radii.xxl`); the section gives the 4 / 16 / 12 margins;
  - `:9` off: `surfaceContainerLow`, no border, padding 10 / 6 / 10 / 12, gap 12;
  - `:10` on: black, padding 12, gap 12 between the rows; `:11` the tint at 160°: `.86`, `.40` at 60 %, black `.55` (`shootingTintStartOpacity`, `…MiddleOpacity`, `…MiddleStop`, `…EndOpacity` take these values); `:17` the backdrop at `.55`;
  - `:19–21` the icon tile: 40 dp, radius 14, `videocam` 22 filled; off `secondaryContainer` / `onSecondaryContainer`; on white 16 % glass (`TtGlassFill`, blur 8 as today); the REC dot 2 dp outside its top end corner with a 2 dp black ring;
  - `:23–24`, `:14–15` the text: `titleMedium` (on: weight 800, white) over `bodySmall` (`onSurfaceVariant`; on: white 85 %);
  - `:25` row 2 wraps, gap 8; `:26–27` Open camera: a white pill, 40 dp, padding 0 16 0 12, `videocam` 20, `labelLarge`, black text; `:28–29` a chip: 40 dp (48 dp target), padding 0 14 0 10, gap 6, `labelLarge` white, an 18 dp icon, `TtGlassFill(blur: 10, fill: white .14)` in a stadium.
- **Motion:** one widget tree for on and off, so the `TtSwitch` element (and TalkBack's focus on it) survives a toggle. The height animates with `AnimatedSize(tt.motion.medium2, tt.motion.emphasized)`; the black layer and Open camera fade in over `medium2`. A chip never has an `Opacity` or `FadeTransition` above its `BackdropFilter`: its blur is a steady 10 from the first frame (a growing blur was lost on the S24, D-172), and only its fill's alpha (0 → .14) and an `Opacity` on its content, inside the fill, fade in. With reduced motion the size change is instant and the fades remain.

- [ ] **Step 1: Write the failing tests** (`shooting_mode_card_test.dart`):
  ```dart
  testWidgets('off: one row; 40 dp tile on secondaryContainer; surfaceContainerLow; padding 10/6/10/12; radius 24', …)
  testWidgets('off: no camera and no chips, even when given', …)
  testWidgets('on: row 1, then Open camera (white pill, 40 dp, black text), then the chips', …)
  testWidgets('on with no chips: Open camera alone', …)
  testWidgets('a chip: 40 dp, 48 dp target, white text, 18 dp icon, one button named its semanticLabel', …)
  testWidgets('the REC dot sits 2 dp outside the tile's top end corner, with a 2 dp black ring', …)
  testWidgets('the tint is 160°, .86 → .40 at 60 % → black .55; the backdrop at .55', …)
  testWidgets('switching on: the same TtSwitch element; the height animates over medium2', …)
  testWidgets('no Opacity or FadeTransition above a chip's BackdropFilter, also mid-fade; sigma 10 from the first frame', …)
  testWidgets('reduced motion: no size animation', …)
  testWidgets('2x text at 360: the chips wrap, no overflow', …)       // Review Focus 4
  testWidgets('white chip text is AA over a white backdrop', …)       // ttTextContrastGuideline
  for (final b in Brightness.values) testWidgets('${b.name}: on and off accessible', …)
  ```
  In `glass_pixels_test.dart`: `'every BackdropFilter has a plain fill first'` gains the on card with two chips; add `'a Shooting mode chip blurs by 10 under its .14 white'` (`expectBlurFilter(…, 10)`, `expectBlurred(c, sharp: s, fillOpacity: .14)`); remove `'Shooting mode references row blurs by 6'`; keep `'Shooting mode icon tile blurs by 8'`.
  Golden scenarios (`shooting_mode_card_{light,dark}`): off, nothing waiting; off, 23 waiting; on with both chips and a backdrop; on in Manual mode with no chips; on with no backdrop.
- [ ] **Step 2: Run** `cd packages/taketray_ui && ../../tool/flutter test test/components/shooting_mode_card_test.dart test/components/glass_pixels_test.dart`. Expected: FAIL (`chips` undefined; old look).
- [ ] **Step 3: Implement** the card, the chip, the metrics and the widgetbook page; remove the rows, the strip and their metrics; apply the stop-gap in `shooting_mode_section.dart`.
- [ ] **Step 4: Run** the tests, update the package macOS goldens, check by eye, and run `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - put a `Material(color: …)` as the chip filter's child: the structure test fails;
  - key the on and off trees separately: `'switching on: the same TtSwitch element …'` fails;
  - fade a chip with a `FadeTransition` around it: `'no Opacity or FadeTransition above a chip's BackdropFilter …'` fails.
- [ ] **Step 6: Docs and commit** `feat(ui): the compact Shooting mode card with glass chips`.
  - **D-193:** the API, the values with their CSS lines, the one-tree rule (focus survives a toggle), the fade that never wraps a filter, and what is removed. D-46 and D-79 get "Amended by D-193".
  - `flow.md` "To tag, the Shooting mode card and Add earlier videos": the card's two layouts.

---

### Task 7: The calm reel card

**Model:** Sonnet. **D-194** (amends D-46, D-158's Home badge, D-173's audit table).

**Files:**
- Modify: `packages/taketray_ui/lib/src/components/reel_card.dart`, `tt_metrics.dart`, `widgetbook/lib/components/reel_card.dart`.
- Remove, after `grep` shows no other user (the card was the only one): `TtGlassPill` (`glass.dart`) and `TtStatusPill`'s `onMedia` variant (`status_pill.dart`), with their tests, golden scenarios, pixel tests (`'status pill on media …'`, `'Editing in VN pill …'`, `'reel card references badge …'`) and widgetbook use cases; the `reelCard*` and `refBadge*` metrics nothing reads any more.
- Test: `reel_card_test.dart`, `reel_card_golden_test.dart`, `glass_pixels_test.dart`, `status_pill_test.dart`, `glass_test.dart`.
- Caller stop-gap: `app/lib/features/reels/views/reels_screen.dart` passes the new arguments (notes built as in Task 9); its references badge tests are skipped with `skip: 'Task 9'`.

**Interfaces:**
- Produces:
  ```dart
  enum TtReelCardNoteKind { editing, missing, references }
  class TtReelCardNote { const TtReelCardNote(this.kind, this.text); final TtReelCardNoteKind kind; final String text; }
  TtReelCard({
    required String name, required String semanticLabel,
    required TtStatusKind status, required String statusLabel,
    required String meta,                 // "14 clips · 5:30" or "No clips yet"
    ImageProvider? cover,                 // null: the movie icon
    List<TtReelCardNote> notes = const [],
    VoidCallback? onTap,
  })
  ```
  Removed: `emptyLabel`, `missingText`, `vnLabel`, `referenceCount`, `referencesSemanticLabel`, `onReferencesTap`, the scrim, the pills, the badge and the text-scale clamp.
- **Values** (`home2.css`):
  - `:56` a column, gap 8 between the cover and the caption; `:58` the cover is full width, 3:4, radius 20, `surfaceContainerHigh`, nothing on it; `:34`, `:59` no cover (or one that fails): `movie` 28 in `onSurfaceVariant`, centred;
  - while a cover decodes: `TtSkeletonLine`-style shimmer filling the same 3:4 box (`Image.frameBuilder`), so nothing jumps;
  - `:60–61` the caption: padding 0 4, gap 2; the name `titleSmall`, up to 2 lines;
  - `:35–39` the status mark: a 14 dp filled icon (collecting `radio_button_checked` in `error`, ready `content_cut` in `tertiary`, published `check_circle` in `primary`), gap 4, the word in `labelMedium` `onSurfaceVariant`;
  - `:40` the meta: `bodySmall` `onSurfaceVariant`, tabular;
  - `:41–45` the notes: a `Wrap` (spacing 10, run 4) of `labelSmall` items, a 14 dp icon, gap 3: editing `folder_copy` filled in `primary`, missing `error` filled in `error`, references `link` in `onSurfaceVariant`.
- **Press** (`home2.css:57`): scale `.98` over `tt.motion.short3` with `tt.motion.standard` while pressed, back on release; none with reduced motion. One `Semantics` button named `semanticLabel`, `excludeSemantics: true`.

- [ ] **Step 1: Write the failing tests** (`reel_card_test.dart`):
  ```dart
  testWidgets('nothing on the cover: no pill, no scrim, no BackdropFilter in the card', …)
  testWidgets('the cover is 3:4 and radius 20 at the card's width', …)
  testWidgets('no cover: movie 28 on surfaceContainerHigh', …)
  testWidgets('a cover that fails: the movie icon', …)
  testWidgets('a cover still decoding: a skeleton in the same 3:4 box; the card's height does not change when it lands', …)
  testWidgets('status marks: icon and colour per status, the word always there in onSurfaceVariant', …)
  testWidgets('notes only when given, in order, with their icons and colours', …)
  testWidgets('one button read as semanticLabel; nothing inside is its own node', …)
  testWidgets('a press scales to .98 over short3 and back', …)
  testWidgets('reduced motion: no scale', …)
  testWidgets('2x text at 158 and at 328 dp: no overflow', …)
  for (final b in Brightness.values) testWidgets('${b.name}: accessible', …)
  ```
  Golden (`reel_card_{light,dark}`): collecting with cover; ready; published; no clips; 2 missing; editing, 2 missing and 3 references; a long name; a cover still decoding.
- [ ] **Step 2: Run** `cd packages/taketray_ui && ../../tool/flutter test test/components/reel_card_test.dart`. Expected: FAIL (`notes` undefined; the old overlays).
- [ ] **Step 3: Implement** the card, remove the overlays, the badge, `TtGlassPill`, `onMedia` and the unused metrics, update the widgetbook pages, and apply the caller stop-gap.
- [ ] **Step 4: Run** the card, status pill, glass and pixel tests, update the package macOS goldens (by eye), and `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - give the cover a fixed `AspectRatio(0.8)`: `'the cover is 3:4 …'` fails;
  - drop the `frameBuilder` skeleton: `'… does not change when it lands'` fails;
  - drop `excludeSemantics`: `'one button read as semanticLabel …'` fails.
- [ ] **Step 6: Docs and commit** `feat(ui): the calm reel card (the cover alone, the text under it)`.
  - **D-194:** the API, the values, the skeleton, the removals (with D-173's audit table amended: the cover pill and the badge are gone). D-46 and D-158 get "Amended by D-194".
  - `flow.md` "Home, the Reels tab": the card.

---

### Task 8: Quiet tabs, the "+ New" pill and the collapsing header

**Model:** Sonnet. **D-195.**

**Files:**
- Create: `packages/taketray_ui/lib/src/components/quiet_tabs.dart`, `widgetbook/lib/components/quiet_tabs.dart`, `packages/taketray_ui/test/components/quiet_tabs_test.dart`, `quiet_tabs_golden_test.dart`.
- Modify: `app_bar.dart` (`TtHeaderPill`, `TtLargeSliverAppBar`), `app_bar_test.dart`, `tt_metrics.dart`, `taketray_ui.dart`, `widgetbook/lib/catalog.dart`, `widgetbook/lib/components/app_bar.dart`.

**Interfaces:**
- Produces:
  ```dart
  class TtQuietTab<T> {
    const TtQuietTab(this.value, this.label, this.count, {required this.semanticLabel});
    final T value; final String label; final int count; final String semanticLabel;
  }
  class TtQuietTabs<T> extends StatelessWidget {
    const TtQuietTabs({required this.tabs, required this.value, required this.onChanged, required this.semanticLabel, super.key});
  }
  /// The header button: "+ New".
  class TtHeaderPill extends StatelessWidget {
    const TtHeaderPill({required this.icon, required this.label, required this.semanticLabel, required this.onPressed, super.key});
  }
  /// A large title that shrinks into a pinned bar as the page scrolls
  /// (`SliverAppBar.large`, on `surface`, no tint, the status bar style of TtAppBar).
  class TtLargeSliverAppBar extends StatelessWidget {
    const TtLargeSliverAppBar({required this.title, this.actions = const [], super.key});
  }
  ```
  `TtPillTabs` stays as it is (the date range picker uses it).
- **Values:**
  - tabs, `home2.css:50–54`: one row that scrolls sideways with no scrollbar, padding 0 12 10, gap 4; each tab 40 dp (48 dp target), padding 0 14, `labelLarge`, the label then the count (tabular, at .8), gap 6; chosen `secondaryContainer` / `onSecondaryContainer`; the others transparent / `onSurfaceVariant`;
  - the pill, `home2.css:4–5`: `secondaryContainer` / `onSecondaryContainer`, 40 dp (48 dp target), padding 0 16 0 12, gap 4, `add` 20, `labelLarge`, 12 dp from the edge;
  - the header: the expanded title is `tt.text.pageTitle` (headlineMedium), as `TtAppBar(large: true)`.
- **Semantics:** the tabs are a container named `semanticLabel` ("Show reels"); each tab is one button named its `semanticLabel`, with `toggled: chosen` (the handoff's `aria-pressed`). The pill is one button named `semanticLabel`.

- [ ] **Step 1: Write the failing tests:**
  ```dart
  testWidgets('the chosen tab is filled secondaryContainer; the others are transparent', …)
  testWidgets('a tab is 40 dp with a 48 dp target; the count is tabular at .8', …)
  testWidgets('a tap calls onChanged with its value', …)
  testWidgets('a group named "Show reels"; each tab read by its label and toggled when chosen', …)
  testWidgets('one row that scrolls sideways at 360 and at 2x, with no scrollbar', …)
  testWidgets('the header pill: 40 dp, 48 dp target, read "New reel", calls onPressed', …)
  testWidgets('the large header collapses on scroll and its action stays hit-testable', …)
  testWidgets('2x text: the collapsed title does not run into the action', …)
  for (final b in Brightness.values) testWidgets('${b.name}: accessible', …)
  ```
  Golden `quiet_tabs_{light,dark}`: All chosen; Ready chosen; the header pill.
- [ ] **Step 2: Run** `cd packages/taketray_ui && ../../tool/flutter test test/components/quiet_tabs_test.dart test/components/app_bar_test.dart`. Expected: FAIL (undefined).
- [ ] **Step 3: Implement** the three widgets, the metrics, the exports and the widgetbook pages.
- [ ] **Step 4: Run** the tests, update the package macOS goldens (by eye), and `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop `toggled`: the group test fails;
  - make the header bar non-pinned: `'… its action stays hit-testable'` fails.
- [ ] **Step 6: Docs and commit** `feat(ui): quiet tabs, the header pill and the collapsing large header`.
  - **D-195:** why a new tab widget instead of a `TtPillTabs` style (other colours, size and count; the date picker keeps the old look), `toggled` for `aria-pressed`, and the header.

---

### Task 9: Home, the calm grid

**Model:** Opus. **D-196** (amends D-76, D-86, D-90, D-158, D-160; carries D-186).

**Files:**
- Create: `app/test/features/reels/views/home_golden_test.dart` (macOS-only).
- Modify:
  - `app/lib/features/reels/views/reels_screen.dart`
  - `app/lib/features/shooting_mode/views/shooting_mode_section.dart`
  - `app/lib/l10n/app_en.arb`
  - `app/lib/features/shooting_mode/views/waiting_duration_text.dart` (delete with its test if `grep` shows no other user)
- Test: `reels_screen_test.dart`, `reels_tab_test.dart`, `shooting_mode_section_test.dart` (un-skip Task 6's and Task 7's moved tests and rewrite them), `shooting_tip_test.dart` and its golden, `app/test/app_test.dart:275`.

**Interfaces:**
- Consumes: Tasks 6, 7 and 8.
- **Rules, the section:**
  - **Off:** `title: shootingOffTitle`; `subtitle: shootingOffWaiting(n)` when `pendingClipsProvider` has n > 0, else `shootingOffIdle` (also while it loads or fails); no chips; **no To tag banner** and no strip (D-186, D-187).
  - **On:** `title: shootingOnTitle`, `subtitle: shootingOnSubtitle(time)` or `shootingOnSubtitleManual(time)`; chips, in order:
    - **References · n** (`Symbols.link_rounded`, label `referencesHeader(n)`, read `shootingReferencesChipLabel(n)`) when `shootingReferenceCount` > 0 (D-160's source: Collecting and Ready to edit reels); it opens `showShootingReferencesSheet`;
    - **Earlier videos** (`Symbols.history_rounded`, label `shootingEarlierChip`, read `earlierCardRowLabel`) when access is full and nothing was added this session (the handoff, home-calm-grid.md:46; D-187 overrides D-90's "stays after an add", controller ruling R12B-2).
  - The off card has no Add earlier videos row (the design's one row); To tag's ⋮ keeps **Add earlier videos**.
  - The margins are 4 / 16 / 12 (`home2.css:8`); the tip (`ShootingTip`, `ShootingCardHighlight`, `_MarkTipSeen`) is unchanged.
- **Rules, the screen** (`home2.js:56–68`):
  - a `CustomScrollView` of: `TtLargeSliverAppBar(title: navReels, actions: [TtHeaderPill(icon: add, label: reelsNew, semanticLabel: reelsNewReel, onPressed: showReelForm)])`, shown with or without reels; the section; the tabs (when reels exist); the grid, the filter's empty block or the first-time empty state (unchanged, with its New reel button); the nav pill's room (`TtNavPill.reservedHeight`). **No FAB.**
  - the tabs: `TtQuietTabs<ReelFilter>(semanticLabel: reelTabsLabel)` with labels All / Collecting / `reelTabReady` / Published, their counts, read `reelFilterChipSemantics(statusName or All, count)`;
  - an empty tab: `reelTabEmpty(statusName)` (`bodyMedium`, `onSurfaceVariant`, centred) over **Show all reels** (tonal), margin 24 / 16 (`home2.css:46`);
  - the grid (`home2.css:55`): rows of two built lazily (`SliverList.builder`, each row a `Row` with `crossAxisAlignment: start` and `Expanded` cards), padding 0 16, 16 dp between rows and 12 between columns; one column at text scale ≥ `TtMetrics.largeTextScale`;
  - the card: `meta` is `reelCardMeta(…)` or `reelCardEmptyArt` ("No clips yet"); notes: editing `reelCardInEditor(editorShortName)`, missing `reelCardMissing(n)`, references `'$n'`; `semanticLabel`: the existing base (`reelCardSemantics` / `…Missing`), then `reelCardSemanticsEditing`, then `reelCardSemanticsReferences` when n > 0, giving "London Food. Collecting. 14 clips, 2 missing. Editing in VN. 2 references";
  - Home no longer opens `Routes.reelReferences` (the badge is gone; the route stays for the Shooting mode references sheet);
  - switching tabs: the grid fades in over `tt.motion.short4` (`SliverFadeTransition` on a controller restarted by `setFilter`; nothing slides); with reduced motion the fade is instant;
  - opening a reel keeps today's route transition. The container transform needs the `animations` package (a new dependency) and is parked in `later.md` for the owner.
- **Strings:**
  - `reelsNew`: `"New"`
  - change `shootingOnTitle` to `"Shooting"`, `shootingOnSubtitle` to `"Since {time}"`, `shootingOnSubtitleManual` to `"Since {time} · Manual mode"`
  - `shootingOffWaiting`: `"{count, plural, one{Off · 1 clip still to tag} other{Off · {count} clips still to tag}}"`
  - `shootingOffIdle`: `"Off · turn it on before you film"`
  - `shootingEarlierChip`: `"Earlier videos"`
  - `shootingReferencesChipLabel`: `"References, {count}, from your Collecting and Ready to edit reels"` (owner to confirm; the prototype says "from your Collecting reels" but the count follows D-160)
  - `reelTabReady`: `"Ready"`, `reelTabsLabel`: `"Show reels"`, `reelTabEmpty`: `"No reels marked {status} yet."`
  - `reelCardInEditor`: `"In {editor}"`
  - `reelCardSemanticsReferences`: `"{card}. {count, plural, =1{1 reference} other{{count} references}}"`
  - remove: `shootingStripTitle`, `shootingStripAction`, `clipsWaitingTitle`, `clipsWaitingBody`, `shootingOffSubtitle`, `earlierCardRowSubtitle`, `earlierCardRowSubtitleOff`, `earlierCardRowLabelOff`, `reelFilterChip`, `reelFilterEmptyTitle`, `reelFilterEmptyCollecting`, `reelFilterEmptyReady`, `reelFilterEmptyPublished`. (`reelCardReferences` goes in Task 10 with its last Patrol user.)

- [ ] **Step 1: Write the failing tests.**
  - `shooting_mode_section_test.dart`:
    ```dart
    testWidgets('off with 23 waiting: "Off · 23 clips still to tag"; 1: "Off · 1 clip still to tag"', …)
    testWidgets('off with none, while loading, and after an error: "Off · turn it on before you film"', …)
    testWidgets('no strip and no To tag banner, on or off, with clips waiting', …)
    testWidgets('on: "Shooting", "Since 9:41 AM"; Manual mode: "Since 9:41 AM · Manual mode"', …) // and the 24-hour, date and midnight tests on the new words
    testWidgets('chips: References · 3 while on with references; Earlier videos with full access', …)
    testWidgets('no chips in Manual mode with no references', …)
    testWidgets('Earlier videos is hidden after an add this session (handoff :46, R12B-2)', …)
    testWidgets('off: no Add earlier videos on the card', …)
    testWidgets('the References chip opens the sheet; Earlier videos opens Add earlier videos', …)
    testWidgets('the References chip is read "References, 3, from your Collecting and Ready to edit reels"', …)
    ```
  - `reels_screen_test.dart`:
    ```dart
    testWidgets('+ New in the header opens the form, with or without reels; read "New reel"', …)
    testWidgets('no FAB', …)
    testWidgets('the screen is in order: header, banner, Shooting mode, tabs, cards', …)
    testWidgets('tabs: All 4, Collecting 2, Ready 1, Published 1; All chosen', …)
    testWidgets('a tab narrows the cards; an empty one says "No reels marked Published yet." and Show all reels', …)
    testWidgets('two columns, 16 × 12, top aligned: a two-line name does not stretch its neighbour', …)
    testWidgets('2x text: one column', …)
    testWidgets('the card is read "London Food. Collecting. 14 clips, 2 missing. Editing in VN. 2 references"', …)
    testWidgets('notes: In VN, 2 missing, 2; none for a plain reel', …)
    testWidgets('a card press scales to .98 and opens the reel once (double tap too)', …)
    testWidgets('switching tabs fades the grid in over short4', …)
    testWidgets('the title collapses on scroll; + New stays in the bar, hit-testable', …)
    testWidgets('2x text at 360 with Shooting mode on, both chips and a long name: one column, no overflow, + New reachable', …) // Review Focus 4, light and dark
    testWidgets('20+ reels build lazily', …)   // existing, on rows
    testWidgets('while the list loads nothing says "no reels" yet', …) // existing
    ```
    Delete the FAB, the references badge and the old filter-empty tests.
  - `reels_tab_test.dart` (the real shell):
    ```dart
    testWidgets('the off line and the To tag badge count the same clips and follow them together', …)
        // one pendingClips stream 3 → 1 → 0: "Off · 3 clips still to tag" with badge 3, then 1 and 1,
        // then "Off · turn it on before you film" with no badge; a skipped clip is in neither
    ```
    Its FAB assertions (:69, :83, :143, :163) become `TtHeaderPill` assertions.
  - `shooting_tip_test.dart`: `'the tip sits under the compact card'` (its top is below the card's bottom; the ring hugs the card).
  - `app_test.dart:275`: still one `TtShootingModeCard`, off.
  - `home_golden_test.dart`: `home_{off_waiting,on_chips,empty_tab,no_reels}_{light,dark}_{1x,2x}` (screen 6's states).
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/shooting_mode/ test/features/reels/views/ test/app_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the section, the screen and the strings; remove the FAB, the banner, `_FilterChips`, `_openReferences` and the unused strings and helper.
- [ ] **Step 4: Run** the same command, then `--update-goldens` for `home_golden_test.dart` and the shooting tip goldens (by eye), and `tool/check`: `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - count `skippedCount` in the off line: the agreement test fails;
  - use `SliverGrid` with a fixed aspect: `'… top aligned …'` fails;
  - drop the large-text column switch: `'2x text: one column'` fails;
  - show the banner again while off: `'no strip and no To tag banner …'` fails.
- [ ] **Step 6: Docs and commit** `feat(reels): Home becomes the calm grid`.
  - **D-196:** the layout and its CSS lines; the off line's source (D-184's stream); the off card without Add earlier videos (the design; To tag's ⋮ keeps it) and the on chip hidden after an add this session (the handoff and `home2.js`'s `earlierUsed`, over D-90; ruling R12B-2); the References chip's words; the fade; no container transform (dependency rule).
  - D-76, D-86, D-90, D-158 and D-160 get "Amended by D-196"; D-186 and D-187 get "Built in Phase 12B (D-193, D-194, D-195, D-196)".
  - `flow.md`: "Home, the Reels tab", "To tag, the Shooting mode card and Add earlier videos", "The Shooting mode References row and sheet" (now a chip).

---

### Task 10: Patrol: the flows on the new controls (no device)

**Model:** Sonnet. **D-197.**

**Files:**
- Modify:
  - `app/patrol_test/support/reel_finders.dart`, `app/test/patrol_support/reel_finders_test.dart`, `app/test/patrol_support/references_source_test.dart`
  - `app/patrol_test/reels_test.dart`, `editors_test.dart`, `references_test.dart`
  - `app/lib/l10n/app_en.arb` (remove `reelCardReferences`)
  - `docs/dev-setup.md` ("Running `editors_test.dart`", "Running `reels_test.dart`", "Running `references_test.dart`"), `docs/flow.md` ("On-device test (Patrol)")
- Check only: `onboarding_test.dart`, `add_videos_test.dart`, `share_test.dart` (they find `TtReelCard` by its name, the tip by its words and the card's one `TtSwitch`; all still hold). Record "no change needed" or fix what `analyze` shows.

**Interfaces:**
- Produces (`reel_finders.dart`; `referencesBadgeOf` is removed):
  ```dart
  Finder newReelButton();             // the TtHeaderPill read reelsNewReel
  Finder reelCardOf(String reelName); // the TtReelCard whose name is [reelName]
  Finder dockAction(String label);    // the TtSelectionDock action with that visible label
  Finder dockEdit();                  // the dock's Edit button
  ```
- **What breaks, and the change:**
  - `references_test.dart:366–369` (a second reel with reels present): the FAB "New reel" → `newReelButton()`. `reels_test.dart:78–82` (the empty Home) keeps the empty state's **New reel** button.
  - `references_test.dart:343` (the badge): tap `reelCardOf(_reelPaste)`, assert the card is read with `reelCardSemanticsReferences(…, 1)`, then scroll the page to `referencesHeader(1)`; the "scrolled into view" expectation goes (Home no longer opens `?refs=1`).
  - `references_test.dart:442` (the References row): the same words on the chip; tap it through the chip's button.
  - `reels_test.dart:215` and `editors_test.dart:566` (`_tapIconButton(selectionRemove)`): `dockAction(_l10n.selectionDockRemove)`.
  - `editors_test.dart` `_pickAllAndContinue` (:1020) becomes `_editAll($, count)`: tap **Edit video** (`TtFab`), wait for `editorSheetTitleAll(count)`; the three flows that call it are otherwise unchanged. Add mode's `_pickScreen` steps are unchanged.
  - New flow in `editors_test.dart`: `'Choose clips: hold one, tap another, Edit 2 clips sends exactly those to CapCut in shooting order; the next Edit video lists CapCut first, Last used'`, on the CapCut capture the first flow uses; its tear-down ends the session as that flow does.
- Keep the files' safety patterns: positive waits before every absent check, tear-downs that run on failure, only `Movies/TakeTray Test/`, raw taps without settling.

- [ ] **Step 1: Write the finder tests first** (`reel_finders_test.dart`): each finder finds exactly one widget and it is hit-testable (`tester.hitTestOnBinding`), on Home with two reels and on a reel page while choosing; `'newReelButton finds one, on an empty Home and with reels'`. Remove the badge finder's tests; update `references_source_test.dart` for the removed string.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/patrol_support/`. Expected: FAIL (undefined); then implement the finders, and it passes.
- [ ] **Step 3: Update** the flows listed above and add the new one.
- [ ] **Step 4: Run** `cd app && ../tool/flutter analyze patrol_test` and `../tool/patrol build android`. Expected: no issues; the build succeeds. **Do not run on a device.**
- [ ] **Step 5: Mutation check:** match `newReelButton` by the label "New reel" alone (not the `TtHeaderPill`): on an empty Home the empty state's **New reel** button matches too, and `'newReelButton finds one, on an empty Home and with reels'` fails.
- [ ] **Step 6: Docs and commit** `test(patrol): the reel, editor and references flows on the new controls`.
  - **D-197:** each changed step, why, and the new flow.
  - `dev-setup.md`: the flow lists and `tool/patrol test -d RZCY80PHWCZ -t patrol_test/editors_test.dart`.

---

### Task 11: Docs: the learning guide, README, later.md, the Phase 12B check

**Model:** Sonnet. No new decision. The step review may be skipped (docs only).

**Files:**
- Create: `docs/learn/phase-12b-edit-flow-calm-home.md`.
- Modify: `README.md`, `docs/later.md`, `docs/dev-setup.md` (a new "Phase 12B check"), `docs/flow.md` (consistency pass only).

- [ ] **Step 1: The learning guide,** in the style of `docs/learn/phase-12-ui-refresh.md`:
  - How to read;
  - one section per task (1–10);
  - "Why the dock lives in the shell" (one bottom bar, snacks above it);
  - "A sheet that answers instead of navigating" (`EditorSheetOutcome`);
  - "A phone habit, not a setting" (`lastEditor`);
  - "Keeping a switch's focus through a layout change";
  - "A grid whose rows fit their cards";
  - a closing summary.
- [ ] **Step 2: README:**
  - the 12 row's description gains "; 12B: edit flow and calm Home", and its status becomes "12 done on the S24; 12B built, phone check pending. **Next: Phase 13**";
  - the "Phase 12" section gains a "12B: edit flow and calm Home" list, one plain line per task (the readme-progress rule), with "Phone tests: pending (Task 12)" and the learning guide's link.
- [ ] **Step 3: `later.md`:**
  - remove "Next: sending clips to an editor in fewer taps" and "Next: the calm Home";
  - add under "Phase 12": **The container transform from a reel card** (the design's 400 ms open; needs the `animations` package or a hand-made route, so it waits for the owner's go);
  - add the parked Minors that are not fixed in the batch.
- [ ] **Step 4: `dev-setup.md` "Phase 12B check":** Task 12 Step 4's hand checks, numbered, each with what to look at and what passes.
- [ ] **Step 5:** Run `tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 6: Commit** `docs: Phase 12B learning guide, README, later.md and the phone check`.

---

### After Task 11 (controller)

1. The Minors batch (Sonnet), one commit.
2. The whole-12B review (Opus), one fix wave (Sonnet), and the re-review (the same Opus reviewer, resumed).
3. Push `phase-12-ui-refresh` with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push.
4. Run the "update goldens" workflow on the branch for the package CI goldens (`selection_dock`, `quiet_tabs`, `shooting_mode_card`, `reel_card`, `grouped_rows`, and the removed sets gone), then `tool/pull_ci_goldens`, commit them, push, and wait for CI to go green on the branch.

---

### Task 12: The S24: Patrol flows, then the owner's side-by-side

**Model:** Sonnet (controller with the owner). Results go into D-191 (choosing), D-196 (Home) and README.

**Safety (repeat before each command):** `-s RZCY80PHWCZ`, `app.taketray.dev` only, logcat `--pid=` only, no screenshots, no reading of shared storage or other apps, Patrol only in `Movies/TakeTray Test/`.

- [ ] **Step 1: Patrol, each file once.** Run `tool/patrol test -d RZCY80PHWCZ -t patrol_test/<file>.dart` for:
  - `editors_test.dart` first, then `reels_test.dart`, `references_test.dart` and `onboarding_test.dart`;
  - then `tagging_test.dart`, `add_videos_test.dart`, `settings_test.dart`, `app_shell_test.dart`, `background_test.dart`, `media_access_test.dart`, `media_scan_test.dart` and `database_test.dart`.

  (`share_test.dart` stays skipped, D-169.)
- [ ] **Step 2: After every Patrol run**, from the repo root:
  ```
  (cd app && ../tool/flutter build apk --debug)
  tool/adb -s RZCY80PHWCZ install -r app/build/app/outputs/flutter-apk/app-debug.apk
  tool/adb -s RZCY80PHWCZ shell pm clear app.taketray.dev
  ```
  A failure is reported to the owner with its step. A test fault is fixed (and reviewed) before the next round; an app fault goes back to its task. Each file runs again only in a new round.
- [ ] **Step 3: Install for the hand checks:** the debug build as above, then open TakeTray Dev and allow video access. Release permissions: `cd app && ../tool/check_release_permissions` ends `RELEASE PERMISSIONS OK`.
- [ ] **Step 4: The hand checks** (owner, TakeTray Dev, the hub open beside the phone, light and dark). Write the verdict per number.
  1. **Screen 19:** Edit video, then CapCut: a whole reel sent in two taps; "Edit all {n} clips in…"; the next time CapCut is first with **Last used**.
  2. **Screen 8, holding:** hold a clip, tap two more, **Edit 3 clips**, Instagram Edits: exactly those three, in shooting order; choosing ends; the snack sits above the nav pill.
  3. **Screen 8, from the sheet:** Edit video, **Choose clips instead**, the hint, choose clips, Edit, VN: the space check with those clips.
  4. **Screen 8, the dock:** it slides up in place of the nav pill; Share, Add to, Move and Remove are labelled, off with nothing chosen; Select all becomes Clear; a snack shown while choosing floats above the dock; Back ends choosing and the nav pill (with its badge) comes back.
  5. **Screen 8, during a VN edit:** the note instead of Edit; the four actions still work.
  6. **Screen 18:** Add more clips opens "Add clips to a VN edit"; add mode works as before.
  7. **Screen 6, the card:** off reads "Off · {n} clips still to tag" and matches the To tag badge; on is one row, then Open camera and the glass chips (the chips blur the clip behind them); switching animates the height smoothly and TalkBack stays on the switch.
  8. **Screen 6, the header and tabs:** + New opens the form; the big "Reels" title shrinks into the bar while scrolling; the tabs filter and an empty one offers Show all reels.
  9. **Screen 6, the cards:** the cover alone, the status mark, the notes only when they apply; a press scales gently; covers never jump while loading.
  10. **Smoothness:** 20+ reels scroll at 120 Hz with no dropped frames by eye (the debug build is slower than release, so a stutter is re-checked on a release build installed over `app.taketray`, with the owner's go).
  11. **2× text:** the dock goes two by two, Select all is its icon, Home is one column, the chips wrap, nothing is cut off.
  12. **TalkBack:** a card reads "{name}. {status}. {n} clips … {n} references"; the tabs are read as toggles in a "Show reels" group; the Edit button reads "Edit 3 clips, 1:38".
  13. **Remove animations:** no slide, no scale; the fades remain.
- [ ] **Step 5: Record** the results:
  - README Phase 12: "12B phone tests …", with the run counts and any fault found and fixed;
  - `dev-setup.md`: the verdicts;
  - the D-numbers named above.

  Commit `docs: Phase 12B phone results`, push, and open (or update) the PR to `main` when CI is green. It merges only on the owner's go.
