#!/usr/bin/env python3
"""Build TakeTray design tokens.

Single source of truth for colour, type, shape, spacing, elevation and motion.
Writes:
  design/tokens/taketray.tokens.json   (design tokens, light + dark)
  design/prototype/assets/tokens.css      (CSS variables used by the prototype)
  design/handoff/compose/*.kt             (Material 3 / Jetpack Compose theme)

Tonal palettes are generated from seed colours the same way Material 3 does it:
each palette keeps the seed's hue and chroma, and "tone" is CIE L* (0 = black,
100 = white), so contrast between tones is predictable. Hue and chroma are held
in OKLCH; chroma is reduced where a tone falls outside the sRGB gamut.

Run:  python3 design/tools/build_tokens.py
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# --------------------------------------------------------------------------
# Colour maths (sRGB <-> OKLab, CIE L*, WCAG contrast)
# --------------------------------------------------------------------------

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return '#' + ''.join(f'{round(max(0, min(1, c)) * 255):02X}' for c in rgb)


def linear_rgb_to_oklab(r, g, b):
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = (math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s))
    return (
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    )


def oklab_to_linear_rgb(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def hex_to_oklch(h):
    lin = [srgb_to_linear(c) for c in hex_to_rgb(h)]
    L, a, b = linear_rgb_to_oklab(*lin)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def luminance_linear(lin):
    r, g, b = lin
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def lstar_from_y(y):
    f = y ** (1 / 3) if y > 216 / 24389 else (24389 / 27 * y + 16) / 116
    return 116 * f - 16


def relative_luminance(h):
    return luminance_linear([srgb_to_linear(c) for c in hex_to_rgb(h)])


def contrast(h1, h2):
    a, b = relative_luminance(h1), relative_luminance(h2)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def _solve_lightness(tone, chroma, hue):
    """Find OKLab L so that the colour's CIE L* equals `tone`. Returns linear rgb."""
    a = chroma * math.cos(math.radians(hue))
    b = chroma * math.sin(math.radians(hue))
    lo, hi = 0.0, 1.0
    lin = (0, 0, 0)
    for _ in range(40):
        mid = (lo + hi) / 2
        lin = oklab_to_linear_rgb(mid, a, b)
        y = luminance_linear([max(0.0, c) for c in lin])
        if lstar_from_y(max(y, 1e-9)) < tone:
            lo = mid
        else:
            hi = mid
    return lin


def _in_gamut(lin, eps=1e-4):
    return all(-eps <= c <= 1 + eps for c in lin)


def tone_color(tone, chroma, hue):
    if tone <= 0:
        return '#000000'
    if tone >= 100:
        return '#FFFFFF'
    lin = _solve_lightness(tone, chroma, hue)
    if not _in_gamut(lin):
        lo, hi = 0.0, chroma
        for _ in range(30):
            mid = (lo + hi) / 2
            if _in_gamut(_solve_lightness(tone, mid, hue)):
                lo = mid
            else:
                hi = mid
        lin = _solve_lightness(tone, lo, hue)
    return rgb_to_hex([linear_to_srgb(max(0.0, min(1.0, c))) for c in lin])


TONES = [0, 4, 6, 10, 12, 17, 20, 22, 24, 25, 30, 35, 40, 45, 50, 60, 70, 75, 80, 85,
         87, 90, 92, 94, 95, 96, 98, 99, 100]


def palette(chroma, hue):
    return {str(t): tone_color(t, chroma, hue) for t in TONES}


# --------------------------------------------------------------------------
# Brand seeds
# --------------------------------------------------------------------------

SEEDS = {
    'primary': '#6A3DE8',    # electric violet: brand, primary actions, selection
    'tertiary': '#F4A300',   # marigold: "clips waiting" attention (To tag)
    'record': '#E5384F',     # REC red: Shooting mode on, "Recording" status
    'success': '#2E9E5B',    # green: "Published", "All caught up"
}

_, p_c, p_h = hex_to_oklch(SEEDS['primary'])
p_h = 293  # nudge toward violet: OKLCH 287 reads periwinkle in the light tones
_, t_c, t_h = hex_to_oklch(SEEDS['tertiary'])
_, r_c, r_h = hex_to_oklch(SEEDS['record'])
_, s_c, s_h = hex_to_oklch(SEEDS['success'])

PALETTES = {
    'primary': palette(min(p_c, 0.24), p_h),
    'secondary': palette(0.032, p_h),
    'tertiary': palette(min(t_c, 0.17), t_h),
    'neutral': palette(0.010, p_h),
    'neutralVariant': palette(0.022, p_h),
    'record': palette(min(r_c, 0.21), r_h),
    'success': palette(min(s_c, 0.11), s_h),
}

# Material 3 baseline error palette (well tested, keeps "error" recognisable)
PALETTES['error'] = {
    '0': '#000000', '10': '#410E0B', '20': '#601410', '30': '#8C1D18',
    '40': '#B3261E', '50': '#DC362E', '60': '#E46962', '70': '#EC928E',
    '80': '#F2B8B5', '90': '#F9DEDC', '95': '#FCEEEE', '99': '#FFFBF9',
    '100': '#FFFFFF',
}

P = PALETTES


def p(name, tone):
    return P[name][str(tone)]


# --------------------------------------------------------------------------
# Colour roles (Material 3 names so they map 1:1 onto Compose ColorScheme)
# --------------------------------------------------------------------------

