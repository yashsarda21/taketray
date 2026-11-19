import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Your data group: "Export and import", with "Last backup: {date}" or
/// "No backup yet" under it (nothing until the date is read), which opens
/// `Routes.backup`. The date is read again when the backup screen is left, so
/// a backup made there shows at once.
class DataGroup extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DataGroup> createState() => _DataGroupState();
}

class _DataGroupState extends ConsumerState<DataGroup> {
  /// Opens the backup screen once however fast the taps.
  final OpenOnce _backup = OpenOnce();

  @override
  void dispose() {
    _backup.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await context.push<void>(Routes.backup);
    if (mounted) ref.invalidate(lastExportProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final export = ref.watch(lastExportProvider);
    // Rebuilt at each local midnight, so a date gains its year when the year
    // turns.
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final last = export.value;
    final subtitle = last != null
        ? l10n.settingsBackupLast(
            ttDayText(context, last.toLocal(), today: today),
          )
        : export.isLoading && !export.hasError
        ? null
        : l10n.settingsBackupNone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtGroupLabel(l10n.settingsGroupYourData),
        TtGroupedRows(
          children: [
            TtListRow(
              leading: const TtRowIcon(
                icon: Symbols.settings_backup_restore_rounded,
                boxed: false,
              ),
              title: l10n.settingsBackupTitle,
              subtitle: subtitle,
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => _backup.open(_open),
            ),
          ],
        ),
      ],
    );
  }
}
