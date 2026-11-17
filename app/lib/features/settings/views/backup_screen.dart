import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Export and import screen (`Routes.backup`, from the Export and import
/// row in Settings; `screens.js`: `routes.backup`).
///
/// A stand-in: only its app bar with **Back**. Phase 10B's Task 7 builds the
/// export and import.
class BackupScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TtAppBar(
            title: l10n.settingsBackupTitle,
            leading: TtIconButton(
              icon: Symbols.arrow_back_rounded,
              semanticLabel: l10n.navBack,
              style: TtIconButtonStyle.circle,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(Routes.settings),
            ),
          ),
        ],
      ),
    );
  }
}
