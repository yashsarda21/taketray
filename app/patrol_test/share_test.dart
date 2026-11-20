import 'package:flutter/material.dart';
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
import 'package:taketray/features/onboarding/views/access_step_screen.dart';
import 'package:taketray/features/onboarding/views/notifications_step_screen.dart';
import 'package:taketray/features/onboarding/views/reels_step_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/references/views/references_section.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/links_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'support/lifecycle.dart';
import 'support/onboarded.dart';
import 'support/patrol_links_bridge.dart';
import 'support/share_screen.dart';
import 'support/system_dialogs.dart';
import 'support/test_media.dart' show testFolder;
import 'support/test_share.dart';
import 'support/waiting.dart';

/// Sharing into TakeTray on the S24 (Phase 9B, Task 8, D-169): another app's
/// Share › TakeTray, saved into an existing reel, into a new reel, refused as
/// "not a link", and made before onboarding.
///
/// **How a share is made without another app.** `TestShare.startShare`
/// (`support/test_share.dart`, the debug-only channel `app.taketray/test_share`)
/// starts `ShareActivity` with an `ACTION_SEND` of `text/plain`, as Instagram
/// would. No real Instagram link is opened or loaded: the text is only text.
/// The hook starts it from TakeTray's own context, so the screen is the root of
/// a task of its own over TakeTray, not over a sharing app; what a real share
/// returns to is a hand check (`docs/dev-setup.md`, "Phase 9B check").
///
/// **How the share screen is driven.** It runs in a second Flutter engine, so
/// Patrol's widget finders (`$(...)`) cannot see it: `support/share_screen.dart`
/// finds and taps its words through Android's accessibility tree (UiAutomator),
/// by text or content description, each wait failing with what it waited for.
/// Only buttons and rows with unique words are tapped, never a point, and never
/// Android's Back (which closes the sheet). While the screen is up the app's
/// engine is not pumped; its results are read through its own repositories.
/// Whether UiAutomator sees the second engine's nodes, and under which
/// attribute, is first known on the S24 (D-169).
///
/// Every flow starts by deleting the `TakeTray Test Share *` reels of an
/// earlier run and ends (also when it fails) by closing a share screen left
/// open, putting back what it changed and deleting the reels again, so no flow
/// depends on another, on the order or on a count made by another. The words
/// are the app's own (`AppLocalizations`), never typed twice.
///
/// **What it touches on the phone.** The app under test is TakeTray Dev
/// (`app.taketray.dev`). The flows read and write its own database (reels named
/// `TakeTray Test Share *` and their references, and the onboarding flags) and
/// nothing else. No video is made and no file is read.
///
/// - **No link is ever opened.** `linksBridgeProvider` is overridden with
///   `PatrolLinksBridge` in every pump, as in `references_test.dart` (the
///   share screen has its own engine and bridges, and it opens no link).
/// - **Shooting mode is never touched.** The flows do not turn it on or off;
///   the tear-down reads it before and after and fails if it changed. The
///   watched folder is the test folder while a flow runs (as in the other
///   files), put back afterwards.
/// - **Onboarding.** Flows 1 to 3 start with onboarding done (in the
///   database, so the share screen reads the same as the app's override).
///   Flow 4 starts with it not done and ends, also when it fails, with it done
///   again: after any flow the app is onboarded.
/// - **Typing.** The share screen's name field is filled through the
///   accessibility tree with the keyboard left alone (`support/share_screen.dart`);
///   the app's own fields are not used.
/// - **Flows 2 and 4 need TakeTray Dev to hold no reels but their own** (a new
///   reel is chosen when there are none, so the form opens in New reel with no
///   switch); they fail at their start, saying so, when it does.
///
/// **Flows** (each a `patrolTest`):
/// 1. Existing reel: a reel exists, a share of an Instagram link, tap the reel,
///    Save, "Saved to {reel}", Done; the app sees the reference.
/// 2. New reel: the name typed, Save, Open reel; the app shows the reel's
///    References with the link.
/// 3. Not a link: a caption alone, "This isn't a link", Close; nothing added.
/// 4. Before onboarding: a share to a new reel (the welcome note shows), Open
///    reel; the welcome stays; onboarding finished through its steps; the reels
///    step lists the reel; the reel's References open.
///
/// **What these flows cannot show** (hand checks in `docs/dev-setup.md`): a
/// real Instagram, YouTube or TikTok share, what Done returns to, Recents,
/// TalkBack, 200 % text, dark mode and the keyboard over Save.
void main() {
  _flowTest('1. Existing reel: pick it, Save, Done', _existingReel);
  _flowTest(
    '2. New reel: name it, Save, Open reel',
    _newReel,
    needsNoReels: true,
  );
  _flowTest('3. Not a link: a caption alone, Close', _notALink);
  _flowTest(
    '4. Before onboarding: Open reel is held until onboarding is done',
    _beforeOnboarding,
    onboarded: false,
    needsNoReels: true,
  );
}

