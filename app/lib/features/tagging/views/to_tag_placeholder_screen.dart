import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Placeholder screen of the tab: its large app bar, until its feature lands.
class ToTagPlaceholderScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TtAppBar(
        large: true,
        title: AppLocalizations.of(context).navToTag,
      ),
    );
  }
}
