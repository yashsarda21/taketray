# Phase 12: UI refresh (glass everywhere, the full-screen tag player) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every blur the design draws inside the phone exists in the app with the design's values and is visible on the S24, proven in CI by pixels; and the tag player is the full-screen D-171 design (clip fills the screen, reels in a dock, Skip and Same on a glass rail, vertical swipes), with the session logic (D-96) unchanged.

**Architecture:**
- **Glass first (Tasks 1–6):**
  - a pixel-test helper in `taketray_ui`'s test support proves "blurred" by edge contrast over sharp stripes;
  - the dialog and sheet scrim becomes a steady 3 dp blur (the phone proved the ramp is what fails);
  - every `BackdropFilter` gets a plain fill as its first painting child (the phone proved a `Material` child loses the blur);
  - the snack gets its 12 dp glass, the nav pill its `saturate(1.4)` and an outside-only shadow;
  - menus open through a TakeTray `PopupRoute` whose barrier is a transparent, blurred scrim;
  - the share screen asks Android 12+ for window blur-behind.
- **The player (Tasks 7–11):**
  - new `taketray_ui` pieces: `TtRailButton`, an `onVideo` style for `TtReelChip`/`TtNewReelChip`, `TtReelDock`, `TtPlayerTopScrim`, chevrons on `TtPlayerHeader`;
  - a pure cover-or-contain rule;
  - `tag_player_screen.dart` becomes a full-screen `Stack` (stage, top, dock, rail), with an All reels sheet;
  - vertical drag-follow swipes and the slide motion.
- **Then:** Patrol (Task 12), docs (Task 13), and the S24 last (Task 14).

**Tech Stack:** Flutter 3.47.7 via `tool/flutter`; Riverpod 3 codegen; go_router; gen-l10n; alchemist goldens (package: CI set by the "update goldens" workflow, macOS set locally, D-61; app goldens macOS-only, D-97); Kotlin platform APIs only; Robolectric 4.17 (`tool/test_android`, SDK 30/33/34/35); Patrol 4.10.

**Spec:**
- `docs/superpowers/specs/2026-11-24-phase-12-ui-refresh-design.md` (owner-approved 2026-11-24), including "What the phone showed" and "Calls made after the builder check".
- The tag player part: `design/handoff/tag-player-full-screen.md` (D-171), with prototype source `design/prototype/assets/player2.js` and `player2.css`.
- The blur audit, design against app with file:line pairs: `/private/tmp/claude-501/-Users-sardap-Documents-github-reel-helper/4598d59b-b566-4e40-b16a-1f194545f2cd/scratchpad/blur-audit.md`. It lives in a session scratchpad: copy what a task needs into its D-number, never link it from the repo.

## Global Constraints

- **Branch:**
  - `phase-12-ui-refresh` in worktree `.claude/worktrees/phase-12`, from `main` (be06695).
  - One phase, one branch, one PR.
  - Push the branch, CI runs on it, and it merges through a green PR after the owner approves.
- **Dependencies:** no new pub package, Gradle dependency or third-party plugin.
- **Release permissions:**
  - the release manifest has no `INTERNET`, `ACCESS_NETWORK_STATE` or `WAKE_LOCK`, and no new permission;
  - `tool/check_release_permissions` ends `RELEASE PERMISSIONS OK`.
- **Logs (D-10):** ids, counts and error types only. No new log line carries a name, a path, a link or a blur value.
- **Phone rules:**
  - The phone is used **only in Task 14**, the last step.
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
  - never weaken a test.
  - Characterization tests that must pass before and after a change (menu placement and keyboard, Task 5) are marked as such and recorded green.
- **Docs in the same task:**
  - each task writes its own D-number in `docs/decisions.md` (Task 1 D-172 … Task 12 D-183, numbered in each task) and its `docs/flow.md` lines;
  - an amended decision gets an "Amended by D-…" line.
- **Values come from the CSS and the handoff, never eyeballed:**
  - every new number is a `TtMetrics` constant (colours in `TtColors`) with the CSS line it copies quoted above it, as today (`// player2.css:33: .p2-rb { … }`);
  - the style rules (D-19: no raw colour, inset, size, radius or duration in `app/lib/features` or `components`) hold.
- **Contrast:**
  - text on glass and scrims is AA over a pure white frame (handoff: scene line 6.4:1, dock text 10:1, rail second line 7.8:1);
  - tests measure it with `ttTextContrastGuideline` (D-62) over a white stand-in for the clip;
  - text over the clip always sits on a scrim or glass;
  - the scrims' stops are exactly the handoff's.
- **The clip is never blurred:**
  - no `ImageFiltered` and no `BackdropFilter` over the stage;
  - only the rail buttons and dock chips blur what is under their own clipped shapes;
  - each `BackdropFilter` sits in a clip of its own size, except the modal scrim and the menu layer.
- **Session logic (D-96) unchanged:**
  - `TagSessionController`, `TagQueue`, the 400 ms hold, Undo, Pick several and "All done!" are not edited;
  - the view only calls their existing API.
- **UI:**
  - design tokens only; 48 dp targets; a semantics label on every control;
  - light and dark; text 1× and 2×; 360 dp wide;
  - the player is always dark (`TakeTrayTheme.video()`).
- **Copy:** strings are given verbatim in each task, through `app/lib/l10n/app_en.arb`.
- **Commands:**
  - package: `cd packages/taketray_ui && ../../tool/flutter test <file>`;
  - app: `cd app && ../tool/flutter test <file>`;
  - Robolectric: `cd app && ../tool/test_android`;
  - all checks: `tool/check` from the repo root, which ends `ALL CHECKS PASSED`.
- **Goldens:**
  - app goldens are macOS-only (`--update-goldens` locally);
  - package macOS goldens are updated locally in the task;
  - package CI goldens come once, at the end, from the "update goldens" workflow, pulled with `tool/pull_ci_goldens`.
- **Models (never Haiku; always pass the model):**
  - Opus: the implementers of Tasks 9, 10 and 11 (stage, screen, swipes);
  - Sonnet: every other implementer, all fixes and all task reviews;
  - Opus: the whole-phase review and its re-review (resume the same reviewer).
- **Reviews:**
  - Critical and Important findings are fixed now; Minors are parked for one batch before the final review;
  - a per-step fixer reviews its own fix; the final review's fix wave gets a separate re-review;
  - the step review may be skipped for Task 13 (docs only); never for code, phone safety, privacy or the final review.

## Review Focus

