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

## 4. The animated splash

## 5. The welcome's picture

## 6. The welcome intro

## 7. Video access and notification steps

## 8. Planning reels and finishing

## 9. The Home tip and the old first-time asks

## 10. On the S24
