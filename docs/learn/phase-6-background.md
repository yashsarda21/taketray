# Learning guide: Phase 6, background detection and notifications

This guide explains how TakeTray notices new clips while it is closed, and how it reminds you without nagging: the new-clips notification, the evening reminder, the 14-day "Still shooting?" question, and what happens after a restart. It also covers the help screen for phones that stop apps in the background.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **The big picture first.** Until Phase 5, TakeTray only looked for new videos while it was open. Phase 6 adds a small piece of Android code that runs **without** the Flutter part of the app:
  - Dart keeps a **copy** of what that code needs (Shooting mode on or off, where each volume's scan stopped, the watched folders, the reminder settings) in Android's own storage;
  - an Android **job** wakes up when the phone's video library changes, counts the new videos 5 quiet minutes after the last one and posts one notification (one sound, then silent updates);
  - **alarms** fire the reminders;
  - the database stays Dart's alone: the only thing that flows back from Android is a button tapped in the notification shade.
- **Order.** The sections follow the order the phase was built, from Section 2 on. Step 1 was the plan and decision D-101 (what Phase 6 builds now and what waits), so it has no section here.
  - the design-system pieces (2);
  - the bridge between Dart and Android (3);
  - the new-clips job (4) and the reminders (5), in Kotlin;
  - Dart keeping the copy in step (6);
  - the screens: taps, the dialog, the permission and the help screen (7);
  - two media repairs parked from Phase 3 (8);
  - the proof on the phone (9).
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-101. "Spec §8.3" is a section of `docs/superpowers/specs/2026-10-24-taketray-v1-build-design.md`.
- **Commands.** Run them from the repository root, through the wrappers in `tool/` (`tool/flutter`, `tool/check`, `tool/test_android`). Run a single Dart test file from `app/` (`cd app && ../tool/flutter test test/...`).
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Expandable card, step list and the success callout](#2-expandable-card-step-list-and-the-success-callout)
3. [The background bridge, the native state store and launch actions](#3-the-background-bridge-the-native-state-store-and-launch-actions)
4. [The new-clips job and notification](#4-the-new-clips-job-and-notification)
5. [Reminders, shade actions and re-arming](#5-reminders-shade-actions-and-re-arming)
6. [Dart keeps the native copy in step](#6-dart-keeps-the-native-copy-in-step)
7. [Notification taps, Still shooting?, the permission and the help screen](#7-notification-taps-still-shooting-the-permission-and-the-help-screen)
8. [Parked media repairs](#8-parked-media-repairs)
9. [On the S24](#9-on-the-s24)

## 2. Expandable card, step list and the success callout

**What we built:** three small pieces in `packages/taketray_ui`, ready for the "Notifications not arriving?" help screen (Task 7):

- **`TtExpandCard`**: a card with a header (a title, an optional small label such as "Your phone", and an arrow) that opens to show whatever you put inside it. Tap the header and it opens or closes.
- **`TtStepList`**: a numbered list, "1.", "2.", "3.", with the text lined up so a long step wraps under its own words and not under its number.
- **`TtCallout(success: true)`**: the existing note box with a new green look, for good news such as "Your clips are never lost".

**Why TakeTray needs it:** some phones (Samsung, Xiaomi, Oppo and others) stop apps in the background to save battery, so the "new clips" notification can be late or missing. The help screen has one card per phone brand, each with the steps for that brand and a button that opens the right Android settings page. The brand that matches the phone gets a "Your phone" label. At the top, a green note tells you the clips are safe either way. Screens in TakeTray never draw their own boxes and colours; they use package components, so these three had to exist first.

**Key ideas:**

- **The card does not remember whether it is open.** The caller keeps that fact and passes it in. This is the usual Flutter way: the screen can then keep one card open at a time, which the help screen wants, and a test can set either state directly.

  ```dart
  TtExpandCard(
    title: 'Samsung',
    badge: 'Your phone',
    expanded: open == 'samsung',
    onToggle: () => setState(() => open = 'samsung'),
    child: const TtStepList(['Open Settings...', 'Tap Never sleeping apps...']),
  )
  ```

- **A closed card does not build its body at all.** `if (expanded) Padding(...)` is in the card's column, so there is nothing hidden: no text for a screen reader to find, and no cost. The test `collapsed card hides the body` checks that the body text is not in the tree.

- **A screen reader hears one button, with its state.** The header is a `Semantics` node that is a button, says whether it is `expanded`, and has a label made of the title and the badge. Its own parts (the arrow, the badge) are hidden from the screen reader so they are not read twice:

  ```dart
  Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    expanded: expanded,
    label: [title, ?badge].join(', '),   // "Samsung, Your phone"
    onTap: onToggle,
  ```

  `?badge` is Dart's "add this only if it is not null". TalkBack then says "Samsung, Your phone, expanded" or "collapsed", because the `expanded` flag is what makes Android say that word. Two tests guard it: `expand card reports expanded` and `badge is read with the title`.

- **At least 56 dp tall, and the whole header is the tap target.** The CSS says `min-height: 56px`. A `ConstrainedBox(minHeight: 56)` inside an `InkWell` makes the full-width header the touch area, comfortably over Android's 48 dp.

- **Large text needed three small changes the prototype never had to think about.** The prototype does not scale its text; real phones do (spec §7 rule 2, and every golden is drawn at 1x and 2x). At 2x on a 360 dp phone the "Your phone" label next to "Samsung" left the title so little room that it broke into "Samsu" and "ng". The first golden showed it. So from a text scale of 1.5 the label moves under the title:

  ```dart
  final badgeBelow = badgeChip != null &&
      MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
  ```

  The step list does the same kind of thing: its number column is 20 dp at 1x, and 20 times the text scale at larger sizes, so a bigger "1." never touches the text. The header also has a little padding above and below that the CSS does not have, which changes nothing at normal size (the 56 dp minimum is already taller) and keeps a two-line title away from the card's edge.

- **A list that is a list.** Flutter has semantic roles; the step list is marked `SemanticsRole.list` and each item `SemanticsRole.listItem`, and each item's label is one string, "1. Tap Never sleeping apps...", so the number is read together with its step and not as a separate "1." The number and the text are two `Text` widgets side by side (so the second line of a long step hangs under the text), and `excludeSemantics: true` hides them from the screen reader so only the joined label is read.

  ```dart
  Semantics(
    container: true,
    role: SemanticsRole.listItem,
    excludeSemantics: true,
    label: '${i + 1}. ${steps[i]}',
  ```

  The `i + 1` matters: the list is numbered from 1. A test (`step list numbers its items`) fails if the numbers start at 0.

- **The success look is two colours from the theme, and the icon takes the text's colour.** A normal callout paints its icon in the accent colour; a warning and a success paint it in the container's text colour (`.callout.ok .ms { color: inherit }`). `warning` and `success` together make no sense, so the constructor has an `assert`:

  ```dart
  assert(!(warning && success), 'A callout is a warning or a success, not both'),
  ```

  An `assert` runs in debug and test builds and stops the program there; the test `warning and success assert` checks that.

- **Tests that can fail.** The tests were written with the component, not strictly before it. To see them fail, the component was set aside and they were run: they failed to compile because the new names did not exist, which is a red at compile level only, not proof that each test checks a behaviour. That proof came afterwards: each of these changes was made alone, to see the right tests fail, and undone: the `expanded` flag removed from the semantics ("Expected: Tristate.isFalse, Actual: Tristate.none"), the step numbers started at 0 (`Found 0 widgets with text "3."`), the success callout painted in the plain container, the badge left out of the label ("Expected: 'Samsung, Your phone', Actual: 'Samsung'"), and the body always built.

**Where it lives:** `packages/taketray_ui/lib/src/components/expand_card.dart` (`TtExpandCard`), `step_list.dart` (`TtStepList`) and `banners.dart` (`TtCallout`, the `success` flag); the few sizes that are not in the shared tokens are in `lib/src/theme/tt_metrics.dart` (`expandCardHeaderMinHeight`, `expandCardBadgeRadius`, `expandCardBadgePaddingVertical`, `stepListGap`). Tests: `packages/taketray_ui/test/components/expand_card_test.dart`, `step_list_test.dart`, `banners_test.dart` and `expand_card_golden_test.dart`. Widgetbook (the catalogue of components): `widgetbook/lib/components/expand_card.dart`, `step_list.dart` and `banners.dart`.

**Try it yourself:** see the test notice a missing "expanded" flag. From the repo root:

```bash
(cd packages/taketray_ui && ../../tool/flutter test test/components/expand_card_test.dart --plain-name "expand card reports expanded")
```

It ends with `All tests passed!`. Now open `packages/taketray_ui/lib/src/components/expand_card.dart`, delete the line `expanded: expanded,` inside the `Semantics(...)`, and run the same command. It fails with `Expected: Tristate:<Tristate.isFalse>` and `Actual: Tristate:<Tristate.none>`: without the flag a screen reader cannot say "collapsed". Put the line back, and run it again to see it pass.

**Decisions:** D-102 (all of this section), with D-101 (Phase 6's scope) as background.

## 3. The background bridge, the native state store and launch actions

**What we built:** the pipe between Dart and the Android code that will run while TakeTray is closed, and the small store that Android code reads.

- **A contract** (`app/pigeons/background_api.dart`). Pigeon, the code generator TakeTray already uses for the media library (D-66), turns it into a Dart class and a Kotlin interface, so both sides agree on every message. Dart can call ten methods on Android; Android can call one method in Dart (`onLaunchAction`).
- **`BackgroundBridge`** in Dart (`app/lib/platform/background_bridge.dart`): the same calls in the app's own types (`BackgroundState`, `ShadeAction`, `NotificationAccess`, `LaunchAction`), plus a stream of "a notification asked to open this screen". Tests use `FakeBackgroundBridge` instead.
- **`BackgroundStateStore`** in Kotlin: Dart's copy of what the background code needs, kept in Android's preferences (a small key-value file).
- **Launch actions**: how a tapped notification says "open To tag" without letting any other app open any screen.
- **The notification permission**: whether TakeTray may post notifications, and Android 13's dialog to ask for it.

**Why TakeTray needs it:** when the app is closed, there is no Dart running, only a little Kotlin that Android wakes up (Task 4's job, Task 5's alarms). That Kotlin needs to know whether Shooting mode is on, where each volume's scan stopped, which folders to watch and when the reminders are. The database is Dart's, so Dart writes a **copy** for Kotlin at every app start and on every change. Going the other way, Kotlin only ever hands Dart two things: a "Still shooting?" button tapped in the notification shade, and the screen a notification tap should open. Dart then decides what to do with them.

**Key ideas:**

- **Dart is the truth; Kotlin keeps a mirror.** `writeState` stores the copy first, then "arms" the background work for it. The order matters: anything the arming starts reads the store, so it must already hold the new state. A test checks that the arming saw the new state already stored (`writeState stores then arms`).

  ```kotlin
  override suspend fun writeState(state: BackgroundStateMsg) =
      guardedOnIo("writeState", ::nativeError) {
          val next = BackgroundState.from(state)
          store.write(next)
          arming.apply(context, next)
      }
  ```

  `Arming` is a one-method interface. When this step was built `MainActivity` passed `Arming.NONE`, which does nothing; Section 4 gives it the job and Section 5 the alarms.

- **`commit()`, not `apply()`.** Android's preferences have two ways to save. `apply()` changes the values in memory at once and writes the file a little later; `commit()` writes the file before it returns. A receiver that Android wakes for a moment may have its process killed right after, so a late write could be lost. The store always uses `commit()`.

  Proving that took a trick. Under Robolectric (the Android simulator the tests run on, D-67) even `apply()` writes the file at once, so re-reading the file cannot tell the two apart. The tests give the store `ProcessPrefs`, a stand-in whose "disk" only `commit()` writes; `afterProcessEnd()` is a new process reading that disk:

  ```kotlin
  store.setPostedNewClips(7)
  assertEquals(7, BackgroundStateStore(afterProcessEnd()).postedNewClips())
  ```

  Change one `commit()` in the store to `apply()` and this fails with `expected:<7> but was:<0>`.

- **A broken copy means "off".** The state is one JSON object. If it is missing, of the wrong type or broken, `state()` returns `BackgroundState.OFF`: Shooting mode off, nothing to watch, no reminder. The worst a corrupt file can do is make the background code quiet until Dart writes again, never make it count everything as new.

- **A shade action names its session and its tap.** When "Turn off" is tapped in the shade, Task 5 stores a `ShadeAction` with `sinceMs` (which Shooting mode session it was for) and `atMs` (when it was tapped). After Dart has applied it, it calls `clearShadeAction(atMs)`, and the store only removes the action if it is **that same** tap. If the user tapped again in between, the newer tap stays for Dart:

  ```kotlin
  if (shadeAction()?.atMs == atMs) prefs.edit().remove(KEY_SHADE_ACTION).commit()
  ```

- **Launch actions, not routes.** `MainActivity` is "exported": the launcher (and so any app) may start it. Flutter can read a route from the intent that starts it (its "deep linking"), which would let any app open any screen. So deep linking is off in the manifest (`flutter_deeplinking_enabled` = false), and a notification sends one of two words instead, in an extra:

  ```kotlin
  private val VALUES = mapOf("toTag" to LaunchActionMsg.TO_TAG, "reels" to LaunchActionMsg.REELS)
  ```

  Anything else is ignored. Building this turned up a second door: Flutter also reads a `route` extra from any starting intent, deep linking or not, and go_router lets that route win over the app's own first screen. `MainActivity.getInitialRoute()` now returns null; the test `the route extra is ignored` failed with `expected null, but was:</settings>` before that line existed.

- **Read once.** Android can hand the same intent to the activity again: when it is re-created, when the user reopens the app from Recents (with the flag `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`), and after the process died (the activity comes back from "saved state" with its first intent). Each would open To tag again if the action were read twice. So `LaunchActions.read` removes the extra as it reads it, ignores the Recents flag, and `MainActivity` drops the action of a restored activity. The test `extra removed after reading` re-creates a real (simulated) activity with the same intent; with the removal taken out it fails with `delivered again after re-creation expected:<[]> but was:<[REELS]>`.

- **The tap that started the app comes first.** When a tap starts the app, Dart is not running yet, so Kotlin keeps the action. When Dart first listens to `launchActions`, the bridge sets up its listener for later taps and then asks for the kept one (`takeLaunchAction`). That first ask is also how Kotlin knows Dart is listening. A tap that arrives while the answer is on its way waits behind it, so the stream gives the start action first (`launch actions stream yields the start action first`). Because Kotlin keeps every tap until one ask has reached it, an ask that fails on the way would strand the taps until the app restarts, so the bridge asks again, up to three times 500 ms apart (the tests under `a take that fails`); only the last failure goes to the stream.

- **The notification permission has its own request code.** Android 13 added a permission for notifications, with a dialog like the one for videos. Both dialogs answer through the same `onRequestPermissionsResult`, so each request has a number: `0x7A71` for videos, `0x7A72` for notifications. `MainActivity` hands every answer to both bridges and each takes only its own. Below Android 13 there is no dialog, so asking just reports the state. After two "Don't allow" answers Android stops showing the dialog; the bridge remembers that, using the same rule as for videos (D-68), so the app can open Settings instead (Task 7).

- **Shared, not copied.** The rule for what an error may say (the method and the exception's class, never its message, which can hold a file path; D-10), the "one request at a time" helper and the "blocked" rule now live once, in `bridge/BridgeSupport.kt`, and both bridges use them.

**Where it lives:** the contract `app/pigeons/background_api.dart` and the generated `app/lib/platform/background_api.g.dart` and `.../background/BackgroundApi.g.kt`; Dart `app/lib/platform/background_bridge.dart`; Kotlin `app/android/app/src/main/kotlin/app/taketray/background/` (`BackgroundState.kt`, `BackgroundStateStore.kt`, `BackgroundHostApiImpl.kt`, `LaunchActions.kt`, `Arming.kt`), `bridge/BridgeSupport.kt` and `MainActivity.kt`; the manifest `app/android/app/src/main/AndroidManifest.xml`. Tests: `app/test/platform/background_bridge_test.dart` (and `app/test/support/fake_background_bridge.dart`), and `app/android/app/src/test/kotlin/app/taketray/background/` (`BackgroundStateStoreTest`, `BackgroundHostApiImplTest`, `LaunchActionsTest`, `ProcessPrefs`). The step-by-step flow is "Background bridge" in `docs/flow.md`.

**Try it yourself:** watch the store's test catch an `apply()`. From the repo root:

```bash
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.background.BackgroundStateStoreTest'
```

It ends with `BUILD SUCCESSFUL`. Now open `app/android/app/src/main/kotlin/app/taketray/background/BackgroundStateStore.kt`, change the `.commit()` in `setPostedNewClips` to `.apply()`, and run the same command. It fails: `posted count persists` says `expected:<7> but was:<0>`, because the count never reached the "disk" a new process reads. Put `.commit()` back and run it again to see it pass.

**Decisions:** D-103 (all of this section), with D-101 (no deep linking; launch actions) and D-68 (asking for a permission) as background.

## 4. The new-clips job and notification

**What we built:** the part of TakeTray that works while the app is closed and you are filming.

- **A job** (`NewClipsJobService`). Android's JobScheduler starts it 5 quiet minutes after the phone's video library last changed. It is plain Kotlin: no Flutter engine starts, and it never touches the database.
- **A counter** (`NewClipsCounter`) that asks the video library how many videos were added since the last scan the app made.
- **One notification** (`Notifier`): "3 new clips to tag", with the newest clip's thumbnail and two buttons, **Open camera** and **Tag now**. It is updated in place and never stacked; it sounds once when it appears and updates silently.
- **Arming** (`NewClipsArming`): the code that schedules the job when Shooting mode is on and removes it, and the notification, when it is off.

**Why TakeTray needs it:** while you shoot, TakeTray is closed. Without this, nothing would tell you that clips are waiting until you happened to open the app. The notification is a nudge for when you have stopped filming: it appears 5 minutes after your last clip and makes the normal notification sound once, later count changes are silent, it is never posted again for the same number, and it goes away when the number is 0, when Shooting mode goes off, or when the app has scanned. The app stays in charge: the job only **counts**; deciding which videos become clips is still the scan that runs when you open the app (spec §8.3, §11).

**Key ideas:**

- **A job that wakes on a change, not on a timer.** A JobScheduler job can wait for a content URI to change. TakeTray watches the whole external video collection, and asks Android to wait for 5 minutes of calm before starting it. Each new clip restarts the wait, so a burst of ten recordings, or a whole afternoon of shooting with short gaps, becomes one run, not ten:

  ```kotlin
  .addTriggerContentUri(
      JobInfo.TriggerContentUri(
          MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL),
          JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS,
      ),
  ).setTriggerContentUpdateDelay(UPDATE_DELAY_MS)
  .setTriggerContentMaxDelay(MAX_DELAY_MS)
  ```

  `MAX_DELAY_MS` is 7 days, on purpose. There is no "no maximum" in JobScheduler: if you leave the maximum out, Android uses its own default of 2 minutes (`JobStatus.DEFAULT_TRIGGER_MAX_DELAY`), and the job would run 2 minutes into a long shoot. A test fails if the call is removed. The value is not `Long.MAX_VALUE` because Android adds the delay to the clock, and that sum would overflow and fire at once. Two limits remain: Android runs the job at once when 40 different rows have changed, and the timer is on the "uptime" clock, which stops while the phone is in deep sleep, so a phone in a pocket may post later than 5 minutes (D-110). The first would break the promise "never in the middle of a shoot", so the run checks the quiet itself, as the next point says.

- **Such a job fires once, so every run arms the next.** After a content-trigger job runs, Android forgets it, and it cannot survive a reboot ("persisted"). So the run ends by scheduling its successor, and the app arms it again whenever Dart writes the state. There is a catch: while the job runs, Android still lists it as pending. The app's arming skips scheduling when an identical job is already pending (scheduling again would restart its watching), but if the job did the same it would see itself, skip, and disarm when it finished. So the job always schedules (`replace = true`); the test `the job re-arms even while its own job is listed` covers that.

- **Count only what the app would count, and never count everything.** The question is "how many videos have a higher generation than where the app's last scan stopped, in a watched folder, finished and not empty?":

  ```kotlin
  return "$selection AND ${MediaColumns.DURATION} > 0 AND ${MediaColumns.SIZE} > 0" to args
  ```

  A video still being recorded is "pending" (and has no duration yet), so it does not count until the camera finishes it. A generation is MediaStore's change counter, and it only means something together with the library's **version**: if the library is rebuilt, generations start again and "after 100" would be almost everything. So a volume whose version changed, a volume that is not mounted, and a volume with no baseline count 0:

  ```kotlin
  if (versionOf(baseline.volumeName) != baseline.version) continue
  ```

  Remove that line and the test `version change counts nothing` fails with `expected:<NewClips(count=1, ...)> but was:<NewClips(count=2, ...)>`.

- **Testing SQL the way Android runs it.** The counter's test does not fake the answer: `SqlVideoProvider` is a tiny video table in a real SQLite database, registered as the media provider. It runs each query's selection through a strict `SQLiteQueryBuilder`, set up as Android's media provider sets one up, and leaves out pending and trashed rows unless asked, as Android does. So a wrong clause, or SQL Android would refuse, fails the test.

- **Once, not twice: "same number, no post".** The store remembers the number the shade shows (`posted_new_clips`). The run posts only when the count changed:

  ```kotlin
  if (found.count == store.postedNewClips()) return state
  ```

  The notification itself uses a DEFAULT-importance channel (`new_clips_alert`: the normal sound or vibration), a fixed id (so posting again replaces it), and `setOnlyAlertOnce(true)`, which makes Android sound only when the notification first appears, not when a count update replaces it. A user who swipes it away and then films more hears it again, because nothing is showing. Android cannot raise the importance of a channel that already exists, so version 2 made a new channel and deletes the old silent one (`deleteNotificationChannel`). Whenever the notification is removed, the posted number goes back to 0, so the next real count posts again.

- **The run checks the quiet too, and a settle job waits for it.** When the job runs it looks at how old the newest new clip is: `now - max(DATE_ADDED, DATE_MODIFIED)`. A recording's row is added when it starts and modified when it ends, so a long recording that has just finished still counts as fresh. Under 5 minutes, it posts nothing and schedules a one-off *settle* job:

  ```kotlin
  JobInfo.Builder(JOB_ID, ComponentName(context, NewClipsSettleJobService::class.java))
      .setMinimumLatency(latencyMs)                           // what is left of the 5 minutes + 5 s
      .setOverrideDeadline(latencyMs + SETTLE_DEADLINE_SLACK_MS)
      .setPersisted(true)
  ```

  The settle job counts again under the same rule: a newer clip under 5 minutes old makes it schedule itself again; otherwise it posts once. It never re-arms the content trigger, because that would restart the content trigger's watch. The deadline is there because of how Android keeps the time: the latency is counted on a clock that runs in deep sleep, but the alarm for it does not wake the phone, while the deadline's alarm does. A clip that looks to be from the future (the clock was set back) is treated as fresh, and the wait is never more than 5 minutes from now. Edge cases the tests pin: 1 minute old waits about 4 minutes; exactly 5 minutes posts; 40 clips in a hurry post nothing; Shooting mode off cancels the settle job with the content job. The Patrol hook `runNewClipsJob` skips the rule, so only flow 1 waits.
- **A take in progress also holds the post.** A recording in progress is a *pending* row in MediaStore, and its insert is the only change until the camera finishes it. Without a check, the job would run 5 quiet minutes after that insert, count the earlier finished clips and sound in the middle of the take. So before posting the job asks for a pending row above the baseline, in a watched folder and touched in the last 3 hours (older ones are stuck rows from a crashed recording, and must not block for ever), and if one exists it settles in 5 minutes instead. A camera app that inserts its row only when the recording ends cannot be seen. Whether TakeTray can see another app's pending row was settled in the Android source: with the video permission a `MATCH_ONLY` pending query has no owner filter (D-110, 6c). A debug-only log line, `quiet-rule: recording=… freshMs=… posted=…`, lets the owner confirm it on the phone. A count that fails is not "no" either: the job asks again in 5 minutes. A clip dated more than a minute in the future (the clock was set back) is treated as having no time, so it cannot wake the phone every 5 minutes for days.
- **The evening reminder waits for the quiet too.** When its alarm fires while a clip is under 5 minutes old or a take is in progress, it is *deferred* to its own one-off job (own id, because the new-clips settle job is replaced by every new clip and is cancelled when Shooting mode goes off). The job posts when it is quiet, counting the clips at that moment. It posts only for the same evening: if the quiet comes after midnight it is skipped and counts as handled, so the reminder never says "today" for yesterday. The once-a-day mark is set only when it posts or is skipped. Switching the reminder off cancels the deferral; a reboot keeps the persisted job (and a re-arm makes it again if Android lost it).
- **Private on the lock screen.** The notification is `VISIBILITY_PRIVATE`, and Android shows its "public version" on a locked phone instead: "TakeTray" and "3 new clips to tag", with no thumbnail. The test `public version has no picture` checks that the public version has no picture and no large icon.

- **Taps are launch actions.** The body and **Tag now** open To tag with the allow-listed launch action from Section 3 (`LaunchActions.intent(context, LaunchActionMsg.TO_TAG)`). **Open camera** opens the phone's video camera directly. Every `PendingIntent` is immutable (no other app can change what it opens) and has its own request code, so none replaces another.

- **A thumbnail never costs a count.** Loading the picture can fail (the video is gone, a decoder breaks). The run then posts without a picture:

  ```kotlin
  } catch (e: Exception) {
      Log.w(LOG_TAG, "new clips thumbnail failed: ${e.javaClass.simpleName}")
      null
  }
  ```

- **Not allowed is not an error.** If notifications are off for TakeTray, or you blocked the "New clips" channel, the run posts nothing, throws nothing, and remembers 0, so the first run after you allow them posts.

- **Every run records the time zone.** Spec §8.3a keeps a list of the zones the phone was in, so a clip's local time is right after a trip. The job adds the current zone on every run (even when Shooting mode is off), one more chance to notice a change while the app was closed.

- **A scan in the app wins.** The job and the app can run at the same moment: you film, then open TakeTray while the job is counting. The app scans, moves the baselines and clears the notification, and a moment later the job would post the count it made before. So after updating, the run reads the state again and, if Dart wrote meanwhile, counts once more on the new baselines:

  ```kotlin
  val counted = update()
  if (store.state() != counted) update()
  ```

- **A run that fails still re-arms.** Every step catches its own errors and logs only the error's class (never a count, a folder or a path, D-10), so the run always gets to the re-arming. A failed count leaves the notification as it was; 0 would have removed it.

**Where it lives:** `app/android/app/src/main/kotlin/app/taketray/background/` (`NewClipsCounter.kt`, `NewClipsJobService.kt` with `NewClipsJob`, `Notifier.kt`, `Arming.kt` with `NewClipsArming`), `media/VideoQueries.kt` (`newClipsArgs`), `media/Thumbnails.kt` (`bitmap`), the copy in `app/android/app/src/main/res/values/strings.xml`, and the service in `AndroidManifest.xml`. Tests: `app/android/app/src/test/kotlin/app/taketray/background/` (`NewClipsCounterTest`, `NotifierTest`, `NewClipsJobServiceTest`, `ArmingTest`, and the `SqlVideoProvider` helper). The step-by-step flow is "New clips while TakeTray is closed" in `docs/flow.md`.

**Try it yourself:** watch a test catch a re-post. From the repo root:

```bash
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.background.NewClipsJobServiceTest'
```

It ends with `BUILD SUCCESSFUL`. Now open `app/android/app/src/main/kotlin/app/taketray/background/NewClipsJobService.kt`, delete the line `if (found.count == store.postedNewClips()) return state`, and run the same command. `same count does not re-post` fails with `expected:<[(external_primary, 2)]> but was:<[(external_primary, 2), (external_primary, 2)]>`: the second run with the same two clips loaded the thumbnail and posted again. Put the line back and run it again to see it pass.

**Decisions:** D-104 (all of this section), with D-101 (the private lock-screen version, what the count means) and D-103 (the mirror, `Arming`, launch actions) as background.

## 5. Reminders, shade actions and re-arming

**What we built:** the reminders, and the code that keeps the background work alive across restarts. All of it is plain Kotlin that Android wakes up while TakeTray is closed.

- **Reminder times** (`ReminderTimes`): pure date arithmetic for "the next 21:00 here" and "the first 10:00 after 14 days".
- **Two alarms** (`ReminderScheduler`): the **evening reminder** ("You shot 3 clips today. Tag them?") and, 14 days into a Shooting mode session, **"Still shooting?"**.
- **A receiver for the alarms** (`ReminderReceiver`, with the work in `Reminders`): it counts today's clips or checks the session, and posts.
- **A receiver for the shade buttons** (`ShadeActionReceiver`): Still shooting?'s **Turn off** and **Keep on** work right in the notification shade, without opening the app. (On Samsung's One UI the buttons show once the notification is expanded: the S24 folded it away even when it was TakeTray's only notification, and groups it under another TakeTray notification. Tapping the body opens Reels, where the app asks, and that always works.)
- **Re-arming** (`BootReceiver`, and `TimeZoneChangedReceiver` from Phase 3): after a reboot, an app update, a clock change or a time-zone change, everything is armed again.

**Why TakeTray needs it:** a creator who shoots all day should get one gentle nudge in the evening to tag what they shot, and nothing on a day they shot nothing. Shooting mode sends every new video to To tag, so leaving it on for weeks by accident would fill To tag with holiday videos: after 14 days TakeTray asks once whether you are still shooting. Android forgets alarms and jobs at a reboot, and the reminder times are local times, which move when you fly or the clocks change, so all of it must be armed again at the right moments.

**Key ideas:**

- **Time in the phone's local day, with `java.time`.** "21:00" is a wall-clock time, not a fixed number of hours. `ReminderTimes.nextEvening` walks forward one local date at a time and returns the first 21:00 that is **strictly after** now:

  ```kotlin
  while (true) {
      val at = instantAt(date.atTime(time), zone)
      if (at.isAfter(now)) return at.toEpochMilli()
      date = date.plusDays(1)
  }
  ```

  Twice a year a local time can be missing or come twice. When the clocks go forward, 01:30 does not exist, so the reminder fires at the first instant after the gap; when they go back, 01:30 comes twice, and only the first counts:

  ```kotlin
  val rules = zone.rules
  if (rules.getValidOffsets(local).isEmpty()) return rules.getTransition(local).instant
  return ZonedDateTime.ofLocal(local, zone, null).toInstant()
  ```

  "Strictly after" is what makes the reminder fire once: when the alarm fires at 21:00 and arms the next one, 21:00 today is not after now, so it arms tomorrow's. Change `isAfter` to "not before" and four tests fail, among them `next evening after the time passed is tomorrow` with `expected:<2026-11-0[6]T21:00:00Z> but was:<2026-11-0[5]T21:00:00Z>`.

- **"Still shooting?" waits for the morning.** It is due 14 × 24 hours after Shooting mode went on, but a notification at 03:00 would be rude, so `stillDueAt` moves it to the first 10:00 at or after that moment. On at 03:00 on 1 November gives 10:00 on 15 November; on at 15:00 gives 10:00 on the 16th.

- **Inexact alarms, on purpose.** Both reminders use `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, …)`:

  ```kotlin
  alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, maxOf(armedFor, nowMs), eveningAlarm(context))
  ```

  `RTC_WAKEUP` is a wall-clock time that wakes the phone; "allow while idle" lets it fire in Doze, Android's deep sleep. It is **inexact**: Android may deliver it a little late to save battery, never early. An exact alarm needs a special permission (`SCHEDULE_EXACT_ALARM`, which Android 14 no longer grants by default, or `USE_EXACT_ALARM`, which Google Play allows only for alarm-clock and calendar apps), and a reminder to tag clips does not need to-the-second timing. WorkManager, the usual library, is ruled out too (D-101): it adds two permissions TakeTray forbids, and it cannot fire at a wall-clock time.

- **Arm the next evening first.** When the evening alarm fires, the receiver first notes which evening the alarm stood for (read before re-arming, which moves it on), then arms the next one, so nothing that fails later (a broken count, a failed post) can lose it. `firing = true` says "this is the alarm itself": always the next evening strictly after now.

  ```kotlin
  // Read before re-arming, which moves it to the next evening.
  val evening = ReminderTimes.dueEvening(store.eveningArmedFor(), nowMs, state.eveningMinutes, zone) ?: nowMs
  scheduler.armEvening(state, nowMs, firing = true)
  if (!state.eveningEnabled) {
      notifier.cancelEvening()
      return
  }
  ```

  The test `evening re-arms before posting` makes the post throw and checks that tomorrow's alarm is set.

- **A late alarm must not be pushed to tomorrow.** Because the alarm is inexact, 21:00 can pass before Android delivers it. Anything that re-arms in that window (you open the app at 21:01, the phone corrects its clock, TakeTray updates, a reboot) would see that 21:00 has passed and arm tomorrow's in its place, and today's reminder would be lost. But firing "whenever 21:00 has passed" is wrong too: a fresh install opened at 21:30, or the reminder switched on late, would then ring at once while you are looking at the app. So the store remembers which evening the alarm stands for, and a re-arm catches up only an alarm that is **due** (armed for tonight's evening once its time has passed, or for last night's evening just after midnight, a 23:30 alarm still on its way at 00:05), at most 3 hours after that evening (`EVENING_CATCH_UP`), and not handled yet:

  ```kotlin
  val due = ReminderTimes.dueEvening(store.eveningArmedFor(), nowMs, state.eveningMinutes, zone)
  val catchUp =
      due?.takeIf {
          !firing &&
              nowMs - it <= ReminderTimes.EVENING_CATCH_UP.toMillis() &&
              store.eveningHandledDay() != ReminderTimes.localDay(it, zone)
      }
  val armedFor = catchUp ?: ReminderTimes.nextEvening(nowMs, state.eveningMinutes, zone)
  ```

  Three hours is long enough for a late delivery and short enough that a phone that died before 21:00 and boots at 08:00 the next morning does not ring about the evening before. Remove the bound and `a boot the next morning does not post yesterday's evening` fails with `expected:<2026-11-06T[21]:00:00Z> but was:<2026-11-06T[08]:00:00Z>`.

  The alarm then fires at the later of `armedFor` and now, and the store keeps `armedFor`: on a catch-up that is still tonight's 21:00, not the 21:01 it fires at, so a second re-arm before it fires catches up again instead of pushing it to tomorrow. Pretend every passed evening was armed (pass `eveningToday(…)` instead of `store.eveningArmedFor()`) and `turning the reminder on after the time passed waits for tomorrow` fails with `expected:<2026-11-0[6T21:0]0:00Z> but was:<2026-11-0[5T21:3]0:00Z>`: switched on at 21:30, it would have rung at once.

  The handled mark names the day of the evening the alarm stood for, not the day it was delivered. The receiver marks it before it counts, whether it posts or not, so a reboot just after the evening has run still arms the next one, and two alarms for one evening do the work once. A 23:30 alarm delivered at 00:15 marks and counts the 5th, and the 6th's 23:30 still runs; mark the delivery day instead and `an evening alarm delivered after midnight counts its own day and tomorrow still fires` fails with `expected:<20762> but was:<20763>` (the 6th's day number where the 5th's belongs). The mark means "handled", not "posted", on purpose: a quiet day (nothing shot) would otherwise never be marked.

- **Only clips shot that day.** The count is the clips that wait in To tag (Dart's list in the copy) plus the ones the app has not scanned yet (Section 4's counter), shot since the start of the evening's local day (usually today; yesterday for a late alarm after midnight):

  ```kotlin
  val since = ReminderTimes.startOfToday(evening, zone)
  val waiting = state.waitingShotMs.count { it >= since }
  val count = waiting + counter.count(state).shotMs.count { it >= since }
  ```

  With none, nothing is posted, even if older clips wait (the owner's ruling): "You shot 0 clips today" is not a reminder anyone wants. And at most one per evening: the store remembers the day of the evening it last handled, so moving the clock back or flying west does not bring a second one.

- **It leaves the shade when it stops being true.** Android removes a notification when you tap its body, but not when you tap one of its buttons, so **Tag now** alone would leave "You shot 3 clips today. Tag them?" hanging after you tagged everything, and into the next morning. So `Notifier.cancelEvening()` is called when:
  - the reminder is switched off, or no clip shot today waits any more (checked at every arming, so tagging the last one removes it, and the next day's first write removes yesterday's; it asks the library only while the reminder is showing, and a failed check keeps it);
  - the next evening's alarm finds nothing shot that day, or the reminder off;
  - To tag opens from any notification (the launch action `toTag`).

  The alarm itself does not take part in the first rule, so it never removes the reminder it is about to post. The tests are in `EveningReminderRemovalTest` (for example `tagging the last of today's clips removes the evening reminder`, `the next day's first write removes yesterday's reminder`) and, for the launch action, `LaunchActionsTest`.

- **Once per session.** Every app start writes the copy and re-arms, and once 14 days have passed the still alarm would be due "at once" every time. So the receiver marks the session as handled **before** it posts, and arming skips a handled session:

  ```kotlin
  if (store.stillPostedSince() == sinceMs) return
  store.setStillPostedSince(sinceMs)
  notifier.showStillShooting(sinceMs)
  ```

  The test `still posts once per session, even after a reboot` swipes the notification away, reboots, and checks that nothing comes back.

- **A shade button names its session.** **Turn off** and **Keep on** are broadcasts that carry the `sinceMs` of the session they were posted for. If Shooting mode was turned off and on again since, that is a different session, and the old button must not turn off the new one. So the receiver acts only when the session still matches; otherwise it just removes the notification:

  ```kotlin
  if (since == null || !state.shootingOn || state.sinceMs != since) {
      notifier.cancelStillShooting()
      return@inBackground
  }
  ```

- **Turn off without the app.** No Dart runs, and the database is Dart's alone. So the receiver writes down what happened and lets Dart apply it at the next start (Section 6): a shade action with the session, the time of the tap and, for each mounted volume (with a baseline or without one, such as a card inserted mid-session), the library's current generation (so clips shot after the tap stay out). Then it writes the copy as off (no session and no baselines, the same as Dart's own off), which stops the job. If an "on" write from the app was already on its way, the store notices the waiting Turn off for that session and keeps the copy off (`writeFromApp`, tests `an on write after a pending Turn off for the same session stays off` and `an on write for a newer session than the Turn off is written`). In the same way the app's own writes do not arm a Still shooting? alarm for a time that has already passed (the in-app dialog asks, so the notification never posts under it): `an app write after Still shooting is due arms no still alarm`. The "N new clips" notification **stays**: those clips are real and still arrive when you open the app.

  ```kotlin
  Receivers.arming().apply(context, off, keepNewClips = true)
  ```

  Everywhere else (turning Shooting mode off in the app, a reboot), arming with Shooting mode off removes that notification, as Section 4 described; the test `the app's own off write still cancels the new clips notification` keeps that true.

- **Only TakeTray can ring these bells.** The reminder and shade receivers are not exported and have no intent filter, so no other app can send them anything; the alarms and the buttons are TakeTray's own explicit, immutable `PendingIntent`s. The manifest test `receivers are not exported` checks it:

  ```xml
  <receiver
      android:name=".background.ReminderReceiver"
      android:exported="false"/>
  ```

- **Re-arming after a restart.** `BootReceiver` listens for `BOOT_COMPLETED` (a reboot), `MY_PACKAGE_REPLACED` (TakeTray was updated) and `TIME_SET` (the clock was changed). Each arms everything again for the stored copy. A zone change (`TimeZoneChangedReceiver`) records the zone, as before, and re-arms with the zone named in the broadcast, so 21:00 is 21:00 where you landed. A reboot at 21:05 arms tomorrow's 21:00 if tonight's has already run, fires tonight's at once if it was armed for tonight and has not run (the phone was off at 21:00), and waits for tomorrow if nothing was armed for tonight. A boot more than 3 hours after the evening (the next morning) waits for the next evening too.

- **Testing alarms as Android fires them.** The tests do not call the receiver's code by hand only: `ReminderTestSupport.fire` takes the alarm Robolectric recorded and sends its `PendingIntent`, which delivers the broadcast to the receiver declared in the manifest. So a wrong action, a wrong component or a missing manifest entry fails a test.

**Where it lives:** `app/android/app/src/main/kotlin/app/taketray/background/` (`ReminderTimes.kt`, `ReminderScheduler.kt`, `ReminderReceiver.kt` with `Reminders`, `ShadeActionReceiver.kt`, `BootReceiver.kt`, `Receivers.kt`, `Arming.kt` with `ReminderArming`, `Notifier.kt`), `media/TimeZoneChangedReceiver.kt`, the copy in `app/android/app/src/main/res/values/strings.xml`, the receivers and `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml`, and `tool/check_release_permissions`. Tests: `app/android/app/src/test/kotlin/app/taketray/background/` (`ReminderTimesTest`, `ReminderSchedulerTest`, `ReminderReceiverTest`, `ShadeActionReceiverTest`, `BootReceiverTest`, `ReminderTestSupport`) and `app/android/app/src/test/kotlin/app/taketray/ManifestTest.kt`. The step-by-step flows are "Reminders" and "Re-arming" in `docs/flow.md`.

**Try it yourself:** watch a test catch a shade button from an old session. From the repo root:

```bash
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.background.ShadeActionReceiverTest'
```

It ends with `BUILD SUCCESSFUL`. Now open `app/android/app/src/main/kotlin/app/taketray/background/ShadeActionReceiver.kt`, delete ` || state.sinceMs != since` from the session check, and run the same command. `shade action for another session only cancels` fails with `expected null, but was:<ShadeActionMsg(kind=TURN_OFF, ...)>`: an old notification's Turn off would have ended the new session. Put it back and run it again to see it pass.

**Decisions:** D-105 (all of this section), with D-101 (no WorkManager, inexact alarms, the copy), D-103 (the copy and shade actions) and D-104 (the job, `Arming`, the count) as background.

## 6. Dart keeps the native copy in step

**What we built:** the Dart half of the background work. Sections 3 to 5 built Kotlin code that runs while TakeTray is closed and reads a copy of the state Dart keeps for it. This section keeps that copy right, and brings back what the shade's buttons did.

- **`BackgroundSync`** writes the copy: Shooting mode, its start, the baselines, the watched folders, the evening reminder, when the waiting clips were shot, and whether "Still shooting?" was answered. It writes at every app start and after every change.
- **`ShadeActions`** applies a **Turn off** or **Keep on** tapped in the shade, only to the Shooting mode session it was for. **Every scan** does the same first, inside its own job, so no trigger can scan past a Turn off.
- **The capped end** (`MediaScanner._endCapped`) is Turn off in Dart: it adds the clips shot before the tap, none after it, then switches Shooting mode off. Every scan runs it first when a Turn off is waiting.
- **`stillAnswered`** is a new field of the stored session; `stillShootingDue` says when the in-app question is due (Task 7 shows it).
- **The lifecycle**, after a scan, writes the copy before it removes the "N new clips" notification.

**Why TakeTray needs it:** the Kotlin side can only count and remind with what the copy says. If the copy says Shooting mode is on after the user turned it off, the phone keeps watching; if it holds yesterday's baselines, the notification counts clips the app has already shown in To tag. And a Turn off tapped in the shade only writes a note, because the database is Dart's alone (D-103): until Dart applies it, the clips shot before the tap are not in To tag and the database still says on.

**Key ideas:**

- **Streams say *when*, the database says *what*.** `BackgroundSync` listens to three streams (Shooting mode, the settings, the waiting clips' shot times), but it never writes what they delivered. Each write reads the database when it starts. Two streams can deliver out of step: new clips can arrive before the moved baseline, so a state built from the events could pair old baselines with new clips. Reading at write time cannot.

- **One write at a time, and only the newest.** A change while a write runs only sets a flag, so ten quick changes cost one more write, of the state as it is then:

  ```dart
  void _request() {
    if (_idle != null) {
      _again = true;
      return;
    }
    _idle = Completer<void>();
    unawaited(_loop());
  }
  ```

- **A shade action first, then the write.** Every write starts with `ShadeActions.apply()`. Then it looks again for a Turn off still waiting for this session (its end could not finish), reads the state, and writes only what differs from the last state the phone took:

  ```dart
  final waiting = await _bridge.pendingShadeAction();
  final shooting = await _phone.loadShooting();
  var state = await _read(shooting);
  if (waiting?.kind == ShadeActionKind.turnOff &&
      shooting.isSession(waiting!.since)) {
    state = state.copyWith(
      shootingOn: false,
      since: null,
      baselines: const {},
      stillAnswered: false,
    );
  }
  if (state == _written) return;
  ```

  Why the apply comes first: say you tap Turn off in the shade while TakeTray is open. The receiver writes the copy "off", but the database still says on. Tag one clip and a plain write would send "on" back, re-arming the job you just turned off. Applying first ends the session, so the write says off. If the end could not finish (a volume did not answer), the session stays on in the database for another try, and the copy still says off. The apply's own changes ask for one more write, which finds no action and nothing new: no loop. Just after the compare, `_written = null` comes before the write: if the write fails, the phone may hold part of it, so the next state is written even if it equals the last good one. The first write after `start()` has no last state, so every app start writes the copy and re-arms the job and the alarms.

- **A session is named to the millisecond.** The phone keeps `sinceMs`; Dart's stored `since` keeps a real clock's microseconds. Comparing them exactly would mean no shade button ever matched on a real phone. The tests' fixed clocks usually have whole milliseconds, so the tests named `a session stored with microseconds matches the tap` set some on purpose. So `ShootingState.isSession` compares milliseconds:

  ```dart
  return on &&
      mine != null &&
      mine.millisecondsSinceEpoch == since.millisecondsSinceEpoch;
  ```

  A tap for another session (Shooting mode was turned off and on again since the notification came) is dropped and cleared. Clearing names the tap's own time, so a newer tap waits.

- **Turn off stops at the tap.** The receiver noted each volume's generation at the tap. The capped end runs the scan's own per-volume code (shared, not copied) with that generation as a cap:

  ```dart
  final captured = cap == null
      ? volume.generation
      : min(volume.generation, cap);
  ```

  Rows above `captured` are left out, and the baseline never moves past it. Then, in the same job on the media queue, Shooting mode goes off, but only if it is still that session (`PhoneStateRepository.endSession`, compare-and-set). A volume that does not answer keeps the session and the action, so the next trigger tries again. A failure counts only 5 minutes or more from the last counted one (`endRetryGap`, by the clock, on either side, so a clock set back by an hour does not hold the count off until it catches up): one app start can try the end three times within a second (the copy's write, the lifecycle's scan, To tag's), and that must not count as three. The third counted failure, at least 10 minutes after the first, ends the session with what could be read (`maxEndAttempts`), so a broken SD card cannot keep Shooting mode on forever. Without full access it ends at once: nothing could be read anyway. A recording still pending at the tap is not added: it holds the baseline, and the session is gone before it finishes.

- **Every scan looks first.** The lifecycle's scan is not the only one: To tag scans when it opens and on resume, and a notification can open To tag before the lifecycle's first frame. A scan joins the media queue at once, so an apply queued separately could come too late, after a scan that added the clips shot after the tap. So the check lives inside the scan's own queued job:

  ```dart
  final ShadeAction? action;
  try {
    action = await _shade.pendingShadeAction();
  } on Object catch (e) {
    _log.warning(
      'Scan deferred: the shade action was not read (${e.runtimeType})',
    );
    return const ScanDeferred();
  }
  if (action != null) {
    final ended = await _applyShade(action);
    if (ended != null) return ended;
  }
  return await _scanOnce();
  ```

  A Turn off for this session replaces the scan with the capped end; a Keep on is stored and the scan runs; an action for another session is cleared and the scan runs. If storing a Keep on or clearing a stale action fails, that is logged and the scan still runs: only a Turn off may hold a scan back. When the action cannot be read, nothing at all is scanned (`ScanDeferred`), because a scan that cannot see a waiting Turn off could add a clip shot after it; the next trigger tries again. `ShadeActions.apply()` is the same path without the scan (the copy's writes use it; the lifecycle no longer needs it), one job on the same queue, and no job ever waits for another (that would deadlock the queue; the test `no queue job waits on another` would time out).

- **Write, then clear.** After a scan the lifecycle removes the notification, but first it flushes the copy. The flush reads the database itself, so it does not wait for the streams:

  ```dart
  // A volume that failed may still hold clips the job counts.
  if (scanned is! ScanDone || scanned.failedVolumes.isNotEmpty || !mounted) {
    return;
  }
  await guarded(
    _log,
    'Writing the background copy',
    () => ref.read(backgroundSyncProvider).flush(),
  );
  ```

  In the other order, a job could run between the clear and the write, count from the old baselines, and post the clips you are looking at again. Only a scan that read every volume clears (an end from the shade counts as one): with Shooting mode off, no access, a deferred scan or a volume that failed, the notification is left alone (and after a shade Turn off, the copy written "off" removes it).

- **`stillAnswered` lives in the session.** It is part of the stored `ShootingState`, so `advanceBaseline` keeps it (`copyWith`), turning Shooting mode off forgets it, and JSON stored before it existed reads as false. `stillShootingDue` is on, not answered, and at least 14 × 24 hours since the start, the same wait as the phone's `STILL_AFTER_DAYS`.

**Where it lives:** `app/lib/data/background/` (`background_sync.dart`, `shade_actions.dart`), the gate, `applyShadeAction` and the capped end in `app/lib/data/media/media_scanner.dart`, `markStillAnswered` and `endSession` in `app/lib/data/repositories/phone_state_repository.dart`, `watchPendingShotTimes` in `clips_repository.dart`, `ShootingState.stillAnswered` and `isSession` in `app/lib/domain/models/media.dart`, `app/lib/domain/rules/still_shooting.dart`, the order in `app/lib/app/media_lifecycle.dart`, and `start()` in `app/lib/app.dart`. Tests: `app/test/data/background/`, `app/test/data/media/media_scanner_end_session_test.dart`, `app/test/data/media/media_scanner_shade_gate_test.dart`, `app/test/domain/rules/still_shooting_test.dart`, and additions to `phone_state_repository_test.dart`, `clips_repository_inbox_test.dart`, `media_lifecycle_test.dart` and `app_test.dart`. The step-by-step flows are "Background bridge", "Finding new clips" and "App start and resume" in `docs/flow.md`.

**Try it yourself:** see the cap keep a clip shot after the tap out of To tag. From `app/`:

```bash
../tool/flutter test test/data/media/media_scanner_end_session_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/data/media/media_scanner.dart`, replace the three lines that set `captured` in `_scanAfter` with `final captured = volume.generation;`, and run the same command. `clips shot after the tap are not added` fails with ``Which: has `added` with value <4>``: the two clips shot after the tap were added too. Put the lines back and run it again to see it pass.

**Decisions:** D-106 (all of this section), with D-103 (the mirror, shade actions), D-104 (what the count means, the clear) and D-105 (Turn off and Keep on in the shade) as background.

## 7. Notification taps, Still shooting?, the permission and the help screen

**What we built:** the screens on top of Sections 3 to 6.

- **A tap on a notification** opens the right screen: **To tag** for the new-clips notification and the evening reminder, **Reels** for "Still shooting?".
- **The "Still shooting?" dialog** in the app, on the Reels screen, after 14 days of Shooting mode.
- **The notification permission**, asked once, the first time Shooting mode is turned on, and from a row in Settings after that.
- **The help screen** "Notifications not arriving?", with steps for Samsung, Xiaomi, Oppo, Vivo and OnePlus.
- **Two Settings rows** (Help and Notifications) that Phase 10 will grow around.

**Why TakeTray needs it:** a notification is only useful if its tap goes somewhere sensible, and the 14-day question must not be asked twice. The phone may post the notification at about the time the app opens, and the user may already have answered it in the shade. The permission is easy to get wrong: ask at the wrong moment and people refuse; Android stops showing its dialog after two refusals, so after that only the phone's settings can help. And some phones kill apps in the background, so the notification arrives late; the help screen says what to change on each.

**Key ideas:**

- **A tap is a name, not a route.** Android never sends a path. It sends one of two names, and Dart turns each into a screen with a `switch`, so no other app can make TakeTray open an arbitrary location:

  ```dart
  String routeFor(LaunchAction action) => switch (action) {
    LaunchAction.toTag => Routes.toTag,
    LaunchAction.reels => Routes.reels,
  };
  ```

- **One listener, for the life of the app.** The tap stream is broadcast: an event that arrives while nobody listens is gone. So the listener is not on a screen (a screen can be rebuilt or closed) but in a widget above the navigator, which listens once and stops only when the app is taken down:

  ```dart
  _subscription = ref
      .read(backgroundBridgeProvider)
      .launchActions
      .listen(_open, onError: _failed);
  ```

  The tap then goes to the router after the current frame (`scheduleMicrotask`), because the tap the app was started with can arrive while the first frame is still being built:

  ```dart
  void _open(LaunchAction action) {
    scheduleMicrotask(() {
      if (!mounted) return;
      ref.read(appRouterProvider).go(routeFor(action));
    });
  }
  ```

- **Ask only when the user is looking at Reels.** This needs three questions, because there are three ways for something to be on top. A hidden tab and a page that covers the whole screen (the tag player) turn Flutter's "ticker mode" off for the screen below. A page pushed inside the Reels tab (a reel's page) makes Reels' own route no longer the current one of its navigator. But a **sheet or a dialog** (the New reel form, "Delete reel?") is pushed on the root navigator and covers nothing: the screen under it keeps its tickers and its route. The first version of this checked only the tickers, and a resume with the New reel sheet open would have stacked "Still shooting?" over it. The only way to know is to watch the navigators, so `PopupRouteTracker` keeps the set of open `PopupRoute`s (sheets and dialogs are popup routes), fed by a `NavigatorObserver` on the root navigator and on each tab's:

  ```dart
  void _add(Route<dynamic>? route) {
    if (route is PopupRoute && _open.add(route)) notifyListeners();
  }

  void _remove(Route<dynamic>? route) {
    if (route != null && _open.remove(route)) notifyListeners();
  }
  ```

  `StillShootingPromptHost` puts the three together, checks after the first frame, on every resume and whenever the screen in front goes away, and never opens over anything:

  ```dart
  bool get _inFront => _screenInFront && !_popups.isOpen;
  ```

  ```dart
  final inFront =
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  ```

  When a popup closes, the host hears it and checks again, so the dialog is not lost; it still shows at most once per app session (next point). A menu (`TtMenuButton`) is an overlay, not a route, so the tracker does not see it; the menus the app has are on To tag and on a reel's page, which already cover Reels.

- **Once, and never twice.** The question is asked at most once per app session, and not at all if the user answered in the shade. The answer in the shade is a note that the scan has not applied yet, so the check reads that note first and the database after it. The scan stores a Keep on and then clears the note: if the note is gone, its effect is already stored. Reading in the other order could miss it:

  ```dart
  final ShadeAction? waiting;
  try {
    waiting = await bridge.pendingShadeAction();
  } on Object catch (error) {
    _log.warning(
      'Reading the shade action failed: ${error.runtimeType}; not asking',
    );
    return null;
  }
  final current = await _ref
      .read(phoneStateRepositoryProvider)
      .loadShooting();
  final since = current.since;
  if (since == null || !stillShootingDue(current, now)) return null;
  if (waiting != null && current.isSession(waiting.since)) {
    _log.info('Still shooting? was answered in the shade; not asking');
    return null;
  }
  _claimed = true;
  return since;
  ```

  The other order needs no code of its own: the answer in the app is stored (`markStillAnswered`), `BackgroundSync` copies it to the phone, and the phone cancels its notification (Sections 5 and 6).

- **Back means "keep it on".** The dialog returns `true`, `false` or `null` (Back, or a tap outside). Only an explicit **Turn off** turns Shooting mode off, so nobody switches it off by accident. And "Shooting mode off" is shown only if it is true: `setOn` never throws, so `turnOff()` reads the state back and says whether Shooting mode is really off.

- **Ask for the permission once.** The phone-state key `notificationsAsked` is written **before** the question, so a question that was cut short (the app closing) is not asked again. A second call at the same moment joins the first:

  ```dart
  Future<void> askOnce() {
    final running = _asking;
    if (running != null) return running;
    final next = _askOnce().whenComplete(() => _asking = null);
    return _asking = next;
  }

  Future<void> _askOnce() =>
      guarded(_log, 'Asking for notifications', () async {
        final bridge = ref.read(backgroundBridgeProvider);
        final phone = ref.read(phoneStateRepositoryProvider);
        final call = ++_latest;
        final access = await bridge.notificationAccess();
        if (access.sdkInt < _permissionSdk || access.granted) return;
        if (await phone.notificationsAsked()) return;
        await phone.markNotificationsAsked();
        _publish(call, await bridge.requestNotificationAccess());
      });
  ```

  `sdkInt < 33` is "below Android 13", which has no dialog. `guarded` (Section 6) means a failure is logged by type and never stops Shooting mode from turning on.

- **A provider nobody listens to is paused.** The prompt reads Shooting mode from a controller built on a stream. In Riverpod 3 such a provider is paused while no one listens, so the first value never comes and the check hangs. While it waits, the prompt listens itself:

  ```dart
  final subscription = _ref.listen(shootingModeControllerProvider, (_, _) {});
  ```

  A test that read the controller without a listener timed out; that is how this was found.

- **Brands, not makers.** Phones from many makers share a few Android skins, so a few sets of steps cover them. The whole name has to match (`samsungx` is nobody), and the maker is never logged because it says which phone someone has:

  ```dart
  PhoneBrand? brandOf(String maker) => switch (maker.trim().toLowerCase()) {
    'samsung' => PhoneBrand.samsung,
    'xiaomi' || 'redmi' || 'poco' => PhoneBrand.xiaomi,
    'oppo' || 'realme' => PhoneBrand.oppo,
    'vivo' || 'iqoo' => PhoneBrand.vivo,
    'oneplus' => PhoneBrand.oneplus,
    _ => null,
  };
  ```

- **The user's card is open, unless they chose another.** The screen keeps what the user chose (`_chosen`, and `_touched` for "they chose"). Until then the open card is the user's brand, which may arrive a moment after the screen opens:

  ```dart
  final open = _touched ? _chosen : mine;
  ```

  A tap sets `_chosen` to the card, or to nothing if that card was the open one, so one card is open at a time.

**Where it lives:** `app/lib/features/notifications/` (`view_models/launch_actions.dart`, `notification_access_controller.dart`, `still_shooting_prompt.dart`, `notifications_help.dart`; `views/still_shooting_dialog.dart`, `notifications_help_screen.dart`), `app/lib/features/settings/views/settings_screen.dart`, `app/lib/domain/rules/phone_brand.dart`, `LaunchActionsListener` in `app/lib/app.dart`, `askOnce` called from `app/lib/features/shooting_mode/view_models/shooting_mode_controller.dart`, `PopupRouteTracker` in `app/lib/router/popup_route_tracker.dart`, `notificationsAsked` in `app/lib/data/repositories/phone_state_repository.dart`, one more step in `app/lib/app/media_lifecycle.dart`, and the route in `app/lib/router/`. Tests: `app/test/features/notifications/`, `app/test/features/settings/`, `app/test/app/launch_actions_test.dart`, `app/test/domain/rules/phone_brand_test.dart`, and additions to `media_lifecycle_test.dart`, `phone_state_repository_test.dart`, `shooting_mode_controller_test.dart` and `app_router_test.dart`. The step-by-step flows are "Notification taps", "Still shooting?", "Notification permission" and "Notifications help" in `docs/flow.md`.

**Try it yourself:** see "once per app session" at work. From `app/`:

```bash
../tool/flutter test test/features/notifications/view_models/still_shooting_prompt_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/features/notifications/view_models/still_shooting_prompt.dart` and delete the line `_claimed = true;` in `claim`, then run the same command. `due after 14 days: the session to ask about, once` fails with `Expected: null` and `Actual: DateTime:<2026-06-01 09:00:00.000Z>`: the second check asked again. Put the line back and run it again to see it pass.

**Decisions:** D-107 (all of this section), with D-101 (the scope and the owner's permission ruling), D-103 (launch actions), D-105 and D-106 (the answers in the shade, `stillAnswered`) as background.

## 8. Parked media repairs

**What we built:** two repairs to how the scan finds clips, both parked by Phase 3's final review.

- **Detached clips find their videos again (I-3).** After Android rebuilds its media library, the app matches its stored clips to the new rows by fingerprint. If Android has not finished indexing at that moment, a clip whose video is not in the list yet is *detached*: it gets the number `-id`, is flagged missing, and nothing ever looked at it again. A minute later the same video appears, and the next scan adds it as a brand-new clip. The reel shows a "missing" clip, and To tag shows the same video as a duplicate. Now, for a day after such a rebuild, a scan matches those clips again whenever the volume has changed, and a duplicate that already arrived gives way to the clip the user knows.
- **A volume with no baseline starts at the session, not at now (M-8).** If Shooting mode is on and a volume has no baseline (its read failed at switch-on, or an SD card was inserted mid-trip), its first scan used to say "nothing here is new". Now it adds the clips shot since Shooting mode was switched on.

**Why TakeTray needs it:** spec §4 names the worst failure: a clip in a reel that points at the wrong video. The next worst is a reel whose clips are split from the videos they stand for, so the user's work and the video live in two rows. A background job that wakes up after a reboot or a system update is the likeliest time to meet a half-built index, which is why this task is in the background-detection phase. And a creator inserting a fresh SD card on a trip expects the clips they shot on it to appear.

**Key ideas:**

- **Detached means "not found yet", not "gone".** A detached clip is `mediaStoreId < 0` (it holds `-id`, so no real video can have its number) and missing. It keeps its fingerprint, which is how it is found again. The scan looks for these clips only on a volume whose index is stable (the `ScanAfter` plan), never in the capped end from the shade (it ends the session, so the repair waits), and **before** it pages over the new videos, so a video that is back ahead of the baseline is found to be a clip already:

  ```dart
  case ScanAfter(:final generation):
    // Never in the capped end: it ends the session, so a repair that
    // reads the whole volume can wait for the next session's scan.
    if (caps == null) await _rematchDetached(context, volume);
    added += await _scanAfter(
      context,
      baseline!,
      volume,
      generation,
      cap: caps?[volume.name],
    );
  ```

- **A window, so the cost ends.** Reading every video on the volume is the expensive part (thousands of rows, on the UI isolate), so it must not happen forever. The only thing that leaves a clip detached while its video is still on the phone is a rebuild that ran too early, and Android finishes re-indexing in minutes. So the resync that detached clips opens a **re-match window** on that volume, and the re-match runs only inside it. A clip a verify detached (its number now holds another video) or flagged gone (its video was deleted) opens none, so it costs nothing. The resync opens the window for the lost clips that are still there:

  ```dart
  await _clips.inTransaction(() async {
    await _clips.applyRebuildMatch(volume.name, match);
    if (match.lost.isEmpty) return;
    final detached = {
      for (final c in await _clips.detachedClipsOn(volume.name))
        if (match.lost.contains(c.id)) c.id,
    };
    if (detached.isNotEmpty) {
      await _phone.openRematchWindow(
        volume.name,
        clipIds: detached,
        generation: volume.generation,
        at: now,
      );
    }
  });
  ```

  The detach and the window are written in **one transaction**. If the window cannot be written (a full disk, say) the detach is taken back with it, so the next scan does both. Without that, the clips would be detached with no window to find them again, and would stay missing for good (the test `the window is written with the detach: if it cannot be, nothing is detached and the next scan does both` guards it).

  `PhoneStateRepository` stores it in the `settings` table under `mediaRematchWindows`, like the volume versions: never exported, deleted by an import, and still there after the app is killed. A value that cannot be read counts as no window, only the key's name is logged, and the read deletes it, so it is logged once and not at every scan.

- **Read only when something changed.** MediaStore keeps a *generation* per volume, a counter that moves whenever a row is added or changed. The window remembers the generation the clips were last matched at (first the resync's). The same generation means the same videos, so a second read would find nothing. `reattach` checks, in order: no window; the window has ended (24 hours, or a clock set back by more than 5 minutes); none of its clips is still detached; the generation has not moved. Only then is the volume read, once, and the same fingerprint rule as a rebuild picks the match:

  ```dart
  if (window.generation == volume.generation) return nothing;
  final current = await _bridge.allVideos(volume.name);
  final match = matchAfterRebuild(
    detached,
    current,
    volumeName: volume.name,
    now: now,
  );
  final result = await _clips.reattachDetached(volume.name, match.remap);
  if (result.reattached + result.merged == detached.length) {
    await _phone.closeRematchWindow(volume.name);
  } else {
    await _phone.recordRematch(volume.name, volume.generation);
  }
  ```

  When every clip is back the window closes; otherwise the new generation is noted. If the read or the write fails, the generation is not noted, so the next scan tries again even when nothing changed. The window's 24 hours are a plain rule in the domain layer, open from the resync, with the end left out:

  ```dart
  bool isOpenAt(DateTime now) =>
      !now.isBefore(openedAt.subtract(rematchClockTolerance)) &&
      now.isBefore(openedAt.add(rematchWindowLength));
  ```

  The start has a tolerance of 5 minutes: an automatic time correction can put the clock a few seconds or minutes before the time the window was opened, and that must not close it. A clock further back than that (a stored time months ahead) still closes it, so a window that cannot be timed does not stay open for good.

  Only the window's own clips are matched. The rule is "when unsure, leave it": a clip with two possible videos, or a video two clips want, matches nothing and stays detached for the next scan. A wrong match would put a reel clip on the wrong video, which is worse than a clip that is flagged missing.

- **Three things can hold the video's number.** For a detached clip D and its video V, `reattachDetached` (one transaction per volume) looks at who holds V's number: nobody (D takes it and is no longer missing); a duplicate N that is the same video (N gives way); or a clip that is *another* video, such as a stale number (nothing changes). The test for "the same video" is `sameFingerprint`: the same size, length and shooting instant, never the name.

- **The old clip survives, because it has the user's work.** D is in the user's reels, in the order they built. N is the duplicate that landed in To tag or Skipped. So N is deleted and D takes its number. If N was also in reels, D gets the **union** of both clips' links, and where both are in one reel the link with the **earlier** `addedAt` stays, so the order does not change:

  ```dart
  for (final link in duplicateLinks) {
    final own = kept[link.reelId];
    if (own == null) {
      await _insertLink(keptId, link.reelId, link.addedAt);
    } else if (link.addedAt.isBefore(own)) {
      await (_db.update(_db.clipReels)..where(
            (l) => l.clipId.equals(keptId) & l.reelId.equals(link.reelId),
          ))
          .write(ClipReelsCompanion(addedAt: Value(link.addedAt)));
    }
  }
  ```

- **A repair never fails the scan.** If the phone or the database fails during the re-match, the failure is logged by its type and the scan goes on. The clips stay detached and the next scan tries again. Failing the volume instead would let a repair stop the volume's new clips and its baseline:

  ```dart
  try {
    await _rebuilds.reattach(volume, now: context.now);
  } on Object catch (e) {
    _log.warning(
      'Volume ${volume.name}: matching detached clips again failed with '
      '${e.runtimeType}; left for the next scan',
    );
  }
  ```

- **A new volume starts at the session.** The phone is asked once for the videos shot since Shooting mode was switched on. Its query is a *superset* (a video also matches if it was added or modified since), so Dart narrows it by the shooting date, `shotAt`. A video shot exactly at the start counts; one shot before does not, even if it was copied onto the card later. A video with no `DATE_TAKEN` falls back to `DATE_ADDED` (the D-69 rule), so an old video without one that is copied onto the card during the session counts as shot since the session and is added. The rule also drops any row added after the generation the scan captured, which belongs to the next scan:

  ```dart
  if (since == null) return const [];
  return [
    for (final v in rows)
      if (v.generationAdded <= captured && !shotAt(v, now: now).isBefore(since))
        v,
  ];
  ```

- **One end for both scans.** What happens after the rows are known (save the usable ones, then move the baseline) used to be the tail of `_scanAfter`. It is now `_commit`, and `_startNewVolume` calls the same function:

  ```dart
  return await _commit(
    context,
    volume,
    baseline: null,
    from: 0,
    captured: captured,
    rows: rows,
    read: '${rows.length} rows shot since the start',
    hold: false,
  );
  ```

  A clip that is already stored stays where it is, and is not added to To tag again. If the phone fails, no baseline is written, and the next scan tries the volume again.

- **The first scan never holds its baseline.** A normal scan holds the baseline just below a row that is not finished yet (`holdsBaseline`, D-72), so the next scan sees it again. The first scan of a volume must not: the session's start is a *date*, and only this scan filters by it. The next scan is a plain `ScanAfter` by generation, with no date filter, and a fresh card indexes its videos in no particular order. Held below an unfinished row, the next scan would add every pre-session video above it as new. So `hold: false` moves the baseline to the captured generation whatever the rows are:

  ```dart
  final generation = advanceBaseline(
    from: from,
    captured: captured,
    seen: hold ? rows : const [],
    now: context.now,
    truncated: truncated,
  );
  ```

  The price is a gap, and it is the rule: a video with no length yet at the first scan of a card is not added, and neither is one still being recorded (the phone's query leaves pending rows out, so the scan never sees them at all). "Add earlier videos" brings such a clip in, and `docs/later.md` (Phase 11) has the idea for closing the gap. One test feeds the scan a pending row through a fake bridge that lists one; the phone never does, so that test only shows the rule would not hold for one either.

- **The capped end covers new volumes too.** When Turn off is tapped in the shade (Section 6), the tap names every mounted volume, with a baseline or without one. A card inserted during the session (or one that could not be read when Shooting mode went on) has no baseline, so it starts at the session's start as above, but only up to the tap: the clips shot on it before the tap arrive, the ones after do not. The first version named baselined volumes only and left the card alone, which lost its clips for good: the job had counted none for it, and the next session's baselines started after them. A volume the phone could not read at the tap is still left alone.

**Where it lives:** `app/lib/data/media/library_resync.dart` (`resync` opens the window, `reattach`), `app/lib/data/media/media_scanner.dart` (`_rematchDetached`, `_startNewVolume`, `_commit`), `app/lib/data/repositories/clips_repository.dart` (`detachedClipsOn`, `reattachDetached`, `ReattachResult`), `app/lib/data/repositories/phone_state_repository.dart` (`rematchWindow`, `openRematchWindow`, `recordRematch`, `closeRematchWindow`), `app/lib/domain/rules/rematch_window.dart` (`RematchWindow`, `rematchWindowLength`), `app/lib/domain/rules/baseline.dart` (`shotSinceSession`). Tests: `app/test/data/repositories/clips_repository_reattach_test.dart`, `app/test/data/media/media_scanner_rematch_test.dart` (its "the re-match window" group), `app/test/data/media/media_scanner_new_volume_test.dart`, the "re-match windows (D-108)" group in `app/test/data/repositories/phone_state_repository_test.dart`, `app/test/domain/rules/rematch_window_test.dart`, and the `shotSinceSession` group in `app/test/domain/rules/baseline_test.dart`. Docs: "Finding new clips", "Tagging data changes" and "Phone state" in `docs/flow.md`.

**Try it yourself:** first, see the cost end. From `app/`:

```bash
../tool/flutter test test/data/media/media_scanner_rematch_test.dart
```

It ends with `All tests passed!`. Open `app/lib/data/media/library_resync.dart` and delete the line `if (window.generation == volume.generation) return nothing;` in `reattach`, then run it again. `the re-match window inside the window an unchanged generation does not read all videos` fails with `Expected: <1>` and `Actual: <3>`: two scans that saw nothing new each read the whole volume. Put the line back.

Then see the order of the reel preserved:

```bash
../tool/flutter test test/data/repositories/clips_repository_reattach_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/data/repositories/clips_repository.dart` and change `link.addedAt.isBefore(own)` to `link.addedAt.isAfter(own)` in `_mergeDuplicate`, then run the same command. `reattachDetached the duplicate is in the same reel: one link, the earliest addedAt kept (the reel clip is the older)` fails with `Expected: {1: DateTime:2026-10-26 09:01:00.000Z}` and `Actual: {1: DateTime:2026-10-26 09:05:00.000Z}`: the merged clip took the later time, so it would move down its reel. Put the line back and run it again to see it pass.

**Decisions:** D-108 (all of this section, amending D-72; its fix round added the window and the first scan that never holds), with D-69 (the fingerprint), D-70 (the plans and the baseline), D-71 (detaching as `-id`) and D-106 (the capped end) as background.

## 9. On the S24

**What we built:** the proof on a real phone. Everything before this section was tested on a computer (Robolectric pretends to be Android); here seven flows run on the S24, in the real app, with the real job scheduler, notification shade and alarm manager: `app/patrol_test/background_test.dart`.

**Why TakeTray needs it:** the whole point of Phase 6 is that a notification arrives *while the app is closed*. A computer cannot say whether Android really wakes the job when a video appears, how long that takes, or whether the shade shows the text we think it shows. Only the phone can.

**Key ideas:**

- **The flows.** Each runs from cleared data, with only `Movies/TakeTray Test/` watched:
  1. two videos go in while the app is in the background, "2 new clips to tag" appears through the real content trigger 5 minutes after the last one (the test waits up to 7 and prints the time), and tapping it opens To tag with the two clips;
  2. turning Shooting mode off removes the notification and the job (the notification is posted by the job-run hook, so the flow does not wait 5 minutes);
  3. the evening reminder says how many clips you shot today;
  4. "Turn off" in the Still shooting? notification switches Shooting mode off without opening the app, and a video shot after it stays out of To tag;
  5. the Still shooting? dialog shows once and Keep it on is remembered;
  6. the real evening alarm, set two minutes ahead, fires;
  7. three bursts of inserts leave exactly one job pending.
- **The test finds only its own notifications.** Every shade helper takes an `OwnText`, the whole text TakeTray writes (never a part of one), so a notification of another app can never match. "Turn off" is not tapped on the screen: with two TakeTray notifications the phone groups them and folds Still shooting? away, and a single one is collapsed, so a tap cannot find the button. The test fires the button's own `PendingIntent` through a hook instead (`pressStillTurnOff`), which runs the real `ShadeActionReceiver`. Whether the button looks right is a hand check.
- **A hook reaches what an app cannot trigger.** The debug-only channel `app.taketray/test_background` sends the very broadcast the alarm carries (`fireEvening`, `fireStill`), runs the job's work (`runNewClipsJob`), presses the Still shooting? Turn off button's own intent (`pressStillTurnOff`), and lists *this app's own* notifications and jobs (`activeNotifications`, `pendingJobs`). Android only ever tells an app about its own, so no other app's is seen.
- **What the phone measured** (2026-11-06, before the 5 minute wait of D-110; the new wait is for the owner to check by hand):
  - insert to notification: **6949 ms** and **6777 ms** (two runs), of which 5 s is the job's own update delay (`Trigger update delay: +5s0ms`; the maximum delay is `+30s0ms`, both read from our job's block of `dumpsys jobscheduler`);
  - the evening alarm came **78 s** and **65 s** after its minute, never early: it is inexact on purpose;
  - after a burst of inserts there is exactly one job.
- **What is not proven.** The button on the screen: the phone's grouping and folding is standard Android, so the owner checks "Turn off" in the expanded notification by hand (`docs/dev-setup.md`, Phase 6 check, step 5). Flows 4 and 7 run the job's own work or fire the button's intent; flow 1 alone proves the real trigger (and the sound is a hand check).
- **Heat holds the job.** After a few flows in a row, on the charger, the phone reached thermal status 2 and our job's block said `Restricted due to: thermal.`: every condition was met and Android still waited. That is Android being right (a hot phone should not do background work), and it is also the lesson for the test: a timeout would blame the app. So the flows ask `PowerManager.getCurrentThermalStatus()` through the `thermalStatus` hook, fail with "phone too hot, let it cool" before waiting, and wait for the phone to cool at the start of each flow. Nothing waits longer to get past the heat.
- **Two bugs were in the test, not the app.** `closeShade` pressed Back; with the shade already closed, Back finished the app, the Flutter engine stopped, and the test died with `Failed to parse HTTP response`. It presses Home now. And Patrol runs each test in a fresh process with cleared data, so a flow never sees the one before it.

**Where it lives:** `app/patrol_test/background_test.dart`, `app/patrol_test/support/` (`shade.dart`, `own_texts.dart`, `test_background.dart`, `test_media.dart`), `app/android/app/src/debug/kotlin/app/taketray/DebugBackgroundHooks.kt`. Unit tests of the helpers: `app/test/patrol_support/`; of the hooks: `DebugBackgroundHandlerTest.kt`. How to run it: "Phase 6 check" in `docs/dev-setup.md`.

**Try it yourself:** the helpers' tests run on a computer. From `app/`:

```bash
../tool/flutter test test/patrol_support/test_background_test.dart
```

It ends with `All tests passed!`. Open `app/patrol_test/support/test_background.dart` and change `status >= thermalModerate` to `status > thermalModerate` in `requireCool`, then run it again: `requireCool fails a hot phone (moderate and above) by name` fails with `Actual: <Instance of 'Future<void>'>`, because a phone at status 2 now passes. Put it back. To see the real thing you need the phone: the steps are in `docs/dev-setup.md`, "Running `background_test.dart`".

**Decisions:** D-109 (the times, the heat and the shade), with D-104 (the job and its delays), D-105 (the reminders) and D-100 (Patrol on the S24) as background.
