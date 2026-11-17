import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';

/// A [SettingsController] that starts at [initial] (null: the first read
/// never answers), records its calls in [calls] as `setEvening(false)`,
/// `setEveningMinutes(425)` and so on, and applies each one to the state, as
/// the real one does once the database has answered. [show] pushes settings
/// as if they had changed elsewhere.
class FakeSettings extends SettingsController {
  FakeSettings(this.initial);

  final AppSettings? initial;
  final List<String> calls = [];

  AppSettings _now = const AppSettings();

  @override
  Stream<AppSettings> build() {
    final first = initial;
    if (first == null) return const Stream<AppSettings>.empty();
    _now = first;
    return Stream.value(first);
  }

  /// Shows [settings].
  void show(AppSettings settings) {
    _now = settings;
    state = AsyncData(settings);
  }

  void _apply(String call, AppSettings next) {
    calls.add(call);
    show(next);
  }

  @override
  Future<void> setEvening(bool enabled) async => _apply(
    'setEvening($enabled)',
    _now.copyWith(eveningReminderEnabled: enabled),
  );

  @override
  Future<void> setEveningMinutes(int minutes) async => _apply(
    'setEveningMinutes($minutes)',
    _now.copyWith(eveningReminderMinutes: minutes),
  );

  @override
  Future<void> setStillReminder(bool enabled) async => _apply(
    'setStillReminder($enabled)',
    _now.copyWith(stillReminderEnabled: enabled),
  );

  @override
  Future<void> setCopiesReminder(bool enabled) async => _apply(
    'setCopiesReminder($enabled)',
    _now.copyWith(copiesReminderEnabled: enabled),
  );
}