def roles_light():
    return {
        'primary': p('primary', 40), 'onPrimary': p('primary', 100),
        'primaryContainer': p('primary', 90), 'onPrimaryContainer': p('primary', 10),
        'secondary': p('secondary', 40), 'onSecondary': p('secondary', 100),
        'secondaryContainer': p('secondary', 90), 'onSecondaryContainer': p('secondary', 10),
        # Tertiary container is vivid marigold in both themes: it marks "clips waiting".
        'tertiary': p('tertiary', 40), 'onTertiary': p('tertiary', 100),
        'tertiaryContainer': p('tertiary', 85), 'onTertiaryContainer': p('tertiary', 10),
        'error': p('error', 40), 'onError': p('error', 100),
        'errorContainer': p('error', 90), 'onErrorContainer': p('error', 10),
        'background': p('neutral', 98), 'onBackground': p('neutral', 10),
        'surface': p('neutral', 98), 'onSurface': p('neutral', 10),
        'surfaceVariant': p('neutralVariant', 90), 'onSurfaceVariant': p('neutralVariant', 30),
        'outline': p('neutralVariant', 50), 'outlineVariant': p('neutralVariant', 80),
        'inverseSurface': p('neutral', 20), 'inverseOnSurface': p('neutral', 95),
        'inversePrimary': p('primary', 80),
        'surfaceDim': p('neutral', 87), 'surfaceBright': p('neutral', 98),
        'surfaceContainerLowest': p('neutral', 100), 'surfaceContainerLow': p('neutral', 96),
        'surfaceContainer': p('neutral', 94), 'surfaceContainerHigh': p('neutral', 92),
        'surfaceContainerHighest': p('neutral', 90),
        'surfaceTint': p('primary', 40), 'scrim': '#000000', 'shadow': '#000000',
    }


def roles_dark():
    return {
        'primary': p('primary', 80), 'onPrimary': p('primary', 20),
        'primaryContainer': p('primary', 30), 'onPrimaryContainer': p('primary', 90),
        'secondary': p('secondary', 80), 'onSecondary': p('secondary', 20),
        'secondaryContainer': p('secondary', 30), 'onSecondaryContainer': p('secondary', 90),
        'tertiary': p('tertiary', 80), 'onTertiary': p('tertiary', 20),
        'tertiaryContainer': p('tertiary', 75), 'onTertiaryContainer': p('tertiary', 10),
        'error': p('error', 80), 'onError': p('error', 20),
        'errorContainer': p('error', 30), 'onErrorContainer': p('error', 90),
        'background': p('neutral', 6), 'onBackground': p('neutral', 90),
        'surface': p('neutral', 6), 'onSurface': p('neutral', 90),
        'surfaceVariant': p('neutralVariant', 30), 'onSurfaceVariant': p('neutralVariant', 80),
        'outline': p('neutralVariant', 60), 'outlineVariant': p('neutralVariant', 30),
        'inverseSurface': p('neutral', 90), 'inverseOnSurface': p('neutral', 20),
        'inversePrimary': p('primary', 40),
        'surfaceDim': p('neutral', 6), 'surfaceBright': p('neutral', 24),
        'surfaceContainerLowest': p('neutral', 4), 'surfaceContainerLow': p('neutral', 10),
        'surfaceContainer': p('neutral', 12), 'surfaceContainerHigh': p('neutral', 17),
        'surfaceContainerHighest': p('neutral', 22),
        'surfaceTint': p('primary', 80), 'scrim': '#000000', 'shadow': '#000000',
    }

LIGHT = roles_light()
DARK = roles_dark()


def extended(name, light_color_tone=40, dark_color_tone=80):
    return {
        'light': {
            'color': p(name, light_color_tone), 'onColor': p(name, 100),
            'colorContainer': p(name, 90), 'onColorContainer': p(name, 10),
        },
        'dark': {
            'color': p(name, dark_color_tone), 'onColor': p(name, 20 if dark_color_tone >= 70 else 100),
            'colorContainer': p(name, 30), 'onColorContainer': p(name, 90),
        },
    }


EXTENDED = {
    # REC dot must stay saturated on dark video and dark surfaces.
    'record': extended('record', 45, 70),
    'success': extended('success', 40, 80),
}

# --------------------------------------------------------------------------
# Brand colour options (for choosing; the default above stays the shipped one)
# Each option keeps the same roles, REC red, success green and error palette.
# --------------------------------------------------------------------------

OPTIONS = {
    'violet': {'name': 'Violet & marigold', 'p': (p_h, min(p_c, 0.24)), 't': (t_h, min(t_c, 0.17)), 'n': 0.010,
               'note': 'Creative and energetic; distinct from Instagram, CapCut and YouTube. The current direction.'},
    'teal': {'name': 'Teal & saffron', 'p': (192, 0.105), 't': (62, 0.17), 'n': 0.008,
             'note': 'Calm and focused, like a good tool. Saffron warmth for "clips waiting". Feels fresh next to most video apps.'},
    'cobalt': {'name': 'Cobalt & marigold', 'p': (263, 0.22), 't': (74, 0.17), 'n': 0.010,
               'note': 'Confident blue that reads very well in sunlight. The safest choice; blue is common among apps.'},
    'graphite': {'name': 'Graphite & marigold', 'p': (255, 0.035), 't': (74, 0.17), 'n': 0.006,
                 'note': 'Almost colourless, like a camera app: the videos bring the colour. Marigold becomes the only accent.'},
    'tangerine': {'name': 'Tangerine & indigo', 'p': (52, 0.19), 't': (275, 0.15), 'n': 0.008,
                  'note': 'Warm, bold and festive. Indigo marks "clips waiting". Orange sits near REC red, so REC keeps its dot and word.'},
}