// =============================================================== the flows

/// Flow 1.
Future<void> _existingReel(_Env env) async {
  final $ = env.$;
  final screen = env.screen;
  final reel = await _makeReel(env, _reelA);
  await _waitForHomeCard(env, _reelA);
  expect(await _referencesOf(env, reel.id), isEmpty);
  final namesBefore = await _reelNames(env);

  await env.share.startShare(_shareLinkA);
  await screen.waitFor(
    _l10n.saveReferenceTitle,
    what: 'the "${_l10n.saveReferenceTitle}" sheet',
    timeout: ShareScreen.engineStart,
  );
  // The row reads "{name}, {count}": the name with its count is unique, the
  // reel's card on Home behind the sheet reads "{name}. {status}. ...".
  await screen.tap(
    '$_reelA, ${_l10n.saveReferenceReelReferences(0)}',
    contains: true,
    what: 'the row of "$_reelA" with no references',
  );
  // Save is enabled only once a reel is picked.
  await screen.tap(
    _l10n.referenceSaveButton,
    enabled: true,
    what: '"${_l10n.referenceSaveButton}", enabled once the reel is picked',
  );
  await screen.waitFor(
    _l10n.saveReferenceSavedTitle(_reelA),
    what: '"${_l10n.saveReferenceSavedTitle(_reelA)}"',
  );
  // Stored before Done: the app's engine reads the share engine's write.
  final saved = await _waitForReferences(env, reel.id, 1);
  expect(saved.single.url, _storedLinkA);
  expect(saved.single.label, isNull);

  await screen.tap(_l10n.saveReferenceDone, what: 'Done');
  await screen.waitGone(
    _l10n.saveReferenceSavedTitle(_reelA),
    what: 'the saved sheet to close after Done',
  );

  // TakeTray's own screen is where it was (hand check 3 is the To tag case),
  // and the app engine still sees exactly the one reference, the same one.
  await waitFor(
    $,
    () => $(ReelsScreen).exists,
    what: 'Reels, where the app was, after Done',
  );
  expect($(ReelDetailScreen).exists, isFalse, reason: 'Done opens no reel');
  final after = await _referencesOf(env, reel.id);
  expect(after, hasLength(1));
  expect(after.single.id, saved.single.id);
  expect(
    await _reelNames(env),
    unorderedEquals(namesBefore),
    reason: 'an existing reel is picked, no reel is made',
  );
  expect(env.links.opened, isEmpty, reason: 'no link was opened');
}

