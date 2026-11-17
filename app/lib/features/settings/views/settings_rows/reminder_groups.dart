import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/features/settings/views/settings_rows/switch_row.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Names the step only, never a value (D-10).
final Logger _log = Logger('settingsScreen');

/// Runs [change] on the settings controller. A failed save is logged by type
/// and changes nothing on screen: the switches follow the saved settings.
void _save(
  WidgetRef ref,
  String what,
  Future<void> Function(SettingsController) change,
) => unawaited(
  guarded(
    _log,
    what,
    () => change(ref.read(settingsControllerProvider.notifier)),
  ),
);

/// The Shooting mode group: "Remind me to turn it off" with its switch
/// (`AppSettings.stillReminderEnabled`, D-145).
class ShootingReminderGroup extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtGroupLabel(l10n.settingsGroupShooting),
        TtGroupedRows(
          children: [
            SettingsSwitchRow(
              icon: Symbols.timer_rounded,
              title: l10n.settingsStillTitle,
              subtitle: l10n.settingsStillSubtitle,
              value: settings?.stillReminderEnabled ?? true,
              semanticLabel: l10n.settingsStillSemantics,
              onChanged: settings == null
                  ? null
                  : (on) => _save(
                      ref,
                      'Saving the still-shooting reminder',
                      (c) => c.setStillReminder(on),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The Reminders group: the evening reminder with its switch, the reminder
/// time (only while the evening reminder is on; it opens the time picker)
/// and the VN copies reminder with its switch.
///
/// The times follow the phone's 12 or 24-hour setting. While the settings
/// are not known the rows show the defaults and the switches cannot be used.
class RemindersGroup extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RemindersGroup> createState() => _RemindersGroupState();
}

class _RemindersGroupState extends ConsumerState<RemindersGroup> {
  /// Opens the time picker once however fast the taps.
  final OpenOnce _picker = OpenOnce();

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  /// Asks for a time, starting at [minutes], and saves the one picked.
  void _pickTime(int minutes) {
    _picker.openSlow((pushing) async {
      final picked = showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      );
      pushing();
      final time = await picked;
      if (time == null || !mounted) return;
      _save(
        ref,
        'Saving the reminder time',
        (c) => c.setEveningMinutes(time.hour * 60 + time.minute),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider).value;
    final current = settings ?? const AppSettings();
    final timeText = _timeText(context, current.eveningReminderMinutes);
    final enabled = settings != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtGroupLabel(l10n.settingsGroupReminders),
        TtGroupedRows(
          children: [
            SettingsSwitchRow(
              icon: Symbols.bedtime_rounded,
              title: l10n.settingsEveningTitle,
              subtitle: l10n.settingsEveningSubtitle(timeText),
              value: current.eveningReminderEnabled,
              semanticLabel: l10n.settingsEveningSemantics,
              onChanged: enabled
                  ? (on) => _save(
                      ref,
                      'Saving the evening reminder',
                      (c) => c.setEvening(on),
                    )
                  : null,
            ),
            if (current.eveningReminderEnabled)
              TtListRow(
                leading: const TtRowIcon(
                  icon: Symbols.schedule_rounded,
                  boxed: false,
                ),
                title: l10n.settingsReminderTimeTitle,
                subtitle: timeText,
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: enabled
                    ? () => _pickTime(current.eveningReminderMinutes)
                    : null,
              ),
            SettingsSwitchRow(
              icon: Symbols.folder_copy_rounded,
              title: l10n.settingsCopiesReminderTitle,
              subtitle: l10n.settingsCopiesReminderSubtitle,
              value: current.copiesReminderEnabled,
              semanticLabel: l10n.settingsCopiesReminderSemantics,
              onChanged: enabled
                  ? (on) => _save(
                      ref,
                      'Saving the copies reminder',
                      (c) => c.setCopiesReminder(on),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  /// [minutes] after midnight as the phone shows a time of day.
  String _timeText(BuildContext context, int minutes) => timeOfDayText(
    DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
    locale: Localizations.localeOf(context).toString(),
    use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
