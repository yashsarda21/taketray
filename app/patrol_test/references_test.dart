import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/references/views/references_section.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/links_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/lifecycle.dart';
import 'support/onboarded.dart';
import 'support/patrol_links_bridge.dart';
import 'support/test_media.dart' show testFolder;
import 'support/waiting.dart';

/// References on the S24 (Phase 9A, Task 9, D-161): add a reference with a
/// typed link, paste one, make a reel with a reference link, and the
/// References row of Shooting mode.
///
/// Every flow pumps the app onboarded (`onboardedOverrides`), starts by
/// deleting the reels of an earlier run and ends (also when it fails) by
/// putting back what it changed, so no flow depends on another, on the order
/// or on a count made by another. The words are the app's own
/// (`AppLocalizations`), never typed twice.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`). The flows read and write its own database (reels
/// named `TakeTray Test *`, with their references) and nothing else: no media
/// permission is asked, no video is made, no file is read.
///
/// - **No link is ever opened.** `linksBridgeProvider` is overridden with
///   `PatrolLinksBridge` (`support/patrol_links_bridge.dart`): it records the
///   link and answers true, so no browser, Instagram or YouTube starts in
///   front of the test. What a tap on a card sends is checked by the
///   bridge's record. The real bridge, Android's choice of app and the two
///   apps are on the owner's hand-check list (`docs/dev-setup.md`, "Phase 9A
///   check").
/// - **The watched folder is the test folder** while a flow runs (as in
///   `settings_test.dart`), put back afterwards, so nothing the background
///   does while Shooting mode is on can name another folder.
/// - **Shooting mode** (flow 4) is turned on in the database
///   (`PhoneStateRepository.turnShootingOn`), not with the card's switch:
///   the switch asks for the media and notification permissions, which
///   `app.taketray.dev` has not been given in a fresh run, and references
///   need neither. The permission asks are the other files' flows. It is
///   turned off in the tear-down through the controller (which cancels the
///   background job), with the settings put back and a sync flush, as the
///   other files do.
/// - **The clipboard** is written by flow 2 (a caption with a link), and
///   emptied in its tear-down: nothing is read from it except by the app's
///   own Paste.
/// - Text is typed with `enterText(..., hideKeyboard: false)` (the 10A
///   harness rule) and the field is unfocused before a button is tapped, so
///   the keyboard is not over it. Android's Back is not used (only the
///   screen's own Back button): D-143.
///
/// **Flows** (each a `patrolTest`):
/// 1. A typed link and a label: the Add row, the Add reference sheet, the
///    card, a tap that reaches the bridge with the stored link, one the
///    phone cannot open ("No app on this phone can open this link."), Edit
///    label, Remove, Undo (the same reference back), and Home with the
///    badge.
/// 2. Paste: a clipboard with no link says so and fills nothing, then a
///    caption with a link is pasted (the link only), Save, the card, the
///    Home badge shows 1, and its tap lands on the reel with the section.
/// 3. The reel form: a new reel with a Reference link; the section shows it.
/// 4. Shooting mode: two Collecting reels with references; the card's
///    References row opens the sheet, a card tap reaches the bridge, one
///    group collapses, and its header opens that reel at its References.
///
/// **What these flows cannot show** (hand checks in `docs/dev-setup.md`):
/// real links, Android's own paste message, TalkBack, 200 % text, dark mode,
/// the colours and the app icons.
void main() {
  _flowTest(
    '1. A typed link and a label: open, Edit label, Remove, Undo',
    _typed,
  );
  _flowTest('2. Paste, then the Home badge opens the reel', _paste);
  _flowTest('3. A new reel with a Reference link', _reelForm);
  _flowTest(
    '4. Shooting mode: the References sheet',
    _shootingSheet,
    shootingMayBeOn: true,
  );
}

// =============================================================== the flows

