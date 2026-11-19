import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// A Settings row with a switch at its end: an icon, a [title], a [subtitle]
/// and the switch. The row is plain (not a button): the switch is the one
/// control in it. A null [onChanged] disables the switch (the settings are
/// not known yet).
class SettingsSwitchRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  /// What a screen reader says for the switch.
  final String semanticLabel;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TtListRow(
      leading: TtRowIcon(icon: icon, boxed: false),
      title: title,
      subtitle: subtitle,
      trailing: TtSwitch(
        value: value,
        onChanged: onChanged,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
