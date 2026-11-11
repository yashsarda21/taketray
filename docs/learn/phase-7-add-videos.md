# Learning guide: Phase 7, adding videos by hand

This guide explains how TakeTray adds videos you pick yourself: friends' WhatsApp and Quick Share videos, clips from any shooting device, and, when TakeTray can't see all your videos, Android's photo picker (Manual mode).

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-111 (the owner's rulings), so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-111.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [The bridge: folder pages and the photo picker](#2-the-bridge-folder-pages-and-the-photo-picker)
3. Adding by hand, and Undo (Task 3)
4. Picked clips get pictures, verification and a grant clean-up (Task 4)
5. The folder browser (Task 5)
6. Manual mode (Task 6)
7. On the S24 (Task 7)

## 2. The bridge: folder pages and the photo picker

**What we built:** six new calls between Dart and Android, so the app can list the videos of any folder a page at a time, and can open Android's photo picker and get back what the user chose.

- **`videosInFolder`**: "give me 60 videos of this folder, starting at video 120".
- **`pickVideos`**: opens the photo picker and waits for the answer.
- **`thumbnailOfUri`, `readableUris`, `persistedUris`, `releaseUris`**: the same kind of questions for a picked video, which has an address (a `content://...` text) and no number in Android's media library.

**Why TakeTray needs it:** two kinds of videos need adding by hand. With full access, the folder browser lists every folder; a folder can hold thousands of clips, so Dart asks for one page at a time. Without full access (Manual mode), TakeTray cannot list anything, so the user picks videos in Android's own picker, which needs no permission and hands TakeTray only the videos that were picked.

**Key ideas:**

- **Pages need a fixed order, or a clip shows twice.** Imagine page 1 is "the 60 newest" and page 2 is "the next 60". If two clips have the same time, the database may put them in either order each time it is asked, so one clip can be the last of page 1 and the first of page 2, and another can fall between them and never show. The fix is a tie-break that is never equal: the clip's number.

  ```kotlin
  const val SHOT_NEWEST_ORDER =
      "COALESCE(NULLIF(${MediaColumns.DATE_TAKEN}, 0), NULLIF(${MediaColumns.DATE_ADDED}, 0) * 1000, " +
          "NULLIF(${MediaColumns.DATE_MODIFIED}, 0) * 1000) DESC, ${MediaColumns._ID} DESC"
  ```

  Read it like this: use the date taken if there is one (a `0` counts as "no date"), else the date added, else the date modified; newest first; for the same time, the higher number first. Date taken is in milliseconds and the other two are in seconds, so they are multiplied by 1000 to be compared. A test (`pages never repeat or skip a clip, even when many share a shot time`) cuts eleven clips into pages of every size from 1 to 12 and checks that the pages put back together are the full list.

- **A card pulled out is not an error.** If the user removes an SD card while its folder is open, asking for the next page must give an empty page, not a crash. So `videosInFolder` checks that the volume is still in Android's list, and if the query itself fails with the "volume not found" kind of error, it checks again:

  ```kotlin
  } catch (e: IllegalArgumentException) {
      // MediaProvider says "Volume ... not found" this way.
      if (volumeName in volumeSource.names()) throw e else emptyList()
  }
  ```

  Any other failure is still an error. "Nothing there" and "I could not look" must never look the same.

- **Two pickers, one intent function.** Android 13 and later have the photo picker built in. Some older phones (Android 11 and 12) get it through a Google update, which shows up as an "extension level" of 2 or more. Everything else gets the older document picker. One small function decides, from two numbers, and the tests try every pair:

  ```kotlin
  if (sdk >= 33 || (sdk in 30..32 && extensionLevel >= 2)) {
      Intent(MediaStore.ACTION_PICK_IMAGES)...
  } else {
      Intent(Intent.ACTION_OPEN_DOCUMENT)...
  ```

  An `Intent` is Android's "please open something for me" message. We build it by hand; a library (androidx) would build the same message for one more dependency (D-112).

- **One picker at a time, and the answer may never come.** The picker is another screen. Our app waits for it, and Android delivers the answer to `onActivityResult`. Three things can go wrong, and each has a test: the user taps the button twice (the second call fails with `busy`); the user cancels (an empty list); Android kills TakeTray while the picker is open (when the app starts again the answer arrives and nobody is waiting for it: it is dropped, and does not answer a later pick by mistake).

  ```kotlin
  if (picks.isWaiting) throw FlutterError("busy", "a picker is already open")
  ```

- **A grant that lasts.** A picked video's address works only while Android lets the app read it. `takePersistableUriPermission` asks Android to remember that across restarts; it can say no (it throws), so each picked video says `persisted`: true or false. When it is false, the video works until the app closes, and Task 4 decides what to do with it.

- **Failed is not gone.** `readableUris` answers "which of these can still be read?". A video whose read is refused (`SecurityException`) or whose cursor has no row is gone. Anything else is a failed read and the whole call throws, including a `null` cursor: Android gives `null` when the provider's process dies during the call, and that must not look like "gone". If a failure looked like "nothing is readable", the app might then give up saved grants that are still in use. Three tests guard it: `readable drops a uri whose query throws SecurityException`, `readable throws on a null cursor, which is a failed read and not a gone video` and `readable throws when the call itself fails, so failed is never read as gone`.

- **Tests that can fail.** The brief's edge cases were written first. They failed to compile (no types yet); then empty stand-ins let them compile and fail for the real reasons (55 Kotlin tests red, 18 Dart tests red). After the code was written, each key line was broken on purpose to see the right test fail, and put back: the sort order (three tests), the `busy` guard, the `SecurityException` branch, the "whole call fails" path, the release loop, the gone-volume check, the duration filter and the "late result" rule.

**Where it lives:** the contract is `app/pigeons/media_api.dart` (new `PickedVideoMsg` and six methods). Kotlin: `app/android/app/src/main/kotlin/app/taketray/media/PickedVideos.kt` (the picker, the facts, the saved grants), `VideoQueries.kt` (`inFolderSelection`, `inFolderArgs`, `SHOT_NEWEST_ORDER`), `Thumbnails.kt` (`loadFromUri`), `MediaHostApiImpl.kt`, and `MainActivity.onActivityResult`. Dart: `app/lib/platform/media_bridge.dart`, the `PickedVideo` type in `app/lib/domain/models/media.dart`, and `app/test/support/fake_media_bridge.dart` for tests. Tests: `PickedVideosTest`, `VideoQueriesTest`, `VideoQueriesSqlTest`, `MediaHostApiImplTest` and `ThumbnailsTest` in `app/android/app/src/test/kotlin/app/taketray/media/`, and `app/test/platform/media_bridge_test.dart` and `fake_media_bridge_test.dart`.

**Try it yourself:** see the tie-break matter. From the repo root:

```bash
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.media.VideoQueriesSqlTest'
```

It ends with `BUILD SUCCESSFUL`. Now open `VideoQueries.kt` and delete `, ${MediaColumns._ID} DESC` from the end of `SHOT_NEWEST_ORDER`, then run the same command. Two tests fail: `clips with the same shot time are ordered by id, newest id first` and `pages never repeat or skip a clip, even when many share a shot time`. Put the text back and run it again to see it pass.

**Decisions:** D-112 (all of this section), with D-111 (Phase 7's scope) as background.

## 4. Picked clips get pictures, verification and a grant clean-up

**What we built:** a video added through Android's photo picker now behaves like any other clip.

- **A picture.** Its tile, a reel's cover and the Shooting mode card's backdrop show its thumbnail.
- **A check.** When To tag or a reel page checks its clips, a picked clip whose video was deleted (or whose access was taken away) is flagged missing, and comes back if it can be read again.
- **A clean-up.** Once per app start, TakeTray gives back the saved read grants that no clip uses any more.
- **A fix from the parked list.** The reel picker no longer fails every time when one of its clips was deleted while it was open.

**Why TakeTray needs it:** in Manual mode the photo picker is the only way in, so picked clips must not be second-class: no grey tiles, no stale clips that cannot play. And Android limits how many saved grants an app may keep, so grants nobody uses must go back. The danger runs the other way too: giving back a grant that a clip still needs would break that clip for good, and the user could only fix it by picking the video again.

**Key ideas:**

- **A file name must not say which video it is.** A MediaStore thumbnail is named after the volume and the number. A picked video has an address such as `content://media/picker/0/.../media/1000017`; putting that in a file name would leak it (D-10) and would hold `/` characters. So the name holds a hash of the address: FNV-1a, a short, well-known function that turns any text into a 64-bit number, the same on every run.

  ```dart
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  ```

  Dart's own `hashCode` would be shorter to write, but it makes no promise to be the same after a restart, and the files must still be found tomorrow. A test checks the published answer for `"foobar"` (`85944171f73967e8`).

- **"I could not look" is not "it is gone".** `readableUris` throws when the question itself failed. The verifier treats any throw as "skipped, change nothing":

  ```dart
  } on Object catch (e) {
    ...
    return _PickedCheck(skipped: {for (final c in picked) c.id});
  }
  ```

  If a failure were read as "gone", one bad moment of the phone would flag every picked clip missing and take the To tag ones out of the list.

- **Picked clips are checked without full access.** MediaStore clips are skipped in Manual mode, because a limited query sees only some videos and everything else would look gone. A picked clip's address is not affected by that, and Manual mode is exactly where picked clips live, so they are always checked.

- **The clean-up only gives back what nobody holds.** It reads the saved grants, then every `picker_uri` in the clips table, and releases the difference:

  ```dart
  final unused = [
    for (final uri in saved)
      if (!heldForms.contains(uri) && !heldForms.contains(_canonical(uri)))
        uri,
  ];
  ```

  Any row counts, whatever its state: a missing clip may come back, a skipped one may be tagged later. An address written slightly differently (the case of the host, of a `%3a` escape) still counts as held, because a mismatch there would be the worst kind of mistake. If reading the grants or the rows fails, it throws before releasing anything.

- **Timing matters.** A grant is taken by Android the moment the user confirms the picker, and the clip row is written a moment later. A clean-up that ran in between would see a grant with no row and give it back. So the clean-up runs on the media queue (an Add queued before it finishes first), and it is queued on the very first frame, before the start's scan: nobody can open the picker and choose videos before it is done. Its bridge calls give up after 15 seconds, so a call that never answers cannot hold the scans behind it.

- **Ids that went away.** The reel picker keeps the ids of the chosen clips while it is open. If a verify deletes one meanwhile, adding a clip that does not exist fails the whole transaction, and every later confirm failed the same way until Cancel. Now `ReelClipActions.addToReels` reads the ids again and drops the ones that are gone; if none is left, nothing is written and no snack is shown.

- **Tests that can fail.** Every edge case was written first and run against an empty `PickedGrants` that only threw: 59 tests failed for the real reasons (no picked key, picked clips skipped, the sweep not there, the picker's confirm failing). After the code was written, each key line was broken on purpose and the right tests went red, then it was put back: the "held by a row" filter, a failed read that releases nothing, "a throw means skipped", the hash in the file name, the picker's dropped ids, the cover rule, the timeout, the spelling match, the queue, the start-up order, the check without full access, the provider's equality and the silent tag of nothing.

**Where it lives:** `app/lib/data/media/thumbnail_cache.dart` (`ClipThumbnailKey`, `addressHash`), `app/lib/features/clips/widgets/clip_thumbnail_image.dart`, `app/lib/data/database/clip_rules.dart` (`hasPicture`), `app/lib/data/media/media_verifier.dart` (`_checkPicked`), `app/lib/data/media/picked_grants.dart` (`PickedGrants.sweep`), `app/lib/app/media_lifecycle.dart`, `app/lib/features/reels/view_models/reel_clip_actions.dart` and `app/lib/features/reels/views/reel_picker_sheet.dart`. Tests: `app/test/data/media/picked_grants_test.dart`, and new groups in `thumbnail_cache_test.dart`, `media_verifier_test.dart`, `media_lifecycle_test.dart`, `reels_repository_test.dart`, `clips_repository_test.dart`, `clip_thumbnail_image_test.dart`, `reel_clip_actions_test.dart`, `reel_selection_screen_test.dart` and `to_tag_actions_test.dart`.

**Try it yourself:** see the clean-up's one rule matter. From the repo root:

```bash
cd app && ../tool/flutter test test/data/media/picked_grants_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/data/media/picked_grants.dart` and replace the line `if (!heldForms.contains(uri) && !heldForms.contains(_canonical(uri)))` with `if (true)`, then run it again. Several tests fail, among them `releases only the saved grants that no clip row holds`: every grant, used or not, would be given back. Put the line back.

**Decisions:** D-74 and D-84 point 3 (amended), D-112 (the bridge calls this builds on).