/// Flow 1.
Future<void> _typed(_Env env) async {
  final $ = env.$;
  final reel = await _makeReel(env, _reelOne);
  final detail = $(ReelDetailScreen);
  final section = $(ReferencesSection);

  await _openReelFromHome(env, _reelOne);
  // A reel with no references: the dashed Add row, and nothing else.
  await waitFor(
    $,
    () => section.$(_l10n.referencesAddRowTitle).exists,
    what: 'the Add reference row on a reel with no references',
  );
  expect(await _referencesOf(env, reel.id), isEmpty);

  // Add one with a typed link and a label.
  await section.$(_l10n.referencesAddRowTitle).tap();
  await _waitForSheet(env, _l10n.referenceSheetTitleAdd);
  await _type($, _fieldOf(_l10n.referenceLinkLabel), _linkOne);
  await _type($, _fieldOf(_l10n.referenceLabelLabel), _labelOne);
  await _closeKeyboard($);
  await $(TtSheet).$(_l10n.referenceSaveButton).tap();
  await _waitForSheetToClose($);
  await waitFor(
    $,
    () => section.$(_labelOne).exists,
    what: 'the card titled with its label',
  );
  expect(section.$(_l10n.referencesHeader(1)).exists, isTrue);
  expect(
    section.$(_l10n.referenceCardSubtitle(_hostOne, _shortOne)).exists,
    isTrue,
    reason: 'the card says what the link is and the short link',
  );
  await waitFor(
    $,
    () => find.text(_l10n.referenceSavedSnack).evaluate().isNotEmpty,
    what: '"${_l10n.referenceSavedSnack}"',
  );
  final saved = await _referencesOf(env, reel.id);
  expect(saved, hasLength(1));
  expect(saved.single.url, _linkOne);
  expect(saved.single.label, _labelOne);
  final referenceId = saved.single.id;

  // A tap reaches the bridge with the stored link, and nothing opens for
  // real.
  expect(env.links.opened, isEmpty, reason: 'nothing opened yet');
  await section.$(_labelOne).tap();
  await waitFor(
    $,
    () => env.links.opened.isNotEmpty,
    what: 'the card tap to reach the links bridge',
  );
  expect(env.links.opened, [_linkOne]);
  await _expectAbsent(
    $,
    present: section.$(_labelOne),
    presentWhat: 'the card, after the open',
    absent: find.text(_l10n.referenceOpenFailed),
    absentWhat: '"${_l10n.referenceOpenFailed}" after an open that worked',
  );

  // A phone with no app for the link: the snack says so.
  env.links.answer = false;
  await section.$(_labelOne).tap();
  await waitFor(
    $,
    () => find.text(_l10n.referenceOpenFailed).evaluate().isNotEmpty,
    what: '"${_l10n.referenceOpenFailed}"',
  );
  expect(env.links.opened, [_linkOne, _linkOne]);
  env.links.answer = true;

  // Edit label: the sheet names the reel and the source, takes the new
  // label, and the card changes.
  await _tapMore($, _labelOne);
  await waitFor(
    $,
    () => $(_l10n.referenceMenuEditLabel).exists,
    what: 'the card menu',
  );
  await $(_l10n.referenceMenuEditLabel).tap();
  await _waitForSheet(env, _l10n.referenceSheetTitleEdit);
  expect(
    $(TtSheet).$(_l10n.referenceSheetSubtitleEdit(_reelOne)).exists,
    isTrue,
  );
  await _type($, _fieldOf(_l10n.referenceLabelLabel), _labelTwo);
  await _closeKeyboard($);
  await $(TtSheet).$(_l10n.referenceSaveButton).tap();
  await _waitForSheetToClose($);
  await waitFor(
    $,
    () => section.$(_labelTwo).exists,
    what: 'the card with the new label',
  );
  await _expectAbsent(
    $,
    present: section.$(_labelTwo),
    presentWhat: 'the card with the new label',
    absent: find.descendant(
      of: find.byType(ReferencesSection),
      matching: find.text(_labelOne),
    ),
    absentWhat: 'the old label on the card',
  );
  final renamed = await _referencesOf(env, reel.id);
  expect(renamed.single.label, _labelTwo);
  expect(renamed.single.id, referenceId, reason: 'the same reference');

  // Remove: at once, with Undo. The reel has no references; Undo brings the
  // same one back, not a second.
  await _tapMore($, _labelTwo);
  await waitFor(
    $,
    () => $(_l10n.referenceMenuRemove).exists,
    what: 'the card menu',
  );
  await $(_l10n.referenceMenuRemove).tap();
  await waitFor(
    $,
    () =>
        find.text(_l10n.referenceRemovedSnack).evaluate().isNotEmpty &&
        section.$(_l10n.referencesAddRowTitle).exists,
    what: '"${_l10n.referenceRemovedSnack}" and the Add row',
  );
  expect(section.$(_labelTwo).exists, isFalse);
  expect(await _referencesOf(env, reel.id), isEmpty);
  await $(find.text(_l10n.undo).first).tap();
  await waitFor(
    $,
    () => section.$(_labelTwo).exists,
    what: 'the card to come back after Undo',
  );
  final back = await _referencesOf(env, reel.id);
  expect(back, hasLength(1), reason: 'Undo adds one reference, not two');
  expect(back.single.id, referenceId, reason: 'Undo puts back the same one');
  expect(back.single.url, _linkOne);
  expect(back.single.label, _labelTwo);

  // Back to Home: the card has its badge with the one reference.
  await _tapBack($);
  final card = $(TtReelCard).containing(_reelOne);
  await waitFor(
    $,
    () => $(ReelsScreen).exists && card.$('1').exists,
    what: 'Home with the reel card and its badge "1"',
  );
  expect(detail.exists, isFalse, reason: 'the reel page is gone');
  expect(env.links.opened, [_linkOne, _linkOne], reason: 'nothing else opened');
}