def build_option(o):
    """Tonal palettes for one option (same structure as PALETTES)."""
    (ph, pc), (th, tc) = o['p'], o['t']
    pal = {
        'primary': palette(pc, ph), 'secondary': palette(min(0.032, pc * 0.7), ph),
        'tertiary': palette(tc, th), 'neutral': palette(o['n'], ph),
        'neutralVariant': palette(o['n'] * 2.2, ph),
        'record': PALETTES['record'], 'success': PALETTES['success'], 'error': PALETTES['error'],
    }
    return pal


def option_schemes():
    """Light/dark roles for every option, built with the same role functions."""
    global P
    keep = P
    out = {}
    for key, o in OPTIONS.items():
        P = PALETTES if key == 'violet' else build_option(o)
        out[key] = {'name': o['name'], 'note': o['note'], 'palette': P, 'light': roles_light(), 'dark': roles_dark()}
    P = keep
    return out


SCHEMES = option_schemes()

# The chosen brand colour (2026-10-23): Graphite & marigold. It drives the shipped tokens,
# the Compose and Flutter themes and the app icon; the other options stay for reference.
SHIPPED = 'graphite'
PALETTES = SCHEMES[SHIPPED]['palette']
P = PALETTES
LIGHT = SCHEMES[SHIPPED]['light']
DARK = SCHEMES[SHIPPED]['dark']

# --------------------------------------------------------------------------
# Type, shape, spacing, elevation, motion
# --------------------------------------------------------------------------

FONT = 'Plus Jakarta Sans'
TYPE = {
    # name: (size sp, line height sp, weight, letter spacing sp)
    'displaySmall': (36, 44, 800, -0.5),
    'headlineLarge': (32, 40, 800, -0.25),
    'headlineMedium': (28, 36, 700, -0.25),
    'headlineSmall': (24, 32, 700, 0),
    'titleLarge': (22, 28, 700, 0),
    'titleMedium': (16, 24, 600, 0.1),
    'titleSmall': (14, 20, 600, 0.1),
    'bodyLarge': (16, 24, 400, 0.15),
    'bodyMedium': (14, 20, 400, 0.2),
    'bodySmall': (12, 16, 500, 0.3),
    'labelLarge': (14, 20, 600, 0.1),
    'labelMedium': (12, 16, 600, 0.4),
    'labelSmall': (12, 16, 700, 0.5),
}

SHAPE = {'none': 0, 'extraSmall': 4, 'small': 8, 'medium': 12, 'large': 16,
         'largeIncreased': 20, 'extraLarge': 28, 'full': 999}

SPACING = {'0': 0, '1': 4, '2': 8, '3': 12, '4': 16, '5': 20, '6': 24, '8': 32,
           '10': 40, '12': 48, '16': 64}

ELEVATION = {
    'level0': {'dp': 0, 'shadow': 'none'},
    'level1': {'dp': 1, 'shadow': '0 1px 2px rgba(0,0,0,.30), 0 1px 3px 1px rgba(0,0,0,.15)'},
    'level2': {'dp': 3, 'shadow': '0 1px 2px rgba(0,0,0,.30), 0 2px 6px 2px rgba(0,0,0,.15)'},
    'level3': {'dp': 6, 'shadow': '0 1px 3px rgba(0,0,0,.30), 0 4px 8px 3px rgba(0,0,0,.15)'},
    'level4': {'dp': 8, 'shadow': '0 2px 3px rgba(0,0,0,.30), 0 6px 10px 4px rgba(0,0,0,.15)'},
    'level5': {'dp': 12, 'shadow': '0 4px 4px rgba(0,0,0,.30), 0 8px 12px 6px rgba(0,0,0,.15)'},
}

MOTION = {
    'duration': {'short1': 50, 'short2': 100, 'short3': 150, 'short4': 200,
                 'medium1': 250, 'medium2': 300, 'medium3': 350, 'medium4': 400,
                 'long1': 450, 'long2': 500},
    'easing': {
        'standard': [0.2, 0.0, 0.0, 1.0],
        'standardDecelerate': [0.0, 0.0, 0.0, 1.0],
        'standardAccelerate': [0.3, 0.0, 1.0, 1.0],
        'emphasizedDecelerate': [0.05, 0.7, 0.1, 1.0],
        'emphasizedAccelerate': [0.3, 0.0, 0.8, 0.15],
    },
}

SIZE = {'touchTarget': 48, 'iconSmall': 18, 'icon': 24, 'iconLarge': 32,
        'topAppBar': 64, 'navigationBar': 80, 'reelChip': 56, 'clipTileAspect': '3:4',
        'screenGutter': 16, 'gridGap': 4, 'designWidth': 360}

# --------------------------------------------------------------------------
# Contrast checks (fail the build if a pair is below its threshold)
# --------------------------------------------------------------------------

