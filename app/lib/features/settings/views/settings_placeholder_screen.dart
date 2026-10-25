import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

class SettingsPlaceholderScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context).navSettings));
  }
}