/// Flow 2.
Future<void> _newReel(_Env env) async {
  final $ = env.$;
  final screen = env.screen;
  await waitFor($, () => $(ReelsScreen).exists, what: 'Reels, with no reels');

  await env.share.startShare(_shareLinkB);
  await screen.waitFor(
    _l10n.saveReferenceTitle,
    what: 'the "${_l10n.saveReferenceTitle}" sheet',
    timeout: ShareScreen.engineStart,
  );
  // No reels: the form opens in New reel. The label field is the first text
  // field and the new reel's name the second.
  await screen.enterText(
    _reelB,
    index: _nameField,
    what: 'the "${_l10n.pickerNewReelName}" field',
  );
  await screen.tapSave(
    _l10n.referenceSaveButton,
    what: '"${_l10n.referenceSaveButton}"',
  );
  await screen.waitFor(
    _l10n.saveReferenceSavedTitle(_reelB),
    what: '"${_l10n.saveReferenceSavedTitle(_reelB)}"',
  );
  final reel = await _reelNamed(env, _reelB);
  final saved = await _waitForReferences(env, reel.id, 1);
  expect(saved.single.url, _storedLinkB);

  await screen.tap(_l10n.saveReferenceOpenReel, what: 'Open reel');
  await screen.waitGone(
    _l10n.saveReferenceSavedTitle(_reelB),
    what: 'the saved sheet to close after Open reel',
  );

  // The app opens the reel at its References, with the link.
  final section = $(ReferencesSection);
  await waitFor(
    $,
    () =>
        $(ReelDetailScreen).exists &&
        $(ReelDetailScreen).$(_reelB).exists &&
        section.$(_l10n.referencesHeader(1)).exists,
    what: 'the page of "$_reelB" with "${_l10n.referencesHeader(1)}"',
  );
  expect(
    find
        .descendant(
          of: find.byType(ReferencesSection),
          matching: find.textContaining('TTTEST2'),
        )
        .evaluate(),
    isNotEmpty,
    reason: "the card shows the saved link's short form",
  );
  expect(env.links.opened, isEmpty, reason: 'no link was opened');
}

/// Flow 3.
Future<void> _notALink(_Env env) async {
  final $ = env.$;
  final screen = env.screen;
  await waitFor($, () => $(ReelsScreen).exists, what: 'Reels');
  final before = await _allReferenceCount(env);
  final namesBefore = await _reelNames(env);

  await env.share.startShare(_captionAlone);
  await screen.waitFor(
    _l10n.saveReferenceNotALinkTitle,
    what: '"${_l10n.saveReferenceNotALinkTitle}"',
    timeout: ShareScreen.engineStart,
  );
  // On the screen now: nothing can be saved from it.
  expect(
    await screen.isShown(_l10n.referenceSaveButton),
    isFalse,
    reason: 'a caption with no link has no Save',
  );
  await screen.tap(_l10n.saveReferenceClose, what: 'Close');
  await screen.waitGone(
    _l10n.saveReferenceNotALinkTitle,
    what: 'the "not a link" screen to close after Close',
  );

  await waitFor($, () => $(ReelsScreen).exists, what: 'Reels after Close');
  expect(
    await _allReferenceCount(env),
    before,
    reason: 'no reference was added',
  );
  expect(
    await _reelNames(env),
    unorderedEquals(namesBefore),
    reason: 'no reel was made',
  );
}

