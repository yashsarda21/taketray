import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/app/database_refresh.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/locale.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/features/share/share_app.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/share_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';

/// The goldens are **macOS only, and not on CI** (D-61, D-97): make or update
/// them with `tool/flutter test --update-goldens
/// test/features/share/share_app_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _reelLink = 'https://www.instagram.com/reel/ABC/?igsh=zz';
const _reelShort = 'instagram.com/p/ABC';
const _otherLink = 'https://youtu.be/xyz123';
const _otherShort = 'youtu.be/xyz123';
const _caption = 'Best breakfast in London, no link in here';

/// A [ShareBridge] that counts its calls and answers [sharedText] from a
/// queue (null once the queue is empty, as the real one does after the first
/// read).
class _FakeShareBridge implements ShareBridge {
  final List<Future<String?> Function()> _reads = [];

  int reads = 0;
  int finishes = 0;
  final List<int> opened = [];

  /// When set, [finish] and [openReel] wait for it.
  Completer<void>? finishGate;

  /// What [finish] and [openReel] answer: false is a failed close, a failed
  /// open (the bridge swallowed a PlatformException).
  bool closeWorks = true;

  /// When set, [finish] and [openReel] throw it.
  Exception? closeThrows;

  /// Queues one read that answers [text] at once.
  void queue(String? text) => _reads.add(() async => text);

  /// Queues one read that answers when [gate] completes.
  void queueGated(Completer<String?> gate) => _reads.add(() => gate.future);

  @override
  Future<String?> sharedText() async {
    reads++;
    if (_reads.isEmpty) return null;
    return await _reads.removeAt(0)();
  }

  @override
  Future<bool> finish() async {
    finishes++;
    await finishGate?.future;
    final error = closeThrows;
    if (error != null) throw error;
    return closeWorks;
  }

  @override
  Future<bool> openReel(int reelId) async {
    opened.add(reelId);
    await finishGate?.future;
    final error = closeThrows;
    if (error != null) throw error;
    return closeWorks;
  }
}

/// A references repository whose `add` waits for [hold] when it is set.
class _Refs extends ReferencesRepository {
  // ignore: use_super_parameters, the parameters of ReferencesRepository are private
  _Refs(AppDatabase db, Clock clock) : super(db, clock);

  Completer<void>? hold;

  @override
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    final gate = hold;
    if (gate != null) await gate.future;
    return await super.add(reelId, rawUrl, label: label);
  }
}

/// A phone state that answers the onboarding flag and records every other
/// call: the share engine writes nothing (D-162).
class _Phone implements PhoneStateRepository {
  _Phone({this.onboarded = true});

  final bool onboarded;
  final List<String> others = [];

  @override
  Future<bool> onboardingDone() async => onboarded;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    others.add('${invocation.memberName}');
    throw StateError('The share engine called the phone state: $others');
  }
}

/// Remembers the name of every provider that is built.
final class _BuiltProviders extends ProviderObserver {
  final List<String> names = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    names.add('${context.provider.name ?? context.provider.runtimeType}');
  }
}

