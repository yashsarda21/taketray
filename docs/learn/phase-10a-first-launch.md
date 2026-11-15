# Learning guide: Phase 10A, the first launch

This guide explains how TakeTray greets someone who has just installed it: the animated splash on every launch, the B · Tray welcome with its 3.6 s intro on the first launch, the steps that ask for video access and notifications in TakeTray's own words, the step that plans the first reels, and the one-time tip that points at Shooting mode. It is written as the phase is built; each section is filled in by the task that builds it.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-134 (the new phase order, the split into 10A and 10B, and the calls made for the owner), so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-134 (D-133 is the motion design it builds).
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Onboarding flags and creating several reels](#2-onboarding-flags-and-creating-several-reels)
3. [Routes, the redirect and the first frame](#3-routes-the-redirect-and-the-first-frame)
4. [The animated splash](#4-the-animated-splash)
5. [The welcome's picture](#5-the-welcomes-picture)
6. [The welcome intro](#6-the-welcome-intro)
7. [Video access and notification steps](#7-video-access-and-notification-steps)
8. [Planning reels and finishing](#8-planning-reels-and-finishing)
9. [The Home tip and the old first-time asks](#9-the-home-tip-and-the-old-first-time-asks)
10. [On the S24](#10-on-the-s24)

## 2. Onboarding flags and creating several reels

**What we built:** the memory first launch needs, and one new way to save reels.

- **Three flags** kept on the phone: `onboardingDone` (onboarding was finished), `introPlayed` (the welcome's animation has played) and `homeTipSeen` (Home's tip was dismissed).
- **`OnboardingController`**, a small object the router and the screens will both ask: "how far did this phone get?"
- **`ReelsRepository.createAll`**, which saves the reels the user types on the last step as one all-or-nothing batch.

**Why TakeTray needs it:** the first minute decides how the app feels, and it is also when things go wrong. The user can close TakeTray on Android's permission dialog, the phone can kill it, or the database can fail to read. Whatever happens, the next open must show the welcome again, never a blank app, never a half-made set of reels, and never a second "Create 3 reels" that makes duplicates.

**Key ideas:**

- **Phone state, not a setting.** The flags are rows in the same `settings` table as Shooting mode, but under `PhoneStateRepository`, so a backup never carries them (D-71): a restored backup on a new phone should still welcome its owner. A bad value reads as "no", and only the key's name is logged:

  ```dart
  _log.warning('Setting $key is corrupt, reading it as no');
  return false;
  ```

- **Show first, write second.** A mark changes the in-memory state before it writes. If the write fails, the user still goes on this session; the worst case is seeing the welcome once more:

  ```dart
  state = AsyncData(set(current));
  final phone = ref.read(phoneStateRepositoryProvider);
  await guarded(_log, 'Saving onboarding', () => write(phone));
  ```

- **Read the state after the wait.** Two marks at once (say the intro finishing as the user taps Skip) both wait for the first read. If each used the value that wait returned, the second would overwrite the first. So each reads `state.requireValue` after waiting. A test marks two flags together; breaking this line makes it fail.

- **An error is never the answer.** If reading the flags throws, `build` returns all false and logs only the error's type (`Reading onboarding failed: StateError`). The welcome shows; there is no error screen to get stuck on.

- **All or nothing for the reels.** `createAll` checks every name first, then does the work in one transaction. A name that repeats an earlier one in the same list is a duplicate too, even though neither is saved yet:

  ```dart
  for (final name in names) {
    if (!taken.add(reelNameKey(name))) {
      throw const InvalidInputException(ReelNameProblem.duplicate);
    }
  }
  ```

  `taken` starts with every saved reel's name key, and `add` returns false for a key already in the set. The inserts come after this, in the same transaction, so a failure on the third reel rolls back the first two (a test makes the database refuse the third name to prove it).

- **Tests that can fail.** All the tests were written first and failed to compile. After the code, three key lines were broken on purpose, one at a time: setting the state after the write, saving outside one transaction, and dropping the in-list duplicate check. Each made a named test fail. Two more checks (the "already set" guard and the stale read) did too.

**Where it lives:** `app/lib/data/repositories/phone_state_repository.dart` (`onboardingDone`, `introPlayed`, `homeTipSeen` and their marks), `app/lib/features/onboarding/view_models/onboarding_controller.dart` and `app/lib/data/repositories/reels_repository.dart` (`createAll`). Tests: the "onboarding flags (D-135)" group in `app/test/data/repositories/phone_state_repository_test.dart`, `app/test/features/onboarding/view_models/onboarding_controller_test.dart` and the "createAll (D-135)" group in `app/test/data/repositories/reels_repository_test.dart`.

**Try it yourself:** see "show first" matter. From the repo root:

```bash
cd app && ../tool/flutter test test/features/onboarding
```

It ends with `All tests passed!`. Now open `lib/features/onboarding/view_models/onboarding_controller.dart` and move the line `state = AsyncData(set(current));` to after the `await guarded(...)` line. Run it again: `finish() shows done before the write completes, then writes` fails, because that test holds the write open and looks at the state meanwhile. Put the line back and run it again to see it pass.

**Decisions:** D-135 (all of this section), with D-71 (phone state), D-114 (the folder tip it copies) and D-134 (the phase and the calls made for the owner) as background.

## 3. Routes, the redirect and the first frame

**What we built:** the road through onboarding, and the guard at its entrance.

- **Four new screens** (for now, stand-ins with a title): the welcome and the three steps for video access, notifications and planning reels. Later tasks draw them.
- **A redirect**: one small function that, on every navigation, asks "has this phone finished onboarding?" and sends the app to the welcome if not, or away from onboarding if it has.
- **A held first frame**: the app shows nothing (Android's splash stays up) until it knows the answer, for 2 seconds at most.
- **Dropped taps**: a notification tap that arrives during onboarding is ignored, not saved for later.

**Why TakeTray needs it:** a new user must start on the welcome, whatever opened the app: the launcher, a leftover notification, Android restoring an old screen. And someone who has finished must never see the welcome again. The answer lives in the database, which takes a moment to read, so the app also needs a plan for that moment: if it drew Reels and then jumped to the welcome, the user would see a flash of the wrong screen.

**Key ideas:**

- **The steps are ordinary routes.** go_router already knows how to go Back, so each step is *pushed* on top of the one before. Back returns to the previous step, and on the welcome there is nothing left, so Android closes the app. The routes sit outside the tab shell, so no nav pill shows:

  ```dart
  GoRoute(
    path: Routes.welcome,
    builder: (context, state) => const WelcomeScreen(),
  ),
  ```

- **One pure function decides.** It takes a location and the flags and returns where to go instead, or `null` to stay. Because it touches nothing else, a test can check it as a table (every location × not read yet, not done, done):

  ```dart
  String? onboardingRedirect(Uri location, OnboardingFlags? flags) {
    if (flags == null) return null;
    final onboarding = Routes.isOnboarding(location.path);
    if (flags.done) return onboarding ? Routes.reels : null;
    return onboarding ? null : Routes.welcome;
  }
  ```

- **Exact matches, not prefixes.** `isOnboarding` compares the path with the four locations exactly. A shortcut like `startsWith('/onboarding')` would also let `/onboardingx` through. A test lists such near misses, and swapping in the shortcut makes it fail.

- **The router listens instead of being rebuilt.** The flags live in a small `OnboardingGate` (a `ValueNotifier`) that follows the controller from Task 2. The router gets it as its `refreshListenable`: when the flags change (the first read, or `finish()` on the last step), go_router runs the redirect again on the current page. Rebuilding the router instead would throw away the whole navigation stack.

- **Holding the first frame.** Flutter can be told not to draw yet. The app asks for that in `initState`, and lets go exactly once, as soon as the flags are known:

  ```dart
  void _allowFirstFrame() {
    if (!_holdingFirstFrame) return;
    _holdingFirstFrame = false;
    _firstFrameTimer?.cancel();
    _onboarding.removeListener(_onOnboarding);
    WidgetsBinding.instance.allowFirstFrame();
  }
  ```

  The guard matters: Flutter asserts if the frame is allowed twice. A test proves it by deleting the guard, and every app test then fails with `'_firstFrameDeferredCount > 0': is not true`.

- **A limit, so nobody waits forever.** If the database hangs, a 2 s timer (`_firstFrameLimit`) gives up waiting, treats the phone as "not onboarded" and lets the frame go. Showing the welcome is the safe side: the user can go through it, and if the read finishes later with "done", the redirect still takes them to Reels.

- **Taps during onboarding are dropped.** A notification tap first waits for the flags (the tap that started the app arrives before they are read), then is ignored if onboarding is not done. The redirect would keep the screen off anyway, but it would also throw a user on step 3 back to the welcome.

- **Every old test runs onboarded.** Many existing tests, and every Patrol flow, start the whole app. Each harness now puts a `FixedOnboarding` (flags fixed at "done", nothing written) into the app, so they all still start on Reels. A test about first launch passes its own: `VmHarness(onboarding: FixedOnboarding.fresh)`.

**Where it lives:** `app/lib/router/routes.dart` (the four locations and `isOnboarding`), `app/lib/router/onboarding_redirect.dart` (`onboardingRedirect`, `OnboardingGate`), `app/lib/router/app_router.dart` (`onboardingRoutes`, the `redirect` and `refreshListenable`), `app/lib/app.dart` (`_firstFrameLimit`, `_holdFirstFrame`, `LaunchActionsListener`) and the stand-ins in `app/lib/features/onboarding/views/`. Tests: `app/test/router/onboarding_redirect_test.dart`, the "Onboarding (D-136)" group in `app/test/router/app_router_test.dart` and two groups in `app/test/app_test.dart`. The harnesses: `app/test/support/fixed_onboarding.dart` and `app/patrol_test/support/onboarded.dart`.

**Try it yourself:** watch the frame being held. From the repo root:

```bash
cd app && ../tool/flutter test test/app_test.dart --plain-name "the first frame"
```

It ends with `All tests passed!`. Now open `app/lib/app.dart` and, in `_firstFrameTooLate`, delete the two lines `_onboarding.stopWaiting();` and `_allowFirstFrame();`. Run it again: `a read that never ends: frames are sent after 2 s, on the welcome` fails, because nothing lets the frame go when the database never answers. Put the lines back and run it once more.

**Decisions:** D-136 (all of this section), with D-134 (why a redirect and not a gate widget, and why taps are dropped), D-135 (the flags) and D-107 (notification taps) as background.

## 4. The animated splash

**What we built:** the first thing every launch shows: the tray icon on a graphite screen, animating for under a second.

- **The motion.** The tray rises in, two clips drop into it one after the other, and the tray squashes slightly as it catches them. It plays once, in 920 ms, and never loops.
- **The wordmark.** "TakeTray" in the app's own heavy font sits still at the bottom.
- **The exit.** When the app's first screen is ready, the splash fades out in 200 ms. It never waits for the animation to finish.
- **Both colour modes.** Light mode is graphite; dark mode is the light graphite with a dark icon disc.

**Why TakeTray needs it:** the owner wanted a more inviting first impression (D-133). The catch is that people open TakeTray many times a day, so the splash must add no waiting. Android already shows a splash before our code runs, so TakeTray only decorates that one instead of building its own.

**Key ideas:**

- **It is all resources.** The look is not code. A theme named `LaunchTheme` points at an icon, a background colour, the wordmark and a duration. Android reads that theme before the app process has finished starting:

  ```xml
  <style name="LaunchTheme" parent="Theme.SplashScreen.IconBackground">
      <item name="windowSplashScreenBackground">@color/splash_background</item>
      <item name="windowSplashScreenAnimatedIcon">@drawable/splash_icon_animated</item>
      <item name="windowSplashScreenAnimationDuration">900</item>
      <item name="postSplashScreenTheme">@style/NormalTheme</item>
  </style>
  ```

  `postSplashScreenTheme` is the theme the app uses once the splash is gone: Flutter's normal one.

- **An animated vector is a drawing plus a list of moves.** The drawing is the launcher icon cut into three named groups (`back`, `front`, `tray`). A second file lists, for each group, which animator to run:

  ```xml
  <target android:name="back" android:animation="@animator/splash_back" />
  ```

  Each animator is a start delay, a duration, a from and a to. For the back clip: wait 150 ms, then move 400 ms from 40 units above to 0 (the icon is drawn on a 108-unit square), slowing down as it lands (the "emphasized decelerate" curve).

- **Two guards for the real phone.** A delayed animator (the clips wait 150 and 300 ms) leaves its target drawn at the vector's own, settled values until it starts, so each clip also gets a zero-length animator at 0 ms that sets its start value (hidden, above the tray) from the first frame. The vector itself is left settled, because Android 11 and "Remove animations" show it as it is. And the tray's squash is written as plain "there" and "back" animators (88 ms and 132 ms) instead of one animator with three keyframes, because the hardware renderer may sample only a keyframe animator's first and last values, which are both 1.

- **Rotation stays inside.** The clips are tilted (-12 and 7 degrees). If the moving group were also tilted, "down" would be a slanted line. So the tilt sits on an inner group and the outer group only moves straight down.

- **Fading a vector means fading its paths.** A vector group has no opacity, so each path's `fillAlpha` goes 0 to 1 along with the move.

- **The exit is code, and it is short.** `MainActivity.onCreate` installs the splash first, before `super.onCreate`, then gives it one exit listener:

  ```kotlin
  fun fadeOut(view: View, remove: () -> Unit) {
      view.animate().alpha(0f).setDuration(FADE_MS).withEndAction(remove).start()
  }
  ```

  Faster out (200 ms) than in (the motion) is the rule for the whole phase.

- **Nothing makes the splash wait.** Android's splash API has a `setKeepOnScreenCondition` for that. TakeTray does not use it. The splash leaves as soon as Flutter draws its first frame, and since the last task Dart holds that frame until the onboarding flags are read, so the splash simply covers that short wait. It works because `FlutterActivity` itself holds the activity's first draw until Flutter's first frame.

- **The wordmark is a drawing, not a picture.** The letters' outlines were taken from the bundled font and written as vector paths, so they are sharp at every density and change colour with dark mode. A one-off script made them; it is not in the repository.

- **What the old phones and settings get.** Android 11 shows the still icon (the library does not animate there). With "Remove animations" on, Android shows the finished icon by itself.

**Where it lives:** `app/android/app/src/main/res/values/styles.xml` (`LaunchTheme`), `values/colors.xml` and `values-night/colors.xml`, `res/drawable/splash_icon_vector.xml`, `splash_icon_animated.xml` and `splash_wordmark.xml`, `res/animator/` and `res/interpolator/`, `app/android/app/src/main/kotlin/app/taketray/LaunchSplash.kt` and the first lines of `MainActivity.onCreate`. Tests: `app/android/app/src/test/kotlin/app/taketray/SplashTest.kt`.

**Try it yourself:** change the length of the motion and watch a test notice. From the repo root:

```bash
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.SplashTest'
```

It ends with `BUILD SUCCESSFUL`. Now open `app/android/app/src/main/res/values/styles.xml` and change `windowSplashScreenAnimationDuration` from `900` to `1200`. Run it again: `the splash animation lasts 900 ms and stays within Android's 1000 ms` fails, because Android's advice is to stay under a second. Put `900` back. (You will only see the splash itself on a phone; that check is in section 10.)

**Decisions:** D-137 (all of this section), with D-133 (the design) and D-136 (the held first frame the splash covers) as background.

## 5. The welcome's picture

**What we built:** the first screen a new user sees, drawn as its last frame: three clips standing in a tray, each with a tab saying which reel it will go to, a count on the tray ("23 takes · 3 reels"), the app's name and one line of what it does, and **Get started**. It does not move yet; section 6 makes it play.

- **The picture.** A soft coloured block 372 dp tall. A big pale disc sits in its top right corner. Three video frames lean against each other in the middle (left, centre, right), each with a small tab above it ("London Food", "Cinematic", "Day 1 Vlog"). A tray, shaped like a trapezoid, holds them at the bottom and carries the count.
- **Below it.** Four dots (this is step 1 of 4), the round app icon with "TakeTray" beside it, the headline "One tray for every take", and two lines about filming as usual.
- **At the bottom.** **Get started**, always in the same place: when the text is very large, the picture and the words scroll, but the button does not.

**Why TakeTray needs it:** the owner chose this welcome (the "B · Tray" option) because it shows the app's name as a picture: the clips you shoot land in a tray and wait to be sorted. It is also where the intro of section 6 happens, so the picture is built from the start to be redrawn many times a second.

**Key ideas:**

- **The picture is a function of a frame.** Instead of animating inside the widget, `WelcomeTrayArt` takes one plain object, a `WelcomeArtFrame`, listing every number that can change: how far each take has dropped, how see-through the tray is, which number the count shows, where the glint of light is. Draw the object, get the picture. Section 6 only has to work out a new object for each moment of the intro. `WelcomeArtFrame.end` is the finished picture, and `end` is the default:

  ```dart
  const WelcomeArtFrame({
    this.discScale = 1,
    this.discOpacity = 1,
    this.trayDy = 0,
    ...
    this.count = 23,
    this.reelsOpacity = 1,
    this.glint,
  })
  ```

  The words, dots and button have their own object, `WelcomeBodyFrame`, because they move on a different schedule.
- **A take drops in the screen's frame, not its own.** The takes lean, so moving a leaning card "down" must not slide it sideways. The widget nests the move *outside* the lean: `Transform.translate(Transform.rotate(card))`. Swap the two and a dropping take would drift along its own tilted edge. A test checks that a take moved 50 dp ends exactly 50 dp lower and not one pixel to the side.
- **The count never makes the words jump.** The number counts 0, 1, 2 ... 23 in the intro, and its digits have different widths. The number is drawn right-aligned in a box as wide as "00" (with figures of equal width), and the word "takes" sits after the box, so the word stays put. The word's own box is as wide as the longest word, so "1 take" does not shift the label either.
- **One picture for a screen reader.** The picture holds text (the tabs, the count), but a person using TalkBack should not hear it in pieces. `Semantics(image: true, label: ..., excludeSemantics: true)` makes it one image with one label. The headline, wordmark and text are the opposite: they must be read from the first frame even while invisible, so they sit in an `Opacity` with `alwaysIncludeSemantics: true`.
- **The picture is a drawing.** At 200 % text the words below it grow, the picture does not (it has a fixed height and its labels keep their size). Otherwise "London Food" would burst out of a 24 dp tab.
- **Pictures that ship with the app.** The three clip pictures (and a fourth for a later step) are four small PNG files in `app/assets/welcome/`. Until now the app had no assets of its own (D-40); D-138 changes that and records how the files were made, so they can be remade.
- **A launcher icon you can place anywhere.** `TtBrandMark(size)` in the design-system package paints the tray icon from the same shapes as the real launcher icon (`ic_launcher_foreground.svg`), clipped to a circle, at any size.

**Where it lives:** `app/lib/features/onboarding/views/welcome_tray_art.dart` (`WelcomeArtFrame`, `WelcomeTakeFrame`, `WelcomeTrayArt`), `welcome_screen.dart` (`WelcomeBodyFrame`, `WelcomeScreen`), `step_dots.dart`; `packages/taketray_ui/lib/src/components/brand_mark.dart`; the pictures in `app/assets/welcome/`. Tests: `app/test/features/onboarding/views/` (`welcome_tray_art_test.dart`, `welcome_screen_test.dart`, `step_dots_test.dart`, and the screenshots in `welcome_golden_test.dart`), `packages/taketray_ui/test/components/brand_mark_test.dart`.

**Try it yourself:** make the middle take lean twice as much and watch a test notice. From `app/`:

```bash
../tool/flutter test test/features/onboarding/views/welcome_tray_art_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/features/onboarding/views/welcome_tray_art.dart` and change `_takeDegrees` from `[-8, 1, 8]` to `[-8, 2, 8]`. Run it again: `the takes lean -8, 1 and 8 degrees and the middle one is on top of its neighbours` fails. Put `1` back. (The screenshots in `test/features/onboarding/views/goldens/macos/` are the picture itself; they are compared only on the owner's Mac.)

**Decisions:** D-138 (all of this section), with D-133 (the design), D-136 (the screen's route) and D-40 (amended: the app now has assets) as background.

## 6. The welcome intro

**What we built:** the 3.6 second animation a new user sees once, on the welcome of section 5. The disc and the tray come in, the three clips drop into the tray one after another (the tray dips a little as it catches each), each clip's reel tab pops on as it lands, the count ticks up to "23 takes", "· 3 reels" fades in, the app's name, headline and text rise into place, and a band of light glints across the tray.

- **Get started works from the very first frame.** Nobody has to wait for the animation.
- **A tap on the picture skips** to the end.
- **It plays once.** Come back from the next step, or reopen the app before finishing onboarding, and the welcome shows its last frame.
- **"Remove animations"** in Android's settings shows the last frame at once.

**Why TakeTray needs it:** the welcome's picture tells the app's whole idea (clips land in a tray, then go to reels), and the animation tells it in order. It must never get in the way: it does not block the button, it can be skipped, it never repeats and it respects the system's motion setting.

**Key ideas:**

- **Time in, picture out.** Section 5 made the picture a function of a frame object. This section adds the other half: a function from time to a frame. `welcomeFrameAt(t)` takes the animation's progress `t` (0 at the start, 1 at the end) and returns every number of the picture at that moment. Each element of the design's table is an `Interval`, a slice of the 0 to 1 range with its own curve:

  ```dart
  Interval _span(num startMs, {Duration? length, int? lengthMs, Curve? curve}) {
    final ms = lengthMs ?? length!.inMilliseconds;
    return Interval(
      startMs / _introMs,
      (startMs + ms) / _introMs,
      curve: curve ?? Curves.linear,
    );
  }
  ```

  Because it is a plain function, a test can ask for any millisecond without running an animation: "the count is 0 before 650 ms and 23 from 1900 ms", "the first clip is 6 dp below its place at 70 % of its drop".
- **A drop with a bounce is three tweens in a row.** A `TweenSequence` splits one clip's 650 ms drop by weight: 70 % falling from 260 dp above (speeding up), 15 % bouncing back to 2 dp above, 15 % settling. The tray's dip is the same idea: down to 5 dp (and a little wider and flatter) at 40 %, back up after.
- **One controller drives everything.** `WelcomeIntro` owns a single `AnimationController` of 3.6 s and rebuilds the welcome from `welcomeFrameAt(controller.value)` on each tick. A skip is just `controller.value = 1`: the same code draws the last frame whether the animation finished, was skipped or never ran.
- **Mark it played when it starts, not when it ends.** The intro calls `markIntroPlayed()` as it starts, so an app killed half way through never plays it again. But that mark changes the very flag the welcome checks! So the welcome reads the flag once with `ref.read` when it is first built, and never watches it; otherwise its own mark would jump it to the end.
- **Stop when nobody can see it.** When **Get started** pushes the next step, Flutter turns off tickers for the hidden welcome (`TickerMode`). The intro notices, stops, and when the user comes Back it jumps to the last frame instead of carrying on half way.
- **Screen readers read the words from frame 0.** The headline and text are invisible for the first two seconds, but an `Opacity` with `alwaysIncludeSemantics: true` keeps them in what TalkBack reads. The picture is one image and does not announce that it can be tapped.

**Where it lives:** `app/lib/features/onboarding/views/welcome_intro.dart` (`introDuration`, `welcomeFrameAt`, `welcomeBodyFrameAt`, `WelcomeIntro`); the tap on the picture in `welcome_screen.dart` (`onPictureTap`); the route in `app/lib/router/app_router.dart`. Tests: `app/test/features/onboarding/views/welcome_intro_test.dart`, and the screenshots at 0.4, 1.0, 1.5, 1.95, 2.5 and 3.1 s in `welcome_intro_golden_test.dart`.

**Try it yourself:** make the count end on 22 and watch a test notice. From `app/`:

```bash
../tool/flutter test test/features/onboarding/views/welcome_intro_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/features/onboarding/views/welcome_intro.dart` and change `IntTween(begin: 0, end: 23)` to `end: 22`. Run it again: `the count is 0 before 650 ms and 23 from 1900 ms` fails (and so does `at 1 it is the final frame`). Put `23` back.

**Decisions:** D-139 (all of this section), with D-133 (the motion design), D-135 (the `introPlayed` flag) and D-138 (the frame objects) as background.

## 7. Video access and notification steps

**What we built:** the second and third steps of onboarding. The first asks for access to the phone's videos and shows what is true right now: "Let TakeTray see your videos" before asking, "TakeTray can see only some videos" if the user chose a few, "TakeTray can't see your videos" if they said no, and "All set" if everything works. The second shows what the "new clips" notification looks like and asks to allow it.

- **The step never lies.** Go to Android's settings, allow all videos, come back: the step says "All set". Open the step with access already given from an earlier install: "All set", nothing asked. Take access away while the step is open: it changes back.
- **A "no" is remembered for the step.** After you say no, the step stops offering "Allow access" and offers "Open settings" (and "Continue in Manual mode"). "Open settings" always opens the app's page in Android's settings and never shows the question again (it has its own controller method, `openSettings()`, so its label tells the truth).
- **One tap, one question.** The buttons turn off while Android's dialog is up, so a double tap does not ask twice.
- **The notification step skips itself** on Android 11 and 12 (they have no question) and when the permission is already given. Whatever the answer to the question, the user goes on to the next step.

**Why TakeTray needs it:** TakeTray cannot find new clips without access to videos, and a notification is how it tells you clips are waiting. Asking in two calm steps with their own words, instead of a surprise dialog when Shooting mode is first turned on, tells the user why before Android asks.

**Key ideas:**

- **The look is a function of the state.** The controller already knows the access level and whether Android would still show its dialog. One small function turns that into a look:

  ```dart
  AccessStep accessStepFor(MediaAccessView view, {required bool askedHere}) =>
      switch (view.level) {
        MediaAccessLevel.full => AccessStep.allSet,
        MediaAccessLevel.limited => AccessStep.some,
        MediaAccessLevel.denied =>
          askedHere || !view.canAskAgain ? AccessStep.denied : AccessStep.before,
      };
  ```

  The screen just watches the controller. When the app comes back from Android's settings the controller reads the level again, the state changes, and the step follows. No special code for "came back from settings".
- **The only things the screen remembers** are "did I ask here" (so a "no" shows the denied look) and "is a question running" (so the buttons wait). Both are things the controller cannot know. Keeping them in the screen and not in the database means a user who changes their mind in Android's settings is not stuck on an old answer.
- **Decide once.** The notification step looks at the first answer to "can this phone ask?" and either shows itself or replaces itself with the next step. If it looked every time the state changed, asking and getting "allowed" would make it skip a second time while the "go on" button was already moving on. `_skip ??= ...` keeps the first decision.
- **A step layout shared by the steps.** `OnboardingStepLayout` gives each step the same picture area, scrolling body and bottom buttons, so at the biggest text the buttons stay where the thumb is and the words scroll. The notification card is a picture, so its text keeps one size and a screen reader skips it.
- **Which word Android uses.** From Android 14 the question has "Allow all"; before, "Allow". The hint ("On the next screen, choose **Allow all**.") has to match, so it asks the media bridge for the Android version (`androidSdkProvider`), which the bridge already reports with the access level.

**Where it lives:** `app/lib/features/onboarding/view_models/onboarding_steps.dart` (the rules), `app/lib/platform/android_sdk.dart`, `app/lib/features/onboarding/views/access_step_screen.dart`, `notifications_step_screen.dart` and `step_layout.dart`. Tests: `app/test/features/onboarding/view_models/onboarding_steps_test.dart`, `access_step_screen_test.dart`, `notifications_step_screen_test.dart` and the screenshots in `access_step_golden_test.dart` and `notifications_step_golden_test.dart`.

**Try it yourself:** break the "Android will not ask again" rule and watch tests notice. From `app/`:

```bash
../tool/flutter test test/features/onboarding/view_models/onboarding_steps_test.dart
```

It ends with `All tests passed!`. Open `app/lib/features/onboarding/view_models/onboarding_steps.dart` and change `askedHere || !view.canAskAgain ? AccessStep.denied` to `askedHere ? AccessStep.denied`. Run it again: `accessStepFor denied, askedHere false, canAskAgain false is denied` fails (and so does the screen test that shows "Open settings"). Put it back.

**Decisions:** D-140 (all of this section), with D-68 and D-75 (the access controller), D-107 (asking for notifications once) and D-136 (the routes) as background.

## 8. Planning reels and finishing

**What we built:** the last step of onboarding, "What reels are you planning?". The user types the reels for their next trip or shoot (or taps an idea), sees them as a list, and taps **Create 3 reels**: the reels are made, onboarding is done, and the app opens on Reels. **Skip for now** finishes without making any.

- **One name at a time, with the reel form's rules.** Enter (or the round plus inside the field) adds the name and keeps the keyboard up for the next one. A blank, a name over 40 characters, a name already in the list in another case ("goa" after "Goa") and the name of a reel that already exists are all refused, with the same words the New reel sheet uses, under the field.
- **One write, then done.** Create makes all the reels in one database transaction (all or none) and only then marks onboarding done. A double tap makes one set.
- **A closed app never doubles the reels.** If the app is killed after the reels were made but before "done" was saved, the next open goes through the welcome again and lands on this step with the reels already there: the button says **Continue**, and typing the same names is refused as duplicates.

**Why TakeTray needs it:** an empty app is a blank page. Planning two or three reels first means the first clips the user shoots have somewhere to go, and the Home tip that follows can point at something real. The step has to be safe to run twice because Android can end the app at any moment.

**Key ideas:**

- **Order is the safety.** `create()` calls `createAll(names)` and waits for it, then `finish()`:

  ```dart
  await repository.createAll(names);
  // ... then
  await ref.read(onboardingControllerProvider.notifier).finish();
  ```

  Done first, the flag could be saved with no reels made. Reels first means the worst case is reels that exist while the flag does not, and that case is handled by reading the database (the "Continue" button), not by a second flag.
- **The database is the truth about what exists.** The step watches the reels (`watchAll`) itself instead of remembering "I created some". Anything that makes a reel, from any screen or an earlier run, shows up the same way. The repository's own duplicate check is still the backstop if a reel appears between the last read and the write.
- **A guard you can see.** `busy` is set before the first `await`, so the second tap of a double tap finds it set and returns. The buttons turn off from the same state.
- **Keeping focus.** The action key of the keyboard takes focus away. Asking for focus again from `onSubmitted` (on a `FocusNode` the field now accepts) keeps it, which is what makes typing several names in a row smooth.
- **A step with no picture.** `OnboardingStepLayout`'s picture is now optional; without it the words start 28 dp from the top.

**Where it lives:** `app/lib/features/onboarding/view_models/reels_step_controller.dart` (the rules), `app/lib/features/onboarding/views/reels_step_screen.dart`, `step_layout.dart`, and `TtTextField` in `packages/taketray_ui` (`focusNode`, `trailing`). Tests: `reels_step_controller_test.dart`, `reels_step_screen_test.dart` and the screenshots in `reels_step_golden_test.dart` (empty, three names, reels that exist, an error, and 2x text with the keyboard up).

**Try it yourself:** make Create finish before it creates, and watch a test notice. From `app/`:

```bash
../tool/flutter test test/features/onboarding/view_models/reels_step_controller_test.dart
```

It ends with `All tests passed!`. Open `app/lib/features/onboarding/view_models/reels_step_controller.dart`, and in `create()` add `unawaited(ref.read(onboardingControllerProvider.notifier).finish());` just before `await repository.createAll(names);`. Run it again: `createAll completes before finish` fails (and so do the tests that check the order of the two calls). Take the line out.

**Decisions:** D-141 (all of this section), with D-135 (`createAll`, `finish`), D-136 (the routes and the redirect), D-80 and D-84 (the reel name rules) as background.

## 9. The Home tip and the old first-time asks

**What we built:** after onboarding, the first time the user lands on Reels with Shooting mode off, a dark note sits under the Shooting mode card: "Going out to shoot? Turn on Shooting mode first. New videos will wait in To tag.", with a **Got it** button. The card has a soft yellow ring round it while the note shows. Tapping **Got it**, or turning Shooting mode on (with the very switch the note points at), makes it go away for good.

- **Shown from the flags alone.** The note shows when onboarding is done, the tip has not been seen and Shooting mode is off. Nothing in the last onboarding step "turns it on", so closing the app right after Create still shows it on the next open.
- **Gone once.** Got it writes "seen" one time. Turning Shooting mode on does the same, so a person who finds the switch first never sees the note later.
- **In the layout, not on top of it.** The note is the next item in the column under the card, right-aligned, with its arrow over the switch. It pushes the banner and the list down while it shows. Because it floats over nothing, it cannot block a tap, and the switch above it always works, even at 200 % text.
- **The first-time asks are still there.** Turning Shooting mode on still asks for video access (only when it was denied and Android can ask again) and for notifications (once ever). After onboarding has asked, those do nothing; if the user chose "Not now", the first turn-on asks once. Tests pin each case.

**Why TakeTray needs it:** a new user has nothing to shoot yet and the tray is empty; the one thing that makes the first shoot work is turning Shooting mode on before filming. A single, dismissible hint at the right moment does that without a tour.

**Key ideas:**

- **Derive, do not arm.** The tip is a function of three stored values (`done`, `homeTipSeen`, Shooting mode). Anything that "switches the tip on" at the end of a flow can be lost to a kill; a condition on stored state cannot.
- **Writing in `build` is not allowed.** Marking the tip seen when Shooting mode is on changes a provider, which must not happen while the tree builds, so it is done in a post-frame callback (the same lesson as the red screen in Phase 8). A tiny widget that is in the tree only while the mark is due queues it from `initState`, so it is queued once, not on every rebuild.
- **Wrap, do not extend.** The ring is outside the card, so a wrapper widget in the app draws it and the shared card in `taketray_ui` stays as it is, with no new package screenshots. The wrapper is always there (`active` says whether the ring shows): a widget that appears and disappears around the card would make Flutter rebuild the card from scratch each time.

**Where it lives:** `app/lib/features/shooting_mode/views/shooting_tip.dart` (`ShootingTip`, `ShootingCardHighlight`), `shooting_mode_section.dart` (the condition), `app/lib/l10n/app_en.arb`. Tests: `app/test/features/shooting_mode/views/shooting_tip_test.dart`, `shooting_tip_golden_test.dart` (Mac only), and the group "the old asks after onboarding" in `app/test/features/shooting_mode/view_models/shooting_mode_controller_test.dart`.

**Try it yourself:** make the tip show while Shooting mode is on. From `app/`:

```bash
../tool/flutter test test/features/shooting_mode/views/shooting_tip_test.dart
```

It ends with `All tests passed!`. In `shooting_mode_section.dart` change `final showTip = tipDue && shooting != null && !shooting.on;` to drop `&& !shooting.on`. Run it again: `Shooting mode on: no tip even while the flag cannot change` fails.

**Decisions:** D-142 (all of this section), with D-135 (the flags), D-141 (finishing arms nothing), D-107 and D-75 (the old asks) as background.

## 10. On the S24

**Draft: the phone run completes this section. What follows is what the run will check; the results are added after it.**

**What we built:** an on-device test for the whole first launch, and a list of hand checks for what a test cannot see. The test is `app/patrol_test/onboarding_test.dart`; the list is "Phase 10A check" in `docs/dev-setup.md`.

- **Four flows.** *Fresh phone*: welcome, Get started, Allow access, Android's "Allow all", All set, Continue, Allow notifications, Android's "Allow", a typed name and an idea, "Create 2 reels", Reels with the tip, Got it. *Manual mode*: "Don't allow", Continue in Manual mode, Not now, Skip for now, Reels with the banner. *Closed midway*: Get started, Back, a restart, the welcome's final frame. *The tip and the switch*: turning Shooting mode on with its own switch hides the tip.
- **Starts clean, ends clean.** Each flow deletes the first-launch rows from the app's own database before the app starts, so the flows can run in any order, and its tear-down deletes the reels it made and puts everything back, even when the flow failed.
- **A restart that is not a restart.** A test cannot kill its own app. The flow throws the widget tree away and builds a new app on the same database; the new app reads the flags from the file, like a relaunched one. A real kill, and the splash, are hand checks.
- **Phone safety.** Only TakeTray Dev. No videos, and nothing created or listed in `Movies/` (only the test folder's name as a setting); Android's dialogs are answered by their button ids, never their text; no screenshots; no user data printed.

**Why TakeTray needs it:** the first launch happens once, on a phone that has nothing. Unit and widget tests cover each piece; only the phone shows that the real permission dialogs, the real database and the real router work together in that order.

**Key ideas:**

- **Reset through the same door as the app.** The flows clear the flags through the app's database (the same table the repository writes), not through a shortcut, so a flag that is stored wrongly shows up in the flow.
- **Always run the tear-down.** The body's error is kept, the tear-down steps all run, and then the first error is thrown.
- **A hand check is a numbered question.** Each one says what to do and what you should see, so the answer can be a number and a few words.

**Where it lives:** `app/patrol_test/onboarding_test.dart`, `app/patrol_test/support/system_dialogs.dart` (the dialog buttons), `app/patrol_test/support/onboarded.dart` (what every other file uses), `docs/dev-setup.md` ("Phase 10A check").

**Try it yourself:** check that the file builds without a phone. From the repo root:

```bash
tool/patrol build android --target patrol_test/onboarding_test.dart --debug
```

It ends with `Completed building apk` and the two APK paths. Then open `app/patrol_test/onboarding_test.dart` and change `_reelA` to a name that does not start with `_reelPrefix`: it still builds, but the tear-down no longer deletes that reel, which is why both names come from the same constant. (Change it back.)

**Decisions:** D-143 (all of this section), with D-100 and D-131 (Patrol on the S24), D-136 (the onboarded harness) and D-137 to D-142 (what the flows check) as background.

**Phone results:** pending. The run, what each flow showed and what was changed are added here after it.
