import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/menu_panel.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The open menu as `TtMenuButton` shows it, drawn directly: an open
/// `MenuAnchor`'s overlay cannot be painted by the CI (blocked-text)
/// variant. The panel sits on the shadow-casting surface `MenuAnchor` gives
/// it, at the top right of a 360 dp screen (`.menu { right: 8px }`).
class _OpenMenu extends StatelessWidget {
  const new(this.items);

  final List<TtMenuItem<String>> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
    child: Align(
      alignment: Alignment.topRight,
      child: Material(
        type: MaterialType.transparency,
        elevation: TtMetrics.menuElevation,
        shadowColor: context.scheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtMetrics.menuRadius),
        ),
        child: TtMenuPanel<String>(items: items, onSelected: (_) {}),
      ),
    ),
  );
}

void main() {
  ttGoldenTest(
    'Menu',
    fileName: 'menu',
    scenarios: [
      const TtScenario(
        'open, 3 items, one destructive',
        _OpenMenu([
          TtMenuItem('edit', 'Reel details', icon: Symbols.edit_rounded),
          TtMenuItem('select', 'Select clips', icon: Symbols.checklist_rounded),
          TtMenuItem(
            'delete',
            'Delete reel',
            icon: Symbols.delete_rounded,
            destructive: true,
          ),
        ]),
      ),
      const TtScenario(
        'long labels',
        _OpenMenu([
          TtMenuItem(
            'move',
            'Move to a reel with a much longer name',
            icon: Symbols.drive_file_move_rounded,
          ),
          TtMenuItem(
            'remove',
            'Remove from Autumn recipes and every other reel',
            icon: Symbols.playlist_remove_rounded,
            destructive: true,
          ),
        ]),
      ),
    ],
  );
}
