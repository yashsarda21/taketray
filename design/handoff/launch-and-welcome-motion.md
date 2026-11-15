# Launch and welcome motion: handoff

Owner-approved design change of 15 Nov 2026 (D-133).
- **Where to see it:** the hub's Motion page, section "Launch and welcome". It has a live phone with Replay, 0.5× and 0.25× speeds, and light and dark.
- **Still frames:** Screens 1 (splash) and 2 (welcome).
- **In the prototype:** Start from: Onboarding.
- **Prototype source:** `design/prototype/assets/intro.js`, plus the "Launch and welcome motion" section at the end of `assets/proto.css`.

**The two parts:**
1. **The splash, on every launch.** The launcher icon animates for 900 ms: the tray rises in, two clips drop into it, and it squashes slightly as it catches them. The splash leaves as soon as the first screen is drawn and never waits for the animation.
2. **The welcome intro, on first launch only.** The B · Tray welcome plays for 3.6 s: the takes drop into the tray, their reel tabs pop on, the count ticks to 23, the copy rises in, and a light glints across the tray.
   - Get started works from the first frame.
   - A tap on the picture skips to the end.
   - It plays once.

Rules for both (the UI skill's motion rules):
- Nothing loops.
- Nothing blocks input.
- A tap interrupts the intro.
- Items enter in a stagger.
- With "Remove animations" on, each part shows its final frame.
- The exit is faster than the entrance.

## 1. Splash (Android 12+ SplashScreen API)

The app has no branded splash today: `LaunchTheme` has Flutter's default `launch_background`, and Android 12+ shows the plain launcher icon.

**Resources.** Use `androidx.core:core-splashscreen`, so Android 11 (minSdk 30) shows the same look. Add to a `Theme.SplashScreen` child used as the launch theme:

| Attribute | Value |
|---|---|
| `windowSplashScreenBackground` | `primary` (graphite). Light and dark use the matching `values` and `values-night`. |
| `windowSplashScreenAnimatedIcon` | `@drawable/splash_icon_animated`, an `animated-vector`. |
| `windowSplashScreenIconBackgroundColor` | the icon background (`ic-bg`). On the light-theme splash it matches the window, as the hub shows. |
| `windowSplashScreenAnimationDuration` | `900`. This is informational on API 33+ and must stay ≤ 1000. |
| `windowSplashScreenBrandingImage` (API 31+) | the "TakeTray" wordmark, still. |
| `postSplashScreenTheme` | `NormalTheme`. |

- **Android 11** (the compat library) shows the still icon. No animation is expected there.
- **Remove animations:** with the system's "Remove animations" on, Android shows the still icon by itself. Nothing to code.

**The vector.** Use the launcher foreground (`design/handoff/icons/tray/`, viewport 108 × 108) and split its paths into three groups, in drawing order:

| Group | Paths | Pivot |
|---|---|---|
| `back` | the back clip (ic-soft, rotated −12°) | — |
| `front` | the front clip and its play mark (rotated 7°) | — |
| `tray` | the tray body (ic-accent) and its rim line (ic-accent-deep) | `pivotX 54`, `pivotY 82` (bottom centre) |

**Animations** (`objectAnimator`s; units are viewport units). "Emphasized decelerate" is `pathInterpolator` `M0,0 C0.05,0.7 0.1,1 1,1`. "Standard" is `C0.2,0 0,1 1,1`.

| Group | Start | Duration | Property | From → to | Interpolator |
|---|---|---|---|---|---|
| `tray` | 0 | 300 | `translateY` | 14 → 0 | emphasized decelerate |
| `tray` | 0 | 300 | fill alpha of its paths | 0 → 1 | emphasized decelerate |
| `back` | 150 | 400 | `translateY` | −40 → 0 (starts outside the circle mask) | emphasized decelerate |
| `back` | 150 | 400 | alpha | 0 → 1 | emphasized decelerate |
| `front` | 300 | 450 | `translateY` | −48 → 0 | emphasized decelerate |
| `front` | 300 | 450 | alpha | 0 → 1 | emphasized decelerate |
| `tray` | 700 | 220 | `scaleX` / `scaleY` | 1 → 1.04 → 1 / 1 → 0.9 → 1 (peak at 40 %) | standard |

The clips' existing rotations stay on inner groups, so the drop is straight down in the screen's frame.

**Fits the mask.** Android 12 masks the splash icon to a circle of 72 viewport units. Every point of the settled foreground is inside it; the farthest is the tray's bottom corner, 35.6 units from the centre. While a clip drops, its top is clipped by the mask, which is intended: it reads as falling in.

**Exit.** In `MainActivity.onCreate`, call `installSplashScreen()` before `super.onCreate`. Then use `setOnExitAnimationListener { v -> v.view.animate().alpha(0f).setDuration(200).withEndAction { v.remove() }.start() }`. The fade is `short4`, faster than the entrance.

Do **not** add `setKeepOnScreenCondition` for the animation's sake. The splash stays only until Flutter draws its first frame, as it does today; if that comes before 900 ms, the fade starts mid-animation.

## 2. Welcome intro (Flutter, onboarding, Phase 10)

**One controller.** One `AnimationController(duration: 3600 ms)` drives everything through `Interval`s. Times are milliseconds from the start; an interval is `Interval(start / 3600, end / 3600, curve: …)`.

| Element | Start–end | What | Curve |
|---|---|---|---|
| Whole screen | 0–200 | opacity 0 → 1 (follows the splash's fade) | `Easing.standard` |
| Get started | — | **no animation**: present and enabled from frame 0 | — |
| Background disc | 0–500 | scale 0.5 → 1, opacity 0 → its 0.5 / 0.2 | `Easing.emphasizedDecelerate` |
| Tray | 100–550 | translate y +80 dp → 0, opacity 0 → 1 | `Easing.emphasizedDecelerate` |
| Take London Food | 600–1250 | the drop (below) | — |
| Take Cinematic | 1000–1650 | the drop | — |
| Take Day 1 Vlog | 1400–2050 | the drop | — |
| Tray dip ×3 | 1050, 1450, 1850, 240 each | translate y 0 → 5 dp → 0, scale 1.01 × 0.97 at 40 % | `Easing.standard` |
| Each take's tab | its start + 480, 250 | scale 0.4 → 1 from its bottom-left corner, opacity 0 → 1 | `Easing.emphasizedDecelerate` |
| Count | 650–1900 | `IntTween(0, 23)`: "N takes", tabular figures, the number right-aligned in 2 ch so the word does not move | `Curves.linear` (keeps pace with the drops) |
| "· 3 reels" | 1900–2150 | opacity 0 → 1 | `Easing.standard` |
| Wordmark | 2200–2650 | translate y +14 dp → 0, opacity 0 → 1 | `Easing.emphasizedDecelerate` |
| Headline | 2350–2800 | same | `Easing.emphasizedDecelerate` |
| Text and step dots | 2500–2950 | same (the dots fade only) | `Easing.emphasizedDecelerate` |
| Glint | 2900–3600 | a 100° white band (white 60 % at its centre, transparent at ±18 % of the tray's width) sweeps from −100 % to +100 % of the tray's width, clipped to the tray's shape | `Easing.standard` |

**The drop** is a `TweenSequence` on translate y, with opacity 0 → 1 over its first 15 %:

| Weight | Translate y | Curve |
|---|---|---|
| 70 | −260 dp → +6 dp (starts above the picture, which clips it) | `Cubic(0.5, 0, 1, 1)`, speeds up as it falls |
| 15 | +6 → −2 dp | `Easing.standard` |
| 15 | −2 → 0 dp | `Easing.standard` |

The takes keep their rotations (−8°, 1°, 8°).

**Rules:**
- **First launch only.** Store a flag with the onboarding state when the intro starts (or is skipped). When it is set, build the welcome with `controller.value = 1`. Back from Video access, and a reopen before onboarding is finished, show the final frame.
- **Tap to skip.** A `GestureDetector` on the picture sets `controller.value = 1`.
- **Reduced motion.** `MediaQuery.disableAnimationsOf(context)` true → `controller.value = 1`, no `forward()`.
- **TalkBack.** The picture is one `Semantics(image: true, label: 'Three takes standing in a tray, labelled London Food, Cinematic and Day 1 Vlog')` with `excludeSemantics`. Wrap the wordmark, headline and text in `FadeTransition(alwaysIncludeSemantics: true)`, so they are read from frame 0 even while transparent.
- **Durations.** The intro's 650, 700, 1250 and 3600 ms durations are local constants in the intro widget. They are not motion tokens, because nothing else uses them. Everything else maps to an existing token (short4, medium1, medium2, medium4, long1, long2).
- **Clean up.** Dispose the controller. Stop it when the route is covered (`TickerMode`), and set it to 1 when the route comes back.

## Testing

- **Golden tests** at the frames the hub shows: 0.4 s, 1.0 s, 1.5 s, 1.95 s, 2.5 s, 3.1 s and final. Use `controller.value = t / 3600` in light and dark.
- **Widget tests:**
  - Get started is enabled at value 0.
  - A tap on the picture → value 1.
  - With `disableAnimations` → value 1 and no ticker.
  - Second build with the flag set → value 1.
  - Semantics: the headline is present at value 0.
- **On the S24, by hand:**
  - a cold start, with the splash's animation and fade;
  - a first-run welcome;
  - "Remove animations" on;
  - Android's splash on a warm start (none is shown).
