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

## 4. The reference card's menu and large text

### What we built

The design system's reference card (the row for one saved link) got two changes. Its ⋮ button now opens a real menu, so a screen can offer "Edit label" and "Remove" without the card knowing what they do. And at large text sizes the word "Open" disappears, leaving just its icon.

Nothing on screen changes yet: the References section (section 6) is the first user of the card.

### Why TakeTray needs it

A reference card has three jobs: open the link, edit its label, remove it. Opening is the whole card, so the other two need a menu, and the app already has one menu component. At 200 % text size the word "Open" took half the row, leaving the title a few letters per line. The icon already says "this leaves the app", so at large sizes it is enough.

### Key ideas

**1. The card does not know what the menu does.** It is generic over the value of an entry, and only reports which value was chosen:

```dart
TtReferenceCard<String>(
  // ...
  moreItems: const [TtMenuItem('edit', 'Edit label'), TtMenuItem('remove', 'Remove')],
  onMoreSelected: (value) { /* 'edit' or 'remove' */ },
)
```

**2. No items, no button.** The ⋮ shows only when there are items and someone listens for the choice; a button that opens nothing would be a trap for a screen-reader user.

**3. Ask how big 14 sp really is.** Android scales text in ways that are not a single factor, so the card asks the scaler what a 14 sp text becomes and compares it with 21 (150 %):

```dart
final iconOnly =
    MediaQuery.textScalerOf(context).scale(TtMetrics.referenceOpenProbeSize) >=
    TtMetrics.referenceOpenIconOnlyFrom;
```

**4. Hiding the word does not hide the meaning.** The main button's spoken label ("Open reference: ..., Instagram") is the same at every size; only the picture changed.

### Where it lives

- `packages/taketray_ui/lib/src/components/reference_card.dart`: `TtReferenceCard<T>`, `_OpenMark`.
- `packages/taketray_ui/lib/src/theme/tt_metrics.dart`: `referenceOpenProbeSize`, `referenceOpenIconOnlyFrom`.
- `packages/taketray_ui/test/components/reference_card_test.dart` and `reference_card_golden_test.dart`.
- `widgetbook/lib/components/reference_card.dart`: the playground.
- Docs: `docs/flow.md` ("The reference card's menu and large-text Open"), D-156.

### Try it yourself

```sh
cd packages/taketray_ui && ../../tool/flutter test test/components/reference_card_test.dart
```

Then break one thing on purpose. In `tt_metrics.dart`, change `referenceOpenIconOnlyFrom` from 21 to 28 (200 %) and run it again: the 150 % test fails. Put it back.

### Decisions

- D-156: the card's `moreItems` / `onMoreSelected` menu, and the icon-only Open mark from 150 % text.

## 5. The Add / edit reference sheet

### What we built

The sheet that saves a link on a reel, and the same sheet in "Edit label" form for a link already saved. You type or paste a link, give it an optional label of up to 60 characters, and Save. A **Paste** button inside the Link field reads the clipboard and takes the first link out of it. Saving shows "Reference saved" with Undo.

Nothing opens it yet: the References section (section 6) and the Shooting mode sheet (section 8) will.

### Why TakeTray needs it

A link a person copied in Instagram is the start of every reference. Android 12 and later tell the user "TakeTray pasted from your clipboard" whenever an app reads it, so the app reads it only when the user taps Paste. And what people type is messy: `hello.` or `.com` or a number like `3.5` must not become a card that opens nowhere.

### Key ideas

**1. The clipboard is read in one place.** Only the Paste button's handler calls it, and a clipboard that is empty, an image or broken just means "no link":

```dart
text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
...
final link = text == null ? null : firstLinkIn(text);
```

**2. A result, not an exception, for what the user can fix.** The controller returns one of five results and the sheet switches over them, so the compiler makes sure every case is handled:

```dart
switch (await controller.saveNew(_link.text, _label.text)) {
  case ReferenceSaved(:final reference): ...
  case ReferenceNotALink(): ...
  case ReferenceAlreadyIn(:final reelName): ...
  case ReferenceLabelTooLong() || ReferenceSaveFailed(): ...
}
```

**3. One flight at a time.** A double tap on Save must make one reference. The controller keeps the running save and hands it to a second caller, and the sheet also returns early while a save runs:

```dart
final running = _newInFlight;
if (running != null) return running;
```

**4. "Looks like a link" has rules.** `typedLink` strips the full stop that ends a sentence, then insists the address has a real host: at least two parts, each made of letters, digits, `-` or `_`, and a last part that is not just digits (except an IP address). `user@example.com` is an email, not a link.

**5. Undo of an add is a delete.** The Undo button deletes the new reference. If it is already gone, nothing happens and nothing fails.

**6. The icon is the phone's, or a plain link symbol.** TakeTray never draws a logo. If the source app is installed its icon is shown; otherwise a neutral tile with a link symbol:

```dart
bytes == null ? link : Image.memory(bytes, ..., errorBuilder: (context, _, _) => link)
```

### Where it lives