/// Flow 2.
Future<void> _paste(_Env env) async {
  final $ = env.$;
  final reel = await _makeReel(env, _reelPaste);
  final section = $(ReferencesSection);
  final sheet = $(TtSheet);

  await _openReelFromHome(env, _reelPaste);
  await waitFor(
    $,
    () => section.$(_l10n.referencesAddRowTitle).exists,
    what: 'the Add reference row',
  );

  // The clipboard holds a caption WITH a link while the sheet opens: if the
  // sheet read it on open (the spec: nothing is read until Paste is tapped),
  // the link would be in the field. With a no-link caption that read would
  // leave the field empty too and prove nothing.
  env.clipboardTouched = true;
  await Clipboard.setData(const ClipboardData(text: _captionWithLink));
  await section.$(_l10n.referencesAddRowTitle).tap();
  await _waitForSheet(env, _l10n.referenceSheetTitleAdd);
  final link = _fieldOf(_l10n.referenceLinkLabel);
  await pumpFor($, const Duration(seconds: 1));
  expect(
    _textOf($, link),
    isEmpty,
    reason: 'opening the sheet reads nothing from the clipboard',
  );
  // Now a caption with no link: the Paste button says there is no link and
  // fills nothing.
  await Clipboard.setData(const ClipboardData(text: _captionWithoutLink));
  await sheet.$(_l10n.referencePasteButton).tap();
  await waitFor(
    $,
    () => sheet.$(_l10n.referenceNoLinkOnClipboard).exists,
    what: '"${_l10n.referenceNoLinkOnClipboard}"',
  );
  expect(
    _textOf($, link),
    isEmpty,
    reason: 'a caption with no link fills nothing',
  );

  // A caption with a link: only the link goes in, and the message goes.
  await Clipboard.setData(const ClipboardData(text: _captionWithLink));
  await sheet.$(_l10n.referencePasteButton).tap();
  await waitFor(
    $,
    () => _textOf($, link) == _linkPaste,
    what: 'the pasted link in the Link field',
  );
  expect(
    sheet.$(_l10n.referenceNoLinkOnClipboard).exists,
    isFalse,
    reason: 'the message goes with a good paste',
  );

  await _closeKeyboard($);
  await sheet.$(_l10n.referenceSaveButton).tap();
  await _waitForSheetToClose($);
  await waitFor(
    $,
    () => section.$(_shortPaste).exists,
    what: 'the card titled with the short link (no label)',
  );
  expect(section.$(_hostOne).exists, isTrue, reason: 'its subtitle: the host');
  expect(section.$(_l10n.referencesHeader(1)).exists, isTrue);
  final saved = await _referencesOf(env, reel.id);
  expect(saved, hasLength(1));
  expect(saved.single.url, _linkPaste);
  expect(saved.single.label, isNull);

  // Home: the badge shows 1, and its tap lands on the reel with its section.
  await _tapBack($);
  final card = $(TtReelCard).containing(_reelPaste);
  await waitFor(
    $,
    () => $(ReelsScreen).exists && card.$('1').exists,
    what: 'Home with the reel card and its badge "1"',
  );
  await card.$('1').tap();
  await waitFor(
    $,
    () =>
        $(ReelDetailScreen).exists &&
        $(ReelDetailScreen).$(_reelPaste).exists &&
        section.$(_l10n.referencesHeader(1)).visible,
    what: 'the reel page with its References section on screen',
  );
  expect(
    section.$(_l10n.referencesHeader(1)).visible,
    isTrue,
    reason: 'the badge tap scrolled the References section into view',
  );
  expect(section.$(_shortPaste).exists, isTrue, reason: 'the card is there');
  expect(env.links.opened, isEmpty, reason: 'nothing was opened');
}

