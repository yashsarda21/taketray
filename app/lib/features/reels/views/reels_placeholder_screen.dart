import 'package:flutter/material.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Reels tab until the reel list lands (Phase 4): its large app bar and
/// the Shooting mode section (the access banner and the Shooting mode card,
/// D-76).
class ReelsPlaceholderScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TtAppBar(
        large: true,
        title: AppLocalizations.of(context).navReels,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ShootingModeSection(),
            // Room to scroll clear of the floating nav pill.
            SizedBox(height: TtNavPill.reservedHeight(context)),
          ],
        ),
      ),
    );
  }
}
