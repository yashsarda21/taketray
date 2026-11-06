import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/background/debug_evening.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

// The debug build's way to set the evening reminder "to the next minutes" for
// the owner's hand check (Phase 6, Task 9): there is no Settings row for the
// time until Phase 10.

late AppDatabase db;
late SettingsRepository settings;

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    settings = SettingsRepository(db, FixedClock(DateTime.utc(2026, 11, 6)));
  });

  group('eveningMinutesIn', () {
    test('adds the minutes to the phone clock, seconds ignored', () {
      expect(eveningMinutesIn(DateTime(2026, 11, 6, 21, 0, 59), 2), 1262);
      expect(eveningMinutesIn(DateTime(2026, 11, 6, 9, 5), 3), 9 * 60 + 8);
    });

    test('wraps after midnight to the early minutes of the day', () {
      expect(eveningMinutesIn(DateTime(2026, 11, 6, 23, 59), 2), 1);
      expect(eveningMinutesIn(DateTime(2026, 11, 6, 23, 58), 2), 0);
    });

    test('a very large number still gives a minute of the day', () {
      final minutes = eveningMinutesIn(DateTime(2026, 11, 6, 12), 100000);
      expect(minutes, inInclusiveRange(0, 1439));
      expect(minutes, (12 * 60 + 100000) % 1440);
    });
  });

  group('applyDebugEvening', () {
    test('sets the minutes and switches the reminder on', () async {
      await settings.save(
        const AppSettings(
          watchedFolders: ['Movies/TakeTray Test'],
          eveningReminderEnabled: false,
        ),
      );

      final set = await applyDebugEvening(
        settings,
        inMinutes: 2,
        now: DateTime(2026, 11, 6, 20, 30),
      );

      expect(set, isTrue);
      final saved = await settings.load();
      expect(saved.eveningReminderMinutes, 20 * 60 + 32);
      expect(saved.eveningReminderEnabled, isTrue);
    });

    test('keeps the watched folders', () async {
      await settings.save(const AppSettings(watchedFolders: ['A', 'B/C']));

      await applyDebugEvening(
        settings,
        inMinutes: 1,
        now: DateTime(2026, 11, 6, 8),
      );

      expect((await settings.load()).watchedFolders, ['A', 'B/C']);
    });

    test('0 and negative numbers change nothing', () async {
      for (final minutes in [0, -1, -1440]) {
        final set = await applyDebugEvening(
          settings,
          inMinutes: minutes,
          now: DateTime(2026, 11, 6, 8),
        );
        expect(set, isFalse, reason: '$minutes');
      }
      expect(await settings.load(), const AppSettings());
      expect(
        await db.select(db.settings).get(),
        isEmpty,
        reason: 'not even a default is written',
      );
    });

    test('a failing save is thrown, not hidden', () async {
      await expectLater(
        applyDebugEvening(
          _FailingSave(),
          inMinutes: 2,
          now: DateTime(2026, 11, 6, 8),
        ),
        throwsA(anything),
      );
    });
  });
}

/// Settings whose save fails (a database error).
class _FailingSave implements SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) =>
      Future<void>.error(StateError('x'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