/// Flow 3.
Future<void> _reelForm(_Env env) async {
  final $ = env.$;
  final home = $(ReelsScreen);
  await waitFor(
    $,
    () => home.$(_l10n.reelsNewReel).exists,
    what: 'the New reel button on Home',
  );
  await home.$(_l10n.reelsNewReel).tap();
  await _waitForSheet(env, _l10n.reelFormTitleNew);
  // Informative, not a check: a widget test hinted that the name field may
  // not take the focus when the form opens (hand check 9).
  await $.tester.pump(const Duration(milliseconds: 500));
  debugPrint(
    'new reel form: name field focused on open: '
    '${_focused($, _fieldOf(_l10n.reelNameLabel))}',
  );

  await _type($, _fieldOf(_l10n.reelNameLabel), _reelFormName);
  await _type($, _fieldOf(_l10n.reelLinkLabel), _linkShort);
  await _closeKeyboard($);
  await $(TtSheet).$(_l10n.reelCreateButton).tap();
  await _waitForSheetToClose($);

  final card = $(TtReelCard).containing(_reelFormName);
  await waitFor($, () => card.exists, what: 'the new reel card on Home');
  final reel =
      (await env.container.read(reelsRepositoryProvider).watchAll().first)
          .singleWhere((r) => r.name == _reelFormName);
  final saved = await _referencesOf(env, reel.id);
  expect(saved, hasLength(1), reason: 'the reel was made with its reference');
  expect(saved.single.url, _linkShort);
  expect(saved.single.label, isNull);

  // The reel's page shows it in the section: its short link, what it is.
  await waitFor($, () => card.$('1').exists, what: 'the badge "1" on the card');
  await card.tap();
  final section = $(ReferencesSection);
  await waitFor(
    $,
    () =>
        $(ReelDetailScreen).exists &&
        section.$(_l10n.referencesHeader(1)).exists,
    what: 'the reel page with "${_l10n.referencesHeader(1)}"',
  );
  expect(section.$(_shortShort).exists, isTrue, reason: 'the card: short link');
  expect(
    section.$(_l10n.referenceKindYoutubeShort).exists,
    isTrue,
    reason: 'the card says it is a YouTube Short',
  );
  expect(env.links.opened, isEmpty, reason: 'nothing was opened');
}