TEXT_PAIRS = [
    ('primary', 'onPrimary'), ('primaryContainer', 'onPrimaryContainer'),
    ('secondary', 'onSecondary'), ('secondaryContainer', 'onSecondaryContainer'),
    ('tertiary', 'onTertiary'), ('tertiaryContainer', 'onTertiaryContainer'),
    ('error', 'onError'), ('errorContainer', 'onErrorContainer'),
    ('surface', 'onSurface'), ('surface', 'onSurfaceVariant'),
    ('surfaceContainerHighest', 'onSurface'), ('surfaceContainerHighest', 'onSurfaceVariant'),
    ('surfaceContainerLow', 'onSurfaceVariant'), ('surface', 'primary'),
    ('surfaceContainer', 'primary'), ('inverseSurface', 'inverseOnSurface'),
    ('inverseSurface', 'inversePrimary'), ('surface', 'error'),
]
NON_TEXT_PAIRS = [('surface', 'outline'), ('surfaceContainerLow', 'outline'),
                  ('surface', 'primary'), ('surfaceContainer', 'tertiaryContainer')]


def check_contrast(light=None, dark=None):
    rows, failures = [], []
    for theme_name, scheme in (('light', light or LIGHT), ('dark', dark or DARK)):
        for bg, fg in TEXT_PAIRS:
            r = contrast(scheme[bg], scheme[fg])
            rows.append((theme_name, bg, fg, round(r, 2), 4.5))
            if r < 4.5:
                failures.append((theme_name, bg, fg, r))
        for bg, fg in NON_TEXT_PAIRS:
            r = contrast(scheme[bg], scheme[fg])
            rows.append((theme_name, bg, fg, round(r, 2), 3.0))
            if r < 3.0 and fg != 'tertiaryContainer':
                failures.append((theme_name, bg, fg, r))
        for name, ext in EXTENDED.items():
            e = ext[theme_name]
            for bg, fg in (('color', 'onColor'), ('colorContainer', 'onColorContainer')):
                r = contrast(e[bg], e[fg])
                rows.append((theme_name, f'{name}.{bg}', f'{name}.{fg}', round(r, 2), 4.5))
                if r < 4.5:
                    failures.append((theme_name, f'{name}.{bg}', f'{name}.{fg}', r))
            r = contrast(scheme['surface'], e['color'])
            rows.append((theme_name, 'surface', f'{name}.color', round(r, 2), 3.0))
            if r < 3.0:
                failures.append((theme_name, 'surface', f'{name}.color', r))
    # White text over video scrim (always-dark player): checked against #000 at 55%
    return rows, failures


# --------------------------------------------------------------------------
# Writers
# --------------------------------------------------------------------------

def kebab(name):
    out = ''
    for ch in name:
        out += ('-' + ch.lower()) if ch.isupper() else ch
    return out


def write_json(rows):
    tokens = {
        '$description': 'TakeTray design tokens (version 1). Generated by design/tools/build_tokens.py. '
                        'Colour roles use Material 3 names and map 1:1 onto Compose lightColorScheme / darkColorScheme. '
                        'Units: dp for sizes and spacing, sp for type, ms for durations.',
        'brand': {'option': SHIPPED, 'name': SCHEMES[SHIPPED]['name'],
                  'primaryOklch': {'hue': OPTIONS[SHIPPED]['p'][0], 'chroma': OPTIONS[SHIPPED]['p'][1]},
                  'tertiaryOklch': {'hue': OPTIONS[SHIPPED]['t'][0], 'chroma': OPTIONS[SHIPPED]['t'][1]},
                  'record': SEEDS['record'], 'success': SEEDS['success']},
        'color': {'light': LIGHT, 'dark': DARK},
        'extendedColor': EXTENDED,
        'videoSurface': {
            '$description': 'Tag player and clip viewer always use the dark scheme, on true black, whatever the app theme.',
            'background': '#000000', 'scrimTop': 'rgba(0,0,0,0.55)', 'scrimBottom': 'rgba(0,0,0,0.70)',
            'onVideo': '#FFFFFF', 'onVideoVariant': 'rgba(255,255,255,0.78)',
        },
        'palette': PALETTES,
        'typography': {
            'fontFamily': {'brand': FONT, 'fallback': 'Roboto, system-ui, sans-serif',
                           'numerals': 'tabular (font-feature-settings "tnum") for durations, counts and times'},
            'scale': {k: {'fontSize': v[0], 'lineHeight': v[1], 'fontWeight': v[2], 'letterSpacing': v[3]}
                      for k, v in TYPE.items()},
        },
        'shape': SHAPE,
        'spacing': SPACING,
        'elevation': ELEVATION,
        'motion': MOTION,
        'size': SIZE,
        'contrastReport': [
            {'theme': t, 'background': b, 'foreground': f, 'ratio': r, 'min': m} for t, b, f, r, m in rows
        ],
    }
    out = ROOT / 'tokens' / 'taketray.tokens.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(tokens, indent=2) + '\n')
    js = ROOT / 'prototype' / 'assets' / 'tokens.js'
    js.parent.mkdir(parents=True, exist_ok=True)
    opts = {k: {'name': v['name'], 'note': v['note'], 'light': v['light'], 'dark': v['dark'],
                'palette': {n: v['palette'][n] for n in ('primary', 'secondary', 'tertiary', 'neutral', 'neutralVariant')}}
            for k, v in SCHEMES.items()}
    js.write_text('/* Generated by design/tools/build_tokens.py. */\nwindow.RH_TOKENS = ' + json.dumps(tokens)
                  + ';\nwindow.RH_PALETTES = ' + json.dumps(opts) + ';\n')
    od = ROOT / 'tokens' / 'colour-options'
    od.mkdir(parents=True, exist_ok=True)
    for k, v in opts.items():
        (od / f'{k}.json').write_text(json.dumps({'$description': f"TakeTray colour option '{v['name']}' (for review; "
                                                  'the shipped tokens are in taketray.tokens.json).', **v}, indent=2) + '\n')
    return out


