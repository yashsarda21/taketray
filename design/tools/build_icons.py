#!/usr/bin/env python3
"""Build TakeTray app icon concepts.

One geometry source for every icon file. For each concept it writes:
  design/handoff/icons/<concept>/
    ic_launcher_background.xml      adaptive icon background (VectorDrawable, 108 dp)
    ic_launcher_foreground.xml      adaptive icon foreground (VectorDrawable, 108 dp)
    ic_launcher_monochrome.xml      Android 13+ themed icon layer (single colour)
    ic_launcher.xml                 mipmap-anydpi-v26 adaptive icon definition
    ic_stat_taketray.xml            notification small icon (24 dp, white)
    *.svg                           the same layers as SVG, plus preview.svg
  design/prototype/assets/icons.js  the same data for the prototype

Artwork stays inside the 66 dp safe zone (a circle of radius 33 around 54,54).
Run:  python3 design/tools/build_icons.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Fills are colour roles, resolved from the shipped brand palette (tokens/taketray.tokens.json)
# for the Android files, and left as CSS variables (--ic-*) for the prototype.
VIOLET, MARIGOLD, MARIGOLD_DEEP, LAVENDER, PEACH, SOFT2 = 'ic-bg', 'ic-accent', 'ic-accent-deep', 'ic-soft', 'ic-peach', 'ic-soft2'
WHITE = '#FFFFFF'


def role_colours():
    t = json.loads((ROOT / 'tokens' / 'taketray.tokens.json').read_text())
    pr, te = t['palette']['primary'], t['palette']['tertiary']
    return {'ic-bg': pr['40'], 'ic-soft': pr['80'], 'ic-soft2': pr['70'], 'ic-accent': te['80'],
            'ic-accent-deep': te['70'], 'ic-peach': te['90']}


def rr(x, y, w, h, r):
    """Rounded rectangle as path data (clockwise)."""
    return (f'M{x + r},{y}H{x + w - r}A{r},{r} 0 0 1 {x + w},{y + r}V{y + h - r}'
            f'A{r},{r} 0 0 1 {x + w - r},{y + h}H{x + r}A{r},{r} 0 0 1 {x},{y + h - r}'
            f'V{y + r}A{r},{r} 0 0 1 {x + r},{y}Z')


def tri(x1, y1, x2, y2, x3, y3):
    return f'M{x1},{y1}L{x2},{y2}L{x3},{y3}Z'


def circle(cx, cy, r):
    return f'M{cx - r},{cy}A{r},{r} 0 1 0 {cx + r},{cy}A{r},{r} 0 1 0 {cx - r},{cy}Z'


# A layer: d = path data, fill, optional rotate = (degrees, pivotX, pivotY), evenodd for holes.
CONCEPTS = {
    'tray': {
        'name': 'Tray of takes',
        'note': 'Recommended. Two takes standing in a tray: the name, drawn. One simple silhouette at 24 dp.',
        'background': VIOLET,
        'foreground': [
            {'d': rr(40, 28, 24, 38, 4), 'fill': LAVENDER, 'rotate': (-12, 52, 47)},
            {'d': rr(48, 32, 26, 40, 4.5), 'fill': WHITE, 'rotate': (7, 61, 52)},
            {'d': tri(57, 45.5, 67, 52, 57, 58.5), 'fill': VIOLET, 'rotate': (7, 61, 52)},
            {'d': 'M24,63H84L78.6,80.2C78.2,81.3 77.2,82 76,82H32C30.8,82 29.8,81.3 29.4,80.2Z', 'fill': MARIGOLD},
            {'d': rr(30, 68, 48, 1.6, 0.8), 'fill': MARIGOLD_DEEP},
        ],
        'monochrome': [
            {'d': rr(48, 32, 26, 27, 4.5) + tri(57, 41, 67, 47.5, 57, 54), 'evenodd': True, 'rotate': (7, 61, 46)},
            {'d': 'M24,63H84L78.6,80.2C78.2,81.3 77.2,82 76,82H32C30.8,82 29.8,81.3 29.4,80.2Z'},
        ],
        'notification': [
            {'d': rr(8, 2.5, 9, 10.5, 1.6) + tri(11, 5.2, 14.6, 7.75, 11, 10.3), 'evenodd': True},
            {'d': 'M3,15H21L19.6,20.2C19.45,20.7 19,21 18.5,21H5.5C5,21 4.55,20.7 4.4,20.2Z'},
        ],
    },
    'clapper': {
        'name': 'Clapper take',
        'note': 'A clapperboard marks every take on a film set. Strong film meaning; the stripes blur below 36 dp.',
        'background': VIOLET,
        'foreground': [
            {'d': rr(30, 46, 48, 34, 6), 'fill': WHITE},
            {'d': rr(30, 35, 48, 9, 2.5), 'fill': MARIGOLD, 'rotate': (-14, 32, 44)},
            {'d': 'M40,35H47L42,44H35Z' + 'M54,35H61L56,44H49Z' + 'M68,35H75L70,44H63Z', 'fill': VIOLET, 'rotate': (-14, 32, 44)},
            {'d': circle(32, 44, 2.6), 'fill': MARIGOLD},
            {'d': tri(50, 55, 62, 63, 50, 71), 'fill': VIOLET},
        ],
        'monochrome': [
            {'d': rr(30, 48, 48, 32, 6) + tri(50, 56, 62, 64, 50, 72), 'evenodd': True},
            {'d': rr(30, 35, 48, 9, 2.5) + 'M40,35H47L42,44H35Z' + 'M54,35H61L56,44H49Z', 'evenodd': True, 'rotate': (-14, 32, 44)},
        ],
        'notification': [
            {'d': rr(3, 10.5, 18, 10.5, 2) + tri(10.2, 12.8, 15, 15.75, 10.2, 18.7), 'evenodd': True},
            {'d': rr(3, 5.2, 18, 3.4, 1) + 'M7.5,5.2H10.3L8.6,8.6H5.8Z' + 'M13.2,5.2H16L14.3,8.6H11.5Z', 'evenodd': True, 'rotate': (-14, 3.6, 8.6)},
        ],
    },
    'stack': {
        'name': 'Sorted takes',
        'note': 'Index cards with tabs, like a card tray: sorting made visible. Calm, but less specific to video.',
        'background': VIOLET,
        'foreground': [
            {'d': rr(32, 30, 44, 26, 4) + rr(34, 26, 14, 6, 2), 'fill': SOFT2},
            {'d': rr(32, 40, 44, 26, 4) + rr(48, 36, 14, 6, 2), 'fill': PEACH},
            {'d': rr(32, 50, 44, 28, 4) + rr(62, 46, 14, 6, 2), 'fill': WHITE},
            {'d': tri(49, 57, 61, 64, 49, 71), 'fill': VIOLET},
        ],
        'monochrome': [
            {'d': rr(32, 27, 44, 7, 3)},
            {'d': rr(32, 38, 44, 7, 3)},
            {'d': rr(32, 49, 44, 29, 4) + tri(49, 56.5, 61, 63.5, 49, 70.5), 'evenodd': True},
        ],
        'notification': [
            {'d': rr(4, 3, 16, 3, 1.2)},
            {'d': rr(4, 7.5, 16, 3, 1.2)},
            {'d': rr(4, 12, 16, 9, 1.8) + tri(10.4, 14, 14.4, 16.5, 10.4, 19), 'evenodd': True},
        ],
    },
}


def svg_layers(layers, size, default_fill):
    out = []
    for L in layers:
        fill = L.get('fill', default_fill)
        rule = ' fill-rule="evenodd"' if L.get('evenodd') else ''
        path = f'<path d="{L["d"]}" fill="{fill}"{rule}/>'
        if 'rotate' in L:
            a, px, py = L['rotate']
            path = f'<g transform="rotate({a} {px} {py})">{path}</g>'
        out.append(path)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">{"".join(out)}</svg>\n'


def vd_layers(layers, size, default_fill, tint=None):
    paths = []
    for L in layers:
        fill = L.get('fill', default_fill)
        rule = '\n        android:fillType="evenOdd"' if L.get('evenodd') else ''
        p = f'    <path\n        android:fillColor="{fill}"{rule}\n        android:pathData="{L["d"]}" />'
        if 'rotate' in L:
            a, px, py = L['rotate']
            p = f'    <group android:rotation="{a}" android:pivotX="{px}" android:pivotY="{py}">\n    {p.strip()}\n    </group>'
        paths.append(p)
    tint_attr = f'\n    android:tint="{tint}"' if tint else ''
    return (f'<?xml version="1.0" encoding="utf-8"?>\n<!-- Generated by design/tools/build_icons.py -->\n'
            f'<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            f'    android:width="{size}dp"\n    android:height="{size}dp"\n'
            f'    android:viewportWidth="{size}"\n    android:viewportHeight="{size}"{tint_attr}>\n'
            + '\n'.join(paths) + '\n</vector>\n')


def resolve(c, roles):
    """Copy of a concept with role fills replaced by hex colours."""
    fix = lambda layers: [{**L, 'fill': roles.get(L['fill'], L['fill'])} if 'fill' in L else L for L in layers]
    return {**c, 'background': roles.get(c['background'], c['background']), 'foreground': fix(c['foreground'])}


def main():
    base = ROOT / 'handoff' / 'icons'
    roles = role_colours()
    for key, c0 in CONCEPTS.items():
        c = resolve(c0, roles)
        d = base / key
        d.mkdir(parents=True, exist_ok=True)
        bg = [{'d': 'M0,0H108V108H0Z', 'fill': c['background']}]  # noqa: E501
        (d / 'ic_launcher_background.xml').write_text(vd_layers(bg, 108, c['background']))
        (d / 'ic_launcher_foreground.xml').write_text(vd_layers(c['foreground'], 108, WHITE))
        (d / 'ic_launcher_monochrome.xml').write_text(vd_layers(c['monochrome'], 108, '#FF000000'))
        (d / 'ic_stat_taketray.xml').write_text(vd_layers(c['notification'], 24, '#FFFFFFFF'))
        (d / 'ic_launcher.xml').write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n<!-- res/mipmap-anydpi-v26/ic_launcher.xml -->\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@drawable/ic_launcher_background" />\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n</adaptive-icon>\n')
        (d / 'ic_launcher_background.svg').write_text(svg_layers(bg, 108, c['background']))
        (d / 'ic_launcher_foreground.svg').write_text(svg_layers(c['foreground'], 108, WHITE))
        (d / 'ic_launcher_monochrome.svg').write_text(svg_layers(c['monochrome'], 108, '#000000'))
        (d / 'ic_stat_taketray.svg').write_text(svg_layers(c['notification'], 24, '#FFFFFF'))
        (d / 'preview.svg').write_text(svg_layers(bg + c['foreground'], 108, WHITE))
    js = ROOT / 'prototype' / 'assets' / 'icons.js'
    js.write_text('/* Generated by design/tools/build_icons.py. */\nwindow.TT_ICONS = ' + json.dumps(CONCEPTS) + ';\n')
    print('Wrote', base, 'and', js)


if __name__ == '__main__':
    main()