void main() {
  late VmHarness h;
  late _FakeShareBridge bridge;
  late _BuiltProviders built;
  late ReelsRepository reels;
  late _Refs refs;
  late _Phone phone;

  setUp(() {
    h = VmHarness();
    bridge = _FakeShareBridge();
    built = _BuiltProviders();
    reels = ReelsRepository(h.media.db, h.media.clock);
    refs = _Refs(h.media.db, h.media.clock);
    phone = _Phone();
    // The source icon asks the phone which apps there are.
    h.editors.allowOnly({'apps'});
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Runs the share screen over a 360 x 800 dp phone, with [text] shared.
  /// With `settled: false` it only pumps the first frame.
  Future<void> pump(
    WidgetTester tester, {
    String? text = _reelLink,
    bool queueText = true,
    double textScale = 1,
    double keyboard = 0,
    Size size = const Size(360, 800),
    Brightness brightness = Brightness.light,
    bool settled = true,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    if (queueText) bridge.queue(text);
    await tester.pumpWidget(
      ProviderScope(
        observers: [built],
        overrides: [
          ...h.overrides,
          shareBridgeProvider.overrideWithValue(bridge),
          referencesRepositoryProvider.overrideWithValue(refs),
          phoneStateRepositoryProvider.overrideWithValue(phone),
        ],
        child: const ShareApp(),
      ),
    );
    if (settled) {
      await settleApp(tester);
    } else {
      await tester.pump();
    }
  }

  Future<int> makeReel(WidgetTester tester, String name) async {
    final reel = await real(tester, () => reels.create(name));
    h.media.clock.advance(const Duration(minutes: 1));
    return reel.id;
  }

  FadeTransition fadeOf(WidgetTester tester) => tester.widget<FadeTransition>(
    find.descendant(
      of: find.byKey(ShareApp.scrimKey),
      matching: find.byType(FadeTransition),
    ),
  );

  SlideTransition riseOf(WidgetTester tester) =>
      tester.widget<SlideTransition>(find.byKey(ShareApp.riseKey));

  MaterialApp app(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  Finder button(String label) => find.byWidgetPredicate(
    (w) => w is TtButton && w.label == label,
    description: 'the "$label" button',
  );

  Finder rowOf(String name) => find.byWidgetPredicate(
    (w) => w is TtReelPickRow && w.name == name,
    description: 'the row of "$name"',
  );

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is TtTextField && w.label == label),
    matching: find.byType(TextField),
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await settleApp(tester);
  }

  /// A tap on the dimmed part above the sheet.
  Future<void> tapScrim(WidgetTester tester) async {
    await tester.tapAt(const Offset(180, 8));
    await tester.pump();
    await settleApp(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
    await settleApp(tester);
  }

  /// Picks the reel [name] and saves with no label.
  Future<void> pickAndSave(WidgetTester tester, String name) async {
    await tapAndSettle(tester, rowOf(name));
    await tester.tap(button('Save'));
    await tester.pump();
  }

  /// The phone leaves the app and comes back (the lifecycle's legal steps).
  void leaveAndReturn(WidgetTester tester) {
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
  }

  Future<void> resume(WidgetTester tester) async {
    leaveAndReturn(tester);
    await tester.pump();
    await settleApp(tester);
  }

  group('the shell', () {
    testApp("it has the app's themes and l10n, following the phone", (
      tester,
    ) async {
      await pump(tester);

      final material = app(tester);
      expect(material.theme!.brightness, Brightness.light);
      expect(material.darkTheme!.brightness, Brightness.dark);
      expect(material.themeMode, ThemeMode.system);
      expect(
        material.localizationsDelegates,
        AppLocalizations.localizationsDelegates,
      );
      expect(material.supportedLocales, AppLocalizations.supportedLocales);
      expect(material.localeListResolutionCallback, resolvePhoneLocale);
      expect(material.debugShowCheckedModeBanner, isFalse);
      final context = tester.element(find.byKey(ShareApp.bodyKey));
      expect(AppLocalizations.of(context).appTitle, 'TakeTray');
    });

    testApp('a dark phone gets the dark theme', (tester) async {
      await pump(tester, brightness: Brightness.dark);

      final context = tester.element(find.byKey(ShareApp.bodyKey));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testApp('it re-reads the database on resume, with one listener of its '
        'own (D-164)', (tester) async {
      await pump(tester);

      expect(find.byType(DatabaseRefresh), findsOneWidget);
      // Above the MaterialApp, so a screen change never drops it.
      expect(
        find.ancestor(
          of: find.byType(MaterialApp),
          matching: find.byType(DatabaseRefresh),
        ),
        findsOneWidget,
      );
    });

    testApp('the window is see-through: only the scrim and the sheet paint', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(Scaffold), findsNothing);
      // Everything above the scrim is fully transparent.
      for (final box in tester.widgetList<ColoredBox>(
        find.ancestor(
          of: find.byKey(ShareApp.scrimKey),
          matching: find.byType(ColoredBox),
        ),
      )) {
        expect(box.color.a, 0, reason: '$box');
      }
    });

    testApp("the scrim is the theme's scrim at the app's sheet opacity, "
        'light and dark', (tester) async {
      for (final brightness in Brightness.values) {
        await pump(tester, brightness: brightness);

        final context = tester.element(find.byKey(ShareApp.bodyKey));
        final scrim = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(ShareApp.scrimKey),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(
          scrim.color,
          context.scheme.scrim.withValues(alpha: TtMetrics.scrimOpacity),
          reason: '$brightness',
        );
        expect(TtMetrics.scrimOpacity, 0.5);
      }
    });

    testApp('the sheet sits at the bottom, over the dimmed page', (
      tester,
    ) async {
      await pump(tester);

      final sheet = tester.getRect(find.byType(TtSheet));
      expect(sheet.bottom, lessThanOrEqualTo(800));
      expect(sheet.bottom, greaterThan(800 - 40));
      expect(
        tester.getRect(find.byKey(ShareApp.scrimKey)).size,
        const Size(360, 800),
      );
    });

    testApp('it builds no background, media, settings or onboarding provider, '
        'and reads no onboarding flag but the callout', (tester) async {
      await pump(tester);
      await back(tester);

      for (final name in built.names) {
        expect(
          name,
          isNot(matches(RegExp('background|media|settings|onboarding'))),
          reason: name,
        );
      }
      expect(built.names, contains('shareBridgeProvider'));
    });
  });

  group('the shared text', () {
    testApp('reaches the sheet: the link, as the form', (tester) async {
      await pump(tester);

      expect(find.text('Save reference'), findsOneWidget);
      expect(find.text(_reelShort), findsOneWidget);
      expect(bridge.reads, 1);
    });

    testApp('with no link in it, shows "This isn\'t a link"', (tester) async {
      await pump(tester, text: _caption);

      expect(find.text("This isn't a link"), findsOneWidget);
      expect(find.text(_caption), findsOneWidget);
    });

    testApp('an empty text is "not a link"', (tester) async {
      await pump(tester, text: '');

      expect(find.text("This isn't a link"), findsOneWidget);
    });

    testApp('no text at all (null) is "not a link" too', (tester) async {
      await pump(tester, text: null);

      expect(find.text("This isn't a link"), findsOneWidget);
    });

    testApp('it is read once on start, not on every rebuild', (tester) async {
      await pump(tester);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bridge.reads, 1);
    });
  });

  group('closing', () {
    testApp('Back closes the share screen, once', (tester) async {
      await pump(tester);
      expect(bridge.finishes, 0);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isTrue, reason: 'the screen takes Back itself');
      expect(bridge.finishes, 1);
    });

    testApp('a tap on the scrim closes it, once', (tester) async {
      await pump(tester);

      await tapScrim(tester);

      expect(bridge.finishes, 1);
    });

    testApp('Cancel closes it, once', (tester) async {
      await makeReel(tester, 'Goa');
      await pump(tester);

      await tapAndSettle(tester, button('Cancel'));

      expect(bridge.finishes, 1);
    });

    testApp('Close, in the "not a link" state, closes it, once', (
      tester,
    ) async {
      await pump(tester, text: _caption);

      await tapAndSettle(tester, button('Close'));

      expect(bridge.finishes, 1);
    });

    testApp('Done, after saving, closes it, once', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      await pickAndSave(tester, 'Goa');
      await settleApp(tester);
      expect(find.text('Saved to Goa'), findsOneWidget);
      expect(bridge.finishes, 0);
      expect(goa, isPositive);

      await tapAndSettle(tester, button('Done'));

      expect(bridge.finishes, 1);
    });

    testApp('a tap on the sheet itself does not close it', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Save reference'));
      await tester.pump();
      await tester.tap(find.byType(TtSheet), warnIfMissed: false);
      await tester.pump();

      expect(bridge.finishes, 0);
    });

    testApp('every way twice is still one finish, even while it is closing', (
      tester,
    ) async {
      await pump(tester);
      // The first finish is slow, so the others come while it is closing.
      bridge.finishGate = Completer<void>();

      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(180, 8));
      await tester.pump();
      await tester.tap(button('Cancel'));
      await tester.pump();
      expect(bridge.finishes, 1);

      bridge.finishGate!.complete();
      await settleApp(tester);
      await back(tester);
      await tapScrim(tester);
      expect(bridge.finishes, 1);
    });

    testApp('Back during a running save finishes only after the save', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(bridge.finishes, 0, reason: 'the save still holds the database');

      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(bridge.finishes, 1);
      expect(
        await real(tester, () async => await refs.watchForReel(goa).first),
        hasLength(1),
        reason: 'the save was finished, not abandoned',
      );
    });

    testApp('a scrim tap during a running save waits for it as well', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');

      await tester.tapAt(const Offset(180, 8));
      await tester.pump();
      expect(bridge.finishes, 0);

      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(bridge.finishes, 1);
    });

    testApp('Back and a scrim tap during one save make one finish', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');

      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(180, 8));
      await tester.pump();
      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(bridge.finishes, 1);
    });

    testApp('a save that fails still lets Back finish', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      await real(tester, () => reels.delete(goa));
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');

      await tester.binding.handlePopRoute();
      await tester.pump();
      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(bridge.finishes, 1);
    });

    testApp('a share that arrives while Back waits for a save cancels the '
        'close, then shows once the save is done (M18)', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(bridge.finishes, 0);
      final reads = bridge.reads;
      bridge.queue(_otherLink);

      await resume(tester);
      expect(bridge.reads, greaterThan(reads), reason: 'it did read');
      expect(find.text(_otherShort), findsNothing, reason: 'the save holds');

      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(find.text(_otherShort), findsOneWidget);
      expect(find.text(_reelShort), findsNothing);
      expect(bridge.finishes, 0, reason: 'the close was cancelled');
      expect(
        await real(tester, () async => await refs.watchForReel(goa).first),
        hasLength(1),
        reason: 'the first share was saved to the end',
      );
    });

    testApp('after a cancelled close, Back closes again, once (M18)', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();
      bridge.queue(_otherLink);
      await resume(tester);
      // The user leaves again while the save still runs.
      await tester.binding.handlePopRoute();
      await tester.pump();

      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(
        bridge.finishes,
        1,
        reason: 'the old close is gone, the new one runs once',
      );
    });

    testApp('a resume with no new share does not cancel the waiting close '
        '(M18)', (tester) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();

      await resume(tester);
      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(bridge.finishes, 1);
    });

    testApp('an empty text during the wait cancels the close too (M18)', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();
      bridge.queue('');

      await resume(tester);
      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(find.text("This isn't a link"), findsOneWidget);
      expect(bridge.finishes, 0);
    });

    testApp('a finish that fails lets Back and the buttons work again (M19)', (
      tester,
    ) async {
      await pump(tester);
      bridge.closeWorks = false;

      await tester.binding.handlePopRoute();
      await tester.pump();
      await settleApp(tester);
      expect(bridge.finishes, 1);

      bridge.closeWorks = true;
      await tapAndSettle(tester, button('Cancel'));
      expect(bridge.finishes, 2, reason: 'not stuck');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(bridge.finishes, 2, reason: 'closed for good now');
    });

    testApp('a finish that throws lets it close again, the type logged '
        '(M19)', (tester) async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = level);
      await pump(tester);
      bridge.closeThrows = const FormatException(
        'secret text https://x.example/a',
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await settleApp(tester);
      bridge.closeThrows = null;
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(bridge.finishes, 2);
      final shown = records.map((r) => '${r.message} ${r.error}').join('\n');
      expect(shown, contains('FormatException'));
      expect(shown, isNot(contains('secret')));
      expect(shown, isNot(contains('example')));
    });

    testApp('an Open reel that fails lets the buttons work again (M19)', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      await pickAndSave(tester, 'Goa');
      await settleApp(tester);
      bridge.closeWorks = false;

      await tapAndSettle(tester, button('Open reel'));
      expect(bridge.opened, [goa]);

      bridge.closeWorks = true;
      await tapAndSettle(tester, button('Open reel'));
      expect(bridge.opened, [goa, goa], reason: 'not stuck');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(bridge.finishes, 0, reason: 'it opened, so it is closing');
    });

    testApp('a save that never ends holds the close for 10 seconds, then it '
        'goes ahead, logged without a secret (M19)', (tester) async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = level);
      await makeReel(tester, 'Goa');
      await pump(tester);
      refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();

      await tester.pump(const Duration(seconds: 9));
      expect(bridge.finishes, 0, reason: 'still within the limit');
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();

      expect(bridge.finishes, 1);
      expect(
        records.map((r) => r.message),
        contains(contains('save still running')),
      );
    });

    testApp('a close that a new share cancelled does not log "Closing '
        'anyway" when its time limit runs out', (tester) async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = level);
      await makeReel(tester, 'Goa');
      await pump(tester);
      refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();
      bridge.queue(_otherLink);
      await resume(tester);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      expect(bridge.finishes, 0, reason: 'the close was cancelled');
      expect(
        records.map((r) => r.message),
        isNot(contains(contains('save still running'))),
        reason: 'it did not close anyway',
      );
    });

    testApp('a save that ends in time cancels the 10 second limit (M19)', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await real(tester, () async => hold.complete());
      await settleApp(tester);
      expect(bridge.finishes, 1);

      await tester.pump(const Duration(seconds: 20));

      expect(bridge.finishes, 1, reason: 'the limit does not close it again');
    });
  });

  group('Open reel', () {
    testApp('after saving calls openReel with the reel, and not finish', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      await pickAndSave(tester, 'Goa');
      await settleApp(tester);

      await tapAndSettle(tester, button('Open reel'));

      expect(bridge.opened, [goa]);
      expect(bridge.finishes, 0, reason: 'native finishes by itself');
    });

    testApp('from the already-saved banner calls openReel as well', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await real(
        tester,
        () => refs.add(goa, 'https://www.instagram.com/p/ABC/'),
      );
      await pump(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      expect(find.text('Already saved in Goa'), findsOneWidget);

      await tapAndSettle(tester, button('Open reel'));

      expect(bridge.opened, [goa]);
      expect(bridge.finishes, 0);
    });

    testApp('after it, Back and a second Open reel do nothing', (tester) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      await pickAndSave(tester, 'Goa');
      await settleApp(tester);
      bridge.finishGate = Completer<void>();

      await tester.tap(button('Open reel'));
      await tester.pump();
      await tester.tap(button('Open reel'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(180, 8));
      await tester.pump();

      expect(bridge.opened, hasLength(1));
      expect(bridge.finishes, 0);
      bridge.finishGate!.complete();
      await settleApp(tester);
    });
  });

  group('a second share', () {
    testApp('a resume with new text shows the new link', (tester) async {
      await pump(tester);
      expect(find.text(_reelShort), findsOneWidget);
      bridge.queue(_otherLink);

      await resume(tester);

      expect(find.text(_otherShort), findsOneWidget);
      expect(find.text(_reelShort), findsNothing);
      expect(bridge.reads, 2);
    });

    testApp('a resume with a caption shows "not a link"', (tester) async {
      await pump(tester);
      bridge.queue(_caption);

      await resume(tester);

      expect(find.text("This isn't a link"), findsOneWidget);
    });

    testApp('a resume with an empty text is "not a link" too', (tester) async {
      await pump(tester);
      bridge.queue('');

      await resume(tester);

      expect(find.text("This isn't a link"), findsOneWidget);
    });

    testApp('a resume with null keeps the current sheet, as typed', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(input('Label (optional)'), 'My label');
      await tester.pump();

      await resume(tester);

      expect(bridge.reads, 2, reason: 'it did ask');
      expect(find.text(_reelShort), findsOneWidget);
      expect(find.text('My label'), findsOneWidget);
    });

    testApp('a resume replaces a saved sheet with the new share', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pump(tester);
      await pickAndSave(tester, 'Goa');
      await settleApp(tester);
      expect(find.text('Saved to Goa'), findsOneWidget);
      bridge.queue(_otherLink);

      await resume(tester);

      expect(find.text('Saved to Goa'), findsNothing);
      expect(find.text(_otherShort), findsOneWidget);
    });

    testApp('leaving the app asks nothing: only coming back does', (
      tester,
    ) async {
      await pump(tester);

      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();

      expect(bridge.reads, 1);
    });

    testApp('a share that arrives during a running save waits for it, then '
        'shows', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await pump(tester);
      final hold = refs.hold = Completer<void>();
      await pickAndSave(tester, 'Goa');
      bridge.queue(_otherLink);

      await resume(tester);
      expect(find.text(_reelShort), findsOneWidget, reason: 'not yet');

      await real(tester, () async => hold.complete());
      await settleApp(tester);

      expect(find.text(_otherShort), findsOneWidget);
      expect(
        await real(tester, () async => await refs.watchForReel(goa).first),
        hasLength(1),
        reason: 'the first share was saved to the end',
      );
    });

    testApp('once the screen is closing, a new share is ignored', (
      tester,
    ) async {
      await pump(tester);
      bridge.finishGate = Completer<void>();
      await tester.binding.handlePopRoute();
      await tester.pump();
      bridge.queue(_otherLink);

      await resume(tester);

      expect(find.text(_otherShort), findsNothing);
      bridge.finishGate!.complete();
      await settleApp(tester);
    });

    testApp('a resume read that lands before the first read does not lose '
        'the text', (tester) async {
      final first = Completer<String?>();
      bridge.queueGated(first);
      await pump(tester, queueText: false, settled: false);
      // The resume's read answers at once, the start's read is still out.
      bridge.queue(_otherLink);
      leaveAndReturn(tester);
      await tester.pump();
      await settleApp(tester);
      expect(find.text(_otherShort), findsOneWidget);

      // Now the start's read ends with nothing: it must not wipe the sheet.
      await real(tester, () async => first.complete(null));
      await settleApp(tester);

      expect(find.text(_otherShort), findsOneWidget);
      expect(find.text("This isn't a link"), findsNothing);
    });
  });

  group('onboarding', () {
    testApp('saving, the welcome note and Open reel write nothing', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      final notDone = phone = _Phone(onboarded: false);
      await pump(tester);

      await pickAndSave(tester, 'Goa');
      await settleApp(tester);
      expect(find.text('Welcome to TakeTray'), findsOneWidget);
      await tapAndSettle(tester, button('Open reel'));

      expect(bridge.opened, [goa]);
      expect(notDone.others, isEmpty);
    });

    testApp('a second share, Done and Back write nothing', (tester) async {
      await makeReel(tester, 'Goa');
      final notDone = phone = _Phone(onboarded: false);
      await pump(tester);
      bridge.queue(_caption);
      await resume(tester);
      expect(find.text("This isn't a link"), findsOneWidget);

      await back(tester);

      expect(bridge.finishes, 1);
      expect(notDone.others, isEmpty);
    });

    testApp('Close and Cancel write nothing either', (tester) async {
      final notDone = phone = _Phone(onboarded: false);
      await pump(tester, text: _caption);
      await tapAndSettle(tester, button('Close'));
      expect(bridge.finishes, 1);
      expect(notDone.others, isEmpty);
    });

    testApp('Cancel on the form writes nothing', (tester) async {
      final notDone = phone = _Phone(onboarded: false);
      await pump(tester);
      await tapAndSettle(tester, button('Cancel'));
      expect(bridge.finishes, 1);
      expect(notDone.others, isEmpty);
    });
  });

  group('keyboard and large text', () {
    testApp('at 200 % text with the keyboard up the new-reel form fits', (
      tester,
    ) async {
      await pump(
        tester,
        textScale: 2,
        keyboard: 280,
        size: const Size(360, 640),
      );

      expect(tester.takeException(), isNull);
      const keyboardTop = 640.0 - 280;
      final nameField = find.byWidgetPredicate(
        (w) => w is TtTextField && w.label == 'New reel name',
      );
      await tester.scrollUntilVisible(
        nameField,
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      final name = tester.getRect(nameField);
      expect(name.bottom, lessThanOrEqualTo(keyboardTop));
      expect(name.top, greaterThanOrEqualTo(0));
      final save = tester.getRect(button('Save'));
      expect(save.bottom, lessThanOrEqualTo(keyboardTop));
    });

    testApp('at 200 % with the keyboard up the label field scrolls into '
        'view with reels', (tester) async {
      await makeReel(tester, 'Goa');
      await makeReel(tester, 'Lisbon');
      await pump(
        tester,
        textScale: 2,
        keyboard: 280,
        size: const Size(360, 640),
      );

      await tester.scrollUntilVisible(
        input('Label (optional)'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(input('Label (optional)')).bottom,
        lessThanOrEqualTo(640.0 - 280),
      );
    });

    testApp('the "not a link" state at 200 % and a small screen fits', (
      tester,
    ) async {
      await pump(
        tester,
        text: _caption,
        textScale: 2,
        size: const Size(360, 480),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Close'), findsOneWidget);
    });

    testApp('the share screen is accessible, light and dark, at 200 %', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      for (final brightness in Brightness.values) {
        await pump(tester, textScale: 2, brightness: brightness);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });

    testApp('the scrim is a labelled button for TalkBack', (tester) async {
      await pump(tester);

      final handle = tester.ensureSemantics();
      final context = tester.element(find.byKey(ShareApp.bodyKey));
      expect(
        find.bySemanticsLabel(MaterialLocalizations.of(context).scrimLabel),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('motion', () {
    testApp('the sheet slides in as the app sheets do, on a ticker', (
      tester,
    ) async {
      await pump(tester, settled: false);

      expect(fadeOf(tester).opacity.value, 0);
      expect(riseOf(tester).position.value, const Offset(0, 1));
      final start = tester.getRect(find.byType(TtSheet)).top;
      expect(start, greaterThanOrEqualTo(800 - 1), reason: 'starts below');
      await tester.pump(const Duration(milliseconds: 100));
      expect(fadeOf(tester).opacity.value, inExclusiveRange(0, 1));
      expect(tester.getRect(find.byType(TtSheet)).top, lessThan(start));

      await settleApp(tester);

      expect(fadeOf(tester).opacity.value, 1);
      expect(
        tester.getRect(find.byType(TtSheet)).bottom,
        lessThanOrEqualTo(800),
      );
      expect(tester.getRect(find.byType(TtSheet)).top, lessThan(800 - 100));
    });

    testApp('with Remove animations there is no ticker, and the sheet is '
        'there at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pump(tester, settled: false);

      // On the very first frame the scrim is full and the sheet in place: the
      // screen's own animation never runs (its duration is zero).
      expect(fadeOf(tester).opacity.value, 1);
      expect(riseOf(tester).position.value, Offset.zero);
      final sheet = tester.getRect(find.byType(TtSheet));
      expect(sheet.top, lessThan(800 - 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(find.byType(TtSheet)), sheet);
      await settleApp(tester);
      expect(find.text(_reelShort), findsOneWidget);
    });
  });

  group('goldens', () {
    for (final (scale, brightness, suffix) in [
      (1.0, Brightness.light, 'light'),
      (1.0, Brightness.dark, 'dark'),
    ]) {
      testApp('the whole screen over a see-through window ($suffix)', (
        tester,
      ) async {
        await makeReel(tester, 'London Food');
        await makeReel(tester, 'Lisbon');
        await pump(tester, textScale: scale, brightness: brightness);
        await tapAndSettle(tester, rowOf('Lisbon'));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/share_app_$suffix.png'),
        );
      }, skip: !_goldens);
    }
  });
}