/// Flow 4.
Future<void> _beforeOnboarding(_Env env) async {
  final $ = env.$;
  final screen = env.screen;
  final welcome = $(WelcomeScreen);
  await waitFor($, () => welcome.exists, what: 'the welcome (not onboarded)');
  expect(await _onboardingDone(env), isFalse);

  // A share to a new reel, before the app has been set up.
  await env.share.startShare(_shareLinkC);
  await screen.waitFor(
    _l10n.saveReferenceTitle,
    what: 'the "${_l10n.saveReferenceTitle}" sheet',
    timeout: ShareScreen.engineStart,
  );
  await screen.enterText(
    _reelC,
    index: _nameField,
    what: 'the "${_l10n.pickerNewReelName}" field',
  );
  await screen.tapSave(
    _l10n.referenceSaveButton,
    what: '"${_l10n.referenceSaveButton}"',
  );
  await screen.waitFor(
    _l10n.saveReferenceSavedTitle(_reelC),
    what: '"${_l10n.saveReferenceSavedTitle(_reelC)}"',
  );
  // The saved state tells a new user what comes next (the sheet reads the
  // flag from the database, so it can take a moment).
  await screen.waitFor(
    _l10n.saveReferenceWelcomeTitle,
    what: '"${_l10n.saveReferenceWelcomeTitle}" before onboarding',
  );
  final reel = await _reelNamed(env, _reelC);
  await _waitForReferences(env, reel.id, 1);
  expect(
    await _onboardingDone(env),
    isFalse,
    reason: 'the share screen never finishes onboarding',
  );

  // Open reel: the app is still on its welcome, the reel is held.
  await screen.tap(_l10n.saveReferenceOpenReel, what: 'Open reel');
  await screen.waitGone(
    _l10n.saveReferenceSavedTitle(_reelC),
    what: 'the saved sheet to close after Open reel',
  );
  await waitFor(
    $,
    () => welcome.exists,
    what: 'the welcome, still showing after Open reel',
  );
  await pumpFor($, const Duration(seconds: 1));
  expect($(ReelDetailScreen).exists, isFalse, reason: 'held, not opened');
  expect(await _onboardingDone(env), isFalse);

  // Onboarding, with every ask answered "no" (the 10A Manual mode road): the
  // reels step lists the reel the share made.
  await welcome.$(_l10n.welcomeGetStarted).tap();
  final access = $(AccessStepScreen);
  await waitFor(
    $,
    () => access.$(_l10n.accessBeforeTitle).exists,
    what: 'the video access step',
  );
  await access.$(_l10n.accessAllow).tap();
  await tapNativeView($, denyButton);
  await waitFor(
    $,
    () => access.$(_l10n.accessDeniedTitle).exists,
    what: "the denied look after Don't allow",
  );
  await access.$(_l10n.accessContinueManual).tap();
  await waitFor(
    $,
    () => $(NotificationsStepScreen).$(_l10n.notificationsStepNotNow).exists,
    what: 'the notifications step',
  );
  await $(NotificationsStepScreen).$(_l10n.notificationsStepNotNow).tap();
  final reelsStep = $(ReelsStepScreen);
  await waitFor(
    $,
    () => reelsStep.exists && reelsStep.$(_reelC).exists,
    what: 'the reels step listing "$_reelC"',
  );
  expect(
    reelsStep.$(_l10n.reelsStepExistingCount(1)).exists,
    isTrue,
    reason: 'the listed reel says it holds the shared reference',
  );
  expect(reelsStep.$(_l10n.reelsStepShareTip).exists, isTrue);

  // Continue finishes onboarding, and the held Open reel is opened.
  await reelsStep.$(_l10n.onboardingContinue).tap();
  final section = $(ReferencesSection);
  await waitFor(
    $,
    () =>
        $(ReelDetailScreen).exists &&
        $(ReelDetailScreen).$(_reelC).exists &&
        section.$(_l10n.referencesHeader(1)).exists,
    what: 'the page of "$_reelC" with "${_l10n.referencesHeader(1)}"',
  );
  expect(await _onboardingDone(env), isTrue);
  expect(await _reelNames(env), [
    _reelC,
  ], reason: 'onboarding made no second reel');
  expect(env.links.opened, isEmpty, reason: 'no link was opened');
}

// ============================================================ the flow shell

/// What a flow gets: the tester, the fake links bridge, the share hook and
/// the share screen's driver.
class _Env {
  _Env(this.$, this.links)
    : share = TestShare(),
      screen = ShareScreen(PatrolNativeScreen($));

  final PatrolIntegrationTester $;
  final PatrolLinksBridge links;
  final TestShare share;
  final ShareScreen screen;

  ProviderContainer get container => _container($);
}

/// What [_prepare] saw, so [_tearDown] can put it back.
class _Prep {
  AppSettings? settingsBefore;
  bool? shootingBefore;
}

void _flowTest(
  String description,
  Future<void> Function(_Env env) body, {
  bool onboarded = true,
  bool needsNoReels = false,
}) {
  patrolTest(description, config: _liveConfig, ($) async {
    final prep = _Prep();
    final links = PatrolLinksBridge();
    final env = _Env($, links);
    (Object, StackTrace)? failure;
    try {
      // Inside the try: a throw while preparing still reaches the tear-down.
      await _prepare(prep, onboarded: onboarded, needsNoReels: needsNoReels);
      await _startApp(env, onboarded: onboarded);
      if (onboarded) {
        await waitFor(
          $,
          () => $(ReelsScreen).exists,
          what: 'Reels (onboarded)',
        );
      }
      await body(env);
    } on Object catch (error, stack) {
      failure = (error, stack);
    }
    await _tearDown($, prep, env: env, failure: failure);
  });
}