/// Flow 4.
Future<void> _shootingSheet(_Env env) async {
  final $ = env.$;
  final references = env.container.read(referencesRepositoryProvider);
  final reels = env.container.read(reelsRepositoryProvider);
  final a = await reels.create(_reelShootA, description: _shotIdeas);
  final b = await reels.create(_reelShootB);
  await _addReference(references, a.id, _linkA1, _labelA1);
  final a2 = await _addReference(references, a.id, _linkA2, _labelA2);
  await _addReference(references, b.id, _linkB1, _labelB1);
  // The row counts every Collecting and Ready to edit reel on the phone. The
  // phone's data is cleared before each run, so these three are all there
  // is; if not, fail here with the reason, not later on a count.
  final all = await references.watchAll().first;
  if (all.length != 3) {
    throw TestFailure(
      'Expected the 3 references this flow made and no others, found '
      '${all.length}: clear the data of app.taketray.dev (docs/dev-setup.md, '
      '"After a Patrol run").',
    );
  }

  // Shooting mode on, in the database (see the file's header).
  await env.container
      .read(phoneStateRepositoryProvider)
      .turnShootingOn(const {});
  final home = $(ReelsScreen);
  final row = home.$(_l10n.referencesHeader(3));
  await waitFor(
    $,
    () => row.exists,
    what: 'the References row (3 references) on the Shooting mode card',
  );

  await row.tap();
  final sheet = $(TtSheet);
  await waitFor(
    $,
    () => sheet.$(_l10n.shootingReferencesTitle).exists,
    what: 'the Shooting mode References sheet',
  );
  // Both groups, with their counts, shot ideas and cards.
  await waitFor(
    $,
    () => sheet.$(_reelShootA).exists && sheet.$(_reelShootB).exists,
    what: 'a group for each of the two reels',
  );
  expect(sheet.$(_l10n.shootingReferencesGroupCount(2)).exists, isTrue);
  expect(sheet.$(_l10n.shootingReferencesGroupCount(1)).exists, isTrue);
  expect(
    sheet.$(_shotIdeas).exists,
    isTrue,
    reason: "the first reel's shot ideas",
  );
  expect(sheet.$(_l10n.shootingReferencesNoShots).exists, isTrue);
  for (final label in [_labelA1, _labelA2, _labelB1]) {
    expect(sheet.$(label).exists, isTrue, reason: 'a card for each reference');
  }

  // A card tap reaches the bridge with that reference's stored link; the
  // sheet stays open.
  expect(env.links.opened, isEmpty, reason: 'nothing opened yet');
  await sheet.$(_labelA2).tap();
  await waitFor(
    $,
    () => env.links.opened.isNotEmpty,
    what: 'the card tap to reach the links bridge',
  );
  expect(env.links.opened, [a2.url]);
  await _expectAbsent(
    $,
    present: sheet.$(_labelA2),
    presentWhat: 'the card in the sheet, after the open',
    absent: find.text(_l10n.referenceOpenFailed),
    absentWhat: '"${_l10n.referenceOpenFailed}" after an open that worked',
  );

  // Collapse the first reel's group: its shot ideas and cards go, the other
  // group stays, and the button says Show.
  await $(_iconButtonLabelled(_l10n.shootingReferencesHide(_reelShootA))).tap();
  await waitFor(
    $,
    () =>
        $(_iconButtonLabelled(_l10n.shootingReferencesShow(_reelShootA)))
            .exists,
    what: 'the collapse button to say Show for the first reel',
  );
  await _expectAbsent(
    $,
    present: sheet.$(_labelB1),
    presentWhat: "the other reel's card, still open",
    absent: find.descendant(
      of: find.byType(TtSheet),
      matching: find.text(_labelA1),
    ),
    absentWhat: "the collapsed reel's card",
  );
  expect(sheet.$(_labelA2).exists, isFalse);
  expect(
    sheet.$(_shotIdeas).exists,
    isFalse,
    reason: 'its shot ideas went too',
  );
  expect(sheet.$(_reelShootA).exists, isTrue, reason: 'its header stays');

  // A header tap closes the sheet and opens that reel at its References.
  await sheet.$(_reelShootA).tap();
  final section = $(ReferencesSection);
  await waitFor(
    $,
    () =>
        $(ReelDetailScreen).$(_reelShootA).exists &&
        section.$(_l10n.referencesHeader(2)).exists,
    what: "the first reel's page at its References section",
  );
  expect(sheet.exists, isFalse, reason: 'the sheet closed');
  for (final label in [_labelA1, _labelA2]) {
    expect(
      section.$(label).exists,
      isTrue,
      reason: 'its cards are in the section',
    );
  }
  expect(section.$(_labelB1).exists, isFalse, reason: "not the other reel's");
}

