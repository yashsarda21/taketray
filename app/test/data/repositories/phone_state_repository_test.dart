import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/media.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 28, 9);
const Duration _minute = Duration(minutes: 1);

const _phone = VolumeBaseline(version: 'v1', generation: 40);
const _card = VolumeBaseline(version: 'c1', generation: 7);

late AppDatabase db;
late FixedClock clock;
late PhoneStateRepository repo;

Future<void> _put(String key, String value) => db
    .into(db.settings)
    .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

Future<String?> _raw(String key) async => (await (db.select(
  db.settings,
)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

/// Captures log lines (the raw message, so a leak cannot hide).
List<LogRecord> _record() {
  final records = <LogRecord>[];
  final sub = Logger.root.onRecord.listen(records.add);
  addTearDown(sub.cancel);
  return records;
}

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = PhoneStateRepository(db, clock);
  });

  Future<ShootingState> turnOn([
    Map<String, VolumeBaseline> baselines = const {'external_primary': _phone},
  ]) => repo.turnShootingOn(baselines);

  group('shooting state', () {
    test('off by default', () async {
      expect(await repo.loadShooting(), ShootingState.off);
      expect(await repo.watchShooting().first, ShootingState.off);
      expect(await repo.accessWasFull(), isFalse);
    });

    test('on stores since=now and baselines', () async {
      final state = await turnOn({
        'external_primary': _phone,
        'ABCD-1234': _card,
      });

      expect(state.on, isTrue);
      expect(state.since, _t0);
      expect(state.baselines, {'external_primary': _phone, 'ABCD-1234': _card});
      expect(await repo.loadShooting(), state);
      // One row holds the whole state, so it changes atomically.
      final json = jsonDecode((await _raw('shootingMode'))!) as Map;
      expect(json['on'], isTrue);
      expect((json['baselines'] as Map).keys, [
        'external_primary',
        'ABCD-1234',
      ]);
    });

    test('turning on twice keeps the first since', () async {
      final first = await turnOn();
      clock.advance(_minute);

      final second = await turnOn({'external_primary': _card});

      expect(second, first);
      expect(await repo.loadShooting(), first);
      expect(second.since, _t0);
    });

    test('already on keeps since and baselines', () async {
      await turnOn();
      clock.advance(_minute);
      final before = await repo.loadShooting();

      final again = await turnOn({'other': _card});

      expect(again, before);
      expect(again.since, _t0);
      expect(again.baselines, {'external_primary': _phone});
    });

    test('off clears baselines', () async {
      await turnOn();

      await repo.turnShootingOff();

      final state = await repo.loadShooting();
      expect(state, ShootingState.off);
      expect(state.baselines, isEmpty);
      expect(state.since, isNull);
    });

    test('off when already off is fine', () async {
      await repo.turnShootingOff();

      expect(await repo.loadShooting(), ShootingState.off);
    });

    test('a new session after off starts fresh', () async {
      await turnOn();
      await repo.turnShootingOff();
      clock.advance(_minute);

      final next = await turnOn({'external_primary': _card});

      expect(next.since, _t0.add(_minute));
      expect(next.baselines, {'external_primary': _card});
    });

    test('watchShooting emits distinct values only', () async {
      final seen = <ShootingState>[];
      final sub = repo.watchShooting().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await turnOn();
      await pumpEventQueue();
      await turnOn(); // already on: no change
      await pumpEventQueue();
      await _put('somethingElse', '1'); // another key
      await pumpEventQueue();
      await repo.turnShootingOff();
      await pumpEventQueue();

      expect(seen.map((s) => s.on), [false, true, false]);
    });

    test('since keeps its microseconds through the JSON', () async {
      final microsecond = DateTime.utc(2026, 10, 28, 9, 0, 0, 123, 456);
      clock = FixedClock(microsecond);
      repo = PhoneStateRepository(db, clock);

      final state = await turnOn();

      expect((await repo.loadShooting()).since, microsecond);
      expect(state.since, microsecond);
    });
  });

  group('corrupt phone state', () {
    const secret = 'SECRET-VALUE-XYZ';

    for (final (name, raw) in [
      ('invalid JSON', '{not json $secret'),
      ('a number', '12345'),
      ('a list', '["$secret"]'),
      ('a string', '"$secret"'),
      ('the old plain true', 'true'),
      ('missing fields', '{"on": true}'),
      ('wrong field types', '{"on": "$secret", "baselines": {}}'),
      ('a baseline of the wrong shape', '{"on": false, "baselines": {"a": 3}}'),
      ('a bad date', '{"on": true, "baselines": {}, "since": "$secret"}'),
      ('on without a start time', '{"on": true, "baselines": {}}'),
      (
        'a generation too big for a double (1e400 is Infinity)',
        '{"on": true, "since": "2026-10-28T09:00:00.000Z", "baselines": '
            '{"a": {"version": "v", "generation": 1e400}}}',
      ),
    ]) {
      test('$name reads as off and logs the key only', () async {
        await _put('shootingMode', raw);
        final records = _record();

        expect(await repo.loadShooting(), ShootingState.off);
        expect(await repo.watchShooting().first, ShootingState.off);

        final lines = records.map((r) => r.message).join('\n');
        expect(lines, contains('shootingMode'));
        expect(lines, isNot(contains(secret)));
        expect(lines, isNot(contains('12345')));
        expect(lines, isNot(contains('not json')));
      });
    }

    test('turning on over a corrupt value starts a session', () async {
      await _put('shootingMode', '{broken');

      final state = await turnOn();

      expect(state.on, isTrue);
      expect(await repo.loadShooting(), state);
    });

    test('a corrupt mediaAccessWasFull reads as false, key only', () async {
      await _put('mediaAccessWasFull', '"$secret"');
      final records = _record();

      expect(await repo.accessWasFull(), isFalse);

      final lines = records.map((r) => r.message).join('\n');
      expect(lines, contains('mediaAccessWasFull'));
      expect(lines, isNot(contains(secret)));
    });
  });

  group('access was full', () {
    test('false until marked, then true, and marking twice is fine', () async {
      expect(await repo.accessWasFull(), isFalse);

      await repo.markAccessWasFull();
      await repo.markAccessWasFull();

      expect(await repo.accessWasFull(), isTrue);
    });

    test('is separate from Shooting mode', () async {
      await repo.markAccessWasFull();
      await turnOn();
      await repo.turnShootingOff();

      expect(await repo.accessWasFull(), isTrue);
    });
  });

  group('backups', () {
    test('phone-state keys are not exported', () async {
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.shootingModeKey)),
      );
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.mediaAccessWasFullKey)),
      );
      expect(PhoneStateRepository.shootingModeKey, 'shootingMode');
      expect(PhoneStateRepository.mediaAccessWasFullKey, 'mediaAccessWasFull');

      await turnOn();
      await repo.markAccessWasFull();
      final text = await BackupService(db, clock).exportJson();

      expect(text, isNot(contains('shootingMode')));
      expect(text, isNot(contains('mediaAccessWasFull')));
      expect(text, isNot(contains('external_primary')));
    });

    test('import turns Shooting mode off', () async {
      await turnOn();
      await repo.markAccessWasFull();
      final fixture = File('test/data/backup/fixtures/backup_v1.json')
          .readAsStringSync();

      await BackupService(db, clock).importJson(fixture);

      expect(await repo.loadShooting(), ShootingState.off);
      expect(await repo.accessWasFull(), isFalse);
    });
  });

  group('volume versions (Ruling V)', () {
    test('none by default; recorded per volume', () async {
      expect(await repo.volumeVersions(), isEmpty);

      await repo.recordVolumeVersion('external_primary', 'v1');
      await repo.recordVolumeVersion('ABCD-1234', 'c1');
      await repo.recordVolumeVersion('external_primary', 'v2');

      expect(await repo.volumeVersions(), {
        'external_primary': 'v2',
        'ABCD-1234': 'c1',
      });
    });

    test('kept when Shooting mode goes off', () async {
      await turnOn();
      await repo.recordVolumeVersion('external_primary', 'v1');

      await repo.turnShootingOff();

      expect(await repo.volumeVersions(), {'external_primary': 'v1'});
    });

    test('never exported, and an import forgets them', () async {
      expect(PhoneStateRepository.volumeVersionsKey, 'mediaVolumeVersions');
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.volumeVersionsKey)),
      );
      await repo.recordVolumeVersion('external_primary', 'secret-version');
      final text = await BackupService(db, clock).exportJson();
      expect(text, isNot(contains('mediaVolumeVersions')));
      expect(text, isNot(contains('secret-version')));

      await BackupService(db, clock).importJson(
        File('test/data/backup/fixtures/backup_v1.json').readAsStringSync(),
      );

      expect(await repo.volumeVersions(), isEmpty);
    });

    for (final (name, value) in [
      ('not JSON', 'nope'),
      ('a list', '["v1"]'),
      ('a number as a version', '{"external_primary": 3}'),
    ]) {
      test('$name reads as none, logging only the key', () async {
        final records = _record();
        await _put('mediaVolumeVersions', value);

        expect(await repo.volumeVersions(), isEmpty);

        expect(
          records.map((r) => r.message),
          contains(contains('mediaVolumeVersions')),
        );
        for (final r in records) {
          expect(r.message, isNot(contains(value)));
        }
        // Recording over a corrupt value starts a fresh map.
        await repo.recordVolumeVersion('external_primary', 'v1');
        expect(await repo.volumeVersions(), {'external_primary': 'v1'});
      });
    }
  });

  group('a state stored before D-90', () {
    test('with earlierAdded: true still loads, and the next write drops the '
        'key', () async {
      await _put(
        'shootingMode',
        jsonEncode({
          'on': true,
          'baselines': {
            'external_primary': {'version': 'v1', 'generation': 40},
          },
          'since': '2026-10-28T09:00:00.000Z',
          'earlierAdded': true,
        }),
      );

      final state = await repo.loadShooting();
      expect(state.on, isTrue);
      expect(state.since, _t0);
      expect(state.baselines, {'external_primary': _phone});
      expect(await repo.watchShooting().first, state);

      // A write rewrites the whole value without the old key.
      expect(
        await repo.advanceBaseline(
          'external_primary',
          expectedSession: state,
          expected: _phone,
          next: const VolumeBaseline(version: 'v1', generation: 45),
        ),
        isTrue,
      );
      final json = jsonDecode((await _raw('shootingMode'))!) as Map;
      expect(json.containsKey('earlierAdded'), isFalse);
      expect((await repo.loadShooting()).since, _t0);
    });
  });

  group('advanceBaseline is compare-and-set', () {
    late ShootingState session;
    const next = VolumeBaseline(version: 'v1', generation: 45);

    setUp(() async {
      session = await turnOn();
    });

    Future<bool> advance({
      ShootingState? expectedSession,
      VolumeBaseline? expected = _phone,
      VolumeBaseline to = next,
      String volume = 'external_primary',
    }) => repo.advanceBaseline(
      volume,
      expectedSession: expectedSession ?? session,
      expected: expected,
      next: to,
    );

    test('it writes on a match', () async {
      expect(await advance(), isTrue);

      final state = await repo.loadShooting();
      expect(state.baselines, {'external_primary': next});
      expect(state.since, session.since);
      expect(state.on, isTrue);
    });

    test('it keeps the other volumes', () async {
      await repo.turnShootingOff();
      session = await turnOn({'external_primary': _phone, 'ABCD-1234': _card});

      expect(await advance(), isTrue);

      final state = await repo.loadShooting();
      expect(state.baselines, {'external_primary': next, 'ABCD-1234': _card});
    });

    test('it writes when the generation stays the same', () async {
      expect(await advance(to: _phone), isTrue);
      expect((await repo.loadShooting()).baselines, {
        'external_primary': _phone,
      });
    });

    test('it refuses after off/on (the since differs)', () async {
      await repo.turnShootingOff();
      clock.advance(_minute);
      final newer = await turnOn();

      expect(await advance(), isFalse);

      expect(await repo.loadShooting(), newer);
    });

    test('it refuses when Shooting mode is off', () async {
      await repo.turnShootingOff();

      expect(await advance(), isFalse);

      expect(await repo.loadShooting(), ShootingState.off);
      expect(await _raw('shootingMode'), isNull);
    });

    test('it refuses an expected session that is off', () async {
      expect(await advance(expectedSession: ShootingState.off), isFalse);

      expect(await repo.loadShooting(), session);
    });

    test('it refuses when the stored baseline changed', () async {
      const other = VolumeBaseline(version: 'v1', generation: 41);
      expect(await advance(expected: other), isFalse);
      const otherVersion = VolumeBaseline(version: 'v2', generation: 40);
      expect(await advance(expected: otherVersion), isFalse);

      expect(await repo.loadShooting(), session);
    });

    test('it refuses when moving backwards', () async {
      const back = VolumeBaseline(version: 'v1', generation: 39);

      expect(await advance(to: back), isFalse);

      expect(await repo.loadShooting(), session);
    });

    test(
      'a rebuilt volume may write a lower generation in one version',
      () async {
        const back = VolumeBaseline(version: 'v1', generation: 4);

        expect(
          await repo.advanceBaseline(
            'external_primary',
            expectedSession: session,
            expected: _phone,
            next: back,
            rebuilt: true,
          ),
          isTrue,
        );

        expect((await repo.loadShooting()).baselines, {
          'external_primary': back,
        });
      },
    );

    test('rebuilt still refuses a stale session or baseline', () async {
      const back = VolumeBaseline(version: 'v1', generation: 4);
      const other = VolumeBaseline(version: 'v1', generation: 41);
      expect(
        await repo.advanceBaseline(
          'external_primary',
          expectedSession: session,
          expected: other,
          next: back,
          rebuilt: true,
        ),
        isFalse,
      );
      await repo.turnShootingOff();
      clock.advance(_minute);
      final newer = await turnOn();
      expect(
        await repo.advanceBaseline(
          'external_primary',
          expectedSession: session,
          expected: _phone,
          next: back,
          rebuilt: true,
        ),
        isFalse,
      );

      expect(await repo.loadShooting(), newer);
    });

    test('a version change (Resync) may write a lower generation', () async {
      const resynced = VolumeBaseline(version: 'v2', generation: 3);

      expect(await advance(to: resynced), isTrue);

      expect((await repo.loadShooting()).baselines, {
        'external_primary': resynced,
      });
    });

    test(
      'it writes for a volume with no baseline when expected is null',
      () async {
        expect(
          await advance(volume: 'ABCD-1234', expected: null, to: _card),
          isTrue,
        );

        expect((await repo.loadShooting()).baselines, {
          'external_primary': _phone,
          'ABCD-1234': _card,
        });
      },
    );

    test('a stored baseline with expected null is refused', () async {
      expect(await advance(expected: null), isFalse);

      expect(await repo.loadShooting(), session);
    });

    test('a baseline that is stored while expected is not null and '
        'the volume has none is refused', () async {
      expect(
        await advance(volume: 'ABCD-1234', expected: _card, to: _card),
        isFalse,
      );

      expect(await repo.loadShooting(), session);
    });

    test('two concurrent calls with the same expected: one wins', () async {
      const a = VolumeBaseline(version: 'v1', generation: 50);
      const b = VolumeBaseline(version: 'v1', generation: 60);

      final results = await Future.wait([advance(to: a), advance(to: b)]);

      expect(results.where((r) => r), hasLength(1));
      final winner = results[0] ? a : b;
      expect((await repo.loadShooting()).baselines, {
        'external_primary': winner,
      });
    });

    test('a stale scan cannot overwrite a newer session', () async {
      // Scan A starts in the first session. Meanwhile the user turns Shooting
      // mode off and on, and the new session gets its own baseline.
      await repo.turnShootingOff();
      clock.advance(_minute);
      const fresh = VolumeBaseline(version: 'v9', generation: 1000);
      final newer = await turnOn({'external_primary': fresh});

      expect(await advance(expected: fresh), isFalse);
      expect(await advance(), isFalse);

      expect(await repo.loadShooting(), newer);
    });

    test('logs no versions or names', () async {
      final records = _record();
      await advance();
      await advance(to: const VolumeBaseline(version: 'v1', generation: 1));

      final lines = records.map((r) => r.message).join('\n');
      expect(lines, isNot(contains('v1')));
    });
  });

  test('logs counts only, never values', () async {
    final records = _record();
    await turnOn({'external_primary': _phone});
    await repo.markAccessWasFull();
    await repo.turnShootingOff();

    expect(records, isNotEmpty);
    final lines = records.map((r) => r.message).join('\n');
    expect(lines, isNot(contains('"v1"')));
    expect(lines, isNot(contains('2026')));
  });
}