/// The state a flow starts from, before any app is pumped: the reels of an
/// earlier run gone, only the test folder watched, and onboarding done (flow 4
/// asks for it not done: its first-launch flags are deleted).
Future<void> _prepare(
  _Prep prep, {
  required bool onboarded,
  required bool needsNoReels,
}) => _withDatabase((c) async {
  final db = c.read(appDatabaseProvider);
  final settings = c.read(settingsRepositoryProvider);
  final phone = c.read(phoneStateRepositoryProvider);
  prep
    ..settingsBefore = await settings.load()
    ..shootingBefore = (await phone.loadShooting()).on;
  await _deleteTestReels(db, c.read(reelsRepositoryProvider));
  await settings.save(const AppSettings(watchedFolders: [testFolder]));
  if (needsNoReels) {
    final others = await db.select(db.reels).get();
    if (others.isNotEmpty) {
      throw TestFailure(
        "Expected TakeTray Dev to hold no reels but this flow's own, found "
        '${others.length}: clear the data of app.taketray.dev '
        '(docs/dev-setup.md, "After a Patrol run").',
      );
    }
  }
  if (onboarded) {
    await phone.markOnboardingDone();
    await phone.markIntroPlayed();
  } else {
    await (db.delete(db.settings)..where(
          (s) => s.key.isIn(const [
            PhoneStateRepository.onboardingDoneKey,
            PhoneStateRepository.introPlayedKey,
            PhoneStateRepository.homeTipSeenKey,
          ]),
        ))
        .go();
  }
});