def css_scheme(scheme, ext, theme):
    lines = [f'  --md-{kebab(k)}: {v};' for k, v in scheme.items()]
    for name, e in ext.items():
        for role, v in e[theme].items():
            lines.append(f'  --x-{name}-{kebab(role)}: {v};')
    return '\n'.join(lines)


def chrome(pal, theme):
    n, nv, pr, t = pal['neutral'], pal['neutralVariant'], pal['primary'], pal['tertiary']
    if theme == 'light':
        return {'page-bg': n['96'], 'page-fg': n['10'], 'page-muted': nv['30'], 'page-line': nv['80'],
                'page-card': n['100'], 'page-raised': n['94'], 'page-accent': pr['40'], 'page-on-accent': pr['100'],
                'page-accent-soft': pr['90'], 'page-on-accent-soft': pr['10'], 'page-mark': t['85']}
    return {'page-bg': n['4'], 'page-fg': n['90'], 'page-muted': nv['80'], 'page-line': nv['30'],
            'page-card': n['10'], 'page-raised': n['17'], 'page-accent': pr['80'], 'page-on-accent': pr['20'],
            'page-accent-soft': pr['30'], 'page-on-accent-soft': pr['90'], 'page-mark': t['75']}


def icon_vars(pal):
    pr, t = pal['primary'], pal['tertiary']
    return {'ic-bg': pr['40'], 'ic-soft': pr['80'], 'ic-soft2': pr['70'], 'ic-accent': t['80'],
            'ic-accent-deep': t['70'], 'ic-peach': t['90']}


def write_css():
    """Each brand option sets raw values (--pl-* light, --pd-* dark, --plc/--pdc page chrome, --ic-* icon).
    The role variables (--md-*) read them, so a .pal-<option> class on any ancestor recolours everything
    inside it, and the nearest ancestor wins."""
    out = ROOT / 'prototype' / 'assets' / 'tokens.css'
    out.parent.mkdir(parents=True, exist_ok=True)
    parts = ['/* Generated by design/tools/build_tokens.py. Do not edit by hand. */', '',
             '/* ---- Brand colour options: raw values ---- */']
    for i, (key, sc) in enumerate(SCHEMES.items()):
        sel = f':root, .pal-{key}' if key == SHIPPED else f'.pal-{key}'
        v = [f'  --pl-{kebab(k)}: {c};' for k, c in sc['light'].items()]
        v += [f'  --pd-{kebab(k)}: {c};' for k, c in sc['dark'].items()]
        v += [f'  --plc-{k}: {c};' for k, c in chrome(sc['palette'], 'light').items()]
        v += [f'  --pdc-{k}: {c};' for k, c in chrome(sc['palette'], 'dark').items()]
        v += [f'  --{k}: {c};' for k, c in icon_vars(sc['palette']).items()]
        parts.append(f'{sel} {{\n' + '\n'.join(v) + '\n}')
    ext = lambda theme: '\n'.join(f'  --x-{n}-{kebab(r)}: {c};' for n, e in EXTENDED.items() for r, c in e[theme].items())
    roles = lambda prefix: '\n'.join(f'  --md-{kebab(k)}: var(--{prefix}-{kebab(k)});' for k in LIGHT)
    parts += ['', '/* ---- App themes: applied to each phone frame with .rh-light / .rh-dark ---- */',
              '.rh-light {\n' + roles('pl') + '\n' + ext('light') + '\n  color-scheme: light;\n}',
              '.rh-dark {\n' + roles('pd') + '\n' + ext('dark') + '\n  color-scheme: dark;\n}', '',
              '/* ---- Type, shape, spacing, elevation, motion ---- */', ':root {',
              f"  --font: '{FONT}', Roboto, system-ui, -apple-system, 'Segoe UI', sans-serif;"]
    for k, (size, lh, w, ls) in TYPE.items():
        parts.append(f'  --type-{kebab(k)}: {w} {size}px/{lh}px var(--font);')
        parts.append(f'  --ls-{kebab(k)}: {ls}px;')
    for k, v in SHAPE.items():
        parts.append(f'  --shape-{kebab(k)}: {v}px;')
    for k, v in SPACING.items():
        parts.append(f'  --space-{k}: {v}px;')
    for k, v in ELEVATION.items():
        parts.append(f'  --elev-{k[-1]}: {v["shadow"]};')
    for k, v in MOTION['duration'].items():
        parts.append(f'  --dur-{kebab(k)}: {v}ms;')
    for k, v in MOTION['easing'].items():
        parts.append(f'  --ease-{kebab(k)}: cubic-bezier({", ".join(str(x) for x in v)});')
    parts += ['}', '', '/* ---- Prototype page chrome (follows the viewer theme and the brand option) ---- */']
    keys = list(chrome(PALETTES, 'light'))
    light_vars = '\n'.join(f'  --{k}: var(--plc-{k});' for k in keys)
    dark_vars = '\n'.join(f'  --{k}: var(--pdc-{k});' for k in keys)
    parts.append(':root, [class*="pal-"] {\n' + light_vars + '\n}')
    parts.append('@media (prefers-color-scheme: dark) {\n  :root:not([data-theme="light"]), :root:not([data-theme="light"]) [class*="pal-"] {\n'
                 + dark_vars.replace('\n', '\n  ') + '\n    color-scheme: dark;\n  }\n}')
    parts.append(':root[data-theme="dark"], :root[data-theme="dark"] [class*="pal-"] {\n' + dark_vars + '\n  color-scheme: dark;\n}')
    out.write_text('\n'.join(parts) + '\n')
    return out


