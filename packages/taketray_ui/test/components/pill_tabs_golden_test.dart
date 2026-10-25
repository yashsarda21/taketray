import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

const _tabs = [
  TtPillTab<String>('all', 'All'),
  TtPillTab<String>('waiting', 'Waiting 3'),
  TtPillTab<String>('ready', 'Ready'),
  TtPillTab<String>('done', 'Published'),
];

void main() {
  ttGoldenTest(
    'Pill tabs',
    fileName: 'pill_tabs',
    scenarios: [
      TtScenario('first selected', _tabsWith('all')),
      TtScenario('middle selected', _tabsWith('waiting')),
      TtScenario(
        'long label',
        TtPillTabs<String>(
          tabs: const [
            TtPillTab<String>('a', 'London street food and markets 2026'),
            TtPillTab<String>('b', 'Two'),
          ],
          value: 'a',
          onChanged: (_) {},
        ),
      ),
    ],
  );

  ttGoldenTest(
    'Suggestion chip',
    fileName: 'suggestion_chip',
    scenarios: [
      TtScenario(
        'chip',
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              TtSuggestionChip(label: 'London Food', onPressed: () {}),
              TtSuggestionChip(label: 'Tokyo', onPressed: () {}),
            ],
          ),
        ),
      ),
      TtScenario(
        'long label',
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TtSuggestionChip(
              label: 'A very long idea for a reel name that keeps going',
              onPressed: () {},
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _tabsWith(String value) =>
    TtPillTabs<String>(tabs: _tabs, value: value, onChanged: (_) {});
