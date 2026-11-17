import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The About group: the promise that videos never leave the phone, and the
/// app's version ("Version 1.0.0"; "Version" alone while the version is not
/// known, or when it could not be read).
class AboutGroup extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final version = ref.watch(appInfoProvider).value?.versionName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtGroupLabel(l10n.settingsGroupAbout),
        TtGroupedRows(
          children: [
            TtListRow(
              leading: const TtRowIcon(
                icon: Symbols.shield_rounded,
                boxed: false,
              ),
              title: l10n.settingsPrivacyTitle,
              subtitle: l10n.settingsPrivacyBody,
            ),
            TtListRow(
              leading: const TtRowIcon(
                icon: Symbols.info_rounded,
                boxed: false,
              ),
              title: l10n.settingsAboutTitle,
              subtitle: version.isEmpty
                  ? l10n.settingsVersionUnknown
                  : l10n.settingsVersion(version),
            ),
          ],
        ),
      ],
    );
  }
}
