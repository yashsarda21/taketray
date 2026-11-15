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

## 6. The welcome intro

## 7. Video access and notification steps

## 8. Planning reels and finishing

## 9. The Home tip and the old first-time asks

## 10. On the S24
