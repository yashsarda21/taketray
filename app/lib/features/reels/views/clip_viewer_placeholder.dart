import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// A stand-in for the clip viewer, so that a tile on a reel's page has
/// somewhere to go (D-87). Task 10 builds the viewer and replaces this.
class ClipViewerPlaceholder extends StatelessWidget {
  const new({required this.reelId, required this.clipId, super.key});

  final int reelId;
  final int clipId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: TtAppBar(title: AppLocalizations.of(context).navReels));
}