/// The end of a flow. Each step runs even when one before it threw, and then
/// the first error is thrown: the flow's own [failure] when there is one.
Future<void> _tearDown(
  PatrolIntegrationTester $,
  _Prep prep, {
  required _Env env,
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

  // A share screen a failed flow left open would sit over the next flow and
  // over the phone: close it first, by its own button. It only ever taps when
  // one of its three titles is on the screen.
  await step(() async {
    await env.screen.closeIfOpen([
      ShareState(title: _l10n.saveReferenceTitle, button: _l10n.cancel),
      ShareState(
        title: _l10n.saveReferenceNotALinkTitle,
        button: _l10n.saveReferenceClose,
      ),
      ShareState(
        title: _l10n.saveReferenceSavedTitle(''),
        titleContains: true,
        button: _l10n.saveReferenceDone,
      ),
    ]);
  });
  // While the app is still up: the settings back, and the background's copy of
  // them follows. (Shooting mode is never touched, so it is not turned off.)
  await step(() async {
    if (find.byType(TakeTrayApp).evaluate().isEmpty) return;
    final container = _container($);
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
  // Close the app, then clean the database with a container of its own.
  await step(() async {
    await $.tester.pumpWidget(const SizedBox.shrink());
    await $.tester.pump(const Duration(milliseconds: 500));
  });
  await step(
    () => _withDatabase((c) async {
      final phone = c.read(phoneStateRepositoryProvider);
      // Onboarding is done after every flow (flow 4 undid it), whatever
      // happened in the body.
      await phone.markOnboardingDone();
      await phone.markIntroPlayed();
      await _deleteTestReels(
        c.read(appDatabaseProvider),
        c.read(reelsRepositoryProvider),
      );
      final before = prep.settingsBefore;
      if (before != null) {
        await c.read(settingsRepositoryProvider).save(before);
      }
      // Shooting mode was never touched: it is what it was.
      final shootingBefore = prep.shootingBefore;
      if (shootingBefore != null &&
          (await phone.loadShooting()).on != shootingBefore) {
        throw TestFailure('Shooting mode changed during the flow');
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

/// Deletes the reels this file makes (`TakeTray Test Share *`; their
/// references go with them). The database is TakeTray Dev's own.
Future<void> _deleteTestReels(AppDatabase db, ReelsRepository reels) async {
  // A one-off read, not a stream (a stream still being cancelled when the
  // database closes fails the test).
  final all = await db.select(db.reels).get();
  for (final reel in all) {
    if (reel.name.startsWith(_reelPrefix)) await reels.delete(reel.id);
  }
}

/// Pumps a fresh app: a new `ProviderScope` (a key of its own), with the fake
/// links bridge, and onboarded (the flags fixed at done) unless [onboarded] is
/// false, when the real flags decide where it opens.
///
/// First the binding gets back the lifecycle state Patrol's test frame wipes
/// ([restoreResumedLifecycle], D-143).
Future<void> _startApp(_Env env, {required bool onboarded}) async {
  await restoreResumedLifecycle(env.$);
  await env.$.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        if (onboarded) ...onboardedOverrides,
        linksBridgeProvider.overrideWithValue(env.links),
      ],
      child: const TakeTrayApp(),
    ),
  );
}

// ================================================================== helpers

const String _reelPrefix = 'TakeTray Test Share ';
const String _reelA = '${_reelPrefix}A';
const String _reelB = '${_reelPrefix}B';
const String _reelC = '${_reelPrefix}C';

// What is shared: a caption with an Instagram reel link (the link is only
// text, nothing opens it), and what the app stores for it (the /reel/ path is
// the /p/ one and the tracking query is gone).
const String _shareLinkA =
    'Look https://www.instagram.com/reel/TTTEST1/?igsh=x';
const String _storedLinkA = 'https://www.instagram.com/p/TTTEST1/';
const String _shareLinkB =
    'Love these cuts https://www.instagram.com/reel/TTTEST2/?igsh=y, so good';
const String _storedLinkB = 'https://www.instagram.com/p/TTTEST2/';
const String _shareLinkC = 'https://www.instagram.com/reel/TTTEST4/?igsh=z';
const String _captionAlone = 'Fast cuts and food close-ups, no link here';

/// The new reel's name is the second text field on the sheet, after the label.
const int _nameField = 1;

/// The app's own words, in English (the tests are run with the phone in
/// English, as the other Patrol tests are).
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// The welcome's intro and a snack count down: never wait for the screen to
// settle, only for the thing the test is about.
const PatrolTesterConfig _liveConfig = PatrolTesterConfig(
  settleTimeout: Duration(seconds: 2),
  existsTimeout: Duration(seconds: 30),
  visibleTimeout: Duration(seconds: 30),
  printLogs: true,
);

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(TakeTrayApp)));

/// A reel of this file, through the app's own repository.
Future<Reel> _makeReel(_Env env, String name) =>
    env.container.read(reelsRepositoryProvider).create(name);

/// The reel named [name] now (a one-off read).
Future<Reel> _reelNamed(_Env env, String name) async {
  final all = await env.container
      .read(reelsRepositoryProvider)
      .watchAll()
      .first;
  return all.singleWhere(
    (r) => r.name == name,
    orElse: () => throw TestFailure('No reel "$name" in the app\'s database'),
  );
}

/// The names of the reels in the database now.
Future<List<String>> _reelNames(_Env env) async => [
  for (final reel
      in await env.container.read(reelsRepositoryProvider).watchAll().first)
    reel.name,
];

/// Reel [reelId]'s references now (a one-off read, newest first).
Future<List<ReelReference>> _referencesOf(_Env env, int reelId) =>
    env.container.read(referencesRepositoryProvider).watchForReel(reelId).first;

/// How many references there are in all.
Future<int> _allReferenceCount(_Env env) async =>
    (await env.container.read(referencesRepositoryProvider).watchAll().first)
        .length;

/// Waits (in real time, with no frame pumped: the app is behind the share
/// screen) until reel [reelId] has [count] references, and returns them. The
/// share engine's write is read through the app engine's own connection.
Future<List<ReelReference>> _waitForReferences(
  _Env env,
  int reelId,
  int count, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    final found = await _referencesOf(env, reelId);
    if (found.length == count) return found;
    if (DateTime.now().isAfter(end)) {
      throw TestFailure(
        'Timed out after ${timeout.inSeconds} s waiting for the app to see '
        '$count reference(s) on the reel (it saw ${found.length})',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

/// Waits until Home shows the card named [name].
Future<void> _waitForHomeCard(_Env env, String name) => waitFor(
  env.$,
  () => env.$(TtReelCard).containing(name).exists,
  what: 'the "$name" card on Home',
);

/// Whether onboarding is stored as done, read by the app engine.
Future<bool> _onboardingDone(_Env env) =>
    env.container.read(phoneStateRepositoryProvider).onboardingDone();
