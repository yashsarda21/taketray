import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

const List<TtViewerAction> _three = [
  TtViewerAction(
    icon: Symbols.library_add_rounded,
    label: 'Add to reel',
    onPressed: _noop,
  ),
  TtViewerAction(
    icon: Symbols.drive_file_move_rounded,
    label: 'Move',
    onPressed: _noop,
  ),
  TtViewerAction(
    icon: Symbols.playlist_remove_rounded,
    label: 'Remove',
    onPressed: _noop,
  ),
];

const List<TtViewerAction> _four = [
  ..._three,
  TtViewerAction(icon: Symbols.share_rounded, label: 'Share', onPressed: _noop),
];

void _noop() {}

/// The bottom of the viewer on its black ground, in the app theme the golden
/// uses (the viewer is dark in both).
Widget _viewer(List<TtViewerAction> actions, List<String> reels) =>
    TtVideoSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            TtReelTagRow(label: 'In', names: reels),
            TtViewerActions(actions: actions),
          ],
        ),
      ),
    );

void main() {
  ttGoldenTest(
    'Viewer chrome',
    fileName: 'viewer_chrome',
    scenarios: [
      TtScenario(
        'three actions, one reel',
        _viewer(_three, const ['Lisbon trip']),
      ),
      TtScenario(
        'three actions, three reels wrap',
        _viewer(_three, const [
          'Lisbon trip',
          'London Food',
          'Saturday morning market walk',
        ]),
      ),
      TtScenario(
        'four actions',
        _viewer(_four, const ['Lisbon trip', 'London Food']),
      ),
    ],
  );
}
