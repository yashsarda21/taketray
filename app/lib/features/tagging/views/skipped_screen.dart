import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Skipped screen's place in the To tag tab (`Routes.skipped`, D-98): an
/// app bar "Skipped" with **Back**, and no list yet. **Skipped ({n})** on To
/// tag opens it already; the clips, Restore and the selection are Task 9.
class SkippedScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: TtAppBar(
        title: l10n.skippedTitle,
        leading: TtIconButton(
          icon: Symbols.arrow_back_rounded,
          semanticLabel: l10n.navBack,
          style: TtIconButtonStyle.circle,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.toTag),
        ),
      ),
      body: const SizedBox.expand(),
    );
  }
}
