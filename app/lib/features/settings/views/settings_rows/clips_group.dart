import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/editors/view_models/copies_storage_controller.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The names of the watched [folders] as one line: each folder's last path
/// segment, joined with ", " ("Camera, WhatsApp Video"); a folder that is the
/// storage root is "Main folder"; no folder is "None".
String watchedFoldersText(AppLocalizations l10n, List<String> folders) {
  if (folders.isEmpty) return l10n.settingsWatchedNone;
  return [for (final path in folders) _folderName(l10n, path)].join(', ');
}

String _folderName(AppLocalizations l10n, String path) {
  final segments = [
    for (final s in path.split('/'))
      if (s.isNotEmpty) s,
  ];
  return segments.isEmpty ? l10n.addFoldersMainFolder : segments.last;
}

/// The Clips group: "Watched folders" (the folder names, opens
/// `Routes.watchedFolders`) and "Storage used by VN copies" (opens
/// `Routes.copiesStorage`, D-130): "{size} in {n} reels" or "None" under it,
/// and nothing until the first read.
class ClipsGroup extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ClipsGroup> createState() => _ClipsGroupState();
}

class _ClipsGroupState extends ConsumerState<ClipsGroup> {
  /// Opens the watched folders screen once however fast the taps.
  final OpenOnce _folders = OpenOnce();

  /// Opens the VN copies screen once however fast the taps.
  final OpenOnce _copies = OpenOnce();

  @override
  void dispose() {
    _folders.dispose();
    _copies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider).value;
    final copies = ref.watch(copiesSummaryProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtGroupLabel(l10n.settingsGroupClips),
        TtGroupedRows(
          children: [
            TtListRow(
              leading: const TtRowIcon(
                icon: Symbols.folder_open_rounded,
                boxed: false,
              ),
              title: l10n.settingsWatchedTitle,
              subtitle: settings == null
                  ? null
                  : watchedFoldersText(l10n, settings.watchedFolders),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => _folders.open(
                () => context.push<void>(Routes.watchedFolders),
              ),
            ),
            TtListRow(
              leading: const TtRowIcon(
                icon: Symbols.sd_storage_rounded,
                boxed: false,
              ),
              title: l10n.settingsCopiesTitle,
              subtitle: copies == null
                  ? null
                  : copies.reels == 0
                  ? l10n.settingsCopiesNone
                  : l10n.settingsCopiesSummary(
                      byteSizeText(l10n, copies.bytes),
                      copies.reels,
                    ),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () =>
                  _copies.open(() => context.push<void>(Routes.copiesStorage)),
            ),
          ],
        ),
      ],
    );
  }
}