- `app/lib/features/references/views/reference_sheet.dart`: `showReferenceSheet` and its state.
- `app/lib/features/references/view_models/reference_form_controller.dart`: `saveNew`, `saveLabel`, the five results.
- `app/lib/features/references/views/reference_text.dart` and `reference_source_icon.dart`: the helpers the cards use.
- `app/lib/domain/rules/reference_links.dart`: `typedLink`.
- Tests: `app/test/features/references/` and `app/test/domain/rules/reference_links_test.dart`.
- Docs: `docs/flow.md` ("The Add / edit reference sheet"), D-157.

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/references test/domain/rules/reference_links_test.dart
```

Then break one thing on purpose. In `reference_sheet.dart`, call `Clipboard.getData` from `initState`: the test "nothing touches the clipboard until Paste" fails. Put it back. Another: in `reference_form_controller.dart` delete the two lines that return `_newInFlight`: "double Save saves once" fails.

### Decisions

- D-157: the sheet, Paste on tap, the controller's results, `typedLink` never giving junk, Undo through the snack's hook, the shared helpers.

## 6. The References section and the Home badge

### What we built

The reel page now shows the links saved on it, right under the reel's name and shot ideas. A reel with none shows one dashed "Add reference" row. A reel with some shows "References · 3", a small **Add** button, and a card for each link, newest first. Tapping a card opens the link in Instagram, YouTube, TikTok or the browser, whichever the phone picks. Each card's ⋮ menu has **Edit label**, **Copy link** and **Remove**; Remove is instant, with **Undo** in the snack. When a reel has links but no shot ideas, a note under the cards says "Write the shots you need" and its button opens the reel's details with the Shot ideas box ready to type in.

On Home, a reel card with links shows a small badge with their number. Tapping the badge opens the reel page already scrolled to the References section, which flashes once so the eye finds it. The empty reel page also says that a reel can be shared from Instagram straight into TakeTray.

### Why TakeTray needs it

The links were saved in Phases 2 and 5 but nothing showed them. A creator saves a reel to copy its style, then needs to watch it again when planning the shots, and again while shooting. The section puts them next to the clips; the badge makes them one tap away from Home.

### Key ideas

**1. The section is a sliver that watches its own list.** It sits in the reel page's `CustomScrollView` between the header and the clips, and watches the references of its reel. Until the first list arrives it draws nothing, so the page never shows "Add reference" and then swaps it for cards:

```dart
final references = ref.watch(reelReferencesProvider(widget.reel.id)).value;
if (references == null) {
  return const SliverToBoxAdapter(child: SizedBox.shrink());
}
```

**2. Actions in a view model, words in the view.** `ReferenceActions` opens, copies and removes, and logs only ids and error types. The section decides what to say. Removing returns the Undo record that the repository made, and the snack hands it back to the shared Undo code:

```dart
final undo = await ref.read(referenceActionsProvider).remove(reference.id);
if (undo != null) snacks.showUndo(l10n.referenceRemovedSnack, undo);
```

**3. Say only what Android does not.** Android 13 and later show their own "Copied" bubble, so TakeTray says "Link copied" only on older phones. If the version cannot be read, the app assumes a newer phone and says nothing:

```dart
if (sdk < _ownCopyConfirmationFrom) {
  snacks.show(l10n.referenceLinkCopiedSnack, icon: Symbols.content_copy_rounded);
}
```

**4. Scroll, then flash, once, and never when animations are off.** After the first frame that has the list, the section asks its scroll view to bring it to the top. Only when that finishes, and only if the phone allows animations, does it make an animation controller for the 600 ms highlight. With "Remove animations" on, no controller exists, so no ticker can run:

```dart
await Scrollable.ensureVisible(box, duration: still ? Duration.zero : motion.medium2, ...);
if (still || !mounted) return;
setState(() {
  _flash = AnimationController(vsync: this, duration: _flashLength)..forward();
});
```

**5. Join in the provider, not in SQL.** Home's reel list comes from one large query that runs again on every clip change. The reference counts come from a second, small stream, and Home's provider joins them by reel id. If the counts cannot be read, Home still shows the reels, just without badges:

```dart
summary.copyWith(referenceCount: referenceCount[summary.reel.id] ?? 0)
```

**6. One guard for two buttons.** The badge and the card share the same `OpenOnce`, so a quick tap on both opens one page.

### Where it lives

- `app/lib/features/references/views/references_section.dart`: `ReferencesSection`, the cards, the prompt, the arrival.
- `app/lib/features/references/view_models/reference_actions.dart`: `ReferenceActions`, `reelReferencesProvider`.
- `app/lib/features/reels/views/reel_detail_screen.dart`: where the section goes, `focusReferences`, the empty reel's second line.
- `app/lib/features/reels/view_models/home_controller.dart` and `views/reels_screen.dart`: `referenceCountsProvider`, the join, the badge.
- `app/lib/router/routes.dart` and `app_router.dart`: `Routes.reelReferences` (`?refs=1`).
- `app/lib/features/reels/views/reel_form_sheet.dart`: `showReelForm(focusDescription:)`.
- Tests: `app/test/features/references/views/references_section_test.dart`, `view_models/reference_actions_test.dart`, the reel page, Home and router tests; `app/test/support/fake_links_bridge.dart`.
- Docs: `docs/flow.md` ("The References section", "Home, the Reels tab", "Opening a reel"), D-158.

### Try it yourself

```sh
cd app && ../tool/flutter test test/features/references test/features/reels/views/reels_screen_test.dart test/router/app_router_test.dart
```

Then break one thing on purpose. In `references_section.dart`, change `if (still || !mounted) return;` to `if (!mounted) return;`: the test "with Remove animations it jumps into view with no flash and no ticker" fails, because the highlight now runs. Put it back. Another: in `home_controller.dart` read `referenceCount[summary.reel.id + 1]`: the badge tests fail, because each card shows its neighbour's count.

### Decisions

- D-158: the section and its three states, the card menu (Remove with Undo, no dialog), `ReferenceActions`, "Link copied" before Android 13 only, the scroll and 600 ms flash, the Home join and badge, the empty reel's second line, `focusDescription`.
