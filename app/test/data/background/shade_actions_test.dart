import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/background/shade_actions.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../support/fake_background_bridge.dart';
import '../../support/fake_media_bridge.dart';
import '../media/media_harness.dart';

// `ShadeActions.apply` (D-106): the Still shooting? buttons tapped in the
// shade while the app was closed, applied by Dart only to their own session.

MediaVideo _video(int id, int generation) =>
    fakeVideo(id: id, generation: generation, sizeBytes: 1000000 + id);

late MediaHarness h;
late FakeBackgroundBridge shade;
late ShadeActions actions;
late DateTime since;

final DateTime _tap = DateTime.utc(2026, 6, 15, 18, 30);

ShadeAction _turnOff({DateTime? forSession, Map<String, int>? generations}) =>
    ShadeAction(
      kind: ShadeActionKind.turnOff,
      since: forSession ?? since,
      at: _tap,
      generations: generations ?? {phone: 12},
    );

ShadeAction _keepOn({DateTime? forSession}) => ShadeAction(
  kind: ShadeActionKind.keepOn,
  since: forSession ?? since,
  at: _tap,
  generations: const {},
);

/// How many ends of a session got past the session check (each asks the
/// phone for its access first; nothing else here does).
int _ends() => h.bridge.count('accessReport');

Future<Set<int>> _toTagIds() async => {
  for (final c in await h.toTag()) c.mediaStoreId!,
};

void main() {
  setUp(() async {
    h = MediaHarness();
    shade = h.background;
    actions = ShadeActions(h.scanner);
    h.bridge.put([_video(1, 10)]);
    since = (await h.turnOnNow()).since!;
    // 11 and 12 shot before the tap (generation 12 then), 13 after it.
    h.bridge.put([_video(11, 11), _video(12, 12), _video(13, 13)]);
  });

  test('no action does nothing', () async {
    await actions.apply();

    expect(shade.calls, ['pendingShadeAction']);
    expect(_ends(), 0);
    expect((await h.phoneState.loadShooting()).on, isTrue);
  });

  test('turn off from the shade applies once', () async {
    shade.shadeAction = _turnOff();

    await actions.apply();

    expect(await _toTagIds(), {11, 12});
    expect(await h.phoneState.loadShooting(), ShootingState.off);
    expect(shade.clearedShadeActions, [_tap]);
    expect(shade.shadeAction, isNull);
    expect(_ends(), 1);

    // Applied: a second apply finds nothing.
    await actions.apply();
    expect(_ends(), 1);
    expect(await _toTagIds(), {11, 12});
    expect(shade.clearedShadeActions, [_tap]);
  });

  test('two applies at once end the session once', () async {
    shade.shadeAction = _turnOff();

    await Future.wait([actions.apply(), actions.apply()]);

    expect(_ends(), 1);
    expect(await _toTagIds(), {11, 12});
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('clips shot after the tap are not added', () async {
    shade.shadeAction = _turnOff(generations: {phone: 11});

    await actions.apply();

    expect(await _toTagIds(), {11});
  });

  test('shade action for another session is dropped and cleared', () async {
    // Turned off and on again since the notification was posted.
    final older = since.subtract(const Duration(days: 15));
    shade.shadeAction = _turnOff(forSession: older);
    final records = captureLogs();

    await actions.apply();

    expect(_ends(), 0);
    expect(await h.allClips(), isEmpty);
    final state = await h.phoneState.loadShooting();
    expect(state.on, isTrue);
    expect(state.since, since);
    expect(shade.clearedShadeActions, [_tap]);
    expect(shade.shadeAction, isNull);
    expect(logText(records), contains('another session'));
  });

  test('keep on for another session is dropped too', () async {
    shade.shadeAction = _keepOn(
      forSession: since.add(const Duration(minutes: 1)),
    );

    await actions.apply();

    expect((await h.phoneState.loadShooting()).stillAnswered, isFalse);
    expect(shade.shadeAction, isNull);
  });

  test('an action with Shooting mode already off is dropped', () async {
    await h.phoneState.turnShootingOff();
    shade.shadeAction = _turnOff();

    await actions.apply();

    expect(_ends(), 0);
    expect(await h.allClips(), isEmpty);
    expect(shade.shadeAction, isNull);
  });

  test('keep on marks answered', () async {
    final before = await h.phoneState.loadShooting();
    shade.shadeAction = _keepOn();

    await actions.apply();

    final state = await h.phoneState.loadShooting();
    expect(state.stillAnswered, isTrue);
    expect(state.on, isTrue);
    expect(state.since, before.since);
    expect(state.baselines, before.baselines);
    expect(await h.allClips(), isEmpty);
    expect(_ends(), 0);
    expect(shade.clearedShadeActions, [_tap]);
  });

  test('a session stored with microseconds matches the tap', () async {
    await h.phoneState.turnShootingOff();
    h.clock.advance(const Duration(microseconds: 321));
    since = (await h.turnOnNow()).since!;
    shade.shadeAction = _keepOn(
      forSession: DateTime.fromMillisecondsSinceEpoch(
        since.millisecondsSinceEpoch,
        isUtc: true,
      ),
    );

    await actions.apply();

    expect((await h.phoneState.loadShooting()).stillAnswered, isTrue);
  });

  test('bridge error keeps the action', () async {
    shade
      ..shadeAction = _turnOff()
      ..failNext('clearShadeAction');

    await expectLater(actions.apply(), throwsA(isA<PlatformException>()));

    // The session ended, but the action stays for the next start.
    expect(await h.phoneState.loadShooting(), ShootingState.off);
    expect(shade.shadeAction, isNotNull);

    // The next start drops it as stale (its session is gone) and clears it,
    // adding nothing twice.
    await actions.apply();
    expect(shade.shadeAction, isNull);
    expect(await _toTagIds(), {11, 12});
    expect(_ends(), 1);
  });

  test('a failing read changes nothing', () async {
    shade
      ..shadeAction = _turnOff()
      ..failNext('pendingShadeAction');

    await expectLater(actions.apply(), throwsA(isA<PlatformException>()));

    expect((await h.phoneState.loadShooting()).on, isTrue);
    expect(shade.shadeAction, isNotNull);
    expect(_ends(), 0);
  });

  test('a failing end keeps the action and the session', () async {
    shade.shadeAction = _turnOff();
    h.bridge.failNext('volumes');

    await expectLater(actions.apply(), throwsA(isA<PlatformException>()));

    expect((await h.phoneState.loadShooting()).on, isTrue);
    expect(shade.shadeAction, isNotNull);
    expect(shade.clearedShadeActions, isEmpty);

    // Tried again at the next start.
    await actions.apply();
    expect(await _toTagIds(), {11, 12});
    expect(shade.shadeAction, isNull);
  });

  test('a newer tap during the apply is kept', () async {
    shade.shadeAction = _keepOn();
    final gate = shade.gate('clearShadeAction');

    final applying = actions.apply();
    await until(() => shade.calls.contains('clearShadeAction'));
    final newer = _turnOff().copyWith(at: _tap.add(const Duration(seconds: 5)));
    shade.shadeAction = newer;
    gate.complete();
    await applying;

    expect(shade.shadeAction, newer);
  });

  test('logs the kind only, never a time', () async {
    final records = captureLogs();
    shade.shadeAction = _turnOff();

    await actions.apply();

    final text = logText(records);
    expect(text, contains('turnOff'));
    expect(text, isNot(contains('2026')));
    expect(text, isNot(contains('DCIM')));
  });
}
