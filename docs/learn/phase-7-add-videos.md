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

- **Failed is not gone.** `readableUris` answers "which of these can still be read?". A video whose read is refused (`SecurityException`) or that has no row is gone. But if the whole call fails for any other reason, it throws. If a failure looked like "nothing is readable", the app might then give up saved grants that are still in use. The two tests that guard it are `readable drops a uri whose query throws SecurityException` and `readable throws when the call itself fails, so failed is never read as gone`.

- **Tests that can fail.** The brief's edge cases were written first. They failed to compile (no types yet); then empty stand-ins let them compile and fail for the real reasons (55 Kotlin tests red, 18 Dart tests red). After the code was written, each key line was broken on purpose to see the right test fail, and put back: the sort order (three tests), the `busy` guard, the `SecurityException` branch, the "whole call fails" path, the release loop, the gone-volume check, the duration filter and the "late result" rule.

**Where it lives:** the contract is `app/pigeons/media_api.dart` (new `PickedVideoMsg` and six methods). Kotlin: `app/android/app/src/main/kotlin/app/taketray/media/PickedVideos.kt` (the picker, the facts, the saved grants), `VideoQueries.kt` (`inFolderSelection`, `inFolderArgs`, `SHOT_NEWEST_ORDER`), `Thumbnails.kt` (`loadFromUri`), `MediaHostApiImpl.kt`, and `MainActivity.onActivityResult`. Dart: `app/lib/platform/media_bridge.dart`, the `PickedVideo` type in `app/lib/domain/models/media.dart`, and `app/test/support/fake_media_bridge.dart` for tests. Tests: `PickedVideosTest`, `VideoQueriesTest`, `VideoQueriesSqlTest`, `MediaHostApiImplTest` and `ThumbnailsTest` in `app/android/app/src/test/kotlin/app/taketray/media/`, and `app/test/platform/media_bridge_test.dart` and `fake_media_bridge_test.dart`.

**Try it yourself:** see the tie-break matter. From the repo root:

```bash
tool/test_android -ProbolectricSdks=35 --tests 'app.taketray.media.VideoQueriesSqlTest'
```

It ends with `BUILD SUCCESSFUL`. Now open `VideoQueries.kt` and delete `, ${MediaColumns._ID} DESC` from the end of `SHOT_NEWEST_ORDER`, then run the same command. Two tests fail: `clips with the same shot time are ordered by id, newest id first` and `pages never repeat or skip a clip, even when many share a shot time`. Put the text back and run it again to see it pass.

**Decisions:** D-112 (all of this section), with D-111 (Phase 7's scope) as background.

