import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';

/// A [SettingsRepository] on a real in-memory database that records every
/// settings value an `update` is about to save (and every `save`), and can
/// make the next saves fail. The controller saves through `update` (D-149,
/// ruling R3), so a failed save is an `update` whose change throws: nothing
/// is written.
class _SpyRepo implements SettingsRepository {
  _SpyRepo(this.inner);

  final SettingsRepository inner;

  /// What every `save` was called with, in order, failed ones too.
  final List<AppSettings> saves = [];

  /// How many of the next saves fail.
  int failSaves = 0;

  @override
  Future<AppSettings> load() => inner.load();

  @override
  Stream<AppSettings> watch() => inner.watch();

  @override
  Future<void> save(AppSettings settings) async {
    saves.add(settings);
    if (failSaves > 0) {
      failSaves--;
      throw StateError('the database said no');
    }
    await inner.save(settings);
  }

  @override
  Future<AppSettings> update(
    AppSettings Function(AppSettings current) change,
  ) => inner.update((current) {
    final next = change(current);
    saves.add(next);
    if (failSaves > 0) {
      failSaves--;
      throw StateError('the database said no');
    }
    return next;
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late _SpyRepo repo;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    repo = _SpyRepo(SettingsRepository(db, FixedClock(DateTime.utc(2026, 11))));
    // The screen listens while it is open; without a listener the provider
    // would be disposed between two calls.
    container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    )..listen(settingsControllerProvider, (_, _) {});
  });

  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);

  Future<AppSettings> stored() => repo.inner.load();

  group('the state', () {
    test('is the settings now, and follows a change made elsewhere', () async {
      expect(
        await container.read(settingsControllerProvider.future),
        const AppSettings(),
      );

      const changed = AppSettings(
        watchedFolders: ['Movies/Drone'],
        eveningReminderEnabled: false,
        eveningReminderMinutes: 75,
        stillReminderEnabled: false,
        copiesReminderEnabled: false,
      );
      final next = Completer<AppSettings>();
      container.listen(settingsControllerProvider, (_, now) {
        if (now.value == changed && !next.isCompleted) {
          next.complete(now.requireValue);
        }
      });
      await repo.inner.save(changed);

      expect(await next.future, changed);
    });
  });

  group('each setter changes its own setting and keeps the rest', () {
    const base = AppSettings(
      watchedFolders: ['DCIM/Camera', 'Movies/Drone'],
      eveningReminderMinutes: 600,
    );

    setUp(() async {
      await repo.inner.save(base);
      await container.read(settingsControllerProvider.future);
    });

    test('setEvening', () async {
      await controller().setEvening(false);

      expect(await stored(), base.copyWith(eveningReminderEnabled: false));
      await controller().setEvening(true);
      expect(await stored(), base);
    });

    test('setEveningMinutes', () async {
      await controller().setEveningMinutes(1321);

      expect(await stored(), base.copyWith(eveningReminderMinutes: 1321));
    });

    test('setStillReminder', () async {
      await controller().setStillReminder(false);

      expect(await stored(), base.copyWith(stillReminderEnabled: false));
      await controller().setStillReminder(true);
      expect(await stored(), base);
    });

    test('setCopiesReminder', () async {
      await controller().setCopiesReminder(false);

      expect(await stored(), base.copyWith(copiesReminderEnabled: false));
      await controller().setCopiesReminder(true);
      expect(await stored(), base);
    });
  });

  group('two quick changes never lose one', () {
    test('two switches in the same frame both persist', () async {
      await container.read(settingsControllerProvider.future);

      final first = controller().setEvening(false);
      final second = controller().setCopiesReminder(false);
      await Future.wait([first, second]);

      expect(
        await stored(),
        const AppSettings(
          eveningReminderEnabled: false,
          copiesReminderEnabled: false,
        ),
      );
    });

    test('all four settings, changed in one frame, all persist', () async {
      await container.read(settingsControllerProvider.future);

      await Future.wait([
        controller().setEvening(false),
        controller().setEveningMinutes(5),
        controller().setStillReminder(false),
        controller().setCopiesReminder(false),
      ]);

      expect(
        await stored(),
        const AppSettings(
          eveningReminderEnabled: false,
          eveningReminderMinutes: 5,
          stillReminderEnabled: false,
          copiesReminderEnabled: false,
        ),
      );
    });

    test('changes to the same setting end on the last one asked for', () async {
      await container.read(settingsControllerProvider.future);

      await Future.wait([
        controller().setEveningMinutes(100),
        controller().setEveningMinutes(200),
        controller().setEveningMinutes(300),
      ]);

      expect((await stored()).eveningReminderMinutes, 300);
      expect(
        [for (final s in repo.saves) s.eveningReminderMinutes],
        [100, 200, 300],
      );
    });

    test('a change reads the settings from the database, not the state '
        'that has not caught up yet', () async {
      await container.read(settingsControllerProvider.future);

      // The folders are saved elsewhere and the state has not heard yet.
      await repo.inner.save(
        const AppSettings(watchedFolders: ['Movies/Drone']),
      );
      await controller().setEvening(false);

      expect(
        await stored(),
        const AppSettings(
          watchedFolders: ['Movies/Drone'],
          eveningReminderEnabled: false,
        ),
      );
    });

    test('a switch here and a save made through another repository, in '
        'the same frame, both persist (R3)', () async {
      await container.read(settingsControllerProvider.future);
      // The Watched folders screen saves through its own repository.
      final other = SettingsRepository(db, FixedClock(DateTime.utc(2026, 11)));

      await Future.wait([
        controller().setEvening(false),
        other.update((s) => s.copyWith(watchedFolders: ['Movies/Drone'])),
        controller().setStillReminder(false),
      ]);

      expect(
        await stored(),
        const AppSettings(
          watchedFolders: ['Movies/Drone'],
          eveningReminderEnabled: false,
          stillReminderEnabled: false,
        ),
      );
    });

    test('a change made before the state was ever read still works', () async {
      await controller().setStillReminder(false);

      expect(await stored(), const AppSettings(stillReminderEnabled: false));
    });
  });

  group('the evening time', () {
    for (final minutes in [0, 1, 719, 1260, 1438, 1439]) {
      test('$minutes is kept exactly', () async {
        await container.read(settingsControllerProvider.future);

        await controller().setEveningMinutes(minutes);

        expect((await stored()).eveningReminderMinutes, minutes);
        expect(repo.saves.single.eveningReminderMinutes, minutes);
      });
    }

    for (final minutes in [-1, 1440, 1441, 2000, -1440, 100000]) {
      test('$minutes throws ArgumentError and saves nothing', () async {
        await container.read(settingsControllerProvider.future);
        await controller().setEveningMinutes(600);
        repo.saves.clear();

        await expectLater(
          controller().setEveningMinutes(minutes),
          throwsArgumentError,
        );

        // Not even tried: the guard is the controller's own.
        expect(repo.saves, isEmpty);
        expect((await stored()).eveningReminderMinutes, 600);
      });
    }

    test('a refused time between two good changes disturbs neither', () async {
      await container.read(settingsControllerProvider.future);

      final first = controller().setEveningMinutes(100);
      final refused = controller().setEveningMinutes(1440);
      final last = controller().setEvening(false);

      await expectLater(refused, throwsArgumentError);
      await Future.wait([first, last]);
      expect(
        await stored(),
        const AppSettings(
          eveningReminderMinutes: 100,
          eveningReminderEnabled: false,
        ),
      );
    });
  });

  group('a save that fails', () {
    test('reaches the caller, saves nothing, and does not block the next '
        'change', () async {
      await container.read(settingsControllerProvider.future);
      repo.failSaves = 1;

      final failed = controller().setEvening(false);
      final next = controller().setCopiesReminder(false);

      await expectLater(failed, throwsStateError);
      await next;
      // The failed change is not half-applied into the next one.
      expect(await stored(), const AppSettings(copiesReminderEnabled: false));
    });
  });
}
