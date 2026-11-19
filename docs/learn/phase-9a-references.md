# Learning guide: Phase 9A, References in the app

This guide explains how TakeTray shows and uses the links saved on a reel: the References section on the reel page, the sheet to add a link or edit its label, opening a link in its app, the link field in the reel form, the badge on Home's reel cards, and the References row and sheet on the Shooting mode card. It ends with how it was checked on a real Samsung Galaxy S24 Ultra.

Every snippet is real code from this repository. You don't need to know Flutter or Android well to follow it; basic programming knowledge is enough.

## How to read this guide

- **Order.** The sections follow the order the phase was built. Step 1 was the plan and decision D-153, so it has no section here.
- **Names you will meet.** `D-xx` is an entry in `docs/decisions.md`; this phase's start at D-153.
- **Commands.** Run them from the repository root, through the wrappers in `tool/`.
- **Every section has the same shape:** **what we built**, **why TakeTray needs it**, **key ideas** (with short snippets of real code), **where it lives**, **try it yourself** and **decisions**.

## Contents

2. [Link rules, remove with Undo, a reel with its link](#2-link-rules-remove-with-undo-a-reel-with-its-link)
3. [Opening a link and the source apps' icons](#3-opening-a-link-and-the-source-apps-icons)
4. [The reference card's menu and large text](#4-the-reference-cards-menu-and-large-text)
5. [The Add / edit reference sheet](#5-the-add--edit-reference-sheet)
6. [The References section and the Home badge](#6-the-references-section-and-the-home-badge)
7. [The reel form's link field](#7-the-reel-forms-link-field)
8. [Shooting mode's References](#8-shooting-modes-references)
9. [On the S24](#9-on-the-s24)

## 2. Link rules, remove with Undo, a reel with its link

### What we built

The data side of references. Three pure functions read a link out of text people paste or type (`firstLinkIn`, `typedLink`) and shorten one for display (`shortLink`); a fourth, `referenceKindOf`, says what kind of page a saved link points to. Removing a reference now hands back a record so the screen can offer Undo. `createWithReference` saves a new reel and its first link in one step. `watchAll` lists every reference.

Nothing on screen changes yet. The screens in sections 3 to 8 use these.

### Why TakeTray needs it

People share a whole sentence, not a link: `Title https://vm.tiktok.com/ZM8x/` or `see (https://youtu.be/a1).` The saving code, `normalizeReferenceUrl`, refuses anything with a space in it (D-55), so something has to find the link first. Every removal in TakeTray can be undone for a few seconds; references were the one exception. And a reel made from a shared link must never be left with no link because the second save failed.

### Key ideas

**1. Find the link, then let the one cleaner decide.** `firstLinkIn` only finds and trims the end of a sentence; it does not judge whether the link is good:

```dart
final link = match.group(0)!.replaceFirst(_trailingPunctuation, '');
```

`normalizeReferenceUrl` stays the single place that cleans a link, so the same page saved twice is still one reference.

**2. `/reel/` and `/p/` are the same after cleaning.** Saved Instagram links are rewritten to `/p/CODE/`, so a reel and a post cannot be told apart later. That is why the card says "Instagram" for both, and only a profile reads differently:

```dart
ReferenceSource.instagram =>
  url.path.startsWith('/p/')
      ? ReferenceKind.instagram
      : ReferenceKind.instagramProfile,
```

**3. An Undo record is a snapshot taken inside the same transaction.** `delete` reads the row and the reel's time, deletes, and writes the new time, all together, so the record cannot disagree with what happened:

```dart
final before = await _updatedAtOf(row.reelId);
...
return ReferenceRemoveUndo(
  reference: _toReference(row),
  touch: before == null ? null : ReelTouch(reelId: row.reelId, before: before, after: after),
);
```

**4. Undo is careful about a world that moved.** The reference comes back with its old id, label and time, but not when the reel is gone, and not when the same link was saved again meanwhile. The reel's "last changed" time goes back only while it is still the value the removal wrote, so a rename since is kept.

**5. One transaction for a reel and its link.** `createWithReference` checks everything it can first, then inserts both rows inside `_db.transaction`. If the reference insert fails after the reel is in, the whole transaction rolls back and there is no reel.

### Where it lives

- `app/lib/domain/rules/reference_links.dart`: the link rules and `ReferenceKind`.
- `app/lib/domain/models/undo_record.dart`: `ReferenceRemoveUndo`.
- `app/lib/data/repositories/references_repository.dart`: `delete` (now returns the record) and `watchAll`.
- `app/lib/data/repositories/undo_writer.dart`: `_undoReferenceRemove`.
- `app/lib/data/repositories/reels_repository.dart`: `createWithReference`.
- Docs: `docs/flow.md` ("References, VN folders, settings and time zones", "Undo"), D-154.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/domain/rules/reference_links_test.dart \
  test/data/repositories/undo_writer_references_test.dart \
  test/data/repositories/references_repository_test.dart \
  test/data/repositories/reels_repository_test.dart
```

Then break one thing on purpose. In `reference_links.dart`, change `_trailingPunctuation` to `r'$^'` (it never matches) and run the first file: the tests that strip a `)` or a `.` fail. Put it back.

### Decisions

- D-154: link rules, `ReferenceKind`, `delete` returns a `ReferenceRemoveUndo`, Undo skips a reel that is gone or a link saved again, `createWithReference` in one transaction, `watchAll`.

## 3. Opening a link and the source apps' icons

### What we built

Two small pieces the reference card needs. A new **Links bridge** opens a saved link in whatever app or browser the phone chooses. And a **source icons** provider reads the real icons of the Instagram, YouTube and TikTok apps, so a card can show the app the link came from.

Nothing on screen changes yet; the card in section 6 uses both.

### Why TakeTray needs it

Tapping a reference should take you to it, ideally in the app you use. Android decides which app opens a web link, so TakeTray only has to ask. But a link comes from text someone pasted, so it must not start anything odd: an address like `javascript:...` or `file:///...` is refused. The source icons come from the phone itself, so TakeTray never draws another company's logo; when the app isn't installed the card shows a plain link symbol.

### Key ideas

**1. Only web addresses open.** Kotlin checks the scheme and that there is a host before starting anything:

```kotlin
val scheme = uri.scheme?.lowercase()
return (scheme == "http" || scheme == "https") && !uri.host.isNullOrEmpty()
```

**2. "Nothing can open it" is an answer, not a crash.** If the phone has no browser, Android throws `ActivityNotFoundException`; the bridge turns that into `false`, and the screen can say "No app on this phone can open this link."

**3. Errors never carry the address.** An unexpected failure becomes `openLink failed: SecurityException`: the class name only. The address could be private, so it never reaches a log (D-10).

**4. Ask the phone once for all the icons.** All four package names go in one call, and each source takes the first installed one. TikTok has two packages (by region), so it tries both in order:

```dart
for (final name in names) {
  final icon = iconOf[name];
  if (icon != null) { icons[source] = icon; break; }
}
```

**5. Android hides other apps unless the manifest names them.** The four source packages join the three editors in `<queries>`. Two tests, one in Dart and one in Kotlin, fail if the list differs from the code.

### Where it lives

- `app/pigeons/links_api.dart`: the contract.
- `app/android/app/src/main/kotlin/app/taketray/links/LinksHostApiImpl.kt`: the Kotlin side.
- `app/lib/platform/links_bridge.dart`: `LinksBridge`, `PigeonLinksBridge`, `linksBridgeProvider`.
- `app/lib/features/references/view_models/source_icons.dart`: `sourceAppPackages`, `sourceIconsProvider`.
- `app/android/app/src/main/AndroidManifest.xml`: `<queries>`.
- Docs: `docs/flow.md` ("Links bridge and the source icons"), D-155.

### Try it yourself

From the repository root:

```sh
cd app && ../tool/flutter test test/platform/links_bridge_test.dart \
  test/features/references/view_models/source_icons_test.dart \
  test/platform/editor_packages_manifest_test.dart
cd .. && tool/test_android --tests 'app.taketray.links.*'
```

Then break one thing on purpose. In `LinksHostApiImpl.kt`, make `isWebLink` return `true` for any scheme and run the Kotlin tests: the `javascript:` and `file:` test fails. Put it back.

### Decisions

- D-155: the Links bridge, only `http`/`https` open, `ActivityNotFoundException` is false, the source packages and icons, the seven `<queries>` entries.