// ============================================================ the flow shell

/// What a flow gets: the tester, the fake links bridge and, once the app is
/// up, its container.
class _Env {
  _Env(this.$, this.links);

  final PatrolIntegrationTester $;
  final PatrolLinksBridge links;

  /// Set by a flow that puts text on the clipboard; the tear-down empties it.
  bool clipboardTouched = false;

  ProviderContainer get container => _container($);
}

/// What [_prepare] changed, so [_tearDown] can put it back.
class _Prep {
  AppSettings? settingsBefore;
}

void _flowTest(
  String description,
  Future<void> Function(_Env env) body, {
  bool shootingMayBeOn = false,
}) {
  patrolTest(description, config: _liveConfig, ($) async {
    final prep = _Prep();
    final links = PatrolLinksBridge();
    final env = _Env($, links);
    (Object, StackTrace)? failure;
    try {
      // Inside the try: a throw while preparing still reaches the tear-down.
      await _prepare(prep);
      await _startApp(env);
      await waitFor($, () => $(ReelsScreen).exists, what: 'Reels (onboarded)');
      await body(env);
    } on Object catch (error, stack) {
      failure = (error, stack);
    }
    await _tearDown(
      $,
      prep,
      env: env,
      shootingMayBeOn: shootingMayBeOn,
      failure: failure,
    );
  });
}

/// The state a flow starts from, before any app is pumped: the reels of an
/// earlier run gone, and only the test folder watched.
Future<void> _prepare(_Prep prep) => _withDatabase((c) async {
  final db = c.read(appDatabaseProvider);
  final settings = c.read(settingsRepositoryProvider);
  prep.settingsBefore = await settings.load();
  await _deleteTestReels(db, c.read(reelsRepositoryProvider));
  await settings.save(const AppSettings(watchedFolders: [testFolder]));
});

/// The end of a flow. Each step runs even when one before it threw, and then
/// the first error is thrown: the flow's own [failure] when there is one.
Future<void> _tearDown(
  PatrolIntegrationTester $,
  _Prep prep, {
  required _Env env,
  required bool shootingMayBeOn,
  (Object, StackTrace)? failure,
}) async {
  var first = failure;
  Future<void> step(Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (error, stack) {
      first ??= (error, stack);
    }
  }

  // While the app is still up: Shooting mode off (it cancels the background
  // job), the settings back, and the background's copy of them follows.
  await step(() async {
    if (find.byType(TakeTrayApp).evaluate().isEmpty) return;
    final container = _container($);
    if (shootingMayBeOn) {
      await container
          .read(shootingModeControllerProvider.notifier)
          .setOn(false)
          .timeout(const Duration(seconds: 15));
    }
    final before = prep.settingsBefore;
    if (before != null) {
      await container
          .read(settingsRepositoryProvider)
          .save(before)
          .timeout(const Duration(seconds: 15));
    }
    await container
        .read(backgroundSyncProvider)
        .flush()
        .timeout(const Duration(seconds: 15));
  });
  // Only a flow that wrote to the clipboard empties it: one that failed
  // before writing leaves the owner's clipboard alone.
  if (env.clipboardTouched) {
    await step(() => Clipboard.setData(const ClipboardData(text: '')));
  }
  // Close the app, then clean the database with a container of its own.
  await step(() async {
    await $.tester.pumpWidget(const SizedBox.shrink());
    await $.tester.pump(const Duration(milliseconds: 500));
  });
  await step(
    () => _withDatabase((c) async {
      // The controller's setOn(false) swallows its failures and a timeout
      // above skips the rest of that step, so Shooting mode is switched off
      // here too, in the database, and read back: a phone left in Shooting
      // mode fails the flow instead of passing quietly. First in this
      // closure, so a failure of the clean-up after it cannot skip it; and
      // its own failure still lets that clean-up run (the `finally`).
      try {
        if (shootingMayBeOn) {
          final phone = c.read(phoneStateRepositoryProvider);
          await phone.turnShootingOff();
          if ((await phone.loadShooting()).on) {
            throw TestFailure('Shooting mode is still on after the flow');
          }
        }
      } finally {
        await _deleteTestReels(
          c.read(appDatabaseProvider),
          c.read(reelsRepositoryProvider),
        );
        final before = prep.settingsBefore;
        if (before != null) {
          await c.read(settingsRepositoryProvider).save(before);
        }
      }
    }),
  );
  if (first case (final error, final stack)) {
    Error.throwWithStackTrace(error, stack);
  }
}

