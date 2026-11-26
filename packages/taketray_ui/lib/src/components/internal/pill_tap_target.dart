import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// Gives a pill-shaped button one semantics node and a 48 dp tall tap target
/// around the pill, which is shorter than that.
///
/// The target is as wide as the pill (at least 48 dp), so pills sit side by
/// side in a row. A tap in the margin above or below the pill counts. The
/// pill's own text is left out of the semantics: a screen reader says [label]
/// instead. With [toggled] the node is a toggle button (`aria-pressed`) that
/// is on or off; without it a plain button.
class TtPillTapTarget extends StatelessWidget {
  /// A target around [child] named [label] that calls [onPressed].
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
    this.toggled,
    super.key,
  });

  /// What a screen reader says.
  final String label;

  /// Called on a tap.
  final VoidCallback onPressed;

  /// The pill.
  final Widget child;

  /// Whether the button is on, or null for a button that is not a toggle.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final target = context.tt.sizes.touchTarget;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      toggled: toggled,
      label: label,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: target, minHeight: target),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}
