# Phase 1: Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `packages/taketray_ui`: generated tokens, the TakeTray theme, every reusable component from the prototype with golden tests in light and dark at 1.0× and 2.0× text, and a Widgetbook catalogue. Then put the app shell on the TakeTray theme and the floating nav pill.

**Architecture:**
- `design/tools/build_tokens.py` stays the single source of design values. It generates `packages/taketray_ui/lib/src/tokens/tokens.g.dart`, and `tool/check` fails if the file is out of date.
- The theme layer turns tokens into `ThemeData` (light, dark, video) plus one `ThemeExtension`, `TtThemeData`, which feature code reads through `context.tt`.
- Components are plain widgets with no app or Riverpod dependency. Every user-facing string comes in as a parameter.
- A `widgetbook/` app is a third workspace member and shows every component.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 via `tool/flutter`, `material_symbols_icons` (Rounded, bundled), `alchemist` (goldens), `widgetbook` (catalogue), Plus Jakarta Sans variable font (bundled in the package), Python 3 stdlib (token generator).

**Spec:** `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md` (§2 visual source of truth, §4, §6, §7, §9 phase 1, §10).

## Visual source of truth

Every component matches the prototype, and implementers read these files for exact values:
- **Structure:** `design/prototype/assets/ui.js` (component functions), `screens.js` and `refs.js`.
- **Base CSS:** `design/prototype/assets/proto.css`.
- **TakeTray overrides:** `design/prototype/assets/tt-style.css`. Its rules win over `proto.css`. The hub always runs in TakeTray style.
- **Old Flutter widgets:** `reference/prototype-app/lib/widgets/tt.dart` and `common.dart` are earlier ports, useful as a starting point. They do not follow the style rule, so don't copy them as they are.

To view a state, open `design/prototype/index.html` in a browser; its screens list shows every state in light and dark.

## Global Constraints

