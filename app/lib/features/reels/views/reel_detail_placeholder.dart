import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// A stand-in for the reel page, so that a card on Home has somewhere to go
/// (D-86). Task 8 builds the real page and replaces this.
class ReelDetailPlaceholder extends StatelessWidget {
  const new({required this.reelId, super.key});

  final int reelId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: TtAppBar(title: AppLocalizations.of(context).navReels));
}