def kt_color(h):
    return f'Color(0xFF{h.lstrip("#").upper()})'


def write_kotlin():
    d = ROOT / 'handoff' / 'compose'
    d.mkdir(parents=True, exist_ok=True)
    header = ('// Generated by design/tools/build_tokens.py from taketray.tokens.json.\n'
              '// Do not edit by hand: change the tokens and re-run the script.\n'
              'package app.taketray.ui.theme\n\n')

    def scheme(fn, s):
        body = ',\n'.join(f'    {k} = {kt_color(v)}' for k, v in s.items() if k not in ('shadow',))
        return f'val {fn} = {fn.startswith("Light") and "lightColorScheme" or "darkColorScheme"}(\n{body},\n)\n'

    ext_fields = []
    for name in EXTENDED:
        for role in ('color', 'onColor', 'colorContainer', 'onColorContainer'):
            ext_fields.append(f'{name}{role[0].upper()}{role[1:]}')
    ext_class = 'data class ExtendedColors(\n' + ',\n'.join(f'    val {f}: Color' for f in ext_fields) + ',\n)\n'

    def ext_val(theme):
        vals = []
        for name, e in EXTENDED.items():
            for role in ('color', 'onColor', 'colorContainer', 'onColorContainer'):
                vals.append(f'    {name}{role[0].upper()}{role[1:]} = {kt_color(e[theme][role])}')
        return ',\n'.join(vals)

    color_kt = (header + 'import androidx.compose.material3.darkColorScheme\n'
                'import androidx.compose.material3.lightColorScheme\n'
                'import androidx.compose.runtime.staticCompositionLocalOf\n'
                'import androidx.compose.ui.graphics.Color\n\n'
                + scheme('LightColors', LIGHT) + '\n' + scheme('DarkColors', DARK) + '\n'
                + '/** Brand colours Material 3 has no role for: REC red and success green. */\n'
                + ext_class + '\n'
                + 'val LightExtendedColors = ExtendedColors(\n' + ext_val('light') + ',\n)\n\n'
                + 'val DarkExtendedColors = ExtendedColors(\n' + ext_val('dark') + ',\n)\n\n'
                + 'val LocalExtendedColors = staticCompositionLocalOf { LightExtendedColors }\n\n'
                + '/** Tag player and clip viewer: always dark, on true black. */\n'
                + 'val VideoBackground = Color(0xFF000000)\n')
    (d / 'Color.kt').write_text(color_kt)

    weight = {400: 'Normal', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold'}
    styles = []
    for k, (size, lh, w, ls) in TYPE.items():
        styles.append(f'    {k} = TextStyle(fontFamily = Brand, fontWeight = FontWeight.{weight[w]}, '
                      f'fontSize = {size}.sp, lineHeight = {lh}.sp, letterSpacing = {ls}.sp)')
    type_kt = (header + 'import androidx.compose.material3.Typography\n'
               'import androidx.compose.ui.text.TextStyle\n'
               'import androidx.compose.ui.text.font.Font\n'
               'import androidx.compose.ui.text.font.FontFamily\n'
               'import androidx.compose.ui.text.font.FontWeight\n'
               'import androidx.compose.ui.text.googlefonts.GoogleFont\n'
               'import androidx.compose.ui.unit.sp\n\n'
               '// Plus Jakarta Sans via downloadable fonts (falls back to Roboto until downloaded).\n'
               '// Add the provider certificates (R.array.com_google_android_gms_fonts_certs) to res/values.\n'
               'private val provider = GoogleFont.Provider(\n'
               '    providerAuthority = "com.google.android.gms.fonts",\n'
               '    providerPackage = "com.google.android.gms",\n'
               '    certificates = R.array.com_google_android_gms_fonts_certs,\n)\n'
               f'private val jakarta = GoogleFont("{FONT}")\n\n'
               'val Brand = FontFamily(\n'
               + ',\n'.join(f'    Font(googleFont = jakarta, fontProvider = provider, weight = FontWeight.{weight[w]})'
                            for w in sorted({v[2] for v in TYPE.values()}))
               + ',\n)\n\n'
               '/** Use for durations, counts and times so digits line up: "0:12", "23 clips". */\n'
               'val TabularNumbers = "tnum"\n\n'
               'val AppTypography = Typography(\n' + ',\n'.join(styles) + ',\n)\n')
    (d / 'Type.kt').write_text(type_kt)

    shape_kt = (header + 'import androidx.compose.foundation.shape.RoundedCornerShape\n'
                'import androidx.compose.material3.Shapes\n'
                'import androidx.compose.ui.unit.dp\n\n'
                'val AppShapes = Shapes(\n'
                f'    extraSmall = RoundedCornerShape({SHAPE["extraSmall"]}.dp),\n'
                f'    small = RoundedCornerShape({SHAPE["small"]}.dp),\n'
                f'    medium = RoundedCornerShape({SHAPE["medium"]}.dp),\n'
                f'    large = RoundedCornerShape({SHAPE["large"]}.dp),\n'
                f'    extraLarge = RoundedCornerShape({SHAPE["extraLarge"]}.dp),\n)\n\n'
                '/** Spacing scale (4 dp grid). */\nobject Spacing {\n'
                + '\n'.join(f'    val s{k} = {v}.dp' for k, v in SPACING.items())
                + f'\n    val gutter = {SIZE["screenGutter"]}.dp\n    val gridGap = {SIZE["gridGap"]}.dp\n'
                f'    val touchTarget = {SIZE["touchTarget"]}.dp\n    val reelChip = {SIZE["reelChip"]}.dp\n}}\n')
    (d / 'Shape.kt').write_text(shape_kt)

    motion_kt = (header + 'import androidx.compose.animation.core.CubicBezierEasing\n\n'
                 '/** Material 3 motion tokens used by TakeTray. Durations in ms. */\nobject Motion {\n'
                 + '\n'.join(f'    const val {k} = {v}' for k, v in MOTION['duration'].items()) + '\n'
                 + '\n'.join(f'    val {k} = CubicBezierEasing({", ".join(f"{x}f" for x in v)})'
                             for k, v in MOTION['easing'].items())
                 + '\n\n    // Tag-and-advance: chip confirm, hold, then clip exits left and next enters.\n'
                 '    const val tagConfirm = short3   // chip fills + check, haptic CONFIRM\n'
                 '    const val tagHold = medium1     // let the user see what they tagged\n'
                 '    const val clipExit = short4     // emphasizedAccelerate\n'
                 '    const val clipEnter = medium2   // emphasizedDecelerate\n}\n')
    (d / 'Motion.kt').write_text(motion_kt)

    theme_kt = (header + 'import androidx.compose.foundation.isSystemInDarkTheme\n'
                'import androidx.compose.material3.MaterialTheme\n'
                'import androidx.compose.runtime.Composable\n'
                'import androidx.compose.runtime.CompositionLocalProvider\n\n'
                '/**\n * Brand colours are fixed (no dynamic colour) so reels, chips and the\n'
                ' * "clips waiting" marigold look the same on every phone.\n */\n'
                '@Composable\nfun TakeTrayTheme(\n    darkTheme: Boolean = isSystemInDarkTheme(),\n'
                '    content: @Composable () -> Unit,\n) {\n'
                '    val extended = if (darkTheme) DarkExtendedColors else LightExtendedColors\n'
                '    CompositionLocalProvider(LocalExtendedColors provides extended) {\n'
                '        MaterialTheme(\n'
                '            colorScheme = if (darkTheme) DarkColors else LightColors,\n'
                '            typography = AppTypography,\n'
                '            shapes = AppShapes,\n'
                '            content = content,\n'
                '        )\n    }\n}\n\n'
                '/** Wrap the tag player and clip viewer so they are always dark. */\n'
                '@Composable\nfun VideoTheme(content: @Composable () -> Unit) =\n'
                '    TakeTrayTheme(darkTheme = true, content = content)\n')
    (d / 'Theme.kt').write_text(theme_kt)
    return d


def dart_color(h):
    return f'Color(0xFF{h.lstrip("#").upper()})'


FLUTTER_ROLES = ['primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer', 'secondary', 'onSecondary',
                 'secondaryContainer', 'onSecondaryContainer', 'tertiary', 'onTertiary', 'tertiaryContainer',
                 'onTertiaryContainer', 'error', 'onError', 'errorContainer', 'onErrorContainer', 'surface', 'onSurface',
                 'onSurfaceVariant', 'outline', 'outlineVariant', 'shadow', 'scrim', 'inverseSurface',
                 ('inverseOnSurface', 'onInverseSurface'), 'inversePrimary', 'surfaceTint', 'surfaceDim', 'surfaceBright',
                 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer', 'surfaceContainerHigh',
                 'surfaceContainerHighest']


def write_dart():
    """Flutter theme tokens: every brand option as Material 3 ColorSchemes, plus type, shape, spacing, motion."""
    def scheme(roles, brightness):
        args = []
        for r in FLUTTER_ROLES:
            src, dst = r if isinstance(r, tuple) else (r, r)
            args.append(f'    {dst}: {dart_color(roles[src])},')
        return f'ColorScheme(\n    brightness: Brightness.{brightness},\n' + '\n'.join(args) + '\n  )'
    weight = {400: 'w400', 500: 'w500', 600: 'w600', 700: 'w700', 800: 'w800'}
    lines = ['// GENERATED by design/tools/build_tokens.py from the TakeTray design tokens. Do not edit by hand.',
             '// Change the tokens and re-run: python3 design/tools/build_tokens.py', '',
             "import 'dart:ui' show FontVariation;", '',
             "import 'package:flutter/material.dart';", '',
             '/// Brand colour options. [shippedBrand] is the chosen one; the rest are kept for reference.',
             'enum BrandOption { ' + ', '.join(SCHEMES) + ' }', '',
             f'const shippedBrand = BrandOption.{SHIPPED};', '',
             'const brandNames = <BrandOption, String>{']
    for k, v in SCHEMES.items():
        lines.append(f"  BrandOption.{k}: '{v['name'].replace(chr(39), chr(92) + chr(39))}',")
    lines += ['};', '', '/// Light and dark Material 3 colour schemes for every brand option (all pass WCAG AA).',
              'const brandSchemes = <BrandOption, ({ColorScheme light, ColorScheme dark})>{']
    for k, v in SCHEMES.items():
        lines.append(f'  BrandOption.{k}: (\n  light: {scheme(v["light"], "light")},\n  dark: {scheme(v["dark"], "dark")},\n  ),')
    lines += ['};', '']
    # extended colours
    fields = [f'{n}{r[0].upper()}{r[1:]}' for n in EXTENDED for r in ('color', 'onColor', 'colorContainer', 'onColorContainer')]
    lines += ['/// Brand colours Material 3 has no role for: REC red and success green. Same in every brand option.',
              '@immutable', 'class TakeTrayColors extends ThemeExtension<TakeTrayColors> {',
              '  const TakeTrayColors({' + ', '.join(f'required this.{f}' for f in fields) + '});', '']
    lines += [f'  final Color {f};' for f in fields]
    def inst(theme):
        vals = ', '.join(f'{n}{r[0].upper()}{r[1:]}: {dart_color(EXTENDED[n][theme][r])}' for n in EXTENDED for r in ('color', 'onColor', 'colorContainer', 'onColorContainer'))
        return f'TakeTrayColors({vals})'
    lines += ['', f'  static const light = {inst("light")};', f'  static const dark = {inst("dark")};', '',
              '  @override', '  TakeTrayColors copyWith() => this;', '',
              '  @override', '  TakeTrayColors lerp(TakeTrayColors? other, double t) {',
              '    if (other == null) return this;',
              '    return TakeTrayColors(' + ', '.join(f'{f}: Color.lerp({f}, other.{f}, t)!' for f in fields) + ');',
              '  }', '}', '']
    # type
    lines += ["const fontFamily = 'PlusJakartaSans';", '',
              '/// Material 3 type scale in Plus Jakarta Sans (variable font: weight is set on the wght axis too).',
              'const appTextTheme = TextTheme(']
    flutter_names = {'displaySmall', 'headlineLarge', 'headlineMedium', 'headlineSmall', 'titleLarge', 'titleMedium',
                     'titleSmall', 'bodyLarge', 'bodyMedium', 'bodySmall', 'labelLarge', 'labelMedium', 'labelSmall'}
    for k, (size, lh, w, ls) in TYPE.items():
        if k in flutter_names:
            lines.append(f"  {k}: TextStyle(fontFamily: fontFamily, fontSize: {size}, height: {lh / size:.4f}, "
                         f"fontWeight: FontWeight.{weight[w]}, letterSpacing: {ls}, fontVariations: [FontVariation('wght', {w})]),")
    lines += [');', '', '/// Use on durations, counts and times so digits line up.',
              "const tabularFigures = [FontFeature.tabularFigures()];", '']
    lines += ['/// Corner radii (dp).', 'abstract final class Radii {']
    lines += [f'  static const double {k} = {v};' for k, v in SHAPE.items() if k != 'full']
    lines += ['}', '', '/// Spacing scale (4 dp grid).', 'abstract final class Space {']
    lines += [f'  static const double s{k} = {v};' for k, v in SPACING.items()]
    lines += [f"  static const double gutter = {SIZE['screenGutter']};", f"  static const double gridGap = {SIZE['gridGap']};",
              f"  static const double touchTarget = {SIZE['touchTarget']};", f"  static const double reelChip = {SIZE['reelChip']};", '}', '',
              '/// Material 3 motion tokens.', 'abstract final class Motion {']
    lines += [f'  static const {k} = Duration(milliseconds: {v});' for k, v in MOTION['duration'].items()]
    lines += [f'  static const {k} = Cubic({", ".join(str(x) for x in v)});' for k, v in MOTION['easing'].items()]
    lines += ['}', '']
    src = '\n'.join(lines).replace("import 'dart:ui' show FontVariation;\n\n", "")
    outs = [ROOT / 'handoff' / 'flutter' / 'tokens.g.dart', ROOT.parent / 'app' / 'lib' / 'theme' / 'tokens.g.dart']
    for o in outs:
        if o.parent.parent.parent.exists() or 'handoff' in str(o):
            o.parent.mkdir(parents=True, exist_ok=True)
            o.write_text(src)
    return outs[0]


def main():
    rows, failures = check_contrast()
    print('Seeds (OKLCH hue):', {k: round(hex_to_oklch(v)[2]) for k, v in SEEDS.items()})
    for theme in ('light', 'dark'):
        s = LIGHT if theme == 'light' else DARK
        print(f'\n{theme}: primary {s["primary"]}  primaryContainer {s["primaryContainer"]}  '
              f'tertiaryContainer {s["tertiaryContainer"]}  surface {s["surface"]}  '
              f'surfaceContainer {s["surfaceContainer"]}  outline {s["outline"]}')
    worst = sorted(rows, key=lambda r: r[3] / r[4])[:8]
    print('\nLowest contrast margins:')
    for t, b, f, r, m in worst:
        print(f'  {t:5} {b:26} / {f:26} {r:5.2f} (min {m})')
    for key, sc in SCHEMES.items():
        _, f2 = check_contrast(sc['light'], sc['dark'])
        print(f"  option {key:10} primary {sc['light']['primary']} / {sc['dark']['primary']}  "
              f"waiting {sc['light']['tertiaryContainer']} / {sc['dark']['tertiaryContainer']}  {'OK' if not f2 else 'FAIL'}")
        failures += [(key,) + x for x in f2]
    if failures:
        print('\nCONTRAST FAILURES:')
        for f in failures:
            print('  ', f)
        sys.exit(1)
    print('\nWrote', write_json(rows))
    print('Wrote', write_css())
    print('Wrote', write_kotlin())
    print('Wrote', write_dart())


if __name__ == '__main__':
    main()