- **SDK:** all Flutter/Dart commands go through `tool/flutter` / `tool/dart` (Flutter **3.47.7**). Never use the `flutter` on PATH (2.8.1), and never touch `~/flutter`.
- **Fully offline:** no package that fetches anything at runtime (no `google_fonts`, no network images, no analytics). Fonts and icons are bundled.
- **Dependencies of `taketray_ui`:** `flutter` and `material_symbols_icons` only. Dev dependencies: `flutter_test`, `alchemist`, `very_good_analysis`. It must never import from `app/`, Riverpod, go_router or l10n.
- **No copy in the package:** components take every user-facing string, including semantics labels, as a parameter. The app passes `AppLocalizations` strings; Widgetbook and tests pass English literals.
- **Style rule:**
  - `tool/check_styles` runs over `app/lib/features` **and** `packages/taketray_ui/lib/src/components`.
  - Non-token numbers a component needs (for example the nav pill's 6 dp padding) live as named `static const double` fields in `packages/taketray_ui/lib/src/theme/tt_metrics.dart`, each with a comment naming its CSS source.
  - Colours, text styles and durations used by components come from `TtThemeData`.
- **Icons:** `material_symbols_icons`, **Rounded** style (`Symbols.<name>`). Selected/"fill" icons use `fill: 1`. Icon names come from the prototype's `icon('<name>')` calls.
- **Font:** family `PlusJakartaSans`, declared in `packages/taketray_ui/pubspec.yaml` and referenced with `package: 'taketray_ui'`. The weight is set on both `fontWeight` and `FontVariation('wght', w)`.
- **Lints:** `very_good_analysis` with zero issues in every member; `dart format` clean.
- **Goldens:** every component has a golden test of each listed state in light and dark at text scale 1.0 and 2.0 (spec §7 rule 2), plus a widget test of its behaviour and semantics. Never commit `test/failures/`.
- **Accessibility:**
  - touch targets of at least 48 dp
  - a required semantics label on every icon-only control
  - no meaning carried by colour alone
  - no overflow at 2.0× text
  - "remove animations" respected
- **Living docs:** any task that makes a meaningful decision adds an entry with the next free `D-xx` to `docs/decisions.md`. Any task that adds or changes a flow updates `docs/flow.md`. Both go in the same commit as the code; reviewers reject a task that skips them.
- **Models:** Task 2 (theme architecture) and the phase review are critical, so they run on Opus when Opus is available and fall back to Sonnet otherwise; record the choice in the ledger. All other tasks run on Sonnet.
- **Git:** local only, on branch `phase-1-design-system`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Long text at 2× scale** (a 40-character reel name, a 60-character reference label, long button labels) → text ends in an ellipsis or clamps to its line count, and nothing overflows. Every component with text has a "long text" golden scenario. An overflow fails the test, because Flutter reports it as an error.
2. **A thumbnail that fails to load** (clip deleted after the query, corrupt file) → the tile, card or chip shows the neutral placeholder and nothing throws. Tests use the `brokenImage` fixture in Tasks 6, 7 and 8.
3. **Count extremes:**
   - the nav badge hides at 0 and shows "99+" above 99
   - the "in N reels" mark shows only at 2 or more
   - the references badge hides at 0
   - the segment bar collapses to three segments above 40 clips

   Tests in Tasks 4, 6, 7, 8 and 11.
4. **Accessibility checks:** each component's main state passes `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`, in light and dark (`expectTtAccessible`, Task 2). Every component task uses it.
5. **Reduced motion** (Android "Remove animations") → `context.tt.motion` returns zero durations, `TtRecDot` stops pulsing and the nav pill switches without animating. Tests in Tasks 2, 4 and 11.

---

## File structure

```
packages/taketray_ui/
  pubspec.yaml                      (resolution: workspace; fonts; deps per Global Constraints)
  analysis_options.yaml             (very_good_analysis)
  fonts/PlusJakartaSans-Variable.ttf, fonts/OFL.txt   (moved from app/assets/fonts)
  lib/taketray_ui.dart              (barrel: exports theme + components + Symbols re-export)
  lib/src/tokens/tokens.g.dart      (GENERATED by build_tokens.py)
  lib/src/theme/
    tt_colors.dart  tt_text.dart  tt_spacing.dart  tt_radii.dart  tt_motion.dart  tt_sizes.dart
    tt_theme_data.dart              (TtThemeData ThemeExtension)
    take_tray_theme.dart            (TakeTrayTheme.light/dark/video → ThemeData)
    tt_context.dart                 (BuildContext.tt / .scheme)
    tt_metrics.dart                 (named component dimensions, CSS-sourced)
  lib/src/components/<one file per family>.dart
  test/flutter_test_config.dart     (alchemist config)
  test/support/{pump.dart, golden.dart, a11y.dart, fixtures.dart}
  test/fixtures/thumbs/*.jpg        (6 images from the old sample set)
  test/theme/*_test.dart  test/components/*_test.dart  test/components/goldens/{ci,macos}/*.png
widgetbook/
  pubspec.yaml  analysis_options.yaml  android/ (applicationId app.taketray.widgetbook)
  assets/thumbs/*.jpg               (12 images from the old sample set)
  lib/main.dart  lib/catalog.dart  lib/components/<same file names as the package>.dart
  test/catalog_coverage_test.dart
```

---

### Task 1: Check tooling, covering every workspace member, plus the style-rule gaps

**Files:**
- Modify: `tool/lib/src/style_rules.dart`, `tool/test/style_rules_test.dart`, `tool/check`, `docs/flow.md` ("Local checks"), `docs/decisions.md`

**Interfaces:**
- Consumes: `findStyleViolations(String source, {required String path})` (phase 0).
- Produces: `tool/check` with `FLUTTER_MEMBERS=(app packages/taketray_ui widgetbook)` and `DART_MEMBERS=(tool)`. Members that don't exist yet are skipped with a printed note. Later tasks only create the folders.

- [ ] **Step 1: Write failing tests** in `tool/test/style_rules_test.dart`:
  - `BorderRadiusDirectional.circular(12)` gives one `raw-radius` violation.
  - `SizedBox.square(dimension: 24)` gives one `raw-size` violation.
  - `Duration(minutes: 1)`, `Duration(hours: 2)` and `Duration(microseconds: 5)` each give one `raw-duration` violation.
  - `BorderRadiusDirectional.circular(radii.m)` and `SizedBox.square(dimension: sizes.icon)` give none.
- [ ] **Step 2:** Run `(cd tool && ../tool/dart test test/style_rules_test.dart)`. Expected: the 5 new cases FAIL.
- [ ] **Step 3:** Extend the `raw-radius`, `raw-size` and `raw-duration` regexes in `style_rules.dart`, keeping the existing argument-position literal (`_lit`) logic.
- [ ] **Step 4:** Run the same test. Expected: all pass (23 existing + new).
- [ ] **Step 5:** Rewrite the member steps of `tool/check`:
  1. A guard reads the `workspace:` list in the root `pubspec.yaml`. If any entry is in neither `FLUTTER_MEMBERS` nor `DART_MEMBERS`, it fails with `workspace member <x> is not covered by tool/check`.
  2. Format runs over `lib`, `test`, `patrol_test` (where present) of every existing member, plus `tool`.
  3. `flutter analyze` runs in each existing Flutter member, and `dart analyze --fatal-infos` in each Dart member.
  4. Style check over `app/lib/features` and `packages/taketray_ui/lib/src/components`. A missing directory is clean, as before.
  5. Tests run in every existing member. A member without a `test/` folder fails, as `app` does today.
- [ ] **Step 6:** Run `tool/check`. Expected: `ALL CHECKS PASSED`, with notes that `packages/taketray_ui` and `widgetbook` are not present yet.
- [ ] **Step 7:** Temporarily add `- fake` to the root `workspace:` list and run `tool/check`. Expected: it fails with `workspace member fake is not covered by tool/check`. Revert.
- [ ] **Step 8:** Docs and commit:
  - Update `docs/flow.md` "Local checks" to the new steps.
  - Add a decision entry for "tool/check covers every workspace member".
  - Commit `build(check): cover every workspace member; close style-rule gaps`.

### Task 2: `taketray_ui` package, generated tokens, theme, golden harness (critical)

**Files:**
- Create: `packages/taketray_ui/` (pubspec, analysis_options, `lib/taketray_ui.dart`, `lib/src/theme/*`, `test/flutter_test_config.dart`, `test/support/*`, `test/fixtures/thumbs/`, `test/theme/*`)
- Move (`git mv`):
  - `app/assets/fonts/*` → `packages/taketray_ui/fonts/`
  - `app/assets/sample` → `reference/prototype-app/assets/sample`
- Copy: 6 thumbs (`c1`–`c6.jpg`) from the moved sample folder into `packages/taketray_ui/test/fixtures/thumbs/`
- Modify:
  - `design/tools/build_tokens.py`
  - `design/README.md`
  - root `pubspec.yaml` (add `packages/taketray_ui` to `workspace:`)
  - `app/pubspec.yaml`: drop `assets:`, `fonts:` and `cupertino_icons`; add `taketray_ui: {path: ../packages/taketray_ui}`
  - `docs/decisions.md`, `docs/flow.md`
- Delete: `design/handoff/flutter/` (its only output moves into the package)

**Interfaces:**
- Produces (exported from `package:taketray_ui/taketray_ui.dart`):
  - `abstract final class TakeTrayTheme { static ThemeData light(); static ThemeData dark(); static ThemeData video(); }`
    - `video()` is `dark()` with `scaffoldBackgroundColor` and `colorScheme.surface` set to `TtColors.videoBackground` (black).
  - `class TtThemeData extends ThemeExtension<TtThemeData>`, with fields `colors` (TtColors), `text` (TtTextStyles), `spacing` (TtSpacing), `radii` (TtRadii), `motion` (TtMotion), `sizes` (TtSizes), plus `copyWith` and `lerp`.
  - `extension TtBuildContext on BuildContext`:
    - `TtThemeData get tt`: the theme's `TtThemeData`, with `motion` replaced by `TtMotion.reduced` when `MediaQuery.maybeDisableAnimationsOf(this) == true`.
    - `ColorScheme get scheme`.
  - `TtSpacing`: `none 0, xxs 4, xs 8, s 12, m 16, l 20, xl 24, xxl 32, x3l 40, x4l 48, x5l 64, gutter 16, gridGap 4` (doubles).
  - `TtRadii`: `xs 4, s 8, m 12, l 16, xl 20, xxl 28, full 999` (doubles; component-specific radii live in `tt_metrics.dart`).
  - `TtMotion`:
    - durations `short1`…`long2` (`Duration`) and curves `standard`, `standardDecelerate`, `standardAccelerate`, `emphasizedDecelerate`, `emphasizedAccelerate` (`Curve`), all from tokens
    - `static const TtMotion standardSet` (the token values) and `static const TtMotion reduced` (all `Duration.zero`, same curves)
  - `TtSizes`: `touchTarget 48, iconSmall 18, icon 24, iconLarge 32, topAppBar 64, reelChip 56, clipTileAspect 0.75, screenGutter 16, designWidth 360`.
  - `TtColors` (all `Color`):
    - status colours: `waiting`, `onWaiting`, `waitingContainer`, `onWaitingContainer` (= the scheme's tertiary roles: the marigold "clips waiting")
    - `record`, `onRecord`, `recordContainer`, `onRecordContainer`
    - `success`, `onSuccess`, `successContainer`, `onSuccessContainer`
    - glass: `hairline` (onSurface at 9 %), `glass` (surfaceContainerHigh at 78 %)
    - on media: `glassOnMedia` (`#940E0C14`), `onMedia` (white), `onMediaVariant` (white at 82 %), `mediaScrimEnd` (black at 80 %), `missingOnMedia` (`#FFB4AB`), `recordOnMedia` / `readyOnMedia` / `publishedOnMedia` (the dark-theme record colour, dark primary and dark success)
    - video: `videoBackground`, `videoScrimTop`, `videoScrimBottom`, `onVideo`, `onVideoVariant` (from `videoSurface` tokens)
  - `TtTextStyles`:
    - `material` (the `TextTheme`, token type scale with colours applied)
    - `pageTitle` 34/40 w800 −1.2; `detailTitle` 30/36 w800 −1.0; `screenTitle` 20/26 w800 −0.4; `dialogTitle` 22/28 w800 −0.4; `shootTitle` 19/24 w800 −0.3; `cardTitle` 15/19 w700 −0.1; `groupLabel` 12/16 w700 +0.8; `navLabel` 11.5/14 w600 +0.2 (from `tt-style.css`)
    - `TextStyle numeric(TextStyle s)`, which adds tabular figures
  - Test support in `packages/taketray_ui/test/support/` (test-only, not exported):
    - `Widget ttTestApp(Widget child, {Brightness brightness = Brightness.light, double textScale = 1.0, bool disableAnimations = false})`
    - `class TtScenario { const TtScenario(this.name, this.child, {this.width}); }`
    - `void ttGoldenTest(String description, {required String fileName, required List<TtScenario> scenarios, double width = 360})` writes `goldens/<fileName>_light.png` and `_dark.png`, each a `GoldenTestGroup` of every scenario at text scale 1.0 and 2.0 on that theme's surface
    - `Future<void> expectTtAccessible(WidgetTester tester)` checks the three guidelines named in Review Focus 4
    - `ImageProvider fixtureThumb(int n)` (n from 1 to 6, a `MemoryImage` of the fixture bytes)
    - `ImageProvider get brokenImage` (bytes that fail to decode)

- [ ] **Step 1: Generator.** Change `write_dart()` in `build_tokens.py`:
  - It writes only `packages/taketray_ui/lib/src/tokens/tokens.g.dart`, with only the shipped brand: `const ttLightScheme`, `const ttDarkScheme` (`ColorScheme`), and `abstract final class` groups `TtColorTokens` (extended light/dark + video surface), `TtTypeTokens` (one `TextStyle` per scale entry, `fontFamily: 'PlusJakartaSans'`, `package: 'taketray_ui'`, weight + `FontVariation`), `TtSpaceTokens`, `TtRadiusTokens`, `TtMotionTokens` (`Duration`s and `Cubic`s) and `TtSizeTokens`.
  - Drop `BrandOption` and `brandSchemes` from the Dart output. The CSS and JSON keep every option for the hub.
  - Add a `--check` flag: generate every output in memory, compare with disk, print each stale path and exit 1 if any differ; write nothing. Without the flag, behaviour is unchanged.
  - Update the docstring and `design/README.md`.
- [ ] **Step 2:** Run `python3 design/tools/build_tokens.py`, then `python3 design/tools/build_tokens.py --check`. Expected: the first writes the package file; the second prints nothing and exits 0. Then hand-edit one value in `tokens.g.dart`, run `--check` (expected: it names the file and exits 1) and revert.
- [ ] **Step 3: Package scaffold.**
  - Create the pubspec (`name: taketray_ui`, `publish_to: none`, `resolution: workspace`, SDK `^3.13.5`, `flutter: 3.47.7`, `fonts:` family `PlusJakartaSans` → `fonts/PlusJakartaSans-Variable.ttf`).
  - Pin `material_symbols_icons`, `alchemist` and `very_good_analysis` to the newest versions that resolve with Flutter 3.47.7, and record them in the decision entry.
  - Add the workspace entry. Do the `git mv`s and the app pubspec edits listed under Files.
  - Add a `tool/check` step `python3 design/tools/build_tokens.py --check` right after `pub get`.
- [ ] **Step 4: Write failing theme tests** in `test/theme/take_tray_theme_test.dart`:
  - `light().colorScheme.primary == ttLightScheme.primary`.
  - `dark()`'s OLED override: `surface == ttDarkScheme.surfaceContainerLowest`, `surfaceContainerLowest == Color(0xFF000000)`, `surfaceContainer == ttDarkScheme.surfaceContainerLow`, `surfaceContainerHigh == ttDarkScheme.surfaceContainer`, `surfaceContainerHighest == ttDarkScheme.surfaceContainerHigh` (from `tt-style.css` §1).
  - `video().scaffoldBackgroundColor == Color(0xFF000000)`.
  - Both light and dark carry a `TtThemeData`; `textTheme.bodyMedium!.fontFamily == 'packages/taketray_ui/PlusJakartaSans'`.
  - `TtThemeData.lerp` at t = 0 and t = 1 returns the endpoints' colours.
  - `context.tt.motion.medium2 == Duration(milliseconds: 300)` normally and `Duration.zero` under `ttTestApp(disableAnimations: true)` (Review Focus 5).
  - `context.tt.colors.waiting == context.scheme.tertiary`.
- [ ] **Step 5:** Run `(cd packages/taketray_ui && ../../tool/flutter test test/theme)`. Expected: FAIL (`TakeTrayTheme` not defined).
- [ ] **Step 6: Implement** the theme files listed in Interfaces.
  - `TakeTrayTheme` also sets Material component themes so stock widgets look TakeTray. Values come from `tt-style.css`:
    - filled, tonal, outlined and text buttons are stadium-shaped with `labelLarge`
    - snackbars float, on `inverseSurface` at 94 % opacity, radius 18
    - bottom sheets are transparent with no drag handle
    - dialogs use radius 32
    - `scrolledUnderElevation: 0`
    - `splashFactory: InkSparkle.splashFactory`
  - Component-specific numbers go in `tt_metrics.dart`.
- [ ] **Step 7:** Run the theme tests. Expected: PASS.
- [ ] **Step 8: Golden harness.**
  - In `test/flutter_test_config.dart`:
    - CI goldens are always on.
    - Platform goldens are on for macOS only, and off when the `CI` environment variable is set.
    - Fonts load through alchemist, so the macOS goldens show real Plus Jakarta Sans and Material Symbols, not Ahem boxes.
  - Write `test/support/*` per Interfaces.
  - Add `test/theme/theme_golden_test.dart`, using `ttGoldenTest(fileName: 'theme_swatches')`, with scenarios showing the type scale (every `TtTextStyles` style) and the colour roles as labelled swatches.
- [ ] **Step 9:** Run `(cd packages/taketray_ui && ../../tool/flutter test --update-goldens test/theme && ../../tool/flutter test test/theme)`. Expected: goldens are written under `test/theme/goldens/{ci,macos}/` and the second run passes. **Open the macOS PNGs** (Read tool) and confirm the real font renders and the dark swatches are OLED-dark.
- [ ] **Step 10:** Run `tool/check`. Expected: `ALL CHECKS PASSED`; the app still builds with no assets section.
- [ ] **Step 11:** Docs and commit:
  - Decision entries for:
    - the package plus generated tokens (shipped brand only, `--check` freshness)
    - the theme architecture (one `TtThemeData` extension, `context.tt`, reduced-motion resolution, OLED override in theme code)
    - no copy in the package
    - `tt_metrics.dart` and the style rule on components
    - goldens (alchemist, CI plus macOS platform goldens, light/dark × 1.0/2.0 in one image per theme)
    - the font and icon packaging
    - the sample assets leaving the app
  - Flow: add "Token build" (`build_tokens.py` › `write_dart` → `tokens.g.dart` → `TakeTrayTheme` → `TtThemeData` → `context.tt`) and the `--check` step to "Local checks".
  - Commit `feat(ui): taketray_ui package with generated tokens and TakeTray theme`.

### Task 3: Widgetbook app and catalogue coverage test

**Files:**
- Create: `widgetbook/` (pubspec, analysis_options, `android/` via `flutter create`, `assets/thumbs/` with 12 sample thumbs, `lib/main.dart`, `lib/catalog.dart`, `lib/components/theme.dart`, `test/catalog_coverage_test.dart`)
- Modify: root `pubspec.yaml` (`workspace:` adds `widgetbook`), `docs/dev-setup.md`, `docs/flow.md`, `docs/decisions.md`

**Interfaces:**
- Consumes: `TakeTrayTheme`, `TtThemeData` (Task 2).
- Produces:
  - `widgetbook/lib/catalog.dart › List<WidgetbookNode> ttCatalog`, the folder tree that later tasks append one component file to
  - `ImageProvider wbThumb(int n)` (n from 1 to 12, an `AssetImage`)
  - convention: package file `src/components/<name>.dart` ↔ `widgetbook/lib/components/<name>.dart`

- [ ] **Step 1:** In `widgetbook/`, run `../tool/flutter create --platforms=android --org app.taketray --project-name taketray_widgetbook .`, set `applicationId "app.taketray.widgetbook"` and label "TakeTray UI", and delete the generated counter app and test. Use a pubspec with `resolution: workspace`, depending on `taketray_ui` and `widgetbook` (newest version that resolves; record it).
- [ ] **Step 2: Write the failing test** `test/catalog_coverage_test.dart`. For every `*.dart` file directly in `../packages/taketray_ui/lib/src/components/`, `lib/components/<same name>.dart` must exist and `lib/catalog.dart` must import it. The test fails listing the missing names, and passes trivially while the folder is empty.
- [ ] **Step 3: `lib/main.dart`.** It runs `Widgetbook.material` with `directories: ttCatalog` and these add-ons:
  - Material theme: "TakeTray light", "TakeTray dark" and "Video", from `TakeTrayTheme`
  - text scale: 1.0, 1.5, 2.0
  - a 360 × 780 dp phone viewport

  `lib/components/theme.dart` shows the colour roles and text styles, mirroring the Task 2 swatch golden.
- [ ] **Step 4:** Run `(cd widgetbook && ../tool/flutter test)` and `(cd widgetbook && ../tool/flutter build apk --debug)`. Expected: the test passes and the APK builds.
- [ ] **Step 5:** Run `tool/check`. Expected: `ALL CHECKS PASSED`, with `widgetbook` now analysed and tested.
- [ ] **Step 6:** Docs and commit:
  - `docs/dev-setup.md` gets "Run the catalogue on the phone: `cd widgetbook && ../tool/flutter run -d <device>`".
  - Decision entry: a hand-written catalogue (no codegen), the coverage test, its own application ID.
  - Flow: "Catalogue coverage".
  - Commit `feat(widgetbook): component catalogue app`.

---

## Component task recipe (Tasks 4–10)

Each component task follows the same cycle. The task lists only what differs: the API, the states and the prototype sources.

1. **Behaviour and semantics tests first:** `packages/taketray_ui/test/components/<file>_test.dart`.
   - Taps call the callbacks, and disabled controls don't.
   - The semantics label equals the passed string.
   - Selected/checked semantics are set where listed.
   - `expectTtAccessible` passes on the main state in light and dark.
   - Plus the task's own assertions.
2. Run them. Expected: FAIL (types not defined).
3. Implement in `packages/taketray_ui/lib/src/components/<file>.dart`.
   - Export from the barrel.
   - Use only the `context.tt.*` and `context.scheme` values and the `tt_metrics.dart` constants. New metrics get a CSS-source comment.
4. **Goldens:** `ttGoldenTest(fileName: '<component>')` with one `TtScenario` per listed state, including a long-text scenario wherever the component shows text.
   - Run `--update-goldens`, then run the tests again. Expected: PASS.
   - **Open the macOS light and dark PNGs** and compare them with the same state in `design/prototype/index.html` (or the CSS values). Fix differences before going on.
5. **Widgetbook:** `widgetbook/lib/components/<file>.dart`.
   - One `WidgetbookComponent` per component, with knobs for every state parameter (booleans, enums, text, counts).
   - Fixture images via `wbThumb`.
   - Register it in `catalog.dart`.
6. Run `tool/check`. Expected: `ALL CHECKS PASSED`, which includes the style rule on components and the catalogue coverage test.
7. Docs and commit. Add a decision entry when the task chose something not fixed here; flows aren't affected by pure widgets. Commit `feat(ui): <family>`.

### Task 4: Core controls (`buttons.dart`, `glass.dart`, `badges.dart`, `rec_dot.dart`)

**API:**
- `enum TtButtonKind { filled, tonal, outlined, text, ghost, danger, attention }`, `enum TtButtonSize { small, medium, large }` (min heights 36/44/56; the tap target is always ≥ 48).
- `TtButton({required String label, required VoidCallback? onPressed, TtButtonKind kind = TtButtonKind.filled, TtButtonSize size = TtButtonSize.medium, IconData? icon, String? semanticLabel, bool expand = false, Key? key})`: `null` onPressed means disabled.
- `enum TtIconButtonStyle { plain, circle, onVideo }`; `TtIconButton({required IconData icon, required String semanticLabel, required VoidCallback? onPressed, TtIconButtonStyle style = TtIconButtonStyle.plain, bool filled = false, bool? pressed, Key? key})`. `pressed` non-null means toggle semantics.
- `TtFab({required String label, required IconData icon, required VoidCallback onPressed, Key? key})`: extended, 52 dp, a stadium in primary with the primary-tinted shadow.
- `TtGlass({required Widget child, required double radius, Color? tint, double blur = TtMetrics.glassBlur, bool shadow = true, Key? key})`.
- `TtGlassPill({required IconData icon, Color? iconColor, String? text, Key? key})`: dark glass on media.
- `TtCountBadge({required int count, Key? key})`: `SizedBox.shrink` at ≤ 0, "99+" above 99, waiting colours.
- `TtRecDot({bool live = true, Key? key})`: a pulsing record dot; static when `context.tt.motion == TtMotion.reduced`.

**States for goldens:**
- every button kind × enabled/disabled, with and without an icon, all 3 sizes, and a long label
- icon button: all 3 styles, filled/unfilled, pressed true/false
- FAB
- glass panel and glass pill on a fixture image
- badge at 1, 9, 99 and 100
- rec dot

**Extra tests:**
- the badge shows `99+` at 100 and nothing at 0
- the small button's tap target is 48 × 48 or more
- `TtRecDot` has no running ticker under `disableAnimations: true` (`tester.hasRunningAnimations == false`)

**Sources:** `.btn`, `.ib`, `.fab`, `.badge`, `.recdot`, `.pill` in proto.css/tt-style.css; `h.btn`, `h.ib` in ui.js; `Glass`, `GlassPill` in reference `tt.dart`.

### Task 5: Selection and input (`selection.dart`, `pill_tabs.dart`, `text_field.dart`)

**API:**
- `TtSwitch({required bool value, required ValueChanged<bool>? onChanged, required String semanticLabel, bool inverted = false, Key? key})`: the TakeTray switch with a check icon in the thumb; `inverted` is the version used on the Shooting mode media card.
- `TtCheckMark({required bool checked, Key? key})` and `TtRadioMark({required bool selected, Key? key})`: visual-only marks (`.cbox`, `.radio`). The row that holds them owns the semantics.
- `TtPillTab<T>(T value, String label, {String? semanticLabel})`; `TtPillTabs<T>({required List<TtPillTab<T>> tabs, required T value, required ValueChanged<T> onChanged, Key? key})`: a horizontal scroller; the selected tab is `inverseSurface`.
- `TtSuggestionChip({required String label, required VoidCallback onPressed, Key? key})`: dashed outline (`.sugg .fchip`).
- `TtTextField({required String label, TextEditingController? controller, String? hint, String? helper, String? error, int? maxLength, bool multiline = false, bool autofocus = false, TextInputAction? textInputAction, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, Key? key})`:
  - `maxLength` shows an `n/max` counter and blocks further input
  - `error` replaces the helper with an error icon and text

**States for goldens:**
- switch off/on/disabled/inverted
- check mark and radio mark on/off
- pill tabs with the first and then a middle tab selected, and a long label
- suggestion chip
- text field: empty with a hint, filled, focused, with a counter at 40/40, with an error, multiline

**Extra tests:**
- `TtPillTabs` calls `onChanged` with the tapped value and marks only that tab `selected` in semantics
- `TtTextField` with `maxLength: 40` refuses a 41st character
- the counter text reads `40/40`

**Sources:** `.sw`, `.cbox`, `.radio`, `.fchip`, `.sugg`, `.tf` in the CSS; `h.sw`, `h.tf` in ui.js; `PillTabs` in reference `tt.dart`.

### Task 6: Clips and status (`status_pill.dart`, `clip_tile.dart`, `headers.dart`, `skeleton.dart`)

**API:**
- `enum TtStatusKind { collecting, ready, published }`.
- `TtStatusPill({required TtStatusKind kind, required String label, bool onMedia = false, bool large = false, VoidCallback? onPressed, String? semanticLabel, Key? key})`:
  - icons: `radio_button_checked`, `content_cut`, `check_circle` (filled)
  - `onPressed` adds the `arrow_drop_down` caret
  - on media it is a dark glass pill with the `*OnMedia` icon colour
- `TtClipMark({required IconData icon, required String label})`.
- `TtClipTile({required ImageProvider thumbnail, required String semanticLabel, String? timeText, String? durationText, int reelCount = 1, bool horizontal = false, bool? selected, TtClipMark? mark, String? vnLabel, bool enabled = true, VoidCallback? onTap, VoidCallback? onLongPress, Key? key})`, a 3:4 tile with radius 12:
  - the `layers` + count mark shows only when `reelCount >= 2`
  - the `crop_16_9` mark shows only when horizontal and `reelCount < 2`
  - `selected` non-null means selecting mode, with a check circle and `aria-pressed`-style semantics
  - `mark` hides the time and duration
  - an image error shows the neutral placeholder (`surfaceContainerHighest` + `movie` icon)
- `TtMissingClipTile({required String label, String? removeLabel, VoidCallback? onRemove, Key? key})`: grey tile with `videocam_off` and a small tonal Remove button.
- `TtClipTileSkeleton({Key? key})`.
- `TtSceneHeader({required String title, required String subtitle, required Widget action, Key? key})`.
- `TtDayHeader({required String title, String? trailing, Key? key})`.
- `TtSkeletonLine({double widthFactor = 0.4, Key? key})`.

**States for goldens:**
- status pill: 3 kinds × surface/media × normal/large/with caret
- clip tile:
  - default
  - in 3 reels
  - horizontal
  - selecting unselected and selected
  - with a mark ("Skipped")
  - in the VN folder
  - disabled
  - `brokenImage`
- missing tile with and without Remove
- skeleton tile and line
- scene header with a tonal "Tag scene" action and with a long title
- day header with and without trailing text

**Extra tests:**
- `brokenImage` renders without exceptions and shows the placeholder icon (Review Focus 2)
- `reelCount: 1` shows no layers mark and `reelCount: 2` shows "2"
- `horizontal: true, reelCount: 2` shows no `crop_16_9`
- long press calls `onLongPress`

**Sources:** `.pill`, `.tile` (`.miss`, `.sel`, `.multi`, `.hz`, `.mark`, `.vnmark`, `.skel`), `.sec-h`, `.day-h`, `.skel-line` in the CSS; `h.statusPill`, `h.tile`, `h.sceneHeader` in ui.js.

### Task 7: Cards (`reel_card.dart`, `reference_card.dart`, `shooting_mode_card.dart`, `stat_strip.dart`)

**API:**
- `TtReelCard({required String name, required String semanticLabel, required TtStatusKind status, required String statusLabel, required String meta, required String emptyLabel, ImageProvider? cover, String? missingText, String? vnLabel, int referenceCount = 0, String? referencesSemanticLabel, VoidCallback? onTap, VoidCallback? onReferencesTap, Key? key})`, a full-bleed 4:5 cover with radius 22:
  - a bottom gradient, with the name (2 lines max, `cardTitle`, `onMedia`) and meta over it
  - `cover == null` shows the empty art with `emptyLabel` and on-surface text
  - the references badge shows only when `referenceCount > 0`
  - an image error falls back to the empty art
- `TtReferenceCard({required String title, required String subtitle, required Widget sourceIcon, required String openLabel, required String openSemanticLabel, required VoidCallback onOpen, String? moreSemanticLabel, VoidCallback? onMore, Key? key})`: the more button shows only when `onMore` is not null.
- `TtAddReferenceTile({required String title, required String subtitle, required VoidCallback onPressed, Key? key})`.
- `TtShootingModeCard({required bool on, required String title, required String subtitle, required String switchSemanticLabel, required ValueChanged<bool> onChanged, ImageProvider? backdrop, String? cameraLabel, VoidCallback? onOpenCamera, Widget? referencesRow, Widget? toTagStrip, Key? key})`:
  - off: the hairline card with the `videocam` icon
  - on: black media hero with the backdrop at 62 % opacity, the gradient, `TtRecDot`, the inverted switch, and the white camera button (`.camb`)
- `TtCardRow({required IconData icon, required String title, String? subtitle, String? trailingText, required VoidCallback onPressed, String? semanticLabel, Key? key})`: the `.refrow`/`.strip` rows inside the on card.
- `TtStatStrip({required Widget leading, required String text, Widget? action, bool muted = false, Key? key})`.

**States for goldens:**
- reel card:
  - with a cover in each status
  - empty
  - with missing clips
  - Editing in VN
  - with 3 references
  - long name
  - `brokenImage`
- reference card with and without the more button, and a long title
- add-reference tile
- shooting card:
  - off
  - on with backdrop, references row and to-tag strip
  - on without backdrop
  - long subtitle
- stat strip live (rec dot) and muted

**Extra tests:**
- `referenceCount: 0` builds no badge
- the badge tap calls `onReferencesTap`, not `onTap`
- the switch in the card calls `onChanged(false)` when on
- `brokenImage` cover shows the empty art

**Sources:** `.rcard`, `.cover`, `.cap`, `.refbadge`, `.refcard`, `.ref-*`, `.ref-add`, `.shoot` (`.on`, `.ico`, `.txt`, `.camb`, `.refrow`, `.strip`), `.stat-strip` in the CSS; `h.reelCard` (ui.js), `h.refCard`, `h.refsSection` (refs.js), `shootingCard` (screens.js).

### Task 8: Tag player chrome and video (`video_surface.dart`, `player_chrome.dart`, `reel_chip.dart`, `tag_panel.dart`)

**API:**
- `TtVideoSurface({required Widget child, bool scrims = false, Key? key})`: applies `TakeTrayTheme.video()` to its subtree on a black background; `scrims` adds the top/bottom gradient scrims.
- `TtSegmentBar({required int total, required int current, required Set<int> done, Key? key})`:
  - one segment per clip when `total <= 40`
  - above 40, three flex segments (done = `current`, current = 1, rest = `total - current - 1`), as in screens.js line 234
- `TtPlayerHeader({required Widget leading, required String title, String? subtitle, Widget? trailing, Key? key})`: `title` is a live region (`liveRegion: true`).
- `enum TtArrowSide { previous, next }`; `TtStageArrow({required TtArrowSide side, required String semanticLabel, VoidCallback? onPressed, Key? key})`.
- `TtScrubBar({required double progress, required String positionText, required String durationText, bool large = false, String? hint, ValueChanged<double>? onSeek, Key? key})`: `progress` runs from 0.0 to 1.0 and is clamped; `onSeek` receives the fraction from a drag or tap.
- `enum TtReelChipState { idle, picked, done }`; `TtReelChip({required String name, required String countText, required String semanticLabel, ImageProvider? cover, TtReelChipState state = TtReelChipState.idle, bool multiSelect = false, VoidCallback? onTap, VoidCallback? onLongPress, Key? key})`:
  - `multiSelect` shows a `TtCheckMark` and checkbox semantics
  - `done` shows the check in place of the cover
  - an image error shows the `movie` icon
- `TtTagPanel({required String title, required List<Widget> chips, Widget? headerAction, Widget? footer, Key? key})`: a glass panel with radius 28 at the top and a 2-column chip grid.
- `TtSameAsPreviousButton({required String label, String? detail, required String semanticLabel, VoidCallback? onPressed, Key? key})`: two lines, with `repeat` and `detail` ellipsised.

**States for goldens** (all inside `TtVideoSurface`):
- segment bar at 5/12 and at 30/120
- header with close and mute
- arrows enabled and disabled
- scrub bar at 0 %, at 26 % large with hint, and with a long time
- reel chip:
  - idle with a cover
  - idle without a cover
  - picked in multi-select
  - done
  - long name
  - `brokenImage`
- tag panel with 5 chips plus a "Pick several" header action and a footer button
- same-as-previous enabled with 3 reel names and disabled

**Extra tests:**
- `TtSegmentBar(total: 120, …)` builds exactly 3 segments, and `total: 12` builds 12
- `TtScrubBar` with `progress: 1.4` paints at 100 % without throwing
- a drag on the scrub bar calls `onSeek` with a fraction between 0 and 1
- a multi-select chip reports `checked` in semantics

**Sources:** `.player`, `.pbar`, `.ptop`, `.stage`, `.arrow`, `.scrub`, `.qrow`, `.tagpanel`, `.ph-h`, `.chipgrid`, `.multi-foot`, `.rchip` in the CSS; the tag player route in screens.js (lines 230–272); `h.reelChip` in ui.js.

### Task 9: Overlays (`sheet.dart`, `dialog.dart`, `snack.dart`, `menu.dart`)

**API:**
- `TtSheet({required Widget child, String? title, Widget? footer, bool fullScreen = false, Key? key})`: inset 8 dp, radius 32, drag handle, `surfaceContainer`, hairline border; `fullScreen` has no inset and no radius.
- `Future<T?> showTtSheet<T>(BuildContext context, {required WidgetBuilder builder, bool fullScreen = false, bool isDismissible = true})`: a modal bottom sheet, transparent route background, the blurred `.scrim`, keyboard-safe.
- `TtDialogAction<T>(T value, String label, {bool destructive = false})`; `TtDialog<T>({required String title, String? body, Widget? content, required List<TtDialogAction<T>> actions, Key? key})`, with equal-width action buttons:
  - the last action is primary
  - a destructive last action uses the error colours
- `Future<T?> showTtDialog<T>(BuildContext context, {required String title, String? body, Widget? content, required List<TtDialogAction<T>> actions})`.
- `TtSnack({required String message, IconData? icon, String? actionLabel, VoidCallback? onAction, Key? key})`.
- `ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showTtSnack(BuildContext context, {required String message, IconData? icon, String? actionLabel, VoidCallback? onAction, Duration? duration})`: a floating snack bar with `TtSnack` content that hides the current one first. The duration defaults to the theme's.
- `TtMenuItem<T>(T value, String label, {IconData? icon, bool destructive = false})`; `TtMenuButton<T>({required List<TtMenuItem<T>> items, required ValueChanged<T> onSelected, required Widget Function(BuildContext context, VoidCallback open) builder, Key? key})`: built on `MenuAnchor`, with menu radius 20 and item radius 14.

**States for goldens:**
- sheet with title, list body and footer; full-screen sheet
- dialog with 2 actions, a destructive one, 1 action, and a long title and body
- snack: plain, with icon, with Undo, long message
- menu open with 3 items (one destructive)

**Extra tests:**
- `showTtDialog` returns the tapped action's value and returns `null` when dismissed by tapping the scrim
- `showTtSnack` twice in a row shows only the second message
- tapping Undo calls `onAction` once
- `TtMenuButton` calls `onSelected` with the item value and closes

**Sources:** `.sheet`, `.sh-foot`, `.scrim`, `.dlg`, `.snack`, `.menu`, `.mi` in the CSS; `h.snack` in ui.js; `FloatingSheet` in reference `tt.dart`.

### Task 10: Lists and feedback (`grouped_rows.dart`, `banners.dart`, `progress.dart`, `empty_state.dart`)

**API:**
- `TtGroupedRows({required List<Widget> children, Key? key})`: outer corners 22, inner corners 6, 2 dp gaps, `surfaceContainerLow`. `TtGroupLabel(String text, {Key? key})` is rendered in upper case with `groupLabel`.
- `TtRowIcon({required IconData icon, bool boxed = true, Key? key})`.
- `TtListRow({required String title, String? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap, String? semanticLabel, Key? key})`.
- `enum TtBannerKind { warning, info, attention, vn }`; `TtBanner({required TtBannerKind kind, required IconData icon, required String title, String? body, Widget? action, VoidCallback? onTap, Key? key})`: `warning` sets `liveRegion` (it is `role=alert` in the prototype).
- `TtCallout({required IconData icon, String? title, String? body, InlineSpan? richBody, bool warning = false, Widget? action, Key? key})`: exactly one of `body` or `richBody` (an assert).
- `TtInfoBar({required IconData icon, required String text, Key? key})`.
- `TtProgressBar({double? value, String? label, String? semanticLabel, Key? key})`: `null` means indeterminate.
- `enum TtIllustrationKind { caught, shootOff, noReels, emptyReel, folder, permission, skipped }`; `TtIllustration(TtIllustrationKind kind, {Key? key})`: a `CustomPainter` at 168 × 140 with the geometry of `h.illus` in ui.js; colours from scheme roles and `TtColors`.
- `TtEmptyState({required TtIllustrationKind illustration, required String title, required String body, List<Widget> actions = const [], Key? key})`.

**States for goldens:**
- grouped rows of 1, 2 and 4 rows (switch, chevron and value trailing), with label
- every banner kind with and without an action
- callout: normal, warning, rich body
- info bar
- progress at 0 %, 40 %, 100 %, indeterminate (frozen frame), with label
- each of the 7 illustrations
- empty state with 0, 1 and 2 actions and long body

**Extra tests:**
- a single-row group has radius 22 on all four corners
- `TtCallout(body: 'a', richBody: …)` throws an `AssertionError`
- `TtProgressBar(value: 0.4)` exposes `value: 40%` in semantics

**Sources:** `.li`, `.li-h`, `.lead.box`, `.banner` (`.warn`, `.info`, `.attn`, `.vn`), `.callout`, `.infobar`, `.prog`, `.empty`, `.ill` in the CSS; `h.empty`, `h.illus` in ui.js; `GroupedRows`, `GroupLabel` in reference `tt.dart`.

### Task 11: App bar, floating nav pill, and the app adopts the theme

**Files:**
- Create:
  - `packages/taketray_ui/lib/src/components/app_bar.dart`
  - `packages/taketray_ui/lib/src/components/nav_pill.dart`
  - their tests and goldens
  - their Widgetbook files
- Modify:
  - `app/lib/app.dart`
  - `app/lib/features/shell/views/app_shell.dart`
  - the three placeholder screens
  - `app/test/app_test.dart`
  - `app/patrol_test/app_shell_test.dart`
  - `docs/flow.md` ("App start", "Tab navigation", "On-device test")
  - `docs/decisions.md` (D-29 is marked **Superseded** and a new entry is added)

**API:**
- `TtAppBar({required String title, String? subtitle, Widget? leading, List<Widget> actions = const [], bool large = false, bool selection = false, Key? key}) implements PreferredSizeWidget`:
  - large: 80 dp with `pageTitle`
  - default: 64 dp with `screenTitle` and an optional subtitle
  - selection: `secondaryContainer` background
  - plain icon actions sit on glass circles (`.appbar .ib::before`)
- `TtNavItem({required IconData icon, required String label, int badgeCount = 0, String? badgeSemanticLabel})`.
- `TtNavPill({required List<TtNavItem> items, required int currentIndex, required ValueChanged<int> onSelected, Key? key})`:
  - glass pill, insets 20/20/10 above the safe area, 64 dp tall, radius 32, 6 dp padding, 4 dp gaps
  - the selected item has a `primaryContainer` fill (radius 26) and a filled icon
  - `TtCountBadge` sits on the icon
  - each item's semantics are `label` or `badgeSemanticLabel`, plus `selected`
  - the selection change animates with `motion.short4`
- `static double TtNavPill.reservedHeight(BuildContext context)`: the pill height + bottom inset + safe area. Later scrollable tab screens add this as bottom padding.

**Steps:**
- [ ] **Step 1:** Recipe steps 1–6 for both components.
  - Golden states for the app bar: large, default with back, with subtitle, selection mode with 2 actions, long title.
  - Golden states for the nav pill: each selected index, badge 0/7/120, long label.
  - Extra tests:
    - the nav pill tap calls `onSelected(i)`
    - the badge semantics label is used when `badgeCount > 0`
    - under `disableAnimations: true` a selection change finishes in one frame (Review Focus 5)
    - `reservedHeight` with `MediaQuery(padding: bottom 24)` returns `64 + 10 + 24`
- [ ] **Step 2: Write failing app tests** in `app/test/app_test.dart`:
  - the app shows a `TtNavPill` with labels Reels, To tag and Settings, and no `NavigationBar`
  - `Theme.of(context).extension<TtThemeData>()` is not null
  - the Reels placeholder shows a `TtAppBar` titled "Reels"
  - the existing tab-switching and back-to-Reels tests still pass, using the pill
- [ ] **Step 3: Implement.**
  - `app.dart` uses `TakeTrayTheme.light()` and `dark()` with `ThemeMode.system`.
  - `AppShell` uses `Scaffold(extendBody: true, bottomNavigationBar: TtNavPill(...))` with icons `Symbols.video_library`, `Symbols.sell` and `Symbols.settings`.
    - The To tag badge count is `0` for now: a constant in the shell with a comment pointing to phase 5.
    - `badgeSemanticLabel` comes from the existing `toTagBadgeSemantics` ARB key.
  - Placeholder screens use `TtAppBar(large: true, title: …)`.
- [ ] **Step 4:** Run `(cd app && ../tool/flutter test)`. Expected: PASS.
- [ ] **Step 5:** Patrol: change the finders in `app_shell_test.dart` from `NavigationBar` to `TtNavPill` (still by label text).
- [ ] **Step 6:** Run `tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 7:** Docs and commit:
  - Flows: "App start" (theme), "Tab navigation" (`TtNavPill.onSelected` → `goBranch`), "On-device test" (finders).
  - Decision: the nav pill replaces the placeholder (supersedes D-29); `reservedHeight` is the bottom-padding contract.
  - Commit `feat(shell): TakeTray theme and floating nav pill in the app`.

### Task 12: Phase verification on the S24 and handover

**Files:** `docs/dev-setup.md` (owner check list for phase 1), `docs/decisions.md` (only if something changes)

- [ ] **Step 1:** Run `tool/check`. Expected: `ALL CHECKS PASSED`.
- [ ] **Step 2:** Run `tool/check_release_permissions`. Expected: `RELEASE PERMISSIONS OK`.
- [ ] **Step 3:** Run `unzip -l app/build/app/outputs/flutter-apk/app-release.apk | grep -c "assets/sample"`. Expected: `0`. Also confirm `PlusJakartaSans` and `MaterialSymbolsRounded` are in the APK's `flutter_assets`, under `packages/`.
- [ ] **Step 4 (needs the owner's phone connected; ask first):**
  - Run `tool/patrol test -t patrol_test/app_shell_test.dart -d RZCY80PHWCZ`. Expected: pass.
  - Install the release app: `tool/adb install -r` with the release APK.
  - Install the catalogue: `cd widgetbook && ../tool/flutter build apk --release && ../tool/adb install -r build/app/outputs/flutter-apk/app-release.apk`. The Widgetbook release APK keeps its debug signing; that is fine for a side-loaded catalogue.
- [ ] **Step 5:** Write the owner checklist in `docs/dev-setup.md` under "Phase 1 check":
  1. the app opens to Reels with the floating pill
  2. tabs switch, and back returns to Reels
  3. the phone's dark mode switch flips the theme
  4. "TakeTray UI" opens and every component is listed
  5. switching light/dark/video and text scale 2.0 in the catalogue shows no broken layouts
  6. buttons, cards, the shooting card and the tag player chrome look like the prototype
- [ ] **Step 6:** Commit `docs: phase 1 owner check`. Then the controller runs the whole-branch review (Opus when available) and superpowers:finishing-a-development-branch.