/// Runs [run] with a container that is closed afterwards (the database is
/// closed first, then the container disposed, as the other files do).
Future<T> _withDatabase<T>(Future<T> Function(ProviderContainer c) run) async {
  final container = ProviderContainer();
  try {
    return await run(container).timeout(const Duration(seconds: 30));
  } finally {
    await container.read(appDatabaseProvider).close();
    container.dispose();
  }
}

/// Deletes the reels this file makes (`TakeTray Test *`; their references go
/// with them). The database is TakeTray Dev's own.
Future<void> _deleteTestReels(AppDatabase db, ReelsRepository reels) async {
  // A one-off read, not a stream (a stream still being cancelled when the
  // database closes fails the test).
  final all = await db.select(db.reels).get();
  for (final reel in all) {
    if (reel.name.startsWith(_reelPrefix)) await reels.delete(reel.id);
  }
}

/// Pumps a fresh app: a new `ProviderScope` (a key of its own), onboarded,
/// with the fake links bridge.
///
/// First the binding gets back the lifecycle state Patrol's test frame wipes
/// ([restoreResumedLifecycle], D-143).
Future<void> _startApp(_Env env) async {
  await restoreResumedLifecycle(env.$);
  await env.$.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        ...onboardedOverrides,
        linksBridgeProvider.overrideWithValue(env.links),
      ],
      child: const TakeTrayApp(),
    ),
  );
}

// ================================================================== helpers

const String _reelPrefix = 'TakeTray Test ';
const String _reelOne = '${_reelPrefix}Ref One';
const String _reelPaste = '${_reelPrefix}Ref Paste';
const String _reelFormName = '${_reelPrefix}Ref Form';
const String _reelShootA = '${_reelPrefix}Ref Shoot A';
const String _reelShootB = '${_reelPrefix}Ref Shoot B';

// Flow 1: a typed link, as stored (a link with nothing to clean), what a
// card says for it, and two labels.
const String _linkOne = 'https://example.com/taketray-test/one';
const String _hostOne = 'example.com';
const String _shortOne = 'example.com/taketray-test/one';
const String _labelOne = 'TakeTray Test label one';
const String _labelTwo = 'TakeTray Test label two';

// Flow 2: a caption that has no link, and one with a link and a comma after
// it (the comma is not part of the link).
const String _captionWithoutLink = 'Fast cuts and food close-ups, no link here';
const String _captionWithLink =
    'Love these cuts https://example.com/taketray-test/paste, so good';
const String _linkPaste = 'https://example.com/taketray-test/paste';
const String _shortPaste = 'example.com/taketray-test/paste';

// Flow 3: a YouTube Short, kept as typed (no tracking to drop).
const String _linkShort = 'https://www.youtube.com/shorts/TakeTrayTest1';
const String _shortShort = 'youtube.com/shorts/TakeTrayTest1';

// Flow 4.
const String _shotIdeas = 'TakeTray Test wide shot of the harbour';
const String _linkA1 = 'https://example.com/taketray-test/a1';
const String _linkA2 = 'https://example.com/taketray-test/a2';
const String _linkB1 = 'https://example.com/taketray-test/b1';
const String _labelA1 = 'TakeTray Test label A1';
const String _labelA2 = 'TakeTray Test label A2';
const String _labelB1 = 'TakeTray Test label B1';

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The Shooting mode card pulses for ever and a snack counts down: never wait
// for the screen to settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(TakeTrayApp)));

/// A reel of this file, through the app's own repository (the Home grid
/// shows it at once).
Future<Reel> _makeReel(_Env env, String name) =>
    env.container.read(reelsRepositoryProvider).create(name);

