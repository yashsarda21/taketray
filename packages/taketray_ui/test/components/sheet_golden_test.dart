import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// A list body like the reel picker's (`.sh-body` rows, 24 dp sides). A
/// column, not a list view: the golden table measures intrinsic sizes,
/// which a scroll view does not answer.
Widget _list(List<String> names) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final name in names)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              const Icon(Symbols.movie_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(name),
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

/// A scrolling body for a sheet of fixed height (no intrinsic queries reach
/// it there).
Widget _scrollingList(List<String> names) => ListView(children: [_list(names)]);

/// The footer of `.sh-foot`: equal-width buttons 8 dp apart.
Widget _footer(String cancel, String confirm) => TtButtonRow(
  children: [
    TtButton(label: cancel, kind: TtButtonKind.tonal, onPressed: () {}),
    TtButton(label: confirm, onPressed: () {}),
  ],
);

void main() {
  ttGoldenTest(
    'Sheet',
    fileName: 'sheet',
    scenarios: [
      TtScenario(
        'title, list body and footer',
        TtSheet(
          title: 'Add to reel',
          footer: _footer('Cancel', 'Add'),
          child: _list(['London Food', 'Day 1 Vlog', 'Autumn recipes']),
        ),
      ),
      TtScenario(
        'body only',
        TtSheet(child: _list(['London Food', 'Day 1 Vlog'])),
      ),
      TtScenario(
        'long title and labels',
        TtSheet(
          title: 'Add this clip to a reel with a very long name indeed',
          footer: _footer('Cancel', 'Add to 3 reels & next'),
          child: _list([
            'Autumn recipes from the farmers market and the old town',
          ]),
        ),
      ),
      TtScenario(
        'full screen',
        SizedBox(
          height: 420,
          child: TtSheet(
            title: 'Pick videos yourself',
            fullScreen: true,
            footer: _footer('Cancel', 'Add 3 videos'),
            child: _scrollingList([
              'London Food',
              'Day 1 Vlog',
              'Autumn recipes',
            ]),
          ),
        ),
      ),
    ],
  );
}
