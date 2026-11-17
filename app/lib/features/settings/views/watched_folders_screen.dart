import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Watched folders screen (`Routes.watchedFolders`, from the Watched
/// folders row in Settings; `screens.js`: `routes.watched`).
///
/// A stand-in: only its app bar with **Back**. Phase 10B's Task 6 builds the
/// folder list.
class WatchedFoldersScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TtAppBar(
            title: l10n.settingsWatchedTitle,
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