/// A reference saved through the repository, for the flows that need some
/// before the screen under test.
Future<ReelReference> _addReference(
  ReferencesRepository references,
  int reelId,
  String url,
  String label,
) async {
  final result = await references.add(reelId, url, label: label);
  return switch (result) {
    ReferenceAdded(:final reference) => reference,
    ReferenceAlreadySaved() => throw StateError(
      'the reference was saved twice',
    ),
  };
}

/// Reel [reelId]'s references now (a one-off read, newest first).
Future<List<ReelReference>> _referencesOf(_Env env, int reelId) =>
    env.container.read(referencesRepositoryProvider).watchForReel(reelId).first;

/// From Home: taps the card named [name] and waits for its page.
Future<void> _openReelFromHome(_Env env, String name) async {
  final $ = env.$;
  final card = $(TtReelCard).containing(name);
  await waitFor($, () => card.exists, what: 'the "$name" card on Home');
  await card.tap();
  await waitFor(
    $,
    () => $(ReelDetailScreen).exists && $(ReelDetailScreen).$(name).exists,
    what: 'the page of "$name"',
  );
}

/// A [TtIconButton] by the label a screen reader gives it (it has no text).
Finder _iconButtonLabelled(String label) => find.byWidgetPredicate(
  (w) => w is TtIconButton && w.semanticLabel == label,
  description: 'TtIconButton labelled "$label"',
);

Future<void> _tapBack(PatrolIntegrationTester $) =>
    $(_iconButtonLabelled(_l10n.navBack)).tap();

/// The more button of the reference card titled [title].
Future<void> _tapMore(PatrolIntegrationTester $, String title) =>
    $(_iconButtonLabelled(_l10n.referenceMoreSemantics(title))).tap();

/// The text box of the field named [label] (its [TtTextField] label).
Finder _fieldOf(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is TtTextField && w.label == label,
    description: 'TtTextField "$label"',
  ),
  matching: find.byType(TextField),
);

/// What the field [field] holds now.
String _textOf(PatrolIntegrationTester $, Finder field) =>
    $.tester.widget<TextField>(field).controller!.text;

/// Whether the field [field] has the focus now.
bool _focused(PatrolIntegrationTester $, Finder field) => $.tester
    .state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .widget
    .focusNode
    .hasFocus;

/// Types [text] in [field]. The field keeps the focus (the 10A rule: Patrol's
/// default closes the input connection).
Future<void> _type(PatrolIntegrationTester $, Finder field, String text) async {
  await $(field).enterText(text, hideKeyboard: false);
  expect(_textOf($, field), text, reason: 'the field holds what was typed');
}

/// Closes the keyboard, as a user does before reaching for a button, so the
/// button is not under it.
Future<void> _closeKeyboard(PatrolIntegrationTester $) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await $.tester.pump(const Duration(milliseconds: 500));
}

/// Waits until a sheet titled [title] is open.
Future<void> _waitForSheet(_Env env, String title) => waitFor(
  env.$,
  () => env.$(TtSheet).exists && env.$(TtSheet).$(title).exists,
  what: 'the sheet "$title"',
);

Future<void> _waitForSheetToClose(PatrolIntegrationTester $) =>
    waitFor($, () => !$(TtSheet).exists, what: 'the sheet to close');

/// A negative check that proves something: first waits until [present] is on
/// screen (so the screen is the one the check is about), then pumps for
/// [settle] and fails the moment [absent] shows.
Future<void> _expectAbsent(
  PatrolIntegrationTester $, {
  required Finder present,
  required String presentWhat,
  required Finder absent,
  required String absentWhat,
  Duration settle = const Duration(seconds: 1),
}) async {
  await waitFor($, () => present.evaluate().isNotEmpty, what: presentWhat);
  final end = DateTime.now().add(settle);
  while (DateTime.now().isBefore(end)) {
    if (absent.evaluate().isNotEmpty) {
      throw TestFailure('Found $absentWhat, which should not be there');
    }
    await $.tester.pump(const Duration(milliseconds: 250));
  }
}
