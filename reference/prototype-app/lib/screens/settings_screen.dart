import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';
import '../widgets/tt.dart';

/// Settings (first pass): the review controls for this build, brand colour and theme.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = context.cs;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                20,
                Space.gutter,
                4,
              ),
              child: Text('Settings', style: pageTitle(context)),
            ),
          ),
          const GroupLabel('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Symbols.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Symbols.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Symbols.dark_mode_rounded),
                ),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          const GroupLabel('About'),
          GroupedRows(
            children: [
              ListTile(
                leading: Icon(
                  Symbols.shield_rounded,
                  color: cs.onSurfaceVariant,
                ),
                title: const Text('Your videos never leave your phone'),
                subtitle: const Text('No account, no cloud, no ads.'),
              ),
              ListTile(
                leading: Icon(Symbols.info_rounded, color: cs.onSurfaceVariant),
                title: const Text('TakeTray'),
                subtitle: const Text('Preview build with sample clips'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
