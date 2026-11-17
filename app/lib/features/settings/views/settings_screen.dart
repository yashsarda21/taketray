import 'package:flutter/material.dart';
import 'package:taketray/features/settings/views/settings_rows/about_group.dart';
import 'package:taketray/features/settings/views/settings_rows/clips_group.dart';
import 'package:taketray/features/settings/views/settings_rows/data_group.dart';
import 'package:taketray/features/settings/views/settings_rows/help_group.dart';
import 'package:taketray/features/settings/views/settings_rows/permissions_group.dart';
import 'package:taketray/features/settings/views/settings_rows/reminder_groups.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Settings, the third tab (`screens.js`: `routes.settings`; Phase 10B,
/// D-148). Seven groups, in the prototype's order, each in
/// `settings_rows/`:
///
/// - **Shooting mode:** "Remind me to turn it off" (switch);
/// - **Reminders:** "Evening reminder" (switch), "Reminder time" (only while
///   the evening reminder is on; a time picker), "VN copies reminder"
///   (switch);
/// - **Clips:** "Watched folders" (`Routes.watchedFolders`) and "Storage used
///   by VN copies" (`Routes.copiesStorage`);
/// - **Help:** "Notifications not arriving?" (`Routes.notificationsHelp`) and
///   "Send error log";
/// - **Your data:** "Export and import" (`Routes.backup`);
/// - **Permissions:** "Video access" and "Notifications", each with its
///   Allow button;
/// - **About:** the privacy line and the app version.
///
/// The switches save at once (`SettingsController`) and follow the saved
/// settings. Times follow the phone's 12 or 24-hour setting.
///
/// The rows are in a plain scroll view, not a lazy list: there are a dozen of
/// them, and every one is built, so a screen reader and the tests see them
/// all.
class SettingsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: TtAppBar(large: true, title: l10n.navSettings),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: TtNavPill.reservedHeight(context)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShootingReminderGroup(),
            RemindersGroup(),
            ClipsGroup(),
            HelpGroup(),
            DataGroup(),
            PermissionsGroup(),
            AboutGroup(),
          ],
        ),
      ),
    );
  }
}
