import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

late AppDatabase db;
late SettingsRepository repo;

Future<void> _put(String key, String value) => db
    .into(db.settings)
    .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    repo = SettingsRepository(db, FixedClock(DateTime.utc(2026, 10, 26)));
  });

  test('an empty database loads the defaults', () async {
    final settings = await repo.load();

    expect(settings, const AppSettings());
    expect(settings.watchedFolders, ['DCIM/Camera']);
    expect(settings.eveningReminderEnabled, isTrue);
    expect(settings.eveningReminderMinutes, 1260);
    expect(settings.stillReminderEnabled, isTrue);
    expect(settings.copiesReminderEnabled, isTrue);
  });

  test('save then load round-trips', () async {
    const saved = AppSettings(
      watchedFolders: ['DCIM/Camera', 'Movies/Drone'],
      eveningReminderEnabled: false,
      eveningReminderMinutes: 75,
      stillReminderEnabled: false,
      copiesReminderEnabled: false,
    );

    await repo.save(saved);

    expect(await repo.load(), saved);
  });

  test('the two new switches are stored and read independently', () async {
    // Swapped keys, or one switch written under both names, would pass a test
    // that sets them together.
    await repo.save(const AppSettings(stillReminderEnabled: false));
    expect(await repo.load(), const AppSettings(stillReminderEnabled: false));

    await repo.save(const AppSettings(copiesReminderEnabled: false));
    expect(await repo.load(), const AppSettings(copiesReminderEnabled: false));
  });

  test('the keys are the documented names', () {
    expect(SettingsRepository.stillReminderEnabledKey, 'stillReminderEnabled');
    expect(
      SettingsRepository.copiesReminderEnabledKey,
      'copiesReminderEnabled',
    );
  });

  test('save stores one JSON row per key and updates them in place', () async {
    await repo.save(const AppSettings(watchedFolders: ['A']));
    await repo.save(const AppSettings(watchedFolders: ['B', 'C']));

    final rows = {
      for (final r in await db.select(db.settings).get()) r.key: r.value,
    };
    expect(rows, {
      'watchedFolders': '["B","C"]',
      'eveningReminderEnabled': 'true',
      'eveningReminderMinutes': '1260',
      'stillReminderEnabled': 'true',
      'copiesReminderEnabled': 'true',
    });
  });

  test('an empty folder list is a valid setting', () async {
    await repo.save(const AppSettings(watchedFolders: []));
    expect((await repo.load()).watchedFolders, isEmpty);
  });

  test('a missing key falls back to its default, others are kept', () async {
    await _put('eveningReminderMinutes', '30');

    final settings = await repo.load();

    expect(settings.eveningReminderMinutes, 30);
    expect(settings.eveningReminderEnabled, isTrue);
    expect(settings.watchedFolders, ['DCIM/Camera']);
    expect(settings.stillReminderEnabled, isTrue);
    expect(settings.copiesReminderEnabled, isTrue);
  });

  test('a corrupt switch is on, and its key name is logged', () async {
    await _put('stillReminderEnabled', '"no"');
    await _put('copiesReminderEnabled', '{not json');
    final records = <LogRecord>[];
    final sub = Logger('settings').onRecord.listen(records.add);
    addTearDown(sub.cancel);

    final settings = await repo.load();

    expect(settings.stillReminderEnabled, isTrue);
    expect(settings.copiesReminderEnabled, isTrue);
    final lines = records.map((r) => r.message).join('\n');
    expect(lines, contains('stillReminderEnabled'));
    expect(lines, contains('copiesReminderEnabled'));
    expect(lines, isNot(contains('"no"')));
  });

  test('a stored false for a new switch is read as off', () async {
    await _put('stillReminderEnabled', 'false');
    await _put('copiesReminderEnabled', 'false');

    final settings = await repo.load();

    expect(settings.stillReminderEnabled, isFalse);
    expect(settings.copiesReminderEnabled, isFalse);
  });

  test(
    'a corrupt value falls back to its default and logs only the key name',
    () async {
      await _put('watchedFolders', '{not json');
      await _put('eveningReminderEnabled', '"yes"');
      await _put('eveningReminderMinutes', '99999');
      final records = <LogRecord>[];
      final sub = Logger('settings').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      final settings = await repo.load();

      expect(settings, const AppSettings());
      final lines = records.map((r) => r.message).join('\n');
      expect(lines, contains('watchedFolders'));
      expect(lines, contains('eveningReminderEnabled'));
      expect(lines, contains('eveningReminderMinutes'));
      expect(lines, isNot(contains('not json')));
      expect(lines, isNot(contains('99999')));
    },
  );

  test('a list with a non-string entry is corrupt', () async {
    // A lenient reader that kept the strings would give ['Movies/Drone'].
    await _put('watchedFolders', '["Movies/Drone", 3]');
    expect((await repo.load()).watchedFolders, ['DCIM/Camera']);
  });

  test('a value of the wrong type is corrupt', () async {
    // A lenient reader would turn these into false and 30; the defaults are
    // true and 1260.
    await _put('eveningReminderEnabled', '0');
    await _put('eveningReminderMinutes', '"30"');

    expect(await repo.load(), const AppSettings());
  });

  test('save repairs corrupt rows', () async {
    await _put('watchedFolders', '{not json');
    await _put('eveningReminderEnabled', '0');
    await _put('eveningReminderMinutes', '"30"');
    await _put('stillReminderEnabled', '1');
    await _put('copiesReminderEnabled', 'null');
    const saved = AppSettings(
      watchedFolders: ['Movies/Drone'],
      eveningReminderEnabled: false,
      eveningReminderMinutes: 30,
      stillReminderEnabled: false,
      copiesReminderEnabled: false,
    );

    await repo.save(saved);

    expect(await repo.load(), saved);
    final rows = {
      for (final r in await db.select(db.settings).get()) r.key: r.value,
    };
    expect(rows, {
      'watchedFolders': '["Movies/Drone"]',
      'eveningReminderEnabled': 'false',
      'eveningReminderMinutes': '30',
      'stillReminderEnabled': 'false',
      'copiesReminderEnabled': 'false',
    });
  });

  test('save refuses reminder minutes outside a day', () async {
    for (final bad in [-1, 1440]) {
      expect(
        () => repo.save(AppSettings(eveningReminderMinutes: bad)),
        throwsArgumentError,
      );
    }
    expect(await db.select(db.settings).get(), isEmpty);
    await repo.save(const AppSettings(eveningReminderMinutes: 0));
    await repo.save(const AppSettings(eveningReminderMinutes: 1439));
  });

  test('other keys are neither loaded nor touched by save', () async {
    await _put('shootingMode', 'true');

    await repo.save(const AppSettings(eveningReminderEnabled: false));

    final rows = {
      for (final r in await db.select(db.settings).get()) r.key: r.value,
    };
    expect(rows['shootingMode'], 'true');
    expect((await repo.load()).eveningReminderEnabled, isFalse);
  });

  test('exportedKeys is exactly the five user settings', () {
    expect(SettingsRepository.exportedKeys, {
      'watchedFolders',
      'eveningReminderEnabled',
      'eveningReminderMinutes',
      'stillReminderEnabled',
      'copiesReminderEnabled',
    });
  });

  group('a corrupt value is logged once per key per repository', () {
    List<String> warnings(List<LogRecord> records) => [
      for (final r in records)
        if (r.level == Level.WARNING) r.message,
    ];

    test('three emissions of watch log one warning', () async {
      await _put('eveningReminderMinutes', '99999');
      final records = <LogRecord>[];
      final sub = Logger('settings').onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final emitted = <AppSettings>[];
      final watching = repo.watch().listen(emitted.add);
      addTearDown(watching.cancel);
      await pumpEventQueue();

      // Each write of another key re-reads every row, the corrupt one too.
      await _put('watchedFolders', '["A"]');
      await pumpEventQueue();
      await _put('watchedFolders', '["B"]');
      await pumpEventQueue();

      expect(emitted, hasLength(3));
      final lines = warnings(records);
      expect(lines, hasLength(1));
      expect(lines.single, contains('eveningReminderMinutes'));
    });

    test('load after watch, and load again, do not log it again', () async {
      await _put('eveningReminderMinutes', '99999');
      final records = <LogRecord>[];
      final sub = Logger('settings').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await repo.load();
      await repo.load();
      await repo.watch().first;

      expect(warnings(records), hasLength(1));
    });

    test('each corrupt key is logged once, by its own name', () async {
      await _put('eveningReminderMinutes', '99999');
      await _put('stillReminderEnabled', '"no"');
      final records = <LogRecord>[];
      final sub = Logger('settings').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await repo.load();
      await repo.load();

      final lines = warnings(records);
      expect(lines, hasLength(2));
      expect(
        lines.where((l) => l.contains('eveningReminderMinutes')),
        hasLength(1),
      );
      expect(
        lines.where((l) => l.contains('stillReminderEnabled')),
        hasLength(1),
      );
    });

    test('another repository instance logs it again', () async {
      await _put('eveningReminderMinutes', '99999');
      final records = <LogRecord>[];
      final sub = Logger('settings').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await repo.load();
      await SettingsRepository(
        db,
        FixedClock(DateTime.utc(2026, 10, 26)),
      ).load();

      expect(warnings(records), hasLength(2));
    });

    test('a key that was never corrupt logs nothing', () async {
      await repo.save(const AppSettings());
      final records = <LogRecord>[];
      final sub = Logger('settings').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      await repo.load();

      expect(warnings(records), isEmpty);
    });
  });

  group('watch', () {
    test('emits the current settings, then each change, not repeats', () async {
      final emitted = <AppSettings>[];
      final sub = repo.watch().listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.save(const AppSettings(eveningReminderEnabled: false));
      await pumpEventQueue();
      await _put('shootingMode', 'false'); // not one of ours
      await pumpEventQueue();
      await repo.save(const AppSettings(eveningReminderEnabled: false));
      await pumpEventQueue();

      expect(emitted, [
        const AppSettings(),
        const AppSettings(eveningReminderEnabled: false),
      ]);
    });

    test('a change to either new switch emits', () async {
      final emitted = <AppSettings>[];
      final sub = repo.watch().listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.save(const AppSettings(stillReminderEnabled: false));
      await pumpEventQueue();
      await repo.save(const AppSettings(copiesReminderEnabled: false));
      await pumpEventQueue();

      expect(emitted, [
        const AppSettings(),
        const AppSettings(stillReminderEnabled: false),
        const AppSettings(copiesReminderEnabled: false),
      ]);
    });
  });
}
