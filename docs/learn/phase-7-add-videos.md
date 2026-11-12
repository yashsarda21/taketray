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
3. [Adding by hand, and Undo](#3-adding-by-hand-and-undo)
4. [Picked clips get pictures, verification and a grant clean-up](#4-picked-clips-get-pictures-verification-and-a-grant-clean-up)
5. [The folder browser](#5-the-folder-browser)
6. [Manual mode](#6-manual-mode)
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

## 3. Adding by hand, and Undo

**What we built:** the rules and the service behind the **Add videos** screens, which come in later tasks.

- **`browseFolders`** turns Android's list of folders into the list the user sees: which folders show, what each is called, and in what order.
- **`AddVideosService`** does every add and every Undo. It has four calls: `marks` (which videos in a folder are already added, and where), `addFromFolder`, `addPicked` (for the photo picker) and `undo`.

**Why TakeTray needs it:** a video can reach TakeTray in more than one way. Shooting mode's scan can find it, the user can add it from a folder, they can tap **Add** twice, or the scan can run while they add. Whatever happens, one video must be **one clip in one place**, and **Undo** must take back only what that add did, never something the user did after it.

**Key ideas:**

- **Hiding WhatsApp's Sent folder.** When the owner sends a clip on WhatsApp, WhatsApp keeps a smaller copy in a folder called `Sent`. Adding that copy by mistake would put a worse version of a clip in a reel (D-111). The rule looks only at the folder's path:

  ```dart
  bool _isWhatsAppSent(List<String> segments) =>
      segments.length >= 2 &&
      _lower(segments.last) == 'sent' &&
      segments
          .take(segments.length - 1)
          .any((s) => _lower(s).startsWith('whatsapp'));
  ```

  Read it like this: the last folder name is `Sent` (any case), and some folder above it starts with `WhatsApp`. So `Movies/WhatsApp/Sent/` is hidden, but `DCIM/Sent/` and `Movies/Sent stuff/` are not.

- **Two folders with the same name.** `DCIM/Camera` and `Movies/Camera` would both show as "Camera". So when names clash, each gets a small `detail`: the folder above it ("DCIM", "Movies"), and the volume (phone or SD card) when they are on different ones.

- **Marks follow the prototype.** A video already added shows a label and cannot be picked again: **In this reel**, **In To tag**, or **In a reel** (only when adding to To tag). A video in Skipped has no mark: picking it again is a clear "I want this now", so the add brings it back.

- **One rule for the grid and the add.** A marked video is exactly a video the add leaves alone (it is counted as `alreadyThere`). A test checks this for every kind of clip and every target, so the screen can never promise something the add does not do.

- **One job at a time.** Every add and every Undo runs on the media work queue, the same line the scan waits in. Two taps on **Add** become two jobs; the second one finds the clip the first one saved and reports it as already there:

  ```dart
  Future<AddResult> addFromFolder(List<MediaVideo> videos, AddTarget target) =>
      _queue.run(() async {
  ```

- **The same clip the scan would make.** A video added from a folder is saved exactly as a scan would save it, by the same function (`clipFromVideo`, moved out of the scanner so both use it). So when Shooting mode's scan later sees the same video, it recognises it and adds nothing. One test adds a video to a reel and then runs the scan: the video stays in the reel and To tag stays empty.

- **A number can belong to another video.** Android gives each video a number. If a stored clip has that number but its size, length or date do not match the video in the folder, it is another video (for example a clip restored from a backup made on another phone). The old clip is set aside (detached) and the video comes in as a new clip, the same rule the scan uses.

- **Undo takes back only what this add created.** The add remembers its exact time (`at`). Undo removes a new clip's place only if it is still the place the add gave it, at that time:

  ```dart
  i.clipId.isIn(batch) &
      i.state.equalsValue(InboxState.pending) &
      i.addedAt.equalsValue(at) &
      i.clipId.isNotInQuery(inAReel),
  ```

  So a clip you tagged, skipped or put in another reel after adding it stays where you put it. A clip the add brought back from Skipped goes back to Skipped. Undo also remembers that it has run: a second tap does nothing, even if you moved the clip back in between.

- **Tests that can fail.** All the edge cases were written first. They failed to compile; then stand-ins that did nothing let them compile and fail for the real reason (92 red; the 5 that passed only check that nothing extra is hidden). After the code was written, 28 key lines were broken on purpose, one at a time, and each made at least one test fail before it was put back: the Sent rule (4 ways), "no inbox row for a reel", the Skipped restore and its Undo, "only what this add created" (5 ways), the double add, the queue, the access check, the rebuild check and the "not kept" rules.

**Where it lives:** `app/lib/domain/rules/browse_folders.dart`, `app/lib/data/media/add_videos_service.dart`, and in `app/lib/data/repositories/clips_repository.dart` the methods `addByHand`, `undoHandAdd` and `placesOf`. Shared rules: `clipFromVideo` in `media_scanner.dart`, `shotAtFrom` in `domain/rules/clip_date.dart`, `newClipFromPicked` in `domain/rules/media_clip.dart`. Tests: `app/test/domain/rules/browse_folders_test.dart`, `app/test/data/media/add_videos_service_test.dart`, and the `addByHand` group in `app/test/data/repositories/clips_repository_test.dart`.

**Try it yourself:** see the Sent rule matter. From the repo root:

```bash
cd app && ../tool/flutter test test/domain/rules/browse_folders_test.dart
```

It ends with `All tests passed!`. Now open `lib/domain/rules/browse_folders.dart` and change `startsWith('whatsapp')` to `contains('whatsapp')`, then run it again. One test fails: `a segment must start with WhatsApp: com.whatsapp alone does not count`, because `Android/media/com.whatsapp/Sent/` would now be hidden. Put the text back and run it again to see it pass.

**Decisions:** D-113 (all of this section), with D-111 (the owner's rulings) and D-57, D-84 and D-94 (identity, Undo and Skipped) as background.

## 4. Picked clips get pictures, verification and a grant clean-up

**What we built:** a video added through Android's photo picker now behaves like any other clip.

- **A picture.** Its tile, a reel's cover and the Shooting mode card's backdrop show its thumbnail.
- **A check.** When To tag or a reel page checks its clips, a picked clip that can no longer be read (its video was deleted, its access was taken away, or its SD card or USB drive was unplugged) is flagged missing, in To tag, Skipped and reels alike. It is never removed by the check, and it comes back if it can be read again. Its tile, in a reel, in To tag or in Skipped, has the same **Remove** button, so a video that really is gone can be taken out of the list with **Undo**.
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

  If a failure were read as "gone", one bad moment of the phone would flag every picked clip missing. Even a real "gone" only flags: Android cannot tell a deleted video from an unplugged drive for a picked address, so the check never takes a picked clip out of To tag (a MediaStore clip on a card that is not mounted is skipped for the same reason).

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

- **Remove on a missing tile.** Because a picked clip that cannot be read now stays in To tag and Skipped, those two screens needed the reel page's **Remove**. It deletes the clip's list row and, by the orphan rule (a clip in no reel and no list is deleted), the clip; the video file is never touched. **Undo** puts back the row, in its state, and the clip with its old id. The tile is the same component, `TtMissingClipTile`; only the row has to grow at large text, as on the reel page. Tests on the real database cover Remove, Undo, a clip that is also in a reel (it keeps its link), a double tap, a failure and 200% text; breaking the orphan sweep, Undo, or the reel-link rule each fails named tests.

- **Two guards on the clean-up, and Android's own cap.** The clean-up reads the saved grants *first* and the clip rows *second*, so a grant taken between the two reads is not in the list it releases from; three tests pin that order and fail when the two lines are swapped. And if clips hold addresses and grants are saved but not one saved grant matches any held address, it releases nothing and logs two counts: that would be a difference in how Android spells the two lists, not a phone full of unused grants, and releasing would revoke every picked clip for good. Android itself keeps at most 512 saved grants per app and, beyond that, quietly releases the oldest ones with no error (AOSP `maybePrunePersistedUriGrantsLocked`). Such a clip reads as unreadable and shows as missing; picking the video again brings it back. A warning near the cap is parked in `later.md`.

- **Ids that went away.** The reel picker keeps the ids of the chosen clips while it is open. If a verify deletes one meanwhile, adding a clip that does not exist fails the whole transaction, and every later confirm failed the same way until Cancel. Now `ReelClipActions.addToReels` reads the ids again and drops the ones that are gone; if none is left, nothing is written and no snack is shown.

- **Tests that can fail.** Every edge case was written first and run against an empty `PickedGrants` that only threw: 59 tests failed for the real reasons (no picked key, picked clips skipped, the sweep not there, the picker's confirm failing). After the code was written, each key line was broken on purpose and the right tests went red, then it was put back: the "held by a row" filter, a failed read that releases nothing, "a throw means skipped", the hash in the file name, the picker's dropped ids, the cover rule, the timeout, the spelling match, the queue, the start-up order, the check without full access, the provider's equality and the silent tag of nothing.

**Where it lives:** `app/lib/data/media/thumbnail_cache.dart` (`ClipThumbnailKey`, `addressHash`), `app/lib/features/clips/widgets/clip_thumbnail_image.dart`, `app/lib/data/database/clip_rules.dart` (`hasPicture`), `app/lib/data/media/media_verifier.dart` (`_checkPicked`), `app/lib/data/media/picked_grants.dart` (`PickedGrants.sweep`), `app/lib/app/media_lifecycle.dart`, `app/lib/features/reels/view_models/reel_clip_actions.dart` and `app/lib/features/reels/views/reel_picker_sheet.dart`. Tests: `app/test/data/media/picked_grants_test.dart`, and new groups in `thumbnail_cache_test.dart`, `media_verifier_test.dart`, `media_lifecycle_test.dart`, `reels_repository_test.dart`, `clips_repository_test.dart`, `clip_thumbnail_image_test.dart`, `reel_clip_actions_test.dart`, `reel_selection_screen_test.dart` and `to_tag_actions_test.dart`.

**Try it yourself:** see the clean-up's one rule matter. From the repo root:

```bash
cd app && ../tool/flutter test test/data/media/picked_grants_test.dart
```

It ends with `All tests passed!`. Now open `app/lib/data/media/picked_grants.dart` and replace the line `if (!heldForms.contains(uri) && !heldForms.contains(_canonical(uri)))` with `if (true)`, then run it again. Several tests fail, among them `releases only the saved grants that no clip row holds`: every grant, used or not, would be given back. Put the line back.

**Decisions:** D-74 and D-84 point 3 (amended), D-112 (the bridge calls this builds on, and the 512 cap), D-116 (unreadable means flagged, not removed; the clean-up's guards).

## 5. The folder browser

**What we built:** the two screens behind **Add videos** when TakeTray can see all your videos.

- **The folder list.** Every folder with videos, on the phone and on any SD card or USB drive. Each row shows a small 2×2 preview of the folder's newest videos, its name and how many videos it holds. The camera folder comes first. A one-time tip at the top says how to keep friends' videos sharp.
- **The video grid.** One folder's videos, newest first, under day headers ("Today · Fri, Oct 30"). Tap videos to pick them; a bar at the bottom counts them and adds up their length; **Add** puts them in To tag or in the reel, and you land back where you started, with a snack and **Undo**.
- **The way in.** A new **Add videos** button on To tag and on every reel's page (and in their empty states).

**Why TakeTray needs it:** friends' WhatsApp and Quick Share videos, and clips from a GoPro or a second phone, land in folders that Shooting mode does not watch (D-111). This is how they get in. A folder can hold thousands of videos, an SD card can be pulled out while you look at it, and access can be taken away from the phone's settings: each of these must end calmly, never with a crash or a wrong video.

**Key ideas:**

- **Never show a volume's name.** Android names the phone's storage `external_primary` and an SD card or USB drive something like `1234-5678`. When two folders share a name (a `Camera` on the phone and one on the card), the row needs to say which is which, but those names would look like a bug. The rule now gives a kind, not a name, and the screen turns it into words:

  ```dart
  FolderStorage storageOf(String volume) => volume == primaryVolumeName
      ? FolderStorage.phone
      : FolderStorage.other(
          others.length > 1 ? others.indexOf(volume) + 1 : null,
        );
  ```

  Read it like this: the phone's own storage is "Phone"; anything else is "Other storage", because a card and a USB drive look the same from here. With two of them, they are numbered, the same way on every row ("Other storage 1", "Other storage 2").

- **Read a page at a time.** The grid never asks for the whole folder. It asks the phone for 200 videos, and asks for the next 200 only when you scroll near the end of what is shown:

  ```dart
  if (index >= rows.length - _loadAheadRows) _askMore(state);
  ```

  The list itself is built lazily too: only the rows on screen exist, and only their pictures are loaded. So a folder of 3,000 videos opens as fast as a folder of 30.

- **Your choice survives the pages.** What you picked is kept as a set of video numbers, apart from the list of videos. A new page only adds videos to the list, so a video you picked on page one is still picked on page three. A test scrolls through 450 videos (three pages), picks the first and the last, and checks that **Add 2** adds exactly those two.

- **A page can arrive too late.** If you leave the app and come back while a page is loading, the grid reads the folder again from the start. The late page would then be added to a list it no longer belongs to. Each full read bumps a counter (`_epoch`), and a page that was asked for under an older counter is dropped when it arrives.

- **Already added means "cannot pick".** A video that is already in this reel, in To tag, or (when adding to To tag) in any reel shows a label instead of a check circle. A tap on it says "Already added". The labels for a page are read before its videos show, so a video is never pickable for a moment and then marked.

- **One add, one result, one way back.** The grid and the folder list are two screens on top of the page you came from. When the add works, the grid closes and hands its result to the list, the list closes and hands it on, and the page that opened them shows the snack. If access is lost or the reel is deleted while you are there, the same chain closes both screens with a "leave" note instead. Only the top screen closes itself, so the two can never close the same screen twice.

- **Tap twice, add once.** **Add** turns off as soon as it is tapped, and the grid's own state says "adding", so even two taps in the same frame start one add. Back waits while it runs, and so does a lost access: the grid closes only once the add is done, so an add that worked always shows its snack with **Undo**.

- **When things change behind you.** Coming back to the app reads the folder again. A video you picked that was deleted meanwhile leaves your choice; an SD card that was removed shows "No videos in this folder" and nothing stays picked. A failed add keeps your choice and says "Couldn't add videos. Try again.".

- **Tests that can fail.** All the screen and rule tests were written first and run against empty stand-ins: 99 failed for the real reasons (no rows, no tiles, no storage, the tip never saved). After the code was written, 28 key lines were broken on purpose, one at a time, and each made a named test fail before it was put back: the choice lost on a new page, the double-tap guard (twice: the grid's state and the button), a marked video that can be picked (twice: the grid's state and the tile), a failed add that drops the choice, the access and reel listeners, a removed card that keeps the old grid, the repeated-video and late-page guards, the numbering of other storages, and more.

**Where it lives:** `app/lib/features/add_videos/` (`views/add_folders_screen.dart`, `views/add_grid_screen.dart`, `views/open_add_videos.dart`, `views/add_videos_flow.dart`, `view_models/add_folders_controller.dart`, `view_models/add_grid_controller.dart`, `view_models/folder_video.dart`), the routes in `app/lib/router/routes.dart` and `app_router.dart` (`addVideosRoute`), the rule in `app/lib/domain/rules/browse_folders.dart`, the tip's flag in `app/lib/data/repositories/phone_state_repository.dart`, and the new buttons in `to_tag_screen.dart` and `reel_detail_screen.dart`. Tests: `app/test/features/add_videos/` (with `add_videos_support.dart`), `browse_folders_test.dart`, `phone_state_repository_test.dart` and `app_router_test.dart`.

**Try it yourself:** see the choice survive paging. From the repo root:

```bash
cd app && ../tool/flutter test test/features/add_videos/views/add_grid_screen_test.dart --plain-name "the choice survives every page"
```

It ends with `All tests passed!`. Now open `app/lib/features/add_videos/view_models/add_grid_controller.dart`, find `_loadMore`, and under `rowsRead: latest.rowsRead + page.length,` add the line `selected: const {},`. Run it again: the test `pages of 200 from the phone, the next near the end, and the choice survives every page` fails, because loading page two forgot what you picked on page one. Delete the line and run it again to see it pass.

**Decisions:** D-114 (all of this section), with D-111 (the owner's rulings), D-112 (the folder pages), D-113 (the folder rules and the marks), D-74 (thumbnails), D-85 (snacks on the root messenger) and D-86 (one tap opens one page) as background.

## 6. Manual mode

**What we built:** a small sheet called "Pick videos yourself". When TakeTray can see only some of your videos (or none), **Add videos** opens this sheet instead of the folder list. Its main button, **Open photo picker**, opens Android's own photo picker. You choose videos there, and TakeTray adds them to To tag or to the reel, with the same snack and **Undo** as before. A second button, **Allow full access instead**, asks Android for full access, so next time you get the folder list.

It also brought three smaller things:

- Every add now ends with the same snack, whichever way you added. If some videos could not be added, the snack has a second line: "Couldn't add 2 videos."
- A reel's page now shows the access banner, the same one To tag has. If you lose access while the folder list is open, the app closes it and takes you back to where you were. Now the page you land on says why.
- The old "On since 9:41 · Manual mode: add clips yourself" line on the Shooting mode card already existed. Its tests got one more case: the line never shows while Shooting mode is off.

**Why TakeTray needs it:** Android lets you share only some videos with an app ("Select photos and videos"), and you can say no to video access altogether. The folder list needs full access, so without it **Add videos** would have nothing to show. The photo picker needs no permission at all: Android shows the picker itself, and the app only gets the videos you choose. That makes it the one way to add a video that always works.

**Key ideas:**

- **Which screen opens is decided by a fresh look at the access.** If reading the access fails, we still open the sheet, because the picker needs no permission:

  ```dart
  if (access?.level != MediaAccessLevel.full) {
    await showManualPickSheet(context, target: target, onOutcome: ...);
    return;
  }
  ```

  Read it like this: anything that is not a known "full" means Manual mode. Only a known "full" opens the folder list.

- **One tap, one picker.** Two guards, so that a quick double tap cannot open two pickers. The first is `OpenOnce.openSlow`, the same helper the screens use to open one page once. The second is a flag: both buttons turn off while the picker is open. Each guard has its own test, and each test fails when only that guard is removed.

  ```dart
  void _openPicker() => _once.openSlow((_) => _pick());
  ...
  onPressed: _picking ? null : _openPicker,
  ```

- **Cancel is not an error.** If you close the picker without choosing, nothing is added and nothing is shown. If Android says a picker is already open (the code `busy`), nothing is shown either, and the sheet stays so you can try again. Any other failure says "Couldn't add videos. Try again."

- **What you pick is never lost.** The sheet reports its result through a callback that is called even if you swiped the sheet away while the picker was open. A test does exactly that and checks the videos still arrive.

- **One snack, two lines.** A new snack replaces the one on screen. If "Couldn't add 2 videos." were its own snack, it would push out the snack with **Undo**. So both messages share one snack, one line under the other. When nothing at all was added and nothing was there already, only the "Couldn't add" line shows, because "Already added" would be untrue.

- **No clean-up between the pick and the add.** Android lets an app keep a limited number of saved permissions, and TakeTray gives back the ones that no clip uses (section 4). Right after a pick, the new permissions belong to no clip yet. A clean-up at that moment would give them back, and the clip would stop working. So the clean-up runs only once, when the app starts, and this sheet never starts it. A test holds the picker open, finishes the pick, and checks the bridge never saw a clean-up call.

- **A picked clip and its folder twin.** A picked clip is known by its address. A folder clip is known by its volume and number. The size, length and date are not an identity (D-57), so if you add a video through the picker and, after getting full access, add the same video from its folder, you get two clips. Nothing breaks: each is added once and can be undone. We chose not to merge them by guessing, because two different takes can look alike. It is noted in `docs/later.md`.

- **Tests that can fail.** All the new tests were written first, and 36 of them failed for the real reasons (no sheet, no banner, no second line in the snack). After the code was written, key lines were broken on purpose, one at a time, and each broke a named test before it was put back: the access check (three ways: limited, denied, and a failed read), the two double-tap guards, the cancel branch, the `busy` branch, the failure message, **Allow full access instead** (not asked, not closing, not turned off), the two "Couldn't add" lines, the "Already added" line, a clean-up added between the pick and the add, the reel page's banner, and the Shooting mode card line (always shown, shown when off, shown when access is unknown).

**Where it lives:** `app/lib/features/add_videos/views/manual_pick_sheet.dart` (the sheet), `app/lib/features/add_videos/views/open_add_videos.dart` (which screen opens, and the snack), `app/lib/features/reels/views/reel_detail_screen.dart` (the banner) and the new texts in `app/lib/l10n/app_en.arb`. Tests: `app/test/features/add_videos/views/manual_pick_sheet_test.dart`, with more cases in `add_videos_entry_test.dart`, `add_grid_screen_test.dart` and `shooting_mode_section_test.dart`; screenshots in `add_videos_golden_test.dart` (macOS only).

**Try it yourself:** see the double-tap guard work. From the repo root:

```bash
cd app && ../tool/flutter test test/features/add_videos/views/manual_pick_sheet_test.dart --plain-name "a double tap opens the picker once"
```

It ends with `All tests passed!`. Now open `app/lib/features/add_videos/views/manual_pick_sheet.dart`, find `_openPicker`, and change it to `void _openPicker() => unawaited(_pick());`. Run the test again: it fails, because two quick taps now open the picker twice. Put the line back and run it again to see it pass.

**Decisions:** D-115 (all of this section), with D-111 (the owner's rulings), D-112 (the photo picker and the clean-up), D-113 (what "not kept" means), D-114 (the folder list and who closes when), D-57 (a clip's identity) and D-86 (one tap opens one page) as background.

