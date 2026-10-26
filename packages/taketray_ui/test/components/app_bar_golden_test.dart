import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'App bar',
    fileName: 'app_bar',
    scenarios: [
      TtScenario(
        'large',
        TtAppBar(
          title: 'Reels',
          large: true,
          actions: [_action(Symbols.search_rounded, 'Search')],
        ),
      ),
      TtScenario(
        'default with back',
        TtAppBar(
          title: 'Trip to Lisbon',
          leading: _action(Symbols.arrow_back_rounded, 'Back'),
          actions: [_action(Symbols.more_vert_rounded, 'More')],
        ),
      ),
      TtScenario(
        'with subtitle',
        TtAppBar(
          title: 'Trip to Lisbon',
          subtitle: '12 clips · 2 min 40 s',
          leading: _action(Symbols.arrow_back_rounded, 'Back'),
          actions: [
            _action(Symbols.search_rounded, 'Search'),
            _action(Symbols.more_vert_rounded, 'More'),
          ],
        ),
      ),
      TtScenario(
        'selection, 2 actions',
        TtAppBar(
          title: '3 selected',
          selection: true,
          leading: _action(Symbols.close_rounded, 'Close'),
          actions: [
            _action(Symbols.sell_rounded, 'Tag'),
            _action(Symbols.delete_rounded, 'Delete'),
          ],
        ),
      ),
      TtScenario(
        'long title',
        TtAppBar(
          title: 'Weekend in the mountains with the whole family and friends',
          subtitle: 'A long subtitle that goes on and on and on and on',
          leading: _action(Symbols.arrow_back_rounded, 'Back'),
          actions: [
            _action(Symbols.search_rounded, 'Search'),
            _action(Symbols.more_vert_rounded, 'More'),
          ],
        ),
      ),
      TtScenario(
        'long large title',
        TtAppBar(
          title: 'Weekend in the mountains with the whole family',
          large: true,
          actions: [_action(Symbols.search_rounded, 'Search')],
        ),
      ),
    ],
  );
}

Widget _action(IconData icon, String label) => TtIconButton(
  icon: icon,
  semanticLabel: label,
  style: TtIconButtonStyle.circle,
  onPressed: _noop,
);

void _noop() {}
