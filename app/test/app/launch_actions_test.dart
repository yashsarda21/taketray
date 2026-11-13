import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/notifications/view_models/launch_actions.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/test_app.dart';
import '../support/vm_harness.dart';

/// The app on an in-memory database and fake bridges.
Future<VmHarness> _pumpApp(
  WidgetTester tester, {
  LaunchAction? startedWith,
}) async {
  final harness = VmHarness();
  harness.background.startAction = startedWith;
  await tester.pumpWidget(
    ProviderScope(overrides: harness.appOverrides, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// The app on [harness]'s database, bridges and clock.
Future<void> _pumpWith(WidgetTester tester, VmHarness harness) async {
  await tester.pumpWidget(
    ProviderScope(overrides: harness.appOverrides, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
}

int _tab(WidgetTester tester) =>
    tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex;

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(TtNavPill), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the screen a tap asks for', () {
    // The reel check must not run for the actions that have no reel.
    Future<bool> never(int id) => throw StateError('no reel check expected');

    test('toTag is To tag, reels is Reels', () async {
      expect(
        await routeFor(const Launch(LaunchAction.toTag), never),
        Routes.toTag,
      );
      expect(
        await routeFor(const Launch(LaunchAction.reels), never),
        Routes.reels,
      );
    });

    test('a reel id on To tag or Reels is ignored', () async {
      expect(
        await routeFor(const Launch(LaunchAction.toTag, reelId: 7), never),
        Routes.toTag,
      );
      expect(
        await routeFor(const Launch(LaunchAction.reels, reelId: 7), never),
        Routes.reels,
      );
    });

    test(
      'Done editing for a reel that exists opens its page, asking Done editing',
      () async {
        final asked = <int>[];
        final route = await routeFor(
          const Launch(LaunchAction.doneEditing, reelId: 7),
          (id) async {
            asked.add(id);
            return true;
          },
        );
        expect(route, Routes.reelDoneEditing(7));
        expect(route, '/reels/7?done=1');
        expect(asked, [7], reason: 'one check, for that reel only');
      },
    );

    test('Done editing for a reel that is gone opens Reels', () async {
      expect(
        await routeFor(
          const Launch(LaunchAction.doneEditing, reelId: 7),
          (id) async => false,
        ),
        Routes.reels,
      );
    });

    test(
      'Done editing with no usable reel id opens Reels without asking',
      () async {
        // A check that would say yes (and records it was asked): an id that
        // cannot be a reel's must never reach it.
        final asked = <int>[];
        for (final id in <int?>[null, 0, -1, -997]) {
          expect(
            await routeFor(Launch(LaunchAction.doneEditing, reelId: id), (
              asked_,
            ) async {
              asked.add(asked_);
              return true;
            }),
            Routes.reels,
            reason: '$id',
          );
        }
        expect(asked, isEmpty);
      },
    );

    test('Done editing when the reel check fails opens Reels, logs the type '
        'only', () async {
      final records = captureLogs();
      final route = await routeFor(
        const Launch(LaunchAction.doneEditing, reelId: 7),
        (id) async => throw StateError('Zq secret reel name'),
      );
      expect(route, Routes.reels);
      expect(logText(records), contains('StateError'));
      expect(logText(records), isNot(contains('Zq')));

      // Any error type, not only one.
      records.clear();
      final other = await routeFor(
        const Launch(LaunchAction.doneEditing, reelId: 7),
        (id) async => throw ArgumentError('Zq secret reel name'),
      );
      expect(other, Routes.reels);
      expect(logText(records), contains('ArgumentError'));
      expect(logText(records), isNot(contains('Zq')));
    });

    test('every action has a route', () async {
      for (final action in LaunchAction.values) {
        expect(
          await routeFor(Launch(action, reelId: 3), (id) async => true),
          startsWith('/'),
          reason: action.name,
        );
      }
    });
  });

  testApp('to tag action opens To tag', (tester) async {
    final harness = await _pumpApp(tester);
    expect(_tab(tester), 0);

    harness.background.emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
  });

  testApp('reels action opens Reels', (tester) async {
    final harness = await _pumpApp(tester);
    await _tapTab(tester, 'Settings');
    expect(_tab(tester), 2);

    harness.background.emit(LaunchAction.reels);
    await tester.pumpAndSettle();

    expect(_tab(tester), 0);
  });

  testApp('a tap goes to its screen from any tab, and back again', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    await _tapTab(tester, 'To tag');

    harness.background.emit(LaunchAction.reels);
    await tester.pumpAndSettle();
    harness.background.emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
  });

  testApp('action at start is handled once', (tester) async {
    final harness = await _pumpApp(tester, startedWith: LaunchAction.toTag);
    expect(_tab(tester), 1, reason: 'the app was started by a tap on To tag');
    expect(harness.background.launchListens, 1);

    await _tapTab(tester, 'Reels');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(_tab(tester), 0, reason: 'the start action is not applied again');
    expect(harness.background.launchListens, 1);
  });

  testApp('taps in a row end at the last one', (tester) async {
    final harness = await _pumpApp(tester);

    harness.background
      ..emit(LaunchAction.toTag)
      ..emit(LaunchAction.reels)
      ..emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
  });

  testApp("one listener for the app's whole life", (tester) async {
    final harness = await _pumpApp(tester);

    await _tapTab(tester, 'To tag');
    await _tapTab(tester, 'Settings');
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(null);
    await tester.pumpAndSettle();

    expect(harness.background.launchListens, 1);
    expect(harness.background.launchCancels, 0);
  });

  testApp('stops listening when the app is taken down', (tester) async {
    final harness = await _pumpApp(tester);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(harness.background.launchCancels, 1);
    harness.background.emit(LaunchAction.toTag);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testApp('an error on the stream is logged by type and the next tap works', (
    tester,
  ) async {
    final records = captureLogs();
    final harness = await _pumpApp(tester);

    harness.background.emitError(StateError('/storage/emulated/0/secret'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    harness.background.emit(LaunchAction.toTag);
    await tester.pumpAndSettle();

    expect(_tab(tester), 1);
    expect(logText(records), contains('StateError'));
    expect(logText(records), isNot(contains('secret')));
  });
  group('the tap queue', () {
    test('runs taps one after the other, in the order they came', () async {
      final log = <String>[];
      final first = Completer<void>();
      LaunchQueue((launch) async {
          log.add('start ${launch.action.name}');
          if (launch.action == LaunchAction.doneEditing) await first.future;
          log.add('end ${launch.action.name}');
        })
        ..add(const Launch(LaunchAction.doneEditing, reelId: 1))
        ..add(const Launch(LaunchAction.toTag));
      await pumpEventQueue();
      expect(log, ['start doneEditing'], reason: 'the second waits');

      first.complete();
      await pumpEventQueue();
      expect(log, [
        'start doneEditing',
        'end doneEditing',
        'start toTag',
        'end toTag',
      ]);
    });

    test('a tap that throws never blocks the next, and only its type is '
        'logged', () async {
      final records = captureLogs();
      final done = <LaunchAction>[];
      LaunchQueue((launch) async {
          if (launch.reelId == 1) throw StateError('Zq secret reel name');
          if (launch.reelId == 2) {
            throw ArgumentError('Zq secret reel name');
          }
          done.add(launch.action);
        })
        ..add(const Launch(LaunchAction.doneEditing, reelId: 1))
        ..add(const Launch(LaunchAction.doneEditing, reelId: 2))
        ..add(const Launch(LaunchAction.toTag))
        ..add(const Launch(LaunchAction.reels));
      await pumpEventQueue();

      expect(done, [LaunchAction.toTag, LaunchAction.reels]);
      expect(logText(records), contains('StateError'));
      expect(logText(records), contains('ArgumentError'));
      expect(logText(records), isNot(contains('Zq')));
    });

    test('a synchronous throw is handled too', () async {
      final done = <LaunchAction>[];
      LaunchQueue((launch) {
          if (launch.reelId == 1) throw StateError('x');
          done.add(launch.action);
          return Future<void>.value();
        })
        ..add(const Launch(LaunchAction.doneEditing, reelId: 1))
        ..add(const Launch(LaunchAction.toTag));
      await pumpEventQueue();
      expect(done, [LaunchAction.toTag]);
    });
  });

  group('Done editing', () {
    Uri location(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(TakeTrayApp)))
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri;

    testApp('opens the reel page for a reel that exists, from another tab', (
      tester,
    ) async {
      final harness = VmHarness();
      final reel = await ReelsRepository(
        harness.media.db,
        harness.media.clock,
      ).create('Goa');
      await _pumpWith(tester, harness);
      await _tapTab(tester, 'Settings');

      harness.background.emit(LaunchAction.doneEditing, reelId: reel.id);
      await tester.pumpAndSettle();

      expect(location(tester).toString(), Routes.reelDoneEditing(reel.id));
      expect(_tab(tester), 0);
      expect(
        tester.widget<ReelDetailScreen>(find.byType(ReelDetailScreen)).reelId,
        reel.id,
      );
    });

    testApp('opens Reels for a reel that is gone, an unknown id or none', (
      tester,
    ) async {
      final harness = await _pumpApp(tester);
      await _tapTab(tester, 'Settings');

      for (final id in <int?>[999, null, 0, -4]) {
        await _tapTab(tester, 'Settings');
        harness.background.emit(LaunchAction.doneEditing, reelId: id);
        await tester.pumpAndSettle();
        expect(location(tester).path, Routes.reels, reason: '$id');
        expect(_tab(tester), 0, reason: '$id');
        expect(find.byType(ReelDetailScreen), findsNothing, reason: '$id');
      }
    });

    testApp('a start action with a reel opens it, once', (tester) async {
      final harness = VmHarness();
      final reel = await ReelsRepository(
        harness.media.db,
        harness.media.clock,
      ).create('Goa');
      harness.background
        ..startAction = LaunchAction.doneEditing
        ..startReelId = reel.id;
      await _pumpWith(tester, harness);

      expect(location(tester).toString(), Routes.reelDoneEditing(reel.id));
      expect(harness.background.launchListens, 1);
    });

    testApp('taps in a row end at the last one even when the first needs a '
        'reel check', (tester) async {
      final harness = VmHarness();
      final reel = await ReelsRepository(
        harness.media.db,
        harness.media.clock,
      ).create('Goa');
      await _pumpWith(tester, harness);

      harness.background
        ..emit(LaunchAction.doneEditing, reelId: reel.id)
        ..emit(LaunchAction.toTag);
      await tester.pumpAndSettle();
      expect(_tab(tester), 1, reason: 'To tag was tapped last');

      harness.background
        ..emit(LaunchAction.toTag)
        ..emit(LaunchAction.doneEditing, reelId: reel.id);
      await tester.pumpAndSettle();
      expect(location(tester).toString(), Routes.reelDoneEditing(reel.id));

      harness.background
        ..emit(LaunchAction.doneEditing, reelId: reel.id)
        ..emit(LaunchAction.reels);
      await tester.pumpAndSettle();
      expect(location(tester).path, Routes.reels);
      expect(find.byType(ReelDetailScreen), findsNothing);
    });

    testApp('a slow lookup is not overtaken by a later tap', (tester) async {
      final harness = VmHarness();
      final repo = _SlowReels(harness.media.db, harness.media.clock);
      final reel = await repo.create('Goa');
      repo.gate = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...harness.appOverrides,
            reelsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const TakeTrayApp(),
        ),
      );
      await tester.pumpAndSettle();

      harness.background
        ..emit(LaunchAction.doneEditing, reelId: reel.id)
        ..emit(LaunchAction.toTag);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _tab(tester),
        0,
        reason: 'the earlier tap is still being looked up',
      );

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(_tab(tester), 1, reason: 'To tag was tapped last, so it wins');
      expect(find.byType(ReelDetailScreen), findsNothing);
    });

    testApp('a lookup that finishes after the app is gone does nothing', (
      tester,
    ) async {
      final harness = VmHarness();
      final repo = _SlowReels(harness.media.db, harness.media.clock);
      final reel = await repo.create('Goa');
      repo.gate = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...harness.appOverrides,
            reelsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const TakeTrayApp(),
        ),
      );
      await tester.pumpAndSettle();
      harness.background.emit(LaunchAction.doneEditing, reelId: reel.id);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox.shrink());
      repo.gate!.complete();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
    });

    testApp('two reminders, two taps: each opens its own reel', (tester) async {
      final harness = VmHarness();
      final repo = ReelsRepository(harness.media.db, harness.media.clock);
      final one = await repo.create('One');
      final two = await repo.create('Two');
      await _pumpWith(tester, harness);

      harness.background.emit(LaunchAction.doneEditing, reelId: one.id);
      await tester.pumpAndSettle();
      expect(location(tester).path, Routes.reel(one.id));

      harness.background.emit(LaunchAction.doneEditing, reelId: two.id);
      await tester.pumpAndSettle();
      expect(location(tester).path, Routes.reel(two.id));
    });

    testApp('a reel deleted just before the tap opens Reels', (tester) async {
      final harness = VmHarness();
      final repo = ReelsRepository(harness.media.db, harness.media.clock);
      final reel = await repo.create('Goa');
      await _pumpWith(tester, harness);
      await tester.runAsync(() => repo.delete(reel.id));

      harness.background.emit(LaunchAction.doneEditing, reelId: reel.id);
      await tester.pumpAndSettle();

      expect(location(tester).path, Routes.reels);
    });
  });
}

/// A reels repository whose `getById` waits for [gate] (when set), as a slow
/// phone would.
class _SlowReels extends ReelsRepository {
  // The base class's fields are private, so super parameters cannot be named.
  // ignore: use_super_parameters
  _SlowReels(AppDatabase db, Clock clock) : super(db, clock);

  Completer<void>? gate;

  @override
  Future<Reel?> getById(int id) async {
    final wait = gate;
    if (wait != null) await wait.future;
    return await super.getById(id);
  }
}
