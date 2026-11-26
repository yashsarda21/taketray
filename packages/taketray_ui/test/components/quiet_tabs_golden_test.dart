import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

const _tabs = [
  TtQuietTab<String>('all', 'All', 12, semanticLabel: 'Show all reels, 12'),
  TtQuietTab<String>(
    'collecting',
    'Collecting',
    5,
    semanticLabel: 'Show Collecting reels, 5',
  ),
  TtQuietTab<String>('ready', 'Ready', 4, semanticLabel: 'Show Ready reels, 4'),
  TtQuietTab<String>(
    'published',
    'Published',
    3,
    semanticLabel: 'Show Published reels, 3',
  ),
];

void main() {
  ttGoldenTest(
    'Quiet tabs',
    fileName: 'quiet_tabs',
    scenarios: [
      TtScenario('All chosen', _tabsWith('all')),
      TtScenario('Ready chosen', _tabsWith('ready')),
      TtScenario(
        'the header pill',
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TtHeaderPill(
            icon: Symbols.add_rounded,
            label: 'New',
            semanticLabel: 'New reel',
            onPressed: () {},
          ),
        ),
      ),
    ],
  );
}

Widget _tabsWith(String value) => TtQuietTabs<String>(
  tabs: _tabs,
  value: value,
  onChanged: (_) {},
  semanticLabel: 'Show reels',
);
