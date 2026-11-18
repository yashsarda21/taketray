import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The About group: the promise that videos never leave the phone, and the
/// app's version ("Version 1.0.0"; "Version" alone while the version is not
/// known, or when it could not be read). A read that failed is tried again
/// when the app comes back to the screen (`resumed`), once per return, so
/// one failure does not hide the version until the app restarts.
class AboutGroup extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AboutGroup> createState() => _AboutGroupState();
}

class _AboutGroupState extends ConsumerState<AboutGroup> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resumed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _resumed() {
    if (ref.read(appInfoProvider).hasError) ref.invalidate(appInfoProvider);
  }

  @override
  Widget build(BuildContext context) {
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