1. **A menu opened inside a sheet** (a reference card's menu in the Shooting mode references sheet, a reel header menu in a sheet).
   - Both blurs show and stack.
   - An outside tap and Back close only the menu.
   - The sheet stays, with its scroll position, and selecting an item acts once.
   - (Task 5, `'a menu inside a sheet: …'`.)
2. **Glass over a clip that is still loading, or has no picture.**
   - The rail and the dock chips blur whatever is under them: the playing texture, the loading thumbnail with its spinner, or black.
   - During a swipe, a clip whose thumbnail is not cached yet, or fails, comes in as black: no error widget, and no frame of another clip.
   - A clip whose stored size says portrait but whose player reports 16:9 switches to contain once it starts.
   - (Task 9 `'the player's own shape wins once it starts'`; Task 11 `'a missing thumbnail comes in as black'`; the texture blur is hand check 14.3.)
3. **Battery saver turned on (or off) while the share sheet is open.**
   - The window blur drops to the dim alone at once, and comes back when blur is allowed again.
   - The Flutter dim never changes.
   - On Android 11 nothing is requested.
   - (Task 6 `toggledOffAndOnAgain…`, and hand check 14.8.)
4. **Font scale 2.0 in the dock.**
   - One column, scrolling within 260 dp; the header wraps.
   - The rail keeps its place (4 dp above the dock), grows with its text, and is never overlapped by the snack.
   - Pick several's footer stays reachable, and nothing overflows at 360 × 640.
   - (Task 8 `'2x: one column, scrolls within 260 dp, header wraps'`; Task 10 `'2x on a small phone: …'`.)
5. **A dialog or sheet opened during the tag player's slide or drag** (the "Still shooting?" dialog, D-107, or New reel during a slide).
   - The slide ends and the new clip's player takes over (no stuck thumbnail, no stage left off screen).
   - A drag in progress is cancelled and springs back.
   - The scrim is the steady 3 dp blur from its first frame.
   - (Task 11 `'a dialog opened during the slide …'` and `'a dialog opened during a drag …'`.)

---

## File map

| Area | Create | Modify |
|---|---|---|
| Glass test support | `packages/taketray_ui/test/support/tt_glass_pixels.dart`, `test/support_test/glass_pixels_test.dart`, `test/components/glass_pixels_test.dart`, `app/test/support/glass_pixels.dart` (re-export) | — |
| Scrim, glass, snack, nav pill | `components/internal/saturation.dart`, `components/internal/outside_shadow.dart` | `internal/blur_barrier.dart`, `dialog.dart`, `sheet.dart`, `status_pill.dart`, `snack.dart`, `glass.dart`, `nav_pill.dart`, `tt_metrics.dart` |
| Menu | `components/internal/menu_route.dart` | `menu.dart`, `internal/menu_panel.dart`, `app/lib/router/popup_route_tracker.dart` (doc) |
| Share | `android/.../share/ShareWindowBlur.kt`, `src/test/.../share/ShareWindowBlurTest.kt` | `ShareActivity.kt` |
| Player pieces | `components/rail_button.dart`, `components/reel_dock.dart` | `reel_chip.dart`, `player_chrome.dart`, `tt_colors.dart`, `taketray_ui.dart` (exports), widgetbook |
| Player screen | `app/lib/features/tagging/views/stage_fit.dart`, `dock_reels.dart`, `all_reels_sheet.dart` | `tag_player_screen.dart`, `app_en.arb` |
| Removed | — | `tag_panel.dart` with its tests, goldens and widgetbook page |
| Patrol | `app/patrol_test/support/player_finders.dart`, `app/test/patrol_support/player_finders_test.dart` | `app/patrol_test/tagging_test.dart` |

All component paths are under `packages/taketray_ui/lib/src/`.

---

### Task 1: Glass pixel helper and the steady scrim blur

**Model:** Sonnet. **D-172.**

**Files:**
- Create:
  - `packages/taketray_ui/test/support/tt_glass_pixels.dart`
  - `packages/taketray_ui/test/support_test/glass_pixels_test.dart`
  - `app/test/support/glass_pixels.dart`: `export '../../../packages/taketray_ui/test/support/tt_glass_pixels.dart';`, as `accessibility.dart` does
  - `app/test/features/reels/views/reel_overlays_golden_test.dart` (macOS-only, the pattern of `tag_player_golden_test.dart`)
- Modify:
  - `packages/taketray_ui/lib/src/components/internal/blur_barrier.dart`
  - `dialog.dart:309-324` (`_TtDialogRoute.buildModalBarrier`)
  - `sheet.dart:216-236` (`_TtSheetRoute.buildModalBarrier`)
- Test:
  - `packages/taketray_ui/test/components/dialog_test.dart` (replace `'dims and blurs the page behind it'`, :475)
  - `sheet_test.dart` (the same test at :359)

**Interfaces:**
- Produces (test support, used by every glass task):
  ```dart
  const double ttStripePeriod = 8;   // dp: 4 black, 4 white
  const double ttBlurredShare = 0.5; // blurred: under half the contrast the fill lets through
  const Key ttCaptureKey = ValueKey('tt-capture');
  /// Sharp black/white stripes that change colour along [along].
  Widget ttStripes({Axis along = Axis.horizontal});
  /// ttTestApp(home) with a RepaintBoundary(key: ttCaptureKey) around the
  /// whole Navigator (MaterialApp.builder), so routes and barriers are captured.
  Widget ttPixelApp(Widget home, {Brightness brightness = Brightness.light, bool disableAnimations = false, double textScale = 1});
  class TtPixels {
    /// The ttCaptureKey boundary at pixel ratio 1 (tests set the view to
    /// 360 × 800 physical, devicePixelRatio 1).
    static Future<TtPixels> capture(WidgetTester tester);
    /// Mean over the lines of [rect] (across [along]) of (max − min) luma,
    /// 0..1. Luma = (0.2126 R + 0.7152 G + 0.0722 B) / 255 of the sRGB bytes
    /// (not WCAG luminance), so a fill of alpha a scales it by (1 − a).
    double edgeContrast(Rect rect, {Axis along = Axis.horizontal});
    double meanLuma(Rect rect);
    Color colorAt(Offset point);
  }
  /// contrast < ttBlurredShare × (1 − fillOpacity) × sharp, else a TestFailure.
  void expectBlurred(double contrast, {required double sharp, required double fillOpacity});
  /// contrast ≥ 0.9 × (1 − fillOpacity) × sharp.
  void expectSharp(double contrast, {required double sharp, double fillOpacity = 0});
  /// Every BackdropFilter under [of] has [sigma] (ImageFilter.blur equality).
  void expectBlurFilter(WidgetTester tester, Finder of, double sigma);
  /// The BackdropFilter that is an ancestor of the topmost ModalBarrier (a
  /// route's scrim; AnimatedModalBarrier builds one inside it).
  Finder ttScrimFilter();
  /// For every BackdropFilter under [of]: the first painting descendant
  /// (skipping layout-only single-child widgets) is a ColoredBox or a
  /// DecoratedBox with a colour, never a Material (the S24 lost the blur with
  /// a Material child, spec "What the phone showed", F).
  void expectGlassStructure(WidgetTester tester, Finder of);
  ```
- Produces (library):
  - `Widget ttBlurredBarrier({required Widget barrier})`: `BackdropFilter(filter: ImageFilter.blur(sigmaX: TtMetrics.scrimBlur, sigmaY: TtMetrics.scrimBlur), child: barrier)`.
  - The `animation` parameter and the `AnimatedBuilder` go. The dim alone fades: Flutter's `AnimatedModalBarrier` keeps the `Curves.ease` colour ramp.
  - Task 5 reuses it.

- [ ] **Step 1: Write the failing tests.**

  The helper's own tests (`glass_pixels_test.dart`, over `ttStripes()` in `ttPixelApp`):
  ```dart
  testWidgets('bare stripes are sharp', …) // edgeContrast(rect) > 0.9
  testWidgets('sigma 0 is not blurred', …)  // BackdropFilter(blur 0) + ColoredBox(white @ .5):
      expect(() => expectBlurred(c, sharp: s, fillOpacity: .5), throwsA(isA<TestFailure>()));
  testWidgets('sigma 1 is not blurred enough', …) // same, blur 1: throws
  testWidgets('sigma 3 is blurred under a half fill', …)   // expectBlurred passes, fill .5
  testWidgets('sigma 12 is blurred under a 94 % fill', …)  // passes, fill .94 (the snack)
  testWidgets('a Material child fails the structure check', …)
  testWidgets('a ColoredBox fill with a transparent Material passes', …)
  ```

  The scrim tests, written once for `showTtDialog` (`dialog_test.dart`) and once for `showTtSheet` (`sheet_test.dart`):
  ```dart
  testWidgets('the scrim blurs by 3 from the first frame to the end of the close', (tester) async {
    // open; await tester.pump();  (animation value 0)
    BackdropFilter scrim() => tester.widget<BackdropFilter>(ttScrimFilter());
    expect(scrim().filter, ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3));
    final first = tester.element(ttScrimFilter());
    for (final ms in [16, 100, 200, 300]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(scrim().filter, ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3));
      expect(tester.element(ttScrimFilter()), same(first)); // no widget swap, no ramp
    }
    // Close (tap the scrim), then pump 1 frame and pump 100 ms: still blur 3.
  });
  testWidgets('reduced motion: blurred at the first frame', …)   // disableAnimations: true
  testWidgets('the page behind is blurred and dimmed by half', (tester) async {
    // ttPixelApp(ttStripes() + opener). sharp = before.edgeContrast(r) and
    // luma0 = before.meanLuma(r), with r a 120 × 40 rect at (8, 8), outside the panel.
    // After open and settle:
    expectBlurred(after.edgeContrast(r), sharp: sharp, fillOpacity: .5);
    expect(after.meanLuma(r), closeTo(luma0 * .5, .03));
  });
  ```
  Keep the existing dim test: barrier colour = `scheme.scrim @ .5`.

  The app golden `reel_overlays_golden_test.dart`: `'the Delete reel dialog over a reel's page'`, light and dark, 1×, written as `reel_delete_dialog_{light,dark}.png`. The reel page has 6 clips with gradient thumbnails, as `tag_player_golden_test.dart` makes them.
- [ ] **Step 2: Run** `cd packages/taketray_ui && ../../tool/flutter test test/support_test/glass_pixels_test.dart test/components/dialog_test.dart test/components/sheet_test.dart`.
  - Expected: FAIL. The helper is undefined first. Then the frame-1 tests fail: a value-0 frame returns the bare barrier, so no `BackdropFilter` is found; and a later frame shows sigma `3 × value` ≠ 3.
  - The pixel test may already pass: the flutter_tester renderer is not the S24's Impeller/Vulkan and need not reproduce the phone bug. Record that, and note in D-172 that the structural frame tests are the regression guard for what the phone proved.
- [ ] **Step 3: Implement** the helper and `ttBlurredBarrier({required Widget barrier})`. Both route overrides call it with `super.buildModalBarrier()`.
- [ ] **Step 4: Run** the same command. Expected: PASS. Then `cd app && ../tool/flutter test --update-goldens test/features/reels/views/reel_overlays_golden_test.dart`, check the images by eye, and run `tool/check`, which must end `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - put back `sigma = TtMetrics.scrimBlur * animation.value`: the first-frame test fails;
  - drop the `BackdropFilter`: the pixel test fails;
  - set the sigma to 1: the pixel test fails.
- [ ] **Step 6: Docs and commit** `feat(ui): steady 3 dp scrim blur behind dialogs and sheets; glass pixel tests`.
  - **D-172** records:
    - the 2026-11-24 phone table, in short, with a pointer to the spec;
    - the cause found: the ramp, when it meets the TakeTray dialog;
    - the fix: a steady blur, with the dim alone fading;
    - that the blur now leaves at once at the end of a close. This overrides spec call 6 ("the blur's ramp follows the dim"): the phone showed the ramp itself is what fails;
    - that the pixel helper and its thresholds are the CI proof, and the frame tests pin the structure.
  - `flow.md`: the dialog and sheet route steps that name `ttBlurredBarrier`.

---

### Task 2: Glass with ink: the fill outside the `Material`, and pixel tests for every existing glass piece

**Model:** Sonnet. **D-173.**

**Files:**
- Modify: `packages/taketray_ui/lib/src/components/status_pill.dart:160-174`.
- Create: `packages/taketray_ui/test/components/glass_pixels_test.dart`.
- Test: `status_pill_test.dart`, and the new file.

**Interfaces:**
- Consumes: Task 1's helper.
- Produces:
  - `TtStatusPill(onMedia: true)` is built as `ClipRRect(corners) → BackdropFilter(blur glassPillBlur) → ColoredBox(fill) → Material(type: MaterialType.transparency) → InkWell | body`, like `TtGlassPill`;
  - its look and API are unchanged.
- **The audit** (every `BackdropFilter` in the package, and what its first painting child is):

  | Where | First painting child | Action |
  |---|---|---|
  | `glass.dart:62` (`TtGlass`, nav pill) | `DecoratedBox` | keep |
  | `glass.dart:112` (`TtGlassPill`) | `ColoredBox` | keep |
  | `status_pill.dart:164` | `Material(color: fill)` | **fix** |
  | `shooting_mode_card.dart:245` (icon tile) | `ColoredBox` | keep |
  | `shooting_mode_card.dart:519` (refs row) | `DecoratedBox`, then a transparent `Material` | keep |
  | `reel_card.dart:473` (refs badge) | `ColoredBox`, ink in a transparent `Material` on top | keep |
  | `tag_panel.dart:163` | — | deleted in Task 10 |

- [ ] **Step 1: Write the failing tests** in `glass_pixels_test.dart`. Each piece sits over `ttStripes()` in `ttPixelApp`, at 360 × 800 and devicePixelRatio 1.

  The sample rect is free of glyphs, 2 dp inside the glass edge, and at least one `ttStripePeriod` long across the stripes. Pick `along: Axis.vertical` for a short piece. The sharp reference is the same rect with the piece absent.
  ```dart
  testWidgets('every BackdropFilter has a plain fill first', (tester) async {
    // pump each piece in turn: TtStatusPill(onMedia: true, onPressed: () {}),
    // TtGlassPill, TtReelCard with 3 references (badge), TtShootingModeCard on
    // with references, TtNavPill.
    expectGlassStructure(tester, find.byType(<piece>));  // RED for TtStatusPill
  });
  testWidgets('status pill on media blurs by 8 under its .58 fill', …)
      // expectBlurFilter(…, 8); expectBlurred(c, sharp: s, fillOpacity: .58)
  testWidgets('Editing in VN pill blurs by 8', …)         // .58
  testWidgets('reel card references badge blurs by 8', …) // .58
  testWidgets('Shooting mode icon tile blurs by 8', …)     // white .16
  testWidgets('Shooting mode references row blurs by 6', …) // black .25
  testWidgets('nav pill blurs by 18 under its .78 glass', …)
  testWidgets('a tap on the pressable status pill still ripples and calls onPressed', …)
  ```
- [ ] **Step 2: Run** `../../tool/flutter test test/components/glass_pixels_test.dart test/components/status_pill_test.dart`.
  - Expected: FAIL on the structure test for `TtStatusPill`.
  - The pixel tests of pieces that already blur may pass at once. Record them as regression guards, green from the start (the spec's "What already matches").
- [ ] **Step 3: Implement** the status pill change.
- [ ] **Step 4: Run** the same tests, and the `status_pill` and `reel_card` goldens. Expected: PASS with unchanged goldens (the pixels are the same in the test renderer). If a golden changes, update the macOS set and say why in the report.
- [ ] **Step 5: Mutation checks:**
  - put the `Material(color: fill)` back: the structure test fails;
  - set the badge's sigma to 0: its pixel test fails.
- [ ] **Step 6: Docs and commit** `fix(ui): reel cover pill blurs on the phone (fill outside the Material)`.
  - **D-173:** the rule "a `BackdropFilter`'s first painting child is a plain fill; ink goes on a transparent `Material` inside it", the audit table, and the phone's case F.
  - `flow.md`: the design-system part ("Accessibility check in component tests" neighbourhood) gains "Glass pixel tests".

---

### Task 3: Snack glass (blur 12, clipped to its shape)

**Model:** Sonnet. **D-174** (amends D-48).

**Files:**
- Modify:
  - `packages/taketray_ui/lib/src/components/snack.dart:11-14` (doc comment), `:63-73`
  - `tt_metrics.dart` (`snackbarBlur`)
- Test: `snack_test.dart`, `glass_pixels_test.dart`, `snack_golden_test.dart` (macOS set).

**Interfaces:**
- Produces:
  - `TtMetrics.snackbarBlur = 12` with `// tt-style.css:130: .style-tt .snack { backdrop-filter: blur(12px) }`;
  - `TtSnack` is `DecoratedBox(boxShadow: level3, borderRadius: 18) → ClipRRect(18) → BackdropFilter(blur 12) → DecoratedBox(color: inverseSurface @ .94, borderRadius: 18) → …` (today's content);
  - `showTtSnack` and `showTtSnackOn` are unchanged.
- [ ] **Step 1: Write the failing tests.** Each uses `ttPixelApp(Scaffold(body: ttStripes()))` with `showTtSnack(message: 'Clip deleted', actionLabel: 'Undo', onAction: …)`, pumped and settled (the resting state is what must match; the fade may hide the blur, spec approach 5).
  ```dart
  testWidgets('the snack blurs by 12 under its 94 % fill, at rest', …)
      // expectBlurFilter(tester, find.byType(TtSnack), 12); expectGlassStructure; expectBlurred(fill .94)
      // sample: the 3 dp band under the panel's top edge, 24 dp in from each end
  testWidgets('the blur stays inside the 18 dp corners', …)
      // a 4 × 4 rect 1 dp outside the panel's top-left corner, on the diagonal,
      // and the 8 dp gap above the panel: expectSharp against the bare stripes
  testWidgets('a long message at 2x: still one blurred panel, no overflow', …)
  testWidgets('a persistent snack (screen reader) is blurred too', …)
  ```
- [ ] **Step 2: Run** `../../tool/flutter test test/components/snack_test.dart test/components/glass_pixels_test.dart`. Expected: FAIL (no `BackdropFilter` under `TtSnack`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and update the macOS snack goldens. Expected: PASS.
- [ ] **Step 5: Mutation checks:**
  - drop the `ClipRRect`: the corner test fails;
  - set the sigma to 6: the pixel test fails (0.5 bound at fill .94).
- [ ] **Step 6: Docs and commit** `feat(ui): snack glass blur 12 (D-48 amended)`.
  - **D-174.**
  - D-48 gets "Amended by D-174: the snack now has the 12 px blur", and its sentence about leaving the blur out is struck through.
  - The snack doc comment says the same.
  - `flow.md`: the snack step.

---

### Task 4: Nav pill: `saturate(1.4)` with the blur, the shadow outside the glass only

**Model:** Sonnet. **D-175.**

**Files:**
- Create:
  - `packages/taketray_ui/lib/src/components/internal/saturation.dart`
  - `internal/outside_shadow.dart`
- Modify:
  - `glass.dart:13-76` (`TtGlass`)
  - `nav_pill.dart:100`
  - `tt_metrics.dart`
- Test: `glass_test.dart`, `nav_pill_test.dart`, `glass_pixels_test.dart`, new `test/components/saturation_test.dart`; `nav_pill` and `glass` goldens (macOS).

**Interfaces:**
- Produces:
  - `List<double> ttSaturationMatrix(double amount)`: the W3C Filter Effects `saturate` matrix (an algorithm with exact values, so here in full):
    ```
    [0.2126+0.7874s, 0.7152-0.7152s, 0.0722-0.0722s, 0, 0,
     0.2126-0.2126s, 0.7152+0.2848s, 0.0722-0.0722s, 0, 0,
     0.2126-0.2126s, 0.7152-0.7152s, 0.0722+0.9278s, 0, 0,
     0, 0, 0, 1, 0]
    ```
  - `TtGlass` gains `this.saturation = 1`:
    - at 1 the filter is `ImageFilter.blur(blur)`, as today;
    - otherwise `ImageFilter.compose(outer: ColorFilter.matrix(ttSaturationMatrix(saturation)), inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur))`: blur first, then saturate, as the CSS order.
  - `TtMetrics.navPillSaturation = 1.4`, quoting `// tt-style.css:33-37: .style-tt .navbar { backdrop-filter: blur(18px) saturate(1.4) }`. `TtNavPill` passes it.
  - `class OutsideShadowPainter extends CustomPainter { new({required List<BoxShadow> shadows, required BorderRadius borderRadius}); }` (internal).
    - It paints each shadow's `toPaint()` as the box's RRect, shifted by `offset` and inflated by `spreadRadius`.
    - The canvas is clipped to the difference of a rect `2 × blurRadius + |offset| + |spread|` larger than the box and the box's own RRect.
    - So nothing is painted under the glass, as CSS `box-shadow` does.
  - `TtGlass` paints its shadow with it (`CustomPaint(painter: …)` behind the clip) instead of a `BoxShadow` on a `DecoratedBox`. `shadow: false` still paints none.
- [ ] **Step 1: Write the failing tests:**
  ```dart
  test('saturation 1 is the identity', …)      // each of the 20 values closeTo(1e-9)
  test('saturation 1.4 matches the CSS filter spec', …)
      // rows: [1.31496, -0.28608, -0.02888, 0, 0], [-0.08504, 1.11392, -0.02888, 0, 0],
      //       [-0.08504, -0.28608, 1.37112, 0, 0], [0, 0, 0, 1, 0]
  testWidgets('the nav pill composes blur 18 with saturate 1.4', …)
      // BackdropFilter.filter == ImageFilter.compose(outer: ColorFilter.matrix(m1.4), inner: blur 18)
  testWidgets('a TtGlass without saturation blurs only', …) // filter == ImageFilter.blur(18, 18)
  testWidgets('the glass is more saturated than the plain blend', …)
      // over a uniform Color(0xFF8A5CC2), at (pill.left + 3, pill.center.dy):
      // colorAt == alphaBlend(fill, saturate(bg)) ± 3 per channel, and its chroma
      // (max − min channel) > chroma(alphaBlend(fill, bg)) + 2
  testWidgets('the shadow is not under the glass', …)
      // over uniform white: the same point == alphaBlend(fill, white) ± 2 (today darker);
      // and 6 dp under the pill's bottom edge is darker than white by > 4 levels
  ```
- [ ] **Step 2: Run** `../../tool/flutter test test/components/saturation_test.dart test/components/glass_test.dart test/components/nav_pill_test.dart test/components/glass_pixels_test.dart`. Expected: FAIL (`ttSaturationMatrix` undefined, filter is blur only, interior darker).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, then update the macOS `nav_pill` and `glass` goldens and look at them. Expected: PASS. The pill reads lighter than before, which is the design.
- [ ] **Step 5: Mutation checks:**
  - `inner` and `outer` swapped: the filter-equality test fails;
  - saturation 1.0 in `TtNavPill`: the chroma test fails;
  - the `BoxShadow` put back: the shadow test fails.
- [ ] **Step 6: Docs and commit** `feat(ui): nav pill saturate(1.4) and an outside-only shadow`. **D-175**; `flow.md` design-system lines for `TtGlass`.

---

### Task 5: The menu layer: a TakeTray menu route with a transparent, steady 3 dp blur

**Model:** Sonnet. **D-176** (amends D-48's menu part and D-51).

**Files:**
- Create: `packages/taketray_ui/lib/src/components/internal/menu_route.dart`.
- Modify:
  - `menu.dart:56-149` (`TtMenuButton`)
  - `internal/menu_panel.dart` (the panel casts its own shadow)
  - `app/lib/router/popup_route_tracker.dart` (doc comment, lines 19-22)
- Test:
  - `packages/taketray_ui/test/components/menu_test.dart`
  - `menu_golden_test.dart` (comment only)
  - `app/test/router/popup_route_tracker_test.dart` (or the file that tests the tracker today)
  - `app/test/features/reels/views/reel_overlays_golden_test.dart` (adds the open menu)

**Interfaces:**
- Consumes: `ttBlurredBarrier({required Widget barrier})` (Task 1).
- Produces:
  - `class TtMenuRoute<T> extends PopupRoute<({T value})>` (internal):
    - `new({required Rect anchor, required TextDirection textDirection, required CapturedThemes themes, required String barrierLabel, required WidgetBuilder builder})`;
    - `barrierColor` null, so there is no dim; `barrierDismissible` true; `barrierLabel` is `MaterialLocalizations.menuDismissLabel`;
    - `transitionDuration` and `reverseTransitionDuration` are `Duration.zero`, marked `// style-check: allow MenuAnchor opened with no motion (D-176)`;
    - `buildModalBarrier()` returns `ttBlurredBarrier(barrier: super.buildModalBarrier())`;
    - `buildPage` lays the panel out with `CustomSingleChildLayout(delegate: TtMenuLayout(...))` inside a `FocusTraversalGroup` with `Shortcuts` (Arrow Down / Arrow Up → `DirectionalFocusIntent`). Escape is the route's `DismissIntent`.
  - `class TtMenuLayout extends SingleChildLayoutDelegate`: today's `MenuAnchor` placement for `AlignmentDirectional.bottomStart`.
    - The panel's top-start sits at the anchor's bottom-start.
    - It flips above the anchor when it does not fit below.
    - It is clamped to the screen less the view padding and Material's menu edge padding.
    - The characterization test below pins the numbers.
  - `TtMenuButton<T>` keeps its constructor and `builder(context, open)`.
    - `open` pushes `TtMenuRoute` on the **root** navigator, with the anchor's global rect and the captured themes.
    - A chosen item pops `(value: item.value)`, and `onSelected` is called once after the pop (a nullable `T` still counts as a selection).
    - An outside tap or Back pops `null`, and nothing is selected.
    - A second `open` while it is open does nothing.
    - A change of the window size closes the menu without a selection, as `MenuAnchor` did.
    - `MenuAnchor`, `MenuController`, the `PopScope` and `_setOpenSafely` go.
  - `TtMenuPanel`'s `Material` gains `elevation: TtMetrics.menuElevation, shadowColor: scheme.shadow` (the shadow `MenuAnchor`'s surface used to cast).
  - Every user gets it unchanged: `reel_header.dart:134`, `reference_card.dart:159`, `to_tag_screen.dart:479`, `reel_detail_screen.dart:350,565`.
  - Menus are now popup routes, so `PopupRouteTracker.isOpen` sees them: "Still shooting?" no longer opens over an open menu.
- [ ] **Step 1: Characterization first** (on today's code; these must pass before and after, recorded green):
  ```dart
  testWidgets('opens where MenuAnchor did', …)
      // four anchors: top-left, top-right, bottom-left (flips up), RTL top-right,
      // at 360 × 800 with a 24 dp status bar; expect tester.getRect(TtMenuPanel)
      // == the Rect constants recorded from today's run (paste them in)
  testWidgets('keyboard: Down moves through the items, Enter selects, Escape closes, focus back on the anchor', …)
  ```
  Delete `'onClose during build is deferred'` (`menu_test.dart:54`): it tests `MenuAnchor` internals that no longer exist. Its successor is the size-change test below.
- [ ] **Step 2: Write the failing tests:**
  ```dart
  testWidgets('blurs the whole page by 3 without dimming', …)
      // ttScrimFilter() filter == ImageFilter.blur(3, 3); no AnimatedModalBarrier;
      // pixels: expectBlurred(c, sharp: s, fillOpacity: 0) on a page rect away from
      // the panel; meanLuma == bare meanLuma ± .03 (no dim)
  testWidgets('the blur is there from the first frame', …)   // pump once after open
  testWidgets('an outside tap closes it and selects nothing', …)  // kept
  testWidgets('Android back closes the open menu and the page stays', …) // kept, now through the route
  testWidgets('a window size change closes the menu without a selection', …)
  testWidgets('a nullable item value of null is still a selection', …)
  testWidgets('TalkBack: items are menu items, a checked one a radio menu item, and the scrim says "Dismiss menu"', …)
  testWidgets('a menu inside a sheet: both blur, an outside tap and Back close only the menu', …)
      // showTtSheet with a TtMenuButton; open; two BackdropFilters of sigma 3;
      // tap outside the panel but inside the sheet → menu gone, sheet there;
      // reopen, Back → menu gone, sheet there; select → onSelected once, sheet there
  testWidgets('the panel casts the menu shadow', …)   // Material.elevation == 6
  ```
  App side:
  ```dart
  test('an open TtMenuButton menu counts as a popup', …)     // tracker.isOpen true, false after close
  ```
  And `'a reel's overflow menu open over its page'`, light and dark, added to `reel_overlays_golden_test.dart`.
- [ ] **Step 3: Run** `../../tool/flutter test test/components/menu_test.dart` and `cd app && ../tool/flutter test test/router`. Expected: FAIL (no `BackdropFilter`; the tracker never sees a menu).
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** the tests, every test of the menu's users (`reel_header_test`, `reference_card_test`, `to_tag_*`, `reel_detail*`), the new app golden (`--update-goldens`, then look at it), and `tool/check`. Expected: PASS and `ALL CHECKS PASSED`; the characterization rects are unchanged.
- [ ] **Step 6: Mutation checks:**
  - the barrier without `ttBlurredBarrier`: the blur test fails;
  - a dim colour on the barrier: the luma test fails;
  - `onSelected` before the pop, called twice: the nullable test fails;
  - the layout's flip removed: the bottom-left characterization case fails.
- [ ] **Step 7: Docs and commit** `feat(ui): menus blur the page behind them (TakeTray menu route)`.
  - **D-176**, which amends D-48 (the panel is no longer inside `MenuAnchor`) and D-51 (Back pops the route; no `PopScope`).
  - `flow.md` "Android back with a menu open" is rewritten.
  - `flow.md:663`: a menu is now a popup route that the tracker sees.
  - The tracker's doc comment is updated to match.

---

### Task 6: The share screen's window blur (Android 12+)

**Model:** Sonnet. **D-177** (amends D-167).

**Files:**
- Create:
  - `app/android/app/src/main/kotlin/app/taketray/share/ShareWindowBlur.kt`
  - `app/android/app/src/test/kotlin/app/taketray/share/ShareWindowBlurTest.kt`
- Modify:
  - `app/android/app/src/main/kotlin/app/taketray/share/ShareActivity.kt`
  - `ShareTheme` (`values*/styles.xml`) is **not** changed. `backgroundDimEnabled` stays false: the Flutter 50 % dim (`share_app.dart:252-285`) is the only dim, and it stays.

**Interfaces:**
- Produces:
  ```kotlin
  internal class ShareWindowBlur(private val window: Window, density: Float) {
      val radiusPx: Int                  // radiusForSigma(SIGMA_DP * density)
      val listener: Consumer<Boolean>    // = { onBlurEnabledChanged(it) }
      /** API 31+: enabled → addFlags(FLAG_BLUR_BEHIND) and blurBehindRadius = radiusPx;
       *  disabled → clearFlags(FLAG_BLUR_BEHIND) and blurBehindRadius = 0; then
       *  window.attributes = attributes. Below API 31: does nothing. */
      fun onBlurEnabledChanged(enabled: Boolean)
      companion object {
          /** tt-style.css:122: .style-tt .scrim { backdrop-filter: blur(3px) } (TtMetrics.scrimBlur). */
          const val SIGMA_DP = 3f
          /** Android's own rule, sigma = 0.57735 × radius + 0.5 (AOSP hwui
           *  Blur::convertRadiusToSigma), inverted and rounded; 0 for sigma ≤ 0.5. */
          fun radiusForSigma(sigmaPx: Float): Int
      }
  }
  ```
  - `ShareActivity`, on `Build.VERSION.SDK_INT >= Build.VERSION_CODES.S`:
    - `onAttachedToWindow` registers `windowManager.addCrossWindowBlurEnabledListener(mainExecutor, blur.listener)`. The listener is called at once with the current state, which covers `isCrossWindowBlurEnabled`; battery saver later calls it with false.
    - `onDetachedFromWindow` removes the listener.
    - `blur` is built lazily from `window` and `resources.displayMetrics.density`.
  - No log line (D-10).
- [ ] **Step 1: Write the failing tests** (Robolectric):
  ```kotlin
  @Test fun radiusForSigmaUsesAndroidsRule()
      // radiusForSigma(3f) == 4; (3f * 2f) == 10; (3f * 2.8125f) == 14; (3f * 3f) == 15; (0.5f) == 0
  @Test @Config(sdk = [33, 34, 35]) fun blurOnSetsTheFlagAndRadius()
      // window from Robolectric.buildActivity(Activity::class.java).setup().get();
      // ShareWindowBlur(window, 2.8125f).onBlurEnabledChanged(true):
      // attributes.flags has FLAG_BLUR_BEHIND; attributes.blurBehindRadius == 14
  @Test @Config(sdk = [33, 34, 35]) fun blurOffFallsBackToTheDimAlone()
      // true then false: flag cleared, radius 0
  @Test @Config(sdk = [33, 34, 35]) fun toggledOffAndOnAgainRestoresTheBlur()   // battery saver while open
  @Test @Config(sdk = [30]) fun android11AsksForNothing()
      // flags and attributes equal to before, for true and false
  @Test fun theShareThemeStillHasNoSystemDim()   // ShareTheme backgroundDimEnabled == false
  ```
  If Robolectric's `WindowManager` supports `addCrossWindowBlurEnabledListener` on SDK 33+, also add `attachRegistersAndDetachRemovesTheListener`, using a `ShareActivity` built but not created (as `ShareActivityTest` does) only if that is possible without starting an engine. Otherwise D-177 says the wiring is proven by hand checks 14.8.
- [ ] **Step 2: Run** `cd app && ../tool/test_android`. Expected: FAIL (`ShareWindowBlur` unresolved).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `../tool/test_android`, `../tool/check_release_permissions` and `tool/check`. Expected: pass, `RELEASE PERMISSIONS OK`, and `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - drop the `+ 0.5` from the rule: the density test fails;
  - the off branch leaves the radius as it was: the fall-back test fails;
  - the SDK guard removed: the SDK 30 test fails.
- [ ] **Step 6: Docs and commit** `feat(share): blur the app behind the share sheet on Android 12+`.
  - **D-177:** amends D-167's "nothing of ours behind a see-through window to blur"; Android 11 keeps the dim alone; the owner checks the radius by eye.
  - `flow.md` "Sharing into TakeTray": the window blur step.

---

### Task 6A: The To tag count on the nav pill (owner's request, 2026-11-24)

**Model:** Sonnet. **D-184** (D-172 to D-183 are reserved by Tasks 1 to 12; this task takes the next free number).

**Why:** The owner noticed that the design's bottom bar shows how many clips wait on the **To tag** tab (`design/prototype/assets/screens.js:157, 222, 467`: `h.navbar(tab, s.toTag.length)` on Reels, To tag and Settings), and the app never does. Cause, found by the controller: `app/lib/features/shell/views/app_shell.dart:8` is still the Phase 0 placeholder `int _clipsToTag() => 0;` ("A constant 0 (no badge) until the tagging feature supplies it in phase 5"). Phase 5 never wired it. `TtNavPill`/`TtNavItem` already draw the badge (`badgeCount`, hidden at 0, "99+" above 99, `TtCountBadge`) and the semantics (`badgeSemanticLabel`, `l10n.toTagBadgeSemantics(n)`), so this is wiring, not new UI.

**Files:**
- Modify: `app/lib/features/shell/views/app_shell.dart` (delete `_clipsToTag`; `AppShell` becomes a `ConsumerWidget`).
- Modify (only if a count provider is cleaner than `.length` in the view): `app/lib/features/tagging/view_models/pending_clips.dart` (+ regenerate `.g.dart` with the repo's build_runner command).
- Test: `app/test/features/shell/views/app_shell_test.dart` (create or extend the existing shell test; find it with `grep -rl AppShell app/test`).

**Interfaces:**
- Consumes: `pendingClipsProvider` (`Stream<List<Clip>>`, `pending_clips.dart:18`), the read-only source the Shooting mode card's "N clips to tag" strip already uses (D-76: reading it never scans or verifies, so it can't stand in for "To tag was opened"). Use this source so the badge and the card's strip always agree.
- Produces: nothing for later tasks.

**Rules:**
- The badge count is the number of pending clips (`pendingClipsProvider`'s list length). While loading or on error: 0 (no badge), never a spinner or an error in the nav pill.
- The badge is on the To tag item on every tab (Reels, To tag, Settings), as the design draws it.
- Semantics: with n > 0 the To tag item reads `l10n.toTagBadgeSemantics(n)` (existing string); at 0 it reads "To tag".
- No new strings, no new metrics, no change to `taketray_ui`.

- [ ] **Step 1: Write the failing tests** (widget tests on the shell with the provider overridden by a `StreamController<List<Clip>>`, using the existing test fixtures for clips and the router setup other shell tests use):
  - `'no clips waiting: no badge'` — emits `[]`: `find.byType(TtCountBadge)` shows nothing visible (match how `TtCountBadge` hides at 0 — assert its `count` is 0 or that no "0" text appears), semantics label of the To tag item is "To tag".
  - `'7 clips waiting: the To tag tab shows 7'` — emits 7 clips: the badge text `7` is found inside the To tag nav item; semantics label equals `toTagBadgeSemantics(7)`.
  - `'the badge follows the stream'` — 3 then 1 then 0: the text changes 3 → 1 → gone without rebuilding the shell from scratch.
  - `'shown on every tab'` — with 2 clips, go to Reels, To tag and Settings: the badge `2` is visible on each.
  - `'while loading or on error there is no badge'` — before the first event, and after `addError`: no badge, no error widget, nav pill still works (tap a tab).
  - `'over 99 shows 99+'` — 120 clips: text `99+`.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/shell/views/app_shell_test.dart`. Expected: FAIL (the placeholder always gives 0, so every test that expects a badge fails; the "no badge" tests may already pass, record that).
- [ ] **Step 3: Implement**: `AppShell extends ConsumerWidget`; `final toTagCount = ref.watch(pendingClipsProvider).value?.length ?? 0;` (or a small `pendingClipCount` provider if that reads better); delete `_clipsToTag` and its comment.
- [ ] **Step 4: Run** the test file, then `tool/check` (must end `ALL CHECKS PASSED`). If an app golden that shows the nav pill changes because its fixture has pending clips, update it on macOS, look at it, and say so in the report.
- [ ] **Step 5: Mutation checks:** put the constant 0 back (the 7-clips test fails); read `skippedCount` instead (the count test fails); use `ref.read` instead of `ref.watch` (the follows-the-stream test fails).
- [ ] **Step 6: Docs and commit** `fix(shell): the To tag tab shows how many clips wait`.
  - **D-184** in `docs/decisions.md`: the owner's report, the cause (the Phase 0 placeholder never wired in Phase 5), the source chosen (`pendingClipsProvider`, read-only, the same as the Shooting mode card, D-76), loading/error → no badge.
  - `docs/flow.md`: the shell / nav pill section says where the count comes from.
  - `docs/later.md`: nothing, unless you find another placeholder of the same kind (`grep -rn "until .* phase" app/lib`): list any you find in the report, don't fix them.

---

### Task 7: `TtRailButton` and the `onVideo` reel chips

**Model:** Sonnet. **D-178.**

**Files:**
- Create:
  - `packages/taketray_ui/lib/src/components/rail_button.dart`
  - `test/components/rail_button_test.dart`
  - `rail_button_golden_test.dart`
  - `widgetbook/lib/components/rail_button.dart` (and its import in `widgetbook/lib/catalog.dart`)
- Modify:
  - `reel_chip.dart`
  - `tt_metrics.dart`
  - `tt_colors.dart` (new colours in the constructor, `lerp` and `copyWith`)
  - `lib/taketray_ui.dart` (export)
  - `widgetbook/lib/components/reel_chip.dart`
- Test: `reel_chip_test.dart`, `reel_chip_golden_test.dart`, `glass_pixels_test.dart`.

**Interfaces:**
- Produces:
  ```dart
  class TtRailButton extends StatelessWidget {
    const new({required this.icon, required this.label, required this.semanticLabel,
               this.detail, this.onPressed, super.key});
    final IconData icon;        // Symbols.redo_rounded / Symbols.repeat_rounded
    final String label;         // labelMedium, white
    final String semanticLabel; // the whole button's one name
    final String? detail;       // labelSmall, white @ .85, one line, ellipsis
    final VoidCallback? onPressed; // null: opacity .45, Semantics(enabled: false)
  }
  enum TtReelChipStyle { surface, onVideo }
  // TtReelChip(..., this.style = TtReelChipStyle.surface)
  // TtNewReelChip(..., this.style = TtReelChipStyle.surface)
  ```
  - **Rail button:** `ClipRRect(20) → BackdropFilter(blur 12) → ColoredBox(TtColors.railGlass) → Material(transparency) → InkWell → Padding(8 v, 4 h) → Column(icon 24, gap 1, label, detail?)`.
    - It is at least 64 × 64 and grows with its text, in both directions.
    - At 1× the detail is at most 56 dp wide.
    - It is one button node named `semanticLabel`.
  - **`onVideo` chip:**
    - glass: `ClipRRect(18) → BackdropFilter(blur 14) → ColoredBox(fill) → Material(transparency) → InkWell`, with the picked border painted on top;
    - idle fill `TtColors.dockChipGlass`; the name in white; the count in white @ .78;
    - picked and done keep today's fills (primaryContainer and primary), with the count at .85 opacity;
    - at least 52 dp high, with a 30 × 40 cover;
    - the rest as today (semantics, long press, the large-text two-line name).
  - **`onVideo` New reel:**
    - fill `TtColors.dockNewChipGlass` with the same blur;
    - a 1.5 dp dashed border in `TtColors.dockNewChipBorder`;
    - the title in white and the subtitle in white @ .78;
    - the cover keeps the secondary container and the plus.
  - **Metrics**, each with its CSS line:
    - `railButtonSize 64`, `railButtonRadius 20`, `railButtonBlur 12`, `railButtonPaddingVertical 8`, `railButtonPaddingHorizontal 4`, `railButtonLineGap 1` (`player2.css:33`);
    - `railButtonIconSize 24` (`:34`);
    - `railButtonDetailMaxWidth 56`, `railButtonDetailOpacity .85` (`:35`);
    - `railButtonDisabledOpacity .45` (`:36`);
    - `reelChipOnVideoMinHeight 52`, `reelChipOnVideoBlur 14` (`:44`);
    - `reelChipOnVideoCountOpacity .78` (`:45`);
    - `reelChipOnVideoCoverWidth 30`, `reelChipOnVideoCoverHeight 40` (`:46`);
    - `reelChipOnVideoStateCountOpacity .85` (`:49`).
  - **Colours** (fixed, the same in light and dark, as `glassOnMedia`):
    - `railGlass = Color(0xBD121316)` (`:33`, rgba 18,19,22,.74);
    - `dockChipGlass = Color(0xD61E2024)` (`:44`, rgba 30,32,36,.84);
    - `dockNewChipGlass = Color(0x8C1E2024)` (`:50`, .55);
    - `dockNewChipBorder = Color(0x8CFFFFFF)` (`:50`).
- [ ] **Step 1: Write the failing tests:**
  ```dart
  testWidgets('rail button: 64 × 64, radius 20, glass 0xBD121316 blurred by 12', …)
      // getSize ≥ 64×64; expectBlurFilter 12; expectGlassStructure; pixel expectBlurred(fill .74)
  testWidgets('rail button: label and detail; detail one line, cut at 56 dp', …)
  testWidgets('rail button off: 45 %, announced disabled with its name', …)
      // Opacity.opacity == .45; semantics: isButton, !isEnabled, label == semanticLabel
  testWidgets('rail button at 2x grows and nothing overflows', …)
  testWidgets('rail detail reads AA over a white frame', …)  // ttTextContrastGuideline over ColoredBox(white)
      // ≥ 4.5:1. White @ .85 on .74 glass over pure white works out near 6.4:1, not
      // the handoff's 7.8:1; report the measured ratio in D-178.
  testWidgets('onVideo chip: 52 dp, 30 × 40 cover, glass 0xD61E2024 blurred by 14', …)
  testWidgets('onVideo chip: white name, count at 78 %; picked and done keep their fills, count 85 %', …)
  testWidgets('onVideo New reel: 55 % glass, dashed white 55 % border, white title', …)
  testWidgets('onVideo chips read AA over a white frame', …)
  testWidgets('surface chips are unchanged', …)  // existing reel_chip tests and goldens untouched
  ```
  Goldens:
  - `rail_button` (dark only: idle, with detail, off, 2×);
  - `reel_chip` gains onVideo scenarios (dark only: idle, picked, done, New reel, no-reels full width), drawn over a gradient stand-in for the clip.
- [ ] **Step 2: Run** `../../tool/flutter test test/components/rail_button_test.dart test/components/reel_chip_test.dart test/components/glass_pixels_test.dart`. Expected: FAIL (undefined).
- [ ] **Step 3: Implement**, plus the widgetbook pages (`(cd widgetbook && ../tool/flutter test)` passes the catalogue coverage test).
- [ ] **Step 4: Run** the tests and the macOS goldens (`--update-goldens` for the new and changed files, then look at them), and `tool/check`. Expected: PASS and `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - a disabled opacity of 1: the off test fails;
  - the chip's `ColoredBox` swapped for `Material(color:)`: the structure test fails;
  - a count opacity of .85 when idle: the colour test fails.
- [ ] **Step 6: Docs and commit** `feat(ui): TtRailButton and on-video reel chips`. **D-178**; `flow.md` design-system section "The tag player's glass pieces" (new).

---

### Task 8: `TtReelDock`, the header chevrons and the top scrim

**Model:** Sonnet. **D-179.**

**Files:**
- Create:
  - `packages/taketray_ui/lib/src/components/reel_dock.dart`
  - `test/components/reel_dock_test.dart`
  - `reel_dock_golden_test.dart`
  - `widgetbook/lib/components/reel_dock.dart` (with its catalog import)
- Modify:
  - `player_chrome.dart` (`TtPlayerHeader`, new `TtPlayerTopScrim`)
  - `tt_metrics.dart`
  - `lib/taketray_ui.dart`
  - `widgetbook/lib/components/player_chrome.dart`
- Test: `player_chrome_test.dart` (or the file testing `TtPlayerHeader` today), its golden.

**Interfaces:**
- Consumes: `TtReelChip(style: onVideo)`, `TtNewReelChip(style: onVideo)` (Task 7).
- Produces:
  ```dart
  class TtReelDock extends StatelessWidget {
    const new({required this.title, required this.semanticLabel, required this.chips,
               this.scrub, this.actions = const [], this.emptyText, this.footer, super.key});
    final String title;               // "Add to reel" / "Pick reels", titleSmall white
    final String semanticLabel;       // "Reels": one group
    final List<Widget> chips;         // two columns; a TtNewReelChip(fullWidth: true) takes a row
    final Widget? scrub;              // the scrub line, first row, padded 0/4/2 (player2.css:39)
    final List<Widget> actions;       // header text buttons, in order
    final String? emptyText;          // centred above the chips, white @ .85 (:52)
    final Widget? footer;             // under the grid, 4 dp above it (:51)
  }
  class TtHeaderChevron {
    const new({required this.semanticLabel, this.onPressed}); // null: 35 %, Semantics(enabled: false)
    final String semanticLabel; final VoidCallback? onPressed;
  }
  // TtPlayerHeader(..., this.previous, this.next): TtHeaderChevron? each; 48 dp
  // TtIconButton(onVideo) with Symbols.chevron_left_rounded / chevron_right_rounded
  // (mirrored in RTL) on either side of the title; wrapSubtitle: true now wraps at
  // every scale, with no line limit and no ellipsis (handoff: "wraps, never cuts").
  class TtPlayerTopScrim extends StatelessWidget {
    const new({required this.child, super.key}); // paints the top gradient behind child
  }
  ```
  - **Dock layout:**
    - the dock scrim is painted behind its own content;
    - padding 28 top, 12 sides, 22 bottom plus `MediaQuery.paddingOf(context).bottom`;
    - rows 8 apart: scrub, header, grid, footer;
    - the header is at least 40 dp high (`:40`); its title is `Expanded`, then the actions;
    - from `TtMetrics.largeTextScale` the header is a `Wrap` and the grid is one column (`:56-57`);
    - the grid scrolls past `reelDockGridMaxHeight` at **every** scale. The CSS caps it only at large text, but in Pick several the grid can hold many picked reels, and the clip must keep its room. This is recorded in D-179.
  - **Scrims** (painters that compute their stops from their own height `h`):
    - dock: colours black @ [0, .74, .90, .90] at stops [0, min(26/h, .5), .5, 1] (`player2.css:31`);
    - top: black @ [.78, .70, 0] at stops [0, (h − 24)/h, 1], clamped to [0, 1] (`:21`);
    - neither takes touches or is announced.
  - **Metrics:**
    - `reelDockPaddingTop 28`, `reelDockPaddingSide 12`, `reelDockPaddingBottom 22`, `reelDockGap 8` (`:31`);
    - `reelDockScrimMidOpacity .74`, `reelDockScrimMidAt 26`, `reelDockScrimEndOpacity .90`, `reelDockScrimEndStop .5` (`:31`);
    - `reelDockHeaderHeight 40` (`:40`), `reelDockGridGap 8` (`:43`), `reelDockFooterGap 4` (`:51`);
    - `reelDockGridMaxHeight 260` (`:56`);
    - `playerTopScrimStartOpacity .78`, `playerTopScrimHoldOpacity .70`, `playerTopScrimFade 24` (`:21`);
    - `playerChevronDisabledOpacity .35` (`:6`).
  - Rename `TtMetrics.tagPanelSingleColumnTextScale` to `reelDockSingleColumnTextScale` (`reel_chip.dart` reads it).
- [ ] **Step 1: Write the failing tests:**
  ```dart
  testWidgets('dock: padding 28/12/22 + the gesture inset, rows 8 apart', …)
  testWidgets('dock: two columns of 164 dp at 360, 8 apart', …)
  testWidgets('dock: a full-width New reel takes a row, under the empty text', …)
  testWidgets('dock is one group named Reels; the title is a heading', …)
  testWidgets('dock scrim stops: 0 at the top, .74 at 26 dp, .90 from half way', …)
      // read the painter's gradient for h = 300: stops [0, 26/300, .5, 1]
  testWidgets('dock scrim on a short dock clamps the 26 dp stop to half way', …) // h = 40
  testWidgets('dock text reads 10:1-class AA over a white frame', …)  // ≥ 4.5 measured
  testWidgets('2x: one column, scrolls within 260 dp, header wraps', …)  // Review Focus 4
  testWidgets('many chips at 1x: the grid scrolls within 260 dp', …)
  testWidgets('header chevrons: 48 dp, either side of the title, off at 35 % and announced disabled', …)
  testWidgets('header: the scene line wraps and is never cut, at 1x and 2x', …)
      // a 60-character subtitle between chevrons: no ellipsis, didExceedMaxLines false
  testWidgets('header without chevrons is unchanged (the clip viewer)', …)
  testWidgets('top scrim stops: .78, .70 until 24 dp above its bottom, then clear', …)
  testWidgets('scene line reads AA on the top scrim over a white frame', …)
  ```
  Goldens:
  - `reel_dock`, dark: 4 chips, no reels, Pick several with a footer, 2×;
  - `player_chrome` gains the chevron header (on, off, 2×).
- [ ] **Step 2: Run** `../../tool/flutter test test/components/reel_dock_test.dart test/components/player_chrome_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**, plus widgetbook.
- [ ] **Step 4: Run** the tests, the macOS goldens and `tool/check`. Expected: PASS and `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - the 26 dp stop without the clamp: the short-dock test fails;
  - the 260 cap only at large text: the 1× test fails;
  - `maxLines: 1` on the subtitle: the wrap test fails.
- [ ] **Step 6: Docs and commit** `feat(ui): TtReelDock, player header chevrons and the top scrim`. **D-179**; `flow.md` design-system lines.

---

### Task 9: The stage: cover or contain, never blurred

**Model:** Opus. **D-180.**

**Files:**
- Create:
  - `app/lib/features/tagging/views/stage_fit.dart`
  - `app/test/features/tagging/views/stage_fit_test.dart`
- Modify:
  - `app/lib/features/tagging/views/tag_player_screen.dart:786-1130` (`_Stage`, `_VideoBox`, `_Loading`, `_Playing`)
  - `packages/taketray_ui/lib/src/theme/tt_metrics.dart:1195-1235`
- Test: `tag_player_screen_test.dart` (group "the clip showing").

**Interfaces:**
- Produces:
  ```dart
  /// The share of [clip] that BoxFit.cover in [area] cuts off (0..1), the
  /// handoff's sum: s = max(aw/cw, ah/ch); crop = 1 − min(aw/(cw·s), ah/(ch·s)).
  double coverCrop({required Size area, required Size clip});
  /// BoxFit.cover unless covering cuts more than TtMetrics.tagStageMaxCoverCrop
  /// (+1e-9, so exactly 20 % covers); BoxFit.cover for an empty or unknown size.
  BoxFit stageFit({required Size area, required Size clip});
  ```
  - `_Stage` gains `double bottomInset = 0`. A contained clip is centred in the area above that inset (Task 10 passes the dock's height); a covering clip fills the whole stage. The stage has `key: ValueKey('tag-stage')`.
  - The video is a `FittedBox(fit: stageFit(...), clipBehavior: Clip.hardEdge)` around a `SizedBox` of the clip's size. That size is `value.size` once the player is initialized, else `clip.width × clip.height`, else 9:16.
  - The loading state is the thumbnail with the same fit, black @ `tagStageLoadingOpacity` (.35, `player2.css:12`) and the spinner.
  - Paused shows the 64 dp disc, black @ .45, with a 36 dp play icon (`:11`).
  - There is no `ImageFiltered`, no rounded `_VideoBox` and no shadow.
  - **Metrics deleted:**
    - `tagStageBlur`, `tagStageDimOpacity`, `tagStageBlurScale`;
    - `tagStageVideoRadius`, `tagStageVideoShadowBlur`, `tagStageVideoShadowOffset`, `tagStageVideoShadowOpacity`.
  - **Metrics added:**
    - `tagStageMaxCoverCrop .20` (handoff "The clip");
    - `tagStagePlayDiscSize 64`, `tagStagePlayDiscOpacity .45`, `tagStagePlayIconSize 36` (`:11`).
  - Task 11 replaces `tagStageSlideDistance` and `tagStageSlideScale`, so they stay for now.
- [ ] **Step 1: Write the failing tests:**
  ```dart
  test('9:16 on 360 × 800 crops exactly 20 % and covers', …)
      // coverCrop(Size(360,800), Size(1080,1920)) closeTo(.2, 1e-9); stageFit == cover
  test('9:16 on the S24 (384 × 832) crops 18 % and covers', …)  // closeTo(.1795, 1e-3)
  test('16:9 is contained', …)   // crop closeTo(.747, 1e-3); contain
  test('1:1 is contained', …)    // .55
  test('3:4 is contained', …)    // .40
  test('4:5 is contained', …)    // .4375
  test('a clip as tall as the screen shape crops nothing', …) // 1080 × 2400 → 0, cover
  test('an empty or unknown size covers', …)   // Size.zero, Size(0, 1920), NaN → cover
  testWidgets('no blur anywhere on the stage', …)
      // find.byType(ImageFiltered) and BackdropFilter under ValueKey('tag-stage'): none
  testWidgets('a vertical clip covers the stage, centred', …)
      // VideoPlayer rect contains the stage rect; centres equal
  testWidgets('a horizontal clip is shown whole, centred above the bottom inset', …)
  testWidgets("the player's own shape wins once it starts", …)  // Review Focus 2
      // clip row 1080 × 1920, platform.size 1920 × 1080 → contain after init
  testWidgets('paused shows the 64 dp disc at 45 %', …)
  ```
  Replace `'a horizontal video is letterboxed 16:9'` and `'a vertical video is 9:16 and fits the stage'` (`:399`, `:411`) with these tests.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/tagging/views/stage_fit_test.dart test/features/tagging/views/tag_player_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the same, then `tool/check`. Expected: PASS and `ALL CHECKS PASSED`. Do not update the player goldens yet: Task 10 rewrites them.
- [ ] **Step 5: Mutation checks:**
  - `>` changed to `>=` without the epsilon: the 20 % test fails;
  - the stored size used after init: the shape test fails.
- [ ] **Step 6: Docs and commit** `feat(tagging): full-bleed stage, cover or contain, no blur`. **D-180**; `flow.md` "The tag player screen and All done" › "The stage".

---

### Task 10: The full-screen player: stack, scrims, dock, rail, snack, All reels

**Model:** Opus. **D-181** (amends D-97's layout).

**Files:**
- Create:
  - `app/lib/features/tagging/views/dock_reels.dart`
  - `app/lib/features/tagging/views/all_reels_sheet.dart`
  - `app/test/features/tagging/views/dock_reels_test.dart`
- Modify:
  - `tag_player_screen.dart` (`build`, `_top`, `_bottomBar` → `_dock`, `_panel` → the dock and the rail)
  - `app/lib/l10n/app_en.arb`
- Delete:
  - `packages/taketray_ui/lib/src/components/tag_panel.dart` (`TtTagPanel`, `TtOtherReelsToggle`, `TtSameAsPreviousButton`), its tests and goldens (`goldens/ci` and `goldens/macos`), and its export;
  - `widgetbook/lib/components/tag_panel.dart` and its catalog entry. Update `widgetbook/lib/components/video_surface.dart:171`, which uses `TtTagPanel`, to show a `TtReelDock`;
  - the `tagPanel*` metrics;
  - l10n keys left unused (`tagOtherReelsCount`; check the others with `grep`).
- Test: `tag_player_screen_test.dart` (rewrite the groups "the panel", "moving between clips" (the arrows) and "large text and accessibility"); `tag_player_golden_test.dart` (all new images).

**Interfaces:**
- Consumes:
  - `TtReelDock`, `TtHeaderChevron`, `TtPlayerTopScrim` (Task 8);
  - `TtRailButton`, `TtReelChipStyle.onVideo` (Task 7);
  - `_Stage(bottomInset:)`, `stageFit` (Task 9).
- Produces:
  ```dart
  /// What the dock shows, from the reels in Home's order (newest first).
  typedef DockReels = ({List<ReelSummary> grid, bool newReel, bool allReels, bool pickSeveral});
  DockReels dockReels(List<ReelSummary> ordered, {required bool multi, required List<int> picked});
  ```
  - **The rules** (handoff "Dock", `player2.js` `full()`):
    - `grid` is the first 3 Collecting reels; in `multi`, followed by every other picked reel in `ordered` order, with no duplicates;
    - `newReel` is `!multi`;
    - `allReels` is shown when more than 3 reels are Collecting, or there is any non-Collecting reel;
    - `pickSeveral` is shown with 2 or more reels.

  ```dart
  Future<void> showAllReelsSheet(BuildContext context, {required int? startClipId,
      required ValueChanged<int> onTag, required VoidCallback onNewReel});
  ```
  - **The All reels sheet:**
    - a `showTtSheet` whose content is wrapped in `Theme(data: TakeTrayTheme.video())`. It watches `tagSessionControllerProvider(startClipId)` and `reelSummariesProvider` itself, so picks update live.
    - The title is `tagPanelTitle`, or `tagPickTitle` while picking.
    - It holds "Collecting" (`statusCollecting`) with its surface-style chips, then a `TtNewReelChip` (with subtitle), then "Other reels" (`tagOtherReels`) with the Ready and Published chips.
    - While picking, the chips are `multiSelect` (they toggle the pick), and a full-width filled **Done** (`tagAllReelsDone`) closes the sheet.
    - In single mode a reel tap pops the sheet, then calls `onTag(id)` once. A second tap during the pop does nothing.
    - New reel pops the sheet, then calls `onNewReel`.
    - It is opened through `OpenOnce`.
  - **The layout** of `TagPlayerScreen.build`, loaded and not done: a `Scaffold(backgroundColor: videoBackground, resizeToAvoidBottomInset: false)` with no `bottomNavigationBar`. Its body is a `Stack(fit: expand)` of:
    1. `_Stage(bottomInset: dockHeight)`, under the status bar (no `SafeArea`).
    2. `Positioned(top: 0, left: 0, right: 0)`: `TtPlayerTopScrim(key: ValueKey('tag-top'))`, padded by the status bar inset + `tt.spacing.xxs` at the top and `playerTopScrimFade` (24) at the bottom. It holds `TtSegmentBar` (margins 16, height 3) and `TtPlayerHeader`:
       - Close;
       - `previous: TtHeaderChevron(semanticLabel: l10n.viewerPrevious, onPressed: state.hasPrevious ? controller.previous : null)`;
       - the title, then `next` the same way;
       - Mute;
       - `wrapSubtitle: true`, with the full "Scene {s} of {S} · {range}" at every scale. The large-text range-only rule goes: the line now wraps.
    3. `Positioned(bottom: 0, left: 0, right: 0)`: `TtReelDock(key: ValueKey('tag-dock'))`, with:
       - the `ClipScrubber` as `scrub`;
       - title `tagPanelTitle`, or `tagDockPickTitle` in multi;
       - actions: [Pick several (`library_add_check`) if `pickSeveral`, All reels (`tagAllReels`, `Symbols.apps_rounded`) if `allReels`], or in multi [All reels if `allReels`, Cancel];
       - chips: the `onVideo` `TtReelChip`s of `grid`, then the `onVideo` `TtNewReelChip` if `newReel`; with no reels, `emptyText: tagNoReels` and a full-width New reel;
       - footer: in multi, the existing confirm button.

       Its height is measured after layout (a size-reporting render object or a `GlobalKey`, never a constant) into `dockHeight`.
    4. **The rail**, unless multi: `PositionedDirectional(end: 12, bottom: dockHeight + 4)`, keyed `ValueKey('tag-rail')`. It is a `Column` of two `TtRailButton`s, 10 apart (`player2.css:32`):
       - Skip: `redo`, `tagPlayerSkip`, `tagPlayerSkipSemantics`, which calls `_act(controller.skip)`;
       - Same: `repeat`, `tagRailSame`, with `detail` the reel names joined `", "`. Its semantic label is `tagPlayerSameSemantics(names)`, or `tagRailSameNone` with `onPressed: null` when nothing has been tagged yet.

     The rail and the snack get metrics `railInsetEnd 12`, `railAboveDock 4` (`:32`), `railGap 10` (`:32`), `playerSnackInsetStart 12`, `playerSnackInsetEnd 88` and `playerSnackAboveDock 8` (`:38`; 12 from the handoff).
  - **Traversal order** (`Semantics(sortKey: OrdinalSortKey(i))` on the groups): top 0, stage 1, rail 2, dock 3. That gives Close, Previous, the title, Next, Mute, the clip, Skip, Same, then the dock: Pick several, All reels, the reels, New reel.
  - **The snack:**
    - the player's `Theme` sets `snackBarTheme.insetPadding` so that a floating snack's bottom edge is 8 dp above the dock's top, with 12 dp at the start and 88 at the end (mirrored in RTL, like the rail);
    - the Scaffold adds the bottom view padding to a floating snack, which the formula accounts for. The test's geometry is the contract;
    - snacks still go to the root messenger (D-85). The player's `Scaffold` is a root scaffold of it, so its theme places them.
  - The status bar keeps its light icons (whatever sets them for the player today stays, and its test with it).
  - **Strings** (verbatim, in `app_en.arb` with descriptions):
    - `tagRailSame` "Same";
    - `tagRailSameNone` "Same as previous: nothing tagged yet";
    - `tagAllReels` "All reels";
    - `tagDockPickTitle` "Pick reels";
    - `tagAllReelsDone` "Done".
- [ ] **Step 1: Write the failing tests.**

  `dock_reels_test.dart` (summaries from `test/support/reel_summaries.dart`):
  ```dart
  test('no reels: an empty grid, New reel, no All reels, no Pick several', …)
  test('one Collecting reel: it and New reel; no Pick several', …)
  test('three Collecting: all three, no All reels', …)
  test('four Collecting: the three newest, All reels', …)
  test('two Collecting and one Ready: both, All reels', …)
  test('only Ready reels: an empty grid, New reel, All reels, Pick several', …)
  test('picking: the three plus a picked Ready reel and a picked 5th Collecting, in Home order', …)
  test('picking: a picked reel among the three is not repeated; no New reel', …)
  ```

  `tag_player_screen_test.dart`, at 360 × 800 with a 24 dp status bar:
  ```dart
  testApp('the clip fills the screen under the status bar', …)  // stage rect == (0,0,360,800)
  testApp('a contained clip is centred above the dock', …)
  testApp('the top: segments, Close, ‹ title ›, Mute; ‹ off on the first clip', …)
  testApp('the dock shows at most three Collecting reels plus New reel', …)
  testApp('All reels only when needed', …)          // 3 Collecting: none; add a Ready reel: shown
  testApp('tagging from All reels closes it and tags', …)
      // tap All reels → sheet; tap "Old shoot" (Ready) → sheet gone; hold → tagged once
  testApp('a double tap in All reels tags once', …)
  testApp('New reel from All reels opens the reel form', …)
  testApp('Pick several: Pick reels, All reels, Cancel; no rail; a reel picked in All reels joins the dock', …)
  testApp('the rail sits 12 dp from the end, 4 dp above the dock, 10 dp apart', …)
  testApp('Same is off at 45 % until something is tagged, then names the reels', …)
  testApp("the snack's right edge stays clear of the rail", …)
      // after a tag: snack.right <= rail.left; snack.left == 12; snack.bottom closeTo(dock.top − 8, .5)
  testApp('the snack follows the dock when it grows (Pick several, 2x)', …)
  testApp('focus order: Close, Previous, title, Next, Mute, the clip, Skip, Same, Pick several, All reels, the reels, New reel', …)
      // tester.semantics.simulatedAccessibilityTraversal() labels, in order
  testApp('text on the scrims and the glass is AA over a white clip', …)
      // the fake video drawn white; ttTextContrastGuideline passes
  testApp('2x text: one column, the rail keeps its place, no overflow', …)
  testApp('2x on a small phone (360 × 640): no overflow, the grid scrolls, the footer is reachable', …) // Review Focus 4
  testApp('the old panel is gone', …)   // no TtTagPanel, TtStageArrow or TtSameAsPreviousButton type in the tree
  testApp('every control has a label; meets the accessibility guidelines', …)  // kept, rewritten
  ```
  Rewrite every existing test that used `TtButton` Skip, `TtSameAsPreviousButton`, `TtStageArrow` or "Other reels" to use the rail, the chevrons and All reels. The behaviour they pin (holds, Undo, leaving during a hold, New reel, D-132) stays.

  Goldens (`tag_player_golden_test.dart`, dark, 1× and 2×, macOS): `tag_player_{first,tagged,tap,pick,loading,long,horizontal,no_reels,all_reels,paused,done}_{1x,2x}`. They are:
  - the first clip;
  - just tagged (with the snack);
  - the tap moment (the check held, `holds` not fired);
  - picking several;
  - loading;
  - a long clip;
  - horizontal;
  - no reels;
  - the All reels sheet;
  - paused;
  - All done.

  Delete the old images (`mid` and the others) that are no longer written.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/tagging`. Expected: FAIL.
- [ ] **Step 3: Implement**, including the deletions.
- [ ] **Step 4: Run**:
  - `../tool/flutter test test/features/tagging`;
  - `../tool/flutter test --update-goldens test/features/tagging/views/tag_player_golden_test.dart`, then compare each image with hub screen 12's states by eye and list any difference in the report;
  - `(cd widgetbook && ../tool/flutter test)`;
  - `tool/check`.

  Expected: PASS and `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - the dock height hard-coded to 300: the "snack follows the dock" test fails;
  - All reels shown always: the "only when needed" test fails;
  - the rail shown in multi: the Pick several test fails;
  - the sort keys removed: the focus-order test fails.
- [ ] **Step 6: Docs and commit** `feat(tagging): the full-screen tag player (dock, rail, All reels)`.
  - **D-181**, amending D-97's layout. It records the 260 dp cap at 1×, the rail mirrored in RTL, the range-only rule dropped, and `TtTagPanel` removed.
  - `flow.md` "The tag player screen and All done" › **Building** step 3, **A chip**, **The snack**, **In tests**, and the new All reels paragraph.
  - `docs/later.md`: delete "Next: the full-screen tag player".

---

### Task 11: Vertical swipes and the slide motion

**Model:** Opus. **D-182.**

**Files:**
- Modify:
  - `tag_player_screen.dart` (`_SwipeArea` → `_VerticalSwipe`, `_SlideIn` → `_ClipMotion`, `_noteClip`)
  - `tt_metrics.dart:1224-1231` (the slide metrics)
- Test: `tag_player_screen_test.dart` (group "moving between clips").

**Interfaces:**
- Consumes:
  - the existing `controller.next()` and `previous()`, and `state.hasNext` and `hasPrevious`;
  - `TagQueue(state.session).next(state.index, state.pending)` and `.previous(…)`, read-only, to know the neighbour clip whose thumbnail comes in;
  - `clipThumbnail(clip:, logicalSize: homeCoverSize, cache:)` and `stageFit`.
- Produces:
  - **The drag:**
    - a `GestureDetector` with **vertical** drag callbacks only, around the stage;
    - taps still reach the video, and horizontal drags do nothing;
    - while dragging, the current stage is translated by the finger's `dy`, and the neighbour in that direction (next when dragging up) is drawn as its thumbnail, with its own `stageFit`, at `dy ± stageHeight`;
    - no neighbour (an end of the session) draws black, and the drag still follows.
  - **Release:**
    - it **goes** when the drag direction has a neighbour, the session is idle (`!busy && confirmingReelId == null`), and either `|dy| > tagSwipeDistance` (64) or the fling velocity is past `tagSwipeVelocity` (800 dp/s) in the same direction;
    - going animates `dy` to `∓stageHeight` over `short4` with `emphasizedAccelerate`, then calls `next()` or `previous()` and marks the move as **swiped**, so `_noteClip` sets no slide-in;
    - otherwise the drag springs back to 0 over `short4` with `standard`;
    - a cancelled drag (the arena lost, a route pushed on top) springs back;
    - after any commit the offset is 0 on the next build, whatever the session did, so the stage is never left off screen.
  - **Moves without a drag** (a tag, Skip, Same, ‹ ›, Undo, Previous):
    - Next: the outgoing clip, drawn as its **thumbnail** (so its player is let go at once and the two-controller rule holds), slides up and out by one stage height over `short4` with `emphasizedAccelerate`;
    - at the same time the incoming stage slides up from `tagStageSlideFrom` (16 %) below and fades from `tagStageSlideFromOpacity` (.3) to 1, over `medium2` with `emphasizedDecelerate` (`player2.css:17-20`);
    - Previous and Undo are the mirror image.
  - **Reduced motion** (`MediaQuery.disableAnimationsOf`): no travel and no drag-follow. A move is a crossfade over `TtMetrics.reducedMotionCrossfadeMillis` (150), a fixed value because the reduced `TtMotion` is zero. A drag past the thresholds still moves, with that crossfade.
    - The handoff says "(as before)", but today's `_SlideIn` does nothing under reduced motion. The owner ruled for the 150 ms crossfade, and D-182 says so.
  - The incoming clip's thumbnail shows until its player takes over (spec call 5): the next clip's player is already open (preload); the previous one opens on arrival and shows `_Loading` (its thumbnail and the spinner).
  - **Metrics:**
    - `tagSwipeDistance 64` and `tagSwipeVelocity 800` (handoff "Gestures");
    - `tagStageSlideFrom .16` and `tagStageSlideFromOpacity .3` (`player2.css:19-20`);
    - `reducedMotionCrossfadeMillis 150` (handoff "Motion");
    - delete `tagStageSlideDistance` and `tagStageSlideScale`, and the `_swipeMinDistance` constant.
- [ ] **Step 1: Write the failing tests** (3 to 5 clips, `animations: true` where motion is measured):
  ```dart
  testApp('a drag up follows the finger and brings the next clip's thumbnail', …)
      // gesture at (180, 300), moveBy(0, -40): stage dy == -40; the next clip's
      // Image (its thumbnail provider) top == 800 - 40; no VideoPlayer for it yet
  testApp('a slow drag past 64 dp goes; 50 dp springs back', …)  // 2 of 3; then 1 of 3 and dy 0
  testApp('a fast short fling (40 dp at 1000 dp/s) goes; 40 dp at 600 springs back', …)
  testApp('a drag down goes to the previous clip', …)
  testApp('at the ends the clip springs back', …)   // first: drag down 120 → 1 of 3, dy 0; last: drag up
  testApp('a horizontal drag does nothing', …)   // flingFrom((180,300), (-200,0), 2000) → 1 of 3, dy 0
  testApp('a swipe that settles does not slide in again', …)  // no translation or opacity on the new stage
  testApp("the incoming clip's thumbnail shows until its player takes over", …)
      // platform.hold: after a swipe to Previous, _Loading with its thumbnail; release → VideoPlayer
  testApp('a missing thumbnail comes in as black', …)   // no cached thumbnail / error → no error widget
  testApp('a tag slides the clip up and out; the next comes up from 16 % and fades in from .3', …)
      // t=0: incoming FractionalTranslation dy .16, Opacity .3; t=medium2: 0, 1; outgoing gone after short4
  testApp('Undo and Previous slide the mirror way', …)       // from -.16
  testApp('‹ › move with the same slide; off at the ends', …)   // replaces 'arrows disabled at the ends'
  testApp('reduced motion: a 150 ms crossfade, no travel, the drag does not move the clip', …)
  testApp('a swipe during the hold springs back and the clip is tagged once', …)
  testApp('a dialog opened during the slide: the slide ends, the new clip plays, the scrim blurs by 3', …) // Review Focus 5
  testApp('a dialog opened during a drag: the drag is cancelled and springs back', …)
  testApp('a tap still plays and pauses', …)
  testApp('swiping through five clips never keeps more than two controllers', …)
  ```
  Delete `'a swipe that starts in the system gesture edge does nothing'`, `'a short quick flick does not change the clip'` and `'the gesture edges move the swipe area, not the video'` (`:493-546`). Their horizontal rules are gone: Android's side back gesture never meets a vertical swipe. Keep the hand check of the back gesture from both edges (14.13).
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/features/tagging/views/tag_player_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the same, then the player goldens (they must be unchanged: they are static states) and `tool/check`. Expected: PASS and `ALL CHECKS PASSED`.
- [ ] **Step 5: Mutation checks:**
  - a threshold of 32: the 50 dp test fails;
  - a horizontal recognizer added: the horizontal test fails;
  - the swiped flag ignored: the "does not slide in again" test fails;
  - the outgoing clip drawn with its player: the two-controller test fails;
  - the idle check removed: the hold test fails.
- [ ] **Step 6: Docs and commit** `feat(tagging): swipe up and down between clips, with the new slides`. **D-182**; `flow.md` "The stage" (the drag, the commit, the spring back, the motion table, reduced motion).

---

### Task 12: Patrol: the tagging flows on the new player (no device)

**Model:** Sonnet. **D-183.**

**Files:**
- Create:
  - `app/patrol_test/support/player_finders.dart`
  - `app/test/patrol_support/player_finders_test.dart`
- Modify:
  - `app/patrol_test/tagging_test.dart` (`:471-482` finders, the flows, and a new flow)
  - `docs/dev-setup.md` ("Running `tagging_test.dart`")
  - `docs/flow.md` ("On-device test (Patrol)")

**Interfaces:**
- Consumes: the keys and types of Task 10 (`ValueKey('tag-stage')`, `'tag-dock'`, `'tag-rail'`, `TtRailButton`, `TtReelChip`, `TtReelDock`) and Task 11's gestures.
- Produces (`player_finders.dart`):
  ```dart
  Finder railButton(String label);  // TtRailButton with that label
  Finder dockChip(String name);     // a TtReelChip named [name] inside the dock
  Finder sheetChip(String name);    // a TtReelChip named [name] inside a TtSheet
  Finder dockAction(String label);  // a TtButton with that label inside the dock
  Offset stageCentre(WidgetTester tester); // the middle of the clip above the dock
  ```
- [ ] **Step 1: Write the finder tests first** (`player_finders_test.dart`, a widget test that pumps the player as `tag_player_screen_test.dart` does). Each finder finds exactly one widget, and that widget is hit-testable (`tester.hitTestOnBinding` reaches it), as `reel_finders_test.dart` does. `stageCentre` lies above the dock's top and below the top scrim.
- [ ] **Step 2: Run** `cd app && ../tool/flutter test test/patrol_support/player_finders_test.dart`. Expected: FAIL (undefined); then implement the finders, and it passes.
- [ ] **Step 3: Update `tagging_test.dart`:**
  - `_chip` becomes `dockChip`;
  - `_sameAsPrevious` becomes `railButton(_l10n.tagRailSame)`;
  - Skip becomes `railButton(_l10n.tagPlayerSkip)`;
  - Pick several, Cancel and the confirm become `dockAction`;
  - the timing and peak-controller checks of "tag a day" are unchanged.

  Add one flow, `'swipe and All reels: up, down, sideways, and a Ready reel from the sheet'`, with 4 clips:
  1. Fling up from `stageCentre` (0, −300) at 1500: the session index is +1.
  2. Fling down: back to the first clip.
  3. Fling (−300, 0): still the first clip.
  4. Set reel B to Ready through `ReelsRepository.setStatus`, then wait for **All reels** in the dock.
  5. Tap it, then `sheetChip(_nameB)`: the sheet is gone, and after the hold the clip is in B (the repository).
  6. The tear-down puts B back to Collecting.

  Keep the file's safety patterns: positive waits before every absent check, tear-downs that run on failure, only `Movies/TakeTray Test/`, and raw taps without settling.
- [ ] **Step 4: Run** `cd app && ../tool/flutter analyze patrol_test` and `../tool/patrol build android`. Expected: no issues; the build succeeds. **Do not run on a device.**
- [ ] **Step 5: Mutation check:** `dockChip` without the dock ancestor finds two chips once All reels is open, and its test fails.
- [ ] **Step 6: Docs and commit** `test(patrol): tagging flows on the full-screen player`.
  - **D-183**: what changed in the flows and why the new flow exists.
  - `dev-setup.md`: the flow list and the command `tool/patrol test -d RZCY80PHWCZ -t patrol_test/tagging_test.dart`.
  - `flow.md` Patrol items.

---

### Task 13: Docs: the learning guide, README, later.md, the Phase 12 check

**Model:** Sonnet. No new decision. The step review may be skipped (docs only).

**Files:**
- Create: `docs/learn/phase-12-ui-refresh.md`.
- Modify: `README.md`, `docs/later.md`, `docs/dev-setup.md` (a new "Phase 12 check"), `docs/flow.md` (consistency pass only).

- [ ] **Step 1: The learning guide,** in the style of `docs/learn/phase-9b-sharing.md`:
  - How to read;
  - one section per task (1–12);
  - "Why the dialog blur was invisible on the phone" (the A/U/V tests, in plain words);
  - "How CI proves a blur" (stripes, edge contrast, the 0.5 share, the structure check);
  - "Glass and ink" (the `Material` child);
  - "Window blur on Android";
  - "Cover or contain";
  - "Following the finger";
  - a closing summary.
- [ ] **Step 2: README:**
  - add the row `| 12 | UI refresh: glass everywhere and the full-screen tag player (ahead of Phase 11, as 10 came before 9) | Built; phone check pending. **Next: Phase 13** |` **after the 9 row and before the 11 row**;
  - move "**Next: Phase 11**" off the 9 row;
  - add a `### Phase 12: UI refresh` section listing what each task added, in plain words (the readme-progress rule), with "Phone tests: pending (Task 14)".
- [ ] **Step 3: `later.md`:**
  - check that "Next: the full-screen tag player" is gone (Task 10);
  - add under a "Phase 12" heading: **Restyle the reminder time picker** (`app/lib/features/settings/views/settings_rows/reminder_groups.dart:94`, `showTimePicker`). It is the one Material dialog with Material's black-54 barrier and no blur, and it is not in the design, so it is parked until the design has one (spec Non-goals);
  - add the parked Minors that are not fixed in the batch.
- [ ] **Step 4: `dev-setup.md` "Phase 12 check":** the hand checks of Task 14 Step 4, numbered, each with what to look at and what passes. Add "Running `tagging_test.dart`" with the after-run commands.
- [ ] **Step 5:** Run `tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 6: Commit** `docs: Phase 12 learning guide, README, later.md and the phone check`.

---

### After Task 13 (controller)

1. The Minors batch (Sonnet), one commit.
2. The whole-phase review (Opus), one fix wave (Sonnet), and the re-review (the same Opus reviewer, resumed).
3. Push `phase-12-ui-refresh` with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push`. Never force-push.
4. Run the "update goldens" workflow on the branch for the package CI goldens, then `tool/pull_ci_goldens`, commit them, push, and wait for CI to go green on the branch.

---

### Task 14: The S24: Patrol flows, then the owner's side-by-side

**Model:** Sonnet (controller with the owner). Results go into D-172 (the strength verdict), D-181/D-182 (the player checks) and README.

**Safety (repeat before each command):** `-s RZCY80PHWCZ`, `app.taketray.dev` only, logcat `--pid=` only, no screenshots, no reading of shared storage or other apps, Patrol only in `Movies/TakeTray Test/`.

- [ ] **Step 1: Patrol, each file once.** Run `tool/patrol test -d RZCY80PHWCZ -t patrol_test/<file>.dart` for:
  - `tagging_test.dart` first;
  - then `reels_test.dart`, `references_test.dart` (menus, sheets, dialogs and snacks), `editors_test.dart`, `add_videos_test.dart`, `settings_test.dart`, `app_shell_test.dart`, `onboarding_test.dart`, `background_test.dart`, `media_access_test.dart`, `media_scan_test.dart` and `database_test.dart`.

  (`share_test.dart` stays skipped, D-169.)
- [ ] **Step 2: After every Patrol run**, from the repo root:
  ```
  (cd app && ../tool/flutter build apk --debug)
  tool/adb -s RZCY80PHWCZ install -r app/build/app/outputs/flutter-apk/app-debug.apk
  tool/adb -s RZCY80PHWCZ shell pm clear app.taketray.dev
  ```
  A failure is reported to the owner with its step. A test fault is fixed (and reviewed) before the next round; an app fault goes back to its task. Each file runs again only in a new round.
- [ ] **Step 3: Install for the hand checks:** the debug build as above, then open TakeTray Dev and allow video access. Release permissions: `cd app && ../tool/check_release_permissions` ends `RELEASE PERMISSIONS OK`.
- [ ] **Step 4: The hand checks** (owner, TakeTray Dev, the prototype open beside the phone, light and dark). The owner judges each glass element against the prototype; write the verdict per number.
  1. **Screen 9:** Delete reel over a reel's page. The page is blurred and dimmed, not only darker.
  2. **Screen 14:** Skip all over To tag. The same.
  3. **Sheets:** screen 7 (reel form), 13 (reel picker), 16 (viewer › Add to reel), and 12 (All reels in the player). The blur is behind each, and the panels are solid.
  4. **Screens 8 and 11:** a reel page's overflow and references menus, and To tag's menu. The page blurs 3 dp with no dimming. A menu inside a sheet (the Shooting mode references sheet's card menu) blurs both.
  5. **Screen 6 (Home):**
     - the nav pill: saturated glass, no dark cast through it, while the content scrolls under it;
     - the reel cover status pill and the "Editing in VN" pill blur the cover (the F case is now fixed);
     - the references badge;
     - the Shooting mode card's icon tile and references row.
  6. **Snacks** (screens 8, 14, 16): at rest the snack blurs what is under it, inside its corners.
  7. **Strength:** if the owner wants a stronger blur after 1–4, the new value applies to the 3 dp group only (scrim, menu, share window; spec call 1) and goes back through Task 1's tests. Record the verdict in D-172.
  8. **Screen 35, the share over Instagram** (Android 12+):
     - the sheet blurs and dims Instagram;
     - turn on battery saver with the sheet open: dim only, at once;
     - turn it off: the blur comes back;
     - it still works after Done and a second share.
  9. **Screen 12, the player:** the rail and the dock chips blur the **playing video** (the texture, not only a picture) and a clip while it is loading.
  10. A day's clips tagged **one-handed**: swipe, tap reels, Skip and Same under the thumb.
  11. A **horizontal clip** is shown whole, centred above the dock; a vertical one covers the screen.
  12. A **very bright (white) clip:** the scene line, the dock text and the rail's second line all read.
  13. **The back gesture from both edges** leaves the player (and never changes the clip).
  14. **Swipes:**
      - up and down follow the finger;
      - a short slow drag springs back;
      - a quick flick goes;
      - the first and last clips spring back;
      - **smoothness** is judged by eye, with no stutter while swiping (the 60 fps anti-goal; the debug build is slower than release, so a stutter is re-checked on a release build installed over `app.taketray`, with the owner's go).
  15. **2× text:** the dock is one column and scrolls, the header wraps, and the rail keeps its place.
  16. **TalkBack:** the focus order matches Task 10's list; ‹ › at the ends are announced as unavailable; Same reads "nothing tagged yet".
  17. **Remove animations:** clips crossfade, with no travel.
- [ ] **Step 5: Record** the results:
  - README Phase 12: "Phone tests …", with the run counts and any fault found and fixed;
  - `dev-setup.md`: the verdicts;
  - the D-numbers named above.

  Commit `docs: Phase 12 phone results`, push, and open the PR to `main` when CI is green. It merges only on the owner's go.
