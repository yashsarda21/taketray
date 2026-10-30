# TakeTray design (Android, version 1)

The complete version 1 UI for **TakeTray** (formerly Reel Helper), built from [`docs/design-prompt.md`](../docs/design-prompt.md) and [`docs/design-prompt-addon-1.md`](../docs/design-prompt-addon-1.md) (rename and reference reels).

Open **`prototype/index.html`** in any browser (it needs an internet connection for the fonts and icons). From the left menu you get:

- **Interactive prototype**: tag a day's clips, send a reel to VN (including Done editing), first launch, **save a reference from Instagram**, and saving a reference on first launch. You can also simulate shooting clips, the notification shade, 9 pm, "3 days later" and "14 days later", and switch the Android version, video access, theme, reduced motion, the welcome design and what is shared from Instagram.
- **Screens 1–40**: every screen and state from both briefs and the Add earlier videos change (38–40), at 360 dp, light and dark, with notes and interactions. "Try it in the prototype" opens any state live. Screen 2 holds the **three welcome options** to choose from.
- **Design system, Navigation map, Name and icon, Motion, Accessibility, Developer handoff, Decisions and questions.**

## Folder

| Path | What it is |
|---|---|
| `tokens/taketray.tokens.json` | Design tokens: Material 3 colour roles (light, dark), extended colours (REC red, success green), tonal palettes, type scale, shape, spacing, elevation, motion, sizes, and a contrast report. |
| `tokens/colour-options/` | The five brand colour options (violet, teal, cobalt, graphite, tangerine) as light and dark colour roles, for review. Switch between them in the hub with the swatches in the sidebar. |
| `handoff/compose/` | Generated Compose theme: `Color.kt`, `Type.kt`, `Shape.kt`, `Motion.kt`, `Theme.kt` (`TakeTrayTheme`, package `app.taketray.ui.theme`; change it to yours). |
| `handoff/icons/<concept>/` | App icon sets for the three concepts (`tray` is recommended): adaptive background and foreground, monochrome themed icon, `mipmap-anydpi-v26/ic_launcher.xml`, notification icon. VectorDrawable XML plus SVG. |
| `prototype/` | The hub and prototype. `assets/screens.js` renders every screen, `assets/refs.js` the reference-reels feature, `assets/earlier.js` Add earlier videos and the date range picker, `assets/welcome.js` the welcome options; `assets/states.js` lists every state; `assets/app.js` runs the prototype. |
| `tools/build_tokens.py` | Regenerates the tokens JSON, the colour options, `prototype/assets/tokens.css`, `tokens.js`, the Kotlin files and the Flutter tokens (`packages/taketray_ui/lib/src/tokens/tokens.g.dart`, shipped brand only) from four brand seeds. |
| `tools/build_icons.py` | Regenerates every icon file and `prototype/assets/icons.js` from one geometry source. |

## Regenerating

```sh
python3 design/tools/build_tokens.py           # colours, type, Compose theme, Flutter tokens (fails below WCAG AA)
python3 design/tools/build_tokens.py --check   # writes nothing; lists stale outputs and exits 1 (run by tool/check)
python3 design/tools/build_icons.py            # app icon sets
```

The Flutter app reads its tokens only through `packages/taketray_ui` (`TakeTrayTheme`, `context.tt`), so commit the regenerated files together with the token change.

## Key decisions (details in the hub)

- Brand: electric violet; marigold marks "clips waiting". Fixed colours, no dynamic colour. Unchanged by the rename.
- The tag player and clip viewer are always dark, on black.
- One tap on a reel tags and advances; "Pick several" (or long-press a chip) tags into several reels.
- Bottom navigation: Reels, To tag (count badge), Settings.
- "Edit video" sends clips to an editor; "Reel details" renames.
- References are links only, shown as designed cards (never thumbnails), under Shot ideas on reel detail, and in a References sheet from the Shooting mode card.
- Chosen: brand colour Graphite & marigold, welcome B · Tray, Flutter (Android first), custom TakeTray style. Still open: the icon concept and the tagline.
