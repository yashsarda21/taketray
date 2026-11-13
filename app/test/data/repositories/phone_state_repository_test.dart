import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/copy_job_plan.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/rematch_window.dart';

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
        'a stillAnswered that is not a bool',
        '{"on": true, "since": "2026-10-28T09:00:00.000Z", "baselines": {}, '
            '"stillAnswered": "$secret"}',
      ),
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

  group('notifications asked', () {
    test('false until marked, then true, and marking twice is fine', () async {
      expect(PhoneStateRepository.notificationsAskedKey, 'notificationsAsked');
      expect(await repo.notificationsAsked(), isFalse);

      await repo.markNotificationsAsked();
      await repo.markNotificationsAsked();

      expect(await repo.notificationsAsked(), isTrue);
    });

    test('is separate from Shooting mode and from access', () async {
      await turnOn();
      await repo.markNotificationsAsked();
      await repo.turnShootingOff();

      expect(await repo.notificationsAsked(), isTrue);
      expect(await repo.accessWasFull(), isFalse);
    });

    test(
      'a value that cannot be read counts as not asked, by key only',
      () async {
        const secret = 'private-note';
        await _put('notificationsAsked', '"$secret"');
        final records = _record();

        expect(await repo.notificationsAsked(), isFalse);

        final lines = records.map((r) => r.message).join('\n');
        expect(lines, contains('notificationsAsked'));
        expect(lines, isNot(contains(secret)));
      },
    );

    test('a value that is not JSON counts as not asked', () async {
      await _put('notificationsAsked', '{not json');

      expect(await repo.notificationsAsked(), isFalse);
    });

    test('is not exported, and an import forgets it', () async {
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.notificationsAskedKey)),
      );
      await repo.markNotificationsAsked();
      expect(
        await BackupService(db, clock).exportJson(),
        isNot(contains('notificationsAsked')),
      );
      final fixture = File('test/data/backup/fixtures/backup_v1.json')
          .readAsStringSync();

      await BackupService(db, clock).importJson(fixture);

      expect(await repo.notificationsAsked(), isFalse);
    });
  });

  group('folder tip seen (Add videos, D-114)', () {
    test('false until marked, then true, and marking twice is fine', () async {
      expect(PhoneStateRepository.folderTipSeenKey, 'folderTipSeen');
      expect(await repo.folderTipSeen(), isFalse);

      await repo.markFolderTipSeen();
      await repo.markFolderTipSeen();

      expect(await repo.folderTipSeen(), isTrue);
      expect(await _raw('folderTipSeen'), 'true');
    });

    test('is separate from Shooting mode, access and notifications', () async {
      await turnOn();
      await repo.markFolderTipSeen();
      await repo.turnShootingOff();

      expect(await repo.folderTipSeen(), isTrue);
      expect(await repo.accessWasFull(), isFalse);
      expect(await repo.notificationsAsked(), isFalse);
    });

    test(
      'a value that cannot be read counts as not seen, by key only',
      () async {
        const secret = 'private-note';
        await _put('folderTipSeen', '"$secret"');
        final records = _record();

        expect(await repo.folderTipSeen(), isFalse);

        final lines = records.map((r) => r.message).join('\n');
        expect(lines, contains('folderTipSeen'));
        expect(lines, isNot(contains(secret)));
      },
    );

    test('a value that is not JSON counts as not seen', () async {
      await _put('folderTipSeen', '{not json');

      expect(await repo.folderTipSeen(), isFalse);
    });

    test('is not exported, and an import forgets it', () async {
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.folderTipSeenKey)),
      );
      await repo.markFolderTipSeen();
      expect(
        await BackupService(db, clock).exportJson(),
        isNot(contains('folderTipSeen')),
      );
      final fixture = File('test/data/backup/fixtures/backup_v1.json')
          .readAsStringSync();

      await BackupService(db, clock).importJson(fixture);

      expect(await repo.folderTipSeen(), isFalse);
    });
  });

  group('copy job plan (D-123, p8-task6)', () {
    CopyJobPlan plan(String jobId, {int reelId = 3}) => CopyJobPlan(
      jobId: jobId,
      reelId: reelId,
      editor: EditorApp.vn,
      folderName: 'Goa trip',
      startedSession: true,
      items: const [
        (clipId: 11, fileName: '2026-10-12_14-32-05.mp4', sizeBytes: 900),
        (clipId: 12, fileName: '2026-10-12_14-32-05_2.mov', sizeBytes: 5),
      ],
    );

    test(
      'none until saved; saved, it reads back equal, under its key',
      () async {
        expect(PhoneStateRepository.copyJobPlanKey, 'copyJobPlan');
        expect(await repo.copyJobPlan(), isNull);

        await repo.saveCopyJobPlan(plan('3-100'));

        expect(await repo.copyJobPlan(), plan('3-100'));
        expect(await _raw('copyJobPlan'), contains('"jobId":"3-100"'));
      },
    );

    test('keeps the editor, startedSession and the items in order', () async {
      final other = CopyJobPlan(
        jobId: '4-1',
        reelId: 4,
        editor: EditorApp.capcut,
        folderName: 'Paris',
        startedSession: false,
        items: const [
          (clipId: 9, fileName: 'b.mp4', sizeBytes: 1),
          (clipId: 2, fileName: 'a.mp4', sizeBytes: 3000000000),
        ],
      );
      await repo.saveCopyJobPlan(other);

      final read = (await repo.copyJobPlan())!;
      expect(read.editor, EditorApp.capcut);
      expect(read.startedSession, isFalse);
      expect([for (final i in read.items) i.clipId], [9, 2]);
      expect(read.items.last.sizeBytes, 3000000000);
    });

    test("saving the same job again replaces it; another job's plan throws "
        'StateError and is not written', () async {
      await repo.saveCopyJobPlan(plan('3-100'));
      final again = CopyJobPlan(
        jobId: '3-100',
        reelId: 3,
        editor: EditorApp.vn,
        folderName: 'Goa trip',
        startedSession: false,
        items: const [],
      );
      await repo.saveCopyJobPlan(again);
      expect(await repo.copyJobPlan(), again);

      await expectLater(
        repo.saveCopyJobPlan(plan('5-200', reelId: 5)),
        throwsStateError,
      );
      expect(await repo.copyJobPlan(), again);
    });

    test(
      'remove takes only the plan of that job, and says whether it did',
      () async {
        await repo.saveCopyJobPlan(plan('3-100'));

        expect(await repo.removeCopyJobPlan('3-999'), isFalse);
        expect(await repo.copyJobPlan(), plan('3-100'));

        expect(await repo.removeCopyJobPlan('3-100'), isTrue);
        expect(await repo.copyJobPlan(), isNull);
        expect(await _raw('copyJobPlan'), isNull);
        expect(await repo.removeCopyJobPlan('3-100'), isFalse);
      },
    );

    test('an unreadable value is no plan, logged by key only, and a save '
        'replaces it', () async {
      final records = _record();
      const goa = '"folderName":"Goa trip"';
      const on = '"startedSession":true';
      const oneBadItem = '"items":[{"clipId":1,"fileName":"x.mp4"}]';
      for (final bad in <String>[
        '{not json',
        '"Goa trip"',
        '{"jobId":"3-1","reelId":3,"editor":"vn",$goa,$on}',
        '{"jobId":"3-1","reelId":3,"editor":"imovie",$goa,$on,"items":[]}',
        '{"jobId":"3-1","reelId":"3","editor":"vn",$goa,$on,"items":[]}',
        '{"jobId":"3-1","reelId":3,"editor":"vn",$goa,$on,$oneBadItem}',
        '{"jobId":"","reelId":3,"editor":"vn",$goa,$on,"items":[]}',
      ]) {
        await _put('copyJobPlan', bad);
        expect(await repo.copyJobPlan(), isNull, reason: bad);
      }
      final lines = records.map((r) => r.message).join('\n');
      expect(lines, contains('copyJobPlan'));
      expect(lines, isNot(contains('Goa trip')));
      expect(lines, isNot(contains('x.mp4')));

      await repo.saveCopyJobPlan(plan('3-100'));
      expect(await repo.copyJobPlan(), plan('3-100'));
    });

    test('logs neither the folder nor a file name', () async {
      final records = _record();
      await repo.saveCopyJobPlan(plan('3-100'));
      await repo.copyJobPlan();
      await repo.removeCopyJobPlan('3-100');

      final lines = records.map((r) => r.message).join('\n');
      expect(lines, isNot(contains('Goa trip')));
      expect(lines, isNot(contains('14-32-05')));
      expect(plan('3-100').toString(), isNot(contains('Goa trip')));
      expect(plan('3-100').toString(), isNot(contains('14-32-05')));
    });

    test('is not exported, and an import forgets it', () async {
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.copyJobPlanKey)),
      );
      await repo.saveCopyJobPlan(plan('3-100'));
      expect(
        await BackupService(db, clock).exportJson(),
        isNot(contains('copyJobPlan')),
      );
      final fixture = File('test/data/backup/fixtures/backup_v1.json')
          .readAsStringSync();

      await BackupService(db, clock).importJson(fixture);

      expect(await repo.copyJobPlan(), isNull);
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

  group('re-match windows (D-108)', () {
    const phone = 'external_primary';
    const card = 'ABCD-1234';

    test('none by default; opened, read back, and closed', () async {
      expect(PhoneStateRepository.rematchWindowsKey, 'mediaRematchWindows');
      expect(await repo.rematchWindow(phone), isNull);

      await repo.openRematchWindow(
        phone,
        clipIds: {3, 9},
        generation: 41,
        at: _t0,
      );
      await repo.openRematchWindow(card, clipIds: {5}, generation: 2, at: _t0);

      expect(
        await repo.rematchWindow(phone),
        RematchWindow(openedAt: _t0, clipIds: const {3, 9}, generation: 41),
      );
      expect(
        await repo.rematchWindow(card),
        RematchWindow(openedAt: _t0, clipIds: const {5}, generation: 2),
      );

      await repo.closeRematchWindow(phone);
      expect(await repo.rematchWindow(phone), isNull);
      expect(await repo.rematchWindow(card), isNotNull, reason: 'per volume');

      // Closing the last one removes the key; closing none is fine.
      await repo.closeRematchWindow(card);
      await repo.closeRematchWindow(card);
      expect(await _raw('mediaRematchWindows'), isNull);
    });

    test('the time is kept to the millisecond, in UTC', () async {
      final at = DateTime.utc(2026, 10, 28, 9, 0, 0, 123);
      await repo.openRematchWindow(
        phone,
        clipIds: {1},
        generation: 1,
        at: at.toLocal(),
      );

      final window = (await repo.rematchWindow(phone))!;
      expect(window.openedAt, at);
      expect(window.openedAt.isUtc, isTrue);
    });

    test('a second rebuild while one is open adds its clips and starts the '
        '24 hours again', () async {
      await repo.openRematchWindow(phone, clipIds: {3}, generation: 4, at: _t0);
      final later = _t0.add(const Duration(hours: 20));

      await repo.openRematchWindow(
        phone,
        clipIds: {8},
        generation: 1,
        at: later,
      );

      expect(
        await repo.rematchWindow(phone),
        RematchWindow(openedAt: later, clipIds: const {3, 8}, generation: 1),
      );
    });

    test('a rebuild after the old window ended starts a fresh one', () async {
      await repo.openRematchWindow(phone, clipIds: {3}, generation: 4, at: _t0);
      final later = _t0.add(rematchWindowLength);

      await repo.openRematchWindow(
        phone,
        clipIds: {8},
        generation: 1,
        at: later,
      );

      expect(
        await repo.rematchWindow(phone),
        RematchWindow(openedAt: later, clipIds: const {8}, generation: 1),
      );
    });

    test('a re-match moves the generation, and only of an open '
        'window', () async {
      await repo.openRematchWindow(phone, clipIds: {3}, generation: 4, at: _t0);

      await repo.recordRematch(phone, 9);
      await repo.recordRematch(card, 9);

      expect((await repo.rematchWindow(phone))!.generation, 9);
      expect(await repo.rematchWindow(card), isNull, reason: 'none opened');
    });

    test('kept when Shooting mode goes off', () async {
      await turnOn();
      await repo.openRematchWindow(phone, clipIds: {3}, generation: 4, at: _t0);

      await repo.turnShootingOff();

      expect(await repo.rematchWindow(phone), isNotNull);
    });

    test('never exported, and an import forgets it', () async {
      expect(
        SettingsRepository.exportedKeys,
        isNot(contains(PhoneStateRepository.rematchWindowsKey)),
      );
      await repo.openRematchWindow(phone, clipIds: {3}, generation: 4, at: _t0);
      final text = await BackupService(db, clock).exportJson();
      expect(text, isNot(contains('mediaRematchWindows')));

      await BackupService(db, clock).importJson(
        File('test/data/backup/fixtures/backup_v1.json').readAsStringSync(),
      );

      expect(await repo.rematchWindow(phone), isNull);
    });

    for (final (name, value) in [
      ('not JSON', 'nope'),
      ('a list', '[1]'),
      ('a volume that is not an object', '{"external_primary": "private"}'),
      (
        'a time that is not a number',
        '{"external_primary": {"openedAtMs": "x", "clipIds": [1], '
            '"generation": 1}}',
      ),
      (
        'clip ids that are not numbers',
        '{"external_primary": {"openedAtMs": 1, "clipIds": ["private"], '
            '"generation": 1}}',
      ),
      (
        'a generation that is missing',
        '{"external_primary": {"openedAtMs": 1, "clipIds": [1]}}',
      ),
      (
        'a time that is not a whole number',
        '{"external_primary": {"openedAtMs": 9e99, "clipIds": [1], '
            '"generation": 1}}',
      ),
      (
        'a time out of range',
        '{"external_primary": {"openedAtMs": 99999999999999999, '
            '"clipIds": [1], "generation": 1}}',
      ),
    ]) {
      test('$name reads as no window, logging only the key', () async {
        final records = _record();
        await _put('mediaRematchWindows', value);

        expect(await repo.rematchWindow(phone), isNull);

        expect(
          records.map((r) => r.message),
          contains(contains('mediaRematchWindows')),
        );
        for (final r in records) {
          expect(r.message, isNot(contains(value)));
          expect(r.message, isNot(contains('private')));
        }
        // Read once, it is dropped: the next read has nothing to log.
        expect(await _raw('mediaRematchWindows'), isNull);
        records.clear();
        expect(await repo.rematchWindow(phone), isNull);
        expect(await repo.rematchWindow(card), isNull);
        expect(records, isEmpty);
        // Opening over it starts a fresh map.
        await repo.openRematchWindow(
          phone,
          clipIds: {1},
          generation: 1,
          at: _t0,
        );
        expect(await repo.rematchWindow(phone), isNotNull);
      });
    }

    test('a readable value is not touched by reading it', () async {
      await repo.openRematchWindow(phone, clipIds: {3}, generation: 4, at: _t0);
      final before = await _raw('mediaRematchWindows');
      final records = _record();

      expect(await repo.rematchWindow(phone), isNotNull);
      expect(await repo.rematchWindow(card), isNull);

      expect(await _raw('mediaRematchWindows'), before);
      expect(records, isEmpty);
    });

    test('a corrupt value met by a write (close, record) is replaced or '
        'left, never half-read', () async {
      await _put('mediaRematchWindows', 'nope');

      await repo.recordRematch(phone, 9);
      await repo.closeRematchWindow(phone);

      expect(await repo.rematchWindow(phone), isNull);
    });
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

  group('the Still shooting? answer and the session', () {
    test('old shooting json reads stillAnswered false', () async {
      await _put(
        'shootingMode',
        jsonEncode({
          'on': true,
          'baselines': {
            'external_primary': {'version': 'v1', 'generation': 40},
          },
          'since': '2026-10-28T09:00:00.000Z',
        }),
      );

      final state = await repo.loadShooting();
      expect(state.on, isTrue);
      expect(state.stillAnswered, isFalse);
      // A null is the same as no key.
      await _put(
        'shootingMode',
        jsonEncode({
          'on': true,
          'baselines': <String, Object>{},
          'since': '2026-10-28T09:00:00.000Z',
          'stillAnswered': null,
        }),
      );
      expect((await repo.loadShooting()).stillAnswered, isFalse);
      expect((await repo.loadShooting()).on, isTrue);
    });

    test('a new session is not answered', () async {
      expect((await turnOn()).stillAnswered, isFalse);
    });

    test('advance keeps stillAnswered', () async {
      final session = await turnOn();
      expect(await repo.markStillAnswered(session.since!), isTrue);

      expect(
        await repo.advanceBaseline(
          'external_primary',
          expectedSession: await repo.loadShooting(),
          expected: _phone,
          next: const VolumeBaseline(version: 'v1', generation: 45),
        ),
        isTrue,
      );

      final state = await repo.loadShooting();
      expect(state.stillAnswered, isTrue);
      expect(state.baselines['external_primary']!.generation, 45);
    });

    test('mark answered only for the same session', () async {
      final session = await turnOn();
      final since = session.since!;

      // Another session (a minute earlier): nothing is written.
      expect(await repo.markStillAnswered(since.subtract(_minute)), isFalse);
      expect((await repo.loadShooting()).stillAnswered, isFalse);

      // The session: answered, and nothing else changes.
      expect(await repo.markStillAnswered(since), isTrue);
      final state = await repo.loadShooting();
      expect(state.stillAnswered, isTrue);
      expect(state.since, since);
      expect(state.baselines, session.baselines);
      expect(state.on, isTrue);

      // Already answered: nothing to write.
      expect(await repo.markStillAnswered(since), isFalse);
    });

    test('mark answered does nothing while off', () async {
      expect(await repo.markStillAnswered(_t0), isFalse);
      expect(await _raw('shootingMode'), isNull);
    });

    test('off forgets the answer; the next session asks again', () async {
      final session = await turnOn();
      await repo.markStillAnswered(session.since!);
      await repo.turnShootingOff();
      clock.advance(_minute);

      expect((await turnOn()).stillAnswered, isFalse);
    });

    test('a session with microseconds matches its milliseconds', () async {
      // A real clock keeps microseconds; the phone's copy keeps `sinceMs`.
      clock = FixedClock(_t0.add(const Duration(microseconds: 456)));
      repo = PhoneStateRepository(db, clock);
      final session = await turnOn();
      final fromPhone = DateTime.fromMillisecondsSinceEpoch(
        session.since!.millisecondsSinceEpoch,
        isUtc: true,
      );

      expect(session.isSession(fromPhone), isTrue);
      expect(session.isSession(fromPhone.add(_minute)), isFalse);
      expect(ShootingState.off.isSession(fromPhone), isFalse);
      expect(await repo.markStillAnswered(fromPhone), isTrue);
      expect(await repo.endSession(fromPhone), isTrue);
      expect(await repo.loadShooting(), ShootingState.off);
    });

    test('end session turns off only the same session', () async {
      final session = await turnOn();
      final since = session.since!;

      expect(await repo.endSession(since.add(_minute)), isFalse);
      expect((await repo.loadShooting()).on, isTrue);

      expect(await repo.endSession(since), isTrue);
      expect(await repo.loadShooting(), ShootingState.off);
      expect(await _raw('shootingMode'), isNull);

      // Already off.
      expect(await repo.endSession(since), isFalse);
    });

    test('the answer is logged without a time', () async {
      final records = _record();
      final session = await turnOn();
      await repo.markStillAnswered(session.since!);
      await repo.endSession(session.since!);

      final lines = records.map((r) => r.message).join('\n');
      expect(lines, contains('answered'));
      expect(lines, isNot(contains('2026')));
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
